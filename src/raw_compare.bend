import Base

# Compare original retained BLOB chunks against one source-read buffer without
# flattening, copying, slicing or decoding either side. This is only equality:
# callers still own raw type, digest, length, coverage and identity validation.
# Empty chunks are allowed; success requires both inputs to be fully exhausted.
# U32 equality is exact even outside the byte range accepted by the SQL bridge.

# The byte loop never receives or touches the outer chunk-list spine. Every
# byte transition is a direct self-tail call; the equality bit avoids a pending
# Bool.and continuation. Some returns the unconsumed source after one chunk.
def consume(current: List<&2,U32>,source: List<&2,U32>,same: Bool) ->
  Maybe<&2,List<&2,U32>>:
  match current source same:
    case _ _ False{}:
      None{}
    case Nil{} remaining True{}:
      Some{remaining}
    case Con{_,_} Nil{} True{}:
      None{}
    case Con{wanted,tail} Con{actual,rest} True{}:
      consume(tail,rest,U32.is_eq(wanted,actual))

def walk(chunks: List<&2,List<&2,U32>>,source: Maybe<&2,List<&2,U32>>) -> Bool:
  match chunks source:
    case _ None{}:
      False{}
    case Nil{} Some{remaining}:
      List.is_empty(&2,U32,remaining)
    case Con{chunk,rest} Some{remaining}:
      walk(rest,consume(chunk,remaining,True{}))

def equal(chunks: List<&2,List<&2,U32>>,source: List<&2,U32>) -> Bool:
  walk(chunks,Some{source})
