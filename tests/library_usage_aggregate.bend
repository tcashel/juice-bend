import Base
import ../src/library_usage_aggregate.bend as A
import ../src/library_usage_types.bend as T
import ../src/session_usage.bend as Session
import ../src/session_usage_counts.bend as Counts

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def row(+provider: String,+snapshot: String,session: String,sha: String,category: String,
  counts: Counts.Counters,status: String) -> T.CaptureRow:
  T.CaptureRow{Session.Capture{provider,snapshot,"/synthetic/" ++ snapshot ++ ".jsonl","1",snapshot,100,1},
    session,sha,category,counts,status,"synthetic capture " ++ snapshot,None{}}

def claude(snapshot: String,session: String,sha: String,counts: Counts.Counters,status: String) -> T.CaptureRow:
  row("claude",snapshot,session,sha,"ordinary",counts,status)

def codex(snapshot: String,session: String,sha: String,counts: Counts.Counters,status: String) -> T.CaptureRow:
  row("codex",snapshot,session,sha,"ordinary",counts,status)

def full() -> Counts.Counters:
  Counts.Counters{"10","2","3","1","4"}

def metric(value: T.Metric) -> String:
  T.Metric{sum,known,unknown,na} = value
  sum ++ ":" ++ U32.show(known) ++ ":" ++ U32.show(unknown) ++ ":" ++ U32.show(na)

def provider(value: T.Provider) -> String:
  T.Provider{name,sessions,aliases,ambiguous,excluded,a,b,c,d,e} = value
  name ++ " " ++ U32.show(sessions) ++ "/" ++ U32.show(aliases) ++ "/" ++ U32.show(ambiguous) ++ "/" ++ U32.show(excluded) ++
    " " ++ metric(a) ++ " " ++ metric(b) ++ " " ++ metric(c) ++ " " ++ metric(d) ++ " " ++ metric(e)

def provider_texts(rows: List<&2,T.Provider>) -> List<&2,String>:
  match rows:
    case []: []
    case row <> rest: provider(row) <> provider_texts(rest)

def providers(value: T.Aggregate) -> List<&2,String>:
  T.Aggregate{_,rows,_} = value
  provider_texts(rows)

def exact_provider_rows(rows: List<&2,String>,claude: String,codex: String) -> Bool:
  match rows:
    case [a,b]: String.eq(a,claude) && String.eq(b,codex)
    case _: False{}

def exact_providers(value: T.Aggregate,claude: String,codex: String) -> Bool:
  exact_provider_rows(providers(value),claude,codex)

def empty_claude() -> String:
  "claude 0/0/0/0 :0:0:0 :0:0:0 :0:0:0 :0:0:0 :0:0:0"

def empty_codex() -> String:
  "codex 0/0/0/0 :0:0:0 :0:0:0 :0:0:0 :0:0:0 :0:0:0"

def available(value: T.Aggregate) -> Bool:
  T.Aggregate{yes,_,_} = value
  yes

def decisions(value: T.Aggregate) -> List<&2,T.Decision>:
  T.Aggregate{_,_,rows} = value
  rows

def decision_text(value: T.Decision) -> String:
  T.Decision{Session.Capture{_,source,locator,generation,snapshot,extent,records},session,status,canonical,reason} = value
  source ++ "|" ++ locator ++ "|" ++ generation ++ "|" ++ snapshot ++ "|" ++ U32.show(extent) ++ "|" ++ U32.show(records) ++
    "|" ++ session ++ "|" ++ status ++ "|" ++ canonical ++ "|" ++ reason

def state(value: T.Decision) -> String:
  T.Decision{_,_,status,canonical,_} = value
  status ++ ":" ++ canonical

def states(rows: List<&2,T.Decision>) -> List<&2,String>:
  match rows:
    case []: []
    case row <> rest: state(row) <> states(rest)

def pair_rows(rows: List<&2,String>,first: String,second: String) -> Bool:
  match rows:
    case [a,b]: String.eq(a,first) && String.eq(b,second)
    case _: False{}

def pair_states(value: T.Aggregate,first: String,second: String) -> Bool:
  pair_rows(states(decisions(value)),first,second)

def single_row(rows: List<&2,String>,expected: String) -> Bool:
  match rows:
    case [actual]: String.eq(actual,expected)
    case _: False{}

def single_state(value: T.Aggregate,expected: String) -> Bool:
  single_row(states(decisions(value)),expected)

def same_provider_rows(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a:
    case [ac,ax]: exact_provider_rows(b,ac,ax)
    case _: False{}

def same_providers(a: T.Aggregate,b: T.Aggregate) -> Bool:
  same_provider_rows(providers(a),providers(b))

def alias_identity(rows: List<&2,T.Decision>) -> Bool:
  match rows:
    case [_,+other]:
      String.starts_with(decision_text(other),"20|/synthetic/20.jsonl|1|20|100|1|shared|alias|10|") &&
        String.contains(decision_text(other),"synthetic capture 20")
    case _: False{}

def exact_and_distinct() -> IO(Unit):
  +a : T.CaptureRow = claude("10","shared","aaa",full(),"eligible")
  +alias : T.CaptureRow = claude("20","shared","aaa",full(),"eligible")
  +different : T.CaptureRow = claude("30","another","aaa",full(),"eligible")
  +result : T.Aggregate = A.summarize([a,alias,different],True{})
  +pair : T.Aggregate = A.summarize([a,alias],True{})
  do IO<Unit>:
    check(available(result) && exact_providers(result,
      "claude 2/1/0/0 20:2:0:0 4:2:0:0 6:2:0:0 2:2:0:0 8:2:0:0",empty_codex()),
      "exact aliases count once while different session identities sharing bytes remain distinct")
    check(same_providers(result,A.summarize([different,alias,a],True{})),"provider sums and group counts are independent of catalog order")
    check(pair_states(pair,"included:10","alias:10") && pair_states(A.summarize([alias,a],True{}),"included:20","alias:20"),
      "every alias retains a decision and the first exact group capture is canonical")
    check(alias_identity(decisions(pair)),"alias drilldown preserves exact capture identity and original reason")

def conflicts() -> IO(Unit):
  +a : T.CaptureRow = claude("1","shared","aaa",full(),"eligible")
  +b : T.CaptureRow = claude("2","shared","bbb",full(),"eligible")
  +missing : T.CaptureRow = claude("3","shared","",full(),"limited")
  +result : T.Aggregate = A.summarize([a,b],True{})
  do IO<Unit>:
    check(exact_providers(result,"claude 0/0/1/0 :0:0:0 :0:0:0 :0:0:0 :0:0:0 :0:0:0",empty_codex()) &&
      pair_states(result,"ambiguous:","ambiguous:"),"different bytes exclude the entire identity group without a canonical winner")
    check(same_providers(result,A.summarize([b,a],True{})),"conflict exclusion is independent of catalog order")
    check(pair_states(A.summarize([a,missing],True{}),"ambiguous:","ambiguous:"),"an unverified alias with empty SHA prevents counting its complete peer")
    check(exact_providers(A.summarize([a,codex("4","shared","bbb",Counts.Counters{"5","6","","","7"},"eligible")],True{}),
      "claude 1/0/0/0 10:1:0:0 2:1:0:0 3:1:0:0 1:1:0:0 4:1:0:0",
      "codex 1/0/0/0 5:1:0:0 6:1:0:0 :0:0:1 :0:0:1 7:1:0:0"),"provider identities isolate otherwise colliding session strings")

def inconsistent_alias_accounting() -> IO(Unit):
  +known : T.CaptureRow = claude("1","one","aaa",full(),"eligible")
  +changed : T.CaptureRow = claude("6","one","aaa",Counts.Counters{"11","2","3","1","4"},"eligible")
  +mixed : T.Aggregate = A.summarize([known,changed],True{})
  do IO<Unit>:
    check(pair_states(mixed,"unknown:1","alias_unknown:1") && same_providers(mixed,A.summarize([changed,known],True{})),
      "identical bytes with inconsistent accounting never select an order-dependent counter winner")

def unknowns() -> IO(Unit):
  +known : T.CaptureRow = claude("1","one","aaa",full(),"eligible")
  +partial : T.CaptureRow = claude("2","two","bbb",Counts.Counters{"20","","5","2","6"},"eligible")
  +alias : T.CaptureRow = claude("3","two","bbb",Counts.Counters{"20","","5","2","6"},"incomplete")
  +result : T.Aggregate = A.summarize([known,partial,alias],True{})
  do IO<Unit>:
    check(exact_providers(result,"claude 2/1/0/0 10:1:1:0 2:1:1:0 3:1:1:0 1:1:1:0 4:1:1:0",empty_codex()),
      "missing required counter withholds all that group's counters once while preserving explicit known subtotals")
    check(pair_states(A.summarize([partial,alias],True{}),"unknown:2","alias_unknown:2"),"incomplete accounting with complete identical bytes is one unknown contribution")
    check(exact_providers(A.summarize([claude("4","zero","ccc",Counts.Counters{"0","0","0","","0"},"eligible")],True{}),
      "claude 1/0/0/0 0:1:0:0 0:1:0:0 0:1:0:0 :0:1:0 0:1:0:0",empty_codex()),
      "measured zero remains known while optional one-hour creation remains unknown")
    check(single_state(A.summarize([claude("5","bad","ddd",Counts.Counters{"1e9","0","0","","0"},"eligible")],True{}),"unknown:5"),
      "noncanonical malformed counters cannot reach decimal addition")
    inconsistent_alias_accounting()
    check(exact_providers(A.summarize([known,claude("8","one","aaa",full(),"incomplete")],True{}),
      "claude 1/1/0/0 :0:1:0 :0:1:0 :0:1:0 :0:1:0 :0:1:0",empty_codex()),
      "incomplete status with populated counters still withholds the whole exact-byte group")
    check(pair_states(A.summarize([known,row("claude","9","one","aaa","other",full(),"eligible")],True{}),"unknown:1","alias_unknown:1"),
      "inconsistent classification under identical bytes cannot select a canonical accounting winner")
    check(exact_providers(A.summarize([codex("7","x","eee",Counts.empty(),"incomplete")],True{}),empty_claude(),
      "codex 1/0/0/0 :0:1:0 :0:1:0 :0:0:1 :0:0:1 :0:1:0"),"unknown Codex accounting does not turn creation N/A into an unknown measurement")

def reviewer_alias() -> IO(Unit):
  +reviewer : T.CaptureRow = row("codex","1","review","aaa","reviewer",Counts.Counters{"99","2","","","3"},"reviewer")
  +ordinary : T.CaptureRow = row("codex","4","review","aaa","ordinary",Counts.Counters{"99","2","","","3"},"eligible")
  do IO<Unit>:
    check(pair_states(A.summarize([ordinary,reviewer],True{}),"reviewer:","reviewer:"),"a reviewer-classified exact alias cannot be counted through an ordinary peer")

def excluded() -> IO(Unit):
  +reviewer : T.CaptureRow = row("codex","1","review","aaa","reviewer",Counts.Counters{"99","2","","","3"},"reviewer")
  +unknown1 : T.CaptureRow = claude("2","","bbb",full(),"identity_unknown")
  +unknown2 : T.CaptureRow = claude("3","","bbb",full(),"identity_unknown")
  do IO<Unit>:
    check(exact_providers(A.summarize([reviewer,unknown1,unknown2],True{}),
      "claude 0/0/0/2 :0:0:0 :0:0:0 :0:0:0 :0:0:0 :0:0:0",
      "codex 0/0/0/1 :0:0:0 :0:0:0 :0:0:0 :0:0:0 :0:0:0"),
      "reviewer is excluded and blank identities are never merged by bytes or filenames")
    check(single_state(A.summarize([reviewer],True{}),"reviewer:") && pair_states(A.summarize([unknown1,unknown2],True{}),"identity_unknown:","identity_unknown:"),
      "excluded captures remain addressable without invented canonical identities")
    reviewer_alias()
    check(single_state(A.summarize([row("other","5","x","ccc","ordinary",full(),"eligible")],True{}),"excluded:"),
      "unknown provider remains excluded from the two supported rows")

def copies(+remaining: Nat) -> List<&2,T.CaptureRow>:
  match remaining:
    case 0n: []
    case 1n+rest: claude(Nat.show(remaining),"shared","aaa",full(),"eligible") <> copies(rest)

def boundaries() -> IO(Unit):
  +huge : String = "9999999999999999999999999999999999999999999999999999999999999999"
  +one : Counts.Counters = Counts.Counters{huge,"0","0","0","9007199254740993"}
  +result : T.Aggregate = A.summarize([claude("1","a","aaa",one,"eligible"),claude("2","b","bbb",one,"eligible")],True{})
  +empty : T.Aggregate = A.summarize([],True{})
  +withheld : T.Aggregate = A.summarize([claude("3","c","ccc",full(),"eligible")],False{})
  +overbound : T.Aggregate = A.summarize(copies(257n),True{})
  +wide : Counts.Counters = Counts.Counters{"1" ++ String.repeat("0",64n),"0","0","0","0"}
  do IO<Unit>:
    check(exact_providers(result,
      "claude 2/0/0/0 19999999999999999999999999999999999999999999999999999999999999998:2:0:0 0:2:0:0 0:2:0:0 0:2:0:0 18014398509481986:2:0:0",empty_codex()),
      "decimal sums preserve 64-digit carry and integers above 2^53")
    check(exact_providers(A.summarize([claude("4","wide-a","ddd",wide,"eligible"),claude("5","wide-b","eee",wide,"eligible")],True{}),
      "claude 2/0/0/0 2" ++ String.repeat("0",64n) ++ ":2:0:0 0:2:0:0 0:2:0:0 0:2:0:0 0:2:0:0",empty_codex()),
      "already aggregated capture counters wider than individual JSON inputs remain exact")
    check(available(empty) && exact_providers(empty,empty_claude(),empty_codex()) && Nat.is_eq(List.length(&2,T.Decision,decisions(empty)),0n),
      "empty catalog has stable provider rows and no manufactured measured zero")
    check(Bool.not(available(withheld)) && Nat.is_eq(List.length(&2,String,providers(withheld)),0n) && single_state(withheld,"withheld:"),
      "incomplete catalog withholds every provider total but preserves capture decisions")
    check(exact_providers(A.summarize(copies(256n),True{}),"claude 1/255/0/0 10:1:0:0 2:1:0:0 3:1:0:0 1:1:0:0 4:1:0:0",empty_codex()),
      "maximum 256-capture group preserves one contribution and all 255 aliases")
    check(Bool.not(available(overbound)) && Nat.is_eq(List.length(&2,String,providers(overbound)),0n) &&
      Nat.is_eq(List.length(&2,T.Decision,decisions(overbound)),257n),"caller source-bound violation withholds totals and preserves decisions")

def main() -> IO(Unit):
  do IO<Unit>:
    exact_and_distinct()
    conflicts()
    unknowns()
    excluded()
    boundaries()
