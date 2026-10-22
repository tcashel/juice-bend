import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/font.bend as Font
import ../src/bend_ui/canvas.bend as C
import ../src/bend_ui/label.bend as Label
import ./polish.bend as Existing

def require(ok: Bool,label: String) -> IO(Unit):
  Existing.require(ok,label)

def action(value: UI.State & UI.Action) -> U32:
  (_,next) = value
  Existing.kind(next)

def clicked(s: UI.State,x: U32,y: U32) -> U32:
  action(UI.event(Mouse{x,y,0,True{}},s))

def choose(right: Bool,bottom: Bool,tl: C.Canvas,tr: C.Canvas,bl: C.Canvas,br: C.Canvas) -> C.Canvas:
  match right bottom:
    case False{} False{}: tl
    case True{} False{}: tr
    case False{} True{}: bl
    case True{} True{}: br

def pixel(fuel: Nat,c: C.Canvas,+x: U32,+y: U32) -> U32:
  match fuel c:
    case _ C.Flat{color}: color
    case _ C.Tile{bits,fg,bg}: C.blend(fg,bg,Font.coverage(bits,U32.mod(x,8),U32.mod(y,8)))
    case 0n _: 0
    case 1n+ +rest C.Four{tl,tr,bl,br}:
      +half = U32.shln(8,rest)
      pixel(rest,choose(U32.is_ge(x,half),U32.is_ge(y,half),tl,tr,bl,br),U32.mod(x,half),U32.mod(y,half))

def same_row(fuel: Nat,+a: C.Canvas,+b: C.Canvas,+x: U32,+y: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      U32.is_eq(pixel(8n,a,x,y),pixel(8n,b,x,y)) && same_row(rest,a,b,U32.inc(x),y)

def same_hint(fuel: Nat,+a: C.Canvas,+b: C.Canvas,+y: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest: same_row(152n,a,b,688,y) && same_hint(rest,a,b,U32.inc(y))

def painted(+s: UI.State,+suspended: Bool) -> Bool:
  +actual = UI.draw_canvas_capture(s,"Pause",suspended)
  +hint = UI.draw_capture_context(UI.is_quota(s),C.Flat{UI.rail()},suspended)
  U32.is_eq(pixel(8n,actual,536,111),UI.panel()) &&
    U32.is_eq(pixel(8n,actual,679,111),UI.panel()) &&
    U32.is_eq(pixel(8n,actual,680,111),UI.rail()) &&
    U32.is_eq(pixel(8n,actual,687,111),UI.rail()) &&
    U32.is_eq(pixel(8n,actual,840,111),UI.rail()) &&
    U32.is_eq(pixel(8n,actual,847,111),UI.rail()) &&
    U32.is_eq(pixel(8n,actual,848,111),UI.panel()) &&
    same_hint(32n,actual,hint,80)

def target(+s: UI.State,+expected: U32) -> Bool:
  U32.is_eq(clicked(s,536,80),expected) &&
    U32.is_eq(clicked(s,552,88),expected) &&
    U32.is_eq(clicked(s,679,111),expected) &&
    U32.is_eq(clicked(s,535,88),0) &&
    U32.is_eq(clicked(s,680,88),0) &&
    U32.is_eq(clicked(s,687,88),0) &&
    U32.is_eq(clicked(s,688,88),0) &&
    U32.is_eq(clicked(s,744,88),0) &&
    U32.is_eq(clicked(s,839,111),0) &&
    U32.is_eq(clicked(s,840,88),0) &&
    U32.is_eq(clicked(s,847,88),0) &&
    U32.is_eq(clicked(s,552,79),0)

def mode(+s: UI.State,expected: U32,+name: String) -> IO(Unit):
  do IO<Unit>:
    require(target(s,expected),name ++ ": exact slot4 target and inert status/gaps")
    require(painted(s,False{}),name ++ ": actual painter preserves target edges and idle hint")
    require(painted(s,True{}),name ++ ": actual painter preserves target edges and suspended hint")

def normal() -> UI.State:
  UI.set_results(UI.init(),UI.Results{0,1,False{},True{}})

def state(results: UI.Results) -> UI.State:
  UI.set_results(normal(),results)

def labels() -> IO(Unit):
  do IO<Unit>:
    require(U32.is_eq(G.top_x(4),536) && U32.is_eq(G.top_width(4),144) && U32.is_eq(G.capture_hint_x(),688),"slot4 has explicit144px width and an8px margin before status")
    require(U32.is_le(Label.measured(128n,0,UI.top_label(4,False{},False{},False{},"Pause"),0,128),128),"captured-page export label fits without ellipsis")
    require(U32.is_le(Label.measured(128n,0,UI.top_label(4,True{},False{},False{},"Pause"),0,128),128),"file export evidence label fits without ellipsis")
    require(U32.is_le(Label.measured(128n,0,UI.top_label(4,False{},False{},True{},"Pause"),0,128),128),"whole-session export evidence label fits without ellipsis")
    require(U32.is_le(Label.measured(128n,0,UI.top_label(4,False{},True{},False{},"Pause"),0,128),128),"Settings Enable selected fits without ellipsis")
    require(U32.is_le(Label.measured(128n,0,UI.library_top_label(True{},4),0,128),128),"retained Usage capture export label fits without ellipsis")
    require(U32.is_le(Label.measured(128n,0,UI.library_top_label(False{},4),0,128),128),"Library Usage provider label fits without ellipsis")
    require(U32.is_le(UI.length(UI.quota_top_label(4)),16) && U32.is_le(UI.length(UI.attachment_top_label(4)),16) && U32.is_le(UI.length(UI.folder_side_label(4)),16),"monospace quota attachment and folder labels fit16cells")
    require(String.eq(UI.brief_top_label(4),""),"brief keeps its unused slot4 empty")

def main() -> IO(Unit):
  do IO<Unit>:
    labels()
    mode(normal(),6,"History")
    mode(UI.set_files(normal(),True{}),6,"Files")
    mode(UI.set_reader(normal(),"Usage | whole captured session","retained evidence"),6,"Whole-session Usage")
    mode(state(UI.SettingsResults{0,1,"Pause",True{}}),22,"Settings")
    mode(state(UI.BriefResults{2}),0,"Brief")
    mode(state(UI.QuotaResults{2,True{},True{},0,0,1,False{}}),45,"Local quota")
    mode(state(UI.AttachmentResults{2,True{},True{},True{}}),51,"Attachments")
    mode(state(UI.AttachmentCaptureResults{2,True{},True{},True{},True{},True{}}),51,"Retained attachment capture")
    mode(state(UI.AttachmentFoldersResults{2,True{},True{},True{},True{},True{}}),55,"Attachment folders")
    mode(state(UI.LibraryUsageResults{2,1}),3,"Library Usage overview")
    mode(state(UI.LibraryUsageResults{6,1}),6,"Library Usage retained capture")
    mode(state(UI.LibraryUsageResults{5,1}),0,"Library Usage pending capture")
