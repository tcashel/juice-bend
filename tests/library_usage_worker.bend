import Base
import ../src/library_usage_worker.bend as W
import ../src/library_usage.bend as L
import ../src/library_usage_types.bend as T
import ../src/session_usage.bend as S
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ../src/json.bend as J
import ../src/paths.bend as Paths
import ../src/reader_document.bend as Reader
import ../src/reader_wire.bend as ReaderWire
import ../src/library_usage_page_wire.bend as PageWire

def check(valid: Bool,label: String) -> IO(Unit):
  match valid:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def nonce(value: Result<&2,&2,S.Failure,U32>,expected: U32) -> Bool:
  match value:
    case Done{actual}: U32.is_eq(actual,expected)
    case Fail{_}: False{}

def refused_nonce(value: Result<&2,&2,S.Failure,U32>) -> Bool:
  match value:
    case Fail{S.Failure{code,_}}: String.eq(code,"library_usage_arguments")
    case Done{_}: False{}

def failed(value: W.answer(),expected: String) -> Bool:
  match value:
    case Fail{S.Failure{code,_}}: String.eq(code,expected)
    case Done{_}: False{}

def parse_checks() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(W.command(),"library-usage-v1") && String.eq(W.command_capture(),"library-usage-capture-v1"),"worker routes are distinct versioned commands")
    check(nonce(W.parse(["1"]),1) && nonce(W.parse(["4294967295"]),4294967295),"canonical nonzero U32 endpoints are admitted")
    check(refused_nonce(W.parse([])) && refused_nonce(W.parse(["1","extra"])),"missing and extra arguments fail exact arity")
    check(refused_nonce(W.parse(["0"])) && refused_nonce(W.parse(["01"])) && refused_nonce(W.parse(["+1"])),"zero and noncanonical request identities are refused")
    check(refused_nonce(W.parse(["4294967296"])) && refused_nonce(W.parse([" 1"])) && refused_nonce(W.parse(["1\n"])),"overflow and whitespace cannot change request identity")
    check(refused_nonce(W.parse([String.repeat("9",4096n)])) && refused_nonce(W.parse(["1\0"])),"overlong and NUL request inputs fail bounded admission")
    check(Nat.is_eq(W.fuel(),1000513n),"driver fuel covers maximum records plus two steps per source and final completion")

def metadata_budget() -> IO(Unit):
  +prefix : String = String.repeat("é",524286n)
  do IO<Unit>:
    check(String.eq(W.optional_response(prefix,"xy"),prefix ++ "xy}"),"optional metadata admits exactly 1 MiB including LF using UTF8 byte width")
    check(String.eq(W.optional_response(prefix,"xyz"),prefix ++ "}"),"one extra UTF8 byte omits only optional metadata without truncating canonical text")

def parsed(value: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match value:
    case Done{json}: IO.pure(J.Json,json)
    case Fail{_}: IO.die(J.Json,1,"FAIL worker output is not JSON")

def text(value: W.answer()) -> IO(String):
  match value:
    case Done{text}: IO.pure(String,text)
    case Fail{S.Failure{code,message}}: IO.die(String,1,"FAIL " ++ code ++ ": " ++ message)

def field(value: J.Json,name: String,wanted: String,label: String) -> IO(Unit):
  check(String.eq(J.encode(J.field(value,name)),wanted),label)

def command_done(value: U32 & (String & String)) -> IO(Unit):
  (code,_) = value
  check(U32.is_eq(code,0),"owned synthetic fixture filesystem operation succeeded")

def primitive(program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",4096,5000))
    command_done(result)

def absent_result(value: Result<&1,&1,U32 & String,File>,label: String) -> IO(Unit):
  match value:
    case Fail{(code,_)}: check(U32.is_eq(code,2),label)
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        check(False{},label)

def absent(path: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent_result(result,label)

def row(id: String,input: String,output: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"synthetic-library-worker\",\"message\":{\"id\":" ++ J.quote(id) ++
    ",\"model\":\"synthetic\",\"usage\":{\"input_tokens\":" ++ input ++
    ",\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":" ++ output ++
    "},\"content\":\"synthetic retained reply\"}}\n"

def fixture() -> String:
  row("one","10","1") ++
    String.repeat("{\"type\":\"user\",\"sessionId\":\"synthetic-library-worker\",\"message\":{\"role\":\"user\",\"content\":\"RAW_BODY_ONLY café 中文 🙂\"}}\n",41n) ++
    row("one","30","5") ++ row("two","7","2")

def make(+root: String,+source: String,raw: String) -> IO(String):
  do IO<String>:
    primitive("/bin/mkdir",["-m","700",root])
    +db : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    Store.write_text(source,"w",raw)
    snapshot : String <- Store.import_file(db,"claude",source)
    IO.try(Unit,Sql.close(db))
    primitive("/bin/rm",["--",source])
    return snapshot

def capture(source: String,snapshot: String) -> S.Capture:
  S.Capture{"claude","1",source,"1",snapshot,U32.from_nat(List.length(&2,U32,D.encode(fixture()))),44}

def one_row(value: J.Json) -> IO(J.Json):
  match value:
    case J.JArray{[row]}: IO.pure(J.Json,row)
    case _: IO.die(J.Json,1,"FAIL selected explicit library must contain one retained capture row")

def summary(+json: J.Json,source: String,snapshot: String,request: U32) -> IO(Unit):
  do IO<Unit>:
    field(json,"kind","\"library_usage\"","worker emits the actual library wire kind")
    field(json,"version","1","worker reports the versioned wire schema")
    field(json,"nonce",U32.show(request),"worker echoes the exact admitted request nonce")
    field(json,"selected_sources","1","explicit root excludes the other synthetic library")
    field(json,"verified_records","44","worker scans the whole captured extent beyond one reader page")
    field(json,"catalog_complete","true","complete catalog remains an explicit observed property")
    +row : J.Json <- one_row(J.field(json,"rows"))
    field(row,"capture",S.capture_text(capture(source,snapshot)),"wire retains every exact selected capture descriptor field")
    field(row,"status","\"eligible\"","raw-backed own-session fixture is eligible only with matching retained source identity")
    field(J.field(row,"counts"),"input","\"37\"","actual reducer counts later mirror maxima plus the second call")
    field(J.field(row,"counts"),"output","\"7\"","actual reducer retains recorded output total")
    check(Bool.not(String.contains(J.encode(json),"RAW_BODY_ONLY")),"summary wire does not leak raw transcript bodies")

def other_identity(root: String) -> IO(Unit):
  do IO<Unit>:
    value : W.answer() <- W.dispatch(root,["25"])
    encoded : String <- text(value)
    json : J.Json <- parsed(J.parse(encoded))
    +row : J.Json <- one_row(J.field(json,"rows"))
    field(row,"status","\"identity_unknown\"","different source stem cannot invent own-session usage attribution")
    field(J.field(row,"counts"),"input","\"\"","unattributed copied counters remain unknown in library totals")

def child(self: String,root: String,command: String,args: List<String>,home: String) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run("/usr/bin/env",
    ("HOME=" ++ home) <> self <> "route" <> "--data-dir" <> root <> command <> args,"",2097152,60000))

def good(value: U32 & (String & String)) -> IO(J.Json):
  (code,(+out,err)) = value
  do IO<J.Json>:
    check(U32.is_eq(code,0) && String.is_empty(err) && String.ends_with(out,"\n"),"actual worker emits one complete JSON line after successful close")
    parsed(J.parse(String.trim(out)))

def bad(value: U32 & (String & String),expected: String,label: String) -> IO(Unit):
  (code,(out,err)) = value
  do IO<Unit>:
    check(U32.is_eq(code,2) && String.is_empty(out),label)
    +json : J.Json <- parsed(J.parse(String.trim(err)))
    field(json,"kind","\"library_usage_error\"","failure uses structured JSON on stderr")
    field(json,"code",J.quote(expected),"failure keeps its typed code without private input interpolation")

def roots(+self: String,+cwd: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    missing : U32 & (String & String) <- child(self,cwd ++ "/missing-root",W.command(),["7"],root)
    bad(missing,"library_usage_open","missing explicit root fails without ordinary app initialization")
    absent(cwd ++ "/missing-root","worker does not create the missing root")
    absent(root ++ "/Library","worker does not derive or initialize a HOME default")
    missing_args : U32 & (String & String) <- child(self,cwd ++ "/missing-root",W.command(),[],root)
    bad(missing_args,"library_usage_arguments","malformed arguments are refused before missing-root access")
    relative : W.answer() <- W.dispatch("relative",["1"])
    check(failed(relative,"library_usage_root"),"relative roots are refused before SQLite open")
    empty : W.answer() <- W.dispatch("",["1"])
    check(failed(empty,"library_usage_root"),"empty root cannot invoke a default")
    nul : W.answer() <- W.dispatch(root ++ "\0",["1"])
    check(failed(nul,"library_usage_root"),"NUL root cannot truncate the explicit database path")

def succeeded(value: Result<&2,&2,S.Failure,Unit>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def released(+db: U32,label: String) -> IO(Unit):
  do IO<Unit>:
    begun : Result<&2,&2,S.Failure,Unit> <- S.start(db)
    ended : Result<&2,&2,S.Failure,Unit> <- S.cleanup(db)
    check(succeeded(begun) && succeeded(ended),label)

def fuel_failure(value: Result<&2,&2,S.Failure,T.Report>) -> Bool:
  match value:
    case Fail{S.Failure{code,_}}: String.eq(code,"library_usage_step_limit")
    case Done{_}: False{}

def transactions(+root: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open_existing(root ++ "/juice-bend.sqlite",0))
    started : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    stopped : Result<&2,&2,S.Failure,T.Report> <- W.begun(started,0n)
    check(fuel_failure(stopped),"exhausted worker fuel cannot publish a partial aggregate")
    released(db,"fuel exhaustion rolls back its owned transaction before returning")
    zero : W.answer() <- W.execute(db,0)
    check(failed(zero,"library_usage_arguments"),"typed execute rejects a zero nonce before BEGIN")
    released(db,"invalid typed execute leaves the read handle transaction-free")
    Store.exec(db,"BEGIN DEFERRED",[])
    occupied : W.answer() <- W.execute(db,3)
    check(failed(occupied,"usage_transaction_unavailable"),"worker refuses an existing caller transaction")
    Store.exec(db,"ROLLBACK",[])
    released(db,"refused begin preserves the caller transaction for its own rollback")
    IO.try(Unit,Sql.close(db))

def expected_result(value: W.answer(),code: String) -> Bool:
  match value:
    case Done{_}: String.is_empty(code)
    case Fail{S.Failure{actual,_}}: String.eq(actual,code)

def reopen_many(left: Nat,+root: String,+code: String) -> IO(Unit):
  match left:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        value : W.answer() <- W.dispatch(root,["1"])
        Store.checked(expected_result(value,code),"Worker failed to release a read-only handle before bounded reopen")
        reopen_many(rest,root,code)

def handle_lifetimes(+cwd: String) -> IO(Unit):
  +empty = cwd ++ "/empty-library"
  +foreign = cwd ++ "/foreign-library"
  do IO<Unit>:
    primitive("/bin/mkdir",["-m","700",empty,foreign])
    db : U32 <- Store.open(empty ++ "/juice-bend.sqlite")
    IO.try(Unit,Sql.close(db))
    raw : U32 <- IO.try(U32,Sql.open(foreign ++ "/juice-bend.sqlite"))
    IO.try(Unit,Sql.close(raw))
    reopen_many(66n,empty,"")
    check(True{},"66 successful worker roots do not exhaust the 64-handle registry")
    reopen_many(66n,foreign,"usage_database_error")
    check(True{},"66 typed schema failures close owned handles without initializing the foreign database")
    +inspect : U32 <- IO.try(U32,Sql.open_existing(foreign ++ "/juice-bend.sqlite",0))
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(inspect,"SELECT count(*) FROM sqlite_master",[],1)
    check(String.eq(Store.field(Store.first(rows),0n),"0"),"read-only worker leaves a foreign empty schema unchanged")
    IO.try(Unit,Sql.close(inspect))

def capture_bad(value: Result<&2,&2,S.Failure,W.CaptureRequest>) -> Bool:
  match value:
    case Fail{S.Failure{code,_}}: String.eq(code,"library_usage_capture_arguments")
    case Done{_}: False{}

def changed(value: S.Capture,field: U32) -> S.Capture:
  S.Capture{provider,source,locator,generation,snapshot,extent,records} = value
  match field:
    case 0: S.Capture{"codex",source,locator,generation,snapshot,extent,records}
    case 1: S.Capture{provider,"2",locator,generation,snapshot,extent,records}
    case 2: S.Capture{provider,source,locator ++ ".other",generation,snapshot,extent,records}
    case 3: S.Capture{provider,source,locator,"2",snapshot,extent,records}
    case 4: S.Capture{provider,source,locator,generation,"999",extent,records}
    case 5: S.Capture{provider,source,locator,generation,snapshot,U32.inc(extent),records}
    case _: S.Capture{provider,source,locator,generation,snapshot,extent,U32.inc(records)}

def identity_refusals(left: Nat,+db: U32,+original: S.Capture,+index: U32) -> IO(Unit):
  match left:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        value : W.answer() <- W.execute_capture(db,W.CaptureRequest{17,changed(original,index),0})
        check(failed(value,Bool.pick(String,U32.is_eq(index,4),"usage_not_found","library_usage_capture_identity")),"changed capture field cannot redirect retained transcript activation")
        released(db,"typed exact-capture refusal releases its owned read transaction")
        identity_refusals(rest,db,original,U32.inc(index))

def original_event(parts: List<&2,Reader.Part>,+snapshot: String,+record: String) -> Bool:
  match parts:
    case []: False{}
    case Reader.Part{Reader.PartKey{actual,id,event,_},Reader.EventHeading{},_,_,_,_} <> rest:
      (String.eq(actual,snapshot) && String.eq(id,record) && U32.is_eq(event,0)) || original_event(rest,snapshot,record)
    case _ <> rest: original_event(rest,snapshot,record)

def accepted_page(value: Result<&2,&2,String,PageWire.Page>,expected: String) -> IO(Unit):
  match value:
    case Fail{_}: check(False{},"actual capture worker envelope must pass the parent page admission")
    case Done{PageWire.Page{_,_,_,+text,document}}:
      check(String.eq(text,expected) && String.eq(Reader.text(document),text),"actual worker envelope passes the independent parent decoder without changing canonical text")

def page(+json: J.Json,+expected: S.Capture,+start: U32,selected: String,needle: String) -> IO(Unit):
  S.Capture{_,_,_,_,+snapshot,_,_} = expected
  do IO<Unit>:
    field(json,"kind","\"library_usage_capture\"","drilldown uses distinct versioned response kind")
    field(json,"nonce","19","drilldown preserves its exact request nonce")
    field(json,"capture",S.capture_text(expected),"drilldown returns the selected full descriptor unchanged")
    +value : J.Json = J.field(json,"page")
    field(value,"start",U32.show(start),"drilldown starts at the requested physical record")
    field(value,"requested_records","40","drilldown page size remains bounded to forty records")
    field(value,"selected_records",selected,"drilldown reports exact remaining record coverage")
    field(value,"complete_export","false","bounded page never claims a complete export")
    +canonical : String = J.text(J.field(value,"text"))
    accepted_page(PageWire.decode(json,19,expected,start,7),canonical)
    +document : Reader.Document = ReaderWire.decode_for(canonical,J.field(value,"reader_view"),7,snapshot)
    check(String.contains(canonical,needle),"retained transcript body is readable after source deletion")
    check(Reader.structured(document) && String.eq(Reader.text(document),canonical),"typed descriptors reconstruct the exact canonical transcript text")
    check(original_event(Reader.parts(document),snapshot,U32.show(start)),"typed event descriptors preserve original physical record and event ordinals")
    +absent : Reader.Document = ReaderWire.decode_for(canonical,J.JNull{},8,snapshot)
    check(Bool.not(Reader.structured(absent)) && String.eq(Reader.text(absent),canonical),"absent optional metadata preserves the complete plain transcript")
    unknown : J.Json <- parsed(J.parse("{\"version\":99,\"mode\":\"structured\",\"parts\":[]}"))
    +fallback : Reader.Document = ReaderWire.decode_for(canonical,unknown,9,snapshot)
    check(Bool.not(Reader.structured(fallback)) && String.eq(Reader.text(fallback),canonical),"unknown optional metadata version preserves the complete plain transcript")

def drilldown(+self: String,+root: String,+expected: S.Capture) -> IO(Unit):
  +encoded = S.capture_text(expected)
  +fields = String.take(encoded,Nat.sub(String.length(encoded),1n))
  do IO<Unit>:
    check(capture_bad(W.parse_capture(["19",encoded])) && capture_bad(W.parse_capture(["19",encoded,"0","extra"])),"capture request requires exact argument count")
    check(capture_bad(W.parse_capture(["0",encoded,"0"])) && capture_bad(W.parse_capture(["19",encoded,"01"])),"capture nonce and start use canonical bounded numbers")
    check(capture_bad(W.parse_capture(["19","{}","0"])) && capture_bad(W.parse_capture(["19",String.repeat("x",16385n),"0"])),"malformed and overlarge capture descriptors cannot reach SQLite")
    check(capture_bad(W.parse_capture(["19",fields ++ ",\"extra\":0}","0"])) &&
      capture_bad(W.parse_capture(["19",fields ++ ",\"source_id\":\"1\"}","0"])),"unknown and duplicate capture fields cannot weaken exact identity admission")
    first : U32 & (String & String) <- child(self,root,W.command_capture(),["19",encoded,"0"],root)
    first_json : J.Json <- good(first)
    page(first_json,expected,0,"40","RAW_BODY_ONLY café 中文 🙂")
    late : U32 & (String & String) <- child(self,root,W.command_capture(),["19",encoded,"40"],root)
    late_json : J.Json <- good(late)
    page(late_json,expected,40,"4","synthetic retained reply")
    +db : U32 <- IO.try(U32,Sql.open_existing(root ++ "/juice-bend.sqlite",0))
    identity_refusals(7n,db,expected,0)
    IO.try(Unit,Sql.close(db))

def append_latest(+root: String,+source: String,old: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open_existing(root ++ "/juice-bend.sqlite",1))
    Store.write_text(source,"w",fixture() ++ row("later","1","1"))
    latest : String <- Store.import_file(db,"claude",source)
    check(Bool.not(String.eq(latest,old)),"synthetic append publishes a distinct latest snapshot before exact old capture activation")
    IO.try(Unit,Sql.close(db))
    primitive("/bin/rm",["--",source])

def corrupted(+root: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open_existing(root ++ "/juice-bend.sqlite",1))
    Store.exec(db,"UPDATE raw SET digest='0000000000000000000000000000000000000000000000000000000000000000'",[])
    IO.try(Unit,Sql.close(db))
    +reader : U32 <- IO.try(U32,Sql.open_existing(root ++ "/juice-bend.sqlite",0))
    failure : W.answer() <- W.execute(reader,21)
    check(failed(failure,"usage_raw_integrity"),"worker exposes corruption as a typed failure without a wire aggregate")
    released(reader,"raw integrity failure closes the core-owned read transaction")
    IO.try(Unit,Sql.close(reader))
    fresh : W.answer() <- W.dispatch(root,["22"])
    check(failed(fresh,"usage_raw_integrity"),"fresh root path returns corruption only after closing its read handle")

def suite(+self: String,+cwd: String) -> IO(Unit):
  +root = cwd ++ "/library"
  +other = cwd ++ "/other-library"
  # The positive own-session fixture must match its recorded sessionId. The
  # separate other-library fixture deliberately retains a mismatched stem.
  +source = cwd ++ "/synthetic-library-worker.jsonl"
  do IO<Unit>:
    parse_checks()
    metadata_budget()
    +snapshot : String <- make(root,source,fixture())
    ignored : String <- make(other,cwd ++ "/other-synthetic-source.jsonl",row("other","777","888"))
    absent(source,"original synthetic source is absent before worker execution")
    first : U32 & (String & String) <- child(self,root,W.command(),["23"],other)
    json : J.Json <- good(first)
    summary(json,source,snapshot,23)
    other_identity(other)
    second : W.answer() <- W.dispatch(root,["24"])
    encoded : String <- text(second)
    json : J.Json <- parsed(J.parse(encoded))
    summary(json,source,snapshot,24)
    roots(self,cwd,root)
    transactions(root)
    handle_lifetimes(cwd)
    append_latest(root,source,snapshot)
    drilldown(self,root,capture(source,snapshot))
    escaped : J.Json <- parsed(J.parse(W.error(S.Failure{"bad\ncode","bad\0message\""})))
    field(escaped,"message",J.quote("bad\0message\""),"error JSON preserves controls safely rather than injecting output lines")
    corrupted(root)

def route(command: String,root: String,args: List<String>) -> IO(Unit):
  match command:
    case "library-usage-v1": W.root(root,args)
    case "library-usage-capture-v1": W.root_capture(root,args)
    case _: IO.die(Unit,2,"Invalid synthetic worker route")

def argv(args: List<String>,cwd: String) -> IO(Unit):
  match args:
    case self <> []: suite(self,cwd)
    case _ <> "route" <> "--data-dir" <> root <> command <> rest: route(command,root,rest)
    case _: IO.die(Unit,2,"Invalid synthetic test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    directory : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(directory,"juice-bend-test-library_usage_worker."),"Synthetic library worker runner only")
    cwd : String <- Paths.resolve(".")
    args : List<String> <- IO.args()
    argv(args,cwd)
