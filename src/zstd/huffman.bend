import Base
import ./pair.bend as DataPair
import ./bits.bend as Bits
import ./bytes.bend as Bytes
import ./fse.bend as FSE

# Zstandard v1.5.7 format, Huffman tree and stream sections. All symbols are
# bytes. Immutable prefix trees have at most 11 levels and 256 leaves.
type Tree is Data:
  Empty{}
  Leaf{symbol: U32}
  Branch{zero: Tree,one: Tree}

type WeightStep is Data:
  Weights{values: List<&2,U32>}
  Continue{cursor: Bits.Rev,current: U32,other: U32,rev: List<&2,U32>,count: U32}

def require(valid: Bool,message: String) -> Result<&2,&2,String,Unit>:
  match valid:
    case False{}: Fail{message}
    case True{}: Done{Unit{}}

def direct(fuel: Nat,bytes: List<&2,U32>,rev: List<&2,U32>,phase: U32,byte: U32) ->
  Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
  match fuel phase:
    case 0n _: Done{(List.reverse(&2,U32,rev),bytes)}
    case 1n+rest 0:
      do Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
        +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
        +next : U32 = DataPair.first(U32,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
        direct(rest,tail,Con{U32.shrn(next,4n),rev},1,next)
    case 1n+rest _:
      direct(rest,bytes,Con{U32.and(byte,15),rev},0,0)

def weight_symbol(entry: FSE.Entry) -> U32:
  FSE.Entry{symbol,_,_} = entry
  symbol

def weights_step(+table: FSE.Table,cursor: Bits.Rev,other: U32,symbol: U32,bits: U32,base: U32,
  rev: List<&2,U32>,+count: U32,terminal: Bool) -> Result<&2,&2,String,WeightStep>:
  match terminal:
    case True{}:
      do Result<&2,&2,String,WeightStep>:
        _ : Unit <- require(U32.is_le(count,253),"Huffman weight count exceeds 255")
        entry : FSE.Entry <- FSE.lookup(table,other)
        Done{Weights{List.reverse(&2,U32,Con{weight_symbol(entry),Con{symbol,rev}})}}
    case False{}:
      do Result<&2,&2,String,WeightStep>:
        _ : Unit <- require(U32.is_lt(count,255),"Huffman weight count exceeds 255")
        +pair : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor,bits)
        next : Bits.Rev = DataPair.first(Bits.Rev,U32,pair)
        value : U32 = DataPair.second(Bits.Rev,U32,pair)
        Done{Continue{next,other,U32.add(base,value),Con{symbol,rev},U32.add(count,1)}}

def weights_entry(entry: FSE.Entry,table: FSE.Table,+cursor: Bits.Rev,other: U32,
  rev: List<&2,U32>,count: U32) -> Result<&2,&2,String,WeightStep>:
  FSE.Entry{symbol,+bits,base} = entry
  weights_step(table,cursor,other,symbol,bits,base,rev,count,U32.is_gt(bits,Bits.remaining_reverse(cursor)))

def weights_transition(+table: FSE.Table,+cursor: Bits.Rev,current: U32,other: U32,
  rev: List<&2,U32>,count: U32) -> Result<&2,&2,String,WeightStep>:
  do Result<&2,&2,String,WeightStep>:
    entry : FSE.Entry <- FSE.lookup(table,current)
    weights_entry(entry,table,cursor,other,rev,count)

def weights_loop(fuel: Nat,+table: FSE.Table,status: Result<&2,&2,String,WeightStep>) ->
  Result<&2,&2,String,List<&2,U32>>:
  match fuel status:
    case _ Fail{error}: Fail{error}
    case _ Done{Weights{values}}: Done{values}
    case 0n Done{Continue{_,_,_,_,_}}: Fail{"Huffman weight count exceeds 255"}
    case 1n+rest Done{Continue{cursor,current,other,rev,count}}:
      weights_loop(rest,table,weights_transition(table,cursor,current,other,rev,count))

def compressed_weights(bytes: List<&2,U32>) -> Result<&2,&2,String,List<&2,U32>>:
  do Result<&2,&2,String,List<&2,U32>>:
    +parsed : DataPair.Duo(FSE.Table,List<&2,U32>) <- FSE.read_table(bytes,11,6)
    +table : FSE.Table = DataPair.first(FSE.Table,List<&2,U32>,parsed)
    stream : List<&2,U32> = DataPair.second(FSE.Table,List<&2,U32>,parsed)
    cursor : Bits.Rev <- Bits.reverse(stream)
    +pair1 : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor,FSE.accuracy(table))
    cursor1 : Bits.Rev = DataPair.first(Bits.Rev,U32,pair1)
    state1 : U32 = DataPair.second(Bits.Rev,U32,pair1)
    +pair2 : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor1,FSE.accuracy(table))
    cursor2 : Bits.Rev = DataPair.first(Bits.Rev,U32,pair2)
    state2 : U32 = DataPair.second(Bits.Rev,U32,pair2)
    weights_loop(256n,table,Done{Continue{cursor2,state1,state2,Nil{},0}})

def read_weights_kind(header: U32,bytes: List<&2,U32>,compressed: Bool) ->
  Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
  match compressed:
    case False{}: direct(U32.to_nat(U32.sub(header,127)),bytes,Nil{},0,0)
    case True{}:
      do Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
        +pair : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(bytes,header)
        description : List<&2,U32> = DataPair.first(List<&2,U32>,List<&2,U32>,pair)
        tail : List<&2,U32> = DataPair.second(List<&2,U32>,List<&2,U32>,pair)
        weights : List<&2,U32> <- compressed_weights(description)
        Done{(weights,tail)}

def read_weights(bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(List<&2,U32>,List<&2,U32>)>:
    +pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
    +header : U32 = DataPair.first(U32,List<&2,U32>,pair)
    tail : List<&2,U32> = DataPair.second(U32,List<&2,U32>,pair)
    read_weights_kind(header,tail,U32.is_lt(header,128))

def weight_value(weight: U32) -> U32:
  match weight:
    case 0: 0
    case _: U32.shln(1,U32.to_nat(U32.sub(weight,1)))

def totals(weights: List<&2,U32>,sum: U32,ones: U32,+count: U32) ->
  Result<&2,&2,String,DataPair.Duo(U32,DataPair.Duo(U32,U32))>:
  match weights:
    case Nil{}: Done{(sum,(ones,count))}
    case Con{+weight,tail}:
      do Result<&2,&2,String,DataPair.Duo(U32,DataPair.Duo(U32,U32))>:
        _ : Unit <- require(U32.is_le(weight,11) && U32.is_lt(count,255),"invalid Huffman weight or too many literal symbols")
        totals(tail,U32.add(sum,weight_value(weight)),U32.add(ones,Bool.to_u32(U32.is_eq(weight,1))),U32.add(count,1))

def route(tree: Tree,direction: U32) -> Result<&2,&2,String,DataPair.Duo(Tree,Tree)>:
  match tree direction:
    case Empty{} _: Done{(Empty{},Empty{})}
    case Branch{zero,one} 0: Done{(zero,one)}
    case Branch{zero,one} _: Done{(one,zero)}
    case Leaf{_} _: Fail{"Huffman prefix collides with existing symbol"}

def restore(selected: Tree,other: Tree,direction: U32) -> Tree:
  match direction:
    case 0: Branch{selected,other}
    case _: Branch{other,selected}

def insert(fuel: Nat,tree: Tree,+code: U32,symbol: U32) -> Result<&2,&2,String,Tree>:
  match fuel tree:
    case 0n Empty{}: Done{Leaf{symbol}}
    case 0n _: Fail{"duplicate Huffman prefix"}
    case 1n+ +rest current:
      do Result<&2,&2,String,Tree>:
        +direction : U32 = U32.and(U32.shrn(code,rest),1)
        +pair : DataPair.Duo(Tree,Tree) <- route(current,direction)
        selected : Tree = DataPair.first(Tree,Tree,pair)
        other : Tree = DataPair.second(Tree,Tree,pair)
        next : Tree <- insert(rest,selected,code,symbol)
        Done{restore(next,other,direction)}

def assign_one(+weight: U32,depth: U32,symbol: U32,tree: Tree,+cursor: U32,selected: Bool) ->
  Result<&2,&2,String,DataPair.Duo(Tree,U32)>:
  match selected:
    case False{}: Done{(tree,cursor)}
    case True{}:
      do Result<&2,&2,String,DataPair.Duo(Tree,U32)>:
        next : Tree <- insert(U32.to_nat(U32.sub(U32.add(depth,1),weight)),tree,U32.shrn(cursor,U32.to_nat(U32.sub(weight,1))),symbol)
        Done{(next,U32.add(cursor,weight_value(weight)))}

def assign(weights: List<&2,U32>,+weight: U32,+depth: U32,+symbol: U32,tree: Tree,cursor: U32) ->
  Result<&2,&2,String,DataPair.Duo(Tree,U32)>:
  match weights:
    case Nil{}: Done{(tree,cursor)}
    case Con{actual,tail}:
      do Result<&2,&2,String,DataPair.Duo(Tree,U32)>:
        +pair : DataPair.Duo(Tree,U32) <- assign_one(weight,depth,symbol,tree,cursor,U32.is_eq(actual,weight))
        next : Tree = DataPair.first(Tree,U32,pair)
        position : U32 = DataPair.second(Tree,U32,pair)
        assign(tail,weight,depth,U32.add(symbol,1),next,position)

def assign_levels(fuel: Nat,+weights: List<&2,U32>,+depth: U32,+weight: U32,tree: Tree,cursor: U32) ->
  Result<&2,&2,String,DataPair.Duo(Tree,U32)>:
  match fuel:
    case 0n: Done{(tree,cursor)}
    case 1n+rest:
      do Result<&2,&2,String,DataPair.Duo(Tree,U32)>:
        +pair : DataPair.Duo(Tree,U32) <- assign(weights,weight,depth,0,tree,cursor)
        next : Tree = DataPair.first(Tree,U32,pair)
        position : U32 = DataPair.second(Tree,U32,pair)
        assign_levels(rest,weights,depth,U32.add(weight,1),next,position)

def make_nonempty(weights: List<&2,U32>,+sum: U32,ones: U32,count: U32,valid: Bool) -> Result<&2,&2,String,Tree>:
  match valid:
    case False{}: Fail{"empty Huffman weights"}
    case True{}:
      do Result<&2,&2,String,Tree>:
        +depth : U32 = U32.add(U32.from_nat(U32.log2(sum)),1)
        +missing : U32 = U32.sub(U32.shln(1,U32.to_nat(depth)),sum)
        +last : U32 = U32.add(U32.from_nat(U32.log2(missing)),1)
        +final_ones : U32 = U32.add(ones,Bool.to_u32(U32.is_eq(last,1)))
        _ : Unit <- require(U32.is_le(depth,11) && U32.is_le(last,11) && U32.is_eq(weight_value(last),missing) && U32.is_ge(final_ones,2) && U32.is_even(final_ones) && U32.is_ge(count,1),"invalid inferred Huffman weight or tree depth")
        +pair : DataPair.Duo(Tree,U32) <- assign_levels(11n,List.append(&2,U32,weights,Con{last,Nil{}}),depth,1,Empty{},0)
        tree : Tree = DataPair.first(Tree,U32,pair)
        filled : U32 = DataPair.second(Tree,U32,pair)
        _ : Unit <- require(U32.is_eq(filled,U32.shln(1,U32.to_nat(depth))),"Huffman tree does not fill probability space")
        Done{tree}

def make_tree(+weights: List<&2,U32>) -> Result<&2,&2,String,Tree>:
  do Result<&2,&2,String,Tree>:
    +summary : DataPair.Duo(U32,DataPair.Duo(U32,U32)) <- totals(weights,0,0,0)
    +sum : U32 = DataPair.first(U32,DataPair.Duo(U32,U32),summary)
    +counts : DataPair.Duo(U32,U32) = DataPair.second(U32,DataPair.Duo(U32,U32),summary)
    ones : U32 = DataPair.first(U32,U32,counts)
    count : U32 = DataPair.second(U32,U32,counts)
    make_nonempty(weights,sum,ones,count,U32.is_gt(sum,0))

def read_tree(bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(Tree,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(Tree,List<&2,U32>)>:
    +pair : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- read_weights(bytes)
    weights : List<&2,U32> = DataPair.first(List<&2,U32>,List<&2,U32>,pair)
    tail : List<&2,U32> = DataPair.second(List<&2,U32>,List<&2,U32>,pair)
    tree : Tree <- make_tree(weights)
    Done{(tree,tail)}

def choose(zero: Tree,one: Tree,direction: U32) -> Tree:
  match direction:
    case 0: zero
    case _: one

def decode_symbol(fuel: Nat,tree: Tree,cursor: Bits.Rev) -> Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>:
  match fuel tree:
    case _ Empty{}: Fail{"Huffman bitstream reached an absent prefix"}
    case _ Leaf{symbol}: Done{(cursor,symbol)}
    case 0n Branch{_,_}: Fail{"Huffman code exceeds depth 11"}
    case 1n+rest Branch{zero,one}:
      do Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>:
        +pair : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor,1)
        next : Bits.Rev = DataPair.first(Bits.Rev,U32,pair)
        bit : U32 = DataPair.second(Bits.Rev,U32,pair)
        decode_symbol(rest,choose(zero,one,bit),next)

def decoded_complete(rev: List<&2,U32>,complete: Bool) -> Result<&2,&2,String,List<&2,U32>>:
  match complete:
    case False{}: Fail{"Huffman stream has trailing bits"}
    case True{}: Done{List.reverse(&2,U32,rev)}

def decode_loop(fuel: Nat,+tree: Tree,cursor: Bits.Rev,rev: List<&2,U32>) ->
  Result<&2,&2,String,List<&2,U32>>:
  match fuel:
    case 0n: decoded_complete(rev,U32.is_eq(Bits.remaining_reverse(cursor),0))
    case 1n+rest:
      do Result<&2,&2,String,List<&2,U32>>:
        +pair : DataPair.Duo(Bits.Rev,U32) <- decode_symbol(11n,tree,cursor)
        next : Bits.Rev = DataPair.first(Bits.Rev,U32,pair)
        symbol : U32 = DataPair.second(Bits.Rev,U32,pair)
        decode_loop(rest,tree,next,Con{symbol,rev})

def decode_stream(tree: Tree,bytes: List<&2,U32>,+count: U32) -> Result<&2,&2,String,List<&2,U32>>:
  do Result<&2,&2,String,List<&2,U32>>:
    _ : Unit <- require(U32.is_le(count,131072),"Huffman output exceeds block limit")
    cursor : Bits.Rev <- Bits.reverse(bytes)
    decode_loop(U32.to_nat(count),tree,cursor,Nil{})
