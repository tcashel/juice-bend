import Base
import ./sql.bend as Sql
import ./claude_quota.bend as Quota

# This store accepts an already-owned dedicated database handle. It never opens
# capture storage, credentials, provider settings or a default home directory.
# Every public operation begins its own transaction; failed BEGIN leaves any
# caller transaction untouched. Only initialize may create the empty schema.
type State is Data:
  State{epoch: Nat, enabled: Bool}

type Sample is Data:
  Sample{sequence: Nat, epoch: Nat, received_at: Nat, observation: Quota.Observation}

type View is Data:
  View{state: State, samples: List<&2,Sample>, more: Bool, outcome: String}

def policy() -> String:
  "claude-statusline-v1"

def cap() -> Nat:
  Nat.add(Nat.mul(4294967295n,65536n),65535n)

def rows_type() -> Data:
  List<&2,List<&2,Sql.Cell>>

def answer_type() -> Data:
  Result<&2,&2,Quota.Failure,View>

def fail(code: String,message: String) -> answer_type():
  Fail{Quota.Failure{code,message}}

def pure(value: answer_type()) -> IO(answer_type()):
  IO.pure(answer_type(),value)

def database() -> answer_type():
  fail("quota_database_error","Quota storage operation failed; no provider data is included in this diagnostic")

def invalid() -> answer_type():
  fail("quota_storage_invalid","Quota storage identity, schema or typed values are invalid")

def blank(state: State,outcome: String) -> answer_type():
  Done{View{state,[],False{},outcome}}

# Branches receive continuations so arithmetic and IO stay behind their guard.
# Computed values become parameters before pattern matching in pinned Bend.
def branch(-A: Type,condition: Bool,yes: Unit -> A,no: Unit -> A) -> A:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def maybe_fold(-A: Data,-B: Type,value: Maybe<&2,A>,none: Unit -> B,some: A -> B) -> B:
  match value:
    case None{}: none(Unit{})
    case Some{value}: some(value)

# A single bounded SQL statement; error strings never include SQLite values.
def queried(result: Result<&1,&1,U32 & String,rows_type()>,next: rows_type() -> IO(answer_type())) -> IO(answer_type()):
  match result:
    case Fail{_}: pure(database())
    case Done{rows}: next(rows)

def query(db: U32,statement: String,args: List<&2,Sql.Cell>,limit: U32,
  next: rows_type() -> IO(answer_type())) -> IO(answer_type()):
  do IO<answer_type()>:
    result : Result<&1,&1,U32 & String,rows_type()> <- Sql.query(db,statement,args,limit)
    queried(result,next)

def finished(result: Result<&1,&1,U32 & String,rows_type()>,prior: answer_type()) -> IO(answer_type()):
  match result:
    case Done{_}: pure(prior)
    case Fail{_}: pure(fail("quota_cleanup_error","Quota transaction cleanup failed; close this connection"))

def rollback(db: U32,prior: answer_type()) -> IO(answer_type()):
  do IO<answer_type()>:
    result : Result<&1,&1,U32 & String,rows_type()> <- Sql.query(db,"ROLLBACK",[],0)
    finished(result,prior)

def committed(result: Result<&1,&1,U32 & String,rows_type()>,db: U32,view: View) -> IO(answer_type()):
  match result:
    case Done{_}: pure(Done{view})
    case Fail{_}: rollback(db,database())

def finish(prior: answer_type(),+db: U32,write: Bool) -> IO(answer_type()):
  match prior write:
    case Done{view} True{}:
      do IO<answer_type()>:
        result : Result<&1,&1,U32 & String,rows_type()> <- Sql.query(db,"COMMIT",[],0)
        committed(result,db,view)
    case other _:
      rollback(db,other)

def started(result: Result<&1,&1,U32 & String,rows_type()>,+db: U32,+write: Bool,
  operation: U32 -> IO(answer_type())) -> IO(answer_type()):
  match result:
    case Fail{_}: pure(fail("quota_transaction_unavailable","Cannot begin quota transaction; any caller transaction was left untouched"))
    case Done{_}:
      do IO<answer_type()>:
        prior : answer_type() <- operation(db)
        finish(prior,db,write)

def transaction(+db: U32,+write: Bool,operation: U32 -> IO(answer_type())) -> IO(answer_type()):
  do IO<answer_type()>:
    result : Result<&1,&1,U32 & String,rows_type()> <- Sql.query(db,
      Bool.pick(String,write,"BEGIN IMMEDIATE","BEGIN DEFERRED"),[],0)
    started(result,db,write,operation)

# Exact unsigned native Nat decoding checks before multiplying. SQLite's signed
# 64-bit column does not authorize truncation to U32 or the pinned 48-bit Nat.
def digit_next(+value: Nat,maximum: Nat,next: Nat -> Maybe<&2,Nat>) -> Maybe<&2,Nat>:
  branch(Maybe<&2,Nat>,Nat.is_le(value,maximum),_ => next(value),_ => None{})

def digits(text: String,+value: Nat,+maximum: Nat) -> Maybe<&2,Nat>:
  match text:
    case "": Some{value}
    case SCon{Chr{+c},rest}:
      branch(Maybe<&2,Nat>,U32.is_ge(c,48) && U32.is_le(c,57) &&
        (Nat.is_lt(value,Nat.div(maximum,10n)) ||
          (Nat.is_eq(value,Nat.div(maximum,10n)) &&
            Nat.is_le(U32.to_nat(U32.sub(c,48)),Nat.mod(maximum,10n)))),
        _ => digit_next(Nat.add(Nat.mul(value,10n),U32.to_nat(U32.sub(c,48))),maximum,
          next => digits(rest,next,maximum)),_ => None{})

def natural(text: String,maximum: Nat) -> Maybe<&2,Nat>:
  match text:
    case "": None{}
    case "0": Some{0n}
    case SCon{'0',_}: None{}
    case other: digits(other,0n,maximum)

def integer(cell: Sql.Cell,maximum: Nat) -> Maybe<&2,Nat>:
  match cell:
    case Sql.Cell.Integer{text}: natural(text,maximum)
    case _: None{}

def state_values(epoch: Maybe<&2,Nat>,enabled: Sql.Cell) -> Maybe<&2,State>:
  match epoch enabled:
    case Some{epoch} Sql.Cell.Integer{"0"}: Some{State{epoch,False{}}}
    case Some{+epoch} Sql.Cell.Integer{"1"}:
      branch(Maybe<&2,State>,Nat.is_gt(epoch,0n),_ => Some{State{epoch,True{}}},_ => None{})
    case _ _: None{}

def state(rows: rows_type()) -> Maybe<&2,State>:
  match rows:
    case [epoch,enabled,Sql.Cell.Integer{"1"}] <> []: state_values(integer(epoch,cap()),enabled)
    case _: None{}

def state_result(value: Maybe<&2,State>,db: U32,next: U32 -> State -> IO(answer_type())) -> IO(answer_type()):
  match value:
    case None{}: pure(invalid())
    case Some{state}: next(db,state)

def load(+db: U32,next: U32 -> State -> IO(answer_type())) -> IO(answer_type()):
  query(db,"SELECT epoch,enabled,version FROM main.quota_state WHERE id=1 LIMIT 2",[],2,
    rows => state_result(state(rows),db,next))

def identified(rows: rows_type(),db: U32,next: U32 -> State -> IO(answer_type())) -> IO(answer_type()):
  match rows:
    case [Sql.Cell.Integer{"1245860180"}] <> []: load(db,next)
    case _: pure(invalid())

def owned(+db: U32,next: U32 -> State -> IO(answer_type())) -> IO(answer_type()):
  query(db,"PRAGMA main.application_id",[],1,rows => identified(rows,db,next))

def state_same(a: State,b: State) -> Bool:
  State{ae,aa} = a
  State{be,ba} = b
  Nat.is_eq(ae,be) && U32.is_eq(Bool.to_u32(aa),Bool.to_u32(ba))

def state_checked(actual: State,+wanted: State,outcome: String) -> IO(answer_type()):
  branch(IO(answer_type()),state_same(actual,wanted),_ => pure(blank(wanted,outcome)),_ => pure(database()))

def state_readback(db: U32,wanted: State,outcome: String) -> IO(answer_type()):
  load(db,_ => actual => state_checked(actual,wanted,outcome))

def created(+db: U32) -> IO(answer_type()):
  query(db,"INSERT INTO main.quota_state(id,version,epoch,enabled) VALUES(1,1,0,0)",[],0,
    _ => state_readback(db,State{0n,False{}},"initialized"))

def create_samples(+db: U32) -> IO(answer_type()):
  query(db,"CREATE TABLE main.quota_samples(sequence INTEGER PRIMARY KEY AUTOINCREMENT CHECK(sequence>0 AND sequence<=281474976710655),epoch INTEGER NOT NULL CHECK(epoch>0 AND epoch<=281474976710655),received_at INTEGER NOT NULL CHECK(received_at>=0 AND received_at<=253402300799),slot INTEGER NOT NULL CHECK(slot>=0),five_present INTEGER NOT NULL CHECK(five_present IN(0,1)),five_used INTEGER CHECK(five_used>=0 AND five_used<=100000000),five_reset INTEGER CHECK(five_reset>=0 AND five_reset<=253402300799),seven_present INTEGER NOT NULL CHECK(seven_present IN(0,1)),seven_used INTEGER CHECK(seven_used>=0 AND seven_used<=100000000),seven_reset INTEGER CHECK(seven_reset>=0 AND seven_reset<=253402300799),policy TEXT NOT NULL CHECK(policy='claude-statusline-v1'),UNIQUE(epoch,slot),CHECK(five_present=1 OR (five_used IS NULL AND five_reset IS NULL)),CHECK(seven_present=1 OR (seven_used IS NULL AND seven_reset IS NULL)))",[],0,
    _ => created(db))

def create_state(+db: U32) -> IO(answer_type()):
  query(db,"CREATE TABLE main.quota_state(id INTEGER PRIMARY KEY CHECK(id=1),version INTEGER NOT NULL CHECK(version=1),epoch INTEGER NOT NULL CHECK(epoch>=0 AND epoch<=281474976710655),enabled INTEGER NOT NULL CHECK(enabled IN(0,1)),CHECK(enabled=0 OR epoch>0))",[],0,
    _ => create_samples(db))

def initialize_empty(rows: rows_type(),+db: U32) -> IO(answer_type()):
  match rows:
    case [Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"}] <> []:
      query(db,"PRAGMA main.application_id=1245860180",[],0,_ => create_state(db))
    case _: pure(fail("quota_not_empty","Only a new empty dedicated quota database can be initialized"))

def initialize_owned(+db: U32) -> IO(answer_type()):
  query(db,"SELECT (SELECT count(*) FROM main.sqlite_master),(SELECT application_id FROM pragma_application_id)",[],1,
    rows => initialize_empty(rows,db))

def initialize(db: U32) -> IO(answer_type()):
  transaction(db,True{},d => initialize_owned(d))

def enable_next(+db: U32,+next: Nat) -> IO(answer_type()):
  query(db,"UPDATE main.quota_state SET epoch=?,enabled=1 WHERE id=1",
    [Sql.Cell.Integer{Nat.show(next)}],0,_ => state_readback(db,State{next,True{}},"enabled"))

def enabled(db: U32,state: State) -> IO(answer_type()):
  State{+epoch,_} = state
  branch(IO(answer_type()),Nat.is_lt(epoch,cap()),_ => enable_next(db,Nat.add(epoch,1n)),
    _ => pure(fail("quota_epoch_exhausted","Quota connection epoch limit reached")))

def enable(db: U32) -> IO(answer_type()):
  transaction(db,True{},d => owned(d,b => s => enabled(b,s)))

def disabled(+db: U32,state: State) -> IO(answer_type()):
  State{epoch,_} = state
  query(db,"UPDATE main.quota_state SET enabled=0 WHERE id=1",[],0,
    _ => state_readback(db,State{epoch,False{}},"disconnected"))

def disconnect(db: U32) -> IO(answer_type()):
  transaction(db,True{},d => owned(d,b => s => disabled(b,s)))

def maybe_natural(cell: Sql.Cell,maximum: Nat) -> Maybe<&2,Maybe<&2,Nat>>:
  match cell:
    case Sql.Cell.Null{}: Some{None{}}
    case other:
      maybe_fold(Nat,Maybe<&2,Maybe<&2,Nat>>,integer(other,maximum),_ => None{},value => Some{Some{value}})

def percent(value: Maybe<&2,Nat>) -> Maybe<&2,U32>:
  match value:
    case None{}: None{}
    case Some{value}: Some{U32.from_nat(value)}

def window_values(present: Sql.Cell,used: Maybe<&2,Maybe<&2,Nat>>,reset: Maybe<&2,Maybe<&2,Nat>>) ->
  Maybe<&2,Maybe<&2,Quota.QuotaWindow>>:
  match present used reset:
    case Sql.Cell.Integer{"0"} Some{None{}} Some{None{}}: Some{None{}}
    case Sql.Cell.Integer{"1"} Some{used} Some{reset}: Some{Some{Quota.QuotaWindow{percent(used),reset}}}
    case _ _ _: None{}

def window(present: Sql.Cell,used: Sql.Cell,reset: Sql.Cell) -> Maybe<&2,Maybe<&2,Quota.QuotaWindow>>:
  window_values(present,maybe_natural(used,100000000n),maybe_natural(reset,Nat.add(Nat.mul(253n,1000000000n),402300799n)))

def sample_values(seq: Maybe<&2,Nat>,epoch: Maybe<&2,Nat>,receipt: Maybe<&2,Nat>,
  five: Maybe<&2,Maybe<&2,Quota.QuotaWindow>>,seven: Maybe<&2,Maybe<&2,Quota.QuotaWindow>>) -> Maybe<&2,Sample>:
  match seq epoch receipt five seven:
    case Some{+seq} Some{+epoch} Some{receipt} Some{five} Some{seven}:
      branch(Maybe<&2,Sample>,Nat.is_gt(seq,0n) && Nat.is_gt(epoch,0n),
        _ => Some{Sample{seq,epoch,receipt,Quota.Observation{five,seven}}},_ => None{})
    case _ _ _ _ _: None{}

def sample_slot_value(+value: Sample,slot: Nat) -> Maybe<&2,Sample>:
  Sample{_,_,receipt,_} = value
  branch(Maybe<&2,Sample>,Nat.is_eq(slot,Nat.div(receipt,300n)),_ => Some{value},_ => None{})

def sample_slot(value: Maybe<&2,Sample>,slot: Maybe<&2,Nat>) -> Maybe<&2,Sample>:
  match value slot:
    case Some{value} Some{slot}: sample_slot_value(value,slot)
    case _ _: None{}

def sample(row: List<&2,Sql.Cell>) -> Maybe<&2,Sample>:
  match row:
    case [seq,epoch,receipt,fp,fu,fr,sp,su,sr,Sql.Cell.Text{"claude-statusline-v1"},slot]:
      sample_slot(sample_values(integer(seq,cap()),integer(epoch,cap()),integer(receipt,Nat.add(Nat.mul(253n,1000000000n),402300799n)),
        window(fp,fu,fr),window(sp,su,sr)),integer(slot,844674335n))
    case _: None{}

def samples(rows: rows_type(),done: List<&2,Sample>,fuel: Nat) -> Maybe<&2,List<&2,Sample>>:
  match rows fuel:
    case Nil{} _: Some{List.reverse(&2,Sample,done)}
    case _ 0n: None{}
    case Con{row,rest} 1n+n:
      maybe_fold(Sample,Maybe<&2,List<&2,Sample>>,sample(row),_ => None{},value => samples(rest,value <> done,n))

def selected_values(values: Maybe<&2,List<&2,Sample>>,state: State,limit: Nat,more: Bool,outcome: String) -> answer_type():
  match values:
    case None{}: invalid()
    case Some{values}: Done{View{state,List.take(&2,Sample,values,limit),more,outcome}}

def selected_samples(+rows: rows_type(),state: State,+limit: Nat,outcome: String) -> answer_type():
  selected_values(samples(rows,[],41n),state,limit,
    Nat.is_gt(List.length(&2,List<&2,Sql.Cell>,rows),limit),outcome)

def status_owned(+db: U32,+state: State) -> IO(answer_type()):
  State{epoch,_} = state
  query(db,"SELECT sequence,epoch,received_at,five_present,five_used,five_reset,seven_present,seven_used,seven_reset,policy,slot FROM main.quota_samples WHERE epoch=? ORDER BY sequence DESC LIMIT 1",
    [Sql.Cell.Integer{Nat.show(epoch)}],1,rows => pure(selected_samples(rows,state,1n,"status")))

def status(db: U32) -> IO(answer_type()):
  transaction(db,False{},d => owned(d,b => s => status_owned(b,s)))

def history_owned(+db: U32,state: State,offset: U32) -> IO(answer_type()):
  query(db,"SELECT sequence,epoch,received_at,five_present,five_used,five_reset,seven_present,seven_used,seven_reset,policy,slot FROM main.quota_samples ORDER BY sequence DESC LIMIT 41 OFFSET ?",
    [Sql.Cell.Integer{U32.show(offset)}],41,rows => pure(selected_samples(rows,state,40n,"history")))

def history(db: U32,+offset: U32) -> IO(answer_type()):
  branch(IO(answer_type()),U32.is_le(offset,32768),
    _ => transaction(db,False{},d => owned(d,b => s => history_owned(b,s,offset))),
    _ => pure(fail("quota_page_invalid","Quota history offset must be at most 32768")))

def used_cell(value: Maybe<&2,U32>) -> Sql.Cell:
  match value:
    case None{}: Sql.Cell.Null{}
    case Some{value}: Sql.Cell.Integer{U32.show(value)}

def reset_cell(value: Maybe<&2,Nat>) -> Sql.Cell:
  match value:
    case None{}: Sql.Cell.Null{}
    case Some{value}: Sql.Cell.Integer{Nat.show(value)}

def window_cells(window: Maybe<&2,Quota.QuotaWindow>) -> List<&2,Sql.Cell>:
  match window:
    case None{}: [Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Null{}]
    case Some{Quota.QuotaWindow{used,reset}}: [Sql.Cell.Integer{"1"},used_cell(used),reset_cell(reset)]

def record_sample(+value: Sample,+state: State,receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  Sample{_,actual_epoch,actual_receipt,actual} = value
  State{epoch,_} = state
  branch(IO(answer_type()),Nat.is_eq(epoch,actual_epoch) && Nat.is_eq(receipt,actual_receipt) && Quota.same(observation,actual),
    _ => pure(Done{View{state,[value],False{},"accepted"}}),_ => pure(database()))

def record_checked(rows: rows_type(),state: State,receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  match rows:
    case [row]:
      maybe_fold(Sample,IO(answer_type()),sample(row),_ => pure(invalid()),
        value => record_sample(value,state,receipt,observation))
    case _: pure(database())

def record_readback(+db: U32,+state: State,+receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  State{epoch,_} = state
  query(db,"SELECT sequence,epoch,received_at,five_present,five_used,five_reset,seven_present,seven_used,seven_reset,policy,slot FROM main.quota_samples WHERE epoch=? AND slot=? LIMIT 2",
    [Sql.Cell.Integer{Nat.show(epoch)},Sql.Cell.Integer{Nat.show(Nat.div(receipt,300n))}],2,
    rows => record_checked(rows,state,receipt,observation))

def retention_checked(rows: rows_type(),db: U32,state: State,receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  match rows:
    case [count,Sql.Cell.Integer{"0"}] <> []:
      maybe_fold(Nat,IO(answer_type()),integer(count,32768n),_ => pure(database()),
        _ => record_readback(db,state,receipt,observation))
    case _: pure(database())

def retention_readback(+db: U32,state: State,+receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  query(db,"SELECT count(*),(SELECT count(*) FROM main.quota_samples WHERE received_at<?) FROM main.quota_samples",
    [Sql.Cell.Integer{Nat.show(Nat.sub(receipt,7776000n))}],1,
    rows => retention_checked(rows,db,state,receipt,observation))

def capped(+db: U32,state: State,receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  query(db,"DELETE FROM main.quota_samples WHERE sequence NOT IN(SELECT sequence FROM main.quota_samples ORDER BY sequence DESC LIMIT 32768)",[],0,
    _ => retention_readback(db,state,receipt,observation))

def pruned(+db: U32,state: State,+receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  query(db,"DELETE FROM main.quota_samples WHERE received_at<?",
    [Sql.Cell.Integer{Nat.show(Nat.sub(receipt,7776000n))}],0,_ => capped(db,state,receipt,observation))

def inserted(+db: U32,+state: State,+receipt: Nat,+observation: Quota.Observation) -> IO(answer_type()):
  State{epoch,_} = state
  Quota.Observation{five,seven} = observation
  query(db,"INSERT INTO main.quota_samples(epoch,received_at,slot,five_present,five_used,five_reset,seven_present,seven_used,seven_reset,policy) VALUES(?,?,?,?,?,?,?,?,?,?)",
    List.append(&2,Sql.Cell,[Sql.Cell.Integer{Nat.show(epoch)},Sql.Cell.Integer{Nat.show(receipt)},Sql.Cell.Integer{Nat.show(Nat.div(receipt,300n))}],
      List.append(&2,Sql.Cell,window_cells(five),List.append(&2,Sql.Cell,window_cells(seven),[Sql.Cell.Text{policy()}]))),0,
    _ => pruned(db,state,receipt,observation))

def replace_slot(+db: U32,+state: State,+receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  State{epoch,_} = state
  query(db,"DELETE FROM main.quota_samples WHERE epoch=? AND slot=?",
    [Sql.Cell.Integer{Nat.show(epoch)},Sql.Cell.Integer{Nat.show(Nat.div(receipt,300n))}],0,
    _ => inserted(db,state,receipt,observation))

def accept(db: U32,+state: State,epoch: Nat,receipt: Nat,+observation: Quota.Observation) -> IO(answer_type()):
  State{current,enabled} = state
  branch(IO(answer_type()),enabled && Nat.is_eq(current,epoch),
    _ => branch(IO(answer_type()),Quota.empty(observation),_ => pure(blank(state,"waiting")),
      _ => replace_slot(db,state,receipt,observation)),
    _ => pure(fail("quota_epoch_retired","Quota collection is off or this callback belongs to a retired connection")))

# Receipt is injected only at this trusted backend seam for deterministic tests.
# Production CLI obtains local time itself; feed data never supplies the clock.
def record(db: U32,+epoch: Nat,+receipt: Nat,observation: Quota.Observation) -> IO(answer_type()):
  branch(IO(answer_type()),Nat.is_gt(epoch,0n) && Nat.is_le(epoch,cap()) && Nat.is_le(receipt,Nat.add(Nat.mul(253n,1000000000n),402300799n)),
    _ => transaction(db,True{},d => owned(d,b => s => accept(b,s,epoch,receipt,observation))),
    _ => pure(fail("quota_input_invalid","Quota epoch or local receipt time is out of range")))
