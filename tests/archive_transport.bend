import Base
import ../src/cli.bend as Cli
import ../src/gui_brief.bend as GuiBrief
import ../src/continuation_brief.bend as Brief
import ../src/brief_cli.bend as BriefCli
import ../src/scoped_reader.bend as Scoped
import ../src/evidence.bend as Evidence
import ../src/sources.bend as Sources
import ../src/maintenance.bend as Maintenance
import ../src/store.bend as Store
import ../src/json.bend as Json
import ../src/query.bend as Query
import ../src/repo_scope.bend as Repo

# Pure focused transport/label checks. Actual archive import, owned-byte
# verification and filesystem publication are covered by the capture harness.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def parsed(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def json(text: String) -> Json.Json:
  parsed(Json.parse(text))

def fields(values: List<&2,Json.Field>,+key: String,+replacement: Json.Json) -> List<&2,Json.Field>:
  match values:
    case []: []
    case Json.JField{+name,old} <> rest:
      Json.JField{name,Bool.pick(Json.Json,String.eq(name,key),replacement,old)} <>
        fields(rest,key,replacement)

def replace(value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{fields(values,key,replacement)}
    case other: other

def remove_fields(values: List<&2,Json.Field>,+key: String) -> List<&2,Json.Field>:
  match values:
    case []: []
    case Json.JField{+name,+value} <> rest:
      List.filter.put(Json.Field,Json.JField{name,value},remove_fields(rest,key),Bool.not(String.eq(name,key)))

def remove(value: Json.Json,key: String) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{remove_fields(values,key)}
    case other: other

def extra(value: Json.Json,key: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{Json.JField{key,replacement} <> values}
    case other: other

def snapshot() -> String: "9007199254740995"

def response() -> Json.Json:
  json(Cli.scoped_response(Maintenance.Header{"9007199254740993",9000,45,"codex"},
    snapshot(),"40","40",False{},"café 中文 🙂"))

def metadata() -> IO(Unit):
  +reply = response()
  +args = GuiBrief.range_args(reply,snapshot(),40,["activity",snapshot(),"/synthetic/history.jsonl.zst","9007199254740993","9000","codex","45","0","5"])
  do IO<Unit>:
    assert(GuiBrief.range_metadata(reply,snapshot(),40),"actual CLI response matches the closed native range schema")
    assert(String.eq(Json.get(reply,"snapshot"),snapshot()) && String.eq(Json.get(reply,"selected_records"),"5"),
      "archive range metadata preserves wide identity and exact five-record tail")
    assert(String.eq(Json.get(reply,"byte_space"),"logical_source_bytes") && String.eq(Json.get(reply,"text"),"café 中文 🙂"),
      "range names logical bytes and preserves complete Unicode text")
    assert(U32.is_eq(GuiBrief.selected_count(args,snapshot(),40),5) &&
      String.eq(String.join(GuiBrief.metadata_base(args),"|"),"activity|9007199254740995|/synthetic/history.jsonl.zst|9007199254740993|9000|codex|45|0|5"),
      "range transport retains preceding captured-source identity and selection count")
    assert(Bool.not(GuiBrief.range_metadata(remove(reply,"byte_space"),snapshot(),40)),
      "older missing-byte-space response cannot authorize a new Brief anchor")
    assert(Bool.not(GuiBrief.range_metadata(replace(reply,"byte_space",Json.JString{"compressed_container_bytes"}),snapshot(),40)),
      "compressed-container offsets cannot masquerade as transcript offsets")
    assert(Bool.not(GuiBrief.range_metadata(replace(reply,"byte_space",Json.JNumber{"0"}),snapshot(),40)),
      "byte-space type is exact")
    assert(Bool.not(GuiBrief.range_metadata(extra(reply,"byte_space",Json.JString{"logical_source_bytes"}),snapshot(),40)),
      "duplicate byte-space metadata is rejected")
    assert(Bool.not(GuiBrief.range_metadata(extra(reply,"source_encoding",Json.JString{"zstd-jsonl-v1"}),snapshot(),40)),
      "unnegotiated metadata cannot widen the closed native response")
    assert(Bool.not(GuiBrief.range_metadata(replace(reply,"snapshot",Json.JString{"9007199254740994"}),snapshot(),40)),
      "adjacent wide snapshot identity cannot substitute for the frozen range")
    assert(Bool.not(GuiBrief.range_metadata(replace(reply,"selected_records",Json.JNumber{"41"}),snapshot(),40)),
      "selected count cannot exceed requested count")
    assert(Bool.not(GuiBrief.range_metadata(replace(reply,"complete_export",Json.JBool{True{}}),snapshot(),40)),
      "archive page cannot claim a complete export")
    assert(String.eq(Json.get(json(Cli.scoped_response(Maintenance.Header{"3",9000,45,"codex"},snapshot(),"40","40",True{},"why")),"selected_records"),"5"),
      "Why still clamps its selected count to the pinned remaining records")

def candidates() -> IO(Unit):
  do IO<Unit>:
    assert(Sources.candidate("/synthetic/root","/synthetic/root/café 中文 🙂.jsonl.zst"),
      "explicit root admits an archive candidate with Unicode locator")
    assert(Sources.candidate("/synthetic/root","/synthetic/root/plain.jsonl") && Sources.candidate("/synthetic/root","/synthetic/root/plain.json"),
      "plain source extensions remain supported")
    assert(Bool.not(Sources.candidate("/synthetic/root","/synthetic/rootish/history.jsonl.zst")),
      "archive suffix does not widen the explicit directory boundary")
    assert(Bool.not(Sources.candidate("/synthetic/root","/synthetic/root/history.jsonl.zst.tmp")) &&
      Bool.not(Sources.candidate("/synthetic/root","/synthetic/root/history.json.zst")),
      "only the exact JSONL archive suffix is queued")
    assert(Sources.candidate("/","/synthetic/history.jsonl.zst"),
      "explicit slash root keeps its existing candidate boundary")
    assert(Sources.candidate("/synthetic/root","/synthetic/root/" ++ String.repeat("x",4070n) ++ ".jsonl.zst") &&
      Bool.not(Sources.candidate("/synthetic/root","/synthetic/root/" ++ String.repeat("x",4071n) ++ ".jsonl.zst")),
      "archive candidates preserve the exact 4096-scalar path limit")

def input() -> Brief.Input:
  Brief.Input{snapshot(),40,5,Scoped.Scope{"codex","","",""},"/synthetic/repository"}

def failed_outcome(value: Sources.Outcome) -> Bool:
  Sources.Outcome{_,_,ok,snapshot,error} = value
  Bool.not(ok) && String.is_empty(snapshot) && Bool.not(String.is_empty(error))

def errors() -> IO(Unit):
  +path = {"/synthetic/root/history.jsonl.zst" : String}
  do IO<Unit>:
    assert(String.starts_with(Sources.import_error(path,1,"archive_limit: untrusted /private/location"),"archive_limit:") &&
      String.starts_with(Sources.import_error(path,1,"archive_dictionary: untrusted content"),"archive_dictionary:") &&
      String.starts_with(Sources.import_error(path,1,"archive_corrupt: untrusted content"),"archive_corrupt:") &&
      String.starts_with(Sources.import_error(path,1,"archive_changed: untrusted content"),"archive_changed:"),
      "fixed archive worker prefixes become bounded actionable failures")
    assert(Bool.not(String.contains(Sources.import_error(path,1,"archive_limit: untrusted /private/location"),"/private/location")) &&
      Bool.not(String.contains(Sources.import_error(path,1,"unknown /private/location raw transcript"),"/private/location")),
      "neither recognized nor unknown worker stderr leaks its free-form body")
    assert(String.starts_with(Sources.import_error(path,2,"untrusted archive_limit: text"),"Import worker exited 2") &&
      String.starts_with(Sources.import_error("/synthetic/plain.jsonl",2,"archive_limit: text"),"Import worker exited 2"),
      "nonprefix markers and plain-source stderr retain generic failures")
    assert(failed_outcome(Sources.import_exited("codex",path,1,"{\"accepted_snapshot\":\"7\"}","archive_corrupt: checksum")),
      "failed archive worker cannot promote a snapshot from its stdout")
    assert(failed_outcome(Sources.import_exited("codex",path,0,"not JSON","archive_changed: ignored")),
      "successful process exit without valid acceptance JSON remains a failure")

def anchor() -> Brief.Anchor:
  Brief.Anchor{input(),Repo.Scope{"/synthetic/repository","/synthetic/repository",["/synthetic/repository"]},
    "codex","/synthetic/history.jsonl.zst","9007199254740993",9000,45}

def accepted(value: Result<&2,&2,Brief.Problem,BriefCli.Command>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def labels() -> IO(Unit):
  +gui = {GuiBrief.Anchor{snapshot(),40,5,Query.Filters{"","codex","","",""}} : GuiBrief.Anchor}
  +heading = Brief.header(anchor(),Brief.Missing{0})
  +reader = Scoped.rendered(Scoped.Output{Store.Context{"","","",""},0,[]},snapshot(),40,40,Scoped.Scope{"codex","","",""},False{})
  +wire = GuiBrief.body(GuiBrief.Model{gui,"/synthetic/repository",0,1,None{},GuiBrief.Whole{}})
  +citation = Evidence.citation(Evidence.Verified{"codex","/synthetic/history.jsonl.zst","9007199254740993",snapshot(),"9000","40",[]},2)
  do IO<Unit>:
    assert(String.contains(GuiBrief.guidance(gui),"captured records 40 + 5") &&
      String.contains(GuiBrief.guidance(gui),"logical source bytes (decompressed for archives)"),
      "native Brief guidance describes the exact captured range and logical byte space")
    assert(String.contains(heading,"captured-record range 40+5") && String.contains(heading,"source record/event order") &&
      String.contains(heading,"decompressed for archives") && Bool.not(String.contains(heading,"physical")),
      "Brief body does not describe archive records as physical JSONL")
    assert(String.contains(Brief.anchor_text(anchor()),"logical_source_bytes") &&
      String.contains(Brief.anchor_text(anchor()),"9007199254740995"),
      "Brief anchor serialization binds logical byte space and exact wide identity")
    assert(String.eq(wire,BriefCli.prepare_request(input())) && accepted(BriefCli.parse("brief-prepare",wire)),
      "existing Brief request protocol remains synchronized without a new required field")
    assert(String.contains(reader,"captured record start 40") && String.contains(reader,"logical source bytes") &&
      Bool.not(String.contains(reader,"physical")),"scoped reader labels captured record order independently of container offsets")
    assert(String.eq(Json.get(json(citation),"snapshot"),snapshot()) && String.eq(Json.get(json(citation),"extent"),"9000") &&
      String.eq(Json.get(json(citation),"source"),"/synthetic/history.jsonl.zst") && String.eq(Json.get(json(citation),"event"),"2"),
      "existing citation tuple keeps the physical locator and logical extent without numeric coercion")

def main() -> IO(Unit):
  do IO<Unit>:
    metadata()
    candidates()
    errors()
    labels()
