import Base
import ./attachment_image_types.bend as T

# Pure reader-preview coordinates. Destination and source rectangles are
# half-open. Offsets never authorize an image or a source read.
type Box is Data:
  Box{left: U32,top: U32,width: U32,height: U32}
type View is Data:
  View{actual: Bool,x: U32,y: U32}
type Frame is Data:
  Frame{left: U32,top: U32,width: U32,height: U32,
    source_x: U32,source_y: U32,source_width: U32,source_height: U32}
type Point is Data:
  Point{x: U32,y: U32}

def viewport() -> Box:
  Box{536,176,640,432}

def admitted(+width: U32,+height: U32) -> Bool:
  U32.is_gt(width,0) && U32.is_gt(height,0) &&
    U32.is_le(width,T.max_dimension()) && U32.is_le(height,T.max_dimension()) &&
    U32.is_le(width,U32.div(T.max_pixels(),U32.max(height,1)))

def validate(+width: U32,+height: U32) -> Result<&2,&2,T.Failure,Unit>:
  do Result<&2,&2,T.Failure,Unit>:
    _ : Unit <- T.require(U32.is_gt(width,0) && U32.is_gt(height,0),T.InvalidInput{},"Preview dimensions must be nonzero")
    _ : Unit <- T.require(U32.is_le(width,T.max_dimension()) && U32.is_le(height,T.max_dimension()),T.ResourceLimit{},"Preview dimensions exceed the image profile")
    T.require(U32.is_le(width,U32.div(T.max_pixels(),height)),T.ResourceLimit{},"Preview pixel count exceeds the image profile")

def centered(box: Box,+width: U32,+height: U32,source_x: U32,source_y: U32,source_width: U32,source_height: U32) -> Frame:
  Box{left,top,box_width,box_height} = box
  Frame{U32.add(left,U32.div(U32.sub(box_width,width),2)),U32.add(top,U32.div(U32.sub(box_height,height),2)),
    width,height,source_x,source_y,source_width,source_height}

# After dimension admission, every cross-product below is at most 2048*640.
# The limiting dimension fills its viewport axis; the other rounds down, with
# a one-pixel minimum for extreme aspect ratios. Upscaling is intentional.
def fit_axis(width_limited: Bool,+width: U32,+height: U32) -> Frame:
  match width_limited:
    case True{}: centered(viewport(),640,U32.max(1,U32.div(U32.mul(height,640),width)),0,0,width,height)
    case False{}: centered(viewport(),U32.max(1,U32.div(U32.mul(width,432),height)),432,0,0,width,height)

def fit_admitted(+width: U32,+height: U32) -> Frame:
  fit_axis(U32.is_ge(U32.mul(width,432),U32.mul(height,640)),width,height)

def fit(+width: U32,+height: U32) -> Result<&2,&2,T.Failure,Frame>:
  do Result<&2,&2,T.Failure,Frame>:
    _ : Unit <- validate(width,height)
    Done{fit_admitted(width,height)}

def actual_frame(+width: U32,+height: U32,x: U32,y: U32) -> Frame:
  +visible_width : U32 = U32.min(width,640)
  +visible_height : U32 = U32.min(height,432)
  centered(viewport(),visible_width,visible_height,
    U32.min(x,U32.sub(width,visible_width)),U32.min(y,U32.sub(height,visible_height)),visible_width,visible_height)

def frame_mode(actual: Bool,width: U32,height: U32,x: U32,y: U32) -> Frame:
  match actual:
    case False{}: fit_admitted(width,height)
    case True{}: actual_frame(width,height,x,y)

def frame(+width: U32,+height: U32,view: View) -> Result<&2,&2,T.Failure,Frame>:
  View{actual,x,y} = view
  do Result<&2,&2,T.Failure,Frame>:
    _ : Unit <- validate(width,height)
    Done{frame_mode(actual,width,height,x,y)}

# Clamp first, then cap the delta by remaining distance. No addition can exceed
# the admitted axis maximum, including a caller-supplied U32_MAX delta.
def pan(value: U32,+maximum: U32,negative: Bool,+delta: U32) -> U32:
  +start : U32 = U32.min(value,maximum)
  Bool.pick(U32,negative,U32.sub(start,U32.min(start,delta)),
    U32.add(start,U32.min(delta,U32.sub(maximum,start))))

def move_actual(+width: U32,+height: U32,+x: U32,+y: U32,dx_negative: Bool,dy_negative: Bool,dx: U32,dy: U32) -> View:
  T.branch(View,admitted(width,height),
    _ => View{True{},pan(x,U32.sub(width,U32.min(width,640)),dx_negative,dx),pan(y,U32.sub(height,U32.min(height,432)),dy_negative,dy)},
    _ => View{True{},x,y})

def move(width: U32,height: U32,view: View,dx_negative: Bool,dy_negative: Bool,dx: U32,dy: U32) -> View:
  match view:
    case View{False{},x,y}: View{False{},x,y}
    case View{True{},x,y}: move_actual(width,height,x,y,dx_negative,dy_negative,dx,dy)

# Frames can be supplied independently of fit/frame. Validate all arithmetic
# domains here as well; Base's wrapping arithmetic is never an extent check.
def frame_valid(value: Frame) -> Bool:
  Frame{+left,+top,+width,+height,+sx,+sy,+sw,+sh} = value
  +extent_x : U32 = U32.add(U32.min(sx,2048),U32.min(sw,2048))
  +extent_y : U32 = U32.add(U32.min(sy,2048),U32.min(sh,2048))
  U32.is_ge(left,536) && U32.is_le(left,1176) && U32.is_ge(top,176) && U32.is_le(top,608) &&
    U32.is_gt(width,0) && U32.is_gt(height,0) &&
    U32.is_le(width,U32.sub(640,U32.min(U32.sub(left,U32.min(left,536)),640))) &&
    U32.is_le(height,U32.sub(432,U32.min(U32.sub(top,U32.min(top,176)),432))) &&
    U32.is_lt(sx,2048) && U32.is_lt(sy,2048) && U32.is_gt(sw,0) && U32.is_gt(sh,0) &&
    U32.is_le(sw,U32.sub(2048,U32.min(sx,2048))) && U32.is_le(sh,U32.sub(2048,U32.min(sy,2048))) &&
    U32.is_le(extent_x,U32.div(T.max_pixels(),U32.max(extent_y,1)))

def point_admitted(value: Frame,+x: U32,+y: U32) -> Maybe<&2,Point>:
  Frame{+left,+top,+width,+height,sx,sy,sw,sh} = value
  +relative_x : U32 = U32.sub(x,U32.min(x,left))
  +relative_y : U32 = U32.sub(y,U32.min(y,top))
  T.branch(Maybe<&2,Point>,U32.is_ge(x,left) && U32.is_ge(y,top) && U32.is_lt(relative_x,width) && U32.is_lt(relative_y,height),
    _ => Some{Point{U32.add(sx,U32.div(U32.mul(relative_x,sw),width)),U32.add(sy,U32.div(U32.mul(relative_y,sh),height))}},
    _ => None{})

def point(+value: Frame,x: U32,y: U32) -> Maybe<&2,Point>:
  T.branch(Maybe<&2,Point>,frame_valid(value),_ => point_admitted(value,x,y),_ => None{})
