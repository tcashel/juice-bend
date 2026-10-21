import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./query.bend as Query
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./maintenance.bend as Maintenance
import ./evidence.bend as Evidence

type Scope is Data:
  Scope{provider: String, repository: String, role: String, after: String}

type Output is Data:
  Output{context: Store.Context, visible: U32, chunks: List<&2,String>}

def valid(scope: Scope) -> Bool:
  Scope{+provider,+repo,+role,+after} = scope
  (String.is_empty(provider) || Query.provider_valid(provider)) &&
    (String.is_empty(role) || Query.role_valid(role)) &&
    (String.is_empty(after) || Query.date_valid(after)) &&
    Nat.is_le(String.length(repo),4096n) && Bool.not(String.contains(repo,"\0"))

def empty(scope: Scope) -> Bool:
  Scope{provider,repo,role,after} = scope
  String.is_empty(provider) && String.is_empty(repo) &&
    String.is_empty(role) && String.is_empty(after)

# contextualize supplies the same inherited metadata and normalized timestamps
# used by capture. Domain.scope_allowed is the production function proved by
# the shared provider/repository scope laws.
def permits(scope: Scope,provider: String,event: Providers.Record) -> Bool:
  Scope{wanted_provider,wanted_repo,+wanted_role,+after} = scope
  Providers.ProviderEvent{role,_,_,_,_,_,repo,_,+stamp,_,_,_,_} = event
  Domain.scope_allowed(provider,repo,wanted_provider,wanted_repo) &&
    (String.is_empty(wanted_role) || String.eq(role,wanted_role)) &&
    (String.is_empty(after) || (Query.date_valid(String.take(stamp,10n)) &&
      String.is_ge(stamp,after)))

def event_text(why: Bool,record: Evidence.Verified,index: U32,event: Providers.Record) -> String:
  match why:
    case True{}:
      Evidence.why_event(record,index,event)
    case False{}:
      Store.display_event(event) ++ "Citation: " ++ Evidence.citation(record,index) ++ "\n\n"

def include(allowed: Bool,output: Output,record: Evidence.Verified,index: U32,
  event: Providers.Record,why: Bool) -> Output:
  match allowed:
    case False{}:
      output
    case True{}:
      Output{context,visible,chunks} = output
      Output{context,U32.add(visible,1),event_text(why,record,index,event) <> chunks}

def normalized(pair: Store.Context & Providers.Record,provider: String,scope: Scope,
  record: Evidence.Verified,index: U32,selected: Bool,why: Bool,visible: U32,
  chunks: List<&2,String>,next: Output -> Output) -> Output:
  (context,+event) = pair
  next(include(selected && permits(scope,provider,event),
    Output{context,visible,chunks},record,index,event,why))

def filter_events(events: List<&2,Providers.Record>,+provider: String,+scope: Scope,
  +record: Evidence.Verified,+index: U32,+selected: Bool,+why: Bool,output: Output) -> Output:
  match events:
    case []:
      output
    case event <> rest:
      Output{context,visible,chunks} = output
      normalized(Store.contextualize(provider,context,event),provider,scope,record,
        index,selected,why,visible,chunks,
        next => filter_events(rest,provider,scope,record,U32.add(index,1),selected,why,next))

def walk(fuel: Nat,+db: U32,+snapshot: String,+header: Maintenance.Header,
  +source: String,+scope: Scope,+start: U32,+ordinal: U32,+offset: U32,
  continued: Bool,+why: Bool,output: Output) -> IO(Output):
  match fuel:
    case 0n:
      IO.pure(Output,output)
    case 1n+rest:
      Maintenance.Header{+generation,+extent,_,+provider} = header
      do IO<Output>:
        +row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,header,ordinal,offset,continued)
        parsed : List<&2,Providers.Record> <- IO.pure(List<&2,Providers.Record>,
          Store.piece_events(String.eq(Store.field(row,6n),"1"),
            provider,Store.blob(Store.cell(row,5n))))
        record : Evidence.Verified <- IO.pure(Evidence.Verified,
          Evidence.Verified{provider,source,generation,snapshot,U32.show(extent),U32.show(ordinal),[]})
        next : Output <- IO.pure(Output,
          filter_events(parsed,provider,scope,record,0,U32.is_ge(ordinal,start),why,output))
        walk(rest,db,snapshot,header,source,scope,start,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),Maintenance.next_continued(row),why,next)

def needs_prefix(scope: Scope) -> Bool:
  Scope{_,repo,_,_} = scope
  Bool.not(String.is_empty(repo))

def selected_record(+record: Evidence.Verified,scope: Scope,why: Bool,output: Output) -> Output:
  Evidence.Verified{provider,_,_,_,_,_,events} = record
  filter_events(events,provider,scope,record,0,True{},why,output)

# Role and normalized time are record-local. Without a repository restriction,
# selected records can be validated with their immediate raw predecessor; no
# scan of earlier history is required. Available verified checkpoints supply
# inherited model/parent metadata; missing legacy metadata remains unknown.
def selected_walk(fuel: Nat,+db: U32,+snapshot: String,+scope: Scope,
  +ordinal: U32,+why: Bool,output: Output) -> IO(Output):
  match fuel:
    case 0n:
      IO.pure(Output,output)
    case 1n+rest:
      do IO<Output>:
        record : Evidence.Verified <- Evidence.read_record(db,snapshot,ordinal)
        selected_walk(rest,db,snapshot,scope,U32.add(ordinal,1),why,
          selected_record(record,scope,why,output))

def missing_context(replay: Bool,db: U32,snapshot: String,header: Maintenance.Header,
  source: String,scope: Scope,start: U32,size: U32,stop: U32,why: Bool) -> IO(Output):
  match replay:
    case True{}:
      walk(U32.to_nat(stop),db,snapshot,header,source,scope,start,0,0,False{},why,
        Output{Store.Context{"","","",""},0,[]})
    case False{}:
      selected_walk(U32.to_nat(size),db,snapshot,scope,start,why,
        Output{Store.Context{"","","",""},0,[]})

def repository_cache(cached: Maybe<&2,Store.Context>,db: U32,snapshot: String,
  header: Maintenance.Header,source: String,scope: Scope,start: U32,size: U32,
  stop: U32,why: Bool,replay: Bool) -> IO(Output):
  match cached:
    case Some{context}:
      selected_walk(U32.to_nat(size),db,snapshot,scope,start,why,Output{context,0,[]})
    case None{}:
      missing_context(replay,db,snapshot,header,source,scope,start,size,stop,why)

def repository_page(enabled: Bool,+db: U32,+snapshot: String,+header: Maintenance.Header,
  source: String,scope: Scope,+start: U32,size: U32,stop: U32,why: Bool,replay: Bool) -> IO(Output):
  match enabled:
    case False{}:
      IO.pure(Output,Output{Store.Context{"","","",""},0,[]})
    case True{}:
      Maintenance.Header{generation,extent,records,_} = header
      do IO<Output>:
        cached : Maybe<&2,Store.Context> <-
          Store.context_before(db,snapshot,generation,extent,records,start)
        repository_cache(cached,db,snapshot,header,source,scope,start,size,stop,why,replay)

def scope_walk(prefix: Bool,db: U32,snapshot: String,header: Maintenance.Header,
  source: String,scope: Scope,start: U32,size: U32,+stop: U32,why: Bool) -> IO(Output):
  repository_page(U32.is_gt(stop,0),db,snapshot,header,source,scope,start,size,stop,why,prefix)

def describe(scope: Scope) -> String:
  Scope{provider,repo,role,after} = scope
  "Provider: " ++ Store.nonempty(provider,"all") ++
    " · repository: " ++ Store.nonempty(repo,"all") ++
    " · role: " ++ Store.nonempty(role,"all") ++
    " · after: " ++ Store.nonempty(after,"all")

def rendered(output: Output,snapshot: String,start: U32,count: U32,
  +scope: Scope,+why: Bool) -> String:
  Output{_,visible,chunks} = output
  "Juice Bend · scoped captured " ++ Bool.pick(String,why,"Why evidence","transcript") ++
    "\nSnapshot " ++ snapshot ++ " · captured record start " ++ U32.show(start) ++
    " · requested records " ++ U32.show(count) ++ "\n" ++ describe(scope) ++
    "\nVisible events in this captured range: " ++ U32.show(visible) ++
    "\nByte offsets: logical source bytes (decompressed for archives)." ++
    Bool.pick(String,needs_prefix(scope),
      "\nRepository scope uses raw-derived context bound to this immutable record. Selected records were verified; the complete snapshot was not reverified. Legacy context may require verified prefix replay.",
      "\nScope uses verified selected raw records. Earlier inherited model and parent metadata may be unavailable; other ranges were not checked.") ++
    Bool.pick(String,why,"\nRationale: captured statements only; no generated or inferred explanation.","") ++
    "\n\n" ++ String.join(List.reverse(&2,String,chunks),"")

def provider_allowed(scope: Scope,provider: String) -> Bool:
  Scope{wanted_provider,_,_,_} = scope
  Domain.scope_allowed(provider,"",wanted_provider,"")

def scoped_header(+db: U32,+snapshot: String,+start: U32,+count: U32,
  +scope: Scope,+why: Bool,+header: Maintenance.Header,source: String) -> IO(String):
  Maintenance.Header{_,_,records,provider} = header
  +size = Domain.bounded_count(start,U32.min(count,Bool.pick(U32,why,20,100)),records)
  +stop = Bool.pick(U32,U32.is_eq(size,0) || Bool.not(provider_allowed(scope,provider)),
    0,U32.add(start,size))
  do IO<String>:
    output : Output <- scope_walk(needs_prefix(scope),db,snapshot,header,source,
      scope,start,size,stop,why)
    Store.exec(db,"COMMIT",[])
    return rendered(output,snapshot,start,count,scope,why)

def scoped(+db: U32,+snapshot: String,start: U32,count: U32,+scope: Scope,why: Bool) -> IO(String):
  do IO<String>:
    Store.checked(valid(scope),"Invalid provider, repository, role or date scope")
    Store.exec(db,"BEGIN",[])
    header : Maintenance.Header <- Maintenance.header(db,snapshot)
    source_rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    scoped_header(db,snapshot,start,count,scope,why,header,Store.field(Store.first(source_rows),0n))

def dispatch(unscoped: Bool,why: Bool,db: U32,snapshot: String,start: U32,count: U32,scope: Scope) -> IO(String):
  match unscoped:
    case True{}:
      match why:
        case True{}:
          Evidence.why(db,snapshot,start,count)
        case False{}:
          Store.page(db,snapshot,start,count)
    case False{}:
      scoped(db,snapshot,start,count,scope,why)

def page(db: U32,snapshot: String,start: U32,count: U32,+scope: Scope,why: Bool) -> IO(String):
  dispatch(empty(scope),why,db,snapshot,start,count,scope)
