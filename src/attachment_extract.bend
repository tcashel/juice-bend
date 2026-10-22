import Base
import ./json.bend as Json
import ./attachment_refs.bend as Ref

# An occurrence's full identity is caller-owned snapshot + raw record ordinal +
# reference ordinal. path is an exact JSON structural path, never a display-event
# ordinal or a filesystem path. No mirror/content deduplication occurs here.
type Occurrence is Data:
  Occurrence{ordinal: U32,path: String,kind: String,reference: Ref.Reference}

type ScanCoverage is Data:
  CompleteScan{}
  PartialScan{reason: String,truncated: Bool}

type Report is Data:
  Report{occurrences: List<&2,Occurrence>,coverage: ScanCoverage}

type Job is Data:
  Content{value: Json.Json,path: String,depth: U32}
  Blocks{items: List<&2,Json.Json>,path: String,index: U32,depth: U32}
  References{value: Json.Json,path: String}
  ReferenceItems{items: List<&2,Json.Json>,path: String,index: U32}
  ToolOutput{value: Json.Json,path: String,depth: U32}

type State is Data:
  State{reversed: List<&2,Occurrence>,count: U32,issue: String,stopped: Bool,truncated: Bool}

type Step is Data:
  Step{state: State,jobs: List<&2,Job>}

def first_issue(+prior: String,next: String) -> String:
  Bool.pick(String,String.is_empty(prior),next,prior)

def version() -> String:
  "attachment-occurrences-v1"

def issue(state: State,message: String) -> State:
  State{rows,count,prior,stopped,truncated} = state
  State{rows,count,first_issue(prior,message),stopped,truncated}

def truncated_branch(state: State,message: String) -> State:
  State{rows,count,prior,stopped,_} = state
  State{rows,count,first_issue(prior,message),stopped,True{}}

def stop(state: State,message: String) -> State:
  State{rows,count,prior,_,_} = state
  State{rows,count,first_issue(prior,message),True{},True{}}

def add_checked(valid: Bool,state: State,path: String,kind: String,reference: Ref.Reference) -> State:
  match valid:
    case False{}: stop(state,"occurrence_limit; total unknown")
    case True{}:
      State{rows,+count,prior,stopped,truncated} = state
      State{Occurrence{count,path,kind,reference} <> rows,U32.inc(count),prior,stopped,truncated}

def add(+state: State,path: String,kind: String,reference: Ref.Reference) -> State:
  State{_,count,_,_,_} = state
  add_checked(U32.is_lt(count,64),state,path,kind,reference)

def done(state: State) -> Report:
  State{rows,_,+reason,_,truncated} = state
  Report{List.reverse(&2,Occurrence,rows),Bool.pick(ScanCoverage,String.is_empty(reason),
    CompleteScan{},PartialScan{reason,truncated})}

def known_text(+kind: String) -> Bool:
  String.eq(kind,"text") || String.eq(kind,"input_text") ||
    String.eq(kind,"output_text") || String.eq(kind,"summary_text") ||
    String.eq(kind,"thinking") || String.eq(kind,"redacted_thinking")

def image_url_value(value: Json.Json) -> Ref.Reference:
  match value:
    case Json.JObject{fields}: Ref.url(Json.field(Json.JObject{fields},"url"))
    case value: Ref.url(value)

def image_url(block: Json.Json) -> Ref.Reference:
  image_url_value(Json.field(block,"image_url"))

def image_url_value_path(value: Json.Json,path: String) -> String:
  match value:
    case Json.JObject{_}: path ++ "/image_url/url"
    case _: path ++ "/image_url"

def image_url_path(block: Json.Json,path: String) -> String:
  image_url_value_path(Json.field(block,"image_url"),path)

def source_path_type(kind: String,base: String) -> String:
  match kind:
    case "file": base ++ "/path"
    case "url": base ++ "/url"
    case "base64": base ++ "/data"
    case _: base

def source_path(block: Json.Json,path: String) -> String:
  source_path_type(Json.get(Json.field(block,"source"),"type"),path ++ "/source")

def nested_checked(valid: Bool,state: State,jobs: List<&2,Job>,value: Json.Json,path: String,depth: U32) -> Step:
  match valid:
    case False{}: Step{truncated_branch(state,"nested_attachment_depth_limit; total unknown"),jobs}
    case True{}: Step{state,Content{value,path,U32.inc(depth)} <> jobs}

def nested(state: State,jobs: List<&2,Job>,value: Json.Json,path: String,+depth: U32) -> Step:
  nested_checked(U32.is_lt(depth,8),state,jobs,value,path,depth)

def block_kind(+kind: String) -> U32:
  Bool.pick(U32,String.eq(kind,"image") || String.eq(kind,"document"),0,
    Bool.pick(U32,String.eq(kind,"input_image") || String.eq(kind,"image_url"),1,
      Bool.pick(U32,String.eq(kind,"tool_result"),2,
        Bool.pick(U32,String.eq(kind,"tool_use"),3,4))))

def block_routed(route: U32,kind: String,+value: Json.Json,+path: String,depth: U32,+state: State,jobs: List<&2,Job>) -> Step:
  match route:
    case 0:
      Step{add(state,source_path(value,path),kind,Ref.source(Json.field(value,"source"))),jobs}
    case 1:
      Step{add(state,image_url_path(value,path),kind,image_url(value)),jobs}
    case 2:
      nested(state,jobs,Json.field(value,"content"),path ++ "/content",depth)
    case 3: Step{state,jobs}
    case _:
      Step{Bool.pick(State,known_text(kind),state,
        issue(state,"unsupported_content_block; total unknown")),jobs}

def block_type(+kind: String,value: Json.Json,path: String,depth: U32,state: State,jobs: List<&2,Job>) -> Step:
  block_routed(block_kind(kind),kind,value,path,depth,state,jobs)

def block(value: Json.Json,path: String,depth: U32,state: State,jobs: List<&2,Job>) -> Step:
  match value:
    case Json.JObject{+fields}:
      block_type(Json.get(Json.JObject{fields},"type"),Json.JObject{fields},path,depth,state,jobs)
    case _: Step{issue(state,"content_block_not_object; total unknown"),jobs}

def content(value: Json.Json,path: String,depth: U32,state: State,jobs: List<&2,Job>) -> Step:
  match value:
    case Json.JString{_}: Step{state,jobs}
    case Json.JArray{items}: Step{state,Blocks{items,path,0,depth} <> jobs}
    case _: Step{issue(state,"content_not_text_or_array; total unknown"),jobs}

def references(value: Json.Json,path: String,state: State,jobs: List<&2,Job>) -> Step:
  match value:
    case Json.JNull{}: Step{state,jobs}
    case Json.JArray{items}: Step{state,ReferenceItems{items,path,0} <> jobs}
    case _: Step{issue(state,"image_references_not_array; total unknown"),jobs}

def output(value: Json.Json,path: String,depth: U32,state: State,jobs: List<&2,Job>) -> Step:
  match value:
    case Json.JString{_}: Step{state,jobs}
    case Json.JArray{items}: Step{state,Blocks{items,path,0,depth} <> jobs}
    case Json.JObject{fields}:
      content(Json.field(Json.JObject{fields},"content"),path ++ "/content",depth,state,jobs)
    case _: Step{issue(state,"tool_output_not_supported_container; total unknown"),jobs}

def job(value: Job,state: State,jobs: List<&2,Job>) -> Step:
  match value:
    case Content{value,path,depth}: content(value,path,depth,state,jobs)
    case Blocks{[],_,_,_}: Step{state,jobs}
    case Blocks{value <> rest,+path,+index,+depth}:
      block(value,path ++ "/" ++ U32.show(index),depth,state,
        Blocks{rest,path,U32.inc(index),depth} <> jobs)
    case References{value,path}: references(value,path,state,jobs)
    case ReferenceItems{[],_,_}: Step{state,jobs}
    case ReferenceItems{value <> rest,+path,+index}:
      Step{add(state,path ++ "/" ++ U32.show(index),"input_image",Ref.url(value)),
        ReferenceItems{rest,path,U32.inc(index)} <> jobs}
    case ToolOutput{value,path,depth}: output(value,path,depth,state,jobs)

def continue_scan(next: Step,scan: List<&2,Job> -> State -> Report) -> Report:
  Step{state,jobs} = next
  scan(jobs,state)

def scan_ready(stopped: Bool,jobs: List<&2,Job>,state: State,
  next_scan: List<&2,Job> -> State -> Report) -> Report:
  match stopped jobs:
    case True{} _: done(state)
    case False{} Nil{}: done(state)
    case False{} Con{next,rest}:
      continue_scan(job(next,state,rest),next_scan)

def exhausted(jobs: List<&2,Job>,state: State) -> Report:
  match jobs:
    case []: done(state)
    case _: done(stop(state,"scan_work_limit; total unknown"))

def scan(fuel: Nat,jobs: List<&2,Job>,+state: State) -> Report:
  match fuel:
    case 0n: exhausted(jobs,state)
    case 1n+left:
      State{_,_,_,stopped,_} = state
      scan_ready(stopped,jobs,state,
        pending => current => scan(left,pending,current))

def empty() -> State:
  State{[],0,"",False{},False{}}

def partial(reason: String) -> Report:
  done(issue(empty(),reason))

def run(jobs: List<&2,Job>) -> Report:
  scan(4096n,jobs,empty())

def role_valid(+role: String) -> Bool:
  String.eq(role,"user") || String.eq(role,"assistant")

def message_allowed(valid: Bool,value: Json.Json,path: String) -> Report:
  match valid:
    case False{}: partial("message_role_not_supported; total unknown")
    case True{}: run([Content{Json.field(value,"content"),path ++ "/content",0}])

def message(+value: Json.Json,path: String) -> Report:
  message_allowed(role_valid(Json.get(value,"role")),value,path)

def claude_type(kind: String,value: Json.Json) -> Report:
  match kind:
    case "user": run([Content{Json.field(Json.field(value,"message"),"content"),"/message/content",0}])
    case "assistant": run([Content{Json.field(Json.field(value,"message"),"content"),"/message/content",0}])
    case "summary": done(empty())
    case "system": done(empty())
    case "file-history-snapshot": done(empty())
    case "queue-operation": done(empty())
    case "progress": done(empty())
    case _: partial("unsupported_claude_record; total unknown")

def claude(+value: Json.Json) -> Report:
  claude_type(Json.get(value,"type"),value)

def optional_content_value(value: Maybe<&2,Json.Json>,path: String) -> List<&2,Job>:
  match value:
    case None{}: []
    case Some{content}: [Content{content,path,0}]

def optional_content(value: Json.Json,path: String) -> List<&2,Job>:
  match value:
    case Json.JObject{fields}:
      optional_content_value(Json.field_scan(fields,"content",None{}),path)
    case _: []

def codex_event_type(kind: String,+value: Json.Json) -> Report:
  match kind:
    case "user_message":
      run(References{Json.field(value,"local_images"),"/payload/local_images"} <>
        References{Json.field(value,"images"),"/payload/images"} <>
        optional_content(value,"/payload/content"))
    case "agent_message": done(empty())
    case "agent_reasoning": done(empty())
    case "token_count": done(empty())
    case "task_started": done(empty())
    case "task_complete": done(empty())
    case "turn_aborted": done(empty())
    case _: partial("unsupported_codex_event; total unknown")

def codex_event(+value: Json.Json) -> Report:
  codex_event_type(Json.get(value,"type"),value)

def codex_response_type(kind: String,value: Json.Json) -> Report:
  match kind:
    case "message": message(value,"/payload")
    case "agent_message": run([Content{Json.field(value,"content"),"/payload/content",0}])
    case "function_call_output": run([ToolOutput{Json.field(value,"output"),"/payload/output",0}])
    case "custom_tool_call_output": run([ToolOutput{Json.field(value,"output"),"/payload/output",0}])
    case "function_call": done(empty())
    case "custom_tool_call": done(empty())
    case "reasoning": done(empty())
    case _: partial("unsupported_codex_response; total unknown")

def codex_response(+value: Json.Json) -> Report:
  codex_response_type(Json.get(value,"type"),value)

def codex_type(kind: String,value: Json.Json) -> Report:
  match kind:
    case "response_item": codex_response(Json.field(value,"payload"))
    case "event_msg": codex_event(Json.field(value,"payload"))
    case "message": message(value,"")
    case "session_meta": done(empty())
    case "turn_context": done(empty())
    case "function_call": done(empty())
    case "compacted": done(empty())
    case _: partial("unsupported_codex_record; total unknown")

def codex(+value: Json.Json) -> Report:
  codex_type(Json.get(value,"type"),value)

# value is an internal seam for JSON already admitted by this same parser.
# Public callers use analyze on a verified retained raw record's decoded text.
def value(provider: String,raw: Json.Json) -> Report:
  match provider raw:
    case "claude" Json.JObject{fields}: claude(Json.JObject{fields})
    case "codex" Json.JObject{fields}: codex(Json.JObject{fields})
    case "claude" _: partial("record_not_object; total unknown")
    case "codex" _: partial("record_not_object; total unknown")
    case _ _: partial("unsupported_provider; total unknown")

def parsed(provider: String,result: Result<&2,&2,String,Json.Json>) -> Report:
  match result:
    case Fail{_}: partial("malformed_or_oversized_json; total unknown")
    case Done{raw}: value(provider,raw)

def analyze(provider: String,raw: String) -> Report:
  parsed(provider,Json.parse(raw))

def count(report: Report) -> U32:
  Report{rows,_} = report
  U32.from_nat(List.length(&2,Occurrence,rows))

def complete(report: Report) -> Bool:
  match report:
    case Report{_,CompleteScan{}}: True{}
    case Report{_,PartialScan{_,_}}: False{}

def reason(report: Report) -> String:
  match report:
    case Report{_,CompleteScan{}}: ""
    case Report{_,PartialScan{reason,_}}: reason

def truncated(report: Report) -> Bool:
  match report:
    case Report{_,CompleteScan{}}: False{}
    case Report{_,PartialScan{_,truncated}}: truncated
