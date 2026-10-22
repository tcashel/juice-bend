import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/scoped_reader.bend as Scoped
import ../src/maintenance.bend as Maintenance

# Run only against an isolated copy of the synthetic seed1337 100k benchmark
# database. Legacy prefix replay, verified checkpoint rebuild, and warm scoped
# pages are measured independently; no original source file is read.
def assert(ok: Bool,message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      IO.die(Unit,1,"Scoped benchmark correctness failure: " ++ message)

def measure(+db: U32,+snapshot: String,repository: String,+name: String) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    +text : String <- Scoped.page(db,snapshot,99900,100,
      Scoped.Scope{"claude",repository,"user","2026-01-01"},False{})
    end : Nat <- IO.now()
    assert(String.contains(text,"Bench record 99900 ") &&
      Bool.not(String.contains(text,"Bench record 99901 ")),
      "selected late page must contain an eligible user record and exclude assistant content")
    assert(String.eq(name,"record_local") ||
      (String.contains(text,"Visible events in this physical range: 9") &&
        Bool.not(String.contains(text,"Bench record 99904 "))),
      "repository scope must expose exactly nine eligible events")
    assert(Bool.not(String.eq(name,"record_local")) ||
      String.contains(text,"Visible events in this physical range: 25"),
      "record-local scope must expose exactly 25 eligible events")
    IO.print("{\"operation\":\"" ++ name ++ "\",\"milliseconds\":" ++ Nat.show(Nat.sub(end,start)) ++ "}")

def trials(fuel: Nat,+db: U32,+snapshot: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        measure(db,snapshot,"/synthetic/bend/repoA","repository")
        measure(db,snapshot,"","record_local")
        trials(rest,db,snapshot)

def run(path: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.records,(SELECT count(*) FROM events e WHERE e.snapshot=p.id) FROM snapshots p WHERE accepted=1 ORDER BY p.id DESC LIMIT 1",[],1)
    +snapshot : String <- IO.pure(String,Store.field(Store.first(rows),0n))
    assert(String.eq(Store.field(Store.first(rows),1n),"100016"),
      "requires the synthetic 100k+16 append benchmark database")
    measure(db,snapshot,"/synthetic/bend/repoA","legacy_repository")
    rebuilding : Nat <- IO.now()
    Maintenance.rebuild(db,snapshot)
    rebuilt : Nat <- IO.now()
    IO.print("{\"operation\":\"verified_projection_context_rebuild\",\"milliseconds\":" ++
      Nat.show(Nat.sub(rebuilt,rebuilding)) ++ "}")
    trials(5n,db,snapshot)
    IO.try(Unit,Sql.close(db))

def args(args: List<String>) -> IO(Unit):
  match args:
    case _ <> path <> []:
      run(path)
    case _:
      IO.die(Unit,2,"usage: scoped-benchmark ISOLATED_SYNTHETIC_DATABASE_COPY")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
