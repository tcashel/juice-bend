# Synthetic native preview chrome only. Existing first-party glyph/canvas
# operations are reused; the production preview renderer accepts caller chrome.
import Base
import ../src/font.bend as Font

type Canvas is Data:
  Flat{color: U32}
  Tile{bits: Font.Half,foreground: U32,background: U32}
  Four{tl: Canvas,tr: Canvas,bl: Canvas,br: Canvas}

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

def ink() -> U32: 2434867
def muted() -> U32: 6448740
def accent() -> U32: 3762751
def paper() -> U32: 16777215
def rail() -> U32: 16054255
def panel() -> U32: 16317176
def selected_bg() -> U32: 14872027
def selection_bg() -> U32: 12444155

def glyph.put(+c: Canvas,+bits: Font.Glyph,+x: U32,+y: U32,+foreground: U32,+background: U32) -> Canvas:
  top = canvas.set(8n,c,x,y,Tile{Font.half(bits,True{}),foreground,background})
  canvas.set(8n,top,x,U32.add(y,1),Tile{Font.half(bits,False{}),foreground,background})

# Tabs occupy one existing character cell. Only their painted glyph changes;
# canonical text, scalar offsets, selection and export retain the original tab.
def display_glyph(+code: U32) -> Font.Glyph:
  match code:
    case 9: Font.glyph(8594)
    case _: Font.glyph(code)

def write(+count: Nat,+c: Canvas,text: String,+x: U32,+y: U32,+foreground: U32,+background: U32) -> Canvas:
  match count text:
    case 1n+n SCon{Chr{code},rest}:
      write(n,glyph.put(c,display_glyph(code),x,y,foreground,background),rest,U32.add(x,1),y,foreground,background)
    case _ _: c

def fill.row(+width: Nat,+c: Canvas,+x: U32,+y: U32,+color: U32) -> Canvas:
  match width:
    case 0n: c
    case 1n+n: fill.row(n,canvas.set(8n,c,x,y,Flat{color}),U32.add(x,1),y,color)

def fill(+rows: Nat,+c: Canvas,+x: U32,+y: U32,+width: Nat,+color: U32) -> Canvas:
  match rows:
    case 0n: c
    case 1n+n: fill(n,fill.row(width,c,x,y,color),x,U32.add(y,1),width,color)

def box(c: Canvas,x: U32,y: U32,width: U32,height: U32,color: U32) -> Canvas:
  fill(U32.to_nat(U32.div(height,8)),c,U32.div(x,8),U32.div(y,8),U32.to_nat(U32.div(width,8)),color)

def text(c: Canvas,label: String,x: U32,y: U32,count: U32,fg: U32,bg: U32) -> Canvas:
  write(U32.to_nat(count),c,label,U32.div(x,8),U32.div(y,8),fg,bg)

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

