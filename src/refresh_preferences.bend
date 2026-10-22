import Base
import ./sql.bend as Sql

# This module only reads or writes two owned main.settings keys. It never
# creates a schema, discovers sources, starts capture, or reads the filesystem.
# Loading missing keys is read-only. Each call owns its transaction only after
# BEGIN succeeds; a preexisting caller transaction is never ended or changed.
type Interval is Data:
  Live30{}
  Hours2{}
  Hours4{}
  Hours8{}
  Daily{}

type Preferences is Data:
  Preferences{enabled: Bool, interval: Interval}

type Failure is Data:
  Failure{code: String, message: String}

type DecodeState is Data:
  DecodeState{preferences: Preferences, enabled_seen: Bool, interval_seen: Bool}

def enabled_key() -> String:
  "refresh.enabled"

def interval_key() -> String:
  "refresh.interval_seconds"

def defaults() -> Preferences:
  Preferences{True{},Live30{}}

def seconds(interval: Interval) -> U32:
  match interval:
    case Live30{}: 30
    case Hours2{}: 7200
    case Hours4{}: 14400
    case Hours8{}: 28800
    case Daily{}: 86400

def milliseconds(interval: Interval) -> Nat:
  Nat.mul(U32.to_nat(seconds(interval)),1000n)

def enabled_text(enabled: Bool) -> String:
  Bool.pick(String,enabled,"true","false")

def native_limit() -> Nat:
  Nat.add(Nat.mul(4294967295n,65536n),65535n)

def interval_from_text(text: String) -> Maybe<&2,Interval>:
  match text:
    case "30": Some{Live30{}}
    case "7200": Some{Hours2{}}
    case "14400": Some{Hours4{}}
    case "28800": Some{Hours8{}}
    case "86400": Some{Daily{}}
    case _: None{}

def enabled_from_text(text: String) -> Maybe<&2,Bool>:
  match text:
    case "true": Some{True{}}
    case "false": Some{False{}}
    case _: None{}

def parse_values(enabled: Maybe<&2,Bool>,interval: Maybe<&2,Interval>) ->
  Result<&2,&2,Failure,Preferences>:
  match enabled interval:
    case Some{enabled} Some{interval}:
      Done{Preferences{enabled,interval}}
    case _ _:
      Fail{Failure{"invalid_preference","Enabled must be true or false; interval seconds must be exactly 30, 7200, 14400, 28800, or 86400"}}

def parse(enabled: String,interval: String) -> Result<&2,&2,Failure,Preferences>:
  parse_values(enabled_from_text(enabled),interval_from_text(interval))

def same(a: Preferences,b: Preferences) -> Bool:
  Preferences{ae,ai} = a
  Preferences{be,bi} = b
  String.eq(enabled_text(ae),enabled_text(be)) && U32.is_eq(seconds(ai),seconds(bi))

# The pinned native compiler represents Nat up to 2^48-1. Check subtraction
# before addition; neither U32 uptime truncation nor a native overflow trap is
# an acceptable schedule. Disabled refresh has no armed deadline.
def deadline_active(valid: Bool,now: Nat,delay: Nat) -> Result<&2,&2,Failure,Maybe<&2,Nat>>:
  match valid:
    case True{}: Done{Some{Nat.add(now,delay)}}
    case False{}: Fail{Failure{"refresh_deadline_overflow","Refresh deadline exceeds the pinned native Nat limit; automatic refresh was not armed"}}

def deadline(preferences: Preferences,+now: Nat) -> Result<&2,&2,Failure,Maybe<&2,Nat>>:
  Preferences{enabled,interval} = preferences
  match enabled:
    case False{}: Done{None{}}
    case True{}:
      +delay = milliseconds(interval)
      deadline_active(Nat.is_le(now,Nat.sub(native_limit(),delay)),now,delay)

def invalid(key: String,reason: String) -> Failure:
  Failure{"invalid_stored_preference","Invalid stored " ++ key ++ ": " ++ reason ++ "; no preference was changed"}

def database(stage: String,code: U32) -> Failure:
  Failure{"preference_database_error","Refresh preference " ++ stage ++ " failed (SQLite " ++ U32.show(code) ++ ")"}

def parsed_enabled(value: Maybe<&2,Bool>,interval: Interval) -> Result<&2,&2,Failure,Preferences>:
  match value:
    case Some{enabled}: Done{Preferences{enabled,interval}}
    case None{}: Fail{invalid(enabled_key(),"expected TEXT true or false")}

def row_enabled(value: Sql.Cell,interval: Interval) -> Result<&2,&2,Failure,Preferences>:
  match value:
    case Sql.Cell.Text{text}: parsed_enabled(enabled_from_text(text),interval)
    case _: Fail{invalid(enabled_key(),"expected a TEXT value")}

def parsed_interval(enabled: Bool,value: Maybe<&2,Interval>) -> Result<&2,&2,Failure,Preferences>:
  match value:
    case Some{interval}: Done{Preferences{enabled,interval}}
    case None{}: Fail{invalid(interval_key(),"expected TEXT 30, 7200, 14400, 28800, or 86400")}

def row_interval(enabled: Bool,value: Sql.Cell) -> Result<&2,&2,Failure,Preferences>:
  match value:
    case Sql.Cell.Text{text}: parsed_interval(enabled,interval_from_text(text))
    case _: Fail{invalid(interval_key(),"expected a TEXT value")}

def decode_state(result: Result<&2,&2,Failure,Preferences>,enabled_seen: Bool,interval_seen: Bool) ->
  Result<&2,&2,Failure,DecodeState>:
  match result:
    case Fail{error}: Fail{error}
    case Done{preferences}: Done{DecodeState{preferences,enabled_seen,interval_seen}}

def decode_enabled(seen: Bool,value: Sql.Cell,interval: Interval,interval_seen: Bool) -> Result<&2,&2,Failure,DecodeState>:
  match seen:
    case True{}: Fail{invalid(enabled_key(),"duplicate key")}
    case False{}: decode_state(row_enabled(value,interval),True{},interval_seen)

def decode_interval(seen: Bool,enabled: Bool,value: Sql.Cell,enabled_seen: Bool) -> Result<&2,&2,Failure,DecodeState>:
  match seen:
    case True{}: Fail{invalid(interval_key(),"duplicate key")}
    case False{}: decode_state(row_interval(enabled,value),enabled_seen,True{})

def decode_row(state: Result<&2,&2,Failure,DecodeState>,row: List<&2,Sql.Cell>) -> Result<&2,&2,Failure,DecodeState>:
  match state row:
    case Fail{error} _: Fail{error}
    case Done{DecodeState{Preferences{enabled,interval},enabled_seen,interval_seen}} Sql.Cell.Text{"refresh.enabled"} <> value <> []:
      decode_enabled(enabled_seen,value,interval,interval_seen)
    case Done{DecodeState{Preferences{enabled,interval},enabled_seen,interval_seen}} Sql.Cell.Text{"refresh.interval_seconds"} <> value <> []:
      decode_interval(interval_seen,enabled,value,enabled_seen)
    case _ _: Fail{invalid("refresh preference row","unexpected key, type, or row shape")}

def decode_presence(present: Bool,preferences: Preferences) -> Result<&2,&2,Failure,Preferences>:
  match present:
    case True{}: Done{preferences}
    case False{}: Fail{Failure{"preference_database_error","Refresh preference readback is missing a required saved key; no update was committed"}}

def decode_done(state: Result<&2,&2,Failure,DecodeState>,required: Bool) -> Result<&2,&2,Failure,Preferences>:
  match state:
    case Fail{error}: Fail{error}
    case Done{DecodeState{preferences,enabled_seen,interval_seen}}:
      decode_presence(Bool.not(required) || (enabled_seen && interval_seen),preferences)

def decoded(rows: List<&2,List<&2,Sql.Cell>>,state: Result<&2,&2,Failure,DecodeState>,required: Bool) -> Result<&2,&2,Failure,Preferences>:
  match rows:
    case []: decode_done(state,required)
    case row <> rest: decoded(rest,decode_row(state,row),required)

def decode(rows: List<&2,List<&2,Sql.Cell>>) -> Result<&2,&2,Failure,Preferences>:
  decoded(rows,Done{DecodeState{defaults(),False{},False{}}},False{})

# Load may default missing keys. Save's readback must instead observe both
# exact keys once, even if an absent value would equal the requested default.
def decode_required(rows: List<&2,List<&2,Sql.Cell>>) -> Result<&2,&2,Failure,Preferences>:
  decoded(rows,Done{DecodeState{defaults(),False{},False{}}},True{})

def read_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,required: Bool) ->
  Result<&2,&2,Failure,Preferences>:
  match result:
    case Fail{(code,_)}: Fail{database("read",code)}
    case Done{rows}: decoded(rows,Done{DecodeState{defaults(),False{},False{}}},required)

# Three rows detect duplicate exact keys in a malformed schema without an
# unbounded result. Main qualification excludes temporary/attached shadows.
def read_owned(db: U32,required: Bool) -> IO(Result<&2,&2,Failure,Preferences>):
  do IO<Result<&2,&2,Failure,Preferences>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,
      "SELECT key,value FROM main.settings WHERE key IN (?,?) ORDER BY key LIMIT 3",
      [Sql.Cell.Text{enabled_key()},Sql.Cell.Text{interval_key()}],3)
    return read_result(result,required)

def begin_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) ->
  Result<&2,&2,Failure,Unit>:
  match result:
    case Done{_}: Done{Unit{}}
    case Fail{(code,_)}:
      Fail{Failure{"preference_transaction_unavailable","Cannot start the refresh preference transaction (SQLite " ++
        U32.show(code) ++ "); any existing caller transaction was left untouched"}}

def begin(db: U32,write: Bool) -> IO(Result<&2,&2,Failure,Unit>):
  do IO<Result<&2,&2,Failure,Unit>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,
      Bool.pick(String,write,"BEGIN IMMEDIATE","BEGIN DEFERRED"),[],0)
    return begin_result(result)

def rollback_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,
  prior: Result<&2,&2,Failure,Preferences>) -> Result<&2,&2,Failure,Preferences>:
  match result:
    case Done{_}: prior
    case Fail{(code,_)}:
      Fail{Failure{"preference_cleanup_error","Refresh preference rollback failed (SQLite " ++ U32.show(code) ++
        "); do not reuse this connection without resolving its transaction state"}}

def rollback(db: U32,prior: Result<&2,&2,Failure,Preferences>) ->
  IO(Result<&2,&2,Failure,Preferences>):
  do IO<Result<&2,&2,Failure,Preferences>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"ROLLBACK",[],0)
    return rollback_result(result,prior)

def load_started(started: Result<&2,&2,Failure,Unit>,+db: U32) -> IO(Result<&2,&2,Failure,Preferences>):
  match started:
    case Fail{error}: IO.pure(Result<&2,&2,Failure,Preferences>,Fail{error})
    case Done{_}:
      do IO<Result<&2,&2,Failure,Preferences>>:
        result : Result<&2,&2,Failure,Preferences> <- read_owned(db,False{})
        rollback(db,result)

def load(+db: U32) -> IO(Result<&2,&2,Failure,Preferences>):
  do IO<Result<&2,&2,Failure,Preferences>>:
    started : Result<&2,&2,Failure,Unit> <- begin(db,False{})
    load_started(started,db)

def commit_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,db: U32,
  preferences: Preferences) -> IO(Result<&2,&2,Failure,Preferences>):
  match result:
    case Done{_}: IO.pure(Result<&2,&2,Failure,Preferences>,Done{preferences})
    case Fail{(code,_)}: rollback(db,Fail{database("commit",code)})

def commit(+db: U32,preferences: Preferences) -> IO(Result<&2,&2,Failure,Preferences>):
  do IO<Result<&2,&2,Failure,Preferences>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"COMMIT",[],0)
    commit_result(result,db,preferences)

def matched(valid: Bool,db: U32,preferences: Preferences) -> IO(Result<&2,&2,Failure,Preferences>):
  match valid:
    case True{}: commit(db,preferences)
    case False{}: rollback(db,Fail{Failure{"preference_database_error","Refresh preference readback did not match the requested values; no update was committed"}})

def verified(result: Result<&2,&2,Failure,Preferences>,db: U32,+preferences: Preferences) ->
  IO(Result<&2,&2,Failure,Preferences>):
  match result:
    case Fail{error}: rollback(db,Fail{error})
    case Done{stored}: matched(same(stored,preferences),db,preferences)

def written(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,+db: U32,
  preferences: Preferences) -> IO(Result<&2,&2,Failure,Preferences>):
  match result:
    case Fail{(code,_)}: rollback(db,Fail{database("write",code)})
    case Done{_}:
      do IO<Result<&2,&2,Failure,Preferences>>:
        stored : Result<&2,&2,Failure,Preferences> <- read_owned(db,True{})
        verified(stored,db,preferences)

def write_owned(+db: U32,+preferences: Preferences) -> IO(Result<&2,&2,Failure,Preferences>):
  Preferences{enabled,interval} = preferences
  do IO<Result<&2,&2,Failure,Preferences>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,
      "INSERT INTO main.settings(key,value) VALUES(?,?),(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
      [Sql.Cell.Text{enabled_key()},Sql.Cell.Text{enabled_text(enabled)},
        Sql.Cell.Text{interval_key()},Sql.Cell.Text{U32.show(seconds(interval))}],0)
    written(result,db,preferences)

def save_validated(prior: Result<&2,&2,Failure,Preferences>,db: U32,preferences: Preferences) ->
  IO(Result<&2,&2,Failure,Preferences>):
  match prior:
    case Fail{error}: rollback(db,Fail{error})
    case Done{_}: write_owned(db,preferences)

def save_started(started: Result<&2,&2,Failure,Unit>,+db: U32,preferences: Preferences) ->
  IO(Result<&2,&2,Failure,Preferences>):
  match started:
    case Fail{error}: IO.pure(Result<&2,&2,Failure,Preferences>,Fail{error})
    case Done{_}:
      do IO<Result<&2,&2,Failure,Preferences>>:
        prior : Result<&2,&2,Failure,Preferences> <- read_owned(db,False{})
        save_validated(prior,db,preferences)

# Save is an explicit complete-pair update. Invalid retained state is an error,
# not permission to overwrite it. No defaults are persisted during load.
def save(+db: U32,preferences: Preferences) -> IO(Result<&2,&2,Failure,Preferences>):
  do IO<Result<&2,&2,Failure,Preferences>>:
    started : Result<&2,&2,Failure,Unit> <- begin(db,True{})
    save_started(started,db,preferences)
