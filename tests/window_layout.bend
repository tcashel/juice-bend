# Pure production-painter and input contracts. These do not prove native Dock
# avoidance; root must launch this exact candidate on the smaller desktop.
import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/font.bend as Font
import ./polish.bend as Polish
import ./tab_readability.bend as Tiles
import ./ui_attachments.bend as A
import ../src/ui_palette.bend as Palette

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def changed(value: UI.State & UI.Action) -> UI.State:
  (state,_) = value
  state

def glyph(c: UI.Canvas,x: U32,y: U32,code: U32,bg: U32) -> Bool:
  Tiles.tile.row(Tiles.tile.at(8n,c,U32.div(x,8),U32.div(y,8)),7,Font.row(Font.half(Font.glyph(code),True{}),7),bg)

def normal() -> UI.State:
  UI.set_status(UI.set_reader(UI.init(),Polish.repeat(100n,"title "),Polish.repeat(40n,"row\n") ++ "final"),Polish.repeat(100n,"diagnostic "))

def painting() -> IO(Unit):
  +canvas = UI.draw_canvas_capture(normal(),"Pause",True{})
  +settings = UI.draw_canvas_capture(UI.set_results(normal(),UI.SettingsResults{0,0,"Pause",True{}}),"Pause",False{})
  +brief = UI.draw_canvas_capture(UI.set_results(normal(),UI.BriefResults{0}),"Pause",False{})
  do IO<Unit>:
    require(U32.is_eq(G.width(),1200) && U32.is_eq(G.height(),664),"compact native content requests 1200 by 664")
    require(U32.is_eq(G.cell(),8) && U32.is_eq(G.line_pitch(),24) && U32.is_eq(G.control_height(),32),"compact layout retains text advance line spacing and control target height")
    require(A.chrome_glyph(canvas,16,432,69,0,Palette.navigation_ink(),Palette.navigation_paper()) && A.chrome_glyph(canvas,16,464,65,0,Palette.navigation_ink(),Palette.navigation_paper()) && A.chrome_glyph(canvas,104,464,65,0,Palette.navigation_ink(),Palette.navigation_paper()) && A.chrome_glyph(canvas,16,592,66,0,Palette.navigation_ink(),Palette.navigation_paper()),"production painter shows JSONL ATIF Archive and Back above the footer")
    require(glyph(settings,16,600,82,UI.rail()) && glyph(settings,16,568,82,UI.rail()),"Settings paints Rebuild and daily Refresh above footer")
    require(glyph(brief,16,312,83,UI.rail()) && Tiles.tile.empty(Tiles.tile.at(8n,brief,2,43),UI.rail()),"Brief paints Select all and leaves later navigation blank")
    require(glyph(canvas,536,600,114,UI.paper()) && Tiles.tile.empty(Tiles.tile.at(8n,canvas,67,77),UI.paper()),"nineteenth reader line paints completely with eight pixels clear before footer")
    require(A.chrome_glyph(canvas,816,120,67,0,UI.accent(),UI.paper()) && A.chrome_glyph(canvas,1104,120,83,0,UI.accent(),UI.paper()),"long reader title cannot paint over Copy or Select all")
    require(glyph(canvas,688,80,67,UI.rail()) && A.chrome_glyph(canvas,1032,80,78,0,UI.accent(),UI.panel()),"capture hint and Next button both remain fully visible")
    require(glyph(canvas,992,640,67,UI.rail()) && Tiles.tile.empty(Tiles.tile.at(8n,canvas,1,82),UI.rail()),"status detail hint and bottom padding remain inside content height")
    require(Tiles.tile.empty(Tiles.tile.at(8n,canvas,150,80),UI.paper()) && Tiles.tile.empty(Tiles.tile.at(8n,canvas,1,83),UI.paper()),"actual production painter does not extend footer beyond 1200 by 664")

def reader() -> UI.State:
  UI.set_edit(UI.set_reader(UI.init(),"Bounded viewport",Polish.repeat(40n,"row\n") ++ "final"),UI.Edit{2,3,0,False{},0})

def scrolling() -> IO(Unit):
  +origin = reader()
  +page = changed(UI.event(Key{63277,True{}},origin))
  +bottom = UI.scroll_by(page,True{},999)
  +last = changed(UI.event(Mouse{536,600,0,True{}},bottom))
  +selected = changed(UI.event(Move{576,600},last))
  +footer = changed(UI.event(Mouse{536,624,0,True{}},selected))
  +restored = changed(UI.event(Key{27,True{}},footer))
  do IO<Unit>:
    require(U32.is_eq(UI.scroll(page),17) && String.eq(UI.selection(page),"row"),"Page Down moves seventeen rows with two rows of overlap and preserves selection")
    require(U32.is_eq(UI.scroll(bottom),22) && U32.is_eq(UI.scroll(UI.scroll_by(bottom,True{},999)),22),"scroll clamps forty-one canonical lines to nineteen visible rows")
    require(U32.is_eq(UI.reader_at(bottom,536,600),160) && U32.is_eq(UI.reader_at(bottom,576,623),165),"bottom reader hit testing reaches the final canonical line without phantom rows")
    require(String.eq(UI.selection(selected),"final"),"drag on final visible row selects exact final text")
    require(U32.is_eq(UI.focus(footer),5) && U32.is_eq(UI.scroll(footer),22),"first footer pixel opens status rather than changing reader selection")
    require(String.eq(UI.selection(restored),"final") && U32.is_eq(UI.scroll(restored),22),"closing footer status preserves last-line selection and scroll")
    require(U32.is_eq(UI.scroll(changed(UI.event(Key{63276,True{}},page))),0),"Page Up returns to the exact preceding viewport")
    require(U32.is_eq(UI.scroll(changed(UI.event(Scroll{800,600,0.0,F32.sub(0.0,1.0)},origin))),3),"native wheel event still scrolls reader by three bounded lines")

def compact_brief() -> IO(Unit):
  +s = UI.set_results(UI.set_query(UI.init(),"/synthetic/repository"),UI.BriefResults{0})
  do IO<Unit>:
    Polish.click(s,16,120,11,"compact Brief Back")
    Polish.click(s,16,152,35,"compact Brief Prepare")
    Polish.click(s,16,184,36,"compact Brief Copy")
    Polish.click(s,16,216,37,"compact Brief Export")
    Polish.click(s,16,248,5,"compact Brief Paste root")
    Polish.click(s,16,280,1,"compact Brief Clear root")
    require(String.eq(UI.selection(changed(UI.event(Mouse{16,312,0,True{}},s))),"/synthetic/repository"),"compact Brief Select all covers complete root")
    Polish.click(s,16,344,0,"Brief blank rows cannot dispatch hidden History actions")
    Polish.click(s,16,600,0,"Brief bottom blank row cannot dispatch Back or Rebuild")

def main() -> IO(Unit):
  do IO<Unit>:
    painting()
    scrolling()
    compact_brief()
