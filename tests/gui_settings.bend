import Base
import ../src/gui.bend as Gui
import ../src/gui_settings.bend as Settings
import ../src/gui_files.bend as Files
import ../src/ui.bend as UI
import ../src/json.bend as Json
import ../src/query.bend as Query
import ../src/refresh_preferences.bend as Refresh

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def origin() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-settings-contract","/usr/bin/false",
    UI.set_edit(UI.set_position(UI.set_rows(UI.set_scope(UI.set_reader(UI.set_query(UI.init(),"needle role:assistant"),
      "Tools | immutable snapshot7","Exact original reader café 中文 🙂\nselected evidence"),"codex"),["first","second"]),1,4),UI.Edit{2,17,3,False{},0}),
    Gui.Selection{[Gui.Item{"7",40,"chosen","codex","/synthetic/repo","3",Gui.empty_filters()}],"7",40,24,["activity","7"],
      Query.Filters{"","codex","/synthetic/repo","assistant","2026-10-20"},Gui.Listing{2,Query.Filters{"needle","codex","","assistant",""},100,True{},True{},""}},
    Gui.Form{0,"needle role:assistant","old source draft","old blame draft",Files.empty(),[],[]},
    Gui.Jobs{9,None{},None{},None{},False{}},31000n,0}

def ready() -> Gui.State:
  Gui.settings_model_set(origin(),Settings.loaded(Settings.initial(),Refresh.defaults()))

def panel() -> Gui.State:
  Gui.settings(ready())

def ui(state: Gui.State) -> UI.State:
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  ui

def request(value: Maybe<&2,Gui.Request>) -> String:
  match value:
    case None{}: "none"
    case Some{Gui.Request{kind,args,snap,start,title}}: String.join(args,"|")

def wanted(state: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},deadline,serial} = state
  request(wanted)

def writer_request(value: Maybe<&2,Gui.Pending>) -> String:
  match value:
    case None{}: "none"
    case Some{Gui.Pending{ticket,Gui.Request{kind,args,snap,start,title},channel}}: String.join(args,"|")

def writer(state: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},deadline,serial} = state
  writer_request(writer)

def preference(state: Gui.State) -> String:
  request(Gui.preference_next(Gui.settings_model(state)))

def preference_text(value: Refresh.Preferences) -> String:
  Refresh.Preferences{enabled,interval} = value
  Refresh.enabled_text(enabled) ++ "/" ++ U32.show(Refresh.seconds(interval))

def acknowledged(state: Gui.State) -> String:
  preference_text(Settings.preferences(Gui.settings_model(state)))

def deadline(state: Gui.State) -> Nat:
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  deadline

def observation(state: Gui.State) -> String:
  Gui.State{db,dir,program,UI.State{UI.Content{query,rows,reader,lines,title,status,scope,results,files,_},
    UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,drag,viewport},command,shift},image,dirty},
    Gui.Selection{items,snapshot,start,kind,args,Query.Filters{query2,provider,repo,role,after},
      Gui.Listing{listkind,Query.Filters{terms,lp,lr,lo,la},offset,more,loaded,listanchor}},
    Gui.Form{mode,search,source,blame,filemodel,navigation,settings},jobs,clock,serial} = state
  String.join([Json.quote(query),Json.quote(reader),Json.quote(title),Json.quote(scope),String.join(rows,"~"),
    U32.show(selected),U32.show(scroll),U32.show(focus),U32.show(caret),U32.show(anchor),U32.show(viewport),
    snapshot,U32.show(start),U32.show(kind),String.join(args,"~"),provider,repo,role,after,
    U32.show(listkind),terms,lp,lr,lo,la,U32.show(offset),Refresh.enabled_text(more),Refresh.enabled_text(loaded),listanchor,
    U32.show(mode),search,source,blame],"|")

def restored() -> IO(Unit):
  require(String.eq(observation(Gui.settings_leave(panel())),observation(ready())),
    "Settings Back restores exact text range scope listing offset cursor and selection")

def completed_no_reread() -> IO(Unit):
  require(String.eq(wanted(Gui.settings_leave(panel())),"none"),"completed Settings origin restores without a new lookup")

def pending_origin() -> IO(Unit):
  require(String.eq(wanted(Gui.settings_leave(Gui.settings(Gui.queue(ready(),
    Gui.Request{3,["session-scope","7","40","40","codex","/synthetic/repo","assistant","2026-10-20"],"7",40,"Exact pending page"})))),
    "session-scope|7|40|40|codex|/synthetic/repo|assistant|2026-10-20"),
    "Settings resumes only the exact request already pending at entry")

def startup_request() -> IO(Unit):
  require(String.eq(preference(origin()),"refresh-preferences"),"unknown startup preferences request one closed read")

def no_repeat() -> IO(Unit):
  require(String.eq(preference(ready()),"none") && String.eq(request(Gui.preference_next(Settings.loading(Settings.initial()))),"none"),
    "acknowledged and in-flight preferences are not reloaded every frame")

def pause_pending() -> IO(Unit):
  require(String.eq(acknowledged(Gui.toggle_pause(ready())),"true/30") &&
    String.eq(preference(Gui.toggle_pause(ready())),"refresh-preferences-set|false|30"),
    "Pause queues a durable full pair while retaining the acknowledged state")

def acknowledged_pause() -> Gui.State:
  Gui.preferences_apply(Gui.toggle_pause(ready()),28,["refresh-preferences-set","false","30"],Done{Refresh.Preferences{False{},Refresh.Live30{}}})

def pause_saved() -> IO(Unit):
  require(String.eq(acknowledged(acknowledged_pause()),"false/30") && String.eq(preference(acknowledged_pause()),"none"),
    "Pause applies only after the exact saved preference acknowledgment")

def queued_after_reload() -> Gui.State:
  Gui.settings_reload(Gui.settings_interval_change(Gui.toggle_pause(panel()),7200))

def reload_keeps_pair() -> IO(Unit):
  require(String.eq(request(Gui.preference_next(Settings.loaded(Gui.settings_model(queued_after_reload()),Refresh.defaults()))),
    "refresh-preferences-set|false|7200"),"Reload preserves the complete pending disabled two-hour pair")

def older_ack() -> Gui.State:
  Gui.preferences_apply(queued_after_reload(),28,["refresh-preferences-set","false","30"],Done{Refresh.Preferences{False{},Refresh.Live30{}}})

def latest_pair_survives() -> IO(Unit):
  require(String.eq(preference(older_ack()),"refresh-preferences-set|false|7200") && String.eq(acknowledged(older_ack()),"false/30"),
    "older save acknowledgment retains the newer desired pair")

def back_keeps_pair() -> IO(Unit):
  require(String.eq(preference(Gui.settings_leave(older_ack())),"refresh-preferences-set|false|7200") &&
    String.eq(acknowledged(Gui.settings_leave(older_ack())),"false/30"),"Back never restores old preferences or discards pending writes")

def back_keeps_saved() -> IO(Unit):
  require(String.eq(acknowledged(Gui.settings_leave(Gui.preferences_apply(panel(),28,
    ["refresh-preferences-set","false","7200"],Done{Refresh.Preferences{False{},Refresh.Hours2{}}}))),"false/7200"),
    "saved preferences remain global after restoring the original reader")

def invalid_ack() -> IO(Unit):
  require(U32.is_eq(Settings.phase(Gui.settings_model(Gui.preferences_apply(ready(),28,
    ["refresh-preferences-set","false","7200"],Done{Refresh.defaults()}))),3),
    "mismatched preference acknowledgment disables scheduling visibly")

def source_json(enabled: String) -> Json.Json:
  Json.JObject{[Json.JField{"columns",Json.JArray{[Json.JString{"provider"},Json.JString{"canonical_root"},Json.JString{"enabled"}]}},
    Json.JField{"rows",Json.JArray{[Json.JArray{[Json.JString{"claude"},Json.JString{"/synthetic/folder café"},Json.JString{enabled}]}]}}]}

def sourced() -> Gui.State:
  Gui.settings_pick(Gui.settings_sources(panel(),Done{source_json("1")}),0)

def source_reply(+enabled: Bool) -> Json.Json:
  Json.JObject{[Json.JField{"kind",Json.JString{"source_change"}},Json.JField{"ack",Json.JObject{[
    Json.JField{"enabled",Json.JBool{enabled}},Json.JField{"provider",Json.JString{"claude"}},
    Json.JField{"requested_root",Json.JString{"/synthetic/folder café"}}]}},
    Json.JField{"sources",source_json(Bool.pick(String,enabled,"1","0"))}]}

def disabled() -> Gui.State:
  Gui.write_done(sourced(),Gui.Request{30,["source-disable","claude","/synthetic/folder café"],"",0,"Disable"},Gui.Reply{Done{source_reply(False{})}})

def selected_state(value: Maybe<&2,Settings.Source>) -> String:
  match value:
    case None{}: "none"
    case Some{Settings.Source{provider,path,enabled}}: provider ++ "|" ++ path ++ "|" ++ Refresh.enabled_text(enabled)

def source_selected() -> IO(Unit):
  require(String.eq(UI.query(ui(sourced())),"/synthetic/folder café") && String.eq(UI.scope(ui(sourced())),"claude"),
    "source row selection uses exact canonical Unicode path and provider")

def confirmed_disable() -> IO(Unit):
  require(String.eq(selected_state(Settings.selected(Gui.settings_model(disabled()))),"claude|/synthetic/folder café|false"),
    "disabled source is shown only from the post-acknowledgment inventory")

def stale_source_reply() -> IO(Unit):
  require(String.eq(selected_state(Settings.selected(Gui.settings_model(Gui.read_current(disabled(),
    Gui.Request{6,["sources"],"0",0,"Old inventory"},Gui.Reply{Done{source_json("1")}},True{})))),"claude|/synthetic/folder café|false"),
    "older source reader cannot overwrite newer acknowledged disabled inventory")

def old_reader_after_back() -> IO(Unit):
  require(String.eq(observation(Gui.read_current(Gui.settings_leave(panel()),Gui.Request{6,["sources"],"0",0,"Old inventory"},
    Gui.Reply{Done{source_json("1")}},False{})),observation(ready())),"Settings reader ticket cannot replace the restored origin")

def source_after_back() -> IO(Unit):
  require(String.eq(observation(Gui.write_done(Gui.settings_leave(sourced()),
    Gui.Request{30,["source-disable","claude","/synthetic/folder café"],"",0,"Disable"},Gui.Reply{Done{source_reply(False{})}})),observation(ready())),
    "source mutation acknowledgment after Back preserves the captured reader")

def rows(+n: Nat) -> List<&2,Settings.Source>:
  match n:
    case 0n: []
    case 1n+p: Settings.Source{"codex","/synthetic/root-" ++ Nat.show(n),True{}} <> rows(p)

def paged() -> Gui.State:
  Gui.settings_update(panel(),Settings.with_sources(Gui.settings_model(panel()),rows(32n)))

def ui_row_count(state: UI.State) -> U32:
  UI.State{UI.Content{query,rows,reader,lines,title,status,scope,results,files,_},input,image,dirty} = state
  U32.from_nat(List.length(&2,String,rows))

def row_count(state: Gui.State) -> U32:
  ui_row_count(ui(state))

def source_paging() -> IO(Unit):
  require(U32.is_eq(row_count(paged()),14) && U32.is_eq(row_count(Gui.settings_page(Gui.settings_page(paged(),True{}),True{})),4),
    "all thirty-two registered folders are reachable in fourteen-row pages")

def source_end() -> IO(Unit):
  require(U32.is_eq(Settings.offset(Gui.settings_model(Gui.settings_page(Gui.settings_page(Gui.settings_page(paged(),True{}),True{}),True{}))),28),
    "source paging stops at the last bounded inventory page")

def source_path_guards() -> IO(Unit):
  require(Gui.settings_path_valid("codex","/synthetic/literal $(none) café") &&
    Bool.not(Gui.settings_path_valid("all","/synthetic/folder")) && Bool.not(Gui.settings_path_valid("claude","relative/file")),
    "source operations accept only explicit providers and literal absolute paths")

def unknown_schedule() -> IO(Unit):
  do IO<Unit>:
    +state : Gui.State <- Gui.auto_refresh(origin(),90000n)
    require(Nat.is_eq(deadline(state),0n) && String.eq(writer(state),"none"),"unknown preferences cannot start automatic capture")

def two_hour_schedule() -> IO(Unit):
  do IO<Unit>:
    +state : Gui.State <- Gui.auto_refresh(Gui.preferences_apply(ready(),28,["refresh-preferences-set","true","7200"],
      Done{Refresh.Preferences{True{},Refresh.Hours2{}}}),1000n)
    require(Nat.is_eq(deadline(state),7201000n),"acknowledged two-hour interval arms a monotonic full deadline")

def failed_schedule() -> IO(Unit):
  do IO<Unit>:
    +state : Gui.State <- Gui.auto_refresh(Gui.preferences_done(ready(),27,["refresh-preferences"],Fail{"invalid retained preference"}),90000n)
    require(Nat.is_eq(deadline(state),0n) && String.eq(writer(state),"none"),"invalid retained preferences never fall back to enabled defaults")

def pending_schedule() -> IO(Unit):
  do IO<Unit>:
    +state : Gui.State <- Gui.auto_refresh(Gui.toggle_pause(ready()),90000n)
    require(Nat.is_eq(deadline(state),0n) && String.eq(writer(state),"none"),"pending preference save suppresses automatic capture without optimistic acknowledgment")

def overflow_schedule() -> IO(Unit):
  do IO<Unit>:
    +state : Gui.State <- Gui.auto_refresh(ready(),Refresh.native_limit())
    require(U32.is_eq(Settings.phase(Gui.settings_model(state)),3) && Nat.is_eq(deadline(state),0n),
      "native monotonic overflow becomes one visible disabled-schedule error")

def busy_pref() -> IO(Unit):
  do IO<Unit>:
    running : Gui.State <- Gui.start_write(ready(),Gui.Request{8,["refresh-all"],"",0,"Synthetic active capture"},None{})
    +next : Gui.State <- Gui.service_preferences(Gui.settings_reload(Gui.toggle_pause(running)))
    require(String.eq(writer(next),"refresh-all") &&
      String.eq(request(Gui.preference_next(Settings.loaded(Gui.settings_model(next),Refresh.defaults()))),"refresh-preferences-set|false|30"),
      "Pause plus Reload during capture preserves the queued pair and single writer")

def manual_while_paused() -> IO(Unit):
  do IO<Unit>:
    +next : Gui.State <- Gui.refresh(Gui.settings(acknowledged_pause()))
    require(String.eq(writer(next),"refresh-all"),"manual Settings Refresh remains available while durable automatic refresh is disabled")

def main() -> IO(Unit):
  do IO<Unit>:
    restored()
    completed_no_reread()
    pending_origin()
    startup_request()
    no_repeat()
    pause_pending()
    pause_saved()
    reload_keeps_pair()
    latest_pair_survives()
    back_keeps_pair()
    back_keeps_saved()
    invalid_ack()
    source_selected()
    confirmed_disable()
    stale_source_reply()
    old_reader_after_back()
    source_after_back()
    source_paging()
    source_end()
    source_path_guards()
    unknown_schedule()
    two_hour_schedule()
    failed_schedule()
    pending_schedule()
    overflow_schedule()
    busy_pref()
    manual_while_paused()
