import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/reader_cards.bend as C
import ../src/reader_document.bend as D
import ../src/transcript_document.bend as T
import ../src/bend_ui/text_line.bend as L
import ../src/bend_ui/canvas.bend as Canvas
import ../src/sans_font.bend as Sans
import ./text_line.bend as Lines
import ./reader_cards.bend as Existing
import ./reader_cards_ui.bend as Reader
import ./reader_cards_polish.bend as Polish
import ./ui_attachments.bend as Actions
import ./text_line_canvas.bend as TilePixels

def body() -> String:
  "iW i café é 中文 🙂\tnearby text.\n" ++ String.repeat("Preserved prose should read naturally and still copy exactly. ",7n)

def document() -> D.Document:
  T.render([T.record_all("8",[
    Polish.event("user",body(),"","","","complete"),
    Polish.event("assistant","Keep the implementation inspectable.\n```bend\nx = 3\n```","Read","HIDDEN_INPUT","HIDDEN_RESULT","partial_content")],
    "Citation: synthetic retained record 8")],"12","Mandatory page integrity warning.",7)

def sample() -> UI.State:
  UI.set_document(UI.init(),"Proportional captured prose",document(),"prose-page")

def first_prose(rows: List<&2,C.Row>) -> L.Line:
  match rows:
    case []: L.Line{0,"",0,[],0}
    case C.ProseRow{line,_} <> _: line
    case _ <> rest: first_prose(rest)

def first_index(rows: List<&2,C.Row>,at: U32) -> U32:
  match rows:
    case []: 9999
    case C.ProseRow{_,_} <> _: at
    case _ <> rest: first_index(rest,U32.inc(at))

def prose_count(rows: List<&2,C.Row>) -> U32:
  match rows:
    case []: 0
    case C.ProseRow{_,_} <> rest: U32.inc(prose_count(rest))
    case _ <> rest: prose_count(rest)

def all_mono(rows: List<&2,C.Row>) -> Bool:
  match rows:
    case []: True{}
    case C.TextRow{_,_,_,_} <> rest: all_mono(rest)
    case _ <> _: False{}

def pointer_copy() -> IO(Unit):
  +s : UI.State = sample()
  +model : C.Model = Reader.state_model(s)
  +line : L.Line = first_prose(C.rows(model))
  +row : U32 = first_index(C.rows(model),0)
  +left : U32 = U32.add(G.reader_x(),L.edge(line,1))
  +right : U32 = U32.add(G.reader_x(),L.edge(line,6))
  +drag : UI.State = Actions.changed(UI.event(Move{right,Reader.row_y(row)},Reader.click(s,left,Reader.row_y(row))))
  +reverse : UI.State = Actions.changed(UI.event(Move{left,Reader.row_y(row)},Reader.click(s,right,Reader.row_y(row))))
  +exact : String = D.slice(UI.reader(s),D.Span{U32.inc(L.start(line)),5})
  +all : UI.State = UI.select_all(UI.set_edit(s,UI.Edit{2,0,0,False{},0}))
  do IO<Unit>:
    Lines.check(U32.is_gt(prose_count(C.rows(model)),3) && Existing.exact_rows(C.rows(model),UI.reader(s)),"real MessageText uses cached proportional rows with exact visible scalar slices")
    Lines.check(Bool.not(U32.is_eq(U32.mod(L.edge(line,1),8),0)),"test drag begins at an insertion boundary inside an 8px canvas tile")
    Lines.check(String.eq(UI.selection(drag),exact) && String.eq(UI.selection(reverse),exact),"actual forward and reverse UI drags copy exact scalar text at proportional edges")
    Lines.check(String.eq(Actions.copied(UI.event(Mouse{824,136,0,True{}},drag)),exact),"production Copy action returns exact proportional selection")
    Lines.check(String.eq(UI.selection(all),UI.reader(s)) && String.contains(UI.selection(all),"é 中文 🙂\t"),"select all retains combining CJK emoji and original tab scalars")
    Lines.check(Bool.not(String.contains(UI.selection(all),"HIDDEN_")) && String.contains(UI.selection(all),"partial_content") && String.contains(UI.selection(all),"Mandatory page integrity warning."),"proportional prose preserves hidden-span exclusion and mandatory notices")
    Lines.check(Existing.has_code(C.rows(model)) && all_mono(C.body_kind(D.ToolArguments{},"assistant","raw tool text",0)),"typed fenced code and tool bodies keep mono rows")
    Lines.check(all_mono(C.body_kind(D.EventHeading{},"assistant","coverage: partial_content",0)) && all_mono(C.body_kind(D.PageNotice{},"","warning",0)),"mandatory event and page headings retain their existing rendering path")
    Lines.check(String.eq(C.canonical(model),D.text(document())) && U32.is_eq(C.count(model),D.length(UI.reader(s))),"proportional layout changes neither canonical export input nor scalar count")

def fallback_and_fold() -> IO(Unit):
  +s : UI.State = sample()
  +model : C.Model = Reader.state_model(s)
  +part : D.PartKey = Existing.part_key(D.parts(document()),0)
  +opened : UI.State = UI.card_fold(s,C.token(model),part)
  +selected : UI.State = UI.select_all(UI.set_edit(opened,UI.Edit{2,0,0,True{},0}))
  +restored : UI.State = UI.restore(UI.init(),UI.bookmark(selected))
  +fallback : List<&2,C.Row> = C.prose_body(Fail{L.LayoutBound{}},body(),0,3)
  do IO<Unit>:
    Lines.check(all_mono(fallback) && Existing.exact_rows(fallback,body()),"explicit proportional layout failure retains complete existing mono source slices")
    Lines.check(String.contains(UI.reader(opened),"HIDDEN_INPUT") && String.eq(UI.selection(opened),"") && Bool.not(Reader.drag_flag(opened)),"fold still changes only its exact projection and clears stale selection")
    Lines.check(String.eq(UI.reader(restored),UI.reader(opened)) && String.eq(UI.selection(restored),UI.reader(opened)),"Back restores proportional rows folds and exact selection together")
    Lines.check(Bool.not(Reader.drag_flag(restored)) && Existing.exact_rows(C.rows(Reader.state_model(restored)),UI.reader(restored)),"restored cached prose geometry stops old drag and retains exact mapping")
    Lines.check(String.eq(UI.reader(UI.card_fold(opened,C.token(model),part)),UI.reader(opened)),"old fold token cannot mutate current proportional page")

def glyph_pixels(fuel: Nat,+image: Image,+glyph: Sans.Glyph,+x: U32,+at: U32,+width: U32,+fg: U32,+bg: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+n:
      +column = U32.mod(at,width)
      +row = U32.div(at,width)
      U32.is_eq(TilePixels.pixel(11n,image,U32.add(x,column),U32.add(168,row)),
        Canvas.blend(fg,bg,Sans.coverage(glyph,column,row))) && glyph_pixels(n,image,glyph,x,U32.inc(at),width,fg,bg)

def verify_glyph(image: Image,+code: U32,x: U32,fg: U32,bg: U32) -> Bool:
  +glyph : Sans.Glyph = Sans.glyph(0,code)
  +width : U32 = Sans.advance(glyph)
  glyph_pixels(U32.to_nat(U32.mul(width,24)),image,glyph,x,0,width,fg,bg)

def production_pixels() -> IO(Unit):
  +line : L.Line = Lines.first(Lines.lines(L.wrap("iW i",50,640)))
  +left : U32 = L.edge(line,1)
  +right : U32 = L.edge(line,2)
  +canvas : Canvas.Canvas = UI.draw_card_row(Canvas.Flat{0},C.ProseRow{line,3},168,51,52,None{})
  +image : Image = Canvas.canvas.image(canvas)
  do IO<Unit>:
    Lines.check(U32.is_eq(TilePixels.pixel(11n,image,U32.add(536,left),168),UI.selection_bg()) &&
      U32.is_eq(TilePixels.pixel(11n,image,U32.add(536,U32.sub(left,1)),168),UI.card_background(3)),"actual prose selection begins exactly inside the boundary tile")
    Lines.check(U32.is_eq(TilePixels.pixel(11n,image,U32.add(536,U32.sub(right,1)),168),UI.selection_bg()) &&
      U32.is_eq(TilePixels.pixel(11n,image,U32.add(536,right),168),UI.card_background(3)),"actual prose selection ends at its half-open pixel boundary")
    Lines.check(verify_glyph(image,105,536,UI.ink(),UI.card_background(3)),"all actual unselected narrow-glyph pixels retain Inter coverage and role background")
    Lines.check(verify_glyph(image,87,U32.add(536,left),UI.ink(),UI.selection_bg()),"all actual selected wide-glyph pixels retain Inter coverage and selection background")
    Lines.check(U32.is_eq(TilePixels.pixel(11n,image,527,168),0) && U32.is_eq(TilePixels.pixel(11n,image,1184,168),0) &&
      U32.is_eq(TilePixels.pixel(11n,image,536,192),0),"prose paint remains inside the existing reader row rectangle")

def main() -> IO(Unit):
  do IO<Unit>:
    Existing.main()
    Reader.main()
    Polish.main()
    pointer_copy()
    fallback_and_fold()
    production_pixels()
