import Base
import ../src/attachment_png.bend as Png
import ../src/attachment_image_types.bend as T
import ../src/png/checksum.bend as Checksum
import ../src/png/pixels.bend as Pixels
import ./png_fixtures.bend as F

def assert(value: Bool,label: String) -> IO(Unit):
  match value:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def next_pixel(pair: Array<U32> & U32,wanted: U32,next: Array<U32> -> Bool) -> Bool:
  (pixels,actual) = pair
  T.branch(Bool,U32.is_eq(actual,wanted),_ => next(pixels),_ => False{})

def equal_pixels(expected: List<&2,U32>,pixels: Array<U32>,+index: U32,+count: U32,+capacity: U32) -> Bool:
  match expected:
    case []: U32.is_eq(index,count)
    case wanted <> rest:
      T.branch(Bool,U32.is_lt(index,count) && U32.is_lt(index,capacity),
        _ => next_pixel(Array.get(U32,pixels,index),wanted,after => equal_pixels(rest,after,U32.inc(index),count,capacity)),_ => False{})

def raster(value: T.Raster,+width: U32,+height: U32,expected: List<&2,U32>,notice: Bool) -> Bool:
  T.Raster{w,h,+count,+capacity,pixels,actual_notice} = value
  T.branch(Bool,U32.is_eq(w,width) && U32.is_eq(h,height) && U32.is_eq(count,U32.mul(width,height)) &&
    U32.is_ge(capacity,count) && U32.is_le(capacity,T.max_pixels()) && U32.is_eq(Bool.to_u32(notice),Bool.to_u32(actual_notice)),
    _ => equal_pixels(expected,pixels,0,count,capacity),_ => False{})

def decoded(result: Result<&2,&1,T.Failure,T.Raster>,width: U32,height: U32,expected: List<&2,U32>,notice: Bool) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{value}: raster(value,width,height,expected,notice)

def failed(result: Result<&2,&1,T.Failure,T.Raster>,expected: String) -> Bool:
  match result:
    case Fail{T.Failure{kind,_}}: String.eq(T.label(kind),expected)
    case Done{_}: False{}

def valid(bytes: List<&2,U32>,width: U32,height: U32,expected: List<&2,U32>,notice: Bool,label: String) -> IO(Unit):
  assert(decoded(Png.decode(bytes),width,height,expected,notice),label)

def invalid(bytes: List<&2,U32>,expected: String,label: String) -> IO(Unit):
  assert(failed(Png.decode(bytes),expected),label)

def expected_rgba() -> List<&2,U32>:
  [4278190335,16711808,65280,287392255,3362009601,4294967295,127,845465854,84413717,574052752]

def repeat(fuel: Nat,+byte: U32) -> List<&2,U32>:
  match fuel:
    case 0n: []
    case 1n+rest: byte <> repeat(rest,byte)

def layout_good(value: Result<&2,&2,T.Failure,T.Layout>) -> Bool:
  match value:
    case Done{T.Layout{2048,512,4,1048576,8192,4194816}}: True{}
    case _: False{}

def layout_bad(value: Result<&2,&2,T.Failure,T.Layout>,expected: String) -> Bool:
  match value:
    case Fail{T.Failure{kind,_}}: String.eq(T.label(kind),expected)
    case _: False{}

def pure() -> IO(Unit):
  do IO<Unit>:
    assert(U32.is_eq(Checksum.crc([49,50,51,52,53,54,55,56,57]),3421780262),"CRC32 independent123456789 check vector")
    assert(U32.is_eq(Checksum.adler([87,105,107,105,112,101,100,105,97]),300286872),"Adler32 independent Wikipedia check vector")
    assert(U32.is_eq(Checksum.crc([]),0) && U32.is_eq(Checksum.adler([]),1),"empty checksum identities")
    assert(U32.is_eq(T.rgba(1,2,3,4),16909060),"RGBA packing keeps channel and alpha byte order")
    assert(U32.is_eq(T.rgb(4278190335,66051),16711680),"opaque native RGB sample keeps red channel")
    assert(U32.is_eq(T.rgb(4278190080,66051),66051),"zero alpha uses exact background without RGB leakage")
    assert(U32.is_eq(T.rgb(4278190208,0),8388608),"half-alpha composite uses bounded integer rounding")
    assert(U32.is_eq(Pixels.paeth(0,0,0),0) && U32.is_eq(Pixels.paeth(10,10,15),10),"Paeth equal-distance ties choose left first")
    assert(U32.is_eq(Pixels.paeth(0,100,0),100) && U32.is_eq(Pixels.paeth(10,20,10),20),"Paeth chooses upper for smaller distance")
    assert(U32.is_eq(Pixels.paeth(15,0,10),0),"Paeth upper versus upper-left tie chooses upper")
    assert(U32.is_eq(Pixels.paeth(0,10,5),5),"Paeth chooses upper-left when strictly closer")
    assert(layout_good(T.layout(2048,512,6)),"maximum pixel profile admits checked exact row and filtered lengths")
    assert(layout_bad(T.layout(2048,513,6),"image_resource_limit"),"pixel product bound is checked before allocation")
    assert(layout_bad(T.layout(4294967295,4294967295,6),"image_resource_limit"),"large unsigned dimensions cannot overflow into a small image")
    assert(layout_bad(T.layout(1,0,0),"invalid_png"),"zero dimension fails before pixel division")

def supported() -> IO(Unit):
  do IO<Unit>:
    valid(F.rgba_filters(),2,5,expected_rgba(),False{},"asymmetric RGBA reconstructs all five filters and exact straight alpha")
    valid(F.split_idat(),2,5,expected_rgba(),False{},"split and empty consecutive IDAT chunks preserve one exact zlib stream")
    valid(F.rgb(),2,1,[203569407,1314552831],False{},"RGB gets explicit opaque alpha without channel swap")
    valid(F.gray(),3,1,[255,2139062271,4294967295],False{},"eight-bit grayscale expands equally into RGB")
    valid(F.gray_alpha(),3,1,[0,2139062144,4294967295],False{},"grayscale-alpha preserves zero half and opaque alpha")
    valid(F.gray_key(),2,1,[0,4294967295],False{},"grayscale tRNS sample key becomes exact transparency")
    valid(F.rgb_key(),2,1,[16909056,16909567],False{},"RGB tRNS matches all channels and preserves nearby nonmatch")
    valid(F.color_notice(),2,1,[203569407,1314552831],True{},"retained color metadata produces an uncalibrated-display notice")
    valid(F.ancillary(),2,1,[203569407,1314552831],False{},"unknown ancillary bytes are CRC-verified and never executed")
    valid(F.palette_rgb(),2,1,[203569407,1314552831],False{},"valid optional suggested palette does not change truecolor pixels")

def refusals() -> IO(Unit):
  do IO<Unit>:
    invalid(F.oversized_dimension(),"image_resource_limit","oversized width refuses before compressed data or pixel allocation")
    invalid(F.oversized_pixels(),"image_resource_limit","oversized pixel count refuses despite individually admitted dimensions")
    invalid(F.zero_width(),"invalid_png","zero-width PNG is invalid")
    invalid(F.palette(),"unsupported_png_color_or_depth","indexed palette remains explicit incomplete display parity")
    invalid(F.bitdepth16(),"unsupported_png_color_or_depth","sixteen-bit sample display remains explicit unsupported")
    invalid(F.interlaced(),"unsupported_png_interlace","Adam7 remains explicit unsupported without partial pixels")
    invalid(F.bad_interlace(),"invalid_png","unknown interlace method is invalid")
    invalid(F.bad_method(),"invalid_png","unknown PNG filter method is rejected")
    invalid(F.animated(),"unsupported_png_animation","APNG remains explicit unsupported rather than a misleading static success")
    invalid(F.critical(),"unsupported_image_format","unknown critical chunk prevents successful display")
    invalid(F.duplicate_header(),"invalid_png","second IHDR cannot reinterpret allocated image metadata")
    invalid(F.nonconsecutive_idat(),"invalid_png","separated IDAT runs cannot create a second logical compressed stream")
    invalid(F.no_data(),"invalid_png","IEND cannot publish image without data")
    invalid(F.rgba_transparency(),"invalid_png","tRNS cannot silently override an explicit RGBA channel")
    invalid(F.duplicate_transparency(),"invalid_png","duplicate transparency keys are rejected")
    invalid(F.late_transparency(),"invalid_png","late transparency cannot change already declared image data")
    invalid(F.bad_filter(),"invalid_png_compressed_data","invalid reconstructed scanline filter is rejected")
    invalid(F.bad_adler(),"invalid_png_compressed_data","valid PNG CRC cannot bless a bad zlib output checksum")
    invalid(F.bad_crc(),"invalid_png","IEND CRC is checked even though it contains no data")
    invalid(F.trailing(),"invalid_png","PNG trailing bytes cannot be accepted as exact image extent")
    invalid(F.truncated(),"invalid_png","truncated final chunk is rejected")
    invalid(F.jpeg(),"unsupported_image_format","JPEG remains visible unimplemented parity rather than missing retained data")
    invalid([256],"invalid_input","non-octet input fails before parsing or allocation")
    invalid(repeat(1048577n,0),"image_resource_limit","input byte bound is enforced independently of header contents")

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    supported()
    refusals()
