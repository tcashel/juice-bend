import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/font.bend as Font

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def kind(action: UI.Action) -> U32:
  match action:
    case UI.NoAction{}: 0
    case UI.Search{}: 1
    case UI.Open{index}: U32.add(100,index)
    case UI.Submit{}: 2
    case UI.Scope{provider}: 3
    case UI.Copy{text}: 4
    case UI.Paste{}: 5
    case UI.Export{}: 6
    case UI.Why{}: 7
    case UI.Usage{}: 8
    case UI.Tools{}: 9
    case UI.Related{}: 10
    case UI.Back{}: 11
    case UI.Rebuild{}: 12
    case UI.Versions{}: 13
    case UI.OpenLatest{}: 14
    case UI.Blame{}: 15
    case UI.Filter{}: 16
    case UI.Refresh{}: 17
    case UI.Pause{}: 18
    case UI.Settings{}: 19
    case UI.SettingsAddFolder{}: 20
    case UI.SettingsImportFile{}: 21
    case UI.SettingsEnable{}: 22
    case UI.SettingsDisable{}: 23
    case UI.SettingsInterval{seconds}: U32.add(1000,seconds)
    case UI.SettingsReload{}: 24
    case UI.Storage{}: 25
    case UI.Files{}: 26
    case UI.RepoOpen{}: 27
    case UI.RepoParent{}: 28
    case UI.Previous{}: 29
    case UI.Next{}: 30
    case UI.ListPrevious{}: 31
    case UI.ListNext{}: 32
    case UI.Quit{}: 33
    case UI.Brief{}: 34
    case UI.BriefPrepare{}: 35
    case UI.BriefCopy{}: 36
    case UI.BriefExport{}: 37
    case UI.CopyStatus{text}: 38

def clicked(result: UI.State & UI.Action,expected: U32,label: String) -> IO(Unit):
  (state,action) = result
  require(U32.is_eq(kind(action),expected),label)

def click(s: UI.State,x: U32,y: U32,expected: U32,label: String) -> IO(Unit):
  clicked(UI.event(Mouse{x,y,0,True{}},s),expected,label)

def state(result: UI.State & UI.Action) -> UI.State:
  (s,action) = result
  s

def repeat(n: Nat,+s: String) -> String:
  match n:
    case 0n: ""
    case 1n+p: s ++ repeat(p,s)

def ready() -> UI.State:
  UI.select_all(UI.set_query(UI.set_results(UI.init(),UI.Results{100,100,True{},True{}}),"A🙂B"))

def ordinary() -> IO(Unit):
  +s = ready()
  do IO<Unit>:
    click(s,16,128,26,"Files target top edge")
    click(s,167,159,26,"Files target far edge")
    click(s,16,160,0,"navigation group gap is inert")
    click(s,16,184,3,"All provider target")
    click(s,16,216,3,"Claude target")
    click(s,16,248,3,"Codex target")
    click(s,16,280,16,"Filter target")
    click(s,16,352,9,"Tools target")
    click(s,16,384,8,"Usage target")
    click(s,16,416,10,"Related target")
    click(s,16,448,13,"Versions target")
    click(s,16,480,14,"Latest target")
    click(s,16,568,19,"Settings target")
    click(s,16,600,25,"Storage target")
    click(s,16,632,34,"Prepare brief target")
    click(s,16,696,4,"Copy target preserves selected query")
    click(s,16,728,5,"Paste target")
    click(s,16,760,1,"Clear target")
    click(s,16,792,0,"Select all target")
    click(s,16,832,11,"Back target")
    click(s,16,855,11,"Back final row does not collide with footer")
    click(s,16,856,0,"footer cannot trigger Back")
    click(s,16,88,17,"Refresh toolbar")
    click(s,200,88,18,"Pause toolbar")
    click(s,360,88,15,"Blame toolbar")
    click(s,520,88,7,"Why toolbar")
    click(s,680,88,6,"Export toolbar")
    click(s,1064,88,29,"Previous reader page")
    click(s,1224,88,30,"Next reader page")
    click(s,900,88,0,"toolbar gap is inert")
    click(s,1016,136,4,"Reader Copy action")
    click(s,1112,136,5,"Reader Paste action")
    click(s,1208,136,1,"Reader Clear action")
    click(s,1304,136,0,"Reader Select all action")
    click(s,200,840,31,"Previous result page")
    click(s,400,840,32,"Next result page")
    click(UI.set_files(s,True{}),200,136,28,"Files parent navigation")
    click(UI.set_files(s,True{}),16,88,27,"Files Open repository toolbar")

def settings() -> IO(Unit):
  +s = UI.set_results(ready(),UI.SettingsResults{0,2,"Resume",True{}})
  do IO<Unit>:
    click(s,16,136,19,"Settings Back")
    click(s,16,184,18,"Settings Automatic")
    click(s,16,216,3,"Settings Claude")
    click(s,16,248,3,"Settings Codex")
    click(s,16,280,20,"Settings Add folder")
    click(s,16,352,21,"Settings Import file")
    click(s,16,384,25,"Settings Storage")
    click(s,16,416,24,"Settings Reload")
    click(s,16,448,22,"Settings Enable")
    click(s,16,480,23,"Settings Disable")
    click(s,16,568,1030,"Settings 30 seconds")
    click(s,16,600,8200,"Settings two hours")
    click(s,16,632,15400,"Settings four hours")
    click(s,16,696,29800,"Settings eight hours")
    click(s,16,728,87400,"Settings 24 hours")
    click(s,1016,136,4,"Settings Copy remains reachable")
    click(s,1112,136,5,"Settings Paste remains reachable")
    click(s,16,760,1,"Settings Clear")
    click(s,16,792,0,"Settings Select all")
    click(s,16,832,12,"Settings Rebuild target")
    click(s,360,88,20,"Settings Add toolbar")
    click(s,520,88,21,"Settings Import toolbar")
    click(s,680,88,22,"Settings Enable toolbar")
    click(s,1064,88,23,"Settings Disable toolbar")
    click(s,1224,88,24,"Settings Reload toolbar")
    click(s,900,88,0,"Settings toolbar whitespace stays inert")

def line(line: UI.Line,start: U32,text: String) -> Bool:
  UI.Line{actual,value} = line
  U32.is_eq(actual,start) && String.eq(value,text)

def text_tests() -> IO(Unit):
  +query = UI.set_query(UI.init(),"A🙂B")
  +drag = state(UI.event(Move{232,40},state(UI.event(Mouse{216,40,0,True{}},query))))
  +wrapped = UI.wrap(repeat(104n,"x") ++ "🙂\nZ")
  +reader = UI.set_reader(UI.init(),"Unicode","é café 中文 🙂\nsecond")
  +selected = UI.select_all(UI.set_edit(reader,UI.Edit{2,0,0,False{},0}))
  +at_second = state(UI.event(Mouse{544,192,0,True{}},reader))
  +at_second_selected = state(UI.event(Move{568,192},at_second))
  +longquery = UI.set_query(UI.init(),repeat(200n,"x"))
  +pressed = state(UI.event(Mouse{208,40,0,True{}},longquery))
  +moved = state(UI.event(Move{288,40},pressed))
  do IO<Unit>:
    require(String.eq(UI.selection(drag),"🙂B"),"8px query drag preserves Unicode scalars")
    require(line(UI.line_at(wrapped,1),104,"🙂"),"104-column wrapping keeps exact offset")
    require(line(UI.line_at(wrapped,2),106,"Z"),"newline after wrapped emoji keeps exact offset")
    require(String.eq(UI.reader(selected),"é café 中文 🙂\nsecond"),"font does not alter canonical reader")
    require(String.eq(UI.selection(selected),UI.reader(reader)),"Select all retains combining CJK emoji")
    require(String.eq(UI.selection(at_second_selected),"eco"),"24px reader pointer selects second-line scalars")
    require(U32.is_eq(UI.query_offset(pressed),56) && U32.is_eq(UI.query_offset(moved),56),"query drag freezes viewport at new width")
    require(U32.is_eq(UI.length(UI.selection(moved)),10),"query drag uses eight-pixel advance")
    require(U32.is_eq(UI.blend(16777215,0,15),16777215) && U32.is_eq(UI.blend(16777215,0,0),0),"grayscale blend endpoints are exact")
    require(U32.is_eq(Font.coverage(Font.half(Font.glyph(32),True{}),0,0),0),"space glyph remains empty")
    require(U32.is_eq(G.reader_columns(),104) && U32.is_eq(G.reader_rows(),28),"reader geometry stays bounded")

def paging() -> IO(Unit):
  +s = UI.set_rows(UI.init(),["0","1","2","3","4","5","6","7","8","9","10","11"])
  do IO<Unit>:
    click(s,200,184,100,"first card top edge")
    click(s,200,247,100,"first card bottom edge")
    click(s,200,248,101,"second card starts at 64px")
    click(UI.set_position(s,11,0),200,184,102,"selected tail keeps ten visible rows")
    click(UI.set_position(s,11,0),200,760,111,"last visible card resolves original index")
    click(s,200,176,0,"list heading does not open a row")
    click(s,200,824,0,"padding after final visible card cannot open invisible row")
    click(s,200,831,0,"last padding pixel cannot open invisible row")
    click(UI.init(),400,840,0,"unloaded pagination is inert")

def copied(result: UI.State & UI.Action) -> String:
  (s,action) = result
  match action:
    case UI.CopyStatus{text}: text
    case _: ""

def kind.action(result: UI.State & UI.Action) -> U32:
  (s,action) = result
  kind(action)

def status_tests() -> IO(Unit):
  +message = repeat(80n,"A long diagnostic line.\n") ++ "final diagnostic café 🙂"
  +original = UI.set_edit(UI.set_position(UI.set_reader(UI.set_status(UI.init(),message),"Retained transcript","exact evidence"),4,7),UI.Edit{2,8,2,False{},0})
  +opened = state(UI.event(Mouse{10,880,0,True{}},original))
  +scrolled = state(UI.event(Key{63277,True{}},opened))
  +closed = state(UI.event(Key{27,True{}},scrolled))
  +query = UI.select_all(UI.set_query(UI.init(),"café 中文 🙂"))
  +query_open = state(UI.event(Mouse{10,880,0,True{}},query))
  +query_arrival = UI.set_reader(query_open,"arrival","new evidence")
  +query_returned = state(UI.event(Key{27,True{}},query_arrival))
  do IO<Unit>:
    require(U32.is_eq(UI.focus(opened),5),"status strip opens full diagnostic inspector")
    require(String.eq(UI.reader(opened),"exact evidence") && U32.is_eq(UI.scroll(scrolled),7),"status inspector preserves canonical evidence and reader scroll")
    require(String.eq(UI.selection(closed),UI.selection(original)),"status inspection preserves canonical evidence selection")
    require(String.eq(copied(UI.event(Mouse{1140,128,0,True{}},scrolled)),message),"status Copy and close includes text beyond summary")
    require(U32.is_eq(UI.focus(closed),2) && U32.is_eq(UI.selected(closed),4) && U32.is_eq(UI.scroll(closed),7),"Escape restores reader without changing list or scroll")
    click(opened,680,88,0,"status modal blocks underlying Export")
    require(U32.is_eq(kind.action(UI.event(Key{101,True{}},UI.set_modifiers(opened,True{},False{}))),0),"status modal blocks Command-E export")
    require(String.eq(UI.selection(query_returned),UI.selection(query)) && U32.is_eq(UI.focus(query_returned),0),"status closes to exact query selection after reader arrival")
    require(String.eq(copied(UI.event(Key{99,True{}},UI.set_modifiers(scrolled,True{},False{}))),message),"Command-C in status copies full diagnostic")
    require(String.eq(UI.selection(state(UI.event(Key{99,True{}},UI.set_modifiers(scrolled,True{},False{})))),UI.selection(original)),"status copy restores canonical selection before callback")

def card_is(value: UI.Card,first: String,second: String) -> Bool:
  UI.Card{a,b} = value
  String.eq(a,first) && String.eq(b,second)

def card_width(value: UI.Card) -> Bool:
  UI.Card{a,b} = value
  U32.is_le(UI.length(a),38) && U32.is_le(UI.length(b),38)

def card_tests() -> IO(Unit):
  +row = {"claude  claude neutral physical record 0" : String}
  +reader = UI.set_reader(UI.set_rows(UI.init(),[row]),"canonical",row)
  do IO<Unit>:
    require(card_is(UI.card("short title"),"short title",""),"short card uses one exact line")
    require(card_is(UI.card(row),"claude  claude neutral physical","record 0"),"card keeps trailing record number with its word")
    require(card_is(UI.card(repeat(39n,"x")),repeat(31n,"x"),repeat(8n,"x")),"unbroken card avoids a one-character second line")
    require(card_is(UI.card(repeat(90n,"🙂")),repeat(38n,"🙂"),repeat(37n,"🙂") ++ "…"),"card ellipsis counts Unicode scalars")
    require(card_width(UI.card(repeat(100n,"long title "))),"both card lines respect the existing width")
    require(String.eq(UI.reader(reader),row),"card formatting leaves canonical reader unchanged")
    require(String.eq(UI.capture_hint(True{}),"Capture suspended") && String.eq(UI.capture_hint(False{}),""),"effective capture hint stays separate from stored toggle label")
    require(String.eq(UI.top_label(1,False{},False{},True{},"Resume"),"Resume"),"Usage preserves saved preference toggle semantics")

def main() -> IO(Unit):
  do IO<Unit>:
    ordinary()
    settings()
    text_tests()
    paging()
    status_tests()
    card_tests()
