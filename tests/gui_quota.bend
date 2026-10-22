import Base
import ../src/gui.bend as G
import ../src/gui_quota.bend as Q
import ../src/gui_settings.bend as Settings
import ../src/ui.bend as UI
import ../src/json.bend as J
import ../src/quota_cli.bend as C
import ./gui_settings.bend as F

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def result(outcome: String,epoch: String,on: Bool) -> J.Json:
  J.JObject{[J.JField{"kind",J.JString{C.protocol()}},J.JField{"outcome",J.JString{outcome}},
    J.JField{"enabled",J.JBool{on}},J.JField{"epoch",J.JString{epoch}},
    J.JField{"samples",J.JArray{[]}},J.JField{"more",J.JBool{False{}}}]}

def wanted(state: G.State) -> G.Request:
  G.State{_,_,_,_,_,_,G.Jobs{_,wanted,_,_,_},_,_} = state
  match wanted:
    case Some{request}: request
    case None{}: G.Request{0,[],"",0,""}

def model(value: Maybe<&2,Q.Model>) -> Q.Model:
  match value:
    case Some{model}: model
    case None{}: Q.initial("/missing")

def current(state: G.State) -> Q.Model:
  model(G.quota_model(G.navigation(state)))

def enter() -> G.State:
  G.quota_enter(F.panel())

def acknowledged() -> G.State:
  +state = enter()
  G.read_done(state,wanted(state),Done{result("status","0",False{})})

def edited(+state: G.State,+root: String) -> G.State:
  G.quota_edit(G.replace_ui(state,UI.set_query(F.ui(state),root)))

def restored_origin() -> G.State:
  F.panel()

def restored_panel() -> G.State:
  G.quota_enter(restored_origin())

def restored_back() -> G.State:
  G.quota_back(restored_panel())

def restored() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(F.observation(restored_back()),F.observation(restored_origin())),"Connections Back restores exact Settings text selection draft scope and reader identity")
    require(Nat.is_eq(List.length(&2,Settings.Source,Settings.sources(G.settings_model(G.read_done(restored_back(),wanted(restored_back()),Done{F.source_json("1")})))),1n),"resumed Settings inventory acknowledgement uses renewed source nonce and actually loads")
    require(String.eq(F.wanted(restored_back()),F.wanted(restored_origin())),"Connections Back resumes only the exact pending Settings inventory")
    require(String.eq(F.observation(G.settings_leave(restored_back())),F.observation(F.ready())),"Settings Back still restores original History snapshot filters and selection")
    require(G.capture_suspended(restored_panel()),"pending Connections suspends automatic capture without changing saved preference")
    require(String.eq(F.acknowledged(restored_panel()),F.acknowledged(restored_origin())),"Connections does not mutate automatic capture preference")
    require(String.eq(F.wanted(restored_panel()),"quota-view|/tmp/juice-bend-settings-contract|1|0|status"),"entry queues exact explicit quota worker metadata")

def lifecycle_waiting() -> G.State:
  enter()

def lifecycle_request() -> G.Request:
  wanted(lifecycle_waiting())

def lifecycle_loaded() -> G.State:
  acknowledged()

def lifecycle_other() -> G.State:
  edited(lifecycle_waiting(),"/synthetic/new root")

def lifecycle_away() -> G.State:
  edited(lifecycle_other(),"/tmp/juice-bend-settings-contract")

def lifecycle_retired() -> G.State:
  G.read_done(lifecycle_away(),lifecycle_request(),Done{result("status","4",True{})})

def lifecycle_back() -> G.State:
  G.quota_back(lifecycle_waiting())

def lifecycle_late_back() -> G.State:
  G.read_done(lifecycle_back(),lifecycle_request(),Done{result("status","4",True{})})

def lifecycle_reload() -> G.State:
  G.quota_read(lifecycle_loaded(),Q.Status{})

def lifecycle_stale() -> G.State:
  G.read_done(lifecycle_reload(),lifecycle_request(),Done{result("status","4",True{})})

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    require(Q.can_enable(current(lifecycle_loaded())),"closed off status acknowledgement enables explicit opt-in")
    require(Bool.not(Q.acknowledged(current(lifecycle_retired()))),"root away and back never revives an old worker reply")
    require(String.eq(F.observation(lifecycle_late_back()),F.observation(lifecycle_back())),"Back-retired reply cannot replace Settings text or selection")
    require(U32.is_eq(Q.phase(current(lifecycle_stale())),1),"new status request rejects prior token despite identical data root")
    require(Bool.not(String.eq(F.wanted(lifecycle_reload()),F.wanted(lifecycle_waiting()))),"each request receives a new operation token")
    require(String.contains(UI.reader(F.ui(lifecycle_reload())),"REQUEST PENDING"),"pending canonical reader labels old acknowledgement")
    require(String.eq(Q.root(current(lifecycle_other())),"/synthetic/new root") && String.eq(UI.query(F.ui(lifecycle_other())),"/synthetic/new root"),"typed root is retained literally with spaces")

def writer_identity_loaded() -> G.State:
  acknowledged()

def writer_identity_model() -> Q.Model:
  current(writer_identity_loaded())

def writer_identity_request() -> Q.Request:
  {Q.Request{"8",Q.root(writer_identity_model()),Q.Enable{},0n} : Q.Request}

def writer_identity_writing() -> G.State:
  G.quota_update(writer_identity_loaded(),Q.begin(writer_identity_model(),writer_identity_request()))

def writer_identity_app() -> G.Request:
  G.quota_app_request(writer_identity_request(),38)

def writer_identity_enabled() -> G.State:
  G.write_done(writer_identity_writing(),writer_identity_app(),G.Reply{Done{result("enabled","1",True{})}})

def writer_identity_back() -> G.State:
  G.quota_back(writer_identity_writing())

def writer_identity_late() -> G.State:
  G.write_done(writer_identity_back(),writer_identity_app(),G.Reply{Done{result("enabled","1",True{})}})

def writer_identity_changed_root() -> G.State:
  edited(writer_identity_writing(),"/synthetic/other")

def writer_identity_oldroot() -> G.State:
  G.write_done(writer_identity_changed_root(),writer_identity_app(),G.Reply{Done{result("enabled","1",True{})}})

def writer_identity_failed() -> G.State:
  G.write_done(writer_identity_writing(),writer_identity_app(),G.Reply{Fail{"private diagnostics"}})

def writer_identity() -> IO(Unit):
  do IO<Unit>:
    require(Q.can_disconnect(current(writer_identity_enabled())),"writer acknowledgement binds exact token root and enabled outcome")
    require(String.eq(F.observation(writer_identity_late()),F.observation(writer_identity_back())),"writer finishing after Back cannot replace restored view")
    require(Bool.not(Q.acknowledged(current(writer_identity_oldroot()))),"old-root writer cannot acknowledge an edited data root")
    require(U32.is_eq(Q.phase(current(writer_identity_failed())),3) &&
      String.contains(UI.reader(F.ui(writer_identity_failed())),"Local state unavailable | Choose Refresh") &&
      String.contains(UI.reader(F.ui(writer_identity_failed())),"A change may have committed."),
      "failed writer explicitly labels uncertain state and last acknowledgement in reader")
    require(Bool.not(String.contains(UI.reader(F.ui(writer_identity_failed())),"private diagnostics")),"raw child diagnostic never enters canonical quota reader")

def visible_rows(state: G.State) -> String:
  G.State{_,_,_,UI.State{UI.Content{_,rows,_,_,_,_,_,_,_},_,_,_},_,_,_,_,_} = state
  String.join(rows,"\n")

def background_source_panel() -> G.State:
  G.quota_enter(F.sourced())

def background_source_changed() -> G.State:
  G.write_done(background_source_panel(),G.Request{30,["source-disable","claude","/synthetic/folder café"],"",0,"Disable"},G.Reply{Done{F.source_reply(False{})}})

def background_source_back() -> G.State:
  G.quota_back(background_source_changed())

def background_source() -> IO(Unit):
  do IO<Unit>:
    require(String.contains(visible_rows(background_source_back()),"[off]") && String.eq(F.selected_state(Settings.selected(G.settings_model(background_source_back()))),"claude|/synthetic/folder café|false"),"Back reconciles source rows with a newer background disable acknowledgement")
    require(String.eq(F.observation(G.settings_leave(background_source_back())),F.observation(F.ready())),"background source reconciliation preserves the original History bookmark")

def main() -> IO(Unit):
  do IO<Unit>:
    restored()
    lifecycle()
    writer_identity()
    background_source()
