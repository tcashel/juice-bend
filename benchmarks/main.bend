import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/scoped_reader.bend as Scoped

# Generator version 1. Seed 1337; one long Claude-format session with varied
# repositories, dates, text, tool arguments/results, IDs and integer payloads.
# The fixture is written in 256-record batches before operation timers start.
# One of each four raw records yields two normalized events (text + tool use).

def assert(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit, Unit{})
    case False{}:
      IO.die(Unit, 1, "benchmark correctness failure: " ++ message)

def mix1(+x: U32) -> U32:
  U32.xor(x, U32.shln(x, 13n))

def mix2(+x: U32) -> U32:
  U32.xor(x, U32.shrn(x, 17n))

def mix3(+x: U32) -> U32:
  U32.xor(x, U32.shln(x, 5n))

def random(index: U32) -> U32:
  mix3(mix2(mix1((index + 1337 : U32))))

def decimal2(+n: U32) -> String:
  Bool.pick(String, U32.is_lt(n, 10), "0" ++ U32.show(n), U32.show(n))

def repo(index: U32) -> String:
  Bool.pick(String, U32.is_eq(U32.mod(index, 3), 0),
    "/synthetic/bend/repoA", "/synthetic/bend/repoB")

def common(+index: U32) -> String:
  "\"sessionId\":\"bench-seed1337\",\"cwd\":\"" ++ repo(index) ++
    "\",\"timestamp\":\"2026-01-" ++ decimal2((U32.mod(index, 28) + 1 : U32)) ++
    "T12:00:00Z\","

def body_text(+index: U32, +noise: U32) -> String:
  "Bench record " ++ U32.show(index) ++
    " lemon preservation request source src/module" ++ U32.show(U32.mod(noise, 211)) ++
    ".bend value " ++ U32.show(noise) ++
    " command rg identifier_" ++ U32.show(U32.mod(noise, 997)) ++
    " Unicode café 中 😀"

def record_kind(kind: U32, +index: U32, +noise: U32) -> String:
  match kind:
    case 0:
      "{" ++ common(index) ++ "\"type\":\"user\",\"message\":{\"role\":\"user\",\"content\":\"" ++
        body_text(index, noise) ++ "\"}}\n"
    case 1:
      "{" ++ common(index) ++ "\"type\":\"assistant\",\"message\":{\"role\":\"assistant\"," ++
        "\"model\":\"synthetic-model\",\"content\":[{\"type\":\"text\",\"text\":\"" ++
        body_text(index, noise) ++ "\"},{\"type\":\"tool_use\",\"id\":\"call-" ++
        U32.show(index) ++ "\",\"name\":\"Edit\",\"input\":{\"file_path\":\"src/module" ++
        U32.show(U32.mod(noise, 211)) ++ ".bend\",\"old_string\":\"value " ++
        U32.show(noise) ++ "\",\"new_string\":\"value " ++ U32.show((noise + 1 : U32)) ++ "\"}}]}}\n"
    case 2:
      "{" ++ common(index) ++ "\"type\":\"user\",\"message\":{\"role\":\"user\"," ++
        "\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"call-" ++
        U32.show((index - 1 : U32)) ++ "\",\"content\":\"Bench record " ++
        U32.show(index) ++ " updated value " ++ U32.show(noise) ++ " successfully\"}]}}\n"
    case _:
      "{" ++ common(index) ++ "\"type\":\"assistant\",\"message\":{\"role\":\"assistant\"," ++
        "\"model\":\"synthetic-model\",\"usage\":{\"input_tokens\":" ++
        U32.show((U32.mod(noise, 600) + 10 : U32)) ++ ",\"output_tokens\":" ++
        U32.show((U32.mod(noise, 90) + 1 : U32)) ++
        "},\"content\":\"" ++ body_text(index, noise) ++ "\"}}\n"

def record(+index: U32) -> String:
  record_kind(U32.mod(index, 4), index, random(index))

def batch(fuel: Nat, +index: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+rest:
      record(index) ++ batch(rest, (index + 1 : U32))

def generate(fuel: Nat, +path: String, +index: U32, +count: U32) -> IO(Unit):
  match fuel:
    case 0n:
      assert(U32.is_eq(count, 0), "generator budget exhausted")
    case 1n+rest:
      match count:
        case 0:
          IO.pure(Unit, Unit{})
        case _:
          +size = U32.min(count, 256)
          do IO<Unit>:
            Store.write_text(path, "a", batch(U32.to_nat(size), index))
            generate(rest, path, (index + size : U32), (count - size : U32))

def fixture(path: String, count: U32) -> IO(Unit):
  +p = path
  do IO<Unit>:
    Store.write_text(p, "w", "")
    generate(392n, p, 0, count)

def file_size_finish(got: File & Result<&1,&1,U32 & String,U32>) -> IO(U32):
  (file, size) = got
  do IO<U32>:
    File.close(file)
    IO.try(U32, IO.pure(Result<&1,&1,U32 & String,U32>, size))

def file_size(path: String) -> IO(U32):
  do IO<U32>:
    file : File <- IO.try(File, File.open(path, "r"))
    sized : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    file_size_finish(sized)

def measure(name: String, duration: Nat) -> IO(Unit):
  IO.print("{\"operation\":\"" ++ name ++ "\",\"duration_ms\":" ++ Nat.show(duration) ++ "}")

def values(xs: List<&2, Nat>) -> String:
  match xs:
    case []:
      ""
    case h <> []:
      Nat.show(h)
    case h <> rest:
      Nat.show(h) ++ "," ++ values(rest)

def nth(xs: List<&2, Nat>, n: Nat) -> Nat:
  match xs n:
    case [] _:
      0n
    case h <> rest 0n:
      h
    case h <> rest 1n+tail:
      nth(rest, tail)

def summarize(name: String, +trials: List<&2, Nat>) -> IO(Unit):
  +sorted = List.sort(~Nat, ~(a => b => Nat.is_le(a,b)), trials)
  # Five trials: median is third and nearest-rank p95 is fifth.
  IO.print("{\"operation\":\"" ++ name ++ "\",\"trials_ms\":[" ++ values(trials) ++
    "],\"median_ms\":" ++ Nat.show(nth(sorted,2n)) ++
    ",\"p95_ms\":" ++ Nat.show(nth(sorted,4n)) ++ ",\"trials\":5}")

def search_rows_valid(rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case []:
      True{}
    case +row <> rest:
      Bool.and(String.eq(Store.field(row,3n),"claude"),
        Bool.and(String.eq(Store.field(row,4n),"user"),
          Bool.and(String.eq(Store.field(row,6n),"/synthetic/bend/repoA"),
            Bool.and(String.is_ge(Store.field(row,8n),"2026-01-10T00:00:00Z"),
              search_rows_valid(rest)))))

def search_once(+db: U32) -> IO(Nat):
  do IO<Nat>:
    start : Nat <- IO.now()
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"lemon","claude",
      "/synthetic/bend/repoA","user","2026-01-10T00:00:00Z",100,0)
    end : Nat <- IO.now()
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),100n),
      "scoped search should fill its bounded 100-row page")
    assert(search_rows_valid(rows),"every result must preserve the requested scope")
    return Nat.sub(end,start)

def search_trials(fuel: Nat, +db: U32) -> IO(List<&2,Nat>):
  match fuel:
    case 0n:
      IO.pure(List<&2,Nat>, [])
    case 1n+rest:
      do IO<List<&2,Nat>>:
        elapsed : Nat <- search_once(db)
        later : List<&2,Nat> <- search_trials(rest,db)
        return elapsed <> later

def page_once(+db: U32, snapshot: String, +start_record: U32) -> IO(Nat):
  do IO<Nat>:
    start : Nat <- IO.now()
    +text : String <- Store.page(db,snapshot,start_record,100)
    end : Nat <- IO.now()
    assert(String.contains(text,"Bench record " ++ U32.show(start_record)),
      "page must contain independently expected first fixture record")
    return Nat.sub(end,start)

def page_trials(fuel: Nat, +db: U32, +snapshot: String,
  +start_record: U32) -> IO(List<&2,Nat>):
  match fuel:
    case 0n:
      IO.pure(List<&2,Nat>, [])
    case 1n+rest:
      do IO<List<&2,Nat>>:
        elapsed : Nat <- page_once(db,snapshot,start_record)
        later : List<&2,Nat> <- page_trials(rest,db,snapshot,start_record)
        return elapsed <> later

def scoped_page_once(+db: U32,snapshot: String,+start_record: U32) -> IO(Nat):
  do IO<Nat>:
    start : Nat <- IO.now()
    +text : String <- Scoped.page(db,snapshot,start_record,100,
      Scoped.Scope{"claude","/synthetic/bend/repoA","",""},False{})
    end : Nat <- IO.now()
    assert(String.contains(text,"Bench record " ++ U32.show(start_record)),
      "scoped late page contains independently expected repository A record")
    assert(Bool.not(String.contains(text,"Bench record " ++ U32.show(U32.add(start_record,1)))),
      "scoped late page excludes next repository B record")
    return Nat.sub(end,start)

def scoped_page_trials(fuel: Nat,+db: U32,+snapshot: String,+start_record: U32) ->
  IO(List<&2,Nat>):
  match fuel:
    case 0n:
      IO.pure(List<&2,Nat>,[])
    case 1n+rest:
      do IO<List<&2,Nat>>:
        elapsed : Nat <- scoped_page_once(db,snapshot,start_record)
        later : List<&2,Nat> <- scoped_page_trials(rest,db,snapshot,start_record)
        return elapsed <> later

def database_size(+db: U32) -> IO(Nat):
  do IO<Nat>:
    pages : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"PRAGMA page_count",[],1)
    size : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"PRAGMA page_size",[],1)
    return Nat.mul(U32.to_nat(Store.number(Store.field(Store.first(pages),0n))),
      U32.to_nat(Store.number(Store.field(Store.first(size),0n))))

def run(+count: U32) -> IO(Unit):
  do IO<Unit>:
    assert(Bool.and(U32.is_ge(count,10000),U32.is_le(count,100000)),
      "count must be between 10000 and 100000")
    assert(U32.is_eq(U32.mod(count,4),0),"count must be a multiple of four")
    IO.print("{\"benchmark\":\"juice-bend-backend\",\"generator\":1,\"seed\":1337,\"raw_records\":" ++
      U32.show(count) ++ ",\"expected_normalized_events\":" ++ U32.show((count + U32.div(count,4) : U32)) ++
      ",\"session_count\":1,\"ui_timings\":\"not_measured\",\"memory\":\"not_measured\"}")
    fixture("benchmark.jsonl",count)
    +source_bytes : U32 <- file_size("benchmark.jsonl")
    IO.print("{\"fixture_ready\":true,\"source_bytes\":" ++ U32.show(source_bytes) ++ "}")
    opened : Nat <- IO.now()
    +db : U32 <- Store.open("library.sqlite")
    ready : Nat <- IO.now()
    measure("empty_library_open",Nat.sub(ready,opened))
    importing : Nat <- IO.now()
    +snapshot : String <- Store.import_file(db,"claude","benchmark.jsonl")
    imported : Nat <- IO.now()
    measure("first_import",Nat.sub(imported,importing))
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],1)
    assert(String.eq(Store.field(Store.first(rows),0n),U32.show((count + U32.div(count,4) : U32))),
      "normalized event count disagrees with independent fixture contract")
    refreshing : Nat <- IO.now()
    +unchanged : String <- Store.import_file(db,"claude","benchmark.jsonl")
    refreshed : Nat <- IO.now()
    assert(String.eq(snapshot,unchanged),"unchanged refresh should reuse snapshot")
    measure("unchanged_refresh",Nat.sub(refreshed,refreshing))
    generate(1n,"benchmark.jsonl",count,16)
    appending : Nat <- IO.now()
    +latest : String <- Store.import_file(db,"claude","benchmark.jsonl")
    appended : Nat <- IO.now()
    assert(Bool.not(String.eq(snapshot,latest)),"append must publish new immutable snapshot")
    measure("append_16_raw_records",Nat.sub(appended,appending))
    first_search : Nat <- search_once(db)
    measure("first_search_after_import",first_search)
    searches : List<&2,Nat> <- search_trials(5n,db)
    summarize("warm_scoped_search",searches)
    early : Nat <- page_once(db,latest,0)
    measure("first_page_beginning_100_raw_records",early)
    middle : Nat <- page_once(db,latest,U32.div(count,2))
    measure("first_page_middle_100_raw_records",middle)
    late : Nat <- page_once(db,latest,(count - 100 : U32))
    measure("first_page_late_100_raw_records",late)
    pages : List<&2,Nat> <- page_trials(5n,db,latest,(count - 100 : U32))
    summarize("warm_late_page_100_raw_records",pages)
    # Repository A occurs every third raw record; select a late range whose
    # first record belongs to A and whose second belongs to B.
    +scoped_start : U32 = U32.sub(U32.sub(count,100),U32.mod(U32.sub(count,100),3))
    scoped_first : Nat <- scoped_page_once(db,latest,scoped_start)
    measure("first_repository_scoped_late_page_100_raw_records",scoped_first)
    scoped_pages : List<&2,Nat> <- scoped_page_trials(5n,db,latest,scoped_start)
    summarize("warm_repository_scoped_late_page_100_raw_records",scoped_pages)
    bytes : Nat <- database_size(db)
    stats : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM snapshots WHERE accepted=1),records,(SELECT count(*) FROM events WHERE snapshot=p.id) FROM snapshots p WHERE p.id=?",
      [Sql.Cell.Integer{latest}],1)
    +statistics : List<&2,Sql.Cell> <- IO.pure(List<&2,Sql.Cell>,Store.first(stats))
    assert(String.eq(Store.field(statistics,0n),"2"),"exactly two accepted snapshots")
    assert(String.eq(Store.field(statistics,1n),U32.show((count + 16 : U32))),
      "append retains exactly all physical records")
    assert(String.eq(Store.field(statistics,2n),U32.show((count + U32.div(count,4) + 20 : U32))),
      "append event count agrees with independent generator contract")
    IO.print("{\"sqlite_logical_page_bytes\":" ++ Nat.show(bytes) ++
      ",\"accepted_snapshots\":" ++ Store.field(statistics,0n) ++
      ",\"raw_records_latest\":" ++ Store.field(statistics,1n) ++
      ",\"normalized_events_latest\":" ++ Store.field(statistics,2n) ++ "}")
    IO.try(Unit,Sql.close(db))
    reopening : Nat <- IO.now()
    +again : U32 <- Store.open("library.sqlite")
    status : List<&2,List<&2,Sql.Cell>> <- Store.status(again)
    reopened : Nat <- IO.now()
    measure("existing_library_open_and_status",Nat.sub(reopened,reopening))
    IO.try(Unit,Sql.close(again))
    IO.print("{\"benchmark_complete\":true}")

def argument(args: List<String>) -> String:
  match args:
    case _ <> count <> _:
      count
    case _:
      "10000"

def run_checked(parsed: Maybe<&2,U32>) -> IO(Unit):
  match parsed:
    case None{}:
      IO.die(Unit,2,"usage: juice-bend-bench [raw-record-count]; canonical decimal required")
    case Some{count}:
      run(count)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    run_checked(Domain.parse_u32(argument(args)))
