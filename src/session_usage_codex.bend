import Base
import ./json.bend as Json
import ./domain.bend as Domain
import ./query.bend as Query
import ./timestamp.bend as Timestamp
import ./session_usage_counts.bend as Counts

# Pure accounting of one retained Codex capture, visited from physical record0.
# No cross-source deduplication, pricing, author identity or billing inference.
# Inherited-copy fallback is explicitly named, not proof of child authorship.
type Time is Data:
  Time{milliseconds: Nat,submillisecond: U32}

type Header is Data:
  Header{seen: Bool,category: String,session: String,parent: String,fork: String,time: String}

type Phase is Data:
  Inherited{copied_turn: Bool}
  Starting{basis: String}
  Own{basis: String}

type Stats is Data:
  Stats{observations: U32,accepted: U32,duplicates: U32,resets: U32,
    excluded: U32,uncertain: U32,first: String,last: String}

type State is Data:
  State{next: U32,header: Header,phase: Phase,previous: Maybe<&2,Counts.Counters>,
    interrupted: Bool,blocked: Bool,accounted: Counts.Counters,stats: Stats}

type Report is Data:
  Report{category: String,session: String,parent: String,fork_basis: String,
    accounted: Counts.Counters,observations: U32,accepted: U32,duplicates: U32,
    resets: U32,excluded: U32,uncertain: U32,first_ordinal: String,last_ordinal: String,complete: Bool}

type Found is Data:
  Missing{}
  Value{value: Json.Json}
  Invalid{}

def new() -> State:
  State{0,Header{False{},"unknown","","","",""},Own{"none"},None{},False{},False{},
    Counts.empty(),Stats{0,0,0,0,0,0,"",""}}

def found_once(previous: Found,value: Json.Json) -> Found:
  match previous:
    case Missing{}: Value{value}
    case _: Invalid{}

def lookup_fields(fields: List<&2,Json.Field>,+key: String,+state: Found) -> Found:
  match fields:
    case []: state
    case Json.JField{name,value} <> rest:
      lookup_fields(rest,key,Bool.pick(Found,String.eq(name,key),found_once(state,value),state))

def lookup(value: Json.Json,key: String) -> Found:
  match value:
    case Json.JObject{fields}: lookup_fields(fields,key,Missing{})
    case _: Invalid{}

def raw_value(value: Found) -> Json.Json:
  match value:
    case Value{value}: value
    case _: Json.JNull{}

def field(value: Json.Json,key: String) -> Json.Json:
  raw_value(lookup(value,key))

def typed_text(value: Json.Json) -> String:
  match value:
    case Json.JString{text}: text
    case _: ""

def text(value: Json.Json,key: String) -> String:
  typed_text(field(value,key))

def id_width_step(valid: Bool,next: Unit -> Bool) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: next(Unit{})

def id_width(text: String,+room: U32) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      id_width_step(Domain.scalar(cp) && U32.is_gt(cp,0) &&
        U32.is_le(U32.inc(Domain.encode_width(cp)),room),unused =>
        id_width(rest,U32.sub(room,U32.inc(Domain.encode_width(cp)))))

def identifier(+value: Json.Json) -> String:
  +s = typed_text(value)
  Bool.pick(String,Bool.not(String.is_empty(s)) && id_width(s,512),s,"")

def optional_id(value: Found) -> Maybe<&2,String>:
  match value:
    case Missing{}: Some{""}
    case Value{value}:
      +id = identifier(value)
      Bool.pick(Maybe<&2,String>,String.is_empty(id),None{},Some{id})
    case Invalid{}: None{}

def absent(value: Found) -> Bool:
  match value:
    case Missing{}: True{}
    case _: False{}

def supported_fork(value: Maybe<&2,String>,supported: Bool) -> Maybe<&2,String>:
  match supported:
    case True{}: value
    case False{}: None{}

# Unrecognized inheritance declarations are not a license to count a copied
# prefix as an ordinary session. A parent relationship alone is not inheritance.
def fork_declaration(+payload: Json.Json) -> Maybe<&2,String>:
  supported_fork(optional_id(lookup(payload,"forked_from_id")),
    absent(lookup(payload,"forked_from_session_id")) && absent(lookup(payload,"forked_from_session")) &&
    absent(lookup(payload,"forked_from")))

def plain_source(value: String) -> Bool:
  match value:
    case "cli": True{}
    case "exec": True{}
    case "vscode": True{}
    case "app-server": True{}
    case "app_server": True{}
    case _: False{}

def source_agent(spawn: Found,other: Found) -> String:
  match spawn other:
    case Missing{} Value{Json.JString{"guardian"}}: "reviewer"
    case Value{value} Missing{}:
      Bool.pick(String,String.is_empty(identifier(field(value,"parent_thread_id"))),"unknown","ordinary")
    case _ _: "unknown"

def kind_of_source(+value: Json.Json) -> String:
  match value:
    case Json.JString{s}: Bool.pick(String,plain_source(s),"ordinary","unknown")
    case Json.JObject{fields}:
      +agent = field(Json.JObject{fields},"subagent")
      +spawn = lookup(agent,"thread_spawn")
      +other = lookup(agent,"other")
      source_agent(spawn,other)
    case _: "unknown"

def parent_of(+payload: Json.Json) -> String:
  +spawn = identifier(field(field(field(field(payload,"source"),"subagent"),"thread_spawn"),"parent_thread_id"))
  Bool.pick(String,String.is_empty(spawn),identifier(field(payload,"parent_thread_id")),spawn)

def header_parts(session: String,parent: String,+category: String,time: String,fork: Maybe<&2,String>) -> Header:
  match fork:
    case None{}: Header{True{},"unknown",session,parent,"",""}
    case Some{+id}:
      Header{True{},Bool.pick(String,String.eq(category,"ordinary") && Bool.not(String.is_empty(id)),"fork",category),
        session,parent,id,time}

def decoded_header(+payload: Json.Json) -> Header:
  +session = identifier(field(payload,"id"))
  +category = Bool.pick(String,String.is_empty(session),"unknown",kind_of_source(field(payload,"source")))
  header_parts(session,parent_of(payload),category,Timestamp.value(Timestamp.parse(text(payload,"timestamp"))),
    fork_declaration(payload))

def header_same(a: Header,b: Header) -> Bool:
  Header{_,ac,as,ap,af,at} = a
  Header{_,bc,bs,bp,bf,bt} = b
  String.eq(ac,bc) && String.eq(as,bs) && String.eq(ap,bp) && String.eq(af,bf) && String.eq(at,bt)

def uncertain_stats(stats: Stats) -> Stats:
  Stats{o,a,d,r,e,u,f,l} = stats
  Stats{o,a,d,r,e,U32.inc(u),f,l}

def damaged(state: State,block: Bool) -> State:
  State{n,h,p,v,_,b,c,s} = state
  State{n,h,p,v,True{},b || block,c,uncertain_stats(s)}

def first_header(state: State,+header: Header) -> State:
  State{n,_,_,previous,interrupted,blocked,counters,+stats} = state
  Header{_,+category,_,_,+fork,_} = header
  State{n,header,Bool.pick(Phase,String.is_empty(fork),Own{"none"},Inherited{False{}}),
    previous,interrupted,blocked,counters,
    Bool.pick(Stats,String.eq(category,"unknown"),uncertain_stats(stats),stats)}

def later_header(state: State,same: Bool) -> State:
  match same:
    case True{}: state
    case False{}: damaged(state,True{})

def metadata_seen(seen: Bool,state: State,header: Header,old: Header) -> State:
  match seen:
    case False{}: first_header(state,header)
    case True{}: later_header(state,header_same(old,header))

def metadata(+state: State,payload: Json.Json) -> State:
  State{_,+old,_,_,_,_,_,_} = state
  Header{seen,_,_,_,_,_} = old
  metadata_seen(seen,state,decoded_header(payload),old)

# UTC calendar conversion is bounded to years1970..9999; the largest epoch
# millisecond fits the pinned native Nat48 range. Submillisecond precision is
# retained separately so a UUID minted just before a fractional fork cannot win.
def days_before_year(+year: Nat) -> Nat:
  +prior = Nat.sub(year,1n)
  Nat.sub(Nat.add(Nat.add(Nat.mul(prior,365n),Nat.div(prior,4n)),Nat.div(prior,400n)),Nat.div(prior,100n))

def month_days(fuel: Nat,+year: U32,+month: U32,total: Nat) -> Nat:
  match fuel:
    case 0n: total
    case 1n+rest:
      month_days(rest,year,U32.inc(month),Nat.add(total,U32.to_nat(Query.month_days(month,year))))

def parsed_time_valid(+value: String,valid: Bool) -> Maybe<&2,Time>:
  match valid:
    case False{}: None{}
    case True{}:
      +year = Timestamp.number(String.take(value,4n))
      +month = Timestamp.number(String.take(String.drop(value,5n),2n))
      day = Timestamp.number(String.take(String.drop(value,8n),2n))
      hour = Timestamp.number(String.take(String.drop(value,11n),2n))
      minute = Timestamp.number(String.take(String.drop(value,14n),2n))
      second = Timestamp.number(String.take(String.drop(value,17n),2n))
      millis = Timestamp.number(String.take(String.drop(value,20n),3n))
      nano_tail = Timestamp.number(String.take(String.drop(value,23n),6n))
      days = Nat.add(Nat.sub(days_before_year(U32.to_nat(year)),719162n),
        Nat.add(month_days(U32.to_nat(U32.sub(month,1)),year,1,0n),U32.to_nat(U32.sub(day,1))))
      seconds = Nat.add(Nat.mul(days,86400n),U32.to_nat((hour * 3600 + minute * 60 + second : U32)))
      Some{Time{Nat.add(Nat.mul(seconds,1000n),U32.to_nat(millis)),nano_tail}}

def time_result(result: Result<&2,&2,String,String>) -> Maybe<&2,Time>:
  match result:
    case Fail{_}: None{}
    case Done{+value}: parsed_time_valid(value,U32.is_ge(Timestamp.number(String.take(value,4n)),1970))

def time(value: String) -> Maybe<&2,Time>:
  time_result(Timestamp.parse(value))

def hex_lower(c: Char) -> U32:
  Chr{+cp} = c
  Bool.pick(U32,U32.is_ge(cp,48) && U32.is_le(cp,57),U32.sub(cp,48),
    Bool.pick(U32,U32.is_ge(cp,97) && U32.is_le(cp,102),U32.add(U32.sub(cp,97),10),99))

def hex(c: Char) -> U32:
  hex_lower(Char.to_lower(c))

def uuid_chars(text: String,+index: U32) -> Bool:
  match text:
    case SNil{}: U32.is_eq(index,36)
    case SCon{+c,rest}:
      Bool.pick(Bool,U32.is_eq(index,8) || U32.is_eq(index,13) || U32.is_eq(index,18) || U32.is_eq(index,23),
        Char.is_eq(c,'-'),U32.is_lt(hex(c),16)) && uuid_chars(rest,U32.inc(index))

def hex_value(text: String,acc: Nat) -> Nat:
  match text:
    case SNil{}: acc
    case SCon{c,rest}: hex_value(rest,Nat.add(Nat.mul(acc,16n),U32.to_nat(hex(c))))

def uuid_ready(+value: String,valid: Bool) -> Maybe<&2,Nat>:
  match valid:
    case False{}: None{}
    case True{}: Some{hex_value(String.take(value,8n) ++ String.take(String.drop(value,9n),4n),0n)}

def uuid_time(+value: String) -> Maybe<&2,Nat>:
  +variant = String.take(String.drop(value,19n),1n)
  uuid_ready(value,uuid_chars(value,0) && String.eq(String.take(String.drop(value,14n),1n),"7") &&
    (String.eq(variant,"8") || String.eq(variant,"9") || String.eq(String.to_lower(variant),"a") || String.eq(String.to_lower(variant),"b")))

def minted_order(minted: Maybe<&2,Nat>,forked: Maybe<&2,Time>) -> Cmp:
  match minted forked:
    case Some{+ms} Some{Time{+floor,remainder}}:
      Bool.pick(Cmp,Nat.is_gt(ms,floor) || (Nat.is_eq(ms,floor) && U32.is_zero(remainder)),GT{},LT{})
    case _ _: EQ{}

def assistant_phase(value: Found) -> Bool:
  match value:
    case Missing{}: True{}
    case Value{Json.JString{+phase}}:
      Bool.not(String.eq(phase,"final_answer") || String.eq(phase,"partial_answer"))
    case _: False{}

def never_copied_item(kind: String,+payload: Json.Json) -> Bool:
  match kind:
    case "reasoning": True{}
    case "function_call": True{}
    case "custom_tool_call": True{}
    case "custom_tool_call_output": True{}
    case "local_shell_call": True{}
    case "web_search_call": True{}
    case "image_generation_call": True{}
    case "tool_search_call": True{}
    case "tool_search_output": True{}
    case "agent_message": True{}
    case "compaction": True{}
    case "context_compaction": True{}
    case "function_call_output": Bool.not(String.is_empty(identifier(field(payload,"call_id"))))
    case "message":
      String.eq(text(payload,"role"),"assistant") && assistant_phase(lookup(payload,"phase"))
    case _: False{}

def never_copied(kind: String,+payload: Json.Json) -> Bool:
  match kind:
    case "inter_agent_communication": True{}
    case "inter_agent_communication_metadata": True{}
    case "response_item": never_copied_item(text(payload,"type"),payload)
    case _: False{}

def turn_phase(order: Cmp) -> Phase:
  match order:
    case GT{}: Starting{"uuid_v7_turn"}
    case LT{}: Inherited{True{}}
    case EQ{}: Inherited{False{}}

def fallback_phase(phase: Phase,mark: Bool) -> Phase:
  match phase:
    case Inherited{False{}}: Bool.pick(Phase,mark,Starting{"codex_0_130_record_policy"},Inherited{False{}})
    case other: other

def record_phase(phase: Phase,header: Header,+kind: String,+payload: Json.Json) -> Phase:
  match phase:
    case Inherited{copied}:
      Header{_,_,_,_,_,stamp} = header
      +turn = String.eq(kind,"event_msg") && String.eq(text(payload,"type"),"task_started")
      fallback_phase(Bool.pick(Phase,turn,
        turn_phase(minted_order(uuid_time(identifier(field(payload,"turn_id"))),time(stamp))),Inherited{copied}),
        never_copied(kind,payload))
    case other: other

def note_observation(stats: Stats,+ordinal: U32) -> Stats:
  Stats{o,a,d,r,e,u,+first,_} = stats
  Stats{U32.inc(o),a,d,r,e,u,Bool.pick(String,String.is_empty(first),U32.show(ordinal),first),U32.show(ordinal)}

def excluded_stats(stats: Stats,uncertain: Bool) -> Stats:
  Stats{o,a,d,r,e,u,f,l} = stats
  Stats{o,a,d,r,U32.inc(e),U32.add(u,Bool.to_u32(uncertain)),f,l}

def counted_stats(stats: Stats,+duplicate: Bool,reset: Bool) -> Stats:
  Stats{o,a,d,r,e,u,f,l} = stats
  Stats{o,U32.add(a,Bool.to_u32(Bool.not(duplicate))),U32.add(d,Bool.to_u32(duplicate)),
    U32.add(r,Bool.to_u32(reset)),e,u,f,l}

def excluded(state: State,unknown: Bool,interrupt: Bool) -> State:
  State{n,h,p,v,i,b,c,s} = state
  State{n,h,p,v,i || interrupt,b,c,excluded_stats(s,unknown)}

def next_owned(phase: Phase) -> Phase:
  match phase:
    case Starting{basis}: Own{basis}
    case other: other

def rebaseline(state: State,counts: Counts.Counters) -> State:
  State{n,h,p,_,_,b,c,s} = state
  State{n,h,next_owned(p),Some{counts},False{},b,c,excluded_stats(s,True{})}

def count_value(state: State,+total: Counts.Counters,value: Counts.Counters,duplicate: Bool,reset: Bool) -> State:
  State{n,h,p,_,_,b,c,s} = state
  State{n,h,next_owned(p),Some{total},False{},b,Counts.sum(c,value),counted_stats(s,duplicate,reset)}

def call_matches(call: Maybe<&2,Counts.Counters>,total: Counts.Counters) -> Bool:
  match call:
    case None{}: False{}
    case Some{value}: Counts.equal(value,total)

def call_or_total(call: Maybe<&2,Counts.Counters>,total: Counts.Counters) -> Counts.Counters:
  match call:
    case None{}: total
    case Some{value}: value

def normal_pair(state: State,+total: Counts.Counters,+call: Maybe<&2,Counts.Counters>,+before: Counts.Counters) -> State:
  +duplicate = Counts.equal(total,before)
  +reset = Bool.not(duplicate) && (Counts.backwards(total,before) || call_matches(call,total))
  count_value(state,total,Bool.pick(Counts.Counters,duplicate,Counts.Counters{"0","0","","","0"},
    Bool.pick(Counts.Counters,reset,call_or_total(call,total),Counts.delta(total,before))),duplicate,reset)

def starting_delta(+state: State,+total: Counts.Counters,+before: Counts.Counters) -> State:
  Bool.pick(State,Counts.backwards(total,before),rebaseline(state,total),
    count_value(state,total,Counts.delta(total,before),False{},False{}))

def starting_count(state: State,+total: Counts.Counters,call: Maybe<&2,Counts.Counters>,previous: Maybe<&2,Counts.Counters>) -> State:
  match call previous:
    case Some{value} _: count_value(state,total,value,False{},False{})
    case None{} Some{before}: starting_delta(state,total,before)
    case None{} None{}: rebaseline(state,total)

def normal_count(previous: Maybe<&2,Counts.Counters>,state: State,+total: Counts.Counters,call: Maybe<&2,Counts.Counters>) -> State:
  match previous:
    case None{}: count_value(state,total,total,False{},False{})
    case Some{before}: normal_pair(state,total,call,before)

def count_phase(interrupted: Bool,phase: Phase,state: State,total: Counts.Counters,call: Maybe<&2,Counts.Counters>,previous: Maybe<&2,Counts.Counters>) -> State:
  match interrupted phase:
    case True{} _: rebaseline(state,total)
    case False{} Inherited{_}:
      State{n,h,p,_,i,b,c,s} = state
      State{n,h,p,Some{total},i,b,c,excluded_stats(s,False{})}
    case False{} Starting{_}: starting_count(state,total,call,previous)
    case False{} Own{_}: normal_count(previous,state,total,call)

def eligible_count(+state: State,total: Counts.Counters,call: Maybe<&2,Counts.Counters>) -> State:
  State{_,_,phase,previous,interrupted,_,_,_} = state
  count_phase(interrupted,phase,state,total,call,previous)

def allowed(state: State) -> Bool:
  State{_,Header{seen,category,_,_,_,_},_,_,_,blocked,_,_} = state
  seen && Bool.not(blocked) && Bool.not(String.eq(category,"unknown"))

def total_ready(+state: State,total: Maybe<&2,Counts.Counters>,call: Result<&2,&2,Unit,Maybe<&2,Counts.Counters>>) -> State:
  match total call:
    case Some{counts} Done{last}:
      Bool.pick(State,allowed(state),eligible_count(state,counts,last),excluded(state,True{},True{}))
    case _ _: excluded(state,True{},True{})

def call_decoded(value: Maybe<&2,Counts.Counters>) -> Result<&2,&2,Unit,Maybe<&2,Counts.Counters>>:
  match value:
    case None{}: Fail{Unit{}}
    case Some{value}: Done{Some{value}}

def optional_call(value: Found) -> Result<&2,&2,Unit,Maybe<&2,Counts.Counters>>:
  match value:
    case Missing{}: Done{None{}}
    case Value{Json.JNull{}}: Done{None{}}
    case Value{value}: call_decoded(Counts.codex(value))
    case Invalid{}: Fail{Unit{}}

def token_info(state: State,info: Found) -> State:
  match info:
    case Value{Json.JNull{}}: excluded(state,False{},False{})
    case Value{+value}:
      total_ready(state,Counts.codex(field(value,"total_token_usage")),optional_call(lookup(value,"last_token_usage")))
    case _: excluded(state,True{},True{})

def token(state: State,ordinal: U32,payload: Json.Json) -> State:
  State{n,h,p,v,i,b,c,s} = state
  token_info(State{n,h,p,v,i,b,c,note_observation(s,ordinal)},lookup(payload,"info"))

def ordinary_record(is_token: Bool,state: State,ordinal: U32,kind: String,payload: Json.Json) -> State:
  match is_token:
    case True{}: token(state,ordinal,payload)
    case False{}:
      State{n,+h,p,v,i,b,c,s} = state
      State{n,h,record_phase(p,h,kind,payload),v,i,b,c,s}

def record_kind(+kind: String,state: State,ordinal: U32,+payload: Json.Json) -> State:
  match kind:
    case "session_meta": metadata(state,payload)
    case _:
      ordinary_record(String.eq(kind,"event_msg") && String.eq(text(payload,"type"),"token_count"),state,ordinal,kind,payload)

def required_payload(kind: String) -> Bool:
  match kind:
    case "session_meta": True{}
    case "turn_context": True{}
    case "response_item": True{}
    case "event_msg": True{}
    case "compacted": True{}
    case "inter_agent_communication": True{}
    case "inter_agent_communication_metadata": True{}
    case _: False{}

def nested_type_valid(kind: String,payload: Json.Json) -> Bool:
  match kind:
    case "event_msg": Bool.not(String.is_empty(text(payload,"type")))
    case "response_item": Bool.not(String.is_empty(text(payload,"type")))
    case _: True{}

def payload_ready(valid: Bool,kind: String,state: State,ordinal: U32,payload: Json.Json) -> State:
  match valid:
    case True{}: record_kind(kind,state,ordinal,payload)
    case False{}: damaged(state,False{})

def invalid_payload(+kind: String,+state: State) -> State:
  match kind:
    case "session_meta": metadata(state,Json.JNull{})
    case _: Bool.pick(State,required_payload(kind),damaged(state,False{}),state)

def record_payload(+kind: String,state: State,ordinal: U32,payload: Found) -> State:
  match payload:
    case Value{Json.JObject{+fields}}:
      payload_ready(nested_type_valid(kind,Json.JObject{fields}),kind,state,ordinal,Json.JObject{fields})
    case _: invalid_payload(kind,state)

def record_string(valid: Bool,kind: String,state: State,ordinal: U32,raw: Json.Json) -> State:
  match valid:
    case True{}: record_payload(kind,state,ordinal,lookup(raw,"payload"))
    case False{}: damaged(state,False{})

def record_type(value: Found,state: State,ordinal: U32,raw: Json.Json) -> State:
  match value:
    case Value{Json.JString{+kind}}:
      record_string(Bool.not(String.is_empty(kind)) && required_payload(kind),kind,state,ordinal,raw)
    case _: damaged(state,False{})

def record(state: State,ordinal: U32,+raw: Json.Json) -> State:
  record_type(lookup(raw,"type"),state,ordinal,raw)

def advance(state: State) -> State:
  State{n,h,p,v,i,b,c,s} = state
  State{U32.inc(n),h,p,v,i,b,c,s}

def ordered(+state: State,+ordinal: U32) -> Bool:
  State{next,_,_,_,_,_,_,_} = state
  U32.is_eq(next,ordinal) && U32.is_lt(ordinal,4294967295)

def observed(state: State,ordinal: U32,raw: Json.Json,valid: Bool) -> State:
  match valid:
    case False{}: damaged(state,True{})
    case True{}: record(advance(state),ordinal,raw)

def observe(+state: State,+ordinal: U32,raw: Json.Json) -> State:
  observed(state,ordinal,raw,ordered(state,ordinal))

def invalid_ordered(state: State,valid: Bool) -> State:
  match valid:
    case False{}: damaged(state,True{})
    case True{}: damaged(advance(state),False{})

def invalid(+state: State,ordinal: U32) -> State:
  invalid_ordered(state,ordered(state,ordinal))

def phase_basis(phase: Phase) -> String:
  match phase:
    case Inherited{_}: "unresolved"
    case Starting{basis}: basis
    case Own{basis}: basis

def phase_complete(phase: Phase) -> Bool:
  match phase:
    case Own{basis}: Bool.not(String.eq(basis,"codex_0_130_record_policy"))
    case _: False{}

def report(state: State) -> Report:
  State{_,Header{seen,+category,session,parent,_,_},+phase,_,interrupted,blocked,+accounted,
    Stats{observations,accepted,duplicates,resets,excluded,+uncertain,first,last}} = state
  Report{category,session,parent,phase_basis(phase),accounted,observations,accepted,duplicates,resets,excluded,uncertain,first,last,
    seen && Bool.not(String.eq(category,"unknown")) && Bool.not(interrupted || blocked) && U32.is_zero(uncertain) &&
      Counts.complete_codex(accounted) && phase_complete(phase)}
