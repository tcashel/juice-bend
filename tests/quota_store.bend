import Base
import ../src/quota_store.bend as S
import ../src/claude_quota.bend as Q
import ../src/sql.bend as Sql

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def query(db: U32,text: String,args: List<&2,Sql.Cell>,limit: U32) -> IO(S.rows_type()):
  IO.try(S.rows_type(),Sql.query(db,text,args,limit))

def exec(db: U32,text: String) -> IO(Unit):
  do IO<Unit>:
    rows : S.rows_type() <- query(db,text,[],0)
    return Unit{}

def scalar(rows: S.rows_type()) -> String:
  match rows:
    case [Sql.Cell.Integer{actual}] <> []: actual
    case [Sql.Cell.Text{actual}] <> []: actual
    case _: "invalid scalar"

def check(db: U32,text: String,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : S.rows_type() <- query(db,text,[],1)
    assert(String.eq(scalar(rows),wanted),label)

def need(result: S.answer_type()) -> IO(S.View):
  match result:
    case Done{view}: IO.pure(S.View,view)
    case Fail{Q.Failure{code,message}}: IO.die(S.View,1,code ++ ": " ++ message)

def outcome(result: S.answer_type(),expected: String,epoch: Nat,enabled: Bool,label: String) -> IO(Unit):
  match result:
    case Done{S.View{actual,_,_,value}}:
      assert(S.state_same(actual,S.State{epoch,enabled}) && String.eq(value,expected),label)
    case Fail{Q.Failure{code,message}}: IO.die(Unit,1,"FAIL " ++ label ++ " " ++ code ++ " " ++ message)

def failure(result: S.answer_type(),wanted: String,label: String) -> IO(Unit):
  match result:
    case Fail{Q.Failure{code,+message}}:
      assert(String.eq(code,wanted) && Bool.not(String.is_empty(message)) &&
        Bool.not(String.contains(message,"private sentinel")),label)
    case Done{_}: assert(False{},label)

def fresh() -> IO(U32):
  do IO<U32>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    made : S.answer_type() <- S.initialize(db)
    outcome(made,"initialized",0n,False{},"explicit empty quota database initializes disabled")
    return db

def active(db: U32,epoch: Nat) -> IO(Unit):
  do IO<Unit>:
    result : S.answer_type() <- S.enable(db)
    outcome(result,"enabled",epoch,True{},"explicit enable allocates expected epoch")

def observation(value: U32) -> Q.Observation:
  Q.Observation{Some{Q.QuotaWindow{Some{value},Some{Nat.add(4294967295n,1n)}}},None{}}

def save(db: U32,+epoch: Nat,receipt: Nat,value: U32) -> IO(Unit):
  do IO<Unit>:
    result : S.answer_type() <- S.record(db,epoch,receipt,observation(value))
    outcome(result,"accepted",epoch,True{},"allowlisted observation commits under current epoch")

def latest(result: S.answer_type(),sequence: Nat,epoch: Nat,receipt: Nat,wanted: Q.Observation,label: String) -> IO(Unit):
  match result:
    case Done{S.View{_,[S.Sample{a,b,c,value}],False{},_}}:
      assert(Nat.is_eq(a,sequence) && Nat.is_eq(b,epoch) && Nat.is_eq(c,receipt) && Q.same(value,wanted),label)
    case _: assert(False{},label)

def exact_nat(value: Maybe<&2,Nat>,expected: Nat) -> Bool:
  match value:
    case Some{value}: Nat.is_eq(value,expected)
    case None{}: False{}

def empty_status(result: S.answer_type()) -> Bool:
  match result:
    case Done{S.View{S.State{2n,True{}},[],False{},"status"}}: True{}
    case _: False{}

def page_shape(result: S.answer_type(),count: Nat,more: Bool) -> Bool:
  match result:
    case Done{S.View{_,rows,actual,"history"}}:
      Nat.is_eq(List.length(&2,S.Sample,rows),count) && U32.is_eq(Bool.to_u32(actual),Bool.to_u32(more))
    case _: False{}

def numeric() -> IO(Unit):
  do IO<Unit>:
    assert(exact_nat(S.natural("281474976710655",S.cap()),S.cap()),"native48 boundary decodes exactly")
    assert(Maybe.is_none(&2,Nat,S.natural("281474976710656",S.cap())),"native48 boundary plus one refuses before multiplication")
    assert(Maybe.is_none(&2,Nat,S.natural("999999999999999999999999999999",S.cap())),"long SQLite decimal refuses without overflowing Nat")
    assert(Maybe.is_none(&2,Nat,S.natural("01",S.cap())),"noncanonical integer is refused")
    assert(Maybe.is_none(&2,Nat,S.integer(Sql.Cell.Real{"1"},S.cap())),"REAL is never silently narrowed to integer")
    assert(Maybe.is_none(&2,S.State,S.state([[Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"}]])),"enabled epoch zero is invalid")
    assert(Maybe.is_none(&2,S.Sample,S.sample([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Text{S.policy()},Sql.Cell.Integer{"0"}])),"absent window cannot hide a numeric zero")
    assert(Maybe.is_none(&2,S.Sample,S.sample([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Text{S.policy()},Sql.Cell.Text{"0"}])),"slot TEXT is rejected even when it looks numeric")
    assert(Maybe.is_none(&2,S.Sample,S.sample([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Integer{"0"},Sql.Cell.Null{},Sql.Cell.Null{},Sql.Cell.Text{S.policy()},Sql.Cell.Integer{"1"}])),"slot inconsistent with receipt time is rejected")

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- fresh()
    before : S.rows_type() <- query(db,"SELECT total_changes()",[],1)
    status : S.answer_type() <- S.status(db)
    outcome(status,"status",0n,False{},"new status remains disabled with no account inference")
    after : S.rows_type() <- query(db,"SELECT total_changes()",[],1)
    assert(String.eq(scalar(before),scalar(after)),"status performs no writes")
    rejected : S.answer_type() <- S.record(db,1n,1000n,observation(0))
    failure(rejected,"quota_epoch_retired","passive callback cannot enable collection")
    active(db,1n)
    save(db,1n,1000n,0)
    status : S.answer_type() <- S.status(db)
    latest(status,1n,1n,1000n,observation(0),"known zero and reset beyond U32 survive exact storage")
    waiting : S.answer_type() <- S.record(db,1n,1001n,Q.Observation{Some{Q.QuotaWindow{None{},None{}}},None{}})
    outcome(waiting,"waiting",1n,True{},"unknown-only feed waits without inventing zero")
    status : S.answer_type() <- S.status(db)
    latest(status,1n,1n,1000n,observation(0),"empty feed does not overwrite prior sample or its receipt")
    save(db,1n,1002n,12345678)
    check(db,"SELECT count(*) FROM main.quota_samples","1","same five-minute slot coalesces")
    status : S.answer_type() <- S.status(db)
    latest(status,2n,1n,1002n,observation(12345678),"coalesced sample gets a new arrival sequence")
    save(db,1n,600n,100000000)
    status : S.answer_type() <- S.status(db)
    latest(status,3n,1n,600n,observation(100000000),"backward wall clock never reorders local arrival sequence")
    result : S.answer_type() <- S.disconnect(db)
    outcome(result,"disconnected",1n,False{},"disconnect retires epoch transactionally")
    late : S.answer_type() <- S.record(db,1n,1200n,observation(9))
    failure(late,"quota_epoch_retired","delayed callback rejected after disconnect")
    active(db,2n)
    old : S.answer_type() <- S.record(db,1n,1200n,observation(9))
    failure(old,"quota_epoch_retired","reenable never revives old callback epoch")
    status : S.answer_type() <- S.status(db)
    assert(empty_status(status),"new connection has unknown current quota instead of prior epoch sample")
    save(db,2n,1200n,1)
    check(db,"SELECT count(*) FROM main.quota_samples","3","retained old epochs are history only")
    check(db,"SELECT count(*) FROM main.sqlite_master WHERE name IN('snapshots','raw_records','events','sessions')","0","quota storage owns no capture/session schema")
    IO.try(Unit,Sql.close(db))

def rollback_cases() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- fresh()
    exec(db,"CREATE TRIGGER ignore_enable BEFORE UPDATE ON main.quota_state BEGIN SELECT RAISE(IGNORE); END")
    result : S.answer_type() <- S.enable(db)
    failure(result,"quota_database_error","ignored enable cannot claim enabled success")
    check(db,"SELECT enabled FROM main.quota_state","0","failed enable leaves stored preference disabled")
    exec(db,"DROP TRIGGER main.ignore_enable")
    active(db,1n)
    exec(db,"CREATE TRIGGER ignore_disable BEFORE UPDATE ON main.quota_state BEGIN SELECT RAISE(IGNORE); END")
    result : S.answer_type() <- S.disconnect(db)
    failure(result,"quota_database_error","ignored disconnect cannot claim collection is off")
    check(db,"SELECT enabled FROM main.quota_state","1","failed disconnect preserves actual enabled state")
    exec(db,"DROP TRIGGER main.ignore_disable")
    save(db,1n,1000n,5)
    exec(db,"CREATE TRIGGER ignore_sample BEFORE INSERT ON main.quota_samples BEGIN SELECT RAISE(IGNORE); END")
    result : S.answer_type() <- S.record(db,1n,1001n,observation(6))
    failure(result,"quota_database_error","ignored insert cannot claim accepted observation")
    status : S.answer_type() <- S.status(db)
    latest(status,1n,1n,1000n,observation(5),"ignored insert rolls back coalesced-slot deletion")
    exec(db,"DROP TRIGGER main.ignore_sample")
    exec(db,"CREATE TRIGGER fail_sample BEFORE INSERT ON main.quota_samples BEGIN SELECT RAISE(ABORT,'private sentinel'); END")
    result : S.answer_type() <- S.record(db,1n,1001n,observation(6))
    failure(result,"quota_database_error","SQLite failure diagnostics never echo trigger/source content")
    status : S.answer_type() <- S.status(db)
    latest(status,1n,1n,1000n,observation(5),"insert failure rolls back deletion and preserves prior receipt")
    exec(db,"DROP TRIGGER main.fail_sample")
    exec(db,"BEGIN IMMEDIATE")
    exec(db,"UPDATE main.quota_state SET epoch=7")
    blocked : S.answer_type() <- S.disconnect(db)
    failure(blocked,"quota_transaction_unavailable","failed BEGIN leaves caller transaction untouched")
    check(db,"SELECT epoch FROM main.quota_state","7","caller uncommitted state still visible after failed BEGIN")
    exec(db,"ROLLBACK")
    check(db,"SELECT epoch FROM main.quota_state","1","caller can still roll back its own transaction")
    IO.try(Unit,Sql.close(db))

def schema_cases() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    exec(db,"CREATE TABLE private_table(value TEXT)")
    exec(db,"INSERT INTO private_table VALUES('private sentinel')")
    rejected : S.answer_type() <- S.initialize(db)
    failure(rejected,"quota_not_empty","existing arbitrary database is not adopted or migrated")
    check(db,"SELECT value FROM private_table","private sentinel","refused database remains unchanged")
    IO.try(Unit,Sql.close(db))
    +bad : U32 <- fresh()
    exec(bad,"PRAGMA main.application_id=0")
    rejected : S.answer_type() <- S.enable(bad)
    failure(rejected,"quota_storage_invalid","wrong database application identity refuses write")
    IO.try(Unit,Sql.close(bad))
    +typed : U32 <- IO.try(U32,Sql.open(":memory:"))
    exec(typed,"PRAGMA main.application_id=1245860180")
    exec(typed,"CREATE TABLE quota_state(id,version,epoch,enabled)")
    exec(typed,"INSERT INTO quota_state VALUES(1,1,'1',1)")
    rejected : S.answer_type() <- S.status(typed)
    failure(rejected,"quota_storage_invalid","TEXT epoch in malformed schema is not integer")
    exec(typed,"UPDATE quota_state SET epoch=281474976710656")
    rejected : S.answer_type() <- S.status(typed)
    failure(rejected,"quota_storage_invalid","SQLite integer above native48 cap is refused")
    exec(typed,"UPDATE quota_state SET epoch=1")
    exec(typed,"INSERT INTO quota_state VALUES(1,1,1,1)")
    rejected : S.answer_type() <- S.status(typed)
    failure(rejected,"quota_storage_invalid","duplicate state rows refuse ambiguous ownership")
    IO.try(Unit,Sql.close(typed))

def contention() -> IO(Unit):
  do IO<Unit>:
    +a : U32 <- IO.try(U32,Sql.open(".build/quota-lock.sqlite"))
    result : S.answer_type() <- S.initialize(a)
    view : S.View <- need(result)
    active(a,1n)
    +b : U32 <- IO.try(U32,Sql.open(".build/quota-lock.sqlite"))
    save(a,1n,1000n,1)
    exec(a,"BEGIN IMMEDIATE")
    exec(a,"UPDATE main.quota_state SET enabled=0 WHERE id=1")
    blocked : S.answer_type() <- S.record(b,1n,1001n,observation(2))
    failure(blocked,"quota_transaction_unavailable","receiver cannot cross another connection's retirement write lock")
    exec(a,"COMMIT")
    retired : S.answer_type() <- S.record(b,1n,1001n,observation(2))
    failure(retired,"quota_epoch_retired","after retirement commit competing receiver observes disabled epoch")
    active(a,2n)
    retired : S.answer_type() <- S.record(b,1n,1001n,observation(2))
    failure(retired,"quota_epoch_retired","other connection cannot revive old epoch after reenable")
    save(b,2n,1001n,2)
    check(a,"SELECT count(*) FROM main.quota_samples","2","cross-connection accepted sample does not overwrite old epoch history")
    IO.try(Unit,Sql.close(b))
    IO.try(Unit,Sql.close(a))

def exhausted() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- fresh()
    active(db,1n)
    save(db,1n,1000n,1)
    exec(db,"UPDATE main.sqlite_sequence SET seq=281474976710655 WHERE name='quota_samples'")
    result : S.answer_type() <- S.record(db,1n,1001n,observation(2))
    failure(result,"quota_database_error","sequence overflow fails without narrowing native48 identity")
    status : S.answer_type() <- S.status(db)
    latest(status,1n,1n,1000n,observation(1),"sequence exhaustion rolls back old-slot deletion")
    exec(db,"UPDATE main.quota_state SET epoch=281474976710655")
    result : S.answer_type() <- S.enable(db)
    failure(result,"quota_epoch_exhausted","connection epoch overflow refuses before Nat increment")
    check(db,"SELECT epoch FROM main.quota_state","281474976710655","epoch at upper bound stays exact after refused enable")
    IO.try(Unit,Sql.close(db))

def limits() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- fresh()
    active(db,1n)
    save(db,1n,300n,1)
    save(db,1n,7776300n,2)
    check(db,"SELECT count(*) FROM main.quota_samples","2","exact ninety-day retention boundary remains")
    save(db,1n,7776600n,3)
    check(db,"SELECT count(*) FROM main.quota_samples","2","older-than-ninety-day sample is pruned")
    exec(db,"DELETE FROM main.quota_samples")
    active(db,2n)
    # Synthetic SQL fixture generation only; application policy remains Bend.
    exec(db,"WITH RECURSIVE n(x) AS (VALUES(1) UNION ALL SELECT x+1 FROM n WHERE x<32768) INSERT INTO main.quota_samples(epoch,received_at,slot,five_present,five_used,seven_present,policy) SELECT CASE WHEN x<=16384 THEN 1 ELSE 2 END,5000100+300*((x-1)%16384),16667+((x-1)%16384),1,0,0,'claude-statusline-v1' FROM n")
    save(db,2n,10000000n,4)
    check(db,"SELECT count(*) FROM main.quota_samples","32768","hard retention ceiling applies across accepted arrivals")
    page : S.answer_type() <- S.history(db,0)
    assert(page_shape(page,40n,True{}),"history returns forty rows plus explicit lookahead flag")
    page : S.answer_type() <- S.history(db,32760)
    assert(page_shape(page,8n,False{}),"last bounded history page has exact remainder")
    page : S.answer_type() <- S.history(db,32769)
    failure(page,"quota_page_invalid","history offset ceiling refuses unbounded scan request")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    numeric()
    lifecycle()
    rollback_cases()
    schema_cases()
    contention()
    exhausted()
    limits()
