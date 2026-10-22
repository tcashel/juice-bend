import Base
import ../src/usage.bend as Usage
import ../src/json.bend as Json
import ../src/store.bend as Store
import ../src/sql.bend as Sql

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def value(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{json}:
      json
    case _:
      Json.JNull{}

def observed(text: String) -> Usage.Observation:
  Usage.Observation{"0","synthetic raw citation",value(Json.parse(text)),"complete"}

def claude(id: String,input: String,output: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"s\",\"message\":{\"id\":\"" ++ id ++
    "\",\"content\":\"recorded\",\"usage\":{\"input_tokens\":" ++ input ++
    ",\"output_tokens\":" ++ output ++ "}}}\n"

def codex(input: String,cached: String,output: String,total: String) -> String:
  "{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":" ++
    input ++ ",\"cached_input_tokens\":" ++ cached ++ ",\"output_tokens\":" ++ output ++
    ",\"total_tokens\":" ++ total ++ "},\"last_token_usage\":{\"total_tokens\":999}}}}\n"

def summary_has(+text: String,input: String,output: String) -> Bool:
  String.contains(text,"input_tokens: " ++ input ++ "\n") &&
    String.contains(text,"output_tokens: " ++ output ++ "\n")

def pure() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(Usage.add("9007199254740993","7"),"9007199254741000"),
      "decimal addition is exact above 2^53")
    assert(String.eq(Usage.add("999999999999999999999999","1"),"1000000000000000000000000"),
      "decimal addition carries without machine-word overflow")
    assert(String.eq(Usage.subtract("9007199254741000","9007199254740993"),"7"),
      "cumulative subtraction is exact above 2^53")
    assert(String.eq(Usage.subtract("1000000000000000000000000","1"),"999999999999999999999999"),
      "decimal subtraction propagates borrow")
    assert(String.eq(Usage.subtract("123","123"),"0"),"duplicate cumulative counter has zero delta")
    assert(String.eq(Usage.number(Json.JNumber{"9007199254740993"}),"9007199254740993"),
      "recorded integer lexeme remains exact")
    assert(String.is_empty(Usage.number(Json.JNumber{"-1"})) &&
      String.is_empty(Usage.number(Json.JNumber{"1.5"})) &&
      String.is_empty(Usage.number(Json.JNumber{"1e3"})) &&
      String.is_empty(Usage.number(Json.JString{"123"})),
      "noncanonical noninteger and string counters remain unknown")
    +mirrors : String = Usage.claude_report([
      observed(claude("same","10","1")),observed(claude("same","8","3")),
      observed(claude("other","4","2"))])
    assert(summary_has(mirrors,"14","5"),"Claude per-message bucket maxima deduplicate mirrors")
    assert(String.contains(mirrors,"Distinct observed message.id keys: 2"),"Claude identity count is deduplicated")
    +missing : String = Usage.claude_report([
      observed(claude("same","10","1")),observed(claude("","100","100"))])
    assert(summary_has(missing,"10","1") && String.contains(missing,"excluded for missing message.id: 1"),
      "missing message identity cannot inflate Claude subtotal")
    +typed_id : String = Usage.claude_report([
      observed(claude("1","10","1")),
      observed("{\"type\":\"assistant\",\"message\":{\"id\":1,\"usage\":{\"input_tokens\":100,\"output_tokens\":100}}}")])
    assert(summary_has(typed_id,"10","1") &&
      String.contains(typed_id,"excluded for missing message.id: 1"),
      "numeric malformed identity cannot collide with a string message ID")
    +different_session : String = Usage.claude_report([
      observed(claude("same","10","1")),
      observed("{\"type\":\"assistant\",\"sessionId\":\"other\",\"message\":{\"id\":\"same\",\"usage\":{\"input_tokens\":4,\"output_tokens\":2}}}")])
    assert(summary_has(different_session,"14","3"),"same message ID in distinct sessions stays distinct")
    assert(String.contains(Usage.claude_report([]),"input_tokens: unknown"),
      "absent usage remains unknown rather than zero")
    +cache : String = Usage.claude_report([observed(
      "{\"type\":\"assistant\",\"message\":{\"id\":\"cache\",\"usage\":{\"input_tokens\":2,\"cache_read_input_tokens\":7,\"cache_creation_input_tokens\":11,\"output_tokens\":3}}}")])
    assert(summary_has(cache,"2","3") && String.contains(cache,"cache_read/cached_input_tokens: 7\n") &&
      String.contains(cache,"cache_creation_input_tokens: 11\n") &&
      String.contains(cache,"total_tokens (only if recorded): unknown"),
      "Claude cache buckets stay separate without invented total")
    +deltas : String = Usage.codex_report([
      observed(codex("100","20","10","110")),observed(codex("100","20","10","110")),
      observed(codex("130","25","15","145"))],False{})
    assert(summary_has(deltas,"30","5") && String.contains(deltas,"total_tokens (only if recorded): 35\n"),
      "Codex cumulative differences exclude first baseline and duplicate mirror")
    assert(String.contains(deltas,"cache_read/cached_input_tokens: 5\n"),
      "cached input delta is separate from inclusive input")
    assert(Bool.not(String.contains(deltas,"total_tokens (only if recorded): 999")),
      "last_token_usage is never treated as additive")
    +reset : String = Usage.codex_report([
      observed(codex("100","20","10","110")),observed(codex("1","0","0","1")),
      observed(codex("3","0","1","4"))],False{})
    assert(summary_has(reset,"2","1") && String.contains(reset,"resets/unknown pairs excluded: 1"),
      "decreasing cumulative reset is excluded and rebaselined")
    +fork : String = Usage.codex_report([
      observed("{\"type\":\"session_meta\",\"payload\":{\"id\":\"child\",\"forked_from_id\":\"parent\"}}"),
      observed(codex("100","20","10","110")),observed(codex("130","25","15","145"))],False{})
    assert(String.contains(fork,"all subtotal attribution excluded") &&
      Bool.not(String.contains(fork,"input_tokens: 30\n")),"known fork excludes inherited subtotal attribution")
    assert(String.contains(Usage.codex_report([observed(codex("100","20","10","110"))],True{}),
      "all subtotal attribution excluded"),"unknown session origin never claims attributable usage")
    assert(String.contains(Usage.codex_report([observed(codex("100","20","10","110"))],False{}),
      "input_tokens: unknown"),"single cumulative observation is only a baseline")

def storage() -> IO(Unit):
  do IO<Unit>:
    +root : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(root,"juice-bend-test-usage."),
      "Run usage test with scripts/test in isolated directory")
    +path : String = root ++ "/usage.jsonl"
    Store.write_text(path,"w",claude("same","9007199254740993","1") ++
      claude("same","9007199254740993","3") ++ claude("other","7","2"))
    +db : U32 <- Store.open(":memory:")
    +snapshot : String <- Store.import_file(db,"claude",path)
    +before : String <- Usage.summary(db,snapshot,0,100)
    assert(summary_has(before,"9007199254741000","5"),"stored usage derives exact deduplicated raw facts")
    assert(String.contains(before,"\"snapshot\":\"" ++ snapshot ++ "\"") &&
      String.contains(before,"\"record\":\"0\",\"event\":\"0\""),"usage facts include immutable capture citations")
    Store.exec(db,"UPDATE events SET usage='{\"input_tokens\":999999}'",[])
    Store.write_text(path,"w","original replaced")
    after : String <- Usage.summary(db,snapshot,0,100)
    assert(String.eq(before,after),"usage ignores altered projection and replaced original source")
    +limited : String <- Usage.summary(db,snapshot,1,1)
    assert(summary_has(limited,"9007199254740993","3") &&
      String.contains(limited,"records 1 through 2"),"bounded usage range does not borrow other records")
    beyond : String <- Usage.summary(db,snapshot,4294967295,100)
    assert(String.contains(beyond,"input_tokens: unknown"),"out-of-range page remains empty and unknown")
    missing : String <- Usage.summary(db,"999999",0,100)
    assert(String.starts_with(missing,"Usage unavailable"),"missing captured snapshot explicit")
    +codex_path : String = root ++ "/codex-usage.jsonl"
    Store.write_text(codex_path,"w","{\"type\":\"session_meta\",\"payload\":{\"id\":\"plain\"}}\n" ++
      codex("100","20","10","110") ++ codex("130","25","15","145"))
    codex_snapshot : String <- Store.import_file(db,"codex",codex_path)
    recorded : String <- Usage.summary(db,codex_snapshot,1,2)
    assert(summary_has(recorded,"30","5"),"Codex partial range uses verified first metadata for origin")
    +large_path : String = root ++ "/bounded-usage.jsonl"
    Store.write_text(large_path,"w",String.repeat(claude("mirror","1","1"),101n))
    large_snapshot : String <- Store.import_file(db,"claude",large_path)
    +bounded : String <- Usage.summary(db,large_snapshot,0,200)
    assert(String.contains(bounded,"records 0 through 100 (exclusive), of 101") &&
      String.contains(bounded,"Record 99\n") && Bool.not(String.contains(bounded,"Record 100\n")),
      "usage hard limit reads at most 100 physical records")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    storage()
