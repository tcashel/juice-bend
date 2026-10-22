# Compact fixed native content area. The pinned upstream Window API does not
# expose resizing or a display visible frame. Query/code rows retain the 8px
# grid; prose uses cached scalar/pixel boundaries within these 24px row targets.
import Base
import ./bend_ui/region.bend as Region

def width() -> U32: 1200
def height() -> U32: 664
def cell() -> U32: 8
def header_height() -> U32: 112
def reader_x() -> U32: 536
def reader_y() -> U32: 168
def reader_columns() -> U32: 80
def reader_rows() -> U32: 19
def line_pitch() -> U32: 24
def reader_page_step() -> U32: U32.sub(reader_rows(),2)
def reader_title_columns() -> U32: 18
def query_x() -> U32: 208
def query_y() -> U32: 32
def query_left() -> U32: 192
def query_right() -> U32: U32.sub(width(),24)
def query_columns() -> U32: U32.div(U32.sub(query_right(),query_x()),cell())
def sidebar_end() -> U32: 176
def sidebar_rows() -> U32: 16
def list_end() -> U32: 512
def list_y() -> U32: 184
def list_pitch() -> U32: 64
def list_rows() -> U32: 6
def list_pager_y() -> U32: 592
def footer_y() -> U32: U32.sub(height(),40)
def body_height() -> U32: U32.sub(footer_y(),header_height())
def footer_columns() -> U32: U32.sub(U32.div(width(),cell()),2)
def footer_hint_x() -> U32: U32.sub(width(),208)
def footer_second_columns() -> U32: U32.sub(U32.div(footer_hint_x(),cell()),2)

def attachment_entry_x() -> U32: 696
def attachment_entry_right() -> U32: 800
def attachment_entry_columns() -> U32: 11
def text_actions_x() -> U32: 808
def text_action_width() -> U32: 96
def text_actions_y() -> U32: 120
def control_height() -> U32: 32
def text_action_x(index: U32) -> U32:
  U32.add(text_actions_x(),U32.mul(index,text_action_width()))

def status_copy_x() -> U32: 896
def status_close_x() -> U32: 1088
def status_right() -> U32: U32.sub(width(),8)
def status_heading_columns() -> U32: 44
def capture_hint_x() -> U32: 688
def capture_hint_columns() -> U32: 19

def rect(+x: U32,+y: U32,left: U32,top: U32,right: U32,bottom: U32) -> Bool:
  Region.contains(Region.Rect{left,top,right,bottom},x,y)

def attachment_entry_contains(x: U32,y: U32) -> Bool:
  rect(x,y,attachment_entry_x(),text_actions_y(),attachment_entry_right(),U32.add(text_actions_y(),control_height()))

def sidebar_y(index: U32) -> U32:
  U32.add(112,U32.mul(index,control_height()))

# The History workspace groups destinations, capture actions, and library
# controls. Logical action IDs remain the coordinator's existing contract.
def sidebar_action_index.normal(index: U32) -> U32:
  match index:
    case 0: 18
    case 1: 0
    case 2: 6
    case 3: 10
    case 4: 99
    case 5: 5
    case 6: 7
    case 7: 8
    case 8: 9
    case 9: 12
    case 10: 14
    case 11: 16
    case 12: 19
    case 13: 11
    case 14: 4
    case 15: 17
    case _: 99

def provider_x(index: U32) -> U32:
  U32.add(192,U32.mul(index,104))
def provider_y() -> U32: 152
def provider_width() -> U32: 96
def provider_bounds(+index: U32) -> Region.Rect:
  Region.Rect{provider_x(index),provider_y(),U32.add(provider_x(index),provider_width()),U32.add(provider_y(),24)}
def provider_region(+index: U32) -> Region.ControlRegion:
  Region.ControlRegion{index,provider_bounds(index),True{},False{}}
def provider_contains(x: U32,y: U32,index: U32) -> Bool:
  Region.contains(provider_bounds(index),x,y)
def provider_hit(result: Maybe<&2,U32>) -> U32:
  match result:
    case Some{index}: index
    case None{}: 99
def provider_index(x: U32,y: U32) -> U32:
  provider_hit(Region.hit(3n,[provider_region(0),provider_region(1),provider_region(2)],x,y))

def sidebar_action_index.valid(+index: U32,inside: Bool,settings: Bool,brief: Bool) -> U32:
  match inside settings brief:
    case False{} _ _: 99
    case True{} _ True{}: Bool.pick(U32,U32.is_lt(index,7),index,99)
    case True{} True{} False{}: Bool.pick(U32,U32.is_eq(index,15),17,index)
    case True{} False{} False{}: sidebar_action_index.normal(index)

def sidebar_action_index(+index: U32,settings: Bool,brief: Bool) -> U32:
  sidebar_action_index.valid(index,U32.is_lt(index,sidebar_rows()),settings,brief)

def side_contains(+y: U32,index: U32) -> Bool:
  +top = sidebar_y(index)
  (y >= top && y < U32.add(top,control_height()) : U32)

def side_index.go(fuel: Nat,+y: U32,+index: U32,inside: Bool) -> U32:
  match fuel inside:
    case 0n _: 99
    case 1n+n True{}: index
    case 1n+n False{}:
      side_index.go(n,y,U32.add(index,1),side_contains(y,U32.add(index,1)))

def side_index(+y: U32) -> U32:
  side_index.go(U32.to_nat(sidebar_rows()),y,0,side_contains(y,0))

def top_x(index: U32) -> U32:
  match index:
    case 0: 8
    case 1: 152
    case 2: 296
    case 3: 416
    case 4: 536
    case 5: 848
    case _: 1024

def top_width(index: U32) -> U32:
  match index:
    case 0: 136
    case 1: 136
    case 2: 112
    case 3: 112
    # Keep the capture-status area (688..839) outside every toolbar target.
    case 4: 144
    case _: 168

def top_contains(+x: U32,+index: U32) -> Bool:
  +left = top_x(index)
  (x >= left && x < U32.add(left,top_width(index)) : U32)

def top_index.go(fuel: Nat,+x: U32,+index: U32,inside: Bool) -> U32:
  match fuel inside:
    case 0n _: 99
    case 1n+n True{}: index
    case 1n+n False{}:
      top_index.go(n,x,U32.add(index,1),top_contains(x,U32.add(index,1)))

def top_index(+x: U32) -> U32:
  top_index.go(7n,x,0,top_contains(x,0))
