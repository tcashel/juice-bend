import Base
import ./attachment_inventory.bend as Inventory
import ./attachment_inventory_output.bend as Output
import ./attachment_inline.bend as Inline
import ./attachment_decode.bend as Decode
import ./attachment_extract.bend as Extract
import ./attachment_refs.bend as Ref
import ./archive_meta.bend as Meta
import ./domain.bend as Domain
import ./paths.bend as Paths

type Command is Data:
  InventoryCommand{snapshot: String,start: U32,count: U32}
  ExportCommand{request: Inline.Request,destination: String}

def answer_type() -> Data:
  Result<&2,&2,Inventory.Failure,String>

def usage() -> Inventory.Failure:
  Inventory.fail("attachment_usage",
    "Expected attachments SNAPSHOT START COUNT (1..40), or export-inline SNAPSHOT RECORD REF JSONPATH DEST; exact canonical identities and bounded paths are required")

def checked_command(valid: Bool,value: Command) -> Result<&2,&2,Inventory.Failure,Command>:
  match valid:
    case True{}: Done{value}
    case False{}: Fail{usage()}

def leaf(parts: List<&2,String>,prior: String) -> String:
  match parts:
    case []: prior
    case value <> rest: leaf(rest,value)

def filename_leaf(+name: String) -> Bool:
  Bool.not(String.is_empty(name)) && Bool.not(String.eq(name,".")) &&
    Bool.not(String.eq(name,"..")) && Ref.bounded(name,244)

def filename_checked(valid: Bool,path: String) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: filename_leaf(leaf(String.split(path,'/'),""))

# A caller chooses the destination. It is never derived from an attachment URL.
# Reserve 11 bytes of the 255-byte leaf limit for the existing .tmp.XXXXXX sink.
def filename(+path: String) -> Bool:
  filename_checked(Ref.bounded(path,4096),path)

def structural_path(+path: String) -> Bool:
  Ref.bounded(path,2048) && String.starts_with(path,"/")

def inventory_numbers(snapshot: String,start: Maybe<&2,U32>,count: Maybe<&2,U32>) -> Result<&2,&2,Inventory.Failure,Command>:
  match start count:
    case Some{start} Some{+count}:
      checked_command(U32.is_gt(count,0) && U32.is_le(count,40),InventoryCommand{snapshot,start,count})
    case _ _: Fail{usage()}

def export_numbers(snapshot: String,record: Maybe<&2,U32>,reference: Maybe<&2,U32>,path: String,destination: String) -> Result<&2,&2,Inventory.Failure,Command>:
  match record reference:
    case Some{record} Some{+reference}:
      checked_command(U32.is_lt(reference,64),ExportCommand{Inline.Request{snapshot,record,reference,path},destination})
    case _ _: Fail{usage()}

def checked_inventory(valid: Bool,snapshot: String,start: String,count: String) -> Result<&2,&2,Inventory.Failure,Command>:
  match valid:
    case False{}: Fail{usage()}
    case True{}: inventory_numbers(snapshot,Domain.parse_u32(start),Domain.parse_u32(count))

def inventory_bounded(valid: Bool,+snapshot: String,start: String,count: String) -> Result<&2,&2,Inventory.Failure,Command>:
  match valid:
    case False{}: Fail{usage()}
    case True{}: checked_inventory(Meta.identity(snapshot),snapshot,start,count)

def checked_export(valid: Bool,snapshot: String,record: String,reference: String,path: String,destination: String) -> Result<&2,&2,Inventory.Failure,Command>:
  match valid:
    case False{}: Fail{usage()}
    case True{}: export_numbers(snapshot,Domain.parse_u32(record),Domain.parse_u32(reference),path,destination)

def export_bounded(valid: Bool,+snapshot: String,record: String,reference: String,path: String,destination: String) -> Result<&2,&2,Inventory.Failure,Command>:
  match valid:
    case False{}: Fail{usage()}
    case True{}: checked_export(Meta.identity(snapshot),snapshot,record,reference,path,destination)

# The small bounds precede decimal parsing; very long malformed inputs are not
# recursively parsed or included in diagnostics. Domain.parse_u32 is canonical.
def parse(command: String,args: List<String>) -> Result<&2,&2,Inventory.Failure,Command>:
  match command args:
    case "attachments" +snapshot <> +start <> +count <> []:
      inventory_bounded(Ref.bounded(snapshot,19) && Ref.bounded(start,10) && Ref.bounded(count,2),snapshot,start,count)
    case "export-inline" +snapshot <> +record <> +reference <> +path <> +destination <> []:
      export_bounded(Ref.bounded(snapshot,19) && Ref.bounded(record,10) && Ref.bounded(reference,2) &&
        structural_path(path) && filename(destination),snapshot,record,reference,path,destination)
    case _ _: Fail{usage()}

def error_fields(value: Inventory.Failure) -> String:
  Inventory.Failure{code,message} = value
  "{\"kind\":\"attachment_error\",\"profile\":" ++ Output.quote(Extract.version()) ++
    ",\"code\":" ++ Output.quote(code) ++ ",\"message\":" ++ Output.quote(message) ++ "}"

def error_checked(valid: Bool,value: Inventory.Failure) -> String:
  match valid:
    case True{}: error_fields(value)
    case False{}: error_fields(Inventory.fail("attachment_error_limit","Attachment operation failed; diagnostic exceeded its metadata limit"))

def error(+value: Inventory.Failure) -> String:
  Inventory.Failure{code,message} = value
  error_checked(Ref.bounded(code,128) && Ref.bounded(message,2048),value)

def ack_fields(value: Inline.Resolved,destination: String) -> answer_type():
  Inline.Resolved{capture,record,offset,length,raw_digest,reference,path,media,Decode.Bytes{_,count,digest}} = value
  do Result<&2,&2,Inventory.Failure,String>:
    header : Output.Buffer <- Output.put("{\"kind\":\"attachment_inline_export\",\"profile\":" ++ Output.quote(Extract.version()) ++
      ",\"capture\":" ++ Output.capture(capture),Output.Buffer{262143,[]})
    identity : Output.Buffer <- Output.put(",\"record\":" ++ U32.show(record) ++ ",\"offset\":" ++ U32.show(offset) ++
      ",\"length\":" ++ U32.show(length) ++ ",\"raw_digest\":" ++ Output.quote(raw_digest) ++
      ",\"reference\":" ++ U32.show(reference) ++ ",\"path\":" ++ Output.quote(path),header)
    closed : Output.Buffer <- Output.put(",\"media_type\":" ++ Output.quote(media) ++ ",\"decoded_bytes\":" ++ U32.show(count) ++
      ",\"sha256\":" ++ Output.quote(digest) ++ ",\"destination\":" ++ Output.quote(destination) ++ "}",identity)
    return Output.finish(closed)

def ack_capture(+capture: Meta.Header,record: U32,+offset: U32,+length: U32) -> Bool:
  Meta.Header{_,_,_,_,_,+extent,total,_,_,accepted,+codec} = capture
  Meta.header_valid(capture) && accepted && (String.eq(codec,"identity") || String.eq(codec,"zstd-jsonl-v1")) &&
    U32.is_lt(record,total) && U32.is_gt(length,0) && U32.is_le(length,262144) &&
    U32.is_le(offset,extent) && U32.is_le(length,U32.sub(extent,offset))

def ack_shape(value: Inline.Resolved,+destination: String) -> Bool:
  Inline.Resolved{capture,record,offset,length,raw_digest,+reference,+path,media,Decode.Bytes{_,count,digest}} = value
  ack_capture(capture,record,offset,length) && Meta.digest_valid(raw_digest) && U32.is_lt(reference,64) && structural_path(path) &&
    Ref.media_type(media) && U32.is_le(count,786432) && Meta.digest_valid(digest) &&
    filename(destination) && String.starts_with(destination,"/")

def ack_checked(valid: Bool,value: Inline.Resolved,destination: String) -> answer_type():
  match valid:
    case False{}: Fail{Inventory.fail("attachment_ack_invalid","Verified inline export metadata could not be represented within the exact acknowledgement contract")}
    case True{}: ack_fields(value,destination)

# Pure acknowledgement serialization never includes decoded octets or encoded
# payloads. This seam does not grant any ability to export a supplied Resolved.
def acknowledge(+value: Inline.Resolved,+destination: String) -> answer_type():
  ack_checked(ack_shape(value,destination),value,destination)

def inventory_result(result: Result<&2,&2,Inventory.Failure,Inventory.Page>) -> answer_type():
  match result:
    case Fail{failure}: Fail{failure}
    case Done{page}: Output.encode(page)

def published(result: Result<&2,&2,Inventory.Failure,Inline.Resolved>,ack: String) -> answer_type():
  match result:
    case Fail{failure}: Fail{failure}
    case Done{_}: Done{ack}

def export_ready(result: answer_type(),db: U32,value: Inline.Resolved,destination: String) -> IO(answer_type()):
  match result:
    case Fail{failure}: IO.pure(answer_type(),Fail{failure})
    case Done{ack}:
      do IO<answer_type()>:
        written : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.export_resolved(Done{value},db,destination)
        return published(written,ack)

def export_value(result: Result<&2,&2,Inventory.Failure,Inline.Resolved>,db: U32,+destination: String) -> IO(answer_type()):
  match result:
    case Fail{failure}: IO.pure(answer_type(),Fail{failure})
    case Done{+value}: export_ready(acknowledge(value,destination),db,value,destination)

def export_canonical(valid: Bool,+db: U32,request: Inline.Request,+destination: String) -> IO(answer_type()):
  match valid:
    case False{}: IO.pure(answer_type(),Fail{usage()})
    case True{}:
      do IO<answer_type()>:
        fresh : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.resolve(db,request)
        export_value(fresh,db,destination)

# Only a fresh locally verified resolution enters export_resolved. Prepare and
# bound its exact acknowledgement before output creation, publish the same bytes,
# then emit that acknowledgement only after the no-clobber sink succeeds.
def execute(+db: U32,command: Command) -> IO(answer_type()):
  match command:
    case InventoryCommand{snapshot,start,count}:
      do IO<answer_type()>:
        page : Result<&2,&2,Inventory.Failure,Inventory.Page> <- Inventory.read(db,snapshot,start,count)
        return inventory_result(page)
    case ExportCommand{request,destination}:
      do IO<answer_type()>:
        +canonical : String <- Paths.destination(destination)
        export_canonical(filename(canonical),db,request,canonical)

def dispatch(db: U32,result: Result<&2,&2,Inventory.Failure,Command>) -> IO(answer_type()):
  match result:
    case Fail{failure}: IO.pure(answer_type(),Fail{failure})
    case Done{command}: execute(db,command)

def emit(result: answer_type()) -> IO(Unit):
  match result:
    case Done{text}: IO.print(text)
    case Fail{failure}: IO.die(Unit,2,error(failure))

# Returned request/format failures are JSON. The frozen inventory reader's
# missing/unaccepted snapshot and storage/OS integrity failures remain worker-
# fatal diagnostics; Client must reject that failed worker without parsing a
# success response. No duplicate metadata authority is introduced here.
def run(db: U32,command: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : answer_type() <- dispatch(db,parse(command,args))
    emit(result)
