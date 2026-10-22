import Base
import ./attachment_image_types.bend as T
import ./png/container.bend as Container
import ./png/inflate.bend as Inflate
import ./png/pixels.bend as Pixels

def decoded(+document: Container.Document) -> Result<&2,&1,T.Failure,T.Raster>:
  Container.Document{Container.Header{T.Layout{_,_,_,_,_,expected},_},_,compressed,_} = document
  do Result<&2,&1,T.Failure,T.Raster>:
    bytes : List<&2,U32> <- Pixels.widen(List<&2,U32>,Inflate.decode(compressed,expected))
    Pixels.render(document,bytes)

# This entry accepts exact verified owned bytes. It never resolves a path, reads
# an original attachment or fetches a URL, and errors never discard raw data.
def decode(bytes: List<&2,U32>) -> Result<&2,&1,T.Failure,T.Raster>:
  do Result<&2,&1,T.Failure,T.Raster>:
    document : Container.Document <- Pixels.widen(Container.Document,Container.decode(bytes))
    decoded(document)
