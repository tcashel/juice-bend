import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/capture.bend as Capture
import ../src/archive_meta.bend as Meta
import ../src/archive_maintenance.bend as Archive
import ../src/maintenance.bend as Maintenance
import ../src/zstd/frame.bend as Frame

# A bounded native resource gate, not a large-archive parity claim. Fixtures
# are generated entirely in Bend from Zstandard raw/RLE framing. SHA-256
# constants were independently calculated with Python hashlib during fixture
# preparation; Python is not a test or application runtime dependency.
# Run from a fresh isolated directory with .build present. The parent harness
# records native wait4 resource accounting; phase timings below distinguish app work
# from fixture construction and test-side export verification.

type Fixture is Data:
  Fixture{name: String,input: U32,output: U32,records: U32,chunks: U32,byte: U32,
    compressed_sha: String,logical_sha: String}

def output_fixture() -> Fixture:
  Fixture{"output-cap",134,4194304,16,1,97,
    "044f32683eeaea444399cf152fcaad21567c295c423e5b7b80277e6cae40c18f",
    "299285fc41a44cdb038b9fdaf494c76ca9d0c866672b2b266c1a0c17dda60a05"}

def input_fixture() -> Fixture:
  Fixture{"input-cap",1048576,1048546,4,16,98,
    "0b27a4c52223e958278c69b52afbfe148bb11ff2ee0be3dafa90a95410544d30",
    "85014aa9a3b525ec69310381e3e798f3aa8b408731521b7b9a5e764d586a194c"}

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def timed(name: String,start: Nat) -> IO(Unit):
  do IO<Unit>:
    end : Nat <- IO.now()
    IO.print("TIMING " ++ name ++ " " ++ Nat.show(Nat.sub(end,start)) ++ " ms")

def little3(+value: U32) -> List<&2,U32>:
  [U32.and(value,255),U32.and(U32.shrn(value,8n),255),U32.and(U32.shrn(value,16n),255)]

def raw_block(+size: U32,last: Bool,byte: U32) -> List<&2,U32>:
  List.append(&2,U32,little3(U32.add(U32.mul(size,8),Bool.to_u32(last))),
    List.replicate(U32,U32.to_nat(size),byte))

def rle_block(size: U32,last: Bool,byte: U32) -> List<&2,U32>:
  List.append(&2,U32,little3(U32.add(U32.add(U32.mul(size,8),2),Bool.to_u32(last))),[byte])

def copies(fuel: Nat,+chunk: List<&2,U32>,tail: List<&2,List<&2,U32>>,
  reversed: List<&2,List<&2,U32>>) -> List<&2,List<&2,U32>>:
  match fuel:
    case 0n:
      List.append(&2,List<&2,U32>,List.reverse(&2,List<&2,U32>,reversed),tail)
    case 1n+rest:
      copies(rest,chunk,tail,Con{chunk,reversed})

def window_header() -> List<&2,U32>:
  # No content-size field; window descriptor 56 advertises 128 KiB.
  [40,181,47,253,0,56]

def output_cap() -> List<&2,List<&2,U32>>:
  Con{window_header(),copies(31n,rle_block(131072,False{},97),[rle_block(131072,True{},97)],[])}

def output_over() -> List<&2,List<&2,U32>>:
  Con{window_header(),copies(32n,rle_block(131072,False{},97),[rle_block(1,True{},97)],[])}

def input_cap() -> List<&2,List<&2,U32>>:
  Con{window_header(),copies(7n,raw_block(131072,False{},98),[raw_block(131042,True{},98)],[])}

def input_over() -> List<&2,List<&2,U32>>:
  Con{window_header(),copies(7n,raw_block(131072,False{},98),[raw_block(131043,True{},98)],[])}

def extent(chunks: List<&2,List<&2,U32>>,total: U32) -> U32:
  match chunks:
    case []:
      total
    case chunk <> rest:
      extent(rest,U32.add(total,U32.from_nat(List.length(&2,U32,chunk))))

def all_bytes_walk(bytes: List<&2,U32>,+expected: U32,same: Bool) -> Bool:
  match bytes same:
    case _ False{}:
      False{}
    case [] True{}:
      True{}
    case byte <> rest True{}:
      all_bytes_walk(rest,expected,U32.is_eq(byte,expected))

def all_bytes(bytes: List<&2,U32>,expected: U32) -> Bool:
  all_bytes_walk(bytes,expected,True{})

def all_chunks(chunks: List<&2,List<&2,U32>>,+expected: U32) -> Bool:
  match chunks:
    case []:
      True{}
    case chunk <> rest:
      all_bytes(chunk,expected) && all_chunks(rest,expected)

def byte_check(bytes: List<&2,U32>,expected: Maybe<&2,U32>) -> Bool:
  match expected:
    case None{}:
      True{}
    case Some{value}:
      all_bytes(bytes,value)

def size_result(result: File & Result<&1,&1,U32 & String,U32>,expected: U32) -> IO(File):
  (file,got) = result
  do IO<File>:
    size : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,got))
    Store.checked(U32.is_eq(size,expected),"Limits fixture/export file has unexpected extent")
    return file

def require_size(file: File,expected: U32) -> IO(File):
  do IO<File>:
    result : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    size_result(result,expected)

# Test-side file verification never allocates a complete 4 MiB export buffer.
# Every read is at most 64 KiB; EOF, exact extent, bytes and SHA are checked.
def file_hash(fuel: Nat,file: File,+full: U32,remaining: U32,+offset: U32,
  +expected: Maybe<&2,U32>,hash: Domain.HashContext) -> IO(String):
  match fuel remaining:
    case _ 0:
      do IO<String>:
        final : File <- require_size(file,full)
        File.close(final)
        return Domain.hash_finish(hash)
    case 0n _:
      do IO<String>:
        File.close(file)
        IO.die(String,1,"Limits export check exceeded bounded read count")
    case 1n+rest +left:
      +wanted = U32.min(65536,left)
      Store.read(String,file,offset,wanted,
        f => bytes => do IO<String>:
          +chunk : List<&2,U32> = bytes
          Store.checked(Nat.is_eq(List.length(&2,U32,chunk),U32.to_nat(wanted)),
            "Limits export ended before its expected extent")
          Store.checked(byte_check(chunk,expected),"Limits logical export changed a retained byte")
          file_hash(rest,f,full,U32.sub(left,wanted),U32.add(offset,wanted),expected,
            Domain.hash_bytes(chunk,hash)))

def exported(path: String,+size: U32,expected: Maybe<&2,U32>,sha: String,name: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"r"))
    checked : File <- require_size(file,size)
    actual : String <- file_hash(65n,checked,size,size,0,expected,
      Domain.HashContext{Domain.hash_initial(),[],0,0})
    assert(String.eq(actual,sha),name)

def write_chunks(path: String,chunks: List<&2,List<&2,U32>>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    final : File <- Archive.write_chunks(chunks,file)
    File.close(final)

def process_ok(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),name)

def absent(result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL limits source still exists after removal")
    case Fail{(code,_)}:
      assert(U32.is_eq(code,2),"only the synthetic cap source is now absent")

def remove_source(+path: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--",path],"",4096,2000))
    process_ok(result,"remove this gate's synthetic cap source")
    opened : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent(opened)

def origin_matches(origin: Meta.Origin,fixture: Fixture) -> Bool:
  Meta.Origin{_,_,_,_,_,logical,records,compressed,chunks,compressed_sha,logical_sha} = origin
  Fixture{_,wanted_input,wanted_output,wanted_records,wanted_chunks,_,wanted_compressed_sha,wanted_logical_sha} = fixture
  U32.is_eq(logical,wanted_output) && U32.is_eq(records,wanted_records) &&
    U32.is_eq(compressed,wanted_input) && U32.is_eq(chunks,wanted_chunks) &&
    String.eq(compressed_sha,wanted_compressed_sha) && String.eq(logical_sha,wanted_logical_sha)

def raw_rows(rows: List<&2,List<&2,Sql.Cell>>,output: U32,+records: U32) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{+extent},Sql.Cell.Integer{declared},Sql.Cell.Integer{count},
      Sql.Cell.Integer{total},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},
      Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"262144"}]]:
      assert(String.eq(extent,U32.show(output)) && String.eq(total,extent) &&
        String.eq(declared,U32.show(records)) && String.eq(count,U32.show(records)),
        "cap raw fragments retain exact extent count unfinished-line and oversized flags")
    case _:
      IO.die(Unit,1,"FAIL limits retained raw aggregate or SQLite types differ")

def retained(+db: U32,+snapshot: String,+fixture: Fixture) -> IO(Unit):
  Fixture{+name,_,+output,records,_,byte,_,_} = fixture
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    found : Maybe<&2,Meta.Origin> <- Meta.read(db,snapshot,True{})
    origin : Meta.Origin <- Archive.required(found)
    assert(origin_matches(origin,fixture),name ++ " sealed origin equals exact extents counts and independent SHA256 oracles")
    +logical : List<&2,List<&2,U32>> <- Archive.logical(db,snapshot,True{})
    assert(U32.is_eq(extent(logical,0),output) && all_chunks(logical,byte),
      name ++ " every retained logical byte survives raw fragment splitting")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.extent,p.records,count(i.ordinal),sum(r.n),min(r.complete),max(r.complete),min(r.oversized),max(r.oversized),max(r.n) FROM snapshots p JOIN records i ON i.snapshot=p.id JOIN raw r ON r.id=i.raw WHERE p.id=? GROUP BY p.id",
      [Sql.Cell.Integer{snapshot}],1)
    raw_rows(rows,output,records)
    Store.exec(db,"COMMIT",[])

def capture_case(+fixture: Fixture,+chunks: List<&2,List<&2,U32>>) -> IO(Unit):
  Fixture{+name,+input,+output,_,_,byte,+compressed_sha,logical_sha} = fixture
  +source = "archive-limits-" ++ name ++ ".jsonl.zst"
  +database = ".build/archive-limits-" ++ name ++ ".sqlite"
  +container_export = "archive-limits-" ++ name ++ "-owned.zst"
  +logical_export = "archive-limits-" ++ name ++ "-logical.raw"
  do IO<Unit>:
    assert(U32.is_eq(extent(chunks,0),input) && String.eq(Meta.digest_chunks(chunks),compressed_sha),
      name ++ " synthetic framing has exact compressed extent and independent SHA256")
    write_chunks(source,chunks)
    +db : U32 <- Store.open(database)
    start : Nat <- IO.now()
    +snapshot : String <- Capture.import_file(db,"claude",source)
    timed(name ++ ".capture",start)
    IO.try(Unit,Sql.close(db))
    +reopened : U32 <- Store.open(database)
    retained(reopened,snapshot,fixture)
    remove_source(source)
    verify_start : Nat <- IO.now()
    Archive.verify(reopened,snapshot)
    timed(name ++ ".verify-owned-after-source-removal",verify_start)
    container_start : Nat <- IO.now()
    Archive.export_container(reopened,snapshot,container_export)
    timed(name ++ ".export-container",container_start)
    logical_start : Nat <- IO.now()
    Maintenance.export_raw(reopened,snapshot,logical_export)
    timed(name ++ ".export-logical",logical_start)
    exported(container_export,input,None{},compressed_sha,
      name ++ " source-absent container export matches exact original bytes by independent SHA256")
    exported(logical_export,output,Some{byte},logical_sha,
      name ++ " source-absent logical export matches every byte and independent SHA256")
    IO.try(Unit,Sql.close(reopened))

def rejected(result: Result<&2,&2,String,List<&2,List<&2,U32>>>,needle: String,name: String) -> IO(Unit):
  match result:
    case Fail{message}:
      assert(String.contains(message,needle),name)
    case Done{_}:
      IO.die(Unit,1,"FAIL " ++ name ++ ": decoder accepted over-limit fixture")

def empty_decoded(result: Result<&2,&2,String,List<&2,List<&2,U32>>>,name: String) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit,1,"FAIL " ++ name ++ ": " ++ error)
    case Done{chunks}:
      assert(U32.is_eq(extent(chunks,0),0),name)

def empty_frames(count: Nat) -> List<&2,U32>:
  List.concat(&2,U32,List.replicate(List<&2,U32>,count,[40,181,47,253,32,0,1,0,0]))

def empty_blocks(nonfinal: Nat) -> List<&2,U32>:
  List.concat(&2,U32,Con{window_header(),copies(nonfinal,[0,0,0],[[1,0,0]],[])})

def count_limits() -> IO(Unit):
  do IO<Unit>:
    empty_decoded(Frame.decode(empty_frames(64n),Archive.limits()),"exactly 64 complete frames pass configured frame cap")
    rejected(Frame.decode(empty_frames(65n),Archive.limits()),"frame count","65 complete frames exceed configured frame cap")
    empty_decoded(Frame.decode(empty_blocks(U32.to_nat(4095)),Archive.limits()),"exactly 4096 valid empty raw blocks pass configured block cap")
    rejected(Frame.decode(empty_blocks(U32.to_nat(4096)),Archive.limits()),"block count","4097 valid empty raw blocks exceed configured block cap")

def byte_limits() -> IO(Unit):
  do IO<Unit>:
    +too_large : List<&2,List<&2,U32>> = input_over()
    assert(U32.is_eq(extent(too_large,0),1048577),"input rejection fixture is exactly one byte above 1 MiB")
    rejected(Frame.decode(List.concat(&2,U32,too_large),Archive.limits()),"byte limit",
      "valid raw container one byte above compressed cap is rejected before decode")
    rejected(Frame.decode(List.concat(&2,U32,output_over()),Archive.limits()),"output",
      "valid RLE frame expanding one byte above 4 MiB output cap is rejected")

def main() -> IO(Unit):
  do IO<Unit>:
    assert(U32.is_eq(Meta.input_limit(),1048576) && U32.is_eq(Meta.output_limit(),4194304),
      "resource gate uses current 1 MiB compressed and 4 MiB logical profile")
    count_limits()
    capture_case(output_fixture(),output_cap())
    capture_case(input_fixture(),input_cap())
    byte_limits()
    IO.print("Archive exact-cap native resource suite passed")
