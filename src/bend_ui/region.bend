import Base

# End coordinates are exclusive. Comparisons avoid coordinate additions and
# therefore cannot wrap at the U32 boundary.
type Rect is Data:
  Rect{left: U32,top: U32,right: U32,bottom: U32}

type ControlRegion is Data:
  ControlRegion{id: U32,bounds: Rect,enabled: Bool,focusable: Bool}

def contains(rect: Rect,+x: U32,+y: U32) -> Bool:
  Rect{+left,+top,+right,+bottom} = rect
  U32.is_lt(left,right) && U32.is_lt(top,bottom) &&
    U32.is_ge(x,left) && U32.is_lt(x,right) &&
    U32.is_ge(y,top) && U32.is_lt(y,bottom)

def hit_selected(found: Bool,id: U32,next: Unit -> Maybe<&2,U32>) -> Maybe<&2,U32>:
  match found:
    case True{}: Some{id}
    case False{}: next(Unit{})

# The first enabled hit in the inspected prefix wins, even when it cannot
# receive keyboard focus. A disabled region never intercepts another region.
def hit(fuel: Nat,regions: List<&2,ControlRegion>,+x: U32,+y: U32) -> Maybe<&2,U32>:
  match fuel regions:
    case 0n _: None{}
    case 1n+_ Nil{}: None{}
    case 1n+left ControlRegion{id,bounds,enabled,_} <> rest:
      hit_selected(enabled && contains(bounds,x,y),id,u => hit(left,rest,x,y))

type FocusScan is Data:
  FocusScan{first: Maybe<&2,U32>,last: Maybe<&2,U32>,before: Maybe<&2,U32>,after: Maybe<&2,U32>,found: Bool,seen: List<&2,U32>}

def same_id(current: Maybe<&2,U32>,id: U32) -> Bool:
  match current:
    case None{}: False{}
    case Some{value}: U32.is_eq(value,id)

def before_update(found: Bool,old: Maybe<&2,U32>,previous: Maybe<&2,U32>) -> Maybe<&2,U32>:
  match found:
    case False{}: old
    case True{}: previous

def after_update(found: Bool,old: Maybe<&2,U32>,id: U32) -> Maybe<&2,U32>:
  match found:
    case False{}: old
    case True{}: Maybe.or(&2,U32,old,Some{id})

def focus_add(+id: U32,current: Maybe<&2,U32>,scan: FocusScan) -> FocusScan:
  FocusScan{first,+last,before,after,+found,seen} = scan
  +matches = same_id(current,id)
  FocusScan{Maybe.or(&2,U32,first,Some{id}),Some{id},
    before_update(matches && Bool.not(found),before,last),
    after_update(found,after,id),found || matches,id <> seen}

def focus_unique(duplicate: Bool,id: U32,current: Maybe<&2,U32>,scan: FocusScan) -> FocusScan:
  match duplicate:
    case True{}: scan
    case False{}: focus_add(id,current,scan)

def focus_enabled(enabled: Bool,+id: U32,current: Maybe<&2,U32>,+scan: FocusScan) -> FocusScan:
  match enabled:
    case False{}: scan
    case True{}:
      FocusScan{_,_,_,_,_,seen} = scan
      focus_unique(List.contains(~U32,~U32.is_eq,seen,id),id,current,scan)

def focus_finish(backward: Bool,scan: FocusScan) -> Maybe<&2,U32>:
  FocusScan{first,last,before,after,_,_} = scan
  Bool.pick(Maybe<&2,U32>,backward,Maybe.or(&2,U32,before,last),Maybe.or(&2,U32,after,first))

# A focus traversal must inspect the complete list before it may wrap. Fuel
# exhaustion with uninspected controls returns None rather than a partial wrap.
# Only enabled+focusable controls participate. None/unknown current chooses
# first forward or last backward. Only the first eligible occurrence of each ID
# participates; later duplicates still consume fuel but cannot trap a cycle.
def focus_walk(fuel: Nat,regions: List<&2,ControlRegion>,+current: Maybe<&2,U32>,backward: Bool,scan: FocusScan) -> Maybe<&2,U32>:
  match fuel regions:
    case 0n Nil{}: focus_finish(backward,scan)
    case 0n _: None{}
    case 1n+_ Nil{}: focus_finish(backward,scan)
    case 1n+left ControlRegion{id,_,enabled,focusable} <> rest:
      focus_walk(left,rest,current,backward,focus_enabled(enabled && focusable,id,current,scan))

def next_focus(fuel: Nat,regions: List<&2,ControlRegion>,current: Maybe<&2,U32>,backward: Bool) -> Maybe<&2,U32>:
  focus_walk(fuel,regions,current,backward,FocusScan{None{},None{},None{},None{},False{},[]})
