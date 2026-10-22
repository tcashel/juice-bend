import Base
import ../src/attachment_image_decode.bend as Decode
import ../src/attachment_image_types.bend as Image
import ./png_fixtures.bend as PNG
import ./png.bend as PngTest
import ./jpeg_fixtures.bend as JPEG
import ./jpeg.bend as JpegTest

def check(okay: Bool,label: String) -> IO(Unit):
  match okay:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def raster(result: Result<&2,&1,String,Image.Raster>,width: U32,height: U32,expected: List<&2,U32>,notice: Bool) -> Bool:
  match result:
    case Done{value}: PngTest.raster(value,width,height,expected,notice)
    case Fail{_}: False{}

def failure(result: Result<&2,&1,String,Image.Raster>,prefix: String) -> Bool:
  match result:
    case Fail{message}: String.starts_with(message,prefix)
    case Done{_}: False{}

def format(value: Decode.Format) -> U32:
  match value:
    case Decode.PngFormat{}: 1
    case Decode.JpegFormat{}: 2
    case Decode.UnknownFormat{}: 0

def main() -> IO(Unit):
  do IO<Unit>:
    check(U32.is_eq(format(Decode.sniff(PNG.rgb())),1),"actual PNG signature chooses PNG")
    check(U32.is_eq(format(Decode.sniff(JPEG.gray_constant_bytes())),2),"actual JPEG SOI chooses JPEG")
    check(U32.is_eq(format(Decode.sniff([137,80,78,71])),0),"partial PNG signature is not accepted as PNG")
    check(U32.is_eq(format(Decode.sniff([255])),0),"partial JPEG prefix is not accepted as JPEG")
    check(raster(Decode.decode(PNG.rgb()),2,1,[203569407,1314552831],False{}),"PNG RGB exact samples remain unchanged through format dispatch")
    check(raster(Decode.decode(PNG.rgba_filters()),2,5,PngTest.expected_rgba(),False{}),"PNG alpha and all reconstruction filters survive common dispatch")
    check(raster(Decode.decode(PNG.color_notice()),2,1,[203569407,1314552831],True{}),"PNG unmanaged color metadata notice is preserved")
    check(raster(Decode.decode(JPEG.gray_constant_bytes()),8,8,JPEG.gray_constant_expected(),False{}),"baseline JPEG decodes to the existing exact opaque raster")
    check(raster(Decode.decode(JPEG.ycbcr_420_bytes()),19,17,JPEG.ycbcr_420_expected(),False{}),"JPEG chroma subsampling retains independent complete-image pixels")
    check(raster(Decode.decode(JPEG.adobe_rgb_bytes()),11,9,JPEG.adobe_rgb_expected(),True{}),"Adobe JPEG retains original color notice and independent pixels")
    check(failure(Decode.decode(PNG.oversized_dimension()),"image_resource_limit:"),"PNG resource refusal remains visible")
    check(failure(Decode.decode(JpegTest.replace(90n,JPEG.gray_constant_bytes(),194)),"unsupported_jpeg_progressive:"),"progressive JPEG has a named in-window failure")
    check(failure(Decode.decode([255,216,255]),"invalid_jpeg:"),"truncated JPEG cannot turn into a successful preview")
    check(failure(Decode.decode([]),"unsupported_image_format:"),"empty retained bytes have a visible unsupported state")
    check(failure(Decode.decode([256]),"invalid_input:"),"common admission refuses non-octets")
    check(failure(Decode.decode(JpegTest.repeat(1048577n,0)),"image_resource_limit:"),"common byte cap is enforced before format selection")
    check(failure(Decode.decode([104,116,116,112,115,58,47,47]),"unsupported_image_format:"),"URL text is an unsupported byte format and never fetched")
