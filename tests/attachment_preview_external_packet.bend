import Base
import ../src/attachment_preview_external_packet.bend as E
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_asset_types.bend as T
import ../src/attachment_capture_output.bend as Output
import ../src/attachment_capture_ack.bend as Ack
import ../src/attachment_decode.bend as D
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as Domain
import ../src/json.bend as J

# Synthetic independent metadata and binary fixtures. Commitment constants were
# calculated with Python hashlib over decimal UTF8 byte lengths, ':' and each
# field in Types.fields order. Neither T.sealed nor the packet encoder supplies
# expected commitments. The primary wire below is an independent JSON literal.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def raw_sha() -> String: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
def binary_sha() -> String: "c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"
def empty_sha() -> String: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

def commitment(index: U32) -> String:
  match index:
    case 0: "db529340a7eeea0d6f3c568e8ecf9e2ff922f394a50856e101e5f017225bef46"
    case 1: "524ab95c006d4b318e3046fa12df8ccf4a016398a0f059e1716f0cb97eaf7b43"
    case 2: "a0c8795e4a1e9a24a92b1b4b8a58004ce2e54ebcebc79b28ebdbfcc2ebb80405"
    case 3: "5cc2f2713dae40e37d391d15aaa723e472a1fb2d442acf1e48b40f6aded7a6da"
    case 4: "34787249811eb16fe76c4d2845981c819eedbdb72e6dcf3057e50130cc9c294a"
    case 5: "468e3e2089178a068f01d08c36c1e465f16353069fd11893bca200244b0f6036"
    case 6: "0747ad861636b6b1f6e0621dcca04bcc113055c5f34942683a10855163d2b657"
    case 7: "76fda3cd74c8d37bed2c17d77d421d639f34bbcb395545365fd6c3c284aa45da"
    case 8: "1736c48bad10907bcff5872ef81a83f8e015fc528fa3d6e335b3ca197407d925"
    case 9: "7b9372da1d3811f20ce34d49eb6648198b930a965b132c6eeec77428bbac98cb"
    case 10: "f5243bd1a2d34e66de5b3bbae5018a4d489aae8ae1d97ba98aa1026ab8432046"
    case 11: "9475828126265b3cb830005931e77539ece79f8cef05b9226bafa178f8dde571"
    case _: "invalid fixture index"

def repeat(n: Nat,+part: String) -> String:
  match n:
    case 0n: ""
    case 1n+left: part ++ repeat(left,part)

def chosen(index: U32,wanted: U32,ordinary: String,changed: String) -> String:
  Bool.pick(String,U32.is_eq(index,wanted),changed,ordinary)

def pointer(index: U32) -> String:
  match index:
    case 10: "/" ++ repeat(2047n,SCon{Chr{1},SNil{}})
    case _: "/message/content/2/source"

def source(index: U32) -> String:
  match index:
    case 10: "/" ++ repeat(4095n,SCon{Chr{1},SNil{}})
    case _: "/synthetic/source.jsonl"

def root_path(index: U32) -> String:
  match index:
    case 10: "/" ++ repeat(4095n,"\"")
    case _: "/synthetic/root"

def header(+index: U32) -> Meta.Header:
  Meta.Header{chosen(index,7,"7","8"),"3","5","claude",source(index),100,2,
    Bool.pick(U32,U32.is_eq(index,5),90,100),2,True{},"identity"}

def local(index: U32) -> I.LocalReference:
  match index:
    case 11: I.LocalFileURL{"file:///synthetic/root/picture.png"}
    case 10: I.LocalPath{"/" ++ repeat(4095n,SCon{Chr{1},SNil{}})}
    case 4: I.LocalPath{"/synthetic/root/other.png"}
    case _: I.LocalPath{"/synthetic/root/picture.png"}

def identity(+index: U32) -> I.Resolved:
  I.Resolved{header(index),1,Bool.pick(U32,U32.is_eq(index,3),41,40),20,raw_sha(),2,pointer(index),
    chosen(index,8,"image","document"),local(index)}

def root(+index: U32) -> T.RootEvidence:
  T.RootEvidence{chosen(index,1,"11","12"),root_path(index),chosen(index,6,"4","5"),True{}}

def fixture_receipt(+index: U32) -> T.Receipt:
  +empty : Bool = U32.is_eq(index,9) || U32.is_eq(index,10)
  T.Receipt{identity(index),root(index),chosen(index,2,"1700000000000","1700000000001"),
    Bool.pick(U32,empty,0,4),Bool.pick(U32,empty,0,1),Bool.pick(String,empty,empty_sha(),binary_sha()),commitment(index)}

def expected(+index: U32) -> E.External:
  E.External{I.request(identity(index)),fixture_receipt(index)}

def receipt_wire() -> String:
  "{\"occurrence\":{\"capture\":{\"snapshot\":\"7\",\"source_id\":\"3\",\"generation\":\"5\",\"provider\":\"claude\",\"source\":\"/synthetic/source.jsonl\",\"extent\":100,\"byte_space\":\"logical_source_bytes\",\"total_records\":2,\"checkpoint\":100,\"checkpoint_ordinal\":2,\"accepted\":true,\"encoding\":\"identity\"}," ++
    "\"byte_space\":\"logical_source_bytes\",\"record\":1,\"offset\":40,\"length\":20,\"raw_sha256\":\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\",\"reference\":2,\"json_path\":\"/message/content/2/source\",\"attachment_kind\":\"image\",\"local_reference\":{\"type\":\"local_path\",\"value\":\"/synthetic/root/picture.png\"}}," ++
    "\"root\":{\"id\":\"11\",\"canonical_path\":\"/synthetic/root\",\"revision\":\"4\",\"enabled\":true},\"observed_at_ms\":\"1700000000000\",\"time_unit\":\"unix_milliseconds\",\"semantics\":\"external bytes observed at attachment capture time\",\"count\":4,\"chunks\":1,\"sha256\":\"c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4\",\"commitment\":\"db529340a7eeea0d6f3c568e8ecf9e2ff922f394a50856e101e5f017225bef46\"}"

def wire(receipt: String,count: String,sha: String,hex: String) -> String:
  "{\"kind\":\"attachment_preview_external\",\"version\":1,\"receipt\":" ++ receipt ++
    ",\"byte_count\":" ++ count ++ ",\"byte_sha256\":\"" ++ sha ++ "\",\"hex\":\"" ++ hex ++ "\"}"

def fixture() -> String: wire(receipt_wire(),"4",binary_sha(),"0001feff")

def parsed(result: Result<&2,&2,String,J.Json>) -> J.Json:
  match result:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def json(text: String) -> J.Json: parsed(J.parse(text))

def fields(values: List<&2,J.Field>,+name: String,+replacement: J.Json) -> List<&2,J.Field>:
  match values:
    case []: []
    case J.JField{+key,value} <> rest:
      J.JField{key,Bool.pick(J.Json,String.eq(key,name),replacement,value)} <> fields(rest,name,replacement)

def replace(value: J.Json,name: String,replacement: J.Json) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{fields(values,name,replacement)}
    case _: J.JNull{}

def add(value: J.Json,name: String,field: J.Json) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{J.JField{name,field} <> values}
    case _: J.JNull{}

def remove_fields(values: List<&2,J.Field>,+name: String) -> List<&2,J.Field>:
  match values:
    case []: []
    case J.JField{+key,value} <> rest:
      List.append(&2,J.Field,Bool.pick(List<&2,J.Field>,String.eq(key,name),[],[J.JField{key,value}]),remove_fields(rest,name))

def remove(value: J.Json,name: String) -> J.Json:
  match value:
    case J.JObject{values}: J.JObject{remove_fields(values,name)}
    case _: J.JNull{}

def rejected(result: Result<&2,&2,String,D.Bytes>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def failed(result: Result<&2,&2,String,D.Bytes>,expected: String) -> Bool:
  match result:
    case Fail{value}: String.eq(value,expected)
    case Done{_}: False{}

def good(result: Result<&2,&2,String,D.Bytes>,bytes: List<&2,U32>,count: U32,digest: String) -> Bool:
  match result:
    case Done{D.Bytes{actual,n,sha}}: Domain.bytes_equal(actual,bytes) && U32.is_eq(n,count) && String.eq(sha,digest)
    case Fail{_}: False{}

def bad_json(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Done{text}: rejected(E.verify(expected(0),text))
    case Fail{_}: False{}

def wrong(value: J.Json) -> Bool: bad_json(J.encode_checked(value))
def changed(name: String,value: J.Json) -> Bool: wrong(replace(json(fixture()),name,value))

def receipt_good(result: Result<&2,&2,String,T.Receipt>,expected: T.Receipt) -> Bool:
  match result:
    case Done{value}: E.same_receipt(value,expected)
    case Fail{_}: False{}

def other_receipts(indices: List<&2,U32>) -> IO(Unit):
  match indices:
    case []: IO.pure(Unit,Unit{})
    case +index <> rest:
      do IO<Unit>:
        check(T.receipt_valid(fixture_receipt(index)) && receipt_good(Ack.receipt(json(Output.receipt(fixture_receipt(index)))),fixture_receipt(index)),"independent changed receipt remains valid " ++ U32.show(index))
        check(failed(E.verify(expected(0),wire(Output.receipt(fixture_receipt(index)),"4",binary_sha(),"0001feff")),"external_preview_receipt_mismatch"),"valid changed full receipt cannot replace expected identity " ++ U32.show(index))
        other_receipts(rest)

def missing(names: List<&2,String>) -> IO(Unit):
  match names:
    case []: IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        check(wrong(remove(json(fixture()),name)),"missing external packet field " ++ name)
        missing(rest)

def bad_hex(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case +value <> rest:
      do IO<Unit>:
        check(changed("hex",J.JString{value}),"invalid external payload hex " ++ J.quote(value))
        bad_hex(rest)

def bad_request(request: I.Request) -> Bool:
  failed(E.verify(E.External{request,fixture_receipt(0)},fixture()),"external_preview_invalid_expected")

def with_seal(value: T.Receipt,seal: String) -> T.Receipt:
  T.Receipt{occurrence,root,time,count,chunks,digest,_} = value
  T.Receipt{occurrence,root,time,count,chunks,digest,seal}

def contracts() -> IO(Unit):
  do IO<Unit>:
    check(E.expected_valid(expected(0)) && U32.is_eq(E.count(expected(0)),4) && E.same_request(E.request(expected(0)),I.Request{"7",1,2,"/message/content/2/source"}) && E.same_receipt(E.receipt(expected(0)),fixture_receipt(0)),"external helpers preserve exact independent expected receipt and request")
    check(receipt_good(Ack.receipt(json(receipt_wire())),fixture_receipt(0)),"independent literal receipt agrees with strict shared codec")
    check(good(E.verify(expected(0),fixture()),[0,1,254,255],4,binary_sha()),"independent external binary packet retains nonUTF8 bytes")
    check(T.receipt_valid(fixture_receipt(9)) && good(E.verify(expected(9),wire(Output.receipt(fixture_receipt(9)),"0",empty_sha(),"")),[],0,empty_sha()),"independently sealed empty receipt retains exact zero-byte observation")
    check(rejected(E.verify(expected(0),fixture() ++ "{}")),"trailing packet JSON rejected")
    check(wrong(add(json(fixture()),"source_path",J.JString{"/must/not/open"})),"unknown source authority field rejected")
    check(wrong(add(json(fixture()),"receipt",json(receipt_wire()))),"duplicate receipt field rejected")
    check(changed("kind",J.JString{"attachment_preview"}),"inline packet kind cannot masquerade as external observation")
    check(changed("version",J.JString{"1"}) && changed("version",J.JNumber{"1.0"}) && changed("version",J.JNumber{"2"}),"version requires exact typed canonical value")
    missing(["kind","version","receipt","byte_count","byte_sha256","hex"])
    other_receipts([1,2,3,4,5,6,7,8,11])
    check(bad_request(I.Request{"8",1,2,"/message/content/2/source"}) && bad_request(I.Request{"07",1,2,"/message/content/2/source"}),"different or noncanonical request snapshot rejected")
    check(bad_request(I.Request{"7",0,2,"/message/content/2/source"}) && bad_request(I.Request{"7",1,1,"/message/content/2/source"}),"request record and reference bind receipt")
    check(bad_request(I.Request{"7",1,2,"/message/content/1/source"}) && bad_request(I.Request{"7",1,64,"/message/content/2/source"}),"request structural path and reference bounds enforced")
    check(failed(E.verify(E.External{E.request(expected(0)),with_seal(fixture_receipt(0),binary_sha())},fixture()),"external_preview_invalid_expected"),"invalid expected receipt commitment rejected before packet admission")
    check(changed("receipt",replace(json(receipt_wire()),"commitment",J.JString{binary_sha()})),"altered received receipt commitment rejected")
    check(changed("receipt",add(json(receipt_wire()),"extra",J.JBool{True{}})),"unknown receipt field rejected by shared decoder")
    check(changed("receipt",replace(json(receipt_wire()),"count",J.JString{"4"})),"receipt numeric spelling and types remain strict")

def malformed() -> IO(Unit):
  do IO<Unit>:
    bad_hex(["","0001fef","0001feff00","0001FEFF","0001feFf","0x01feff","0001fe-f","0001fe f","0001fegg","0001féff"])
    check(changed("hex",J.JNull{}),"external hex must be a string")
    check(changed("hex",J.JString{"0001fefe"}),"same length altered bytes fail SHA256")
    check(changed("byte_count",J.JNumber{"5"}) && changed("byte_count",J.JString{"4"}) && changed("byte_count",J.JNumber{"4.0"}),"exact typed byte count binds independently sealed receipt")
    check(changed("byte_sha256",J.JString{empty_sha()}),"payload digest must equal expected receipt digest")
    check(changed("byte_sha256",J.JString{"C5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"}),"uppercase byte digest rejected")
    check(failed(E.verify(expected(0),repeat(65536n," ") ++ fixture()),"external_preview_packet_limit"),"oversized external header refused before JSON parsing")
    check(failed(E.verify(expected(0),repeat(22000n,"中") ++ fixture()),"external_preview_packet_limit"),"external packet budget counts UTF8 octets")

def owned() -> T.Owned:
  T.Owned{fixture_receipt(0),[T.Chunk{0,0,4,binary_sha(),[0,1,254,255]}]}

def encoded(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Done{+text}: String.eq(text,fixture()) && good(E.verify(expected(0),text),[0,1,254,255],4,binary_sha())
    case Fail{_}: False{}

def encode_failed(result: Result<&2,&2,String,String>,wanted: String) -> Bool:
  match result:
    case Fail{message}: String.eq(message,wanted)
    case Done{_}: False{}

def empty_encoded(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Done{text}: good(E.verify(expected(9),text),[],0,empty_sha())
    case Fail{_}: False{}

def producing() -> IO(Unit):
  do IO<Unit>:
    check(encoded(E.encode(expected(0),owned())),"owned binary encoder matches independent six-field literal")
    check(empty_encoded(E.encode(expected(9),T.Owned{fixture_receipt(9),[]})),"empty owned observation serializes without fake chunk")
    check(encode_failed(E.encode(expected(0),T.Owned{fixture_receipt(1),[T.Chunk{0,0,4,binary_sha(),[0,1,254,255]}]}),"external_preview_receipt_mismatch"),"producer refuses valid bytes from a different historical root receipt")
    check(encode_failed(E.encode(expected(0),T.Owned{fixture_receipt(0),[T.Chunk{0,0,4,binary_sha(),[0,1,254,256]}]}),"external_preview_invalid_owned_bytes"),"producer refuses nonoctet owned chunk")
    check(encode_failed(E.encode(expected(0),T.Owned{fixture_receipt(0),[T.Chunk{0,0,4,binary_sha(),[0,1,254]}]}),"external_preview_invalid_owned_bytes"),"producer refuses truncated owned bytes")
    check(encode_failed(E.encode(expected(0),T.Owned{fixture_receipt(0),[T.Chunk{0,0,4,empty_sha(),[0,1,254,255]}]}),"external_preview_invalid_owned_bytes"),"producer refuses chunk checksum mismatch")
    check(encode_failed(E.encode(expected(0),T.Owned{fixture_receipt(0),[T.Chunk{0,1,4,binary_sha(),[0,1,254,255]}]}),"external_preview_invalid_owned_bytes"),"producer refuses noncontiguous owned chunk")
    check(encode_failed(E.encode(expected(0),T.Owned{fixture_receipt(0),[T.Chunk{1,0,4,binary_sha(),[0,1,254,255]}]}),"external_preview_invalid_owned_bytes"),"producer refuses wrong owned chunk ordinal")
    check(E.expected_valid(expected(10)),"independently sealed large escaped metadata is otherwise valid")
    check(encode_failed(E.encode(expected(10),T.Owned{fixture_receipt(10),[]}),"external_preview_metadata_limit"),"producer refuses oversized escaped receipt without truncating metadata")

def main() -> IO(Unit):
  do IO<Unit>:
    contracts()
    malformed()
    producing()
    IO.print("External retained preview packet tests passed")
