import Base
import ../src/sources.bend as Sources
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def process(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),name)

def command(program: String,args: List<String>,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program,args,"",8192,2000))
    process(result,name)

def record(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"source-fixture\",\"message\":{\"content\":" ++
    Json.quote(text) ++ "}}\n"

def files(count: Nat) -> IO(Unit):
  match count:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+ +rest:
      +i = U32.from_nat(rest)
      do IO<Unit>:
        Store.write_text("source-root/item-" ++ U32.show(i) ++ ".jsonl","w",
          record("source discovery " ++ U32.show(i)))
        files(rest)

def scalar(db: U32,sql: String) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],1)
    return Store.field(Store.first(rows),0n)

def parse(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{error}:
      IO.die(Json.Json,1,"Refresh emitted invalid JSON: " ++ error)

def number(value: Json.Json) -> String:
  match value:
    case Json.JNumber{lexeme}:
      lexeme
    case _:
      ""

def refresh(db: U32,self: String) -> IO(Json.Json):
  do IO<Json.Json>:
    raw : String <- Sources.refresh_all(db,".build",self)
    parse(Json.parse(raw))

def worker(+dir: String,provider: String,path: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(dir ++ "/juice-bend.sqlite")
    snapshot : String <- Store.import_file(db,provider,path)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"accepted_snapshot\":" ++ Json.quote(snapshot) ++ "}")

def bad_root_result(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  assert(Bool.not(U32.is_eq(code,0)),"source root rejects a regular file")

def bad_root(self: String,path: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String &String),
      Process.run(self,["bad-root",path],"",8192,5000))
    bad_root_result(result)

def disabled(+db: U32,+self: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    Sources.disable(db,"claude",root)
    Store.write_text("source-root/item-0.jsonl","a",record("disabled append must wait"))
    +stopped : Json.Json <- refresh(db,self)
    assert(String.eq(number(Json.field(stopped,"attempted")),"0"),
      "disabled root excludes both discovery and its registered descendants")
    snapshots : String <- scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1")
    assert(String.eq(snapshots,"11"),"disabled root cannot publish a new append")
    Sources.add(db,"claude",root)
    +resumed : Json.Json <- refresh(db,self)
    assert(Bool.not(String.eq(number(Json.field(resumed,"attempted")),"0")),
      "reenabling root resumes bounded refresh")
    Sources.disable(db,"claude",root)
    standalone : String <- Store.import_file(db,"claude","outside/standalone.jsonl")
    Store.write_text("outside/standalone.jsonl","a",record("explicit standalone append"))
    +standalone_report : Json.Json <- refresh(db,self)
    assert(String.eq(number(Json.field(standalone_report,"succeeded")),"1"),
      "explicit standalone import remains refreshable with roots disabled")
    before : String <- scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1")
    command("/bin/rm",["--","outside/standalone.jsonl"],"remove only the synthetic registered source")
    +missing : Json.Json <- refresh(db,self)
    assert(String.eq(number(Json.field(missing,"failed")),"1"),
      "missing registered source becomes a per-file failure")
    after : String <- scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1")
    assert(String.eq(before,after),"missing source leaves accepted snapshots intact")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/juice-bend.sqlite")
    Store.write_text("unconfigured.jsonl","w",record("must not be scanned"))
    +empty : Json.Json <- refresh(db,self)
    assert(String.eq(number(Json.field(empty,"attempted")),"0"),
      "empty library performs no implicit source scan")
    initial : List<&2,List<&2,Sql.Cell>> <- Sources.list(db)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,initial),"no provider roots are enabled by default")
    command("/bin/mkdir",["-p","source-root/nested","outside"],
      "create only isolated synthetic source directories")
    files(10n)
    Store.write_text("source-root/nested/full.json","w",record("nested json capture"))
    Store.write_text("source-root/failure.jsonl","w",record("injected failing import"))
    Store.write_text("source-root/ignored.txt","w",record("wrong extension"))
    Store.write_text("outside/standalone.jsonl","w",record("unconfigured external capture"))
    command("/bin/ln",["-s","../outside/standalone.jsonl","source-root/link.jsonl"],
      "create synthetic file symlink")
    command("/bin/ln",["-s","../outside","source-root/link-directory"],
      "create synthetic directory symlink")
    +root : String <- Paths.resolve("source-root")
    Sources.add(db,"claude","source-root")
    Sources.add(db,"claude",root ++ "/.")
    +rows : List<&2,List<&2,Sql.Cell>> <- Sources.list(db)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),1n),
      "relative and canonical root aliases persist one root")
    assert(String.eq(Store.field(Store.first(rows),1n),root),
      "stored source root is canonical")
    bad_root(self,"source-root/item-0.jsonl")
    Store.exec(db,"CREATE TRIGGER synthetic_source_failure BEFORE INSERT ON sources WHEN NEW.locator LIKE '%/failure.jsonl' BEGIN SELECT RAISE(ABORT,'synthetic source failure'); END",[])
    +first : Json.Json <- refresh(db,self)
    assert(String.eq(number(Json.field(Json.field(first,"discovery"),"files")),"12"),
      "recursive discovery filters extensions and excludes symlink files and directories")
    assert(String.eq(number(Json.field(first,"attempted")),"4"),
      "first discovery imports only four new files")
    assert(String.eq(number(Json.field(first,"failed")),"1"),
      "one failed child import does not abort the refresh batch")
    +second : Json.Json <- refresh(db,self)
    assert(U32.is_le(Store.number(number(Json.field(second,"attempted"))),8),
      "refresh has an eight-file upper bound")
    third : Json.Json <- refresh(db,self)
    count : String <- scalar(db,"SELECT count(*) FROM sources")
    assert(String.eq(count,"11"),"successive bounded refreshes progress beyond the first discovery page")
    outside : String <- scalar(db,"SELECT count(*) FROM sources WHERE locator LIKE '%/outside/%' OR locator LIKE '%link%' OR locator LIKE '%ignored.txt'")
    assert(String.eq(outside,"0"),"discovery never imports symlink targets or unrelated file types")
    fourth : Json.Json <- refresh(db,self)
    stable : String <- scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1")
    assert(String.eq(stable,"11"),"unchanged refresh retains existing accepted snapshots")
    attempts : String <- scalar(db,"SELECT attempts FROM source_root_files WHERE locator LIKE '%/failure.jsonl'")
    assert(U32.is_gt(Store.number(attempts),1),"failed candidates retry without starving unattempted files")
    disabled(db,self,root)
    Store.exec(db,"DROP TRIGGER synthetic_source_failure",[])
    IO.try(Unit,Sql.close(db))
    +reopened : U32 <- Store.open(".build/juice-bend.sqlite")
    persisted : List<&2,List<&2,Sql.Cell>> <- Sources.list(reopened)
    assert(String.eq(Store.field(Store.first(persisted),2n),"0"),
      "disabled roots persist after library close and reopen")
    IO.try(Unit,Sql.close(reopened))
    IO.print("Sources suite passed")

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "--data-dir" <> dir <> "import" <> provider <> path <> []:
      worker(dir,provider,path)
    case _ <> "bad-root" <> path <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/juice-bend.sqlite")
        Sources.add(db,"claude",path)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Invalid sources test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
