import Base
import ../src/attachment_capture.bend as C
import ../src/attachment_asset_types.bend as T
import ../src/attachment_inventory.bend as I
import ./attachment_asset_types.bend as F

def accepted(value: C.result(),expected: T.Receipt) -> Bool:
  match value:
    case Done{C.Captured{receipt}}: T.same(receipt,expected)
    case _: False{}

def rejected(value: C.result(),expected: String) -> Bool:
  match value:
    case Fail{C.Failure{"publish",I.Failure{code,_},C.PublicationUncertain{}}}: String.eq(code,expected)
    case _: False{}

def receipt(time: String) -> T.Receipt:
  T.receipt(T.Admission{F.identity(99),F.root(99),time,F.binary()})

def suite() -> IO(Unit):
  do IO<Unit>:
    +expected : T.Receipt = receipt("1700000000000")
    F.assert(accepted(C.publication(Done{T.Published{expected,False{}}},expected),expected),"publication acknowledgement accepts the whole exact valid receipt")
    F.assert(rejected(C.publication(Done{T.Published{receipt("1700000000001"),True{}}},expected),"attachment_capture_ack"),"a valid retry receipt with another observation time is uncertainty rather than relabeled success")
    F.assert(rejected(C.publication(Done{T.Published{F.bad_seal(expected),False{}}},expected),"attachment_capture_ack"),"a corrupt receipt acknowledgement cannot claim success")
    F.assert(rejected(C.publication(Done{T.Initialized{}},expected),"attachment_capture_ack"),"unexpected storage outcome remains publication uncertainty")
    F.assert(rejected(C.publication(Fail{I.Failure{"attachment_root_revoked","synthetic"}},expected),"attachment_root_revoked"),"publication refusal keeps its exact cause and conservative uncertainty")

def main() -> IO(Unit): suite()
