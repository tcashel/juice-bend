import Base
import ./attachment_image_binding.bend as Header
import ./attachment_image_encode.bend as Legacy
import ./attachment_image_types.bend as Image
import ./attachment_image_decode.bend as Decode
import ./attachment_image_stream.bend as Stream
import ./domain.bend as D
import ./json.bend as J

# A disposable display transport, never the preserved attachment authority.
# Hash and hex work is bounded to 128 pixels. No complete raster String exists.
type Receipt is Data:
  Receipt{bytes: U32,digest: String}
type Hashing is Type:
  Hashing{pixels: Array<U32>,index: U32,hash: D.HashContext}
type Batch is Type:
  Batch{pixels: Array<U32>,index: U32,text: String}

def hash_value(pair: Array<U32> & U32,index: U32,hash: D.HashContext,next: Hashing -> Hashing) -> Hashing:
  (pixels,value) = pair
  next(Hashing{pixels,U32.inc(index),D.hash_bytes(Legacy.word_bytes(value),hash)})

def hash_chunk(fuel: Nat,value: Hashing) -> Hashing:
  match fuel:
    case 0n: value
    case 1n+rest:
      Hashing{pixels,+index,hash} = value
      hash_value(Array.get(U32,pixels,index),index,hash,v => hash_chunk(rest,v))

def hash_turn(done: Bool,count: U32,value: Hashing,next: Hashing -> IO(Array<U32> & String)) -> IO(Array<U32> & String):
  match done:
    case True{}:
      Hashing{pixels,_,hash} = value
      IO.pure(Array<U32> & String,(pixels,D.hash_finish(hash)))
    case False{}:
      Hashing{pixels,+index,hash} = value
      do IO<Array<U32> & String>:
        IO.sleep(0)
        next(hash_chunk(U32.to_nat(U32.min(128,U32.sub(count,index))),Hashing{pixels,index,hash}))

def hash_loop(fuel: Nat,+count: U32,value: Hashing) -> IO(Array<U32> & String):
  match fuel:
    case 0n: IO.die(Array<U32> & String,2,"image_spool_hash_limit")
    case 1n+left:
      Hashing{pixels,+index,hash} = value
      hash_turn(U32.is_ge(index,count),count,Hashing{pixels,index,hash},v => hash_loop(left,count,v))

def hash_all(count: U32,value: Hashing) -> IO(Array<U32> & String): hash_loop(8193n,count,value)

def hex_value(pair: Array<U32> & U32,index: U32,text: String,next: Batch -> Batch) -> Batch:
  (pixels,value) = pair
  next(Batch{pixels,U32.inc(index),String.reverse(D.hex_word(value)) ++ text})

def hex_chunk(fuel: Nat,value: Batch) -> Batch:
  match fuel:
    case 0n:
      Batch{pixels,index,text} = value
      Batch{pixels,index,String.reverse(text)}
    case 1n+rest:
      Batch{pixels,+index,text} = value
      hex_value(Array.get(U32,pixels,index),index,text,v => hex_chunk(rest,v))

def write_result(pair: File & Result<&1,&1,U32 & String,Unit>,next: File -> IO(File & Result<&2,&2,String,U32>)) -> IO(File & Result<&2,&2,String,U32>):
  (file,result) = pair
  match result:
    case Fail{_}: IO.pure(File & Result<&2,&2,String,U32>,(file,Fail{"image_spool_write_failed"}))
    case Done{_}: next(file)

# File.write_bytes handles short writes in upstream Base; every effect receives
# at most1024bytes. The final File.size independently checks the complete count.
def write_blocks(fuel: Nat,bytes: List<&2,U32>,file: File,count: U32) -> IO(File & Result<&2,&2,String,U32>):
  match fuel bytes:
    case _ Nil{}: IO.pure(File & Result<&2,&2,String,U32>,(file,Done{count}))
    case 0n _: IO.pure(File & Result<&2,&2,String,U32>,(file,Fail{"image_spool_write_limit"}))
    case 1n+left first <> rest:
      +all : List<&2,U32> = first <> rest
      +chunk = List.take(&2,U32,all,1024n)
      size = U32.from_nat(List.length(&2,U32,chunk))
      do IO<File & Result<&2,&2,String,U32>>:
        written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,chunk)
        write_result(written,f => write_blocks(left,List.drop(&2,U32,all,1024n),f,U32.add(count,size)))

def write_bytes(file: File,bytes: List<&2,U32>,count: U32) -> IO(File & Result<&2,&2,String,U32>):
  write_blocks(67n,bytes,file,count)

def emitted(pair: File & Result<&2,&2,String,U32>,pixels: Array<U32>,index: U32,next: File -> Array<U32> -> U32 -> U32 -> IO(File & Result<&2,&2,String,U32>)) -> IO(File & Result<&2,&2,String,U32>):
  (file,result) = pair
  match result:
    case Fail{message}: IO.pure(File & Result<&2,&2,String,U32>,(file,Fail{message}))
    case Done{bytes}: next(file,pixels,index,bytes)

def emit_batch(file: File,value: Batch,bytes: U32,next: File -> Array<U32> -> U32 -> U32 -> IO(File & Result<&2,&2,String,U32>)) -> IO(File & Result<&2,&2,String,U32>):
  Batch{pixels,index,text} = value
  do IO<File & Result<&2,&2,String,U32>>:
    written : File & Result<&2,&2,String,U32> <- write_bytes(file,D.encode(text),bytes)
    emitted(written,pixels,index,next)

def emit_turn(done: Bool,file: File,pixels: Array<U32>,+index: U32,count: U32,bytes: U32,next: File -> Array<U32> -> U32 -> U32 -> IO(File & Result<&2,&2,String,U32>)) -> IO(File & Result<&2,&2,String,U32>):
  match done:
    case True{}: IO.pure(File & Result<&2,&2,String,U32>,(file,Done{bytes}))
    case False{}:
      do IO<File & Result<&2,&2,String,U32>>:
        IO.sleep(0)
        emit_batch(file,hex_chunk(U32.to_nat(U32.min(128,U32.sub(count,index))),Batch{pixels,index,""}),bytes,next)

def emit_loop(fuel: Nat,file: File,pixels: Array<U32>,+index: U32,+count: U32,bytes: U32) -> IO(File & Result<&2,&2,String,U32>):
  match fuel:
    case 0n: IO.pure(File & Result<&2,&2,String,U32>,(file,Fail{"image_spool_pixel_limit"}))
    case 1n+left:
      emit_turn(U32.is_ge(index,count),file,pixels,index,count,bytes,f => p => i => b => emit_loop(left,f,p,i,count,b))

def emit_pixels(file: File,pixels: Array<U32>,index: U32,count: U32,bytes: U32) -> IO(File & Result<&2,&2,String,U32>):
  emit_loop(8193n,file,pixels,index,count,bytes)

def size_result(result: Result<&1,&1,U32 & String,U32>,expected: U32,digest: String) -> Result<&2,&2,String,Receipt>:
  match result:
    case Done{+actual}:
      Bool.pick(Result<&2,&2,String,Receipt>,U32.is_eq(actual,expected) && U32.is_le(actual,Stream.max_output()),Done{Receipt{actual,digest}},Fail{"image_spool_written_extent"})
    case Fail{_}: Fail{"image_spool_size_failed"}

def sized(pair: File & Result<&1,&1,U32 & String,U32>,expected: U32,digest: String) -> IO(Result<&2,&2,String,Receipt>):
  (file,result) = pair
  do IO<Result<&2,&2,String,Receipt>>:
    File.close(file)
    return size_result(result,expected,digest)

def finish(pair: File & Result<&2,&2,String,U32>,digest: String) -> IO(Result<&2,&2,String,Receipt>):
  (file,result) = pair
  match result:
    case Fail{message}:
      do IO<Result<&2,&2,String,Receipt>>:
        File.close(file)
        return Fail{message}
    case Done{count}:
      do IO<Result<&2,&2,String,Receipt>>:
        measured : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
        sized(measured,count,digest)

def header_written(pair: File & Result<&2,&2,String,U32>,pixels: Array<U32>,count: U32,digest: String) -> IO(Result<&2,&2,String,Receipt>):
  (file,result) = pair
  match result:
    case Fail{message}: finish((file,Fail{message}),digest)
    case Done{bytes}:
      do IO<Result<&2,&2,String,Receipt>>:
        written : File & Result<&2,&2,String,U32> <- emit_pixels(file,pixels,0,count,bytes)
        finish(written,digest)

def opened(result: Result<&1,&1,U32 & String,File>,header: String,pixels: Array<U32>,count: U32,digest: String) -> IO(Result<&2,&2,String,Receipt>):
  match result:
    case Fail{_}: IO.pure(Result<&2,&2,String,Receipt>,Fail{"image_spool_open_failed"})
    case Done{file}:
      do IO<Result<&2,&2,String,Receipt>>:
        written : File & Result<&2,&2,String,U32> <- write_bytes(file,D.encode(header ++ "\n"),0)
        header_written(written,pixels,count,digest)

def header_ready(value: Result<&2,&2,String,String>,path: String,pixels: Array<U32>,count: U32,digest: String) -> IO(Result<&2,&2,String,Receipt>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&2,String,Receipt>,Fail{message})
    case Done{header}:
      do IO<Result<&2,&2,String,Receipt>>:
        result : Result<&1,&1,U32 & String,File> <- File.open(path,"w")
        opened(result,header,pixels,count,digest)

def raster_hashed(pair: Array<U32> & String,binding: J.Json,path: String,w: U32,h: U32,+count: U32,capacity: U32,notice: Bool) -> IO(Result<&2,&2,String,Receipt>):
  (pixels,+digest) = pair
  header_ready(Header.success(binding,w,h,count,capacity,notice,digest),path,pixels,count,digest)

def raster_valid(valid: Bool,binding: J.Json,path: String,w: U32,h: U32,+count: U32,capacity: U32,pixels: Array<U32>,notice: Bool) -> IO(Result<&2,&2,String,Receipt>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Receipt>,Fail{"image_child_raster_limit"})
    case True{}:
      do IO<Result<&2,&2,String,Receipt>>:
        pair : Array<U32> & String <- hash_all(count,Hashing{pixels,0,D.HashContext{D.hash_initial(),[],0,0}})
        raster_hashed(pair,binding,path,w,h,count,capacity,notice)

def raster_sized(pair: Array<U32> & U32,binding: J.Json,path: String,w: U32,h: U32,count: U32,+capacity: U32,notice: Bool) -> IO(Result<&2,&2,String,Receipt>):
  (pixels,actual) = pair
  raster_valid(U32.is_eq(actual,capacity),binding,path,w,h,count,capacity,pixels,notice)

def raster_geometry(valid: Bool,binding: J.Json,path: String,w: U32,h: U32,count: U32,capacity: U32,pixels: Array<U32>,notice: Bool) -> IO(Result<&2,&2,String,Receipt>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Receipt>,Fail{"image_child_raster_limit"})
    case True{}: raster_sized(Array.size(U32,pixels),binding,path,w,h,count,capacity,notice)

def raster(binding: J.Json,path: String,value: Image.Raster) -> IO(Result<&2,&2,String,Receipt>):
  Image.Raster{+w,+h,+count,+capacity,pixels,notice} = value
  raster_geometry(Header.geometry(w,h,count,capacity),binding,path,w,h,count,capacity,pixels,notice)

def decoded(binding: J.Json,path: String,value: Result<&2,&1,String,Image.Raster>) -> IO(Result<&2,&2,String,Receipt>):
  match value:
    case Fail{message}: header_ready(Header.failure(binding,message),path,ALeaf{0},0,"none")
    case Done{value}: raster(binding,path,value)

def encode(binding: J.Json,path: String,bytes: List<&2,U32>) -> IO(Result<&2,&2,String,Receipt>):
  decoded(binding,path,Decode.decode(bytes))
