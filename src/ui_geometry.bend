# Compact fixed native content area. The pinned upstream Window API does not
# expose resizing or a display visible frame. Keep 8x16 type and 32px targets;
# consolidate only duplicate sidebar text actions into the reader toolbar.
import Base

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
def reader_title_columns() -> U32: 32
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
  (x >= left && x < right && y >= top && y < bottom : U32)

def sidebar_y(index: U32) -> U32:
  U32.add(112,U32.mul(index,control_height()))

# Logical action identities stay stable; only redundant visible rows disappear.
# Every remaining row uses this same mapping for painting and pointer dispatch.
def sidebar_action_index.normal(index: U32) -> U32:
  match index:
    case 13: 14
    case 14: 16
    case 15: 17
    case _: index

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
    case 4: 136
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
