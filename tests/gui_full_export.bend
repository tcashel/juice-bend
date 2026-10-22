import Base
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/json.bend as Json
import ../src/query.bend as Query
import ./gui_usage.bend as Fixture
import ./gui_brief.bend as BriefFixture

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def action(result: UI.State & UI.Action) -> String:
  (_,value) = result
  match value:
    case UI.WholeExport{}: "whole"
    case UI.ContainerExport{}: "container"
    case UI.Export{}: "bounded"
    case UI.Paste{}: "paste"
    case UI.SettingsInterval{86400}: "interval"
    case UI.NoAction{}: "none"
    case _: "other"

def next_ui(result: UI.State & UI.Action) -> UI.State:
  (state,_) = result
  state

def rail(index: U32) -> String:
  action(UI.event(Mouse{24,U32.add(G.sidebar_y(index),8),0,True{}},Fixture.origin_ui()))

def routes() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(rail(13),"whole") && String.eq(UI.side_label(False{},14,False{}),"Export full JSONL"),"native compact sidebar row13 points to full JSONL export")
    require(String.eq(action(UI.event(Mouse{120,U32.add(G.sidebar_y(14),8),0,True{}},Fixture.origin_ui())),"container") && String.eq(UI.side_label(False{},16,False{}),"Export archive"),"native compact sidebar row14 points to compressed container export")
    require(String.eq(action(UI.top_action(Fixture.origin_ui(),4)),"bounded") && String.eq(action(UI.key_down(Fixture.origin_ui(),101,True{})),"bounded"),"toolbar and Command E retain bounded evidence export")
    require(String.eq(action(UI.key_down(UI.set_edit(Fixture.origin_ui(),UI.Edit{0,0,0,False{},0}),118,True{})),"paste"),"Command V remains the ordinary native paste action")
    require(String.eq(UI.selection(next_ui(UI.key_down(Fixture.origin_ui(),97,True{}))),UI.reader(Fixture.origin_ui())),"Command A still selects the entire reader independently of sidebar export")
    require(String.eq(action(UI.sidebar_settings(Fixture.origin_ui(),14)),"interval") && String.eq(UI.selection(next_ui(UI.event(Mouse{1112,136,0,True{}},UI.set_results(Fixture.origin_ui(),UI.SettingsResults{0,0,"Resume",True{}})))),UI.reader(Fixture.origin_ui())),"Settings keeps daily refresh and toolbar Select all")
    require(String.eq(UI.brief_side_label(4),"Paste root") && String.eq(UI.brief_side_label(6),"Select all"),"Brief sidebar retains its separate text controls")
    require(String.contains(Gui.write_start_text(35),"including all records outside current filters") && String.contains(Gui.write_start_text(36),"Plain captures have no archive container"),"running statuses disclose complete capture scope and plain-source refusal")

def selected_as(state: Gui.State,snapshot: String,kind: U32,mode: U32) -> Gui.State:
  Gui.State{db,dir,program,ui,Gui.Selection{items,_,start,_,args,filters,listing},Gui.Form{_,search,source,blame,files,navigation,settings},jobs,deadline,serial} = state
  Gui.State{db,dir,program,ui,Gui.Selection{items,snapshot,start,kind,args,filters,listing},Gui.Form{mode,search,source,blame,files,navigation,settings},jobs,deadline,serial}

def listing_newer(state: Gui.State) -> Gui.State:
  Gui.State{db,dir,program,ui,Gui.Selection{_,snapshot,start,kind,args,filters,listing},form,jobs,deadline,serial} = state
  Gui.State{db,dir,program,ui,Gui.Selection{[Gui.Item{"8",0,"new latest","codex","/unrelated","4",Gui.empty_filters()}],snapshot,start,kind,args,filters,listing},form,jobs,deadline,serial}

def with_serial(state: Gui.State,serial: U32) -> Gui.State:
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,_} = state
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,serial}

def writer_absent(state: Gui.State) -> Bool:
  Gui.State{_,_,_,_,_,_,Gui.Jobs{_,_,_,writer,_},_,_} = state
  match writer:
    case None{}: True{}
    case Some{_}: False{}

def request_text(request: Gui.Request) -> String:
  Gui.Request{kind,args,snapshot,start,title} = request
  U32.show(kind) ++ "|" ++ String.join(args,"|") ++ "|" ++ snapshot ++ "|" ++ U32.show(start) ++ "|" ++ title

def whole() -> Gui.Request: Gui.full_export_request(Fixture.origin(),123n,False{})
def container() -> Gui.Request: Gui.full_export_request(Fixture.origin(),123n,True{})
def path(archive: Bool) -> String:
  "/tmp/juice-bend-gui-usage/capture-7-123-0" ++ Bool.pick(String,archive,".jsonl.zst",".jsonl")

def eligibility() -> IO(Unit):
  do IO<Unit>:
    require(Gui.full_export_available(Fixture.origin()),"opened immutable transcript permits complete capture export")
    require(Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"",3,0))) && Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"07",3,0))),"missing and noncanonical snapshot identities cannot authorize exports")
    require(Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"9223372036854775808",3,0))),"export snapshot cannot exceed signed SQLite identity range")
    require(Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"7",0,0))) && Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"7",4,0))),"list-only and Why views cannot silently export a complete capture")
    require(Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"7",3,1))) && Bool.not(Gui.full_export_available(selected_as(Fixture.origin(),"7",3,2))),"Settings and Files modes cannot reuse hidden capture selection")
    require(Bool.not(Gui.full_export_available(Gui.usage(Fixture.origin()))) && Bool.not(Gui.full_export_available(BriefFixture.entered())),"Usage and Brief subviews require returning to their original transcript")
    require(Bool.not(Gui.full_export_available(BriefFixture.related_origin())),"nested Related origin cannot be confused with the opened History transcript")
    require(String.eq(request_text(whole()),"35|export-all|7|" ++ path(False{}) ++ "|7|0|" ++ path(False{})),"full JSONL request pins exact snapshot and unique app-data path without scope or live-source arguments")
    require(String.eq(request_text(container()),"36|export-container|7|" ++ path(True{}) ++ "|7|0|" ++ path(True{})),"archive request pins exact snapshot and exact container format")
    require(String.eq(request_text(Gui.full_export_request(listing_newer(Fixture.origin()),123n,False{})),request_text(whole())),"refreshing list to newer snapshot8 cannot substitute opened snapshot7")
    require(Bool.not(String.eq(request_text(Gui.full_export_request(Fixture.origin(),124n,False{})),request_text(whole()))),"operation clock contributes to a new no-clobber destination")
    require(Bool.not(String.eq(request_text(Gui.full_export_request(with_serial(Fixture.origin(),1),123n,False{})),request_text(whole()))),"same-millisecond operations receive distinct serial destinations")
    require(String.starts_with(String.join(Gui.export_args(3,"7",40,Fixture.filters(),"shown","/tmp/evidence.md"),"|"),"export-range-scope|7|40|40|claude|"),"existing bounded export still carries its original forty-record provider scope")

def response(+archive: Bool) -> Json.Json:
  Fixture.json("{\"path\":" ++ Json.quote(path(archive)) ++ ",\"snapshot\":\"7\",\"format\":" ++
    Json.quote(Bool.pick(String,archive,"retained_zstd_container","retained_raw_bytes")) ++ ",\"byte_space\":" ++
    Json.quote(Bool.pick(String,archive,"compressed_container_bytes","logical_source_bytes")) ++
    ",\"complete_export\":true,\"verification\":" ++ Json.quote(Bool.pick(String,archive,"complete_owned_container","complete_accepted_extent")) ++ "}")

def accepted(value: Json.Json) -> Bool:
  Gui.full_export_response(35,["export-all","7",path(False{})],value)

def wrong(key: String,value: Json.Json,label: String) -> IO(Unit):
  require(Bool.not(accepted(Fixture.replace(response(False{}),key,value))),label)

def acknowledgments() -> IO(Unit):
  do IO<Unit>:
    require(accepted(response(False{})) && Gui.full_export_response(36,["export-container","7",path(True{})],response(True{})),"exact logical and compressed acknowledgments retain distinct verified byte spaces")
    wrong("snapshot",Json.JString{"8"},"newer snapshot acknowledgment cannot confirm the requested old capture")
    wrong("snapshot",Json.JNumber{"7"},"snapshot response preserves its exact string type")
    wrong("path",Json.JString{"/tmp/different.jsonl"},"different destination cannot be reported as the requested export")
    wrong("format",Json.JString{"retained_zstd_container"},"compressed bytes cannot masquerade as logical JSONL")
    wrong("byte_space",Json.JString{"compressed_container_bytes"},"wrong byte space cannot confirm logical export")
    wrong("complete_export",Json.JBool{False{}},"bounded export cannot be promoted to complete")
    wrong("complete_export",Json.JString{"true"},"complete-export response flag must be a true boolean")
    wrong("verification",Json.JString{"selected_records_only"},"range verification cannot be reported as complete verification")
    require(Bool.not(accepted(Fixture.duplicate(response(False{}),"snapshot",Json.JString{"7"}))),"duplicate acknowledgment fields are rejected")
    require(Bool.not(accepted(Fixture.duplicate(response(False{}),"unexpected",Json.JNull{}))),"unknown acknowledgment fields are rejected")
    require(Bool.not(Gui.full_export_response(35,["export-container","7",path(True{})],response(True{}))),"writer kind cannot authorize a different operation")

def completed(+archive: Bool) -> Gui.State:
  Gui.write_done(listing_newer(Fixture.origin()),Bool.pick(Gui.Request,archive,container(),whole()),Gui.Reply{Done{response(archive)}})

def effects() -> IO(Unit):
  +newer = Fixture.box(selected_as(listing_newer(Fixture.origin()),"8",3,0))
  +changed = Fixture.box(Gui.write_done(Fixture.unbox(newer),whole(),Gui.Reply{Done{response(False{})}}))
  +failed = Fixture.box(Gui.write_done(Fixture.origin(),container(),Gui.Reply{Fail{"Snapshot is not a captured archive"}}))
  +bad = Fixture.box(Gui.write_done(Fixture.origin(),whole(),Gui.Reply{Done{Fixture.replace(response(False{}),"snapshot",Json.JString{"8"})}}))
  do IO<Unit>:
    require(String.eq(Fixture.selected(completed(False{})),Fixture.selected(listing_newer(Fixture.origin()))) && String.eq(UI.reader(Fixture.ui(completed(False{}))),UI.reader(Fixture.origin_ui())),"successful full export preserves opened capture, filters, refreshed listing and reader")
    require(String.eq(Fixture.position(Fixture.ui(completed(True{}))),Fixture.position(Fixture.origin_ui())),"container export completion preserves caret selection and scroll")
    require(String.contains(UI.status_text(Fixture.ui(completed(False{}))),"including ALL records outside current filters") && String.contains(UI.status_text(Fixture.ui(completed(True{}))),"complete compressed archive"),"completion clearly distinguishes complete capture scope and exported format")
    require(String.eq(Fixture.selected(Fixture.unbox(changed)),Fixture.selected(Fixture.unbox(newer))) && String.contains(UI.status_text(Fixture.ui(Fixture.unbox(changed))),"snapshot 7"),"finishing snapshot7 export cannot replace a subsequently opened snapshot8")
    require(String.contains(UI.status_text(Fixture.ui(Fixture.unbox(failed))),"Snapshot is not a captured archive") && String.eq(Fixture.selected(Fixture.unbox(failed)),Fixture.selected(Fixture.origin())),"plain-source archive refusal stays an error and preserves reader identity")
    require(String.contains(UI.status_text(Fixture.ui(Fixture.unbox(bad))),"success is not confirmed"),"mismatched worker acknowledgment does not claim export success")

def guarded_actions() -> IO(Unit):
  do IO<Unit>:
    +blocked : Gui.State <- Gui.full_export(selected_as(Fixture.origin(),"",0,0),False{})
    require(String.contains(UI.status_text(Fixture.ui(blocked)),"Open a captured transcript") && writer_absent(blocked),"actual empty-reader action returns an explanation without queuing a worker")
    +nested : Gui.State <- Gui.full_export(BriefFixture.entered(),True{})
    require(String.contains(UI.status_text(Fixture.ui(nested)),"including those outside current filters"),"actual nested action refuses full export with complete-scope disclosure")

def main() -> IO(Unit):
  do IO<Unit>:
    routes()
    eligibility()
    acknowledgments()
    effects()
    guarded_actions()
    IO.print("Native full-capture export routing tests passed")
