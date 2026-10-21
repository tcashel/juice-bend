import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths
import ../src/capture.bend as Capture
import ../src/maintenance.bend as Maintenance
import ../src/archive_meta.bend as ArchiveMeta
import ../src/archive_maintenance.bend as ArchiveMaintenance

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def equal_case(+left: List<&2,List<&2,U32>>,+right: List<&2,List<&2,U32>>,
  +expected: Bool,name: String) -> IO(Unit):
  assert(Bool.pick(Bool,expected,ArchiveMaintenance.equal_chunks(left,right),
    Bool.not(ArchiveMaintenance.equal_chunks(left,right))) &&
    Bool.pick(Bool,expected,Domain.bytes_equal(List.concat(&2,U32,left),List.concat(&2,U32,right)),
      Bool.not(Domain.bytes_equal(List.concat(&2,U32,left),List.concat(&2,U32,right)))),name)

def split_sample(+bytes: List<&2,U32>,+at: Nat) -> List<&2,List<&2,U32>>:
  [[],List.take(&2,U32,bytes,at),[],List.drop(&2,U32,bytes,at),[]]

def split_cases(fuel: Nat,+at: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        equal_case(split_sample([0,255,192,128,240,159,152,128,10,0],at),
          [[0],[255,192],[],[128,240,159,152],[128,10],[0]],True{},
          "logical chunk comparison ignores only segmentation at " ++ Nat.show(at))
        equal_case(split_sample([0,255,192,128,240,159,152,128,10,0],at),
          [[0],[255,192],[],[128,240,159,152],[128,10]],False{},
          "logical chunk comparison detects terminal NUL loss at " ++ Nat.show(at))
        split_cases(rest,1n+at)

def comparator_cases() -> IO(Unit):
  do IO<Unit>:
    equal_case([],[],True{},"empty logical streams agree")
    equal_case([[],[],[]],[[]],True{},"empty decoder blocks do not invent bytes")
    equal_case([[],[],[0]],[[],[]],False{},"late nonempty decoder block cannot disappear")
    equal_case([[1],[],[2]],[[2],[1]],False{},"logical stream order remains significant")
    equal_case([[0]],[[256]],False{},"comparator does not narrow U32 to octets")
    equal_case([[4294967295]],[[4294967295]],True{},"comparator keeps exact U32 equality")
    equal_case([[1,2],[3]],[[1,2],[3,4]],False{},"extra captured bytes fail exact comparison")
    assert(ArchiveMaintenance.typed_record([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},
      Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Text{"digest"},Sql.Cell.Blob{[10]},
      Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"}]),
      "archive logical row accepts only its exact typed column shape")
    assert(Bool.not(ArchiveMaintenance.typed_record([Sql.Cell.Integer{"1"},Sql.Cell.Text{"0"},
      Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Text{"digest"},Sql.Cell.Blob{[10]},
      Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"}])),
      "archive logical row rejects textual ordinal despite matching digits")
    assert(Bool.not(ArchiveMaintenance.typed_record([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},
      Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Text{"digest"},Sql.Cell.Text{"\n"},
      Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"}])),
      "archive logical row rejects TEXT payload despite matching apparent contents")
    split_cases(11n,0n)

def raw_frame(+bytes: List<&2,U32>) -> List<&2,U32>:
  +descriptor = U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),8),1)
  List.append(&2,U32,[40,181,47,253,0,56,U32.and(descriptor,255),
    U32.and(U32.shrn(descriptor,8n),255),U32.and(U32.shrn(descriptor,16n),255)],bytes)

def record(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"archive-maintenance\",\"cwd\":\"/synthetic/archive\",\"message\":{\"content\":\"" ++ text ++ "\"}}\n"

def payload() -> List<&2,U32>:
  List.append(&2,U32,Domain.encode(record("archive Café 中文 🙂 preserved")),[0,255,254,10,116,97,105,108])

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
    read : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1048576)
    read_closed(read)

def scalar(db: U32,sql: String) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],1)
    return Store.field(Store.first(rows),0n)

def process_ok(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),name)

def failure_result(result: U32 & (String & String),needle: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,needle),name)

def child_failure(self: String,mode: String,path: String,snapshot: String,
  output: String,needle: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[mode,path,snapshot,output],"",8192,30000))
    failure_result(result,needle,name)

def action(db: U32,mode: String,snapshot: String,output: String) -> IO(Unit):
  match mode:
    case "verify":
      ArchiveMaintenance.verify(db,snapshot)
    case "container":
      ArchiveMaintenance.export_container(db,snapshot,output)
    case "logical":
      Maintenance.export_raw(db,snapshot,output)
    case "header":
      do IO<Unit>:
        h : Maintenance.Header <- Maintenance.header(db,snapshot)
        return Unit{}
    case _:
      IO.die(Unit,2,"Unknown archive maintenance child mode")

def child(mode: String,path: String,snapshot: String,output: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    action(db,mode,snapshot,output)
    IO.try(Unit,Sql.close(db))

def absent(result: Result<&1,&1,U32 & String,File>,name: String) -> IO(Unit):
  match result:
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL " ++ name)
    case Fail{(code,_)}:
      assert(U32.is_eq(code,2),name)

def capture(+db: U32,+path: String,bytes: List<&2,U32>) -> IO(String):
  do IO<String>:
    write_bytes(path,raw_frame(bytes))
    Capture.import_file(db,"claude",path)

def vanished_source(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--","archive-maintenance-source.jsonl.zst"],"",4096,2000))
    process_ok(removed,"remove only this suite's synthetic archive source")
    ArchiveMaintenance.verify(db,snapshot)
    IO.print("PASS full archive verification survives original-source removal")
    ArchiveMaintenance.export_container(db,snapshot,"archive-maintenance-container.zst")
    Maintenance.export_raw(db,snapshot,"archive-maintenance-logical.raw")
    compressed : List<&2,U32> <- read_bytes("archive-maintenance-container.zst")
    assert(Domain.bytes_equal(compressed,raw_frame(payload())),"container export preserves exact original frame bytes after source removal")
    logical : List<&2,U32> <- read_bytes("archive-maintenance-logical.raw")
    assert(Domain.bytes_equal(logical,payload()),"logical export preserves Unicode NUL invalid UTF8 and unfinished tail")
    +before : String <- scalar(db,"SELECT group_concat(identity,'|') FROM (SELECT CAST(id AS TEXT)||':'||CAST(generation AS TEXT)||':'||digest AS identity FROM raw ORDER BY id)")
    Maintenance.rebuild(db,snapshot)
    ArchiveMaintenance.verify(db,snapshot)
    after : String <- scalar(db,"SELECT group_concat(identity,'|') FROM (SELECT CAST(id AS TEXT)||':'||CAST(generation AS TEXT)||':'||digest AS identity FROM raw ORDER BY id)")
    assert(String.eq(before,after),"logical rebuild preserves every raw ID generation digest and archive transform")

def export_guards(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    child_failure(self,"container",".build/archive-maintenance.sqlite",snapshot,
      "archive-maintenance-source.jsonl.zst","source locator","container export refuses a vanished original source locator")
    child_failure(self,"container",".build/archive-maintenance.sqlite",snapshot,
      "archive-maintenance-container.zst","already exists","container export refuses existing destination")
    bytes : List<&2,U32> <- read_bytes("archive-maintenance-container.zst")
    assert(Domain.bytes_equal(bytes,raw_frame(payload())),"failed no-clobber container export preserves destination")
    linked : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/ln",["-s","archive-maintenance-absent-target.zst","archive-maintenance-dangling.zst"],"",4096,2000))
    process_ok(linked,"create only the suite's synthetic dangling export symlink")
    child_failure(self,"container",".build/archive-maintenance.sqlite",snapshot,
      "archive-maintenance-dangling.zst","atomic publication failed","container publication rejects a dangling symlink without following it")
    missing : Result<&1,&1,U32 & String,File> <- File.open("archive-maintenance-absent-target.zst","r")
    absent(missing,"dangling container-export target remains absent")

def plain_rejected(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-maintenance.sqlite")
    Store.write_text("archive-maintenance-plain.jsonl","w",record("plain history still works"))
    +snapshot : String <- Store.import_file(db,"claude","archive-maintenance-plain.jsonl")
    Maintenance.verify(db,snapshot)
    IO.try(Unit,Sql.close(db))
    child_failure(self,"verify",".build/archive-maintenance.sqlite",snapshot,"",
      "not a captured archive","archive verify rejects an identity generation")
    child_failure(self,"container",".build/archive-maintenance.sqlite",snapshot,"archive-maintenance-plain-out.zst",
      "not a compressed archive","plain snapshot has no container export")
    missing : Result<&1,&1,U32 & String,File> <- File.open("archive-maintenance-plain-out.zst","r")
    absent(missing,"plain container export creates no destination")

def logical_corruption(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-maintenance.sqlite")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? ORDER BY ordinal DESC LIMIT 1)",
      [Sql.Cell.Integer{snapshot}])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"verify",".build/archive-maintenance.sqlite",snapshot,"",
      "integrity","full archive verification rejects corrupt logical raw bytes")
    child_failure(self,"logical",".build/archive-maintenance.sqlite",snapshot,"archive-maintenance-corrupt-logical.raw",
      "integrity","logical export refuses corrupt raw before destination creation")
    missing : Result<&1,&1,U32 & String,File> <- File.open("archive-maintenance-corrupt-logical.raw","r")
    absent(missing,"corrupt logical export creates no destination")

def container_corruption(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-maintenance-container.sqlite")
    +snapshot : String <- capture(db,"archive-maintenance-container-source.jsonl.zst",payload())
    Store.exec(db,"UPDATE archive_chunks SET bytes=zeroblob(n) WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"verify",".build/archive-maintenance-container.sqlite",snapshot,"",
      "Archive chunk types, bytes or digest are corrupt","full archive verification rejects changed retained compressed bytes")
    child_failure(self,"container",".build/archive-maintenance-container.sqlite",snapshot,"archive-maintenance-corrupt-container.zst",
      "Archive chunk types, bytes or digest are corrupt","container export validates all chunks before creating destination")
    missing : Result<&1,&1,U32 & String,File> <- File.open("archive-maintenance-corrupt-container.zst","r")
    absent(missing,"corrupt container export creates no destination")
    +db2 : U32 <- Store.open(".build/archive-maintenance-container.sqlite")
    Store.exec(db2,"DELETE FROM archive_captures WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    IO.try(Unit,Sql.close(db2))
    child_failure(self,"header",".build/archive-maintenance-container.sqlite",snapshot,"",
      "missing its immutable origin metadata","ordinary maintenance header refuses missing archive origin metadata")

def extra_map(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-maintenance-map.sqlite")
    +snapshot : String <- capture(db,"archive-maintenance-map-source.jsonl.zst",payload())
    Store.exec(db,"INSERT INTO records(snapshot,ordinal,raw) SELECT snapshot,999,raw FROM records WHERE snapshot=? AND ordinal=0",
      [Sql.Cell.Integer{snapshot}])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"verify",".build/archive-maintenance-map.sqlite",snapshot,"",
      "logical record count","full archive verify rejects extra record maps beyond sealed extent")

# A corruption test deliberately creates internally valid metadata for a
# different container. Independent stream hashes must not substitute for the
# actual transformation relationship. Only this isolated synthetic DB changes.
def transform_mismatch(+self: String) -> IO(Unit):
  +other = raw_frame(Domain.encode(record("different retained archive content")))
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-maintenance-transform.sqlite")
    +snapshot : String <- capture(db,"archive-maintenance-transform-source.jsonl.zst",payload())
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"UPDATE snapshots SET accepted=0 WHERE id=?",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"DELETE FROM archive_captures WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"DELETE FROM archive_chunks WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    ArchiveMeta.stage(db,snapshot,[other])
    ArchiveMeta.seal(db,snapshot,U32.from_nat(List.length(&2,U32,other)),Domain.digest(other),Domain.digest(payload()))
    Store.exec(db,"UPDATE snapshots SET accepted=1 WHERE id=?",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"COMMIT",[])
    Store.exec(db,"BEGIN",[])
    compressed : List<&2,List<&2,U32>> <- ArchiveMeta.container(db,snapshot,True{})
    raw : List<&2,List<&2,U32>> <- ArchiveMaintenance.logical(db,snapshot,True{})
    assert(Domain.bytes_equal(List.concat(&2,U32,compressed),other) &&
      Domain.bytes_equal(List.concat(&2,U32,raw),payload()),
      "transform failure fixture has independently valid compressed and logical stream hashes")
    Store.exec(db,"COMMIT",[])
    IO.try(Unit,Sql.close(db))
    child_failure(self,"verify",".build/archive-maintenance-transform.sqlite",snapshot,"",
      "does not exactly match","full archive verification checks actual decode equality beyond independent hashes")

def staging_read(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"UPDATE snapshots SET accepted=0 WHERE id=?",[Sql.Cell.Integer{snapshot}])
    ArchiveMaintenance.verify_owned(db,snapshot,False{})
    chunks : List<&2,List<&2,U32>> <- ArchiveMaintenance.logical(db,snapshot,False{})
    assert(Domain.bytes_equal(List.concat(&2,U32,chunks),payload()),
      "capture transaction verifies unaccepted archive through the same retained-byte algorithm")
    Store.exec(db,"ROLLBACK",[])

def empty_and_chunks() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-maintenance-empty.sqlite")
    +empty : String <- capture(db,"archive-maintenance-empty.jsonl.zst",[])
    ArchiveMaintenance.verify(db,empty)
    ArchiveMaintenance.export_container(db,empty,"archive-maintenance-empty-out.zst")
    Maintenance.export_raw(db,empty,"archive-maintenance-empty-out.raw")
    bytes : List<&2,U32> <- read_bytes("archive-maintenance-empty-out.raw")
    assert(List.is_empty(&2,U32,bytes),"empty logical archive exports a zero-byte logical file")
    +large : List<&2,U32> = Domain.encode(String.repeat("a",70000n) ++ "\n")
    +snapshot : String <- capture(db,"archive-maintenance-multichunk.jsonl.zst",large)
    ArchiveMaintenance.verify(db,snapshot)
    ArchiveMaintenance.export_container(db,snapshot,"archive-maintenance-multichunk-out.zst")
    output : List<&2,U32> <- read_bytes("archive-maintenance-multichunk-out.zst")
    assert(Domain.bytes_equal(output,raw_frame(large)),"multi-chunk retained container export preserves every byte across64KiB boundary")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    comparator_cases()
    +db : U32 <- Store.open(".build/archive-maintenance.sqlite")
    +snapshot : String <- capture(db,"archive-maintenance-source.jsonl.zst",payload())
    ArchiveMaintenance.verify(db,snapshot)
    staging_read(db,snapshot)
    Store.exec(db,"BEGIN",[])
    chunks : List<&2,List<&2,U32>> <- ArchiveMaintenance.logical(db,snapshot,True{})
    assert(Domain.bytes_equal(List.concat(&2,U32,chunks),payload()),"logical helper returns the complete validated retained byte stream")
    Store.exec(db,"COMMIT",[])
    vanished_source(db,snapshot)
    IO.try(Unit,Sql.close(db))
    export_guards(self,snapshot)
    plain_rejected(self)
    logical_corruption(self,snapshot)
    container_corruption(self)
    extra_map(self)
    transform_mismatch(self)
    empty_and_chunks()
    IO.print("Archive maintenance suite passed")

def args(argv: List<String>) -> IO(Unit):
  match argv:
    case Con{self,Nil{}}:
      suite(self)
    case Con{_,Con{mode,Con{path,Con{snapshot,Con{output,Nil{}}}}}}:
      child(mode,path,snapshot,output)
    case _:
      IO.die(Unit,2,"Invalid archive maintenance test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
