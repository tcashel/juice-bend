import Base
import ./json.bend as J
import ./gui_attachments.bend as Gui
import ./gui_settings.bend as Shape
import ./attachment_inline.bend as Inline
import ./attachment_decode.bend as Decode
import ./attachment_inventory_output.bend as Output
import ./attachment_refs.bend as Ref
import ./archive_meta.bend as Meta
import ./domain.bend as Domain

# A pure, bounded transport boundary for bytes resolved from owned evidence.
# It grants no source/file/network authority and performs no image decoding.
# Expected is retained by the caller, never reconstructed from the packet.
type Expected is Data:
  Expected{capture: J.Json,snapshot: String,key: Gui.OccurrenceKey}

def max_bytes() -> U32: 1048576
def max_output() -> U32: 2162688
def header_limit() -> U32: 65536

def request(value: Expected) -> Inline.Request:
  Expected{_,snapshot,Gui.OccurrenceKey{record,reference,path,_,_,_,_,_,_}} = value
  Inline.Request{snapshot,record,reference,path}

def count(value: Expected) -> U32:
  Expected{_,_,Gui.OccurrenceKey{_,_,_,_,_,_,_,count,_}} = value
  count

def key_valid(value: Gui.OccurrenceKey,+capture: J.Json) -> Bool:
  Gui.OccurrenceKey{+record,reference,+path,+offset,+length,digest,media,bytes,exportable} = value
  +extent : U32 = Gui.number(J.JNumber{J.get(capture,"extent")})
  exportable && U32.is_lt(record,Gui.number(J.field(capture,"total_records"))) && U32.is_lt(reference,64) &&
    Ref.bounded(path,2048) && String.starts_with(path,"/") && Ref.bounded(media,127) &&
    U32.is_gt(length,0) && U32.is_le(length,262144) && U32.is_le(offset,extent) &&
    U32.is_le(length,U32.sub(extent,offset)) && (U32.is_ne(record,0) || U32.is_eq(offset,0)) &&
    Gui.commitment(digest) && U32.is_le(bytes,max_bytes())

def expected_valid(value: Expected) -> Bool:
  Expected{+capture,snapshot,key} = value
  Gui.capture_valid(capture,snapshot) && key_valid(key,capture)

def guard(ok: Bool,message: String) -> Result<&2,&2,String,Unit>:
  Gui.guard(ok,message)

# The wire budget is UTF8 bytes, not Unicode character count. Reserve only the
# selected payload's two hex characters per byte plus a bounded JSON header.
# This also rejects huge whitespace or escaped-header expansion for tiny data.
def wire_bound(value: Expected,text: String) -> Bool:
  Ref.bounded(text,U32.add(header_limit(),U32.mul(count(value),2)))

# The common parser's default 1Mi-character fuel cannot fit a 1Mi-byte hex
# payload. Reuse its exact lexer/tree with this transport's admitted budget.
def parse(text: String) -> Result<&2,&2,String,J.Json>:
  do Result<&2,&2,String,J.Json>:
    tokens : List<&2,J.Token> <- J.lex(text,J.JLBase{[]},U32.to_nat(max_output()))
    J.tree(tokens,[J.JFRoot{}])

def fields(+value: J.Json) -> Bool:
  Shape.exact_object(value,["kind","version","capture","record","ref","path","offset","length","raw_sha256","media","byte_count","byte_sha256","hex"]) &&
    Shape.text_is(J.field(value,"kind"),"attachment_preview") && Shape.number_is(J.field(value,"version"),"1")

def capture_matches(value: Expected,+packet: J.Json) -> Bool:
  Expected{capture,snapshot,_} = value
  Gui.capture_valid(J.field(packet,"capture"),snapshot) && Gui.same_capture(capture,J.field(packet,"capture"))

def key_matches(value: Gui.OccurrenceKey,+packet: J.Json) -> Bool:
  Gui.OccurrenceKey{record,reference,path,offset,length,digest,media,bytes,_} = value
  Shape.number_is(J.field(packet,"record"),U32.show(record)) && Shape.number_is(J.field(packet,"ref"),U32.show(reference)) &&
    Shape.text_is(J.field(packet,"path"),path) && Shape.number_is(J.field(packet,"offset"),U32.show(offset)) &&
    Shape.number_is(J.field(packet,"length"),U32.show(length)) && Shape.text_is(J.field(packet,"raw_sha256"),digest) &&
    Shape.text_is(J.field(packet,"media"),media) && Shape.number_is(J.field(packet,"byte_count"),U32.show(bytes))

def occurrence_matches(value: Expected,packet: J.Json) -> Bool:
  Expected{_,_,key} = value
  key_matches(key,packet)

def lower_hex(+cp: U32) -> Bool:
  (U32.is_ge(cp,48) && U32.is_le(cp,57)) || (U32.is_ge(cp,97) && U32.is_le(cp,102))

def nibble(+cp: U32) -> U32:
  Bool.pick(U32,U32.is_le(cp,57),U32.sub(cp,48),U32.add(U32.sub(cp,97),10))

# Structural fuel is the already admitted byte count. A short/odd input or any
# remaining suffix fails; no truncation, whitespace, signs or uppercase hex.
def hex_octets(fuel: Nat,text: String,acc: List<&2,U32>) -> Result<&2,&2,String,List<&2,U32>>:
  match fuel text:
    case 0n SNil{}: Done{List.reverse(&2,U32,acc)}
    case 1n+left SCon{Chr{+hi},SCon{Chr{+lo},rest}}:
      do Result<&2,&2,String,List<&2,U32>>:
        _ : Unit <- guard(lower_hex(hi) && lower_hex(lo),"preview_invalid_hex")
        hex_octets(left,rest,U32.add(U32.mul(nibble(hi),16),nibble(lo)) <> acc)
    case _ _: Fail{"preview_hex_length_mismatch"}

def payload_text(value: J.Json,count: U32) -> Result<&2,&2,String,List<&2,U32>>:
  match value:
    case J.JString{text}: hex_octets(U32.to_nat(count),text,[])
    case _: Fail{"preview_hex_not_string"}

def verified_payload(+packet: J.Json,+count: U32) -> Result<&2,&2,String,Decode.Bytes>:
  do Result<&2,&2,String,Decode.Bytes>:
    _ : Unit <- guard(Gui.bounded(J.field(packet,"byte_sha256"),64) && Gui.commitment(J.get(packet,"byte_sha256")),"preview_invalid_byte_digest")
    +bytes : List<&2,U32> <- payload_text(J.field(packet,"hex"),count)
    _ : Unit <- guard(String.eq(Domain.digest(bytes),J.get(packet,"byte_sha256")),"preview_byte_digest_mismatch")
    Done{Decode.Bytes{bytes,count,J.get(packet,"byte_sha256")}}

def verify_value(+expected: Expected,+packet: J.Json) -> Result<&2,&2,String,Decode.Bytes>:
  do Result<&2,&2,String,Decode.Bytes>:
    _ : Unit <- guard(fields(packet),"preview_packet_shape")
    _ : Unit <- guard(capture_matches(expected,packet),"preview_capture_mismatch")
    _ : Unit <- guard(occurrence_matches(expected,packet),"preview_occurrence_mismatch")
    verified_payload(packet,count(expected))

def verify(+expected: Expected,+text: String) -> Result<&2,&2,String,Decode.Bytes>:
  do Result<&2,&2,String,Decode.Bytes>:
    _ : Unit <- guard(expected_valid(expected),"preview_invalid_expected")
    _ : Unit <- guard(wire_bound(expected,text),"preview_packet_limit")
    packet : J.Json <- parse(text)
    verify_value(expected,packet)

# Producer checks are separate from Decode.valid's fixed base64 profile, so
# future owned-byte transports can retain the 1MiB packet limit without changing
# that decoder. This inline producer still admits at most 786432 decoded bytes.
def octets_exact(fuel: Nat,bytes: List<&2,U32>) -> Bool:
  match fuel bytes:
    case 0n Nil{}: True{}
    case 1n+left byte <> rest: U32.is_le(byte,255) && octets_exact(left,rest)
    case _ _: False{}

def data_valid(value: Decode.Bytes) -> Result<&2,&2,String,Unit>:
  Decode.Bytes{+bytes,+count,+digest} = value
  do Result<&2,&2,String,Unit>:
    _ : Unit <- guard(U32.is_le(count,786432),"preview_inline_byte_limit")
    _ : Unit <- guard(octets_exact(U32.to_nat(count),bytes),"preview_inline_octets")
    _ : Unit <- guard(Gui.commitment(digest),"preview_invalid_byte_digest")
    guard(String.eq(Domain.digest(bytes),digest),"preview_byte_digest_mismatch")

def hex_encode(bytes: List<&2,U32>,acc: String) -> String:
  match bytes:
    case []: String.reverse(acc)
    case +byte <> rest:
      hex_encode(rest,SCon{Domain.hex_digit(U32.and(byte,15)),SCon{Domain.hex_digit(U32.div(byte,16)),acc}})

def header(value: Inline.Resolved) -> Meta.Header:
  Inline.Resolved{header,_,_,_,_,_,_,_,_} = value
  header

def header_snapshot(value: Meta.Header) -> String:
  Meta.Header{snapshot,_,_,_,_,_,_,_,_,_,_} = value
  snapshot

def header_published(value: Meta.Header) -> Bool:
  Meta.Header{_,_,_,_,_,_,_,_,_,accepted,_} = value
  accepted

def resolved_data(value: Inline.Resolved) -> Decode.Bytes:
  Inline.Resolved{_,_,_,_,_,_,_,_,data} = value
  data

def resolved_key(value: Inline.Resolved) -> Gui.OccurrenceKey:
  Inline.Resolved{_,record,offset,length,digest,reference,path,media,Decode.Bytes{_,count,_}} = value
  Gui.OccurrenceKey{record,reference,path,offset,length,digest,media,count,True{}}

def resolved_expected(+value: Inline.Resolved) -> Result<&2,&2,String,Expected>:
  do Result<&2,&2,String,Expected>:
    capture : J.Json <- J.parse(Output.capture(header(value)))
    Done{Expected{capture,header_snapshot(header(value)),resolved_key(value)}}

def encoded(value: Inline.Resolved) -> String:
  Inline.Resolved{capture,record,offset,length,digest,reference,path,media,Decode.Bytes{bytes,count,byte_digest}} = value
  "{\"kind\":\"attachment_preview\",\"version\":1,\"capture\":" ++ Output.capture(capture) ++
    ",\"record\":" ++ U32.show(record) ++ ",\"ref\":" ++ U32.show(reference) ++ ",\"path\":" ++ J.quote(path) ++
    ",\"offset\":" ++ U32.show(offset) ++ ",\"length\":" ++ U32.show(length) ++ ",\"raw_sha256\":" ++ J.quote(digest) ++
    ",\"media\":" ++ J.quote(media) ++ ",\"byte_count\":" ++ U32.show(count) ++ ",\"byte_sha256\":" ++ J.quote(byte_digest) ++
    ",\"hex\":\"" ++ hex_encode(bytes,"") ++ "\"}"

def encode(+value: Inline.Resolved) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    _ : Unit <- guard(Meta.header_valid(header(value)) && header_published(header(value)),"preview_invalid_capture_header")
    +expected : Expected <- resolved_expected(value)
    _ : Unit <- guard(expected_valid(expected),"preview_invalid_expected")
    _ : Unit <- data_valid(resolved_data(value))
    +text : String = encoded(value)
    _ : Unit <- guard(wire_bound(expected,text),"preview_packet_limit")
    Done{text}
