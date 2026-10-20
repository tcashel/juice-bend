import Base
import ../src/activity_reader.bend as Reader
import ../src/tool_activity.bend as Activity
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/scoped_reader.bend as Scoped
import ../src/maintenance.bend as Maintenance
import ../src/evidence.bend as Evidence
import ../src/providers.bend as Providers
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def need(-A: Kind(&2),result: Result<&2,&2,String,A>) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{message}:
      IO.die(A,1,"FAIL " ++ message)

def failed(-A: Kind(&2),result: Result<&2,&2,String,A>,expected: String) -> Bool:
  match result:
    case Fail{message}:
      String.contains(message,expected)
    case Done{_}:
      False{}

def all() -> Scoped.Scope:
  Scoped.Scope{"","","",""}

def scope() -> Scoped.Scope:
  Scoped.Scope{"claude","/synthetic/a","","2026-10-02"}

def call(id: String,text: String) -> String:
  "{\"type\":\"tool_use\",\"name\":\"Bash\",\"id\":" ++ Json.quote(id) ++ ",\"input\":{\"command\":" ++ Json.quote(text) ++ "}}"

def result(id: String,text: String) -> String:
  "{\"type\":\"tool_result\",\"tool_use_id\":" ++ Json.quote(id) ++ ",\"content\":" ++ Json.quote(text) ++ "}"

def record(role: String,repo: String,time: String,content: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"timestamp\":" ++ Json.quote(time) ++ ",\"sessionId\":\"activity-actor\",\"message\":{\"content\":[" ++ content ++ "]}}\n"

def fixtures() -> String:
  record("assistant","/synthetic/a","2026-10-02T00:00:00Z","{\"type\":\"text\",\"text\":\"ordinary chat\"}," ++ call("first","visible argument café 🙂")) ++
    record("user","/synthetic/a","2026-10-03T00:00:00Z",result("first","visible result")) ++
    record("assistant","/synthetic/b","2026-10-03T00:00:00Z",call("other","excluded other-repository arguments")) ++
    record("user","/synthetic/b","2026-10-03T00:00:00Z",result("other","excluded other-repository result")) ++
    record("assistant","/synthetic/a","2026-10-01T23:00:00Z",call("old","excluded old-date arguments")) ++
    record("user","/synthetic/a","unknown",result("old","excluded invalid-date result"))

def activity(page: Reader.Page) -> Activity.Page:
  Reader.Page{_,_,_,_,_,_,_,_,_,_,_,activity} = page
  activity

def activity_rows(page: Activity.Page) -> List<&2,Activity.Row>:
  Activity.Page{rows,_} = page
  rows

def rows(page: Reader.Page) -> List<&2,Activity.Row>:
  activity_rows(activity(page))

def first(items: List<&2,Activity.Row>) -> Maybe<&2,Activity.Row>:
  List.head(&2,Activity.Row,items)

def first_record_value(item: Maybe<&2,Activity.Row>) -> Providers.Record:
  match item:
    case Some{Activity.Row{Activity.Occurrence{_,record},_,_}}:
      record
    case None{}:
      Providers.ProviderEvent{"","","","","","","","","","","","",""}

def first_record(page: Reader.Page) -> Providers.Record:
  first_record_value(first(rows(page)))

def first_citation_value(item: Maybe<&2,Activity.Row>) -> String:
  match item:
    case Some{Activity.Row{Activity.Occurrence{citation,_},_,_}}:
      Activity.descriptor_text(citation)
    case None{}:
      ""

def first_citation(page: Reader.Page) -> String:
  first_citation_value(first(rows(page)))

def activity_counts(page: Activity.Page) -> String:
  Activity.Page{_,Activity.Stats{events,calls,results,pairs,errors,coverage,unpaired}} = page
  String.join([U32.show(events),U32.show(calls),U32.show(results),U32.show(pairs),U32.show(errors),U32.show(coverage),U32.show(unpaired)],"|")

def counts(page: Reader.Page) -> String:
  activity_counts(activity(page))

def metadata(page: Reader.Page) -> String:
  Reader.Page{_,_,_,_,_,total,start,requested,selected,verified,_,_} = page
  String.join([U32.show(total),U32.show(start),U32.show(requested),U32.show(selected),U32.show(verified)],"|")

def read(+db: U32,snapshot: String,start: U32,count: U32,scope: Scoped.Scope) -> IO(Reader.Page):
  do IO<Reader.Page>:
    result : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,start,count,scope)
    need(Reader.Page,result)

def rendered(page: Reader.Page) -> IO(String):
  need(String,Reader.render(page))

def basic(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +page : Reader.Page <- read(db,snapshot,0,100,scope())
    +text : String <- rendered(page)
    assert(String.eq(counts(page),"3|1|1|1|0|0|0"),"raw contextualized scoped events form one pair with the ordinary text counted only as selected input")
    assert(String.eq(metadata(page),"6|0|100|6|6"),"total records requested range selected count and verified count remain distinct")
    assert(String.contains(text,"visible argument") && String.contains(text,"visible result") &&
      Bool.not(String.contains(text,"excluded")),"repository and date scope excludes payloads before pairing and rendering")
    assert(String.contains(text,"Frozen scope: {\"provider\":\"claude\",\"repository\":\"/synthetic/a\",\"role\":\"\",\"after\":\"2026-10-02\"}") &&
      String.contains(text,"Source: ") && String.contains(text,"Generation: ") && String.contains(text,"Captured extent bytes:"),"rendered header includes immutable identity and exact frozen scope")
    assert(String.contains(text,"complete snapshot were not reverified"),"selected raw verification is not claimed as whole-snapshot verification")
    +citation : String = first_citation(page)
    assert(String.contains(citation,"\"record\":\"0\"") && String.contains(citation,"\"event\":\"1\""),"filtered activity retains original event ordinal after preceding ordinary text")
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    source : String <- need(String,resolved)
    assert(String.contains(source,"visible argument"),"activity citation resolves through the production retained-evidence reader")
    +only_results : Reader.Page <- read(db,snapshot,0,100,Scoped.Scope{"claude","/synthetic/a","tool","2026-10-02"})
    result_text : String <- rendered(only_results)
    assert(String.eq(counts(only_results),"1|0|1|0|0|0|1") && Bool.not(String.contains(result_text,"visible argument")),"role-excluded calls cannot pair or leak arguments into a visible result")
    +only_calls : Reader.Page <- read(db,snapshot,0,100,Scoped.Scope{"claude","/synthetic/a","assistant","2026-10-02"})
    call_text : String <- rendered(only_calls)
    assert(String.eq(counts(only_calls),"2|1|0|0|0|0|1") && Bool.not(String.contains(call_text,"visible result")),"role-excluded results remain unavailable rather than enriching a visible call")
    +mismatch : Reader.Page <- read(db,snapshot,0,100,Scoped.Scope{"codex","","",""})
    assert(String.eq(counts(mismatch),"0|0|0|0|0|0|0") && String.eq(metadata(mismatch),"6|0|100|6|0"),"provider mismatch exposes no events and does not claim raw verification")
    +eof : Reader.Page <- read(db,snapshot,6,40,all())
    assert(String.eq(metadata(eof),"6|6|40|0|0") && String.eq(counts(eof),"0|0|0|0|0|0|0"),"EOF returns an empty selected range without changing requested count")
    +beyond : Reader.Page <- read(db,snapshot,4294967295,40,all())
    assert(String.eq(metadata(beyond),"6|4294967295|40|0|0") && String.eq(counts(beyond),"0|0|0|0|0|0|0"),"range beyond EOF remains empty without U32 cursor overflow")
    +short : Reader.Page <- read(db,snapshot,5,40,all())
    assert(String.eq(metadata(short),"6|5|40|1|1"),"late final range clamps physical count exactly at EOF")
    Store.exec(db,"UPDATE events SET body='forged projection text',arguments='forged arguments',result='forged result',repository='/synthetic/a',role='tool',timestamp='2099-01-01' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    projected : Reader.Page <- read(db,snapshot,0,100,scope())
    original : String <- rendered(projected)
    assert(String.eq(text,original),"mutated SQL event payloads and scope fields cannot alter verified activity")

def transaction_tests(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"CREATE TABLE activity_test_owner(value TEXT)",[])
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"INSERT INTO activity_test_owner VALUES('pending')",[])
    refused : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,0,1,all())
    assert(failed(Reader.Page,refused,"transaction start failed"),"preexisting caller transaction is refused explicitly")
    +inside : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM activity_test_owner",[],1)
    assert(String.eq(Store.field(Store.first(inside),0n),"1"),"transaction-start refusal does not roll back caller work")
    +other : U32 <- Store.open(".build/activity-reader.sqlite")
    unseen : List<&2,List<&2,Sql.Cell>> <- Store.q(other,"SELECT count(*) FROM activity_test_owner",[],1)
    assert(String.eq(Store.field(Store.first(unseen),0n),"0"),"transaction-start refusal does not commit caller work")
    IO.try(Unit,Sql.close(other))
    Store.exec(db,"ROLLBACK",[])
    page : Reader.Page <- read(db,snapshot,0,1,all())
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"successful adapter read closes only its own transaction")
    invalid : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,0,101,all())
    assert(failed(Reader.Page,invalid,"1..100"),"physical record count above100 is rejected rather than silently clamped")
    zero : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,0,0,all())
    assert(failed(Reader.Page,zero,"1..100"),"zero record request is rejected explicitly")
    bad_scope : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,0,1,Scoped.Scope{"","","","2026-02-30"})
    assert(failed(Reader.Page,bad_scope,"valid frozen scope"),"invalid date scope is rejected before reading")
    bad_snapshot : Result<&2,&2,String,Reader.Page> <- Reader.read(db,"latest",0,1,all())
    assert(failed(Reader.Page,bad_snapshot,"immutable positive"),"mutable latest alias cannot enter the pinned activity reader")

def removed(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  Store.checked(U32.is_eq(code,0),"Synthetic source removal failed")

def remove(path: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--",path],"",1024,2000))
    removed(result)

def retained(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("pinned.jsonl","w",record("assistant","/synthetic/a","2026-10-02T00:00:00Z",call("append","retained argument")))
    +old : String <- Store.import_file(db,"claude","pinned.jsonl")
    +before : Reader.Page <- read(db,old,0,40,all())
    +before_text : String <- rendered(before)
    Store.write_text("pinned.jsonl","a",record("user","/synthetic/a","2026-10-03T00:00:00Z",result("append","appended result")))
    +new : String <- Store.import_file(db,"claude","pinned.jsonl")
    old_again : Reader.Page <- read(db,old,0,40,all())
    old_text : String <- rendered(old_again)
    assert(String.eq(before_text,old_text) && String.eq(counts(before),"1|1|0|0|0|0|1"),"old snapshot never acquires an appended result or changed page metadata")
    remove("pinned.jsonl")
    +captured : Reader.Page <- read(db,new,0,40,all())
    assert(String.eq(counts(captured),"2|1|1|1|0|0|0"),"retained call and appended result still pair after original source deletion")
    +text : String <- rendered(captured)
    assert(String.contains(text,"retained argument") && String.contains(text,"appended result"),"activity payloads come from owned captured bytes after source deletion")

def codex(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("codex.jsonl","w",
      "{\"type\":\"session_meta\",\"payload\":{\"id\":\"codex-activity\",\"cwd\":\"/synthetic/codex\"}}\n" ++
      "{\"type\":\"turn_context\",\"payload\":{\"model\":\"recorded-codex-model\"}}\n" ++
      "{\"type\":\"response_item\",\"timestamp\":\"2026-10-03T00:00:00Z\",\"payload\":{\"type\":\"function_call\",\"name\":\"exec_command\",\"call_id\":\"codex-call\",\"arguments\":\"exact args  \\n\"}}\n" ++
      "{\"type\":\"response_item\",\"timestamp\":\"2026-10-03T00:00:01Z\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"codex-call\",\"output\":\"\"}}\n")
    +snapshot : String <- Store.import_file(db,"codex","codex.jsonl")
    +page : Reader.Page <- read(db,snapshot,2,2,Scoped.Scope{"codex","/synthetic/codex","","2026-10-02"})
    +event : Providers.Record = first_record(page)
    assert(String.eq(counts(page),"2|1|1|1|0|0|0") && String.eq(Providers.arguments(event),"exact args  \n"),"late Codex activity pairs an empty result using retained incoming context")
    assert(String.eq(Providers.session(event),"codex-activity") && String.eq(Providers.repository(event),"/synthetic/codex") &&
      String.eq(Providers.model(event),"recorded-codex-model"),"late adapter uses the production contextualizer for inherited actor repository and model")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=2",[Sql.Cell.Integer{snapshot}])
    missing : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,2,2,all())
    assert(failed(Reader.Page,missing,"Verified rebuild needed"),"missing incoming checkpoint explicitly requests rebuild instead of guessing context")
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"ordinary context error closes the adapter-owned transaction")
    Maintenance.rebuild(db,snapshot)
    restored : Reader.Page <- read(db,snapshot,2,2,all())
    assert(String.eq(counts(restored),"2|1|1|1|0|0|0"),"verified production rebuild restores bounded activity reads")
    Store.exec(db,"UPDATE snapshot_context SET version='legacy' WHERE snapshot=? AND ordinal=2",[Sql.Cell.Integer{snapshot}])
    stale : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,2,2,all())
    assert(failed(Reader.Page,stale,"Verified rebuild needed"),"stale checkpoint version cannot silently reuse actor context")

def repeat(count: Nat,+text: String) -> String:
  match count:
    case 0n:
      ""
    case 1n+n:
      text ++ repeat(n,text)

def many_calls(count: Nat,+index: U32) -> String:
  match count:
    case 0n:
      ""
    case 1n+0n:
      call("id-" ++ U32.show(index),"bounded")
    case 1n+n:
      call("id-" ++ U32.show(index),"bounded") ++ "," ++ many_calls(n,U32.inc(index))

def budget_tests(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("event-budget.jsonl","w",record("assistant","/synthetic/a","",many_calls(257n,0)))
    +events : String <- Store.import_file(db,"claude","event-budget.jsonl")
    too_many : Result<&2,&2,String,Reader.Page> <- Reader.read(db,events,0,1,all())
    assert(failed(Reader.Page,too_many,"exceeds 256 events"),"single verified physical record cannot bypass selected event budget")
    Store.write_text("byte-budget.jsonl","w",record("assistant","/synthetic/a","",call("a",repeat(210000n,"x"))) ++
      record("assistant","/synthetic/a","",call("b",repeat(210000n,"y"))) ++
      record("assistant","/synthetic/a","",call("c",repeat(210000n,"z"))))
    +bytes : String <- Store.import_file(db,"claude","byte-budget.jsonl")
    too_large : Result<&2,&2,String,Reader.Page> <- Reader.read(db,bytes,0,3,all())
    assert(failed(Reader.Page,too_large,"524288 UTF-8 bytes"),"multiple legal raw records cannot bypass cumulative selected UTF-8 budget")
    +small : Reader.Page <- read(db,bytes,0,1,all())
    assert(Nat.is_gt(String.length(Providers.arguments(first_record(small))),210000n),"smaller bounded range retains the complete large tool payload")
    filtered : Reader.Page <- read(db,bytes,0,3,Scoped.Scope{"","","tool",""})
    assert(String.eq(counts(filtered),"0|0|0|0|0|0|0"),"excluded payloads do not consume selected budgets or leak into activity")
    Store.write_text("unsupported.jsonl","w","{malformed\n" ++ repeat(270000n,"x") ++ "\n")
    +unsupported : String <- Store.import_file(db,"claude","unsupported.jsonl")
    +coverage : Reader.Page <- read(db,unsupported,0,100,all())
    +text : String <- rendered(coverage)
    assert(String.contains(text,"malformed") && String.contains(text,"oversized_record_fragment"),"malformed and oversized retained raw become explicit cited coverage rows")
    Store.write_text("uncertain.jsonl","w",record("assistant","/synthetic/a","",call("42","first") ++ "," ++ call("duplicate","one") ++ "," ++ call("duplicate","two")) ++
      record("user","/synthetic/a","",result("42","") ++ "," ++ result("duplicate","result")))
    +uncertain : String <- Store.import_file(db,"claude","uncertain.jsonl")
    checked : Reader.Page <- read(db,uncertain,0,100,all())
    +rendered_uncertain : String <- rendered(checked)
    assert(String.contains(rendered_uncertain,"raw field type is unavailable") && String.contains(rendered_uncertain,"Ambiguous in this selected page"),"verified adapter preserves duplicate and normalized-type uncertainty")

def child_result(result: U32 & (String & String),expected: String,name: String) -> IO(Unit):
  (code,(_,err)) = result
  assert(U32.is_ne(code,0) && String.contains(err,expected),name)

def output_budget(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("render-budget.jsonl","w",repeat(5n,
      record("user","/synthetic/a","",result("escaped",repeat(40000n,"\0")))))
    +snapshot : String <- Store.import_file(db,"claude","render-budget.jsonl")
    +page : Reader.Page <- read(db,snapshot,0,5,all())
    assert(String.eq(counts(page),"5|0|5|0|0|0|5") &&
      Nat.is_eq(String.length(Providers.result(first_record(page))),40000n),"legal escaped raw records retain complete result payloads below the selected input budget")
    assert(failed(String,Reader.render(page),"1048576-byte worker limit"),"escaped readable activity exceeding final output bound returns an error rather than truncating results")

def child(+self: String,snapshot: String,start: U32,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["read",snapshot,U32.show(start)],"",65536,30000))
    child_result(result,expected,name)

def corruption(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("integrity.jsonl","w",record("assistant","/synthetic/a","",call("c","safe")) ++ record("user","/synthetic/a","",result("c","safe")))
    +snapshot : String <- Store.import_file(db,"claude","integrity.jsonl")
    Store.exec(db,"UPDATE snapshot_context SET session='forged-actor' WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{snapshot}])
    child(self,snapshot,1,"checkpoint integrity mismatch","corrupt incoming actor checkpoint is a hard worker failure")
    Maintenance.rebuild(db,snapshot)
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=1)",[Sql.Cell.Integer{snapshot}])
    child(self,snapshot,1,"integrity","changed raw bytes cannot become tool activity evidence")
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"failed child worker does not leave an active transaction on the parent connection")

def consistent_snapshot(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("consistent.jsonl","w",record("assistant","/synthetic/a","",call("c","original stable bytes")))
    +snapshot : String <- Store.import_file(db,"claude","consistent.jsonl")
    owned : Result<&2,&2,String,Unit> <- Reader.transaction(db)
    need(Unit,owned)
    +header : Maintenance.Header <- Maintenance.header(db,snapshot)
    +other : U32 <- Store.open(".build/activity-reader.sqlite")
    Store.exec(other,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    IO.try(Unit,Sql.close(other))
    result : Result<&2,&2,String,Reader.Page> <- Reader.read_header(db,snapshot,0,1,all(),header)
    +page : Reader.Page <- need(Reader.Page,result)
    Store.exec(db,"ROLLBACK",[])
    assert(String.contains(Providers.arguments(first_record(page)),"original stable bytes"),"production read helper keeps raw checkpoint and metadata in the established SQLite read snapshot during concurrent writes")
    child(self,snapshot,0,"integrity","subsequent owned transaction sees corruption committed by the second connection")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/activity-reader.sqlite")
    Store.write_text("activity.jsonl","w",fixtures())
    +snapshot : String <- Store.import_file(db,"claude","activity.jsonl")
    basic(db,snapshot)
    transaction_tests(db,snapshot)
    retained(db)
    codex(db)
    budget_tests(db)
    output_budget(db)
    corruption(db,self)
    consistent_snapshot(db,self)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "read" <> snapshot <> start <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/activity-reader.sqlite")
        result : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,Store.number(start),1,all())
        page : Reader.Page <- need(Reader.Page,result)
        text : String <- rendered(page)
        IO.print(text)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Invalid synthetic activity reader arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
