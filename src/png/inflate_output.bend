import Base
import ../attachment_image_types.bend as T

# The output list is returned to PNG; only the last declared-window bytes live
# in this affine circular array. Every Array index is guarded before access.
type Sink is Type:
  Sink{bytes: Array<U32>,window: U32,position: U32,count: U32,limit: U32,rev: List<&2,U32>}

def unpack(-A: Type,-B: Type,-R: Type,pair: A & B,next: A -> B -> R) -> R:
  (first,second) = pair
  next(first,second)

def widen(-A: Data,result: Result<&2,&2,T.Failure,A>) -> Result<&2,&1,T.Failure,A>:
  match result:
    case Fail{error}: Fail{error}
    case Done{value}: Done{value}

def new(+window_bits: U32,+limit: U32) -> Result<&2,&1,T.Failure,Sink>:
  do Result<&2,&1,T.Failure,Sink>:
    _ : Unit <- widen(Unit,T.require(U32.is_ge(window_bits,8) && U32.is_le(window_bits,15) && U32.is_le(limit,T.max_filtered()),T.ResourceLimit{},"DEFLATE output or window exceeds profile"))
    Done{Sink{Array.new(U32,U32.to_nat(window_bits),0),U32.shln(1,U32.to_nat(window_bits)),0,0,limit,Nil{}}}

def put(sink: Sink,+byte: U32) -> Result<&2,&1,T.Failure,Sink>:
  Sink{bytes,+window,+position,+count,+limit,rev} = sink
  do Result<&2,&1,T.Failure,Sink>:
    _ : Unit <- widen(Unit,T.require(U32.is_le(byte,255) && U32.is_lt(count,limit) && U32.is_ge(window,256) && U32.is_le(window,32768) && U32.is_lt(position,window),T.CompressedData{},"DEFLATE output exceeds exact declared length"))
    Done{Sink{Array.set(U32,bytes,position,byte),window,U32.mod(U32.inc(position),window),U32.inc(count),limit,Con{byte,rev}}}

def previous(sink: Sink,+distance: U32) -> Result<&2,&1,T.Failure,Sink & U32>:
  Sink{bytes,+window,+position,+count,limit,rev} = sink
  do Result<&2,&1,T.Failure,Sink & U32>:
    _ : Unit <- widen(Unit,T.require(U32.is_gt(distance,0) && U32.is_le(distance,count) && U32.is_le(distance,window) && U32.is_ge(window,256) && U32.is_le(window,32768) && U32.is_lt(position,window),T.CompressedData{},"DEFLATE match is outside retained history or declared window"))
    +index : U32 = U32.mod(U32.sub(U32.add(position,window),distance),window)
    _ : Unit <- widen(Unit,T.require(U32.is_lt(index,window),T.CompressedData{},"DEFLATE window index is invalid"))
    pair : Array<U32> & U32 = Array.get(U32,bytes,index)
    unpack(Array<U32>,U32,Result<&2,&1,T.Failure,Sink & U32>,pair,next => byte =>
      Done{(Sink{next,window,position,count,limit,rev},byte)})

def matched(fuel: Nat,sink: Sink,+distance: U32) -> Result<&2,&1,T.Failure,Sink>:
  match fuel:
    case 0n: Done{sink}
    case 1n+rest:
      do Result<&2,&1,T.Failure,Sink>:
        pair : Sink & U32 <- previous(sink,distance)
        unpack(Sink,U32,Result<&2,&1,T.Failure,Sink>,pair,read => byte =>
          do Result<&2,&1,T.Failure,Sink>:
            next : Sink <- put(read,byte)
            matched(rest,next,distance))

def copy(sink: Sink,+distance: U32,+length: U32) -> Result<&2,&1,T.Failure,Sink>:
  Sink{bytes,window,position,+count,+limit,rev} = sink
  do Result<&2,&1,T.Failure,Sink>:
    _ : Unit <- widen(Unit,T.require(U32.is_ge(length,3) && U32.is_le(length,258) && U32.is_le(count,limit) && U32.is_le(length,U32.sub(limit,U32.min(count,limit))),T.CompressedData{},"DEFLATE match exceeds exact output length"))
    matched(U32.to_nat(length),Sink{bytes,window,position,count,limit,rev},distance)

def finish(sink: Sink) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  Sink{_,_,_,count,limit,rev} = sink
  do Result<&2,&2,T.Failure,List<&2,U32>>:
    _ : Unit <- T.require(U32.is_eq(count,limit),T.CompressedData{},"DEFLATE output is shorter than declared length")
    Done{List.reverse(&2,U32,rev)}
