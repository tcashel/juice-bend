# Strict, pure protocol for the whole pinned captured-session Usage view.
# A closed schema rejects duplicate keys and wrong types before reading fields.
import Base
import ./json.bend as Json
import ./gui_settings.bend as Shape
import ./gui_files.bend as F
import ./gui_relations.bend as R
import ./query.bend as Query
import ./provenance.bend as P

type Report is Data:
  Report{capture: Json.Json,text: String,scan_complete: Bool,bucket_complete: Bool,attribution_complete: Bool}

def text(+value: Json.Json,budget: U32) -> Bool:
  F.text_valid(value) && Bool.not(String.contains(Json.text(value),"\0")) && R.fits(Json.text(value),budget)

def nullable_text(value: Json.Json,budget: U32) -> Bool:
  match value:
    case Json.JNull{}: True{}
    case +value: text(value,budget) && Bool.not(String.is_empty(Json.text(value)))

def uint_string(+value: Json.Json) -> Bool:
  F.text_valid(value) && F.number_valid(Json.JNumber{Json.text(value)})

def exact(+value: Json.Json,keys: List<&2,String>) -> Bool:
  Shape.exact_object(value,keys)

def numbers(+value: Json.Json,keys: List<&2,String>,+maximum: U32) -> Bool:
  match keys:
    case []: True{}
    case +key <> rest:
      F.number_valid(Json.field(value,key)) && U32.is_le(F.number(Json.get(value,key)),maximum) && numbers(value,rest,maximum)

def flag(value: Json.Json) -> Bool:
  match value:
    case Json.JBool{value}: value
    case _: False{}

def same(a: Bool,b: Bool) -> Bool:
  Bool.not(Bool.xor(a,b))

def scope(filters: Query.Filters) -> Bool:
  Query.Filters{_,_,repo,role,after} = filters
  String.is_empty(repo) && String.is_empty(role) && String.is_empty(after)

def capture(+value: Json.Json,+snapshot: String,filters: Query.Filters) -> Bool:
  Query.Filters{_,+provider,_,_,_} = filters
  exact(value,["provider","source_id","source","generation","snapshot","extent","records"]) &&
    text(Json.field(value,"provider"),16) && Shape.provider(Json.get(value,"provider")) &&
    (String.is_empty(provider) || String.eq(provider,Json.get(value,"provider"))) &&
    R.id(Json.field(value,"source_id")) && R.id(Json.field(value,"generation")) && R.id(Json.field(value,"snapshot")) &&
    String.eq(Json.get(value,"snapshot"),snapshot) && text(Json.field(value,"source"),8192) &&
    String.starts_with(Json.get(value,"source"),"/") && uint_string(Json.field(value,"extent")) && uint_string(Json.field(value,"records"))

# The UI command has no configurable limits. An acknowledgement must match the
# exact default request rather than silently accepting a larger or smaller scan.
def limits(+value: Json.Json) -> Bool:
  exact(value,["records","bytes","keys","descriptor_bytes"]) &&
    Shape.number_is(Json.field(value,"records"),"1000000") && Shape.number_is(Json.field(value,"bytes"),"1073741824") &&
    Shape.number_is(Json.field(value,"keys"),"100000") && Shape.number_is(Json.field(value,"descriptor_bytes"),"16777216")

def witnesses(values: List<&2,Json.Json>,+total: U32) -> Bool:
  match values:
    case []: True{}
    case +value <> rest:
      exact(value,["physical_record","reason"]) && F.number_valid(Json.field(value,"physical_record")) &&
        U32.is_lt(F.number(Json.get(value,"physical_record")),total) && text(Json.field(value,"reason"),512) && witnesses(rest,total)

def coverage(+value: Json.Json,+processed: U32,total: U32) -> Bool:
  exact(value,["decoded","malformed","oversized","issues","witnesses"]) &&
    numbers(value,["decoded","malformed","oversized","issues"],processed) &&
    U32.is_eq(U32.add(U32.add(F.number(Json.get(value,"decoded")),F.number(Json.get(value,"malformed"))),F.number(Json.get(value,"oversized"))),processed) &&
    R.array(Json.field(value,"witnesses")) && Nat.is_le(List.length(&2,Json.Json,Json.items(Json.field(value,"witnesses"))),16n) &&
    witnesses(Json.items(Json.field(value,"witnesses")),total)

def covered(+value: Json.Json) -> Bool:
  String.eq(Json.get(value,"malformed"),"0") && String.eq(Json.get(value,"oversized"),"0") && String.eq(Json.get(value,"issues"),"0")

def counter(value: Json.Json) -> Bool:
  match value:
    case Json.JNull{}: True{}
    case Json.JString{+number}: P.decimal_valid(number) && Nat.is_le(String.length(number),70n)
    case _: False{}

def counters(+value: Json.Json) -> Bool:
  exact(value,["input_tokens","cached_input_tokens","cache_creation_input_tokens","cache_creation_1h_input_tokens","output_tokens"]) &&
    counter(Json.field(value,"input_tokens")) && counter(Json.field(value,"cached_input_tokens")) &&
    counter(Json.field(value,"cache_creation_input_tokens")) && counter(Json.field(value,"cache_creation_1h_input_tokens")) &&
    counter(Json.field(value,"output_tokens"))

def known(+value: Json.Json,keys: List<&2,String>) -> Bool:
  match keys:
    case []: True{}
    case key <> rest: F.text_valid(Json.field(value,key)) && known(value,rest)

def unknown(+value: Json.Json,keys: List<&2,String>) -> Bool:
  match keys:
    case []: True{}
    case key <> rest: R.null(Json.field(value,key)) && unknown(value,rest)

def claude_completeness(+value: Json.Json) -> Bool:
  (Bool.not(flag(Json.field(value,"bucket_complete"))) ||
    (U32.is_gt(F.number(Json.get(value,"usage_records")),0) && String.eq(Json.get(value,"missing_ids"),"0") &&
      String.eq(Json.get(value,"incomplete_observations"),"0") &&
      known(Json.field(value,"observed"),["input_tokens","cached_input_tokens","cache_creation_input_tokens","output_tokens"]))) &&
    (Bool.not(flag(Json.field(value,"attribution_complete"))) ||
      (flag(Json.field(value,"bucket_complete")) && F.text_valid(Json.field(value,"source_session_path_association")) &&
        String.eq(Json.get(value,"conflicting_calls"),"0") && unknown(Json.field(value,"unattributed"),
          ["input_tokens","cached_input_tokens","cache_creation_input_tokens","cache_creation_1h_input_tokens","output_tokens"])))

def claude(+value: Json.Json,+processed: U32) -> Bool:
  exact(value,["provider","source_session_path_association","observed","source_associated","copied_session","unattributed",
    "usage_records","distinct_call_keys","descriptor_bytes","missing_ids","incomplete_observations","conflicting_calls",
    "repeat_observations","bucket_complete","attribution_complete"]) &&
    nullable_text(Json.field(value,"source_session_path_association"),8192) &&
    counters(Json.field(value,"observed")) && counters(Json.field(value,"source_associated")) &&
    counters(Json.field(value,"copied_session")) && counters(Json.field(value,"unattributed")) &&
    numbers(value,["usage_records","missing_ids","incomplete_observations","conflicting_calls","repeat_observations"],processed) &&
    numbers(value,["distinct_call_keys"],U32.min(processed,100000)) && numbers(value,["descriptor_bytes"],16777216) &&
    Shape.boolean(Json.field(value,"bucket_complete")) && Shape.boolean(Json.field(value,"attribution_complete")) && claude_completeness(value)

def ordinal(value: Json.Json,total: U32) -> Bool:
  match value:
    case Json.JNull{}: True{}
    case +value: uint_string(value) && U32.is_lt(F.number(Json.text(value)),total)

def category(+value: Json.Json) -> Bool:
  Shape.text_is(value,"ordinary") || Shape.text_is(value,"fork") || Shape.text_is(value,"reviewer") || Shape.text_is(value,"unknown")

def fork_basis(+value: Json.Json) -> Bool:
  Shape.text_is(value,"none") || Shape.text_is(value,"unresolved") || Shape.text_is(value,"uuid_v7_turn") || Shape.text_is(value,"codex_0_130_record_policy")

def codex_completeness(+value: Json.Json) -> Bool:
  Bool.not(flag(Json.field(value,"accounting_complete"))) ||
    (Bool.not(String.eq(Json.get(value,"category"),"unknown")) && String.eq(Json.get(value,"uncertain"),"0") &&
      known(Json.field(value,"accounted"),["input_tokens","cached_input_tokens","output_tokens"]) &&
      (String.eq(Json.get(value,"fork_basis"),"none") || String.eq(Json.get(value,"fork_basis"),"uuid_v7_turn")))

def codex(+value: Json.Json,+processed: U32) -> Bool:
  exact(value,["provider","category","session","recorded_parent_thread_id","fork_basis","accounted","observations",
    "accepted","duplicates","resets","excluded","uncertain","first_ordinal","last_ordinal","accounting_complete"]) &&
    category(Json.field(value,"category")) && nullable_text(Json.field(value,"session"),8192) &&
    nullable_text(Json.field(value,"recorded_parent_thread_id"),8192) && fork_basis(Json.field(value,"fork_basis")) &&
    counters(Json.field(value,"accounted")) && numbers(value,["observations","accepted","duplicates","resets","excluded","uncertain"],processed) &&
    U32.is_eq(U32.add(U32.add(F.number(Json.get(value,"accepted")),F.number(Json.get(value,"duplicates"))),F.number(Json.get(value,"excluded"))),F.number(Json.get(value,"observations"))) &&
    U32.is_le(F.number(Json.get(value,"resets")),F.number(Json.get(value,"accepted"))) &&
    ordinal(Json.field(value,"first_ordinal"),processed) && ordinal(Json.field(value,"last_ordinal"),processed) &&
    Shape.boolean(Json.field(value,"accounting_complete")) && codex_completeness(value)

def summary(+value: Json.Json,+provider: String,+processed: U32) -> Bool:
  Shape.text_is(Json.field(value,"provider"),provider) &&
    Bool.pick(Bool,String.eq(provider,"claude"),claude(value,processed),codex(value,processed))

def summary_flag(+value: Json.Json,name: String) -> Bool:
  flag(Json.field(value,Bool.pick(String,String.eq(Json.get(value,"provider"),"claude"),name,"accounting_complete")))

def semantics(+value: Json.Json) -> Bool:
  +captured = Json.field(value,"capture")
  +processed = F.number(Json.get(value,"processed_records"))
  +bytes = F.number(Json.get(value,"verified_bytes"))
  +scanned = flag(Json.field(value,"scan_complete"))
  +quality = Json.field(value,"coverage")
  +facts = Json.field(value,"summary")
  U32.is_le(processed,F.number(Json.get(captured,"records"))) && U32.is_le(bytes,F.number(Json.get(captured,"extent"))) &&
    (Bool.not(scanned) || (String.eq(Json.get(value,"processed_records"),Json.get(captured,"records")) &&
      String.eq(Json.get(value,"verified_bytes"),Json.get(captured,"extent")))) &&
    coverage(quality,processed,F.number(Json.get(captured,"records"))) && summary(facts,Json.get(captured,"provider"),processed) &&
    same(flag(Json.field(value,"bucket_complete")),scanned && covered(quality) && summary_flag(facts,"bucket_complete")) &&
    same(flag(Json.field(value,"attribution_complete")),scanned && covered(quality) && summary_flag(facts,"attribution_complete"))

def valid(+value: Json.Json,snapshot: String,+filters: Query.Filters) -> Bool:
  exact(value,["kind","capture","processed_records","verified_bytes","scan_complete","bucket_complete","attribution_complete",
    "stop_reason","limits","coverage","summary","text"]) && Shape.text_is(Json.field(value,"kind"),"session_usage") &&
    scope(filters) && capture(Json.field(value,"capture"),snapshot,filters) && limits(Json.field(value,"limits")) &&
    numbers(value,["processed_records"],1000000) && numbers(value,["verified_bytes"],1073741824) &&
    Shape.boolean(Json.field(value,"scan_complete")) && Shape.boolean(Json.field(value,"bucket_complete")) &&
    Shape.boolean(Json.field(value,"attribution_complete")) && text(Json.field(value,"stop_reason"),512) &&
    text(Json.field(value,"text"),1048575) && semantics(value)

def decoded(+value: Json.Json,valid: Bool) -> Result<&2,&2,String,Report>:
  match valid:
    case False{}: Fail{"Usage reply violated its pinned capture, field types, limits or coverage contract. Current evidence is unchanged."}
    case True{}: Done{Report{Json.field(value,"capture"),Json.get(value,"text"),flag(Json.field(value,"scan_complete")),
      flag(Json.field(value,"bucket_complete")),flag(Json.field(value,"attribution_complete"))}}

def decode(+value: Json.Json,snapshot: String,filters: Query.Filters) -> Result<&2,&2,String,Report>:
  decoded(value,valid(value,snapshot,filters))

def description(value: Report) -> String:
  Report{_,_,scan,buckets,attribution} = value
  "Whole captured session | scan " ++ Bool.pick(String,scan,"complete","INCOMPLETE") ++
    " | buckets " ++ Bool.pick(String,buckets,"complete","unknown/partial") ++
    " | attribution " ++ Bool.pick(String,attribution,"complete","unknown/partial") ++ ". Back restores the original range."

def displayed(value: Report) -> String:
  Report{_,text,_,_,_} = value
  "WHOLE CAPTURED SESSION USAGE\nThis report covers the pinned snapshot, not just the original visible range.\nBack restores that range and its text selection. Why and Tools use the original range.\n\n" ++ text
