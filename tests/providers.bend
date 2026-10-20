import Base
import ../src/json.bend as J
import ../src/providers.bend as P

def assert(name: String, passed: Bool) -> IO(Unit):
  match passed:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def is_error(result: Result<&2, &2, String, J.Json>) -> Bool:
  match result:
    case Fail{error}:
      True{}
    case Done{value}:
      False{}

def is_json(result: Result<&2, &2, String, J.Json>, expected: String) -> Bool:
  match result:
    case Done{value}:
      String.eq(J.encode(value), expected)
    case Fail{error}:
      False{}

def field_is(result: Result<&2, &2, String, J.Json>, key: String, expected: String) -> Bool:
  match result:
    case Done{value}:
      String.eq(J.get(value, key), expected)
    case Fail{error}:
      False{}

def same(+a: P.Record, +b: P.Record) -> Bool:
  Bool.and(String.eq(P.role(a), P.role(b)),
  Bool.and(String.eq(P.text(a), P.text(b)),
  Bool.and(String.eq(P.tool(a), P.tool(b)),
  Bool.and(String.eq(P.call_id(a), P.call_id(b)),
  Bool.and(String.eq(P.arguments(a), P.arguments(b)),
  Bool.and(String.eq(P.result(a), P.result(b)),
  Bool.and(String.eq(P.repository(a), P.repository(b)),
  Bool.and(String.eq(P.session(a), P.session(b)),
  Bool.and(String.eq(P.timestamp(a), P.timestamp(b)),
  Bool.and(String.eq(P.model(a), P.model(b)),
  Bool.and(String.eq(P.usage(a), P.usage(b)),
  Bool.and(String.eq(P.parent(a), P.parent(b)),
    String.eq(P.coverage(a), P.coverage(b))))))))))))))

def records_equal(actual: List<&2, P.Record>, expected: List<&2, P.Record>) -> Bool:
  match actual expected:
    case Nil{} Nil{}:
      True{}
    case Con{a, at} Con{b, bt}:
      Bool.and(same(a, b), records_equal(at, bt))
    case _ _:
      False{}

def first_coverage(records: List<&2, P.Record>, expected: String) -> Bool:
  match records:
    case Con{a, rest}:
      String.eq(P.coverage(a), expected)
    case Nil{}:
      False{}

def parse_tests() -> IO(Unit):
  do IO<Unit>:
    assert("JSON nested roundtrip", is_json(J.parse("{\"a\":[1,true,false,null,{\"x\":\"yes\"}]}"), "{\"a\":[1,true,false,null,{\"x\":\"yes\"}]}"))
    assert("JSON exact large and signed numbers", is_json(J.parse("[0,-2147483648,4294967296,9007199254740993,9223372036854775807,-9223372036854775808,1.234567890123456789e+900]"), "[0,-2147483648,4294967296,9007199254740993,9223372036854775807,-9223372036854775808,1.234567890123456789e+900]"))
    assert("JSON escapes and surrogate pair", field_is(J.parse("{\"x\":\"a\\n\\t\\b\\f\\r\\/\\\\\\\"\\u0000\\uD83D\\uDE00\"}"), "x", "a\n\t\u{8}\u{c}\r/\\\"\0😀"))
    assert("JSON Unicode scalar preservation", field_is(J.parse("{\"x\":\"Café é 中文 😀\"}"), "x", "Café é 中文 😀"))
    assert("JSON whitespace CRLF", is_json(J.parse(" \r\n\t[1, 2]\r\n"), "[1,2]"))
    assert("JSON null string distinction", is_json(J.parse("[null,\"null\",\"\"]"), "[null,\"null\",\"\"]"))
    assert("JSON empty rejects", is_error(J.parse("")))
    assert("JSON incomplete array rejects", is_error(J.parse("[1")))
    assert("JSON trailing content rejects", is_error(J.parse("{} false")))
    assert("JSON duplicate keys reject ambiguity", is_error(J.parse("{\"x\":1,\"x\":2}")))
    assert("JSON missing object colon rejects", is_error(J.parse("{\"a\" 1}")))
    assert("JSON missing array comma rejects", is_error(J.parse("[1 2]")))
    assert("JSON wrong close rejects", is_error(J.parse("[1}")))
    assert("JSON trailing array comma rejects", is_error(J.parse("[1,]")))
    assert("JSON trailing object comma rejects", is_error(J.parse("{\"a\":1,}")))
    assert("JSON nonstring object key rejects", is_error(J.parse("{1:2}")))
    assert("JSON unterminated string rejects", is_error(J.parse("\"abc")))
    assert("JSON raw newline rejects", is_error(J.parse("\"a\nb\"")))
    assert("JSON raw NUL rejects", is_error(J.parse("\"a\0b\"")))
    assert("JSON unknown escape rejects", is_error(J.parse("\"\\z\"")))
    assert("JSON hex escape rejects", is_error(J.parse("\"\\u12xz\"")))
    assert("JSON short hex rejects", is_error(J.parse("\"\\u12\"")))
    assert("JSON high surrogate alone rejects", is_error(J.parse("\"\\uD800\"")))
    assert("JSON low surrogate alone rejects", is_error(J.parse("\"\\uDC00\"")))
    assert("JSON high surrogate wrong second rejects", is_error(J.parse("\"\\uD800\\u0041\"")))
    assert("JSON leading zero rejects", is_error(J.parse("01")))
    assert("JSON leading plus rejects", is_error(J.parse("+1")))
    assert("JSON missing integer rejects", is_error(J.parse(".1")))
    assert("JSON missing fraction rejects", is_error(J.parse("1.")))
    assert("JSON missing exponent rejects", is_error(J.parse("1e+")))
    assert("JSON negative leading zero rejects", is_error(J.parse("-01")))
    assert("JSON invalid literal rejects", is_error(J.parse("undefined")))
    assert("JSON depth 64 accepted", is_json(J.parse(String.repeat("[", 64n) ++ "0" ++ String.repeat("]", 64n)), String.repeat("[", 64n) ++ "0" ++ String.repeat("]", 64n)))
    assert("JSON record size bound rejects excess", is_error(J.parse(String.repeat(" ", 1048577n))))
    assert("JSON invalid decoded scalar rejects", is_error(J.parse(SCon{Chr{34}, SCon{Chr{55296}, SCon{Chr{34}, SNil{}}}})))
    assert("JSON depth 65 rejected", is_error(J.parse(String.repeat("[", 65n) ++ "0" ++ String.repeat("]", 65n))))

def provider_tests() -> IO(Unit):
  do IO<Unit>:
    assert("Claude full normalized text and tool fields", records_equal(P.parse("claude", "{\"type\":\"assistant\",\"sessionId\":\"s1\",\"cwd\":\"/synthetic/repo\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"parentUuid\":\"p1\",\"message\":{\"id\":\"m1\",\"model\":\"synthetic\",\"usage\":{\"output_tokens\":9007199254740993},\"content\":[{\"type\":\"text\",\"text\":\"Hello 😀\"},{\"type\":\"tool_use\",\"id\":\"c1\",\"name\":\"Write\",\"input\":{\"file_path\":\"a.bend\",\"content\":\"first\\nsecond\"}}]}}"), [P.ProviderEvent{"assistant", "Hello 😀", "", "", "", "", "/synthetic/repo", "s1", "2026-10-20T12:00:00Z", "synthetic", "{\"output_tokens\":9007199254740993}", "p1", "complete"}, P.ProviderEvent{"assistant", "", "Write", "c1", "{\"file_path\":\"a.bend\",\"content\":\"first\\u000asecond\"}", "", "/synthetic/repo", "s1", "2026-10-20T12:00:00Z", "synthetic", "", "p1", "complete"}]))
    assert("Claude tool result text array", records_equal(P.parse("claude", "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"c1\",\"content\":[{\"type\":\"text\",\"text\":\"first\"},{\"type\":\"text\",\"text\":\"second\"}]}]}}"), [P.ProviderEvent{"tool", "", "", "c1", "", "first\nsecond", "", "", "", "", "", "", "complete"}]))
    assert("Claude missing model remains unknown", records_equal(P.parse("claude", "{\"type\":\"assistant\",\"message\":{\"content\":\"next\"}}"), [P.ProviderEvent{"assistant", "next", "", "", "", "", "", "", "", "", "", "", "complete"}]))
    assert("Claude tool error remains explicit", first_coverage(P.parse("claude", "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"is_error\":true,\"content\":\"failed\"}]}}"), "tool_error"))
    assert("Claude unknown block partial", first_coverage(P.parse("claude", "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"future_block\"}]}}"), "unsupported"))
    assert("Claude attachment coverage", first_coverage(P.parse("claude", "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"image\",\"source\":{\"url\":\"https://invalid.example/synthetic\"}}]}}"), "unsupported_attachment"))
    assert("Codex session metadata fields", records_equal(P.parse("codex", "{\"timestamp\":\"t1\",\"type\":\"session_meta\",\"payload\":{\"id\":\"s2\",\"cwd\":\"/synthetic/repo2\",\"model\":\"synthetic\"}}"), [P.ProviderEvent{"metadata", "[Session metadata]", "", "", "", "", "/synthetic/repo2", "s2", "t1", "synthetic", "", "", "metadata"}]))
    assert("Codex message chunk spacing and no false session id", records_equal(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"id\":\"message-not-session\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"one\"},{\"type\":\"output_text\",\"text\":\"two\"}]}}"), [P.ProviderEvent{"assistant", "one\n\ntwo", "", "", "", "", "", "", "", "", "", "", "complete"}]))
    assert("Codex exact call argument string", records_equal(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"name\":\"exec_command\",\"call_id\":\"c2\",\"arguments\":\"{ \\\"cmd\\\": \\\"echo synthetic\\\" }\"}}"), [P.ProviderEvent{"assistant", "", "exec_command", "c2", "{ \"cmd\": \"echo synthetic\" }", "", "", "", "", "", "", "", "complete"}]))
    assert("Codex output object shape", records_equal(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"c2\",\"output\":{\"content\":\"result\\n\"}}}"), [P.ProviderEvent{"tool", "", "", "c2", "", "result\n", "", "", "", "", "", "", "complete"}]))
    assert("Codex output chunks no added separators", records_equal(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"c2\",\"output\":[{\"type\":\"input_text\",\"text\":\"a\"},{\"type\":\"input_text\",\"text\":\"b\"}]}}"), [P.ProviderEvent{"tool", "", "", "c2", "", "ab", "", "", "", "", "", "", "complete"}]))
    assert("Codex legacy function call", records_equal(P.parse("codex", "{\"type\":\"function_call\",\"payload\":{\"name\":\"exec_command\",\"call_id\":\"legacy\",\"arguments\":\"{}\"}}"), [P.ProviderEvent{"assistant", "", "exec_command", "legacy", "{}", "", "", "", "", "", "", "", "complete"}]))
    assert("Codex readable agent relay is system", records_equal(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"agent_message\",\"content\":[{\"type\":\"input_text\",\"text\":\"child result\"}]}}"), [P.ProviderEvent{"system", "child result", "", "", "", "", "", "", "", "", "", "", "complete"}]))
    assert("Codex encrypted relay stays partial", first_coverage(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"agent_message\",\"content\":[{\"type\":\"input_text\",\"text\":\"header\"},{\"type\":\"encrypted_content\",\"data\":\"synthetic\"}]}}"), "partial_agent_relay"))
    assert("Codex mirrors omitted", records_equal(P.parse("codex", "{\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_message\",\"message\":\"mirror\"}}"), []))
    assert("Codex unknown event preserved as unsupported", first_coverage(P.parse("codex", "{\"type\":\"event_msg\",\"payload\":{\"type\":\"future_event\"}}"), "unsupported"))
    assert("Codex encrypted reasoning partial", first_coverage(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"reasoning\",\"encrypted_content\":\"synthetic\"}}"), "partial_reasoning"))
    assert("Codex unknown content coverage", first_coverage(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_image\"}]}}"), "partial_content"))
    assert("Codex unsupported output is partial", first_coverage(P.parse("codex", "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"output\":{\"unknown\":1}}}"), "partial_content"))
    assert("Provider malformed input visible", first_coverage(P.parse("claude", "{bad"), "malformed"))
    assert("Provider unsupported input visible", first_coverage(P.parse("future-provider", "{}"), "unsupported"))

def main() -> IO(Unit):
  do IO<Unit>:
    parse_tests()
    provider_tests()
    IO.print("JSON/provider checks complete")
