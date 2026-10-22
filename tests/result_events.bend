import Base
import ./result_links.bend as T
import ../src/result_events.bend as E
import ../src/result_events_cli.bend as EC
import ../src/result_links.bend as Links
import ../src/result_links_cli.bend as LC
import ../src/gui_result_links.bend as G
import ../src/gui_relations.bend as GR
import ../src/gui_files.bend as F
import ../src/relations.bend as R
import ../src/scoped_reader.bend as Scoped
import ../src/query.bend as Q
import ../src/json.bend as J
import ../src/store.bend as Store
import ../src/sql.bend as Sql

def filters() -> Q.Filters:
  Q.Filters{"","claude","/synthetic/repo","tool","2026-10-20"}

def scope() -> Scoped.Scope:
  Scoped.Scope{"claude","/synthetic/repo","tool","2026-10-20"}

def parsed(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(value: String) -> J.Json:
  parsed(J.parse(value))

def replace_fields(values: List<&2,J.Field>,+key: String,+value: J.Json) -> List<&2,J.Field>:
  match values:
    case []: []
    case J.JField{+name,old} <> rest:
      J.JField{name,Bool.pick(J.Json,String.eq(name,key),value,old)} <> replace_fields(rest,key,value)

def replace(value: J.Json,key: String,replacement: J.Json) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{replace_fields(values,key,replacement)}
    case _: value

def list_ok(+value: J.Json,snapshot: String,cursor: G.Cursor) -> Bool:
  G.list_valid(value,snapshot,0,4,cursor,filters())

def inspect_first(+page: E.Page,+snapshot: String) -> IO(Unit):
  E.Page{_,_,_,record,event,next,slot,more,scanned,_,unavailable,_,+rows} = page
  +value = json(EC.json(page))
  do IO<Unit>:
    T.assert(U32.is_eq(record,0) && U32.is_eq(event,0) && U32.is_eq(next,2) && U32.is_eq(slot,20),"dense raw result record resumes at exact unconsumed content slot")
    T.assert(more && U32.is_eq(scanned,3) && U32.is_eq(unavailable,0),"result-list record budget and continuation are explicit")
    T.assert(Nat.is_eq(List.length(&2,E.ResultEvent,rows),20n),"twenty typed results cap a page; citation-looking plain text adds no row")
    T.assert(list_ok(value,snapshot,G.Cursor{0,0}),"native event envelope passes strict GUI protocol")
    T.assert(Bool.not(list_ok(replace(value,"more",J.JString{"true"}),snapshot,G.Cursor{0,0})),"string boolean cannot authorize continuation")
    T.assert(Bool.not(list_ok(replace(value,"next_record",J.JNumber{"0"}),snapshot,G.Cursor{0,0})),"returned cursor cannot precede emitted rows")
    T.assert(Bool.not(list_ok(replace(value,"scope",replace(J.field(value,"scope"),"role",J.JString{"user"})),snapshot,G.Cursor{0,0})),"result list cannot widen frozen tool-role filter")
    T.assert(Bool.not(list_ok(replace(value,"reference",replace(J.field(value,"reference"),"snapshot",J.JString{"999"})),snapshot,G.Cursor{0,0})),"result list snapshot must match request")

def count(page: E.Page) -> U32:
  E.Page{_,_,_,_,_,_,_,_,_,_,_,_,rows} = page
  U32.from_nat(List.length(&2,E.ResultEvent,rows))

def second(+page: E.Page,+snapshot: String) -> IO(Unit):
  E.Page{_,_,_,_,_,next,slot,more,_,_,_,_,_} = page
  +value = json(EC.json(page))
  do IO<Unit>:
    T.assert(U32.is_eq(count(page),2) && U32.is_eq(next,4) && U32.is_eq(slot,0) && Bool.not(more),"dense record tail and following standalone result remain reachable")
    T.assert(list_ok(value,snapshot,G.Cursor{2,20}),"resumed raw cursor passes strict GUI contract")
    T.assert(Bool.not(list_ok(replace(value,"next_record",J.JNumber{"1"}),snapshot,G.Cursor{2,20})),"terminal cursor cannot regress")
    T.assert(Bool.not(list_ok(replace(value,"next_event",J.JNumber{"1"}),snapshot,G.Cursor{2,20})),"terminal event cursor must end at record boundary")

def page(+db: U32,snapshot: String,start: U32,count: U32,record: U32,event: U32,scope: Scoped.Scope) -> IO(E.Page):
  do IO<E.Page>:
    value : Result<&2,&2,String,E.Page> <- E.page(db,snapshot,start,count,record,event,scope)
    T.need(E.Page,value)

def negative_rows(+value: J.Json,+reference: GR.Reference,+selected: G.ResultEvent,rows: List<&2,J.Json>) -> IO(Unit):
  match rows:
    case []: IO.die(Unit,1,"FAIL synthetic child candidate missing")
    case +head <> _:
      +target = J.field(head,"target")
      +bad = replace(head,"target",replace(target,"session",J.JObject{[J.JField{"kind",J.JString{"conflicting"}},J.JField{"reason",J.JString{"synthetic conflict"}}]}))
      +self_selected = replace(J.field(value,"selected"),"reference",J.field(target,"reference"))
      +self_row = replace(head,"witness",J.field(target,"reference"))
      +alias = replace(head,"target",replace(target,"reference",replace(J.field(target,"reference"),"source",
        J.JString{J.get(J.field(target,"reference"),"source") ++ ".alias"})))
      do IO<Unit>:
        T.assert(Bool.not(G.candidate_valid(self_row,self_selected,"100","/synthetic/repo",False{})),"child result cannot navigate to its own retained source")
        T.assert(Bool.not(G.candidate_page_valid(replace(value,"rows",J.JArray{[alias]}),reference,selected,filters(),"","0")),"filename alias cannot replace literal retained child locator")
        T.assert(Bool.not(G.candidate_page_valid(replace(value,"rows",J.JArray{[head,head]}),reference,selected,filters(),"","0")),"multiple page candidates require explicit ambiguity and bounded source count")
        T.assert(Bool.not(G.candidate_page_valid(replace(replace(value,"coverage",replace(J.field(value,"coverage"),"partial",J.JNumber{"1"})),"page_metadata_complete",J.JBool{True{}}),reference,selected,filters(),"","0")),"partial raw prefix cannot claim page metadata complete")
        T.assert(Bool.not(G.candidate_page_valid(replace(value,"selected",replace(J.field(value,"selected"),"facts",replace(J.field(J.field(value,"selected"),"facts"),"parent",J.JObject{[J.JField{"kind",J.JString{"unsupported"}},J.JField{"reason",J.JString{"bad parent"}}]}))),reference,selected,filters(),"","0")),"unsupported selected parent cannot authorize a candidate")
        T.assert(Bool.not(G.candidate_page_valid(replace(value,"rows",J.JArray{[bad]}),reference,selected,filters(),"","0")),"forged conflicting child metadata cannot authorize target")
        T.assert(Bool.not(G.candidate_page_valid(replace(value,"rows",J.JArray{[replace(head,"basis",J.JString{"retained_path_association"})]}),reference,selected,filters(),"","0")),"result navigation cannot borrow Related path-only basis")

def candidates(+page: Links.Page,reference: R.SnapshotRef) -> IO(Unit):
  +value = json(LC.json(page))
  +selected = G.event(J.field(value,"selected"))
  +actual = GR.reference(J.field(J.field(value,"selected"),"reference"))
  +rows = J.items(J.field(value,"rows"))
  do IO<Unit>:
    T.assert(G.candidate_page_valid(value,actual,selected,filters(),"","0"),"selected late ordinal candidate envelope validates separately from prefix facts")
    T.assert(Bool.not(G.candidate_page_valid(replace(value,"selected",replace(J.field(value,"selected"),"event",J.JNumber{"1"})),actual,selected,filters(),"","0")),"candidate response cannot substitute another event")
    T.assert(Bool.not(G.candidate_page_valid(replace(value,"selected",replace(J.field(value,"selected"),"citation",replace(J.field(J.field(value,"selected"),"citation"),"record",J.JString{"0"}))),actual,selected,filters(),"","0")),"candidate selected citation must retain exact raw ordinal")
    negative_rows(value,actual,selected,rows)

def bounded(page: E.Page) -> Bool:
  E.Page{_,_,_,_,_,next,_,more,scanned,_,_,_,rows} = page
  U32.is_eq(next,10) && U32.is_eq(scanned,10) && more && List.is_empty(&2,E.ResultEvent,rows)

def repeat(+value: String,count: Nat) -> String:
  match count:
    case 0n: ""
    case 1n: value
    case 1n+rest: value ++ "," ++ repeat(value,rest)

def suite() -> IO(Unit):
  do IO<Unit>:
    T.fixture("/bin/mkdir",["-p",".build/events/subagents"])
    +db : U32 <- Store.open(".build/result-events.sqlite")
    +snapshot : String <- T.capture(db,"claude",".build/events.jsonl",T.metadata("parent","/synthetic/repo") ++
      "{\"type\":\"user\",\"message\":{\"content\":\"tool_result agentId abc record 3 event 0\"}}\n" ++
      T.result_record("\"abc\"",repeat(T.result_block(),21n)) ++ T.result_record("\"abc\"",T.result_block()))
    +reference : R.SnapshotRef <- T.reference(db,snapshot)
    child : String <- T.capture(db,"claude",".build/events/subagents/agent-abc.jsonl",T.metadata("parent","/synthetic/repo"))
    first : E.Page <- page(db,snapshot,0,4,0,0,scope())
    inspect_first(first,snapshot)
    T.fixture("/bin/rm",[".build/events.jsonl",".build/events/subagents/agent-abc.jsonl"])
    tail : E.Page <- page(db,snapshot,0,4,2,20,scope())
    second(tail,snapshot)
    filtered : E.Page <- page(db,snapshot,0,4,0,0,Scoped.Scope{"claude","/synthetic/repo","user",""})
    T.assert(U32.is_eq(count(filtered),0),"tool results do not become human requests under user filter")
    different : E.Page <- page(db,snapshot,0,4,0,0,Scoped.Scope{"claude","/other/repo","tool",""})
    T.assert(U32.is_eq(count(different),0),"retained context enforces repository filter")
    later : E.Page <- page(db,snapshot,0,4,0,0,Scoped.Scope{"claude","/synthetic/repo","tool","2027-01-01"})
    T.assert(U32.is_eq(count(later),0),"event date scope remains exact")
    linked : Links.Page <- T.open(db,reference,3,0,scope(),15)
    candidates(linked,reference)
    +long : String <- T.capture(db,"claude",".build/long.jsonl",String.repeat("{}\n",40n))
    limited : E.Page <- page(db,long,0,40,0,0,Scoped.Scope{"","","",""})
    T.assert(bounded(limited),"record traversal stops at ten physical records and preserves forward cursor")
    invalid : Result<&2,&2,String,E.Page> <- E.page(db,snapshot,0,41,0,0,scope())
    T.assert(T.failure(E.Page,invalid,"bounded range"),"range cannot exceed displayed forty-record profile")
    terminal : Result<&2,&2,String,E.Page> <- E.page(db,snapshot,0,4,4,1,scope())
    T.assert(T.failure(E.Page,terminal,"cursor inside"),"terminal range cursor cannot name an unconsumed event")
    Store.exec(db,"BEGIN",[])
    busy : Result<&2,&2,String,E.Page> <- E.page(db,snapshot,0,4,0,0,scope())
    T.assert(T.failure(E.Page,busy,"transaction"),"event list refuses caller-owned transaction")
    Store.exec(db,"ROLLBACK",[])
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  suite()
