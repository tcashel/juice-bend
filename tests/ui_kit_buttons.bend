import Base
import ../src/bend_ui/button.bend as B
import ../src/bend_ui/region.bend as R
import ../src/bend_ui/canvas.bend as C
import ./ui_kit_labels.bend as Pixel

def button(enabled: Bool,label: String) -> B.Button:
  B.Button{R.ControlRegion{10,R.Rect{16,16,112,48},enabled,True{}},label}

def style() -> B.Style:
  B.Style{16777215,6710886,0,1118481,65280,255}

def accepted(value: Result<&2,&2,C.Failure,C.Canvas>) -> C.Canvas:
  match value:
    case Done{canvas}: canvas
    case Fail{_}: C.Flat{16711680}

def draw(enabled: Bool,focus: Bool,label: String) -> C.Canvas:
  accepted(B.draw(C.Flat{1193046},button(enabled,label),style(),focus))

def hit(value: Maybe<&2,U32>,expected: U32) -> Bool:
  match value:
    case Some{actual}: U32.is_eq(actual,expected)
    case None{}: U32.is_eq(expected,99)

def pointer(+enabled: Bool,x: U32,y: U32,expected: U32) -> Bool:
  hit(R.hit(1n,[B.region(button(enabled,"A"))],x,y),expected)

def outside_valid(inside: Bool,value: U32) -> Bool:
  match inside:
    case True{}: True{}
    case False{}: U32.is_eq(value,1193046)

def outside(fuel: Nat,+canvas: C.Canvas,+index: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      +x = U32.mod(index,128)
      +y = U32.div(index,128)
      outside_valid(U32.is_ge(x,16) && U32.is_lt(x,112) && U32.is_ge(y,16) && U32.is_lt(y,48),
        Pixel.pixel(8n,canvas,x,y)) && outside(rest,canvas,U32.add(index,1))

def repeated(fuel: Nat) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: "W" ++ repeated(rest)

def refused(bounds: R.Rect) -> Bool:
  Pixel.refused(B.draw(C.Flat{1193046},B.Button{R.ControlRegion{10,bounds,True{},False{}},"A"},style(),False{}))

def patterned() -> C.Canvas:
  +underlay = C.box(C.Flat{1193046},16,16,8,8,11259375)
  accepted(B.draw(underlay,button(True{},""),style(),False{}))

def main() -> IO(Unit):
  +plain = draw(True{},False{},"")
  +named = draw(True{},False{},"A")
  +disabled = draw(False{},True{},"A")
  +focused = draw(True{},True{},"A")
  do IO<Unit>:
    Pixel.require(pointer(True{},16,16,10) && pointer(True{},111,47,10),"button rectangular target includes rounded corners and its final inside pixel")
    Pixel.require(pointer(True{},15,16,99) && pointer(True{},112,47,99) && pointer(True{},16,48,99),"button half-open boundary excludes its left neighbor right edge and bottom edge")
    Pixel.require(pointer(False{},64,32,99),"painted disabled button cannot intercept a pointer action")
    Pixel.require(hit(R.hit(2n,[B.region(button(True{},"A")),R.ControlRegion{20,R.Rect{120,16,216,48},True{},False{}}],116,32),99),"spacing between adjacent controls remains inert")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,plain,16,16),1193046) && U32.is_eq(Pixel.pixel(8n,plain,18,18),65280) && U32.is_eq(Pixel.pixel(8n,plain,19,19),0),"fixed rounded corner retains background then exposes a one-pixel outline and body")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,plain,64,16),65280) && U32.is_eq(Pixel.pixel(8n,plain,16,32),65280) && U32.is_eq(Pixel.pixel(8n,plain,64,47),65280) && U32.is_eq(Pixel.pixel(8n,plain,17,32),0),"top side and bottom outlines stay inside the declared 32px control")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,patterned(),16,16),11259375),"rounded cutout preserves the actual underlying canvas instead of assuming one background color")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,named,27,29),2236962) && U32.is_eq(Pixel.pixel(8n,named,28,29),16777215) && U32.is_eq(Pixel.pixel(8n,named,29,29),12303291),"shared label keeps independently pinned A coverage at the deliberate 8px inset")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,focused,64,16),255) && U32.is_eq(Pixel.pixel(8n,named,64,16),65280),"keyboard focus has a visible boundary without moving its hit target")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,disabled,64,16),65280) && U32.is_eq(Pixel.pixel(8n,disabled,64,32),1118481) && U32.is_eq(Pixel.pixel(8n,disabled,28,29),6710886),"disabled style changes body and ink and cannot display an enabled focus edge")
    Pixel.require(outside(8192n,named,0),"button preserves every sampled pixel outside its rectangle")
    Pixel.require(outside(8192n,draw(True{},False{},repeated(1000n)),0),"bounded long-label clipping cannot paint into adjacent controls")
    Pixel.require(refused(R.Rect{16,16,40,48}) && refused(R.Rect{16,16,112,56}),"button rejects insufficient label width and unsupported height")
    Pixel.require(refused(R.Rect{17,16,113,48}) && refused(R.Rect{112,16,16,48}),"button rejects unaligned and reversed geometry before painting")
    Pixel.require(refused(R.Rect{2040,16,2136,48}) && refused(R.Rect{4294967295,16,16,48}),"button rejects canvas overflow and wrapped unsigned bounds")
