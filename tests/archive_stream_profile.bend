import Base
import ../src/archive_meta.bend as Meta
import ../src/archive_profile.bend as Profile
import ../src/domain.bend as Domain
import ../src/sql.bend as Sql
import ./archive_meta.bend as Test

# Opaque synthetic metadata payloads, not claims of valid Zstandard streams.
# Independent fixture preparation used Python hashlib.sha256 over the fixed
# UTF-8 length-prefixed fields and over byte i repeated 65536 times, i=1..17.
# Batch commitment preimage: 340 bytes; stream commitment: 346 bytes.
def batch_commitment() -> String:
  "6c65b6a78139d4f6f13ef37ecbb59bcaf916e922862ba57fea78f6087ee55f6d"

def stream_commitment() -> String:
  "2dbfecd5493c4f6d0591852345af4437252ef2bc17b5e5307e90418964de14b7"

def compressed_sha() -> String:
  "24397706eb32f8691116fe4728d18eda7eacc40925e0ae26a5780cd8b8b13f80"

def logical_sha() -> String:
  "73cb3858a687a8494ca3323053016282f3dad39d42cf62ca4e79dda2aac7d9ac"

def large_sha() -> String:
  "c02a2d38c546b0e85a63c4fd7580d08d5a2bedf711634bca3d326a86734b5290"

def unknown(value: Maybe<&2,Profile.Profile>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def commitments() -> IO(Unit):
  do IO<Unit>:
    Test.assert(String.eq(Test.sha(),compressed_sha()) && String.eq(Test.logical_sha(),logical_sha()),
      "profile commitment inputs match independent physical and logical SHA256 literals")
    Test.assert(String.eq(Meta.origin_digest(Test.sample_header(),Test.sample_metadata()),batch_commitment()) &&
      String.eq(Meta.origin_digest_for(Profile.batch(),Test.sample_header(),Test.sample_metadata()),batch_commitment()),
      "archive-batch-v1 exact 340-byte commitment remains unchanged")
    Test.assert(String.eq(Meta.origin_digest_for(Profile.streaming(),Test.sample_header(),Test.sample_metadata()),stream_commitment()),
      "archive-stream-v2 exact 346-byte commitment binds its distinct limits")
    Test.assert(unknown(Profile.read("future-profile")) && unknown(Profile.read("archive-stream-v02")) &&
      unknown(Profile.read("archive-stream-v2\0")) && unknown(Profile.read("ARCHIVE-STREAM-V2")),
      "profile names require exact known values")
    Test.assert(Meta.metadata_valid_for(Profile.streaming(),Test.sample_header(),Meta.Metadata{1114112,17,large_sha(),logical_sha()}) &&
      Bool.not(Meta.metadata_valid_for(Profile.batch(),Test.sample_header(),Meta.Metadata{1114112,17,large_sha(),logical_sha()})),
      "stream profile admits seventeen full chunks while the batch profile still refuses")
    Test.assert(Test.missing_metadata(Meta.decode_metadata(Test.sample_header(),
      Test.replace(Test.metadata_cells(),2n,Sql.Cell.Text{Profile.name(Profile.streaming())}))),
      "changing a recognized profile without resealing its commitment is refused")

def prepare_empty() -> IO(U32):
  do IO<U32>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    Test.schema2(db)
    Meta.migrate(db)
    Test.archive_rows(db)
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    return db

def publish(+db: U32,extent: U32,sha: String) -> IO(Unit):
  do IO<Unit>:
    Test.finalized(db)
    Meta.seal_for(db,"3",Profile.streaming(),extent,sha,logical_sha())
    Meta.exec(db,"UPDATE snapshots SET accepted=1 WHERE id=3",[])
    Meta.exec(db,"COMMIT",[])

def prepared() -> IO(U32):
  do IO<U32>:
    +db : U32 <- prepare_empty()
    Meta.stage_one(db,"3",Profile.streaming(),0,0,[0,255])
    Meta.stage_one(db,"3",Profile.streaming(),1,2,[97,98,99])
    publish(db,5,compressed_sha())
    return db

def stage_large(fuel: Nat,+db: U32,+ordinal: U32,+offset: U32,hash: Domain.HashContext) -> IO(String):
  match fuel:
    case 0n: IO.pure(String,Domain.hash_finish(hash))
    case 1n+rest:
      +bytes = List.replicate(U32,65536n,U32.inc(ordinal))
      do IO<String>:
        Meta.stage_one(db,"3",Profile.streaming(),ordinal,offset,bytes)
        stage_large(rest,db,U32.inc(ordinal),U32.add(offset,65536),Domain.hash_bytes(bytes,hash))

def repeated(bytes: List<&2,U32>,+value: U32) -> Bool:
  match bytes:
    case []: True{}
    case byte <> rest: U32.is_eq(byte,value) && repeated(rest,value)

def inspected(read: Meta.Read,+ordinal: U32,+extent: U32,next: Meta.Reader -> U32 -> U32 -> IO(Unit)) -> IO(Unit):
  Meta.Read{reader,bytes} = read
  match bytes:
    case None{}:
      Test.assert(U32.is_eq(ordinal,17) && U32.is_eq(extent,1114112),
        "incremental reader reaches exact 17-chunk 1114112-byte end with verified container SHA256")
    case Some{+raw}:
      do IO<Unit>:
        Meta.checked(U32.is_lt(ordinal,17) && Nat.is_eq(List.length(&2,U32,raw),65536n) && repeated(raw,U32.inc(ordinal)),
          "FAIL bounded reader changed chunk length order or byte content")
        next(reader,U32.inc(ordinal),U32.add(extent,65536))

def inspect(fuel: Nat,+db: U32,reader: Meta.Reader,ordinal: U32,extent: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.die(Unit,1,"FAIL bounded reader did not end within its declared chunk count")
    case 1n+rest:
      do IO<Unit>:
        read : Meta.Read <- Meta.next(db,reader)
        inspected(read,ordinal,extent,next => count => total => inspect(rest,db,next,count,total))

def large_opened(db: U32,opened: Meta.Open) -> IO(Unit):
  Meta.Open{Meta.Origin{snapshot,source,generation,provider,locator,logical,records,compressed,chunks,sha,logical_digest},reader} = opened
  do IO<Unit>:
    Test.assert(String.eq(snapshot,"3") && String.eq(source,"1") && String.eq(generation,"2") && String.eq(provider,"codex") &&
      String.eq(locator,"/synthetic/meta.jsonl.zst") && U32.is_eq(logical,2) && U32.is_eq(records,1) &&
      U32.is_eq(compressed,1114112) && U32.is_eq(chunks,17) && String.eq(sha,large_sha()) && String.eq(logical_digest,logical_sha()),
      "stream origin retains exact identities and separate logical and physical commitments")
    inspect(18n,db,reader,0,0)

def drained(db: U32,opened: Meta.Open) -> IO(Unit):
  Meta.Open{_,reader} = opened
  Meta.validate_reader(db,reader)

def large() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- prepare_empty()
    digest : String <- stage_large(17n,db,0,0,Meta.initial_hash())
    Test.assert(String.eq(digest,large_sha()),"incremental staging matches independent seventeen-chunk SHA256 literal")
    publish(db,1114112,large_sha())
    Test.check(db,"SELECT profile,compressed_extent,chunks FROM archive_captures WHERE snapshot=3",
      [[Sql.Cell.Text{"archive-stream-v2"},Sql.Cell.Integer{"1114112"},Sql.Cell.Integer{"17"}]],
      "stream publication stores its exact versioned profile and extent")
    opened : Meta.Open <- Meta.open_reader(db,"3",True{})
    large_opened(db,opened)
    again : Meta.Open <- Meta.open_reader(db,"3",True{})
    drained(db,again)
    IO.print("PASS bounded validation drains a fresh seventeen-chunk reader")
    IO.try(Unit,Sql.close(db))

def batch_readable() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Test.prepared()
    opened : Meta.Open <- Meta.open_reader(db,"3",True{})
    drained(db,opened)
    Test.check(db,"SELECT profile FROM archive_captures WHERE snapshot=3",[[Sql.Cell.Text{"archive-batch-v1"}]],
      "previous batch profile remains readable through the bounded reader")
    IO.try(Unit,Sql.close(db))

def count_lie(+db: U32) -> IO(Unit):
  do IO<Unit>:
    header : Meta.Header <- Meta.header(db,"3",True{})
    commitment : String = Meta.origin_digest_for(Profile.streaming(),header,Meta.Metadata{5,3,compressed_sha(),logical_sha()})
    Meta.exec(db,"UPDATE archive_captures SET chunks=3,commitment=? WHERE snapshot=3",[Sql.Cell.Text{commitment}])

def corrupt(+db: U32,mode: String) -> IO(Unit):
  match mode:
    case "profile-known":
      Meta.exec(db,"UPDATE archive_captures SET profile='archive-batch-v1' WHERE snapshot=3",[])
    case "profile-type":
      Meta.exec(db,"UPDATE archive_captures SET profile=? WHERE snapshot=3",[Sql.Cell.Blob{Domain.encode("archive-stream-v2")}])
    case "chunk-ordinal":
      Meta.exec(db,"UPDATE archive_chunks SET ordinal=7 WHERE snapshot=3 AND ordinal=0",[])
    case "chunk-count": count_lie(db)
    case "chunk-zero":
      Meta.exec(db,"UPDATE archive_chunks SET n=0,bytes=? WHERE snapshot=3 AND ordinal=0",[Sql.Cell.Blob{[]}])
    case other: Test.corruption(db,other)

def child(mode: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- prepared()
    corrupt(db,mode)
    opened : Meta.Open <- Meta.open_reader(db,"3",True{})
    drained(db,opened)
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"CORRUPT-STREAM-PROFILE-WAS-ACCEPTED")

def expected_error(mode: String) -> String:
  match mode:
    case "profile-known": "Archive origin, required format, limits or commitment are corrupt"
    case "profile-type": "Archive origin, required format, limits or commitment are corrupt"
    case "metadata-profile": "Archive origin, required format, limits or commitment are corrupt"
    case "chunk-count": "Archive count, extent or SHA256 is invalid"
    case "chunk-missing": "Archive count, extent or SHA256 is invalid"
    case "chunk-extra": "Archive count, extent or SHA256 is invalid"
    case "chunk-ordinal": "Archive chunk is missing or ambiguous"
    case "chunk-position": "Archive chunks are missing, reordered or noncontiguous"
    case _: "Archive chunk types, bytes or digest are corrupt"

def rejected(result: Result<&1,&1,U32 & String,U32 & (String & String)>,+mode: String) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,1,"FAIL streaming metadata child transport: " ++ mode)
    case Done{(code,(out,err))}:
      Test.assert(U32.is_eq(code,1) && String.contains(out ++ err,expected_error(mode)),
        "bounded reader refuses " ++ mode ++ " with explicit validation failure")

def cases(modes: List<&2,String>,+self: String) -> IO(Unit):
  match modes:
    case []: IO.pure(Unit,Unit{})
    case +mode <> rest:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(self,["child",mode],"",4096,10000)
        rejected(result,mode)
        cases(rest,self)

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    commitments()
    batch_readable()
    large()
    cases(["metadata-profile","profile-known","profile-type","chunk-n-type","chunk-type","chunk-large",
      "chunk-length","chunk-zero","chunk-digest","chunk-bytes","chunk-position","chunk-ordinal",
      "chunk-count","chunk-missing","chunk-extra"],self)
    IO.print("Archive streaming profile suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case [_,"child",mode]: child(mode)
    case _: IO.die(Unit,2,"Archive streaming profile test expects no arguments or owned child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
