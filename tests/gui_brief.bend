import Base
import ../src/gui.bend as Gui
import ../src/gui_brief.bend as Brief
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/json.bend as Json
import ../src/gui_files.bend as Files
import ../src/gui_relations.bend as Related
import ../src/query.bend as Query
import ./gui_usage.bend as Fixture

def require(+ok: Bool,+label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def origin_value(state: Gui.State) -> Gui.State:
  Gui.State{+db,+dir,+program,+ui,Gui.Selection{+items,+snap,+start,+kind,+args,+filters,+listing},+form,+jobs,+deadline,+serial} = state
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,kind,["transcript-range-v1","7","40","40","5"],filters,listing},form,jobs,deadline,serial}

def origin() -> Gui.State: origin_value(Fixture.origin())

def model_value(value: Maybe<&2,Brief.Model>) -> Brief.Model:
  match value:
    case Some{+model}: model
    case _: Brief.Model{Brief.Anchor{"",0,0,Gui.empty_filters()},"",0,0,None{},Brief.Whole{}}

def model(+state: Gui.State) -> Brief.Model:
  model_value(Gui.brief_model(Gui.navigation(state)))

def entered() -> Gui.State: Gui.brief_enter(origin())

def user_opened_value(state: Gui.State) -> Gui.State:
  Gui.State{+db,+dir,+program,+ui,+selection,Gui.Form{+mode,+search,+source,+blame,+files,+nav,+settings},+jobs,+deadline,+serial} = state
  Gui.State{db,dir,program,ui,selection,Gui.Form{mode,search,source,blame,
    Files.State{"/synthetic/user-opened",Files.Identity{"/synthetic/canonical","/synthetic/user-opened","0123456789012345678901234567890123456789"},
      Files.Directory{"",0,0,0,[]},Files.Source{"",1,0,0,0},Files.Saved{[]}},nav,settings},jobs,deadline,serial}

def user_opened_origin() -> Gui.State: user_opened_value(origin())

def related_origin() -> Gui.State:
  +state = origin()
  Gui.set_navigation(state,Gui.RelatedNavigation{Fixture.origin_selection(),UI.bookmark(Fixture.origin_ui()),"saved origin",None{},None{},[],2,
    Some{Related.Reference{"claude","/synthetic/source.jsonl","3","7","9000"}}})

def rooted() -> Gui.State:
  +state = entered()
  Gui.brief_edit(Gui.replace_ui(state,UI.set_query(Fixture.ui(state),"/synthetic/explicit repository")))

def pending() -> Gui.State: Gui.brief_prepare(rooted())

def text() -> String: "Continuation brief — recorded facts\nRequest: café 中文 🙂\nReview before sharing.\n"

def token() -> String: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

def response(+kind: String) -> Json.Json:
  Fixture.json("{\"protocol\":\"juice-bend-brief-transport-v1\",\"kind\":" ++ Json.quote(kind) ++
    ",\"snapshot\":\"7\",\"start\":\"40\",\"count\":\"5\",\"commitment\":" ++ Json.quote(token()) ++
    ",\"text\":" ++ Json.quote(text()) ++ ",\"utf8_bytes\":" ++ Json.quote(U32.show(Brief.bytes(text()))) ++ "}")

def shown() -> Gui.State:
  +state = pending()
  Gui.read_done(state,Fixture.request(state),Done{response("prepared")})

def accepted(+result: Result<&2,&2,String,Brief.Preview>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def valid(+value: Json.Json) -> Bool: accepted(Brief.decode(value,model(pending())))

def wrong(+key: String,+value: Json.Json,+label: String) -> IO(Unit):
  require(Bool.not(valid(Fixture.replace(response("prepared"),key,value))),label)

def repeat(+n: Nat,+value: String) -> String:
  match n:
    case 0n: ""
    case 1n+rest: value ++ repeat(rest,value)

def sized(+text: String) -> Json.Json:
  Fixture.replace(Fixture.replace(response("prepared"),"text",Json.JString{text}),"utf8_bytes",Json.JString{U32.show(Brief.bytes(text))})

def transport() -> IO(Unit):
  do IO<Unit>:
    require(valid(response("prepared")),"closed prepared response retains exact Unicode UTF8 byte count")
    require(valid(sized(repeat(2048n,"🙂"))) && Bool.not(valid(sized(repeat(2048n,"🙂") ++ "x"))),"8192 UTF8 bytes admit complete emoji scalars but reject an extra byte")
    wrong("protocol",Json.JString{"v0"},"old protocol cannot authorize a preview")
    wrong("snapshot",Json.JString{"8"},"different accepted snapshot is refused")
    wrong("start",Json.JString{"0"},"different physical start is refused")
    wrong("count",Json.JString{"40"},"requested forty is not the exact five-record tail")
    wrong("count",Json.JNumber{"5"},"range string type is exact")
    wrong("utf8_bytes",Json.JString{U32.show(UI.length(text()))},"scalar count cannot masquerade as UTF8 bytes")
    wrong("commitment",Json.JString{"ABCDEF"},"commitment must have exact lowercase SHA256 shape")
    wrong("text",Json.JString{"changed"},"changed text cannot keep the original byte count")
    require(Bool.not(valid(Fixture.duplicate(response("prepared"),"text",Json.JString{text()}))),"duplicate text fields are rejected")
    require(Bool.not(valid(Fixture.duplicate(response("prepared"),"unexpected",Json.JNull{}))),"unknown response fields are rejected")
    require(String.contains(Brief.body(model(pending())),"/synthetic/explicit repository") &&
      String.contains(Brief.body(model(pending())),"\"count\":\"5\"") &&
      String.contains(Brief.body(model(pending())),"\"provider\":\"claude\""),"request binds explicit root exact range and frozen provider")

def action(result: UI.State & UI.Action) -> String:
  (_,action) = result
  match action:
    case UI.Brief{}: "brief"
    case UI.BriefPrepare{}: "prepare"
    case UI.BriefCopy{}: "copy"
    case UI.BriefExport{}: "export"
    case UI.Back{}: "back"
    case UI.Settings{}: "settings"
    case UI.CopyStatus{+text}: "status-copy"
    case _: "other"

def rail_action(row: U32) -> String: action(UI.sidebar_action(Fixture.ui(entered()),row))
def top_action(index: U32) -> String: action(UI.top_action(Fixture.ui(entered()),index))

def routes() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.workspace_side_label(12),"Prepare brief") &&
      String.eq(action(UI.event(Mouse{24,U32.add(G.sidebar_y(9),8),0,True{}},Fixture.ui(origin()))),"brief"),"normal rail pointer reaches Prepare brief")
    require(String.eq(rail_action(0),"back") &&
      String.eq(rail_action(1),"prepare") &&
      String.eq(rail_action(2),"copy") &&
      String.eq(rail_action(3),"export"),"brief rail exposes Back Prepare Copy and Export")
    require(String.eq(top_action(0),"prepare") &&
      String.eq(top_action(1),"copy") &&
      String.eq(top_action(2),"export") &&
      String.eq(top_action(3),"back"),"top controls perform the labeled brief actions")
    require(U32.is_eq(Gui.navigation_phase(Gui.navigation(Gui.brief_enter(Fixture.origin()))),3),"legacy reader without exact count remains readable but cannot start brief")
    require(String.is_empty(UI.query(Fixture.ui(entered()))),"captured repository metadata cannot supply executable Git root")
    require(String.eq(UI.query(Fixture.ui(Gui.brief_enter(user_opened_origin()))),"/synthetic/user-opened"),"previous explicitly opened Files checkout supplies optional root prefill")
    require(U32.is_eq(Brief.phase(model(Gui.brief_prepare(entered()))),0),"empty explicit root refuses preparation")
    require(Gui.capture_suspended(entered()),"automatic capture is held throughout brief navigation")
    require(String.eq(action(UI.status_copy(UI.status_open(Fixture.ui(shown())))),"status-copy"),"status inspector copy has an explicit diagnostic origin independent of reader selection")

def related_back_phase() -> U32:
  Gui.navigation_phase(Gui.navigation(Gui.brief_back(Gui.brief_enter(related_origin()))))

def related_back_selected() -> String:
  Fixture.selected(Gui.brief_back(Gui.brief_enter(related_origin())))

def related_origin_selected() -> String:
  Fixture.selected(related_origin())

def back_selected() -> String: Fixture.selected(Gui.brief_back(shown()))
def origin_selected() -> String: Fixture.selected(origin())
def back_position() -> String: Fixture.position(Fixture.ui(Gui.brief_back(shown())))
def origin_position() -> String: Fixture.position(Fixture.ui(origin()))
def back_query() -> String: UI.query(Fixture.ui(Gui.brief_back(shown())))
def origin_query() -> String: UI.query(Fixture.ui(origin()))
def back_reader() -> String: UI.reader(Fixture.ui(Gui.brief_back(shown())))
def origin_reader() -> String: UI.reader(Fixture.ui(origin()))
def back_capture_suspended() -> Bool: Gui.capture_suspended(Gui.brief_back(shown()))
def shown_reader() -> String: UI.reader(Fixture.ui(shown()))
def shown_status() -> String: UI.status_text(Fixture.ui(shown()))

def bookmarks() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(back_selected(),origin_selected()),"Back restores snapshot range filters and listing including range metadata")
    require(String.eq(back_position(),origin_position()) &&
      String.eq(back_query(),origin_query()) &&
      String.eq(back_reader(),origin_reader()),"Back restores query reader list scroll and Unicode selection")
    require(Bool.not(back_capture_suspended()),"Back releases temporary capture hold")
    require(U32.is_eq(related_back_phase(),2) && String.eq(related_back_selected(),related_origin_selected()),"Back restores a Related target and its prior navigation rather than flattening to History")
    require(String.eq(shown_reader(),text()),"preview displays exact checked backend text")
    require(String.contains(shown_status(),"Review the whole brief"),"preview explicitly requires review before sharing")

def check_reply(+state: Gui.State,+value: Json.Json) -> Result<&2,&2,String,Brief.Preview>:
  Gui.brief_effect_reply(state,Fixture.request(state),Done{value})

def selected() -> Gui.State:
  +state = shown()
  Gui.replace_ui(state,UI.set_edit(Fixture.ui(state),UI.Edit{2,49,42,False{},0}))

def selected_pending() -> Gui.State:
  Gui.brief_selected_checked(selected(),Brief.Selected{42,49},True{})

def effects() -> IO(Unit):
  +copy = Fixture.box(Gui.brief_check(shown(),False{}))
  +export = Fixture.box(Gui.brief_check(shown(),True{}))
  +selected = Fixture.box(selected_pending())
  +edited = Fixture.box(Gui.brief_edit(Gui.replace_ui(Fixture.unbox(copy),UI.set_query(Fixture.ui(Fixture.unbox(copy)),"/different"))))
  +changed_selection = Fixture.box(Gui.replace_ui(Fixture.unbox(selected),UI.set_edit(Fixture.ui(Fixture.unbox(selected)),UI.Edit{2,50,42,False{},0})))
  +retired = Fixture.box(Gui.brief_selection_value(Fixture.unbox(changed_selection),Gui.brief_model(Gui.navigation(Fixture.unbox(changed_selection)))))
  +returned = Fixture.box(Gui.replace_ui(Fixture.unbox(retired),UI.set_edit(Fixture.ui(Fixture.unbox(retired)),UI.Edit{2,49,42,False{},0})))
  do IO<Unit>:
    require(accepted(check_reply(Fixture.unbox(copy),response("checked"))) && accepted(check_reply(Fixture.unbox(export),response("checked"))),"Copy and Export authorize only successful checked response")
    require(Bool.not(accepted(check_reply(Fixture.unbox(copy),response("prepared")))),"prepared response cannot bypass a fresh check")
    require(Bool.not(accepted(check_reply(Fixture.unbox(copy),Fixture.replace(response("checked"),"commitment",Json.JString{"abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"})))),"different full commitment refuses copy")
    require(Bool.not(accepted(check_reply(Fixture.unbox(copy),Fixture.replace(response("checked"),"text",Json.JString{"replacement"})))),"different checked text refuses copy")
    require(accepted(check_reply(Fixture.unbox(selected),response("checked"))),"unchanged scalar selection can copy after full-preview validation")
    require(String.eq(Gui.brief_copy_text(Brief.Preview{token(),text(),Brief.bytes(text())},Gui.brief_model(Gui.navigation(Fixture.unbox(selected)))),UI.span(text(),42,49)),"selected copy uses exact Unicode scalar substring after checking whole preview")
    require(Bool.not(accepted(Gui.brief_effect_reply(Fixture.unbox(changed_selection),Fixture.request(Fixture.unbox(selected)),Done{response("checked")}))),"selection changes during recheck refuse clipboard effect")
    require(Bool.not(accepted(Gui.brief_effect_reply(Fixture.unbox(edited),Fixture.request(Fixture.unbox(copy)),Done{response("checked")}))),"root edits retire prior check identity")
    require(Bool.not(accepted(Gui.brief_effect_reply(Fixture.unbox(returned),Fixture.request(Fixture.unbox(selected)),Done{response("checked")}))),"moving selection away and back cannot revive a retired copy")
    require(Bool.not(accepted(Gui.brief_effect_reply(Gui.brief_back(Fixture.unbox(copy)),Fixture.request(Fixture.unbox(copy)),Done{response("checked")}))),"Back retires pending check without clipboard or export authorization")
    require(String.eq(Brief.selected_text(Brief.Preview{token(),text(),Brief.bytes(text())},Brief.Whole{}),text()),"explicit Copy brief preserves the whole exact text")

def metadata() -> IO(Unit):
  +reply = Fixture.json("{\"snapshot\":\"7\",\"start\":40,\"requested_records\":40,\"selected_records\":5,\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":\"reader\"}")
  +metadata = Brief.range_args(reply,"7",40,["activity","7","source","3","9000","claude","45","0","5"])
  do IO<Unit>:
    require(Brief.range_metadata(reply,"7",40) && U32.is_eq(Brief.selected_count(metadata,"7",40),5),"actual physical tail count stays separate from requested40")
    require(String.eq(String.join(Brief.metadata_base(metadata),"|"),"activity|7|source|3|9000|claude|45|0|5"),"range metadata retains prior verified Tools identity")
    require(U32.is_eq(Brief.selected_count(metadata,"8",40),0) && U32.is_eq(Brief.selected_count(metadata,"7",0),0),"range identity cannot move to another snapshot or page")
    require(U32.is_eq(Brief.selected_count(["transcript-range-v1","7","40","40","0"],"7",40),0),"empty exact range does not enable a brief")
    require(Bool.not(Brief.range_metadata(Fixture.duplicate(reply,"selected_records",Json.JNumber{"5"}),"7",40)),"duplicate range metadata cannot enable brief")
    require(Bool.not(Brief.range_metadata(Fixture.replace(reply,"selected_records",Json.JNumber{"41"}),"7",40)),"actual range cannot exceed requested page size")
    require(Bool.not(Brief.range_metadata(Fixture.replace(reply,"complete_export",Json.JBool{True{}}),"7",40)),"bounded reader cannot claim a complete export")

def main() -> IO(Unit):
  do IO<Unit>:
    transport()
    routes()
    bookmarks()
    effects()
    metadata()
