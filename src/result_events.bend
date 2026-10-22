import Base
import ./json.bend as Json
import ./relations.bend as R
import ./result_link.bend as Link
import ./result_links.bend as Links
import ./request_evidence.bend as Request
import ./store.bend as Store
import ./sql.bend as Sql
import ./history_titles.bend as Retained
import ./scoped_reader.bend as Scoped
import ./providers.bend as Providers
import ./domain.bend as Domain
import ./evidence.bend as Evidence
import ./catalog.bend as Catalog

type ResultEvent is Data:
  ResultEvent{record: U32,event: U32,recorded: Link.Recorded,citation: String}

type Blocks is Data:
  Blocks{rows: List<&2,ResultEvent>,next: U32,more: Bool}

type Accum is Data:
  Accum{rows: List<&2,ResultEvent>,record: U32,event: U32,left: U32,scanned: U32,unavailable: U32}

type Page is Data:
  Page{reference: R.SnapshotRef,start: U32,count: U32,record: U32,event: U32,
    next_record: U32,next_event: U32,more: Bool,scanned: U32,bytes: U32,
    unavailable: U32,scope: Scoped.Scope,rows: List<&2,ResultEvent>}

def citation(reference: R.SnapshotRef,record: U32,event: U32) -> String:
  R.SnapshotRef{provider,source,generation,snapshot,extent} = reference
  Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,extent,U32.show(record),[]},event)

def admitted(+raw: Json.Json,+block: Json.Json,+context: Store.Context,+scope: Scoped.Scope) -> Bool:
  Request.named(Request.field(block,"type"),"tool_result") &&
    (Request.named(Request.field(raw,"type"),"user") || Request.named(Request.field(raw,"type"),"assistant")) &&
    Links.permitted(Store.contextualize("claude",context,
      Providers.claude_block_type("tool_result",raw,"tool",block)),scope)

def block_row(yes: Bool,raw: Json.Json,reference: R.SnapshotRef,+record: U32,+event: U32,
  context: Store.Context) -> List<&2,ResultEvent>:
  match yes:
    case False{}: []
    case True{}:
      Store.Context{_,session,_,_} = context
      [ResultEvent{record,event,Link.decode(raw,event,session),citation(reference,record,event)}]

def combine(rows: List<&2,ResultEvent>,rest: Blocks) -> Blocks:
  Blocks{tail,next,more} = rest
  Blocks{List.append(&2,ResultEvent,rows,tail),next,more}

# The cursor is a raw content-block index, never a position inferred from text.
# A full row page resumes inside that same record; no dense-record tail is lost.
def blocks(items: List<&2,Json.Json>,+slot: U32,+room: U32,+raw: Json.Json,
  +reference: R.SnapshotRef,+record: U32,+context: Store.Context,+scope: Scoped.Scope) -> Blocks:
  match items room:
    case [] _: Blocks{[],slot,False{}}
    case _ 0: Blocks{[],slot,True{}}
    case +head <> rest n:
      +row = block_row(admitted(raw,head,context,scope),raw,reference,record,slot,context)
      combine(row,blocks(rest,U32.inc(slot),U32.sub(n,U32.from_nat(List.length(&2,ResultEvent,row))),
        raw,reference,record,context,scope))


def parsed(value: Result<&2,&2,String,Json.Json>,reference: R.SnapshotRef,record: U32,
  +event: U32,room: U32,context: Store.Context,scope: Scoped.Scope) -> Maybe<&2,Blocks>:
  match value:
    case Fail{_}: None{}
    case Done{+raw}:
      Some{blocks(List.drop(&2,Json.Json,Json.items(Json.field(Json.field(raw,"message"),"content")),U32.to_nat(event)),
        event,room,raw,reference,record,context,scope)}

def decoded(value: Result<&2,&2,String,String>,reference: R.SnapshotRef,record: U32,
  +event: U32,room: U32,context: Store.Context,scope: Scoped.Scope) -> Maybe<&2,Blocks>:
  match value:
    case Fail{_}: None{}
    case Done{text}: parsed(Json.parse(text),reference,record,event,room,context,scope)

def accumulated(value: Maybe<&2,Blocks>,accum: Accum,bytes: U32) -> Accum:
  match value accum:
    case None{} Accum{rows,record,event,left,scanned,unavailable}:
      Accum{rows,U32.inc(record),0,U32.sub(left,bytes),U32.inc(scanned),U32.inc(unavailable)}
    case Some{Blocks{more_rows,next,+more}} Accum{rows,+record,event,left,scanned,unavailable}:
      Accum{List.append(&2,ResultEvent,rows,more_rows),Bool.pick(U32,more,record,U32.inc(record)),
        Bool.pick(U32,more,next,0),U32.sub(left,bytes),U32.inc(scanned),unavailable}

def read_allowed(yes: Bool,+db: U32,header: R.Header,+accum: Accum,bytes: U32,
  scope: Scoped.Scope) -> IO(Accum):
  match yes:
    case False{}: IO.pure(Accum,accumulated(None{},accum,0))
    case True{}:
      R.Header{+reference,source,+records} = header
      R.SnapshotRef{provider,locator,+generation,+snapshot,+extent} = reference
      Accum{+rows,+record,event,_,_,_} = accum
      do IO<Accum>:
        +row : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,Store.number(extent),records,record)
        context : Store.Context <- Retained.context_needed(True{},db,
          Retained.Header{source,provider,locator,snapshot,generation,Store.number(extent),records},record,row)
        return accumulated(Bool.pick(Maybe<&2,Blocks>,String.eq(Store.field(row,6n),"0"),
          decoded(Domain.decode(Store.blob(Store.cell(row,5n))),reference,record,event,
            U32.sub(20,U32.from_nat(List.length(&2,ResultEvent,rows))),context,scope),None{}),accum,bytes)

def walk_ready(yes: Bool,+db: U32,+header: R.Header,scope: Scoped.Scope,+accum: Accum,
  next_page: Accum -> IO(Accum)) -> IO(Accum):
  match yes:
    case False{}: IO.pure(Accum,accum)
    case True{}:
      Accum{_,+record,_,left,_,_} = accum
      do IO<Accum>:
        +cost : U32 <- Retained.cost(db,R.ref_id(R.header_reference(header)),record)
        next : Accum <- read_allowed(U32.is_le(cost,left),db,header,accum,cost,scope)
        next_page(next)

def walk(fuel: Nat,+db: U32,+header: R.Header,+end: U32,+scope: Scoped.Scope,+accum: Accum) -> IO(Accum):
  match fuel:
    case 0n: IO.pure(Accum,accum)
    case 1n+rest:
      Accum{rows,record,_,_,scanned,_} = accum
      walk_ready(U32.is_lt(record,end) && U32.is_lt(scanned,10) &&
        Nat.is_lt(List.length(&2,ResultEvent,rows),20n),db,header,scope,accum,
        next => walk(rest,db,header,end,scope,next))

def assemble(reference: R.SnapshotRef,start: U32,count: U32,record: U32,event: U32,
  end: U32,scope: Scoped.Scope,accum: Accum) -> Page:
  Accum{rows,+next,slot,left,scanned,unavailable} = accum
  Page{reference,start,count,record,event,next,slot,U32.is_lt(next,end),scanned,
    U32.sub(2097152,left),unavailable,scope,rows}

def loaded_valid(yes: Bool,+db: U32,+header: R.Header,+start: U32,+count: U32,
  +record: U32,+event: U32,+scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  match yes:
    case False{}: IO.pure(Result<&2,&2,String,Page>,Fail{"Child results require a captured Claude range and a cursor inside that range"})
    case True{}:
      R.Header{+reference,_,records} = header
      do IO<Result<&2,&2,String,Page>>:
        accum : Accum <- walk(10n,db,header,U32.min(records,U32.add(start,count)),scope,Accum{[],record,event,2097152,0,0})
        return Done{assemble(reference,start,count,record,event,U32.min(records,U32.add(start,count)),scope,accum)}

def loaded(value: Result<&2,&2,String,R.Header>,db: U32,+start: U32,+count: U32,
  +record: U32,+event: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,Page>,Fail{reason})
    case Done{+header}:
      R.Header{reference,_,records} = header
      loaded_valid(String.eq(R.ref_provider(reference),"claude") && U32.is_le(start,records) &&
        U32.is_ge(record,start) && U32.is_le(record,U32.min(records,U32.add(start,count))) &&
        (U32.is_lt(record,U32.min(records,U32.add(start,count))) || U32.is_eq(event,0)),
        db,header,start,count,record,event,scope)

def owned(value: Result<&2,&2,String,Unit>,+db: U32,snapshot: String,start: U32,count: U32,
  record: U32,event: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{reason}: IO.pure(Result<&2,&2,String,Page>,Fail{reason})
    case Done{_}:
      do IO<Result<&2,&2,String,Page>>:
        header : Result<&2,&2,String,R.Header> <- R.load_header(db,snapshot)
        result : Result<&2,&2,String,Page> <- loaded(header,db,start,count,record,event,scope)
        Store.exec(db,"ROLLBACK",[])
        return result

def valid(yes: Bool,+db: U32,snapshot: String,start: U32,count: U32,record: U32,event: U32,
  scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  match yes:
    case False{}: IO.pure(Result<&2,&2,String,Page>,Fail{"Child result list requires a valid snapshot, scope, bounded range <=40 and event cursor <=262144"})
    case True{}:
      do IO<Result<&2,&2,String,Page>>:
        started : Result<&2,&2,String,Unit> <- R.transaction(db)
        owned(started,db,snapshot,start,count,record,event,scope)

def page(db: U32,+snapshot: String,+start: U32,+count: U32,record: U32,+event: U32,
  +scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  valid(Catalog.identity_valid(snapshot) && Scoped.valid(scope) && U32.is_le(count,40) &&
    U32.is_le(start,4294967255) && U32.is_le(event,262144),db,snapshot,start,count,record,event,scope)
