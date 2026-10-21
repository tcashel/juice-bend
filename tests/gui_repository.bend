import Base
import ../src/gui.bend as Gui
import ../src/gui_files.bend as Files
import ../src/ui.bend as UI
import ../src/json.bend as Json
import ../src/query.bend as Query

def require(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def sha() -> String:
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

def field(key: String,value: String) -> Json.Field:
  Json.JField{key,Json.JString{value}}

def num(key: String,value: U32) -> Json.Field:
  Json.JField{key,Json.JNumber{U32.show(value)}}

def identity_fields() -> List<&2,Json.Field>:
  [field("repository","/synthetic/main"),field("checkout","/synthetic/worktree"),field("commit",sha())]

def object(fields: List<&2,Json.Field>) -> Json.Json:
  Json.JObject{List.append(&2,Json.Field,identity_fields(),fields)}

def node(path: String,kind: String) -> Json.Json:
  Json.JObject{[field("path",path),field("kind",kind),field("object",sha()),field("bytes","12")]}

def directory(path: String,offset: U32,total: U32,nodes: List<&2,Json.Json>,next: Json.Json) -> Json.Json:
  object([field("kind","repository_directory"),field("path",path),num("offset",offset),num("limit",100),num("total",total),
    Json.JField{"nodes",Json.JArray{nodes}},Json.JField{"next",next},field("text","Pinned committed directory")])

def root() -> Json.Json:
  directory("",0,4,[node("folder","directory"),node("a.bend","file"),node("link","symlink"),node("sub","submodule")],Json.JNull{})

def line(number: U32) -> Json.Json:
  Json.JObject{[num("number",number),field("text","café 中文 🙂")]}

def lines(count: Nat,+first: U32) -> List<&2,Json.Json>:
  match count:
    case 0n:
      []
    case 1n+n:
      line(first) <> lines(n,U32.add(first,1))

def source(+first: U32,count: U32,total: U32,next: Json.Json) -> Json.Json:
  object([field("kind","repository_source"),field("path","a.bend"),field("blob",sha()),field("bytes","900"),num("total_lines",total),num("start",first),
    Json.JField{"lines",Json.JArray{lines(U32.to_nat(count),first)}},Json.JField{"next",next},Json.JField{"final_newline",Json.JBool{True{}}},field("text","Pinned source café 中文 🙂")])

def evidence(kind: String,count: U32) -> Json.Json:
  object([field("kind",kind),field("path","a.bend"),num("start",41),num("count",count),field("text","Exact pinned evidence")])

def initial() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-gui-files","/usr/bin/false",UI.set_position(UI.set_reader(UI.set_query(UI.init(),"needle"),"Captured snapshot 7","retained captured Unicode café"),0,3),
    Gui.Selection{[],"7",500,3,[],Query.Filters{"","codex","/synthetic/main","assistant","2026-10-01"},Gui.empty_listing()},
    Gui.Form{0,"needle","","",Files.empty(),[]},Gui.Jobs{9,None{},None{},None{},False{}},0n,0}

def ui(state: Gui.State) -> UI.State:
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  ui

def wanted_value(value: Maybe<&2,Gui.Request>) -> String:
  match value:
    case None{}:
      "none"
    case Some{Gui.Request{kind,args,snapshot,start,title}}:
      String.join(args,"|")

def wanted(state: Gui.State) -> String:
  Gui.State{db,dir,program,ui,selection,form,Gui.Jobs{revision,wanted,reader,writer,paused},deadline,serial} = state
  wanted_value(wanted)

def capture(state: Gui.State) -> String:
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,kind,args,Query.Filters{query,provider,repo,role,after},listing},form,jobs,deadline,serial} = state
  snap ++ "|" ++ U32.show(start) ++ "|" ++ U32.show(kind) ++ "|" ++ provider ++ "|" ++ repo ++ "|" ++ role ++ "|" ++ after

def ui_status(value: UI.State) -> String:
  UI.State{UI.Content{q,rows,text,lines,title,status,scope,results,files},input,image,dirty} = value
  status

def status(state: Gui.State) -> String:
  ui_status(ui(state))

def opened() -> Gui.State:
  Gui.read_current(Gui.files_enter(initial()),Gui.Request{20,["repo-open","/synthetic/worktree"],"",0,""},Gui.Reply{Done{root()}},True{})

def sourced() -> Gui.State:
  Gui.read_current(opened(),Gui.Request{21,["repo-source","/synthetic/worktree",sha(),"a.bend","41","40"],"",41,""},
    Gui.Reply{Done{source(41,2,42,Json.JNull{})}},True{})

def entry() -> IO(Unit):
  +entered = Gui.files_enter(initial())
  do IO<Unit>:
    require(Gui.files_active(entered) && UI.is_files(ui(entered)),"Files uses a distinct input and navigation mode")
    require(String.eq(wanted(entered),"none") && String.eq(capture(entered),capture(initial())),"entering Files performs no scan and retains capture identity")
    require(String.eq(wanted(Gui.files_open_repo(entered)),"none"),"empty Files root cannot open or scan")
    require(String.eq(wanted(Gui.files_open_repo(Gui.replace_ui(entered,UI.set_query(ui(entered),"/synthetic/worktree")))),"repo-open|/synthetic/worktree"),"explicit root input requests one pinned HEAD")
    require(String.eq(wanted(Gui.files_open_repo(Gui.replace_ui(entered,UI.set_query(ui(entered),"/synthetic/space repo ")))),"repo-open|/synthetic/space repo "),"Files preserves literal root path spaces for backend validation")

def navigation() -> IO(Unit):
  +opened = opened()
  do IO<Unit>:
    require(String.eq(wanted(Gui.files_select(opened,0)),"repo-tree|/synthetic/worktree|" ++ sha() ++ "|folder|0"),"directory click uses exact worktree and pinned commit")
    require(String.eq(wanted(Gui.files_select(opened,1)),"repo-source|/synthetic/worktree|" ++ sha() ++ "|a.bend|1|40"),"file click requests bounded committed source")
    require(String.contains(status(Gui.files_select(opened,2)),"Unsupported symlink") && String.eq(wanted(Gui.files_select(opened,2)),"none"),"symlink rows are explicit and never followed")
    require(String.contains(status(Gui.files_select(opened,3)),"Unsupported submodule"),"submodule rows remain unsupported")
    require(String.eq(wanted(Gui.files_select(opened,100)),"none"),"nonexistent directory rows cannot become transcript selections")
    require(String.eq(Files.parent("a/b/c"),"a/b") && String.eq(Files.parent("a"),"") && String.eq(Files.parent(""),""),"parent navigation terminates at pinned root")

def source_actions() -> IO(Unit):
  +shown = sourced()
  do IO<Unit>:
    require(String.eq(capture(shown),capture(initial())),"source arrival cannot mutate captured snapshot range or filters")
    require(String.eq(wanted(Gui.paging(shown,False{})),"repo-source|/synthetic/worktree|" ++ sha() ++ "|a.bend|1|40"),"source Previous uses pinned identity and forty-line range")
    require(String.eq(wanted(Gui.paging(shown,True{})),"none"),"final source page does not request beyond EOF")
    require(String.eq(wanted(Gui.blame(shown)),"repo-blame|/synthetic/worktree|" ++ sha() ++ "|a.bend|41|2"),"Blame binds the actual displayed short range")
    require(String.eq(wanted(Gui.why(shown)),"repo-why|/synthetic/worktree|" ++ sha() ++ "|a.bend|41|2"),"Why binds the same pinned displayed range")
    require(String.contains(status(Gui.usage(shown)),"Return to History"),"Files cannot reinterpret captured snapshot as usage")

def restoration() -> IO(Unit):
  +back = Gui.files_leave(sourced())
  do IO<Unit>:
    require(Bool.not(Gui.files_active(back)) && Bool.not(UI.is_files(ui(back))),"History exits Files mode")
    require(String.eq(UI.reader(ui(back)),UI.reader(ui(initial()))) && String.eq(UI.title(ui(back)),"Captured snapshot 7"),"History visibly restores exact captured reader text and title")
    require(U32.is_eq(UI.scroll(ui(back)),3) && String.eq(UI.query(ui(back)),"needle") && String.eq(capture(back),capture(initial())),"History restores reader scroll query and scoped identity")
    require(String.eq(wanted(Gui.paging(back,False{})),"session-scope|7|460|40|codex|/synthetic/main|assistant|2026-10-01"),"restored transcript paging retains captured filters")

def stale_and_identity() -> IO(Unit):
  +request = {Gui.Request{21,["repo-source","/synthetic/worktree",sha(),"a.bend","41","40"],"",41,""} : Gui.Request}
  +stale = Gui.read_current(Gui.files_leave(opened()),request,Gui.Reply{Done{source(41,2,42,Json.JNull{})}},False{})
  do IO<Unit>:
    require(String.eq(UI.reader(ui(stale)),UI.reader(ui(initial()))),"stale repository reply cannot replace returned History")
    require(Bool.not(Files.valid(21,Gui.files_model(opened()),["repo-source","/synthetic/main",sha(),"a.bend","41","40"],source(41,2,42,Json.JNull{}))),"canonical repository cannot substitute for selected worktree")
    require(Bool.not(Files.valid(21,Gui.files_model(opened()),["repo-source","/synthetic/worktree","bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","a.bend","41","40"],source(41,2,42,Json.JNull{}))),"different commit is rejected even when source path matches")
    require(Bool.not(Files.valid(21,Gui.files_model(opened()),["repo-source","/synthetic/worktree",sha(),"other.bend","41","40"],source(41,2,42,Json.JNull{}))),"mismatched source path is rejected")

def protocol() -> IO(Unit):
  +model = Gui.files_model(opened())
  do IO<Unit>:
    require(Files.valid(21,model,["repo-source","/synthetic/worktree",sha(),"a.bend","1","40"],source(1,40,42,Json.JNumber{"41"})),"source page validates exact contiguous range and next line")
    require(Bool.not(Files.valid(21,model,["repo-source","/synthetic/worktree",sha(),"a.bend","1","2"],source(1,3,3,Json.JNull{}))),"source reply cannot exceed requested line count")
    require(Bool.not(Files.valid(21,model,["repo-source","/synthetic/worktree",sha(),"a.bend","1","40"],source(1,39,42,Json.JNumber{"40"}))),"short nonfinal source page is rejected")
    require(Bool.not(Files.valid(20,model,["repo-tree","/synthetic/worktree",sha(),"","0"],directory("",0,2,[node("a","file")],Json.JNumber{"1"}))),"directory page must contain every expected bounded row")
    require(Files.valid(22,model,["repo-blame","/synthetic/worktree",sha(),"a.bend","41","2"],evidence("repository_blame",2)) &&
      Bool.not(Files.valid(22,model,["repo-blame","/synthetic/worktree",sha(),"a.bend","41","2"],evidence("repository_blame",40))),"evidence response must retain requested displayed count")

def settings_roundtrip() -> IO(Unit):
  +back = Gui.files_leave(Gui.files_enter(Gui.settings(initial())))
  do IO<Unit>:
    require(String.eq(wanted(back),"session-scope|7|500|40|codex|/synthetic/main|assistant|2026-10-01"),
      "Files entered from Settings returns by reading the exact selected capture")
    require(String.eq(UI.title(ui(back)),"History") && Bool.not(String.contains(UI.reader(ui(back)),"Enable a history folder")),
      "History never relabels Settings text as a restored transcript")

def departure_settings() -> IO(Unit):
  +next = Gui.settings(sourced())
  require(Bool.not(UI.is_files(ui(next))) && String.eq(wanted(next),"sources"),
    "Settings exits Files labels and requests registered sources")

def departure_storage() -> IO(Unit):
  +next = Gui.storage(sourced())
  require(Bool.not(UI.is_files(ui(next))) && String.eq(wanted(next),"storage"),
    "Storage exits Files labels without changing capture identity")

def departure_filter() -> IO(Unit):
  +next = Gui.filter_help(sourced())
  require(Bool.not(UI.is_files(ui(next))) && String.contains(UI.reader(ui(next)),"Optional filters"),
    "Filter exits Files to a truthful help view")

def departure_scope() -> IO(Unit):
  +next = Gui.scope_changed(sourced())
  require(Bool.not(UI.is_files(ui(next))) && String.eq(UI.reader(ui(next)),"retained captured Unicode café"),
    "provider scope exits Files and restores retained transcript")

def exact_export() -> IO(Unit):
  require(String.eq(String.join(Gui.files_export_args(ui(sourced()),"/tmp/output"),"|"),"export-displayed|/tmp/output|Pinned source café 中文 🙂"),
    "Files export carries exact displayed Unicode and no captured snapshot argument")

def replace_fields(fields: List<&2,Json.Field>,+key: String,+value: Json.Json) -> List<&2,Json.Field>:
  match fields:
    case []:
      []
    case Json.JField{+name,old} <> rest:
      Json.JField{name,Bool.pick(Json.Json,String.eq(name,key),value,old)} <> replace_fields(rest,key,value)

def replace(value: Json.Json,key: String,new: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{fields}:
      Json.JObject{replace_fields(fields,key,new)}
    case other:
      other

def malformed_pages() -> IO(Unit):
  +model = Gui.files_model(opened())
  +args = {["repo-source","/synthetic/worktree",sha(),"a.bend","1","40"] : List<&2,String>}
  do IO<Unit>:
    require(Bool.not(Files.valid(20,model,["repo-tree","/synthetic/worktree",sha(),"","0"],
      replace(directory("",0,0,[],Json.JNull{}),"nodes",Json.JString{"invalid"}))),
      "wrong directory array type cannot masquerade as empty results")
    require(Bool.not(Files.valid(21,model,args,replace(source(1,0,0,Json.JNull{}),"lines",Json.JNull{}))),
      "wrong source array type cannot masquerade as empty file")
    require(Bool.not(Files.valid(21,model,args,replace(source(1,2,2,Json.JNull{}),"lines",Json.JArray{[line(1),line(3)]}))),
      "source lines must be contiguous from requested first")
    require(Bool.not(Files.valid(21,model,args,replace(source(1,1,1,Json.JNull{}),"lines",Json.JArray{[Json.JObject{[num("number",1),num("text",1)]}]}))),
      "source text must remain a JSON string")
    require(Files.valid(21,model,["repo-source","/synthetic/worktree",sha(),"a.bend","4294967295","1"],source(4294967295,1,4294967295,Json.JNull{})),
      "last U32 line validates without exclusive-end overflow")
    require(String.contains(Files.title(Files.apply(21,model,source(1,0,0,Json.JNull{}))),"empty file"),
      "empty file never claims a visible line one")

def directory_nodes(count: Nat,+first: U32) -> List<&2,Json.Json>:
  match count:
    case 0n:
      []
    case 1n+n:
      node("many/" ++ U32.show(first),"file") <> directory_nodes(n,U32.add(first,1))

def directory_page(+offset: U32,count: Nat,next: Json.Json) -> Gui.State:
  Gui.read_current(opened(),Gui.Request{20,["repo-tree","/synthetic/worktree",sha(),"many",U32.show(offset)],"",offset,""},
    Gui.Reply{Done{directory("many",offset,107,directory_nodes(count,offset),next)}},True{})

def directory_paging() -> IO(Unit):
  +first = directory_page(0,100n,Json.JNumber{"100"})
  do IO<Unit>:
    require(String.eq(wanted(Gui.list_paging(first,True{})),"repo-tree|/synthetic/worktree|" ++ sha() ++ "|many|100"),
      "directory Next advances one bounded hundred-entry page")
    require(String.eq(wanted(Gui.list_paging(first,False{})),"none"),
      "first directory page has no Previous request")
    require(String.eq(wanted(Gui.files_parent(first)),"repo-tree|/synthetic/worktree|" ++ sha() ++ "||0"),
      "Up folder returns to parent at the same pinned commit")

def directory_end() -> IO(Unit):
  +last = directory_page(100,7n,Json.JNull{})
  do IO<Unit>:
    require(String.eq(wanted(Gui.list_paging(last,False{})),"repo-tree|/synthetic/worktree|" ++ sha() ++ "|many|0"),
      "final directory page can return to the first page")
    require(String.eq(wanted(Gui.list_paging(last,True{})),"none"),
      "final directory page never requests past end")

def pending() -> Gui.State:
  +shown = sourced()
  Gui.files_open_repo(Gui.replace_ui(shown,UI.set_query(ui(shown),"/synthetic/other")))

def pending_view() -> IO(Unit):
  +next = pending()
  require(String.eq(UI.reader(ui(next)),"Pinned source café 中文 🙂") && String.eq(capture(next),capture(initial())),
    "opening another root retains the displayed file and captured identity while pending")

def pending_evidence() -> IO(Unit):
  require(String.eq(wanted(Gui.blame(pending())),"repo-blame|/synthetic/worktree|" ++ sha() ++ "|a.bend|41|2"),
    "pending new root cannot redirect old displayed-range evidence actions")

def pending_failure() -> IO(Unit):
  require(String.eq(UI.reader(ui(Gui.files_done(pending(),Gui.Request{20,["repo-open","/synthetic/other"],"",0,""},Fail{"missing repository"}))),"Pinned source café 中文 🙂"),
    "repository failure retains readable prior pinned source")

def invalid_arrival() -> IO(Unit):
  +shown = sourced()
  +bad = Gui.files_done(shown,Gui.Request{21,["repo-source","/synthetic/worktree",sha(),"a.bend","41","40"],"",41,""},
    Done{replace(source(41,2,42,Json.JNull{}),"commit",Json.JString{"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"})})
  require(String.eq(UI.reader(ui(bad)),UI.reader(ui(shown))) && String.contains(status(bad),"did not match"),
    "current but mismatched repository response is rejected without changing displayed content")

def empty_source() -> IO(Unit):
  +empty = Gui.files_done(opened(),Gui.Request{21,["repo-source","/synthetic/worktree",sha(),"a.bend","1","40"],"",1,""},Done{source(1,0,0,Json.JNull{})})
  require(String.eq(wanted(Gui.blame(empty)),"none") && String.contains(status(Gui.why(empty)),"nonempty"),
    "empty committed source cannot claim Blame or Why for a nonexistent line")

def empty_history() -> IO(Unit):
  +back = Gui.files_leave(Gui.files_enter(Gui.initial(0,"/tmp/juice-bend-empty-files","/usr/bin/false")))
  require(Bool.not(UI.is_files(ui(back))) && String.eq(UI.title(ui(back)),"History") && String.contains(UI.reader(ui(back)),"Choose a captured session"),
    "Files without a selected capture returns to a clear History empty state")

def main() -> IO(Unit):
  do IO<Unit>:
    entry()
    navigation()
    source_actions()
    restoration()
    stale_and_identity()
    protocol()
    settings_roundtrip()
    departure_settings()
    departure_storage()
    departure_filter()
    departure_scope()
    exact_export()
    malformed_pages()
    directory_paging()
    directory_end()
    pending_view()
    pending_evidence()
    pending_failure()
    invalid_arrival()
    empty_source()
    empty_history()
