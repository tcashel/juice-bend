import Base
import ../src/library_usage_wire.bend as W
import ../src/library_usage_types.bend as T
import ../src/session_usage.bend as S
import ../src/session_usage_counts.bend as Counts
import ../src/session_usage_claude.bend as Claude
import ../src/json.bend as J

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(text: String) -> J.Json:
  parsed(J.parse(text))

def capture_text() -> String:
  "{\"provider\":\"claude\",\"source_id\":\"9007199254740993\",\"source\":\"/synthetic/café 中文 🙂.jsonl\",\"generation\":\"7\",\"snapshot\":\"9223372036854775807\",\"extent\":\"4294967295\",\"records\":\"4294967295\"}"

def row_text() -> String:
  "{\"capture\":" ++ capture_text() ++ ",\"session\":\"synthetic-session\",\"sha256\":\"" ++ String.repeat("a",64n) ++
    "\",\"category\":\"ordinary\",\"counts\":{\"input\":\"10\",\"cached\":\"2\",\"created\":\"3\",\"created1h\":\"1\",\"output\":\"4\"},\"status\":\"eligible\",\"reason\":\"synthetic reason\"}"

def expected() -> String:
  "{\"kind\":\"library_usage\",\"version\":1,\"nonce\":7,\"catalog_complete\":true,\"selected_sources\":1,\"verified_records\":4,\"verified_bytes\":321,\"limits\":{\"sources\":256,\"records\":1000000,\"bytes\":134217728},\"rows\":[" ++ row_text() ++ "]}"

def replace(fields: List<&2,J.Field>,+key: String,+value: J.Json) -> List<&2,J.Field>:
  match fields:
    case []: []
    case J.JField{+name,+old} <> rest:
      J.JField{name,Bool.pick(J.Json,String.eq(name,key),value,old)} <> replace(rest,key,value)

def set(value: J.Json,key: String,field: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{replace(fields,key,field)}
    case _: J.JNull{}

def add(value: J.Json,key: String,field: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{J.JField{key,field} <> fields}
    case _: J.JNull{}

def removed(fields: List<&2,J.Field>,+key: String) -> List<&2,J.Field>:
  match fields:
    case []: []
    case J.JField{+name,value} <> rest:
      +tail : List<&2,J.Field> = removed(rest,key)
      Bool.pick(List<&2,J.Field>,String.eq(name,key),tail,J.JField{name,value} <> tail)

def remove(value: J.Json,key: String) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{removed(fields,key)}
    case _: J.JNull{}

def envelope(row: J.Json) -> J.Json:
  set(json(expected()),"rows",J.JArray{[row]})

def field(key: String,value: J.Json) -> J.Json:
  set(json(expected()),key,value)

def row_field(key: String,value: J.Json) -> J.Json:
  envelope(set(json(row_text()),key,value))

def capture_field(key: String,value: J.Json) -> J.Json:
  row_field("capture",set(json(capture_text()),key,value))

def count_field(key: String,value: J.Json) -> J.Json:
  row_field("counts",set(J.field(json(row_text()),"counts"),key,value))

def accepted(value: Result<&2,&2,String,T.Report>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def accept(value: J.Json) -> Bool:
  accepted(W.decode(value,7))

def reject(value: J.Json) -> Bool:
  Bool.not(accept(value))

def read(text: String) -> Result<&2,&2,String,T.Report>:
  W.completed(Done{(0,(text,""))},7)

def encoded(value: Result<&2,&2,String,String>) -> String:
  match value:
    case Done{text}: text
    case Fail{_}: "unexpected encode failure"

def encode_failed(value: Result<&2,&2,String,String>) -> Bool:
  match value:
    case Done{_}: False{}
    case Fail{_}: True{}

def typed_capture() -> S.Capture:
  S.Capture{"claude","9007199254740993","/synthetic/café 中文 🙂.jsonl","7","9223372036854775807",4294967295,4294967295}

def full_report() -> S.Report:
  S.Report{typed_capture(),S.defaults(),4,321,False{},False{},False{},"private-to-summary full evidence",
    S.Coverage{4,0,0,0,[]},S.ClaudeSummary{Claude.report(Claude.new("synthetic-session"))}}

def typed_row() -> T.CaptureRow:
  T.CaptureRow{typed_capture(),"synthetic-session",String.repeat("a",64n),"ordinary",Counts.Counters{"10","2","3","1","4"},
    "eligible","synthetic reason",Some{full_report()}}

def typed() -> T.Report:
  # Deliberately wrong aggregate projection; the wire never transmits it.
  T.Report{True{},1,4,321,T.defaults(),[typed_row()],T.Aggregate{False{},[],[]}}

def no_report(value: Maybe<&2,S.Report>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def exact_row(values: List<&2,T.CaptureRow>) -> Bool:
  match values:
    case [T.CaptureRow{capture,session,hash,category,counts,status,reason,report}]:
      String.eq(S.capture_text(capture),capture_text()) && String.eq(session,"synthetic-session") && String.eq(hash,String.repeat("a",64n)) &&
        String.eq(category,"ordinary") && Counts.equal(counts,Counts.Counters{"10","2","3","1","4"}) &&
        String.eq(status,"eligible") && String.eq(reason,"synthetic reason") && no_report(report)
    case _: False{}

def input_metric(values: List<&2,T.Provider>) -> String:
  match values:
    case T.Provider{"claude",sessions,aliases,_,_,T.Metric{sum,known,unknown,_},_,_,_,_} <> _:
      U32.show(sessions) ++ "/" ++ U32.show(aliases) ++ ":" ++ sum ++ ":" ++ U32.show(known) ++ ":" ++ U32.show(unknown)
    case _: "missing"

def metric(value: Result<&2,&2,String,T.Report>) -> String:
  match value:
    case Done{T.Report{_,_,_,_,_,_,T.Aggregate{_,providers,_}}}: input_metric(providers)
    case Fail{_}: "failed"

def roundtrip(value: Result<&2,&2,String,T.Report>) -> Bool:
  match value:
    case Done{T.Report{complete,sources,records,bytes,limits,rows,T.Aggregate{available,providers,decisions}}}:
      complete && U32.is_eq(sources,1) && U32.is_eq(records,4) && U32.is_eq(bytes,321) && W.default_limits(limits) && exact_row(rows) &&
        available && String.eq(input_metric(providers),"1/0:10:1:0") && Nat.is_eq(List.length(&2,T.Decision,decisions),1n)
    case Fail{_}: False{}

def baseline() -> IO(Unit):
  +out : String = encoded(W.encode(7,typed()))
  do IO<Unit>:
    check(String.eq(out,expected()),"encoder matches independently specified complete summary with exact signed64 and U32 identity")
    check(roundtrip(read(out ++ "\n")),"transport roundtrip preserves all row fields and rebuilds the aggregate while omitting full per-capture reports")
    check(Bool.not(String.contains(out,"private-to-summary")) && Bool.not(String.contains(out,"\"aggregate\"")) &&
      Bool.not(String.contains(out,"\"report\"")),"wire omits evidence bodies and precomputed aggregate authority")
    check(accept(json(expected())),"independent valid JSON fixture is accepted without the encoder")
    check(encode_failed(W.encode(0,typed())),"zero request identity is refused by the encoder")

def envelope_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(add(json(expected()),"extra",J.JNull{})) && reject(add(json(expected()),"nonce",J.JNumber{"7"})) &&
      reject(remove(json(expected()),"catalog_complete")),"closed envelope rejects unknown, duplicate and missing fields")
    check(reject(field("kind",J.JString{"session_usage"})) && reject(field("version",J.JNumber{"1.0"})) &&
      reject(field("nonce",J.JNumber{"8"})) && reject(field("nonce",J.JString{"7"})) && reject(field("nonce",J.JNumber{"07"})),
      "kind, version and exact canonical numeric nonce cannot be coerced")
    check(reject(field("catalog_complete",J.JString{"true"})) && reject(field("rows",J.JObject{[]})),"completion and rows require exact boolean and array types")
    check(reject(field("selected_sources",J.JNumber{"0"})) && reject(field("selected_sources",J.JNumber{"257"})) &&
      reject(field("verified_records",J.JNumber{"1000001"})) && reject(field("verified_bytes",J.JNumber{"134217729"})),
      "selected count matches rows and all envelope counters obey caps")
    check(reject(field("verified_records",J.JNumber{"-1"})) && reject(field("verified_records",J.JNumber{"1e3"})) &&
      reject(field("verified_bytes",J.JString{"321"})),"envelope counters reject negative, exponent and string forms")
    check(reject(field("limits",set(J.field(json(expected()),"limits"),"sources",J.JNumber{"255"}))) &&
      reject(field("limits",add(J.field(json(expected()),"limits"),"extra",J.JNumber{"0"}))),"default limits are exact and closed")
    check(reject(add(json(expected()),"aggregate",J.JObject{[]})),"untrusted aggregate projections are never admitted")

def identity_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(capture_field("source_id",J.JString{"0"})) && reject(capture_field("generation",J.JString{"07"})) &&
      reject(capture_field("snapshot",J.JString{"9223372036854775808"})) && reject(capture_field("source_id",J.JNumber{"1"})),
      "capture identifiers require positive canonical signed64 decimal strings")
    check(reject(capture_field("extent",J.JString{"4294967296"})) && reject(capture_field("records",J.JString{"-1"})) &&
      reject(capture_field("records",J.JNumber{"4"})),"capture extent and record count are exact canonical U32 strings")
    check(reject(capture_field("source",J.JString{"relative/file.jsonl"})) && reject(capture_field("source",J.JString{"/synthetic/\0x"})) &&
      reject(capture_field("provider",J.JString{"other"})),"capture source is absolute without NUL and provider is supported")
    check(reject(row_field("capture",add(json(capture_text()),"extra",J.JNull{}))) &&
      reject(row_field("capture",add(json(capture_text()),"snapshot",J.JString{"1"}))),"capture object rejects extra and duplicate identity fields")
    check(accept(capture_field("source",J.JString{"/" ++ String.repeat("é",4095n) ++ "x"})) &&
      reject(capture_field("source",J.JString{"/" ++ String.repeat("é",4096n)})),"capture path bound counts UTF-8 bytes, accepting exactly 8192")
    check(accept(row_field("session",J.JString{String.repeat("é",32768n)})) &&
      reject(row_field("session",J.JString{String.repeat("é",32769n)})) &&
      reject(row_field("reason",J.JString{String.repeat("é",32769n)})),"session and reason bounds count UTF-8 bytes")

def row_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(envelope(add(json(row_text()),"extra",J.JNull{}))) && reject(envelope(add(json(row_text()),"status",J.JString{"eligible"}))),
      "row object rejects unknown and duplicate fields")
    check(reject(row_field("category",J.JString{"inferred"})) && reject(row_field("status",J.JString{"included"})),
      "row category and backend classification are closed vocabularies")
    check(reject(row_field("sha256",J.JString{String.repeat("A",64n)})) && reject(row_field("sha256",J.JString{String.repeat("g",64n)})) &&
      reject(row_field("sha256",J.JString{String.repeat("a",63n)})) && accept(row_field("sha256",J.JString{""})),
      "SHA is empty or exactly 64 lowercase hexadecimal characters")
    check(reject(row_field("counts",remove(J.field(json(row_text()),"counts"),"cached"))) &&
      reject(row_field("counts",add(J.field(json(row_text()),"counts"),"input",J.JString{"10"}))) &&
      reject(row_field("counts",add(J.field(json(row_text()),"counts"),"total",J.JString{"10"}))),
      "counter object rejects missing, duplicate and invented buckets")
    check(reject(count_field("input",J.JNumber{"10"})) && reject(count_field("input",J.JString{"1e3"})) &&
      reject(count_field("input",J.JString{"01"})) && reject(count_field("input",J.JString{"-1"})) &&
      reject(count_field("input",J.JString{String.repeat("9",257n)})),"counters are empty or bounded canonical decimal strings")
    check(String.eq(metric(W.decode(count_field("input",J.JString{""}),7)),"1/0::0:1"),
      "explicit missing counter survives transport as an unknown contribution, never zero or a partial sum")
    check(String.eq(metric(W.decode(count_field("input",J.JString{"1" ++ String.repeat("0",64n)}),7)),
      "1/0:1" ++ String.repeat("0",64n) ++ ":1:0") &&
      String.eq(metric(W.decode(count_field("input",J.JString{"1" ++ String.repeat("0",68n)}),7)),
      "1/0:1" ++ String.repeat("0",68n) ++ ":1:0"),"65- and 69-digit retained reducer sums remain exact")

def unique_row(+n: Nat) -> J.Json:
  set(json(row_text()),"capture",set(set(json(capture_text()),"source_id",J.JString{Nat.show(n)}),"snapshot",J.JString{Nat.show(n)}))

def unique_rows(+n: Nat) -> List<&2,J.Json>:
  match n:
    case 0n: []
    case 1n+rest: unique_row(n) <> unique_rows(rest)

def rows_case(values: List<&2,J.Json>,count: String) -> J.Json:
  set(field("rows",J.JArray{values}),"selected_sources",J.JNumber{count})

def aggregate_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(rows_case([json(row_text()),json(row_text())],"2")),"repeated source and snapshot identity cannot multiply contributions")
    check(reject(rows_case([json(row_text()),set(json(row_text()),"capture",set(json(capture_text()),"snapshot",J.JString{"2"}))],"2")),
      "two snapshots for one source cannot enter the selected latest catalog")
    check(reject(rows_case([json(row_text()),set(json(row_text()),"capture",set(json(capture_text()),"source_id",J.JString{"2"}))],"2")),
      "two source rows cannot claim one snapshot")
    check(String.eq(metric(W.decode(rows_case([json(row_text()),unique_row(2n)],"2"),7)),"1/1:10:1:0"),
      "exact-byte session aliases are recomputed once from validated distinct captures")
    check(reject(rows_case(unique_rows(257n),"256")),"row count above 256 is rejected without a partial catalog")
    check(accept(set(set(rows_case([],"0"),"verified_records",J.JNumber{"0"}),"verified_bytes",J.JNumber{"0"})) &&
      reject(rows_case([],"0")),"empty catalog has zero verification counters rather than an invented scan")

def withheld(value: Result<&2,&2,String,T.Report>) -> Bool:
  match value:
    case Done{T.Report{complete,_,_,_,_,rows,T.Aggregate{available,providers,decisions}}}:
      Bool.not(complete || available) && List.is_empty(&2,T.Provider,providers) &&
        Nat.is_eq(List.length(&2,T.CaptureRow,rows),1n) && Nat.is_eq(List.length(&2,T.Decision,decisions),1n)
    case Fail{_}: False{}

def large_rows(+n: Nat,+reason: String) -> List<&2,T.CaptureRow>:
  match n:
    case 0n: []
    case 1n+rest:
      T.CaptureRow{S.Capture{"claude",Nat.show(n),"/synthetic/large.jsonl","1",Nat.show(n),1,1},"","","unknown",
        Counts.empty(),"limited",reason,None{}} <> large_rows(rest,reason)

def too_large() -> T.Report:
  T.Report{True{},33,0,0,T.defaults(),large_rows(33n,String.repeat("x",65536n)),T.Aggregate{False{},[],[]}}

def transport_cases() -> IO(Unit):
  do IO<Unit>:
    check(withheld(W.decode(field("catalog_complete",J.JBool{False{}}),7)),"incomplete catalog preserves capture rows while recomputed totals are withheld")
    check(Bool.not(accepted(read("{"))) && Bool.not(accepted(read(expected() ++ " trailing"))) &&
      Bool.not(accepted(W.completed(Done{(2,(expected(),""))},7))) && Bool.not(accepted(W.completed(Done{(0,(expected(),"diagnostic"))},7))),
      "malformed JSON, trailing material, nonzero exit and mixed stderr cannot produce a summary")
    check(Bool.not(accepted(W.completed(Fail{(5,"synthetic launch error")},7))) &&
      Bool.not(accepted(W.completed(Done{(0,(expected(),""))},8))),"launch failure and stale request identity are rejected")
    check(Bool.not(accepted(read(String.repeat(" ",2097153n)))),"raw stdout beyond 2 MiB is rejected before parsing, including whitespace")
    check(accepted(read(String.repeat(" ",1048577n) ++ expected() ++ "\n")),"admitted whitespace above the parser default uses bounded 2 MiB parser fuel")
    check(encode_failed(W.encode(7,too_large())),"oversized canonical summary fails whole instead of truncating rows or evidence identity")

def main() -> IO(Unit):
  do IO<Unit>:
    baseline()
    envelope_cases()
    identity_cases()
    row_cases()
    aggregate_cases()
    transport_cases()
