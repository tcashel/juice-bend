import Base
import ../../src/zstd/stream.bend as Stream
import ../../src/zstd/frame.bend as Frame
import ../../src/zstd/output.bend as Output
import ../../src/zstd/bytes.bend as Bytes
import ../../src/zstd/pair.bend as DataPair
import ../../src/zstd/huffman.bend as Huffman
import ../../src/domain.bend as Domain
import ./frame_vectors.bend as Vectors
import ./multiblock_vectors.bend as Multi
import ./block_tests.bend as BlockTests
import ./frame_tests.bend as FrameTests
import ./bits_tests.bend as Test

type Stats is Data:
  Stats{chunks: U32,request: U32,output: U32}

type Observed is Data:
  Observed{summary: Stream.Summary,stats: Stats}

def limits() -> Frame.Limits: Frame.Limits{67108864,268435456,8388608,64,4096}

def unpack_step(-R: Type,step: Stream.Step,next: Stream.State -> List<&2,U32> -> R) -> R:
  Stream.Step{state,raw} = step
  next(state,raw)

def prefix(raw: List<&2,U32>,expected: List<&2,U32>) -> Result<&2,&2,String,List<&2,U32>>:
  match raw expected:
    case Nil{} rest: Done{rest}
    case Con{_,_} Nil{}: Fail{"stream emitted extra output"}
    case Con{a,tail} Con{b,rest}:
      do Result<&2,&2,String,List<&2,U32>>:
        _ : Unit <- Huffman.require(U32.is_eq(a,b),"stream output byte differs")
        prefix(tail,rest)

def compare(expected: Maybe<&2,List<&2,U32>>,raw: List<&2,U32>) -> Result<&2,&2,String,Maybe<&2,List<&2,U32>>>:
  match expected:
    case None{}: Done{None{}}
    case Some{bytes}:
      do Result<&2,&2,String,Maybe<&2,List<&2,U32>>>:
        rest : List<&2,U32> <- prefix(raw,bytes)
        Done{Some{rest}}

def ended(expected: Maybe<&2,List<&2,U32>>) -> Bool:
  match expected:
    case None{}: True{}
    case Some{bytes}: List.is_empty(&2,U32,bytes)

def stats(stats: Stats,request: U32,+output: U32) -> Stats:
  Stats{chunks,maximum_request,maximum_output} = stats
  Stats{U32.add(chunks,1),U32.max(maximum_request,request),U32.max(maximum_output,output)}

def drive(fuel: Nat,state: Stream.State,bytes: List<&2,U32>,expected: Maybe<&2,List<&2,U32>>,seen: Stats) ->
  Result<&2,&1,String,Observed>:
  match fuel bytes:
    case _ Nil{}:
      do Result<&2,&1,String,Observed>:
        summary : Stream.Summary <- Output.widen(Stream.Summary,Stream.finish(state))
        _ : Unit <- Output.widen(Unit,Huffman.require(ended(expected),"stream omitted expected output"))
        Done{Observed{summary,seen}}
    case 0n Con{_,_}: Fail{"test stream exhausted progress fuel"}
    case 1n+rest remaining:
      Output.unpack(Stream.State,U32,Result<&2,&1,String,Observed>,Stream.request(state),
        next => count => do Result<&2,&1,String,Observed>:
          +requested : U32 = count
          +parts : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Output.widen(DataPair.Duo(List<&2,U32>,List<&2,U32>),Bytes.take(remaining,requested))
          part : List<&2,U32> = DataPair.first(List<&2,U32>,List<&2,U32>,parts)
          tail : List<&2,U32> = DataPair.second(List<&2,U32>,List<&2,U32>,parts)
          step : Stream.Step <- Stream.push(next,part)
          unpack_step(Result<&2,&1,String,Observed>,step,
            after => raw => do Result<&2,&1,String,Observed>:
              +saved : List<&2,U32> = raw
              +length : U32 = U32.from_nat(List.length(&2,U32,saved))
              _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_gt(requested,0) && U32.is_le(requested,131072) && U32.is_le(length,131072),
                "stream request or output exceeds bounded block"))
              next_expected : Maybe<&2,List<&2,U32>> <- Output.widen(Maybe<&2,List<&2,U32>>,compare(expected,saved))
              drive(rest,after,tail,next_expected,stats(seen,requested,length))))

def decode(+bytes: List<&2,U32>,expected: Maybe<&2,List<&2,U32>>,bound: Frame.Limits) -> Result<&2,&1,String,Observed>:
  do Result<&2,&1,String,Observed>:
    initial : Stream.State <- Stream.begin(bound)
    drive(Nat.add(List.length(&2,U32,bytes),1n),initial,bytes,expected,Stats{0,0,0})

def checked(result: Result<&2,&1,String,Observed>,input: U32,output: U32,frames: U32,label: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ error)
    case Done{Observed{Stream.Summary{actual_input,actual_output,actual_frames},_}}:
      Test.require(U32.is_eq(input,actual_input) && U32.is_eq(output,actual_output) && U32.is_eq(frames,actual_frames),label)

def check_bound(+bytes: List<&2,U32>,+expected: List<&2,U32>,bound: Frame.Limits,frames: U32,label: String) -> IO(Unit):
  checked(decode(bytes,Some{expected},bound),U32.from_nat(List.length(&2,U32,bytes)),
    U32.from_nat(List.length(&2,U32,expected)),frames,label)

def check(bytes: List<&2,U32>,expected: List<&2,U32>,frames: U32,label: String) -> IO(Unit):
  check_bound(bytes,expected,limits(),frames,label)

def run(bytes: List<&2,U32>,expected: String,label: String) -> IO(Unit):
  check(bytes,Domain.encode(expected),1,label)

def failed(result: Result<&2,&1,String,Observed>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def rejects(bytes: List<&2,U32>) -> Bool:
  failed(decode(bytes,None{},limits()))

def prefixes(bytes: List<&2,U32>,+prefix: List<&2,U32>) -> Bool:
  match bytes:
    case Nil{}: True{}
    case Con{byte,tail}:
      rejects(prefix) && prefixes(tail,List.append(&2,U32,prefix,[byte]))

def finish_failed(result: Result<&2,&2,String,Stream.Summary>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def push_failed(result: Result<&2,&1,String,Stream.Step>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def request_rejected(bytes: List<&2,U32>) -> Result<&2,&1,String,Bool>:
  do Result<&2,&1,String,Bool>:
    state : Stream.State <- Stream.begin(limits())
    Done{push_failed(Stream.push(state,bytes))}

def require_result(result: Result<&2,&1,String,Bool>,label: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ error)
    case Done{ok}: Test.require(ok,label)

# Generate a 4,456,448-byte unknown-size frame one RLE block at a time. There
# is no list holding the full compressed or logical stream in this test.
def rle_header(last: Bool) -> List<&2,U32>:
  match last:
    case True{}: [3,0,16]
    case False{}: [2,0,16]

def repeated_byte(fuel: Nat,bytes: List<&2,U32>) -> Bool:
  match fuel bytes:
    case 0n Nil{}: True{}
    case 1n+rest Con{byte,tail}: U32.is_eq(byte,65) && repeated_byte(rest,tail)
    case _ _: False{}

def silent(result: Result<&2,&1,String,Stream.Step>) -> Result<&2,&1,String,Stream.State>:
  match result:
    case Fail{error}: Fail{error}
    case Done{Stream.Step{state,raw}}:
      do Result<&2,&1,String,Stream.State>:
        _ : Unit <- Output.widen(Unit,Huffman.require(List.is_empty(&2,U32,raw),"unexpected output before block body"))
        Done{state}

def unknown(bound: Frame.Limits,descriptor_byte: U32) -> Result<&2,&1,String,Stream.State>:
  do Result<&2,&1,String,Stream.State>:
    state : Stream.State <- Stream.begin(bound)
    descriptor : Stream.State <- silent(Stream.push(state,[40,181,47,253]))
    header : Stream.State <- silent(Stream.push(descriptor,[descriptor_byte]))
    silent(Stream.push(header,[0]))

def checksum_after_output(step: Stream.Step) -> Result<&2,&1,String,Bool>:
  Stream.Step{state,raw} = step
  do Result<&2,&1,String,Bool>:
    _ : Unit <- Output.widen(Unit,Huffman.require(Domain.bytes_equal(raw,[65]),"checksum case did not emit expected earlier output"))
    Done{push_failed(Stream.push(state,[0,0,0,0]))}

def checksum_late() -> Result<&2,&1,String,Bool>:
  do Result<&2,&1,String,Bool>:
    state : Stream.State <- unknown(limits(),4)
    body : Stream.State <- silent(Stream.push(state,[9,0,0]))
    step : Stream.Step <- Stream.push(body,[65])
    checksum_after_output(step)

def budget_after_output(step: Stream.Step) -> Result<&2,&1,String,Bool>:
  Stream.Step{state,raw} = step
  do Result<&2,&1,String,Bool>:
    _ : Unit <- Output.widen(Unit,Huffman.require(Domain.bytes_equal(raw,[65]),"budget case did not emit expected earlier output"))
    body : Stream.State <- silent(Stream.push(state,[9,0,0]))
    Done{push_failed(Stream.push(body,[66]))}

def budget_late() -> Result<&2,&1,String,Bool>:
  do Result<&2,&1,String,Bool>:
    state : Stream.State <- unknown(Frame.Limits{1048576,1,8388608,4,4},0)
    body : Stream.State <- silent(Stream.push(state,[8,0,0]))
    step : Stream.Step <- Stream.push(body,[65])
    budget_after_output(step)

def large_blocks(fuel: Nat,state: Stream.State,left: U32) -> Result<&2,&1,String,Stream.Summary>:
  match fuel:
    case 0n: Output.widen(Stream.Summary,Stream.finish(state))
    case 1n+rest:
      do Result<&2,&1,String,Stream.Summary>:
        +remaining : U32 = left
        body : Stream.State <- silent(Stream.push(state,rle_header(U32.is_eq(remaining,1))))
        step : Stream.Step <- Stream.push(body,[65])
        unpack_step(Result<&2,&1,String,Stream.Summary>,step,
          next => raw => do Result<&2,&1,String,Stream.Summary>:
            _ : Unit <- Output.widen(Unit,Huffman.require(repeated_byte(131072n,raw),"large streaming RLE block differs"))
            large_blocks(rest,next,U32.sub(remaining,1)))

def large() -> Result<&2,&1,String,Stream.Summary>:
  do Result<&2,&1,String,Stream.Summary>:
    state : Stream.State <- Stream.begin(limits())
    descriptor : Stream.State <- silent(Stream.push(state,[40,181,47,253]))
    header : Stream.State <- silent(Stream.push(descriptor,[0]))
    blocks : Stream.State <- silent(Stream.push(header,[56]))
    large_blocks(34n,blocks,34)

def large_checked(result: Result<&2,&1,String,Stream.Summary>) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,1,"FAIL bounded streaming output above 4 MiB: " ++ error)
    case Done{Stream.Summary{input,output,frames}}:
      Test.require(U32.is_eq(input,142) && U32.is_eq(output,4456448) && U32.is_eq(frames,1),
        "bounded streaming output above 4 MiB without whole input or output accumulation")

def main() -> IO(Unit):
  do IO<Unit>:
    run(Vectors.empty(),"","stream empty ordinary frame")
    run(Vectors.empty_check(),"","stream empty checksummed frame")
    run(Vectors.hello(),"hello archive\n","stream raw frame")
    run(Vectors.hello_check(),"hello archive\n","stream raw checksummed frame")
    run(Vectors.overlap(),BlockTests.repeated(400n,"abcde"),"stream compressed overlapping matches")
    run(Vectors.overlap_check(),BlockTests.repeated(400n,"abcde"),"stream checksummed overlapping matches")
    run(Vectors.jsonl(),BlockTests.records(100n,0),"stream ordinary Huffman and FSE JSONL")
    run(Vectors.jsonl_check(),BlockTests.records(100n,0),"stream checksummed compressed JSONL")
    run(Vectors.unicode(),BlockTests.repeated(300n,"café 中文 🙂\tA\0B\r\n"),"stream exact Unicode NUL CRLF")
    run(Vectors.unicode_check(),BlockTests.repeated(300n,"café 中文 🙂\tA\0B\r\n"),"stream checksummed Unicode NUL CRLF")
    run(Multi.records(),BlockTests.records(2000n,0),"stream repeated Huffman FSE and LZ state across five blocks")
    run(Multi.records_check(),BlockTests.records(2000n,0),"stream checksum across five compressed blocks")
    run(Multi.records_raw_bridge(),BlockTests.records(2000n,0),"stream raw bridge retains entropy and LZ state")
    run([40,181,47,253,32,5,43,0,0,65],"AAAAA","stream RLE frame")
    run([40,181,47,253,32,0,3,0,0,65],"","stream zero-length RLE consumes stored byte")
    run([40,181,47,253,0,0,25,0,0,65,66,67],"ABC","stream unknown content size")
    check([40,181,47,253,32,3,25,0,0,0,255,10],[0,255,10],1,"stream exact non-UTF8 raw bytes")
    check(List.append(&2,U32,Vectors.hello_check(),Vectors.overlap_check()),
      Domain.encode("hello archive\n" ++ BlockTests.repeated(400n,"abcde")),2,"stream concatenated checksummed frames")
    check(List.append(&2,U32,[80,42,77,24,3,0,0,0,1,255,0],Vectors.hello_check()),
      Domain.encode("hello archive\n"),2,"stream skippable frame")
    check([95,42,77,24,0,0,0,0],[],1,"stream empty skippable source")
    check(List.append(&2,U32,[80,42,77,24,1,0,1,0],Bytes.repeat(65537n,0,[])),[],1,
      "stream skippable payload split into at most 65536-byte requests")
    Test.require(rejects(FrameTests.corrupt_last(Vectors.jsonl_check())),"stream wrong checksum rejected after emitted output")
    Test.require(rejects(List.append(&2,U32,Vectors.hello(),[0,0,0,0])),"stream bad trailing frame rejects prior provisional output")
    Test.require(rejects(List.append(&2,U32,Vectors.hello(),[40])) &&
      rejects(List.append(&2,U32,Vectors.hello(),[40,181])) &&
      rejects(List.append(&2,U32,Vectors.hello(),[40,181,47])),"stream partial trailing magic rejects complete earlier frame")
    Test.require(rejects([40,181,47,253,1,0,1,1,0,0]),"stream required dictionary rejected")
    Test.require(rejects([40,181,47,253,0,112,1,0,0]),"stream oversized window rejected")
    Test.require(rejects([40,181,47,253,40,0,1,0,0]),"stream reserved descriptor bit rejected")
    Test.require(rejects([40,181,47,253,32,0,7,0,0]),"stream reserved block type rejected")
    Test.require(rejects([40,181,47,253,32,4,25,0,0,65,66,67]),"stream content size lie rejected")
    Test.require(rejects([40,181,47,253,192,0,0,0,0,0,1,0,0,0]),"stream 64-bit content size outside supported output rejected")
    Test.require(failed(decode(Vectors.jsonl(),None{},Frame.Limits{1048576,16000,8388608,32,64})),"stream global output cap")
    Test.require(failed(decode(Vectors.jsonl(),None{},Frame.Limits{100,1048576,8388608,32,64})),"stream input cap")
    Test.require(failed(decode(List.append(&2,U32,Vectors.hello(),Vectors.hello()),None{},Frame.Limits{1048576,1048576,8388608,1,64})),"stream frame count cap")
    Test.require(failed(decode(List.append(&2,U32,Vectors.hello(),Vectors.hello()),None{},Frame.Limits{1048576,20,8388608,4,64})),
      "stream output budget is shared across concatenated frames")
    Test.require(failed(decode([80,42,77,24,0,0,0,0,80,42,77,24,0,0,0,0],None{},Frame.Limits{1048576,1048576,8388608,1,64})),
      "stream skippable frames count against shared frame cap")
    Test.require(failed(decode(Multi.records(),None{},Frame.Limits{1048576,1048576,8388608,32,4})),"stream per-frame block count cap")
    check_bound(List.append(&2,U32,Multi.records(),Multi.records()),
      Domain.encode(BlockTests.records(2000n,0) ++ BlockTests.records(2000n,0)),
      Frame.Limits{1048576,1048576,8388608,2,5},2,"stream block count resets for each concatenated frame")
    Test.require(rejects([80,42,77,24,255,255,255,255]),"stream oversized skip rejected before payload")
    Test.require(rejects([]) && rejects([40,181,47]),"stream empty and truncated input rejected")
    Test.require(rejects([256,0,0,0]) && rejects([0,0,0,0]),"stream non-octet and bad magic rejected")
    Test.require(prefixes(Vectors.hello_check(),[]) && prefixes(Vectors.overlap_check(),[]),"stream every truncated raw and compressed prefix rejected")
    require_result(request_rejected([40,181,47]),"stream rejects fewer than requested bytes")
    require_result(request_rejected([40,181,47,253,0]),"stream rejects more than requested bytes")
    require_result(checksum_late(),"stream observes emitted output before refusing wrong checksum")
    require_result(budget_late(),"stream unknown-size frame refuses output budget after earlier emitted block")
    large_checked(large())
