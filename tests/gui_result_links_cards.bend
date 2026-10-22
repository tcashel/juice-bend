import Base
import ./gui_result_links.bend as Plain
import ./gui_relations.bend as T
import ./result_events.bend as ETest
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/json.bend as J
import ../src/reader_document.bend as Doc
import ../src/reader_cards.bend as Cards
import ../src/reader_wire.bend as Wire
import ../src/gui_command_route.bend as Route

def export_action(value: UI.State & UI.Action) -> Bool:
  (_,action) = value
  match action:
    case UI.Export{}: True{}
    case _: False{}

def card_document(+snapshot: String,+record: String) -> Doc.Document:
  +first : String = "Original café 中文 🙂\n"
  +hidden : String = "RETAINED_RESULT_DETAILS\n"
  +last : String = "Assistant response\n"
  Doc.admit(first ++ hidden ++ last,7,[
    Doc.Part{Doc.PartKey{snapshot,record,0,0},Doc.MessageText{},Doc.Span{0,Doc.length(first)},"user","",False{}},
    Doc.Part{Doc.PartKey{snapshot,record,1,0},Doc.ToolResult{},Doc.Span{Doc.length(first),Doc.length(hidden)},"tool","task",True{}},
    Doc.Part{Doc.PartKey{snapshot,record,2,0},Doc.MessageText{},Doc.Span{U32.add(Doc.length(first),Doc.length(hidden)),Doc.length(last)},"assistant","",False{}}])

def token_value(value: Maybe<&2,Cards.Model>) -> Cards.Token:
  match value:
    case Some{model}: Cards.token(model)
    case None{}: Cards.Token{"missing",0,0}

def token(ui: UI.State) -> Cards.Token: token_value(UI.card_model(ui))

def unfold_origin(opened: Bool,+ui: UI.State) -> UI.State:
  match opened:
    case True{}: UI.card_fold(ui,token(ui),Doc.PartKey{"7","41",1,0})
    case False{}: ui

def card_ui(opened: Bool) -> UI.State:
  UI.set_edit(unfold_origin(opened,UI.set_document(Plain.origin_ui(),"Tools | snapshot 7",card_document("7","41"),"original exact page")),
    UI.Edit{2,2,20,False{},0})

# Each fixture transition stores its full controller State in one recursive
# slot. Only the production transition being exercised unboxes that state.
def card_origin(opened: Bool) -> List<&2,Gui.State>:
  [Gui.replace_ui(Plain.origin(),card_ui(opened))]

def enter_box(value: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match value:
    case Con{state,Nil{}}: [Gui.child_enter(state)]
    case _: []

def open_box(value: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match value:
    case Con{state,Nil{}}: [Gui.child_open(state,0)]
    case _: []

def apply_box(value: List<&2,Gui.State>,reply: J.Json) -> List<&2,Gui.State>:
  match value:
    case Con{state,Nil{}}: [Plain.apply(state,reply)]
    case _: []

def card_events(opened: Bool) -> List<&2,Gui.State>:
  apply_box(enter_box(card_origin(opened)),Plain.events())

def card_candidates(opened: Bool) -> List<&2,Gui.State>:
  apply_box(open_box(card_events(opened)),Plain.candidates())

def card_target_page() -> J.Json:
  ETest.json("{\"snapshot\":\"9\",\"start\":0,\"requested_records\":40,\"selected_records\":2,\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":" ++
    J.quote(Doc.text(card_document("9","0"))) ++ ",\"reader_view\":" ++ Wire.encode(card_document("9","0")) ++ "}")

def card_target(opened: Bool) -> List<&2,Gui.State>:
  apply_box(open_box(card_candidates(opened)),card_target_page())

def card_restored(opened: Bool) -> List<&2,Gui.State>:
  Plain.back_box(Plain.back_box(Plain.back_box(card_target(opened))))

def ui_box(value: List<&2,Gui.State>) -> UI.State:
  match value:
    case Con{state,Nil{}}: T.ui(state)
    case _: UI.init()

def phase_box(value: List<&2,Gui.State>) -> U32:
  match value:
    case Con{state,Nil{}}: Gui.navigation_phase(Gui.navigation(state))
    case _: 999

def request_box(value: List<&2,Gui.State>) -> Gui.Request:
  match value:
    case Con{state,Nil{}}: T.request(state)
    case _: Gui.Request{0,[],"missing",0,"missing"}

def canonical_value(value: Maybe<&2,Cards.Model>) -> String:
  match value:
    case Some{model}: Cards.canonical(model)
    case None{}: "missing"

def token_text(value: Cards.Token) -> String:
  Cards.Token{page,epoch,revision} = value
  page ++ "|" ++ U32.show(epoch) ++ "|" ++ U32.show(revision)

def card_observation(state: Gui.State) -> String:
  Gui.State{_,_,_,+ui,selection,Gui.Form{_,search,_,_,_,_,_},_,_,_} = state
  T.selection_observation(selection) ++ "\n" ++ T.ui_observation(ui) ++ "\n" ++ search ++ "\n" ++
    UI.selection(ui) ++ "\n" ++ canonical_value(UI.card_model(ui)) ++ "\n" ++ token_text(token(ui))

def card_observation_box(value: List<&2,Gui.State>) -> String:
  match value:
    case Con{state,Nil{}}: card_observation(state)
    case _: "MISSING_BOXED_CHILD_CARD_STATE"

def restored_check(+opened: Bool) -> IO(Unit):
  do IO<Unit>:
    actual : String <- IO.pure(String,card_observation_box(card_restored(opened)))
    T.require(String.eq(actual,card_observation_box(card_origin(opened))),"three Back transitions restore structured canonical text folds token exact selection and list position")

def stale_reply_box(value: List<&2,Gui.State>,request: Gui.Request) -> List<&2,Gui.State>:
  match value:
    case Con{state,Nil{}}: [Gui.read_current(state,request,Gui.Reply{Done{card_target_page()}},False{})]
    case _: []

def pointer_input(value: UI.State & UI.Action) -> String:
  (state,_) = value
  T.input(state)

def no_old_pointer() -> Bool:
  String.eq(T.input(ui_box(card_target(False{}))),
    pointer_input(UI.card_pointer(ui_box(card_target(False{})),token(card_ui(False{})),545,200,False{},True{})))

def chrome_checks() -> IO(Unit):
  do IO<Unit>:
    T.require(export_action(UI.mouse(Plain.origin_ui(),552,96,True{})),"Child entry preserves the existing Export captured page hit target")
    T.require(U32.is_eq(Route.read_kind("result-link-events"),4) && U32.is_eq(Route.read_kind("result-link-page"),4),"both Child workers use the existing bounded scoped read lane")
    T.require(Bool.not(UI.child_entry_visible(UI.set_results(Plain.origin_ui(),UI.LibraryUsageResults{6,1}))),"Library capture chrome does not advertise an unavailable nested Child action")

def navigation_checks() -> IO(Unit):
  do IO<Unit>:
    T.require(U32.is_eq(phase_box(card_events(False{})),10) &&
      U32.is_eq(Gui.navigation_phase(Gui.navigation(Gui.library_enter(Plain.origin()))),9),"Child and Library Usage navigation phases remain distinct")
    T.require(Bool.not(String.contains(UI.reader(card_ui(False{})),"RETAINED_RESULT_DETAILS")) &&
      String.contains(UI.reader(card_ui(True{})),"RETAINED_RESULT_DETAILS"),"origin fixture exercises both collapsed and expanded retained result text")
    T.require(Maybe.is_some(&2,Cards.Model,UI.card_model(ui_box(card_target(False{})))) &&
      Bool.not(String.contains(UI.reader(ui_box(card_target(False{}))),"RETAINED_RESULT_DETAILS")),"matching child response reaches the current typed reader with hidden details excluded")
    T.require(String.contains(canonical_value(UI.card_model(ui_box(card_target(False{})))),"RETAINED_RESULT_DETAILS"),"child canonical evidence still includes collapsed details for captured export")

def restoration_checks() -> IO(Unit):
  do IO<Unit>:
    T.require(no_old_pointer(),"original structured page token cannot select text in the newly loaded child page")
    restored_check(False{})
    restored_check(True{})
    T.require(String.eq(card_observation_box(stale_reply_box(card_restored(False{}),request_box(open_box(card_candidates(False{}))))),card_observation_box(card_origin(False{}))),"late child response after Back cannot replace the restored structured origin")

def main() -> IO(Unit):
  do IO<Unit>:
    chrome_checks()
    navigation_checks()
    restoration_checks()
