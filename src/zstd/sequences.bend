import Base
import ./pair.bend as DataPair
import ./bits.bend as Bits
import ./bytes.bend as Bytes
import ./fse.bend as FSE
import ./huffman.bend as Huffman

type Offsets is Data:
  Offsets{recent: U32,second: U32,third: U32}

type Tables is Data:
  Tables{literal: Maybe<&2,FSE.Table>,offset: Maybe<&2,FSE.Table>,matched: Maybe<&2,FSE.Table>,history: Offsets}

type Sequence is Data:
  Sequence{literals: U32,matched: U32,distance: U32}

type Plan is Data:
  Plan{commands: List<&2,Sequence>,tables: Tables}

# Parameter-only destructuring keeps do blocks within the pinned grammar.

def with_number_tail(-R: Type,unpack_value: DataPair.Duo(U32,List<&2,U32>),unpack_continue: U32 -> List<&2,U32> -> R) -> R:
  (extra,tail) = unpack_value
  unpack_continue(extra,tail)

def with_length_bases(-R: Type,unpack_value: DataPair.Duo(DataPair.Duo(U32,U32),DataPair.Duo(U32,U32)),unpack_continue: U32 -> U32 -> U32 -> U32 -> R) -> R:
  ((lb,ln),(mb,mn)) = unpack_value
  unpack_continue(lb,ln,mb,mn)

def with_reverse_value(-R: Type,unpack_value: DataPair.Duo(Bits.Rev,U32),unpack_continue: Bits.Rev -> U32 -> R) -> R:
  (cursor1,offset_extra) = unpack_value
  unpack_continue(cursor1,offset_extra)

def with_offset_history(-R: Type,unpack_value: DataPair.Duo(U32,Offsets),unpack_continue: U32 -> Offsets -> R) -> R:
  (distance,next_history) = unpack_value
  unpack_continue(distance,next_history)

def with_decoded_sequence(-R: Type,unpack_value: DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets)),unpack_continue: Bits.Rev -> Sequence -> Offsets -> R) -> R:
  (cursor1,(command,next_history)) = unpack_value
  unpack_continue(cursor1,command,next_history)

def with_sequence_states(-R: Type,unpack_value: DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32))),unpack_continue: Bits.Rev -> U32 -> U32 -> U32 -> R) -> R:
  (cursor2,(next1,(next2,next3))) = unpack_value
  unpack_continue(cursor2,next1,next2,next3)

def with_table_tail(-R: Type,unpack_value: DataPair.Duo(FSE.Table,List<&2,U32>),unpack_continue: FSE.Table -> List<&2,U32> -> R) -> R:
  (ll,tail1) = unpack_value
  unpack_continue(ll,tail1)

def with_commands_history(-R: Type,unpack_value: DataPair.Duo(List<&2,Sequence>,Offsets),unpack_continue: List<&2,Sequence> -> Offsets -> R) -> R:
  (commands,next_history) = unpack_value
  unpack_continue(commands,next_history)

def initial() -> Tables:
  Tables{None{},None{},None{},Offsets{1,4,8}}

def sequence_count(first: U32,bytes: List<&2,U32>,small: Bool) -> Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  match first small:
    case _ True{}: Done{(first,bytes)}
    case 255 False{}:
      do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,2)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>,pair,extra => tail =>
          do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
            Done{(U32.add(extra,32512),tail)}
        )
    case _ False{}:
      do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>,pair,extra => tail =>
          do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
            Done{(U32.add(U32.shln(U32.sub(first,128),8n),extra),tail)}
        )

def count(bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
    pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
    with_number_tail(Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>,pair,+first => tail =>
      do Result<&2,&2,String,DataPair.Duo(U32,List<&2,U32>)>:
        sequence_count(first,tail,U32.is_lt(first,128))
    )

def default_table(kind: U32) -> Result<&2,&2,String,FSE.Table>:
  match kind:
    case 0: FSE.literals()
    case 1: FSE.offsets()
    case _: FSE.matches()

def max_symbol(kind: U32) -> U32:
  match kind:
    case 0: 35
    case 1: 31
    case _: 52

def max_log(kind: U32) -> U32:
  match kind:
    case 1: 8
    case _: 9

def repeat(previous: Maybe<&2,FSE.Table>,bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>:
  match previous:
    case None{}: Fail{"repeated sequence table has no prior table"}
    case Some{table}: Done{(table,bytes)}

def read_table(mode: U32,+kind: U32,previous: Maybe<&2,FSE.Table>,bytes: List<&2,U32>) ->
  Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>:
  match mode:
    case 0:
      do Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>:
        table : FSE.Table <- default_table(kind)
        Done{(table,bytes)}
    case 1:
      do Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>,pair,symbol => tail =>
          do Result<&2,&2,String,DataPair.Duo(FSE.Table,List<&2,U32>)>:
            table : FSE.Table <- FSE.rle(symbol,max_symbol(kind))
            Done{(table,tail)}
        )
    case 2: FSE.read_table(bytes,max_symbol(kind),max_log(kind))
    case _: repeat(previous,bytes)

def literal_small(code: U32) -> DataPair.Duo(U32,U32):
  match code:
    case 16: (16,1)
    case 17: (18,1)
    case 18: (20,1)
    case 19: (22,1)
    case 20: (24,2)
    case 21: (28,2)
    case 22: (32,3)
    case 23: (40,3)
    case 24: (48,4)
    case _: (0,0)

def literal_base(+code: U32,short: Bool,medium: Bool) -> DataPair.Duo(U32,U32):
  match short medium:
    case True{} _: (code,0)
    case False{} True{}: literal_small(code)
    case False{} False{}:
      +bits = U32.sub(code,19)
      (U32.shln(1,U32.to_nat(bits)),bits)

def match_small(code: U32) -> DataPair.Duo(U32,U32):
  match code:
    case 32: (35,1)
    case 33: (37,1)
    case 34: (39,1)
    case 35: (41,1)
    case 36: (43,2)
    case 37: (47,2)
    case 38: (51,3)
    case 39: (59,3)
    case 40: (67,4)
    case 41: (83,4)
    case 42: (99,5)
    case _: (0,0)

def match_base(+code: U32,short: Bool,medium: Bool) -> DataPair.Duo(U32,U32):
  match short medium:
    case True{} _: (U32.add(code,3),0)
    case False{} True{}: match_small(code)
    case False{} False{}:
      +bits = U32.sub(code,36)
      (U32.add(U32.shln(1,U32.to_nat(bits)),3),bits)

def repeated(+value: U32,history: Offsets,empty_literals: Bool) -> Result<&2,&2,String,DataPair.Duo(U32,Offsets)>:
  match value history empty_literals:
    case 1 Offsets{+a,b,c} False{}: Done{(a,Offsets{a,b,c})}
    case 1 Offsets{a,+b,c} True{}: Done{(b,Offsets{b,a,c})}
    case 2 Offsets{a,+b,c} False{}: Done{(b,Offsets{b,a,c})}
    case 2 Offsets{a,b,+c} True{}: Done{(c,Offsets{c,a,b})}
    case 3 Offsets{a,b,+c} False{}: Done{(c,Offsets{c,a,b})}
    case 3 Offsets{+a,b,_} True{}:
      do Result<&2,&2,String,DataPair.Duo(U32,Offsets)>:
        _ : Unit <- Huffman.require(U32.is_gt(a,1),"repeat offset minus one is zero")
        +distance : U32 = U32.sub(a,1)
        Done{(distance,Offsets{distance,a,b})}
    case _ Offsets{a,b,_} _:
      do Result<&2,&2,String,DataPair.Duo(U32,Offsets)>:
        _ : Unit <- Huffman.require(U32.is_gt(value,3),"invalid zero offset")
        +distance : U32 = U32.sub(value,3)
        Done{(distance,Offsets{distance,a,b})}

def lengths(cursor: Bits.Rev,+ll: U32,+of: U32,+ml: U32,history: Offsets) ->
  Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
  do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
    _ : Unit <- Huffman.require(U32.is_le(ll,35) && U32.is_le(ml,52) && U32.is_le(of,23),"unsupported sequence code or offset above8MiB window")
    bases : DataPair.Duo(DataPair.Duo(U32,U32),DataPair.Duo(U32,U32)) <- Done{(literal_base(ll,U32.is_lt(ll,16),U32.is_le(ll,24)),match_base(ml,U32.is_lt(ml,32),U32.is_le(ml,42)))}
    with_length_bases(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>,bases,lb => ln => mb => mn =>
      do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
        offset_pair : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor,of)
        with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>,offset_pair,cursor1 => offset_extra =>
          do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
            match_pair : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor1,mn)
            with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>,match_pair,cursor2 => match_extra =>
              do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
                literal_pair : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor2,ln)
                with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>,literal_pair,cursor3 => literal_extra =>
                  do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
                    +literal_count : U32 = U32.add(lb,literal_extra)
                    resolved : DataPair.Duo(U32,Offsets) <- repeated(U32.add(U32.shln(1,U32.to_nat(of)),offset_extra),history,U32.is_eq(literal_count,0))
                    with_offset_history(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>,resolved,distance => next_history =>
                      do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets))>:
                        Done{(cursor3,(Sequence{literal_count,U32.add(mb,match_extra),distance},next_history))}
                    )
                )
            )
        )
    )

def transition(cursor: Bits.Rev,entry: FSE.Entry) -> Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>:
  FSE.Entry{_,bits,base} = entry
  do Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>:
    pair : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor,bits)
    with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>,pair,next => value =>
      do Result<&2,&2,String,DataPair.Duo(Bits.Rev,U32)>:
        Done{(next,U32.add(base,value))}
    )

def symbol(entry: FSE.Entry) -> U32:
  FSE.Entry{value,_,_} = entry
  value

def next_states(last: Bool,cursor: Bits.Rev,literal: FSE.Entry,offset: FSE.Entry,matched: FSE.Entry) ->
  Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>:
  match last:
    case True{}: Done{(cursor,(0,(0,0)))}
    case False{}:
      do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>:
        ll : DataPair.Duo(Bits.Rev,U32) <- transition(cursor,literal)
        with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>,ll,cursor1 => state1 =>
          do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>:
            ml : DataPair.Duo(Bits.Rev,U32) <- transition(cursor1,matched)
            with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>,ml,cursor2 => state2 =>
              do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>:
                of : DataPair.Duo(Bits.Rev,U32) <- transition(cursor2,offset)
                with_reverse_value(Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>,of,cursor3 => state3 =>
                  do Result<&2,&2,String,DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32)))>:
                    Done{(cursor3,(state1,(state3,state2)))}
                )
            )
        )

def decode(fuel: Nat,+literal: FSE.Table,+offset: FSE.Table,+matched: FSE.Table,
  cursor: Bits.Rev,state1: U32,state2: U32,state3: U32,history: Offsets,rev: List<&2,Sequence>) ->
  Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>:
  match fuel:
    case 0n:
      do Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>:
        _ : Unit <- Huffman.require(U32.is_eq(Bits.remaining_reverse(cursor),0),"sequence bitstream has trailing bits")
        Done{(List.reverse(&2,Sequence,rev),history)}
    case 1n+ +rest:
      do Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>:
        +lle : FSE.Entry <- FSE.lookup(literal,state1)
        +ofe : FSE.Entry <- FSE.lookup(offset,state2)
        +mle : FSE.Entry <- FSE.lookup(matched,state3)
        result : DataPair.Duo(Bits.Rev,DataPair.Duo(Sequence,Offsets)) <- lengths(cursor,symbol(lle),symbol(ofe),symbol(mle),history)
        with_decoded_sequence(Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>,result,cursor1 => command => next_history =>
          do Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>:
            states : DataPair.Duo(Bits.Rev,DataPair.Duo(U32,DataPair.Duo(U32,U32))) <- next_states(Nat.is_eq(rest,0n),cursor1,lle,ofe,mle)
            with_sequence_states(Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>,states,cursor2 => next1 => next2 => next3 =>
              do Result<&2,&2,String,DataPair.Duo(List<&2,Sequence>,Offsets)>:
                decode(rest,literal,offset,matched,cursor2,next1,next2,next3,next_history,Con{command,rev})
            )
        )

def read_nonempty(bytes: List<&2,U32>,previous: Tables,count: U32) -> Result<&2,&2,String,Plan>:
  Tables{old_ll,old_of,old_ml,history} = previous
  do Result<&2,&2,String,Plan>:
    modes_pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.octet(bytes)
    with_number_tail(Result<&2,&2,String,Plan>,modes_pair,+modes => tail =>
      do Result<&2,&2,String,Plan>:
        _ : Unit <- Huffman.require(U32.is_eq(U32.and(modes,3),0),"reserved sequence mode bits are set")
        ll_pair : DataPair.Duo(FSE.Table,List<&2,U32>) <- read_table(U32.shrn(modes,6n),0,old_ll,tail)
        with_table_tail(Result<&2,&2,String,Plan>,ll_pair,+ll => tail1 =>
          do Result<&2,&2,String,Plan>:
            of_pair : DataPair.Duo(FSE.Table,List<&2,U32>) <- read_table(U32.and(U32.shrn(modes,4n),3),1,old_of,tail1)
            with_table_tail(Result<&2,&2,String,Plan>,of_pair,+of => tail2 =>
              do Result<&2,&2,String,Plan>:
                ml_pair : DataPair.Duo(FSE.Table,List<&2,U32>) <- read_table(U32.and(U32.shrn(modes,2n),3),2,old_ml,tail2)
                with_table_tail(Result<&2,&2,String,Plan>,ml_pair,+ml => stream =>
                  do Result<&2,&2,String,Plan>:
                    cursor : Bits.Rev <- Bits.reverse(stream)
                    s1 : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor,FSE.accuracy(ll))
                    with_reverse_value(Result<&2,&2,String,Plan>,s1,cursor1 => state1 =>
                      do Result<&2,&2,String,Plan>:
                        s2 : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor1,FSE.accuracy(of))
                        with_reverse_value(Result<&2,&2,String,Plan>,s2,cursor2 => state2 =>
                          do Result<&2,&2,String,Plan>:
                            s3 : DataPair.Duo(Bits.Rev,U32) <- Bits.read_reverse(cursor2,FSE.accuracy(ml))
                            with_reverse_value(Result<&2,&2,String,Plan>,s3,cursor3 => state3 =>
                              do Result<&2,&2,String,Plan>:
                                result : DataPair.Duo(List<&2,Sequence>,Offsets) <- decode(U32.to_nat(count),ll,of,ml,cursor3,state1,state2,state3,history,Nil{})
                                with_commands_history(Result<&2,&2,String,Plan>,result,commands => next_history =>
                                  do Result<&2,&2,String,Plan>:
                                    Done{Plan{commands,Tables{Some{ll},Some{of},Some{ml},next_history}}}
                                )
                            )
                        )
                    )
                )
            )
        )
    )

def read_counted(+count: U32,bytes: List<&2,U32>,previous: Tables,maximum: U32) -> Result<&2,&2,String,Plan>:
  match count:
    case 0:
      do Result<&2,&2,String,Plan>:
        _ : Unit <- Huffman.require(List.is_empty(&2,U32,bytes),"zero-sequence section has trailing bytes")
        Done{Plan{Nil{},previous}}
    case _:
      do Result<&2,&2,String,Plan>:
        _ : Unit <- Huffman.require(U32.is_le(count,U32.div(maximum,3)),"sequence count exceeds block output maximum")
        read_nonempty(bytes,previous,count)

def read(bytes: List<&2,U32>,previous: Tables,maximum: U32) -> Result<&2,&2,String,Plan>:
  do Result<&2,&2,String,Plan>:
    pair : DataPair.Duo(U32,List<&2,U32>) <- count(bytes)
    with_number_tail(Result<&2,&2,String,Plan>,pair,amount => tail =>
      do Result<&2,&2,String,Plan>:
        read_counted(amount,tail,previous,maximum)
    )
