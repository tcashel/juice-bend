import Base
import ./json.bend as Json
import ./domain.bend as Domain
import ./timestamp.bend as Timestamp
import ./session_usage_counts.bend as Counts

# An exact-key Patricia map, bounded by key count and logical descriptor UTF8
# bytes. Those byte counts are NOT native heap or RSS measurements.
type Call is Data:
  Call{session: String,model: String,hour: String,counts: Counts.Counters,group: U32,conflict: Bool}

type Bucket is Data:
  Bucket{sum: String,known: U32}

type Total is Data:
  Total{buckets: List<&2,Bucket>}

type State is Data:
  State{calls: Map<&2,Maybe<&2,Call>>,own_session: String,keys: U32,descriptor_bytes: U32,
    observed: Total,own: Total,copied: Total,unattributed: Total,
    usage_records: U32,missing_ids: U32,incomplete: U32,conflicts: U32,mirrors: U32}

type Update is Data:
  Accepted{state: State,issue: String}
  Limited{state: State,reason: String}

type Change is Data:
  Change{before: Call,after: Call,fresh: Bool}

type Report is Data:
  Report{own_session: String,keys: U32,descriptor_bytes: U32,observed: Counts.Counters,
    own: Counts.Counters,copied: Counts.Counters,unattributed: Counts.Counters,
    usage_records: U32,missing_ids: U32,incomplete: U32,conflicts: U32,mirrors: U32,
    bucket_complete: Bool,attribution_complete: Bool}

def empty_total() -> Total:
  Total{[Bucket{"0",0},Bucket{"0",0},Bucket{"0",0},Bucket{"0",0},Bucket{"0",0}]}

def new(own_session: String) -> State:
  State{Map.new(&2,Maybe<&2,Call>),own_session,0,0,empty_total(),empty_total(),empty_total(),empty_total(),0,0,0,0,0}

def byte_step(ok: Bool,left: U32,next: U32 -> Maybe<&2,U32>) -> Maybe<&2,U32>:
  match ok:
    case False{}: None{}
    case True{}: next(left)

def remaining(text: String,+budget: U32) -> Maybe<&2,U32>:
  match text:
    case SNil{}: Some{budget}
    case SCon{Chr{+cp},rest}:
      +width = U32.inc(Domain.encode_width(cp))
      byte_step(Domain.scalar(cp) && U32.is_le(width,budget),U32.sub(budget,width),
        left => remaining(rest,left))

def fits_result(value: Maybe<&2,U32>) -> Bool:
  match value:
    case None{}: False{}
    case Some{_}: True{}

def identifier(+text: String) -> Bool:
  Bool.not(String.is_empty(text)) && Bool.not(String.contains(text,"\0")) && fits_result(remaining(text,512))

def text(value: Json.Json) -> String:
  match value:
    case Json.JString{value}: value
    case _: ""

def id(value: Json.Json) -> String:
  +value = text(value)
  Bool.pick(String,identifier(value),value,"")

def hour(value: Json.Json) -> String:
  +normalized = Timestamp.value(Timestamp.parse(text(value)))
  Bool.pick(String,String.is_empty(normalized),"",String.take(normalized,13n) ++ ":00:00Z")

def group(+session: String,+own: String) -> U32:
  Bool.pick(U32,String.is_empty(session) || String.is_empty(own),2,
    Bool.pick(U32,String.eq(session,own),0,1))

def bucket_remove(bucket: Bucket,+value: String) -> Bucket:
  Bucket{+sum,+known} = bucket
  Bool.pick(Bucket,String.is_empty(value),Bucket{sum,known},
    Bucket{Counts.subtract(sum,value),U32.sub(known,1)})

def bucket_add(bucket: Bucket,+value: String) -> Bucket:
  Bucket{+sum,+known} = bucket
  Bool.pick(Bucket,String.is_empty(value),Bucket{sum,known},Bucket{Counts.add(sum,value),U32.inc(known)})

def replace_buckets(buckets: List<&2,Bucket>,before: List<&2,String>,after: List<&2,String>) -> List<&2,Bucket>:
  match buckets before after:
    case bucket <> rest old <> olds value <> values:
      bucket_add(bucket_remove(bucket,old),value) <> replace_buckets(rest,olds,values)
    case _ _ _: []

def replace(total: Total,before: Counts.Counters,after: Counts.Counters) -> Total:
  Total{buckets} = total
  Total{replace_buckets(buckets,Counts.fields(before),Counts.fields(after))}

def group_replace(+wanted: U32,total: Total,+before: Call,+after: Call) -> Total:
  Call{_,_,_,old,oldgroup,_} = before
  Call{_,_,_,new,newgroup,_} = after
  replace(total,Bool.pick(Counts.Counters,U32.is_eq(wanted,oldgroup),old,Counts.empty()),
    Bool.pick(Counts.Counters,U32.is_eq(wanted,newgroup),new,Counts.empty()))

def shown(bucket: Bucket) -> String:
  Bucket{sum,known} = bucket
  Bool.pick(String,U32.is_eq(known,0),"",sum)

def values(total: Total) -> Counts.Counters:
  Total{buckets} = total
  match buckets:
    case [a,b,c,d,e]: Counts.Counters{shown(a),shown(b),shown(c),shown(d),shown(e)}
    case _: Counts.empty()

def descriptor(+key: String,call: Call) -> List<&2,String>:
  Call{session,model,hour,counts,group,conflict} = call
  key <> session <> model <> hour <> U32.show(group) <> Bool.pick(String,conflict,"true","false") <>
    Counts.fields(counts)

def fields_remaining(fields: List<&2,String>,budget: U32) -> Maybe<&2,U32>:
  match fields:
    case []: Some{budget}
    case field <> rest:
      do Maybe<&2,U32>:
        left : U32 <- remaining(field,budget)
        fields_remaining(rest,left)

def bytes_result(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{left}: U32.sub(8192,left)
    case None{}: 8192

def bytes(key: String,call: Call) -> U32:
  bytes_result(fields_remaining(descriptor(key,call),8192))

def different(+a: String,+b: String) -> Bool:
  Bool.not(String.is_empty(a)) && Bool.not(String.is_empty(b)) && Bool.not(String.eq(a,b))

def call_counts(call: Call) -> Counts.Counters:
  Call{_,_,_,counts,_,_} = call
  counts

def call_group(call: Call) -> U32:
  Call{_,_,_,_,group,_} = call
  group

def call_conflict(call: Call) -> Bool:
  Call{_,_,_,_,_,conflict} = call
  conflict

def updated(prior: Maybe<&2,Call>,+session: String,+model: String,+at: String,counts: Counts.Counters,own: String) -> Change:
  match prior:
    case None{}:
      Change{Call{"","","",Counts.empty(),2,False{}},Call{session,model,at,counts,group(session,own),False{}},True{}}
    case Some{Call{+original,+first_model,+first_hour,+old,+kind,+conflict}}:
      +ambiguous = conflict || different(original,session) ||
        (String.is_empty(original) && Bool.not(String.is_empty(session))) || different(first_model,model) ||
        (Bool.not(String.is_empty(first_hour)) && Bool.not(String.is_empty(at)) && String.is_lt(at,first_hour))
      Change{Call{original,first_model,first_hour,old,kind,conflict},
        Call{original,first_model,first_hour,Counts.maxima(old,counts),Bool.pick(U32,ambiguous,2,kind),
          ambiguous},False{}}

def missing(state: State,issue: String) -> Update:
  State{calls,own,keys,bytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors} = state
  Accepted{State{calls,own,keys,bytes,all,total,copied,unknown,U32.inc(records),U32.inc(missing),
    U32.inc(incomplete),conflicts,mirrors},issue}

def apply(valid: Bool,state: State,key: String,+before: Call,+after: Call,+fresh: Bool,newbytes: U32,
  complete: Bool,issue: String) -> Update:
  match valid:
    case False{}: Limited{state,"Claude exact-key or logical descriptor-byte limit reached"}
    case True{}:
      State{calls,own,keys,_,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors} = state
      Accepted{State{Map.set(&2,Maybe<&2,Call>,calls,key,Some{after}),own,
        U32.add(keys,Bool.to_u32(fresh)),newbytes,replace(all,call_counts(before),call_counts(after)),
        group_replace(0,total,before,after),group_replace(1,copied,before,after),group_replace(2,unknown,before,after),
        U32.inc(records),missing,U32.add(incomplete,Bool.to_u32(Bool.not(complete))),
        U32.add(conflicts,Bool.to_u32(call_conflict(after) && Bool.not(call_conflict(before)))),
        U32.add(mirrors,Bool.to_u32(Bool.not(fresh)))},issue}

def found_updated(state: State,change: Change,+key: String,+counts: Counts.Counters,
  +split_valid: Bool,maxkeys: U32,+maxbytes: U32) -> Update:
  State{map,own,+keys,+oldbytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors} = state
  Change{+before,+after,+fresh} = change
  +previous = Bool.pick(U32,fresh,0,bytes(key,before))
  +replacement = bytes(key,after)
  +base = U32.sub(oldbytes,previous)
  +issue = Bool.pick(String,call_conflict(after),"conflicting Claude call origin/model/hour; first fields retained",
    Bool.pick(String,U32.is_eq(call_group(after),2),"Claude call has no unambiguous source-session attribution",
      Bool.pick(String,Counts.complete_claude(counts) && split_valid,"","Claude usage has unknown or malformed buckets")))
  apply((Bool.not(fresh) || U32.is_lt(keys,maxkeys)) && U32.is_le(base,maxbytes) &&
    U32.is_le(replacement,U32.sub(maxbytes,base)),
    State{map,own,keys,oldbytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors},
    key,before,after,fresh,U32.add(base,replacement),Counts.complete_claude(counts) && split_valid,issue)

def found(got: Map<&2,Maybe<&2,Call>> & Maybe<&2,Call>,state: State,key: String,session: String,model: String,at: String,
  +counts: Counts.Counters,split_valid: Bool,maxkeys: U32,maxbytes: U32) -> Update:
  (map,prior) = got
  State{_,+own,keys,oldbytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors} = state
  found_updated(State{map,own,keys,oldbytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors},
    updated(prior,session,model,at,counts,own),key,counts,split_valid,maxkeys,maxbytes)

def keyed(valid: Bool,+key: String,+root: Json.Json,+usage: Json.Json,state: State,maxkeys: U32,maxbytes: U32) -> Update:
  match valid:
    case False{}: missing(state,"Claude usage missing a bounded typed message.id; excluded from deduplicated totals")
    case True{}:
      State{map,own,keys,bytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors} = state
      found(Map.get(Maybe<&2,Call>,None{},map,key),
        State{Map.new(&2,Maybe<&2,Call>),own,keys,bytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors},
        key,id(Counts.field(root,"sessionId")),id(Counts.field(Counts.field(root,"message"),"model")),
        hour(Counts.field(root,"timestamp")),Counts.claude(usage),Counts.claude_split_valid(usage),maxkeys,maxbytes)

def malformed(state: State,usage: Bool,issue: String) -> Update:
  State{calls,own,keys,bytes,all,total,copied,unknown,records,missing,incomplete,conflicts,mirrors} = state
  Accepted{State{calls,own,keys,bytes,all,total,copied,unknown,U32.add(records,Bool.to_u32(usage)),missing,
    U32.inc(incomplete),conflicts,mirrors},issue}

def with_usage(value: Counts.Field,+root: Json.Json,state: State,maxkeys: U32,maxbytes: U32) -> Update:
  match value:
    case Counts.Absent{}: Accepted{state,""}
    case Counts.Present{Json.JObject{fields}}:
      +key = id(Counts.field(Counts.field(root,"message"),"id"))
      keyed(Bool.not(String.is_empty(key)),key,root,Json.JObject{fields},state,maxkeys,maxbytes)
    case _: malformed(state,True{},"Claude message.usage is duplicated or not an object; accounting is incomplete")

def message(value: Json.Json,root: Json.Json,state: State,maxkeys: U32,maxbytes: U32) -> Update:
  match value:
    case Json.JObject{fields}: with_usage(Counts.select(fields,"usage",Counts.Absent{}),root,state,maxkeys,maxbytes)
    case _: malformed(state,False{},"Claude assistant message is missing or not an object")

def observe_type(kind: String,+root: Json.Json,state: State,maxkeys: U32,maxbytes: U32) -> Update:
  match kind:
    case "assistant": message(Counts.field(root,"message"),root,state,maxkeys,maxbytes)
    case "user": Accepted{state,""}
    case "system": Accepted{state,""}
    case "summary": Accepted{state,""}
    case "progress": Accepted{state,""}
    case "queue-operation": Accepted{state,""}
    case "file-history-snapshot": Accepted{state,""}
    case "ai-title": Accepted{state,""}
    case _: malformed(state,False{},"unsupported Claude record type; usage completeness is unknown")

def observe(+root: Json.Json,state: State,maxkeys: U32,maxbytes: U32) -> Update:
  observe_type(text(Counts.field(root,"type")),root,state,maxkeys,maxbytes)

def no_known(buckets: List<&2,Bucket>) -> Bool:
  match buckets:
    case []: True{}
    case Bucket{_,known} <> rest: U32.is_eq(known,0) && no_known(rest)

def unknown_empty(total: Total) -> Bool:
  Total{buckets} = total
  no_known(buckets)

def report(state: State) -> Report:
  State{_,+own,keys,bytes,all,total,copied,+unknown,+records,+missing,+incomplete,+conflicts,mirrors} = state
  +complete = U32.is_gt(records,0) && U32.is_eq(missing,0) && U32.is_eq(incomplete,0)
  Report{own,keys,bytes,values(all),values(total),values(copied),values(unknown),records,missing,incomplete,conflicts,mirrors,
    complete,complete && Bool.not(String.is_empty(own)) && U32.is_eq(conflicts,0) && unknown_empty(unknown)}
