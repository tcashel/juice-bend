# Pure production projection/painter tests with synthetic rows. These do not
# claim native-window, clipboard, shaping or IME acceptance.
import Base
import ../src/ui.bend as UI
import ../src/bend_ui/canvas.bend as C
import ../src/font.bend as Font
import ../src/sans_font.bend as Sans
import ../src/library_usage_screen.bend as Screen
import ../src/library_usage_view_types.bend as View
import ../src/session_usage.bend as Usage

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def card_is(value: UI.Card,first: String,second: String) -> Bool:
  UI.Card{a,b} = value
  String.eq(a,first) && String.eq(b,second)

def changed(result: UI.State & UI.Action) -> UI.State:
  (state,_) = result
  state

def copied(result: UI.State & UI.Action) -> String:
  (_,action) = result
  match action:
    case UI.Copy{text}: text
    case _: ""

def opened(result: UI.State & UI.Action) -> U32:
  (_,action) = result
  match action:
    case UI.Open{index}: index
    case _: 99

def projection() -> IO(Unit):
  +long = String.repeat("é🙂",40n)
  do IO<Unit>:
    require(card_is(UI.card("A\nB"),"A","B"),"LF separates title and subtitle instead of reaching a glyph")
    require(card_is(UI.card("A\r\nB\r\nignored"),"A","B"),"CRLF removes only its CR terminators from both visual lines")
    require(card_is(UI.card("A \r\n B \r\nignored"),"A "," B "),"explicit separator preserves ordinary leading and trailing spaces")
    require(card_is(UI.card("A\nB\nnot a third row"),"A","B"),"only the first two explicit lines appear in a row")
    require(card_is(UI.card("A\n"),"A",""),"trailing separator yields a genuinely empty subtitle")
    require(card_is(UI.card("\nB"),"","B"),"empty explicit title stays empty rather than stealing its subtitle")
    require(card_is(UI.card(long ++ "\nRésumé 中文 🙂"),long,"Résumé 中文 🙂"),"long explicit Unicode title remains separate from exact subtitle scalars")
    require(card_is(UI.card("A\n" ++ String.repeat("🙂",40n)),"A",String.repeat("🙂",37n) ++ "…"),"long explicit subtitle has the existing scalar-based display bound")
    require(card_is(UI.card(String.repeat("x",382n) ++ "\nB"),String.repeat("x",382n),"B"),"separator and subtitle inside the 384-scalar display prefix remain distinct")
    require(card_is(UI.card("A\rB"),"A\rB",""),"literal CR without LF remains on the backward-compatible no-separator path")
    require(card_is(UI.card("short title"),"short title",""),"short no-newline row keeps previous wrapping")
    require(card_is(UI.card("claude  claude neutral physical record 0"),"claude  claude neutral physical","record 0"),"ordinary no-newline row retains previous word-aware wrapping")
    require(card_is(UI.card(String.repeat("x",39n)),String.repeat("x",31n),String.repeat("x",8n)),"unbroken no-newline row retains previous two-line split")
    require(card_is(UI.card(String.repeat("🙂",90n)),String.repeat("🙂",38n),String.repeat("🙂",37n) ++ "…"),"no-newline Unicode row keeps previous scalar-based ellipsis")
    require(card_is(UI.card(String.repeat("x",400n) ++ "\nlate"),String.repeat("x",38n),String.repeat("x",37n) ++ "…"),"separator beyond bounded prefix preserves the old visible row")
    require(card_is(UI.display_card("claude  Review café",True{}),"Review café","Claude") &&
      card_is(UI.display_card("codex  Review café",True{}),"Review café","Codex"),"History session provider subtitle remains intact")
    require(card_is(UI.display_card("claude  notes",False{}),"claude  notes",""),"non-session literal provider-like prefix stays intact")

# Locate an actual 8px tile from the production Canvas. Expected glyph rows
# come directly from the pinned atlas, independent of Label layout/splitting.
def tile_choose(tl: C.Canvas,tr: C.Canvas,bl: C.Canvas,br: C.Canvas,q: U32) -> C.Canvas:
  match q:
    case 0: tl
    case 1: tr
    case 2: bl
    case _: br

def tile_at(depth: Nat,c: C.Canvas,+x: U32,+y: U32) -> C.Canvas:
  match depth c:
    case 1n+ +rest C.Four{tl,tr,bl,br}:
      +half = U32.shln(1,rest)
      q = U32.add(Bool.to_u32(U32.is_ge(x,half)),U32.mul(2,Bool.to_u32(U32.is_ge(y,half))))
      tile_at(rest,tile_choose(tl,tr,bl,br,q),U32.mod(x,half),U32.mod(y,half))
    case _ value: value

def rows_match(fuel: Nat,+bits: Font.Half,+glyph: Sans.Glyph,+word: U32,+row: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      U32.is_eq(Font.row(bits,row),Sans.row_word(glyph,word,row)) && rows_match(rest,bits,glyph,word,U32.inc(row))

def glyph_tile(value: C.Canvas,face: U32,code: U32,word: U32,foreground: U32,background: U32) -> Bool:
  match value:
    case C.Tile{bits,fg,bg}:
      rows_match(8n,bits, Sans.glyph(face,code),word,0) && U32.is_eq(fg,foreground) && U32.is_eq(bg,background)
    case _: False{}

def painting() -> IO(Unit):
  +row = UI.draw_rows(1n,C.Flat{UI.panel()},["A\r\nB"],0,0,False{})
  +usage = UI.set_results(UI.init(),UI.LibraryUsageResults{2,4,[]})
  +heading = UI.draw_list_header(C.Flat{UI.panel()},usage,UI.LibraryUsageResults{2,4,[]},False{})
  do IO<Unit>:
    require(glyph_tile(tile_at(8n,row,25,23),1,65,0,UI.ink(),UI.selected_bg()) &&
      glyph_tile(tile_at(8n,row,26,23),1,65,1,UI.ink(),UI.selected_bg()),"production row paints only title A, including its blank trailing tile; no CR/LF box")
    require(glyph_tile(tile_at(8n,row,25,26),0,66,0,UI.muted(),UI.selected_bg()) &&
      glyph_tile(tile_at(8n,row,26,26),0,66,1,UI.muted(),UI.selected_bg()),"production row paints subtitle B at the separate lower baseline")
    require(String.eq(UI.provider_list_heading(usage),"Usage") && String.eq(UI.provider_list_heading(UI.init()),"History"),"visible Usage heading fits while History keeps its name")
    require(glyph_tile(tile_at(8n,heading,24,15),2,85,0,UI.heading_ink(),UI.panel()),"production header painter starts with the Usage heading glyph")

def capture() -> Usage.Capture:
  Usage.Capture{"claude","source-1","/synthetic/source","7","9007199254740993",123,4}

def item() -> View.CaptureItem:
  View.CaptureItem{capture(),"Claude · fixture","included","Counted · snapshot 9007199254740993","canonical-source"}

def row_text(values: List<&2,String>) -> String:
  match values:
    case [value]: value
    case _: ""

def identity_matches(value: Maybe<&2,Usage.Capture>) -> Bool:
  match value:
    case Some{Usage.Capture{provider,source,path,generation,snapshot,extent,records}}:
      String.eq(provider,"claude") && String.eq(source,"source-1") && String.eq(path,"/synthetic/source") &&
      String.eq(generation,"7") && String.eq(snapshot,"9007199254740993") && U32.is_eq(extent,123) && U32.is_eq(records,4)
    case _: False{}

def canonical() -> IO(Unit):
  +text = {"Canonical café 中文 🙂\r\nA\tB" : String}
  +row = row_text(Screen.titles([item()]))
  +s = UI.set_rows(UI.set_reader(UI.init(),"Fixture",text),[row])
  do IO<Unit>:
    require(String.eq(row,"Claude · fixture\nCounted · snapshot 9007199254740993"),"Usage row has one human-readable status and omits its redundant raw status key")
    require(identity_matches(Screen.row([item()],0n)),"display formatting preserves exact typed source/generation/large snapshot identity")
    require(U32.is_eq(opened(UI.event(Mouse{216,192,0,True{}},s)),0),"new list presentation still opens exact row index zero")
    require(String.eq(UI.reader(s),text) && String.eq(copied(UI.text_action(UI.select_all(UI.set_edit(s,UI.Edit{2,0,0,False{},0})),0)),text),"canonical reader and Copy action preserve CRLF, tabs and Unicode")

def main() -> IO(Unit):
  do IO<Unit>:
    projection()
    painting()
    canonical()
