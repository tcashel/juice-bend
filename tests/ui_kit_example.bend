import Base
import ../examples/ui_controls.bend as E
import ./ui_kit_labels.bend as Pixel
import ../src/bend_ui/canvas.bend as C

# Sample the actual Image at the runtime's depth for a 512x216 window. The
# original full-2048 image fails this comparison even though Canvas tests pass.
def image_child(image: Image,right: Bool,bottom: Bool) -> Image:
  match image right bottom:
    case Pix{color} _ _: Pix{color}
    case Qua{tl,_,_,_} False{} False{}: tl
    case Qua{_,tr,_,_} True{} False{}: tr
    case Qua{_,_,bl,_} False{} True{}: bl
    case Qua{_,_,_,br} True{} True{}: br

def image_pixel(depth: Nat,image: Image,+x: U32,+y: U32) -> U32:
  match depth image:
    case _ Pix{color}: color
    case 0n _: 0
    case 1n+ +rest +node:
      +half = U32.shln(1,rest)
      image_pixel(rest,image_child(node,U32.is_ge(x,half),U32.is_ge(y,half)),U32.mod(x,half),U32.mod(y,half))

def frame_pixels(fuel: Nat,+canvas: C.Canvas,+image: Image,+index: U32) -> Bool:
  match fuel:
    case 0n: True{}
    case 1n+rest:
      +x = U32.mod(index,512)
      +y = U32.div(index,512)
      U32.is_eq(image_pixel(9n,image,x,y),Pixel.pixel(8n,canvas,x,y)) &&
        frame_pixels(rest,canvas,image,U32.inc(index))

def cached_image(state: E.State) -> Image:
  E.State{_,image} = state
  image

def image_refused(result: Result<&2,&2,C.Failure,Image>) -> Bool:
  match result:
    case Fail{C.InvalidBounds{}}: True{}
    case _: False{}

def value(model: Maybe<E.Model>,focus: U32,selected: U32) -> Bool:
  match model:
    case Some{E.Model{Some{actual},pick,_}}: U32.is_eq(actual,focus) && U32.is_eq(pick,selected)
    case _: False{}
def closed(model: Maybe<E.Model>) -> Bool:
  match model:
    case None{}: True{}
    case _: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    Pixel.require(value(E.events([Key{9,True{}}],Some{E.initial()}),10,0),"standalone Tab focuses first control without activating it")
    Pixel.require(value(E.events([Key{9,True{}},Key{9,True{}},Key{13,True{}}],Some{E.initial()}),20,20),"standalone second Tab then Enter activates the focused control")
    Pixel.require(value(E.events([Key{65592,True{}},Key{9,True{}}],Some{E.initial()}),20,0),"standalone native left Shift-Tab starts at the last enabled control")
    Pixel.require(value(E.events([Key{65596,True{}},Key{9,True{}}],Some{E.initial()}),20,0),"standalone native right Shift-Tab starts at the last enabled control")
    Pixel.require(value(E.events([Key{65592,True{}},Key{65592,False{}},Key{9,True{}}],Some{E.initial()}),10,0),"native left Shift release restores forward Tab traversal")
    Pixel.require(value(E.events([Key{65596,True{}},Key{65596,False{}},Key{9,True{}}],Some{E.initial()}),10,0),"native right Shift release restores forward Tab traversal")
    Pixel.require(value(E.events([Key{25,True{}}],Some{E.initial()}),20,0),"native back-tab character explicitly selects reverse traversal")
    Pixel.require(value(E.events([Key{25,True{}},Key{9,True{}}],Some{E.initial()}),10,0),"back-tab character does not latch a Shift modifier into the next Tab")
    Pixel.require(value(E.events([Mouse{30,110,0,True{}},Mouse{350,110,0,True{}}],Some{E.initial()}),10,10),"standalone disabled control cannot replace clicked selection")
    Pixel.require(value(E.events([Key{9,True{}},Key{32,True{}}],Some{E.initial()}),10,10),"standalone Space activates a focused control")
    Pixel.require(closed(E.events([Close{},Key{9,True{}}],Some{E.initial()})),"standalone native Close is terminal for the remaining event batch")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,E.paint(E.initial()),0,0),16316144),"standalone checked drawing retains the neutral canvas outside controls")
    Pixel.require(U32.is_eq(Pixel.pixel(8n,E.paint(E.Model{Some{10},10,False{}}),24,96),2502743),"standalone focus is visible in the same painted control rectangle")
    Pixel.require(frame_pixels(110592n,E.paint(E.initial()),E.frame(E.initial()),0),"initial native frame preserves all 512x216 canvas pixels at window coordinates")
    Pixel.require(frame_pixels(110592n,E.paint(E.Model{Some{20},20,False{}}),cached_image(E.cached(True{},E.State{E.initial(),Pix{0}},E.Model{Some{20},20,False{}})),0),"changed cached native frame preserves all 512x216 selected-control pixels")
    Pixel.require(image_refused(C.image_viewport(C.Flat{0},0,216)) && image_refused(C.image_viewport(C.Flat{0},512,0)) && image_refused(C.image_viewport(C.Flat{0},2049,216)) && image_refused(C.image_viewport(C.Flat{0},512,4294967295)),"viewport refuses zero and oversized dimensions instead of wrapping or scaling")
    Pixel.require(U32.is_eq(image_pixel(0n,E.accepted_image(C.image_viewport(C.Flat{1193046},1,1)),0,0),1193046),"one-pixel viewport preserves its original pixel without a minimum tile-size restriction")
