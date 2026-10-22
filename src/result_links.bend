import Base
import ./result_link.bend as Link
import ./relations.bend as R
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./scoped_reader.bend as Scoped
import ./evidence.bend as Evidence
import ./history_titles.bend as Retained
import ./catalog.bend as Catalog
import ./provenance.bend as P

# Selected-result navigation is independent of the bounded relationship prefix.
# One exact selected record plus its predecessor is admitted before blobs are
# read. Candidate pages share the remaining 2 MiB and inspect at most 15 sources
# with 16 records each. Later pages and unexamined tails cannot prove uniqueness.
type Selected is Data:
  Selected{reference: R.SnapshotRef,ordinal: U32,event: U32,scope: Scoped.Scope,
    recorded: Link.Recorded,facts: R.Facts,citation: String,bytes: U32}

type Page is Data:
  Page{selected: Selected,watermark: String,after_source: String,next: Maybe<&2,String>,
    limit: U32,scanned_sources: U32,inspected_records: U32,inspected_bytes: U32,
    coverage: R.Coverage,rows: List<&2,R.Row>}

def context_identity(+value: String,record: U32) -> R.Identity:
  Bool.pick(R.Identity,String.is_empty(value),R.Missing{},R.Known{value,record})

def facts(+reference: R.SnapshotRef,+ordinal: U32,records: U32,bytes: U32,
  context: Store.Context,raw: Json.Json) -> R.Facts:
  Store.Context{repo,session,_,_} = context
  R.finished(R.raw_object(raw,ordinal,R.Facts{reference,context_identity(session,ordinal),
    context_identity(repo,ordinal),R.UnknownParent{},1,records,bytes,False{},
    "Selected result and verified incoming context only; earlier history was not replayed"}))

def permitted(pair: Store.Context & Providers.Record,scope: Scoped.Scope) -> Bool:
  (_, +event) = pair
  String.eq(Providers.role(event),"tool") && Scoped.permits(scope,"claude",event)

def event_allowed(value: Maybe<&2,Providers.Record>,context: Store.Context,scope: Scoped.Scope) -> Bool:
  match value:
    case None{}: False{}
    case Some{event}: permitted(Store.contextualize("claude",context,event),scope)

def scoped(allowed: Bool,recorded: Link.Recorded) -> Link.Recorded:
  match recorded:
    case Link.Agent{id,call}:
      Bool.pick(Link.Recorded,allowed,Link.Agent{id,call},
        Link.Unsupported{"Selected result is outside the current scope or lacks consistent retained repository/session/path metadata"})
    case other: other

def selected_raw(+raw: Json.Json,+reference: R.SnapshotRef,+ordinal: U32,+event: U32,
  records: U32,+bytes: U32,+context: Store.Context,+scope: Scoped.Scope) -> Selected:
  R.SnapshotRef{provider,source,generation,snapshot,extent} = reference
  Store.Context{_,session,_,_} = context
  +f = facts(reference,ordinal,records,bytes,context,raw)
  +recorded = Link.decode(raw,event,session)
  +events = Providers.usage_once(Providers.normalized("claude",raw))
  +allowed = event_allowed(Evidence.event_at(events,U32.to_nat(event)),context,scope) &&
    Bool.not(R.facts_bad(f)) && R.canonical_path(R.facts_repo(f)) &&
    Bool.not(String.is_empty(Link.namespace(R.ref_source(reference))))
  Selected{reference,ordinal,event,scope,
    scoped(allowed,recorded),
    f,Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,extent,U32.show(ordinal),[]},event),bytes}

def parsed(value: Result<&2,&2,String,Json.Json>,reference: R.SnapshotRef,ordinal: U32,event: U32,
  records: U32,bytes: U32,context: Store.Context,scope: Scoped.Scope) -> Result<&2,&2,String,Selected>:
  match value:
    case Fail{reason}: Fail{"Selected child result cannot be decoded: " ++ reason}
    case Done{raw}: Done{selected_raw(raw,reference,ordinal,event,records,bytes,context,scope)}

def decoded(value: Result<&2,&2,String,String>,reference: R.SnapshotRef,ordinal: U32,event: U32,
  records: U32,bytes: U32,context: Store.Context,scope: Scoped.Scope) -> Result<&2,&2,String,Selected>:
  match value:
    case Fail{reason}: Fail{"Selected child result is not valid UTF-8: " ++ reason}
    case Done{text}: parsed(Json.parse(text),reference,ordinal,event,records,bytes,context,scope)

def selected_sized(allowed: Bool,+db: U32,+header: R.Header,+ordinal: U32,event: U32,
  bytes: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Selected>):
  match allowed:
    case False{}: IO.pure(Result<&2,&2,String,Selected>,Fail{"Selected child result exceeds retained read budget"})
    case True{}:
      R.Header{+reference,source,+records} = header
      R.SnapshotRef{provider,locator,+generation,+snapshot,+extent} = reference
      do IO<Result<&2,&2,String,Selected>>:
        +row : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,Store.number(extent),records,ordinal)
        # These generic retained helpers are also used by titles: selected raw
        # is not read twice, and context is bound to its raw identity/version.
        ctx : Store.Context <- Retained.context_needed(True{},db,
          Retained.Header{source,provider,locator,snapshot,generation,Store.number(extent),records},ordinal,row)
        Store.checked(String.eq(Store.field(row,6n),"0"),"Selected child result is an oversized record fragment")
        return decoded(Domain.decode(Store.blob(Store.cell(row,5n))),reference,ordinal,event,records,bytes,ctx,scope)

def selected_valid(allowed: Bool,+db: U32,+header: R.Header,+ordinal: U32,event: U32,
  scope: Scoped.Scope) -> IO(Result<&2,&2,String,Selected>):
  match allowed:
    case False{}: IO.pure(Result<&2,&2,String,Selected>,Fail{"Selected child result ordinal is outside its captured snapshot"})
    case True{}:
      R.Header{reference,_,_} = header
      do IO<Result<&2,&2,String,Selected>>:
        +bytes : U32 <- Retained.cost(db,R.ref_id(reference),ordinal)
        selected_sized(U32.is_le(bytes,2097152),db,header,ordinal,event,bytes,scope)

def selected(+db: U32,+header: R.Header,+ordinal: U32,event: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Selected>):
  R.Header{_,_,records} = header
  selected_valid(U32.is_lt(ordinal,records),db,header,ordinal,event,scope)

def edge(selection: Selected,+target: R.Facts) -> List<&2,R.Row>:
  Selected{+reference,ordinal,_,Scoped.Scope{_,repo,_,_},recorded,+anchor,_,_} = selection
  match recorded:
    case Link.Agent{id,_}:
      Bool.pick(List<&2,R.Row>,R.compatible(anchor,target,repo) &&
        Link.target(R.ref_source(reference),id,R.ref_source(R.facts_ref(target))),
        [R.Row{target,"child","recorded_tool_result_agent_id",reference,Some{ordinal},False{}}],[])
    case _: []

def add_scan(value: Result<&2,&2,String,R.Scan>,selection: Selected,cursor: String,
  accum: R.Accum) -> Result<&2,&2,String,R.Accum>:
  match value:
    case Fail{+message}:
      R.budget_skip(String.starts_with(message,"Relationship read exceeds the 2097152-byte"),message,cursor,accum)
    case Done{R.Scan{+f,left}}:
      R.Accum{_,records,scanned,_,prior,rows} = accum
      Done{R.Accum{left,U32.add(records,R.facts_inspected(f)),U32.inc(scanned),cursor,
        R.coverage(prior,f),List.append(&2,R.Row,rows,edge(selection,f))}}

def walk_header(value: Result<&2,&2,String,R.Header>,+db: U32,selection: Selected,
  +accum: R.Accum) -> IO(Result<&2,&2,String,R.Accum>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,R.Accum>,Fail{reason})
    case Done{+header}:
      R.Header{_,source,_} = header
      R.Accum{remaining,_,_,_,_,_} = accum
      do IO<Result<&2,&2,String,R.Accum>>:
        result : Result<&2,&2,String,R.Scan> <- R.scan(db,header,remaining)
        return add_scan(result,selection,source,accum)

def walk(rows: List<&2,List<&2,Sql.Cell>>,+db: U32,+selection: Selected,
  accum: R.Accum) -> IO(Result<&2,&2,String,R.Accum>):
  match rows:
    case []: IO.pure(Result<&2,&2,String,R.Accum>,Done{accum})
    case row <> rest:
      do IO<Result<&2,&2,String,R.Accum>>:
        next : Result<&2,&2,String,R.Accum> <- walk_header(R.header(row),db,selection,accum)
        R.walk_next(next,a => walk(rest,db,selection,a))

def marked(rows: List<&2,R.Row>,+ambiguous: Bool) -> List<&2,R.Row>:
  match rows:
    case []: []
    case row <> rest: R.marked(row,ambiguous) <> marked(rest,ambiguous)

def assembled(value: Result<&2,&2,String,R.Accum>,selection: Selected,watermark: String,
  after: String,limit: U32,more: Bool) -> Result<&2,&2,String,Page>:
  match value:
    case Fail{reason}: Fail{reason}
    case Done{R.Accum{remaining,records,scanned,cursor,cov,+rows}}:
      Done{Page{selection,watermark,after,Bool.pick(Maybe<&2,String>,more,Some{cursor},None{}),
        limit,scanned,records,U32.sub(2097152,remaining),cov,
        marked(rows,Nat.is_gt(List.length(&2,R.Row,rows),1n))}}

def candidates(+db: U32,+selection: Selected,source_id: String,+watermark: String,
  +after: String,+limit: U32) -> IO(Result<&2,&2,String,Page>):
  Selected{_,ordinal,_,_,_,_,_,bytes} = selection
  do IO<Result<&2,&2,String,Page>>:
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.provider,s.locator,p.generation,p.id,p.extent,s.id,p.records FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE s.provider='claude' AND s.id>? AND s.id<>? AND p.accepted=1 AND p.id<=? AND p.id=(SELECT max(x.id) FROM generations gx JOIN snapshots x ON x.generation=gx.id WHERE gx.source=s.id AND x.accepted=1 AND x.id<=?) ORDER BY s.id LIMIT ?",
      [Sql.Cell.Integer{after},Sql.Cell.Integer{source_id},Sql.Cell.Integer{watermark},
       Sql.Cell.Integer{watermark},Sql.Cell.Integer{U32.show(U32.inc(limit))}],16)
    result : Result<&2,&2,String,R.Accum> <- walk(List.take(&2,List<&2,Sql.Cell>,rows,U32.to_nat(limit)),
      db,selection,R.Accum{U32.sub(2097152,bytes),U32.inc(Bool.to_u32(U32.is_gt(ordinal,0))),
        0,after,R.Coverage{0,0,0,0,0},[]})
    return assembled(result,selection,watermark,after,limit,
      Nat.is_gt(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(limit)))

def selection_ready(value: Result<&2,&2,String,Selected>,db: U32,source: String,
  watermark: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,Page>,Fail{reason})
    case Done{+selection}:
      candidates(db,selection,source,watermark,after,limit)

def loaded(value: Result<&2,&2,String,R.Header>,+db: U32,ordinal: U32,event: U32,
  scope: Scoped.Scope,watermark: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,Page>,Fail{reason})
    case Done{+header}:
      R.Header{_,source,_} = header
      do IO<Result<&2,&2,String,Page>>:
        value : Result<&2,&2,String,Selected> <- selected(db,header,ordinal,event,scope)
        selection_ready(value,db,source,watermark,after,limit)

def watermarked(value: Result<&2,&2,String,String>,+db: U32,+expected: R.SnapshotRef,
  ordinal: U32,event: U32,scope: Scoped.Scope,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,Page>,Fail{reason})
    case Done{watermark}:
      do IO<Result<&2,&2,String,Page>>:
        header : Result<&2,&2,String,R.Header> <- R.load_header(db,R.ref_id(expected))
        loaded(R.checked_header(header,expected),db,ordinal,event,scope,watermark,after,limit)

def load_mark(fresh: Bool,db: U32,watermark: String) -> IO(List<&2,List<&2,Sql.Cell>>):
  match fresh:
    case True{}: Store.q(db,"SELECT max(id) FROM snapshots WHERE accepted=1",[],1)
    case False{}: Store.q(db,"SELECT id FROM snapshots WHERE id=? AND accepted=1",[Sql.Cell.Integer{watermark}],1)

def owned(value: Result<&2,&2,String,Unit>,+db: U32,expected: R.SnapshotRef,ordinal: U32,
  event: U32,scope: Scoped.Scope,+watermark: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,Page>,Fail{reason})
    case Done{_}:
      do IO<Result<&2,&2,String,Page>>:
        rows : List<&2,List<&2,Sql.Cell>> <- load_mark(String.is_empty(watermark),db,watermark)
        result : Result<&2,&2,String,Page> <- watermarked(R.watermark_row(Store.first(rows)),
          db,expected,ordinal,event,scope,after,limit)
        Store.exec(db,"ROLLBACK",[])
        return result

def valid(yes: Bool,+db: U32,expected: R.SnapshotRef,ordinal: U32,event: U32,
  scope: Scoped.Scope,watermark: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match yes:
    case False{}: IO.pure(Result<&2,&2,String,Page>,Fail{"Child-result navigation requires an exact Claude snapshot, valid scope, watermark/cursor and candidate limit from 1 to 15"})
    case True{}:
      do IO<Result<&2,&2,String,Page>>:
        started : Result<&2,&2,String,Unit> <- R.transaction(db)
        owned(started,db,expected,ordinal,event,scope,watermark,after,limit)

def page(db: U32,+expected: R.SnapshotRef,ordinal: U32,event: U32,+scope: Scoped.Scope,
  +watermark: String,+after: String,+limit: U32) -> IO(Result<&2,&2,String,Page>):
  Scoped.Scope{_,+repo,_,_} = scope
  valid(R.valid_ref(expected) && String.eq(R.ref_provider(expected),"claude") && Scoped.valid(scope) &&
    (String.is_empty(repo) || R.canonical_path(repo)) &&
    (String.is_empty(watermark) || (Catalog.identity_valid(watermark) &&
      Bool.not(Cmp.is_gt(P.decimal_compare(R.ref_id(expected),watermark))))) &&
    (String.eq(after,"0") || Catalog.identity_valid(after)) &&
    U32.is_gt(limit,0) && U32.is_le(limit,15),db,expected,ordinal,event,scope,watermark,after,limit)

def open(db: U32,expected: R.SnapshotRef,ordinal: U32,event: U32,scope: Scoped.Scope,limit: U32) -> IO(Result<&2,&2,String,Page>):
  page(db,expected,ordinal,event,scope,"","0",limit)

# Completeness is bounded and page-local. A single candidate is not described as
# globally unique; partial raw metadata, skips and other pages remain explicit.
def complete(page: Page) -> Bool:
  Page{_,_,_,next,_,_,_,_,R.Coverage{unknown,conflicting,unsupported,partial,skipped},_} = page
  Bool.not(Maybe.is_some(&2,String,next)) && U32.is_eq(unknown,0) && U32.is_eq(conflicting,0) &&
    U32.is_eq(unsupported,0) && U32.is_eq(partial,0) && U32.is_eq(skipped,0)
