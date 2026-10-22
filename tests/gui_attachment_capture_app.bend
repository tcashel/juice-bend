import Base
import ../src/gui.bend as G
import ../src/ui.bend as UI
import ../src/gui_attachments.bend as A
import ../src/gui_attachment_capture.bend as C
import ../src/gui_attachment_folders.bend as D
import ../src/attachment_capture_output.bend as O
import ../src/attachment_asset_types.bend as T
import ../src/json.bend as J
import ../src/gui_settings.bend as Settings
import ./gui_settings.bend as S
import ./gui_attachments.bend as Existing
import ./gui_attachments_model.bend as M
import ./gui_attachment_capture.bend as F
import ./attachment_asset_types.bend as Types
import ./polish.bend as Painter

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def origin_from(state: G.State) -> G.State:
  G.State{db,dir,program,ui,G.Selection{items,_,_,_,_,filters,listing},form,jobs,deadline,serial} = state
  G.State{db,dir,program,ui,G.Selection{items,"1",1,3,["transcript-range-v1","1","1","40","1"],filters,listing},form,jobs,deadline,serial}
def origin() -> G.State: origin_from(S.ready())
def inventory() -> J.Json:
  +base = F.inventory("local_path")
  J.JObject{[J.JField{"kind",J.JString{"attachment_inventory"}},J.JField{"profile",J.JString{A.profile()}},
    J.JField{"capture",J.field(base,"capture")},J.JField{"records",J.field(base,"records")},
    J.JField{"page",M.json("{\"start\":1,\"requested\":1,\"selected\":1,\"verified\":1,\"next\":null,\"covers_snapshot_record_range\":false,\"complete_extraction_records\":1,\"partial_extraction_records\":0,\"returned_occurrences\":3}")},
    J.JField{"verification",J.JString{"Selected records verified"}}]}
def entered() -> G.State: G.attachment_enter(origin())
def loaded() -> G.State:
  +state = entered()
  G.read_done(state,Existing.wanted(state),Done{inventory()})
def picked() -> G.State:
  +state = loaded()
  G.attachment_pick(state,3,G.attachment_model(G.navigation(state)))
def inspecting() -> G.Request:
  G.Request{43,C.inspect_args(C.Target{J.field(inventory(),"capture"),F.key(),"document","local_path"}),"2",0,"Retained attachment"}
def pending_value(value: List<&2,G.Request>) -> G.Request:
  match value:
    case [request]: request
    case _: G.Request{0,[],"",0,""}
def pending(state: G.State) -> G.Request: pending_value(G.attachment_work(G.navigation(state)))
def complete(value: O.result()) -> J.Json:
  match value:
    case Done{text}: M.json(text)
    case Fail{_}: J.JNull{}
def retained() -> J.Json: complete(O.asset("retained",F.receipt(),None{},O.NoMutation{}))
def ready() -> G.State:
  +state = picked()
  G.read_done(state,pending(state),Done{retained()})
def missing() -> G.State:
  +state = picked()
  G.read_done(state,pending(state),Done{F.error(O.NoMutation{})})
def external(state: G.State) -> C.Model: G.attachment_external(G.navigation(state))
def chosen() -> G.State:
  +state = missing()
  G.attachment_overlay(state,C.choose(external(state),Types.root(99)),[])
def folder_entered() -> G.State: G.attachment_folder_enter(chosen())
def folders() -> G.State:
  +state = folder_entered()
  G.read_done(state,Existing.wanted(state),Done{complete(O.page(F.folder_page()))})
def root_model(value: Maybe<&2,D.Model>) -> D.Model:
  match value:
    case Some{model}: model
    case None{}: D.initial()
def folders_model(state: G.State) -> D.Model: root_model(G.attachment_folder_model(G.navigation(state)))
def folder_writing() -> G.State:
  +state = folders()
  G.attachment_folder_update(G.attachment_folder_clear(state),D.writing(folders_model(state),99,["attachment-root-disable","1"]))
def folder_request() -> G.Request: G.attachment_folder_request(folders_model(folder_writing()),47)
def wrong_args(value: G.Request) -> G.Request:
  G.Request{kind,_,nonce,start,title} = value
  G.Request{kind,["captured-attachment","1","1","1",F.path()],nonce,start,title}
def capture_enabled(ui: UI.State) -> Bool:
  UI.State{UI.Content{_,_,_,_,_,_,_,results,_},_,_,_} = ui
  UI.attachment_available(results,6)
def root_disabled() -> J.Json:
  complete(O.root_ack("disable",T.RootEvidence{"1","/synthetic/one","2",False{}}))
def export_waiting() -> G.State:
  +state = ready()
  G.attachment_overlay(state,external(state),[G.Request{48,["export-captured-attachment","1","1","2",F.path(),"/synthetic/saved.bin"],"100",0,"Export retained attachment"}])
def exported(path: String) -> J.Json: complete(O.asset("exported",F.receipt(),Some{path},O.NoMutation{}))
def status(state: G.State) -> String: UI.status_text(S.ui(state))
def model_and_navigation() -> IO(Unit):
  do IO<Unit>:
    require(A.page_valid(inventory(),A.Anchor{"1",1,1},1),"independent local-reference inventory validates exact frozen range")
    require(U32.is_eq(A.phase(Existing.model(loaded())),2),"native GUI applies complete local attachment inventory")
    require(G.attachment_work_current(pending(picked()),G.attachment_work(G.navigation(picked()))),"local row selection creates one exact retained-inspect request")
    require(String.eq(S.wanted(picked()),"captured-attachment|1|1|2|" ++ F.path()),"UI derives target only from frozen snapshot physical record reference and structural path")
    require(Bool.not(C.can_export(external(picked()))) && Bool.not(C.can_capture(external(picked()))),"pending retained inspection grants no capture or export authority")
    require(Bool.not(C.can_export(external(G.read_done(picked(),Existing.request_with_nonce(pending(picked())),Done{retained()})))),"stale retained nonce cannot enable export")
    require(Bool.not(C.can_export(external(G.read_done(picked(),wrong_args(pending(picked())),Done{retained()})))),"different occurrence args cannot enable export")
    require(C.can_export(external(ready())) && Maybe.is_some(&2,T.Receipt,G.attachment_retained(ready())),"matched exact retained receipt enables owned export and preview admission")
    require(String.contains(UI.reader(S.ui(ready())),"Retained asset") && Bool.not(String.contains(UI.reader(S.ui(ready())),"Byte export is unavailable")),"retained local detail presents availability without obsolete uncaptured text")
    require(C.can_capture(external(chosen())),"known uncaptured occurrence and explicit enabled root enable Capture file")
    require(U32.is_eq(A.selected_index(Existing.model(G.attachment_pick(picked(),1,G.attachment_model(G.navigation(picked()))))),3),"pending inspect locks selected identity")
    require(String.eq(S.observation(G.attachment_back(ready())),S.observation(origin())),"Back from retained detail restores exact original reader filters selection and listing")
    require(String.eq(S.observation(G.read_done(G.attachment_back(picked()),pending(picked()),Done{retained()})),S.observation(origin())),"retained reply after Back cannot replace reader")

def folder_navigation() -> IO(Unit):
  do IO<Unit>:
    require(U32.is_eq(G.navigation_phase(G.navigation(folder_entered())),8),"Folders opens bounded explicit policy view")
    require(String.eq(S.wanted(folder_entered()),"attachment-roots|0|40"),"folder view asks only for bounded policy rows without source scanning")
    require(String.eq(UI.query_label(S.ui(folder_entered())),"Explicit attachment capture folder path") && U32.is_eq(UI.focus(S.ui(folder_entered())),0),"folder path input is visible and focused")
    require(String.eq(S.observation(G.attachment_folder_back(folders())),S.observation(chosen())),"folder Back restores exact attachment view and selection")
    require(C.can_capture(external(G.attachment_folder_choose(folders(),G.attachment_folder_model(G.navigation(folders()))))),"Use selects exact completed enabled root for original occurrence")
    require(Bool.not(C.valid_root(C.chosen(external(G.attachment_folder_back(folder_writing()))))),"starting folder mutation clears previous new-read authorization before Back")
    require(Bool.not(capture_enabled(S.ui(G.attachment_folder_back(folder_writing())))) && String.contains(UI.reader(S.ui(G.attachment_folder_back(folder_writing()))),"No capture folder selected"),"Back after policy mutation repaints disabled Capture and cleared folder disclosure")
    require(String.eq(S.observation(G.attachment_back(G.attachment_folder_back(folders()))),S.observation(origin())),"nested folder and attachment Back preserve original filtered reader")
    require(U32.is_eq(D.phase(folders_model(G.write_done(folder_writing(),folder_request(),G.Reply{Done{root_disabled()}}))),1),"exact root mutation ack queues policy reload instead of reusing old enabled row")
    require(U32.is_eq(D.phase(folders_model(G.write_done(folder_writing(),folder_request(),G.Reply{Done{M.replace(root_disabled(),"operation",J.JString{"enable"})}}))),2),"wrong root ack retires stale policy page")
    require(Bool.not(D.can_choose(folders_model(G.write_done(folder_writing(),folder_request(),G.Reply{Fail{"child ended"}})))),"fatal folder child leaves no stale Use authority")
    require(String.eq(S.observation(G.write_done(G.attachment_folder_back(folder_writing()),folder_request(),G.Reply{Done{root_disabled()}})),S.observation(G.attachment_folder_back(folder_writing()))),"late folder writer reply cannot disturb restored attachment")

def retained_exports() -> IO(Unit):
  do IO<Unit>:
    require(String.contains(status(G.write_done(export_waiting(),pending(export_waiting()),G.Reply{Done{exported("/synthetic/saved.bin")}})),"Saved retained attachment bytes"),"retained export ack requires original receipt and exact destination")
    require(String.contains(status(G.write_done(export_waiting(),pending(export_waiting()),G.Reply{Done{exported("/synthetic/other.bin")}})),"success is not confirmed"),"different retained export destination remains uncertain")
    require(C.can_export(external(G.write_done(export_waiting(),pending(export_waiting()),G.Reply{Fail{"child ended"}}))),"uncertain export does not discard already retained asset")
    require(String.eq(S.observation(G.write_done(G.attachment_back(export_waiting()),pending(export_waiting()),G.Reply{Done{exported("/synthetic/saved.bin")}})),S.observation(origin())),"export completion after Back cannot replace original reader")

def action(value: UI.State & UI.Action) -> U32:
  (_,action) = value
  Painter.kind(action)
def controls() -> IO(Unit):
  +s = UI.set_results(UI.init(),UI.AttachmentCaptureResults{2,True{},False{},False{},True{},True{}})
  +f = UI.set_results(UI.init(),UI.AttachmentFoldersResults{2,True{},False{},True{},False{},False{}})
  do IO<Unit>:
    require(U32.is_eq(action(UI.event(Mouse{552,88,0,True{}},s)),51),"Folders toolbar target dispatches explicit policy view")
    require(U32.is_eq(action(UI.event(Mouse{16,312,0,True{}},s)),52),"Capture file target dispatches exact selected occurrence action")
    require(U32.is_eq(action(UI.event(Mouse{432,88,0,True{}},s)),50),"Open image toolbar target shares preview action")
    require(U32.is_eq(action(UI.event(Mouse{168,88,0,True{}},f)),56),"Use folder toolbar target dispatches selection only")
    require(U32.is_eq(action(UI.event(Mouse{312,88,0,True{}},f)),53),"Add folder toolbar target dispatches explicit path registration")
    require(U32.is_eq(action(UI.event(Mouse{432,88,0,True{}},f)),0),"already enabled root cannot dispatch hidden Enable")
    require(U32.is_eq(action(UI.event(Mouse{552,88,0,True{}},f)),55),"Disable folder toolbar target is distinct from Use and Add")

def discovery_report(value: J.Json) -> String:
  Settings.last(G.settings_model(G.write_capture_ok(S.ready(),0,value,"",True{})))
def discovery_status() -> IO(Unit):
  do IO<Unit>:
    +scanning : String = discovery_report(M.json("{\"attempted\":0,\"succeeded\":0,\"failed\":0,\"discovery\":{\"status\":\"scanning\",\"files\":42}}"))
    require(String.contains(scanning,"This bounded batch does not establish full-library health.") && String.contains(scanning,"Discovery continues across refreshes; found 42 files"),"capture report retains batch limits and exposes resumable discovery progress")
    require(String.contains(discovery_report(M.json("{\"discovery\":{\"status\":\"cancelled\",\"files\":0}}")),"cancelled") && String.contains(discovery_report(M.json("{\"discovery\":{\"status\":\"cancelled\",\"files\":0}}")),"changed"),"capture report explains changed discovery pass instead of hiding cancellation")

def main() -> IO(Unit):
  do IO<Unit>:
    model_and_navigation()
    folder_navigation()
    retained_exports()
    controls()
    discovery_status()
