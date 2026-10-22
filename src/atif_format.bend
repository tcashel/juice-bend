import Base
import ./atif_types.bend as T
import ./providers.bend as Providers
import ./json.bend as J
import ./domain.bend as D
import ./session_usage.bend as U
import ./session_usage_cli.bend as UC
import ./session_usage_counts.bend as Counts
import ./session_usage_claude.bend as Claude
import ./session_usage_codex.bend as Codex

# Official Harbor immutable schema pin; the exporter is distinct from the
# originating agent. Missing version is disclosed, never replaced by ours.
def schema_pin() -> String:
  "09f5b964f8e5075f7e52fd08c9994dfc80ad5d24"

def optional(key: String,+value: String) -> String:
  Bool.pick(String,String.is_empty(value),"","," ++ J.quote(key) ++ ":" ++ J.quote(value))

def number(key: String,+value: String) -> String:
  Bool.pick(String,String.is_empty(value),"","," ++ J.quote(key) ++ ":" ++ value)

def opening(origin: T.Origin) -> String:
  T.Origin{U.Capture{provider,_,_,_,snapshot,_,_},_,_} = origin
  "{\"schema_version\":\"ATIF-v1.8\",\"trajectory_id\":" ++ J.quote("juice-bend-snapshot-" ++ snapshot) ++
    ",\"agent\":{\"name\":" ++ J.quote(provider) ++ ",\"version\":\"unknown\",\"extra\":{\"juice_bend\":{\"version_known\":false}}}," ++
    "\"notes\":\"Complete traversal of one retained capture, not a claim of complete agent history. Text subset; attachment bytes, raw provider records and related trajectories are not embedded. Exact raw records remain separately exportable from the retained library. Step order follows retained records except that an unambiguously paired later result is attached to its call step; exact original result position remains in its citation. Unknown inference counts, cost, copied-context status and provider version are not inferred.\",\"steps\":["

def citation(origin: T.Origin,event: T.AtifEvent) -> String:
  T.Origin{U.Capture{provider,source,locator,generation,snapshot,_,_},space,_} = origin
  T.AtifEvent{number,record,slot,offset,length,digest,complete,oversized,_,_} = event
  "{\"provider\":" ++ J.quote(provider) ++ ",\"source_id\":" ++ J.quote(source) ++
    ",\"locator\":" ++ J.quote(locator) ++ ",\"generation\":" ++ J.quote(generation) ++
    ",\"snapshot\":" ++ J.quote(snapshot) ++ ",\"event\":" ++ U32.show(number) ++
    ",\"record\":" ++ U32.show(record) ++ ",\"slot\":" ++ U32.show(slot) ++
    ",\"offset\":" ++ U32.show(offset) ++ ",\"length\":" ++ U32.show(length) ++
    ",\"raw_commitment\":" ++ J.quote(digest) ++ ",\"byte_space\":" ++ J.quote(space) ++
    ",\"record_complete\":" ++ U.boolean(complete) ++ ",\"oversized_fragment\":" ++ U.boolean(oversized) ++ "}"

def metadata_value(value: Providers.Record) -> String:
  Providers.ProviderEvent{role,body,tool,call,args,result,repo,session,stamp,model,usage,parent,coverage} = value
  "{\"role\":" ++ J.quote(role) ++ ",\"text\":" ++ J.quote(body) ++
    ",\"tool\":" ++ J.quote(tool) ++ ",\"provider_call_id\":" ++ J.quote(call) ++
    ",\"arguments\":" ++ J.quote(args) ++ ",\"result\":" ++ J.quote(result) ++
    ",\"repository\":" ++ J.quote(repo) ++ ",\"session\":" ++ J.quote(session) ++
    ",\"timestamp\":" ++ J.quote(stamp) ++ ",\"model\":" ++ J.quote(model) ++
    ",\"usage\":" ++ J.quote(usage) ++ ",\"parent\":" ++ J.quote(parent) ++
    ",\"coverage\":" ++ J.quote(coverage) ++ "}"

def metadata(+origin: T.Origin,+event: T.AtifEvent,pairing: String) -> String:
  T.AtifEvent{_,_,_,_,_,_,_,_,recorded,value} = event
  "{\"juice_bend\":{\"citation\":" ++ citation(origin,event) ++
    ",\"pairing\":" ++ J.quote(pairing) ++ ",\"recorded_metadata\":" ++ recorded ++
    ",\"normalized_event\":" ++ metadata_value(value) ++ "}}"

def call_id(event: T.AtifEvent) -> String:
  T.AtifEvent{number,_,_,_,_,_,_,_,_,_} = event
  "jb-call-" ++ U32.show(number)

def arguments(value: Result<&2,&2,String,J.Json>) -> String & Bool:
  match value:
    case Done{J.JObject{fields}}: (J.encode(J.JObject{fields}),True{})
    case _: ("{}",False{})

def tool_json(event: T.AtifEvent,args: String & Bool) -> String:
  T.AtifEvent{+number,_,_,_,_,_,_,_,_,Providers.ProviderEvent{_,_,tool,call,raw,_,_,_,_,_,_,_,_}} = event
  (json,captured) = args
  "{\"tool_call_id\":" ++ J.quote("jb-call-" ++ U32.show(number)) ++
    ",\"function_name\":" ++ J.quote(tool) ++ ",\"arguments\":" ++ json ++
    ",\"extra\":{\"juice_bend\":{\"provider_call_id\":" ++ J.quote(call) ++
    ",\"arguments_captured\":" ++ U.boolean(captured) ++ ",\"recorded_arguments\":" ++ J.quote(raw) ++ "}}}"

def tool(+event: T.AtifEvent) -> String:
  T.AtifEvent{_,_,_,_,_,_,_,_,_,Providers.ProviderEvent{_,_,_,_,args,_,_,_,_,_,_,_,_}} = event
  tool_json(event,arguments(J.parse(args)))

def result_text(event: T.AtifEvent) -> String:
  T.AtifEvent{_,_,_,_,_,_,_,_,_,Providers.ProviderEvent{_,body,_,_,_,+result,_,_,_,_,_,_,_}} = event
  Bool.pick(String,String.is_empty(result),body,result)

def observation(origin: T.Origin,+event: T.AtifEvent,call: String,pairing: String) -> String:
  ",\"observation\":{\"results\":[{\"content\":" ++ J.quote(result_text(event)) ++
    optional("source_call_id",call) ++ ",\"extra\":" ++ metadata(origin,event,pairing) ++ "}]}"

def paired(origin: T.Origin,event: Maybe<&2,T.AtifEvent>,call: String) -> String:
  match event:
    case None{}: ""
    case Some{result}: observation(origin,result,call,"unique retained session and provider call ID; result later than call")

def source(+role: String,tool: String) -> String:
  Bool.pick(String,Bool.not(String.is_empty(tool)),"agent",
    Bool.pick(String,String.eq(role,"user"),"user",
      Bool.pick(String,String.eq(role,"assistant") || String.eq(role,"thinking"),"agent","system")))

def body_fields(+origin: T.Origin,+event: T.AtifEvent,result: Maybe<&2,T.AtifEvent>,pairing: String) -> String:
  T.AtifEvent{_,_,_,_,_,_,_,_,_,Providers.ProviderEvent{+role,+body,+tool_name,_,_,_,_,_,stamp,model,_,_,_}} = event
  +who = source(role,tool_name)
  ",\"source\":" ++ J.quote(who) ++ ",\"message\":" ++
    J.quote(Bool.pick(String,String.eq(role,"thinking"),"",body)) ++ optional("timestamp",stamp) ++
    Bool.pick(String,String.eq(who,"agent"),optional("model_name",model),"") ++
    Bool.pick(String,String.eq(role,"thinking"),",\"reasoning_content\":" ++ J.quote(body),"") ++
    Bool.pick(String,String.is_empty(tool_name),"",",\"tool_calls\":[" ++ tool(event) ++ "]") ++
    Bool.pick(String,String.eq(role,"tool"),observation(origin,event,"",pairing),paired(origin,result,call_id(event)))

def parsed_step(parsed: Result<&2,&2,String,J.Json>,text: String) -> Result<&2,&2,T.Failure,String>:
  match parsed:
    case Done{J.JObject{_}}: Done{text}
    case _: T.failure(String,"atif_step_json","ATIF step could not be independently reparsed within the JSON parser envelope")

def step(+origin: T.Origin,+event: T.AtifEvent,result: Maybe<&2,T.AtifEvent>,id: U32,+pairing: String) -> Result<&2,&2,T.Failure,String>:
  +text = "{\"step_id\":" ++ U32.show(id) ++ body_fields(origin,event,result,pairing) ++
    ",\"extra\":" ++ metadata(origin,event,pairing) ++ "}"
  do Result<&2,&2,T.Failure,String>:
    T.check(Nat.is_le(List.length(&2,U32,D.encode(text)),2097152n),"atif_step_limit","ATIF step exceeds the 2 MiB supported envelope")
    parsed_step(J.parse(text),text)

def totals_counts(counts: Counts.Counters,claude: Bool) -> String:
  Counts.Counters{input,+cached,created,_,output} = counts
  +prompt = Counts.known_sum(Counts.known_sum(input,cached),Bool.pick(String,claude,created,"0"))
  number("total_prompt_tokens",prompt) ++ number("total_completion_tokens",output) ++ number("total_cached_tokens",cached)

def totals(summary: U.Summary) -> String:
  match summary:
    case U.ClaudeSummary{Claude.Report{_,_,_,observed,_,_,_,_,_,_,_,_,_,_}}: totals_counts(observed,True{})
    case U.CodexSummary{Codex.Report{_,_,_,_,accounted,_,_,_,_,_,_,_,_,_}}: totals_counts(accounted,False{})

def closing(origin: T.Origin,report: U.Report,events: U32,+steps: U32) -> String:
  T.Origin{+capture,space,archive} = origin
  U.Capture{_,_,_,_,_,total_bytes,total_records} = capture
  U.Report{_,limits,records,bytes,+scan,+buckets,+attribution,reason,coverage,+summary} = report
  "],\"final_metrics\":{\"total_steps\":" ++ U32.show(steps) ++
    Bool.pick(String,scan && buckets && attribution,totals(summary),"") ++
    "},\"extra\":{\"juice_bend\":{\"exporter\":{\"name\":\"Juice Bend\",\"format_revision\":\"atif-retained-v1\",\"official_schema_commit\":" ++ J.quote(schema_pin()) ++
    "},\"capture\":" ++ U.capture_text(capture) ++ ",\"byte_space\":" ++ J.quote(space) ++
    ",\"archive_origin\":" ++ archive ++ ",\"retained_scan_complete\":" ++ "true" ++
    ",\"processed_records\":" ++ U32.show(total_records) ++ ",\"verified_bytes\":" ++ U32.show(total_bytes) ++
    ",\"normalized_events\":" ++ U32.show(events) ++ ",\"exported_steps\":" ++ U32.show(steps) ++
    ",\"attachment_bytes_embedded\":false,\"related_trajectories_traversed\":false," ++
    "\"record_index_base\":0,\"event_index_base\":0,\"coverage_interpretation\":\"All retained records traversed. Provider decoding, metadata, copied context, attachment and usage completeness are independent; unsupported and unmapped records remain explicit steps.\"," ++
    "\"usage\":{\"processed_records\":" ++ U32.show(records) ++ ",\"verified_bytes\":" ++ U32.show(bytes) ++ ",\"scan_complete\":" ++ U.boolean(scan) ++ ",\"bucket_complete\":" ++ U.boolean(buckets) ++
    ",\"attribution_complete\":" ++ U.boolean(attribution) ++ ",\"stop_reason\":" ++ J.quote(reason) ++
    ",\"limits\":" ++ UC.limits_json(limits) ++ ",\"coverage\":" ++ UC.coverage_json(coverage) ++
    ",\"summary\":" ++ UC.summary_json(summary) ++ "}}}}\n"
