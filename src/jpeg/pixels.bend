import Base
import ./types.bend as T

# ITU-T T.81 A.3.3: B[x,u] = C(u)/2 * cos((2*x+1)*u*pi/16).
# Natural-order coefficients are [v*8+u]; output samples are [y*8+x].
# Two bounded passes use 1024 multiplications, after 64 exact integer
# dequantizations. Constants and accumulation use the pinned IEEE F32 backend;
# this is an approximate IDCT, not an ISO/IEC 10918-2 conformance claim.
def basis(row: U32,column: U32) -> F32:
  match row column:
    case _ 0: 0.3535533905932738
    case 0 1: 0.4903926402016152
    case 0 2: 0.4619397662556434
    case 0 3: 0.4157348061512726
    case 0 4: 0.3535533905932738
    case 0 5: 0.2777851165098011
    case 0 6: 0.1913417161825449
    case 0 7: 0.0975451610080642
    case 1 1: 0.4157348061512726
    case 1 2: 0.1913417161825449
    case 1 3: F32.neg(0.0975451610080641)
    case 1 4: F32.neg(0.3535533905932737)
    case 1 5: F32.neg(0.4903926402016152)
    case 1 6: F32.neg(0.4619397662556434)
    case 1 7: F32.neg(0.2777851165098011)
    case 2 1: 0.2777851165098011
    case 2 2: F32.neg(0.1913417161825449)
    case 2 3: F32.neg(0.4903926402016152)
    case 2 4: F32.neg(0.3535533905932738)
    case 2 5: 0.0975451610080642
    case 2 6: 0.4619397662556433
    case 2 7: 0.4157348061512727
    case 3 1: 0.0975451610080642
    case 3 2: F32.neg(0.4619397662556434)
    case 3 3: F32.neg(0.2777851165098011)
    case 3 4: 0.3535533905932737
    case 3 5: 0.4157348061512727
    case 3 6: F32.neg(0.1913417161825450)
    case 3 7: F32.neg(0.4903926402016153)
    case 4 1: F32.neg(0.0975451610080641)
    case 4 2: F32.neg(0.4619397662556434)
    case 4 3: 0.2777851165098009
    case 4 4: 0.3535533905932738
    case 4 5: F32.neg(0.4157348061512726)
    case 4 6: F32.neg(0.1913417161825453)
    case 4 7: 0.4903926402016152
    case 5 1: F32.neg(0.2777851165098010)
    case 5 2: F32.neg(0.1913417161825452)
    case 5 3: 0.4903926402016152
    case 5 4: F32.neg(0.3535533905932733)
    case 5 5: F32.neg(0.0975451610080640)
    case 5 6: 0.4619397662556437
    case 5 7: F32.neg(0.4157348061512720)
    case 6 1: F32.neg(0.4157348061512727)
    case 6 2: 0.1913417161825450
    case 6 3: 0.0975451610080644
    case 6 4: F32.neg(0.3535533905932736)
    case 6 5: 0.4903926402016153
    case 6 6: F32.neg(0.4619397662556432)
    case 6 7: 0.2777851165098008
    case 7 1: F32.neg(0.4903926402016152)
    case 7 2: 0.4619397662556433
    case 7 3: F32.neg(0.4157348061512721)
    case 7 4: 0.3535533905932733
    case 7 5: F32.neg(0.2777851165098008)
    case 7 6: 0.1913417161825431
    case 7 7: F32.neg(0.0975451610080643)
    case _ _: 0.0

# Range comparisons reject NaN/infinities before arithmetic. Exact baseline
# integers are representable in F32; a fractional coefficient is not accepted.
def coefficient(+value: F32,+dc: Bool) -> Bool:
  F32.is_ge(value,Bool.pick(F32,dc,F32.neg(2048.0),F32.neg(1023.0))) &&
    F32.is_le(value,Bool.pick(F32,dc,2047.0,1023.0)) &&
    F32.is_eq(value,F32.floor(value))

# Array.size assumes a balanced tree. Check the whole fixed shape instead,
# rejecting short, long and irregular arrays before any wrapping get/set.
def coefficients(depth: Nat,value: Array<F32>,dc: Bool) -> Result<&2,&1,T.Failure,Array<F32>>:
  match depth value:
    case 0n ALeaf{+sample}:
      do Result<&2,&1,T.Failure,Array<F32>>:
        _ : Unit <- T.widen(Unit,T.require(coefficient(sample,dc),"jpeg_coefficient","JPEG coefficient must be a finite baseline integer"))
        Done{ALeaf{sample}}
    case 1n+ +rest ANode{left,right}:
      do Result<&2,&1,T.Failure,Array<F32>>:
        checked_left : Array<F32> <- coefficients(rest,left,dc)
        checked_right : Array<F32> <- coefficients(rest,right,False{})
        Done{ANode{checked_left,checked_right}}
    case _ _: Fail{T.Failure{"jpeg_coefficient","JPEG coefficient block must contain exactly 64 natural-order values"}}

def quantizers(fuel: Nat,values: List<&2,U32>) -> Bool:
  match fuel values:
    case 0n Nil{}: True{}
    case 1n+rest Con{+value,tail}: U32.is_ge(value,1) && U32.is_le(value,255) && quantizers(rest,tail)
    case _ _: False{}

def unpack(-R: Type,pair: Array<F32> & F32,next: Array<F32> -> F32 -> R) -> R:
  (values,value) = pair
  next(values,value)

def dequantize(quants: List<&2,U32>,+index: U32,values: Array<F32>) -> Result<&2,&1,T.Failure,Array<F32>>:
  match quants:
    case []:
      do Result<&2,&1,T.Failure,Array<F32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_eq(index,64),"jpeg_quantization","JPEG dequantization block length mismatch"))
        Done{values}
    case +quant <> rest:
      do Result<&2,&1,T.Failure,Array<F32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64) && U32.is_ge(quant,1) && U32.is_le(quant,255),"jpeg_quantization","JPEG dequantization index or quantizer exceeds admitted block"))
        unpack(Result<&2,&1,T.Failure,Array<F32>>,Array.get(F32,values,index),values => value =>
          dequantize(rest,U32.inc(index),Array.set(F32,values,index,F32.mul(value,U32.to_f32(quant)))))

def dot(fuel: Nat,values: Array<F32>,+index: U32,+vertical: Bool,+frequency: U32,sum: F32) -> Result<&2,&1,T.Failure,Array<F32> & F32>:
  match fuel:
    case 0n: Done{(values,sum)}
    case 1n+rest:
      do Result<&2,&1,T.Failure,Array<F32> & F32>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64) && U32.is_lt(frequency,8),"jpeg_idct","JPEG IDCT index exceeds fixed block"))
        +coordinate : U32 = Bool.pick(U32,vertical,U32.div(index,8),U32.mod(index,8))
        +source : U32 = Bool.pick(U32,vertical,U32.add(U32.mul(frequency,8),U32.mod(index,8)),U32.add(U32.mul(U32.div(index,8),8),frequency))
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(source,64) && U32.is_lt(coordinate,8),"jpeg_idct","JPEG IDCT source or basis index exceeds fixed block"))
        unpack(Result<&2,&1,T.Failure,Array<F32> & F32>,Array.get(F32,values,source),values => value =>
          dot(rest,values,index,vertical,U32.inc(frequency),F32.add(sum,F32.mul(value,basis(coordinate,frequency)))))

def pass_walk(fuel: Nat,+index: U32,+vertical: Bool,values: Array<F32>,output: Array<F32>) -> Result<&2,&1,T.Failure,Array<F32>>:
  match fuel:
    case 0n: Done{output}
    case 1n+rest:
      do Result<&2,&1,T.Failure,Array<F32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64),"jpeg_idct","JPEG IDCT output exceeds fixed block"))
        pair : Array<F32> & F32 <- dot(8n,values,index,vertical,0,0.0)
        unpack(Result<&2,&1,T.Failure,Array<F32>>,pair,values => value =>
          pass_walk(rest,U32.inc(index),vertical,values,Array.set(F32,output,index,value)))

# Round half upward after clamping. No negative/oversized F32 reaches to_u32.
def sample(value: F32) -> U32:
  F32.to_u32(F32.floor(F32.add(F32.clamp(value,0.0,255.0),0.5)))

def shift(fuel: Nat,+index: U32,values: Array<F32>,output: Array<U32>) -> Result<&2,&1,T.Failure,Array<U32>>:
  match fuel:
    case 0n: Done{output}
    case 1n+rest:
      do Result<&2,&1,T.Failure,Array<U32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64),"jpeg_idct","JPEG level-shift index exceeds fixed block"))
        unpack(Result<&2,&1,T.Failure,Array<U32>>,Array.get(F32,values,index),values => value =>
          shift(rest,U32.inc(index),values,Array.set(U32,output,index,sample(F32.add(value,128.0)))))

type Inspected is Type:
  Inspected{values: Array<F32>,zero_ac: Bool}

def inspected_pair(left: Inspected,right: Inspected) -> Inspected:
  Inspected{left,left_zero} = left
  Inspected{right,right_zero} = right
  Inspected{ANode{left,right},left_zero && right_zero}

# Called only after coefficients has checked the complete fixed shape and all
# 64 finite baseline integers. Carry the affine array through the inspection;
# no copy of the coefficient block is needed to choose the dense fallback.
def inspect_ac(depth: Nat,values: Array<F32>,dc: Bool) -> Inspected:
  match depth values:
    case 0n ALeaf{+value}: Inspected{ALeaf{value},dc || F32.is_eq(value,0.0)}
    case 1n+ +rest ANode{left,right}:
      inspected_pair(inspect_ac(rest,left,dc),inspect_ac(rest,right,False{}))
    case _ other: Inspected{other,False{}}

# With every AC value zero the two original passes are constant. Keep their
# two separately rounded F32 products and initial additions in the same order;
# replacing them with division by eight can change half-sample rounding.
def dc_samples(quant: U32,pair: Array<F32> & F32) -> Array<U32>:
  (_,value) = pair
  dequant = F32.mul(value,U32.to_f32(quant))
  horizontal = F32.add(0.0,F32.mul(dequant,basis(0,0)))
  vertical = F32.add(0.0,F32.mul(horizontal,basis(0,0)))
  Array.new(U32,6n,sample(F32.add(vertical,128.0)))

def transform(zero_ac: Bool,quant: List<&2,U32>,values: Array<F32>) -> Result<&2,&1,T.Failure,Array<U32>>:
  match zero_ac:
    case True{}:
      match quant:
        case first <> _: Done{dc_samples(first,Array.get(F32,values,0))}
        case []: Fail{T.Failure{"jpeg_quantization","Baseline JPEG quantizer needs exactly 64 values in 1..255"}}
    case False{}:
      do Result<&2,&1,T.Failure,Array<U32>>:
        dequant : Array<F32> <- dequantize(quant,0,values)
        horizontal : Array<F32> <- pass_walk(64n,0,False{},dequant,Array.new(F32,6n,0.0))
        vertical : Array<F32> <- pass_walk(64n,0,True{},horizontal,Array.new(F32,6n,0.0))
        shift(64n,0,vertical,Array.new(U32,6n,0))

def inspected_block(inspected: Inspected,quant: List<&2,U32>) -> Result<&2,&1,T.Failure,Array<U32>>:
  Inspected{values,zero_ac} = inspected
  transform(zero_ac,quant,values)

def block(values: Array<F32>,+quant: List<&2,U32>) -> Result<&2,&1,T.Failure,Array<U32>>:
  do Result<&2,&1,T.Failure,Array<U32>>:
    _ : Unit <- T.widen(Unit,T.require(quantizers(64n,quant),"jpeg_quantization","Baseline JPEG quantizer needs exactly 64 values in 1..255"))
    checked : Array<F32> <- coefficients(6n,values,True{})
    inspected_block(inspect_ac(6n,checked,True{}),quant)

# JFIF 1.02 p.3 full-range YCbCr conversion, no gamma/color management claim.
# Driver supplies admitted 8-bit samples; clamp here also bounds direct callers.
def rgb(+y: U32,+cb: U32,+cr: U32) -> U32:
  +luma = U32.to_f32(U32.min(y,255))
  +blue = F32.sub(U32.to_f32(U32.min(cb,255)),128.0)
  +red = F32.sub(U32.to_f32(U32.min(cr,255)),128.0)
  +r = sample(F32.add(luma,F32.mul(1.402,red)))
  +g = sample(F32.sub(F32.sub(luma,F32.mul(0.34414,blue)),F32.mul(0.71414,red)))
  +b = sample(F32.add(luma,F32.mul(1.772,blue)))
  U32.or(U32.or(U32.shln(r,24n),U32.shln(g,16n)),U32.or(U32.shln(b,8n),255))
