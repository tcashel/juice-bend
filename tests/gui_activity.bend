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

def field(key: String,value: String) -> Json.Field:
  Json.JField{key,Json.JString{value}}

def num(key: String,value: U32) -> Json.Field:
  Json.JField{key,Json.JNumber{U32.show(value)}}

def filters() -> Query.Filters:
  Query.Filters{"","codex","/synthetic/repository","assistant","2026-10-01"}

def scope(filters: Query.Filters) -> Json.Json:
  Query.Filters{query,provider,repo,role,after} = filters
  Json.JObject{[field("provider",provider),field("repository",repo),field("role",role),field("after",after)]}

def page(start: U32,+selected: U32,next: Json.Json) -> Json.Json:
  Json.JObject{[field("kind","recorded_activity"),field("provider","codex"),field("source","/synthetic/café 中文.jsonl"),field("generation","3"),
    field("snapshot","7"),field("extent","90000"),num("total_records",582),num("start",start),num("requested_count",40),
    num("selected_count",selected),num("verified_count",selected),Json.JField{"next",next},Json.JField{"scope",scope(filters())},
    field("text","Recorded Tools\ncall: literal shell command; never executed\nresult café 中文 🙂\ncitation snapshot7 record500")]}

def replace_fields(fields: List<&2,Json.Field>,+key: String,+value: Json.Json) -> List<&2,Json.Field>:
  match fields:
    case []:
      []
    case Json.JField{+name,old} <> rest:
      Json.JField{name,Bool.pick(Json.Json,String.eq(name,key),value,old)} <> replace_fields(rest,key,value)

def replace(value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{fields}:
      Json.JObject{replace_fields(fields,key,replacement)}
    case _:
      value

def first() -> Json.Json:
  page(500,40,Json.JNumber{"540"})

def state() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-gui-activity","/usr/bin/false",UI.set_reader(UI.set_query(UI.init(),"visible query"),"Transcript","retained transcript"),
    Gui.Selection{[],"7",500,3,[],filters(),Gui.empty_listing()},Gui.Form{0,"visible query","","",Files.empty(),[],[]},
    Gui.Jobs{9,None{},None{},None{},False{}},0n,0}

def request(+start: U32) -> Gui.Request:
  Gui.Request{24,Gui.scoped_args("activity-scope","7",start,"40",filters()),"7",start,"Tools"}

def loaded() -> Gui.State:
  Gui.read_current(state(),request(500),Gui.Reply{Done{first()}},True{})

def ui(state: Gui.State) -> UI.State:
  Gui.State{db,dir,program,ui,selection,form,jobs,deadline,serial} = state
  ui

def ui_status(ui: UI.State) -> String:
  UI.State{UI.Content{query,rows,reader,lines,title,status,scope,results,files},input,image,dirty} = ui
  status

def status(state: Gui.State) -> String:
  ui_status(ui(state))

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

def with_filters(state: Gui.State,filters: Query.Filters) -> Gui.State:
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,kind,args,old,listing},form,jobs,deadline,serial} = state
  Gui.State{db,dir,program,ui,Gui.Selection{items,snap,start,kind,args,filters,listing},form,jobs,deadline,serial}

def opening() -> IO(Unit):
  +queued = Gui.tools(state())
  do IO<Unit>:
    require(String.eq(wanted(queued),"activity-scope|7|500|40|codex|/synthetic/repository|assistant|2026-10-01"),"Tools request freezes selected snapshot range and filters")
    require(String.eq(UI.reader(ui(queued)),"retained transcript") && String.eq(capture(queued),capture(state())),"pending Tools keeps the displayed transcript and selection")
    require(String.eq(UI.query(ui(queued)),"visible query"),"Tools leaves listing query unchanged")

def loaded_view() -> IO(Unit):
  +loaded = loaded()
  do IO<Unit>:
    require(String.eq(capture(loaded),"7|500|24|codex|/synthetic/repository|assistant|2026-10-01"),"Tools success retains exact captured identity scope and raw cursor")
    require(String.eq(UI.reader(ui(loaded)),Json.get(first(),"text")),"Tools renders exact worker evidence with Unicode and citations")
    require(String.contains(UI.title(ui(loaded)),"500+40/582 records"),"Tools title exposes physical selected range and total")
    require(String.eq(wanted(Gui.paging(loaded,True{})),"activity-scope|7|540|40|codex|/synthetic/repository|assistant|2026-10-01"),"Tools Next uses verified physical next cursor")
    require(String.eq(wanted(Gui.paging(loaded,False{})),"activity-scope|7|460|40|codex|/synthetic/repository|assistant|2026-10-01"),"Tools Previous preserves captured scope")

def eof() -> IO(Unit):
  +last = Gui.read_current(loaded(),request(580),Gui.Reply{Done{page(580,2,Json.JNull{})}},True{})
  do IO<Unit>:
    require(String.contains(UI.title(ui(last)),"580+2/582 records"),"short Tools EOF page shows actual physical range")
    require(String.eq(wanted(Gui.paging(last,True{})),"none") && String.contains(status(Gui.paging(last,True{})),"No further Tools page"),"Tools EOF does not request beyond captured extent")
    require(String.eq(wanted(Gui.paging(last,False{})),"activity-scope|7|540|40|codex|/synthetic/repository|assistant|2026-10-01"),"Tools Previous remains available at EOF")

def empty_ranges() -> IO(Unit):
  +empty = Gui.read_current(state(),request(700),Gui.Reply{Done{page(700,0,Json.JNull{})}},True{})
  do IO<Unit>:
    require(String.contains(UI.title(ui(empty)),"700+0/582 records") && String.contains(capture(empty),"7|700|24"),"Tools accepts truthful empty range when prior transcript paged beyond EOF")
    require(String.eq(wanted(Gui.paging(empty,True{})),"none"),"empty Tools EOF cannot advance further")
    require(Gui.tools_valid(state(),request(0),replace(page(0,0,Json.JNull{}),"total_records",Json.JNumber{"0"})),"empty captured snapshot has a valid zero-record Tools view")
    require(Gui.tools_valid(state(),request(4294967295),page(4294967295,0,Json.JNull{})),"Tools beyond-EOF checks do not overflow U32 start")

def valid(value: Json.Json) -> Bool:
  Gui.tools_valid(state(),request(500),value)

def protocol_identity() -> IO(Unit):
  do IO<Unit>:
    require(valid(first()),"Tools protocol accepts exact typed immutable response")
    require(Bool.not(valid(replace(first(),"snapshot",Json.JString{"8"}))),"Tools rejects another snapshot")
    require(valid(first()) && Bool.not(valid(replace(first(),"source",Json.JNumber{"2"}))) && Bool.not(valid(replace(first(),"source",Json.JString{"relative.jsonl"}))),"Tools source identity is a typed absolute Unicode locator")
    require(Bool.not(valid(replace(first(),"generation",Json.JString{"0"}))) && Bool.not(valid(replace(first(),"snapshot",Json.JNumber{"7"}))),"Tools generation and snapshot require positive typed SQLite IDs")
    require(Bool.not(valid(replace(first(),"extent",Json.JString{"4294967296"}))),"Tools rejects extent beyond raw byte representation")
    require(Bool.not(valid(replace(first(),"provider",Json.JString{"other"}))),"Tools rejects unsupported actual provider")
    require(Bool.not(valid(replace(first(),"scope",scope(Gui.empty_filters())))),"Tools rejects changed scope")
    require(Bool.not(valid(replace(first(),"text",Json.JNull{}))),"Tools rejects missing evidence text")
    require(Bool.not(valid(replace(first(),"kind",Json.JString{"repository_source"}))),"Tools rejects file-shaped worker results")

def protocol_range() -> IO(Unit):
  do IO<Unit>:
    require(Bool.not(valid(replace(first(),"start",Json.JNumber{"501"}))),"Tools rejects wrong raw start")
    require(Bool.not(valid(replace(first(),"requested_count",Json.JNumber{"100"}))),"Tools rejects changed page budget")
    require(Bool.not(valid(replace(first(),"selected_count",Json.JNumber{"39"}))),"Tools refuses truncated nonterminal physical ranges")
    require(Bool.not(valid(replace(first(),"verified_count",Json.JNumber{"0"}))),"Tools requires each selected matching-provider record verified")
    require(Bool.not(valid(replace(first(),"next",Json.JNumber{"541"}))) && Bool.not(valid(replace(first(),"next",Json.JNull{}))),"Tools rejects wrong or premature terminal cursors")
    require(Bool.not(valid(replace(first(),"total_records",Json.JNumber{"499"}))) && Bool.not(valid(replace(first(),"total_records",Json.JNumber{"4294967296"}))),"Tools rejects inconsistent or overflowing record totals")
    require(Bool.not(valid(replace(first(),"selected_count",Json.JString{"40"}))),"Tools numeric metadata cannot be string-coerced")

def failures() -> IO(Unit):
  +before = loaded()
  do IO<Unit>:
    require(String.eq(UI.reader(ui(Gui.read_current(before,request(540),Gui.Reply{Done{page(540,40,Json.JNumber{"580"})}},False{}))),UI.reader(ui(before))),"stale Tools ticket cannot replace visible evidence")
    require(String.eq(UI.reader(ui(Gui.read_current(before,request(540),Gui.Reply{Done{replace(page(540,40,Json.JNumber{"580"}),"generation",Json.JString{"4"})}},True{}))),UI.reader(ui(before))),"Tools paging refuses immutable generation drift")
    require(String.contains(status(Gui.read_current(before,request(540),Gui.Reply{Fail{"verified-rebuild-needed"}},True{})),"verified-rebuild-needed") &&
      String.eq(UI.reader(ui(Gui.read_current(before,request(540),Gui.Reply{Fail{"verified-rebuild-needed"}},True{}))),UI.reader(ui(before))),"Tools verification failures preserve old reader and actionable error")

def transitions() -> IO(Unit):
  +loaded = loaded()
  do IO<Unit>:
    require(String.eq(wanted(Gui.why(loaded)),"why-scope|7|500|20|codex|/synthetic/repository|assistant|2026-10-01"),"Why from Tools preserves snapshot start and frozen scope")
    require(String.eq(wanted(Gui.usage(loaded)),"none") && String.contains(status(Gui.usage(loaded)),"would widen this repository, role or date scope") &&
      String.eq(UI.reader(ui(Gui.usage(loaded))),UI.reader(ui(loaded))),"Usage from scoped Tools refuses widening and retains displayed evidence")
    require(String.eq(wanted(Gui.usage(with_filters(loaded,Gui.empty_filters()))),"session-usage|7") &&
      String.eq(capture(Gui.usage_restore(Gui.usage(with_filters(loaded,Gui.empty_filters())))),capture(with_filters(loaded,Gui.empty_filters()))),
      "Usage from unfiltered Tools requests whole capture and restores its original physical range")
    require(String.eq(String.join(Gui.export_args(24,"7",500,filters(),UI.reader(ui(loaded)),"/synthetic/evidence.md"),"|"),
      "export-displayed|/synthetic/evidence.md|" ++ UI.reader(ui(loaded))),"Tools export copies exact displayed Unicode evidence without rereading")

def forms() -> IO(Unit):
  do IO<Unit>:
    require(String.contains(status(Gui.tools(Gui.files_enter(loaded()))),"History") && Gui.files_active(Gui.tools(Gui.files_enter(loaded()))),"Tools refuses Files without changing its pinned view")
    require(String.contains(status(Gui.tools(Gui.settings(loaded()))),"History"),"Tools refuses Settings rather than reusing hidden capture selection")
    require(String.contains(status(Gui.tools(Gui.filter_help(loaded()))),"History"),"Tools refuses help text masquerading as a captured reader")
    require(Bool.not(Gui.tools_valid(Gui.files_enter(loaded()),request(500),first())),"Tools response cannot overwrite Files mode")

def provider_scope() -> IO(Unit):
  +mismatch = replace(replace(first(),"provider",Json.JString{"claude"}),"verified_count",Json.JNumber{"0"})
  do IO<Unit>:
    require(valid(mismatch),"provider-mismatched Tools page retains physical range with zero verified matching records")
    require(Bool.not(valid(replace(mismatch,"verified_count",Json.JNumber{"40"}))),"provider mismatch cannot claim matching-record verification")

def reader_transitions() -> IO(Unit):
  +why = Gui.text_done(loaded(),Gui.Request{4,Gui.scoped_args("why-scope","7",500,"20",filters()),"7",500,"Why"},Done{"why evidence"})
  require(String.eq(wanted(Gui.tools(why)),"activity-scope|7|500|40|codex|/synthetic/repository|assistant|2026-10-01"),"Tools from Why retains captured range and filters")

def files_return() -> IO(Unit):
  +restored = Gui.files_leave(Gui.files_enter(Gui.replace_ui(loaded(),UI.set_position(ui(loaded()),0,3))))
  do IO<Unit>:
    require(String.eq(capture(restored),capture(loaded())) && String.eq(UI.reader(ui(restored)),UI.reader(ui(loaded()))),"History return restores exact Tools view and captured identity")
    require(U32.is_eq(UI.scroll(ui(restored)),3),"Files round trip retains Tools scroll position")
    require(String.eq(wanted(Gui.paging(restored,True{})),"activity-scope|7|540|40|codex|/synthetic/repository|assistant|2026-10-01"),"Files round trip retains validated Tools paging metadata")

def main() -> IO(Unit):
  do IO<Unit>:
    opening()
    loaded_view()
    eof()
    empty_ranges()
    protocol_identity()
    protocol_range()
    failures()
    transitions()
    forms()
    provider_scope()
    reader_transitions()
    files_return()
