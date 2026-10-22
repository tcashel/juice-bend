import Base
import ./types.bend as T
import ./input.bend as Input
import ./tables.bend as Tables

def contains(items: List<&2,T.Component>,+id: U32) -> Bool:
  match items:
    case []: False{}
    case T.Component{key,_,_,_} <> rest: U32.is_eq(key,id) || contains(rest,id)

def components(fuel: Nat,bytes: List<&2,U32>,+rev: List<&2,T.Component>) -> Result<&2,&2,T.Failure,List<&2,T.Component>>:
  match fuel bytes:
    case 0n Nil{}: Done{List.reverse(&2,T.Component,rev)}
    case 1n+rest Con{+id,Con{+sample,Con{+quant,tail}}}:
      +h : U32 = U32.shrn(sample,4n)
      +v : U32 = U32.and(sample,15)
      do Result<&2,&2,T.Failure,List<&2,T.Component>>:
        _ : Unit <- T.require(Bool.not(contains(rev,id)) && U32.is_le(quant,3),"invalid_jpeg","JPEG frame component identifiers or quantizer selectors are invalid")
        _ : Unit <- T.require(U32.is_gt(h,0) && U32.is_gt(v,0) && U32.is_le(h,4) && U32.is_le(v,4),"invalid_jpeg","JPEG sampling factors are outside 1..4")
        _ : Unit <- T.require(U32.is_le(h,2) && U32.is_le(v,2),"unsupported_jpeg_sampling","JPEG sampling greater than two is not yet displayed")
        components(rest,tail,T.Component{id,h,v,quant} <> rev)
    case _ _: Fail{T.Failure{"invalid_jpeg","JPEG frame component extent is inconsistent"}}

def sized(+width: U32,+height: U32,+items: List<&2,T.Component>,+h: U32,+v: U32) -> Result<&2,&2,T.Failure,T.Frame>:
  do Result<&2,&2,T.Failure,T.Frame>:
    _ : Unit <- T.require(U32.is_gt(width,0) && U32.is_gt(height,0),"unsupported_jpeg_mode","JPEG delayed or zero dimensions are not displayed")
    _ : Unit <- T.require(U32.is_le(width,T.max_dimension()) && U32.is_le(height,T.max_dimension()),"image_resource_limit","JPEG dimensions exceed the display bound")
    _ : Unit <- T.require(U32.is_le(width,U32.div(T.max_pixels(),height)),"image_resource_limit","JPEG pixel count exceeds the display bound")
    +mw : U32 = U32.mul(8,h)
    +mh : U32 = U32.mul(8,v)
    Done{T.Frame{width,height,items,h,v,U32.div(U32.add(width,U32.sub(mw,1)),mw),U32.div(U32.add(height,U32.sub(mh,1)),mh)}}

def sampling(+items: List<&2,T.Component>,width: U32,height: U32) -> Result<&2,&2,T.Failure,T.Frame>:
  match items:
    case [T.Component{_,1,1,_}]: sized(width,height,items,1,1)
    case [T.Component{_,h,v,_},T.Component{_,1,1,_},T.Component{_,1,1,_}]: sized(width,height,items,h,v)
    case _: Fail{T.Failure{"unsupported_jpeg_sampling","JPEG sampling layout is not yet displayed"}}

def frame(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,T.Frame>:
  match bytes:
    case precision <> yh <> yl <> xh <> xl <> +count <> tail:
      do Result<&2,&2,T.Failure,T.Frame>:
        _ : Unit <- T.require(U32.is_eq(precision,8),"unsupported_jpeg_mode","Only eight-bit baseline JPEG is currently displayed")
        _ : Unit <- T.require(U32.is_eq(count,1) || U32.is_eq(count,3),"unsupported_jpeg_color","Only grayscale and three-component JPEG are currently displayed")
        items : List<&2,T.Component> <- components(U32.to_nat(count),tail,[])
        sampling(items,Input.word(xh,xl),Input.word(yh,yl))
    case _: Fail{T.Failure{"invalid_jpeg","JPEG frame header is truncated"}}

def find(items: List<&2,T.Component>,+id: U32) -> Result<&2,&2,T.Failure,T.Component>:
  match items:
    case []: Fail{T.Failure{"invalid_jpeg","JPEG scan contains an unknown frame component"}}
    case +item <> rest:
      T.Component{key,_,_,_} = item
      T.branch(Result<&2,&2,T.Failure,T.Component>,U32.is_eq(key,id),_ => Done{item},_ => find(rest,id))

def scan_contains(items: List<&2,T.ScanComponent>,+id: U32) -> Bool:
  match items:
    case []: False{}
    case T.ScanComponent{T.Component{key,_,_,_},_,_} <> rest: U32.is_eq(key,id) || scan_contains(rest,id)

def scan_quant(+item: T.Component,quants: List<&2,T.Quantizer>) -> Result<&2,&2,T.Failure,Unit>:
  T.Component{_,_,_,quant} = item
  do Result<&2,&2,T.Failure,Unit>:
    _ : List<&2,U32> <- Tables.quant_get(quants,quant)
    Done{Unit{}}

def scan_parts(fuel: Nat,bytes: List<&2,U32>,+frame: List<&2,T.Component>,+quants: List<&2,T.Quantizer>,+tables: List<&2,T.Table>,+rev: List<&2,T.ScanComponent>) -> Result<&2,&2,T.Failure,List<&2,T.ScanComponent>>:
  match fuel bytes:
    case 0n Con{0,Con{63,Con{0,Nil{}}}}: Done{List.reverse(&2,T.ScanComponent,rev)}
    case 0n _: Fail{T.Failure{"unsupported_jpeg_mode","JPEG scan is not full sequential baseline spectral selection"}}
    case 1n+rest Con{+id,Con{+selectors,tail}}:
      +dc : U32 = U32.shrn(selectors,4n)
      +ac : U32 = U32.and(selectors,15)
      do Result<&2,&2,T.Failure,List<&2,T.ScanComponent>>:
        _ : Unit <- T.require(Bool.not(scan_contains(rev,id)) && U32.is_le(dc,1) && U32.is_le(ac,1),"invalid_jpeg","JPEG scan component or Huffman selector is invalid")
        +item : T.Component <- find(frame,id)
        _ : Unit <- scan_quant(item,quants)
        _ : T.Huffman <- Tables.huffman_get(tables,0,dc)
        _ : T.Huffman <- Tables.huffman_get(tables,1,ac)
        scan_parts(rest,tail,frame,quants,tables,T.ScanComponent{item,dc,ac} <> rev)
    case _ _: Fail{T.Failure{"invalid_jpeg","JPEG scan component extent is truncated"}}

def component_count(items: List<&2,T.Component>,count: U32) -> U32:
  match items:
    case []: count
    case _ <> rest: component_count(rest,U32.inc(count))

def scan(bytes: List<&2,U32>,frame: T.Frame,quants: List<&2,T.Quantizer>,tables: List<&2,T.Table>) -> Result<&2,&2,T.Failure,List<&2,T.ScanComponent>>:
  match bytes:
    case +count <> tail:
      T.Frame{_,_,+items,_,_,_,_} = frame
      do Result<&2,&2,T.Failure,List<&2,T.ScanComponent>>:
        _ : Unit <- T.require(U32.is_eq(count,component_count(items,0)),"unsupported_jpeg_mode","Multi-scan sequential JPEG is not yet displayed")
        scan_parts(U32.to_nat(count),tail,items,quants,tables,[])
    case []: Fail{T.Failure{"invalid_jpeg","JPEG scan header is empty"}}

def rgb_sampling(items: List<&2,T.Component>) -> Bool:
  match items:
    case [T.Component{_,1,1,_},T.Component{_,1,1,_},T.Component{_,1,1,_}]: True{}
    case _: False{}

def color_ids(items: List<&2,T.Component>) -> U32:
  match items:
    case [T.Component{1,_,_,_},T.Component{2,_,_,_},T.Component{3,_,_,_}]: 1
    case [T.Component{82,_,_,_},T.Component{71,_,_,_},T.Component{66,_,_,_}]: 2
    case _: 0

def color_adobe(adobe: Maybe<&2,U32>,jfif: Bool,+items: List<&2,T.Component>) -> Result<&2,&2,T.Failure,T.ColorMode>:
  match adobe:
    case Some{0}:
      do Result<&2,&2,T.Failure,T.ColorMode>:
        _ : Unit <- T.require(Bool.not(jfif) && U32.is_ne(color_ids(items),0) && rgb_sampling(items),"unsupported_jpeg_color","Adobe RGB JPEG color markers or sampling are unsupported")
        Done{T.RGB{}}
    case Some{1}:
      do Result<&2,&2,T.Failure,T.ColorMode>:
        _ : Unit <- T.require(U32.is_eq(color_ids(items),1),"unsupported_jpeg_color","YCbCr JPEG component identities are unsupported")
        Done{T.YCbCr{}}
    case None{}:
      do Result<&2,&2,T.Failure,T.ColorMode>:
        _ : Unit <- T.require(jfif && U32.is_eq(color_ids(items),1),"unsupported_jpeg_color","JPEG color interpretation is not identified by a supported JFIF or Adobe marker")
        Done{T.YCbCr{}}
    case _: Fail{T.Failure{"unsupported_jpeg_color","CMYK or YCCK JPEG is not yet displayed"}}

def gray(adobe: Maybe<&2,U32>) -> Result<&2,&2,T.Failure,T.ColorMode>:
  match adobe:
    case None{}: Done{T.Gray{}}
    case Some{0}: Done{T.Gray{}}
    case _: Fail{T.Failure{"unsupported_jpeg_color","Grayscale JPEG contradicts its Adobe color transform"}}

def color(frame: T.Frame,jfif: Bool,adobe: Maybe<&2,U32>) -> Result<&2,&2,T.Failure,T.ColorMode>:
  T.Frame{_,_,items,_,_,_,_} = frame
  match items:
    case [_]: gray(adobe)
    case rest: color_adobe(adobe,jfif,rest)
