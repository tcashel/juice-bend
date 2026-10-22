import Base
import ../src/claude_quota.bend as Q

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def agrees(result: Result<&2,&2,Q.Failure,Q.Observation>,expected: Q.Observation) -> Bool:
  match result:
    case Done{actual}: Q.same(actual,expected)
    case Fail{_}: False{}

def accepted(text: String,expected: Q.Observation) -> Bool:
  agrees(Q.parse(text),expected)

def failure(result: Result<&2,&2,Q.Failure,Q.Observation>,code: String) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{Q.Failure{actual,+message}}:
      String.eq(actual,code) && Bool.not(String.is_empty(message)) &&
        Bool.not(String.contains(message,"SYNTHETIC_SECRET"))

def rejected(text: String,code: String) -> Bool:
  failure(Q.parse(text),code)

def feed(percent: String,reset: String) -> String:
  "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":" ++ percent ++
    ",\"resets_at\":" ++ reset ++ "}}}"

def single(used: Maybe<&2,U32>,reset: Maybe<&2,Nat>) -> Q.Observation:
  Q.Observation{Some{Q.QuotaWindow{used,reset}},None{}}

def canonical(result: Result<&2,&2,Q.Failure,Q.Observation>,expected: String) -> Bool:
  match result:
    case Done{+value}: String.eq(Q.encode(value),expected) && agrees(Q.parse(Q.encode(value)),value)
    case Fail{_}: False{}

def roundtrip(+value: Q.Observation) -> Bool:
  agrees(Q.parse(Q.encode(value)),value)

def unknowns() -> IO(Unit):
  do IO<Unit>:
    assert(accepted("{}",Q.Observation{None{},None{}}),"missing rate_limits is a valid waiting observation")
    assert(accepted("{\"rate_limits\":null}",Q.Observation{None{},None{}}),"null rate_limits remains unknown")
    assert(accepted("{\"rate_limits\":{}}",Q.Observation{None{},None{}}),"missing windows remain unknown")
    assert(accepted("{\"rate_limits\":{\"five_hour\":null,\"seven_day\":null}}",Q.Observation{None{},None{}}),"explicit null windows remain unknown")
    assert(accepted("{\"rate_limits\":{\"five_hour\":{}}}",single(None{},None{})),"present window with unknown fields remains present")
    assert(accepted(feed("null","null"),single(None{},None{})),"null numeric fields remain unknown")
    assert(Q.empty(single(None{},None{})) && Q.empty(Q.Observation{None{},None{}}),"waiting means no known numeric metric")
    assert(Bool.not(Q.same(single(None{},None{}),Q.Observation{None{},None{}})),"state equality preserves absent versus present unknown window")
    assert(Bool.not(Q.empty(single(Some{0},None{}))) && Bool.not(Q.empty(single(None{},Some{0n}))),"zero percent and zero reset are known values")
    assert(accepted("{\"rate_limits\":{\"seven_day\":{\"resets_at\":4294967296}}}",Q.Observation{None{},Some{Q.QuotaWindow{None{},Some{Nat.add(4294967295n,1n)}}}}),"reset-only partial window retains integers beyond U32")
    assert(accepted("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":25},\"seven_day\":{\"used_percentage\":75,\"resets_at\":123}}}",
      Q.Observation{Some{Q.QuotaWindow{Some{25000000},None{}}},Some{Q.QuotaWindow{Some{75000000},Some{123n}}}}),"both windows and partial metrics are independent")

def percentages() -> IO(Unit):
  do IO<Unit>:
    assert(accepted(feed("0","0"),single(Some{0},Some{0n})),"numeric zero is never treated as missing")
    assert(accepted(feed("100","null"),single(Some{100000000},None{})),"100 percent upper bound is exact")
    assert(accepted(feed("12.345678","null"),single(Some{12345678},None{})),"six fractional places are exact millionths")
    assert(accepted(feed("0.000001","null"),single(Some{1},None{})),"smallest supported nonzero percentage is retained")
    assert(accepted(feed("1.230000000","null"),single(Some{1230000},None{})),"extra trailing zero fractional places do not change value")
    assert(accepted(feed("100.000000000","null"),single(Some{100000000},None{})),"upper bound allows only zero fraction")
    assert(rejected(feed("100.000001","null"),"invalid_percentage"),"fraction above 100 is refused")
    assert(rejected(feed("101","null"),"invalid_percentage"),"integer above 100 is refused")
    assert(rejected(feed("429496729600","null"),"invalid_percentage"),"large percent cannot wrap U32")
    assert(rejected(feed("-1","null"),"invalid_percentage") && rejected(feed("-0","null"),"invalid_percentage"),"negative lexemes including negative zero are unsupported")
    assert(rejected(feed("0.0000001","null"),"invalid_percentage") && rejected(feed("1.1234560001","null"),"invalid_percentage"),"unsupported precision is never rounded")
    assert(rejected(feed("1e2","null"),"invalid_percentage") && rejected(feed("1E-2","null"),"invalid_percentage"),"exponents are explicitly unsupported")
    assert(rejected(feed("\"25\"","null"),"invalid_percentage") && rejected(feed("true","null"),"invalid_percentage") &&
      rejected(feed("{}","null"),"invalid_percentage"),"strings booleans and objects are not coerced to percentages")

def resets() -> IO(Unit):
  do IO<Unit>:
    assert(accepted(feed("null","253402300799"),single(None{},Some{Nat.add(Nat.mul(253n,1000000000n),402300799n)})),"maximum supported Unix timestamp is exact Nat")
    assert(rejected(feed("null","253402300800"),"invalid_reset"),"timestamp above supported maximum is refused")
    assert(rejected(feed("null","281474976710656"),"invalid_reset") && rejected(feed("null","999999999999999999999999"),"invalid_reset"),"timestamps beyond native Nat range cannot wrap")
    assert(rejected(feed("null","-1"),"invalid_reset") && rejected(feed("null","-0"),"invalid_reset"),"negative timestamp lexemes are refused")
    assert(rejected(feed("null","1.0"),"invalid_reset") && rejected(feed("null","1e3"),"invalid_reset"),"reset requires an integer lexeme without decimal or exponent")
    assert(rejected(feed("null","\"123\""),"invalid_reset") && rejected(feed("null","false"),"invalid_reset") &&
      rejected(feed("null","[]"),"invalid_reset"),"reset fields are not type coerced")

def strict_shapes() -> IO(Unit):
  do IO<Unit>:
    assert(rejected("null","invalid_shape") && rejected("[]","invalid_shape") && rejected("1","invalid_shape"),"top level must be an object")
    assert(rejected("{\"rate_limits\":[]}","invalid_shape") && rejected("{\"rate_limits\":false}","invalid_shape"),"rate_limits must be object or null")
    assert(rejected("{\"rate_limits\":{\"five_hour\":7}}","invalid_shape") && rejected("{\"rate_limits\":{\"seven_day\":[]}}","invalid_shape"),"each known window must be object or null")
    assert(rejected("{\"rate_limits\":null,\"rate_limits\":{}}","invalid_json"),"duplicate top-level quota key is refused")
    assert(rejected("{\"rate_limits\":{\"five_hour\":null,\"five_hour\":{}}}","invalid_json"),"duplicate window key is refused")
    assert(rejected("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"used_percentage\":50}}}","invalid_json"),"duplicate percentage cannot overwrite a value")
    assert(rejected("{\"rate_limits\":{\"seven_day\":{\"resets_at\":0,\"resets_at\":1}}}","invalid_json"),"duplicate reset cannot overwrite a value")
    assert(rejected("{\"rate_limits\":{\"five_hour\":{\"used_percentage\":0,\"used_\\u0070ercentage\":50}}}","invalid_json"),"escaped duplicate key is compared after JSON decoding")
    assert(rejected("{} {}","invalid_json") && rejected("{\"rate_limits\":{},}","invalid_json") && rejected("{","invalid_json"),"trailing values trailing comma and truncation are refused")
    assert(rejected(feed("01","null"),"invalid_json") && rejected(feed("NaN","null"),"invalid_json"),"invalid JSON number grammar is refused before quota parsing")
    assert(rejected("{\"unused\":\"\\ud800\"}","invalid_json"),"unknown fields must still be strict Unicode JSON")
    assert(rejected(feed("\"SYNTHETIC_SECRET café 中文 🙂\"","null"),"invalid_percentage") &&
      rejected("{\"SYNTHETIC_SECRET\":}","invalid_json"),"failure messages never echo rejected input")

def canonicalization() -> IO(Unit):
  do IO<Unit>:
    assert(canonical(Q.parse("{\"workspace\":{\"current_dir\":\"/synthetic/SYNTHETIC_SECRET\"},\"session_id\":\"SYNTHETIC_SECRET café é 中文 🙂\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":1.230000000,\"resets_at\":253402300799,\"token\":\"SYNTHETIC_SECRET\"},\"seven_day\":{\"used_percentage\":null},\"extra\":{\"private\":true}},\"cost\":{\"total_cost_usd\":999},\"unknown\":[false,123,\"🙂\"]}"),
      "{\"rate_limits\":{\"five_hour\":{\"used_percentage\":1.23,\"resets_at\":253402300799},\"seven_day\":{\"used_percentage\":null,\"resets_at\":null}}}"),"canonical payload discards all unknown fields and preserves only allowlisted numbers")
    assert(canonical(Q.parse(feed("0.000001","0")),"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":0.000001,\"resets_at\":0},\"seven_day\":null}}"),"canonical encoder retains leading fractional zeros and exact zero reset")
    assert(canonical(Q.parse(feed("100.000000","null")),"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":100,\"resets_at\":null},\"seven_day\":null}}"),"canonical encoder removes insignificant fractional zeros")
    assert(roundtrip(Q.Observation{None{},None{}}) && roundtrip(single(None{},None{})),"empty observations roundtrip without collapsing window structure")
    assert(roundtrip(Q.Observation{Some{Q.QuotaWindow{Some{1},Some{Nat.add(Nat.mul(253n,1000000000n),402300799n)}}},Some{Q.QuotaWindow{Some{99999999},Some{0n}}}}),"two-window edge values roundtrip exactly")
    assert(Bool.not(Q.same(single(Some{1},Some{2n}),single(Some{2},Some{2n}))) &&
      Bool.not(Q.same(single(Some{1},Some{2n}),single(Some{1},Some{3n}))) &&
      Bool.not(Q.same(single(Some{0},None{}),single(None{},Some{0n}))),"state equality detects percentage reset and known-field differences")

def bounds() -> IO(Unit):
  do IO<Unit>:
    assert(accepted("{\"unused\":\"" ++ String.repeat("x",1048563n) ++ "\"}",Q.Observation{None{},None{}}),"exact one MiB UTF-8 input is accepted")
    assert(rejected("{\"unused\":\"" ++ String.repeat("x",1048564n) ++ "\"}","input_limit"),"one byte beyond one MiB is refused")
    assert(accepted("{\"unused\":\"" ++ String.repeat("🙂",262140n) ++ "xxx\"}",Q.Observation{None{},None{}}),"UTF-8 boundary counts four-byte scalars exactly")
    assert(rejected("{\"unused\":\"" ++ String.repeat("🙂",262140n) ++ "xxxx\"}","input_limit"),"multibyte payload over byte bound is refused below character limit")
    assert(rejected(SCon{Chr{55296},SNil{}},"input_limit") && rejected(SCon{Chr{1114112},SNil{}},"input_limit"),"direct invalid Unicode scalar strings are refused before JSON")

def main() -> IO(Unit):
  do IO<Unit>:
    unknowns()
    percentages()
    resets()
    strict_shapes()
    canonicalization()
    bounds()
