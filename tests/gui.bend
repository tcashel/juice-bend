import Base
import ../src/gui.bend as Gui
import ../src/ui.bend as UI
import ../src/json.bend as Json
import ../src/query.bend as Query
import ../src/sql.bend as Sql

def require(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def state() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-gui-contract","/usr/bin/false",
    UI.set_reader(UI.set_query(UI.init(),"needle"),"Pinned","stable evidence"),
    Gui.Selection{[],"7",0,3,[],Gui.empty_filters()},Gui.Form{0,"needle","",""},
    Gui.Jobs{2,None{},None{},None{},False{}},0n,0}

def ui(s: Gui.State) -> UI.State:
  Gui.State{db,dir,program,ui,selection,form,jobs,refresh_at,serial} = s
  ui

def snapshot(s: Gui.State) -> String:
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,displayed,args,filters},form,jobs,refresh_at,serial} = s
  snap

def mode(s: Gui.State) -> U32:
  Gui.State{db,dir,program,ui,selection,Gui.Form{mode,search,source,blame},jobs,refresh_at,serial} = s
  mode

def wanted_args(value: Maybe<&2,Gui.Request>) -> String:
  match value:
    case None{}:
      "none"
    case Some{Gui.Request{kind,args,snapshot,start,title}}:
      String.join(args,"|")

def wanted(s: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = s
  wanted_args(wanted)

def result_text(text: String) -> Gui.Reply:
  Gui.Reply{Done{Json.JObject{[Json.JField{"text",Json.JString{text}}]}}}

def blame_result(value: Result<&2,&2,String,List<&2,String>>) -> String:
  match value:
    case Fail{message}:
      "error"
    case Done{args}:
      String.join(args,"|")

def forms() -> IO(Unit):
  +settings = Gui.settings(state())
  +input = Gui.form_text(Gui.replace_ui(settings,UI.set_query(ui(settings),"/tmp/explicit source.jsonl")))
  +scoped = Gui.scope_changed(Gui.replace_ui(input,UI.set_scope(ui(input),"codex")))
  +completed = Gui.write_done(input,Gui.Request{7,["import","claude","/tmp/a"],"",0,"import"},
    Gui.Reply{Done{Json.JObject{[Json.JField{"accepted_snapshot",Json.JString{"8"}}]}}})
  do IO<Unit>:
    Unit <- require(U32.is_eq(mode(settings),1),"settings is an explicit input mode")
    Unit <- require(String.eq(UI.query(ui(scoped)),"/tmp/explicit source.jsonl"),"provider choice preserves source path")
    Unit <- require(U32.is_eq(mode(scoped),1) && String.eq(wanted(scoped),"sources"),"source mode never executes lexical search")
    require(String.eq(UI.query(ui(completed)),"/tmp/explicit source.jsonl") && U32.is_eq(mode(completed),1),"import completion retains current form")

def readers() -> IO(Unit):
  +stale = Gui.read_current(state(),Gui.Request{3,["session","8","0","40"],"8",0,"new"},result_text("new evidence"),False{})
  +fresh = Gui.read_current(state(),Gui.Request{3,["session","8","0","40"],"8",0,"new"},result_text("new evidence"),True{})
  +pinned = Gui.with_rows(state(),[Gui.Item{"9",0,"new source extent","claude","/tmp/repo","2",Gui.empty_filters()}])
  do IO<Unit>:
    Unit <- require(String.eq(UI.reader(ui(stale)),"stable evidence") && String.eq(snapshot(stale),"7"),"stale worker cannot replace pinned evidence")
    Unit <- require(String.eq(UI.reader(ui(fresh)),"new evidence") && String.eq(snapshot(fresh),"8"),"current worker applies exact requested snapshot")
    require(String.eq(snapshot(pinned),"7") && String.eq(wanted(pinned),"none"),"browse refresh preserves accepted snapshot")

def initial() -> IO(Unit):
  +empty = {Gui.State{0,"/tmp/juice-bend-gui-contract","/usr/bin/false",UI.init(),
    Gui.Selection{[],"",0,0,[],Gui.empty_filters()},Gui.Form{0,"","",""},Gui.Jobs{0,None{},None{},None{},False{}},0n,0} : Gui.State}
  +next = Gui.with_rows(empty,[Gui.Item{"9",0,"initial source","claude","/tmp/repo","2",Gui.empty_filters()}])
  require(String.eq(wanted(next),"session-scope|9|0|40||||"),"initial unpinned browse opens first accepted snapshot")

def initial_late_hit() -> IO(Unit):
  +empty = {Gui.State{0,"/tmp/juice-bend-gui-contract","/usr/bin/false",UI.init(),
    Gui.Selection{[],"",0,0,[],Gui.empty_filters()},Gui.Form{0,"","",""},Gui.Jobs{0,None{},None{},None{},False{}},0n,0} : Gui.State}
  +next = Gui.with_rows(empty,[Gui.Item{"9",500,"late matching record","codex","/tmp/repo","2",
    Query.Filters{"","codex","/tmp/repo","assistant","2026-10-01"}}])
  require(String.eq(wanted(next),"session-scope|9|500|40|codex|/tmp/repo|assistant|2026-10-01"),
    "initial search opens the matching record with its frozen filters")

def history_ordinal() -> IO(Unit):
  +prefix = {[Sql.Cell.Text{"source"},Sql.Cell.Text{"codex"},Sql.Cell.Text{"/tmp/source"},
    Sql.Cell.Text{"9"},Sql.Cell.Text{"2"},Sql.Cell.Text{"10000"},Sql.Cell.Text{"600"},
    Sql.Cell.Text{"matching body"},Sql.Cell.Text{"/tmp/repo"}] : List<&2,Sql.Cell>}
  do IO<Unit>:
    Unit <- require(U32.is_eq(Gui.first_ordinal(Gui.history_items(
      [List.append(&2,Sql.Cell,prefix,[Sql.Cell.Text{"500"}])],Gui.empty_filters())),500),
      "history opens the first scoped readable record")
    require(U32.is_eq(Gui.first_ordinal(Gui.history_items([prefix],Gui.empty_filters())),0),
      "history rows without an ordinal retain the record zero fallback")

def filters() -> IO(Unit):
  +filtered = Gui.form_text(Gui.replace_ui(state(),UI.set_query(ui(state()),"cache role:assistant after:2026-10-01 provider:codex")))
  do IO<Unit>:
    Unit <- require(String.eq(wanted(filtered),"search|cache|codex||assistant|2026-10-01"),"GUI filters reach literal CLI argv")
    Unit <- require(String.eq(blame_result(Gui.blame_fields(String.split("/tmp/a repo|src/file.txt|3|4",'|'))),"blame|/tmp/a repo|src/file.txt|3|6"),"Blame count converts to exact end line")
    require(String.eq(blame_result(Gui.blame_fields(String.split("/tmp/repo|../escape|x|4",'|'))),"error"),"invalid Blame quantities are rejected")

def result_items(s: Gui.State) -> List<&2,Gui.Item>:
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,displayed,args,filters},form,jobs,refresh_at,serial} = s
  items

def revision(s: Gui.State) -> U32:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = s
  revision

def ui_status(s: UI.State) -> String:
  UI.State{UI.Content{query,rows,reader,lines,title,status,scope},input,image,dirty} = s
  status

def state_status(s: Gui.State) -> String:
  ui_status(ui(s))

def scoped_state() -> Gui.State:
  +old = Gui.with_rows(state(),[Gui.Item{"7",0,"Claude old","claude","/tmp/repo","1",Gui.empty_filters()}])
  Gui.scope_changed(Gui.replace_ui(old,UI.set_scope(ui(old),"codex")))

def result_invalidation() -> IO(Unit):
  require(List.is_empty(&2,Gui.Item,result_items(scoped_state())),"new scope clears actionable old results")

def click_invalidation() -> IO(Unit):
  +scoped = scoped_state()
  +clicked = Gui.open_item(scoped,Gui.select_item(result_items(scoped),0n))
  require(String.eq(wanted(clicked),"search|needle|codex|||") && String.eq(snapshot(clicked),"7"),"old click cannot cancel scoped search or pinned reader")

def caret_preserved() -> IO(Unit):
  require(String.eq(UI.query(UI.insert(ui(Gui.text_done(state(),Gui.Request{3,[],"7",0,"page"},Done{"page"})),"X")),"needleX"),"transcript arrival preserves search insertion point")

def blame_shown() -> Gui.State:
  Gui.text_done(state(),Gui.Request{5,["blame","/tmp/repo","file","1","2"],"",0,"Blame"},Done{"file evidence"})

def blame_pending() -> Gui.State:
  Gui.blame_result(blame_shown(),Done{["blame","/tmp/repo","file","1","2"]})

def why_blame() -> IO(Unit):
  +checked = Gui.why(blame_shown())
  require(String.eq(wanted(checked),"why-file|/tmp/repo|file|1|2"),"Why on Blame uses the displayed file/range")

def blame_edit() -> IO(Unit):
  +pending = blame_pending()
  +edited = Gui.form_text(Gui.replace_ui(pending,UI.set_query(ui(pending),"changed")))
  require(String.eq(wanted(edited),"none") && U32.is_gt(revision(edited),revision(pending)),"editing Blame invalidates pending evidence")

def blame_bad() -> IO(Unit):
  +pending = blame_pending()
  +bad = Gui.blame_result(pending,Fail{"invalid"})
  require(String.eq(wanted(bad),"none") && U32.is_gt(revision(bad),revision(pending)),"invalid Blame input invalidates pending evidence")

def blame_page() -> IO(Unit):
  require(String.eq(wanted(Gui.paging(blame_shown(),True{})),"none"),"Blame paging cannot silently open old transcript")

def why_paging() -> IO(Unit):
  +shown = Gui.text_done(state(),Gui.Request{4,["why","7","20","20"],"7",20,"Why"},Done{"recorded evidence"})
  require(String.eq(wanted(Gui.paging(shown,True{})),"why-scope|7|40|20||||"),"Why paging keeps evidence mode and bounded count")

def export_selection() -> IO(Unit):
  require(String.eq(String.join(Gui.export_args(5,"old",0,Gui.empty_filters(),"immutable displayed evidence","/tmp/export.md"),"|"),
    "export-displayed|/tmp/export.md|immutable displayed evidence"),"Blame export carries exact displayed evidence without rerunning Git")

def selected_filters(s: Gui.State) -> Query.Filters:
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,displayed,args,filters},form,jobs,refresh_at,serial} = s
  filters

def scope_values() -> Query.Filters:
  Query.Filters{"","codex","/tmp/repo","assistant","2026-10-01"}

def scoped_shown() -> Gui.State:
  Gui.text_done(state(),Gui.Request{3,
    ["session-scope","8","4","40","codex","/tmp/repo","assistant","2026-10-01"],"8",4,"Scoped"},Done{"only eligible evidence"})

def selected_scope_open() -> IO(Unit):
  require(String.eq(wanted(Gui.open_item(state(),Some{Gui.Item{"8",4,"scoped","codex","/tmp/repo","2",scope_values()}})),
    "session-scope|8|4|40|codex|/tmp/repo|assistant|2026-10-01"),"opening a result uses its frozen provider repo role date scope")

def selected_scope_paging() -> IO(Unit):
  +shown = scoped_shown()
  +changed = Gui.form_text(Gui.replace_ui(shown,UI.set_query(ui(shown),"other role:user provider:claude")))
  require(String.eq(wanted(Gui.paging(changed,True{})),"session-scope|8|44|40|codex|/tmp/repo|assistant|2026-10-01"),
    "new search scope cannot change the pinned reader page scope")

def selected_scope_export() -> IO(Unit):
  require(String.eq(String.join(Gui.export_args(3,"8",4,selected_filters(scoped_shown()),"shown","/tmp/output.md"),"|"),
    "export-range-scope|8|4|40|codex|/tmp/repo|assistant|2026-10-01|/tmp/output.md"),"transcript export carries the selected scope")

def selected_scope_why() -> IO(Unit):
  require(String.eq(wanted(Gui.why(scoped_shown())),"why-scope|8|4|20|codex|/tmp/repo|assistant|2026-10-01"),
    "Why carries the selected scope")

def commit_why_form() -> IO(Unit):
  require(String.eq(wanted(Gui.blame_result(state(),Gui.blame_fields(String.split(
    "/tmp/repo|commit:0123456789abcdef0123456789abcdef01234567",'|')))),
    "why-commit|/tmp/repo|0123456789abcdef0123456789abcdef01234567"),"exact commit Why form uses literal repository and full SHA")

def writer_pending(value: Maybe<&2,Gui.Pending>) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{pending}:
      True{}

def has_writer(s: Gui.State) -> Bool:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = s
  writer_pending(writer)

def automatic_forms() -> IO(Unit):
  do IO<Unit>:
    next : Gui.State <- Gui.auto_refresh(Gui.settings(state()),60000n)
    require(Bool.not(has_writer(next)),"automatic refresh never starts from a source form")

def automatic_notice() -> IO(Unit):
  require(String.eq(state_status(Gui.automatic_success(Gui.status(Gui.settings(state()),"explicit capture failed"),1,Json.JNull{})),
    "explicit capture failed"),"background success preserves actionable form failure")

def usage_range() -> IO(Unit):
  require(String.eq(wanted(Gui.usage(state())),"usage|7|0|40"),"Usage binds the selected captured range")

def usage_scope_guard() -> IO(Unit):
  require(String.eq(wanted(Gui.usage(scoped_shown())),"none") &&
    String.contains(state_status(Gui.usage(scoped_shown())),"Clear repository, role and date"),
    "Usage does not silently widen a repository role date scope")

def writer_command(value: Maybe<&2,Gui.Pending>) -> String:
  match value:
    case None{}:
      "none"
    case Some{Gui.Pending{ticket,Gui.Request{kind,args,snapshot,start,title},channel}}:
      String.join(args,"|")

def writer_args(s: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = s
  writer_command(writer)

def rebuild_gate() -> IO(Unit):
  do IO<Unit>:
    next : Gui.State <- Gui.rebuild(state())
    require(Bool.not(has_writer(next)),"rebuild requires the explicit Settings view")

def rebuild_snapshot() -> IO(Unit):
  do IO<Unit>:
    next : Gui.State <- Gui.rebuild(Gui.settings(state()))
    require(String.eq(writer_args(next),"rebuild|7"),"Settings rebuild binds the shown captured snapshot")

def deadline(s: Gui.State) -> Nat:
  Gui.State{db,dir,program,ui,selection,form,jobs,refresh_at,serial} = s
  refresh_at

def clean(s: Gui.State) -> Gui.State:
  Gui.State{db,dir,program,UI.State{content,input,image,dirty},selection,form,jobs,refresh_at,serial} = s
  Gui.State{db,dir,program,UI.State{content,input,image,False{}},selection,form,jobs,refresh_at,serial}

def refresh_clock() -> IO(Unit):
  do IO<Unit>:
    +armed : Gui.State <- Gui.auto_refresh(clean(state()),1000n)
    +same_time : Gui.State <- Gui.auto_refresh(armed,1000n)
    +early : Gui.State <- Gui.auto_refresh(same_time,30999n)
    +large : Gui.State <- Gui.auto_refresh(clean(state()),Nat.add(4294967295n,1n))
    Unit <- require(Nat.is_eq(deadline(armed),31000n) && Bool.not(has_writer(armed)),
      "automatic refresh arms a thirty second monotonic deadline")
    Unit <- require(Nat.is_eq(deadline(same_time),31000n) && Nat.is_eq(deadline(early),31000n) && Bool.not(has_writer(early)),
      "render frequency does not advance or postpone the refresh deadline")
    Unit <- require(Nat.is_eq(deadline(large),Nat.add(4294967295n,30001n)),
      "refresh timestamps retain milliseconds beyond the U32 boundary")
    Unit <- require(Bool.not(Gui.refresh_due(31000n,30999n)) && Gui.refresh_due(31000n,31000n),
      "refresh is due exactly at its deadline")
    require(U32.is_eq(Gui.sleep_ms(armed,False{}),80),
      "arming a refresh deadline does not dirty the settled view")

def refresh_resume() -> IO(Unit):
  +armed = Gui.refresh_deadline(clean(state()),31000n)
  do IO<Unit>:
    +paused : Gui.State <- Gui.auto_refresh(Gui.toggle_pause(armed),90000n)
    +resumed : Gui.State <- Gui.auto_refresh(Gui.toggle_pause(paused),100000n)
    +source : Gui.State <- Gui.auto_refresh(Gui.settings(armed),90000n)
    +blame : Gui.State <- Gui.auto_refresh(Gui.selected_file_form(armed,"/tmp/repo|file|1|1"),90000n)
    +backwards : Gui.State <- Gui.auto_refresh(Gui.refresh_deadline(armed,50000n),1000n)
    Unit <- require(Nat.is_eq(deadline(paused),0n) && Bool.not(has_writer(paused)),
      "pause disarms automatic refresh even after the deadline")
    Unit <- require(Nat.is_eq(deadline(resumed),130000n) && Bool.not(has_writer(resumed)),
      "resume starts a full interval rather than catching up missed refreshes")
    Unit <- require(Nat.is_eq(deadline(source),0n) && Nat.is_eq(deadline(blame),0n) && Bool.not(has_writer(blame)),
      "source and Blame forms disarm automatic refresh")
    require(Nat.is_eq(deadline(backwards),31000n) && Bool.not(has_writer(backwards)),
      "a reversed clock rearms conservatively")

def reader_pending(+s: Gui.State) -> Gui.State:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,+writer,paused},refresh_at,serial} = s
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,writer,None{},paused},refresh_at,serial}

def refresh_writer() -> IO(Unit):
  do IO<Unit>:
    +started : Gui.State <- Gui.auto_refresh(Gui.refresh_deadline(clean(state()),31000n),31000n)
    +busy : Gui.State <- Gui.auto_refresh(started,90000n)
    +completed : Gui.State <- Gui.auto_refresh(clean(Gui.clear_writer(busy)),90000n)
    Unit <- require(String.eq(writer_args(started),"refresh-all") && Nat.is_eq(deadline(started),0n),
      "due automatic refresh starts one bounded production writer")
    Unit <- require(String.eq(writer_args(busy),"refresh-all") && Nat.is_eq(deadline(busy),0n),
      "an outstanding writer prevents another scheduled capture")
    Unit <- require(Nat.is_eq(deadline(completed),120000n) && Bool.not(has_writer(completed)),
      "writer completion receives a fresh interval without a catch-up burst")
    Unit <- require(U32.is_eq(Gui.sleep_ms(clean(busy),False{}),1),
      "pending writer keeps the fast polling cadence")
    require(U32.is_eq(Gui.sleep_ms(clean(reader_pending(busy)),False{}),1),
      "pending reader keeps the fast polling cadence")

def idle_pacing() -> IO(Unit):
  +settled = clean(state())
  +queued = clean(Gui.queue(settled,Gui.Request{1,["history","",""],"",0,"History"}))
  do IO<Unit>:
    Unit <- require(U32.is_eq(Gui.sleep_ms(settled,False{}),80),
      "only a settled event-free view uses the bounded idle delay")
    Unit <- require(U32.is_eq(Gui.sleep_ms(settled,True{}),1),
      "input batches retain the fast cadence even without a dirty view")
    Unit <- require(U32.is_eq(Gui.sleep_ms(Gui.status(settled,"reply arrived"),False{}),1),
      "a worker reply requiring repaint bypasses the idle delay")
    require(U32.is_eq(Gui.sleep_ms(queued,False{}),1),
      "queued reader work bypasses the idle delay")

def main() -> IO(Unit):
  do IO<Unit>:
    forms()
    readers()
    initial()
    initial_late_hit()
    history_ordinal()
    filters()
    result_invalidation()
    click_invalidation()
    caret_preserved()
    why_blame()
    blame_edit()
    blame_bad()
    blame_page()
    why_paging()
    export_selection()
    selected_scope_open()
    selected_scope_paging()
    selected_scope_export()
    selected_scope_why()
    commit_why_form()
    automatic_forms()
    automatic_notice()
    usage_range()
    usage_scope_guard()
    rebuild_gate()
    rebuild_snapshot()
    refresh_clock()
    refresh_resume()
    refresh_writer()
    idle_pacing()
    IO.print("PASS GUI coordinator contracts; native interaction is separate")
