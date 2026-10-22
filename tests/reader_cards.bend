import Base
import ../src/reader_cards.bend as C
import ../src/reader_document.bend as D
import ../src/reader_projection.bend as P
import ../src/transcript_document.bend as T
import ../src/providers.bend as Provider

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def document(revision: U32) -> D.Document:
  T.render([T.record_all("4",[Provider.ProviderEvent{"assistant","A🙂 é 中文\n```bend\nx = 3\n```\nB café",
    "Write","call-1","secret-input","secret-result","/synthetic","session","2026-10-22T00:00:00Z","model","usage","parent","partial_content"}],"Citation: captured bytes 1..99")],"12","Integrity warning stays visible",revision)

def part_key(parts: List<&2,D.Part>,+want: U32) -> D.PartKey:
  match parts:
    case []: D.PartKey{"","",0,0}
    case D.Part{key,D.ToolArguments{},_,_,_,_} <> rest:
      Bool.pick(D.PartKey,U32.is_eq(want,0),key,part_key(rest,want))
    case D.Part{key,D.EvidenceDetails{},_,_,_,_} <> rest:
      Bool.pick(D.PartKey,U32.is_eq(want,1),key,part_key(rest,want))
    case _ <> rest: part_key(rest,want)

def exact_rows(rows: List<&2,C.Row>,+text: String) -> Bool:
  match rows:
    case []: True{}
    case C.TextRow{start,+body,+count,_} <> rest:
      U32.is_eq(count,D.length(body)) && String.eq(body,D.slice(text,D.Span{start,count})) && exact_rows(rest,text)
    case _ <> rest: exact_rows(rest,text)

def has_code(rows: List<&2,C.Row>) -> Bool:
  match rows:
    case []: False{}
    case C.TextRow{_,body,_,2} <> rest: String.eq(body,"x = 3") || has_code(rest)
    case _ <> rest: has_code(rest)

def selected(value: Maybe<&2,P.Selection>) -> String:
  match value:
    case Some{value}: P.selection_text(value)
    case None{}: "invalid"

def is_none(value: Maybe<&2,P.Selection>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def main() -> IO(Unit):
  +doc = document(7)
  +model = C.open(doc,"session-scope\0snapshot12\0start0\0role-all")
  +key = part_key(D.parts(doc),0)
  +expanded = C.toggle(model,C.token(model),key)
  +selected_model = C.sync(model,0,C.count(model),True{})
  +folded_after_selection = C.toggle(selected_model,C.token(selected_model),key)
  +next_page = C.open(document(8),"session-scope\0snapshot12\0start40\0role-all")
  +next_scope = C.open(document(7),"session-scope\0snapshot12\0start0\0role-user")
  +focused = C.with_focus(model,Some{key})
  do IO<Unit>:
    check(Bool.not(String.contains(C.text(model),"secret-input")) && Bool.not(String.contains(C.text(model),"secret-result")) && Bool.not(String.contains(C.text(model),"Recorded model:")),"tool input result and evidence details begin folded")
    check(String.contains(C.text(model),"partial_content") && String.contains(C.text(model),"Integrity warning stays visible"),"coverage and page warnings always remain visible")
    check(String.contains(C.text(model),"A🙂 é 中文") && String.contains(C.text(model),"```bend\nx = 3\n```\nB café"),"message and code scalar content remains exact")
    check(String.eq(C.canonical(model),D.text(doc)),"folding retains complete canonical evidence separately")
    check(U32.is_eq(C.count(model),D.length(C.text(model))) && U32.is_eq(C.row_count(model),U32.from_nat(List.length(&2,C.Row,C.rows(model)))),"scalar and visual row counts are cached at page admission")
    check(exact_rows(C.rows(model),C.text(model)),"all text rows map to exact visible scalar slices")
    check(has_code(C.rows(model)),"typed closed code fence receives code presentation")
    check(U32.is_eq(U32.from_nat(List.length(&2,D.PartKey,C.controls(C.rows(model)))),3),"three explicit eligible disclosure controls are reachable")
    check(String.contains(C.text(expanded),"secret-input") && Bool.not(String.contains(C.text(expanded),"secret-result")),"one disclosure expands only its own exact source part")
    check(U32.is_eq(C.revision(expanded),8) && String.eq(C.canonical(expanded),D.text(doc)),"fold revision advances without replacing captured document")
    check(String.eq(selected(C.selection(selected_model,C.token(selected_model))),C.text(model)),"select all copies exactly visible text across hidden parts")
    check(String.eq(selected(C.selection(folded_after_selection,C.token(folded_after_selection))),""),"fold clears existing selection and drag")
    check(is_none(C.selection(next_page,C.token(expanded))),"old page fold8 cannot copy new page loaded at revision8")
    check(Bool.not(C.accepts(next_scope,C.token(model))),"same snapshot and revision with different filter rejects old token")
    check(String.eq(C.text(C.toggle(next_page,C.token(expanded),key)),C.text(next_page)),"old page fold token cannot toggle same snapshot new range")
    check(Maybe.is_some(&2,D.PartKey,C.focus_next(model,False{})) && Maybe.is_some(&2,U32,C.focused_row(focused)),"keyboard control sequence and focus geometry are available")
    check(is_none(C.selection(model,C.token(expanded))),"stale fold revision cannot copy old projection")
    check(exact_rows(C.rows(expanded),C.text(expanded)),"expanded tool rows preserve all canonical text scalars")
