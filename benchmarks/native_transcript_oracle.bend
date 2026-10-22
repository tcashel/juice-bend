import Base
import ../src/json.bend as J
import ../src/domain.bend as D

# Acceptance only: validate actual CLI receipts against independent synthetic
# fixture facts, then return their canonical text for native clipboard equality.
# This imports neither the transcript formatter nor a provider parser. It never
# opens an application database or source archive, and writes no files.
def checked(valid: Bool,message: String) -> IO(Unit):
  match valid:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,2,"Transcript native oracle: " ++ message)

def decoded(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{_}: IO.die(String,2,"Receipt is not strict UTF8")

def next_sized(fits: Bool,file: File,size: U32,total: U32,part: List<&2,U32>,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  match fits:
    case False{}:
      do IO<String>:
        File.close(file)
        IO.die(String,2,"Receipt exceeds 262144 bytes")
    case True{}: next(file,U32.add(total,size),part <> chunks)

def next_chunk(file: File,bytes: List<&2,U32>,+total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  match bytes:
    case []:
      do IO<String>:
        File.close(file)
        decoded(D.decode(List.concat(&2,U32,List.reverse(&2,List<&2,U32>,chunks))))
    case byte <> rest:
      +part = {byte <> rest : List<&2,U32>}
      +size = U32.from_nat(List.length(&2,U32,part))
      next_sized(U32.is_le(size,U32.sub(262144,total)),file,size,total,part,chunks,next)

def read_result(got: File & Result<&1,&1,U32 & String,List<&2,U32>>,total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(String)) -> IO(String):
  (file,result) = got
  match result:
    case Fail{_}:
      do IO<String>:
        File.close(file)
        IO.die(String,2,"Cannot read receipt")
    case Done{bytes}: next_chunk(file,bytes,total,chunks,next)

def read(fuel: Nat,+total: U32,chunks: List<&2,List<&2,U32>>,file: File) -> IO(String):
  match fuel:
    case 0n:
      do IO<String>:
        File.close(file)
        IO.die(String,2,"Receipt read iteration bound exceeded")
    case 1n+left:
      do IO<String>:
        got : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
          File.read_bytes(file,U32.min(4096,U32.add(U32.sub(262144,total),1)))
        read_result(got,total,chunks,f => n => parts => read(left,n,parts,f))

def parse(result: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match result:
    case Done{value}: IO.pure(J.Json,value)
    case Fail{_}: IO.die(J.Json,2,"Receipt is not bounded valid JSON")

def input(path: String) -> IO(J.Json):
  do IO<J.Json>:
    file : File <- IO.try(File,File.open(path,"r"))
    raw : String <- read(262145n,0,[],file)
    parse(J.parse(raw))

def equal_field(value: J.Json,key: String,expected: String) -> Bool:
  String.eq(J.get(value,key),expected)

def citation(+source: String,+extent: String,record: U32) -> String:
  "Citation: {\"provider\":\"claude\",\"source\":" ++ J.quote(source) ++
    ",\"generation\":\"1\",\"snapshot\":\"1\",\"extent\":" ++ J.quote(extent) ++
    ",\"record\":" ++ J.quote(U32.show(record)) ++ ",\"event\":\"0\"}\n"

def citation_count(lines: List<&2,String>) -> U32:
  match lines:
    case []: 0
    case +line <> rest:
      U32.add(Bool.to_u32(String.starts_with(line,"Citation: ")),citation_count(rest))

def citations(fuel: Nat,+ordinal: U32,+text: String,+source: String,+extent: String) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+left:
      (U32.is_eq(ordinal,11) || U32.is_eq(ordinal,19) || String.contains(text,citation(source,extent,ordinal))) &&
        citations(left,U32.inc(ordinal),text,source,extent)

def first_body() -> String:
  "attachment-native-search — Preserve this synthetic attachment fixture, café 中文 🙂.\n" ++
    "Keep the exact tool request and result after source removal.\n```bend\nlet preserved = 42\n```\n" ++
    "The first reader range contains four raw-record attachment pages."

def late_body() -> String:
  "attachment-late-40 café 中文 🙂\nThe second transcript page begins at physical record 40.\n" ++
    "Captured text remains readable after the archive source was removed."

def final_body() -> String:
  "attachment-late-41 — final retained record.\nExact response: preserved = 42; café 中文 🙂.\n" ++
    "There are no attachment references on this final two-record page."

# The canonical JSON payload preserves LF as the literal escape \u000a.
# This exact full-object expectation includes the nested argument evidence.
def tool_argument() -> String:
  "Arguments: {\"file_path\":\"synthetic-only.txt\",\"content\":\"let preserved = 42\\u000a// café 中文 🙂\\u000a\"," ++
    "\"nested_artifact_probe\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"application/octet-stream\",\"data\":\"AAH+/w==\"}}]}\n"

def event_count(kind: String) -> String:
  match kind:
    case "first": "38"
    case "late": "2"
    case _: "1"

def scope(kind: String) -> String:
  match kind:
    case "filtered": "Provider: claude · repository: /synthetic/attachments · role: user · after: 2026-10-20"
    case _: "Provider: claude · repository: all · role: all · after: all"

def kind_assertions(+kind: String,+text: String,+source: String,+extent: String) -> IO(Unit):
  match kind:
    case "first":
      do IO<Unit>:
        checked(String.contains(text,first_body()) && String.contains(text,"Tool: Write\nCall ID: synthetic-write-9\n" ++ tool_argument()),"complete user body or tool payload lost")
        checked(String.contains(text,"Call ID: synthetic-nested\nResult: Nested retained attachment follows\n") &&
          String.contains(text,"Call ID: synthetic-write-9\nResult: Saved synthetic-only.txt; result marker attachment-tool-result café 中文 🙂.\nThis is recorded synthetic evidence; no tool command was executed.\n"),"exact tool results lost")
        checked(String.contains(text,"[attachment] 2026-10-20T12:00:00.000000000Z · [r0:e0] · coverage: unsupported_attachment\n") &&
          String.contains(text,"[Unsupported Claude content block]") && String.contains(text,"[Claude record has no supported message content]"),"partial or unsupported evidence hidden")
        checked(citations(40n,0,text,source,extent) && U32.is_eq(citation_count(String.lines(text)),38),"first page citation set differs from independent event positions")
        checked(Bool.not(String.contains(text,late_body())) && Bool.not(String.contains(text,"[r11:e0]")) &&
          Bool.not(String.contains(text,"[r19:e0]")),"out-of-range or invented empty-record event")
    case "late":
      do IO<Unit>:
        checked(String.contains(text,late_body()) && String.contains(text,final_body()),"late full payload lost")
        checked(citations(2n,40,text,source,extent) && U32.is_eq(citation_count(String.lines(text)),2),"late exact citation set differs")
        checked(Bool.not(String.contains(text,first_body())) && Bool.not(String.contains(text,"[r39:e0]")),"earlier event leaked into late page")
    case _:
      do IO<Unit>:
        checked(String.contains(text,late_body()) && Bool.not(String.contains(text,final_body())),"role-filtered late page lost user content or leaked excluded assistant")
        checked(String.contains(text,citation(source,extent,40)) && U32.is_eq(citation_count(String.lines(text)),1),"filtered page citation set differs")
        checked(String.contains(text,"the complete snapshot was not reverified"),"bounded verification caveat lost")

def page_assertions(+kind: String,+text: String,+source: String,+extent: String) -> IO(Unit):
  do IO<Unit>:
    checked(String.starts_with(text,"Transcript · snapshot 1 · " ++ event_count(kind) ++ " events\n" ++
      "Bounded captured page; details and references follow.\n\n"),"compact header or independent visible event count differs")
    checked(String.contains(text,"Page details & exact references\nJuice Bend · scoped captured transcript\n") &&
      String.contains(text,scope(kind)) &&
      String.contains(text,"Byte offsets: logical source bytes (decompressed for archives)."),"scope or logical byte-space disclosure missing")
    checked(String.contains(text,"Captured repository: /synthetic/attachments\nSession reference: native-attachments-synthetic\n") &&
      String.contains(text,"Recorded time: 2026-10-20T12:00:00.000000000Z\n"),"recorded metadata lost")
    kind_assertions(kind,text,source,extent)

def output(+text: String) -> String:
  "{\"kind\":\"validated_native_transcript_oracle_v1\",\"text\":" ++ J.quote(text) ++
    ",\"pointer\":\"Transcript\",\"export\":" ++ J.quote("# Juice Bend scoped captured evidence\n\n" ++
      "This is a bounded captured-record range, not a complete transcript export. Byte offsets refer to logical source bytes (decompressed for archives).\n\n" ++ text) ++ "}"

def run(+kind: String,+root: String,+manifest: J.Json,+page: J.Json) -> IO(Unit):
  +source = root ++ "/sources/attachment-fixture.jsonl.zst"
  +extent = J.get(manifest,"logical_bytes")
  +start = Bool.pick(String,String.eq(kind,"first"),"0","40")
  +selected = Bool.pick(String,String.eq(kind,"first"),"40","2")
  +text = J.get(page,"text")
  do IO<Unit>:
    checked(String.eq(kind,"first") || String.eq(kind,"late") || String.eq(kind,"filtered"),"unknown page kind")
    checked(String.starts_with(root,"/private/tmp/juice-bend-attachments-fixture-") && equal_field(manifest,"root",root) &&
      equal_field(manifest,"fixture","juice-bend-attachments-fixture-v1") && equal_field(manifest,"source",source) &&
      equal_field(manifest,"source_removed","true") && equal_field(manifest,"snapshot","1") && equal_field(manifest,"physical_records","42") &&
      Bool.not(String.is_empty(extent)),"unexpected fixture identity or source-loss receipt")
    checked(equal_field(page,"kind","scoped_transcript_page") && equal_field(page,"snapshot","1") && equal_field(page,"start",start) &&
      equal_field(page,"requested_records","40") && equal_field(page,"selected_records",selected) && equal_field(page,"complete_export","false") &&
      equal_field(page,"byte_space","logical_source_bytes"),"actual CLI range envelope differs")
    page_assertions(kind,text,source,extent)
    IO.print(output(text))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> kind <> root <> manifest_path <> page_path <> []:
      do IO<Unit>:
        manifest : J.Json <- input(manifest_path)
        page : J.Json <- input(page_path)
        run(kind,root,manifest,page)
    case _: IO.die(Unit,2,"Expected first|late|filtered ROOT FIXTURE_JSON ACTUAL_CLI_JSON")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
