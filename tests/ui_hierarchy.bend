import Base
import ../src/ui.bend as UI
import ../src/ui_palette.bend as Palette
import ../src/ui_geometry.bend as G
import ../src/font.bend as Font
import ./tab_readability.bend as Tiles
import ./ui_attachments.bend as Attachments

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def changed(result: UI.State & UI.Action) -> UI.State:
  (state,_) = result
  state

def copied(result: UI.State & UI.Action) -> String:
  (_,action) = result
  match action:
    case UI.Copy{text}: text
    case _: ""

def headings() -> IO(Unit):
  do IO<Unit>:
    check(String.eq(Palette.heading("Transcript | pinned snapshot 9007199254740993 | record 40"),"Transcript") &&
      String.eq(Palette.heading("Why | pinned snapshot 9007199254740993"),"Why this request"),
      "known captured reader titles use complete short headings instead of clipped identity suffixes")
    check(String.eq(Palette.heading("Transcript | pinned snapshots are prose"),"Transcript | pinned snapshots are prose") &&
      String.eq(Palette.heading("Settings | storage inventory"),"Settings | storage inventory"),
      "heading compaction recognizes only exact application title prefixes")
    check(String.eq(Palette.fit_heading("A🙂B",3),"A🙂B") &&
      String.eq(Palette.fit_heading("A🙂BC",3),"A🙂…") &&
      String.eq(Palette.fit_heading("café",1),"…") &&
      String.eq(Palette.fit_heading("café",0),""),
      "overflow is explicit and bounded by Unicode scalars at zero, one and exact widths")

def state() -> UI.State:
  UI.set_edit(UI.set_rows(UI.set_reader(UI.init(),
    "Transcript | pinned snapshot 9007199254740993 | record 40",
    "A🙂B\t café 中文\nexact retained body"),["First capture","Second capture"]),UI.Edit{2,3,1,False{},0})

def painting() -> IO(Unit):
  +origin = state()
  +canvas = UI.draw_canvas_capture(origin,"Pause",False{})
  +moved = UI.draw_canvas_capture(UI.set_position(origin,1,0),"Pause",False{})
  +long = UI.draw_canvas_capture(UI.set_reader(origin,String.repeat("W",30n),UI.reader(origin)),"Pause",False{})
  do IO<Unit>:
    check(Attachments.glyph(canvas,536,128,84,UI.heading_ink(),UI.paper()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,canvas,78,16),UI.paper()),
      "actual painter shows a complete Transcript heading without the clipped pinned suffix")
    check(Attachments.glyph(long,672,128,8230,UI.heading_ink(),UI.paper()) &&
      U32.is_ne(Font.row(Font.half(Font.glyph(8230),False{}),1),0) &&
      Tiles.tile.row(Tiles.tile.at(8n,long,84,17),1,Font.row(Font.half(Font.glyph(8230),False{}),1),UI.paper()) &&
      Attachments.glyph(long,704,128,65,UI.accent(),UI.paper()) &&
      Attachments.glyph(long,816,128,67,UI.accent(),UI.paper()),
      "long heading ends in a real ellipsis and leaves Attachments and Copy intact")
    check(Attachments.glyph(canvas,192,128,83,UI.heading_ink(),UI.panel()) &&
      Attachments.glyph(canvas,192,152,82,UI.muted(),UI.panel()),
      "list heading and secondary loading label use distinct presentation roles")
    check(Tiles.tile.empty(Tiles.tile.at(8n,canvas,1,18),UI.accent()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,canvas,1,14),UI.rail()),
      "only the active provider row receives a visible selection marker")
    check(Tiles.tile.empty(Tiles.tile.at(8n,canvas,23,23),UI.accent()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,canvas,23,31),UI.panel()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,moved,23,23),UI.panel()) &&
      Tiles.tile.empty(Tiles.tile.at(8n,moved,23,31),UI.accent()),
      "selected capture marker follows exact list selection without changing card layout")
    check(Tiles.tile.empty(Tiles.tile.at(8n,canvas,2,3),Palette.ink(Palette.Brand{})) &&
      Attachments.glyph(canvas,32,24,74,UI.heading_ink(),UI.rail()),
      "warm brand mark is confined to the application identity area")

def unchanged_interaction() -> IO(Unit):
  +origin = state()
  +restored = UI.restore(UI.init(),UI.bookmark(origin))
  copy = UI.copy_action(origin,False{})
  +clicked = changed(UI.event(Mouse{544,168,0,True{}},origin))
  +dragged = changed(UI.event(Move{560,168},clicked))
  do IO<Unit>:
    check(String.eq(UI.title(origin),"Transcript | pinned snapshot 9007199254740993 | record 40") &&
      String.eq(UI.reader(origin),"A🙂B\t café 中文\nexact retained body"),
      "compact paint leaves the exact full title and retained transcript untouched")
    check(String.eq(copied(copy),"🙂B") && String.eq(UI.selection(restored),"🙂B") &&
      String.eq(UI.title(restored),UI.title(origin)),
      "copy and bookmark restoration preserve exact text selection and full title")
    check(String.eq(UI.selection(dragged),"🙂B") && U32.is_eq(G.cell(),8) &&
      U32.is_eq(G.reader_columns(),80) && U32.is_eq(G.reader_rows(),19),
      "pointer selection still uses the accepted eight-pixel grid and bounded reader")
    check(U32.is_ne(UI.ink(),UI.muted()) && U32.is_ne(UI.heading_ink(),UI.accent()) &&
      U32.is_ne(UI.selected_bg(),UI.selection_bg()),
      "body, secondary text, headings, actions and text selection have separate roles")

def main() -> IO(Unit):
  do IO<Unit>:
    headings()
    painting()
    unchanged_interaction()
