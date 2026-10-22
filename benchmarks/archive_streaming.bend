import Base
import ../src/domain.bend as Domain
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/archive_meta.bend as Meta
import ../src/archive_maintenance.bend as Archive
import ../src/maintenance.bend as Maintenance
import ../src/evidence.bend as Evidence
import ../tests/publication_crash.bend as Check

# Synthetic fixture grammar and assertions stay in Bend. The separate test
# orchestration may compress this prepared file offline with a recorded zstd
# tool; the application path never invokes a compressor or external decoder.

# Pinned Base exposes IO.now, whose native effect returns monotonic
# milliseconds. Each timer surrounds the complete named operation, including
# its checks and handle closure. No time is inferred from compiler duration.
def elapsed(phase: String,start: Nat) -> IO(Unit):
  do IO<Unit>:
    finished : Nat <- IO.now()
    IO.print("phase=" ++ phase ++ " elapsed_ms=" ++ Nat.show(Nat.sub(finished,start)))

def random(+value: U32) -> U32:
  +a = U32.xor(value,U32.shln(value,13n))
  +b = U32.xor(a,U32.shrn(a,17n))
  U32.xor(b,U32.shln(b,5n))

def noise(fuel: Nat,+value: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: Domain.hex_word(value) ++ noise(rest,random(value))

def record_kind(kind: U32,+index: U32,+payload: String) -> String:
  match kind:
    case 0:
      "{\"type\":\"user\",\"sessionId\":\"streaming-synthetic\",\"message\":{\"role\":\"user\",\"content\":\"streamneedle " ++ U32.show(index) ++ " café 中文 🙂 " ++ payload ++ "\"}}\n"
    case 1:
      "{\"type\":\"assistant\",\"sessionId\":\"streaming-synthetic\",\"message\":{\"role\":\"assistant\",\"content\":\"Response " ++ U32.show(index) ++ " " ++ payload ++ "\"}}\n"
    case 2:
      "{\"type\":\"assistant\",\"sessionId\":\"streaming-synthetic\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"tool-" ++ U32.show(index) ++ "\",\"name\":\"Read\",\"input\":{\"file_path\":\"synthetic/" ++ U32.show(index) ++ ".txt\",\"expected\":\"" ++ payload ++ "\"}}]}}\n"
    case _:
      "{\"type\":\"user\",\"sessionId\":\"streaming-synthetic\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"tool-" ++ U32.show(U32.sub(index,1)) ++ "\",\"content\":\"" ++ payload ++ "\"}]}}\n"

def record(+index: U32) -> List<&2,U32>:
  Domain.encode(record_kind(U32.mod(index,4),index,noise(16n,random(U32.add(index,1)))))

type Expected is Data:
  Expected{extent: U32,digest: String}

def expected(fuel: Nat,+index: U32,extent: U32,hash: Domain.HashContext) -> Expected:
  match fuel:
    case 0n: Expected{extent,Domain.hash_finish(hash)}
    case 1n+rest:
      +bytes = record(index)
      expected(rest,U32.inc(index),U32.add(extent,U32.from_nat(List.length(&2,U32,bytes))),Domain.hash_bytes(bytes,hash))

def prepared(file: File,+extent: U32,hash: Domain.HashContext) -> IO(Unit):
  do IO<Unit>:
    File.close(file)
    Check.assert(U32.is_gt(extent,4194304),"100000 mixed records exceed old logical batch cap")
    IO.print("logical_extent=" ++ U32.show(extent))
    IO.print("logical_sha256=" ++ Domain.hash_finish(hash))

def prepare_walk(fuel: Nat,file: File,+index: U32,extent: U32,hash: Domain.HashContext) -> IO(Unit):
  match fuel:
    case 0n: prepared(file,extent,hash)
    case 1n+rest:
      +bytes = record(index)
      do IO<Unit>:
        written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
        next : File <- Maintenance.write_result(written)
        prepare_walk(rest,next,U32.inc(index),U32.add(extent,U32.from_nat(List.length(&2,U32,bytes))),Domain.hash_bytes(bytes,hash))

def prepare() -> IO(Unit):
  do IO<Unit>:
    started : Nat <- IO.now()
    existing : Result<&1,&1,U32 & String,File> <- File.open("streaming-expected.jsonl","r")
    Maintenance.output_absent(existing)
    file : File <- IO.try(File,File.open("streaming-expected.jsonl","w"))
    prepare_walk(100000n,file,0,0,Meta.initial_hash())
    elapsed("prepare",started)

def selected_bytes(rows: List<&2,List<&2,Sql.Cell>>,ordinal: U32) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Blob{bytes}]]:
      Check.assert(Domain.bytes_equal(bytes,record(ordinal)),"selected first/middle/late raw record matches independent fixture grammar")
    case _: IO.die(Unit,1,"FAIL selected raw record shape")

def selected(+db: U32,+snapshot: String,+ordinal: U32) -> IO(Unit):
  do IO<Unit>:
    record : Evidence.Verified <- Evidence.read_record(db,snapshot,ordinal)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.bytes FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal=?",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],1)
    selected_bytes(rows,ordinal)

def file_hash_end(file: File,hash: Domain.HashContext,expected: String) -> IO(Unit):
  do IO<Unit>:
    File.close(file)
    Check.assert(String.eq(Domain.hash_finish(hash),expected),"streamed export matches exact retained SHA256")

def file_hash_piece(file: File,+bytes: List<&2,U32>,+wanted: U32,hash: Domain.HashContext,
  next: File -> Domain.HashContext -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    Check.assert(Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(wanted)),"bounded exported file read has exact requested extent")
    next(file,Domain.hash_bytes(bytes,hash))

def file_hash_step(file: File,+offset: U32,+extent: U32,hash: Domain.HashContext,expected: String,done: Bool,
  next: File -> U32 -> Domain.HashContext -> IO(Unit)) -> IO(Unit):
  match done:
    case True{}: file_hash_end(file,hash,expected)
    case False{}:
      +wanted = U32.min(65536,U32.sub(extent,offset))
      Store.read(Unit,file,offset,wanted,f => bytes => file_hash_piece(f,bytes,wanted,hash,
        after => digest => next(after,U32.add(offset,wanted),digest)))

def file_hash_walk(fuel: Nat,file: File,+offset: U32,+extent: U32,hash: Domain.HashContext,+expected: String) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL exported file exceeds bounded read fuel")
    case 1n+rest:
      file_hash_step(file,offset,extent,hash,expected,U32.is_eq(offset,extent),
        f => next => digest => file_hash_walk(rest,f,next,extent,digest,expected))

def file_sized(result: File & Result<&1,&1,U32 & String,U32>,+extent: U32,expected: String) -> IO(Unit):
  (file,value) = result
  do IO<Unit>:
    actual : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,value))
    Check.assert(U32.is_eq(actual,extent),"exported file has exact retained extent")
    file_hash_walk(4097n,file,0,extent,Meta.initial_hash(),expected)

def verify_file(path: String,extent: U32,expected: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"r"))
    size : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    file_sized(size,extent,expected)

def verified_origin(+db: U32,+snapshot: String,origin: Meta.Origin,expected: Expected,+fixture_sha: String) -> IO(Unit):
  Meta.Origin{_,_,_,_,_,+extent,records,+compressed,_,compressed_sha,sha} = origin
  Expected{+wanted,+digest} = expected
  do IO<Unit>:
    Check.assert(Meta.digest_valid(fixture_sha) && String.eq(compressed_sha,fixture_sha),
      "owned compressed commitment matches independently recorded fixture SHA256")
    Check.assert(U32.is_eq(records,100000) && U32.is_eq(extent,wanted) && String.eq(sha,digest),
      "100000 mixed records retain exact independently generated logical commitment")
    Check.assert(U32.is_gt(extent,4194304) && U32.is_gt(compressed,1048576),
      "large fixture exceeds both former archive batch caps")
    selected(db,snapshot,0)
    selected(db,snapshot,50000)
    selected(db,snapshot,99999)
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"streamneedle","claude","","","",10,0)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),10n),"large retained corpus supports bounded lexical search")
    Archive.verify(db,snapshot)
    Maintenance.export_raw(db,snapshot,"streaming-owned.jsonl")
    Archive.export_container(db,snapshot,"streaming-owned.zst")
    verify_file("streaming-owned.jsonl",wanted,digest)
    verify_file("streaming-owned.zst",compressed,fixture_sha)
    IO.print("snapshot=" ++ snapshot)
    IO.print("logical_extent=" ++ U32.show(wanted))
    IO.print("logical_sha256=" ++ digest)

def verify_snapshot(+db: U32,+snapshot: String,fixture_sha: String) -> IO(Unit):
  do IO<Unit>:
    value : Maybe<&2,Meta.Origin> <- Meta.read(db,snapshot,True{})
    origin : Meta.Origin <- Archive.required(value)
    verified_origin(db,snapshot,origin,expected(100000n,0,0,Meta.initial_hash()),fixture_sha)

# The compressor receives stdin, so this benchmark requires an ordinary
# checksummed frame without a content-size or dictionary-ID field. Read only
# magic, descriptor and window descriptor; Capture validates the full stream.
def selected_header(bytes: List<&2,U32>) -> IO(Unit):
  match bytes:
    case [40,181,47,253,+descriptor,_]:
      do IO<Unit>:
        IO.print("PASS selected compressed fixture starts with standard Zstandard magic")
        Check.assert(U32.is_eq(U32.and(descriptor,4),4),
          "selected compressed fixture enables content checksum")
        Check.assert(U32.is_eq(U32.and(descriptor,224),0),
          "selected compressed fixture has unknown content size and is not single segment")
        Check.assert(U32.is_eq(U32.and(descriptor,3),0),
          "selected compressed fixture has no dictionary-ID field")
        Check.assert(U32.is_eq(U32.and(descriptor,24),0),
          "selected compressed fixture keeps reserved and unused descriptor bits clear")
    case _: IO.die(Unit,1,"FAIL selected compressed fixture lacks a complete ordinary Zstandard header")

def check_source_header() -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open("streaming-source.jsonl.zst","r"))
    Store.read(Unit,file,0,6,f => bytes => do IO<Unit>:
      File.close(f)
      selected_header(bytes))

def capture() -> IO(Unit):
  do IO<Unit>:
    started : Nat <- IO.now()
    check_source_header()
    +db : U32 <- Store.open(".build/streaming.sqlite")
    +snapshot : String <- Capture.import_file(db,"claude","streaming-source.jsonl.zst")
    IO.print("captured_snapshot=" ++ snapshot)
    IO.try(Unit,Sql.close(db))
    elapsed("capture",started)

def inspect_rows(+db: U32,rows: List<&2,List<&2,Sql.Cell>>,fixture_sha: String) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{snapshot}]]: verify_snapshot(db,snapshot,fixture_sha)
    case _: IO.die(Unit,1,"FAIL large capture latest identity missing or ambiguous")

def source_absent(result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Fail{(code,_)}: Check.assert(U32.is_eq(code,2),"original compressed source is absent before retained verification")
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL remove the synthetic source before retained verification")

def inspect(fixture_sha: String) -> IO(Unit):
  do IO<Unit>:
    started : Nat <- IO.now()
    original : Result<&1,&1,U32 & String,File> <- File.open("streaming-source.jsonl.zst","r")
    source_absent(original)
    +db : U32 <- Store.open(".build/streaming.sqlite")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT latest FROM sources",[],2)
    inspect_rows(db,rows,fixture_sha)
    IO.try(Unit,Sql.close(db))
    elapsed("inspect",started)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "prepare" <> []: prepare()
    case _ <> "capture" <> []: capture()
    case _ <> "inspect" <> fixture_sha <> []: inspect(fixture_sha)
    case _: IO.die(Unit,2,"Use an isolated synthetic directory: archive-streaming prepare|capture|inspect COMPRESSED-SHA256")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
