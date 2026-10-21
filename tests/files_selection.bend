import Base
import ../src/gui.bend as Gui
import ../src/gui_files.bend as Files
import ../src/ui.bend as UI
import ../src/query.bend as Query
import ../src/json.bend as Json
import ./gui_repository.bend as Repository

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def body() -> String:
  "prefix café 中文 🙂 suffix\nsecond line\nthird line\nfourth line"

def filters() -> Query.Filters:
  Query.Filters{"","codex","/synthetic/main","assistant","2026-10-01"}

def rows() -> List<&2,Gui.Item>:
  [Gui.Item{"6",400,"first","codex","/synthetic/main","1",filters()},
    Gui.Item{"7",500,"chosen","codex","/synthetic/main","2",filters()},
    Gui.Item{"8",600,"last","codex","/synthetic/main","3",filters()}]

def origin_ui(state: UI.State) -> UI.State:
  UI.State{content,UI.Input{selected,scroll,edit,command,shift},image,dirty} = state
  UI.State{content,UI.Input{selected,scroll,edit,True{},True{}},Pix{123},False{}}

def origin_value(state: Gui.State) -> Gui.State:
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  Gui.State{db,dir,program,origin_ui(UI.set_edit(UI.set_position(UI.set_results(UI.set_rows(UI.set_reader(ui,"Captured snapshot 7",body()),
    ["first","chosen","last"]),UI.Results{100,3,True{},True{}}),1,3),UI.Edit{2,16,7,True{},17})),
    Gui.Selection{rows(),"7",500,3,["captured-origin-metadata"],filters(),
      Gui.Listing{2,Query.Filters{"needle","codex","/synthetic/main","assistant","2026-10-01"},100,True{},True{},""}},
    form,jobs,deadline,serial}

def origin() -> Gui.State:
  origin_value(Repository.initial())

def selected_result(result: UI.State & UI.Action) -> String:
  (ui,action) = result
  match action:
    case UI.Copy{text}: text
    case _: "<no copy action>"

def copied(ui: UI.State) -> String:
  selected_result(UI.key_down(ui,99,True{}))

def selected(state: Gui.State) -> String:
  Gui.State{_,_,_,_,Gui.Selection{items,snapshot,start,kind,args,Query.Filters{q,p,r,role,after},Gui.Listing{lk,_,offset,more,loaded,anchor}},_,_,_,_} = state
  String.join([snapshot,U32.show(start),U32.show(kind),String.join(args,"|"),q,p,r,role,after,U32.show(lk),U32.show(offset),anchor],";")

def input(state: UI.State) -> String:
  UI.State{_,UI.Input{selected,scroll,UI.Edit{focus,caret,anchor,drag,viewport},command,shift},_,_} = state
  String.join([U32.show(selected),U32.show(scroll),U32.show(focus),U32.show(caret),U32.show(anchor),U32.show(viewport)],"|")

def no_transients(state: UI.State) -> Bool:
  UI.State{_,UI.Input{_,_,UI.Edit{_,_,_,drag,_},command,shift},_,_} = state
  Bool.not(drag || command || shift)

def visible(state: UI.State) -> String:
  UI.State{UI.Content{query,rows,reader,lines,title,status,scope,results,files},_,_,_} = state
  String.join([query,String.join(rows,"/"),reader,title,scope,UI.result_label(results)],"|")

def image_is(image: Image,color: U32) -> Bool:
  match image:
    case Pix{value}: U32.is_eq(value,color)
    case _: False{}

def image_ready(state: UI.State,color: U32) -> Bool:
  UI.State{_,_,image,dirty} = state
  image_is(image,color) && dirty

def file_image(state: Gui.State) -> Gui.State:
  Gui.State{db,dir,program,UI.State{content,input,image,dirty},selection,form,jobs,deadline,serial} = state
  Gui.State{db,dir,program,UI.State{content,input,Pix{456},False{}},selection,form,jobs,deadline,serial}

def returned() -> Gui.State:
  Gui.files_leave(file_image(Gui.files_enter(origin())))

def roundtrip() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(copied(Repository.ui(returned())),"café 中文 🙂"),"Files to History retains focused Unicode selection for Command C")
    require(String.eq(input(Repository.ui(returned())),"1|3|2|16|7|17"),"History restores selected row scroll focus caret anchor and viewport")
    require(String.eq(visible(Repository.ui(returned())),visible(Repository.ui(origin()))),"History restores exact query rows title body scope and result metadata")
    require(String.eq(selected(returned()),selected(origin())),"History retains exact captured identity filters range metadata and listing")
    require(String.eq(Repository.wanted(returned()),"none"),"accepted reader restoration does not schedule a reread")
    require(no_transients(Repository.ui(returned())),"History clears stale command shift and drag state")
    require(image_ready(Repository.ui(returned()),456),"History redraws using current image rather than retaining old rendered image")
    require(Bool.not(Gui.files_active(returned())) && Bool.not(UI.is_files(Repository.ui(returned()))),"History exits Files input and display modes")

def sanitized_saved(saved: Files.Saved) -> Bool:
  match saved:
    case Files.Saved{[UI.Bookmark{content,UI.Input{_,_,UI.Edit{_,_,_,drag,_},command,shift}}]}: Bool.not(drag || command || shift)
    case _: False{}

def query_origin() -> Gui.State:
  +state = origin()
  Gui.replace_ui(state,UI.set_edit(Repository.ui(state),UI.Edit{0,5,1,True{},3}))

def query_return() -> Gui.State:
  Gui.files_leave(Gui.files_enter(query_origin()))

def query_selection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(copied(Repository.ui(query_return())),"eedl"),"query text selection survives Files without switching to reader text")
    require(String.eq(input(Repository.ui(query_return())),"1|3|0|5|1|3"),"query focus and horizontal viewport restore exactly")
    require(sanitized_saved(Gui.files_saved_for(query_origin())),"valid origin produces one sanitized bookmark")

def pending() -> Gui.State:
  Gui.queue(origin(),Gui.Request{3,["session-scope","8","600","40","codex","/synthetic/main","assistant","2026-10-01"],"8",600,"Pending snapshot 8"})

def pending_return() -> Gui.State:
  Gui.files_leave(Gui.files_enter(pending()))

def revision(state: Gui.State) -> U32:
  Gui.State{_,_,_,_,_,_,Gui.Jobs{revision,_,_,_,_},_,_} = state
  revision

def late_return() -> Gui.State:
  Gui.read_current(pending_return(),Gui.Request{3,["session-scope","8","600","40","codex","/synthetic/main","assistant","2026-10-01"],"8",600,"Pending snapshot 8"},
    Gui.Reply{Done{Json.JObject{[Json.JField{"text",Json.JString{"late replacement"}}]}}},False{})

def pending_selection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(copied(Repository.ui(pending_return())),"café 中文 🙂"),"pending different capture does not replace the last accepted reader bookmark")
    require(String.eq(selected(pending_return()),selected(origin())),"pending different capture keeps original snapshot and range after return")
    require(String.eq(Repository.wanted(pending_return()),"none") && U32.is_gt(revision(pending_return()),revision(pending())),"Files cancels queued request identity without scheduling an unwanted reread")
    require(String.eq(visible(Repository.ui(late_return())),visible(Repository.ui(origin()))),"late invalidated captured reply cannot overwrite restored reader")
    require(String.eq(input(Repository.ui(late_return())),"1|3|2|16|7|17"),"late invalidated reply cannot disturb restored selection")

def invalid(state: Gui.State,snapshot: String,kind: U32) -> Gui.State:
  Gui.State{db,dir,program,ui,Gui.Selection{items,old,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  Gui.State{db,dir,program,UI.set_reader(ui,"Settings or pending help","not accepted captured evidence"),
    Gui.Selection{items,snapshot,start,kind,args,filters,listing},form,jobs,deadline,serial}

def invalid_return() -> Gui.State:
  Gui.files_leave(Gui.files_enter(invalid(origin(),"7",0)))

def empty_return() -> Gui.State:
  Gui.files_leave(Gui.files_enter(invalid(origin(),"",3)))

def invalid_selection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.title(Repository.ui(invalid_return())),"History"),"invalid origin returns truthful History placeholder")
    require(Bool.not(String.contains(UI.reader(Repository.ui(invalid_return())),"not accepted")),"invalid helper text is never relabeled as a captured transcript")
    require(String.eq(Repository.wanted(invalid_return()),"session-scope|7|500|40|codex|/synthetic/main|assistant|2026-10-01"),"invalid origin rereads only exact pinned snapshot range and scope")
    require(String.eq(Repository.wanted(empty_return()),"none"),"missing snapshot never rereads an empty capture identity")
    require(String.eq(UI.title(Repository.ui(empty_return())),"History"),"missing identity cannot bless valid-looking displayed kind")
    require(Bool.not(Gui.files_saved_ready(Files.Saved{[]})),"missing bookmark is not considered ready")
    require(Bool.not(Gui.files_saved_ready(Files.Saved{[UI.bookmark(UI.init()),UI.bookmark(UI.init())]})),"multiple bookmarks are rejected rather than selecting an arbitrary reader")

def settings_return() -> Gui.State:
  Gui.files_leave(Gui.settings_leave(Gui.settings_enter(Gui.files_enter(origin()))))

def nested_selection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(copied(Repository.ui(settings_return())),"café 中文 🙂"),"Files Settings Back History retains original Unicode selection")
    require(String.eq(selected(settings_return()),selected(origin())),"nested Settings round trip retains capture selection and filters")
    require(String.eq(input(Repository.ui(settings_return())),"1|3|2|16|7|17"),"nested Settings round trip retains list and text positions")

def provider_return() -> Gui.State:
  +state = Gui.files_enter(origin())
  Gui.scope_changed(Gui.replace_ui(state,UI.set_scope(Repository.ui(state),"claude")))

def provider_selection() -> IO(Unit):
  do IO<Unit>:
    require(String.eq(UI.scope(Repository.ui(provider_return())),"claude"),"explicit provider click overrides saved sidebar scope")
    require(String.eq(Repository.wanted(provider_return()),"search|needle|claude||||0"),"provider click requests the chosen scope after restoring History")
    require(String.eq(UI.reader(Repository.ui(provider_return())),body()),"provider click retains accepted reader until the new listing arrives")

def main() -> IO(Unit):
  do IO<Unit>:
    roundtrip()
    query_selection()
    pending_selection()
    invalid_selection()
    nested_selection()
    provider_selection()
    Repository.main()
