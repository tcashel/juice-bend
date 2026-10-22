import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/domain.bend as Domain
import ../src/archive_meta.bend as Meta
import ../src/archive_maintenance.bend as Archive
import ../src/maintenance.bend as Maintenance
import ./archive_maintenance.bend as Fixture
import ./archive_publication.bend as Publication
import ./archive_capture.bend as Lifecycle
import ./publication_crash.bend as Check
import ./zstd/frame_vectors.bend as Vectors

# Run only against the separately hash-verified preserved pre-stream native app.
# This harness never opens a default data directory: every old-app command has
# an explicit nonce-owned synthetic directory and the current process owns it.
# The launcher records the actual old binary hash before and after execution.
def tables() -> List<&2,String>:
  List.append(&2,String,Publication.tables(),["settings"])

def old_result(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = result
  Check.assert(U32.is_eq(code,1) && String.contains(out ++ err,
    "Archive origin, required format, limits or commitment are corrupt"),
    "preserved old app explicitly refuses stream profile for " ++ label)

def unchanged(+db: U32,+snapshot: String,label: String) -> IO(Unit):
  do IO<Unit>:
    Check.unchanged_tables(tables(),db,label)
    Check.equal_scalar(db,"PRAGMA user_version",[],"3","old app cannot downgrade schema3")
    Check.equal_scalar(db,"SELECT latest FROM sources",[],snapshot,"old app preserves latest accepted snapshot identity")
    Check.equal_scalar(db,"SELECT profile FROM archive_captures WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}],"archive-stream-v2","old app preserves unknown profile byte commitment")

def refused(+old: String,+directory: String,+snapshot: String,args: List<String>,+label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(old,List.append(&1,String,["--data-dir",directory],args),"",65536,15000))
    old_result(result,label)
    +db : U32 <- Store.open(directory ++ "/juice-bend.sqlite")
    unchanged(db,snapshot,"old app refused " ++ label)
    IO.try(Unit,Sql.close(db))

def no_output(path: String,label: String) -> IO(Unit):
  do IO<Unit>:
    file : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    Fixture.absent(file,label)

def commands(+old: String,+directory: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    refused(old,directory,snapshot,["history"],"history metadata enumeration")
    refused(old,directory,snapshot,["verify",snapshot],"complete verification")
    refused(old,directory,snapshot,["session",snapshot,"0","1"],"selected record reading")
    refused(old,directory,snapshot,["export-all",snapshot,directory ++ "/old-logical.jsonl"],"logical export")
    refused(old,directory,snapshot,["export-container",snapshot,directory ++ "/old-container.zst"],"container export")
    refused(old,directory,snapshot,["rebuild",snapshot],"projection rebuild")
    refused(old,directory,snapshot,["import","claude",directory ++ "/source.jsonl.zst"],"archive recapture")
    no_output(directory ++ "/old-logical.jsonl","old app creates no refused logical export")
    no_output(directory ++ "/old-container.zst","old app creates no refused compressed export")

def retained(+directory: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--",directory ++ "/source.jsonl.zst"],"",4096,2000))
    Fixture.process_ok(removed,"remove only compatibility fixture compressed source")
    +db : U32 <- Store.open(directory ++ "/juice-bend.sqlite")
    unchanged(db,snapshot,"all preserved-old-app probes")
    Archive.verify(db,snapshot)
    Maintenance.export_raw(db,snapshot,directory ++ "/new-logical.jsonl")
    Archive.export_container(db,snapshot,directory ++ "/new-container.zst")
    container : List<&2,U32> <- Fixture.read_bytes(directory ++ "/new-container.zst")
    Check.assert(Domain.bytes_equal(container,Vectors.jsonl_check()),
      "new writer exports the exact retained container after old-app refusals and source removal")
    logical : List<&2,U32> <- Fixture.read_bytes(directory ++ "/new-logical.jsonl")
    Check.assert(Domain.bytes_equal(logical,Domain.encode(Lifecycle.records(100n,0))),
      "new writer exports independently expected logical bytes after old-app refusals and source removal")
    IO.try(Unit,Sql.close(db))

def prepared(+old: String,+directory: String) -> IO(Unit):
  do IO<Unit>:
    Fixture.write_bytes(directory ++ "/source.jsonl.zst",Vectors.jsonl_check())
    +db : U32 <- Store.open(directory ++ "/juice-bend.sqlite")
    +snapshot : String <- Capture.import_file(db,"claude",directory ++ "/source.jsonl.zst")
    Check.equal_scalar(db,"SELECT profile FROM archive_captures WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}],"archive-stream-v2","new writer creates explicit stream profile even for small fixture")
    Check.remember_tables(tables(),db)
    IO.try(Unit,Sql.close(db))
    commands(old,directory,snapshot)
    retained(directory,snapshot)

def suite(old: String) -> IO(Unit):
  do IO<Unit>:
    nonce : U32 <- IO.try(U32,IO.random_u32())
    other : U32 <- IO.try(U32,IO.random_u32())
    +directory : String = ".build/archive-stream-compat-" ++ U32.show(nonce) ++ "-" ++ U32.show(other)
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-m","700",directory],"",4096,2000))
    Fixture.process_ok(made,"create fresh private old-app compatibility fixture directory")
    prepared(old,directory)
    IO.print("Archive stream preserved-old-app compatibility suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case [_,old]: suite(old)
    case _: IO.die(Unit,2,"Pass the hash-verified preserved pre-stream executable; use an isolated synthetic cwd")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
