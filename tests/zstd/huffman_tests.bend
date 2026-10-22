import Base
import ../../src/zstd/pair.bend as DataPair
import ../../src/zstd/huffman.bend as Huffman
import ./bits_tests.bend as BitsTests

def same(left: List<&2,U32>,right: List<&2,U32>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Con{a,as} Con{b,bs}: U32.is_eq(a,b) && same(as,bs)
    case _ _: False{}

def bytes_are(result: Result<&2,&2,String,List<&2,U32>>,expected: List<&2,U32>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{actual}: same(actual,expected)

def tree_failed(result: Result<&2,&2,String,Huffman.Tree>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def bytes_failed(result: Result<&2,&2,String,List<&2,U32>>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def decode(result: Result<&2,&2,String,Huffman.Tree>,stream: List<&2,U32>,count: U32,expected: List<&2,U32>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{tree}: bytes_are(Huffman.decode_stream(tree,stream,count),expected)

def decode_failed(result: Result<&2,&2,String,Huffman.Tree>,stream: List<&2,U32>,count: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{tree}: bytes_failed(Huffman.decode_stream(tree,stream,count))

def header(result: Result<&2,&2,String,DataPair.Duo(Huffman.Tree,List<&2,U32>)>,stream: List<&2,U32>,count: U32,expected: List<&2,U32>,tail: List<&2,U32>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{(tree,remaining)}: same(remaining,tail) && bytes_are(Huffman.decode_stream(tree,stream,count),expected)

def header_failed(result: Result<&2,&2,String,DataPair.Duo(Huffman.Tree,List<&2,U32>)>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    # Independent code assignment: symbols0..5 have prefixes 1,01,001,absent,0000,0001.
    # Reverse fields [symbol5=0001,symbol4=0000,symbol1=01,symbol0=1,sentinel=1].
    BitsTests.require(decode(Huffman.make_tree([4,3,2,0,1]),[1,13],4,[0,1,4,5]),"Huffman varying code lengths decode exact independent symbols")
    BitsTests.require(header(Huffman.read_tree([132,67,32,31,99]),[1,13],4,[0,1,4,5],[99]),"direct odd weight count ignores only unused low nibble and retains tail")
    BitsTests.require(decode(Huffman.make_tree([1]),[10],3,[0,1,0]),"two-symbol minimum Huffman alphabet")
    BitsTests.require(decode(Huffman.make_tree([1]),[1],0,[]),"zero output accepts sentinel-only stream")
    BitsTests.require(decode_failed(Huffman.make_tree([4,3,2,0,1]),[1,13],3),"decoded size cannot leave trailing Huffman bits")
    BitsTests.require(decode_failed(Huffman.make_tree([4,3,2,0,1]),[1,13],5),"decoded size cannot overread Huffman stream")
    BitsTests.require(decode_failed(Huffman.make_tree([1]),[0],1),"Huffman zero sentinel rejected")
    BitsTests.require(decode_failed(Huffman.make_tree([1]),[1],131073),"Huffman declared output above block maximum rejected")
    BitsTests.require(tree_failed(Huffman.make_tree([])) && tree_failed(Huffman.make_tree([0,0])),"empty Huffman alphabet rejected")
    BitsTests.require(tree_failed(Huffman.make_tree([12])),"Huffman weights above11 rejected")
    BitsTests.require(tree_failed(Huffman.make_tree([2,2,2])),"tree without a least-weight symbol rejected")
    BitsTests.require(tree_failed(Huffman.make_tree([3,1])),"inferred missing Huffman weight must be a power of two")
    BitsTests.require(header_failed(Huffman.read_tree([])) && header_failed(Huffman.read_tree([132,67,32])),"truncated direct description rejected")
    # FSE probability table [16,16]: packed count fields [16,63]. Initial
    # states3/3 both emit symbol1 and each requires one transition bit. No
    # transition bits remain: final two weights are [1,1], implicit weight2.
    BitsTests.require(bytes_are(Huffman.compressed_weights([16,63,99,4]),[1,1]),"two-state FSE weight termination emits exact last symbols")
    BitsTests.require(header(Huffman.read_tree([4,16,63,99,4,77]),[52],3,[2,1,0],[77]),"FSE-compressed weights construct a usable Huffman tree")
    BitsTests.require(bytes_failed(Huffman.compressed_weights([16,63,3])),"truncated FSE initial states rejected")
    BitsTests.require(header_failed(Huffman.read_tree([0])) && header_failed(Huffman.read_tree([4,16,63,99])),"empty and truncated compressed weight description rejected")
