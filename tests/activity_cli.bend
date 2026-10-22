import Base
import ../src/cli.bend as Cli
import ../src/activity_cli.bend as Command
import ../src/activity_reader.bend as Reader
import ../src/tool_activity.bend as Activity
import ../src/scoped_reader.bend as Scoped
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ./file_evidence.bend as Fixture

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{error}:
      IO.die(Json.Json,1,"FAIL activity CLI JSON: " ++ error)

def execute(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"command" <> args,"",1048576,30000))

def good_result(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    Fixture.assert(U32.is_eq(code,0) && String.is_empty(err),"activity command exits successfully without stderr")
    parsed(Json.parse(String.trim(out)))

def good(self: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- execute(self,args)
    good_result(result)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  Fixture.assert(String.eq(Json.encode(Json.field(value,key)),expected),label)

def bad_result(result: U32 & (String & String),expected: String,+label: String) -> IO(Unit):
  (code,(out,err)) = result
  do IO<Unit>:
    Fixture.assert(U32.is_eq(code,2) && String.is_empty(out),label ++ " has nonzero exit and no success output")
    +value : Json.Json <- parsed(Json.parse(String.trim(err)))
    Fixture.assert(String.eq(Json.text(Json.field(value,"code")),expected) &&
      Bool.not(String.is_empty(Json.text(Json.field(value,"error")))),label ++ " has an explicit structured failure")

def bad(self: String,args: List<String>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,args)
    bad_result(result,expected,label)

def failed(result: U32 & (String & String),expected: String,label: String) -> IO(Unit):
  (code,(out,err)) = result
  Fixture.assert(U32.is_ne(code,0) && String.is_empty(out) && String.contains(err,expected),label)

def args(snapshot: String,start: String,count: String,provider: String,repo: String,role: String,after: String) -> List<String>:
  ["activity-scope",snapshot,start,count,provider,repo,role,after]

def content() -> String:
  "captured result \"quoted\"\n\t café 中文 😀"

def call(id: String) -> String:
  "{\"type\":\"assistant\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"model\":\"synthetic-model\",\"content\":[{\"type\":\"tool_use\",\"id\":" ++
    Json.quote(id) ++ ",\"name\":\"Read\",\"input\":{\"file_path\":\"safe \\\"quoted\\\".txt\",\"note\":\"café 😀\"}}]}}\n"

def result(text: String) -> String:
  "{\"type\":\"user\",\"timestamp\":\"2026-10-20T12:01:00Z\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"read-one\",\"is_error\":true,\"content\":" ++
    Json.quote(text) ++ "}]}}\n"

def fixture(text: String) -> String:
  Fixture.request("/synthetic/activity/repository","activity-session-one","Inspect the synthetic file.") ++
    call("read-one") ++ result(text) ++ call("outside-page") ++
    "{\"type\":\"assistant\",\"message\":{\"content\":\"Recorded response.\"}}\n"

def metadata(+value: Json.Json,snapshot: String,source: String,extent: String) -> IO(Unit):
  do IO<Unit>:
    field(value,"kind","\"recorded_activity\"","activity JSON kind is explicit")
    field(value,"provider","\"claude\"","actual captured provider is a string")
    field(value,"source",Json.quote(source),"actual canonical source locator is preserved")
    field(value,"generation","\"1\"","generation identity is a quoted decimal string")
    field(value,"snapshot",Json.quote(snapshot),"selected immutable snapshot identity is quoted")
    field(value,"extent",Json.quote(extent),"captured extent is an exact decimal string")
    field(value,"total_records","5","total physical record count is numeric")

def pages(+self: String,+snapshot: String,source: String,extent: String) -> IO(Unit):
  do IO<Unit>:
    +whole : Json.Json <- good(self,args(snapshot,"0","100","","","",""))
    metadata(whole,snapshot,source,extent)
    field(whole,"start","0","page start is numeric")
    field(whole,"requested_count","100","requested count is retained after EOF clamp")
    field(whole,"selected_count","5","selected count clamps to actual remaining records")
    field(whole,"verified_count","5","matching provider verifies every selected record")
    field(whole,"next","null","complete range has no continuation")
    field(whole,"scope","{\"provider\":\"\",\"repository\":\"\",\"role\":\"\",\"after\":\"\"}","empty scope is explicit and nested")
    +text : String = Json.text(Json.field(whole,"text"))
    Fixture.assert(String.contains(text,"Unique pairs: 1") && String.contains(text,"Explicit tool_error: 1"),
      "production reader resolves one captured pair and explicit error fact")
    Fixture.assert(String.contains(text,Json.quote(content())) && String.contains(text,"safe "),
      "nested JSON preserves exact Unicode and escaped captured result")
    Fixture.assert(String.contains(text,"\"snapshot\":\"" ++ snapshot ++ "\"") &&
      String.contains(text,"Counts describe this page, not a complete session"),"text contains immutable citations and page-only coverage")
    +one : Json.Json <- good(self,args(snapshot,"1","1","","","",""))
    field(one,"next","2","partial physical page exposes exact next record")
    field(one,"selected_count","1","one-record request stays one record")
    Fixture.assert(String.contains(Json.text(Json.field(one,"text")),"counterpart is not in this selected page"),
      "call-only page does not pair with a result outside its range")
    +last : Json.Json <- good(self,args(snapshot,"4","100","","","",""))
    field(last,"requested_count","100","last page preserves requested count")
    field(last,"selected_count","1","last page clamps remaining record")
    field(last,"next","null","last page does not advertise an EOF loop")
    +empty : Json.Json <- good(self,args(snapshot,"5","1","","","",""))
    field(empty,"selected_count","0","start at EOF selects zero records")
    field(empty,"verified_count","0","EOF page claims no record verification")
    field(empty,"next","null","EOF has no next cursor")
    +far : Json.Json <- good(self,args(snapshot,"4294967295","100","","","",""))
    field(far,"start","4294967295","maximum U32 start is represented exactly")
    field(far,"selected_count","0","out-of-range start clamps to an empty page")
    field(far,"next","null","large start cannot wrap to a spurious next page")

def filters(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +mismatch : Json.Json <- good(self,args(snapshot,"0","2","codex","","",""))
    field(mismatch,"provider","\"claude\"","provider mismatch retains actual captured identity")
    field(Json.field(mismatch,"scope"),"provider","\"codex\"","requested provider remains only in frozen scope")
    field(mismatch,"selected_count","2","mismatch still reports physical range size")
    field(mismatch,"verified_count","0","mismatch does not claim raw records were read")
    field(mismatch,"next","2","mismatch keeps bounded physical continuation")
    Fixture.assert(Bool.not(String.contains(Json.text(Json.field(mismatch,"text")),"captured result")),
      "provider mismatch exposes no out-of-scope payload")
    +tools : Json.Json <- good(self,args(snapshot,"0","100","claude","/synthetic/activity/repository","tool","2026-10-20"))
    field(tools,"scope","{\"provider\":\"claude\",\"repository\":\"/synthetic/activity/repository\",\"role\":\"tool\",\"after\":\"2026-10-20\"}",
      "all scope fields round-trip without widening")
    Fixture.assert(String.contains(Json.text(Json.field(tools,"text")),"calls: 0; results: 1") &&
      String.contains(Json.text(Json.field(tools,"text")),"Unique pairs: 0"),
      "role-filtered result does not reveal an excluded counterpart")
    +later : Json.Json <- good(self,args(snapshot,"0","100","","","","2026-10-21"))
    field(later,"verified_count","5","empty date scope still reports performed raw verification")
    Fixture.assert(String.contains(Json.text(Json.field(later,"text")),"Selected events: 0; calls: 0; results: 0"),
      "date scope suppresses earlier tool payloads")
    +other : Json.Json <- good(self,args(snapshot,"0","100","","/synthetic/other","",""))
    Fixture.assert(Bool.not(String.contains(Json.text(Json.field(other,"text")),"captured result")),
      "repository scope cannot disclose another repository's result")

def invalid(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    bad(self,["activity-scope"],"usage","missing activity arguments")
    bad(self,["activity-scope",snapshot,"0","1","","","","","extra"],"usage","extra activity argument")
    bad(self,args("0","0","1","","","",""),"activity_unavailable","zero snapshot identity")
    bad(self,args("01","0","1","","","",""),"activity_unavailable","noncanonical snapshot identity")
    bad(self,args("9223372036854775808","0","1","","","",""),"activity_unavailable","snapshot outside SQLite integer range")
    bad(self,args(snapshot,"-1","1","","","",""),"invalid_number","negative start")
    bad(self,args(snapshot,"4294967296","1","","","",""),"invalid_number","overflowing start")
    bad(self,args(snapshot,"0","x","","","",""),"invalid_number","nonnumeric count")
    bad(self,args(snapshot,"0","0","","","",""),"activity_unavailable","zero record count")
    bad(self,args(snapshot,"0","101","","","",""),"activity_unavailable","oversized record count")
    bad(self,args(snapshot,"0","1","unknown","","",""),"activity_unavailable","unknown provider scope")
    bad(self,args(snapshot,"0","1","","","unknown",""),"activity_unavailable","unknown role scope")
    bad(self,args(snapshot,"0","1","","","","2026-02-30"),"activity_unavailable","invalid calendar date")
    missing : U32 & (String & String) <- execute(self,args("999","0","1","","","",""))
    failed(missing,"Accepted snapshot not found","missing accepted snapshot fails without success output")

def empty_activity() -> Activity.Page:
  Activity.Page{[],Activity.Stats{0,0,0,0,0,0,0}}

def huge_page() -> Reader.Page:
  Reader.Page{"claude","synthetic://activity","9007199254740993","9007199254740995",4294967295,
    4294967295,4294967294,100,1,1,Scoped.Scope{"","","",""},empty_activity()}

def encoded(result: Result<&2,&2,String,String>) -> IO(Json.Json):
  match result:
    case Done{text}:
      parsed(Json.parse(text))
    case Fail{message}:
      IO.die(Json.Json,1,"FAIL activity encoding: " ++ message)

def refused(result: Result<&2,&2,String,String>,label: String) -> IO(Unit):
  match result:
    case Fail{message}:
      Fixture.assert(Bool.not(String.is_empty(message)),label)
    case Done{_}:
      IO.die(Unit,1,"FAIL " ++ label)

def pure() -> IO(Unit):
  do IO<Unit>:
    +value : Json.Json <- encoded(Command.encode(huge_page(),"quoted \"text\"\n😀"))
    field(value,"generation","\"9007199254740993\"","generation above 2^53 remains an exact string")
    field(value,"snapshot","\"9007199254740995\"","snapshot above 2^53 remains an exact string")
    field(value,"extent","\"4294967295\"","maximum extent remains an exact string")
    field(value,"next","null","largest valid EOF calculation does not wrap")
    field(value,"text",Json.quote("quoted \"text\"\n😀"),"Unicode text survives whole-envelope JSON escaping")
    refused(Command.encode(huge_page(),String.repeat("\"",524288n)),"escaped JSON budget includes envelope and newline")
    refused(Command.encode(Reader.Page{"claude","synthetic://activity","1","1",1,1,0,100,1,0,
      Scoped.Scope{"","","",""},empty_activity()},""),"inconsistent verified-count metadata is rejected")

def retained(+self: String,+db: U32,+snapshot: String,+source: String) -> IO(Unit):
  do IO<Unit>:
    moved : String <- Fixture.command("/bin/mv",[source,source ++ ".moved"])
    +saved : Json.Json <- good(self,args(snapshot,"1","2","","","",""))
    Fixture.assert(String.contains(Json.text(Json.field(saved,"text")),Json.quote(content())),"activity remains available after original source is moved")
    Store.write_text(source,"w",fixture("new generation sentinel"))
    newer : String <- Store.import_file(db,"claude",source)
    Fixture.assert(Bool.not(String.eq(snapshot,newer)),"rewrite publishes another immutable snapshot")
    +old : Json.Json <- good(self,args(snapshot,"1","2","","","",""))
    Fixture.assert(String.contains(Json.text(Json.field(old,"text")),Json.quote(content())) &&
      Bool.not(String.contains(Json.text(Json.field(old,"text")),"new generation sentinel")),"old activity selection stays pinned after rewrite")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{snapshot}])
    bad(self,args(snapshot,"1","1","","","",""),"activity_unavailable","missing context requests verified rebuild rather than prefix replay")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    pure()
    +db : U32 <- Store.open(".build/activity-cli.sqlite")
    Store.write_text("activity \"café\".jsonl","w",fixture(content()))
    +source : String <- Paths.resolve("activity \"café\".jsonl")
    +snapshot : String <- Store.import_file(db,"claude",source)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT extent FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],1)
    pages(self,snapshot,source,Store.field(Store.first(rows),0n))
    filters(self,snapshot)
    invalid(self,snapshot)
    retained(self,db,snapshot,source)
    +help : Json.Json <- good(self,["help"])
    Fixture.assert(String.contains(Json.encode(Json.field(help,"commands")),"activity-scope SNAPSHOT START COUNT PROVIDER REPOSITORY ROLE AFTER"),
      "CLI help advertises recorded activity and its frozen scope")
    IO.try(Unit,Sql.close(db))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "command" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/activity-cli.sqlite")
        Cli.command(db,"",command,rest)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Unsupported recorded activity CLI test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
