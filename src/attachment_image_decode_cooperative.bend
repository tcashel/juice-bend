import Base
import ./attachment_image_decode.bend as Legacy
import ./attachment_image_cancel.bend as Cancel
import ./attachment_image_types.bend as Image
import ./jpeg/types.bend as T
import ./jpeg/input.bend as Input
import ./jpeg/container.bend as Container
import ./jpeg/cooperative.bend as Cooperative

# JPEG admission/container and initial allocation retain their original bounded
# synchronous spans. PNG retains its original pure decoder in this first slice.
# Only JPEG rendering is cooperatively stepped; cancellation never changes math.
def document(value: Result<&2,&2,T.Failure,T.Document>,mode: Cancel.Mode) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{T.Failure{kind,detail}}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{kind ++ ": " ++ detail})
    case Done{value}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        raster : Result<&2,&1,T.Failure,Image.Raster> <- Cooperative.render(value,mode)
        return Legacy.jpeg(raster)

def select(format: Legacy.Format,bytes: List<&2,U32>,mode: Cancel.Mode) -> IO(Result<&2,&1,String,Image.Raster>):
  match format:
    case Legacy.JpegFormat{}: document(Container.decode(bytes),mode)
    case other: IO.pure(Result<&2,&1,String,Image.Raster>,Legacy.selected(other,bytes))

def selected(format: Legacy.Format,bytes: List<&2,U32>,+mode: Cancel.Mode) -> IO(Result<&2,&1,String,Image.Raster>):
  do IO<Result<&2,&1,String,Image.Raster>>:
    Cancel.check(mode)
    select(format,bytes,mode)

def admitted(value: Result<&2,&1,String,U32>,+bytes: List<&2,U32>,mode: Cancel.Mode) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{message})
    case Done{_}: selected(Legacy.sniff(bytes),bytes,mode)

def decode(+bytes: List<&2,U32>,+mode: Cancel.Mode) -> IO(Result<&2,&1,String,Image.Raster>):
  do IO<Result<&2,&1,String,Image.Raster>>:
    Cancel.check(mode)
    admitted(Legacy.admission(Input.admitted(bytes,0)),bytes,mode)
