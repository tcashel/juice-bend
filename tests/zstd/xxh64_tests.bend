import Base
import ../../src/zstd/xxh64.bend as Hash
import ./checksum_vectors.bend as Vectors

# Digest low32 oracles are the stored Zstd content checksums produced by
# offline zstd1.5.6. Arithmetic oracles use exact integer identities, not the
# implementation's limbs. Empty full64 is the canonical XXH64 seed0 vector.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def word(result: Result<&2,&2,String,Hash.LimbWord>,expected: Hash.LimbWord) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{actual}: Hash.equal(actual,expected)

def low(result: Result<&2,&2,String,Hash.LimbWord>,expected: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{actual}: U32.is_eq(Hash.low(actual),expected)

def arithmetic() -> IO(Unit):
  do IO<Unit>:
    check(Hash.equal(Hash.multiply32(0,0),Hash.LimbWord{0,0}),"exact32-bit limb product 00000000 * 00000000")
    check(Hash.equal(Hash.multiply32(4294967295,4294967295),Hash.LimbWord{1,4294967294}),"exact32-bit limb product ffffffff * ffffffff")
    check(Hash.equal(Hash.multiply32(2147483648,2),Hash.LimbWord{0,1}),"exact32-bit limb product 80000000 * 00000002")
    check(Hash.equal(Hash.multiply32(305419896,2596069104),Hash.LimbWord{606937216,184609358}),"exact32-bit limb product 12345678 * 9abcdef0")
    check(Hash.equal(Hash.multiply32(131071,4294901761),Hash.LimbWord{196607,131069}),"exact32-bit limb product 0001ffff * ffff0001")
    check(Hash.equal(Hash.multiply(Hash.LimbWord{4294967295,4294967295},Hash.LimbWord{4294967295,4294967295}),Hash.LimbWord{1,0}),"exact64-bit modular product ffffffffffffffff * ffffffffffffffff")
    check(Hash.equal(Hash.multiply(Hash.LimbWord{2309737967,19088743},Hash.LimbWord{1985229328,4275878552}),Hash.LimbWord{3848375536,574019727}),"exact64-bit modular product 0123456789abcdef * fedcba9876543210")
    check(Hash.equal(Hash.multiply(Hash.LimbWord{0,4294967295},Hash.LimbWord{4294967295,0}),Hash.LimbWord{0,1}),"exact64-bit modular product ffffffff00000000 * 00000000ffffffff")
    check(Hash.equal(Hash.multiply(Hash.LimbWord{1,2147483648},Hash.LimbWord{2,0}),Hash.LimbWord{2,0}),"exact64-bit modular product 8000000000000001 * 0000000000000002")
    check(Hash.equal(Hash.add(Hash.LimbWord{4294967295,0},Hash.LimbWord{1,0}),Hash.LimbWord{0,1}),"64-bit addition carry 00000000ffffffff + 0000000000000001")
    check(Hash.equal(Hash.add(Hash.LimbWord{4294967295,4294967295},Hash.LimbWord{1,0}),Hash.LimbWord{0,0}),"64-bit addition carry ffffffffffffffff + 0000000000000001")
    check(Hash.equal(Hash.add(Hash.LimbWord{4294967295,305419896},Hash.LimbWord{2,2596069104}),Hash.LimbWord{1,2901489001}),"64-bit addition carry 12345678ffffffff + 9abcdef000000002")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},0n),Hash.LimbWord{2309737967,19088743}),"64-bit rotate left 0")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},1n),Hash.LimbWord{324508638,38177487}),"64-bit rotate left 1")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},7n),Hash.LimbWord{3588683648,2443359172}),"64-bit rotate left 7")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},11n),Hash.LimbWord{1584363529,439041101}),"64-bit rotate left 11")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},12n),Hash.LimbWord{3168727058,878082202}),"64-bit rotate left 12")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},18n),Hash.LimbWord{935068813,362686127}),"64-bit rotate left 18")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},23n),Hash.LimbWord{4152398242,3016021478}),"64-bit rotate left 23")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},27n),Hash.LimbWord{2013862443,1011703407}),"64-bit rotate left 27")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},31n),Hash.LimbWord{2157028019,3302352631}),"64-bit rotate left 31")
    check(Hash.equal(Hash.rotate(Hash.LimbWord{2309737967,19088743},32n),Hash.LimbWord{19088743,2309737967}),"64-bit rotate left 32")
    check(Hash.equal(Hash.shift29(Hash.LimbWord{1985229328,4275878552}),Hash.LimbWord{4142257347,7}),"64-bit right shift 29")
    check(Hash.equal(Hash.shift32(Hash.LimbWord{1985229328,4275878552}),Hash.LimbWord{4275878552,0}),"64-bit right shift 32")
    check(Hash.equal(Hash.shift33(Hash.LimbWord{1985229328,4275878552}),Hash.LimbWord{2137939276,0}),"64-bit right shift 33")
    check(Hash.equal(Hash.negate(Hash.LimbWord{1,0}),Hash.LimbWord{4294967295,4294967295}),"64-bit negation borrows across both halves")

def pattern_go(count: Nat,+index: U32,rev: List<&2,U32>) -> List<&2,U32>:
  match count:
    case 0n: List.reverse(&2,U32,rev)
    case 1n+rest:
      pattern_go(rest,U32.add(index,1),Con{U32.and(U32.add(U32.mul(index,73),19),255),rev})

def pattern(count: Nat) -> List<&2,U32>:
  pattern_go(count,0,[])

def vector(+count: U32,expected: U32) -> IO(Unit):
  check(low(Hash.digest(pattern(U32.to_nat(count)),count),expected),"Zstd checksum oracle for patterned bytes length " ++ U32.show(count))

def vectors() -> IO(Unit):
  do IO<Unit>:
    check(word(Hash.digest([],0),Hash.LimbWord{1373170073,4014398263}),"canonical empty XXH64 full64 digest")
    vector(1,1000278680)
    vector(2,3757175204)
    vector(3,1064155817)
    vector(4,4008909162)
    vector(7,4038598255)
    vector(8,1607388804)
    vector(9,3899883070)
    vector(15,3216046725)
    vector(16,1871952763)
    vector(23,754811183)
    vector(24,4060444378)
    vector(28,310359500)
    vector(31,4157760803)
    vector(32,2100021821)
    vector(33,606121305)
    vector(39,1800255898)
    vector(40,2326212107)
    vector(63,1683324589)
    vector(64,3298354761)
    vector(65,3602997127)
    vector(95,3372974602)
    vector(96,1021080437)
    vector(127,1655934437)
    vector(128,3032772509)
    vector(129,3420258759)
    vector(255,1461290566)
    vector(256,654857632)
    vector(257,2286722225)
    vector(1024,468190296)

def split(+bytes: List<&2,U32>,+at: Nat) -> Result<&2,&2,String,Hash.LimbWord>:
  do Result<&2,&2,String,Hash.LimbWord>:
    initial : Hash.State <- Hash.update(Hash.init(129),List.take(&2,U32,bytes,at))
    complete : Hash.State <- Hash.update(initial,List.drop(&2,U32,bytes,at))
    Hash.finish(complete)

def split_checks(fuel: Nat,+at: Nat,+expected: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        check(low(split(pattern(129n),at),expected),"stream split preserves checksum at " ++ Nat.show(at))
        split_checks(rest,1n+at,expected)

def byte_updates(bytes: List<&2,U32>,state: Hash.State) -> Result<&2,&2,String,Hash.LimbWord>:
  match bytes:
    case Nil{}: Hash.finish(state)
    case Con{head,tail}:
      do Result<&2,&2,String,Hash.LimbWord>:
        next : Hash.State <- Hash.update(state,[head])
        byte_updates(tail,next)

def bounded(result: Result<&2,&2,String,Hash.State>,+count: U32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{Hash.State{_,_,_,_,actual,_,pending,used}}:
      U32.is_eq(actual,count) && U32.is_eq(used,U32.mod(count,32)) &&
        U32.is_eq(U32.from_nat(List.length(&2,U32,pending)),U32.mod(count,32))

def read_closed(pair: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,result) = pair
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))

def fixture(name: String) -> IO(List<&2,U32>):
  match name:
    case "empty": IO.pure(List<&2,U32>,Vectors.empty())
    case "hello": IO.pure(List<&2,U32>,Vectors.hello())
    case "overlap": IO.pure(List<&2,U32>,Vectors.overlap())
    case "unicode": IO.pure(List<&2,U32>,Vectors.unicode())
    case "jsonl": IO.pure(List<&2,U32>,Vectors.jsonl())
    case _: IO.die(List<&2,U32>,1,"Unknown synthetic checksum fixture")

def file_vector(+name: String,+size: U32,expected: U32) -> IO(Unit):
  do IO<Unit>:
    +bytes : List<&2,U32> <- fixture(name)
    check(U32.is_eq(U32.from_nat(List.length(&2,U32,bytes)),size) && low(Hash.digest(bytes,size),expected),"stored synthetic " ++ name ++ " frame content checksum")

def update_failed(result: Result<&2,&2,String,Hash.State>) -> Bool:
  Result.is_fail(&2,&2,String,Hash.State,result)

def finish_failed(result: Result<&2,&2,String,Hash.LimbWord>) -> Bool:
  Result.is_fail(&2,&2,String,Hash.LimbWord,result)

def forged(total: U32,limit: U32,pending: List<&2,U32>,used: U32) -> Hash.State:
  Hash.State{Hash.LimbWord{0,0},Hash.LimbWord{0,0},Hash.LimbWord{0,0},Hash.LimbWord{0,0},total,limit,pending,used}

def failures() -> IO(Unit):
  do IO<Unit>:
    check(update_failed(Hash.update(Hash.init(0),[0])),"zero input cap refuses any byte")
    check(update_failed(Hash.update(Hash.init(31),pattern(32n))),"stream input cap is enforced before stripe completion")
    check(update_failed(Hash.update(Hash.init(3),[0,256,1])),"non-octet input refused")
    check(update_failed(Hash.update(forged(4294967295,4294967295,[],0),[0])),"total length cannot wrap at U32 maximum")
    check(finish_failed(Hash.finish(forged(4,3,[1,2,3,4],4))),"finish refuses total above cap")
    check(finish_failed(Hash.finish(forged(32,32,[],32))),"finish refuses oversized pending count")
    check(finish_failed(Hash.finish(forged(2,2,[1],1))),"finish refuses total/pending inconsistency")
    check(finish_failed(Hash.finish(forged(2,2,[1],2))),"finish refuses short pending list")
    check(finish_failed(Hash.finish(forged(1,1,[1,2],1))),"finish refuses extra pending list")
    check(finish_failed(Hash.finish(forged(1,1,[256],1))),"finish refuses forged non-octet")

def main() -> IO(Unit):
  do IO<Unit>:
    arithmetic()
    vectors()
    file_vector("empty",0,1373170073)
    file_vector("hello",14,4080112649)
    file_vector("overlap",2000,1100234828)
    file_vector("unicode",6900,194294537)
    file_vector("jsonl",16104,2881381213)
    split_checks(130n,0n,3420258759)
    check(low(byte_updates(pattern(1024n),Hash.init(1024)),468190296),"single-byte updates preserve multi-stripe checksum")
    check(bounded(Hash.update(Hash.init(1024),pattern(1024n)),1024),"full stripes retain zero prior bytes")
    check(bounded(Hash.update(Hash.init(33),pattern(33n)),33),"stream retains only one pending byte after stripe")
    failures()
