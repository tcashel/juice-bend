import Base
import ../src/attachment_capture_ack.bend as Ack
import ../src/attachment_capture_output.bend as O
import ../src/attachment_capture_roots.bend as Roots
import ../src/attachment_asset_types.bend as T
import ../src/gui_attachments.bend as G
import ../src/gui_attachment_capture.bend as C
import ../src/gui_attachment_folders.bend as Folders
import ../src/json.bend as J
import ./attachment_asset_types.bend as F
import ./attachment_capture_command.bend as P
import ./gui_attachments_model.bend as M

def receipt() -> T.Receipt: T.receipt(T.Admission{F.identity(99),F.root(99),"9007199254740993",F.binary()})
def ack_same(value: Result<&2,&2,String,Ack.Asset>,expected: T.Receipt) -> Bool:
  match value:
    case Done{Ack.Asset{state,actual,None{}}}: String.eq(state,"retained") && T.same(actual,expected)
    case _: False{}
def refused(value: Result<&2,&2,String,Ack.Asset>) -> Bool:
  match value:
    case Fail{_}: True{}
    case _: False{}
def path() -> String: "/message/content/2/source/path"
def key() -> G.OccurrenceKey: G.OccurrenceKey{1,2,path(),100,100,F.raw_sha(),"",0,False{}}
def descriptor(kind: String) -> String:
  "{\"type\":\"" ++ kind ++ "\",\"availability\":\"external_bytes_uncaptured\",\"name\":\"photo.png\",\"summary\":\"Synthetic local reference\"}"
def occurrence(+index: U32,kind: String) -> String:
  "{\"reference\":" ++ U32.show(index) ++ ",\"path\":\"/message/content/" ++ U32.show(index) ++ "/source/path\",\"kind\":\"document\",\"descriptor\":" ++ descriptor(kind) ++ "}"
def inventory(kind: String) -> J.Json:
  M.json("{\"capture\":{\"provider\":\"claude\",\"source_id\":\"2\",\"source\":\"/synthetic/capture.jsonl\",\"generation\":\"3\",\"snapshot\":\"1\",\"extent\":\"200\",\"total_records\":2,\"encoding\":\"identity\",\"byte_space\":\"logical_source_bytes\"},\"records\":[{\"record\":1,\"offset\":100,\"length\":100,\"digest\":\"" ++ F.raw_sha() ++ "\",\"coverage\":{\"state\":\"extracted\",\"complete\":true,\"truncated\":false},\"occurrences\":[" ++ occurrence(0,"local_path") ++ "," ++ occurrence(1,"local_path") ++ "," ++ occurrence(2,kind) ++ "]}]}")
def selected() -> C.Model: C.select_key(C.inventory(C.initial(),inventory("local_path")),Some{key()})
def error(state: O.Knowledge) -> J.Json:
  M.json(O.error(O.Failure{"owned",T.failure("attachment_asset_not_captured","No owned asset"),state}))
def uncaptured() -> C.Model: C.apply(C.begin(selected(),2,False{}),Done{error(O.NoMutation{})})
def exportable() -> C.Model: C.choose(uncaptured(),F.root(99))
def ready(value: J.Json) -> C.Model: C.apply(C.begin(selected(),3,False{}),Done{value})
def folder_page() -> Roots.Page:
  Roots.Page{"0",40,[T.RootEvidence{"1","/synthetic/one","1",True{}},T.RootEvidence{"2","/synthetic/two","3",False{}}],None{}}
def main() -> IO(Unit):
  do IO<Unit>:
    +text : String <- P.need(O.asset("retained",receipt(),None{},O.NoMutation{}))
    +value : J.Json <- P.parsed(J.parse(text))
    F.assert(ack_same(Ack.asset(value),receipt()),"UI decoder preserves full immutable original receipt and exact time above2^53")
    F.assert(refused(Ack.asset(M.replace(value,"profile",J.JString{"unknown"}))),"unknown asset profile cannot enable retained controls")
    F.assert(refused(Ack.asset(M.replace(value,"receipt",M.replace(J.field(value,"receipt"),"observed_at_ms",J.JNumber{"9007199254740993"})))),"numeric time cannot substitute exact string milliseconds")
    F.assert(refused(Ack.asset(M.replace(value,"receipt",M.replace(J.field(value,"receipt"),"commitment",J.JString{F.other_sha()})))),"receipt commitment mismatch prevents success")
    F.assert(refused(Ack.asset(M.replace(value,"receipt",M.replace(J.field(value,"receipt"),"occurrence",M.replace(J.field(J.field(value,"receipt"),"occurrence"),"byte_space",J.JString{"compressed_container_bytes"}))))),"container byte space cannot masquerade as logical occurrence offsets")
    F.assert(Maybe.is_some(&2,C.Target,C.target(selected())),"validated local occurrence creates exact capture target")
    F.assert(Bool.not(C.can_capture(selected())) && Bool.not(C.can_capture(uncaptured())),"selection and uncaptured state need an explicitly selected enabled root")
    F.assert(C.can_capture(exportable()),"known uncaptured exact local occurrence enables explicit Capture only with enabled root")
    F.assert(Bool.not(C.can_capture(C.choose(uncaptured(),T.RootEvidence{"7","/synthetic/café","10",False{}}))),"disabled selected root cannot enable new capture")
    F.assert(Bool.not(C.can_capture(C.choose(C.apply(C.begin(selected(),2,False{}),Done{error(O.CaptureUncertain{})}),F.root(99)))),"uncertain failure never becomes known uncaptured eligibility")
    F.assert(C.can_export(ready(value)),"strict retained receipt matching selected identity enables owned export")
    F.assert(C.can_export(C.choose(ready(value),T.RootEvidence{"7","/synthetic/café","10",False{}})),"root disable leaves already retained bytes exportable")
    F.assert(Bool.not(C.can_export(C.apply(C.begin(selected(),2,False{}),Fail{"child ended"}))),"fatal or incomplete child reply cannot enable retained success")
    F.assert(Bool.not(C.can_export(C.select_key(ready(value),None{}))),"leaving a selected occurrence removes prior owned export eligibility")
    F.assert(Bool.not(C.can_export(C.apply(C.begin(C.inventory(C.initial(),inventory("local_path")),2,False{}),Done{value}))),"reply without a current selected target cannot create retained state")
    +page_text : String <- P.need(O.page(folder_page()))
    +page : J.Json <- P.parsed(J.parse(page_text))
    +folders : Folders.Model = Folders.response(Folders.load(Folders.initial(),1),Done{page})
    F.assert(Folders.can_choose(folders) && Folders.can_disable(folders) && Bool.not(Folders.can_enable(folders)),"enabled root exposes explicit Use and Disable controls")
    +disabled : Folders.Model = Folders.select(folders,1)
    F.assert(Folders.can_enable(disabled) && Bool.not(Folders.can_choose(disabled)),"disabled root exposes Enable but cannot authorize a new capture")
    F.assert(Bool.not(Folders.can_choose(Folders.writing(folders,2,["attachment-root-disable","1"]))),"pending root mutation blocks stale Use selection")
    F.assert(Bool.not(Folders.can_choose(Folders.fail(folders,"uncertain root mutation"))),"uncertain root mutation drops old root page instead of reusing stale enabled state")
    F.assert(Bool.not(Folders.next(folders)) && Bool.not(Folders.previous(folders)),"single root page has no speculative navigation")
