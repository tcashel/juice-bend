import Base
import ../src/jpeg/types.bend as T
import ../src/jpeg/pixels.bend as P

# Differential regression checks for the admitted DC-only shortcut. The dense
# reference calls the unchanged production passes; it does not reimplement the
# basis, accumulation, rounding or validation algorithms. Independent JPEG
# decoder fixtures remain separate accuracy checks, not a conformance claim.
def dense(values: Array<F32>,+quant: List<&2,U32>) -> Result<&2,&1,T.Failure,Array<U32>>:
  do Result<&2,&1,T.Failure,Array<U32>>:
    _ : Unit <- T.widen(Unit,T.require(P.quantizers(64n,quant),"jpeg_quantization","Baseline JPEG quantizer needs exactly 64 values in 1..255"))
    checked : Array<F32> <- P.coefficients(6n,values,True{})
    dequant : Array<F32> <- P.dequantize(quant,0,checked)
    horizontal : Array<F32> <- P.pass_walk(64n,0,False{},dequant,Array.new(F32,6n,0.0))
    vertical : Array<F32> <- P.pass_walk(64n,0,True{},horizontal,Array.new(F32,6n,0.0))
    P.shift(64n,0,vertical,Array.new(U32,6n,0))

# A successful comparison requires exactly 64 equal bytes on both sides.
def equal(fuel: Nat,actual: List<U32>,expected: List<U32>) -> Bool:
  match fuel actual expected:
    case 0n Nil{} Nil{}: True{}
    case 1n+rest Con{left,tail} Con{right,remaining}:
      U32.is_eq(left,right) && equal(rest,tail,remaining)
    case _ _ _: False{}

def compared(actual: Result<&2,&1,T.Failure,Array<U32>>,expected: Result<&2,&1,T.Failure,Array<U32>>) -> Bool:
  match actual expected:
    case Done{left} Done{right}: equal(64n,Array.to_list(U32,left),Array.to_list(U32,right))
    case _ _: False{}

def same_pair(pair: Array<F32> & Array<F32>,+quant: List<&2,U32>) -> Bool:
  (actual,expected) = pair
  compared(P.block(actual,quant),dense(expected,quant))

def same(values: Array<F32>,quant: List<&2,U32>) -> Bool:
  same_pair(Array.clone(F32,values),quant)

def check(okay: Bool,label: String) -> IO(Unit):
  match okay:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL JPEG DC fast path: " ++ label)

def single(index: U32,value: F32) -> Array<F32>:
  Array.set(F32,Array.new(F32,6n,0.0),index,value)

def bits(value: U32) -> F32:
  U32{word} = value
  F32{word}

def constant(value: F32) -> Bool:
  same(single(0,value),List.replicate(U32,64n,1))

def varying_quant() -> List<&2,U32>:
  [1,2,3,4,5,6,7,1,2,3,4,5,6,7,1,2,
   3,4,5,6,7,1,2,3,4,5,6,7,1,2,3,4,
   5,6,7,1,2,3,4,5,6,7,1,2,3,4,5,6,
   7,1,2,3,4,5,6,7,1,2,3,4,5,6,7,1]

def mixed() -> Array<F32>:
  a = single(0,120.0)
  b = Array.set(F32,a,1,F32.neg(30.0))
  c = Array.set(F32,b,8,F32.neg(20.0))
  d = Array.set(F32,c,9,12.0)
  e = Array.set(F32,d,2,7.0)
  f = Array.set(F32,e,16,F32.neg(11.0))
  Array.set(F32,f,63,F32.neg(7.0))

def negative_zero() -> Bool:
  same(Array.new(F32,6n,bits(2147483648)),varying_quant()) &&
    compared(P.block(Array.new(F32,6n,bits(2147483648)),varying_quant()),
      Done{Array.new(U32,6n,128)})

def rejected(result: Result<&2,&1,T.Failure,Array<U32>>,kind: String) -> Bool:
  match result:
    case Fail{T.Failure{actual,_}}: String.eq(actual,kind)
    case Done{_}: False{}

def dc_boundaries() -> IO(Unit):
  do IO<Unit>:
    check(constant(3.0),"DC +3 matches every dense byte below the half step")
    check(constant(4.0),"DC +4 matches every dense byte at the half step")
    check(constant(5.0),"DC +5 matches every dense byte above the half step")
    check(constant(F32.neg(3.0)),"DC -3 matches every dense byte above the negative half step")
    check(constant(F32.neg(4.0)),"DC -4 matches every dense byte at the negative half step")
    check(constant(F32.neg(5.0)),"DC -5 matches every dense byte below the negative half step")
    check(constant(1003.0),"DC +1003 preserves dense rounding near the high sample bound")
    check(constant(1004.0),"DC +1004 preserves the dense high half step")
    check(constant(1005.0),"DC +1005 preserves dense rounding above the high half step")
    check(constant(F32.neg(1003.0)),"DC -1003 preserves dense rounding near the low sample bound")
    check(constant(F32.neg(1004.0)),"DC -1004 preserves the dense low half step")
    check(constant(F32.neg(1005.0)),"DC -1005 preserves dense rounding below the low half step")
    check(same(single(0,1.0),4 <> List.replicate(U32,63n,1)),"DC +1 quantizer 4 preserves dequantization before both F32 passes")
    check(same(single(0,F32.neg(1.0)),4 <> List.replicate(U32,63n,1)),"DC -1 quantizer 4 preserves dequantization before both F32 passes")
    check(same(single(0,80.0),varying_quant()),"nonuniform AC quantizers leave DC-only output byte identical")
    check(negative_zero(),"all negative-zero coefficients produce exactly 64 samples of 128")

def ac_fallbacks() -> IO(Unit):
  do IO<Unit>:
    check(same(single(1,80.0),varying_quant()),"positive first horizontal AC retains every dense byte")
    check(same(single(1,F32.neg(80.0)),varying_quant()),"negative first horizontal AC retains every dense byte")
    check(same(single(8,80.0),varying_quant()),"positive first vertical AC retains every dense byte")
    check(same(single(8,F32.neg(80.0)),varying_quant()),"negative first vertical AC retains every dense byte")
    check(same(single(63,80.0),varying_quant()),"positive final AC prevents a premature DC-only decision")
    check(same(single(63,F32.neg(80.0)),varying_quant()),"negative final AC prevents a premature DC-only decision")
    check(same(mixed(),varying_quant()),"mixed signed frequencies and natural-order quantizers remain exactly byte identical")

def invalid_tail() -> IO(Unit):
  do IO<Unit>:
    check(rejected(P.block(single(63,bits(2143289344)),List.replicate(U32,64n,1)),"jpeg_coefficient"),
      "late NaN cannot be ignored after an otherwise zero coefficient prefix")
    check(rejected(P.block(single(63,bits(2143289344)),List.append(&2,U32,List.replicate(U32,63n,1),[0])),"jpeg_quantization"),
      "invalid final quantizer retains precedence over invalid final coefficient")

def main() -> IO(Unit):
  do IO<Unit>:
    dc_boundaries()
    ac_fallbacks()
    invalid_tail()
    IO.print("Completed 25 JPEG DC fast-path regression assertions.")
