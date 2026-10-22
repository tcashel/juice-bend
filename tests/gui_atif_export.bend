import Base
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/json.bend as J
import ../src/atif_command.bend as C
import ../src/atif_types.bend as T
import ./gui_usage.bend as F
import ./gui_full_export.bend as Full
import ./gui_brief.bend as Brief
import ./window_layout.bend as Window
import ./tab_readability.bend as Tiles
import ./polish.bend as Polish

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def action(value: UI.State & UI.Action) -> String:
  (_,action) = value
  match action:
    case UI.AtifExport{}: "atif"
    case UI.ContainerExport{}: "archive"
    case UI.WholeExport{}: "jsonl"
    case UI.NoAction{}: "none"
    case _: "other"

def pointer(+x: U32,+y: U32) -> String:
  action(UI.event(Mouse{x,y,0,True{}},F.origin_ui()))

def path() -> String: "/tmp/juice-bend-gui-usage/capture-7-123-0.atif.json"
def canonical() -> String: "/private/tmp/juice-bend-gui-usage/capture-7-123-0.atif.json"
def request() -> Gui.Request: Gui.atif_export_request(F.origin(),123n)

def encoded(value: Result<&2,&2,String,String>) -> J.Json:
  match value:
    case Done{text}: F.json(text)
    case Fail{_}: J.JNull{}

def response() -> J.Json:
  encoded(C.acknowledge(C.Command{"7",path()},canonical(),T.Receipt{"7",canonical(),45,48,44,12000}))

def accepted(value: J.Json) -> Bool:
  Gui.atif_export_response(["export-atif","7",path()],value)

def wrong(key: String,value: J.Json,label: String) -> IO(Unit):
  require(Bool.not(accepted(F.replace(response(),key,value))),label)

def routes() -> IO(Unit):
  +canvas = UI.draw_canvas_capture(F.origin_ui(),"Pause",False{})
  do IO<Unit>:
    require(String.eq(pointer(8,560),"atif") && String.eq(pointer(87,591),"atif"),"ATIF button accepts its full visible32px target including edge pixels")
    require(String.eq(pointer(96,560),"archive") && String.eq(pointer(167,591),"archive"),"Archive button retains its own visible32px target")
    require(String.eq(pointer(7,568),"none") && String.eq(pointer(88,568),"none") && String.eq(pointer(95,568),"none") && String.eq(pointer(168,568),"none"),"split export row padding and eight-pixel gap are inert")
    require(String.eq(pointer(24,536),"jsonl") && String.eq(Full.action(UI.top_action(F.origin_ui(),4)),"bounded"),"full JSONL and bounded evidence export routes remain distinct and reachable")
    require(Window.glyph(canvas,16,568,65,UI.panel()) && Window.glyph(canvas,104,568,65,UI.panel()) && Tiles.tile.empty(Tiles.tile.at(8n,canvas,11,71),UI.rail()),"actual painter shows both format labels with matching inert gap")
    require(String.eq(UI.selection(Full.next_ui(UI.event(Mouse{24,568,0,True{}},F.origin_ui()))),UI.selection(F.origin_ui())),"ATIF pointer does not alter canonical text selection")
    require(String.eq(Full.request_text(request()),"41|export-atif|7|" ++ path() ++ "|7|0|" ++ path()),"ATIF queues exact snapshot and unique application-data path with no page or filter arguments")
    require(String.eq(Full.request_text(Gui.atif_export_request(Full.listing_newer(F.origin()),123n)),Full.request_text(request())),"refreshed newer listing cannot replace the opened export snapshot")
    require(Bool.not(String.eq(Full.request_text(Gui.atif_export_request(Full.with_serial(F.origin(),1),123n)),Full.request_text(request()))),"same-millisecond ATIF requests use distinct no-clobber serial destinations")
    require(String.contains(Gui.write_start_text(41),"text-only ATIF 1.8") && String.contains(Gui.write_start_text(41),"all records outside current filters"),"running status discloses format and complete capture scope")

def acknowledgments() -> IO(Unit):
  do IO<Unit>:
    require(accepted(response()),"actual pure serializer is accepted with exact requested path and canonical alias")
    wrong("snapshot",J.JString{"8"},"newer snapshot acknowledgment is rejected")
    wrong("snapshot",J.JNumber{"7"},"snapshot retains exact string identity type")
    wrong("requested_path",J.JString{"/tmp/other.atif.json"},"different requested destination is rejected")
    wrong("path",J.JString{"relative.atif.json"},"canonical output must be an absolute bounded filename")
    wrong("path",J.JNumber{"12"},"canonical output cannot use a non-string field")
    wrong("schema_version",J.JString{"ATIF-v1.7"},"another schema version cannot confirm this export")
    wrong("complete_export",J.JBool{False{}},"partial export cannot be promoted to complete")
    wrong("complete_export",J.JString{"true"},"complete flag must be a boolean")
    wrong("scope",J.JString{"visible_page"},"current-page output cannot confirm complete snapshot")
    wrong("content",J.JString{"all_attachments"},"unimplemented attachment embedding cannot be claimed")
    wrong("verification",J.JString{"some_records"},"partial verification cannot confirm complete retained extent")
    wrong("records",J.JNumber{"0"},"empty records cannot confirm a published ATIF trajectory")
    wrong("events",J.JString{"48"},"event count must retain its typed integer form")
    wrong("steps",J.JNumber{"49"},"step count cannot exceed retained events")
    require(Bool.not(accepted(F.duplicate(response(),"snapshot",J.JString{"7"}))) && Bool.not(accepted(F.duplicate(response(),"extra",J.JNull{}))),"duplicate and unknown acknowledgment fields are refused")
    require(Bool.not(Gui.atif_export_response(["export-all","7",path()],response())) && Bool.not(Gui.atif_export_response(["export-atif","7",path(),"extra"],response())),"different or trailing command arguments cannot authorize success")

def effects() -> IO(Unit):
  +origin = F.box(Full.listing_newer(F.origin()))
  +done = F.box(Gui.write_done(F.unbox(origin),request(),Gui.Reply{Done{response()}}))
  +newer = F.box(Full.selected_as(F.unbox(origin),"8",3,0))
  +late = F.box(Gui.write_done(F.unbox(newer),request(),Gui.Reply{Done{response()}}))
  +bad = F.box(Gui.write_done(F.origin(),request(),Gui.Reply{Done{F.replace(response(),"snapshot",J.JString{"8"})}}))
  +failed = F.box(Gui.write_done(F.origin(),request(),Gui.Reply{Fail{"retained raw checksum mismatch"}}))
  do IO<Unit>:
    require(String.eq(F.selected(F.unbox(done)),F.selected(F.unbox(origin))) && String.eq(F.position(F.ui(F.unbox(done))),F.position(F.ui(F.unbox(origin)))),"successful ATIF completion preserves opened identity filters listing scroll and selection")
    require(String.eq(F.selected(F.unbox(late)),F.selected(F.unbox(newer))) && String.contains(UI.status_text(F.ui(F.unbox(late))),"snapshot 7"),"late completion reports its old snapshot without replacing a newer opened capture")
    require(String.contains(UI.status_text(F.ui(F.unbox(done))),"including ALL records outside current filters") && String.contains(UI.status_text(F.ui(F.unbox(done))),canonical()),"completion discloses complete scope and actual canonical output")
    require(String.contains(UI.status_text(F.ui(F.unbox(bad))),"success is not confirmed"),"mismatched response never claims export success")
    require(String.contains(UI.status_text(F.ui(F.unbox(failed))),"retained raw checksum mismatch"),"worker refusal remains visible failure")
    +blocked : Gui.State <- Gui.atif_export(Full.selected_as(F.origin(),"",0,0))
    require(Full.writer_absent(blocked) && String.contains(UI.status_text(F.ui(blocked)),"Open a captured transcript"),"actual action without opened capture queues no worker")
    +nested : Gui.State <- Gui.atif_export(Brief.entered())
    require(Full.writer_absent(nested),"Brief cannot reuse a hidden captured selection for ATIF export")
    +exhausted : Gui.State <- Gui.atif_export(Full.with_serial(F.origin(),4294967295))
    require(Full.writer_absent(exhausted),"exhausted operation serial refuses before destination reuse")

def main() -> IO(Unit):
  do IO<Unit>:
    routes()
    acknowledgments()
    effects()
    Full.main()
    Window.main()
    Polish.ordinary()
    Polish.settings()
