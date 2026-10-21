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
import ./gui_relations.bend as Related
import ./gui_settings.bend as Settings
import ./gui_usage.bend as Usage
import ./gui_brief.bend as Brief
import ./refresh_preferences.bend as Refresh

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

type Navigation is Data:
  NoNavigation{}
  RelatedNavigation{origin: Selection,origin_view: UI.Bookmark,origin_search: String,
    page: Maybe<&2,Related.Page>,page_view: Maybe<&2,UI.Bookmark>,
    previous: List<&2,String>,phase: U32,target: Maybe<&2,Related.Reference>}
  BriefNavigation{origin: Selection,origin_view: UI.Bookmark,origin_search: String,
    prior: List<&2,Navigation>,model: List<&2,Brief.Model>}
  UsageNavigation{origin: Selection,origin_view: UI.Bookmark,origin_search: String,
    prior: List<&2,Navigation>,ready: Bool}

# Global acknowledged preferences outlive the Settings panel. Its origin is
# boxed separately and deliberately excludes SettingsState to prevent nesting.
type SettingsOrigin is Data:
  SettingsOrigin{selection: Selection,view: UI.Bookmark,mode: U32,search: String,
    source: String,blame: String,files: Files.State,navigation: List<&2,Navigation>,pending: Maybe<&2,Request>}

type SettingsState is Data:
  SettingsState{model: Settings.Model,origin: List<&2,SettingsOrigin>,input: String,provider: String}

type Form is Data:
  Form{mode: U32, search: String, source: String, blame: String, files: Files.State, navigation: List<&2,Navigation>, settings: List<&2,SettingsState>}

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

def queued_reader_status(value: Maybe<&2,Pending>) -> String:
  match value:
    case Some{Pending{_,Request{14,_,_,_,_},_}}:
      "Queued behind the previous whole-capture Usage worker. Its bounded read must finish before this read starts; its old response will be ignored."
    case _: "Loading captured evidence..."

def queue(+state: State, +request: Request) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  State{db,dir,program,UI.set_status(ui,queued_reader_status(reader)),selection,form,
    Jobs{U32.add(revision,1),Some{request},reader,writer,paused},refresh_at,serial}

def invalidate(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  State{db,dir,program,ui,selection,form,Jobs{U32.add(revision,1),None{},reader,writer,paused},refresh_at,serial}

# Navigation is boxed in a zero/one list so its two exact UI bookmarks do not
# inflate every generated State continuation. Only [] and [value] are written;
# malformed multiple entries are inactive rather than selecting an arbitrary one.
def navigation_value(values: List<&2,Navigation>) -> Navigation:
  match values:
    case value <> []: value
    case _: NoNavigation{}

def navigation_box(value: Navigation) -> List<&2,Navigation>:
  match value:
    case NoNavigation{}: []
    case _: [value]

def navigation(state: State) -> Navigation:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,navigation,settings},jobs,deadline,serial} = state
  navigation_value(navigation)

def set_navigation(state: State,navigation: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,navigation_box(navigation),settings},jobs,deadline,serial}

def navigation_active(value: Navigation) -> Bool:
  match value:
    case NoNavigation{}: False{}
    case _: True{}

def related_active(state: State) -> Bool:
  navigation_active(navigation(state))

# A transient navigation hold is distinct from the saved refresh preference.
# Usage is already held while its worker is pending, before its title changes.
def capture_suspended(state: State) -> Bool:
  related_active(state)

def navigation_phase(value: Navigation) -> U32:
  match value:
    case NoNavigation{}: 3
    case RelatedNavigation{origin,view,search,page,page_view,previous,phase,target}: phase
    case UsageNavigation{_,_,_,_,_}: 4
    case BriefNavigation{_,_,_,_,_}: 5

def related_filters(value: Navigation) -> Query.Filters:
  match value:
    case RelatedNavigation{Selection{items,snap,start,kind,args,filters,listing},view,search,page,page_view,previous,phase,target}: filters
    case _: empty_filters()

def related_restore_value(+state: State,value: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  match value:
    case RelatedNavigation{origin,view,search,page,page_view,previous,phase,target}:
      invalidate(State{db,dir,program,UI.restore(ui,view),origin,Form{0,search,source,blame,files,[],settings},jobs,0n,serial})
    case _: state

def related_restore(+state: State) -> State:
  related_restore_value(state,navigation(state))

def related_selection(origin: Selection) -> Selection:
  Selection{items,snap,start,displayed,args,filters,listing} = origin
  Selection{items,snap,start,25,[],filters,listing}

def related_back_view(+state: State,value: Navigation,bookmark: Maybe<&2,UI.Bookmark>) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  match value bookmark:
    case RelatedNavigation{+origin,view,+search,page,saved,previous,phase,target} Some{+page_view}:
      invalidate(State{db,dir,program,UI.restore(ui,page_view),related_selection(origin),
        Form{0,search,source,blame,files,[RelatedNavigation{origin,view,search,page,Some{page_view},previous,0,None{}}],settings},jobs,0n,serial})
    case _ _: related_restore(state)

def related_back_value(+state: State,+value: Navigation) -> State:
  match value:
    case RelatedNavigation{origin,view,search,page,+page_view,previous,0,target}: related_restore(state)
    case RelatedNavigation{origin,view,search,page,+page_view,previous,phase,target}: related_back_view(state,value,page_view)
    case _: status(state,"No Related navigation to return from.")

def related_back(+state: State) -> State:
  related_back_value(state,navigation(state))

def related_enter_ready(+state: State,valid: Bool) -> State:
  State{db,dir,program,+ui,Selection{items,+snap,start,kind,args,+filters,listing},Form{mode,+search,source,blame,files,old,settings},jobs,deadline,serial} = state
  match valid:
    case False{}: status(state,"Related needs a captured History reader. Return to History and choose a transcript.")
    case True{}:
      +selection = {Selection{items,snap,start,kind,args,filters,listing} : Selection}
      +view = UI.bookmark(ui)
      next = UI.set_reader(UI.set_results(UI.set_rows(ui,[]),UI.RelatedResults{1,0,False{},False{}}),
        "Related | pinning captured anchor", "Loading a bounded relationship page from retained evidence.\nBack returns the exact captured reader.\nNo latest capture or original log is opened.")
      queue(State{db,dir,program,next,related_selection(selection),
        Form{0,search,source,blame,files,[RelatedNavigation{selection,view,search,None{},None{},[],0,None{}}],settings},jobs,0n,serial},
        Request{25,Related.open_args(snap,filters),snap,0,"Related captured sessions"})

def related_enter_value(+state: State,value: Navigation) -> State:
  State{db,dir,program,ui,Selection{items,+snap,start,+kind,args,filters,listing},Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  match value:
    case NoNavigation{}:
      related_enter_ready(state,U32.is_eq(mode,0) && Bool.not(String.is_empty(snap)) &&
        (U32.is_eq(kind,3) || U32.is_eq(kind,4) || U32.is_eq(kind,14) || U32.is_eq(kind,24)))
    case _: status(state,"Related is already anchored. Use Back before starting another relationship navigation.")

def related_enter(+state: State) -> State:
  related_enter_value(state,navigation(state))

def related_next_args(+state: State,+page: Related.Page,cursor: String,step: U32,valid: Bool) -> State:
  match valid:
    case False{}: status(state,"No requested Related page is available. This does not establish absence of relatives.")
    case True{}:
      queue(state,Request{26,Related.page_args(page,cursor),Related.snapshot(Related.anchor(page)),step,"Related | pinned library watermark"})

def related_previous(+state: State,page: Related.Page,previous: List<&2,String>) -> State:
  match previous:
    case []: status(state,"Already at the first Related page.")
    case cursor <> rest: related_next_args(state,page,cursor,2,True{})

def related_forward_ready(+state: State,+page: Related.Page,room: Bool) -> State:
  match room:
    case False{}: status(state,"Related cursor history reached its 4096-page bound. Back to origin to restart; this is not a completeness claim.")
    case True{}: related_next_args(state,page,Related.next(page),1,Bool.not(String.is_empty(Related.next(page))))

def related_page_step(+state: State,+page: Related.Page,+previous: List<&2,String>,forward: Bool) -> State:
  match forward:
    case True{}:
      related_forward_ready(state,page,Nat.is_lt(List.length(&2,String,previous),4096n))
    case False{}: related_previous(state,page,previous)

def related_page_value(+state: State,forward: Bool,value: Navigation) -> State:
  match value:
    case RelatedNavigation{origin,view,search,Some{+page},saved,+previous,0,target}:
      related_page_step(state,page,previous,forward)
    case _: status(state,"Back to the Related page before paging candidate sources.")

def related_paging(+state: State,forward: Bool) -> State:
  related_page_value(state,forward,navigation(state))

def related_reload_value(+state: State,value: Navigation) -> State:
  match value:
    case RelatedNavigation{origin,view,search,Some{+page},saved,previous,0,target}:
      related_next_args(state,page,Related.after(page),0,True{})
    case _: status(state,"Related keeps its pinned anchor and target. Back to its page to reread the same watermark.")

def related_reload(+state: State) -> State:
  related_reload_value(state,navigation(state))

def related_saved_selected(saved: Maybe<&2,UI.Bookmark>,index: U32) -> Maybe<&2,UI.Bookmark>:
  match saved:
    case None{}: None{}
    case Some{view}: Some{UI.bookmark_selected(view,index)}

def related_open_row(+state: State,+index: U32,+value: Navigation,row: Maybe<&2,Related.Row>) -> State:
  State{db,dir,program,+ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  match value row:
    case RelatedNavigation{origin,view,+search,page,saved,previous,phase,target} Some{Related.Row{+reference,direction,basis,ambiguous}}:
      +snap = Related.snapshot(reference)
      +saved_view = Bool.pick(Maybe<&2,UI.Bookmark>,U32.is_eq(phase,0),Some{UI.bookmark_selected(UI.bookmark(ui),index)},related_saved_selected(saved,index))
      queue(State{db,dir,program,ui,selection,Form{0,search,source,blame,files,
        [RelatedNavigation{origin,view,search,page,saved_view,previous,1,Some{reference}}],settings},jobs,0n,serial},
        Request{3,scoped_args("session-scope",snap,0,"40",related_filters(value)),snap,0,
          "Related target | snapshot " ++ snap ++ " | record 0"})
    case _ _: status(state,"Choose a candidate row. An empty page is not proof that no relatives exist.")

def related_open_value(+state: State,+index: U32,+value: Navigation) -> State:
  match value:
    case RelatedNavigation{origin,view,search,Some{Related.Page{anchor,watermark,after,next,scanned,rows,text,filters}},saved,previous,phase,target}:
      related_open_row(state,index,value,Related.select(rows,index))
    case _: status(state,"Wait for the bounded Related page before choosing a target.")

def related_open(+state: State,index: U32) -> State:
  related_open_value(state,index,navigation(state))

def related_scope_args(args: List<&2,String>) -> Query.Filters:
  match args:
    case "relations-scope" <> snap <> "15" <> provider <> repo <> role <> after <> []: Query.Filters{"",provider,repo,role,after}
    case "relations-page" <> p <> source <> gen <> snap <> extent <> watermark <> cursor <> "15" <> provider <> repo <> role <> after <> []:
      Query.Filters{"",provider,repo,role,after}
    case _: empty_filters()

def related_request_cursor(args: List<&2,String>) -> String:
  match args:
    case "relations-page" <> p <> source <> gen <> snap <> extent <> watermark <> cursor <> rest: cursor
    case _: "0"

def related_prior_cursor(previous: List<&2,String>) -> String:
  match previous:
    case []: ""
    case cursor <> rest: cursor

def related_matches_prior(+request: Request,+page: Related.Page,+value: Navigation) -> Bool:
  Request{+kind,+args,+snap,+step,title} = request
  Related.Page{+anchor,+watermark,+after,next,scanned,rows,text,filters} = page
  match value:
    case RelatedNavigation{origin,view,search,None{},saved,previous,0,target}:
      U32.is_eq(kind,25) && U32.is_eq(step,0) && String.eq(Related.snapshot(anchor),snap) && String.eq(after,"0") &&
        String.eq(String.join(args,"\0"),String.join(Related.open_args(snap,related_filters(value)),"\0"))
    case RelatedNavigation{origin,view,search,Some{+prior},saved,+previous,0,target}:
      U32.is_eq(kind,26) && Related.same(anchor,Related.anchor(prior)) && String.eq(watermark,Related.watermark(prior)) &&
        String.eq(snap,Related.snapshot(anchor)) &&
        String.eq(after,Bool.pick(String,U32.is_eq(step,1),Related.next(prior),Bool.pick(String,U32.is_eq(step,2),related_prior_cursor(previous),Related.after(prior)))) &&
        String.eq(String.join(args,"\0"),String.join(Related.page_args(prior,after),"\0"))
    case _: False{}

def related_trail(step: U32,prior: String,previous: List<&2,String>) -> List<&2,String>:
  match step previous:
    case 1 rest: prior <> rest
    case 2 head <> rest: rest
    case _ rest: rest

def related_old_after(page: Maybe<&2,Related.Page>) -> String:
  match page:
    case None{}: "0"
    case Some{Related.Page{anchor,watermark,after,next,scanned,rows,text,filters}}: after

def related_apply(+state: State,+request: Request,+page: Related.Page,value: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  Request{kind,args,snap,step,title} = request
  Related.Page{anchor,watermark,after,+next,+scanned,+rows,text,filters} = page
  match value:
    case RelatedNavigation{+origin,view,+search,+prior,saved,previous,phase,target}:
      +trail = related_trail(step,related_old_after(prior),previous)
      +number = U32.inc(U32.from_nat(List.length(&2,String,trail)))
      +shown = UI.set_status(UI.set_reader(UI.set_results(UI.set_rows(ui,Related.titles(rows)),
        UI.RelatedResults{number,U32.from_nat(List.length(&2,Related.Row,rows)),Bool.not(String.is_empty(next)),Bool.not(List.is_empty(&2,String,trail))}),
        "Related | snap " ++ Related.snapshot(anchor) ++ " | page " ++ U32.show(number),text),
        "Inspected " ++ U32.show(scanned) ++ " sources. Links/ambiguity are page-local; absent links do not prove no relatives. Back restores origin.")
      State{db,dir,program,shown,related_selection(origin),Form{0,search,source,blame,files,
        [RelatedNavigation{origin,view,search,Some{page},Some{UI.bookmark(shown)},trail,0,None{}}],settings},jobs,0n,serial}
    case _: state

def related_validated(+state: State,request: Request,page: Related.Page,valid: Bool) -> State:
  match valid:
    case True{}: related_apply(state,request,page,navigation(state))
    case False{}: status(state,"Related response did not match its pinned request. Displayed evidence is unchanged.")

def related_decoded(+state: State,+request: Request,result: Result<&2,&2,String,Related.Page>) -> State:
  match result:
    case Fail{message}: status(state,message)
    case Done{+page}:
      related_validated(state,request,page,related_matches_prior(request,page,navigation(state)))

def related_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{kind,args,snap,start,title} = request
  match result:
    case Fail{message}: status(state,message)
    case Done{value}: related_decoded(state,request,Related.decode(value,related_scope_args(args)))

def related_tool_identity(value: Navigation,response: Json.Json) -> Bool:
  match value:
    case NoNavigation{}: True{}
    case RelatedNavigation{origin,view,search,page,saved,previous,2,Some{target}}:
      Related.same(target,Related.reference(response))
    case _: False{}

def related_export_available(value: Navigation) -> Bool:
  match value:
    case RelatedNavigation{origin,view,search,Some{page},saved,previous,phase,target}: True{}
    case _: False{}

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
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,+navigation,+settings},jobs,deadline,serial} = state
  files

def files_replace(state: State,files: Files.State) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,old,+navigation,+settings},jobs,deadline,serial} = state
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,navigation,settings},jobs,deadline,serial}

def files_active(state: State) -> Bool:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,+navigation,+settings},jobs,deadline,serial} = state
  U32.is_eq(mode,3)

def files_saved_valid(+kind: U32) -> Bool:
  U32.is_eq(kind,3) || U32.is_eq(kind,4) || U32.is_eq(kind,14) || U32.is_eq(kind,24)

def files_saved_view(+ui: UI.State,valid: Bool) -> Files.Saved:
  match valid:
    case True{}:
      Files.Saved{[UI.bookmark(UI.restore(ui,UI.bookmark(ui)))]}
    case False{}:
      Files.Saved{[]}

def files_saved_for(state: State) -> Files.Saved:
  State{db,dir,program,ui,Selection{items,snap,start,kind,args,filters,listing},form,jobs,deadline,serial} = state
  files_saved_view(ui,files_saved_valid(kind) && Bool.not(String.is_empty(snap)))

# Restore the accepted reader verbatim. Do not call set_reader/set_query after
# restoring: both reset character selection or focus. Empty origins use the
# existing truthful History placeholder and exact pinned reread below.
def files_restore_view(+ui: UI.State,saved: Files.Saved) -> UI.State:
  match saved:
    case Files.Saved{[view]}: UI.restore(ui,view)
    case _: UI.set_position(UI.set_reader(ui,"History","Choose a captured session to read its owned evidence."),0,0)

def files_saved_ready(saved: Files.Saved) -> Bool:
  match saved:
    case Files.Saved{[_]}: True{}
    case _: False{}

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
  State{db,dir,program,ui,Selection{+items,+snap,+start,+displayed,+args,+filters,Listing{+kind,+full,+offset,+more,+loaded,+anchor}},Form{mode,+search,source,blame,+files,+navigation,+settings},jobs,deadline,serial} = state
  match mode:
    case 3:
      Files.State{input,identity,directory,file_source,saved} = files
      +ready = files_saved_ready(saved) && files_saved_valid(displayed) && Bool.not(String.is_empty(snap))
      fallback = UI.set_results(UI.set_rows(UI.set_query(UI.set_files(ui,False{}),search),item_titles(items)),
        UI.Results{offset,U32.from_nat(List.length(&2,Item,items)),more,loaded})
      restored = files_restore_view(fallback,Bool.pick(Files.Saved,ready,saved,Files.Saved{[]}))
      files_return_ready(invalidate(State{db,dir,program,restored,Selection{items,snap,start,Bool.pick(U32,ready,displayed,0),args,filters,Listing{kind,full,offset,more,loaded,anchor}},Form{0,search,source,blame,files,navigation,settings},jobs,deadline,serial}),
        snap,start,filters,ready)
    case _:
      state

def files_enter(+state: State) -> State:
  State{db,dir,program,+ui,selection,Form{mode,search,source,blame,+files,+navigation,+settings},jobs,deadline,serial} = state
  +next = Files.begin(files,files_saved_for(state))
  view = UI.set_reader(UI.set_results(UI.set_rows(UI.set_query(UI.set_files(ui,True{}),Files.input(next)),[]),UI.Results{0,0,False{},False{}}),
    "Files | explicit local repository", "Paste a local checkout path above.\nClick Open repo or press Return to pin HEAD.\n\nDirectory rows open committed folders/files.\nUp folder returns to the parent directory.\nPrev/Next list page directory entries.\nPrev/Next text page committed source lines.\nBlame and Why use the displayed source range.\n\nThe full pinned commit is shown in each result.\nWorking-tree edits are excluded. Symlinks and submodules are listed but never followed.\n\nCopy and Export use exactly displayed text.\nClick History at left to restore the prior captured transcript.\nNo home-folder scan or logged command is run.")
  status(invalidate(State{db,dir,program,view,selection,Form{3,search,source,blame,next,navigation,settings},jobs,0n,serial}),
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
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,+navigation,+settings},jobs,deadline,serial} = state
  Request{+kind,args,snap,start,title} = request
  match valid:
    case False{}:
      status(state,"Repository reply identity or page metadata did not match the request; current view retained.")
    case True{}:
      +next = Files.apply(kind,files,value)
      view = UI.set_reader(files_rows(kind,ui,next),Files.title(next),Json.get(value,"text"))
      State{db,dir,program,UI.set_status(view,"Committed view loaded. Copy/export preserve this exact displayed text; History restores the captured reader."),
        selection,Form{mode,search,source,blame,next,navigation,settings},jobs,deadline,serial}

def files_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{kind,args,snapshot,start,title} = request
  match result:
    case Fail{message}:
      status(state,"Repository read failed; current view retained: " ++ message)
    case Done{+value}:
      files_apply(state,request,value,files_active(state) && Files.valid(kind,files_model(state),args,value))

def list_paging_capture(+state: State,forward: Bool) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,filters,+listing},
    Form{mode,search,source,blame,+files,+navigation,+settings},jobs,refresh_at,serial} = state
  list_page_ready(state,listing,forward,U32.is_eq(mode,0) && listing_loaded(listing))

def list_paging_mode(+state: State,forward: Bool,active: Bool) -> State:
  match active:
    case True{}:
      files_list_page(state,forward)
    case False{}:
      list_paging_capture(state,forward)

def list_paging(+state: State,forward: Bool) -> State:
  list_paging_mode(state,forward,files_active(state))


def no_display(+selection: Selection) -> Selection:
  Selection{items,snap,start,displayed,blame,filters,+listing} = selection
  Selection{items,snap,start,0,blame,filters,listing}

def selection_snapshot(selection: Selection) -> String:
  Selection{items,snap,start,displayed,args,filters,+listing} = selection
  snap

def settings_value(+values: List<&2,SettingsState>) -> SettingsState:
  match values:
    case [value]: value
    case _: SettingsState{Settings.initial(),[],"","claude"}

def settings_state(+state: State) -> SettingsState:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+deadline,+serial} = state
  settings_value(settings)

def settings_model_value(+state: State,+settingsValue: SettingsState) -> Settings.Model:
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  model
def settings_model(+state: State) -> Settings.Model:
  settings_model_value(state,settings_state(state))


def set_settings(state: State,value: SettingsState) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,navigation,old},jobs,deadline,serial} = state
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,navigation,[value]},jobs,deadline,serial}

def settings_model_set_value(+state: State,+model: Settings.Model,+settingsValue: SettingsState) -> State:
  SettingsState{+old,+origin,+input,+provider} = settingsValue
  set_settings(state,SettingsState{model,origin,input,provider})
def settings_model_set(+state: State,+model: Settings.Model) -> State:
  settings_model_set_value(state,model,settings_state(state))


def settings_has_origin(+origin: List<&2,SettingsOrigin>) -> Bool:
  match origin:
    case [value]: True{}
    case _: False{}

def settings_active_value(+state: State,+settingsValue: SettingsState) -> Bool:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+deadline,+serial} = state
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  U32.is_eq(mode,1) && settings_has_origin(origin)
def settings_active(+state: State) -> Bool:
  settings_active_value(state,settings_state(state))


def settings_interval(+preferences: Refresh.Preferences) -> String:
  Refresh.Preferences{+enabled,+interval} = preferences
  match interval:
    case Refresh.Live30{}: "30 seconds"
    case Refresh.Hours2{}: "2 hours"
    case Refresh.Hours4{}: "4 hours"
    case Refresh.Hours8{}: "8 hours"
    case Refresh.Daily{}: "24 hours"

def settings_automatic_phase(+phase: U32,+enabled: Bool) -> String:
  match phase:
    case 2: Bool.pick(String,enabled,"Pause","Resume")
    case 0: "Loading"
    case 1: "Loading"
    case _: "Auto error"

def settings_automatic_pending(phase: U32,enabled: Bool,pending: Maybe<&2,Refresh.Preferences>) -> String:
  match pending:
    case Some{value}: "Saving"
    case None{}: settings_automatic_phase(phase,enabled)

def settings_automatic(+model: Settings.Model) -> String:
  Settings.Model{phase,Refresh.Preferences{enabled,interval},desired,sources,loaded,selected,offset,last} = model
  settings_automatic_pending(phase,enabled,desired)

def settings_pref_phase(+phase: U32,+prefs: Refresh.Preferences) -> String:
  match phase:
    case 2:
      Refresh.Preferences{+enabled,+interval} = prefs
      "Automatic refresh: " ++ Bool.pick(String,enabled,"enabled","disabled") ++ " | every " ++ settings_interval(prefs) ++ ".\n"
    case 0: "Automatic refresh: not loaded; no automatic work is armed.\n"
    case 1: "Automatic refresh: loading saved preferences.\n"
    case _: "Automatic refresh unavailable. Reload retries the saved preferences; no silent repair.\n"

def settings_pref_text(+model: Settings.Model) -> String:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  settings_pref_phase(phase,prefs)

def settings_pending_text(+desired: Maybe<&2,Refresh.Preferences>) -> String:
  match desired:
    case None{}: ""
    case Some{+prefs}:
      Refresh.Preferences{+enabled,+interval} = prefs
      "Pending save: " ++ Bool.pick(String,enabled,"enabled","disabled") ++ " / " ++ settings_interval(prefs) ++
        ". Current capture finishes first; changes apply after acknowledgment.\n"

def settings_source_text(+source: Maybe<&2,Settings.Source>) -> String:
  match source:
    case None{}: "No registered folder selected.\n"
    case Some{Settings.Source{+provider,+path,+enabled}}:
      "Selected folder: " ++ provider ++ " / " ++ Bool.pick(String,enabled,"enabled","disabled") ++ "\n" ++ path ++ "\n"

def settings_rebuild_text(snapshot: String) -> String:
  match snapshot:
    case "":
      "No captured snapshot selected. Choose a captured transcript first.\n" ++
      "Rebuild changes only derived rows; retained raw remains unchanged.\n\n"
    case value:
      "Rebuild target: captured snapshot " ++ value ++ ".\n" ++
      "Rebuild capture changes only its derived rows; retained raw remains unchanged.\n\n"

def settings_body(+dir: String,+snapshot: String,+provider: String,+model: Settings.Model) -> String:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  "INDEXING / EXPLICIT SOURCES\n\n" ++ settings_rebuild_text(snapshot) ++ settings_pref_text(model) ++ settings_pending_text(desired) ++
  "Provider for new paths: " ++ provider ++ "\n\n" ++ settings_source_text(selected) ++
  "\nChoose Claude or Codex; paste a literal absolute path above. Add folder registers it; Import file captures one JSONL file. " ++
  "Enable / Disable act only on the selected registered folder. Disabling keeps all captured evidence.\n\n" ++
  "Refresh checks a bounded batch of enabled sources and explicitly imported files. A batch result is not a full-library health check. " ++
  "No private folders are scanned by default.\n\n" ++
  "Choose an interval at left. Pause and Automatic use the same saved preference. In-flight work finishes; manual Refresh remains available.\n\n" ++
  "Last operation (bounded report):\n" ++ Store.nonempty(last,"No result in this app session.") ++
  "\n\nData directory:\n" ++ dir ++ "\nCaptured snapshot: " ++ Store.nonempty(snapshot,"none") ++
  "\nBack restores the exact prior reader and selection. Storage is read-only."

def settings_source_titles(+values: List<&2,Settings.Source>) -> List<&2,String>:
  match values:
    case []: []
    case Settings.Source{+provider,+path,+enabled} <> rest:
      (provider ++ Bool.pick(String,enabled," [on] "," [off] ") ++ path) <> settings_source_titles(rest)

def settings_row_index(+rows: List<&2,Settings.Source>,+wanted: Settings.Source,+at: U32) -> U32:
  match rows:
    case []: 0
    case first <> rest: Bool.pick(U32,Settings.same(first,wanted),at,settings_row_index(rest,wanted,U32.add(at,1)))

def settings_selected_index(+model: Settings.Model,+selected: Maybe<&2,Settings.Source>) -> U32:
  match selected:
    case None{}: 0
    case Some{source}: UI.minus(settings_row_index(Settings.sources(model),source,0),Settings.offset(model))

def settings_render_value(+state: State,+settingsValue: SettingsState) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  +rows = settings_source_titles(List.take(&2,Settings.Source,List.drop(&2,Settings.Source,sources,U32.to_nat(offset)),14n))
  +view = UI.set_results(UI.set_rows(UI.set_files(ui,False{}),rows),
    UI.SettingsResults{offset,U32.from_nat(List.length(&2,Settings.Source,sources)),settings_automatic(model),loaded})
  State{db,dir,program,UI.set_position(UI.set_reader(view,"Settings | Indexing",settings_body(dir,selection_snapshot(selection),provider,model)),
    U32.min(13,settings_selected_index(model,Settings.selected(model))),0),selection,form,jobs,deadline,serial}
def settings_render(+state: State) -> State:
  settings_render_value(state,settings_state(state))


def settings_show(+state: State,+active: Bool) -> State:
  match active:
    case True{}: settings_render(state)
    case False{}: state

def settings_update(+state: State,+model: Settings.Model) -> State:
  settings_show(settings_model_set(state,model),settings_active(state))

def settings_resume(+state: State,+pending: Maybe<&2,Request>) -> State:
  match pending:
    case None{}: state
    case Some{+request}: queue(state,request)

def settings_origin_reader(+revision: U32,+reader: Maybe<&2,Pending>) -> Maybe<&2,Request>:
  match reader:
    case Some{Pending{+ticket,+request,+channel}}: Bool.pick(Maybe<&2,Request>,U32.is_eq(revision,ticket),Some{request},None{})
    case None{}: None{}

def settings_origin_wanted(+revision: U32,+reader: Maybe<&2,Pending>,+wanted: Maybe<&2,Request>) -> Maybe<&2,Request>:
  match wanted:
    case Some{+request}: Some{request}
    case None{}: settings_origin_reader(revision,reader)

def settings_pending_origin(+jobs: Jobs) -> Maybe<&2,Request>:
  Jobs{+revision,+wanted,+reader,+writer,+paused} = jobs
  settings_origin_wanted(revision,reader,wanted)

def settings_restore_value(+state: State,+saved: List<&2,SettingsOrigin>,+settingsValue: SettingsState) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  match saved:
    case [SettingsOrigin{+origin,+view,+mode,+search,+source,+blame,+files,+navigation,+pending}]:
      SettingsState{+model,+old,+input,+provider} = settingsValue
      settings_resume(invalidate(State{db,dir,program,UI.restore(ui,view),origin,
        Form{mode,search,source,blame,files,navigation,[SettingsState{model,[],input,provider}]},jobs,0n,serial}),pending)
    case _: state
def settings_restore(+state: State,+saved: List<&2,SettingsOrigin>) -> State:
  settings_restore_value(state,saved,settings_state(state))


def settings_leave_value(+state: State,+settingsValue: SettingsState) -> State:
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  settings_restore(state,origin)
def settings_leave(+state: State) -> State:
  settings_leave_value(state,settings_state(state))


def settings_enter_value(+state: State,+settingsValue: SettingsState) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+old},+jobs,+deadline,+serial} = state
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  +saved = {SettingsOrigin{selection,UI.bookmark(ui),mode,search,source,blame,files,navigation,settings_pending_origin(jobs)} : SettingsOrigin}
  queue(settings_render(State{db,dir,program,UI.set_scope(UI.set_query(ui,input),provider),no_display(selection),
    Form{1,search,input,blame,files,[],[SettingsState{model,[saved],input,provider}]},jobs,0n,serial}),
    Request{6,["sources"],U32.show(serial),0,"Registered folders"})
def settings_enter(+state: State) -> State:
  settings_enter_value(state,settings_state(state))


def settings_toggle(+state: State,+active: Bool) -> State:
  match active:
    case True{}: settings_leave(state)
    case False{}: settings_enter(state)

def settings(+state: State) -> State:
  settings_toggle(state,settings_active(state))

def settings_last(+model: Settings.Model,+message: String) -> Settings.Model:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  Settings.Model{phase,prefs,desired,sources,loaded,selected,offset,String.take(message,2048n)}

def settings_report(+state: State,+message: String) -> State:
  status(settings_update(state,settings_last(settings_model(state),message)),String.take(message,300n))

# The operation nonce is shared with export naming; source inventory requests
# freeze it and source acknowledgments advance it. Reader tickets alone cannot
# reject an inventory read that raced a different writer.
def source_nonce(+state: State) -> String:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  U32.show(serial)

def source_barrier(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  State{db,dir,program,ui,selection,form,jobs,deadline,U32.add(serial,1)}

def settings_inventory_page(+model: Settings.Model,+selected: Maybe<&2,Settings.Source>) -> Settings.Model:
  Settings.Model{phase,prefs,desired,+sources,loaded,chosen,offset,last} = model
  match selected:
    case None{}: model
    case Some{source}:
      Settings.Model{phase,prefs,desired,sources,loaded,chosen,U32.mul(U32.div(settings_row_index(sources,source,0),14),14),last}

def settings_inventory(+model: Settings.Model) -> Settings.Model:
  settings_inventory_page(model,Settings.selected(model))

def source_rows(+state: State,+result: Result<&2,&2,String,List<&2,Settings.Source>>) -> State:
  match result:
    case Fail{+message}: settings_report(state,"Source list unavailable: " ++ message)
    case Done{+rows}: settings_update(state,settings_inventory(Settings.with_sources(settings_model(state),rows)))

def settings_sources(+state: State,+result: Result<&2,&2,String,Json.Json>) -> State:
  match result:
    case Fail{+message}: source_rows(state,Fail{message})
    case Done{+value}: source_rows(state,Settings.sources_decode(value))

def source_read_apply(+state: State,+result: Result<&2,&2,String,Json.Json>,+current: Bool) -> State:
  match current:
    case True{}: settings_sources(state,result)
    case False{}: state

def source_read_done(+state: State,+request: Request,+result: Result<&2,&2,String,Json.Json>) -> State:
  Request{+kind,+args,+nonce,+start,+title} = request
  source_read_apply(state,result,String.eq(nonce,source_nonce(state)))

def settings_pick_selected(+state: State,+model: Settings.Model,+origin: List<&2,SettingsOrigin>,+selected: Maybe<&2,Settings.Source>) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  match selected:
    case None{}: state
    case Some{Settings.Source{+provider,+path,+enabled}}:
      settings_render(set_settings(State{db,dir,program,UI.set_scope(UI.set_query(ui,path),provider),selection,form,jobs,deadline,serial},SettingsState{model,origin,path,provider}))

def settings_pick_model(+state: State,+model: Settings.Model,+origin: List<&2,SettingsOrigin>) -> State:
  settings_pick_selected(state,model,origin,Settings.selected(model))

def settings_pick_value(+state: State,+index: U32,+settingsValue: SettingsState) -> State:
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  settings_pick_model(state,Settings.select(model,U32.add(Settings.offset(model),index)),origin)

def settings_pick(+state: State,+index: U32) -> State:
  settings_pick_value(state,index,settings_state(state))

def settings_page_value(+state: State,+forward: Bool,+settingsValue: Settings.Model) -> State:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = settingsValue
  +total = U32.from_nat(List.length(&2,Settings.Source,sources))
  +next = Bool.pick(U32,forward,Bool.pick(U32,U32.is_lt(U32.add(offset,14),total),U32.add(offset,14),offset),UI.minus(offset,14))
  settings_update(state,Settings.Model{phase,prefs,desired,sources,loaded,None{},next,last})
def settings_page(+state: State,+forward: Bool) -> State:
  settings_page_value(state,forward,settings_model(state))


def settings_input_value(+state: State,+settingsValue: SettingsState) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  SettingsState{+model,+origin,+input,+provider} = settingsValue
  set_settings(state,SettingsState{model,origin,UI.query(ui),UI.scope(ui)})

# Storage stays inside Settings so Back restores its original reader too.
def settings_input(+state: State) -> State:
  settings_input_value(state,settings_state(state))


def storage_ready(state: State,active: Bool) -> State:
  match active:
    case True{}: queue(state,Request{19,["storage"],"",0,"Storage inventory"})
    case False{}: queue(settings_enter(state),Request{19,["storage"],"",0,"Storage inventory"})

def storage(+state: State) -> State:
  storage_ready(state,settings_active(state))

def storage_done(state: State,result: Result<&2,&2,String,String>) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  match result:
    case Fail{message}: settings_report(state,message)
    case Done{text}:
      State{db,dir,program,UI.set_status(UI.set_reader(ui,"Settings | storage inventory",text),
        "Read-only storage inventory. Back restores the prior reader."),selection,form,jobs,deadline,serial}

def form_text(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      settings_input(State{db,dir,program,ui,selection,Form{1,search,UI.query(ui),blame,files,navigation,settings},jobs,refresh_at,serial})
    case 2:
      invalidate(State{db,dir,program,ui,selection,Form{2,search,source,UI.query(ui),files,navigation,settings},jobs,refresh_at,serial})
    case 3:
      invalidate(State{db,dir,program,ui,selection,Form{3,search,source,blame,Files.edit(files,UI.query(ui)),navigation,settings},jobs,refresh_at,serial})
    case _:
      reload(State{db,dir,program,ui,selection,Form{0,UI.query(ui),source,blame,files,navigation,settings},jobs,refresh_at,serial})

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
  State{db,dir,program,ui,selection,Form{mode,search,source,old,+files,+navigation,+settings},jobs,refresh_at,serial} = state
  State{db,dir,program,UI.set_query(ui,text),selection,Form{2,search,source,text,files,navigation,settings},jobs,refresh_at,serial}

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
  Usage.scope(filters)

def usage_active(value: Navigation) -> Bool:
  match value:
    case UsageNavigation{_,_,_,_,_}: True{}
    case _: False{}

def usage_restore_value(+state: State,value: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  match value:
    case UsageNavigation{origin,view,search,prior,ready}:
      invalidate(State{db,dir,program,UI.restore(ui,view),origin,Form{0,search,source,blame,files,prior,settings},jobs,deadline,serial})
    case _: state

def usage_restore(+state: State) -> State:
  usage_restore_value(state,navigation(state))

def usage_enter(+state: State,+snap: String,+start: U32) -> State:
  State{db,dir,program,+ui,+selection,Form{mode,+search,source,blame,files,prior,settings},jobs,deadline,serial} = state
  status(queue(State{db,dir,program,ui,
    selection,Form{mode,search,source,blame,files,[UsageNavigation{selection,UI.bookmark(ui),search,prior,False{}}],settings},jobs,deadline,serial},
    Request{14,["session-usage",snap],snap,start,"Usage | whole captured session | snapshot " ++ snap}),
    "Scanning the whole pinned capture. Back restores this range immediately; the active worker may finish before another read starts.")

def usage_enter_ready(state: State,snap: String,start: U32,active: Bool) -> State:
  match active:
    case True{}: status(state,"Usage is already scanning or displaying this whole pinned capture. Back returns to its original range.")
    case False{}: usage_enter(state,snap,start)

def usage_nonempty(+state: State,+snap: String,+start: U32,+filters: Query.Filters,valid: Bool) -> State:
  match valid:
    case True{}:
      usage_enter_ready(state,snap,start,usage_active(navigation(state)))
    case False{}:
      status(state,"Whole-session Usage would widen this repository, role or date scope. Clear those filters and reopen a transcript first.")

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

def usage_item_identity(items: List<&2,Item>,+capture: Json.Json,+snapshot: String) -> Bool:
  match items:
    case []: True{}
    case Item{+snap,_,_,+provider,_,generation,_} <> rest:
      (Bool.not(String.eq(snapshot,snap)) ||
        ((String.eq(provider,"capture") || String.eq(provider,Json.get(capture,"provider"))) && String.eq(generation,Json.get(capture,"generation")))) &&
        usage_item_identity(rest,capture,snapshot)

def usage_view_identity(args: List<&2,String>,+capture: Json.Json) -> Bool:
  match args:
    case "activity" <> snap <> source <> generation <> extent <> provider <> total <> next <> count <> []:
      String.eq(snap,Json.get(capture,"snapshot")) && String.eq(source,Json.get(capture,"source")) &&
        String.eq(generation,Json.get(capture,"generation")) && String.eq(extent,Json.get(capture,"extent")) &&
        String.eq(provider,Json.get(capture,"provider")) && String.eq(total,Json.get(capture,"records"))
    case _: True{}

def usage_related_identity(value: Navigation,+capture: Json.Json) -> Bool:
  match value:
    case NoNavigation{}: True{}
    case RelatedNavigation{_,_,_,_,_,_,2,Some{target}}:
      Related.same(target,Related.reference(capture))
    case _: False{}

def usage_request_valid(request: Request,value: Navigation,+capture: Json.Json) -> Bool:
  Request{kind,args,+snapshot,start,title} = request
  match value:
    case UsageNavigation{Selection{items,+snap,first,displayed,view_args,filters,listing},_,_,prior,False{}}:
      U32.is_eq(kind,14) && String.eq(snapshot,snap) && U32.is_eq(start,first) &&
        String.eq(String.join(args,"\0"),String.join(["session-usage",snap],"\0")) &&
        usage_item_identity(items,capture,snapshot) && usage_view_identity(Brief.metadata_base(view_args),capture) &&
        usage_related_identity(navigation_value(prior),capture)
    case _: False{}

def usage_filters(value: Navigation) -> Query.Filters:
  match value:
    case UsageNavigation{Selection{_,_,_,_,_,filters,_},_,_,_,_}: filters
    case _: empty_filters()

def usage_selection(origin: Selection) -> Selection:
  Selection{items,snap,first,displayed,view_args,filters,listing} = origin
  Selection{items,snap,first,14,view_args,filters,listing}

def usage_apply_ready(+state: State,+request: Request,+report: Usage.Report,value: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,old,settings},jobs,deadline,serial} = state
  Request{kind,args,snapshot,start,title} = request
  match value:
    case UsageNavigation{+origin,view,+saved_search,prior,False{}}:
      State{db,dir,program,UI.set_status(UI.set_reader(ui,title,Usage.displayed(report)),Usage.description(report)),
        usage_selection(origin),
        Form{mode,search,source,blame,files,[UsageNavigation{origin,view,saved_search,prior,True{}}],settings},jobs,deadline,serial}
    case _: status(state,"Usage reply was already accepted. Displayed evidence is unchanged.")

def usage_apply(state: State,request: Request,report: Usage.Report,value: Navigation,valid: Bool) -> State:
  match valid:
    case True{}: usage_apply_ready(state,request,report,value)
    case False{}: status(state,"Usage reply did not match the current pinned request, or was already accepted. Displayed evidence is unchanged.")

def usage_decoded(+state: State,+request: Request,result: Result<&2,&2,String,Usage.Report>) -> State:
  match result:
    case Fail{message}: status(state,message)
    case Done{+report}:
      Usage.Report{capture,_,_,_,_} = report
      usage_apply(state,request,report,navigation(state),usage_request_valid(request,navigation(state),capture))

def usage_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{kind,args,snapshot,start,title} = request
  match result:
    case Fail{message}: status(state,message)
    case Done{value}: usage_decoded(state,request,Usage.decode(value,snapshot,usage_filters(navigation(state))))

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
  State{db,dir,program,ui,Selection{items,+snap,start,displayed,args,filters,listing},Form{mode,search,source,blame,files,+navigation,+settings},jobs,deadline,serial} = state
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
      status(state,"Whole-session Usage has no transcript pages. Back restores the original range; scroll the summary to read it.")
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
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  reload(State{db,dir,program,UI.set_query(ui,search),selection,Form{0,search,source,blame,files,navigation,settings},jobs,refresh_at,serial})

def browse(state: State) -> State:
  browse_capture(files_leave(settings_leave(state)))


def capture_browse_capture(+state: State) -> State:
  State{db,dir,program,ui,selection,Form{mode,+search,source,blame,+files,+navigation,+settings},jobs,refresh_at,serial} = state
  State{db,dir,program,UI.set_query(ui,search),selection,Form{0,search,source,blame,files,navigation,settings},jobs,refresh_at,serial}

def capture_browse(state: State) -> State:
  capture_browse_capture(files_leave(settings_leave(state)))


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

def filter_help_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  invalidate(State{db,dir,program,UI.set_reader(UI.set_query(ui,search),"Search filters | literal terms",
    "Type words or a quoted phrase above.\n\nOptional filters:\nprovider:claude\nprovider:codex\nrepo:\"/absolute/path with spaces\"\nrole:user\nrole:assistant\nrole:tool\nafter:2026-10-01\n\nExample:\ncache role:assistant after:2026-10-01\n\nProvider tokens override the sidebar scope.\nDates are inclusive calendar dates.\nEmpty words with filters browse matching records.\nPunctuation is literal; FTS syntax is not executed.\n\nTyping applies filters. Click a result to read its exact accepted snapshot."),
    no_display(selection),Form{0,search,source,blame,files,navigation,settings},jobs,refresh_at,serial})

def filter_help(state: State) -> State:
  filter_help_capture(files_leave(state))


def blame_help_capture(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  invalidate(State{db,dir,program,UI.set_reader(UI.set_query(ui,blame),"Blame | local repository evidence",
    "Enter literal fields separated by |:\n\n/absolute/repository|relative/file|first|count\n\nOr exact commit Why:\n/absolute/repository|commit:full40hex\n\nExample:\n/tmp/demo-repo|src/cache.txt|1|20\n\nClick Blame again or press Return to run.\nThe final field is a count, from 1 to 100.\nSpaces are allowed in paths. | is reserved.\n\nGit is read-only. No logged command is run.\nMissing or ambiguous evidence remains explicit.\nContent overlap does not prove authorship.\nFile evidence searches captured sources for this repository independently of transcript filters.\n\nClick Filter to return to search."),
    no_display(selection),Form{2,search,source,blame,files,navigation,settings},jobs,refresh_at,serial})

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
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+form,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
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


# A provider click is an explicit new listing scope, unlike History return.
# Apply it after restoring the old bookmark so the bookmark cannot undo it.
def files_scope_restore(+state: State,provider: String) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  browse(State{db,dir,program,UI.set_scope(ui,provider),selection,form,jobs,deadline,serial})

def scope_changed(+state: State) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  match mode:
    case 0:
      reload(state)
    case 3:
      files_scope_restore(files_leave(state),UI.scope(ui))
    case _:
      status(state,"Provider scope selected. The current input form is unchanged.")

def read_scoped(program: String,dir: String,args: List<&2,String>) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,"--data-dir" <> dir <> linear_args(args),"",1048576,60000)
    return Reply{Client.completed(result)}

def brief_read_job(+program: String,+dir: String,+command: String,+body: String) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,["--data-dir",dir,command],body,131072,60000)
    return Reply{Client.completed(result)}

def read_job(+program: String,+dir: String,args: List<&2,String>) -> IO(Reply):
  match args:
    case "brief-prepare" <> body <> []:
      brief_read_job(program,dir,"brief-prepare",body)
    case "brief-check" <> body <> []:
      brief_read_job(program,dir,"brief-check",body)
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
    case "relations-scope" <> rest:
      read_scoped(program,dir,"relations-scope" <> rest)
    case "relations-page" <> rest:
      read_scoped(program,dir,"relations-page" <> rest)
    case other:
      do IO<Reply>:
        result : Result<&2,&2,String,Json.Json> <- Client.call(program,dir,linear_args(other))
        return Reply{result}

def run_write(+program: String,+dir: String,args: List<&2,String>) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,"--data-dir" <> dir <> linear_args(args),"",1048576,600000)
    return Reply{Client.completed(result)}

def source_change_list(+ack: Json.Json,+result: Result<&2,&2,String,Json.Json>) -> Reply:
  match result:
    case Fail{+message}: Reply{Fail{"Source change was acknowledged, but the source list could not be confirmed: " ++ message}}
    case Done{+sources}: Reply{Done{Json.JObject{[Json.JField{"kind",Json.JString{"source_change"}},Json.JField{"ack",ack},Json.JField{"sources",sources}]}}}

def source_change_result(+program: String,+dir: String,+args: List<&2,String>,+reply: Reply) -> IO(Reply):
  Reply{+value} = reply
  match value:
    case Fail{+message}: IO.pure(Reply,Reply{Fail{message}})
    case Done{+ack}:
      do IO<Reply>:
        rows : Result<&2,&2,String,Json.Json> <- Client.call(program,dir,["sources"])
        return source_change_list(ack,rows)

def source_change(+program: String,+dir: String,+args: List<&2,String>) -> IO(Reply):
  do IO<Reply>:
    reply : Reply <- run_write(program,dir,args)
    source_change_result(program,dir,args,reply)

def run_write_text(+program: String,+dir: String,+command: String,+path: String,text: String) -> IO(Reply):
  do IO<Reply>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,["--data-dir",dir,command,path],text,1048576,10000)
    return Reply{Client.completed(result)}

def write_job(+program: String,+dir: String,args: List<&2,String>) -> IO(Reply):
  match args:
    case "export-displayed" <> path <> text <> []:
      run_write_text(program,dir,"export-displayed",path,text)
    case "export-brief-text" <> path <> text <> []:
      run_write_text(program,dir,"export-brief-text",path,text)
    case "source-add" <> provider <> path <> []:
      source_change(program,dir,["source-add",provider,path])
    case "source-disable" <> provider <> path <> []:
      source_change(program,dir,["source-disable",provider,path])
    case "refresh-preferences" <> []:
      read_job(program,dir,["refresh-preferences"])
    case "refresh-preferences-set" <> enabled <> interval <> []:
      read_job(program,dir,["refresh-preferences-set",enabled,interval])
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

def refresh_normal(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      start_write(state,Request{8,["refresh-all"],"",0,"Refresh registered sources"},writer_of(state))
    case 3:
      IO.pure(State,files_tree_guard(state,False{},Files.pinned(Files.identity(files))))
    case _:
      start_write(refresh_listing(state,mode),Request{8,["refresh-all"],"",0,"Refresh registered sources"},writer_of(state))

def refresh_mode(state: State,related: Bool) -> IO(State):
  match related:
    case True{}: IO.pure(State,related_reload(state))
    case False{}: refresh_normal(state)

def refresh(+state: State) -> IO(State):
  refresh_mode(state,related_active(state))

def rebuild_allowed(+state: State,+snap: String,allowed: Bool) -> IO(State):
  match allowed:
    case True{}:
      start_write(state,Request{16,["rebuild",snap],snap,0,"Snapshot " ++ snap},writer_of(state))
    case False{}:
      IO.pure(State,status(state,"Select a captured transcript, then open Settings to rebuild that snapshot's derived search rows."))

def rebuild(+state: State) -> IO(State):
  State{db,dir,program,ui,Selection{items,+snap,start,displayed,args,filters,+listing},Form{mode,search,source,blame,+files,+navigation,+settings},jobs,refresh_at,serial} = state
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
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+blame,+filters,+listing},Form{+mode,+search,+source,+form,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
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

def related_export_at(+state: State,now: Nat) -> IO(State):
  State{db,+dir,program,+ui,selection,form,jobs,deadline,+serial} = state
  +path = dir ++ "/evidence-related-" ++ Nat.show(now) ++ "-" ++ U32.show(serial) ++ ".md"
  start_write(State{db,dir,program,ui,selection,form,jobs,deadline,U32.inc(serial)},
    Request{9,files_export_args(ui,path),"",0,path},writer_of(state))

def related_export_ready(state: State,ready: Bool) -> IO(Maybe<State>):
  match ready:
    case False{}: IO.pure(Maybe<State>,Some{status(state,"Wait for a verified Related page before exporting evidence.")})
    case True{}:
      do IO<Maybe<State>>:
        now : Nat <- IO.now()
        next : State <- related_export_at(state,now)
        return Some{next}


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

# Captured view metadata belongs to the accepted snapshot, not the live listing.
# Keep same-snapshot Tools identity across transcript/Why, but retire it only
# after a different snapshot's reader succeeds. File evidence owns its args.
def text_view_args(kind: U32,args: List<&2,String>,previous: List<&2,String>,old: String,snapshot: String) -> List<&2,String>:
  Bool.pick(List<&2,String>,file_kind(kind),args,
    Bool.pick(List<&2,String>,String.eq(old,snapshot),Brief.metadata_base(previous),[]))

def text_done(+state: State,+request: Request,result: Result<&2,&2,String,String>) -> State:
  State{+db,+dir,+program,+ui,Selection{+items,+old,+oldstart,+displayed,+blame,+filters,+listing},Form{+mode,+search,+source,+form,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  Request{+kind,+args,+snap,+start,+title} = request
  match result:
    case Fail{message}:
      status(State{db,dir,program,ui,Selection{items,old,oldstart,displayed,blame,filters,listing},Form{mode,search,source,form,files,navigation,settings},jobs,refresh_at,serial},message)
    case Done{text}:
      State{db,dir,program,UI.set_status(UI.set_reader(Bool.pick(UI.State,file_kind(kind) || U32.is_eq(mode,0),ui,UI.set_query(ui,search)),title,text),"Captured evidence loaded. Scroll or drag to select; Cmd+C copies."),
        Selection{items,Bool.pick(String,file_kind(kind),old,snap),start,kind,
          text_view_args(kind,args,blame,old,snap),
          Bool.pick(Query.Filters,file_kind(kind) || U32.is_eq(kind,14),filters,request_filters(args)),listing},Form{Bool.pick(U32,file_kind(kind),2,0),search,source,form,files,navigation,settings},jobs,refresh_at,serial}

def related_target_result(+state: State,+request: Request,value: Navigation,valid: Bool,+result: Result<&2,&2,String,String>) -> State:
  match value valid result:
    case NoNavigation{} _ _: text_done(state,request,result)
    case RelatedNavigation{origin,view,search,page,saved,previous,phase,target} True{} Done{text}:
      text_done(set_navigation(state,RelatedNavigation{origin,view,search,page,saved,previous,2,target}),request,Done{text})
    case _ True{} Fail{message}: status(state,message)
    case _ False{} _: status(state,"Captured target reply did not match the Related selection; displayed evidence is unchanged.")
    case _ _ _: status(state,"Captured target reply cannot replace whole-session Usage; Back restores the original range.")

def related_target_valid(+request: Request,+value: Navigation) -> Bool:
  Request{kind,+args,+snap,start,title} = request
  match value:
    case NoNavigation{}: True{}
    case RelatedNavigation{origin,view,search,page,saved,previous,+phase,Some{target}}:
      (U32.is_eq(phase,1) || U32.is_eq(phase,2)) && String.eq(snap,Related.snapshot(target)) &&
        (U32.is_eq(phase,2) || U32.is_eq(start,0)) &&
        String.eq(String.join(args,"\0"),String.join(scoped_args("session-scope",snap,start,"40",related_filters(value)),"\0"))
    case _: False{}

def related_target_done(+state: State,+request: Request,result: Result<&2,&2,String,String>) -> State:
  related_target_result(state,request,navigation(state),related_target_valid(request,navigation(state)),result)

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
  State{db,dir,program,ui,Selection{items,snap,start,displayed,view_args,filters,listing},Form{mode,search,source,blame,files,+navigation,+settings},jobs,deadline,serial} = state
  Request{kind,+args,+snapshot,first,title} = request
  U32.is_eq(mode,0) && tools_request_valid(request) && tools_text_matches(value,"kind","recorded_activity") &&
    tools_text_matches(value,"snapshot",snapshot) && tools_id(value,"snapshot") && tools_locator(value) && tools_id(value,"generation") &&
    Files.text_valid(Json.field(value,"provider")) &&
    (String.eq(Json.get(value,"provider"),"claude") || String.eq(Json.get(value,"provider"),"codex")) &&
    Files.text_valid(Json.field(value,"extent")) && Files.number_valid(Json.JNumber{Json.get(value,"extent")}) &&
    Files.text_valid(Json.field(value,"text")) && tools_scope(Json.field(value,"scope"),request_filters(args)) &&
    tools_range(value,first,request_filters(args)) && tools_same_identity(value,snapshot,Brief.metadata_base(view_args)) && related_tool_identity(navigation_value(navigation),value)

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

def refresh_idle(+state: State,wanted: Maybe<&2,Request>,reader: Maybe<&2,Pending>) -> State:
  match wanted reader:
    case None{} None{}:
      reload_listing(state)
    case _ _:
      status(state,"Capture finished. Your current view stays pinned.")

def refresh_finished_normal(+state: State) -> State:
  State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = state
  refresh_idle(state,wanted,reader)

def refresh_finished_mode(state: State,related: Bool) -> State:
  match related:
    case True{}: status(state,"Capture finished. Your evidence navigation and original range remain pinned.")
    case False{}: refresh_finished_normal(state)

def refresh_finished(+state: State) -> State:
  refresh_finished_mode(state,related_active(state))

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
      status(state,"Capture batch finished. Settings retains its path and saved origin; Back restores the reader.")

def write_capture_ok(+state: State,mode: U32,+value: Json.Json,error: String,ok: Bool) -> State:
  match ok:
    case False{}:
      settings_report(state,error)
    case True{}:
      write_mode(settings_report(state,"Capture batch completed: attempted " ++ Store.nonempty(Json.get(value,"attempted"),"one explicit file") ++
        "; succeeded " ++ Store.nonempty(Json.get(value,"succeeded"),"one") ++ "; failed " ++ Store.nonempty(Json.get(value,"failed"),"0") ++
        ". This bounded batch does not establish full-library health."),mode,value)

def write_capture(state: State,mode: U32,+value: Json.Json,+error: String) -> State:
  write_capture_ok(state,mode,value,error,String.is_empty(error))

def automatic_success(+state: State,+mode: U32,+value: Json.Json) -> State:
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
  settings_report(state,Bool.pick(String,U32.is_eq(kind,7) || U32.is_eq(kind,8) || U32.is_eq(kind,15),
    "Capture/refresh failed; earlier captures may have completed: " ++ message,message))

def write_value(+state: State,+kind: U32,+title: String,+mode: U32,result: Result<&2,&2,String,Json.Json>) -> State:
  match result:
    case Fail{message}:
      write_failed(state,kind,message)
    case Done{value}:
      write_success(state,kind,title,mode,value)

def preferences_paused(+state: State,+paused: Bool) -> State:
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+old},+deadline,+serial} = state
  State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,writer,paused},0n,serial}

def preferences_parse(+result: Result<&2,&2,Refresh.Failure,Refresh.Preferences>) -> Result<&2,&2,String,Refresh.Preferences>:
  match result:
    case Done{+prefs}: Done{prefs}
    case Fail{Refresh.Failure{+code,+message}}: Fail{message}

def preferences_request(+args: List<&2,String>) -> Result<&2,&2,String,Refresh.Preferences>:
  match args:
    case "refresh-preferences-set" <> enabled <> interval <> []: preferences_parse(Refresh.parse(enabled,interval))
    case _: Fail{"Preference request was not a closed full-pair update."}

def preferences_saved_result(+model: Settings.Model,+ack: Refresh.Preferences,+requested: Result<&2,&2,String,Refresh.Preferences>) -> Settings.Model:
  match requested:
    case Fail{+message}: Settings.failed(model,message)
    case Done{+value}: Settings.saved(model,value,ack)

def preferences_saved(+model: Settings.Model,+args: List<&2,String>,+ack: Refresh.Preferences) -> Settings.Model:
  preferences_saved_result(model,ack,preferences_request(args))

def preferences_finish(+state: State,+model: Settings.Model) -> State:
  status(settings_update(preferences_paused(state,Settings.paused(model)),model),
    String.take(settings_pref_text(model) ++ settings_pending_text(Settings.pending(model)),300n))

def preferences_apply(+state: State,+kind: U32,+args: List<&2,String>,+result: Result<&2,&2,String,Refresh.Preferences>) -> State:
  match result:
    case Fail{+message}:
      settings_report(settings_update(state,Settings.failed(settings_model(state),message)),"Automatic refresh unavailable: " ++ message)
    case Done{+prefs}:
      +next = Bool.pick(Settings.Model,U32.is_eq(kind,27),Settings.loaded(settings_model(state),prefs),preferences_saved(settings_model(state),args,prefs))
      preferences_finish(state,next)

def preferences_done(+state: State,+kind: U32,+args: List<&2,String>,+result: Result<&2,&2,String,Json.Json>) -> State:
  match result:
    case Fail{+message}: preferences_apply(state,kind,args,Fail{message})
    case Done{+value}: preferences_apply(state,kind,args,Settings.prefs_decode(value))

def source_effect_value(+source: Maybe<&2,Settings.Source>,+enabled: Bool) -> Bool:
  match source:
    case None{}: False{}
    case Some{Settings.Source{+provider,+path,+actual}}: Bool.not(Bool.xor(actual,enabled))

def source_effect(+kind: U32,+args: List<&2,String>,+rows: List<&2,Settings.Source>) -> Bool:
  match kind args:
    case 29 _: True{}
    case 30 "source-disable" <> provider <> path <> []: source_effect_value(Settings.find(rows,Settings.Source{provider,path,False{}}),False{})
    case 31 "source-add" <> provider <> path <> []: source_effect_value(Settings.find(rows,Settings.Source{provider,path,True{}}),True{})
    case _ _: False{}

def source_confirmed(+state: State,+rows: List<&2,Settings.Source>,+valid: Bool) -> State:
  match valid:
    case True{}: source_rows(settings_report(state,"Registered folder change confirmed by a fresh source inventory. Retained captures are unchanged; Refresh imports a bounded enabled-source batch."),Done{rows})
    case False{}: source_rows(settings_report(state,"Source command acknowledged, but the fresh inventory does not confirm the selected folder's requested state. No enabled-state success is claimed."),Done{rows})

def source_change_rows(+state: State,+kind: U32,+args: List<&2,String>,+result: Result<&2,&2,String,List<&2,Settings.Source>>) -> State:
  match result:
    case Fail{+message}: settings_report(state,"Source command acknowledged, but the inventory is invalid: " ++ message)
    case Done{+rows}: source_confirmed(state,rows,source_effect(kind,args,rows))

def source_change_apply(+state: State,+kind: U32,+args: List<&2,String>,+value: Json.Json,+valid: Bool) -> State:
  match valid:
    case False{}: settings_report(state,"Source change response did not match its exact requested provider and path. Reload the source list before retrying.")
    case True{}: source_change_rows(state,kind,args,Settings.sources_decode(Json.field(value,"sources")))

def source_change_done(+state: State,+kind: U32,+args: List<&2,String>,+result: Result<&2,&2,String,Json.Json>) -> State:
  match result:
    case Fail{+message}: settings_report(state,message)
    case Done{+value}:
      source_change_apply(state,kind,args,value,String.eq(Json.get(value,"kind"),"source_change") && Settings.source_ack(args,Json.field(value,"ack")))

def write_dispatch(state: State,kind: U32,args: List<&2,String>,title: String,mode: U32,result: Result<&2,&2,String,Json.Json>) -> State:
  match kind:
    case 27: preferences_done(state,kind,args,result)
    case 28: preferences_done(state,kind,args,result)
    case 29: source_change_done(source_barrier(state),kind,args,result)
    case 30: source_change_done(source_barrier(state),kind,args,result)
    case 31: source_change_done(source_barrier(state),kind,args,result)
    case _: write_value(state,kind,title,mode,result)

def write_done(+state: State,+request: Request,+reply: Reply) -> State:
  State{+db,+dir,+program,+ui,+selection,Form{+mode,+search,+source,+blame,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  Request{+kind,+args,+snap,+start,+title} = request
  Reply{+value} = reply
  write_dispatch(State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,navigation,settings},jobs,refresh_at,serial},kind,args,title,mode,value)

def poll_write_ready(+state: State,+request: Request,chan: Chan(Reply),result: Maybe<&1,Reply>) -> IO(State):
  match result:
    case None{}:
      do IO<State>:
        Chan.close(Reply,chan)
        return write_done(clear_writer(state),request,Reply{Fail{"Local writer ended without a result. Accepted captures remain available."}})
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

def automatic_due(+state: State,+next: Nat,+unarmed: Bool,+due: Bool) -> IO(State):
  match unarmed due:
    case True{} _: IO.pure(State,refresh_deadline(state,next))
    case False{} True{}: start_write(refresh_deadline(state,0n),Request{15,["refresh-all"],"",0,"Automatic registered-source batch"},None{})
    case _ _: IO.pure(State,state)

def automatic_ready(+state: State,+now: Nat,+next: Nat) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  automatic_due(state,next,Nat.is_eq(deadline,0n) || Nat.is_gt(deadline,next),refresh_due(deadline,now))

def automatic_deadline(+state: State,+now: Nat,+result: Result<&2,&2,String,Maybe<&2,Nat>>) -> IO(State):
  match result:
    case Fail{+message}: IO.pure(State,settings_report(refresh_deadline(settings_update(state,Settings.failed(settings_model(state),message)),0n),message))
    case Done{None{}}: IO.pure(State,refresh_deadline(state,0n))
    case Done{Some{+next}}: automatic_ready(state,now,next)

def auto_active(+state: State,+now: Nat) -> IO(State):
  State{db,dir,program,ui,selection,form,Jobs{revision,wanted,reader,writer,paused},refresh_at,serial} = state
  match writer:
    case None{}: automatic_deadline(state,now,Settings.deadline(settings_model(state),now))
    case _: IO.pure(State,refresh_deadline(state,0n))

def auto_mode(+state: State,mode: U32,now: Nat) -> IO(State):
  match mode:
    case 0:
      auto_active(state,now)
    case _:
      IO.pure(State,refresh_deadline(state,0n))

def auto_refresh_normal(+state: State,+now: Nat) -> IO(State):
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,+files,+navigation,+settings},jobs,refresh_at,serial} = state
  auto_mode(state,mode,now)

def auto_refresh_mode(state: State,now: Nat,related: Bool) -> IO(State):
  match related:
    case True{}: IO.pure(State,refresh_deadline(state,0n))
    case False{}: auto_refresh_normal(state,now)

def auto_refresh(+state: State,now: Nat) -> IO(State):
  auto_refresh_mode(state,now,related_active(state))

def preference_next(+model: Settings.Model) -> Maybe<&2,Request>:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  match phase desired:
    case 0 _: Some{Request{27,["refresh-preferences"],"",0,"Load saved refresh preferences"}}
    case 2 Some{Refresh.Preferences{+enabled,+interval}}:
      Some{Request{28,["refresh-preferences-set",Refresh.enabled_text(enabled),U32.show(Refresh.seconds(interval))],"",0,"Save automatic refresh preference"}}
    case _ _: None{}

def preference_start(+state: State,+request: Maybe<&2,Request>,+busy: Maybe<&2,Pending>) -> IO(State):
  match request busy:
    case Some{Request{+kind,+args,+snap,+start,+title}} None{}:
      start_write(Bool.pick(State,U32.is_eq(kind,27),settings_update(state,Settings.loading(settings_model(state))),state),Request{kind,args,snap,start,title},None{})
    case _ _: IO.pure(State,state)

def service_preferences(+state: State) -> IO(State):
  preference_start(state,preference_next(settings_model(state)),writer_of(state))

def service_start(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  do IO<State>:
    next : State <- start_read(state,wanted,reader)
    now : Nat <- IO.now()
    auto_refresh(next,now)

def service_write(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  do IO<State>:
    polled : State <- poll_write(state,writer)
    next : State <- service_preferences(polled)
    service_start(next)

def settings_effective(+model: Settings.Model) -> Refresh.Preferences:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  match desired:
    case None{}: prefs
    case Some{+value}: value

def settings_desire(+state: State,+prefs: Refresh.Preferences,+ready: Bool) -> State:
  match ready:
    case False{}: settings_report(state,"Saved automatic preferences are unavailable. Open Settings and Reload; no defaults are silently applied.")
    case True{}:
      status(refresh_deadline(settings_update(state,Settings.desire(settings_model(state),prefs)),0n),
        "Preference change queued. It applies only after durable acknowledgment; any active capture finishes safely.")

def preferences_ready(+model: Settings.Model) -> Bool:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = model
  U32.is_eq(phase,2)

def toggle_pause_value(+state: State,+settingsValue: Refresh.Preferences) -> State:
  Refresh.Preferences{+enabled,+interval} = settingsValue
  settings_desire(state,Refresh.Preferences{Bool.not(enabled),interval},preferences_ready(settings_model(state)))
def toggle_pause(+state: State) -> State:
  toggle_pause_value(state,settings_effective(settings_model(state)))


def settings_interval_result_value(+state: State,+interval: Maybe<&2,Refresh.Interval>,+settingsValue: Refresh.Preferences) -> State:
  match interval:
    case Some{+next}:
      Refresh.Preferences{+enabled,+old} = settingsValue
      settings_desire(state,Refresh.Preferences{enabled,next},preferences_ready(settings_model(state)))
    case None{}: settings_report(state,"Choose one of the five explicit refresh intervals.")
def settings_interval_result(+state: State,+interval: Maybe<&2,Refresh.Interval>) -> State:
  settings_interval_result_value(state,interval,settings_effective(settings_model(state)))


def settings_interval_change(+state: State,+seconds: U32) -> State:
  settings_interval_result(state,Refresh.interval_from_text(U32.show(seconds)))

def settings_reload_value(+state: State,+settingsValue: Settings.Model) -> State:
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = settingsValue
  queue(settings_update(state,Settings.Model{0,prefs,desired,sources,loaded,selected,offset,last}),
    Request{6,["sources"],source_nonce(state),0,"Reload registered folders"})
def settings_reload(+state: State) -> State:
  settings_reload_value(state,settings_model(state))


def settings_path_valid(+provider: String,+path: String) -> Bool:
  Query.provider_valid(provider) && Bool.not(String.is_empty(provider)) &&
    String.starts_with(path,"/") && Nat.is_le(String.length(path),4096n) && Bool.not(String.contains(path,SCon{Chr{0},""}))

def settings_add_checked(+state: State,+provider: String,+path: String,+file: Bool,+valid: Bool) -> IO(State):
  match valid:
    case False{}: IO.pure(State,settings_report(state,"Choose Claude or Codex and paste an absolute literal path. Use Add folder or Import file explicitly."))
    case True{}:
      start_write(state,Bool.pick(Request,file,Request{7,["import",provider,path],"",0,"Import explicit file"},
        Request{29,["source-add",provider,path],"",0,"Register explicit folder"}),writer_of(state))

def settings_add(+state: State,+file: Bool) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  settings_add_checked(state,UI.scope(ui),UI.query(ui),file,settings_path_valid(UI.scope(ui),UI.query(ui)))

def settings_enable_selected(+state: State,+enable: Bool,+selected: Maybe<&2,Settings.Source>) -> IO(State):
  match selected:
    case None{}: IO.pure(State,settings_report(state,"Select a registered folder row before Enable or Disable. Editing the path does not select a source."))
    case Some{Settings.Source{+provider,+path,+enabled}}:
      start_write(state,Request{Bool.pick(U32,enable,31,30),[Bool.pick(String,enable,"source-add","source-disable"),provider,path],"",0,
        Bool.pick(String,enable,"Enable selected folder","Disable selected folder")},writer_of(state))

def settings_enable_value(+state: State,+enable: Bool,+settingsValue: Settings.Model) -> IO(State):
  Settings.Model{+phase,+prefs,+desired,+sources,+loaded,+selected,+offset,+last} = settingsValue
  settings_enable_selected(state,enable,selected)
def settings_enable(+state: State,+enable: Bool) -> IO(State):
  settings_enable_value(state,enable,settings_model(state))


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
  State{+db,+dir,+program,+ui,Selection{+items,+snap,+start,+displayed,+args,+filters,+listing},Form{+mode,+search,+source,+blameform,+files,+navigation,+settings},+jobs,+refresh_at,+serial} = state
  match mode:
    case 1:
      IO.pure(State,settings_report(state,"Use Add folder or Import file for this literal path; Return does not guess which operation you intend."))
    case 2:
      IO.pure(State,blame(state))
    case 3:
      IO.pure(State,files_enter_action(state,index,U32.is_eq(UI.focus(ui),0)))
    case _:
      IO.pure(State,open_item(state,select_item(items,U32.to_nat(index))))

# Brief navigation freezes the actual displayed range and keeps the origin intact.
def brief_model_box(values: List<&2,Brief.Model>) -> Maybe<&2,Brief.Model>:
  match values:
    case value <> []: Some{value}
    case _: None{}

def brief_model(+value: Navigation) -> Maybe<&2,Brief.Model>:
  match value:
    case BriefNavigation{_,_,_,_,model}: brief_model_box(model)
    case _: None{}

def brief_update_value(+state: State,+model: Brief.Model,+value: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,nav,settings},jobs,deadline,serial} = state
  match value:
    case BriefNavigation{origin,view,saved,prior,old}:
      State{db,dir,program,UI.set_results(ui,UI.BriefResults{Brief.phase(model)}),selection,
        Form{mode,search,source,blame,files,[BriefNavigation{origin,view,saved,prior,[model]}],settings},jobs,deadline,serial}
    case _: state

def brief_update(+state: State,+model: Brief.Model) -> State:
  brief_update_value(state,model,navigation(state))

def brief_restore_value(+state: State,+value: Navigation) -> State:
  State{db,dir,program,ui,selection,Form{mode,search,source,blame,files,nav,settings},jobs,deadline,serial} = state
  match value:
    case BriefNavigation{origin,view,saved,prior,model}:
      invalidate(State{db,dir,program,UI.restore(ui,view),origin,Form{0,saved,source,blame,files,prior,settings},jobs,0n,serial})
    case _: state

def brief_back(+state: State) -> State:
  brief_restore_value(state,navigation(state))

def brief_prefill_identity(identity: Files.Identity) -> String:
  Files.Identity{repo,checkout,commit} = identity
  # Files identity is populated only by an explicitly opened repository.
  checkout

def brief_prefill(+files: Files.State) -> String:
  brief_prefill_identity(Files.identity(files))

def brief_enter_ready(+state: State,+count: U32,+valid: Bool) -> State:
  State{db,dir,program,+ui,Selection{+items,+snap,+start,+displayed,+args,+filters,+listing},Form{mode,+search,source,blame,+files,+prior,settings},jobs,deadline,+serial} = state
  match valid:
    case False{}: status(state,"Open a captured transcript with a nonempty verified physical range before preparing a brief. Reopen the reader if its range metadata is older.")
    case True{}:
      +selection = {Selection{items,snap,start,displayed,args,filters,listing} : Selection}
      +anchor = {Brief.Anchor{snap,start,count,filters} : Brief.Anchor}
      +root = brief_prefill(files)
      +model = {Brief.Model{anchor,root,serial,0,None{},Brief.Whole{}} : Brief.Model}
      shown = UI.set_reader(UI.set_query(UI.set_rows(UI.set_results(ui,UI.BriefResults{0}),
        ["Snapshot " ++ snap,"Records " ++ U32.show(start) ++ " + " ++ U32.show(count),"Frozen reader filters","Explicit repository only","Review before sharing"]),root),
        "Continuation brief | choose repository",Brief.guidance(anchor))
      invalidate(State{db,dir,program,shown,selection,
        Form{0,search,source,blame,files,[BriefNavigation{selection,UI.bookmark(ui),search,prior,[model]}],settings},jobs,0n,U32.inc(serial)})

def brief_enter(+state: State) -> State:
  State{_,_,_,_,Selection{_,+snap,+start,+kind,+args,_,_},Form{+mode,_,_,_,_,_,_},_,_,_} = state
  +count = Brief.selected_count(args,snap,start)
  brief_enter_ready(state,count,U32.is_eq(mode,0) && U32.is_eq(kind,3) && U32.is_gt(count,0) &&
    (U32.is_eq(navigation_phase(navigation(state)),3) || U32.is_eq(navigation_phase(navigation(state)),2)))

def brief_edit_value(+state: State,+value: Maybe<&2,Brief.Model>) -> State:
  State{_,_,_,+ui,_,_,_,_,_} = state
  match value:
    case None{}: state
    case Some{+model}:
      status(invalidate(brief_update(replace_ui(state,UI.set_reader(ui,"Continuation brief | choose repository",Brief.guidance(Brief.anchor(model)))),
        Brief.edit(model,UI.query(ui)))),"Repository input changed. Prepare a new preview; the old preview cannot be copied or exported.")

def brief_edit(+state: State) -> State:
  brief_edit_value(state,brief_model(navigation(state)))

def brief_queue(+state: State,+model: Brief.Model,+kind: U32) -> State:
  queue(brief_update(state,model),Request{kind,Brief.args(model),Brief.nonce(model),0,"Continuation brief"})

def brief_prepare_checked(+state: State,+model: Brief.Model,+valid: Bool) -> State:
  State{_,_,_,+ui,_,_,_,_,_} = state
  match valid:
    case False{}: status(state,"Enter an explicit absolute repository folder above. Captured working directories are never executed.")
    case True{}:
      brief_queue(replace_ui(state,UI.set_reader(ui,"Continuation brief | preparing",Brief.guidance(Brief.anchor(model)))),Brief.preparing(model),32)

def brief_prepare_value(+state: State,+value: Maybe<&2,Brief.Model>) -> State:
  match value:
    case Some{+model}: brief_prepare_checked(state,model,Brief.valid_root(Brief.root(model)))
    case _: status(state,"Choose Prepare brief from a captured transcript first.")

def brief_prepare(+state: State) -> State:
  brief_prepare_value(state,brief_model(navigation(state)))

def brief_check_ready(+state: State,+model: Brief.Model,+export: Bool,+choice: Brief.Choice,+valid: Bool) -> State:
  match valid:
    case True{}: brief_queue(state,Brief.checking(model,export,choice),Bool.pick(U32,export,34,33))
    case False{}: status(state,"Prepare and review a complete preview before Copy brief or Export brief. A recheck may already be pending.")

def brief_check_value(+state: State,+export: Bool,+choice: Brief.Choice,+value: Maybe<&2,Brief.Model>) -> State:
  match value:
    case Some{+model}: brief_check_ready(state,model,export,choice,U32.is_eq(Brief.phase(model),2))
    case _: status(state,"No continuation brief is ready.")

def brief_check(+state: State,+export: Bool) -> State:
  brief_check_value(state,export,Brief.Whole{},brief_model(navigation(state)))

def brief_request_matches(+request: Request,+model: Brief.Model) -> Bool:
  Request{kind,args,nonce,start,title} = request
  String.eq(nonce,Brief.nonce(model)) && U32.is_eq(start,0) &&
    String.eq(String.join(args,"\0"),String.join(Brief.args(model),"\0")) &&
    U32.is_eq(kind,Bool.pick(U32,U32.is_eq(Brief.phase(model),1),32,Bool.pick(U32,U32.is_eq(Brief.phase(model),3),33,34)))

def brief_reply_match(+model: Brief.Model,+value: Json.Json,+valid: Bool) -> Result<&2,&2,String,Brief.Preview>:
  match valid:
    case True{}: Brief.decode(value,model)
    case False{}: Fail{"Brief reply was stale. Nothing was copied or exported."}

def brief_reply_value(+request: Request,+value: Maybe<&2,Brief.Model>,+result: Result<&2,&2,String,Json.Json>) -> Result<&2,&2,String,Brief.Preview>:
  match value result:
    case Some{+model} Done{value}:
      brief_reply_match(model,value,brief_request_matches(request,model))
    case _ Fail{message}: Fail{message}
    case _ _: Fail{"The brief view was retired. Nothing was copied or exported."}

def brief_fail_value(+state: State,+message: String,+value: Maybe<&2,Brief.Model>) -> State:
  match value:
    case Some{model}: status(brief_update(state,Brief.failed(model)),message)
    case _: state

def brief_fail(+state: State,+message: String) -> State:
  brief_fail_value(state,message,brief_model(navigation(state)))

def brief_preview_value(+state: State,+preview: Brief.Preview,+value: Maybe<&2,Brief.Model>) -> State:
  State{_,_,_,ui,_,_,_,_,_} = state
  match value:
    case Some{model}:
      status(brief_update(replace_ui(state,UI.set_reader(ui,"Continuation brief | review before sharing",Brief.preview_text(preview))),Brief.ready(model,preview)),
        "Review the whole brief before sharing. Recognized sensitive fields were withheld; unknown sensitive text may remain. Copy brief and Export brief recheck this exact preview.")
    case _: state

def brief_prepared(+state: State,+result: Result<&2,&2,String,Brief.Preview>) -> State:
  match result:
    case Fail{message}: brief_fail(state,message)
    case Done{preview}: brief_preview_value(state,preview,brief_model(navigation(state)))

def brief_done(+state: State,+request: Request,+result: Result<&2,&2,String,Json.Json>) -> State:
  brief_prepared(state,brief_reply_value(request,brief_model(navigation(state)),result))

# Only accepted current check replies reach these effects. Worker check itself
# never writes a file or clipboard, so Back can safely retire pending replies.
def brief_export_at(+state: State,+text: String,+now: Nat) -> IO(State):
  State{db,+dir,program,ui,selection,form,jobs,deadline,+serial} = state
  +path = dir ++ "/continuation-brief-" ++ Nat.show(now) ++ "-" ++ U32.show(serial) ++ ".txt"
  start_write(State{db,dir,program,ui,selection,form,jobs,deadline,U32.inc(serial)},
    Request{9,["export-brief-text",path,text],"",0,path},writer_of(state))

def brief_complete(+state: State,+preview: Brief.Preview,+value: Maybe<&2,Brief.Model>) -> State:
  match value:
    case Some{model}: brief_update(state,Brief.ready(model,preview))
    case _: state

def brief_copy_text(+preview: Brief.Preview,+value: Maybe<&2,Brief.Model>) -> String:
  match value:
    case Some{model}: Brief.selected_text(preview,Brief.choice(model))
    case _: ""

def brief_choice_current(+ui: UI.State,+choice: Brief.Choice) -> Bool:
  UI.State{_,UI.Input{_,_,UI.Edit{focus,caret,anchor,_,_},_,_},_,_} = ui
  match choice:
    case Brief.Whole{}: True{}
    case Brief.Selected{first,last}: U32.is_eq(focus,2) && U32.is_eq(U32.min(caret,anchor),first) &&
      U32.is_eq(U32.max(caret,anchor),last) && U32.is_lt(first,last)

def brief_effect_guard(+state: State,+request: Request,+result: Result<&2,&2,String,Json.Json>,+valid: Bool) -> Result<&2,&2,String,Brief.Preview>:
  match valid:
    case True{}: brief_reply_value(request,brief_model(navigation(state)),result)
    case False{}: Fail{"Text selection changed while the brief was being checked. Nothing was copied or exported; select text and try again."}

def brief_effect_model(+state: State,+request: Request,+result: Result<&2,&2,String,Json.Json>,+value: Maybe<&2,Brief.Model>) -> Result<&2,&2,String,Brief.Preview>:
  State{_,_,_,ui,_,_,_,_,_} = state
  match value:
    case Some{+model}: brief_effect_guard(state,request,result,brief_choice_current(ui,Brief.choice(model)))
    case _: Fail{"The brief view was retired. Nothing was copied or exported."}

def brief_effect_reply(+state: State,+request: Request,+result: Result<&2,&2,String,Json.Json>) -> Result<&2,&2,String,Brief.Preview>:
  brief_effect_model(state,request,result,brief_model(navigation(state)))

def brief_selected_checked(+state: State,+choice: Brief.Choice,+valid: Bool) -> State:
  match valid:
    case True{}: brief_check_value(state,False{},choice,brief_model(navigation(state)))
    case False{}: status(state,"Select preview text to copy it, or choose Copy brief for the whole checked preview.")

def brief_effect_ready(+state: State,+ready: State,+preview: Brief.Preview,+export: Bool) -> IO(State):
  match export:
    case False{}:
      do IO<State>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- UI.clipboard_copy(brief_copy_text(preview,brief_model(navigation(state))))
        return copy_done(ready,result)
    case True{}:
      do IO<State>:
        now : Nat <- IO.now()
        brief_export_at(ready,Brief.preview_text(preview),now)

def brief_effect(+state: State,+preview: Brief.Preview,+export: Bool) -> IO(State):
  brief_effect_ready(state,brief_complete(state,preview,brief_model(navigation(state))),preview,export)

def brief_effect_result(+state: State,+result: Result<&2,&2,String,Brief.Preview>,+export: Bool) -> IO(State):
  match result:
    case Fail{message}: IO.pure(State,brief_fail(state,message))
    case Done{preview}: brief_effect(state,preview,export)

def brief_paste(+state: State,result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> State:
  State{_,_,_,ui,_,_,_,_,_} = state
  match result:
    case Done{(0,(text,error))}: brief_edit(replace_ui(state,UI.insert(ui,text)))
    case _: status(state,"Clipboard unavailable or paste failed.")

def brief_selection_invalidated(+state: State,+model: Brief.Model,+changed: Bool) -> State:
  match changed:
    case False{}: state
    case True{}: status(invalidate(brief_update(state,Brief.failed(model))),"Text selection changed. Pending copy was retired; copy the new selection to recheck it.")

def brief_selection_value(+state: State,+value: Maybe<&2,Brief.Model>) -> State:
  State{_,_,_,+ui,_,_,_,_,_} = state
  match value:
    case Some{+model}: brief_selection_invalidated(state,model,U32.is_eq(Brief.phase(model),3) && Bool.not(brief_choice_current(ui,Brief.choice(model))))
    case _: state

def transcript_apply_metadata(+state: State,+request: Request,+value: Json.Json,+valid: Bool) -> State:
  State{db,dir,program,ui,Selection{items,snap,start,displayed,args,filters,listing},form,jobs,deadline,serial} = state
  Request{_,_,snapshot,first,_} = request
  match valid:
    case True{}: State{db,dir,program,ui,Selection{items,snap,start,displayed,Brief.range_args(value,snapshot,first,args),filters,listing},form,jobs,deadline,serial}
    case False{}: state

def transcript_done(+state: State,+request: Request,+result: Result<&2,&2,String,Json.Json>) -> State:
  Request{_,_,+snapshot,+start,_} = request
  match result:
    case Fail{message}: related_target_done(state,request,Fail{message})
    case Done{+value}:
      transcript_apply_metadata(related_target_done(state,request,Client.text_result(Done{value})),request,value,
        related_target_valid(request,navigation(state)) && Brief.range_metadata(value,snapshot,start))

def read_done(+state: State,+request: Request,result: Result<&2,&2,String,Json.Json>) -> State:
  Request{+kind,+args,+snap,+start,+title} = request
  match kind:
    case 1:
      listing_done(state,request,result)
    case 2:
      listing_done(state,request,result)
    case 3:
      transcript_done(state,request,result)
    case 17:
      listing_done(state,request,result)
    case 18:
      latest_done(state,request,result)
    case 19:
      storage_done(state,Client.text_result(result))
    case 6:
      source_read_done(state,request,result)
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
    case 14:
      usage_done(state,request,result)
    case 25:
      related_done(state,request,result)
    case 26:
      related_done(state,request,result)
    case 32:
      brief_done(state,request,result)
    case 33:
      status(state,"Brief check requires current-request effect handling; no text was copied.")
    case 34:
      status(state,"Brief check requires current-request effect handling; no text was exported.")
    case _:
      text_done(state,request,Client.text_result(result))

def read_current(+state: State,+request: Request,+reply: Reply,+current: Bool) -> State:
  Reply{+value} = reply
  match current:
    case False{}:
      clear_reader(state)
    case True{}:
      read_done(clear_reader(state),request,value)

def read_current_kind(+state: State,+request: Request,+reply: Reply,+result: Result<&2,&2,String,Json.Json>,+kind: U32) -> IO(State):
  match kind:
    case 33: brief_effect_result(clear_reader(state),brief_effect_reply(state,request,result),False{})
    case 34: brief_effect_result(clear_reader(state),brief_effect_reply(state,request,result),True{})
    case _: IO.pure(State,read_current(state,request,reply,True{}))

def read_current_io(+state: State,+request: Request,+reply: Reply,+current: Bool) -> IO(State):
  Request{+kind,_,_,_,_} = request
  Reply{result} = reply
  match current:
    case False{}: IO.pure(State,clear_reader(state))
    case True{}: read_current_kind(state,request,reply,result,kind)

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
        read_current_io(state,request,reply,U32.is_eq(ticket,revision))

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

def service(+state: State) -> IO(State):
  State{+db,+dir,+program,+ui,+selection,+form,Jobs{+revision,+wanted,+reader,+writer,+paused},+refresh_at,+serial} = state
  do IO<State>:
    next : State <- poll_read(state,reader)
    service_write(next)

def copy_action(+state: State,text: String) -> IO(Maybe<State>):
  do IO<Maybe<State>>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- UI.clipboard_copy(text)
    return Some{copy_done(state,result)}

def handle_normal(+state: State,action: UI.Action) -> IO(Maybe<State>):
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
    case UI.CopyStatus{text}: copy_action(state,text)
    case UI.Copy{text}: copy_action(state,text)
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
    case UI.Related{}:
      IO.pure(Maybe<State>,Some{related_enter(state)})
    case UI.Brief{}:
      IO.pure(Maybe<State>,Some{brief_enter(state)})
    case UI.Back{}:
      IO.pure(Maybe<State>,Some{related_back(state)})
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

def brief_selected_copy(+state: State,+text: String) -> IO(Maybe<State>):
  State{_,_,_,+ui,_,_,_,_,_} = state
  UI.State{_,UI.Input{_,_,UI.Edit{focus,+caret,+anchor,_,_},_,_},_,_} = ui
  match focus:
    case 0: handle_normal(state,UI.Copy{text})
    case _:
      IO.pure(Maybe<State>,Some{brief_selected_checked(state,Brief.Selected{U32.min(caret,anchor),U32.max(caret,anchor)},
        U32.is_eq(focus,2) && Bool.not(String.is_empty(text)) && String.eq(text,UI.selection(ui)))})

def handle_brief_action(+state: State,+action: UI.Action) -> IO(Maybe<State>):
  match action:
    case UI.Quit{}: IO.pure(Maybe<State>,None{})
    case UI.Back{}: IO.pure(Maybe<State>,Some{brief_back(state)})
    case UI.Search{}: IO.pure(Maybe<State>,Some{brief_edit(state)})
    case UI.Submit{}: IO.pure(Maybe<State>,Some{brief_prepare(state)})
    case UI.BriefPrepare{}: IO.pure(Maybe<State>,Some{brief_prepare(state)})
    case UI.BriefCopy{}: IO.pure(Maybe<State>,Some{brief_check(state,False{})})
    case UI.Copy{text}: brief_selected_copy(state,text)
    case UI.CopyStatus{text}: handle_normal(state,UI.Copy{text})
    case UI.BriefExport{}: IO.pure(Maybe<State>,Some{brief_check(state,True{})})
    case UI.Export{}: IO.pure(Maybe<State>,Some{brief_check(state,True{})})
    case UI.Paste{}:
      do IO<Maybe<State>>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- UI.clipboard_paste()
        return Some{brief_paste(state,result)}
    case UI.NoAction{}: IO.pure(Maybe<State>,Some{state})
    case _: IO.pure(Maybe<State>,Some{status(state,"This brief keeps its frozen reader range. Back restores History before changing scope or opening another view.")})

# Missing legacy range metadata allows reading, but never enables a brief.
def handle_brief(+state: State,+action: UI.Action) -> IO(Maybe<State>):
  handle_brief_action(brief_selection_value(state,brief_model(navigation(state))),action)

def related_reader_action(state: State,action: UI.Action,ready: Bool) -> IO(Maybe<State>):
  match ready:
    case True{}: handle_normal(state,action)
    case False{}: IO.pure(Maybe<State>,Some{status(state,"Choose a Related target first. Back restores the prior reader.")})

def related_query_restore(state: State,query: String) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  State{db,dir,program,UI.set_query(ui,query),selection,form,jobs,deadline,serial}

def related_search_exit(+state: State) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  related_query_restore(related_restore(state),UI.query(ui))

def related_scope_restore(state: State,provider: String) -> State:
  State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  State{db,dir,program,UI.set_scope(ui,provider),selection,form,jobs,deadline,serial}

def related_scope_exit(state: State,provider: String) -> State:
  related_scope_restore(related_restore(state),provider)

def handle_related(+state: State,action: UI.Action,+phase: U32) -> IO(Maybe<State>):
  State{db,dir,program,+ui,selection,form,jobs,deadline,serial} = state
  match action:
    case UI.Back{}: IO.pure(Maybe<State>,Some{related_back(state)})
    case UI.Related{}: IO.pure(Maybe<State>,Some{related_enter(state)})
    case UI.Open{index}: IO.pure(Maybe<State>,Some{related_open(state,index)})
    case UI.Submit{}: IO.pure(Maybe<State>,Some{related_open(state,UI.selected(ui))})
    case UI.ListPrevious{}: IO.pure(Maybe<State>,Some{related_paging(state,False{})})
    case UI.ListNext{}: IO.pure(Maybe<State>,Some{related_paging(state,True{})})
    case UI.Refresh{}: IO.pure(Maybe<State>,Some{related_reload(state)})
    case UI.Previous{}: related_reader_action(state,UI.Previous{},U32.is_eq(phase,2))
    case UI.Next{}: related_reader_action(state,UI.Next{},U32.is_eq(phase,2))
    case UI.Why{}: related_reader_action(state,UI.Why{},U32.is_eq(phase,2))
    case UI.Tools{}: related_reader_action(state,UI.Tools{},U32.is_eq(phase,2))
    case UI.Usage{}: related_reader_action(state,UI.Usage{},U32.is_eq(phase,2))
    case UI.Export{}:
      related_export_ready(state,related_export_available(navigation(state)))
    case UI.Search{}: handle_normal(related_search_exit(state),UI.Search{})
    case UI.Scope{+provider}: handle_normal(related_scope_exit(state,provider),UI.Scope{provider})
    case UI.Paste{}: handle_normal(related_restore(state),UI.Paste{})
    case UI.Settings{}: handle_normal(related_restore(state),UI.Settings{})
    case UI.Storage{}: handle_normal(related_restore(state),UI.Storage{})
    case UI.Files{}: handle_normal(related_restore(state),UI.Files{})
    case UI.Filter{}: handle_normal(related_restore(state),UI.Filter{})
    case UI.Blame{}: handle_normal(related_restore(state),UI.Blame{})
    case UI.Versions{}: IO.pure(Maybe<State>,Some{status(state,"Back to the origin before browsing saved versions. Related targets stay exact.")})
    case UI.OpenLatest{}: IO.pure(Maybe<State>,Some{status(state,"Back to the origin before Open latest. Related never resolves a newer target.")})
    case UI.Rebuild{}: IO.pure(Maybe<State>,Some{status(state,"Back to the origin and open Settings before rebuilding a captured snapshot.")})
    case other: handle_normal(state,other)

def usage_ready(value: Navigation) -> Bool:
  match value:
    case UsageNavigation{_,_,_,_,ready}: ready
    case _: False{}

def usage_reader_pending(reader: Maybe<&2,Pending>) -> Bool:
  match reader:
    case Some{_}: True{}
    case None{}: False{}

def usage_back(+state: State) -> State:
  State{_,_,_,_,_,_,Jobs{_,_,reader,_,_},_,_} = state
  +restored = usage_restore(state)
  Bool.pick(State,usage_reader_pending(reader),status(restored,
    "Original range restored. The previous Usage worker may still finish; its result is ignored. A new read waits for that single worker."),restored)

def usage_export(+state: State,ready: Bool) -> IO(Maybe<State>):
  match ready:
    case False{}: IO.pure(Maybe<State>,Some{status(state,"Wait for the captured Usage summary before exporting it, or Back to export the original range.")})
    case True{}:
      do IO<Maybe<State>>:
        next : State <- export(state)
        return Some{next}

def handle_usage_origin_phase(state: State,action: UI.Action,phase: U32) -> IO(Maybe<State>):
  match phase:
    case 3: handle_normal(state,action)
    case 4: IO.pure(Maybe<State>,Some{status(state,"Invalid nested Usage origin; current evidence retained.")})
    case phase: handle_related(state,action,phase)

def handle_usage_origin(+state: State,action: UI.Action) -> IO(Maybe<State>):
  handle_usage_origin_phase(state,action,navigation_phase(navigation(state)))

def handle_usage(+state: State,action: UI.Action) -> IO(Maybe<State>):
  State{_,_,_,+ui,_,_,_,_,_} = state
  match action:
    case UI.Back{}: IO.pure(Maybe<State>,Some{usage_back(state)})
    case UI.Usage{}: IO.pure(Maybe<State>,Some{status(state,"This is Usage for the whole pinned capture. Back restores the original range.")})
    case UI.Previous{}: IO.pure(Maybe<State>,Some{status(state,"Whole-session Usage has no transcript pages. Back restores the original range; scroll this summary to read it.")})
    case UI.Next{}: IO.pure(Maybe<State>,Some{status(state,"Whole-session Usage has no transcript pages. Back restores the original range; scroll this summary to read it.")})
    case UI.ListPrevious{}: IO.pure(Maybe<State>,Some{status(state,"Back restores the result list and its paging position.")})
    case UI.ListNext{}: IO.pure(Maybe<State>,Some{status(state,"Back restores the result list and its paging position.")})
    case UI.Open{index}: IO.pure(Maybe<State>,Some{status(state,"Back restores the result list before opening another captured transcript.")})
    case UI.Submit{}: IO.pure(Maybe<State>,Some{status(state,"Back restores the result list before opening another captured transcript.")})
    case UI.Export{}: usage_export(state,usage_ready(navigation(state)))
    case UI.Refresh{}: IO.pure(Maybe<State>,Some{status(state,"Usage stays pinned to this accepted capture. Back to History before refreshing source files or choosing Open latest.")})
    case UI.Why{}: handle_usage_origin(usage_restore(state),UI.Why{})
    case UI.Tools{}: handle_usage_origin(usage_restore(state),UI.Tools{})
    case UI.Related{}: handle_usage_origin(usage_restore(state),UI.Related{})
    case UI.Search{}: handle_usage_origin(related_query_restore(usage_restore(state),UI.query(ui)),UI.Search{})
    case UI.Scope{+provider}: handle_usage_origin(related_scope_restore(usage_restore(state),provider),UI.Scope{provider})
    case UI.Paste{}: handle_usage_origin(usage_restore(state),UI.Paste{})
    case UI.Files{}: handle_usage_origin(usage_restore(state),UI.Files{})
    case UI.Filter{}: handle_usage_origin(usage_restore(state),UI.Filter{})
    case UI.Blame{}: handle_usage_origin(usage_restore(state),UI.Blame{})
    case UI.Versions{}: handle_usage_origin(usage_restore(state),UI.Versions{})
    case UI.OpenLatest{}: handle_usage_origin(usage_restore(state),UI.OpenLatest{})
    case other: handle_normal(state,other)

def handle_navigation(+state: State,action: UI.Action,phase: U32) -> IO(Maybe<State>):
  match phase:
    case 3: handle_normal(state,action)
    case 4: handle_usage(state,action)
    case 5: handle_brief(state,action)
    case phase: handle_related(state,action,phase)

def settings_scope(+state: State,+provider: String) -> State:
  match provider:
    case "claude": settings_render(settings_input(state))
    case "codex": settings_render(settings_input(state))
    case _: settings_report(state,"Choose the explicit Claude or Codex source provider.")

def handle_settings(+state: State,+action: UI.Action) -> IO(Maybe<State>):
  State{+db,+dir,+program,+ui,+selection,+form,+jobs,+deadline,+serial} = state
  match action:
    case UI.Settings{}: IO.pure(Maybe<State>,Some{settings_leave(state)})
    case UI.Back{}: IO.pure(Maybe<State>,Some{settings_leave(state)})
    case UI.Search{}: IO.pure(Maybe<State>,Some{form_text(state)})
    case UI.Scope{+provider}: IO.pure(Maybe<State>,Some{settings_scope(state,provider)})
    case UI.Open{+index}: IO.pure(Maybe<State>,Some{settings_pick(state,index)})
    case UI.ListPrevious{}: IO.pure(Maybe<State>,Some{settings_page(state,False{})})
    case UI.ListNext{}: IO.pure(Maybe<State>,Some{settings_page(state,True{})})
    case UI.SettingsInterval{+seconds}: IO.pure(Maybe<State>,Some{settings_interval_change(state,seconds)})
    case UI.SettingsReload{}: IO.pure(Maybe<State>,Some{settings_reload(state)})
    case UI.SettingsAddFolder{}:
      do IO<Maybe<State>>:
        next : State <- settings_add(state,False{})
        return Some{next}
    case UI.SettingsImportFile{}:
      do IO<Maybe<State>>:
        next : State <- settings_add(state,True{})
        return Some{next}
    case UI.SettingsEnable{}:
      do IO<Maybe<State>>:
        next : State <- settings_enable(state,True{})
        return Some{next}
    case UI.SettingsDisable{}:
      do IO<Maybe<State>>:
        next : State <- settings_enable(state,False{})
        return Some{next}
    case UI.Files{}: handle_normal(settings_leave(state),action)
    case UI.Filter{}: handle_normal(settings_leave(state),action)
    case UI.Blame{}: handle_normal(settings_leave(state),action)
    case UI.Why{}: IO.pure(Maybe<State>,Some{status(state,"Back restores History or Files before Why.")})
    case UI.Tools{}: IO.pure(Maybe<State>,Some{status(state,"Back restores History before recorded Tools.")})
    case UI.Usage{}: IO.pure(Maybe<State>,Some{status(state,"Back restores History before recorded Usage.")})
    case UI.Related{}: IO.pure(Maybe<State>,Some{status(state,"Back restores History before Related captures.")})
    case UI.Versions{}: IO.pure(Maybe<State>,Some{status(state,"Back restores History before saved versions.")})
    case UI.OpenLatest{}: IO.pure(Maybe<State>,Some{status(state,"Back restores History before Open latest.")})
    case UI.Previous{}: IO.pure(Maybe<State>,Some{state})
    case UI.Next{}: IO.pure(Maybe<State>,Some{state})
    case other: handle_normal(state,other)

def handle_mode_inner(+state: State,+action: UI.Action,+active: Bool) -> IO(Maybe<State>):
  match action active:
    case action True{}: handle_settings(state,action)
    case UI.Settings{} False{}: IO.pure(Maybe<State>,Some{settings(state)})
    case UI.Storage{} False{}: IO.pure(Maybe<State>,Some{storage(state)})
    case other False{}: handle_navigation(state,other,navigation_phase(navigation(state)))

def handle_mode_phase(+state: State,+action: UI.Action,active: Bool,phase: U32) -> IO(Maybe<State>):
  match phase:
    case 5: handle_brief(state,action)
    case _: handle_mode_inner(state,action,active)

def handle_mode(+state: State,+action: UI.Action,active: Bool) -> IO(Maybe<State>):
  handle_mode_phase(state,action,active,navigation_phase(navigation(state)))

def handle(+state: State,action: UI.Action) -> IO(Maybe<State>):
  handle_mode(state,action,settings_active(state))

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
  view_result(current,UI.view_capture(ui,settings_automatic(settings_model(current)),capture_suspended(current)))

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
  reload(State{db,dir,program,UI.init(),Selection{[],"",0,0,[],empty_filters(),empty_listing()},Form{0,"","","",Files.empty(),[],[]},
    Jobs{0,None{},None{},None{},False{}},0n,0})

def run(+db: U32,+dir: String,+program: String) -> IO(Unit):
  App.run(~State,~App{view,tick},"Juice Bend",1408,896,initial(db,dir,program))
