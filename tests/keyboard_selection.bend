import Base
import ../src/ui.bend as UI

def require(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def sample() -> String:
  "A🙂é中BC\nZ"

def seed(focus: U32,caret: U32,anchor: U32,shift: Bool) -> UI.State:
  UI.set_modifiers(UI.set_edit(UI.set_position(
    UI.set_reader(UI.set_query(UI.init(),sample()),"Synthetic selection",sample()),3,7),
    UI.Edit{focus,caret,anchor,False{},0}),False{},shift)

def changed(result: UI.State & UI.Action) -> UI.State:
  (state,action) = result
  state

def event(state: UI.State,code: U32,down: Bool) -> UI.State:
  changed(UI.event(Key{code,down},state))

def arrow(state: UI.State,right: Bool) -> UI.State:
  event(state,Bool.pick(U32,right,63235,63234),True{})

def at(state: UI.State,focus: U32,caret: U32,anchor: U32) -> Bool:
  UI.State{content,UI.Input{selected,scroll,UI.Edit{f,c,a,drag,viewport},command,shift},image,dirty} = state
  U32.is_eq(f,focus) && U32.is_eq(c,caret) && U32.is_eq(a,anchor)

def command_all(state: UI.State) -> UI.State:
  event(event(event(state,65591,True{}),97,True{}),65591,False{})

def steps(n: Nat,state: UI.State,+right: Bool) -> UI.State:
  match n:
    case 0n: state
    case 1n+rest: steps(rest,arrow(state,right),right)

def copied(result: UI.State & UI.Action) -> String:
  (state,action) = result
  match action:
    case UI.Copy{text}: text
    case _: ""

def collapses(+focus: U32,+name: String) -> IO(Unit):
  +forward = seed(focus,6,2,False{})
  +reverse = seed(focus,2,6,False{})
  +left = arrow(forward,False{})
  +right = arrow(forward,True{})
  do IO<Unit>:
    require(at(left,focus,2,2),name ++ " plain Left collapses to lower edge without an extra step")
    require(at(right,focus,6,6),name ++ " plain Right collapses to upper edge without an extra step")
    require(at(arrow(reverse,False{}),focus,2,2),name ++ " reversed selection Left reaches lower edge")
    require(at(arrow(reverse,True{}),focus,6,6),name ++ " reversed selection Right reaches upper edge")
    require(at(arrow(left,False{}),focus,1,1) && at(arrow(right,True{}),focus,7,7),name ++ " next plain arrow takes exactly one scalar step")
    require(String.eq(UI.query(left),sample()) && String.eq(UI.reader(left),sample()) &&
      U32.is_eq(UI.selected(left),3) && U32.is_eq(UI.scroll(left),7),name ++ " collapse preserves text and list/reader position")

def extensions(+focus: U32,+name: String) -> IO(Unit):
  +forward = seed(focus,6,2,True{})
  +reverse = seed(focus,2,6,True{})
  +empty = seed(focus,4,4,True{})
  do IO<Unit>:
    require(at(arrow(forward,False{}),focus,5,2),name ++ " Shift-Left contracts forward selection from active caret")
    require(at(arrow(forward,True{}),focus,7,2),name ++ " Shift-Right extends forward selection from active caret")
    require(at(arrow(reverse,False{}),focus,1,6),name ++ " Shift-Left extends reversed selection from active caret")
    require(at(arrow(reverse,True{}),focus,3,6),name ++ " Shift-Right contracts reversed selection from active caret")
    require(at(arrow(empty,False{}),focus,3,4) && at(arrow(empty,True{}),focus,5,4),name ++ " shifted arrow creates selection from collapsed caret")
    require(String.eq(UI.selection(arrow(seed(focus,1,1,True{}),True{})),"🙂"),name ++ " shifted arrow selects one Unicode scalar")

def boundaries(+focus: U32,+name: String) -> IO(Unit):
  +empty = UI.set_edit(UI.set_reader(UI.set_query(UI.init(),""),"Empty",""),UI.Edit{focus,0,0,False{},0})
  do IO<Unit>:
    require(at(arrow(seed(focus,0,0,False{}),False{}),focus,0,0),name ++ " plain Left stays at start")
    require(at(arrow(seed(focus,8,8,False{}),True{}),focus,8,8),name ++ " plain Right stays at end")
    require(at(arrow(seed(focus,0,6,True{}),False{}),focus,0,6),name ++ " Shift-Left preserves anchor at start")
    require(at(arrow(seed(focus,8,2,True{}),True{}),focus,8,2),name ++ " Shift-Right preserves anchor at end")
    require(at(arrow(empty,False{}),focus,0,0) && at(arrow(empty,True{}),focus,0,0),name ++ " empty text arrows stay at zero")
    require(at(arrow(UI.set_modifiers(empty,False{},True{}),False{}),focus,0,0) &&
      at(arrow(UI.set_modifiers(empty,False{},True{}),True{}),focus,0,0),name ++ " empty text shifted arrows stay at zero")

def command_sequence(+focus: U32,+name: String) -> IO(Unit):
  +all = command_all(seed(focus,3,3,False{}))
  +left = arrow(all,False{})
  +right = arrow(all,True{})
  +partial = event(steps(4n,event(left,65592,True{}),True{}),65592,False{})
  +copy_ready = event(partial,65591,True{})
  do IO<Unit>:
    require(at(all,focus,8,0),name ++ " physical Command-A selects complete scalar range")
    require(at(left,focus,0,0) && at(right,focus,8,8),name ++ " Command-A then plain arrow collapses to matching document edge")
    require(at(partial,focus,4,0) && String.eq(UI.selection(partial),"A🙂é中"),name ++ " Command-A Left Shift-Right selects the leading scalars")
    require(String.eq(copied(UI.event(Key{99,True{}},copy_ready)),"A🙂é中"),name ++ " Command-C after keyboard selection emits exact Unicode prefix")

def query_insert() -> IO(Unit):
  +all = command_all(seed(0,3,3,False{}))
  do IO<Unit>:
    require(String.eq(UI.query(UI.insert(arrow(all,False{}),"!")),"!" ++ sample()),"query insertion after collapse Left prepends without replacing prior text")
    require(String.eq(UI.query(UI.insert(arrow(all,True{}),"!")),sample() ++ "!"),"query insertion after collapse Right appends without replacing prior text")

def main() -> IO(Unit):
  do IO<Unit>:
    collapses(0,"query")
    collapses(2,"reader")
    extensions(0,"query")
    extensions(2,"reader")
    boundaries(0,"query")
    boundaries(2,"reader")
    command_sequence(0,"query")
    command_sequence(2,"reader")
    query_insert()
