import Base
import ./json.bend as Json
import ./providers.bend as Providers
import ./request_origin.bend as Origin

# Read-time policy only. No normalized text, role, ordinal or capture changes.
def policy() -> String:
  "recorded-request-v1"

type Lookup is Data:
  Missing{}
  Found{value: Json.Json}
  Invalid{}

def found(previous: Lookup,value: Json.Json) -> Lookup:
  match previous:
    case Missing{}: Found{value}
    case _: Invalid{}

def fields(items: List<&2,Json.Field>,+key: String,+state: Lookup) -> Lookup:
  match items:
    case []: state
    case Json.JField{+name,value} <> rest:
      fields(rest,key,Bool.pick(Lookup,String.eq(name,key),found(state,value),state))

def field(raw: Json.Json,key: String) -> Lookup:
  match raw:
    case Json.JObject{items}: fields(items,key,Missing{})
    case _: Invalid{}

def value(item: Lookup) -> Json.Json:
  match item:
    case Found{raw}: raw
    case _: Json.JNull{}

def string(item: Lookup) -> Maybe<&2,String>:
  match item:
    case Found{Json.JString{text}}: Some{text}
    case _: None{}

def named(item: Lookup,name: String) -> Bool:
  match item:
    case Found{Json.JString{text}}: String.eq(text,name)
    case _: False{}

def block(+raw: Json.Json) -> Maybe<&2,String>:
  Bool.pick(Maybe<&2,String>,named(field(raw,"type"),"text"),string(field(raw,"text")),None{})

def at_next(first: Bool,head: Json.Json,tail: Unit -> Maybe<&2,String>) -> Maybe<&2,String>:
  match first:
    case True{}: block(head)
    case False{}: tail(Unit{})

def at(items: List<&2,Json.Json>,+index: U32) -> Maybe<&2,String>:
  match items:
    case []: None{}
    case head <> rest:
      at_next(U32.is_eq(index,0),head,_ => at(rest,U32.sub(index,1)))

def claude_content(raw: Json.Json,index: U32) -> Maybe<&2,String>:
  match raw:
    case Json.JString{text}:
      Bool.pick(Maybe<&2,String>,U32.is_eq(index,0),Some{text},None{})
    case Json.JArray{items}: at(items,index)
    case _: None{}

def claude(+raw: Json.Json,index: U32) -> Maybe<&2,String>:
  Bool.pick(Maybe<&2,String>,named(field(raw,"type"),"user"),
    claude_content(value(field(value(field(raw,"message")),"content")),index),None{})

def part(+raw: Json.Json) -> Maybe<&2,String>:
  +kind = field(raw,"type")
  Bool.pick(Maybe<&2,String>,named(kind,"text") || named(kind,"input_text") ||
    named(kind,"output_text") || named(kind,"summary_text"),string(field(raw,"text")),None{})

def join_part(head: Maybe<&2,String>,tail: Maybe<&2,List<&2,String>>) -> Maybe<&2,List<&2,String>>:
  match head tail:
    case Some{h} Some{t}: Some{h <> t}
    case _ _: None{}

def parts(items: List<&2,Json.Json>) -> Maybe<&2,List<&2,String>>:
  match items:
    case []: Some{[]}
    case head <> rest: join_part(part(head),parts(rest))

def joined(items: Maybe<&2,List<&2,String>>) -> Maybe<&2,String>:
  match items:
    case Some{strings}: Some{String.join(strings,"\n\n")}
    case None{}: None{}

def codex_content(raw: Json.Json) -> Maybe<&2,String>:
  match raw:
    case Json.JString{text}: Some{text}
    case Json.JArray{items}: joined(parts(items))
    case _: None{}

def codex_payload(+raw: Json.Json) -> Maybe<&2,String>:
  Bool.pick(Maybe<&2,String>,named(field(raw,"type"),"message") && named(field(raw,"role"),"user"),
    codex_content(value(field(raw,"content"))),None{})

def codex(+raw: Json.Json,+index: U32) -> Maybe<&2,String>:
  +payload = Bool.pick(Json.Json,named(field(raw,"type"),"response_item"),value(field(raw,"payload")),raw)
  Bool.pick(Maybe<&2,String>,U32.is_eq(index,0) &&
    (named(field(raw,"type"),"response_item") || named(field(raw,"type"),"message")),
    codex_payload(payload),None{})

def typed(provider: String,raw: Json.Json,index: U32) -> Maybe<&2,String>:
  match provider:
    case "claude": claude(raw,index)
    case "codex": codex(raw,index)
    case _: None{}

# Alignment is generated once per physical record. The actor then consumes one
# hint for each unchanged normalized event, including attachments and tools.
# It never repeatedly indexes the original array while scanning its events.
def block_texts(items: List<&2,Json.Json>) -> List<&2,Maybe<&2,String>>:
  match items:
    case []: []
    case head <> rest: block(head) <> block_texts(rest)

def claude_texts(content: Json.Json) -> List<&2,Maybe<&2,String>>:
  match content:
    case Json.JString{text}: [Some{text}]
    case Json.JArray{items}: block_texts(items)
    case _: [None{}]

def texts(name: String,+raw: Json.Json) -> List<&2,Maybe<&2,String>>:
  match name:
    case "claude": claude_texts(value(field(value(field(raw,"message")),"content")))
    case "codex": [codex(raw,0)]
    case _: []

def present(item: Maybe<&2,String>) -> Bool:
  match item:
    case Some{_}: True{}
    case None{}: False{}

def claude_block_shape(+raw: Json.Json) -> Bool:
  +kind = field(raw,"type")
  Bool.pick(Bool,named(kind,"text"),present(string(field(raw,"text"))),
    named(kind,"thinking") || named(kind,"tool_use") || named(kind,"tool_result") ||
      named(kind,"image") || named(kind,"document"))

def claude_shapes(items: List<&2,Json.Json>) -> Bool:
  match items:
    case []: True{}
    case head <> rest: claude_block_shape(head) && claude_shapes(rest)

def claude_shape(raw: Json.Json) -> Bool:
  match raw:
    case Json.JString{_}: True{}
    case Json.JArray{items}: claude_shapes(items)
    case _: False{}

def frame_shape(name: String,+raw: Json.Json) -> Bool:
  match name:
    case "claude":
      Bool.not(named(field(raw,"type"),"user")) ||
        claude_shape(value(field(value(field(raw,"message")),"content")))
    case "codex":
      +payload = Bool.pick(Json.Json,named(field(raw,"type"),"response_item"),value(field(raw,"payload")),raw)
      Bool.not(named(field(payload,"role"),"user")) || present(codex(raw,0))
    case _: False{}

def meta_valid(meta: Origin.MetaFlag) -> Bool:
  match meta:
    case Origin.Malformed{}: False{}
    case _: True{}

def object_issue(+name: String,+raw: Json.Json) -> String:
  Bool.pick(String,Bool.not(meta_valid(Origin.metadata(raw))),
    "recorded request uncertain: isMeta is malformed or duplicated",
    Bool.pick(String,frame_shape(name,raw),"",
      "recorded request uncertain: malformed or unsupported user content"))

def frame_issue(name: String,raw: Json.Json) -> String:
  match raw:
    case Json.JObject{items}: object_issue(name,Json.JObject{items})
    case _:
      "recorded request uncertain: retained record is not a decoded object"

def provider(name: String) -> Origin.Provider:
  Bool.pick(Origin.Provider,String.eq(name,"claude"),Origin.Claude{},Origin.Codex{})

def checked(ok: Bool,kind: Origin.Provider,meta: Origin.MetaFlag,+text: String) -> Origin.Assessment:
  match ok:
    case True{}: Origin.classify(kind,"user",meta,text)
    case False{}: Origin.Assessment{text,"user",Origin.Uncertain{"raw text or normalized event correspondence is unsupported"}}

def assessment_text(typed: Maybe<&2,String>,provider: Origin.Provider,meta: Origin.MetaFlag,
  +text: String,coverage: String) -> Origin.Assessment:
  match typed:
    case Some{raw_text}: checked(String.eq(raw_text,text) && String.eq(coverage,"complete"),provider,meta,text)
    case None{}: checked(False{},provider,meta,text)

def assess(+name: String,+raw: Json.Json,index: U32,event: Providers.Record) -> Origin.Assessment:
  Providers.ProviderEvent{_,text,_,_,_,_,_,_,_,_,_,_,coverage} = event
  assessment_text(typed(name,raw,index),provider(name),Origin.metadata(raw),text,coverage)

def assess_aligned(name: String,meta: Origin.MetaFlag,hint: Maybe<&2,String>,
  event: Providers.Record) -> Origin.Assessment:
  Providers.ProviderEvent{_,text,_,_,_,_,_,_,_,_,_,_,coverage} = event
  assessment_text(hint,provider(name),meta,text,coverage)

def uncertainty(assessment: Origin.Assessment) -> String:
  Origin.Assessment{_,_,disposition} = assessment
  match disposition:
    case Origin.Uncertain{reason}: "recorded request uncertain: " ++ reason
    case _: ""

def request_value(value: Maybe<&2,String>) -> String:
  match value:
    case Some{text}: text
    case None{}: ""

def request(assessment: Origin.Assessment) -> String:
  request_value(Origin.request(assessment))
