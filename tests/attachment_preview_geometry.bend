import Base
import ../src/attachment_preview_geometry.bend as G
import ../src/attachment_image_types.bend as T

# Exact expected coordinates below are independent arithmetic fixtures. No
# expected Frame/Point is produced by the geometry functions under test.
def check(label: String,valid: Bool) -> IO(Unit):
  match valid:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def same_frame(a: G.Frame,b: G.Frame) -> Bool:
  G.Frame{al,at,aw,ah,ax,ay,asw,ash} = a
  G.Frame{bl,bt,bw,bh,bx,by,bsw,bsh} = b
  U32.is_eq(al,bl) && U32.is_eq(at,bt) && U32.is_eq(aw,bw) && U32.is_eq(ah,bh) &&
    U32.is_eq(ax,bx) && U32.is_eq(ay,by) && U32.is_eq(asw,bsw) && U32.is_eq(ash,bsh)

def good_frame(result: Result<&2,&2,T.Failure,G.Frame>,expected: G.Frame) -> Bool:
  match result:
    case Done{actual}: same_frame(actual,expected)
    case Fail{_}: False{}

def bad_frame(result: Result<&2,&2,T.Failure,G.Frame>,expected: String) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{T.Failure{kind,_}}: String.eq(T.label(kind),expected)

def same_view(a: G.View,b: G.View) -> Bool:
  G.View{aa,ax,ay} = a
  G.View{ba,bx,by} = b
  U32.is_eq(Bool.to_u32(aa),Bool.to_u32(ba)) && U32.is_eq(ax,bx) && U32.is_eq(ay,by)

def at(result: Maybe<&2,G.Point>,x: U32,y: U32) -> Bool:
  match result:
    case Some{G.Point{actual_x,actual_y}}: U32.is_eq(actual_x,x) && U32.is_eq(actual_y,y)
    case None{}: False{}

def absent(result: Maybe<&2,G.Point>) -> Bool:
  match result:
    case Some{_}: False{}
    case None{}: True{}

def viewport(value: G.Box) -> Bool:
  match value:
    case G.Box{536,176,640,432}: True{}
    case _: False{}

def fitting() -> IO(Unit):
  do IO<Unit>:
    check("fixed reader viewport",viewport(G.viewport()))
    check("landscape fit centers 16 by 9",good_frame(G.fit(16,9),G.Frame{536,212,640,360,0,0,16,9}))
    check("portrait fit rounds down 9 by 16",good_frame(G.fit(9,16),G.Frame{734,176,243,432,0,0,9,16}))
    check("one pixel upscales without losing source extent",good_frame(G.fit(1,1),G.Frame{640,176,432,432,0,0,1,1}))
    check("extreme landscape remains one destination pixel high",good_frame(G.fit(2048,1),G.Frame{536,391,640,1,0,0,2048,1}))
    check("extreme portrait remains one destination pixel wide",good_frame(G.fit(1,2048),G.Frame{855,176,1,432,0,0,1,2048}))
    check("exact viewport ratio fills both axes",good_frame(G.fit(640,432),G.Frame{536,176,640,432,0,0,640,432}))
    check("maximum landscape pixel count",good_frame(G.fit(2048,512),G.Frame{536,312,640,160,0,0,2048,512}))
    check("maximum portrait pixel count",good_frame(G.fit(512,2048),G.Frame{802,176,108,432,0,0,512,2048}))
    check("maximum square pixel count",good_frame(G.fit(1024,1024),G.Frame{640,176,432,432,0,0,1024,1024}))
    check("zero width refuses before division",bad_frame(G.fit(0,1),"invalid_input"))
    check("zero height refuses before division",bad_frame(G.fit(1,0),"invalid_input"))
    check("dimension limit",bad_frame(G.fit(2049,1),"image_resource_limit"))
    check("pixel product limit",bad_frame(G.fit(2048,513),"image_resource_limit"))
    check("maximum unsigned input cannot overflow fit products",bad_frame(G.fit(4294967295,4294967295),"image_resource_limit"))

def actual() -> IO(Unit):
  do IO<Unit>:
    check("fit mode ignores saved pan offsets",good_frame(G.frame(16,9,G.View{False{},4294967295,4294967295}),G.Frame{536,212,640,360,0,0,16,9}))
    check("actual small image centered with zero crop",good_frame(G.frame(16,9,G.View{True{},12345,12345}),G.Frame{848,387,16,9,0,0,16,9}))
    check("actual landscape crops only horizontal axis",good_frame(G.frame(1024,256,G.View{True{},123,200}),G.Frame{536,264,640,256,123,0,640,256}))
    check("actual portrait crops only vertical axis",good_frame(G.frame(256,1024,G.View{True{},200,200}),G.Frame{728,176,256,432,0,200,256,432}))
    check("actual unsigned offsets clamp to maximum source region",good_frame(G.frame(2048,512,G.View{True{},4294967295,4294967295}),G.Frame{536,176,640,432,1408,80,640,432}))
    check("actual square retains explicit requested offsets",good_frame(G.frame(1024,1024,G.View{True{},300,500}),G.Frame{536,176,640,432,300,500,640,432}))
    check("actual size validates dimensions",bad_frame(G.frame(1,0,G.View{True{},0,0}),"invalid_input"))

def panning() -> IO(Unit):
  do IO<Unit>:
    check("fit view is unchanged by pan",same_view(G.move(1024,1024,G.View{False{},4294967295,99},True{},False{},4294967295,4294967295),G.View{False{},4294967295,99}))
    check("actual pan follows independent axis signs",same_view(G.move(1024,1024,G.View{True{},300,500},False{},True{},10,50),G.View{True{},310,450}))
    check("positive maximum delta saturates without wrapping",same_view(G.move(1024,1024,G.View{True{},1,1},False{},False{},4294967295,4294967295),G.View{True{},384,592}))
    check("negative maximum delta saturates at zero",same_view(G.move(1024,1024,G.View{True{},1,1},True{},True{},4294967295,4294967295),G.View{True{},0,0}))
    check("existing unsigned offsets clamp before movement",same_view(G.move(1024,1024,G.View{True{},4294967295,4294967295},True{},True{},10,10),G.View{True{},374,582}))
    check("small actual image cannot pan",same_view(G.move(16,9,G.View{True{},100,200},False{},False{},4294967295,4294967295),G.View{True{},0,0}))
    check("zero delta still clamps existing actual offsets",same_view(G.move(1024,1024,G.View{True{},4294967295,4294967295},False{},False{},0,0),G.View{True{},384,592}))
    check("invalid dimensions leave view unchanged",same_view(G.move(0,1024,G.View{True{},77,88},False{},False{},4294967295,4294967295),G.View{True{},77,88}))
    check("oversized dimensions leave view unchanged",same_view(G.move(4294967295,4294967295,G.View{True{},77,88},True{},True{},4294967295,4294967295),G.View{True{},77,88}))

def mapping() -> IO(Unit):
  do IO<Unit>:
    check("top-left fit pixel maps to source origin",at(G.point(G.Frame{536,212,640,360,0,0,16,9},536,212),0,0))
    check("upscale nearest-neighbor cell boundary",at(G.point(G.Frame{536,212,640,360,0,0,16,9},576,252),1,1))
    check("fit center floors vertical fraction",at(G.point(G.Frame{536,212,640,360,0,0,16,9},856,392),8,4))
    check("last fit pixel remains inside source",at(G.point(G.Frame{536,212,640,360,0,0,16,9},1175,571),15,8))
    check("right destination boundary is excluded",absent(G.point(G.Frame{536,212,640,360,0,0,16,9},1176,212)))
    check("bottom destination boundary is excluded",absent(G.point(G.Frame{536,212,640,360,0,0,16,9},536,572)))
    check("left destination boundary minus one is excluded",absent(G.point(G.Frame{536,212,640,360,0,0,16,9},535,212)))
    check("top destination boundary minus one is excluded",absent(G.point(G.Frame{536,212,640,360,0,0,16,9},536,211)))
    check("unsigned pointer coordinates cannot wrap into frame",absent(G.point(G.Frame{536,212,640,360,0,0,16,9},4294967295,4294967295)))
    check("downscale final pixel uses floor sampling",at(G.point(G.Frame{536,312,640,160,0,0,2048,512},1175,471),2044,508))
    check("downscale center maps exactly",at(G.point(G.Frame{536,312,640,160,0,0,2048,512},856,392),1024,256))
    check("one-pixel source maps every display pixel to origin",at(G.point(G.Frame{640,176,432,432,0,0,1,1},1071,607),0,0))
    check("one-pixel-wide portrait maps its final row",at(G.point(G.Frame{855,176,1,432,0,0,1,2048},855,607),0,2043))
    check("actual crop mapping includes source offsets",at(G.point(G.Frame{536,176,640,432,1408,80,640,432},1175,607),2047,511))
    check("actual crop top-left includes source offsets",at(G.point(G.Frame{536,176,640,432,1408,80,640,432},536,176),1408,80))
    check("zero destination width fails before division",absent(G.point(G.Frame{536,176,0,1,0,0,1,1},536,176)))
    check("zero destination height fails before division",absent(G.point(G.Frame{536,176,1,0,0,0,1,1},536,176)))
    check("zero source extent is invalid",absent(G.point(G.Frame{536,176,1,1,0,0,0,1},536,176)))
    check("overflowing destination extent is invalid",absent(G.point(G.Frame{4294967295,176,2,1,0,0,1,1},4294967295,176)))
    check("destination outside viewport is invalid",absent(G.point(G.Frame{535,176,1,1,0,0,1,1},535,176)))
    check("destination width outside viewport is invalid",absent(G.point(G.Frame{536,176,641,1,0,0,1,1},536,176)))
    check("overflowing source extent is invalid",absent(G.point(G.Frame{536,176,1,1,4294967295,0,2,1},536,176)))
    check("source width limit cannot wrap multiplication",absent(G.point(G.Frame{536,176,640,1,0,0,4294967295,1},1175,176)))
    check("source region exceeds admitted dimension",absent(G.point(G.Frame{536,176,1,1,2047,0,2,1},536,176)))
    check("source bounding extent exceeds pixel profile",absent(G.point(G.Frame{536,176,1,1,2047,2047,1,1},536,176)))

def main() -> IO(Unit):
  do IO<Unit>:
    fitting()
    actual()
    panning()
    mapping()
    IO.print("Attachment preview geometry tests passed")
