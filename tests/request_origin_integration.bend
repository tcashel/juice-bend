import Base
import ../src/actors.bend as A
import ../src/evidence.bend as E
import ../src/file_evidence.bend as F
import ../src/provenance.bend as P
import ../src/request_evidence.bend as R
import ../src/request_origin.bend as O
import ../src/providers.bend as Providers
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/maintenance.bend as Maintenance
import ../src/paths.bend as Paths

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def parsed(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{raw}: raw
    case Fail{_}: Json.JNull{}

def claude(id: String,meta: String,content: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(id) ++
    ",\"cwd\":\"/synthetic/request\"," ++ meta ++ "\"message\":{\"content\":" ++ content ++ "}}\n"

def message(id: String,text: String) -> String:
  claude(id,"",Json.quote(text))

def codex_meta(id: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":" ++ Json.quote(id) ++
    ",\"cwd\":\"/synthetic/request\",\"source\":\"cli\"}}\n"

def codex(text: String) -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":" ++ Json.quote(text) ++ "}]}}\n"

def capture(+db: U32,provider: String,+path: String,text: String) -> IO(String):
  do IO<String>:
    Store.write_text(path,"w",text)
    Store.import_file(db,provider,path)

def actor(+db: U32,provider: String,+snapshot: String,count: U32) -> IO(A.Actor):
  do IO<A.Actor>:
    value : A.Actor <- A.scan(U32.to_nat(U32.min(count,16)),db,snapshot,0,
      A.empty(provider,"/synthetic/source.jsonl",snapshot))
    return A.complete_actor(value)

def exact(+value: A.Actor) -> String:
  P.attribution_name(F.commit_identity("/synthetic/request",
    Bool.pick(String,String.eq(A.provider(value),"claude"),"Claude-Session: ","Codex-Session: ") ++
      A.session(value),[value]))

def blocked(actor: A.Actor) -> String:
  A.Actor{_,_,_,_,_,_,_,_,reason} = actor
  reason

def key_field(+value: A.Actor,key: String) -> String:
  Json.get(parsed(Json.parse(A.key(value))),key)

def read_closed(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,bytes) = result
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,bytes))

def bytes(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    read : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65536)
    read_closed(read)

def resolved(result: Result<&2,&2,String,String>) -> String:
  match result:
    case Done{text}: text
    case Fail{error}: "ERROR: " ++ error

def moved_ok(result: U32 & (String & String)) -> Bool:
  (code,_) = result
  U32.is_eq(code,0)

def reject_case(+db: U32,+id: String,first: String,needle: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"claude",id ++ ".jsonl",first ++ message(id,"Later legitimate-looking request"))
    +value : A.Actor <- actor(db,"claude",snapshot,2)
    assert(String.eq(exact(value),"not_indexed"),id ++ " cannot establish exact trailer evidence")
    assert(String.contains(blocked(value),needle),id ++ " retains explicit ineligibility reason")

def negative(+db: U32) -> IO(Unit):
  do IO<Unit>:
    reject_case(db,"bad-meta",claude("bad-meta","\"isMeta\":\"true\",",Json.quote("Do work")),"uncertain")
    reject_case(db,"empty-meta",claude("empty-meta","\"isMeta\":null,",Json.quote("")),"isMeta is malformed")
    reject_case(db,"open-wrapper",message("open-wrapper","<system-reminder>unclosed request"),"uncertain")
    reject_case(db,"wrong-close",message("wrong-close","<system-reminder>x</user_instructions>Do work"),"uncertain")
    reject_case(db,"numeric-text",claude("numeric-text","","[{\"type\":\"text\",\"text\":42}]"),"malformed")
    reject_case(db,"null-text",claude("null-text","","[{\"type\":\"text\",\"text\":null}]"),"malformed")
    reject_case(db,"invalid-json","{unparseable}\n","not a decoded object")
    reject_case(db,"nonobject","[]\n","not a decoded object")
    reject_case(db,"diagnostic-tail",message("diagnostic-tail","<system-reminder>context</system-reminder>## Diagnostic review"),"diagnostic-style")
    reject_case(db,"marker-context",message("marker-context","<system-reminder>[juice:benchmark-synthetic:v1]</system-reminder>Do work"),"synthetic")

def skipped(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +context : String <- capture(db,"claude","context.jsonl",message("context-only","<environment_context>captured context</environment_context>"))
    +context_actor : A.Actor <- actor(db,"claude",context,1)
    assert(String.eq(exact(context_actor),"not_indexed") && String.is_empty(A.key(context_actor)),
      "context-only user record cannot become request or exact trailer evidence")
    +relay : String <- capture(db,"claude","relay.jsonl",message("relay-only","<teammate-message>Relay request</teammate-message>"))
    +relay_actor : A.Actor <- actor(db,"claude",relay,1)
    assert(String.eq(exact(relay_actor),"not_indexed") && String.is_empty(A.key(relay_actor)),
      "closed relay is preserved but cannot provide recorded request")
    +meta : String <- capture(db,"claude","meta.jsonl",claude("meta-session","\"isMeta\":true,",Json.quote("Metadata command")) ++
      message("meta-session","Later recorded request"))
    +meta_actor : A.Actor <- actor(db,"claude",meta,2)
    assert(String.eq(exact(meta_actor),"exact") && String.eq(key_field(meta_actor,"record"),"1") &&
      String.eq(A.request_preview(meta_actor),"Later recorded request"),
      "typed Claude metadata cannot claim intent but later recorded request can qualify")
    +page : String <- Store.page(db,meta,0,2)
    assert(String.contains(page,"Metadata command") && String.contains(page,"Later recorded request"),
      "metadata request remains readable in unchanged transcript")

def wrapped() -> String:
  "<system-reminder>retained context</system-reminder>\n  Fix café 😀 safely. \n"

def array_content() -> String:
  "[{\"type\":\"image\",\"source\":{\"type\":\"synthetic\"}},{\"type\":\"text\",\"text\":" ++ Json.quote(wrapped()) ++ "}]"

def initial() -> String:
  message("wrapped-session","<environment_context>context only</environment_context>") ++
    claude("wrapped-session","",array_content())

def retained_checks(+db: U32,+snapshot: String,+key: String,+signature: String) -> IO(Unit):
  do IO<Unit>:
    +value : A.Actor <- actor(db,"claude",snapshot,2)
    assert(String.eq(A.key(value),key) && String.eq(exact(value),"exact"),
      "old snapshot retains the same exact request citation after source mutation")
    quote : Result<&2,&2,String,String> <- E.resolve_citation(db,key)
    assert(String.contains(resolved(quote),wrapped()),"old citation resolves complete wrapped witness from owned raw")
    after : String <- Store.projection_digest(db,snapshot)
    assert(String.eq(after,signature),"actor read does not change normalized projection")

def retained(+db: U32,+snapshot: String,+value: A.Actor) -> IO(Unit):
  do IO<Unit>:
    +signature : String <- Store.projection_digest(db,snapshot)
    Maintenance.export_raw(db,snapshot,"before.raw")
    before : List<&2,U32> <- bytes("before.raw")
    assert(Domain.bytes_equal(before,Domain.encode(initial())),"owned raw export exactly matches original JSONL bytes")
    Store.write_text("wrapped.jsonl","a",message("wrapped-session","A later request"))
    +appended : String <- Store.import_file(db,"claude","wrapped.jsonl")
    +new_actor : A.Actor <- actor(db,"claude",appended,3)
    assert(String.eq(A.request_preview(new_actor),A.request_preview(value)) &&
      String.eq(key_field(new_actor,"record"),"1") && String.eq(key_field(new_actor,"event"),"1") &&
      Bool.not(String.eq(A.key(new_actor),A.key(value))),
      "append retains physical and event ordinals with a distinct snapshot citation")
    +fresh : String <- capture(db,"claude","fresh.jsonl",initial() ++ message("wrapped-session","A later request"))
    +fresh_actor : A.Actor <- actor(db,"claude",fresh,3)
    assert(String.eq(A.request_preview(fresh_actor),A.request_preview(new_actor)) &&
      String.eq(key_field(fresh_actor,"record"),key_field(new_actor,"record")) &&
      String.eq(key_field(fresh_actor,"event"),key_field(new_actor,"event")),
      "fresh replay and appended capture select equivalent request occurrences")
    assert(String.eq(P.attribution_name(F.commit_identity("/synthetic/request",
      "Claude-Session: wrapped-session",[fresh_actor,new_actor])),"ambiguous"),
      "same session ID across independent captured sources never merges exact evidence")
    retained_checks(db,snapshot,A.key(value),signature)
    Maintenance.rebuild(db,snapshot)
    retained_checks(db,snapshot,A.key(value),signature)
    Store.write_text("wrapped.jsonl","w",message("rewritten-session","Different source generation"))
    rewrite : String <- Store.import_file(db,"claude","wrapped.jsonl")
    retained_checks(db,snapshot,A.key(value),signature)
    moved : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mv",["wrapped.jsonl","source-moved.jsonl"],"",4096,2000))
    assert(moved_ok(moved),"synthetic source relocation succeeds")
    retained_checks(db,snapshot,A.key(value),signature)
    Maintenance.export_raw(db,snapshot,"after.raw")
    after : List<&2,U32> <- bytes("after.raw")
    assert(Domain.bytes_equal(after,Domain.encode(initial())),"append rewrite rebuild and source absence preserve exact old raw bytes")

def positive(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"claude","wrapped.jsonl",initial())
    +value : A.Actor <- actor(db,"claude",snapshot,2)
    assert(String.eq(A.request_preview(value),"\n  Fix café 😀 safely. \n"),
      "supported wrapper exposes exact suffix including whitespace and Unicode")
    assert(String.eq(exact(value),"exact"),"typed wrapped recorded request supports exact scoped trailer association")
    assert(String.eq(key_field(value,"record"),"1") && String.eq(key_field(value,"event"),"1") &&
      String.eq(key_field(value,"snapshot"),snapshot),"context and attachment events do not shift immutable citation ordinals")
    +witness : E.Verified <- E.read_record(db,snapshot,1)
    assert(String.eq(E.citation(witness,1),A.key(value)),"selected descriptor equals unchanged production evidence citation")
    +why : String <- F.actor_context(Some{value},[value],db,"/synthetic/request")
    assert(String.contains(why,"Recorded request policy: recorded-request-v1") &&
      String.contains(why,"not proof of human authorship") && String.contains(why,"Retained request event excerpt"),
      "Why distinguishes request policy and bounded preview from retained event excerpt")
    assert(String.contains(why,wrapped()) && String.contains(why,A.key(value)),
      "Why retains full wrapped text and exact citation")
    retained(db,snapshot,value)

def long_witness(+db: U32) -> IO(Unit):
  +text = "<system-reminder>" ++ String.repeat("x",3000n) ++ "</system-reminder>Actual suffix after long context"
  do IO<Unit>:
    +snapshot : String <- capture(db,"claude","long.jsonl",message("long-context-session",text))
    +value : A.Actor <- actor(db,"claude",snapshot,1)
    assert(String.eq(exact(value),"exact") && String.eq(A.request_preview(value),"Actual suffix after long context"),
      "long context does not erase the exact eligible request suffix")
    +why : String <- F.actor_context(Some{value},[value],db,"/synthetic/request")
    assert(String.contains(why,"Actual suffix after long context") &&
      String.contains(why,"text, arguments, result: at most 2048 decoded characters each") &&
      Bool.not(String.contains(why,"Full retained")),"Why labels bounded witness and still shows request after long context")
    Maintenance.export_raw(db,snapshot,"long.raw")
    raw : List<&2,U32> <- bytes("long.raw")
    assert(Domain.bytes_equal(raw,Domain.encode(message("long-context-session",text))),
      "long witness exact bytes remain accessible through verified raw export")

def codex_cases(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"codex","codex.jsonl",codex_meta("codex-session") ++
      codex("<permissions>recorded context</permissions>") ++ codex(wrapped()))
    +value : A.Actor <- actor(db,"codex",snapshot,3)
    assert(String.eq(exact(value),"exact") && String.eq(key_field(value,"record"),"2") &&
      String.eq(key_field(value,"event"),"0"),"Codex request skips context and keeps response-item ordinal")
    assert(String.eq(A.request_preview(value),"\n  Fix café 😀 safely. \n"),
      "Codex wrapper uses same exact recorded suffix policy")
    +bad : String <- capture(db,"codex","codex-bad.jsonl",codex_meta("codex-bad") ++
      "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":false}]}}\n" ++ codex("Later request"))
    +bad_actor : A.Actor <- actor(db,"codex",bad,3)
    assert(String.eq(exact(bad_actor),"not_indexed") && String.contains(blocked(bad_actor),"malformed"),
      "Codex boolean text cannot be promoted through normalized string coercion")

def many_blocks(+db: U32) -> IO(Unit):
  +prefix = {"{\"type\":\"text\",\"text\":\"<system-reminder>context</system-reminder>\"}," : String}
  +content = "[" ++ String.repeat(prefix,512n) ++ "{\"type\":\"text\",\"text\":\"Final recorded request\"}]"
  do IO<Unit>:
    +snapshot : String <- capture(db,"claude","many.jsonl",claude("many-block-session","",content))
    +value : A.Actor <- actor(db,"claude",snapshot,1)
    assert(String.eq(exact(value),"exact") && String.eq(A.request_preview(value),"Final recorded request"),
      "512 context-only blocks lead to the final typed request in one physical record")
    assert(String.eq(key_field(value,"record"),"0") && String.eq(key_field(value,"event"),"512"),
      "aligned raw hints preserve every preceding normalized event ordinal")
    +record : E.Verified <- E.read_record(db,snapshot,0)
    assert(String.eq(E.citation(record,512),A.key(value)),"many-block descriptor resolves unchanged raw event index")
    +beyond : String <- capture(db,"claude","beyond.jsonl",
      String.repeat(message("bounded-session","<system-reminder>context</system-reminder>"),16n) ++
        message("bounded-session","Request beyond actor coverage"))
    +bounded : A.Actor <- actor(db,"claude",beyond,17)
    assert(String.eq(exact(bounded),"not_indexed") && String.is_empty(A.key(bounded)),
      "request beyond first 16 physical records remains unavailable rather than inferred")

def forged() -> IO(Unit):
  +raw = {Json.JObject{[Json.JField{"type",Json.JString{"user"}},Json.JField{"type",Json.JString{"user"}},
    Json.JField{"message",Json.JObject{[Json.JField{"content",Json.JString{"Request"}}]}}]} : Json.Json}
  +event = {Providers.ProviderEvent{"user","Request","","","","","/synthetic/request","id","","","","","complete"} : Providers.Record}
  do IO<Unit>:
    assert(Bool.not(O.eligible(R.assess("claude",raw,0,event))),"duplicate constructed raw fields cannot establish typed request")
    assert(Bool.not(O.eligible(R.assess("claude",parsed(Json.parse(message("id","Different"))),0,event))),
      "normalized and typed raw text mismatch is ineligible")
    assert(String.eq(Store.projection_version(),"providers-v4-utc-context-relay"),
      "read-time request policy preserves parser and context projection version")

def main() -> IO(Unit):
  do IO<Unit>:
    raw_root : String <- IO.try(String,IO.get_env("PWD"))
    root : String <- Paths.resolve(raw_root)
    Store.checked(String.contains(root,"juice-bend-test-request_origin_integration."),"requires isolated synthetic test root")
    +db : U32 <- Store.open(".build/request-origin.sqlite")
    forged()
    skipped(db)
    negative(db)
    positive(db)
    long_witness(db)
    codex_cases(db)
    many_blocks(db)
    IO.try(Unit,Sql.close(db))
