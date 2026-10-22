import Base
import ../src/attachment_root_policy.bend as Policy
import ../src/attachment_root_rules.bend as Rules
import ../src/attachment_root_schema.bend as Schema
import ../src/attachment_root_path.bend as Path
import ../src/attachment_asset_types.bend as Types
import ../src/sql.bend as Sql
import ../src/store.bend as Store
import ../src/attachment_inventory.bend as Inventory

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def query(db: U32,statement: String,args: List<&2,Sql.Cell>,limit: U32) -> IO(Schema.rows()):
  IO.try(Schema.rows(),Sql.query(db,statement,args,limit))

def exec(db: U32,statement: String,args: List<&2,Sql.Cell>) -> IO(Unit):
  do IO<Unit>:
    rows : Schema.rows() <- query(db,statement,args,0)
    return Unit{}

def scalar(rows: Schema.rows()) -> String:
  match rows:
    case [Sql.Cell.Integer{value}] <> []: value
    case [Sql.Cell.Text{value}] <> []: value
    case _: "invalid scalar"

def count(db: U32,statement: String,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : Schema.rows() <- query(db,statement,[],1)
    check(String.eq(scalar(rows),wanted),label)

def done(-A: Data,value: Schema.result(A),label: String) -> IO(A):
  match value:
    case Done{actual}:
      do IO<A>:
        check(True{},label)
        return actual
    case Fail{error}: IO.die(A,1,"FAIL " ++ label)

def failure_code(value: Inventory.Failure) -> String:
  Inventory.Failure{code,_} = value
  code

def failed(-A: Data,value: Schema.result(A),expected: String,label: String) -> IO(Unit):
  match value:
    case Fail{error}:
      check(String.eq(failure_code(error),expected),label)
    case Done{_}: check(False{},label)

# Exact metadata stages observed on the two supported validation hosts:
# Darwin realpath refuses the missing final component; GNU realpath resolves
# its spelling and the following directory test refuses it. No generic error
# acceptance, and the actual typed code is retained in the test receipt.
def missing_code(+code: String,expected: String) -> IO(Unit):
  check(String.eq(code,expected),"nonexistent explicit directory refuses at exact platform metadata stage: " ++ code)

def missing_refusal(value: Schema.result(Types.RootEvidence),expected: String) -> IO(Unit):
  match value:
    case Fail{error}: missing_code(failure_code(error),expected)
    case Done{_}: check(False{},"nonexistent explicit directory must never become policy evidence")

def platform(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match value:
    case Done{(0,("Darwin\n",""))}: IO.pure(String,"attachment_root_path")
    case Done{(0,("Linux\n",""))}: IO.pure(String,"attachment_root_not_directory")
    case _: IO.die(String,1,"Unsupported or unreadable metadata-test platform")

def expect(value: Schema.result(Types.RootEvidence),wanted: Types.RootEvidence,label: String) -> IO(Unit):
  match value:
    case Done{actual}: check(Policy.same(actual,wanted),label)
    case Fail{_}: check(False{},label)

def init(+db: U32) -> IO(Unit):
  do IO<Unit>:
    result : Schema.result(Unit) <- Policy.initialize(db)
    done(Unit,result,"explicit policy initialization succeeds")

def enable(+db: U32,identity: Maybe<&2,String>,path: String,wanted: Types.RootEvidence,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Schema.result(Types.RootEvidence) <- Policy.enable(db,identity,path)
    expect(result,wanted,label)

def read(db: U32,identity: String,wanted: Types.RootEvidence,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Schema.result(Types.RootEvidence) <- Policy.read(db,identity)
    expect(result,wanted,label)

def validation(value: Schema.result(Unit),valid: Bool,label: String) -> IO(Unit):
  match valid:
    case True{}: done(Unit,value,label)
    case False{}: failed(Unit,value,"attachment_root_revoked",label)

def owned_validation(+db: U32,value: Types.RootEvidence,valid: Bool,label: String) -> IO(Unit):
  do IO<Unit>:
    exec(db,"BEGIN IMMEDIATE",[])
    exec(db,"INSERT INTO policy_fixture_assets(value) VALUES('pending')",[])
    result : Schema.result(Unit) <- Policy.validate_owned(db,value)
    validation(result,valid,label)
    exec(db,"INSERT INTO policy_fixture_assets(value) VALUES('still-owned')",[])
    count(db,"SELECT count(*) FROM policy_fixture_assets","2","validator leaves caller transaction and pending writes owned")
    exec(db,"ROLLBACK",[])
    count(db,"SELECT count(*) FROM policy_fixture_assets","0","caller rollback removes both writes after validator outcome")

def first_history(rows: Schema.rows(),expected: String) -> Bool:
  match rows:
    case [Sql.Cell.Text{path},Sql.Cell.Integer{"1"}] <> []: String.eq(path,expected)
    case _: False{}

def lifecycle_paths(+db: U32,+db_path: String,+a: String,+b: String,+c: String) -> IO(Unit):
  do IO<Unit>:
    absent : Schema.result(Types.RootEvidence) <- Policy.read(db,"1")
    failed(Types.RootEvidence,absent,"attachment_root_schema","ordinary read refuses absent policy schema")
    count(db,"SELECT count(*) FROM main.sqlite_master WHERE name LIKE 'attachment_root%'","0","ordinary read creates no policy tables")
    init(db)
    init(db)
    count(db,"SELECT count(*) FROM main.attachment_root_meta","1","initialization retry preserves one exact identity row")
    exec(db,"CREATE TABLE policy_fixture_assets(value TEXT NOT NULL)",[])
    enable(db,None{},a,Types.RootEvidence{"1",a,"1",True{}},"explicit Unicode directory enable creates stable root1 revision1")
    enable(db,None{},a,Types.RootEvidence{"1",a,"1",True{}},"same path enable retry is idempotent")
    count(db,"SELECT count(*) FROM main.attachment_root_revisions","1","idempotent enable never adds a revision")
    owned_validation(db,Types.RootEvidence{"1",a,"1",True{}},True{},"same-db current enabled evidence validates inside owned write transaction")
    +other : U32 <- IO.try(U32,Sql.open_existing(db_path,1))
    disabled : Schema.result(Types.RootEvidence) <- Policy.disable(other,"1")
    expect(disabled,Types.RootEvidence{"1",a,"2",False{}},"separate writer commits disable as a new revision")
    IO.try(Unit,Sql.close(other))
    owned_validation(db,Types.RootEvidence{"1",a,"1",True{}},False{},"disable committed before validation invalidates old evidence on same library")
    again : Schema.result(Types.RootEvidence) <- Policy.disable(db,"1")
    expect(again,Types.RootEvidence{"1",a,"2",False{}},"disable retry is idempotent")
    count(db,"SELECT count(*) FROM main.attachment_root_revisions","2","disable retry preserves immutable transition count")
    enable(db,Some{"1"},a,Types.RootEvidence{"1",a,"3",True{}},"re-enable retains identity and advances policy revision")
    owned_validation(db,Types.RootEvidence{"1",a,"1",True{}},False{},"re-enable never reauthorizes an old enabled revision")
    enable(db,None{},b,Types.RootEvidence{"2",b,"1",True{}},"second path allocates distinct root identity")
    conflict : Schema.result(Types.RootEvidence) <- Policy.enable(db,Some{"1"},b)
    failed(Types.RootEvidence,conflict,"attachment_root_conflict","explicit path change cannot steal another root path")
    read(db,"1",Types.RootEvidence{"1",a,"3",True{}},"conflicting change leaves original state unchanged")
    enable(db,Some{"1"},c,Types.RootEvidence{"1",c,"4",True{}},"explicit root path change appends revision4")
    owned_validation(db,Types.RootEvidence{"1",a,"3",True{}},False{},"changed path/revision invalidates prior root evidence")
    history : Schema.rows() <- query(db,"SELECT canonical_path,enabled FROM main.attachment_root_revisions WHERE root_id=1 AND revision=1",[],1)
    check(first_history(history,a),"later disable re-enable and path change preserve exact first history entry")
    count(db,"SELECT count(*) FROM main.attachment_root_revisions WHERE root_id=1","4","all four effective policy transitions remain recorded")

def ownership(+db: U32,+path: String) -> IO(Unit):
  do IO<Unit>:
    exec(db,"BEGIN IMMEDIATE",[])
    exec(db,"INSERT INTO policy_fixture_assets(value) VALUES('caller')",[])
    r : Schema.result(Types.RootEvidence) <- Policy.read(db,"1")
    failed(Types.RootEvidence,r,"attachment_root_transaction","public read refuses to steal a caller transaction")
    d : Schema.result(Types.RootEvidence) <- Policy.disable(db,"1")
    failed(Types.RootEvidence,d,"attachment_root_transaction","public disable leaves caller transaction untouched on failed BEGIN")
    e : Schema.result(Types.RootEvidence) <- Policy.enable(db,Some{"1"},path)
    failed(Types.RootEvidence,e,"attachment_root_transaction","public enable leaves caller transaction untouched on failed BEGIN")
    i : Schema.result(Unit) <- Policy.initialize(db)
    failed(Unit,i,"attachment_root_transaction","initialization cannot commit or rollback another caller's transaction")
    count(db,"SELECT count(*) FROM policy_fixture_assets","1","all failed public BEGINs preserve caller pending write")
    count(db,"SELECT count(*) FROM main.attachment_root_revisions WHERE root_id=1","4","failed public BEGINs never mutate root revision history")
    exec(db,"ROLLBACK",[])
    count(db,"SELECT count(*) FROM policy_fixture_assets","0","caller still owns rollback after public-operation refusal")
    owned_validation(db,Types.RootEvidence{"1",path,"4",True{}},True{},"current revision remains authorized after refused nested operations")

def exact_ids(+root: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/root-exact-ids.sqlite")
    init(db)
    exec(db,"INSERT INTO main.attachment_roots(id,canonical_path,current_revision,enabled) VALUES(9007199254740993,?,1,1)",[Sql.Cell.Text{root ++ "/root-b"}])
    exec(db,"INSERT INTO main.attachment_root_revisions(root_id,revision,canonical_path,enabled) VALUES(9007199254740993,1,?,1)",[Sql.Cell.Text{root ++ "/root-b"}])
    enable(db,None{},root ++ "/root-c",Types.RootEvidence{"9007199254740994",root ++ "/root-c","1",True{}},
      "new root allocation remains exact above double precision and native Nat")
    exec(db,"INSERT INTO main.attachment_roots(id,canonical_path,current_revision,enabled) VALUES(9223372036854775807,?,1,1)",[Sql.Cell.Text{root ++ "/synthetic-max-identity"}])
    exec(db,"INSERT INTO main.attachment_root_revisions(root_id,revision,canonical_path,enabled) VALUES(9223372036854775807,1,?,1)",[Sql.Cell.Text{root ++ "/synthetic-max-identity"}])
    exhausted : Schema.result(Types.RootEvidence) <- Policy.enable(db,None{},root ++ "/root café 中文")
    failed(Types.RootEvidence,exhausted,"attachment_root_exhausted","signed64 identity exhaustion refuses allocation without wrapping")
    count(db,"SELECT count(*) FROM main.attachment_roots","3","exhausted allocation leaves all root rows unchanged")
    count(db,"SELECT count(*) FROM main.attachment_root_revisions","3","exhausted allocation leaves all history rows unchanged")
    IO.try(Unit,Sql.close(db))

def different_database(+root: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/root-different-library.sqlite")
    init(db)
    exec(db,"CREATE TABLE policy_fixture_assets(value TEXT NOT NULL)",[])
    enable(db,None{},root ++ "/root-b",Types.RootEvidence{"1",root ++ "/root-b","1",True{}},"separate library has an independent root1")
    owned_validation(db,Types.RootEvidence{"1",root ++ "/root café 中文","1",True{}},False{},
      "same numeric root ID from another library cannot authorize different canonical path")
    IO.try(Unit,Sql.close(db))

def missing_and_invalid(+db: U32,+root: String,missing_expected: String) -> IO(Unit):
  do IO<Unit>:
    missing : Schema.result(Types.RootEvidence) <- Policy.read(db,"99")
    failed(Types.RootEvidence,missing,"attachment_root_missing","missing root never defaults to enabled")
    malformed : Schema.result(Types.RootEvidence) <- Policy.read(db,"01")
    failed(Types.RootEvidence,malformed,"attachment_root_request","noncanonical root identity refuses without SQL coercion")
    invalid_path : Schema.result(Types.RootEvidence) <- Policy.enable(db,None{},root ++ "/../outside")
    failed(Types.RootEvidence,invalid_path,"attachment_root_path","explicit enable refuses traversal spelling before canonicalization")
    nonexistent : Schema.result(Types.RootEvidence) <- Policy.enable(db,None{},root ++ "/does-not-exist")
    missing_refusal(nonexistent,missing_expected)
    not_directory : Schema.result(Types.RootEvidence) <- Policy.enable(db,None{},root ++ "/.build/root-policy.sqlite")
    failed(Types.RootEvidence,not_directory,"attachment_root_not_directory","regular database file cannot be enabled as a directory root")
    count(db,"SELECT count(*) FROM main.attachment_roots","2","all invalid enable requests preserve existing roots")

def malformed_schema(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    exec(db,"CREATE TEMP TABLE attachment_roots(id INTEGER,canonical_path TEXT,current_revision INTEGER,enabled INTEGER)",[])
    exec(db,"INSERT INTO temp.attachment_roots VALUES(1,'/synthetic/forged',999,1)",[])
    read(db,"1",Types.RootEvidence{"1",root ++ "/root-c","4",True{}},"temporary table cannot shadow authoritative main policy rows")
    exec(db,"CREATE INDEX main.unexpected_root_index ON attachment_roots(enabled)",[])
    extra : Schema.result(Types.RootEvidence) <- Policy.read(db,"1")
    failed(Types.RootEvidence,extra,"attachment_root_schema","unexpected owned-table index refuses schema validation")
    count(db,"SELECT count(*) FROM main.sqlite_master WHERE name='unexpected_root_index'","1","ordinary read does not repair unexpected schema")
    exec(db,"DROP INDEX main.unexpected_root_index",[])
    exec(db,"PRAGMA ignore_check_constraints=ON",[])
    exec(db,"UPDATE main.attachment_root_revisions SET revision=2.5 WHERE root_id=1 AND revision=2",[])
    exec(db,"PRAGMA ignore_check_constraints=OFF",[])
    fractional : Schema.result(Types.RootEvidence) <- Policy.read(db,"1")
    failed(Types.RootEvidence,fractional,"attachment_root_invalid","fractional middle revision cannot fake contiguous count min and max")
    count(db,"SELECT count(*) FROM main.attachment_root_revisions WHERE typeof(revision)='real'","1","malformed revision is refused without silent history repair")

def wrong_library() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(".build/root-wrong-library.sqlite"))
    value : Schema.result(Unit) <- Policy.initialize(db)
    failed(Unit,value,"attachment_root_library","policy initialization refuses an uninitialized or unsupported library")
    count(db,"SELECT count(*) FROM main.sqlite_master","0","unsupported library is left empty")
    exec(db,"PRAGMA user_version=3",[])
    forged : Schema.result(Unit) <- Policy.initialize(db)
    failed(Unit,forged,"attachment_root_library","schema version alone does not impersonate initialized library tables")
    IO.try(Unit,Sql.close(db))

def process_ok(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Bool:
  match value:
    case Done{(0,("",""))}: True{}
    case _: False{}

def fixture_path(value: Maybe<&2,String>) -> IO(String):
  match value:
    case None{}: IO.die(String,1,"Unable to identify isolated synthetic cwd")
    case Some{+root}:
      do IO<String>:
        check(String.contains(root,"juice-bend-test-"),"native test runs only in owned synthetic test working directory")
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run("/bin/mkdir",[root ++ "/root café 中文",root ++ "/root-b",root ++ "/root-c"],"",4096,2000)
        check(process_ok(result),"fresh synthetic directory fixtures created without content access")
        return root

def main() -> IO(Unit):
  do IO<Unit>:
    host : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/usr/bin/uname",["-s"],"",1024,2000)
    missing_expected : String <- platform(host)
    cwd : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/pwd",["-P"],"",8192,2000)
    +root : String <- fixture_path(Rules.resolved(cwd))
    +db : U32 <- Store.open(".build/root-policy.sqlite")
    lifecycle_paths(db,root ++ "/.build/root-policy.sqlite",root ++ "/root café 中文",root ++ "/root-b",root ++ "/root-c")
    ownership(db,root ++ "/root-c")
    missing_and_invalid(db,root,missing_expected)
    exact_ids(root)
    different_database(root)
    malformed_schema(db,root)
    IO.try(Unit,Sql.close(db))
    wrong_library()
