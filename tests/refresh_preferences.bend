import Base
import ../src/refresh_preferences.bend as Refresh
import ../src/sql.bend as Sql

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def query(db: U32,statement: String,bindings: List<&2,Sql.Cell>,limit: U32) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  IO.try(List<&2,List<&2,Sql.Cell>>,Sql.query(db,statement,bindings,limit))

def exec(db: U32,statement: String,bindings: List<&2,Sql.Cell>) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- query(db,statement,bindings,0)
    return Unit{}

def scalar(rows: List<&2,List<&2,Sql.Cell>>) -> String:
  match rows:
    case [Sql.Cell.Integer{value}] <> []: value
    case [Sql.Cell.Text{value}] <> []: value
    case _: "invalid scalar"

def check(db: U32,statement: String,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- query(db,statement,[],1)
    assert(String.eq(scalar(rows),expected),label)

def open(path: String) -> IO(U32):
  do IO<U32>:
    +db : U32 <- IO.try(U32,Sql.open(path))
    exec(db,"CREATE TABLE main.settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)",[])
    return db

def expect(result: Result<&2,&2,Refresh.Failure,Refresh.Preferences>,wanted: Refresh.Preferences,label: String) -> IO(Unit):
  match result:
    case Done{value}: assert(Refresh.same(value,wanted),label)
    case Fail{Refresh.Failure{code,message}}: IO.die(Unit,1,"FAIL " ++ label ++ ": " ++ code ++ " " ++ message)

def fail(result: Result<&2,&2,Refresh.Failure,Refresh.Preferences>,expected: String,label: String) -> IO(Unit):
  match result:
    case Fail{Refresh.Failure{code,message}}:
      assert(String.eq(code,expected) && Bool.not(String.is_empty(message)),label)
    case Done{_}: assert(False{},label)

def loaded(db: U32,wanted: Refresh.Preferences,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.load(db)
    expect(result,wanted,label)

def saved(db: U32,+wanted: Refresh.Preferences,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.save(db,wanted)
    expect(result,wanted,label)

def failed_load(db: U32,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.load(db)
    fail(result,code,label)

def failed_save(db: U32,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.save(db,Refresh.Preferences{False{},Refresh.Hours8{}})
    fail(result,code,label)

def failed_pair(db: U32,preferences: Refresh.Preferences,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.save(db,preferences)
    fail(result,"preference_database_error",label)

def put(db: U32,key: String,value: Sql.Cell) -> IO(Unit):
  exec(db,"INSERT INTO main.settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
    [Sql.Cell.Text{key},value])

def interval_case(result: Result<&2,&2,Refresh.Failure,Refresh.Preferences>,+text: String) -> IO(Unit):
  match result:
    case Done{Refresh.Preferences{enabled,interval}}:
      assert(enabled && String.eq(U32.show(Refresh.seconds(interval)),text),"closed interval round-trips " ++ text)
    case Fail{_}: assert(False{},"closed interval round-trips " ++ text)

def interval_cases(cases: List<&2,String>) -> IO(Unit):
  match cases:
    case []: IO.pure(Unit,Unit{})
    case +text <> rest:
      do IO<Unit>:
        interval_case(Refresh.parse("true",text),text)
        interval_cases(rest)

def rejected(cases: List<&2,String>) -> IO(Unit):
  match cases:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        fail(Refresh.parse("true",value),"invalid_preference","noncanonical or unsupported interval is refused")
        rejected(rest)

def pure() -> IO(Unit):
  do IO<Unit>:
    interval_cases(["30","7200","14400","28800","86400"])
    rejected(["","0","60","030"," 30","30 ","30.0","3e1","-30","+30","4294967296","86401"])
    fail(Refresh.parse("1","30"),"invalid_preference","numeric-looking enabled flag is not a boolean")
    fail(Refresh.parse("TRUE","30"),"invalid_preference","enabled flag is case-sensitive and closed")
    expect(Refresh.decode([]),Refresh.defaults(),"missing keys default to enabled and thirty seconds")
    expect(Refresh.decode([[Sql.Cell.Text{Refresh.enabled_key()},Sql.Cell.Text{"false"}]]),
      Refresh.Preferences{False{},Refresh.Live30{}},"missing interval defaults independently of a saved disabled flag")
    expect(Refresh.decode([[Sql.Cell.Text{Refresh.interval_key()},Sql.Cell.Text{"7200"}]]),
      Refresh.Preferences{True{},Refresh.Hours2{}},"missing enabled key defaults independently of a saved interval")
    fail(Refresh.decode([[Sql.Cell.Text{Refresh.enabled_key()},Sql.Cell.Integer{"1"}]]),
      "invalid_stored_preference","integer enabled cell is not coerced")
    fail(Refresh.decode([[Sql.Cell.Text{Refresh.interval_key()},Sql.Cell.Real{"30"}]]),
      "invalid_stored_preference","real interval cell is not coerced")
    fail(Refresh.decode([[Sql.Cell.Text{Refresh.interval_key()},Sql.Cell.Null{}]]),
      "invalid_stored_preference","NULL interval is not a missing key")
    fail(Refresh.decode([[Sql.Cell.Text{Refresh.enabled_key()},Sql.Cell.Blob{[116,114,117,101]}]]),
      "invalid_stored_preference","UTF8-looking BLOB enabled value is not TEXT")
    fail(Refresh.decode([[Sql.Cell.Text{Refresh.enabled_key()},Sql.Cell.Text{"true"}],
      [Sql.Cell.Text{Refresh.enabled_key()},Sql.Cell.Text{"false"}]]),
      "invalid_stored_preference","duplicate exact keys cannot choose an arbitrary winner")
    fail(Refresh.decode([[Sql.Cell.Text{"unrelated"},Sql.Cell.Text{"true"}]]),
      "invalid_stored_preference","unexpected query row is an explicit decoder error")
    fail(Refresh.decode([[Sql.Cell.Text{Refresh.enabled_key()}]]),
      "invalid_stored_preference","truncated query row is an explicit decoder error")

def deadline_value(result: Result<&2,&2,Refresh.Failure,Maybe<&2,Nat>>,expected: String,label: String) -> IO(Unit):
  match result:
    case Done{Some{value}}: assert(String.eq(Nat.show(value),expected),label)
    case _: assert(False{},label)

def deadline_overflow(result: Result<&2,&2,Refresh.Failure,Maybe<&2,Nat>>) -> IO(Unit):
  match result:
    case Fail{Refresh.Failure{code,_}}: assert(String.eq(code,"refresh_deadline_overflow"),"one millisecond beyond native cap refuses to arm")
    case _: assert(False{},"one millisecond beyond native cap refuses to arm")

def deadline_disabled(result: Result<&2,&2,Refresh.Failure,Maybe<&2,Nat>>) -> IO(Unit):
  match result:
    case Done{None{}}: assert(True{},"disabled preference has no armed deadline even at native cap")
    case _: assert(False{},"disabled preference has no armed deadline even at native cap")

def arithmetic() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(Nat.show(Refresh.native_limit()),"281474976710655"),"native scheduling cap matches pinned compiler 2^48-1")
    assert(String.eq(Nat.show(Refresh.milliseconds(Refresh.Daily{})),"86400000"),"daily interval converts exactly to milliseconds")
    deadline_value(Refresh.deadline(Refresh.defaults(),4294967295n),"4294997295","uptime above U32 is not truncated")
    deadline_value(Refresh.deadline(Refresh.Preferences{True{},Refresh.Daily{}},Nat.sub(Refresh.native_limit(),86400000n)),
      "281474976710655","deadline at native upper bound remains exact")
    deadline_overflow(Refresh.deadline(Refresh.Preferences{True{},Refresh.Daily{}},Nat.sub(Refresh.native_limit(),86399999n)))
    deadline_disabled(Refresh.deadline(Refresh.Preferences{False{},Refresh.Daily{}},Refresh.native_limit()))

def defaults_and_persistence() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- open(".build/refresh-persistence.sqlite")
    loaded(db,Refresh.defaults(),"empty owned settings load defaults")
    check(db,"SELECT total_changes()","0","default load makes no writes")
    check(db,"SELECT count(*) FROM main.settings","0","default load does not persist defaults")
    put(db,"source_root_cursor",Sql.Cell.Text{"0004"})
    put(db,"unrelated",Sql.Cell.Blob{[255,0,255]})
    saved(db,Refresh.Preferences{False{},Refresh.Hours4{}},"explicit pair save returns its committed values")
    check(db,"SELECT count(*) FROM main.settings","4","pair save writes only two owned keys")
    check(db,"SELECT value FROM main.settings WHERE key='source_root_cursor'","0004","save preserves the discovery cursor verbatim")
    check(db,"SELECT typeof(value) FROM main.settings WHERE key='unrelated'","blob","save leaves unrelated typed setting unchanged")
    IO.try(Unit,Sql.close(db))
    +again : U32 <- IO.try(U32,Sql.open(".build/refresh-persistence.sqlite"))
    loaded(again,Refresh.Preferences{False{},Refresh.Hours4{}},"disabled state and interval survive close and reopen")
    check(again,"SELECT total_changes()","0","reopened load is read-only")
    exec(again,"CREATE TEMP TABLE settings(key TEXT PRIMARY KEY,value TEXT)",[])
    exec(again,"INSERT INTO temp.settings VALUES('refresh.enabled','invalid')",[])
    loaded(again,Refresh.Preferences{False{},Refresh.Hours4{}},"temporary settings table cannot shadow main preferences")
    saved(again,Refresh.Preferences{True{},Refresh.Daily{}},"save addresses main settings despite temporary shadow")
    check(again,"SELECT value FROM temp.settings WHERE key='refresh.enabled'","invalid","temporary settings remain untouched")
    exec(again,"DROP TABLE temp.settings",[])
    IO.try(Unit,Sql.close(again))

def invalid_storage() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- open(":memory:")
    put(db,Refresh.enabled_key(),Sql.Cell.Text{"private invalid content"})
    failed_load(db,"invalid_stored_preference","invalid persisted enabled value is explicit")
    failed_save(db,"invalid_stored_preference","save never silently repairs an invalid enabled value")
    check(db,"SELECT value FROM main.settings WHERE key='refresh.enabled'","private invalid content","invalid stored enabled value remains unchanged")
    check(db,"SELECT count(*) FROM main.settings","1","failed validation does not write the other default key")
    put(db,Refresh.enabled_key(),Sql.Cell.Text{"false"})
    put(db,Refresh.interval_key(),Sql.Cell.Text{"60"})
    failed_load(db,"invalid_stored_preference","unsupported saved interval does not silently default")
    failed_save(db,"invalid_stored_preference","unsupported interval cannot be overwritten by ordinary save")
    put(db,Refresh.interval_key(),Sql.Cell.Blob{[51,48]})
    failed_load(db,"invalid_stored_preference","actual SQLite BLOB interval is not coerced to text")
    put(db,Refresh.interval_key(),Sql.Cell.Text{"30"})
    loaded(db,Refresh.Preferences{False{},Refresh.Live30{}},"read failure releases its owned transaction for the next valid operation")
    IO.try(Unit,Sql.close(db))
    +typed : U32 <- IO.try(U32,Sql.open(":memory:"))
    exec(typed,"CREATE TABLE main.settings(key,value)",[])
    exec(typed,"INSERT INTO main.settings VALUES('refresh.interval_seconds',30)",[])
    failed_load(typed,"invalid_stored_preference","integer interval in a malformed schema is not accepted")
    exec(typed,"UPDATE main.settings SET value=NULL",[])
    failed_load(typed,"invalid_stored_preference","NULL stored value in a malformed schema is explicit")
    exec(typed,"UPDATE main.settings SET value='30'",[])
    exec(typed,"INSERT INTO main.settings VALUES('refresh.interval_seconds','7200')",[])
    failed_load(typed,"invalid_stored_preference","actual duplicate stored keys fail bounded decoding")
    IO.try(Unit,Sql.close(typed))

def ownership() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- open(":memory:")
    exec(db,"BEGIN",[])
    put(db,"caller-uncommitted",Sql.Cell.Text{"preserve me"})
    failed_load(db,"preference_transaction_unavailable","load refuses an existing caller transaction")
    failed_save(db,"preference_transaction_unavailable","save refuses an existing caller transaction")
    check(db,"SELECT value FROM main.settings WHERE key='caller-uncommitted'","preserve me","refused calls preserve caller uncommitted changes")
    exec(db,"ROLLBACK",[])
    check(db,"SELECT count(*) FROM main.settings","0","caller still owns and can roll back its transaction")
    loaded(db,Refresh.defaults(),"refused nested operations leave connection reusable")
    IO.try(Unit,Sql.close(db))
    +missing : U32 <- IO.try(U32,Sql.open(":memory:"))
    failed_load(missing,"preference_database_error","missing schema is a database error rather than default preferences")
    failed_save(missing,"preference_database_error","save does not create missing schema")
    exec(missing,"BEGIN",[])
    exec(missing,"ROLLBACK",[])
    check(missing,"SELECT count(*) FROM sqlite_master","0","missing-schema errors leave no DDL or open transaction")
    IO.try(Unit,Sql.close(missing))

def write_failures() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- open(":memory:")
    saved(db,Refresh.defaults(),"write-failure fixture starts with valid preferences")
    exec(db,"PRAGMA query_only=ON",[])
    failed_save(db,"preference_transaction_unavailable","read-only connection refuses the write transaction before updates")
    exec(db,"PRAGMA query_only=OFF",[])
    loaded(db,Refresh.defaults(),"read-only write failure leaves preferences unchanged")
    exec(db,"CREATE TRIGGER refuse_interval BEFORE UPDATE ON settings WHEN NEW.key='refresh.interval_seconds' BEGIN SELECT RAISE(FAIL,'synthetic refusal'); END",[])
    failed_save(db,"preference_database_error","second-row failure is reported instead of partial success")
    loaded(db,Refresh.defaults(),"rollback restores first preference after SQLite FAIL preserves prior row work")
    exec(db,"DROP TRIGGER refuse_interval",[])
    exec(db,"CREATE TRIGGER ignore_interval BEFORE UPDATE ON settings WHEN NEW.key='refresh.interval_seconds' BEGIN SELECT RAISE(IGNORE); END",[])
    failed_save(db,"preference_database_error","readback detects silently ignored interval update")
    loaded(db,Refresh.defaults(),"readback mismatch rolls back the changed enabled flag")
    exec(db,"DROP TRIGGER ignore_interval",[])
    exec(db,"PRAGMA foreign_keys=ON",[])
    exec(db,"CREATE TABLE fixture_parent(id INTEGER PRIMARY KEY)",[])
    exec(db,"CREATE TABLE fixture_child(parent INTEGER REFERENCES fixture_parent(id) DEFERRABLE INITIALLY DEFERRED)",[])
    exec(db,"CREATE TRIGGER defer_failure AFTER UPDATE ON settings WHEN NEW.key='refresh.interval_seconds' BEGIN INSERT INTO fixture_child VALUES(99); END",[])
    failed_save(db,"preference_database_error","deferred commit failure is explicit")
    loaded(db,Refresh.defaults(),"failed commit is rolled back before connection reuse")
    check(db,"SELECT count(*) FROM fixture_child","0","commit-failure rollback also clears only the owned transaction's trigger effects")
    exec(db,"DROP TRIGGER defer_failure",[])
    saved(db,Refresh.Preferences{False{},Refresh.Hours2{}},"successful update follows failure without reopening")
    IO.try(Unit,Sql.close(db))

def contention() -> IO(Unit):
  do IO<Unit>:
    +a : U32 <- open(".build/refresh-lock.sqlite")
    +b : U32 <- IO.try(U32,Sql.open(".build/refresh-lock.sqlite"))
    exec(a,"BEGIN IMMEDIATE",[])
    failed_save(b,"preference_transaction_unavailable","competing writer is refused within the bridge busy bound")
    put(a,"caller-uncommitted",Sql.Cell.Text{"still mine"})
    exec(a,"ROLLBACK",[])
    saved(b,Refresh.Preferences{False{},Refresh.Hours8{}},"failed BEGIN never installs a rollback against the caller-owned lock")
    loaded(a,Refresh.Preferences{False{},Refresh.Hours8{}},"separate connection sees the committed preference pair")
    IO.try(Unit,Sql.close(b))
    IO.try(Unit,Sql.close(a))

def ignored_inserts() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- open(":memory:")
    exec(db,"CREATE TRIGGER ignore_all BEFORE INSERT ON settings BEGIN SELECT RAISE(IGNORE); END",[])
    failed_pair(db,Refresh.defaults(),"ignored default-pair insertion cannot report persisted success")
    check(db,"SELECT count(*) FROM main.settings","0","failed complete-pair readback leaves no keys committed")
    exec(db,"DROP TRIGGER ignore_all",[])
    put(db,Refresh.interval_key(),Sql.Cell.Text{"7200"})
    exec(db,"CREATE TRIGGER ignore_enabled BEFORE INSERT ON settings WHEN NEW.key='refresh.enabled' BEGIN SELECT RAISE(IGNORE); END",[])
    failed_pair(db,Refresh.Preferences{True{},Refresh.Hours4{}},"missing default-valued enabled key cannot be masked by load defaulting")
    loaded(db,Refresh.Preferences{True{},Refresh.Hours2{}},"missing-enabled readback failure rolls back the interval update")
    check(db,"SELECT count(*) FROM main.settings","1","missing-enabled rollback retains the original partial key set")
    exec(db,"DROP TRIGGER ignore_enabled",[])
    exec(db,"DELETE FROM main.settings",[])
    put(db,Refresh.enabled_key(),Sql.Cell.Text{"false"})
    exec(db,"CREATE TRIGGER ignore_interval_insert BEFORE INSERT ON settings WHEN NEW.key='refresh.interval_seconds' BEGIN SELECT RAISE(IGNORE); END",[])
    failed_pair(db,Refresh.Preferences{True{},Refresh.Live30{}},"missing default-valued interval cannot be masked by load defaulting")
    loaded(db,Refresh.Preferences{False{},Refresh.Live30{}},"missing-interval readback failure rolls back the enabled update")
    check(db,"SELECT count(*) FROM main.settings","1","missing-interval rollback retains the original partial key set")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    arithmetic()
    defaults_and_persistence()
    invalid_storage()
    ownership()
    write_failures()
    contention()
    ignored_inserts()
