import Base
import ./ui.bend as UI
import ./bend_ui/canvas.bend as C
import ./attachment_preview_geometry.bend as Geometry

# Application chrome remains the existing Bend canvas. This dedicated view
# makes inactive attachment controls disappear while preserving their bookmark.
def base(+caption: String,+status: String,+ready: Bool) -> C.Canvas:
  +a : C.Canvas = UI.box(C.Flat{UI.paper()},0,0,512,664,UI.rail())
  +b : C.Canvas = UI.text(a,"JUICE BEND",24,24,40,UI.accent(),UI.rail())
  +c : C.Canvas = UI.text(b,"Retained attachment",24,72,52,UI.ink(),UI.rail())
  +d : C.Canvas = UI.text(c,caption,24,112,56,UI.muted(),UI.rail())
  +e : C.Canvas = UI.text(d,Bool.pick(String,ready,"Verified bytes from this captured occurrence","Selected captured attachment occurrence"),24,176,58,UI.ink(),UI.rail())
  +f : C.Canvas = UI.text(e,"All attachment references in these",24,224,58,UI.muted(),UI.rail())
  +g : C.Canvas = UI.text(f,"captured records. Reader filters do not apply.",24,248,58,UI.muted(),UI.rail())
  +h : C.Canvas = UI.text(g,"Back or Escape returns to your selection.",24,312,58,UI.ink(),UI.rail())
  +i : C.Canvas = UI.text(h,"At 100%: use arrow keys or scroll to pan.",24,344,58,UI.muted(),UI.rail())
  +j : C.Canvas = UI.text(i,Bool.pick(String,ready,"Original bytes remain available to export.","Return to inspect or export available bytes."),24,400,58,UI.muted(),UI.rail())
  +k : C.Canvas = UI.text(j,"Image preview",536,48,70,UI.ink(),UI.paper())
  +l : C.Canvas = UI.text(k,Bool.pick(String,ready,"Fit: F  |  Actual pixels: 1  |  Nearest sampling","Preview unavailable"),536,88,78,UI.muted(),UI.paper())
  +m : C.Canvas = UI.box(UI.box(UI.box(l,536,128,88,32,UI.panel()),632,128,72,32,UI.panel()),712,128,88,32,UI.panel())
  +n : C.Canvas = UI.text(UI.text(UI.text(m,"Back",552,136,8,UI.accent(),UI.panel()),"Fit",648,136,6,Bool.pick(U32,ready,UI.accent(),UI.muted()),UI.panel()),"100%",728,136,8,Bool.pick(U32,ready,UI.accent(),UI.muted()),UI.panel())
  +o : C.Canvas = UI.box(n,0,624,1200,40,UI.rail())
  UI.text(o,status,16,640,146,UI.ink(),UI.rail())

def ready(caption: String,width: U32,height: U32,view: Geometry.View,notice: Bool) -> Image:
  Geometry.View{actual,x,y} = view
  +status = U32.show(width) ++ " x " ++ U32.show(height) ++ " px | " ++
    Bool.pick(String,actual,"100% at " ++ U32.show(x) ++ "," ++ U32.show(y),"Fit to reader") ++
    Bool.pick(String,notice," | Color profile not applied","")
  UI.canvas.image(base(caption,status,True{}))

def failure(caption: String,detail: String) -> Image:
  +a : C.Canvas = base(caption,"This preview made no capture changes. Export performs its own byte verification.",False{})
  +b : C.Canvas = UI.text(a,"This retained image cannot be displayed.",536,192,78,UI.ink(),UI.paper())
  +c : C.Canvas = UI.draw_reader(16n,b,UI.wrap(detail),28,0,0)
  +d : C.Canvas = UI.text(c,"Basic PNG and baseline JPEG are supported within display limits.",536,536,78,UI.muted(),UI.paper())
  +e : C.Canvas = UI.text(d,"Progressive JPEG, palette PNG, Adam7 and APNG remain unavailable.",536,560,78,UI.muted(),UI.paper())
  UI.canvas.image(e)
