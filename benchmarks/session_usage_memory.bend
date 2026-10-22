import Base
import ../src/session_usage.bend as Session
import ../src/session_usage_claude.bend as Claude
import ../src/session_usage_counts.bend as Counts
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths

# Synthetic fixture creation and the retained-capture reader run in separate
# processes. This executable reports logical descriptor counts only. External
# owned-child wait4 measurement records native RSS independently.
def checked(ok: Bool,message: String) -> IO(Unit):
  Store.checked(ok,"Usage memory benchmark: " ++ message)

def command_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Done{(0,(out,_))}: IO.pure(String,out)
    case _: IO.die(String,1,"Usage memory benchmark: bounded OS primitive failed")

def command(program: String,args: List<String>) -> IO(String):
  do IO<String>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(program,args,"",8192,10000)
    command_result(result)

def root_shape(+root: String) -> Bool:
  String.starts_with(root,"/private/tmp/juice-bend-usage-memory-") && Nat.is_le(String.length(root),200n) &&
    Bool.not(String.contains(root,"\0")) && Bool.not(String.contains(String.drop(root,13n),"/"))

def regular(+path: String,directory: Bool) -> IO(Unit):
  do IO<Unit>:
    +mode : String <- command("/usr/bin/stat",["-q","-f","%Op|%l","--",path])
    checked(Bool.pick(Bool,directory,String.starts_with(mode,"40700|"),String.eq(String.trim(mode),"100600|1")),
      "expected private ordinary path with no symlink or hardlink")
    canonical : String <- Paths.resolve(path)
    checked(String.eq(canonical,path),"canonical path must match exactly")

def test_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Bool):
  match result:
    case Done{(0,_)}: IO.pure(Bool,True{})
    case Done{(1,_)}: IO.pure(Bool,False{})
    case _: IO.die(Bool,1,"Usage memory benchmark: file existence check failed")

def test(flag: String,path: String) -> IO(Bool):
  do IO<Bool>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",[flag,path],"",1024,2000)
    test_result(result)

def optional_present(exists: Bool,path: String) -> IO(Unit):
  match exists:
    case True{}: regular(path,False{})
    case False{}: IO.pure(Unit,Unit{})

def optional(+path: String) -> IO(Unit):
  do IO<Unit>:
    link : Bool <- test("-L",path)
    checked(Bool.not(link),"database sidecar is a symlink")
    exists : Bool <- test("-e",path)
    optional_present(exists,path)

def chmod(path: String) -> IO(Unit):
  do IO<Unit>:
    out : String <- command("/bin/chmod",["600",path])
    return Unit{}

def profile(value: String) -> Bool:
  match value:
    case "check": True{}
    case "short": True{}
    case "long": True{}
    case _: False{}

def count(kind: String) -> U32:
  match kind:
    case "check": 32
    case "short": 100001
    case _: 16000

def unit_bytes(kind: String) -> U32:
  match kind:
    case "short": 48
    case _: 1060

def accepted(kind: String) -> U32:
  match kind:
    case "check": 32
    case "short": 100000
    case _: 15827

def source(root: String) -> String:
  root ++ "/usage.jsonl"

def database(root: String) -> String:
  root ++ "/usage.sqlite"

def marker(root: String) -> String:
  root ++ "/.usage-memory-fixture-v1"

def description(+root: String,+kind: String) -> String:
  "{\"fixture\":\"usage-memory-v1\",\"root\":" ++ Json.quote(root) ++ ",\"profile\":" ++ Json.quote(kind) ++
    ",\"snapshot\":\"1\",\"records\":" ++ U32.show(count(kind)) ++ "}\n"

def decimal6(index: U32) -> String:
  +text = U32.show(index)
  String.repeat("0",Nat.sub(6n,String.length(text))) ++ text

def key(kind: String,index: U32) -> String:
  match kind:
    case "short": "call-" ++ decimal6(index)
    case _: String.repeat("k",506n) ++ decimal6(index)

def model(kind: String) -> String:
  match kind:
    case "short": "m"
    case _: String.repeat("模",170n) ++ "mm"

def row(+kind: String,index: U32) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"usage\",\"cwd\":\"/synthetic/usage-memory\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"id\":" ++
    Json.quote(key(kind,index)) ++ ",\"model\":" ++ Json.quote(model(kind)) ++
    ",\"content\":\"synthetic memory fixture\",\"usage\":{\"input_tokens\":10,\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":1}}}\n"

def chunk(fuel: Nat,+kind: String,+index: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: row(kind,index) ++ chunk(rest,kind,U32.inc(index))

def generate(fuel: Nat,+path: String,+kind: String,+index: U32,+left: U32,+bytes: U32) -> IO(U32):
  match fuel left:
    case _ 0: IO.pure(U32,bytes)
    case 0n _: IO.die(U32,1,"Usage memory benchmark: generation step bound exhausted")
    case 1n+rest _:
      +size = U32.min(left,128)
      +text = chunk(U32.to_nat(size),kind,index)
      +n = U32.from_nat(List.length(&2,U32,Domain.encode(text)))
      do IO<U32>:
        checked(U32.is_le(bytes,67108864) && U32.is_le(n,U32.sub(67108864,bytes)),"source generation exceeds64MiB")
        Store.write_text(path,"a",text)
        generate(rest,path,kind,U32.add(index,size),U32.sub(left,size),U32.add(bytes,n))

def size_finish(value: File & Result<&1,&1,U32 & String,U32>) -> IO(U32):
  (file,result) = value
  do IO<U32>:
    File.close(file)
    IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,result))

def file_size(path: String) -> IO(U32):
  do IO<U32>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    size_finish(result)

def text_finish(value: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,result) = value
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))

def exact_marker(+root: String,kind: String) -> IO(Unit):
  do IO<Unit>:
    regular(marker(root),False{})
    file : File <- IO.try(File,File.open(marker(root),"r"))
    read : File & Result<&1,&1,U32 & String,String> <- File.read(file,4096)
    text : String <- text_finish(read)
    checked(String.eq(text,description(root,kind)),"immutable synthetic marker mismatch")

def fixture(+root: String,+kind: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root) && profile(kind),"unsupported root or profile")
    created : String <- command("/bin/mkdir",["-m","700","--",root])
    regular(root,True{})
    Store.write_text(source(root),"w","")
    chmod(source(root))
    +bytes : U32 <- generate(1000n,source(root),kind,0,count(kind),0)
    regular(source(root),False{})
    actual : U32 <- file_size(source(root))
    checked(U32.is_eq(bytes,actual),"generated source byte accounting mismatch")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    chmod(database(root))
    Store.schema(db)
    snapshot : String <- Store.import_file(db,"claude",source(root))
    checked(String.eq(snapshot,"1"),"new fixture must have exact first snapshot")
    IO.try(Unit,Sql.close(db))
    regular(database(root),False{})
    +database_bytes : U32 <- file_size(database(root))
    checked(U32.is_le(database_bytes,268435456),"database exceeds256MiB fixture bound")
    Store.write_text(marker(root),"w",description(root,kind))
    chmod(marker(root))
    IO.print("{\"stage\":\"fixture_import\",\"profile\":" ++ Json.quote(kind) ++ ",\"records\":" ++ U32.show(count(kind)) ++
      ",\"source_bytes\":" ++ U32.show(bytes) ++ ",\"database_bytes\":" ++ U32.show(database_bytes) ++ ",\"snapshot\":\"1\"}")

def need_run(result: Result<&2,&1,Session.Failure,Session.Run>) -> IO(Session.Run):
  match result:
    case Done{run}: IO.pure(Session.Run,run)
    case Fail{Session.Failure{code,message}}: IO.die(Session.Run,1,code ++ ": " ++ message)

def drive(fuel: Nat,result: Session.Step) -> IO(Session.Report):
  match fuel result:
    case _ Session.Finished{report}: IO.pure(Session.Report,report)
    case _ Session.Failed{Session.Failure{code,message}}: IO.die(Session.Report,1,code ++ ": " ++ message)
    case 1n+rest Session.More{run,_}:
      do IO<Session.Report>:
        next : Session.Step <- Session.step(run)
        drive(rest,next)
    case 0n Session.More{run,_}:
      do IO<Session.Report>:
        closed : Result<&2,&2,Session.Failure,Unit> <- Session.cancel(run)
        IO.die(Session.Report,1,"Usage memory benchmark: scan step bound exhausted")

def claude_report(summary: Session.Summary) -> Claude.Report:
  match summary:
    case Session.ClaudeSummary{report}: report
    case _: Claude.report(Claude.new(""))

def counts_match(counts: Counts.Counters,+n: U32) -> Bool:
  Counts.equal(counts,Counts.Counters{U32.show(U32.mul(n,10)),U32.show(U32.mul(n,2)),U32.show(U32.mul(n,3)),"",U32.show(n)})

def outcome_claude(report: Claude.Report,+kind: String,+processed: U32,bytes: U32,+complete: Bool,reason: String) -> IO(Unit):
  Claude.Report{own,keys,+descriptors,observed,total,_,_,records,missing,incomplete,conflicts,mirrors,_,_} = report
  do IO<Unit>:
    checked(String.eq(own,"usage") && U32.is_eq(keys,accepted(kind)) && U32.is_eq(processed,accepted(kind)) &&
      U32.is_eq(records,accepted(kind)) && U32.is_eq(missing,0) && U32.is_eq(incomplete,0) && U32.is_eq(conflicts,0) && U32.is_eq(mirrors,0),
      "observed key prefix differs from independently predicted limit")
    checked(U32.is_eq(descriptors,U32.mul(accepted(kind),unit_bytes(kind))),"logical UTF8 descriptor bytes differ from independent field lengths")
    checked(counts_match(observed,accepted(kind)) && counts_match(total,accepted(kind)),"known recorded counters differ from exact accepted prefix")
    checked(Cmp.is_eq(Bool.cmp(complete,String.eq(kind,"check"))),"a configured stop cannot claim the complete capture")
    IO.print("{\"stage\":\"reader_scan\",\"profile\":" ++ Json.quote(kind) ++ ",\"processed_records\":" ++ U32.show(processed) ++
      ",\"verified_bytes\":" ++ U32.show(bytes) ++ ",\"logical_descriptor_bytes\":" ++ U32.show(descriptors) ++
      ",\"descriptor_cap\":16777216,\"key_cap\":100000,\"scan_complete\":" ++ Session.boolean(complete) ++
      ",\"stop_reason\":" ++ Json.quote(reason) ++ ",\"rss_is_separately_measured\":true}")

def outcome(report: Session.Report,+root: String,+kind: String) -> IO(Unit):
  Session.Report{Session.Capture{provider,sourceid,locator,generation,snapshot,_,records},_,processed,bytes,complete,_,_,reason,_,summary} = report
  do IO<Unit>:
    checked(String.eq(provider,"claude") && String.eq(sourceid,"1") && String.eq(generation,"1") && String.eq(snapshot,"1") &&
      String.eq(locator,source(root)) && U32.is_eq(records,count(kind)),"returned immutable fixture identity differs")
    outcome_claude(claude_report(summary),kind,processed,bytes,complete,reason)

def scan(+root: String,+kind: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root) && profile(kind),"unsupported root or profile")
    regular(root,True{})
    exact_marker(root,kind)
    regular(database(root),False{})
    optional(database(root) ++ "-wal")
    optional(database(root) ++ "-shm")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    Store.exec(db,"PRAGMA query_only=ON",[])
    result : Result<&2,&1,Session.Failure,Session.Run> <- Session.begin(db,"1",Session.defaults())
    run : Session.Run <- need_run(result)
    next : Session.Step <- Session.step(run)
    report : Session.Report <- drive(10000n,next)
    outcome(report,root,kind)
    Store.exec(db,"BEGIN DEFERRED",[])
    Store.exec(db,"ROLLBACK",[])
    IO.try(Unit,Sql.close(db))

def args(values: List<String>) -> IO(Unit):
  match values:
    case _ <> "fixture" <> root <> kind <> []: fixture(root,kind)
    case _ <> "scan" <> root <> kind <> []: scan(root,kind)
    case _: IO.die(Unit,2,"Usage: session-usage-memory fixture NEW_ROOT check|short|long | scan ROOT check|short|long")

def main() -> IO(Unit):
  do IO<Unit>:
    values : List<String> <- IO.args()
    args(values)
