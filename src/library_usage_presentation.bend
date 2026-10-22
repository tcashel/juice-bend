import Base
import ./library_usage_types.bend as T
import ./library_usage_view_types.bend as V
import ./session_usage.bend as S
import ./session_usage_counts.bend as Counts
import ./session_usage_claude.bend as Claude
import ./brief_safe_text.bend as Safe
import ./json.bend as Json

# Pure presentation of an already classified retained-library report. Labels
# are bounded; exact captures and canonical snapshot identities are not labels.
def scope() -> String:
  "Captured library · All time"

def display_next(fits: Bool,next: Unit -> String) -> String:
  match fits:
    case False{}: "…"
    case True{}: next(Unit{})

# Controls are indivisible literal escapes. At most budget+1 display scalars
# are emitted, including the visible ellipsis; ordinary Unicode stays intact.
def display(text: String,+budget: U32) -> String:
  match text:
    case SNil{}: ""
    case SCon{+c,rest}:
      +width : U32 = Bool.pick(U32,Safe.control(c),6,1)
      display_next(U32.is_le(width,budget),_ =>
        Bool.pick(String,Safe.control(c),Safe.escaped(c),SCon{c,SNil{}}) ++ display(rest,U32.sub(budget,width)))

def same_capture(a: S.Capture,b: S.Capture) -> Bool:
  S.Capture{ap,ai,al,ag,asnap,ae,ar} = a
  S.Capture{bp,bi,bl,bg,bsnap,be,br} = b
  String.eq(ap,bp) && String.eq(ai,bi) && String.eq(al,bl) && String.eq(ag,bg) &&
    String.eq(asnap,bsnap) && U32.is_eq(ae,be) && U32.is_eq(ar,br)

def provider_name(value: String) -> String:
  match value:
    case "claude": "Claude"
    case "codex": "Codex"
    case _: "Other provider"

def selection(value: String) -> String:
  match value:
    case "claude": "claude"
    case "codex": "codex"
    case _: ""

def metric_counts(known: U32,unknown: U32,na: U32) -> String:
  U32.show(known) ++ " known sessions · " ++ U32.show(unknown) ++ " unknown · " ++ U32.show(na) ++ " not applicable"

def observed_metric(known: Bool,label: String,sum: String,+unknown: U32,detail: String) -> V.Measure:
  match known:
    case True{}:
      V.Measure{label,sum,Bool.pick(V.MetricStyle,U32.is_gt(unknown,0),V.KnownSubtotal{},V.RecordedValue{}),
        Bool.pick(String,U32.is_gt(unknown,0),"Known subtotal; remaining contributions are unknown. ","Recorded counters. ") ++ detail}
    case False{}:
      V.Measure{label,Bool.pick(String,U32.is_gt(unknown,0),"Unknown","Not observed"),
        Bool.pick(V.MetricStyle,U32.is_gt(unknown,0),V.UnknownValue{},V.UnobservedValue{}),detail}

def measure(available: Bool,applicable: Bool,label: String,value: T.Metric) -> V.Measure:
  match available applicable:
    case False{} _: V.Measure{label,"Withheld",V.WithheldValue{},"Catalog coverage is incomplete; no provider total is shown."}
    case True{} False{}: V.Measure{label,"N/A",V.NotApplicableValue{},"This accounting bucket does not apply to Codex."}
    case True{} True{}:
      T.Metric{+sum,+known,+unknown,na} = value
      observed_metric(U32.is_gt(known,0) && Bool.not(String.is_empty(sum)),label,sum,unknown,metric_counts(known,unknown,na))

def empty_metric() -> T.Metric:
  T.Metric{"",0,0,0}

def empty_provider(name: String) -> T.Provider:
  T.Provider{name,0,0,0,0,empty_metric(),empty_metric(),empty_metric(),empty_metric(),empty_metric()}

def provider_match(matches: Bool,value: T.Provider,next: Unit -> T.Provider) -> T.Provider:
  match matches:
    case True{}: value
    case False{}: next(Unit{})

def provider(values: List<&2,T.Provider>,+name: String) -> T.Provider:
  match values:
    case []: empty_provider(name)
    case +value <> rest:
      T.Provider{key,_,_,_,_,_,_,_,_,_} = value
      provider_match(String.eq(key,name),value,_ => provider(rest,name))

def card(+available: Bool,value: T.Provider) -> V.ProviderCard:
  T.Provider{+name,sessions,aliases,ambiguous,excluded,input,cached,created,hour,output} = value
  +claude : Bool = String.eq(name,"claude")
  V.ProviderCard{name,provider_name(name),sessions,aliases,ambiguous,excluded,
    [measure(available,True{},"Input",input),measure(available,True{},"Cached input",cached),
      measure(available,claude,"Cache creation",created),measure(available,claude,"Cache creation (1h)",hour),
      measure(available,True{},"Output",output)]}

def cards(available: Bool,+values: List<&2,T.Provider>) -> List<&2,V.ProviderCard>:
  match available:
    case False{}: [card(False{},empty_provider("claude")),card(False{},empty_provider("codex"))]
    case True{}: [card(True{},provider(values,"claude")),card(True{},provider(values,"codex"))]

def unknown_metric(value: T.Metric) -> Bool:
  T.Metric{_,_,unknown,_} = value
  U32.is_gt(unknown,0)

def unknown_provider(value: T.Provider) -> Bool:
  T.Provider{_,_,_,_,_,a,b,c,d,e} = value
  unknown_metric(a) || unknown_metric(b) || unknown_metric(c) || unknown_metric(d) || unknown_metric(e)

def unknowns(values: List<&2,T.Provider>) -> Bool:
  match values:
    case []: False{}
    case value <> rest: unknown_provider(value) || unknowns(rest)

def has_status(values: List<&2,T.Decision>,+wanted: String) -> Bool:
  match values:
    case []: False{}
    case T.Decision{_,_,status,_,_} <> rest: String.eq(status,wanted) || has_status(rest,wanted)

def has_capture_status(values: List<&2,T.CaptureRow>,+wanted: String) -> Bool:
  match values:
    case []: False{}
    case T.CaptureRow{_,_,_,_,_,status,_,_} <> rest: String.eq(status,wanted) || has_capture_status(rest,wanted)

def notice(show: Bool,warning: Bool,text: String,tail: List<&2,V.Notice>) -> List<&2,V.Notice>:
  match show:
    case False{}: tail
    case True{}: V.Notice{warning,text} <> tail

def notices(+available: Bool,+rows: List<&2,T.CaptureRow>,+decisions: List<&2,T.Decision>,providers: List<&2,T.Provider>,
  sources: U32,records: U32,bytes: U32) -> List<&2,V.Notice>:
  notice(Bool.not(available),True{},"Totals withheld: catalog coverage is incomplete. Unseen aliases may conflict with these captures.",
    notice(available && unknowns(providers),True{},"Partial accounting: unknown counters are not zero. A known subtotal excludes unknown contributions.",
      notice(has_status(decisions,"ambiguous"),True{},"Ambiguous identities are excluded: the same provider/session has differing or unverified captured bytes.",
        notice(has_capture_status(rows,"limited"),True{},"Limited captures remain in the list; their incomplete accounting is excluded from totals.",
          notice(has_status(decisions,"identity_unknown") || has_status(decisions,"excluded") || has_status(decisions,"reviewer"),True{},
            "Some captures are excluded from ordinary session totals. Open a capture for its exact status and reason.",
            [V.Notice{False{},"Scope: captured library, All time. Complete catalog coverage does not imply complete provider history, live usage, quota, or billed spend."},
             V.Notice{False{},U32.show(sources) ++ " selected sources · " ++ U32.show(records) ++ " verified records · " ++ U32.show(bytes) ++ " verified logical bytes."},
             V.Notice{False{},"Exact verified-byte aliases count once; every retained capture remains available for inspection."}])))))

def status_label(value: String) -> String:
  match value:
    case "included": "Counted"
    case "alias": "Alias · counted once"
    case "unknown": "Unknown contribution"
    case "alias_unknown": "Alias · unknown contribution"
    case "ambiguous": "Ambiguous · excluded"
    case "reviewer": "Reviewer · excluded"
    case "identity_unknown": "Identity unknown · excluded"
    case "limited": "Limited · excluded"
    case "withheld": "Totals withheld"
    case "unavailable": "Decision unavailable"
    case _: "Excluded"

def found_decision(matches: Bool,value: T.Decision,next: Unit -> Maybe<&2,T.Decision>) -> Maybe<&2,T.Decision>:
  match matches:
    case True{}: Some{value}
    case False{}: next(Unit{})

def decision(values: List<&2,T.Decision>,+capture: S.Capture,+session: String) -> Maybe<&2,T.Decision>:
  match values:
    case []: None{}
    case +value <> rest:
      T.Decision{other,identity,_,_,_} = value
      found_decision(same_capture(capture,other) && String.eq(session,identity),value,_ => decision(rest,capture,session))

def item_decision(value: Maybe<&2,T.Decision>,capture: S.Capture,session: String,reason: String) -> T.Decision:
  match value:
    case Some{value}: value
    case None{}: T.Decision{capture,session,"unavailable","","No matching aggregate decision. Capture detail: " ++ reason}

def item_ready(+capture: S.Capture,+session: String,original: String,value: T.Decision) -> V.CaptureItem:
  S.Capture{provider,_,_,_,+snapshot,_,_} = capture
  T.Decision{_,_,+status,canonical,why} = value
  V.CaptureItem{capture,display(provider_name(provider) ++ " · " ++
    Bool.pick(String,String.is_empty(session),"Capture " ++ snapshot,session),80),status,
    display(status_label(status) ++ " · snapshot " ++ snapshot ++ " · Capture " ++ original ++ " · " ++ why,240),canonical}

def item(row: T.CaptureRow,decisions: List<&2,T.Decision>) -> V.CaptureItem:
  T.CaptureRow{+capture,+session,_,_,_,original,reason,_} = row
  item_ready(capture,session,original,item_decision(decision(decisions,capture,session),capture,session,reason))

def include_item(include: Bool,row: T.CaptureRow,decisions: List<&2,T.Decision>,tail: List<&2,V.CaptureItem>) -> List<&2,V.CaptureItem>:
  match include:
    case True{}: item(row,decisions) <> tail
    case False{}: tail

def captures(rows: List<&2,T.CaptureRow>,+decisions: List<&2,T.Decision>,+selected: String) -> List<&2,V.CaptureItem>:
  match rows:
    case []: []
    case +row <> rest:
      T.CaptureRow{S.Capture{provider,_,_,_,_,_,_},_,_,_,_,_,_,_} = row
      include_item(String.is_empty(selected) || String.eq(selected,provider),row,decisions,captures(rest,decisions,selected))

def report(value: T.Report,selected_provider: String) -> V.View:
  T.Report{complete,sources,records,bytes,_,+rows,T.Aggregate{ready,+providers,+decisions}} = value
  +available : Bool = complete && ready
  +selected : String = selection(selected_provider)
  V.View{"Usage",scope(),notices(available,rows,decisions,providers,sources,records,bytes),
    available,cards(available,providers),selected,captures(rows,decisions,selected)}

def style(value: V.MetricStyle) -> String:
  match value:
    case V.RecordedValue{}: "Recorded"
    case V.KnownSubtotal{}: "Known subtotal"
    case V.UnknownValue{}: "Unknown"
    case V.NotApplicableValue{}: "N/A"
    case V.UnobservedValue{}: "Unobserved"
    case V.WithheldValue{}: "Withheld"

def notice_text(values: List<&2,V.Notice>) -> String:
  match values:
    case []: ""
    case V.Notice{warning,text} <> rest:
      Bool.pick(String,warning,"Attention: ","") ++ text ++ "\n" ++ notice_text(rest)

def measure_text(values: List<&2,V.Measure>) -> String:
  match values:
    case []: ""
    case V.Measure{label,value,kind,detail} <> rest:
      label ++ ": " ++ value ++ " · " ++ style(kind) ++ "\n  " ++ detail ++ "\n" ++ measure_text(rest)

def is_withheld(values: List<&2,V.Measure>) -> Bool:
  match values:
    case V.Measure{_,_,V.WithheldValue{},_} <> _: True{}
    case _: False{}

def card_text(value: V.ProviderCard) -> String:
  V.ProviderCard{_,label,sessions,aliases,ambiguous,excluded,+measures} = value
  "\n" ++ label ++ "\n" ++ Bool.pick(String,is_withheld(measures),"Provider totals withheld.\n",
    U32.show(sessions) ++ " contributing sessions · " ++ U32.show(aliases) ++ " exact aliases · " ++
    U32.show(ambiguous) ++ " ambiguous groups · " ++ U32.show(excluded) ++ " excluded groups\n") ++ measure_text(measures)

def provider_text(values: List<&2,V.ProviderCard>) -> String:
  match values:
    case []: ""
    case value <> rest: card_text(value) ++ provider_text(rest)

def capture_text(values: List<&2,V.CaptureItem>) -> String:
  match values:
    case []: ""
    case V.CaptureItem{_,title,_,summary,_} <> rest: "\n" ++ title ++ "\n" ++ summary ++ "\n" ++ capture_text(rest)

# First reader bridge keeps all notices before any metrics. Exact identities
# and full evidence are intentionally reserved for the selected-row detail.
def text(value: V.View) -> String:
  V.View{heading,scope,notices,_,providers,+selected,captures} = value
  heading ++ "\n" ++ scope ++ "\n\n" ++ notice_text(notices) ++ provider_text(providers) ++
    "\nCaptured sessions · " ++ Bool.pick(String,String.is_empty(selected),"All providers",provider_name(selected)) ++
    "\nSelect a capture to inspect or copy its complete accounting evidence.\n" ++ capture_text(captures)

def report_capture(value: S.Report) -> S.Capture:
  S.Report{capture,_,_,_,_,_,_,_,_,_} = value
  capture

def capture_report(value: Maybe<&2,S.Report>,+capture: S.Capture) -> Result<&2,&2,S.Failure,String>:
  match value:
    case None{}: Done{"No whole-capture accounting report is available. The capture identity, classification and reason above remain inspectable.\n"}
    case Some{+value}:
      do Result<&2,&2,S.Failure,String>:
        Unit <- S.check(same_capture(capture,report_capture(value)),"library_usage_detail_identity","Accounting report does not match the selected immutable capture.")
        S.render(value)

def detail_limit(+text: String) -> Result<&2,&2,S.Failure,String>:
  S.rendered(Claude.fits_result(Claude.remaining(text,1048576)),text)

def exact_counters(value: Counts.Counters) -> String:
  Counts.Counters{input,cached,created,hour,output} = value
  "{\"input\":" ++ Json.quote(input) ++ ",\"cached\":" ++ Json.quote(cached) ++ ",\"created\":" ++ Json.quote(created) ++
    ",\"created1h\":" ++ Json.quote(hour) ++ ",\"output\":" ++ Json.quote(output) ++ "}"

def detail(row: T.CaptureRow,value: T.Decision) -> Result<&2,&2,S.Failure,String>:
  T.CaptureRow{+capture,+session,sha,category,+counts,status,reason,accounting} = row
  T.Decision{other,identity,decision,canonical,why} = value
  do Result<&2,&2,S.Failure,String>:
    Unit <- S.check(same_capture(capture,other) && String.eq(session,identity),
      "library_usage_detail_identity","Aggregate decision does not match the selected immutable capture and session identity.")
    body : String <- capture_report(accounting,capture)
    detail_limit("Juice Bend · library Usage capture detail\nScope: " ++ scope() ++ "\nCapture: " ++ S.capture_text(capture) ++
      "\nSession identity: " ++ Json.quote(session) ++ "\nVerified logical-byte SHA-256: " ++ Json.quote(sha) ++
      "\nCapture category: " ++ Json.quote(category) ++ "\nCapture status: " ++ Json.quote(status) ++ "\nCapture reason: " ++ Json.quote(reason) ++
      "\nAggregate decision: " ++ Json.quote(decision) ++ "\nCanonical snapshot: " ++ Json.quote(canonical) ++ "\nDecision reason: " ++ Json.quote(why) ++
      "\n\nCapture counters (exact strings; empty is unknown or not applicable):\n" ++ exact_counters(counts) ++
      "\nRecorded capture counters (not necessarily a counted contribution):\n" ++ Counts.text(counts) ++
      "\nUnknown counters are not zero. Alias grouping changes contribution counts, never retained evidence identity.\n\n" ++ body)
