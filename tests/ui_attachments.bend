# Pure production painter / input checks. Native window interaction remains a
# separate acceptance gate; these fixtures contain synthetic metadata only.
import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/font.bend as Font
import ./tab_readability.bend as Tiles

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def kind(value: UI.Action) -> U32:
  match value:
    case UI.NoAction{}: 0
    case UI.Attachments{}: 1
    case UI.AttachmentExport{}: 2
    case UI.Back{}: 3
    case UI.ListPrevious{}: 4
    case UI.ListNext{}: 5
    case UI.Copy{_}: 6
    case UI.Open{_}: 7
    case UI.Paste{}: 8
    case UI.Search{}: 9
    case UI.QuotaDisconnect{}: 10
    case UI.Storage{}: 11
    case UI.BriefPrepare{}: 12
    case UI.SettingsAddFolder{}: 13
    case UI.AttachmentFolders{}: 14
    case UI.AttachmentPreview{}: 15
    case _: 99

def action(result: UI.State & UI.Action) -> U32:
  (_,value) = result
  kind(value)

def changed(result: UI.State & UI.Action) -> UI.State:
  (state,_) = result
  state

def copied(result: UI.State & UI.Action) -> String:
  (_,value) = result
  match value:
    case UI.Copy{text}: text
    case _: ""

def opened(result: UI.State & UI.Action) -> U32:
  (_,value) = result
  match value:
    case UI.Open{index}: index
    case _: 99

def click(s: UI.State,x: U32,y: U32,expected: U32,label: String) -> IO(Unit):
  require(U32.is_eq(action(UI.event(Mouse{x,y,0,True{}},s)),expected),label)

def content() -> UI.State:
  UI.set_edit(UI.set_rows(UI.set_reader(UI.set_query(UI.init(),"scope sentinel café 中文 🙂"),
    "Long capture title that must leave room for attachment controls",
    "A🙂B\t café 中文\nSnapshot 9007199254740993 / record 0 / reference 1\nRaw record coverage is partial; remote reference unavailable."),
    ["Inline image\nRecord 0 / reference 1","Remote image\nRecord 1 / reference 0"]),UI.Edit{2,4,1,False{},0})

def panel(phase: U32,exportable: Bool,previous: Bool,next: Bool) -> UI.State:
  UI.set_results(content(),UI.AttachmentResults{phase,exportable,previous,next})

def ready() -> UI.State:
  panel(2,True{},True{},True{})

def entry() -> IO(Unit):
  do IO<Unit>:
    require(U32.is_eq(G.attachment_entry_x(),696) && U32.is_eq(G.attachment_entry_right(),800) &&
      U32.is_eq(G.reader_title_columns(),18) && U32.is_eq(G.text_actions_x(),808),"attachment entry reserves exact 104px target while retaining existing Copy rectangle")
    click(content(),696,120,1,"reader Attachments includes its top-left pixel")
    click(content(),799,151,1,"reader Attachments includes its bottom-right pixel")
    click(content(),695,120,0,"reader title margin cannot open Attachments")
    click(content(),800,120,0,"gap between Attachments and Copy is inert")
    click(content(),696,119,0,"row above Attachments cannot activate entry")
    click(content(),696,152,0,"row below Attachments cannot activate entry")
    click(content(),808,120,6,"Copy keeps its original left edge and exact text selection")
    click(ready(),704,136,0,"current Attachments mode cannot start a duplicate entry request")
    require(String.eq(UI.selection(changed(UI.event(Mouse{704,136,0,True{}},content()))),"🙂B\t"),"entering Attachments preserves canonical reader selection for the model bookmark")

def controls() -> IO(Unit):
  do IO<Unit>:
    click(ready(),16,120,0,"duplicate sidebar Back is removed and inert")
    click(ready(),16,152,0,"duplicate sidebar Previous is removed and inert")
    click(ready(),16,184,0,"duplicate sidebar Next is removed and inert")
    click(ready(),16,208,0,"former sidebar Export first pixel is inert")
    click(ready(),167,239,0,"former sidebar Export last pixel is inert")
    click(ready(),16,240,0,"duplicate sidebar Copy details is removed and inert")
    click(ready(),16,280,0,"duplicate sidebar Folders is removed and inert")
    click(ready(),16,472,0,"attachment sidebar cannot reach hidden History Storage")
    click(ready(),16,600,0,"attachment sidebar cannot dispatch old bottom-row Back")
    click(ready(),16,88,3,"attachment toolbar Back returns to the original captured reader")
    click(ready(),152,80,2,"attachment header Export includes top-left pixel")
    click(ready(),287,111,2,"attachment header Export includes bottom-right pixel")
    click(ready(),288,88,0,"gap after attachment header Export is inert")
    click(ready(),312,88,6,"attachment header Copy details is reachable")
    click(ready(),432,88,15,"attachment header Open image uses preview action")
    click(ready(),552,88,14,"attachment header Folders cannot dispatch a transcript export")
    click(ready(),864,88,4,"attachment header Previous uses raw-record page action")
    click(ready(),1040,88,5,"attachment header Next uses raw-record page action")
    click(ready(),200,600,0,"duplicate list Previous is removed and inert")
    click(ready(),400,600,0,"duplicate list Next is removed and inert")
    require(U32.is_eq(opened(UI.event(Mouse{200,256,0,True{}},ready())),1),"attachment second row opens exact local row index")
    require(String.eq(copied(UI.event(Mouse{312,88,0,True{}},ready())),UI.reader(content())),"Copy details returns full canonical metadata including Unicode and tabs")
    require(String.eq(copied(UI.event(Mouse{824,136,0,True{}},ready())),"🙂B\t"),"reader Copy remains distinct from Copy details")

def blocked(+s: UI.State) -> Bool:
  U32.is_eq(action(UI.event(Mouse{864,88,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{1040,88,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{16,216,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{168,88,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Mouse{400,600,0,True{}},s)),0) &&
    U32.is_eq(action(UI.event(Key{101,True{}},UI.set_modifiers(s,True{},False{}))),0)

def phases() -> IO(Unit):
  do IO<Unit>:
    require(blocked(panel(0,True{},True{},True{})),"unloaded attachment state cannot export or page stale rows")
    require(blocked(panel(1,True{},True{},True{})),"pending attachment state disables export and page requests")
    require(blocked(panel(3,True{},True{},True{})),"exporting attachment state cannot submit another export or page")
    require(blocked(panel(99,True{},True{},True{})),"unknown attachment phase cannot grant export")
    click(panel(2,False{},True{},True{}),168,88,0,"unsupported or remote selected occurrence cannot export bytes")
    click(panel(2,True{},False{},True{}),864,88,0,"first record page has no Previous")
    click(panel(2,True{},True{},False{}),1040,88,0,"last record page has no Next")
    click(panel(1,False{},False{},False{}),16,88,3,"Back remains usable during attachment work")
    click(panel(3,False{},False{},False{}),312,88,6,"exporting occurrence details can still be copied")
    require(U32.is_eq(action(UI.event(Key{101,True{}},UI.set_modifiers(ready(),True{},False{}))),2),"Command-E uses eligible attachment export rather than transcript export")

def readonly_scope() -> IO(Unit):
  +s = UI.set_edit(ready(),UI.Edit{0,3,0,False{},0})
  +typed = changed(UI.event(Text{"untrusted edit"},s))
  +cleared = changed(UI.event(Mouse{1016,136,0,True{}},s))
  +all = changed(UI.event(Mouse{1112,136,0,True{}},s))
  +keyall = changed(UI.event(Key{97,True{}},UI.set_modifiers(s,True{},False{})))
  +queryclick = changed(UI.event(Mouse{216,40,0,True{}},ready()))
  +dragged = changed(UI.event(Move{560,168},changed(UI.event(Mouse{544,168,0,True{}},ready()))))
  do IO<Unit>:
    require(String.eq(UI.query_label(ready()),"Captured record scope"),"scope field label never asks for an output path")
    require(String.eq(UI.query(typed),UI.query(s)) && U32.is_eq(action(UI.event(Text{"ignored"},s)),0),"attachment text events cannot edit scope or dispatch search")
    require(String.eq(UI.query(cleared),UI.query(s)),"attachment Clear cannot mutate hidden query state")
    click(ready(),920,136,0,"attachment Paste toolbar is inert")
    click(ready(),1016,136,0,"attachment Clear toolbar is inert")
    require(U32.is_eq(action(UI.event(Key{118,True{}},UI.set_modifiers(s,True{},False{}))),0),"Command-V cannot request clipboard insertion into read-only scope")
    require(U32.is_eq(action(UI.event(Key{127,True{}},s)),0) &&
      String.eq(UI.query(changed(UI.event(Key{127,True{}},s))),UI.query(s)),"Backspace cannot edit attachment scope or search")
    require(U32.is_eq(action(UI.event(Key{13,True{}},s)),0),"Enter cannot submit scope text as a command")
    click(s,824,136,0,"Copy cannot expose an invisible stale query selection")
    require(U32.is_eq(action(UI.event(Key{99,True{}},UI.set_modifiers(s,True{},False{}))),0),"Command-C requires the visible reader selection in attachment mode")
    require(U32.is_eq(UI.focus(queryclick),2) && String.eq(UI.selection(queryclick),"🙂B\t"),"read-only scope click leaves reader focus and selection unchanged")
    require(String.eq(UI.selection(all),UI.reader(s)) && String.eq(UI.selection(keyall),UI.reader(s)),"toolbar and Command-A select canonical details even from stale query focus")
    require(String.eq(UI.selection(dragged),"🙂B"),"attachment reader pointer drag retains scalar-correct Unicode selection")
    require(U32.is_eq(UI.focus(changed(UI.event(Key{9,True{}},s))),1) &&
      U32.is_eq(UI.focus(changed(UI.event(Key{9,True{}},UI.set_edit(s,UI.Edit{1,0,0,False{},0})))),2),"attachment Tab cycles only reference list and reader")

def tile_glyph(c: UI.Canvas,code: U32,foreground: U32,background: U32) -> Bool:
  match c:
    case UI.Tile{bits,fg,bg}:
      U32.is_eq(Font.row(bits,7),Font.row(Font.half(Font.glyph(code),True{}),7)) &&
        U32.is_eq(fg,foreground) && U32.is_eq(bg,background)
    case _: False{}

def glyph(c: UI.Canvas,x: U32,y: U32,code: U32,foreground: U32,background: U32) -> Bool:
  tile_glyph(Tiles.tile.at(8n,c,U32.div(x,8),U32.div(y,8)),code,foreground,background)

def label_bounds(fuel: Nat,+index: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+n:
      U32.is_le(UI.length(UI.attachment_side_label(index)),18) &&
        U32.is_le(UI.length(UI.attachment_top_label(index)),U32.sub(U32.div(G.top_width(index),8),2)) &&
        label_bounds(n,U32.inc(index))

def painting() -> IO(Unit):
  +canvas = UI.draw_canvas_capture(ready(),"Pause",True{})
  +pending = UI.draw_canvas_capture(panel(1,True{},True{},True{}),"Pause",True{})
  +normal = UI.draw_canvas_capture(content(),"Pause",False{})
  do IO<Unit>:
    require(label_bounds(7n,0),"all attachment labels fit the exact existing control rectangles")
    require(String.eq(UI.result_label(UI.AttachmentResults{3,False{},False{},False{}}),"Exporting selected inline bytes"),"exporting phase is labeled as pending publication rather than a read failure")
    require(String.eq(UI.list_heading(UI.AttachmentResults{2,False{},False{},False{}},False{}),"Captured attachments") &&
      String.eq(UI.result_label(UI.AttachmentResults{2,False{},False{},False{}}),"See record coverage in details"),"attachment list names captured metadata without claiming total extraction completeness")
    require(Tiles.tile.empty(Tiles.tile.at(8n,canvas,2,27),UI.rail()) && glyph(canvas,160,88,69,UI.accent(),UI.panel()),"eligible Export bytes paints once at its toolbar target")
    require(Tiles.tile.empty(Tiles.tile.at(8n,pending,2,27),UI.rail()) && glyph(pending,160,88,69,UI.muted(),UI.panel()),"pending Export bytes remains muted at its sole toolbar target")
    require(glyph(pending,856,88,80,UI.muted(),UI.panel()) && Tiles.tile.empty(Tiles.tile.at(8n,pending,24,74),UI.panel()) && Tiles.tile.empty(Tiles.tile.at(8n,pending,45,74),UI.panel()),"pending toolbar Previous remains muted while duplicate list paging is absent")
    require(glyph(canvas,704,128,97,UI.heading_ink(),UI.paper()) && glyph(normal,704,128,65,UI.accent(),UI.paper()),"attachment panel reclaims its title while captured reader paints the entry")
    require(glyph(normal,784,128,115,UI.accent(),UI.paper()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,normal,99,16),UI.paper()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,normal,100,16),UI.paper()),"complete Attachments label ends before its trailing padding and Copy gap")
    require(glyph(normal,816,128,67,UI.accent(),UI.paper()) && glyph(normal,1104,128,83,UI.accent(),UI.paper()),"long reader title leaves Copy and Select all unobscured")
    require(Tiles.tile.empty(Tiles.tile.at(8n,canvas,114,16),UI.paper()) && Tiles.tile.empty(Tiles.tile.at(8n,canvas,126,16),UI.paper()),"inapplicable Paste and Clear are absent from the read-only attachment toolbar")
    require(glyph(canvas,208,32,65,UI.muted(),UI.paper()),"attachment scope paints instructions without an editable caret")
    require(Tiles.tile.empty(Tiles.tile.at(8n,canvas,2,47),UI.rail()),"unused attachment sidebar rows below new controls contain no hidden old controls")
    require(U32.is_eq(G.width(),1200) && U32.is_eq(G.height(),664),"attachment mode preserves accepted compact native dimensions")

def other_modes() -> IO(Unit):
  do IO<Unit>:
    click(content(),16,472,11,"normal History Storage remains reachable")
    click(UI.set_results(content(),UI.QuotaResults{2,True{},True{},2,0,0,False{}}),312,88,10,"quota Disconnect retains its own header mapping")
    click(UI.set_results(content(),UI.BriefResults{0}),16,152,12,"Brief Prepare retains sidebar behavior")
    click(UI.set_results(content(),UI.SettingsResults{0,1,"Pause",True{}}),312,88,13,"Settings Add folder retains header behavior")
    click(content(),920,136,8,"normal reader toolbar Paste remains enabled")
    require(U32.is_eq(action(UI.event(Text{"x"},UI.set_edit(content(),UI.Edit{0,0,0,False{},0}))),9),"normal query typing continues to dispatch lexical search")

def main() -> IO(Unit):
  do IO<Unit>:
    entry()
    controls()
    phases()
    readonly_scope()
    painting()
    other_modes()
