import Base
import ./pair.bend as DataPair
import ./sequences.bend as Sequences

# A frame-local, affine LZ window grows only when decoded bytes reach capacity.
# No source allocation is based on an unvalidated compressed size. Every array
# get/set is preceded by explicit bounds; Base.Array's wrapped indices are not
# used as validation. Decoded blocks are handed back separately to the caller.
type Sink is Type:
  Sink{bytes: Array<U32>,capacity: U32,position: U32,count: U32,window: U32,limit: U32}

# Destructure an affine pair exactly once, including pairs containing a window.
def unpack(-A: Type,-B: Type,-R: Type,pair: A & B,next: A -> B -> R) -> R:
  (a,b) = pair
  next(a,b)

def unpack_data(-A: Data,-B: Data,-R: Type,pair: DataPair.Duo(A,B),next: A -> B -> R) -> R:
  (a,b) = pair
  next(a,b)

def widen(-A: Data,result: Result<&2,&2,String,A>) -> Result<&2,&1,String,A>:
  match result:
    case Fail{error}: Fail{error}
    case Done{value}: Done{value}

def new_allowed(window: U32,limit: U32,allowed: Bool) -> Result<&2,&1,String,Sink>:
  match allowed:
    case False{}: Fail{"decoder output or window limit unsupported"}
    case True{}: Done{Sink{Array.new(U32,0n,0),1,0,0,window,limit}}

def new(+window: U32,+limit: U32) -> Result<&2,&1,String,Sink>:
  new_allowed(window,limit,U32.is_le(window,8388608) && U32.is_le(limit,268435456))

def count(sink: Sink) -> Sink & U32:
  Sink{bytes,capacity,position,+count,window,limit} = sink
  (Sink{bytes,capacity,position,count,window,limit},count)

def grow(sink: Sink,needed: Bool) -> Sink:
  match sink needed:
    case current False{}: current
    case Sink{bytes,+capacity,_,count,window,limit} True{}:
      Sink{ANode{bytes,Array.new(U32,U32.log2(capacity),0)},U32.mul(capacity,2),capacity,count,window,limit}

def put_ready(sink: Sink,byte: U32) -> Sink:
  Sink{bytes,+capacity,+position,count,window,limit} = sink
  Sink{Array.set(U32,bytes,position,byte),capacity,U32.mod(U32.add(position,1),capacity),U32.add(count,1),window,limit}

def put_allowed(sink: Sink,byte: U32,growing: Bool,allowed: Bool) -> Result<&2,&1,String,Sink>:
  match allowed:
    case False{}: Fail{"decoded byte exceeds output/window bound"}
    case True{}: Done{put_ready(grow(sink,growing),byte)}

def put(sink: Sink,+byte: U32) -> Result<&2,&1,String,Sink>:
  Sink{bytes,+capacity,+position,+count,+window,+limit} = sink
  put_allowed(Sink{bytes,capacity,position,count,window,limit},byte,
    U32.is_eq(count,capacity) && U32.is_lt(capacity,window),
    U32.is_le(byte,255) && U32.is_gt(window,0) && U32.is_lt(count,limit) &&
    U32.is_gt(capacity,0) && U32.is_le(capacity,8388608) && U32.is_lt(position,capacity))

def previous_read(pair: Array<U32> & U32,capacity: U32,position: U32,count: U32,window: U32,limit: U32) -> Result<&2,&1,String,Sink & U32>:
  (next,byte) = pair
  Done{(Sink{next,capacity,position,count,window,limit},byte)}

def previous_allowed(sink: Sink,distance: U32,allowed: Bool) -> Result<&2,&1,String,Sink & U32>:
  match sink allowed:
    case _ False{}: Fail{"match offset is zero, outside window, or before frame start"}
    case Sink{bytes,+capacity,+position,count,window,limit} True{}:
      previous_read(Array.get(U32,bytes,U32.mod(U32.sub(U32.add(position,capacity),distance),capacity)),capacity,position,count,window,limit)

def previous(sink: Sink,+distance: U32) -> Result<&2,&1,String,Sink & U32>:
  Sink{bytes,+capacity,+position,+count,+window,limit} = sink
  previous_allowed(Sink{bytes,capacity,position,count,window,limit},distance,
    U32.is_gt(distance,0) && U32.is_le(distance,count) && U32.is_le(distance,window) &&
    U32.is_le(distance,capacity) && U32.is_gt(capacity,0) && U32.is_lt(position,capacity))

def literal(fuel: Nat,sink: Sink,bytes: List<&2,U32>,rev: List<&2,U32>) ->
  Result<&2,&1,String,Sink & DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
  match fuel bytes:
    case 0n remaining: Done{(sink,(remaining,rev))}
    case 1n+_ Nil{}: Fail{"sequence literal count exceeds decoded literals"}
    case 1n+rest Con{+byte,tail}:
      do Result<&2,&1,String,Sink & DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
        next : Sink <- put(sink,byte)
        literal(rest,next,tail,Con{byte,rev})

def matched(fuel: Nat,sink: Sink,+distance: U32,rev: List<&2,U32>) ->
  Result<&2,&1,String,Sink & List<&2,U32>>:
  match fuel:
    case 0n: Done{(sink,rev)}
    case 1n+rest:
      do Result<&2,&1,String,Sink & List<&2,U32>>:
        pair : Sink & U32 <- previous(sink,distance)
        unpack(Sink,U32,Result<&2,&1,String,Sink & List<&2,U32>>,pair,
          read => byte => do Result<&2,&1,String,Sink & List<&2,U32>>:
            +saved : U32 = byte
            next : Sink <- put(read,saved)
            matched(rest,next,distance,Con{saved,rev}))

def command_allowed(command: Sequences.Sequence,remaining: U32,allowed: Bool) ->
  Result<&2,&2,String,Unit>:
  match allowed:
    case False{}: Fail{"sequence exceeds decompressed block bound"}
    case True{}: Done{Unit{}}

def command(command: Sequences.Sequence,+remaining: U32) -> Result<&2,&2,String,U32>:
  Sequences.Sequence{+literals,+matched,_} = command
  do Result<&2,&2,String,U32>:
    _ : Unit <- command_allowed(Sequences.Sequence{literals,matched,0},remaining,U32.is_le(literals,remaining) && U32.is_le(matched,U32.sub(remaining,U32.min(literals,remaining))))
    Done{U32.sub(U32.sub(remaining,literals),matched)}

def finish_literal(bytes: List<&2,U32>,sink: Sink,remaining: Nat,rev: List<&2,U32>) ->
  Result<&2,&1,String,Sink & List<&2,U32>>:
  match bytes remaining:
    case Nil{} _: Done{(sink,List.reverse(&2,U32,rev))}
    case Con{_,_} 0n: Fail{"remaining literals exceed decompressed block bound"}
    case Con{+byte,tail} 1n+rest:
      do Result<&2,&1,String,Sink & List<&2,U32>>:
        next : Sink <- put(sink,byte)
        finish_literal(tail,next,rest,Con{byte,rev})

def apply(commands: List<&2,Sequences.Sequence>,sink: Sink,literals: List<&2,U32>,remaining: U32,rev: List<&2,U32>) ->
  Result<&2,&1,String,Sink & List<&2,U32>>:
  match commands:
    case Nil{}: finish_literal(literals,sink,U32.to_nat(remaining),rev)
    case Con{Sequences.Sequence{+ll,+ml,distance},tail}:
      do Result<&2,&1,String,Sink & List<&2,U32>>:
        next_remaining : U32 <- widen(U32,command(Sequences.Sequence{ll,ml,0},remaining))
        written : Sink & DataPair.Duo(List<&2,U32>,List<&2,U32>) <- literal(U32.to_nat(ll),sink,literals,rev)
        unpack(Sink,DataPair.Duo(List<&2,U32>,List<&2,U32>),Result<&2,&1,String,Sink & List<&2,U32>>,written,
          next => parts => unpack_data(List<&2,U32>,List<&2,U32>,Result<&2,&1,String,Sink & List<&2,U32>>,parts,
            literals1 => rev1 => do Result<&2,&1,String,Sink & List<&2,U32>>:
              copied : Sink & List<&2,U32> <- matched(U32.to_nat(ml),next,distance,rev1)
              unpack(Sink,List<&2,U32>,Result<&2,&1,String,Sink & List<&2,U32>>,copied,
                next1 => rev2 => apply(tail,next1,literals1,next_remaining,rev2))))
