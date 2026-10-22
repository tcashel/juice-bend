import Base
import ../src/jpeg/types.bend as T
import ../src/jpeg/entropy.bend as E

# Independent Annex C/F bit recipes. Constants below were packed from the
# explicitly stated code words, not produced by the decoder or a JPEG encoder.
type Cell is Data:
  Cell{index: U32,value: F32}

def check(label: String,valid: Bool) -> IO(Unit):
  match valid:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL JPEG entropy: " ++ label)

def okay(result: Result<&2,&2,T.Failure,Unit>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def rejected(result: Result<&2,&1,T.Failure,E.Decoded>) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{_}: True{}

def read_failed(result: Result<&2,&2,T.Failure,E.Read>) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{_}: True{}

def read_value(result: Result<&2,&2,T.Failure,E.Read>,expected: U32) -> Bool:
  match result:
    case Done{E.Read{_,value}}: U32.is_eq(value,expected)
    case Fail{_}: False{}

def cursor_failed(result: Result<&2,&2,T.Failure,E.Cursor>) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{_}: True{}

def wanted(values: List<&2,Cell>,+index: U32) -> F32:
  match values:
    case Nil{}: 0.0
    case Con{Cell{at,value},rest}: Bool.pick(F32,U32.is_eq(at,index),value,wanted(rest,index))

def values(fuel: Nat,actual: List<F32>,+expected: List<&2,Cell>,+index: U32) -> Bool:
  match fuel actual:
    case 0n Nil{}: True{}
    case 1n+rest Con{value,tail}: F32.is_eq(value,wanted(expected,index)) && values(rest,tail,expected,U32.inc(index))
    case _ _: False{}

def decoded(result: Result<&2,&1,T.Failure,E.Decoded>,expected: List<&2,Cell>,dc: F32) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{E.Decoded{cursor,actual,coefficients}}:
      F32.is_eq(actual,dc) && okay(E.finish(cursor)) && values(64n,Array.to_list(F32,coefficients),expected,0)

def all_ac(fuel: Nat,actual: List<F32>,+index: U32) -> Bool:
  match fuel actual:
    case 0n Nil{}: True{}
    case 1n+rest Con{value,tail}:
      F32.is_eq(value,Bool.pick(F32,U32.is_eq(index,0),0.0,1.0)) && all_ac(rest,tail,U32.inc(index))
    case _ _: False{}

def full_block(result: Result<&2,&1,T.Failure,E.Decoded>) -> Bool:
  match result:
    case Done{E.Decoded{cursor,dc,coefficients}}: F32.is_eq(dc,0.0) && okay(E.finish(cursor)) && all_ac(64n,Array.to_list(F32,coefficients),0)
    case Fail{_}: False{}

# DC categories 0..11 have code words 0,10,110,...,111111111110.
def dc() -> T.Huffman:
  T.Huffman{[1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,0],[0,1,2,3,4,5,6,7,8,9,10,11]}

# EOB=0, (run0,size1)=10, (run1,size1)=110, ZRL=1110,
# (run0,size10)=11110. The unused all-ones prefix is intentional.
def ac() -> T.Huffman:
  T.Huffman{[1,1,1,1,1,0,0,0,0,0,0,0,0,0,0,0],[0,1,17,240,10]}

def single(symbol: U32) -> T.Huffman:
  T.Huffman{[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[symbol]}

def boundary(symbol: U32) -> T.Huffman:
  T.Huffman{[1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,240,symbol]}

def decode(bytes: List<&2,U32>,prior: F32) -> Result<&2,&1,T.Failure,E.Decoded>:
  E.block(E.start(bytes),dc(),ac(),prior)

def reset_block(result: Result<&2,&2,T.Failure,E.Cursor>) -> Bool:
  match result:
    case Done{cursor}: decoded(E.block(cursor,dc(),ac(),0.0),[],0.0)
    case Fail{_}: False{}

def restarted(result: Result<&2,&1,T.Failure,E.Decoded>) -> Bool:
  match result:
    case Done{E.Decoded{cursor,dc,_}}: F32.is_eq(dc,5.0) && reset_block(E.restart(cursor,0))
    case Fail{_}: False{}

def restarted_tail(result: Result<&2,&2,T.Failure,E.Cursor>) -> Bool:
  match result:
    case Done{E.Cursor{Con{7,Nil{}},0,0}}: True{}
    case _: False{}

def zigzag_result(result: Result<&2,&2,T.Failure,U32>,expected: U32) -> Bool:
  match result:
    case Done{actual}: U32.is_eq(actual,expected)
    case Fail{_}: False{}

def zigzag_failed(result: Result<&2,&2,T.Failure,U32>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def zigzag_all(expected: List<&2,U32>,+index: U32) -> Bool:
  match expected:
    case Nil{}: U32.is_eq(index,64)
    case Con{value,tail}: zigzag_result(E.zigzag(index),value) && zigzag_all(tail,U32.inc(index))

def tables() -> IO(Unit):
  do IO<Unit>:
    check("incomplete canonical DC table",okay(E.validate(0,dc())))
    check("baseline AC EOB and ZRL table",okay(E.validate(1,ac())))
    check("single zero-bit-prefix table",okay(E.validate(0,single(0))))
    check("sixteen-bit canonical code",okay(E.validate(0,T.Huffman{[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],[0]})))
    check("invalid Huffman class",Bool.not(okay(E.validate(2,single(0)))))
    check("DC category twelve rejected",Bool.not(okay(E.validate(0,single(12)))))
    check("AC size eleven rejected",Bool.not(okay(E.validate(1,single(11)))))
    check("non-EOB non-ZRL zero size rejected",Bool.not(okay(E.validate(1,single(16)))))
    check("non-octet symbol rejected",Bool.not(okay(E.validate(1,single(256)))))
    check("empty table rejected",Bool.not(okay(E.validate(0,T.Huffman{List.replicate(U32,16n,0),[]}))))
    check("fifteen counts rejected",Bool.not(okay(E.validate(0,T.Huffman{List.replicate(U32,15n,0),[]}))))
    check("seventeen counts rejected",Bool.not(okay(E.validate(0,T.Huffman{List.replicate(U32,17n,0),[]}))))
    check("missing symbol rejected",Bool.not(okay(E.validate(0,T.Huffman{[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[]}))))
    check("extra symbol rejected",Bool.not(okay(E.validate(0,T.Huffman{[1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,1]}))))
    check("all-ones one-bit code rejected",Bool.not(okay(E.validate(0,T.Huffman{[2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,1]}))))
    check("all-ones two-bit code rejected",Bool.not(okay(E.validate(0,T.Huffman{[1,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,1,2]}))))
    check("oversubscribed tree rejected",Bool.not(okay(E.validate(0,T.Huffman{[3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[0,1,2]}))))
    check("count 257 rejected before symbols",Bool.not(okay(E.validate(0,T.Huffman{[0,0,0,0,0,0,0,0,0,257,0,0,0,0,0,0],List.replicate(U32,257n,0)}))))
    check("non-octet count256 rejected",Bool.not(okay(E.validate(0,T.Huffman{[0,0,0,0,0,0,0,0,256,0,0,0,0,0,0,0],List.replicate(U32,256n,0)}))))
    check("total256 remains bounded and valid",okay(E.validate(1,T.Huffman{[0,0,0,0,0,0,0,0,255,1,0,0,0,0,0,0],List.replicate(U32,256n,0)})))
    check("total 257 rejected",Bool.not(okay(E.validate(0,T.Huffman{[0,0,0,0,0,0,0,0,255,2,0,0,0,0,0,0],List.replicate(U32,257n,0)}))))
    check("hostile U32 count rejected",Bool.not(okay(E.validate(0,T.Huffman{[4294967295,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],[]}))))

def bit_boundaries() -> IO(Unit):
  do IO<Unit>:
    check("MSB-first octet 128",read_value(E.read(E.start([128]),8),128))
    check("MSB-first octet 1",read_value(E.read(E.start([1]),8),1))
    check("FF00 unstuffing across byte",read_value(E.read(E.start([255,0,128]),9),511))
    check("zero category reads no marker",read_value(E.read(E.start([255,217]),0),0))
    check("empty entropy truncated",read_failed(E.read(E.start([]),1)))
    check("FF entropy truncated",read_failed(E.read(E.start([255]),1)))
    check("marker cannot become entropy",read_failed(E.read(E.start([255,217]),1)))
    check("fill cannot replace FF00 stuffing",read_failed(E.read(E.start([255,255,0]),1)))
    check("non-octet entropy rejected",read_failed(E.read(E.start([256]),1)))
    check("invalid residual cursor rejected",read_failed(E.read(E.Cursor{[],8,3},1)))
    check("cursor bits eight rejected",read_failed(E.read(E.Cursor{[],0,8},1)))
    check("magnitude width twelve rejected",read_failed(E.read(E.start([0,0]),12)))

def coefficients() -> IO(Unit):
  do IO<Unit>:
    # DC0 code0 + EOB0 + six one padding bits.
    check("all-zero block and EOI",decoded(decode([63,255,217],0.0),[],0.0))
    check("predictor carries with category zero",decoded(decode([63,255,217],5.0),[Cell{0,5.0}],5.0))
    # DC category2: code110, positive10 / negative01; EOB0.
    check("positive DC magnitude",decoded(decode([211,255,217],0.0),[Cell{0,2.0}],2.0))
    check("negative DC magnitude",decoded(decode([203,255,217],0.0),[Cell{0,F32.neg(2.0)}],F32.neg(2.0)))
    check("DC sign plus prior",decoded(decode([203,255,217],5.0),[Cell{0,3.0}],3.0))
    check("negative one DC",decoded(decode([143,255,217],0.0),[Cell{0,F32.neg(1.0)}],F32.neg(1.0)))
    check("positive one DC",decoded(decode([175,255,217],0.0),[Cell{0,1.0}],1.0))
    check("DC 2047 crosses stuffed FF",decoded(decode([255,0,239,254,255,217],0.0),[Cell{0,2047.0}],2047.0))
    check("DC -2047 sign extension",decoded(decode([255,0,224,0,255,217],0.0),[Cell{0,F32.neg(2047.0)}],F32.neg(2047.0)))
    check("DC -2048 predictor boundary",decoded(decode([255,0,224,0,255,217],F32.neg(1.0)),[Cell{0,F32.neg(2048.0)}],F32.neg(2048.0)))
    check("DC positive overflow rejected",rejected(decode([175,255,217],2047.0)))
    check("DC negative overflow rejected",rejected(decode([143,255,217],F32.neg(2048.0))))
    check("fractional predictor rejected",rejected(decode([63,255,217],0.5)))
    check("oversized predictor rejected",rejected(decode([63,255,217],2048.0)))
    # AC code10 + amplitude1 -> zigzag1; 110 + amplitude0 skips zigzag1.
    check("first AC positive",decoded(decode([87,255,217],0.0),[Cell{1,1.0}],0.0))
    check("run-one negative AC natural index8",decoded(decode([99,255,217],0.0),[Cell{8,F32.neg(1.0)}],0.0))
    check("ZRL advances sixteen then natural index19",decoded(decode([117,127,255,217],0.0),[Cell{19,1.0}],0.0))
    check("AC 1023 and stuffed entropy FF",decoded(decode([123,255,0,127,255,217],0.0),[Cell{1,1023.0}],0.0))
    check("AC -1023",decoded(decode([120,0,127,255,217],0.0),[Cell{1,F32.neg(1023.0)}],0.0))
    # DC0 + 63 repetitions of (AC code10, amplitude1); no EOB is needed.
    check("63 nonzero AC coefficients exhaust block",full_block(decode([91,109,182,219,109,182,219,109,182,219,109,182,219,109,182,219,109,182,219,109,182,219,109,183,255,217],0.0)))
    # Boundary table EOB0, ZRL10, run14/size1=110. Three ZRL reach49,
    # run14 writes index63; two ZRL + run14 write47 then final ZRL ends64.
    check("last coefficient exactly index63",decoded(E.block(E.start([85,191,255,217]),dc(),boundary(225),0.0),[Cell{63,1.0}],0.0))
    check("final ZRL ends exactly at64",decoded(E.block(E.start([86,223,255,217]),dc(),boundary(225),0.0),[Cell{51,1.0}],0.0))
    check("run beyond coefficient63 rejected",rejected(E.block(E.start([85,191,255,217]),dc(),boundary(241),0.0)))
    check("four ZRL exceed block",rejected(decode([119,119,127,255,217],0.0)))
    check("truncated DC magnitude",rejected(decode([255,0],0.0)))
    check("truncated AC magnitude",rejected(decode([123],0.0)))
    check("undefined Huffman prefix bounded at16",rejected(decode([255,0,255,0],0.0)))
    check("block independently validates DC table",rejected(E.block(E.start([0]),single(12),ac(),0.0)))
    check("block independently validates AC table",rejected(E.block(E.start([0]),dc(),single(16),0.0)))
    check("sixteen-bit DC and one-bit EOB",decoded(E.block(E.start([0,0,127,255,217]),T.Huffman{[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1],[0]},single(0),0.0),[],0.0))

def markers() -> IO(Unit):
  do IO<Unit>:
    check("restart boundary followed by zero predictor",restarted(decode([63,255,208,63,255,217],5.0)))
    check("restart allows FF fill and preserves tail",restarted_tail(E.restart(E.Cursor{[255,255,208,7],7,3},0)))
    check("restart7 exact marker",restarted_tail(E.restart(E.start([255,215,7]),7)))
    check("wrong restart order rejected",cursor_failed(E.restart(E.start([255,209]),0)))
    check("restart8 rejected",cursor_failed(E.restart(E.start([255,216]),8)))
    check("restart U32max rejected",cursor_failed(E.restart(E.start([255,208]),4294967295)))
    check("restart zero padding rejected",cursor_failed(E.restart(E.Cursor{[255,208],6,3},0)))
    check("restart marker prefix required",cursor_failed(E.restart(E.start([208]),0)))
    check("restart FF00 is data not marker",cursor_failed(E.restart(E.start([255,0,208]),0)))
    check("restart truncated FF rejected",cursor_failed(E.restart(E.start([255]),0)))
    check("EOI exact at byte boundary",okay(E.finish(E.start([255,217]))))
    check("EOI accepts FF fill",okay(E.finish(E.Cursor{[255,255,217],31,5})))
    check("EOI trailing byte rejected",Bool.not(okay(E.finish(E.start([255,217,0])))))
    check("EOI zero padding rejected",Bool.not(okay(E.finish(E.Cursor{[255,217],30,5}))))
    check("EOI missing rejected",Bool.not(okay(E.finish(E.start([])))))
    check("EOI truncated marker rejected",Bool.not(okay(E.finish(E.start([255])))))
    check("EOI wrong marker rejected",Bool.not(okay(E.finish(E.start([255,208])))))
    check("EOI stuffed FF rejected",Bool.not(okay(E.finish(E.start([255,0,217])))))
    check("EOI invalid residual count rejected",Bool.not(okay(E.finish(E.Cursor{[255,217],255,8}))))

def main() -> IO(Unit):
  do IO<Unit>:
    tables()
    bit_boundaries()
    coefficients()
    markers()
    check("all64 independent zigzag positions",zigzag_all([0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63],0))
    check("zigzag64 rejected",zigzag_failed(E.zigzag(64)))
    check("zigzag U32max rejected",zigzag_failed(E.zigzag(4294967295)))
