import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./maintenance.bend as Maintenance
import ./evidence.bend as Evidence
import ./providers.bend as Providers
import ./scoped_reader.bend as Scoped
import ./tool_activity.bend as Activity
import ./domain.bend as Domain
import ./json.bend as Json

# read owns one DEFERRED transaction and refuses a preexisting transaction. It
# does not publish, repair, consult original logs, or end a caller transaction.
# Raw verification/context seals use the same production readers as transcripts.
type Page is Data:
  Page{provider: String, source: String, generation: String, snapshot: String,
    extent: U32, total_records: U32, start: U32, requested: U32,
    selected_count: U32, verified_count: U32, scope: Scoped.Scope,
    activity: Activity.Page}

type Gather is Data:
  Gather{context: Store.Context, count: U32, remaining: U32, events: List<&2,Activity.Occurrence>}

def scope_text(scope: Scoped.Scope) -> String:
  Scoped.Scope{provider,repository,role,after} = scope
  "{\"provider\":" ++ Json.quote(provider) ++ ",\"repository\":" ++ Json.quote(repository) ++
    ",\"role\":" ++ Json.quote(role) ++ ",\"after\":" ++ Json.quote(after) ++ "}"

def descriptor(+record: Evidence.Verified,+index: U32) -> Evidence.Descriptor:
  Evidence.Verified{_,_,_,_,extent,ordinal,_} = record
  Evidence.Descriptor{Evidence.record_key(record,index),extent,Store.number(ordinal),index}

def include_bytes(context: Store.Context,count: U32,events: List<&2,Activity.Occurrence>,
  occurrence: Activity.Occurrence,left: Maybe<&2,U32>) -> Result<&2,&2,String,Gather>:
  match left:
    case None{}:
      Fail{"Selected scoped activity exceeds 524288 UTF-8 bytes including citations; choose a smaller physical range. No payload was truncated"}
    case Some{remaining}:
      Done{Gather{context,U32.inc(count),remaining,occurrence <> events}}

def include_count(context: Store.Context,count: U32,budget: U32,events: List<&2,Activity.Occurrence>,
  +occurrence: Activity.Occurrence,available: Bool) -> Result<&2,&2,String,Gather>:
  match available:
    case False{}:
      Fail{"Selected scoped activity exceeds 256 events; choose a smaller physical range. No occurrence was truncated"}
    case True{}:
      include_bytes(context,count,events,occurrence,
        Activity.consume_fields(List.append(&2,String,Activity.descriptor_strings(Activity.citation(occurrence)),
          Activity.record_strings(Activity.record(occurrence))),budget))

def include(allowed: Bool,gather: Gather,occurrence: Activity.Occurrence) -> Result<&2,&2,String,Gather>:
  match allowed:
    case False{}:
      Done{gather}
    case True{}:
      Gather{context,+count,budget,events} = gather
      include_count(context,count,budget,events,occurrence,U32.is_lt(count,256))

def normalized(pair: Store.Context & Providers.Record,provider: String,scope: Scoped.Scope,
  record: Evidence.Verified,index: U32,count: U32,budget: U32,events: List<&2,Activity.Occurrence>,
  next: Gather -> Result<&2,&2,String,Gather>) -> Result<&2,&2,String,Gather>:
  (context,+event) = pair
  do Result<&2,&2,String,Gather>:
    selected : Gather <- include(Scoped.permits(scope,provider,event),Gather{context,count,budget,events},
      Activity.Occurrence{descriptor(record,index),event})
    next(selected)

def events(values: List<&2,Providers.Record>,+provider: String,+scope: Scoped.Scope,
  +record: Evidence.Verified,+index: U32,gather: Gather) -> Result<&2,&2,String,Gather>:
  match values:
    case []:
      Done{gather}
    case value <> rest:
      Gather{context,count,budget,selected} = gather
      normalized(Store.contextualize(provider,context,value),provider,scope,record,index,count,budget,selected,
        next => events(rest,provider,scope,record,U32.inc(index),next))

def selected(+record: Evidence.Verified,scope: Scoped.Scope,gather: Gather) -> Result<&2,&2,String,Gather>:
  Evidence.Verified{provider,_,_,_,_,_,values} = record
  events(values,provider,scope,record,0,gather)

def walk_next(result: Result<&2,&2,String,Gather>,next: Gather -> IO(Result<&2,&2,String,Gather>)) -> IO(Result<&2,&2,String,Gather>):
  match result:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Gather>,Fail{message})
    case Done{gather}:
      next(gather)

def walk(fuel: Nat,+db: U32,+snapshot: String,+ordinal: U32,+scope: Scoped.Scope,gather: Gather) -> IO(Result<&2,&2,String,Gather>):
  match fuel:
    case 0n:
      IO.pure(Result<&2,&2,String,Gather>,Done{gather})
    case 1n+n:
      do IO<Result<&2,&2,String,Gather>>:
        record : Evidence.Verified <- Evidence.read_record(db,snapshot,ordinal)
        walk_next(selected(record,scope,gather),next => walk(n,db,snapshot,U32.inc(ordinal),scope,next))

def cached(context: Maybe<&2,Store.Context>,db: U32,snapshot: String,start: U32,count: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Gather>):
  match context:
    case None{}:
      IO.pure(Result<&2,&2,String,Gather>,Fail{"Verified rebuild needed: incoming context checkpoint is missing or stale. No unbounded prefix replay or actor context was invented"})
    case Some{context}:
      walk(U32.to_nat(count),db,snapshot,start,scope,Gather{context,0,524288,[]})

def collect(enabled: Bool,+db: U32,+snapshot: String,+start: U32,+count: U32,header: Maintenance.Header,+scope: Scoped.Scope) -> IO(Result<&2,&2,String,Gather>):
  match enabled:
    case False{}:
      IO.pure(Result<&2,&2,String,Gather>,Done{Gather{Store.Context{"","","",""},0,524288,[]}})
    case True{}:
      Maintenance.Header{generation,extent,records,_} = header
      do IO<Result<&2,&2,String,Gather>>:
        context : Maybe<&2,Store.Context> <- Store.context_before(db,snapshot,generation,extent,records,start)
        cached(context,db,snapshot,start,count,scope)

def gathered_items(value: Gather) -> List<&2,Activity.Occurrence>:
  Gather{_,_,_,events} = value
  List.reverse(&2,Activity.Occurrence,events)

def assembled(result: Result<&2,&2,String,Gather>,provider: String,source: String,generation: String,
  snapshot: String,extent: U32,total: U32,start: U32,count: U32,size: U32,verified: U32,scope: Scoped.Scope) -> Result<&2,&2,String,Page>:
  do Result<&2,&2,String,Page>:
    value : Gather <- result
    activity : Activity.Page <- Activity.analyze(gathered_items(value))
    return Page{provider,source,generation,snapshot,extent,total,start,count,size,verified,scope,activity}

def read_header(+db: U32,+snapshot: String,+start: U32,+count: U32,+scope: Scoped.Scope,+header: Maintenance.Header) -> IO(Result<&2,&2,String,Page>):
  Maintenance.Header{generation,extent,+total,+provider} = header
  +size = Domain.bounded_count(start,count,total)
  +enabled = U32.is_gt(size,0) && Scoped.provider_allowed(scope,provider)
  do IO<Result<&2,&2,String,Page>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    gathered : Result<&2,&2,String,Gather> <- collect(enabled,db,snapshot,start,size,header,scope)
    return assembled(gathered,provider,Store.field(Store.first(rows),0n),generation,snapshot,extent,total,start,count,size,
      Bool.pick(U32,enabled,size,0),scope)

# Never infer transaction state from an SQLite error. Only a successful BEGIN
# grants ownership, and only that owned transaction is ended on Result paths.
# Fatal integrity errors terminate the worker; connection teardown rolls back.
def transaction_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> Result<&2,&2,String,Unit>:
  match result:
    case Fail{(code,_)}:
      Fail{"Activity transaction start failed (SQLite " ++ U32.show(code) ++ "); existing caller transaction was not ended"}
    case Done{_}:
      Done{Unit{}}

def transaction(+db: U32) -> IO(Result<&2,&2,String,Unit>):
  do IO<Result<&2,&2,String,Unit>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"BEGIN DEFERRED",[],0)
    return transaction_result(result)

def read_transaction(valid: Result<&2,&2,String,Unit>,+db: U32,+snapshot: String,start: U32,count: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  match valid:
    case Fail{message}:
      IO.pure(Result<&2,&2,String,Page>,Fail{message})
    case Done{_}:
      do IO<Result<&2,&2,String,Page>>:
        header : Maintenance.Header <- Maintenance.header(db,snapshot)
        result : Result<&2,&2,String,Page> <- read_header(db,snapshot,start,count,scope,header)
        Store.exec(db,"ROLLBACK",[])
        return result

def read_valid(valid: Bool,+db: U32,snapshot: String,start: U32,count: U32,scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Page>,Fail{"Activity read requires an immutable positive snapshot ID, valid frozen scope, and 1..100 physical records"})
    case True{}:
      do IO<Result<&2,&2,String,Page>>:
        owned : Result<&2,&2,String,Unit> <- transaction(db)
        read_transaction(owned,db,snapshot,start,count,scope)

def read(db: U32,+snapshot: String,start: U32,+count: U32,+scope: Scoped.Scope) -> IO(Result<&2,&2,String,Page>):
  read_valid(Evidence.positive_id(snapshot) && Scoped.valid(scope) && U32.is_gt(count,0) && U32.is_le(count,100),db,snapshot,start,count,scope)

def header(page: Page) -> String:
  Page{provider,source,generation,snapshot,extent,total,start,count,selected,+verified,scope,_} = page
  "Juice Bend · retained tool activity\nProvider: " ++ Json.quote(provider) ++ "\nSource: " ++ Json.quote(source) ++
    "\nGeneration: " ++ generation ++ "\nSnapshot: " ++ snapshot ++ "\nCaptured extent bytes: " ++ U32.show(extent) ++
    "\nTotal physical records in snapshot: " ++ U32.show(total) ++ "\nPhysical start: " ++ U32.show(start) ++
    "\nRequested records: " ++ U32.show(count) ++ "\nActual selected records: " ++ U32.show(selected) ++
    "\nVerified selected records: " ++ U32.show(verified) ++ "\nFrozen scope: " ++ scope_text(scope) ++
    Bool.pick(String,U32.is_eq(verified,0),"\nNo selected records were read.",
      "\nSelected retained raw records and immediate raw boundaries were verified. Incoming raw-derived context used its verified checkpoint seal.") ++
    "\nEarlier raw ranges and the complete snapshot were not reverified. Original source files were not read.\n\n"

def render(+page: Page) -> Result<&2,&2,String,String>:
  Page{_,_,_,_,_,_,_,_,_,_,_,activity} = page
  do Result<&2,&2,String,String>:
    body : String <- Activity.render(activity)
    +text : String = header(page) ++ body
    Activity.rendered(text,Activity.consume(text,1048575))
