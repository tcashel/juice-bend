# Pure bounded button paint/region descriptor. Callers own actions and focus.
import Base
import ./canvas.bend as C
import ./region.bend as R
import ./label.bend as L
import ../font.bend as Font

type Button is Data:
  Button{region: R.ControlRegion,label: String}

type Style is Data:
  Style{ink: U32,disabled_ink: U32,paper: U32,disabled_paper: U32,
    edge: U32,focus: U32}

type Paint is Data:
  Paint{ink: U32,paper: U32,edge: U32}

def region(button: Button) -> R.ControlRegion:
  Button{value,_} = button
  value

def regions(buttons: List<&2,Button>) -> List<&2,R.ControlRegion>:
  match buttons:
    case []: []
    case button <> rest: region(button) <> regions(rest)

def paint(style: Style,+enabled: Bool,focused: Bool) -> Paint:
  Style{ink,disabled_ink,paper,disabled_paper,edge,focus} = style
  Paint{Bool.pick(U32,enabled,ink,disabled_ink),Bool.pick(U32,enabled,paper,disabled_paper),
    Bool.pick(U32,enabled && focused,focus,edge)}

def valid(+bounds: R.Rect) -> Bool:
  R.Rect{+left,+top,+right,+bottom} = bounds
  C.bounds_valid(bounds) && U32.is_ge(right,left) && U32.is_ge(bottom,top) &&
    U32.is_ge(U32.sub(right,left),32) && U32.is_eq(U32.sub(bottom,top),32)

def choose(right: Bool,bottom: Bool,tl: C.Canvas,tr: C.Canvas,bl: C.Canvas,br: C.Canvas) -> C.Canvas:
  match right bottom:
    case False{} False{}: tl
    case True{} False{}: tr
    case False{} True{}: bl
    case True{} True{}: br

# Read one already-admitted tile. No window/global state or pixel buffer.
def tile_at(depth: Nat,+canvas: C.Canvas,+x: U32,+y: U32) -> C.Canvas:
  match depth canvas:
    case _ C.Flat{color}: C.Flat{color}
    case _ C.Tile{bits,fg,bg}: C.Tile{bits,fg,bg}
    case 0n _: canvas
    case 1n+ +rest C.Four{tl,tr,bl,br}:
      +half = U32.shln(1,rest)
      tile_at(rest,choose(U32.is_ge(x,half),U32.is_ge(y,half),tl,tr,bl,br),U32.mod(x,half),U32.mod(y,half))

def tile_pixel(depth: Nat,canvas: C.Canvas,+x: U32,+y: U32) -> U32:
  match depth canvas:
    case _ C.Flat{color}: color
    case _ C.Tile{bits,fg,bg}: C.blend(fg,bg,Font.coverage(bits,x,y))
    case 0n _: 0
    case 1n+ +rest C.Four{tl,tr,bl,br}:
      +half = U32.shln(1,rest)
      tile_pixel(rest,choose(U32.is_ge(x,half),U32.is_ge(y,half),tl,tr,bl,br),U32.mod(x,half),U32.mod(y,half))

# Fixed radius8, evaluated at pixel centers in doubled integer coordinates.
# Only corner tiles need the circle test; radius/geometry are not unbounded.
def corner(+x: U32,+y: U32,limit: U32,inside_corner: Bool) -> Bool:
  match inside_corner:
    case False{}: True{}
    case True{}:
      +dx = U32.sub(15,U32.mul(x,2))
      +dy = U32.sub(15,U32.mul(y,2))
      U32.is_le(U32.add(U32.mul(dx,dx),U32.mul(dy,dy)),limit)

def frame_color(outer: Bool,inner: Bool,original: U32,edge: U32,surround: U32) -> U32:
  match outer inner:
    case False{} _: surround
    case True{} False{}: edge
    case True{} True{}: original

def frame_pixel(+original: U32,+x: U32,+y: U32,+width: U32,edge: U32,surround: U32) -> U32:
  +near_x = U32.min(x,U32.sub(U32.sub(width,1),x))
  +near_y = U32.min(y,U32.sub(31,y))
  +curved = U32.is_lt(near_x,8) && U32.is_lt(near_y,8)
  frame_color(corner(near_x,near_y,256,curved),
    U32.is_gt(near_x,0) && U32.is_gt(near_y,0) && corner(near_x,near_y,196,curved),
    original,edge,surround)

# Preserve every interior pixel, including the label's descenders. Only the
# one-pixel boundary and rounded corner cutouts replace existing tile pixels.
def frame_pixels(depth: Nat,+tile: C.Canvas,+underlay: C.Canvas,+x: U32,+y: U32,+offset_x: U32,+offset_y: U32,
  +width: U32,+edge: U32) -> C.Canvas:
  match depth:
    case 0n:
      C.Flat{frame_pixel(tile_pixel(3n,tile,x,y),U32.add(offset_x,x),U32.add(offset_y,y),width,edge,tile_pixel(3n,underlay,x,y))}
    case 1n+ +rest:
      +half = U32.shln(1,rest)
      C.Four{frame_pixels(rest,tile,underlay,x,y,offset_x,offset_y,width,edge),
        frame_pixels(rest,tile,underlay,U32.add(x,half),y,offset_x,offset_y,width,edge),
        frame_pixels(rest,tile,underlay,x,U32.add(y,half),offset_x,offset_y,width,edge),
        frame_pixels(rest,tile,underlay,U32.add(x,half),U32.add(y,half),offset_x,offset_y,width,edge)}

def frame_tile(+canvas: C.Canvas,+underlay: C.Canvas,+tx: U32,+ty: U32,left: U32,top: U32,width: U32,edge: U32) -> C.Canvas:
  old = tile_at(8n,canvas,tx,ty)
  base = tile_at(8n,underlay,tx,ty)
  next = frame_pixels(3n,old,base,0,0,U32.sub(U32.mul(tx,8),left),U32.sub(U32.mul(ty,8),top),width,edge)
  C.canvas.set(8n,canvas,tx,ty,next)

def frame_band(fuel: Nat,canvas: C.Canvas,+underlay: C.Canvas,+tx: U32,+ty: U32,+left: U32,+top: U32,+width: U32,+edge: U32) -> C.Canvas:
  match fuel:
    case 0n: canvas
    case 1n+rest:
      frame_band(rest,frame_tile(canvas,underlay,tx,ty,left,top,width,edge),underlay,U32.add(tx,1),ty,left,top,width,edge)

def frame(canvas: C.Canvas,+underlay: C.Canvas,bounds: R.Rect,edge: U32) -> C.Canvas:
  R.Rect{+left,+top,+right,_} = bounds
  +width = U32.sub(right,left)
  +x = U32.div(left,8)
  +y = U32.div(top,8)
  +last = U32.sub(U32.div(right,8),1)
  +fg = edge
  a = frame_band(U32.to_nat(U32.div(width,8)),canvas,underlay,x,y,left,top,width,fg)
  b = frame_band(U32.to_nat(U32.div(width,8)),a,underlay,x,U32.add(y,3),left,top,width,fg)
  c = frame_tile(b,underlay,x,U32.add(y,1),left,top,width,fg)
  d = frame_tile(c,underlay,last,U32.add(y,1),left,top,width,fg)
  e = frame_tile(d,underlay,x,U32.add(y,2),left,top,width,fg)
  frame_tile(e,underlay,last,U32.add(y,2),left,top,width,fg)

def named(result: Result<&2,&2,C.Failure,C.Canvas>,underlay: C.Canvas,bounds: R.Rect,edge: U32) -> Result<&2,&2,C.Failure,C.Canvas>:
  match result:
    case Fail{why}: Fail{why}
    case Done{canvas}: Done{frame(canvas,underlay,bounds,edge)}

def draw_painted(+canvas: C.Canvas,label: String,+bounds: R.Rect,colors: Paint) -> Result<&2,&2,C.Failure,C.Canvas>:
  R.Rect{+left,+top,+right,+bottom} = bounds
  Paint{ink,+paper,edge} = colors
  body = C.box(canvas,left,top,U32.sub(right,left),32,paper)
  named(L.draw(body,label,R.Rect{U32.add(left,8),U32.add(top,8),U32.sub(right,8),bottom},
    L.Style{L.Regular{},ink,paper}),canvas,bounds,edge)

def draw_valid(ok: Bool,+canvas: C.Canvas,button: Button,style: Style,focused: Bool) -> Result<&2,&2,C.Failure,C.Canvas>:
  match ok:
    case False{}: Fail{C.InvalidBounds{}}
    case True{}:
      Button{R.ControlRegion{_,+bounds,enabled,_},label} = button
      draw_painted(canvas,label,bounds,paint(style,enabled,focused))

def draw(canvas: C.Canvas,+button: Button,style: Style,focused: Bool) -> Result<&2,&2,C.Failure,C.Canvas>:
  Button{R.ControlRegion{_,bounds,_,_},_} = button
  draw_valid(valid(bounds),canvas,button,style,focused)
