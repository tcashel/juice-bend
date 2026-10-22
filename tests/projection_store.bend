import Base
import ../src/projection_store.bend as Projection
import ../src/store.bend as Store
import ../src/maintenance.bend as Maintenance
import ../src/providers.bend as Providers
import ../src/domain.bend as Domain
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ./publication_crash.bend as Check

# The isolated engine is exercised against genuine retained Store captures.
# All source fixtures and child processes stay in scripts/test's private root.
# Parsing and state replacement are the production Store functions.
def into_store(context: Projection.Context) -> Store.Context:
  Projection.Context{repository,session,model,parent} = context
  Store.Context{repository,session,model,parent}

def from_store(context: Store.Context) -> Projection.Context:
  Store.Context{repository,session,model,parent} = context
  Projection.Context{repository,session,model,parent}

def normalize_next(projected: Store.Context & Providers.Record,
  next: Store.Context -> Providers.Record -> (Projection.Context & List<&2,Providers.Record>)) ->
  Projection.Context & List<&2,Providers.Record>:
  (context,event) = projected
  next(context,event)

def normalize_rows(events: List<&2,Providers.Record>,+provider: String,
  context: Store.Context,done: List<&2,Providers.Record>) ->
  Projection.Context & List<&2,Providers.Record>:
  match events:
    case []:
      (from_store(context),List.reverse(&2,Providers.Record,done))
    case event <> rest:
      normalize_next(Store.contextualize(provider,context,event),next => projected =>
        normalize_rows(rest,provider,next,projected <> done))

def normalize(+provider: String,row: List<&2,Sql.Cell>,context: Projection.Context) ->
  Projection.Context & List<&2,Providers.Record>:
  +raw = row
  normalize_rows(Store.piece_events(String.eq(Store.field(raw,6n),"1"),provider,
    Store.blob(Store.cell(raw,5n))),provider,into_store(context),[])

def record_count(header: Maintenance.Header) -> U32:
  Maintenance.Header{_,_,count,_} = header
  count

def replay(fuel: Nat,+db: U32,+snapshot: String,+header: Maintenance.Header,
  +ordinal: U32,+offset: U32,continued: Bool,writer: Projection.Writer) -> IO(Projection.Writer):
  match fuel:
    case 0n:
      do IO<Projection.Writer>:
        Maintenance.complete(header,offset)
        return writer
    case 1n+rest:
      Maintenance.Header{_,_,_,provider} = header
      do IO<Projection.Writer>:
        +row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,header,ordinal,offset,continued)
        raw_id : String <- Check.scalar(db,"SELECT raw FROM records WHERE snapshot=? AND ordinal=?",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}])
        next : Projection.Writer <- Projection.put(db,writer,raw_id,context => normalize(provider,row,context))
        replay(rest,db,snapshot,header,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),Maintenance.next_continued(row),next)

def full_writer(+db: U32,+snapshot: String,version: String) -> IO(Projection.Writer):
  do IO<Projection.Writer>:
    +header : Maintenance.Header <- Maintenance.header(db,snapshot)
    Maintenance.verify_header(db,snapshot,header)
    writer : Projection.Writer <- Projection.begin(db,snapshot,version)
    count : U32 = record_count(header)
    replay(U32.to_nat(count),db,snapshot,header,0,0,False{},writer)

def full(+db: U32,snapshot: String,version: String) -> IO(Unit):
  do IO<Unit>:
    writer : Projection.Writer <- full_writer(db,snapshot,version)
    Projection.seal(db,writer)

def build(+db: U32,snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    full(db,snapshot,Store.projection_version())
    Store.exec(db,"COMMIT",[])

def verify(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    +header : Maintenance.Header <- Maintenance.header(db,snapshot)
    Maintenance.verify_header(db,snapshot,header)
    prefix : Projection.VerifiedPrefix <- Projection.verify(db,snapshot)
    Store.exec(db,"COMMIT",[])

def append(+db: U32,+previous: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    +header : Maintenance.Header <- Maintenance.header(db,snapshot)
    Maintenance.verify_header(db,snapshot,header)
    +old_header : Maintenance.Header <- Maintenance.header(db,previous)
    Maintenance.verify_header(db,previous,old_header)
    prefix : Projection.VerifiedPrefix <- Projection.verify(db,previous)
    writer : Projection.Writer <- Projection.append(db,snapshot,Store.projection_version(),prefix)
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT checkpoint_ordinal,checkpoint FROM snapshots WHERE id=?",[Sql.Cell.Integer{previous}],1)
    +ordinal : U32 = Store.number(Store.field(Store.first(rows),0n))
    +offset : U32 = Store.number(Store.field(Store.first(rows),1n))
    count : U32 = record_count(header)
    complete : Projection.Writer <- replay(U32.to_nat(U32.sub(count,ordinal)),db,snapshot,
      header,ordinal,offset,False{},writer)
    Projection.seal(db,complete)
    Store.exec(db,"COMMIT",[])

def context_is(context: Projection.Context,repository: String,session: String,model: String) -> Bool:
  Projection.Context{actual_repository,actual_session,actual_model,parent} = context
  String.eq(repository,actual_repository) && String.eq(session,actual_session) &&
    String.eq(model,actual_model) && String.is_empty(parent)

def context(+db: U32,snapshot: String,ordinal: U32,model: String,label: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    result : Projection.Context <- Projection.context_before(db,snapshot,ordinal)
    Store.exec(db,"COMMIT",[])
    Check.assert(context_is(result,"/synthetic/projection-v3","projection-v3",model),label)

def message(body: String) -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(body) ++ "}]}}\n"

def model(name: String) -> String:
  "{\"type\":\"turn_context\",\"payload\":{\"model\":" ++ Json.quote(name) ++ "}}\n"

def fixture() -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"projection-v3\",\"cwd\":\"/synthetic/projection-v3\"}}\n" ++
    model("recorded-model") ++ message("inherited model Café 🍋") ++
    "{\"type\":\"turn_context\",\"payload\":{}}\n" ++ message("explicit model clear") ++
    String.repeat(message("stable repeated occurrence"),67n)

def addition() -> String:
  model("appended-model") ++ message("new tail result")

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  Check.equal_scalar(db,sql,args,expected,label)

def failed(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = result
  Check.assert(U32.is_ne(code,0) && String.contains(out ++ err,"Shared projection integrity"),label)

def child_failure(self: String,mode: String,path: String,snapshot: String,other: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[mode,path,snapshot,other],"",8192,30000))
    failed(result,label)

def tables() -> List<&2,String>:
  List.append(&2,String,Check.tables(),List.append(&2,String,Projection.tables(),["sqlite_sequence"]))

# The expected serialization is written independently of Projection.encoded,
# event_cells and the streaming implementation. Domain.digest is the one-shot
# byte oracle; its SHA implementation has separate published-vector tests.
def framed_row(index: U32,body: String,tool: String) -> List<&2,Sql.Cell>:
  [Sql.Cell.Integer{U32.show(index)},Sql.Cell.Text{"role"},Sql.Cell.Text{body},
   Sql.Cell.Text{tool},Sql.Cell.Text{"call"},Sql.Cell.Text{"args"},Sql.Cell.Text{"result"},
   Sql.Cell.Text{"repository"},Sql.Cell.Text{"session"},Sql.Cell.Text{"timestamp"},
   Sql.Cell.Text{"model"},Sql.Cell.Text{"usage"},Sql.Cell.Text{"parent"},Sql.Cell.Text{"coverage"}]

# Arguments are already independently escaped JSON string contents.
def framed_event(index: String,body: String,tool: String) -> String:
  "event|integer:\"" ++ index ++ "\":text:\"role\":text:\"" ++ body ++
    "\":text:\"" ++ tool ++ "\":text:\"call\":text:\"args\":text:\"result\":" ++
    "text:\"repository\":text:\"session\":text:\"timestamp\":text:\"model\":" ++
    "text:\"usage\":text:\"parent\":text:\"coverage\":|"

def framed_payload(events: String,count: String) -> String:
  "shared-projection-v2|payload|" ++ events ++ "count|integer:\"" ++ count ++ "\":"

def one_payload(body: String,tool: String) -> IO(String):
  do IO<String>:
    initial : Domain.HashContext <- Projection.payload_start()
    event : Domain.HashContext <- Projection.event_row(framed_row(0,body,tool),0,initial)
    Projection.payload_finish(event,1)

def payload_vector(body: String,tool: String,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : String <- one_payload(body,tool)
    Check.assert(String.eq(actual,Domain.digest(Domain.encode(expected))),label)

def payload_length(+length: Nat) -> IO(Unit):
  +base = framed_payload(framed_event("0","",""),"1")
  +padding = String.repeat("x",Nat.sub(length,List.length(&2,U32,Domain.encode(base))))
  +expected = framed_payload(framed_event("0",padding,""),"1")
  do IO<Unit>:
    Check.assert(Nat.is_eq(List.length(&2,U32,Domain.encode(expected)),length),
      "framed payload fixture has exact byte length " ++ Nat.show(length))
    payload_vector(padding,"",expected,
      "production streaming payload matches one-shot bytes at length " ++ Nat.show(length))

def payload_framing() -> IO(Unit):
  do IO<Unit>:
    Check.assert(String.eq(Projection.format(),"shared-projection-v2"),
      "two-digest engine uses an explicit incompatible v2 format")
    empty : Domain.HashContext <- Projection.payload_start()
    empty_hash : String <- Projection.payload_finish(empty,0)
    Check.assert(String.eq(empty_hash,Domain.digest(Domain.encode(framed_payload("","0")))),
      "zero-event payload hashes its exact domain and final integer count")
    payload_vector("","",framed_payload(framed_event("0","",""),"1"),
      "empty field payload keeps all thirteen typed text positions")
    payload_vector("Café 🍋\0\"\\:\n|","工具",
      framed_payload(framed_event("0","Café 🍋\\u0000\\\"\\\\:\\u000a|","工具"),"1"),
      "Unicode UTF8 and NUL quote slash colon pipe framing match exact bytes")
    +left : String <- one_payload("a","bc")
    +right : String <- one_payload("ab","c")
    Check.assert(Bool.not(String.eq(left,right)),
      "adjacent text field boundaries cannot collapse equal concatenated text")
    payload_vector("a","bc",framed_payload(framed_event("0","a","bc"),"1"),
      "first adjacent field split has its independent framed digest")
    payload_vector("ab","c",framed_payload(framed_event("0","ab","c"),"1"),
      "second adjacent field split has its independent framed digest")
    initial : Domain.HashContext <- Projection.payload_start()
    first : Domain.HashContext <- Projection.event_row(framed_row(0,"first","one"),0,initial)
    +second : Domain.HashContext <- Projection.event_row(framed_row(1,"second","two"),1,first)
    +pair : String <- Projection.payload_finish(second,2)
    wrong_count : String <- Projection.payload_finish(second,1)
    Check.assert(String.eq(pair,Domain.digest(Domain.encode(framed_payload(
      framed_event("0","first","one") ++ framed_event("1","second","two"),"2")))),
      "multiple events stream in exact ordinal order with one final count")
    Check.assert(Bool.not(String.eq(pair,wrong_count)),"final event count is part of payload bytes")
    reverse_initial : Domain.HashContext <- Projection.payload_start()
    reverse_first : Domain.HashContext <- Projection.event_row(framed_row(0,"second","two"),0,reverse_initial)
    reverse_second : Domain.HashContext <- Projection.event_row(framed_row(1,"first","one"),1,reverse_first)
    reverse_hash : String <- Projection.payload_finish(reverse_second,2)
    Check.assert(Bool.not(String.eq(pair,reverse_hash)),"swapping payload order changes the stream digest")
    payload_length(311n)
    payload_length(312n)
    payload_length(319n)
    payload_length(320n)
    payload_length(321n)
    payload_length(383n)
    payload_length(384n)
    payload_length(385n)
    Check.assert(Projection.payload_room(0,4294967295n),"payload byte guard accepts exact U32 capacity")
    Check.assert(Projection.payload_room(4294967295,0n),"full payload permits a zero-byte addition")
    Check.assert(Bool.not(Projection.payload_room(4294967295,1n)),"full payload refuses one more byte")
    Check.assert(Projection.payload_room(4294967292,3n),"payload byte guard accepts the final three bytes")
    Check.assert(Bool.not(Projection.payload_room(4294967292,4n)),"payload byte guard rejects wraparound by one")
    Check.assert(Bool.not(Projection.payload_room(0,Nat.add(4294967295n,1n))),"payload guard rejects Nat length before narrowing to U32")

type RecordInput is Data:
  RecordInput{header: Projection.Header,run: String,parser: String,raw: Projection.Raw,
    incoming: Projection.Context,outgoing: Projection.Context,previous: String,count: U32,
    payload: String,label: String}

def record_header(source: String,generation: String,provider: String,locator: String) -> Projection.Header:
  Projection.Header{"9",source,generation,provider,locator,116,4,116,4,True{},17}

def record_digest(input: RecordInput) -> IO(String):
  RecordInput{h,run,parser,raw,incoming,outgoing,previous,count,payload,_} = input
  Projection.record_hash(h,run,parser,raw,incoming,outgoing,previous,count,payload)

def changed_record(inputs: List<&2,RecordInput>,+expected: String) -> IO(Unit):
  match inputs:
    case []:
      IO.pure(Unit,Unit{})
    case +input <> rest:
      RecordInput{_,_,_,_,_,_,_,_,_,label} = input
      do IO<Unit>:
        actual : String <- record_digest(input)
        Check.assert(Bool.not(String.eq(actual,expected)),"combined record digest binds " ++ label)
        changed_record(rest,expected)

def record_framing() -> IO(Unit):
  +h = record_header("7","11","claude","/synthetic/source")
  +raw = {Projection.Raw{"101","11",3,99,17,"raw-sha",True{},False{}} : Projection.Raw}
  +incoming = {Projection.Context{"/in","in-session","",""} : Projection.Context}
  +outgoing = {Projection.Context{"/out","out-session","model","parent"} : Projection.Context}
  +expected = Domain.digest(Domain.encode(
    "shared-projection-v2|record|integer:\"41\":text:\"parser-v2\":integer:\"7\":integer:\"11\":" ++
    "text:\"claude\":text:\"/synthetic/source\":integer:\"101\":integer:\"11\":integer:\"3\":" ++
    "integer:\"99\":integer:\"17\":text:\"raw-sha\":integer:\"1\":integer:\"0\":" ++
    "text:\"/in\":text:\"in-session\":text:\"\":text:\"\":text:\"/out\":text:\"out-session\":" ++
    "text:\"model\":text:\"parent\":text:\"previous\":integer:\"2\":text:\"payload-sha\":"))
  do IO<Unit>:
    actual : String <- Projection.record_hash(h,"41","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha")
    Check.assert(String.eq(actual,expected),"combined record digest matches an independently framed complete preimage")
    changed_record([
      RecordInput{record_header("8","11","claude","/synthetic/source"),"41","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha","source"},
      RecordInput{record_header("7","12","claude","/synthetic/source"),"41","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha","generation"},
      RecordInput{record_header("7","11","codex","/synthetic/source"),"41","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha","provider"},
      RecordInput{record_header("7","11","claude","/synthetic/other"),"41","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha","locator"},
      RecordInput{h,"42","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha","run"},
      RecordInput{h,"41","parser-other",raw,incoming,outgoing,"previous",2,"payload-sha","parser"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"102","11",3,99,17,"raw-sha",True{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw identity"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","12",3,99,17,"raw-sha",True{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw generation"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","11",4,99,17,"raw-sha",True{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw ordinal"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","11",3,100,17,"raw-sha",True{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw offset"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","11",3,99,18,"raw-sha",True{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw byte length"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","11",3,99,17,"changed",True{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw digest"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","11",3,99,17,"raw-sha",False{},False{}},incoming,outgoing,"previous",2,"payload-sha","raw completeness"},
      RecordInput{h,"41","parser-v2",Projection.Raw{"101","11",3,99,17,"raw-sha",True{},True{}},incoming,outgoing,"previous",2,"payload-sha","raw oversized flag"},
      RecordInput{h,"41","parser-v2",raw,Projection.Context{"/changed","in-session","",""},outgoing,"previous",2,"payload-sha","incoming repository"},
      RecordInput{h,"41","parser-v2",raw,Projection.Context{"/in","changed","",""},outgoing,"previous",2,"payload-sha","incoming session"},
      RecordInput{h,"41","parser-v2",raw,Projection.Context{"/in","in-session","changed",""},outgoing,"previous",2,"payload-sha","incoming model"},
      RecordInput{h,"41","parser-v2",raw,Projection.Context{"/in","in-session","","changed"},outgoing,"previous",2,"payload-sha","incoming parent"},
      RecordInput{h,"41","parser-v2",raw,incoming,Projection.Context{"/changed","out-session","model","parent"},"previous",2,"payload-sha","outgoing repository"},
      RecordInput{h,"41","parser-v2",raw,incoming,Projection.Context{"/out","changed","model","parent"},"previous",2,"payload-sha","outgoing session"},
      RecordInput{h,"41","parser-v2",raw,incoming,Projection.Context{"/out","out-session","changed","parent"},"previous",2,"payload-sha","outgoing model"},
      RecordInput{h,"41","parser-v2",raw,incoming,Projection.Context{"/out","out-session","model","changed"},"previous",2,"payload-sha","outgoing parent"},
      RecordInput{h,"41","parser-v2",raw,incoming,outgoing,"changed",2,"payload-sha","previous chain"},
      RecordInput{h,"41","parser-v2",raw,incoming,outgoing,"previous",3,"payload-sha","event count"},
      RecordInput{h,"41","parser-v2",raw,incoming,outgoing,"previous",2,"changed","payload digest"}],expected)
    reused : String <- Projection.record_hash(
      Projection.Header{"100","7","11","claude","/synthetic/source",999,99,888,88,False{},999},
      "41","parser-v2",raw,incoming,outgoing,"previous",2,"payload-sha")
    Check.assert(String.eq(reused,expected),
      "record digest omits snapshot publication and connection metadata for immutable prefix reuse")

def projected() -> String:
  "SELECT r.ordinal,e.event,e.role,e.body,e.tool,e.call_id,e.arguments,e.result,e.repository,e.session,e.timestamp,e.model,e.usage,e.parent,e.coverage FROM projection_v3_snapshots m JOIN records i ON i.snapshot=m.snapshot JOIN projection_v3_records r ON r.run=m.run AND r.raw=i.raw JOIN projection_v3_events e ON e.record=r.id WHERE m.snapshot=?"

def legacy() -> String:
  "SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=?"

def equivalent(+db: U32,+snapshot: String,+expected: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM (" ++ projected() ++ " EXCEPT " ++ legacy() ++ ")",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{expected}],"0",label ++ " actual fields have no extras")
    scalar(db,"SELECT count(*) FROM (" ++ legacy() ++ " EXCEPT " ++ projected() ++ ")",
      [Sql.Cell.Integer{expected},Sql.Cell.Integer{snapshot}],"0",label ++ " every expected typed field is present")

def count(db: U32,table: String,expected: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM " ++ table,[],expected,label)

def schema_boundary(+db: U32) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM sqlite_master WHERE type='table' AND name LIKE 'projection_v3_%'",[],"0",
      "ordinary Store.open never enables experimental projection storage")
    Projection.schema(db)
    Projection.schema(db)
    scalar(db,"SELECT count(*) FROM sqlite_master WHERE type='table' AND name LIKE 'projection_v3_%'",[],"4",
      "explicit experimental schema is idempotent and contains four tables")
    scalar(db,"PRAGMA user_version",[],"3","experimental schema preserves application schema version")

def exact_append() -> IO(Unit):
  +path = {".build/projection-append.sqlite" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    schema_boundary(db)
    Store.write_text("projection-append.jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex","projection-append.jsonl")
    build(db,old)
    verify(db,old)
    scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{old}],"72","fixture has 72 physical captured records")
    count(db,"projection_v3_runs","1","initial full projection creates one parser run")
    count(db,"projection_v3_records","72","initial full projection owns one context per raw occurrence")
    count(db,"projection_v3_events","72","initial event count matches independent fixture")
    scalar(db,"SELECT count(*) FROM projection_v3_records WHERE context_digest<>chain",[],"0",
      "stored context and chain columns carry one identical combined record digest")
    scalar(db,"SELECT count(*) FROM projection_v3_runs WHERE version='shared-projection-v2'",[],"1",
      "new parser run stores the explicit v2 digest format")
    context(db,old,2,"recorded-model","context inherits recorded model before message")
    context(db,old,4,"","explicit absent Codex model clears prior model")
    context(db,old,71,"","cleared model persists across many complete records")
    equivalent(db,old,old,"initial production parser projection")
    +baseline : Check.Baseline <- Check.capture_baseline(db,old)
    Store.exec(db,"CREATE TABLE original_projection_records AS SELECT * FROM projection_v3_records",[])
    Store.exec(db,"CREATE TABLE original_projection_events AS SELECT * FROM projection_v3_events",[])
    Store.write_text("projection-append.jsonl","a",addition())
    +latest : String <- Store.import_file(db,"codex","projection-append.jsonl")
    append(db,old,latest)
    verify(db,latest)
    verify(db,old)
    count(db,"projection_v3_runs","1","exact append reuses the original parser run")
    count(db,"projection_v3_records","74","exact append stores only two new record projections")
    count(db,"projection_v3_events","74","exact append stores only two new event payloads")
    scalar(db,"SELECT count(*) FROM (SELECT * FROM original_projection_records EXCEPT SELECT * FROM projection_v3_records)",[],"0",
      "all original projection IDs and context cells remain immutable")
    scalar(db,"SELECT count(*) FROM (SELECT * FROM original_projection_events EXCEPT SELECT * FROM projection_v3_events)",[],"0",
      "all original event IDs and payload cells remain immutable")
    scalar(db,"SELECT count(*) FROM projection_v3_records WHERE raw IN (SELECT raw FROM records WHERE snapshot=?)",
      [Sql.Cell.Integer{old}],"72","repeated identical text remains 72 distinct captured occurrences")
    context(db,latest,73,"appended-model","appended model replacement reaches its following message")
    context(db,old,71,"","old context remains pinned after new model appears")
    Check.pinned(db,baseline,"shared append")
    equivalent(db,latest,latest,"incremental projection equals current production import")
    Store.write_text("projection-independent.jsonl","w",fixture() ++ addition())
    +fresh : String <- Store.import_file(db,"codex","projection-independent.jsonl")
    build(db,fresh)
    equivalent(db,latest,fresh,"incremental projection equals independent fresh full parsing")
    Store.exec(db,"CREATE TABLE latest_manifest_before AS SELECT * FROM projection_v3_snapshots WHERE snapshot=?",[Sql.Cell.Integer{latest}])
    build(db,old)
    verify(db,old)
    verify(db,latest)
    scalar(db,"SELECT count(*) FROM (SELECT * FROM latest_manifest_before EXCEPT SELECT * FROM projection_v3_snapshots)",[],"0",
      "historical rebuild cannot change newer snapshot manifest")
    scalar(db,"SELECT count(*) FROM projection_v3_snapshots a JOIN projection_v3_snapshots b ON a.run=b.run WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],"0","rebuild publishes a new run only for selected historical snapshot")
    equivalent(db,old,old,"historical rebuild reparses verified retained bytes")
    equivalent(db,latest,fresh,"newer shared projection survives historical rebuild")
    Check.pinned(db,baseline,"historical shared rebuild")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    full(db,old,"historical-parser-v0")
    Store.exec(db,"COMMIT",[])
    verify(db,old)
    context(db,old,4,"","archived parser tag preserves readable historical context")
    Check.check_integrity(db,"shared append and rebuild")
    IO.try(Unit,Sql.close(db))

def partial_tail() -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"unfinished newline boundary\"}]}}"

def partial_replacement() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/projection-partial.sqlite")
    Projection.schema(db)
    Store.write_text("projection-partial.jsonl","w",fixture() ++ partial_tail())
    +old : String <- Store.import_file(db,"codex","projection-partial.jsonl")
    build(db,old)
    +baseline : Check.Baseline <- Check.capture_baseline(db,old)
    Store.write_text("projection-partial.jsonl","a","\n" ++ addition())
    +latest : String <- Store.import_file(db,"codex","projection-partial.jsonl")
    append(db,old,latest)
    verify(db,old)
    verify(db,latest)
    count(db,"projection_v3_runs","1","partial-tail completion shares one parser run")
    count(db,"projection_v3_records","76","partial-tail completion retains old tail plus three new projections")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],"72","only complete-record prefix is shared across tail completion")
    scalar(db,"SELECT count(*) FROM projection_v3_records WHERE ordinal=72",[],"2",
      "old and completed tails coexist at one generation ordinal with distinct raw identities")
    context(db,old,72,"","old partial-tail context stays pinned")
    context(db,latest,74,"appended-model","completed tail resumes later model context correctly")
    equivalent(db,latest,latest,"completed tail projection matches full snapshot parsing")
    Check.pinned(db,baseline,"partial-tail replacement")
    IO.try(Unit,Sql.close(db))

def stateful_partial(+name: String,+tail: String,+expected: String) -> IO(Unit):
  +source = "projection-stateful-" ++ name ++ ".jsonl"
  do IO<Unit>:
    +db : U32 <- Store.open(".build/projection-stateful-" ++ name ++ ".sqlite")
    Projection.schema(db)
    Store.write_text(source,"w",fixture() ++ model("before-tail-model") ++ tail)
    +old : String <- Store.import_file(db,"codex",source)
    build(db,old)
    context(db,old,73,"before-tail-model",name ++ " unfinished tail begins with complete-prefix context")
    scalar(db,"SELECT p.out_model FROM projection_v3_records p JOIN projection_v3_snapshots m ON m.run=p.run JOIN records i ON i.snapshot=m.snapshot AND i.raw=p.raw WHERE m.snapshot=? AND i.ordinal=73",
      [Sql.Cell.Integer{old}],expected,name ++ " unfinished valid JSON already has its own terminal model state")
    Store.write_text(source,"a","\n" ++ message("after stateful tail"))
    +latest : String <- Store.import_file(db,"codex",source)
    append(db,old,latest)
    verify(db,old)
    verify(db,latest)
    context(db,latest,73,"before-tail-model",name ++ " replacement resumes checkpoint context instead of old terminal context")
    context(db,latest,74,expected,name ++ " completed tail changes model for following message")
    context(db,old,73,"before-tail-model",name ++ " old unfinished tail context remains pinned")
    scalar(db,"SELECT p.out_model FROM projection_v3_records p JOIN projection_v3_snapshots m ON m.run=p.run JOIN records i ON i.snapshot=m.snapshot AND i.raw=p.raw WHERE m.snapshot=? AND i.ordinal=73",
      [Sql.Cell.Integer{old}],expected,name ++ " old terminal context remains immutable after append")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],"73",name ++ " stateful partial tail is excluded from shared prefix")
    equivalent(db,latest,latest,name ++ " stateful partial-tail replay matches full parsing")
    IO.try(Unit,Sql.close(db))

def zero_events() -> IO(Unit):
  +empty = {"{\"type\":\"assistant\",\"message\":{\"content\":[]}}\n" : String}
  +text = {"{\"type\":\"user\",\"message\":{\"content\":\"after empty content\"}}\n" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(".build/projection-zero.sqlite")
    Projection.schema(db)
    Store.write_text("projection-empty.jsonl","w","")
    +empty_snapshot : String <- Store.import_file(db,"claude","projection-empty.jsonl")
    build(db,empty_snapshot)
    verify(db,empty_snapshot)
    count(db,"projection_v3_records","0","empty accepted snapshot seals without invented raw records")
    count(db,"projection_v3_events","0","empty accepted snapshot seals without invented events")
    Store.write_text("projection-zero.jsonl","w",empty)
    +old : String <- Store.import_file(db,"claude","projection-zero.jsonl")
    build(db,old)
    verify(db,old)
    count(db,"projection_v3_records","1","zero-event raw record retains its context and chain entry")
    count(db,"projection_v3_events","0","empty Claude content projects no invented display event")
    scalar(db,"SELECT events_digest FROM projection_v3_records WHERE events=0",[],
      Domain.digest(Domain.encode(framed_payload("","0"))),
      "persisted zero-event payload has the independent exact-byte digest")
    Store.write_text("projection-zero.jsonl","a",text)
    +latest : String <- Store.import_file(db,"claude","projection-zero.jsonl")
    append(db,old,latest)
    verify(db,latest)
    count(db,"projection_v3_records","2","append resumes through zero-event record")
    count(db,"projection_v3_events","1","append adds one independently expected display event")
    equivalent(db,latest,latest,"zero-event prefix append preserves production parser result")
    IO.try(Unit,Sql.close(db))

def fragment_checkpoint() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/projection-fragment.sqlite")
    Projection.schema(db)
    Store.write_text("projection-fragment.jsonl","w",fixture() ++ String.repeat("x",262144n))
    +old : String <- Store.import_file(db,"codex","projection-fragment.jsonl")
    build(db,old)
    Store.write_text("projection-fragment.jsonl","a","\n" ++ message("after oversized physical line"))
    +latest : String <- Store.import_file(db,"codex","projection-fragment.jsonl")
    append(db,old,latest)
    verify(db,old)
    verify(db,latest)
    count(db,"projection_v3_records","76","oversized incomplete tail is reparsed from complete-record checkpoint")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],"72","full-sized unfinished fragment is never a reusable line checkpoint")
    scalar(db,"SELECT count(*) FROM (" ++ projected() ++ ") WHERE coverage='oversized_record_fragment'",
      [Sql.Cell.Integer{latest}],"2","both fragments preserve unsupported oversized coverage")
    context(db,latest,74,"","newline ending an oversized line restores ordinary following-record context")
    equivalent(db,latest,latest,"oversized continuation projection equals full parsing")
    IO.try(Unit,Sql.close(db))

def large_id_sequences(names: List<&2,String>,+db: U32) -> IO(Unit):
  match names:
    case []:
      IO.pure(Unit,Unit{})
    case name <> rest:
      do IO<Unit>:
        Store.exec(db,"INSERT INTO sqlite_sequence(name,seq) VALUES(?,9007199254740992)",[Sql.Cell.Text{name}])
        large_id_sequences(rest,db)

def exact_identifiers() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/projection-exact-ids.sqlite")
    Projection.schema(db)
    large_id_sequences(["projection_v3_runs","projection_v3_records","projection_v3_events"],db)
    Store.write_text("projection-exact-ids.jsonl","w",message("exact identity beyond floating point"))
    +snapshot : String <- Store.import_file(db,"codex","projection-exact-ids.jsonl")
    build(db,snapshot)
    verify(db,snapshot)
    scalar(db,"SELECT id FROM projection_v3_runs",[],"9007199254740993","parser run identity remains exact above 2^53")
    scalar(db,"SELECT id FROM projection_v3_records",[],"9007199254740993","raw projection identity remains exact above 2^53")
    scalar(db,"SELECT id FROM projection_v3_events",[],"9007199254740993","event identity remains exact above 2^53")
    scalar(db,"SELECT run FROM projection_v3_snapshots WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],"9007199254740993",
      "manifest binds exact large run identity without float conversion")
    equivalent(db,snapshot,snapshot,"large-identity projection resolves every exact joined field")
    Check.check_integrity(db,"large shared projection identities")
    IO.try(Unit,Sql.close(db))

def archived_parser_boundary(+self: String) -> IO(Unit):
  +path = {".build/projection-parser-version.sqlite" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    Projection.schema(db)
    Store.write_text("projection-parser-version.jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex","projection-parser-version.jsonl")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    full(db,old,"historical-parser-v0")
    Store.exec(db,"COMMIT",[])
    verify(db,old)
    Store.write_text("projection-parser-version.jsonl","a",addition())
    +latest : String <- Store.import_file(db,"codex","projection-parser-version.jsonl")
    Check.remember_tables(tables(),db)
    child_failure(self,"foreign",path,old,latest,
      "append enforces current parser even when prefix came from generic archived verification")
    Check.unchanged_tables(tables(),db,"archived parser append rejection")
    build(db,old)
    append(db,old,latest)
    verify(db,old)
    verify(db,latest)
    count(db,"projection_v3_runs","2","verified current-parser full rebuild creates new run before append")
    scalar(db,"SELECT count(*) FROM projection_v3_records p JOIN projection_v3_runs r ON r.id=p.run WHERE r.parser='historical-parser-v0'",[],"72",
      "current parser rebuild leaves historical run payloads immutable")
    equivalent(db,latest,latest,"append after parser-version replay matches full current parsing")
    IO.try(Unit,Sql.close(db))

def record_at(ordinal: String) -> String:
  "SELECT p.id FROM projection_v3_snapshots m JOIN records i ON i.snapshot=m.snapshot JOIN projection_v3_records p ON p.run=m.run AND p.raw=i.raw WHERE m.snapshot=? AND i.ordinal=" ++ ordinal

def selected_record() -> String:
  record_at("31")

def corruptions() -> List<(String & String)>:
  [
    ("changed event payload","UPDATE projection_v3_events SET body='altered retained projection' WHERE record=(" ++ selected_record() ++ ")"),
    ("BLOB substituted for event TEXT","UPDATE projection_v3_events SET body=CAST(body AS BLOB) WHERE record=(" ++ selected_record() ++ ")"),
    ("BLOB substituted for event INTEGER","UPDATE projection_v3_events SET event=CAST(event AS BLOB) WHERE record=(" ++ selected_record() ++ ")"),
    ("missing event row","DELETE FROM projection_v3_events WHERE record=(" ++ selected_record() ++ ")"),
    ("noncontiguous event ordinal","UPDATE projection_v3_events SET event=99 WHERE record=(" ++ selected_record() ++ ")"),
    ("changed incoming context","UPDATE projection_v3_records SET in_model='invented model' WHERE id=(" ++ selected_record() ++ ")"),
    ("changed outgoing context","UPDATE projection_v3_records SET out_model='invented model' WHERE id=(" ++ selected_record() ++ ")"),
    ("incoming context after first32-record window","UPDATE projection_v3_records SET in_model='invented boundary context' WHERE id=(" ++ record_at("32") ++ ")"),
    ("outgoing context near second32-record window","UPDATE projection_v3_records SET out_model='invented late context' WHERE id=(" ++ record_at("63") ++ ")"),
    ("incoming context after second32-record window","UPDATE projection_v3_records SET in_model='invented late context' WHERE id=(" ++ record_at("64") ++ ")"),
    ("typed payload after second32-record window","UPDATE projection_v3_events SET body=CAST(body AS BLOB) WHERE record=(" ++ record_at("64") ++ ")"),
    ("late retained raw digest disagreement","UPDATE raw SET digest='changed late raw digest' WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=64)"),
    ("late retained raw digest type disagreement","UPDATE raw SET digest=CAST(digest AS BLOB) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=64)"),
    ("1.1MiB corrupt context checksum respects stream byte budget","UPDATE projection_v3_records SET context_digest=replace(hex(zeroblob(550000)),'0','x') WHERE id=(" ++ record_at("32") ++ ")"),
    ("BLOB substituted for context TEXT","UPDATE projection_v3_records SET out_repository=CAST(out_repository AS BLOB) WHERE id=(" ++ selected_record() ++ ")"),
    ("raw binding digest disagreement","UPDATE projection_v3_records SET raw_digest='damaged' WHERE id=(" ++ selected_record() ++ ")"),
    ("raw offset disagreement","UPDATE projection_v3_records SET offset=offset+1 WHERE id=(" ++ selected_record() ++ ")"),
    ("raw ordinal disagreement","UPDATE projection_v3_records SET ordinal=ordinal+1 WHERE id=(" ++ selected_record() ++ ")"),
    ("newline coverage disagreement","UPDATE projection_v3_records SET complete=0 WHERE id=(" ++ selected_record() ++ ")"),
    ("oversized coverage disagreement","UPDATE projection_v3_records SET oversized=1 WHERE id=(" ++ selected_record() ++ ")"),
    ("declared event count disagreement","UPDATE projection_v3_records SET events=events+1 WHERE id=(" ++ selected_record() ++ ")"),
    ("event count above U32","UPDATE projection_v3_records SET events=4294967296 WHERE id=(" ++ selected_record() ++ ")"),
    ("REAL substituted for event count INTEGER","UPDATE projection_v3_records SET events=1.5 WHERE id=(" ++ selected_record() ++ ")"),
    ("event checksum disagreement","UPDATE projection_v3_records SET events_digest='damaged' WHERE id=(" ++ selected_record() ++ ")"),
    ("context checksum disagreement","UPDATE projection_v3_records SET context_digest='damaged' WHERE id=(" ++ selected_record() ++ ")"),
    ("prefix chain disagreement","UPDATE projection_v3_records SET previous_chain='damaged' WHERE id=(" ++ selected_record() ++ ")"),
    ("terminal record chain disagreement","UPDATE projection_v3_records SET chain='damaged' WHERE id=(" ++ selected_record() ++ ")"),
    ("missing raw map row","DELETE FROM records WHERE snapshot=? AND ordinal=31"),
    ("substituted adjacent raw occurrence","UPDATE records AS target SET raw=(SELECT raw FROM records AS previous WHERE previous.snapshot=target.snapshot AND previous.ordinal=30) WHERE snapshot=? AND ordinal=31"),
    ("BLOB substituted for snapshot INTEGER","UPDATE snapshots SET extent=CAST(extent AS BLOB) WHERE id=?"),
    ("snapshot extent seal disagreement","UPDATE snapshots SET extent=extent+1 WHERE id=?"),
    ("snapshot checkpoint seal disagreement","UPDATE snapshots SET checkpoint_ordinal=checkpoint_ordinal-1 WHERE id=?"),
    ("unaccepted snapshot cannot yield verified prefix","UPDATE snapshots SET accepted=0 WHERE id=?"),
    ("manifest event count disagreement","UPDATE projection_v3_snapshots SET events=events+1 WHERE snapshot=?"),
    ("manifest checkpoint count disagreement","UPDATE projection_v3_snapshots SET checkpoint_events=checkpoint_events+1 WHERE snapshot=?"),
    ("manifest checkpoint chain disagreement","UPDATE projection_v3_snapshots SET checkpoint_chain='damaged' WHERE snapshot=?"),
    ("manifest terminal chain disagreement","UPDATE projection_v3_snapshots SET terminal_chain='damaged' WHERE snapshot=?"),
    ("manifest seal disagreement","UPDATE projection_v3_snapshots SET digest='damaged' WHERE snapshot=?"),
    ("parser run version disagreement","UPDATE projection_v3_runs SET parser='incompatible-parser' WHERE id=(SELECT run FROM projection_v3_snapshots WHERE snapshot=?)"),
    ("parser run source binding disagreement","UPDATE projection_v3_runs SET locator='/synthetic/different-source' WHERE id=(SELECT run FROM projection_v3_snapshots WHERE snapshot=?)"),
    ("manifest format disagreement","UPDATE projection_v3_snapshots SET version='incompatible-format' WHERE snapshot=?"),
    ("archived v1 manifest format","UPDATE projection_v3_snapshots SET version='shared-projection-v1' WHERE snapshot=?"),
    ("archived v1 run format","UPDATE projection_v3_runs SET version='shared-projection-v1' WHERE id=(SELECT run FROM projection_v3_snapshots WHERE snapshot=?)")
  ]

def corruption_cases(cases: List<(String & String)>,+self: String,+db: U32,
  +path: String,+snapshot: String) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case (+label,sql) <> rest:
      do IO<Unit>:
        child_failure(self,"corrupt",path,snapshot,sql,label ++ " is rejected")
        Check.unchanged_tables(tables(),db,label)
        corruption_cases(rest,self,db,path,snapshot)

# Only these isolated child transactions disable foreign-key enforcement, to
# exercise corrupt LEFT JOIN targets that ordinary writes cannot produce.
def join_corruption_cases(cases: List<(String & String)>,+self: String,+db: U32,
  +path: String,+snapshot: String) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case (+label,sql) <> rest:
      do IO<Unit>:
        child_failure(self,"join-corrupt",path,snapshot,sql,label ++ " is rejected")
        Check.unchanged_tables(tables(),db,label)
        join_corruption_cases(rest,self,db,path,snapshot)

def selected_corruption_cases(cases: List<(String & String)>,+self: String,+db: U32,
  +path: String,+snapshot: String,+ordinal: String) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case (+label,assignment) <> rest:
      do IO<Unit>:
        child_failure(self,"selected",path,snapshot,
          "UPDATE projection_v3_records SET " ++ assignment ++ " WHERE id=(" ++ record_at(ordinal) ++ ")",
          "bounded context read rejects " ++ label ++ " at ordinal" ++ ordinal)
        Check.unchanged_tables(tables(),db,"selected " ++ label ++ " at ordinal" ++ ordinal)
        selected_corruption_cases(rest,self,db,path,snapshot,ordinal)

def selected_commitments() -> List<(String & String)>:
  [("payload digest corruption","events_digest='changed-payload'"),
   ("declared count corruption","events=events+1"),
   ("context_digest-only corruption","context_digest='changed-context'"),
   ("chain-only corruption","chain='changed-chain'")]

def fanout_blocks(count: Nat,+index: U32) -> List<&2,String>:
  match count:
    case 0n:
      []
    case 1n+rest:
      ("{\"type\":\"text\",\"text\":\"fanout event " ++ U32.show(index) ++ "\"}") <>
        fanout_blocks(rest,U32.add(index,1))

def fanout(count: Nat,repository: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"shared-fanout\",\"cwd\":" ++ Json.quote(repository) ++
    ",\"message\":{\"content\":[" ++ String.join(fanout_blocks(count,0),",") ++ "]}}\n"

def fanout_record() -> String:
  record_at("0")

def extra_event(record: String,event: String) -> String:
  "INSERT INTO projection_v3_events(record,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage) SELECT record," ++ event ++
    ",role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM projection_v3_events WHERE record=(" ++ record ++ ") AND event=0"

def event_pages(+self: String,+name: String,+events: Nat,repository: String,
  corruptions: List<(String & String)>) -> IO(Unit):
  +path = ".build/projection-events-" ++ name ++ ".sqlite"
  +source = "projection-events-" ++ name ++ ".jsonl"
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    Projection.schema(db)
    Store.write_text(source,"w",fanout(events,repository))
    +snapshot : String <- Store.import_file(db,"claude",source)
    build(db,snapshot)
    verify(db,snapshot)
    count(db,"projection_v3_records","1",name ++ " fanout stays one retained raw occurrence")
    count(db,"projection_v3_events",Nat.show(events),name ++ " fanout preserves independently expected event count")
    equivalent(db,snapshot,snapshot,name ++ " fanout projection equals complete provider parsing")
    Check.remember_tables(tables(),db)
    corruption_cases(corruptions,self,db,path,snapshot)
    verify(db,snapshot)
    Check.check_integrity(db,name ++ " event paging")
    IO.try(Unit,Sql.close(db))

def paged_events(+self: String) -> IO(Unit):
  do IO<Unit>:
    event_pages(self,"row-bound",130n,"/synthetic/projection-fanout",[
      ("event63 at first page end","UPDATE projection_v3_events SET body='corrupt page end' WHERE record=(" ++ fanout_record() ++ ") AND event=63"),
      ("event64 at second page start","UPDATE projection_v3_events SET body='corrupt next page' WHERE record=(" ++ fanout_record() ++ ") AND event=64"),
      ("event128 at third page start","UPDATE projection_v3_events SET body='corrupt late page' WHERE record=(" ++ fanout_record() ++ ") AND event=128"),
      ("missing event128 cannot skip to final row","DELETE FROM projection_v3_events WHERE record=(" ++ fanout_record() ++ ") AND event=128"),
      ("same130-event count with gap64 and extra130","UPDATE projection_v3_events SET event=130 WHERE record=(" ++ fanout_record() ++ ") AND event=64"),
      ("negative event precedes normal initial event","UPDATE projection_v3_events SET event=-1 WHERE record=(" ++ fanout_record() ++ ") AND event=129")])
    event_pages(self,"terminal-page",64n,"/synthetic/projection-fanout",[
      ("declared64 actual65 extra event immediately after full SQL page",extra_event(fanout_record(),"64")),
      ("declared64 actual65 extra late event beyond full SQL page",extra_event(fanout_record(),"9000000000")),
      ("extra negative event before a full SQL page",extra_event(fanout_record(),"-1")),
      ("INT64_MIN extra event cannot fall below cursor sentinel",extra_event(fanout_record(),"-9223372036854775808")),
      ("REAL extra event below INT64_MIN cannot be excluded by integer range",extra_event(fanout_record(),"-1e100"))])
    event_pages(self,"high-fanout",2049n,"/synthetic/projection-fanout",[
      ("event2048 after32 full event pages","UPDATE projection_v3_events SET body='corrupt final high-fanout event' WHERE record=(" ++ fanout_record() ++ ") AND event=2048"),
      ("missing event2047 before final high-fanout event","DELETE FROM projection_v3_events WHERE record=(" ++ fanout_record() ++ ") AND event=2047"),
      ("same2049 count with late gap2047 and extra2049","UPDATE projection_v3_events SET event=2049 WHERE record=(" ++ fanout_record() ++ ") AND event=2047")])
    event_pages(self,"byte-bound",20n,"/synthetic/" ++ String.repeat("x",100000n),[
      ("large inherited scope event10 after byte-budget cut","UPDATE projection_v3_events SET body='corrupt byte-bounded page' WHERE record=(" ++ fanout_record() ++ ") AND event=10"),
      ("large inherited scope final event19","UPDATE projection_v3_events SET body='corrupt final byte-bounded page' WHERE record=(" ++ fanout_record() ++ ") AND event=19")])

def window_event(model: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"projection-v3\",\"cwd\":\"/synthetic/projection-v3\",\"message\":{\"model\":" ++
    Json.quote(model) ++ ",\"content\":\"window boundary message\"}}\n"

def window_record(index: U32) -> String:
  match index:
    case 0:
      window_event("initial-model")
    case 30:
      window_event("window-one")
    case 31:
      "{\"type\":\"assistant\",\"message\":{\"content\":[]}}\n"
    case 32:
      "{\"type\":\"assistant\",\"message\":{\"content\":[]}}\n"
    case 62:
      window_event("window-two")
    case 63:
      "{\"type\":\"assistant\",\"message\":{\"content\":[]}}\n"
    case 64:
      "{\"type\":\"assistant\",\"message\":{\"content\":[]}}\n"
    case _:
      window_event("")

def window_records(count: Nat,+index: U32) -> String:
  match count:
    case 0n:
      ""
    case 1n+rest:
      window_record(index) ++ window_records(rest,U32.add(index,1))

def extra_zero_event(record: String,event: String) -> String:
  "INSERT INTO projection_v3_events(record,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage) SELECT p.id," ++ event ++
    ",e.role,e.body,e.tool,e.call_id,e.arguments,e.result,e.repository,e.session,e.timestamp,e.model,e.usage,e.parent,e.coverage FROM projection_v3_records p JOIN projection_v3_events e ON e.id=(SELECT min(id) FROM projection_v3_events) WHERE p.id=(" ++ record ++ ")"

def zero_event_windows(+self: String) -> IO(Unit):
  +path = {".build/projection-zero-windows.sqlite" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    Projection.schema(db)
    Store.write_text("projection-zero-windows.jsonl","w",window_records(66n,0))
    +old : String <- Store.import_file(db,"claude","projection-zero-windows.jsonl")
    build(db,old)
    verify(db,old)
    count(db,"projection_v3_records","66","zero-event windows preserve every physical record")
    count(db,"projection_v3_events","62","four zero-event boundary records produce no invented payloads")
    context(db,old,31,"window-one","zero-event ordinal31 inherits changed model")
    context(db,old,32,"window-one","zero-event ordinal32 carries model across physical window")
    context(db,old,33,"window-one","incoming context before first event after zero-event window")
    context(db,old,63,"window-two","zero-event ordinal63 inherits later model")
    context(db,old,64,"window-two","zero-event ordinal64 carries later model across physical window")
    context(db,old,65,"window-two","incoming context before first event after second zero-event window")
    equivalent(db,old,old,"zero-event window projection equals complete parsing")
    Store.write_text("projection-zero-windows.jsonl","a",window_event(""))
    +latest : String <- Store.import_file(db,"claude","projection-zero-windows.jsonl")
    append(db,old,latest)
    verify(db,latest)
    context(db,latest,66,"","append resumes complete-record state after the later Claude message has no recorded model")
    Check.remember_tables(tables(),db)
    corruption_cases([
      ("unexpected event0 in zero-event ordinal31",extra_zero_event(record_at("31"),"0")),
      ("unexpected negative event in zero-event ordinal32",extra_zero_event(record_at("32"),"-1")),
      ("REAL below INT64_MIN cannot disappear from declared-zero ordinal32",extra_zero_event(record_at("32"),"-1e100")),
      ("missing event after zero-event ordinal64","DELETE FROM projection_v3_events WHERE record=(" ++ record_at("65") ++ ")")
    ],self,db,path,old)
    join_corruption_cases([
      ("missing zero-event projection at window ordinal32","DELETE FROM projection_v3_records WHERE id=(" ++ record_at("32") ++ ")"),
      ("missing raw JOIN target at window ordinal64","UPDATE records SET raw=9000000000 WHERE snapshot=? AND ordinal=64")
    ],self,db,path,old)
    verify(db,old)
    verify(db,latest)
    Check.check_integrity(db,"zero-event windows")
    IO.try(Unit,Sql.close(db))

def rollback_cases(+self: String) -> IO(Unit):
  +path = {".build/projection-corruption.sqlite" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    Projection.schema(db)
    Store.write_text("projection-corruption.jsonl","w",fixture())
    +snapshot : String <- Store.import_file(db,"codex","projection-corruption.jsonl")
    build(db,snapshot)
    Store.write_text("projection-corruption.jsonl","a",addition())
    +later : String <- Store.import_file(db,"codex","projection-corruption.jsonl")
    append(db,snapshot,later)
    Store.write_text("projection-corruption.jsonl","w",addition())
    +rewrite : String <- Store.import_file(db,"codex","projection-corruption.jsonl")
    build(db,rewrite)
    Store.write_text("projection-other-generation.jsonl","w",fixture())
    +other : String <- Store.import_file(db,"codex","projection-other-generation.jsonl")
    build(db,other)
    Check.remember_tables(tables(),db)
    corruption_cases(corruptions(),self,db,path,snapshot)
    join_corruption_cases([
      ("missing projection LEFT JOIN at ordinal32","DELETE FROM projection_v3_records WHERE id=(" ++ record_at("32") ++ ")"),
      ("missing raw LEFT JOIN at ordinal64","DELETE FROM raw WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=64)")
    ],self,db,path,snapshot)
    child_failure(self,"foreign",path,snapshot,other,"valid prefix cannot append into a different source generation")
    Check.unchanged_tables(tables(),db,"cross-generation append rejection")
    child_failure(self,"foreign",path,snapshot,rewrite,"valid prefix cannot append into a rewritten generation of its own source")
    Check.unchanged_tables(tables(),db,"same-source rewrite rejection")
    child_failure(self,"foreign",path,later,snapshot,"later checkpoint cannot be reused for a shorter old snapshot")
    Check.unchanged_tables(tables(),db,"reverse extent append rejection")
    child_failure(self,"append-map",path,snapshot,later,"append compares every shared-prefix raw identity against target snapshot")
    Check.unchanged_tables(tables(),db,"append map disagreement")
    child_failure(self,"incomplete",path,snapshot,"","seal cannot publish an incomplete writer")
    Check.unchanged_tables(tables(),db,"incomplete writer rejection")
    child_failure(self,"wrong-raw",path,snapshot,"","writer rejects raw identity from the wrong occurrence")
    Check.unchanged_tables(tables(),db,"wrong raw writer rejection")
    child_failure(self,"version",path,snapshot,"incompatible-parser","current-parser validation rejects incompatible archived parser version")
    Check.unchanged_tables(tables(),db,"incompatible parser rejection")
    child_failure(self,"old-format",path,snapshot,"","consistent v1 run and manifest tags cannot be interpreted as v2")
    Check.unchanged_tables(tables(),db,"v1 format rejection")
    child_failure(self,"payload-feed-full",path,snapshot,"","production payload feed rejects byte-counter overflow before hashing")
    Check.unchanged_tables(tables(),db,"payload feed overflow")
    child_failure(self,"payload-feed-unicode",path,snapshot,"","payload feed counts UTF8 bytes rather than Unicode characters at capacity")
    Check.unchanged_tables(tables(),db,"Unicode payload feed overflow")
    child_failure(self,"payload-finish-full",path,snapshot,"","production payload finish reserves room for final count framing")
    Check.unchanged_tables(tables(),db,"payload finish overflow")
    child_failure(self,"payload-count-full",path,snapshot,"","production event stream rejects event-count overflow before incrementing")
    Check.unchanged_tables(tables(),db,"payload count overflow")
    child_failure(self,"connection-prefix",path,snapshot,path,"verified prefix cannot cross SQLite connection tokens")
    Check.unchanged_tables(tables(),db,"prefix connection binding")
    child_failure(self,"connection-writer",path,snapshot,path,"writer put cannot cross SQLite connection tokens")
    Check.unchanged_tables(tables(),db,"writer connection binding")
    child_failure(self,"connection-seal",path,snapshot,path,"complete writer seal cannot cross SQLite connection tokens")
    Check.unchanged_tables(tables(),db,"seal connection binding")
    child_failure(self,"selected",path,snapshot,
      "UPDATE projection_v3_records SET out_model='invented model' WHERE id=(" ++ selected_record() ++ ")",
      "selected context refuses corrupt immediate predecessor")
    Check.unchanged_tables(tables(),db,"selected context corruption")
    selected_corruption_cases(selected_commitments(),self,db,path,snapshot,"31")
    selected_corruption_cases(selected_commitments(),self,db,path,snapshot,"32")
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["hold",path,snapshot,"projection-sealed.marker"],"",8192,2000)
    Check.interrupted(result,"projection-sealed.marker","sealed-uncommitted\n",
      "sealed shared projection rebuild interruption")
    Check.unchanged_tables(tables(),db,"abrupt sealed rebuild termination")
    verify(db,snapshot)
    verify(db,later)
    verify(db,rewrite)
    verify(db,other)
    Check.check_integrity(db,"projection corruption rollback")
    IO.try(Unit,Sql.close(db))

def corrupt_read(db: U32,snapshot: String,selected: Bool) -> IO(Unit):
  match selected:
    case True{}:
      do IO<Unit>:
        ignored : Projection.Context <- Projection.context_before(db,snapshot,32)
        return Unit{}
    case False{}:
      do IO<Unit>:
        ignored : Projection.VerifiedPrefix <- Projection.verify(db,snapshot)
        return Unit{}

def corrupt_child(+db: U32,+snapshot: String,sql: String,selected: Bool) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,sql,[Sql.Cell.Integer{snapshot}])
    corrupt_read(db,snapshot,selected)
    IO.die(Unit,1,"FAIL deliberately corrupted projection was accepted")

def action(mode: String,+db: U32,+snapshot: String,+other: String) -> IO(Unit):
  match mode:
    case "corrupt":
      corrupt_child(db,snapshot,other,False{})
    case "join-corrupt":
      do IO<Unit>:
        Store.exec(db,"PRAGMA foreign_keys=OFF",[])
        corrupt_child(db,snapshot,other,False{})
    case "selected":
      corrupt_child(db,snapshot,other,True{})
    case "foreign":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        prefix : Projection.VerifiedPrefix <- Projection.verify(db,snapshot)
        ignored : Projection.Writer <- Projection.append(db,other,Store.projection_version(),prefix)
        IO.die(Unit,1,"FAIL cross-generation prefix was accepted")
    case "append-map":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        prefix : Projection.VerifiedPrefix <- Projection.verify(db,snapshot)
        Store.exec(db,"UPDATE records AS target SET raw=(SELECT raw FROM records AS previous WHERE previous.snapshot=target.snapshot AND previous.ordinal=30) WHERE snapshot=? AND ordinal=31",
          [Sql.Cell.Integer{other}])
        ignored : Projection.Writer <- Projection.append(db,other,Store.projection_version(),prefix)
        IO.die(Unit,1,"FAIL mismatched append map was accepted")
    case "incomplete":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        writer : Projection.Writer <- Projection.begin(db,snapshot,Store.projection_version())
        Projection.seal(db,writer)
        IO.die(Unit,1,"FAIL incomplete writer was sealed")
    case "wrong-raw":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        +header : Maintenance.Header <- Maintenance.header(db,snapshot)
        row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,header,0,0,False{})
        raw_id : String <- Check.scalar(db,"SELECT raw FROM records WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{snapshot}])
        writer : Projection.Writer <- Projection.begin(db,snapshot,Store.projection_version())
        ignored : Projection.Writer <- Projection.put(db,writer,raw_id,context => normalize("codex",row,context))
        IO.die(Unit,1,"FAIL wrong raw occurrence was accepted")
    case "version":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        ignored : Projection.VerifiedPrefix <- Projection.verify_version(db,snapshot,other)
        IO.die(Unit,1,"FAIL incompatible parser version was accepted")
    case "old-format":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        Store.exec(db,"UPDATE projection_v3_runs SET version='shared-projection-v1' WHERE id=(SELECT run FROM projection_v3_snapshots WHERE snapshot=?)",
          [Sql.Cell.Integer{snapshot}])
        Store.exec(db,"UPDATE projection_v3_snapshots SET version='shared-projection-v1' WHERE snapshot=?",
          [Sql.Cell.Integer{snapshot}])
        ignored : Projection.VerifiedPrefix <- Projection.verify(db,snapshot)
        IO.die(Unit,1,"FAIL v1 projection format was interpreted as v2")
    case "payload-feed-full":
      do IO<Unit>:
        ignored : Domain.HashContext <- Projection.payload_feed(
          Domain.HashContext{Domain.hash_initial(),[],0,4294967295},"x")
        IO.die(Unit,1,"FAIL payload feed wrapped its byte counter")
    case "payload-feed-unicode":
      do IO<Unit>:
        ignored : Domain.HashContext <- Projection.payload_feed(
          Domain.HashContext{Domain.hash_initial(),[],0,4294967294},"é")
        IO.die(Unit,1,"FAIL payload feed counted Unicode characters instead of UTF8 bytes")
    case "payload-finish-full":
      do IO<Unit>:
        ignored : String <- Projection.payload_finish(
          Domain.HashContext{Domain.hash_initial(),[],0,4294967295},0)
        IO.die(Unit,1,"FAIL final count framing wrapped its byte counter")
    case "payload-count-full":
      do IO<Unit>:
        initial : Domain.HashContext <- Projection.payload_start()
        ignored : Domain.HashContext <- Projection.event_row(framed_row(4294967295,"",""),4294967295,initial)
        IO.die(Unit,1,"FAIL payload event count wrapped")
    case "connection-prefix":
      do IO<Unit>:
        other_db : U32 <- Store.open(other)
        Store.exec(db,"BEGIN IMMEDIATE",[])
        prefix : Projection.VerifiedPrefix <- Projection.verify(db,snapshot)
        ignored : Projection.Writer <- Projection.append(other_db,snapshot,Store.projection_version(),prefix)
        IO.die(Unit,1,"FAIL prefix crossed its database connection")
    case "connection-writer":
      do IO<Unit>:
        other_db : U32 <- Store.open(other)
        Store.exec(db,"BEGIN IMMEDIATE",[])
        header : Maintenance.Header <- Maintenance.header(db,snapshot)
        row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,header,0,0,False{})
        raw_id : String <- Check.scalar(db,"SELECT raw FROM records WHERE snapshot=? AND ordinal=0",[Sql.Cell.Integer{snapshot}])
        writer : Projection.Writer <- Projection.begin(db,snapshot,Store.projection_version())
        ignored : Projection.Writer <- Projection.put(other_db,writer,raw_id,context => normalize("codex",row,context))
        IO.die(Unit,1,"FAIL writer crossed its database connection")
    case "connection-seal":
      do IO<Unit>:
        other_db : U32 <- Store.open(other)
        Store.exec(db,"BEGIN IMMEDIATE",[])
        writer : Projection.Writer <- full_writer(db,snapshot,Store.projection_version())
        Projection.seal(other_db,writer)
        IO.die(Unit,1,"FAIL seal crossed its database connection")
    case "hold":
      do IO<Unit>:
        Store.exec(db,"BEGIN IMMEDIATE",[])
        full(db,snapshot,"rebuild-at-crash-boundary")
        Check.hold(True{},other,"sealed-uncommitted\n")
        IO.die(Unit,1,"FAIL held projection child unexpectedly resumed")
    case _:
      IO.die(Unit,2,"Unknown projection test child mode")

def child(mode: String,path: String,snapshot: String,other: String) -> IO(Unit):
  do IO<Unit>:
    db : U32 <- Store.open(path)
    action(mode,db,snapshot,other)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    payload_framing()
    record_framing()
    exact_append()
    partial_replacement()
    stateful_partial("model-change","{\"type\":\"turn_context\",\"payload\":{\"model\":\"tail-model\"}}","tail-model")
    stateful_partial("model-clear","{\"type\":\"turn_context\",\"payload\":{}}","")
    zero_events()
    fragment_checkpoint()
    exact_identifiers()
    archived_parser_boundary(self)
    paged_events(self)
    zero_event_windows(self)
    rollback_cases(self)
    IO.print("Shared projection suite passed")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{_,Con{mode,Con{path,Con{snapshot,Con{other,Nil{}}}}}}:
      child(mode,path,snapshot,other)
    case _:
      IO.die(Unit,2,"Invalid projection test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
