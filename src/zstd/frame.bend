import Base
import ./pair.bend as DataPair
import ./bytes.bend as Bytes
import ./huffman.bend as Huffman
import ./output.bend as Output
import ./block.bend as Block
import ./xxh64.bend as XXH

type Limits is Data:
  Limits{input: U32,output: U32,window: U32,frames: U32,blocks: U32}

type Header is Data:
  Header{window: U32,content: Maybe<&2,U32>,checksum: Bool}

type Frame is Data:
  Frame{tail: List<&2,U32>,reversed: List<&2,List<&2,U32>>,count: U32}

type DecodedBlock is Type:
  DecodedBlock{tail: List<&2,U32>,state: Block.State,sink: Output.Sink,bytes: List<&2,U32>}

def unpack_decoded(-R: Type,decoded: DecodedBlock,next: List<&2,U32> -> Block.State -> Output.Sink -> List<&2,U32> -> R) -> R:
  DecodedBlock{tail,state,sink,bytes} = decoded
  next(tail,state,sink,bytes)

def unpack_frame(-R: Type,frame: Frame,next: List<&2,U32> -> List<&2,List<&2,U32>> -> U32 -> R) -> R:
  Frame{tail,chunks,count} = frame
  next(tail,chunks,count)

def window(header: Header) -> U32:
  Header{size,_,_} = header
  size

def narrow(-A: Data,result: Result<&2,&1,String,A>) -> Result<&2,&2,String,A>:
  match result:
    case Fail{error}: Fail{error}
    case Done{value}: Done{value}

def dictionary_width(flag: U32) -> U32:
  match flag:
    case 3: 4
    case _: flag

def window_descriptor(single: Bool,bytes: List<&2,U32>,limit: U32) -> Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  match single:
    case True{}: Done{(0,bytes)}
    case False{}:
      do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
        +descriptor : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        +log : U32 = U32.add(10,U32.shrn(descriptor,3n))
        _ : Unit <- Huffman.require(U32.is_le(log,23),"Zstandard window exceeds8MiB")
        +base : U32 = U32.shln(1,U32.to_nat(log))
        +window : U32 = U32.add(base,U32.mul(U32.shrn(base,3n),U32.and(descriptor,7)))
        _ : Unit <- Huffman.require(U32.is_le(window,limit),"Zstandard window exceeds configured limit")
        Done{(window,tail)}

def content_size(flag: U32,single: Bool,bytes: List<&2,U32>) ->
  Result<&2,&2,String,DataPair.Duo(Maybe<&2,U32>,List<&2,U32>)>:
  match flag single:
    case 0 False{}: Done{(None{},bytes)}
    case 0 True{}:
      do Result<&2,&2,String,DataPair.Duo(Maybe<&2,U32>,List<&2,U32>)>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
        size : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        Done{(Some{size},tail)}
    case 1 _:
      do Result<&2,&2,String,DataPair.Duo(Maybe<&2,U32>,List<&2,U32>)>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,2)
        size : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        Done{(Some{U32.add(size,256)},tail)}
    case 2 _:
      do Result<&2,&2,String,DataPair.Duo(Maybe<&2,U32>,List<&2,U32>)>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
        size : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        Done{(Some{size},tail)}
    case _ _:
      do Result<&2,&2,String,DataPair.Duo(Maybe<&2,U32>,List<&2,U32>)>:
        +low : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
        size : U32 = DataPair.first(U32,List<&2,U32>,low)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,low)
        +high : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(tail,4)
        upper : U32 = DataPair.first(U32,List<&2,U32>,high)
        rest : List<&2,U32> = DataPair.second(U32,List<&2,U32>,high)
        _ : Unit <- Huffman.require(U32.is_eq(upper,0),"64-bit frame content size exceeds supported output limit")
        Done{(Some{size},rest)}

def header_ready(single: Bool,window: U32,content: Maybe<&2,U32>,checksum: Bool,output: U32,maximum: U32) ->
  Result<&2,&2,String,Header>:
  match single content:
    case True{} None{}: Fail{"single-segment frame lacks content size"}
    case True{} Some{+size}:
      do Result<&2,&2,String,Header>:
        _ : Unit <- Huffman.require(U32.is_le(size,output) && U32.is_le(size,maximum),"single-segment frame exceeds output or window limit")
        Done{Header{size,Some{size},checksum}}
    case False{} Some{+size}:
      do Result<&2,&2,String,Header>:
        _ : Unit <- Huffman.require(U32.is_le(size,output),"frame content exceeds output limit")
        Done{Header{window,Some{size},checksum}}
    case False{} None{}: Done{Header{window,None{},checksum}}

def header(bytes: List<&2,U32>,+window_limit: U32,output: U32) -> Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
    +descriptor_pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
    +descriptor : U32 = DataPair.first(U32,List<&2,U32>,descriptor_pair)
    tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,descriptor_pair)
    _ : Unit <- Huffman.require(U32.is_eq(U32.and(descriptor,8),0),"reserved frame header bit is set")
    +single : Bool = U32.is_ne(U32.and(descriptor,32),0)
    +window_pair : DataPair.Duo(U32,List<&2,U32>) <- window_descriptor(single,tail,window_limit)
    window : U32 = DataPair.first(U32,List<&2,U32>,window_pair)
    tail1 : List<&2,U32> = DataPair.second(U32,List<&2,U32>,window_pair)
    +dictionary_pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(tail1,dictionary_width(U32.and(descriptor,3)))
    dictionary : U32 = DataPair.first(U32,List<&2,U32>,dictionary_pair)
    tail2 : List<&2,U32> = DataPair.second(U32,List<&2,U32>,dictionary_pair)
    _ : Unit <- Huffman.require(U32.is_eq(dictionary,0),"dictionary-required Zstandard frame is unsupported")
    +content_pair : DataPair.Duo(Maybe<&2,U32>,List<&2,U32>) <- content_size(U32.shrn(descriptor,6n),single,tail2)
    content : Maybe<&2,U32> = DataPair.first(Maybe<&2,U32>,List<&2,U32>,content_pair)
    tail3 : List<&2,U32> = DataPair.second(Maybe<&2,U32>,List<&2,U32>,content_pair)
    parsed : Header <- header_ready(single,window,content,U32.is_ne(U32.and(descriptor,4),0),output,window_limit)
    Done{(parsed,tail3)}

def body(kind: U32,+size: U32,bytes: List<&2,U32>,state: Block.State,sink: Output.Sink,+maximum: U32) ->
  Result<&2,&1,String,DecodedBlock>:
  match kind:
    case 0:
      do Result<&2,&1,String,DecodedBlock>:
        +pair : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Output.widen(DataPair.Duo(List<&2,U32>,List<&2,U32>),Bytes.take(bytes,size))
        raw : List<&2,U32> = DataPair.first(List<&2,U32>,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(List<&2,U32>,List<&2,U32>,pair)
        written : Output.Sink & List<&2,U32> <- Output.apply(Nil{},sink,raw,maximum,Nil{})
        Output.unpack(Output.Sink,List<&2,U32>,Result<&2,&1,String,DecodedBlock>,written,
          next => decoded => Done{DecodedBlock{tail,state,next,decoded}})
    case 1:
      do Result<&2,&1,String,DecodedBlock>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Output.widen(DataPair.Duo(U32,List<&2,U32>),Bytes.octet(bytes))
        byte : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        written : Output.Sink & List<&2,U32> <- Output.apply(Nil{},sink,Bytes.repeat(U32.to_nat(size),byte,Nil{}),maximum,Nil{})
        Output.unpack(Output.Sink,List<&2,U32>,Result<&2,&1,String,DecodedBlock>,written,
          next => decoded => Done{DecodedBlock{tail,state,next,decoded}})
    case 2:
      do Result<&2,&1,String,DecodedBlock>:
        +pair : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Output.widen(DataPair.Duo(List<&2,U32>,List<&2,U32>),Bytes.take(bytes,size))
        compressed : List<&2,U32> = DataPair.first(List<&2,U32>,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(List<&2,U32>,List<&2,U32>,pair)
        decoded : (Block.State & Output.Sink) & List<&2,U32> <- Block.compressed(compressed,state,sink,maximum)
        Output.unpack(Block.State & Output.Sink,List<&2,U32>,Result<&2,&1,String,DecodedBlock>,decoded,
          next => raw => Output.unpack(Block.State,Output.Sink,Result<&2,&1,String,DecodedBlock>,next,
            next_state => next_sink => Done{DecodedBlock{tail,next_state,next_sink,raw}}))
    case _: Fail{"reserved Zstandard block type"}

def size_matches(content: Maybe<&2,U32>,count: U32) -> Bool:
  match content:
    case None{}: True{}
    case Some{size}: U32.is_eq(size,count)

def checksum_bytes(checksum: Bool,bytes: List<&2,U32>,hash: XXH.State) -> Result<&2,&2,String,List<&2,U32>>:
  match checksum:
    case False{}: Done{bytes}
    case True{}:
      do Result<&2,&2,String,List<&2,U32>>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
        expected : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        digest : XXH.LimbWord <- XXH.finish(hash)
        _ : Unit <- Huffman.require(U32.is_eq(expected,XXH.low(digest)),"Zstandard content checksum mismatch")
        Done{tail}

def finish(header: Header,bytes: List<&2,U32>,sink: Output.Sink,hash: XXH.State,reversed: List<&2,List<&2,U32>>) ->
  Result<&2,&1,String,Frame>:
  Header{_,content,checksum} = header
  Output.Sink{_,_,_,+count,_,_} = sink
  do Result<&2,&1,String,Frame>:
    _ : Unit <- Output.widen(Unit,Huffman.require(size_matches(content,count),"decoded frame size disagrees with header"))
    tail : List<&2,U32> <- Output.widen(List<&2,U32>,checksum_bytes(checksum,bytes,hash))
    Done{Frame{tail,reversed,count}}

def blocks(fuel: Nat,finished: Bool,+header: Header,bytes: List<&2,U32>,state: Block.State,
  sink: Output.Sink,hash: XXH.State,reversed: List<&2,List<&2,U32>>) -> Result<&2,&1,String,Frame>:
  match fuel finished:
    case _ True{}: finish(header,bytes,sink,hash,reversed)
    case 0n False{}: Fail{"Zstandard frame exceeds configured block count"}
    case 1n+rest False{}:
      do Result<&2,&1,String,Frame>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Output.widen(DataPair.Duo(U32,List<&2,U32>),Bytes.little(bytes,3))
        +descriptor : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        +maximum : U32 = U32.min(window(header),131072)
        +size : U32 = U32.shrn(descriptor,3n)
        _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_le(size,maximum),"compressed or raw block exceeds frame block limit"))
        decoded : DecodedBlock <- body(U32.and(U32.shr(descriptor),3),size,tail,state,sink,maximum)
        unpack_decoded(Result<&2,&1,String,Frame>,decoded,
          tail1 => state1 => sink1 => raw => do Result<&2,&1,String,Frame>:
            +saved : List<&2,U32> = raw
            next_hash : XXH.State <- Output.widen(XXH.State,XXH.update(hash,saved))
            blocks(rest,U32.is_ne(U32.and(descriptor,1),0),header,tail1,state1,sink1,next_hash,Con{saved,reversed}))

def framed(+header: Header,bytes: List<&2,U32>,+output: U32,max_blocks: U32) -> Result<&2,&1,String,Frame>:
  do Result<&2,&1,String,Frame>:
    sink : Output.Sink <- Output.new(window(header),output)
    blocks(U32.to_nat(max_blocks),False{},header,bytes,Block.initial(),sink,XXH.init(output),Nil{})

def magic(+magic: U32,bytes: List<&2,U32>,limits: Limits,+output: U32) -> Result<&2,&2,String,Frame>:
  match magic:
    case 4247762216:
      Limits{_,_,window,_,block_limit} = limits
      do Result<&2,&2,String,Frame>:
        +pair : DataPair.Duo(Header,List<&2,U32>) <- header(bytes,window,output)
        h : Header = DataPair.first(Header,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(Header,List<&2,U32>,pair)
        narrow(Frame,framed(h,tail,output,block_limit))
    case _:
      Limits{input,_,_,_,_} = limits
      do Result<&2,&2,String,Frame>:
        _ : Unit <- Huffman.require(U32.is_ge(magic,407710288) && U32.is_le(magic,407710303),"unrecognized Zstandard frame magic")
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
        +size : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        _ : Unit <- Huffman.require(U32.is_le(size,input),"skippable frame exceeds input limit")
        taken : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(tail,size)
        remaining : List<&2,U32> = DataPair.second(List<&2,U32>,List<&2,U32>,taken)
        Done{Frame{remaining,Nil{},0}}

def one(bytes: List<&2,U32>,limits: Limits,output: U32) -> Result<&2,&2,String,Frame>:
  do Result<&2,&2,String,Frame>:
    +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
    marker : U32 = DataPair.first(U32,List<&2,U32>,pair)
    tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
    magic(marker,tail,limits,output)

def frames(fuel: Nat,bytes: List<&2,U32>,+limits: Limits,+remaining: U32,reversed: List<&2,List<&2,U32>>) ->
  Result<&2,&2,String,List<&2,List<&2,U32>>>:
  match fuel bytes:
    case _ Nil{}: Done{List.reverse(&2,List<&2,U32>,reversed)}
    case 0n Con{_,_}: Fail{"Zstandard input exceeds configured frame count"}
    case 1n+rest current:
      do Result<&2,&2,String,List<&2,List<&2,U32>>>:
        decoded : Frame <- one(current,limits,remaining)
        unpack_frame(Result<&2,&2,String,List<&2,List<&2,U32>>>,decoded,
          tail => chunks => count => do Result<&2,&2,String,List<&2,List<&2,U32>>>:
            +saved : U32 = count
            _ : Unit <- Huffman.require(U32.is_le(saved,remaining),"decoded frames exceed output limit")
            frames(rest,tail,limits,U32.sub(remaining,saved),List.append(&2,List<&2,U32>,chunks,reversed)))

def validate(bytes: List<&2,U32>,remaining: Nat) -> Result<&2,&2,String,Unit>:
  match bytes remaining:
    case Nil{} _: Done{Unit{}}
    case Con{_,_} 0n: Fail{"Zstandard input exceeds configured byte limit"}
    case Con{byte,tail} 1n+rest:
      do Result<&2,&2,String,Unit>:
        _ : Unit <- Huffman.require(U32.is_le(byte,255),"Zstandard input contains non-octet")
        validate(tail,rest)

def decode(+bytes: List<&2,U32>,+limits: Limits) -> Result<&2,&2,String,List<&2,List<&2,U32>>>:
  Limits{+input,+output,window,+frame_count,+block_count} = limits
  do Result<&2,&2,String,List<&2,List<&2,U32>>>:
    _ : Unit <- Huffman.require(U32.is_le(input,67108864) && U32.is_le(output,268435456) && U32.is_le(window,8388608) && U32.is_gt(frame_count,0) && U32.is_le(frame_count,1024) && U32.is_gt(block_count,0) && U32.is_le(block_count,65536),"invalid Zstandard decoder limits")
    _ : Unit <- validate(bytes,U32.to_nat(input))
    _ : Unit <- Huffman.require(Bool.not(List.is_empty(&2,U32,bytes)),"empty Zstandard source")
    frames(U32.to_nat(frame_count),bytes,limits,output,Nil{})
