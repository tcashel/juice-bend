import Base
import ./attachment_preview_packet.bend as Packet
import ./attachment_asset_identity.bend as I
import ./attachment_asset_types.bend as T
import ./attachment_capture_output.bend as Output
import ./attachment_capture_ack.bend as Ack
import ./attachment_decode.bend as Decode
import ./attachment_refs.bend as Ref
import ./gui_settings.bend as Shape
import ./json.bend as J

# Pure retained-asset transport. The receipt is the original observation, not
# permission to read a source or an assertion about current root policy.
# Ack is the shared strict receipt codec; its independent validation gate must
# pass before this integration is accepted. No alternate receipt codec lives here.
type External is Data:
  External{request: I.Request,receipt: T.Receipt}

def request(value: External) -> I.Request:
  External{request,_} = value
  request

def receipt(value: External) -> T.Receipt:
  External{_,receipt} = value
  receipt

def count(value: External) -> U32:
  External{_,T.Receipt{_,_,_,count,_,_,_}} = value
  count

def digest(value: T.Receipt) -> String:
  T.Receipt{_,_,_,_,_,digest,_} = value
  digest

def seal(value: T.Receipt) -> String:
  T.Receipt{_,_,_,_,_,_,seal} = value
  seal

def occurrence(value: T.Receipt) -> I.Resolved:
  T.Receipt{occurrence,_,_,_,_,_,_} = value
  occurrence

def same_request(a: I.Request,b: I.Request) -> Bool:
  I.Request{asnapshot,arecord,areference,apath} = a
  I.Request{bsnapshot,brecord,breference,bpath} = b
  String.eq(asnapshot,bsnapshot) && U32.is_eq(arecord,brecord) &&
    U32.is_eq(areference,breference) && String.eq(apath,bpath)

def expected_valid(value: External) -> Bool:
  External{+request,+receipt} = value
  I.request_valid(request) && T.receipt_valid(receipt) && same_request(request,I.request(occurrence(receipt)))

def same_receipt(+a: T.Receipt,+b: T.Receipt) -> Bool:
  # T.same includes every full header and occurrence field, the historical root
  # evidence, observation time, chunk layout, byte digest and profile constants.
  T.same(a,b) && String.eq(seal(a),seal(b))

def guard(valid: Bool,message: String) -> Result<&2,&2,String,Unit>:
  Packet.guard(valid,message)

# Expected.count is admitted through T.receipt_valid before this multiplication.
def wire_bound(value: External,text: String) -> Bool:
  Ref.bounded(text,U32.add(Packet.header_limit(),U32.mul(count(value),2)))

def shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["kind","version","receipt","byte_count","byte_sha256","hex"]) &&
    Shape.text_is(J.field(value,"kind"),"attachment_preview_external") && Shape.number_is(J.field(value,"version"),"1")

def matches(+expected: External,+actual: T.Receipt) -> Bool:
  I.same(occurrence(receipt(expected)),occurrence(actual)) && same_receipt(receipt(expected),actual)

def verified(+expected: External,+packet: J.Json) -> Result<&2,&2,String,Decode.Bytes>:
  do Result<&2,&2,String,Decode.Bytes>:
    _ : Unit <- guard(shape(packet),"external_preview_packet_shape")
    actual : T.Receipt <- Ack.receipt(J.field(packet,"receipt"))
    _ : Unit <- guard(matches(expected,actual),"external_preview_receipt_mismatch")
    _ : Unit <- guard(Shape.number_is(J.field(packet,"byte_count"),U32.show(count(expected))) &&
      Shape.text_is(J.field(packet,"byte_sha256"),digest(receipt(expected))),"external_preview_payload_mismatch")
    Packet.verified_payload(packet,count(expected))

def verify(+expected: External,+text: String) -> Result<&2,&2,String,Decode.Bytes>:
  do Result<&2,&2,String,Decode.Bytes>:
    _ : Unit <- guard(expected_valid(expected),"external_preview_invalid_expected")
    _ : Unit <- guard(wire_bound(expected,text),"external_preview_packet_limit")
    packet : J.Json <- Packet.parse(text)
    verified(expected,packet)

def owned_receipt(value: T.Owned) -> T.Receipt:
  T.Owned{receipt,_} = value
  receipt

def owned_bytes(value: T.Owned) -> List<&2,U32>:
  T.Owned{_,chunks} = value
  List.concat(&2,U32,T.chunk_bytes(chunks))

# The serializer and strict decoder share responsibility for receipt metadata.
# Round-trip admission here prevents emitting a receipt outside Ack's tighter
# presentation profile; no paths or authority are reconstructed or normalized.
def encoded_receipt(+value: T.Receipt) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    +text : String = Output.receipt(value)
    _ : Unit <- guard(Ref.bounded(text,Packet.header_limit()),"external_preview_metadata_limit")
    parsed : J.Json <- J.parse(text)
    actual : T.Receipt <- Ack.receipt(parsed)
    _ : Unit <- guard(same_receipt(value,actual),"external_preview_receipt_mismatch")
    Done{text}

def encoded(header: String,count: U32,digest: String,bytes: List<&2,U32>) -> String:
  "{\"kind\":\"attachment_preview_external\",\"version\":1,\"receipt\":" ++ header ++
    ",\"byte_count\":" ++ U32.show(count) ++ ",\"byte_sha256\":" ++ J.quote(digest) ++
    ",\"hex\":\"" ++ Packet.hex_encode(bytes,"") ++ "\"}"

def encode(+expected: External,+owned: T.Owned) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    _ : Unit <- guard(expected_valid(expected),"external_preview_invalid_expected")
    _ : Unit <- guard(T.receipt_valid(owned_receipt(owned)),"external_preview_invalid_receipt")
    _ : Unit <- guard(matches(expected,owned_receipt(owned)),"external_preview_receipt_mismatch")
    header : String <- encoded_receipt(owned_receipt(owned))
    _ : Unit <- guard(T.owned_valid(owned),"external_preview_invalid_owned_bytes")
    +text : String = encoded(header,count(expected),digest(receipt(expected)),owned_bytes(owned))
    _ : Unit <- guard(wire_bound(expected,text),"external_preview_packet_limit")
    Done{text}
