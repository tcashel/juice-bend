import Base
import ../../src/zstd/pair.bend as DataPair
import ../../src/zstd/fse.bend as FSE

# These 160 expected rows are transcribed from Appendix A of the pinned
# Zstandard v1.5.7 format document. They are not calculated by the table
# constructor, the spreading algorithm, or a second decoder in these tests.
def literal_rows() -> List<&2,FSE.Entry>:
  [FSE.Entry{0,4,0},
    FSE.Entry{0,4,16},
    FSE.Entry{1,5,32},
    FSE.Entry{3,5,0},
    FSE.Entry{4,5,0},
    FSE.Entry{6,5,0},
    FSE.Entry{7,5,0},
    FSE.Entry{9,5,0},
    FSE.Entry{10,5,0},
    FSE.Entry{12,5,0},
    FSE.Entry{14,6,0},
    FSE.Entry{16,5,0},
    FSE.Entry{18,5,0},
    FSE.Entry{19,5,0},
    FSE.Entry{21,5,0},
    FSE.Entry{22,5,0},
    FSE.Entry{24,5,0},
    FSE.Entry{25,5,32},
    FSE.Entry{26,5,0},
    FSE.Entry{27,6,0},
    FSE.Entry{29,6,0},
    FSE.Entry{31,6,0},
    FSE.Entry{0,4,32},
    FSE.Entry{1,4,0},
    FSE.Entry{2,5,0},
    FSE.Entry{4,5,32},
    FSE.Entry{5,5,0},
    FSE.Entry{7,5,32},
    FSE.Entry{8,5,0},
    FSE.Entry{10,5,32},
    FSE.Entry{11,5,0},
    FSE.Entry{13,6,0},
    FSE.Entry{16,5,32},
    FSE.Entry{17,5,0},
    FSE.Entry{19,5,32},
    FSE.Entry{20,5,0},
    FSE.Entry{22,5,32},
    FSE.Entry{23,5,0},
    FSE.Entry{25,4,0},
    FSE.Entry{25,4,16},
    FSE.Entry{26,5,32},
    FSE.Entry{28,6,0},
    FSE.Entry{30,6,0},
    FSE.Entry{0,4,48},
    FSE.Entry{1,4,16},
    FSE.Entry{2,5,32},
    FSE.Entry{3,5,32},
    FSE.Entry{5,5,32},
    FSE.Entry{6,5,32},
    FSE.Entry{8,5,32},
    FSE.Entry{9,5,32},
    FSE.Entry{11,5,32},
    FSE.Entry{12,5,32},
    FSE.Entry{15,6,0},
    FSE.Entry{17,5,32},
    FSE.Entry{18,5,32},
    FSE.Entry{20,5,32},
    FSE.Entry{21,5,32},
    FSE.Entry{23,5,32},
    FSE.Entry{24,5,32},
    FSE.Entry{35,6,0},
    FSE.Entry{34,6,0},
    FSE.Entry{33,6,0},
    FSE.Entry{32,6,0}]

def match_rows() -> List<&2,FSE.Entry>:
  [FSE.Entry{0,6,0},
    FSE.Entry{1,4,0},
    FSE.Entry{2,5,32},
    FSE.Entry{3,5,0},
    FSE.Entry{5,5,0},
    FSE.Entry{6,5,0},
    FSE.Entry{8,5,0},
    FSE.Entry{10,6,0},
    FSE.Entry{13,6,0},
    FSE.Entry{16,6,0},
    FSE.Entry{19,6,0},
    FSE.Entry{22,6,0},
    FSE.Entry{25,6,0},
    FSE.Entry{28,6,0},
    FSE.Entry{31,6,0},
    FSE.Entry{33,6,0},
    FSE.Entry{35,6,0},
    FSE.Entry{37,6,0},
    FSE.Entry{39,6,0},
    FSE.Entry{41,6,0},
    FSE.Entry{43,6,0},
    FSE.Entry{45,6,0},
    FSE.Entry{1,4,16},
    FSE.Entry{2,4,0},
    FSE.Entry{3,5,32},
    FSE.Entry{4,5,0},
    FSE.Entry{6,5,32},
    FSE.Entry{7,5,0},
    FSE.Entry{9,6,0},
    FSE.Entry{12,6,0},
    FSE.Entry{15,6,0},
    FSE.Entry{18,6,0},
    FSE.Entry{21,6,0},
    FSE.Entry{24,6,0},
    FSE.Entry{27,6,0},
    FSE.Entry{30,6,0},
    FSE.Entry{32,6,0},
    FSE.Entry{34,6,0},
    FSE.Entry{36,6,0},
    FSE.Entry{38,6,0},
    FSE.Entry{40,6,0},
    FSE.Entry{42,6,0},
    FSE.Entry{44,6,0},
    FSE.Entry{1,4,32},
    FSE.Entry{1,4,48},
    FSE.Entry{2,4,16},
    FSE.Entry{4,5,32},
    FSE.Entry{5,5,32},
    FSE.Entry{7,5,32},
    FSE.Entry{8,5,32},
    FSE.Entry{11,6,0},
    FSE.Entry{14,6,0},
    FSE.Entry{17,6,0},
    FSE.Entry{20,6,0},
    FSE.Entry{23,6,0},
    FSE.Entry{26,6,0},
    FSE.Entry{29,6,0},
    FSE.Entry{52,6,0},
    FSE.Entry{51,6,0},
    FSE.Entry{50,6,0},
    FSE.Entry{49,6,0},
    FSE.Entry{48,6,0},
    FSE.Entry{47,6,0},
    FSE.Entry{46,6,0}]

def offset_rows() -> List<&2,FSE.Entry>:
  [FSE.Entry{0,5,0},
    FSE.Entry{6,4,0},
    FSE.Entry{9,5,0},
    FSE.Entry{15,5,0},
    FSE.Entry{21,5,0},
    FSE.Entry{3,5,0},
    FSE.Entry{7,4,0},
    FSE.Entry{12,5,0},
    FSE.Entry{18,5,0},
    FSE.Entry{23,5,0},
    FSE.Entry{5,5,0},
    FSE.Entry{8,4,0},
    FSE.Entry{14,5,0},
    FSE.Entry{20,5,0},
    FSE.Entry{2,5,0},
    FSE.Entry{7,4,16},
    FSE.Entry{11,5,0},
    FSE.Entry{17,5,0},
    FSE.Entry{22,5,0},
    FSE.Entry{4,5,0},
    FSE.Entry{8,4,16},
    FSE.Entry{13,5,0},
    FSE.Entry{19,5,0},
    FSE.Entry{1,5,0},
    FSE.Entry{6,4,16},
    FSE.Entry{10,5,0},
    FSE.Entry{16,5,0},
    FSE.Entry{28,5,0},
    FSE.Entry{27,5,0},
    FSE.Entry{26,5,0},
    FSE.Entry{25,5,0},
    FSE.Entry{24,5,0}]

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def table(result: Result<&2,&2,String,FSE.Table>) -> IO(FSE.Table):
  match result:
    case Fail{error}: IO.die(FSE.Table,1,"FAIL table: " ++ error)
    case Done{value}: IO.pure(FSE.Table,value)

def equal_entry(a: FSE.Entry,b: FSE.Entry) -> Bool:
  FSE.Entry{asym,ab,an} = a
  FSE.Entry{bsym,bb,bn} = b
  U32.is_eq(asym,bsym) && U32.is_eq(ab,bb) && U32.is_eq(an,bn)

def entry(result: Result<&2,&2,String,FSE.Entry>,expected: FSE.Entry) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{actual}: equal_entry(actual,expected)

def check_rows(rows: List<&2,FSE.Entry>,+built: FSE.Table,+index: U32,+label: String) -> IO(Unit):
  match rows:
    case Nil{}: IO.pure(Unit,Unit{})
    case Con{expected,rest}:
      do IO<Unit>:
        require(entry(FSE.lookup(built,index),expected),label ++ " Appendix A state " ++ U32.show(index))
        check_rows(rest,built,U32.add(index,1),label)

def rejected(result: Result<&2,&2,String,FSE.Table>) -> Bool:
  Result.is_fail(&2,&2,String,FSE.Table,result)

def read_rejected(result: Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>) -> Bool:
  Result.is_fail(&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>),result)

def entry_rejected(result: Result<&2,&2,String,FSE.Entry>) -> Bool:
  Result.is_fail(&2,&2,String,FSE.Entry,result)

def same_result(a: Result<&2,&2,String,FSE.Entry>,b: Result<&2,&2,String,FSE.Entry>) -> Bool:
  match a b:
    case Done{left} Done{right}: equal_entry(left,right)
    case _ _: False{}

def same_cells(count: Nat,+left: FSE.Table,+right: FSE.Table,+index: U32) -> Bool:
  match count:
    case 0n: True{}
    case 1n+rest:
      same_result(FSE.lookup(left,index),FSE.lookup(right,index)) && same_cells(rest,left,right,U32.add(index,1))

def bytes_equal(a: List<&2,U32>,b: List<&2,U32>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{left,ls} Con{right,rs}: U32.is_eq(left,right) && bytes_equal(ls,rs)
    case _ _: False{}

def read_matches(result: Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>,expected: Result<&2,&2,String,FSE.Table>,tail: List<&2,U32>) -> Bool:
  match result expected:
    case Done{(+actual,remaining)} Done{+wanted}:
      U32.is_eq(FSE.accuracy(actual),FSE.accuracy(wanted)) &&
        same_cells(U32.to_nat(U32.shln(1,U32.to_nat(FSE.accuracy(wanted)))),actual,wanted,0) && bytes_equal(remaining,tail)
    case _ _: False{}

def repeat(count: Nat,+value: U32) -> List<&2,U32>:
  match count:
    case 0n: []
    case 1n+rest: Con{value,repeat(rest,value)}

def defaults() -> IO(Unit):
  do IO<Unit>:
    ll : FSE.Table <- table(FSE.literals())
    ml : FSE.Table <- table(FSE.matches())
    of : FSE.Table <- table(FSE.offsets())
    check_rows(literal_rows(),ll,0,"literal length")
    check_rows(match_rows(),ml,0,"match length")
    check_rows(offset_rows(),of,0,"offset")

def distributions() -> IO(Unit):
  do IO<Unit>:
    +five : FSE.Table <- table(FSE.make_table(5,[5,27]))
    # Symbol zero lands at 0,23,14,5,28 under stride23; the ordered ranges
    # 8..15,16..23,24..31,0..3,4..7 exercise mixed transition widths.
    require(entry(FSE.lookup(five,0),FSE.Entry{0,3,8}),"5/27 first large-width row")
    require(entry(FSE.lookup(five,5),FSE.Entry{0,3,16}),"5/27 second large-width row")
    require(entry(FSE.lookup(five,14),FSE.Entry{0,3,24}),"5/27 third large-width row")
    require(entry(FSE.lookup(five,23),FSE.Entry{0,2,0}),"5/27 first small-width row")
    require(entry(FSE.lookup(five,28),FSE.Entry{0,2,4}),"5/27 second small-width row")
    require(entry(FSE.lookup(five,1),FSE.Entry{1,1,22}),"27-frequency low state has one bit")
    require(entry(FSE.lookup(five,7),FSE.Entry{1,0,0}),"27-frequency high state has zero bits")
    +rare : FSE.Table <- table(FSE.make_table(5,[1,0,4294967295,30]))
    require(entry(FSE.lookup(rare,31),FSE.Entry{2,5,0}),"rare probability reserves highest row")
    require(entry(FSE.lookup(rare,0),FSE.Entry{0,5,0}),"zero probability allocates no row")
    require(entry(FSE.lookup(rare,1),FSE.Entry{3,1,28}),"30-frequency first extra-bit range")
    require(entry(FSE.lookup(rare,2),FSE.Entry{3,1,30}),"30-frequency second extra-bit range")
    require(entry(FSE.lookup(rare,3),FSE.Entry{3,0,0}),"30-frequency first zero-bit range")
    +all_rare : FSE.Table <- table(FSE.make_table(5,repeat(32n,4294967295)))
    require(entry(FSE.lookup(all_rare,0),FSE.Entry{31,5,0}) && entry(FSE.lookup(all_rare,31),FSE.Entry{0,5,0}),"all-rare table retains reversed allocation")
    +wide : FSE.Table <- table(FSE.make_table(9,repeat(256n,2)))
    require(U32.is_eq(FSE.accuracy(wide),9) && entry_rejected(FSE.lookup(wide,512)),"maximum alphabet and log enforce exact bound")
    +single : FSE.Table <- table(FSE.rle(52,52))
    require(entry(FSE.lookup(single,0),FSE.Entry{52,0,0}) && U32.is_eq(FSE.accuracy(single),0),"RLE uses one state and consumes no bits")
    require(entry_rejected(FSE.lookup(single,1)) && entry_rejected(FSE.lookup(five,32)) && entry_rejected(FSE.lookup(five,4294967295)),"lookup refuses out-of-range states rather than wrapping")
    require(rejected(FSE.rle(53,52)) && rejected(FSE.rle(0,256)),"RLE alphabet guard")

def malformed() -> IO(Unit):
  do IO<Unit>:
    require(rejected(FSE.make_table(4,[8,8])) && rejected(FSE.make_table(10,[512,512])),"accuracy log cannot leave 5..9")
    require(rejected(FSE.make_table(5,[])) && rejected(FSE.make_table(5,[1,1])),"empty and undersubscribed distributions rejected")
    require(rejected(FSE.make_table(5,[16,17])) && rejected(FSE.make_table(5,[4294967294,2])),"oversubscribed and invalid signed-like counts rejected")
    require(rejected(FSE.make_table(5,[32])) && rejected(FSE.make_table(5,[0,32])),"compressed mode requires at least two symbols")
    require(rejected(FSE.make_table(5,Con{16,Con{16,repeat(255n,0)}})),"constructor bounds symbol alphabet")
    # Literal independent packed fields: log0/4, value17/5, value31/5.
    require(read_matches(FSE.read_table([16,63,170,85],1,5),FSE.make_table(5,[16,16]),[170,85]),"forward header small-value coding and whole-byte tail")
    require(read_matches(FSE.read_table([16,255],1,5),FSE.make_table(5,[16,16]),[]),"unused last-byte high bits do not consume another byte")
    require(read_matches(FSE.read_table([17,254],1,6),FSE.make_table(6,[32,32]),[]),"six-bit accuracy header is accepted for Huffman weights")
    require(read_matches(FSE.read_table([16,136,31],2,5),FSE.make_table(5,[0,16,16]),[]),"zero repeat flag zero consumes no additional symbol")
    # Value1/5 (zero), repeat3/2, repeat0/2, then value17/5,value31/5.
    require(read_matches(FSE.read_table([16,38,126,170],5,5),FSE.make_table(5,[0,0,0,0,16,16]),[170]),"continued zero repeat consumes terminating repeat flag")
    require(read_matches(FSE.read_table([16,140,31],4,5),FSE.make_table(5,[0,0,0,16,16]),[]),"noncontinued zero repeat exact symbol positions")
    # Value0/5 is -1; the second encoded field63/6 represents probability31.
    require(read_matches(FSE.read_table([0,126,85],1,5),FSE.make_table(5,[4294967295,31]),[85]),"forward header rare count and upper-value coding")
    require(read_rejected(FSE.read_table([],35,9)) && read_rejected(FSE.read_table([16],1,5)),"truncated header and probability bits rejected")
    require(read_rejected(FSE.read_table([16,38],5,5)),"truncated after zero-repeat prefix rejected")
    require(read_rejected(FSE.read_table([16,38,126],2,5)),"zero repeat cannot exceed alphabet")
    require(read_rejected(FSE.read_table([16,63],0,5)),"nonzero out-of-alphabet symbol rejected")
    require(read_rejected(FSE.read_table([240,3],0,5)),"encoded single-symbol compressed table rejected")
    require(read_rejected(FSE.read_table([1],35,5)) && read_rejected(FSE.read_table([15],35,9)),"header log bounded before allocating table")
    require(read_rejected(FSE.read_table([256],1,5)),"consumed non-octet rejected")
    require(read_rejected(FSE.read_table([16,63],256,5)) && read_rejected(FSE.read_table([16,63],1,10)),"parser bounds are checked")

def main() -> IO(Unit):
  do IO<Unit>:
    defaults()
    distributions()
    malformed()
