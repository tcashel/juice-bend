import Base
import ../src/library_usage_presentation.bend as P
import ../src/library_usage_view_types.bend as V
import ../src/library_usage_types.bend as T
import ../src/library_usage_aggregate.bend as A
import ../src/session_usage.bend as S
import ../src/session_usage_counts.bend as Counts
import ../src/session_usage_claude.bend as Claude

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def capture(provider: String,+snapshot: String) -> S.Capture:
  S.Capture{provider,"source-" ++ snapshot,"/synthetic/" ++ snapshot ++ " café 中文 🙂.jsonl","7",snapshot,321,4}

def row(+provider: String,+snapshot: String,session: String,sha: String,counts: Counts.Counters,+status: String) -> T.CaptureRow:
  T.CaptureRow{capture(provider,snapshot),session,sha,Bool.pick(String,String.eq(status,"reviewer"),"reviewer","ordinary"),
    counts,status,"synthetic reason for " ++ snapshot,None{}}

def known(snapshot: String,session: String) -> T.CaptureRow:
  row("claude",snapshot,session,"aaa",Counts.Counters{"10","2","3","1","4"},"eligible")

def library(+rows: List<&2,T.CaptureRow>,+complete: Bool) -> T.Report:
  T.Report{complete,U32.from_nat(List.length(&2,T.CaptureRow,rows)),16,1284,T.defaults(),rows,A.summarize(rows,complete)}

def view(rows: List<&2,T.CaptureRow>,complete: Bool,selected: String) -> V.View:
  P.report(library(rows,complete),selected)

def metric_kind(value: V.MetricStyle) -> String:
  match value:
    case V.RecordedValue{}: "recorded"
    case V.KnownSubtotal{}: "subtotal"
    case V.UnknownValue{}: "unknown"
    case V.NotApplicableValue{}: "na"
    case V.UnobservedValue{}: "unobserved"
    case V.WithheldValue{}: "withheld"

def selected_measure(values: List<&2,V.Measure>,+label: String) -> String:
  match values:
    case []: "missing"
    case V.Measure{name,value,kind,_} <> rest:
      Bool.pick(String,String.eq(name,label),value ++ ":" ++ metric_kind(kind),selected_measure(rest,label))

def selected_card(values: List<&2,V.ProviderCard>,+provider: String,+label: String) -> String:
  match values:
    case []: "missing"
    case V.ProviderCard{key,_,_,_,_,_,measures} <> rest:
      Bool.pick(String,String.eq(key,provider),selected_measure(measures,label),selected_card(rest,provider,label))

def measurement(value: V.View,provider: String,label: String) -> String:
  V.View{_,_,_,_,cards,_,_} = value
  selected_card(cards,provider,label)

def card_names(values: List<&2,V.ProviderCard>) -> String:
  match values:
    case []: ""
    case V.ProviderCard{key,label,_,_,_,_,_} <> rest: key ++ ":" ++ label ++ ";" ++ card_names(rest)

def names(value: V.View) -> String:
  V.View{_,_,_,_,cards,_,_} = value
  card_names(cards)

def available(value: V.View) -> Bool:
  V.View{_,_,_,available,_,_,_} = value
  available

def selected(value: V.View) -> String:
  V.View{_,_,_,_,_,provider,_} = value
  provider

def items(value: V.View) -> List<&2,V.CaptureItem>:
  V.View{_,_,_,_,_,_,rows} = value
  rows

def item_states(values: List<&2,V.CaptureItem>) -> String:
  match values:
    case []: ""
    case V.CaptureItem{S.Capture{_,_,_,_,snapshot,_,_},_,status,_,canonical} <> rest:
      snapshot ++ ":" ++ status ++ ":" ++ canonical ++ ";" ++ item_states(rest)

def before_step(left: Bool,right: Bool,next: Unit -> Bool) -> Bool:
  match left right:
    case True{} _: True{}
    case _ True{}: False{}
    case _ _: next(Unit{})

def before_walk(+text: String,+left: String,+right: String) -> Bool:
  match text:
    case SNil{}: False{}
    case SCon{_,rest}:
      before_step(String.starts_with(text,left),String.starts_with(text,right),_ => before_walk(rest,left,right))

def before(+text: String,+left: String,+right: String) -> Bool:
  String.contains(text,left) && String.contains(text,right) && before_walk(text,left,right)

def metric_states() -> IO(Unit):
  +partial : V.View = view([
    row("claude","1","zero","aaa",Counts.Counters{"0","0","0","","0"},"eligible"),
    row("claude","2","unknown","bbb",Counts.Counters{"20","","3","1","4"},"incomplete")],True{},"")
  +zero : V.View = view([row("claude","3","zero","ccc",Counts.Counters{"0","0","0","0","0"},"eligible")],True{},"")
  +codex : V.View = view([row("codex","4","exact","ddd",Counts.Counters{"9007199254740993","2","","","4"},"eligible")],True{},"")
  do IO<Unit>:
    check(String.eq(measurement(partial,"claude","Input"),"0:subtotal"),"known zero remains an explicit subtotal when another contribution is unknown")
    check(String.eq(measurement(partial,"claude","Cache creation (1h)"),"Unknown:unknown"),"no known optional split is unknown rather than zero")
    check(String.eq(measurement(zero,"claude","Input"),"0:recorded"),"a complete measured zero is recorded")
    check(String.eq(measurement(codex,"codex","Input"),"9007199254740993:recorded"),"provider measures retain exact integers above 2^53")
    check(String.eq(measurement(codex,"codex","Cache creation"),"N/A:na") &&
      String.eq(measurement(codex,"codex","Cache creation (1h)"),"N/A:na"),"Codex creation buckets remain structurally not applicable")
    check(before(P.text(partial),"Partial accounting:","\nClaude\n") && before(P.text(partial),"Partial accounting:","Input: 0"),
      "partial-accounting warning is serialized before provider headings and numeric subtotals")

def empty_and_withheld() -> IO(Unit):
  +empty : V.View = view([],True{},"")
  +withheld : V.View = view([known("10","one")],False{},"claude")
  do IO<Unit>:
    check(String.eq(names(empty),"claude:Claude;codex:Codex;") && String.eq(names(withheld),"claude:Claude;codex:Codex;"),
      "empty and withheld libraries retain stable provider card order")
    check(available(empty) && Bool.not(available(withheld)),"structured view distinguishes an observed empty catalog from withheld provider counts")
    check(String.eq(measurement(empty,"claude","Input"),"Not observed:unobserved") &&
      String.eq(measurement(empty,"codex","Input"),"Not observed:unobserved"),"empty captures do not manufacture measured zero")
    check(String.eq(measurement(withheld,"claude","Input"),"Withheld:withheld") &&
      String.eq(measurement(withheld,"codex","Cache creation"),"Withheld:withheld"),"incomplete catalog withholds every measure with its own style")
    check(before(P.text(withheld),"Totals withheld:","\nClaude\n") && Bool.not(String.contains(P.text(withheld),"Input: 10")) &&
      Bool.not(String.contains(P.text(withheld),"contributing sessions")),"withheld text exposes neither a partial total nor misleading zero contribution counts")
    check(String.eq(item_states(items(withheld)),"10:withheld:;"),"catalog withholding retains exact capture drilldown")
    check(String.starts_with(P.text(empty),"Usage\nCaptured library · All time\n") &&
      before(P.text(empty),"Complete catalog coverage does not imply complete provider history", "\nClaude\n"),
      "captured-library all-time scope and coverage limits precede measures")

def long_session() -> String:
  "café\n中文 🙂 " ++ String.repeat("x",120n)

def drilldown_last() -> List<&2,T.CaptureRow>:
  [row("codex","6","reviewer","eee",Counts.Counters{"99","1","","","2"},"reviewer"),
    row("claude","7","","fff",Counts.empty(),"identity_unknown"),
    row("other","8","unsupported","ggg",Counts.empty(),"eligible")]

def drilldown_middle() -> List<&2,T.CaptureRow>:
  row("claude","4","conflict","different",Counts.Counters{"10","2","3","1","4"},"eligible") <>
    row("claude","5","","",Counts.empty(),"limited") <> drilldown_last()

def drilldown_rows() -> List<&2,T.CaptureRow>:
  known("1",long_session()) <> known("2",long_session()) <> known("3","conflict") <> drilldown_middle()

def first_item_identity(values: List<&2,V.CaptureItem>) -> Bool:
  match values:
    case V.CaptureItem{capture,+title,_,+summary,canonical} <> _:
      String.eq(S.capture_text(capture),"{\"provider\":\"claude\",\"source_id\":\"source-1\",\"source\":\"/synthetic/1 café 中文 🙂.jsonl\",\"generation\":\"7\",\"snapshot\":\"1\",\"extent\":\"321\",\"records\":\"4\"}") &&
        String.eq(canonical,"1") && String.contains(title,"café\\u000a中文 🙂") && Bool.not(String.contains(title,"\n")) &&
        Nat.is_le(String.length(title),81n) && Nat.is_le(String.length(summary),241n) && String.contains(title,"…")
    case _: False{}

def drilldown() -> IO(Unit):
  +all : V.View = view(drilldown_rows(),True{},"")
  +claude : V.View = view(drilldown_rows(),True{},"claude")
  +codex : V.View = view(drilldown_rows(),True{},"codex")
  do IO<Unit>:
    check(String.eq(item_states(items(all)),"1:included:1;2:alias:1;3:ambiguous:;4:ambiguous:;5:limited:;6:reviewer:;7:identity_unknown:;8:excluded:;"),
      "overview preserves every included, alias, ambiguous, limited, reviewer and unknown-identity capture in order")
    check(String.eq(item_states(items(claude)),"1:included:1;2:alias:1;3:ambiguous:;4:ambiguous:;5:limited:;7:identity_unknown:;") &&
      String.eq(item_states(items(codex)),"6:reviewer:;"),"provider drilldown filters rows without dropping excluded captures or aliases")
    check(first_item_identity(items(claude)),"display clipping and escaped controls leave the complete capture identity and canonical snapshot untouched")
    check(before(P.text(all),"Ambiguous identities are excluded:","\nClaude\n") && before(P.text(all),"Limited captures remain", "\nClaude\n"),
      "ambiguous and limited coverage warnings precede provider numbers")
    check(String.eq(selected(view(drilldown_rows(),True{},"unrecognized")),"") &&
      Nat.is_eq(List.length(&2,V.CaptureItem,items(view(drilldown_rows(),True{},"unrecognized"))),8n),
      "unknown provider selection returns overview without hiding captures")
    check(String.eq(P.display("A\nB",2),"A…") && String.eq(P.display("A\nB",7),"A\\u000a…"),
      "display clipping never emits a partial control escape")

def only_decision(value: T.Aggregate) -> T.Decision:
  T.Aggregate{_,_,rows} = value
  match rows:
    case [value]: value
    case _: T.Decision{capture("claude","invalid"),"","invalid","","invalid test fixture"}

def detail(+row: T.CaptureRow) -> Result<&2,&2,S.Failure,String>:
  P.detail(row,only_decision(A.summarize([row],True{})))

def detail_text(value: Result<&2,&2,S.Failure,String>) -> String:
  match value:
    case Done{text}: text
    case Fail{_}: "unexpected detail failure"

def failed(value: Result<&2,&2,S.Failure,String>,expected: String) -> Bool:
  match value:
    case Fail{S.Failure{code,_}}: String.eq(code,expected)
    case Done{_}: False{}

def retained_report() -> S.Report:
  S.Report{capture("claude","9"),S.defaults(),4,321,True{},False{},False{},"synthetic incomplete accounting",
    S.Coverage{4,0,0,1,[S.Witness{2,"synthetic missing counter"}]},S.ClaudeSummary{Claude.report(Claude.new("with-report"))}}

def reported_row(report: S.Report) -> T.CaptureRow:
  T.CaptureRow{capture("claude","9"),"with-report","abc","ordinary",Counts.empty(),"incomplete","exact report preserved",Some{report}}

def wrong_report(value: S.Report) -> S.Report:
  S.Report{_,limits,records,bytes,scan,bucket,attribution,reason,coverage,summary} = value
  S.Report{capture("claude","8"),limits,records,bytes,scan,bucket,attribution,reason,coverage,summary}

def oversized_row() -> T.CaptureRow:
  T.CaptureRow{capture("claude","10"),"large","abc","ordinary",Counts.empty(),"limited",String.repeat("é",524288n),None{}}

def detail_cases() -> IO(Unit):
  +plain : String = detail_text(detail(row("claude","5","","",Counts.empty(),"limited")))
  +full : String = detail_text(detail(reported_row(retained_report())))
  do IO<Unit>:
    check(String.contains(plain,"Capture: {\"provider\":\"claude\",\"source_id\":\"source-5\",\"source\":\"/synthetic/5 café 中文 🙂.jsonl\",\"generation\":\"7\",\"snapshot\":\"5\",\"extent\":\"321\",\"records\":\"4\"}") &&
      String.contains(plain,"Verified logical-byte SHA-256: \"\"") && String.contains(plain,"Capture status: \"limited\"") &&
      String.contains(plain,"Capture reason: \"synthetic reason for 5\"") && String.contains(plain,"Aggregate decision: \"limited\"") &&
      String.contains(plain,"{\"input\":\"\",\"cached\":\"\",\"created\":\"\",\"created1h\":\"\",\"output\":\"\"}") &&
      String.contains(plain,"No whole-capture accounting report is available."),"detail without accounting report retains exact identity, raw status, reason, SHA and counter strings")
    check(String.contains(full,detail_text(S.render(retained_report()))) && String.contains(full,"\"physical_record\":\"2\"") &&
      String.contains(full,"synthetic missing counter"),"selected detail retains the complete existing accounting report and record witness")
    check(failed(P.detail(known("1","a"),only_decision(A.summarize([known("2","a")],True{}))),"library_usage_detail_identity"),
      "detail refuses a decision belonging to another capture")
    check(failed(P.detail(known("1","a"),only_decision(A.summarize([known("1","b")],True{}))),"library_usage_detail_identity"),
      "detail refuses a decision belonging to another session identity")
    check(failed(detail(reported_row(wrong_report(retained_report()))),"library_usage_detail_identity"),
      "detail refuses accounting evidence belonging to another immutable capture")
    check(String.contains(detail_text(detail(known("1",long_session()))),"Session identity: \"café\\u000a中文 🙂 " ++ String.repeat("x",120n) ++ "\""),
      "full detail retains the complete escaped session identity beyond the clipped list title")
    check(failed(detail(oversized_row()),"usage_output_limit"),"UTF-8 detail over one MiB fails instead of truncating evidence")

def main() -> IO(Unit):
  do IO<Unit>:
    metric_states()
    empty_and_withheld()
    drilldown()
    detail_cases()
