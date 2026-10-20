import Base
import ../src/projection_seal.bend as Seal
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def parser() -> String:
  "providers-v4-utc-context-relay"

def header() -> Seal.Header:
  Seal.Header{"9007199254740993","42","9007199254740995","claude",
    "/synthetic/history.jsonl",80,4,60,3}

def fields(body: String) -> List<&2,Sql.Cell>:
  [Sql.Cell.Text{"assistant"},Sql.Cell.Text{body},Sql.Cell.Text{"tool"},
   Sql.Cell.Text{"call"},Sql.Cell.Text{"arguments"},Sql.Cell.Text{"result"},
   Sql.Cell.Text{"repository"},Sql.Cell.Text{"session"},Sql.Cell.Text{"timestamp"},
   Sql.Cell.Text{"model"},Sql.Cell.Text{"usage"},Sql.Cell.Text{"parent"},
   Sql.Cell.Text{"coverage"}]

def row(ordinal: String,event: String,body: String) -> List<&2,Sql.Cell>:
  Sql.Cell.Integer{ordinal} <> Sql.Cell.Integer{event} <> fields(body)

def require_scan(value: Maybe<&2,Seal.Scan>) -> IO(Seal.Scan):
  match value:
    case Some{scan}:
      IO.pure(Seal.Scan,scan)
    case None{}:
      IO.die(Seal.Scan,1,"FAIL valid event scan rejected")

def rejected(value: Maybe<&2,Seal.Scan>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{_}:
      False{}

def reject_row(row: List<&2,Sql.Cell>,label: String) -> IO(Unit):
  check(rejected(Seal.push(header(),0,row,Seal.start(parser()))),label)

def decoded(value: Maybe<&2,Seal.Envelope>,expected: String) -> Bool:
  match value:
    case Some{envelope}:
      String.eq(Seal.encode(envelope),expected)
    case None{}:
      False{}

def invalid_envelope(value: Maybe<&2,Seal.Envelope>) -> Bool:
  match value:
    case Some{_}:
      False{}
    case None{}:
      True{}

def replace(index: Nat,cells: List<&2,Sql.Cell>,value: Sql.Cell) -> List<&2,Sql.Cell>:
  match index cells:
    case _ Nil{}:
      []
    case 0n Con{_,tail}:
      value <> tail
    case 1n+rest Con{head,tail}:
      head <> replace(rest,tail,value)

def changes(remaining: Nat,+index: Nat,+baseline: String) -> IO(Unit):
  match remaining:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        changed : Seal.Scan <- require_scan(Seal.push(header(),0,
          replace(index,row("1","0","body"),Sql.Cell.Text{"changed"}),Seal.start(parser())))
        check(Bool.not(String.eq(Seal.encode(Seal.finish(header(),parser(),changed)),baseline)),
          "event text field " ++ Nat.show(index) ++ " changes its commitment")
        reject_row(replace(index,row("1","0","body"),Sql.Cell.Blob{[]}),
          "event field " ++ Nat.show(index) ++ " rejects Blob in place of Text")
        changes(rest,Nat.add(index,1n),baseline)

def scan_is(scan: Seal.Scan,+expected: String,+n: Nat) -> Bool:
  Seal.Scan{chain,count,prefix,prefix_count,_} = scan
  String.eq(chain,expected) && String.eq(prefix,expected) &&
    Nat.is_eq(count,n) && Nat.is_eq(prefix_count,n)

def checkpoint_count(scan: Seal.Scan) -> Nat:
  Seal.Scan{_,_,_,count,_} = scan
  count

def resumed(scan: Seal.Scan) -> Seal.Scan:
  Seal.Scan{_,_,chain,count,_} = scan
  Seal.resume(chain,count)

def framing() -> IO(Unit):
  +seed = Domain.digest(Domain.encode(
    "event-seal-v1|seed|text:\"providers-v4-utc-context-relay\":"))
  do IO<Unit>:
    check(String.eq(Seal.seed(parser()),seed),"seed has independent literal typed parser framing")
    check(String.eq(Seal.version(parser()),"providers-v4-utc-context-relay|event-seal-v1"),
      "seal format is explicit and separate from the unchanged parser tag")
    +one : Seal.Scan <- require_scan(Seal.push(header(),0,
      row("1","0","Café 🍋\0\"\\:\n|"),Seal.start(parser())))
    +expected : String = Domain.digest(Domain.encode("event-seal-v1|event|text:\"" ++ seed ++
      "\":integer:\"1\":integer:\"0\":text:\"assistant\":text:\"Café 🍋\\u0000\\\"\\\\:\\u000a|\":" ++
      "text:\"tool\":text:\"call\":text:\"arguments\":text:\"result\":text:\"repository\":" ++
      "text:\"session\":text:\"timestamp\":text:\"model\":text:\"usage\":text:\"parent\":text:\"coverage\":"))
    check(scan_is(one,expected,1n),
      "Unicode NUL quotes slash colon pipe and all typed positions preserve literal framing")
    +envelope : String = Seal.encode(Seal.finish(header(),parser(),one))
    check(decoded(Seal.decode(envelope),envelope),"canonical envelope round trips without numeric rounding")
    check(Seal.matches(header(),parser(),one,envelope),"fresh actual scan matches its exact envelope")
    +basic : Seal.Scan <- require_scan(Seal.push(header(),0,row("1","0","body"),Seal.start(parser())))
    changes(13n,2n,Seal.encode(Seal.finish(header(),parser(),basic)))

def header_changes(rows: List<&2,Seal.Header>,+scan: Seal.Scan,+expected: String,+index: Nat) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case h <> rest:
      do IO<Unit>:
        check(Bool.not(Seal.matches(h,parser(),scan,expected)),
          "snapshot header binding " ++ Nat.show(index) ++ " rejects alteration")
        header_changes(rest,scan,expected,Nat.add(index,1n))

def headers() -> IO(Unit):
  do IO<Unit>:
    +scan : Seal.Scan <- require_scan(Seal.push(header(),0,row("1","0","body"),Seal.start(parser())))
    +sealed : String = Seal.encode(Seal.finish(header(),parser(),scan))
    check(Seal.header_valid(header()),"exact identities above 2^53 remain valid")
    header_changes([
      Seal.Header{"9007199254740994","42","9007199254740995","claude","/synthetic/history.jsonl",80,4,60,3},
      Seal.Header{"9007199254740993","43","9007199254740995","claude","/synthetic/history.jsonl",80,4,60,3},
      Seal.Header{"9007199254740993","42","9007199254740996","claude","/synthetic/history.jsonl",80,4,60,3},
      Seal.Header{"9007199254740993","42","9007199254740995","codex","/synthetic/history.jsonl",80,4,60,3},
      Seal.Header{"9007199254740993","42","9007199254740995","claude","/synthetic/other.jsonl",80,4,60,3},
      Seal.Header{"9007199254740993","42","9007199254740995","claude","/synthetic/history.jsonl",81,4,60,3},
      Seal.Header{"9007199254740993","42","9007199254740995","claude","/synthetic/history.jsonl",80,5,60,3},
      Seal.Header{"9007199254740993","42","9007199254740995","claude","/synthetic/history.jsonl",80,4,61,3},
      Seal.Header{"9007199254740993","42","9007199254740995","claude","/synthetic/history.jsonl",80,4,60,2}
    ],scan,sealed,0n)
    check(Bool.not(Seal.matches(header(),"another-parser",scan,sealed)),"parser identity is in snapshot commitment")
    check(Bool.not(Seal.identity("9223372036854775808")) &&
      Seal.identity("9223372036854775807"),"identity signed64 boundary is exact")
    check(Bool.not(Seal.identity("09007199254740993")) && Bool.not(Seal.identity("0")),
      "identity requires canonical positive decimal")

def malformed() -> IO(Unit):
  do IO<Unit>:
    reject_row(row("-1","0","body"),"negative ordinal is rejected rather than skipped")
    reject_row(row("1","-1","body"),"negative event index is rejected rather than skipped")
    reject_row(Sql.Cell.Real{"-1e100"} <> Sql.Cell.Integer{"0"} <> fields("body"),
      "REAL ordinal below INT64_MIN is rejected")
    reject_row(Sql.Cell.Integer{"1"} <> Sql.Cell.Real{"0.0"} <> fields("body"),
      "REAL event key cannot impersonate integer zero")
    reject_row(Sql.Cell.Text{"1"} <> Sql.Cell.Integer{"0"} <> fields("body"),
      "Text ordinal cannot impersonate integer identity")
    reject_row(row("01","0","body"),"noncanonical ordinal is rejected")
    reject_row(row("1","00","body"),"noncanonical event index is rejected")
    reject_row(row("4294967296","0","body"),"ordinal above U32 is rejected before narrowing")
    reject_row(row("4","0","body"),"event ordinal must be below snapshot physical record count")
    reject_row(row("1","1","body"),"first event of a physical record must have index zero")
    reject_row(List.take(&2,Sql.Cell,row("1","0","body"),14n),"missing event field is rejected")
    reject_row(List.append(&2,Sql.Cell,row("1","0","body"),[Sql.Cell.Text{"extra"}]),
      "extra event field is rejected")
    +one : Seal.Scan <- require_scan(Seal.push(header(),0,row("1","0","first"),Seal.start(parser())))
    check(rejected(Seal.push(header(),0,row("1","0","duplicate"),one)),"duplicate event index is rejected")
    check(rejected(Seal.push(header(),0,row("1","2","gap"),one)),"event index gap is rejected")
    check(rejected(Seal.push(header(),0,row("0","0","backward"),one)),"decreasing ordinal is rejected")
    check(rejected(Seal.push(header(),2,row("1","0","prefix"),Seal.start(parser()))),
      "tail scan cannot accept a prefix ordinal")
    check(rejected(Seal.push(header(),0,row("1","0","overflow"),
      Seal.Scan{Seal.seed(parser()),Seal.maximum_count(),Seal.seed(parser()),0n,None{}})),
      "total event count refuses U32 overflow before hashing")
    check(rejected(Seal.push(header(),0,row("1","0","wrap"),
      Seal.Scan{Seal.seed(parser()),1n,Seal.seed(parser()),0n,Some{Seal.EventKey{1,4294967295}}})),
      "per-record index cannot wrap from U32_MAX to zero")

def partial_tail() -> IO(Unit):
  +prefix = {[row("1","0","first"),row("1","1","second")] : List<&2,List<&2,Sql.Cell>>}
  +new_header = {Seal.Header{"9007199254740997","42","9007199254740995","claude",
    "/synthetic/history.jsonl",100,5,100,5} : Seal.Header}
  +tail = {[row("3","0","completed tail"),row("4","0","new complete record")] : List<&2,List<&2,Sql.Cell>>}
  do IO<Unit>:
    +old : Seal.Scan <- require_scan(Seal.feed(header(),0,
      List.append(&2,List<&2,Sql.Cell>,prefix,[row("3","0","unfinished old tail")]),Seal.start(parser())))
    check(Nat.is_eq(checkpoint_count(old),2n),"partial tail is excluded from verified complete-prefix count")
    +extended : Seal.Scan <- require_scan(Seal.feed(new_header,3,tail,resumed(old)))
    +fresh : Seal.Scan <- require_scan(Seal.feed(new_header,0,
      List.append(&2,List<&2,Sql.Cell>,prefix,tail),Seal.start(parser())))
    check(String.eq(Seal.encode(Seal.finish(new_header,parser(),extended)),
      Seal.encode(Seal.finish(new_header,parser(),fresh))),"prefix extension equals complete fresh seal after partial-tail replacement")
    +old_seal : String = Seal.encode(Seal.finish(header(),parser(),old))
    +corrupt_tail : Seal.Scan <- require_scan(Seal.feed(header(),0,
      List.append(&2,List<&2,Sql.Cell>,prefix,[row("3","0","damaged unfinished tail")]),Seal.start(parser())))
    check(Bool.not(Seal.matches(header(),parser(),corrupt_tail,old_seal)),
      "old unfinished tail is still verified before any prefix can be reused")
    +empty : Seal.Scan = Seal.start(parser())
    check(scan_is(empty,Seal.seed(parser()),0n),
      "physical records with zero events retain the exact empty prefix")
    check(decoded(Seal.decode(Seal.encode(Seal.finish(header(),parser(),empty))),
      Seal.encode(Seal.finish(header(),parser(),empty))),"zero-event snapshot envelope round trips")

def rows(remaining: Nat,+index: U32) -> List<&2,List<&2,Sql.Cell>>:
  match remaining:
    case 0n:
      []
    case 1n+rest:
      row(U32.show(U32.div(index,3)),U32.show(U32.mod(index,3)),"body " ++ U32.show(index)) <>
        rows(rest,U32.add(index,1))

def pagination() -> IO(Unit):
  +h = {Seal.Header{"7","8","9","claude","/synthetic/pages.jsonl",1000,44,990,43} : Seal.Header}
  +events = rows(132n,0)
  do IO<Unit>:
    +full : Seal.Scan <- require_scan(Seal.feed(h,0,events,Seal.start(parser())))
    first : Seal.Scan <- require_scan(Seal.feed(h,0,List.take(&2,List<&2,Sql.Cell>,events,64n),Seal.start(parser())))
    second : Seal.Scan <- require_scan(Seal.feed(h,0,List.take(&2,List<&2,Sql.Cell>,
      List.drop(&2,List<&2,Sql.Cell>,events,64n),64n),first))
    paged : Seal.Scan <- require_scan(Seal.feed(h,0,List.drop(&2,List<&2,Sql.Cell>,events,128n),second))
    check(String.eq(Seal.encode(Seal.finish(h,parser(),full)),Seal.encode(Seal.finish(h,parser(),paged))),
      "64-row pages crossing physical-record fanout preserve exact seal and checkpoint")

def envelopes() -> IO(Unit):
  +hash = String.repeat("a",64n)
  +base = "event-seal-v1|0|" ++ hash ++ "|0|" ++ hash ++ "|" ++ hash
  do IO<Unit>:
    check(decoded(Seal.decode(base),base),"strict six-part envelope is canonical")
    check(invalid_envelope(Seal.decode(base ++ "|extra")),"extra envelope part rejected")
    check(invalid_envelope(Seal.decode("event-seal-v0|0|" ++ hash ++ "|0|" ++ hash ++ "|" ++ hash)),
      "old format is never reinterpreted")
    check(invalid_envelope(Seal.decode("event-seal-v1|00|" ++ hash ++ "|0|" ++ hash ++ "|" ++ hash)),
      "noncanonical count rejected")
    check(invalid_envelope(Seal.decode("event-seal-v1|1|" ++ hash ++ "|0|" ++ hash ++ "|" ++ hash)),
      "checkpoint count cannot exceed total")
    check(invalid_envelope(Seal.decode("event-seal-v1|0|" ++ hash ++ "|9223372036854775808|" ++ hash ++ "|" ++ hash)),
      "envelope signed64 count overflow rejected")
    check(invalid_envelope(Seal.decode("event-seal-v1|0|" ++ hash ++ "|0|" ++ hash ++ "|" ++ String.repeat("A",64n))),
      "noncanonical digest rejected")
    check(invalid_envelope(Seal.decode(String.repeat("x",257n))),"oversized envelope rejected before splitting")

def main() -> IO(Unit):
  do IO<Unit>:
    framing()
    headers()
    malformed()
    partial_tail()
    pagination()
    envelopes()
