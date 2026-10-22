import Base
import ../src/transcript_format.bend as Format
import ../src/providers.bend as Providers
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def message(role: String,text: String,coverage: String) -> Providers.Record:
  Providers.ProviderEvent{role,text,"","","","","/synthetic/repository","session-1",
    "2026-10-20T12:00:00Z","model-1","","parent-1",coverage}

def line_text(lines: List<&2,UI.Line>) -> String:
  match lines:
    case []: ""
    case UI.Line{_,text} <> rest: text ++ "\n" ++ line_text(rest)

def copied(result: UI.State & UI.Action) -> String:
  (state,action) = result
  match action:
    case UI.Copy{text}: text
    case _: ""

def fields() -> IO(Unit):
  +payload = "Café é 中文 🙂\n" ++ String.repeat("x",4096n) ++ "\nTAIL body intact"
  +arguments = "{\"note\":\"" ++ String.repeat("a",4096n) ++ "終わり\"}"
  +result = "Result\tNUL-looking \\0\n" ++ String.repeat("r",4096n) ++ "\nEND result"
  +event = {Providers.ProviderEvent{"assistant",payload,"Write","call-1",arguments,result,
    "/synthetic/quoted\"café 中文 🙂","session-1","2026-10-20T12:00:00Z","recorded-model",
    "{\"input_tokens\":9007199254740993}","parent-1","partial_content"} : Providers.Record}
  +body = Format.body("[r7:e2]",event)
  +details = Format.details("[r7:e2]",event,"Citation: {\"snapshot\":\"9007199254740993\"}")
  expected = "[assistant] 2026-10-20T12:00:00Z · [r7:e2] · coverage: partial_content\n" ++
    payload ++ "\nTool: Write\nCall ID: call-1\nArguments: " ++ arguments ++ "\nResult: " ++ result ++ "\n\n"
  do IO<Unit>:
    check(String.eq(body,expected),"complete Unicode body, long arguments and long result remain unchanged and selectable")
    check(String.starts_with(body,"[assistant] 2026-10-20T12:00:00Z · [r7:e2] · coverage: partial_content\n"),
      "incomplete coverage is adjacent to the event before its content")
    check(Bool.not(String.contains(body,"Recorded model:")) && Bool.not(String.contains(body,"Citation:")),
      "technical metadata does not interrupt the conversation")
    check(String.contains(details,"Captured repository: /synthetic/quoted\"café 中文 🙂\n") &&
      String.contains(details,"Session reference: session-1\nRecorded model: recorded-model\n"),
      "appendix keeps complete repository, session and recorded model fields")
    check(String.contains(details,"Recorded usage (source fact; mirrors are not additive): {\"input_tokens\":9007199254740993}\n") &&
      String.contains(details,"Parent reference: parent-1\nCoverage: partial_content\n"),
      "appendix preserves wide recorded usage without inventing a total and retains parent and coverage")
    check(String.contains(details,"Citation: {\"snapshot\":\"9007199254740993\"}\n\n"),
      "formatter preserves the supplied exact citation bytes without interpreting identity numbers")
    check(String.eq(Format.reference("9007199254740993",4294967295),"[r9007199254740993:e4294967295]"),
      "short references do not round or truncate exact identities")

def missing() -> IO(Unit):
  +unknown = {Providers.ProviderEvent{"user","request","","","","","","","","","","",""} : Providers.Record}
  +complete = message("user","ordinary message","complete")
  +body = Format.body("[r0:e0]",unknown)
  +details = Format.details("[r0:e0]",unknown,"Record 0 · bytes 0..7")
  do IO<Unit>:
    check(String.eq(body,"[user] time not captured · [r0:e0] · coverage unavailable\nrequest\n\n"),
      "missing time and unknown coverage remain visible without invented values")
    check(String.contains(details,"Coverage: unavailable\nRecord 0 · bytes 0..7\n\n") &&
      Bool.not(String.contains(details,"tokens")),"missing usage is not shown as zero")
    check(Bool.not(String.contains(Format.body("[r0:e0]",complete),"coverage")) &&
      String.contains(Format.details("[r0:e0]",complete,"Record 0 · bytes 0..7"),"Coverage: complete\n"),
      "complete coverage moves to appendix while remaining explicit")
    check(String.contains(Format.body("[r0:e0]",message("user","attachment","unsupported_attachment")),
      "coverage: unsupported_attachment\nattachment"),"unsupported attachment coverage stays adjacent to the visible reference")

def viewport_and_copy() -> IO(Unit):
  pages = Format.events([
    message("user","first visible request","complete"),
    message("assistant","second visible reply","complete"),
    message("user","third visible request","complete"),
    message("assistant","fourth visible reply","complete"),
    message("user","fifth visible request","complete"),
    message("assistant","sixth visible reply","complete")],"7",0,"Record 7 · bytes 100..700")
  +text = Format.render(pages,"9007199254740993",
    "Provider: claude\nIntegrity: selected records verified; other ranges not checked.")
  +first = line_text(List.take(&2,UI.Line,UI.wrap(text),U32.to_nat(G.reader_rows())))
  +state = UI.set_edit(UI.set_reader(UI.init(),"Transcript",text),UI.Edit{2,0,0,False{},0})
  +selection = UI.select_all(state)
  do IO<Unit>:
    check(String.starts_with(text,"Transcript · snapshot 9007199254740993 · 6 events\n" ++
      "Bounded captured page; details and references follow.\n\n" ++
      "[user] 2026-10-20T12:00:00Z · [r7:e0]\nfirst visible request\n\n" ++
      "[assistant] 2026-10-20T12:00:00Z · [r7:e1]\nsecond visible reply\n\n"),
      "conversation order and compact references appear immediately after the bounded-page notice")
    check(String.contains(first,"first visible request") && String.contains(first,"third visible request") &&
      String.contains(first,"fifth visible request"),"actual native wrapping shows five short event bodies in the first viewport")
    check(Bool.not(String.contains(first,"Page details")) && Bool.not(String.contains(first,"Recorded model")),
      "first native viewport is not occupied by repeated metadata")
    check(String.contains(text,"Page details & exact references\nProvider: claude\n") &&
      String.contains(text,"[r7:e5]\nRole: assistant\n"),"explicit appendix retains references for the whole displayed page")
    check(String.eq(UI.reader(state),text) && String.eq(UI.selection(selection),text),
      "rendered reader and Select all use the same canonical string including appendix")
    check(String.eq(copied(UI.copy_action(selection,False{})),text),
      "actual copy action returns all canonical content and references without a separate display projection")

def empty_page() -> IO(Unit):
  +text = Format.render(Format.Page{0,"",""},"5","Visible events in this captured range: 0")
  do IO<Unit>:
    check(String.contains(text,"0 events\n") && String.contains(text,"No transcript events in this captured page.\n\n"),
      "empty selected page states that it has no transcript events")
    check(String.contains(text,"Page details & exact references\nVisible events in this captured range: 0"),
      "empty page retains its explicit scope and range appendix")

def main() -> IO(Unit):
  do IO<Unit>:
    fields()
    missing()
    viewport_and_copy()
    empty_page()
