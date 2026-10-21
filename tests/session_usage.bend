import Base
import ../src/session_usage.bend as Session
import ../src/session_usage_counts.bend as Counts
import ../src/session_usage_claude.bend as Claude
import ../src/session_usage_codex.bend as Codex
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need(-A: Kind(&2),result: Result<&2,&2,Session.Failure,A>) -> IO(A):
  match result:
    case Done{value}: IO.pure(A,value)
    case Fail{Session.Failure{code,message}}: IO.die(A,1,"FAIL " ++ code ++ ": " ++ message)

def need_run(result: Result<&2,&1,Session.Failure,Session.Run>) -> IO(Session.Run):
  match result:
    case Done{run}: IO.pure(Session.Run,run)
    case Fail{Session.Failure{code,message}}: IO.die(Session.Run,1,"FAIL begin " ++ code ++ ": " ++ message)

def drive(fuel: Nat,result: Session.Step) -> IO(Session.Report):
  match fuel result:
    case _ Session.Finished{report}: IO.pure(Session.Report,report)
    case _ Session.Failed{Session.Failure{code,message}}: IO.die(Session.Report,1,"FAIL scan " ++ code ++ ": " ++ message)
    case 1n+rest Session.More{run,_}:
      do IO<Session.Report>:
        next : Session.Step <- Session.step(run)
        drive(rest,next)
    case 0n Session.More{run,_}:
      do IO<Session.Report>:
        closed : Result<&2,&2,Session.Failure,Unit> <- Session.cancel(run)
        IO.die(Session.Report,1,"FAIL test step budget exhausted")

def scan(+db: U32,snapshot: String,limits: Session.Limits) -> IO(Session.Report):
  do IO<Session.Report>:
    started : Result<&2,&1,Session.Failure,Session.Run> <- Session.begin(db,snapshot,limits)
    run : Session.Run <- need_run(started)
    first : Session.Step <- Session.step(run)
    drive(10000n,first)

def initial(+db: U32,snapshot: String) -> IO(Session.Run):
  do IO<Session.Run>:
    result : Result<&2,&1,Session.Failure,Session.Run> <- Session.begin(db,snapshot,Session.defaults())
    need_run(result)

def refused(result: Result<&2,&1,Session.Failure,Session.Run>,expected: String,label: String) -> IO(Unit):
  match result:
    case Fail{Session.Failure{code,_}}: assert(String.eq(code,expected),label)
    case Done{run}:
      do IO<Unit>:
        closed : Result<&2,&2,Session.Failure,Unit> <- Session.cancel(run)
        assert(False{},label)

def error_drive(fuel: Nat,result: Session.Step,expected: String,label: String) -> IO(Unit):
  match fuel result:
    case _ Session.Failed{Session.Failure{code,_}}: assert(String.eq(code,expected),label)
    case _ Session.Finished{_}: assert(False{},label)
    case 1n+rest Session.More{run,_}:
      do IO<Unit>:
        next : Session.Step <- Session.step(run)
        error_drive(rest,next,expected,label)
    case 0n Session.More{run,_}:
      do IO<Unit>:
        closed : Result<&2,&2,Session.Failure,Unit> <- Session.cancel(run)
        assert(False{},label)

def failing(+db: U32,snapshot: String,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    run : Session.Run <- initial(db,snapshot)
    next : Session.Step <- Session.step(run)
    error_drive(1000n,next,code,label)

def available_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,db: U32,label: String) -> IO(Unit):
  match result:
    case Fail{_}: assert(False{},label)
    case Done{_}:
      do IO<Unit>:
        Store.exec(db,"ROLLBACK",[])
        assert(True{},label)

def available(+db: U32,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"BEGIN DEFERRED",[],0)
    available_result(result,db,label)

def json_result(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def json(text: String) -> Json.Json:
  json_result(Json.parse(text))

def row(id: String,session: String,input: String,output: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":" ++ Json.quote(session) ++
    ",\"cwd\":\"/synthetic/session-usage\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"id\":" ++ Json.quote(id) ++
    ",\"model\":\"synthetic-model\",\"content\":\"retained usage\",\"usage\":{\"input_tokens\":" ++ input ++
    ",\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":" ++ output ++ "}}}\n"

def series(fuel: Nat,+ordinal: U32,+session: String) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: row(U32.show(ordinal),session,"10","1") ++ series(rest,U32.inc(ordinal),session)

def get_claude(report: Session.Report) -> Claude.Report:
  Session.Report{_,_,_,_,_,_,_,_,_,value} = report
  match value:
    case Session.ClaudeSummary{value}: value
    case _: Claude.report(Claude.new(""))

def get_codex(report: Session.Report) -> Codex.Report:
  Session.Report{_,_,_,_,_,_,_,_,_,value} = report
  match value:
    case Session.CodexSummary{value}: value
    case _: Codex.report(Codex.new())

def totals(value: Claude.Report) -> Counts.Counters:
  Claude.Report{_,_,_,counts,_,_,_,_,_,_,_,_,_,_} = value
  counts

def own(value: Claude.Report) -> Counts.Counters:
  Claude.Report{_,_,_,_,counts,_,_,_,_,_,_,_,_,_} = value
  counts

def copied(value: Claude.Report) -> Counts.Counters:
  Claude.Report{_,_,_,_,_,counts,_,_,_,_,_,_,_,_} = value
  counts

def unknown(value: Claude.Report) -> Counts.Counters:
  Claude.Report{_,_,_,_,_,_,counts,_,_,_,_,_,_,_} = value
  counts

def input_output(value: Counts.Counters,input: String,output: String) -> Bool:
  Counts.Counters{a,_,_,_,b} = value
  String.eq(a,input) && String.eq(b,output)

def complete(report: Session.Report) -> Bool:
  Session.Report{_,_,_,_,complete,_,_,_,_,_} = report
  complete

def accounted(report: Session.Report) -> Bool:
  Session.Report{_,_,_,_,_,buckets,attributed,_,_,_} = report
  buckets && attributed

def processed(report: Session.Report) -> U32:
  Session.Report{_,_,records,_,_,_,_,_,_,_} = report
  records

def cap(report: Session.Report) -> Session.Capture:
  Session.Report{capture,_,_,_,_,_,_,_,_,_} = report
  capture

def witness_count(report: Session.Report) -> Nat:
  Session.Report{_,_,_,_,_,_,_,_,Session.Coverage{_,_,_,_,items},_} = report
  List.length(&2,Session.Witness,items)

def report_text(report: Session.Report) -> IO(String):
  need(String,Session.render(report))

def scalar(+db: U32,sql: String,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),label)

def arithmetic() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(Counts.add("9007199254740993","7"),"9007199254741000"),"whole-capture counters preserve integers above2^53")
    assert(String.eq(Counts.subtract("1000000000000000000000000","1"),"999999999999999999999999"),"counter subtraction is exact beyond machine words")
    assert(String.is_empty(Counts.number(Json.JString{"7"})) && String.is_empty(Counts.number(Json.JNumber{"-1"})) &&
      String.is_empty(Counts.number(Json.JNumber{"1.5"})) && String.is_empty(Counts.number(Json.JNumber{"1e3"})),
      "counter decoder never coerces strings negative fractional or exponent values")
    assert(String.is_empty(Counts.number(Json.JNumber{String.repeat("9",65n)})),"65-digit counter exceeds explicit per-observation arithmetic bound")
    assert(String.eq(Counts.number(Json.JNumber{String.repeat("9",64n)}),String.repeat("9",64n)),"64-digit recorded counter stays exact")
    assert(String.eq(Session.own_session("/synthetic/A.jsonl"),"A") &&
      String.eq(Session.own_session("/synthetic/A/subagents/agent-child.jsonl"),"A"),"retained Claude locator association distinguishes parent directory from child alias")
    assert(Bool.not(Session.limits_valid(Session.Limits{0,1,1,1})) &&
      Bool.not(Session.limits_valid(Session.Limits{1,1,100001,1})) &&
      Bool.not(Session.limits_valid(Session.Limits{1,1,1,67108865})),"zero and excessive bounds are rejected explicitly")

def absent_counts(value: Maybe<&2,Counts.Counters>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def count_fields() -> IO(Unit):
  +usage = json("{\"input_tokens\":10,\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":1,\"cache_creation\":{\"ephemeral_1h_input_tokens\":5}}")
  do IO<Unit>:
    assert(Counts.equal(Counts.claude(usage),Counts.Counters{"10","2","3","3","1"}),
      "valid optional Claude1h split is capped at the recorded creation bucket")
    assert(Counts.claude_split_valid(usage) && Counts.claude_split_valid(json("{}")),
      "absent optional split is unknown without claiming malformed required counters")
    assert(Bool.not(Counts.claude_split_valid(json("{\"cache_creation\":{\"ephemeral_1h_input_tokens\":\"5\"}}"))) &&
      Bool.not(Counts.claude_split_valid(json("{\"cache_creation\":null}"))),
      "present malformed optional split produces explicit coverage loss")
    assert(absent_counts(Counts.codex(Json.JObject{[Json.JField{"input_tokens",Json.JNumber{"10"}},
      Json.JField{"input_tokens",Json.JNumber{"10"}},Json.JField{"cached_input_tokens",Json.JNumber{"2"}},
      Json.JField{"output_tokens",Json.JNumber{"1"}}]})),"constructed duplicate input counter is rejected even when values agree")
    assert(absent_counts(Counts.codex(Json.JObject{[Json.JField{"input_tokens",Json.JNumber{"10"}},
      Json.JField{"cached_input_tokens",Json.JNumber{"2"}},Json.JField{"cached_input_tokens",Json.JNumber{"3"}},
      Json.JField{"output_tokens",Json.JNumber{"1"}}]})),"constructed duplicate cached counter cannot select a convenient value")
    assert(absent_counts(Counts.codex(Json.JObject{[Json.JField{"input_tokens",Json.JNumber{"10"}},
      Json.JField{"cached_input_tokens",Json.JNumber{"2"}},Json.JField{"output_tokens",Json.JNumber{"1"}},
      Json.JField{"output_tokens",Json.JNull{}}]})),"constructed duplicate output counter remains malformed")
    assert(Bool.not(Counts.complete_claude(Counts.claude(Json.JObject{[
      Json.JField{"input_tokens",Json.JNumber{"10"}},Json.JField{"input_tokens",Json.JNumber{"10"}},
      Json.JField{"cache_read_input_tokens",Json.JNumber{"2"}},Json.JField{"cache_creation_input_tokens",Json.JNumber{"3"}},
      Json.JField{"output_tokens",Json.JNumber{"1"}}]}))),"Claude duplicate required counter remains unknown")

def altered(id: String,session: String,model: String,time: String,usage: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":" ++ session ++ ",\"timestamp\":" ++ time ++
    ",\"message\":{\"id\":" ++ id ++ ",\"model\":" ++ model ++ ",\"content\":\"synthetic\",\"usage\":" ++ usage ++ "}}\n"

def simple_usage() -> String:
  "{\"input_tokens\":10,\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":1}"

def pure_report(result: Claude.Update) -> Claude.Report:
  match result:
    case Claude.Accepted{state,_}: Claude.report(state)
    case Claude.Limited{state,_}: Claude.report(state)

def pure_claude(value: Json.Json) -> Claude.Report:
  pure_report(Claude.observe(value,Claude.new("pure"),1000,16777216))

def keys(value: Claude.Report) -> U32:
  Claude.Report{_,count,_,_,_,_,_,_,_,_,_,_,_,_} = value
  count

def malformed_claude() -> IO(Unit):
  do IO<Unit>:
    assert(U32.is_eq(keys(pure_claude(Json.JObject{[Json.JField{"type",Json.JString{"assistant"}},
      Json.JField{"sessionId",Json.JString{"pure"}},Json.JField{"message",Json.JObject{[
        Json.JField{"id",Json.JString{"a"}},Json.JField{"id",Json.JString{"b"}},
        Json.JField{"usage",json(simple_usage())}]}}]})),0),
      "constructed duplicate Claude message IDs cannot choose a convenient exact dedup key")
    assert(U32.is_eq(keys(pure_claude(Json.JObject{[Json.JField{"type",Json.JString{"assistant"}},
      Json.JField{"sessionId",Json.JString{"pure"}},Json.JField{"message",Json.JObject{[
        Json.JField{"id",Json.JString{"a"}},Json.JField{"usage",json(simple_usage())},
        Json.JField{"usage",json(simple_usage())}]}}]})),0),
      "constructed duplicate Claude usage envelopes cannot select a counter observation")
    assert(input_output(unknown(pure_claude(Json.JObject{[Json.JField{"type",Json.JString{"assistant"}},
      Json.JField{"sessionId",Json.JString{"pure"}},Json.JField{"sessionId",Json.JString{"other"}},
      Json.JField{"message",Json.JObject{[Json.JField{"id",Json.JString{"a"}},
        Json.JField{"usage",json(simple_usage())}]}}]})),"10","1"),
      "constructed duplicate source session IDs preserve observed counts only as unattributed")

def claude_identity(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("unicode.jsonl","w",row(String.repeat("🙂",128n),"unicode","10","1"))
    +snapshot : String <- Store.import_file(db,"claude","unicode.jsonl")
    +exact : Session.Report <- scan(db,snapshot,Session.Limits{1000,1048576,10,565})
    assert(complete(exact) && input_output(totals(get_claude(exact)),"10","1"),
      "512-byte Unicode call key fits the exact565-byte retained descriptor budget")
    +short : Session.Report <- scan(db,snapshot,Session.Limits{1000,1048576,10,564})
    assert(Bool.not(complete(short)) && U32.is_eq(processed(short),0),
      "descriptor bound counts UTF8 bytes including first model hour origin and counter strings")
    Store.write_text("keys.jsonl","w",row("é","keys","10","1") ++ row("é","keys","10","1") ++
      row("42","keys","10","1") ++ row(String.repeat("🙂",129n),"keys","100","100") ++
      altered("42","\"keys\"","\"synthetic-model\"","\"2026-10-20T12:00:00Z\"",simple_usage()))
    keys : String <- Store.import_file(db,"claude","keys.jsonl")
    +distinct : Session.Report <- scan(db,keys,Session.defaults())
    assert(input_output(totals(get_claude(distinct)),"30","3"),
      "exact scalar keys retain distinct combining spellings and valid numeric-string IDs while invalid types stay excluded")
    assert(complete(distinct) && Bool.not(accounted(distinct)),"516-byte and nonstring call IDs leave explicit accounting incompleteness")
    Store.write_text("model.jsonl","w",row("same","model","10","1") ++
      altered("\"same\"","\"model\"","\"changed-model\"","\"2026-10-20T13:00:00Z\"",simple_usage()))
    model : String <- Store.import_file(db,"claude","model.jsonl")
    +changed : Session.Report <- scan(db,model,Session.defaults())
    assert(input_output(unknown(get_claude(changed)),"10","1") && Bool.not(accounted(changed)),
      "later contradictory model cannot silently reassign first-call metadata")
    Store.write_text("time.jsonl","w",row("same","time","10","1") ++
      altered("\"same\"","\"time\"","\"synthetic-model\"","\"2026-10-20T11:00:00Z\"",simple_usage()))
    time : String <- Store.import_file(db,"claude","time.jsonl")
    +earlier : Session.Report <- scan(db,time,Session.defaults())
    assert(input_output(unknown(get_claude(earlier)),"10","1") && Bool.not(accounted(earlier)),
      "later observation with an earlier hour flags the preserved first-hour contradiction")

def codex_usage(input: String,cached: String,output: String) -> String:
  "{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":" ++
    input ++ ",\"cached_input_tokens\":" ++ cached ++ ",\"output_tokens\":" ++ output ++ "}}}}\n"

def report_codex_counts(report: Codex.Report) -> Counts.Counters:
  Codex.Report{_,_,_,_,value,_,_,_,_,_,_,_,_,_} = report
  value

def codex_counts(report: Session.Report) -> Counts.Counters:
  report_codex_counts(get_codex(report))

def codex_capture(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("codex.jsonl","w","{\"type\":\"session_meta\",\"payload\":{\"id\":\"synthetic-codex\",\"source\":\"cli\",\"timestamp\":\"2026-10-20T12:00:00Z\"}}\n" ++
      codex_usage("100","20","5") ++ String.repeat("{\"type\":\"turn_context\",\"payload\":{\"model\":\"synthetic\"}}\n",126n) ++
      codex_usage("240","70","11") ++ codex_usage("240","70","11") ++ codex_usage("90","10","3"))
    snapshot : String <- Store.import_file(db,"codex","codex.jsonl")
    +report : Session.Report <- scan(db,snapshot,Session.defaults())
    assert(complete(report) && accounted(report) && U32.is_eq(processed(report),131),
      "Codex complete retained capture carries counter state across128-record boundaries")
    assert(Counts.equal(codex_counts(report),Counts.Counters{"250","80","","","14"}),
      "actual Codex raw reader counts first total growth duplicate and restart with independent exact expected buckets")
    Store.write_text("reviewer.jsonl","w","{\"type\":\"session_meta\",\"payload\":{\"id\":\"reviewer\",\"source\":{\"subagent\":{\"other\":\"guardian\"}},\"timestamp\":\"2026-10-20T12:00:00Z\"}}\n" ++ codex_usage("100","20","5"))
    reviewer : String <- Store.import_file(db,"codex","reviewer.jsonl")
    report : Session.Report <- scan(db,reviewer,Session.defaults())
    +text : String <- report_text(report)
    assert(String.contains(text,"Codex category: reviewer") && String.contains(text,"separate from coding-session usage"),
      "verified reviewer accounting remains explicitly separate in the full report")

def removed(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),"only the synthetic source fixture is removed")

def pages(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("A.jsonl","w",series(260n,0,"A") ++ row("0","A","10","9"))
    +snapshot : String <- Store.import_file(db,"claude","A.jsonl")
    +report : Session.Report <- scan(db,snapshot,Session.defaults())
    assert(complete(report) && U32.is_eq(processed(report),261),"entire261-record retained capture crosses multiple128-record steps")
    assert(input_output(totals(get_claude(report)),"2600","268"),"late mirror growth merges into its original call across page boundaries")
    assert(input_output(own(get_claude(report)),"2600","268") && accounted(report),"known source-associated usage has independent complete accounting")
    assert(Nat.is_eq(witness_count(report),16n),"whole-session report retains at most16 exact raw witnesses")
    +before : String <- report_text(report)
    assert(String.contains(before,"\"snapshot\":\"" ++ snapshot ++ "\"") &&
      String.contains(before,"\"physical_record\":\"0\""),"summary and raw witnesses bind the immutable capture identity")
    Store.exec(db,"UPDATE events SET usage='forged',session='untrusted'",[])
    Store.write_text("A.jsonl","a",row("0","A","10","12") ++ row("later","A","7","2"))
    +new : String <- Store.import_file(db,"claude","A.jsonl")
    updated : Session.Report <- scan(db,new,Session.defaults())
    assert(input_output(totals(get_claude(updated)),"2607","273"),"appended capture counts only mirror growth and the new call")
    Store.write_text("A.jsonl","w","original source replaced")
    deleted : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--","A.jsonl"],"",1024,2000))
    removed(deleted)
    old : Session.Report <- scan(db,snapshot,Session.defaults())
    after : String <- report_text(old)
    assert(String.eq(before,after),"old snapshot totals and exact report survive append projection tampering original replacement and deletion")
    available(db,"successful final report releases its own read transaction")

def mixed(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("B.jsonl","w",row("copied","A","10","1") ++ row("own","B","7","2") ++ row("copied","A","10","3"))
    snapshot : String <- Store.import_file(db,"claude","B.jsonl")
    +report : Session.Report <- scan(db,snapshot,Session.defaults())
    assert(input_output(totals(get_claude(report)),"17","5"),"copied records remain in capture-deduplicated recorded subtotals")
    assert(input_output(own(get_claude(report)),"7","2") && input_output(copied(get_claude(report)),"10","3"),
      "source-own and copied-session subtotals stay separate")
    Store.write_text("conflict.jsonl","w",row("same","conflict","10","1") ++ row("same","other","8","3"))
    conflicting : String <- Store.import_file(db,"claude","conflict.jsonl")
    +conflict : Session.Report <- scan(db,conflicting,Session.defaults())
    assert(input_output(totals(get_claude(conflict)),"10","3"),"contradictory origin cannot create a second identical call key")
    assert(input_output(unknown(get_claude(conflict)),"10","3") && Bool.not(accounted(conflict)),
      "contradictory call moves all peaks out of source attribution without losing facts")
    Store.write_text("missing.jsonl","w",row("","missing","100","100") ++ row("present","missing","9","2"))
    missing : String <- Store.import_file(db,"claude","missing.jsonl")
    +partial : Session.Report <- scan(db,missing,Session.defaults())
    assert(input_output(totals(get_claude(partial)),"9","2") && complete(partial) && Bool.not(accounted(partial)),
      "missing call ID is explicit accounting incompleteness rather than duplicated guessed usage")

def limits(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("limits.jsonl","w",series(5n,0,"limits"))
    +snapshot : String <- Store.import_file(db,"claude","limits.jsonl")
    +records : Session.Report <- scan(db,snapshot,Session.Limits{2,1073741824,100000,16777216})
    assert(Bool.not(complete(records)) && U32.is_eq(processed(records),2) && Bool.not(accounted(records)),
      "physical record cap reports exact processed prefix and cannot claim complete buckets")
    +partial_text : String <- report_text(records)
    whole : Session.Report <- scan(db,snapshot,Session.defaults())
    +whole_text : String <- report_text(whole)
    assert(String.starts_with(partial_text,"Juice Bend · retained-capture usage\n") &&
      String.starts_with(whole_text,"Juice Bend · retained-capture usage\n") &&
      String.contains(partial_text,"Scan complete: false | processed physical records: 2") &&
      String.contains(whole_text,"Scan complete: true | processed physical records: 5"),
      "complete and limited reports share a neutral heading while the partial scan stays explicitly incomplete")
    +keys : Session.Report <- scan(db,snapshot,Session.Limits{1000000,1073741824,2,16777216})
    assert(Bool.not(complete(keys)) && U32.is_eq(processed(keys),2),"exact-key cap stops before accepting a new untracked call")
    +descriptors : Session.Report <- scan(db,snapshot,Session.Limits{1000000,1073741824,100000,1})
    assert(Bool.not(complete(descriptors)) && U32.is_eq(processed(descriptors),0),"logical descriptor budget refuses whole call rather than truncating identity")
    +bytes : Session.Report <- scan(db,snapshot,Session.Limits{1000000,1,100000,16777216})
    assert(Bool.not(complete(bytes)) && U32.is_eq(processed(bytes),0),"verified-byte cap refuses partial raw record accounting")
    available(db,"all bounded stops release only their owned read transaction")
    run : Session.Run <- initial(db,snapshot)
    canceled : Result<&2,&2,Session.Failure,Unit> <- Session.cancel(run)
    need(Unit,canceled)
    available(db,"explicit cancel releases an owned read transaction")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO settings(key,value) VALUES('caller-marker','uncommitted')",[])
    denied : Result<&2,&1,Session.Failure,Session.Run> <- Session.begin(db,snapshot,Session.defaults())
    refused(denied,"usage_transaction_unavailable","preexisting caller transaction is refused")
    scalar(db,"SELECT value FROM settings WHERE key='caller-marker'","uncommitted","refused begin does not roll back the caller's uncommitted write")
    Store.exec(db,"ROLLBACK",[])
    scalar(db,"SELECT count(*) FROM settings WHERE key='caller-marker'","0","refused begin does not commit the caller's write")
    absent : Result<&2,&1,Session.Failure,Session.Run> <- Session.begin(db,"999999",Session.defaults())
    refused(absent,"usage_not_found","missing immutable capture is explicit")
    available(db,"header failure rolls back the owned read view")

def rejected_begin(result: Result<&2,&1,Session.Failure,Session.Run>,code: String,label: String) -> IO(Unit):
  match result:
    case Fail{Session.Failure{actual,_}}: assert(String.eq(actual,code),label)
    case Done{run}:
      do IO<Unit>:
        next : Session.Step <- Session.step(run)
        error_drive(1000n,next,code,label)

def rejected_capture(+db: U32,snapshot: String,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&1,Session.Failure,Session.Run> <- Session.begin(db,snapshot,Session.defaults())
    rejected_begin(result,code,label)

def restore(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"DELETE FROM records",[])
    Store.exec(db,"DELETE FROM raw",[])
    Store.exec(db,"DELETE FROM snapshots",[])
    Store.exec(db,"INSERT INTO snapshots SELECT * FROM saved_snapshots",[])
    Store.exec(db,"INSERT INTO raw SELECT * FROM saved_raw",[])
    Store.exec(db,"INSERT INTO records SELECT * FROM saved_records",[])

def mutation(+db: U32,+snapshot: String,sql: String,code: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,sql,[])
    rejected_capture(db,snapshot,code,label)
    available(db,label ++ " releases the owned transaction")
    restore(db)

def corrupt_raw(+db: U32,+snapshot: String,ordinals: List<&2,U32>) -> IO(Unit):
  match ordinals:
    case []: IO.pure(Unit,Unit{})
    case +ordinal <> rest:
      do IO<Unit>:
        mutation(db,snapshot,"UPDATE raw SET bytes=zeroblob(n) WHERE ordinal=" ++ U32.show(ordinal),
          "usage_raw_integrity","checksum corruption at physical record" ++ U32.show(ordinal) ++ " cannot hide at a batch boundary")
        corrupt_raw(db,snapshot,rest)

def corruption() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/session-corrupt.sqlite")
    Store.write_text("corrupt.jsonl","w",series(300n,0,"corrupt"))
    +snapshot : String <- Store.import_file(db,"claude","corrupt.jsonl")
    Store.exec(db,"PRAGMA foreign_keys=OFF",[])
    Store.exec(db,"CREATE TEMP TABLE saved_raw AS SELECT * FROM raw",[])
    Store.exec(db,"CREATE TEMP TABLE saved_records AS SELECT * FROM records",[])
    Store.exec(db,"CREATE TEMP TABLE saved_snapshots AS SELECT * FROM snapshots",[])
    corrupt_raw(db,snapshot,[0,127,128,255,256,299])
    mutation(db,snapshot,"UPDATE records SET ordinal=-1 WHERE ordinal=299","usage_map_integrity",
      "negative map key outside the cursor is caught by whole-map guard")
    mutation(db,snapshot,"UPDATE records SET ordinal=299.5 WHERE ordinal=299","usage_map_integrity",
      "REAL map key cannot hide beyond an integer cursor")
    mutation(db,snapshot,"INSERT INTO records SELECT snapshot,300,raw FROM records WHERE ordinal=0","usage_map_integrity",
      "extra mapped row beyond accepted EOF is rejected before scanning")
    mutation(db,snapshot,"DELETE FROM records WHERE ordinal=128","usage_map_integrity",
      "missing map row cannot produce an apparently complete smaller scan")
    mutation(db,snapshot,"UPDATE records SET raw=9223372036854775807 WHERE ordinal=128","usage_raw_integrity",
      "missing raw LEFT JOIN remains a hard failure rather than skipped input")
    mutation(db,snapshot,"UPDATE records SET raw=1.5 WHERE ordinal=128","usage_map_integrity",
      "noninteger mapped raw identity is rejected by the global typed guard")
    mutation(db,snapshot,"UPDATE raw SET generation=9007199254740993 WHERE ordinal=255","usage_raw_integrity",
      "raw generation must match the pinned header exactly")
    mutation(db,snapshot,"UPDATE raw SET ordinal=-1 WHERE ordinal=128","usage_raw_integrity",
      "negative raw ordinal is rejected independently of map order")
    mutation(db,snapshot,"UPDATE raw SET offset=offset+1 WHERE ordinal=256","usage_raw_integrity",
      "carried byte offset validates boundaries between SQL windows")
    mutation(db,snapshot,"UPDATE raw SET complete=2 WHERE ordinal=299","usage_raw_integrity",
      "invalid raw boolean flag is not coerced to truth")
    mutation(db,snapshot,"UPDATE raw SET digest=CAST(digest AS BLOB) WHERE ordinal=128","usage_raw_integrity",
      "digest SQLite type must be TEXT even when bytes would display identically")
    mutation(db,snapshot,"UPDATE raw SET ordinal=128.5 WHERE ordinal=128","usage_raw_integrity",
      "REAL raw quantity is rejected before numeric conversion")
    mutation(db,snapshot,"UPDATE snapshots SET extent=extent+1","usage_raw_integrity",
      "accepted extent must match the final verified byte boundary")
    mutation(db,snapshot,"UPDATE snapshots SET records=300.5","usage_header_integrity",
      "REAL capture record count is rejected before cursor conversion")
    result : Session.Report <- scan(db,snapshot,Session.defaults())
    assert(complete(result),"restored independent raw fixture still completes after all corruption probes")
    Store.exec(db,"CREATE TEMP TABLE raw(wrong INTEGER)",[])
    Store.exec(db,"CREATE TEMP TABLE snapshots(wrong INTEGER)",[])
    Store.exec(db,"CREATE TEMP TABLE generations(wrong INTEGER)",[])
    Store.exec(db,"CREATE TEMP TABLE sources(wrong INTEGER)",[])
    Store.exec(db,"CREATE TEMP TABLE records(wrong INTEGER)",[])
    +shadowed : Session.Report <- scan(db,snapshot,Session.defaults())
    assert(complete(shadowed) && input_output(totals(get_claude(shadowed)),"3000","300"),
      "temporary tables cannot shadow owned main capture identities maps or raw bytes")
    Store.exec(db,"DROP TABLE temp.raw",[])
    Store.exec(db,"DROP TABLE temp.snapshots",[])
    Store.exec(db,"DROP TABLE temp.generations",[])
    Store.exec(db,"DROP TABLE temp.sources",[])
    Store.exec(db,"DROP TABLE temp.records",[])
    Store.exec(db,"ALTER TABLE main.raw RENAME TO missing_raw",[])
    rejected_capture(db,snapshot,"usage_database_error","failed main raw query returns an explicit ordinary database error")
    available(db,"failed raw SQL query releases its owned read transaction")
    Store.exec(db,"ALTER TABLE main.missing_raw RENAME TO raw",[])
    IO.try(Unit,Sql.close(db))

def concurrent_read() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/session-concurrent.sqlite")
    Store.write_text("concurrent.jsonl","w",series(130n,0,"concurrent"))
    +snapshot : String <- Store.import_file(db,"claude","concurrent.jsonl")
    +other : U32 <- Store.open(".build/session-concurrent.sqlite")
    run : Session.Run <- initial(db,snapshot)
    Store.exec(other,"UPDATE raw SET digest='corrupted by isolated second connection' WHERE ordinal=129",[])
    first : Session.Step <- Session.step(run)
    report : Session.Report <- drive(1000n,first)
    assert(input_output(totals(get_claude(report)),"1300","130"),
      "header and later raw windows share one read snapshot across another connection's committed mutation")
    failing(db,snapshot,"usage_raw_integrity","new read transaction sees the second connection's committed late-row corruption")
    available(db,"failed late raw window rolls back its own read view")
    IO.try(Unit,Sql.close(other))
    IO.try(Unit,Sql.close(db))

def raw_write(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(result)

def coverage_shape(report: Session.Report) -> String:
  Session.Report{_,_,_,_,_,_,_,_,Session.Coverage{decoded,malformed,oversized,_,_},_} = report
  U32.show(decoded) ++ "|" ++ U32.show(malformed) ++ "|" ++ U32.show(oversized)

def byte_batches(+db: U32) -> IO(Unit):
  +padding = "{\"type\":\"user\",\"message\":{\"content\":" ++ Json.quote(String.repeat("界",73000n)) ++ "}}\n"
  do IO<Unit>:
    Store.write_text("bytes.jsonl","w",String.repeat(padding,6n) ++ row("call","bytes","13","7"))
    snapshot : String <- Store.import_file(db,"claude","bytes.jsonl")
    +report : Session.Report <- scan(db,snapshot,Session.defaults())
    assert(complete(report) && U32.is_eq(processed(report),7) && input_output(totals(get_claude(report)),"13","7"),
      "actual UTF8 payload budget splits large legal records across windows without losing trailing usage")
    raw_write("malformed.jsonl",List.concat(&2,U32,[Domain.encode("{bad json}\n"),[255,10],
      Domain.encode(String.repeat("x",262145n) ++ "\n" ++ row("valid","malformed","9","4"))]))
    bad : String <- Store.import_file(db,"claude","malformed.jsonl")
    +partial : Session.Report <- scan(db,bad,Session.defaults())
    assert(complete(partial) && Bool.not(accounted(partial)) && String.eq(coverage_shape(partial),"1|2|2"),
      "malformed JSON invalid UTF8 and both oversize fragments stay explicit while the retained extent completes")
    assert(input_output(totals(get_claude(partial)),"9","4"),"valid usage after oversized continuation remains independently readable")
    Store.write_text("empty.jsonl","w","")
    empty : String <- Store.import_file(db,"claude","empty.jsonl")
    +none : Session.Report <- scan(db,empty,Session.defaults())
    assert(complete(none) && U32.is_eq(processed(none),0) && Bool.not(accounted(none)) &&
      input_output(totals(get_claude(none)),"",""),"empty retained extent is scan-complete with unknown usage rather than known zero")

def wide_ids() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/session-wide.sqlite")
    Store.exec(db,"INSERT INTO sources(id,provider,locator) VALUES(9007199254740992,'claude','/synthetic/unimported-usage-seed')",[])
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(9007199254740992,9007199254740992)",[])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent) VALUES(9007199254740992,9007199254740992,0)",[])
    Store.write_text("wide.jsonl","w",row("id","wide","9007199254740993","9007199254740995"))
    +snapshot : String <- Store.import_file(db,"claude","wide.jsonl")
    +report : Session.Report <- scan(db,snapshot,Session.defaults())
    +text : String <- report_text(report)
    assert(String.eq(snapshot,"9007199254740993") &&
      String.contains(text,"\"source_id\":\"9007199254740993\"") && String.contains(text,"\"generation\":\"9007199254740993\""),
      "actual retained read and rendered witnesses preserve odd IDs above2^53")
    assert(input_output(totals(get_claude(report)),"9007199254740993","9007199254740995"),
      "native owned raw accounting preserves wide decimal token counters")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    +cwd : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(cwd,"juice-bend-test-session_usage."),"Run only through scripts/test in a synthetic directory")
    arithmetic()
    count_fields()
    malformed_claude()
    +db : U32 <- Store.open(".build/session-usage.sqlite")
    pages(db)
    mixed(db)
    claude_identity(db)
    codex_capture(db)
    limits(db)
    byte_batches(db)
    IO.try(Unit,Sql.close(db))
    corruption()
    concurrent_read()
    wide_ids()
