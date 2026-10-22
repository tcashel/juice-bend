import Base
import ./pair.bend as DataPair

# Raw octets, never decoded through String. The enclosing decoder supplies
# one block at a time; reverse streams additionally enforce the 128 KiB cap.
type Fwd is Data:
  Forward{tail: List<&2,U32>,byte: U32,bits: U32,used: U32}

type Rev is Data:
  Reverse{tail: List<&2,U32>,byte: U32,bits: U32,left: U32}

def forward(bytes: List<&2,U32>) -> Fwd:
  Forward{bytes,0,0,0}

def remaining_forward(cursor: Fwd) -> List<&2,U32>:
  Forward{tail,_,_,_} = cursor
  tail

def used_forward(cursor: Fwd) -> U32:
  Forward{_,_,_,used} = cursor
  used

def forward_loaded(tail: List<&2,U32>,+byte: U32,used: U32,valid: Bool) ->
  Result<&2,&2,String,DataPair.Duo(Fwd,U32)>:
  match valid:
    case False{}: Fail{"input is not an octet"}
    case True{}: Done{(Forward{tail,U32.shr(byte),7,U32.add(used,1)},U32.and(byte,1))}

def forward_bit(cursor: Fwd) -> Result<&2,&2,String,DataPair.Duo(Fwd,U32)>:
  match cursor:
    case Forward{Nil{},_,0,_}: Fail{"truncated forward bitstream"}
    case Forward{Con{+byte,tail},_,0,used}:
      forward_loaded(tail,byte,used,U32.is_le(byte,255))
    case Forward{tail,+byte,bits,used}:
      Done{(Forward{tail,U32.shr(byte),U32.sub(bits,1),used},U32.and(byte,1))}

def forward_then(result: Result<&2,&2,String,DataPair.Duo(Fwd,U32)>,next: Fwd -> U32 -> Result<&2,&2,String,DataPair.Duo(Fwd,U32)>) -> Result<&2,&2,String,DataPair.Duo(Fwd,U32)>:
  match result:
    case Fail{error}: Fail{error}
    case Done{(cursor,value)}: next(cursor,value)

def forward_loop(fuel: Nat,cursor: Fwd,+shift: U32,value: U32) ->
  Result<&2,&2,String,DataPair.Duo(Fwd,U32)>:
  match fuel:
    case 0n: Done{(cursor,value)}
    case 1n+rest:
      forward_then(forward_bit(cursor),next => bit =>
        forward_loop(rest,next,U32.add(shift,1),U32.or(value,U32.shln(bit,U32.to_nat(shift)))))

def forward_allowed(cursor: Fwd,width: U32,allowed: Bool) -> Result<&2,&2,String,DataPair.Duo(Fwd,U32)>:
  match allowed:
    case False{}: Fail{"forward field wider than 24 bits"}
    case True{}: forward_loop(U32.to_nat(width),cursor,0,0)

def read_forward(cursor: Fwd,+width: U32) -> Result<&2,&2,String,DataPair.Duo(Fwd,U32)>:
  forward_allowed(cursor,width,U32.is_le(width,24))

def reverse_valid(valid: Bool) -> Result<&2,&2,String,Unit>:
  match valid:
    case False{}: Fail{"reverse bitstream exceeds block bound or contains non-octet"}
    case True{}: Done{Unit{}}

def reverse_checked(bytes: List<&2,U32>,rev: List<&2,U32>,+count: U32) ->
  Result<&2,&2,String,DataPair.Duo(List<&2,U32>,U32)>:
  match bytes:
    case Nil{}: Done{(rev,count)}
    case Con{+byte,tail}:
      do Result<&2,&2,String,DataPair.Duo(List<&2,U32>,U32)>:
        _ : Unit <- reverse_valid(U32.is_le(byte,255) && U32.is_lt(count,131072))
        reverse_checked(tail,Con{byte,rev},U32.add(count,1))

def reverse_last(+last: U32,tail: List<&2,U32>,count: U32,valid: Bool) ->
  Result<&2,&2,String,Rev>:
  match valid:
    case False{}: Fail{"missing reverse bitstream sentinel"}
    case True{}:
      +bits = U32.from_nat(U32.log2(last))
      Done{Reverse{tail,last,bits,U32.add(U32.mul(U32.sub(count,1),8),bits)}}

def reverse_from(reversed: List<&2,U32>,count: U32) -> Result<&2,&2,String,Rev>:
  match reversed:
    case Nil{}: Fail{"empty reverse bitstream"}
    case Con{+last,tail}: reverse_last(last,tail,count,U32.is_ne(last,0))

def reverse_ready(result: Result<&2,&2,String,DataPair.Duo(List<&2,U32>,U32)>) -> Result<&2,&2,String,Rev>:
  match result:
    case Fail{error}: Fail{error}
    case Done{(reversed,count)}: reverse_from(reversed,count)

def reverse(bytes: List<&2,U32>) -> Result<&2,&2,String,Rev>:
  reverse_ready(reverse_checked(bytes,Nil{},0))

def remaining_reverse(cursor: Rev) -> U32:
  Reverse{_,_,_,left} = cursor
  left

def reverse_bit(cursor: Rev) -> Result<&2,&2,String,DataPair.Duo(Rev,U32)>:
  match cursor:
    case Reverse{Nil{},_,0,_}: Fail{"truncated reverse bitstream"}
    case Reverse{Con{+byte,tail},_,0,left}:
      Done{(Reverse{tail,byte,7,U32.sub(left,1)},U32.shrn(byte,7n))}
    case Reverse{tail,+byte,bits,left}:
      +next_bits = U32.sub(bits,1)
      Done{(Reverse{tail,byte,next_bits,U32.sub(left,1)},U32.and(U32.shrn(byte,U32.to_nat(next_bits)),1))}

def reverse_then(result: Result<&2,&2,String,DataPair.Duo(Rev,U32)>,next: Rev -> U32 -> Result<&2,&2,String,DataPair.Duo(Rev,U32)>) -> Result<&2,&2,String,DataPair.Duo(Rev,U32)>:
  match result:
    case Fail{error}: Fail{error}
    case Done{(cursor,value)}: next(cursor,value)

def reverse_loop(fuel: Nat,cursor: Rev,value: U32) -> Result<&2,&2,String,DataPair.Duo(Rev,U32)>:
  match fuel:
    case 0n: Done{(cursor,value)}
    case 1n+rest:
      reverse_then(reverse_bit(cursor),next => bit =>
        reverse_loop(rest,next,U32.or(U32.shl(value),bit)))

def reverse_allowed(cursor: Rev,width: U32,allowed: Bool) -> Result<&2,&2,String,DataPair.Duo(Rev,U32)>:
  match allowed:
    case False{}: Fail{"truncated reverse field or width over 24 bits"}
    case True{}: reverse_loop(U32.to_nat(width),cursor,0)

def read_reverse(+cursor: Rev,+width: U32) -> Result<&2,&2,String,DataPair.Duo(Rev,U32)>:
  reverse_allowed(cursor,width,U32.is_le(width,24) && U32.is_le(width,remaining_reverse(cursor)))
