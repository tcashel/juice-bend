import Base
import ./ui.bend as UI
import ./store.bend as Store
import ./sql.bend as Sql
import ./client.bend as Client
import ./json.bend as Json
import ./query.bend as Query
import ./domain.bend as Domain
import ./provenance.bend as P
import ./gui_files.bend as Files

# The window owns no effectful database path. Every operation is a bounded call
# to this same native executable. One reader and one writer can be outstanding;
# a newer request replaces queued work and stale replies cannot replace its UI.
type Item is Data:
  Item{snapshot: String, ordinal: U32, title: String, provider: String,
    repository: String, generation: String, filters: Query.Filters}

type Request is Data:
  Request{kind: U32, args: List<&2,String>, snapshot: String, start: U32, title: String}

type Reply is Data:
  Reply{value: Result<&2,&2,String,Json.Json>}

type Pending is Data:
  Pending{ticket: U32, request: Request, channel: Chan(Reply)}

type Selection is Data:
  Selection{items: List<&2,Item>, snapshot: String, start: U32,
    displayed: U32, view_args: List<&2,String>, filters: Query.Filters, listing: Listing}

# List navigation is independent of the immutable reader selection. The full
# parsed listing filters include the lexical query; reader filters omit it.
type Listing is Data:
  Listing{kind: U32, filters: Query.Filters, offset: U32, has_more: Bool, loaded: Bool,
    anchor: String}

type Form is Data:
  Form{mode: U32, search: String, source: String, blame: String, files: Files.State}

type Jobs is Data:
  Jobs{revision: U32, wanted: Maybe<&2,Request>, reader: Maybe<&2,Pending>,
    writer: Maybe<&2,Pending>, paused: Bool}

type State is Data:
  State{db: U32, dir: String, program: String, ui: UI.State,
    selection: Selection, form: Form, jobs: Jobs, refresh_at: Nat, serial: U32}

def status(+state: State, +message: String) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = state
  State{db,dir,program,UI.set_status(ui,message),selection,form,jobs,refresh_at,serial}

def replace_ui(+state: State,+ui: UI.State) -> State:
  State{+db,+dir,+program,+old,+selection,+form,+jobs,+refresh_at,+serial} = state
  State{db,dir,program,ui,selection,form,jobs,refresh_at,serial}

def linear_args(args: List<&2,String>) -> List<String>:
  match args:
    case []:
      []
    case h <> t:
      h <> linear_args(t)

def empty_filters() -> Query.Filters:
  Query.Filters{"","","","",""}

def empty_listing() -> Listing:
  Listing{1,empty_filters(),0,False{},False{},""}

def request_filters(args: List<&2,String>) -> Query.Filters:
  match args:
    case "history" <> provider <> repo <> []:
      Query.Filters{"",provider,repo,"",""}
    case "history" <> provider <> repo <> offset <> []:
      Query.Filters{"",provider,repo,"",""}
    case "search" <> query <> provider <> repo <> role <> after <> []:
      Query.Filters{"",provider,repo,role,after}
    case "search" <> query <> provider <> repo <> role <> after <> offset <> []:
      Query.Filters{"",provider,repo,role,after}
    case "latest-view" <> snap <> provider <> repo <> role <> after <> []:
      Query.Filters{"",provider,repo,role,after}
    case cmd <> snap <> start <> count <> provider <> repo <> role <> after <> []:
      Query.Filters{"",provider,repo,role,after}
    case _:
      empty_filters()

def scoped_args(command: String,snap: String,start: U32,count: String,filters: Query.Filters) -> List<&2,String>:
  Query.Filters{query,provider,repo,role,after} = filters
  [command,snap,U32.show(start),count,provider,repo,role,after]

def first_filters(items: List<&2,Item>) -> Query.Filters:
  match items:
    case []:
      empty_filters()
    case Item{snapshot,ordinal,title,provider,repo,gen,filters} <> rest:
      filters

def first_ordinal(items: List<&2,Item>) -> U32:
  match items:
    case []:
      0
    case Item{snapshot,ordinal,title,provider,repo,gen,filters} <> rest:
      ordinal

def file_kind(+kind: U32) -> Bool:
  U32.is_eq(kind,5) || U32.is_eq(kind,12) || U32.is_eq(kind,13)

def scope(+ui: UI.State) -> String:
  +value = UI.scope(ui)
  Bool.pick(String,String.eq(value,"all"),"",value)

def item_titles(items: List<&2,Item>) -> List<&2,String>:
  match items:
    case []:
      []
    case Item{snapshot,ordinal,title,provider,repo,gen,filters} <> rest:
      (provider ++ "  " ++ title) <> item_titles(rest)

def history_items(rows: List<&2,List<&2,Sql.Cell>>,+filters: Query.Filters) -> List<&2,Item>:
  match rows:
    case []:
      []
    case +r <> rest:
      Item{Store.field(r,3n),Store.number(Store.field(r,9n)),Store.field(r,7n),Store.field(r,1n),
        Store.field(r,8n),Store.field(r,4n),filters} <> history_items(rest,filters)

def search_items(rows: List<&2,List<&2,Sql.Cell>>,+filters: Query.Filters) -> List<&2,Item>:
  match rows:
    case []:
      []
    case +r <> rest:
      Item{Store.field(r,0n),Store.number(Store.field(r,1n)),Store.field(r,5n),
        Store.field(r,3n),Store.field(r,6n),Store.field(r,9n),filters} <> search_items(rest,filters)

def version_items(rows: List<&2,List<&2,Sql.Cell>>,+filters: Query.Filters) -> List<&2,Item>:
  match rows:
    case []:
      []
    case +row <> rest:
      Item{Store.field(row,0n),0,"Snap " ++ Store.field(row,0n) ++ " gen " ++ Store.field(row,1n) ++
        " | " ++ Store.field(row,3n) ++ " records | " ++ Store.field(row,2n) ++ "B" ++
        Bool.pick(String,String.eq(Store.field(row,4n),"1")," | latest",""),
        "capture","",Store.field(row,1n),filters} <> version_items(rest,filters)

def listing_items(kind: U32,rows: List<&2,List<&2,Sql.Cell>>,filters: Query.Filters) -> List<&2,Item>:
  match kind:
    case 1:
      history_items(rows,filters)
    case 17:
      version_items(rows,filters)
    case _:
      search_items(rows,filters)

def select_item(items: List<&2,Item>, +n: Nat) -> Maybe<&2,Item>:
  match items n:
    case [] _:
      None{}
    case h <> t 0n:
      Some{h}
    case h <> t 1n+p:
      select_item(t,p)

def maybe_snapshot(+snapshot: String) -> Maybe<&2,String>:
  match snapshot:
    case "":
      None{}
    case value:
      Some{value}

def first_snapshot(items: List<&2,Item>) -> String:
  match items:
    case []:
      ""
    case Item{snapshot,ordinal,title,provider,repo,gen,filters} <> rest:
      snapshot

def queue(+state: State, +request: Request) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  State{db,dir,program,UI.set_status(ui,"Loading captured evidence..."),selection,form,
    Jobs{U32.add(revision,1),Some{request},reader,writer,paused},refresh_at,serial}

def invalidate(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  State{db,dir,program,ui,selection,form,Jobs{U32.add(revision,1),None{},reader,writer,paused},refresh_at,serial}

def list_args(kind: U32,filters: Query.Filters,offset: U32) -> List<&2,String>:
  match kind:
    case 1:
      Query.Filters{query,provider,repo,role,after} = filters
      ["history",provider,repo,U32.show(offset)]
    case _:
      Query.Filters{query,provider,repo,role,after} = filters
      ["search",query,provider,repo,role,after,U32.show(offset)]

def anchored_list_args(+kind: U32,filters: Query.Filters,offset: U32,anchor: String) -> List<&2,String>:
  match kind:
    case 17:
      ["versions",anchor,U32.show(offset)]
    case _:
      list_args(kind,filters,offset)

def list_request_at(+state: State,+kind: U32,+filters: Query.Filters,+offset: U32,+anchor: String) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,reader_filters,old},form,jobs,refresh_at,serial} = state
  queue(State{db,dir,program,UI.set_results(UI.set_rows(ui,[]),UI.Results{offset,0,False{},False{}}),
    Selection{[],snap,start,displayed,args,reader_filters,Listing{kind,filters,offset,False{},False{},anchor}},
    form,jobs,refresh_at,serial},Request{kind,anchored_list_args(kind,filters,offset,anchor),anchor,offset,
      Bool.pick(String,U32.is_eq(kind,17),"Saved captures",Bool.pick(String,U32.is_eq(kind,1),"History","Search"))})

def list_request(state: State,kind: U32,filters: Query.Filters,offset: U32) -> State:
  list_request_at(state,kind,filters,offset,"")

def list_step(+state: State,+kind: U32,+filters: Query.Filters,+offset: U32,+anchor: String,+forward: Bool,available: Bool) -> State:
  match available:
    case True{}:
      list_request_at(state,kind,filters,Bool.pick(U32,forward,U32.add(offset,100),UI.minus(offset,100)),anchor)
    case False{}:
      status(state,Bool.pick(String,forward,"End of the current results. Refresh restarts the live listing.",
        "Already at the first result page."))

def list_page_ready(+state: State,+listing: Listing,+forward: Bool,+ready: Bool) -> State:
  Listing{kind,filters,+offset,more,loaded,+anchor} = listing
  match ready:
    case False{}:
      status(state,"Result navigation is available after the current listing loads.")
    case True{}:
      list_step(state,kind,filters,offset,anchor,forward,
        Bool.pick(Bool,forward,more && U32.is_le(offset,4294967095),U32.is_gt(offset,0)))

def listing_loaded(listing: Listing) -> Bool:
  Listing{kind,full,offset,more,loaded,+anchor} = listing
  loaded


def reload_args(+state: State, +query: String, +provider: String, +repo: String,
  +role: String, +after: String, +history: Bool) -> State:
  list_request(state,Bool.pick(U32,history,1,2),Query.Filters{query,provider,repo,role,after},0)

def reload_filters(+state: State, result: Result<&2,&2,String,Query.Filters>) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = state
  match result:
    case Fail{message}:
      status(invalidate(State{db,dir,program,ui,selection,form,jobs,refresh_at,serial}),message)
    case Done{Query.Filters{+query,+provider,+repo,+role,+after}}:
      chosen = Store.nonempty(provider,scope(ui))
      reload_args(State{db,dir,program,ui,selection,form,jobs,refresh_at,serial},
        query,chosen,repo,role,after,String.is_empty(query) && String.is_empty(role) && String.is_empty(after))

def clear_rows(+state: State) -> State:
  State{+db,+dir,+program,+ui,Selection{items,snap,start,displayed,blame,filters,+listing},+form,+jobs,+refresh_at,+serial} = state
  Listing{kind,full,offset,more,loaded,+anchor} = listing
  State{db,dir,program,UI.set_results(UI.set_rows(ui,[]),UI.Results{0,0,False{},False{}}),
    Selection{[],snap,start,displayed,blame,filters,Listing{kind,full,0,False{},False{},""}},form,jobs,refresh_at,serial}

def reload(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = state
  reload_filters(clear_rows(state),Query.parse_ui(UI.query(ui)))

def reload_listing_kind(state: State,listing: Listing) -> State:
  Listing{kind,filters,offset,more,loaded,anchor} = listing
  match kind:
    case 17:
      list_request_at(state,17,filters,0,anchor)
    case _:
      reload(state)

def reload_listing(+state: State) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  reload_listing_kind(state,listing)

# Files owns a separate pinned Git identity and never mutates Selection.
def files_model(state: State) -> Files.State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files},jobs,deadline,serial} = state
  files

def files_replace(state: State,files: Files.State) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,old},jobs,deadline,serial} = state
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files},jobs,deadline,serial}

def files_active(state: State) -> Bool:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files},jobs,deadline,serial} = state
  U32.is_eq(mode,3)

def files_saved_valid(+kind: U32) -> Bool:
  U32.is_eq(kind,3) || U32.is_eq(kind,4) || U32.is_eq(kind,14) || U32.is_eq(kind,24)

def files_saved_view(+ui: UI.State,valid: Bool) -> Files.Saved:
  match valid:
    case True{}:
      Files.Saved{UI.title(ui),UI.reader(ui),UI.scroll(ui)}
    case False{}:
      Files.Saved{"History","Choose a captured session to read its owned evidence.",0}

def files_saved_for(state: State) -> Files.Saved:
  State{db,dir,program,ui,Selection{items,snap,start,kind,args,filters,listing},form,jobs,deadline,serial} = state
  files_saved_view(ui,files_saved_valid(kind))

def files_return_missing(+state: State,+snap: String,+start: U32,+filters: Query.Filters,empty: Bool) -> State:
  match empty:
    case True{}:
      status(state,"History is empty. Choose or capture a session to read retained evidence.")
    case False{}:
      queue(state,Request{3,scoped_args("session-scope",snap,start,"40",filters),snap,start,
        "Transcript | pinned snapshot " ++ snap ++ " | record " ++ U32.show(start)})

def files_return_ready(+state: State,+snap: String,start: U32,filters: Query.Filters,ready: Bool) -> State:
  match ready:
    case True{}:
      status(state,"History restored. The captured reader keeps its exact snapshot and range.")
    case False{}:
      files_return_missing(state,snap,start,filters,String.is_empty(snap))

def files_leave(+state: State) -> State:
  State{db,dir,program,ui,Selection{+items,+snap,+start,+displayed,+args,+filters,Listing{+kind,+full,+offset,+more,+loaded,+anchor}},Form{mode,+search,source,blame,+files},jobs,deadline,serial} = state
  match mode:
    case 3:
      Files.State{input,identity,directory,file_source,saved} = files
      Files.Saved{title,text,scroll} = saved
      restored = UI.set_position(UI.set_reader(UI.set_query(UI.set_files(ui,False{}),search),title,text),0,scroll)
      rows = UI.set_results(UI.set_rows(restored,item_titles(items)),UI.Results{offset,U32.from_nat(List.length(&2,Item,items)),more,loaded})
      files_return_ready(invalidate(State{db,dir,program,rows,Selection{items,snap,start,Bool.pick(U32,files_saved_valid(displayed),displayed,0),args,filters,Listing{kind,full,offset,more,loaded,anchor}},Form{0,search,source,blame,files},jobs,deadline,serial}),
        snap,start,filters,files_saved_valid(displayed))
    case _:
      state

def files_enter(+state: State) -> State:
  State{db,dir,program,+ui,selection,Form{mode,search,source,blame,+files},jobs,deadline,serial} = state
  +next = Files.begin(files,files_saved_for(state))
  view = UI.set_reader(UI.set_results(UI.set_rows(UI.set_query(UI.set_files(ui,True{}),Files.input(next)),[]),UI.Results{0,0,False{},False{}}),
    "Files | explicit local repository", "Paste a local checkout path above.\nClick Open repo or press Return to pin HEAD.\n\nDirectory rows open committed folders/files.\nUp folder returns to the parent directory.\nPrev/Next list page directory entries.\nPrev/Next text page committed source lines.\nBlame and Why use the displayed source range.\n\nThe full pinned commit is shown in each result.\nWorking-tree edits are excluded. Symlinks and submodules are listed but never followed.\n\nCopy and Export use exactly displayed text.\nClick History at left to restore the prior captured transcript.\nNo home-folder scan or logged command is run.")
  status(invalidate(State{db,dir,program,view,selection,Form{3,search,source,blame,next},jobs,0n,serial}),
    "Enter an explicit checkout path, then Open repo. History selection is retained.")

def files_toggle(+state: State,active: Bool) -> State:
  match active:
    case True{}:
      files_leave(state)
    case False{}:
      files_enter(state)

def files_request(+state: State,kind: U32,args: List<&2,String>,start: U32) -> State:
  status(queue(state,Request{kind,args,"",start,"Pinned repository"}),
    "Loading requested repository view; the currently displayed revision stays pinned.")

def files_open_valid(+state: State,+path: String,valid: Bool) -> State:
  match valid:
    case True{}:
      files_request(state,20,["repo-open",path],0)
    case False{}:
      status(invalidate(state),"Files needs an explicit absolute checkout path; no folder is scanned automatically.")

def files_open_repo(+state: State) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  +path = UI.query(ui)
  files_open_valid(files_replace(state,Files.edit(files_model(state),path)),path,String.starts_with(path,"/"))

def files_tree(+state: State,path: String,+offset: U32) -> State:
  files_request(state,20,Files.tree_args(Files.identity(files_model(state)),path,offset),offset)

def files_parent_value(+state: State,value: Files.Directory) -> State:
  Files.Directory{+path,offset,total,next,nodes} = value
  files_tree(state,Files.parent(path),0)

def files_parent(+state: State) -> State:
  files_parent_value(state,Files.directory(files_model(state)))

def files_reload_value(+state: State,value: Files.Directory) -> State:
  Files.Directory{path,offset,total,next,nodes} = value
  files_tree(state,path,offset)

def files_reload(+state: State) -> State:
  files_reload_value(state,Files.directory(files_model(state)))

def files_tree_guard(+state: State,parent: Bool,valid: Bool) -> State:
  match valid:
    case False{}:
      status(state,"Open an explicit repository first.")
    case True{}:
      Bool.pick(State,parent,files_parent(state),files_reload(state))

def files_page_ready(+state: State,+path: String,+offset: U32,+next: U32,+forward: Bool,valid: Bool) -> State:
  match valid:
    case True{}:
      files_tree(state,path,Bool.pick(U32,forward,next,UI.minus(offset,100)))
    case False{}:
      status(state,"No further directory page. The displayed commit is unchanged.")

def files_list_page_value(+state: State,+forward: Bool,value: Files.Directory) -> State:
  Files.Directory{path,+offset,total,+next,nodes} = value
  files_page_ready(state,path,offset,next,forward,Files.pinned(Files.identity(files_model(state))) &&
    Bool.pick(Bool,forward,U32.is_gt(next,0),U32.is_gt(offset,0)))

def files_list_page(+state: State,+forward: Bool) -> State:
  files_list_page_value(state,forward,Files.directory(files_model(state)))

def files_source(+state: State,path: String,+first: U32) -> State:
  files_request(state,21,Files.source_args("repo-source",Files.identity(files_model(state)),path,first,40),first)

def files_node(+state: State,node: Maybe<&2,Files.Node>) -> State:
  match node:
    case Some{Files.Node{path,"directory"}}:
      files_tree(state,path,0)
    case Some{Files.Node{path,"file"}}:
      files_source(state,path,1)
    case Some{Files.Node{path,kind}}:
      status(invalidate(state),"Unsupported " ++ kind ++ " entry; it is not followed: " ++ path)
    case None{}:
      status(state,"Choose a listed committed file or directory.")

def files_select_value(+state: State,index: U32,value: Files.Directory) -> State:
  Files.Directory{path,offset,total,next,nodes} = value
  files_node(state,Files.node_at(nodes,index))

def files_select(+state: State,index: U32) -> State:
  files_select_value(state,index,Files.directory(files_model(state)))

def files_source_step(+state: State,+path: String,+first: U32,+next: U32,+forward: Bool,valid: Bool) -> State:
  match valid:
    case True{}:
      files_source(state,path,Bool.pick(U32,forward,next,U32.max(1,UI.minus(first,40))))
    case False{}:
      status(state,"No further source page. Choose a regular file to read committed lines.")

def files_page_value(+state: State,+forward: Bool,value: Files.Source) -> State:
  Files.Source{path,+first,count,+next,+kind} = value
  files_source_step(state,path,first,next,forward,(kind >= 21 && kind <= 23 : U32) &&
    Bool.pick(Bool,forward,U32.is_gt(next,0),U32.is_gt(first,1)))

def files_page(+state: State,+forward: Bool) -> State:
  files_page_value(state,forward,Files.source(files_model(state)))

def files_evidence_ready(+state: State,+why: Bool,+path: String,+first: U32,+count: U32,valid: Bool) -> State:
  match valid:
    case True{}:
      files_request(state,Bool.pick(U32,why,23,22),Files.source_args(Bool.pick(String,why,"repo-why","repo-blame"),
        Files.identity(files_model(state)),path,first,count),first)
    case False{}:
      status(state,"Choose a nonempty committed source range before Blame or Why.")

def files_evidence_value(+state: State,why: Bool,value: Files.Source) -> State:
  Files.Source{path,first,+count,next,+kind} = value
  files_evidence_ready(state,why,path,first,count,(kind >= 21 && kind <= 23 && count > 0 : U32))

def files_evidence(+state: State,why: Bool) -> State:
  files_evidence_value(state,why,Files.source(files_model(state)))

def files_rows(kind: U32,+ui: UI.State,+files: Files.State) -> UI.State:
  match kind:
    case 20:
      Files.State{input,identity,directory,source,saved} = files
      Files.Directory{path,offset,total,+next,+nodes} = directory
      UI.set_results(UI.set_rows(ui,Files.node_titles(nodes)),UI.Results{offset,U32.from_nat(List.length(&2,Files.Node,nodes)),U32.is_gt(next,0),True{}})
    case _:
      ui

def files_apply(+state: State,+request: Request,+value: Json.Json,valid: Bool) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files},jobs,deadline,serial} = state
  Request{+kind,args,snap,start,title} = request
  match valid:
    case False{}:
      status(state,"Repository reply identity or page metadata did not match the request; current view retained.")
    case True{}:
      +next = Files.apply(kind,files,value)
      view = UI.set_reader(files_rows(kind,ui,next),Files.title(next),Json.get(value,"text"))
      State{db,dir,program,UI.set_status(view,"Committed view loaded. Copy/export preserve this exact displayed text; History restores the captured reader."),
        selection,Form{mode,search,source,blame,next},jobs,deadline,serial}

def files_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{kind,args,snapshot,start,title} = request
  match result:
    case Fail{message}:
      status(state,"Repository read failed; current view retained: " ++ message)
    case Done{+value}:
      files_apply(state,request,value,files_active(state) && Files.valid(kind,files_model(state),args,value))

def list_paging_capture(+state: State,forward: Bool) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,filters,+listing},
    Form{mode,search,source,blame,+files},jobs,refresh_at,serial} = state
  list_page_ready(state,listing,forward,U32.is_eq(mode,0) && listing_loaded(listing))

def list_paging_mode(+state: State,forward: Bool,active: Bool) -> State:
  match active:
    case True{}:
      files_list_page(state,forward)
    case False{}:
      list_paging_capture(state,forward)

def list_paging(+state: State,forward: Bool) -> State:
  list_paging_mode(state,forward,files_active(state))


def form_text(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      State{db,dir,program,ui,selection,Form{1,search,UI.query(ui),blame,files},jobs,refresh_at,serial}
    case 2:
      invalidate(State{db,dir,program,ui,selection,Form{2,search,source,UI.query(ui),files},jobs,refresh_at,serial})
    case 3:
      invalidate(State{db,dir,program,ui,selection,Form{3,search,source,blame,Files.edit(files,UI.query(ui))},jobs,refresh_at,serial})
    case _:
      reload(State{db,dir,program,ui,selection,Form{0,UI.query(ui),source,blame,files},jobs,refresh_at,serial})

def open_item(+state: State,item: Maybe<&2,Item>) -> State:
  match item:
    case None{}:
      status(state,"No captured result selected.")
    case Some{Item{+snap,+ordinal,title,provider,repo,gen,filters}}:
      queue(state,Request{3,scoped_args("session-scope",snap,ordinal,"40",filters),snap,ordinal,
        provider ++ " | snapshot " ++ snap ++ " | gen " ++ gen ++ " | " ++ repo})

def page_nonempty(+state: State,+snap: String,+start: U32,+filters: Query.Filters,+empty: Bool) -> State:
  match empty:
    case True{}:
      status(state,"Choose a captured session first.")
    case False{}:
      queue(state,Request{3,scoped_args("session-scope",snap,start,"40",filters),snap,start,
        "Transcript | pinned snapshot " ++ snap ++ " | record " ++ U32.show(start)})

def page_at(+state: State, +start: U32) -> State:
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+old,+displayed,+blame,+filters,+listing},+form,+jobs,+refresh_at,+serial} = state
  page_nonempty(state,snap,start,filters,String.is_empty(snap))

def why_nonempty(+state: State,+snap: String,+start: U32,+filters: Query.Filters,+empty: Bool) -> State:
  match empty:
    case True{}:
      status(state,"Choose a captured session before opening Why.")
    case False{}:
      queue(state,Request{4,scoped_args("why-scope",snap,start,"20",filters),snap,start,
        "Why | pinned snapshot " ++ snap})

def selected_file_form(+state: State,+text: String) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,old,+files},jobs,refresh_at,serial} = state
  State{db,dir,program,UI.set_query(ui,text),selection,Form{2,search,source,text,files},jobs,refresh_at,serial}

def why_file(+state: State,args: List<&2,String>) -> State:
  match args:
    case cmd <> +repo <> +path <> +first <> +last <> []:
      queue(selected_file_form(state,repo ++ "|" ++ path ++ "|" ++ first ++ "|" ++
        U32.show(U32.add(U32.sub(Store.number(last),Store.number(first)),1))),
        Request{12,["why-file",repo,path,first,last],"",0,"Why | file/range captured evidence"})
    case _:
      status(state,"Open file/range Blame before file Why.")

def why_commit(+state: State,args: List<&2,String>) -> State:
  match args:
    case cmd <> +repo <> +sha <> []:
      queue(selected_file_form(state,repo ++ "|commit:" ++ sha),
        Request{13,["why-commit",repo,sha],"",0,"Why | exact commit captured evidence"})
    case _:
      status(state,"Use /absolute/repository|commit:full40hex in the Blame form.")

def why_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+blame,+filters,+listing},+form,+jobs,+refresh_at,+serial} = state
  match displayed:
    case 3:
      why_nonempty(state,snap,start,filters,String.is_empty(snap))
    case 4:
      why_nonempty(state,snap,start,filters,String.is_empty(snap))
    case 14:
      why_nonempty(state,snap,start,filters,String.is_empty(snap))
    case 24:
      why_nonempty(state,snap,start,filters,String.is_empty(snap))
    case 5:
      why_file(state,blame)
    case 12:
      why_file(state,blame)
    case 13:
      why_commit(state,blame)
    case _:
      status(state,"Choose a captured transcript or file/range Blame before Why.")

def why_mode(+state: State,active: Bool) -> State:
  match active:
    case True{}:
      files_evidence(state,True{})
    case False{}:
      why_capture(state)

def why(+state: State) -> State:
  why_mode(state,files_active(state))


def usage_scope(filters: Query.Filters) -> Bool:
  Query.Filters{query,provider,repo,role,after} = filters
  String.is_empty(repo) && String.is_empty(role) && String.is_empty(after)

def usage_nonempty(+state: State,+snap: String,+start: U32,+filters: Query.Filters,valid: Bool) -> State:
  match valid:
    case True{}:
      queue(state,Request{14,["usage",snap,U32.show(start),"40"],snap,start,"Usage | recorded facts in captured range"})
    case False{}:
      status(state,"Usage needs an unfiltered transcript range. Clear repository, role and date filters, then reopen a result.")

def usage_capture(+state: State) -> State:
  State{db,dir,program,ui,Selection{items,+snap,+start,displayed,args,+filters,+listing},form,jobs,refresh_at,serial} = state
  match displayed:
    case 3:
      usage_nonempty(state,snap,start,filters,usage_scope(filters) && Bool.not(String.is_empty(snap)))
    case 4:
      usage_nonempty(state,snap,start,filters,usage_scope(filters) && Bool.not(String.is_empty(snap)))
    case 14:
      usage_nonempty(state,snap,start,filters,usage_scope(filters) && Bool.not(String.is_empty(snap)))
    case 24:
      usage_nonempty(state,snap,start,filters,usage_scope(filters) && Bool.not(String.is_empty(snap)))
    case _:
      status(state,"Choose a captured transcript to inspect recorded usage.")

def usage_mode(+state: State,active: Bool) -> State:
  match active:
    case True{}:
      status(state,"Return to History before inspecting captured usage.")
    case False{}:
      usage_capture(state)

def usage(+state: State) -> State:
  usage_mode(state,files_active(state))

# Tools uses the same immutable raw-record range as the captured reader. Its
# response carries separate EOF metadata; visible tool count is not a cursor.
def tools_request(+state: State,+snap: String,+start: U32,filters: Query.Filters) -> State:
  queue(state,Request{24,scoped_args("activity-scope",snap,start,"40",filters),snap,start,
    "Tools | snapshot " ++ snap ++ " | record " ++ U32.show(start)})

def tools_ready(state: State,snap: String,start: U32,filters: Query.Filters,valid: Bool) -> State:
  match valid:
    case True{}:
      tools_request(state,snap,start,filters)
    case False{}:
      status(state,"Tools needs a captured History reader. Return to History and choose a transcript first.")

def tools(+state: State) -> State:
  State{db,dir,program,ui,Selection{items,+snap,start,displayed,args,filters,listing},Form{mode,search,source,blame,files},jobs,deadline,serial} = state
  tools_ready(state,snap,start,filters,U32.is_eq(mode,0) && files_saved_valid(displayed) && Bool.not(String.is_empty(snap)))

def tools_page_ready(state: State,snap: String,start: U32,filters: Query.Filters,valid: Bool) -> State:
  match valid:
    case True{}:
      tools_request(state,snap,start,filters)
    case False{}:
      status(state,"No further Tools page. The displayed captured range is unchanged.")

def tools_paging(state: State,+snap: String,+start: U32,filters: Query.Filters,+forward: Bool,args: List<&2,String>) -> State:
  match args:
    case "activity" <> pinned <> source <> generation <> extent <> provider <> total <> +next <> selected <> []:
      tools_page_ready(state,snap,Bool.pick(U32,forward,Files.number(next),UI.minus(start,40)),filters,
        String.eq(snap,pinned) && Bool.pick(Bool,forward,U32.is_gt(Files.number(next),0),U32.is_gt(start,0)))
    case _:
      status(state,"Reload Tools to obtain its captured range metadata before paging.")


def paging_next(+state: State,kind: U32,+snap: String,+next: U32,+filters: Query.Filters) -> State:
  match kind:
    case 3:
      page_nonempty(state,snap,next,filters,String.is_empty(snap))
    case 4:
      why_nonempty(state,snap,next,filters,String.is_empty(snap))
    case 14:
      usage_nonempty(state,snap,next,filters,usage_scope(filters) && Bool.not(String.is_empty(snap)))
    case _:
      status(state,"Open a transcript to page. Adjust the Blame form for another file range.")

def paging_kind(+state: State,+kind: U32,+snap: String,+start: U32,+filters: Query.Filters,+forward: Bool) -> State:
  +step = Bool.pick(U32,U32.is_eq(kind,4),20,40)
  +next = Bool.pick(U32,forward,U32.add(U32.min(start,U32.sub(4294967295,step)),step),UI.minus(start,step))
  paging_next(state,kind,snap,next,filters)

def paging_capture(+state: State,+forward: Bool) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,filters,+listing},form,jobs,refresh_at,serial} = state
  match displayed:
    case 24:
      tools_paging(state,snap,start,filters,forward,args)
    case _:
      paging_kind(state,displayed,snap,start,filters,forward)

def paging_mode(+state: State,forward: Bool,active: Bool) -> State:
  match active:
    case True{}:
      files_page(state,forward)
    case False{}:
      paging_capture(state,forward)

def paging(+state: State,forward: Bool) -> State:
  paging_mode(state,forward,files_active(state))


def browse_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  reload(State{db,dir,program,UI.set_query(ui,search),selection,Form{0,search,source,blame,files},jobs,refresh_at,serial})

def browse(state: State) -> State:
  browse_capture(files_leave(state))


def capture_browse_capture(+state: State) -> State:
  State{db,dir,program,ui,selection,Form{mode,+search,source,blame,+files},jobs,refresh_at,serial} = state
  State{db,dir,program,UI.set_query(ui,search),selection,Form{0,search,source,blame,files},jobs,refresh_at,serial}

def capture_browse(state: State) -> State:
  capture_browse_capture(files_leave(state))


def versions_ready(state: State,snapshot: String,filters: Query.Filters,valid: Bool) -> State:
  match valid:
    case True{}:
      list_request_at(capture_browse(state),17,filters,0,snapshot)
    case False{}:
      status(state,"Choose a captured transcript before browsing saved versions.")

def versions(+state: State) -> State:
  State{db,dir,program,ui,Selection{items,+snap,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  versions_ready(state,snap,filters,Bool.not(String.is_empty(snap)))

def latest_args(snapshot: String,filters: Query.Filters) -> List<&2,String>:
  Query.Filters{query,provider,repo,role,after} = filters
  ["latest-view",snapshot,provider,repo,role,after]

def latest_ready(state: State,+snapshot: String,filters: Query.Filters,valid: Bool) -> State:
  match valid:
    case True{}:
      queue(capture_browse(state),Request{18,latest_args(snapshot,filters),snapshot,0,"Open latest capture"})
    case False{}:
      status(state,"Choose a captured transcript before opening its latest capture.")

def open_latest(+state: State) -> State:
  State{db,dir,program,ui,Selection{items,+snap,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  latest_ready(state,snap,filters,Bool.not(String.is_empty(snap)))

def no_display(+selection: Selection) -> Selection:
  Selection{items,snap,start,displayed,blame,filters,+listing} = selection
  Selection{items,snap,start,0,blame,filters,listing}

def selection_snapshot(selection: Selection) -> String:
  Selection{items,snap,start,displayed,args,filters,+listing} = selection
  snap

def settings_text(dir: String,snapshot: String) -> String:
  "Data directory:\n" ++ dir ++ "\nSelected snapshot: " ++ Store.nonempty(snapshot,"none") ++
  "\nRebuild restores this snapshot's derived search rows from verified raw bytes. Use Rebuild at left. Captured evidence is retained." ++
  "\n\nEnable a history folder:\n1. Choose Claude or Codex at left.\n2. Paste its full local folder path above.\n3. Click Refresh or press Return.\n\nFor one JSONL file, use file:/absolute/log.jsonl.\nDisable a folder with disable:/canonical/root.\nUse the exact registered path listed below.\nRetained evidence is never deleted by disabling.\n\nThe input is a literal path, never a command.\nNo private home history is scanned by default.\n\nClick Settings again to return to search.\nRefresh rechecks registered folders and explicit files.\nPause stops automatic refresh; in-flight captures finish safely.\n\nReader: fixed 16px font. Unsupported glyphs are boxes; copy/export retain Unicode.\nUsage stays recorded facts, never billed spend.\n\nRegistered source folders:\n"

def source_lines(rows: List<&2,List<&2,Sql.Cell>>) -> String:
  match rows:
    case []:
      ""
    case +row <> rest:
      Store.field(row,0n) ++ " | " ++ Bool.pick(String,String.eq(Store.field(row,2n),"1"),"enabled","disabled") ++
      "\n" ++ Store.field(row,1n) ++ "\n\n" ++ source_lines(rest)

def source_rows(+state: State,result: Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = state
  match result:
    case Fail{message}:
      status(state,message)
    case Done{rows}:
      State{db,dir,program,UI.set_status(UI.set_reader(ui,"Settings | explicit sources",settings_text(dir,selection_snapshot(selection)) ++ source_lines(rows)),
        "Explicit source configuration loaded. Disabled roots keep captured evidence."),selection,form,jobs,refresh_at,serial}

def settings_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      browse(State{db,dir,program,ui,selection,Form{mode,search,source,blame,files},jobs,refresh_at,serial})
    case _:
      queue(clear_rows(State{db,dir,program,UI.set_reader(UI.set_query(ui,source),"Settings | explicit sources",settings_text(dir,selection_snapshot(selection))),
        no_display(selection),Form{1,search,source,blame,files},jobs,refresh_at,serial}),Request{6,["sources"],"",0,"Registered sources"})

def settings(state: State) -> State:
  settings_capture(files_leave(state))


def storage_capture(+state: State) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,+source,blame,+files},jobs,deadline,serial} = state
  queue(clear_rows(State{db,dir,program,UI.set_query(ui,source),no_display(selection),
    Form{1,search,source,blame,files},jobs,deadline,serial}),Request{19,["storage"],"",0,"Storage inventory"})

def storage(state: State) -> State:
  storage_capture(files_leave(state))


def storage_done(+state: State,result: Result<&2,&2,String,String>) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  match result:
    case Fail{message}:
      status(state,message)
    case Done{text}:
      State{db,dir,program,UI.set_status(UI.set_reader(ui,"Settings | storage inventory",text),
        "Read-only storage inventory. Click Settings to return to search."),
        no_display(selection),form,jobs,deadline,serial}

def filter_help_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  invalidate(State{db,dir,program,UI.set_reader(UI.set_query(ui,search),"Search filters | literal terms",
    "Type words or a quoted phrase above.\n\nOptional filters:\nprovider:claude\nprovider:codex\nrepo:\"/absolute/path with spaces\"\nrole:user\nrole:assistant\nrole:tool\nafter:2026-10-01\n\nExample:\ncache role:assistant after:2026-10-01\n\nProvider tokens override the sidebar scope.\nDates are inclusive calendar dates.\nEmpty words with filters browse matching records.\nPunctuation is literal; FTS syntax is not executed.\n\nTyping applies filters. Click a result to read its exact accepted snapshot."),
    no_display(selection),Form{0,search,source,blame,files},jobs,refresh_at,serial})

def filter_help(state: State) -> State:
  filter_help_capture(files_leave(state))


def blame_help_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  invalidate(State{db,dir,program,UI.set_reader(UI.set_query(ui,blame),"Blame | local repository evidence",
    "Enter literal fields separated by |:\n\n/absolute/repository|relative/file|first|count\n\nOr exact commit Why:\n/absolute/repository|commit:full40hex\n\nExample:\n/tmp/demo-repo|src/cache.txt|1|20\n\nClick Blame again or press Return to run.\nThe final field is a count, from 1 to 100.\nSpaces are allowed in paths. | is reserved.\n\nGit is read-only. No logged command is run.\nMissing or ambiguous evidence remains explicit.\nContent overlap does not prove authorship.\nFile evidence searches captured sources for this repository independently of transcript filters.\n\nClick Filter to return to search."),
    no_display(selection),Form{2,search,source,blame,files},jobs,refresh_at,serial})

def blame_help(state: State) -> State:
  blame_help_capture(files_leave(state))


def blame_valid(+repo: String,+path: String,+first: U32,+count: U32,+valid: Bool) -> Result<&2,&2,String,List<&2,String>>:
  match valid:
    case True{}:
      Done{["blame",repo,path,U32.show(first),U32.show(U32.sub(U32.add(first,count),1))]}
    case False{}:
      Fail{"Blame needs first >= 1 and count 1 through 100 without overflow."}

def blame_numbers(+repo: String,+path: String,first: Maybe<&2,U32>,count: Maybe<&2,U32>) -> Result<&2,&2,String,List<&2,String>>:
  match first count:
    case Some{+a} Some{+n}:
      blame_valid(repo,path,a,n,(a > 0 && n > 0 && n <= 100 && a <= 4294967295 - n : U32))
    case _ _:
      Fail{"Blame first/count must be unsigned decimal integers."}

def commit_form(repo: String,+text: String,valid: Bool) -> Result<&2,&2,String,List<&2,String>>:
  match valid:
    case True{}:
      Done{["why-commit",repo,String.drop(text,7n)]}
    case False{}:
      Fail{"Use /absolute/repository|commit:full40hex for commit Why."}

def blame_fields(fields: List<&2,String>) -> Result<&2,&2,String,List<&2,String>>:
  match fields:
    case repo <> path <> first <> count <> []:
      blame_numbers(String.trim(repo),String.trim(path),P.parse_u32(String.trim(first)),P.parse_u32(String.trim(count)))
    case repo <> +commit <> []:
      commit_form(String.trim(repo),String.trim(commit),String.starts_with(String.trim(commit),"commit:"))
    case _:
      Fail{"Use /absolute/repository|relative/file|first|count, then click Blame."}

def blame_request(+state: State,args: List<&2,String>) -> State:
  match args:
    case "why-commit" <> repo <> sha <> []:
      why_commit(state,["why-commit",repo,sha])
    case other:
      queue(state,Request{5,other,"",0,"Blame | captured provenance"})

def blame_result(+state: State,result: Result<&2,&2,String,List<&2,String>>) -> State:
  match result:
    case Fail{message}:
      status(invalidate(state),message)
    case Done{args}:
      blame_request(state,args)

def blame_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+form,+files},+jobs,+refresh_at,+serial} = state
  match mode:
    case 2:
      blame_result(state,blame_fields(String.split(UI.query(ui),'|')))
    case _:
      blame_help(state)

def blame_mode(+state: State,active: Bool) -> State:
  match active:
    case True{}:
      files_evidence(state,False{})
    case False{}:
      blame_capture(state)

def blame(+state: State) -> State:
  blame_mode(state,files_active(state))


def scope_changed(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  match mode:
    case 0:
      reload(state)
    case 3:
      browse(state)
    case _:
      status(state,"Provider scope selected. The current input form is unchanged.")

def read_scoped(program: String,dir: String,args: List<&2,String>) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,"--data-dir" <> dir <> linear_args(args),"",1048576,60000)
    return Reply{Client.completed(result)}

def read_job(+program: String,+dir: String,args: List<&2,String>) -> IO(Reply):
  match args:
    case "latest-view" <> snapshot <> provider <> repo <> role <> after <> []:
      do IO<Reply>:
        result : Result<&2,&2,String,Json.Json> <- Client.call(program,dir,["latest",snapshot])
        return Reply{result}
    case "session-scope" <> rest:
      read_scoped(program,dir,"session-scope" <> rest)
    case "why-scope" <> rest:
      read_scoped(program,dir,"why-scope" <> rest)
    case "activity-scope" <> rest:
      read_scoped(program,dir,"activity-scope" <> rest)
    case other:
      do IO<Reply>:
        result : Result<&2,&2,String,Json.Json> <- Client.call(program,dir,linear_args(other))
        return Reply{result}

def run_write(+program: String,+dir: String,args: List<&2,String>) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,"--data-dir" <> dir <> linear_args(args),"",1048576,600000)
    return Reply{Client.completed(result)}

def registered_result(program: String,dir: String,result: Result<&2,&2,String,Json.Json>) -> IO(Reply):
  match result:
    case Fail{message}:
      IO.pure(Reply,Reply{Fail{message}})
    case Done{value}:
      run_write(program,dir,["refresh-all"])

def registered(+program: String,+dir: String,reply: Reply) -> IO(Reply):
  Reply{value} = reply
  registered_result(program,dir,value)

def run_write_text(+program: String,+dir: String,+path: String,text: String) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,["--data-dir",dir,"export-displayed",path],text,1048576,10000)
    return Reply{Client.completed(result)}

def write_job(+program: String,+dir: String,args: List<&2,String>) -> IO(Reply):
  match args:
    case "export-displayed" <> path <> text <> []:
      run_write_text(program,dir,path,text)
    case "source-add" <> provider <> path <> []:
      do IO<Reply>:
        reply : Reply <- run_write(program,dir,["source-add",provider,path])
        registered(program,dir,reply)
    case other:
      run_write(program,dir,other)

def start_write(+state: State,+request: Request,busy: Maybe<&2,Pending>) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  Request{+kind,+args,+snap,+start,+title} = request
  match busy:
    case Some{pending}:
      IO.pure(State,status(State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,writer,paused},refresh_at,serial},
        "A capture or export is already running. Browsing stays available."))
    case None{}:
      do IO<State>:
        channel : Chan(Reply) <- IO.fork(Reply,write_job(program,dir,args))
        return State{db,dir,program,UI.set_status(ui,"Updating captures or exporting evidence. Browsing stays available."),selection,form,
          Jobs{revision,wanted,reader,Some{Pending{revision,Request{kind,args,snap,start,title},channel}},paused},0n,serial}

def import_path(state: State,provider: String,path: String,writer: Maybe<&2,Pending>,file: Bool) -> IO(State):
  match file:
    case True{}:
      start_write(state,Request{7,["import",provider,String.drop(path,5n)],"",0,"Capture explicit file"},writer)
    case False{}:
      start_write(state,Request{7,["source-add",provider,path],"",0,"Enable and capture explicit folder"},writer)

def import_operation(+state: State,+provider: String,+path: String,writer: Maybe<&2,Pending>,disable: Bool) -> IO(State):
  match disable:
    case True{}:
      start_write(state,Request{10,["source-disable",provider,String.drop(path,8n)],"",0,"Disable explicit folder"},writer)
    case False{}:
      import_path(state,provider,path,writer,String.starts_with(path,"file:"))

def import_valid(+state: State,+provider: String,+path: String,writer: Maybe<&2,Pending>,+valid: Bool) -> IO(State):
  match valid:
    case False{}:
      IO.pure(State,status(state,"Choose Claude or Codex and enter an explicit local source path."))
    case True{}:
      import_operation(state,provider,path,writer,String.starts_with(path,"disable:"))

def import_checked(+state: State,+provider: String,+path: String,writer: Maybe<&2,Pending>) -> IO(State):
  import_valid(state,provider,path,writer,
    Query.provider_valid(provider) && Bool.not(String.is_empty(path)))

def writer_of(+state: State) -> Maybe<&2,Pending>:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  writer

def refresh_listing(state: State,mode: U32) -> State:
  match mode:
    case 0:
      reload_listing(state)
    case _:
      state

def refresh(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      import_checked(state,scope(ui),String.trim(UI.query(ui)),writer_of(state))
    case 3:
      IO.pure(State,files_tree_guard(state,False{},Files.pinned(Files.identity(files))))
    case _:
      start_write(refresh_listing(state,mode),Request{8,["refresh-all"],"",0,"Refresh registered sources"},writer_of(state))

def rebuild_allowed(+state: State,+snap: String,allowed: Bool) -> IO(State):
  match allowed:
    case True{}:
      start_write(state,Request{16,["rebuild",snap],snap,0,"Snapshot " ++ snap},writer_of(state))
    case False{}:
      IO.pure(State,status(state,"Select a captured transcript, then open Settings to rebuild that snapshot's derived search rows."))

def rebuild(+state: State) -> IO(State):
  State{db,dir,program,ui,Selection{items,+snap,start,displayed,args,filters,+listing},Form{mode,search,source,blame,+files},jobs,refresh_at,serial} = state
  rebuild_allowed(state,snap,U32.is_eq(mode,1) && Bool.not(String.is_empty(snap)))

def copy_done(+state: State,result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> State:
  match result:
    case Done{(0,output)}:
      status(state,"Selected Unicode copied to clipboard.")
    case Done{(code,output)}:
      status(state,"Clipboard command returned an error; text was not confirmed copied.")
    case Fail{error}:
      status(state,"Clipboard unavailable or timed out; copy was not confirmed.")

def paste_done(+state: State,result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = state
  match result:
    case Done{(0,(text,error))}:
      form_text(State{db,dir,program,UI.insert(ui,text),selection,form,jobs,refresh_at,serial})
    case _:
      status(State{db,dir,program,ui,selection,form,jobs,refresh_at,serial},"Clipboard unavailable or paste failed.")

# Blame depends on the inspected Git state and candidate set. Export the exact
# already-rendered immutable evidence through stdin, never re-run attribution.

def export_args(+kind: U32,+snap: String,+start: U32,+filters: Query.Filters,+text: String,+path: String) -> List<&2,String>:
  match kind:
    case 5:
      ["export-displayed",path,text]
    case 12:
      ["export-displayed",path,text]
    case 13:
      ["export-displayed",path,text]
    case 14:
      ["export-displayed",path,text]
    case 24:
      ["export-displayed",path,text]
    case 4:
      List.append(&2,String,scoped_args("export-why-scope",snap,start,"20",filters),[path])
    case _:
      List.append(&2,String,scoped_args("export-range-scope",snap,start,"40",filters),[path])

def export_at(+state: State,+now: Nat) -> IO(State):
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+blame,+filters,listing},+form,
    Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  +path = dir ++ "/evidence-" ++ Store.nonempty(Bool.pick(String,file_kind(displayed),"file",snap),"selection") ++ "-" ++ Nat.show(now) ++ "-" ++ U32.show(serial) ++ ".md"
  start_write(State{db,dir,program,ui,Selection{items,snap,start,displayed,blame,filters,listing},form,
    Jobs{revision,wanted,reader,writer,paused},refresh_at,U32.add(serial,1)},
    Request{9,export_args(displayed,snap,start,filters,UI.reader(ui),path),snap,start,path},writer)

def export_begin(+state: State,+valid: Bool) -> IO(State):
  match valid:
    case False{}:
      IO.pure(State,status(state,"Open captured transcript or provenance evidence before exporting."))
    case True{}:
      do IO<State>:
        now : Nat <- IO.now()
        export_at(state,now)

def export_capture(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+blame,+filters,+listing},Form{+mode,+search,+source,+form,+files},+jobs,+refresh_at,+serial} = state
  export_begin(state,Bool.not(U32.is_eq(mode,1)) && ((displayed >= 3 && displayed <= 4 : U32) || file_kind(displayed) || U32.is_eq(displayed,14) || U32.is_eq(displayed,24)))

def files_export_args(ui: UI.State,path: String) -> List<&2,String>:
  ["export-displayed",path,UI.reader(ui)]

def files_export_at(+state: State,now: Nat) -> IO(State):
  State{db,+dir,program,+ui,selection,form,jobs,deadline,+serial} = state
  +path = dir ++ "/evidence-repository-" ++ Nat.show(now) ++ "-" ++ U32.show(serial) ++ ".md"
  start_write(State{db,dir,program,ui,selection,form,jobs,deadline,U32.add(serial,1)},
    Request{9,files_export_args(ui,path),"",0,path},writer_of(state))

def files_export_ready(+state: State,ready: Bool) -> IO(State):
  match ready:
    case False{}:
      IO.pure(State,status(state,"Open a committed repository view before exporting."))
    case True{}:
      do IO<State>:
        now : Nat <- IO.now()
        files_export_at(state,now)

def files_export_model(state: State,source: Files.Source) -> IO(State):
  Files.Source{path,first,count,next,+kind} = source
  files_export_ready(state,(kind >= 20 && kind <= 23 : U32))

def export_mode(+state: State,active: Bool) -> IO(State):
  match active:
    case True{}:
      files_export_model(state,Files.source(files_model(state)))
    case False{}:
      export_capture(state)

def export(+state: State) -> IO(State):
  export_mode(state,files_active(state))


def clear_reader(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  State{db,dir,program,ui,selection,form,Jobs{revision,wanted,None{},writer,paused},refresh_at,serial}

def clear_writer(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,None{},paused},refresh_at,serial}

def initial_page(+state: State,+snap: String,+start: U32,+filters: Query.Filters,+initial: Bool) -> State:
  match initial:
    case True{}:
      page_nonempty(state,snap,start,filters,False{})
    case False{}:
      state

def with_rows(+state: State,+items: List<&2,Item>) -> State:
  State{+db,+dir,+program,+ui,Selection{+old,+snap,+start,+displayed,+blame,+filters,+listing},+form,+jobs,+refresh_at,+serial} = state
  Listing{kind,full,+offset,+more,loaded,+anchor} = listing
  +results = {UI.Results{offset,U32.from_nat(List.length(&2,Item,items)),more,True{}} : UI.Results}
  +chosen = Domain.select_snapshot(maybe_snapshot(snap),first_snapshot(items))
  +next = {State{db,dir,program,UI.set_status(UI.set_results(UI.set_rows(ui,item_titles(items)),results),
    Bool.pick(String,U32.is_eq(kind,17),"Saved captures ","") ++ UI.result_label(results) ++
      Bool.pick(String,U32.is_eq(kind,17),". Choose a version or Open latest; reader stays pinned.",
        ". Reader remains pinned; Refresh restarts the live listing.")),
    Selection{items,snap,start,displayed,blame,filters,Listing{kind,full,offset,more,True{},anchor}},form,jobs,refresh_at,serial} : State}
  initial_page(next,chosen,first_ordinal(items),first_filters(items),String.is_empty(snap) && Bool.not(String.is_empty(chosen)))

def rows_done(+state: State,+kind: U32,+filters: Query.Filters,+more: Bool,
  result: Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>) -> State:
  State{db,dir,program,ui,Selection{old,snap,start,displayed,args,reader_filters,
    Listing{listing_kind,full,offset,oldmore,loaded,+anchor}},form,jobs,refresh_at,serial} = state
  match result:
    case Fail{message}:
      status(state,message)
    case Done{+rows}:
      with_rows(State{db,dir,program,ui,Selection{old,snap,start,displayed,args,reader_filters,
        Listing{listing_kind,full,offset,more,True{},anchor}},form,jobs,refresh_at,serial},
        listing_items(kind,rows,Bool.pick(Query.Filters,U32.is_eq(kind,17),full,filters)))

def listing_value(+state: State,request: Request,+value: Json.Json,valid: Bool) -> State:
  Request{+kind,args,snap,start,title} = request
  match valid:
    case False{}:
      status(state,"Result page metadata was invalid; refresh the listing.")
    case True{}:
      rows_done(state,kind,request_filters(args),String.eq(Json.get(value,"has_more"),"true"),
        Client.rows_result(Done{value}))

def listing_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{kind,args,snap,+start,title} = request
  match result:
    case Fail{message}:
      status(state,message)
    case Done{+value}:
      listing_value(state,request,value,String.eq(Json.get(value,"offset"),U32.show(start)) &&
        String.eq(Json.get(value,"limit"),"100") &&
        (String.eq(Json.get(value,"has_more"),"true") || String.eq(Json.get(value,"has_more"),"false")))

def latest_value(+state: State,+request: Request,+value: Json.Json,valid: Bool) -> State:
  Request{kind,args,snapshot,start,title} = request
  match valid:
    case True{}:
      page_nonempty(state,Json.get(value,"snapshot"),0,request_filters(args),False{})
    case False{}:
      status(state,"Latest capture response did not match its requested source; reader remains pinned.")

def latest_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{kind,args,snapshot,start,title} = request
  match result:
    case Fail{message}:
      status(state,message)
    case Done{+value}:
      latest_value(state,request,value,String.eq(Json.get(value,"anchor_snapshot"),snapshot) &&
        P.decimal_valid(Json.get(value,"snapshot")) && Bool.not(String.eq(Json.get(value,"snapshot"),"0")) &&
        Bool.not(Cmp.is_gt(P.decimal_compare(Json.get(value,"snapshot"),"9223372036854775807"))))

def text_done(+state: State,+request: Request,result: Result<&2,&2,String,String>) -> State:
  State{+db,+dir,+program,+ui,Selection{+items,+old,+oldstart,+displayed,+blame,+filters,+listing},Form{+mode,+search,+source,+form,+files},+jobs,+refresh_at,+serial} = state
  Request{+kind,+args,+snap,+start,+title} = request
  match result:
    case Fail{message}:
      status(State{db,dir,program,ui,Selection{items,old,oldstart,displayed,blame,filters,listing},Form{mode,search,source,form,files},jobs,refresh_at,serial},message)
    case Done{text}:
      State{db,dir,program,UI.set_status(UI.set_reader(Bool.pick(UI.State,file_kind(kind) || U32.is_eq(mode,0),ui,UI.set_query(ui,search)),title,text),"Captured evidence loaded. Scroll or drag to select; Cmd+C copies."),
        Selection{items,Bool.pick(String,file_kind(kind),old,snap),start,kind,
          Bool.pick(List<&2,String>,file_kind(kind),args,blame),
          Bool.pick(Query.Filters,file_kind(kind) || U32.is_eq(kind,14),filters,request_filters(args)),listing},Form{Bool.pick(U32,file_kind(kind),2,0),search,source,form,files},jobs,refresh_at,serial}

# The activity worker returns immutable identity and physical-record cursors,
# not search-hit counts. Keep this metadata in Selection's tagged view_args;
# neither Files nor transcript exports interpret it as a file/range request.
def tools_text_matches(+value: Json.Json,+key: String,expected: String) -> Bool:
  Files.text_valid(Json.field(value,key)) && String.eq(Json.get(value,key),expected)

def tools_id(+value: Json.Json,+key: String) -> Bool:
  Files.text_valid(Json.field(value,key)) && P.decimal_valid(Json.get(value,key)) &&
    Bool.not(String.eq(Json.get(value,key),"0")) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(Json.get(value,key),"9223372036854775807")))

def tools_locator(+value: Json.Json) -> Bool:
  Files.text_valid(Json.field(value,"source")) && String.starts_with(Json.get(value,"source"),"/") &&
    Bool.not(String.contains(Json.get(value,"source"),"\0")) && Nat.is_le(String.length(Json.get(value,"source")),8192n)

def tools_scope(+value: Json.Json,filters: Query.Filters) -> Bool:
  Query.Filters{query,provider,repo,role,after} = filters
  tools_text_matches(value,"provider",provider) && tools_text_matches(value,"repository",repo) &&
    tools_text_matches(value,"role",role) && tools_text_matches(value,"after",after)

def tools_numbers(+value: Json.Json,keys: List<&2,String>) -> Bool:
  match keys:
    case []:
      True{}
    case key <> rest:
      Files.number_valid(Json.field(value,key)) && tools_numbers(value,rest)

def tools_next(value: Json.Json,+end: Nat,total: U32) -> Bool:
  match value:
    case Json.JNull{}:
      Nat.is_ge(end,U32.to_nat(total))
    case Json.JNumber{text}:
      String.eq(text,Nat.show(end)) && Nat.is_lt(end,U32.to_nat(total))
    case _:
      False{}

def tools_present(value: Maybe<&2,Json.Json>) -> Bool:
  match value:
    case Some{value}:
      True{}
    case None{}:
      False{}

def tools_has_next(value: Json.Json) -> Bool:
  match value:
    case Json.JObject{fields}:
      tools_present(Json.field_scan(fields,"next",None{}))
    case _:
      False{}

def tools_bounds(+value: Json.Json,+start: U32,+total: U32,+selected: U32,+provider: String) -> Bool:
  U32.is_eq(selected,U32.min(40,UI.minus(total,start))) &&
    tools_has_next(value) && tools_next(Json.field(value,"next"),Nat.add(U32.to_nat(start),U32.to_nat(selected)),total) &&
    String.eq(Json.get(value,"verified_count"),U32.show(Bool.pick(U32,
      String.is_empty(provider) || String.eq(provider,Json.get(value,"provider")),selected,0)))

def tools_range(+value: Json.Json,+start: U32,filters: Query.Filters) -> Bool:
  Query.Filters{query,provider,repo,role,after} = filters
  tools_numbers(value,["start","requested_count","selected_count","verified_count","total_records"]) &&
    String.eq(Json.get(value,"start"),U32.show(start)) && String.eq(Json.get(value,"requested_count"),"40") &&
    tools_bounds(value,start,Files.number(Json.get(value,"total_records")),Files.number(Json.get(value,"selected_count")),provider)

def tools_same_identity(+value: Json.Json,+snapshot: String,args: List<&2,String>) -> Bool:
  match args:
    case "activity" <> +pinned <> source <> generation <> extent <> provider <> total <> next <> selected <> []:
      Bool.not(String.eq(snapshot,pinned)) ||
        (String.eq(Json.get(value,"source"),source) && String.eq(Json.get(value,"generation"),generation) &&
        String.eq(Json.get(value,"extent"),extent) && String.eq(Json.get(value,"provider"),provider) &&
        String.eq(Json.get(value,"total_records"),total))
    case _:
      True{}

def tools_request_args(args: List<&2,String>,snapshot: String,start: U32) -> Bool:
  match args:
    case "activity-scope" <> snap <> first <> "40" <> provider <> repo <> role <> after <> []:
      String.eq(snap,snapshot) && String.eq(first,U32.show(start))
    case _:
      False{}

def tools_request_valid(request: Request) -> Bool:
  Request{kind,args,snapshot,start,title} = request
  U32.is_eq(kind,24) && tools_request_args(args,snapshot,start)

def tools_valid(state: State,+request: Request,+value: Json.Json) -> Bool:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,view_args,filters,listing},Form{mode,search,source,blame,files},jobs,deadline,serial} = state
  Request{kind,+args,+snapshot,first,title} = request
  U32.is_eq(mode,0) && tools_request_valid(request) && tools_text_matches(value,"kind","recorded_activity") &&
    tools_text_matches(value,"snapshot",snapshot) && tools_id(value,"snapshot") && tools_locator(value) && tools_id(value,"generation") &&
    Files.text_valid(Json.field(value,"provider")) &&
    (String.eq(Json.get(value,"provider"),"claude") || String.eq(Json.get(value,"provider"),"codex")) &&
    Files.text_valid(Json.field(value,"extent")) && Files.number_valid(Json.JNumber{Json.get(value,"extent")}) &&
    Files.text_valid(Json.field(value,"text")) && tools_scope(Json.field(value,"scope"),request_filters(args)) &&
    tools_range(value,first,request_filters(args)) && tools_same_identity(value,snapshot,view_args)

def tools_metadata(+value: Json.Json) -> List<&2,String>:
  ["activity",Json.get(value,"snapshot"),Json.get(value,"source"),Json.get(value,"generation"),Json.get(value,"extent"),
    Json.get(value,"provider"),Json.get(value,"total_records"),U32.show(Files.next(Json.field(value,"next"))),Json.get(value,"selected_count")]

def tools_title(+value: Json.Json) -> String:
  "Tools | snap " ++ Json.get(value,"snapshot") ++ " | " ++ Json.get(value,"start") ++
    "+" ++ Json.get(value,"selected_count") ++ "/" ++ Json.get(value,"total_records") ++ " records"

def tools_apply(state: State,+value: Json.Json) -> State:
  State{db,dir,program,ui,Selection{items,snapshot,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  State{db,dir,program,UI.set_status(ui,
    "Recorded Tools loaded. Prev/Next text pages captured records; Copy/Export preserve displayed evidence."),
    Selection{items,snapshot,start,displayed,tools_metadata(value),filters,listing},form,jobs,deadline,serial}

def tools_value(+state: State,+request: Request,+value: Json.Json,valid: Bool) -> State:
  Request{kind,args,snapshot,start,title} = request
  match valid:
    case False{}:
      status(state,"Tools response did not match its captured identity, range or filters; the reader is unchanged.")
    case True{}:
      tools_apply(text_done(state,Request{kind,args,snapshot,start,tools_title(value)},Done{Json.get(value,"text")}),value)

def tools_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  match result:
    case Fail{message}:
      status(state,message)
    case Done{+value}:
      tools_value(state,request,value,tools_valid(state,request,value))

def read_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{+kind,+args,+snap,+start,+title} = request
  match kind:
    case 1:
      listing_done(state,request,result)
    case 2:
      listing_done(state,request,result)
    case 17:
      listing_done(state,request,result)
    case 18:
      latest_done(state,request,result)
    case 19:
      storage_done(state,Client.text_result(result))
    case 6:
      source_rows(state,Client.rows_result(result))
    case 20:
      files_done(state,request,result)
    case 21:
      files_done(state,request,result)
    case 22:
      files_done(state,request,result)
    case 23:
      files_done(state,request,result)
    case 24:
      tools_done(state,request,result)
    case _:
      text_done(state,request,Client.text_result(result))

def read_current(+state: State,+request: Request,+reply: Reply,+current: Bool) -> State:
  Reply{+value} = reply
  match current:
    case False{}:
      clear_reader(state)
    case True{}:
      read_done(clear_reader(state),request,value)

def poll_read_ready(+state: State,+ticket: U32,+request: Request,chan: Chan(Reply),result: Maybe<&1,Reply>) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  match result:
    case None{}:
      do IO<State>:
        Chan.close(Reply,chan)
        return status(clear_reader(state),"Local reader ended without a result.")
    case Some{reply}:
      do IO<State>:
        Chan.close(Reply,chan)
        return read_current(state,request,reply,U32.is_eq(ticket,revision))

def poll_read_result(+state: State,+ticket: U32,+request: Request,chan: Chan(Reply),result: Poll<&1,&1,Maybe<&1,Reply>,Unit>) -> IO(State):
  match result:
    case Wait{unit}:
      IO.pure(State,state)
    case Ready{value}:
      poll_read_ready(state,ticket,request,chan,value)

def poll_read(+state: State,pending: Maybe<&2,Pending>) -> IO(State):
  match pending:
    case None{}:
      IO.pure(State,state)
    case Some{Pending{ticket,request,+chan}}:
      do IO<State>:
        result : Poll<&1,&1,Maybe<&1,Reply>,Unit> <- Chan.try_recv(Reply,chan,0)
        poll_read_result(state,ticket,request,chan,result)

def refresh_idle(+state: State,wanted: Maybe<&2,Request>,reader: Maybe<&2,Pending>) -> State:
  match wanted reader:
    case None{} None{}:
      reload_listing(state)
    case _ _:
      status(state,"Capture finished. Your current view stays pinned.")

def refresh_finished(+state: State) -> State:
  State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = state
  refresh_idle(state,wanted,reader)

def refresh_error_kind(failed: String,discovery: Json.Json,partial: Bool,bad_discovery: Bool) -> String:
  match partial bad_discovery:
    case True{} _:
      "Partial refresh: " ++ failed ++ " files failed. Accepted captures remain available; inspect refresh-all diagnostics."
    case False{} True{}:
      "Source discovery failed: " ++ String.take(Json.get(discovery,"error"),160n)
    case _ _:
      ""

def refresh_error(+value: Json.Json) -> String:
  +failed = Json.get(value,"failed")
  +discovery = Json.field(value,"discovery")
  refresh_error_kind(failed,discovery,Bool.not(String.is_empty(failed)) && Bool.not(String.eq(failed,"0")),
    String.eq(Json.get(discovery,"status"),"failed"))

def write_mode(+state: State,mode: U32,+value: Json.Json) -> State:
  match mode:
    case 0:
      refresh_finished(status(state,"Refresh batch finished; accepted snapshots stay pinned."))
    case _:
      status(state,"Capture batch finished. Current input retained; click Settings again to browse.")

def write_capture_ok(+state: State,mode: U32,+value: Json.Json,error: String,ok: Bool) -> State:
  match ok:
    case False{}:
      status(state,error)
    case True{}:
      write_mode(state,mode,value)

def write_capture(state: State,mode: U32,+value: Json.Json,+error: String) -> State:
  write_capture_ok(state,mode,value,error,String.is_empty(error))

def automatic_success(+state: State,mode: U32,+value: Json.Json) -> State:
  match mode:
    case 0:
      write_capture(state,mode,value,refresh_error(value))
    case _:
      state

def write_success(+state: State,+kind: U32,+title: String,+mode: U32,+value: Json.Json) -> State:
  match kind:
    case 9:
      status(state,"Exported bounded evidence: " ++ title)
    case 10:
      status(state,"Source folder disabled. Retained evidence remains available. Reopen Settings to refresh the list.")
    case 15:
      automatic_success(state,mode,value)
    case 16:
      status(state,"Verified search rows rebuilt for " ++ title ++ ". Captured evidence remains retained.")
    case _:
      write_capture(state,mode,value,refresh_error(value))

def write_failed(+state: State,+kind: U32,+message: String) -> State:
  status(state,Bool.pick(String,U32.is_eq(kind,7) || U32.is_eq(kind,8) || U32.is_eq(kind,15),
    "Capture/refresh failed; earlier captures may have completed: " ++ message,message))

def write_value(+state: State,+kind: U32,+title: String,+mode: U32,result: Result<&2,&2,String,Json.Json>) -> State:
  match result:
    case Fail{message}:
      write_failed(state,kind,message)
    case Done{value}:
      write_success(state,kind,title,mode,value)

def write_done(+state: State,+request: Request,+reply: Reply) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files},+jobs,+refresh_at,+serial} = state
  Request{+kind,+args,+snap,+start,+title} = request
  Reply{+value} = reply
  write_value(State{db,dir,program,ui,selection,Form{mode,search,source,blame,files},jobs,refresh_at,serial},kind,title,mode,value)

def poll_write_ready(+state: State,+request: Request,chan: Chan(Reply),result: Maybe<&1,Reply>) -> IO(State):
  match result:
    case None{}:
      do IO<State>:
        Chan.close(Reply,chan)
        return status(clear_writer(state),"Local writer ended without a result. Accepted captures remain available.")
    case Some{reply}:
      do IO<State>:
        Chan.close(Reply,chan)
        return write_done(clear_writer(state),request,reply)

def poll_write_result(+state: State,+request: Request,chan: Chan(Reply),result: Poll<&1,&1,Maybe<&1,Reply>,Unit>) -> IO(State):
  match result:
    case Wait{unit}:
      IO.pure(State,state)
    case Ready{value}:
      poll_write_ready(state,request,chan,value)

def poll_write(+state: State,pending: Maybe<&2,Pending>) -> IO(State):
  match pending:
    case None{}:
      IO.pure(State,state)
    case Some{Pending{ticket,request,+chan}}:
      do IO<State>:
        result : Poll<&1,&1,Maybe<&1,Reply>,Unit> <- Chan.try_recv(Reply,chan,0)
        poll_write_result(state,request,chan,result)

def start_read(+state: State,wanted: Maybe<&2,Request>,busy: Maybe<&2,Pending>) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+old,+reader,+writer,+paused},+refresh_at,+serial} = state
  match wanted busy:
    case Some{Request{+kind,+args,+snap,+start,+title}} None{}:
      do IO<State>:
        chan : Chan(Reply) <- IO.fork(Reply,read_job(program,dir,args))
        return State{db,dir,program,ui,selection,form,Jobs{revision,None{},Some{Pending{revision,Request{kind,args,snap,start,title},chan}},writer,paused},refresh_at,serial}
    case _ _:
      IO.pure(State,State{db,dir,program,ui,selection,form,Jobs{revision,old,reader,writer,paused},refresh_at,serial})

# The deadline is monotonic milliseconds, never a count of rendered frames.
# Unarmed while paused, editing a form or writing: resume/completion gets a full
# interval instead of immediately repeating a long capture. Nat avoids uptime
# truncation at the U32 millisecond boundary.
def refresh_deadline(+state: State,deadline: Nat) -> State:
  State{db,dir,program,ui,selection,form,jobs,old,serial} = state
  State{db,dir,program,ui,selection,form,jobs,deadline,serial}

def next_refresh(now: Nat) -> Nat:
  Nat.add(now,30000n)

def refresh_due(+deadline: Nat,+now: Nat) -> Bool:
  Bool.not(Nat.is_eq(deadline,0n)) && Nat.is_ge(now,deadline)

def refresh_unarmed(+deadline: Nat,+now: Nat) -> Bool:
  Nat.is_eq(deadline,0n) || Nat.is_gt(deadline,next_refresh(now))

def auto_due(+state: State,+now: Nat,+unarmed: Bool,+due: Bool) -> IO(State):
  match unarmed due:
    case True{} _:
      IO.pure(State,refresh_deadline(state,next_refresh(now)))
    case False{} True{}:
      start_write(refresh_deadline(state,0n),
        Request{15,["refresh-all"],"",0,"Automatic registered-source refresh"},None{})
    case _ _:
      IO.pure(State,state)

def auto_active(+state: State,+now: Nat) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  match writer paused:
    case None{} False{}:
      auto_due(state,now,refresh_unarmed(refresh_at,now),refresh_due(refresh_at,now))
    case _ _:
      IO.pure(State,refresh_deadline(state,0n))

def auto_mode(+state: State,mode: U32,now: Nat) -> IO(State):
  match mode:
    case 0:
      auto_active(state,now)
    case _:
      IO.pure(State,refresh_deadline(state,0n))

def auto_refresh(+state: State,+now: Nat) -> IO(State):
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,+files},jobs,refresh_at,serial} = state
  auto_mode(state,mode,now)

def service_start(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  do IO<State>:
    next : State <- start_read(state,wanted,reader)
    now : Nat <- IO.now()
    auto_refresh(next,now)

def service_write(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  do IO<State>:
    next : State <- poll_write(state,writer)
    service_start(next)

def service(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  do IO<State>:
    next : State <- poll_read(state,reader)
    service_write(next)

def toggle_pause(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  status(State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,writer,Bool.not(paused)},0n,serial},
    Bool.pick(String,paused,"Automatic refresh resumed.","Automatic refresh paused. In-flight work finishes safely; manual Refresh still works."))

def files_enter_action(+state: State,index: U32,query: Bool) -> State:
  match query:
    case True{}:
      files_open_repo(state)
    case False{}:
      files_select(state,index)

def open_selected(+state: State,index: U32,active: Bool) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  match active:
    case True{}:
      files_select(state,index)
    case False{}:
      open_item(state,select_item(items,U32.to_nat(index)))


def enter(+state: State,+index: U32) -> IO(State):
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+args,+filters,+listing},Form{+mode,+search,+source,+blameform,+files},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      refresh(state)
    case 2:
      IO.pure(State,blame(state))
    case 3:
      IO.pure(State,files_enter_action(state,index,U32.is_eq(UI.focus(ui),0)))
    case _:
      IO.pure(State,open_item(state,select_item(items,U32.to_nat(index))))

def handle(+state: State,action: UI.Action) -> IO(Maybe<State>):
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+args,+filters,+listing},+form,+jobs,+refresh_at,+serial} = state
  match action:
    case UI.Quit{}:
      IO.pure(Maybe<State>,None{})
    case UI.Search{}:
      IO.pure(Maybe<State>,Some{form_text(state)})
    case UI.Scope{provider}:
      IO.pure(Maybe<State>,Some{scope_changed(state)})
    case UI.Open{index}:
      IO.pure(Maybe<State>,Some{open_selected(state,index,files_active(state))})
    case UI.Submit{}:
      do IO<Maybe<State>>:
        next : State <- enter(state,UI.selected(ui))
        return Some{next}
    case UI.Copy{text}:
      do IO<Maybe<State>>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- UI.clipboard_copy(text)
        return Some{copy_done(state,result)}
    case UI.Paste{}:
      do IO<Maybe<State>>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- UI.clipboard_paste()
        return Some{paste_done(state,result)}
    case UI.Settings{}:
      IO.pure(Maybe<State>,Some{settings(state)})
    case UI.Storage{}:
      IO.pure(Maybe<State>,Some{storage(state)})
    case UI.Files{}:
      IO.pure(Maybe<State>,Some{files_toggle(state,files_active(state))})
    case UI.RepoOpen{}:
      IO.pure(Maybe<State>,Some{files_open_repo(state)})
    case UI.RepoParent{}:
      IO.pure(Maybe<State>,Some{files_tree_guard(state,True{},Files.pinned(Files.identity(files_model(state))))})
    case UI.Filter{}:
      IO.pure(Maybe<State>,Some{filter_help(state)})
    case UI.Blame{}:
      IO.pure(Maybe<State>,Some{blame(state)})
    case UI.Refresh{}:
      do IO<Maybe<State>>:
        next : State <- refresh(state)
        return Some{next}
    case UI.Pause{}:
      IO.pure(Maybe<State>,Some{toggle_pause(state)})
    case UI.Previous{}:
      IO.pure(Maybe<State>,Some{paging(state,False{})})
    case UI.Next{}:
      IO.pure(Maybe<State>,Some{paging(state,True{})})
    case UI.ListPrevious{}:
      IO.pure(Maybe<State>,Some{list_paging(state,False{})})
    case UI.ListNext{}:
      IO.pure(Maybe<State>,Some{list_paging(state,True{})})
    case UI.Why{}:
      IO.pure(Maybe<State>,Some{why(state)})
    case UI.Usage{}:
      IO.pure(Maybe<State>,Some{usage(state)})
    case UI.Tools{}:
      IO.pure(Maybe<State>,Some{tools(state)})
    case UI.Rebuild{}:
      do IO<Maybe<State>>:
        next : State <- rebuild(state)
        return Some{next}
    case UI.Versions{}:
      IO.pure(Maybe<State>,Some{versions(state)})
    case UI.OpenLatest{}:
      IO.pure(Maybe<State>,Some{open_latest(state)})
    case UI.Export{}:
      do IO<Maybe<State>>:
        next : State <- export(state)
        return Some{next}
    case _:
      IO.pure(Maybe<State>,Some{state})

def event(+state: State,result: UI.State & UI.Action) -> IO(Maybe<State>):
  (ui,action) = result
  handle(replace_ui(state,ui),action)

def events_next(result: Maybe<State>,next: State -> IO(Maybe<State>)) -> IO(Maybe<State>):
  match result:
    case None{}:
      IO.pure(Maybe<State>,None{})
    case Some{state}:
      next(state)

def events(es: List<Event>,+state: State) -> IO(Maybe<State>):
  match es:
    case []:
      IO.pure(Maybe<State>,Some{state})
    case e <> rest:
      State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = state
      do IO<Maybe<State>>:
        result : Maybe<State> <- event(state,UI.event(e,ui))
        events_next(result,s => events(rest,s))

def view_result(+state: State,result: UI.State & Image) -> State & Image:
  (ui,image) = result
  (replace_ui(state,ui),image)

def view_inner(+current: State) -> State & Image:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+refresh_at,+serial} = current
  view_result(current,UI.view(ui))

def view(state: State) -> State & Image:
  view_inner(state)

def pending_request(value: Maybe<&2,Request>) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{request}:
      True{}

def pending_job(value: Maybe<&2,Pending>) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{pending}:
      True{}

# Window.frame is also the upstream native event pump. Cap settled sleep at
# 80ms, and keep input, dirty frames and all outstanding work on the 1ms path.
# Inspect the state after service so a newly arrived reply repaints promptly.
def sleep_ms(+state: State,+had_events: Bool) -> U32:
  State{db,dir,program,UI.State{content,input,image,dirty},selection,form,
    Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = state
  Bool.pick(U32,had_events || dirty || pending_request(wanted) || pending_job(reader) || pending_job(writer),1,80)

def tick_result(had_events: Bool,result: Maybe<State>) -> IO(Maybe<State>):
  match result:
    case None{}:
      IO.pure(Maybe<State>,None{})
    case Some{state}:
      do IO<Maybe<State>>:
        +next : State <- service(state)
        IO.sleep(sleep_ms(next,had_events))
        return Some{next}

def tick_input(es: List<Event>,state: State,had_events: Bool) -> IO(Maybe<State>):
  do IO<Maybe<State>>:
    result : Maybe<State> <- events(es,state)
    tick_result(had_events,result)

def tick(es: List<Event>,state: State) -> IO(Maybe<State>):
  match es:
    case []:
      tick_input([],state,False{})
    case e <> rest:
      tick_input(e <> rest,state,True{})

def initial(+db: U32,+dir: String,+program: String) -> State:
  reload(State{db,dir,program,UI.init(),Selection{[],"",0,0,[],empty_filters(),empty_listing()},Form{0,"","","",Files.empty()},
    Jobs{0,None{},None{},None{},False{}},0n,0})

def run(+db: U32,+dir: String,+program: String) -> IO(Unit):
  App.run(~State,~App{view,tick},"Juice Bend",1408,896,initial(db,dir,program))
