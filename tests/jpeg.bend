import Base
import ../src/attachment_jpeg.bend as Jpeg
import ../src/attachment_image_types.bend as Image
import ../src/jpeg/types.bend as T
import ../src/jpeg/headers.bend as Headers
import ../src/jpeg/metadata.bend as Metadata
import ./jpeg_fixtures.bend as F

type Stats is Data:
  Stats{count: U32,maximum: U32,alpha_bad: Bool}

def assert(value: Bool,label: String) -> IO(Unit):
  match value:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def difference(+a: U32,+b: U32) -> U32:
  U32.sub(U32.max(a,b),U32.min(a,b))

def channel(+a: U32,+b: U32) -> U32:
  U32.max(difference(Image.component(a,24n),Image.component(b,24n)),U32.max(difference(Image.component(a,16n),Image.component(b,16n)),difference(Image.component(a,8n),Image.component(b,8n))))

def compared(pair: Array<U32> & U32,+wanted: U32,count: U32,+maximum: U32,alpha_bad: Bool,next: Array<U32> -> Stats -> Stats) -> Stats:
  (pixels,+value) = pair
  next(pixels,Stats{count,U32.max(maximum,channel(value,wanted)),alpha_bad || U32.is_ne(Image.component(value,0n),255)})

def samples(expected: List<&2,U32>,pixels: Array<U32>,stats: Stats) -> Stats:
  match expected:
    case []: stats
    case wanted <> rest:
      Stats{+count,maximum,alpha_bad} = stats
      compared(Array.get(U32,pixels,count),wanted,U32.inc(count),maximum,alpha_bad,after => next => samples(rest,after,next))

def reported(stats: Stats,count: U32,tolerance: U32,+label: String) -> IO(Unit):
  Stats{actual,+maximum,bad} = stats
  do IO<Unit>:
    IO.print("JPEG maximum channel difference " ++ label ++ ": " ++ U32.show(maximum))
    assert(U32.is_eq(actual,count) && U32.is_le(maximum,tolerance) && Bool.not(bad),label)

def raster(value: Image.Raster,+width: U32,+height: U32,expected: List<&2,U32>,tolerance: U32,notice: Bool,+label: String) -> IO(Unit):
  Image.Raster{w,h,+count,+capacity,pixels,actual_notice} = value
  do IO<Unit>:
    assert(U32.is_eq(w,width) && U32.is_eq(h,height) && U32.is_eq(count,U32.mul(width,height)) && U32.is_ge(capacity,count) && U32.is_le(capacity,T.max_pixels()) && U32.is_eq(Bool.to_u32(notice),Bool.to_u32(actual_notice)),label ++ " dimensions and color notice")
    reported(samples(expected,pixels,Stats{0,0,False{}}),count,tolerance,label)

def decoded(result: Result<&2,&1,T.Failure,Image.Raster>,width: U32,height: U32,expected: List<&2,U32>,tolerance: U32,notice: Bool,label: String) -> IO(Unit):
  match result:
    case Fail{T.Failure{kind,detail}}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ kind ++ " " ++ detail)
    case Done{value}: raster(value,width,height,expected,tolerance,notice,label)

def valid(bytes: List<&2,U32>,width: U32,height: U32,expected: List<&2,U32>,tolerance: U32,notice: Bool,label: String) -> IO(Unit):
  decoded(Jpeg.decode(bytes),width,height,expected,tolerance,notice,label)

def rejected(result: Result<&2,&1,T.Failure,Image.Raster>,wanted: String) -> Bool:
  match result:
    case Fail{T.Failure{kind,_}}: String.eq(kind,wanted)
    case Done{_}: False{}

def invalid(bytes: List<&2,U32>,kind: String,label: String) -> IO(Unit):
  assert(rejected(Jpeg.decode(bytes),kind),label)

def replace(fuel: Nat,bytes: List<&2,U32>,value: U32) -> List<&2,U32>:
  match fuel bytes:
    case 0n Con{_,tail}: value <> tail
    case 1n+rest Con{head,tail}: head <> replace(rest,tail,value)
    case _ _: []

def prefix(fuel: Nat,bytes: List<&2,U32>) -> List<&2,U32>:
  match fuel bytes:
    case 0n _: []
    case 1n+rest Con{head,tail}: head <> prefix(rest,tail)
    case _ _: []

def repeat(fuel: Nat,+value: U32) -> List<&2,U32>:
  match fuel:
    case 0n: []
    case 1n+rest: value <> repeat(rest,value)

def insert(bytes: List<&2,U32>,metadata: List<&2,U32>) -> List<&2,U32>:
  match bytes:
    case 255 <> 216 <> rest: 255 <> 216 <> List.append(&2,U32,metadata,rest)
    case _: []

def exif(orientation: U32) -> List<&2,U32>:
  [255,225,0,34,69,120,105,102,0,0,73,73,42,0,8,0,0,0,1,0,18,1,3,0,1,0,0,0,orientation,0,0,0,0,0,0,0]

def success() -> IO(Unit):
  do IO<Unit>:
    valid(F.gray_constant_bytes(),8,8,F.gray_constant_expected(),0,False{},"grayscale constant independently decodes exactly")
    valid(F.gray_edges_bytes(),9,7,F.gray_edges_expected(),2,False{},"grayscale AC and partial edge block match independent float IDCT")
    valid(F.ycbcr_444_bytes(),17,9,F.ycbcr_444_expected(),2,False{},"YCbCr 4:4:4 asymmetric edges match independent decoder")
    valid(F.ycbcr_422_bytes(),17,13,F.ycbcr_422_expected(),2,False{},"YCbCr 4:2:2 nearest chroma expansion matches independent decoder")
    valid(F.ycbcr_420_bytes(),19,17,F.ycbcr_420_expected(),2,False{},"YCbCr 4:2:0 nearest chroma expansion matches independent decoder")
    valid(F.ycbcr_440_bytes(),13,19,F.ycbcr_440_expected(),2,False{},"YCbCr 4:4:0 vertical subsampling matches independent decoder")
    valid(F.adobe_rgb_bytes(),11,9,F.adobe_rgb_expected(),2,True{},"Adobe RGB sample interpretation remains distinct from YCbCr")
    valid(F.restart_420_bytes(),33,17,F.restart_420_expected(),2,False{},"restart intervals reset every component predictor and crop padded MCUs")
    valid(insert(F.gray_constant_bytes(),exif(1)),8,8,F.gray_constant_expected(),0,True{},"Exif identity orientation keeps exact samples with metadata notice")

def refusals() -> IO(Unit):
  do IO<Unit>:
    invalid([256],"invalid_input","non-octet refuses before parsing")
    invalid([1,2,3],"unsupported_image_format","non-JPEG retained bytes remain an explicit unsupported format")
    invalid(repeat(1048577n,0),"image_resource_limit","compressed input cap is independent of frame metadata")
    invalid(List.append(&2,U32,F.gray_constant_bytes(),[0]),"jpeg_entropy","trailing bytes cannot extend the declared JPEG image")
    invalid(prefix(331n,F.gray_constant_bytes()),"jpeg_entropy","missing final EOI is refused")
    invalid(replace(90n,F.gray_constant_bytes(),194),"unsupported_jpeg_progressive","progressive frame mode remains named unfinished parity")
    invalid(replace(90n,F.gray_constant_bytes(),193),"unsupported_jpeg_mode","extended sequential mode is not silently treated as baseline")
    invalid(replace(93n,F.gray_constant_bytes(),12),"unsupported_jpeg_mode","twelve-bit sample precision is explicit unsupported")
    invalid(replace(97n,replace(96n,F.gray_constant_bytes(),8),1),"image_resource_limit","oversized dimension is refused before raster allocation")
    invalid(replace(95n,replace(94n,replace(97n,replace(96n,F.gray_constant_bytes(),8),0),2),1),"image_resource_limit","pixel product bound is checked before raster allocation")
    invalid(replace(25n,F.gray_constant_bytes(),0),"invalid_jpeg","zero quantization value is invalid")
    invalid(replace(24n,F.gray_constant_bytes(),16),"unsupported_jpeg_mode","sixteen-bit quantization remains explicit unsupported")
    invalid(replace(109n,replace(107n,F.gray_constant_bytes(),2),3),"jpeg_huffman","oversubscribed Huffman table is refused")
    invalid(replace(824n,F.restart_420_bytes(),209),"jpeg_entropy","wrong restart sequence number is refused")
    invalid(replace(6n,F.ycbcr_420_bytes(),88),"unsupported_jpeg_color","unidentified three-component color interpretation is refused")
    invalid(replace(167n,F.ycbcr_420_bytes(),4),"unsupported_jpeg_color","CMYK component count remains explicit unsupported")
    invalid(insert(F.gray_constant_bytes(),exif(6)),"unsupported_jpeg_orientation","rotated Exif remains explicit unsupported without misleading pixels")
    invalid(insert(F.gray_constant_bytes(),[255,238,0,14,65,100,111,98,101,0,100,0,0,0,0,2]),"unsupported_jpeg_color","grayscale cannot ignore contradictory Adobe YCCK transform")

def main() -> IO(Unit):
  do IO<Unit>:
    success()
    refusals()
