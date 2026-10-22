import Base
import ../src/attachment_png.bend as Png
import ../src/attachment_image_types.bend as T
import ../src/attachment_preview.bend as P
import ./preview_chrome.bend as C
import ./preview_fixture.bend as Fixture
import ../tests/png_fixtures.bend as Small

type Screen is Type:
  Preview{state: P.State<String>}
  Returned{bookmark: String}
  Unsupported{bookmark: String,detail: String}

def bookmark() -> String: "snapshot 17 / raw record 11 / reference 2 / /message/content/3/source"

def chrome(+message: String) -> Image:
  +a : C.Canvas = C.box(C.Flat{C.paper()},0,0,512,664,C.rail())
  +b : C.Canvas = C.text(a,"Juice Bend",24,32,40,C.ink(),C.rail())
  +c : C.Canvas = C.text(b,"Retained image preview",24,80,50,C.ink(),C.rail())
  +d : C.Canvas = C.text(c,"Synthetic native acceptance fixture",24,120,56,C.muted(),C.rail())
  +e : C.Canvas = C.text(d,"Only decoded PNG bytes are in memory.",24,176,56,C.ink(),C.rail())
  +f : C.Canvas = C.text(e,"No attachment files or URLs are read.",24,208,56,C.ink(),C.rail())
  +g : C.Canvas = C.text(f,"Fit: F    Actual pixels: 1",24,272,56,C.ink(),C.rail())
  +h : C.Canvas = C.text(g,"In 100%: arrows or wheel to pan",24,304,56,C.ink(),C.rail())
  +i : C.Canvas = C.text(h,"Back or Escape: restore exact bookmark",24,336,56,C.ink(),C.rail())
  +j : C.Canvas = C.text(i,"J: explicit unsupported JPEG state",24,368,56,C.ink(),C.rail())
  +k : C.Canvas = C.text(j,"P: reopen this synthetic retained image",24,400,56,C.ink(),C.rail())
  +l : C.Canvas = C.text(k,"Preview from verified owned bytes",536,48,80,C.ink(),C.paper())
  +m : C.Canvas = C.text(l,"1024 x 640  |  RGBA  |  nearest sampling",536,88,80,C.muted(),C.paper())
  +n : C.Canvas = C.box(C.box(C.box(m,536,128,88,32,C.panel()),632,128,72,32,C.panel()),712,128,88,32,C.panel())
  +o : C.Canvas = C.text(C.text(C.text(n,"Back",552,136,8,C.ink(),C.panel()),"Fit",648,136,6,C.ink(),C.panel()),"100%",728,136,8,C.ink(),C.panel())
  C.canvas.image(C.text(C.box(o,0,624,1200,40,C.rail()),message,16,640,146,C.ink(),C.rail()))

def return_image(bookmark: String) -> Image:
  C.canvas.image(C.text(C.text(C.Flat{C.paper()},"Returned to the exact attachment bookmark. Press P to reopen.",24,64,120,C.ink(),C.paper()),bookmark,24,112,140,C.ink(),C.paper()))

def unsupported_image(detail: String) -> Image:
  C.canvas.image(C.text(C.text(C.text(C.Flat{C.paper()},"Retained image cannot be previewed",24,64,100,C.ink(),C.paper()),detail,24,112,140,C.ink(),C.paper()),"Original retained bytes remain available to export. Escape returns.",24,160,140,C.muted(),C.paper()))

def shown(pair: P.State<String> & Image) -> Screen & Image:
  (state,image) = pair
  (Preview{state},image)

def view(screen: Screen) -> Screen & Image:
  match screen:
    case Preview{state}: shown(P.draw(String,state,chrome("Synthetic PNG: opaque red / half-alpha green / clear blue / translucent amber")))
    case Returned{+value}: (Returned{value},return_image(value))
    case Unsupported{bookmark,+detail}: (Unsupported{bookmark,detail},unsupported_image(detail))

def opened(result: Result<&2,&1,T.Failure,P.State<String>>) -> IO(Screen):
  match result:
    case Done{state}: IO.pure(Screen,Preview{state})
    case Fail{T.Failure{_,detail}}: IO.die(Screen,1,detail)

def decoded(result: Result<&2,&1,T.Failure,T.Raster>) -> IO(Screen):
  match result:
    case Done{raster}: opened(P.open(String,bookmark(),raster))
    case Fail{T.Failure{_,detail}}: IO.die(Screen,1,detail)

def initial() -> IO(Screen): decoded(Png.decode(Fixture.bytes()))

def unsupported(value: String,result: Result<&2,&1,T.Failure,T.Raster>) -> Screen:
  match result:
    case Fail{T.Failure{kind,detail}}: Unsupported{value,T.label(kind) ++ ": " ++ detail}
    case Done{_}: Unsupported{value,"Unexpected fixture decode result"}

def outcome(step: P.Step<String>) -> Maybe<Screen>:
  match step:
    case P.Kept{state}: Some{Preview{state}}
    case P.Back{value}: Some{Returned{value}}
    case P.Closed{_}: None{}

def preview_event(event: Event,state: P.State<String>) -> IO(Maybe<Screen>):
  match event:
    case Key{106,True{}}:
      P.State{value,_,_,_,_} = state
      IO.pure(Maybe<Screen>,Some{unsupported(value,Png.decode(Small.jpeg()))})
    case other: IO.pure(Maybe<Screen>,outcome(P.event(String,other,state)))

def ordinary_event(event: Event,screen: Screen,value: String) -> IO(Maybe<Screen>):
  match event:
    case Close{}: IO.pure(Maybe<Screen>,None{})
    case Key{112,True{}}:
      do IO<Maybe<Screen>>:
        current : Screen <- initial()
        return Some{current}
    case Key{27,True{}}: IO.pure(Maybe<Screen>,Some{Returned{value}})
    case _: IO.pure(Maybe<Screen>,Some{screen})

def event(event: Event,screen: Screen) -> IO(Maybe<Screen>):
  match screen:
    case Preview{state}: preview_event(event,state)
    case Returned{+value}: ordinary_event(event,Returned{value},value)
    case Unsupported{+value,detail}: ordinary_event(event,Unsupported{value,detail},value)

def events(rest: List<Event>,screen: Screen) -> IO(Maybe<Screen>):
  match rest:
    case []: IO.pure(Maybe<Screen>,Some{screen})
    case first <> tail:
      do IO<Maybe<Screen>>:
        next : Maybe<Screen> <- event(first,screen)
        App.more(Screen,s => events(tail,s),next)

def tick(rest: List<Event>,screen: Screen) -> IO(Maybe<Screen>):
  do IO<Maybe<Screen>>:
    next : Maybe<Screen> <- events(rest,screen)
    IO.sleep(80)
    return next

def main() -> IO(Unit):
  do IO<Unit>:
    screen : Screen <- initial()
    App.run(~Screen,~App{view,tick},"Juice Bend Image Preview",1200,664,screen)
