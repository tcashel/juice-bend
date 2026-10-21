import Base
import ../src/store.bend as Store
import ../src/maintenance.bend as Maintenance
import ../src/context_store.bend as ContextStore
import ../src/context_binding.bend as Binding
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ./context_portable.bend as Portable
import ./publication_crash.bend as Check
import ./append_integrity.bend as Append

# This candidate-only suite retains the original portable suite and adds real
# capture/publication checks around the larger context-query pages.
def fixture(count: U32) -> String:
  Check.fixture("oldcapture") ++ String.repeat(Check.message("assistant","batched retained message"),
    Nat.sub(U32.to_nat(count),8n))

def byte_fixture() -> String:
  fixture(120) ++ "{\"type\":\"session_meta\",\"payload\":{\"id\":\"large-context\",\"cwd\":" ++
    Json.quote("/synthetic/" ++ String.repeat("x",230000n)) ++ "}}\n" ++
    String.repeat(Check.message("assistant","late inherited large context"),136n)

def contents(mode: String) -> String:
  match mode:
    case "byte-gap":
      byte_fixture()
    case _:
      fixture(257)

def last_key(rows: List<&2,List<&2,Sql.Cell>>) -> String:
  match rows:
    case []:
      ""
    case [row]:
      Store.field(row,0n)
    case _ <> rest:
      last_key(rest)

def page(+rows: List<&2,List<&2,Sql.Cell>>,first: String,last: String,count: Nat,+label: String) -> IO(Unit):
  do IO<Unit>:
    Check.assert(String.eq(Store.field(Store.first(rows),0n),first),label ++ " starts at the exact observed key")
    Check.assert(String.eq(last_key(rows),last),label ++ " ends at the exact observed key")
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),count),label ++ " returns the expected bounded row count")

def pages(+db: U32,+snapshot: String,+count: U32) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,0,True{})
    page(rows,"0","127",128n,"initial production scan")
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.copy_keys(db,snapshot,0,count)
    page(rows,"0","127",128n,"initial production copy-key query")
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.equality_query(db,snapshot,snapshot,count,0,True{})
    page(rows,"0","127",128n,"initial production equality query")
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,128,False{})
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(
      Bool.pick(U32,U32.is_ge(count,256),128,U32.sub(count,128)))),
      "continuation scan is bounded at the128-row page boundary")
    rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,count,False{})
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),0n),"terminal scan proves no unvisited context keys")

def healthy(+count: U32) -> IO(Unit):
  +prefix = ".build/batched-healthy-" ++ U32.show(count)
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",fixture(count))
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    Portable.current(db,old,U32.show(count),"batched first capture" )
    pages(db,old,count)
    +baseline : Check.Baseline <- Check.capture_baseline(db,old)
    Store.write_text(prefix ++ ".jsonl","a",Check.message("assistant","one appended record"))
    +new : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    Portable.shared(db,old,new,U32.show(count),"batched healthy append retains every complete raw identity")
    Portable.copied_contexts(db,old,new,U32.show(count),"batched healthy append")
    Portable.current(db,new,U32.show(U32.add(count,1)),"batched appended capture")
    Portable.selected(db,new,U32.sub(count,1),"oldcapture-model","selected incoming context survives the page boundary")
    Store.write_text(prefix ++ "-fresh.jsonl","w",fixture(count) ++ Check.message("assistant","one appended record"))
    +fresh : String <- Store.import_file(db,"codex",prefix ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,"batched append equals independent full provider replay")
    Check.pinned(db,baseline,"batched healthy append")
    Check.check_integrity(db,"batched healthy append")
    IO.try(Unit,Sql.close(db))

def mutation(mode: String,target: String) -> String:
  match mode:
    case "fractional127":
      Portable.extra_from("127.5",target,"127")
    case "fractional255":
      Portable.extra_from("255.5",target,"255")
    case "negative":
      Portable.extra_from("-9223372036854775808",target,"127")
    case "negative-real":
      Portable.extra_from("-1e100",target,"255")
    case "text":
      Portable.extra_from("'typed-boundary'",target,"127")
    case "blob127":
      "UPDATE snapshot_context SET ordinal=CAST(ordinal AS BLOB) WHERE snapshot=" ++ target ++ " AND ordinal=127"
    case "blob255":
      "UPDATE snapshot_context SET ordinal=CAST(ordinal AS BLOB) WHERE snapshot=" ++ target ++ " AND ordinal=255"
    case "payload128":
      "UPDATE snapshot_context SET model=CAST(model AS BLOB) WHERE snapshot=" ++ target ++ " AND ordinal=128"
    case "missing128":
      "DELETE FROM snapshot_context WHERE snapshot=" ++ target ++ " AND ordinal=128"
    case _:
      "UPDATE snapshot_context SET digest=CAST(digest AS BLOB) WHERE snapshot=" ++ target ++ " AND ordinal=255"

def byte_cut(+rows: List<&2,List<&2,Sql.Cell>>,+label: String) -> IO(U32):
  +last = Store.number(last_key(rows))
  do IO<U32>:
    Check.assert(U32.is_ge(last,120) && U32.is_lt(last,127) &&
      Nat.is_lt(List.length(&2,List<&2,Sql.Cell>,rows),128n),
      label ++ " production query reaches its byte cut before its row limit")
    return U32.add(last,1)

def old_mutation(+mode: String,+db: U32,+snapshot: String) -> IO(Unit):
  match mode:
    case "byte-gap":
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,0,True{})
        gap : U32 <- byte_cut(rows,"old-prefix scan")
        Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=?",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(gap)}])
    case _:
      Store.exec(db,mutation(mode,"?"),[Sql.Cell.Integer{snapshot}])

def old_fallback(+mode: String) -> IO(Unit):
  +prefix = ".build/batched-old-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",contents(mode))
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    old_mutation(mode,db,old)
    event_valid : Bool <- Store.projection_valid(db,old)
    Check.assert(event_valid,mode ++ " context mutation leaves the independent event seal valid")
    Store.write_text(prefix ++ ".jsonl","a",Check.message("assistant","recovered batch tail"))
    +new : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    Portable.shared(db,old,new,"0",mode ++ " old checkpoint corruption forces safe full replay")
    Portable.same_generation(db,old,new,mode ++ " exact append replay retains source generation")
    Portable.current(db,new,"258",mode ++ " batched recovery")
    Store.write_text(prefix ++ "-fresh.jsonl","w",contents(mode) ++ Check.message("assistant","recovered batch tail"))
    +fresh : String <- Store.import_file(db,"codex",prefix ++ "-fresh.jsonl")
    Append.equivalent(db,new,fresh,mode ++ " recovery equals fresh normalized fields")
    Check.check_integrity(db,mode ++ " batched recovery")
    IO.try(Unit,Sql.close(db))

def target_mutation_mode(mode: String,+db: U32,+target: String) -> IO(Unit):
  match mode:
    case "byte-gap":
      do IO<Unit>:
        old : String <- Check.scalar(db,"SELECT min(id) FROM snapshots",[])
        rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.equality_query(db,old,target,257,0,True{})
        gap : U32 <- byte_cut(rows,"copied-prefix comparison")
        Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=?",
          [Sql.Cell.Integer{target},Sql.Cell.Integer{U32.show(gap)}])
    case _:
      Store.exec(db,mutation(mode,"?"),[Sql.Cell.Integer{target}])

def target_mutation(+mode: String,+db: U32) -> IO(Unit):
  do IO<Unit>:
    +target : String <- Check.scalar(db,"SELECT max(id) FROM snapshots",[])
    target_mutation_mode(mode,db,target)

def stage(enabled: Bool,+db: U32,+mode: String,prefix: String) -> IO(Unit):
  match enabled:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        target_mutation(mode,db)
        Store.write_text(prefix ++ ".marker","w","staged:" ++ mode ++ "\n")

def observe(fuel: Nat,+db: U32,+mode: String,+prefix: String) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        stage(String.eq(Store.phase_name(phase),"staged"),db,mode,prefix)
        return observe(rest,db,mode,prefix)}

def fault_child(+mode: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    ignored : String <- Store.import_observed(db,"codex",prefix ++ ".jsonl",observe(9n,db,mode,prefix))
    IO.die(Unit,1,"FAIL unsafe batched publication succeeded")

def new_fault(+self: String,+mode: String) -> IO(Unit):
  +prefix = ".build/batched-new-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",contents(mode))
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    +baseline : Check.Baseline <- Check.capture_baseline(db,old)
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",Check.message("assistant","retried batch tail"))
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["batch-fault",mode,prefix],"",8192,30000))
    Portable.rejected(result,mode ++ " copied checkpoint corruption rejects publication")
    Portable.marker(prefix ++ ".marker","staged:" ++ mode ++ "\n")
    Check.unchanged_tables(Check.tables(),db,mode ++ " batched transaction")
    Check.pinned(db,baseline,mode ++ " batched transaction")
    +new : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    Portable.shared(db,old,new,"257",mode ++ " rollback leaves the old prefix reusable")
    Portable.current(db,new,"258",mode ++ " batched retry")
    Check.check_integrity(db,mode ++ " batched rollback")
    IO.try(Unit,Sql.close(db))

# These transactional probes exercise the production limited payload query and
# its validator directly. A malformed first row must still make progress;
# missing joins must remain observable rather than disappearing from the page.
def query_mutation(+mode: String,+db: U32,+snapshot: String) -> IO(Unit):
  match mode:
    case "missing-map":
      Store.exec(db,"DELETE FROM records WHERE snapshot=? AND ordinal=128",[Sql.Cell.Integer{snapshot}])
    case "missing-raw":
      Store.exec(db,"DELETE FROM raw WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=128)",
        [Sql.Cell.Integer{snapshot}])
    case "raw-metadata":
      Store.exec(db,"UPDATE raw SET digest=? WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=128)",
        [Sql.Cell.Text{String.repeat("a",1100000n)},Sql.Cell.Integer{snapshot}])
    case "version-metadata":
      Store.exec(db,"UPDATE snapshot_context SET version=? WHERE snapshot=? AND ordinal=128",
        [Sql.Cell.Text{String.repeat("v",1100000n)},Sql.Cell.Integer{snapshot}])
    case "digest-metadata":
      Store.exec(db,"UPDATE snapshot_context SET digest=? WHERE snapshot=? AND ordinal=128",
        [Sql.Cell.Text{String.repeat("d",1100000n)},Sql.Cell.Integer{snapshot}])
    case _:
      Store.exec(db,"UPDATE snapshot_context SET repository=? WHERE snapshot=? AND ordinal=128",
        [Sql.Cell.Text{String.repeat("r",1100000n)},Sql.Cell.Integer{snapshot}])

def query_case(+mode: String) -> IO(Unit):
  +path = ".build/batched-query-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(path ++ ".sqlite")
    Store.write_text(path ++ ".jsonl","w",fixture(257))
    +snapshot : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    +generation : String <- Check.scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}])
    +prefix : Binding.Prefix <- ContextStore.generation_prefix(db,Store.projection_version(),generation)
    Check.remember_tables(Check.tables(),db)
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"PRAGMA defer_foreign_keys=ON",[])
    query_mutation(mode,db,snapshot)
    +rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,128,False{})
    Check.assert(String.eq(Store.field(Store.first(rows),0n),"128"),mode ++ " malformed first row remains visible")
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),
      Bool.pick(Nat,String.contains(mode,"missing-"),128n,1n)),
      mode ++ " first-row progress respects row and byte budgets")
    +rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.copy_keys(db,snapshot,128,257)
    Check.assert(String.eq(Store.field(Store.first(rows),0n),"128") &&
      Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),
        Bool.pick(Nat,String.contains(mode,"missing-") || String.eq(mode,"raw-metadata"),128n,1n)),
      mode ++ " copy-key query includes an oversized first row without loading later payloads")
    +rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.equality_query(db,snapshot,snapshot,257,128,False{})
    Check.assert(String.eq(Store.field(Store.first(rows),0n),"128") &&
      Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),
        Bool.pick(Nat,String.contains(mode,"missing-") || String.eq(mode,"raw-metadata"),128n,1n)),
      mode ++ " equality query respects metadata byte limits and first-row progress")
    valid : Bool <- ContextStore.scan(db,snapshot,prefix,257,0)
    Check.assert(Bool.not(valid),mode ++ " production validator rejects malformed joined payload")
    Store.exec(db,"ROLLBACK",[])
    Check.unchanged_tables(Check.tables(),db,mode ++ " query probe")
    Portable.current(db,snapshot,"257",mode ++ " rolled back healthy capture")
    Check.check_integrity(db,mode ++ " query rollback")
    IO.try(Unit,Sql.close(db))

def marker_type(blob: Bool) -> String:
  Bool.pick(String,blob,"BLOB","TEXT")

def add_marker(+db: U32,snapshot: String,blob: Bool,key: String) -> IO(Unit):
  Store.exec(db,"INSERT INTO snapshot_context SELECT snapshot,CAST(? AS " ++ marker_type(blob) ++
    "),repository,session,model,parent,version,digest FROM snapshot_context WHERE snapshot=? AND ordinal=0",
    [Sql.Cell.Text{key},Sql.Cell.Integer{snapshot}])

def add_markers(fuel: Nat,+db: U32,+snapshot: String,+blob: Bool) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+ +rest:
      do IO<Unit>:
        add_marker(db,snapshot,blob,"malformed-" ++ Nat.show(rest))
        add_markers(rest,db,snapshot,blob)

def all_null(cells: List<&2,Sql.Cell>) -> Bool:
  match cells:
    case []:
      True{}
    case Sql.Cell.Null{} <> rest:
      all_null(rest)
    case _:
      False{}

def marker_row(row: List<&2,Sql.Cell>,blob: Bool) -> Bool:
  match row:
    case Sql.Cell.Text{""} <> +rest:
      Bool.not(blob) && Nat.is_eq(List.length(&2,Sql.Cell,rest),13n) && all_null(rest)
    case Sql.Cell.Blob{bytes} <> +rest:
      blob && Nat.is_eq(List.length(&2,U32,bytes),0n) &&
        Nat.is_eq(List.length(&2,Sql.Cell,rest),13n) && all_null(rest)
    case _:
      False{}

def marker_rows(rows: List<&2,List<&2,Sql.Cell>>,+blob: Bool) -> Bool:
  match rows:
    case []:
      True{}
    case row <> rest:
      marker_row(row,blob) && marker_rows(rest,blob)

def marker_amplification(+blob: Bool) -> IO(Unit):
  +name = marker_type(blob)
  +path = ".build/batched-marker-" ++ name
  do IO<Unit>:
    +db : U32 <- Store.open(path ++ ".sqlite")
    Store.write_text(path ++ ".jsonl","w",fixture(257))
    +snapshot : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    generation : String <- Check.scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}])
    prefix : Binding.Prefix <- ContextStore.generation_prefix(db,Store.projection_version(),generation)
    Check.remember_tables(Check.tables(),db)
    Store.exec(db,"BEGIN IMMEDIATE",[])
    add_marker(db,snapshot,blob,"")
    Store.exec(db,"UPDATE snapshot_context SET repository=? WHERE snapshot=? AND ordinal=CAST('' AS " ++ marker_type(blob) ++ ")",
      [Sql.Cell.Text{String.repeat("x",65536n)},Sql.Cell.Integer{snapshot}])
    add_markers(127n,db,snapshot,blob)
    +rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,257,False{})
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),128n),
      name ++ " malformed-key page retains all128 typed failure markers")
    Check.assert(marker_rows(rows,blob),
      name ++ " normalized markers never join the real empty-key payload")
    valid : Bool <- ContextStore.scan(db,snapshot,prefix,257,0)
    Check.assert(Bool.not(valid),name ++ " malformed-key amplification fixture fails production validation")
    Store.exec(db,"ROLLBACK",[])
    Check.unchanged_tables(Check.tables(),db,name ++ " marker amplification probe")
    Portable.current(db,snapshot,"257",name ++ " marker rollback")
    Check.check_integrity(db,name ++ " marker rollback")
    IO.try(Unit,Sql.close(db))

def additions(+self: String) -> IO(Unit):
  do IO<Unit>:
    healthy(128)
    healthy(129)
    healthy(256)
    healthy(257)
    old_fallback("fractional127")
    old_fallback("fractional255")
    old_fallback("negative")
    old_fallback("negative-real")
    old_fallback("text")
    old_fallback("blob127")
    old_fallback("blob255")
    old_fallback("payload128")
    old_fallback("missing128")
    old_fallback("digest255")
    old_fallback("byte-gap")
    new_fault(self,"fractional127")
    new_fault(self,"fractional255")
    new_fault(self,"negative")
    new_fault(self,"negative-real")
    new_fault(self,"text")
    new_fault(self,"blob127")
    new_fault(self,"blob255")
    new_fault(self,"payload128")
    new_fault(self,"missing128")
    new_fault(self,"digest255")
    new_fault(self,"byte-gap")
    query_case("missing-map")
    query_case("missing-raw")
    query_case("oversized-first")
    query_case("version-metadata")
    query_case("digest-metadata")
    query_case("raw-metadata")
    marker_amplification(False{})
    marker_amplification(True{})
    IO.print("Batched context boundary additions passed")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case +self <> []:
      do IO<Unit>:
        Portable.suite(self)
        additions(self)
        IO.print("Batched context full integration suite passed")
    case _ <> "batch-fault" <> mode <> prefix <> []:
      fault_child(mode,prefix)
    case +self <> "batch-only" <> []:
      additions(self)
    case _ <> "fault" <> mode <> prefix <> []:
      Portable.fault_child(mode,prefix)
    case _ <> "binding" <> mode <> prefix <> snapshot <> []:
      Portable.binding_child(mode,prefix,snapshot)
    case _ <> "compat" <> +worker <> []:
      do IO<Unit>:
        Portable.compatibility_plain(worker)
        Portable.compatibility_waiting(worker)
        IO.print("Batched context actual old-worker compatibility passed")
    case _:
      IO.die(Unit,2,"Usage: context-batched [batch-only | compat ABSOLUTE_FROZEN_OLD_WORKER]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
