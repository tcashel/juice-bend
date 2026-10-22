import Base
import ./attachment_image_binding.bend as Header
import ./attachment_image_types.bend as Image
import ./attachment_preview_packet.bend as Hex
import ./domain.bend as D

# One line of closed metadata, then exactly eight lowercase hex characters per
# row-major RGBA pixel. No final newline or other suffix is accepted. This is
# parent-side admission only: it never reads a file, URL or original source.
def max_output() -> U32: 8454145
def header_limit() -> U32: 65536
def pixel_chunk() -> Nat: 128n

type HeadStep is Data:
  HeadMore{rest: String,reversed: String,used: U32}
  HeadDone{header: String,body: String}
  HeadBad{message: String}
type PixelWord is Data:
  PixelWord{rest: String,value: U32}
type Branch is Type:
  Branch{span: U32,pixels: Array<U32>}
type Extent is Data:
  Extent{width: U32,height: U32,count: U32,capacity: U32,notice: Bool,digest: String}
type Receiving is Type:
  Receiving{header: Extent,index: U32,tail: String,hash: D.HashContext,stack: List<&1,Branch>}
type Step is Type:
  Continuing{value: Receiving}
  Finished{value: Result<&2,&1,String,Image.Raster>}

def utf8(+cp: U32) -> U32:
  Bool.pick(U32,U32.is_lt(cp,128),1,Bool.pick(U32,U32.is_lt(cp,2048),2,Bool.pick(U32,U32.is_lt(cp,65536),3,4)))

def head_char(valid: Bool,cp: U32,rest: String,acc: String,used: U32,next: String -> String -> U32 -> HeadStep) -> HeadStep:
  match valid:
    case False{}: HeadBad{"image_header_limit_or_encoding"}
    case True{}: next(rest,SCon{Chr{cp},acc},used)

def head(fuel: Nat,text: String,acc: String,+used: U32) -> HeadStep:
  match fuel text:
    case _ SNil{}: HeadBad{"image_header_missing_separator"}
    case _ SCon{'\n',rest}: HeadDone{String.reverse(acc),rest}
    case 0n rest: HeadMore{rest,acc,used}
    case 1n+left SCon{Chr{+cp},rest}:
      +size : U32 = utf8(cp)
      head_char(U32.is_le(cp,1114111) && (U32.is_lt(cp,55296) || U32.is_gt(cp,57343)) &&
        U32.is_le(used,header_limit()) && U32.is_le(size,U32.sub(header_limit(),used)),cp,rest,acc,U32.add(used,size),r => a => u => head(left,r,a,u))

def checked_digit(valid: Bool,cp: U32,value: U32) -> Result<&2,&2,String,U32>:
  match valid:
    case False{}: Fail{"image_pixel_invalid_hex"}
    case True{}: Done{U32.or(U32.shln(value,4n),Hex.nibble(cp))}

def hex_digit(+cp: U32,value: U32) -> Result<&2,&2,String,U32>:
  checked_digit(Hex.lower_hex(cp),cp,value)

def word_digit(digit: Result<&2,&2,String,U32>,rest: String,next: String -> U32 -> Result<&2,&2,String,PixelWord>) -> Result<&2,&2,String,PixelWord>:
  match digit:
    case Fail{message}: Fail{message}
    case Done{value}: next(rest,value)

def word(fuel: Nat,text: String,value: U32) -> Result<&2,&2,String,PixelWord>:
  match fuel text:
    case 0n rest: Done{PixelWord{rest,value}}
    case 1n+left SCon{Chr{+cp},rest}:
      word_digit(hex_digit(cp,value),rest,r => v => word(left,r,v))
    case _ _: Fail{"image_pixel_length_mismatch"}

# A binary-counter stack builds only equal-height Array nodes. There is no
# eager million-element Array.new before the first cooperative yield.
def joined(equal: Bool,left: Branch,right: Branch,rest: List<&1,Branch>,next: Branch -> List<&1,Branch> -> Result<&2,&1,String,List<&1,Branch>>) -> Result<&2,&1,String,List<&1,Branch>>:
  match equal:
    case False{}: Done{right <> left <> rest}
    case True{}:
      Branch{span,a} = left
      Branch{_,b} = right
      next(Branch{U32.mul(span,2),ANode{a,b}},rest)

def push(fuel: Nat,stack: List<&1,Branch>,branch: Branch) -> Result<&2,&1,String,List<&1,Branch>>:
  match fuel stack:
    case _ Nil{}: Done{[branch]}
    case 0n _: Fail{"image_array_stack_limit"}
    case 1n+left first <> rest:
      Branch{+prior,old} = first
      Branch{+span,pixels} = branch
      joined(U32.is_eq(span,prior),Branch{prior,old},Branch{span,pixels},rest,b => s => push(left,s,b))

def bytes(+value: U32) -> List<&2,U32>:
  [Image.component(value,24n),Image.component(value,16n),Image.component(value,8n),Image.component(value,0n)]

def added(result: Result<&2,&1,String,List<&1,Branch>>,header: Extent,index: U32,tail: String,hash: D.HashContext,next: Receiving -> Step) -> Step:
  match result:
    case Fail{message}: Finished{Fail{message}}
    case Done{stack}: next(Receiving{header,U32.inc(index),tail,hash,stack})

def got(value: Result<&2,&2,String,PixelWord>,header: Extent,index: U32,hash: D.HashContext,stack: List<&1,Branch>,next: Receiving -> Step) -> Step:
  match value:
    case Fail{message}: Finished{Fail{message}}
    case Done{PixelWord{tail,+pixel}}:
      added(push(21n,stack,Branch{1,ALeaf{pixel}}),header,index,tail,D.hash_bytes(bytes(pixel),hash),next)

def finish_array(valid: Bool,w: U32,h: U32,count: U32,capacity: U32,notice: Bool,pixels: Array<U32>) -> Step:
  match valid:
    case True{}: Finished{Done{Image.Raster{w,h,count,capacity,pixels,notice}}}
    case False{}: Finished{Fail{"image_array_capacity_mismatch"}}

def finish_stack(valid: Bool,header: Extent,stack: List<&1,Branch>) -> Step:
  match valid header stack:
    case True{} Extent{w,h,count,+capacity,notice,_} Branch{span,pixels} <> Nil{}:
      finish_array(U32.is_eq(span,capacity),w,h,count,capacity,notice,pixels)
    case _ _ _: Finished{Fail{"image_pixel_digest_or_array_mismatch"}}

def finish(tail: String,hash: D.HashContext,header: Extent,stack: List<&1,Branch>) -> Step:
  match tail:
    case SNil{}:
      Extent{w,h,count,capacity,notice,+digest} = header
      finish_stack(String.eq(D.hash_finish(hash),digest),Extent{w,h,count,capacity,notice,digest},stack)
    case _: Finished{Fail{"image_pixel_trailing_data"}}

def padding(tail: String,header: Extent,index: U32,hash: D.HashContext,stack: List<&1,Branch>,next: Receiving -> Step) -> Step:
  match tail:
    case SNil{}: added(push(21n,stack,Branch{1,ALeaf{0}}),header,index,"",hash,next)
    case _: Finished{Fail{"image_pixel_trailing_data"}}

def pixel_mode(mode: U32,header: Extent,index: U32,tail: String,hash: D.HashContext,stack: List<&1,Branch>,next: Receiving -> Step) -> Step:
  match mode:
    case 0: got(word(8n,tail,0),header,index,hash,stack,next)
    case 1: padding(tail,header,index,hash,stack,next)
    case _: finish(tail,hash,header,stack)

def chunk(fuel: Nat,value: Receiving) -> Step:
  match fuel:
    case 0n: Continuing{value}
    case 1n+left:
      Receiving{header,+index,tail,hash,stack} = value
      Extent{w,h,+count,+capacity,notice,digest} = header
      pixel_mode(Bool.pick(U32,U32.is_lt(index,count),0,Bool.pick(U32,U32.is_lt(index,capacity),1,2)),
        Extent{w,h,count,capacity,notice,digest},index,tail,hash,stack,s => chunk(left,s))

# Every 128 decoded/padded pixels includes at most 1024 hex validations,
# eight SHA-256 blocks, and 128 bounded-depth Array insertions. Yield before
# the next chunk. There is no whole-wire pre-scan, rehash or Array fill.
def consume_step(fuel: Nat,step: Step) -> IO(Result<&2,&1,String,Image.Raster>):
  match fuel step:
    case _ Finished{value}: IO.pure(Result<&2,&1,String,Image.Raster>,value)
    case 0n _: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"image_pixel_chunk_limit"})
    case 1n+left Continuing{value}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        IO.sleep(0)
        consume_step(left,chunk(pixel_chunk(),value))

def failure_body(body: String,message: String) -> IO(Result<&2,&1,String,Image.Raster>):
  match body:
    case SNil{}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{message})
    case _: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"image_failure_trailing_data"})

def admitted(header: Result<&2,&2,String,Header.Header>,body: String) -> IO(Result<&2,&1,String,Image.Raster>):
  match header:
    case Fail{message}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{message})
    case Done{Header.FailureHeader{message}}: failure_body(body,message)
    case Done{Header.PixelsHeader{w,h,count,capacity,notice,digest}}:
      consume_step(8193n,Continuing{Receiving{Extent{w,h,count,capacity,notice,digest},0,body,D.HashContext{D.hash_initial(),[],0,0},[]}})

def scan_step(fuel: Nat,expected: Header.Expected,step: HeadStep) -> IO(Result<&2,&1,String,Image.Raster>):
  match fuel step:
    case _ HeadBad{message}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{message})
    case _ HeadDone{header,body}: admitted(Header.verify(expected,header),body)
    case 0n _: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"image_header_chunk_limit"})
    case 1n+left HeadMore{rest,acc,used}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        IO.sleep(0)
        scan_step(left,expected,head(256n,rest,acc,used))

def read(expected: Header.Expected,text: String) -> IO(Result<&2,&1,String,Image.Raster>):
  scan_step(257n,expected,HeadMore{text,"",0})
