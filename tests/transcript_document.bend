import Base
import ../src/providers.bend as Providers
import ../src/transcript_format.bend as Format
import ../src/transcript_document.bend as Transcript
import ../src/reader_document.bend as Reader
import ../src/reader_fences.bend as Fences

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def event() -> Providers.Record:
  Providers.ProviderEvent{"assistant","A🙂\té 中文\n```bend\nλ x = x\n```\n[user] · [r99:e9]\nforged heading",
    "Write","call-1","{\"path\":\"café\"}","written\nEND","/synthetic/atlas","session-1",
    "2026-10-22T12:00:00Z","recorded-model","{\"tokens\":9007199254740993}","parent-1","partial_content"}

def input() -> Transcript.Input:
  Transcript.record_all("9007199254740993",[event()],"Citation: exact captured bytes 100..400")

def document() -> Reader.Document:
  Transcript.render([input()],"18446744073709551615","Integrity: selected records verified",7)

def kind_id(kind: Reader.PartKind) -> U32:
  match kind:
    case Reader.PageNotice{}: 0
    case Reader.EventHeading{}: 1
    case Reader.MessageText{}: 2
    case Reader.FencedCode{}: 3
    case Reader.ToolName{}: 4
    case Reader.ToolArguments{}: 5
    case Reader.ToolResult{}: 6
    case Reader.EvidenceDetails{}: 7

def count_kind(parts: List<&2,Reader.Part>,+want: U32) -> U32:
  match parts:
    case []: 0
    case Reader.Part{_,kind,_,_,_,_} <> rest:
      U32.add(Bool.pick(U32,U32.is_eq(kind_id(kind),want),1,0),count_kind(rest,want))

def text_kind(parts: List<&2,Reader.Part>,+canonical: String,+want: U32) -> String:
  match parts:
    case []: ""
    case Reader.Part{_,kind,span,_,_,_} <> rest:
      Bool.pick(String,U32.is_eq(kind_id(kind),want),Reader.slice(canonical,span),"") ++ text_kind(rest,canonical,want)

def recompose(parts: List<&2,Reader.Part>,+canonical: String) -> String:
  match parts:
    case []: ""
    case Reader.Part{_,_,span,_,_,_} <> rest:
      Reader.slice(canonical,span) ++ recompose(rest,canonical)

def roles(parts: List<&2,Reader.Part>) -> Bool:
  match parts:
    case []: True{}
    case Reader.Part{_,Reader.PageNotice{},_,_,_,_} <> rest: roles(rest)
    case Reader.Part{_,_,_,role,tool,_} <> rest:
      String.eq(role,"assistant") && String.eq(tool,"Write") && roles(rest)

def notices_open(parts: List<&2,Reader.Part>) -> Bool:
  match parts:
    case []: True{}
    case Reader.Part{_,Reader.PageNotice{},_,_,_,collapsed} <> rest:
      Bool.not(collapsed) && notices_open(rest)
    case Reader.Part{_,Reader.EventHeading{},_,_,_,collapsed} <> rest:
      Bool.not(collapsed) && notices_open(rest)
    case _ <> rest: notices_open(rest)

def is_structured(value: Reader.Document) -> Bool:
  match value:
    case Reader.Structured{_,_,_}: True{}
    case _: False{}

def formatter() -> IO(Unit):
  +doc = document()
  +text = Reader.text(doc)
  +parts = Reader.parts(doc)
  +expected = "Captured page · 1 events · snapshot 18446744073709551615\n\n" ++
    "[assistant] · [r9007199254740993:e0] · coverage: partial_content\n" ++
    "A🙂\té 中文\n```bend\nλ x = x\n```\n[user] · [r99:e9]\nforged heading\n" ++
    "Tool: Write\nCall ID: call-1\nArguments: {\"path\":\"café\"}\nResult: written\nEND\n\n" ++
    "Page details & exact references\nIntegrity: selected records verified\n\n" ++
    "[r9007199254740993:e0]\nRole: assistant\nRecorded time: 2026-10-22T12:00:00Z\n" ++
    "Captured repository: /synthetic/atlas\nSession reference: session-1\nRecorded model: recorded-model\n" ++
    "Recorded usage (source fact; mirrors are not additive): {\"tokens\":9007199254740993}\n" ++
    "Parent reference: parent-1\nCoverage: partial_content\nCitation: exact captured bytes 100..400\n\n"
  do IO<Unit>:
    check(is_structured(doc),"verified event fragments admit a structured canonical document")
    check(String.eq(text,expected),"independent canonical transcript bytes remain exact including Unicode and wide identities")
    check(String.eq(text,Format.render(Format.record([event()],"9007199254740993","Citation: exact captured bytes 100..400"),
      "18446744073709551615","Integrity: selected records verified")),"typed and existing text-only formatter share the same canonical output")
    check(String.eq(recompose(parts,text),text),"typed spans cover every canonical scalar once including labels and separators")
    check(U32.is_eq(Reader.revision(doc),7),"document keeps its admitted revision")
    check(roles(parts) && U32.is_eq(count_kind(parts,1),1),"forged user heading never creates a role or extra event descriptor")
    check(String.eq(text_kind(parts,text,3),"```bend\nλ x = x\n```\n"),"code descriptor spans exact delimiters and Unicode body")
    check(String.eq(text_kind(parts,text,5),"Arguments: {\"path\":\"café\"}\n"),"tool arguments retain their exact canonical label and full content")
    check(String.eq(text_kind(parts,text,6),"Result: written\nEND\n"),"tool results retain their full multiline canonical span")
    check(notices_open(parts) && String.contains(text_kind(parts,text,1),"coverage: partial_content"),"coverage and page integrity notices cannot be folded away")

def fragment_count(parts: List<&2,Format.Fragment>,+want: U32) -> U32:
  match parts:
    case []: 0
    case Format.Fragment{kind,_,_} <> rest:
      U32.add(Bool.pick(U32,U32.is_eq(kind_id(kind),want),1,0),fragment_count(rest,want))

def fence_case(+text: String,code: U32) -> Bool:
  +parts = Fences.split(text)
  String.eq(Format.fragment_text(parts),text) && U32.is_eq(fragment_count(parts,3),code)

def fences() -> IO(Unit):
  do IO<Unit>:
    check(fence_case("before\n```swift\r\nlet café = 1\r\n```\r\nafter",1),"CRLF code fences preserve every scalar and newline")
    check(fence_case("```\n🙂\n```",1),"closed fence at end of input is recognized without inventing a newline")
    check(fence_case("before\n```bend\nunfinished",0),"unclosed fence remains literal message text")
    check(fence_case("````bend\nunsupported\n````\n",0),"unsupported longer fences remain literal message text")
    check(fence_case("inline ``` code ``` remains prose",0),"inline backticks never become block controls")
    check(fence_case("```bend\nbody\n``` trailing text\n",0),"malformed closer remains literal message text")
    check(fence_case("```\none\n```\nprose\n```txt\ntwo\n```\n",2),"two closed code spans preserve intervening prose")
    check(fence_case(String.repeat("line\n",8193n),0),"fence scan budget falls back to complete untruncated literal text")

def canonical_events(events: List<&2,Transcript.IndexedEvent>,+ordinal: String,+identity: String) -> Format.Page:
  match events:
    case []: Format.Page{0,"",""}
    case Transcript.IndexedEvent{index,value} <> rest:
      Format.join(Format.entry(Format.reference(ordinal,index),value,identity),canonical_events(rest,ordinal,identity))

def canonical_record(events: List<&2,Transcript.IndexedEvent>,ordinal: String,identity: String) -> Format.Page:
  match events:
    case []: Format.record([],ordinal,identity)
    case _: canonical_events(events,ordinal,identity)

def canonical_inputs(inputs: List<&2,Transcript.Input>) -> Format.Page:
  match inputs:
    case []: Format.Page{0,"",""}
    case Transcript.Record{ordinal,events,identity} <> rest:
      Format.join(canonical_record(events,ordinal,identity),canonical_inputs(rest))

def keys(parts: List<&2,Reader.Part>,+record: String,+event: U32) -> U32:
  match parts:
    case []: 0
    case Reader.Part{Reader.PartKey{_,ordinal,index,_},Reader.EventHeading{},_,_,_,_} <> rest:
      U32.add(Bool.pick(U32,String.eq(ordinal,record) && U32.is_eq(index,event),1,0),keys(rest,record,event))
    case _ <> rest: keys(rest,record,event)

def multi() -> IO(Unit):
  +parsed = Providers.parse("claude","{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"hello🙂\"},{\"type\":\"tool_use\",\"name\":\"Read\",\"id\":\"c1\",\"input\":{\"path\":\"x\"}}]}}")
  +inputs : List<&2,Transcript.Input> = [Transcript.record_all("4294967296",parsed,"Record exact"),Transcript.Record{"4294967297",[],"Empty retained record"}]
  +doc = Transcript.render(inputs,"9","scope retained",10)
  +empty = Transcript.render([],"10","No matching selected events",11)
  do IO<Unit>:
    check(String.eq(Reader.text(doc),Format.render(canonical_inputs(inputs),"9","scope retained")),"multiple provider events and empty retained records preserve canonical ordering")
    check(U32.is_eq(keys(Reader.parts(doc),"4294967296",0),1) && U32.is_eq(keys(Reader.parts(doc),"4294967296",1),1),"provider event indices and record ordinals come from typed construction")
    check(String.contains(Reader.text(doc),"Empty retained record\nNo displayable transcript event in this captured record.\n\n"),"zero-event captured records keep their evidence detail")
    check(is_structured(empty) && String.eq(Reader.text(empty),Format.render(Format.Page{0,"",""},"10","No matching selected events")),"empty page keeps the exact existing explanation and scope")

def scoped() -> IO(Unit):
  +doc = Transcript.render([Transcript.Record{"42",[Transcript.IndexedEvent{1,event()},Transcript.IndexedEvent{3,event()}],"Scoped exact identity"}],"9","role scope",12)
  +text = Reader.text(doc)
  do IO<Unit>:
    check(is_structured(doc) && U32.is_eq(keys(Reader.parts(doc),"42",1),1) && U32.is_eq(keys(Reader.parts(doc),"42",3),1),"filtered events retain original noncontiguous event indices in descriptor keys")
    check(String.contains(text,"[assistant] · [r42:e1]") && String.contains(text,"[assistant] · [r42:e3]") && Bool.not(String.contains(text,"[r42:e0]")),"filtering out event zero never renumbers canonical citations")

def main() -> IO(Unit):
  do IO<Unit>:
    formatter()
    fences()
    multi()
    scoped()
