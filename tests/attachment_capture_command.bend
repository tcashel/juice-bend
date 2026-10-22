import Base
import ../src/attachment_capture_command.bend as C
import ../src/attachment_capture_output.bend as O
import ../src/attachment_capture_roots.bend as R
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_asset_types.bend as T
import ../src/attachment_inventory.bend as E
import ../src/json.bend as J
import ./attachment_asset_types.bend as F

def rejected(value: C.result()) -> Bool:
  match value:
    case Fail{E.Failure{code,_}}: String.eq(code,"attachment_capture_usage")
    case _: False{}
def capture(value: C.result()) -> Bool:
  match value:
    case Done{C.Capture{I.Request{snapshot,record,reference,path},root,revision}}:
      String.eq(snapshot,"9223372036854775807") && U32.is_eq(record,4294967295) && U32.is_eq(reference,63) &&
      String.eq(path,"/message/content/0/source/path") && String.eq(root,"9007199254740993") && String.eq(revision,"9223372036854775807")
    case _: False{}
def roots(value: C.result()) -> Bool:
  match value:
    case Done{C.Roots{after,count}}: String.eq(after,"0") && U32.is_eq(count,40)
    case _: False{}
def need(value: O.result()) -> IO(String):
  match value:
    case Done{text}: IO.pure(String,text)
    case Fail{O.Failure{_,E.Failure{code,_},_}}: IO.die(String,1,code)
def parsed(value: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match value:
    case Done{value}: IO.pure(J.Json,value)
    case Fail{error}: IO.die(J.Json,1,error)
def count(value: J.Json,expected: Nat) -> Bool:
  match value:
    case J.JObject{fields}: Nat.is_eq(List.length(&2,J.Field,fields),expected)
    case _: False{}
def ack(+value: J.Json,+expected: T.Receipt) -> Bool:
  T.Receipt{_,_,_,_,_,_,seal} = expected
  +receipt = J.field(value,"receipt")
  +occurrence = J.field(receipt,"occurrence")
  +capture = J.field(occurrence,"capture")
  +root = J.field(receipt,"root")
  count(value,4n) && count(receipt,9n) && count(occurrence,10n) && count(capture,12n) && count(root,4n) &&
    String.eq(J.get(value,"kind"),"attachment_asset") && String.eq(J.get(value,"state"),"already_captured") &&
    String.eq(J.get(capture,"byte_space"),"logical_source_bytes") && String.eq(J.get(occurrence,"byte_space"),"logical_source_bytes") &&
    String.eq(J.get(receipt,"observed_at_ms"),"9007199254740993") && String.eq(J.get(receipt,"commitment"),seal) &&
    String.eq(J.get(capture,"snapshot"),"1") && String.eq(J.get(capture,"source_id"),"2") && String.eq(J.get(capture,"generation"),"3") &&
    String.eq(J.get(capture,"checkpoint"),"100") && String.eq(J.get(capture,"checkpoint_ordinal"),"1") && String.eq(J.get(capture,"accepted"),"true") &&
    String.eq(J.get(occurrence,"raw_sha256"),F.raw_sha()) && String.eq(J.get(occurrence,"record"),"1") &&
    String.eq(J.get(J.field(occurrence,"local_reference"),"value"),"/synthetic/photo 中文%20.png") &&
    String.eq(J.get(root,"id"),"7") && String.eq(J.get(root,"revision"),"9") && String.eq(J.get(root,"enabled"),"true") &&
    String.eq(J.get(receipt,"count"),"4") && String.eq(J.get(receipt,"chunks"),"1") && String.eq(J.get(receipt,"sha256"),F.binary_sha())
def failed(value: O.result(),expected: String) -> Bool:
  match value:
    case Fail{O.Failure{_,E.Failure{code,_},_}}: String.eq(code,expected)
    case _: False{}
def oversized(left: Nat,+id: U32) -> List<&2,T.RootEvidence>:
  match left:
    case 0n: []
    case 1n+rest: T.RootEvidence{U32.show(id),"/" ++ String.repeat("\"",4095n),"1",True{}} <> oversized(rest,U32.inc(id))
def suite() -> IO(Unit):
  do IO<Unit>:
    F.assert(capture(C.parse("capture-attachment",["9223372036854775807","4294967295","63","/message/content/0/source/path","9007199254740993","9223372036854775807"])),"capture parser preserves exact wide snapshot root revision and physical occurrence bounds")
    F.assert(roots(C.parse("attachment-roots",["0","40"])),"root list accepts explicit empty-start cursor and exact40 limit")
    F.assert(rejected(C.parse("capture-attachment",["1","0","0","/x","1"])) && rejected(C.parse("capture-attachment",["1","0","0","/x","1","1","/injected"])),"capture requires exact selected root revision and has no supplied target path slot")
    F.assert(rejected(C.parse("capture-attachment",["01","0","0","/x","1","1"])) && rejected(C.parse("capture-attachment",["1","4294967296","0","/x","1","1"])) && rejected(C.parse("capture-attachment",["1","0","64","/x","1","1"])),"noncanonical identity record overflow and unseen reference range are rejected")
    F.assert(rejected(C.parse("capture-attachment",["1","0","0","/x","1","9223372036854775808"])) && rejected(C.parse("capture-attachment",["1","0","0","/x","0","1"])),"root IDs and revisions remain canonical positive signed64 text")
    F.assert(rejected(C.parse("attachment-roots",["0","0"])) && rejected(C.parse("attachment-roots",["0","41"])) && rejected(C.parse("attachment-roots",["00","1"])),"root pagination rejects zero overlarge count and ambiguous cursor")
    F.assert(rejected(C.parse("attachment-root-add",["relative"])) && rejected(C.parse("attachment-root-add",["file:///tmp/root"])) && rejected(C.parse("attachment-root-add",["/tmp/../root"])),"root addition requires explicit safe absolute filesystem path")
    F.assert(rejected(C.parse("export-captured-attachment",["1","0","0","/x","relative.bin"])) && rejected(C.parse("export-captured-attachment",["1","0","0","/x","/tmp/" ++ String.repeat("a",245n)])),"retained export destination is explicit absolute and reserves the sink leaf budget")
    F.assert(rejected(C.parse("captured-attachment",["1","0","0","/" ++ String.repeat("x",2048n)])) && rejected(C.parse("captured-attachment",["1","0","0","/x\0y"])),"structural identity path is bounded scalar nonNUL metadata")
    F.assert(rejected(C.parse("private-unknown-command",[])) && rejected(C.parse("attachment-root-enable",["1","/substitute"])),"unknown or extra arguments never select executable or replacement root path")
    +expected : T.Receipt = T.receipt(T.Admission{F.identity(99),F.root(99),"9007199254740993",F.binary()})
    +encoded : String <- need(O.asset("already_captured",expected,None{},O.NoMutation{}))
    json : J.Json <- parsed(J.parse(encoded))
    F.assert(ack(json,expected),"asset acknowledgement preserves full immutable receipt with exact wide time and full capture checkpoints")
    F.assert(Bool.not(String.contains(encoded,"\"bytes\":")) && Bool.not(String.contains(encoded,"AAH+/w==")) && Bool.not(String.contains(encoded,"\"payload\":")),"asset metadata never contains binary body or base64 representation")
    F.assert(failed(O.asset("captured",F.bad_seal(expected),None{},O.CaptureUncertain{}),"attachment_capture_ack"),"corrupt receipt cannot produce a success acknowledgement")
    F.assert(failed(O.page(R.Page{"0",40,oversized(40n,1),None{}}),"attachment_output_limit"),"oversized root JSON fails completely without silently omitting roots")
    +error : String = O.error(O.Failure{"publish",E.Failure{"attachment_root_revoked","static"},O.CaptureUncertain{}})
    failure_json : J.Json <- parsed(J.parse(error))
    F.assert(String.eq(J.get(failure_json,"mutation"),"capture_uncertain"),"typed JSON failure preserves publication uncertainty")
    F.assert(Bool.not(String.contains(O.error(O.Failure{"request",E.Failure{"bad",String.repeat("secret",500n)},O.NoMutation{}}),String.repeat("secret",5n))),"overlarge diagnostics are replaced without echoing caller content")

def main() -> IO(Unit): suite()
