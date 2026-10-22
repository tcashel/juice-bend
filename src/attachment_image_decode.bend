import Base
import ./attachment_png.bend as Png
import ./attachment_jpeg.bend as Jpeg
import ./attachment_image_types.bend as Image
import ./jpeg/types.bend as J
import ./jpeg/input.bend as Input

# Format comes only from freshly verified retained bytes, never a filename or
# provider MIME claim. This module adds no file, URL, worker or storage access.
type Format is Data:
  PngFormat{}
  JpegFormat{}
  UnknownFormat{}

def sniff(bytes: List<&2,U32>) -> Format:
  match bytes:
    case 137 <> 80 <> 78 <> 71 <> 13 <> 10 <> 26 <> 10 <> _: PngFormat{}
    case 255 <> 216 <> _: JpegFormat{}
    case _: UnknownFormat{}

def png(result: Result<&2,&1,Image.Failure,Image.Raster>) -> Result<&2,&1,String,Image.Raster>:
  match result:
    case Fail{Image.Failure{kind,detail}}: Fail{Image.label(kind) ++ ": " ++ detail}
    case Done{raster}: Done{raster}

def jpeg(result: Result<&2,&1,J.Failure,Image.Raster>) -> Result<&2,&1,String,Image.Raster>:
  match result:
    case Fail{J.Failure{kind,detail}}: Fail{kind ++ ": " ++ detail}
    case Done{raster}: Done{raster}

def admission(result: Result<&2,&2,J.Failure,U32>) -> Result<&2,&1,String,U32>:
  match result:
    case Fail{J.Failure{kind,detail}}: Fail{kind ++ ": " ++ detail}
    case Done{count}: Done{count}

def selected(format: Format,bytes: List<&2,U32>) -> Result<&2,&1,String,Image.Raster>:
  match format:
    case PngFormat{}: png(Png.decode(bytes))
    case JpegFormat{}: jpeg(Jpeg.decode(bytes))
    case UnknownFormat{}: Fail{"unsupported_image_format: These retained bytes are not a supported PNG or baseline JPEG image. Original bytes remain available to export."}

def decode(+bytes: List<&2,U32>) -> Result<&2,&1,String,Image.Raster>:
  do Result<&2,&1,String,Image.Raster>:
    _ : U32 <- admission(Input.admitted(bytes,0))
    selected(sniff(bytes),bytes)
