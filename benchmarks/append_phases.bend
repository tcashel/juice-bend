import Base
import ./main.bend as Fixture
import ../src/store.bend as Store
import ../src/sql.bend as Sql

# A diagnostic, not an alternate importer. Component probes call the actual
# production helpers in one transaction that is rolled back. The following
# full append calls import_observed and uses its existing publication cuts.
# Fixture generation and initial capture precede all append measurements.

def measure(name: String,start: Nat,end: Nat) -> IO(Unit):
  IO.print("{\"phase\":\"" ++ name ++ "\",\"duration_ms\":" ++ Nat.show(Nat.sub(end,start)) ++ "}")

def observer(fuel: Nat,previous: Nat) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        +now : Nat <- IO.now()
        measure("production_" ++ Store.phase_name(phase),previous,now)
        return observer(rest,now)}

def verified(got: File & Bool) -> IO(Unit):
  (file,same) = got
  do IO<Unit>:
    File.close(file)
    Store.checked(same,"Profile source prefix differs from retained raw bytes")

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    Store.checked(String.eq(Store.field(Store.first(rows),0n),expected),"Profile independent count mismatch")

def probe_copies(+db: U32,+old: List<&2,Sql.Cell>,+extent: U32) -> IO(Unit):
  +snapshot = Store.field(old,1n)
  +count = Store.number(Store.field(old,4n))
  do IO<Unit>:
    Store.exec(db,"INSERT INTO snapshots(generation,extent) VALUES(?,?)",
      [Sql.Cell.Integer{Store.field(old,0n)},Sql.Cell.Integer{U32.show(extent)}])
    +next : String <- Store.last_id(db)
    start : Nat <- IO.now()
    Store.copy_record_walk(4294967295n,db,snapshot,next,count,0)
    +maps : Nat <- IO.now()
    measure("probe_copy_record_maps",start,maps)
    Store.copy_event_walk(4294967295n,db,snapshot,next,U32.show(count),"-1","-1")
    +events : Nat <- IO.now()
    measure("probe_copy_events",maps,events)
    Store.copy_context_walk(4294967295n,db,snapshot,next,extent,count,0,U32.is_eq(count,0))
    contexts : Nat <- IO.now()
    measure("probe_copy_contexts",events,contexts)
    scalar(db,"SELECT count(*) FROM records WHERE snapshot=?",[Sql.Cell.Integer{next}],U32.show(count))
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{next}],
      U32.show(U32.add(count,U32.div(count,4))))
    scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=?",[Sql.Cell.Integer{next}],U32.show(count))

def probes(+db: U32,+snapshot: String,extent: U32) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT generation,id,extent,checkpoint,checkpoint_ordinal FROM snapshots WHERE id=?",
      [Sql.Cell.Integer{snapshot}],1)
    +old : List<&2,Sql.Cell> = Store.first(rows)
    file : File <- IO.try(File,File.open("benchmark.jsonl","r"))
    start : Nat <- IO.now()
    result : File & Bool <- Store.verify_loop(4294967295n,db,snapshot,0,file)
    verified(result)
    +raw : Nat <- IO.now()
    measure("probe_verify_raw_and_source",start,raw)
    +projection_ok : Bool <- Store.projection_valid(db,snapshot)
    +projection : Nat <- IO.now()
    Store.checked(projection_ok,"Profile existing projection seal is invalid")
    measure("probe_verify_projection",raw,projection)
    context_ok : Bool <- Store.context_prefix_valid(db,old,projection_ok)
    context : Nat <- IO.now()
    Store.checked(context_ok,"Profile existing context checkpoints are invalid")
    measure("probe_verify_contexts",projection,context)
    probe_copies(db,old,extent)
    Store.exec(db,"ROLLBACK",[])
    IO.print("{\"component_probe_rolled_back\":true}")

def run(+count: U32) -> IO(Unit):
  do IO<Unit>:
    Store.checked(U32.is_gt(count,0) && U32.is_le(count,100000) && U32.is_eq(U32.mod(count,4),0),
      "Profile count must be a positive multiple of four, at most100000")
    IO.print("{\"diagnostic\":\"append-phases-v1\",\"raw_records\":" ++ U32.show(count) ++
      ",\"fixture_generation_and_initial_capture\":\"outside_append_timers\",\"production_phase_times_include_observer_output\":true}")
    Fixture.fixture("benchmark.jsonl",count)
    +db : U32 <- Store.open("library.sqlite")
    +old : String <- Store.import_file(db,"claude","benchmark.jsonl")
    Fixture.generate(1n,"benchmark.jsonl",count,16)
    extent : U32 <- Fixture.file_size("benchmark.jsonl")
    probes(db,old,extent)
    +start : Nat <- IO.now()
    +latest : String <- Store.import_observed(db,"claude","benchmark.jsonl",observer(9n,start))
    end : Nat <- IO.now()
    measure("production_append_total",start,end)
    Store.checked(Bool.not(String.eq(old,latest)),"Profile append did not publish a new snapshot")
    scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],"2")
    scalar(db,"SELECT count(*) FROM records WHERE snapshot=?",[Sql.Cell.Integer{latest}],U32.show(U32.add(count,16)))
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{latest}],
      U32.show(U32.add(U32.add(count,U32.div(count,4)),20)))
    IO.try(Unit,Sql.close(db))
    IO.print("{\"diagnostic_complete\":true}")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    +value : String = Fixture.argument(args)
    Store.checked(Store.numeric(value),"Profile count requires canonical decimal")
    run(Store.number(value))
