import Base
import ../src/attachment_preview.bend as P
import ../src/attachment_preview_geometry.bend as G
import ../src/attachment_preview_render.bend as R
import ../src/attachment_image_types.bend as T
import ../src/attachment_png.bend as Png
import ./png_fixtures.bend as F

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def bookmark() -> String: "snapshot=17;record=11;reference=2;path=/message/content/3/source;query=role:user;row=4;scroll=23;caret=91;anchor=84"

def ready(result: Result<&2,&1,T.Failure,P.State<String>>) -> IO(P.State<String>):
  match result:
    case Done{state}: IO.pure(P.State<String>,state)
    case Fail{T.Failure{_,detail}}: IO.die(P.State<String>,1,"preview fixture failed: " ++ detail)

def decoded(result: Result<&2,&1,T.Failure,T.Raster>) -> IO(P.State<String>):
  match result:
    case Done{raster}: ready(P.open(String,bookmark(),raster))
    case Fail{T.Failure{_,detail}}: IO.die(P.State<String>,1,"PNG fixture failed: " ++ detail)

def fixture() -> IO(P.State<String>): decoded(Png.decode(F.rgba_filters()))

def back_is_exact(step: P.Step<String>) -> Bool:
  match step:
    case P.Back{value}: String.eq(value,bookmark())
    case _: False{}

def closed_is_exact(step: P.Step<String>) -> Bool:
  match step:
    case P.Closed{value}: String.eq(value,bookmark())
    case _: False{}

def state_is(state: P.State<String>,actual: Bool,x: U32,y: U32) -> Bool:
  P.State{value,_,G.View{a,b,c},_,_} = state
  String.eq(value,bookmark()) && U32.is_eq(Bool.to_u32(a),Bool.to_u32(actual)) && U32.is_eq(b,x) && U32.is_eq(c,y)

def step_is(step: P.Step<String>,actual: Bool,x: U32,y: U32) -> Bool:
  match step:
    case P.Kept{state}: state_is(state,actual,x,y)
    case _: False{}

def pixel(depth: Nat,image: Image,+x: U32,+y: U32) -> U32:
  match depth image:
    case _ Pix{color}: color
    case 0n _: 0
    case 1n+ +rest Qua{tl,tr,bl,br}:
      +half : U32 = U32.shln(1,rest)
      pixel(rest,Bool.pick(Image,U32.is_lt(y,half),Bool.pick(Image,U32.is_lt(x,half),tl,tr),Bool.pick(Image,U32.is_lt(x,half),bl,br)),U32.mod(x,half),U32.mod(y,half))

def check_image(pair: P.State<String> & Image) -> IO(Unit):
  (state,+image) = pair
  do IO<Unit>:
    check(U32.is_eq(pixel(11n,image,0,0),1193046) && U32.is_eq(pixel(11n,image,535,176),1193046) && U32.is_eq(pixel(11n,image,1176,608),1193046),"renderer preserves caller chrome outside exact reader viewport")
    check(U32.is_eq(pixel(11n,image,536,176),15789806),"fit letterbox uses bounded neutral matte")
    check(U32.is_eq(pixel(11n,image,770,176),16711680),"fit maps first opaque red sample to native RGB without alpha channel shift")
    check(U32.is_eq(pixel(11n,image,856,176),8059514),"half alpha green is exactly composited on the corresponding checker tile")
    check(U32.is_eq(pixel(11n,image,770,263),16053492),"zero-alpha blue contributes no color to checkerboard")
    check(U32.is_eq(pixel(11n,image,770,272),13487565) && U32.is_ne(16053492,13487565),"transparent pixels preserve alternating checkerboard cells")
    check(back_is_exact(P.event(String,Key{27,True{}},state)),"drawing preserves exact captured occurrence and reader bookmark for Escape")

def cache_checked(pair: P.State<String> & Image) -> IO(Unit):
  (state,+image) = pair
  do IO<Unit>:
    check(U32.is_eq(pixel(11n,image,0,0),6636321) && U32.is_eq(pixel(11n,image,535,176),6636321),"cached preview always preserves the caller's current chrome")
    check(U32.is_eq(pixel(11n,image,770,176),16711680),"cached viewport retains exact rendered pixels while chrome changes")
    check(back_is_exact(P.event(String,Key{27,True{}},state)),"cache composition preserves the exact caller bookmark")

def cache_first(pair: P.State<String> & Image) -> IO(Unit):
  (state,_) = pair
  cache_checked(P.draw(String,state,Pix{6636321}))

def quiet(step: P.Step<String>,actual: Bool) -> Bool:
  match step:
    case P.Kept{P.State{value,_,G.View{mode,0,0},_,dirty}}:
      String.eq(value,bookmark()) && U32.is_eq(Bool.to_u32(mode),Bool.to_u32(actual)) && Bool.not(dirty)
    case _: False{}

def quiet_drawn(pair: P.State<String> & Image,event: Event,actual: Bool,label: String) -> IO(Unit):
  (state,_) = pair
  check(quiet(P.event(String,event,state),actual),label)

def interaction() -> IO(Unit):
  do IO<Unit>:
    a : P.State<String> <- fixture()
    check(back_is_exact(P.event(String,Key{27,True{}},a)),"Escape returns exact opaque caller bookmark")
    b : P.State<String> <- fixture()
    check(back_is_exact(P.event(String,Mouse{536,128,0,True{}},b)),"Back button first pixel returns exact caller bookmark")
    c : P.State<String> <- fixture()
    check(step_is(P.event(String,Mouse{624,128,0,True{}},c),False{},0,0),"Back right edge is exclusive and cannot navigate")
    d : P.State<String> <- fixture()
    check(step_is(P.event(String,Mouse{712,128,0,True{}},d),True{},0,0),"100 percent button enters actual-pixel mode")
    e : P.State<String> <- fixture()
    check(step_is(P.event(String,Key{102,True{}},P.set_view(String,e,G.View{True{},99,88})),False{},0,0),"Fit keyboard action resets pan without changing bookmark")
    f : P.State<String> <- fixture()
    check(step_is(P.event(String,Key{27,False{}},f),False{},0,0),"Escape key release does not dispatch Back")
    g : P.State<String> <- fixture()
    check(closed_is_exact(P.event(String,Close{},g)),"window close is distinct from Back and still returns caller bookmark")
    h : P.State<String> <- fixture()
    check(step_is(P.event(String,Scroll{0,0,0.0,F32.sub(0.0,1.0)},h),False{},0,0),"wheel outside preview cannot pan or change reader state")

def refused(result: Result<&2,&1,T.Failure,P.State<String>>) -> Bool:
  match result:
    case Fail{T.Failure{T.InvalidInput{},_}}: True{}
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    interaction()
    check(refused(P.open(String,bookmark(),T.Raster{2,2,4,4,Array.new(U32,1n,0),False{}})),"preview admission rejects array capacity mismatch before any wrapping access")
    check(refused(P.open(String,bookmark(),T.Raster{2,2,3,4,Array.new(U32,2n,0),False{}})),"preview admission rejects exact pixel-count mismatch")
    s : P.State<String> <- fixture()
    check_image(P.draw(String,s,Pix{1193046}))
    cached : P.State<String> <- fixture()
    cache_first(P.draw(String,cached,Pix{1193046}))
    wheel : P.State<String> <- fixture()
    quiet_drawn(P.draw(String,wheel,Pix{0}),Scroll{600,200,0.0,F32.sub(0.0,1.0)},False{},"Fit wheel preserves valid cached pixels without unnecessary redraw")
    arrow : P.State<String> <- fixture()
    quiet_drawn(P.draw(String,arrow,Pix{0}),Key{63235,True{}},False{},"Fit arrow preserves valid cached pixels without unnecessary redraw")
    edge : P.State<String> <- fixture()
    quiet_drawn(P.draw(String,P.set_view(String,edge,G.View{True{},0,0}),Pix{0}),Key{63235,True{}},True{},"actual-size pan already at edge preserves valid cached pixels")
