import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/maintenance.bend as Maintenance
import ../src/evidence.bend as Evidence
import ./publication_crash.bend as Check
import ./append_integrity.bend as Append
import ./sql_batches.bend as Batches

# These tests exercise the production importer and stored seal, not a second
# implementation of the event hashing algorithm. Every source is synthetic.
def record(content: String) -> String:
  "{\"type\":\"assistant\",\"cwd\":\"/synthetic/event-seal\",\"sessionId\":\"event-seal-session\"," ++
    "\"timestamp\":\"2026-10-20T12:00:00Z\",\"parentUuid\":\"recorded-parent\",\"message\":{\"model\":\"seal-model\"," ++
    "\"usage\":{\"input_tokens\":7},\"content\":[" ++ content ++ "]}}\n"

def block(body: String) -> String:
  "{\"type\":\"text\",\"text\":" ++ Json.quote(body) ++ "}"

def message(body: String) -> String:
  record(block(body))

def blocks(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+0n:
      block("sealneedle fanout " ++ U32.show(index))
    case 1n+rest:
      block("sealneedle fanout " ++ U32.show(index)) ++ "," ++ blocks(rest,U32.inc(index))

def call() -> String:
  record("{\"type\":\"tool_use\",\"name\":\"Bash\",\"id\":\"seal-call\",\"input\":{\"command\":\"captured text café only\"}}")

def output() -> String:
  "{\"type\":\"user\",\"cwd\":\"/synthetic/event-seal\",\"sessionId\":\"event-seal-session\",\"message\":{\"content\":[" ++
    "{\"type\":\"tool_result\",\"tool_use_id\":\"seal-call\",\"content\":\"retained result\"}]}}\n"

def fixture() -> String:
  record(blocks(130n,0)) ++ call()

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  Check.equal_scalar(db,sql,args,expected,label)

def valid(+db: U32,snapshot: String,expected: Bool,label: String) -> IO(Unit):
  do IO<Unit>:
    +actual : Bool <- Store.projection_valid(db,snapshot)
    Check.assert(Bool.pick(Bool,expected,actual,Bool.not(actual)),label)

def shared(db: U32,old: String,new: String,expected: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
    [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],expected,label)

def cite(+db: U32,snapshot: String,ordinal: U32,event: U32) -> IO(String):
  do IO<String>:
    record : Evidence.Verified <- Evidence.read_record(db,snapshot,ordinal)
    return Evidence.citation(record,event)

def quote(+db: U32,citation: String) -> IO(String):
  do IO<String>:
    result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    Check.quote_result(result)

def lifecycle(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("seal-main.jsonl","w",fixture())
    +old : String <- Store.import_file(db,"claude","seal-main.jsonl")
    valid(db,old,True{},"initial production capture seals a fanout spanning three event pages")
    Batches.index_exact(db,old,"131","initial event seal")
    +citation : String <- cite(db,old,0,128)
    +original : String <- quote(db,citation)
    Check.assert(String.contains(original,"fanout 128"),"pinned citation selects the independent fanout event after two64-event boundaries")
    Store.write_text("seal-main.jsonl","a",output() ++ message("appendedneedle"))
    +new : String <- Store.import_file(db,"claude","seal-main.jsonl")
    shared(db,old,new,"2","valid new event seal reuses every complete raw prefix record")
    valid(db,new,True{},"appended production seal verifies the resumed event chain")
    Store.write_text("seal-main-fresh.jsonl","w",fixture() ++ output() ++ message("appendedneedle"))
    +fresh : String <- Store.import_file(db,"claude","seal-main-fresh.jsonl")
    Append.equivalent(db,new,fresh,"optimized append exactly equals an independent full parse")
    Batches.index_exact(db,new,"133","optimized append")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{old}],"0","append removes every old-snapshot search occurrence")
    unchanged : String <- Store.import_file(db,"claude","seal-main.jsonl")
    Check.assert(String.eq(unchanged,new),"unchanged source retains the existing accepted sealed snapshot")
    Store.write_text("seal-main.jsonl","w",message("rewrittenneedle"))
    +rewritten : String <- Store.import_file(db,"claude","seal-main.jsonl")
    scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation<>b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{new},Sql.Cell.Integer{rewritten}],"1","source rewrite creates a new immutable generation")
    Batches.index_exact(db,rewritten,"1","rewritten source")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{new}],"0","rewrite removes prior current events from FTS")
    Maintenance.rebuild(db,old)
    valid(db,old,True{},"historical verified rebuild writes a valid current-format event seal")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{old}],"0","historical rebuild cannot republish old events into current search")
    after : String <- quote(db,citation)
    Check.assert(String.eq(original,after),"old pinned citation remains exact after append rewrite and historical rebuild")

def unfinished(+db: U32) -> IO(Unit):
  +prefix = message("complete anchor")
  +partial = {"{\"type\":\"assistant\",\"cwd\":\"/synthetic/event-seal\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"unfinished" : String}
  +suffix = {" completed\"},{\"type\":\"text\",\"text\":\"second completed event\"}]}}\n" : String}
  do IO<Unit>:
    Store.write_text("seal-tail.jsonl","w",prefix ++ partial)
    +old : String <- Store.import_file(db,"claude","seal-tail.jsonl")
    +citation : String <- cite(db,old,1,0)
    +before : String <- quote(db,citation)
    Check.assert(String.contains(before,"malformed"),"unfinished raw tail is independently retained as explicit malformed coverage")
    Store.write_text("seal-tail.jsonl","a",suffix ++ message("tail end"))
    +new : String <- Store.import_file(db,"claude","seal-tail.jsonl")
    shared(db,old,new,"1","tail completion reuses only complete physical prefix records")
    Store.write_text("seal-tail-fresh.jsonl","w",prefix ++ partial ++ suffix ++ message("tail end"))
    +fresh : String <- Store.import_file(db,"claude","seal-tail-fresh.jsonl")
    Append.equivalent(db,new,fresh,"completed tail replaces only its provisional projection")
    scalar(db,"SELECT body FROM events WHERE snapshot=? AND ordinal=1 AND event=1",[Sql.Cell.Integer{new}],"second completed event",
      "completed tail emits its independently expected second event")
    valid(db,new,True{},"resumed checkpoint chain excludes provisional old-tail events")
    after : String <- quote(db,citation)
    Check.assert(String.eq(before,after),"old malformed-tail citation remains stable after completion")

def zero_events(+db: U32) -> IO(Unit):
  +mirror = {"{\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_message\",\"message\":\"mirror only\"}}\n" : String}
  +tail = {"{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"zero-prefix result\"}]}}\n" : String}
  do IO<Unit>:
    Store.write_text("seal-zero.jsonl","w",mirror ++ mirror)
    +old : String <- Store.import_file(db,"codex","seal-zero.jsonl")
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{old}],"0","complete physical records may legitimately emit no normalized events")
    valid(db,old,True{},"zero-event nonempty raw snapshot has a valid envelope")
    Store.write_text("seal-zero.jsonl","a",tail)
    +new : String <- Store.import_file(db,"codex","seal-zero.jsonl")
    shared(db,old,new,"2","zero-event prefix still preserves physical raw ownership across append")
    scalar(db,"SELECT ordinal||'|'||event||'|'||body FROM events WHERE snapshot=?",[Sql.Cell.Integer{new}],"2|0|zero-prefix result",
      "first normalized event after zero-event prefix keeps its physical ordinal")
    valid(db,new,True{},"resumed empty event chain verifies after a later physical record emits an event")

def large_payload(+db: U32) -> IO(Unit):
  +body = message(String.repeat("x",220000n))
  do IO<Unit>:
    Store.write_text("seal-large.jsonl","w",String.repeat(body,7n))
    +old : String <- Store.import_file(db,"claude","seal-large.jsonl")
    Store.write_text("seal-large.jsonl","a",message("small appended event"))
    +new : String <- Store.import_file(db,"claude","seal-large.jsonl")
    shared(db,old,new,"7","event chain retains every raw record across multiple byte-limited prefix batches")
    valid(db,new,True{},"large payload copy and tail seal remain below bridge output bounds")
    scalar(db,"SELECT sum(length(CAST(body AS BLOB))) FROM events WHERE snapshot=? AND ordinal<7",
      [Sql.Cell.Integer{new}],"1540000","large copied event payloads retain every expected byte")

# Existing SQL triggers conservatively disable carried-prefix seal reuse. The
# trigger is deliberately benign: this does not claim arbitrary privileged SQL
# code can mutate both a verified anchor and its copy safely.
def trigger_case(+db: U32,+name: String,temp: Bool) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(name ++ ".jsonl","w",fixture())
    +old : String <- Store.import_file(db,"claude",name ++ ".jsonl")
    Store.exec(db,"CREATE TABLE seal_trigger_audit(snapshot INTEGER,ordinal INTEGER,event INTEGER)",[])
    Store.exec(db,"CREATE " ++ Bool.pick(String,temp,"TEMP ","") ++
      "TRIGGER seal_benign_trigger AFTER INSERT ON main.events BEGIN INSERT INTO seal_trigger_audit VALUES(new.snapshot,new.ordinal,new.event); END",[])
    present : Bool <- Store.has_triggers(db)
    Check.assert(present,name ++ " production trigger guard sees the installed trigger")
    Store.write_text(name ++ ".jsonl","a",message("trigger append"))
    +new : String <- Store.import_file(db,"claude",name ++ ".jsonl")
    scalar(db,"SELECT count(*) FROM seal_trigger_audit WHERE snapshot=?",[Sql.Cell.Integer{new}],"132",
      name ++ " trigger observes actual copied and appended event writes")
    valid(db,new,True{},name ++ " conservative full seal remains valid")
    Store.write_text(name ++ "-fresh.jsonl","w",fixture() ++ message("trigger append"))
    +fresh : String <- Store.import_file(db,"claude",name ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,name ++ " trigger path matches independent fresh replay")
    Batches.index_exact(db,new,"132",name ++ " current search")
    Store.exec(db,"DROP TRIGGER seal_benign_trigger",[])
    Store.exec(db,"DROP TABLE seal_trigger_audit",[])
    absent : Bool <- Store.has_triggers(db)
    Check.assert(Bool.not(absent),name ++ " production trigger guard clears after exact trigger removal")

def mutate_and_rollback(+db: U32,+snapshot: String,sql: String,label: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,sql,[Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,False{},label)
    Store.exec(db,"ROLLBACK",[])

def fields() -> List<&2,String>:
  ["role","body","tool","call_id","arguments","result","repository","session","timestamp","model","usage","parent","coverage"]

def payloads(fields: List<&2,String>,+db: U32,+snapshot: String) -> IO(Unit):
  match fields:
    case []:
      IO.pure(Unit,Unit{})
    case +field <> rest:
      do IO<Unit>:
        mutate_and_rollback(db,snapshot,"UPDATE events SET " ++ field ++ "=" ++ field ++ "||'changed' WHERE snapshot=? AND ordinal=0 AND event=64",
          "event seal binds exact " ++ field ++ " text after a batch boundary")
        mutate_and_rollback(db,snapshot,"UPDATE events SET " ++ field ++ "=CAST(" ++ field ++ " AS BLOB) WHERE snapshot=? AND ordinal=0 AND event=64",
          "event seal rejects BLOB masquerading as " ++ field ++ " text")
        payloads(rest,db,snapshot)

def numeric_headers(fields: List<&2,String>,+db: U32,+snapshot: String) -> IO(Unit):
  match fields:
    case []:
      IO.pure(Unit,Unit{})
    case +field <> rest:
      do IO<Unit>:
        mutate_and_rollback(db,snapshot,"UPDATE snapshots SET " ++ field ++ "=" ++ field ++
          Bool.pick(String,String.starts_with(field,"checkpoint"),"-1","+1") ++ " WHERE id=?",
          "event envelope binds snapshot " ++ field ++ " value")
        mutate_and_rollback(db,snapshot,"UPDATE snapshots SET " ++ field ++ "=0.5 WHERE id=?",
          "event envelope rejects REAL snapshot " ++ field)
        mutate_and_rollback(db,snapshot,"UPDATE snapshots SET " ++ field ++ "=CAST(" ++ field ++ " AS BLOB) WHERE id=?",
          "event envelope rejects BLOB snapshot " ++ field)
        numeric_headers(rest,db,snapshot)

def extra(ordinal: String,event: String) -> String:
  "INSERT INTO events SELECT snapshot," ++ ordinal ++ "," ++ event ++ ",role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=? AND ordinal=0 AND event=0"

def row_keys(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    mutate_and_rollback(db,snapshot,extra("-2","0"),"extra negative ordinal cannot hide before the first keyset cursor")
    mutate_and_rollback(db,snapshot,extra("-1.5","0"),"extra REAL negative ordinal cannot hide before the first keyset cursor")
    mutate_and_rollback(db,snapshot,extra("0","-1"),"extra negative event index is rejected before event zero")
    mutate_and_rollback(db,snapshot,extra("0","0.5"),"REAL event key cannot masquerade as an integer occurrence")
    mutate_and_rollback(db,snapshot,extra("x'30'","0"),"BLOB ordinal cannot disappear behind a converted cursor")
    mutate_and_rollback(db,snapshot,extra("0","x'30'"),"BLOB event index cannot disappear behind a converted cursor")
    mutate_and_rollback(db,snapshot,extra("4294967296","0"),"out-of-range physical ordinal is rejected")
    mutate_and_rollback(db,snapshot,extra("0","4294967296"),"out-of-range event index is rejected")
    mutate_and_rollback(db,snapshot,"DELETE FROM events WHERE snapshot=? AND ordinal=0 AND event=64","missing event exactly at a page boundary invalidates the envelope")
    mutate_and_rollback(db,snapshot,"DELETE FROM events WHERE snapshot=? AND ordinal=0 AND event=0","missing leading event cannot be treated as an empty prefix")
    mutate_and_rollback(db,snapshot,extra("0","130"),"extra contiguous fanout event invalidates the complete event count and chain")

def snapshot_binding(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO snapshots(generation,extent,checkpoint,checkpoint_ordinal,records,accepted) SELECT generation,extent,checkpoint,checkpoint_ordinal,records,accepted FROM snapshots WHERE id=?",
      [Sql.Cell.Integer{snapshot}])
    +copy : String <- Store.last_id(db)
    Store.exec(db,"INSERT INTO records SELECT ?,ordinal,raw FROM records WHERE snapshot=?",[Sql.Cell.Integer{copy},Sql.Cell.Integer{snapshot}])
    Store.exec(db,"INSERT INTO events SELECT ?,ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=?",
      [Sql.Cell.Integer{copy},Sql.Cell.Integer{snapshot}])
    Store.exec(db,"INSERT INTO projection_checks SELECT ?,version,digest FROM projection_checks WHERE snapshot=?",
      [Sql.Cell.Integer{copy},Sql.Cell.Integer{snapshot}])
    valid(db,copy,False{},"event envelope binds snapshot ID when source generation extent counts and all event cells are identical")
    Store.exec(db,"ROLLBACK",[])

def headers(+db: U32,+snapshot: String,+other: String) -> IO(Unit):
  do IO<Unit>:
    numeric_headers(["extent","records","checkpoint","checkpoint_ordinal"],db,snapshot)
    mutate_and_rollback(db,snapshot,"UPDATE sources SET provider='codex' WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
      "event envelope binds exact provider identity")
    mutate_and_rollback(db,snapshot,"UPDATE sources SET locator=locator||'/forged' WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
      "event envelope binds exact source locator")
    mutate_and_rollback(db,snapshot,"UPDATE sources SET provider=CAST(provider AS BLOB) WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
      "event envelope requires provider TEXT type")
    mutate_and_rollback(db,snapshot,"UPDATE sources SET locator=CAST(locator AS BLOB) WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
      "event envelope requires locator TEXT type")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO generations(source) SELECT source FROM generations WHERE id=(SELECT generation FROM snapshots WHERE id=?)",
      [Sql.Cell.Integer{snapshot}])
    Store.exec(db,"UPDATE snapshots SET generation=last_insert_rowid() WHERE id=?",[Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,False{},"event envelope binds generation independently of unchanged source identity")
    Store.exec(db,"ROLLBACK",[])
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"UPDATE generations SET source=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?) WHERE id=(SELECT generation FROM snapshots WHERE id=?)",
      [Sql.Cell.Integer{other},Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,False{},"event envelope binds source independently of unchanged generation identity")
    Store.exec(db,"ROLLBACK",[])
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"UPDATE projection_checks SET digest=(SELECT digest FROM projection_checks WHERE snapshot=?) WHERE snapshot=?",
      [Sql.Cell.Integer{other},Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,False{},"another snapshot envelope cannot replace a matching-content snapshot seal")
    Store.exec(db,"ROLLBACK",[])

def bindings(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("seal-bindings.jsonl","w",fixture())
    +snapshot : String <- Store.import_file(db,"claude","seal-bindings.jsonl")
    Store.write_text("seal-bindings-other.jsonl","w",fixture())
    +other : String <- Store.import_file(db,"claude","seal-bindings-other.jsonl")
    payloads(fields(),db,snapshot)
    row_keys(db,snapshot)
    snapshot_binding(db,snapshot)
    headers(db,snapshot,other)
    valid(db,snapshot,True{},"all rolled-back mutation probes leave original production seal valid")

def fallback(+db: U32,+name: String,mutation: String) -> IO(Unit):
  +body = message("retained before fallback") ++ call()
  +tail = output() ++ message("retained after fallback")
  do IO<Unit>:
    Store.write_text(name ++ ".jsonl","w",body)
    +old : String <- Store.import_file(db,"claude",name ++ ".jsonl")
    Store.exec(db,mutation,[Sql.Cell.Integer{old}])
    valid(db,old,False{},name ++ " is not trusted as a complete prefix")
    Store.write_text(name ++ ".jsonl","a",tail)
    +new : String <- Store.import_file(db,"claude",name ++ ".jsonl")
    shared(db,old,new,"0",name ++ " performs verified full raw replay instead of reusing derived prefix")
    Store.write_text(name ++ "-fresh.jsonl","w",body ++ tail)
    +fresh : String <- Store.import_file(db,"claude",name ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,name ++ " recovery matches an independent fresh import")
    valid(db,new,True{},name ++ " recovery publishes a newly valid envelope")
    Batches.index_exact(db,new,"4",name ++ " recovered search")

def fallbacks(+db: U32) -> IO(Unit):
  do IO<Unit>:
    fallback(db,"seal-missing","DELETE FROM projection_checks WHERE snapshot=?")
    fallback(db,"seal-legacy","UPDATE projection_checks SET version='providers-v4-utc-context-relay' WHERE snapshot=?")
    fallback(db,"seal-damaged","UPDATE projection_checks SET digest='event-seal-v1|broken' WHERE snapshot=?")
    fallback(db,"seal-typed","UPDATE projection_checks SET digest=CAST(digest AS BLOB) WHERE snapshot=?")
    fallback(db,"seal-version-type","UPDATE projection_checks SET version=CAST(version AS BLOB) WHERE snapshot=?")
    fallback(db,"seal-missing-event","DELETE FROM events WHERE snapshot=? AND ordinal=0")
    fallback(db,"seal-negative-extra",extra("-2","0"))

# Mutation occurs after the production copy but before its source reverification
# and final seal. The observer is explicit, bounded and isolated to this child.
def fault_sql(mode: String) -> String:
  match mode:
    case "delete":
      "DELETE FROM events WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=0 AND event=64"
    case "type":
      "UPDATE events SET body=CAST(body AS BLOB) WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=0 AND event=64"
    case "extra":
      "INSERT INTO events SELECT snapshot,-2,0,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=0 AND event=0"
    case "extra-valid":
      "INSERT INTO events SELECT snapshot,0,130,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=0 AND event=0"
    case _:
      "UPDATE events SET body='forged copied payload' WHERE snapshot=(SELECT max(id) FROM snapshots) AND ordinal=0 AND event=64"

def mutate_at(enabled: Bool,db: U32,+mode: String,prefix: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        Store.exec(db,fault_sql(mode),[])
        Store.write_text(prefix ++ ".marker","w","staged:" ++ mode ++ "\n")

def observe(fuel: Nat,+db: U32,+mode: String,+prefix: String) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        mutate_at(String.eq(Store.phase_name(phase),"staged"),db,mode,prefix)
        return observe(rest,db,mode,prefix)}

def combined(output: String & String) -> String:
  (out,err) = output
  out ++ err

def rejected(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,output) = result
  +text = combined(output)
  Check.assert(U32.is_ne(code,0) && (String.contains(text,"prefix") || String.contains(text,"seal")),label)

def marker_read(got: File & Result<&1,&1,U32 & String,String>,expected: String) -> IO(Unit):
  (file,result) = got
  do IO<Unit>:
    File.close(file)
    text : String <- IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))
    Check.assert(String.eq(text,expected),"copied-prefix fault reached exact Staged observer before rejection")

def baseline(+db: U32,+snapshot: String) -> IO(Check.Baseline):
  do IO<Check.Baseline>:
    text : String <- Store.page(db,snapshot,0,100)
    +citation : String <- cite(db,snapshot,0,128)
    captured : String <- quote(db,citation)
    return Check.Baseline{snapshot,text,citation,captured}

def fault(+self: String,+mode: String) -> IO(Unit):
  +prefix = ".build/seal-fault-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",fixture())
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    +baseline : Check.Baseline <- baseline(db,old)
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",message("pending new raw"))
    child : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["fault",mode,prefix],"",8192,30000))
    rejected(child,mode ++ " copied-prefix corruption cannot be sealed and published")
    file : File <- IO.try(File,File.open(prefix ++ ".marker","r"))
    marker : File & Result<&1,&1,U32 & String,String> <- File.read(file,128)
    marker_read(marker,"staged:" ++ mode ++ "\n")
    Check.unchanged_tables(Check.tables(),db,mode ++ " copied-prefix failure")
    Check.pinned(db,baseline,mode ++ " copied-prefix failure")
    +new : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    valid(db,new,True{},mode ++ " ordinary retry succeeds after rollback")
    shared(db,old,new,"2",mode ++ " failed mutation never poisons later prefix reuse")
    IO.try(Unit,Sql.close(db))

def wide_ids() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/seal-wide.sqlite")
    Store.exec(db,"INSERT INTO sources(id,provider,locator) VALUES(9007199254740992,'claude','/synthetic/unimported-id-seed')",[])
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(9007199254740992,9007199254740992)",[])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent) VALUES(9007199254740992,9007199254740992,0)",[])
    Store.write_text("seal-wide.jsonl","w",message("wide identity retained"))
    +old : String <- Store.import_file(db,"claude","seal-wide.jsonl")
    Check.assert(String.eq(old,"9007199254740993"),"production import preserves an odd snapshot ID above2^53")
    scalar(db,"SELECT p.id||'|'||g.id||'|'||s.id FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{old}],"9007199254740993|9007199254740993|9007199254740993","production envelope header retains exact wide source generation and snapshot identities")
    valid(db,old,True{},"wide integer identities verify through actual SQLite header extraction")
    +citation : String <- cite(db,old,0,0)
    +before : String <- quote(db,citation)
    Check.assert(String.contains(citation,"9007199254740993"),"wide immutable citation is serialized as exact decimal text")
    Store.write_text("seal-wide.jsonl","a",message("wide identity appended"))
    +new : String <- Store.import_file(db,"claude","seal-wide.jsonl")
    Check.assert(String.eq(new,"9007199254740994"),"production append allocates the next exact wide snapshot ID")
    shared(db,old,new,"1","wide-ID optimized append retains original raw occurrence identity")
    valid(db,new,True{},"wide-ID appended envelope verifies")
    after : String <- quote(db,citation)
    Check.assert(String.eq(before,after),"wide old citation remains exact after append")
    IO.try(Unit,Sql.close(db))

def rejected_owner(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  Check.assert(U32.is_ne(code,0) && String.contains(out ++ err,"source"),
    "valid foreign seal linked through sources.latest is rejected before append")

def foreign_owner(self: String) -> IO(Unit):
  +prefix = {".build/seal-owner" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",message("identical foreign bytes"))
    Store.write_text(prefix ++ "-other.jsonl","w",message("identical foreign bytes"))
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    +foreign : String <- Store.import_file(db,"claude",prefix ++ "-other.jsonl")
    valid(db,foreign,True{},"foreign-source regression starts with a legitimately valid matching-byte seal")
    Store.exec(db,"UPDATE sources SET latest=? WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
      [Sql.Cell.Integer{foreign},Sql.Cell.Integer{old}])
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",message("owner append"))
    child : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["plain",prefix],"",8192,30000))
    rejected_owner(child)
    Check.unchanged_tables(Check.tables(),db,"foreign source ownership rejection")
    valid(db,foreign,True{},"foreign-source rejection preserves the other source's valid seal")
    Store.exec(db,"UPDATE sources SET latest=? WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{old}])
    +new : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    shared(db,old,new,"1","restoring the correct source link permits healthy prefix reuse")
    scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"1","recovered append remains in its own source generation")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/event-seal-append.sqlite")
    lifecycle(db)
    unfinished(db)
    zero_events(db)
    large_payload(db)
    bindings(db)
    fallbacks(db)
    trigger_case(db,"seal-main-trigger",False{})
    trigger_case(db,"seal-temp-trigger",True{})
    IO.try(Unit,Sql.close(db))
    fault(self,"body")
    fault(self,"delete")
    fault(self,"type")
    fault(self,"extra")
    fault(self,"extra-valid")
    wide_ids()
    foreign_owner(self)

def child(+mode: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- Store.import_observed(db,"claude",prefix ++ ".jsonl",observe(9n,db,mode,prefix))
    IO.print("Unexpected publication " ++ snapshot)
    IO.try(Unit,Sql.close(db))

def plain_child(+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    IO.print("Unexpected foreign-source publication " ++ snapshot)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "fault" <> mode <> prefix <> []:
      child(mode,prefix)
    case _ <> "plain" <> prefix <> []:
      plain_child(prefix)
    case _:
      IO.die(Unit,2,"Invalid synthetic event-seal regression arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
