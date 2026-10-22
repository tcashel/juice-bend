import Base
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/gui_quota.bend as Quota
import ../src/quota_store.bend as Store
import ../src/gui_settings.bend as Settings
import ../src/refresh_preferences.bend as Refresh
import ../src/gui_files.bend as Files

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

# Exact synthetic Connections body and clipboard from failed native v3.
# Fixed source slices are evidence, not a second wrapping/selection algorithm.
def body() -> String:
  "Claude Code quota\n\nOff\nChoose Enable, then review Manual setup.\n\nFive-hour: not received\nSeven-day: not received\nUnknown is different from 0%.\n\nDetails | Recorded fields\nLocal collection: off\nConnection epoch: 0\nNo usable observation in this view.\n\nReset dates are provider-supplied fields. Receipt dates use this device's clock; clock changes can reverse them.\nSequence orders accepted local receipts, not provider events.\nHistory survives disconnect. It keeps the latest sample per epoch and five-minute slot. Older receipts are trimmed when a usable observation arrives; the hard cap is 32,768 samples. New observations can shift offset pages.\n\nQuota is separate from captured-session usage and API-equivalent estimates. Account, plan and billed spend are not identified.\nCollection is explicit local opt-in. Enable creates a dedicated private quota store in the selected Juice Bend data directory.\nNo provider command, configuration change, credential read, network request or inference occurs here.\n"

def expected() -> String:
  "and five-minute slot."

def failed() -> String:
  "\n\nOff\nChoose Enable, then review Manual setup.\n\nFive-hour: not received\nSeven-day: not received\nUnknown is different from 0%.\n\nDetails | Recorded fields\nLocal collection: off\nConnection epoch: 0\nNo usable observation in this view.\n\nReset dates are provider-supplied fields. Receipt dates use this device's clock; clock changes can reverse them.\nSequence orders accepted local receipts, not provider events.\nHistory survives disconnect. It keeps the latest sample per epoch "

# The data root is a literal, never created or opened. service() is admitted
# only with loaded disabled preferences, no pending jobs and active Connections.
def root() -> String: "/synthetic/reader-release-replay"

def model() -> Quota.Model:
  Quota.Model{root(),2,Some{Store.State{0n,False{}}},None{},[],0,False{},0,0,None{},""}

def initial() -> Gui.State:
  Gui.quota_render(Gui.State{0,root(),"/usr/bin/false",UI.set_query(UI.init(),root()),
    Gui.Selection{[],"",0,0,[],Gui.empty_filters(),Gui.empty_listing()},
    Gui.Form{0,"","","",Files.empty(),[Gui.QuotaNavigation{[],[],[model()]}],
      [Gui.SettingsState{Settings.loaded(Settings.initial(),Refresh.Preferences{False{},Refresh.Live30{}}),[],"","claude"}]},
    Gui.Jobs{0,None{},None{},None{},False{}},0n,0})

def ui(state: Gui.State) -> UI.State:
  Gui.State{_,_,_,ui,_,_,_,_,_} = state
  ui

def idle_jobs(state: Gui.State) -> Bool:
  Gui.State{_,_,_,_,_,_,jobs,_,_} = state
  match jobs:
    case Gui.Jobs{_,None{},None{},None{},_}: True{}
    case _: False{}

def service_safe(+state: Gui.State) -> Bool:
  idle_jobs(state) && Gui.capture_suspended(state) &&
    Bool.not(Maybe.is_some(&2,Gui.Request,Gui.preference_next(Gui.settings_model(state)))) &&
    String.eq(UI.query(ui(state)),root())

def unwrapped(value: Maybe<Gui.State>) -> IO(Gui.State):
  match value:
    case None{}: IO.die(Gui.State,1,"FAIL replay unexpectedly closed the app state")
    case Some{state}: IO.pure(Gui.State,state)

# This is the actual production event fold. No trace calls, observer snapshots
# or assertions are inserted between individual events in one native batch.
def batch(events: List<Event>,state: Gui.State) -> IO(Gui.State):
  do IO<Gui.State>:
    value : Maybe<Gui.State> <- Gui.events(events,state)
    unwrapped(value)

def serviced(state: Gui.State,admitted: Bool) -> IO(Gui.State):
  match admitted:
    case False{}: IO.die(Gui.State,1,"FAIL replay service fixture has possible external work")
    case True{}: Gui.service(state)

def service(+state: Gui.State) -> IO(Gui.State):
  serviced(state,service_safe(state))

# Match App.turn's actual Image.drop after Gui.view without opening a window.
# This exercises rendering ownership while preserving the uninstrumented UI.
def drawn(value: Gui.State & Image) -> IO(Gui.State):
  (state,image) = value
  do IO<Gui.State>:
    Unit <- IO.pure(Unit,Image.drop!(image))
    return state

def view(state: Gui.State) -> IO(Gui.State):
  drawn(Gui.view(state))

# 0: no seam; 1: service only; 2: view/drop only;
# 3: real between-frame order, service then next view/drop.
def seam(state: Gui.State,kind: U32) -> IO(Gui.State):
  match kind:
    case 0: IO.pure(Gui.State,state)
    case 1: service(state)
    case 2: view(state)
    case 3:
      do IO<Gui.State>:
        next : Gui.State <- service(state)
        view(next)
    case _: IO.die(Gui.State,1,"FAIL unknown replay seam")

def frames(batches: List<List<Event>>,state: Gui.State,+kind: U32) -> IO(Gui.State):
  match batches:
    case []: IO.pure(Gui.State,state)
    case events <> rest:
      do IO<Gui.State>:
        next : Gui.State <- batch(events,state)
        across : Gui.State <- seam(next,kind)
        frames(rest,across,kind)

def positive() -> List<Event>:
  [Mouse{1065,584,0,True{}},Move{673,608},Mouse{673,608,0,False{}},Move{824,136}]

def negative() -> List<Event>:
  [Mouse{1065,584,0,True{}},Move{673,608},Move{824,136}]

def positive_frames(before_up: Bool) -> List<List<Event>>:
  match before_up:
    case True{}:
      [[Mouse{1065,584,0,True{}},Move{673,608}],
       [Mouse{673,608,0,False{}},Move{824,136}]]
    case False{}:
      [[Mouse{1065,584,0,True{}},Move{673,608},Mouse{673,608,0,False{}}],
       [Move{824,136}]]

# Same phase boundaries with Up absent: the extra empty batch deliberately
# exercises a service/view interval where the missing release should have been.
def negative_frames(before_up: Bool) -> List<List<Event>>:
  match before_up:
    case True{}:
      [[Mouse{1065,584,0,True{}},Move{673,608}],[],[Move{824,136}]]
    case False{}:
      [[Mouse{1065,584,0,True{}},Move{673,608}], [Move{824,136}]]

def edit_is(state: UI.State,want_caret: U32,want_drag: Bool) -> Bool:
  UI.State{_,UI.Input{_,scroll,UI.Edit{focus,caret,anchor,drag,viewport},command,shift},_,_} = state
  U32.is_eq(focus,2) && U32.is_eq(caret,want_caret) && U32.is_eq(anchor,490) &&
    Bool.not(Bool.xor(drag,want_drag)) && U32.is_eq(scroll,0) &&
    U32.is_eq(viewport,0) && Bool.not(command) && Bool.not(shift)

def copied(value: UI.State & UI.Action) -> String:
  (_,action) = value
  match action:
    case UI.Copy{text}: text
    case _: ""

def observed(+state: Gui.State,+caret: U32,+drag: Bool,+text: String,+label: String) -> IO(Unit):
  +current = ui(state)
  do IO<Unit>:
    require(edit_is(current,caret,drag),label ++ " exact caret anchor drag and viewport")
    require(String.eq(UI.selection(current),text),label ++ " exact canonical substring")
    require(String.eq(copied(UI.event(Mouse{824,136,0,True{}},current)),text),label ++ " actual toolbar Copy action text")
    require(String.eq(UI.reader(current),body()) && service_safe(state),label ++ " unchanged body and no external work")

def finished(state: Gui.State,missing_up: Bool,label: String) -> IO(Unit):
  match missing_up:
    case False{}: observed(state,511,False{},expected(),label)
    case True{}: observed(state,17,True{},failed(),label)

# UI-only replay is a control for the same real UI.event function; no alternate
# coordinate, wrapping, selection or clipboard implementation is used here.
def ui_next(value: UI.State & UI.Action) -> UI.State:
  (state,action) = value
  state

def ui_events(events: List<Event>,state: UI.State) -> UI.State:
  match events:
    case []: state
    case e <> rest: ui_events(rest,ui_next(UI.event(e,state)))

def fixture() -> IO(Unit):
  +current = ui(initial())
  do IO<Unit>:
    require(String.eq(UI.reader(current),body()) && U32.is_eq(UI.length(body()),1004),"exact synthetic Connections body matches the v3 source oracle")
    require(U32.is_eq(UI.reader_at(current,1065,584),490) && U32.is_eq(UI.reader_at(current,673,608),511),"native drag coordinates map to fixed independent490 and511 offsets")
    require(U32.is_eq(UI.reader_at(current,824,136),17),"Copy hover clamps to the first17-character heading when stale drag is active")
    require(String.eq(UI.span(body(),490,511),expected()) && String.eq(UI.span(body(),17,490),failed()) && U32.is_eq(UI.length(failed()),473),"positive and negative literals equal exact independently observed source intervals")
    require(service_safe(initial()),"replay starts with no worker database capture or preference work")

def ui_control() -> IO(Unit):
  do IO<Unit>:
    finished(Gui.replace_ui(initial(),ui_events(positive(),ui(initial()))),False{},"UI positive")
    finished(Gui.replace_ui(initial(),ui_events(negative(),ui(initial()))),True{},"UI missing-Up control")

def one_batch() -> IO(Unit):
  do IO<Unit>:
    +good : Gui.State <- batch(positive(),initial())
    +bad : Gui.State <- batch(negative(),initial())
    finished(good,False{},"Gui one batch positive")
    finished(bad,True{},"Gui one batch missing-Up control")

def split_case(+kind: U32,+before: Bool) -> IO(Unit):
  +label = "Gui split " ++ Bool.pick(String,before,"before-Up","after-Up") ++ " seam" ++ U32.show(kind)
  do IO<Unit>:
    good : Gui.State <- frames(positive_frames(before),initial(),kind)
    bad : Gui.State <- frames(negative_frames(before),initial(),kind)
    finished(good,False{},label ++ " positive")
    finished(bad,True{},label ++ " missing-Up control")

def split_cases() -> IO(Unit):
  do IO<Unit>:
    split_case(0,True{})
    split_case(0,False{})
    split_case(1,True{})
    split_case(1,False{})
    split_case(2,True{})
    split_case(2,False{})
    split_case(3,True{})
    split_case(3,False{})

# A separate boundary check proves the real release clears drag before hover,
# then keeps that state across service and renderer ownership transitions.
def release_boundary() -> IO(Unit):
  do IO<Unit>:
    +released : Gui.State <- batch([Mouse{1065,584,0,True{}},Move{673,608},Mouse{673,608,0,False{}}],initial())
    finished(released,False{},"release boundary before seams")
    +settled : Gui.State <- seam(released,3)
    finished(settled,False{},"release boundary after service and view")
    moved : Gui.State <- batch([Move{824,136}],settled)
    finished(moved,False{},"release boundary after hover")

def main() -> IO(Unit):
  do IO<Unit>:
    fixture()
    ui_control()
    one_batch()
    split_cases()
    release_boundary()
