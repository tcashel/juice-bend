import Base
import ../font.bend as Mono
import ../sans_font.bend as Sans
import ./canvas.bend as C
import ./region.bend as Region

# Small, bounded non-editable label rasterizer. Transcript prose uses the
# separate cached text_line component; query/code rows retain their cell map.
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
def chrome_tiles(+fuel: Nat,+c: C.Canvas,+runs: List<&2,Placed>,+column: U32,+left: U32,+top: U32,+x: U32,+y: U32,+fg: U32,+bg: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      local_runs = nearby(runs,left)
      next = C.canvas.set(8n,c,U32.add(x,column),y,C.Tile{tile(local_runs,left,top),fg,bg})
      chrome_tiles(n,next,runs,U32.add(column,1),U32.add(left,8),top,x,y,fg,bg)

def chrome_rows(+fuel: Nat,+c: C.Canvas,+runs: List<&2,Placed>,+columns: Nat,+top: U32,+x: U32,+y: U32,+fg: U32,+bg: U32) -> C.Canvas:
  match fuel:
    case 0n: c
    case 1n+n:
      next = chrome_tiles(columns,c,runs,0,0,top,x,y,fg,bg)
      chrome_rows(n,next,runs,columns,U32.add(top,8),x,U32.add(y,1),fg,bg)

def chrome_text(+c: C.Canvas,+label: String,+x: U32,+y: U32,+width: U32,+face: U32,+fg: U32,+bg: U32) -> C.Canvas:
  runs = layout(128n,face,label,0,width)
  chrome_rows(Bool.pick(Nat,U32.is_eq(face,2),4n,3n),c,runs,U32.to_nat(U32.div(width,8)),0,U32.div(x,8),U32.div(y,8),fg,bg)


# Stable public face choices. Glyphs are pinned assets; this is label layout,
# not text editing, shaping, bidi, IME or runtime font fallback.
type Face is Data:
  Regular{}
  Strong{}
  Heading{}

type Style is Data:
  Style{face: Face,foreground: U32,background: U32}

def face_index(face: Face) -> U32:
  match face:
    case Regular{}: 0
    case Strong{}: 1
    case Heading{}: 2

def height(face: Face) -> U32:
  Sans.height(face_index(face))
def baseline(face: Face) -> U32:
  Sans.baseline(face_index(face))

def draw_checked(valid: Bool,c: C.Canvas,text: String,bounds: Region.Rect,style: Style) -> Result<&2,&2,C.Failure,C.Canvas>:
  match valid:
    case False{}: Fail{C.InvalidBounds{}}
    case True{}:
      Region.Rect{+left,top,right,_} = bounds
      Style{face,fg,bg} = style
      Done{chrome_text(c,text,left,top,U32.sub(right,left),face_index(face),fg,bg)}

def height_valid(+bounds: Region.Rect,face: Face) -> Bool:
  Region.Rect{_,+top,_,bottom} = bounds
  U32.is_le(top,bottom) && U32.is_eq(U32.sub(bottom,top),height(face))

def draw(c: C.Canvas,text: String,+bounds: Region.Rect,+style: Style) -> Result<&2,&2,C.Failure,C.Canvas>:
  Style{face,_,_} = style
  draw_checked(C.bounds_valid(bounds) && height_valid(bounds,face),c,text,bounds,style)
