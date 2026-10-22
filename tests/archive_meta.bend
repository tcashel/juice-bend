import Base
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as Domain
import ../src/sql.bend as Sql

# These bytes are opaque container evidence, not decoder fixtures. Zstandard
# validity belongs to ArchiveCapture/ArchiveMaintenance's separate decoder gate.
def chunks() -> List<&2,List<&2,U32>>:
  [[0,255],[97,98,99]]

def sha() -> String:
  Meta.digest_chunks(chunks())

def logical_sha() -> String:
  Domain.digest([120,10])

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def cell_equal(left: Sql.Cell,right: Sql.Cell) -> Bool:
  match left right:
    case Sql.Cell.Integer{a} Sql.Cell.Integer{b}:
      String.eq(a,b)
    case Sql.Cell.Text{a} Sql.Cell.Text{b}:
      String.eq(a,b)
    case Sql.Cell.Blob{a} Sql.Cell.Blob{b}:
      Domain.bytes_equal(a,b)
    case Sql.Cell.Null{} Sql.Cell.Null{}:
      True{}
    case _ _:
      False{}

def row_equal(left: List<&2,Sql.Cell>,right: List<&2,Sql.Cell>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case a <> rest b <> tail:
      cell_equal(a,b) && row_equal(rest,tail)
    case _ _:
      False{}

def rows_equal(left: List<&2,List<&2,Sql.Cell>>,right: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case a <> rest b <> tail:
      row_equal(a,b) && rows_equal(rest,tail)
    case _ _:
      False{}

def chunks_equal(left: List<&2,List<&2,U32>>,right: List<&2,List<&2,U32>>) -> Bool:
  match left right:
    case Nil{} Nil{}:
      True{}
    case a <> rest b <> tail:
      Domain.bytes_equal(a,b) && chunks_equal(rest,tail)
    case _ _:
      False{}

def check(db: U32,sql: String,expected: List<&2,List<&2,Sql.Cell>>,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : List<&2,List<&2,Sql.Cell>> <- Meta.q(db,sql,[],8)
    assert(rows_equal(actual,expected),label)

def schema2(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Meta.exec(db,"PRAGMA foreign_keys=ON",[])
    Meta.exec(db,"CREATE TABLE sources(id INTEGER PRIMARY KEY,provider TEXT NOT NULL,locator TEXT NOT NULL,latest INTEGER)",[])
    Meta.exec(db,"CREATE TABLE generations(id INTEGER PRIMARY KEY,source INTEGER NOT NULL REFERENCES sources(id))",[])
    Meta.exec(db,"CREATE TABLE snapshots(id INTEGER PRIMARY KEY,generation INTEGER NOT NULL REFERENCES generations(id),extent INTEGER NOT NULL,checkpoint INTEGER NOT NULL,checkpoint_ordinal INTEGER NOT NULL,records INTEGER NOT NULL,accepted INTEGER NOT NULL)",[])
    Meta.exec(db,"CREATE TABLE raw(id INTEGER PRIMARY KEY,bytes BLOB NOT NULL)",[])
    Meta.exec(db,"INSERT INTO sources VALUES(9007199254740993,'codex','/synthetic/meta.jsonl',9007199254740995)",[])
    Meta.exec(db,"INSERT INTO generations VALUES(9007199254740994,9007199254740993)",[])
    Meta.exec(db,"INSERT INTO snapshots VALUES(9007199254740995,9007199254740994,0,0,0,0,1)",[])
    Meta.exec(db,"INSERT INTO raw VALUES(9223372036854775807,?)",[Sql.Cell.Blob{[0,255,10,97]}])
    Meta.exec(db,"PRAGMA user_version=2",[])

def archive_rows(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Meta.exec(db,"INSERT INTO sources VALUES(1,'codex','/synthetic/meta.jsonl.zst',NULL)",[])
    Meta.exec(db,"INSERT INTO generations(id,source,encoding) VALUES(2,1,?)",[Sql.Cell.Text{Meta.encoding()}])
    Meta.exec(db,"INSERT INTO snapshots VALUES(3,2,2,0,0,0,0)",[])

def finalized(+db: U32) -> IO(Unit):
  Meta.exec(db,"UPDATE snapshots SET records=1,checkpoint=2,checkpoint_ordinal=1 WHERE id=3",[])

def prepared() -> IO(U32):
  do IO<U32>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    schema2(db)
    Meta.migrate(db)
    archive_rows(db)
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    Meta.stage(db,"3",chunks())
    finalized(db)
    Meta.seal(db,"3",5,sha(),logical_sha())
    Meta.exec(db,"UPDATE snapshots SET accepted=1 WHERE id=3",[])
    Meta.exec(db,"COMMIT",[])
    return db

def plain(value: Maybe<&2,Meta.Origin>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def exact_origin(value: Maybe<&2,Meta.Origin>) -> Bool:
  match value:
    case Some{Meta.Origin{snapshot,source,generation,provider,locator,logical,records,compressed,count,a,b}}:
      String.eq(snapshot,"3") && String.eq(source,"1") && String.eq(generation,"2") &&
        String.eq(provider,"codex") && String.eq(locator,"/synthetic/meta.jsonl.zst") &&
        U32.is_eq(logical,2) && U32.is_eq(records,1) && U32.is_eq(compressed,5) &&
        U32.is_eq(count,2) && String.eq(a,sha()) && String.eq(b,logical_sha())
    case _:
      False{}

def migration() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    schema2(db)
    Meta.migrate(db)
    Meta.migrate(db)
    check(db,"PRAGMA user_version",[[Sql.Cell.Integer{"3"}]],"schema2 migration is idempotent at schema3")
    check(db,"SELECT id,source,encoding FROM generations",
      [[Sql.Cell.Integer{"9007199254740994"},Sql.Cell.Integer{"9007199254740993"},Sql.Cell.Text{"identity"}]],
      "migration preserves exact above2^53 IDs and marks existing generation identity")
    check(db,"SELECT id,bytes FROM raw",[[Sql.Cell.Integer{"9223372036854775807"},Sql.Cell.Blob{[0,255,10,97]}]],
      "migration preserves signed64 maximum identity and exact binary raw bytes")
    old : Maybe<&2,Meta.Origin> <- Meta.read(db,"9007199254740995",True{})
    assert(plain(old),"valid identity snapshot has no invented archive origin")
    archive_rows(db)
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    Meta.stage(db,"3",chunks())
    check(db,"SELECT count(*) FROM archive_captures",[[Sql.Cell.Integer{"0"}]],
      "staging physical bytes does not fabricate sealed metadata")
    check(db,"SELECT ordinal,offset,n FROM archive_chunks ORDER BY ordinal",
      [[Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"2"}],
       [Sql.Cell.Integer{"1"},Sql.Cell.Integer{"2"},Sql.Cell.Integer{"3"}]],
      "staging preserves contiguous ordinals and exact byte extents")
    finalized(db)
    Meta.seal(db,"3",5,sha(),logical_sha())
    before : Maybe<&2,Meta.Origin> <- Meta.read(db,"3",False{})
    assert(exact_origin(before),"unaccepted sealed origin binds actual final snapshot metadata")
    physical : List<&2,List<&2,U32>> <- Meta.container(db,"3",False{})
    assert(chunks_equal(physical,chunks()),"staging container roundtrips exact nonUTF8 and original chunk order")
    Meta.exec(db,"ROLLBACK",[])
    check(db,"SELECT count(*) FROM archive_captures",[[Sql.Cell.Integer{"0"}]],"rollback discards candidate origin")
    check(db,"SELECT count(*) FROM archive_chunks",[[Sql.Cell.Integer{"0"}]],"rollback discards every candidate compressed chunk")
    check(db,"SELECT records,checkpoint,accepted FROM snapshots WHERE id=3",
      [[Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"}]],"rollback restores logical snapshot header")
    IO.try(Unit,Sql.close(db))

def roundtrip() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- prepared()
    value : Maybe<&2,Meta.Origin> <- Meta.read(db,"3",True{})
    assert(exact_origin(value),"accepted read validates complete immutable origin")
    physical : List<&2,List<&2,U32>> <- Meta.container(db,"3",True{})
    assert(chunks_equal(physical,chunks()),"accepted container needs no original source path")
    Meta.exec(db,"INSERT INTO snapshots VALUES(4,2,0,0,0,0,0)",[])
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    Meta.stage(db,"4",[[1]])
    Meta.seal(db,"4",1,Domain.digest([1]),Domain.digest([]))
    empty : List<&2,List<&2,U32>> <- Meta.container(db,"4",False{})
    assert(chunks_equal(empty,[[1]]),"nonempty container with empty logical stream retains physical evidence")
    Meta.exec(db,"ROLLBACK",[])
    IO.try(Unit,Sql.close(db))

def sample_header() -> Meta.Header:
  Meta.Header{"9007199254740993","9007199254740994","9223372036854775807",
    "codex","/synthetic/café\0:🍋",2,1,2,1,True{},Meta.encoding()}

def sample_metadata() -> Meta.Metadata:
  Meta.Metadata{5,2,sha(),logical_sha()}

def header_cells() -> List<&2,Sql.Cell>:
  [Sql.Cell.Integer{"9007199254740993"},Sql.Cell.Integer{"9007199254740994"},
   Sql.Cell.Integer{"9223372036854775807"},Sql.Cell.Text{"codex"},Sql.Cell.Text{"/synthetic/café\0:🍋"},
   Sql.Cell.Integer{"2"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"2"},Sql.Cell.Integer{"1"},
   Sql.Cell.Integer{"1"},Sql.Cell.Text{Meta.encoding()}]

def metadata_cells() -> List<&2,Sql.Cell>:
  [Sql.Cell.Integer{"9007199254740993"},Sql.Cell.Text{Meta.format()},Sql.Cell.Text{Meta.profile()},
   Sql.Cell.Integer{"5"},Sql.Cell.Integer{"2"},Sql.Cell.Text{sha()},Sql.Cell.Text{logical_sha()},
   Sql.Cell.Text{Meta.origin_digest(sample_header(),sample_metadata())}]

def chunk_cells() -> List<&2,Sql.Cell>:
  [Sql.Cell.Integer{"9007199254740993"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},
   Sql.Cell.Integer{"3"},Sql.Cell.Text{Meta.chunk_digest("9007199254740993",0,0,3,[97,98,99])},
   Sql.Cell.Blob{[97,98,99]}]

def missing_header(value: Maybe<&2,Meta.Header>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def missing_metadata(value: Maybe<&2,Meta.Metadata>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def missing_chunk(value: Maybe<&2,Meta.Chunk>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def replace(cells: List<&2,Sql.Cell>,index: Nat,value: Sql.Cell) -> List<&2,Sql.Cell>:
  match cells index:
    case [] _:
      []
    case _ <> rest 0n:
      value <> rest
    case first <> rest 1n+left:
      first <> replace(rest,left,value)

def bad_ids(values: List<&2,String>) -> IO(Unit):
  match values:
    case []:
      IO.pure(Unit,Unit{})
    case +value <> rest:
      do IO<Unit>:
        assert(Bool.not(Meta.identity(value)),"reject noncanonical signed64 identity: " ++ value)
        bad_ids(rest)

def type_columns(fuel: Nat,+index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        assert(missing_header(Meta.decode_header(replace(header_cells(),index,Sql.Cell.Null{}))) &&
          missing_header(Meta.decode_header(replace(header_cells(),index,Sql.Cell.Real{"1"}))) &&
          missing_header(Meta.decode_header(replace(header_cells(),index,Sql.Cell.Blob{[49]}))),
          "header rejects Null Real Blob column " ++ Nat.show(index))
        type_columns(rest,1n+index)

def meta_columns(fuel: Nat,+index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        assert(missing_metadata(Meta.decode_metadata(sample_header(),replace(metadata_cells(),index,Sql.Cell.Null{}))) &&
          missing_metadata(Meta.decode_metadata(sample_header(),replace(metadata_cells(),index,Sql.Cell.Real{"1"}))) &&
          missing_metadata(Meta.decode_metadata(sample_header(),replace(metadata_cells(),index,Sql.Cell.Blob{[49]}))),
          "origin rejects Null Real Blob column " ++ Nat.show(index))
        meta_columns(rest,1n+index)

def origin_bindings(headers: List<&2,Meta.Header>,+digest: String,+index: Nat) -> IO(Unit):
  match headers:
    case []:
      IO.pure(Unit,Unit{})
    case h <> rest:
      do IO<Unit>:
        assert(Bool.not(String.eq(Meta.origin_digest(h,sample_metadata()),digest)),
          "origin checksum binds snapshot header field " ++ Nat.show(index))
        origin_bindings(rest,digest,1n+index)

def fragmentation_limit() -> IO(Unit):
  +seventeen = {Meta.Metadata{17,17,sha(),logical_sha()} : Meta.Metadata}
  do IO<Unit>:
    assert(U32.is_eq(Meta.chunk_count_limit(),16),"archive profile explicitly caps stored chunks at sixteen")
    assert(Meta.chunks_valid(List.replicate(List<&2,U32>,16n,[0]),0) &&
      Bool.not(Meta.chunks_valid(List.replicate(List<&2,U32>,17n,[0]),0)),
      "stage accepts sixteen tiny chunks and rejects seventeen within the byte limit")
    assert(Meta.chunks_valid(List.replicate(List<&2,U32>,16n,List.replicate(U32,65536n,0)),0),
      "sixteen full chunks retain the exact one MiB container allowance")
    assert(Meta.metadata_valid(sample_header(),Meta.Metadata{16,16,sha(),logical_sha()}) &&
      Bool.not(Meta.metadata_valid(sample_header(),seventeen)),
      "origin enforces chunk count independently of compressed byte extent")
    assert(missing_metadata(Meta.decode_metadata(sample_header(),
      [Sql.Cell.Integer{"9007199254740993"},Sql.Cell.Text{Meta.format()},Sql.Cell.Text{Meta.profile()},
       Sql.Cell.Integer{"17"},Sql.Cell.Integer{"17"},Sql.Cell.Text{sha()},Sql.Cell.Text{logical_sha()},
       Sql.Cell.Text{Meta.origin_digest(sample_header(),seventeen)}])),
      "correctly resealed origin with seventeen chunks is rejected before scanning")

def codecs() -> IO(Unit):
  do IO<Unit>:
    assert(Meta.identity("1") && Meta.identity("9007199254740993") && Meta.identity("9223372036854775807"),
      "identities preserve exact signed64 range above floating precision")
    bad_ids(["","0","01","+1","-1","1.0","1e0"," 1","1 ","9223372036854775808"])
    assert(Domain.bytes_equal(Meta.framed("é\0:"),[52,58,195,169,0,58]),
      "framing counts UTF8 bytes and retains embedded NUL separator")
    assert(String.eq(Meta.digest_chunks([]),"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") &&
      String.eq(Meta.digest_chunks([[97],[],[98,99]]),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),
      "streaming SHA agrees with independent empty and abc known vectors")
    assert(String.eq(Meta.chunk_digest("9007199254740993",0,0,3,[97,98,99]),
      "ca6d62aadf52ceb070de30e4b6e1a07280aaf2fdd7321d66864ed20b1bb42d4c"),
      "domain-separated chunk hash matches independent 50-byte SHA256 vector")
    assert(Bool.not(missing_header(Meta.decode_header(header_cells()))) &&
      Bool.not(missing_metadata(Meta.decode_metadata(sample_header(),metadata_cells()))) &&
      Bool.not(missing_chunk(Meta.decode_chunk("9007199254740993",chunk_cells()))),
      "strict codecs accept independently typed valid header origin and chunk")
    type_columns(11n,0n)
    meta_columns(8n,0n)
    assert(missing_header(Meta.decode_header(replace(header_cells(),0n,Sql.Cell.Text{"9007199254740993"}))) &&
      missing_header(Meta.decode_header(replace(header_cells(),5n,Sql.Cell.Integer{"4294967296"}))) &&
      missing_header(Meta.decode_header(replace(header_cells(),9n,Sql.Cell.Integer{"2"}))),
      "header rejects coerced identity overflow and nonBoolean accepted flag")
    assert(missing_metadata(Meta.decode_metadata(sample_header(),replace(metadata_cells(),1n,Sql.Cell.Text{"unknown"}))) &&
      missing_metadata(Meta.decode_metadata(sample_header(),replace(metadata_cells(),2n,Sql.Cell.Text{"unknown"}))) &&
      missing_metadata(Meta.decode_metadata(sample_header(),replace(metadata_cells(),3n,Sql.Cell.Integer{"1048577"}))),
      "origin rejects unknown required format profile and excessive physical size")
    assert(missing_chunk(Meta.decode_chunk("9007199254740994",chunk_cells())) &&
      missing_chunk(Meta.decode_chunk("9007199254740993",replace(chunk_cells(),5n,Sql.Cell.Text{"abc"}))) &&
      missing_chunk(Meta.decode_chunk("9007199254740993",replace(chunk_cells(),5n,Sql.Cell.Blob{[97,98,100]}))) &&
      missing_chunk(Meta.decode_chunk("9007199254740993",replace(chunk_cells(),3n,Sql.Cell.Integer{"2"}))),
      "chunk decoder binds snapshot type exact bytes and length")
    assert(Meta.chunks_valid(chunks(),0) && Bool.not(Meta.chunks_valid([],0)) &&
      Bool.not(Meta.chunks_valid([[]],0)) && Bool.not(Meta.chunks_valid([[256]],0)) &&
      Bool.not(Meta.chunks_valid([List.replicate(U32,65537n,0)],0)),
      "stage preflight refuses empty zero-sized nonoctet and oversized chunks")
    fragmentation_limit()
    origin_bindings([
      Meta.Header{"9007199254740992","9007199254740994","9223372036854775807","codex","/synthetic/café\0:🍋",2,1,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740995","9223372036854775807","codex","/synthetic/café\0:🍋",2,1,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775806","codex","/synthetic/café\0:🍋",2,1,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","claude","/synthetic/café\0:🍋",2,1,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","codex","/synthetic/other",2,1,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","codex","/synthetic/café\0:🍋",3,1,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","codex","/synthetic/café\0:🍋",2,2,2,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","codex","/synthetic/café\0:🍋",2,1,0,1,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","codex","/synthetic/café\0:🍋",2,1,2,0,True{},Meta.encoding()},
      Meta.Header{"9007199254740993","9007199254740994","9223372036854775807","codex","/synthetic/café\0:🍋",2,1,2,1,True{},"identity"}],
      Meta.origin_digest(sample_header(),sample_metadata()),0n)

def corruption(+db: U32,mode: String) -> IO(Unit):
  match mode:
    case "missing-origin":
      Meta.exec(db,"DELETE FROM archive_captures WHERE snapshot=3",[])
    case "unknown-codec":
      Meta.exec(db,"UPDATE generations SET encoding='future-format' WHERE id=2",[])
    case "identity-origin":
      Meta.exec(db,"UPDATE generations SET encoding='identity' WHERE id=2",[])
    case "header-provider":
      Meta.exec(db,"UPDATE sources SET provider='claude' WHERE id=1",[])
    case "header-checkpoint":
      Meta.exec(db,"UPDATE snapshots SET checkpoint=1 WHERE id=3",[])
    case "metadata-type":
      Meta.exec(db,"UPDATE archive_captures SET compressed_sha=? WHERE snapshot=3",[Sql.Cell.Blob{Domain.encode(sha())}])
    case "metadata-profile":
      Meta.exec(db,"UPDATE archive_captures SET profile='future-profile' WHERE snapshot=3",[])
    case "origin-logical-sha":
      Meta.exec(db,"UPDATE archive_captures SET logical_sha=? WHERE snapshot=3",[Sql.Cell.Text{Domain.digest([0])}])
    case "origin-extent":
      Meta.exec(db,"UPDATE archive_captures SET compressed_extent=6 WHERE snapshot=3",[])
    case "chunk-bytes":
      Meta.exec(db,"UPDATE archive_chunks SET bytes=? WHERE snapshot=3 AND ordinal=0",[Sql.Cell.Blob{[0,254]}])
    case "chunk-type":
      Meta.exec(db,"UPDATE archive_chunks SET bytes=? WHERE snapshot=3 AND ordinal=1",[Sql.Cell.Text{"abc"}])
    case "chunk-large":
      Meta.exec(db,"UPDATE archive_chunks SET n=65537,bytes=zeroblob(65537) WHERE snapshot=3 AND ordinal=0",[])
    case "chunk-length":
      do IO<Unit>:
        Meta.exec(db,"PRAGMA ignore_check_constraints=ON",[])
        Meta.exec(db,"UPDATE archive_chunks SET bytes=zeroblob(65537) WHERE snapshot=3 AND ordinal=0",[])
    case "chunk-n-type":
      do IO<Unit>:
        Meta.exec(db,"PRAGMA ignore_check_constraints=ON",[])
        Meta.exec(db,"UPDATE archive_chunks SET n='two' WHERE snapshot=3 AND ordinal=0",[])
    case "chunk-digest":
      Meta.exec(db,"UPDATE archive_chunks SET digest=? WHERE snapshot=3 AND ordinal=0",[Sql.Cell.Text{String.repeat("a",64n)}])
    case "chunk-position":
      Meta.exec(db,"UPDATE archive_chunks SET offset=1,digest=? WHERE snapshot=3 AND ordinal=0",
        [Sql.Cell.Text{Meta.chunk_digest("3",0,1,2,[0,255])}])
    case "chunk-missing":
      Meta.exec(db,"DELETE FROM archive_chunks WHERE snapshot=3 AND ordinal=0",[])
    case "chunk-extra":
      Meta.exec(db,"INSERT INTO archive_chunks VALUES(3,2,5,1,?,?)",
        [Sql.Cell.Text{Meta.chunk_digest("3",2,5,1,[0])},Sql.Cell.Blob{[0]}])
    case "not-accepted":
      Meta.exec(db,"UPDATE snapshots SET accepted=0 WHERE id=3",[])
    case _:
      IO.die(Unit,2,"Unknown metadata corruption test")

def corruption_child(mode: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- prepared()
    corruption(db,mode)
    bytes : List<&2,List<&2,U32>> <- Meta.container(db,"3",True{})
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"CORRUPTION-WAS-ACCEPTED")

def fragmentation_child() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    schema2(db)
    Meta.migrate(db)
    archive_rows(db)
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    Meta.stage(db,"3",List.replicate(List<&2,U32>,17n,[0]))
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"SEVENTEEN-CHUNKS-WERE-ACCEPTED")

def child(mode: String) -> IO(Unit):
  match mode:
    case "seventeen-chunks":
      fragmentation_child()
    case other:
      corruption_child(other)

def expected_error(mode: String) -> String:
  match mode:
    case "seventeen-chunks":
      "Compressed chunks exceed archive limits or contain non-octets"
    case "unknown-codec":
      "Unsupported generation encoding"
    case "identity-origin":
      "Snapshot already has compressed archive metadata or chunks"
    case "chunk-large":
      "Archive chunk types, bytes or digest are corrupt"
    case "chunk-length":
      "Archive chunk types, bytes or digest are corrupt"
    case "chunk-n-type":
      "Archive chunk types, bytes or digest are corrupt"
    case _:
      "Archive"

def rejected(result: Result<&1,&1,U32 & String,U32 & (String & String)>,+label: String) -> IO(Unit):
  match result:
    case Fail{_}:
      IO.die(Unit,1,"FAIL metadata child transport: " ++ label)
    case Done{(code,(out,err))}:
      assert(U32.is_eq(code,1) && String.contains(out ++ err,expected_error(label)),
        "owned child rejects " ++ label ++ " with explicit validation failure")

def fatal_cases(cases: List<&2,String>,+self: String) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case +mode <> rest:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run(self,["child",mode],"",4096,10000)
        rejected(result,mode)
        fatal_cases(rest,self)

def migration_failure_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{_}:
      IO.die(Unit,1,"FAIL atomic migration child transport")
    case Done{(code,_)}:
      assert(U32.is_eq(code,1),"owned migration worker exits at deliberately conflicting table")

def migration_child(path: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(path))
    Meta.migrate(db)
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"MIGRATION-CONFLICT-WAS-ACCEPTED")

def migration_atomic(self: String) -> IO(Unit):
  do IO<Unit>:
    first : U32 <- IO.try(U32,IO.random_u32())
    second : U32 <- IO.try(U32,IO.random_u32())
    +path : String = "/tmp/juice-bend-archive-meta-" ++ U32.show(first) ++ "-" ++ U32.show(second) ++ ".sqlite"
    +db : U32 <- IO.try(U32,Sql.open(path))
    schema2(db)
    Meta.exec(db,"CREATE TABLE archive_chunks(sentinel BLOB NOT NULL)",[])
    Meta.exec(db,"INSERT INTO archive_chunks VALUES(?)",[Sql.Cell.Blob{[255,0,7]}])
    IO.try(Unit,Sql.close(db))
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["migration-child",path],"",4096,10000)
    migration_failure_result(result)
    +reopened : U32 <- IO.try(U32,Sql.open(path))
    check(reopened,"PRAGMA user_version",[[Sql.Cell.Integer{"2"}]],
      "failed migration preserves schema2 version after worker exit")
    check(reopened,"SELECT name FROM pragma_table_info('generations') ORDER BY cid",
      [[Sql.Cell.Text{"id"}],[Sql.Cell.Text{"source"}]],
      "failed migration rolls back encoding column atomically")
    check(reopened,"SELECT count(*) FROM sqlite_schema WHERE name='archive_captures'",[[Sql.Cell.Integer{"0"}]],
      "failed migration rolls back newly created origin table")
    check(reopened,"SELECT sentinel FROM archive_chunks",[[Sql.Cell.Blob{[255,0,7]}]],
      "failed migration preserves conflicting preexisting data")
    check(reopened,"SELECT id,bytes FROM raw",[[Sql.Cell.Integer{"9223372036854775807"},Sql.Cell.Blob{[0,255,10,97]}]],
      "failed migration leaves original signed64 raw identity and bytes intact")
    IO.try(Unit,Sql.close(reopened))

def projected_null(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case [[_,_,_,_,_,Sql.Cell.Null{}]]: True{}
    case _: False{}

def projected_full(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case [[_,_,_,Sql.Cell.Integer{"65536"},_,Sql.Cell.Blob{bytes}]]:
      Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(65536))
    case _: False{}

def chunk_admission() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- prepared()
    corruption(db,"chunk-large")
    check(db,"SELECT typeof(n),n,typeof(bytes),length(bytes) FROM archive_chunks WHERE snapshot=3 AND ordinal=0",
      [[Sql.Cell.Text{"integer"},Sql.Cell.Integer{"65537"},Sql.Cell.Text{"blob"},Sql.Cell.Integer{"65537"}]],
      "oversized corrupt chunk has valid integer and BLOB types with matching length")
    large : List<&2,List<&2,Sql.Cell>> <- Meta.chunk_rows(db,"3",0)
    assert(projected_null(large),"oversized chunk payload is withheld before crossing the bridge into Bend")
    Meta.exec(db,"UPDATE archive_chunks SET n=65536,bytes=zeroblob(65536) WHERE snapshot=3 AND ordinal=0",[])
    full : List<&2,List<&2,Sql.Cell>> <- Meta.chunk_rows(db,"3",0)
    assert(projected_full(full),"admission preserves the exact allowed64KiB chunk payload")
    corruption(db,"chunk-length")
    mismatch : List<&2,List<&2,Sql.Cell>> <- Meta.chunk_rows(db,"3",0)
    assert(projected_null(mismatch),"mismatched n and BLOB length withholds the corrupt payload")
    corruption(db,"chunk-n-type")
    wrong_n : List<&2,List<&2,Sql.Cell>> <- Meta.chunk_rows(db,"3",0)
    assert(projected_null(wrong_n),"wrong n storage type withholds the corrupt payload")
    corruption(db,"chunk-type")
    wrong_blob : List<&2,List<&2,Sql.Cell>> <- Meta.chunk_rows(db,"3",1)
    assert(projected_null(wrong_blob),"non-BLOB storage type withholds the corrupt payload")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    codecs()
    migration()
    migration_atomic(self)
    roundtrip()
    chunk_admission()
    fatal_cases(["missing-origin","unknown-codec","identity-origin","header-provider",
      "header-checkpoint","metadata-type","metadata-profile","origin-logical-sha","origin-extent",
      "chunk-bytes","chunk-type","chunk-large","chunk-length","chunk-n-type","chunk-digest","chunk-position","chunk-missing","chunk-extra","not-accepted",
      "seventeen-chunks"],self)
    IO.print("Archive metadata suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]:
      suite(self)
    case [_,"child",mode]:
      child(mode)
    case [_,"migration-child",path]:
      migration_child(path)
    case _:
      IO.die(Unit,2,"Archive metadata test expects zero arguments or owned child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
