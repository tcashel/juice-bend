import Base
import ./attachment_image_types.bend as T
import ./attachment_preview_geometry.bend as G

# Array access is confined to the admitted decoded raster. Image.Pix is RGB,
# not packed RGBA; every sample is explicitly composited in Bend.
def matte() -> U32: 15789806
def light() -> U32: 16053492
def dark() -> U32: 13487565

def checker(+x: U32,+y: U32) -> U32:
  Bool.pick(U32,U32.is_eq(U32.and(U32.add(U32.div(x,16),U32.div(y,16)),1),0),light(),dark())

def inside(+x: U32,+y: U32,+left: U32,+top: U32,width: U32,height: U32) -> Bool:
  U32.is_ge(x,left) && U32.is_ge(y,top) && U32.is_lt(x,U32.add(left,width)) && U32.is_lt(y,U32.add(top,height))

def intersects(+x: U32,+y: U32,+size: U32,+left: U32,+top: U32,width: U32,height: U32) -> Bool:
  U32.is_lt(x,U32.add(left,width)) && U32.is_lt(y,U32.add(top,height)) && U32.is_gt(U32.add(x,size),left) && U32.is_gt(U32.add(y,size),top)

def composed(pair: Array<U32> & U32,background: U32) -> Array<U32> & Image:
  (pixels,pixel) = pair
  (pixels,Pix{T.rgb(pixel,background)})

def sample_index_checked(ok: Bool,pixels: Array<U32>,index: U32,background: U32) -> Array<U32> & Image:
  match ok:
    case True{}: composed(Array.get(U32,pixels,index),background)
    case False{}: (pixels,Pix{matte()})

def sample_index(pixels: Array<U32>,+index: U32,count: U32,capacity: U32,background: U32) -> Array<U32> & Image:
  sample_index_checked(U32.is_lt(index,count) && U32.is_lt(index,capacity),pixels,index,background)

def sample_bounds(ok: Bool,pixels: Array<U32>,width: U32,sx: U32,sy: U32,count: U32,capacity: U32,background: U32) -> Array<U32> & Image:
  match ok:
    case True{}: sample_index(pixels,U32.add(U32.mul(sy,width),sx),count,capacity,background)
    case False{}: (pixels,Pix{matte()})

def sample(point: Maybe<&2,G.Point>,pixels: Array<U32>,+width: U32,+height: U32,count: U32,capacity: U32,background: U32) -> Array<U32> & Image:
  match point:
    case None{}: (pixels,Pix{matte()})
    case Some{G.Point{+sx,+sy}}:
      sample_bounds(U32.is_lt(sx,width) && U32.is_lt(sy,height),pixels,width,sx,sy,count,capacity,background)

def same_points(first: Maybe<&2,G.Point>,last: Maybe<&2,G.Point>) -> Bool:
  match first last:
    case Some{G.Point{ax,ay}} Some{G.Point{bx,by}}: U32.is_eq(ax,bx) && U32.is_eq(ay,by)
    case _ _: False{}

def uniform(+frame: G.Frame,+x: U32,+y: U32,+size: U32) -> Bool:
  +last_x : U32 = U32.sub(U32.add(x,size),1)
  +last_y : U32 = U32.sub(U32.add(y,size),1)
  U32.is_eq(U32.div(x,16),U32.div(last_x,16)) && U32.is_eq(U32.div(y,16),U32.div(last_y,16)) &&
    same_points(G.point(frame,x,y),G.point(frame,last_x,last_y))

def children(image: Image) -> Image & (Image & (Image & Image)):
  match image:
    case Pix{+color}: (Pix{color},(Pix{color},(Pix{color},Pix{color})))
    case Qua{tl,tr,bl,br}: (tl,(tr,(bl,br)))

def join_last(pair: Array<U32> & Image,tl: Image,tr: Image,bl: Image) -> Array<U32> & Image:
  (pixels,br) = pair
  (pixels,Qua{tl,tr,bl,br})

def join_third(pair: Array<U32> & Image,tl: Image,tr: Image,last: Array<U32> -> Array<U32> & Image) -> Array<U32> & Image:
  (pixels,bl) = pair
  join_last(last(pixels),tl,tr,bl)

def join_second(pair: Array<U32> & Image,tl: Image,third: Array<U32> -> Array<U32> & Image,last: Array<U32> -> Array<U32> & Image) -> Array<U32> & Image:
  (pixels,tr) = pair
  join_third(third(pixels),tl,tr,last)

def join_first(pair: Array<U32> & Image,second: Array<U32> -> Array<U32> & Image,third: Array<U32> -> Array<U32> & Image,last: Array<U32> -> Array<U32> & Image) -> Array<U32> & Image:
  (pixels,tl) = pair
  join_second(second(pixels),tl,third,last)

def split_children(parts: Image & (Image & (Image & Image)),pixels: Array<U32>,
  first: Array<U32> -> Image -> Array<U32> & Image,second: Array<U32> -> Image -> Array<U32> & Image,
  third: Array<U32> -> Image -> Array<U32> & Image,last: Array<U32> -> Image -> Array<U32> & Image) -> Array<U32> & Image:
  (tl,second_parts) = parts
  (tr,third_parts) = second_parts
  (bl,br) = third_parts
  join_first(first(pixels,tl),p => second(p,tr),p => third(p,bl),p => last(p,br))

# Decide with reusable metadata first, then transfer the array to exactly one
# branch. Ordinary callback functions must never capture the affine owner twice.
def decision(+frame: G.Frame,+x: U32,+y: U32,+size: U32) -> U32:
  G.Frame{left,top,fw,fh,_,_,_,_} = frame
  Bool.pick(U32,intersects(x,y,size,536,176,640,432),
    Bool.pick(U32,inside(x,y,536,176,640,432) && inside(U32.sub(U32.add(x,size),1),U32.sub(U32.add(y,size),1),536,176,640,432),
      Bool.pick(U32,intersects(x,y,size,left,top,fw,fh),Bool.pick(U32,uniform(frame,x,y,size),2,3),1),3),0)

def paint_leaf(ok: Bool,pixels: Array<U32>,frame: G.Frame,width: U32,height: U32,count: U32,capacity: U32,+x: U32,+y: U32,base: Image) -> Array<U32> & Image:
  match ok:
    case True{}: sample(G.point(frame,x,y),pixels,width,height,count,capacity,checker(x,y))
    case False{}: (pixels,base)

def node(mode: U32,pixels: Array<U32>,frame: G.Frame,width: U32,height: U32,count: U32,capacity: U32,+x: U32,+y: U32,base: Image,
  split: Array<U32> -> Image -> Array<U32> & Image) -> Array<U32> & Image:
  match mode:
    case 0: (pixels,base)
    case 1: (pixels,Pix{matte()})
    case 2: sample(G.point(frame,x,y),pixels,width,height,count,capacity,checker(x,y))
    case _: split(pixels,base)

def paint(depth: Nat,pixels: Array<U32>,+frame: G.Frame,+width: U32,+height: U32,+count: U32,+capacity: U32,+x: U32,+y: U32,+size: U32,base: Image) -> Array<U32> & Image:
  match depth:
    case 0n: paint_leaf(inside(x,y,536,176,640,432),pixels,frame,width,height,count,capacity,x,y,base)
    case 1n+ +rest:
      node(decision(frame,x,y,size),pixels,frame,width,height,count,capacity,x,y,base,p => b =>
        split_children(children(b),p,
          a => c => paint(rest,a,frame,width,height,count,capacity,x,y,U32.shr(size),c),
          a => c => paint(rest,a,frame,width,height,count,capacity,U32.add(x,U32.shr(size)),y,U32.shr(size),c),
          a => c => paint(rest,a,frame,width,height,count,capacity,x,U32.add(y,U32.shr(size)),U32.shr(size),c),
          a => c => paint(rest,a,frame,width,height,count,capacity,U32.add(x,U32.shr(size)),U32.add(y,U32.shr(size)),U32.shr(size),c)))

def rendered(pair: Array<U32> & Image,w: U32,h: U32,count: U32,capacity: U32,notice: Bool) -> T.Raster & Image:
  (pixels,image) = pair
  (T.Raster{w,h,count,capacity,pixels,notice},image)

def draw(raster: T.Raster,frame: G.Frame,base: Image) -> T.Raster & Image:
  T.Raster{+w,+h,+count,+capacity,pixels,notice} = raster
  rendered(paint(11n,pixels,frame,w,h,count,capacity,0,0,2048,base),w,h,count,capacity,notice)

# Cached image pixels never own the surrounding caller chrome. Recompose only
# the preview rectangle, keeping newly supplied reader/status chrome current.
def child(image: Image,index: U32) -> Image:
  match image index:
    case Pix{color} _: Pix{color}
    case Qua{tl,_,_,_} 0: tl
    case Qua{_,tr,_,_} 1: tr
    case Qua{_,_,bl,_} 2: bl
    case Qua{_,_,_,br} _: br

def overlay(depth: Nat,+cached: Image,+base: Image,+x: U32,+y: U32,+size: U32) -> Image:
  match depth:
    case 0n: Bool.pick(Image,inside(x,y,536,176,640,432),cached,base)
    case 1n+ +rest:
      T.branch(Image,intersects(x,y,size,536,176,640,432),
        _ => T.branch(Image,inside(x,y,536,176,640,432) && inside(U32.sub(U32.add(x,size),1),U32.sub(U32.add(y,size),1),536,176,640,432),
          _ => cached,
          _ => Qua{overlay(rest,child(cached,0),child(base,0),x,y,U32.shr(size)),
            overlay(rest,child(cached,1),child(base,1),U32.add(x,U32.shr(size)),y,U32.shr(size)),
            overlay(rest,child(cached,2),child(base,2),x,U32.add(y,U32.shr(size)),U32.shr(size)),
            overlay(rest,child(cached,3),child(base,3),U32.add(x,U32.shr(size)),U32.add(y,U32.shr(size)),U32.shr(size))}),
        _ => base)

def compose(cached: Image,base: Image) -> Image:
  overlay(11n,cached,base,0,0,2048)
