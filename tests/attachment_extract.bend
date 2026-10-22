import Base
import ../src/attachment_extract.bend as A
import ../src/attachment_refs.bend as R
import ../src/json.bend as J

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def reference(value: R.Reference) -> String:
  match value:
    case R.LocalPath{path}: "local:" ++ path
    case R.LocalFileURL{url}: "file-url:" ++ url
    case R.RemoteURL{url}: "remote:" ++ url
    case R.InlineData{media,encoding,R.ValidBase64{chars,bytes}}:
      "inline:" ++ media ++ ":" ++ encoding ++ ":" ++ U32.show(chars) ++ ":" ++ U32.show(bytes)
    case R.InlineData{media,encoding,R.InvalidBase64{reason}}:
      "inline-invalid:" ++ media ++ ":" ++ encoding ++ ":" ++ reason
    case R.UnsupportedReference{reason}: "unsupported:" ++ reason

def row(value: A.Occurrence) -> String:
  A.Occurrence{ordinal,path,kind,ref} = value
  U32.show(ordinal) ++ "|" ++ path ++ "|" ++ kind ++ "|" ++ reference(ref)

def rows(values: List<&2,A.Occurrence>) -> List<&2,String>:
  match values:
    case []: []
    case value <> rest: row(value) <> rows(rest)

def equal(actual: List<&2,String>,expected: List<&2,String>) -> Bool:
  match actual expected:
    case Nil{} Nil{}: True{}
    case Con{a,ar} Con{b,br}: String.eq(a,b) && equal(ar,br)
    case _ _: False{}

def same_bool(a: Bool,+b: Bool) -> Bool:
  Bool.pick(Bool,a,b,Bool.not(b))

def matches(+report: A.Report,expected: List<&2,String>,complete: Bool,truncated: Bool) -> Bool:
  A.Report{values,_} = report
  equal(rows(values),expected) && same_bool(A.complete(report),complete) && same_bool(A.truncated(report),truncated)

def expect(provider: String,raw: String,expected: List<&2,String>,complete: Bool,truncated: Bool,label: String) -> IO(Unit):
  check(matches(A.analyze(provider,raw),expected,complete,truncated),label)

def claude(content: String) -> String:
  "{\"type\":\"user\",\"message\":{\"content\":" ++ content ++ "}}"

def response(kind: String,body: String) -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":" ++ J.quote(kind) ++ "," ++ body ++ "}}"

def local() -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":\"/synthetic/picture.bin\"}}"

def ignored() -> String:
  "{\"type\":\"text\",\"text\":\"/synthetic/prose.png\",\"image_url\":\"/synthetic/not-an-image.png\"}"

def basics() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(A.version(),"attachment-occurrences-v1"),"extractor occurrence profile is explicit")
    expect("claude",claude("[]"),[],True{},False{},"empty content has a complete empty occurrence scan")
    expect("claude",claude(J.quote("look at /synthetic/image.png")),[],True{},False{},"prose path never becomes an attachment")
    expect("claude",claude("[" ++ ignored() ++ "]"),[],True{},False{},"unknown fields of a known text block are not recursively searched")
    expect("claude",claude("[{\"type\":\"tool_use\",\"name\":\"Read\",\"input\":{\"file_path\":\"/synthetic/private.png\",\"content\":[" ++ local() ++ "]}}]"),
      [],True{},False{},"tool arguments and quoted conversation content are never attachment containers")
    expect("claude",claude("[" ++ local() ++ "]"),
      ["0|/message/content/0/source/path|image|local:/synthetic/picture.bin"],True{},False{},"image-only record has an exact source occurrence")
    expect("claude",claude("[{\"type\":\"document\",\"source\":{\"type\":\"file\",\"path\":\"/synthetic/absent.pdf\"}}]"),
      ["0|/message/content/0/source/path|document|local:/synthetic/absent.pdf"],True{},False{},"local existence remains unknown without filesystem reads")
    expect("claude",claude("[{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/image.png\"}}]"),
      ["0|/message/content/0/source/url|image|remote:https://example.invalid/image.png"],True{},False{},"remote URL is explicitly unfetched")
    expect("claude",claude("[{\"type\":\"document\",\"source\":{\"type\":\"url\",\"url\":\"file://localhost/synthetic/document.pdf\"}}]"),
      ["0|/message/content/0/source/url|document|file-url:file://localhost/synthetic/document.pdf"],True{},False{},"local file URL remains an undecoded typed reference")
    expect("claude",claude("[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"AAH+/w==\"}}]"),
      ["0|/message/content/0/source/data|image|inline:image/png:base64:8:4"],True{},False{},"inline binary representation is retained without putting bytes in descriptor")
    expect("claude",claude("[{\"type\":\"document\",\"source\":{\"type\":\"future\",\"payload\":\"secret-inline-data\"}}]"),
      ["0|/message/content/0/source|document|unsupported:unsupported_attachment_source_type"],True{},False{},"unknown source variant has an explicit unsupported occurrence")

def nested_cases() -> IO(Unit):
  +event = A.analyze("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"local_images\":[\"/synthetic/a.png\"]}}")
  +reply = A.analyze("codex",response("message","\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":\"/synthetic/a.png\"}]"))
  do IO<Unit>:
    expect("claude",claude("[{\"type\":\"tool_result\",\"tool_use_id\":\"call\",\"content\":[" ++ ignored() ++ "," ++ local() ++ "]}]"),
      ["0|/message/content/0/content/1/source/path|image|local:/synthetic/picture.bin"],True{},False{},"nested Claude tool result retains exact structural path")
    expect("claude",claude("[" ++ local() ++ "," ++ local() ++ "]"),
      ["0|/message/content/0/source/path|image|local:/synthetic/picture.bin"
       "1|/message/content/1/source/path|image|local:/synthetic/picture.bin"],True{},False{},"equal references at two positions remain two occurrences")
    expect("codex",response("message","\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":\"/synthetic/a.png\"},{\"type\":\"image_url\",\"image_url\":{\"url\":\"https://example.invalid/b.png\"}}]"),
      ["0|/payload/content/0/image_url|input_image|local:/synthetic/a.png"
       "1|/payload/content/1/image_url/url|image_url|remote:https://example.invalid/b.png"],True{},False{},"Codex image URL string and object shapes keep distinct exact paths")
    expect("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"message\":\"Look\",\"images\":[\"/synthetic/a.png\"],\"local_images\":[\"/synthetic/a.png\",\"/synthetic/b.png\"]}}",
      ["0|/payload/local_images/0|input_image|local:/synthetic/a.png"
       "1|/payload/local_images/1|input_image|local:/synthetic/b.png"
       "2|/payload/images/0|input_image|local:/synthetic/a.png"],True{},False{},"Codex legacy image lists use fixed field order without guessing mirrors")
    expect("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"content\":[{\"type\":\"input_image\",\"image_url\":\"/synthetic/a.png\"}]}}",
      ["0|/payload/content/0/image_url|input_image|local:/synthetic/a.png"],True{},False{},"optional Codex user-message content is a documented attachment container")
    expect("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"message\":\"No images\"}}",[],True{},False{},
      "absent optional Codex content is a valid empty attachment scan")
    expect("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"content\":null}}",[],False{},False{},
      "present null Codex content is not confused with an absent field")
    expect("codex",response("function_call_output","\"call_id\":\"tool\",\"output\":[" ++ local() ++ "]"),
      ["0|/payload/output/0/source/path|image|local:/synthetic/picture.bin"],True{},False{},"function output content array is a known attachment container")
    expect("codex",response("custom_tool_call_output","\"call_id\":\"tool\",\"output\":{\"content\":[" ++ local() ++ "]}"),
      ["0|/payload/output/content/0/source/path|image|local:/synthetic/picture.bin"],True{},False{},"custom tool output content object is a known attachment container")
    expect("codex",response("function_call","\"name\":\"tool\",\"arguments\":{\"images\":[\"/synthetic/private.png\"]}"),
      [],True{},False{},"Codex tool arguments are never followed")
    expect("codex","{\"type\":\"message\",\"role\":\"assistant\",\"content\":[" ++ local() ++ "]}",
      ["0|/content/0/source/path|image|local:/synthetic/picture.bin"],True{},False{},"legacy top-level message preserves its different raw structural path")
    check(U32.is_eq(A.count(event),1) && U32.is_eq(A.count(reply),1) && A.complete(event) && A.complete(reply),
      "event/response mirror candidates remain separate raw-record occurrences without evidence-backed dedup")

def base64_expected_result(result: R.InlineCheck,encoded: U32,decoded: U32,label: String) -> IO(Unit):
  match result:
    case R.ValidBase64{a,b}: check(U32.is_eq(a,encoded) && U32.is_eq(b,decoded),label)
    case _: check(False{},label)

def base64_expected(text: String,encoded: U32,decoded: U32,label: String) -> IO(Unit):
  base64_expected_result(R.base64(text),encoded,decoded,label)

def base64_invalid_result(result: R.InlineCheck,wanted: String,label: String) -> IO(Unit):
  match result:
    case R.InvalidBase64{actual}: check(String.eq(actual,wanted),label)
    case _: check(False{},label)

def base64_invalid(text: String,wanted: String,label: String) -> IO(Unit):
  base64_invalid_result(R.base64(text),wanted,label)

def is_local(value: R.Reference) -> Bool:
  match value:
    case R.LocalPath{_}: True{}
    case _: False{}

def encoding_cases() -> IO(Unit):
  do IO<Unit>:
    base64_expected("",0,0,"empty base64 has exactly zero decoded bytes")
    base64_expected("Zg==",4,1,"one-byte RFC4648 vector")
    base64_expected("Zm8=",4,2,"two-byte RFC4648 vector")
    base64_expected("Zm9v",4,3,"three-byte RFC4648 vector")
    base64_expected("Zm9vYg==",8,4,"four-byte RFC4648 vector")
    base64_expected("Zm9vYmE=",8,5,"five-byte RFC4648 vector")
    base64_expected("Zm9vYmFy",8,6,"six-byte RFC4648 vector")
    base64_invalid("Zg=","invalid_base64_length","short padding is malformed")
    base64_invalid("Zh==","invalid_base64_padding","nonzero four pad bits are malformed")
    base64_invalid("Zm9=","invalid_base64_padding","nonzero two pad bits are malformed")
    base64_invalid("Zg==AAAA","invalid_base64_padding","payload after padding is malformed")
    base64_invalid("Zg==\n","invalid_base64_padding","whitespace after padding is not silently normalized")
    base64_invalid("Zm-_","invalid_base64_alphabet","URL-safe alphabet is not mistaken for standard base64")
    base64_invalid("Zg","invalid_base64_length","unpadded short input stays unsupported")
    base64_invalid("=m9v","invalid_base64_alphabet","leading padding is malformed")
    expect("claude",claude("[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"data\":\"Zh==\"}}]"),
      ["0|/message/content/0/source/data|image|inline-invalid::base64:invalid_base64_padding"],True{},False{},"malformed encoding remains an inline occurrence with invalid coverage")
    expect("codex",response("message","\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":\"data:image/png;base64,AAH+/w==\"}]"),
      ["0|/payload/content/0/image_url|input_image|inline:image/png:base64:8:4"],True{},False{},"data URL returns metadata and validated byte length only")
    check(String.eq(reference(R.url(J.JString{"data:image/png,unencoded"})),"unsupported:unsupported_data_url_encoding"),
      "unsupported data URL encoding is explicit")
    check(String.eq(reference(R.url(J.JString{"data:image/png;base64"})),"unsupported:data_url_missing_comma"),
      "truncated data URL is explicit")
    check(String.eq(reference(R.url(J.JString{"data:;base64,Zg=="})),"inline::base64:4:1"),
      "missing media type remains unknown without inventing an image type")
    check(String.eq(reference(R.url(J.JString{"data:image/png;charset=x;base64,Zg=="})),"unsupported:unsupported_data_url_encoding"),
      "unsupported data URL parameter is not silently dropped")

def malformed_cases() -> IO(Unit):
  do IO<Unit>:
    expect("claude","{bad",[],False{},False{},"malformed JSON does not become a complete empty scan")
    expect("claude","{\"type\":\"user\",\"type\":\"assistant\"}",[],False{},False{},"duplicate keys cannot select conflicting attachment containers")
    expect("claude","null",[],False{},False{},"nonobject JSON is explicit partial")
    expect("future",claude("[]"),[],False{},False{},"unknown provider remains partial")
    expect("claude","{\"type\":\"future_record\",\"message\":{\"content\":[" ++ local() ++ "]}}",[],False{},False{},
      "unknown record variant is not recursively guessed")
    expect("claude",claude("[{\"type\":\"future_block\",\"content\":[" ++ local() ++ "]}]"),[],False{},False{},
      "unknown block reports incomplete coverage without following arbitrary nested content")
    expect("claude",claude("[7]"),[],False{},False{},"nonobject content block is explicit partial")
    expect("claude",claude("null"),[],False{},False{},"missing or malformed content is explicit partial")
    expect("claude",claude("[{\"type\":\"image\"}]"),
      ["0|/message/content/0/source|image|unsupported:attachment_source_not_object"],True{},False{},"missing image source has an occurrence-level unsupported state")
    expect("codex",response("message","\"role\":\"tool\",\"content\":[" ++ local() ++ "]"),[],False{},False{},
      "unknown message role does not authorize an attachment container")
    expect("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"local_images\":7}}",[],False{},False{},
      "malformed image-reference list cannot claim complete scan")
    expect("codex","{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"images\":[7]}}",
      ["0|/payload/images/0|input_image|unsupported:reference_not_string"],True{},False{},"malformed list element keeps its own source position")
    expect("codex",response("function_call_output","\"output\":{\"unknown\":[" ++ local() ++ "]}"),[],False{},False{},
      "unknown output object stays partial and is not recursively searched")

def reference_cases() -> IO(Unit):
  +inlined = R.url(J.JString{"data:image/png;base64,AAH+/w=="})
  do IO<Unit>:
    check(String.eq(reference(R.url(J.JString{"file:///synthetic/a%20b.png"})),"file-url:file:///synthetic/a%20b.png"),
      "file URL escapes stay exact for a later path-policy resolver")
    check(String.eq(reference(R.url(J.JString{"file://remotehost/a.png"})),"unsupported:unsupported_reference_scheme_or_relative_path"),
      "remote file authority is unsupported")
    check(String.eq(reference(R.url(J.JString{"relative/picture.png"})),"unsupported:unsupported_reference_scheme_or_relative_path"),
      "relative path never inherits an implicit working directory")
    check(String.eq(reference(R.url(J.JString{"/synthetic/bad\0.png"})),"unsupported:reference_text_limit_or_invalid_scalar"),
      "embedded NUL path remains unsupported")
    check(String.eq(reference(R.url(J.JString{"https://"})),"unsupported:unsupported_reference_scheme_or_relative_path"),
      "empty HTTP authority does not become a usable remote reference")
    check(String.eq(reference(R.url(J.JString{"/" ++ String.repeat("中",1366n)})),"unsupported:reference_text_limit_or_invalid_scalar"),
      "local reference bound counts UTF8 bytes")
    check(is_local(R.url(J.JString{"/" ++ String.repeat("中",1365n)})),
      "exact4096-byte Unicode reference remains typed local")
    check(Bool.not(String.contains(reference(inlined),"AAH+")) && Bool.not(String.contains(R.summary(inlined),"AAH+")),
      "neither typed inline descriptor signature nor readable summary contains base64 payload")
    check(String.eq(R.summary(R.LocalPath{"/synthetic/private-name.png"}),"Local file reference; external bytes not captured"),
      "readable local summary cannot claim missing saved or authorized status")
    check(String.eq(R.summary(R.RemoteURL{"https://example.invalid/?private=value"}),"Remote reference; never fetched"),
      "readable remote summary does not leak URL query or imply a fetch")

def last_row(values: List<&2,A.Occurrence>) -> String:
  match values:
    case []: ""
    case [value]: row(value)
    case _ <> rest: last_row(rest)

def last_report_row(report: A.Report) -> String:
  A.Report{values,_} = report
  last_row(values)

def nested_block(depth: Nat,inside: String) -> String:
  match depth:
    case 0n: inside
    case 1n+left:
      nested_block(left,"{\"type\":\"tool_result\",\"content\":[" ++ inside ++ "]}")

def limits() -> IO(Unit):
  +sixty_four = "[" ++ String.repeat(local() ++ ",",63n) ++ local() ++ "]"
  +sixty_five = "[" ++ String.repeat(local() ++ ",",64n) ++ local() ++ "]"
  +a = A.analyze("claude",claude(sixty_four))
  +b = A.analyze("claude",claude(sixty_five))
  +c = A.analyze("claude",claude("[{\"type\":\"future_block\"}," ++ String.repeat(local() ++ ",",64n) ++ local() ++ "]"))
  +d = A.analyze("claude",claude("[" ++ String.repeat(ignored() ++ ",",5000n) ++ local() ++ "]"))
  +e = A.analyze("claude",claude("[" ++ nested_block(8n,local()) ++ "]"))
  +f = A.analyze("claude",claude("[" ++ nested_block(9n,local()) ++ "," ++ local() ++ "]"))
  do IO<Unit>:
    check(U32.is_eq(A.count(a),64) && A.complete(a) && Bool.not(A.truncated(a)) &&
      String.eq(last_report_row(a),"63|/message/content/63/source/path|image|local:/synthetic/picture.bin"),
      "exact64 occurrences preserve complete count and stable ordinal")
    check(U32.is_eq(A.count(b),64) && Bool.not(A.complete(b)) && A.truncated(b) && String.contains(A.reason(b),"total unknown"),
      "65th occurrence keeps bounded prefix and explicitly unknown total")
    check(U32.is_eq(A.count(c),64) && Bool.not(A.complete(c)) && A.truncated(c),
      "earlier unsupported variant cannot hide later occurrence truncation")
    check(U32.is_eq(A.count(d),0) && Bool.not(A.complete(d)) && A.truncated(d) && String.contains(A.reason(d),"scan_work_limit"),
      "bounded scan does not claim no attachments after an unexamined long prefix")
    check(U32.is_eq(A.count(e),1) && A.complete(e),"eight supported nested tool-result levels remain visible")
    check(U32.is_eq(A.count(f),1) && Bool.not(A.complete(f)) && A.truncated(f),
      "depth limit preserves later shallow siblings and explicit truncation")
    check(String.eq(reference(R.url(J.JString{"data:" ++ String.repeat("a",256n) ++ ",AAAA"})),"unsupported:data_url_header_limit"),
      "data URL header has a separate bounded scan")
    base64_invalid(String.repeat("A",1048580n),"inline_encoding_limit","base64 validation has an independent maximum")

def main() -> IO(Unit):
  do IO<Unit>:
    basics()
    nested_cases()
    encoding_cases()
    malformed_cases()
    reference_cases()
    limits()
