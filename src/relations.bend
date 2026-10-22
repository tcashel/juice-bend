import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./domain.bend as Domain
import ./catalog.bend as Catalog
import ./provenance.bend as P

# A relationship is a fact about retained bytes or a retained locator, never
# authorship, execution status, or a reconstructed historical session graph.
type SnapshotRef is Data:
  SnapshotRef{provider: String,source: String,generation: String,snapshot: String,extent: String}

type Identity is Data:
  Missing{}
  Known{value: String,record: U32}
  Invalid{reason: String}
  Conflicting{reason: String}

type Parent is Data:
  UnknownParent{}
  RecordedParent{id: String,record: U32}
  PathAssociated{locator: String,parent_alias: String,child_alias: String}
  UnsupportedParent{reason: String}
  ConflictingParent{reason: String}

type Facts is Data:
  Facts{reference: SnapshotRef,session: Identity,repository: Identity,parent: Parent,
    inspected: U32,total_records: U32,bytes: U32,complete: Bool,coverage: String}

type Row is Data:
  # ambiguous reports collisions observed in this page. False is not a global
  # uniqueness claim; further pages, unexamined sources and raw tails may exist.
  Row{target: Facts,direction: String,basis: String,witness: SnapshotRef,
    record: Maybe<&2,U32>,ambiguous: Bool}

type Link is Data:
  Link{basis: String,record: Maybe<&2,U32>}

type Coverage is Data:
  Coverage{unknown: U32,conflicting: U32,unsupported: U32,partial: U32,unexamined_budget: U32}

type Page is Data:
  Page{anchor: Facts,repository: String,watermark: String,after_source: String,
    next: Maybe<&2,String>,limit: U32,scanned_sources: U32,inspected_records: U32,
    inspected_bytes: U32,coverage: Coverage,rows: List<&2,Row>}

type Header is Data:
  Header{reference: SnapshotRef,source_id: String,records: U32}

type Scan is Data:
  Scan{facts: Facts,remaining: U32}

type RecordState is Data:
  RecordState{facts: Facts,codex_header_seen: Bool}

type Accum is Data:
  Accum{remaining: U32,records: U32,scanned: U32,cursor: String,
    coverage: Coverage,rows: List<&2,Row>}

def check(valid: Bool,message: String) -> Result<&2,&2,String,Unit>:
  Bool.pick(Result<&2,&2,String,Unit>,valid,Done{Unit{}},Fail{message})

def byte_step(valid: Bool,left: U32,next: U32 -> Bool) -> Bool:
  match valid:
    case False{}:
      False{}
    case True{}:
      next(left)

def utf8_fits(value: String,+left: U32) -> Bool:
  match value:
    case SNil{}:
      True{}
    case SCon{Chr{+cp},rest}:
      +n = U32.inc(Domain.encode_width(cp))
      byte_step(Domain.scalar(cp) && U32.is_le(n,left),U32.sub(left,n),
        remaining => utf8_fits(rest,remaining))

def identifier(+value: String) -> Bool:
  Bool.not(String.is_empty(value)) && Bool.not(String.contains(value,"\0")) && utf8_fits(value,8192)

def path_components(parts: List<&2,String>) -> Bool:
  match parts:
    case []:
      True{}
    case +part <> rest:
      Bool.not(String.is_empty(part)) && Bool.not(String.eq(part,".")) &&
        Bool.not(String.eq(part,"..")) && path_components(rest)

# Lexical canonical form only: no source or repository filesystem access.
def canonical_path(+value: String) -> Bool:
  identifier(value) && (String.eq(value,"/") ||
    (String.starts_with(value,"/") && path_components(String.split(String.drop(value,1n),'/'))))

def field(value: Json.Json,name: String) -> Maybe<&2,Json.Json>:
  match value:
    case Json.JObject{fields}:
      Json.field_scan(fields,name,None{})
    case _:
      None{}

def text(value: Json.Json) -> String:
  match value:
    case Json.JString{value}:
      value
    case _:
      ""

def known(value: Identity) -> String:
  match value:
    case Known{value,_}:
      value
    case _:
      ""

def identity_bad(value: Identity) -> Bool:
  match value:
    case Invalid{_}:
      True{}
    case Conflicting{_}:
      True{}
    case _:
      False{}

def merge_id(prior: Identity,+value: String,record: U32) -> Identity:
  match prior:
    case Missing{}:
      Known{value,record}
    case Known{+old,at}:
      Bool.pick(Identity,String.eq(old,value),Known{old,at},Conflicting{"conflicting retained identity declarations"})
    case Invalid{reason}:
      Invalid{reason}
    case Conflicting{reason}:
      Conflicting{reason}

def observed_valid(valid: Bool,prior: Identity,value: String,record: U32) -> Identity:
  match valid:
    case True{}:
      merge_id(prior,value,record)
    case False{}:
      Invalid{"identity must be a nonempty bounded string; repository must have canonical absolute syntax"}

def observe(value: Maybe<&2,Json.Json>,prior: Identity,record: U32,repo: Bool) -> Identity:
  match value:
    case None{}:
      prior
    case Some{Json.JString{+value}}:
      observed_valid(identifier(value) && (Bool.not(repo) || canonical_path(value)),prior,value,record)
    case Some{_}:
      Invalid{"retained identity has an unsupported JSON type; it was not coerced"}

def parent_id(value: Parent) -> String:
  match value:
    case RecordedParent{id,_}:
      id
    case _:
      ""

def merge_parent(prior: Parent,+id: String,record: U32) -> Parent:
  match prior:
    case UnknownParent{}:
      RecordedParent{id,record}
    case RecordedParent{+old,at}:
      Bool.pick(Parent,String.eq(old,id),RecordedParent{old,at},
        ConflictingParent{"conflicting recorded parent thread identifiers"})
    case UnsupportedParent{reason}:
      UnsupportedParent{reason}
    case ConflictingParent{reason}:
      ConflictingParent{reason}
    case PathAssociated{_,_,_}:
      ConflictingParent{"recorded and path-associated parent metadata conflict"}

def recorded_valid(valid: Bool,prior: Parent,id: String,record: U32) -> Parent:
  match valid:
    case True{}:
      merge_parent(prior,id,record)
    case False{}:
      UnsupportedParent{"Codex parent thread identifier is empty, oversized, or contains NUL"}

def recorded_id(value: Json.Json,prior: Parent,record: U32) -> Parent:
  match value:
    case Json.JString{+id}:
      recorded_valid(identifier(id),prior,id,record)
    case _:
      UnsupportedParent{"Codex subagent has no supported string parent thread identifier"}

def subagent(value: Maybe<&2,Json.Json>,prior: Parent,record: U32) -> Parent:
  match value:
    case None{}:
      prior
    case Some{Json.JObject{fields}}:
      recorded_id(Json.field(Json.field(Json.JObject{fields},"thread_spawn"),"parent_thread_id"),prior,record)
    case Some{_}:
      UnsupportedParent{"unsupported or parentless Codex subagent metadata"}

def first_issue(+old: String,message: String) -> String:
  Bool.pick(String,String.is_empty(old),message,old)

def raw_object(+raw: Json.Json,+at: U32,facts: Facts) -> Facts:
  Facts{+reference,session,repository,+parent,inspected,total,bytes,complete,coverage} = facts
  SnapshotRef{provider,_,_,_,_} = reference
  match provider:
    case "claude":
      +session = observe(field(raw,"session_id"),observe(field(raw,"sessionId"),session,at,False{}),at,False{})
      +repository = observe(field(raw,"repository"),observe(field(raw,"cwd"),repository,at,True{}),at,True{})
      Facts{reference,session,repository,parent,inspected,total,bytes,complete,coverage}
    case "codex":
      +payload = Json.field(raw,"payload")
      +metadata = String.eq(text(Json.field(raw,"type")),"session_meta")
      +session = observe(field(raw,"session_id"),session,at,False{})
      +session = observe(field(payload,"session_id"),session,at,False{})
      +session = Bool.pick(Identity,metadata,observe(field(payload,"id"),session,at,False{}),session)
      +repository = observe(field(raw,"cwd"),observe(field(payload,"cwd"),repository,at,True{}),at,True{})
      +parent = Bool.pick(Parent,metadata,subagent(field(Json.field(payload,"source"),"subagent"),parent,at),parent)
      Facts{reference,session,repository,parent,inspected,total,bytes,complete,coverage}
    case _:
      Facts{reference,session,repository,UnsupportedParent{"unsupported provider"},inspected,total,bytes,complete,coverage}

def issue(facts: Facts,message: String) -> Facts:
  Facts{reference,session,repository,parent,inspected,total,bytes,_,coverage} = facts
  Facts{reference,session,repository,parent,inspected,total,bytes,False{},first_issue(coverage,message)}

def parsed(value: Result<&2,&2,String,Json.Json>,at: U32,facts: Facts) -> Facts:
  match value:
    case Done{Json.JObject{fields}}:
      raw_object(Json.JObject{fields},at,facts)
    case Done{_}:
      issue(facts,"non-object retained record was not interpreted as relationship metadata")
    case Fail{_}:
      issue(facts,"malformed retained JSON was not interpreted as relationship metadata")

def decoded(value: Result<&2,&2,String,String>,at: U32,facts: Facts) -> Facts:
  match value:
    case Done{text}:
      parsed(Json.parse(text),at,facts)
    case Fail{_}:
      issue(facts,"invalid UTF-8 retained record was not interpreted as relationship metadata")

def later_parent(prior: Parent,later: Parent) -> Parent:
  match prior later:
    case UnknownParent{} UnknownParent{}:
      UnknownParent{}
    case RecordedParent{+id,record} RecordedParent{other,_}:
      Bool.pick(Parent,String.eq(id,other),RecordedParent{id,record},
        ConflictingParent{"later session_meta contradicts the first header's parent; no replacement link was created"})
    case UnsupportedParent{reason} _:
      UnsupportedParent{reason}
    case ConflictingParent{reason} _:
      ConflictingParent{reason}
    case _ _:
      ConflictingParent{"later session_meta adds or changes parent metadata; the first header remains authoritative"}

def repeated_header(+raw: Json.Json,at: U32,facts: Facts) -> Facts:
  Facts{reference,session,repository,parent,inspected,total,bytes,complete,coverage} = facts
  +payload = Json.field(raw,"payload")
  Facts{reference,session,repository,later_parent(parent,
    subagent(field(Json.field(payload,"source"),"subagent"),UnknownParent{},at)),
    inspected,total,bytes,complete,first_issue(coverage,
      "Later session_meta identity/repository declarations were not used; the first Codex header is authoritative")}

def first_header(raw: Json.Json,at: U32,facts: Facts) -> Facts:
  Facts{reference,_,_,_,inspected,total,bytes,complete,coverage} = facts
  raw_object(raw,at,Facts{reference,Missing{},Missing{},UnknownParent{},inspected,total,bytes,complete,coverage})

def state_object(+raw: Json.Json,+at: U32,state: RecordState) -> RecordState:
  RecordState{+facts,+seen} = state
  Facts{SnapshotRef{provider,_,_,_,_},_,_,_,_,_,_,_,_} = facts
  +codex = String.eq(provider,"codex")
  +metadata = String.eq(text(Json.field(raw,"type")),"session_meta")
  RecordState{Bool.pick(Facts,codex,
    Bool.pick(Facts,metadata,Bool.pick(Facts,seen,repeated_header(raw,at,facts),first_header(raw,at,facts)),facts),
    raw_object(raw,at,facts)),seen || (codex && metadata)}

def state_parsed(value: Result<&2,&2,String,Json.Json>,at: U32,state: RecordState) -> RecordState:
  match value:
    case Done{Json.JObject{fields}}:
      state_object(Json.JObject{fields},at,state)
    case Done{_}:
      RecordState{facts,seen} = state
      RecordState{issue(facts,"non-object retained record was not interpreted as relationship metadata"),seen}
    case Fail{_}:
      RecordState{facts,seen} = state
      RecordState{issue(facts,"malformed retained JSON was not interpreted as relationship metadata"),seen}

def state_decoded(value: Result<&2,&2,String,String>,at: U32,state: RecordState) -> RecordState:
  match value:
    case Done{text}:
      state_parsed(Json.parse(text),at,state)
    case Fail{_}:
      RecordState{facts,seen} = state
      RecordState{issue(facts,"invalid UTF-8 retained record was not interpreted as relationship metadata"),seen}

def row_facts(+row: List<&2,Sql.Cell>,at: U32,state: RecordState) -> RecordState:
  RecordState{facts,+seen} = state
  Facts{reference,session,repository,parent,inspected,total,bytes,complete,coverage} = facts
  +next = {Facts{reference,session,repository,parent,U32.inc(inspected),total,
    U32.add(bytes,Store.number(Store.field(row,3n))),complete,coverage} : Facts}
  Bool.pick(RecordState,String.eq(Store.field(row,6n),"0"),
    state_decoded(Domain.decode(Store.blob(Store.cell(row,5n))),at,RecordState{next,seen}),
    RecordState{issue(next,"oversized retained record was not interpreted as relationship metadata"),seen})

def inspect(rows: List<&2,List<&2,Sql.Cell>>,+at: U32,state: RecordState) -> Facts:
  match rows:
    case []:
      RecordState{facts,_} = state
      facts
    case row <> rest:
      inspect(rest,U32.inc(at),row_facts(row,at,state))

def path_parent(parts: List<&2,String>,parent: Parent) -> Parent:
  match parts:
    case +filename <> "subagents" <> +alias <> rest:
      +valid = identifier(alias) && String.ends_with(filename,".jsonl") &&
        Nat.is_gt(String.length(filename),6n)
      +base = String.join(List.reverse(&2,String,rest),"/")
      Bool.pick(Parent,valid,PathAssociated{base ++ "/" ++ alias ++ ".jsonl",alias,
        alias ++ "/" ++ String.take(filename,Nat.sub(String.length(filename),6n))},parent)
    case _:
      parent

def finished(facts: Facts) -> Facts:
  Facts{+reference,+session,repository,+parent,inspected,total,bytes,complete,coverage} = facts
  SnapshotRef{provider,source,_,_,_} = reference
  +parent = Bool.pick(Parent,Bool.not(String.is_empty(known(session))) &&
    String.eq(known(session),parent_id(parent)),ConflictingParent{"self-referencing recorded parent identity"},parent)
  Facts{reference,session,repository,Bool.pick(Parent,String.eq(provider,"claude"),
    path_parent(List.reverse(&2,String,String.split(source,'/')),parent),parent),
    inspected,total,bytes,complete,coverage}

def ref_id(reference: SnapshotRef) -> String:
  SnapshotRef{_,_,_,snapshot,_} = reference
  snapshot

def ref_source(reference: SnapshotRef) -> String:
  SnapshotRef{_,source,_,_,_} = reference
  source

def ref_provider(reference: SnapshotRef) -> String:
  SnapshotRef{provider,_,_,_,_} = reference
  provider

def same_ref(a: SnapshotRef,b: SnapshotRef) -> Bool:
  SnapshotRef{ap,as,ag,ai,ae} = a
  SnapshotRef{bp,bs,bg,bi,be} = b
  String.eq(ap,bp) && String.eq(as,bs) && String.eq(ag,bg) && String.eq(ai,bi) && String.eq(ae,be)

def valid_ref(reference: SnapshotRef) -> Bool:
  SnapshotRef{+provider,source,generation,snapshot,extent} = reference
  (String.eq(provider,"claude") || String.eq(provider,"codex")) && canonical_path(source) &&
    Catalog.identity_valid(generation) && Catalog.identity_valid(snapshot) && Catalog.quantity_valid(extent)

def header(row: List<&2,Sql.Cell>) -> Result<&2,&2,String,Header>:
  match row:
    case [Sql.Cell.Text{provider},Sql.Cell.Text{source},Sql.Cell.Integer{generation},
      Sql.Cell.Integer{snapshot},Sql.Cell.Integer{extent},Sql.Cell.Integer{+source_id},
      Sql.Cell.Integer{+records}]:
      +reference = {SnapshotRef{provider,source,generation,snapshot,extent} : SnapshotRef}
      do Result<&2,&2,String,Header>:
        check(valid_ref(reference) && Catalog.identity_valid(source_id) && Catalog.quantity_valid(records),
          "Relationship snapshot metadata is invalid")
        return Header{reference,source_id,Store.number(records)}
    case _:
      Fail{"Accepted relationship snapshot is missing or metadata has an invalid SQLite type"}

def load_header(db: U32,snapshot: String) -> IO(Result<&2,&2,String,Header>):
  do IO<Result<&2,&2,String,Header>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.provider,s.locator,p.generation,p.id,p.extent,s.id,p.records FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    return header(Store.first(rows))

def rows_budget(rows: List<&2,List<&2,Sql.Cell>>,+remaining: U32) -> Result<&2,&2,String,U32>:
  match rows:
    case []:
      Done{remaining}
    case +row <> rest:
      +length = Store.number(Store.field(row,3n))
      do Result<&2,&2,String,U32>:
        check(U32.is_le(length,remaining),"Relationship read exceeds the 2097152-byte aggregate retained-raw budget; choose a smaller candidate page")
        rows_budget(rest,U32.sub(remaining,length))

def scanned_rows(+rows: List<&2,List<&2,Sql.Cell>>,reference: SnapshotRef,+records: U32,
  remaining: U32) -> Result<&2,&2,String,Scan>:
  do Result<&2,&2,String,Scan>:
    left : U32 <- rows_budget(rows,remaining)
    facts : Facts = finished(inspect(rows,0,RecordState{Facts{reference,Missing{},Missing{},UnknownParent{},
      0,records,0,U32.is_le(records,16),""},False{}}))
    return Scan{facts,left}

def raw_sizes(rows: List<&2,List<&2,Sql.Cell>>,+remaining: U32) -> Result<&2,&2,String,U32>:
  match rows:
    case []:
      Done{remaining}
    case [Sql.Cell.Integer{+length},Sql.Cell.Integer{actual}] <> rest:
      do Result<&2,&2,String,U32>:
        check(Catalog.quantity_valid(length) && String.eq(length,actual),"Relationship retained raw byte-count metadata is invalid")
        +size : U32 = Store.number(length)
        check(U32.is_le(size,remaining),"Relationship read exceeds the 2097152-byte aggregate retained-raw budget; source was not examined")
        raw_sizes(rest,U32.sub(remaining,size))
    case _:
      Fail{"Relationship retained raw byte-count metadata has invalid SQLite types"}

def scan_sized(value: Result<&2,&2,String,U32>,db: U32,+reference: SnapshotRef,+records: U32,
  remaining: U32) -> IO(Result<&2,&2,String,Scan>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Scan>,Fail{message})
    case Done{_}:
      SnapshotRef{_,_,generation,snapshot,extent} = reference
      do IO<Result<&2,&2,String,Scan>>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.selected_records(db,snapshot,generation,
          Store.number(extent),records,0,U32.min(records,16))
        return scanned_rows(rows,reference,records,remaining)

def scan(+db: U32,header: Header,+remaining: U32) -> IO(Result<&2,&2,String,Scan>):
  Header{+reference,_,+records} = header
  SnapshotRef{_,_,_,snapshot,_} = reference
  do IO<Result<&2,&2,String,Scan>>:
    # Size preflight loads no raw payload. Accepted bytes are immutable inside
    # this transaction; actual payloads are subsequently verified, not trusted.
    +sizes : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.n,length(r.bytes) FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal<? ORDER BY i.ordinal",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(U32.min(records,16))}],16)
    Store.checked(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,sizes),U32.to_nat(U32.min(records,16))),
      "Relationship retained prefix record index is incomplete or corrupt")
    scan_sized(raw_sizes(sizes,remaining),db,reference,records,remaining)

def header_reference(value: Header) -> SnapshotRef:
  Header{reference,_,_} = value
  reference

def checked_header(value: Result<&2,&2,String,Header>,expected: SnapshotRef) -> Result<&2,&2,String,Header>:
  do Result<&2,&2,String,Header>:
    +h : Header <- value
    check(same_ref(header_reference(h),expected),"Relationship snapshot identity changed or does not match the selected capture")
    return h

def read_header(value: Result<&2,&2,String,Header>,db: U32,remaining: U32) -> IO(Result<&2,&2,String,Scan>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Scan>,Fail{message})
    case Done{h}:
      scan(db,h,remaining)

def scan_facts(result: Result<&2,&2,String,Scan>) -> Result<&2,&2,String,Facts>:
  match result:
    case Fail{message}:
      Fail{message}
    case Done{Scan{facts,_}}:
      Done{facts}

def transaction_result(value: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> Result<&2,&2,String,Unit>:
  match value:
    case Done{_}:
      Done{Unit{}}
    case Fail{(code,_)}:
      Fail{"Relationship transaction start failed (SQLite " ++ U32.show(code) ++ "); caller transaction was not ended"}

def transaction(db: U32) -> IO(Result<&2,&2,String,Unit>):
  do IO<Result<&2,&2,String,Unit>>:
    value : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"BEGIN DEFERRED",[],0)
    return transaction_result(value)

def read_owned(value: Result<&2,&2,String,Unit>,+db: U32,+expected: SnapshotRef) -> IO(Result<&2,&2,String,Facts>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Facts>,Fail{message})
    case Done{_}:
      do IO<Result<&2,&2,String,Facts>>:
        h : Result<&2,&2,String,Header> <- load_header(db,ref_id(expected))
        result : Result<&2,&2,String,Scan> <- read_header(checked_header(h,expected),db,2097152)
        Store.exec(db,"ROLLBACK",[])
        return scan_facts(result)

def read_valid(valid: Bool,+db: U32,expected: SnapshotRef) -> IO(Result<&2,&2,String,Facts>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Facts>,Fail{"Invalid selected relationship snapshot identity"})
    case True{}:
      do IO<Result<&2,&2,String,Facts>>:
        owned : Result<&2,&2,String,Unit> <- transaction(db)
        read_owned(owned,db,expected)

def read_facts(db: U32,+expected: SnapshotRef) -> IO(Result<&2,&2,String,Facts>):
  read_valid(valid_ref(expected),db,expected)

def facts_ref(facts: Facts) -> SnapshotRef:
  Facts{reference,_,_,_,_,_,_,_,_} = facts
  reference

def facts_repo(facts: Facts) -> String:
  Facts{_,_,repository,_,_,_,_,_,_} = facts
  known(repository)

def facts_session(facts: Facts) -> String:
  Facts{_,session,_,_,_,_,_,_,_} = facts
  known(session)

def facts_inspected(facts: Facts) -> U32:
  Facts{_,_,_,_,inspected,_,_,_,_} = facts
  inspected

def parent_conflict(parent: Parent) -> Bool:
  match parent:
    case ConflictingParent{_}:
      True{}
    case _:
      False{}

def facts_bad(facts: Facts) -> Bool:
  Facts{_,session,repository,parent,_,_,_,_,_} = facts
  identity_bad(session) || identity_bad(repository) || parent_conflict(parent)

def facts_supported(facts: Facts) -> Bool:
  Facts{_,_,_,parent,_,_,_,_,_} = facts
  match parent:
    case UnsupportedParent{_}:
      False{}
    case _:
      True{}

def compatible(+a: Facts,+b: Facts,+repository: String) -> Bool:
  +repo = facts_repo(a)
  String.eq(ref_provider(facts_ref(a)),ref_provider(facts_ref(b))) &&
    Bool.not(String.eq(ref_source(facts_ref(a)),ref_source(facts_ref(b)))) && Bool.not(String.is_empty(repo)) &&
    String.eq(repo,facts_repo(b)) && (String.is_empty(repository) || String.eq(repo,repository)) &&
    Bool.not(facts_bad(a)) && Bool.not(facts_bad(b)) && facts_supported(a) && facts_supported(b)

def link(child: Facts,+parent: Facts) -> Maybe<&2,Link>:
  Facts{_,_,_,relation,_,_,_,_,_} = child
  match relation:
    case RecordedParent{+id,record}:
      Bool.pick(Maybe<&2,Link>,String.eq(id,facts_session(parent)),
        Some{Link{"recorded_parent_thread_id",Some{record}}},None{})
    case PathAssociated{locator,_,_}:
      Bool.pick(Maybe<&2,Link>,String.eq(locator,ref_source(facts_ref(parent))),
        Some{Link{"retained_path_association",None{}}},None{})
    case _:
      None{}

def linked(value: Maybe<&2,Link>,target: Facts,direction: String,
  witness: SnapshotRef,rest: List<&2,Row>) -> List<&2,Row>:
  match value:
    case None{}:
      rest
    case Some{Link{basis,record}}:
      Row{target,direction,basis,witness,record,False{}} <> rest

def edges_valid(valid: Bool,+anchor: Facts,+target: Facts) -> List<&2,Row>:
  match valid:
    case False{}:
      []
    case True{}:
      linked(link(anchor,target),target,"parent",facts_ref(anchor),
        linked(link(target,anchor),target,"child",facts_ref(target),[]))

def edges(+anchor: Facts,+target: Facts,repository: String) -> List<&2,Row>:
  edges_valid(compatible(anchor,target,repository),anchor,target)

def coverage(prior: Coverage,+facts: Facts) -> Coverage:
  Coverage{unknown,conflicting,unsupported,partial,unexamined} = prior
  Facts{_,_,_,_,_,_,_,complete,issue} = facts
  Coverage{U32.add(unknown,Bool.to_u32(String.is_empty(facts_session(facts)) || String.is_empty(facts_repo(facts)))),
    U32.add(conflicting,Bool.to_u32(facts_bad(facts))),
    U32.add(unsupported,Bool.to_u32(Bool.not(facts_supported(facts)))),
    U32.add(partial,Bool.to_u32(Bool.not(complete) || Bool.not(String.is_empty(issue)))),unexamined}

def budget_skip(valid: Bool,message: String,cursor: String,accum: Accum) -> Result<&2,&2,String,Accum>:
  match valid:
    case False{}:
      Fail{message}
    case True{}:
      Accum{remaining,records,scanned,_,Coverage{unknown,conflicting,unsupported,partial,skipped},rows} = accum
      Done{Accum{remaining,records,U32.inc(scanned),cursor,
        Coverage{unknown,conflicting,unsupported,partial,U32.inc(skipped)},rows}}

def add_scan(value: Result<&2,&2,String,Scan>,+anchor: Facts,repo: String,cursor: String,
  accum: Accum) -> Result<&2,&2,String,Accum>:
  match value:
    case Fail{+message}:
      budget_skip(String.starts_with(message,"Relationship read exceeds the 2097152-byte"),message,cursor,accum)
    case Done{Scan{+facts,left}}:
      Accum{_,records,scanned,_,prior,rows} = accum
      Done{Accum{left,U32.add(records,facts_inspected(facts)),U32.inc(scanned),cursor,coverage(prior,facts),
        List.append(&2,Row,rows,edges(anchor,facts,repo))}}

def walk_next(value: Result<&2,&2,String,Accum>,next: Accum -> IO(Result<&2,&2,String,Accum>)) -> IO(Result<&2,&2,String,Accum>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Accum>,Fail{message})
    case Done{value}:
      next(value)

def walk_header(value: Result<&2,&2,String,Header>,+db: U32,anchor: Facts,repo: String,
  +accum: Accum) -> IO(Result<&2,&2,String,Accum>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Accum>,Fail{message})
    case Done{+h}:
      Header{_,source,_} = h
      Accum{remaining,_,_,_,_,_} = accum
      do IO<Result<&2,&2,String,Accum>>:
        result : Result<&2,&2,String,Scan> <- scan(db,h,remaining)
        return add_scan(result,anchor,repo,source,accum)

def walk(rows: List<&2,List<&2,Sql.Cell>>,+db: U32,+anchor: Facts,+repo: String,accum: Accum) -> IO(Result<&2,&2,String,Accum>):
  match rows:
    case []:
      IO.pure(Result<&2,&2,String,Accum>,Done{accum})
    case row <> rest:
      do IO<Result<&2,&2,String,Accum>>:
        next : Result<&2,&2,String,Accum> <- walk_header(header(row),db,anchor,repo,accum)
        walk_next(next,a => walk(rest,db,anchor,repo,a))

def row_direction(row: Row) -> String:
  Row{_,direction,_,_,_,_} = row
  direction

def actor_alias(facts: Facts) -> String:
  Facts{_,session,_,parent,_,_,_,_,_} = facts
  match parent:
    case PathAssociated{_,_,alias}:
      alias
    case _:
      known(session)

def collision(a: Row,b: Row) -> Bool:
  Row{+at,+ad,_,_,_,_} = a
  Row{+bt,+bd,_,_,_,_} = b
  +same_target = same_ref(facts_ref(at),facts_ref(bt))
  +same_direction = String.eq(ad,bd)
  (same_target && Bool.not(same_direction)) ||
    (Bool.not(same_target) && same_direction &&
      (String.eq(ad,"parent") || (Bool.not(String.is_empty(actor_alias(at))) &&
        String.eq(actor_alias(at),actor_alias(bt)))))

def collisions(rows: List<&2,Row>,+wanted: Row) -> Bool:
  match rows:
    case []:
      False{}
    case row <> rest:
      collision(wanted,row) || collisions(rest,wanted)

def marked(row: Row,ambiguous: Bool) -> Row:
  Row{target,direction,basis,witness,record,_} = row
  Row{target,direction,basis,witness,record,ambiguous}

def mark(rows: List<&2,Row>,+all: List<&2,Row>) -> List<&2,Row>:
  match rows:
    case []:
      []
    case +row <> rest:
      marked(row,collisions(all,row)) <> mark(rest,all)

def assembled(value: Result<&2,&2,String,Accum>,anchor: Facts,repo: String,watermark: String,
  after: String,limit: U32,more: Bool) -> Result<&2,&2,String,Page>:
  match value:
    case Fail{message}:
      Fail{message}
    case Done{Accum{remaining,records,scanned,cursor,cov,+rows}}:
      Done{Page{anchor,repo,watermark,after,Bool.pick(Maybe<&2,String>,more,Some{cursor},None{}),
        limit,scanned,records,U32.sub(2097152,remaining),cov,mark(rows,rows)}}

def candidates(+db: U32,+anchor: Facts,source_id: String,+repo: String,+watermark: String,
  +after: String,+limit: U32,remaining: U32) -> IO(Result<&2,&2,String,Page>):
  Facts{+reference,_,_,_,inspected,_,_,_,_} = anchor
  SnapshotRef{provider,_,_,_,_} = reference
  do IO<Result<&2,&2,String,Page>>:
    # Select one accepted snapshot per exact source across all generations.
    # A fixed accepted-ID watermark makes later appends and rewrites invisible.
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.provider,s.locator,p.generation,p.id,p.extent,s.id,p.records FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE s.provider=? AND s.id>? AND s.id<>? AND p.accepted=1 AND p.id<=? AND p.id=(SELECT max(x.id) FROM generations gx JOIN snapshots x ON x.generation=gx.id WHERE gx.source=s.id AND x.accepted=1 AND x.id<=?) ORDER BY s.id LIMIT ?",
      [Sql.Cell.Text{provider},Sql.Cell.Integer{after},Sql.Cell.Integer{source_id},
       Sql.Cell.Integer{watermark},Sql.Cell.Integer{watermark},Sql.Cell.Integer{U32.show(U32.inc(limit))}],16)
    result : Result<&2,&2,String,Accum> <- walk(List.take(&2,List<&2,Sql.Cell>,rows,U32.to_nat(limit)),
      db,anchor,repo,Accum{remaining,inspected,0,after,coverage(Coverage{0,0,0,0,0},anchor),[]})
    return assembled(result,anchor,repo,watermark,after,limit,
      Nat.is_gt(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(limit)))

def anchor_scanned(value: Result<&2,&2,String,Scan>,db: U32,source: String,repo: String,
  watermark: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{Scan{facts,remaining}}:
      candidates(db,facts,source,repo,watermark,after,limit,remaining)

def anchor_header(value: Result<&2,&2,String,Header>,+db: U32,repo: String,watermark: String,
  after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{+h}:
      Header{_,source,_} = h
      do IO<Result<&2,&2,String,Page>>:
        result : Result<&2,&2,String,Scan> <- scan(db,h,2097152)
        anchor_scanned(result,db,source,repo,watermark,after,limit)

def watermark_row(row: List<&2,Sql.Cell>) -> Result<&2,&2,String,String>:
  match row:
    case [Sql.Cell.Integer{+id}]:
      do Result<&2,&2,String,String>:
        check(Catalog.identity_valid(id),"Invalid accepted snapshot watermark")
        return id
    case _:
      Fail{"Accepted snapshot watermark is unavailable"}

def loaded_watermark(value: Result<&2,&2,String,String>,+db: U32,+expected: SnapshotRef,
  repo: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{+watermark}:
      do IO<Result<&2,&2,String,Page>>:
        h : Result<&2,&2,String,Header> <- load_header(db,ref_id(expected))
        anchor_header(checked_header(h,expected),db,repo,watermark,after,limit)

def within_watermark(valid: Bool,+db: U32,expected: SnapshotRef,repo: String,+watermark: String,
  after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Page>,Fail{"Selected anchor is newer than the requested library watermark"})
    case True{}:
      do IO<Result<&2,&2,String,Page>>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT id FROM snapshots WHERE id=? AND accepted=1",
          [Sql.Cell.Integer{watermark}],1)
        loaded_watermark(watermark_row(Store.first(rows)),db,expected,repo,after,limit)

def page_owned(value: Result<&2,&2,String,Unit>,+db: U32,+expected: SnapshotRef,repo: String,
  +watermark: String,after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{_}:
      do IO<Result<&2,&2,String,Page>>:
        result : Result<&2,&2,String,Page> <- within_watermark(
          Bool.not(Cmp.is_gt(P.decimal_compare(ref_id(expected),watermark))),db,expected,repo,watermark,after,limit)
        Store.exec(db,"ROLLBACK",[])
        return result

def page_valid(valid: Bool,+db: U32,expected: SnapshotRef,repo: String,watermark: String,
  after: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Page>,Fail{"Relationship read requires valid snapshot/watermark/cursor identities, canonical repository scope, and a candidate limit from1 to16"})
    case True{}:
      do IO<Result<&2,&2,String,Page>>:
        owned : Result<&2,&2,String,Unit> <- transaction(db)
        page_owned(owned,db,expected,repo,watermark,after,U32.min(limit,15))

def page(db: U32,+expected: SnapshotRef,+repo: String,+watermark: String,+after: String,+limit: U32) -> IO(Result<&2,&2,String,Page>):
  page_valid(valid_ref(expected) && (String.is_empty(repo) || canonical_path(repo)) &&
    Catalog.identity_valid(watermark) && (String.eq(after,"0") || Catalog.identity_valid(after)) &&
    U32.is_gt(limit,0) && U32.is_le(limit,16),db,expected,repo,watermark,after,limit)

def open_header(value: Result<&2,&2,String,Header>,+db: U32,repo: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{Header{expected,_,_}}:
      do IO<Result<&2,&2,String,Page>>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT max(id) FROM snapshots WHERE accepted=1",[],1)
        loaded_watermark(watermark_row(Store.first(rows)),db,expected,repo,"0",limit)

def open_owned(value: Result<&2,&2,String,Unit>,+db: U32,snapshot: String,repo: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match value:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{_}:
      do IO<Result<&2,&2,String,Page>>:
        h : Result<&2,&2,String,Header> <- load_header(db,snapshot)
        result : Result<&2,&2,String,Page> <- open_header(h,db,repo,limit)
        Store.exec(db,"ROLLBACK",[])
        return result

def open_valid(valid: Bool,+db: U32,snapshot: String,repo: String,limit: U32) -> IO(Result<&2,&2,String,Page>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Page>,Fail{"Relationship open requires a valid snapshot, canonical repository scope, and candidate limit from1 to16"})
    case True{}:
      do IO<Result<&2,&2,String,Page>>:
        owned : Result<&2,&2,String,Unit> <- transaction(db)
        open_owned(owned,db,snapshot,repo,U32.min(limit,15))

def open(db: U32,+snapshot: String,+repo: String,+limit: U32) -> IO(Result<&2,&2,String,Page>):
  open_valid(Catalog.identity_valid(snapshot) && (String.is_empty(repo) || canonical_path(repo)) &&
    U32.is_gt(limit,0) && U32.is_le(limit,16),db,snapshot,repo,limit)
