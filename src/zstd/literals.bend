import Base
import ./pair.bend as DataPair
import ./bits.bend as Bits
import ./bytes.bend as Bytes
import ./huffman.bend as Huffman

type Header is Data:
  Header{kind: U32,count: U32,compressed: U32,streams: U32}

type Content is Data:
  Content{bytes: List<&2,U32>,table: Maybe<&2,Huffman.Tree>}

# Parameter-only destructuring keeps do blocks within the pinned grammar.

def with_number_tail(-R: Type,unpack_value: DataPair.Duo(U32,List<&2,U32>),unpack_continue: U32 -> List<&2,U32> -> R) -> R:
  (extra,tail) = unpack_value
  unpack_continue(extra,tail)

def with_forward_cursor(-R: Type,unpack_value: DataPair.Duo(Bits.Fwd,U32),unpack_continue: Bits.Fwd -> R) -> R:
  (cursor,_) = unpack_value
  unpack_continue(cursor)

def with_forward_value(-R: Type,unpack_value: DataPair.Duo(Bits.Fwd,U32),unpack_continue: Bits.Fwd -> U32 -> R) -> R:
  (cursor1,count) = unpack_value
  unpack_continue(cursor1,count)

def with_bytes_tail(-R: Type,unpack_value: DataPair.Duo(List<&2,U32>,List<&2,U32>),unpack_continue: List<&2,U32> -> List<&2,U32> -> R) -> R:
  (stream1,tail4) = unpack_value
  unpack_continue(stream1,tail4)

def with_tree_tail(-R: Type,unpack_value: DataPair.Duo(Huffman.Tree,List<&2,U32>),unpack_continue: Huffman.Tree -> List<&2,U32> -> R) -> R:
  (tree,stream) = unpack_value
  unpack_continue(tree,stream)

def with_header_fields(-R: Type,unpack_value: DataPair.Duo(Header,List<&2,U32>),unpack_continue: U32 -> U32 -> U32 -> U32 -> List<&2,U32> -> R) -> R:
  (Header{kind,count,size,streams},tail) = unpack_value
  unpack_continue(kind,count,size,streams,tail)

def raw_header(format: U32,kind: U32,+first: U32,bytes: List<&2,U32>) ->
  Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
  match format:
    case 1:
      do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,1)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>,pair,extra => tail =>
          do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
            Done{(Header{kind,U32.add(U32.shrn(first,4n),U32.shln(extra,4n)),0,1},tail)}
        )
    case 3:
      do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,2)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>,pair,extra => tail =>
          do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
            Done{(Header{kind,U32.add(U32.shrn(first,4n),U32.shln(extra,4n)),0,1},tail)}
        )
    case _: Done{(Header{kind,U32.shrn(first,3n),0,1},bytes)}

def field_width(format: U32) -> U32:
  match format:
    case 2: 14
    case 3: 18
    case _: 10

def compressed_header(+format: U32,kind: U32,first: U32,bytes: List<&2,U32>) ->
  Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
    first_pair : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(Bits.forward(Con{first,bytes}),4)
    with_forward_cursor(Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>,first_pair,cursor =>
      do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
        count_pair : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(cursor,field_width(format))
        with_forward_value(Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>,count_pair,cursor1 => count =>
          do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
            size_pair : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(cursor1,field_width(format))
            with_forward_value(Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>,size_pair,cursor2 => size =>
              do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
                Done{(Header{kind,count,size,Bool.pick(U32,U32.is_eq(format,0),1,4)},Bits.remaining_forward(cursor2))}
            )
        )
    )

def header_kind(+kind: U32,format: U32,first: U32,bytes: List<&2,U32>,compressed: Bool) ->
  Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
  match compressed:
    case False{}: raw_header(format,kind,first,bytes)
    case True{}: compressed_header(format,kind,first,bytes)

def header(bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
    pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
    with_number_tail(Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>,pair,+first => tail =>
      do Result<&2,&2,String,DataPair.Duo(Header,List<&2,U32>)>:
        +kind : U32 = U32.and(first,3)
        header_kind(kind,U32.and(U32.shrn(first,2n),3),first,tail,U32.is_ge(kind,2))
    )

def four(+tree: Huffman.Tree,bytes: List<&2,U32>,+count: U32) -> Result<&2,&2,String,List<&2,U32>>:
  do Result<&2,&2,String,List<&2,U32>>:
    _ : Unit <- Huffman.require(U32.is_ge(count,6) && U32.is_le(count,131072),"invalid four-stream literal count")
    first : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,2)
    with_number_tail(Result<&2,&2,String,List<&2,U32>>,first,size1 => tail1 =>
      do Result<&2,&2,String,List<&2,U32>>:
        second : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(tail1,2)
        with_number_tail(Result<&2,&2,String,List<&2,U32>>,second,size2 => tail2 =>
          do Result<&2,&2,String,List<&2,U32>>:
            third : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(tail2,2)
            with_number_tail(Result<&2,&2,String,List<&2,U32>>,third,size3 => tail3 =>
              do Result<&2,&2,String,List<&2,U32>>:
                p1 : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(tail3,size1)
                with_bytes_tail(Result<&2,&2,String,List<&2,U32>>,p1,stream1 => tail4 =>
                  do Result<&2,&2,String,List<&2,U32>>:
                    p2 : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(tail4,size2)
                    with_bytes_tail(Result<&2,&2,String,List<&2,U32>>,p2,stream2 => tail5 =>
                      do Result<&2,&2,String,List<&2,U32>>:
                        p3 : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(tail5,size3)
                        with_bytes_tail(Result<&2,&2,String,List<&2,U32>>,p3,stream3 => stream4 =>
                          do Result<&2,&2,String,List<&2,U32>>:
                            +quarter : U32 = U32.div(U32.add(count,3),4)
                            out1 : List<&2,U32> <- Huffman.decode_stream(tree,stream1,quarter)
                            out2 : List<&2,U32> <- Huffman.decode_stream(tree,stream2,quarter)
                            out3 : List<&2,U32> <- Huffman.decode_stream(tree,stream3,quarter)
                            out4 : List<&2,U32> <- Huffman.decode_stream(tree,stream4,U32.sub(count,U32.mul(quarter,3)))
                            Done{List.append(&2,U32,out1,List.append(&2,U32,out2,List.append(&2,U32,out3,out4)))}
                        )
                    )
                )
            )
        )
    )

def streams(streams: U32,tree: Huffman.Tree,bytes: List<&2,U32>,count: U32) -> Result<&2,&2,String,List<&2,U32>>:
  match streams:
    case 1: Huffman.decode_stream(tree,bytes,count)
    case _: four(tree,bytes,count)

def reuse(previous: Maybe<&2,Huffman.Tree>,bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(Huffman.Tree,List<&2,U32>)>:
  match previous:
    case None{}: Fail{"treeless literals have no previous Huffman table"}
    case Some{tree}: Done{(tree,bytes)}

def table(kind: U32,previous: Maybe<&2,Huffman.Tree>,bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(Huffman.Tree,List<&2,U32>)>:
  match kind:
    case 2: Huffman.read_tree(bytes)
    case _: reuse(previous,bytes)

def body(header: Header,previous: Maybe<&2,Huffman.Tree>,bytes: List<&2,U32>) ->
  Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
  match header:
    case Header{0,count,_,_}:
      do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
        pair : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(bytes,count)
        with_bytes_tail(Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>,pair,literal => tail =>
          do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
            Done{(Content{literal,previous},tail)}
        )
    case Header{1,count,_,_}:
      do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>,pair,byte => tail =>
          do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
            Done{(Content{Bytes.repeat(U32.to_nat(count),byte,Nil{}),previous},tail)}
        )
    case Header{kind,count,size,stream_count}:
      do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
        pair : DataPair.Duo(List<&2,U32>,List<&2,U32>) <- Bytes.take(bytes,size)
        with_bytes_tail(Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>,pair,compressed => tail =>
          do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
            described : DataPair.Duo(Huffman.Tree,List<&2,U32>) <- table(kind,previous,compressed)
            with_tree_tail(Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>,described,+tree => stream =>
              do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
                literal : List<&2,U32> <- streams(stream_count,tree,stream,count)
                Done{(Content{literal,Some{tree}},tail)}
            )
        )

def read(bytes: List<&2,U32>,previous: Maybe<&2,Huffman.Tree>,+maximum: U32) ->
  Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
    pair : DataPair.Duo(Header,List<&2,U32>) <- header(bytes)
    with_header_fields(Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>,pair,kind => +count => +size => streams => tail =>
      do Result<&2,&2,String,DataPair.Duo(Content,List<&2,U32>)>:
        _ : Unit <- Huffman.require(U32.is_le(maximum,131072) && U32.is_le(count,maximum) && U32.is_le(size,maximum),"literals exceed frame block maximum")
        body(Header{kind,count,size,streams},previous,tail)
    )
