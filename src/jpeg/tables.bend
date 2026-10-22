import Base
import ./types.bend as T
import ./input.bend as Input
import ./entropy.bend as Entropy

def quant_get(values: List<&2,T.Quantizer>,+id: U32) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  match values:
    case []: Fail{T.Failure{"invalid_jpeg","JPEG scan references an undefined quantization table"}}
    case T.Quantizer{key,items} <> rest:
      T.branch(Result<&2,&2,T.Failure,List<&2,U32>>,U32.is_eq(key,id),_ => Done{items},_ => quant_get(rest,id))

def huffman_get(values: List<&2,T.Table>,+kind: U32,+id: U32) -> Result<&2,&2,T.Failure,T.Huffman>:
  match values:
    case []: Fail{T.Failure{"invalid_jpeg","JPEG scan references an undefined Huffman table"}}
    case T.Table{class,key,items} <> rest:
      T.branch(Result<&2,&2,T.Failure,T.Huffman>,U32.is_eq(class,kind) && U32.is_eq(key,id),_ => Done{items},_ => huffman_get(rest,kind,id))

def quant_without(values: List<&2,T.Quantizer>,+id: U32) -> List<&2,T.Quantizer>:
  match values:
    case []: []
    case +item <> rest:
      T.Quantizer{key,_} = item
      +tail : List<&2,T.Quantizer> = quant_without(rest,id)
      Bool.pick(List<&2,T.Quantizer>,U32.is_eq(key,id),tail,item <> tail)

def huffman_without(values: List<&2,T.Table>,+kind: U32,+id: U32) -> List<&2,T.Table>:
  match values:
    case []: []
    case +item <> rest:
      T.Table{class,key,_} = item
      +tail : List<&2,T.Table> = huffman_without(rest,kind,id)
      Bool.pick(List<&2,T.Table>,U32.is_eq(class,kind) && U32.is_eq(key,id),tail,item <> tail)

def reusable(values: List<U32>) -> List<&2,U32>:
  match values:
    case []: []
    case value <> rest: value <> reusable(rest)

def natural(values: List<&2,U32>,array: Array<U32>,+index: U32) -> Result<&2,&1,T.Failure,Array<U32>>:
  match values:
    case []:
      do Result<&2,&1,T.Failure,Array<U32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_eq(index,64),"invalid_jpeg","JPEG quantizer must have exactly64 entries"))
        Done{array}
    case +value <> rest:
      do Result<&2,&1,T.Failure,Array<U32>>:
        _ : Unit <- T.widen(Unit,T.require(U32.is_lt(index,64) && U32.is_gt(value,0) && U32.is_le(value,255),"invalid_jpeg","Baseline JPEG quantizer is outside1..255"))
        target : U32 <- T.widen(U32,Entropy.zigzag(index))
        natural(rest,Array.set(U32,array,target,value),U32.inc(index))

def quant_ready(result: Result<&2,&1,T.Failure,Array<U32>>) -> Result<&2,&2,T.Failure,List<&2,U32>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{array}: Done{reusable(Array.to_list(U32,array))}

def quant_part(part: Input.Part,+id: U32,previous: List<&2,T.Quantizer>,next: List<&2,U32> -> List<&2,T.Quantizer> -> Result<&2,&2,T.Failure,List<&2,T.Quantizer>>) -> Result<&2,&2,T.Failure,List<&2,T.Quantizer>>:
  Input.Part{bytes,tail} = part
  do Result<&2,&2,T.Failure,List<&2,T.Quantizer>>:
    values : List<&2,U32> <- quant_ready(natural(bytes,Array.new(U32,6n,0),0))
    next(tail,T.Quantizer{id,values} <> quant_without(previous,id))

def quant_tables(fuel: Nat,bytes: List<&2,U32>,previous: List<&2,T.Quantizer>) -> Result<&2,&2,T.Failure,List<&2,T.Quantizer>>:
  match fuel bytes:
    case _ Nil{}: Done{previous}
    case 0n _: Fail{T.Failure{"image_resource_limit","JPEG quantization definitions exceed the segment bound"}}
    case 1n+rest Con{+header,tail}:
      do Result<&2,&2,T.Failure,List<&2,T.Quantizer>>:
        _ : Unit <- T.require(U32.is_eq(U32.shrn(header,4n),0),"unsupported_jpeg_mode","Sixteen-bit JPEG quantization is not yet displayed")
        +id : U32 = U32.and(header,15)
        _ : Unit <- T.require(U32.is_le(id,3),"invalid_jpeg","JPEG quantization selector is invalid")
        part : Input.Part <- Input.take(64n,tail,[])
        quant_part(part,id,previous,after => updated => quant_tables(rest,after,updated))

def sum(values: List<&2,U32>,total: U32) -> U32:
  match values:
    case []: total
    case value <> rest: sum(rest,U32.add(total,value))

def huffman_values(part: Input.Part,counts: List<&2,U32>,+kind: U32,+id: U32,previous: List<&2,T.Table>,next: List<&2,U32> -> List<&2,T.Table> -> Result<&2,&2,T.Failure,List<&2,T.Table>>) -> Result<&2,&2,T.Failure,List<&2,T.Table>>:
  Input.Part{symbols,tail} = part
  +table : T.Huffman = T.Huffman{counts,symbols}
  do Result<&2,&2,T.Failure,List<&2,T.Table>>:
    _ : Unit <- Entropy.validate(kind,table)
    next(tail,T.Table{kind,id,table} <> huffman_without(previous,kind,id))

def huffman_counts(part: Input.Part,kind: U32,id: U32,previous: List<&2,T.Table>,next: List<&2,U32> -> List<&2,T.Table> -> Result<&2,&2,T.Failure,List<&2,T.Table>>) -> Result<&2,&2,T.Failure,List<&2,T.Table>>:
  Input.Part{+counts,tail} = part
  +count : U32 = sum(counts,0)
  do Result<&2,&2,T.Failure,List<&2,T.Table>>:
    _ : Unit <- T.require(U32.is_gt(count,0) && U32.is_le(count,256),"invalid_jpeg","JPEG Huffman symbol count is outside1..256")
    values : Input.Part <- Input.take(U32.to_nat(count),tail,[])
    huffman_values(values,counts,kind,id,previous,next)

def huffman_tables(fuel: Nat,bytes: List<&2,U32>,previous: List<&2,T.Table>) -> Result<&2,&2,T.Failure,List<&2,T.Table>>:
  match fuel bytes:
    case _ Nil{}: Done{previous}
    case 0n _: Fail{T.Failure{"image_resource_limit","JPEG Huffman definitions exceed the segment bound"}}
    case 1n+rest Con{+header,tail}:
      +kind : U32 = U32.shrn(header,4n)
      +id : U32 = U32.and(header,15)
      do Result<&2,&2,T.Failure,List<&2,T.Table>>:
        _ : Unit <- T.require(U32.is_le(kind,1) && U32.is_le(id,1),"unsupported_jpeg_mode","Baseline JPEG supports two AC and DC Huffman destinations")
        counts : Input.Part <- Input.take(16n,tail,[])
        huffman_counts(counts,kind,id,previous,after => updated => huffman_tables(rest,after,updated))
