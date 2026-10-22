import Base
import ../src/library_usage_page_wire.bend as W
import ../src/session_usage.bend as S
import ../src/reader_document.bend as Reader
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

def canonical() -> String:
  "é\t中文🙂\n\0"

def capture_text() -> String:
  "{\"provider\":\"claude\",\"source_id\":\"9007199254740993\",\"source\":\"/synthetic/café 中文.jsonl\",\"generation\":\"3\",\"snapshot\":\"9223372036854775807\",\"extent\":\"4294967295\",\"records\":\"45\"}"

def capture() -> S.Capture:
  S.Capture{"claude","9007199254740993","/synthetic/café 中文.jsonl","3","9223372036854775807",4294967295,45}

def page() -> J.Json:
  J.JObject{[J.JField{"snapshot",J.JString{"9223372036854775807"}},J.JField{"start",J.JNumber{"40"}},
    J.JField{"requested_records",J.JNumber{"40"}},J.JField{"selected_records",J.JNumber{"5"}},
    J.JField{"kind",J.JString{"scoped_transcript_page"}},J.JField{"byte_space",J.JString{"logical_source_bytes"}},
    J.JField{"complete_export",J.JBool{False{}}},J.JField{"text",J.JString{canonical()}}]}

def first() -> J.Json:
  json("{\"snapshot\":\"9223372036854775807\",\"record\":\"42\",\"event\":0,\"part\":0,\"kind\":\"message_text\",\"start\":0,\"length\":3,\"role\":\"assistant\",\"tool\":\"\",\"collapsible\":false}")

def second() -> J.Json:
  json("{\"snapshot\":\"9223372036854775807\",\"record\":\"43\",\"event\":0,\"part\":1,\"kind\":\"tool_result\",\"start\":3,\"length\":4,\"role\":\"tool\",\"tool\":\"synthetic tool\",\"collapsible\":true}")

def metadata(parts: List<&2,J.Json>) -> J.Json:
  J.JObject{[J.JField{"version",J.JNumber{"1"}},J.JField{"mode",J.JString{"structured"}},J.JField{"parts",J.JArray{parts}}]}

def changed(fields: List<&2,J.Field>,+name: String,+replacement: J.Json) -> List<&2,J.Field>:
  match fields:
    case []: []
    case J.JField{+key,value} <> rest:
      J.JField{key,Bool.pick(J.Json,String.eq(key,name),replacement,value)} <> changed(rest,name,replacement)

def set(value: J.Json,name: String,replacement: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{changed(fields,name,replacement)}
    case _: J.JNull{}

def add(value: J.Json,name: String,field: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{J.JField{name,field} <> fields}
    case _: J.JNull{}

def outer(page: J.Json) -> J.Json:
  J.JObject{[J.JField{"kind",J.JString{"library_usage_capture"}},J.JField{"version",J.JNumber{"1"}},
    J.JField{"nonce",J.JNumber{"17"}},J.JField{"capture",json(capture_text())},J.JField{"page",page}]}

def with_metadata(value: J.Json) -> J.Json:
  outer(add(page(),"reader_view",value))

def decode(value: J.Json) -> Result<&2,&2,String,W.Page>:
  W.decode(value,17,capture(),40,99)

def accepted(value: Result<&2,&2,String,W.Page>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def reject(value: J.Json) -> Bool:
  Bool.not(accepted(decode(value)))

def exact(value: Result<&2,&2,String,W.Page>,structured: Bool) -> Bool:
  match value:
    case Done{W.Page{capture,start,selected,+text,+document}}:
      String.eq(S.capture_text(capture),capture_text()) && U32.is_eq(start,40) && U32.is_eq(selected,5) &&
        String.eq(text,canonical()) && String.eq(Reader.text(document),canonical()) && U32.is_eq(Reader.revision(document),99) &&
        Bool.not(Bool.xor(Reader.structured(document),structured))
    case Fail{_}: False{}

def fallback(value: J.Json) -> Bool:
  exact(decode(with_metadata(value)),False{})

def part_identities(parts: List<&2,Reader.Part>) -> String:
  match parts:
    case []: ""
    case Reader.Part{Reader.PartKey{snapshot,record,_,index},_,_,_,_,_} <> rest:
      snapshot ++ "/" ++ record ++ "/" ++ U32.show(index) ++ ";" ++ part_identities(rest)

def identities(value: Result<&2,&2,String,W.Page>) -> String:
  match value:
    case Done{W.Page{_,_,_,_,document}}: part_identities(Reader.parts(document))
    case Fail{_}: "failed"

def baseline() -> IO(Unit):
  do IO<Unit>:
    check(exact(decode(outer(page())),False{}),"standard eight-field page preserves every Unicode and control scalar with a fresh plain reader revision")
    check(exact(decode(with_metadata(metadata([first(),second()]))),True{}),"valid ninth-field metadata builds a structured reader without changing canonical text")
    check(String.eq(identities(decode(with_metadata(metadata([first(),second()])))),
      "9223372036854775807/42/0;9223372036854775807/43/1;"),"structured reader retains exact snapshot and record descriptor identities")
    check(fallback(J.JNull{}) && fallback(J.JString{"unknown metadata"}),"null or wrong-type optional metadata preserves a successful plain canonical page")

def outer_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(set(outer(page()),"kind",J.JString{"library_usage"})) && reject(set(outer(page()),"version",J.JNumber{"2"})) &&
      reject(set(outer(page()),"version",J.JString{"1"})),"capture page envelope kind and version are exact")
    check(reject(set(outer(page()),"nonce",J.JNumber{"18"})) && reject(set(outer(page()),"nonce",J.JNumber{"017"})) &&
      reject(set(outer(page()),"nonce",J.JString{"17"})) && Bool.not(accepted(W.decode(outer(page()),0,capture(),40,99))),
      "stale, noncanonical, wrong-type and zero request identities are rejected")
    check(reject(add(outer(page()),"extra",J.JNull{})) && reject(add(outer(page()),"nonce",J.JNumber{"17"})),
      "capture envelope admits no extra or duplicate fields")

def capture_field(name: String,value: J.Json) -> J.Json:
  set(outer(page()),"capture",set(json(capture_text()),name,value))

def capture_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(capture_field("provider",J.JString{"codex"})) && reject(capture_field("source_id",J.JString{"2"})) &&
      reject(capture_field("source",J.JString{"/synthetic/other.jsonl"})),"provider, source identity and locator must all match the selected capture")
    check(reject(capture_field("generation",J.JString{"4"})) && reject(capture_field("snapshot",J.JString{"2"})) &&
      reject(capture_field("extent",J.JString{"4294967294"})) && reject(capture_field("records",J.JString{"44"})),
      "generation, snapshot, accepted extent and record count must all match exactly")
    check(reject(set(outer(page()),"capture",add(json(capture_text()),"extra",J.JNull{}))) &&
      reject(capture_field("snapshot",J.JString{"9223372036854775808"})),"capture decoder retains its closed schema and signed64 bound")

def page_field(name: String,value: J.Json) -> J.Json:
  outer(set(page(),name,value))

def page_cases() -> IO(Unit):
  do IO<Unit>:
    check(reject(page_field("snapshot",J.JString{"2"})) && reject(page_field("start",J.JNumber{"0"})) &&
      reject(page_field("start",J.JString{"40"})) && reject(page_field("start",J.JNumber{"40.0"})),"page snapshot and canonical numeric start match the request")
    check(reject(page_field("requested_records",J.JNumber{"39"})) && reject(page_field("requested_records",J.JString{"40"})) &&
      reject(page_field("selected_records",J.JNumber{"4"})) && reject(page_field("selected_records",J.JNumber{"41"})),
      "requested forty records and the exact bounded tail count cannot be changed")
    check(reject(page_field("kind",J.JString{"scoped_recorded_evidence"})) && reject(page_field("byte_space",J.JString{"compressed_container_bytes"})) &&
      reject(page_field("complete_export",J.JBool{True{}})),"page kind, logical-byte space and partial-export flag are fixed")
    check(reject(page_field("text",J.JNull{})) && reject(outer(add(page(),"extra",J.JNull{}))) &&
      reject(outer(add(page(),"text",J.JString{canonical()}))) &&
      reject(outer(add(add(page(),"reader_view",J.JNull{}),"reader_view",J.JNull{}))),
      "required text and exact eight-or-nine-field page shape reject malformed, unknown and duplicate fields")

def range_page(start: String,selected: String) -> J.Json:
  outer(set(set(page(),"start",J.JNumber{start}),"selected_records",J.JNumber{selected}))

def range_cases() -> IO(Unit):
  do IO<Unit>:
    check(accepted(W.decode(range_page("0","40"),17,capture(),0,99)) && accepted(W.decode(range_page("45","0"),17,capture(),45,99)),
      "first full page and exact end of capture use bounded record counts")
    check(accepted(W.decode(range_page("4294967295","0"),17,capture(),4294967295,99)) &&
      Bool.not(accepted(W.decode(range_page("4294967295","1"),17,capture(),4294967295,99))),
      "far-past-end U32 start cannot wrap into a nonempty range")

def metadata_cases() -> IO(Unit):
  do IO<Unit>:
    check(fallback(set(metadata([first(),second()]),"version",J.JNumber{"2"})) &&
      fallback(add(metadata([first(),second()]),"extra",J.JNull{})),"unknown metadata version or fields never block canonical evidence")
    check(fallback(add(metadata([first(),second()]),"version",J.JNumber{"1"})) &&
      fallback(set(metadata([first(),second()]),"parts",J.JString{"not an array"})),"duplicate or malformed metadata falls back atomically")
    check(fallback(metadata([set(first(),"snapshot",J.JString{"2"}),second()])) &&
      fallback(metadata([first(),set(second(),"kind",J.JString{"invented"})])),"foreign snapshot or unknown part kind cannot style the selected evidence")
    check(fallback(metadata([first()])) && fallback(metadata([first(),set(second(),"start",J.JNumber{"2"})])),
      "missing tail or overlapping spans preserve full plain text instead of a partial structured page")

def same_text(value: Result<&2,&2,String,W.Page>,+text: String) -> Bool:
  match value:
    case Done{W.Page{_,_,_,actual,document}}: String.eq(actual,text) && String.eq(Reader.text(document),text)
    case Fail{_}: False{}

def text_bounds() -> IO(Unit):
  +exact : String = String.repeat("é",524288n)
  do IO<Unit>:
    check(same_text(decode(page_field("text",J.JString{exact})),exact),"exactly one MiB of UTF-8 canonical text is retained without clipping")
    check(reject(page_field("text",J.JString{String.repeat("é",524289n)})),"text above one MiB is rejected by bytes rather than scalar count")
    check(reject(page_field("text",J.JString{SCon{Chr{55296},SNil{}}})),"invalid Unicode scalars cannot masquerade as UTF-8 canonical text")

def main() -> IO(Unit):
  do IO<Unit>:
    baseline()
    outer_cases()
    capture_cases()
    page_cases()
    range_cases()
    metadata_cases()
    text_bounds()
