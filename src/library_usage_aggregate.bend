import Base
import ./library_usage_types.bend as T
import ./session_usage.bend as Session
import ./session_usage_counts.bend as Counts
import ./provenance.bend as Provenance

# Pure All-time aggregation over the caller's at-most-256 verified captures.
# This groups presentation aliases only; no capture or raw ownership changes.
type Group is Data:
  Group{canonical: String,members: U32,ambiguous: Bool,excluded: Bool,
    reviewer: Bool,unknown: Bool,counts: Counts.Counters}

def provider(row: T.CaptureRow) -> String:
  T.CaptureRow{Session.Capture{name,_,_,_,_,_,_},_,_,_,_,_,_,_} = row
  name

def same_group(+wanted: T.CaptureRow,+row: T.CaptureRow) -> Bool:
  T.CaptureRow{_,+session,_,_,_,_,_,_} = wanted
  T.CaptureRow{_,other,_,_,_,_,_,_} = row
  Bool.not(String.is_empty(session)) && String.eq(session,other) && String.eq(provider(wanted),provider(row))

def seen(rows: List<&2,T.CaptureRow>,+wanted: T.CaptureRow) -> Bool:
  match rows:
    case []: False{}
    case row <> rest: same_group(wanted,row) || seen(rest,wanted)

def valid_counter(value: String) -> Bool:
  # Per-capture totals may already exceed the provider's 64-digit input bound.
  Provenance.decimal_valid(value)

def required(+name: String,counts: Counts.Counters) -> Bool:
  Counts.Counters{input,cached,created,+onehour,output} = counts
  valid_counter(input) && valid_counter(cached) && valid_counter(output) &&
    (String.eq(name,"codex") || (valid_counter(created) && (String.is_empty(onehour) || valid_counter(onehour))))

def member(+row: T.CaptureRow,+wanted: T.CaptureRow,group: Group) -> Group:
  T.CaptureRow{Session.Capture{_,_,_,_,+snapshot,_,_},_,+sha,+category,+counts,+status,_,_} = row
  T.CaptureRow{_,_,+expected,expected_category,expected_counts,_,_,_} = wanted
  Group{+canonical,+members,ambiguous,excluded,reviewer,unknown,base} = group
  Group{Bool.pick(String,U32.is_eq(members,0),snapshot,canonical),U32.inc(members),
    ambiguous || String.is_empty(sha) || String.is_empty(expected) || Bool.not(String.eq(sha,expected)),
    excluded || Bool.not(String.eq(status,"eligible") || String.eq(status,"incomplete")),
    reviewer || String.eq(status,"reviewer") || String.eq(category,"reviewer"),
    unknown || String.eq(status,"incomplete") || Bool.not(String.eq(category,expected_category)) || Bool.not(required(provider(row),counts)) ||
      Bool.not(Counts.equal(counts,expected_counts)),base}

def scan(rows: List<&2,T.CaptureRow>,+wanted: T.CaptureRow,+group: Group) -> Group:
  match rows:
    case []: group
    case +row <> rest:
      scan(rest,wanted,Bool.pick(Group,same_group(wanted,row),member(row,wanted,group),group))

def grouped(+row: T.CaptureRow,rows: List<&2,T.CaptureRow>) -> Group:
  T.CaptureRow{_,_,_,_,counts,_,_,_} = row
  scan(rows,row,Group{"",0,False{},False{},False{},False{},counts})

def recognized(+name: String) -> Bool:
  String.eq(name,"claude") || String.eq(name,"codex")

def status(+row: T.CaptureRow,group: Group) -> String:
  T.CaptureRow{_,+session,_,+category,_,+original,_,_} = row
  Group{_,_,ambiguous,excluded,reviewer,unknown,_} = group
  Bool.pick(String,Bool.not(recognized(provider(row))),"excluded",
    Bool.pick(String,String.is_empty(session),
      Bool.pick(String,String.eq(original,"reviewer") || String.eq(category,"reviewer"),"reviewer",
        Bool.pick(String,String.eq(original,"limited"),"limited","identity_unknown")),
      Bool.pick(String,ambiguous,"ambiguous",
        Bool.pick(String,reviewer,"reviewer",Bool.pick(String,excluded,"excluded",
          Bool.pick(String,unknown,"unknown","included"))))))

def accepted(+status: String) -> Bool:
  String.eq(status,"included") || String.eq(status,"unknown")

def reason(status: String) -> String:
  match status:
    case "included": "One complete recorded session contribution; exact verified-byte aliases count once."
    case "unknown": "One session contribution has incomplete or inconsistent accounting; every applicable counter is unknown."
    case "ambiguous": "Same provider/session has differing or incompletely verified logical bytes; the entire identity group is excluded."
    case "reviewer": "Reviewer usage is excluded from ordinary provider totals."
    case "identity_unknown": "No raw-backed session identity; no alias or counted session is inferred from the locator."
    case "limited": "Capture accounting was limited; this capture is excluded."
    case _: "Unsupported provider or an excluded member prevents counting this identity group."

def note(+original: String) -> String:
  Bool.pick(String,String.is_empty(original),""," Capture detail: " ++ original)

def decision(row: T.CaptureRow,group: Group,+kind: String,fresh: Bool) -> T.Decision:
  T.CaptureRow{capture,session,_,_,_,_,original,_} = row
  Group{canonical,_,_,_,_,_,_} = group
  T.Decision{capture,session,Bool.pick(String,fresh,kind,
    Bool.pick(String,String.eq(kind,"included"),"alias",Bool.pick(String,String.eq(kind,"unknown"),"alias_unknown",kind))),
    Bool.pick(String,accepted(kind),canonical,""),reason(kind) ++ note(original)}

def empty_metric() -> T.Metric:
  T.Metric{"",0,0,0}

def empty_provider(name: String) -> T.Provider:
  T.Provider{name,0,0,0,0,empty_metric(),empty_metric(),empty_metric(),empty_metric(),empty_metric()}

def added_sum(+sum: String,+value: String) -> String:
  Bool.pick(String,String.is_empty(sum),value,Counts.add(sum,value))

def metric_value(unknown: Bool,old: T.Metric,value: String) -> T.Metric:
  match unknown:
    case True{}:
      T.Metric{sum,known,missing,na} = old
      T.Metric{sum,known,U32.inc(missing),na}
    case False{}:
      T.Metric{sum,known,missing,na} = old
      T.Metric{added_sum(sum,value),U32.inc(known),missing,na}

def metric(applicable: Bool,unknown: Bool,+value: String,old: T.Metric) -> T.Metric:
  match applicable:
    case False{}:
      T.Metric{sum,known,missing,na} = old
      T.Metric{sum,known,missing,U32.inc(na)}
    case True{}: metric_value(unknown || String.is_empty(value),old,value)

# sessions = included identity groups, including one group of unknown counters.
# aliases = their additional exact-byte captures. ambiguous/excluded count
# excluded identity groups; empty identity captures are individually excluded.
# A Metric.sum is the KNOWN subtotal, never a complete total if unknown > 0.
def contribution(old: T.Provider,group: Group,+unknown: Bool) -> T.Provider:
  T.Provider{+name,sessions,aliases,ambiguous,excluded,input,cached,created,onehour,output} = old
  Group{_,members,_,_,_,_,Counts.Counters{ci,cc,cr,ch,co}} = group
  +claude = String.eq(name,"claude")
  T.Provider{name,U32.inc(sessions),U32.add(aliases,U32.sub(U32.max(members,1),1)),ambiguous,excluded,
    metric(True{},unknown,ci,input),metric(True{},unknown,cc,cached),metric(claude,unknown,cr,created),
    metric(claude,unknown,ch,onehour),metric(True{},unknown,co,output)}

def excluded_provider(old: T.Provider,+kind: String) -> T.Provider:
  T.Provider{name,sessions,aliases,ambiguous,excluded,input,cached,created,onehour,output} = old
  T.Provider{name,sessions,aliases,U32.add(ambiguous,Bool.to_u32(String.eq(kind,"ambiguous"))),
    U32.add(excluded,Bool.to_u32(Bool.not(String.eq(kind,"ambiguous")))),input,cached,created,onehour,output}

def contribute(kind: String,old: T.Provider,group: Group) -> T.Provider:
  match kind:
    case "included": contribution(old,group,False{})
    case "unknown": contribution(old,group,True{})
    case other: excluded_provider(old,other)

def walk(rows: List<&2,T.CaptureRow>,+all: List<&2,T.CaptureRow>,+prior: List<&2,T.CaptureRow>,
  +claude: T.Provider,+codex: T.Provider,decisions: List<&2,T.Decision>) -> T.Aggregate:
  match rows:
    case []: T.Aggregate{True{},[claude,codex],List.reverse(&2,T.Decision,decisions)}
    case +row <> rest:
      +group = grouped(row,all)
      +kind = status(row,group)
      +fresh = Bool.not(seen(prior,row))
      +name = provider(row)
      walk(rest,all,row <> prior,
        Bool.pick(T.Provider,fresh && String.eq(name,"claude"),contribute(kind,claude,group),claude),
        Bool.pick(T.Provider,fresh && String.eq(name,"codex"),contribute(kind,codex,group),codex),
        decision(row,group,kind,fresh) <> decisions)

def withheld(rows: List<&2,T.CaptureRow>,+reason: String) -> List<&2,T.Decision>:
  match rows:
    case []: []
    case T.CaptureRow{capture,session,_,_,_,_,original,_} <> rest:
      T.Decision{capture,session,"withheld","",reason ++ note(original)} <> withheld(rest,reason)

def finish(complete: Bool,+rows: List<&2,T.CaptureRow>) -> T.Aggregate:
  match complete:
    case False{}:
      T.Aggregate{False{},[],withheld(rows,"Catalog is incomplete or exceeds 256 captures; unseen aliases may conflict, so all totals are withheld.")}
    case True{}: walk(rows,rows,[],empty_provider("claude"),empty_provider("codex"),[])

def summarize(+rows: List<&2,T.CaptureRow>,catalog_complete: Bool) -> T.Aggregate:
  finish(catalog_complete && Nat.is_le(List.length(&2,T.CaptureRow,rows),256n),rows)
