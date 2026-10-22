import Base
import ./attachment_decode.bend as Decode
import ./attachment_refs.bend as Ref
import ./attachment_extract.bend as Extract
import ./attachment_inventory.bend as Inventory
import ./archive_meta.bend as Meta
import ./maintenance.bend as Maintenance
import ./domain.bend as Domain
import ./json.bend as Json
import ./store.bend as Store
import ./sql.bend as Sql
import ./paths.bend as Paths

type Request is Data:
  Request{snapshot: String,record: U32,reference: U32,path: String}

type InlineValue is Data:
  InlineValue{media: String,data: Decode.Bytes}

type Resolved is Data:
  Resolved{capture: Meta.Header,record: U32,offset: U32,length: U32,raw_digest: String,
    reference: U32,path: String,media_type: String,data: Decode.Bytes}

def failure(code: String) -> Inventory.Failure:
  Inventory.Failure{code,"Inline attachment request could not resolve exact verified retained bytes"}

def at(items: List<&2,Json.Json>,index: Nat) -> Json.Json:
  match items index:
    case [] _: Json.JNull{}
    case item <> _ 0n: item
    case _ <> rest 1n+left: at(rest,left)

def index_valid(valid: Bool,items: List<&2,Json.Json>,index: U32) -> Json.Json:
  match valid:
    case True{}: at(items,U32.to_nat(index))
    case False{}: Json.JNull{}

def array_index(parsed: Maybe<&2,U32>,items: List<&2,Json.Json>,key: String) -> Json.Json:
  match parsed:
    case None{}: Json.JNull{}
    case Some{+index}: index_valid(String.eq(U32.show(index),key),items,index)

def child(value: Json.Json,+key: String) -> Json.Json:
  match value:
    case Json.JObject{fields}: Json.field(Json.JObject{fields},key)
    case Json.JArray{items}: array_index(Domain.parse_u32(key),items,key)
    case _: Json.JNull{}

# Only extractor-issued paths reach this helper. Known keys do not need JSON
# pointer unescaping; arbitrary user paths are never traversal authority.
def descend(parts: List<&2,String>,value: Json.Json) -> Json.Json:
  match parts:
    case []: value
    case key <> rest: descend(rest,child(value,key))

def path_value(parts: List<&2,String>,value: Json.Json) -> Json.Json:
  match parts:
    case "" <> rest: descend(rest,value)
    case _: Json.JNull{}

def payload_url(fuel: Nat,text: String) -> Result<&2,&2,String,String>:
  match fuel text:
    case _ SNil{}: Fail{"data_url_missing_comma"}
    case 0n _: Fail{"data_url_header_limit"}
    case 1n+_ SCon{',',rest}: Done{rest}
    case 1n+left SCon{_,rest}: payload_url(left,rest)

def payload_kind(is_url: Bool,text: String) -> Result<&2,&2,String,String>:
  match is_url:
    case True{}: payload_url(256n,String.drop(text,5n))
    case False{}: Done{text}

def payload(value: Json.Json) -> Result<&2,&2,String,String>:
  match value:
    case Json.JString{+text}: payload_kind(String.starts_with(text,"data:"),text)
    case _: Fail{"inline_data_not_string"}

def decoded(result: Result<&2,&2,String,Decode.Bytes>,expected: U32) -> Result<&2,&2,Inventory.Failure,Decode.Bytes>:
  match result:
    case Fail{_}: Fail{failure("attachment_invalid_base64")}
    case Done{Decode.Bytes{bytes,+count,digest}}:
      Bool.pick(Result<&2,&2,Inventory.Failure,Decode.Bytes>,U32.is_eq(count,expected),
        Done{Decode.Bytes{bytes,count,digest}},Fail{failure("attachment_inline_length_mismatch")})

def payload_decode(result: Result<&2,&2,String,String>,expected: U32) -> Result<&2,&2,Inventory.Failure,Decode.Bytes>:
  match result:
    case Fail{_}: Fail{failure("attachment_unsupported_encoding")}
    case Done{text}: decoded(Decode.decode(text),expected)

def with_media(result: Result<&2,&2,Inventory.Failure,Decode.Bytes>,media: String) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match result:
    case Fail{error}: Fail{error}
    case Done{bytes}: Done{InlineValue{media,bytes}}

def reference_decode(reference: Ref.Reference,value: Json.Json) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match reference:
    case Ref.InlineData{media,"base64",Ref.ValidBase64{_,expected}}:
      with_media(payload_decode(payload(value),expected),media)
    case Ref.InlineData{_,_,Ref.InvalidBase64{_}}: Fail{failure("attachment_invalid_base64")}
    case _: Fail{failure("attachment_not_supported_inline")}

def exact(valid: Bool,reference: Ref.Reference,path: String,value: Json.Json) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match valid:
    case False{}: Fail{failure("attachment_occurrence_path_mismatch")}
    case True{}: reference_decode(reference,path_value(String.split(path,'/'),value))

def choose(found: Bool,reference: Ref.Reference,+actual_path: String,+path: String,value: Json.Json,
  next: Json.Json -> Result<&2,&2,Inventory.Failure,InlineValue>) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match found:
    case True{}: exact(String.eq(actual_path,path),reference,actual_path,value)
    case False{}: next(value)

def select(rows: List<&2,Extract.Occurrence>,+ordinal: U32,+path: String,value: Json.Json) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match rows:
    case []: Fail{failure("attachment_occurrence_not_found")}
    case Extract.Occurrence{actual,+actual_path,_,reference} <> rest:
      choose(U32.is_eq(actual,ordinal),reference,actual_path,path,value,
        remaining_value => select(rest,ordinal,path,remaining_value))

def report(report: Extract.Report,ordinal: U32,path: String,value: Json.Json) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  Extract.Report{rows,_} = report
  select(rows,ordinal,path,value)

def parsed(result: Result<&2,&2,String,Json.Json>,provider: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match result:
    case Fail{_}: Fail{failure("attachment_malformed_json")}
    case Done{+value}: report(Extract.value(provider,value),ordinal,path,value)

def text(result: Result<&2,&2,String,String>,provider: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match result:
    case Fail{_}: Fail{failure("attachment_invalid_utf8")}
    case Done{raw}: parsed(Json.parse(raw),provider,ordinal,path)

def raw(oversized: Bool,bytes: List<&2,U32>,provider: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,InlineValue>:
  match oversized:
    case True{}: Fail{failure("attachment_oversized_record")}
    case False{}: text(Domain.decode(bytes),provider,ordinal,path)

def resolved(result: Result<&2,&2,Inventory.Failure,InlineValue>,capture: Meta.Header,record: U32,offset: U32,length: U32,digest: String,ordinal: U32,path: String) -> Result<&2,&2,Inventory.Failure,Resolved>:
  match result:
    case Fail{error}: Fail{error}
    case Done{InlineValue{media,bytes}}: Done{Resolved{capture,record,offset,length,digest,ordinal,path,media,bytes}}

def row(+capture: Meta.Header,record: U32,+ordinal: U32,+path: String,+raw_row: List<&2,Sql.Cell>) -> Result<&2,&2,Inventory.Failure,Resolved>:
  Meta.Header{_,_,_,provider,_,_,_,_,_,_,_} = capture
  resolved(raw(U32.is_ne(Store.number(Store.field(raw_row,6n)),0),Store.blob(Store.cell(raw_row,5n)),provider,ordinal,path),
    capture,record,Store.number(Store.field(raw_row,2n)),Store.number(Store.field(raw_row,3n)),Store.field(raw_row,4n),ordinal,path)

def read_record(valid: Bool,+db: U32,+capture: Meta.Header,+record: U32,ordinal: U32,path: String) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match valid:
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
  Request{+snapshot,+record,ordinal,path} = request
  do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
    verified : Maintenance.Header <- Maintenance.header(db,snapshot)
    +capture : Meta.Header <- Meta.header(db,snapshot,True{})
    Store.checked(Inventory.same_header(verified,capture),"Inline attachment header changed within read transaction")
    read_captured(db,capture,record,ordinal,path)

def cleanup(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,value: Result<&2,&2,Inventory.Failure,Resolved>) -> Result<&2,&2,Inventory.Failure,Resolved>:
  match result:
    case Done{_}: value
    case Fail{_}: Fail{failure("attachment_cleanup_failed")}

# Existence/acceptance is ordinary request admission. It does not bypass either
# established header verifier and does not transfer any raw payload.
def read_candidate(rows: List<&2,List<&2,Sql.Cell>>,db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match rows:
    case []: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_snapshot_not_found")})
    case [[Sql.Cell.Integer{"0"}]]:
      IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_snapshot_not_accepted")})
    case [[Sql.Cell.Integer{"1"}]]: read_verified(db,request)
    case _: IO.die(Result<&2,&2,Inventory.Failure,Resolved>,1,"Inline attachment snapshot acceptance metadata is corrupt")

def read_header(+db: U32,+request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  Request{snapshot,_,_,_} = request
  do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT accepted FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],1)
    read_candidate(rows,db,request)

def owned(result: Result<&2,&2,Inventory.Failure,Unit>,+db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match result:
    case Fail{error}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{error})
    case Done{_}:
      do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
        value : Result<&2,&2,Inventory.Failure,Resolved> <- read_header(db,request)
        rolled : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"ROLLBACK",[],0)
        return cleanup(rolled,value)

def resolve_valid(valid: Bool,+db: U32,request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{failure("attachment_invalid_request")})
    case True{}:
      do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
        transaction : Result<&2,&2,Inventory.Failure,Unit> <- Inventory.transaction(db)
        owned(transaction,db,request)

def resolve(db: U32,+request: Request) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  Request{snapshot,_,ordinal,+path} = request
  resolve_valid(Meta.identity(snapshot) && U32.is_lt(ordinal,64) && Ref.bounded(path,2048) &&
    String.starts_with(path,"/"),db,request)

# Only fully decoded, length/digest-validated bytes reach output creation. The
# existing 0600 mktemp and no-clobber exact link publication helpers are reused.
def write(+db: U32,path: String,+data: Decode.Bytes) -> IO(Unit):
  Decode.Bytes{bytes,_,_} = data
  do IO<Unit>:
    Store.checked(Decode.valid(data),"Inline attachment decoded integrity failed before output")
    +canonical : String <- Paths.destination(path)
    Maintenance.output_canonical(db,canonical)
    +temporary : String <- Maintenance.temporary(canonical)
    file : File <- IO.try(File,File.open(temporary,"w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(written)
    Maintenance.publish(temporary,canonical)

def export_resolved(result: Result<&2,&2,Inventory.Failure,Resolved>,db: U32,path: String) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  match result:
    case Fail{error}: IO.pure(Result<&2,&2,Inventory.Failure,Resolved>,Fail{error})
    case Done{+value}:
      Resolved{_,_,_,_,_,_,_,_,data} = value
      do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
        write(db,path,data)
        return Done{value}

def export(+db: U32,request: Request,path: String) -> IO(Result<&2,&2,Inventory.Failure,Resolved>):
  do IO<Result<&2,&2,Inventory.Failure,Resolved>>:
    result : Result<&2,&2,Inventory.Failure,Resolved> <- resolve(db,request)
    export_resolved(result,db,path)
