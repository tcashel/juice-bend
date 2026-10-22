import Base
import ./archive_meta.bend as Meta
import ./archive_profile.bend as Profile
import ./zstd/stream.bend as Stream
import ./zstd/pair.bend as Pair
import ./zstd/bytes.bend as Bytes
import ./zstd/output.bend as Output

# A reader cursor retains at most one 64 KiB owned chunk. Exact decoder input
# requests join only the required bytes. Legacy archives may have short chunks;
# the validated chunk count bounds joins without requiring full-size chunks.
type Cursor is Data:
  Cursor{reader: Meta.Reader,pending: List<&2,U32>,available: U32,position: U32}

type Visitor<-A: Type> is Type:
  Visitor{state: A,consume: A -> List<&2,U32> -> IO(Visitor<A>)}

def result(-A: Type,value: Result<&2,&1,String,A>) -> IO(A):
  match value:
    case Done{answer}: IO.pure(A,answer)
    case Fail{+message}: IO.die(A,2,
      Bool.pick(String,String.contains(message,"dictionary"),"archive_dictionary: ",
        Bool.pick(String,String.contains(message,"limit") || String.contains(message,"exceeds"),
          "archive_limit: ","archive_corrupt: ")) ++ message)

def data_result(-A: Data,value: Result<&2,&2,String,A>) -> IO(A):
  match value:
    case Done{answer}: IO.pure(A,answer)
    case Fail{+message}: IO.die(A,2,
      Bool.pick(String,String.contains(message,"dictionary"),"archive_dictionary: ",
        Bool.pick(String,String.contains(message,"limit") || String.contains(message,"exceeds"),
          "archive_limit: ","archive_corrupt: ")) ++ message)

def loaded(read: Meta.Read,position: U32,next: Cursor -> IO(Pair.Duo(Cursor,List<&2,U32>))) -> IO(Pair.Duo(Cursor,List<&2,U32>)):
  Meta.Read{reader,bytes} = read
  match bytes:
    case None{}: IO.die(Pair.Duo(Cursor,List<&2,U32>),2,"archive_corrupt: truncated decoder input")
    case Some{+chunk}: next(Cursor{reader,chunk,U32.from_nat(List.length(&2,U32,chunk)),position})

def split_input(pair: Pair.Duo(List<&2,U32>,List<&2,U32>),reader: Meta.Reader,available: U32,position: U32,
  reversed: List<&2,U32>,next: Cursor -> List<&2,U32> -> IO(Pair.Duo(Cursor,List<&2,U32>))) -> IO(Pair.Duo(Cursor,List<&2,U32>)):
  (taken,tail) = pair
  next(Cursor{reader,tail,available,position},List.reverse.go(&2,U32,taken,reversed))

def read_walk(fuel: Nat,+remaining: U32,+db: U32,cursor: Cursor,reversed: List<&2,U32>) -> IO(Pair.Duo(Cursor,List<&2,U32>)):
  match fuel remaining:
    case _ 0: IO.pure(Pair.Duo(Cursor,List<&2,U32>),(cursor,List.reverse(&2,U32,reversed)))
    case 0n _: IO.die(Pair.Duo(Cursor,List<&2,U32>),2,"archive_limit: decoder input request exceeded bounded chunk join")
    case 1n+rest _:
      Cursor{reader,pending,+available,+position} = cursor
      match pending:
        case []:
          do IO<Pair.Duo(Cursor,List<&2,U32>)>:
            read : Meta.Read <- Meta.next(db,reader)
            loaded(read,position,next => read_walk(rest,remaining,db,next,reversed))
        case +bytes:
          +count = U32.min(remaining,available)
          do IO<Pair.Duo(Cursor,List<&2,U32>)>:
            parts : Pair.Duo(List<&2,U32>,List<&2,U32>) <- data_result(Pair.Duo(List<&2,U32>,List<&2,U32>),Bytes.take(bytes,count))
            split_input(parts,reader,U32.sub(available,count),U32.add(position,count),reversed,
              next => rev => read_walk(rest,U32.sub(remaining,count),db,next,rev))

def read_exact(db: U32,+cursor: Cursor,+count: U32) -> IO(Pair.Duo(Cursor,List<&2,U32>)):
  Cursor{Meta.Reader{_,_,+extent,+chunks,_,+ordinal,_,_},_,_,+position} = cursor
  do IO<Pair.Duo(Cursor,List<&2,U32>)>:
    Meta.checked(U32.is_gt(count,0) && U32.is_le(count,131072) && U32.is_le(position,extent) &&
      U32.is_le(count,U32.sub(extent,position)),"archive_corrupt: truncated or oversized decoder request")
    Meta.checked(U32.is_le(ordinal,chunks),"archive_corrupt: reader chunk position exceeds count")
    read_walk(U32.to_nat(U32.add(U32.mul(U32.inc(U32.sub(chunks,ordinal)),2),1)),count,db,cursor,[])

def finish_read(read: Meta.Read) -> IO(Unit):
  Meta.Read{_,bytes} = read
  match bytes:
    case None{}: IO.pure(Unit,Unit{})
    case Some{_}: IO.die(Unit,2,"archive_corrupt: unconsumed container chunk at decoder EOF")

def finish_cursor(db: U32,cursor: Cursor) -> IO(Unit):
  Cursor{reader,pending,_,_} = cursor
  do IO<Unit>:
    Meta.checked(List.is_empty(&2,U32,pending),"archive_corrupt: unconsumed container bytes at decoder EOF")
    read : Meta.Read <- Meta.next(db,reader)
    finish_read(read)

def finish_visitor(-A: Type,visitor: Visitor<A>,summary: Stream.Summary) -> IO(A & Stream.Summary):
  Visitor{state,_} = visitor
  IO.pure(A & Stream.Summary,(state,summary))

def deliver(-A: Type,step: Stream.Step,visitor: Visitor<A>,next: Stream.State -> Visitor<A> -> IO(A & Stream.Summary)) -> IO(A & Stream.Summary):
  Stream.Step{decoder,bytes} = step
  Visitor{state,consume} = visitor
  do IO<A & Stream.Summary>:
    updated : Visitor<A> <- consume(state,bytes)
    next(decoder,updated)

def decode_input(-A: Type,db: U32,decoder: Stream.State,pair: Pair.Duo(Cursor,List<&2,U32>),
  visitor: Visitor<A>,next: Cursor -> Stream.State -> Visitor<A> -> IO(A & Stream.Summary)) -> IO(A & Stream.Summary):
  (cursor,bytes) = pair
  do IO<A & Stream.Summary>:
    step : Stream.Step <- result(Stream.Step,Stream.push(decoder,bytes))
    deliver(A,step,visitor,dec => vis => next(cursor,dec,vis))

def requested(-A: Type,+db: U32,cursor: Cursor,request: Stream.State & U32,visitor: Visitor<A>,
  next: Cursor -> Stream.State -> Visitor<A> -> IO(A & Stream.Summary)) -> IO(A & Stream.Summary):
  (decoder,count) = request
  do IO<A & Stream.Summary>:
    input : Pair.Duo(Cursor,List<&2,U32>) <- read_exact(db,cursor,count)
    decode_input(A,db,decoder,input,visitor,next)

def at_end(cursor: Cursor) -> Bool:
  Cursor{Meta.Reader{_,_,extent,_,_,_,_,_},_,_,position} = cursor
  U32.is_eq(position,extent)

def walk(-A: Type,fuel: Nat,+db: U32,+cursor: Cursor,decoder: Stream.State,visitor: Visitor<A>,done: Bool) -> IO(A & Stream.Summary):
  match fuel done:
    case _ True{}:
      do IO<A & Stream.Summary>:
        finish_cursor(db,cursor)
        summary : Stream.Summary <- data_result(Stream.Summary,Stream.finish(decoder))
        finish_visitor(A,visitor,summary)
    case 0n False{}: IO.die(A & Stream.Summary,2,"archive_limit: decoder request count exceeds bounded input")
    case 1n+rest False{}:
      requested(A,db,cursor,Stream.request(decoder),visitor,
        +next => dec => vis => walk(A,rest,db,next,dec,vis,at_end(next)))

def run(-A: Type,+db: U32,+reader: Meta.Reader,visitor: Visitor<A>) -> IO(A & Stream.Summary):
  Meta.Reader{_,policy,extent,_,_,_,_,_} = reader
  do IO<A & Stream.Summary>:
    decoder : Stream.State <- result(Stream.State,Stream.begin(Profile.decoder(policy)))
    walk(A,U32.to_nat(extent),db,Cursor{reader,[],0,0},decoder,visitor,False{})
