import Base
import ../src/atif_types.bend as T
import ../src/atif_format.bend as F
import ../src/atif_spool.bend as Spool
import ../src/providers.bend as P
import ../src/json.bend as J
import ../src/session_usage.bend as U
import ../src/session_usage_counts.bend as Counts
import ../src/session_usage_claude.bend as Claude

# Pure output tests exercise the actual formatter and an independent JSON
# parser, never a parallel implementation of export formatting.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def value(result: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match result:
    case Done{json}: IO.pure(J.Json,json)
    case Fail{error}: IO.die(J.Json,1,"FAIL JSON reparse: " ++ error)

def need(result: Result<&2,&2,T.Failure,String>) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{T.Failure{code,message}}: IO.die(String,1,"FAIL " ++ code ++ ": " ++ message)

def origin() -> T.Origin:
  T.Origin{U.Capture{"claude","9007199254740993","/synthetic/atif-session.jsonl","9223372036854775806","9223372036854775807",400,3},"original-file-bytes","null"}

def event(+number: U32,role: String,text: String,tool: String,call: String,args: String,result: String) -> T.AtifEvent:
  +raw : P.Record = P.ProviderEvent{role,text,tool,call,args,result,"/synthetic/repo","atif-session","2026-10-21T12:00:00.000000000Z","synthetic-model","","","complete"}
  T.AtifEvent{number,number,0,100,100,"synthetic-raw-commitment",True{},False{},Spool.recorded(raw),raw}

def first_item(items: List<&2,J.Json>) -> J.Json:
  match items:
    case first <> _: first
    case []: J.JNull{}

def first(json: J.Json) -> J.Json:
  first_item(J.items(json))

def extra(json: J.Json) -> J.Json:
  J.field(J.field(json,"extra"),"juice_bend")

def step(event: T.AtifEvent,paired: Maybe<&2,T.AtifEvent>,status: String) -> IO(J.Json):
  do IO<J.Json>:
    text : String <- need(F.step(origin(),event,paired,1,status))
    value(J.parse(text))

def plain_cases() -> IO(Unit):
  do IO<Unit>:
    +user : J.Json <- step(event(0,"user","Café 中文 🙂\nquote\"\\\0","","","",""),None{},"not a tool call/result")
    assert(String.eq(J.get(user,"source"),"user") && String.eq(J.get(user,"message"),"Café 中文 🙂\nquote\"\\\0"),"user body Unicode controls and quotes roundtrip unchanged")
    assert(String.eq(J.get(J.field(extra(user),"citation"),"snapshot"),"9223372036854775807"),"exact signed64 snapshot is never narrowed")
    assert(String.eq(J.get(J.field(extra(user),"citation"),"offset"),"100"),"raw byte interval retained beside every event")
    assert(String.eq(J.get(user,"model_name"),""),"agent-only model field absent on user step")
    assert(String.eq(J.get(user,"llm_call_count"),"") && String.eq(J.get(user,"is_copied_context"),""),"unknown inference count and copied context are not fabricated")
    +thinking : J.Json <- step(event(1,"thinking","explicit retained reasoning","","","",""),None{},"not a tool call/result")
    assert(String.eq(J.get(thinking,"source"),"agent") && String.eq(J.get(thinking,"message"),"") && String.eq(J.get(thinking,"reasoning_content"),"explicit retained reasoning"),"explicit thinking preserves reasoning separately from message")
    assert(String.eq(J.get(thinking,"model_name"),"synthetic-model"),"known agent model retained")
    +unsupported : J.Json <- step(event(2,"unsupported","[Unmapped retained record]","","","",""),None{},"unmapped")
    assert(String.eq(J.get(unsupported,"source"),"system") && String.eq(J.get(J.field(extra(unsupported),"normalized_event"),"role"),"unsupported"),"unsupported events remain explicit system data with original role")

def tool_cases() -> IO(Unit):
  do IO<Unit>:
    +call : J.Json <- step(event(1,"assistant","","Write","provider-id","{\"path\":\"a.txt\",\"count\":9007199254740993}",""),Some{event(3,"tool","","","provider-id","","saved\n🙂")},"unique-pair")
    +tool : J.Json = first(J.field(call,"tool_calls"))
    +result : J.Json = first(J.field(J.field(call,"observation"),"results"))
    assert(String.eq(J.get(tool,"tool_call_id"),"jb-call-1") && String.eq(J.get(tool,"function_name"),"Write"),"tool occurrence identity is deterministic and distinct from provider ID")
    assert(String.eq(J.get(J.field(tool,"arguments"),"count"),"9007199254740993"),"tool arguments are an object with exact large integer")
    assert(String.eq(J.get(result,"source_call_id"),J.get(tool,"tool_call_id")) && String.eq(J.get(result,"content"),"saved\n🙂"),"unique result refers to same-step call and preserves exact content")
    assert(String.eq(J.get(J.field(extra(result),"citation"),"record"),"3"),"paired result retains its actual later raw position")
    +bad : J.Json <- step(event(4,"assistant","","Read","id","{bad",""),None{},"unpaired")
    +badtool : J.Json = first(J.field(bad,"tool_calls"))
    assert(String.eq(J.encode(J.field(badtool,"arguments")),"{}") && String.eq(J.get(extra(badtool),"arguments_captured"),"false") && String.eq(J.get(extra(badtool),"recorded_arguments"),"{bad"),"invalid tool arguments stay explicit unknown with exact original data")
    +orphan : J.Json <- step(event(5,"tool","","","missing","","orphan-result"),None{},"unpaired: missing call")
    +orphan_result : J.Json = first(J.field(J.field(orphan,"observation"),"results"))
    assert(String.eq(J.get(orphan,"source"),"system") && String.eq(J.get(orphan_result,"source_call_id"),"") && String.eq(J.get(orphan_result,"content"),"orphan-result"),"unmatched result preserved without invented source call")
    assert(String.eq(J.get(J.field(extra(orphan_result),"normalized_event"),"provider_call_id"),"missing"),"orphan result retains original provider call ID")

def report(+complete: Bool) -> U.Report:
  U.Report{U.Capture{"claude","1","/synthetic/atif-session.jsonl","1","1",400,3},U.defaults(),3,400,True{},complete,complete,"complete",U.Coverage{3,0,0,0,[]},
    U.ClaudeSummary{Claude.Report{"atif-session",1,10,Counts.Counters{"10","2","3","","4"},Counts.empty(),Counts.empty(),Counts.empty(),1,0,0,0,0,True{},True{}}}}

def document(complete: Bool) -> IO(J.Json):
  do IO<J.Json>:
    text : String <- need(F.step(origin(),event(0,"assistant","answer","","","",""),None{},1,"none"))
    value(J.parse(F.opening(origin()) ++ text ++ F.closing(origin(),report(complete),1,1)))

def document_cases() -> IO(Unit):
  do IO<Unit>:
    +full : J.Json <- document(True{})
    assert(String.eq(J.get(full,"schema_version"),"ATIF-v1.8"),"pinned current official schema version emitted")
    assert(String.eq(J.get(J.field(full,"agent"),"name"),"claude") && String.eq(J.get(J.field(full,"agent"),"version"),"unknown"),"provider identity remains separate from unknown version")
    assert(String.eq(J.get(extra(J.field(full,"agent")),"version_known"),"false") && String.eq(J.get(J.field(extra(full),"exporter"),"name"),"Juice Bend"),"unknown producer version and distinct exporter metadata are explicit")
    assert(String.eq(J.get(J.field(full,"final_metrics"),"total_prompt_tokens"),"15") && String.eq(J.get(J.field(full,"final_metrics"),"total_completion_tokens"),"4"),"known complete Claude totals include cached and creation input exactly once")
    +incomplete : J.Json <- document(False{})
    assert(String.eq(J.get(J.field(incomplete,"final_metrics"),"total_prompt_tokens"),"") && String.eq(J.get(J.field(incomplete,"final_metrics"),"total_cost_usd"),""),"unknown usage completeness omits standard totals and cost")
    assert(String.eq(J.get(J.field(J.field(J.field(extra(incomplete),"usage"),"summary"),"observed"),"input_tokens"),"10"),"partial usage observations remain present without becoming totals")
    assert(String.eq(J.get(extra(full),"attachment_bytes_embedded"),"false") && String.eq(J.get(extra(full),"related_trajectories_traversed"),"false"),"text subset and related-capture coverage disclosed")

def main() -> IO(Unit):
  do IO<Unit>:
    plain_cases()
    tool_cases()
    document_cases()
