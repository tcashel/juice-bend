import Base
import ../src/domain.bend as Domain
import ../src/raw_compare.bend as RawCompare

# The old production expression is the differential oracle. Explicit expected
# results additionally ensure a shared fixture mistake cannot make both pass.
# These are equality checks only, not claims that metadata, byte ranges, or
# capture size limits have been validated by this pure comparator.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def bool_equal(a: Bool,+b: Bool) -> Bool:
  Bool.pick(Bool,a,b,Bool.not(b))

def agrees(+chunks: List<&2,List<&2,U32>>,+source: List<&2,U32>,+expected: Bool,label: String) -> IO(Unit):
  check(bool_equal(RawCompare.equal(chunks,source),expected) &&
    bool_equal(Domain.bytes_equal(List.concat(&2,U32,chunks),source),expected),label)

def pattern_go(count: Nat,+index: U32,acc: List<&2,U32>) -> List<&2,U32>:
  match count:
    case 0n: List.reverse(&2,U32,acc)
    case 1n+rest: pattern_go(rest,U32.add(index,1),U32.mod((index*73+19 : U32),256) <> acc)

def pattern(count: Nat) -> List<&2,U32>:
  pattern_go(count,0,[])

def changed(bytes: List<&2,U32>,index: Nat) -> List<&2,U32>:
  match bytes index:
    case [] _: []
    case head <> tail 0n: U32.add(head,1) <> tail
    case head <> tail 1n+rest: head <> changed(tail,rest)

def sample() -> List<&2,U32>:
  [0,255,128,10,13,192,128,237,160,128,244,144,128,128,240,159,152,128,0]

def split(+bytes: List<&2,U32>,+at: Nat) -> List<&2,List<&2,U32>>:
  [[],List.take(&2,U32,bytes,at),[],List.drop(&2,U32,bytes,at),[]]

def empty_cases() -> IO(Unit):
  do IO<Unit>:
    agrees([],[],True{},"no chunks equal an empty source")
    agrees([[]],[],True{},"one empty chunk equals an empty source")
    agrees([[],[],[],[]],[],True{},"empty chunk runs preserve an empty source")
    agrees([],[0],False{},"no chunks reject one NUL source byte")
    agrees([[],[],[]],[0],False{},"empty chunks cannot consume source bytes")
    agrees([[0]],[],False{},"one NUL chunk cannot disappear into empty source")
    agrees([[],[0],[]],[0],True{},"NUL survives leading and trailing empty chunks")
    agrees([[0],[],[]],[],False{},"trailing empty chunks cannot erase missing source bytes")
    agrees([[],[],[0]],[],False{},"late nonempty chunk is not hidden by preceding empties")
    agrees([[1],[],[2]],[2,1],False{},"chunk order remains significant")
    agrees([[1],[2],[1]],[1,2],False{},"extra repeated final occurrence remains significant")

def exact_u32() -> IO(Unit):
  do IO<Unit>:
    agrees([[0,256],[],[65536,1114112],[2147483648,4294967295]],
      [0,256,65536,1114112,2147483648,4294967295],True{},"all U32 values compare exactly without byte or Unicode coercion")
    agrees([[256]],[0],False{},"256 does not compare equal to byte zero")
    agrees([[0]],[256],False{},"source values are not narrowed to bytes")
    agrees([[4294967295]],[255],False{},"maximum U32 does not compare equal to byte255")
    agrees([[255]],[4294967295],False{},"maximum source U32 does not compare equal to byte255")
    agrees([[65536]],[0],False{},"U32 comparison does not truncate to sixteen bits")
    agrees([[2147483648]],[0],False{},"high signed bit stays significant")
    agrees([[4294967295]],[4294967294],False{},"adjacent maximum U32 values remain distinct")
    agrees([[192],[128],[],[237,160],[128],[244,144,128,128]],
      [192,128,237,160,128,244,144,128,128],True{},"invalid UTF8 is compared literally without decoding")
    agrees([[240],[159],[],[152],[128],[],[0]],[240,159,152,128,0],True{},
      "multibyte UTF8 and terminal NUL may split at every byte")

def split_case(+at: Nat) -> IO(Unit):
  do IO<Unit>:
    agrees(split(sample(),at),sample(),True{},"exact bytes at split " ++ Nat.show(at))
    agrees(split(sample(),at),List.take(&2,U32,sample(),18n),False{},"truncated source at split " ++ Nat.show(at))
    agrees(split(sample(),at),List.append(&2,U32,sample(),[0]),False{},"extra source byte at split " ++ Nat.show(at))
    agrees(split(sample(),at),changed(sample(),Nat.min(at,18n)),False{},"mismatch on or after chunk edge " ++ Nat.show(at))
    agrees(split(sample(),at),changed(sample(),Nat.sub(at,1n)),False{},"mismatch before chunk edge " ++ Nat.show(at))

def every_split(remaining: Nat,+at: Nat) -> IO(Unit):
  match remaining:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        split_case(at)
        every_split(rest,1n+at)

def three_chunks(+bytes: List<&2,U32>,+first: Nat,+second: Nat) -> List<&2,List<&2,U32>>:
  [[],List.take(&2,U32,bytes,first),[],
    List.take(&2,U32,List.drop(&2,U32,bytes,first),Nat.sub(second,first)),[],
    List.drop(&2,U32,bytes,second),[]]

def second_cuts(remaining: Nat,+first: Nat,+second: Nat) -> IO(Unit):
  match remaining:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        agrees(three_chunks(sample(),first,second),sample(),True{},
          "three chunks with empty separators at cuts " ++ Nat.show(first) ++ "/" ++ Nat.show(second))
        second_cuts(rest,first,1n+second)

def all_cuts(+remaining: Nat,+first: Nat) -> IO(Unit):
  match remaining:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        second_cuts(remaining,first,first)
        all_cuts(rest,1n+first)

def singleton_chunks(bytes: List<&2,U32>) -> List<&2,List<&2,U32>>:
  match bytes:
    case []: [[]]
    case head <> tail: [] <> [head] <> singleton_chunks(tail)

def many_chunks() -> IO(Unit):
  do IO<Unit>:
    agrees(List.replicate(List<&2,U32>,32768n,[]),[],True{},"32768 empty chunks terminate with exact empty equality")
    agrees(List.append(&2,List<&2,U32>,List.replicate(List<&2,U32>,32768n,[]),[[1]]),[],False{},
      "nonempty last chunk after32768 empty chunks is still examined")
    agrees(singleton_chunks(pattern(4096n)),pattern(4096n),True{},"4096 one-byte chunks with intervening empties preserve order")
    agrees(singleton_chunks(pattern(4096n)),changed(pattern(4096n),2048n),False{},"late singleton mismatch remains false after later matches")
    agrees(singleton_chunks(pattern(4096n)),List.take(&2,U32,pattern(4096n),4095n),False{},"singleton sequence rejects missing final byte")
    agrees(singleton_chunks(pattern(4096n)),List.append(&2,U32,pattern(4096n),[19]),False{},"singleton sequence rejects extra final byte")

def byte_chunks(remaining: Nat,+bytes: List<&2,U32>) -> List<&2,List<&2,U32>>:
  match remaining:
    case 0n: [bytes]
    case 1n+rest:
      List.append(&2,List<&2,U32>,[List.take(&2,U32,bytes,262144n),[]],
        byte_chunks(rest,List.drop(&2,U32,bytes,262144n)))

def large_mismatches(indices: List<&2,Nat>) -> IO(Unit):
  match indices:
    case []: IO.pure(Unit,Unit{})
    case +index <> rest:
      do IO<Unit>:
        agrees(byte_chunks(5n,pattern(1310720n)),changed(pattern(1310720n),index),False{},
          "over1MiB comparison detects mismatch at fragment edge " ++ Nat.show(index))
        large_mismatches(rest)

def large_cases() -> IO(Unit):
  do IO<Unit>:
    agrees([pattern(262144n)],pattern(262144n),True{},"one full262144-byte captured fragment compares exactly")
    agrees([[],pattern(262144n),[]],changed(pattern(262144n),262143n),False{},"maximum fragment checks its final byte")
    agrees(byte_chunks(5n,pattern(1310720n)),pattern(1310720n),True{},"five full fragments compare1310720 bytes without a oneMiB truncation")
    agrees(byte_chunks(5n,pattern(1310720n)),pattern(1310719n),False{},"over1MiB comparison rejects one missing terminal byte")
    agrees(byte_chunks(5n,pattern(1310720n)),pattern(1310721n),False{},"over1MiB comparison rejects one extra terminal byte")
    large_mismatches([0n,262143n,262144n,524287n,524288n,786431n,786432n,1048575n,1048576n,1310719n])

def main() -> IO(Unit):
  do IO<Unit>:
    empty_cases()
    exact_u32()
    every_split(20n,0n)
    all_cuts(20n,0n)
    many_chunks()
    large_cases()
