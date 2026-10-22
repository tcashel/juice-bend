import Base
import ../src/bend_ui/region.bend as R

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def equals_id(value: Maybe<&2,U32>,want: U32) -> Bool:
  match value:
    case None{}: False{}
    case Some{id}: U32.is_eq(id,want)

def absent(value: Maybe<&2,U32>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def control(id: U32,left: U32,right: U32,enabled: Bool,focusable: Bool) -> R.ControlRegion:
  R.ControlRegion{id,R.Rect{left,10,right,20},enabled,focusable}

def controls() -> List<&2,R.ControlRegion>:
  [control(10,0,10,True{},True{}),control(20,10,20,False{},True{}),
    control(30,20,30,True{},False{}),control(40,30,40,True{},True{}),control(50,40,50,True{},True{})]

def rectangles() -> IO(Unit):
  do IO<Unit>:
    check(R.contains(R.Rect{10,20,30,40},10,20),"region includes its top-left boundary")
    check(R.contains(R.Rect{10,20,30,40},29,39),"region includes its last interior pixel")
    check(Bool.not(R.contains(R.Rect{10,20,30,40},30,20)),"region excludes its right edge")
    check(Bool.not(R.contains(R.Rect{10,20,30,40},10,40)),"region excludes its bottom edge")
    check(Bool.not(R.contains(R.Rect{10,20,30,40},9,20)),"region excludes a pixel left of its origin")
    check(Bool.not(R.contains(R.Rect{10,20,30,40},10,19)),"region excludes a pixel above its origin")
    check(Bool.not(R.contains(R.Rect{10,20,10,40},10,20)),"zero-width region is empty")
    check(Bool.not(R.contains(R.Rect{10,20,30,20},10,20)),"zero-height region is empty")
    check(Bool.not(R.contains(R.Rect{30,20,10,40},20,30)),"reversed horizontal bounds are invalid")
    check(Bool.not(R.contains(R.Rect{10,40,30,20},20,30)),"reversed vertical bounds are invalid")
    check(R.contains(R.Rect{4294967294,4294967294,4294967295,4294967295},4294967294,4294967294),"maximum end coordinates retain their final interior pixel")
    check(Bool.not(R.contains(R.Rect{4294967294,4294967294,4294967295,4294967295},4294967295,4294967295)),"maximum coordinates remain exclusive without wrap")

def pointer_hits() -> IO(Unit):
  do IO<Unit>:
    check(equals_id(R.hit(2n,[control(1,0,10,True{},True{}),control(2,10,20,True{},True{})],10,10),2),"adjacent controls share no active edge")
    check(equals_id(R.hit(2n,[control(1,0,20,True{},True{}),control(2,0,20,True{},True{})],5,10),1),"first enabled overlap wins in stable order")
    check(equals_id(R.hit(2n,[control(1,0,20,False{},True{}),control(2,0,20,True{},True{})],5,10),2),"disabled overlap cannot intercept a later enabled control")
    check(equals_id(R.hit(1n,[control(3,0,20,True{},False{})],5,10),3),"enabled nonfocusable control still receives a pointer hit")
    check(absent(R.hit(1n,[control(1,0,10,True{},True{}),control(2,10,20,True{},True{})],10,10)),"hit fuel never inspects a later region")
    check(absent(R.hit(0n,[control(1,0,10,True{},True{})],5,10)),"zero hit fuel does not inspect a region")
    check(absent(R.hit(5n,[],0,0)),"empty region list has no pointer hit")
    check(absent(R.hit(1n,[control(1,20,10,True{},True{})],15,10)),"invalid enabled region remains inert")
    check(equals_id(R.hit(1n,[control(4294967295,0,10,True{},True{})],0,10),4294967295),"control IDs retain the full U32 domain")

def focus() -> IO(Unit):
  do IO<Unit>:
    check(equals_id(R.next_focus(5n,controls(),None{},False{}),10),"forward focus begins at the first eligible control")
    check(equals_id(R.next_focus(5n,controls(),None{},True{}),50),"backward focus begins at the last eligible control")
    check(equals_id(R.next_focus(5n,controls(),Some{10},False{}),40),"forward focus skips disabled and nonfocusable controls")
    check(equals_id(R.next_focus(5n,controls(),Some{50},True{}),40),"backward focus preserves eligible order")
    check(equals_id(R.next_focus(5n,controls(),Some{40},True{}),10),"backward focus skips disabled and nonfocusable controls")
    check(equals_id(R.next_focus(5n,controls(),Some{50},False{}),10),"forward focus wraps to the first eligible control")
    check(equals_id(R.next_focus(5n,controls(),Some{10},True{}),50),"backward focus wraps to the last eligible control")
    check(equals_id(R.next_focus(5n,controls(),Some{99},False{}),10),"unknown current ID starts forward focus")
    check(equals_id(R.next_focus(5n,controls(),Some{99},True{}),50),"unknown current ID starts backward focus")
    check(equals_id(R.next_focus(5n,controls(),Some{20},False{}),10),"disabled current ID does not anchor traversal")
    check(equals_id(R.next_focus(5n,controls(),Some{30},True{}),50),"nonfocusable current ID does not anchor traversal")
    check(absent(R.next_focus(4n,controls(),Some{10},False{})),"incomplete focus scan cannot manufacture a wrapped result")
    check(absent(R.next_focus(0n,controls(),None{},False{})),"zero focus fuel refuses a nonempty list")
    check(absent(R.next_focus(0n,[],None{},True{})),"empty focus list needs no scan and has no target")
    check(absent(R.next_focus(2n,[control(1,0,10,False{},True{}),control(2,10,20,True{},False{})],None{},False{})),"no enabled focusable control means no focus target")
    check(equals_id(R.next_focus(1n,[control(0,0,10,True{},True{})],Some{0},False{}),0),"one eligible zero-ID control wraps to itself")
    check(equals_id(R.next_focus(1n,[control(4294967295,0,10,True{},True{})],Some{4294967295},True{}),4294967295),"one maximum-ID control wraps backward without arithmetic")
    check(equals_id(R.next_focus(3n,[control(1,0,10,True{},True{}),control(2,10,20,True{},True{}),control(1,20,30,True{},True{})],Some{1},False{}),2),"duplicate IDs anchor at the first eligible occurrence forward")
    check(equals_id(R.next_focus(3n,[control(1,0,10,True{},True{}),control(2,10,20,True{},True{}),control(1,20,30,True{},True{})],Some{1},True{}),2),"backward wrap ignores the later duplicate of its first eligible anchor")

def cycle(expected: List<&2,U32>,+fuel: Nat,+regions: List<&2,R.ControlRegion>,current: Maybe<&2,U32>,+backward: Bool) -> Bool:
  match expected:
    case Nil{}: True{}
    case want <> rest:
      +next = R.next_focus(fuel,regions,current,backward)
      equals_id(next,want) && cycle(rest,fuel,regions,next,backward)

def duplicates() -> IO(Unit):
  +adjacent : List<&2,R.ControlRegion> = [control(1,0,10,True{},True{}),control(1,10,20,True{},True{}),control(2,20,30,True{},True{})]
  +interleaved : List<&2,R.ControlRegion> = [control(1,0,10,True{},True{}),control(2,10,20,True{},True{}),control(1,20,30,True{},True{}),control(3,30,40,True{},True{})]
  +eligibility : List<&2,R.ControlRegion> = [control(1,0,10,False{},True{}),control(2,10,20,True{},True{}),control(1,20,30,True{},True{}),control(2,30,40,True{},False{}),control(3,40,50,True{},True{})]
  do IO<Unit>:
    check(cycle([2,1,2,1],3n,adjacent,Some{1},False{}),"repeated forward focus cannot get trapped at adjacent duplicate IDs")
    check(cycle([2,1,2,1],3n,adjacent,Some{1},True{}),"repeated backward focus cycles the same distinct adjacent IDs")
    check(cycle([2,3,1,2,3,1],4n,interleaved,Some{1},False{}),"repeated forward focus reaches every distinct interleaved ID before wrapping")
    check(cycle([3,2,1,3,2,1],4n,interleaved,Some{1},True{}),"repeated backward focus reverses distinct first-occurrence order")
    check(cycle([3,2,1,3,2,1],5n,eligibility,Some{1},False{}),"disabled and nonfocusable duplicates do not claim the first eligible occurrence")
    check(absent(R.next_focus(3n,interleaved,Some{1},False{})),"ignored duplicate regions still consume traversal fuel")
    check(cycle([1,1,1],2n,[control(1,0,10,True{},True{}),control(1,10,20,True{},True{})],Some{1},False{}),"one distinct eligible ID wraps to itself across repeated traversal")
    check(equals_id(R.next_focus(3n,[control(1,0,10,True{},True{}),control(2,10,20,True{},True{}),control(1,20,30,True{},True{})],None{},True{}),2),"unknown backward focus starts at the last distinct eligible ID")

def main() -> IO(Unit):
  do IO<Unit>:
    rectangles()
    pointer_hits()
    focus()
    duplicates()
