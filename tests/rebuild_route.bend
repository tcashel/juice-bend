# Pointer-to-coordinator contracts. Native drawing/worker success is a separate
# root-owned acceptance gate. Worker processes here are only /usr/bin/false.
import Base
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/json.bend as Json
import ./gui_settings.bend as Fixture

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def boxed(value: Maybe<Gui.State>) -> List<&2,Gui.State>:
  match value:
    case None{}: []
    case Some{state}: [state]

def pointer(state: Gui.State,row: U32) -> IO(List<&2,Gui.State>):
  do IO<List<&2,Gui.State>>:
    next : Maybe<Gui.State> <- Gui.events([Mouse{24,U32.add(G.sidebar_y(row),8),0,True{}}],state)
    return boxed(next)

def click(states: List<&2,Gui.State>,row: U32) -> IO(List<&2,Gui.State>):
  match states:
    case [state]: pointer(state,row)
    case _: IO.die(List<&2,Gui.State>,1,"FAIL pointer route lost its single state")

def pointer_action(result: UI.State & UI.Action) -> String:
  (view,action) = result
  match action:
    case UI.Settings{}: "settings"
    case UI.Brief{}: "brief"
    case UI.Rebuild{}: "rebuild"
    case _: "other"

def actions() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.workspace_side_label(12),"Prepare brief"),
      "normal rail labels the route Prepare brief")
    require(String.eq(UI.side_label(True{},17,False{}),"Rebuild capture") &&
      String.eq(UI.side_label(True{},0,False{}),"Back to history"),
      "Settings exposes Rebuild capture and keeps its first Back control")
    require(String.eq(pointer_action(UI.event(Mouse{24,U32.add(G.sidebar_y(9),8),0,True{}},Fixture.ui(Fixture.ready()))),"brief"),
      "actual normal pointer hit emits Brief without Rebuild")
    require(String.eq(pointer_action(UI.event(Mouse{24,U32.add(G.sidebar_y(15),8),0,True{}},Fixture.ui(Fixture.panel()))),"rebuild"),
      "actual Settings pointer hit emits Rebuild")

def target_shown(states: List<&2,Gui.State>) -> Bool:
  match states:
    case [+state]:
      Gui.settings_active(state) && String.eq(Fixture.writer(state),"none") &&
      String.contains(UI.reader(Fixture.ui(state)),"Rebuild target: captured snapshot 7.") &&
      String.contains(UI.reader(Fixture.ui(state)),"only its derived rows; retained raw remains unchanged")
    case _: False{}

def existing_fields(states: List<&2,Gui.State>) -> Bool:
  match states:
    case [state]:
      +body = UI.reader(Fixture.ui(state))
      String.contains(body,"Automatic refresh:") && String.contains(body,"Provider for new paths:") &&
      String.contains(body,"No registered folder selected.") && String.contains(body,"Add folder registers it") &&
      String.contains(body,"Enable / Disable") && String.contains(body,"Refresh checks a bounded batch") &&
      String.contains(body,"No private folders") && String.contains(body,"Choose an interval") &&
      String.contains(body,"Last operation") && String.contains(body,"Data directory:") &&
      String.contains(body,"Back restores the exact prior reader and selection")
    case _: False{}

def pending(value: Maybe<&2,Gui.Pending>) -> String:
  match value:
    case None{}: "none"
    case Some{Gui.Pending{ticket,Gui.Request{kind,args,snapshot,start,title},channel}}:
      U32.show(kind) ++ "|" ++ String.join(args,"|") ++ "|" ++ snapshot ++ "|" ++ U32.show(start)

def writer(states: List<&2,Gui.State>) -> String:
  match states:
    case [state]: pending(Gui.writer_of(state))
    case _: "invalid-state-box"

def status(states: List<&2,Gui.State>) -> String:
  match states:
    case [state]: UI.status_text(Fixture.ui(state))
    case _: "invalid-state-box"

def observation(states: List<&2,Gui.State>) -> String:
  match states:
    case [state]: Fixture.observation(state)
    case _: "invalid-state-box"

def original() -> String:
  Fixture.observation(Fixture.ready())

def no_target(+state: Gui.State) -> Gui.State:
  Gui.State{db,dir,program,ui,Gui.Selection{items,snapshot,start,kind,args,filters,listing},form,jobs,deadline,serial} = state
  Gui.State{db,dir,program,ui,Gui.Selection{items,"",start,kind,args,filters,listing},form,jobs,deadline,serial}

def no_target_shown(states: List<&2,Gui.State>) -> Bool:
  match states:
    case [state]: String.contains(UI.reader(Fixture.ui(state)),"No captured snapshot selected. Choose a captured transcript first.")
    case _: False{}

def route() -> IO(Unit):
  do IO<Unit>:
    +opened : List<&2,Gui.State> <- click([Fixture.ready()],3)
    require(target_shown(opened),"Index settings pointer route shows exact target and starts no writer")
    require(existing_fields(opened),"Rebuild target notice preserves every existing Settings field group")
    +started : List<&2,Gui.State> <- click(opened,15)
    require(String.eq(writer(started),"16|rebuild|7|7|0"),
      "Settings Rebuild pointer dispatch queues the exact immutable selected snapshot")
    +back : List<&2,Gui.State> <- click(started,0)
    require(String.eq(observation(back),original()),
      "Back after starting Rebuild restores exact original reader selection scope and listing")
    require(String.eq(writer(back),"16|rebuild|7|7|0"),
      "Back keeps the already-started captured-snapshot writer")

def missing() -> IO(Unit):
  do IO<Unit>:
    +opened : List<&2,Gui.State> <- click([no_target(Fixture.ready())],3)
    require(no_target_shown(opened),"Settings without a captured snapshot explains how to select its target")
    +refused : List<&2,Gui.State> <- click(opened,15)
    require(String.eq(writer(refused),"none") && String.contains(status(refused),"Select a captured transcript"),
      "actual Rebuild pointer route refuses an empty target without starting work")

def busy_origin() -> IO(List<&2,Gui.State>):
  do IO<List<&2,Gui.State>>:
    state : Gui.State <- Gui.start_write(Fixture.panel(),Gui.Request{8,["refresh-all"],"",0,"Existing capture"},None{})
    return [state]

def busy() -> IO(Unit):
  do IO<Unit>:
    +started : List<&2,Gui.State> <- busy_origin()
    require(String.eq(writer(started),"8|refresh-all||0"),"busy fixture owns one existing capture writer")
    +refused : List<&2,Gui.State> <- click(started,15)
    require(String.eq(writer(refused),"8|refresh-all||0") && String.contains(status(refused),"already running"),
      "Rebuild pointer route preserves a busy writer and reports refusal")
    +back : List<&2,Gui.State> <- click(refused,0)
    require(String.eq(observation(back),original()),"Back after busy refusal restores the complete saved origin")

def completed(states: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match states:
    case [state]:
      [Gui.write_done(Gui.clear_writer(state),Gui.Request{16,["rebuild","7"],"7",0,"Snapshot 7"},
        Gui.Reply{Done{Json.JObject{[Json.JField{"snapshot",Json.JString{"7"}},
          Json.JField{"verification",Json.JString{"complete_accepted_extent"}},
          Json.JField{"raw_bytes_unchanged",Json.JBool{True{}}}]}}})]
    case _: []

def completion() -> IO(Unit):
  do IO<Unit>:
    opened : List<&2,Gui.State> <- click([Fixture.ready()],3)
    started : List<&2,Gui.State> <- click(opened,15)
    +done : List<&2,Gui.State> <- IO.pure(List<&2,Gui.State>,completed(started))
    require(String.eq(writer(done),"none") && String.contains(status(done),"Verified search rows rebuilt for Snapshot 7"),
      "existing successful rebuild reply reports its exact snapshot without a remaining writer")
    +back : List<&2,Gui.State> <- click(done,0)
    require(String.eq(observation(back),original()),"Back after successful rebuild reply restores the exact captured reader")

def main() -> IO(Unit):
  do IO<Unit>:
    actions()
    route()
    missing()
    busy()
    completion()
