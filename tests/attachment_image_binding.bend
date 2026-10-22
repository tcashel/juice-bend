import Base
import ../src/attachment_image_binding.bend as B
import ../src/attachment_preview_packet.bend as P
import ../src/attachment_preview_external_packet.bend as E
import ../src/attachment_inline.bend as Inline
import ../src/attachment_decode.bend as D
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_asset_types.bend as T
import ../src/attachment_capture_output.bend as Output
import ../src/gui_attachments.bend as G
import ../src/archive_meta.bend as Meta
import ../src/json.bend as J

# Synthetic metadata only; independent byte/receipt SHA256 constants originate
# in the existing transport fixtures. No image decoder, source file or DB runs.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def raw_sha() -> String: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
def byte_sha() -> String: "c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"
def empty_sha() -> String: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
def path() -> String: "/message/content/2/source/data"

def parsed(result: Result<&2,&2,String,J.Json>) -> J.Json:
  match result:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(text: String) -> J.Json: parsed(J.parse(text))

def capture() -> String:
  "{\"provider\":\"claude\",\"source_id\":\"3\",\"source\":\"/synthetic/source.jsonl\",\"generation\":\"5\",\"snapshot\":\"7\",\"extent\":\"100\",\"total_records\":2,\"encoding\":\"identity\",\"byte_space\":\"logical_source_bytes\"}"

def inline_binding() -> String:
  "{\"kind\":\"inline\",\"capture\":" ++ capture() ++
    ",\"record\":1,\"ref\":2,\"path\":\"/message/content/2/source/data\",\"offset\":40,\"length\":20," ++
    "\"raw_sha256\":\"" ++ raw_sha() ++ "\",\"media\":\"image/png\",\"byte_count\":4,\"byte_sha256\":\"" ++ byte_sha() ++ "\"}"

def inline_expected() -> B.Expected:
  B.ExpectedInline{P.Expected{json(capture()),"7",G.OccurrenceKey{1,2,path(),40,20,raw_sha(),"image/png",4,True{}}}}

def header() -> Meta.Header:
  Meta.Header{"7","3","5","claude","/synthetic/source.jsonl",100,2,100,2,True{},"identity"}

def identity() -> I.Resolved:
  I.Resolved{header(),1,40,20,raw_sha(),2,"/message/content/2/source","image",I.LocalPath{"/synthetic/root/picture.png"}}

def receipt(index: U32) -> T.Receipt:
  match index:
    case 1: T.Receipt{identity(),T.RootEvidence{"11","/synthetic/root","5",True{}},"1700000000000",4,1,byte_sha(),"0747ad861636b6b1f6e0621dcca04bcc113055c5f34942683a10855163d2b657"}
    case 2: T.Receipt{identity(),T.RootEvidence{"11","/synthetic/root","4",True{}},"1700000000001",4,1,byte_sha(),"a0c8795e4a1e9a24a92b1b4b8a58004ce2e54ebcebc79b28ebdbfcc2ebb80405"}
    case _: T.Receipt{identity(),T.RootEvidence{"11","/synthetic/root","4",True{}},"1700000000000",4,1,byte_sha(),"db529340a7eeea0d6f3c568e8ecf9e2ff922f394a50856e101e5f017225bef46"}

def external() -> E.External:
  E.External{I.Request{"7",1,2,"/message/content/2/source"},receipt(0)}

def external_expected() -> B.Expected: B.ExpectedExternal{external()}

def external_binding(index: U32) -> String:
  "{\"kind\":\"external\",\"receipt\":" ++ Output.receipt(receipt(index)) ++
    ",\"byte_count\":4,\"byte_sha256\":\"" ++ byte_sha() ++ "\"}"

def pixel_result() -> String:
  "{\"kind\":\"pixels\",\"width\":3,\"height\":2,\"count\":6,\"capacity\":8,\"notice\":false,\"sha256\":\"" ++ raw_sha() ++ "\"}"

def wire(binding: String,result: String) -> String:
  "{\"kind\":\"attachment_image_raster\",\"version\":1,\"binding\":" ++ binding ++ ",\"result\":" ++ result ++ "}"

def fixture() -> String: wire(inline_binding(),pixel_result())

def pixels(result: Result<&2,&2,String,B.Header>,width: U32,height: U32,count: U32,capacity: U32) -> Bool:
  match result:
    case Done{B.PixelsHeader{w,h,n,size,notice,sha}}:
      U32.is_eq(w,width) && U32.is_eq(h,height) && U32.is_eq(n,count) && U32.is_eq(size,capacity) && Bool.not(notice) && String.eq(sha,raw_sha())
    case _: False{}

def refused(result: Result<&2,&2,String,B.Header>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def refused_json(result: Result<&2,&2,String,J.Json>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def refused_text(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def fields(values: List<&2,J.Field>,+name: String,+replacement: J.Json) -> List<&2,J.Field>:
  match values:
    case []: []
    case J.JField{+key,value} <> rest:
      J.JField{key,Bool.pick(J.Json,String.eq(key,name),replacement,value)} <> fields(rest,name,replacement)

def replace(value: J.Json,name: String,replacement: J.Json) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{fields(values,name,replacement)}
    case _: J.JNull{}

def extra(value: J.Json,name: String,field: J.Json) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{J.JField{name,field} <> values}
    case _: J.JNull{}

def absent(values: List<&2,J.Field>,+name: String) -> List<&2,J.Field>:
  match values:
    case []: []
    case J.JField{+key,value} <> rest:
      List.append(&2,J.Field,Bool.pick(List<&2,J.Field>,String.eq(key,name),[],[J.JField{key,value}]),absent(rest,name))

def remove(value: J.Json,name: String) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{absent(values,name)}
    case _: J.JNull{}

def rejected_encoded(value: Result<&2,&2,String,String>) -> Bool:
  match value:
    case Done{text}: refused(B.verify(inline_expected(),text))
    case Fail{_}: False{}

def bad(value: J.Json) -> Bool: rejected_encoded(J.encode_checked(value))
def changed(name: String,value: J.Json) -> Bool: bad(replace(json(fixture()),name,value))
def changed_binding(name: String,value: J.Json) -> Bool: changed("binding",replace(json(inline_binding()),name,value))
def changed_capture(name: String,value: J.Json) -> Bool:
  changed_binding("capture",replace(json(capture()),name,value))
def changed_result(name: String,value: J.Json) -> Bool: changed("result",replace(json(pixel_result()),name,value))

def missing(names: List<&2,String>) -> IO(Unit):
  match names:
    case []: IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        check(bad(remove(json(fixture()),name)),"missing raster header field " ++ name)
        missing(rest)

def identities() -> IO(Unit):
  do IO<Unit>:
    check(pixels(B.verify(inline_expected(),fixture()),3,2,6,8),"literal inline raster header admits exact occurrence and dimensions")
    check(pixels(B.verify(external_expected(),wire(external_binding(0),pixel_result())),3,2,6,8),"external header binds exact historical receipt")
    check(refused(B.verify(external_expected(),fixture())) && refused(B.verify(inline_expected(),wire(external_binding(0),pixel_result()))),"inline and external authority cannot substitute")
    check(changed_capture("snapshot",J.JString{"8"}),"different capture snapshot rejected")
    check(changed_capture("generation",J.JString{"6"}) && changed_capture("source",J.JString{"/synthetic/other.jsonl"}),"capture generation and literal source remain bound")
    check(changed_binding("record",J.JNumber{"0"}) && changed_binding("ref",J.JNumber{"1"}),"raw record and reference remain exact")
    check(changed_binding("path",J.JString{"/message/content/1/source/data"}),"forged occurrence path rejected")
    check(changed_binding("raw_sha256",J.JString{byte_sha()}),"raw record SHA cannot change")
    check(changed_binding("byte_count",J.JNumber{"5"}),"inline descriptor byte count cannot change")
    check(changed_binding("byte_sha256",J.JString{"bad"}),"decoded input digest must have canonical SHA256 shape")
    check(changed_binding("record",J.JNumber{"1.0"}) && changed_binding("offset",J.JString{"40"}),"occurrence numeric syntax and types remain exact")
    check(T.receipt_valid(receipt(1)) && T.receipt_valid(receipt(2)),"independent alternate receipt seals are valid fixtures")
    check(refused(B.verify(external_expected(),wire(external_binding(1),pixel_result()))),"otherwise valid changed historical root revision rejected")
    check(refused(B.verify(external_expected(),wire(external_binding(2),pixel_result()))),"otherwise valid changed observation timestamp rejected")

def shapes() -> IO(Unit):
  do IO<Unit>:
    missing(["kind","version","binding","result"])
    check(bad(extra(json(fixture()),"command",J.JString{"forged"})),"unknown outer field rejected")
    check(bad(extra(json(fixture()),"binding",json(inline_binding()))),"duplicate binding rejected")
    check(changed("version",J.JString{"1"}) && changed("version",J.JNumber{"1.0"}),"header version is canonical typed integer")
    check(changed("binding",extra(json(inline_binding()),"hex",J.JString{"0001feff"})),"binding cannot contain byte payload")
    check(changed("binding",remove(json(inline_binding()),"raw_sha256")),"missing raw commitment rejected")
    check(changed("result",extra(json(pixel_result()),"message",J.JString{"forged"})),"pixels and failure fields cannot mix")
    check(changed("result",extra(json(pixel_result()),"width",J.JNumber{"3"})),"duplicate pixel dimensions rejected")
    check(changed_result("width",J.JNumber{"3.0"}) && changed_result("height",J.JString{"2"}),"pixel dimensions require canonical numeric fields")
    check(changed_result("notice",J.JString{"false"}),"color notice requires JSON boolean")
    check(changed_result("sha256",J.JString{"ABCDEF0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcd"}),"uppercase pixel digest rejected")
    check(refused(B.verify(inline_expected(),fixture() ++ "{}")),"trailing JSON value rejected")
    check(refused(B.verify(inline_expected(),fixture() ++ "\n")),"header codec requires one line without stream delimiter")

def geometry() -> IO(Unit):
  do IO<Unit>:
    check(changed_result("width",J.JNumber{"0"}) && changed_result("height",J.JNumber{"0"}),"zero dimension rejected")
    check(changed_result("width",J.JNumber{"2049"}) && changed_result("height",J.JNumber{"4294967295"}),"oversize and overflow dimensions rejected")
    check(changed_result("count",J.JNumber{"5"}),"pixel count equals exact width times height")
    check(changed_result("capacity",J.JNumber{"6"}) && changed_result("capacity",J.JNumber{"16"}),"capacity is exact least holding power of two")
    check(U32.is_eq(B.capacity(1),1) && U32.is_eq(B.capacity(3),4) && U32.is_eq(B.capacity(1048576),1048576),"capacity boundaries use bounded calculation")
    check(B.geometry(2048,512,1048576,1048576),"one megapixel inclusive boundary admitted")
    check(Bool.not(B.geometry(2048,513,1050624,2097152)),"one megapixel excess rejected")
    check(Bool.not(B.geometry(4294967295,4294967295,1,1)),"wrapped multiplication cannot authorize large dimensions")

def failure_ok(result: Result<&2,&2,String,B.Header>,wanted: String) -> Bool:
  match result:
    case Done{B.FailureHeader{message}}: String.eq(message,wanted)
    case _: False{}

def encoded_failure(value: Result<&2,&2,String,String>,expected: B.Expected,wanted: String) -> Bool:
  match value:
    case Done{text}: failure_ok(B.verify(expected,text),wanted)
    case Fail{_}: False{}

def errors() -> IO(Unit):
  do IO<Unit>:
    check(failure_ok(B.verify(inline_expected(),wire(inline_binding(),"{\"kind\":\"failure\",\"message\":\"Unsupported progressive JPEG\"}")),"Unsupported progressive JPEG"),"typed failure binds same exact occurrence")
    check(refused(B.verify(inline_expected(),wire(inline_binding(),"{\"kind\":\"failure\",\"message\":\"bad\",\"width\":1}"))),"failure cannot smuggle pixel fields")
    check(refused(B.verify(inline_expected(),wire(inline_binding(),"{\"kind\":\"failure\",\"message\":\"line\\nnext\"}"))),"escaped control in failure rejected")
    check(refused_text(B.failure(json(inline_binding()),"")) && refused_text(B.failure(json(inline_binding()),"bad\0message")),"empty and NUL error messages rejected")
    check(refused_text(B.failure(json(inline_binding()),SCon{Chr{8238},"reversed"})),"direction override in error rejected")
    check(encoded_failure(B.failure(json(inline_binding()),String.repeat("a",1024n)),inline_expected(),String.repeat("a",1024n)),"1024 UTF8 byte failure boundary admitted")
    check(refused_text(B.failure(json(inline_binding()),String.repeat("a",1025n))),"oversized failure refused without truncation")
    check(refused_text(B.failure(json(inline_binding()),String.repeat("中",342n))),"failure byte bound includes Unicode width")
    check(refused(B.verify(inline_expected(),String.repeat(" ",65536n) ++ fixture())),"header raw byte limit checked before parse")

def resolved(data: D.Bytes) -> Inline.Resolved:
  Inline.Resolved{header(),1,40,20,raw_sha(),2,path(),"image/png",data}

def produced_text(value: Result<&2,&2,String,String>,expected: B.Expected) -> Bool:
  match value:
    case Done{text}: pixels(B.verify(expected,text),3,2,6,8)
    case Fail{_}: False{}

def produced(value: Result<&2,&2,String,J.Json>,expected: B.Expected) -> Bool:
  match value:
    case Fail{_}: False{}
    case Done{binding}: produced_text(B.success(binding,3,2,6,8,False{},raw_sha()),expected)

def producers() -> IO(Unit):
  do IO<Unit>:
    check(produced(B.inline(resolved(D.Bytes{[0,1,254,255],4,byte_sha()})),inline_expected()),"inline producer validates retained bytes then emits metadata only")
    check(refused_json(B.inline(resolved(D.Bytes{[0,1,254,255],4,empty_sha()}))),"inline producer rejects wrong retained input digest")
    check(refused_json(B.inline(resolved(D.Bytes{[0,1,254],4,byte_sha()}))),"inline producer rejects short retained bytes")
    check(produced(B.external(external(),T.Owned{receipt(0),[T.Chunk{0,0,4,byte_sha(),[0,1,254,255]}]}),external_expected()),"external producer verifies complete retained bytes and receipt")
    check(refused_json(B.external(external(),T.Owned{receipt(0),[T.Chunk{0,0,4,byte_sha(),[0,1,254,256]}]})),"external producer rejects nonoctet owned payload")
    check(refused_json(B.external(external(),T.Owned{receipt(1),[T.Chunk{0,0,4,byte_sha(),[0,1,254,255]}]})),"external producer rejects different valid historical receipt")
    check(refused_text(B.success(json(inline_binding()),2049,1,2049,4096,False{},raw_sha())),"producer refuses geometry outside display profile")
    check(refused_text(B.success(json(inline_binding()),3,2,6,8,False{},"bad")),"producer refuses noncanonical pixel digest")

def main() -> IO(Unit):
  do IO<Unit>:
    identities()
    shapes()
    geometry()
    errors()
    producers()
    IO.print("Image raster binding tests passed")
