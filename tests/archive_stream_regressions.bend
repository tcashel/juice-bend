import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/archive_meta.bend as Meta
import ../src/archive_profile.bend as Profile
import ../src/archive_maintenance.bend as Archive
import ../src/maintenance.bend as Maintenance
import ./archive_maintenance.bend as Fixture
import ./archive_meta.bend as MetadataTest
import ./zstd/frame_vectors.bend as Vectors

# This accepted legacy fixture owns one exact raw record and a checksummed
# ordinary frame split into 16 legal batch chunks: 9-byte header, fourteen
# one-byte payload chunks, 4-byte checksum. A body request crosses 14 chunks.
# No original source is created or read; every path belongs to this test run.
def logical() -> List<&2,U32>:
  Domain.encode("hello archive\n")

def singletons(bytes: List<&2,U32>) -> List<&2,List<&2,U32>>:
  match bytes:
    case []: []
    case byte <> rest: [byte] <> singletons(rest)

def fragmented() -> List<&2,List<&2,U32>>:
  +bytes = Vectors.hello_check()
  List.take(&2,U32,bytes,9n) <>
    List.append(&2,List<&2,U32>,singletons(List.take(&2,U32,List.drop(&2,U32,bytes,9n),14n)),
      [List.drop(&2,U32,bytes,23n)])

def prepared(path: String,source: String) -> IO(U32):
  do IO<U32>:
    +db : U32 <- Store.open(path)
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO sources(id,provider,locator) VALUES(1,'claude',?)",[Sql.Cell.Text{source}])
    Store.exec(db,"INSERT INTO generations(id,source,encoding) VALUES(2,1,?)",[Sql.Cell.Text{Meta.encoding()}])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent,checkpoint,checkpoint_ordinal,records,accepted) VALUES(3,2,14,14,1,1,0)",[])
    Store.exec(db,"INSERT INTO raw(id,generation,ordinal,offset,n,digest,bytes,complete,oversized) VALUES(4,2,0,0,14,?,?,1,0)",
      [Sql.Cell.Text{Store.raw_digest("2",0,0,14,logical())},Sql.Cell.Blob{logical()}])
    Store.exec(db,"INSERT INTO records(snapshot,ordinal,raw) VALUES(3,0,4)",[])
    Meta.stage(db,"3",fragmented())
    Meta.seal(db,"3",27,Domain.digest(Vectors.hello_check()),Domain.digest(logical()))
    Store.exec(db,"UPDATE snapshots SET accepted=1 WHERE id=3",[])
    Store.exec(db,"UPDATE sources SET latest=3 WHERE id=1",[])
    Store.exec(db,"COMMIT",[])
    return db

def selected_exact(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +row : List<&2,Sql.Cell> <- Store.selected_record(db,"3","2",14,1,0)
    Fixture.assert(String.eq(Store.field(row,0n),"2") && String.eq(Store.field(row,1n),"0") &&
      String.eq(Store.field(row,2n),"0") && String.eq(Store.field(row,3n),"14") &&
      Domain.bytes_equal(Store.blob(Store.cell(row,5n)),logical()),
      "fragmented legacy archive preserves its selected historical logical record")
    MetadataTest.check(db,"SELECT s.id,g.id,p.id,i.raw FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id JOIN records i ON i.snapshot=p.id",
      [[Sql.Cell.Integer{"1"},Sql.Cell.Integer{"2"},Sql.Cell.Integer{"3"},Sql.Cell.Integer{"4"}]],
      "fragmented verification and exports preserve source generation snapshot and raw identities")

def fragmented_case(+directory: String) -> IO(Unit):
  do IO<Unit>:
    Fixture.assert(Nat.is_eq(List.length(&2,List<&2,U32>,fragmented()),16n) &&
      Nat.is_eq(List.length(&2,U32,Vectors.hello_check()),27n) &&
      Domain.bytes_equal(List.concat(&2,U32,fragmented()),Vectors.hello_check()),
      "legacy regression fixture is exactly sixteen legal chunks of the frozen checksummed frame")
    +db : U32 <- prepared(directory ++ "/legacy.sqlite",directory ++ "/absent-source.jsonl.zst")
    MetadataTest.check(db,"SELECT profile,chunks,compressed_extent FROM archive_captures WHERE snapshot=3",
      [[Sql.Cell.Text{"archive-batch-v1"},Sql.Cell.Integer{"16"},Sql.Cell.Integer{"27"}]],
      "fragmented fixture uses accepted legacy batch limits and commitment")
    Store.exec(db,"BEGIN",[])
    Archive.verify_owned(db,"3",True{})
    Store.exec(db,"COMMIT",[])
    IO.print("PASS bounded decoder verifies a fourteen-chunk block body in an accepted batch archive")
    Archive.export_container(db,"3",directory ++ "/valid/retained.zst")
    Maintenance.export_raw(db,"3",directory ++ "/valid/retained.raw")
    physical : List<&2,U32> <- Fixture.read_bytes(directory ++ "/valid/retained.zst")
    Fixture.assert(Domain.bytes_equal(physical,Vectors.hello_check()),"fragmented legacy container export is byte-exact without a source")
    raw : List<&2,U32> <- Fixture.read_bytes(directory ++ "/valid/retained.raw")
    Fixture.assert(Domain.bytes_equal(raw,logical()),"fragmented legacy logical export is byte-exact without a source")
    selected_exact(db)
    IO.try(Unit,Sql.close(db))

def corrupt(+db: U32,mode: String) -> IO(Unit):
  match mode:
    case "late-chunk":
      Store.exec(db,"UPDATE archive_chunks SET digest=? WHERE snapshot=3 AND ordinal=15",
        [Sql.Cell.Text{String.repeat("0",64n)}])
    case "whole-sha":
      do IO<Unit>:
        +h : Meta.Header <- Meta.header(db,"3",True{})
        +wrong : String = String.repeat("0",64n)
        +m : Meta.Metadata = Meta.Metadata{27,16,wrong,Domain.digest(logical())}
        Store.exec(db,"UPDATE archive_captures SET compressed_sha=?,commitment=? WHERE snapshot=3",
          [Sql.Cell.Text{wrong},Sql.Cell.Text{Meta.origin_digest_for(Profile.batch(),h,m)}])
    case _: IO.die(Unit,2,"Unknown archive stream regression corruption")

def expected_error(mode: String) -> String:
  match mode:
    case "late-chunk": "Archive chunk types, bytes or digest are corrupt"
    case "whole-sha": "Archive whole-container extent or SHA256 does not match its origin"
    case _: "UNKNOWN"

def refused(result: U32 & (String & String),+mode: String) -> IO(Unit):
  (code,(out,err)) = result
  Fixture.assert(U32.is_eq(code,1) && String.contains(out ++ err,expected_error(mode)),
    "container export refuses " ++ mode ++ " at its exact integrity boundary")

def empty_listing(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = result
  Fixture.assert(U32.is_eq(code,0) && String.is_empty(out) && String.is_empty(err),label)

def no_artifacts(directory: String,mode: String) -> IO(Unit):
  do IO<Unit>:
    listing : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/ls",["-A",directory],"",8192,2000))
    empty_listing(listing,"refused " ++ mode ++ " export leaves no destination or private temporary artifact")

def failure_case(+self: String,+directory: String,+mode: String) -> IO(Unit):
  +path = directory ++ "/" ++ mode ++ ".sqlite"
  +output = directory ++ "/" ++ mode ++ "/refused.zst"
  do IO<Unit>:
    +db : U32 <- prepared(path,directory ++ "/absent-" ++ mode ++ ".jsonl.zst")
    corrupt(db,mode)
    accepted : Maybe<&2,Meta.Origin> <- Meta.read(db,"3",True{})
    IO.print("PASS corrupt " ++ mode ++ " fixture retains a valid typed origin before bounded chunk validation")
    IO.try(Unit,Sql.close(db))
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["export",path,output],"",8192,10000))
    refused(result,mode)
    absent : Result<&1,&1,U32 & String,File> <- File.open(output,"r")
    Fixture.absent(absent,"refused " ++ mode ++ " export creates no final destination")
    no_artifacts(directory ++ "/" ++ mode,mode)

def child(path: String,output: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    Archive.export_container(db,"3",output)
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"CORRUPT-CONTAINER-WAS-EXPORTED")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    first : U32 <- IO.try(U32,IO.random_u32())
    second : U32 <- IO.try(U32,IO.random_u32())
    +directory : String = ".build/archive-stream-regressions-" ++ U32.show(first) ++ "-" ++ U32.show(second)
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-m","700",directory,directory ++ "/valid",directory ++ "/late-chunk",directory ++ "/whole-sha"],"",4096,2000))
    Fixture.process_ok(made,"create unique private streaming regression directories")
    fragmented_case(directory)
    failure_case(self,directory,"late-chunk")
    failure_case(self,directory,"whole-sha")
    IO.print("Archive streaming regression suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case [_,"export",path,output]: child(path,output)
    case _: IO.die(Unit,2,"Archive streaming regression test expects no arguments or owned export child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
