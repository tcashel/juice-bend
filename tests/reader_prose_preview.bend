import Base
import ../src/ui.bend as UI
import ../src/reader_cards.bend as C
import ../src/reader_document.bend as D
import ../src/bend_ui/canvas.bend as Canvas
import ./reader_cards.bend as Existing
import ./reader_cards_ui.bend as Reader
import ./reader_cards_polish.bend as Polish
import ./text_line_canvas.bend as Pixels
import ./history_workspace.bend as Files

# Inspect the actual Image conversion, including partial selection subtrees.
def pixels(fuel: Nat,+image: Image,+x: U32,+y: U32) -> List<&2,U32>:
  match fuel:
    case 0n: []
    case 1n+n:
      +color = Pixels.pixel(11n,image,x,y)
      U32.and(U32.shrn(color,16n),255) <> U32.and(U32.shrn(color,8n),255) <> U32.and(color,255) <> pixels(n,image,U32.inc(x),y)

def rows(fuel: Nat,file: File,+image: Image,+y: U32) -> IO(File):
  match fuel:
    case 0n: IO.pure(File,file)
    case 1n+n:
      do IO<File>:
        got : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,pixels(1200n,image,0,y))
        next : File <- Files.written(got)
        rows(n,next,image,U32.inc(y))

def write(name: String,canvas: Canvas.Canvas) -> IO(Unit):
  image : Image = Canvas.canvas.image(canvas)
  do IO<Unit>:
    file : File <- IO.try(File,File.open(name,"w"))
    header : File & Result<&1,&1,U32 & String,Unit> <- File.write(file,"P6\n1200 664\n255\n")
    open : File <- Files.written(header)
    done : File <- rows(664n,open,image,0)
    File.close(done)
    IO.print("PASS exact production Image preview written; no native window claim")

def main() -> IO(Unit):
  +base : UI.State = Polish.sample()
  +model : C.Model = Reader.state_model(base)
  +expanded : UI.State = UI.card_fold(base,C.token(model),Existing.part_key(D.parts(Polish.document()),0))
  do IO<Unit>:
    write("reader-prose-compact.ppm",UI.draw_canvas_capture(base,"Pause",False{}))
    write("reader-prose-expanded.ppm",UI.draw_canvas_capture(expanded,"Pause",False{}))
