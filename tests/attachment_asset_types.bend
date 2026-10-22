import Base
import ../src/attachment_asset_types.bend as T
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_worker_protocol.bend as W
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as D

# Pure assertions only: no database, provider, source, worker or filesystem IO.
# Byte vectors and metadata commitments below have independent SHA256 constants.
def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def empty_sha() -> String: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
def binary_sha() -> String: "c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"
def zeros_sha() -> String: "de2f256064a0af797747c2b97505dc0b9f3df0de4f489eac731c23ae9ca9cc31"
def ones_sha() -> String: "916b144867c340614f515c7b0e5415c74832d899c05264ded2a277a6e81d81ff"
def multi_sha() -> String: "1927430662b3943c63bddb87e79ee58fed9d8b3bdbd338f7d67b5263f3b190e3"
def maximum_sha() -> String: "30e14955ebf1352266dc2ff8067e68104607e750abb9d3b36582b8af909fcb58"
def raw_sha() -> String: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
def other_sha() -> String: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

def strings(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case x <> xs y <> ys: String.eq(x,y) && strings(xs,ys)
    case _ _: False{}

def changed(+index: U32,field: U32,original: String,replacement: String) -> String:
  Bool.pick(String,U32.is_eq(index,field),replacement,original)

def changed_number(+index: U32,field: U32,original: U32,replacement: U32) -> U32:
  Bool.pick(U32,U32.is_eq(index,field),replacement,original)

def capture(+index: U32) -> Meta.Header:
  Meta.Header{changed(index,0,"1","4"),changed(index,1,"2","4"),changed(index,2,"3","4"),
    changed(index,3,"claude","codex"),changed(index,4,"/synthetic/capture.jsonl","/synthetic/other.jsonl"),
    changed_number(index,5,200,201),changed_number(index,6,2,3),changed_number(index,7,100,101),
    changed_number(index,8,1,2),Bool.not(U32.is_eq(index,9)),changed(index,10,"identity","zstd-jsonl-v1")}

def reference(+index: U32) -> I.LocalReference:
  +value = changed(index,19,"/synthetic/photo 中文%20.png","/synthetic/photo 中文 .png")
  Bool.pick(I.LocalReference,U32.is_eq(index,18),I.LocalFileURL{value},I.LocalPath{value})

def identity(+index: U32) -> I.Resolved:
  I.Resolved{capture(index),changed_number(index,11,1,0),changed_number(index,12,100,101),
    changed_number(index,13,100,99),changed(index,14,raw_sha(),other_sha()),changed_number(index,15,2,3),
    changed(index,16,"/message/content/2/source/path","/message/content/3/source/path"),
    changed(index,17,"document","image"),reference(index)}

def root(+index: U32) -> T.RootEvidence:
  T.RootEvidence{changed(index,20,"7","8"),changed(index,21,"/synthetic/café","/synthetic/other"),
    changed(index,22,"9","10"),Bool.not(U32.is_eq(index,23))}

def receipt_variant(+index: U32) -> T.Receipt:
  T.Receipt{identity(index),root(index),changed(index,24,"1700000000000","1700000000001"),
    changed_number(index,25,4,5),changed_number(index,26,1,2),changed(index,27,binary_sha(),other_sha()),""}

def binary() -> W.Payload:
  W.Payload{4,binary_sha(),[0,1,254,255]}

def empty() -> W.Payload:
  W.Payload{0,empty_sha(),[]}

def admission(payload: W.Payload) -> T.Admission:
  T.Admission{identity(99),root(99),"1700000000000",payload}

def owned(+payload: W.Payload) -> T.Owned:
  T.Owned{T.receipt(admission(payload)),T.payload_chunks(payload)}

def invalid_times(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case +value <> rest:
      do IO<Unit>:
        assert(Bool.not(T.valid_time(value)),"noncanonical or out-of-range observed time refused")
        invalid_times(rest)

def invalid_paths(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        assert(Bool.not(T.root_valid(T.RootEvidence{"7",value,"9",True{}})),"noncanonical root spelling refused")
        invalid_paths(rest)

def repeat(fuel: Nat,+text: String) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: text ++ repeat(rest,text)

def time_root_tests() -> IO(Unit):
  do IO<Unit>:
    assert(T.valid_time("0") && T.valid_time("1") && T.valid_time("1700000000000") &&
      T.valid_time("9223372036854775807"),"time retains exact nonnegative signed64 decimal endpoints")
    invalid_times(["","00","01","-0","-1","+1","1.0","1e3"," 1","1 ","\t1","9223372036854775808","18446744073709551615"])
    assert(T.root_valid(root(99)) && T.root_valid(T.RootEvidence{"9223372036854775807","/synthetic/root","9223372036854775807",True{}}),"enabled canonical roots retain exact signed64 IDs and revision")
    assert(Bool.not(T.root_valid(root(23))) && Bool.not(T.root_valid(T.RootEvidence{"0","/synthetic/root","9",True{}})) &&
      Bool.not(T.root_valid(T.RootEvidence{"7","/synthetic/root","01",True{}})) &&
      Bool.not(T.root_valid(T.RootEvidence{"9223372036854775808","/synthetic/root","9",True{}})),"disabled and noncanonical root identities cannot authorize publication")
    invalid_paths(["","/","relative","//synthetic/root","/synthetic//root","/synthetic/./root","/synthetic/../root","/synthetic/root/","file:///synthetic/root","/synthetic/\0root"])
    assert(T.root_valid(T.RootEvidence{"7","/" ++ repeat(4095n,"a"),"9",True{}}) &&
      Bool.not(T.root_valid(T.RootEvidence{"7","/" ++ repeat(4096n,"a"),"9",True{}})) &&
      Bool.not(T.root_valid(T.RootEvidence{"7","/" ++ repeat(2048n,"é"),"9",True{}})),"root spelling enforces exact 4096 UTF8 byte bound")

def payload_tests() -> IO(Unit):
  do IO<Unit>:
    assert(T.payload_valid(empty()) && T.payload_valid(binary()),"empty and NUL/nonUTF8 binary payloads preserve independent byte digest")
    assert(Bool.not(T.payload_valid(W.Payload{3,binary_sha(),[0,1,254,255]})) &&
      Bool.not(T.payload_valid(W.Payload{5,binary_sha(),[0,1,254,255]})),"payload count must equal every actual octet")
    assert(Bool.not(T.payload_valid(W.Payload{4,other_sha(),[0,1,254,255]})) &&
      Bool.not(T.payload_valid(W.Payload{4,"invalid",[0,1,254,255]})),"payload digest must be canonical and recomputed from exact bytes")
    assert(Bool.not(T.payload_valid(W.Payload{1,D.digest([256]),[256]})) &&
      Bool.not(T.payload_valid(W.Payload{1,D.digest([4294967295]),[4294967295]})),"out-of-range octets fail even with a matching generated digest")
    assert(Bool.not(T.payload_valid(W.Payload{1048577,maximum_sha(),[]})) &&
      Bool.not(T.payload_valid(W.Payload{1048576,maximum_sha(),List.replicate(U32,1048577n,0)})),"declared and actual byte extents above1MiB are independently refused")
    assert(T.admission_valid(admission(binary())) &&
      Bool.not(T.admission_valid(T.Admission{identity(9),root(99),"1700000000000",binary()})) &&
      Bool.not(T.admission_valid(T.Admission{identity(99),root(23),"1700000000000",binary()})) &&
      Bool.not(T.admission_valid(T.Admission{identity(99),root(99),"01",binary()})),"admission requires complete occurrence enabled root canonical time and verified bytes")

def commitment_changes(fuel: Nat,+index: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        assert(Bool.not(String.eq(T.commitment(receipt_variant(99)),T.commitment(receipt_variant(index)))) &&
          Bool.not(T.same(receipt_variant(99),receipt_variant(index))),"commitment and metadata equality bind field " ++ U32.show(index))
        commitment_changes(rest,U32.inc(index))

def bad_seal(value: T.Receipt) -> T.Receipt:
  T.Receipt{occurrence,root,time,count,chunks,digest,_} = value
  T.Receipt{occurrence,root,time,count,chunks,digest,other_sha()}

def metadata_tests() -> IO(Unit):
  +expected : List<&2,String> = ["external-attachment-bytes-v1","external bytes observed at attachment capture time",
    "1","2","3","claude","/synthetic/capture.jsonl","200","2","100","1","true","identity","1","100","100",raw_sha(),"2",
    "/message/content/2/source/path","document","local_path","/synthetic/photo 中文%20.png","7","/synthetic/café","9","true",
    "1700000000000","unix_milliseconds","4","1",binary_sha(),"1048576","65536","16"]
  do IO<Unit>:
    assert(strings(T.fields(receipt_variant(99)),expected),"independent34-field oracle pins domain semantics complete occurrence root time sizes digest and limits")
    assert(String.eq(T.commitment(receipt_variant(99)),"ee4f500667697c9e6104c40f1af13d645bc12438e7f064bd7553c953b9c96fcc"),"metadata commitment matches independent UTF8 length-framed SHA256 constant")
    assert(String.eq(T.frames(["é","中文","\0"]),"2:é6:中文1:\0") &&
      Bool.not(String.eq(T.frames(["a","bc"]),T.frames(["ab","c"]))),"metadata framing uses UTF8 bytes and does not alias joined text")
    assert(String.starts_with(T.identity_text(identity(99)),"30:attachment-local-occurrence-v1") &&
      String.contains(T.identity_text(identity(99)),"30:/synthetic/photo 中文%20.png"),"identity text carries its own domain and exact Unicode field framing")
    assert(T.receipt_valid(T.receipt(admission(binary()))) && T.receipt_valid(T.receipt(admission(empty()))) &&
      T.same(T.receipt(admission(binary())),T.sealed(receipt_variant(99))),"receipt generation seals exact binary and empty metadata")
    assert(Bool.not(T.receipt_valid(bad_seal(T.receipt(admission(binary()))))) &&
      Bool.not(T.receipt_valid(T.sealed(receipt_variant(26)))),"wrong stored commitment or impossible chunk count is refused")
    commitment_changes(28n,0)

def all_bytes(bytes: List<&2,U32>,+expected: U32) -> Bool:
  match bytes:
    case []: True{}
    case byte <> rest: U32.is_eq(byte,expected) && all_bytes(rest,expected)

def binary_shape(chunks: List<&2,T.Chunk>) -> Bool:
  match chunks:
    case [T.Chunk{0,0,4,digest,bytes}]: String.eq(digest,binary_sha()) && D.bytes_equal(bytes,[0,1,254,255])
    case _: False{}

def multi() -> W.Payload:
  W.Payload{131076,multi_sha(),List.append(&2,U32,List.replicate(U32,65536n,0),List.append(&2,U32,List.replicate(U32,65536n,1),[0,1,254,255]))}

def multi_shape(chunks: List<&2,T.Chunk>) -> Bool:
  match chunks:
    case [T.Chunk{0,0,65536,d0,+b0},T.Chunk{1,65536,65536,d1,+b1},T.Chunk{2,131072,4,d2,b2}]:
      String.eq(d0,zeros_sha()) && Nat.is_eq(List.length(&2,U32,b0),65536n) && all_bytes(b0,0) &&
      String.eq(d1,ones_sha()) && Nat.is_eq(List.length(&2,U32,b1),65536n) && all_bytes(b1,1) &&
      String.eq(d2,binary_sha()) && D.bytes_equal(b2,[0,1,254,255])
    case _: False{}

def swapped(chunks: List<&2,T.Chunk>) -> List<&2,T.Chunk>:
  match chunks:
    case [T.Chunk{_,_,_,d0,b0},T.Chunk{_,_,_,d1,b1},last]:
      [T.Chunk{0,0,65536,d1,b1},T.Chunk{1,65536,65536,d0,b0},last]
    case _: []

def maximum_shape(chunks: List<&2,T.Chunk>,+ordinal: U32) -> Bool:
  match chunks:
    case []: U32.is_eq(ordinal,16)
    case T.Chunk{actual,offset,length,digest,+bytes} <> rest:
      U32.is_lt(ordinal,16) && U32.is_eq(actual,ordinal) && U32.is_eq(offset,U32.mul(ordinal,65536)) && U32.is_eq(length,65536) &&
      String.eq(digest,zeros_sha()) && Nat.is_eq(List.length(&2,U32,bytes),65536n) && all_bytes(bytes,0) && maximum_shape(rest,U32.inc(ordinal))

def corruption_tests() -> IO(Unit):
  +ok : T.Chunk = T.Chunk{0,0,4,binary_sha(),[0,1,254,255]}
  do IO<Unit>:
    assert(Bool.not(T.chunks_valid([],0,0,4)) &&
      Bool.not(T.chunks_valid([T.Chunk{0,0,0,empty_sha(),[]}],0,0,0)),"missing bytes and synthetic zero-length chunks cannot stand for an empty asset")
    assert(Bool.not(T.chunks_valid([T.Chunk{1,0,4,binary_sha(),[0,1,254,255]}],0,0,4)) &&
      Bool.not(T.chunks_valid([T.Chunk{0,1,4,binary_sha(),[0,1,254,255]}],0,0,4)),"chunk ordinal and offset must match exact contiguous position")
    assert(Bool.not(T.chunks_valid([T.Chunk{0,0,3,binary_sha(),[0,1,254,255]}],0,0,4)) &&
      Bool.not(T.chunks_valid([T.Chunk{0,0,4,binary_sha(),[0,1,254]}],0,0,4)),"chunk declared length and actual byte length must both match")
    assert(Bool.not(T.chunks_valid([T.Chunk{0,0,4,binary_sha(),[0,1,254,254]}],0,0,4)) &&
      Bool.not(T.chunks_valid([T.Chunk{0,0,4,other_sha(),[0,1,254,255]}],0,0,4)),"chunk byte corruption and changed digest are refused")
    assert(Bool.not(T.chunks_valid([T.Chunk{0,0,1,D.digest([256]),[256]}],0,0,1)) &&
      Bool.not(T.chunks_valid([ok,T.Chunk{1,4,1,D.digest([0]),[0]}],0,0,4)),"non-octet and trailing extra chunks are refused")
    assert(Bool.not(T.chunks_valid([T.Chunk{0,0,65537,other_sha(),List.replicate(U32,65537n,0)}],0,0,65537)),"a chunk cannot bypass the65536-byte bound")
    assert(Bool.not(T.owned_valid(T.Owned{T.sealed(T.Receipt{identity(99),root(99),"1700000000000",4,1,empty_sha(),""}),[ok]})),"valid metadata seal and valid individual chunk cannot replace the whole-byte digest")

def chunk_tests() -> IO(Unit):
  +many : W.Payload = multi()
  +chunks = T.payload_chunks(many)
  +reordered = swapped(chunks)
  do IO<Unit>:
    assert(U32.is_eq(T.chunk_count(0),0) && U32.is_eq(T.chunk_count(1),1) && U32.is_eq(T.chunk_count(65536),1) &&
      U32.is_eq(T.chunk_count(65537),2) && U32.is_eq(T.chunk_count(1048576),16),"independent chunk-count boundaries include empty and exact maximum")
    assert(List.is_empty(&2,T.Chunk,T.payload_chunks(empty())) && T.owned_valid(owned(empty())),"empty bytes produce zero chunks with independent SHA256empty")
    assert(binary_shape(T.payload_chunks(binary())) && T.owned_valid(owned(binary())),"binary split preserves NUL and nonUTF8 octets exactly")
    assert(T.payload_valid(many) && multi_shape(chunks) && T.owned_valid(T.Owned{T.receipt(admission(many)),chunks}),"three ordered chunks preserve independent lengths offsets bytes and whole SHA256")
    assert(Bool.not(T.chunks_valid(List.reverse(&2,T.Chunk,chunks),0,0,131076)),"reversing stored chunks violates exact ordinal order")
    assert(T.chunks_valid(reordered,0,0,131076) &&
      Bool.not(T.owned_valid(T.Owned{T.receipt(admission(many)),reordered})),"reordered bytes with repaired per-chunk metadata still fail whole-asset digest")
    corruption_tests()

def maximum_test() -> IO(Unit):
  +payload : W.Payload = W.Payload{1048576,maximum_sha(),List.replicate(U32,1048576n,0)}
  +chunks = T.payload_chunks(payload)
  do IO<Unit>:
    assert(T.payload_valid(payload),"exact 1MiB payload admits independently known zero-byte SHA256")
    assert(maximum_shape(chunks,0) && T.owned_valid(T.Owned{T.receipt(admission(payload)),chunks}),"exact maximum splits into16 complete verified chunks without truncation")

def main() -> IO(Unit):
  do IO<Unit>:
    time_root_tests()
    payload_tests()
    metadata_tests()
    chunk_tests()
    maximum_test()
