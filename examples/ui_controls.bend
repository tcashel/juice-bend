# Standalone native Bend example: no Juice coordinator, data, provider or process.
import Base
import ../src/bend_ui/canvas.bend as C
import ../src/bend_ui/label.bend as L
import ../src/bend_ui/region.bend as R

type Model is Data:
  Model{focus: Maybe<&2,U32>,selected: U32,shift: Bool}
type State is Data:
  State{model: Model,image: Image}

def regions() -> List<&2,R.ControlRegion>:
  [R.ControlRegion{10,R.Rect{24,96,168,136},True{},True{}},
   R.ControlRegion{20,R.Rect{184,96,328,136},True{},True{}},
   R.ControlRegion{30,R.Rect{344,96,488,136},False{},True{}}]

def accepted(result: Result<&2,&2,C.Failure,C.Canvas>) -> C.Canvas:
  match result:
    case Done{canvas}: canvas
    # A fixed example geometry error is conspicuous and tested, not hidden.
    case Fail{_}: C.Flat{16711680}

def label(canvas: C.Canvas,text: String,bounds: R.Rect,face: L.Face,fg: U32,bg: U32) -> C.Canvas:
  accepted(L.draw(canvas,text,bounds,L.Style{face,fg,bg}))
def focused(current: Maybe<&2,U32>,id: U32) -> Bool:
  match current:
    case Some{value}: U32.is_eq(value,id)
    case None{}: False{}

def button(+c: C.Canvas,+focus: Maybe<&2,U32>,+id: U32,+left: U32,text: String,+enabled: Bool) -> C.Canvas:
  +bg = Bool.pick(U32,enabled,15395035,14737632)
  +fg = Bool.pick(U32,enabled,2111513,8421504)
  +border = Bool.pick(U32,focused(focus,id),2502743,bg)
  outline = accepted(C.fill_rect(c,R.Rect{left,96,U32.add(left,144),136},border))
  body = accepted(C.fill_rect(outline,R.Rect{U32.add(left,8),104,U32.add(left,136),128},bg))
  label(body,text,R.Rect{U32.add(left,16),104,U32.add(left,128),128},L.Strong{},fg,bg)

def selected_text(id: U32) -> String:
  match id:
    case 10: "Selected: Apricot"
    case 20: "Selected: Meadow"
    case _: "Choose a control"

def paint(+model: Model) -> C.Canvas:
  Model{+focus,selected,_} = model
  a = label(C.Flat{16316144},"Bend UI controls",R.Rect{24,24,488,56},L.Heading{},2111513,16316144)
  b = label(a,"Click or Tab; Enter activates. Shift-Tab goes back.",R.Rect{24,64,488,88},L.Regular{},4210752,16316144)
  c = button(b,focus,10,24,"Apricot",True{})
  d = button(c,focus,20,184,"Meadow",True{})
  e = button(d,focus,30,344,"Disabled",False{})
  label(e,selected_text(selected),R.Rect{24,160,488,184},L.Regular{},2111513,16316144)

def accepted_image(result: Result<&2,&2,C.Failure,Image>) -> Image:
  match result:
    case Done{image}: image
    case Fail{_}: Pix{16711680}

def frame(model: Model) -> Image:
  accepted_image(C.image_viewport(paint(model),512,216))

def click(model: Model,hit: Maybe<&2,U32>) -> Model:
  match model hit:
    case Model{focus,selected,shift} None{}: Model{focus,selected,shift}
    case Model{_,_,shift} Some{+id}: Model{Some{id},id,shift}
def activate(model: Model) -> Model:
  Model{+focus,selected,shift} = model
  Model{focus,Bool.pick(U32,focused(focus,10),10,Bool.pick(U32,focused(focus,20),20,selected)),shift}
def shift(model: Model,down: Bool) -> Model:
  Model{focus,selected,_} = model
  Model{focus,selected,down}
def tab(model: Model) -> Model:
  Model{focus,selected,+backward} = model
  Model{R.next_focus(3n,regions(),focus,backward),selected,backward}
def backtab(model: Model) -> Model:
  Model{focus,selected,shift} = model
  Model{R.next_focus(3n,regions(),focus,True{}),selected,shift}
def step(event: Event,+model: Model) -> Maybe<Model>:
  match event:
    case Close{}: None{}
    case Key{27,True{}}: None{}
    # Pinned Base maps native left/right Shift to these modifier key codes.
    case Key{65592,down}: Some{shift(model,down)}
    case Key{65596,down}: Some{shift(model,down)}
    case Key{9,True{}}: Some{tab(model)}
    # Base also preserves the native back-tab character (25).
    case Key{25,True{}}: Some{backtab(model)}
    case Key{13,True{}}: Some{activate(model)}
    case Key{32,True{}}: Some{activate(model)}
    case Mouse{x,y,0,True{}}: Some{click(model,R.hit(3n,regions(),x,y))}
    case _: Some{model}

def events(es: List<Event>,model: Maybe<Model>) -> Maybe<Model>:
  match es model:
    case _ None{}: None{}
    case Nil{} Some{value}: Some{value}
    case event <> rest Some{value}: events(rest,step(event,value))
def view(state: State) -> State & Image:
  State{model,+image} = state
  (State{model,image},image)
def same_focus(a: Maybe<&2,U32>,b: Maybe<&2,U32>) -> Bool:
  match a b:
    case None{} None{}: True{}
    case Some{x} Some{y}: U32.is_eq(x,y)
    case _ _: False{}
def same_model(a: Model,b: Model) -> Bool:
  Model{af,aselected,ax} = a
  Model{bf,bs,bx} = b
  same_focus(af,bf) && U32.is_eq(aselected,bs) && U32.is_eq(Bool.to_u32(ax),Bool.to_u32(bx))
def cached(changed: Bool,state: State,+model: Model) -> State:
  match changed:
    case False{}: state
    case True{}: State{model,frame(model)}
def updated(+state: State,model: Maybe<Model>) -> IO(Maybe<State>):
  match state model:
    case _ None{}: IO.pure(Maybe<State>,None{})
    case State{old,_} Some{+next}:
      do IO<Maybe<State>>:
        IO.sleep(16)
        return Some{cached(Bool.not(same_model(old,next)),state,next)}
def tick(input: List<Event>,state: State) -> IO(Maybe<State>):
  State{+model,image} = state
  updated(State{model,image},events(input,Some{model}))
def initial() -> Model: Model{None{},0,False{}}
def main() -> IO(Unit):
  +model = initial()
  App.run(~State,~App{view,tick},"Bend UI components",512,216,State{model,frame(model)})
