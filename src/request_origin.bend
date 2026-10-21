import Base
import ./json.bend as Json
import ./domain.bend as Domain

# A conservative classification of recorded text, not proof of human authorship.
# Read-time request policy; it cannot change captured bytes, provider event
# ordinals, projections, source discovery, or evidence citations.
type Provider is Data:
  Claude{}
  Codex{}

type MetaFlag is Data:
  Unspecified{}
  Explicit{value: Bool}
  Malformed{}

type Span is Data:
  Span{start: U32,count: U32}

type Disposition is Data:
  RecordedRequest{span: Span,prefix_blocks: U32}
  RecordedNonUser{}
  ContextEnvelope{basis: String}
  RelayEnvelope{basis: String}
  Empty{}
  Uncertain{reason: String}

type Assessment is Data:
  Assessment{source_text: String,recorded_role: String,disposition: Disposition}

type Cursor is Data:
  Cursor{text: String,offset: U32}

type Rule is Data:
  Rule{name: String,kind: U32}

type Marker is Data:
  Marker{prefix: String,basis: String,relay: Bool,boundary: Bool}

type Decision is Data:
  Finished{disposition: Disposition}
  Advance{cursor: Cursor}

def maximum_bytes() -> U32:
  1048576

def whitespace(value: Char) -> Bool:
  Chr{+cp} = value
  (U32.is_ge(cp,9) && U32.is_le(cp,13)) || U32.is_eq(cp,32) || U32.is_eq(cp,133) ||
    U32.is_eq(cp,160) || U32.is_eq(cp,5760) || (U32.is_ge(cp,8192) && U32.is_le(cp,8202)) ||
    U32.is_eq(cp,8232) || U32.is_eq(cp,8233) || U32.is_eq(cp,8239) || U32.is_eq(cp,8287) || U32.is_eq(cp,12288)

def measured_step(valid: Bool,remaining: U32,next: U32 -> Result<&2,&2,String,U32>) -> Result<&2,&2,String,U32>:
  match valid:
    case True{}: next(remaining)
    case False{}: Fail{"text exceeds the 1 MiB UTF8 inspection budget or contains an invalid Unicode scalar"}

# One scalar pass; no encoded byte-list allocation, repeated suffix length, or
# accumulated String append. A UTF8 byte bound also bounds the scalar count.
def measure(text: String,+remaining: U32,count: U32) -> Result<&2,&2,String,U32>:
  match text:
    case SNil{}: Done{count}
    case SCon{Chr{+cp},rest}:
      +width = U32.inc(Domain.encode_width(cp))
      measured_step(Domain.scalar(cp) && U32.is_le(width,remaining),U32.sub(remaining,width),
        left => measure(rest,left,U32.inc(count)))

def size(text: String) -> Result<&2,&2,String,U32>:
  measure(text,maximum_bytes(),0)

def meta_value(value: Json.Json) -> MetaFlag:
  match value:
    case Json.JBool{value}: Explicit{value}
    case _: Malformed{}

def meta_found(seen: Bool,value: Json.Json) -> MetaFlag:
  match seen:
    case True{}: Malformed{}
    case False{}: meta_value(value)

def meta_fields(fields: List<&2,Json.Field>,state: MetaFlag,seen: Bool) -> MetaFlag:
  match fields:
    case []: state
    case Json.JField{"isMeta",value} <> rest: meta_fields(rest,meta_found(seen,value),True{})
    case Json.JField{_,_} <> rest: meta_fields(rest,state,seen)

# Missing is distinct from null, wrong type, duplicate keys, or nonobject input.
def metadata(raw: Json.Json) -> MetaFlag:
  match raw:
    case Json.JObject{fields}: meta_fields(fields,Unspecified{},False{})
    case _: Malformed{}

def trim_step(skip: Bool,current: Cursor,next: Unit -> Cursor) -> Cursor:
  match skip:
    case True{}: next(Unit{})
    case False{}: current

def leading(text: String,+offset: U32) -> Cursor:
  match text:
    case SNil{}: Cursor{"",offset}
    case SCon{+head,+tail}:
      trim_step(whitespace(head),Cursor{SCon{head,tail},offset},_ => leading(tail,U32.inc(offset)))

def has_text(text: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{head,tail}: Bool.not(whitespace(head)) || has_text(tail)

def prefix_step(same: Bool,next: Unit -> Maybe<&2,String>) -> Maybe<&2,String>:
  match same:
    case True{}: next(Unit{})
    case False{}: None{}

# Only the bounded ASCII marker is folded, never the source text as a whole.
def after_prefix(prefix: String,text: String) -> Maybe<&2,String>:
  match prefix text:
    case SNil{} _: Some{text}
    case _ SNil{}: None{}
    case SCon{p,pt} SCon{s,st}:
      prefix_step(Char.is_eq(Char.to_lower(p),Char.to_lower(s)),_ => after_prefix(pt,st))

def tag_boundary(rest: Maybe<&2,String>) -> Bool:
  match rest:
    case None{}: False{}
    case Some{SNil{}}: True{}
    case Some{SCon{+head,_}}:
      whitespace(head) || Char.is_eq(head,'>') || Char.is_eq(head,'/')

def request_rules() -> List<&2,Rule>:
  [Rule{"system-reminder",0},Rule{"environment_context",0},Rule{"user_instructions",0}]

def shared_rules() -> List<&2,Rule>:
  [Rule{"task-notification",2},Rule{"teammate-message",2},
    Rule{"multi_agent_mode",1},Rule{"skills_instructions",1},Rule{"apps_instructions",1},
    Rule{"plugins_instructions",1},Rule{"recommended_plugins",1},Rule{"local-command-caveat",1},
    Rule{"local-command-stdout",1},Rule{"local-command-stderr",1},Rule{"tool_result",1},
    Rule{"command-name",1},Rule{"command-message",1},Rule{"command-args",1}]

def provider_rules(provider: Provider) -> List<&2,Rule>:
  match provider:
    case Claude{}: [Rule{"relay",2}]
    case Codex{}: [Rule{"codex_internal_context",1},Rule{"app-context",1},Rule{"permissions",1},Rule{"collaboration_mode",1}]

def rules(provider: Provider) -> List<&2,Rule>:
  List.append(&2,Rule,request_rules(),List.append(&2,Rule,shared_rules(),provider_rules(provider)))

def chosen_rule(found: Bool,rule: Rule,next: Unit -> Maybe<&2,Rule>) -> Maybe<&2,Rule>:
  match found:
    case True{}: Some{rule}
    case False{}: next(Unit{})

def find_rule(values: List<&2,Rule>,+text: String) -> Maybe<&2,Rule>:
  match values:
    case []: None{}
    case Rule{+name,+kind} <> rest:
      chosen_rule(tag_boundary(after_prefix("<" ++ name,text)),Rule{name,kind},_ => find_rule(rest,text))

def marker_boundary(rest: Maybe<&2,String>,required: Bool) -> Bool:
  match rest:
    case None{}: False{}
    case Some{SNil{}}: True{}
    case Some{SCon{+head,_}}:
      Bool.not(required) || whitespace(head) || Char.is_eq(head,'.') || Char.is_eq(head,':')

def markers(provider: Provider) -> List<&2,Marker>:
  match provider:
    case Claude{}:
      [Marker{"# agents.md instructions for","agents_md_instructions",False{},True{}},
        Marker{"another claude session sent a message:","claude_cross_session_message",True{},False{}},
        Marker{"the coordinator sent a message:","claude_coordinator_message",True{},False{}},
        Marker{"this session is being continued from a previous conversation","claude_continuation_summary",True{},True{}},
        Marker{"[system notification - not user input]","claude_system_notification",True{},True{}},
        Marker{"[cross-session idle notice]","claude_cross_session_idle",True{},True{}}]
    case Codex{}:
      [Marker{"# agents.md instructions for","agents_md_instructions",False{},True{}},
        Marker{"[request interrupted by user for tool use]","codex_request_interrupted",False{},True{}}]

def marker_result(found: Bool,+basis: String,relay: Bool,next: Unit -> Maybe<&2,Disposition>) -> Maybe<&2,Disposition>:
  match found:
    case False{}: next(Unit{})
    case True{}:
      Some{Bool.pick(Disposition,relay,RelayEnvelope{basis},ContextEnvelope{basis})}

def find_marker(values: List<&2,Marker>,+text: String) -> Maybe<&2,Disposition>:
  match values:
    case []: None{}
    case Marker{prefix,basis,relay,boundary} <> rest:
      marker_result(marker_boundary(after_prefix(prefix,text),boundary),basis,relay,_ => find_marker(rest,text))

def close_result(after: Maybe<&2,String>,offset: U32,length: U32) -> Result<&2,&2,String,Cursor>:
  match after:
    case Some{rest}: Done{Cursor{rest,U32.add(offset,length)}}
    case None{}: Fail{"nested markup or a mismatched closing tag in a recognized envelope"}

# Exact attribute-free tags only. Any '<' inside a recognized wrapper must be
# its matching close: nested markup is an explicit unsupported/uncertain case.
def scan_close(text: String,offset: U32,+close: String,+length: U32) -> Result<&2,&2,String,Cursor>:
  match text:
    case SNil{}: Fail{"recognized envelope has no matching closing tag"}
    case SCon{Chr{60},rest}:
      close_result(after_prefix(close,SCon{Chr{60},rest}),offset,length)
    case SCon{_,rest}: scan_close(rest,U32.inc(offset),close,length)

def opened(after: Maybe<&2,String>,offset: U32,+name: String) -> Result<&2,&2,String,Cursor>:
  match after:
    case None{}: Fail{"recognized envelope opener is incomplete or has unsupported attributes or syntax"}
    case Some{rest}:
      +name_length = U32.from_nat(String.length(name))
      scan_close(rest,U32.add(offset,U32.add(name_length,2)),"</" ++ name ++ ">",U32.add(name_length,3))

def closed(+text: String,offset: U32,+name: String) -> Result<&2,&2,String,Cursor>:
  opened(after_prefix("<" ++ name ++ ">",text),offset,name)

def rule_closed(result: Result<&2,&2,String,Cursor>,name: String,kind: U32) -> Decision:
  match result:
    case Fail{reason}: Finished{Uncertain{reason}}
    case Done{cursor}:
      match kind:
        case 0: Advance{cursor}
        case 2: Finished{RelayEnvelope{"closed_" ++ name}}
        case _: Finished{ContextEnvelope{"closed_" ++ name}}

def ordinary(marker: Maybe<&2,Disposition>,closing: Bool,+start: U32,total: U32,blocks: U32) -> Decision:
  match marker closing:
    case Some{disposition} _: Finished{disposition}
    case None{} True{}: Finished{Uncertain{"unexpected leading closing tag"}}
    case None{} False{}: Finished{RecordedRequest{Span{start,U32.sub(total,start)},blocks}}

def with_rule(rule: Maybe<&2,Rule>,+provider: Provider,+text: String,offset: U32,start: U32,total: U32,blocks: U32) -> Decision:
  match rule:
    case Some{Rule{+name,kind}}: rule_closed(closed(text,offset,name),name,kind)
    case None{}:
      ordinary(find_marker(markers(provider),text),String.starts_with(text,"</"),start,total,blocks)

def at_cursor(cursor: Cursor,+provider: Provider,start: U32,total: U32,blocks: U32) -> Decision:
  match cursor:
    case Cursor{SNil{},_}:
      Finished{Bool.pick(Disposition,U32.is_zero(blocks),Empty{},ContextEnvelope{"closed_request_prefix_only"})}
    case Cursor{+text,offset}: with_rule(find_rule(rules(provider),text),provider,text,offset,start,total,blocks)

def decide(cursor: Cursor,provider: Provider,total: U32,blocks: U32) -> Decision:
  Cursor{text,+offset} = cursor
  at_cursor(leading(text,offset),provider,offset,total,blocks)

def at_limit(decision: Decision) -> Disposition:
  match decision:
    case Finished{disposition}: disposition
    case Advance{_}: Uncertain{"more than 12 leading request-context blocks"}

def followed(decision: Decision,next: Cursor -> Disposition) -> Disposition:
  match decision:
    case Finished{disposition}: disposition
    case Advance{cursor}: next(cursor)

def prefixes(fuel: Nat,cursor: Cursor,+provider: Provider,+total: U32,+blocks: U32) -> Disposition:
  match fuel:
    case 0n: at_limit(decide(cursor,provider,total,blocks))
    case 1n+rest:
      followed(decide(cursor,provider,total,blocks),next => prefixes(rest,next,provider,total,U32.inc(blocks)))

def known_nonuser(role: String) -> Bool:
  match role:
    case "assistant": True{}
    case "system": True{}
    case "developer": True{}
    case "tool": True{}
    case "tool_result": True{}
    case "toolResult": True{}
    case "thinking": True{}
    case "metadata": True{}
    case "attachment": True{}
    case "unsupported": True{}
    case _: False{}

def other_role(known: Bool) -> Disposition:
  Bool.pick(Disposition,known,RecordedNonUser{},Uncertain{"unknown recorded role"})

def role_disposition(role: String,provider: Provider,text: String,total: U32) -> Disposition:
  match role:
    case "user": prefixes(12n,Cursor{text,0},provider,total,0)
    case _: other_role(known_nonuser(role))

def meta_only(disposition: Disposition) -> Disposition:
  match disposition:
    case RecordedRequest{_,_}: ContextEnvelope{"claude_is_meta"}
    case _: disposition

# isMeta is a Claude field; an explicit Codex boolean has no Claude meaning.
# Malformed supplied metadata is conservatively uncertain for both providers.
def meta_disposition(provider: Provider,meta: MetaFlag,role: String,text: String,total: U32) -> Disposition:
  match provider meta:
    case _ Malformed{}: Uncertain{"isMeta is malformed or duplicated"}
    case Claude{} Explicit{True{}}: meta_only(role_disposition(role,Claude{},text,total))
    case _ _: role_disposition(role,provider,text,total)

def sized(result: Result<&2,&2,String,U32>,+provider: Provider,meta: MetaFlag,+role: String,+text: String) -> Assessment:
  match result:
    case Fail{reason}: Assessment{text,role,Uncertain{reason}}
    case Done{total}: Assessment{text,role,meta_disposition(provider,meta,role,text,total)}

def classify(provider: Provider,recorded_role: String,meta: MetaFlag,+text: String) -> Assessment:
  sized(size(text),provider,meta,recorded_role,text)

def original(assessment: Assessment) -> String:
  Assessment{source_text,_,_} = assessment
  source_text

def extracted(valid: Bool,text: String,start: U32,count: U32) -> Maybe<&2,String>:
  match valid:
    case False{}: None{}
    case True{}: Some{String.take(String.drop(text,U32.to_nat(start)),U32.to_nat(count))}

def extract_size(result: Result<&2,&2,String,U32>,text: String,span: Span) -> Maybe<&2,String>:
  match result:
    case Fail{_}: None{}
    case Done{+total}:
      Span{+start,+count} = span
      extracted(U32.is_le(start,total) && U32.is_le(count,U32.sub(total,start)),text,start,count)

# Span arithmetic never adds untrusted U32 values. Out-of-range, overflow-shaped
# spans, invalid scalars, and overbudget supplied texts return None.
def extract(+source_text: String,span: Span) -> Maybe<&2,String>:
  extract_size(size(source_text),source_text,span)

def nonblank(value: Maybe<&2,String>) -> Maybe<&2,String>:
  match value:
    case None{}: None{}
    case Some{+text}: Bool.pick(Maybe<&2,String>,has_text(text),Some{text},None{})

def request(assessment: Assessment) -> Maybe<&2,String>:
  match assessment:
    case Assessment{text,"user",RecordedRequest{span,_}}: nonblank(extract(text,span))
    case _: None{}

def eligible_result(result: Maybe<&2,String>) -> Bool:
  match result:
    case Some{_}: True{}
    case None{}: False{}

def eligible(assessment: Assessment) -> Bool:
  eligible_result(request(assessment))
