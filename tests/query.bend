import Base
import ../src/query.bend as Query
import ../src/sql.bend as Sql

def assert(label: String, ok: Bool) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ label)

def is_error(result: Result<&2, &2, String, Query.Filters>) -> Bool:
  match result:
    case Fail{error}:
      True{}
    case Done{value}:
      False{}

def filters_equal(result: Result<&2, &2, String, Query.Filters>, query: String, provider: String, repo: String, role: String, after: String) -> Bool:
  match result:
    case Fail{error}:
      False{}
    case Done{Query.Filters{q, p, r, l, a}}:
      String.eq(q, query) && String.eq(p, provider) && String.eq(r, repo) && String.eq(l, role) && String.eq(a, after)

def pure_tests() -> IO(Unit):
  do IO<Unit>:
    assert("words become literal AND terms", String.eq(Query.fts("lemon counter"), "\"lemon\" AND \"counter\""))
    assert("phrase remains adjacent", String.eq(Query.fts("\"lemon counter\" preserved"), "\"lemon counter\" AND \"preserved\""))
    assert("FTS operators become text", String.eq(Query.fts("NEAR OR NOT * -foo"), "\"NEAR\" AND \"OR\" AND \"NOT\" AND \"*\" AND \"-foo\""))
    assert("path identifier punctuation safely quoted", String.eq(Query.fts("src/lemon.bend foo_bar() x:y"), "\"src/lemon.bend\" AND \"foo_bar()\" AND \"x:y\""))
    assert("quoted embedded quote escapes for FTS", String.eq(Query.fts("\"say \\\"hello\\\"\""), "\"say \"\"hello\"\"\""))
    assert("empty quoted and whitespace tokens disappear", String.eq(Query.fts(" \"\"  \"  \" \t\n"), ""))
    assert("unfinished phrase fallback remains safe literal", String.eq(Query.fts("\"unfinished"), "\"\"\"unfinished\""))
    assert("all inline filters parsed", filters_equal(Query.parse("lemon provider:claude repo:/synthetic/repo role:user after:2026-10-01"), "lemon", "claude", "/synthetic/repo", "user", "2026-10-01"))
    assert("quoted phrase retained around filters", filters_equal(Query.parse("provider:codex \"lemon counter\" preserves"), "\"lemon counter\" preserves", "codex", "", "", ""))
    assert("quoted repository with spaces", filters_equal(Query.parse("repo:\"/synthetic/my repo\" lemon"), "lemon", "", "/synthetic/my repo", "", ""))
    assert("quoted filter-looking term remains text", filters_equal(Query.parse("\"provider:claude\" x:y"), "\"provider:claude\" x:y", "", "", "", ""))
    assert("provider and role values normalize case", filters_equal(Query.parse("provider:CODEX role:ASSISTANT"), "", "codex", "", "assistant", ""))
    assert("empty text with filters is valid", filters_equal(Query.parse("\"\" provider:claude"), "", "claude", "", "", ""))
    assert("unknown provider visible", is_error(Query.parse("provider:future")))
    assert("empty provider visible", is_error(Query.parse("provider:")))
    assert("duplicate provider rejected", is_error(Query.parse("provider:claude provider:codex")))
    assert("duplicate repo rejected", is_error(Query.parse("repo:/a repo:/b")))
    assert("empty repository rejected", is_error(Query.parse("repo:\"\"")))
    assert("unknown role rejected", is_error(Query.parse("role:future")))
    assert("duplicate role rejected", is_error(Query.parse("role:user role:assistant")))
    assert("duplicate after rejected", is_error(Query.parse("after:2026-01-01 after:2026-02-01")))
    assert("unclosed quote visibly rejected", is_error(Query.parse("\"lemon")))
    assert("NUL visibly rejected", is_error(Query.parse("lemon\0counter")))
    assert("Unicode query retained", filters_equal(Query.parse("Café 中文 😀"), "Café 中文 😀", "", "", "", ""))
    assert("CLI 4096 characters accepted", Bool.not(is_error(Query.parse(String.repeat("x", 4096n)))))
    assert("CLI 4097 characters rejected", is_error(Query.parse(String.repeat("x", 4097n))))
    assert("UI 512 characters accepted", Bool.not(is_error(Query.parse_ui(String.repeat("x", 512n)))))
    assert("UI 513 characters rejected", is_error(Query.parse_ui(String.repeat("x", 513n))))
    assert("date ordinary valid", Query.date_valid("2026-10-20"))
    assert("date leap divisible by four", Query.date_valid("2024-02-29"))
    assert("date leap century divisible by four hundred", Query.date_valid("2000-02-29"))
    assert("date nonleap century rejects", Bool.not(Query.date_valid("1900-02-29")))
    assert("date nonleap ordinary rejects", Bool.not(Query.date_valid("2026-02-29")))
    assert("date April day31 rejects", Bool.not(Query.date_valid("2026-04-31")))
    assert("date invalid month rejects", Bool.not(Query.date_valid("2026-13-01")))
    assert("date zero day rejects", Bool.not(Query.date_valid("2026-01-00")))
    assert("date zero year rejects", Bool.not(Query.date_valid("0000-01-01")))
    assert("date malformed formatting rejects", Bool.not(Query.date_valid("2026-1-01")))
    assert("date nonnumeric rejects", Bool.not(Query.date_valid("202x-01-01")))
    assert("invalid date surfaces parse error", is_error(Query.parse("after:2026-02-30 lemon")))

def sql_exec(db: U32, statement: String, bindings: List<&2, Sql.Cell>) -> IO(Unit):
  do IO<Unit>:
    ignored : List<&2, List<&2, Sql.Cell>> <- IO.try(List<&2, List<&2, Sql.Cell>>, Sql.query(db, statement, bindings, 0))
    return Unit{}

def count_value(rows: List<&2, List<&2, Sql.Cell>>) -> String:
  match rows:
    case [[Sql.Cell.Integer{value}]]:
      value
    case _:
      "unexpected result"

def search_count(db: U32, raw: String, expected: String, label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2, List<&2, Sql.Cell>> <- IO.try(List<&2, List<&2, Sql.Cell>>, Sql.query(db,
      "SELECT count(*) FROM corpus WHERE corpus MATCH ?", [Sql.Cell.Text{Query.fts(raw)}], 1))
    assert(label, String.eq(count_value(rows), expected))

def sqlite_tests() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32, Sql.open(":memory:"))
    sql_exec(db, "CREATE VIRTUAL TABLE corpus USING fts5(body)", [])
    sql_exec(db, "INSERT INTO corpus(body) VALUES (?)", [Sql.Cell.Text{"lemon counter src/lemon.bend foo_bar say hello"}])
    sql_exec(db, "INSERT INTO corpus(body) VALUES (?)", [Sql.Cell.Text{"counter with fresh lemon elsewhere"}])
    sql_exec(db, "INSERT INTO corpus(body) VALUES (?)", [Sql.Cell.Text{"NEAR OR NOT literal operators"}])
    search_count(db, "lemon counter", "2", "SQLite default words AND without adjacency")
    search_count(db, "\"lemon counter\"", "1", "SQLite explicit phrase requires adjacency")
    search_count(db, "src/lemon.bend", "1", "SQLite practical path query")
    search_count(db, "foo_bar()", "1", "SQLite practical identifier query")
    search_count(db, "NEAR OR NOT", "1", "SQLite operator words literal")
    search_count(db, "\"say \\\"hello\\\"\"", "1", "SQLite embedded quote remains literal")
    search_count(db, "()[]{}:*!-+", "0", "SQLite punctuation-only query has no syntax error")
    search_count(db, "x: OR 1=1 --", "0", "SQLite injection-like query has no syntax error")
    IO.try(Unit, Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    pure_tests()
    sqlite_tests()
    IO.print("Query parser and native SQLite FTS checks complete")
