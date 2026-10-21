import Base
import ../src/session_usage_cli.bend as Command
import ../src/session_usage.bend as Reader
import ../src/session_usage_counts.bend as Counts
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match value:
    case Done{value}: IO.pure(Json.Json,value)
    case Fail{error}: IO.die(Json.Json,1,"FAIL usage command JSON: " ++ error)

def need(-A: Kind(&2),value: Result<&2,&2,Reader.Failure,A>) -> IO(A):
  match value:
    case Done{value}: IO.pure(A,value)
    case Fail{Reader.Failure{code,message}}: IO.die(A,1,"FAIL " ++ code ++ ": " ++ message)

def refused(-A: Kind(&2),value: Result<&2,&2,Reader.Failure,A>,code: String,label: String) -> IO(Unit):
  match value:
    case Done{_}: check(False{},label)
    case Fail{Reader.Failure{actual,message}}:
      check(String.eq(actual,code) && Bool.not(String.is_empty(message)),label)

def execute(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"worker" <> args,"",1048576,30000))

def good_result(value: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = value
  do IO<Json.Json>:
    check(U32.is_eq(code,0) && String.is_empty(err),"whole-capture command exits0 with no stderr")
    parsed(Json.parse(String.trim(out)))

def good(self: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    value : U32 & (String & String) <- execute(self,args)
    good_result(value)

def bad_result(value: U32 & (String & String),expected: String,+label: String) -> IO(Unit):
  (code,(out,err)) = value
  do IO<Unit>:
    check(U32.is_eq(code,2) && String.is_empty(out),label ++ " exits2 without success output")
    +error : Json.Json <- parsed(Json.parse(String.trim(err)))
    check(String.eq(Json.text(Json.field(error,"code")),expected) &&
      Bool.not(String.is_empty(Json.text(Json.field(error,"error")))),label ++ " has a structured error acknowledgement")

def bad(self: String,args: List<String>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,args)
    bad_result(result,expected,label)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  check(String.eq(Json.encode(Json.field(value,key)),expected),label)

def moved(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  check(U32.is_eq(code,0) && String.is_empty(out) && String.is_empty(err),"synthetic source relocation actually succeeds")

def row(id: String,input: String,output: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"owned café\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"id\":" ++
    Json.quote(id) ++ ",\"model\":\"synthetic\",\"usage\":{\"input_tokens\":" ++ input ++
    ",\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":" ++ output ++ "}}}\n"

def claude() -> String:
  row("one","10","1") ++ row("one","12","4") ++ row("two","8","2")

def codex() -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"synthetic-codex\",\"source\":\"cli\"}}\n" ++
  "{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":100,\"cached_input_tokens\":20,\"output_tokens\":5}}}}\n" ++
  String.repeat("{\"type\":\"turn_context\",\"payload\":{\"model\":\"synthetic\"}}\n",127n) ++
  "{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":240,\"cached_input_tokens\":70,\"output_tokens\":11}}}}\n"

def read(+db: U32,snapshot: String) -> IO(Reader.Report):
  do IO<Reader.Report>:
    result : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run(db,snapshot,Reader.defaults())
    need(Reader.Report,result)

def reopened(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,db: U32,label: String) -> IO(Unit):
  match result:
    case Fail{_}: check(False{},label)
    case Done{_}:
      do IO<Unit>:
        Store.exec(db,"ROLLBACK",[])
        check(True{},label)

def available(+db: U32,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"BEGIN DEFERRED",[],0)
    reopened(result,db,label)

def full(+self: String,+db: U32,+snapshot: String,+source: String) -> IO(Reader.Report):
  do IO<Reader.Report>:
    +value : Json.Json <- good(self,["default",snapshot])
    field(value,"kind","\"session_usage\"","full usage has its own command discriminator")
    field(value,"processed_records","3","full usage drives every physical record")
    field(value,"scan_complete","true","full retained extent completion is explicit")
    field(value,"bucket_complete","true","complete required buckets are separate from scan completion")
    field(value,"attribution_complete","true","captured source-session association is separately reported")
    field(value,"limits","{\"records\":1000000,\"bytes\":1073741824,\"keys\":100000,\"descriptor_bytes\":16777216}",
      "default operational limits are visible in the result")
    +capture : Json.Json = Json.field(value,"capture")
    field(capture,"snapshot",Json.quote(snapshot),"snapshot identity is an exact JSON string")
    field(capture,"source",Json.quote(source),"canonical retained Unicode source locator is unchanged")
    field(capture,"records","\"3\"","capture record quantity stays an exact identity string")
    field(capture,"provider","\"claude\"","captured provider is explicit")
    +summary : Json.Json = Json.field(value,"summary")
    field(summary,"provider","\"claude\"","summary is provider-discriminated")
    field(summary,"distinct_call_keys","2","duplicate call observations do not inflate distinct calls")
    field(summary,"repeat_observations","1","repeat observations stay visible")
    field(Json.field(summary,"observed"),"input_tokens","\"20\"","Claude command emits exact per-call maxima subtotal")
    field(Json.field(summary,"observed"),"output_tokens","\"6\"","Claude output subtotal includes later call enrichment")
    field(Json.field(summary,"observed"),"cache_creation_1h_input_tokens","null","absent optional counter is null rather than invented zero")
    field(Json.field(summary,"unattributed"),"input_tokens","null","no known unattributed counter remains unknown")
    +report : Reader.Report <- read(db,snapshot)
    +expected : String <- need(String,Command.rendered(report))
    check(String.eq(Json.encode(value),expected),"command JSON exactly matches the direct verified reader and encoder")
    check(String.contains(Json.text(Json.field(value,"text")),"not a bill, quota, authorship proof") &&
      String.contains(Json.text(Json.field(value,"text")),"logical UTF8 descriptor bytes"),"readable report retains accounting and logical-budget disclosures")
    available(db,"successful adapter run releases its owned read transaction")
    return report

def reidentified(report: Reader.Report) -> Reader.Report:
  Reader.Report{Reader.Capture{provider,_,_,_,_,extent,records},limits,processed,bytes,scan,buckets,attribution,reason,coverage,summary} = report
  Reader.Report{Reader.Capture{provider,"9007199254740993","/synthetic/quoted \"café😀\".jsonl","9007199254740995","9007199254740997",extent,records},
    limits,processed,bytes,scan,buckets,attribution,reason,coverage,summary}

def bad_identity(report: Reader.Report) -> Reader.Report:
  Reader.Report{Reader.Capture{provider,_,path,generation,snapshot,extent,records},limits,processed,bytes,scan,buckets,attribution,reason,coverage,summary} = report
  Reader.Report{Reader.Capture{provider,"01",path,generation,snapshot,extent,records},limits,processed,bytes,scan,buckets,attribution,reason,coverage,summary}

def oversized_text(report: Reader.Report) -> Reader.Report:
  Reader.Report{capture,limits,processed,bytes,scan,buckets,attribution,_,coverage,summary} = report
  Reader.Report{capture,limits,processed,bytes,scan,buckets,attribution,String.repeat("界",350000n),coverage,summary}

def encoding(+report: Reader.Report) -> IO(Unit):
  do IO<Unit>:
    +wide : Json.Json <- parsed(Json.parse(Command.counters(Counts.Counters{"9007199254740993","0","","","9007199254740995"})))
    field(wide,"input_tokens","\"9007199254740993\"","counter above2^53 stays an exact decimal string")
    field(wide,"cached_input_tokens","\"0\"","known zero stays distinct from a null unknown counter")
    encoded : String <- need(String,Command.encode(reidentified(report),"recorded \"quote\"\n😀"))
    +value : Json.Json <- parsed(Json.parse(encoded))
    field(Json.field(value,"capture"),"source_id","\"9007199254740993\"","source IDs above2^53 never pass through floating point")
    field(Json.field(value,"capture"),"generation","\"9007199254740995\"","generation IDs above2^53 stay exact")
    field(Json.field(value,"capture"),"snapshot","\"9007199254740997\"","snapshot IDs above2^53 stay exact")
    field(value,"text",Json.quote("recorded \"quote\"\n😀"),"text survives Unicode and JSON escaping exactly")
    refused(String,Command.encode(report,String.repeat("\"",524288n)),"usage_output_limit","escaped envelope and newline enforce the1MiB budget")
    refused(String,Command.encode(report,String.repeat("😀",262144n)),"usage_output_limit","output limit counts actual UTF8 bytes rather than scalars")
    refused(String,Command.encode(bad_identity(report),""),"usage_report_integrity","noncanonical source identity cannot become a success envelope")
    refused(String,Reader.render(oversized_text(report)),"usage_output_limit","full readable renderer refuses oversized text without truncation")

def limits(+self: String,+db: U32,+snapshot: String,+codex_snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +limited : Json.Json <- good(self,["limited",snapshot])
    field(limited,"scan_complete","false","configured record cap produces an explicit partial scan")
    field(limited,"bucket_complete","false","partial scan never claims complete whole-capture buckets")
    field(limited,"attribution_complete","false","partial scan never claims complete whole-capture attribution")
    field(limited,"processed_records","2","configured record cap stops after exactly two records")
    field(Json.field(Json.field(limited,"summary"),"observed"),"input_tokens","\"12\"","partial report exposes only the retained processed subtotal")
    zero : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run_steps(db,snapshot,Reader.defaults(),0)
    refused(Reader.Report,zero,"usage_step_limit","zero-step cancellation emits no complete report")
    available(db,"zero-step cancellation confirms owned rollback")
    one : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run_steps(db,codex_snapshot,Reader.defaults(),1)
    refused(Reader.Report,one,"usage_step_limit","exhaustion after a real raw window is explicit failure")
    available(db,"post-window cancellation releases the pinned read view")
    invalid : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run_steps(db,snapshot,Reader.defaults(),1000002)
    refused(Reader.Report,invalid,"usage_invalid_request","unsupported step limit fails before acquiring a transaction")
    available(db,"invalid step configuration leaves the connection reusable")
    bad(self,["cancel",codex_snapshot],"usage_step_limit","worker step exhaustion")

def caller(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO main.settings(key,value) VALUES('synthetic.usage.caller','pending')",[])
    result : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run(db,snapshot,Reader.defaults())
    refused(Reader.Report,result,"usage_transaction_unavailable","adapter refuses an existing caller transaction")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT value FROM main.settings WHERE key='synthetic.usage.caller'",[],1)
    check(String.eq(Store.field(Store.first(rows),0n),"pending"),"caller pending writes remain after refused ownership")
    Store.exec(db,"ROLLBACK",[])
    gone : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM main.settings WHERE key='synthetic.usage.caller'",[],1)
    check(String.eq(Store.field(Store.first(gone),0n),"0"),"caller can still roll back its original transaction")

def invalid(+self: String,+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    bad(self,["default"],"usage","missing snapshot")
    bad(self,["default",snapshot,"extra"],"usage","extra arguments")
    bad(self,["default","0"],"usage_invalid_request","zero identity")
    bad(self,["default","01"],"usage_invalid_request","noncanonical identity")
    bad(self,["default","9223372036854775808"],"usage_invalid_request","overflowing SQLite identity")
    bad(self,["default","999999"],"usage_not_found","missing accepted capture")
    malformed : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run(db,snapshot,Reader.Limits{0,1,1,1})
    refused(Reader.Report,malformed,"usage_invalid_request","zero configured record budget is rejected")
    available(db,"invalid configured limits do not leave a read transaction")

def retained(+self: String,+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    relocation : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/mv",["owned café.jsonl","retained-owned.jsonl"],"",1024,10000))
    moved(relocation)
    +old : Json.Json <- good(self,["default",snapshot])
    field(Json.field(Json.field(old,"summary"),"observed"),"input_tokens","\"20\"","owned usage remains readable after original source relocation")
    Store.write_text("owned café.jsonl","w",row("new","999","77"))
    +newer : String <- Store.import_file(db,"claude","owned café.jsonl")
    check(Bool.not(String.eq(snapshot,newer)),"rewrite creates a distinct accepted snapshot")
    +pinned : Json.Json <- good(self,["default",snapshot])
    field(Json.field(Json.field(pinned,"summary"),"observed"),"input_tokens","\"20\"","old selected capture never follows the new generation")
    Store.exec(db,"UPDATE main.raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM main.records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{newer}])
    bad(self,["default",newer],"usage_raw_integrity","corrupt retained raw")
    corrupt : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run(db,newer,Reader.defaults())
    refused(Reader.Report,corrupt,"usage_raw_integrity","direct corrupted capture returns a structured failure")
    available(db,"corrupt raw failure rolls back the owned transaction")

def codex_result(+self: String,snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +value : Json.Json <- good(self,["default",snapshot])
    field(value,"processed_records","130","adapter drives across the128-row raw window boundary")
    field(value,"scan_complete","true","multi-step scan reaches the exact retained extent")
    +summary : Json.Json = Json.field(value,"summary")
    field(summary,"provider","\"codex\"","Codex summary has its own discriminator")
    field(summary,"category","\"ordinary\"","ordinary accounting is not silently treated as reviewer usage")
    field(summary,"recorded_parent_thread_id","null","missing recorded parent is explicit null")
    field(Json.field(summary,"accounted"),"input_tokens","\"170\"","cross-window normalized Codex input remains exact")
    field(Json.field(summary,"accounted"),"cached_input_tokens","\"70\"","cross-window cached input remains separate")
    field(Json.field(summary,"accounted"),"cache_creation_input_tokens","null","nonapplicable Codex cache creation is not invented zero")

def empty(+self: String,+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("empty-cli.jsonl","w","")
    snapshot : String <- Store.import_file(db,"claude","empty-cli.jsonl")
    +value : Json.Json <- good(self,["default",snapshot])
    field(value,"scan_complete","true","empty retained extent can be fully scanned")
    field(value,"bucket_complete","false","empty capture does not invent complete usage buckets")
    field(Json.field(Json.field(value,"summary"),"observed"),"input_tokens","null","empty capture has unknown usage instead of zero")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/session-usage-cli.sqlite")
    Store.write_text("owned café.jsonl","w",claude())
    +source : String <- Paths.resolve("owned café.jsonl")
    +snapshot : String <- Store.import_file(db,"claude",source)
    report : Reader.Report <- full(self,db,snapshot,source)
    encoding(report)
    Store.write_text("codex-cli.jsonl","w",codex())
    +codex_snapshot : String <- Store.import_file(db,"codex","codex-cli.jsonl")
    codex_result(self,codex_snapshot)
    limits(self,db,snapshot,codex_snapshot)
    caller(db,snapshot)
    invalid(self,db,snapshot)
    empty(self,db)
    retained(self,db,snapshot)
    IO.try(Unit,Sql.close(db))

def worker(+db: U32,mode: String,args: List<String>) -> IO(Unit):
  match mode args:
    case "default" args: Command.command(db,args)
    case "limited" Con{snapshot,Nil{}}: Command.selected(db,snapshot,Reader.Limits{2,1048576,100,1048576})
    case "cancel" Con{snapshot,Nil{}}:
      do IO<Unit>:
        result : Result<&2,&2,Reader.Failure,Reader.Report> <- Command.run_steps(db,snapshot,Reader.defaults(),1)
        report : Reader.Report <- Command.require(Reader.Report,result)
        text : String <- Command.require(String,Command.rendered(report))
        IO.print(text)
    case _ _: IO.die(Unit,2,"Unsupported synthetic usage worker mode")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case _ <> "worker" <> mode <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/session-usage-cli.sqlite")
        worker(db,mode,rest)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Unsupported whole-capture usage CLI test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    cwd : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(cwd,"juice-bend-test-session_usage_cli."),"Run only through scripts/test in an isolated synthetic directory")
    args : List<String> <- IO.args()
    dispatch(args)
