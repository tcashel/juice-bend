import Base
import ./pair.bend as DataPair
import ./bits.bend as Bits

# Zstandard v1.5.7 format, FSE Table Description. -1 is the unsigned
# sentinel below, never interpreted through a signed conversion. All arrays
# are bounded before construction, used affinely, then consumed into a tree.
type Entry is Data:
  Entry{symbol: U32,bits: U32,base: U32}

type Cells is Data:
  Leaf{entry: Entry}
  Branch{left: Cells,right: Cells}

type Table is Data:
  Table{log: U32,size: U32,cells: Cells}

def accuracy(table: Table) -> U32:
  Table{log,_,_} = table
  log

def rare() -> U32: 4294967295

def mass(+probability: U32) -> U32:
  Bool.pick(U32,U32.is_eq(probability,rare()),1,probability)

def checked(-A: Data,valid: Bool,error: String,next: Unit -> Result<&2,&2,String,A>) -> Result<&2,&2,String,A>:
  match valid:
    case False{}: Fail{error}
    case True{}: next(Unit{})

def validate(probabilities: List<&2,U32>,+remaining: U32,present: U32,+symbols: U32) -> Result<&2,&2,String,Unit>:
  match probabilities:
    case Nil{}:
      checked(Unit,U32.is_eq(remaining,0) && U32.is_ge(present,2),
        "FSE normalized sum must be exact with at least two symbols",_ => Done{Unit{}})
    case Con{probability,rest}:
      +count = mass(probability)
      checked(Unit,U32.is_le(count,remaining) && U32.is_lt(symbols,256),
        "invalid FSE normalized probability or symbol count",_ =>
          validate(rest,U32.sub(remaining,count),U32.add(present,Bool.to_u32(U32.is_ne(count,0))),U32.add(symbols,1)))

# Reserve rare symbols from the end, and initialize each symbol's state
# counter to its normalized frequency. This is the equivalent of assigning
# low-state larger ranges and high-state smaller ranges in the format text.
def low_step(special: Bool,symbols: Array<U32>,+high: U32,+symbol: U32,
  counters: Array<U32>,probability: U32) -> (Array<U32> & Array<U32>) & U32:
  match special:
    case True{}:
      ( (Array.set(U32,symbols,U32.sub(high,1),symbol),
          Array.set(U32,counters,symbol,1)),U32.sub(high,1))
    case False{}: ((symbols,Array.set(U32,counters,symbol,probability)),high)

def low_continue(-A: Type,result: (Array<U32> & Array<U32>) & U32,
  next: Array<U32> -> Array<U32> -> U32 -> A) -> A:
  ((symbols,counters),high) = result
  next(symbols,counters,high)

def low_rows(probabilities: List<&2,U32>,symbols: Array<U32>,counters: Array<U32>,+symbol: U32,high: U32) -> (Array<U32> & Array<U32>) & U32:
  match probabilities:
    case Nil{}: ((symbols,counters),high)
    case Con{+probability,rest}:
      low_continue((Array<U32> & Array<U32>) & U32,
        low_step(U32.is_eq(probability,rare()),symbols,high,symbol,counters,probability),
        next_symbols => next_counters => next_high =>
          low_rows(rest,next_symbols,next_counters,U32.add(symbol,1),next_high))

# The odd spread stride visits every cell of the power-of-two table. The
# explicit fuel is defensive: malformed internal state cannot spin forever.
def open_step(open: Bool,position: U32,next: Unit -> Result<&2,&2,String,U32>) -> Result<&2,&2,String,U32>:
  match open:
    case True{}: Done{position}
    case False{}: next(Unit{})

def next_open(fuel: Nat,+position: U32,+high: U32,+step: U32,+mask: U32) -> Result<&2,&2,String,U32>:
  match fuel:
    case 0n: Fail{"FSE spread has no open position"}
    case 1n+rest:
      open_step(U32.is_lt(position,high),position,_ =>
        next_open(rest,U32.and(U32.add(position,step),mask),high,step,mask))

def placed(next: Result<&2,&2,String,U32>,symbols: Array<U32>,
  continue: Array<U32> -> U32 -> Result<&2,&1,String,Array<U32> & U32>) -> Result<&2,&1,String,Array<U32> & U32>:
  match next:
    case Fail{error}: Fail{error}
    case Done{position}: continue(symbols,position)

def place(count: Nat,symbols: Array<U32>,+symbol: U32,+position: U32,+high: U32,+step: U32,+mask: U32) -> Result<&2,&1,String,Array<U32> & U32>:
  match count:
    case 0n: Done{(symbols,position)}
    case 1n+rest:
      placed(next_open(512n,U32.and(U32.add(position,step),mask),high,step,mask),
        Array.set(U32,symbols,position,symbol),
        array => next => place(rest,array,symbol,next,high,step,mask))

def spread_next(result: Result<&2,&1,String,Array<U32> & U32>,
  continue: Array<U32> -> U32 -> Result<&2,&1,String,Array<U32>>) -> Result<&2,&1,String,Array<U32>>:
  match result:
    case Fail{error}: Fail{error}
    case Done{(symbols,position)}: continue(symbols,position)

def ordinary(+probability: U32) -> U32:
  Bool.pick(U32,U32.is_eq(probability,rare()),0,probability)

def spread_end(closed: Bool,symbols: Array<U32>) -> Result<&2,&1,String,Array<U32>>:
  match closed:
    case True{}: Done{symbols}
    case False{}: Fail{"FSE spread did not close its cycle"}

def spread(probabilities: List<&2,U32>,symbols: Array<U32>,+symbol: U32,position: U32,+high: U32,+step: U32,+mask: U32) -> Result<&2,&1,String,Array<U32>>:
  match probabilities:
    case Nil{}: spread_end(U32.is_eq(position,0),symbols)
    case Con{probability,rest}:
      spread_next(place(U32.to_nat(ordinary(probability)),symbols,symbol,position,high,step,mask),
        array => next => spread(rest,array,U32.add(symbol,1),next,high,step,mask))

def freeze_leaf(result: Array<U32> & U32,+symbol: U32,log: U32,size: U32) -> Array<U32> & Cells:
  (counters,+next_state) = result
  +bits = U32.sub(log,U32.from_nat(U32.log2(next_state)))
  base = U32.sub(U32.shln(next_state,U32.to_nat(bits)),size)
  (Array.set(U32,counters,symbol,U32.add(next_state,1)),Leaf{Entry{symbol,bits,base}})

def freeze_join(result: Array<U32> & Cells,left: Cells) -> Array<U32> & Cells:
  (counters,right) = result
  (counters,Branch{left,right})

def freeze_left(result: Array<U32> & Cells,
  next: Array<U32> -> Cells -> Array<U32> & Cells) -> Array<U32> & Cells:
  (counters,left) = result
  next(counters,left)

def freeze(symbols: Array<U32>,counters: Array<U32>,+log: U32,+size: U32) -> Array<U32> & Cells:
  match symbols:
    case ALeaf{+symbol}: freeze_leaf(Array.get(U32,counters,symbol),symbol,log,size)
    case ANode{left,right}:
      freeze_left(freeze(left,counters,log,size),
        left_counters => left_cells =>
          freeze_join(freeze(right,left_counters,log,size),left_cells))

def frozen_table(result: Array<U32> & Cells,log: U32,size: U32) -> Result<&2,&2,String,Table>:
  (discard,cells) = result
  Done{Table{log,size,cells}}

def finish(result: Result<&2,&1,String,Array<U32>>,counters: Array<U32>,+log: U32,+size: U32) -> Result<&2,&2,String,Table>:
  match result:
    case Fail{error}: Fail{error}
    case Done{symbols}: frozen_table(freeze(symbols,counters,log,size),log,size)

def make_valid(valid: Result<&2,&2,String,Unit>,+log: U32,+size: U32,+probabilities: List<&2,U32>) -> Result<&2,&2,String,Table>:
  match valid:
    case Fail{error}: Fail{error}
    case Done{_}:
      step = U32.add(U32.add(U32.shr(size),U32.shrn(size,3n)),3)
      low_continue(Result<&2,&2,String,Table>,
        low_rows(probabilities,Array.new(U32,U32.to_nat(log),0),Array.new(U32,8n,0),0,size),
        symbols => counters => high =>
          finish(spread(probabilities,symbols,0,0,high,step,U32.sub(size,1)),counters,log,size))

def make_checked(valid: Bool,+log: U32,+probabilities: List<&2,U32>) -> Result<&2,&2,String,Table>:
  match valid:
    case False{}: Fail{"FSE accuracy log outside 5..9"}
    case True{}:
      +size = U32.shln(1,U32.to_nat(log))
      make_valid(validate(probabilities,size,0,0),log,size,probabilities)

def make_table(+log: U32,probabilities: List<&2,U32>) -> Result<&2,&2,String,Table>:
  make_checked(U32.is_ge(log,5) && U32.is_le(log,9),log,probabilities)

# RLE has one state and consumes no state/transition bits. Its symbol limit
# belongs to the caller's LL/ML/OF alphabet, rather than to probability parsing.
def rle(+symbol: U32,+max_symbol: U32) -> Result<&2,&2,String,Table>:
  checked(Table,U32.is_le(symbol,max_symbol) && U32.is_le(max_symbol,255),
    "FSE RLE symbol outside alphabet",_ => Done{Table{0,1,Leaf{Entry{symbol,0,0}}}})

def cell_side(low: Bool,left: Cells,right: Cells,state: U32,+half: U32,
  next: Cells -> U32 -> U32 -> Result<&2,&2,String,Entry>) -> Result<&2,&2,String,Entry>:
  match low:
    case True{}: next(left,state,half)
    case False{}: next(right,U32.sub(state,half),half)

def cell(fuel: Nat,cells: Cells,+state: U32,size: U32) -> Result<&2,&2,String,Entry>:
  match fuel cells:
    case 0n _: Fail{"invalid FSE tree depth"}
    case _ Leaf{entry}:
      checked(Entry,U32.is_eq(state,0),"invalid FSE tree leaf state",_ => Done{entry})
    case 1n+rest Branch{left,right}:
      +half = U32.shr(size)
      cell_side(U32.is_lt(state,half),left,right,state,half,
        tree => index => width => cell(rest,tree,index,width))

def lookup(table: Table,+state: U32) -> Result<&2,&2,String,Entry>:
  Table{_,+size,cells} = table
  checked(Entry,U32.is_lt(state,size),"FSE state outside table",_ => cell(10n,cells,state,size))

# For remaining mass r, encoded values range 0..r+1. Low values use one
# fewer bit. Read those bits first so the parser never requires padding or
# consumes a byte beyond the aligned end of the actual table description.
def upper_value(pair: DataPair.Duo(Bits.Fwd,U32),+low: U32,+half: U32,cutoff: U32) -> Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>:
  (cursor,bit) = pair
  +encoded = U32.add(low,U32.mul(bit,half))
  Done{(cursor,Bool.pick(U32,U32.is_ge(encoded,half),U32.sub(encoded,cutoff),encoded))}

def lower_small(small: Bool,cursor: Bits.Fwd,low: U32,width: U32,cutoff: U32) -> Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>:
  match small:
    case True{}: Done{(cursor,low)}
    case False{}:
      do Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>:
        extra : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(cursor,1)
        upper_value(extra,low,U32.shln(1,U32.to_nat(U32.sub(width,1))),cutoff)

def lower_value(pair: DataPair.Duo(Bits.Fwd,U32),width: U32,+cutoff: U32) -> Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>:
  (cursor,+low) = pair
  lower_small(U32.is_lt(low,cutoff),cursor,low,width,cutoff)

def probability(cursor: Bits.Fwd,remaining: U32) -> Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>:
  +maximum = U32.add(remaining,1)
  +width = U32.add(U32.from_nat(U32.log2(maximum)),1)
  cutoff = U32.sub(U32.sub(U32.shln(1,U32.to_nat(width)),1),maximum)
  do Result<&2,&2,String,DataPair.Duo(Bits.Fwd,U32)>:
    low : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(cursor,U32.sub(width,1))
    lower_value(low,width,cutoff)

type Counts is Data:
  Counts{cursor: Bits.Fwd,reversed: List<&2,U32>,next: U32}

def zeroes(count: Nat,reversed: List<&2,U32>) -> List<&2,U32>:
  match count:
    case 0n: reversed
    case 1n+rest: zeroes(rest,Con{0,reversed})

def repeat_more(more: Bool,cursor: Bits.Fwd,reversed: List<&2,U32>,next: U32,
  again: Bits.Fwd -> List<&2,U32> -> U32 -> Result<&2,&2,String,Counts>) -> Result<&2,&2,String,Counts>:
  match more:
    case True{}: again(cursor,reversed,next)
    case False{}: Done{Counts{cursor,reversed,next}}

def repeated(pair: DataPair.Duo(Bits.Fwd,U32),reversed: List<&2,U32>,+next: U32,max_symbol: U32,
  again: Bits.Fwd -> List<&2,U32> -> U32 -> Result<&2,&2,String,Counts>) -> Result<&2,&2,String,Counts>:
  (cursor,+run) = pair
  checked(Counts,U32.is_le(U32.add(next,run),U32.add(max_symbol,1)),
    "FSE zero repeat exceeds symbol alphabet",_ =>
      repeat_more(U32.is_eq(run,3),cursor,zeroes(U32.to_nat(run),reversed),U32.add(next,run),again))

def repeat_zero(fuel: Nat,cursor: Bits.Fwd,reversed: List<&2,U32>,next: U32,+max_symbol: U32) -> Result<&2,&2,String,Counts>:
  match fuel:
    case 0n: Fail{"FSE zero repeat bound exceeded"}
    case 1n+rest:
      do Result<&2,&2,String,Counts>:
        pair : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(cursor,2)
        repeated(pair,reversed,next,max_symbol,
          stream => xs => index => repeat_zero(rest,stream,xs,index,max_symbol))

def decoded(pair: DataPair.Duo(Bits.Fwd,U32),+remaining: U32,reversed: List<&2,U32>,next: U32,max_symbol: U32) -> Result<&2,&2,String,DataPair.Duo(Counts,U32)>:
  match pair:
    case (cursor,0): Done{(Counts{cursor,Con{4294967295,reversed},U32.add(next,1)},U32.sub(remaining,1))}
    case (cursor,1):
      do Result<&2,&2,String,DataPair.Duo(Counts,U32)>:
        counts : Counts <- repeat_zero(256n,cursor,Con{0,reversed},U32.add(next,1),max_symbol)
        Done{(counts,remaining)}
    case (cursor,value):
      +count = U32.sub(value,1)
      checked(DataPair.Duo(Counts,U32),U32.is_le(count,remaining),"FSE count exceeds remaining probability mass",_ =>
        Done{(Counts{cursor,Con{count,reversed},U32.add(next,1)},U32.sub(remaining,count))})

def counts_continue(pair: DataPair.Duo(Counts,U32),
  next: Counts -> U32 -> Result<&2,&2,String,Counts>) -> Result<&2,&2,String,Counts>:
  (counts,remaining) = pair
  next(counts,remaining)

def read_counts(fuel: Nat,counts: Counts,+remaining: U32,+max_symbol: U32) -> Result<&2,&2,String,Counts>:
  match fuel counts remaining:
    case _ current 0: Done{current}
    case 0n _ _: Fail{"FSE probability count bound exceeded"}
    case 1n+rest Counts{cursor,reversed,+next} _:
      checked(Counts,U32.is_le(next,max_symbol),"FSE nonzero probability outside symbol alphabet",_ =>
        do Result<&2,&2,String,Counts>:
          pair : DataPair.Duo(Bits.Fwd,U32) <- probability(cursor,remaining)
          updated : DataPair.Duo(Counts,U32) <- decoded(pair,remaining,reversed,next,max_symbol)
          counts_continue(updated,next_counts => next_remaining =>
            read_counts(rest,next_counts,next_remaining,max_symbol)))

def read_finished(counts: Counts,log: U32) -> Result<&2,&2,String,DataPair.Duo(Table,List<&2,U32>)>:
  Counts{aligned,reversed,_} = counts
  do Result<&2,&2,String,DataPair.Duo(Table,List<&2,U32>)>:
    table : Table <- make_table(log,List.reverse(&2,U32,reversed))
    Done{(table,Bits.remaining_forward(aligned))}

def read_log(pair: DataPair.Duo(Bits.Fwd,U32),+max_symbol: U32,+max_log: U32) -> Result<&2,&2,String,DataPair.Duo(Table,List<&2,U32>)>:
  (cursor,low) = pair
  +log = U32.add(low,5)
  checked(DataPair.Duo(Table,List<&2,U32>),U32.is_le(log,max_log),"FSE table log exceeds alphabet limit",_ =>
    do Result<&2,&2,String,DataPair.Duo(Table,List<&2,U32>)>:
      counts : Counts <- read_counts(256n,Counts{cursor,[],0},U32.shln(1,U32.to_nat(log)),max_symbol)
      read_finished(counts,log))

def read_table(bytes: List<&2,U32>,+max_symbol: U32,+max_log: U32) -> Result<&2,&2,String,DataPair.Duo(Table,List<&2,U32>)>:
  checked(DataPair.Duo(Table,List<&2,U32>),U32.is_le(max_symbol,255) && U32.is_ge(max_log,5) && U32.is_le(max_log,9),
    "FSE parser alphabet or accuracy bound invalid",_ =>
      do Result<&2,&2,String,DataPair.Duo(Table,List<&2,U32>)>:
        pair : DataPair.Duo(Bits.Fwd,U32) <- Bits.read_forward(Bits.forward(bytes),4)
        read_log(pair,max_symbol,max_log))

# Format-defined defaults, not hand-maintained decoding arrays. The tests
# independently compare every resulting row with the published Appendix A.
def literals() -> Result<&2,&2,String,Table>:
  make_table(6,[4,3,2,2,2,2,2,2,2,2,2,2,2,1,1,1,2,2,2,2,2,2,2,2,2,3,2,1,1,1,1,1,4294967295,4294967295,4294967295,4294967295])

def matches() -> Result<&2,&2,String,Table>:
  make_table(6,[1,4,3,2,2,2,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,4294967295,4294967295,4294967295,4294967295,4294967295,4294967295,4294967295])

def offsets() -> Result<&2,&2,String,Table>:
  make_table(5,[1,1,1,1,1,1,2,2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,4294967295,4294967295,4294967295,4294967295,4294967295])
