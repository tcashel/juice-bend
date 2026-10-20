import Base
import ../src/tool_activity.bend as Activity
import ../src/providers.bend as Providers
import ../src/evidence.bend as Evidence
import ../src/domain.bend as Domain
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
      IO.die(A,1,"FAIL unexpected tool activity error: " ++ message)

def failed(-A: Kind(&2),result: Result<&2,&2,String,A>,expected: String) -> Bool:
  match result:
    case Fail{message}:
      String.contains(message,expected)
    case Done{_}:
      False{}

def precedes(+text: String,+first: String,+second: String) -> Bool:
  match text:
    case SNil{}:
      False{}
    case SCon{c,tail}:
      String.starts_with(text,first) || (Bool.not(String.starts_with(text,second)) && precedes(tail,first,second))

def key(provider: String,source: String,generation: String,snapshot: String,extent: String,+ordinal: U32,+event: U32) -> Evidence.Descriptor:
  Evidence.Descriptor{Domain.EvidenceKey{provider,source,generation,snapshot,U32.show(ordinal),U32.show(event)},extent,ordinal,event}

def at(ordinal: U32,event: U32,record: Providers.Record) -> Activity.Occurrence:
  Activity.Occurrence{key("claude","/synthetic/alpha.jsonl","1","7","9000",ordinal,event),record}

def call(id: String,args: String) -> Providers.Record:
  Providers.ProviderEvent{"assistant","","Bash",id,args,"","/synthetic/repo","actor-1","2026-10-20T12:00:00Z","recorded-model","","","complete"}

def result(id: String,text: String,coverage: String) -> Providers.Record:
  Providers.ProviderEvent{"tool","","",id,"",text,"/synthetic/repo","actor-1","2026-10-20T12:00:01Z","recorded-model","","",coverage}

def context(value: Providers.Record,repo: String,session: String) -> Providers.Record:
  Providers.ProviderEvent{role,text,tool,id,args,result,_,_,time,model,usage,parent,coverage} = value
  Providers.ProviderEvent{role,text,tool,id,args,result,repo,session,time,model,usage,parent,coverage}

def rows(page: Activity.Page) -> List<&2,Activity.Row>:
  Activity.Page{rows,_} = page
  rows

def row_at(items: List<&2,Activity.Row>,index: Nat) -> Activity.Row:
  match items index:
    case Con{row,_} 0n:
      row
    case Con{_,rest} 1n+n:
      row_at(rest,n)
    case Nil{} _:
      Activity.Row{at(999,0,result("","","unsupported")),Activity.Coverage{},Activity.CoverageOnly{}}

def row(page: Activity.Page,index: Nat) -> Activity.Row:
  row_at(rows(page),index)

def occurrence(row: Activity.Row) -> Activity.Occurrence:
  Activity.Row{item,_,_} = row
  item

def link(row: Activity.Row) -> String:
  Activity.Row{_,_,value} = row
  match value:
    case Activity.Unique{peer}:
      "unique:" ++ Activity.descriptor_text(peer)
    case Activity.NoId{}:
      "no_id"
    case Activity.UnknownIdentity{}:
      "unknown_identity"
    case Activity.UncertainId{}:
      "uncertain_id"
    case Activity.CounterpartAbsent{}:
      "absent"
    case Activity.Ambiguous{calls,results}:
      "ambiguous:" ++ U32.show(calls) ++ ":" ++ U32.show(results)
    case Activity.UncertainShape{n}:
      "uncertain:" ++ U32.show(n)
    case Activity.OrderConflict{}:
      "order"
    case Activity.CoverageOnly{}:
      "coverage"

def counts(page: Activity.Page) -> String:
  Activity.Page{_,Activity.Stats{events,calls,results,pairs,errors,coverage,unpaired}} = page
  String.join([U32.show(events),U32.show(calls),U32.show(results),U32.show(pairs),U32.show(errors),U32.show(coverage),U32.show(unpaired)],"|")

def paired() -> IO(Unit):
  +arguments = {"{\"command\":\"printf 'café 中文 🙂'\\n\",\"counter\":9007199254740993}" : String}
  +output = {"line one\nline two\t🙂\0end" : String}
  do IO<Unit>:
    +page : Activity.Page <- need(Activity.Page,Activity.analyze([at(4,0,call("call-1",arguments)),at(4,1,result("call-1",output,"complete"))]))
    assert(String.eq(counts(page),"2|1|1|1|0|0|0"),"one scoped call and result count as one pair and two retained occurrences")
    assert(Nat.is_eq(List.length(&2,Activity.Row,rows(page)),2n),"pairing never merges or discards occurrences")
    assert(String.eq(Providers.arguments(Activity.record(occurrence(row(page,0n)))),arguments),"full captured arguments and exact number lexeme retained")
    assert(String.eq(Providers.result(Activity.record(occurrence(row(page,1n)))),output),"full captured result including Unicode NUL and whitespace retained")
    assert(String.eq(link(row(page,0n)),"unique:" ++ Activity.descriptor_text(key("claude","/synthetic/alpha.jsonl","1","7","9000",4,1))),"call peer is exact immutable result event citation")
    assert(String.eq(link(row(page,1n)),"unique:" ++ Activity.descriptor_text(key("claude","/synthetic/alpha.jsonl","1","7","9000",4,0))),"result peer points back to the exact call event")
    +text : String <- need(String,Activity.render(page))
    assert(String.contains(text,Json.quote(arguments)) && String.contains(text,Json.quote(output)),"readable output contains complete escaped captured payloads")
    assert(precedes(text,Json.quote(arguments),"Evidence details") && precedes(text,Json.quote(output),"Evidence details"),"both complete call and result payloads precede repeated citation details")
    assert(String.contains(text,"Occurrence 1\nRecorded tool call | Tool: \"Bash\"") &&
      String.contains(text,"Occurrence 2\nRecorded tool result") && String.contains(text,"Evidence for occurrence 1\nCitation: " ++ Activity.descriptor_text(key("claude","/synthetic/alpha.jsonl","1","7","9000",4,0))) &&
      String.contains(text,"Evidence for occurrence 2\nCitation: " ++ Activity.descriptor_text(key("claude","/synthetic/alpha.jsonl","1","7","9000",4,1))),"numbered occurrence bodies map to their exact immutable evidence without relying on pairing")
    assert(String.contains(text,"selected page only") && String.contains(text,"not a complete session") &&
      String.contains(text,"never executed"),"presentation discloses page counts and does not claim successful tool execution")
    again : String <- need(String,Activity.render(page))
    assert(String.eq(text,again),"activity rendering is deterministic")

def absent() -> IO(Unit):
  do IO<Unit>:
    +calls : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("same","{}"))]))
    +results : Activity.Page <- need(Activity.Page,Activity.analyze([at(1,0,result("same","","complete"))]))
    assert(String.eq(counts(calls),"1|1|0|0|0|0|1") && String.eq(link(row(calls,0n)),"absent"),"call without visible result stays an unpaired page occurrence")
    assert(String.eq(counts(results),"1|0|1|0|0|0|1") && String.eq(link(row(results,0n)),"absent"),"empty-string orphan result remains a result occurrence")
    text : String <- need(String,Activity.render(results))
    assert(String.contains(text,"counterpart is not in this selected page; it may exist elsewhere"),"orphan wording does not claim the counterpart never existed")
    +noid : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("","{}")),at(1,0,result("","","complete"))]))
    assert(String.eq(link(row(noid,0n)),"no_id") && String.eq(link(row(noid,1n)),"no_id"),"empty call IDs never pair through shared emptiness")
    +empty : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("empty","")),at(1,0,result("empty","","complete"))]))
    assert(String.eq(counts(empty),"2|1|1|1|0|0|0"),"structurally valid empty argument and result strings can pair")

def ambiguous() -> IO(Unit):
  do IO<Unit>:
    +duplicate_calls : Activity.Page <- need(Activity.Page,Activity.analyze([
      at(0,0,call("same","identical")),at(1,0,call("same","identical")),at(2,0,result("same","ok","complete"))]))
    assert(String.eq(counts(duplicate_calls),"3|2|1|0|0|0|3"),"identical repeated calls at distinct captured positions remain ambiguous")
    assert(String.eq(link(row(duplicate_calls,0n)),"ambiguous:2:1") && String.eq(link(row(duplicate_calls,2n)),"ambiguous:2:1"),"both sides see all duplicate call occurrences")
    +duplicate_results : Activity.Page <- need(Activity.Page,Activity.analyze([
      at(0,0,call("same","{}")),at(1,0,result("same","ok","complete")),at(2,0,result("same","ok","complete"))]))
    assert(String.eq(counts(duplicate_results),"3|1|2|0|0|0|3") && String.eq(link(row(duplicate_results,0n)),"ambiguous:1:2"),"mirrored result occurrences are not silently deduplicated into a unique pair")
    +reversed : Activity.Page <- need(Activity.Page,Activity.analyze([at(3,0,call("same","{}")),at(2,9,result("same","ok","complete"))]))
    assert(String.eq(link(row(reversed,0n)),"order") && String.eq(link(row(reversed,1n)),"order"),"result before call in physical record order is not paired")
    +reordered : Activity.Page <- need(Activity.Page,Activity.analyze([at(2,0,result("same","ok","complete")),at(1,0,call("same","{}"))]))
    assert(String.eq(counts(reordered),"2|1|1|1|0|0|0") && String.eq(Providers.role(Activity.record(occurrence(row(reordered,0n)))),"tool"),"citation order controls pairing while input occurrence order is preserved")

def separated(other: Activity.Occurrence,label: String) -> IO(Unit):
  do IO<Unit>:
    +page : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("same","{}")),other]))
    assert(String.eq(counts(page),"2|1|1|0|0|0|2") && String.eq(link(row(page,0n)),"absent"),label)

def identities() -> IO(Unit):
  do IO<Unit>:
    separated(Activity.Occurrence{key("codex","/synthetic/alpha.jsonl","1","7","9000",1,0),result("same","ok","complete")},"same ID never pairs across providers")
    separated(Activity.Occurrence{key("claude","/synthetic/beta.jsonl","1","7","9000",1,0),result("same","ok","complete")},"same ID never pairs across source locators")
    separated(Activity.Occurrence{key("claude","/synthetic/alpha.jsonl","2","7","9000",1,0),result("same","ok","complete")},"same ID never pairs across generations")
    separated(Activity.Occurrence{key("claude","/synthetic/alpha.jsonl","1","8","9000",1,0),result("same","ok","complete")},"same ID never pairs across accepted snapshots")
    separated(Activity.Occurrence{key("claude","/synthetic/alpha.jsonl","1","7","9001",1,0),result("same","ok","complete")},"same ID never pairs across captured extents")
    separated(at(1,0,context(result("same","ok","complete"),"/synthetic/other","actor-1")),"same ID never pairs across contextualized repositories")
    separated(at(1,0,context(result("same","ok","complete"),"/synthetic/repo","child-actor")),"same ID never pairs across recorded actors or child sessions")
    +unknown : Activity.Page <- need(Activity.Page,Activity.analyze([
      at(0,0,context(call("same","{}"),"/synthetic/repo","")),at(1,0,context(result("same","ok","complete"),"/synthetic/repo",""))]))
    assert(String.eq(link(row(unknown,0n)),"unknown_identity") && String.eq(link(row(unknown,1n)),"unknown_identity"),"missing recorded session refuses matching even when both are missing")
    +repo : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,context(call("same","{}"),"","actor-1")),at(1,0,context(result("same","ok","complete"),"","actor-1"))]))
    assert(String.eq(link(row(repo,0n)),"unknown_identity"),"missing repository identity cannot be invented")

def coverage() -> IO(Unit):
  +unknown = {Providers.ProviderEvent{"unsupported","unrecognized captured variant","","same","{raw}","","/synthetic/repo","actor-1","","","","","unsupported"} : Providers.Record}
  do IO<Unit>:
    +page : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("same","{}")),at(1,0,result("same","recorded failure","tool_error; invalid_timestamp")),at(2,0,unknown)]))
    assert(String.eq(counts(page),"3|1|1|0|1|2|2"),"explicit error and coverage facts remain separate from pair and success counts")
    assert(String.eq(link(row(page,0n)),"uncertain:1") && String.eq(link(row(page,1n)),"uncertain:1"),"unknown same-ID tool shape prevents an unjustified unique pair")
    assert(String.eq(link(row(page,2n)),"coverage") && String.eq(Providers.arguments(Activity.record(occurrence(row(page,2n)))),"{raw}"),"unsupported occurrence retains payload and citation")
    +error_page : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("e","{}")),at(1,0,result("e","failed","tool_error"))]))
    assert(String.eq(counts(error_page),"2|1|1|1|1|0|0"),"recorded tool_error can be uniquely linked without becoming successful execution")
    +error_text : String <- need(String,Activity.render(error_page))
    assert(String.contains(error_text,"Recorded tool_error: true"),"recorded provider error is visibly explicit")
    assert(precedes(error_text,"Recorded tool_error: true","Captured result (JSON string): \"failed\"") &&
      precedes(error_text,"Captured result (JSON string): \"failed\"","Evidence details"),"recorded error status precedes its complete result before evidence details")
    +partial : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("p","{}")),at(1,0,result("p","retained supported text","partial_content"))]))
    assert(String.eq(counts(partial),"2|1|1|1|0|1|0"),"partial result coverage survives a unique identity match")

def parsed_at(+provider: String,+ordinal: U32,events: List<&2,Providers.Record>,+index: U32) -> List<&2,Activity.Occurrence>:
  match events:
    case []:
      []
    case value <> rest:
      Activity.Occurrence{key(provider,"/synthetic/provider.jsonl","3","9","8000",ordinal,index),value} <>
        parsed_at(provider,ordinal,rest,U32.inc(index))

def provider_records() -> IO(Unit):
  +claude_call = {"{\"type\":\"assistant\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"s\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"c\",\"name\":\"Bash\",\"input\":{\"command\":\"echo synthetic\"}}]}}" : String}
  +claude_result = {"{\"type\":\"user\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"s\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"c\",\"content\":\"\",\"is_error\":true}]}}" : String}
  do IO<Unit>:
    +claude : Activity.Page <- need(Activity.Page,Activity.analyze(List.append(&2,Activity.Occurrence,
      parsed_at("claude",0,Providers.parse("claude",claude_call),0),parsed_at("claude",1,Providers.parse("claude",claude_result),0))))
    assert(String.eq(counts(claude),"2|1|1|1|1|0|0"),"real Claude parser empty error result pairs without losing explicit error")
    +codex : Activity.Page <- need(Activity.Page,Activity.analyze(List.append(&2,Activity.Occurrence,
      parsed_at("codex",0,Providers.parse("codex","{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"cwd\":\"/synthetic/repo\",\"session_id\":\"s\",\"name\":\"exec_command\",\"call_id\":\"c\",\"arguments\":\"exact whitespace  \\n\"}}"),0),
      parsed_at("codex",1,Providers.parse("codex","{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"cwd\":\"/synthetic/repo\",\"session_id\":\"s\",\"call_id\":\"c\",\"output\":\"\"}}"),0))))
    assert(String.eq(counts(codex),"2|1|1|1|0|0|0") && String.eq(Providers.arguments(Activity.record(occurrence(row(codex,0n)))),"exact whitespace  \n"),"real Codex parser pairs empty result and preserves exact argument string")
    +bad : Activity.Page <- need(Activity.Page,Activity.analyze(parsed_at("claude",0,Providers.parse("claude","{bad"),0)))
    assert(String.eq(counts(bad),"1|0|0|0|0|1|0") && String.eq(link(row(bad,0n)),"coverage"),"malformed production parser record remains an explicit cited coverage row")

def validation() -> IO(Unit):
  +item = at(0,0,call("same","{}"))
  do IO<Unit>:
    assert(failed(Activity.Page,Activity.analyze([item,item]),"distinct immutable"),"duplicate event citation is rejected rather than inflating occurrence counts")
    assert(failed(Activity.Page,Activity.analyze([item,Activity.Occurrence{key("claude","/synthetic/alpha.jsonl","1","7","9001",0,0),call("same","different")}]),"distinct immutable"),"same occurrence with conflicting extent is rejected")
    assert(failed(Activity.Page,Activity.analyze([Activity.Occurrence{Evidence.Descriptor{Domain.EvidenceKey{"claude","/synthetic/source","1","7","0","0"},"8",1,0},call("c","{}")}]),"distinct immutable"),"descriptor ordinal must agree with its exact durable key")
    assert(failed(Activity.Page,Activity.analyze([Activity.Occurrence{key("unknown","/synthetic/source","1","7","8",0,0),call("c","{}")}]),"distinct immutable"),"unknown provider cannot create a validated activity citation")
    assert(failed(Activity.Page,Activity.analyze([Activity.Occurrence{key("claude","/synthetic/source","0","7","8",0,0),call("c","{}")}]),"distinct immutable"),"zero generation cannot masquerade as an accepted citation")
    +empty : Activity.Page <- need(Activity.Page,Activity.analyze([]))
    assert(String.eq(counts(empty),"0|0|0|0|0|0|0"),"empty selected page has zero observed counts without a session-completeness claim")

def uncertain_id(+id: String,label: String) -> IO(Unit):
  do IO<Unit>:
    +page : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call(id,"{}")),at(1,0,result(id,"ok","complete"))]))
    assert(String.eq(counts(page),"2|1|1|0|0|0|2") && String.eq(link(row(page,0n)),"uncertain_id") &&
      String.eq(link(row(page,1n)),"uncertain_id"),label)

def coerced_pair(raw_id: String,string_id: String,label: String) -> IO(Unit):
  do IO<Unit>:
    +page : Activity.Page <- need(Activity.Page,Activity.analyze(List.append(&2,Activity.Occurrence,
      parsed_at("claude",0,Providers.parse("claude","{\"type\":\"assistant\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"s\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":" ++ raw_id ++ ",\"name\":\"Bash\",\"input\":{}}]}}"),0),
      parsed_at("claude",1,Providers.parse("claude","{\"type\":\"user\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"s\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":" ++ Json.quote(string_id) ++ ",\"content\":\"\"}]}}"),0))))
    assert(String.eq(counts(page),"2|1|1|0|0|0|2") && String.eq(link(row(page,1n)),"uncertain_id"),label)

def typed_identity() -> IO(Unit):
  do IO<Unit>:
    uncertain_id("42","valid all-numeric string call ID is conservatively withheld because raw scalar type is unavailable")
    uncertain_id("true","boolean-looking call ID cannot collide with a coerced JSON boolean")
    uncertain_id("null","null-looking identifier remains uncertain rather than inventing raw type")
    uncertain_id("[1,2]","array-looking identifier does not establish a typed call identity")
    uncertain_id("{\"id\":1}","object-looking identifier does not establish a typed call identity")
    +session : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,context(call("c","{}"),"/synthetic/repo","false")),at(1,0,context(result("c","ok","complete"),"/synthetic/repo","false"))]))
    assert(String.eq(link(row(session,0n)),"uncertain_id") && String.eq(link(row(session,1n)),"uncertain_id"),"coercible session ID cannot merge distinct actors")
    text : String <- need(String,Activity.render(session))
    assert(String.contains(text,"raw field type is unavailable"),"identity withholding explains the normalized-data limitation")
    +relative : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,context(call("c","{}"),"relative/repo","actor")),at(1,0,context(result("c","ok","complete"),"relative/repo","actor"))]))
    assert(String.eq(link(row(relative,0n)),"unknown_identity"),"relative repository identity is insufficient for pairing")
    +coerced : Activity.Page <- need(Activity.Page,Activity.analyze(List.append(&2,Activity.Occurrence,
      parsed_at("claude",0,Providers.parse("claude","{\"type\":\"assistant\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"s\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":42,\"name\":\"Bash\",\"input\":{}}]}}"),0),
      parsed_at("claude",1,Providers.parse("claude","{\"type\":\"user\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"s\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"42\",\"content\":\"\"}]}}"),0))))
    assert(String.eq(counts(coerced),"2|1|1|0|0|0|2") && String.eq(link(row(coerced,0n)),"uncertain_id"),"real provider parser numeric-versus-string ID collision cannot become a unique tool pair")

def provider_type_collisions() -> IO(Unit):
  do IO<Unit>:
    coerced_pair("true","true","real parser boolean and string call IDs cannot be promoted to a unique pair")
    coerced_pair("null","null","raw null and string null retain separate unpaired occurrences")
    coerced_pair("[1]","[1]","raw array and array-looking string IDs never pair")
    coerced_pair("{\"a\":1}","{\"a\":1}","raw object and object-looking string IDs never pair")
    coerced_pair("\"42\"","42","real parser valid numeric string IDs are conservatively withheld without claiming malformed data")

def repeat(count: Nat,+text: String) -> String:
  match count:
    case 0n:
      ""
    case 1n+n:
      text ++ repeat(n,text)

def many(count: Nat,+index: U32) -> List<&2,Activity.Occurrence>:
  match count:
    case 0n:
      []
    case 1n+n:
      at(index,0,call(U32.show(index),"{}")) <> many(n,U32.inc(index))

def remaining(value: Maybe<&2,U32>,n: U32) -> Bool:
  match value:
    case Some{budget}:
      U32.is_eq(budget,n)
    case None{}:
      False{}

def exhausted(value: Maybe<&2,U32>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def bounds() -> IO(Unit):
  do IO<Unit>:
    assert(remaining(Activity.consume("🙂éx",7),0) && exhausted(Activity.consume("🙂éx",6)),"UTF-8 budget counts four-byte emoji and two-byte accented text exactly")
    assert(exhausted(Activity.consume(SCon{Chr{55296},SNil{}},100)),"invalid Unicode scalar is rejected at the pure input boundary")
    uncertain_id(repeat(150n,"[") ++ "0" ++ repeat(150n,"]"),"container-looking identity remains uncertain even beyond the JSON nesting bound")
    +full : Activity.Page <- need(Activity.Page,Activity.analyze(many(256n,0)))
    assert(String.eq(counts(full),"256|256|0|0|0|0|256"),"exactly 256 cited occurrences are accepted")
    assert(failed(Activity.Page,Activity.analyze(many(257n,0)),"exceeds 256"),"event bound rejects the entire excess page without truncation")
    assert(failed(Activity.Page,Activity.analyze([at(0,0,call("large",repeat(131072n,"🙂")))]),"524288 UTF-8 bytes"),"UTF-8 input bound includes all descriptor and provider fields beyond argument bytes")
    assert(failed(Activity.Page,Activity.analyze([Activity.Occurrence{key("claude",repeat(4097n,"s"),"1","7","8",0,0),call("c","{}")}]),"distinct immutable"),"oversized source locator is rejected rather than omitted from citation")
    +escaped : Activity.Page <- need(Activity.Page,Activity.analyze([at(0,0,call("escaped",repeat(180000n,"\0")))]))
    assert(failed(String,Activity.render(escaped),"1048576-byte worker limit"),"escaped final output over one MiB is an explicit failure without truncating input")

def detail_preservation() -> IO(Unit):
  +event = {Providers.ProviderEvent{"unsupported","full captured text café\n🙂","named tool","call-id","full args\t\0","full result  ",
    "/synthetic/space repo","session-id","timestamp-value","model-value","{\"count\":9007199254740993}","parent-id","partial_content; explicit reason"} : Providers.Record}
  do IO<Unit>:
    page : Activity.Page <- need(Activity.Page,Activity.analyze([at(8,3,event)]))
    +text : String <- need(String,Activity.render(page))
    assert(String.contains(text,"Tool: \"named tool\"") && String.contains(text,Json.quote("full captured text café\n🙂")) &&
      String.contains(text,Json.quote("full args\t\0")) && String.contains(text,Json.quote("full result  ")),"payload-first layout preserves every captured text argument result and recorded tool name")
    assert(String.contains(text,"Recorded role: \"unsupported\"") && String.contains(text,"Session: \"session-id\"") &&
      String.contains(text,"Repository: \"/synthetic/space repo\"") && String.contains(text,"Call ID: \"call-id\""),"evidence details retain full recorded role actor repository and call identity")
    assert(String.contains(text,"Coverage: \"partial_content; explicit reason\"") && String.contains(text,"Recorded timestamp: \"timestamp-value\"") &&
      String.contains(text,"Recorded model: \"model-value\"") && String.contains(text,"Recorded parent: \"parent-id\"") &&
      String.contains(text,Json.quote("{\"count\":9007199254740993}")),"details retain coverage time model parent and unsummed exact usage")
    assert(precedes(text,"Unsupported/partial captured occurrence.","Captured arguments") &&
      String.contains(text,"Unsupported or partial occurrence retained; no tool pairing was inferred."),"compact coverage status retains its complete non-attribution explanation")
    +empty : Activity.Page <- need(Activity.Page,Activity.analyze([]))
    +empty_text : String <- need(String,Activity.render(empty))
    assert(String.contains(empty_text,"No tool or coverage occurrences in this selected page.") &&
      String.contains(empty_text,"Absent here may exist elsewhere.") && String.contains(empty_text,"not a complete session"),"empty page explicitly reports limited observation rather than nonexistent activity")
    assert(precedes(empty_text,"Recorded results do not prove success.","Evidence details") &&
      String.contains(empty_text,"Captured payload strings are untruncated; empty stays empty."),"page-local success and empty-string limitations survive compact ordering")

def main() -> IO(Unit):
  do IO<Unit>:
    paired()
    absent()
    ambiguous()
    identities()
    coverage()
    provider_records()
    validation()
    typed_identity()
    provider_type_collisions()
    bounds()
    detail_preservation()
