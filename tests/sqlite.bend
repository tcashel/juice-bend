import Base
import ../src/sql.bend as Sql

def assert(ok: Bool, label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ label)

def byte_eq(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      U32.is_eq(x, y) && byte_eq(xt, yt)
    case _ _:
      False{}

def cell_eq(x: Sql.Cell, y: Sql.Cell) -> Bool:
  match x y:
    case Sql.Cell.Null{} Sql.Cell.Null{}:
      True{}
    case Sql.Cell.Integer{x} Sql.Cell.Integer{y}:
      String.eq(x, y)
    case Sql.Cell.Text{x} Sql.Cell.Text{y}:
      String.eq(x, y)
    case Sql.Cell.Blob{x} Sql.Cell.Blob{y}:
      byte_eq(x, y)
    case Sql.Cell.Real{x} Sql.Cell.Real{y}:
      String.eq(x, y)
    case _ _:
      False{}

def row_eq(xs: List<&2, Sql.Cell>, ys: List<&2, Sql.Cell>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      cell_eq(x, y) && row_eq(xt, yt)
    case _ _:
      False{}

def rows_eq(xs: List<&2, List<&2, Sql.Cell>>, ys: List<&2, List<&2, Sql.Cell>>) -> Bool:
  match xs ys:
    case Nil{} Nil{}:
      True{}
    case Con{x, xt} Con{y, yt}:
      row_eq(x, y) && rows_eq(xt, yt)
    case _ _:
      False{}

def check(db: U32, sql: String, values: List<&2, Sql.Cell>, limit: U32,
  expected: List<&2, List<&2, Sql.Cell>>, label: String) -> IO(Unit):
  do IO<Unit>:
    got : List<&2, List<&2, Sql.Cell>> <- IO.try(List<&2, List<&2, Sql.Cell>>,
      Sql.query(db, sql, values, limit))
    assert(rows_eq(got, expected), label)

def exec(db: U32, sql: String) -> IO(Unit):
  do IO<Unit>:
    result : List<&2, List<&2, Sql.Cell>> <- IO.try(List<&2, List<&2, Sql.Cell>>,
      Sql.query(db, sql, [], 0))
    return Unit{}

def failed(result: Result<&1, &1, U32 & String, List<&2, List<&2, Sql.Cell>>>,
  code: U32, label: String) -> IO(Unit):
  match result:
    case Fail{(actual, _)}:
      assert(U32.is_eq(actual, code), label)
    case Done{_}:
      assert(False{}, label)

def failure(db: U32, sql: String, values: List<&2, Sql.Cell>, limit: U32,
  code: U32, label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, List<&2, List<&2, Sql.Cell>>> <-
      Sql.query(db, sql, values, limit)
    failed(result, code, label)

def failed_close(result: Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match result:
    case Fail{(code, _)}:
      assert(U32.is_eq(code, 21), "double close refuses stale token")
    case Done{_}:
      assert(False{}, "double close refuses stale token")

def busy_close(result: Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  match result:
    case Fail{(code, _)}:
      assert(U32.is_eq(code, 5), "close refuses in-flight operation without invalidating token")
    case Done{_}:
      assert(False{}, "close refuses in-flight operation without invalidating token")

def failed_open(result: Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  match result:
    case Fail{(code, _)}:
      assert(U32.is_eq(code, 14), "open failure reports CANTOPEN")
    case Done{token}:
      do IO<Unit>:
        IO.try(Unit, Sql.close(token))
        assert(False{}, "open failure reports CANTOPEN")

def integer_failures(+db: U32, values: List<&2, String>) -> IO(Unit):
  match values:
    case []:
      IO.pure(Unit, Unit{})
    case Con{+head, tail}:
      do IO<Unit>:
        failure(db, "SELECT ?", [Sql.Cell.Integer{head}], 1, 20,
          "reject noncanonical or overflowing integer")
        integer_failures(db, tail)

def close_reopen(+path: String, +old: U32) -> IO(Unit):
  do IO<Unit>:
    IO.try(Unit, Sql.close(old))
    failure(old, "SELECT 1", [], 1, 21, "use after close refused")
    closed : Result<&1, &1, U32 & String, Unit> <- Sql.close(old)
    failed_close(closed)
    +reopened : U32 <- IO.try(U32, Sql.open(path))
    assert(Bool.not(U32.is_eq(reopened, old)), "connection tokens never reused")
    check(reopened, "SELECT value FROM boundary ORDER BY rowid", [], 4,
      [[Sql.Cell.Text{"durable"}], [Sql.Cell.Text{"after rollback"}]], "close/reopen persistence")
    exec(reopened, "BEGIN")
    exec(reopened, "INSERT INTO boundary VALUES ('uncommitted on close')")
    IO.try(Unit, Sql.close(reopened))
    +last : U32 <- IO.try(U32, Sql.open(path))
    check(last, "SELECT count(*) FROM boundary", [], 1,
      [[Sql.Cell.Integer{"2"}]], "close rolls back unfinished transaction")
    IO.try(Unit, Sql.close(last))

def worker_check(+db: U32) -> IO(Unit):
  do IO<Unit>:
    start : Nat <- IO.now()
    job : Chan(Result<&1, &1, U32 & String, List<&2, List<&2, Sql.Cell>>>) <-
      IO.fork(Result<&1, &1, U32 & String, List<&2, List<&2, Sql.Cell>>>,
        Sql.query(db, "WITH RECURSIVE forever(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM forever) SELECT sum(x) FROM forever",
          [], 1))
    IO.sleep(25)
    now : Nat <- IO.now()
    assert(((now - start : Nat) < 1000n : Nat), "SQLite worker leaves event loop available to timers")
    failure(db, "SELECT 1", [], 1, 5, "overlapping operation on same token refused")
    closing : Result<&1, &1, U32 & String, Unit> <- Sql.close(db)
    busy_close(closing)
    +independent : U32 <- IO.try(U32, Sql.open(":memory:"))
    check(independent, "SELECT 9", [], 1, [[Sql.Cell.Integer{"9"}]],
      "independent connection works during blocked query")
    IO.try(Unit, Sql.close(independent))
    answer : Result<&1, &1, U32 & String, List<&2, List<&2, Sql.Cell>>> <-
      IO.join(Result<&1, &1, U32 & String, List<&2, List<&2, Sql.Cell>>>, job)
    failed(answer, 9, "progress deadline interrupts runaway query")

def open_many(left: Nat, tokens: List<&2, U32>) -> IO(List<&2, U32>):
  match left:
    case 0n:
      IO.pure(List<&2, U32>, tokens)
    case 1n+tail:
      do IO<List<&2, U32>>:
        token : U32 <- IO.try(U32, Sql.open(":memory:"))
        open_many(tail, token <> tokens)

def close_many(tokens: List<&2, U32>) -> IO(Unit):
  match tokens:
    case []:
      IO.pure(Unit, Unit{})
    case Con{head, tail}:
      do IO<Unit>:
        IO.try(Unit, Sql.close(head))
        close_many(tail)

def registry_full(result: Result<&1, &1, U32 & String, U32>) -> IO(Unit):
  match result:
    case Fail{(code, _)}:
      assert(U32.is_eq(code, 13), "connection registry exhausts safely")
    case Done{token}:
      do IO<Unit>:
        IO.try(Unit, Sql.close(token))
        assert(False{}, "connection registry exhausts safely")

def registry_check() -> IO(Unit):
  do IO<Unit>:
    tokens : List<&2, U32> <- open_many(63n, [])
    full : Result<&1, &1, U32 & String, U32> <- Sql.open(":memory:")
    registry_full(full)
    close_many(tokens)
    token : U32 <- IO.try(U32, Sql.open(":memory:"))
    IO.try(Unit, Sql.close(token))
    assert(True{}, "closing releases every registry slot")

def main() -> IO(Unit):
  do IO<Unit>:
    nonce : U32 <- IO.try(U32, IO.random_u32())
    +path : String = ".build/sqlite-boundary-" ++ U32.show(nonce) ++ ".sqlite"
    +db : U32 <- IO.try(U32, Sql.open(path))
    check(db, "SELECT ?, ?, ?, ?, ?, ?, ?, ?, ?, ?", [
      Sql.Cell.Null{}, Sql.Cell.Integer{"0"}, Sql.Cell.Integer{"-9223372036854775808"},
      Sql.Cell.Integer{"9223372036854775807"}, Sql.Cell.Integer{"9007199254740993"},
      Sql.Cell.Integer{"4294967296"}, Sql.Cell.Text{"Juice\0 café 中 😀"},
      Sql.Cell.Blob{[0, 255, 128, 65]}, Sql.Cell.Blob{[]}, Sql.Cell.Real{"1.5"}], 1,
      [[Sql.Cell.Null{}, Sql.Cell.Integer{"0"}, Sql.Cell.Integer{"-9223372036854775808"},
      Sql.Cell.Integer{"9223372036854775807"}, Sql.Cell.Integer{"9007199254740993"},
      Sql.Cell.Integer{"4294967296"}, Sql.Cell.Text{"Juice\0 café 中 😀"},
      Sql.Cell.Blob{[0, 255, 128, 65]}, Sql.Cell.Blob{[]}, Sql.Cell.Real{"1.5"}]],
      "typed exact i64/Unicode/NUL/binary/empty blob/real roundtrip")
    exec(db, "CREATE TABLE boundary(value TEXT NOT NULL)")
    check(db, "INSERT INTO boundary VALUES (?)", [Sql.Cell.Text{"durable"}], 0, [],
      "prepared mutation")
    check(db, "SELECT ?", [Sql.Cell.Text{"'); DROP TABLE boundary; --"}], 1,
      [[Sql.Cell.Text{"'); DROP TABLE boundary; --"}]], "injection text remains data")
    exec(db, "CREATE VIRTUAL TABLE search USING fts5(text)")
    exec(db, "INSERT INTO search VALUES ('captured juice benchmark')")
    check(db, "SELECT rowid FROM search WHERE search MATCH ?", [Sql.Cell.Text{"juice"}], 2,
      [[Sql.Cell.Integer{"1"}]], "SQLite FTS5 enabled")
    check(db, "SELECT 1; -- trailing comment", [], 1, [[Sql.Cell.Integer{"1"}]],
      "trailing SQL comment accepted")
    failure(db, "INSERT INTO boundary VALUES ('must not run'); DELETE FROM boundary",
      [], 0, 21, "multiple statements refused before execution")
    check(db, "SELECT count(*) FROM boundary", [], 1, [[Sql.Cell.Integer{"1"}]],
      "multiple-statement rejection has no side effects")
    integer_failures(db, ["9223372036854775808", "-9223372036854775809", "01", "-0", "+1", "", "1.0", " 1", "1\0"])
    failure(db, "SELECT ?", [Sql.Cell.Blob{[256]}], 1, 20, "out-of-range byte refused")
    failure(db, "SELECT ?", [Sql.Cell.Text{SCon{Chr{55296},SNil{}}}], 1, 20,
      "surrogate scalar refused without replacement")
    failure(db, "SELECT ?", [Sql.Cell.Text{SCon{Chr{1114112},SNil{}}}], 1, 20,
      "out-of-range Unicode scalar refused without replacement")
    failure(db, "SELECT ?", [Sql.Cell.Real{"NaN"}], 1, 20, "NaN refused")
    failure(db, "SELECT ?", [Sql.Cell.Real{"1e999"}], 1, 20, "overflowing real refused")
    failure(db, "SELECT ?", [], 1, 25, "missing binding refused")
    failure(db, "SELECT 1", [Sql.Cell.Null{}], 1, 25, "extra binding refused")
    failure(db, "", [], 1, 21, "empty SQL refused")
    failure(db, "SELECT 1\0; SELECT 2", [], 1, 21, "SQL NUL refused")
    failure(db, "SELECT absent FROM missing_table", [], 1, 1, "SQL error finalized")
    failure(db, "SELECT 1 UNION ALL SELECT 2", [], 1, 18, "row limit fails without truncation")
    failure(db, "SELECT zeroblob(4194305)", [], 1, 18, "output byte limit enforced")
    failure(db, "SELECT CAST(x'ff' AS TEXT)", [], 1, 20, "invalid UTF-8 text refused, use Blob")
    failure(db, "SELECT 1", [], 4097, 18, "caller row limit bounded")
    failure(0, "SELECT 1", [], 1, 21, "invalid token refused")
    check(db, "SELECT 42", [], 1, [[Sql.Cell.Integer{"42"}]],
      "connection reusable after statement errors")
    exec(db, "BEGIN IMMEDIATE")
    exec(db, "INSERT INTO boundary VALUES ('rollback me')")
    +other : U32 <- IO.try(U32, Sql.open(path))
    check(other, "SELECT count(*) FROM boundary", [], 1, [[Sql.Cell.Integer{"1"}]],
      "reader cannot observe uncommitted capture")
    failure(other, "INSERT INTO boundary VALUES ('busy')", [], 0, 5,
      "database contention returns BUSY within timeout")
    exec(db, "ROLLBACK")
    check(db, "SELECT count(*) FROM boundary", [], 1, [[Sql.Cell.Integer{"1"}]],
      "rollback discards staged bytes")
    exec(other, "INSERT INTO boundary VALUES ('after rollback')")
    IO.try(Unit, Sql.close(other))
    worker_check(db)
    check(db, "SELECT 7", [], 1, [[Sql.Cell.Integer{"7"}]],
      "interrupt finalized and progress hook reset")
    bad : Result<&1, &1, U32 & String, U32> <- Sql.open("/private/tmp/juice-bend-no-such-parent/sqlite.db")
    failed_open(bad)
    registry_check()
    close_reopen(path, db)
    IO.print("SQLite boundary suite passed; isolated database: " ++ path)
