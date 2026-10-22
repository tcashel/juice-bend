import Base
import ./attachment_refs.bend as Ref
import ./attachment_extract.bend as Extract
import ./attachment_inventory.bend as Inventory
import ./archive_meta.bend as Meta
import ./maintenance.bend as Maintenance
import ./domain.bend as Domain
import ./json.bend as Json
import ./store.bend as Store
import ./sql.bend as Sql

# Exact retained local-reference identity only. No referenced file or source
# locator is opened, normalized, percent-decoded, or treated as authorization.
type Request is Data:
  Request{snapshot: String,record: U32,reference: U32,path: String}

type LocalReference is Data:
  LocalPath{value: String}
  LocalFileURL{value: String}

type Resolved is Data:
  # raw_sha256 is Store's existing raw-record commitment: SHA256 of the exact
  # generation|ordinal|offset|length| framing followed by raw bytes, not a bare
  # payload digest. It binds the retained physical identity as well as content.
  Resolved{capture: Meta.Header,record: U32,offset: U32,length: U32,raw_sha256: String,
    reference: U32,path: String,kind: String,local: LocalReference}

type Found is Data:
  Found{kind: String,local: LocalReference}

def failure(code: String) -> Inventory.Failure:
  Inventory.Failure{code,"Local attachment request could not resolve exact verified retained identity"}

def request(value: Resolved) -> Request:
  Resolved{Meta.Header{snapshot,_,_,_,_,_,_,_,_,_,_},record,_,_,_,reference,path,_,_} = value
  Request{snapshot,record,reference,path}

def request_valid(value: Request) -> Bool:
  Request{snapshot,_,reference,+path} = value
  Meta.identity(snapshot) && U32.is_lt(reference,64) && Ref.bounded(path,2048) && String.starts_with(path,"/")

def local_fields(value: LocalReference) -> List<&2,String>:
  match value:
    case LocalPath{value}: ["local_path",value]
    case LocalFileURL{value}: ["local_file_url",value]

# Stable order: all eleven Header fields in declaration order, then the nine
# occurrence fields below. Every numeric spelling is canonical and accepted is
# literal true/false. Callers length-frame these exact fields before hashing.
def fields(value: Resolved) -> List<&2,String>:
  Resolved{Meta.Header{snapshot,source,generation,provider,locator,extent,records,checkpoint,checkpoint_ordinal,accepted,encoding},
    record,offset,length,raw_sha256,reference,path,kind,local} = value
  List.append(&2,String,[snapshot,source,generation,provider,locator,U32.show(extent),U32.show(records),
    U32.show(checkpoint),U32.show(checkpoint_ordinal),Bool.pick(String,accepted,"true","false"),encoding,
    U32.show(record),U32.show(offset),U32.show(length),raw_sha256,U32.show(reference),path,kind],local_fields(local))

def same_fields(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case first <> rest second <> tail: String.eq(first,second) && same_fields(rest,tail)
    case _ _: False{}

def same(a: Resolved,b: Resolved) -> Bool:
  same_fields(fields(a),fields(b))

def local_valid(value: LocalReference) -> Bool:
  match value:
    case LocalPath{+value}: Ref.bounded(value,4096) && String.starts_with(value,"/")
    case LocalFileURL{+value}: Ref.bounded(value,4096) &&
      (String.starts_with(value,"file:///") || String.starts_with(value,"file://localhost/"))

def kind_valid(+kind: String) -> Bool:
  String.eq(kind,"image") || String.eq(kind,"document") || String.eq(kind,"input_image") || String.eq(kind,"image_url")

def valid(+value: Resolved) -> Bool:
  Resolved{+capture,+record,+offset,+length,raw_sha256,_,_,kind,local} = value
  Meta.Header{_,_,_,+provider,+locator,+extent,total,_,_,accepted,+encoding} = capture
  Meta.header_valid(capture) && accepted && (String.eq(provider,"claude") || String.eq(provider,"codex")) &&
    Ref.bounded(locator,4096) && String.starts_with(locator,"/") &&
    (String.eq(encoding,"identity") || String.eq(encoding,"zstd-jsonl-v1")) && request_valid(request(value)) &&
    U32.is_lt(record,total) && U32.is_gt(length,0) && U32.is_le(length,262144) && U32.is_le(offset,extent) &&
    U32.is_le(length,U32.sub(extent,offset)) && (U32.is_ne(record,0) || U32.is_eq(offset,0)) &&
    Meta.digest_valid(raw_sha256) && kind_valid(kind) && local_valid(local)

def local(kind: String,value: Ref.Reference) -> Result<&2,&2,Inventory.Failure,Found>:
  match value:
    case Ref.LocalPath{value}: Done{Found{kind,LocalPath{value}}}
    case Ref.LocalFileURL{value}: Done{Found{kind,LocalFileURL{value}}}
    case _: Fail{failure("attachment_not_supported_local")}

def exact(matches: Bool,kind: String,value: Ref.Reference) -> Result<&2,&2,Inventory.Failure,Found>:
  match matches:
    case True{}: local(kind,value)
    case False{}: Fail{failure("attachment_occurrence_path_mismatch")}

def select(rows: List<&2,Extract.Occurrence>,+ordinal: U32) -> Maybe<&2,Extract.Occurrence>:
  match rows:
    case []: None{}
    case +value <> rest:
      Extract.Occurrence{actual,_,_,_} = value
      Bool.pick(Maybe<&2,Extract.Occurrence>,U32.is_eq(actual,ordinal),Some{value},select(rest,ordinal))

def selected(value: Maybe<&2,Extract.Occurrence>,path: String) -> Result<&2,&2,Inventory.Failure,Found>:
  match value:
    case None{}: Fail{failure("attachment_occurrence_not_found")}
    case Some{Extract.Occurrence{_,actual_path,kind,reference}}: exact(String.eq(actual_path,path),kind,reference)

def report(value: Extract.Report,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,Found>:
  Extract.Report{rows,_} = value
  selected(select(rows,ordinal),path)

def parsed(result: Result<&2,&2,String,Json.Json>,provider: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,Found>:
  match result:
    case Fail{_}: Fail{failure("attachment_malformed_json")}
    case Done{value}: report(Extract.value(provider,value),ordinal,path)

def text(result: Result<&2,&2,String,String>,provider: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,Found>:
  match result:
    case Fail{_}: Fail{failure("attachment_invalid_utf8")}
    case Done{raw}: parsed(Json.parse(raw),provider,ordinal,path)

def raw(oversized: Bool,bytes: List<&2,U32>,provider: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,Found>:
  match oversized:
    case True{}: Fail{failure("attachment_oversized_record")}
    case False{}: text(Domain.decode(bytes),provider,ordinal,path)

def admitted_identity(+value: Resolved) -> Result<&2,&2,Inventory.Failure,Resolved>:
  Bool.pick(Result<&2,&2,Inventory.Failure,Resolved>,valid(value),Done{value},Fail{failure("attachment_local_identity_invalid")})

def resolved(result: Result<&2,&2,Inventory.Failure,Found>,capture: Meta.Header,record: U32,offset: U32,length: U32,digest: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,Resolved>:
  match result:
    case Fail{error}: Fail{error}
    case Done{Found{kind,local}}: admitted_identity(Resolved{capture,record,offset,length,digest,ordinal,path,kind,local})

def row(+capture: Meta.Header,record: U32,+ordinal: U32,+path: String,+raw_row: List<&2,Sql.Cell>) -> Result<&2,&2,Inventory.Failure,Resolved>:
  Meta.Header{_,_,_,provider,_,_,_,_,_,_,_} = capture
  resolved(raw(U32.is_ne(Store.number(Store.field(raw_row,6n)),0),Store.blob(Store.cell(raw_row,5n)),provider,ordinal,path),
    capture,record,Store.number(Store.field(raw_row,2n)),Store.number(Store.field(raw_row,3n)),Store.field(raw_row,4n),ordinal,path)

def read_record(allowed: Bool,+db: U32,+capture: Meta.Header,+record: U32,ordinal: U32,path: String) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match allowed:
    case False{}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_record_not_found")})
    case True{}:
      Meta.Header{+snapshot,_,generation,_,_,extent,total,_,_,_,_} = capture
      do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
        Inventory.admission(db,snapshot,record)
        raw_row : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,extent,total,record)
        return row(capture,record,ordinal,path,raw_row)

def read_captured(db: U32,+capture: Meta.Header,+record: U32,ordinal: U32,path: String) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  Meta.Header{_,_,_,_,_,_,total,_,_,_,_} = capture
  read_record(U32.is_lt(record,total),db,capture,record,ordinal,path)

def read_verified(+db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  Request{+snapshot,record,ordinal,path} = request
  do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
    verified : Maintenance.Header <- Maintenance.header(db,snapshot)
    +capture : Meta.Header <- Meta.header(db,snapshot,True{})
    Store.checked(Inventory.same_header(verified,capture),"Local attachment header changed within owned transaction")
    read_captured(db,capture,record,ordinal,path)

def read_candidate(rows: List<&2,List<&2,Sql.Cell>>,db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match rows:
    case []: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_snapshot_not_found")})
    case [[Sql.Cell.Integer{"0"}]]: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_snapshot_not_accepted")})
    case [[Sql.Cell.Integer{"1"}]]: read_verified(db,request)
    case _: IO.die(Result<&2,&2,Inventory.Failure,Resolved>,1,"Local attachment snapshot acceptance metadata is corrupt")

def read_header(+db: U32,+request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  Request{snapshot,_,_,_} = request
  do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT accepted FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],1)
    read_candidate(rows,db,request)

def resolve_owned_valid(allowed: Bool,db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match allowed:
    case False{}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_invalid_request")})
    case True{}: read_header(db,request)

# Internal seam: the caller MUST already own this connection's transaction.
# Publication passes its BEGIN IMMEDIATE view. This function neither begins nor
# commits nor rolls back; expected failures leave caller cleanup to the caller.
# Fatal existing integrity verifiers terminate the isolated worker, and SQLite
# connection teardown releases its transaction. No external effects occur here.
def resolve_owned(db: U32,+request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  resolve_owned_valid(request_valid(request),db,request)

def cleanup(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,value: Result<&2,&2,Inventory.Failure,Resolved>) -> Result<&2,&2,Inventory.Failure,Resolved>:
  match result:
    case Done{_}: value
    case Fail{_}: Fail{failure("attachment_cleanup_failed")}

def owned(result: Result<&2,&2,Inventory.Failure,Unit>,+db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match result:
    case Fail{error}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{error})
    case Done{_}:
      do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
        value : Result<&2,&2,Inventory.Failure,Resolved> <- resolve_owned(db,request)
        rolled : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"ROLLBACK",[],0)
        return cleanup(rolled,value)

def resolve_valid(allowed: Bool,+db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match allowed:
    case False{}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_invalid_request")})
    case True{}:
      do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
        transaction : Result<&2,&2,Inventory.Failure,Unit> <- Inventory.transaction(db)
        owned(transaction,db,request)

def resolve(db: U32,+request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  resolve_valid(request_valid(request),db,request)
