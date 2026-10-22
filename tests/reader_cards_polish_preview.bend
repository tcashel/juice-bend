import Base
import ../src/ui.bend as UI
import ../src/reader_cards.bend as C
import ../src/reader_document.bend as D
import ./reader_cards.bend as Existing
import ./reader_cards_ui.bend as Reader
import ./reader_cards_preview.bend as Preview
import ./reader_cards_polish.bend as Polish

def main() -> IO(Unit):
  +base : UI.State = Polish.sample()
  +model : C.Model = Reader.state_model(base)
  +expanded : UI.State = UI.card_fold(base,C.token(model),Existing.part_key(D.parts(Polish.document()),0))
  do IO<Unit>:
    Preview.write("reader-cards-polish-compact.ppm",UI.draw_canvas_capture(base,"Pause",False{}))
    Preview.write("reader-cards-polish-expanded.ppm",UI.draw_canvas_capture(expanded,"Pause",False{}))
