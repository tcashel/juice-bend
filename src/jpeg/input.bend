import Base
import ./types.bend as T

type Part is Data:
  Part{bytes: List<&2,U32>,tail: List<&2,U32>}
type Marker is Data:
  Marker{code: U32,tail: List<&2,U32>}

def admitted(bytes: List<&2,U32>,+count: U32) -> Result<&2,&2,T.Failure,U32>:
  match bytes:
    case []: Done{count}
    case +value <> rest:
      do Result<&2,&2,T.Failure,U32>:
        _ : Unit <- T.require(U32.is_le(value,255),"invalid_input","JPEG input contains a non-octet")
        _ : Unit <- T.require(U32.is_lt(count,T.max_input()),"image_resource_limit","JPEG exceeds the retained-byte display limit")
        admitted(rest,U32.inc(count))

def take(fuel: Nat,bytes: List<&2,U32>,rev: List<&2,U32>) -> Result<&2,&2,T.Failure,Part>:
  match fuel bytes:
    case 0n tail: Done{Part{List.reverse(&2,U32,rev),tail}}
    case 1n+rest Con{value,tail}: take(rest,tail,value <> rev)
    case _ _: Fail{T.Failure{"invalid_jpeg","JPEG marker segment is truncated"}}

def word(high: U32,low: U32) -> U32:
  U32.or(U32.shln(high,8n),low)

def segment(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Part>:
  match bytes:
    case high <> low <> tail:
      do Result<&2,&2,T.Failure,Part>:
        +length : U32 = word(high,low)
        _ : Unit <- T.require(U32.is_ge(length,2),"invalid_jpeg","JPEG segment length is less than its own length field")
        take(U32.to_nat(U32.sub(length,2)),tail,[])
    case _: Fail{T.Failure{"invalid_jpeg","JPEG marker segment length is truncated"}}

def marker_fill(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Marker>:
  match bytes:
    case 255 <> rest: marker_fill(rest)
    case 0 <> _: Fail{T.Failure{"invalid_jpeg","Byte stuffing is only valid inside JPEG entropy data"}}
    case code <> tail: Done{Marker{code,tail}}
    case []: Fail{T.Failure{"invalid_jpeg","JPEG ends inside a marker prefix"}}

def marker(bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,Marker>:
  match bytes:
    case 255 <> rest: marker_fill(rest)
    case _: Fail{T.Failure{"invalid_jpeg","JPEG marker prefix is missing"}}

def at(fuel: Nat,bytes: List<&2,U32>) -> Result<&2,&2,T.Failure,U32>:
  match fuel bytes:
    case 0n Con{value,_}: Done{value}
    case 1n+rest Con{_,tail}: at(rest,tail)
    case _ _: Fail{T.Failure{"invalid_jpeg","JPEG metadata offset exceeds its segment"}}

def nth(bytes: List<&2,U32>,index: U32) -> Result<&2,&2,T.Failure,U32>:
  at(U32.to_nat(index),bytes)

def count(bytes: List<&2,U32>,value: U32) -> U32:
  match bytes:
    case []: value
    case _ <> rest: count(rest,U32.inc(value))
