import Base
import ../src/store.bend as Store
import ../src/context_store.bend as ContextStore
import ../src/context_binding.bend as Binding
import ../src/sql.bend as Sql
import ./context_batched.bend as Batched
import ./context_portable.bend as Portable
import ./publication_crash.bend as Check

# Separate gate for integer-affinity raw metadata included in the byte budget.
# Corruption is transaction-local and never becomes an accepted capture.
def cell_at(cells: List<&2,Sql.Cell>,index: Nat) -> Sql.Cell:
  match cells index:
    case Nil{} _:
      Sql.Cell.Null{}
    case Con{cell,_} 0n:
      cell
    case Con{_,rest} 1n+next:
      cell_at(rest,next)

def exact_text(cell: Sql.Cell) -> Bool:
  match cell:
    case Sql.Cell.Text{value}:
      Nat.is_eq(String.length(value),1100000n)
    case _:
      False{}

def position(mode: String) -> Nat:
  match mode:
    case "record-raw":
      2n
    case "raw-generation":
      3n
    case _:
      5n

def statement(mode: String) -> String:
  match mode:
    case "record-raw":
      "UPDATE records SET raw=? WHERE snapshot=? AND ordinal=128"
    case "raw-generation":
      "UPDATE raw SET generation=? WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=128)"
    case _:
      "UPDATE raw SET offset=? WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=128)"

def check_field(+mode: String) -> IO(Unit):
  +path = ".build/context-metadata-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(path ++ ".sqlite")
    Store.write_text(path ++ ".jsonl","w",Batched.fixture(257))
    +snapshot : String <- Store.import_file(db,"codex",path ++ ".jsonl")
    generation : String <- Check.scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}])
    prefix : Binding.Prefix <- ContextStore.generation_prefix(db,Store.projection_version(),generation)
    Check.remember_tables(Check.tables(),db)
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"PRAGMA defer_foreign_keys=ON",[])
    Store.exec(db,statement(mode),[Sql.Cell.Text{String.repeat("x",1100000n)},Sql.Cell.Integer{snapshot}])
    +rows : List<&2,List<&2,Sql.Cell>> <- ContextStore.scan_query(db,snapshot,128,False{})
    Batched.page(rows,"128","128",1n,mode ++ " oversized metadata")
    Check.assert(exact_text(cell_at(Store.first(rows),position(mode))),
      mode ++ " query retains exact TEXT type and1100000-character ASCII length")
    valid : Bool <- ContextStore.scan(db,snapshot,prefix,257,0)
    Check.assert(Bool.not(valid),mode ++ " production validator rejects malformed integer-affinity metadata")
    Store.exec(db,"ROLLBACK",[])
    Check.unchanged_tables(Check.tables(),db,mode ++ " deferred-FK metadata probe")
    Portable.current(db,snapshot,"257",mode ++ " rolled back capture")
    Check.check_integrity(db,mode ++ " metadata rollback")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    check_field("record-raw")
    check_field("raw-generation")
    check_field("raw-offset")
    IO.print("Oversized context metadata suite passed")
