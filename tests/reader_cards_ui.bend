import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/reader_cards.bend as C
import ../src/reader_document.bend as D
import ../src/reader_projection.bend as P
import ./reader_cards.bend as Fixture
import ./ui_attachments.bend as A

def check(ok: Bool,label: String) -> IO(Unit):
  Fixture.check(ok,label)

def base(revision: U32,page: String) -> UI.State:
  UI.set_document(UI.init(),"Assistant transcript",Fixture.document(revision),page)

def model(value: Maybe<&2,C.Model>) -> C.Model:
  match value:
    case Some{model}: model
    case None{}: C.open(Fixture.document(0),"missing")

def state_model(s: UI.State) -> C.Model:
  model(UI.card_model(s))

def row_index(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{row}: row
    case None{}: 9999

def row_y(row: U32) -> U32:
  U32.add(G.reader_y(),U32.mul(row,G.line_pitch()))

def drag_flag(s: UI.State) -> Bool:
  UI.State{_,UI.Input{_,_,UI.Edit{_,_,_,drag,_},_,_},_,_} = s
  drag

def click(s: UI.State,x: U32,y: U32) -> UI.State:
  A.changed(UI.event(Mouse{x,y,0,True{}},s))

def key(s: UI.State,code: U32) -> UI.State:
  A.changed(UI.event(Key{code,True{}},s))

def plain_and_admission() -> IO(Unit):
  +s = base(7,"page-a")
  +plain = UI.set_document(s,"Plain fallback",D.Plain{"complete malformed view café 中文 🙂",8},"page-b")
  do IO<Unit>:
    check(Maybe.is_some(&2,C.Model,UI.card_model(s)),"admitted typed transcript opens card reader")
    check(String.eq(UI.reader(s),C.text(state_model(s))) && U32.is_eq(UI.reader_count(s),D.length(UI.reader(s))),"visible content and cached count share projection coordinates")
    check(String.contains(UI.reader(s),"partial_content") && String.contains(UI.reader(s),"Integrity warning stays visible"),"native reader leaves coverage and page warnings visible")
    check(Bool.not(Maybe.is_some(&2,C.Model,UI.card_model(plain))) && String.eq(UI.reader(plain),"complete malformed view café 中文 🙂"),"failed metadata admission keeps full plain reader and retires cards")
    check(String.eq(UI.top_label(4,False{},False{},False{},"Pause"),"Export captured page") && U32.is_eq(G.top_index(839),4) && U32.is_eq(G.top_index(840),99),"captured-page export has readable label and matching expanded rectangle")

def pointer_and_copy() -> IO(Unit):
  +s = base(7,"page-a")
  +model = state_model(s)
  # The first two rows are a PageNotice; row2 is nonselectable role chrome.
  +header = click(s,600,row_y(2))
  +start = click(s,544,row_y(4))
  +drag = A.changed(UI.event(Move{576,row_y(8)},start))
  +reverse = A.changed(UI.event(Move{544,row_y(4)},click(s,576,row_y(8))))
  +all = UI.select_all(UI.set_edit(s,UI.Edit{2,0,0,False{},0}))
  do IO<Unit>:
    check(String.eq(UI.selection(header),"") && Bool.not(drag_flag(header)),"role chrome never starts text selection")
    check(drag_flag(start) && String.eq(UI.selection(drag),UI.selection(reverse)),"forward and reverse body drag use the same visible scalar interval")
    check(String.eq(A.copied(UI.event(Mouse{824,136,0,True{}},all)),UI.reader(s)),"Copy select-all excludes every hidden tool and evidence part")
    check(Bool.not(String.contains(UI.selection(all),"secret-input")) && Bool.not(String.contains(UI.selection(all),"secret-result")),"selection across collapsed gaps never includes hidden material")
    check(String.eq(Fixture.selected(UI.card_visible_selection(all,C.token(model))),UI.reader(s)),"evidence selection returns matching visible text with separate canonical spans")

def fold_and_bookmark() -> IO(Unit):
  +s = base(7,"page-a")
  +model = state_model(s)
  +part = Fixture.part_key(D.parts(Fixture.document(7)),0)
  +row = row_index(C.focus_row(C.rows(model),part,0))
  +all = UI.select_all(UI.set_edit(s,UI.Edit{2,0,0,True{},0}))
  +opened = click(all,1104,row_y(row))
  +saved = UI.bookmark(UI.select_all(opened))
  +restored = UI.restore(UI.set_reader(UI.init(),"Other","other"),saved)
  +closed = UI.card_fold(opened,C.token(state_model(opened)),part)
  +stale = UI.card_fold(opened,C.token(model),part)
  do IO<Unit>:
    check(U32.is_lt(row,G.reader_rows()) && String.contains(UI.reader(opened),"secret-input"),"actual visible disclosure rectangle opens its tool input")
    check(String.eq(UI.selection(opened),"") && Bool.not(drag_flag(opened)),"disclosure clears stale selection and drag")
    check(String.eq(UI.reader(restored),UI.reader(opened)) && String.eq(UI.selection(restored),UI.reader(opened)),"Back bookmark restores exact document fold state and persistent selection")
    check(Bool.not(drag_flag(restored)) && U32.is_eq(C.revision(state_model(restored)),C.revision(state_model(opened))),"Back clears transient drag and preserves projection revision")
    check(Bool.not(String.contains(UI.reader(closed),"secret-input")) && String.eq(C.canonical(state_model(closed)),C.canonical(model)),"second toggle restores compact page without changing canonical evidence")
    check(String.eq(UI.reader(stale),UI.reader(opened)),"stale fold callback leaves current projection unchanged")
    check(String.eq(UI.selection(UI.card_fold(all,C.token(state_model(all)),D.PartKey{"12","",4294967295,0})),UI.selection(all)),"noncollapsible notice toggle preserves selection and displayed page")

def stale_page_and_keyboard() -> IO(Unit):
  +a = base(7,"snapshot12\0start0\0all")
  +part = Fixture.part_key(D.parts(Fixture.document(7)),0)
  +folded = UI.card_fold(a,C.token(state_model(a)),part)
  +old = C.token(state_model(folded))
  +b = base(8,"snapshot12\0start40\0all")
  +stale_pointer = A.changed(UI.card_pointer(b,old,544,row_y(4),False{},True{}))
  +reader_focus = UI.set_edit(a,UI.Edit{2,0,0,False{},0})
  +focused = key(reader_focus,9)
  +expanded = key(focused,13)
  +collapsed = key(expanded,32)
  do IO<Unit>:
    check(U32.is_eq(C.revision(state_model(b)),C.revision(state_model(folded))) && String.eq(UI.selection(stale_pointer),"") && Bool.not(drag_flag(stale_pointer)),"old page folded revision8 cannot pointer-select new page revision8")
    check(Fixture.is_none(UI.card_visible_selection(b,old)),"old page token cannot copy a new range in same snapshot")
    check(Maybe.is_some(&2,D.PartKey,C.focus(state_model(focused))) && U32.is_eq(UI.focus(focused),2),"Tab reaches first disclosure from reader without changing query")
    check(String.contains(UI.reader(expanded),"secret-input") && Bool.not(String.contains(UI.reader(collapsed),"secret-input")),"Enter and Space activate focused disclosure")
    check(String.eq(UI.query(a),UI.query(collapsed)),"disclosure keyboard activation never edits query")
    check(Bool.not(Maybe.is_some(&2,D.PartKey,C.focus(state_model(key(focused,25))))) && U32.is_eq(UI.focus(key(focused,25)),2),"native NSBackTab25 returns from first disclosure to reader")
    check(Bool.not(Maybe.is_some(&2,D.PartKey,C.focus(state_model(key(collapsed,27))))),"Escape returns from disclosure to ordinary reader focus")

def main() -> IO(Unit):
  do IO<Unit>:
    plain_and_admission()
    pointer_and_copy()
    fold_and_bookmark()
    stale_page_and_keyboard()
