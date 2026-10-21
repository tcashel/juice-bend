import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./query.bend as Query
import ./scoped_reader.bend as Scoped
import ./providers.bend as Providers
import ./request_evidence.bend as Request
import ./request_origin.bend as Origin
import ./evidence.bend as Evidence
import ./domain.bend as Domain
import ./json.bend as Json

# History titles are bounded display excerpts, never actor attribution or a
# claim to the first human intent. SQL events locate candidates only. Capture,
# opening ordinals, Search snippets and all nine other History cells stay exact.
# One page inspects at most 4 candidate physical records per row and 8 MiB of
# selected raw plus predecessor bytes. No prefix replay or all-source actor scan.
def candidate_limit() -> U32: 4
def page_budget() -> U32: 8388608
def neutral() -> String: "Captured source"

type Header is Data:
  Header{source: String,provider: String,locator: String,snapshot: String,
    generation: String,extent: U32,records: U32}

type Choice is Data:
  Continue{}
  Chosen{text: String}
  Unavailable{}

type Inspection is Data:
  Inspection{choice: Choice,remaining: U32}

def replacement(row: List<&2,Sql.Cell>,title: String) -> List<&2,Sql.Cell>:
  match row:
    case [a,b,c,d,e,f,g,_,i,j]: [a,b,c,d,e,f,g,Sql.Cell.Text{title},i,j]
    case other: other

# Display-only whitespace normalization is after complete typed classification.
# Accumulating in reverse avoids repeated growing-string append.
def compact_step(white: Bool,head: Char,space: Bool,+done: String,next: Bool -> String -> String) -> String:
  match white:
    case True{}:
      next(True{},Bool.pick(String,space,done,SCon{' ',done}))
    case False{}: next(False{},SCon{head,done})

def compact(text: String,+space: Bool,done: String) -> String:
  match text:
    case SNil{}: String.trim_end(String.reverse(done))
    case SCon{+head,tail}:
      compact_step(Origin.whitespace(head),head,space,done,
        white => acc => compact(tail,white,acc))

def excerpt(+text: String) -> String:
  +single = compact(text,True{},"")
  Bool.pick(String,Nat.is_gt(String.length(single),90n),
    String.take(single,89n) ++ "…",single)

def requested(value: Maybe<&2,String>) -> Choice:
  match value:
    case Some{text}: Chosen{excerpt(text)}
    case None{}: Continue{}

def assessed(value: Origin.Assessment) -> Choice:
  match value:
    case Origin.Assessment{_,_,Origin.Uncertain{_}}: Unavailable{}
    case other: requested(Origin.request(other))

def event_choice(allowed: Bool,provider: String,meta: Origin.MetaFlag,
  hint: Maybe<&2,String>,event: Providers.Record) -> Choice:
  match allowed:
    case False{}: Continue{}
    case True{}: assessed(Request.assess_aligned(provider,meta,hint,event))

def events_next(choice: Choice,next: Unit -> Choice) -> Choice:
  match choice:
    case Continue{}: next(Unit{})
    case other: other

def normalized(pair: Store.Context & Providers.Record,original: Providers.Record,
  +provider: String,scope: Scoped.Scope,meta: Origin.MetaFlag,hint: Maybe<&2,String>,
  next: Store.Context -> Choice) -> Choice:
  (context,+event) = pair
  events_next(event_choice(String.eq(Providers.role(event),"user") &&
    Scoped.permits(scope,provider,event),provider,meta,hint,original),_ => next(context))

def events_scan(events: List<&2,Providers.Record>,hints: List<&2,Maybe<&2,String>>,
  +provider: String,+scope: Scoped.Scope,+meta: Origin.MetaFlag,context: Store.Context) -> Choice:
  match events hints:
    case Nil{} _: Continue{}
    case Con{+event,rest} Con{hint,tail}:
      normalized(Store.contextualize(provider,context,event),event,provider,scope,meta,hint,
        next => events_scan(rest,tail,provider,scope,meta,next))
    case Con{+event,rest} Nil{}:
      normalized(Store.contextualize(provider,context,event),event,provider,scope,meta,None{},
        next => events_scan(rest,[],provider,scope,meta,next))

def frame_ready(ready: Bool,+raw: Json.Json,+provider: String,scope: Scoped.Scope,
  context: Store.Context) -> Choice:
  match ready:
    case False{}: Unavailable{}
    case True{}:
      events_scan(Providers.usage_once(Providers.normalized(provider,raw)),Request.texts(provider,raw),
        provider,scope,Origin.metadata(raw),context)

def parsed(result: Result<&2,&2,String,Json.Json>,+provider: String,scope: Scoped.Scope,
  context: Store.Context) -> Choice:
  match result:
    case Fail{_}: Unavailable{}
    case Done{+raw}:
      frame_ready(String.is_empty(Request.frame_issue(provider,raw)),raw,provider,scope,context)

def decoded(result: Result<&2,&2,String,String>,provider: String,scope: Scoped.Scope,
  context: Store.Context) -> Choice:
  match result:
    case Fail{_}: Unavailable{}
    case Done{text}: parsed(Json.parse(text),provider,scope,context)

def frame_complete(complete: Bool,row: List<&2,Sql.Cell>,provider: String,scope: Scoped.Scope,
  context: Store.Context) -> Choice:
  match complete:
    case True{}: decoded(Domain.decode(Store.blob(Store.cell(row,5n))),provider,scope,context)
    case False{}: Unavailable{}

def frame(+row: List<&2,Sql.Cell>,provider: String,scope: Scoped.Scope,context: Store.Context) -> Choice:
  frame_complete(String.eq(Store.field(row,6n),"0"),row,provider,scope,context)

def incoming(value: Maybe<&2,Store.Context>) -> Store.Context:
  match value:
    case Some{context}: context
    case None{}: Store.Context{"","","",""}

# Reuse the ordinary selected-context verifier with the already verified raw
# row, avoiding context_before's second selected raw/predecessor read. Unknown
# legacy/missing context remains empty: only explicit raw scope can then match.
def context_needed(needed: Bool,+db: U32,header: Header,+ordinal: U32,raw: List<&2,Sql.Cell>) -> IO(Store.Context):
  match needed:
    case False{}: IO.pure(Store.Context,Store.Context{"","","",""})
    case True{}:
      Header{_,_,_,+snapshot,+generation,+extent,+records} = header
      do IO<Store.Context>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT c.repository,c.session,c.model,c.parent,c.version,c.digest,i.raw,r.generation,r.ordinal,r.offset,r.n,r.digest,g.source,s.provider,s.locator,p.generation,p.extent,p.records FROM snapshot_context c LEFT JOIN records i ON i.snapshot=c.snapshot AND i.ordinal=c.ordinal LEFT JOIN raw r ON r.id=i.raw LEFT JOIN snapshots p ON p.id=c.snapshot LEFT JOIN generations g ON g.id=p.generation LEFT JOIN sources s ON s.id=g.source WHERE c.snapshot=? AND c.ordinal=?",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],1)
        value : Maybe<&2,Store.Context> <- Store.selected_context_rows(snapshot,generation,extent,records,ordinal,raw,rows)
        return incoming(value)

def context(db: U32,header: Header,ordinal: U32,raw: List<&2,Sql.Cell>,scope: Scoped.Scope) -> IO(Store.Context):
  Scoped.Scope{_,repo,_,_} = scope
  context_needed(Bool.not(String.is_empty(repo)),db,header,ordinal,raw)

# Read SQLite byte lengths before materializing blobs. The selected verifier
# still authenticates their digest, positions, coverage and predecessor.
def costs(rows: List<&2,List<&2,Sql.Cell>>,total: U32) -> IO(U32):
  match rows:
    case []: IO.pure(U32,total)
    case [Sql.Cell.Integer{+n},Sql.Cell.Integer{+actual},Sql.Cell.Text{kind}] <> rest:
      do IO<U32>:
        Store.checked(Store.numeric(n) && Store.numeric(actual) && String.eq(n,actual) &&
          String.eq(kind,"blob") && U32.is_gt(Store.number(n),0) && U32.is_le(Store.number(n),262144),
          "History title raw integrity byte budget mismatch")
        costs(rest,U32.add(total,Store.number(n)))
    case _: IO.die(U32,1,"History title raw integrity byte metadata type mismatch")

def cost(+db: U32,snapshot: String,+ordinal: U32) -> IO(U32):
  +before = Bool.to_u32(U32.is_gt(ordinal,0))
  do IO<U32>:
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.n,length(r.bytes),typeof(r.bytes) FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal>=? AND i.ordinal<=? ORDER BY i.ordinal",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(U32.sub(ordinal,before))},Sql.Cell.Integer{U32.show(ordinal)}],2)
    Store.checked(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(U32.inc(before))),
      "History title raw integrity record or predecessor is missing")
    costs(rows,0)

def inspected(allowed: Bool,+db: U32,+header: Header,+scope: Scoped.Scope,+ordinal: U32,
  budget: U32,bytes: U32) -> IO(Inspection):
  match allowed:
    case False{}: IO.pure(Inspection,Inspection{Unavailable{},budget})
    case True{}:
      Header{_,provider,_,+snapshot,generation,extent,records} = header
      do IO<Inspection>:
        +raw : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,extent,records,ordinal)
        ctx : Store.Context <- context(db,header,ordinal,raw,scope)
        return Inspection{frame(raw,provider,scope,ctx),U32.sub(budget,bytes)}

def candidate(+db: U32,+header: Header,scope: Scoped.Scope,+ordinal: U32,+budget: U32) -> IO(Inspection):
  Header{_,_,_,snapshot,_,_,records} = header
  do IO<Inspection>:
    Store.checked(U32.is_lt(ordinal,records),"History title candidate ordinal integrity mismatch")
    +bytes : U32 <- cost(db,snapshot,ordinal)
    inspected(U32.is_le(bytes,budget),db,header,scope,ordinal,budget,bytes)

def candidates_next(result: Inspection,next: U32 -> IO(Inspection)) -> IO(Inspection):
  match result:
    case Inspection{Continue{},budget}: next(budget)
    case other: IO.pure(Inspection,other)

def candidates(rows: List<&2,List<&2,Sql.Cell>>,+db: U32,+header: Header,+scope: Scoped.Scope,budget: U32) -> IO(Inspection):
  match rows:
    case []: IO.pure(Inspection,Inspection{Unavailable{},budget})
    case [Sql.Cell.Integer{+ordinal}] <> rest:
      do IO<Inspection>:
        Store.checked(Store.numeric(ordinal),"History title candidate ordinal integrity type mismatch")
        result : Inspection <- candidate(db,header,scope,Store.number(ordinal),budget)
        candidates_next(result,remaining => candidates(rest,db,header,scope,remaining))
    case _: IO.die(Inspection,1,"History title candidate integrity row mismatch")

def allowed(+provider: String,scope: Scoped.Scope) -> Bool:
  Scoped.Scope{+wanted,_,+role,_} = scope
  (String.is_empty(wanted) || String.eq(provider,wanted)) &&
    (String.is_empty(role) || String.eq(role,"user"))

def locate(+db: U32,+header: Header,+scope: Scoped.Scope,budget: U32) -> IO(Inspection):
  Header{source,provider,locator,+snapshot,generation,extent,records} = header
  Scoped.Scope{_,+repo,_,+after} = scope
  do IO<Inspection>:
    +identity : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT g.source,s.provider,s.locator,p.generation,p.extent,p.records FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    Store.checked(String.eq(Store.field(Store.first(identity),0n),source) &&
      String.eq(Store.field(Store.first(identity),1n),provider) && String.eq(Store.field(Store.first(identity),2n),locator) &&
      String.eq(Store.field(Store.first(identity),3n),generation) && String.eq(Store.field(Store.first(identity),4n),U32.show(extent)) &&
      String.eq(Store.field(Store.first(identity),5n),U32.show(records)),"History title source or snapshot integrity mismatch")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT DISTINCT ordinal FROM events WHERE snapshot=? AND role='user' AND body<>'' AND (?='' OR repository=?) AND (?='' OR (length(timestamp)=30 AND substr(timestamp,11,1)='T' AND substr(timestamp,30,1)='Z' AND timestamp>=?)) ORDER BY ordinal LIMIT ?",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Text{repo},Sql.Cell.Text{repo},Sql.Cell.Text{after},Sql.Cell.Text{after},
        Sql.Cell.Integer{U32.show(candidate_limit())}],4)
    candidates(rows,db,header,scope,budget)

def inspect_allowed(yes: Bool,db: U32,header: Header,scope: Scoped.Scope,budget: U32) -> IO(Inspection):
  match yes:
    case False{}: IO.pure(Inspection,Inspection{Unavailable{},budget})
    case True{}: locate(db,header,scope,budget)

def inspect(+db: U32,+row: List<&2,Sql.Cell>,+scope: Scoped.Scope,+budget: U32) -> IO(Inspection):
  +source = Store.field(row,0n)
  +provider = Store.field(row,1n)
  +snapshot = Store.field(row,3n)
  +generation = Store.field(row,4n)
  +extent = Store.field(row,5n)
  +records = Store.field(row,6n)
  do IO<Inspection>:
    Store.checked(Nat.is_eq(List.length(&2,Sql.Cell,row),10n) && Evidence.positive_id(source) &&
      Evidence.positive_id(snapshot) && Evidence.positive_id(generation) && Store.numeric(extent) && Store.numeric(records),
      "History title snapshot integrity metadata mismatch")
    inspect_allowed(allowed(provider,scope) && U32.is_gt(budget,0),db,
      Header{source,provider,Store.field(row,2n),snapshot,generation,Store.number(extent),Store.number(records)},scope,budget)

def choice_title(choice: Choice) -> String:
  match choice:
    case Chosen{text}: text
    case _: neutral()

def enriched(result: Inspection,row: List<&2,Sql.Cell>,
  next: U32 -> IO(List<&2,List<&2,Sql.Cell>>)) -> IO(List<&2,List<&2,Sql.Cell>>):
  Inspection{choice,budget} = result
  do IO<List<&2,List<&2,Sql.Cell>>>:
    tail : List<&2,List<&2,Sql.Cell>> <- next(budget)
    return replacement(row,choice_title(choice)) <> tail

def enrich_budget(+db: U32,rows: List<&2,List<&2,Sql.Cell>>,+scope: Scoped.Scope,budget: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  match rows:
    case []: IO.pure(List<&2,List<&2,Sql.Cell>>,[])
    case +row <> rest:
      do IO<List<&2,List<&2,Sql.Cell>>>:
        result : Inspection <- inspect(db,row,scope,budget)
        enriched(result,row,remaining => enrich_budget(db,rest,scope,remaining))

def enrich(db: U32,rows: List<&2,List<&2,Sql.Cell>>,scope: Scoped.Scope) -> IO(List<&2,List<&2,Sql.Cell>>):
  enrich_budget(db,rows,scope,page_budget())

# Called by CLI list_rows inside its existing read transaction. Search never
# enters this function and its exact snippets and result shape remain unchanged.
def history(+db: U32,filters: Query.Filters,limit: U32,offset: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  Query.Filters{_,+provider,+repo,role,after} = filters
  +scope = {Scoped.Scope{provider,repo,role,after} : Scoped.Scope}
  do IO<List<&2,List<&2,Sql.Cell>>>:
    Store.checked(Scoped.valid(scope),"History title scope is invalid")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.history(db,provider,repo,limit,offset)
    enrich(db,rows,scope)
