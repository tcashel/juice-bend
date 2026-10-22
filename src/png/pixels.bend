import Base
import ../attachment_image_types.bend as T
import ./container.bend as C

type Row is Data:
  Row{remaining: List<&2,U32>,samples: List<&2,U32>}
type Sample is Data:
  Sample{pixel: U32,remaining: List<&2,U32>}

def widen(-A: Data,result: Result<&2,&2,T.Failure,A>) -> Result<&2,&1,T.Failure,A>:
  match result:
    case Fail{error}: Fail{error}
    case Done{value}: Done{value}

def difference(+a: U32,+b: U32) -> U32:
  U32.sub(U32.max(a,b),U32.min(a,b))

def paeth(+a: U32,+b: U32,+c: U32) -> U32:
  +pa : U32 = difference(b,c)
  +pb : U32 = difference(a,c)
  +pc : U32 = difference(U32.add(a,b),U32.mul(c,2))
  Bool.pick(U32,U32.is_le(pa,pb) && U32.is_le(pa,pc),a,Bool.pick(U32,U32.is_le(pb,pc),b,c))

def predictor(filter: U32,+a: U32,+b: U32,c: U32) -> U32:
  match filter:
    case 0: 0
    case 1: a
    case 2: b
    case 3: U32.shr(U32.add(a,b))
    case 4: paeth(a,b,c)
    case _: 0

# The two packed histories hold at most the previous four reconstructed/up
# bytes. The chosen channel count selects the byte one full pixel to the left.
def unfilter(fuel: Nat,bytes: List<&2,U32>,previous: List<&2,U32>,+filter: U32,+shift: Nat,
  +left: U32,+upper_left: U32,rev: List<&2,U32>) -> Result<&2,&2,T.Failure,Row>:
  match fuel bytes previous:
    case 0n remaining Nil{}: Done{Row{remaining,List.reverse(&2,U32,rev)}}
    case 1n+rest +byte <> remaining +up <> prior:
      do Result<&2,&2,T.Failure,Row>:
        _ : Unit <- T.require(U32.is_le(byte,255),T.CompressedData{},"PNG scanline contains a non-octet")
        +value : U32 = U32.and(U32.add(byte,predictor(filter,U32.and(U32.shrn(left,shift),255),up,U32.and(U32.shrn(upper_left,shift),255))),255)
        unfilter(rest,remaining,prior,filter,shift,U32.or(U32.shln(left,8n),value),U32.or(U32.shln(upper_left,8n),up),value <> rev)
    case _ _ _: Fail{T.Failure{T.CompressedData{},"PNG scanline extent differs from its header"}}

def transparent(key: C.Transparency,+red: U32,+green: U32,+blue: U32) -> U32:
  match key:
    case C.Opaque{}: 255
    case C.GrayKey{gray}: Bool.pick(U32,U32.is_eq(red,gray),0,255)
    case C.RGBKey{r,g,b}: Bool.pick(U32,U32.is_eq(red,r) && U32.is_eq(green,g) && U32.is_eq(blue,b),0,255)

def sample(color: U32,bytes: List<&2,U32>,key: C.Transparency) -> Result<&2,&2,T.Failure,Sample>:
  match color bytes:
    case 0 +gray <> rest: Done{Sample{T.rgba(gray,gray,gray,transparent(key,gray,gray,gray)),rest}}
    case 2 +red <> +green <> +blue <> rest: Done{Sample{T.rgba(red,green,blue,transparent(key,red,green,blue)),rest}}
    case 4 +gray <> alpha <> rest: Done{Sample{T.rgba(gray,gray,gray,alpha),rest}}
    case 6 red <> green <> blue <> alpha <> rest: Done{Sample{T.rgba(red,green,blue,alpha),rest}}
    case _ _: Fail{T.Failure{T.CompressedData{},"PNG row has an incomplete pixel"}}

def inserted(value: Sample,pixels: Array<U32>,index: U32,next: List<&2,U32> -> Array<U32> -> Result<&2,&1,T.Failure,Array<U32>>) -> Result<&2,&1,T.Failure,Array<U32>>:
  Sample{pixel,remaining} = value
  next(remaining,Array.set(U32,pixels,index,pixel))

def write_row(fuel: Nat,bytes: List<&2,U32>,pixels: Array<U32>,+index: U32,+count: U32,+capacity: U32,+color: U32,+key: C.Transparency) -> Result<&2,&1,T.Failure,Array<U32>>:
  match fuel bytes:
    case 0n Nil{}: Done{pixels}
    case 0n _: Fail{T.Failure{T.CompressedData{},"PNG row contains extra samples"}}
    case 1n+rest remaining:
      do Result<&2,&1,T.Failure,Array<U32>>:
        _ : Unit <- widen(Unit,T.require(U32.is_lt(index,count) && U32.is_lt(index,capacity),T.ResourceLimit{},"PNG pixel write exceeds allocated image"))
        value : Sample <- widen(Sample,sample(color,remaining,key))
        inserted(value,pixels,index,after => updated => write_row(rest,after,updated,U32.inc(index),count,capacity,color,key))

def advance(row: Row,pixels: Array<U32>,layout: T.Layout,color: U32,key: C.Transparency,index: U32,capacity: U32,
  next: List<&2,U32> -> List<&2,U32> -> Array<U32> -> Result<&2,&1,T.Failure,T.Raster>) -> Result<&2,&1,T.Failure,T.Raster>:
  Row{remaining,+samples} = row
  T.Layout{width,_,_,count,_,_} = layout
  do Result<&2,&1,T.Failure,T.Raster>:
    updated : Array<U32> <- write_row(U32.to_nat(width),samples,pixels,index,count,capacity,color,key)
    next(remaining,samples,updated)

def finished(bytes: List<&2,U32>,pixels: Array<U32>,layout: T.Layout,index: U32,capacity: U32,notice: Bool) -> Result<&2,&1,T.Failure,T.Raster>:
  T.Layout{width,height,_,+count,_,_} = layout
  do Result<&2,&1,T.Failure,T.Raster>:
    _ : Unit <- widen(Unit,T.require(List.is_empty(&2,U32,bytes) && U32.is_eq(index,count),T.CompressedData{},"PNG output extent differs from dimensions"))
    Done{T.Raster{width,height,count,capacity,pixels,notice}}

def rows(fuel: Nat,bytes: List<&2,U32>,previous: List<&2,U32>,pixels: Array<U32>,+layout: T.Layout,
  +color: U32,+key: C.Transparency,+index: U32,+capacity: U32,+notice: Bool) -> Result<&2,&1,T.Failure,T.Raster>:
  match fuel bytes:
    case 0n remaining: finished(remaining,pixels,layout,index,capacity,notice)
    case 1n+rest +filter <> remaining:
      T.Layout{width,_,channels,_,row_bytes,_} = layout
      do Result<&2,&1,T.Failure,T.Raster>:
        _ : Unit <- widen(Unit,T.require(U32.is_le(filter,4),T.CompressedData{},"PNG filter type is invalid"))
        row : Row <- widen(Row,unfilter(U32.to_nat(row_bytes),remaining,previous,filter,U32.to_nat(U32.mul(U32.sub(channels,1),8)),0,0,[]))
        advance(row,pixels,layout,color,key,index,capacity,after => samples => updated =>
          rows(rest,after,samples,updated,layout,color,key,U32.add(index,width),capacity,notice))
    case _ _: Fail{T.Failure{T.CompressedData{},"PNG scanline is missing"}}

def zeros(fuel: Nat) -> List<&2,U32>:
  match fuel:
    case 0n: []
    case 1n+rest: 0 <> zeros(rest)

def same_layout(a: T.Layout,b: T.Layout) -> Bool:
  T.Layout{aw,ah,ac,ap,ar,af} = a
  T.Layout{bw,bh,bc,bp,br,bf} = b
  U32.is_eq(aw,bw) && U32.is_eq(ah,bh) && U32.is_eq(ac,bc) && U32.is_eq(ap,bp) && U32.is_eq(ar,br) && U32.is_eq(af,bf)

def render_layout(+layout: T.Layout,wanted: T.Layout,bytes: List<&2,U32>,color: U32,key: C.Transparency,notice: Bool) -> Result<&2,&1,T.Failure,T.Raster>:
  T.Layout{_,height,_,count,row,_} = layout
  do Result<&2,&1,T.Failure,T.Raster>:
    _ : Unit <- widen(Unit,T.require(same_layout(layout,wanted),T.InvalidPng{},"PNG layout metadata is inconsistent"))
    rows(U32.to_nat(height),bytes,zeros(U32.to_nat(row)),Array.new(U32,T.depth(count),0),layout,color,key,0,U32.shln(1,T.depth(count)),notice)

def render(document: C.Document,bytes: List<&2,U32>) -> Result<&2,&1,T.Failure,T.Raster>:
  C.Document{C.Header{+wanted,+color},key,_,notice} = document
  T.Layout{width,height,_,_,_,_} = wanted
  do Result<&2,&1,T.Failure,T.Raster>:
    layout : T.Layout <- widen(T.Layout,T.layout(width,height,color))
    render_layout(layout,wanted,bytes,color,key,notice)
