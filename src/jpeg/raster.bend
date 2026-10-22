import Base
import ./types.bend as T
import ./headers.bend as Headers
import ./tables.bend as Tables
import ./entropy.bend as Entropy
import ./pixels.bend as Pixels
import ../attachment_image_types.bend as Image

type Job is Data:
  Job{plane: U32,x: U32,y: U32,stride: U32,quant: List<&2,U32>,dc: T.Huffman,ac: T.Huffman}
type Mcu is Type:
  Mcu{cursor: Entropy.Cursor,predictors: Array<F32>,samples: Array<U32>}
type Painted is Type:
  Painted{samples: Array<U32>,pixels: Array<U32>}
type Advanced is Type:
  Advanced{mcu: Mcu,pixels: Array<U32>}
type Prepared is Data:
  Prepared{frame: T.Frame,jobs: List<&2,Job>,interval: U32,entropy: List<&2,U32>,mode: T.ColorMode,notice: Bool}

def plane(items: List<&2,T.Component>,+id: U32,+index: U32) -> Result<&2,&2,T.Failure,U32>:
  match items:
    case []: Fail{T.Failure{"invalid_jpeg","JPEG scan component has no output plane"}}
    case T.Component{key,_,_,_} <> rest:
      T.branch(Result<&2,&2,T.Failure,U32>,U32.is_eq(key,id),_ => Done{index},_ => plane(rest,id,U32.inc(index)))

def component_jobs(fuel: Nat,+index: U32,+target: U32,+h: U32,+quant: List<&2,U32>,+dc: T.Huffman,+ac: T.Huffman) -> List<&2,Job>:
  match fuel:
    case 0n: []
    case 1n+rest:
      Job{target,U32.mul(U32.mod(index,h),8),U32.mul(U32.div(index,h),8),U32.mul(h,8),quant,dc,ac} <>
        component_jobs(rest,U32.inc(index),target,h,quant,dc,ac)

def jobs(scan: List<&2,T.ScanComponent>,+components: List<&2,T.Component>,+quants: List<&2,T.Quantizer>,+tables: List<&2,T.Table>) -> Result<&2,&2,T.Failure,List<&2,Job>>:
  match scan:
    case []: Done{[]}
    case T.ScanComponent{T.Component{id,+h,v,key},dc,ac} <> rest:
      do Result<&2,&2,T.Failure,List<&2,Job>>:
        target : U32 <- plane(components,id,0)
        quant : List<&2,U32> <- Tables.quant_get(quants,key)
        dctable : T.Huffman <- Tables.huffman_get(tables,0,dc)
        actable : T.Huffman <- Tables.huffman_get(tables,1,ac)
        tail : List<&2,Job> <- jobs(rest,components,quants,tables)
        Done{List.append(&2,Job,component_jobs(U32.to_nat(U32.mul(h,v)),0,target,h,quant,dctable,actable),tail)}

def copied(pair: Array<U32> & U32,samples: Array<U32>,target: U32,next: Array<U32> -> Array<U32> -> Result<&2,&1,T.Failure,Array<U32>>) -> Result<&2,&1,T.Failure,Array<U32>>:
  (block,value) = pair
  next(block,Array.set(U32,samples,target,value))

def copy_block(fuel: Nat,block: Array<U32>,samples: Array<U32>,+index: U32,+base: U32,+x: U32,+y: U32,+stride: U32) -> Result<&2,&1,T.Failure,Array<U32>>:
  match fuel:
    case 0n: Done{samples}
    case 1n+rest:
      +target : U32 = U32.add(base,U32.add(U32.mul(U32.add(y,U32.div(index,8)),stride),U32.add(x,U32.mod(index,8))))
      do Result<&2,&1,T.Failure,Array<U32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64) && U32.is_lt(target,1024),"image_resource_limit","JPEG block copy exceeds its allocated MCU"))
        copied(Array.get(U32,block,index),samples,target,after => updated => copy_block(rest,after,updated,U32.inc(index),base,x,y,stride))

def decoded(value: Entropy.Decoded,predictors: Array<F32>,samples: Array<U32>,job: Job) -> Result<&2,&1,T.Failure,Mcu>:
  Entropy.Decoded{cursor,dc,coefficients} = value
  Job{+target,x,y,stride,quant,_,_} = job
  do Result<&2,&1,T.Failure,Mcu>:
    block : Array<U32> <- Pixels.block(coefficients,quant)
    updated : Array<U32> <- copy_block(64n,block,samples,0,U32.mul(target,256),x,y,stride)
    Done{Mcu{cursor,Array.set(F32,predictors,target,dc),updated}}

def predicted(pair: Array<F32> & F32,cursor: Entropy.Cursor,samples: Array<U32>,+job: Job) -> Result<&2,&1,T.Failure,Mcu>:
  (predictors,prior) = pair
  Job{_,_,_,_,_,dc,ac} = job
  do Result<&2,&1,T.Failure,Mcu>:
    value : Entropy.Decoded <- Entropy.block(cursor,dc,ac,prior)
    decoded(value,predictors,samples,job)

def one(mcu: Mcu,+job: Job) -> Result<&2,&1,T.Failure,Mcu>:
  Mcu{cursor,predictors,samples} = mcu
  Job{+target,_,_,_,_,_,_} = job
  do Result<&2,&1,T.Failure,Mcu>:
    _ : Unit <- T.widen(Unit,T.require(U32.is_lt(target,3),"image_resource_limit","JPEG predictor index exceeds its fixed array"))
    predicted(Array.get(F32,predictors,target),cursor,samples,job)

def blocks(jobs: List<&2,Job>,mcu: Mcu) -> Result<&2,&1,T.Failure,Mcu>:
  match jobs:
    case []: Done{mcu}
    case job <> rest:
      do Result<&2,&1,T.Failure,Mcu>:
        value : Mcu <- one(mcu,job)
        blocks(rest,value)

def opaque(+value: U32) -> U32:
  Image.rgba(value,value,value,255)

def final_color(mode: T.ColorMode,y: U32,cb: U32,cr: U32) -> U32:
  match mode:
    case T.Gray{}: opaque(y)
    case T.YCbCr{}: Pixels.rgb(y,cb,cr)
    case T.RGB{}: Image.rgba(y,cb,cr,255)

def color_third(pair: Array<U32> & U32,mode: T.ColorMode,y: U32,cb: U32) -> Array<U32> & U32:
  (samples,cr) = pair
  (samples,final_color(mode,y,cb,cr))

def color_second(pair: Array<U32> & U32,mode: T.ColorMode,y: U32,third: U32) -> Array<U32> & U32:
  (samples,cb) = pair
  color_third(Array.get(U32,samples,third),mode,y,cb)

def color_first(pair: Array<U32> & U32,mode: T.ColorMode,+index: U32) -> Array<U32> & U32:
  (samples,+y) = pair
  match mode:
    case T.Gray{}: (samples,opaque(y))
    case other: color_second(Array.get(U32,samples,U32.add(256,index)),other,y,U32.add(512,index))

def put_color(pair: Array<U32> & U32,pixels: Array<U32>,target: U32,next: Array<U32> -> Array<U32> -> Result<&2,&1,T.Failure,Painted>) -> Result<&2,&1,T.Failure,Painted>:
  (samples,value) = pair
  next(samples,Array.set(U32,pixels,target,value))

def paint_one(inside: Bool,samples: Array<U32>,pixels: Array<U32>,+local: U32,+mw: U32,+h: U32,+v: U32,+target: U32,count: U32,mode: T.ColorMode,next: Array<U32> -> Array<U32> -> Result<&2,&1,T.Failure,Painted>) -> Result<&2,&1,T.Failure,Painted>:
  match inside:
    case False{}: next(samples,pixels)
    case True{}:
      +x : U32 = U32.mod(local,mw)
      +y : U32 = U32.div(local,mw)
      +chroma : U32 = U32.add(U32.mul(U32.div(y,v),8),U32.div(x,h))
      do Result<&2,&1,T.Failure,Painted>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(local,256) && U32.is_lt(chroma,64) && U32.is_lt(target,count),"image_resource_limit","JPEG sample or output index exceeds its allocated image"))
        put_color(color_first(Array.get(U32,samples,local),mode,chroma),pixels,target,next)

def paint(fuel: Nat,samples: Array<U32>,pixels: Array<U32>,+local: U32,+x0: U32,+y0: U32,+width: U32,+height: U32,+h: U32,+v: U32,+mode: T.ColorMode) -> Result<&2,&1,T.Failure,Painted>:
  match fuel:
    case 0n: Done{Painted{samples,pixels}}
    case 1n+rest:
      +mw : U32 = U32.mul(h,8)
      +x : U32 = U32.add(x0,U32.mod(local,mw))
      +y : U32 = U32.add(y0,U32.div(local,mw))
      paint_one(U32.is_lt(x,width) && U32.is_lt(y,height),samples,pixels,local,mw,h,v,U32.add(U32.mul(y,width),x),U32.mul(width,height),mode,
        after => updated => paint(rest,after,updated,U32.inc(local),x0,y0,width,height,h,v,mode))

def maybe_restart(needed: Bool,mcu: Mcu,index: U32) -> Result<&2,&1,T.Failure,Mcu>:
  match needed:
    case False{}: Done{mcu}
    case True{}:
      Mcu{cursor,_,samples} = mcu
      do Result<&2,&1,T.Failure,Mcu>:
        after : Entropy.Cursor <- T.widen(Entropy.Cursor,Entropy.restart(cursor,index))
        Done{Mcu{after,Array.new(F32,2n,0.0),samples}}

def painted(value: Painted,cursor: Entropy.Cursor,predictors: Array<F32>) -> Result<&2,&1,T.Failure,Advanced>:
  Painted{samples,pixels} = value
  Done{Advanced{Mcu{cursor,predictors,samples},pixels}}

def draw(mcu: Mcu,pixels: Array<U32>,+index: U32,frame: T.Frame,mode: T.ColorMode) -> Result<&2,&1,T.Failure,Advanced>:
  Mcu{cursor,predictors,samples} = mcu
  T.Frame{+width,+height,_,+h,+v,+columns,_} = frame
  do Result<&2,&1,T.Failure,Advanced>:
    value : Painted <- paint(U32.to_nat(U32.mul(U32.mul(h,v),64)),samples,pixels,0,U32.mul(U32.mod(index,columns),U32.mul(h,8)),U32.mul(U32.div(index,columns),U32.mul(v,8)),width,height,h,v,mode)
    painted(value,cursor,predictors)

def unpack(-R: Type,value: Advanced,next: Mcu -> Array<U32> -> R) -> R:
  Advanced{mcu,pixels} = value
  next(mcu,pixels)

# Both pure and cooperative rendering use this exact transition. Restart marker
# fill remains a synchronous scan bounded by the admitted one-MiB input.
def step(mcu: Mcu,pixels: Array<U32>,+index: U32,frame: T.Frame,jobs: List<&2,Job>,+interval: U32,mode: T.ColorMode) -> Result<&2,&1,T.Failure,Advanced>:
  +needed : Bool = U32.is_gt(index,0) && U32.is_gt(interval,0) && U32.is_eq(U32.mod(index,interval),0)
  +restart_index : U32 = U32.and(U32.sub(U32.div(index,interval),1),7)
  do Result<&2,&1,T.Failure,Advanced>:
    ready : Mcu <- maybe_restart(needed,mcu,restart_index)
    decoded : Mcu <- blocks(jobs,ready)
    draw(decoded,pixels,index,frame,mode)

def finish(mcu: Mcu,pixels: Array<U32>,frame: T.Frame,notice: Bool) -> Result<&2,&1,T.Failure,Image.Raster>:
  Mcu{cursor,_,_} = mcu
  T.Frame{+width,+height,_,_,_,_,_} = frame
  +count : U32 = U32.mul(width,height)
  do Result<&2,&1,T.Failure,Image.Raster>:
    _ : Unit <- T.widen(Unit,Entropy.finish(cursor))
    Done{Image.Raster{width,height,count,U32.shln(1,T.depth(count)),pixels,notice}}

def mcus(fuel: Nat,mcu: Mcu,pixels: Array<U32>,+index: U32,+frame: T.Frame,+jobs: List<&2,Job>,+interval: U32,+mode: T.ColorMode,+notice: Bool) -> Result<&2,&1,T.Failure,Image.Raster>:
  match fuel:
    case 0n: finish(mcu,pixels,frame,notice)
    case 1n+rest:
      do Result<&2,&1,T.Failure,Image.Raster>:
        advanced : Advanced <- step(mcu,pixels,index,frame,jobs,interval,mode)
        unpack(Result<&2,&1,T.Failure,Image.Raster>,advanced,after => updated => mcus(rest,after,updated,U32.inc(index),frame,jobs,interval,mode,notice))

def prepare(document: T.Document) -> Result<&2,&2,T.Failure,Prepared>:
  T.Document{+frame,scan,quants,tables,interval,entropy,mode,notice} = document
  T.Frame{+width,+height,components,_,_,_,_} = frame
  do Result<&2,&2,T.Failure,Prepared>:
    _ : Unit <- T.require(U32.is_gt(width,0) && U32.is_gt(height,0) && U32.is_le(width,T.max_dimension()) && U32.is_le(height,T.max_dimension()) && U32.is_le(width,U32.div(T.max_pixels(),height)),"image_resource_limit","JPEG raster dimensions exceed the bounded allocation profile")
    jobs : List<&2,Job> <- jobs(scan,components,quants,tables)
    Done{Prepared{frame,jobs,interval,entropy,mode,notice}}

# The pinned native Array.new fills its allocation synchronously. The output
# has at most 1,048,576 cells; this is not a per-MCU cooperative operation.
def initial(frame: T.Frame,entropy: List<&2,U32>) -> Advanced:
  T.Frame{width,height,_,_,_,_,_} = frame
  Advanced{Mcu{Entropy.start(entropy),Array.new(F32,2n,0.0),Array.new(U32,10n,0)},Array.new(U32,T.depth(U32.mul(width,height)),0)}

def render_prepared(value: Prepared) -> Result<&2,&1,T.Failure,Image.Raster>:
  Prepared{+frame,jobs,interval,entropy,mode,notice} = value
  T.Frame{_,_,_,_,_,columns,rows} = frame
  unpack(Result<&2,&1,T.Failure,Image.Raster>,initial(frame,entropy),mcu => pixels =>
    mcus(U32.to_nat(U32.mul(columns,rows)),mcu,pixels,0,frame,jobs,interval,mode,notice))

def render(document: T.Document) -> Result<&2,&1,T.Failure,Image.Raster>:
  do Result<&2,&1,T.Failure,Image.Raster>:
    value : Prepared <- T.widen(Prepared,prepare(document))
    render_prepared(value)
