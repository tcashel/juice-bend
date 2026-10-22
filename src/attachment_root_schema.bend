import Base
import ./sql.bend as Sql
import ./attachment_inventory.bend as Inventory

def rows() -> Data: List<&2,List<&2,Sql.Cell>>
def result(-A: Data) -> Data: Result<&2,&2,Inventory.Failure,A>
def pure(-A: Data,value: result(A)) -> IO(result(A)): IO.pure(result(A),value)
def failure(code: String) -> Inventory.Failure:
  Inventory.Failure{code,"Attachment-root policy operation refused; no private path or SQLite values are included"}
def fail(-A: Data,code: String) -> IO(result(A)): pure(A,Fail{failure(code)})

def branch(-A: Type,valid: Bool,yes: Unit -> A,no: Unit -> A) -> A:
  match valid:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def queried(-A: Data,value: Result<&1,&1,U32 & String,rows()>,next: rows() -> IO(result(A))) -> IO(result(A)):
  match value:
    case Fail{_}: fail(A,"attachment_root_database")
    case Done{values}: next(values)

def query(-A: Data,db: U32,statement: String,args: List<&2,Sql.Cell>,limit: U32,next: rows() -> IO(result(A))) -> IO(result(A)):
  do IO<result(A)>:
    value : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,statement,args,limit)
    queried(A,value,next)

def rollback_done(-A: Data,value: Result<&1,&1,U32 & String,rows()>,prior: result(A)) -> IO(result(A)):
  match value:
    case Fail{_}: fail(A,"attachment_root_cleanup")
    case Done{_}: pure(A,prior)

def rollback(-A: Data,db: U32,prior: result(A)) -> IO(result(A)):
  do IO<result(A)>:
    value : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,"ROLLBACK",[],0)
    rollback_done(A,value,prior)

def committed(-A: Data,value: Result<&1,&1,U32 & String,rows()>,db: U32,prior: A) -> IO(result(A)):
  match value:
    case Fail{_}: rollback(A,db,Fail{failure("attachment_root_database")})
    case Done{_}: pure(A,Done{prior})

def finish(-A: Data,prior: result(A),+db: U32,write: Bool) -> IO(result(A)):
  match prior write:
    case Done{value} True{}:
      do IO<result(A)>:
        committed_value : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,"COMMIT",[],0)
        committed(A,committed_value,db,value)
    case other _: rollback(A,db,other)

def started(-A: Data,value: Result<&1,&1,U32 & String,rows()>,+db: U32,write: Bool,operation: U32 -> IO(result(A))) -> IO(result(A)):
  match value:
    case Fail{_}: fail(A,"attachment_root_transaction")
    case Done{_}:
      do IO<result(A)>:
        prior : result(A) <- operation(db)
        finish(A,prior,db,write)

# Failed BEGIN never commits or rolls back a pre-existing caller transaction.
def transaction(-A: Data,+db: U32,+write: Bool,operation: U32 -> IO(result(A))) -> IO(result(A)):
  do IO<result(A)>:
    value : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,Bool.pick(String,write,"BEGIN IMMEDIATE","BEGIN DEFERRED"),[],0)
    started(A,value,db,write,operation)

def meta_sql(prefix: String) -> String:
  "CREATE TABLE " ++ prefix ++ "attachment_root_meta(id INTEGER PRIMARY KEY CHECK(id=1),version INTEGER NOT NULL CHECK(version=1),profile TEXT NOT NULL CHECK(profile='explicit-attachment-roots-v1'))"
def roots_sql(prefix: String) -> String:
  "CREATE TABLE " ++ prefix ++ "attachment_roots(id INTEGER PRIMARY KEY CHECK(id>0),canonical_path TEXT NOT NULL UNIQUE,current_revision INTEGER NOT NULL CHECK(current_revision>0),enabled INTEGER NOT NULL CHECK(enabled IN(0,1)))"
def history_sql(prefix: String) -> String:
  "CREATE TABLE " ++ prefix ++ "attachment_root_revisions(root_id INTEGER NOT NULL REFERENCES attachment_roots(id),revision INTEGER NOT NULL CHECK(typeof(revision)='integer' AND revision>0),canonical_path TEXT NOT NULL,enabled INTEGER NOT NULL CHECK(enabled IN(0,1)),PRIMARY KEY(root_id,revision)) WITHOUT ROWID"

def object_query() -> String:
  "SELECT type,name,tbl_name,sql FROM main.sqlite_master WHERE name IN('attachment_root_meta','attachment_roots','attachment_root_revisions') OR tbl_name IN('attachment_root_meta','attachment_roots','attachment_root_revisions') ORDER BY name LIMIT 8"

def table_object(value: List<&2,Sql.Cell>,+expected: String,definition: String) -> Bool:
  match value:
    case [Sql.Cell.Text{kind},Sql.Cell.Text{name},Sql.Cell.Text{table},Sql.Cell.Text{sql}]:
      String.eq(kind,"table") && String.eq(name,expected) && String.eq(table,expected) && String.eq(sql,definition)
    case _: False{}

def index_object(value: List<&2,Sql.Cell>) -> Bool:
  match value:
    case [Sql.Cell.Text{kind},Sql.Cell.Text{name},Sql.Cell.Text{table},Sql.Cell.Null{}]:
      String.eq(kind,"index") && String.eq(name,"sqlite_autoindex_attachment_roots_1") && String.eq(table,"attachment_roots")
    case _: False{}

# Keep shape matching shallow: every field still has an exact type/name/value
# check without expanding all schema-name strings in one constructor pattern.
def objects(value: rows()) -> Bool:
  match value:
    case [meta,history,roots,index]:
      table_object(meta,"attachment_root_meta",meta_sql("")) &&
        table_object(history,"attachment_root_revisions",history_sql("")) &&
        table_object(roots,"attachment_roots",roots_sql("")) && index_object(index)
    case _: False{}

def metadata(value: rows()) -> Bool:
  match value:
    case [Sql.Cell.Integer{id},Sql.Cell.Integer{version},Sql.Cell.Text{profile}] <> []:
      String.eq(id,"1") && String.eq(version,"1") && String.eq(profile,"explicit-attachment-roots-v1")
    case _: False{}

def meta_checked(-A: Data,valid: Bool,next: Unit -> IO(result(A))) -> IO(result(A)):
  branch(IO(result(A)),valid,next,_ => fail(A,"attachment_root_schema"))

def checked_objects(-A: Data,valid: Bool,db: U32,next: Unit -> IO(result(A))) -> IO(result(A)):
  branch(IO(result(A)),valid,_ => query(A,db,"SELECT id,version,profile FROM main.attachment_root_meta LIMIT 2",[],2,
    value => meta_checked(A,metadata(value),next)),_ => fail(A,"attachment_root_schema"))

def version(value: rows()) -> Bool:
  match value:
    case [Sql.Cell.Integer{"3"}] <> []: True{}
    case _: False{}

def core_name(value: List<&2,Sql.Cell>,wanted: String) -> Bool:
  match value:
    case [Sql.Cell.Text{name}]: String.eq(name,wanted)
    case _: False{}

def core(value: rows()) -> Bool:
  match value:
    case [generations,raw,records,settings,snapshots,sources]:
      core_name(generations,"generations") && core_name(raw,"raw") &&
        core_name(records,"records") && core_name(settings,"settings") &&
        core_name(snapshots,"snapshots") && core_name(sources,"sources")
    case _: False{}

def core_checked(-A: Data,valid: Bool,+db: U32,next: Unit -> IO(result(A))) -> IO(result(A)):
  branch(IO(result(A)),valid,_ => query(A,db,
    "SELECT s.id,g.id,g.source,g.encoding,n.id,n.generation,n.accepted,r.id,r.bytes,i.snapshot,i.ordinal,i.raw,k.key,k.value FROM main.sources s,main.generations g,main.snapshots n,main.raw r,main.records i,main.settings k LIMIT 0",
    [],0,_ => next(Unit{})),_ => fail(A,"attachment_root_library"))

def library_version(-A: Data,valid: Bool,+db: U32,next: Unit -> IO(result(A))) -> IO(result(A)):
  branch(IO(result(A)),valid,_ => query(A,db,
    "SELECT name FROM main.sqlite_master WHERE type='table' AND name IN('sources','generations','snapshots','raw','records','settings') ORDER BY name LIMIT 7",[],7,
    value => core_checked(A,core(value),db,next)),_ => fail(A,"attachment_root_library"))

def library(-A: Data,+db: U32,next: Unit -> IO(result(A))) -> IO(result(A)):
  query(A,db,"PRAGMA main.user_version",[],1,value => library_version(A,version(value),db,next))

# Internal: caller already owns its transaction. No creation or repair.
def owned(-A: Data,+db: U32,next: Unit -> IO(result(A))) -> IO(result(A)):
  library(A,db,_ => query(A,db,object_query(),[],8,value => checked_objects(A,objects(value),db,next)))

def created(+db: U32) -> IO(result(Unit)):
  query(Unit,db,"INSERT INTO main.attachment_root_meta(id,version,profile) VALUES(1,1,'explicit-attachment-roots-v1')",[],0,
    _ => owned(Unit,db,_ => pure(Unit,Done{Unit{}})))

def create(+db: U32) -> IO(result(Unit)):
  query(Unit,db,meta_sql("main."),[],0,_ =>
    query(Unit,db,roots_sql("main."),[],0,_ =>
      query(Unit,db,history_sql("main."),[],0,_ => created(db))))

def initialize_rows(+value: rows(),+db: U32) -> IO(result(Unit)):
  match value:
    case []: create(db)
    case _:
      checked_objects(Unit,objects(value),db,_ => pure(Unit,Done{Unit{}}))

def initialize(db: U32) -> IO(result(Unit)):
  transaction(Unit,db,True{},+d => library(Unit,d,_ => query(Unit,d,object_query(),[],8,value => initialize_rows(value,d))))
