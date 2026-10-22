import Base
import ./types.bend as T
import ./input.bend as Input

def jfif(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Bool>:
  match bytes:
    case 74 <> 70 <> 73 <> 70 <> 0 <> major <> minor <> units <> xh <> xl <> yh <> yl <> +x <> +y <> tail:
      do Result<&2,&2,T.Failure,Bool>:
        _ : Unit <- T.require(U32.is_eq(major,1) && U32.is_le(minor,2) && U32.is_le(units,2),"unsupported_jpeg_metadata","JFIF version or density unit is unsupported")
        _ : Unit <- T.require(U32.is_gt(Input.word(xh,xl),0) && U32.is_gt(Input.word(yh,yl),0),"invalid_jpeg","JFIF density must be nonzero")
        _ : Unit <- T.require(U32.is_eq(Input.count(tail,0),U32.mul(U32.mul(x,y),3)),"invalid_jpeg","JFIF thumbnail extent differs from its dimensions")
        Done{True{}}
    case 74 <> 70 <> 73 <> 70 <> 0 <> _: Fail{T.Failure{"invalid_jpeg","JFIF marker is truncated"}}
    case _: Done{False{}}

def adobe(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Maybe<&2,U32>>:
  match bytes:
    case [65,100,111,98,101,_,_,_,_,_,_,+transform]:
      do Result<&2,&2,T.Failure,Maybe<&2,U32>>:
        _ : Unit <- T.require(U32.is_le(transform,2),"unsupported_jpeg_color","Adobe JPEG color transform is unsupported")
        Done{Some{transform}}
    case 65 <> 100 <> 111 <> 98 <> 101 <> _: Fail{T.Failure{"invalid_jpeg","Adobe JPEG marker has an invalid extent"}}
    case _: Done{None{}}

def word(little: Bool,+a: U32,+b: U32) -> U32:
  Bool.pick(U32,little,Input.word(b,a),Input.word(a,b))

def long(little: Bool,+a: U32,+b: U32,+c: U32,+d: U32) -> U32:
  Bool.pick(U32,little,U32.or(U32.shln(Input.word(d,c),16n),Input.word(b,a)),U32.or(U32.shln(Input.word(a,b),16n),Input.word(c,d)))

def read16(+bytes: List<&2,U32>,+index: U32,little: Bool) -> Result<&2,&2,T.Failure,U32>:
  do Result<&2,&2,T.Failure,U32>:
    _ : Unit <- T.require(U32.is_le(index,65533),"invalid_jpeg","Exif field offset exceeds its bounded JPEG segment")
    a : U32 <- Input.nth(bytes,index)
    b : U32 <- Input.nth(bytes,U32.inc(index))
    Done{word(little,a,b)}

def read32(+bytes: List<&2,U32>,+index: U32,little: Bool) -> Result<&2,&2,T.Failure,U32>:
  do Result<&2,&2,T.Failure,U32>:
    _ : Unit <- T.require(U32.is_le(index,65531),"invalid_jpeg","Exif long field offset exceeds its bounded JPEG segment")
    a : U32 <- Input.nth(bytes,index)
    b : U32 <- Input.nth(bytes,U32.inc(index))
    c : U32 <- Input.nth(bytes,U32.add(index,2))
    d : U32 <- Input.nth(bytes,U32.add(index,3))
    Done{long(little,a,b,c,d)}

def orientation_field(tag: U32,+little: Bool,a: U32,b: U32,c: U32,d: U32,e: U32,f: U32,g: U32,h: U32,seen: Bool) -> Result<&2,&2,T.Failure,Bool>:
  match tag:
    case 274:
      do Result<&2,&2,T.Failure,Bool>:
        _ : Unit <- T.require(Bool.not(seen) && U32.is_eq(word(little,a,b),3) && U32.is_eq(long(little,c,d,e,f),1),"invalid_jpeg","Exif orientation field is duplicated or malformed")
        _ : Unit <- T.require(U32.is_eq(word(little,g,h),1),"unsupported_jpeg_orientation","Rotated or mirrored Exif JPEG is not yet displayed")
        Done{True{}}
    case _: Done{seen}

def fields(fuel: Nat,bytes: List<&2,U32>,+little: Bool,seen: Bool) -> Result<&2,&2,T.Failure,Unit>:
  match fuel bytes:
    case 0n Con{_,Con{_,Con{_,Con{_,_}}}}: Done{Unit{}}
    case 1n+rest Con{th,Con{tl,Con{a,Con{b,Con{c,Con{d,Con{e,Con{f,Con{g,Con{h,Con{_,Con{_,tail}}}}}}}}}}}}:
      do Result<&2,&2,T.Failure,Unit>:
        found : Bool <- orientation_field(word(little,th,tl),little,a,b,c,d,e,f,g,h,seen)
        fields(rest,tail,little,found)
    case _ _: Fail{T.Failure{"invalid_jpeg","Exif directory entries are truncated"}}

def directory(bytes: List<&2,U32>,+little: Bool) -> Result<&2,&2,T.Failure,Unit>:
  match bytes:
    case a <> b <> tail:
      +count : U32 = word(little,a,b)
      do Result<&2,&2,T.Failure,Unit>:
        _ : Unit <- T.require(U32.is_le(count,128),"unsupported_jpeg_metadata","Exif directory exceeds the bounded metadata profile")
        fields(U32.to_nat(count),tail,little,False{})
    case _: Fail{T.Failure{"invalid_jpeg","Exif directory count is truncated"}}

def directory_part(part: Input.Part,little: Bool) -> Result<&2,&2,T.Failure,Unit>:
  Input.Part{_,tail} = part
  directory(tail,little)

def tiff_fields(+bytes: List<&2,U32>,+little: Bool) -> Result<&2,&2,T.Failure,Unit>:
  do Result<&2,&2,T.Failure,Unit>:
    magic : U32 <- read16(bytes,2,little)
    +offset : U32 <- read32(bytes,4,little)
    _ : Unit <- T.require(U32.is_eq(magic,42) && U32.is_ge(offset,8) && U32.is_le(offset,65533),"invalid_jpeg","Exif TIFF header or directory offset is invalid")
    part : Input.Part <- Input.take(U32.to_nat(offset),bytes,[])
    directory_part(part,little)

def tiff(+bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Unit>:
  match bytes:
    case 73 <> 73 <> _: tiff_fields(bytes,True{})
    case 77 <> 77 <> _: tiff_fields(bytes,False{})
    case _: Fail{T.Failure{"invalid_jpeg","Exif TIFF byte order is invalid"}}

def exif(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Unit>:
  match bytes:
    case 69 <> 120 <> 105 <> 102 <> 0 <> 0 <> tail: tiff(tail)
    case 69 <> 120 <> 105 <> 102 <> _: Fail{T.Failure{"invalid_jpeg","Exif signature is malformed"}}
    case _: Done{Unit{}}
