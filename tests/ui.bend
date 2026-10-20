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
  +dragged = apply(Move{272, 64}, apply(Mouse{240, 64, 0, True{}}, UI.set_query(UI.init(), "A🙂B")))
  +command_reader = apply(Key{65591, True{}}, reader)
  +wrapped = UI.wrap("012345678901234567890123456789012345678901234567X\nZ")
  do IO<Unit>:
    Unit <- require(String.eq(UI.query(typed), "naive cafe é 漢字 🙂"), "committed Unicode Text event")
    Unit <- require(String.eq(UI.selection(selected), "naive cafe é 漢字 🙂"), "query select-all preserves Unicode")
    Unit <- require(String.eq(UI.query(placed), "Aé🙂B"), "cursor insertion counts Unicode scalars")
    Unit <- require(String.eq(UI.query(UI.backspace(placed)), "A🙂B"), "backspace deletes selected scalar")
    Unit <- require(String.eq(UI.selection(reader), "é 漢字 🙂\nsecond"), "reader copy retains combining CJK emoji")
    Unit <- line_test(UI.line_at(wrapped, 1), 48, "X", "wrap retains source offset")
    Unit <- line_test(UI.line_at(wrapped, 2), 50, "Z", "newline retains source offset")
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

def buttons() -> IO(Unit):
  +reader = UI.select_all(UI.set_edit(UI.set_reader(UI.init(),"Unicode","é 漢字 🙂"),UI.Edit{2,0,0,False{}, 0}))
  +query = UI.select_all(UI.set_query(UI.init(),"replace me"))
  do IO<Unit>:
    Unit <- require(String.eq(copied(UI.sidebar_action(reader,30)),"é 漢字 🙂"),"pointer Copy retains selected reader Unicode")
    Unit <- require(button_paste(UI.sidebar_action(query,33)),"pointer Paste requests clipboard input")
    Unit <- require(String.eq(UI.selection(changed(UI.sidebar_action(query,33))),"replace me"),"pointer Paste preserves query replacement selection")
    Unit <- require(String.eq(UI.query(changed(UI.sidebar_action(query,36))),""),"pointer Clear empties query")
    require(String.eq(UI.selection(changed(UI.sidebar_action(UI.set_query(UI.init(),"whole query"),39))),"whole query"),"pointer Select all uses focused text")

def long_drag() -> IO(Unit):
  +pressed = apply(Mouse{224,64,0,True{}},UI.set_query(UI.init(),repeat(10n,"0123456789")))
  +moved = apply(Move{384,64},pressed)
  +arrival = UI.set_reader(pressed,"new reader","asynchronous evidence")
  do IO<Unit>:
    Unit <- require(U32.is_eq(UI.query_offset(pressed),30) && U32.is_eq(UI.query_offset(moved),30) &&
      String.eq(UI.selection(moved),"0123456789"),"long query drag freezes its original viewport")
    require(String.eq(UI.selection(apply(Move{384,64},arrival)),"0123456789"),"reader arrival preserves an active query drag")

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

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
