# One geometry contract for the fixed upstream 1408x896 window.
import Base

def cell() -> U32: 8
def reader_x() -> U32: 536
def reader_y() -> U32: 168
def reader_columns() -> U32: 104
def reader_rows() -> U32: 28
def line_pitch() -> U32: 24
def query_x() -> U32: 208
def query_y() -> U32: 32
def query_columns() -> U32: 146
def sidebar_end() -> U32: 176
def list_end() -> U32: 512
def list_y() -> U32: 184
def list_pitch() -> U32: 64
def list_rows() -> U32: 10
def list_pager_y() -> U32: 832
def footer_y() -> U32: 856

def text_actions_x() -> U32: 1000
def text_action_width() -> U32: 96
def text_actions_y() -> U32: 120
def control_height() -> U32: 32
def text_action_x(index: U32) -> U32:
  U32.add(text_actions_x(),U32.mul(index,text_action_width()))

def rect(+x: U32,+y: U32,left: U32,top: U32,right: U32,bottom: U32) -> Bool:
  (x >= left && x < right && y >= top && y < bottom : U32)

def sidebar_y(index: U32) -> U32:
  match index:
    case 0: 128
    case 1: 176
    case 2: 208
    case 3: 240
    case 4: 272
    case 5: 344
    case 6: 376
    case 7: 408
    case 8: 440
    case 9: 472
    case 10: 560
    case 11: 592
    case 12: 624
    case 13: 688
    case 14: 720
    case 15: 752
    case 16: 784
    case _: 824

def side_contains(+y: U32,index: U32) -> Bool:
  +top = sidebar_y(index)
  (y >= top && y < U32.add(top,32) : U32)

def side_index.go(fuel: Nat,+y: U32,+index: U32,inside: Bool) -> U32:
  match fuel inside:
    case 0n _: 99
    case 1n+n True{}: index
    case 1n+n False{}:
      side_index.go(n,y,U32.add(index,1),side_contains(y,U32.add(index,1)))

def side_index(+y: U32) -> U32:
  side_index.go(18n,y,0,side_contains(y,0))

def top_x(index: U32) -> U32:
  match index:
    case 0: 8
    case 1: 184
    case 2: 344
    case 3: 504
    case 4: 664
    case 5: 1048
    case _: 1208

def top_width(index: U32) -> U32:
  match index:
    case 0: 160
    case 6: 192
    case _: 152

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
