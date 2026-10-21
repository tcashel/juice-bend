import Base
import ../../src/zstd/output.bend as Output
import ../../src/zstd/sequences.bend as Sequences
import ./bits_tests.bend as Test
import ../../src/domain.bend as Domain

def check(result: Result<&2,&1,String,Output.Sink & List<&2,U32>>,expected: String,count: U32,label: String) -> IO(Unit):
  match result:
    case Fail{error}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ error)
    case Done{(Output.Sink{_,_,_,actual_count,_,_},bytes)}:
      Test.require(Domain.bytes_equal(bytes,Domain.encode(expected)) && U32.is_eq(actual_count,count),label)

def wrapped(window: U32,initial: String,commands: List<&2,Sequences.Sequence>) -> Result<&2,&1,String,Output.Sink & List<&2,U32>>:
  do Result<&2,&1,String,Output.Sink & List<&2,U32>>:
    sink : Output.Sink <- Output.new(window,64)
    written : Output.Sink & List<&2,U32> <- Output.apply(Nil{},sink,Domain.encode(initial),32,Nil{})
    Output.unpack(Output.Sink,List<&2,U32>,Result<&2,&1,String,Output.Sink & List<&2,U32>>,written,
      next => unused => Output.apply(commands,next,Nil{},32,Nil{}))

def failed(result: Result<&2,&1,String,Output.Sink & List<&2,U32>>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def limited() -> Result<&2,&1,String,Output.Sink & List<&2,U32>>:
  do Result<&2,&1,String,Output.Sink & List<&2,U32>>:
    sink : Output.Sink <- Output.new(4,4)
    Output.apply([Sequences.Sequence{1,4,1}],sink,[65],5,Nil{})

def block_bound() -> Result<&2,&1,String,Output.Sink & List<&2,U32>>:
  do Result<&2,&1,String,Output.Sink & List<&2,U32>>:
    sink : Output.Sink <- Output.new(4,64)
    Output.apply([Sequences.Sequence{1,4,1}],sink,[65],4,Nil{})

def missing_literals() -> Result<&2,&1,String,Output.Sink & List<&2,U32>>:
  do Result<&2,&1,String,Output.Sink & List<&2,U32>>:
    sink : Output.Sink <- Output.new(4,64)
    Output.apply([Sequences.Sequence{2,3,1}],sink,[65],5,Nil{})

def main() -> IO(Unit):
  do IO<Unit>:
    check(wrapped(4,"abcdefghij",[Sequences.Sequence{0,9,3}]),"hijhijhij",19,"ring wrap and overlapping match across output blocks")
    check(wrapped(5,"abcdefghijkl",[Sequences.Sequence{0,12,5}]),"hijklhijklhi",24,"non-power-of-two window retains only allowed distances")
    check(wrapped(1,"ab",[Sequences.Sequence{0,8,1}]),"bbbbbbbb",10,"one-byte ring overlaps safely")
    Test.require(failed(wrapped(4,"abcd",[Sequences.Sequence{0,3,0}])),"zero match distance rejected")
    Test.require(failed(wrapped(4,"abcdef",[Sequences.Sequence{0,3,5}])),"match beyond retained window rejected")
    Test.require(failed(wrapped(8,"ab",[Sequences.Sequence{0,3,3}])),"match before frame start rejected")
    Test.require(failed(limited()),"output bound interrupts overlapping copy")
    Test.require(failed(block_bound()),"sequence aggregate exceeds block bound")
    Test.require(failed(missing_literals()),"sequence cannot consume missing literals")
