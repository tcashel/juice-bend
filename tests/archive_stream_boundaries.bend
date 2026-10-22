import Base
import ../src/archive_meta.bend as Meta
import ../src/archive_profile.bend as Profile
import ../src/domain.bend as Domain
import ../src/sql.bend as Sql
import ./archive_meta.bend as Test
import ./archive_stream_profile.bend as Fixture

# Metadata-level tests use opaque synthetic container bytes. The WAL test
# deliberately interleaves two real SQLite connections; it does not claim an
# end-to-end concurrent Store import or a valid Zstandard transformation.
def invalid(+db: U32,kind: String) -> IO(Unit):
  match kind:
    case "ordinal": Meta.stage_one(db,"3",Profile.streaming(),1024,0,[7])
    case "offset-above": Meta.stage_one(db,"3",Profile.streaming(),0,67108865,[7])
    case "offset-at-end": Meta.stage_one(db,"3",Profile.streaming(),0,67108864,[7])
    case "crossing-end": Meta.stage_one(db,"3",Profile.streaming(),0,67108863,[7,8])
    case "empty": Meta.stage_one(db,"3",Profile.streaming(),0,0,[])
    case "large-chunk": Meta.stage_one(db,"3",Profile.streaming(),0,0,List.replicate(U32,65537n,7))
    case "non-octet": Meta.stage_one(db,"3",Profile.streaming(),0,0,[256])
    case _: IO.die(Unit,78,"FAIL unknown boundary fixture")

def child(kind: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Fixture.prepare_empty()
    invalid(db,kind)
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"INVALID-CHUNK-BOUNDARY-WAS-ACCEPTED")

def rejected(result: Result<&1,&1,U32 & String,U32 & (String & String)>,label: String) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,1,"FAIL boundary child transport")
    case Done{(code,(out,err))}:
      Test.assert(U32.is_eq(code,1) && String.contains(out ++ err,
        "Compressed chunk exceeds archive profile or contains non-octets"),
        "stage_one explicitly refuses " ++ label)

def cases(kinds: List<&2,String>,+self: String) -> IO(Unit):
  match kinds:
    case []: IO.pure(Unit,Unit{})
    case +kind <> rest:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(self,["child",kind],"",4096,10000)
        rejected(result,kind)
        cases(rest,self)

def valid_edges() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Fixture.prepare_empty()
    Meta.stage_one(db,"3",Profile.streaming(),1023,67108863,[255])
    Test.check(db,"SELECT ordinal,offset,n,bytes FROM archive_chunks",
      [[Sql.Cell.Integer{"1023"},Sql.Cell.Integer{"67108863"},Sql.Cell.Integer{"1"},Sql.Cell.Blob{[255]}]],
      "stage_one admits exact final ordinal and final compressed byte; seal still owns contiguity")
    Meta.exec(db,"ROLLBACK",[])
    Test.check(db,"SELECT count(*) FROM archive_chunks",[[Sql.Cell.Integer{"0"}]],
      "boundary admission leaves no chunk after rollback")
    IO.try(Unit,Sql.close(db))

def absent(value: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match value:
    case Fail{(code,_)}: Test.assert(U32.is_eq(code,2),"WAL fixture starts at an absent nonce-owned path")
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL WAL fixture path already exists")

def prepare_file(+path: String) -> IO(U32):
  do IO<U32>:
    missing : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent(missing)
    +db : U32 <- IO.try(U32,Sql.open(path))
    Test.check(db,"PRAGMA journal_mode=WAL",[[Sql.Cell.Text{"wal"}]],"metadata fixture explicitly enables WAL mode")
    Test.check(db,"PRAGMA journal_mode",[[Sql.Cell.Text{"wal"}]],"metadata reader fixture uses actual WAL mode")
    Test.schema2(db)
    Meta.migrate(db)
    Test.archive_rows(db)
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    Meta.stage_one(db,"3",Profile.streaming(),0,0,[0,255])
    Meta.stage_one(db,"3",Profile.streaming(),1,2,[97,98,99])
    Test.finalized(db)
    Meta.seal_for(db,"3",Profile.streaming(),5,Fixture.compressed_sha(),Fixture.logical_sha())
    Meta.exec(db,"UPDATE snapshots SET accepted=1 WHERE id=3",[])
    Meta.exec(db,"UPDATE sources SET latest=3 WHERE id=1",[])
    Meta.exec(db,"COMMIT",[])
    return db

def first_chunk(read: Meta.Read) -> IO(Meta.Reader):
  Meta.Read{reader,bytes} = read
  match bytes:
    case Some{raw}:
      do IO<Meta.Reader>:
        Test.assert(Domain.bytes_equal(raw,[0,255]),"reader consumes exact first old chunk before writer publication")
        return reader
    case None{}: IO.die(Meta.Reader,1,"FAIL old reader has no first chunk")

def first_reader(db: U32,opened: Meta.Open) -> IO(Meta.Reader):
  Meta.Open{_,reader} = opened
  do IO<Meta.Reader>:
    read : Meta.Read <- Meta.next(db,reader)
    first_chunk(read)

def publish_next(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Meta.exec(db,"BEGIN IMMEDIATE",[])
    Meta.exec(db,"INSERT INTO snapshots VALUES(4,2,2,2,1,1,0)",[])
    Meta.stage_one(db,"4",Profile.streaming(),0,0,[7,8,9])
    Meta.seal_for(db,"4",Profile.streaming(),3,Domain.digest([7,8,9]),Fixture.logical_sha())
    Meta.exec(db,"UPDATE snapshots SET accepted=1 WHERE id=4",[])
    Meta.exec(db,"UPDATE sources SET latest=4 WHERE id=1",[])
    Meta.exec(db,"COMMIT",[])
    Test.check(db,"SELECT latest FROM sources WHERE id=1",[[Sql.Cell.Integer{"4"}]],
      "writer commits new latest while independent WAL reader remains open")

def end_reader(read: Meta.Read) -> IO(Unit):
  Meta.Read{_,bytes} = read
  match bytes:
    case None{}: IO.print("PASS paused reader validates exact old container end and SHA after newer publication")
    case Some{_}: IO.die(Unit,1,"FAIL old reader produced an extra chunk")

def second_chunk(+db: U32,read: Meta.Read) -> IO(Unit):
  Meta.Read{reader,bytes} = read
  match bytes:
    case Some{raw}:
      do IO<Unit>:
        Test.assert(Domain.bytes_equal(raw,[97,98,99]),"paused reader consumes exact second old chunk after writer publication")
        final : Meta.Read <- Meta.next(db,reader)
        end_reader(final)
    case None{}: IO.die(Unit,1,"FAIL old reader lost its remaining chunk")

def new_chunk(+db: U32,read: Meta.Read) -> IO(Unit):
  Meta.Read{reader,bytes} = read
  match bytes:
    case Some{raw}:
      do IO<Unit>:
        Test.assert(Domain.bytes_equal(raw,[7,8,9]),"fresh reader sees exact independently committed container")
        Meta.validate_reader(db,reader)
    case None{}: IO.die(Unit,1,"FAIL new reader lost its committed chunk")

def read_new(+db: U32,opened: Meta.Open) -> IO(Unit):
  Meta.Open{_,reader} = opened
  do IO<Unit>:
    read : Meta.Read <- Meta.next(db,reader)
    new_chunk(db,read)

def interleaved(+reader_db: U32,+writer_db: U32,reader: Meta.Reader) -> IO(Unit):
  do IO<Unit>:
    publish_next(writer_db)
    Test.check(reader_db,"SELECT latest FROM sources WHERE id=1",[[Sql.Cell.Integer{"3"}]],
      "open WAL reader keeps its original latest identity after writer commits")
    Test.check(reader_db,"SELECT count(*) FROM snapshots WHERE id=4",[[Sql.Cell.Integer{"0"}]],
      "open WAL reader cannot mix newer snapshot rows into its prior read transaction")
    second : Meta.Read <- Meta.next(reader_db,reader)
    second_chunk(reader_db,second)
    Meta.exec(reader_db,"COMMIT",[])
    Test.check(reader_db,"SELECT latest FROM sources WHERE id=1",[[Sql.Cell.Integer{"4"}]],
      "ending the old read transaction exposes the newer latest normally")
    opened : Meta.Open <- Meta.open_reader(reader_db,"4",True{})
    read_new(reader_db,opened)
    again : Meta.Open <- Meta.open_reader(reader_db,"3",True{})
    Fixture.drained(reader_db,again)
    IO.print("PASS selected historical metadata and bytes remain valid after newer latest")
    IO.try(Unit,Sql.close(writer_db))
    IO.try(Unit,Sql.close(reader_db))

def wal(+path: String) -> IO(Unit):
  do IO<Unit>:
    +reader_db : U32 <- prepare_file(path)
    +writer_db : U32 <- IO.try(U32,Sql.open(path))
    Meta.exec(reader_db,"BEGIN",[])
    opened : Meta.Open <- Meta.open_reader(reader_db,"3",True{})
    reader : Meta.Reader <- first_reader(reader_db,opened)
    interleaved(reader_db,writer_db,reader)

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    valid_edges()
    cases(["ordinal","offset-above","offset-at-end","crossing-end","empty","large-chunk","non-octet"],self)
    nonce : U32 <- IO.try(U32,IO.random_u32())
    other : U32 <- IO.try(U32,IO.random_u32())
    wal(".build/archive-stream-wal-" ++ U32.show(nonce) ++ "-" ++ U32.show(other) ++ ".sqlite")
    IO.print("Archive stream metadata boundary and WAL interleaving suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case [_,"child",kind]: child(kind)
    case _: IO.die(Unit,2,"Archive stream boundary suite expects no args or an owned child mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
