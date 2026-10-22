import Base
import ./attachment_asset_types.bend as T
import ./attachment_inventory.bend as Inventory
import ./archive_meta.bend as Meta
import ./domain.bend as Domain
import ./sql.bend as Sql

# These three tables belong only to this additive module. Initialization never
# changes the library version and ordinary reads never create or repair them.
def meta_sql() -> String:
  "CREATE TABLE attachment_asset_meta(id INTEGER PRIMARY KEY CHECK(id=1),version INTEGER NOT NULL CHECK(version=1),profile TEXT NOT NULL,chunk_bytes INTEGER NOT NULL,max_bytes INTEGER NOT NULL,schema_sha256 TEXT NOT NULL)"

def assets_sql() -> String:
  "CREATE TABLE attachment_assets(snapshot INTEGER NOT NULL,record INTEGER NOT NULL,reference INTEGER NOT NULL CHECK(reference>=0 AND reference<64),json_path TEXT NOT NULL,identity TEXT NOT NULL,root_id TEXT NOT NULL,root_path TEXT NOT NULL,root_revision TEXT NOT NULL,observed_at_ms TEXT NOT NULL,byte_count INTEGER NOT NULL CHECK(byte_count>=0 AND byte_count<=1048576),chunk_count INTEGER NOT NULL CHECK(chunk_count>=0 AND chunk_count<=16),sha256 TEXT NOT NULL,commitment TEXT NOT NULL,PRIMARY KEY(snapshot,record,reference),FOREIGN KEY(snapshot,record) REFERENCES records(snapshot,ordinal)) WITHOUT ROWID"

def chunks_sql() -> String:
  "CREATE TABLE attachment_asset_chunks(snapshot INTEGER NOT NULL,record INTEGER NOT NULL,reference INTEGER NOT NULL,ordinal INTEGER NOT NULL CHECK(ordinal>=0 AND ordinal<16),offset INTEGER NOT NULL CHECK(offset>=0 AND offset<1048576),n INTEGER NOT NULL CHECK(n>0 AND n<=65536),sha256 TEXT NOT NULL,bytes BLOB NOT NULL,PRIMARY KEY(snapshot,record,reference,ordinal),FOREIGN KEY(snapshot,record,reference) REFERENCES attachment_assets(snapshot,record,reference)) WITHOUT ROWID"

def schema_digest() -> String:
  Domain.hash_finish(Meta.hash_fields(["attachment-asset-schema-v1",meta_sql(),assets_sql(),chunks_sql()],Meta.initial_hash()))

def rows() -> Data: List<&2,List<&2,Sql.Cell>>
def pure(value: T.unit_result()) -> IO(T.unit_result()): IO.pure(T.unit_result(),value)
def invalid() -> T.unit_result(): Fail{T.failure("attachment_asset_schema_invalid","Owned attachment schema or identity metadata is incompatible")}
def database() -> T.unit_result(): Fail{T.failure("attachment_asset_database_error","Owned attachment storage operation failed")}

def branch(-A: Type,condition: Bool,yes: Unit -> A,no: Unit -> A) -> A:
  match condition:
    case True{}: yes(Unit{})
    case False{}: no(Unit{})

def queried(result: Result<&1,&1,U32 & String,rows()>,next: rows() -> IO(T.unit_result())) -> IO(T.unit_result()):
  match result:
    case Fail{_}: pure(database())
    case Done{values}: next(values)

def query(db: U32,sql: String,args: List<&2,Sql.Cell>,limit: U32,next: rows() -> IO(T.unit_result())) -> IO(T.unit_result()):
  do IO<T.unit_result()>:
    result : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,sql,args,limit)
    queried(result,next)

def identity_rows(value: rows()) -> IO(T.unit_result()):
  match value:
    case [[Sql.Cell.Integer{"1"},Sql.Cell.Integer{"1"}]]: pure(Done{Unit{}})
    case _: pure(invalid())

def identity(db: U32) -> IO(T.unit_result()):
  query(db,"SELECT count(*),coalesce(sum(CASE WHEN typeof(id)='integer' AND id=1 AND typeof(version)='integer' AND version=1 AND typeof(profile)='text' AND profile=? AND typeof(chunk_bytes)='integer' AND chunk_bytes=65536 AND typeof(max_bytes)='integer' AND max_bytes=1048576 AND typeof(schema_sha256)='text' AND schema_sha256=? THEN 1 ELSE 0 END),0) FROM main.attachment_asset_meta",
    [Sql.Cell.Text{T.profile()},Sql.Cell.Text{schema_digest()}],1,v => identity_rows(v))

def object_row(value: List<&2,Sql.Cell>,+wanted: String,ddl: String) -> Bool:
  match value:
    case [Sql.Cell.Text{kind},Sql.Cell.Text{name},Sql.Cell.Text{table},Sql.Cell.Text{actual}]:
      String.eq(kind,"table") && String.eq(name,wanted) && String.eq(table,wanted) && String.eq(actual,ddl)
    case _: False{}

def shape(value: rows()) -> Bool:
  match value:
    case [chunks,meta,assets]:
      object_row(chunks,"attachment_asset_chunks",chunks_sql()) &&
        object_row(meta,"attachment_asset_meta",meta_sql()) && object_row(assets,"attachment_assets",assets_sql())
    case _: False{}

def existing(value: rows(),db: U32) -> IO(T.unit_result()):
  branch(IO(T.unit_result()),shape(value),_ => identity(db),_ => pure(invalid()))

def objects(+db: U32,next: rows() -> IO(T.unit_result())) -> IO(T.unit_result()):
  query(db,"SELECT type,CASE WHEN length(CAST(name AS BLOB))<=128 THEN name ELSE NULL END,CASE WHEN length(CAST(tbl_name AS BLOB))<=128 THEN tbl_name ELSE NULL END,CASE WHEN typeof(sql)='text' AND length(CAST(sql AS BLOB))<=8192 THEN sql ELSE NULL END FROM main.sqlite_master WHERE name LIKE 'attachment_asset%' OR tbl_name IN('attachment_asset_chunks','attachment_asset_meta','attachment_assets') ORDER BY name LIMIT 5",[],5,next)

def library_tables(+db: U32,next: U32 -> IO(T.unit_result())) -> IO(T.unit_result()):
  query(db,"SELECT s.id,s.generation,s.extent,s.checkpoint,s.checkpoint_ordinal,s.records,s.accepted,r.snapshot,r.ordinal,r.raw,b.id,b.generation,b.ordinal,b.offset,b.n,b.digest,b.bytes,b.complete,b.oversized,g.source,p.provider,p.locator FROM main.snapshots s JOIN main.records r ON r.snapshot=s.id JOIN main.raw b ON b.id=r.raw JOIN main.generations g ON g.id=s.generation JOIN main.sources p ON p.id=g.source LIMIT 0",[],0,_ => next(db))

def foreign_keys(value: rows(),db: U32,next: U32 -> IO(T.unit_result())) -> IO(T.unit_result()):
  match value:
    case [[Sql.Cell.Integer{"1"}]]: library_tables(db,next)
    case _: pure(invalid())

def library_version(value: rows(),+db: U32,next: U32 -> IO(T.unit_result())) -> IO(T.unit_result()):
  match value:
    case [[Sql.Cell.Integer{"2"}]]: query(db,"PRAGMA foreign_keys",[],1,v => foreign_keys(v,db,next))
    case [[Sql.Cell.Integer{"3"}]]: query(db,"PRAGMA foreign_keys",[],1,v => foreign_keys(v,db,next))
    case _: pure(invalid())

def library(+db: U32,next: U32 -> IO(T.unit_result())) -> IO(T.unit_result()):
  query(db,"PRAGMA main.user_version",[],1,v => library_version(v,db,next))

# Precondition: caller owns the transaction. These internal operations never
# begin/end it; the public store API establishes and cleans up its own scope.
def validate_owned(db: U32) -> IO(T.unit_result()):
  library(db,+d => objects(d,v => existing(v,d)))

def insert_meta(+db: U32) -> IO(T.unit_result()):
  query(db,"INSERT INTO main.attachment_asset_meta(id,version,profile,chunk_bytes,max_bytes,schema_sha256) VALUES(1,1,?,65536,1048576,?)",
    [Sql.Cell.Text{T.profile()},Sql.Cell.Text{schema_digest()}],0,_ => validate_owned(db))

def create_chunks(+db: U32) -> IO(T.unit_result()):
  query(db,chunks_sql(),[],0,_ => insert_meta(db))

def create_assets(+db: U32) -> IO(T.unit_result()):
  query(db,assets_sql(),[],0,_ => create_chunks(db))

def create(+db: U32) -> IO(T.unit_result()):
  query(db,meta_sql(),[],0,_ => create_assets(db))

def initialize_objects(value: rows(),db: U32) -> IO(T.unit_result()):
  match value:
    case []: create(db)
    case other: existing(other,db)

def initialize_owned(db: U32) -> IO(T.unit_result()):
  library(db,+d => objects(d,v => initialize_objects(v,d)))
