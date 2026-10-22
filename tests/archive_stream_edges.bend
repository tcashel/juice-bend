import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/capture.bend as Capture
import ../src/evidence.bend as Evidence
import ../src/archive_meta.bend as Meta
import ../src/archive_maintenance.bend as Archive
import ../src/maintenance.bend as Maintenance
import ./archive_maintenance.bend as Fixture
import ./archive_limits.bend as Limits
import ./archive_publication.bend as Check
import ./archive_failures.bend as Failure
import ./zstd/frame_vectors.bend as Vectors

# This fixture crosses the former 4 MiB logical limit without constructing a
# whole logical archive. Its three frames are a small raw JSONL frame, an
# unknown-size 34-block RLE frame, and a frozen checksummed raw frame. Fixture
# generation, expected-byte hashing, capture, assertions and exports are Bend.
# This checks ordinary rejected-worker rollback, not asynchronous cancellation.
type Expected is Data:
  Expected{extent: U32,digest: String}

type Pinned is Data:
  Pinned{snapshot: String,generation: String,raw: String,page: String,
    citation: String,quote: String}

def first_record() -> List<&2,U32>:
  Domain.encode(Fixture.record("streamedgefirst café 中文 🙂"))

def last_record() -> List<&2,U32>:
  Domain.encode("hello archive\n")

def container_chunks() -> List<&2,List<&2,U32>>:
  Fixture.raw_frame(first_record()) <> Limits.window_header() <>
    Limits.copies(33n,Limits.rle_block(131072,False{},97),
      [Limits.rle_block(131072,True{},97),Vectors.hello_check()],[])

# Every expected block is at most 128 KiB. The SHA is derived directly from
# the synthetic grammar, independently of decoding, SQLite and export bytes.
def expected_blocks(fuel: Nat,hash: Domain.HashContext) -> Domain.HashContext:
  match fuel:
    case 0n: hash
    case 1n+rest:
      expected_blocks(rest,Domain.hash_bytes(List.replicate(U32,131072n,97),hash))

def logical_expected() -> Expected:
  Expected{U32.add(U32.from_nat(List.length(&2,U32,first_record())),4456462),
    Domain.hash_finish(Domain.hash_bytes(last_record(),expected_blocks(34n,
      Domain.hash_bytes(first_record(),Meta.initial_hash()))))}

def physical_expected() -> Expected:
  Expected{Limits.extent(container_chunks(),0),
    Domain.hash_finish(Meta.hash_chunks(container_chunks(),Meta.initial_hash()))}

def write_source(path: String,extra: List<&2,U32>) -> IO(Unit):
  Limits.write_chunks(path,List.append(&2,List<&2,U32>,container_chunks(),[extra]))

def expected_file(path: String,expected: Expected,label: String) -> IO(Unit):
  Expected{+extent,digest} = expected
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"r"))
    sized : File <- Limits.require_size(file,extent)
    actual : String <- Limits.file_hash(80n,sized,extent,extent,0,None{},Meta.initial_hash())
    Check.assert(String.eq(actual,digest),label)

def expected_origin(+db: U32,+snapshot: String,logical: Expected,physical: Expected) -> IO(Unit):
  Expected{+extent,digest} = logical
  Expected{compressed,physical_digest} = physical
  do IO<Unit>:
    Check.assert(U32.is_gt(extent,4194304),"fixture independently exceeds the former 4 MiB logical cap")
    Check.equal_scalar(db,"SELECT extent FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],
      U32.show(extent),"stream capture publishes the exact logical extent beyond 4 MiB")
    Check.equal_scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],
      "19","large raw/RLE/checksummed concatenation retains every bounded logical record")
    Check.equal_scalar(db,"SELECT profile FROM archive_captures WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],
      "archive-stream-v2","large capture uses the explicit streaming profile")
    Check.equal_scalar(db,"SELECT compressed_extent FROM archive_captures WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],
      U32.show(compressed),"retained physical extent matches the independently generated container")
    Check.equal_scalar(db,"SELECT compressed_sha FROM archive_captures WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],
      physical_digest,"retained physical SHA matches the independently generated container")
    Check.equal_scalar(db,"SELECT logical_sha FROM archive_captures WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],
      digest,"retained logical SHA matches the independently generated logical stream")
    Check.equal_scalar(db,"SELECT count(*) FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND r.n=262144 AND r.oversized=1",
      [Sql.Cell.Integer{snapshot}],"17","overlong synthetic line is retained in seventeen bounded raw fragments")

def selected_bytes(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Blob{bytes}]]:
      Check.assert(Domain.bytes_equal(bytes,first_record()),"selected Unicode record matches independently generated exact UTF8 bytes")
    case _: IO.die(Unit,1,"FAIL selected streaming-edge raw record shape")

def select(+db: U32,+snapshot: String) -> IO(Pinned):
  do IO<Pinned>:
    generation : String <- Check.scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}])
    raw : String <- Check.scalar(db,"SELECT raw FROM records WHERE snapshot=? AND ordinal=0",[Sql.Cell.Integer{snapshot}])
    page : String <- Store.page(db,snapshot,0,1)
    record : Evidence.Verified <- Evidence.read_record(db,snapshot,0)
    +citation : String = Evidence.citation(record,0)
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    quote : String <- Check.quote_result(resolved)
    return Pinned{snapshot,generation,raw,page,citation,quote}

def pinned(+db: U32,selected: Pinned,+label: String) -> IO(Unit):
  Pinned{+snapshot,generation,raw,page,citation,quote} = selected
  do IO<Unit>:
    Check.equal_scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],
      generation,label ++ " selected generation identity is unchanged")
    Check.equal_scalar(db,"SELECT raw FROM records WHERE snapshot=? AND ordinal=0",[Sql.Cell.Integer{snapshot}],
      raw,label ++ " selected raw identity is unchanged")
    Check.equal_scalar(db,"SELECT s.latest FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],snapshot,label ++ " accepted latest snapshot is unchanged")
    actual : String <- Store.page(db,snapshot,0,1)
    Check.assert(String.eq(actual,page),label ++ " selected transcript page is exact")
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    actual_quote : String <- Check.quote_result(resolved)
    Check.assert(String.eq(actual_quote,quote),label ++ " selected citation resolves to exact retained evidence")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.bytes FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal=0",
      [Sql.Cell.Integer{snapshot}],1)
    selected_bytes(rows)
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"streamedgefirst","claude","","","",10,0)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),1n),label ++ " selected event remains lexically searchable")

def failure_tail(mode: String) -> List<&2,U32>:
  match mode:
    case "checksum": Failure.flip_last(Vectors.hello_check())
    case "incomplete": Failure.without_last(Vectors.hello_check())
    case _: []

def failure_error(mode: String) -> String:
  match mode:
    case "checksum": "archive_corrupt: Zstandard content checksum mismatch"
    case "incomplete": "archive_corrupt: truncated or oversized decoder request"
    case _: "UNKNOWN-STREAM-EDGE-FAILURE"

def child(+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- Capture.import_file(db,"claude",prefix ++ ".jsonl.zst")
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,92,"UNEXPECTED accepted streaming-edge snapshot " ++ snapshot)

def failure_case(+self: String,+prefix: String,+mode: String,selected: Pinned) -> IO(Unit):
  do IO<Unit>:
    write_source(prefix ++ ".jsonl.zst",failure_tail(mode))
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["child",prefix],"",8192,120000)
    Failure.failed(result,failure_error(mode),"late streaming " ++ mode)
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Check.unchanged_tables(Check.tables(),db,"late streaming " ++ mode)
    pinned(db,selected,"late streaming " ++ mode)
    Check.check_integrity(db,"late streaming " ++ mode)
    IO.try(Unit,Sql.close(db))

def retained(+prefix: String,+selected: Pinned,logical: Expected,physical: Expected) -> IO(Unit):
  Pinned{+snapshot,_,_,_,_,_} = selected
  do IO<Unit>:
    Limits.remove_source(prefix ++ ".jsonl.zst")
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Archive.verify(db,snapshot)
    IO.print("PASS full retained transform verification succeeds beyond 4 MiB with the source absent")
    pinned(db,selected,"source absent")
    Archive.export_container(db,snapshot,prefix ++ ".retained.zst")
    Maintenance.export_raw(db,snapshot,prefix ++ ".retained.raw")
    expected_file(prefix ++ ".retained.zst",physical,"source-absent container export matches the independent incremental fixture digest")
    expected_file(prefix ++ ".retained.raw",logical,"source-absent logical export matches the independent incremental fixture digest")
    Check.check_integrity(db,"source absent")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    first : U32 <- IO.try(U32,IO.random_u32())
    second : U32 <- IO.try(U32,IO.random_u32())
    +directory : String = ".build/archive-stream-edges-" ++ U32.show(first) ++ "-" ++ U32.show(second)
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-m","700",directory],"",4096,2000))
    Fixture.process_ok(made,"create unique private streaming edge directory")
    +prefix : String = directory ++ "/large"
    +logical : Expected = logical_expected()
    +physical : Expected = physical_expected()
    write_source(prefix ++ ".jsonl.zst",[])
    expected_file(prefix ++ ".jsonl.zst",physical,"generated source matches independent physical framing digest")
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    started : Nat <- IO.now()
    +snapshot : String <- Capture.import_file(db,"claude",prefix ++ ".jsonl.zst")
    Limits.timed("stream-edge-capture",started)
    expected_origin(db,snapshot,logical,physical)
    +selected : Pinned <- select(db,snapshot)
    pinned(db,selected,"initial large capture")
    Check.remember_tables(Check.tables(),db)
    IO.try(Unit,Sql.close(db))
    failure_case(self,prefix,"checksum",selected)
    failure_case(self,prefix,"incomplete",selected)
    retained(prefix,selected,logical,physical)
    IO.print("Archive streaming edge suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case [_,"child",prefix]: child(prefix)
    case _: IO.die(Unit,2,"Archive streaming edge test expects no arguments or owned child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
