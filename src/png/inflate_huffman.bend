import Base
import ../attachment_image_types.bend as T
import ./inflate_bits.bend as Bits

# Canonical RFC1951 trees, at most 15 levels and 288 leaves. Zero lengths do
# not participate. Tree shape and code assignment are checked before decoding.
type Tree is Data:
  Empty{}
  Leaf{symbol: U32}
  Fork{zero: Tree,one: Tree}
type Summary is Data:
  Summary{count: U32,nonzero: U32,ones: U32,space: U32}
type Assigned is Data:
  Assigned{tree: Tree,code: U32}
type Halves is Data:
  Halves{selected: Tree,other: Tree}

def unpack_halves(-R: Type,value: Halves,next: Tree -> Tree -> R) -> R:
  Halves{selected,other} = value
  next(selected,other)

def unpack_assigned(-R: Type,value: Assigned,next: Tree -> U32 -> R) -> R:
  Assigned{tree,code} = value
  next(tree,code)

def unpack_summary(-R: Type,value: Summary,next: U32 -> U32 -> U32 -> U32 -> R) -> R:
  Summary{count,nonzero,ones,space} = value
  next(count,nonzero,ones,space)

def summary(lengths: List<&2,U32>,+count: U32,nonzero: U32,ones: U32,+space: U32) -> Result<&2,&2,T.Failure,Summary>:
  match lengths:
    case Nil{}: Done{Summary{count,nonzero,ones,space}}
    case Con{+width,tail}:
      do Result<&2,&2,T.Failure,Summary>:
        _ : Unit <- T.require(U32.is_lt(count,288) && U32.is_le(width,15),T.CompressedData{},"Invalid Huffman alphabet or code length")
        +weight : U32 = Bool.pick(U32,U32.is_eq(width,0),0,U32.shln(1,U32.to_nat(U32.sub(15,U32.min(width,15)))))
        _ : Unit <- T.require(U32.is_le(weight,U32.sub(32768,space)),T.CompressedData{},"Oversubscribed Huffman tree")
        summary(tail,U32.inc(count),U32.add(nonzero,Bool.to_u32(U32.is_ne(width,0))),U32.add(ones,Bool.to_u32(U32.is_eq(width,1))),U32.add(space,weight))

def route(tree: Tree,bit: U32) -> Result<&2,&2,T.Failure,Halves>:
  match tree bit:
    case Empty{} _: Done{Halves{Empty{},Empty{}}}
    case Fork{zero,one} 0: Done{Halves{zero,one}}
    case Fork{zero,one} _: Done{Halves{one,zero}}
    case Leaf{_} _: Fail{T.Failure{T.CompressedData{},"Huffman prefix collision"}}

def restore(selected: Tree,other: Tree,bit: U32) -> Tree:
  match bit:
    case 0: Fork{selected,other}
    case _: Fork{other,selected}

def insert(fuel: Nat,tree: Tree,+code: U32,symbol: U32) -> Result<&2,&2,T.Failure,Tree>:
  match fuel tree:
    case 0n Empty{}: Done{Leaf{symbol}}
    case 0n _: Fail{T.Failure{T.CompressedData{},"Duplicate Huffman code"}}
    case 1n+ +rest current:
      do Result<&2,&2,T.Failure,Tree>:
        +bit : U32 = U32.and(U32.shrn(code,rest),1)
        parts : Halves <- route(current,bit)
        unpack_halves(Result<&2,&2,T.Failure,Tree>,parts,selected => other =>
          do Result<&2,&2,T.Failure,Tree>:
            next : Tree <- insert(rest,selected,code,symbol)
            Done{restore(next,other,bit)})

def assign_one(tree: Tree,+width: U32,symbol: U32,+code: U32,selected: Bool) -> Result<&2,&2,T.Failure,Assigned>:
  match selected:
    case False{}: Done{Assigned{tree,code}}
    case True{}:
      do Result<&2,&2,T.Failure,Assigned>:
        _ : Unit <- T.require(U32.is_lt(code,U32.shln(1,U32.to_nat(width))),T.CompressedData{},"Huffman code exceeds its width")
        next : Tree <- insert(U32.to_nat(width),tree,code,symbol)
        Done{Assigned{next,U32.inc(code)}}

def assign(lengths: List<&2,U32>,+width: U32,+symbol: U32,tree: Tree,code: U32) -> Result<&2,&2,T.Failure,Assigned>:
  match lengths:
    case Nil{}: Done{Assigned{tree,code}}
    case Con{actual,tail}:
      do Result<&2,&2,T.Failure,Assigned>:
        next : Assigned <- assign_one(tree,width,symbol,code,U32.is_eq(actual,width))
        unpack_assigned(Result<&2,&2,T.Failure,Assigned>,next,next_tree => next_code =>
          assign(tail,width,U32.inc(symbol),next_tree,next_code))

def levels(fuel: Nat,+lengths: List<&2,U32>,+width: U32,tree: Tree,code: U32) -> Result<&2,&2,T.Failure,Tree>:
  match fuel:
    case 0n: Done{tree}
    case 1n+rest:
      do Result<&2,&2,T.Failure,Tree>:
        next : Assigned <- assign(lengths,width,0,tree,code)
        unpack_assigned(Result<&2,&2,T.Failure,Tree>,next,next_tree => next_code =>
          levels(rest,lengths,U32.inc(width),next_tree,U32.shl(next_code)))

# A one-symbol alphabet has a one-bit code, with one absent branch. The code
# length alphabet must be complete. An absent distance tree is admitted only
# for the RFC's single zero-length distance code and fails if actually used.
def make(+lengths: List<&2,U32>,allow_single: Bool,allow_empty: Bool) -> Result<&2,&2,T.Failure,Tree>:
  do Result<&2,&2,T.Failure,Tree>:
    totals : Summary <- summary(lengths,0,0,0,0)
    unpack_summary(Result<&2,&2,T.Failure,Tree>,totals,count => nonzero => ones => space =>
      do Result<&2,&2,T.Failure,Tree>:
        +used : U32 = nonzero
        _ : Unit <- T.require(U32.is_eq(space,32768) || (allow_single && U32.is_eq(used,1) && U32.is_eq(ones,1)) || (allow_empty && U32.is_eq(count,1) && U32.is_eq(used,0)),T.CompressedData{},"Incomplete Huffman tree")
        levels(15n,lengths,1,Empty{},0))

def choose(zero: Tree,one: Tree,bit: U32) -> Tree:
  match bit:
    case 0: zero
    case _: one

def symbol(fuel: Nat,tree: Tree,cursor: Bits.Cursor) -> Result<&2,&2,T.Failure,Bits.Read>:
  match fuel tree:
    case _ Empty{}: Fail{T.Failure{T.CompressedData{},"DEFLATE reached an absent Huffman code"}}
    case _ Leaf{value}: Done{Bits.Read{cursor,value}}
    case 0n Fork{_,_}: Fail{T.Failure{T.CompressedData{},"Huffman code exceeds 15 bits"}}
    case 1n+rest Fork{zero,one}:
      do Result<&2,&2,T.Failure,Bits.Read>:
        next : Bits.Read <- Bits.bit(cursor)
        Bits.unpack(Result<&2,&2,T.Failure,Bits.Read>,next,next_cursor => bit =>
          symbol(rest,choose(zero,one,bit),next_cursor))
