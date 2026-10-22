import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G

def check(value: Bool,label: String) -> IO(Unit):
  match value:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def kind(value: UI.Action) -> U32:
  match value:
    case UI.NoAction{}: 0
    case UI.LibraryUsage{}: 1
    case UI.Usage{}: 2
    case UI.Refresh{}: 3
    case UI.Pause{}: 4
    case UI.Scope{"all"}: 5
    case UI.Scope{"claude"}: 6
    case UI.Scope{"codex"}: 7
    case UI.Back{}: 8
    case UI.Submit{}: 9
    case UI.Attachments{}: 10
    case UI.Why{}: 11
    case UI.Export{}: 12
    case UI.Previous{}: 13
    case UI.Next{}: 14
    case UI.Quit{}: 15
    case UI.Copy{_}: 16
    case _: 99

def action(value: UI.State & UI.Action) -> U32:
  (_,next) = value
  kind(next)

def state(value: UI.State & UI.Action) -> UI.State:
  (next,_) = value
  next

def panel(phase: U32) -> UI.State:
  UI.set_results(UI.set_rows(UI.set_reader(UI.set_query(UI.init(),"needle repo:/synthetic role:user"),
    "Library usage | all time","Partial coverage\nKnown input: 9007199254740993\nCached input: unknown\ncafé 中文 🙂"),["Claude session","Codex session"]),UI.LibraryUsageResults{phase,2,[]})

def click(+s: UI.State,x: U32,y: U32) -> U32:
  action(UI.event(Mouse{x,y,0,True{}},s))

def overview() -> IO(Unit):
  +s = panel(2)
  do IO<Unit>:
    check(U32.is_eq(click(UI.init(),16,504),1),"Library usage is a separate explicit sidebar destination")
    check(U32.is_eq(click(UI.init(),16,184),2),"selected-session Usage keeps its original destination")
    check(U32.is_eq(action(UI.top_action(s,0)),3) && U32.is_eq(action(UI.top_action(s,1)),4),"overview exposes reload and cancel")
    check(U32.is_eq(action(UI.top_action(s,2)),5) && U32.is_eq(action(UI.top_action(s,3)),6) && U32.is_eq(action(UI.top_action(s,4)),7),"provider controls return explicit All Claude Codex actions")
    check(U32.is_eq(action(UI.top_action(s,5)),8) && U32.is_eq(action(UI.top_action(s,6)),9),"overview Back and selected-capture Open stay separate")
    check(UI.provider_chips_visible(s) && Bool.not(UI.attachment_entry_visible(s)),"overview shows provider choice without a duplicate attachment shortcut")
    check(Bool.not(UI.result_available(UI.LibraryUsageResults{2,256,[]},True{})),"capture rows use the existing bounded list rather than a false extra-page control")

def target() -> IO(Unit):
  +s = panel(6)
  do IO<Unit>:
    check(U32.is_eq(action(UI.top_action(s,0)),8) && U32.is_eq(action(UI.top_action(s,1)),2),"captured page has report Back and whole selected-session Usage")
    check(U32.is_eq(action(UI.top_action(s,2)),10) && U32.is_eq(action(UI.top_action(s,3)),11),"captured page retains Attachments and Why")
    check(U32.is_eq(action(UI.top_action(s,4)),12),"captured page retains evidence export")
    check(U32.is_eq(action(UI.top_action(s,5)),13) && U32.is_eq(action(UI.top_action(s,6)),14),"captured page previous and next are explicit")
    check(Bool.not(UI.provider_chips_visible(s)),"provider choice cannot silently widen a captured page")
    check(U32.is_eq(action(UI.top_action(panel(5),0)),8) && U32.is_eq(action(UI.top_action(panel(5),4)),0),"pending captured page keeps Back and blocks unready toolbar export")

def interaction() -> IO(Unit):
  +s = panel(2)
  +typed = state(UI.text_event(s,"private accidental edit"))
  +all = state(UI.key_down(s,97,True{}))
  do IO<Unit>:
    check(String.eq(UI.query(typed),UI.query(s)) && String.eq(UI.reader(typed),UI.reader(s)),"library query is read-only even when origin focus was query")
    check(String.eq(UI.selection(all),UI.reader(s)),"Command A selects exact displayed evidence including unknowns and Unicode")
    check(U32.is_eq(action(UI.key_down(all,99,True{})),16),"Command C keeps exact reader copy route")
    check(U32.is_eq(action(UI.key_down(s,27,False{})),8),"Escape returns through the exact saved bookmark")
    check(U32.is_eq(action(UI.key_down(s,113,True{})),15),"Command Q is preserved")
    check(U32.is_eq(action(UI.key_down(s,13,False{})),9),"Return activates the selected capture")
    check(U32.is_eq(action(UI.key_down(s,118,True{})),0),"paste cannot alter the read-only usage scope")

def main() -> IO(Unit):
  do IO<Unit>:
    overview()
    target()
    interaction()
