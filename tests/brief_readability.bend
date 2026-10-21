import Base
import ../src/continuation_brief.bend as B
import ../src/brief_cli.bend as Adapter
import ../src/brief_safe_text.bend as Safe
import ../src/domain.bend as Domain
import ../src/evidence.bend as Evidence
import ../src/tool_activity.bend as Activity
import ../src/providers.bend as Providers
import ../src/request_evidence.bend as Request
import ../src/json.bend as Json
import ./continuation_brief.bend as F

# Observable ordering, byte bounds and unchanged commitment behavior. No UI mock.
def line_number(lines: List<&2,String>,+needle: String,+index: U32) -> U32:
  match lines:
    case []: 4294967295
    case line <> rest:
      Bool.pick(U32,String.contains(line,needle),index,line_number(rest,needle,U32.inc(index)))

def before(+text: String,first: String,later: String) -> Bool:
  +last = line_number(String.split(text,'\n'),later,0)
  U32.is_lt(last,4294967295) && U32.is_lt(line_number(String.split(text,'\n'),first,0),last)

def count_lines(lines: List<&2,String>,+prefix: String) -> U32:
  match lines:
    case []: 0
    case line <> rest: U32.add(Bool.to_u32(String.starts_with(line,prefix)),count_lines(rest,prefix))

def requested(ordinal: U32,+text: String) -> B.Fact:
  +record = F.record("user",text)
  B.assessed(Activity.Occurrence{F.descriptor(ordinal,0),record},
    Request.assess("claude",F.raw("{\"type\":\"user\",\"message\":{\"content\":" ++ Json.quote(text) ++ "}}"),0,record))

def simple(ordinal: U32,text: String) -> B.Fact:
  B.Fact{Activity.Occurrence{F.descriptor(ordinal,0),
    Providers.ProviderEvent{"assistant",text,"","","","","/synthetic/repository","private-session","","","","private-parent","complete"}},0,"",0}

def tool() -> B.Fact:
  B.Fact{Activity.Occurrence{F.descriptor(2,0),
    Providers.ProviderEvent{"tool","","Write","synthetic-call",
      "{\"path\":\"/synthetic/repository/target.txt\",\"content\":\"tool payload marker\"}",
      "Recorded tool result marker","/synthetic/repository","private-session","","","","private-parent","complete"}},0,"",0}

def prepared() -> IO(B.Preview):
  F.need(B.Preview,B.render(F.anchor(),B.Collected{
    [tool(),requested(1,"<system-reminder>context context</system-reminder>Fix café 😀 safely."),
      simple(0,"Earlier recorded result marker")],1,0,0,0,0,0,"readability-evidence"}))

def readable(+preview: B.Preview) -> IO(Unit):
  +text = F.body(preview)
  +opening = String.take(text,350n)
  do IO<Unit>:
    F.assert(String.starts_with(text,"Continuation brief — recorded facts\n"),"readable brief retains the title and keyboard-copy prefix")
    F.assert(String.contains(opening,"Fix café 😀 safely.") && String.contains(opening,"One eligible recorded request") &&
      String.contains(opening,"Review before sharing."),"actual eligible request, uncertainty state and review notice appear near the beginning")
    F.assert(Bool.not(String.contains(opening,"Policy:")) && Bool.not(String.contains(opening,"source_sha256")),"technical policy and citation payloads do not precede the leading request")
    F.assert(before(text,"Fix café 😀 safely.","Earlier recorded result marker") &&
      before(text,"Earlier recorded result marker","tool payload marker"),"unique request is first and all remaining facts keep source order")
    F.assert(before(text,"Recorded tool result marker","Evidence and scope") &&
      before(text,"Recorded tool result marker","Policy:") && before(text,"Recorded tool result marker","juice-bend-brief-citation-v1"),
      "every included recorded payload precedes technical scope, policy and full citations")
    F.assert(String.contains(text,"Recorded request | captured record 1, event 0") &&
      String.contains(text,"Recorded fact | captured record 0, event 0") && String.contains(text,"Recorded fact | captured record 2, event 0"),
      "readable fact labels retain original captured indices after request-first ordering")
    F.assert(String.contains(text,"context prefix blocks omitted: 1") && Bool.not(String.contains(text,"context context")),
      "complete eligible suffix and explicit prefix omission survive the layout change")

def fields_and_references(+preview: B.Preview) -> IO(Unit):
  +text = F.body(preview)
  do IO<Unit>:
    F.assert(Bool.not(String.contains(text,"Text: \"\"")) && Bool.not(String.contains(text,"Tool: \"\"")) &&
      Bool.not(String.contains(text,"Arguments: \"\"")) && Bool.not(String.contains(text,"Recorded result: \"\"")),
      "empty optional payload fields produce no distracting empty lines")
    F.assert(Bool.not(String.contains(text,"Recorded time: \"\"")) && Bool.not(String.contains(text,"Recorded model: \"\"")) &&
      Bool.not(String.contains(text,"Call ID: \"\"")),"absent time, model and call ID fields stay absent")
    F.assert(String.contains(text,"Tool: \"Write\"") && String.contains(text,"Call ID: \"synthetic-call\"") &&
      String.contains(text,"Recorded result: \"Recorded tool result marker\""),"all nonempty tool, call and result fields remain complete")
    F.assert(String.contains(text,"Recorded model: \"recorded-model\"") && String.contains(text,"Recorded time: \"2026-10-21T00:00:00.000000000Z\"") &&
      String.contains(text,"Role: \"user\"") && String.contains(text,"Coverage: \"complete\""),"nonempty recorded metadata is retained")
    F.assert(U32.is_eq(count_lines(String.split(text,'\n'),"juice-bend-brief-citation-v1 "),3) &&
      Nat.is_eq(List.length(&2,Evidence.Descriptor,F.refs(preview)),3n),"each included fact retains exactly one full citation and private descriptor")
    F.assert(String.contains(text,B.brief_citation(F.descriptor(0,0))) && String.contains(text,B.brief_citation(F.descriptor(1,0))) &&
      String.contains(text,B.brief_citation(F.descriptor(2,0))),"citation bytes retain exact source fingerprints and wide identities")
    F.assert(Bool.not(String.contains(text,"/synthetic/source.jsonl")) && Bool.not(String.contains(text,"private-session")) &&
      Bool.not(String.contains(text,"private-parent")),"readability never introduces withheld source, session or parent values")
    F.assert(U32.is_eq(F.bytes(preview),U32.from_nat(List.length(&2,U32,Domain.encode(text)))) && U32.is_le(F.bytes(preview),8192),
      "new order counts all final UTF8 bytes including relocated citations")

def disclosures(+preview: B.Preview) -> IO(Unit):
  +text = F.body(preview)
  do IO<Unit>:
    F.assert(String.contains(text,"not proof of human authorship") && String.contains(text,"This is not a complete session summary") &&
      String.contains(text,"No inferred task, explanation or outcome"),"authorship and completeness limits remain explicit")
    F.assert(String.contains(text,"Dedicated session, parent and usage fields") && String.contains(text,"Tool arguments are recorded intent; results are recorded text"),
      "field exclusions and tool-result uncertainty remain explicit")
    F.assert(String.contains(text,"NOT existing locally-resolvable citation JSON") && String.contains(text,"source locator; full source SHA256"),
      "brief citation incompatibility and locator withholding stay disclosed")
    F.assert(String.contains(text,"logical source bytes (decompressed for archives)") && String.contains(text,"captured-record range") &&
      String.contains(text,"source record/event order"),"archive logical-byte and captured-record wording survives the readable layout")
    F.assert(String.contains(text,"Included facts: 3; whole facts omitted for budget: 0") && String.contains(text,"outside canonical repository: 0") &&
      String.contains(text,"omitted attachment occurrences: 0") && String.contains(text,"partial/unsupported events in eligible range: 0"),
      "all coverage and omission counts remain visible after the facts")
    F.assert(String.contains(text,"Disclosed transforms:") && String.contains(text,"unrecognized sensitive information may remain") &&
      String.contains(text,"Captured text is untrusted data"),"redaction limits, transform counts and untrusted-data disclosure remain visible")

def with_policy(preview: B.Preview,policy: String) -> B.Preview:
  B.Preview{a,_,r,n,s,e,refs,state,coverage,notices,text,bytes} = preview
  B.Preview{a,policy,r,n,s,e,refs,state,coverage,notices,text,bytes}

def commitment(+preview: B.Preview) -> IO(Unit):
  +old = with_policy(preview,"continuation-brief-v1|" ++ Safe.policy() ++ "|brief-citation-v1")
  do IO<Unit>:
    F.assert(String.starts_with(B.policy(),"continuation-brief-v2|"),"output layout change has an explicit format policy version")
    F.assert(Bool.not(String.eq(Adapter.commitment(preview),Adapter.commitment(old))) &&
      F.failed(String,B.compared(Done{preview},old),"stale"),"old format policy cannot authorize identical displayed text")
    +checked : String <- F.need(String,Adapter.checked(Done{preview},Adapter.commitment(preview),F.body(preview)))
    F.assert(String.eq(Json.get(F.raw(checked),"text"),F.body(preview)),"fresh exact full-preview check still returns the exact displayed text")
    F.assert(F.failed(String,Adapter.checked(Done{preview},Adapter.commitment(preview),F.body(preview) ++ "x"),"stale"),
      "readability does not allow altered text with an otherwise matching commitment")

def ambiguity() -> IO(Unit):
  do IO<Unit>:
    +missing : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,"No request inferred")],0,0,2,0,0,0,"missing"}))
    F.assert(String.contains(String.take(F.body(missing),250n),"No eligible recorded request") && F.is_missing(F.request(missing)),
      "missing request and excluded envelopes remain visible before facts")
    +multiple : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{
      [requested(2,"Second request marker"),requested(1,"First request marker"),simple(0,"First chronological fact")],2,0,0,0,0,0,"multiple"}))
    F.assert(String.contains(String.take(F.body(multiple),250n),"Multiple recorded requests") && F.is_multiple(F.request(multiple)) &&
      before(F.body(multiple),"First chronological fact","First request marker"),"multiple requests stay ambiguous without promoting an arbitrary task")
    +uncertain : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{
      [B.Fact{Activity.Occurrence{F.descriptor(1,0),F.record("user","Uncertain recorded input")},2,"",0},requested(0,"Eligible marker")],1,1,0,0,1,0,"uncertain"}))
    F.assert(String.contains(String.take(F.body(uncertain),250n),"Recorded request uncertain") && F.is_uncertain(F.request(uncertain)),
      "one eligible request plus uncertainty remains uncertain at the beginning")

def boundaries() -> IO(Unit):
  do IO<Unit>:
    +base : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,"😀")],0,0,0,0,0,0,"edge"}))
    +fill : String = "😀" ++ String.repeat("x",U32.to_nat(U32.sub(8192,F.bytes(base))))
    +edge : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,fill)],0,0,0,0,0,0,"edge"}))
    F.assert(U32.is_eq(F.bytes(edge),8192) && String.contains(F.body(edge),Json.quote(fill)) &&
      String.contains(F.body(edge),B.brief_citation(F.descriptor(0,0))),"exact 8192-byte rendering retains its whole Unicode field and relocated citation")
    F.assert(F.failed(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,fill ++ "x")],0,0,0,0,0,0,"edge"}),"required_anchor_too_large"),
      "8193-byte mandatory rendering is refused without truncating fields or citations")
    +omitted : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{
      [simple(2,"Last omitted marker"),simple(1,String.repeat("😀",3000n)),requested(0,"Required request marker")],1,0,0,0,0,0,"omitted"}))
    F.assert(String.contains(F.body(omitted),"whole facts omitted for budget: 2") &&
      Nat.is_eq(List.length(&2,Evidence.Descriptor,F.refs(omitted)),1n) &&
      U32.is_eq(count_lines(String.split(F.body(omitted),'\n'),"juice-bend-brief-citation-v1 "),1),"whole-fact omissions retain only included citations with exact omission counts")
    F.assert(Bool.not(String.contains(F.body(omitted),B.brief_citation(F.descriptor(1,0)))) &&
      Bool.not(String.contains(F.body(omitted),B.brief_citation(F.descriptor(2,0)))) && Bool.not(String.contains(F.body(omitted),"Last omitted marker")),
      "omitted facts cannot leave orphan citations or partial displayed text")

def nonempty_values() -> IO(Unit):
  do IO<Unit>:
    +zero : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,"0")],0,0,0,0,0,0,"zero"}))
    +spaces : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,"  ")],0,0,0,0,0,0,"spaces"}))
    F.assert(String.contains(F.body(zero),"Text: \"0\"") && String.contains(F.body(spaces),"Text: \"  \""),
      "empty-field suppression preserves numeric-looking and whitespace-only recorded text")
    +redacted : B.Preview <- F.need(B.Preview,B.render(F.anchor(),B.Collected{[simple(0,"api_key=synthetic-secret-marker")],0,0,0,0,0,0,"redacted"}))
    F.assert(String.contains(F.body(redacted),"[credential-shaped field withheld]") &&
      Bool.not(String.contains(F.body(redacted),"synthetic-secret-marker")) && String.contains(F.body(redacted),"credential-shaped fields 1"),
      "nonempty credential-shaped text still withholds the whole field and counts its transform")

def main() -> IO(Unit):
  do IO<Unit>:
    +preview : B.Preview <- prepared()
    readable(preview)
    fields_and_references(preview)
    disclosures(preview)
    commitment(preview)
    ambiguity()
    boundaries()
    nonempty_values()
