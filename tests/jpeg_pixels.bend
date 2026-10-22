import Base
import ../src/jpeg/types.bend as T
import ../src/jpeg/pixels.bend as P

# Pixel expectations are independent literals, not results of P.basis/P.sample.
# AC and mixed-block literals were evaluated from the T.81 A.3.3 double sum
# using host binary64 cosine. Approximate F32 IDCT permits at most one sample
# value of error; constant DC blocks and full-range JFIF colors remain exact.
# This tests chosen fixtures, not ISO/IEC 10918-2 decoder conformance.
def check(label: String,okay: Bool) -> IO(Unit):
  match okay:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL JPEG pixels: " ++ label)

def close(actual: List<U32>,expected: List<&2,U32>,+tolerance: U32) -> Bool:
  match actual expected:
    case Nil{} Nil{}: True{}
    case Con{+left,rest} Con{+right,tail}:
      U32.is_le(U32.sub(U32.max(left,right),U32.min(left,right)),tolerance) && close(rest,tail,tolerance)
    case _ _: False{}

def decoded(result: Result<&2,&1,T.Failure,Array<U32>>,expected: List<&2,U32>,tolerance: U32) -> Bool:
  match result:
    case Done{samples}: close(Array.to_list(U32,samples),expected,tolerance)
    case Fail{_}: False{}

def rejected(result: Result<&2,&1,T.Failure,Array<U32>>,kind: String) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{T.Failure{actual,_}}: String.eq(actual,kind)

def single(index: U32,value: F32) -> Array<F32>:
  Array.set(F32,Array.new(F32,6n,0.0),index,value)

def bits(value: U32) -> F32:
  U32{word} = value
  F32{word}

def constant(value: F32,quant: U32,expected: U32) -> Bool:
  decoded(P.block(single(0,value),List.replicate(U32,64n,quant)),List.replicate(U32,64n,expected),0)

def horizontal() -> List<&2,U32>:
  List.concat(&2,U32,List.replicate(List<&2,U32>,8n,[142,140,136,131,125,120,116,114]))

def vertical() -> List<&2,U32>:
  [142,142,142,142,142,142,142,142,
   140,140,140,140,140,140,140,140,
   136,136,136,136,136,136,136,136,
   131,131,131,131,131,131,131,131,
   125,125,125,125,125,125,125,125,
   120,120,120,120,120,120,120,120,
   116,116,116,116,116,116,116,116,
   114,114,114,114,114,114,114,114]

def mixed() -> Array<F32>:
  a = single(0,120.0)
  b = Array.set(F32,a,1,F32.neg(30.0))
  c = Array.set(F32,b,8,F32.neg(20.0))
  d = Array.set(F32,c,9,12.0)
  e = Array.set(F32,d,2,7.0)
  f = Array.set(F32,e,16,F32.neg(11.0))
  Array.set(F32,f,63,F32.neg(7.0))

# Quantization values are already in natural order; a zigzag interpretation
# would disagree with this nonsymmetric mixed block and the u=1/v=1 cases.
def varying_quant() -> List<&2,U32>:
  [1,2,3,4,5,6,7,1,2,3,4,5,6,7,1,2,
   3,4,5,6,7,1,2,3,4,5,6,7,1,2,3,4,
   5,6,7,1,2,3,4,5,6,7,1,2,3,4,5,6,
   7,1,2,3,4,5,6,7,1,2,3,4,5,6,7,1]

def mixed_expected() -> List<&2,U32>:
  [132,131,128,127,127,131,133,136,
   135,133,133,130,133,134,139,141,
   139,139,136,138,138,144,147,151,
   142,140,142,140,147,149,157,159,
   141,142,140,146,147,157,161,166,
   138,137,140,141,150,155,164,168,
   132,134,134,141,146,156,163,168,
   129,130,133,137,145,154,162,167]

def blocks() -> IO(Unit):
  do IO<Unit>:
    check("zero coefficients reverse level shift to128",constant(0.0,1,128))
    check("positive DC8 gives129",constant(8.0,1,129))
    check("negative DC8 gives127",constant(F32.neg(8.0),1,127))
    check("DC dequantization precedes IDCT",constant(80.0,2,148))
    check("negative DC dequantization",constant(F32.neg(80.0),2,108))
    check("DC full black",constant(F32.neg(1024.0),1,0))
    check("DC full white",constant(1016.0,1,255))
    check("minimum DC and quant255 clamp low",constant(F32.neg(2048.0),255,0))
    check("maximum DC and quant255 clamp high",constant(2047.0,255,255))
    check("u1 changes columns only within one sample",decoded(P.block(single(1,80.0),List.replicate(U32,64n,1)),horizontal(),1))
    check("v1 changes rows only within one sample",decoded(P.block(single(8,80.0),List.replicate(U32,64n,1)),vertical(),1))
    check("u1 natural quant2 scales coefficient40",decoded(P.block(single(1,40.0),varying_quant()),horizontal(),1))
    check("v1 natural quant2 scales coefficient40",decoded(P.block(single(8,40.0),varying_quant()),vertical(),1))
    check("mixed signed frequencies and nonuniform quantization within one sample",decoded(P.block(mixed(),varying_quant()),mixed_expected(),1))
    check("maximum AC and quant255 clamp every sample",decoded(P.block(single(1,1023.0),List.replicate(U32,64n,255)),List.concat(&2,U32,List.replicate(List<&2,U32>,8n,[255,255,255,255,0,0,0,0])),0))
    check("minimum AC and quant255 clamp every sample",decoded(P.block(single(1,F32.neg(1023.0)),List.replicate(U32,64n,255)),List.concat(&2,U32,List.replicate(List<&2,U32>,8n,[0,0,0,0,255,255,255,255])),0))

# The pinned native Array representation is a flat power-of-two block.
# Constructing unequal ANode children itself posts ERR_TAGS in blk_node,
# before the decoder can receive a value. Test that boundary in two bounded
# owned children, never call P.block there, and require exact runtime refusal.
# These are runtime constructor guards, separate from the 44 pixel/decoder
# assertions. Representable 32/128-value arrays still test typed block refusal.
def constructor_marker() -> String:
  "JPEG native ragged Array constructor probe"

def unexpected_array(pair: Array<F32> & U32) -> IO(Unit):
  (_,count) = pair
  IO.print("UNEXPECTED native ragged Array was constructed: " ++ U32.show(count))

def constructor_child(mode: String) -> IO(Unit):
  match mode:
    case "ragged-shorter":
      do IO<Unit>:
        IO.print(constructor_marker())
        unexpected_array(Array.size(F32,ANode{Array.new(F32,5n,0.0),Array.new(F32,4n,0.0)}))
    case "ragged-longer":
      do IO<Unit>:
        IO.print(constructor_marker())
        unexpected_array(Array.size(F32,ANode{Array.new(F32,5n,0.0),Array.new(F32,6n,0.0)}))
    case _: IO.die(Unit,2,"Unknown native Array constructor probe")

def constructor_refused(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Bool:
  match result:
    case Done{(1,(out,err))}:
      String.eq(out,constructor_marker() ++ "\n") && String.eq(err,"bend: runtime fail-stop\n")
    case _: False{}

def constructor_probe(self: String,mode: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(self,["constructor",mode],"",4096,2000)
    check(label,constructor_refused(result))

def malformed(+self: String) -> IO(Unit):
  do IO<Unit>:
    check("32 coefficients refused before indexing",rejected(P.block(Array.new(F32,5n,0.0),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("128 coefficients refused before indexing",rejected(P.block(Array.new(F32,7n,0.0),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    constructor_probe(self,"ragged-shorter","runtime refuses shorter right child during Array construction")
    constructor_probe(self,"ragged-longer","runtime refuses longer right child during Array construction")
    check("DC2048 refused",rejected(P.block(single(0,2048.0),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("DC minus2049 refused",rejected(P.block(single(0,F32.neg(2049.0)),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("AC1024 refused",rejected(P.block(single(1,1024.0),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("last AC minus1024 refused",rejected(P.block(single(63,F32.neg(1024.0)),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("fractional DC refused",rejected(P.block(single(0,0.5),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("fractional last AC refused",rejected(P.block(single(63,F32.neg(0.5)),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("quiet NaN DC refused",rejected(P.block(single(0,bits(2143289344)),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("positive infinity AC refused",rejected(P.block(single(1,bits(2139095040)),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("negative infinity last AC refused",rejected(P.block(single(63,bits(4286578688)),List.replicate(U32,64n,1)),"jpeg_coefficient"))
    check("63 quantizers refused",rejected(P.block(single(0,0.0),List.replicate(U32,63n,1)),"jpeg_quantization"))
    check("65 quantizers refused",rejected(P.block(single(0,0.0),List.replicate(U32,65n,1)),"jpeg_quantization"))
    check("empty quantizers refused",rejected(P.block(single(0,0.0),[]),"jpeg_quantization"))
    check("zero quantizer refused",rejected(P.block(single(0,0.0),0 <> List.replicate(U32,63n,1)),"jpeg_quantization"))
    check("quantizer256 refused",rejected(P.block(single(0,0.0),256 <> List.replicate(U32,63n,1)),"jpeg_quantization"))
    check("last hostile U32 quantizer refused",rejected(P.block(single(0,0.0),List.append(&2,U32,List.replicate(U32,63n,1),[4294967295])),"jpeg_quantization"))

def colors() -> IO(Unit):
  do IO<Unit>:
    check("neutral black opaque RRGGBBAA",U32.is_eq(P.rgb(0,128,128),255))
    check("neutral gray opaque RRGGBBAA",U32.is_eq(P.rgb(128,128,128),2155905279))
    check("neutral white opaque RRGGBBAA",U32.is_eq(P.rgb(255,128,128),4294967295))
    check("JFIF red near primary",U32.is_eq(P.rgb(76,85,255),4261413119))
    check("JFIF green near primary",U32.is_eq(P.rgb(150,44,21),16712191))
    check("JFIF blue near primary",U32.is_eq(P.rgb(29,255,107),65279))
    check("negative components clamp before integer conversion",U32.is_eq(P.rgb(0,0,0),8847615))
    check("oversized components clamp before integer conversion",U32.is_eq(P.rgb(255,255,255),4286185471))
    check("opposing chroma red",U32.is_eq(P.rgb(128,0,255),4283498751))
    check("opposing chroma blue",U32.is_eq(P.rgb(128,255,0),11599871))
    check("direct U32max callers are bounded",U32.is_eq(P.rgb(4294967295,4294967295,4294967295),4286185471))

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    blocks()
    malformed(self)
    colors()
    IO.print("Completed 44 JPEG pixel/decoder assertions and 2 native Array constructor guards.")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}: suite(self)
    case Con{_,Con{"constructor",Con{mode,Nil{}}}}: constructor_child(mode)
    case _: IO.die(Unit,2,"JPEG pixel test expects no arguments or its owned constructor probe")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
