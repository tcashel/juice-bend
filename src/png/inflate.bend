import Base
import ../attachment_image_types.bend as T
import ./checksum.bend as Checksum
import ./inflate_bits.bend as Bits
import ./inflate_huffman.bend as H
import ./inflate_tables.bend as Tables
import ./inflate_output.bend as Output

# RFC1950/1951 decoder for retained PNG bytes. No file/network/native effects.
# Resource admission precedes the array allocation and compressed parsing.
type State is Type:
  State{cursor: Bits.Cursor,sink: Output.Sink}
type Match is Data:
  Match{cursor: Bits.Cursor,length: U32,distance: U32}

def unpack_match(-R: Type,value: Match,next: Bits.Cursor -> U32 -> U32 -> R) -> R:
  Match{cursor,length,distance} = value
  next(cursor,length,distance)

def admit(bytes: List<&2,U32>,+count: U32) -> Result<&2,&2,T.Failure,Unit>:
  match bytes:
    case Nil{}: Done{Unit{}}
    case Con{byte,tail}:
      do Result<&2,&2,T.Failure,Unit>:
        _ : Unit <- T.require(U32.is_lt(count,T.max_input()),T.ResourceLimit{},"Compressed PNG exceeds input limit")
        _ : Unit <- T.require(U32.is_le(byte,255),T.InvalidInput{},"Compressed PNG contains a non-octet")
        admit(tail,U32.inc(count))

def length_base() -> List<&2,U32>:
  [3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227,258]

def length_extra() -> List<&2,U32>:
  [0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0]

def distance_extra(+symbol: U32) -> U32:
  Bool.pick(U32,U32.is_lt(symbol,4),0,U32.sub(U32.div(U32.max(symbol,4),2),1))

def distance_base(+symbol: U32,+extra: U32) -> U32:
  Bool.pick(U32,U32.is_lt(symbol,4),U32.inc(symbol),U32.inc(U32.shln(U32.add(2,U32.and(symbol,1)),U32.to_nat(extra))))

def match_code(cursor: Bits.Cursor,+symbol: U32,distance_tree: H.Tree) -> Result<&2,&2,T.Failure,Match>:
  do Result<&2,&2,T.Failure,Match>:
    _ : Unit <- T.require(U32.is_ge(symbol,257) && U32.is_le(symbol,285),T.CompressedData{},"Reserved DEFLATE literal/length code")
    +index : Nat = U32.to_nat(U32.sub(symbol,257))
    +base : U32 = Tables.at(length_base(),index)
    p1 : Bits.Read <- Bits.read(cursor,Tables.at(length_extra(),index))
    Bits.unpack(Result<&2,&2,T.Failure,Match>,p1,c1 => extra =>
      do Result<&2,&2,T.Failure,Match>:
        length : U32 = U32.add(base,extra)
        p2 : Bits.Read <- H.symbol(15n,distance_tree,c1)
        Bits.unpack(Result<&2,&2,T.Failure,Match>,p2,c2 => decoded_distance =>
          do Result<&2,&2,T.Failure,Match>:
            +distance_symbol : U32 = decoded_distance
            _ : Unit <- T.require(U32.is_le(distance_symbol,29),T.CompressedData{},"Reserved DEFLATE distance code")
            +width : U32 = distance_extra(distance_symbol)
            p3 : Bits.Read <- Bits.read(c2,width)
            Bits.unpack(Result<&2,&2,T.Failure,Match>,p3,c3 => value =>
              Done{Match{c3,length,U32.add(distance_base(distance_symbol,width),value)}})))

# Match heads remain at definition scope for the pinned Bend parser. The
# continuation is affine and invokes the caller's decreasing symbol budget.
def data_symbol(is_literal: Bool,cursor: Bits.Cursor,sink: Output.Sink,value: U32,distance: H.Tree,
  next: Bits.Cursor -> Output.Sink -> Result<&2,&1,T.Failure,State>) -> Result<&2,&1,T.Failure,State>:
  match is_literal:
    case True{}:
      do Result<&2,&1,T.Failure,State>:
        written : Output.Sink <- Output.put(sink,value)
        next(cursor,written)
    case False{}:
      do Result<&2,&1,T.Failure,State>:
        matched : Match <- Output.widen(Match,match_code(cursor,value,distance))
        unpack_match(Result<&2,&1,T.Failure,State>,matched,after => length => offset =>
          do Result<&2,&1,T.Failure,State>:
            written : Output.Sink <- Output.copy(sink,offset,length)
            next(after,written))

def token(symbol: U32,cursor: Bits.Cursor,sink: Output.Sink,distance: H.Tree,
  next: Bits.Cursor -> Output.Sink -> Result<&2,&1,T.Failure,State>) -> Result<&2,&1,T.Failure,State>:
  match symbol:
    case 256: Done{State{cursor,sink}}
    case +value: data_symbol(U32.is_lt(value,256),cursor,sink,value,distance,next)

def compressed(fuel: Nat,+literal: H.Tree,+distance: H.Tree,cursor: Bits.Cursor,sink: Output.Sink) -> Result<&2,&1,T.Failure,State>:
  match fuel:
    case 0n: Fail{T.Failure{T.CompressedData{},"DEFLATE block has no bounded end-of-block code"}}
    case 1n+rest:
      do Result<&2,&1,T.Failure,State>:
        decoded : Bits.Read <- Output.widen(Bits.Read,H.symbol(15n,literal,cursor))
        Bits.unpack(Result<&2,&1,T.Failure,State>,decoded,next_cursor => symbol =>
          token(symbol,next_cursor,sink,distance,after => written => compressed(rest,literal,distance,after,written)))

def stored_bytes(fuel: Nat,cursor: Bits.Cursor,sink: Output.Sink) -> Result<&2,&1,T.Failure,State>:
  match fuel:
    case 0n: Done{State{cursor,sink}}
    case 1n+rest:
      do Result<&2,&1,T.Failure,State>:
        decoded : Bits.Read <- Output.widen(Bits.Read,Bits.read(cursor,8))
        Bits.unpack(Result<&2,&1,T.Failure,State>,decoded,next_cursor => byte =>
          do Result<&2,&1,T.Failure,State>:
            next : Output.Sink <- Output.put(sink,byte)
            stored_bytes(rest,next_cursor,next))

def stored(cursor: Bits.Cursor,sink: Output.Sink) -> Result<&2,&1,T.Failure,State>:
  do Result<&2,&1,T.Failure,State>:
    first : Bits.Read <- Output.widen(Bits.Read,Bits.read(Bits.aligned(cursor),16))
    Bits.unpack(Result<&2,&1,T.Failure,State>,first,c1 => declared_length =>
      do Result<&2,&1,T.Failure,State>:
        +length : U32 = declared_length
        second : Bits.Read <- Output.widen(Bits.Read,Bits.read(c1,16))
        Bits.unpack(Result<&2,&1,T.Failure,State>,second,c2 => inverse =>
          do Result<&2,&1,T.Failure,State>:
            _ : Unit <- Output.widen(Unit,T.require(U32.is_eq(U32.xor(length,inverse),65535),T.CompressedData{},"DEFLATE stored LEN/NLEN mismatch"))
            stored_bytes(U32.to_nat(length),c2,sink)))

def block(kind: U32,cursor: Bits.Cursor,sink: Output.Sink,limit: U32) -> Result<&2,&1,T.Failure,State>:
  match kind:
    case 0: stored(cursor,sink)
    case 1:
      do Result<&2,&1,T.Failure,State>:
        tables : Tables.Tables <- Output.widen(Tables.Tables,Tables.fixed())
        Tables.unpack(Result<&2,&1,T.Failure,State>,tables,literal => distance =>
          compressed(U32.to_nat(U32.inc(limit)),literal,distance,cursor,sink))
    case 2:
      do Result<&2,&1,T.Failure,State>:
        parsed : Tables.Parsed <- Output.widen(Tables.Parsed,Tables.dynamic(cursor))
        Tables.unpack_parsed(Result<&2,&1,T.Failure,State>,parsed,next_cursor => literal => distance =>
          compressed(U32.to_nat(U32.inc(limit)),literal,distance,next_cursor,sink))
    case _: Fail{T.Failure{T.CompressedData{},"Reserved DEFLATE block type"}}

def next_block(last: U32,state: State,next: State -> Result<&2,&1,T.Failure,State>) -> Result<&2,&1,T.Failure,State>:
  match last:
    case 0: next(state)
    case _: Done{state}

def blocks(fuel: Nat,state: State,+limit: U32) -> Result<&2,&1,T.Failure,State>:
  match fuel state:
    case 0n _: Fail{T.Failure{T.ResourceLimit{},"DEFLATE exceeds 4096 blocks"}}
    case 1n+rest State{cursor,sink}:
      do Result<&2,&1,T.Failure,State>:
        parsed : Bits.Read <- Output.widen(Bits.Read,Bits.read(cursor,3))
        Bits.unpack(Result<&2,&1,T.Failure,State>,parsed,next_cursor => decoded_header =>
          do Result<&2,&1,T.Failure,State>:
            +header : U32 = decoded_header
            next : State <- block(U32.shr(header),next_cursor,sink,limit)
            next_block(U32.and(header,1),next,after => blocks(rest,after,limit)))

def trailer(bytes: List<&2,U32>,+output: List<&2,U32>) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  match bytes:
    case Con{a,Con{b,Con{c,Con{d,Nil{}}}}}:
      do Result<&2,&2,T.Failure,List<&2,U32>>:
        expected : U32 = U32.or(U32.or(U32.shln(a,24n),U32.shln(b,16n)),U32.or(U32.shln(c,8n),d))
        _ : Unit <- T.require(U32.is_eq(expected,Checksum.adler(output)),T.CompressedData{},"PNG zlib Adler32 mismatch")
        Done{output}
    case _: Fail{T.Failure{T.CompressedData{},"Missing zlib checksum or trailing compressed bytes"}}

def finish(result: Result<&2,&1,T.Failure,State>) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{State{cursor,sink}}:
      do Result<&2,&2,T.Failure,List<&2,U32>>:
        output : List<&2,U32> <- Output.finish(sink)
        trailer(Bits.remaining(Bits.aligned(cursor)),output)

def run(bytes: List<&2,U32>,+limit: U32,window_bits: U32) -> Result<&2,&1,T.Failure,State>:
  do Result<&2,&1,T.Failure,State>:
    sink : Output.Sink <- Output.new(window_bits,limit)
    blocks(4096n,State{Bits.start(bytes),sink},limit)

def header(bytes: List<&2,U32>,limit: U32) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  match bytes:
    case Con{+cmf,Con{+flg,tail}}:
      do Result<&2,&2,T.Failure,List<&2,U32>>:
        _ : Unit <- T.require(U32.is_eq(U32.and(cmf,15),8) && U32.is_le(U32.shrn(cmf,4n),7),T.CompressedData{},"Unsupported zlib method or window")
        _ : Unit <- T.require(U32.is_eq(U32.mod(U32.add(U32.mul(cmf,256),flg),31),0),T.CompressedData{},"Invalid zlib header FCHECK")
        _ : Unit <- T.require(U32.is_eq(U32.and(flg,32),0),T.CompressedData{},"PNG zlib preset dictionaries are forbidden")
        finish(run(tail,limit,U32.add(U32.shrn(cmf,4n),8)))
    case _: Fail{T.Failure{T.CompressedData{},"Truncated zlib header"}}

def decode(+bytes: List<&2,U32>,+expected_count: U32) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  do Result<&2,&2,T.Failure,List<&2,U32>>:
    _ : Unit <- T.require(U32.is_le(expected_count,T.max_filtered()),T.ResourceLimit{},"Declared PNG output exceeds image profile")
    _ : Unit <- admit(bytes,0)
    header(bytes,expected_count)
