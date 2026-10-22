import Base
import ../../src/zstd/pair.bend as DataPair
import ../../src/zstd/block.bend as Block
import ../../src/zstd/output.bend as Output
import ./block_vectors.bend as Vectors
import ../../src/zstd/sequences.bend as Sequences
import ./huffman_tests.bend as HuffmanTests
import ./bits_tests.bend as Test
import ../../src/domain.bend as Domain

def repeated(fuel: Nat,+value: String) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: value ++ repeated(rest,value)

def role(user: Bool) -> String:
  match user:
    case True{}: "user"
    case False{}: "assistant"

def records(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest:
      +r = role(U32.is_eq(U32.mod(index,3),0))
      "{\"type\":\"" ++ r ++ "\",\"sessionId\":\"synthetic-zstd\",\"message\":{\"role\":\"" ++ r ++ "\",\"content\":\"Archive record " ++ U32.show(index) ++ ": keep exact cafe and code path src/" ++ U32.show(U32.mod(index,7)) ++ ".bend; value=" ++ U32.show(U32.mul(index,index)) ++ "\"}}\n" ++ records(rest,U32.add(index,1))

def decoded(result: Result<&2,&1,String,(Block.State & Output.Sink) & List<&2,U32>>,expected: List<&2,U32>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,1,"FAIL compressed block: " ++ error)
    case Done{((_,_),actual)}: Test.require(Domain.bytes_equal(actual,expected),"compressed block equals independent complete raw bytes")

def decode_with(sink: Result<&2,&1,String,Output.Sink>,bytes: List<&2,U32>,expected: List<&2,U32>) -> IO(Unit):
  match sink:
    case Fail{error}: IO.die(Unit,1,error)
    case Done{output}: decoded(Block.compressed(bytes,Block.initial(),output,131072),expected)

def run(bytes: List<&2,U32>,expected: String) -> IO(Unit):
  decode_with(Output.new(8388608,65536),bytes,Domain.encode(expected))

def offsets(result: Result<&2,&2,String,DataPair.Duo(U32,Sequences.Offsets)>,expected: U32,a: U32,b: U32,c: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{(actual,Sequences.Offsets{x,y,z})}: U32.is_eq(actual,expected) && U32.is_eq(x,a) && U32.is_eq(y,b) && U32.is_eq(z,c)

def failed_offset(result: Result<&2,&2,String,DataPair.Duo(U32,Sequences.Offsets)>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    run(Vectors.overlap(),repeated(400n,"abcde"))
    run(Vectors.jsonl(),records(100n,0))
    run(Vectors.unicode(),repeated(300n,"café 中文 🙂\tA\0B\r\n"))
    Test.require(offsets(Sequences.repeated(1,Sequences.Offsets{10,20,30},False{}),10,10,20,30),"repeat1 retains history")
    Test.require(offsets(Sequences.repeated(1,Sequences.Offsets{10,20,30},True{}),20,20,10,30),"empty literals shifts repeat1 to repeat2")
    Test.require(offsets(Sequences.repeated(2,Sequences.Offsets{10,20,30},False{}),20,20,10,30),"repeat2 swaps recent offsets")
    Test.require(offsets(Sequences.repeated(2,Sequences.Offsets{10,20,30},True{}),30,30,10,20),"empty literals shifts repeat2 to repeat3")
    Test.require(offsets(Sequences.repeated(3,Sequences.Offsets{10,20,30},False{}),30,30,10,20),"repeat3 rotates history")
    Test.require(offsets(Sequences.repeated(3,Sequences.Offsets{10,20,30},True{}),9,9,10,20),"empty literals repeat3 inserts recent minus one")
    Test.require(offsets(Sequences.repeated(12,Sequences.Offsets{10,20,30},False{}),9,9,10,20),"explicit distance shifts history even when previously present")
    Test.require(failed_offset(Sequences.repeated(3,Sequences.Offsets{1,4,8},True{})) && failed_offset(Sequences.repeated(0,Sequences.Offsets{1,4,8},False{})),"zero repeat and explicit offsets fail")
