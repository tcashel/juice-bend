import Base
import ./attachment_image_stream.bend as Stream
import ./attachment_image_binding.bend as Header
import ./attachment_image_types.bend as Image
import ./domain.bend as D

# The caller owns regular-file/path/owner policy and supplies independently
# checked completion fields. This module admits bytes only from that path.
# One file buffer is at most 4096 bytes; each pure feed handles at most 256
# bytes (<=256 header scalars or 32 pixel words), then yields and polls.
# Header reversal and Header.verify remain one bounded <=65536-byte operation.
# File.close has no fallible result in the pinned Base API.
type Config is Data:
  Config{expected: Header.Expected,bytes: U32,digest: String,read_size: U32}
type State is Type:
  Heading{decoder: D.DecodeState,used: U32}
  Pixels{receiving: Stream.Receiving,digits: U32,word: U32}
  Failure{message: String}
type Fed is Type:
  Fed{state: State,rest: List<&2,U32>}

def answer_type() -> Type: Result<&2,&1,String,Image.Raster>
def state_type() -> Type: Result<&2,&1,String,State>
def feed_type() -> Type: Result<&2,&1,String,Fed>
def known(config: Config) -> U32:
  Config{_,bytes,_,_} = config
  bytes
def width(config: Config) -> U32:
  Config{_,_,_,size} = config
  size
def expected(config: Config) -> Header.Expected:
  Config{value,_,_,_} = config
  value
def digest(config: Config) -> String:
  Config{_,_,value,_} = config
  value

# Every non-EOF pump consumes at least one byte, including legal short reads.
# The pinned native compiler represents Nat numerically; this conversion does
# not allocate one node per byte. The byte cap therefore also bounds turns.
def turn_limit(config: Config) -> Nat:
  U32.to_nat(U32.add(known(config),2))

def close(file: File,value: answer_type()) -> IO(answer_type()):
  do IO<answer_type()>:
    File.close(file)
    return value

def bound_header(valid: Bool,header: Header.Header) -> state_type():
  match valid header:
    case False{} _: Fail{"image_completion_digest_mismatch"}
    case True{} Header.FailureHeader{message}: Done{Failure{message}}
    case True{} Header.PixelsHeader{w,h,count,capacity,notice,digest}:
      Done{Pixels{Stream.Receiving{Stream.Extent{w,h,count,capacity,notice,digest},0,"",D.HashContext{D.hash_initial(),[],0,0},[]},0,0}}

def admitted(result: Result<&2,&2,String,Header.Header>,digest: String) -> state_type():
  match result:
    case Fail{message}: Fail{message}
    case Done{+header}:
      match header:
        case Header.FailureHeader{message}: bound_header(String.eq(digest,"none"),Header.FailureHeader{message})
        case Header.PixelsHeader{w,h,count,capacity,notice,+actual}:
          bound_header(String.eq(digest,actual),Header.PixelsHeader{w,h,count,capacity,notice,actual})

def header_done(result: Result<&2,&2,String,String>,expected: Header.Expected,digest: String) -> state_type():
  match result:
    case Fail{_}: Fail{"image_header_limit_or_encoding"}
    case Done{text}: admitted(Header.verify(expected,text),digest)

def decoded(result: Result<&2,&2,String,D.DecodeState>,used: U32) -> state_type():
  match result:
    case Fail{_}: Fail{"image_header_limit_or_encoding"}
    case Done{decoder}: Done{Heading{decoder,used}}

def header_byte(valid: Bool,decoder: D.DecodeState,used: U32,byte: U32) -> state_type():
  match valid:
    case False{}: Fail{"image_header_limit_or_encoding"}
    case True{}: decoded(D.decode_byte(decoder,byte),U32.inc(used))

def heading(byte: U32,decoder: D.DecodeState,+used: U32,expected: Header.Expected,digest: String) -> state_type():
  match byte:
    case 10: header_done(D.decode_done(decoder),expected,digest)
    case other: header_byte(U32.is_lt(used,Stream.header_limit()),decoder,used,other)

# Pixel parsing shares the legacy consumer's exact digit, word admission,
# SHA-256, equal-height Array-stack, padding and finalization kernels.
def appended(step: Stream.Step) -> state_type():
  match step:
    case Stream.Continuing{receiving}: Done{Pixels{receiving,0,0}}
    case Stream.Finished{Fail{message}}: Fail{message}
    case Stream.Finished{Done{_}}: Fail{"image_file_unexpected_finish"}

def digit_ready(result: Result<&2,&2,String,U32>,digits: U32,receiving: Stream.Receiving) -> state_type():
  match result digits:
    case Fail{message} _: Fail{message}
    case Done{value} 7:
      Stream.Receiving{header,index,_,hash,stack} = receiving
      appended(Stream.got(Done{Stream.PixelWord{"",value}},header,index,hash,stack,v => Stream.Continuing{v}))
    case Done{value} n: Done{Pixels{receiving,U32.inc(n),value}}

def pixel_byte(valid: Bool,receiving: Stream.Receiving,digits: U32,word: U32,byte: U32) -> state_type():
  match valid:
    case False{}: Fail{"image_pixel_trailing_data"}
    case True{}: digit_ready(Stream.hex_digit(byte,word),digits,receiving)

def byte(state: State,value: U32,expected: Header.Expected,digest: String) -> state_type():
  match state:
    case Heading{decoder,used}: heading(value,decoder,used,expected,digest)
    case Failure{_}: Fail{"image_failure_trailing_data"}
    case Pixels{Stream.Receiving{header,+index,tail,hash,stack},digits,word}:
      Stream.Extent{w,h,+count,capacity,notice,sha} = header
      pixel_byte(U32.is_lt(index,count),Stream.Receiving{Stream.Extent{w,h,count,capacity,notice,sha},index,tail,hash,stack},digits,word,value)

def fed(result: state_type(),rest: List<&2,U32>,next: State -> List<&2,U32> -> feed_type()) -> feed_type():
  match result:
    case Fail{message}: Fail{message}
    case Done{state}: next(state,rest)

def feed(fuel: Nat,state: State,bytes: List<&2,U32>,+expected: Header.Expected,+digest: String) -> feed_type():
  match fuel bytes:
    case 0n rest: Done{Fed{state,rest}}
    case _ Nil{}: Done{Fed{state,[]}}
    case 1n+left value <> rest:
      fed(byte(state,value,expected,digest),rest,s => r => feed(left,s,r,expected,digest))

# An explicit cancel signal or closed channel retires the request. The caller
# owns the channel; admission only polls it and always closes its own file.
def cancel_result(value: Poll<&1,&1,Maybe<&1,Unit>,Unit>) -> IO(Bool):
  match value:
    case Wait{_}: IO.pure(Bool,True{})
    case Ready{_}: IO.pure(Bool,False{})

def poll_cancel(cancel: Maybe<&2,Chan(Unit)>) -> IO(Bool):
  match cancel:
    case None{}: IO.pure(Bool,True{})
    case Some{channel}:
      do IO<Bool>:
        value : Poll<&1,&1,Maybe<&1,Unit>,Unit> <- Chan.try_recv(Unit,channel,0)
        cancel_result(value)

def finish_allowed(allowed: Bool,file: File,receiving: Stream.Receiving,next: File -> Stream.Step -> IO(answer_type())) -> IO(answer_type()):
  match allowed:
    case False{}: close(file,Fail{"image_file_cancelled"})
    case True{}:
      do IO<answer_type()>:
        IO.sleep(0)
        next(file,Stream.chunk(Stream.pixel_chunk(),receiving))

def finish(fuel: Nat,file: File,step: Stream.Step,+cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  match fuel step:
    case _ Stream.Finished{value}: close(file,value)
    case 0n _: close(file,Fail{"image_pixel_chunk_limit"})
    case 1n+left Stream.Continuing{receiving}:
      do IO<answer_type()>:
        allowed : Bool <- poll_cancel(cancel)
        finish_allowed(allowed,file,receiving,f => s => finish(left,f,s,cancel))

def complete(valid: Bool,file: File,receiving: Stream.Receiving,cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  match valid:
    case False{}: close(file,Fail{"image_pixel_length_mismatch"})
    case True{}: finish(8193n,file,Stream.Continuing{receiving},cancel)

def eof(valid: Bool,file: File,state: State,cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  match valid state:
    case False{} _: close(file,Fail{"image_file_byte_count_mismatch"})
    case True{} Heading{_,_}: close(file,Fail{"image_header_missing_separator"})
    case True{} Failure{message}: close(file,Fail{message})
    case True{} Pixels{Stream.Receiving{header,+index,tail,hash,stack},+digits,_}:
      Stream.Extent{w,h,+count,capacity,notice,sha} = header
      complete(U32.is_eq(digits,0) && U32.is_eq(index,count),file,
        Stream.Receiving{Stream.Extent{w,h,count,capacity,notice,sha},index,tail,hash,stack},cancel)

def feed_result(result: feed_type(),file: File,total: U32,next: File -> U32 -> State -> List<&2,U32> -> IO(answer_type())) -> IO(answer_type()):
  match result:
    case Fail{message}: close(file,Fail{message})
    case Done{Fed{state,rest}}: next(file,total,state,rest)

def sized(valid: Bool,file: File,state: State,bytes: List<&2,U32>,total: U32,config: Config,
  next: File -> U32 -> State -> List<&2,U32> -> IO(answer_type())) -> IO(answer_type()):
  match valid:
    case False{}: close(file,Fail{"image_file_byte_count_mismatch"})
    case True{}:
      Config{expected,_,digest,_} = config
      feed_result(feed(256n,state,bytes,expected,digest),file,total,next)

def read_result(result: File & Result<&1,&1,U32 & String,List<&2,U32>>,state: State,+total: U32,+config: Config,cancel: Maybe<&2,Chan(Unit)>,
  next: File -> U32 -> State -> List<&2,U32> -> IO(answer_type())) -> IO(answer_type()):
  (file,answer) = result
  match answer:
    case Fail{_}: close(file,Fail{"image_file_read_error"})
    case Done{[]}: eof(U32.is_eq(total,known(config)),file,state,cancel)
    case Done{+bytes}:
      +count : U32 = U32.from_nat(List.length(&2,U32,bytes))
      sized(U32.is_le(count,width(config)) && U32.is_le(total,known(config)) && U32.is_le(count,U32.sub(known(config),total)),
        file,state,bytes,U32.add(total,count),config,next)

def buffered(bytes: List<&2,U32>,file: File,state: State,total: U32,+config: Config,cancel: Maybe<&2,Chan(Unit)>,
  next: File -> U32 -> State -> List<&2,U32> -> IO(answer_type())) -> IO(answer_type()):
  match bytes:
    case []:
      do IO<answer_type()>:
        result : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,width(config))
        read_result(result,state,total,config,cancel,next)
    case remaining:
      feed_result(feed(256n,state,remaining,expected(config),digest(config)),file,total,next)

def allowed(proceed: Bool,file: File,total: U32,state: State,bytes: List<&2,U32>,config: Config,cancel: Maybe<&2,Chan(Unit)>,
  next: File -> U32 -> State -> List<&2,U32> -> IO(answer_type())) -> IO(answer_type()):
  match proceed:
    case False{}: close(file,Fail{"image_file_cancelled"})
    case True{}:
      do IO<answer_type()>:
        IO.sleep(0)
        buffered(bytes,file,state,total,config,cancel,next)

def pump(fuel: Nat,file: File,total: U32,state: State,bytes: List<&2,U32>,+config: Config,+cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  match fuel:
    case 0n: close(file,Fail{"image_file_step_limit"})
    case 1n+left:
      do IO<answer_type()>:
        proceed : Bool <- poll_cancel(cancel)
        allowed(proceed,file,total,state,bytes,config,cancel,f => n => s => b => pump(left,f,n,s,b,config,cancel))

def opened(result: Result<&1,&1,U32 & String,File>,+config: Config,cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  match result:
    case Fail{_}: IO.pure(answer_type(),Fail{"image_file_open_error"})
    case Done{file}: pump(turn_limit(config),file,0,Heading{D.DecodeState{0,0,0,""},0},[],config,cancel)

def start(valid: Bool,path: String,config: Config,cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  match valid:
    case False{}: IO.pure(answer_type(),Fail{"image_file_limit"})
    case True{}:
      do IO<answer_type()>:
        result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
        opened(result,config,cancel)

# The variable read size supports boundary fixtures through the same IO/parser
# path. It cannot broaden the production 4096-byte or global output limits.
def read_bounded(expected: Header.Expected,path: String,+expected_bytes: U32,expected_digest: String,+read_size: U32,cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  start(U32.is_gt(expected_bytes,0) && U32.is_le(expected_bytes,Stream.max_output()) && U32.is_gt(read_size,0) && U32.is_le(read_size,4096),
    path,Config{expected,expected_bytes,expected_digest,read_size},cancel)

def read_checked(expected: Header.Expected,path: String,expected_bytes: U32,expected_digest: String,cancel: Maybe<&2,Chan(Unit)>) -> IO(answer_type()):
  read_bounded(expected,path,expected_bytes,expected_digest,4096,cancel)

def read(expected: Header.Expected,path: String,expected_bytes: U32,expected_digest: String) -> IO(answer_type()):
  read_checked(expected,path,expected_bytes,expected_digest,None{})
