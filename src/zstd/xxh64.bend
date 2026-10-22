import Base
import ./pair.bend as DataPair
import ./bytes.bend as Bytes

# XXH64, seed zero, from xxHash v0.8.3 specification. A LimbWord is always
# (low32, high32); no floating point or host-sized integer conversions.
type LimbWord is Data:
  LimbWord{low: U32,high: U32}

type State is Data:
  State{a: LimbWord,b: LimbWord,c: LimbWord,d: LimbWord,total: U32,limit: U32,
    reversed: List<&2,U32>,used: U32}

# Parameter-only destructuring keeps do blocks within the pinned grammar.

def with_number_tail(-R: Type,unpack_value: DataPair.Duo(U32,List<&2,U32>),unpack_continue: U32 -> List<&2,U32> -> R) -> R:
  (lo,middle) = unpack_value
  unpack_continue(lo,middle)

def with_word_tail(-R: Type,unpack_value: DataPair.Duo(LimbWord,List<&2,U32>),unpack_continue: LimbWord -> List<&2,U32> -> R) -> R:
  (lane1,tail1) = unpack_value
  unpack_continue(lane1,tail1)

def low(word: LimbWord) -> U32:
  LimbWord{value,_} = word
  value

def high(word: LimbWord) -> U32:
  LimbWord{_,value} = word
  value

def equal(a: LimbWord,b: LimbWord) -> Bool:
  LimbWord{al,ah} = a
  LimbWord{bl,bh} = b
  U32.is_eq(al,bl) && U32.is_eq(ah,bh)

def add(a: LimbWord,b: LimbWord) -> LimbWord:
  LimbWord{+al,ah} = a
  LimbWord{bl,bh} = b
  +sum = U32.add(al,bl)
  LimbWord{sum,U32.add(U32.add(ah,bh),Bool.to_u32(U32.is_lt(sum,al)))}

def xor(a: LimbWord,b: LimbWord) -> LimbWord:
  LimbWord{al,ah} = a
  LimbWord{bl,bh} = b
  LimbWord{U32.xor(al,bl),U32.xor(ah,bh)}

def negate(word: LimbWord) -> LimbWord:
  LimbWord{lo,hi} = word
  add(LimbWord{U32.not(lo),U32.not(hi)},LimbWord{1,0})

# Each product of two 16-bit limbs fits 32 bits. The intermediate sums below
# are <=0xfffeffff, so their carry cannot be lost by U32 modular arithmetic.

def multiply32(+a: U32,+b: U32) -> LimbWord:
  +a0 = U32.and(a,65535)
  +a1 = U32.shrn(a,16n)
  +b0 = U32.and(b,65535)
  +b1 = U32.shrn(b,16n)
  +p0 = U32.mul(a0,b0)
  +middle1 = U32.add(U32.mul(a1,b0),U32.shrn(p0,16n))
  +middle2 = U32.add(U32.mul(a0,b1),U32.and(middle1,65535))
  LimbWord{U32.or(U32.shln(middle2,16n),U32.and(p0,65535)),
    U32.add(U32.add(U32.mul(a1,b1),U32.shrn(middle1,16n)),U32.shrn(middle2,16n))}

def multiply_product(product: LimbWord,al: U32,ah: U32,bl: U32,bh: U32) -> LimbWord:
  LimbWord{product_low,product_high} = product
  LimbWord{product_low,U32.add(product_high,U32.add(U32.mul(al,bh),U32.mul(ah,bl)))}

def multiply(a: LimbWord,b: LimbWord) -> LimbWord:
  LimbWord{+al,ah} = a
  LimbWord{+bl,bh} = b
  multiply_product(multiply32(al,bl),al,ah,bl,bh)

# The only rotate widths in XXH64 are 1,7,11,12,18,23,27,31. This helper
# additionally handles 0 and 32; no call passes a width beyond 32.

def rotate(word: LimbWord,+bits: Nat) -> LimbWord:
  LimbWord{+lo,+hi} = word
  +other = Nat.sub(32n,bits)
  LimbWord{U32.or(U32.shln(lo,bits),U32.shrn(hi,other)),
    U32.or(U32.shln(hi,bits),U32.shrn(lo,other))}

def shift29(word: LimbWord) -> LimbWord:
  LimbWord{lo,+hi} = word
  LimbWord{U32.or(U32.shrn(lo,29n),U32.shln(hi,3n)),U32.shrn(hi,29n)}

def shift32(word: LimbWord) -> LimbWord:
  LimbWord{_,hi} = word
  LimbWord{hi,0}

def shift33(word: LimbWord) -> LimbWord:
  LimbWord{_,hi} = word
  LimbWord{U32.shr(hi),0}

def prime1() -> LimbWord: LimbWord{2246822535,2654435761}

def prime2() -> LimbWord: LimbWord{668265295,3266489917}

def prime3() -> LimbWord: LimbWord{2654435833,374761393}

def prime4() -> LimbWord: LimbWord{3266489955,2246822519}

def prime5() -> LimbWord: LimbWord{374761413,668265263}

def round(acc: LimbWord,lane: LimbWord) -> LimbWord:
  multiply(rotate(add(acc,multiply(lane,prime2())),31n),prime1())

def merge(acc: LimbWord,lane: LimbWord) -> LimbWord:
  add(multiply(xor(acc,round(LimbWord{0,0},lane)),prime1()),prime4())

def avalanche(+acc: LimbWord) -> LimbWord:
  +step1 = multiply(xor(acc,shift33(acc)),prime2())
  +step2 = multiply(xor(step1,shift29(step1)),prime3())
  xor(step2,shift32(step2))

def require(valid: Bool,error: String) -> Result<&2,&2,String,Unit>:
  match valid:
    case False{}: Fail{error}
    case True{}: Done{Unit{}}

def init(limit: U32) -> State:
  State{add(prime1(),prime2()),prime2(),LimbWord{0,0},negate(prime1()),0,limit,[],0}

def read_word(bytes: List<&2,U32>) -> Result<&2,&2,String,DataPair.Duo(LimbWord,List<&2,U32>)>:
  do Result<&2,&2,String,DataPair.Duo(LimbWord,List<&2,U32>)>:
    left : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
    with_number_tail(Result<&2,&2,String,DataPair.Duo(LimbWord,List<&2,U32>)>,left,lo => middle =>
      do Result<&2,&2,String,DataPair.Duo(LimbWord,List<&2,U32>)>:
        right : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(middle,4)
        with_number_tail(Result<&2,&2,String,DataPair.Duo(LimbWord,List<&2,U32>)>,right,hi => tail =>
          do Result<&2,&2,String,DataPair.Duo(LimbWord,List<&2,U32>)>:
            Done{(LimbWord{lo,hi},tail)}
        )
    )

def stripe_end(tail: List<&2,U32>,a: LimbWord,b: LimbWord,c: LimbWord,d: LimbWord,total: U32,limit: U32) -> Result<&2,&2,String,State>:
  match tail:
    case Nil{}: Done{State{a,b,c,d,total,limit,[],0}}
    case Con{_,_}: Fail{"XXH64 pending stripe exceeds 32 bytes"}

def push(full: Bool,a: LimbWord,b: LimbWord,c: LimbWord,d: LimbWord,total: U32,limit: U32,
  reversed: List<&2,U32>,used: U32) -> Result<&2,&2,String,State>:
  match full:
    case False{}: Done{State{a,b,c,d,total,limit,reversed,used}}
    case True{}:
      do Result<&2,&2,String,State>:
        first : DataPair.Duo(LimbWord,List<&2,U32>) <- read_word(List.reverse(&2,U32,reversed))
        with_word_tail(Result<&2,&2,String,State>,first,lane1 => tail1 =>
          do Result<&2,&2,String,State>:
            second : DataPair.Duo(LimbWord,List<&2,U32>) <- read_word(tail1)
            with_word_tail(Result<&2,&2,String,State>,second,lane2 => tail2 =>
              do Result<&2,&2,String,State>:
                third : DataPair.Duo(LimbWord,List<&2,U32>) <- read_word(tail2)
                with_word_tail(Result<&2,&2,String,State>,third,lane3 => tail3 =>
                  do Result<&2,&2,String,State>:
                    fourth : DataPair.Duo(LimbWord,List<&2,U32>) <- read_word(tail3)
                    with_word_tail(Result<&2,&2,String,State>,fourth,lane4 => tail4 =>
                      do Result<&2,&2,String,State>:
                        stripe_end(tail4,round(a,lane1),round(b,lane2),round(c,lane3),round(d,lane4),total,limit)
                    )
                )
            )
        )

def byte(state: State,+value: U32) -> Result<&2,&2,String,State>:
  State{a,b,c,d,+total,+limit,reversed,+used} = state
  do Result<&2,&2,String,State>:
    _ : Unit <- require(U32.is_le(value,255),"XXH64 input is not an octet")
    _ : Unit <- require(U32.is_lt(total,limit) && U32.is_lt(used,32),"XXH64 explicit input limit or pending bound exceeded")
    push(U32.is_eq(used,31),a,b,c,d,U32.add(total,1),limit,Con{value,reversed},U32.add(used,1))

def update_loop(bytes: List<&2,U32>,state: State) -> Result<&2,&2,String,State>:
  match bytes:
    case Nil{}: Done{state}
    case Con{head,tail}:
      do Result<&2,&2,String,State>:
        next : State <- byte(state,head)
        update_loop(tail,next)

def update(state: State,bytes: List<&2,U32>) -> Result<&2,&2,String,State>:
  update_loop(bytes,state)

# pending state validation is bounded to 31 bytes; it never walks a forged
# unbounded tail. The total cap is checked before increment, not after wrap.

def pending_valid(fuel: Nat,bytes: List<&2,U32>) -> Result<&2,&2,String,Unit>:
  match fuel bytes:
    case 0n Nil{}: Done{Unit{}}
    case 1n+rest Con{head,tail}:
      do Result<&2,&2,String,Unit>:
        _ : Unit <- require(U32.is_le(head,255),"XXH64 pending value is not an octet")
        pending_valid(rest,tail)
    case _ _: Fail{"XXH64 pending byte count is inconsistent"}

def converge(long: Bool,+a: LimbWord,+b: LimbWord,+c: LimbWord,+d: LimbWord) -> LimbWord:
  match long:
    case False{}: prime5()
    case True{}:
      combined = add(add(rotate(a,1n),rotate(b,7n)),add(rotate(c,12n),rotate(d,18n)))
      merge(merge(merge(merge(combined,a),b),c),d)

def tail_byte(bytes: List<&2,U32>,acc: LimbWord) -> LimbWord:
  match bytes:
    case Nil{}: avalanche(acc)
    case Con{head,tail}:
      tail_byte(tail,multiply(rotate(xor(acc,multiply(LimbWord{head,0},prime5())),11n),prime1()))

def tail_four(has_four: Bool,bytes: List<&2,U32>,acc: LimbWord) -> Result<&2,&2,String,LimbWord>:
  match has_four:
    case False{}: Done{tail_byte(bytes,acc)}
    case True{}:
      do Result<&2,&2,String,LimbWord>:
        pair : DataPair.Duo(U32,List<&2,U32>) <- Bytes.little(bytes,4)
        with_number_tail(Result<&2,&2,String,LimbWord>,pair,lane => tail =>
          do Result<&2,&2,String,LimbWord>:
            next : LimbWord = add(multiply(rotate(xor(acc,multiply(LimbWord{lane,0},prime1())),23n),prime2()),prime3())
            Done{tail_byte(tail,next)}
        )

def tail_step(has_eight: Bool,bytes: List<&2,U32>,remaining: U32,acc: LimbWord,
  next: List<&2,U32> -> U32 -> LimbWord -> Result<&2,&2,String,LimbWord>) -> Result<&2,&2,String,LimbWord>:
  match has_eight:
    case False{}: tail_four(U32.is_ge(remaining,4),bytes,acc)
    case True{}:
      do Result<&2,&2,String,LimbWord>:
        pair : DataPair.Duo(LimbWord,List<&2,U32>) <- read_word(bytes)
        with_word_tail(Result<&2,&2,String,LimbWord>,pair,lane => tail =>
          do Result<&2,&2,String,LimbWord>:
            mixed : LimbWord = add(multiply(rotate(xor(acc,round(LimbWord{0,0},lane)),27n),prime1()),prime4())
            next(tail,U32.sub(remaining,8),mixed)
        )

def tail_eight(fuel: Nat,bytes: List<&2,U32>,+remaining: U32,acc: LimbWord) -> Result<&2,&2,String,LimbWord>:
  match fuel:
    case 0n: Fail{"XXH64 tail stripe bound exceeded"}
    case 1n+rest:
      tail_step(U32.is_ge(remaining,8),bytes,remaining,acc,
        tail => count => next => tail_eight(rest,tail,count,next))

def finish(state: State) -> Result<&2,&2,String,LimbWord>:
  State{a,b,c,d,+total,limit,+reversed,+used} = state
  do Result<&2,&2,String,LimbWord>:
    _ : Unit <- require(U32.is_le(total,limit) && U32.is_lt(used,32) && U32.is_eq(U32.mod(total,32),used),"XXH64 state length invariant failed")
    _ : Unit <- pending_valid(U32.to_nat(used),reversed)
    acc : LimbWord = add(converge(U32.is_ge(total,32),a,b,c,d),LimbWord{total,0})
    tail_eight(4n,List.reverse(&2,U32,reversed),used,acc)

def digest(bytes: List<&2,U32>,limit: U32) -> Result<&2,&2,String,LimbWord>:
  do Result<&2,&2,String,LimbWord>:
    state : State <- update(init(limit),bytes)
    finish(state)
