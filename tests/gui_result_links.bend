import Base
import ./gui_relations.bend as T
import ./result_events.bend as ETest
import ../src/gui.bend as Gui
import ../src/gui_result_links.bend as G
import ../src/gui_files.bend as F
import ../src/ui.bend as UI
import ../src/query.bend as Q
import ../src/json.bend as J
import ../src/result_events.bend as E
import ../src/result_events_cli.bend as EC
import ../src/result_links.bend as L
import ../src/result_links_cli.bend as LC
import ../src/result_link.bend as Link
import ../src/relations.bend as R
import ../src/scoped_reader.bend as Scoped

def filters() -> Q.Filters:
  Q.Filters{"","claude","/synthetic/repo","tool","2026-10-20"}

def scope() -> Scoped.Scope:
  Scoped.Scope{"claude","/synthetic/repo","tool","2026-10-20"}

def ref() -> R.SnapshotRef:
  R.SnapshotRef{"claude","/synthetic/parent.jsonl","3","7","90000"}

def child() -> R.SnapshotRef:
  R.SnapshotRef{"claude","/synthetic/parent/subagents/agent-abc.jsonl","4","9","90000"}

def events() -> J.Json:
  ETest.json(EC.json(E.Page{ref(),40,5,40,0,45,0,False{},5,100,0,scope(),
    [E.ResultEvent{41,1,Link.Agent{"abc","t1"},E.citation(ref(),41,1)}]}))

def facts(reference: R.SnapshotRef,+ordinal: U32,inspected: U32) -> R.Facts:
  R.Facts{reference,R.Known{"parent",ordinal},R.Known{"/synthetic/repo",ordinal},R.UnknownParent{},inspected,45,100,False{},"bounded retained metadata"}

def candidates() -> J.Json:
  ETest.json(LC.json(L.Page{L.Selected{ref(),41,1,scope(),Link.Agent{"abc","t1"},facts(ref(),41,1),E.citation(ref(),41,1),100},
    "100","0",None{},15,1,3,200,R.Coverage{0,0,0,1,0},
    [R.Row{facts(child(),0,2),"child","recorded_tool_result_agent_id",ref(),Some{41},False{}}]}))

def origin_ui() -> UI.State:
  UI.set_edit(UI.set_position(UI.set_results(UI.set_rows(UI.set_scope(UI.set_reader(UI.set_query(UI.init(),
    "needle role:tool"),"Tools | snapshot 7","Original reader café 中文 🙂\nimmutable text"),"claude"),["first","chosen"]),
    UI.Results{100,2,True{},True{}}),1,7),UI.Edit{2,19,4,False{},0})

def origin_selection() -> Gui.Selection:
  Gui.Selection{[],"7",40,24,["activity","7","/synthetic/parent.jsonl","3","90000","claude","45","0","5"],
    filters(),Gui.Listing{2,Q.Filters{"needle","claude","/synthetic/repo","tool","2026-10-20"},100,True{},True{},""}}

def origin() -> Gui.State:
  Gui.State{0,"/tmp/juice-bend-child-ui-tests","/usr/bin/false",origin_ui(),origin_selection(),
    Gui.Form{0,"needle role:tool","","",F.empty(),[],[]},Gui.Jobs{9,None{},None{},None{},False{}},60000n,0}

def apply(+state: Gui.State,value: J.Json) -> Gui.State:
  Gui.read_current(state,T.request(state),Gui.Reply{Done{value}},True{})

def event_state() -> Gui.State:
  apply(Gui.child_enter(origin()),events())

def candidate_state() -> Gui.State:
  apply(Gui.child_open(event_state(),0),candidates())

def pending_target() -> Gui.State:
  Gui.child_open(candidate_state(),0)

def transcript() -> J.Json:
  ETest.json("{\"snapshot\":\"9\",\"start\":0,\"requested_records\":40,\"selected_records\":2,\"kind\":\"scoped_transcript_page\",\"byte_space\":\"logical_source_bytes\",\"complete_export\":false,\"text\":\"Retained child transcript\"}")

def phase(value: Gui.Navigation) -> U32:
  match value:
    case Gui.ChildNavigation{_,_,_,G.Model{phase,_,_,_,_,_,_},_,_}: phase
    case _: 99

def child_action(value: UI.State & UI.Action) -> Bool:
  (_,action) = value
  match action:
    case UI.ChildResultsOpen{}: True{}
    case _: False{}

# One-slot recursive boxes prevent three full State temporaries from remaining
# live in a generated continuation. The same production Back calls still run.
def back_box(value: List<&2,Gui.State>) -> List<&2,Gui.State>:
  match value:
    case Con{state,Nil{}}: [Gui.child_back(state)]
    case _: []

def observation_box(value: List<&2,Gui.State>) -> String:
  match value:
    case Con{state,Nil{}}: T.captured_observation(state)
    case _: "MISSING_BOXED_CHILD_STATE"

def restored() -> String:
  observation_box(back_box(back_box(back_box([apply(pending_target(),transcript())]))))

def origin_observation() -> String:
  T.captured_observation(origin())

def rejected(value: J.Json) -> Bool:
  +state = apply(pending_target(),value)
  String.eq(UI.reader(T.ui(state)),J.get(candidates(),"text")) && U32.is_eq(phase(Gui.navigation(state)),2)

def assertions() -> IO(Unit):
  do IO<Unit>:
    T.require(UI.child_entry_visible(origin_ui()),"Child results button is visible in captured Tools chrome")
    T.require(child_action(UI.mouse(origin_ui(),1060,12,True{})),"Child results header button hit test emits explicit typed action")
    T.require(String.eq(T.wanted(Gui.child_enter(origin())),"result-link-events|7|40|5|40|0|claude|/synthetic/repo|tool|2026-10-20"),"entry freezes exact range and full scope")
    T.require(U32.is_eq(phase(Gui.navigation(event_state())),0),"typed event response reaches selectable result list")
    T.require(String.eq(T.wanted(Gui.child_open(event_state(),0)),"result-link-page|claude|/synthetic/parent.jsonl|3|7|90000|41|1||0|15|claude|/synthetic/repo|tool|2026-10-20"),"result selection freezes raw record and event citation")
    T.require(U32.is_eq(phase(Gui.navigation(candidate_state())),1),"separate child candidate envelope reaches candidate list")
    T.require(String.eq(T.wanted(pending_target()),"session-scope|9|0|40|claude|/synthetic/repo|tool|2026-10-20"),"target reader receives exact captured target and original filters")
    T.require(rejected(ETest.replace(transcript(),"snapshot",J.JString{"8"})),"wrong target snapshot cannot replace candidate text")
    T.require(rejected(ETest.replace(transcript(),"start",J.JNumber{"1"})),"wrong target range cannot replace candidate text")
    T.require(rejected(ETest.replace(transcript(),"kind",J.JString{"session"})),"wrong target envelope kind cannot replace candidate text")
    T.require(rejected(ETest.json("{\"text\":\"forged transcript\"}")),"text alone cannot authorize child target transition")
    T.require(U32.is_eq(phase(Gui.navigation(apply(pending_target(),transcript()))),3),"valid bounded transcript reaches captured child reader")
    +actual : String <- IO.pure(String,restored())
    +expected : String <- IO.pure(String,origin_observation())
    T.require(String.eq(actual,expected),"Back through target candidates and results restores original text selection scope and list position")


def main() -> IO(Unit):
  assertions()
