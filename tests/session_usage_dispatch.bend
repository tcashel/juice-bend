import Base
import ../src/cli.bend as Cli
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths

# Invoke the actual product command dispatcher in a child of this executable.
# This is deliberately separate from the adapter's direct unit tests.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match value:
    case Done{value}: IO.pure(Json.Json,value)
    case Fail{error}: IO.die(Json.Json,1,"FAIL dispatched JSON: " ++ error)

def execute(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"worker" <> args,"",1048576,30000))

def good_result(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    check(U32.is_eq(code,0) && String.is_empty(err),"actual CLI command exits0 without stderr")
    parsed(Json.parse(String.trim(out)))

def good(self: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- execute(self,args)
    good_result(result)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  check(String.eq(Json.encode(Json.field(value,key)),expected),label)

def bad_result(result: U32 & (String & String),expected: String,+label: String) -> IO(Unit):
  (code,(out,err)) = result
  do IO<Unit>:
    check(U32.is_eq(code,2) && String.is_empty(out),label ++ " exits2 without success output")
    +error : Json.Json <- parsed(Json.parse(String.trim(err)))
    check(String.eq(Json.text(Json.field(error,"code")),expected) &&
      Bool.not(String.is_empty(Json.text(Json.field(error,"error")))),label ++ " returns a structured error")

def bad(self: String,args: List<String>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,args)
    bad_result(result,expected,label)

def row(id: String,input: String,output: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"dispatch-usage\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"id\":" ++
    Json.quote(id) ++ ",\"model\":\"synthetic\",\"usage\":{\"input_tokens\":" ++ input ++
    ",\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":" ++ output ++ "}}}\n"

def fixture() -> String:
  row("one","10","1") ++
    String.repeat("{\"type\":\"user\",\"sessionId\":\"dispatch-usage\",\"message\":{\"role\":\"user\",\"content\":\"synthetic retained request café\"}}\n",50n) ++
    row("one","30","5") ++ row("two","7","2")

def full(+self: String,+snapshot: String,+source: String) -> IO(Json.Json):
  do IO<Json.Json>:
    +value : Json.Json <- good(self,["session-usage",snapshot])
    field(value,"kind","\"session_usage\"","actual dispatch reaches the whole-capture command")
    field(value,"processed_records","53","full dispatch scans beyond the first40 physical records")
    field(value,"scan_complete","true","full dispatch reaches the retained extent")
    field(value,"bucket_complete","true","required counter completeness is explicit")
    field(value,"attribution_complete","true","source association completeness remains separate")
    field(value,"limits","{\"records\":1000000,\"bytes\":1073741824,\"keys\":100000,\"descriptor_bytes\":16777216}",
      "actual dispatch reports the operational limits")
    +capture : Json.Json = Json.field(value,"capture")
    field(capture,"provider","\"claude\"","actual captured provider is retained")
    field(capture,"snapshot",Json.quote(snapshot),"accepted snapshot remains an exact string")
    field(capture,"source",Json.quote(source),"retained locator is preserved exactly")
    field(capture,"records","\"53\"","capture record quantity is an exact string")
    +summary : Json.Json = Json.field(value,"summary")
    field(summary,"distinct_call_keys","2","two distinct calls are accounted")
    field(summary,"repeat_observations","1","later mirrored call remains an observation")
    +observed : Json.Json = Json.field(summary,"observed")
    field(observed,"input_tokens","\"37\"","full dispatch includes later mirror enrichment and second call")
    field(observed,"cached_input_tokens","\"4\"","cached input is separately exact")
    field(observed,"cache_creation_input_tokens","\"6\"","cache creation is separately exact")
    field(observed,"output_tokens","\"7\"","output includes later observed maxima")
    field(observed,"cache_creation_1h_input_tokens","null","absent optional bucket stays unknown")
    check(String.contains(Json.text(Json.field(value,"text")),"retained-capture usage"),"actual dispatch includes bounded readable evidence")
    return value

def old_route(+self: String,snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +value : Json.Json <- good(self,["usage",snapshot,"0","1"])
    field(value,"kind","\"recorded_usage\"","old bounded Usage route remains available")
    field(value,"scope","\"selected_physical_range\"","old bounded route keeps its range scope")
    field(value,"requested_records","1","old bounded route preserves requested range")
    +help : Json.Json <- good(self,["help"])
    check(String.contains(Json.encode(Json.field(help,"commands")),"session-usage SNAPSHOT") &&
      String.contains(Json.encode(Json.field(help,"commands")),"usage SNAPSHOT [START [COUNT]]"),
      "actual help advertises both distinct Usage commands")

def invalid(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    bad(self,["session-usage"],"usage","missing snapshot")
    bad(self,["session-usage",snapshot,"extra"],"usage","unexpected argument")
    bad(self,["session-usage","unknown"],"usage_invalid_request","nonnumeric snapshot")
    bad(self,["session-usage","0"],"usage_invalid_request","zero snapshot")
    bad(self,["session-usage","01"],"usage_invalid_request","noncanonical snapshot")
    bad(self,["session-usage","9223372036854775808"],"usage_invalid_request","overflowing snapshot")
    bad(self,["session-usage","999999"],"usage_not_found","unknown accepted snapshot")

def moved(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  check(U32.is_eq(code,0) && String.is_empty(out) && String.is_empty(err),"synthetic source removal from original path succeeds")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/session-usage-dispatch.sqlite")
    Store.write_text("dispatch-usage.jsonl","w",fixture())
    +source : String <- Paths.resolve("dispatch-usage.jsonl")
    +snapshot : String <- Store.import_file(db,"claude",source)
    +before : Json.Json <- full(self,snapshot,source)
    old_route(self,snapshot)
    invalid(self,snapshot)
    renamed : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mv",["dispatch-usage.jsonl","retained-synthetic-source.jsonl"],"",1024,5000))
    moved(renamed)
    after : Json.Json <- good(self,["session-usage",snapshot])
    check(String.eq(Json.encode(before),Json.encode(after)),"actual dispatch reads identical pinned report after original source removal")
    Store.write_text("dispatch-usage.jsonl","w",row("replacement","900","99"))
    +newer : String <- Store.import_file(db,"claude",source)
    check(Bool.not(String.eq(snapshot,newer)),"synthetic rewrite receives a distinct accepted snapshot")
    pinned : Json.Json <- good(self,["session-usage",snapshot])
    check(String.eq(Json.encode(before),Json.encode(pinned)),"explicit old snapshot does not follow rewritten source")
    +latest : Json.Json <- good(self,["session-usage",newer])
    field(Json.field(Json.field(latest,"summary"),"observed"),"input_tokens","\"900\"","new snapshot reports its own distinct counters")
    field(Json.field(latest,"capture"),"records","\"1\"","new generation has its own exact record extent")
    IO.try(Unit,Sql.close(db))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case _ <> "worker" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/session-usage-dispatch.sqlite")
        Cli.command(db,"",command,rest)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Unsupported synthetic dispatch worker arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    cwd : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(cwd,"juice-bend-test-session_usage_dispatch."),
      "Run only through scripts/test in an isolated synthetic directory")
    args : List<String> <- IO.args()
    dispatch(args)
