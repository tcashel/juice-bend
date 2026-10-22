import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),name)

def record(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"collision\",\"cwd\":\"/synthetic/alpha\",\"message\":{\"role\":\"user\",\"content\":\"" ++ text ++ "\"}}\n"

def child_result(result: U32 & (String & String),message: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_eq(code,1) && String.contains(out ++ err,message),name)

def removed_status(result: U32 & (String & String)) -> IO(Unit):
  (code,output) = result
  assert(U32.is_eq(code,0),"remove only the created synthetic source fixture")

def child_failure(self: String,mode: String,path: String,arg: String,message: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[mode,path,arg],"",8192,20000))
    child_result(result,message,name)

def child_page(+path: String,snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    page : String <- Store.page(db,snapshot,0,100)
    IO.print(page)
    IO.try(Unit,Sql.close(db))

def child_import(path: String,source: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    snap : String <- Store.import_file(db,"claude",source)
    IO.print("Unexpected accepted snapshot " ++ snap)
    IO.try(Unit,Sql.close(db))

def fresh(+path: String,+source: String) -> IO(String):
  do IO<String>:
    Store.write_text(source,"w",record("retained corruption probe"))
    +db : U32 <- Store.open(path)
    snap : String <- Store.import_file(db,"claude",source)
    IO.try(Unit,Sql.close(db))
    return snap

def corrupt_bytes(+self: String) -> IO(Unit):
  do IO<Unit>:
    +snap : String <- fresh(".build/edge-corrupt-bytes.sqlite","edge-corrupt-bytes.jsonl")
    +db : U32 <- Store.open(".build/edge-corrupt-bytes.sqlite")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n)",[])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"page",".build/edge-corrupt-bytes.sqlite",snap,"integrity",
      "changed owned raw bytes are rejected by page")
    child_failure(self,"import",".build/edge-corrupt-bytes.sqlite","edge-corrupt-bytes.jsonl","integrity",
      "changed owned raw bytes cannot be blessed by refresh")

def corrupt_index(+self: String) -> IO(Unit):
  do IO<Unit>:
    +snap : String <- fresh(".build/edge-corrupt-index.sqlite","edge-corrupt-index.jsonl")
    +db : U32 <- Store.open(".build/edge-corrupt-index.sqlite")
    Store.exec(db,"DELETE FROM records WHERE ordinal=0",[])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"page",".build/edge-corrupt-index.sqlite",snap,"index",
      "missing location index is rejected by page")
    child_failure(self,"import",".build/edge-corrupt-index.sqlite","edge-corrupt-index.jsonl","corrupt",
      "missing first location cannot masquerade as verified empty prefix")

def corrupt_generation(+self: String) -> IO(Unit):
  do IO<Unit>:
    +snap : String <- fresh(".build/edge-corrupt-generation.sqlite","edge-corrupt-generation-a.jsonl")
    Store.write_text("edge-corrupt-generation-b.jsonl","w",record("retained corruption probe"))
    +db : U32 <- Store.open(".build/edge-corrupt-generation.sqlite")
    +other : String <- Store.import_file(db,"claude","edge-corrupt-generation-b.jsonl")
    Store.exec(db,"UPDATE records SET raw=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0) WHERE snapshot=?",
      [Sql.Cell.Integer{other},Sql.Cell.Integer{snap}])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"page",".build/edge-corrupt-generation.sqlite",snap,"binding",
      "identical bytes from another generation cannot replace evidence")
    child_failure(self,"import",".build/edge-corrupt-generation.sqlite","edge-corrupt-generation-a.jsonl","binding",
      "refresh verifies generation as well as matching content")

def corrupt_number(+self: String) -> IO(Unit):
  do IO<Unit>:
    +snap : String <- fresh(".build/edge-corrupt-number.sqlite","edge-corrupt-number.jsonl")
    +db : U32 <- Store.open(".build/edge-corrupt-number.sqlite")
    Store.exec(db,"UPDATE snapshots SET extent=4294967296",[])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"page",".build/edge-corrupt-number.sqlite",snap,"numeric",
      "out-of-range stored extent cannot silently become zero")
    child_failure(self,"import",".build/edge-corrupt-number.sqlite","edge-corrupt-number.jsonl","numeric",
      "refresh refuses invalid exact snapshot numeric metadata")

def tail_and_owned() -> IO(Unit):
  +head = record("anchor lemon evidence")
  +tail = {"{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"tail" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(".build/edge-tail.sqlite")
    Store.write_text("edge-source.jsonl","w",head ++ tail)
    +first : String <- Store.import_file(db,"claude","edge-source.jsonl")
    +old_page : String <- Store.page(db,first,0,100)
    assert(String.contains(old_page,"malformed"),"incomplete JSON tail is retained with explicit coverage")
    scalar(db,"SELECT count(*) FROM raw",[],"2","complete record and incomplete tail both retained")
    Store.write_text("edge-source.jsonl","a"," repaired\"}]}}\n" ++ record("third record"))
    +appended : String <- Store.import_file(db,"claude","edge-source.jsonl")
    assert(Bool.not(String.eq(first,appended)),"tail completion creates a distinct accepted snapshot")
    scalar(db,"SELECT count(*) FROM generations",[],"1","exact append retains generation")
    scalar(db,"SELECT count(*) FROM raw",[],"4","append reuses complete prefix and retains former tail")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{first},Sql.Cell.Integer{appended}],"1","complete prefix has stable raw occurrence identity")
    scalar(db,"SELECT body FROM events WHERE snapshot=? AND ordinal=1",
      [Sql.Cell.Integer{appended}],"tail repaired","completed tail projection matches independent expected text")
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=?",
      [Sql.Cell.Integer{appended}],"3","append does not duplicate complete prefix events")
    +new_page : String <- Store.page(db,appended,0,100)
    assert(String.contains(new_page,"tail repaired"),"completed tail is readable")
    prior : String <- Store.page(db,first,0,100)
    assert(String.eq(prior,old_page),"tail append leaves old accepted page byte-for-byte stable")
    unchanged : String <- Store.import_file(db,"claude","edge-source.jsonl")
    assert(String.eq(unchanged,appended),"unchanged tail-completed source reuses snapshot")
    +late : String <- Store.page(db,appended,2,1)
    assert(String.contains(late,"third record") && Bool.not(String.contains(late,"anchor lemon evidence")),
      "bounded late page selects only requested raw record")
    Store.write_text("edge-clone.jsonl","w",head)
    clone : String <- Store.import_file(db,"claude","edge-clone.jsonl")
    scalar(db,"SELECT count(*) FROM sources",[],"2","colliding provider session IDs preserve separate source identity")
    Store.write_text("edge-fresh.jsonl","w",head ++ tail ++ " repaired\"}]}}\n" ++ record("third record"))
    +fresh : String <- Store.import_file(db,"claude","edge-fresh.jsonl")
    scalar(db,"SELECT count(*) FROM (SELECT ordinal,event,role,body,tool,arguments,result FROM events WHERE snapshot=? EXCEPT SELECT ordinal,event,role,body,tool,arguments,result FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{appended},Sql.Cell.Integer{fresh}],"0","append projection matches fresh full import")
    scalar(db,"SELECT count(*) FROM (SELECT ordinal,event,role,body,tool,arguments,result FROM events WHERE snapshot=? EXCEPT SELECT ordinal,event,role,body,tool,arguments,result FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{fresh},Sql.Cell.Integer{appended}],"0","fresh full import has no omitted append events")
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--","edge-source.jsonl"],"",4096,2000))
    removed_status(removed)
    owned : String <- Store.page(db,appended,0,100)
    assert(String.eq(owned,new_page),"transcript survives removal of original fixture")
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"tail repaired","claude","/synthetic/alpha","assistant","",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),2n),
      "scoped search survives removed source and preserves separate source occurrences")
    excluded : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"tail repaired","codex","","","",100,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,excluded),"provider filter excludes other capture domain")
    IO.try(Unit,Sql.close(db))

def child_crash_import(path: String,unused: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    Store.write_text("edge-crash-source.jsonl","w",String.repeat(record("crash capture sample"),10000n))
    Store.write_text("edge-crash-ready","w","production import starting")
    snap : String <- Store.import_file(db,"claude","edge-crash-source.jsonl")
    IO.print("Import completed before interruption " ++ snap)
    IO.try(Unit,Sql.close(db))

def timed_out(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{(code,message)}:
      assert(U32.is_eq(code,60),"own production-import child is abruptly killed on bounded macOS timeout")
    case Done{(code,(out,err))}:
      IO.die(Unit,1,"FAIL own production-import child was expected to time out; exit " ++
        U32.show(code) ++ " " ++ out ++ err)

def ready_closed(got: File & Result<&1,&1,U32 & String,String>) -> IO(Unit):
  (file,result) = got
  do IO<Unit>:
    File.close(file)
    text : String <- IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))
    assert(String.eq(text,"production import starting"),"crash child reached production import")

def crash_capture(self: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["crash",".build/edge-crash.sqlite",""],"",8192,500)
    timed_out(result)
    file : File <- IO.try(File,File.open("edge-crash-ready","r"))
    ready : File & Result<&1,&1,U32 & String,String> <- File.read(file,100)
    ready_closed(ready)
    +db : U32 <- Store.open(".build/edge-crash.sqlite")
    scalar(db,"PRAGMA integrity_check",[],"ok","SQLite integrity survives killed production capture")
    scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],"0",
      "killed initial import publishes no accepted snapshot")
    scalar(db,"SELECT count(*) FROM raw",[],"0","killed capture rolls back uncommitted owned bytes")
    Store.write_text("edge-crash-source.jsonl","w",record("resumed after crash"))
    +snap : String <- Store.import_file(db,"claude","edge-crash-source.jsonl")
    page : String <- Store.page(db,snap,0,1)
    assert(String.contains(page,"resumed after crash"),"capture recovers after abrupt worker termination")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    tail_and_owned()
    corrupt_bytes(self)
    corrupt_index(self)
    corrupt_generation(self)
    corrupt_number(self)
    crash_capture(self)
    IO.print("Storage edge suite passed")

def child(mode: String,path: String,arg: String) -> IO(Unit):
  match mode:
    case "page":
      child_page(path,arg)
    case "import":
      child_import(path,arg)
    case "crash":
      child_crash_import(path,arg)
    case _:
      IO.die(Unit,2,"Unknown storage edge test mode")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{self,Con{mode,Con{path,Con{arg,Nil{}}}}}:
      child(mode,path,arg)
    case _:
      IO.die(Unit,2,"Storage edge test expects zero or three arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
