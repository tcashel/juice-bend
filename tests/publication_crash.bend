import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/evidence.bend as Evidence
import ../src/maintenance.bend as Maintenance

# The runner starts in scripts/test's private synthetic directory. Every child
# is this executable; Process.run owns its PID, sends SIGKILL on timeout and
# reaps it. A fresh nonce-bound, closed marker proves the exact hold was reached.
# There is no shell, external kill, environment switch or per-record fault hook.
type Baseline is Data:
  Baseline{snapshot: String,page: String,citation: String,quote: String}

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    return Store.field(Store.first(rows),0n)

def equal_scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,
  expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : String <- scalar(db,sql,args)
    assert(String.eq(actual,expected),label)

def response(payload: String) -> String:
  "{\"type\":\"response_item\",\"timestamp\":\"2026-10-01T12:00:00Z\",\"payload\":" ++ payload ++ "}\n"

def message(role: String,body: String) -> String:
  response("{\"type\":\"message\",\"role\":" ++ Json.quote(role) ++
    ",\"content\":[{\"type\":\"input_text\",\"text\":" ++ Json.quote(body) ++ "}]}")

def context(model: String) -> String:
  "{\"type\":\"turn_context\",\"payload\":{\"model\":" ++ Json.quote(model) ++ "}}\n"

def call(+word: String) -> String:
  response("{\"type\":\"function_call\",\"name\":\"exec_command\",\"call_id\":" ++
    Json.quote(word ++ "-call") ++ ",\"arguments\":" ++
    Json.quote("{\"cmd\":\"printf " ++ word ++ "\"}") ++ "}")

def output(+word: String) -> String:
  response("{\"type\":\"function_call_output\",\"call_id\":" ++ Json.quote(word ++ "-call") ++
    ",\"output\":" ++ Json.quote(word ++ " tool result") ++ "}")

# Eight physical records, with explicit independent field expectations below.
def fixture(+word: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"publication-session\",\"cwd\":\"/synthetic/publication\"}}\n" ++
    context(word ++ "-model") ++ message("user",word ++ " request") ++
    call(word) ++ output(word) ++ message("assistant",word ++ " answer") ++
    message("user",word ++ " second request") ++ message("assistant",word ++ " final answer")

def tail() -> String:
  context("newcapture-model") ++ message("user","newcapture request") ++
    call("newcapture") ++ output("newcapture") ++
    message("assistant","newcapture answer") ++ message("user","newcapture second request") ++
    message("assistant","newcapture final answer") ++ message("user","newcapture closing request")

def changed(mode: String) -> String:
  match mode:
    case "append":
      fixture("oldcapture") ++ tail()
    case _:
      fixture("newcapture")

def tables() -> List<&2,String>:
  ["sources","generations","snapshots","raw","records","events","snapshot_context","projection_checks","search"]

def table_columns(table: String) -> String:
  match table:
    case "search":
      "rowid,*"
    case _:
      "*"

# Exact SQL set comparison includes every cell and raw BLOB, not just counts.
# Primary keys make these sets; FTS rowid is included to retain multiplicity.
def remember_tables(names: List<&2,String>,+db: U32) -> IO(Unit):
  match names:
    case []:
      IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        Store.exec(db,"CREATE TABLE before_" ++ name ++ " AS SELECT " ++
          table_columns(name) ++ " FROM " ++ name,[])
        remember_tables(rest,db)

def unchanged_tables(names: List<&2,String>,+db: U32,+label: String) -> IO(Unit):
  match names:
    case []:
      IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        +forward : String <- scalar(db,"SELECT count(*) FROM (SELECT " ++ table_columns(name) ++
          " FROM " ++ name ++ " EXCEPT SELECT * FROM before_" ++ name ++ ")",[])
        reverse : String <- scalar(db,"SELECT count(*) FROM (SELECT * FROM before_" ++ name ++
          " EXCEPT SELECT " ++ table_columns(name) ++ " FROM " ++ name ++ ")",[])
        assert(String.eq(forward,"0") && String.eq(reverse,"0"),
          label ++ " rollback preserves every " ++ name ++ " cell")
        unchanged_tables(rest,db,label)

def quote_result(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}:
      IO.pure(String,text)
    case Fail{error}:
      IO.die(String,1,"FAIL citation resolution: " ++ error)

def capture_baseline(+db: U32,+snapshot: String) -> IO(Baseline):
  do IO<Baseline>:
    page : String <- Store.page(db,snapshot,0,100)
    record : Evidence.Verified <- Evidence.read_record(db,snapshot,2)
    +citation : String = Evidence.citation(record,0)
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    quote : String <- quote_result(resolved)
    return Baseline{snapshot,page,citation,quote}

def prepare_baseline(mode: String,+db: U32,+source: String) -> IO(Baseline):
  match mode:
    case "initial":
      IO.pure(Baseline,Baseline{"","","",""})
    case _:
      do IO<Baseline>:
        Store.write_text(source,"w",fixture("oldcapture"))
        snapshot : String <- Store.import_file(db,"codex",source)
        capture_baseline(db,snapshot)

def pinned(+db: U32,baseline: Baseline,+label: String) -> IO(Unit):
  Baseline{+snapshot,page,citation,quote} = baseline
  match snapshot:
    case "":
      IO.pure(Unit,Unit{})
    case _:
      do IO<Unit>:
        actual : String <- Store.page(db,snapshot,0,100)
        assert(String.eq(actual,page),label ++ " old pinned transcript is byte-for-byte stable")
        resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
        actual_quote : String <- quote_result(resolved)
        assert(String.eq(actual_quote,quote),label ++ " old citation resolves to the exact retained evidence")
        Maintenance.verify(db,snapshot)
        IO.print("PASS " ++ label ++ " old raw extent remains fully verified")

def check_integrity(+db: U32,+label: String) -> IO(Unit):
  do IO<Unit>:
    equal_scalar(db,"PRAGMA integrity_check",[],"ok",label ++ " SQLite integrity")
    violations : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"PRAGMA foreign_key_check",[],100)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,violations),label ++ " foreign-key integrity")

def all_snapshot(rows: List<&2,List<&2,Sql.Cell>>,+snapshot: String) -> Bool:
  match rows:
    case []:
      True{}
    case row <> rest:
      String.eq(Store.field(row,0n),snapshot) && all_snapshot(rest,snapshot)

def search_present(+db: U32,word: String,+snapshot: String,count: Nat,label: String) -> IO(Unit):
  do IO<Unit>:
    +hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,word,"codex","/synthetic/publication","","",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),count) && all_snapshot(hits,snapshot),label)

def search_absent(db: U32,word: String,label: String) -> IO(Unit):
  do IO<Unit>:
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,word,"codex","","","",100,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,hits),label)

def previous_visible(mode: String,+db: U32,baseline: Baseline,+label: String) -> IO(Unit):
  match mode:
    case "initial":
      do IO<Unit>:
        equal_scalar(db,"SELECT count(*) FROM sources",[],"0",label ++ " initial source remains unpublished")
        search_absent(db,"oldcapture",label ++ " empty baseline has no old search result")
    case _:
      Baseline{+snapshot,_,_,_} = baseline
      do IO<Unit>:
        equal_scalar(db,"SELECT latest FROM sources",[],snapshot,label ++ " previous latest remains published")
        search_present(db,"oldcapture",snapshot,6n,label ++ " all six previous accepted search results stay visible")

def record_count(mode: String) -> String:
  match mode:
    case "append":
      "16"
    case _:
      "8"

def generations(mode: String) -> String:
  match mode:
    case "rewrite":
      "2"
    case _:
      "1"

def accepted_count(mode: String) -> String:
  match mode:
    case "initial":
      "1"
    case _:
      "2"

def total_records(mode: String) -> String:
  match mode:
    case "initial":
      "8"
    case "append":
      "24"
    case _:
      "16"

def request_ordinal(mode: String) -> String:
  match mode:
    case "append":
      "9"
    case _:
      "2"

def call_ordinal(mode: String) -> String:
  match mode:
    case "append":
      "10"
    case _:
      "3"

def published(+db: U32,+mode: String,+snapshot: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    equal_scalar(db,"SELECT latest FROM sources",[],snapshot,label ++ " complete latest is published")
    equal_scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],accepted_count(mode),
      label ++ " accepted snapshot count")
    equal_scalar(db,"SELECT count(*) FROM snapshots WHERE accepted<>1",[],"0",
      label ++ " no pending snapshot escapes publication")
    equal_scalar(db,"SELECT count(*) FROM generations",[],generations(mode),label ++ " generation semantics")
    equal_scalar(db,"SELECT count(*) FROM raw",[],
      Bool.pick(String,String.eq(mode,"initial"),"8","16"),label ++ " no extra raw occurrences survive")
    equal_scalar(db,"SELECT count(*) FROM records",[],total_records(mode),label ++ " all snapshot record mappings complete")
    equal_scalar(db,"SELECT count(*) FROM projection_checks",[],accepted_count(mode),label ++ " every accepted projection has one seal")
    equal_scalar(db,"SELECT records FROM snapshots WHERE id=? AND accepted=1",[Sql.Cell.Integer{snapshot}],
      record_count(mode),label ++ " complete accepted record count")
    equal_scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],
      record_count(mode),label ++ " every accepted record has bound incoming context")
    Maintenance.verify(db,snapshot)
    IO.print("PASS " ++ label ++ " accepted raw extent fully verified")
    valid : Bool <- Store.projection_valid(db,snapshot)
    assert(valid,label ++ " accepted projection seal verified")
    equal_scalar(db,
      "SELECT group_concat(body,'') FROM (SELECT CAST(r.bytes AS TEXT) AS body FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal)",
      [Sql.Cell.Integer{snapshot}],changed(mode),label ++ " owned bytes exactly equal independent synthetic input")
    equal_scalar(db,"SELECT repository||'|'||session||'|'||model||'|'||body FROM events WHERE snapshot=? AND ordinal=? AND event=0",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{request_ordinal(mode)}],
      "/synthetic/publication|publication-session|newcapture-model|newcapture request",
      label ++ " independent scope session model and request fields")
    equal_scalar(db,"SELECT c.tool||'|'||c.call_id||'|'||c.arguments||'|'||r.result FROM events c JOIN events r ON r.snapshot=c.snapshot AND r.call_id=c.call_id AND r.ordinal=c.ordinal+1 WHERE c.snapshot=? AND c.ordinal=? AND c.event=0 AND r.event=0",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{call_ordinal(mode)}],
      "exec_command|newcapture-call|{\"cmd\":\"printf newcapture\"}|newcapture tool result",
      label ++ " complete tool arguments and result share the recorded call identity")
    search_present(db,"newcapture",snapshot,Bool.pick(Nat,String.eq(mode,"append"),7n,6n),
      label ++ " complete new search count points only to accepted latest")

def old_search(mode: String,+db: U32,snapshot: String,+label: String) -> IO(Unit):
  match mode:
    case "append":
      search_present(db,"oldcapture",snapshot,6n,label ++ " all six append prefix hits are indexed only under latest")
    case _:
      search_absent(db,"oldcapture",label ++ " replaced generation is absent from latest search")

def raw_reuse(mode: String,db: U32,baseline: Baseline,snapshot: String,label: String) -> IO(Unit):
  Baseline{old,_,_,_} = baseline
  equal_scalar(db,
    "SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
    [Sql.Cell.Text{old},Sql.Cell.Integer{snapshot}],
    Bool.pick(String,String.eq(mode,"append"),"8","0"),label ++ " append reuses exactly the verified prefix occurrences")

def equivalent(+db: U32,+left: String,+right: String,+label: String) -> IO(Unit):
  +columns = {"ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage" : String}
  do IO<Unit>:
    equal_scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++
      " FROM events WHERE snapshot=? EXCEPT SELECT " ++ columns ++ " FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{left},Sql.Cell.Integer{right}],"0",label ++ " fresh full projection forward")
    equal_scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++
      " FROM events WHERE snapshot=? EXCEPT SELECT " ++ columns ++ " FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{right},Sql.Cell.Integer{left}],"0",label ++ " fresh full projection reverse")

def recovery(+db: U32,+mode: String,+source: String,+baseline: Baseline,+before: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- Store.import_file(db,"codex",source)
    assert(String.is_empty(before) || String.eq(snapshot,before),
      label ++ " retry preserves any already committed snapshot identity")
    published(db,mode,snapshot,label ++ " retry")
    old_search(mode,db,snapshot,label ++ " retry")
    raw_reuse(mode,db,baseline,snapshot,label ++ " retry")
    +again : String <- Store.import_file(db,"codex",source)
    assert(String.eq(snapshot,again),label ++ " unchanged retry is idempotent")
    equal_scalar(db,"SELECT count(*) FROM snapshots",[],accepted_count(mode),label ++ " retry creates no duplicate snapshot")
    pinned(db,baseline,label ++ " retry")
    Store.write_text(source ++ ".fresh","w",changed(mode))
    fresh : String <- Store.import_file(db,"codex",source ++ ".fresh")
    equivalent(db,snapshot,fresh,label)
    check_integrity(db,label ++ " recovered")

def after_interruption(phase: String,+db: U32,+mode: String,+source: String,
  +baseline: Baseline,+label: String) -> IO(Unit):
  match phase:
    case "committed":
      do IO<Unit>:
        +latest : String <- scalar(db,"SELECT latest FROM sources",[])
        published(db,mode,latest,label)
        old_search(mode,db,latest,label)
        pinned(db,baseline,label)
        recovery(db,mode,source,baseline,latest,label)
    case _:
      do IO<Unit>:
        unchanged_tables(tables(),db,label)
        previous_visible(mode,db,baseline,label)
        search_absent(db,"newcapture",label ++ " uncommitted data never becomes searchable")
        pinned(db,baseline,label)
        recovery(db,mode,source,baseline,"",label)

def hold(selected: Bool,marker: String,contents: String) -> IO(Unit):
  match selected:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      do IO<Unit>:
        Store.write_text(marker,"w",contents)
        IO.sleep(60000)

def observe(+expected: String,+marker: String,+contents: String,phase: Store.ImportPhase) -> IO(Unit):
  hold(String.eq(Store.phase_name(phase),expected),marker,contents)

def held_observer(fuel: Nat,+expected: String,+marker: String,+contents: String) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        observe(expected,marker,contents,phase)
        return held_observer(rest,expected,marker,contents)}

def token(nonce: String,mode: String,phase: String) -> String:
  nonce ++ "\n" ++ mode ++ "\n" ++ phase ++ "\n"

def child(+mode: String,+phase: String,nonce: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- Store.import_observed(db,"codex",prefix ++ ".jsonl",
      held_observer(9n,phase,prefix ++ ".marker",token(nonce,mode,phase)))
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,1,"FAIL child missed requested hold and returned snapshot " ++ snapshot)

def marker_closed(got: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,result) = got
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))

def file_text(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    read : File & Result<&1,&1,U32 & String,String> <- File.read(file,4096)
    marker_closed(read)

def log_phase(+path: String,phase: Store.ImportPhase) -> IO(Unit):
  Store.write_text(path,"a",Store.phase_name(phase) ++ "\n")

def logged_observer(fuel: Nat,+path: String) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        log_phase(path,phase)
        return logged_observer(rest,path)}

def callback_control() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/publication-control.sqlite")
    Store.write_text("publication-control.jsonl","w",fixture("newcapture"))
    Store.write_text("publication-control.phases","w","")
    +first : String <- Store.import_observed(db,"codex","publication-control.jsonl",
      logged_observer(10n,"publication-control.phases"))
    order : String <- file_text("publication-control.phases")
    assert(String.eq(order,"before_transaction\nstaged\nreverified\nsealed\naccepted\nsearch_removed\nlatest_repointed\nbefore_commit\ncommitted\n"),
      "changed capture observes exactly nine ordered publication boundaries")
    Store.write_text("publication-control.phases","w","")
    again : String <- Store.import_observed(db,"codex","publication-control.jsonl",
      logged_observer(10n,"publication-control.phases"))
    assert(String.eq(first,again),"observed unchanged import retains accepted identity")
    unchanged : String <- file_text("publication-control.phases")
    assert(String.eq(unchanged,"before_transaction\nbefore_commit\ncommitted\n"),
      "unchanged capture observes exactly three ordered transaction boundaries")
    IO.try(Unit,Sql.close(db))

def interrupted(result: Result<&1,&1,U32 & String,U32 & (String & String)>,
  marker: String,expected: String,+label: String) -> IO(Unit):
  match result:
    case Fail{(code,error)}:
      do IO<Unit>:
        file : File <- IO.try(File,File.open(marker,"r"))
        read : File & Result<&1,&1,U32 & String,String> <- File.read(file,4096)
        actual : String <- marker_closed(read)
        assert(String.eq(actual,expected),label ++ " exact nonce mode and phase marker confirmed")
        assert(U32.is_eq(code,60),label ++ " owned child killed and reaped by macOS ETIMEDOUT")
    case Done{(code,(out,err))}:
      IO.die(Unit,1,"FAIL " ++ label ++ " expected abrupt interruption; exit " ++ U32.show(code) ++ " " ++ out ++ err)

def run_case(+self: String,+nonce: String,+mode: String,+phase: String) -> IO(Unit):
  +label = mode ++ "/" ++ phase
  +prefix = ".build/publication-" ++ nonce ++ "-" ++ mode ++ "-" ++ phase
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    +baseline : Baseline <- prepare_baseline(mode,db,prefix ++ ".jsonl")
    remember_tables(tables(),db)
    Store.write_text(prefix ++ ".jsonl","w",changed(mode))
    IO.try(Unit,Sql.close(db))
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,["child",mode,phase,nonce,prefix],"",8192,2000)
    interrupted(result,prefix ++ ".marker",token(nonce,mode,phase),label)
    +reopened : U32 <- Store.open(prefix ++ ".sqlite")
    check_integrity(reopened,label ++ " reopened")
    after_interruption(phase,reopened,mode,prefix ++ ".jsonl",baseline,label)
    IO.try(Unit,Sql.close(reopened))

def phases() -> List<&2,String>:
  ["before_transaction","staged","reverified","sealed","accepted","search_removed",
    "latest_repointed","before_commit","committed"]

def run_phases(remaining: List<&2,String>,+self: String,+nonce: String,+mode: String) -> IO(Unit):
  match remaining:
    case []:
      IO.pure(Unit,Unit{})
    case phase <> rest:
      do IO<Unit>:
        run_case(self,nonce,mode,phase)
        run_phases(rest,self,nonce,mode)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    callback_control()
    first : U32 <- IO.try(U32,IO.random_u32())
    second : U32 <- IO.try(U32,IO.random_u32())
    +nonce : String = U32.show(first) ++ "-" ++ U32.show(second)
    run_phases(phases(),self,nonce,"initial")
    run_phases(phases(),self,nonce,"append")
    run_phases(phases(),self,nonce,"rewrite")
    IO.print("Publication crash suite passed: initial/append/rewrite x 9 real transaction boundaries")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{_,Con{"child",Con{mode,Con{phase,Con{nonce,Con{prefix,Nil{}}}}}}}:
      child(mode,phase,nonce,prefix)
    case _:
      IO.die(Unit,2,"Publication crash test expects zero arguments or its owned child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
