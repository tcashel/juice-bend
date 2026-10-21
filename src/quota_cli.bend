import Base
import ./claude_quota.bend as Quota
import ./quota_store.bend as Store
import ./domain.bend as Domain
import ./json.bend as Json
import ./sql.bend as Sql

# Embedding executable must dispatch before opening capture storage and provide
# an already-owned dedicated quota handle. No path, provider or auth IO here.
type Command is Data:
  Status{}
  Enable{}
  Disconnect{}
  History{offset: U32}
  Observe{epoch: Nat, footer: Bool}

def protocol() -> String:
  "claude_quota_v1"

def limit() -> U32:
  1048576

def result_type() -> Data:
  Result<&2,&2,Quota.Failure,String>

def invalid() -> Result<&2,&2,Quota.Failure,Command>:
  Fail{Quota.Failure{"quota_usage","Expected status, enable, disconnect, history OFFSET, observe-claude EPOCH or statusline-claude EPOCH"}}

def observed(value: Maybe<&2,Nat>,footer: Bool) -> Result<&2,&2,Quota.Failure,Command>:
  match value:
    case Some{+value}:
      Bool.pick(Result<&2,&2,Quota.Failure,Command>,Nat.is_gt(value,0n),Done{Observe{value,footer}},invalid())
    case None{}: invalid()

def observe(epoch: String,footer: Bool) -> Result<&2,&2,Quota.Failure,Command>:
  observed(Store.natural(epoch,Store.cap()),footer)

def history(value: Maybe<&2,Nat>) -> Result<&2,&2,Quota.Failure,Command>:
  match value:
    case Some{offset}: Done{History{U32.from_nat(offset)}}
    case None{}: invalid()

def parse(operation: String,args: List<&2,String>) -> Result<&2,&2,Quota.Failure,Command>:
  match operation args:
    case "status" Nil{}: Done{Status{}}
    case "enable" Nil{}: Done{Enable{}}
    case "disconnect" Nil{}: Done{Disconnect{}}
    case "history" Con{text,Nil{}}: history(Store.natural(text,32768n))
    case "observe-claude" Con{epoch,Nil{}}: observe(epoch,False{})
    case "statusline-claude" Con{epoch,Nil{}}: observe(epoch,True{})
    case _ _: invalid()

def boolean(value: Bool) -> String:
  Bool.pick(String,value,"true","false")

def maybe_used(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}: "null"
    case Some{value}: U32.show(value)

def maybe_reset(value: Maybe<&2,Nat>) -> String:
  match value:
    case None{}: "null"
    case Some{value}: Json.quote(Nat.show(value))

def window(value: Maybe<&2,Quota.QuotaWindow>) -> String:
  match value:
    case None{}: "null"
    case Some{Quota.QuotaWindow{used,reset}}:
      "{\"used_millionths\":" ++ maybe_used(used) ++ ",\"resets_at\":" ++ maybe_reset(reset) ++ "}"

def sample(value: Store.Sample) -> String:
  Store.Sample{sequence,epoch,receipt,Quota.Observation{five,seven}} = value
  "{\"sequence\":" ++ Json.quote(Nat.show(sequence)) ++ ",\"epoch\":" ++ Json.quote(Nat.show(epoch)) ++
    ",\"received_at\":" ++ Json.quote(Nat.show(receipt)) ++ ",\"parser\":" ++ Json.quote(Store.policy()) ++
    ",\"five_hour\":" ++ window(five) ++ ",\"seven_day\":" ++ window(seven) ++ "}"

def samples(values: List<&2,Store.Sample>) -> String:
  match values:
    case []: ""
    case [value]: sample(value)
    case value <> rest: sample(value) ++ "," ++ samples(rest)

def encode(view: Store.View) -> String:
  Store.View{Store.State{epoch,enabled},values,more,outcome} = view
  "{\"kind\":" ++ Json.quote(protocol()) ++ ",\"outcome\":" ++ Json.quote(outcome) ++
    ",\"enabled\":" ++ boolean(enabled) ++ ",\"epoch\":" ++ Json.quote(Nat.show(epoch)) ++
    ",\"samples\":[" ++ samples(values) ++ "],\"more\":" ++ boolean(more) ++ "}"

def error(value: Quota.Failure) -> String:
  Quota.Failure{code,message} = value
  "{\"kind\":" ++ Json.quote(protocol()) ++ ",\"outcome\":\"error\",\"code\":" ++ Json.quote(code) ++
    ",\"message\":" ++ Json.quote(message) ++ "}"

def encoded(result: Store.answer_type()) -> result_type():
  match result:
    case Fail{problem}: Fail{problem}
    case Done{view}: Done{encode(view)}

# Time comes only from this local clock, never callback JSON or command args.
# It measures receipt before lock acquisition, not provider refresh/freshness.
def clock_natural(value: Maybe<&2,Nat>) -> Result<&2,&2,Quota.Failure,Nat>:
  match value:
    case Some{value}: Done{value}
    case None{}: Fail{Quota.Failure{"quota_clock","Local receipt clock is out of range"}}

def clock_value(rows: Store.rows_type()) -> Result<&2,&2,Quota.Failure,Nat>:
  match rows:
    case [Sql.Cell.Text{text}] <> []:
      clock_natural(Store.natural(text,Nat.add(Nat.mul(253n,1000000000n),402300799n)))
    case _: Fail{Quota.Failure{"quota_clock","Local receipt clock is unavailable"}}

def clock_result(result: Result<&1,&1,U32 & String,Store.rows_type()>) -> Result<&2,&2,Quota.Failure,Nat>:
  match result:
    case Fail{_}: Fail{Quota.Failure{"quota_clock","Local receipt clock is unavailable"}}
    case Done{rows}: clock_value(rows)

def clock(db: U32) -> IO(Result<&2,&2,Quota.Failure,Nat>):
  do IO<Result<&2,&2,Quota.Failure,Nat>>:
    result : Result<&1,&1,U32 & String,Store.rows_type()> <- Sql.query(db,"SELECT strftime('%s','now')",[],1)
    return clock_result(result)

def timed(db: U32,epoch: Nat,observation: Quota.Observation,time: Result<&2,&2,Quota.Failure,Nat>) -> IO(Store.answer_type()):
  match time:
    case Fail{problem}: Store.pure(Fail{problem})
    case Done{receipt}: Store.record(db,epoch,receipt,observation)

def receive_parsed(+db: U32,epoch: Nat,result: Result<&2,&2,Quota.Failure,Quota.Observation>) -> IO(Store.answer_type()):
  match result:
    case Fail{problem}: Store.pure(Fail{problem})
    case Done{observation}:
      do IO<Store.answer_type()>:
        time : Result<&2,&2,Quota.Failure,Nat> <- clock(db)
        timed(db,epoch,observation,time)

def receive(db: U32,epoch: Nat,body: String) -> IO(Store.answer_type()):
  receive_parsed(db,epoch,Quota.parse(body))

def dispatch(db: U32,command: Command,body: String) -> IO(Store.answer_type()):
  match command:
    case Status{}: Store.status(db)
    case Enable{}: Store.enable(db)
    case Disconnect{}: Store.disconnect(db)
    case History{offset}: Store.history(db,offset)
    case Observe{epoch,_}: receive(db,epoch,body)

def decoded(result: Result<&2,&2,String,String>) -> result_type():
  match result:
    case Fail{_}: Fail{Quota.Failure{"quota_utf8","Quota stdin must be strict UTF8"}}
    case Done{text}: Done{text}

def read_sized(fits: Bool,file: File,size: U32,total: U32,part: List<&2,U32>,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(result_type())) -> IO(result_type()):
  match fits:
    case False{}:
      do IO<result_type()>:
        File.close(file)
        return Fail{Quota.Failure{"quota_input_limit","Quota stdin exceeds 1048576 bytes"}}
    case True{}: next(file,U32.add(total,size),part <> chunks)

def read_chunk(file: File,bytes: List<&2,U32>,+total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(result_type())) -> IO(result_type()):
  match bytes:
    case []:
      do IO<result_type()>:
        File.close(file)
        return decoded(Domain.decode(List.concat(&2,U32,List.reverse(&2,List<&2,U32>,chunks))))
    case byte <> rest:
      +part = {byte <> rest : List<&2,U32>}
      +size = U32.from_nat(List.length(&2,U32,part))
      read_sized(U32.is_le(size,U32.sub(limit(),total)),file,size,total,part,chunks,next)

def read_result(got: File & Result<&1,&1,U32 & String,List<&2,U32>>,total: U32,chunks: List<&2,List<&2,U32>>,
  next: File -> U32 -> List<&2,List<&2,U32>> -> IO(result_type())) -> IO(result_type()):
  (file,result) = got
  match result:
    case Fail{_}:
      do IO<result_type()>:
        File.close(file)
        return Fail{Quota.Failure{"quota_stdin","Unable to read quota stdin"}}
    case Done{bytes}: read_chunk(file,bytes,total,chunks,next)

def read(fuel: Nat,+total: U32,chunks: List<&2,List<&2,U32>>,file: File) -> IO(result_type()):
  match fuel:
    case 0n:
      do IO<result_type()>:
        File.close(file)
        return Fail{Quota.Failure{"quota_input_limit","Quota stdin read limit exceeded"}}
    case 1n+rest:
      do IO<result_type()>:
        got : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
          File.read_bytes(file,U32.min(4096,U32.add(U32.sub(limit(),total),1)))
        read_result(got,total,chunks,f => n => parts => read(rest,n,parts,f))

def stdin_opened(result: Result<&1,&1,U32 & String,File>) -> IO(result_type()):
  match result:
    case Fail{_}: IO.pure(result_type(),Fail{Quota.Failure{"quota_stdin","Unable to open quota stdin"}})
    case Done{file}: read(1048577n,0,[],file)

def stdin() -> IO(result_type()):
  do IO<result_type()>:
    opened : Result<&1,&1,U32 & String,File> <- File.open("/dev/stdin","r")
    stdin_opened(opened)

# Footer mode never presents machine JSON or source values as Claude UI text.
def footer_outcome(outcome: String) -> String:
  match outcome:
    case "accepted": "Juice Bend quota: received locally"
    case "waiting": "Juice Bend quota: waiting for limits"
    case _: "Juice Bend quota: unavailable"

def footer(value: Store.View) -> String:
  Store.View{_,_,_,outcome} = value
  footer_outcome(outcome)

def emit(result: Store.answer_type(),as_footer: Bool) -> IO(Unit):
  match result as_footer:
    case Done{view} True{}: IO.print(footer(view))
    case Done{view} False{}: IO.print(encode(view))
    case Fail{problem} False{}: IO.die(Unit,2,error(problem))
    case Fail{problem} True{}:
      do IO<Unit>:
        IO.print_err(error(problem))
        IO.print("Juice Bend quota: unavailable")

def run_body(db: U32,epoch: Nat,as_footer: Bool,result: result_type()) -> IO(Unit):
  match result:
    case Fail{problem}: emit(Fail{problem},as_footer)
    case Done{body}:
      do IO<Unit>:
        response : Store.answer_type() <- receive(db,epoch,body)
        emit(response,as_footer)

def run_command(db: U32,command: Command) -> IO(Unit):
  match command:
    case Observe{epoch,as_footer}:
      do IO<Unit>:
        body : result_type() <- stdin()
        run_body(db,epoch,as_footer,body)
    case other:
      do IO<Unit>:
        result : Store.answer_type() <- dispatch(db,other,"")
        emit(result,False{})

def run_parsed(db: U32,result: Result<&2,&2,Quota.Failure,Command>) -> IO(Unit):
  match result:
    case Fail{problem}: emit(Fail{problem},False{})
    case Done{command}: run_command(db,command)

def run(db: U32,operation: String,args: List<&2,String>) -> IO(Unit):
  run_parsed(db,parse(operation,args))

# Pure reviewed configuration text only. This is not a config installer, auth
# reader, command runner, command chainer or promise of an authenticated account.
def path_chars(value: String,fuel: Nat) -> Bool:
  match value fuel:
    case "" _: True{}
    case _ 0n: False{}
    case SCon{Chr{+c},rest} 1n+n:
      U32.is_ge(c,32) && U32.is_ne(c,127) && U32.is_le(c,1114111) &&
        Bool.not(U32.is_ge(c,55296) && U32.is_le(c,57343)) && path_chars(rest,n)

def path(+value: String) -> Bool:
  String.starts_with(value,"/") && path_chars(value,4096n)

def literal_tail(value: String) -> String:
  match value:
    case "": ""
    case SCon{'\'',rest}: "'\"'\"'" ++ literal_tail(rest)
    case SCon{c,rest}: SCon{c,literal_tail(rest)}

def literal(value: String) -> String:
  "'" ++ literal_tail(value) ++ "'"

def setup_valid(valid: Bool,program: String,root: String,epoch: Nat) -> result_type():
  match valid:
    case False{}: Fail{Quota.Failure{"quota_setup","Setup requires explicit absolute paths without control characters and a positive current epoch"}}
    case True{}:
      command = literal(program) ++ " '--data-dir' " ++ literal(root) ++ " 'quota' 'statusline-claude' " ++ literal(Nat.show(epoch))
      Done{"{\"statusLine\":{\"type\":\"command\",\"command\":" ++ Json.quote(command) ++ "}}"}

def setup(+program: String,+root: String,+epoch: Nat) -> result_type():
  setup_valid(path(program) && path(root) && Nat.is_gt(epoch,0n) && Nat.is_le(epoch,Store.cap()),program,root,epoch)
