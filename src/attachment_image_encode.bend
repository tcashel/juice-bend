import Base
import ./attachment_image_binding.bend as Header
import ./attachment_image_types.bend as Image
import ./attachment_image_decode.bend as Decode
import ./domain.bend as D
import ./json.bend as J

# Executed only inside the supervised read-only image child. The original
# verified bytes are retained/exported elsewhere; this packet is display data.
type Packed is Data:
  Packed{hex: String,digest: String}

def word_bytes(+pixel: U32) -> List<&2,U32>:
  [Image.component(pixel,24n),Image.component(pixel,16n),Image.component(pixel,8n),Image.component(pixel,0n)]

def packed(pair: Array<U32> & U32,hash: D.HashContext,text: String,next: Array<U32> -> D.HashContext -> String -> Packed) -> Packed:
  (pixels,+pixel) = pair
  next(pixels,D.hash_bytes(word_bytes(pixel),hash),String.reverse(D.hex_word(pixel)) ++ text)

def pixels_hex(fuel: Nat,pixels: Array<U32>,+index: U32,hash: D.HashContext,text: String) -> Packed:
  match fuel:
    case 0n: Packed{String.reverse(text),D.hash_finish(hash)}
    case 1n+left: packed(Array.get(U32,pixels,index),hash,text,p => h => t => pixels_hex(left,p,U32.inc(index),h,t))

def publish(binding: J.Json,w: U32,h: U32,count: U32,capacity: U32,notice: Bool,packed: Packed) -> Result<&2,&2,String,String>:
  Packed{hex,digest} = packed
  do Result<&2,&2,String,String>:
    header : String <- Header.success(binding,w,h,count,capacity,notice,digest)
    Done{header ++ "\n" ++ hex}

def array_size(valid: Bool,binding: J.Json,w: U32,h: U32,+count: U32,capacity: U32,notice: Bool,pixels: Array<U32>) -> Result<&2,&2,String,String>:
  match valid:
    case False{}: Fail{"image_child_array_extent"}
    case True{}: publish(binding,w,h,count,capacity,notice,pixels_hex(U32.to_nat(count),pixels,0,D.HashContext{D.hash_initial(),[],0,0},""))

def sized(binding: J.Json,w: U32,h: U32,count: U32,+capacity: U32,notice: Bool,pair: Array<U32> & U32) -> Result<&2,&2,String,String>:
  (pixels,actual) = pair
  array_size(U32.is_eq(actual,capacity),binding,w,h,count,capacity,notice,pixels)

def extent(valid: Bool,binding: J.Json,w: U32,h: U32,count: U32,capacity: U32,notice: Bool,pixels: Array<U32>) -> Result<&2,&2,String,String>:
  match valid:
    case False{}: Fail{"image_child_raster_limit"}
    case True{}: sized(binding,w,h,count,capacity,notice,Array.size(U32,pixels))

def raster(binding: J.Json,value: Image.Raster) -> Result<&2,&2,String,String>:
  Image.Raster{+w,+h,+count,+capacity,pixels,notice} = value
  extent(U32.is_gt(w,0) && U32.is_gt(h,0) && U32.is_le(w,Image.max_dimension()) && U32.is_le(h,Image.max_dimension()) &&
    U32.is_eq(count,U32.mul(w,h)) && U32.is_le(count,Image.max_pixels()) &&
    U32.is_eq(capacity,U32.shln(1,Image.depth(count))) && U32.is_le(capacity,Image.max_pixels()),binding,w,h,count,capacity,notice,pixels)

def decoded(binding: J.Json,value: Result<&2,&1,String,Image.Raster>) -> Result<&2,&2,String,String>:
  match value:
    case Fail{message}:
      do Result<&2,&2,String,String>:
        header : String <- Header.failure(binding,message)
        Done{header ++ "\n"}
    case Done{value}: raster(binding,value)

def encode(binding: J.Json,bytes: List<&2,U32>) -> Result<&2,&2,String,String>:
  decoded(binding,Decode.decode(bytes))
