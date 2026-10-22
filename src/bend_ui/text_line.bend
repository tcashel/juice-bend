import Base
import ../sans_font.bend as Sans
import ../font.bend as Mono
import ./canvas.bend as C
import ./label.bend as Label

# A cached scalar line, not shaped text. Ends are cumulative pixel insertion
# boundaries (one per scalar; the initial zero is implicit). Original scalars
# remain exact, including tabs and unavailable glyphs. No ellipsis is inserted.
type Scalar is Data:
  Scalar{code: U32,advance: U32}
type Line is Data:
  Line{start: U32,text: String,count: U32,ends: List<&2,U32>,width: U32}
type Failure is Data:
  InvalidWidth{}
  OffsetOverflow{}
  TooNarrow{}
  LayoutBound{}

def display_code(code: U32) -> U32:
  match code:
    case 9: 8594
    case _: code

def scalar(+code: U32) -> Scalar:
  match code:
    case 10: Scalar{10,0}
    case _: Scalar{code, Sans.advance(Sans.glyph(0,display_code(code)))}

def measure(text: String) -> List<&2,Scalar>:
  match text:
    case SNil{}: []
    case SCon{Chr{code},rest}: scalar(code) <> measure(rest)

def make.go(values: List<&2,Scalar>,+start: U32,+text: String,+count: U32,+ends: List<&2,U32>,+width: U32) -> Line:
  match values:
    case []: Line{start,String.reverse(text),count,List.reverse(&2,U32,ends),width}
    case Scalar{code,advance} <> rest:
      +edge = U32.add(width,advance)
      make.go(rest,start,SCon{Chr{code},text},U32.inc(count),edge <> ends,edge)

def make(values: List<&2,Scalar>,start: U32) -> Line:
  make.go(values,start,"",0,[],0)

def space(+code: U32) -> Bool: U32.is_eq(code,32) || U32.is_eq(code,9)

def choose(test: Bool,yes: Unit -> Result<&2,&2,Failure,List<&2,Line>>,no: Unit -> Result<&2,&2,Failure,List<&2,Line>>) -> Result<&2,&2,Failure,List<&2,Line>>:
  match test:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def overflow(acc: List<&2,Scalar>,+cut: U32,start: U32,next: List<&2,Scalar> -> Line -> Result<&2,&2,Failure,List<&2,Line>>) -> Result<&2,&2,Failure,List<&2,Line>>:
  +ordered = List.reverse(&2,Scalar,acc)
  next(List.drop(&2,Scalar,ordered,U32.to_nat(cut)))(make(List.take(&2,Scalar,ordered,U32.to_nat(cut)),start))

# Fuel permits an overflowed word to be moved once to its next row. Exhaustion
# is an explicit failure, never a partial line list. Advances are measured once
# above; wrapping, painting and hit testing consume the resulting cached map.
def wrap.go(fuel: Nat,+values: List<&2,Scalar>,+width: U32,+at: U32,+start: U32,+used: U32,+count: U32,+word: U32,+acc: List<&2,Scalar>,+done: List<&2,Line>) -> Result<&2,&2,Failure,List<&2,Line>>:
  match fuel values:
    case _ Nil{}:
      Done{List.reverse(&2,Line,Bool.pick(List<&2,Line>,U32.is_eq(count,0),done,make(List.reverse(&2,Scalar,acc),start) <> done))}
    case 0n _: Fail{LayoutBound{}}
    case 1n+n Con{Scalar{10,_},rest}:
      wrap.go(n,rest,width,U32.inc(at),U32.inc(at),0,0,0,[],make(List.reverse(&2,Scalar,acc),start) <> done)
    case 1n+ +n Con{Scalar{+code,+advance},+rest}:
      +value : Scalar = Scalar{code,advance}
      +cut = Bool.pick(U32,space(code) || U32.is_eq(word,0),count,word)
      choose(U32.is_gt(advance,width),_ => Fail{TooNarrow{}},_ =>
        choose(U32.is_gt(U32.add(used,advance),width),
          _ => overflow(acc,cut,start,remaining => row =>
            wrap.go(n,List.append(&2,Scalar,remaining,value <> rest),width,
              U32.add(start,cut),U32.add(start,cut),0,0,0,[],row <> done)),
          _ => wrap.go(n,rest,width,U32.inc(at),start,U32.add(used,advance),U32.inc(count),
            Bool.pick(U32,space(code),U32.inc(count),word),value <> acc,done)))

def wrap.checked(valid: Bool,+text: String,+start: U32,width: U32) -> Result<&2,&2,Failure,List<&2,Line>>:
  match valid:
    case False{}: Fail{OffsetOverflow{}}
    case True{}:
      wrap.go(Nat.add(4n,Nat.mul(4n,String.length(text))),measure(text),width,start,start,0,0,0,[],[])

def wrap.width(valid: Bool,+text: String,+start: U32,width: U32) -> Result<&2,&2,Failure,List<&2,Line>>:
  match valid:
    case False{}: Fail{InvalidWidth{}}
    case True{}: wrap.checked(Nat.is_le(String.length(text),U32.to_nat(U32.sub(4294967295,start))),text,start,width)

def wrap(text: String,start: U32,+width: U32) -> Result<&2,&2,Failure,List<&2,Line>>:
  wrap.width(U32.is_gt(width,0) && U32.is_le(width,C.extent()),text,start,width)

def text(line: Line) -> String:
  Line{_,value,_,_,_} = line
  value
def start(line: Line) -> U32:
  Line{value,_,_,_,_} = line
  value
def count(line: Line) -> U32:
  Line{_,_,value,_,_} = line
  value
def width(line: Line) -> U32:
  Line{_,_,_,_,value} = line
  value

def hit.choose(before: Bool,at: U32,next: Unit -> U32) -> U32:
  match before:
    case True{}: at
    case False{}: next(Unit{})

def hit.go(ends: List<&2,U32>,+x: U32,+previous: U32,+at: U32) -> U32:
  match ends:
    case []: at
    case +edge <> rest:
      hit.choose(U32.is_lt(x,U32.add(previous,U32.div(U32.inc(U32.sub(edge,previous)),2))),at,
        _ => hit.go(rest,x,edge,U32.inc(at)))

def hit(line: Line,x: U32) -> U32:
  Line{start,_,_,ends,_} = line
  U32.add(start,hit.go(ends,x,0,0))

def edge.go(ends: List<&2,U32>,offset: Nat,previous: U32) -> U32:
  match ends offset:
    case _ 0n: previous
    case Con{edge,rest} 1n+n: edge.go(rest,n,edge)
    case Nil{} _: previous

def edge(line: Line,offset: U32) -> U32:
  Line{_,_,_,ends,_} = line
  edge.go(ends,U32.to_nat(offset),0)

def runs(text: String,ends: List<&2,U32>,x: U32) -> List<&2,Label.Placed>:
  match text ends:
    case SCon{Chr{code},rest} Con{edge,tail}:
      Label.Placed{x,Sans.glyph(0,display_code(code))} <> runs(rest,tail,edge)
    case _ _: []

def minus(+a: U32,b: U32) -> U32: U32.sub(a,U32.min(a,b))

# Internal coordinates are clamped to one 8px tile. A failed checked tile
# preserves every glyph using its ordinary background; no text is dropped.
def tile_value(value: Result<&2,&2,C.Failure,C.Canvas>,bits: Mono.Half,fg: U32,bg: U32) -> C.Canvas:
  match value:
    case Done{tile}: tile
    case Fail{_}: C.Tile{bits,fg,bg}

def draw.columns(fuel: Nat,+c: C.Canvas,+placed: List<&2,Label.Placed>,+column: U32,+top: U32,+x: U32,+y: U32,+fg: U32,+bg: U32,+selected: U32,+low: U32,+high: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      +left = U32.mul(column,8)
      +bits = Label.tile(Label.nearby(placed,left),left,top)
      tile = tile_value(C.coverage_tile(bits,fg,bg,selected,U32.min(8,minus(low,left)),U32.min(8,minus(high,left))),bits,fg,bg)
      draw.columns(n,C.canvas.set(8n,c,U32.add(x,column),y,tile),placed,U32.inc(column),top,x,y,fg,bg,selected,low,high)

def draw.rows(fuel: Nat,c: C.Canvas,+placed: List<&2,Label.Placed>,+columns: Nat,+top: U32,+x: U32,+y: U32,+fg: U32,+bg: U32,+selected: U32,+low: U32,+high: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      draw.rows(n,draw.columns(columns,c,placed,0,top,x,y,fg,bg,selected,low,high),placed,columns,U32.add(top,8),x,U32.inc(y),fg,bg,selected,low,high)

# Paint an admitted cached line in an aligned 24px reader row. The app owns
# viewport clipping. Neither this path nor pointer handling measures text.
def draw(c: C.Canvas,+line: Line,x: U32,y: U32,columns: U32,fg: U32,bg: U32,selected: U32,low: U32,high: U32) -> C.Canvas:
  Line{+start,text,_,ends,_} = line
  draw.rows(3n,c,runs(text,ends,0),U32.to_nat(columns),0,U32.div(x,8),U32.div(y,8),fg,bg,selected,
    edge(line,minus(low,start)),edge(line,minus(high,start)))
