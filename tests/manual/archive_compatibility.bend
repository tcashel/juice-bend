import Base
import ../../src/store.bend as Store
import ../../src/capture.bend as Capture
import ../../src/sql.bend as Sql
import ../archive_publication.bend as Publication
import ../archive_maintenance.bend as Fixture

# Supply the actual pre-schema3 native executable as argv[1]. The gate runner
# records its exact input SHA before and after this test. No legacy algorithm
# is copied into this test, and the old process only sees this synthetic root.
def refused(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Done{(1,(_,error))}:
      Publication.assert(String.contains(error,"Unsupported Juice Bend library schema version"),
        "actual schema2 native writer refuses schema3 before archive dispatch")
    case _:
      IO.die(Unit,1,"FAIL old native writer did not reject schema3 at its version fence")

def suite(previous: String) -> IO(Unit):
  do IO<Unit>:
    nonce : U32 <- IO.try(U32,IO.random_u32())
    +directory : String = ".build/archive-compatibility-" ++ U32.show(nonce)
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-m","700",directory],"",4096,2000))
    Fixture.process_ok(made,"create private old-writer compatibility root")
    +db : U32 <- Store.open(directory ++ "/juice-bend.sqlite")
    +source : String = directory ++ "/source.jsonl.zst"
    Publication.write_archive(source,Publication.fixture("oldcapture"))
    +snapshot : String <- Capture.import_file(db,"codex",source)
    baseline : Publication.Baseline <- Publication.capture_baseline(db,snapshot)
    Publication.remember_tables(Publication.tables(),db)
    IO.try(Unit,Sql.close(db))
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(previous,["--data-dir",directory,"import","codex",source],"",8192,30000)
    refused(result)
    +reopened : U32 <- Store.open(directory ++ "/juice-bend.sqlite")
    Publication.unchanged_tables(Publication.tables(),reopened,"old writer fence")
    Publication.equal_scalar(reopened,"PRAGMA user_version",[],"3","old writer leaves schema fence unchanged")
    Publication.pinned(reopened,baseline,"old writer fence")
    Publication.check_integrity(reopened,"old writer fence")
    IO.try(Unit,Sql.close(reopened))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [_,previous]: suite(previous)
    case _: IO.die(Unit,2,"Archive compatibility test requires the pinned pre-schema3 native executable")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
