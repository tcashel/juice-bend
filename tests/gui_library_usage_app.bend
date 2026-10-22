import Base
import ../src/gui.bend as G
import ../src/gui_files.bend as Files
import ../src/gui_library_usage.bend as Model
import ../src/ui.bend as UI
import ../src/json.bend as J
import ../src/query.bend as Query
import ../src/session_usage.bend as S
import ../src/library_usage_screen.bend as Screen
import ../src/gui_command_route.bend as Route
import ../src/reader_document.bend as Doc
import ../src/reader_cards.bend as Cards
import ../src/reader_wire.bend as Wire
import ../src/reader_projection.bend as Projection
import ../src/ui_geometry.bend as Geometry
import ../src/bend_ui/text_line.bend as Prose

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(text: String) -> J.Json: parsed(J.parse(text))

def capture() -> S.Capture:
  S.Capture{"claude","42","/synthetic/café 中文 🙂.jsonl","2","92",9000,45}

def row() -> String:
  "{\"capture\":" ++ S.capture_text(capture()) ++ ",\"session\":\"exact-session\",\"sha256\":\"" ++ String.repeat("a",64n) ++
    "\",\"category\":\"ordinary\",\"counts\":{\"input\":\"9007199254740993\",\"cached\":\"0\",\"created\":\"2\",\"created1h\":\"\",\"output\":\"3\"},\"status\":\"eligible\",\"reason\":\"Retained evidence verified\"}"

def report(nonce: U32) -> J.Json:
  json("{\"kind\":\"library_usage\",\"version\":1,\"nonce\":" ++ U32.show(nonce) ++
    ",\"catalog_complete\":true,\"selected_sources\":1,\"verified_records\":45,\"verified_bytes\":9000,\"limits\":{\"sources\":256,\"records\":1000000,\"bytes\":134217728},\"rows\":[" ++ row() ++ "]}")

def origin_ui() -> UI.State:
  UI.set_edit(UI.set_position(UI.set_results(UI.set_rows(UI.set_scope(UI.set_reader(UI.set_query(UI.init(),
    "needle repo:/synthetic role:user"),"Origin","Original café 中文 🙂\nretained evidence"),"codex"),["first","chosen"]),
    UI.Results{100,2,True{},True{}}),1,7),UI.Edit{2,20,3,False{},0})

def origin() -> G.State:
  G.State{0,"/tmp/juice-bend-gui-library-usage","/usr/bin/false",origin_ui(),
    G.Selection{[],"7",40,3,[],Query.Filters{"","codex","/synthetic","user","2026-10-20"},G.empty_listing()},
    G.Form{0,"needle repo:/synthetic role:user","","",Files.empty(),[],[]},G.Jobs{9,None{},None{},None{},False{}},60000n,0}

def ui(state: G.State) -> UI.State:
  G.State{_,_,_,ui,_,_,_,_,_} = state
  ui

def request_value(value: Maybe<&2,G.Request>) -> G.Request:
  match value:
    case Some{value}: value
    case None{}: G.Request{0,[],"",0,""}

def request(state: G.State) -> G.Request:
  G.State{_,_,_,_,_,_,G.Jobs{_,wanted,_,_,_},_,_} = state
  request_value(wanted)

def args(value: G.Request) -> String:
  G.Request{_,args,_,_,_} = value
  String.join(args,"|")

def wanted(state: G.State) -> String: args(request(state))

def phase(+state: G.State) -> U32: G.library_phase(G.navigation(state))

def selected(state: G.State) -> String:
  G.State{_,_,_,_,G.Selection{_,snapshot,start,kind,_,Query.Filters{q,p,r,role,after},_},_,_,_,_} = state
  String.join([snapshot,U32.show(start),U32.show(kind),q,p,r,role,after],"|")

def position(state: UI.State) -> String:
  UI.State{_,UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,drag,viewport},_,_},_,_} = state
  String.join([U32.show(selected),U32.show(scroll),U32.show(focus),U32.show(caret),U32.show(anchor),U32.show(viewport)],"|")

def pending() -> G.State: G.library_enter(origin())

def apply(+state: G.State,value: J.Json) -> G.State:
  G.read_done(state,request(state),Done{value})

def loaded() -> G.State: apply(pending(),report(10))

def opening() -> G.State: G.library_open(loaded(),0)

def text() -> String: "Captured session café 中文 🙂\nexact canonical transcript"

def page(nonce: U32,start: U32,count: U32) -> J.Json:
  json("{\"kind\":\"library_usage_capture\",\"version\":1,\"nonce\":" ++ U32.show(nonce) ++
    ",\"capture\":" ++ S.capture_text(capture()) ++ ",\"page\":{\"snapshot\":\"92\",\"start\":" ++ U32.show(start) ++
    ",\"requested_records\":40,\"selected_records\":" ++ U32.show(count) ++
    ",\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":" ++ J.quote(text()) ++ "}}")

def shown() -> G.State: apply(opening(),page(11,0,40))

def target(value: Maybe<&2,S.Capture>) -> String:
  match value:
    case Some{value}: S.capture_text(value)
    case None{}: "none"

def summary_checks() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(wanted(pending()),"library-usage-v1|10"),"library entry queues a fresh nonce on the same executable read lane")
    check(U32.is_eq(Route.read_kind("library-usage-v1"),6) && U32.is_eq(Route.read_kind("library-usage-capture-v1"),6),"both retained library commands use the bounded wire transport")
    check(UI.is_library_usage(ui(pending())) && String.contains(UI.reader(ui(pending())),"Totals will appear when the scan finishes"),"pending overview does not show an invented zero total")
    check(String.contains(UI.reader(ui(loaded())),"9007199254740993"),"native report retains exact large decimal without abbreviation")
    check(String.contains(UI.reader(ui(loaded())),"Unknown") || String.contains(UI.reader(ui(loaded())),"unknown"),"optional missing one-hour counter remains visible as unknown")
    check(String.eq(target(Screen.selected(G.library_model(G.navigation(loaded())),0)),S.capture_text(capture())),"capture activation uses complete typed identity rather than title text")
    check(String.eq(target(Screen.selected(G.library_model(G.navigation(G.library_provider(loaded(),"codex"))),0)),"none"),"provider filtering cannot expose another provider's capture")
    check(String.eq(target(Screen.selected(G.library_model(G.navigation(G.library_provider(loaded(),"claude"))),0)),S.capture_text(capture())),"provider filtering preserves exact retained descriptor")
    check(Bool.not(String.eq(UI.reader(ui(apply(pending(),report(9)))),UI.reader(ui(pending())))),"wrong nonce yields an explicit failure view rather than loading forever")
    check(Bool.not(String.contains(UI.reader(ui(apply(pending(),report(9)))),"9007199254740993")),"wrong nonce cannot publish any summary total")

def capture_checks() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(wanted(opening()),"library-usage-capture-v1|11|" ++ S.capture_text(capture()) ++ "|0"),"open request carries exact capture and physical range")
    check(U32.is_eq(phase(opening()),5) && U32.is_eq(phase(shown()),6),"only matching captured-page acknowledgement makes the capture ready")
    check(String.eq(UI.reader(ui(shown())),text()) && String.eq(selected(shown()),"92|0|3||claude|||"),"accepted exact page preserves canonical text and source identity")
    check(String.eq(wanted(G.library_page(shown(),True{})),"library-usage-capture-v1|12|" ++ S.capture_text(capture()) ++ "|40"),"next page retains exact descriptor and advances forty physical records")
    check(String.eq(wanted(G.library_page(shown(),False{})),wanted(shown())),"previous at zero does not wrap range or queue another capture")
    check(String.eq(wanted(G.usage(shown())),"session-usage|92"),"full selected-session accounting is reachable from exact capture")
    check(String.eq(UI.reader(ui(G.library_back(shown()))),UI.reader(ui(loaded()))),"capture Back restores accepted report without rerunning the scan")
    check(U32.is_eq(phase(apply(opening(),page(12,0,40))),2) && Bool.not(String.eq(UI.reader(ui(apply(opening(),page(12,0,40)))),text())),"wrong captured nonce returns to report without accepting transcript")

def restoration_checks() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(UI.reader(ui(G.library_back(loaded()))),UI.reader(origin_ui())),"overview Back restores prior canonical reader")
    check(String.eq(position(ui(G.library_back(loaded()))),position(origin_ui())),"overview Back restores original list scroll caret and text selection")
    check(String.eq(UI.query(ui(G.library_back(loaded()))),UI.query(origin_ui())) && String.eq(selected(G.library_back(loaded())),selected(origin())),"overview Back restores original query snapshot range and all scope filters")
    check(String.eq(UI.reader(ui(G.read_done(G.library_back(pending()),request(pending()),Done{report(10)}))),UI.reader(origin_ui())),"late library completion after Back cannot replace original evidence")
    check(String.eq(UI.reader(ui(G.read_current(G.library_back(opening()),request(opening()),G.Reply{Done{page(11,0,40)}},False{}))),UI.reader(ui(loaded()))),"stale captured-page worker cannot replace restored report")
    check(Bool.not(Model.busy(G.library_model(G.navigation(G.library_cancel(pending()))))),"cancel before dispatch retires the owned queued scan")
    check(String.eq(UI.reader(ui(G.library_back(G.library_back(shown())))),UI.reader(origin_ui())),"two Back levels restore the original workspace")

def with_reader(state: G.State,channel: Chan(G.Reply)) -> G.State:
  G.State{db,dir,program,ui,selection,form,G.Jobs{+revision,wanted,_,writer,paused},deadline,serial} = state
  G.State{db,dir,program,ui,selection,form,G.Jobs{revision,None{},Some{G.Pending{revision,request_value(wanted),channel}},writer,paused},deadline,serial}

def reader(state: G.State) -> Maybe<&2,G.Pending>:
  G.State{_,_,_,_,_,_,G.Jobs{_,_,reader,_,_},_,_} = state
  reader

def has_reader(value: Maybe<&2,G.Pending>) -> Bool:
  match value:
    case Some{_}: True{}
    case None{}: False{}

def worker_checks(+channel: Chan(G.Reply)) -> IO(Unit):
  do IO<Unit>:
    check(has_reader(reader(G.library_cancel(with_reader(pending(),channel)))) &&
      Model.busy(G.library_model(G.navigation(G.library_cancel(with_reader(pending(),channel))))),
      "active cancellation keeps the single owned reader until actual terminal completion")
    check(Bool.not(Model.busy(G.library_model(G.navigation(G.read_current(G.library_cancel(with_reader(pending(),channel)),request(pending()),G.Reply{Done{report(10)}},True{}))))),
      "cancelled worker completion retires pending state")
    check(Bool.not(String.contains(UI.reader(ui(G.read_current(G.library_cancel(with_reader(pending(),channel)),request(pending()),G.Reply{Done{report(10)}},True{}))),"9007199254740993")),
      "cancelled worker completion cannot publish its totals")
    check(has_reader(reader(G.library_back(with_reader(pending(),channel)))) &&
      String.eq(UI.reader(ui(G.library_back(with_reader(pending(),channel)))),UI.reader(origin_ui())),
      "Back restores original evidence immediately while retaining owned worker retirement")
    Chan.close(G.Reply,channel)

def pending_worker() -> IO(Unit):
  do IO<Unit>:
    channel : Chan(G.Reply) <- Chan.new(G.Reply,1)
    worker_checks(channel)

def card_origin() -> G.State:
  G.replace_ui(origin(),UI.set_document(origin_ui(),"Original card",Doc.Structured{"card evidence",7,
    [Doc.Part{Doc.PartKey{"7","40",0,0},Doc.MessageText{},Doc.Span{0,13},"assistant","",False{}}]},"original page"))

def card_restored() -> UI.State:
  ui(G.library_back(apply(G.library_enter(card_origin()),report(10))))

def card_checks() -> IO(Unit):
  do IO<Unit>:
    check(Maybe.is_some(&2,Cards.Model,UI.card_model(card_restored())),"Library Back preserves the original structured reader model")
    check(String.eq(UI.reader(card_restored()),"card evidence"),"Library Back preserves original card canonical evidence")


# Cross-path fixture: exact retained Usage capture plus admitted structured
# metadata. Literal expected strings remain independent of the projection.
def structured_user() -> String: "Preserve café 中文 🙂.\n"
def structured_answer() -> String: "Recorded response.\n"
def structured_secret() -> String: "SECRET_USAGE_ARGUMENTS\n"
def structured_tail() -> String: "Evidence retained.\n"
def structured_prefix() -> String: "User\n" ++ structured_user() ++ "Assistant\n" ++ structured_answer()
def structured_visible() -> String: structured_prefix() ++ structured_tail()
def structured_canonical() -> String: structured_prefix() ++ structured_secret() ++ structured_tail()

def structured_key(record: String) -> Doc.PartKey: Doc.PartKey{"92",record,1,2}

def structured_document(+record: String) -> Doc.Document:
  +user_end : U32 = Doc.length("User\n" ++ structured_user())
  +answer_at : U32 = U32.add(user_end,10)
  +secret_at : U32 = Doc.length(structured_prefix())
  +tail_at : U32 = U32.add(secret_at,Doc.length(structured_secret()))
  Doc.Structured{structured_canonical(),0,[
    Doc.Part{Doc.PartKey{"92",record,0,0},Doc.EventHeading{},Doc.Span{0,5},"user","",False{}},
    Doc.Part{Doc.PartKey{"92",record,0,1},Doc.MessageText{},Doc.Span{5,Doc.length(structured_user())},"user","",False{}},
    Doc.Part{Doc.PartKey{"92",record,1,0},Doc.EventHeading{},Doc.Span{user_end,10},"assistant","",False{}},
    Doc.Part{Doc.PartKey{"92",record,1,1},Doc.MessageText{},Doc.Span{answer_at,Doc.length(structured_answer())},"assistant","",False{}},
    Doc.Part{structured_key(record),Doc.ToolArguments{},Doc.Span{secret_at,Doc.length(structured_secret())},"assistant","Read",True{}},
    Doc.Part{Doc.PartKey{"92",record,1,3},Doc.MessageText{},Doc.Span{tail_at,Doc.length(structured_tail())},"assistant","",False{}}]}

def structured_page(nonce: U32,+start: U32,count: U32) -> J.Json:
  json("{\"kind\":\"library_usage_capture\",\"version\":1,\"nonce\":" ++ U32.show(nonce) ++
    ",\"capture\":" ++ S.capture_text(capture()) ++ ",\"page\":{\"snapshot\":\"92\",\"start\":" ++ U32.show(start) ++
    ",\"requested_records\":40,\"selected_records\":" ++ U32.show(count) ++
    ",\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":" ++ J.quote(structured_canonical()) ++
    ",\"reader_view\":" ++ Wire.encode(structured_document(U32.show(start))) ++ "}}")

def structured_report() -> G.State:
  +state : G.State = apply(G.library_enter(card_origin()),report(10))
  G.replace_ui(state,UI.set_edit(ui(state),UI.Edit{2,19,2,False{},0}))

def structured_shown() -> G.State:
  apply(G.library_open(structured_report(),0),structured_page(11,0,40))

def structured_model_value(value: Maybe<&2,Cards.Model>) -> Cards.Model:
  match value:
    case Some{model}: model
    case None{}: Cards.open(Doc.Plain{"MISSING_STRUCTURED_PAGE",0},"missing")

def structured_model(view: UI.State) -> Cards.Model: structured_model_value(UI.card_model(view))

def changed(value: UI.State & UI.Action) -> UI.State:
  (view,_) = value
  view

def copy_text(value: UI.State & UI.Action) -> String:
  match value:
    case (_,UI.Copy{text}): text
    case _: "MISSING_COPY_ACTION"

def structured_all(view: UI.State) -> UI.State:
  UI.select_all(UI.set_edit(view,UI.Edit{2,0,0,False{},0}))

def structured_copy(+view: UI.State) -> String:
  copy_text(UI.copy_action(view,String.is_empty(UI.selection(view))))

def structured_row(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{row}: row
    case None{}: 9999

def structured_fold_row(+view: UI.State,record: String) -> U32:
  structured_row(Cards.focus_row(Cards.rows(structured_model(view)),structured_key(record),0))

def structured_y(row: U32) -> U32: U32.add(Geometry.reader_y(),U32.mul(row,Geometry.line_pitch()))

def structured_click(+view: UI.State,+record: String) -> UI.State:
  changed(UI.event(Mouse{1104,structured_y(structured_fold_row(view,record)),0,True{}},view))

def structured_opened() -> G.State:
  +state : G.State = structured_shown()
  G.replace_ui(state,structured_click(structured_all(ui(state)),"0"))

def structured_gap(rows: List<&2,Cards.Row>,+at: U32) -> U32:
  match rows:
    case []: 9999
    case Cards.GapRow{} <> _: at
    case _ <> rest: structured_gap(rest,U32.inc(at))

def structured_roles(rows: List<&2,Cards.Row>) -> String:
  match rows:
    case []: ""
    case Cards.RoleRow{_,role} <> rest: role ++ "|" ++ structured_roles(rest)
    case _ <> rest: structured_roles(rest)

def structured_spans(spans: List<&2,Doc.Span>) -> String:
  match spans:
    case []: ""
    case span <> rest: Doc.slice(structured_canonical(),span) ++ structured_spans(rest)

def structured_selection(value: Maybe<&2,Projection.Selection>) -> String:
  match value:
    case Some{Projection.Selection{text,spans}}: text ++ "|" ++ structured_spans(spans)
    case None{}: "MISSING_STRUCTURED_SELECTION"

def structured_mapping(+view: UI.State) -> String:
  structured_selection(UI.card_visible_selection(view,Cards.token(structured_model(view))))

def structured_named(rows: List<&2,Cards.Row>,+wanted: String,+at: U32) -> U32:
  match rows:
    case []: 9999
    case Cards.ProseRow{line,_} <> rest:
      Bool.pick(U32,String.eq(Prose.text(line),wanted),at,structured_named(rest,wanted,U32.inc(at)))
    case Cards.TextRow{_,text,_,_} <> rest:
      Bool.pick(U32,String.eq(text,wanted),at,structured_named(rest,wanted,U32.inc(at)))
    case _ <> rest: structured_named(rest,wanted,U32.inc(at))

def structured_drag(+view: UI.State) -> UI.State:
  +rows : List<&2,Cards.Row> = Cards.rows(structured_model(view))
  +first : U32 = structured_named(rows,"Preserve café 中文 🙂.",0)
  +last : U32 = structured_named(rows,"Recorded response.",0)
  changed(UI.event(Move{569,structured_y(last)},changed(UI.event(Mouse{545,structured_y(first),0,True{}},view))))

def structured_next() -> G.State:
  apply(G.library_page(structured_opened(),True{}),structured_page(12,40,5))

def structured_gap_before_fold(+view: UI.State) -> Bool:
  +gap : U32 = structured_gap(Cards.rows(structured_model(view)),0)
  +fold : U32 = structured_fold_row(view,"0")
  U32.is_lt(gap,fold) && U32.is_lt(fold,Geometry.reader_rows())

# The observed compiler continuation retains whole state-returning temporaries.
# Recursive List boxes are one slot; scalar observations consume each box.
# The exact production Back calls, expected values and assertion labels remain.
def structured_return_report() -> List<&2,G.State>:
  [G.library_back(structured_next())]

def structured_back_box(value: List<&2,G.State>) -> List<&2,G.State>:
  match value:
    case Con{state,Nil{}}: [G.library_back(state)]
    case _: []

def structured_return_origin() -> List<&2,G.State>:
  structured_back_box(structured_return_report())

def structured_box_reader(value: List<&2,G.State>) -> String:
  match value:
    case Con{state,Nil{}}: UI.reader(ui(state))
    case _: "MISSING_BOXED_READER"

def structured_box_position(value: List<&2,G.State>) -> String:
  match value:
    case Con{state,Nil{}}: position(ui(state))
    case _: "MISSING_BOXED_POSITION"

def structured_box_query(value: List<&2,G.State>) -> String:
  match value:
    case Con{state,Nil{}}: UI.query(ui(state))
    case _: "MISSING_BOXED_QUERY"

def structured_box_selected(value: List<&2,G.State>) -> String:
  match value:
    case Con{state,Nil{}}: selected(state)
    case _: "MISSING_BOXED_SELECTION"

def structured_box_cards(value: List<&2,G.State>) -> Bool:
  match value:
    case Con{state,Nil{}}: Maybe.is_some(&2,Cards.Model,UI.card_model(ui(state)))
    case _: False{}

def structured_checks() -> IO(Unit):
  do IO<Unit>:
    check(U32.is_eq(phase(structured_shown()),6) && Maybe.is_some(&2,Cards.Model,UI.card_model(ui(structured_shown()))),"structured Usage capture reaches ready phase6 with admitted cards")
    check(String.eq(structured_roles(Cards.rows(structured_model(ui(structured_shown())))),"user|assistant|") && structured_gap_before_fold(ui(structured_shown())),"Usage page contains two typed roles and its disclosure follows a visible event gap")
    check(String.eq(UI.reader(ui(structured_shown())),structured_visible()) && String.eq(Cards.canonical(structured_model(ui(structured_shown()))),structured_canonical()),"Usage collapsed view omits only secret part and retains complete canonical evidence")
    check(String.eq(structured_copy(structured_all(ui(structured_shown()))),structured_visible()),"Usage select-all Copy action contains exact visible Unicode and no hidden bytes")
    check(String.eq(structured_mapping(structured_all(ui(structured_shown()))),structured_visible() ++ "|" ++ structured_visible()),"Usage visible selection reconstructs the exact same text from canonical source spans across a hidden part")
    check(String.eq(structured_copy(structured_drag(ui(structured_shown()))),Doc.slice(structured_visible(),Doc.Span{6,U32.sub(U32.add(Doc.length("User\n" ++ structured_user() ++ "Assistant\n"),4),6)})),"Usage pointer selection across event gap copies the exact visible scalar interval")
    check(String.eq(UI.reader(ui(structured_opened())),structured_canonical()) && String.eq(UI.selection(ui(structured_opened())),""),"Usage disclosure pointer after gap expands exact part and clears old selection")
    check(String.eq(structured_copy(structured_all(ui(structured_opened()))),structured_canonical()),"expanded Usage Copy action is byte-exact canonical evidence including hidden arguments")
    check(String.eq(UI.reader(structured_click(ui(structured_opened()),"0")),structured_visible()) && String.eq(Cards.canonical(structured_model(structured_click(ui(structured_opened()),"0"))),structured_canonical()),"Usage second disclosure click restores compact view without canonical mutation")
    check(String.eq(wanted(G.library_page(structured_opened(),True{})),"library-usage-capture-v1|12|" ++ S.capture_text(capture()) ++ "|40"),"structured Usage Next retains exact descriptor and advances physical range")
    check(U32.is_eq(phase(structured_next()),6) && String.eq(selected(structured_next()),"92|40|3||claude|||") && String.eq(UI.reader(ui(structured_next())),structured_visible()),"structured next-page acknowledgement preserves exact snapshot and starts with fresh folds")
    check(String.eq(UI.reader(UI.card_fold(ui(structured_next()),Cards.token(structured_model(ui(structured_opened()))),structured_key("40"))),structured_visible()),"old Usage page disclosure token cannot open a different physical page")
    check(String.eq(wanted(G.library_page(structured_next(),False{})),"library-usage-capture-v1|13|" ++ S.capture_text(capture()) ++ "|0"),"structured Usage Previous requests original physical page with fresh nonce")
    check(String.eq(structured_box_reader(structured_return_report()),UI.reader(ui(structured_report()))) && String.eq(structured_box_position(structured_return_report()),position(ui(structured_report()))),"Back from structured next page restores report text and exact saved selection")
    check(String.eq(structured_box_reader(structured_return_origin()),UI.reader(ui(card_origin()))) && structured_box_cards(structured_return_origin()),"two structured Usage Back levels restore original card reader")
    check(String.eq(structured_box_query(structured_return_origin()),UI.query(ui(card_origin()))) && String.eq(structured_box_selected(structured_return_origin()),selected(card_origin())),"structured Usage Back preserves original query and all retained selection scope")

def main() -> IO(Unit):
  do IO<Unit>:
    summary_checks()
    capture_checks()
    restoration_checks()
    pending_worker()
    card_checks()
    structured_checks()
