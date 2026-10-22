import Base
import ./json.bend as J
import ./gui_settings.bend as Shape
import ./provenance.bend as P
import ./session_usage.bend as S
import ./session_usage_counts.bend as Counts
import ./session_usage_claude.bend as Claude
import ./library_usage_types.bend as T
import ./library_usage_aggregate.bend as A

# Same-app summary protocol. The read-only worker verifies retained raw; this
# codec validates transport shape, bounds and identity, not counter authority.
# Per-capture reports are omitted. Fresh exact-capture evidence remains separate.
def check(valid: Bool) -> Result<&2,&2,String,Unit>:
  match valid:
    case True{}: Done{Unit{}}
    case False{}: Fail{"Library Usage summary has an invalid shape, identity, value or bound; no partial summary was accepted."}

def invalid(-X: Data) -> Result<&2,&2,String,X>:
  Fail{"Library Usage summary has an invalid shape, identity, value or bound; no partial summary was accepted."}

def fits(+text: String,budget: U32) -> Bool:
  Bool.not(String.contains(text,"\0")) && Claude.fits_result(Claude.remaining(text,budget))

def uint(+text: String,maximum: U32) -> Bool:
  Nat.is_le(String.length(text),10n) && P.decimal_valid(text) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(text,U32.show(maximum))))

def id(+text: String) -> Bool:
  Nat.is_le(String.length(text),19n) && P.decimal_valid(text) && Bool.not(String.eq(text,"0")) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(text,"9223372036854775807")))

def path(+text: String) -> Bool:
  fits(text,8192) && String.starts_with(text,"/")

def hex(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      ((cp >= 48 && cp <= 57 : U32) || (cp >= 97 && cp <= 102 : U32)) && hex(rest)

def sha(+text: String) -> Bool:
  String.is_empty(text) || (Nat.is_eq(String.length(text),64n) && hex(text))

def category(value: String) -> Bool:
  match value:
    case "ordinary": True{}
    case "fork": True{}
    case "reviewer": True{}
    case "unknown": True{}
    case _: False{}

def status(value: String) -> Bool:
  match value:
    case "eligible": True{}
    case "incomplete": True{}
    case "identity_unknown": True{}
    case "reviewer": True{}
    case "limited": True{}
    case _: False{}

# A bounded capture can sum many 64-digit provider observations. This wire cap
# preserves those wider totals without floating point, truncation or rounding.
def counter(+text: String) -> Bool:
  String.is_empty(text) || (Nat.is_le(String.length(text),256n) && P.decimal_valid(text))

def valid_counts(value: Counts.Counters) -> Bool:
  Counts.Counters{a,b,c,d,e} = value
  counter(a) && counter(b) && counter(c) && counter(d) && counter(e)

def valid_capture(value: S.Capture) -> Bool:
  S.Capture{provider,source,locator,generation,snapshot,_,_} = value
  Shape.provider(provider) && id(source) && path(locator) && id(generation) && id(snapshot)

def same_capture(a: S.Capture,b: S.Capture) -> Bool:
  S.Capture{ap,ai,al,ag,asnap,ae,ar} = a
  S.Capture{bp,bi,bl,bg,bsnap,be,br} = b
  String.eq(ap,bp) && String.eq(ai,bi) && String.eq(al,bl) && String.eq(ag,bg) &&
    String.eq(asnap,bsnap) && U32.is_eq(ae,be) && U32.is_eq(ar,br)

def valid_row(value: T.CaptureRow) -> Bool:
  T.CaptureRow{capture,session,hash,kind,counts,state,reason,_} = value
  valid_capture(capture) && fits(session,65536) && sha(hash) && category(kind) &&
    valid_counts(counts) && status(state) && fits(reason,65536)

def same_identity(a: S.Capture,b: S.Capture) -> Bool:
  S.Capture{_,source_a,_,_,snapshot_a,_,_} = a
  S.Capture{_,source_b,_,_,snapshot_b,_,_} = b
  String.eq(source_a,source_b) || String.eq(snapshot_a,snapshot_b)

def seen(values: List<&2,S.Capture>,+capture: S.Capture) -> Bool:
  match values:
    case []: False{}
    case value <> rest: same_identity(value,capture) || seen(rest,capture)

def row_capture(value: T.CaptureRow) -> S.Capture:
  T.CaptureRow{capture,_,_,_,_,_,_,_} = value
  capture

def valid_rows(values: List<&2,T.CaptureRow>,fuel: Nat,+prior: List<&2,S.Capture>) -> Bool:
  match values fuel:
    case [] _: True{}
    case _ 0n: False{}
    case +value <> rest 1n+n:
      +capture : S.Capture = row_capture(value)
      valid_row(value) && Bool.not(seen(prior,capture)) && valid_rows(rest,n,capture <> prior)

def default_limits(value: T.Limits) -> Bool:
  T.Limits{sources,records,bytes} = value
  U32.is_eq(sources,256) && U32.is_eq(records,1000000) && U32.is_eq(bytes,134217728)

def valid_report(value: T.Report) -> Bool:
  T.Report{_,+sources,+records,+bytes,limits,+rows,_} = value
  default_limits(limits) && U32.is_le(sources,256) && U32.is_le(records,1000000) && U32.is_le(bytes,134217728) &&
    (U32.is_gt(sources,0) || (U32.is_eq(records,0) && U32.is_eq(bytes,0))) &&
    Nat.is_eq(List.length(&2,T.CaptureRow,rows),U32.to_nat(sources)) && valid_rows(rows,256n,[])

def counter_json(value: Counts.Counters) -> String:
  Counts.Counters{a,b,c,d,e} = value
  "{\"input\":" ++ J.quote(a) ++ ",\"cached\":" ++ J.quote(b) ++ ",\"created\":" ++ J.quote(c) ++
    ",\"created1h\":" ++ J.quote(d) ++ ",\"output\":" ++ J.quote(e) ++ "}"

def row_json(value: T.CaptureRow) -> String:
  T.CaptureRow{capture,session,hash,kind,counts,state,reason,_} = value
  "{\"capture\":" ++ S.capture_text(capture) ++ ",\"session\":" ++ J.quote(session) ++ ",\"sha256\":" ++ J.quote(hash) ++
    ",\"category\":" ++ J.quote(kind) ++ ",\"counts\":" ++ counter_json(counts) ++ ",\"status\":" ++ J.quote(state) ++
    ",\"reason\":" ++ J.quote(reason) ++ "}"

def rows_json(values: List<&2,T.CaptureRow>) -> String:
  match values:
    case []: ""
    case [value]: row_json(value)
    case value <> rest: row_json(value) ++ "," ++ rows_json(rest)

def report_json(nonce: U32,value: T.Report) -> String:
  T.Report{complete,sources,records,bytes,_,rows,_} = value
  "{\"kind\":\"library_usage\",\"version\":1,\"nonce\":" ++ U32.show(nonce) ++
    ",\"catalog_complete\":" ++ S.boolean(complete) ++ ",\"selected_sources\":" ++ U32.show(sources) ++
    ",\"verified_records\":" ++ U32.show(records) ++ ",\"verified_bytes\":" ++ U32.show(bytes) ++
    ",\"limits\":{\"sources\":256,\"records\":1000000,\"bytes\":134217728},\"rows\":[" ++ rows_json(rows) ++ "]}"

def bounded(+text: String) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    # Reserve the worker's final newline within the 2 MiB transport bound.
    Unit <- check(Claude.fits_result(Claude.remaining(text,2097151)))
    return text

def encode(+nonce: U32,+report: T.Report) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    Unit <- check(U32.is_gt(nonce,0) && valid_report(report))
    bounded(report_json(nonce,report))

def string(value: J.Json,budget: U32) -> Result<&2,&2,String,String>:
  match value:
    case J.JString{+text}:
      do Result<&2,&2,String,String>:
        Unit <- check(fits(text,budget))
        return text
    case _: invalid(String)

def parsed_number(value: Maybe<&2,U32>) -> Result<&2,&2,String,U32>:
  match value:
    case Some{value}: Done{value}
    case None{}: invalid(U32)

def uint_text(+text: String,maximum: U32) -> Result<&2,&2,String,U32>:
  do Result<&2,&2,String,U32>:
    Unit <- check(uint(text,maximum))
    parsed_number(P.parse_u32(text))

def number(value: J.Json,maximum: U32) -> Result<&2,&2,String,U32>:
  match value:
    case J.JNumber{text}: uint_text(text,maximum)
    case _: invalid(U32)

def number_string(value: J.Json,maximum: U32) -> Result<&2,&2,String,U32>:
  match value:
    case J.JString{text}: uint_text(text,maximum)
    case _: invalid(U32)

def boolean(value: J.Json) -> Result<&2,&2,String,Bool>:
  match value:
    case J.JBool{flag}: Done{flag}
    case _: invalid(Bool)

def identifier(value: J.Json) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    +text : String <- string(value,19)
    Unit <- check(id(text))
    return text

def parse_capture(+value: J.Json) -> Result<&2,&2,String,S.Capture>:
  do Result<&2,&2,String,S.Capture>:
    Unit <- check(Shape.exact_object(value,["provider","source_id","source","generation","snapshot","extent","records"]))
    +provider : String <- string(J.field(value,"provider"),16)
    source : String <- identifier(J.field(value,"source_id"))
    +locator : String <- string(J.field(value,"source"),8192)
    generation : String <- identifier(J.field(value,"generation"))
    snapshot : String <- identifier(J.field(value,"snapshot"))
    extent : U32 <- number_string(J.field(value,"extent"),4294967295)
    records : U32 <- number_string(J.field(value,"records"),4294967295)
    Unit <- check(Shape.provider(provider) && path(locator))
    return S.Capture{provider,source,locator,generation,snapshot,extent,records}

def count(value: J.Json) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    +text : String <- string(value,256)
    Unit <- check(counter(text))
    return text

def counts(+value: J.Json) -> Result<&2,&2,String,Counts.Counters>:
  do Result<&2,&2,String,Counts.Counters>:
    Unit <- check(Shape.exact_object(value,["input","cached","created","created1h","output"]))
    a : String <- count(J.field(value,"input"))
    b : String <- count(J.field(value,"cached"))
    c : String <- count(J.field(value,"created"))
    d : String <- count(J.field(value,"created1h"))
    e : String <- count(J.field(value,"output"))
    return Counts.Counters{a,b,c,d,e}

def row(+value: J.Json) -> Result<&2,&2,String,T.CaptureRow>:
  do Result<&2,&2,String,T.CaptureRow>:
    Unit <- check(Shape.exact_object(value,["capture","session","sha256","category","counts","status","reason"]))
    parsed_capture : S.Capture <- parse_capture(J.field(value,"capture"))
    session : String <- string(J.field(value,"session"),65536)
    +hash : String <- string(J.field(value,"sha256"),64)
    +kind : String <- string(J.field(value,"category"),16)
    counters : Counts.Counters <- counts(J.field(value,"counts"))
    +state : String <- string(J.field(value,"status"),32)
    reason : String <- string(J.field(value,"reason"),65536)
    Unit <- check(sha(hash) && category(kind) && status(state))
    return T.CaptureRow{parsed_capture,session,hash,kind,counters,state,reason,None{}}

def rows(values: List<&2,J.Json>,fuel: Nat,+prior: List<&2,S.Capture>) -> Result<&2,&2,String,List<&2,T.CaptureRow>>:
  match values fuel:
    case [] _: Done{[]}
    case _ 0n: invalid(List<&2,T.CaptureRow>)
    case value <> rest 1n+n:
      do Result<&2,&2,String,List<&2,T.CaptureRow>>:
        +parsed : T.CaptureRow <- row(value)
        Unit <- check(Bool.not(seen(prior,row_capture(parsed))))
        tail : List<&2,T.CaptureRow> <- rows(rest,n,row_capture(parsed) <> prior)
        return parsed <> tail

def array(value: J.Json) -> Result<&2,&2,String,List<&2,T.CaptureRow>>:
  match value:
    case J.JArray{values}: rows(values,256n,[])
    case _: invalid(List<&2,T.CaptureRow>)

def limits(+value: J.Json) -> Bool:
  Shape.exact_object(value,["sources","records","bytes"]) && Shape.number_is(J.field(value,"sources"),"256") &&
    Shape.number_is(J.field(value,"records"),"1000000") && Shape.number_is(J.field(value,"bytes"),"134217728")

def accepted(+nonce: U32,+report: T.Report) -> Result<&2,&2,String,T.Report>:
  do Result<&2,&2,String,T.Report>:
    Unit <- check(valid_report(report))
    ignored : String <- bounded(report_json(nonce,report))
    return report

def decode(+value: J.Json,+expected_nonce: U32) -> Result<&2,&2,String,T.Report>:
  do Result<&2,&2,String,T.Report>:
    Unit <- check(Shape.exact_object(value,["kind","version","nonce","catalog_complete","selected_sources","verified_records","verified_bytes","limits","rows"]) &&
      Shape.text_is(J.field(value,"kind"),"library_usage") && Shape.number_is(J.field(value,"version"),"1") && limits(J.field(value,"limits")))
    nonce : U32 <- number(J.field(value,"nonce"),4294967295)
    Unit <- check(U32.is_gt(expected_nonce,0) && U32.is_eq(nonce,expected_nonce))
    +complete : Bool <- boolean(J.field(value,"catalog_complete"))
    sources : U32 <- number(J.field(value,"selected_sources"),256)
    records : U32 <- number(J.field(value,"verified_records"),1000000)
    bytes : U32 <- number(J.field(value,"verified_bytes"),134217728)
    +values : List<&2,T.CaptureRow> <- array(J.field(value,"rows"))
    accepted(expected_nonce,T.Report{complete,sources,records,bytes,T.defaults(),values,A.summarize(values,complete)})

def parsed(value: Result<&2,&2,String,J.Json>,nonce: U32) -> Result<&2,&2,String,T.Report>:
  match value:
    case Fail{_}: invalid(T.Report)
    case Done{value}: decode(value,nonce)

# Reuse the pinned parser with scalar fuel covering the admitted byte bound.
# Its default parse() fuel is only one MiB, including skipped whitespace.
def parse_summary(text: String) -> Result<&2,&2,String,J.Json>:
  do Result<&2,&2,String,J.Json>:
    tokens : List<&2,J.Token> <- J.lex(text,J.JLBase{[]},2097152n)
    J.tree(tokens,[J.JFRoot{}])

def output(code: U32,+out: String,err: String,nonce: U32) -> Result<&2,&2,String,T.Report>:
  do Result<&2,&2,String,T.Report>:
    Unit <- check(U32.is_eq(code,0) && String.is_empty(err) && Claude.fits_result(Claude.remaining(out,2097152)))
    parsed(parse_summary(out),nonce)

def completed(value: Result<&1,&1,U32 & String,U32 & (String & String)>,expected_nonce: U32) -> Result<&2,&2,String,T.Report>:
  match value:
    case Fail{_}: invalid(T.Report)
    case Done{(code,(out,err))}: output(code,out,err,expected_nonce)
