import Base
import ../src/bend_ui/canvas.bend as C
import ../src/font.bend as Font

# Synthetic coverage visits every 4-bit value plus zero/full and alternating
# rows. Expected colors below are literal RGB samples, independent of blend.
def bits() -> Font.Half:
  Font.Half{1985229328,4275878552,0,4294967295,1431655765,2863311530,252645135,4042322160}

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def choose(right: Bool,bottom: Bool,tl: Image,tr: Image,bl: Image,br: Image) -> Image:
  match right bottom:
    case False{} False{}: tl
    case True{} False{}: tr
    case False{} True{}: bl
    case True{} True{}: br

def pixel(depth: Nat,image: Image,+x: U32,+y: U32) -> U32:
  match depth image:
    case _ Pix{color}: color
    case 0n _: 4294967295
    case 1n+ +rest Qua{tl,tr,bl,br}:
      +half = U32.shln(1,rest)
      pixel(rest,choose(U32.is_ge(x,half),U32.is_ge(y,half),tl,tr,bl,br),U32.mod(x,half),U32.mod(y,half))

def shape(depth: Nat,c: C.Canvas) -> Bool:
  match depth c:
    case 0n C.Flat{_}: True{}
    case 1n+ +rest C.Four{tl,tr,bl,br}: shape(rest,tl) && shape(rest,tr) && shape(rest,bl) && shape(rest,br)
    case _ _: False{}

def expected_pixels(expected: List<&2,U32>,+image: Image,+at: U32) -> Bool:
  match expected:
    case []: U32.is_eq(at,64)
    case color <> rest:
      U32.is_eq(pixel(3n,image,U32.mod(at,8),U32.div(at,8)),color) && expected_pixels(rest,image,U32.add(at,1))

def unselected() -> List<&2,U32>: [0,1118481,2236962,3355443,4473924,5592405,6710886,7829367,8947848,10066329,11184810,12303291,13421772,14540253,15658734,16777215,0,0,0,0,0,0,0,0,16777215,16777215,16777215,16777215,16777215,16777215,16777215,16777215,5592405,5592405,5592405,5592405,5592405,5592405,5592405,5592405,11184810,11184810,11184810,11184810,11184810,11184810,11184810,11184810,16777215,0,16777215,0,16777215,0,16777215,0,0,16777215,0,16777215,0,16777215,0,16777215]
def partial() -> List<&2,U32>: [0,1118481,2237183,3355647,4474111,5592405,6710886,7829367,8947848,10066329,11184895,12303359,13421823,14540253,15658734,16777215,0,0,255,255,255,0,0,0,16777215,16777215,16777215,16777215,16777215,16777215,16777215,16777215,5592405,5592405,5592575,5592575,5592575,5592405,5592405,5592405,11184810,11184810,11184895,11184895,11184895,11184810,11184810,11184810,16777215,0,16777215,255,16777215,0,16777215,0,0,16777215,255,16777215,255,16777215,0,16777215]
def selected() -> List<&2,U32>: [255,1118719,2237183,3355647,4474111,5592575,6711039,7829503,8947967,10066431,11184895,12303359,13421823,14540287,15658751,16777215,255,255,255,255,255,255,255,255,16777215,16777215,16777215,16777215,16777215,16777215,16777215,16777215,5592575,5592575,5592575,5592575,5592575,5592575,5592575,5592575,11184895,11184895,11184895,11184895,11184895,11184895,11184895,11184895,16777215,255,16777215,255,16777215,255,16777215,255,255,16777215,255,16777215,255,16777215,255,16777215]

def compact(c: C.Canvas,want: U32) -> Bool:
  match c:
    case C.Tile{_,fg,bg}: U32.is_eq(fg,16777215) && U32.is_eq(bg,want)
    case _: False{}

def fast(value: Result<&2,&2,C.Failure,C.Canvas>,want: U32,expected: List<&2,U32>) -> Bool:
  match value:
    case Done{+c}: compact(c,want) && expected_pixels(expected,C.canvas.image(c),0)
    case _: False{}

def partial_exact(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Done{+c}: shape(3n,c) && expected_pixels(partial(),C.canvas.image(c),0)
    case _: False{}

def edge_pixels(value: Result<&2,&2,C.Failure,C.Canvas>,+x: U32,+y: U32,left: U32,right: U32) -> Bool:
  match value:
    case Done{c}:
      +image: Image = C.canvas.image(c)
      U32.is_eq(pixel(3n,image,x,y),left) && U32.is_eq(pixel(3n,image,U32.add(x,1),y),right)
    case _: False{}

def one_column(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Done{c}:
      +image: Image = C.canvas.image(c)
      U32.is_eq(pixel(3n,image,2,2),0) && U32.is_eq(pixel(3n,image,3,2),255) && U32.is_eq(pixel(3n,image,4,2),0)
    case _: False{}

def refused(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Fail{C.InvalidBounds{}}: True{}
    case _: False{}

# Compare all surrounding pixels in a 24x24 square, including actual glyph
# tiles on either side, after replacing only the center tile.
def outside(fuel: Nat,+before: Image,+after: Image,+at: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      +x: U32 = U32.mod(at,24)
      +y: U32 = U32.div(at,24)
      (Bool.not(U32.is_lt(x,8) || U32.is_ge(x,16) || U32.is_lt(y,8) || U32.is_ge(y,16)) ||
        U32.is_eq(pixel(11n,before,x,y),pixel(11n,after,x,y))) && outside(rest,before,after,U32.add(at,1))

def adjacent(value: Result<&2,&2,C.Failure,C.Canvas>) -> Bool:
  match value:
    case Done{tile}:
      left: C.Canvas = C.canvas.set(8n,C.Flat{1193046},0,1,C.Tile{bits(),16777215,0})
      +before: C.Canvas = C.canvas.set(8n,left,2,1,C.Tile{bits(),16777215,255})
      after: C.Canvas = C.canvas.set(8n,before,1,1,tile)
      outside(576n,C.canvas.image(before),C.canvas.image(after),0)
    case _: False{}

def paint(lo: U32,hi: U32) -> Result<&2,&2,C.Failure,C.Canvas>:
  C.coverage_tile(bits(),16777215,0,255,lo,hi)

def main() -> IO(Unit):
  do IO<Unit>:
    require(fast(paint(0,0),0,unselected()),"empty origin interval retains Tile and every unselected coverage pixel")
    require(fast(paint(4,4),0,unselected()),"empty middle interval retains Tile and exact source coverage")
    require(fast(paint(8,8),0,unselected()),"empty end interval is legal and preserves all pixels")
    require(fast(paint(0,8),255,selected()),"full interval retains Tile and every selected coverage pixel")
    require(partial_exact(paint(2,5)),"same-tile two-edge selection has exactly three Four levels and all 64 exact RGB pixels")
    require(edge_pixels(paint(0,3),2,0,2237183,3355443),"prefix selection ends at its exact half-open pixel boundary")
    require(edge_pixels(paint(5,8),4,0,4473924,5592575),"suffix selection begins at its exact pixel boundary")
    require(one_column(paint(3,4)),"one selected zero-coverage column leaves both adjacent columns unchanged")
    require(refused(paint(5,2)),"reversed selection bounds are refused")
    require(refused(paint(0,9)),"selection extending beyond the tile is refused")
    require(refused(paint(9,9)),"out-of-range empty selection is refused")
    require(refused(paint(4294967295,4294967295)),"maximum unsigned bounds cannot wrap into a valid tile")
    require(refused(paint(4294967295,0)),"wrapped reversed bounds are refused")
    require(adjacent(paint(2,5)),"partial subtree insertion preserves every surrounding pixel and adjacent glyph tile")
