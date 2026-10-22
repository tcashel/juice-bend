import Base
import ../src/attachment_jpeg.bend as Jpeg
import ../src/attachment_image_types.bend as Image
import ../src/attachment_image_cancel.bend as Cancel
import ../src/jpeg/types.bend as T
import ../src/jpeg/container.bend as Container
import ../src/jpeg/cooperative.bend as Cooperative
import ./jpeg.bend as Check
import ./jpeg_fixtures.bend as F

# These fixtures already carry independent decoder oracles. Unchecked mode
# tests the cooperative orchestration and shared arithmetic; it does not test
# filesystem cancellation or establish a cancellation-latency bound.
def document(value: Result<&2,&2,T.Failure,T.Document>) -> IO(Result<&2,&1,T.Failure,Image.Raster>):
  match value:
    case Fail{error}: IO.pure(Result<&2,&1,T.Failure,Image.Raster>,Fail{error})
    case Done{value}: Cooperative.render(value,Cancel.Unchecked{})

def decode(bytes: List<&2,U32>) -> IO(Result<&2,&1,T.Failure,Image.Raster>):
  document(Container.decode(bytes))

def pixels(left: List<U32>,right: List<U32>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case Con{a,rest} Con{b,tail}: U32.is_eq(a,b) && pixels(rest,tail)
    case _ _: False{}

# Compare every allocated pixel, including zero padding, and all result fields.
def same(left: Result<&2,&1,T.Failure,Image.Raster>,right: Result<&2,&1,T.Failure,Image.Raster>) -> Bool:
  match left right:
    case Done{Image.Raster{lw,lh,ln,lc,lp,li}} Done{Image.Raster{rw,rh,rn,rc,rp,ri}}:
      U32.is_eq(lw,rw) && U32.is_eq(lh,rh) && U32.is_eq(ln,rn) && U32.is_eq(lc,rc) &&
        U32.is_eq(Bool.to_u32(li),Bool.to_u32(ri)) && pixels(Array.to_list(U32,lp),Array.to_list(U32,rp))
    case _ _: False{}

def valid(+bytes: List<&2,U32>,width: U32,height: U32,expected: List<&2,U32>,tolerance: U32,notice: Bool,+label: String) -> IO(Unit):
  do IO<Unit>:
    actual : Result<&2,&1,T.Failure,Image.Raster> <- decode(bytes)
    Check.decoded(actual,width,height,expected,tolerance,notice,label ++ " independent oracle")
    again : Result<&2,&1,T.Failure,Image.Raster> <- decode(bytes)
    Check.assert(same(Jpeg.decode(bytes),again),label ++ " exact pure/cooperative result parity")

def same_failure(left: Result<&2,&1,T.Failure,Image.Raster>,right: Result<&2,&1,T.Failure,Image.Raster>,wanted: String) -> Bool:
  match left right:
    case Fail{T.Failure{+kind,detail}} Fail{T.Failure{other,other_detail}}:
      String.eq(kind,wanted) && String.eq(kind,other) && String.eq(detail,other_detail)
    case _ _: False{}

def invalid(+bytes: List<&2,U32>,kind: String,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : Result<&2,&1,T.Failure,Image.Raster> <- decode(bytes)
    Check.assert(same_failure(Jpeg.decode(bytes),actual,kind),label)

def success() -> IO(Unit):
  do IO<Unit>:
    valid(F.gray_constant_bytes(),8,8,F.gray_constant_expected(),0,False{},"cooperative gray DC")
    valid(F.gray_edges_bytes(),9,7,F.gray_edges_expected(),2,False{},"cooperative gray AC edge")
    valid(F.ycbcr_420_bytes(),19,17,F.ycbcr_420_expected(),2,False{},"cooperative 4:2:0 edge")
    valid(F.restart_420_bytes(),33,17,F.restart_420_expected(),2,False{},"cooperative restart 4:2:0")
    valid(F.adobe_rgb_bytes(),11,9,F.adobe_rgb_expected(),2,True{},"cooperative Adobe RGB notice")

def refusals() -> IO(Unit):
  do IO<Unit>:
    invalid([256],"invalid_input","cooperative non-octet failure kind and detail match")
    invalid(Check.replace(90n,F.gray_constant_bytes(),194),"unsupported_jpeg_progressive","cooperative unsupported progressive failure kind and detail match")
    invalid(Check.replace(25n,F.gray_constant_bytes(),0),"invalid_jpeg","cooperative invalid quantizer failure kind and detail match")
    invalid(Check.replace(824n,F.restart_420_bytes(),209),"jpeg_entropy","cooperative wrong restart failure kind and detail match")
    invalid(Check.prefix(331n,F.gray_constant_bytes()),"jpeg_entropy","cooperative missing EOI failure kind and detail match")
    invalid(List.append(&2,U32,F.gray_constant_bytes(),[0]),"jpeg_entropy","cooperative trailing bytes failure kind and detail match")

def main() -> IO(Unit):
  do IO<Unit>:
    success()
    refusals()
    IO.print("Completed 21 JPEG cooperative result assertions.")
