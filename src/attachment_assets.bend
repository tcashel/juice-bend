import Base
import ./attachment_asset_identity.bend as Identity
import ./attachment_asset_types.bend as T
import ./attachment_asset_schema.bend as Schema
import ./attachment_inventory.bend as Inventory
import ./archive_meta.bend as Meta
import ./domain.bend as Domain
import ./sql.bend as Sql
import ./store.bend as Store
import ./paths.bend as Paths
import ./maintenance.bend as Maintenance

def rows() -> Data: List<&2,List<&2,Sql.Cell>>
def pure(value: T.answer()) -> IO(T.answer()): IO.pure(T.answer(),value)
def fail(code: String,message: String) -> T.answer(): Fail{T.failure(code,message)}
def invalid() -> T.answer(): fail("attachment_asset_invalid","Owned attachment metadata or bytes failed integrity validation")
def database() -> T.answer(): fail("attachment_asset_database_error","Owned attachment storage operation failed")
def missing() -> T.answer(): fail("attachment_asset_not_captured","External bytes have not been captured for this exact retained occurrence")

def queried(result: Result<&1,&1,U32 & String,rows()>,next: rows() -> IO(T.answer())) -> IO(T.answer()):
  match result:
    case Fail{_}: pure(database())
    case Done{values}: next(values)

def query(db: U32,sql: String,args: List<&2,Sql.Cell>,limit: U32,next: rows() -> IO(T.answer())) -> IO(T.answer()):
  do IO<T.answer()>:
    result : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,sql,args,limit)
    queried(result,next)

def cleaned(result: Result<&1,&1,U32 & String,rows()>,prior: T.answer()) -> IO(T.answer()):
  match result:
    case Done{_}: pure(prior)
    case Fail{_}: pure(fail("attachment_asset_cleanup_failed","Owned attachment transaction cleanup failed; close this connection"))

def rollback(db: U32,prior: T.answer()) -> IO(T.answer()):
  do IO<T.answer()>:
    result : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,"ROLLBACK",[],0)
    cleaned(result,prior)

def committed(result: Result<&1,&1,U32 & String,rows()>,db: U32,value: T.Outcome) -> IO(T.answer()):
  match result:
    case Done{_}: pure(Done{value})
    case Fail{_}: rollback(db,database())

def finish(prior: T.answer(),+db: U32,write: Bool) -> IO(T.answer()):
  match prior write:
    case Done{value} True{}:
      do IO<T.answer()>:
        result : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,"COMMIT",[],0)
        committed(result,db,value)
    case other _: rollback(db,other)

def started(result: Result<&1,&1,U32 & String,rows()>,+db: U32,write: Bool,operation: U32 -> IO(T.answer())) -> IO(T.answer()):
  match result:
    case Fail{_}: pure(fail("attachment_asset_transaction_unavailable","Cannot begin attachment transaction; caller transaction was left untouched"))
    case Done{_}:
      do IO<T.answer()>:
        prior : T.answer() <- operation(db)
        finish(prior,db,write)

def transaction(+db: U32,+write: Bool,operation: U32 -> IO(T.answer())) -> IO(T.answer()):
  do IO<T.answer()>:
    result : Result<&1,&1,U32 & String,rows()> <- Sql.query(db,Bool.pick(String,write,"BEGIN IMMEDIATE","BEGIN DEFERRED"),[],0)
    started(result,db,write,operation)

def checked(result: T.unit_result(),next: Unit -> IO(T.answer())) -> IO(T.answer()):
  match result:
    case Fail{error}: pure(Fail{error})
    case Done{_}: next(Unit{})

def initialized(result: T.unit_result()) -> IO(T.answer()):
  checked(result,_ => pure(Done{T.Initialized{}}))

def initialize_owned(db: U32) -> IO(T.answer()):
  do IO<T.answer()>:
    result : T.unit_result() <- Schema.initialize_owned(db)
    initialized(result)

def initialize(db: U32) -> IO(T.answer()):
  transaction(db,True{},d => initialize_owned(d))

def keys(value: Identity.Resolved) -> List<&2,Sql.Cell>:
  Identity.Resolved{Meta.Header{snapshot,_,_,_,_,_,_,_,_,_,_},record,_,_,_,reference,_,_,_} = value
  [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(record)},Sql.Cell.Integer{U32.show(reference)}]

def canonical_number(value: Maybe<&2,U32>,text: String) -> Maybe<&2,U32>:
  match value:
    case Some{+number}: Bool.pick(Maybe<&2,U32>,String.eq(U32.show(number),text),Some{number},None{})
    case None{}: None{}

def number(cell: Sql.Cell) -> Maybe<&2,U32>:
  match cell:
    case Sql.Cell.Integer{+text}: canonical_number(Domain.parse_u32(text),text)
    case _: None{}

def receipt_counts(count: Maybe<&2,U32>,chunks: Maybe<&2,U32>,occurrence: Identity.Resolved,root: T.RootEvidence,time: String,digest: String,seal: String) -> Maybe<&2,T.Receipt>:
  match count chunks:
    case Some{count} Some{chunks}: Some{T.Receipt{occurrence,root,time,count,chunks,digest,seal}}
    case _ _: None{}

def receipt_row(value: List<&2,Sql.Cell>,+occurrence: Identity.Resolved) -> Maybe<&2,T.Receipt>:
  match value:
    case [Sql.Cell.Text{path},Sql.Cell.Text{identity},Sql.Cell.Text{root_id},Sql.Cell.Text{root_path},Sql.Cell.Text{revision},Sql.Cell.Text{time},count,chunks,Sql.Cell.Text{digest},Sql.Cell.Text{seal}]:
      Identity.Resolved{_,_,_,_,_,_,wanted_path,_,_} = occurrence
      Schema.branch(Maybe<&2,T.Receipt>,String.eq(path,wanted_path) && String.eq(identity,T.identity_text(occurrence)),
        _ => receipt_counts(number(count),number(chunks),occurrence,T.RootEvidence{root_id,root_path,revision,True{}},time,digest,seal),_ => None{})
    case _: None{}

def chunk_values(ordinal: Maybe<&2,U32>,offset: Maybe<&2,U32>,n: Maybe<&2,U32>,digest: String,bytes: List<&2,U32>) -> Maybe<&2,T.Chunk>:
  match ordinal offset n:
    case Some{ordinal} Some{offset} Some{n}: Some{T.Chunk{ordinal,offset,n,digest,bytes}}
    case _ _ _: None{}

def chunk_row(row: List<&2,Sql.Cell>) -> Maybe<&2,T.Chunk>:
  match row:
    case [ordinal,offset,n,Sql.Cell.Text{digest},Sql.Cell.Blob{bytes}]: chunk_values(number(ordinal),number(offset),number(n),digest,bytes)
    case _: None{}

def prepend_chunk(value: Maybe<&2,T.Chunk>,tail: Maybe<&2,List<&2,T.Chunk>>) -> Maybe<&2,List<&2,T.Chunk>>:
  match value tail:
    case Some{chunk} Some{rest}: Some{chunk <> rest}
    case _ _: None{}

def chunks(values: rows()) -> Maybe<&2,List<&2,T.Chunk>>:
  match values:
    case []: Some{[]}
    case row <> rest: prepend_chunk(chunk_row(row),chunks(rest))

def loaded_chunks(value: Maybe<&2,List<&2,T.Chunk>>,receipt: T.Receipt) -> IO(T.answer()):
  match value:
    case None{}: pure(invalid())
    case Some{parts}:
      +owned : T.Owned = T.Owned{receipt,parts}
      pure(Bool.pick(T.answer(),T.owned_valid(owned),Done{T.Loaded{owned}},invalid()))

def read_chunks(+db: U32,+receipt: T.Receipt) -> IO(T.answer()):
  T.Receipt{occurrence,_,_,_,_,_,_} = receipt
  query(db,"SELECT ordinal,offset,n,sha256,bytes FROM main.attachment_asset_chunks WHERE snapshot=? AND record=? AND reference=? ORDER BY ordinal LIMIT 17",
    keys(occurrence),17,v => loaded_chunks(chunks(v),receipt))

# Metadata-only admission precedes materializing any BLOB. Every queried chunk
# is bounded, contiguous and has the exact expected length; byte hashes remain
# independently verified after transfer under the same transaction snapshot.
def admitted_chunk_numbers(ordinal: Maybe<&2,U32>,offset: Maybe<&2,U32>,n: Maybe<&2,U32>,actual: Maybe<&2,U32>,+index: U32,+at: U32,+total: U32) -> Bool:
  match ordinal offset n actual:
    case Some{ordinal} Some{offset} Some{+n} Some{actual}:
      U32.is_lt(index,16) && U32.is_eq(index,ordinal) && U32.is_eq(at,offset) && U32.is_le(at,total) &&
        U32.is_eq(n,U32.min(65536,U32.sub(total,at))) && U32.is_gt(n,0) && U32.is_eq(n,actual)
    case _ _ _ _: False{}

def admitted_chunks(values: rows(),+index: U32,+at: U32,+total: U32) -> Bool:
  match values:
    case []: U32.is_eq(at,total) && U32.is_eq(index,T.chunk_count(total))
    case [ordinal,offset,+n,Sql.Cell.Text{"blob"},actual,Sql.Cell.Text{"text"},Sql.Cell.Integer{"64"}] <> rest:
      admitted_chunk_numbers(number(ordinal),number(offset),number(n),number(actual),index,at,total) &&
        admitted_chunks(rest,U32.inc(index),U32.add(at,U32.min(65536,U32.sub(total,at))),total)
    case _: False{}

def chunk_admission(value: rows(),db: U32,+receipt: T.Receipt) -> IO(T.answer()):
  T.Receipt{_,_,_,total,_,_,_} = receipt
  Schema.branch(IO(T.answer()),admitted_chunks(value,0,0,total),_ => read_chunks(db,receipt),_ => pure(invalid()))

def admit_chunks(+db: U32,+receipt: T.Receipt) -> IO(T.answer()):
  T.Receipt{occurrence,_,_,_,_,_,_} = receipt
  query(db,"SELECT CASE WHEN typeof(ordinal)='integer' THEN ordinal ELSE NULL END,CASE WHEN typeof(offset)='integer' THEN offset ELSE NULL END,CASE WHEN typeof(n)='integer' THEN n ELSE NULL END,typeof(bytes),length(bytes),typeof(sha256),length(CAST(sha256 AS BLOB)) FROM main.attachment_asset_chunks WHERE snapshot=? AND record=? AND reference=? ORDER BY ordinal LIMIT 17",
    keys(occurrence),17,v => chunk_admission(v,db,receipt))

def valid_receipt(value: Maybe<&2,T.Receipt>,db: U32) -> IO(T.answer()):
  match value:
    case None{}: pure(invalid())
    case Some{+receipt}: Schema.branch(IO(T.answer()),T.receipt_valid(receipt),_ => admit_chunks(db,receipt),_ => pure(invalid()))

def receipt_rows(value: rows(),db: U32,occurrence: Identity.Resolved) -> IO(T.answer()):
  match value:
    case [row]: valid_receipt(receipt_row(row,occurrence),db)
    case []: pure(missing())
    case _: pure(invalid())

def read_receipt(+db: U32,+occurrence: Identity.Resolved) -> IO(T.answer()):
  query(db,"SELECT json_path,identity,root_id,root_path,root_revision,observed_at_ms,byte_count,chunk_count,sha256,commitment FROM main.attachment_assets WHERE snapshot=? AND record=? AND reference=? LIMIT 2",
    keys(occurrence),2,v => receipt_rows(v,db,occurrence))

def parent_admitted(value: rows(),db: U32,occurrence: Identity.Resolved) -> IO(T.answer()):
  match value:
    case [[Sql.Cell.Integer{"1"}]]: read_receipt(db,occurrence)
    case []: pure(missing())
    case _: pure(invalid())

def load_owned(+db: U32,+occurrence: Identity.Resolved) -> IO(T.answer()):
  query(db,"SELECT CASE WHEN typeof(json_path)='text' AND length(CAST(json_path AS BLOB))<=2048 AND typeof(identity)='text' AND length(CAST(identity AS BLOB))<=32768 AND typeof(root_id)='text' AND length(CAST(root_id AS BLOB))<=19 AND typeof(root_path)='text' AND length(CAST(root_path AS BLOB))<=4096 AND typeof(root_revision)='text' AND length(CAST(root_revision AS BLOB))<=19 AND typeof(observed_at_ms)='text' AND length(CAST(observed_at_ms AS BLOB))<=19 AND typeof(byte_count)='integer' AND byte_count BETWEEN 0 AND 1048576 AND typeof(chunk_count)='integer' AND chunk_count BETWEEN 0 AND 16 AND typeof(sha256)='text' AND length(CAST(sha256 AS BLOB))=64 AND typeof(commitment)='text' AND length(CAST(commitment AS BLOB))=64 THEN 1 ELSE 0 END FROM main.attachment_assets WHERE snapshot=? AND record=? AND reference=? LIMIT 2",
    keys(occurrence),2,v => parent_admitted(v,db,occurrence))

def resolved_read(result: Result<&2,&2,Inventory.Failure,Identity.Resolved>,db: U32) -> IO(T.answer()):
  match result:
    case Fail{error}: pure(Fail{error})
    case Done{occurrence}: load_owned(db,occurrence)

def resolve_read(+db: U32,request: Identity.Request) -> IO(T.answer()):
  do IO<T.answer()>:
    resolved : Result<&2,&2,Inventory.Failure,Identity.Resolved> <- Identity.resolve_owned(db,request)
    resolved_read(resolved,db)

def read_owned(+db: U32,request: Identity.Request) -> IO(T.answer()):
  do IO<T.answer()>:
    schema : T.unit_result() <- Schema.validate_owned(db)
    checked(schema,_ => resolve_read(db,request))

def read(db: U32,request: Identity.Request) -> IO(T.answer()):
  transaction(db,False{},d => read_owned(d,request))

def observed(result: Result<&2,&1,Inventory.Failure,T.Observer>,next: T.Observer -> IO(T.answer())) -> IO(T.answer()):
  match result:
    case Fail{error}: pure(Fail{error})
    case Done{observer}: next(observer)

def observe(observer: T.Observer,phase: T.Phase,next: T.Observer -> IO(T.answer())) -> IO(T.answer()):
  match observer:
    case T.Inert{}: next(T.Inert{})
    case T.Observed{step}:
      do IO<T.answer()>:
        result : Result<&2,&1,Inventory.Failure,T.Observer> <- step(phase)
        observed(result,next)

def published_read(result: T.answer(),wanted: T.Receipt,expected: List<&2,T.Chunk>,retry: Bool,observer: T.Observer) -> IO(T.answer()):
  match result:
    case Done{T.Loaded{T.Owned{+receipt,actual}}}:
      Schema.branch(IO(T.answer()),T.same(receipt,wanted) && T.chunks_equal(actual,expected),
        _ => observe(observer,T.BeforeCommit{},_ => pure(Done{T.Published{receipt,retry}})),
        _ => pure(fail("attachment_asset_conflict","This occurrence already has a different immutable byte observation")))
    case Fail{error}: pure(Fail{error})
    case _: pure(invalid())

def check_published(+db: U32,+receipt: T.Receipt,expected: List<&2,T.Chunk>,retry: Bool,observer: T.Observer) -> IO(T.answer()):
  T.Receipt{occurrence,_,_,_,_,_,_} = receipt
  do IO<T.answer()>:
    result : T.answer() <- load_owned(db,occurrence)
    published_read(result,receipt,expected,retry,observer)

def chunk_args(occurrence: Identity.Resolved,chunk: T.Chunk) -> List<&2,Sql.Cell>:
  T.Chunk{ordinal,offset,n,digest,bytes} = chunk
  List.append(&2,Sql.Cell,keys(occurrence),[Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(offset)},
    Sql.Cell.Integer{U32.show(n)},Sql.Cell.Text{digest},Sql.Cell.Blob{bytes}])

def insert_chunks(values: List<&2,T.Chunk>,+db: U32,+receipt: T.Receipt,expected: List<&2,T.Chunk>,observer: T.Observer) -> IO(T.answer()):
  match values:
    case []: check_published(db,receipt,expected,False{},observer)
    case +chunk <> rest:
      T.Chunk{ordinal,_,_,_,_} = chunk
      T.Receipt{occurrence,_,_,_,_,_,_} = receipt
      query(db,"INSERT INTO main.attachment_asset_chunks(snapshot,record,reference,ordinal,offset,n,sha256,bytes) VALUES(?,?,?,?,?,?,?,?)",
        chunk_args(occurrence,chunk),0,_ => observe(observer,T.ChunkInserted{ordinal},next => insert_chunks(rest,db,receipt,expected,next)))

def occurrence_path(value: Identity.Resolved) -> String:
  Identity.Resolved{_,_,_,_,_,_,path,_,_} = value
  path

def parent_args(+receipt: T.Receipt) -> List<&2,Sql.Cell>:
  T.Receipt{+occurrence,T.RootEvidence{id,path,revision,_},time,count,chunks,digest,seal} = receipt
  List.append(&2,Sql.Cell,keys(occurrence),[Sql.Cell.Text{occurrence_path(occurrence)},Sql.Cell.Text{T.identity_text(occurrence)},Sql.Cell.Text{id},
    Sql.Cell.Text{path},Sql.Cell.Text{revision},Sql.Cell.Text{time},Sql.Cell.Integer{U32.show(count)},Sql.Cell.Integer{U32.show(chunks)},Sql.Cell.Text{digest},Sql.Cell.Text{seal}])

def insert(+db: U32,+receipt: T.Receipt,+parts: List<&2,T.Chunk>,observer: T.Observer) -> IO(T.answer()):
  query(db,"INSERT INTO main.attachment_assets(snapshot,record,reference,json_path,identity,root_id,root_path,root_revision,observed_at_ms,byte_count,chunk_count,sha256,commitment) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)",
    parent_args(receipt),0,_ => observe(observer,T.AssociationInserted{},next => insert_chunks(parts,db,receipt,parts,next)))

def exists(value: rows(),db: U32,receipt: T.Receipt,parts: List<&2,T.Chunk>,observer: T.Observer) -> IO(T.answer()):
  match value:
    case []: insert(db,receipt,parts,observer)
    case [[Sql.Cell.Integer{"1"}]]: check_published(db,receipt,parts,True{},observer)
    case _: pure(invalid())

def publish_authorized(+db: U32,+admission: T.Admission,observer: T.Observer) -> IO(T.answer()):
  T.Admission{occurrence,_,_,payload} = admission
  query(db,"SELECT 1 FROM main.attachment_assets WHERE snapshot=? AND record=? AND reference=? LIMIT 2",keys(occurrence),2,
    v => exists(v,db,T.receipt(admission),T.payload_chunks(payload),observer))

# The callback is mandatory, runs on this exact owned write transaction and is
# the policy authority. Supplied enabled/path/revision metadata alone is not.
def authorize(+db: U32,+admission: T.Admission,validator: U32 -> T.RootEvidence -> IO(T.unit_result()),observer: T.Observer) -> IO(T.answer()):
  T.Admission{_,root,_,_} = admission
  do IO<T.answer()>:
    policy : T.unit_result() <- validator(db,root)
    checked(policy,_ => publish_authorized(db,admission,observer))

def publish_resolved(result: Result<&2,&2,Inventory.Failure,Identity.Resolved>,db: U32,+admission: T.Admission,
  validator: U32 -> T.RootEvidence -> IO(T.unit_result()),observer: T.Observer) -> IO(T.answer()):
  match result:
    case Fail{error}: pure(Fail{error})
    case Done{actual}:
      T.Admission{wanted,_,_,_} = admission
      Schema.branch(IO(T.answer()),Identity.same(actual,wanted),_ => authorize(db,admission,validator,observer),
        _ => pure(fail("attachment_asset_occurrence_changed","The supplied retained occurrence identity does not match verified storage")))

def publish_resolve(+db: U32,+admission: T.Admission,validator: U32 -> T.RootEvidence -> IO(T.unit_result()),observer: T.Observer) -> IO(T.answer()):
  T.Admission{occurrence,_,_,_} = admission
  do IO<T.answer()>:
    result : Result<&2,&2,Inventory.Failure,Identity.Resolved> <- Identity.resolve_owned(db,Identity.request(occurrence))
    publish_resolved(result,db,admission,validator,observer)

def publish_owned(+db: U32,admission: T.Admission,validator: U32 -> T.RootEvidence -> IO(T.unit_result()),observer: T.Observer) -> IO(T.answer()):
  do IO<T.answer()>:
    schema : T.unit_result() <- Schema.validate_owned(db)
    checked(schema,_ => publish_resolve(db,admission,validator,observer))

def publish_observed(db: U32,+admission: T.Admission,validator: U32 -> T.RootEvidence -> IO(T.unit_result()),observer: T.Observer) -> IO(T.answer()):
  Schema.branch(IO(T.answer()),T.admission_valid(admission),_ => transaction(db,True{},d => publish_owned(d,admission,validator,observer)),
    _ => pure(fail("attachment_asset_admission_invalid","External attachment admission metadata or worker bytes are invalid")))

def publish(db: U32,admission: T.Admission,validator: U32 -> T.RootEvidence -> IO(T.unit_result())) -> IO(T.answer()):
  publish_observed(db,admission,validator,T.Inert{})

def bytes(values: List<&2,T.Chunk>) -> List<&2,U32>:
  match values:
    case []: []
    case T.Chunk{_,_,_,_,part} <> rest: List.append(&2,U32,part,bytes(rest))

def write(+db: U32,path: String,+owned: T.Owned) -> IO(String):
  T.Owned{_,parts} = owned
  do IO<String>:
    Store.checked(T.owned_valid(owned),"Owned external attachment integrity failed before output")
    +canonical : String <- Paths.destination(path)
    Maintenance.output_canonical(db,canonical)
    +temporary : String <- Maintenance.temporary(canonical)
    file : File <- IO.try(File,File.open(temporary,"w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes(parts))
    Store.write_closed(written)
    Maintenance.publish(temporary,canonical)
    return canonical

def export_result(result: T.answer(),db: U32,+destination: String) -> IO(T.answer()):
  match result:
    case Fail{error}: pure(Fail{error})
    case Done{T.Loaded{+owned}}:
      T.Owned{receipt,_} = owned
      do IO<T.answer()>:
        canonical : String <- write(db,destination,owned)
        return Done{T.Exported{receipt,canonical}}
    case _: pure(invalid())

# Current root authorization is deliberately not consulted here: revocation
# blocks new capture, never preservation/read/export of already accepted bytes.
def export(+db: U32,request: Identity.Request,destination: String) -> IO(T.answer()):
  do IO<T.answer()>:
    result : T.answer() <- read(db,request)
    export_result(result,db,destination)
