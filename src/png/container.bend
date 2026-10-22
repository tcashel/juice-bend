import Base
import ../attachment_image_types.bend as T
import ./checksum.bend as Checksum

type Cursor is Data:
  Cursor{tail: List<&2,U32>,remaining: U32}
type Part is Data:
  Part{bytes: List<&2,U32>,after: Cursor}
type Number is Data:
  Number{value: U32,after: Cursor}
type Chunk is Data:
  Chunk{kind: U32,ancillary: Bool,bytes: List<&2,U32>,after: Cursor}
type Transparency is Data:
  Opaque{}
  GrayKey{gray: U32}
  RGBKey{red: U32,green: U32,blue: U32}
type Header is Data:
  Header{layout: T.Layout,color: U32}
type State is Data:
  State{header: Header,key: Transparency,seen_transparency: Bool,seen_palette: Bool,
    phase: U32,compressed_rev: List<&2,List<&2,U32>>,compressed_count: U32,color_notice: Bool}
type Document is Data:
  Document{header: Header,key: Transparency,compressed: List<&2,U32>,color_notice: Bool}

def admitted(bytes: List<&2,U32>,+count: U32) -> Result<&2,&2,T.Failure,U32>:
  match bytes:
    case []: Done{count}
    case +byte <> rest:
      do Result<&2,&2,T.Failure,U32>:
        _ : Unit <- T.require(U32.is_le(byte,255),T.InvalidInput{},"Image input contains a non-octet")
        _ : Unit <- T.require(U32.is_lt(count,T.max_input()),T.ResourceLimit{},"Retained image exceeds the compressed byte limit")
        admitted(rest,U32.inc(count))

def take(fuel: Nat,cursor: Cursor,rev: List<&2,U32>) -> Result<&2,&2,T.Failure,Part>:
  match fuel cursor:
    case 0n after: Done{Part{List.reverse(&2,U32,rev),after}}
    case 1n+_ Cursor{Nil{},_}: Fail{T.Failure{T.InvalidPng{},"PNG chunk is truncated"}}
    case 1n+rest Cursor{byte <> tail,+remaining}:
      do Result<&2,&2,T.Failure,Part>:
        _ : Unit <- T.require(U32.is_gt(remaining,0),T.InvalidPng{},"PNG cursor extent disagrees")
        take(rest,Cursor{tail,U32.sub(remaining,1)},byte <> rev)

def number(part: Part) -> Result<&2,&2,T.Failure,Number>:
  match part:
    case Part{[a,b,c,d],after}:
      Done{Number{U32.or(U32.shln(a,24n),U32.or(U32.shln(b,16n),U32.or(U32.shln(c,8n),d))),after}}
    case _: Fail{T.Failure{T.InvalidPng{},"PNG integer is truncated"}}

def read32(cursor: Cursor) -> Result<&2,&2,T.Failure,Number>:
  do Result<&2,&2,T.Failure,Number>:
    part : Part <- take(4n,cursor,[])
    number(part)

def alphabetic(+byte: U32) -> Bool:
  (U32.is_ge(byte,65) && U32.is_le(byte,90)) || (U32.is_ge(byte,97) && U32.is_le(byte,122))

def type_valid(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case [a,b,+c,d]: alphabetic(a) && alphabetic(b) && alphabetic(c) && alphabetic(d) && U32.is_eq(U32.and(c,32),0)
    case _: False{}

def is_ancillary(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case first <> _: U32.is_ne(U32.and(first,32),0)
    case []: False{}

def chunk_checked(check: Number,kind: U32,ancillary: Bool,+data: List<&2,U32>,type_bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Chunk>:
  Number{expected,after} = check
  do Result<&2,&2,T.Failure,Chunk>:
    _ : Unit <- T.require(U32.is_eq(expected,Checksum.crc(List.append(&2,U32,type_bytes,data))),T.InvalidPng{},"PNG chunk CRC mismatch")
    Done{Chunk{kind,ancillary,data,after}}

def chunk_data(part: Part,kind: U32,ancillary: Bool,type_bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Chunk>:
  Part{data,after} = part
  do Result<&2,&2,T.Failure,Chunk>:
    check : Number <- read32(after)
    chunk_checked(check,kind,ancillary,data,type_bytes)

def chunk_type_value(value: Number,+length: U32,+type_bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Chunk>:
  Number{kind,+cursor} = value
  Cursor{_,remaining} = cursor
  do Result<&2,&2,T.Failure,Chunk>:
    _ : Unit <- T.require(type_valid(type_bytes),T.InvalidPng{},"PNG chunk type is invalid")
    _ : Unit <- T.require(U32.is_le(length,2147483647) && U32.is_ge(remaining,4) && U32.is_le(length,U32.sub(remaining,U32.min(remaining,4))),T.InvalidPng{},"PNG chunk length exceeds retained input")
    part : Part <- take(U32.to_nat(length),cursor,[])
    chunk_data(part,kind,is_ancillary(type_bytes),type_bytes)

def chunk_type(part: Part,length: U32) -> Result<&2,&2,T.Failure,Chunk>:
  Part{+type_bytes,after} = part
  do Result<&2,&2,T.Failure,Chunk>:
    value : Number <- number(Part{type_bytes,after})
    chunk_type_value(value,length,type_bytes)

def chunk_length(value: Number) -> Result<&2,&2,T.Failure,Chunk>:
  Number{length,after} = value
  do Result<&2,&2,T.Failure,Chunk>:
    part : Part <- take(4n,after,[])
    chunk_type(part,length)

def chunk(cursor: Cursor) -> Result<&2,&2,T.Failure,Chunk>:
  do Result<&2,&2,T.Failure,Chunk>:
    length : Number <- read32(cursor)
    chunk_length(length)

def packed(a: U32,b: U32,c: U32,d: U32) -> U32:
  U32.or(U32.shln(a,24n),U32.or(U32.shln(b,16n),U32.or(U32.shln(c,8n),d)))

def header_fields(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Header>:
  match bytes:
    case [a,b,c,d,e,f,g,h,depth,+color,compression,filter,+interlace]:
      do Result<&2,&2,T.Failure,Header>:
        _ : Unit <- T.require(U32.is_eq(depth,8),T.UnsupportedColor{},"Only eight-bit PNG samples are currently displayed")
        _ : Unit <- T.require(U32.is_eq(compression,0) && U32.is_eq(filter,0),T.InvalidPng{},"PNG compression or filter method is unknown")
        _ : Unit <- T.require(U32.is_le(interlace,1),T.InvalidPng{},"PNG interlace method is invalid")
        _ : Unit <- T.require(U32.is_eq(interlace,0),T.UnsupportedInterlace{},"Adam7 PNG display is not yet implemented")
        layout : T.Layout <- T.layout(packed(a,b,c,d),packed(e,f,g,h),color)
        Done{Header{layout,color}}
    case _: Fail{T.Failure{T.InvalidPng{},"PNG IHDR must have exactly thirteen bytes"}}

def flatten(parts: List<&2,List<&2,U32>>) -> List<&2,U32>:
  match parts:
    case []: []
    case first <> rest: List.append(&2,U32,first,flatten(rest))

def finish(state: State,bytes: List<&2,U32>,cursor: Cursor) -> Result<&2,&2,T.Failure,Document>:
  State{header,key,_,_,phase,rev,count,notice} = state
  Cursor{remaining,left} = cursor
  do Result<&2,&2,T.Failure,Document>:
    _ : Unit <- T.require(List.is_empty(&2,U32,bytes) && List.is_empty(&2,U32,remaining) && U32.is_eq(left,0),T.InvalidPng{},"PNG IEND must be empty and terminal")
    _ : Unit <- T.require(U32.is_gt(phase,0) && U32.is_gt(count,0),T.InvalidPng{},"PNG image data is missing")
    Done{Document{header,key,flatten(List.reverse(&2,List<&2,U32>,rev)),notice}}

def transparency(bytes: List<&2,U32>,color: U32) -> Result<&2,&2,T.Failure,Transparency>:
  match bytes color:
    case [0,gray] 0: Done{GrayKey{gray}}
    case [0,red,0,green,0,blue] 2: Done{RGBKey{red,green,blue}}
    case _ _: Fail{T.Failure{T.InvalidPng{},"PNG transparency key is invalid for the sample type"}}

def after_transparency(key: Transparency,state: State,cursor: Cursor,next: Cursor -> State -> Result<&2,&2,T.Failure,Document>) -> Result<&2,&2,T.Failure,Document>:
  State{header,_,_,palette,phase,parts,count,notice} = state
  next(cursor,State{header,key,True{},palette,phase,parts,count,notice})

def transparency_chunk(+state: State,bytes: List<&2,U32>,cursor: Cursor,next: Cursor -> State -> Result<&2,&2,T.Failure,Document>) -> Result<&2,&2,T.Failure,Document>:
  State{Header{_,color},_,seen,_,phase,_,_,_} = state
  do Result<&2,&2,T.Failure,Document>:
    _ : Unit <- T.require(Bool.not(seen) && U32.is_eq(phase,0),T.InvalidPng{},"PNG transparency must occur once before image data")
    key : Transparency <- transparency(bytes,color)
    after_transparency(key,state,cursor,next)

def palette_chunk(state: State,bytes: List<&2,U32>,cursor: Cursor,next: Cursor -> State -> Result<&2,&2,T.Failure,Document>) -> Result<&2,&2,T.Failure,Document>:
  State{+header,key,+seen_transparency,seen_palette,+phase,parts,count,notice} = state
  Header{_,+color} = header
  +size : U32 = U32.from_nat(List.length(&2,U32,bytes))
  do Result<&2,&2,T.Failure,Document>:
    _ : Unit <- T.require(Bool.not(seen_palette) && Bool.not(seen_transparency) && U32.is_eq(phase,0) && (U32.is_eq(color,2) || U32.is_eq(color,6)),T.InvalidPng{},"PNG palette is duplicated or invalid for this position or color type")
    _ : Unit <- T.require(U32.is_gt(size,0) && U32.is_le(size,768) && U32.is_eq(U32.mod(size,3),0),T.InvalidPng{},"PNG palette length is invalid")
    next(cursor,State{header,key,seen_transparency,True{},phase,parts,count,notice})

def image_data(state: State,+bytes: List<&2,U32>,cursor: Cursor,next: Cursor -> State -> Result<&2,&2,T.Failure,Document>) -> Result<&2,&2,T.Failure,Document>:
  State{header,key,transparency,palette,phase,parts,+count,notice} = state
  +size : U32 = U32.from_nat(List.length(&2,U32,bytes))
  do Result<&2,&2,T.Failure,Document>:
    _ : Unit <- T.require(U32.is_lt(phase,2),T.InvalidPng{},"PNG IDAT chunks must be consecutive")
    _ : Unit <- T.require(U32.is_le(size,U32.sub(T.max_input(),count)),T.ResourceLimit{},"PNG image data exceeds compressed bound")
    next(cursor,State{header,key,transparency,palette,1,bytes <> parts,U32.add(count,size),notice})

def color_metadata(+kind: U32) -> Bool:
  U32.is_eq(kind,1732332865) || U32.is_eq(kind,1665684045) || U32.is_eq(kind,1766015824) ||
    U32.is_eq(kind,1934772034) || U32.is_eq(kind,1665745744) || U32.is_eq(kind,1833190230) || U32.is_eq(kind,1665944649)

def other_chunk(state: State,kind: U32,ancillary: Bool,cursor: Cursor,next: Cursor -> State -> Result<&2,&2,T.Failure,Document>) -> Result<&2,&2,T.Failure,Document>:
  State{header,key,transparency,palette,+phase,parts,count,notice} = state
  do Result<&2,&2,T.Failure,Document>:
    _ : Unit <- T.require(ancillary,T.UnsupportedFormat{},"PNG contains an unsupported critical chunk")
    next(cursor,State{header,key,transparency,palette,Bool.pick(U32,U32.is_eq(phase,1),2,phase),parts,count,notice || color_metadata(kind)})

def dispatch(value: Chunk,state: State,next: Cursor -> State -> Result<&2,&2,T.Failure,Document>) -> Result<&2,&2,T.Failure,Document>:
  match value:
    case Chunk{1229472850,_,_,_}: Fail{T.Failure{T.InvalidPng{},"PNG contains a second IHDR"}}
    case Chunk{1229209940,_,data,cursor}: image_data(state,data,cursor,next)
    case Chunk{1229278788,_,data,cursor}: finish(state,data,cursor)
    case Chunk{1347179589,_,data,cursor}: palette_chunk(state,data,cursor,next)
    case Chunk{1951551059,_,data,cursor}: transparency_chunk(state,data,cursor,next)
    case Chunk{1633899596,_,_,_}: Fail{T.Failure{T.UnsupportedAnimation{},"Animated PNG display is not yet implemented"}}
    case Chunk{1717785676,_,_,_}: Fail{T.Failure{T.UnsupportedAnimation{},"Animated PNG display is not yet implemented"}}
    case Chunk{1717846356,_,_,_}: Fail{T.Failure{T.UnsupportedAnimation{},"Animated PNG display is not yet implemented"}}
    case Chunk{kind,ancillary,_,cursor}: other_chunk(state,kind,ancillary,cursor,next)

def walk(fuel: Nat,cursor: Cursor,state: State) -> Result<&2,&2,T.Failure,Document>:
  match fuel:
    case 0n: Fail{T.Failure{T.ResourceLimit{},"PNG chunk count exceeds the display profile"}}
    case 1n+rest:
      do Result<&2,&2,T.Failure,Document>:
        value : Chunk <- chunk(cursor)
        dispatch(value,state,after => current => walk(rest,after,current))

def first(value: Chunk) -> Result<&2,&2,T.Failure,Document>:
  match value:
    case Chunk{1229472850,_,bytes,after}:
      do Result<&2,&2,T.Failure,Document>:
        header : Header <- header_fields(bytes)
        walk(U32.to_nat(U32.sub(T.max_chunks(),1)),after,State{header,Opaque{},False{},False{},0,[],0,False{}})
    case _: Fail{T.Failure{T.InvalidPng{},"PNG IHDR must be the first chunk"}}

def signature(part: Part) -> Result<&2,&2,T.Failure,Document>:
  match part:
    case Part{[137,80,78,71,13,10,26,10],after}:
      do Result<&2,&2,T.Failure,Document>:
        value : Chunk <- chunk(after)
        first(value)
    case _: Fail{T.Failure{T.UnsupportedFormat{},"Only PNG image display is currently implemented; JPEG remains unavailable"}}

def decode(+bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Document>:
  do Result<&2,&2,T.Failure,Document>:
    count : U32 <- admitted(bytes,0)
    part : Part <- take(8n,Cursor{bytes,count},[])
    signature(part)
