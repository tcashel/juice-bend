import Base
import ./pair.bend as DataPair
import ./bytes.bend as Bytes
import ./frame.bend as Frame
import ./block.bend as Block
import ./output.bend as Output
import ./huffman.bend as Huffman
import ./xxh64.bend as XXH

# Exact-request, affine streaming decoder. A caller supplies only request()'s
# bounded byte count and consumes each output before requesting more input.
# Output remains provisional until finish succeeds: a later checksum, truncated
# frame, or corrupt concatenated frame must roll back the caller's transaction.
# The state retains one bounded LZ window, entropy tables, and checksum state;
# it never retains the compressed source or previously emitted output blocks.
type Counters is Data:
  Counters{limits: Frame.Limits,input: U32,output: U32,frames: U32}

type Active is Type:
  Active{header: Frame.Header,tables: Block.State,sink: Output.Sink,hash: XXH.State,blocks: U32}

type Phase is Type:
  Magic{}
  Descriptor{}
  HeaderTail{descriptor: U32,count: U32}
  BlockHeader{active: Active}
  BlockBody{active: Active,kind: U32,size: U32,last: Bool}
  Checksum{hash: XXH.State}
  SkipSize{}
  SkipBody{remaining: U32}

type State is Type:
  State{counters: Counters,phase: Phase}

type Step is Type:
  Step{state: State,output: List<&2,U32>}

type Summary is Data:
  Summary{input: U32,output: U32,frames: U32}

def begin(+limits: Frame.Limits) -> Result<&2,&1,String,State>:
  Frame.Limits{input,output,window,+frames,+blocks} = limits
  do Result<&2,&1,String,State>:
    _ : Unit <- Output.widen(Unit,Huffman.require(
      U32.is_le(input,67108864) && U32.is_le(output,268435456) && U32.is_le(window,8388608) &&
      U32.is_gt(frames,0) && U32.is_le(frames,1024) && U32.is_gt(blocks,0) && U32.is_le(blocks,65536),
      "invalid Zstandard decoder limits"))
    Done{State{Counters{limits,0,0,0},Magic{}}}

def body_count(kind: U32,size: U32) -> U32:
  match kind:
    case 1: 1
    case _: size

def request(state: State) -> State & U32:
  State{counters,phase} = state
  match phase:
    case Magic{}: (State{counters,Magic{}},4)
    case Descriptor{}: (State{counters,Descriptor{}},1)
    case HeaderTail{descriptor,+count}: (State{counters,HeaderTail{descriptor,count}},count)
    case BlockHeader{active}: (State{counters,BlockHeader{active}},3)
    case BlockBody{active,+kind,+size,last}: (State{counters,BlockBody{active,kind,size,last}},body_count(kind,size))
    case Checksum{hash}: (State{counters,Checksum{hash}},4)
    case SkipSize{}: (State{counters,SkipSize{}},4)
    case SkipBody{+remaining}: (State{counters,SkipBody{remaining}},U32.min(remaining,65536))

def exact(bytes: List<&2,U32>,fuel: Nat) -> Result<&2,&2,String,Unit>:
  match bytes fuel:
    case Nil{} 0n: Done{Unit{}}
    case Nil{} 1n+_: Fail{"stream input shorter than requested field"}
    case Con{_,_} 0n: Fail{"stream input longer than requested field"}
    case Con{byte,tail} 1n+rest:
      do Result<&2,&2,String,Unit>:
        _ : Unit <- Huffman.require(U32.is_le(byte,255),"Zstandard input contains non-octet")
        exact(tail,rest)

def charged(counters: Counters,+count: U32) -> Result<&2,&2,String,Counters>:
  Counters{+limits,+input,output,frames} = counters
  Frame.Limits{+maximum,_,_,_,_} = limits
  do Result<&2,&2,String,Counters>:
    _ : Unit <- Huffman.require(U32.is_le(input,maximum) && U32.is_le(count,U32.sub(maximum,U32.min(input,maximum))),
      "Zstandard input exceeds configured byte limit")
    Done{Counters{limits,U32.add(input,count),output,frames}}

def emitted(counters: Counters,+count: U32) -> Result<&2,&2,String,Counters>:
  Counters{+limits,input,+output,frames} = counters
  Frame.Limits{_,+maximum,_,_,_} = limits
  do Result<&2,&2,String,Counters>:
    _ : Unit <- Huffman.require(U32.is_le(output,maximum) && U32.is_le(count,U32.sub(maximum,U32.min(output,maximum))),
      "decoded frames exceed output limit")
    Done{Counters{limits,input,U32.add(output,count),frames}}

def complete(counters: Counters) -> Counters:
  Counters{limits,input,output,frames} = counters
  Counters{limits,input,output,U32.add(frames,1)}

def empty_step(counters: Counters,phase: Phase) -> Result<&2,&1,String,Step>:
  Done{Step{State{counters,phase},Nil{}}}

def little(bytes: List<&2,U32>,count: U32) -> Result<&2,&2,String,U32>:
  do Result<&2,&2,String,U32>:
    pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,count)
    Done{DataPair.first(U32,List<&2,U32>,pair)}

def magic_marker(counters: Counters,+marker: U32) -> Result<&2,&1,String,Step>:
  match marker:
    case 4247762216: empty_step(counters,Descriptor{})
    case _:
      do Result<&2,&1,String,Step>:
        _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_ge(marker,407710288) && U32.is_le(marker,407710303),
          "unrecognized Zstandard frame magic"))
        empty_step(counters,SkipSize{})

def magic(counters: Counters,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  Counters{+limits,input,output,+frames} = counters
  Frame.Limits{_,_,_,maximum,_} = limits
  do Result<&2,&1,String,Step>:
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_lt(frames,maximum),"Zstandard input exceeds configured frame count"))
    marker : U32 <- Output.widen(U32,little(bytes,4))
    magic_marker(Counters{limits,input,output,frames},marker)

def content_width(flag: U32,single: Bool) -> U32:
  match flag single:
    case 0 False{}: 0
    case 0 True{}: 1
    case 1 _: 2
    case 2 _: 4
    case _ _: 8

def window_width(single: Bool) -> U32:
  match single:
    case True{}: 0
    case False{}: 1

def header_count(+descriptor: U32) -> U32:
  +single = U32.is_ne(U32.and(descriptor,32),0)
  U32.add(window_width(single),
    U32.add(Frame.dictionary_width(U32.and(descriptor,3)),content_width(U32.shrn(descriptor,6n),single)))

def descriptor(counters: Counters,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  do Result<&2,&1,String,Step>:
    +value : U32 <- Output.widen(U32,little(bytes,1))
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_eq(U32.and(value,8),0),"reserved frame header bit is set"))
    empty_step(counters,HeaderTail{value,header_count(value)})

def start_frame(counters: Counters,+header: Frame.Header,+remaining: U32) -> Result<&2,&1,String,Step>:
  do Result<&2,&1,String,Step>:
    sink : Output.Sink <- Output.new(Frame.window(header),remaining)
    empty_step(counters,BlockHeader{Active{header,Block.initial(),sink,XXH.init(remaining),0}})

def header_tail(counters: Counters,value: U32,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  Counters{+limits,input,+output,frames} = counters
  Frame.Limits{_,maximum,window,_,_} = limits
  do Result<&2,&1,String,Step>:
    +remaining : U32 = U32.sub(maximum,output)
    pair : DataPair.Duo(Frame.Header,List<&2,U32>) <- Output.widen(DataPair.Duo(Frame.Header,List<&2,U32>),Frame.header(Con{value,bytes},window,remaining))
    header : Frame.Header = DataPair.first(Frame.Header,List<&2,U32>,pair)
    start_frame(Counters{limits,input,output,frames},header,remaining)

def end_frame(counters: Counters,checksum: Bool,hash: XXH.State,raw: List<&2,U32>) -> Result<&2,&1,String,Step>:
  match checksum:
    case True{}: Done{Step{State{counters,Checksum{hash}},raw}}
    case False{}: Done{Step{State{complete(counters),Magic{}},raw}}

def last_block(counters: Counters,active: Active,raw: List<&2,U32>) -> Result<&2,&1,String,Step>:
  Active{Frame.Header{_,content,checksum},_,sink,hash,_} = active
  Output.Sink{_,_,_,count,_,_} = sink
  do Result<&2,&1,String,Step>:
    _ : Unit <- Output.widen(Unit,Huffman.require(Frame.size_matches(content,count),"decoded frame size disagrees with header"))
    end_frame(counters,checksum,hash,raw)

def emit_block(counters: Counters,active: Active,last: Bool,raw: List<&2,U32>) -> Result<&2,&1,String,Step>:
  match last:
    case True{}: last_block(counters,active,raw)
    case False{}: Done{Step{State{counters,BlockHeader{active}},raw}}

def after_block(counters: Counters,header: Frame.Header,hash: XXH.State,blocks: U32,last: Bool,decoded: Frame.DecodedBlock) ->
  Result<&2,&1,String,Step>:
  Frame.DecodedBlock{tail,tables,sink,+raw} = decoded
  do Result<&2,&1,String,Step>:
    _ : Unit <- Output.widen(Unit,Huffman.require(List.is_empty(&2,U32,tail),"stream block decoder left input bytes"))
    next_hash : XXH.State <- Output.widen(XXH.State,XXH.update(hash,raw))
    next_counters : Counters <- Output.widen(Counters,emitted(counters,U32.from_nat(List.length(&2,U32,raw))))
    emit_block(next_counters,Active{header,tables,sink,next_hash,blocks},last,raw)

def block_body(counters: Counters,active: Active,kind: U32,size: U32,last: Bool,bytes: List<&2,U32>) ->
  Result<&2,&1,String,Step>:
  Active{+header,tables,sink,hash,blocks} = active
  do Result<&2,&1,String,Step>:
    decoded : Frame.DecodedBlock <- Frame.body(kind,size,bytes,tables,sink,U32.min(Frame.window(header),131072))
    after_block(counters,header,hash,blocks,last,decoded)

def block_ready(counters: Counters,active: Active,kind: U32,size: U32,last: Bool,empty: Bool) -> Result<&2,&1,String,Step>:
  match empty:
    case True{}: block_body(counters,active,kind,size,last,Nil{})
    case False{}: empty_step(counters,BlockBody{active,kind,size,last})

def block_header(counters: Counters,active: Active,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  Counters{+limits,input,output,frames} = counters
  Frame.Limits{_,_,_,_,maximum_blocks} = limits
  Active{+header,tables,sink,hash,+blocks} = active
  do Result<&2,&1,String,Step>:
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_lt(blocks,maximum_blocks),"Zstandard frame exceeds configured block count"))
    +value : U32 <- Output.widen(U32,little(bytes,3))
    +size : U32 = U32.shrn(value,3n)
    +kind : U32 = U32.and(U32.shr(value),3)
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_ne(kind,3),"reserved Zstandard block type"))
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_le(size,U32.min(Frame.window(header),131072)),
      "compressed or raw block exceeds frame block limit"))
    block_ready(Counters{limits,input,output,frames},Active{header,tables,sink,hash,U32.add(blocks,1)},kind,size,
      U32.is_ne(U32.and(value,1),0),U32.is_eq(body_count(kind,size),0))

def checksum(counters: Counters,hash: XXH.State,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  do Result<&2,&1,String,Step>:
    _ : List<&2,U32> <- Output.widen(List<&2,U32>,Frame.checksum_bytes(True{},bytes,hash))
    empty_step(complete(counters),Magic{})

def skip_ready(counters: Counters,size: U32,empty: Bool) -> Result<&2,&1,String,Step>:
  match empty:
    case True{}: empty_step(complete(counters),Magic{})
    case False{}: empty_step(counters,SkipBody{size})

def skip_size(counters: Counters,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  Counters{+limits,+input,output,frames} = counters
  Frame.Limits{maximum,_,_,_,_} = limits
  do Result<&2,&1,String,Step>:
    +size : U32 <- Output.widen(U32,little(bytes,4))
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_le(size,U32.sub(maximum,input)),"skippable frame exceeds input limit"))
    skip_ready(Counters{limits,input,output,frames},size,U32.is_eq(size,0))

def skip_body(counters: Counters,remaining: U32,count: U32) -> Result<&2,&1,String,Step>:
  +next = U32.sub(remaining,count)
  skip_ready(counters,next,U32.is_eq(next,0))

def push_phase(counters: Counters,phase: Phase,bytes: List<&2,U32>,count: U32) -> Result<&2,&1,String,Step>:
  match phase:
    case Magic{}: magic(counters,bytes)
    case Descriptor{}: descriptor(counters,bytes)
    case HeaderTail{value,_}: header_tail(counters,value,bytes)
    case BlockHeader{active}: block_header(counters,active,bytes)
    case BlockBody{active,kind,size,last}: block_body(counters,active,kind,size,last,bytes)
    case Checksum{hash}: checksum(counters,hash,bytes)
    case SkipSize{}: skip_size(counters,bytes)
    case SkipBody{remaining}: skip_body(counters,remaining,count)

def push_requested(state: State,+bytes: List<&2,U32>,+count: U32) -> Result<&2,&1,String,Step>:
  State{counters,phase} = state
  do Result<&2,&1,String,Step>:
    _ : Unit <- Output.widen(Unit,Huffman.require(U32.is_gt(count,0) && U32.is_le(count,131072),"invalid stream request size"))
    _ : Unit <- Output.widen(Unit,exact(bytes,U32.to_nat(count)))
    next : Counters <- Output.widen(Counters,charged(counters,count))
    push_phase(next,phase,bytes,count)

def push(state: State,bytes: List<&2,U32>) -> Result<&2,&1,String,Step>:
  Output.unpack(State,U32,Result<&2,&1,String,Step>,request(state),
    next => count => push_requested(next,bytes,count))

def finish(state: State) -> Result<&2,&2,String,Summary>:
  State{Counters{_,input,output,+frames},phase} = state
  match phase:
    case Magic{}:
      do Result<&2,&2,String,Summary>:
        _ : Unit <- Huffman.require(U32.is_gt(frames,0),"empty Zstandard source")
        Done{Summary{input,output,frames}}
    case _: Fail{"truncated Zstandard stream"}
