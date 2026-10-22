import Base
import ../src/atif_export.bend as Export
import ../src/atif_types.bend as T
import ../src/store.bend as S
import ../src/sql.bend as Sql
import ../src/json.bend as J
import ../src/domain.bend as D
import ../src/paths.bend as Paths
import ../src/capture.bend as Capture
import ../src/providers.bend as P

# This suite creates only relative synthetic files in the runner's new test
# directory. Refusal cases run the same export API in owned bounded children.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def ok(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,(_,err)) = result
  assert(U32.is_eq(code,0) && String.is_empty(err),name)

def command(path: String,args: List<String>,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(path,args,"",8192,5000))
    ok(result,name)

def json(result: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match result:
    case Done{value}: IO.pure(J.Json,value)
    case Fail{message}: IO.die(J.Json,1,"FAIL independent JSON reparse: " ++ message)

def decoded(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{message}: IO.die(String,1,"FAIL exported UTF8: " ++ message)

def read_result(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(String):
  (file,read) = result
  do IO<String>:
    File.close(file)
    bytes : List<&2,U32> <- IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,read))
    decoded(D.decode(bytes))

def read(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1048576)
    read_result(result)

def document(path: String) -> IO(J.Json):
  do IO<J.Json>:
    text : String <- read(path)
    json(J.parse(text))

def item(items: List<&2,J.Json>,index: Nat) -> J.Json:
  match items index:
    case Nil{} _: J.JNull{}
    case first <> _ 0n: first
    case _ <> rest 1n+left: item(rest,left)

def step(value: J.Json,index: Nat) -> J.Json:
  item(J.items(J.field(value,"steps")),index)

def extra(value: J.Json) -> J.Json:
  J.field(J.field(value,"extra"),"juice_bend")

def scalar(db: U32,sql: String) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- S.q(db,sql,[],1)
    return S.field(S.first(rows),0n)

def fingerprint(db: U32) -> IO(String):
  scalar(db,"SELECT (SELECT group_concat(id||':'||generation||':'||extent||':'||records||':'||accepted,'|') FROM snapshots)||';'||(SELECT group_concat(id||':'||digest||':'||hex(bytes),'|') FROM raw)||';'||(SELECT group_concat(snapshot||':'||ordinal||':'||raw,'|') FROM records)")

def user(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"atif-session\",\"message\":{\"content\":" ++ J.quote(text) ++ "}}\n"

def call(id: String,name: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"atif-session\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":" ++ J.quote(id) ++ ",\"name\":" ++ J.quote(name) ++ ",\"input\":{\"path\":\"kept.txt\"}}]}}\n"

def result(id: String,text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"atif-session\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":" ++ J.quote(id) ++ ",\"content\":" ++ J.quote(text) ++ "}]}}\n"

def fixture() -> String:
  user("early retained body Café 中文 🙂") ++ call("single","Write") ++ result("single","saved exactly") ++
    result("orphan","unpaired result") ++ call("duplicate","Read") ++ call("duplicate","Read") ++ result("duplicate","ambiguous result") ++
    "{\"type\":\"assistant\",\"sessionId\":\"atif-session\",\"message\":{\"content\":[]}}\n" ++
    "{malformed\n" ++ user("last retained body")

def many(fuel: Nat,+ordinal: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: user("all-record-marker-" ++ U32.show(ordinal)) ++ many(rest,U32.inc(ordinal))

def receipt(value: T.Receipt,snapshot: String,records: U32,events: U32,steps: U32,name: String) -> IO(Unit):
  T.Receipt{got,_,r,e,s,bytes} = value
  assert(String.eq(got,snapshot) && U32.is_eq(r,records) && U32.is_eq(e,events) && U32.is_eq(s,steps) && U32.is_gt(bytes,0),name)

def check_plain(+doc: J.Json,+snapshot: String) -> IO(Unit):
  +tool = item(J.items(J.field(step(doc,1n),"tool_calls")),0n)
  +observation = item(J.items(J.field(J.field(step(doc,1n),"observation"),"results")),0n)
  do IO<Unit>:
    assert(Nat.is_eq(List.length(&2,J.Json,J.items(J.field(doc,"steps"))),9n),"all ten raw records become nine steps after exactly one proven pair")
    assert(String.eq(J.get(step(doc,0n),"message"),"early retained body Café 中文 🙂") && String.eq(J.get(step(doc,8n),"message"),"last retained body"),"first and final retained bodies survive complete export")
    assert(String.eq(J.get(observation,"content"),"saved exactly") && String.eq(J.get(observation,"source_call_id"),J.get(tool,"tool_call_id")),"cross-record tool result references exact same-step occurrence")
    assert(String.eq(J.get(J.field(extra(observation),"citation"),"record"),"2"),"paired result retains original record chronology")
    assert(String.eq(J.get(item(J.items(J.field(J.field(step(doc,2n),"observation"),"results")),0n),"source_call_id"),""),"orphan result has no false pairing")
    assert(String.eq(J.get(item(J.items(J.field(J.field(step(doc,5n),"observation"),"results")),0n),"content"),"ambiguous result"),"duplicate call IDs preserve ambiguous result as independent data")
    assert(String.eq(J.get(J.field(extra(step(doc,6n)),"citation"),"record"),"7") && String.eq(J.get(J.field(extra(step(doc,6n)),"normalized_event"),"coverage"),"unmapped_record"),"zero-event raw record retains exact citation and explicit coverage marker")
    assert(String.eq(J.get(J.field(extra(step(doc,7n)),"normalized_event"),"coverage"),"malformed"),"malformed raw record does not disappear or claim complete decoding")
    assert(String.eq(J.get(J.field(extra(doc),"capture"),"snapshot"),snapshot) && String.eq(J.get(extra(doc),"retained_scan_complete"),"true"),"full export retains exact selected snapshot and complete traversal disclosure")

def no_output(result: Result<&1,&1,U32 & String,File>,name: String) -> IO(Unit):
  match result:
    case Fail{(code,_)}: assert(U32.is_eq(code,2),name)
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        assert(False{},name)

def failure(result: U32 & (String & String),needle: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,needle),name)

def refuse(+self: String,mode: String,db: String,snapshot: String,+path: String,needle: String,name: String) -> IO(Unit):
  do IO<Unit>:
    run : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,[mode,db,snapshot,path],"",16384,15000))
    failure(run,needle,name)

def mode_limits(mode: String) -> T.Limits:
  match mode:
    case "record-cap": T.Limits{1,1073741824,2000000,2097152,2147483648}
    case "event-cap": T.Limits{1000000,1073741824,1,2097152,2147483648}
    case "step-cap": T.Limits{1000000,1073741824,2000000,1,2147483648}
    case "output-cap": T.Limits{1000000,1073741824,2000000,2097152,8000}
    case _: T.defaults()

def child(mode: String,path: String,snapshot: String,output: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open_existing(path,0))
    exported : T.Receipt <- Export.export_limits(db,snapshot,output,mode_limits(mode))
    IO.try(Unit,Sql.close(db))
    IO.print("exported")

def guard_cases(+self: String,+dbpath: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    S.write_text("occupied.atif.json","w","unchanged destination sentinel")
    refuse(self,"export",dbpath,snapshot,"occupied.atif.json","destination exists","existing output refuses without replacement")
    text : String <- read("occupied.atif.json")
    assert(String.eq(text,"unchanged destination sentinel"),"no-clobber refusal preserves existing bytes")
    command("/bin/ln",["-s","never-created.atif.json","dangling.atif.json"],"synthetic dangling output symlink created")
    refuse(self,"export",dbpath,snapshot,"dangling.atif.json","destination exists","dangling symlink is never followed")
    command("/usr/bin/mkfifo",["destination.fifo"],"synthetic output FIFO created with no writer")
    refuse(self,"export",dbpath,snapshot,"destination.fifo","destination exists","FIFO destination refuses promptly without opening it")
    refuse(self,"record-cap",dbpath,snapshot,"record-cap.atif.json","record/byte supported envelope","record cap refuses partial traversal")
    refuse(self,"event-cap",dbpath,snapshot,"event-cap.atif.json","event supported envelope","event cap refuses partial transcript")
    refuse(self,"step-cap",dbpath,snapshot,"step-cap.atif.json","step supported envelope","step cap refuses truncation")
    refuse(self,"output-cap",dbpath,snapshot,"output-cap.atif.json","output supported envelope","output cap refuses partial publication")
    absent : Result<&1,&1,U32 & String,File> <- File.open("output-cap.atif.json","r")
    no_output(absent,"cap failure publishes no final path")

def raw_frame(+bytes: List<&2,U32>) -> List<&2,U32>:
  +descriptor = U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),8),1)
  List.append(&2,U32,[40,181,47,253,0,56,U32.and(descriptor,255),U32.and(U32.shrn(descriptor,8n),255),U32.and(U32.shrn(descriptor,16n),255)],bytes)

def archive_case(+db: U32) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open("atif-source.jsonl.zst","w"))
    wrote : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,raw_frame(D.encode(user("archived retained body"))))
    S.write_closed(wrote)
    +snapshot : String <- Capture.import_file(db,"claude","atif-source.jsonl.zst")
    command("/bin/rm",["--","atif-source.jsonl.zst"],"remove only synthetic archive source")
    out : T.Receipt <- Export.export(db,snapshot,"archive.atif.json")
    receipt(out,snapshot,1,1,1,"archive export succeeds entirely from retained SQLite bytes")
    +doc : J.Json <- document("archive.atif.json")
    assert(String.eq(J.get(J.field(extra(step(doc,0n)),"citation"),"byte_space"),"logical-decoded-jsonl-bytes") && String.eq(J.get(extra(doc),"byte_space"),"logical-decoded-jsonl-bytes"),"compressed source citations explicitly use logical JSONL byte space")
    assert(Bool.not(String.is_empty(J.get(J.field(extra(doc),"archive_origin"),"compressed_sha256"))),"archive origin container digest remains resolvable")

def codex_case(+db: U32) -> IO(Unit):
  do IO<Unit>:
    S.write_text("atif-codex.jsonl","w","{\"type\":\"session_meta\",\"payload\":{\"id\":\"synthetic-codex\",\"source\":\"cli\"}}\n" ++
      "{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\"}}\n" ++
      "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":\"codex retained user\"}]}}\n" ++
      "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"call_id\":\"codex-call\",\"name\":\"exec_command\",\"arguments\":\"{\\\"cmd\\\":\\\"echo synthetic\\\"}\"}}\n" ++
      "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"codex-call\",\"output\":\"synthetic output\"}}\n")
    +snapshot : String <- S.import_file(db,"codex","atif-codex.jsonl")
    out : T.Receipt <- Export.export(db,snapshot,"codex.atif.json")
    receipt(out,snapshot,5,5,4,"Codex metadata zero-event record user call and result all traversed")
    +doc : J.Json <- document("codex.atif.json")
    assert(String.eq(J.get(J.field(doc,"agent"),"name"),"codex") && String.eq(J.get(step(doc,2n),"message"),"codex retained user"),"Codex provider and user role survive structured export")
    assert(String.eq(J.get(item(J.items(J.field(J.field(step(doc,3n),"observation"),"results")),0n),"content"),"synthetic output"),"Codex argument/result pairing survives context metadata replay")

def permission_result(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_eq(code,0) && String.eq(out,"600\n") && String.is_empty(err),"published ATIF file has exact0600 permissions")

def permission_platform(platform: String,path: String) -> IO(Unit):
  match platform:
    case "Darwin\n":
      do IO<Unit>:
        result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/usr/bin/stat",["-f","%Lp",path],"",8192,2000))
        permission_result(result)
    case "Linux\n":
      do IO<Unit>:
        result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/usr/bin/stat",["-c","%a",path],"",8192,2000))
        permission_result(result)
    case _: IO.die(Unit,1,"FAIL unsupported permission-test platform")

def permission_os(result: U32 & (String & String),path: String) -> IO(Unit):
  (code,(platform,err)) = result
  do IO<Unit>:
    assert(U32.is_eq(code,0) && String.is_empty(err),"permission test observes actual host OS")
    permission_platform(platform,path)

def permissions(path: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/usr/bin/uname",["-s"],"",8192,2000))
    permission_os(result,path)

def ordering_case(+db: U32) -> IO(Unit):
  do IO<Unit>:
    S.write_text("order.jsonl","w",result("backwards","result before call") ++ call("backwards","Read"))
    +snapshot : String <- S.import_file(db,"claude","order.jsonl")
    out : T.Receipt <- Export.export(db,snapshot,"order.atif.json")
    receipt(out,snapshot,2,2,2,"result before call remains two chronological steps")
    +doc : J.Json <- document("order.atif.json")
    +observed : J.Json = item(J.items(J.field(J.field(step(doc,0n),"observation"),"results")),0n)
    assert(String.eq(J.get(observed,"source_call_id"),"") && String.eq(J.get(observed,"content"),"result before call"),"out-of-order result cannot be falsely linked to a future call")
    S.write_text("session-keys.jsonl","w",call("same-id","Read") ++
      "{\"type\":\"assistant\",\"sessionId\":\"other-session\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"same-id\",\"name\":\"Write\",\"input\":{}}]}}\n" ++
      result("same-id","only first session") ++
      "{\"type\":\"user\",\"sessionId\":\"other-session\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"same-id\",\"content\":\"only other session\"}]}}\n")
    +sessions : String <- S.import_file(db,"claude","session-keys.jsonl")
    session_out : T.Receipt <- Export.export(db,sessions,"session-keys.atif.json")
    receipt(session_out,sessions,4,4,2,"same provider call ID in distinct retained sessions pairs independently")
    +session_doc : J.Json <- document("session-keys.atif.json")
    assert(String.eq(J.get(item(J.items(J.field(J.field(step(session_doc,0n),"observation"),"results")),0n),"content"),"only first session") &&
      String.eq(J.get(item(J.items(J.field(J.field(step(session_doc,1n),"observation"),"results")),0n),"content"),"only other session"),"tool matching never crosses retained session identity")

def corruption(+self: String,+path: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open_existing(path,1))
    S.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    +before : String <- fingerprint(db)
    IO.try(Unit,Sql.close(db))
    refuse(self,"export",path,snapshot,"corrupt.atif.json","integrity","corrupt retained bytes refuse export before publication")
    +reopened : U32 <- IO.try(U32,Sql.open_existing(path,0))
    after : String <- fingerprint(reopened)
    assert(String.eq(before,after),"refused corruption export does not mutate retained library state")
    IO.try(Unit,Sql.close(reopened))
    missing : Result<&1,&1,U32 & String,File> <- File.open("corrupt.atif.json","r")
    no_output(missing,"corrupt capture creates no published destination")

def marker_context(projected: S.Context & P.Record) -> IO(Unit):
  (S.Context{repo,session,model,parent},_) = projected
  assert(String.eq(repo,"/synthetic/repo") && String.eq(session,"retained-session") &&
    String.eq(model,"known-model") && String.eq(parent,"retained-parent"),
    "zero-event presentation marker preserves the exact parser context for later records")

def marker_case() -> IO(Unit):
  marker_context(Export.project_event("claude",S.Context{"/synthetic/repo","retained-session","known-model","retained-parent"},
    P.ProviderEvent{"unsupported","marker","","","","","","","","","","","unmapped_record"}))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    marker_case()
    +db : U32 <- S.open(".build/atif.sqlite")
    S.write_text("atif-session.jsonl","w",fixture())
    +snapshot : String <- S.import_file(db,"claude","atif-session.jsonl")
    S.write_text("atif-session.jsonl","a",user("newer snapshot only"))
    newer : String <- S.import_file(db,"claude","atif-session.jsonl")
    assert(Bool.not(String.eq(snapshot,newer)),"append fixture has distinct old and newer accepted snapshots")
    command("/bin/rm",["--","atif-session.jsonl"],"remove only synthetic original JSONL source")
    +before : String <- fingerprint(db)
    out : T.Receipt <- Export.export(db,snapshot,"old.atif.json")
    receipt(out,snapshot,10,10,9,"full export uses exact old snapshot after source deletion")
    +doc : J.Json <- document("old.atif.json")
    check_plain(doc,snapshot)
    assert(Bool.not(String.contains(J.encode(doc),"newer snapshot only")),"old snapshot export never substitutes refreshed capture")
    after : String <- fingerprint(db)
    assert(String.eq(before,after),"successful export does not modify snapshots raw bytes or record mappings")
    temp : String <- scalar(db,"SELECT count(*) FROM sqlite_temp_master WHERE name IN ('jb_atif_events_v1','jb_atif_pairs_v1')")
    assert(String.eq(temp,"0"),"successful export rolls back every staging table and index")
    S.write_text("many.jsonl","w",many(260n,0))
    +all : String <- S.import_file(db,"claude","many.jsonl")
    all_out : T.Receipt <- Export.export(db,all,"all-records.atif.json")
    receipt(all_out,all,260,260,260,"export crosses reader paging boundaries and includes all260 records")
    +all_doc : J.Json <- document("all-records.atif.json")
    assert(String.eq(J.get(step(all_doc,259n),"message"),"all-record-marker-259"),"last record beyond UI page is exported")
    archive_case(db)
    codex_case(db)
    ordering_case(db)
    permissions("old.atif.json")
    S.write_text("empty.jsonl","w","")
    +empty : String <- S.import_file(db,"claude","empty.jsonl")
    IO.try(Unit,Sql.close(db))
    +path : String <- Paths.resolve(".build/atif.sqlite")
    refuse(self,"export",path,empty,"empty.atif.json","nonempty complete snapshot","empty capture cannot masquerade as a complete ATIF trajectory")
    guard_cases(self,path,snapshot)
    refuse(self,"export",path,snapshot,"atif-session.jsonl","source locator","export never recreates a vanished source locator")
    corruption(self,path,snapshot)

def args(argv: List<String>) -> IO(Unit):
  match argv:
    case self <> []: suite(self)
    case _ <> mode <> path <> snapshot <> output <> []: child(mode,path,snapshot,output)
    case _: IO.die(Unit,2,"Invalid ATIF test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
