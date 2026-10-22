import Base
import ../src/gui.bend as Gui
import ../src/gui_usage.bend as Usage
import ../src/gui_files.bend as Files
import ../src/gui_relations.bend as Related
import ../src/ui.bend as UI
import ../src/json.bend as Json
import ../src/query.bend as Query

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def json(value: String) -> Json.Json:
  parsed(Json.parse(value))

def replace_fields(values: List<&2,Json.Field>,+key: String,+value: Json.Json) -> List<&2,Json.Field>:
  match values:
    case []: []
    case Json.JField{+name,old} <> rest:
      Json.JField{name,Bool.pick(Json.Json,String.eq(name,key),value,old)} <> replace_fields(rest,key,value)

def replace(value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{replace_fields(values,key,replacement)}
    case _: value

def duplicate(value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{Json.JField{key,replacement} <> values}
    case _: value

def capture() -> Json.Json:
  json("{\"provider\":\"claude\",\"source_id\":\"2\",\"source\":\"/synthetic/café 中文 🙂.jsonl\",\"generation\":\"3\",\"snapshot\":\"7\",\"extent\":\"9000\",\"records\":\"45\"}")

def summary() -> Json.Json:
  json("{\"provider\":\"claude\",\"source_session_path_association\":null,\"observed\":{\"input_tokens\":\"9007199254740993\",\"cached_input_tokens\":null,\"cache_creation_input_tokens\":\"2\",\"cache_creation_1h_input_tokens\":null,\"output_tokens\":\"5\"},\"source_associated\":{\"input_tokens\":null,\"cached_input_tokens\":null,\"cache_creation_input_tokens\":null,\"cache_creation_1h_input_tokens\":null,\"output_tokens\":null},\"copied_session\":{\"input_tokens\":null,\"cached_input_tokens\":null,\"cache_creation_input_tokens\":null,\"cache_creation_1h_input_tokens\":null,\"output_tokens\":null},\"unattributed\":{\"input_tokens\":\"9007199254740993\",\"cached_input_tokens\":null,\"cache_creation_input_tokens\":\"2\",\"cache_creation_1h_input_tokens\":null,\"output_tokens\":\"5\"},\"usage_records\":3,\"distinct_call_keys\":2,\"descriptor_bytes\":200,\"missing_ids\":0,\"incomplete_observations\":1,\"conflicting_calls\":0,\"repeat_observations\":1,\"bucket_complete\":false,\"attribution_complete\":false}")

def report() -> Json.Json:
  +base = json("{\"kind\":\"session_usage\",\"capture\":null,\"processed_records\":45,\"verified_bytes\":9000,\"scan_complete\":true,\"bucket_complete\":false,\"attribution_complete\":false,\"stop_reason\":\"Complete pinned retained extent scanned\",\"limits\":{\"records\":1000000,\"bytes\":1073741824,\"keys\":100000,\"descriptor_bytes\":16777216},\"coverage\":{\"decoded\":45,\"malformed\":0,\"oversized\":0,\"issues\":0,\"witnesses\":[]},\"summary\":null,\"text\":\"Recorded totals café 中文 🙂\\nInput: 9007199254740993\\nCached input: unknown\\nNo price or billing estimate.\"}")
  replace(replace(base,"capture",capture()),"summary",summary())

def filters() -> Query.Filters:
  Query.Filters{"","claude","","",""}

def accepted(result: Result<&2,&2,String,Usage.Report>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def valid(value: Json.Json) -> Bool:
  accepted(Usage.decode(value,"7",filters()))

def wrong(key: String,value: Json.Json,label: String) -> IO(Unit):
  require(Bool.not(valid(replace(report(),key,value))),label)

def identities() -> IO(Unit):
  do IO<Unit>:
    require(valid(report()),"independent whole-capture fixture keeps exact >2^53 decimal and unknown counters")
    wrong("kind",Json.JString{"usage"},"old range-only envelope cannot be a whole-capture acknowledgement")
    wrong("capture",replace(capture(),"snapshot",Json.JString{"8"}),"different snapshot is rejected")
    wrong("capture",replace(capture(),"snapshot",Json.JNumber{"7"}),"snapshot identity is a typed string")
    wrong("capture",replace(capture(),"source_id",Json.JString{"02"}),"source identity must be canonical")
    wrong("capture",replace(capture(),"generation",Json.JString{"9223372036854775808"}),"generation cannot exceed signed SQLite range")
    wrong("capture",replace(capture(),"extent",Json.JString{"4294967296"}),"captured byte extent cannot wrap U32")
    wrong("capture",replace(capture(),"provider",Json.JString{"codex"}),"provider-filtered reader cannot accept another provider")
    wrong("capture",replace(capture(),"source",Json.JString{"relative.jsonl"}),"captured source locator must be absolute")
    wrong("capture",duplicate(capture(),"snapshot",Json.JString{"7"}),"duplicate identity keys are rejected even when equal")
    require(Bool.not(valid(duplicate(report(),"text",Json.JString{"forged"}))),"duplicate top-level text is rejected")
    wrong("summary",duplicate(summary(),"usage_records",Json.JNumber{"3"}),"duplicate summary counters are rejected")

def coverage_contract() -> IO(Unit):
  +quality = Json.field(report(),"coverage")
  +limits = Json.field(report(),"limits")
  do IO<Unit>:
    wrong("scan_complete",Json.JString{"true"},"scan completeness requires a boolean")
    wrong("processed_records",Json.JNumber{"44"},"complete scan cannot omit a captured record")
    wrong("verified_bytes",Json.JNumber{"8999"},"complete scan cannot omit retained bytes")
    wrong("processed_records",Json.JNumber{"4294967296"},"processed count cannot wrap")
    wrong("limits",replace(limits,"records",Json.JNumber{"999999"}),"acknowledged limits must match the whole-capture request")
    wrong("limits",replace(limits,"bytes",Json.JString{"1073741824"}),"limits require exact number types")
    wrong("coverage",replace(quality,"decoded",Json.JNumber{"44"}),"coverage partition must account for processed records")
    wrong("coverage",replace(quality,"issues",Json.JNumber{"46"}),"issue count cannot exceed scanned records")
    wrong("coverage",replace(quality,"witnesses",json("[{\"physical_record\":45,\"reason\":\"missing\"}]")),"witness cannot escape capture")
    wrong("coverage",replace(quality,"witnesses",json("[{\"physical_record\":4,\"physical_record\":4,\"reason\":\"duplicate\"}]")),"duplicate witness fields are rejected")
    wrong("bucket_complete",Json.JBool{True{}},"outer bucket flag cannot promote unknown summary counters")
    wrong("attribution_complete",Json.JBool{True{}},"outer attribution flag cannot promote missing attribution")
    wrong("summary",replace(summary(),"observed",replace(Json.field(summary(),"observed"),"input_tokens",Json.JNumber{"9007199254740993"})),"large counters must be exact strings, not JSON numeric coercion")
    wrong("summary",replace(summary(),"observed",replace(Json.field(summary(),"observed"),"input_tokens",Json.JString{"01"})),"counter strings must be canonical decimal")
    wrong("text",Json.JBool{True{}},"summary text cannot be coerced from another type")

def partial() -> Json.Json:
  +counts = replace(replace(report(),"processed_records",Json.JNumber{"40"}),"verified_bytes",Json.JNumber{"8000"})
  +quality = json("{\"decoded\":40,\"malformed\":0,\"oversized\":0,\"issues\":1,\"witnesses\":[{\"physical_record\":40,\"reason\":\"first excluded call\"}]}")
  replace(replace(counts,"scan_complete",Json.JBool{False{}}),"coverage",quality)

def partial_contract() -> IO(Unit):
  do IO<Unit>:
    require(valid(partial()),"partial scan can retain a verified witness for its first excluded record")
    require(Bool.not(valid(replace(partial(),"bucket_complete",Json.JBool{True{}}))),"partial scan cannot claim whole-capture bucket completeness")
    require(Bool.not(accepted(Usage.decode(report(),"7",Query.Filters{"","claude","/repo","",""}))),"repository filter cannot silently widen to whole capture")
    require(Bool.not(accepted(Usage.decode(report(),"7",Query.Filters{"","claude","","user",""}))),"role filter cannot silently widen to whole capture")
    require(Bool.not(accepted(Usage.decode(report(),"7",Query.Filters{"","claude","","","2026-10-20"}))),"date filter cannot silently widen to whole capture")

def codex_report() -> Json.Json:
  +facts = json("{\"provider\":\"codex\",\"category\":\"reviewer\",\"session\":\"review-session\",\"recorded_parent_thread_id\":null,\"fork_basis\":\"none\",\"accounted\":{\"input_tokens\":\"4\",\"cached_input_tokens\":\"1\",\"cache_creation_input_tokens\":null,\"cache_creation_1h_input_tokens\":null,\"output_tokens\":\"2\"},\"observations\":4,\"accepted\":2,\"duplicates\":1,\"resets\":0,\"excluded\":1,\"uncertain\":0,\"first_ordinal\":\"2\",\"last_ordinal\":\"43\",\"accounting_complete\":true}")
  replace(replace(replace(replace(report(),"capture",replace(capture(),"provider",Json.JString{"codex"})),"summary",facts),"bucket_complete",Json.JBool{True{}}),"attribution_complete",Json.JBool{True{}})

def codex_contract() -> IO(Unit):
  +value = codex_report()
  +facts = Json.field(value,"summary")
  do IO<Unit>:
    require(accepted(Usage.decode(value,"7",Query.Filters{"","codex","","",""})),"reviewer category remains separate in typed Codex summary")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"last_ordinal",Json.JString{"45"})),"7",Gui.empty_filters()))),"Codex usage ordinal must be a scanned physical record")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"category",Json.JString{"coding-reviewer"})),"7",Gui.empty_filters()))),"unknown category strings cannot invent coding attribution")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"category",Json.JString{"unknown"})),"7",Gui.empty_filters()))),"unknown Codex category cannot claim complete accounting")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"fork_basis",Json.JString{"inferred"})),"7",Gui.empty_filters()))),"fork basis is a closed recorded-evidence contract")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"fork_basis",Json.JString{"unresolved"})),"7",Gui.empty_filters()))),"unresolved fork attribution cannot claim complete accounting")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"accounted",replace(Json.field(facts,"accounted"),"input_tokens",Json.JNull{}))),"7",Gui.empty_filters()))),"unknown Codex token bucket cannot claim complete accounting")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"accepted",Json.JNumber{"3"})),"7",Gui.empty_filters()))),"Codex observation partition must match accepted duplicates and excluded")
    require(Bool.not(accepted(Usage.decode(replace(value,"summary",replace(facts,"resets",Json.JNumber{"3"})),"7",Gui.empty_filters()))),"Codex resets cannot exceed accepted observations")

def claude_completeness() -> IO(Unit):
  +complete = replace(replace(summary(),"incomplete_observations",Json.JNumber{"0"}),"bucket_complete",Json.JBool{True{}})
  +reply = replace(replace(report(),"summary",complete),"bucket_complete",Json.JBool{True{}})
  +known = replace(complete,"observed",replace(Json.field(complete,"observed"),"cached_input_tokens",Json.JString{"0"}))
  +valid_reply = replace(reply,"summary",known)
  +attributed = replace(replace(known,"source_session_path_association",Json.JString{"session"}),"attribution_complete",Json.JBool{True{}})
  do IO<Unit>:
    require(Bool.not(valid(reply)),"unknown required Claude bucket cannot claim complete accounting")
    require(valid(valid_reply),"explicit recorded zero remains distinct from unknown and optional one-hour cache is not required")
    require(Bool.not(valid(replace(valid_reply,"summary",replace(known,"usage_records",Json.JNumber{"0"})))),"no Claude observations cannot claim complete accounting")
    require(Bool.not(valid(replace(valid_reply,"summary",replace(known,"missing_ids",Json.JNumber{"1"})))),"missing Claude call identity prevents complete accounting")
    require(Bool.not(valid(replace(replace(valid_reply,"summary",attributed),"attribution_complete",Json.JBool{True{}}))),"known unattributed counters cannot claim complete Claude attribution")
    require(Bool.not(valid(replace(valid_reply,"summary",replace(known,"source_session_path_association",Json.JString{""})))),"empty optional source association must remain null rather than a fabricated identity")

def origin_ui() -> UI.State:
  UI.set_edit(UI.set_position(UI.set_results(UI.set_rows(UI.set_scope(UI.set_reader(UI.set_query(UI.init(),
    "needle provider:claude"),"Origin snapshot7 record40","Original captured range café 中文 🙂\nimmutable evidence"),"claude"),["first","chosen"]),
    UI.Results{100,2,True{},True{}}),1,7),UI.Edit{2,24,4,False{},0})

def origin_selection() -> Gui.Selection:
  Gui.Selection{[Gui.Item{"7",40,"chosen","claude","/synthetic/repository","3",filters()}],"7",40,3,[],filters(),
      Gui.Listing{2,Query.Filters{"needle","claude","","",""},100,True{},True{},""}}

def origin() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-gui-usage","/usr/bin/false",origin_ui(),origin_selection(),
    Gui.Form{0,"needle provider:claude","","",Files.empty(),[],[]},Gui.Jobs{9,None{},None{},None{},False{}},60000n,0}

def ui(state: Gui.State) -> UI.State:
  Gui.State{_,_,_,ui,_,_,_,_,_} = state
  ui

def request_value(value: Maybe<&2,Gui.Request>) -> Gui.Request:
  match value:
    case Some{request}: request
    case None{}: Gui.Request{0,[],"",0,""}

def request(state: Gui.State) -> Gui.Request:
  Gui.State{_,_,_,_,_,_,Gui.Jobs{_,wanted,_,_,_},_,_} = state
  request_value(wanted)

def wanted_request(request: Gui.Request) -> String:
  Gui.Request{_,args,_,_,_} = request
  String.join(args,"|")

def wanted(state: Gui.State) -> String:
  wanted_request(request(state))

def selected(state: Gui.State) -> String:
  Gui.State{_,_,_,_,Gui.Selection{items,snapshot,start,kind,args,Query.Filters{q,p,r,role,after},Gui.Listing{lk,_,offset,more,loaded,anchor}},_,_,_,_} = state
  String.join([snapshot,U32.show(start),U32.show(kind),String.join(args,"|"),q,p,r,role,after,U32.show(lk),U32.show(offset),anchor],";")

def position(state: UI.State) -> String:
  UI.State{_,UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,drag,viewport},command,shift},_,_} = state
  String.join([U32.show(selected),U32.show(scroll),U32.show(focus),U32.show(caret),U32.show(anchor),U32.show(viewport)],";")

def ui_status(state: UI.State) -> String:
  UI.State{UI.Content{_,_,_,_,_,status,_,_,_,_},_,_,_} = state
  status

def state_status(state: Gui.State) -> String:
  ui_status(ui(state))

def loaded(value: Json.Json) -> Gui.State:
  +pending = Gui.usage(origin())
  Gui.read_done(pending,request(pending),Done{value})

# Saved test states are boxed across IO continuations; assertions still compare
# the complete original selection and UI bookmark.
def box(state: Gui.State) -> List<&2,Gui.State>:
  [state]

def unbox(values: List<&2,Gui.State>) -> Gui.State:
  match values:
    case value <> []: value
    case _: origin()

def expected_selection() -> String:
  String.join(["7","40","3","","","claude","","","","2","100",""],";")

def expected_reader() -> String:
  "WHOLE CAPTURED SESSION USAGE\nThis report covers the pinned snapshot, not just the original visible range.\nBack restores that range and its text selection. Why and Tools use the original range.\n\n" ++ Json.get(report(),"text")

def navigation_contract() -> IO(Unit):
  +pending = box(Gui.usage(origin()))
  +shown = box(loaded(report()))
  +restored = box(Gui.usage_restore(unbox(shown)))
  do IO<Unit>:
    require(String.eq(wanted(unbox(pending)),"session-usage|7"),"native Usage requests the complete pinned snapshot without range arguments")
    require(String.eq(UI.reader(ui(unbox(pending))),UI.reader(origin_ui())) && String.eq(selected(unbox(pending)),expected_selection()),"pending Usage keeps the currently verified range visible")
    require(String.contains(state_status(unbox(pending)),"whole pinned capture"),"loading text explains whole-capture scope and worker wait")
    require(UI.whole_usage(ui(unbox(shown))) && String.contains(UI.reader(ui(unbox(shown))),"not just the original visible range"),"accepted view labels full captured scope explicitly")
    require(String.contains(state_status(unbox(shown)),"scan complete") && String.contains(state_status(unbox(shown)),"unknown/partial"),"scanned completeness remains separate from usage-accounting completeness")
    require(String.contains(state_status(loaded(partial())),"INCOMPLETE"),"limited summary remains visibly incomplete")
    require(String.eq(selected(unbox(restored)),expected_selection()) && String.eq(UI.reader(ui(unbox(restored))),UI.reader(origin_ui())),"Back restores exact original snapshot range and listing")
    require(String.eq(position(ui(unbox(restored))),position(origin_ui())) && String.eq(UI.query(ui(unbox(restored))),UI.query(origin_ui())),"Back restores original scroll selection list position and query")
    require(String.eq(UI.selection(UI.select_all(UI.set_edit(ui(unbox(shown)),UI.Edit{2,0,0,False{},0}))),UI.reader(ui(unbox(shown)))),"copy selects exact displayed Unicode summary including scope notice")
    require(String.eq(String.join(Gui.export_args(14,"7",40,filters(),UI.reader(ui(unbox(shown))),"/tmp/evidence.md"),"|"),
      "export-displayed|/tmp/evidence.md|" ++ UI.reader(ui(unbox(shown)))),"Usage export transports the exact displayed summary")

def strict_controller() -> IO(Unit):
  +pending = box(Gui.usage(origin()))
  +shown = box(loaded(report()))
  +wronggen = replace(report(),"capture",replace(capture(),"generation",Json.JString{"4"}))
  +stale = box(Gui.read_current(unbox(pending),request(unbox(pending)),Gui.Reply{Done{report()}},False{}))
  +duplicate = box(Gui.read_done(unbox(shown),request(unbox(pending)),Done{replace(report(),"text",Json.JString{"replayed replacement"})}))
  do IO<Unit>:
    require(String.eq(UI.reader(ui(unbox(stale))),UI.reader(origin_ui())),"stale Usage response cannot replace current evidence")
    require(String.eq(UI.reader(ui(loaded(wronggen))),UI.reader(origin_ui())),"known captured generation must agree with reply")
    require(String.eq(UI.reader(ui(unbox(duplicate))),UI.reader(ui(unbox(shown)))),"duplicate completion cannot replace accepted summary")
    require(String.eq(UI.reader(ui(Gui.read_done(Gui.usage_restore(unbox(pending)),request(unbox(pending)),Done{report()}))),UI.reader(origin_ui())),"Back invalidates in-flight response even if explicitly delivered later")
    require(String.eq(UI.reader(ui(Gui.read_done(unbox(pending),Gui.Request{14,["session-usage","7","40"],"7",40,"bad"},Done{report()}))),UI.reader(origin_ui())),"request argument list must be closed and exact")
    require(String.eq(UI.reader(ui(Gui.read_done(unbox(pending),Gui.Request{14,["session-usage","7"],"7",0,"bad"},Done{report()}))),UI.reader(origin_ui())),"origin physical range cannot silently move while summary is loading")
    require(String.eq(UI.reader(ui(Gui.read_done(unbox(pending),request(unbox(pending)),Fail{"worker timeout"}))),UI.reader(origin_ui())),"worker error leaves prior verified evidence readable")

def action_state(value: Maybe<Gui.State>) -> Gui.State:
  match value:
    case Some{state}: state
    case None{}: origin()

def acted(state: Gui.State,action: UI.Action) -> IO(Gui.State):
  do IO<Gui.State>:
    result : Maybe<Gui.State> <- Gui.handle(state,action)
    return action_state(result)

def acted_box(state: Gui.State,action: UI.Action) -> IO(List<&2,Gui.State>):
  do IO<List<&2,Gui.State>>:
    value : Gui.State <- acted(state,action)
    return [value]

def action_selected(action: UI.Action) -> IO(String):
  do IO<String>:
    value : Gui.State <- acted(loaded(report()),action)
    return selected(value)

def action_wanted(action: UI.Action) -> IO(String):
  do IO<String>:
    value : Gui.State <- acted(loaded(report()),action)
    return wanted(value)

def action_page(action: UI.Action,label: String) -> IO(Unit):
  do IO<Unit>:
    +value : Gui.State <- acted(loaded(report()),action)
    require(String.eq(UI.reader(ui(value)),expected_reader()) &&
      String.contains(state_status(value),"no transcript pages"),label)

def actions() -> IO(Unit):
  do IO<Unit>:
    back : String <- action_selected(UI.Back{})
    require(String.eq(back,expected_selection()),"visible Back action restores original range")
    action_page(UI.Next{},"Next does not paginate a whole-capture summary")
    action_page(UI.Previous{},"Previous does not paginate a whole-capture summary")
    why : String <- action_wanted(UI.Why{})
    require(String.eq(why,"why-scope|7|40|20|claude|||"),"Why uses the exact original physical range")
    tools : String <- action_wanted(UI.Tools{})
    require(String.eq(tools,"activity-scope|7|40|40|claude|||"),"Tools uses the exact original physical range")

def selection_value(state: Gui.State) -> Gui.Selection:
  Gui.State{_,_,_,_,selection,_,_,_,_} = state
  selection

def nested_origin() -> Gui.State:
  Gui.set_navigation(origin(),Gui.RelatedNavigation{origin_selection(),UI.bookmark(origin_ui()),"related origin query",
    None{},None{},[],2,Some{Related.Reference{"claude","/synthetic/café 中文 🙂.jsonl","3","7","9000"}}})

def nested_loaded() -> Gui.State:
  +pending = Gui.usage(nested_origin())
  Gui.read_done(pending,request(pending),Done{report()})

def nested_ready() -> IO(Unit):
  require(Gui.usage_ready(Gui.navigation(nested_loaded())),"Usage can inspect an exact Related target with compatible scope")

def nested_selection() -> IO(Unit):
  +back = Gui.usage_restore(nested_loaded())
  require(U32.is_eq(Gui.navigation_phase(Gui.navigation(back)),2) && String.eq(selected(back),expected_selection()),
    "Usage Back restores the previous Related target navigation")

def nested_position() -> IO(Unit):
  +back = Gui.usage_restore(nested_loaded())
  require(String.eq(UI.reader(ui(back)),UI.reader(origin_ui())) && String.eq(position(ui(back)),position(origin_ui())),
    "nested Related reader scroll and text selection are restored")

def settings_resume() -> IO(Unit):
  +back = Gui.settings_leave(Gui.settings(loaded(report())))
  require(Gui.usage_ready(Gui.navigation(back)) && String.eq(UI.reader(ui(back)),expected_reader()),
    "Settings Back retains the accepted Usage summary and return bookmark")

def nested_navigation() -> IO(Unit):
  do IO<Unit>:
    nested_ready()
    nested_selection()
    nested_position()
    settings_resume()

def with_reader(state: Gui.State,channel: Chan(Gui.Reply)) -> Gui.State:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{+revision,wanted,reader,writer,paused},deadline,serial} = state
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,None{},Some{Gui.Pending{revision,request_value(wanted),channel}},writer,paused},deadline,serial}

def reader_value(state: Gui.State) -> Maybe<&2,Gui.Pending>:
  Gui.State{_,_,_,_,_,_,Gui.Jobs{_,_,reader,_,_},_,_} = state
  reader

def wanted_value(state: Gui.State) -> Maybe<&2,Gui.Request>:
  Gui.State{_,_,_,_,_,_,Gui.Jobs{_,wanted,_,_,_},_,_} = state
  wanted

def reader_command(value: Maybe<&2,Gui.Pending>) -> String:
  match value:
    case Some{Gui.Pending{_,Gui.Request{_,args,_,_,_},_}}: String.join(args,"|")
    case None{}: "none"

def pending_back_range(+restored: Gui.State) -> IO(Unit):
  require(String.eq(selected(restored),expected_selection()) && String.eq(position(ui(restored)),position(origin_ui())),
    "Back restores immediately while the existing Usage worker remains outstanding")

def pending_back_message(+restored: Gui.State) -> IO(Unit):
  require(String.contains(state_status(restored),"result is ignored") && String.eq(reader_command(reader_value(restored)),"session-usage|7"),
    "pending Back accurately reports ignored completion without claiming process cancellation")

def pending_wait(restored: Gui.State) -> IO(Unit):
  +queued = Gui.why(restored)
  do IO<Unit>:
    +waiting : Gui.State <- Gui.start_read(queued,wanted_value(queued),reader_value(queued))
    require(String.eq(reader_command(reader_value(waiting)),"session-usage|7") && String.eq(wanted(waiting),"why-scope|7|40|20|claude|||"),
      "new reads queue behind one outstanding worker without spawning another")

def pending_worker_channel(+channel: Chan(Gui.Reply)) -> IO(Unit):
  +restored = box(Gui.usage_back(with_reader(Gui.usage(origin()),channel)))
  do IO<Unit>:
    pending_back_range(unbox(restored))
    pending_back_message(unbox(restored))
    pending_wait(unbox(restored))
    Chan.close(Gui.Reply,channel)

def pending_worker() -> IO(Unit):
  do IO<Unit>:
    channel : Chan(Gui.Reply) <- Chan.new(Gui.Reply,1)
    pending_worker_channel(channel)

# Reproduce the native transition: Claude Usage -> Back -> Why -> Tools ->
# scoped Claude refusal -> unfiltered Codex search -> second captured reader.
# The first source's Tools identity must survive until the second read succeeds.
def tools_origin() -> Gui.State:
  +why = Gui.why(Gui.usage_restore(loaded(report())))
  +tools = Gui.tools(Gui.text_done(why,request(why),Done{"Claude Why record40"}))
  +value = json("{\"kind\":\"recorded_activity\",\"provider\":\"claude\",\"source\":\"/synthetic/café 中文 🙂.jsonl\",\"generation\":\"3\",\"snapshot\":\"7\",\"extent\":\"9000\",\"total_records\":45,\"start\":40,\"requested_count\":40,\"selected_count\":5,\"verified_count\":5,\"next\":null,\"scope\":{\"provider\":\"claude\",\"repository\":\"\",\"role\":\"\",\"after\":\"\"},\"text\":\"Claude Tools record40\"}")
  Gui.read_done(tools,request(tools),Done{value})

def view_args(state: Gui.State) -> List<&2,String>:
  Gui.State{_,_,_,_,Gui.Selection{_,_,_,_,args,_,_},_,_,_,_} = state
  args

def item_values(state: Gui.State) -> List<&2,Gui.Item>:
  Gui.State{_,_,_,_,Gui.Selection{items,_,_,_,_,_,_},_,_,_,_} = state
  items

def search_open(+state: Gui.State,query: String,rows: Json.Json) -> Gui.State:
  +searching = Gui.form_text(Gui.replace_ui(state,UI.set_scope(UI.set_query(ui(state),query),"all")))
  +value = replace(json("{\"offset\":0,\"limit\":100,\"has_more\":false,\"rows\":[]}"),"rows",rows)
  +listed = Gui.read_done(searching,request(searching),Done{value})
  Gui.open_item(listed,Gui.select_item(item_values(listed),0n))

def scoped_origin() -> Gui.State:
  +opened = search_open(tools_origin(),"originneedle provider:claude repo:/synthetic/usage role:assistant after:2026-10-20",
    json("[[\"7\",\"40\",\"0\",\"claude\",\"assistant\",\"originneedle Claude\",\"/synthetic/usage\",\"claude-session\",\"2026-10-20\",\"3\"]]"))
  Gui.read_done(opened,request(opened),Done{json("{\"text\":\"Scoped Claude transcript record40\"}")})

def second_requested() -> Gui.State:
  search_open(Gui.usage(scoped_origin()),"originneedle provider:codex",
    json("[[\"2\",\"40\",\"0\",\"codex\",\"assistant\",\"originneedle Codex\",\"/synthetic/usage\",\"codex-usage-session\",\"2026-10-20\",\"2\"]]"))

def second_origin() -> Gui.State:
  +opened = second_requested()
  Gui.read_done(opened,request(opened),Done{json("{\"text\":\"Codex transcript record40 café 中文 🙂\"}")})

def second_report() -> Json.Json:
  +capture = json("{\"provider\":\"codex\",\"source_id\":\"2\",\"source\":\"/synthetic/codex-usage-session.jsonl\",\"generation\":\"2\",\"snapshot\":\"2\",\"extent\":\"27736\",\"records\":\"132\"}")
  +summary = json("{\"provider\":\"codex\",\"category\":\"ordinary\",\"session\":\"codex-usage-session\",\"recorded_parent_thread_id\":null,\"fork_basis\":\"none\",\"accounted\":{\"input_tokens\":\"150\",\"cached_input_tokens\":\"50\",\"cache_creation_input_tokens\":null,\"cache_creation_1h_input_tokens\":null,\"output_tokens\":\"30\"},\"observations\":5,\"accepted\":4,\"duplicates\":1,\"resets\":0,\"excluded\":0,\"uncertain\":0,\"first_ordinal\":\"38\",\"last_ordinal\":\"129\",\"accounting_complete\":true}")
  +value = replace(replace(replace(replace(codex_report(),"capture",capture),"summary",summary),"processed_records",Json.JNumber{"132"}),"verified_bytes",Json.JNumber{"27736"})
  replace(replace(value,"coverage",json("{\"decoded\":132,\"malformed\":0,\"oversized\":0,\"issues\":0,\"witnesses\":[]}")),
    "text",Json.JString{"Codex whole capture input150 / cached50 / output30 café 中文 🙂"})

def second_loaded(+value: Json.Json) -> Gui.State:
  +pending = Gui.usage(second_origin())
  Gui.read_done(pending,request(pending),Done{value})

def source_metadata_contract() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.reader(ui(tools_origin())),"Claude Tools record40") &&
      String.eq(String.join(view_args(tools_origin()),"|"),"activity|7|/synthetic/café 中文 🙂.jsonl|3|9000|claude|45|0|5"),
      "Claude Usage Back Why Tools produces verified first-source activity metadata")
    require(String.eq(String.join(view_args(scoped_origin()),"|"),String.join(view_args(tools_origin()),"|")),
      "same-snapshot transcript keeps previously verified Tools identity")
    require(String.contains(state_status(Gui.usage(scoped_origin())),"would widen") &&
      Bool.not(Gui.usage_active(Gui.navigation(Gui.usage(scoped_origin())))),
      "scoped Claude Usage refuses widening before switching providers")
    require(String.eq(String.join(view_args(second_requested()),"|"),String.join(view_args(tools_origin()),"|")),
      "search and pending second-source open retain the currently displayed identity")
    require(List.is_empty(&2,String,view_args(second_origin())) &&
      String.eq(wanted(Gui.usage(second_origin())),"session-usage|2"),
      "accepted second-source transcript retires prior Tools metadata and requests snapshot2")

def metadata_failure_contract() -> IO(Unit):
  +pending = box(second_requested())
  +failed = box(Gui.read_done(unbox(pending),request(unbox(pending)),Fail{"synthetic second-source read failure"}))
  +same = box(Gui.text_done(tools_origin(),Gui.Request{4,Gui.scoped_args("why-scope","7",40,"20",filters()),"7",40,"Why"},Done{"same snapshot Why"}))
  do IO<Unit>:
    require(String.eq(String.join(view_args(unbox(failed)),"|"),String.join(view_args(tools_origin()),"|")) &&
      String.eq(UI.reader(ui(unbox(failed))),"Scoped Claude transcript record40"),
      "failed second-source read preserves prior captured text and full Tools identity")
    require(String.eq(String.join(view_args(unbox(same)),"|"),String.join(view_args(tools_origin()),"|")),
      "same-snapshot Why preserves verified Tools identity")
    require(String.eq(String.join(Gui.text_view_args(5,["blame","/repo","file","1","2"],view_args(tools_origin()),"7",""),"|"),"blame|/repo|file|1|2"),
      "file provenance continues to own its request arguments")

def second_source_contract() -> IO(Unit):
  +shown = box(second_loaded(second_report()))
  +wronggen = replace(second_report(),"capture",replace(Json.field(second_report(),"capture"),"generation",Json.JString{"3"}))
  do IO<Unit>:
    require(Gui.usage_ready(Gui.navigation(unbox(shown))) && String.contains(UI.reader(ui(unbox(shown))),"input150 / cached50 / output30"),
      "Codex snapshot2 generation2 Usage is accepted after the Claude Tools and scoped-search flow")
    require(String.eq(UI.reader(ui(second_loaded(wronggen))),UI.reader(ui(second_origin()))),
      "second-source Usage still rejects a reply with the first source generation")
    require(String.eq(selected(Gui.usage_restore(unbox(shown))),selected(second_origin())) &&
      String.eq(UI.reader(ui(Gui.usage_restore(unbox(shown)))),UI.reader(ui(second_origin()))),
      "Codex Usage Back restores its own exact range and provider scope")
    require(Bool.not(Gui.usage_view_identity(view_args(tools_origin()),Json.field(second_report(),"capture"))),
      "foreign captured metadata remains an identity mismatch rather than weakening the Usage guard")

def capture_hint_contract() -> IO(Unit):
  +pending = box(Gui.usage(origin()))
  +shown = box(loaded(report()))
  do IO<Unit>:
    require(Bool.not(Gui.capture_suspended(origin())),"ordinary History has no navigation capture hold")
    require(Gui.capture_suspended(unbox(pending)) && Bool.not(UI.whole_usage(ui(unbox(pending)))),"pending Usage shows capture hold before title changes")
    require(Gui.capture_suspended(unbox(shown)),"accepted Usage retains the capture hold")
    require(Bool.not(Gui.capture_suspended(Gui.usage_restore(unbox(shown)))),"Back clears the navigation capture hold")
    require(String.eq(Gui.settings_automatic(Gui.settings_model(origin())),Gui.settings_automatic(Gui.settings_model(unbox(pending)))),"navigation hold leaves saved refresh preference label unchanged")

def main() -> IO(Unit):
  do IO<Unit>:
    identities()
    coverage_contract()
    partial_contract()
    codex_contract()
    claude_completeness()
    navigation_contract()
    capture_hint_contract()
    strict_controller()
    actions()
    nested_navigation()
    pending_worker()
    source_metadata_contract()
    metadata_failure_contract()
    second_source_contract()
