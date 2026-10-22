import Base
import ../attachment_image_types.bend as T
import ./inflate_bits.bend as Bits
import ./inflate_huffman.bend as H

type Tables is Data:
  Tables{literal: H.Tree,distance: H.Tree}
type Parsed is Data:
  Parsed{cursor: Bits.Cursor,tables: Tables}
type Width is Data:
  Width{symbol: U32,value: U32}
type Widths is Data:
  Widths{cursor: Bits.Cursor,values: List<&2,Width>}
type Lengths is Data:
  Lengths{cursor: Bits.Cursor,values: List<&2,U32>}

def unpack(-R: Type,value: Tables,next: H.Tree -> H.Tree -> R) -> R:
  Tables{literal,distance} = value
  next(literal,distance)

def unpack_parsed(-R: Type,value: Parsed,next: Bits.Cursor -> H.Tree -> H.Tree -> R) -> R:
  Parsed{cursor,Tables{literal,distance}} = value
  next(cursor,literal,distance)

def unpack_widths(-R: Type,value: Widths,next: Bits.Cursor -> List<&2,Width> -> R) -> R:
  Widths{cursor,values} = value
  next(cursor,values)

def unpack_lengths(-R: Type,value: Lengths,next: Bits.Cursor -> List<&2,U32> -> R) -> R:
  Lengths{cursor,values} = value
  next(cursor,values)

def repeat(fuel: Nat,+value: U32,tail: List<&2,U32>) -> List<&2,U32>:
  match fuel:
    case 0n: tail
    case 1n+rest: repeat(rest,value,Con{value,tail})

def fixed() -> Result<&2,&2,T.Failure,Tables>:
  do Result<&2,&2,T.Failure,Tables>:
    literal : H.Tree <- H.make(repeat(144n,8,repeat(112n,9,repeat(24n,7,repeat(8n,8,Nil{})))),False{},False{})
    distance : H.Tree <- H.make(repeat(32n,5,Nil{}),False{},False{})
    Done{Tables{literal,distance}}

def order() -> List<&2,U32>:
  [16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15]

def code_widths(fuel: Nat,order: List<&2,U32>,cursor: Bits.Cursor,rev: List<&2,Width>) -> Result<&2,&2,T.Failure,Widths>:
  match fuel order:
    case 0n _: Done{Widths{cursor,rev}}
    case 1n+_ Nil{}: Fail{T.Failure{T.CompressedData{},"Too many code-length codes"}}
    case 1n+rest Con{symbol,tail}:
      do Result<&2,&2,T.Failure,Widths>:
        next : Bits.Read <- Bits.read(cursor,3)
        Bits.unpack(Result<&2,&2,T.Failure,Widths>,next,next_cursor => value =>
          code_widths(rest,tail,next_cursor,Con{Width{symbol,value},rev}))

def find_width(values: List<&2,Width>,+wanted: U32) -> U32:
  match values:
    case Nil{}: 0
    case Con{Width{symbol,value},tail}:
      T.branch(U32,U32.is_eq(symbol,wanted),_ => value,_ => find_width(tail,wanted))

def sorted_widths(fuel: Nat,+values: List<&2,Width>,+symbol: U32) -> List<&2,U32>:
  match fuel:
    case 0n: Nil{}
    case 1n+rest: Con{find_width(values,symbol),sorted_widths(rest,values,U32.inc(symbol))}

def repeat_field(cursor: Bits.Cursor,+symbol: U32,+previous: U32,+written: U32) -> Result<&2,&2,T.Failure,Bits.Read>:
  do Result<&2,&2,T.Failure,Bits.Read>:
    _ : Unit <- T.require(U32.is_ge(symbol,16) && U32.is_le(symbol,18) && (U32.is_ne(symbol,16) || U32.is_gt(written,0)),T.CompressedData{},"Invalid DEFLATE code-length repeat")
    +width : U32 = Bool.pick(U32,U32.is_eq(symbol,16),2,Bool.pick(U32,U32.is_eq(symbol,17),3,7))
    +base : U32 = Bool.pick(U32,U32.is_eq(symbol,18),11,3)
    next : Bits.Read <- Bits.read(cursor,width)
    Bits.unpack(Result<&2,&2,T.Failure,Bits.Read>,next,next_cursor => value =>
      Done{Bits.Read{next_cursor,U32.add(base,value)}})

# Count-bearing continuation keeps repeat expansion bounded across the literal
# and distance alphabet boundary. Zero runs update the previous length to zero.
type Expanded is Data:
  Expanded{cursor: Bits.Cursor,remaining: U32,written: U32,previous: U32,rev: List<&2,U32>}

def unpack_expanded(-R: Type,value: Expanded,next: Bits.Cursor -> U32 -> U32 -> U32 -> List<&2,U32> -> R) -> R:
  Expanded{cursor,remaining,written,previous,rev} = value
  next(cursor,remaining,written,previous,rev)

def expand(cursor: Bits.Cursor,+symbol: U32,+remaining: U32,+written: U32,+previous: U32,rev: List<&2,U32>,literal: Bool) -> Result<&2,&2,T.Failure,Expanded>:
  match literal:
    case True{}: Done{Expanded{cursor,U32.sub(remaining,1),U32.inc(written),symbol,Con{symbol,rev}}}
    case False{}:
      do Result<&2,&2,T.Failure,Expanded>:
        next : Bits.Read <- repeat_field(cursor,symbol,previous,written)
        Bits.unpack(Result<&2,&2,T.Failure,Expanded>,next,next_cursor => amount =>
          do Result<&2,&2,T.Failure,Expanded>:
            +count : U32 = amount
            _ : Unit <- T.require(U32.is_le(count,remaining),T.CompressedData{},"DEFLATE code-length repeat exceeds alphabet")
            +value : U32 = Bool.pick(U32,U32.is_eq(symbol,16),previous,0)
            Done{Expanded{next_cursor,U32.sub(remaining,count),U32.add(written,count),value,repeat(U32.to_nat(count),value,rev)}})

def lengths(fuel: Nat,remaining: U32,+tree: H.Tree,cursor: Bits.Cursor,written: U32,previous: U32,rev: List<&2,U32>) -> Result<&2,&2,T.Failure,Lengths>:
  match fuel remaining:
    case _ 0: Done{Lengths{cursor,List.reverse(&2,U32,rev)}}
    case 0n _: Fail{T.Failure{T.CompressedData{},"DEFLATE code-length description exceeds alphabet bound"}}
    case 1n+rest left:
      do Result<&2,&2,T.Failure,Lengths>:
        next : Bits.Read <- H.symbol(15n,tree,cursor)
        Bits.unpack(Result<&2,&2,T.Failure,Lengths>,next,next_cursor => decoded_symbol =>
          do Result<&2,&2,T.Failure,Lengths>:
            +symbol : U32 = decoded_symbol
            expanded : Expanded <- expand(next_cursor,symbol,left,written,previous,rev,U32.is_le(symbol,15))
            unpack_expanded(Result<&2,&2,T.Failure,Lengths>,expanded,cursor1 => left1 => written1 => previous1 => rev1 =>
              lengths(rest,left1,tree,cursor1,written1,previous1,rev1)))

def at(values: List<&2,U32>,index: Nat) -> U32:
  match values index:
    case Nil{} _: 0
    case Con{value,_} 0n: value
    case Con{_,tail} 1n+rest: at(tail,rest)

def dynamic(cursor: Bits.Cursor) -> Result<&2,&2,T.Failure,Parsed>:
  do Result<&2,&2,T.Failure,Parsed>:
    p1 : Bits.Read <- Bits.read(cursor,5)
    Bits.unpack(Result<&2,&2,T.Failure,Parsed>,p1,c1 => literal_field =>
      do Result<&2,&2,T.Failure,Parsed>:
        +hlit : U32 = literal_field
        _ : Unit <- T.require(U32.is_le(hlit,29),T.CompressedData{},"Reserved dynamic literal alphabet size")
        p2 : Bits.Read <- Bits.read(c1,5)
        Bits.unpack(Result<&2,&2,T.Failure,Parsed>,p2,c2 => hdist =>
          do Result<&2,&2,T.Failure,Parsed>:
            p3 : Bits.Read <- Bits.read(c2,4)
            Bits.unpack(Result<&2,&2,T.Failure,Parsed>,p3,c3 => hclen =>
              do Result<&2,&2,T.Failure,Parsed>:
                +literal_count : U32 = U32.add(hlit,257)
                distance_count : U32 = U32.inc(hdist)
                +total : U32 = U32.add(literal_count,distance_count)
                declared : Widths <- code_widths(U32.to_nat(U32.add(hclen,4)),order(),c3,Nil{})
                unpack_widths(Result<&2,&2,T.Failure,Parsed>,declared,c4 => widths =>
                  do Result<&2,&2,T.Failure,Parsed>:
                    codes : H.Tree <- H.make(sorted_widths(19n,widths,0),False{},False{})
                    expanded : Lengths <- lengths(U32.to_nat(total),total,codes,c4,0,0,Nil{})
                    unpack_lengths(Result<&2,&2,T.Failure,Parsed>,expanded,c5 => values =>
                      do Result<&2,&2,T.Failure,Parsed>:
                        +all : List<&2,U32> = values
                        +literals : List<&2,U32> = List.take(&2,U32,all,U32.to_nat(literal_count))
                        distances : List<&2,U32> = List.drop(&2,U32,all,U32.to_nat(literal_count))
                        _ : Unit <- T.require(U32.is_gt(at(literals,256n),0),T.CompressedData{},"DEFLATE literal tree has no end-of-block code")
                        literal : H.Tree <- H.make(literals,True{},False{})
                        distance : H.Tree <- H.make(distances,True{},True{})
                        Done{Parsed{c5,Tables{literal,distance}}})))))
