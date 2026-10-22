import Base
import ../attachment_image_types.bend as T

# RFC1951 physical bits run low to high within each octet. Ordinary fields
# accumulate LSB first; Huffman traversal consumes these same bits MSB first.
type Cursor is Data:
  Cursor{tail: List<&2,U32>,byte: U32,bits: U32}
type Read is Data:
  Read{cursor: Cursor,value: U32}

def unpack(-R: Type,value: Read,next: Cursor -> U32 -> R) -> R:
  Read{cursor,field} = value
  next(cursor,field)

def start(bytes: List<&2,U32>) -> Cursor:
  Cursor{bytes,0,0}

def aligned(cursor: Cursor) -> Cursor:
  Cursor{tail,_,_} = cursor
  Cursor{tail,0,0}

def remaining(cursor: Cursor) -> List<&2,U32>:
  Cursor{tail,_,_} = cursor
  tail

def bit(cursor: Cursor) -> Result<&2,&2,T.Failure,Read>:
  match cursor:
    case Cursor{Nil{},_,0}: Fail{T.Failure{T.CompressedData{},"Truncated DEFLATE bitstream"}}
    case Cursor{Con{+byte,tail},_,0}: Done{Read{Cursor{tail,U32.shr(byte),7},U32.and(byte,1)}}
    case Cursor{tail,+byte,bits}: Done{Read{Cursor{tail,U32.shr(byte),U32.sub(bits,1)},U32.and(byte,1)}}

def fields(fuel: Nat,cursor: Cursor,+shift: U32,value: U32) -> Result<&2,&2,T.Failure,Read>:
  match fuel:
    case 0n: Done{Read{cursor,value}}
    case 1n+rest:
      do Result<&2,&2,T.Failure,Read>:
        parsed : Read <- bit(cursor)
        unpack(Result<&2,&2,T.Failure,Read>,parsed,next => next_bit =>
          fields(rest,next,U32.inc(shift),U32.or(value,U32.shln(next_bit,U32.to_nat(shift)))))

def read(cursor: Cursor,+width: U32) -> Result<&2,&2,T.Failure,Read>:
  do Result<&2,&2,T.Failure,Read>:
    _ : Unit <- T.require(U32.is_le(width,16),T.CompressedData{},"DEFLATE field exceeds 16 bits")
    fields(U32.to_nat(width),cursor,0,0)
