import Base
import ./attachment_image_types.bend as T
import ./attachment_preview_geometry.bend as G
import ./attachment_preview_render.bend as Render

type State<-B: Data> is Type:
  State{bookmark: B,raster: T.Raster,view: G.View,image: Image,dirty: Bool}
type Step<-B: Data> is Type:
  Kept{state: State<B>}
  Back{bookmark: B}
  Closed{bookmark: B}

def admitted_extent(-B: Data,valid: Bool,bookmark: B,pixels: Array<U32>,width: U32,height: U32,count: U32,capacity: U32,notice: Bool) -> Result<&2,&1,T.Failure,State<B>>:
  match valid:
    case False{}: Fail{T.Failure{T.InvalidInput{},"Decoded image array extent disagrees with its metadata"}}
    case True{}: Done{State{bookmark,T.Raster{width,height,count,capacity,pixels,notice},G.View{False{},0,0},Pix{0},True{}}}

def admitted_size(-B: Data,bookmark: B,pair: Array<U32> & U32,+width: U32,+height: U32,+count: U32,+capacity: U32,notice: Bool) -> Result<&2,&1,T.Failure,State<B>>:
  (pixels,actual) = pair
  admitted_extent(B,U32.is_eq(actual,capacity) && U32.is_eq(count,U32.mul(width,height)) && U32.is_le(count,capacity) && U32.is_le(capacity,T.max_pixels()),
    bookmark,pixels,width,height,count,capacity,notice)

def admitted_raster(-B: Data,bookmark: B,raster: T.Raster) -> Result<&2,&1,T.Failure,State<B>>:
  T.Raster{w,h,count,capacity,pixels,notice} = raster
  admitted_size(B,bookmark,Array.size(U32,pixels),w,h,count,capacity,notice)

def admitted_result(-B: Data,result: Result<&2,&2,T.Failure,G.Frame>,bookmark: B,raster: T.Raster) -> Result<&2,&1,T.Failure,State<B>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{_}: admitted_raster(B,bookmark,raster)

def admitted(-B: Data,bookmark: B,raster: T.Raster,result: Result<&2,&2,T.Failure,G.Frame>) -> Result<&2,&1,T.Failure,State<B>>:
  admitted_result(B,result,bookmark,raster)

# The caller supplies an exact decoded owned raster and its complete bookmark.
# No source path, worker, byte export, provider, or network API is available here.
def open(-B: Data,bookmark: B,raster: T.Raster) -> Result<&2,&1,T.Failure,State<B>>:
  T.Raster{+w,+h,count,capacity,pixels,notice} = raster
  admitted(B,bookmark,T.Raster{w,h,count,capacity,pixels,notice},G.fit(w,h))

def back(-B: Data,state: State<B>) -> Step<B>:
  State{bookmark,_,_,_,_} = state
  Back{bookmark}

def closed(-B: Data,state: State<B>) -> Step<B>:
  State{bookmark,_,_,_,_} = state
  Closed{bookmark}

def set_view(-B: Data,state: State<B>,view: G.View) -> State<B>:
  State{bookmark,raster,_,image,_} = state
  State{bookmark,raster,view,image,True{}}

def same_view(a: G.View,b: G.View) -> Bool:
  G.View{aa,ax,ay} = a
  G.View{ba,bx,by} = b
  U32.is_eq(Bool.to_u32(aa),Bool.to_u32(ba)) && U32.is_eq(ax,bx) && U32.is_eq(ay,by)

def pan_updated(-B: Data,changed: Bool,state: State<B>,view: G.View) -> State<B>:
  match changed:
    case False{}: state
    case True{}: set_view(B,state,view)

def pan(-B: Data,state: State<B>,negative_x: Bool,negative_y: Bool,dx: U32,dy: U32) -> State<B>:
  State{bookmark,T.Raster{+w,+h,count,capacity,pixels,notice},+view,image,dirty} = state
  +next : G.View = G.move(w,h,view,negative_x,negative_y,dx,dy)
  pan_updated(B,Bool.not(same_view(view,next)),State{bookmark,T.Raster{w,h,count,capacity,pixels,notice},view,image,dirty},next)

def key(-B: Data,code: U32,state: State<B>) -> Step<B>:
  match code:
    case 27: back(B,state)
    case 49: Kept{set_view(B,state,G.View{True{},0,0})}
    case 70: Kept{set_view(B,state,G.View{False{},0,0})}
    case 102: Kept{set_view(B,state,G.View{False{},0,0})}
    case 63234: Kept{pan(B,state,True{},False{},32,0)}
    case 63235: Kept{pan(B,state,False{},False{},32,0)}
    case 63232: Kept{pan(B,state,False{},True{},0,32)}
    case 63233: Kept{pan(B,state,False{},False{},0,32)}
    case _: Kept{state}

# Select a reusable action before passing the affine State through key once.
# These are the same commands used by the actual keyboard handlers above.
def mouse_code(+x: U32,+y: U32) -> U32:
  Bool.pick(U32,Render.inside(x,y,536,128,88,32),27,
    Bool.pick(U32,Render.inside(x,y,632,128,72,32),70,
      Bool.pick(U32,Render.inside(x,y,712,128,88,32),49,0)))

def mouse(-B: Data,state: State<B>,x: U32,y: U32) -> Step<B>:
  key(B,mouse_code(x,y),state)

def wheel_inside(-B: Data,inside: Bool,state: State<B>,+dx: F32,+dy: F32) -> Step<B>:
  match inside:
    case False{}: Kept{state}
    case True{}: Kept{pan(B,state,F32.is_gt(dx,0.0),F32.is_gt(dy,0.0),Bool.pick(U32,F32.is_eq(dx,0.0),0,32),Bool.pick(U32,F32.is_eq(dy,0.0),0,32))}

def wheel(-B: Data,state: State<B>,x: U32,y: U32,dx: F32,dy: F32) -> Step<B>:
  wheel_inside(B,Render.inside(x,y,536,176,640,432),state,dx,dy)

def event(-B: Data,event: Event,state: State<B>) -> Step<B>:
  match event:
    case Key{code,True{}}: key(B,code,state)
    case Mouse{x,y,0,True{}}: mouse(B,state,x,y)
    case Scroll{x,y,dx,dy}: wheel(B,state,x,y,dx,dy)
    case Close{}: closed(B,state)
    case _: Kept{state}

def rendered(-B: Data,bookmark: B,view: G.View,pair: T.Raster & Image) -> State<B> & Image:
  (raster,+image) = pair
  (State{bookmark,raster,view,image,False{}},image)

def draw_frame(-B: Data,bookmark: B,raster: T.Raster,view: G.View,+base: Image,result: Result<&2,&2,T.Failure,G.Frame>) -> State<B> & Image:
  match result:
    case Fail{_}: (State{bookmark,raster,view,base,False{}},base)
    case Done{frame}: rendered(B,bookmark,view,Render.draw(raster,frame,base))

def draw_requested(-B: Data,bookmark: B,raster: T.Raster,+view: G.View,base: Image) -> State<B> & Image:
  T.Raster{+w,+h,count,capacity,pixels,notice} = raster
  draw_frame(B,bookmark,T.Raster{w,h,count,capacity,pixels,notice},view,base,G.frame(w,h,view))

def draw_mode(-B: Data,dirty: Bool,bookmark: B,raster: T.Raster,view: G.View,+image: Image,base: Image) -> State<B> & Image:
  match dirty:
    case True{}: draw_requested(B,bookmark,raster,view,base)
    case False{}: (State{bookmark,raster,view,image,False{}},Render.compose(image,base))

def draw(-B: Data,state: State<B>,base: Image) -> State<B> & Image:
  State{bookmark,raster,view,image,dirty} = state
  draw_mode(B,dirty,bookmark,raster,view,image,base)
