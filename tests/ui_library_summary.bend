import Base
import ../src/ui.bend as UI
import ../src/library_usage_view_types.bend as V

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)
def text() -> String: "Exact report café 中文 🙂\nInput: 9007199254740993\nUnknown counters are not zero."
def initial() -> UI.State:
  UI.focus_list(UI.set_results(UI.set_rows(UI.set_reader(UI.init(),"Library usage | all time",text()),["Claude","Codex"]),
    UI.LibraryUsageResults{2,2,[V.Summary{True{},[],[],"",False{}}]}))
def state(value: UI.State & UI.Action) -> UI.State:
  (s,_) = value
  s
def copied(value: UI.State & UI.Action) -> String:
  (_,action) = value
  match action:
    case UI.Copy{text}: text
    case _: "not copied"
def kind(value: UI.State & UI.Action) -> U32:
  (_,action) = value
  match action:
    case UI.NoAction{}: 0
    case UI.Scope{"claude"}: 1
    case UI.Back{}: 2
    case UI.Submit{}: 3
    case _: 99
def report() -> UI.State: state(UI.event(Mouse{912,128,0,True{}},initial()))
def selected() -> UI.State: UI.set_edit(report(),UI.Edit{2,12,0,False{},0})
def all() -> UI.State: state(UI.key_down(initial(),97,True{}))
def capture() -> UI.State:
  UI.set_results(selected(),UI.LibraryUsageResults{6,0,[]})

def main() -> IO(Unit):
  do IO<Unit>:
    check(UI.library_overview(initial()),"ready typed summary opens as the overview")
    check(String.eq(UI.reader(initial()),text()),"overview retains canonical report bytes separately")
    check(Bool.not(UI.library_overview(report())) && String.eq(UI.reader(report()),text()),"Report button changes presentation without rewriting evidence")
    check(UI.library_overview(state(UI.event(Mouse{912,128,0,True{}},report()))),"Overview button returns through the same explicit control")
    check(UI.library_overview(state(UI.event(Mouse{1000,128,0,True{}},initial()))),"right edge of Report target is excluded")
    check(UI.library_overview(state(UI.event(Mouse{912,152,0,True{}},initial()))),"bottom edge of Report target is excluded")
    check(String.eq(copied(UI.text_action(initial(),0)),text()),"Copy report emits complete canonical report from overview")
    check(String.eq(copied(UI.text_action(selected(),0)),text()),"Copy report remains complete even with a partial text selection")
    check(String.eq(copied(UI.key_down(selected(),99,True{})),UI.span(text(),0,12)),"Command C preserves exact partial report selection")
    check(Bool.not(UI.library_overview(all())) && String.eq(UI.selection(all()),text()),"Command A shows the full report with visible canonical selection")
    check(Bool.not(UI.library_overview(state(UI.text_action(initial(),3)))),"Select all control opens report mode")
    check(Bool.not(UI.library_overview(state(UI.key_down(initial(),9,False{})))),"Tab into evidence exposes report instead of hidden text focus")
    check(U32.is_eq(UI.focus(state(UI.event(Mouse{600,400,0,True{}},initial()))),1),"metric display click does not invent a canonical text offset")
    check(U32.is_eq(UI.scroll(state(UI.event(Scroll{600,400,0.0,F32.sub(0.0,1.0)},initial()))),0),"overview wheel does not scroll an invisible report")
    check(UI.library_overview(state(UI.key_down(initial(),63277,False{}))) && U32.is_eq(UI.scroll(state(UI.key_down(initial(),63277,False{}))),0),"overview Page Down leaves hidden report position unchanged")
    check(U32.is_eq(kind(UI.top_action(initial(),3)),1) && U32.is_eq(kind(UI.key_down(initial(),13,False{})),3),"typed provider filter and selected-capture activation remain existing actions")
    check(U32.is_eq(kind(UI.key_down(initial(),27,False{})),2),"Back remains the exact coordinator navigation action")
    check(U32.is_eq(UI.focus(state(UI.text_action(capture(),1))),2) && String.eq(UI.selection(state(UI.text_action(capture(),1))),UI.selection(capture())),"hidden toggle remains inert on an opened capture")
    check(UI.library_overview(UI.restore(UI.init(),UI.bookmark(initial()))) && Bool.not(UI.library_overview(UI.restore(UI.init(),UI.bookmark(report())))),"bookmarks preserve overview or report mode without changing origin identity")
