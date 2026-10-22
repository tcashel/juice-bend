import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/bend_ui/region.bend as R

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def tag(action: UI.Action) -> U32:
  match action:
    case UI.Refresh{}: 0
    case UI.Pause{}: 1
    case UI.Blame{}: 2
    case UI.Why{}: 3
    case UI.Export{}: 4
    case UI.Previous{}: 5
    case UI.Next{}: 6
    case UI.Back{}: 7
    case UI.ListNext{}: 8
    case _: 99

def action(value: UI.State & UI.Action) -> U32:
  (_,next) = value
  tag(next)

def clicked(s: UI.State,x: U32,y: U32) -> U32:
  action(UI.event(Mouse{x,y,0,True{}},s))

def selected(value: UI.State & UI.Action) -> String:
  (state,_) = value
  UI.selection(state)

def original_actions(fuel: Nat,+index: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      U32.is_eq(clicked(UI.init(),U32.add(G.top_x(index),8),88),index) && original_actions(rest,U32.add(index,1))

def rect_bounds(rect: R.Rect,left: U32,right: U32) -> Bool:
  R.Rect{l,t,r,b} = rect
  U32.is_eq(l,left) && U32.is_eq(r,right) && U32.is_eq(t,80) && U32.is_eq(b,112)

def bounds(index: U32,left: U32,right: U32) -> Bool:
  rect_bounds(G.top_bounds(index),left,right)

def main() -> IO(Unit):
  +pending = UI.set_results(UI.init(),UI.LibraryUsageResults{5,0,[]})
  +attachment = UI.set_results(UI.init(),UI.AttachmentResults{2,False{},False{},True{}})
  +brief = UI.set_results(UI.init(),UI.BriefResults{0})
  +selection = UI.set_edit(UI.set_query(UI.init(),"café 中文"),UI.Edit{0,4,1,False{},0})
  do IO<Unit>:
    require(original_actions(7n,0),"all seven History toolbar action IDs retain their original pointer routes")
    require(bounds(0,8,144) && bounds(1,152,288) && bounds(2,296,408) && bounds(3,416,528),"first four button descriptors retain exact existing rectangles")
    require(bounds(4,536,680) && bounds(5,848,1016) && bounds(6,1024,1192),"export and page descriptors retain exact existing rectangles")
    require(U32.is_eq(clicked(UI.init(),679,111),4) && U32.is_eq(clicked(UI.init(),680,111),99),"export bottom-right pixel remains active and its exclusive edge remains inert")
    require(U32.is_eq(clicked(UI.init(),700,88),99) && U32.is_eq(clicked(UI.init(),847,88),99) && U32.is_eq(clicked(UI.init(),848,88),5),"capture-status gap stays inert immediately before the Previous control")
    require(U32.is_eq(clicked(pending,16,88),7) && U32.is_eq(clicked(pending,544,88),99),"pending captured page keeps Back and blocks unready Export")
    require(U32.is_eq(clicked(attachment,160,88),99) && U32.is_eq(clicked(attachment,856,88),99) && U32.is_eq(clicked(attachment,1032,88),8),"attachment export and previous remain disabled while available Next keeps its route")
    require(U32.is_eq(clicked(brief,544,88),99) && U32.is_eq(clicked(brief,856,88),99),"unused Brief toolbar slots remain inert")
    require(String.eq(selected(UI.event(Mouse{544,88,0,True{}},selection)),"afé"),"toolbar activation preserves existing Unicode text selection")
    require(Bool.not(UI.toolbar_available(UI.AttachmentResults{2,False{},False{},True{}},1)) && Bool.not(UI.toolbar_available(UI.LibraryUsageResults{5,0,[]},4)),"paint and hits share the existing disabled availability descriptor")
