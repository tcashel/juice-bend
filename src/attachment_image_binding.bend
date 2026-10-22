import Base
import ./attachment_preview_packet.bend as Packet
import ./attachment_preview_external_packet.bend as External
import ./attachment_inline.bend as Inline
import ./attachment_decode.bend as Decode
import ./attachment_asset_types.bend as Assets
import ./attachment_capture_ack.bend as Ack
import ./gui_attachments.bend as Gui
import ./gui_settings.bend as Shape
import ./attachment_refs.bend as Ref
import ./archive_meta.bend as Meta
import ./json.bend as J

# Metadata only. The parent retains Expected independently of the child output.
# Pixel digest verification and affine Array construction belong to the bounded
# streaming consumer; this codec never grants source or filesystem authority.
type Expected is Data:
  ExpectedInline{expected: Packet.Expected}
  ExpectedExternal{expected: External.External}

type Header is Data:
  PixelsHeader{width: U32,height: U32,count: U32,capacity: U32,notice: Bool,digest: String}
  FailureHeader{message: String}

def limit() -> U32: 65536

def guard(valid: Bool,message: String) -> Result<&2,&2,String,Unit>:
  Packet.guard(valid,message)

def digest(+value: J.Json) -> Bool:
  Gui.bounded(value,64) && Gui.commitment(J.text(value))

def inline_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["kind","capture","record","ref","path","offset","length","raw_sha256","media","byte_count","byte_sha256"]) &&
    Shape.text_is(J.field(value,"kind"),"inline") && digest(J.field(value,"byte_sha256"))

def inline_expected(+value: J.Json) -> Packet.Expected:
  +capture = J.field(value,"capture")
  Packet.Expected{capture,J.get(capture,"snapshot"),Gui.OccurrenceKey{
    Gui.number(J.field(value,"record")),Gui.number(J.field(value,"ref")),J.get(value,"path"),
    Gui.number(J.field(value,"offset")),Gui.number(J.field(value,"length")),J.get(value,"raw_sha256"),
    J.get(value,"media"),Gui.number(J.field(value,"byte_count")),True{}}}

def inline_matches(+expected: Packet.Expected,+value: J.Json) -> Bool:
  inline_shape(value) && Packet.expected_valid(expected) && Packet.capture_matches(expected,value) && Packet.occurrence_matches(expected,value)

def external_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["kind","receipt","byte_count","byte_sha256"]) &&
    Shape.text_is(J.field(value,"kind"),"external") && digest(J.field(value,"byte_sha256"))

def receipt_payload(+value: J.Json,receipt: Assets.Receipt) -> Bool:
  Assets.Receipt{_,_,_,count,_,sha,_} = receipt
  Shape.number_is(J.field(value,"byte_count"),U32.show(count)) && Shape.text_is(J.field(value,"byte_sha256"),sha)

def external_receipt(+value: J.Json) -> Result<&2,&2,String,Assets.Receipt>:
  do Result<&2,&2,String,Assets.Receipt>:
    _ : Unit <- guard(external_shape(value),"image_external_binding_shape")
    +receipt : Assets.Receipt <- Ack.receipt(J.field(value,"receipt"))
    _ : Unit <- guard(receipt_payload(value,receipt),"image_external_binding_payload")
    Done{receipt}

def binding_external(external: Bool,+value: J.Json) -> Result<&2,&2,String,Unit>:
  match external:
    case False{}: Fail{"image_binding_kind"}
    case True{}:
      do Result<&2,&2,String,Unit>:
        _ : Assets.Receipt <- external_receipt(value)
        Done{Unit{}}

def binding_inline(inline: Bool,+value: J.Json) -> Result<&2,&2,String,Unit>:
  match inline:
    case True{}: guard(inline_matches(inline_expected(value),value),"image_inline_binding_metadata")
    case False{}: binding_external(Shape.text_is(J.field(value,"kind"),"external"),value)

def binding(value: J.Json) -> Result<&2,&2,String,Unit>:
  +copy = value
  binding_inline(Shape.text_is(J.field(copy,"kind"),"inline"),copy)

def expected_valid(value: Expected) -> Bool:
  match value:
    case ExpectedInline{expected}: Packet.expected_valid(expected)
    case ExpectedExternal{expected}: External.expected_valid(expected)

def matches(expected: Expected,+value: J.Json) -> Result<&2,&2,String,Unit>:
  match expected:
    case ExpectedInline{expected}: guard(inline_matches(expected,value),"image_inline_binding_mismatch")
    case ExpectedExternal{+expected}:
      do Result<&2,&2,String,Unit>:
        actual : Assets.Receipt <- external_receipt(value)
        guard(External.expected_valid(expected) && External.matches(expected,actual),"image_external_binding_mismatch")

# Bound the calculation independently of untrusted count. The only accepted
# capacity is the smallest power of two holding all admitted image pixels.
def capacity_step(left: Nat,+count: U32,+capacity: U32) -> U32:
  match left:
    case 0n: capacity
    case 1n+rest:
      Bool.pick(U32,U32.is_ge(capacity,count),capacity,capacity_step(rest,count,U32.mul(capacity,2)))

def capacity(count: U32) -> U32:
  capacity_step(20n,U32.min(count,1048576),1)

def geometry(+width: U32,+height: U32,+count: U32,size: U32) -> Bool:
  U32.is_gt(width,0) && U32.is_le(width,2048) && U32.is_gt(height,0) && U32.is_le(height,2048) &&
    U32.is_gt(count,0) && U32.is_le(count,1048576) && U32.is_eq(count,U32.mul(width,height)) && U32.is_eq(size,capacity(count))

def controls(value: String) -> Bool:
  match value:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      U32.is_ge(cp,32) && Bool.not(U32.is_ge(cp,127) && U32.is_le(cp,159)) &&
        U32.is_ne(cp,1564) && U32.is_ne(cp,8206) && U32.is_ne(cp,8207) &&
        Bool.not(U32.is_ge(cp,8232) && U32.is_le(cp,8238)) &&
        Bool.not(U32.is_ge(cp,8294) && U32.is_le(cp,8297)) && controls(rest)

def failure_message(+message: String) -> Bool:
  Bool.not(String.is_empty(message)) && Ref.bounded(message,1024) && controls(message)

def pixels(+value: J.Json) -> Result<&2,&2,String,Header>:
  do Result<&2,&2,String,Header>:
    _ : Unit <- guard(Shape.exact_object(value,["kind","width","height","count","capacity","notice","sha256"]) &&
      Shape.text_is(J.field(value,"kind"),"pixels") && Gui.numeric(J.field(value,"width")) &&
      Gui.numeric(J.field(value,"height")) && Gui.numeric(J.field(value,"count")) && Gui.numeric(J.field(value,"capacity")) &&
      Shape.boolean(J.field(value,"notice")) && digest(J.field(value,"sha256")),"image_pixel_header_shape")
    +width : U32 = Gui.number(J.field(value,"width"))
    +height : U32 = Gui.number(J.field(value,"height"))
    +count : U32 = Gui.number(J.field(value,"count"))
    +size : U32 = Gui.number(J.field(value,"capacity"))
    _ : Unit <- guard(geometry(width,height,count,size),"image_pixel_geometry")
    Done{PixelsHeader{width,height,count,size,Gui.true(J.field(value,"notice")),J.get(value,"sha256")}}

def result_kind(success: Bool,+value: J.Json) -> Result<&2,&2,String,Header>:
  match success:
    case True{}: pixels(value)
    case False{}:
      do Result<&2,&2,String,Header>:
        _ : Unit <- guard(Shape.exact_object(value,["kind","message"]) && Shape.text_is(J.field(value,"kind"),"failure") &&
          Gui.bounded(J.field(value,"message"),1024) && failure_message(J.get(value,"message")),"image_failure_header_shape")
        Done{FailureHeader{J.get(value,"message")}}

def verified(expected: Expected,+value: J.Json) -> Result<&2,&2,String,Header>:
  do Result<&2,&2,String,Header>:
    _ : Unit <- guard(Shape.exact_object(value,["kind","version","binding","result"]) &&
      Shape.text_is(J.field(value,"kind"),"attachment_image_raster") && Shape.number_is(J.field(value,"version"),"1"),"image_header_shape")
    _ : Unit <- matches(expected,J.field(value,"binding"))
    +result : J.Json = J.field(value,"result")
    result_kind(Shape.text_is(J.field(result,"kind"),"pixels"),result)

def verify(+expected: Expected,+text: String) -> Result<&2,&2,String,Header>:
  do Result<&2,&2,String,Header>:
    _ : Unit <- guard(expected_valid(expected),"image_invalid_expected")
    _ : Unit <- guard(Ref.bounded(text,limit()),"image_header_limit")
    _ : Unit <- guard(Bool.not(String.contains(text,"\n")) && Bool.not(String.contains(text,"\r")),"image_header_line")
    value : J.Json <- J.parse(text)
    verified(expected,value)

def inline_metadata(expected: Packet.Expected,sha: String) -> J.Json:
  Packet.Expected{capture,_,Gui.OccurrenceKey{record,reference,path,offset,length,raw,media,count,_}} = expected
  J.JObject{[J.JField{"kind",J.JString{"inline"}},J.JField{"capture",capture},
    J.JField{"record",J.JNumber{U32.show(record)}},J.JField{"ref",J.JNumber{U32.show(reference)}},
    J.JField{"path",J.JString{path}},J.JField{"offset",J.JNumber{U32.show(offset)}},
    J.JField{"length",J.JNumber{U32.show(length)}},J.JField{"raw_sha256",J.JString{raw}},
    J.JField{"media",J.JString{media}},J.JField{"byte_count",J.JNumber{U32.show(count)}},J.JField{"byte_sha256",J.JString{sha}}]}

def data_digest(data: Decode.Bytes) -> String:
  Decode.Bytes{_,_,sha} = data
  sha

def inline(+value: Inline.Resolved) -> Result<&2,&2,String,J.Json>:
  do Result<&2,&2,String,J.Json>:
    _ : Unit <- guard(Meta.header_valid(Packet.header(value)) && Packet.header_published(Packet.header(value)),"image_inline_capture_header")
    +expected : Packet.Expected <- Packet.resolved_expected(value)
    _ : Unit <- guard(Packet.expected_valid(expected),"image_inline_expected")
    +data : Decode.Bytes = Packet.resolved_data(value)
    _ : Unit <- Packet.data_valid(data)
    Done{inline_metadata(expected,data_digest(data))}

def external(+expected: External.External,+owned: Assets.Owned) -> Result<&2,&2,String,J.Json>:
  do Result<&2,&2,String,J.Json>:
    _ : Unit <- guard(External.expected_valid(expected),"image_external_expected")
    _ : Unit <- guard(Assets.receipt_valid(External.owned_receipt(owned)) &&
      External.matches(expected,External.owned_receipt(owned)),"image_external_owned_receipt")
    _ : Unit <- guard(Assets.owned_valid(owned),"image_external_owned_bytes")
    text : String <- External.encoded_receipt(External.receipt(expected))
    receipt : J.Json <- J.parse(text)
    Done{J.JObject{[J.JField{"kind",J.JString{"external"}},J.JField{"receipt",receipt},
      J.JField{"byte_count",J.JNumber{U32.show(External.count(expected))}},
      J.JField{"byte_sha256",J.JString{External.digest(External.receipt(expected))}}]}}

def encoded(binding: J.Json,result: J.Json) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    +text : String <- J.encode_checked(J.JObject{[J.JField{"kind",J.JString{"attachment_image_raster"}},
      J.JField{"version",J.JNumber{"1"}},J.JField{"binding",binding},J.JField{"result",result}]})
    _ : Unit <- guard(Ref.bounded(text,limit()),"image_header_limit")
    Done{text}

def success(+value: J.Json,+width: U32,+height: U32,+count: U32,+size: U32,notice: Bool,+sha: String) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    _ : Unit <- binding(value)
    _ : Unit <- guard(geometry(width,height,count,size) && digest(J.JString{sha}),"image_pixel_geometry_or_digest")
    encoded(value,J.JObject{[J.JField{"kind",J.JString{"pixels"}},J.JField{"width",J.JNumber{U32.show(width)}},
      J.JField{"height",J.JNumber{U32.show(height)}},J.JField{"count",J.JNumber{U32.show(count)}},
      J.JField{"capacity",J.JNumber{U32.show(size)}},J.JField{"notice",J.JBool{notice}},J.JField{"sha256",J.JString{sha}}]})

def failure(+value: J.Json,+message: String) -> Result<&2,&2,String,String>:
  do Result<&2,&2,String,String>:
    _ : Unit <- binding(value)
    _ : Unit <- guard(failure_message(message),"image_failure_message")
    encoded(value,J.JObject{[J.JField{"kind",J.JString{"failure"}},J.JField{"message",J.JString{message}}]})
