import Base
import ../src/ui.bend as UI
import ../src/bend_ui/canvas.bend as C
import ../src/reader_cards.bend as Cards
import ../src/reader_document.bend as D
import ./reader_cards_ui.bend as Reader
import ./reader_cards.bend as Fixture
import ./history_workspace.bend as Canvas

def sample() -> UI.State:
  UI.set_status(UI.set_rows(UI.set_query(Reader.base(7,"synthetic-preview"),"repository: /synthetic"),
    ["claude  Preserve the display calculation","codex  Review the captured changes"]),
    "Captured page. Show/Hide opens recorded tool and evidence details. Copy selects visible text; export includes collapsed details.")

def write(name: String,+canvas: C.Canvas) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(name,"w"))
    header : File & Result<&1,&1,U32 & String,Unit> <- File.write(file,"P6\n1200 664\n255\n")
    open : File <- Canvas.written(header)
    done : File <- Canvas.rows(664n,open,canvas,0)
    File.close(done)
    IO.print("PASS exact synthetic reader production canvas written; no native window claim")

def main() -> IO(Unit):
  +base = sample()
  +model = Reader.state_model(base)
  +expanded = UI.card_fold(base,Cards.token(model),Fixture.part_key(D.parts(Fixture.document(7)),0))
  do IO<Unit>:
    write("reader-cards-compact.ppm",UI.draw_canvas_capture(base,"Pause",False{}))
    write("reader-cards-expanded.ppm",UI.draw_canvas_capture(expanded,"Pause",False{}))
