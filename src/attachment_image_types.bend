import Base

# Fixed initial display profile, separate from preservation: unsupported images
# remain retained/exportable. All arithmetic is checked before allocation.
type FailureKind is Data:
  InvalidInput{}
  InvalidPng{}
  UnsupportedFormat{}
  UnsupportedColor{}
  UnsupportedInterlace{}
  UnsupportedAnimation{}
  UnsupportedTransparency{}
  CompressedData{}
  ResourceLimit{}

type Failure is Data:
  Failure{kind: FailureKind,detail: String}

type Layout is Data:
  Layout{width: U32,height: U32,channels: U32,pixels: U32,row_bytes: U32,filtered_bytes: U32}

# RGBA samples use straight alpha and row-major order. Array capacity may exceed
# count; it is never part of the image. Color metadata is not color-managed.
type Raster is Type:
  Raster{width: U32,height: U32,count: U32,capacity: U32,pixels: Array<U32>,color_notice: Bool}

def max_input() -> U32: 1048576
def max_dimension() -> U32: 2048
def max_pixels() -> U32: 1048576
def max_filtered() -> U32: 4196352
def max_chunks() -> U32: 4096

def branch(-A: Type,condition: Bool,yes: Unit -> A,no: Unit -> A) -> A:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def label(kind: FailureKind) -> String:
  match kind:
    case InvalidInput{}: "invalid_input"
    case InvalidPng{}: "invalid_png"
    case UnsupportedFormat{}: "unsupported_image_format"
    case UnsupportedColor{}: "unsupported_png_color_or_depth"
    case UnsupportedInterlace{}: "unsupported_png_interlace"
    case UnsupportedAnimation{}: "unsupported_png_animation"
    case UnsupportedTransparency{}: "unsupported_png_transparency"
    case CompressedData{}: "invalid_png_compressed_data"
    case ResourceLimit{}: "image_resource_limit"

def require(condition: Bool,kind: FailureKind,detail: String) -> Result<&2,&2,Failure,Unit>:
  Bool.pick(Result<&2,&2,Failure,Unit>,condition,Done{Unit{}},Fail{Failure{kind,detail}})

def channel_count(color: U32) -> Maybe<&2,U32>:
  match color:
    case 0: Some{1}
    case 2: Some{3}
    case 4: Some{2}
    case 6: Some{4}
    case _: None{}

def layout_channels(value: Maybe<&2,U32>,+width: U32,+height: U32) -> Result<&2,&2,Failure,Layout>:
  match value:
    case None{}: Fail{Failure{UnsupportedColor{},"This PNG color type is not yet displayed"}}
    case Some{+channels}:
      do Result<&2,&2,Failure,Layout>:
        _ : Unit <- require(U32.is_gt(width,0) && U32.is_gt(height,0),InvalidPng{},"PNG dimensions must be nonzero")
        _ : Unit <- require(U32.is_le(width,max_dimension()) && U32.is_le(height,max_dimension()),ResourceLimit{},"PNG dimensions exceed the display profile")
        _ : Unit <- require(U32.is_le(width,U32.div(max_pixels(),height)),ResourceLimit{},"PNG pixel count exceeds the display profile")
        +row : U32 = U32.mul(width,channels)
        +filtered : U32 = U32.mul(height,U32.inc(row))
        _ : Unit <- require(U32.is_le(filtered,max_filtered()),ResourceLimit{},"PNG filtered output exceeds the display profile")
        Done{Layout{width,height,channels,U32.mul(width,height),row,filtered}}

def layout(width: U32,height: U32,color: U32) -> Result<&2,&2,Failure,Layout>:
  layout_channels(channel_count(color),width,height)

def depth(+count: U32) -> Nat:
  Bool.pick(Nat,U32.is_le(count,1),0n,1n+U32.log2(U32.sub(count,1)))

def rgba(red: U32,green: U32,blue: U32,alpha: U32) -> U32:
  U32.or(U32.or(U32.shln(red,24n),U32.shln(green,16n)),U32.or(U32.shln(blue,8n),alpha))

def component(value: U32,shift: Nat) -> U32:
  U32.and(U32.shrn(value,shift),255)

def blend(foreground: U32,background: U32,+alpha: U32) -> U32:
  U32.div(U32.add(U32.add(U32.mul(foreground,alpha),U32.mul(background,U32.sub(255,alpha))),127),255)

# Base.Image.Pix is an RGB integer; transparent samples are composited in Bend.
def rgb(+pixel: U32,+background: U32) -> U32:
  +alpha : U32 = component(pixel,0n)
  U32.or(U32.shln(blend(component(pixel,24n),component(background,16n),alpha),16n),
    U32.or(U32.shln(blend(component(pixel,16n),component(background,8n),alpha),8n),
      blend(component(pixel,8n),component(background,0n),alpha)))
