import Base
import ../src/reader_cards.bend as C
import ../src/reader_document.bend as D
import ../src/reader_projection.bend as P
import ../src/transcript_document.bend as T
import ../src/providers.bend as Provider
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/bend_ui/canvas.bend as Canvas
import ../src/bend_ui/text_line.bend as Prose
import ./reader_cards.bend as Existing
import ./reader_cards_ui.bend as Reader
import ./ui_attachments.bend as Actions
import ./history_workspace.bend as Pixels

def check(ok: Bool,label: String) -> IO(Unit): Existing.check(ok,label)

def user_text() -> String:
  "Review the captured change. café é 中文 🙂\n[assistant] is literal user text."

def assistant_text() -> String:
  "The retained source keeps the change inspectable.\n```bend\nvalue = 42\n```"

def event(role: String,body: String,+tool: String,args: String,result: String,coverage: String) -> Provider.Record:
  Provider.ProviderEvent{role,body,tool,Bool.pick(String,String.is_empty(tool),"","call-polish"),args,result,"/synthetic/polish","session-polish",
    "2026-10-22T00:00:00Z","synthetic-model","","",coverage}

def document() -> D.Document:
  T.render([T.record_all("4",[
    event("user",user_text(),"","","","complete"),
    event("assistant",assistant_text(),"Write","HIDDEN_ARGUMENTS","HIDDEN_RESULT","partial_content"),
    event("reviewer","Unknown roles retain a neutral surface.","","","","unsupported")],
    "Citation: synthetic retained record 4")],"12","Integrity warning remains visible.",7)

def sample() -> UI.State:
  UI.set_status(UI.set_rows(UI.set_query(UI.set_document(UI.init(),"Captured conversation",document(),"polish-page"),
    "repository: /synthetic/polish"),["claude  Review the captured change","codex  Inspect the retained evidence"]),
    "Captured page. Copy selects visible text; export includes collapsed details.")

def gaps(rows: List<&2,C.Row>) -> U32:
  match rows:
    case []: 0
    case C.GapRow{} <> rest: U32.inc(gaps(rest))
    case _ <> rest: gaps(rest)

def gap_shape(rows: List<&2,C.Row>,+seen: Bool,pending: Bool) -> Bool:
  match rows:
    case []: Bool.not(pending)
    case C.GapRow{} <> rest: seen && Bool.not(pending) && gap_shape(rest,seen,True{})
    case C.RoleRow{_,_} <> rest: Bool.not(Bool.xor(seen,pending)) && gap_shape(rest,True{},False{})
    case _ <> rest: Bool.not(pending) && gap_shape(rest,seen,False{})

def first_gap(rows: List<&2,C.Row>,+at: U32) -> U32:
  match rows:
    case []: 9999
    case C.GapRow{} <> _: at
    case _ <> rest: first_gap(rest,U32.inc(at))

def named_row(rows: List<&2,C.Row>,+wanted: String,+at: U32) -> U32:
  match rows:
    case []: 9999
    case C.TextRow{_,text,_,_} <> rest:
      Bool.pick(U32,String.eq(text,wanted),at,named_row(rest,wanted,U32.inc(at)))
    case C.ProseRow{line,_} <> rest:
      Bool.pick(U32,String.eq(Prose.text(line),wanted),at,named_row(rest,wanted,U32.inc(at)))
    case _ <> rest: named_row(rest,wanted,U32.inc(at))

def named_style(rows: List<&2,C.Row>,+wanted: String) -> U32:
  match rows:
    case []: 9999
    case C.TextRow{_,text,_,style} <> rest:
      Bool.pick(U32,String.eq(text,wanted),style,named_style(rest,wanted))
    case C.ProseRow{line,style} <> rest:
      Bool.pick(U32,String.eq(Prose.text(line),wanted),style,named_style(rest,wanted))
    case _ <> rest: named_style(rest,wanted)

def no_hit(hit: C.Hit) -> Bool:
  match hit:
    case C.NoHit{}: True{}
    case _: False{}

def text_position(hit: C.Hit) -> U32:
  match hit:
    case C.TextHit{position}: position
    case _: 4294967295

def key_equal(left: List<&2,D.PartKey>,right: List<&2,D.PartKey>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Con{a,tail} Con{b,rest}: D.key_equal(a,b) && key_equal(tail,rest)
    case _ _: False{}

def exact_count(+model: C.Model) -> Bool:
  U32.is_eq(C.row_count(model),U32.from_nat(List.length(&2,C.Row,C.rows(model)))) &&
    U32.is_eq(C.count(model),D.length(C.text(model))) && Existing.exact_rows(C.rows(model),C.text(model))

def structure() -> IO(Unit):
  +doc : D.Document = document()
  +model : C.Model = C.open(doc,"polish-page")
  +key : D.PartKey = Existing.part_key(D.parts(doc),0)
  +expanded : C.Model = C.toggle(model,C.token(model),key)
  +expected : String = P.text(P.build(doc,C.initial_folds(D.parts(doc))))
  do IO<Unit>:
    check(U32.is_eq(gaps(C.rows(model)),2) && gap_shape(C.rows(model),False{},False{}),"exactly one chrome gap separates consecutive typed events, with no leading or trailing gap")
    check(String.eq(C.text(model),expected) && String.eq(C.canonical(model),D.text(doc)),"event spacing adds no visible or canonical scalar")
    check(exact_count(model) && exact_count(expanded),"cached row and scalar counts remain exact before and after a fold")
    check(U32.is_eq(gaps(C.rows(expanded)),2) && gap_shape(C.rows(expanded),False{},False{}),"expanding a disclosure cannot insert or remove event gaps")
    check(key_equal(C.controls(C.rows(model)),C.initial_folds(D.parts(doc))) && key_equal(C.controls(C.rows(model)),C.controls(C.rows(expanded))),"role and gap chrome cannot reorder or introduce disclosure controls")
    check(String.contains(C.text(model),"partial_content") && String.contains(C.text(model),"unsupported") && String.contains(C.text(model),"Integrity warning remains visible."),"mandatory coverage and page warnings survive role surfaces")
    check(String.contains(C.text(expanded),"HIDDEN_ARGUMENTS") && Bool.not(String.contains(C.text(expanded),"HIDDEN_RESULT")),"disclosure still expands only its exact typed part")
    check(String.eq(C.canonical(expanded),D.text(doc)),"expanded presentation preserves complete canonical export source")
    check(U32.is_eq(named_style(C.rows(model),"[assistant] is literal user text."),3),"forged role-looking body text retains its verified user surface")

def pointer_and_selection() -> IO(Unit):
  +s : UI.State = sample()
  +model : C.Model = Reader.state_model(s)
  +gap : U32 = first_gap(C.rows(model),0)
  +before : U32 = named_row(C.rows(model),"[assistant] is literal user text.",0)
  +after : U32 = named_row(C.rows(model),"The retained source keeps the change inspectable.",0)
  +first : U32 = text_position(C.hit_pixel(model,before,8))
  +last : U32 = text_position(C.hit_pixel(model,after,32))
  +all : UI.State = UI.select_all(UI.set_edit(s,UI.Edit{2,0,0,False{},0}))
  +drag : UI.State = Actions.changed(UI.event(Move{568,Reader.row_y(after)},Reader.click(s,544,Reader.row_y(before))))
  do IO<Unit>:
    check(no_hit(C.hit(model,gap,1)) && no_hit(C.hit(model,U32.inc(gap),1)),"gap and proportional role heading are nonselectable")
    check(String.eq(UI.selection(Reader.click(all,544,Reader.row_y(gap))),UI.reader(s)),"clicking an event gap preserves the existing selection")
    check(U32.is_lt(before,gap) && U32.is_gt(after,gap) && U32.is_lt(after,G.reader_rows()),"synthetic drag crosses a visible inter-event gap")
    check(String.eq(UI.selection(drag),D.slice(UI.reader(s),D.Span{first,U32.sub(last,first)})),"drag across gap copies only the unchanged visible scalar interval")
    check(String.eq(UI.selection(all),C.text(model)) && Bool.not(String.contains(UI.selection(all),"HIDDEN_")),"select all includes no gap characters or collapsed material")

def long_document() -> D.Document:
  T.render([T.record_all("9",[
    event("user",String.repeat("A retained line.\n",18n),"","","","complete"),
    event("assistant","Second event has the focused tool.","Read",String.repeat("ARGUMENT\n",20n),"RESULT","complete")],
    "Citation: synthetic retained record 9")],"12","Keep this warning visible.",7)

def scroll(ui: UI.State) -> U32:
  UI.State{_,UI.Input{_,value,_,_,_},_,_} = ui
  value

def focused_disclosure() -> IO(Unit):
  +doc : D.Document = long_document()
  +s : UI.State = UI.set_document(UI.init(),"Long captured conversation",doc,"long-page")
  +model : C.Model = Reader.state_model(s)
  +key : D.PartKey = Existing.part_key(D.parts(doc),0)
  +row : U32 = Reader.row_index(C.focus_row(C.rows(model),key,0))
  +focused : UI.State = UI.card_focus_set(s,model,key)
  +offset : U32 = scroll(focused)
  do IO<Unit>:
    check(U32.is_ge(row,G.reader_rows()) && U32.is_gt(offset,0) && U32.is_lt(U32.sub(row,offset),G.reader_rows()),"later disclosure focus scroll includes added event spacing")
    check(String.contains(UI.reader(Reader.click(focused,1104,Reader.row_y(U32.sub(row,offset)))),"ARGUMENT"),"scrolled disclosure hit target still activates the intended key")
    check(String.eq(UI.query(focused),UI.query(s)),"card focus changes neither query nor page identity")

def compact_scroll() -> IO(Unit):
  +doc : D.Document = long_document()
  +s : UI.State = UI.set_document(UI.init(),"Long captured conversation",doc,"long-page")
  +key : D.PartKey = Existing.part_key(D.parts(doc),0)
  +opened : UI.State = UI.card_fold(s,C.token(Reader.state_model(s)),key)
  +bottom : UI.State = UI.scroll_by(opened,True{},9999)
  +closed : UI.State = UI.card_fold(bottom,C.token(Reader.state_model(bottom)),key)
  +model : C.Model = Reader.state_model(closed)
  +row : U32 = Reader.row_index(C.focus_row(C.rows(model),key,0))
  do IO<Unit>:
    check(U32.is_gt(UI.reader_row_count(opened),UI.reader_row_count(closed)) && exact_count(model),"compact projection replaces expanded row count while keeping gap rows")
    check(U32.is_le(scroll(closed),row) && U32.is_lt(U32.sub(row,scroll(closed)),G.reader_rows()),"collapse from bottom returns its disclosure to the compact viewport")
    check(U32.is_eq(scroll(UI.scroll_by(closed,True{},0)),UI.minus(UI.reader_row_count(closed),G.reader_rows())),"subsequent scroll clamp uses compact rows including event gaps")
    check(String.eq(UI.reader(closed),UI.reader(s)) && String.eq(UI.selection(closed),""),"compact scroll adjustment preserves visible text and clears stale selection")

def typed_surfaces() -> IO(Unit):
  +user : Canvas.Canvas = UI.draw_card_row(Canvas.Flat{0},C.RoleRow{"You","user"},168,0,0,None{})
  +assistant : Canvas.Canvas = UI.draw_card_row(Canvas.Flat{0},C.RoleRow{"Assistant","assistant"},168,0,0,None{})
  +selected : Canvas.Canvas = UI.draw_card_row(Canvas.Flat{0},C.TextRow{0," ",1,3},168,0,1,None{})
  +gap : Canvas.Canvas = UI.draw_card_row(Canvas.Flat{0},C.GapRow{},168,0,1,None{})
  do IO<Unit>:
    check(U32.is_eq(C.part_style(D.MessageText{},"user"),3) && U32.is_eq(C.part_style(D.MessageText{},"assistant"),4),"body surfaces follow typed role metadata")
    check(U32.is_eq(C.part_style(D.MessageText{},"reviewer"),0) && U32.is_eq(C.part_style(D.EventHeading{},"reviewer"),1),"unknown role uses neutral text surfaces")
    check(U32.is_eq(C.part_style(D.FencedCode{},"user"),2) && U32.is_eq(C.part_style(D.ToolArguments{},"assistant"),2),"code and tool presentation takes precedence over role tint")
    check(U32.is_eq(Pixels.canvas_pixel(user,528,168),13213493) && U32.is_eq(Pixels.canvas_pixel(assistant,528,168),7640440),"production role painter draws distinct grid-aligned accents")
    check(U32.is_eq(Pixels.canvas_pixel(user,1176,184),16775125) && U32.is_eq(Pixels.canvas_pixel(assistant,1176,184),15922929),"production role surfaces distinguish user and assistant")
    check(U32.is_eq(Pixels.canvas_pixel(selected,536,168),UI.selection_bg()),"selected text background overrides role tint")
    check(U32.is_eq(Pixels.canvas_pixel(gap,536,168),UI.paper()),"gap chrome renders paper without a selection highlight")

def main() -> IO(Unit):
  do IO<Unit>:
    structure()
    pointer_and_selection()
    focused_disclosure()
    compact_scroll()
    typed_surfaces()
