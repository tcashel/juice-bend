import Base
import ../../src/zstd/pair.bend as DataPair
import ../../src/zstd/bits.bend as Bits

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def forward_case(result: Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>,expected: U32,used: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{(cursor,value)}: U32.is_eq(value,expected) && U32.is_eq(Bits.used_forward(cursor),used)

def reverse_case(result: Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>,expected: U32,left: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{(cursor,value)}: U32.is_eq(value,expected) && U32.is_eq(Bits.remaining_reverse(cursor),left)

def reverse_setup(result: Result<&2,&2,String,Bits.Rev>,width: U32,expected: U32,left: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{cursor}: reverse_case(Bits.read_reverse(cursor,width),expected,left)

def forward_failure(result: Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def reverse_failure(result: Result<&2,&2,String,Bits.Rev>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def reverse_failed(result: Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def reverse_read_failure(result: Result<&2,&2,String,Bits.Rev>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{cursor}: reverse_failed(Bits.read_reverse(cursor,12))

def tail_expected(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case Con{254,Nil{}}: True{}
    case _: False{}

def forward_rest(result: Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{(cursor,_)}: tail_expected(Bits.remaining_forward(cursor))

def forward_next(result: Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{(cursor,value)}:
      U32.is_eq(value,5) && forward_case(Bits.read_forward(cursor,7),117,2)

def fill(fuel: Nat,acc: List<&2,U32>) -> List<&2,U32>:
  match fuel:
    case 0n: acc
    case 1n+rest: fill(rest,Con{1,acc})

def main() -> IO(Unit):
  do IO<Unit>:
    require(forward_case(Bits.read_forward(Bits.forward([173,3]),10),941,2),"forward fields retain little-endian bit order across bytes")
    require(forward_next(Bits.read_forward(Bits.forward([173,3]),3)),"forward reads retain exact partial-byte position")
    require(forward_rest(Bits.read_forward(Bits.forward([173,3,254]),10)),"forward alignment exposes only unread bytes")
    require(forward_case(Bits.read_forward(Bits.forward(Nil{}),0),0,0),"empty zero-bit field consumes nothing")
    require(forward_failure(Bits.read_forward(Bits.forward([1]),9)),"forward truncation fails")
    require(forward_failure(Bits.read_forward(Bits.forward([256]),1)),"non-octet fails")
    require(forward_failure(Bits.read_forward(Bits.forward([1,2,3,4]),25)),"field above supported width fails")
    require(reverse_setup(Bits.reverse([1,13]),11,1281,0),"reverse stream strips sentinel and preserves field numeric order")
    require(reverse_setup(Bits.reverse([1,13]),3,5,8),"reverse initial field stops at exact byte boundary")
    require(reverse_setup(Bits.reverse([1]),0,0,0),"sentinel-only stream supports zero output")
    require(reverse_read_failure(Bits.reverse([1,13])),"reverse field cannot overread sentinel-bound extent")
    require(reverse_failure(Bits.reverse(Nil{})),"empty reverse stream rejected")
    require(reverse_failure(Bits.reverse([0])),"zero final byte rejected")
    require(reverse_failure(Bits.reverse([256,1])),"reverse non-octet rejected")
    require(reverse_failure(Bits.reverse(fill(131073n,Nil{}))),"reverse stream above128KiB rejected")
