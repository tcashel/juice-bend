import Base
import ../src/attachment_preview_packet.bend as P
import ../src/attachment_inline.bend as Inline
import ../src/attachment_decode.bend as D
import ../src/gui_attachments.bend as G
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as Domain
import ../src/json.bend as J

# Independent literal wire/identity fixtures. SHA256 constants were calculated
# independently (Python hashlib), not by the Bend encoder under test. No files,
# database, provider source, external attachment or image decoder are used.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def json_result(result: Result<&2,&2,String,J.Json>) -> J.Json:
  match result:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(text: String) -> J.Json: json_result(J.parse(text))
def raw_sha() -> String: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
def binary_sha() -> String: "c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"
def empty_sha() -> String: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
def million_sha() -> String: "30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58"
def path() -> String: "/message/content/2/source/data"

def capture() -> String:
  "{\"provider\":\"claude\",\"source_id\":\"3\",\"source\":\"/synthetic/source.jsonl\",\"generation\":\"5\",\"snapshot\":\"7\",\"extent\":\"100\",\"total_records\":2,\"encoding\":\"identity\",\"byte_space\":\"logical_source_bytes\"}"

def wire(capture: String,count: String,digest: String,hex: String) -> String:
  "{\"kind\":\"attachment_preview\",\"version\":1,\"capture\":" ++ capture ++
    ",\"record\":1,\"ref\":2,\"path\":\"/message/content/2/source/data\",\"offset\":40,\"length\":20," ++
    "\"raw_sha256\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"media\":\"image/png\",\"byte_count\":" ++ count ++
    ",\"byte_sha256\":\"" ++ digest ++ "\",\"hex\":\"" ++ hex ++ "\"}"

def fixture() -> String: wire(capture(),"4",binary_sha(),"0001feff")

def key(bytes: U32) -> G.OccurrenceKey:
  G.OccurrenceKey{1,2,path(),40,20,raw_sha(),"image/png",bytes,True{}}

def expected(bytes: U32) -> P.Expected:
  P.Expected{json(capture()),"7",key(bytes)}

def rejected(result: Result<&2,&2,String,D.Bytes>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def failed(result: Result<&2,&2,String,D.Bytes>,expected: String) -> Bool:
  match result:
    case Fail{message}: String.eq(message,expected)
    case Done{_}: False{}

def good(result: Result<&2,&2,String,D.Bytes>,bytes: List<&2,U32>,count: U32,digest: String) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{D.Bytes{actual,actual_count,actual_digest}}:
      Domain.bytes_equal(actual,bytes) && U32.is_eq(actual_count,count) && String.eq(actual_digest,digest)

def replace_fields(fields: List<&2,J.Field>,+name: String,+replacement: J.Json) -> List<&2,J.Field>:
  match fields:
    case []: []
    case J.JField{+key,value} <> rest:
      J.JField{key,Bool.pick(J.Json,String.eq(key,name),replacement,value)} <> replace_fields(rest,name,replacement)

def replace(value: J.Json,name: String,replacement: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{replace_fields(fields,name,replacement)}
    case _: J.JNull{}

def remove_fields(fields: List<&2,J.Field>,+name: String) -> List<&2,J.Field>:
  match fields:
    case []: []
    case J.JField{+key,value} <> rest:
      List.append(&2,J.Field,Bool.pick(List<&2,J.Field>,String.eq(key,name),[],[J.JField{key,value}]),remove_fields(rest,name))

def remove(value: J.Json,name: String) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{remove_fields(fields,name)}
    case _: J.JNull{}

def extra(value: J.Json,name: String,field: J.Json) -> J.Json:
  match value:
    case J.JObject{fields}: J.JObject{J.JField{name,field} <> fields}
    case _: J.JNull{}

def wrong_encoded(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{text}: rejected(P.verify(expected(4),text))

def wrong(value: J.Json) -> Bool: wrong_encoded(J.encode_checked(value))
def changed(name: String,value: J.Json) -> Bool: wrong(replace(json(fixture()),name,value))
def changed_capture(name: String,value: J.Json) -> Bool:
  changed("capture",replace(json(capture()),name,value))

def repeat(n: Nat,+part: String) -> String:
  match n:
    case 0n: ""
    case 1n+left: part ++ repeat(left,part)

def missing(names: List<&2,String>) -> IO(Unit):
  match names:
    case []: IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        check(wrong(remove(json(fixture()),name)),"missing exact packet field " ++ name)
        missing(rest)

def bad_hex(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case +text <> rest:
      do IO<Unit>:
        check(changed("hex",J.JString{text}),"strict lowercase octets reject " ++ J.quote(text))
        bad_hex(rest)

def bad_keys(values: List<&2,G.OccurrenceKey>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        check(failed(P.verify(P.Expected{json(capture()),"7",value},fixture()),"preview_invalid_expected"),"invalid caller key cannot authorize packet")
        bad_keys(rest)

def requested(value: Inline.Request) -> Bool:
  Inline.Request{snapshot,record,reference,pointer} = value
  String.eq(snapshot,"7") && U32.is_eq(record,1) && U32.is_eq(reference,2) && String.eq(pointer,path())

def known() -> IO(Unit):
  do IO<Unit>:
    check(U32.is_eq(P.max_output(),2162688),"wire cap is two MiB plus64 KiB")
    check(requested(P.request(expected(4))),"request retains exact snapshot record reference path")
    check(good(P.verify(expected(4),fixture()),[0,1,254,255],4,binary_sha()),"independent binary packet preserves NUL and invalidUTF8 octets")
    check(good(P.verify(expected(3),wire(capture(),"3","ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad","616263")),[97,98,99],3,"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),"independent abc SHA256 vector")
    check(good(P.verify(expected(0),wire(capture(),"0",empty_sha(),"")),[],0,empty_sha()),"empty retained bytes require exact empty commitment")
    check(good(P.verify(expected(4)," \n" ++ fixture() ++ "\t"),[0,1,254,255],4,binary_sha()),"bounded JSON whitespace preserves identity")
    check(rejected(P.verify(expected(4),fixture() ++ "{}")),"trailing JSON value rejected")
    check(rejected(P.verify(expected(4),"[]")),"nonobject packet rejected")
    check(wrong(extra(json(fixture()),"untrusted",J.JBool{True{}})),"unknown packet field rejected")
    check(wrong(extra(json(fixture()),"kind",J.JString{"attachment_preview"})),"duplicate packet field rejected")
    check(changed("kind",J.JString{"attachment_inventory"}),"ordinary metadata is not a byte packet")
    check(changed("version",J.JNumber{"2"}) && changed("version",J.JString{"1"}) && changed("version",J.JNumber{"1.0"}),"version has exact typed canonical representation")
    missing(["kind","version","capture","record","ref","path","offset","length","raw_sha256","media","byte_count","byte_sha256","hex"])

def identities() -> IO(Unit):
  do IO<Unit>:
    check(changed_capture("provider",J.JString{"codex"}),"other valid provider rejected")
    check(changed_capture("source_id",J.JString{"4"}),"other source identity rejected")
    check(changed_capture("source",J.JString{"/synthetic/other.jsonl"}),"other source locator rejected")
    check(changed_capture("generation",J.JString{"6"}),"other generation rejected")
    check(changed_capture("snapshot",J.JString{"8"}),"other snapshot rejected")
    check(changed_capture("extent",J.JString{"101"}),"changed logical extent rejected")
    check(changed_capture("total_records",J.JNumber{"3"}),"changed total records rejected")
    check(changed_capture("encoding",J.JString{"zstd-jsonl-v1"}),"other valid encoding rejected")
    check(changed_capture("byte_space",J.JString{"compressed_source_bytes"}),"compressed bytes cannot masquerade as logical record offsets")
    check(changed_capture("source_id",J.JNumber{"3"}) && changed_capture("extent",J.JNumber{"100"}) && changed_capture("total_records",J.JString{"2"}),"capture field types are exact")
    check(changed_capture("generation",J.JString{"05"}),"noncanonical capture identity rejected")
    check(changed("capture",extra(json(capture()),"extra",J.JNull{})),"unknown capture field rejected")
    check(changed("capture",remove(json(capture()),"source")),"missing capture field rejected")
    check(changed("capture",extra(json(capture()),"snapshot",J.JString{"7"})),"duplicate capture field rejected")
    check(changed("record",J.JNumber{"0"}) && changed("ref",J.JNumber{"1"}),"record and reference bind exact occurrence")
    check(changed("path",J.JString{"/message/content/1/source/data"}),"same metadata with different structural path rejected")
    check(changed("offset",J.JNumber{"41"}) && changed("length",J.JNumber{"19"}),"record interval binds both offset and length")
    check(changed("raw_sha256",J.JString{binary_sha()}),"raw record commitment cannot change")
    check(changed("media",J.JString{"image/jpeg"}),"media type cannot change")
    check(changed("byte_count",J.JNumber{"5"}) && changed("byte_count",J.JString{"4"}),"byte count binds exact typed descriptor count")
    check(changed("record",J.JNumber{"1e0"}) && changed("offset",J.JNumber{"40.0"}),"numerically equal noncanonical occurrence numbers rejected")
    check(failed(P.verify(P.Expected{json(capture()),"8",key(4)},fixture()),"preview_invalid_expected"),"caller snapshot must agree with caller capture")
    check(failed(P.verify(P.Expected{replace(json(capture()),"snapshot",J.JString{"07"}),"07",key(4)},fixture()),"preview_invalid_expected"),"caller capture is validated independently")

def malformed() -> IO(Unit):
  do IO<Unit>:
    bad_hex(["","0001fef","0001feff00","0001feFf","0001FEFF","0001fe f","0x01feff","0001fe-1","0001fegg","0001féff","0001feff\n"])
    check(changed("hex",J.JNumber{"1234"}),"hex payload must be a JSON string")
    check(changed("hex",J.JString{"0001fefe"}),"same length altered payload fails SHA256")
    check(changed("byte_sha256",J.JString{empty_sha()}),"different valid checksum rejected")
    check(changed("byte_sha256",J.JString{"C5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"}),"uppercase checksum rejected")
    check(changed("byte_sha256",J.JString{binary_sha() ++ "0"}) && changed("byte_sha256",J.JNull{}),"wrong checksum width or type rejected")
    bad_keys([
      G.OccurrenceKey{2,2,path(),40,20,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,64,path(),40,20,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,"relative",40,20,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),101,20,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),4294967295,20,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),40,61,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),40,0,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),0,262145,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{0,2,path(),40,20,raw_sha(),"image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),40,20,"wrong","image/png",4,True{}},
      G.OccurrenceKey{1,2,path(),40,20,raw_sha(),"image/png",1048577,True{}},
      G.OccurrenceKey{1,2,path(),40,20,raw_sha(),"image/png",4294967295,True{}},
      G.OccurrenceKey{1,2,path(),40,20,raw_sha(),"image/png",4,False{}}])

def all_zero(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case []: True{}
    case byte <> rest: U32.is_eq(byte,0) && all_zero(rest)

def maximum(result: Result<&2,&2,String,D.Bytes>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{D.Bytes{+bytes,count,digest}}:
      U32.is_eq(count,1048576) && Nat.is_eq(List.length(&2,U32,bytes),1048576n) && all_zero(bytes) && String.eq(digest,million_sha())

def limits() -> IO(Unit):
  do IO<Unit>:
    check(failed(P.verify(expected(4),repeat(65536n," ") ++ fixture()),"preview_packet_limit"),"oversized raw header whitespace refused before JSON parse")
    check(failed(P.verify(expected(4),repeat(22000n,"中") ++ fixture()),"preview_packet_limit"),"wire limit counts UTF8 bytes rather than characters")
    check(changed_capture("source",J.JString{"/" ++ repeat(4096n,"a")}),"source header exceeds4096 UTF8 bytes")
    check(changed_capture("source",J.JString{"/" ++ repeat(1366n,"中")}),"source header UTF8 bound includes multibyte characters")
    check(failed(P.verify(P.Expected{json(capture()),"7",G.OccurrenceKey{1,2,"/" ++ repeat(2048n,"a"),40,20,raw_sha(),"image/png",4,True{}}},fixture()),"preview_invalid_expected"),"structural path header exceeds2048 UTF8 bytes")
    check(failed(P.verify(P.Expected{json(capture()),"7",G.OccurrenceKey{1,2,path(),40,20,raw_sha(),repeat(128n,"a"),4,True{}}},fixture()),"preview_invalid_expected"),"media header exceeds127 UTF8 bytes")
    check(maximum(P.verify(expected(1048576),wire(capture(),"1048576",million_sha(),repeat(1048576n,"00")))),"exact one MiB packet verifies beyond base64 decoder cap and default JSON lexer fuel")

def resolved(data: D.Bytes) -> Inline.Resolved:
  Inline.Resolved{Meta.Header{"7","3","5","claude","/synthetic/source.jsonl",100,2,100,2,True{},"identity"},
    1,40,20,raw_sha(),2,path(),"image/png",data}

def encode_failed(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def encoded(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{+text}: String.eq(text,fixture()) && good(P.verify(expected(4),text),[0,1,254,255],4,binary_sha())

def unpublished(value: Inline.Resolved) -> Inline.Resolved:
  Inline.Resolved{_,record,offset,length,sha,reference,pointer,media,data} = value
  Inline.Resolved{Meta.Header{"7","3","5","claude","/synthetic/source.jsonl",100,2,100,2,False{},"identity"},record,offset,length,sha,reference,pointer,media,data}

def producing() -> IO(Unit):
  do IO<Unit>:
    check(encoded(P.encode(resolved(D.Bytes{[0,1,254,255],4,binary_sha()}))),"fresh resolved bytes encode exactly independent wire fixture")
    check(encode_failed(P.encode(resolved(D.Bytes{[0,1,254,255],3,binary_sha()}))),"producer refuses byte count mismatch")
    check(encode_failed(P.encode(resolved(D.Bytes{[0,1,254,255],4,empty_sha()}))),"producer refuses byte checksum mismatch")
    check(encode_failed(P.encode(resolved(D.Bytes{[256],1,empty_sha()}))),"producer refuses nonoctet byte before hashing")
    check(encode_failed(P.encode(resolved(D.Bytes{[],786433,empty_sha()}))),"inline producer retains base64-specific byte cap")
    check(encode_failed(P.encode(resolved(D.Bytes{[],4294967295,empty_sha()}))),"producer refuses unsigned maximum count before allocation")
    check(encode_failed(P.encode(unpublished(resolved(D.Bytes{[0,1,254,255],4,binary_sha()})))),"unpublished capture cannot produce preview packet")

def main() -> IO(Unit):
  do IO<Unit>:
    known()
    identities()
    malformed()
    limits()
    producing()
    IO.print("Attachment preview packet tests passed")
