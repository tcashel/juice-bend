import Base
import ./font.bend as Mono
import ./sans_font.bend as Sans

# Small, bounded label rasterizer. Only non-editable application chrome uses
# proportional advances. Transcript/query text keeps its canonical cell map.
type Placed is Data:
  Placed{x: U32,glyph: Sans.Glyph}

def width(+glyph: Sans.Glyph) -> U32:
  Sans.advance(glyph)

def remaining(+space: U32,+used: U32) -> U32:
  Bool.pick(U32,U32.is_gt(space,used),U32.sub(space,used),0)

def measured(+fuel: Nat,+face: U32,+text: String,+used: U32,+limit: U32) -> U32:
  match fuel text:
    case _ SNil{}: used
    case 0n _: U32.add(limit,1)
    case 1n+n SCon{Chr{code},rest}:
      +next = U32.add(used,width(Sans.glyph(face,code)))
      Bool.pick(U32,U32.is_gt(next,limit),next,measured(n,face,rest,next,limit))

def layout_step(+x: U32,+limit: U32,glyph: Sans.Glyph,+face: U32,full: Bool,next: Unit -> List<&2,Placed>) -> List<&2,Placed>:
  match full:
    case True{}:
      +ellipsis = Sans.glyph(face,8230)
      Bool.pick(List<&2,Placed>,U32.is_le(width(ellipsis),remaining(limit,x)),[Placed{x,ellipsis}],[])
    case False{}:
      Placed{x,glyph} <> next(Unit{})

def positions(+fuel: Nat,+face: U32,+text: String,+x: U32,+limit: U32,+crop: Bool) -> List<&2,Placed>:
  match fuel text:
    case 1n+n SCon{Chr{code},rest}:
      +glyph = Sans.glyph(face,code)
      +ellipsis = Sans.glyph(face,8230)
      layout_step(x,limit,glyph,face,
        U32.is_gt(width(glyph),remaining(limit,x)) ||
        (crop && Bool.not(String.is_empty(rest)) && U32.is_gt(U32.add(width(glyph),width(ellipsis)),remaining(limit,x))),
        _ => positions(n,face,rest,U32.add(x,width(glyph)),limit,crop))
    case _ _: []

def layout(+fuel: Nat,+face: U32,+text: String,+x: U32,+limit: U32) -> List<&2,Placed>:
  positions(fuel,face,text,x,limit,U32.is_gt(measured(fuel,face,text,x,limit),limit))

def overlaps(+run: Placed,+left: U32) -> Bool:
  Placed{+x,glyph} = run
  U32.is_lt(x,U32.add(left,8)) && U32.is_gt(U32.add(x,width(glyph)),left)

def nearby_step(run: Placed,rest: List<&2,Placed>,keep: Bool) -> List<&2,Placed>:
  match keep:
    case True{}: run <> rest
    case False{}: rest

def nearby(+runs: List<&2,Placed>,+left: U32) -> List<&2,Placed>:
  match runs:
    case []: []
    case +run <> rest:
      nearby_step(run,nearby(rest,left),overlaps(run,left))

def slice(+glyph: Sans.Glyph,+offset: U32,+y: U32) -> U32:
  +word = U32.div(offset,8)
  +shift = U32.mod(offset,8)
  U32.or(U32.shrn(Sans.row_word(glyph,word,y),U32.to_nat(U32.mul(shift,4))),
    Bool.pick(U32,U32.is_eq(shift,0),0,U32.shln(Sans.row_word(glyph,U32.add(word,1),y),U32.to_nat(U32.mul(U32.sub(8,shift),4)))))

def piece_at(+glyph: Sans.Glyph,+x: U32,+left: U32,+y: U32,+after: Bool) -> U32:
  match after:
    case True{}: U32.shln(Sans.row_word(glyph,0,y),U32.to_nat(U32.mul(U32.sub(x,left),4)))
    case False{}: slice(glyph,U32.sub(left,x),y)

def piece(+run: Placed,+left: U32,+y: U32) -> U32:
  Placed{+x,glyph} = run
  piece_at(glyph,x,left,y,U32.is_ge(x,left))

def row(+runs: List<&2,Placed>,+left: U32,+y: U32) -> U32:
  match runs:
    case []: 0
    case run <> rest: U32.or(piece(run,left,y),row(rest,left,y))

def tile(+runs: List<&2,Placed>,+left: U32,+top: U32) -> Mono.Half:
  Mono.Half{row(runs,left,top),row(runs,left,U32.add(top,1)),row(runs,left,U32.add(top,2)),row(runs,left,U32.add(top,3)),
    row(runs,left,U32.add(top,4)),row(runs,left,U32.add(top,5)),row(runs,left,U32.add(top,6)),row(runs,left,U32.add(top,7))}
