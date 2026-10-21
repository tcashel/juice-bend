import Base
import ../src/request_origin.bend as Origin
import ../src/json.bend as Json

# Independently specified expected classifications. This is the isolated pure
# module gate; no assertion claims parser, storage, or GUI integration exists.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def kind(assessment: Origin.Assessment) -> String:
  Origin.Assessment{_,_,disposition} = assessment
  match disposition:
    case Origin.RecordedRequest{_,_}: "request"
    case Origin.RecordedNonUser{}: "nonuser"
    case Origin.ContextEnvelope{_}: "context"
    case Origin.RelayEnvelope{_}: "relay"
    case Origin.Empty{}: "empty"
    case Origin.Uncertain{_}: "uncertain"

def requested(result: Maybe<&2,String>,expected: Maybe<&2,String>) -> Bool:
  match result expected:
    case None{} None{}: True{}
    case Some{actual} Some{wanted}: String.eq(actual,wanted)
    case _ _: False{}

def present(value: Maybe<&2,String>) -> Bool:
  match value:
    case Some{_}: True{}
    case None{}: False{}

def same_bool(a: Bool,+b: Bool) -> Bool:
  Bool.pick(Bool,a,b,Bool.not(b))

def source_and_role(assessment: Origin.Assessment,source: String,role: String) -> Bool:
  Origin.Assessment{actual,recorded,_} = assessment
  String.eq(actual,source) && String.eq(recorded,role)

def case_of(provider: Origin.Provider,+role: String,meta: Origin.MetaFlag,+source: String,
  expected: String,+request: Maybe<&2,String>,label: String) -> IO(Unit):
  +assessment = Origin.classify(provider,role,meta,source)
  check(String.eq(kind(assessment),expected) && source_and_role(assessment,source,role) &&
    String.eq(Origin.original(assessment),source) && requested(Origin.request(assessment),request) &&
    same_bool(Origin.eligible(assessment),present(request)),label)

def user(provider: Origin.Provider,+source: String,expected: String,request: Maybe<&2,String>,label: String) -> IO(Unit):
  case_of(provider,"user",Origin.Unspecified{},source,expected,request,label)

def span_is(assessment: Origin.Assessment,start: U32,count: U32,blocks: U32) -> Bool:
  match assessment:
    case Origin.Assessment{_,_,Origin.RecordedRequest{Origin.Span{a,b},n}}:
      U32.is_eq(a,start) && U32.is_eq(b,count) && U32.is_eq(n,blocks)
    case _: False{}

def basic() -> IO(Unit):
  do IO<Unit>:
    user(Origin.Claude{},"Fix the tests.","request",Some{"Fix the tests."},"ordinary recorded request remains exact")
    user(Origin.Codex{}," \t\nFix café 中🙂 é.\n  ","request",Some{" \t\nFix café 中🙂 é.\n  "},"plain request preserves leading trailing and combining characters")
    user(Origin.Claude{},"","empty",None{},"empty recorded user text remains empty")
    user(Origin.Codex{}," \t\r\n\u{00a0}\u{2003}\u{3000}","empty",None{},"Unicode whitespace alone is not a request")
    user(Origin.Claude{},"Repair <system-reminder>literal</system-reminder> in this example.","request",
      Some{"Repair <system-reminder>literal</system-reminder> in this example."},"recognized markup inside prose is unchanged")
    user(Origin.Codex{},"```xml\n<environment_context>example</environment_context>\n```","request",
      Some{"```xml\n<environment_context>example</environment_context>\n```"},"fenced markup is recorded code rather than a leading envelope")
    user(Origin.Codex{},"<div>user-authored example</div>","request",Some{"<div>user-authored example</div>"},"unrecognized markup is never generically stripped")
    user(Origin.Claude{},"A\0B","request",Some{"A\0B"},"embedded NUL remains in exact decoded input")
    check(span_is(Origin.classify(Origin.Codex{},"user",Origin.Unspecified{},"🙂é中"),0,4,0),
      "ordinary span counts Unicode scalars rather than UTF8 bytes or graphemes")

def wrappers() -> IO(Unit):
  do IO<Unit>:
    user(Origin.Claude{},"<system-reminder>ctx</system-reminder> \nDo the work.\n","request",Some{" \nDo the work.\n"},
      "closed reminder exposes exact suffix including separator whitespace")
    user(Origin.Codex{},"<environment_context>ctx</environment_context>Fix it","request",Some{"Fix it"},
      "closed environment prefix exposes recorded request")
    user(Origin.Codex{},"<user_instructions>ctx</user_instructions>\tKeep tabs\t","request",Some{"\tKeep tabs\t"},
      "closed instructions prefix does not trim the suffix")
    user(Origin.Claude{},"  <SYSTEM-REMINDER>ctx</system-reminder>  Request  ","request",Some{"  Request  "},
      "ASCII case-insensitive closed tag retains exact source and suffix")
    user(Origin.Claude{},"<system-reminder></system-reminder> \n","context",None{},"closed prefix with whitespace-only suffix is context")
    user(Origin.Claude{},"<system-reminder></system-reminder>\u{85}\u{a0}\u{1680}\u{2000}\u{2001}\u{2002}\u{2003}\u{2004}\u{2005}\u{2006}\u{2007}\u{2008}\u{2009}\u{200a}\u{2028}\u{2029}\u{202f}\u{205f}\u{3000}",
      "context",None{},"all supported nonASCII Unicode whitespace tails remain context")
    user(Origin.Codex{},"<system-reminder></system-reminder><environment_context>ctx</environment_context> \tNext\n",
      "request",Some{" \tNext\n"},"two different closed prefixes advance in source order")
    check(span_is(Origin.classify(Origin.Codex{},"user",Origin.Unspecified{},
      "<system-reminder></system-reminder><environment_context>ctx</environment_context> \tNext\n"),81,7,2),
      "two-prefix span has independently counted start count and block count")
    check(span_is(Origin.classify(Origin.Claude{},"user",Origin.Unspecified{},
      "<system-reminder>😀é</system-reminder> \nFix é中😀é.\n"),38,13,1),
      "Unicode prefix and suffix offsets count exact decoded scalars")
    user(Origin.Claude{},"<system-reminder>😀é</system-reminder> \nFix é中😀é.\n","request",Some{" \nFix é中😀é.\n"},
      "Unicode span extraction preserves combining mark and emoji content")

def uncertain_cases(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        user(Origin.Claude{},value,"uncertain",None{},"malformed or unsupported wrapper retains source without request")
        uncertain_cases(rest)

def malformed() -> IO(Unit):
  do IO<Unit>:
    uncertain_cases(["<system-reminder>never closed. Fix it", "<system-reminder", "<system-reminder/>",
      "<system-reminder mode=\"x\">ctx</system-reminder>Do it", "<system-reminder >ctx</system-reminder>Do it",
      "<system-reminder>ctx</environment_context>Do it", "<system-reminder>ctx</system-reminder >Do it",
      "<system-reminder>outer<system-reminder>inner</system-reminder></system-reminder>Do it",
      "<system-reminder>ctx<other>nested</other></system-reminder>Do it",
      "<system-reminder>ctx</system-reminder></user_instructions>Do it", "</system-reminder>Do it",
      "<teammate-message>never closed", "<task-notification id=\"x\">done</task-notification>",
      "<skills_instructions>open", "<system-reminder>ctx</system-reminder><skills_instructions mode=\"x\">context</skills_instructions>"])
    user(Origin.Claude{},"<system-reminder>ctx</system-reminder><skills_instructions>context</skills_instructions>",
      "context",None{},"unsupported request-prefix continuation remains context rather than intent")
    user(Origin.Claude{},"<system-reminderish>ordinary</system-reminderish>","request",
      Some{"<system-reminderish>ordinary</system-reminderish>"},"request-prefix name lookalike is untouched")
    user(Origin.Codex{},"<teammate-messages>ordinary</teammate-messages>","request",
      Some{"<teammate-messages>ordinary</teammate-messages>"},"relay tag plural lookalike is untouched")

def limits() -> IO(Unit):
  +wrapper = {"<system-reminder></system-reminder>" : String}
  do IO<Unit>:
    user(Origin.Claude{},String.repeat(wrapper,12n) ++ " \nRequest","request",Some{" \nRequest"},"twelve closed prefixes allow exact remaining request")
    check(span_is(Origin.classify(Origin.Claude{},"user",Origin.Unspecified{},String.repeat(wrapper,12n) ++ "X"),420,1,12),
      "twelve-prefix span does not overflow or lose a block")
    user(Origin.Codex{},String.repeat(wrapper,13n) ++ "Request","uncertain",None{},"thirteenth supported prefix exceeds bounded classifier")
    user(Origin.Codex{},String.repeat(wrapper,12n),"context",None{},"twelve prefixes without request remain context")

def relay_cases() -> IO(Unit):
  do IO<Unit>:
    user(Origin.Claude{},"Another Claude session sent a message: hello","relay",None{},"explicit Claude cross-session marker remains nonrequest")
    user(Origin.Claude{}," THE COORDINATOR SENT A MESSAGE: done","relay",None{},"explicit coordinator relay permits leading whitespace and ASCII case")
    user(Origin.Claude{},"This session is being continued from a previous conversation. Summary","relay",None{},"explicit continuation summary is a relay record")
    user(Origin.Claude{},"[system notification - not user input]\nWake","relay",None{},"explicit system notification is a relay record")
    user(Origin.Claude{},"[cross-session idle notice] waiting","relay",None{},"explicit cross-session idle marker is a relay record")
    user(Origin.Claude{},"<teammate-message>done</teammate-message>","relay",None{},"closed teammate relay is visible and ineligible")
    user(Origin.Codex{},"<task-notification>done</task-notification>","relay",None{},"closed task notification is visible and ineligible")
    user(Origin.Claude{},"<relay>done</relay>","relay",None{},"closed attribute-free Claude relay is supported")
    user(Origin.Codex{},"[request interrupted by user for tool use]","context",None{},"explicit Codex interruption is context")
    user(Origin.Codex{},"<codex_internal_context>goal</codex_internal_context>","context",None{},"closed Codex internal context is not a request")
    user(Origin.Codex{},"<codex_internal_context source=\"agent_notification\">done</codex_internal_context>",
      "uncertain",None{},"attribute-bearing Codex relay is explicitly outside the supported subset")
    user(Origin.Claude{},"# AGENTS.md instructions for /synthetic/project","context",None{},"explicit instructions heading is context")
    user(Origin.Claude{},"Another Claude session sent a messageboard note","request",Some{"Another Claude session sent a messageboard note"},
      "relay prose lookalike cannot match by partial word")
    user(Origin.Claude{},"This session is being continued from a previous conversationboard","request",
      Some{"This session is being continued from a previous conversationboard"},"continuation marker requires a token boundary")
    user(Origin.Codex{},"Please quote Another Claude session sent a message: literally","request",
      Some{"Please quote Another Claude session sent a message: literally"},"relay mention inside prose stays literal")
    user(Origin.Codex{},"Another Claude session sent a message: literal","request",Some{"Another Claude session sent a message: literal"},
      "Claude-only text marker does not apply to Codex")
    user(Origin.Claude{},"[request interrupted by user for tool use]","request",Some{"[request interrupted by user for tool use]"},
      "Codex-only marker does not apply to Claude")
    user(Origin.Claude{},"<codex_internal_context>example</codex_internal_context>","request",
      Some{"<codex_internal_context>example</codex_internal_context>"},"Codex-only tag is not stripped from Claude")
    user(Origin.Claude{},"<system-reminder>ctx</system-reminder>Another Claude session sent a message: done",
      "relay",None{},"relay after supported context cannot become a recorded request")

def meta_is(value: Origin.MetaFlag,expected: String) -> Bool:
  match value:
    case Origin.Unspecified{}: String.eq(expected,"missing")
    case Origin.Explicit{True{}}: String.eq(expected,"true")
    case Origin.Explicit{False{}}: String.eq(expected,"false")
    case Origin.Malformed{}: String.eq(expected,"malformed")

def invalid_meta(values: List<&2,Json.Json>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        check(meta_is(Origin.metadata(Json.JObject{[Json.JField{"isMeta",value}]}),"malformed"),"metadata rejects nonboolean without coercion")
        invalid_meta(rest)

def metadata_cases() -> IO(Unit):
  do IO<Unit>:
    check(meta_is(Origin.metadata(Json.JObject{[]}),"missing"),"absent isMeta remains unspecified")
    check(meta_is(Origin.metadata(Json.JObject{[Json.JField{"isMeta",Json.JBool{True{}}}]}),"true"),"typed true remains explicit")
    check(meta_is(Origin.metadata(Json.JObject{[Json.JField{"isMeta",Json.JBool{False{}}}]}),"false"),"typed false remains explicit")
    invalid_meta([Json.JNull{},Json.JNumber{"1"},Json.JNumber{"0"},Json.JString{"true"},Json.JString{"false"},Json.JArray{[]},Json.JObject{[]}])
    check(meta_is(Origin.metadata(Json.JObject{[Json.JField{"isMeta",Json.JBool{False{}}},Json.JField{"isMeta",Json.JBool{False{}}}]}),"malformed"),
      "duplicate equal typed metadata is malformed rather than last-wins")
    check(meta_is(Origin.metadata(Json.JObject{[Json.JField{"isMeta",Json.JNull{}},Json.JField{"isMeta",Json.JBool{True{}}},Json.JField{"isMeta",Json.JBool{False{}}}]}),"malformed"),
      "malformed mixed duplicate metadata cannot become a later boolean")
    check(meta_is(Origin.metadata(Json.JArray{[]}),"malformed"),"nonobject metadata input is malformed")
    check(meta_is(Origin.metadata(Json.JObject{[Json.JField{"nested",Json.JObject{[Json.JField{"isMeta",Json.JBool{True{}}}]}}]}),"missing"),
      "nested isMeta does not masquerade as the record envelope")
    case_of(Origin.Claude{},"user",Origin.Explicit{True{}},"<system-reminder>ctx</system-reminder> Request","context",None{},
      "explicit Claude meta forbids request after a valid context wrapper")
    case_of(Origin.Claude{},"user",Origin.Explicit{True{}},"<system-reminder>unclosed Request","uncertain",None{},
      "explicit meta does not hide malformed wrapper uncertainty")
    case_of(Origin.Claude{},"user",Origin.Explicit{True{}},"<relay>done</relay>","relay",None{},
      "explicit Claude meta preserves the recorded relay distinction")
    case_of(Origin.Claude{},"user",Origin.Explicit{False{}},"Request","request",Some{"Request"},"explicit Claude false permits recorded request")
    case_of(Origin.Codex{},"user",Origin.Explicit{True{}},"Request","request",Some{"Request"},"Codex typed flag has no Claude semantics")
    case_of(Origin.Codex{},"user",Origin.Malformed{},"Request","uncertain",None{},"malformed supplied metadata never becomes intent")
    case_of(Origin.Claude{},"user",Origin.Malformed{},"Request","uncertain",None{},"malformed Claude metadata never becomes intent")

def roles(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        case_of(Origin.Codex{},value,Origin.Unspecified{},"Please change code","nonuser",None{},"known nonuser recorded role remains ineligible")
        roles(rest)

def forged(+source: String,span: Origin.Span,label: String) -> IO(Unit):
  +assessment = {Origin.Assessment{source,"user",Origin.RecordedRequest{span,0}} : Origin.Assessment}
  check(Bool.not(Origin.eligible(assessment)) && requested(Origin.request(assessment),None{}) &&
    String.eq(Origin.original(assessment),source),label)

def span_guards() -> IO(Unit):
  do IO<Unit>:
    check(requested(Origin.extract("A🙂é中Z",Origin.Span{1,4}),Some{"🙂é中"}),"public extraction uses scalar bounds with exact suffix text")
    check(requested(Origin.extract("ABC",Origin.Span{3,0}),Some{""}),"empty span exactly at EOF is a valid extraction")
    check(requested(Origin.extract("ABC",Origin.Span{4,0}),None{}),"empty span beyond EOF is rejected")
    forged("ABC",Origin.Span{4294967295,1},"forged maximum start cannot overflow into source")
    forged("ABC",Origin.Span{1,4294967295},"forged maximum count cannot overflow into source")
    forged("ABC",Origin.Span{4294967294,4294967295},"forged start plus count never wraps")
    forged("ABC",Origin.Span{0,4},"forged span beyond source is ineligible")
    forged("ABC",Origin.Span{0,0},"forged empty request span is ineligible")
    forged(" \t\u{2003}",Origin.Span{0,3},"forged whitespace-only request span is ineligible")
    check(Bool.not(Origin.eligible(Origin.Assessment{"Request","assistant",Origin.RecordedRequest{Origin.Span{0,7},0}})),
      "forged nonuser assessment cannot gain request eligibility")

def large_ascii() -> IO(Unit):
  +ascii = String.repeat("x",1048576n)
  user(Origin.Codex{},ascii,"request",Some{ascii},"exact oneMiB ASCII text remains eligible and wholly retained")

def large_emoji() -> IO(Unit):
  +emoji = String.repeat("🙂",262144n)
  user(Origin.Claude{},emoji,"request",Some{emoji},"UTF8 budget counts four bytes per emoji at exact cap")

def large() -> IO(Unit):
  do IO<Unit>:
    large_ascii()
    user(Origin.Codex{},String.repeat("x",1048577n),"uncertain",None{},"one byte above budget remains retained but uninspected")
    large_emoji()
    user(Origin.Claude{},String.repeat("🙂",262145n),"uncertain",None{},"UTF8 byte overflow is detected below the scalar-count cap")
    forged(String.repeat("x",1048577n),Origin.Span{0,1},"forged short span cannot bypass source inspection budget")
    user(Origin.Claude{},SCon{Chr{55296},""},"uncertain",None{},"invalid surrogate scalar is retained but never treated as request")
    user(Origin.Codex{},SCon{Chr{1114112},""},"uncertain",None{},"out-of-range Unicode scalar is retained with uncertainty")

def main() -> IO(Unit):
  do IO<Unit>:
    basic()
    wrappers()
    malformed()
    limits()
    relay_cases()
    metadata_cases()
    roles(["assistant","system","developer","tool","tool_result","toolResult","thinking","metadata","attachment","unsupported"])
    case_of(Origin.Codex{},"future_role",Origin.Unspecified{},"Request","uncertain",None{},"unknown role is explicitly uncertain")
    case_of(Origin.Claude{},"",Origin.Unspecified{},"Request","uncertain",None{},"missing role is explicitly uncertain")
    span_guards()
    large()
