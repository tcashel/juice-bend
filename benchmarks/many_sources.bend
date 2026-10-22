import Base
import ./main.bend as Common
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/scoped_reader.bend as Scoped
import ../src/evidence.bend as Evidence

# Run only in a fresh private directory. Generator2 has unique source/session/
# repository identities, alternating providers, and exactly one event per raw
# record. Codex carries explicit root cwd/session_id on every response_item;
# there is no extra session_meta record. Fixture generation and all validation
# are outside operation timers. check mode never calls IO.now.
def check(ok: Bool,message: String) -> IO(Unit):
  Store.checked(ok,"Many-source benchmark: " ++ message)

def clock(enabled: Bool) -> IO(Nat):
  match enabled:
    case True{}: IO.now()
    case False{}: IO.pure(Nat,0n)

def provider(index: U32) -> String:
  Bool.pick(String,U32.is_eq(U32.mod(index,2),0),"claude","codex")

def path(index: U32) -> String:
  "many-source-" ++ U32.show(index) ++ ".jsonl"

def session(index: U32) -> String:
  "many-session-" ++ U32.show(index)

def repository(index: U32) -> String:
  "/synthetic/many/repo-" ++ U32.show(index)

def marker(source: U32,ordinal: U32) -> String:
  "Many source " ++ U32.show(source) ++ " record " ++ U32.show(ordinal) ++ " marker"

def body(+source: U32,+ordinal: U32) -> String:
  marker(source,ordinal) ++ " lemongrid café 中 😀 value " ++
    U32.show(Common.random(U32.add(U32.mul(source,100000),ordinal)))

def call_id(source: U32,ordinal: U32) -> String:
  "many-call-" ++ U32.show(source) ++ "-" ++ U32.show(ordinal)

def common(+source: U32,+ordinal: U32) -> String:
  "\"cwd\":" ++ Json.quote(repository(source)) ++
    Bool.pick(String,String.eq(provider(source),"claude"),",\"sessionId\":",",\"session_id\":") ++
    Json.quote(session(source)) ++ ",\"timestamp\":\"2026-10-" ++
    Common.decimal2(U32.add(U32.mod(ordinal,28),1)) ++ "T12:00:00Z\","

def claude(kind: U32,+source: U32,+ordinal: U32) -> String:
  match kind:
    case 0:
      "\"type\":\"user\",\"message\":{\"content\":" ++ Json.quote(body(source,ordinal)) ++ "}"
    case 1:
      "\"type\":\"assistant\",\"message\":{\"model\":\"synthetic-model\",\"content\":" ++ Json.quote(body(source,ordinal)) ++ "}"
    case 2:
      "\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"id\":" ++
        Json.quote(call_id(source,ordinal)) ++ ",\"input\":{\"file_path\":\"src/example.bend\",\"new_string\":" ++ Json.quote(body(source,ordinal)) ++ "}}]}"
    case _:
      "\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":" ++
        Json.quote(call_id(source,U32.sub(ordinal,1))) ++ ",\"content\":" ++ Json.quote(body(source,ordinal)) ++ "}]}"

def codex(kind: U32,+source: U32,+ordinal: U32) -> String:
  match kind:
    case 2:
      "\"type\":\"function_call\",\"name\":\"apply_patch\",\"call_id\":" ++ Json.quote(call_id(source,ordinal)) ++
        ",\"arguments\":" ++ Json.quote("{\"new_string\":" ++ Json.quote(body(source,ordinal)) ++ "}")
    case 3:
      "\"type\":\"function_call_output\",\"call_id\":" ++ Json.quote(call_id(source,U32.sub(ordinal,1))) ++
        ",\"output\":" ++ Json.quote(body(source,ordinal))
    case _:
      "\"type\":\"message\",\"role\":" ++ Json.quote(Bool.pick(String,U32.is_eq(kind,0),"user","assistant")) ++
        ",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(body(source,ordinal)) ++ "}]"

def record(+source: U32,+ordinal: U32) -> String:
  "{" ++ common(source,ordinal) ++ Bool.pick(String,String.eq(provider(source),"claude"),
    claude(U32.mod(ordinal,4),source,ordinal),
    "\"type\":\"response_item\",\"payload\":{" ++ codex(U32.mod(ordinal,4),source,ordinal) ++ "}") ++ "}\n"

def batch(fuel: Nat,+source: U32,+ordinal: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: record(source,ordinal) ++ batch(rest,source,U32.add(ordinal,1))

def generate(fuel: Nat,+source: U32,+ordinal: U32,+count: U32) -> IO(Unit):
  match fuel:
    case 0n: check(U32.is_eq(count,0),"fixture generation budget exhausted")
    case 1n+rest:
      match count:
        case 0: IO.pure(Unit,Unit{})
        case _:
          +size = U32.min(count,128)
          do IO<Unit>:
            Store.write_text(path(source),"a",batch(U32.to_nat(size),source,ordinal))
            generate(rest,source,U32.add(ordinal,size),U32.sub(count,size))

def absent_result(path: String,result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Fail{_}: IO.pure(Unit,Unit{})
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,2,"Refusing existing benchmark path: " ++ path)

def absent(+path: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent_result(path,result)

def fixtures(fuel: Nat,+index: U32,+count: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        absent(path(index))
        Store.write_text(path(index),"w","")
        generate(783n,index,0,count)
        fixtures(rest,U32.add(index,1),count)

def imports(fuel: Nat,+db: U32,+index: U32) -> IO(List<&2,String>):
  match fuel:
    case 0n: IO.pure(List<&2,String>,[])
    case 1n+rest:
      do IO<List<&2,String>>:
        snapshot : String <- Store.import_file(db,provider(index),path(index))
        later : List<&2,String> <- imports(rest,db,U32.add(index,1))
        return snapshot <> later

def nth(rows: List<&2,String>,index: Nat) -> String:
  match rows index:
    case head <> _ 0n: head
    case _ <> rest 1n+tail: nth(rest,tail)
    case [] _: ""

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    check(String.eq(Store.field(Store.first(rows),0n),expected),label)

def identities(rows: List<&2,String>,+db: U32,+index: U32,+count: U32) -> IO(Unit):
  match rows:
    case []: IO.pure(Unit,Unit{})
    case +snapshot <> rest:
      do IO<Unit>:
        scalar(db,"SELECT count(*) FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.id=s.latest AND p.generation=g.id WHERE p.id=? AND s.provider=? AND p.records=? AND p.accepted=1",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Text{provider(index)},Sql.Cell.Integer{U32.show(count)}],"1","source/provider/snapshot identity")
        scalar(db,"SELECT count(*) FROM events WHERE snapshot=? AND session=? AND repository=? AND event=0 AND coverage='complete'",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Text{session(index)},Sql.Cell.Text{repository(index)}],U32.show(count),"independent one-event record and exact session/repository contract")
        identities(rest,db,U32.add(index,1),count)

def typed(+prefix: String,names: List<&2,String>) -> String:
  match names:
    case []: ""
    case +name <> []: prefix ++ name ++ ",typeof(" ++ prefix ++ name ++ ")"
    case +name <> rest: prefix ++ name ++ ",typeof(" ++ prefix ++ name ++ ")," ++ typed(prefix,rest)

def fts_columns(prefix: String) -> String:
  typed(prefix,["rowid","body","arguments","result","tool","snapshot","ordinal","event"])

def event_columns(prefix: String) -> String:
  typed(prefix,["ordinal","event","role","body","tool","call_id","arguments","result","repository","session","timestamp","model","usage","parent","coverage"])

def source_select() -> String:
  "SELECT " ++ typed("s.",["id","provider","locator","latest"]) ++ "," ++
    typed("g.",["id","source"]) ++ "," ++ typed("p.",["id","generation","extent","checkpoint","checkpoint_ordinal","records","accepted"]) ++
    "," ++ typed("c.",["version","digest"]) ++
    " FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.id=s.latest AND p.generation=g.id JOIN projection_checks c ON c.snapshot=p.id WHERE s.id<>?"

def equal_queries(+db: U32,+left: String,+right: String,+args: List<&2,Sql.Cell>,+label: String) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM (" ++ left ++ " EXCEPT " ++ right ++ ")",args,"0",label ++ " forward")
    scalar(db,"SELECT count(*) FROM (" ++ right ++ " EXCEPT " ++ left ++ ")",args,"0",label ++ " reverse")

def remember(+db: U32,+source: String,+old: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"CREATE TEMP TABLE many_before_sources AS " ++ source_select(),[Sql.Cell.Integer{source}])
    Store.exec(db,"CREATE TEMP TABLE many_before_search AS SELECT " ++ fts_columns("") ++ " FROM search WHERE snapshot<>?",[Sql.Cell.Integer{old}])
    Store.exec(db,"CREATE TEMP TABLE many_old_events AS SELECT " ++ event_columns("") ++ " FROM events WHERE snapshot=?",[Sql.Cell.Integer{old}])

def quote_result(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{message}: IO.die(String,1,"Benchmark citation failed: " ++ message)

def resolve(+db: U32,citation: String) -> IO(String):
  do IO<String>:
    result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    quote_result(result)

def index_exact(+db: U32,expected: U32) -> IO(Unit):
  +actual = "SELECT " ++ fts_columns("f.") ++ " FROM search f"
  +wanted = "SELECT " ++ fts_columns("e.") ++ " FROM events e JOIN sources s ON s.latest=e.snapshot JOIN snapshots p ON p.id=e.snapshot AND p.accepted=1"
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM search",[],U32.show(expected),"exact current FTS cardinality")
    equal_queries(db,actual,wanted,[],"latest-only exact typed FTS rows")

def search_rows(rows: List<&2,List<&2,Sql.Cell>>,+snapshot: String,+source: U32,+records: U32) -> Bool:
  match rows:
    case []: True{}
    case +row <> rest:
      String.eq(Store.field(row,0n),snapshot) &&
        U32.is_lt(Store.number(Store.field(row,1n)),records) &&
        U32.is_eq(U32.mod(Store.number(Store.field(row,1n)),4),0) &&
        String.eq(Store.field(row,2n),"0") && String.eq(Store.field(row,3n),provider(source)) &&
        String.eq(Store.field(row,4n),"user") && String.eq(Store.field(row,6n),repository(source)) &&
        String.eq(Store.field(row,7n),session(source)) && search_rows(rest,snapshot,source,records)

def search_once(+db: U32,+snapshot: String,+source: U32,+records: U32,+measured: Bool) -> IO(Nat):
  do IO<Nat>:
    start : Nat <- clock(measured)
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"lemongrid",provider(source),repository(source),"user","",100,0)
    end : Nat <- clock(measured)
    check(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(U32.min(100,U32.div(records,4)))) &&
      search_rows(rows,snapshot,source,records),"scoped lexical results retain exact source/provider/session/repository")
    return Nat.sub(end,start)

def search_trials(fuel: Nat,+db: U32,+snapshot: String,+source: U32,+records: U32,+measured: Bool) -> IO(List<&2,Nat>):
  match fuel:
    case 0n: IO.pure(List<&2,Nat>,[])
    case 1n+rest:
      do IO<List<&2,Nat>>:
        elapsed : Nat <- search_once(db,snapshot,source,records,measured)
        later : List<&2,Nat> <- search_trials(rest,db,snapshot,source,records,measured)
        return elapsed <> later

def page_once(+db: U32,+snapshot: String,+source: U32,+records: U32,+measured: Bool) -> IO(Nat):
  +width = U32.min(100,records)
  +offset = U32.sub(records,width)
  do IO<Nat>:
    start : Nat <- clock(measured)
    +text : String <- Scoped.page(db,snapshot,offset,width,Scoped.Scope{provider(source),repository(source),"",""},False{})
    end : Nat <- clock(measured)
    check(String.contains(text,marker(source,offset)) && String.contains(text,marker(source,U32.sub(records,1))) &&
      String.contains(text,"Visible events in this physical range: " ++ U32.show(width) ++ "\n"),"verified late page has every independently expected physical event")
    return Nat.sub(end,start)

def page_trials(fuel: Nat,+db: U32,+snapshot: String,+source: U32,+records: U32,+measured: Bool) -> IO(List<&2,Nat>):
  match fuel:
    case 0n: IO.pure(List<&2,Nat>,[])
    case 1n+rest:
      do IO<List<&2,Nat>>:
        elapsed : Nat <- page_once(db,snapshot,source,records,measured)
        later : List<&2,Nat> <- page_trials(rest,db,snapshot,source,records,measured)
        return elapsed <> later

def finish(+db: U32,+sources: U32,+records: U32,+source_id: String,+old: String,+latest: String,
  old_page: String,citation: String,old_quote: String) -> IO(Unit):
  +total = U32.mul(sources,records)
  do IO<Unit>:
    equal_queries(db,source_select(),"SELECT * FROM many_before_sources",[Sql.Cell.Integer{source_id}],"untouched source/snapshot/header/seal identities")
    equal_queries(db,"SELECT " ++ fts_columns("") ++ " FROM search WHERE snapshot<>?","SELECT * FROM many_before_search",[Sql.Cell.Integer{latest}],"untouched FTS rowids/cells/types")
    equal_queries(db,"SELECT " ++ event_columns("") ++ " FROM events WHERE snapshot=?","SELECT * FROM many_old_events",[Sql.Cell.Integer{old}],"old target event cells/types")
    scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],U32.show(U32.add(sources,1)),"only target gains an accepted snapshot")
    scalar(db,"SELECT count(*) FROM generations",[],U32.show(sources),"append retains every generation")
    scalar(db,"SELECT count(*) FROM raw",[],U32.show(U32.add(total,16)),"only16 new raw records retained")
    scalar(db,"SELECT count(*) FROM events",[],U32.show(U32.add(U32.add(total,records),16)),"historical target events remain retained")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw AND a.ordinal=b.ordinal WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],U32.show(records),"all old target raw occurrences remain shared")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{old}],"0","historical target events excluded from FTS")
    index_exact(db,U32.add(total,16))
    current_page : String <- Store.page(db,old,U32.sub(records,U32.min(records,100)),100)
    current_quote : String <- resolve(db,citation)
    check(String.eq(current_page,old_page) && String.eq(current_quote,old_quote),"saved target page and exact citation remain unchanged")
    old_valid : Bool <- Store.projection_valid(db,old)
    new_valid : Bool <- Store.projection_valid(db,latest)
    check(old_valid && new_valid,"old/new target event seals independently verify")
    scalar(db,"PRAGMA quick_check",[],"ok","SQLite integrity")
    scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0","foreign-key integrity")
    IO.print("{\"preservation_checks_passed\":true,\"untouched_sources\":" ++ U32.show(U32.sub(sources,1)) ++
      ",\"old_target_page_and_citation_exact\":true,\"current_search_events\":" ++ U32.show(U32.add(total,16)) ++ "}")

def run(+sources: U32,+records: U32,+measured: Bool) -> IO(Unit):
  +middle = U32.div(sources,2)
  do IO<Unit>:
    check(U32.is_ge(sources,4) && U32.is_le(sources,100) && U32.is_ge(records,20) && U32.is_le(records,25000) &&
      U32.is_eq(U32.mod(records,4),0) && U32.is_le(U32.mul(sources,records),100000),"bounds:4..100 sources,20..25000 records divisible by4,total<=100000")
    absent("many-library.sqlite")
    absent("many-library.sqlite-wal")
    absent("many-library.sqlite-shm")
    fixtures(U32.to_nat(sources),0,records)
    IO.print("{\"benchmark\":\"many-sources-v1\",\"seed\":1337,\"sources\":" ++ U32.show(sources) ++
      ",\"raw_records_per_source\":" ++ U32.show(records) ++ ",\"raw_records_before\":" ++ U32.show(U32.mul(sources,records)) ++
      ",\"normalized_events_per_raw_record\":1,\"providers\":[\"claude\",\"codex\"],\"target_source_index\":" ++ U32.show(middle) ++
      ",\"timing_enabled\":" ++ Bool.pick(String,measured,"true","false") ++ ",\"setup_and_validation_outside_timers\":true}")
    +db : U32 <- Store.open("many-library.sqlite")
    importing : Nat <- clock(measured)
    +snapshots : List<&2,String> <- imports(U32.to_nat(sources),db,0)
    imported : Nat <- clock(measured)
    Common.measure("first_import_all_sources",Nat.sub(imported,importing))
    identities(snapshots,db,0,records)
    scalar(db,"SELECT count(*) FROM sources",[],U32.show(sources),"exact independent source count")
    scalar(db,"SELECT count(DISTINCT session) FROM events",[],U32.show(sources),"sessions never merge across sources/providers")
    index_exact(db,U32.mul(sources,records))
    +old : String = nth(snapshots,U32.to_nat(middle))
    +last : String = nth(snapshots,U32.to_nat(U32.sub(sources,1)))
    refreshing : Nat <- clock(measured)
    unchanged : String <- Store.import_file(db,provider(U32.sub(sources,1)),path(U32.sub(sources,1)))
    refreshed : Nat <- clock(measured)
    check(String.eq(unchanged,last),"last-source unchanged refresh retains snapshot identity")
    Common.measure("last_source_unchanged",Nat.sub(refreshed,refreshing))
    source_rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT g.source FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=?",[Sql.Cell.Integer{old}],1)
    +source_id : String = Store.field(Store.first(source_rows),0n)
    +old_page : String <- Store.page(db,old,U32.sub(records,U32.min(records,100)),100)
    verified : Evidence.Verified <- Evidence.read_record(db,old,U32.sub(records,1))
    +citation : String = Evidence.citation(verified,0)
    old_quote : String <- resolve(db,citation)
    remember(db,source_id,old)
    generate(1n,middle,records,16)
    appending : Nat <- clock(measured)
    +latest : String <- Store.import_file(db,provider(middle),path(middle))
    appended : Nat <- clock(measured)
    check(Bool.not(String.eq(old,latest)),"middle-source append creates an immutable snapshot")
    Common.measure("middle_source_append_16",Nat.sub(appended,appending))
    first_search : Nat <- search_once(db,latest,middle,U32.add(records,16),measured)
    Common.measure("first_scoped_search_after_append",first_search)
    searches : List<&2,Nat> <- search_trials(5n,db,latest,middle,U32.add(records,16),measured)
    Common.summarize("warm_scoped_search",searches)
    first_page : Nat <- page_once(db,latest,middle,U32.add(records,16),measured)
    Common.measure("first_scoped_late_page",first_page)
    pages : List<&2,Nat> <- page_trials(5n,db,latest,middle,U32.add(records,16),measured)
    Common.summarize("warm_scoped_late_page",pages)
    finish(db,sources,records,source_id,old,latest,old_page,citation,old_quote)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"benchmark_complete\":true,\"timing_enabled\":" ++ Bool.pick(String,measured,"true","false") ++ "}")

def parsed(+mode: String,left: Maybe<&2,U32>,right: Maybe<&2,U32>) -> IO(Unit):
  match left right:
    case Some{sources} Some{records}:
      do IO<Unit>:
        check(String.eq(mode,"check") || String.eq(mode,"run"),"mode must be check or run")
        run(sources,records,String.eq(mode,"run"))
    case _ _: IO.die(Unit,2,"Counts must be canonical U32 decimals")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case _ <> []: run(100,1000,True{})
    case _ <> "check" <> []: run(4,24,False{})
    case _ <> "run" <> []: run(100,1000,True{})
    case _ <> mode <> sources <> records <> []:
      parsed(mode,Domain.parse_u32(sources),Domain.parse_u32(records))
    case _: IO.die(Unit,2,"usage: many-sources [check|run [SOURCES RECORDS_PER_SOURCE]]")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
