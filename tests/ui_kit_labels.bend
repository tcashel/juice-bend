import Base
import ../src/bend_ui/canvas.bend as C
import ../src/bend_ui/label.bend as L
import ../src/bend_ui/region.bend as R
import ../src/font.bend as Mono

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def refused(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Fail{C.InvalidBounds{}}: True{}
    case _: False{}

def choose(right: Bool,bottom: Bool,tl: C.Canvas,tr: C.Canvas,bl: C.Canvas,br: C.Canvas) -> C.Canvas:
  match right bottom:
    case False{} False{}: tl
    case True{} False{}: tr
    case False{} True{}: bl
    case True{} True{}: br
def pixel(fuel: Nat,c: C.Canvas,+x: U32,+y: U32) -> U32:
  match fuel c:
    case _ C.Flat{color}: color
    case _ C.Tile{bits,fg,bg}: C.blend(fg,bg,Mono.coverage(bits,U32.mod(x,8),U32.mod(y,8)))
    case 0n _: 0
    case 1n+ +n C.Four{tl,tr,bl,br}:
      +half = U32.shln(8,n)
      pixel(n,choose(U32.is_ge(x,half),U32.is_ge(y,half),tl,tr,bl,br),U32.mod(x,half),U32.mod(y,half))

def painted(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Done{+c}:
      U32.is_eq(pixel(8n,c,8,8),1193046) && U32.is_eq(pixel(8n,c,15,15),1193046) &&
      U32.is_eq(pixel(8n,c,7,8),0) && U32.is_eq(pixel(8n,c,16,8),0) && U32.is_eq(pixel(8n,c,8,16),0)
    case _: False{}

def edge_painted(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Done{+c}: U32.is_eq(pixel(8n,c,2047,2047),16777215) && U32.is_eq(pixel(8n,c,0,0),0)
    case _: False{}

def label_pixels(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Done{+c}:
      # Independent atlas raster word 0x00bf2000 at row5: coverage2,15,11.
      U32.is_eq(pixel(8n,c,11,13),2236962) && U32.is_eq(pixel(8n,c,12,13),16777215) && U32.is_eq(pixel(8n,c,13,13),12303291) &&
      U32.is_eq(pixel(8n,c,7,13),1193046) && U32.is_eq(pixel(8n,c,24,13),1193046)
    case _: False{}

def run_count(runs: List<&2,L.Placed>) -> U32:
  U32.from_nat(List.length(&2,L.Placed,runs))
def only_ellipsis(runs: List<&2,L.Placed>) -> Bool:
  match runs:
    case L.Placed{0,glyph} <> []:
      # Inter regular14 ellipsis advance is independently pinned at12px.
      U32.is_eq(L.width(glyph),12)
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    require(painted(C.fill_rect(C.Flat{0},R.Rect{8,8,16,16},1193046)),"checked rectangle writes only its half-open tile and keeps adjacent pixels")
    require(edge_painted(C.fill_rect(C.Flat{0},R.Rect{2040,2040,2048,2048},16777215)),"last legal tile never aliases the origin")
    require(refused(C.fill_rect(C.Flat{0},R.Rect{2048,0,2056,8},1)),"out-of-canvas rectangle is refused before tree-coordinate wrap")
    require(refused(C.fill_rect(C.Flat{0},R.Rect{16,0,8,8},1)),"reversed rectangle is refused before unsigned subtraction")
    require(refused(C.fill_rect(C.Flat{0},R.Rect{1,0,9,8},1)),"non-grid rectangle is refused instead of silently rounding")
    require(refused(C.fill_rect(C.Flat{0},R.Rect{4294967295,0,0,8},1)),"maximum unsigned coordinate cannot wrap into a valid rectangle")
    require(label_pixels(L.draw(C.Flat{1193046},"A",R.Rect{8,8,24,32},L.Style{L.Regular{},16777215,0})),"label painter matches independent coverage samples and preserves outside pixels")
    require(refused(L.draw(C.Flat{0},"A",R.Rect{8,8,24,24},L.Style{L.Regular{},1,0})),"label rejects a rectangle shorter than its documented line height")
    require(refused(L.draw(C.Flat{0},"A",R.Rect{8,8,23,32},L.Style{L.Regular{},1,0})),"label rejects non-grid clipping width")
    require(U32.is_eq(L.height(L.Regular{}),24) && U32.is_eq(L.baseline(L.Regular{}),16) && U32.is_eq(L.height(L.Heading{}),32) && U32.is_eq(L.baseline(L.Heading{}),24),"typed typography exposes pinned regular and heading metrics")
    require(U32.is_eq(L.measured(128n,0,"History",0,200),46) && U32.is_eq(L.measured(128n,1,"History",0,200),50) && U32.is_eq(L.measured(128n,2,"History",0,200),77),"proportional measurement preserves three independently pinned widths")
    require(only_ellipsis(L.layout(128n,0,"WWW",0,16)),"overflow label reserves actual ellipsis width")
    require(U32.is_eq(run_count(L.layout(128n,0,"A",0,10)),1) && U32.is_eq(run_count(L.layout(128n,0,"A",0,0)),0),"exact-fitting label is preserved and zero width is empty")
    require(U32.is_eq(run_count(L.layout(2n,0,"AAAA",0,64)),2),"label scalar traversal is bounded by explicit fuel")
    require(U32.is_eq(C.blend(16777215,0,0),0) && U32.is_eq(C.blend(16777215,0,15),16777215),"shared coverage blend endpoints remain exact")
