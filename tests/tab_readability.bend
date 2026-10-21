import Base
import ../src/ui.bend as UI
import ../src/ui_geometry.bend as G
import ../src/font.bend as Font

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def state(result: UI.State & UI.Action) -> UI.State:
  (s,action) = result
  s

def copied(result: UI.State & UI.Action) -> String:
  (s,action) = result
  match action:
    case UI.Copy{text}: text
    case _: ""

def exported(result: UI.State & UI.Action) -> Bool:
  (s,action) = result
  match action:
    case UI.Export{}: True{}
    case _: False{}

def line(line: UI.Line,start: U32,text: String) -> Bool:
  UI.Line{actual,value} = line
  U32.is_eq(actual,start) && String.eq(value,text)

def repeat(n: Nat,+s: String) -> String:
  match n:
    case 0n: ""
    case 1n+p: s ++ repeat(p,s)

# Inspect actual painted cells without duplicating text layout or hit testing.
def tile.choose(tl: UI.Canvas,tr: UI.Canvas,bl: UI.Canvas,br: UI.Canvas,q: U32) -> UI.Canvas:
  match q:
    case 0: tl
    case 1: tr
    case 2: bl
    case _: br

def tile.at(d: Nat,c: UI.Canvas,+x: U32,+y: U32) -> UI.Canvas:
  match d c:
    case 1n+ +p UI.Four{tl,tr,bl,br}:
      +half = U32.shln(1,p)
      q = U32.add(Bool.to_u32(U32.is_ge(x,half)),U32.mul(2,Bool.to_u32(U32.is_ge(y,half))))
      tile.at(p,tile.choose(tl,tr,bl,br,q),U32.mod(x,half),U32.mod(y,half))
    case _ value: value

def tile.row(c: UI.Canvas,y: U32,row: U32,background: U32) -> Bool:
  match c:
    case UI.Tile{bits,fg,bg}: U32.is_eq(Font.row(bits,y),row) && U32.is_eq(bg,background)
    case _: False{}

def tile.empty(c: UI.Canvas,color: U32) -> Bool:
  match c:
    case UI.Flat{actual}: U32.is_eq(actual,color)
    case _: False{}

def painting() -> IO(Unit):
  +query = UI.write(2n,UI.Flat{UI.paper()},"\tA",0,0,UI.ink(),UI.paper())
  +reader = UI.draw_line(2n,UI.Flat{UI.paper()},"\tA",0,0,7,7,8)
  do IO<Unit>:
    require(tile.row(tile.at(8n,query,0,0),7,2143009720,UI.paper()),"query tab paints existing arrow shaft, not missing-glyph box")
    require(tile.row(tile.at(8n,query,0,1),0,479199232,UI.paper()),"query tab paints existing arrow lower half")
    require(tile.row(tile.at(8n,reader,0,0),7,2143009720,UI.selection_bg()),"reader tab paints arrow with selected-cell background")
    require(tile.row(tile.at(8n,reader,0,1),0,479199232,UI.selection_bg()),"selected tab background covers both glyph halves")
    require(tile.row(tile.at(8n,reader,1,0),7,Font.row(Font.half(Font.glyph(65),True{}),7),UI.paper()),"next reader character starts exactly one unselected cell later")
    require(tile.row(tile.at(8n,query,1,0),7,Font.row(Font.half(Font.glyph(65),True{}),7),UI.paper()),"next query character starts exactly one cell later")
    require(tile.empty(tile.at(8n,reader,2,0),UI.paper()) && tile.empty(tile.at(8n,query,2,0),UI.paper()),"tab painting does not consume an extra cell")

def selection() -> IO(Unit):
  +text = {"A\t🙂B" : String}
  +query = UI.set_query(UI.init(),text)
  +query_pressed = state(UI.event(Mouse{216,40,0,True{}},query))
  +query_tab = state(UI.event(Move{224,40},query_pressed))
  +query_unicode = state(UI.event(Move{232,40},query_pressed))
  +reader = UI.set_reader(UI.init(),"Tab marker",text)
  +reader_pressed = state(UI.event(Mouse{544,168,0,True{}},reader))
  +reader_tab = state(UI.event(Move{552,168},reader_pressed))
  +reader_unicode = state(UI.event(Move{560,168},reader_pressed))
  +all = UI.select_all(reader_unicode)
  do IO<Unit>:
    require(String.eq(UI.selection(query_tab),"\t") && String.eq(UI.selection(reader_tab),"\t"),"one-cell pointer drag selects the original tab in both fields")
    require(String.eq(UI.selection(query_unicode),"\t🙂") && String.eq(UI.selection(reader_unicode),"\t🙂"),"drag over tab and emoji preserves exact Unicode scalars")
    require(String.eq(copied(UI.event(Key{99,True{}},UI.set_modifiers(query_unicode,True{},False{}))),"\t🙂"),"query Command-C emits original tab and emoji")
    require(String.eq(copied(UI.event(Key{99,True{}},UI.set_modifiers(reader_unicode,True{},False{}))),"\t🙂"),"reader Command-C emits original tab and emoji")
    require(String.eq(copied(UI.text_action(all,0)),text),"reader Copy action retains exact canonical full text")
    require(exported(UI.event(Mouse{680,88,0,True{}},all)),"Export action remains available with tab selection")
    require(String.eq(UI.reader(state(UI.event(Mouse{680,88,0,True{}},all))),text),"Export dispatch leaves canonical reader untouched")
    require(String.eq(UI.query(query_unicode),text) && String.eq(UI.reader(reader_unicode),text),"painting marker never substitutes the stored tab")

def wrapping() -> IO(Unit):
  +text = repeat(103n,"x") ++ "\t🙂\nZ"
  +lines = UI.wrap(text)
  +reader = UI.set_reader(UI.init(),"Wrapped tab",text)
  +pressed = state(UI.event(Mouse{1360,168,0,True{}},reader))
  +dragged = state(UI.event(Move{544,192},pressed))
  do IO<Unit>:
    require(line(UI.line_at(lines,0),0,repeat(103n,"x") ++ "\t"),"tab occupies final existing column without expansion")
    require(line(UI.line_at(lines,1),104,"🙂") && line(UI.line_at(lines,2),106,"Z"),"tab wrap preserves emoji and newline source offsets")
    require(U32.is_eq(UI.reader_at(reader,1360,168),103) && U32.is_eq(UI.reader_at(reader,544,192),105),"reader hit testing crosses tab wrap at exact scalar offsets")
    require(String.eq(UI.selection(dragged),"\t🙂"),"pointer selection across tab wrap retains original characters")
    require(String.eq(copied(UI.event(Key{99,True{}},UI.set_modifiers(dragged,True{},False{}))),"\t🙂"),"copy across tab wrap does not insert the display arrow")
    require(U32.is_eq(G.cell(),8) && U32.is_eq(G.reader_columns(),104),"tab marker retains existing cell and reader geometry")

def main() -> IO(Unit):
  do IO<Unit>:
    painting()
    selection()
    wrapping()
