import Base
import ../../src/zstd/frame.bend as Frame
import ./frame_vectors.bend as Vectors
import ./block_tests.bend as BlockTests
import ./bits_tests.bend as Test
import ../../src/domain.bend as Domain

def limits() -> Frame.Limits: Frame.Limits{1048576,1048576,8388608,32,64}

def flatten(chunks: List<&2,List<&2,U32>>) -> List<&2,U32>:
  match chunks:
    case Nil{}: Nil{}
    case Con{chunk,tail}: List.append(&2,U32,chunk,flatten(tail))

def check(result: Result<&2,&2,String,List<&2,List<&2,U32>>>,expected: List<&2,U32>,label: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ error)
    case Done{chunks}: Test.require(Domain.bytes_equal(flatten(chunks),expected),label)

def run(bytes: List<&2,U32>,expected: String,label: String) -> IO(Unit):
  check(Frame.decode(bytes,limits()),Domain.encode(expected),label)

def failed(result: Result<&2,&2,String,List<&2,List<&2,U32>>>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def corrupt_last(bytes: List<&2,U32>) -> List<&2,U32>:
  match bytes:
    case Nil{}: Nil{}
    case Con{last,Nil{}}: Con{U32.xor(last,1),Nil{}}
    case Con{byte,tail}: Con{byte,corrupt_last(tail)}

def truncated_prefixes(bytes: List<&2,U32>,+prefix: List<&2,U32>) -> Bool:
  match bytes:
    case Nil{}: True{}
    case Con{byte,tail}:
      failed(Frame.decode(prefix,limits())) && truncated_prefixes(tail,List.append(&2,U32,prefix,[byte]))

def main() -> IO(Unit):
  do IO<Unit>:
    run(Vectors.empty(),"","empty frame")
    run(Vectors.empty_check(),"","empty checksummed frame")
    run(Vectors.hello(),"hello archive\n","raw frame")
    run(Vectors.hello_check(),"hello archive\n","raw checksummed frame")
    run(Vectors.overlap(),BlockTests.repeated(400n,"abcde"),"compressed overlapping matches")
    run(Vectors.overlap_check(),BlockTests.repeated(400n,"abcde"),"checksummed overlapping matches")
    run(Vectors.jsonl(),BlockTests.records(100n,0),"ordinary compressed JSONL with Huffman and FSE")
    run(Vectors.jsonl_check(),BlockTests.records(100n,0),"checksummed compressed JSONL")
    run(Vectors.unicode(),BlockTests.repeated(300n,"café 中文 🙂\tA\0B\r\n"),"compressed exact Unicode NUL CRLF bytes")
    run(Vectors.unicode_check(),BlockTests.repeated(300n,"café 中文 🙂\tA\0B\r\n"),"checksummed Unicode NUL CRLF bytes")
    run([40,181,47,253,32,5,43,0,0,65],"AAAAA","RLE frame and single-segment content size")
    run([40,181,47,253,32,0,3,0,0,65],"","zero-length RLE frame consumes its stored byte with an empty window")
    check(Frame.decode([40,181,47,253,32,3,25,0,0,0,255,10],limits()),[0,255,10],"raw frame retains nonUTF8 and embeddedNUL")
    run(List.append(&2,U32,Vectors.hello_check(),Vectors.overlap_check()),"hello archive\n" ++ BlockTests.repeated(400n,"abcde"),"concatenated checksummed frames preserve order")
    run(List.append(&2,U32,[80,42,77,24,3,0,0,0,1,255,0],Vectors.hello_check()),"hello archive\n","skippable frame ignored within explicit input bound")
    Test.require(failed(Frame.decode(corrupt_last(Vectors.jsonl_check()),limits())),"wrong content checksum rejected")
    Test.require(failed(Frame.decode([40,181,47,253,1,0,1,1,0,0],limits())),"required dictionary rejected explicitly")
    Test.require(failed(Frame.decode([40,181,47,253,0,112,1,0,0],limits())),"oversized window rejected before allocation")
    Test.require(failed(Frame.decode([40,181,47,253,40,0,1,0,0],limits())),"reserved frame descriptor bit rejected")
    Test.require(failed(Frame.decode([40,181,47,253,32,0,7,0,0],limits())),"reserved block type rejected")
    Test.require(failed(Frame.decode([40,181,47,253,32,4,25,0,0,65,66,67],limits())),"content size lie rejected")
    Test.require(failed(Frame.decode(Vectors.jsonl(),Frame.Limits{1048576,16000,8388608,32,64})),"output cap enforced during decoded growth")
    Test.require(failed(Frame.decode(Vectors.jsonl(),Frame.Limits{100,1048576,8388608,32,64})),"input cap enforced before decode")
    Test.require(failed(Frame.decode(List.append(&2,U32,Vectors.hello(),Vectors.hello()),Frame.Limits{1048576,1048576,8388608,1,64})),"concatenated frame limit enforced")
    Test.require(failed(Frame.decode([80,42,77,24,255,255,255,255],limits())),"oversized skippable payload rejected before Nat allocation")
    Test.require(failed(Frame.decode([],limits())) && failed(Frame.decode([40,181,47],limits())),"empty and truncated source rejected")
    Test.require(failed(Frame.decode([256],limits())) && failed(Frame.decode([0,0,0,0],limits())),"non-octet and unrecognized frame magic rejected")
    Test.require(truncated_prefixes(Vectors.hello_check(),Nil{}) && truncated_prefixes(Vectors.overlap_check(),Nil{}),"every truncated prefix of raw and compressed checksummed frames fails")
