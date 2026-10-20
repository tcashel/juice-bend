import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/maintenance.bend as Maintenance
import ../src/paths.bend as Paths

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def record(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"maintenance-fixture\",\"cwd\":\"/synthetic/maintenance\",\"message\":{\"content\":\"" ++ text ++ "\"}}\n"

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(result)

def read_closed(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,bytes) = result
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,bytes))

def read_bytes(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    read : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65536)
    read_closed(read)

def scalar(db: U32,sql: String) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],1)
    return Store.field(Store.first(rows),0n)

def failure_result(result: U32 & (String & String),needle: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(Bool.not(U32.is_eq(code,0)) && String.contains(out ++ err,needle),name)

def child_failure(self: String,mode: String,path: String,snapshot: String,
  output: String,needle: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[mode,path,snapshot,output],"",8192,10000))
    failure_result(result,needle,name)

def action(db: U32,mode: String,snapshot: String,output: String) -> IO(Unit):
  match mode:
    case "verify":
      Maintenance.verify(db,snapshot)
    case "rebuild":
      Maintenance.rebuild(db,snapshot)
    case "export":
      Maintenance.export_raw(db,snapshot,output)
    case "publish":
      Maintenance.publish(snapshot,output)
    case _:
      IO.die(Unit,2,"Unknown test child mode")

def child(+mode: String,path: String,+snapshot: String,output: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    action(db,mode,snapshot,output)
    IO.try(Unit,Sql.close(db))

def absent_output(result: Result<&1,&1,U32 & String,File>,name: String) -> IO(Unit):
  match result:
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL " ++ name)
    case Fail{(code,_)}:
      assert(U32.is_eq(code,2),name)

def process_succeeded(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),name)

def atomic_exports(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    linked : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/ln",["-s","dangling-target.raw","dangling-export.raw"],"",4096,2000))
    process_succeeded(linked,"create only the synthetic dangling export symlink")
    child_failure(self,"export",".build/maintenance.sqlite",snapshot,"dangling-export.raw",
      "atomic publication failed","raw export refuses dangling symlink without following it")
    absent : Result<&1,&1,U32 & String,File> <- File.open("dangling-target.raw","r")
    absent_output(absent,"dangling symlink target remains absent")
    +canonical : String <- Paths.destination("publication-race.raw")
    +temp : String <- Maintenance.temporary(canonical)
    Store.write_text(temp,"w","candidate bytes")
    Store.write_text(canonical,"w","existing destination")
    child_failure(self,"publish",".build/maintenance.sqlite",temp,canonical,
      "atomic publication failed","atomic publication refuses destination created after preflight")
    kept : List<&2,U32> <- read_bytes(canonical)
    assert(Domain.bytes_equal(kept,Domain.encode("existing destination")),
      "publication race leaves existing destination bytes unchanged")

def tail_snapshots() -> IO(Unit):
  +tail = {"{\"type\":\"user\",\"message\":{\"content\":\"immutable tail\"}}" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(".build/maintenance-tail.sqlite")
    Store.write_text("maintenance-tail.jsonl","w",tail)
    +old : String <- Store.import_file(db,"claude","maintenance-tail.jsonl")
    Store.write_text("maintenance-tail.jsonl","a","\n" ++ record("new appended record"))
    +latest : String <- Store.import_file(db,"claude","maintenance-tail.jsonl")
    Maintenance.verify(db,old)
    Maintenance.verify(db,latest)
    IO.print("PASS complete verification accepts immutable old tail and appended snapshot")
    Maintenance.export_raw(db,old,"maintenance-old-tail.raw")
    bytes : List<&2,U32> <- read_bytes("maintenance-old-tail.raw")
    assert(Domain.bytes_equal(bytes,Domain.encode(tail)),"old snapshot export excludes later newline and appended record")
    Maintenance.rebuild(db,old)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{latest}],1)
    assert(String.eq(Store.field(Store.first(rows),0n),"2"),"rebuilding old snapshot leaves newer projection untouched")
    IO.try(Unit,Sql.close(db))

def fragment_boundaries() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/maintenance-fragments.sqlite")
    Store.write_text("maintenance-fragment.jsonl","w",String.repeat("x",262144n) ++ "\n")
    +fragmented : String <- Store.import_file(db,"claude","maintenance-fragment.jsonl")
    Maintenance.verify(db,fragmented)
    Maintenance.rebuild(db,fragmented)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM events WHERE snapshot=? AND coverage='oversized_record_fragment'",
      [Sql.Cell.Integer{fragmented}],1)
    assert(String.eq(Store.field(Store.first(rows),0n),"2"),
      "verification and rebuild preserve both oversized record fragments")
    Store.write_text("maintenance-boundary.jsonl","w",String.repeat("x",262143n) ++ "\n")
    boundary : String <- Store.import_file(db,"claude","maintenance-boundary.jsonl")
    Maintenance.verify(db,boundary)
    IO.print("PASS exact 262144-byte newline record is not mislabeled oversized")
    IO.try(Unit,Sql.close(db))

def source_aliases() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/maintenance-aliases.sqlite")
    Store.write_text("maintenance source Café.jsonl","w",record("canonical source identity"))
    +original : String <- Store.import_file(db,"claude","maintenance source Café.jsonl")
    +absolute : String <- Paths.resolve("maintenance source Café.jsonl")
    same : String <- Store.import_file(db,"claude",absolute)
    assert(String.eq(original,same),"relative and absolute source aliases retain one snapshot")
    linked : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/ln",["-s","maintenance source Café.jsonl","maintenance-alias-link.jsonl"],"",4096,2000))
    process_succeeded(linked,"create only the synthetic source alias")
    alias : String <- Store.import_file(db,"claude","maintenance-alias-link.jsonl")
    assert(String.eq(original,alias),"explicit symlink source resolves to its canonical identity")
    source_count : String <- scalar(db,"SELECT count(*) FROM sources")
    assert(String.eq(source_count,"1"),"canonical aliases do not duplicate captured sources")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  +raw = List.append(&2,U32,
    Domain.encode(record("preserved Café evidence") ++ record("second maintenance record")),
    [0,255,254,10])
  do IO<Unit>:
    write_bytes("maintenance-source.jsonl",raw)
    +db : U32 <- Store.open(".build/maintenance.sqlite")
    +snapshot : String <- Store.import_file(db,"claude","maintenance-source.jsonl")
    +before_hashes : String <- scalar(db,"SELECT group_concat(digest,'|') FROM raw ORDER BY ordinal")
    Store.write_text("maintenance-source.jsonl","w","source replacement must never enter export")
    Maintenance.verify(db,snapshot)
    IO.print("PASS complete raw verification does not read replaced source")
    Maintenance.export_raw(db,snapshot,"maintenance-export.raw")
    bytes : List<&2,U32> <- read_bytes("maintenance-export.raw")
    assert(Domain.bytes_equal(bytes,raw),"full raw export preserves exact UTF-8, NUL and invalid bytes")
    Store.exec(db,"DELETE FROM events",[])
    Maintenance.rebuild(db,snapshot)
    +after_hashes : String <- scalar(db,"SELECT group_concat(digest,'|') FROM raw ORDER BY ordinal")
    assert(String.eq(before_hashes,after_hashes),"rebuild leaves original digest identities unchanged")
    +event_count : String <- scalar(db,"SELECT count(*) FROM events")
    assert(String.eq(event_count,"3"),"rebuild restores all physical records including invalid UTF-8 coverage")
    coverage : String <- scalar(db,"SELECT coverage FROM events WHERE ordinal=2")
    assert(String.starts_with(coverage,"invalid_utf8:"),"rebuild preserves explicit invalid-byte coverage")
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"preserved Café","","","","",10,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),1n),"rebuilt lexical index returns one retained source occurrence")
    Maintenance.rebuild(db,snapshot)
    search_count : String <- scalar(db,"SELECT count(*) FROM search")
    assert(String.eq(search_count,"3"),"repeated rebuild does not duplicate FTS rows")
    IO.try(Unit,Sql.close(db))
    child_failure(self,"export",".build/maintenance.sqlite",snapshot,"maintenance-source.jsonl",
      "source locator","export refuses original source locator")
    child_failure(self,"export",".build/maintenance.sqlite",snapshot,"maintenance-export.raw",
      "already exists","export refuses existing destination without truncation")
    retained : List<&2,U32> <- read_bytes("maintenance-export.raw")
    assert(Domain.bytes_equal(retained,raw),"failed existing-file export leaves output bytes unchanged")
    atomic_exports(self,snapshot)
    +db2 : U32 <- Store.open(".build/maintenance.sqlite")
    Store.exec(db2,"CREATE TRIGGER fail_rebuild BEFORE INSERT ON events BEGIN SELECT RAISE(ABORT,'synthetic rebuild fault'); END",[])
    IO.try(Unit,Sql.close(db2))
    child_failure(self,"rebuild",".build/maintenance.sqlite",snapshot,"",
      "constraint failed","rebuild reports injected projection-write failure")
    +db3 : U32 <- Store.open(".build/maintenance.sqlite")
    recovered : String <- scalar(db3,"SELECT count(*) FROM events")
    assert(String.eq(recovered,event_count),"failed rebuild rolls back prior projection deletion")
    Store.exec(db3,"DROP TRIGGER fail_rebuild",[])
    Store.exec(db3,"UPDATE raw SET bytes=zeroblob(n) WHERE ordinal=2",[])
    IO.try(Unit,Sql.close(db3))
    child_failure(self,"verify",".build/maintenance.sqlite",snapshot,"",
      "integrity","full verification rejects changed late retained bytes")
    child_failure(self,"rebuild",".build/maintenance.sqlite",snapshot,"",
      "integrity","rebuild refuses to bless changed retained bytes")
    child_failure(self,"export",".build/maintenance.sqlite",snapshot,"must-not-exist.raw",
      "integrity","raw export verifies before creating destination")
    absent : Result<&1,&1,U32 & String,File> <- File.open("must-not-exist.raw","r")
    absent_output(absent,"corrupt export creates no output file")
    tail_snapshots()
    fragment_boundaries()
    source_aliases()
    IO.print("Maintenance suite passed")

def args(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{_,Con{mode,Con{path,Con{snapshot,Con{output,Nil{}}}}}}:
      child(mode,path,snapshot,output)
    case _:
      IO.die(Unit,2,"Invalid maintenance test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
