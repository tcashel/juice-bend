import Base
import ./attachment_image_types.bend as Image
import ./jpeg/types.bend as T
import ./jpeg/container.bend as Container
import ./jpeg/raster.bend as Raster

# Already-owned exact bytes only. No source file, URL, process or native decoder.
def decode(bytes: List<&2,U32>) -> Result<&2,&1,T.Failure,Image.Raster>:
  do Result<&2,&1,T.Failure,Image.Raster>:
    document : T.Document <- T.widen(T.Document,Container.decode(bytes))
    Raster.render(document)
