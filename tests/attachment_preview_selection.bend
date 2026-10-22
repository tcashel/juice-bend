import Base
import ../src/attachment_preview_selection.bend as S
import ../src/attachment_preview_external_packet.bend as P
import ../src/attachment_preview_external_worker.bend as W
import ../src/attachment_asset_types.bend as T
import ../src/attachment_asset_identity.bend as I
import ../src/gui_attachments.bend as G
import ../src/json.bend as J
import ./attachment_preview_external_packet.bend as F

def capture() -> J.Json:
  F.json("{\"provider\":\"claude\",\"source_id\":\"3\",\"source\":\"/synthetic/source.jsonl\",\"generation\":\"5\",\"snapshot\":\"7\",\"extent\":\"100\",\"total_records\":2,\"encoding\":\"identity\",\"byte_space\":\"logical_source_bytes\"}")
def key(+index: U32) -> G.OccurrenceKey:
  G.OccurrenceKey{Bool.pick(U32,U32.is_eq(index,1),0,1),Bool.pick(U32,U32.is_eq(index,2),1,2),
    Bool.pick(String,U32.is_eq(index,3),"/message/content/1/source","/message/content/2/source"),
    Bool.pick(U32,U32.is_eq(index,4),41,40),Bool.pick(U32,U32.is_eq(index,5),19,20),
    Bool.pick(String,U32.is_eq(index,6),"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff",F.raw_sha()),"",0,False{}}
def model(phase: U32,anchor: G.Anchor,capture: J.Json,key: G.OccurrenceKey) -> G.Model:
  G.Model{anchor,0,1,phase,[G.Page{capture,0,2,[G.Item{"Local reference","External bytes must be explicitly captured",[key]}],1,0,1}],0,[],""}
def ready(index: U32) -> G.Model:
  model(2,G.Anchor{"7",0,2},capture(),key(index))
def present(value: Maybe<&2,P.External>) -> Bool:
  match value:
    case Some{+value}: P.expected_valid(value) && P.same_receipt(P.receipt(value),F.fixture_receipt(0)) && P.same_request(P.request(value),I.Request{"7",1,2,"/message/content/2/source"})
    case None{}: False{}
def absent(value: Maybe<&2,P.External>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}
def mismatch(fuel: Nat,+index: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+left:
      do IO<Unit>:
        F.check(absent(S.selected(Some{ready(index)},Some{F.fixture_receipt(0)})),"changed selected physical identity refuses retained Open")
        mismatch(left,U32.inc(index))
def parsed(value: Result<&2,&2,String,P.External>) -> Bool:
  match value:
    case Done{+value}: P.expected_valid(value) && P.same_receipt(P.receipt(value),F.fixture_receipt(0))
    case Fail{_}: False{}
def refused(value: Result<&2,&2,String,P.External>) -> Bool:
  match value:
    case Fail{_}: True{}
    case Done{_}: False{}
def arguments() -> List<String>:
  ["7","1","2","/message/content/2/source",F.receipt_wire()]
def suite() -> IO(Unit):
  do IO<Unit>:
    F.check(present(S.selected(Some{ready(0)},Some{F.fixture_receipt(0)})),"retained receipt binds exact acknowledged capture and selected physical occurrence")
    mismatch(6n,1)
    F.check(absent(S.selected(None{},Some{F.fixture_receipt(0)})),"receipt without selected attachment view cannot preview")
    F.check(absent(S.selected(Some{ready(0)},None{})),"local metadata without retained receipt cannot preview")
    F.check(absent(S.selected(Some{model(1,G.Anchor{"7",0,2},capture(),key(0))},Some{F.fixture_receipt(0)})),"pending inventory phase cannot preview stale receipt")
    F.check(absent(S.selected(Some{model(2,G.Anchor{"8",0,2},capture(),key(0))},Some{F.fixture_receipt(0)})),"different frozen snapshot anchor cannot preview receipt")
    F.check(absent(S.selected(Some{model(2,G.Anchor{"7",0,1},capture(),key(0))},Some{F.fixture_receipt(0)})),"occurrence outside frozen physical range cannot preview")
    F.check(absent(S.selected(Some{model(2,G.Anchor{"7",0,2},F.replace(capture(),"source_id",J.JString{"4"}),key(0))},Some{F.fixture_receipt(0)})),"capture source mismatch cannot preview same-looking record")
    F.check(parsed(W.parse(arguments())),"bounded worker route parses exact canonical identity plus original receipt")
    F.check(refused(W.parse("extra" <> arguments())),"retained worker rejects extra argument before database open")
    F.check(refused(W.parse(["7","1","1","/message/content/2/source",F.receipt_wire()])),"worker rejects request ordinal differing from valid receipt")
    F.check(refused(W.parse(["7","01","2","/message/content/2/source",F.receipt_wire()])),"worker rejects noncanonical numeric request")
    F.check(refused(W.parse(["7","1","2","/message/content/2/source",F.repeat(U32.to_nat(65537)," ")])),"worker rejects oversized receipt before JSON parsing or database open")
    F.check(refused(W.parse(["7","1","2","/message/content/2/source","{}"])) ,"worker rejects missing receipt schema")
def main() -> IO(Unit): suite()
