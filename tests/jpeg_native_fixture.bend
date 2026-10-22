import Base
import ../benchmarks/jpeg_preview_fixture.bend as F
import ../src/attachment_decode.bend as Bytes
import ../src/attachment_image_decode.bend as ImageDecode
import ../src/attachment_image_types.bend as Image

type Sample is Data:
  Sample{index: U32,rgba: U32}

def check(okay: Bool,label: String) -> IO(Unit):
  match okay:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def decoded_bytes(result: Result<&2,&2,String,Bytes.Bytes>,count: U32,digest: String) -> IO(List<&2,U32>):
  match result:
    case Fail{message}: IO.die(List<&2,U32>,1,message)
    case Done{+value}:
      Bytes.Bytes{bytes,actual,hash} = value
      do IO<List<&2,U32>>:
        check(U32.is_eq(count,actual) && String.eq(digest,hash) && Bytes.valid(value),"native fixture strict base64 count and independent SHA256")
        return bytes

def samples() -> List<&2,Sample>:
  [Sample{32800,255},Sample{32896,3913172223},Sample{33152,867198207},Sample{33408,710926335},Sample{33664,4070912511},Sample{33760,4070912511},Sample{163872,3913172223},Sample{163968,3913172223},Sample{164224,867198207},Sample{164480,710926335},Sample{164736,4070912511},Sample{164832,4070912511},Sample{491552,808929279},Sample{491648,808929279},Sample{491904,3907378431},Sample{492160,3191910143},Sample{492416,1184289279},Sample{492512,1184289279},Sample{622624,808929279},Sample{622720,808929279},Sample{622976,3907378431},Sample{623232,3191910143},Sample{623488,1184289279},Sample{623584,4294967295}]

def next_sample(pair: Array<U32> & U32,expected: U32,index: U32,next: Array<U32> -> IO(Unit)) -> IO(Unit):
  (pixels,actual) = pair
  do IO<Unit>:
    check(U32.is_eq(actual,expected),"independent full-size JPEG sample at index " ++ U32.show(index))
    next(pixels)

def inspect(items: List<&2,Sample>,pixels: Array<U32>,+count: U32) -> IO(Unit):
  match items:
    case []: IO.pure(Unit,Unit{})
    case Sample{+index,value} <> rest:
      do IO<Unit>:
        check(U32.is_lt(index,count),"native fixture oracle index within admitted raster")
        next_sample(Array.get(U32,pixels,index),value,index,after => inspect(rest,after,count))

def image(result: Result<&2,&1,String,Image.Raster>) -> IO(Unit):
  match result:
    case Fail{message}: IO.die(Unit,1,message)
    case Done{Image.Raster{width,height,+count,capacity,pixels,notice}}:
      do IO<Unit>:
        check(U32.is_eq(width,1024) && U32.is_eq(height,640) && U32.is_eq(count,655360) && U32.is_eq(capacity,1048576) && Bool.not(notice),"actual native JPEG fixture decodes with exact bounded geometry")
        inspect(samples(),pixels,count)

def unsupported(result: Result<&2,&1,String,Image.Raster>) -> Bool:
  match result:
    case Fail{message}: String.starts_with(message,"unsupported_jpeg_progressive:")
    case Done{_}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    bytes : List<&2,U32> <- decoded_bytes(Bytes.decode(F.image_data()),F.image_count(),F.image_digest())
    image(ImageDecode.decode(bytes))
    progressive : List<&2,U32> <- decoded_bytes(Bytes.decode(F.progressive_data()),F.progressive_count(),F.progressive_digest())
    check(unsupported(ImageDecode.decode(progressive)),"real progressive fixture has an explicit unsupported state")
