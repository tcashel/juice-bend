import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def kind(action: UI.Action) -> U32:
  match action:
    case UI.NoAction{}: 0
    case UI.Settings{}: 1
    case UI.Refresh{}: 2
    case UI.QuotaEnable{}: 3
    case UI.QuotaDisconnect{}: 4
    case UI.QuotaHistory{}: 5
    case UI.QuotaSetup{}: 6
    case UI.QuotaCopySetup{}: 7
    case UI.Connections{}: 8
    case UI.Storage{}: 9
    case UI.ListPrevious{}: 10
    case UI.ListNext{}: 11
    case UI.Copy{_}: 12
    case UI.Scope{_}: 13
    case UI.Back{}: 14
    case _: 99

def action(result: UI.State & UI.Action) -> U32:
  (_,value) = result
  kind(value)

def state(result: UI.State & UI.Action) -> UI.State:
  (value,_) = result
  value

def click(s: UI.State,x: U32,y: U32,expected: U32,label: String) -> IO(Unit):
  require(U32.is_eq(action(UI.event(Mouse{x,y,0,True{}},s)),expected),label)

def content() -> UI.State:
  UI.set_edit(UI.set_reader(UI.set_query(UI.init(),"/tmp/juice-bend-quota café 中文 🙂"),
    "Local quota observations","A🙂B\t café\nCanonical local observation"),UI.Edit{2,4,1,False{},0})

def panel(phase: U32,loaded: Bool,enabled: Bool,view: U32,offset: U32,count: U32,more: Bool) -> UI.State:
  UI.set_results(content(),UI.QuotaResults{phase,loaded,enabled,view,offset,count,more})

def off() -> UI.State:
  panel(2,True{},False{},0,0,0,False{})

def on(view: U32) -> UI.State:
  panel(2,True{},True{},view,0,1,False{})

def controls() -> IO(Unit):
  do IO<Unit>:
    click(UI.set_results(content(),UI.SettingsResults{0,1,"Pause",True{}}),16,312,8,"Settings row6 opens Connections")
    click(content(),16,472,9,"normal History Storage action remains available")
    click(content(),16,184,13,"ordinary provider controls remain unchanged")
    click(off(),16,112,1,"Connections sidebar Back returns to Settings")
    click(off(),16,152,2,"Connections refresh reads local observations")
    click(off(),16,184,3,"acknowledged off state offers Enable")
    click(off(),16,216,0,"off state cannot Disconnect")
    click(off(),16,248,5,"acknowledged off state can inspect retained history")
    click(off(),16,280,0,"off state cannot prepare an active callback setup")
    click(off(),16,312,0,"off state cannot copy callback setup")
    click(on(0),16,184,0,"enabled state cannot re-enable by accidental click")
    click(on(0),16,216,4,"enabled state offers explicit Disconnect")
    click(on(0),16,280,6,"enabled state offers manual setup")
    click(on(0),16,312,0,"Copy setup requires the reviewed setup view")
    click(on(2),16,312,7,"reviewed enabled setup exposes Copy setup")
    click(on(2),16,344,0,"unused sidebar row7 is inert")
    click(on(2),16,472,0,"Connections never exposes normal Storage through its empty rows")
    click(on(2),16,600,0,"Connections final sidebar row cannot trigger old Back action")
    click(on(2),16,72,0,"padding above Connections header is inert")
    click(on(2),16,632,0,"Connections sidebar bottom padding is inert")

def blocked_controls(+s: UI.State) -> Bool:
  U32.is_eq(action(UI.event(Mouse{16,184,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{16,216,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{16,248,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{16,280,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{16,312,0,True{}},s)),0)

def phases() -> IO(Unit):
  do IO<Unit>:
    require(blocked_controls(panel(0,False{},False{},0,0,0,False{})),"unloaded state cannot mutate or present sampled history")
    require(blocked_controls(panel(1,True{},True{},2,0,0,False{})),"pending request disables mutation history setup and copy together")
    require(blocked_controls(panel(3,True{},True{},2,0,0,False{})),"error state requires Refresh before trusting retained acknowledgment")
    require(blocked_controls(panel(2,False{},True{},2,0,0,False{})),"phase2 alone cannot authorize controls without loaded state")
    click(panel(0,False{},False{},0,0,0,False{}),16,152,2,"unloaded state permits explicit Refresh")
    click(panel(1,True{},True{},2,0,0,False{}),16,152,0,"pending Refresh cannot start a duplicate request")
    click(panel(3,True{},True{},2,0,0,False{}),16,152,2,"failed request permits explicit retry")
    click(panel(1,True{},True{},2,0,0,False{}),16,112,1,"Back remains available during pending work")
    click(panel(99,True{},True{},2,0,0,False{}),16,152,0,"unknown presentation phase is not treated as acknowledged")

def header() -> IO(Unit):
  do IO<Unit>:
    click(off(),16,88,2,"header Refresh local matches sidebar")
    click(off(),168,88,3,"header Enable matches acknowledged off state")
    click(off(),312,88,0,"header Disconnect is inert while off")
    click(off(),432,88,5,"header History is reachable")
    click(off(),552,88,0,"header setup is inert while off")
    click(on(2),168,88,0,"header cannot accidentally re-enable")
    click(on(2),312,88,4,"header Disconnect remains reachable")
    click(on(2),552,88,6,"header Manual setup remains reachable")
    click(on(2),744,88,0,"capture hint between setup and paging is inert")
    click(on(2),864,88,0,"manual setup cannot page unrelated transcript")
    click(on(2),1040,88,0,"manual setup cannot advance unrelated transcript")
    click(panel(1,True{},True{},1,40,40,True{}),432,88,0,"pending header History is inert")

def pagination() -> IO(Unit):
  +history = panel(2,True{},True{},1,40,40,True{})
  do IO<Unit>:
    click(history,864,88,10,"history header Previous dispatches observation paging")
    click(history,1040,88,11,"history header Next dispatches observation paging")
    click(history,200,600,10,"history list Previous shares the header gate")
    click(history,400,600,11,"history list Next shares the header gate")
    click(panel(2,True{},False{},1,0,40,True{}),200,600,0,"first retained-history page has no previous page")
    click(panel(2,True{},False{},1,0,40,True{}),400,600,11,"disconnected state may browse retained observations")
    click(panel(2,True{},True{},1,40,12,False{}),400,600,0,"last history page disables Next")
    click(panel(2,True{},True{},1,32760,40,True{}),400,600,0,"history page bound prevents overflowing the backend offset limit")
    click(panel(1,True{},True{},1,40,40,True{}),400,600,0,"pending history cannot page")
    click(panel(3,True{},True{},1,40,40,True{}),200,600,0,"failed history cannot reuse stale previous control")

def labels(fuel: Nat,+index: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+n:
      U32.is_le(UI.length(UI.quota_side_label(index)),18) &&
        U32.is_le(UI.length(UI.quota_top_label(index)),U32.sub(U32.div(G.top_width(index),8),2)) && labels(n,U32.inc(index))

def presentation() -> IO(Unit):
  +disabled = {UI.QuotaResults{1,True{},True{},2,0,0,False{}} : UI.Results}
  +enabled = {UI.QuotaResults{2,True{},True{},2,0,0,False{}} : UI.Results}
  do IO<Unit>:
    require(String.eq(UI.query_label(on(0)),"Selected Juice Bend data directory") &&
      String.eq(UI.list_heading(enabled,False{}),"Local observations"),"Connections labels distinguish selected app storage from provider accounts")
    require(labels(7n,0),"all Connections labels fit their unchanged compact hit rectangles")
    require(U32.is_eq(UI.quota_side_color(disabled,6),UI.muted()) &&
      U32.is_eq(UI.quota_top_color(disabled,2),UI.muted()),"pending setup copy and disconnect are visibly muted")
    require(U32.is_eq(UI.quota_side_color(enabled,6),UI.ink()) &&
      U32.is_eq(UI.quota_top_color(enabled,2),UI.accent()),"acknowledged enabled controls retain active paint")
    require(String.eq(UI.result_label(UI.QuotaResults{3,True{},True{},2,0,0,False{}}),"Refresh to verify local state"),"error presentation never claims collection is currently enabled")
    require(String.eq(UI.reader(state(UI.event(Mouse{16,312,0,True{}},on(2)))),UI.reader(content())) &&
      String.eq(UI.query(state(UI.event(Mouse{16,312,0,True{}},on(2)))),UI.query(content())),"quota actions preserve canonical reader and exact Unicode data-root text")
    require(String.eq(UI.selection(on(2)),"🙂B\t") &&
      String.eq(UI.selection(state(UI.event(Mouse{16,312,0,True{}},on(2)))),"🙂B\t"),"setup action preserves canonical Unicode and tab selection")
    click(on(2),824,136,12,"reader Copy selection remains available separately from Copy setup")
    require(U32.is_eq(G.width(),1200) && U32.is_eq(G.height(),664),"Connections keeps the accepted compact native window size")

def main() -> IO(Unit):
  do IO<Unit>:
    controls()
    phases()
    header()
    pagination()
    presentation()
