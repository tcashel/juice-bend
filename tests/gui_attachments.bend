import Base
import ../src/gui.bend as G
import ../src/gui_attachments.bend as A
import ../src/ui.bend as UI
import ../src/json.bend as J
import ./gui_attachments_model.bend as M
import ./gui_settings.bend as F

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def origin_from(state: G.State) -> G.State:
  G.State{db,dir,program,ui,G.Selection{items,_,_,_,_,filters,listing},form,jobs,deadline,serial} = state
  G.State{db,dir,program,ui,G.Selection{items,"7",4,3,["transcript-range-v1","7","4","40","13"],filters,listing},form,jobs,deadline,serial}

def origin() -> G.State: origin_from(F.ready())

def wanted(state: G.State) -> G.Request:
  G.State{_,_,_,_,_,_,G.Jobs{_,wanted,_,_,_},_,_} = state
  match wanted:
    case Some{request}: request
    case None{}: G.Request{0,[],"",0,""}

def get(value: Maybe<&2,A.Model>) -> A.Model:
  match value:
    case Some{model}: model
    case None{}: A.initial(A.Anchor{"0",0,0})

def model(state: G.State) -> A.Model: get(G.attachment_model(G.navigation(state)))
def entered() -> G.State: G.attachment_enter(origin())
def loaded() -> G.State:
  +state = entered()
  G.read_done(state,wanted(state),Done{M.json(M.wire(4,10))})

def picked() -> G.State:
  +state = loaded()
  G.attachment_pick(state,1,G.attachment_model(G.navigation(state)))

def request_with_nonce(request: G.Request) -> G.Request:
  G.Request{kind,args,_,start,title} = request
  G.Request{kind,args,"999",start,title}

def request_with_args(request: G.Request) -> G.Request:
  G.Request{kind,_,nonce,start,title} = request
  G.Request{kind,["attachments","7","5","10"],nonce,start,title}

def nested_from(+state: G.State) -> G.State:
  G.State{_,_,_,+ui,selection,_,_,_,_} = state
  G.set_navigation(state,G.RelatedNavigation{selection,UI.bookmark(ui),"nested filtered search",None{},None{},["older-page"],2,None{}})

def nested_origin() -> G.State: nested_from(origin())

def restored() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(F.observation(G.attachment_back(entered())),F.observation(origin())),"Back while loading restores exact reader text selection listing and all filters")
    require(String.eq(F.wanted(G.attachment_back(entered())),"none"),"Back never retargets or reloads latest capture")
    require(String.eq(F.observation(G.attachment_back(picked())),F.observation(origin())),"Back after occurrence selection restores exact original filtered reader")
    require(U32.is_eq(G.navigation_phase(G.navigation(G.attachment_back(G.attachment_enter(nested_origin())))),2),"Back preserves enclosing Related navigation phase")
    require(String.eq(F.observation(G.attachment_back(G.attachment_enter(nested_origin()))),F.observation(nested_origin())),"nested Back restores its exact reader filters and selection")
    require(G.capture_suspended(entered()),"attachment browsing suspends automatic capture without preference change")
    require(String.eq(F.acknowledged(entered()),F.acknowledged(origin())),"attachment browsing preserves acknowledged automatic refresh preference")
    require(String.eq(F.wanted(entered()),"attachments|7|4|10"),"GUI queue uses frozen physical range without inherited role repository time filters")
    require(String.eq(F.observation(G.read_done(G.attachment_back(entered()),wanted(entered()),Done{M.json(M.wire(4,10))})),F.observation(origin())),"late inventory completion after Back cannot replace original reader")
    require(U32.is_eq(A.phase(model(G.read_done(entered(),request_with_nonce(wanted(entered())),Done{M.json(M.wire(4,10))}))),1),"stale inventory nonce is ignored")
    require(U32.is_eq(A.phase(model(G.read_done(entered(),request_with_args(wanted(entered())),Done{M.json(M.wire(4,10))}))),1),"different raw range request is ignored")
    require(String.contains(UI.reader(F.ui(loaded())),A.scope()),"loaded native reader exposes raw scope before export")
    require(A.exportable(model(picked())),"inline occurrence selection enables exact byte export")
    require(String.eq(G.attachment_name(A.Anchor{"7",4,13},A.OccurrenceKey{4,0,"/message/content/0/source",40,10,M.sha(),"image/png",4,True{}},2,123n),"attachment-7-4-0-123-2.bin"),"private export filename is unique metadata-only and ignores source name")

def exporting() -> G.State:
  +state = picked()
  G.attachment_update(state,A.exporting(model(state),["export-inline","7","4","0","/message/content/0/source","/synthetic/owned.bin"],10))

def export_request() -> G.Request: G.attachment_request(model(exporting()),40)

def export_done(state: G.State,value: J.Json) -> G.State:
  G.write_done(state,export_request(),G.Reply{Done{value}})

def exported() -> IO(Unit):
  do IO<Unit>:
    require(String.contains(UI.reader(F.ui(export_done(exporting(),M.ack("/synthetic/owned.bin","4")))),"Saved original inline bytes"),"GUI writer completion requires exact frozen occurrence acknowledgement")
    require(String.contains(UI.reader(F.ui(export_done(exporting(),M.ack("/synthetic/other.bin","4")))),"file may have been published"),"GUI mismatched export acknowledgement reports uncertainty")
    require(String.eq(F.observation(export_done(G.attachment_back(exporting()),M.ack("/synthetic/owned.bin","4"))),F.observation(origin())),"export completion after Back cannot disturb restored reader selection")
    require(U32.is_eq(A.selected_index(model(G.attachment_pick(exporting(),3,G.attachment_model(G.navigation(exporting()))))),1),"occurrence identity cannot change while selected export runs")
    require(String.eq(F.wanted(G.attachment_page(loaded(),True{},G.attachment_model(G.navigation(loaded())))),"attachments|7|14|3"),"GUI last raw page is bounded by original reader range")

def busy(+state: G.State,channel: Chan(G.Reply)) -> G.State:
  G.State{db,dir,program,ui,selection,form,G.Jobs{revision,wanted,reader,_,paused},deadline,serial} = state
  G.State{db,dir,program,ui,selection,form,G.Jobs{revision,wanted,reader,Some{G.Pending{revision,G.Request{7,["import","claude","/synthetic/source"],"",0,"existing writer"},channel}},paused},deadline,serial}

def busy_checked(+channel: Chan(G.Reply)) -> IO(Unit):
  do IO<Unit>:
    require(Bool.not(G.attachment_can_export(busy(picked(),channel),model(picked()))),"attachment export cannot start a second writer")
    Chan.close(G.Reply,channel)

def admission() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(F.observation(G.attachment_enter(F.ready())),F.observation(F.ready())),"nontranscript activity cannot masquerade as captured attachment range")
    require(String.eq(F.observation(G.attachment_enter(G.queue(origin(),G.Request{3,["session-scope","8","0","40","","","",""],"8",0,"pending"}))),F.observation(origin())),"entry never cancels an already requested reader range")
    require(Bool.not(G.attachment_range(["transcript-range-v1","7","4","40","013"],"7",4)),"noncanonical range metadata rejected")
    require(Bool.not(G.attachment_range(["transcript-range-v1","8","4","40","13"],"7",4)),"range metadata cannot retarget snapshot")
    channel : Chan(G.Reply) <- Chan.new(G.Reply,1)
    busy_checked(channel)

def main() -> IO(Unit):
  do IO<Unit>:
    restored()
    exported()
    admission()
