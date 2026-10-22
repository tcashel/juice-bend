import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./query.bend as Query
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./maintenance.bend as Maintenance
import ./evidence.bend as Evidence
import ./transcript_format.bend as Transcript
import ./transcript_document.bend as TranscriptDoc
import ./reader_document.bend as Reader

type Scope is Data:
  Scope{provider: String, repository: String, role: String, after: String}

# Retained compatibility value for existing text-only render callers.
type Output is Data:
  Output{context: Store.Context,visible: U32,chunks: List<&2,String>,details: List<&2,String>}

# A list boxes each prepared event, keeping the scoped walk continuation small.
type ReadState is Data:
  ReadState{context: Store.Context,visible: U32,chunks: List<&2,String>,details: List<&2,String>,prepared: List<&2,TranscriptDoc.Prepared>}

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

def reference(record: Evidence.Verified,index: U32) -> String:
  Evidence.Verified{_,_,_,_,_,ordinal,_} = record
  Transcript.reference(ordinal,index)

def event_text(why: Bool,record: Evidence.Verified,index: U32,event: Providers.Record) -> String:
  match why:
    case True{}:
      Evidence.why_event(record,index,event)
    case False{}:
      Transcript.body(reference(record,index),event)

def event_details(why: Bool,+record: Evidence.Verified,+index: U32,event: Providers.Record) -> String:
  match why:
    case True{}: ""
    case False{}:
      Transcript.details(reference(record,index),event,"Citation: " ++ Evidence.citation(record,index))

def prepared_event(why: Bool,+record: Evidence.Verified,+index: U32,event: Providers.Record,
  prepared: List<&2,TranscriptDoc.Prepared>) -> List<&2,TranscriptDoc.Prepared>:
  match why:
    case True{}: prepared
    case False{}:
      Evidence.Verified{_,_,_,snapshot,_,ordinal,_} = record
      TranscriptDoc.entry(snapshot,ordinal,index,event,"Citation: " ++ Evidence.citation(record,index)) <> prepared

def include(allowed: Bool,output: ReadState,+record: Evidence.Verified,+index: U32,
  +event: Providers.Record,+why: Bool) -> ReadState:
  match allowed:
    case False{}:
      output
    case True{}:
      ReadState{context,visible,chunks,details,prepared} = output
      ReadState{context,U32.add(visible,1),event_text(why,record,index,event) <> chunks,
        event_details(why,record,index,event) <> details,prepared_event(why,record,index,event,prepared)}

def normalized(pair: Store.Context & Providers.Record,provider: String,scope: Scope,
  record: Evidence.Verified,index: U32,selected: Bool,why: Bool,visible: U32,
  chunks: List<&2,String>,details: List<&2,String>,prepared: List<&2,TranscriptDoc.Prepared>,next: ReadState -> ReadState) -> ReadState:
  (context,+event) = pair
  next(include(selected && permits(scope,provider,event),
    ReadState{context,visible,chunks,details,prepared},record,index,event,why))

def filter_events(events: List<&2,Providers.Record>,+provider: String,+scope: Scope,
  +record: Evidence.Verified,+index: U32,+selected: Bool,+why: Bool,output: ReadState) -> ReadState:
  match events:
    case []:
      output
    case event <> rest:
      ReadState{context,visible,chunks,details,prepared} = output
      normalized(Store.contextualize(provider,context,event),provider,scope,record,
        index,selected,why,visible,chunks,details,prepared,
        next => filter_events(rest,provider,scope,record,U32.add(index,1),selected,why,next))

def walk(fuel: Nat,+db: U32,+snapshot: String,+header: Maintenance.Header,
  +source: String,+scope: Scope,+start: U32,+ordinal: U32,+offset: U32,
  continued: Bool,+why: Bool,output: ReadState) -> IO(ReadState):
  match fuel:
    case 0n:
      IO.pure(ReadState,output)
    case 1n+rest:
      Maintenance.Header{+generation,+extent,_,+provider} = header
      do IO<ReadState>:
        +row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,header,ordinal,offset,continued)
        parsed : List<&2,Providers.Record> <- IO.pure(List<&2,Providers.Record>,
          Store.piece_events(String.eq(Store.field(row,6n),"1"),
            provider,Store.blob(Store.cell(row,5n))))
        record : Evidence.Verified <- IO.pure(Evidence.Verified,
          Evidence.Verified{provider,source,generation,snapshot,U32.show(extent),U32.show(ordinal),[]})
        next : ReadState <- IO.pure(ReadState,
          filter_events(parsed,provider,scope,record,0,U32.is_ge(ordinal,start),why,output))
        walk(rest,db,snapshot,header,source,scope,start,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),Maintenance.next_continued(row),why,next)

def needs_prefix(scope: Scope) -> Bool:
  Scope{_,repo,_,_} = scope
  Bool.not(String.is_empty(repo))

def selected_record(+record: Evidence.Verified,scope: Scope,why: Bool,output: ReadState) -> ReadState:
  Evidence.Verified{provider,_,_,_,_,_,events} = record
  filter_events(events,provider,scope,record,0,True{},why,output)

# Role and normalized time are record-local. Without a repository restriction,
# selected records can be validated with their immediate raw predecessor; no
# scan of earlier history is required. Available verified checkpoints supply
# inherited model/parent metadata; missing legacy metadata remains unknown.
def selected_walk(fuel: Nat,+db: U32,+snapshot: String,+scope: Scope,
  +ordinal: U32,+why: Bool,output: ReadState) -> IO(ReadState):
  match fuel:
    case 0n:
      IO.pure(ReadState,output)
    case 1n+rest:
      do IO<ReadState>:
        record : Evidence.Verified <- Evidence.read_record(db,snapshot,ordinal)
        selected_walk(rest,db,snapshot,scope,U32.add(ordinal,1),why,
          selected_record(record,scope,why,output))

def missing_context(replay: Bool,db: U32,snapshot: String,header: Maintenance.Header,
  source: String,scope: Scope,start: U32,size: U32,stop: U32,why: Bool) -> IO(ReadState):
  match replay:
    case True{}:
      walk(U32.to_nat(stop),db,snapshot,header,source,scope,start,0,0,False{},why,
        ReadState{Store.Context{"","","",""},0,[],[],[]})
    case False{}:
      selected_walk(U32.to_nat(size),db,snapshot,scope,start,why,
        ReadState{Store.Context{"","","",""},0,[],[],[]})

def repository_cache(cached: Maybe<&2,Store.Context>,db: U32,snapshot: String,
  header: Maintenance.Header,source: String,scope: Scope,start: U32,size: U32,
  stop: U32,why: Bool,replay: Bool) -> IO(ReadState):
  match cached:
    case Some{context}:
      selected_walk(U32.to_nat(size),db,snapshot,scope,start,why,ReadState{context,0,[],[],[]})
    case None{}:
      missing_context(replay,db,snapshot,header,source,scope,start,size,stop,why)

def repository_page(enabled: Bool,+db: U32,+snapshot: String,+header: Maintenance.Header,
  source: String,scope: Scope,+start: U32,size: U32,stop: U32,why: Bool,replay: Bool) -> IO(ReadState):
  match enabled:
    case False{}:
      IO.pure(ReadState,ReadState{Store.Context{"","","",""},0,[],[],[]})
    case True{}:
      Maintenance.Header{generation,extent,records,_} = header
      do IO<ReadState>:
        cached : Maybe<&2,Store.Context> <-
          Store.context_before(db,snapshot,generation,extent,records,start)
        repository_cache(cached,db,snapshot,header,source,scope,start,size,stop,why,replay)

def scope_walk(prefix: Bool,db: U32,snapshot: String,header: Maintenance.Header,
  source: String,scope: Scope,start: U32,size: U32,+stop: U32,why: Bool) -> IO(ReadState):
  repository_page(U32.is_gt(stop,0),db,snapshot,header,source,scope,start,size,stop,why,prefix)

def describe(scope: Scope) -> String:
  Scope{provider,repo,role,after} = scope
  "Provider: " ++ Store.nonempty(provider,"all") ++
    " · repository: " ++ Store.nonempty(repo,"all") ++
    " · role: " ++ Store.nonempty(role,"all") ++
    " · after: " ++ Store.nonempty(after,"all")

def legacy_rendered(output: ReadState,snapshot: String,start: U32,count: U32,
  +scope: Scope,+why: Bool) -> String:
  ReadState{_,visible,chunks,_,_} = output
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

def page_details(+visible: U32,+snapshot: String,start: U32,count: U32,+scope: Scope) -> String:
  "Juice Bend · scoped captured transcript\nSnapshot " ++ snapshot ++
    " · captured record start " ++ U32.show(start) ++ " · requested records " ++ U32.show(count) ++
    "\n" ++ describe(scope) ++ "\nVisible events in this captured range: " ++ U32.show(visible) ++
    "\nByte offsets: logical source bytes (decompressed for archives)." ++
    Bool.pick(String,needs_prefix(scope),
      "\nRepository scope uses raw-derived context bound to this immutable record. Selected records were verified; the complete snapshot was not reverified. Legacy context may require verified prefix replay.",
      "\nScope uses verified selected raw records. Earlier inherited model and parent metadata may be unavailable; other ranges were not checked.")

def transcript_rendered(output: ReadState,+snapshot: String,start: U32,count: U32,scope: Scope) -> String:
  ReadState{_,+visible,chunks,details,_} = output
  Transcript.render(Transcript.Page{visible,String.join(List.reverse(&2,String,chunks),""),
    String.join(List.reverse(&2,String,details),"")},snapshot,page_details(visible,snapshot,start,count,scope))

def prepared_page(items: List<&2,TranscriptDoc.Prepared>) -> TranscriptDoc.Prepared:
  match items:
    case []: TranscriptDoc.Prepared{0,[],[]}
    case item <> rest: TranscriptDoc.join(item,prepared_page(rest))

def document_rendered(output: ReadState,+snapshot: String,start: U32,count: U32,scope: Scope) -> Reader.Document:
  ReadState{_,visible,_,_,prepared} = output
  TranscriptDoc.page(prepared_page(List.reverse(&2,TranscriptDoc.Prepared,prepared)),snapshot,
    page_details(visible,snapshot,start,count,scope),0)

def render_mode(why: Bool,output: ReadState,snapshot: String,start: U32,count: U32,scope: Scope) -> String:
  match why:
    case True{}: legacy_rendered(output,snapshot,start,count,scope,True{})
    case False{}: transcript_rendered(output,snapshot,start,count,scope)

def rendered_state(output: ReadState,snapshot: String,start: U32,count: U32,scope: Scope,why: Bool) -> String:
  render_mode(why,output,snapshot,start,count,scope)

def rendered(output: Output,snapshot: String,start: U32,count: U32,scope: Scope,why: Bool) -> String:
  Output{context,visible,chunks,details} = output
  rendered_state(ReadState{context,visible,chunks,details,[]},snapshot,start,count,scope,why)

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
    output : ReadState <- scope_walk(needs_prefix(scope),db,snapshot,header,source,
      scope,start,size,stop,why)
    Store.exec(db,"COMMIT",[])
    return rendered_state(output,snapshot,start,count,scope,why)

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

# Transcript descriptors are collected during the same verified scoped walk;
# the original event index is passed to entry before any excluded event is lost.
def document_header(+db: U32,+snapshot: String,+start: U32,+count: U32,
  +scope: Scope,+header: Maintenance.Header,source: String) -> IO(Reader.Document):
  Maintenance.Header{_,_,records,provider} = header
  +size = Domain.bounded_count(start,U32.min(count,100),records)
  +stop = Bool.pick(U32,U32.is_eq(size,0) || Bool.not(provider_allowed(scope,provider)),0,U32.add(start,size))
  do IO<Reader.Document>:
    output : ReadState <- scope_walk(needs_prefix(scope),db,snapshot,header,source,scope,start,size,stop,False{})
    Store.exec(db,"COMMIT",[])
    return document_rendered(output,snapshot,start,count,scope)

def scoped_document(+db: U32,+snapshot: String,start: U32,count: U32,+scope: Scope) -> IO(Reader.Document):
  do IO<Reader.Document>:
    Store.checked(valid(scope),"Invalid provider, repository, role or date scope")
    Store.exec(db,"BEGIN",[])
    header : Maintenance.Header <- Maintenance.header(db,snapshot)
    source_rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    document_header(db,snapshot,start,count,scope,header,Store.field(Store.first(source_rows),0n))

def document_dispatch(unscoped: Bool,db: U32,snapshot: String,start: U32,count: U32,scope: Scope) -> IO(Reader.Document):
  match unscoped:
    case True{}: Store.page_document(db,snapshot,start,count)
    case False{}: scoped_document(db,snapshot,start,count,scope)

def page_document(db: U32,snapshot: String,start: U32,count: U32,+scope: Scope) -> IO(Reader.Document):
  document_dispatch(empty(scope),db,snapshot,start,count,scope)
