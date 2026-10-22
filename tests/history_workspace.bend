import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/ui_palette.bend as Palette
import ../src/ui_chrome.bend as Chrome
import ../src/sans_font.bend as Sans
import ../src/font.bend as Mono
import ./keyboard_selection.bend as Keyboard
import ./reader_polish.bend as Reader
import ./tab_readability.bend as Tiles
import ./ui_attachments.bend as Attachments

def require(+ok: Bool,+label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def action(+value: UI.Action) -> U32:
  match value:
    case UI.NoAction{}: 0
    case UI.Files{}: 1
    case UI.Usage{}: 2
    case UI.Settings{}: 3
    case UI.Tools{}: 4
    case UI.Related{}: 5
    case UI.Versions{}: 6
    case UI.OpenLatest{}: 7
    case UI.Brief{}: 8
    case UI.WholeExport{}: 9
    case UI.AtifExport{}: 10
    case UI.ContainerExport{}: 11
    case UI.Storage{}: 12
    case UI.Filter{}: 13
    case UI.Back{}: 14
    case UI.Scope{"all"}: 15
    case UI.Scope{"claude"}: 16
    case UI.Scope{"codex"}: 17
    case UI.AttachmentCapture{}: 18
    case UI.AttachmentFolderUse{}: 19
    case UI.Open{0}: 20
    case UI.Paste{}: 21
    case UI.Search{}: 22
    case _: 99

def action_result(result: UI.State & UI.Action) -> U32:
  (_,next) = result
  action(next)

def clicked(+s: UI.State,+x: U32,+y: U32) -> U32:
  action_result(UI.event(Mouse{x,y,0,True{}},s))

def sample() -> UI.State:
  UI.set_edit(UI.set_results(UI.set_rows(UI.set_reader(UI.set_query(UI.init(),"cache"),
    "claude | snapshot 9007199254740993 | gen 7 | /synthetic/atlas",
    "Captured page · 2 events · snapshot 7\n\n[user] · [r0:e0]\nReview the cache invalidation path.\nKeep the captured evidence available.\n\n[assistant] · [r1:e0]\nThe cache key needs the repository revision.\nA🙂B\t café 中文\n\nPage details & exact references\nCaptured repository: /synthetic/atlas\nCoverage: complete\n"),
    ["claude  Review the cache invalidation path","codex  Add a bounded transcript reader","claude  Check the export behavior"]),UI.Results{0,3,False{},True{}}),UI.Edit{2,3,1,False{},0})

def navigation() -> IO(Unit):
  +s = sample()
  +focused = Keyboard.changed(UI.event(Mouse{16,120,0,True{}},s))
  +files = UI.set_files(s,True{})
  do IO<Unit>:
    require(U32.is_eq(clicked(s,16,120),0) && U32.is_eq(UI.focus(focused),1) && String.eq(UI.reader(focused),UI.reader(s)) && String.eq(UI.selection(focused),UI.selection(s)),"History focuses the existing list without losing accepted text or selection")
    require(U32.is_eq(clicked(s,16,152),1) && U32.is_eq(clicked(s,16,184),2) && U32.is_eq(clicked(s,16,216),3),"History destinations reach repository files, selected-session Usage and Settings")
    require(U32.is_eq(clicked(files,16,120),1) && U32.is_eq(clicked(files,16,152),0),"History exits Files through its existing bookmark route; active Files does not toggle away")
    require(U32.is_eq(clicked(UI.set_reader(s,"Usage | whole captured session","retained"),16,120),14),"History exits recorded Usage through its existing Back route")
    require(U32.is_eq(clicked(UI.set_results(s,UI.RelatedResults{1,2,False{},False{}}),16,120),14),"History leaves Related through its existing origin-preserving Back handler")
    require(U32.is_eq(clicked(s,16,248),0) && U32.is_eq(clicked(s,16,504),0),"section headings are visibly non-controls and dispatch nothing")
    require(U32.is_eq(clicked(s,16,280),4) && U32.is_eq(clicked(s,16,312),5) && U32.is_eq(clicked(s,16,344),6) && U32.is_eq(clicked(s,16,376),7),"Tools, Related, Versions and Open latest remain reachable in capture group")
    require(U32.is_eq(clicked(s,16,408),8) && U32.is_eq(clicked(s,16,440),9),"Brief and full JSONL export retain their coordinator actions")
    require(U32.is_eq(clicked(s,8,464),10) && U32.is_eq(clicked(s,87,495),10) && U32.is_eq(clicked(s,96,464),11) && U32.is_eq(clicked(s,167,495),11),"split ATIF and Archive actions share the new painted bounds")
    require(U32.is_eq(clicked(s,88,472),0) && U32.is_eq(clicked(s,95,472),0),"the export gap cannot choose either format")
    require(U32.is_eq(clicked(s,16,536),12) && U32.is_eq(clicked(s,16,568),13) && U32.is_eq(clicked(s,16,600),14),"Storage, filter help and Back remain reachable above the footer")
    require(U32.is_eq(clicked(s,192,152),15) && U32.is_eq(clicked(s,287,175),15) && U32.is_eq(clicked(s,296,152),16) && U32.is_eq(clicked(s,391,175),16) && U32.is_eq(clicked(s,400,152),17) && U32.is_eq(clicked(s,495,175),17),"all source chips dispatch their original provider scope actions at both bounds")
    require(U32.is_eq(clicked(s,288,160),0) && U32.is_eq(clicked(s,392,160),0) && U32.is_eq(clicked(s,496,160),0),"provider chip gutters are inert")
    require(U32.is_eq(clicked(s,200,176),0) && U32.is_eq(clicked(s,200,184),20),"provider controls stop before the unchanged first session target")
    require(U32.is_eq(clicked(s,920,128),21) && U32.is_eq(clicked(s,1016,128),22),"explicit Paste query and Clear query retain their accepted targets")
    require(String.eq(UI.scope(Keyboard.changed(UI.event(Mouse{304,160,0,True{}},s))),"claude") && String.eq(UI.reader(s),UI.reader(Keyboard.changed(UI.event(Mouse{304,160,0,True{}},s)))),"scope chip changes scope without mutating canonical transcript")

def card_is(value: UI.Card,first: String,second: String) -> Bool:
  UI.Card{title,detail} = value
  String.eq(title,first) && String.eq(detail,second)

def session_card_scope() -> IO(Unit):
  +files = UI.draw_canvas_capture(UI.set_files(UI.set_rows(sample(),["claude  notes"]),True{}),"Pause",False{})
  do IO<Unit>:
    require(card_is(UI.display_card("claude  Review the cache",True{}),"Review the cache","Claude"),"session cards split only the application-generated provider prefix")
    require(card_is(UI.display_card("claude  notes",False{}),"claude  notes","") && card_is(UI.display_card("codex  settings",False{}),"codex  settings",""),"repository and other non-session labels retain provider-like literal prefixes")
    require(Attachments.chrome_glyph(files,200,184,99,1,UI.ink(),UI.selected_bg()),"production Files painter retains the literal initial c of a provider-like filename")

def special_contexts() -> IO(Unit):
  +s = sample()
  +attachments = UI.set_results(s,UI.AttachmentCaptureResults{2,True{},False{},False{},True{},True{}})
  +folders = UI.set_results(s,UI.AttachmentFoldersResults{2,True{},True{},True{},False{},False{}})
  +settings = UI.set_results(s,UI.SettingsResults{0,1,"Pause",True{}})
  do IO<Unit>:
    require(U32.is_eq(UI.sidebar_index(attachments,320),6) && U32.is_eq(clicked(attachments,16,320),18),"specialized attachment Capture keeps its original visual row and gate")
    require(U32.is_eq(UI.sidebar_index(folders,288),5),"specialized folder Reload keeps its original visual row")
    require(Bool.not(UI.provider_chips_visible(attachments)) && Bool.not(UI.provider_chips_visible(folders)) && Bool.not(UI.provider_chips_visible(settings)) && Bool.not(UI.provider_chips_visible(UI.set_files(s,True{}))),"provider chips do not reinterpret specialized or repository controls")
    require(U32.is_eq(G.reader_x(),536) && U32.is_eq(G.reader_y(),168) && U32.is_eq(G.reader_columns(),80) && U32.is_eq(G.reader_rows(),19) && U32.is_eq(G.line_pitch(),24),"reader geometry and exact scalar-to-pointer contract are unchanged")

def runs_size(+runs: List<&2,Chrome.Placed>) -> U32:
  U32.from_nat(List.length(&2,Chrome.Placed,runs))

def sans_check0() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  U32.is_eq(Sans.advance(a),10) && U32.is_eq(Sans.row_word(a,0,5),12525568) && U32.is_eq(Sans.row_word(bold,0,5),117391360)

def sans_check1() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  U32.is_eq(Sans.advance(large),16) && U32.is_eq(Sans.row_word(large,0,8),4279238656) && U32.is_eq(Sans.row_word(large,1,8),239)

def sans_check2() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  U32.is_eq(Chrome.measured(128n,0,"History",0,200),46) && U32.is_eq(Chrome.measured(128n,1,"History",0,200),50) && U32.is_eq(Chrome.measured(128n,2,"History",0,200),77)

def sans_check3() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  U32.is_eq(runs_size(Chrome.layout(128n,0,"A ",0,14)),2) && U32.is_eq(runs_size(Chrome.layout(128n,0,"A",0,10)),1) && U32.is_eq(runs_size(Chrome.layout(128n,0,"A",0,0)),0)

def sans_check4() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  U32.is_eq(Mono.row(tile0,5),12525568) && U32.is_eq(Mono.row(tile1,5),0)

def sans_check5() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  String.eq(Palette.heading("claude | snapshot 9007199254740993 | gen 7"),"Claude transcript") && String.eq(Palette.heading("codex | snapshot 1"),"Codex transcript")

def sans_check6() -> Bool:
  +a = Sans.glyph(0,65)
  +bold = Sans.glyph(1,65)
  +large = Sans.glyph(2,65)
  +runs = Chrome.layout(128n,0,"A A",0,24)
  +tile0 = Chrome.tile(Chrome.nearby(runs,0),0,0)
  +tile1 = Chrome.tile(Chrome.nearby(runs,8),8,0)
  String.eq(Palette.heading("claude | snapshots are prose"),"claude | snapshots are prose")

def sans_checks() -> IO(Unit):
  do IO<Unit>:
    require(sans_check0(),"pinned sans regular and semibold contain independently recorded raster words")
    require(sans_check1(),"large heading raster has its independently recorded two-word coverage")
    require(sans_check2(),"actual static proportional advances provide three distinct hierarchy sizes")
    require(sans_check3(),"bounded labels retain exact fitting text and handle zero space without false ellipsis")
    require(sans_check4(),"proportional label tiles preserve pinned first A coverage and empty inter-glyph cells")
    require(sans_check5(),"initial provider-open headers use complete short presentation titles")
    require(sans_check6(),"title compaction recognizes only exact application-generated prefixes")

def tile_pixel(+tile: UI.Canvas,+x: U32,+y: U32) -> U32:
  match tile:
    case UI.Flat{color}: color
    case UI.Tile{bits,fg,bg}: UI.blend(fg,bg,Mono.coverage(bits,x,y))
    case _: 0

def canvas_pixel(+c: UI.Canvas,+x: U32,+y: U32) -> U32:
  tile_pixel(Tiles.tile.at(8n,c,U32.div(x,8),U32.div(y,8)),U32.mod(x,8),U32.mod(y,8))

def pixels(+fuel: Nat,+c: UI.Canvas,+x: U32,+y: U32) -> List<&2,U32>:
  match fuel:
    case 0n: []
    case 1n+n:
      +color = canvas_pixel(c,x,y)
      U32.and(U32.shrn(color,16n),255) <> U32.and(U32.shrn(color,8n),255) <> U32.and(color,255) <> pixels(n,c,U32.add(x,1),y)

def written(got: File & Result<&1,&1,U32 & String,Unit>) -> IO(File):
  (file,result) = got
  do IO<File>:
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))
    return file

def rows(+fuel: Nat,file: File,+canvas: UI.Canvas,+y: U32) -> IO(File):
  match fuel:
    case 0n: IO.pure(File,file)
    case 1n+n:
      do IO<File>:
        got : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,pixels(1200n,canvas,0,y))
        next : File <- written(got)
        rows(n,next,canvas,U32.add(y,1))

def preview() -> IO(Unit):
  +canvas = UI.draw_canvas_capture(UI.set_edit(sample(),UI.Edit{2,0,0,False{},0}),"Pause",False{})
  do IO<Unit>:
    require(U32.is_eq(canvas_pixel(canvas,0,200),Palette.navigation_paper()) && U32.is_eq(canvas_pixel(canvas,8,120),Palette.navigation_current()),"actual production canvas paints a green destination rail and yellow active History")
    require(U32.is_eq(canvas_pixel(canvas,192,184),UI.selected_bg()) && U32.is_eq(canvas_pixel(canvas,512,200),UI.paper()),"session selection stays distinct from the unmodified evidence pane")
    file : File <- IO.try(File,File.open("history-workspace.ppm","w"))
    header : File & Result<&1,&1,U32 & String,Unit> <- File.write(file,"P6\n1200 664\n255\n")
    open : File <- written(header)
    done : File <- rows(664n,open,canvas,0)
    File.close(done)
    IO.print("PASS synthetic production-canvas preview written; native window acceptance not implied")

def main() -> IO(Unit):
  do IO<Unit>:
    navigation()
    special_contexts()
    session_card_scope()
    sans_checks()
    Keyboard.main()
    Reader.wrap_cases()
    Reader.pointer_cases()
    Tiles.main()
    preview()
