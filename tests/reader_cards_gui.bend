import Base
import ../src/gui.bend as Gui
import ../src/gui_brief.bend as Brief
import ../src/ui.bend as UI
import ../src/json.bend as Json
import ../src/reader_wire.bend as Wire
import ../src/reader_document.bend as D
import ../src/reader_cards.bend as C
import ./gui.bend as Fixture
import ./reader_cards.bend as Cards

def json_result(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def payload(view: String) -> Json.Json:
  json_result(Json.parse("{\"snapshot\":\"12\",\"start\":0,\"requested_records\":40,\"selected_records\":40,\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":" ++
    Json.quote(D.text(Cards.document(7))) ++ view ++ "}"))

def request() -> Gui.Request:
  Gui.Request{3,["session-scope","12","0","40","","","",""],"12",0,"Transcript | pinned snapshot12"}

def loaded() -> Gui.State:
  Gui.transcript_done(Fixture.state(),request(),Done{payload(",\"reader_view\":" ++ Wire.encode(Cards.document(7)))})

def model_revision(value: Maybe<&2,C.Model>) -> U32:
  match value:
    case Some{model}: C.revision(model)
    case None{}: 999

def admission() -> IO(Unit):
  +state = loaded()
  +ui = Fixture.ui(state)
  do IO<Unit>:
    Cards.check(Brief.range_metadata(payload(",\"reader_view\":" ++ Wire.encode(Cards.document(7))),"12",0),"typed optional metadata preserves strict admitted transcript envelope")
    Cards.check(Maybe.is_some(&2,C.Model,UI.card_model(ui)) && U32.is_eq(model_revision(UI.card_model(ui)),2),"accepted transcript binds descriptors to current GUI request epoch")
    Cards.check(String.eq(Fixture.snapshot(state),"12") && String.contains(UI.reader(ui),"partial_content") && Bool.not(String.contains(UI.reader(ui),"secret-input")),"GUI snapshot identity and warnings survive default compact reader")

def restored(+state: Gui.State,+expected: String) -> IO(Unit):
  Cards.check(String.eq(UI.reader(Fixture.ui(state)),expected) && String.eq(UI.selection(Fixture.ui(state)),expected),"actual Settings Back restores boxed card document folds and selection")

def bookmark() -> IO(Unit):
  +state = loaded()
  +ui = Fixture.ui(state)
  restored(Gui.settings_leave(Gui.settings(Gui.replace_ui(state,UI.select_all(UI.set_edit(ui,UI.Edit{2,0,0,True{},0}))))),UI.reader(ui))

def fallback(+metadata: String,label: String) -> IO(Unit):
  +state = Gui.transcript_done(Fixture.state(),request(),Done{payload(metadata)})
  Cards.check(Bool.not(Maybe.is_some(&2,C.Model,UI.card_model(Fixture.ui(state)))) && String.eq(UI.reader(Fixture.ui(state)),D.text(Cards.document(7))),label)

def export_contract() -> IO(Unit):
  Cards.check(String.eq(String.join(Gui.export_args(3,"12",0,Gui.empty_filters(),UI.reader(Fixture.ui(loaded())),"/synthetic/export.md"),"|"),
    "export-range-scope|12|0|40|||||/synthetic/export.md"),"captured-page export remains backend evidence range including folded details")

def main() -> IO(Unit):
  do IO<Unit>:
    admission()
    bookmark()
    fallback("","old text-only worker reply remains complete canonical plain reader")
    fallback(",\"reader_view\":{\"version\":9}","invalid optional metadata falls back without dropping captured text")
    export_contract()
