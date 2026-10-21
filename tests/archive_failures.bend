import Base
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/maintenance.bend as Maintenance
import ../src/archive_maintenance.bend as Retained
import ./archive_maintenance.bend as Fixture
import ./archive_publication.bend as Publication
import ./zstd/frame_vectors.bend as Vectors

# Run in the runner's private synthetic cwd. Each case gets a nonce-owned
# subdirectory path, database and source. Only this executable is launched as a
# child. A normal importer error must exit: a timeout or successful import fails
# the test. Mutation observers change only that child's synthetic source/DB.

def flip_last(bytes: List<&2,U32>) -> List<&2,U32>:
  match bytes:
    case []: []
    case byte <> []: [U32.xor(byte,1)]
    case byte <> tail: byte <> flip_last(tail)

def without_last(bytes: List<&2,U32>) -> List<&2,U32>:
  match bytes:
    case []: []
    case _ <> []: []
    case byte <> tail: byte <> without_last(tail)

# Unknown content size,8MiB window. Thirty-two nonfinal RLE blocks each produce
# 131072 bytes; the final one-byte block attempts byte4194305. No large source
# fixture or declared-size shortcut is involved in this output-limit test.
def rle_blocks(fuel: Nat,tail: List<&2,U32>) -> List<&2,U32>:
  match fuel:
    case 0n: tail
    case 1n+rest:
      2 <> 0 <> 16 <> 65 <> rle_blocks(rest,tail)

def expansion() -> List<&2,U32>:
  List.append(&2,U32,[40,181,47,253,0,88],rle_blocks(32n,[11,0,0,65]))

def bytes_for(mode: String) -> List<&2,U32>:
  match mode:
    case "checksum": flip_last(Vectors.jsonl_check())
    case "truncated": without_last(Vectors.jsonl_check())
    case "trailing": List.append(&2,U32,Vectors.jsonl_check(),[0,0,0,0])
    # Window descriptor112 requests16MiB; the archive profile permits8MiB.
    case "window": [40,181,47,253,0,112,1,0,0]
    # Descriptor1 selects a one-byte nonzero dictionary ID after the window.
    case "dictionary": [40,181,47,253,1,56,1,1,0,0]
    # Single segment,4-byte FCS4194305, followed by an empty final raw block.
    case "logical_declared": [40,181,47,253,160,1,0,64,0,1,0,0]
    case "logical_expansion": expansion()
    case _: []

def repeat_writes(fuel: Nat,file: File,+chunk: List<&2,U32>) -> IO(File):
  match fuel:
    case 0n: IO.pure(File,file)
    case 1n+rest:
      do IO<File>:
        result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,chunk)
        next : File <- Maintenance.write_result(result)
        repeat_writes(rest,next,chunk)

def oversized_file(path: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    filled : File <- repeat_writes(16n,file,List.replicate(U32,65536n,0))
    extra : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(filled,[0])
    Store.write_closed(extra)

def observed(mode: String) -> Bool:
  match mode:
    case "source_changed": True{}
    case "container_metadata": True{}
    case "logical_metadata": True{}
    case "origin_metadata": True{}
    case _: False{}

def observed_phase(mode: String) -> String:
  match mode:
    case "source_changed": "staged"
    case _: "before_commit"

def expected_error(mode: String) -> String:
  match mode:
    case "checksum": "archive_corrupt: Zstandard content checksum mismatch"
    case "truncated": "archive_corrupt: truncated byte field"
    case "trailing": "archive_corrupt: unrecognized Zstandard frame magic"
    case "window": "archive_limit: Zstandard window exceeds"
    case "dictionary": "archive_dictionary: dictionary-required Zstandard frame is unsupported"
    case "logical_declared": "archive_limit: single-segment frame exceeds output or window limit"
    case "logical_expansion": "archive_limit: decoded byte exceeds output/window bound"
    case "physical": "archive_limit: compressed source exceeds 1 MiB"
    case "source_changed": "archive_changed: compressed bytes changed during capture"
    case "container_metadata": "Archive chunk types, bytes or digest are corrupt"
    case "logical_metadata": "integrity"
    case "origin_metadata": "Archive origin, required format, limits or commitment are corrupt"
    case "plain_guard": "Compressed source requires the archive capture dispatcher"
    case _: "INVALID FAILURE CASE"

def prepare_source(+mode: String,path: String) -> IO(Unit):
  match mode:
    case "physical": oversized_file(path)
    case "source_changed": Publication.write_archive(path,Publication.fixture("newcapture"))
    case "container_metadata": Publication.write_archive(path,Publication.fixture("newcapture"))
    case "logical_metadata": Publication.write_archive(path,Publication.fixture("newcapture"))
    case "origin_metadata": Publication.write_archive(path,Publication.fixture("newcapture"))
    case "plain_guard": Publication.write_archive(path,Publication.fixture("newcapture"))
    case _: Fixture.write_bytes(path,bytes_for(mode))

def damage_snapshot(+db: U32,mode: String) -> IO(Unit):
  match mode:
    case "container_metadata":
      do IO<Unit>:
        snapshot : String <- Publication.scalar(db,"SELECT latest FROM sources",[])
        Store.exec(db,"UPDATE archive_chunks SET offset=offset+1 WHERE snapshot=? AND ordinal=0",[Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changed exactly one owned container offset")
    case "logical_metadata":
      do IO<Unit>:
        snapshot : String <- Publication.scalar(db,"SELECT latest FROM sources",[])
        Store.exec(db,"UPDATE raw SET offset=offset+1 WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changed exactly one owned logical offset")
    case "origin_metadata":
      do IO<Unit>:
        snapshot : String <- Publication.scalar(db,"SELECT latest FROM sources",[])
        Store.exec(db,"UPDATE archive_captures SET logical_sha=? WHERE snapshot=?",[Sql.Cell.Text{String.repeat("0",64n)},Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changed exactly one owned logical commitment")
    case _: IO.die(Unit,91,"Unexpected mutation mode")

def mutation(+db: U32,mode: String,prefix: String) -> IO(Unit):
  match mode:
    case "source_changed":
      # Same byte length as newcapture: must fail byte revalidation, not size.
      Publication.write_archive(prefix ++ ".jsonl.zst",Publication.fixture("badcapture"))
    case other:
      damage_snapshot(db,other)

def mutate_selected(db: U32,+mode: String,+prefix: String,phase: String,selected: Bool) -> IO(Unit):
  match selected:
    case False{}: IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        mutation(db,mode,prefix)
        Store.write_text(prefix ++ ".marker","w",prefix ++ "|" ++ mode ++ "|" ++ phase)

def observer(fuel: Nat,+db: U32,+mode: String,+prefix: String) -> Store.ImportObserver:
  match fuel:
    case 0n: Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        +name : String = Store.phase_name(phase)
        mutate_selected(db,mode,prefix,name,String.eq(name,observed_phase(mode)))
        return observer(rest,db,mode,prefix)}

def capture_child(+db: U32,mode: String,+prefix: String,observing: Bool) -> IO(String):
  match observing:
    case False{}: Capture.import_file(db,"codex",prefix ++ ".jsonl.zst")
    case True{}: Capture.import_observed(db,"codex",prefix ++ ".jsonl.zst",observer(11n,db,mode,prefix))

def import_child(db: U32,mode: String,prefix: String) -> IO(String):
  match mode:
    case "plain_guard": Store.import_file(db,"codex",prefix ++ ".jsonl.zst")
    case +other: capture_child(db,other,prefix,observed(other))

def child(+mode: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- import_child(db,mode,prefix)
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,92,"UNEXPECTED accepted snapshot " ++ snapshot)

def failed(result: Result<&1,&1,U32 & String,U32 & (String & String)>,needle: String,+label: String) -> IO(Unit):
  match result:
    case Fail{(code,message)}:
      IO.die(Unit,1,"FAIL " ++ label ++ " child failed to complete normally: " ++ U32.show(code) ++ " " ++ message)
    case Done{(+code,(_,error))}:
      Publication.assert((U32.is_eq(code,1) || U32.is_eq(code,2)) && String.contains(error,needle),
        label ++ " actual importer rejects input with the expected error")

def check_marker(+mode: String,+prefix: String,required: Bool) -> IO(Unit):
  match required:
    case False{}: IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        actual : String <- Publication.file_text(prefix ++ ".marker")
        Publication.assert(String.eq(actual,prefix ++ "|" ++ mode ++ "|" ++ observed_phase(mode)),
          mode ++ " exact owned mutation boundary was reached")

def run_case(+self: String,+directory: String,+mode: String) -> IO(Unit):
  +prefix = directory ++ "/" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    +baseline : Publication.Baseline <- Publication.prepare_baseline("rewrite",db,prefix ++ ".jsonl.zst")
    Publication.remember_tables(Publication.tables(),db)
    prepare_source(mode,prefix ++ ".jsonl.zst")
    Store.write_text(prefix ++ ".marker","w","")
    IO.try(Unit,Sql.close(db))
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["child",mode,prefix],"",8192,30000)
    failed(result,expected_error(mode),mode)
    check_marker(mode,prefix,observed(mode))
    +reopened : U32 <- Store.open(prefix ++ ".sqlite")
    Publication.unchanged_tables(Publication.tables(),reopened,mode)
    Publication.previous_visible("rewrite",reopened,baseline,mode)
    Publication.search_absent(reopened,"newcapture",mode ++ " failed capture is never searchable")
    Publication.pinned(reopened,baseline,mode)
    Publication.check_integrity(reopened,mode)
    # A valid retry exercises release of the failed worker's transaction/lock.
    Publication.write_archive(prefix ++ ".jsonl.zst",Publication.fixture("newcapture"))
    +recovered : String <- Capture.import_file(reopened,"codex",prefix ++ ".jsonl.zst")
    Publication.published(reopened,"rewrite",recovered,mode ++ " retry")
    again : String <- Capture.import_file(reopened,"codex",prefix ++ ".jsonl.zst")
    Publication.assert(String.eq(recovered,again),mode ++ " recovered retry is idempotent")
    IO.try(Unit,Sql.close(reopened))

def cases() -> List<&2,String>:
  ["checksum","truncated","trailing","window","dictionary","logical_declared",
    "logical_expansion","physical","source_changed","container_metadata","logical_metadata",
    "origin_metadata","plain_guard"]

def run_cases(modes: List<&2,String>,+self: String,+directory: String) -> IO(Unit):
  match modes:
    case []: IO.pure(Unit,Unit{})
    case mode <> rest:
      do IO<Unit>:
        run_case(self,directory,mode)
        run_cases(rest,self,directory)

# Every final-gate case has an independently accepted control source. This
# makes a foreign accepted latest pointer available even for an initial import
# and checks that rejection preserves unrelated captured evidence as well.
def final_faults() -> List<&2,String>:
  ["latest_null","latest_other","event_body","projection_seal","fts_delete",
    "fts_body","fts_extra","fts_snapshot_type","fts_ordinal_type","fts_event_type"]

def final_error(fault: String) -> String:
  match fault:
    case "latest_null": "archive_corrupt: final source/latest/snapshot binding"
    case "latest_other": "archive_corrupt: final source/latest/snapshot binding"
    case "event_body": "archive_corrupt: final event projection seal changed"
    case "projection_seal": "archive_corrupt: final event projection seal changed"
    case _: "archive_corrupt: final lexical search projection changed"

def typed_fts_damage(+db: U32,+snapshot: String,+column: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"UPDATE search SET " ++ column ++ "=CAST(" ++ column ++
      " AS TEXT) WHERE rowid=(SELECT rowid FROM events WHERE snapshot=? AND ordinal=2 AND event=0)",
      [Sql.Cell.Integer{snapshot}])
    Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changes one owned FTS key type")
    Publication.equal_scalar(db,"SELECT typeof(" ++ column ++
      ") FROM search WHERE rowid=(SELECT rowid FROM events WHERE snapshot=? AND ordinal=2 AND event=0)",
      [Sql.Cell.Integer{snapshot}],"text","observer proves the FTS key now has TEXT storage class")

def final_damage(+db: U32,fault: String,+snapshot: String) -> IO(Unit):
  match fault:
    case "latest_null":
      do IO<Unit>:
        Store.exec(db,"UPDATE sources SET latest=NULL WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
          [Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer clears exactly the owned latest pointer")
    case "latest_other":
      # Append selects its previous accepted snapshot; initial and unchanged
      # select the control source. Both stale and foreign bindings are covered.
      do IO<Unit>:
        +other : String <- Publication.scalar(db,"SELECT max(id) FROM snapshots WHERE accepted=1 AND id<>?",[Sql.Cell.Integer{snapshot}])
        Publication.assert(Bool.not(String.is_empty(other)) && Bool.not(String.eq(other,snapshot)),"observer has a different accepted snapshot")
        Store.exec(db,"UPDATE sources SET latest=? WHERE id=(SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?)",
          [Sql.Cell.Integer{other},Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer substitutes exactly the owned latest pointer")
    case "event_body":
      do IO<Unit>:
        Store.exec(db,"UPDATE events SET body='forged event body' WHERE snapshot=? AND ordinal=2 AND event=0",[Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changes one sealed event body")
    case "projection_seal":
      do IO<Unit>:
        Store.exec(db,"UPDATE projection_checks SET digest=? WHERE snapshot=?",
          [Sql.Cell.Text{String.repeat("0",64n)},Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changes one final projection seal")
    case "fts_delete":
      do IO<Unit>:
        Store.exec(db,"DELETE FROM search WHERE rowid=(SELECT rowid FROM events WHERE snapshot=? AND ordinal=2 AND event=0)",[Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer removes one owned FTS row")
    case "fts_body":
      do IO<Unit>:
        Store.exec(db,"UPDATE search SET body='forged FTS body' WHERE rowid=(SELECT rowid FROM events WHERE snapshot=? AND ordinal=2 AND event=0)",[Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer changes one owned FTS body")
    case "fts_extra":
      do IO<Unit>:
        Store.exec(db,"INSERT INTO search(body,arguments,result,tool,snapshot,ordinal,event) SELECT body,arguments,result,tool,snapshot,ordinal,event FROM events WHERE snapshot=? AND ordinal=2 AND event=0",[Sql.Cell.Integer{snapshot}])
        Publication.equal_scalar(db,"SELECT changes()",[],"1","observer adds one duplicate FTS payload with a different row identity")
    case "fts_snapshot_type": typed_fts_damage(db,snapshot,"snapshot")
    case "fts_ordinal_type": typed_fts_damage(db,snapshot,"ordinal")
    case "fts_event_type": typed_fts_damage(db,snapshot,"event")
    case _: IO.die(Unit,91,"Unexpected final-gate mutation")

def final_mutate_selected(+db: U32,+state: String,+fault: String,+prefix: String,selected: Bool) -> IO(Unit):
  match selected:
    case False{}: IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        # Control is imported first; the target is the newest accepted ID in
        # initial, append and unchanged cases before any pointer is damaged.
        +snapshot : String <- Publication.scalar(db,"SELECT max(id) FROM snapshots WHERE accepted=1",[])
        Publication.assert(Bool.not(String.is_empty(snapshot)),"final observer targets an accepted owned snapshot")
        final_damage(db,fault,snapshot)
        Store.write_text(prefix ++ ".marker","w",prefix ++ "|" ++ state ++ "|" ++ fault ++ "|before_commit")

def final_observer(fuel: Nat,+db: U32,+state: String,+fault: String,+prefix: String) -> Store.ImportObserver:
  match fuel:
    case 0n: Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        final_mutate_selected(db,state,fault,prefix,String.eq(Store.phase_name(phase),"before_commit"))
        return final_observer(rest,db,state,fault,prefix)}

def final_child(+state: String,+fault: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- Capture.import_observed(db,"codex",prefix ++ ".jsonl.zst",
      final_observer(11n,db,state,fault,prefix))
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,92,"UNEXPECTED final-gate accepted snapshot " ++ snapshot)

def final_source(state: String,path: String) -> IO(Unit):
  match state:
    case "unchanged": IO.pure(Unit,Unit{})
    case mode: Publication.write_changed(path,mode)

def baseline_latest(+db: U32,baseline: Publication.Baseline,+label: String) -> IO(Unit):
  Publication.Baseline{+snapshot,_,_,_} = baseline
  match snapshot:
    case "":
      Publication.equal_scalar(db,"SELECT count(*) FROM sources",[],"1",label ++ " initial target stays unpublished")
    case _:
      Publication.equal_scalar(db,"SELECT s.latest FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE p.id=?",
        [Sql.Cell.Integer{snapshot}],snapshot,label ++ " original latest remains published")

def baseline_search(db: U32,baseline: Publication.Baseline,word: String,label: String) -> IO(Unit):
  Publication.Baseline{+snapshot,_,_,_} = baseline
  match snapshot:
    case "": Publication.search_absent(db,word,label)
    case _: Publication.search_present(db,word,snapshot,6n,label)

def retry_identity(state: String,baseline: Publication.Baseline,+snapshot: String,label: String) -> IO(Unit):
  match state:
    case "unchanged":
      Publication.Baseline{old,_,_,_} = baseline
      Publication.assert(String.eq(old,snapshot),label ++ " unchanged retry retains its snapshot")
    case _:
      Publication.Baseline{old,_,_,_} = baseline
      Publication.assert(Bool.not(String.eq(old,snapshot)),label ++ " valid retry creates the required snapshot")

def retry_search(state: String,+db: U32,+snapshot: String,+label: String) -> IO(Unit):
  match state:
    case "initial":
      do IO<Unit>:
        Publication.search_present(db,"newcapture",snapshot,6n,label ++ " complete initial search is published")
        Publication.search_absent(db,"oldcapture",label ++ " no invented prefix appears")
    case "append":
      do IO<Unit>:
        Publication.search_present(db,"newcapture",snapshot,7n,label ++ " complete appended search is published")
        Publication.search_present(db,"oldcapture",snapshot,6n,label ++ " append prefix belongs to the new latest")
    case _:
      do IO<Unit>:
        Publication.search_present(db,"oldcapture",snapshot,6n,label ++ " unchanged search remains complete")
        Publication.search_absent(db,"newcapture",label ++ " unchanged retry adds no invented events")

def retry_text(state: String) -> String:
  match state:
    case "unchanged": Publication.fixture("oldcapture")
    case mode: Publication.changed(mode)

def final_retry(+db: U32,+state: String,+prefix: String,+baseline: Publication.Baseline,
  +control: Publication.Baseline,+label: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- Capture.import_file(db,"codex",prefix ++ ".jsonl.zst")
    retry_identity(state,baseline,snapshot,label)
    Publication.equal_scalar(db,"SELECT s.latest FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],snapshot,label ++ " valid retry publishes the target latest")
    Publication.equal_scalar(db,"SELECT count(*) FROM sources",[],"2",label ++ " both sources are preserved")
    Publication.equal_scalar(db,"SELECT count(*) FROM generations",[],"2",label ++ " append and unchanged retain their generation")
    Publication.equal_scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],
      Bool.pick(String,String.eq(state,"append"),"3","2"),label ++ " exact accepted snapshot count")
    Publication.equal_scalar(db,"SELECT count(*) FROM snapshots WHERE accepted<>1",[],"0",label ++ " no pending snapshot escapes")
    Publication.equal_scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],
      Bool.pick(String,String.eq(state,"append"),"16","8"),label ++ " complete logical record count")
    Publication.equal_scalar(db,"SELECT group_concat(body,'') FROM (SELECT CAST(r.bytes AS TEXT) AS body FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal)",
      [Sql.Cell.Integer{snapshot}],retry_text(state),label ++ " valid retry retains every exact logical byte")
    Retained.verify(db,snapshot)
    valid : Bool <- Store.projection_valid(db,snapshot)
    Publication.assert(valid,label ++ " valid retry projection seal verifies")
    retry_search(state,db,snapshot,label)
    baseline_latest(db,control,label ++ " control")
    baseline_search(db,control,"controlcapture",label ++ " control search is unchanged")
    Publication.pinned(db,control,label ++ " control")
    Publication.pinned(db,baseline,label ++ " target")
    again : String <- Capture.import_file(db,"codex",prefix ++ ".jsonl.zst")
    Publication.assert(String.eq(snapshot,again),label ++ " valid retry is idempotent")
    Publication.check_integrity(db,label)

def run_final_case(+self: String,+directory: String,+state: String,+fault: String) -> IO(Unit):
  +label = "final " ++ state ++ " " ++ fault
  +prefix = directory ++ "/gate-" ++ state ++ "-" ++ fault
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Publication.write_archive(prefix ++ ".control.jsonl.zst",Publication.fixture("controlcapture"))
    control_id : String <- Capture.import_file(db,"codex",prefix ++ ".control.jsonl.zst")
    +control : Publication.Baseline <- Publication.capture_baseline(db,control_id)
    +baseline : Publication.Baseline <- Publication.prepare_baseline(state,db,prefix ++ ".jsonl.zst")
    Publication.remember_tables(Publication.tables(),db)
    final_source(state,prefix ++ ".jsonl.zst")
    Store.write_text(prefix ++ ".marker","w","")
    IO.try(Unit,Sql.close(db))
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["final-child",state,fault,prefix],"",8192,30000)
    failed(result,final_error(fault),label)
    marker : String <- Publication.file_text(prefix ++ ".marker")
    Publication.assert(String.eq(marker,prefix ++ "|" ++ state ++ "|" ++ fault ++ "|before_commit"),
      label ++ " final BeforeCommit observer was reached")
    +reopened : U32 <- Store.open(prefix ++ ".sqlite")
    Publication.unchanged_tables(Publication.tables(),reopened,label)
    baseline_latest(reopened,control,label ++ " control")
    baseline_latest(reopened,baseline,label ++ " target")
    baseline_search(reopened,control,"controlcapture",label ++ " control search remains complete")
    baseline_search(reopened,baseline,"oldcapture",label ++ " target baseline search remains complete")
    Publication.search_absent(reopened,"newcapture",label ++ " failed capture is never searchable")
    Publication.pinned(reopened,control,label ++ " control")
    Publication.pinned(reopened,baseline,label ++ " target")
    Publication.check_integrity(reopened,label)
    final_retry(reopened,state,prefix,baseline,control,label ++ " retry")
    IO.try(Unit,Sql.close(reopened))

def run_final_faults(faults: List<&2,String>,+self: String,+directory: String,+state: String) -> IO(Unit):
  match faults:
    case []: IO.pure(Unit,Unit{})
    case fault <> rest:
      do IO<Unit>:
        run_final_case(self,directory,state,fault)
        run_final_faults(rest,self,directory,state)

def run_final_states(states: List<&2,String>,+self: String,+directory: String) -> IO(Unit):
  match states:
    case []: IO.pure(Unit,Unit{})
    case state <> rest:
      do IO<Unit>:
        run_final_faults(final_faults(),self,directory,state)
        run_final_states(rest,self,directory)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    first : U32 <- IO.try(U32,IO.random_u32())
    second : U32 <- IO.try(U32,IO.random_u32())
    +directory : String = ".build/archive-failures-" ++ U32.show(first) ++ "-" ++ U32.show(second)
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-m","700",directory],"",4096,2000))
    Fixture.process_ok(made,"create unique private synthetic failure directory")
    run_cases(cases(),self,directory)
    run_final_states(["initial","append","unchanged"],self,directory)
    IO.print("Archive failure suite passed: 43 owned importer rejection and atomic rollback cases")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "child" <> mode <> prefix <> []: child(mode,prefix)
    case _ <> "final-child" <> state <> fault <> prefix <> []: final_child(state,fault,prefix)
    case _: IO.die(Unit,2,"Archive failures expects no arguments or its owned child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
