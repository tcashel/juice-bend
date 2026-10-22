import Base
import ./canvas.bend as C
import ./label.bend as Label
import ./region.bend as Region

# A non-editable metric display. The caller owns values, meaning and actions.
# Labels may ellipsize; this component never changes the underlying strings.
type Model is Data:
  Model{label: String,value: String,detail: String}

type Style is Data:
  Style{foreground: U32,secondary: U32,background: U32}

def value_face(text: String,+width: U32) -> Label.Face:
  Bool.pick(Label.Face,U32.is_le(Label.measured(128n,2,text,0,width),width),Label.Heading{},Label.Strong{})

def valid(+bounds: Region.Rect) -> Bool:
  Region.Rect{+left,+top,+right,+bottom} = bounds
  C.bounds_valid(bounds) && U32.is_ge(right,left) &&
    U32.is_ge(U32.sub(right,left),32) && U32.is_eq(U32.sub(bottom,top),96)

def draw_valid(valid: Bool,c: C.Canvas,model: Model,+bounds: Region.Rect,style: Style) -> Result<&2,&2,C.Failure,C.Canvas>:
  match valid:
    case False{}: Fail{C.InvalidBounds{}}
    case True{}:
      Model{label,+value,detail} = model
      Region.Rect{left,+top,right,_} = bounds
      Style{fg,+secondary,+bg} = style
      +start = U32.add(left,8)
      +end = U32.sub(right,8)
      +face = value_face(value,U32.sub(end,start))
      do Result<&2,&2,C.Failure,C.Canvas>:
        filled : C.Canvas <- C.fill_rect(c,bounds,bg)
        named : C.Canvas <- Label.draw(filled,label,Region.Rect{start,U32.add(top,8),end,U32.add(top,32)},Label.Style{Label.Regular{},secondary,bg})
        amount : C.Canvas <- Label.draw(named,value,Region.Rect{start,U32.add(top,32),end,U32.add(U32.add(top,32),Label.height(face))},Label.Style{face,fg,bg})
        Label.draw(amount,detail,Region.Rect{start,U32.add(top,64),end,U32.add(top,88)},Label.Style{Label.Regular{},secondary,bg})

def draw(c: C.Canvas,model: Model,+bounds: Region.Rect,style: Style) -> Result<&2,&2,C.Failure,C.Canvas>:
  draw_valid(valid(bounds),c,model,bounds,style)
