import Base
import ./types.bend as T

# ITU-T T.81 Annex C and F.2.2. Unconsumed bits occupy the low part of byte.
# No marker byte is consumed as entropy, and every coefficient index is checked
# before Array.set (the pinned Array implementation otherwise wraps indices).
type Cursor is Data:
  Cursor{tail: List<&2,U32>,byte: U32,bits: U32}
type Read is Data:
  Read{cursor: Cursor,value: U32}
type Decoded is Type:
  Decoded{cursor: Cursor,dc: F32,coefficients: Array<F32>}

def unpack(-R: Type,value: Read,next: Cursor -> U32 -> R) -> R:
  Read{cursor,field} = value
  next(cursor,field)

def start(bytes: List<&2,U32>) -> Cursor: Cursor{bytes,0,0}
def power(width: U32) -> U32: U32.shln(1,U32.to_nat(width))

def octet(tail: List<&2,U32>,+byte: U32) -> Result<&2,&2,T.Failure,Read>:
  do Result<&2,&2,T.Failure,Read>:
    _ : Unit <- T.require(U32.is_le(byte,255),"jpeg_entropy","Non-octet in JPEG entropy")
    Done{Read{Cursor{tail,U32.and(byte,127),7},U32.shrn(byte,7n)}}

def stuffed(tail: List<&2,U32>) -> Result<&2,&2,T.Failure,Read>:
  match tail:
    case Con{0,rest}: octet(rest,255)
    case _: Fail{T.Failure{"jpeg_entropy","JPEG data FF must be followed by stuffed zero"}}

def load(tail: List<&2,U32>) -> Result<&2,&2,T.Failure,Read>:
  match tail:
    case Nil{}: Fail{T.Failure{"jpeg_entropy","Truncated JPEG entropy"}}
    case Con{255,rest}: stuffed(rest)
    case Con{byte,rest}: octet(rest,byte)

def bit_ready(empty: Bool,tail: List<&2,U32>,+byte: U32,bits: U32) -> Result<&2,&2,T.Failure,Read>:
  match empty:
    case True{}: load(tail)
    case False{}:
      +remaining = U32.sub(bits,1)
      Done{Read{Cursor{tail,U32.and(byte,U32.sub(power(remaining),1)),remaining},U32.shrn(byte,U32.to_nat(remaining))}}

def bit(cursor: Cursor) -> Result<&2,&2,T.Failure,Read>:
  Cursor{tail,+byte,+bits} = cursor
  do Result<&2,&2,T.Failure,Read>:
    _ : Unit <- T.require(U32.is_le(bits,7) && U32.is_lt(byte,power(U32.min(bits,7))),"jpeg_entropy","Invalid JPEG bit cursor")
    bit_ready(U32.is_eq(bits,0),tail,byte,bits)

def fields(fuel: Nat,cursor: Cursor,value: U32) -> Result<&2,&2,T.Failure,Read>:
  match fuel:
    case 0n: Done{Read{cursor,value}}
    case 1n+rest:
      do Result<&2,&2,T.Failure,Read>:
        parsed : Read <- bit(cursor)
        unpack(Result<&2,&2,T.Failure,Read>,parsed,next => digit => fields(rest,next,U32.add(U32.shl(value),digit)))

def read(cursor: Cursor,+width: U32) -> Result<&2,&2,T.Failure,Read>:
  do Result<&2,&2,T.Failure,Read>:
    _ : Unit <- T.require(U32.is_le(width,11),"jpeg_entropy","JPEG magnitude exceeds baseline precision")
    fields(U32.to_nat(width),cursor,0)

def legal(kind: U32,+symbol: U32) -> Bool:
  match kind:
    case 0: U32.is_le(symbol,11)
    case 1: U32.is_le(symbol,255) && (U32.is_eq(symbol,0) || U32.is_eq(symbol,240) ||
      (U32.is_ge(U32.and(symbol,15),1) && U32.is_le(U32.and(symbol,15),10)))
    case _: False{}

def symbols(fuel: Nat,values: List<&2,U32>,+kind: U32) -> Result<&2,&2,T.Failure,Unit>:
  match fuel values:
    case 0n Nil{}: Done{Unit{}}
    case 1n+rest Con{symbol,tail}:
      do Result<&2,&2,T.Failure,Unit>:
        _ : Unit <- T.require(legal(kind,symbol),"jpeg_huffman","Invalid baseline Huffman symbol")
        symbols(rest,tail,kind)
    case _ _: Fail{T.Failure{"jpeg_huffman","Huffman symbol count differs from its sixteen counts"}}

# code is the first canonical code at this length; limit is 2^length.
# Strict inequality reserves the all-ones word, including at length sixteen.
def counts(fuel: Nat,values: List<&2,U32>,+code: U32,+limit: U32,+total: U32) -> Result<&2,&2,T.Failure,U32>:
  match fuel values:
    case 0n Nil{}:
      do Result<&2,&2,T.Failure,U32>:
        _ : Unit <- T.require(U32.is_ge(total,1) && U32.is_le(total,256),"jpeg_huffman","Empty or oversized JPEG Huffman table")
        Done{total}
    case 1n+rest Con{+count,tail}:
      do Result<&2,&2,T.Failure,U32>:
        _ : Unit <- T.require(U32.is_le(count,255) && U32.is_le(total,256) && U32.is_le(count,U32.sub(256,U32.min(total,256))) &&
          U32.is_lt(U32.add(code,count),limit),"jpeg_huffman","Oversubscribed JPEG Huffman table or forbidden all-ones code")
        counts(rest,tail,U32.shl(U32.add(code,count)),U32.shl(limit),U32.add(total,count))
    case _ _: Fail{T.Failure{"jpeg_huffman","JPEG Huffman table requires exactly sixteen counts"}}

def validate(+kind: U32,huffman: T.Huffman) -> Result<&2,&2,T.Failure,Unit>:
  T.Huffman{lengths,values} = huffman
  do Result<&2,&2,T.Failure,Unit>:
    _ : Unit <- T.require(U32.is_le(kind,1),"jpeg_huffman","Invalid JPEG Huffman class")
    count : U32 <- counts(16n,lengths,0,2,0)
    symbols(U32.to_nat(count),values,kind)

def indexed(value: Maybe<&2,U32>) -> Result<&2,&2,T.Failure,U32>:
  match value:
    case Some{value}: Done{value}
    case None{}: Fail{T.Failure{"jpeg_huffman","JPEG Huffman symbol index is outside table"}}

def lookup(values: List<&2,U32>,+index: U32) -> Result<&2,&2,T.Failure,U32>:
  do Result<&2,&2,T.Failure,U32>:
    _ : Unit <- T.require(U32.is_lt(index,256),"jpeg_huffman","JPEG symbol index exceeds bound")
    indexed(List.get(&2,U32,values,U32.to_nat(index)))

def code_result(cursor: Cursor,result: Result<&2,&2,T.Failure,U32>) -> Result<&2,&2,T.Failure,Read>:
  match result:
    case Done{value}: Done{Read{cursor,value}}
    case Fail{error}: Fail{error}

def code_choice(found: Bool,cursor: Cursor,+value: U32,+first: U32,+count: U32,+offset: U32,values: List<&2,U32>,next: Cursor -> U32 -> U32 -> U32 -> Result<&2,&2,T.Failure,Read>) -> Result<&2,&2,T.Failure,Read>:
  match found:
    case True{}: code_result(cursor,lookup(values,U32.add(offset,U32.sub(value,first))))
    case False{}: next(cursor,value,U32.shl(U32.add(first,count)),U32.add(offset,count))

def codes(fuel: Nat,lengths: List<&2,U32>,+values: List<&2,U32>,cursor: Cursor,+code: U32,+first: U32,+offset: U32) -> Result<&2,&2,T.Failure,Read>:
  match fuel lengths:
    case 1n+rest Con{+count,tail}:
      do Result<&2,&2,T.Failure,Read>:
        parsed : Read <- bit(cursor)
        unpack(Result<&2,&2,T.Failure,Read>,parsed,next => +digit =>
          code_choice(U32.is_ge(U32.add(U32.shl(code),digit),first) && U32.is_lt(U32.add(U32.shl(code),digit),U32.add(first,count)),
            next,U32.add(U32.shl(code),digit),first,count,offset,values,
            cursor => value => first => offset => codes(rest,tail,values,cursor,value,first,offset)))
    case _ _: Fail{T.Failure{"jpeg_huffman","No JPEG Huffman symbol within sixteen bits"}}

def symbol(cursor: Cursor,table: T.Huffman) -> Result<&2,&2,T.Failure,Read>:
  T.Huffman{lengths,values} = table
  codes(16n,lengths,values,cursor,0,0,0)

def extend(+value: U32,+width: U32) -> F32:
  Bool.pick(F32,U32.is_lt(value,U32.shr(power(width))),
    F32.sub(U32.to_f32(value),U32.to_f32(U32.sub(power(width),1))),U32.to_f32(value))

def zigzag(index: U32) -> Result<&2,&2,T.Failure,U32>:
  lookup([0,1,8,16,9,2,3,10,17,24,32,25,18,11,4,5,12,19,26,33,40,48,41,34,27,20,13,6,7,14,21,28,
    35,42,49,56,57,50,43,36,29,22,15,23,30,37,44,51,58,59,52,45,38,31,39,46,53,60,61,54,47,55,62,63],index)

def coefficient(cursor: Cursor,bytes: U32,+size: U32,coefficients: Array<F32>,+index: U32,next: Cursor -> Array<F32> -> U32 -> Result<&2,&1,T.Failure,Decoded>) -> Result<&2,&1,T.Failure,Decoded>:
  do Result<&2,&1,T.Failure,Decoded>:
    _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64) && U32.is_ge(size,1) && U32.is_le(size,10),"jpeg_entropy","AC coefficient exceeds baseline block"))
    +at : U32 <- T.widen(U32,zigzag(index))
    _ : Unit <- T.widen(Unit,T.require(U32.is_lt(at,64),"jpeg_entropy","AC natural index exceeds block"))
    next(cursor,Array.set(F32,coefficients,at,extend(bytes,size)),U32.inc(index))

def ac_code(+value: U32,cursor: Cursor,+dc: F32,coefficients: Array<F32>,+index: U32,next: Cursor -> Array<F32> -> U32 -> Result<&2,&1,T.Failure,Decoded>) -> Result<&2,&1,T.Failure,Decoded>:
  match value:
    case 0: Done{Decoded{cursor,dc,coefficients}}
    case 240:
      do Result<&2,&1,T.Failure,Decoded>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_le(index,48),"jpeg_entropy","JPEG zero run exceeds block"))
        next(cursor,coefficients,U32.add(index,16))
    case +value:
      +size = U32.and(value,15)
      +at = U32.add(index,U32.shrn(value,4n))
      do Result<&2,&1,T.Failure,Decoded>:
        _ : Unit <- T.widen(Unit,T.require(legal(1,value) && U32.is_lt(at,64),"jpeg_entropy","JPEG AC run exceeds block"))
        parsed : Read <- T.widen(Read,read(cursor,size))
        unpack(Result<&2,&1,T.Failure,Decoded>,parsed,cursor => bytes => coefficient(cursor,bytes,size,coefficients,at,next))

def ac_ready(done: Bool,cursor: Cursor,table: T.Huffman,+dc: F32,coefficients: Array<F32>,index: U32,next: Cursor -> Array<F32> -> U32 -> Result<&2,&1,T.Failure,Decoded>) -> Result<&2,&1,T.Failure,Decoded>:
  match done:
    case True{}: Done{Decoded{cursor,dc,coefficients}}
    case False{}:
      do Result<&2,&1,T.Failure,Decoded>:
        parsed : Read <- T.widen(Read,symbol(cursor,table))
        unpack(Result<&2,&1,T.Failure,Decoded>,parsed,cursor => value => ac_code(value,cursor,dc,coefficients,index,next))

def ac(fuel: Nat,cursor: Cursor,+table: T.Huffman,+dc: F32,coefficients: Array<F32>,+index: U32) -> Result<&2,&1,T.Failure,Decoded>:
  match fuel:
    case 0n:
      do Result<&2,&1,T.Failure,Decoded>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_eq(index,64),"jpeg_entropy","JPEG AC symbol limit exceeded"))
        Done{Decoded{cursor,dc,coefficients}}
    case 1n+rest: ac_ready(U32.is_eq(index,64),cursor,table,dc,coefficients,index,
      cursor => coefficients => index => ac(rest,cursor,table,dc,coefficients,index))

def dc_value(cursor: Cursor,bytes: U32,size: U32,table: T.Huffman,prior: F32) -> Result<&2,&1,T.Failure,Decoded>:
  +value = F32.add(prior,extend(bytes,size))
  do Result<&2,&1,T.Failure,Decoded>:
    _ : Unit <- T.widen(Unit,T.require(F32.is_ge(value,F32.neg(2048.0)) && F32.is_le(value,2047.0),"jpeg_entropy","JPEG DC predictor exceeds baseline bound"))
    ac(63n,cursor,table,value,Array.set(F32,Array.new(F32,6n,0.0),0,value),1)

def dc_code(cursor: Cursor,+size: U32,table: T.Huffman,prior: F32) -> Result<&2,&1,T.Failure,Decoded>:
  do Result<&2,&1,T.Failure,Decoded>:
    _ : Unit <- T.widen(Unit,T.require(U32.is_le(size,11),"jpeg_entropy","JPEG DC category exceeds eleven bits"))
    parsed : Read <- T.widen(Read,read(cursor,size))
    unpack(Result<&2,&1,T.Failure,Decoded>,parsed,cursor => bytes => dc_value(cursor,bytes,size,table,prior))

def block(cursor: Cursor,+dc: T.Huffman,+ac: T.Huffman,+prior: F32) -> Result<&2,&1,T.Failure,Decoded>:
  do Result<&2,&1,T.Failure,Decoded>:
    _ : Unit <- T.widen(Unit,validate(0,dc))
    _ : Unit <- T.widen(Unit,validate(1,ac))
    _ : Unit <- T.widen(Unit,T.require(F32.is_ge(prior,F32.neg(2048.0)) && F32.is_le(prior,2047.0) && F32.is_eq(prior,F32.floor(prior)),"jpeg_entropy","Invalid JPEG DC predictor"))
    parsed : Read <- T.widen(Read,symbol(cursor,dc))
    unpack(Result<&2,&1,T.Failure,Decoded>,parsed,cursor => size => dc_code(cursor,size,ac,prior))

def padding(cursor: Cursor) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  Cursor{tail,byte,+bits} = cursor
  do Result<&2,&2,T.Failure,List<&2,U32>>:
    _ : Unit <- T.require(U32.is_le(bits,7) && U32.is_eq(byte,U32.sub(power(U32.min(bits,7)),1)),"jpeg_entropy","JPEG padding bits must all be one")
    Done{tail}

def marker_fill(tail: List<&2,U32>,+code: U32,+count: U32) -> Result<&2,&2,T.Failure,Cursor>:
  match tail:
    case Nil{}: Fail{T.Failure{"jpeg_entropy","Truncated JPEG marker"}}
    case Con{255,rest}:
      do Result<&2,&2,T.Failure,Cursor>:
        _ : Unit <- T.require(U32.is_lt(count,T.max_input()),"jpeg_entropy","JPEG marker fill exceeds input bound")
        marker_fill(rest,code,U32.inc(count))
    case Con{byte,rest}:
      do Result<&2,&2,T.Failure,Cursor>:
        _ : Unit <- T.require(U32.is_eq(byte,code),"jpeg_entropy","Unexpected marker at JPEG entropy boundary")
        Done{Cursor{rest,0,0}}

def marker(tail: List<&2,U32>,code: U32) -> Result<&2,&2,T.Failure,Cursor>:
  match tail:
    case Con{255,rest}: marker_fill(rest,code,1)
    case _: Fail{T.Failure{"jpeg_entropy","JPEG entropy boundary requires marker prefix"}}

def restart(cursor: Cursor,+index: U32) -> Result<&2,&2,T.Failure,Cursor>:
  do Result<&2,&2,T.Failure,Cursor>:
    _ : Unit <- T.require(U32.is_le(index,7),"jpeg_entropy","JPEG restart index exceeds seven")
    tail : List<&2,U32> <- padding(cursor)
    marker(tail,U32.add(208,index))

def ended(cursor: Cursor) -> Result<&2,&2,T.Failure,Unit>:
  match cursor:
    case Cursor{Nil{},0,0}: Done{Unit{}}
    case _: Fail{T.Failure{"jpeg_entropy","Trailing bytes after JPEG EOI"}}

def finish(cursor: Cursor) -> Result<&2,&2,T.Failure,Unit>:
  do Result<&2,&2,T.Failure,Unit>:
    tail : List<&2,U32> <- padding(cursor)
    next : Cursor <- marker(tail,217)
    ended(next)
