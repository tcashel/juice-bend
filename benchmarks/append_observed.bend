import Base
import ./main.bend as Fixture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/projection_seal.bend as Seal
import ../src/domain.bend as Domain

# Diagnostic of the actual production importer, with no component replay or
# rollback probe before measurement. Prepare creates one owned synthetic capture
# and appends16 fixture records outside every append timer. Run append once in
# that same private directory. Existing Store/Seal code is unchanged.
#
# Each of the nine real callbacks takes one clock sample and validates its
# expected phase. Samples stay in the affine observer until Committed, then
# print together. Segment times include the preceding callback's small bounded
# bookkeeping; the observed total excludes printing, while importer-return time
# includes it. No clock or diagnostic query runs per record.

type Sample is Data:
  Sample{phase: String, elapsed: Nat}

def phase_index(phase: Store.ImportPhase) -> U32:
  match phase:
    case Store.BeforeTransaction{}: 0
    case Store.Staged{}: 1
    case Store.Reverified{}: 2
    case Store.Sealed{}: 3
    case Store.Accepted{}: 4
    case Store.SearchRemoved{}: 5
    case Store.LatestRepointed{}: 6
    case Store.BeforeCommit{}: 7
    case Store.Committed{}: 8

def clock(enabled: Bool) -> IO(Nat):
  match enabled:
    case True{}: IO.now()
    case False{}: IO.pure(Nat,0n)

def print_samples(samples: List<&2,Sample>) -> IO(Unit):
  match samples:
    case []:
      IO.pure(Unit,Unit{})
    case Sample{phase,elapsed} <> rest:
      do IO<Unit>:
        IO.print("{\"end_phase\":\"" ++ phase ++ "\",\"segment_ms\":" ++ Nat.show(elapsed) ++ "}")
        print_samples(rest)

def observe_finish(samples: List<&2,Sample>,start: Nat,now: Nat,last: Bool,
  next: Unit -> Store.ImportObserver) -> IO(Store.ImportObserver):
  match last:
    case False{}:
      IO.pure(Store.ImportObserver,next(Unit{}))
    case True{}:
      do IO<Store.ImportObserver>:
        print_samples(List.reverse(&2,Sample,samples))
        IO.print("{\"operation\":\"observed_append_to_committed\",\"duration_ms\":" ++
          Nat.show(Nat.sub(now,start)) ++ ",\"callbacks\":9}")
        return Store.Unobserved{}

def observer(fuel: Nat,+measured: Bool,+index: U32,+start: Nat,+previous: Nat,+samples: List<&2,Sample>) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{+phase => do IO<Store.ImportObserver>:
        +now : Nat <- clock(measured)
        Store.checked(U32.is_eq(phase_index(phase),index),"Append diagnostic observed an unexpected production phase")
        Store.checked(Nat.is_ge(now,previous),"Append diagnostic clock moved backwards")
        +next_samples : List<&2,Sample> = Sample{Store.phase_name(phase),Nat.sub(now,previous)} <> samples
        observe_finish(next_samples,start,now,U32.is_eq(index,8),unused =>
          observer(rest,measured,U32.add(index,1),start,now,next_samples))}

def absent_opened(path: String,result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Fail{_}:
      IO.pure(Unit,Unit{})
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,2,"Refusing to overwrite existing diagnostic input: " ++ path)

def absent(+path: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent_opened(path,result)

def scalar(db: U32,statement: String,args: List<&2,Sql.Cell>,expected: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,statement,args,1)
    Store.checked(String.eq(Store.field(Store.first(rows),0n),expected),
      "Append diagnostic fixture/postflight scalar mismatch")

def expected_events(+count: U32) -> U32:
  U32.add(count,U32.div(count,4))

def preflight(+db: U32,+count: U32) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM sources",[],"1")
    scalar(db,"SELECT count(*) FROM generations",[],"1")
    scalar(db,"SELECT count(*) FROM snapshots",[],"1")
    scalar(db,"SELECT latest FROM sources WHERE id=1 AND provider='claude'",[],"1")
    scalar(db,"SELECT records FROM snapshots WHERE id=1 AND generation=1 AND accepted=1 AND checkpoint=extent AND checkpoint_ordinal=records",
      [],U32.show(count))
    scalar(db,"SELECT version FROM projection_checks WHERE snapshot=1",[],Seal.version(Store.projection_version()))
    triggers : Bool <- Store.has_triggers(db)
    Store.checked(Bool.not(triggers),"Append diagnostic fixture must have no SQL triggers")

def prepare(+count: U32) -> IO(Unit):
  do IO<Unit>:
    absent("benchmark.jsonl")
    absent("library.sqlite")
    absent("library.sqlite-wal")
    absent("library.sqlite-shm")
    Fixture.fixture("benchmark.jsonl",count)
    +db : U32 <- Store.open("library.sqlite")
    snapshot : String <- Store.import_file(db,"claude","benchmark.jsonl")
    Store.checked(String.eq(snapshot,"1"),"Append diagnostic preparation must start from an empty library")
    preflight(db,count)
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=1",[],U32.show(expected_events(count)))
    Fixture.generate(1n,"benchmark.jsonl",count,16)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"prepared\":true,\"old_snapshot\":\"1\",\"old_raw_records\":" ++ U32.show(count) ++
      ",\"tail_raw_records\":16,\"fixture_and_initial_capture_timed\":false}")

def postflight(+db: U32,+count: U32) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],"2")
    scalar(db,"SELECT count(*) FROM generations",[],"1")
    scalar(db,"SELECT latest FROM sources WHERE id=1",[],"2")
    scalar(db,"SELECT records FROM snapshots WHERE id=1",[],U32.show(count))
    scalar(db,"SELECT records FROM snapshots WHERE id=2",[],U32.show(U32.add(count,16)))
    scalar(db,"SELECT count(*) FROM raw",[],U32.show(U32.add(count,16)))
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw AND a.ordinal=b.ordinal WHERE a.snapshot=1 AND b.snapshot=2",[],U32.show(count))
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=1",[],U32.show(expected_events(count)))
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=2",[],U32.show(U32.add(expected_events(count),20)))
    scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=2",[],U32.show(U32.add(count,16)))
    scalar(db,"SELECT count(*) FROM search",[],U32.show(U32.add(expected_events(count),20)))
    scalar(db,"SELECT count(*) FROM search WHERE snapshot<>2",[],"0")
    old_valid : Bool <- Store.projection_valid(db,"1")
    Store.checked(old_valid,"Append diagnostic old event seal failed postflight")
    new_valid : Bool <- Store.projection_valid(db,"2")
    Store.checked(new_valid,"Append diagnostic new event seal failed postflight")
    scalar(db,"PRAGMA quick_check",[],"ok")
    scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")

def append(+count: U32,+measured: Bool) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open("library.sqlite")
    preflight(db,count)
    IO.print("{\"diagnostic\":\"actual-import-observer-v1\",\"raw_records_before\":" ++ U32.show(count) ++
      ",\"tail_raw_records\":16,\"preflight_and_postflight_outside_timer\":true,\"per_record_clock_calls\":0,\"timing_enabled\":" ++
      Bool.pick(String,measured,"true","false") ++ "}")
    +start : Nat <- clock(measured)
    latest : String <- Store.import_observed(db,"claude","benchmark.jsonl",observer(9n,measured,0,start,start,[]))
    end : Nat <- clock(measured)
    Store.checked(String.eq(latest,"2"),"Append diagnostic did not publish expected new snapshot")
    IO.print("{\"operation\":\"observed_append_until_import_return\",\"duration_ms\":" ++ Nat.show(Nat.sub(end,start)) ++
      ",\"includes_terminal_sample_printing\":true,\"timing_interval_ended\":true}")
    postflight(db,count)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"diagnostic_complete\":true,\"both_event_seals_valid\":true,\"prefix_raw_ids_shared\":" ++ U32.show(count) ++ "}")

def selected(mode: String,count: U32) -> IO(Unit):
  match mode:
    case "prepare": prepare(count)
    case "append": append(count,True{})
    case "check": append(count,False{})
    case _: IO.die(Unit,2,"usage: append-observed prepare|append|check RAW_RECORD_COUNT")

def run(mode: String,+count: U32) -> IO(Unit):
  do IO<Unit>:
    Store.checked(U32.is_ge(count,4) && U32.is_le(count,100000) && U32.is_eq(U32.mod(count,4),0),
      "Diagnostic count must be a positive multiple of four, at most100000")
    selected(mode,count)

def parsed(mode: String,value: Maybe<&2,U32>) -> IO(Unit):
  match value:
    case None{}: IO.die(Unit,2,"Diagnostic count requires canonical U32 decimal")
    case Some{count}: run(mode,count)

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case _ <> mode <> count <> []: parsed(mode,Domain.parse_u32(count))
    case _: IO.die(Unit,2,"usage: append-observed prepare|append|check RAW_RECORD_COUNT")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
