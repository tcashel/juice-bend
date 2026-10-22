import Base
import ./json.bend as Json
import ./request_evidence.bend as Request
import ./provider_title.bend as Title
import ./relations.bend as R

# Read-only navigation metadata. This never modifies provider events, recorded
# session identity or request eligibility. One top-level agentId cannot assign
# different children to several result blocks, so that shape stays ambiguous.
type Recorded is Data:
  Missing{reason: String}
  Unsupported{reason: String}
  Ambiguous{reason: String}
  Agent{id: String,call: String}

def safe_chars(value: String) -> Bool:
  match value:
    case SNil{}: True{}
    case SCon{Chr{+cp},tail}:
      ((U32.is_ge(cp,48) && U32.is_le(cp,57)) ||
       (U32.is_ge(cp,65) && U32.is_le(cp,90)) ||
       (U32.is_ge(cp,97) && U32.is_le(cp,122)) ||
       U32.is_eq(cp,45) || U32.is_eq(cp,95)) && safe_chars(tail)

def safe_id(+value: String) -> Bool:
  Bool.not(String.is_empty(value)) && Nat.is_le(String.length(value),128n) && safe_chars(value)

def at(items: List<&2,Json.Json>,index: Nat) -> Json.Json:
  match items index:
    case [] _: Json.JNull{}
    case head <> _ 0n: head
    case _ <> rest 1n+tail: at(rest,tail)

def results(items: List<&2,Json.Json>) -> U32:
  match items:
    case []: 0
    case head <> rest:
      U32.add(Bool.to_u32(Request.named(Request.field(head,"type"),"tool_result")),results(rest))

def optional_role(value: Request.Lookup,role: String) -> Bool:
  match value:
    case Request.Missing{}: True{}
    case other: Request.named(other,role)

def agent(value: Request.Lookup,call: String) -> Recorded:
  match value:
    case Request.Missing{}: Missing{"Result has no recorded child agentId"}
    case Request.Found{Json.JString{+id}}:
      Bool.pick(Recorded,safe_id(id),Agent{id,call},
        Unsupported{"Child agentId must be 1 to 128 literal ASCII letters, digits, hyphens or underscores"})
    case _: Unsupported{"Child agentId has an unsupported or ambiguous JSON type"}

def envelope(value: Request.Lookup,call: String) -> Recorded:
  match value:
    case Request.Missing{}: Missing{"Result has no recorded toolUseResult envelope"}
    case Request.Found{+raw}:
      agent(Request.field(raw,"agentId"),call)
    case _: Unsupported{"Recorded toolUseResult envelope is ambiguous"}

def selected(yes: Bool,+raw: Json.Json,+block: Json.Json,count: U32) -> Recorded:
  match yes:
    case False{}: Missing{"Selected event is not a typed Claude tool_result"}
    case True{}:
      Bool.pick(Recorded,U32.is_ne(count,1),
        Ambiguous{"Multiple tool_result blocks share one agentId envelope; no child was selected"},
        Bool.pick(Recorded,Title.optional_string(Request.field(block,"tool_use_id")),
          envelope(Request.field(raw,"toolUseResult"),Json.get(block,"tool_use_id")),
          Unsupported{"Recorded tool_use_id has an unsupported JSON type"}))

def blocks(value: Request.Lookup,+raw: Json.Json,event: U32) -> Recorded:
  match value:
    case Request.Found{Json.JArray{+items}}:
      +block = at(items,U32.to_nat(event))
      selected(Request.named(Request.field(block,"type"),"tool_result"),raw,block,results(items))
    case _: Missing{"Selected record has no typed content-block array"}

def ready(yes: Bool,+raw: Json.Json,event: U32) -> Recorded:
  match yes:
    case False{}: Unsupported{"Selected result metadata is malformed or conflicts with retained session context"}
    case True{}:
      blocks(Request.field(Request.value(Request.field(raw,"message")),"content"),raw,event)

def decode(+raw: Json.Json,event: U32,session: String) -> Recorded:
  +role = Json.get(raw,"type")
  ready((Request.named(Request.field(raw,"type"),"user") ||
    Request.named(Request.field(raw,"type"),"assistant")) && Title.metadata(raw,session) &&
    optional_role(Request.field(Request.value(Request.field(raw,"message")),"role"),role),raw,event)

# Lexical association only; these strings are never passed to the filesystem.
# A nested child may record a result for another child in the same retained
# enclosing parent/subagents directory. Raw sessionId is deliberately irrelevant.
def namespace_parts(parts: List<&2,String>,+source: String) -> String:
  match parts:
    case _ <> "subagents" <> rest:
      String.join(List.reverse(&2,String,rest),"/") ++ "/subagents/"
    case _:
      String.take(source,Nat.sub(String.length(source),6n)) ++ "/subagents/"

def namespace(+source: String) -> String:
  Bool.pick(String,R.canonical_path(source) && String.ends_with(source,".jsonl"),
    namespace_parts(List.reverse(&2,String,String.split(source,'/')),source),"")

def target(+source: String,+id: String,+candidate: String) -> Bool:
  +base = namespace(source)
  Bool.not(String.is_empty(base)) && safe_id(id) && R.canonical_path(candidate) &&
    String.eq(candidate,base ++ "agent-" ++ id ++ ".jsonl")

def status(value: Recorded) -> String:
  match value:
    case Missing{_}: "missing"
    case Unsupported{_}: "unsupported"
    case Ambiguous{_}: "ambiguous"
    case Agent{_,_}: "recorded"

def reason(value: Recorded) -> String:
  match value:
    case Missing{reason}: reason
    case Unsupported{reason}: reason
    case Ambiguous{reason}: reason
    case Agent{_,_}: "Recorded agentId is a navigation hint; retained candidates must still match scope and locator"
