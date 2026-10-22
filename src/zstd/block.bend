import Base
import ./pair.bend as DataPair
import ./literals.bend as Literals
import ./sequences.bend as Sequences
import ./huffman.bend as Huffman
import ./output.bend as Output

type State is Data:
  State{huffman: Maybe<&2,Huffman.Tree>,sequences: Sequences.Tables}

def initial() -> State:
  State{None{},Sequences.initial()}

def compressed_finish(result: Output.Sink & List<&2,U32>,huffman: Maybe<&2,Huffman.Tree>,sequences: Sequences.Tables) ->
  Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
  (next,decoded) = result
  Done{((State{huffman,sequences},next),decoded)}

def compressed_plan(plan: Sequences.Plan,sink: Output.Sink,literals: List<&2,U32>,maximum: U32,huffman: Maybe<&2,Huffman.Tree>) ->
  Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
  Sequences.Plan{commands,sequences} = plan
  do Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
    result : Output.Sink & List<&2,U32> <- Output.apply(commands,sink,literals,maximum,Nil{})
    compressed_finish(result,huffman,sequences)

def compressed_literals(pair: DataPair.Duo(Literals.Content,List<&2,U32>),old_sequences: Sequences.Tables,sink: Output.Sink,+maximum: U32) ->
  Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
  (Literals.Content{literals,huffman},sequence_bytes) = pair
  do Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
    plan : Sequences.Plan <- Output.widen(Sequences.Plan,Sequences.read(sequence_bytes,old_sequences,maximum))
    compressed_plan(plan,sink,literals,maximum,huffman)

def compressed(bytes: List<&2,U32>,state: State,sink: Output.Sink,+maximum: U32) ->
  Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
  State{old_huffman,old_sequences} = state
  do Result<&2,&1,String,(State & Output.Sink) & List<&2,U32>>:
    literal_pair : DataPair.Duo(Literals.Content,List<&2,U32>) <- Output.widen(DataPair.Duo(Literals.Content,List<&2,U32>),Literals.read(bytes,old_huffman,maximum))
    compressed_literals(literal_pair,old_sequences,sink,maximum)
