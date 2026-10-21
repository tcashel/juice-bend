import Base
import ../src/session_usage_codex.bend as Codex
import ../src/session_usage_counts.bend as Counts
import ../src/json.bend as Json

# Independent synthetic counter oracles. No original rollout/source is read.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parse_result(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def json(text: String) -> Json.Json:
  parse_result(Json.parse(text))

def meta(session: String,+source: String,+fork: String,stamp: String) -> Json.Json:
  json("{\"type\":\"session_meta\",\"payload\":{\"id\":" ++ Json.quote(session) ++
    ",\"source\":" ++ source ++ ",\"timestamp\":" ++ Json.quote(stamp) ++
    Bool.pick(String,String.is_empty(fork),"",",\"forked_from_id\":" ++ Json.quote(fork)) ++ "}}")

def ordinary() -> Json.Json:
  meta("synthetic-session","\"cli\"","","1970-01-01T00:00:01.000Z")

def buckets(input: String,cached: String,output: String) -> String:
  "{\"input_tokens\":" ++ input ++ ",\"cached_input_tokens\":" ++ cached ++ ",\"output_tokens\":" ++ output ++ "}"

def usage(total: String,+call: String) -> Json.Json:
  json("{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":" ++
    total ++ Bool.pick(String,String.is_empty(call),"",",\"last_token_usage\":" ++ call) ++ "}}}")

def total(input: String,cached: String,output: String) -> Json.Json:
  usage(buckets(input,cached,output),"")

def turn(id: String) -> Json.Json:
  json("{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\",\"turn_id\":" ++ Json.quote(id) ++ "}}")

def item(kind: String) -> Json.Json:
  json("{\"type\":\"response_item\",\"payload\":{\"type\":" ++ Json.quote(kind) ++ "}}")

def wrapped(kind: String,payload: Json.Json) -> Json.Json:
  Json.JObject{[Json.JField{"type",Json.JString{kind}},Json.JField{"payload",payload}]}

def walk(records: List<&2,Json.Json>,state: Codex.State,+index: U32) -> Codex.State:
  match records:
    case []: state
    case row <> rest: walk(rest,Codex.observe(state,index,row),U32.inc(index))

def run(records: List<&2,Json.Json>) -> Codex.Report:
  Codex.report(walk(records,Codex.new(),0))

def shape(report: Codex.Report) -> String:
  Codex.Report{category,_,_,basis,Counts.Counters{input,cached,_,_,output},o,a,d,r,e,u,f,l,complete} = report
  category ++ "|" ++ basis ++ "|" ++ input ++ "," ++ cached ++ "," ++ output ++ "|" ++
    U32.show(o) ++ "," ++ U32.show(a) ++ "," ++ U32.show(d) ++ "," ++ U32.show(r) ++ "," ++
    U32.show(e) ++ "," ++ U32.show(u) ++ "|" ++ f ++ "," ++ l ++ "|" ++
    Bool.pick(String,complete,"complete","partial")

def result(records: List<&2,Json.Json>,expected: String,label: String) -> IO(Unit):
  check(String.eq(shape(run(records)),expected),label)

def actor(report: Codex.Report) -> String:
  Codex.Report{category,session,parent,_,_,_,_,_,_,_,_,_,_,_} = report
  category ++ "|" ++ session ++ "|" ++ parent

def ordinary_cases() -> IO(Unit):
  do IO<Unit>:
    result([ordinary(),total("100","20","5"),total("240","70","11")],
      "ordinary|none|170,70,11|2,2,0,0,0,0|1,2|complete","first valid ordinary total and later normalized growth count exactly")
    result([ordinary(),total("100","20","5"),usage(buckets("100","20","5"),buckets("100","20","5"))],
      "ordinary|none|80,20,5|2,1,1,0,0,0|1,2|complete","identical cumulative total wins over repeated last-call reset marker")
    result([ordinary(),total("100","20","5"),total("240","70","11"),usage(buckets("90","10","3"),buckets("90","10","3"))],
      "ordinary|none|250,80,14|3,3,0,1,0,0|1,3|complete","full restart preserves usage before reset and counts fresh call")
    result([ordinary(),total("240","70","11"),usage(buckets("300","200","9"),buckets("40","10","2"))],
      "ordinary|none|200,80,13|2,2,0,1,0,0|1,2|complete","one decreasing normalized bucket selects recorded last-call counters")
    result([ordinary(),total("240","70","11"),usage(buckets("300","80","20"),buckets("300","80","20"))],
      "ordinary|none|390,150,31|2,2,0,1,0,0|1,2|complete","new total equal to last call resets even when every bucket increases")
    result([ordinary(),total("240","70","11"),total("90","10","3")],
      "ordinary|none|250,80,14|2,2,0,1,0,0|1,2|complete","reset without last-call counts the new recorded total")
    result([ordinary(),total("10","25","5")],
      "ordinary|none|0,25,5|1,1,0,0,0,0|1,1|complete","cached overshoot cannot make negative noncached input")
    result([ordinary(),total("0","0","0")],
      "ordinary|none|0,0,0|1,1,0,0,0,0|1,1|complete","explicit typed zero is distinct from missing usage")
    result([ordinary()],"ordinary|none|,,|0,0,0,0,0,0|,|partial","no recorded counters remain unknown rather than known zero")
    result([ordinary(),total("9007199254740993","1","9007199254740995"),total("9007199254741003","2","9007199254741005")],
      "ordinary|none|9007199254741001,2,9007199254741005|2,2,0,0,0,0|1,2|complete","counters above2^53 remain exact across subtraction and addition")

def malformed_cases() -> IO(Unit):
  +state = walk([ordinary(),total("100","20","5")],Codex.new(),0)
  do IO<Unit>:
    result([ordinary(),total("100","20","5"),usage("{\"input_tokens\":200,\"output_tokens\":9}",""),total("240","70","11"),total("340","80","16")],
      "ordinary|none|170,30,10|4,2,0,0,2,2|1,4|partial","malformed total breaks continuity and next valid observation only rebaselines")
    result([ordinary(),usage(buckets("100","20","5"),"{}"),total("240","70","11")],
      "ordinary|none|,,|2,0,0,0,2,2|1,2|partial","invalid supplied last-call never silently becomes absent or a fresh baseline")
    result([ordinary(),usage(buckets("\"100\"","20","5"),""),total("240","70","11")],
      "ordinary|none|,,|2,0,0,0,2,2|1,2|partial","string token count cannot coerce to an integer")
    result([ordinary(),total("-1","0","0"),total("1.5","0","0"),total("1e3","0","0")],
      "ordinary|none|,,|3,0,0,0,3,3|1,3|partial","negative fractional and exponent token lexemes stay unknown")
    result([ordinary(),total("100","20","5"),json("{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":null}}"),total("240","70","11")],
      "ordinary|none|170,70,11|3,2,0,0,1,0|1,3|complete","explicit null info carries no usage and does not invent a reset")
    result([total("100","20","5"),ordinary(),total("240","70","11"),total("340","80","16")],
      "ordinary|none|90,10,5|3,1,0,0,2,2|0,3|partial","usage before authoritative metadata cannot be retroactively attributed")
    check(String.eq(shape(Codex.report(Codex.observe(Codex.invalid(state,2),3,total("240","70","11")))),
      "ordinary|none|80,20,5|2,1,0,0,1,2|1,3|partial"),"malformed physical record prevents cross-gap counter subtraction")
    check(String.eq(shape(Codex.report(Codex.observe(state,7,total("240","70","11")))),
      "ordinary|none|80,20,5|1,1,0,0,0,1|1,1|partial"),"out-of-order raw ordinal quarantines subsequent attribution")
    result([ordinary(),total("100","20","5"),json("17"),total("240","70","11")],
      "ordinary|none|80,20,5|2,1,0,0,1,2|1,3|partial","parsed scalar envelope prevents counter subtraction across unclassified data")
    result([ordinary(),total("100","20","5"),json("{\"type\":\"event_msg\",\"payload\":false}"),total("240","70","11")],
      "ordinary|none|80,20,5|2,1,0,0,1,2|1,3|partial","known envelope with nonobject payload interrupts continuity")
    result([ordinary(),total("100","20","5"),json("{\"type\":\"event_msg\",\"payload\":{\"type\":7}}"),total("240","70","11")],
      "ordinary|none|80,20,5|2,1,0,0,1,2|1,3|partial","nonstring nested event type cannot silently hide an accounting observation")
    result([ordinary(),total("100","20","5"),json("{\"type\":\"future_usage_envelope\",\"payload\":{}}"),total("240","70","11")],
      "ordinary|none|80,20,5|2,1,0,0,1,2|1,3|partial","unknown future outer envelope makes accounting explicitly incomplete")

def metadata_cases() -> IO(Unit):
  do IO<Unit>:
    result([json("{\"type\":\"session_meta\",\"payload\":{\"id\":42,\"source\":\"cli\"}}"),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","numeric session ID cannot become an accounting actor")
    result([json("{\"type\":\"session_meta\",\"payload\":{\"id\":\"s\"}}"),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","missing source kind keeps first metadata authority unknown")
    result([meta("s","\"future-kind\"","",""),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","unknown provider source kind does not enable full first total")
    result([ordinary(),ordinary(),total("100","20","5")],
      "ordinary|none|80,20,5|1,1,0,0,0,0|2,2|complete","matching repeated metadata preserves first authority")
    result([ordinary(),meta("other","\"cli\"","","1970-01-01T00:00:01Z"),total("100","20","5")],
      "ordinary|none|,,|1,0,0,0,1,2|2,2|partial","contradictory later session cannot replace first actor or admit later counters")
    result([ordinary(),meta("synthetic-session","\"cli\"","parent","1970-01-01T00:00:01Z"),total("100","20","5")],
      "ordinary|none|,,|1,0,0,0,1,2|2,2|partial","later fork declaration cannot upgrade first metadata")
    result([json("{\"type\":\"session_meta\",\"payload\":{\"id\":\"linked\",\"parent_thread_id\":\"parent\",\"source\":\"cli\"}}"),total("100","20","5")],
      "ordinary|none|80,20,5|1,1,0,0,0,0|1,1|complete","parent link alone never marks cumulative counters as inherited")
    result([json("{\"type\":\"session_meta\",\"payload\":{\"id\":\"linked\",\"forked_from_session_id\":\"parent\",\"source\":\"cli\"}}"),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","unsupported fork alias cannot silently admit an inherited prefix as ordinary usage")
    result([meta("child","{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":\"parent\"}}}","",""),total("100","20","5")],
      "ordinary|none|80,20,5|1,1,0,0,0,0|1,1|complete","typed thread_spawn parent without fork declaration remains ordinary accounting")
    result([meta(String.repeat("🙂",129n),"\"cli\"","",""),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","metadata IDs enforce512UTF8bytes rather than512scalars")
    result([meta("review","{\"subagent\":{\"other\":\"guardian\"}}","",""),total("100","20","5")],
      "reviewer|none|80,20,5|1,1,0,0,0,0|1,1|complete","explicit guardian counts in separate reviewer category only")
    result([meta("review","{\"subagent\":{\"other\":\"future\"}}","",""),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","unknown parentless subagent remains unattributed")
    result([json("{\"type\":\"session_meta\",\"payload\":{\"id\":\"s\",\"source\":\"cli\",\"forked_from_id\":17}}"),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","numeric fork ID cannot be reinterpreted as ordinary accounting")
    result([json("{\"type\":\"session_meta\",\"payload\":{\"id\":\"s\",\"source\":\"cli\",\"forked_from_id\":{\"id\":\"parent\"}}}"),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,2|1,1|partial","container fork ID cannot be string-coerced or silently ignored")
    result([meta("synthetic-session","\"future-kind\"","","1970-01-01T00:00:01Z"),ordinary(),total("100","20","5")],
      "unknown|none|,,|1,0,0,0,1,3|2,2|partial","later supported source cannot repair unknown first metadata authority")
    result([json("{\"type\":\"session_meta\",\"payload\":false}"),ordinary(),total("100","20","5"),total("240","70","11")],
      "unknown|none|,,|2,0,0,0,2,4|2,3|partial","malformed first session metadata still freezes unknown authority against later replacement")
    result([ordinary(),total("100","20","5"),meta("synthetic-session","{\"subagent\":{\"other\":\"guardian\"}}","","1970-01-01T00:00:01Z"),total("240","70","11")],
      "ordinary|none|80,20,5|2,1,0,0,1,2|1,3|partial","later reviewer category contradicts but cannot recategorize prior ordinary subtotal")

def fork_meta() -> Json.Json:
  meta("child","\"cli\"","parent","1970-01-01T00:00:01Z")

def constructed_cases() -> IO(Unit):
  duplicate_id = wrapped("session_meta",Json.JObject{[
    Json.JField{"id",Json.JString{"s"}},Json.JField{"id",Json.JString{"s"}},Json.JField{"source",Json.JString{"cli"}}]})
  duplicate_fork = wrapped("session_meta",Json.JObject{[
    Json.JField{"id",Json.JString{"s"}},Json.JField{"source",Json.JString{"cli"}},
    Json.JField{"forked_from_id",Json.JString{"parent"}},Json.JField{"forked_from_id",Json.JString{"parent"}}]})
  duplicate_count = wrapped("event_msg",Json.JObject{[
    Json.JField{"type",Json.JString{"token_count"}},Json.JField{"info",Json.JObject{[
      Json.JField{"total_token_usage",Json.JObject{[
        Json.JField{"input_tokens",Json.JNumber{"100"}},Json.JField{"input_tokens",Json.JNumber{"100"}},
        Json.JField{"cached_input_tokens",Json.JNumber{"20"}},Json.JField{"output_tokens",Json.JNumber{"5"}}]}}
    ]}}]})
  do IO<Unit>:
    result([duplicate_id,total("100","20","5")],"unknown|none|,,|1,0,0,0,1,2|1,1|partial",
      "constructed duplicate metadata ID is invalid even when its values agree")
    result([duplicate_fork,total("100","20","5")],"unknown|none|,,|1,0,0,0,1,2|1,1|partial",
      "constructed duplicate inheritance declarations cannot establish authority")
    result([ordinary(),duplicate_count,total("240","70","11")],"ordinary|none|,,|2,0,0,0,2,2|1,2|partial",
      "constructed duplicate counter fields interrupt continuity rather than select one value")
    check(String.eq(actor(run([meta("child","{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":\"parent\"}}}","","")])),"ordinary|child|parent"),
      "typed spawn metadata preserves session and recorded parent separately")
    check(String.eq(actor(run([ordinary(),meta("other","\"exec\"","parent","")])),"ordinary|synthetic-session|"),
      "contradictory metadata never replaces returned first session identity")

def fork_cases() -> IO(Unit):
  do IO<Unit>:
    result([fork_meta(),turn("00000000-03e7-7000-8000-000000000001"),item("reasoning"),total("1000","200","50")],
      "fork|unresolved|,,|1,0,0,0,1,0|3,3|partial","copied dated turn blocks reasoning fallback and never claims known zero")
    result([fork_meta(),total("1000","200","50"),turn("00000000-03e8-7000-8000-000000000001"),
      usage(buckets("1300","250","60"),buckets("300","50","10")),total("1700","350","80")],
      "fork|uuid_v7_turn|550,150,30|3,2,0,0,1,0|1,4|complete","first own timestamped turn counts its call and later own growth")
    result([fork_meta(),total("1000","200","50"),turn("00000000-03e9-7000-8000-000000000001"),total("1300","250","60")],
      "fork|uuid_v7_turn|250,50,10|2,1,0,0,1,0|1,3|complete","first own event without last-call subtracts the inherited baseline")
    result([fork_meta(),turn("00000000-03e9-7000-8000-000000000001"),total("1300","250","60")],
      "fork|uuid_v7_turn|,,|1,0,0,0,1,1|2,2|partial","first own event without prior total or last-call cannot count inherited whole total")
    result([fork_meta(),total("1000","200","50"),turn("00000000-03e9-7000-8000-000000000001"),total("100","20","5")],
      "fork|uuid_v7_turn|,,|2,0,0,0,2,1|1,3|partial","first own reset without last-call stays unknown rather than a complete zero")
    result([fork_meta(),total("1000","200","50"),turn("00000000-03e9-7000-8000-000000000001"),total("1300","150","60"),total("1500","200","70")],
      "fork|uuid_v7_turn|150,50,10|3,1,0,0,2,1|1,4|partial","mixed decreasing first-own buckets rebaseline before later own growth")
    result([fork_meta(),total("1000","200","50"),turn("undatable"),item("reasoning"),usage(buckets("1300","250","60"),buckets("300","50","10"))],
      "fork|codex_0_130_record_policy|250,50,10|2,1,0,0,1,0|1,4|partial","undatable fork fallback is explicitly named and not exact attribution")
    result([meta("child","\"cli\"","parent","1970-01-01T00:00:01.000000001Z"),
      turn("00000000-03e8-7000-8000-000000000001"),item("reasoning"),total("1300","250","60")],
      "fork|unresolved|,,|1,0,0,0,1,0|3,3|partial","submillisecond fork time prevents equal-floor UUID from starting child usage")
    result([fork_meta(),json("{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"phase\":\"final_answer\"}}"),total("1000","200","50")],
      "fork|unresolved|,,|1,0,0,0,1,0|2,2|partial","final assistant answer is not a never-copied boundary")
    result([fork_meta(),json("{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":99}}"),total("1000","200","50")],
      "fork|unresolved|,,|1,0,0,0,1,0|2,2|partial","numeric call ID cannot activate output-based fork fallback")
    result([fork_meta(),json("{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"phase\":42}}"),total("1000","200","50")],
      "fork|unresolved|,,|1,0,0,0,1,0|2,2|partial","malformed present assistant phase cannot activate fork fallback")
    result([meta("review","{\"subagent\":{\"other\":\"guardian\"}}","parent","1970-01-01T00:00:01Z"),
      total("1000","200","50"),turn("00000000-03e9-7000-8000-000000000001"),usage(buckets("1300","250","60"),buckets("300","50","10"))],
      "reviewer|uuid_v7_turn|250,50,10|2,1,0,0,1,0|1,3|complete","reviewer fork excludes copied counters while preserving separate reviewer category")
    result([fork_meta(),turn("00000000-03e7-7000-8000-000000000001"),item("reasoning"),total("1000","200","50"),
      turn("00000000-03e9-7000-8000-000000000001"),usage(buckets("1300","250","60"),buckets("300","50","10"))],
      "fork|uuid_v7_turn|250,50,10|2,1,0,0,1,0|3,5|complete","later dated own turn clears an earlier copied-turn block")
    result([fork_meta(),total("1000","200","50"),turn("00000000-03e9-7000-8000-000000000001"),
      usage(buckets("1300","250","60"),buckets("300","50","10")),usage(buckets("90","10","3"),buckets("90","10","3"))],
      "fork|uuid_v7_turn|330,60,13|3,2,0,1,1,0|1,4|complete","own fork counters retain subtotal through later recorded restart")

def epoch(value: Maybe<&2,Codex.Time>,ms: Nat,sub: U32) -> Bool:
  match value:
    case Some{Codex.Time{actual,tail}}: Nat.is_eq(actual,ms) && U32.is_eq(tail,sub)
    case None{}: False{}

def uuid(value: Maybe<&2,Nat>,expected: Maybe<&2,Nat>) -> Bool:
  match value expected:
    case None{} None{}: True{}
    case Some{a} Some{b}: Nat.is_eq(a,b)
    case _ _: False{}

def time_cases() -> IO(Unit):
  do IO<Unit>:
    check(epoch(Codex.time("1970-01-01T00:00:00Z"),0n,0),"timestamp epoch starts at exact zero")
    check(epoch(Codex.time("1970-01-01T01:00:01.000000001+01:00"),1000n,1),"offset normalization retains nanosecond boundary remainder")
    check(epoch(Codex.time("2000-01-01T00:00:00Z"),Nat.mul(946684800n,1000n),0),"Gregorian century epoch conversion matches independent constant")
    check(epoch(Codex.time("2000-03-01T00:00:00Z"),Nat.mul(951868800n,1000n),0),"Gregorian leap day conversion matches independent constant")
    check(epoch(Codex.time("9999-12-31T23:59:59.999999999Z"),Nat.add(Nat.mul(253402300n,1000000n),799999n),999999),"maximum supported timestamp fits exact native48bit milliseconds")
    check(uuid(Codex.uuid_time("00000000-03e8-7000-8000-000000000001"),Some{1000n}),"UUIDv7 reads exact first48bits")
    check(uuid(Codex.uuid_time("FFFFFFFF-FFFF-7FFF-BFFF-FFFFFFFFFFFF"),Some{Nat.add(Nat.mul(16777215n,16777216n),16777215n)}),"uppercase UUIDv7 preserves maximum48bit integer")
    check(uuid(Codex.uuid_time("00000000-03e8-4000-8000-000000000001"),None{}),"nonversion7 UUID cannot supply creation time")
    check(uuid(Codex.uuid_time("00000000-03e8-7000-0000-000000000001"),None{}),"invalid UUID variant cannot supply an own-work boundary")
    check(uuid(Codex.uuid_time("0000000003e870008000000000000001"),None{}),"compact noncanonical UUID is not silently accepted")

def main() -> IO(Unit):
  do IO<Unit>:
    ordinary_cases()
    malformed_cases()
    metadata_cases()
    constructed_cases()
    fork_cases()
    time_cases()
