import Base
import ./types.bend as T
import ./input.bend as Input
import ./headers.bend as Headers
import ./tables.bend as Tables
import ./metadata.bend as Metadata

type State is Data:
  State{frame: Maybe<&2,T.Frame>,quants: List<&2,T.Quantizer>,tables: List<&2,T.Table>,restart: U32,jfif: Bool,adobe: Maybe<&2,U32>,notice: Bool}

def frame_once(prior: Maybe<&2,T.Frame>,value: T.Frame) -> Result<&2,&2,T.Failure,Maybe<&2,T.Frame>>:
  match prior:
    case None{}: Done{Some{value}}
    case Some{_}: Fail{T.Failure{"invalid_jpeg","JPEG contains more than one frame header"}}

def adobe_once(prior: Maybe<&2,U32>,value: Maybe<&2,U32>) -> Result<&2,&2,T.Failure,Maybe<&2,U32>>:
  match prior value:
    case before None{}: Done{before}
    case None{} after: Done{after}
    case _ _: Fail{T.Failure{"invalid_jpeg","JPEG contains duplicate Adobe color markers"}}

def restart(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,U32>:
  match bytes:
    case [a,b]: Done{Input.word(a,b)}
    case _: Fail{T.Failure{"invalid_jpeg","JPEG restart interval must contain two bytes"}}

def ancillary_metadata(code: U32,bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Unit>:
  match code:
    case 225: Metadata.exif(bytes)
    case _: Done{Unit{}}

def ancillary(+code: U32,bytes: List<&2,U32>,state: State) -> Result<&2,&2,T.Failure,State>:
  do Result<&2,&2,T.Failure,State>:
    _ : Unit <- T.require((U32.is_ge(code,224) && U32.is_le(code,239)) || U32.is_eq(code,254),"unsupported_jpeg_mode","JPEG marker mode is not yet supported")
    _ : Unit <- ancillary_metadata(code,bytes)
    Done{state}

def update(state: State,code: U32,+bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,State>:
  State{frame,quants,tables,interval,+jfif,adobe,notice} = state
  match code:
    case 192:
      do Result<&2,&2,T.Failure,State>:
        value : T.Frame <- Headers.frame(bytes)
        updated : Maybe<&2,T.Frame> <- frame_once(frame,value)
        Done{State{updated,quants,tables,interval,jfif,adobe,notice}}
    case 194: Fail{T.Failure{"unsupported_jpeg_progressive","Progressive JPEG display is not yet implemented"}}
    case 219:
      do Result<&2,&2,T.Failure,State>:
        _ : Unit <- T.require(Bool.not(List.is_empty(&2,U32,bytes)),"invalid_jpeg","JPEG quantization segment is empty")
        updated : List<&2,T.Quantizer> <- Tables.quant_tables(1024n,bytes,quants)
        Done{State{frame,updated,tables,interval,jfif,adobe,notice}}
    case 196:
      do Result<&2,&2,T.Failure,State>:
        _ : Unit <- T.require(Bool.not(List.is_empty(&2,U32,bytes)),"invalid_jpeg","JPEG Huffman segment is empty")
        updated : List<&2,T.Table> <- Tables.huffman_tables(1024n,bytes,tables)
        Done{State{frame,quants,updated,interval,jfif,adobe,notice}}
    case 221:
      do Result<&2,&2,T.Failure,State>:
        value : U32 <- restart(bytes)
        Done{State{frame,quants,tables,value,jfif,adobe,notice}}
    case 224:
      do Result<&2,&2,T.Failure,State>:
        +found : Bool <- Metadata.jfif(bytes)
        _ : Unit <- T.require(Bool.not(found && jfif),"invalid_jpeg","JPEG contains duplicate JFIF markers")
        Done{State{frame,quants,tables,interval,found || jfif,adobe,notice}}
    case 238:
      do Result<&2,&2,T.Failure,State>:
        value : Maybe<&2,U32> <- Metadata.adobe(bytes)
        updated : Maybe<&2,U32> <- adobe_once(adobe,value)
        Done{State{frame,quants,tables,interval,jfif,updated,True{}}}
    case other: ancillary(other,bytes,State{frame,quants,tables,interval,jfif,adobe,True{}})

def document_frame(frame: Maybe<&2,T.Frame>,bytes: List<&2,U32>,+quants: List<&2,T.Quantizer>,+tables: List<&2,T.Table>,interval: U32,jfif: Bool,adobe: Maybe<&2,U32>,notice: Bool,entropy: List<&2,U32>) -> Result<&2,&2,T.Failure,T.Document>:
  match frame:
    case None{}: Fail{T.Failure{"invalid_jpeg","JPEG scan precedes its frame header"}}
    case Some{+frame}:
      do Result<&2,&2,T.Failure,T.Document>:
        scan : List<&2,T.ScanComponent> <- Headers.scan(bytes,frame,quants,tables)
        color : T.ColorMode <- Headers.color(frame,jfif,adobe)
        Done{T.Document{frame,scan,quants,tables,interval,entropy,color,notice}}

def document(state: State,bytes: List<&2,U32>,entropy: List<&2,U32>) -> Result<&2,&2,T.Failure,T.Document>:
  State{frame,quants,tables,interval,jfif,adobe,notice} = state
  document_frame(frame,bytes,quants,tables,interval,jfif,adobe,notice,entropy)

def part(code: U32,state: State,value: Input.Part,next: State -> List<&2,U32> -> Result<&2,&2,T.Failure,T.Document>) -> Result<&2,&2,T.Failure,T.Document>:
  match code:
    case 218:
      Input.Part{bytes,tail} = value
      document(state,bytes,tail)
    case other:
      Input.Part{bytes,tail} = value
      do Result<&2,&2,T.Failure,T.Document>:
        updated : State <- update(state,other,bytes)
        next(updated,tail)

def marked(value: Input.Marker,state: State,next: State -> List<&2,U32> -> Result<&2,&2,T.Failure,T.Document>) -> Result<&2,&2,T.Failure,T.Document>:
  Input.Marker{+code,tail} = value
  do Result<&2,&2,T.Failure,T.Document>:
    _ : Unit <- T.require(U32.is_ne(code,216) && U32.is_ne(code,217) && U32.is_ne(code,1) && Bool.not(U32.is_ge(code,208) && U32.is_le(code,215)),"invalid_jpeg","Unexpected standalone JPEG marker before its scan")
    value : Input.Part <- Input.segment(tail)
    part(code,state,value,next)

def walk(fuel: Nat,state: State,bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,T.Document>:
  match fuel:
    case 0n: Fail{T.Failure{"image_resource_limit","JPEG marker count exceeds the display bound"}}
    case 1n+rest:
      do Result<&2,&2,T.Failure,T.Document>:
        value : Input.Marker <- Input.marker(bytes)
        marked(value,state,updated => tail => walk(rest,updated,tail))

def signature(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,T.Document>:
  match bytes:
    case 255 <> 216 <> tail: walk(U32.to_nat(T.max_segments()),State{None{},[],[],0,False{},None{},False{}},tail)
    case _: Fail{T.Failure{"unsupported_image_format","Retained bytes are not a JPEG image"}}

def decode(+bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,T.Document>:
  do Result<&2,&2,T.Failure,T.Document>:
    _ : U32 <- Input.admitted(bytes,0)
    signature(bytes)
