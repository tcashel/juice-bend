import Base

# Byte equality across unrelated chunk boundaries. No strings or whole logical
# output flattening. Both nesting levels have explicit structural descent.
type Cursor is Data:
  Cursor{current: List<&2,U32>,rest: List<&2,List<&2,U32>>}

def normalize(rest: List<&2,List<&2,U32>>,current: List<&2,U32>) -> Cursor:
  match rest current:
    case remaining Con{byte,tail}:
      Cursor{Con{byte,tail},remaining}
    case Nil{} Nil{}:
      Cursor{[],[]}
    case Con{head,tail} Nil{}:
      normalize(tail,head)

def matching(valid: Bool,cursor: Cursor,next: Cursor -> Maybe<&2,Cursor>) -> Maybe<&2,Cursor>:
  match valid:
    case False{}: None{}
    case True{}: next(cursor)

def step(cursor: Cursor,wanted: U32,next: Cursor -> Maybe<&2,Cursor>) -> Maybe<&2,Cursor>:
  match cursor:
    case Cursor{Nil{},_}:
      None{}
    case Cursor{Con{actual,tail},rest}:
      matching(U32.is_eq(wanted,actual),Cursor{tail,rest},next)

def consume(bytes: List<&2,U32>,cursor: Cursor) -> Maybe<&2,Cursor>:
  match bytes:
    case Nil{}: Some{cursor}
    case Con{byte,rest}:
      Cursor{head,tail} = cursor
      step(normalize(tail,head),byte,next => consume(rest,next))

def walk(chunks: List<&2,List<&2,U32>>,cursor: Maybe<&2,Cursor>) -> Maybe<&2,Cursor>:
  match chunks cursor:
    case _ None{}: None{}
    case Nil{} Some{remaining}: Some{remaining}
    case Con{head,tail} Some{remaining}:
      walk(tail,consume(head,remaining))

def success(result: Maybe<&2,Cursor>) -> Bool:
  match result:
    case None{}: False{}
    case Some{_}: True{}

def empty(cursor: Cursor) -> Bool:
  match cursor:
    case Cursor{Nil{},Nil{}}: True{}
    case _: False{}

def finished(result: Maybe<&2,Cursor>) -> Bool:
  match result:
    case None{}: False{}
    case Some{Cursor{head,tail}}: empty(normalize(tail,head))

def prefix(expected: List<&2,List<&2,U32>>,actual: List<&2,List<&2,U32>>) -> Bool:
  success(walk(expected,Some{Cursor{[],actual}}))

def equal(expected: List<&2,List<&2,U32>>,actual: List<&2,List<&2,U32>>) -> Bool:
  finished(walk(expected,Some{Cursor{[],actual}}))
