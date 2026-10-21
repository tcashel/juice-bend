import Base
import ../src/gui.bend as Gui
import ../src/gui_relations.bend as R
import ../src/gui_files.bend as Files
import ../src/ui.bend as UI
import ../src/query.bend as Query
import ../src/json.bend as Json

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def field(key: String,value: String) -> Json.Field:
  Json.JField{key,Json.JString{value}}

def num(key: String,value: U32) -> Json.Field:
  Json.JField{key,Json.JNumber{U32.show(value)}}

def replace_fields(values: List<&2,Json.Field>,+key: String,+value: Json.Json) -> List<&2,Json.Field>:
  match values:
    case []: []
    case Json.JField{+name,old} <> rest:
      Json.JField{name,Bool.pick(Json.Json,String.eq(name,key),value,old)} <> replace_fields(rest,key,value)

def replace(value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{replace_fields(values,key,replacement)}
    case _: value

def ref(source: String,snapshot: String) -> Json.Json:
  Json.JObject{[field("provider","codex"),field("source",source),field("generation","3"),field("snapshot",snapshot),field("extent","90000")]}

def anchor_ref() -> Json.Json:
  ref("/synthetic/origin café 中文.jsonl","7")

def child_ref() -> Json.Json:
  ref("/synthetic/child 🙂.jsonl","9")

def known(value: String) -> Json.Json:
  Json.JObject{[field("kind","known"),field("value",value),num("record",0)]}

def parent() -> Json.Json:
  Json.JObject{[field("kind","recorded"),field("id","origin"),num("record",0)]}

def facts(reference: Json.Json) -> Json.Json:
  Json.JObject{[Json.JField{"reference",reference},Json.JField{"session",known("actor")},
    Json.JField{"repository",known("/synthetic/repository")},Json.JField{"parent",parent()},
    num("inspected",2),num("total_records",45),num("bytes",100),Json.JField{"complete",Json.JBool{False{}}},field("coverage","")]}

def row() -> Json.Json:
  Json.JObject{[Json.JField{"target",facts(child_ref())},field("direction","child"),field("basis","recorded_parent_thread_id"),
    Json.JField{"witness",child_ref()},num("record",0),Json.JField{"ambiguous_on_page",Json.JBool{False{}}}]}

def filters() -> Query.Filters:
  Query.Filters{"","codex","/synthetic/repository","assistant","2026-10-20"}

def scope() -> Json.Json:
  Json.JObject{[field("provider","codex"),field("repository","/synthetic/repository"),field("role","assistant"),field("after","2026-10-20")]}

def page(+after: String,next: Json.Json,values: List<&2,Json.Json>) -> Json.Json:
  Json.JObject{[field("kind","related_captures"),Json.JField{"anchor",facts(anchor_ref())},field("watermark","100"),
    field("after_source",after),Json.JField{"next_source",next},num("requested_limit",15),num("limit",15),num("scanned_sources",15),
    num("inspected_records",4),num("inspected_bytes",200),
    Json.JField{"coverage",Json.JObject{[num("unknown",2),num("conflicting",1),num("unsupported",0),num("partial",3),num("unexamined_budget",1)]}},
    Json.JField{"scope",scope()},Json.JField{"rows",Json.JArray{values}},field("text","Related page cursor " ++ after ++ "\nExact retained evidence café 中文 🙂\nAbsence here is not proof of no relatives.")]}

def first() -> Json.Json:
  page("0",Json.JString{"42"},[row()])

def accepted(result: Result<&2,&2,String,R.Page>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def valid(value: Json.Json) -> Bool:
  accepted(R.decode(value,filters()))

def protocol_shapes() -> IO(Unit):
  do IO<Unit>:
    require(valid(first()),"typed page accepts absolute Unicode locators and exact immutable references")
    require(Bool.not(valid(replace(first(),"rows",Json.JObject{[]}))),"wrong-shaped rows cannot masquerade as an empty page")
    require(Bool.not(valid(replace(first(),"anchor",Json.JNull{}))),"anchor facts must be a typed object")
    require(Bool.not(valid(replace(first(),"next_source",Json.JNumber{"42"}))),"source continuation is an exact string rather than a numeric coercion")
    require(Bool.not(valid(replace(first(),"next_source",Json.JString{"0"}))),"source continuation must advance beyond its cursor")
    require(Bool.not(valid(replace(first(),"watermark",Json.JString{"9223372036854775808"}))),"watermark cannot exceed signed SQLite identity range")
    require(Bool.not(valid(replace(first(),"inspected_records",Json.JNumber{"257"}))),"verified record budget is bounded")
    require(Bool.not(valid(replace(first(),"inspected_bytes",Json.JNumber{"2097153"}))),"retained raw byte budget is bounded")

def protocol_rows() -> IO(Unit):
  +bad_repo = replace(row(),"target",replace(facts(child_ref()),"repository",known("/other/repository")))
  +bad_provider = replace(first(),"anchor",facts(replace(anchor_ref(),"provider",Json.JString{"claude"})))
  +empty_other = replace(page("0",Json.JNull{},[]),"anchor",replace(facts(anchor_ref()),"repository",known("/other/repository")))
  do IO<Unit>:
    require(Bool.not(valid(page("0",Json.JNull{},[bad_repo]))),"emitted target cannot contradict anchor or frozen repository scope")
    require(Bool.not(valid(bad_provider)),"nonempty provider scope must match the anchor provider")
    require(valid(empty_other),"empty repository-mismatched page remains an honest bounded observation")
    require(Bool.not(valid(page("0",Json.JNull{},[replace(row(),"witness",anchor_ref())]))),"child witness must identify the child's exact captured snapshot")
    require(Bool.not(valid(page("0",Json.JNull{},[replace(row(),"record",Json.JNumber{"2"})]))),"recorded witness must lie in its verified prefix")
    require(Bool.not(valid(page("0",Json.JNull{},[replace(row(),"ambiguous_on_page",Json.JString{"false"})]))),"ambiguity is a typed page-local boolean")
    require(valid(page("0",Json.JString{"42"},[])),"empty page with continuation and coverage budget remains valid")
    require(valid(page("42",Json.JNull{},[row(),row()])),"separate relation occurrences are not merged by shared target identity")

def protocol_edges() -> IO(Unit):
  +associated = {Json.JObject{[field("kind","path_associated"),field("locator","/synthetic/origin café 中文.jsonl"),field("parent_alias","path-parent"),field("child_alias","path-child")]} : Json.Json}
  +path_row = replace(replace(replace(row(),"basis",Json.JString{"retained_path_association"}),"record",Json.JNull{}),
    "target",replace(facts(child_ref()),"parent",associated))
  +complete = replace(replace(replace(facts(anchor_ref()),"total_records",Json.JNumber{"2"}),"complete",Json.JBool{True{}}),"coverage",Json.JString{"ignored later header"})
  do IO<Unit>:
    require(valid(page("0",Json.JNull{},[path_row])),"retained path association keeps null witness record and separate path aliases")
    require(valid(replace(first(),"anchor",complete)),"complete physical prefix can retain explicit unsupported metadata coverage")
    require(valid(replace(first(),"watermark",Json.JString{"9007199254740993"})),"watermark above IEEE exact-integer range stays an exact string")
    require(Bool.not(valid(replace(first(),"watermark",Json.JString{"0100"}))),"noncanonical decimal identities are rejected")
    require(Bool.not(valid(replace(first(),"scope",replace(scope(),"role",Json.JString{"user"})))),"worker cannot silently widen or replace the frozen role filter")

def origin_ui() -> UI.State:
  UI.set_edit(UI.set_position(UI.set_results(UI.set_rows(UI.set_scope(UI.set_reader(UI.set_query(UI.init(),
    "needle role:assistant"),"Origin Tools snapshot7","Original reader café 中文 🙂\nimmutable text"),"codex"),["first","chosen"]),
    UI.Results{100,2,True{},True{}}),1,7),UI.Edit{2,19,4,False{},0})

def origin_selection() -> Gui.Selection:
  Gui.Selection{[Gui.Item{"7",40,"origin","codex","/synthetic/repository","3",filters()}],"7",40,24,
    ["activity","7","/synthetic/origin café 中文.jsonl","3","90000","codex","45","0","5"],filters(),
    Gui.Listing{2,Query.Filters{"needle","codex","/synthetic/repository","assistant","2026-10-20"},100,True{},True{},""}}

def origin() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-related-tests","/usr/bin/false",origin_ui(),origin_selection(),
    Gui.Form{0,"needle role:assistant","","",Files.empty(),[],[]},Gui.Jobs{9,None{},None{},None{},False{}},60000n,0}

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

def filters_observation(value: Query.Filters) -> String:
  Query.Filters{query,provider,repo,role,after} = value
  String.join([Json.quote(query),Json.quote(provider),Json.quote(repo),Json.quote(role),Json.quote(after)],",")

def item_observations(items: List<&2,Gui.Item>) -> String:
  match items:
    case []: ""
    case Gui.Item{snap,start,title,provider,repo,generation,filters} <> rest:
      String.join([Json.quote(snap),U32.show(start),Json.quote(title),Json.quote(provider),Json.quote(repo),
        Json.quote(generation),filters_observation(filters)],",") ++ "\n" ++ item_observations(rest)

def selection_observation(value: Gui.Selection) -> String:
  Gui.Selection{items,snap,start,kind,args,Query.Filters{q,p,r,role,after},Gui.Listing{lk,Query.Filters{lq,lp,lr,lrole,la},offset,more,loaded,anchor}} = value
  String.join([snap,U32.show(start),U32.show(kind),String.join(args,"|"),q,p,r,role,after,U32.show(lk),lq,lp,lr,lrole,la,U32.show(offset),anchor,
    Bool.pick(String,more,"more","end"),Bool.pick(String,loaded,"loaded","pending"),item_observations(items)],";")

def selection(state: Gui.State) -> String:
  Gui.State{_,_,_,_,selection,_,_,_,_} = state
  selection_observation(selection)

def input(state: UI.State) -> String:
  UI.State{_,UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,drag,viewport},command,shift},_,_} = state
  String.join([U32.show(selected),U32.show(scroll),U32.show(focus),U32.show(caret),U32.show(anchor),U32.show(viewport),
    Bool.pick(String,drag,"drag","idle"),Bool.pick(String,command,"command","up"),Bool.pick(String,shift,"shift","up")],"|")

def chrome(state: UI.State) -> String:
  UI.State{UI.Content{query,rows,reader,lines,title,status,scope,+results,files},input,image,dirty} = state
  String.join([String.join(rows,"|"),status,UI.result_label(results),
    Bool.pick(String,UI.result_available(results,True{}),"next","end"),
    Bool.pick(String,UI.result_available(results,False{}),"previous","first"),Bool.pick(String,files,"files","capture")],";")

def same_ui(+a: UI.State,+b: UI.State) -> Bool:
  String.eq(UI.reader(a),UI.reader(b)) && String.eq(UI.title(a),UI.title(b)) && String.eq(UI.query(a),UI.query(b)) &&
    String.eq(UI.scope(a),UI.scope(b)) && String.eq(input(a),input(b)) && String.eq(chrome(a),chrome(b))

def ui_observation(+state: UI.State) -> String:
  String.join([Json.quote(UI.reader(state)),Json.quote(UI.title(state)),Json.quote(UI.query(state)),
    Json.quote(UI.scope(state)),Json.quote(input(state)),Json.quote(chrome(state))],"\n")

def captured_observation(state: Gui.State) -> String:
  Gui.State{_,_,_,ui,selection,Gui.Form{_,search,_,_,_,_,_},_,_,_} = state
  Json.quote(selection_observation(selection)) ++ "\n" ++ ui_observation(ui) ++ "\n" ++ Json.quote(search)

def origin_observation() -> String:
  Json.quote(selection_observation(origin_selection())) ++ "\n" ++ ui_observation(origin_ui()) ++ "\n" ++ Json.quote("needle role:assistant")

# Complete observations are returned before constructing the comparison state.
# This preserves the checks while keeping native continuations bounded.
def restored_origin(make: Unit -> Gui.State,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : String <- IO.pure(String,captured_observation(make(Unit{})))
    require(String.eq(actual,origin_observation()),label)

# Two independent fixture states must stay boxed between transitions: the
# compiler may lift closed thunk bodies before an IO continuation runs.
def origin_box() -> List<&2,Gui.State>:
  [origin()]

def enter_box(values: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match values:
    case state <> []: [Gui.related_enter(state)]
    case _: []

def attach_box(current: List<&2,Gui.State>,saved: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match current saved:
    case state <> [] prior <> []: [Gui.set_navigation(state,Gui.navigation(prior))]
    case _ _: []

def back_box(values: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match values:
    case state <> []: [Gui.related_back(state)]
    case _: []

def boxed_observation(values: List<&2,Gui.State>) -> String:
  match values:
    case state <> []: captured_observation(state)
    case _: "INVALID TEST STATE BOX"

def apply(+state: Gui.State,value: Json.Json) -> Gui.State:
  Gui.read_current(state,request(state),Gui.Reply{Done{value}},True{})

def loaded() -> Gui.State:
  apply(Gui.related_enter(origin()),first())

def target_pending() -> Gui.State:
  Gui.related_open(loaded(),0)

def target() -> Gui.State:
  apply(target_pending(),Json.JObject{[field("text","Target snapshot9 reader café 🙂")]})

def tools_reply() -> Json.Json:
  Json.JObject{[field("kind","recorded_activity"),field("provider","codex"),field("source","/synthetic/child 🙂.jsonl"),
    field("generation","3"),field("snapshot","9"),field("extent","90000"),num("total_records",45),num("start",0),
    num("requested_count",40),num("selected_count",40),num("verified_count",40),num("next",40),Json.JField{"scope",scope()},
    field("text","Target Tools complete arguments café 🙂\nexact citations")]}

def target_tools() -> Gui.State:
  apply(Gui.tools(target()),tools_reply())

def returned(result: Maybe<Gui.State>) -> Gui.State:
  match result:
    case Some{state}: state
    case None{}: origin()

def navigation_enter() -> IO(Unit):
  do IO<Unit>:
    require(Bool.not(Gui.navigation_active(Gui.navigation_value([]))) &&
      Bool.not(Gui.navigation_active(Gui.navigation_value([Gui.navigation(Gui.related_enter(origin())),Gui.NoNavigation{}]))),
      "boxed navigation accepts only zero or one exact saved object")
    require(String.eq(boxed_observation(back_box(attach_box(origin_box(),enter_box(origin_box())))),origin_observation()),
      "navigation boxing retains the complete origin bookmark without flattening it")
    require(String.eq(wanted(Gui.related_enter(origin())),"relations-scope|7|15|codex|/synthetic/repository|assistant|2026-10-20"),"Related initial request freezes snapshot and all four reader filters")
    require(String.contains(UI.reader(ui(loaded())),"cursor 0") && U32.is_eq(Gui.navigation_phase(Gui.navigation(loaded())),0),"valid first page becomes visible without changing the saved origin")
    restored_origin(unit => Gui.related_back(loaded()),
      "Back from Related restores exact reader identity listing query offset selection text caret and scroll")
    restored_origin(unit => Gui.related_back(Gui.related_enter(origin())),
      "Back during initial load restores the origin synchronously")

def navigation_target() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(wanted(target_pending()),"session-scope|9|0|40|codex|/synthetic/repository|assistant|2026-10-20"),"candidate opens exact target snapshot record0 with frozen scope")
    require(String.eq(UI.reader(ui(target())),"Target snapshot9 reader café 🙂") && U32.is_eq(Gui.navigation_phase(Gui.navigation(target())),2),"target response becomes a captured reader in the second navigation level")
    require(String.eq(wanted(Gui.tools(target())),"activity-scope|9|0|40|codex|/synthetic/repository|assistant|2026-10-20"),"Tools uses the selected exact target and frozen filters")
    require(String.eq(wanted(Gui.paging(target(),True{})),"session-scope|9|40|40|codex|/synthetic/repository|assistant|2026-10-20"),"target transcript paging retains its snapshot and scope")
    require(same_ui(ui(Gui.related_back(target())),ui(loaded())),"first Back restores the exact rendered Related page and row selection")
    restored_origin(unit => Gui.related_back(Gui.related_back(target())),"second Back restores original Tools metadata and nonzero physical range")

def second_page() -> Gui.State:
  apply(Gui.related_paging(loaded(),True{}),page("42",Json.JNull{},[]))

def navigation_pages() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(wanted(Gui.related_paging(loaded(),True{})),"relations-page|codex|/synthetic/origin café 中文.jsonl|3|7|90000|100|42|15|codex|/synthetic/repository|assistant|2026-10-20"),"next page sends exact anchor reference watermark and source cursor")
    require(String.contains(UI.reader(ui(second_page())),"cursor 42"),"empty terminal page remains a rendered bounded observation")
    require(String.eq(wanted(Gui.related_paging(second_page(),False{})),"relations-page|codex|/synthetic/origin café 中文.jsonl|3|7|90000|100|0|15|codex|/synthetic/repository|assistant|2026-10-20"),"previous page uses saved source cursor with unchanged watermark")
    require(String.eq(wanted(Gui.related_reload(second_page())),"relations-page|codex|/synthetic/origin café 中文.jsonl|3|7|90000|100|42|15|codex|/synthetic/repository|assistant|2026-10-20"),"Refresh rereads the same page without latest or reanchoring")

def navigation_views() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.reader(ui(target_tools())),"Target Tools complete arguments café 🙂\nexact citations"),"target Tools response matches every immutable target reference field")
    require(String.eq(UI.reader(ui(apply(Gui.tools(target()),replace(tools_reply(),"extent",Json.JString{"90001"})))),UI.reader(ui(target()))),
      "target Tools refuses a changed captured extent despite matching snapshot text")
    require(same_ui(ui(Gui.related_back(target_tools())),ui(loaded())) &&
      same_ui(ui(Gui.related_back(Gui.related_back(target_tools()))),origin_ui()),"Tools retains both exact Back levels")
    require(String.eq(wanted(Gui.why(target_tools())),"why-scope|9|0|20|codex|/synthetic/repository|assistant|2026-10-20"),"Why after target Tools preserves the exact snapshot and scope")
    require(String.eq(String.join(Gui.files_export_args(ui(target_tools()),"/tmp/export.md"),"|"),
      "export-displayed|/tmp/export.md|Target Tools complete arguments café 🙂\nexact citations"),"Related export passes exact displayed text as literal worker input")
    require(Bool.not(Gui.related_export_available(Gui.navigation(Gui.related_enter(origin())))),"initial loading prompt is not exportable captured evidence")

def wrong_page() -> Gui.State:
  apply(Gui.related_paging(loaded(),True{}),replace(page("42",Json.JNull{},[]),"watermark",Json.JString{"101"}))

def stale_target() -> Gui.State:
  Gui.read_current(Gui.related_back(target_pending()),request(target_pending()),Gui.Reply{Done{Json.JObject{[field("text","STALE")]} }},False{})

def reader_request(+state: Gui.State) -> String:
  UI.reader(ui(state)) ++ "\0" ++ wanted(state)

def history_identity(+state: Gui.State) -> String:
  UI.reader(ui(state)) ++ "\0" ++ selection(state)

def files_exit_observation(+state: Gui.State) -> String:
  Bool.pick(String,Gui.related_active(state),"active","inactive") ++ "\0" ++ history_identity(Gui.files_leave(state))

def navigation_rejection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.reader(ui(wrong_page())),UI.reader(ui(loaded()))),"changed watermark is rejected without replacing displayed page")
    require(String.eq(UI.reader(ui(stale_target())),UI.reader(ui(loaded()))),"stale target reply after Back cannot replace the Related page")
    require(String.eq(reader_request(Gui.refresh_finished(loaded())),reader_request(loaded())),
      "background capture completion cannot reload the Related listing")
    require(String.eq(UI.reader(ui(Gui.refresh_finished(target()))),UI.reader(ui(target()))),"background capture completion preserves an opened target")

def files_exit_assert(state: Gui.State) -> IO(Unit):
  require(String.eq(files_exit_observation(state),"inactive\0" ++ history_identity(origin())),
    "leaving Related for Files first restores the captured origin instead of saving target as origin")

def navigation_actions() -> IO(Unit):
  do IO<Unit>:
    blocked : Maybe<Gui.State> <- Gui.handle(loaded(),UI.Tools{})
    require(U32.is_eq(Gui.navigation_phase(Gui.navigation(returned(blocked))),0),"Tools cannot interpret the Related page as a captured range")
    latest : Maybe<Gui.State> <- Gui.handle(target(),UI.OpenLatest{})
    require(String.eq(wanted(returned(latest)),wanted(target())),"Open latest is refused inside pinned Related target navigation")
    files : Maybe<Gui.State> <- Gui.handle(target(),UI.Files{})
    files_exit_assert(returned(files))
    automatic : Gui.State <- Gui.auto_refresh(loaded(),100000n)
    require(String.eq(wanted(automatic),wanted(loaded())),"automatic refresh schedules no new read in Related")

def main() -> IO(Unit):
  do IO<Unit>:
    protocol_shapes()
    protocol_rows()
    protocol_edges()
    navigation_enter()
    navigation_target()
    navigation_pages()
    navigation_views()
    navigation_rejection()
    navigation_actions()
