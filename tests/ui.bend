import Base
import ../src/ui.bend as UI

def require(ok: Bool, name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print(String.append("PASS ", name))
    case False{}:
      IO.die(Unit, 1, String.append("FAIL ", name))

def changed(result: UI.State & UI.Action) -> UI.State:
  (state, action) = result
  state

def apply(e: Event, state: UI.State) -> UI.State:
  changed(UI.event(e, state))

def line_test(line: UI.Line, +expected: U32, text: String, name: String) -> IO(Unit):
  UI.Line{start, actual} = line
  require(U32.is_eq(start, expected) && String.eq(actual, text), name)

def repeat(n: Nat, +s: String) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      String.append(s, repeat(p, s))

def copied(result: UI.State & UI.Action) -> String:
  (state, action) = result
  match action:
    case UI.Copy{text}:
      text
    case _:
      ""

def tests() -> IO(Unit):
  +typed = apply(Text{"naive cafe é 漢字 🙂"}, UI.init())
  +selected = UI.select_all(typed)
  +edited = UI.insert(selected, "A🙂B")
  +mid = UI.move_caret(UI.move_caret(edited, False{}), False{})
  +placed = UI.insert(mid, "é")
  +reader = UI.select_all(UI.set_edit(UI.set_reader(UI.init(), "Unicode", "é 漢字 🙂\nsecond"), UI.Edit{2, 0, 0, False{}, 0}))
  +dragged = apply(Move{232, 40}, apply(Mouse{216, 40, 0, True{}}, UI.set_query(UI.init(), "A🙂B")))
  +command_reader = apply(Key{65591, True{}}, reader)
  +wrapped = UI.wrap(repeat(104n,"x") ++ "X\nZ")
  do IO<Unit>:
    Unit <- require(String.eq(UI.query(typed), "naive cafe é 漢字 🙂"), "committed Unicode Text event")
    Unit <- require(String.eq(UI.selection(selected), "naive cafe é 漢字 🙂"), "query select-all preserves Unicode")
    Unit <- require(String.eq(UI.query(placed), "Aé🙂B"), "cursor insertion counts Unicode scalars")
    Unit <- require(String.eq(UI.query(UI.backspace(placed)), "A🙂B"), "backspace deletes selected scalar")
    Unit <- require(String.eq(UI.selection(reader), "é 漢字 🙂\nsecond"), "reader copy retains combining CJK emoji")
    Unit <- line_test(UI.line_at(wrapped, 1), 104, "X", "wrap retains source offset")
    Unit <- line_test(UI.line_at(wrapped, 2), 106, "Z", "newline retains source offset")
    Unit <- require(U32.is_eq(UI.length(UI.query(UI.insert(UI.init(), repeat(600n, "x")))), 512), "query input limit is explicit")
    Unit <- require(String.eq(UI.scope(UI.set_scope(UI.init(), "codex")), "codex"), "provider scope reaches UI state")
    Unit <- require(String.eq(UI.query(apply(Key{97, True{}}, UI.init())), ""), "physical keys never fabricate typed characters")
    Unit <- require(String.eq(UI.selection(dragged), "🙂B"), "query drag maps screen cells to Unicode offsets")
    Unit <- require(String.eq(copied(UI.event(Key{99, True{}}, command_reader)), "é 漢字 🙂\nsecond"), "Command-C emits exact selected text")
    IO.print("PASS native UI pure contracts (native interaction separate)")

def button_paste(result: UI.State & UI.Action) -> Bool:
  (state,action) = result
  match action:
    case UI.Paste{}:
      True{}
    case _:
      False{}

def button_export(result: UI.State & UI.Action) -> String:
  (state,action) = result
  match action:
    case UI.WholeExport{}: "full-jsonl"
    case UI.ContainerExport{}: "archive"
    case _: ""

def buttons() -> IO(Unit):
  +reader = UI.select_all(UI.set_edit(UI.set_reader(UI.init(),"Unicode","é 漢字 🙂"),UI.Edit{2,0,0,False{}, 0}))
  +query = UI.select_all(UI.set_query(UI.init(),"replace me"))
  +settings = UI.set_results(UI.select_all(UI.set_query(UI.init(),"café 中文 🙂")),UI.SettingsResults{0,0,"Resume",True{}})
  do IO<Unit>:
    Unit <- require(String.eq(copied(UI.event(Mouse{16,696,0,True{}},reader)),"é 漢字 🙂"),"pointer Copy retains selected reader Unicode")
    Unit <- require(String.eq(button_export(UI.event(Mouse{16,728,0,True{}},query)),"full-jsonl"),"normal sidebar pointer requests full JSONL export")
    Unit <- require(String.eq(button_export(UI.event(Mouse{16,792,0,True{}},reader)),"archive") && String.eq(UI.selection(changed(UI.event(Mouse{16,792,0,True{}},reader))),"é 漢字 🙂"),"normal sidebar pointer requests archive export without changing reader selection")
    Unit <- require(button_paste(UI.event(Mouse{1112,136,0,True{}},query)),"reader toolbar pointer Paste requests clipboard input")
    Unit <- require(String.eq(UI.selection(changed(UI.event(Mouse{1112,136,0,True{}},query))),"replace me"),"reader toolbar pointer Paste preserves query replacement selection")
    Unit <- require(String.eq(UI.query(changed(UI.event(Mouse{16,760,0,True{}},query))),""),"pointer Clear empties query")
    Unit <- require(String.eq(UI.selection(changed(UI.event(Mouse{1304,136,0,True{}},UI.set_query(UI.init(),"whole query")))),"whole query"),"reader toolbar pointer Select all uses focused text")
    Unit <- require(button_paste(UI.event(Mouse{1112,136,0,True{}},settings)) && String.eq(UI.selection(changed(UI.event(Mouse{1112,136,0,True{}},settings))),"café 中文 🙂"),"Settings pointer Paste retains exact Unicode replacement selection")
    require(String.eq(UI.selection(changed(UI.event(Mouse{16,792,0,True{}},UI.set_edit(settings,UI.Edit{0,2,1,False{},0})))),"café 中文 🙂"),"Settings sidebar pointer Select all expands a partial Unicode selection")

def long_drag() -> IO(Unit):
  +pressed = apply(Mouse{208,40,0,True{}},UI.set_query(UI.init(),repeat(20n,"0123456789")))
  +moved = apply(Move{288,40},pressed)
  +arrival = UI.set_reader(pressed,"new reader","asynchronous evidence")
  do IO<Unit>:
    Unit <- require(U32.is_eq(UI.query_offset(pressed),56) && U32.is_eq(UI.query_offset(moved),56) &&
      String.eq(UI.selection(moved),"6789012345"),"long query drag freezes its original viewport")
    require(String.eq(UI.selection(apply(Move{288,40},arrival)),"6789012345"),"reader arrival preserves an active query drag")

def navigation_kind(result: UI.State & UI.Action) -> U32:
  (state,action) = result
  match action:
    case UI.ListPrevious{}:
      1
    case UI.ListNext{}:
      2
    case UI.Previous{}:
      3
    case UI.Next{}:
      4
    case UI.Open{index}:
      5
    case UI.Versions{}:
      6
    case UI.OpenLatest{}:
      7
    case UI.Storage{}:
      8
    case UI.Files{}:
      9
    case UI.RepoOpen{}:
      10
    case UI.RepoParent{}:
      11
    case UI.Tools{}:
      12
    case UI.Related{}:
      13
    case UI.Back{}:
      14
    case _:
      0

def related_navigation() -> IO(Unit):
  +state = UI.set_results(UI.init(),UI.RelatedResults{2,0,True{},True{}})
  +original = UI.set_edit(UI.set_position(UI.set_reader(UI.init(),"title","Unicode café 🙂"),3,8),UI.Edit{2,8,2,True{},4})
  +restored = UI.restore(UI.init(),UI.bookmark(UI.set_modifiers(original,True{},True{})))
  do IO<Unit>:
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,416,0,True{}},state)),13) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{32,832,0,True{}},state)),14),"Related and Back have dedicated nonoverlapping pointer controls")
    require(U32.is_eq(navigation_kind(UI.event(Key{103,True{}},UI.set_modifiers(state,True{},False{}))),13) &&
      U32.is_eq(navigation_kind(UI.event(Key{91,True{}},UI.set_modifiers(state,True{},False{}))),14),"Command-G and Command-left-bracket navigate Related and Back")
    require(String.eq(UI.result_label(UI.RelatedResults{2,0,True{},True{}}),"Page 2 | 0 links") &&
      UI.result_available(UI.RelatedResults{2,0,True{},True{}},True{}),"empty Related page preserves continuation without claiming no relatives")
    require(U32.is_eq(UI.selected(restored),3) && U32.is_eq(UI.scroll(restored),8) &&
      String.eq(UI.selection(restored),UI.selection(original)),"bookmark preserves exact row scroll and Unicode character selection")
    require(U32.is_eq(navigation_kind(UI.event(Key{103,True{}},restored)),0),"bookmark restoration clears transient command state")

def result_navigation() -> IO(Unit):
  +first = UI.set_results(UI.set_rows(UI.init(),["one result"]),UI.Results{0,100,True{},True{}})
  +last = UI.set_results(first,UI.Results{100,1,False{},True{}})
  +pending = UI.set_results(first,UI.Results{100,0,False{},False{}})
  do IO<Unit>:
    require(U32.is_eq(navigation_kind(UI.event(Mouse{400,832,0,True{}},first)),2),
      "result Next control emits a distinct list action")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{208,832,0,True{}},last)),1),
      "result Previous control emits a distinct list action")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{208,832,0,True{}},first)),0) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{400,832,0,True{}},last)),0),
      "result controls are inert at first and final boundaries")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{208,832,0,True{}},pending)),0) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{400,832,0,True{}},pending)),0),
      "pending result navigation is disabled")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{1064,96,0,True{}},first)),3) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{1224,96,0,True{}},first)),4),
      "transcript toolbar paging remains separate")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{208,144,0,True{}},first)),0) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{208,248,0,True{}},first)),0),
      "list header and blank rows cannot select nonexistent results")
    require(String.eq(UI.result_label(UI.Results{0,0,False{},True{}}),"No results") &&
      String.eq(UI.result_label(UI.Results{200,0,False{},True{}}),"No results after 200"),
      "result labels distinguish empty first and later pages")
    require(String.eq(UI.result_label(UI.Results{100,100,True{},True{}}),"101-200 + more") &&
      String.eq(UI.result_label(UI.Results{200,1,False{},True{}}),"201-201 / end"),
      "result range labels use global ordinal ranges")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,448,0,True{}},first)),6) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{32,480,0,True{}},first)),7),
      "saved versions and explicit latest have distinct pointer actions")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,600,0,True{}},first)),8),
      "Storage inventory has a dedicated Settings action")

def files_navigation() -> IO(Unit):
  +files = UI.set_files(UI.init(),True{})
  do IO<Unit>:
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,144,0,True{}},UI.init())),9) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{32,144,0,True{}},files)),9),
      "Files and History share a dedicated sidebar target")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,96,0,True{}},files)),10),
      "Files exposes explicit Open repo instead of capture Refresh")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{208,128,0,True{}},files)),11) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{208,128,0,True{}},UI.init())),0),
      "Up folder occupies only the Files list header")
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,600,0,True{}},files)),8) &&
      U32.is_eq(navigation_kind(UI.event(Mouse{32,448,0,True{}},files)),6),
      "Files controls preserve Storage and Versions hit targets")

def tools_navigation() -> IO(Unit):
  +state = UI.set_query(UI.init(),"literal query")
  do IO<Unit>:
    require(U32.is_eq(navigation_kind(UI.event(Mouse{32,352,0,True{}},state)),12),
      "Tools has a distinct sidebar row below Scope")
    require(U32.is_eq(navigation_kind(UI.event(Key{116,True{}},UI.set_modifiers(state,True{},False{}))),12),
      "Command-T opens recorded Tools")
    require(String.eq(UI.query(changed(UI.event(Key{116,True{}},UI.set_modifiers(state,True{},False{})))),"literal query") &&
      U32.is_eq(navigation_kind(UI.event(Key{116,True{}},state)),0),
      "Tools shortcut preserves query and plain T is not a command")

def settings_action(result: UI.State & UI.Action) -> String:
  (state,action) = result
  match action:
    case UI.SettingsAddFolder{}: "add"
    case UI.SettingsImportFile{}: "import"
    case UI.SettingsEnable{}: "enable"
    case UI.SettingsDisable{}: "disable"
    case UI.SettingsReload{}: "reload"
    case UI.SettingsInterval{seconds}: U32.show(seconds)
    case UI.Refresh{}: "refresh"
    case UI.Pause{}: "automatic"
    case UI.Settings{}: "back"
    case UI.Rebuild{}: "rebuild"
    case _: "other"

def settings_navigation() -> IO(Unit):
  +state = UI.set_results(UI.init(),UI.SettingsResults{0,32,"Pause",True{}})
  do IO<Unit>:
    require(String.eq(UI.result_label(UI.SettingsResults{0,0,"Loading",False{}}),"Inventory not loaded") &&
      String.eq(UI.result_label(UI.SettingsResults{0,0,"Pause",True{}}),"No registered folders"),"unloaded source inventory is distinct from confirmed empty inventory")
    require(String.eq(settings_action(UI.event(Mouse{32,96,0,True{}},state)),"refresh") &&
      String.eq(settings_action(UI.event(Mouse{224,96,0,True{}},state)),"automatic"),"Settings retains independent manual Refresh and durable automatic controls")
    require(String.eq(settings_action(UI.event(Mouse{416,96,0,True{}},state)),"add") &&
      String.eq(settings_action(UI.event(Mouse{608,96,0,True{}},state)),"import"),"Settings Add folder and Import file have distinct hit targets")
    require(String.eq(settings_action(UI.event(Mouse{800,96,0,True{}},state)),"enable") &&
      String.eq(settings_action(UI.event(Mouse{1064,96,0,True{}},state)),"disable"),"Settings Enable and Disable are separate selected-row actions")
    require(String.eq(settings_action(UI.event(Mouse{1224,96,0,True{}},state)),"reload"),"Settings Reload has its own toolbar target")
    require(String.eq(settings_action(UI.event(Mouse{32,568,0,True{}},state)),"30") &&
      String.eq(settings_action(UI.event(Mouse{32,600,0,True{}},state)),"7200"),"Settings exposes exact thirty-second and two-hour choices")
    require(String.eq(settings_action(UI.event(Mouse{32,632,0,True{}},state)),"14400") &&
      String.eq(settings_action(UI.event(Mouse{32,696,0,True{}},state)),"28800") &&
      String.eq(settings_action(UI.event(Mouse{32,728,0,True{}},state)),"86400"),"Settings exposes exact four-hour eight-hour and daily choices")
    require(String.eq(settings_action(UI.event(Mouse{32,144,0,True{}},state)),"back") &&
      String.eq(settings_action(UI.event(Mouse{32,832,0,True{}},state)),"rebuild"),"Settings keeps its first Back control and reachable final Rebuild action")
    require(UI.result_available(UI.SettingsResults{0,32,"Pause",True{}},True{}) &&
      Bool.not(UI.result_available(UI.SettingsResults{28,32,"Pause",True{}},True{})) &&
      String.eq(UI.result_label(UI.SettingsResults{28,32,"Pause",True{}}),"29-32/32"),"Settings folder paging reaches all thirty-two bounded rows and stops at the end")

def after_clipboard(result: Result<&1, &1, U32 & String, U32 & (String & String)>, state: UI.State) -> IO(Maybe<UI.State>):
  match result:
    case Fail{(code, message)}:
      IO.pure(Maybe<UI.State>, Some{UI.set_status(state, "Clipboard failed")})
    case Done{(0, out)}:
      IO.pure(Maybe<UI.State>, Some{UI.set_status(state, "Selected Unicode copied")})
    case Done{(code, out)}:
      IO.pure(Maybe<UI.State>, Some{UI.set_status(state, "Clipboard returned nonzero")})

def after_paste(result: Result<&1, &1, U32 & String, U32 & (String & String)>, state: UI.State) -> IO(Maybe<UI.State>):
  match result:
    case Fail{error}:
      IO.pure(Maybe<UI.State>, Some{UI.set_status(state, "Paste failed")})
    case Done{(0, (text, error))}:
      IO.pure(Maybe<UI.State>, Some{UI.insert(state, text)})
    case Done{other}:
      IO.pure(Maybe<UI.State>, Some{UI.set_status(state, "Paste returned nonzero")})

def probe_action(result: UI.State & UI.Action) -> IO(Maybe<UI.State>):
  (state, action) = result
  match action:
    case UI.Quit{}:
      IO.pure(Maybe<UI.State>, None{})
    case UI.Copy{text}:
      do IO<Maybe<UI.State>>:
        result : Result<&1, &1, U32 & String, U32 & (String & String)> <- UI.clipboard_copy(text)
        after_clipboard(result, state)
    case UI.CopyStatus{text}:
      do IO<Maybe<UI.State>>:
        result : Result<&1, &1, U32 & String, U32 & (String & String)> <- UI.clipboard_copy(text)
        after_clipboard(result, state)
    case UI.Paste{}:
      do IO<Maybe<UI.State>>:
        result : Result<&1, &1, U32 & String, U32 & (String & String)> <- UI.clipboard_paste()
        after_paste(result, state)
    case UI.Search{}:
      IO.pure(Maybe<UI.State>, Some{UI.set_status(state, "Committed text received. This is the isolated UI probe.")})
    case _:
      IO.pure(Maybe<UI.State>, Some{state})

def probe_tick(events: List<Event>, state: UI.State) -> IO(Maybe<UI.State>):
  match events:
    case []:
      IO.pure(Maybe<UI.State>, Some{state})
    case event <> rest:
      IO.bind(Maybe<UI.State>, Maybe<UI.State>, probe_action(UI.event(event, state)),
        next => App.more(UI.State, s => probe_tick(rest, s), next))

def probe() -> IO(Unit):
  s = UI.set_reader(UI.set_rows(UI.init(), ["Synthetic native input probe"]), "Native text / selection probe",
    String.append("USER\nThis is an isolated native Bend UI probe.\n\nType in Search. Cmd+A selects the query.\nCmd+C copies selection; Cmd+V pastes.\n\nUnicode survives selection and clipboard:\né cafe 漢字 🙂\nUnsupported glyphs appear as boxes.\n\nClick and drag in this reader to select.\n\nScroll to exercise the bounded reader.\n\n", repeat(50n, "Captured synthetic transcript line.\n")))
  App.run(~UI.State, ~App{UI.view, probe_tick}, "Juice Bend UI Probe", 1408, 896, s)

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case program <> "--probe" <> rest:
      probe()
    case _:
      do IO<Unit>:
        tests()
        buttons()
        long_drag()
        result_navigation()
        files_navigation()
        tools_navigation()
        related_navigation()
        settings_navigation()

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
