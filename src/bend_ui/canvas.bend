# Shared pure 8px tile canvas. The application supplies colors and layout.
# Glyph coverage data remains under its font license; no OS/font parser here.
import Base
import ../font.bend as Font
import ./region.bend as Region

type Canvas is Data:
  Flat{color: U32}
  Tile{bits: Font.Half,foreground: U32,background: U32}
  Four{tl: Canvas,tr: Canvas,bl: Canvas,br: Canvas}

type Failure is Data:
  InvalidBounds{}

def extent() -> U32: 2048
def cell() -> U32: 8

def canvas.children(+tl: Canvas, +tr: Canvas, +bl: Canvas, +br: Canvas,
  +quad: U32, update: Canvas -> Canvas) -> Canvas:
  match quad:
    case 0:
      Four{update(tl), tr, bl, br}
    case 1:
      Four{tl, update(tr), bl, br}
    case 2:
      Four{tl, tr, update(bl), br}
    case _:
      Four{tl, tr, bl, update(br)}

def canvas.update(+c: Canvas, +quad: U32, update: Canvas -> Canvas) -> Canvas:
  match c:
    case Flat{+bg}:
      canvas.children(Flat{bg}, Flat{bg}, Flat{bg}, Flat{bg}, quad, update)
    case Tile{bits, fg, +bg}:
      canvas.children(Flat{bg}, Flat{bg}, Flat{bg}, Flat{bg}, quad, update)
    case Four{tl, tr, bl, br}:
      canvas.children(tl, tr, bl, br, quad, update)

def canvas.set(+d: Nat, +c: Canvas, +x: U32, +y: U32, +tile: Canvas) -> Canvas:
  match d:
    case 0n:
      tile
    case 1n+ +p:
      +half = U32.shln(1, p)
      +quad = U32.add(Bool.to_u32(U32.is_ge(x, half)), U32.mul(2, Bool.to_u32(U32.is_ge(y, half))))
      canvas.update(c, quad, sub => canvas.set(p, sub, U32.mod(x, half), U32.mod(y, half), tile))

def glyph.put(+c: Canvas,+bits: Font.Glyph,+x: U32,+y: U32,+foreground: U32,+background: U32) -> Canvas:
  top = canvas.set(8n,c,x,y,Tile{Font.half(bits,True{}),foreground,background})
  canvas.set(8n,top,x,U32.add(y,1),Tile{Font.half(bits,False{}),foreground,background})

def fill.row(+width: Nat,+c: Canvas,+x: U32,+y: U32,+color: U32) -> Canvas:
  match width:
    case 0n: c
    case 1n+n: fill.row(n,canvas.set(8n,c,x,y,Flat{color}),U32.add(x,1),y,color)

def fill(+rows: Nat,+c: Canvas,+x: U32,+y: U32,+width: Nat,+color: U32) -> Canvas:
  match rows:
    case 0n: c
    case 1n+n: fill(n,fill.row(width,c,x,y,color),x,U32.add(y,1),width,color)

def box(c: Canvas,x: U32,y: U32,width: U32,height: U32,color: U32) -> Canvas:
  fill(U32.to_nat(U32.div(height,cell())),c,U32.div(x,cell()),U32.div(y,cell()),U32.to_nat(U32.div(width,cell())),color)

def blend.channel(+fg: U32,+bg: U32,+coverage: U32) -> U32:
  U32.div(U32.add(U32.mul(fg,coverage),U32.mul(bg,U32.sub(15,coverage))),15)

def blend(+fg: U32,+bg: U32,+coverage: U32) -> U32:
  r = blend.channel(U32.and(U32.shrn(fg,16n),255),U32.and(U32.shrn(bg,16n),255),coverage)
  g = blend.channel(U32.and(U32.shrn(fg,8n),255),U32.and(U32.shrn(bg,8n),255),coverage)
  b = blend.channel(U32.and(fg,255),U32.and(bg,255),coverage)
  U32.add(U32.add(U32.shln(r,16n),U32.shln(g,8n)),b)

def glyph.draw(+d: Nat,+x: U32,+y: U32,+bits: Font.Half,+fg: U32,+bg: U32) -> Image:
  match d:
    case 0n: Pix{blend(fg,bg,Font.coverage(bits,x,y))}
    case 1n+ +p:
      +h = U32.shln(1,p)
      Qua{glyph.draw(p,x,y,bits,fg,bg),glyph.draw(p,U32.add(x,h),y,bits,fg,bg),
        glyph.draw(p,x,U32.add(y,h),bits,fg,bg),glyph.draw(p,U32.add(x,h),U32.add(y,h),bits,fg,bg)}

def canvas.image(c: Canvas) -> Image:
  match c:
    case Flat{color}: Pix{color}
    case Tile{bits,fg,bg}: glyph.draw(3n,0,0,bits,fg,bg)
    case Four{tl,tr,bl,br}: Qua{canvas.image(tl),canvas.image(tr),canvas.image(bl),canvas.image(br)}

# Base frames use the smallest power-of-two square enclosing the native
# window; the runtime clips its unused right/bottom pixels. Keep coordinates
# exact by cropping the fixed 2048-square canvas before submitting the image.
def viewport.top_left(image: Image) -> Image:
  match image:
    case Pix{color}: Pix{color}
    case Qua{tl,_,_,_}: tl

def viewport.choose(crop: Bool,image: Image,next: Image -> Image) -> Image:
  match crop:
    case False{}: image
    case True{}: next(viewport.top_left(image))

def viewport.crop(depth: Nat,image: Image,+size: U32,+width: U32,+height: U32) -> Image:
  match depth:
    case 0n: image
    case 1n+rest:
      +half = U32.shr(size)
      viewport.choose(U32.is_le(width,half) && U32.is_le(height,half),image,
        child => viewport.crop(rest,child,half,width,height))

def image_viewport.checked(valid: Bool,c: Canvas,width: U32,height: U32) -> Result<&2,&2,Failure,Image>:
  match valid:
    case False{}: Fail{InvalidBounds{}}
    case True{}: Done{viewport.crop(11n,canvas.image(c),extent(),width,height)}

def image_viewport(c: Canvas,+width: U32,+height: U32) -> Result<&2,&2,Failure,Image>:
  image_viewport.checked(U32.is_gt(width,0) && U32.is_gt(height,0) &&
    U32.is_le(width,extent()) && U32.is_le(height,extent()),c,width,height)


# Public checked pixel rectangle API. End coordinates avoid overflow from x+w.
# Empty aligned rectangles are valid no-ops; reversed/out-of-range/unaligned
# bounds are refused before the low-level tree writer can wrap coordinates.
def bounds_valid(+bounds: Region.Rect) -> Bool:
  Region.Rect{+left,+top,+right,+bottom} = bounds
  U32.is_le(left,right) && U32.is_le(top,bottom) && U32.is_le(right,extent()) && U32.is_le(bottom,extent()) &&
    U32.is_eq(U32.mod(left,cell()),0) && U32.is_eq(U32.mod(top,cell()),0) &&
    U32.is_eq(U32.mod(right,cell()),0) && U32.is_eq(U32.mod(bottom,cell()),0)

def fill_checked(valid: Bool,c: Canvas,bounds: Region.Rect,color: U32) -> Result<&2,&2,Failure,Canvas>:
  match valid:
    case False{}: Fail{InvalidBounds{}}
    case True{}:
      Region.Rect{+left,+top,right,bottom} = bounds
      Done{box(c,left,top,U32.sub(right,left),U32.sub(bottom,top),color)}

def fill_rect(c: Canvas,+bounds: Region.Rect,color: U32) -> Result<&2,&2,Failure,Canvas>:
  fill_checked(bounds_valid(bounds),c,bounds,color)

# A single 8x8 coverage tile with a half-open selected column interval. Empty
# and full intervals retain compact Tile storage. Only boundary tiles need a
# three-level pixel subtree; callers insert it with canvas.set(8n,...).
def coverage_tile.pixels(depth: Nat,+bits: Font.Half,+fg: U32,+bg: U32,+selected_bg: U32,
  +lo: U32,+hi: U32,+x: U32,+y: U32) -> Canvas:
  match depth:
    case 0n:
      Flat{blend(fg,Bool.pick(U32,U32.is_ge(x,lo) && U32.is_lt(x,hi),selected_bg,bg),Font.coverage(bits,x,y))}
    case 1n+ +rest:
      +half = U32.shln(1,rest)
      Four{coverage_tile.pixels(rest,bits,fg,bg,selected_bg,lo,hi,x,y),
        coverage_tile.pixels(rest,bits,fg,bg,selected_bg,lo,hi,U32.add(x,half),y),
        coverage_tile.pixels(rest,bits,fg,bg,selected_bg,lo,hi,x,U32.add(y,half)),
        coverage_tile.pixels(rest,bits,fg,bg,selected_bg,lo,hi,U32.add(x,half),U32.add(y,half))}

def coverage_tile.surface(empty: Bool,+lo: U32,+hi: U32,bits: Font.Half,fg: U32,bg: U32,selected_bg: U32) -> Canvas:
  match empty:
    case True{}: Tile{bits,fg,bg}
    case False{}:
      match lo hi:
        case 0 8: Tile{bits,fg,selected_bg}
        case _ _: coverage_tile.pixels(3n,bits,fg,bg,selected_bg,lo,hi,0,0)

def coverage_tile.checked(valid: Bool,bits: Font.Half,fg: U32,bg: U32,selected_bg: U32,+lo: U32,+hi: U32) -> Result<&2,&2,Failure,Canvas>:
  match valid:
    case False{}: Fail{InvalidBounds{}}
    case True{}: Done{coverage_tile.surface(U32.is_eq(lo,hi),lo,hi,bits,fg,bg,selected_bg)}

def coverage_tile(bits: Font.Half,fg: U32,bg: U32,selected_bg: U32,+lo: U32,+hi: U32) -> Result<&2,&2,Failure,Canvas>:
  coverage_tile.checked(U32.is_le(lo,hi) && U32.is_le(hi,cell()),bits,fg,bg,selected_bg,lo,hi)
