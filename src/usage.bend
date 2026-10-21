import Base
import ./domain.bend as Domain
import ./json.bend as Json
import ./providers.bend as Providers
import ./provenance.bend as Provenance
import ./store.bend as Store
import ./sql.bend as Sql
import ./evidence.bend as Evidence

# Counts are canonical decimal strings. Bend Nat.read has a smaller bound than
# some provider integers; digit arithmetic avoids rounding or narrowing them.
type Counters is Data:
  Counters{input: String,cached: String,created: String,output: String,total: String}

type Observation is Data:
  Observation{ordinal: String,citation: String,value: Json.Json,coverage: String}

type Call is Data:
  Call{key: String,counts: Counters}

type Claude is Data:
  Claude{calls: List<&2,Call>,excluded: U32,facts: String}

type Codex is Data:
  Codex{previous: Maybe<&2,Counters>,delta: Counters,pairs: U32,resets: U32,
    inherited: Bool,facts: String}

def empty() -> Counters:
  Counters{"","","","",""}

def shown(+value: String) -> String:
  Bool.pick(String,String.is_empty(value),"unknown",value)

def digit(c: Char) -> U32:
  Chr{value} = c
  U32.sub(value,48)

def add_step(+sum: U32,rest: String) -> String:
  SCon{Chr{U32.add(48,U32.mod(sum,10))},rest}

def add_reversed(a: String,b: String,carry: U32) -> String:
  match a b:
    case SNil{} SNil{}:
      Bool.pick(String,U32.is_eq(carry,0),"","1")
    case SCon{x,xs} SNil{}:
      +sum = U32.add(digit(x),carry)
      add_step(sum,add_reversed(xs,"",U32.div(sum,10)))
    case SNil{} SCon{y,ys}:
      +sum = U32.add(digit(y),carry)
      add_step(sum,add_reversed("",ys,U32.div(sum,10)))
    case SCon{x,xs} SCon{y,ys}:
      +sum = U32.add(U32.add(digit(x),digit(y)),carry)
      add_step(sum,add_reversed(xs,ys,U32.div(sum,10)))

def add(a: String,b: String) -> String:
  String.reverse(add_reversed(String.reverse(a),String.reverse(b),0))

def subtract_reversed(a: String,b: String,borrow: U32) -> String:
  match a b:
    case SNil{} _:
      ""
    case SCon{x,xs} SNil{}:
      +n = U32.sub(U32.add(digit(x),10),borrow)
      SCon{Chr{U32.add(48,U32.mod(n,10))},
        subtract_reversed(xs,"",Bool.to_u32(U32.is_lt(n,10)))}
    case SCon{x,xs} SCon{y,ys}:
      +n = U32.sub(U32.sub(U32.add(digit(x),10),borrow),digit(y))
      SCon{Chr{U32.add(48,U32.mod(n,10))},
        subtract_reversed(xs,ys,Bool.to_u32(U32.is_lt(n,10)))}

def trim_zero(value: String) -> String:
  match value:
    case SCon{'0',SCon{c,rest}}:
      trim_zero(SCon{c,rest})
    case other:
      other

def subtract(a: String,b: String) -> String:
  trim_zero(String.reverse(subtract_reversed(String.reverse(a),String.reverse(b),0)))

def number(value: Json.Json) -> String:
  match value:
    case Json.JNumber{+text}:
      Bool.pick(String,Provenance.decimal_valid(text) && Nat.is_le(String.length(text),64n),
        text,"")
    case _:
      ""

def maximum(+a: String,+b: String) -> String:
  Bool.pick(String,Cmp.is_ge(Provenance.decimal_compare(a,b)),a,b)

def known_add(+a: String,+b: String) -> String:
  Bool.pick(String,String.is_empty(a),b,
    Bool.pick(String,String.is_empty(b),a,add(a,b)))

def merge_max(a: Counters,b: Counters) -> Counters:
  Counters{ai,ac,ar,ao,at} = a
  Counters{bi,bc,br,bo,bt} = b
  Counters{maximum(ai,bi),maximum(ac,bc),maximum(ar,br),maximum(ao,bo),maximum(at,bt)}

def sum(a: Counters,b: Counters) -> Counters:
  Counters{ai,ac,ar,ao,at} = a
  Counters{bi,bc,br,bo,bt} = b
  Counters{known_add(ai,bi),known_add(ac,bc),known_add(ar,br),known_add(ao,bo),known_add(at,bt)}

def claude_counts(+usage: Json.Json) -> Counters:
  Counters{number(Json.field(usage,"input_tokens")),
    number(Json.field(usage,"cache_read_input_tokens")),
    number(Json.field(usage,"cache_creation_input_tokens")),
    number(Json.field(usage,"output_tokens")),""}

def codex_counts(+usage: Json.Json) -> Counters:
  Counters{number(Json.field(usage,"input_tokens")),
    number(Json.field(usage,"cached_input_tokens")),"",
    number(Json.field(usage,"output_tokens")),number(Json.field(usage,"total_tokens"))}

def counts_text(value: Counters) -> String:
  Counters{input,cached,created,output,total} = value
  "input_tokens: " ++ shown(input) ++ "\ncache_read/cached_input_tokens: " ++ shown(cached) ++
    "\ncache_creation_input_tokens: " ++ shown(created) ++ "\noutput_tokens: " ++ shown(output) ++
    "\ntotal_tokens (only if recorded): " ++ shown(total) ++ "\n"

def put_call(calls: List<&2,Call>,+key: String,+counts: Counters) -> List<&2,Call>:
  match calls:
    case []:
      [Call{key,counts}]
    case Call{+old,+prior} <> +rest:
      Bool.pick(List<&2,Call>,String.eq(key,old),
        Call{old,merge_max(prior,counts)} <> rest,
        Call{old,prior} <> put_call(rest,key,counts))

def sum_calls(calls: List<&2,Call>,acc: Counters) -> Counters:
  match calls:
    case []:
      acc
    case Call{_,counts} <> rest:
      sum_calls(rest,sum(acc,counts))

def present(value: Json.Json) -> Bool:
  match value:
    case Json.JNull{}:
      False{}
    case _:
      True{}

def identifier(value: Json.Json) -> String:
  match value:
    case Json.JString{text}:
      text
    case _:
      ""

def fact(ordinal: String,citation: String,usage: Json.Json) -> String:
  "Record " ++ ordinal ++ "\nRecorded usage (up to 2048 characters; full raw retained): " ++ String.take(Json.encode(usage),2048n) ++
    "\n" ++ citation ++ "\n\n"

def claude_usage(state: Claude,+root: Json.Json,+usage: Json.Json,
  ordinal: String,citation: String) -> Claude:
  Claude{+calls,+excluded,facts} = state
  +id = identifier(Json.field(Json.field(root,"message"),"id"))
  +session = Store.nonempty(identifier(Json.field(root,"sessionId")),
    identifier(Json.field(root,"session_id")))
  +key = Json.encode(Json.JArray{[Json.JString{session},Json.JString{id}]})
  +missing = String.is_empty(id)
  Claude{Bool.pick(List<&2,Call>,missing,calls,put_call(calls,key,claude_counts(usage))),
    U32.add(excluded,Bool.to_u32(missing)),facts ++ fact(ordinal,citation,usage)}

def claude_record(+state: Claude,observation: Observation) -> Claude:
  Observation{ordinal,citation,+root,coverage} = observation
  +usage = Json.field(Json.field(root,"message"),"usage")
  Bool.pick(Claude,String.eq(Json.get(root,"type"),"assistant") && present(usage),
    claude_usage(state,root,usage,ordinal,citation),state)

def claude_walk(rows: List<&2,Observation>,state: Claude) -> Claude:
  match rows:
    case []:
      state
    case row <> rest:
      claude_walk(rest,claude_record(state,row))

def claude_render(state: Claude) -> String:
  Claude{+calls,excluded,facts} = state
  "Claude known recorded bucket subtotals within this selected range:\n" ++
    counts_text(sum_calls(calls,empty())) ++
    "Distinct observed message.id keys: " ++ Nat.show(List.length(&2,Call,calls)) ++
    "\nUsage records excluded for missing message.id: " ++ U32.show(excluded) ++
    "\nRepeated records use each message.id bucket maximum, never a sum of mirrors." ++
    "\nUnknown/missing/non-integer buckets are not treated as zero. These are known-value subtotals, not complete session usage." ++
    "\nCache buckets are shown separately; no combined token/billing estimate is inferred.\n\n" ++ facts

def claude_report(rows: List<&2,Observation>) -> String:
  claude_render(claude_walk(rows,Claude{[],0,""}))

def decreased(+a: String,+b: String) -> Bool:
  Bool.not(String.is_empty(a)) && Bool.not(String.is_empty(b)) &&
    Cmp.is_lt(Provenance.decimal_compare(a,b))

def backwards(a: Counters,b: Counters) -> Bool:
  Counters{ai,ac,_,ao,at} = a
  Counters{bi,bc,_,bo,bt} = b
  decreased(ai,bi) || decreased(ac,bc) || decreased(ao,bo) || decreased(at,bt)

def delta_field(+a: String,+b: String) -> String:
  Bool.pick(String,String.is_empty(a) || String.is_empty(b),"",subtract(a,b))

def difference(a: Counters,b: Counters) -> Counters:
  Counters{ai,ac,_,ao,at} = a
  Counters{bi,bc,_,bo,bt} = b
  Counters{delta_field(ai,bi),delta_field(ac,bc),"",delta_field(ao,bo),delta_field(at,bt)}

def comparable(value: Counters) -> Bool:
  Counters{input,_,_,output,total} = value
  Bool.not(String.is_empty(input)) && Bool.not(String.is_empty(output)) &&
    Bool.not(String.is_empty(total))

def codex_pair(state: Codex,+counts: Counters) -> Codex:
  Codex{previous,+delta,+pairs,+resets,inherited,facts} = state
  match previous:
    case None{}:
      Codex{Some{counts},delta,pairs,resets,inherited,facts}
    case Some{+before}:
      +usable = comparable(counts) && comparable(before) && Bool.not(backwards(counts,before))
      Codex{Some{counts},Bool.pick(Counters,usable,sum(delta,difference(counts,before)),delta),
        U32.add(pairs,Bool.to_u32(usable)),U32.add(resets,Bool.to_u32(Bool.not(usable))),
        inherited,facts}

def forked(+value: Json.Json) -> Bool:
  present(Json.field(value,"forked_from_id")) ||
    present(Json.field(value,"forked_from_session_id")) ||
    present(Json.field(value,"forked_from")) ||
    present(Json.field(value,"forked_from_session")) ||
    present(Json.field(value,"parent_thread_id")) || present(Json.field(value,"parent_id")) ||
    present(Json.field(Json.field(value,"source"),"parent_thread_id")) ||
    present(Json.field(Json.field(value,"source"),"subagent"))

def codex_observation(state: Codex,+info: Json.Json,ordinal: String,citation: String) -> Codex:
  Codex{previous,delta,pairs,resets,inherited,facts} = state
  codex_pair(Codex{previous,delta,pairs,resets,inherited,
    facts ++ fact(ordinal,citation,info)},codex_counts(Json.field(info,"total_token_usage")))

def codex_record(state: Codex,observation: Observation) -> Codex:
  Codex{previous,delta,pairs,resets,+inherited,facts} = state
  Observation{ordinal,citation,+root,coverage} = observation
  +payload = Json.field(root,"payload")
  +next = {Codex{previous,delta,pairs,resets,
    inherited || forked(root) || forked(payload),facts} : Codex}
  Bool.pick(Codex,String.eq(Json.get(root,"type"),"event_msg") &&
    String.eq(Json.get(payload,"type"),"token_count"),
    codex_observation(next,Json.field(payload,"info"),ordinal,citation),next)

def codex_walk(rows: List<&2,Observation>,state: Codex) -> Codex:
  match rows:
    case []:
      state
    case row <> rest:
      codex_walk(rest,codex_record(state,row))

def codex_render(state: Codex) -> String:
  Codex{_,delta,pairs,resets,+fork,facts} = state
  "Codex recorded cumulative observations; last_token_usage is retained as a fact, never summed.\n" ++
    Bool.pick(String,fork,
      "Fork/inherited or unknown session metadata: all subtotal attribution excluded.\n",
      "Known adjacent cumulative deltas in this selected range (first baseline excluded):\n" ++
        counts_text(delta)) ++
    "Valid adjacent pairs: " ++ U32.show(pairs) ++
    "\nCounter resets/unknown pairs excluded: " ++ U32.show(resets) ++
    "\nDuplicate cumulative observations contribute zero. Cached input is a subset, not added to input." ++
    "\nFirst cumulative totals may include prior/inherited usage and never count as new usage." ++
    "\nNo full-session, billing or quota claim.\n\n" ++ facts

def codex_report(rows: List<&2,Observation>,inherited: Bool) -> String:
  codex_render(codex_walk(rows,Codex{None{},empty(),0,0,inherited,""}))

def decoded_json(provider: String,ordinal: String,citation: String,
  result: Result<&2,&2,String,Json.Json>) -> Observation:
  match result:
    case Fail{error}:
      Observation{ordinal,citation,Json.JNull{},"malformed_json"}
    case Done{+value}:
      Observation{ordinal,Bool.pick(String,
        List.is_empty(&2,Providers.Record,Providers.normalized(provider,value)),
        "No normalized event citation is available for this raw usage observation.",citation),
        value,"complete"}

def decoded(provider: String,ordinal: String,citation: String,
  result: Result<&2,&2,String,String>) -> Observation:
  match result:
    case Fail{error}:
      Observation{ordinal,citation,Json.JNull{},"invalid_utf8"}
    case Done{text}:
      decoded_json(provider,ordinal,citation,Json.parse(text))

def observation(+row: List<&2,Sql.Cell>,+provider: String,source: String,
  generation: String,snapshot: String,extent: String,+ordinal: U32) -> Observation:
  +citation = Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,extent,
    U32.show(ordinal),[]},0)
  Bool.pick(Observation,String.eq(Store.field(row,6n),"1"),
    Observation{U32.show(ordinal),citation,Json.JNull{},"oversized_record_fragment"},
    decoded(provider,U32.show(ordinal),citation,Domain.decode(Store.blob(Store.cell(row,5n)))))

def load(left: Nat,+db: U32,+provider: String,+source: String,+generation: String,
  +snapshot: String,+extent: U32,+records: U32,+ordinal: U32) -> IO(List<&2,Observation>):
  match left:
    case 0n:
      IO.pure(List<&2,Observation>,[])
    case 1n+rest:
      do IO<List<&2,Observation>>:
        raw : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,extent,records,ordinal)
        tail : List<&2,Observation> <- load(rest,db,provider,source,generation,snapshot,
          extent,records,U32.add(ordinal,1))
        return observation(raw,provider,source,generation,snapshot,U32.show(extent),ordinal) <> tail

def metadata_unknown(observation: Observation) -> Bool:
  Observation{_,_,+value,coverage} = observation
  Bool.not(String.eq(coverage,"complete")) ||
    Bool.not(String.eq(Json.get(value,"type"),"session_meta")) ||
    forked(value) || forked(Json.field(value,"payload"))

def partial_count(rows: List<&2,Observation>) -> U32:
  match rows:
    case []:
      0
    case Observation{_,_,_,coverage} <> rest:
      U32.add(Bool.to_u32(Bool.not(String.eq(coverage,"complete"))),partial_count(rest))

def render(provider: String,+rows: List<&2,Observation>,first: Observation,
  +start: U32,count: U32,records: U32) -> String:
  "Juice Bend · recorded usage evidence\nSelected captured records " ++ U32.show(start) ++
    " through " ++ U32.show(U32.add(start,count)) ++ " (exclusive), of " ++ U32.show(records) ++
    ". Maximum 100 records. This range is not a whole-session usage total.\n" ++
    "Unsupported/malformed selected records excluded: " ++ U32.show(partial_count(rows)) ++ "\n\n" ++
    Bool.pick(String,String.eq(provider,"claude"),claude_report(rows),
      codex_report(rows,metadata_unknown(first)))

def render_first(provider: String,rows: List<&2,Observation>,first: List<&2,Observation>,
  start: U32,count: U32,records: U32) -> IO(String):
  match first:
    case []:
      IO.pure(String,"No captured records; usage unknown.")
    case head <> _:
      IO.pure(String,render(provider,rows,head,start,count,records))

def summary_rows(+db: U32,+snapshot: String,+start: U32,count: U32,
  rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case []:
      IO.pure(String,"Usage unavailable: accepted snapshot not captured.")
    case +meta <> _:
      +records = Store.number(Store.field(meta,2n))
      +extent = Store.number(Store.field(meta,1n))
      +selected = Domain.bounded_count(start,U32.min(count,100),records)
      +generation = Store.field(meta,0n)
      +provider = Store.field(meta,3n)
      +source = Store.field(meta,4n)
      do IO<String>:
        Store.checked(Store.numeric(Store.field(meta,1n)) && Store.numeric(Store.field(meta,2n)),
          "Usage snapshot numeric metadata is corrupt")
        loaded : List<&2,Observation> <- load(U32.to_nat(selected),db,provider,source,
          generation,snapshot,extent,records,start)
        first : List<&2,Observation> <- load(U32.to_nat(U32.min(records,1)),db,provider,source,
          generation,snapshot,extent,records,0)
        text : String <- render_first(provider,loaded,first,start,selected,records)
        return "Snapshot " ++ snapshot ++ " · provider " ++ provider ++ "\n" ++ text

def summary(+db: U32,+snapshot: String,start: U32,count: U32) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.generation,p.extent,p.records,s.provider,s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    summary_rows(db,snapshot,start,count,rows)
