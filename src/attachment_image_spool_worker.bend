import Base
import ./attachment_image_worker.bend as Legacy
import ./attachment_image_binding.bend as Header
import ./attachment_image_types.bend as Image
import ./attachment_image_decode_cooperative.bend as Decode
import ./attachment_image_cancel.bend as Cancel
import ./attachment_image_spool_encode.bend as Encode
import ./attachment_image_spool_path.bend as Path
import ./attachment_image_spool_protocol.bend as Protocol
import ./attachment_image_file.bend as FileStream
import ./attachment_preview_worker.bend as InlineWorker
import ./attachment_preview_external_worker.bend as ExternalWorker
import ./attachment_preview_packet.bend as InlinePacket
import ./attachment_preview_external_packet.bend as ExternalPacket
import ./attachment_asset_identity.bend as Identity
import ./attachment_capture_output.bend as Output
import ./gui_attachments.bend as Attachments
import ./json.bend as J
import ./sql.bend as Sql

def inline_command() -> String: "attachment-preview-image-inline-spool-v1"
def external_command() -> String: "attachment-preview-image-retained-spool-v1"

def arguments(value: Header.Expected,request: Path.Request) -> List<String>:
  match value:
    case Header.ExpectedInline{InlinePacket.Expected{_,snapshot,Attachments.OccurrenceKey{record,reference,path,_,_,_,_,_,_}}}:
      Path.Request{dir,nonce,identity} = request
      ["--data-dir",dir,inline_command(),nonce,identity,snapshot,U32.show(record),U32.show(reference),path]
    case Header.ExpectedExternal{ExternalPacket.External{Identity.Request{snapshot,record,reference,path},receipt}}:
      Path.Request{dir,nonce,identity} = request
      ["--data-dir",dir,external_command(),nonce,identity,snapshot,U32.show(record),U32.show(reference),path,Output.receipt(receipt)]

def cleanup_result(cleaned: Result<&2,&2,String,Unit>,result: Result<&2,&1,String,Image.Raster>) -> Result<&2,&1,String,Image.Raster>:
  match cleaned:
    case Done{_}: result
    case Fail{_}: Fail{"The image reader finished, but its private temporary display file could not be removed."}
def cleanup(request: Path.Request,result: Result<&2,&1,String,Image.Raster>) -> IO(Result<&2,&1,String,Image.Raster>):
  do IO<Result<&2,&1,String,Image.Raster>>:
    cleaned : Result<&2,&2,String,Unit> <- Path.cleanup(request)
    return cleanup_result(cleaned,result)
def readable(+read_cancel: Chan(Unit),value: Result<&2,&2,String,Unit>,request: Path.Request,expected: Header.Expected,completion: Protocol.Completion) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{message})
    case Done{_}:
      Protocol.Completion{bytes,digest} = completion
      FileStream.read_checked(expected,Path.output(request),bytes,digest,Some{read_cancel})
def receipt(read_cancel: Chan(Unit),value: Result<&2,&2,String,Protocol.Completion>,+request: Path.Request,expected: Header.Expected) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{message}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{message})
    case Done{completion}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        valid : Result<&2,&2,String,Unit> <- Path.readable(request)
        readable(read_cancel,valid,request,expected,completion)
def successful(read_cancel: Chan(Unit),valid: Bool,+request: Path.Request,expected: Header.Expected,out: String) -> IO(Result<&2,&1,String,Image.Raster>):
  match valid:
    case False{}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"The supervised retained-image decoder failed; your capture and reader selection are unchanged."})
    case True{}:
      Path.Request{_,nonce,_} = request
      receipt(read_cancel,Protocol.parse(nonce,out),request,expected)
def completed(read_cancel: Chan(Unit),request: Path.Request,expected: Header.Expected,value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{_}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"The retained-image decoder could not complete within its bounded process limits."})
    case Done{(code,(out,error))}: successful(read_cancel,U32.is_eq(code,0) && String.is_empty(error),request,expected,out)
def watched(value: Cancel.Watched,result: Result<&2,&1,String,Image.Raster>) -> Result<&2,&1,String,Image.Raster>:
  match value:
    case Cancel.Watched{False{},True{}}: result
    case _: Fail{Cancel.error()}

def supervised(program: String,+expected: Header.Expected,+request: Path.Request,+cancel: Chan(Unit),file: File) -> IO(Result<&2,&1,String,Image.Raster>):
  do IO<Result<&2,&1,String,Image.Raster>>:
    +read_cancel : Chan(Unit) <- Chan.new(Unit,1)
    watcher : Chan(Cancel.Watched) <- IO.fork(Cancel.Watched,Cancel.watch(cancel,file,read_cancel))
    # Exact direct-child return is still the reap boundary. The watcher keeps
    # its original control handle, and must finish before any path is removed.
    child : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(program,arguments(expected,request),"",Protocol.limit(),Legacy.timeout())
    result : Result<&2,&1,String,Image.Raster> <- completed(read_cancel,request,expected,child)
    Chan.close(Unit,cancel)
    status : Cancel.Watched <- IO.join(Cancel.Watched,watcher)
    Chan.close(Unit,read_cancel)
    cleanup(request,watched(status,result))

def control_opened(value: Result<&1,&1,U32 & String,File>,program: String,expected: Header.Expected,request: Path.Request,cancel: Chan(Unit)) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{_}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        Chan.close(Unit,cancel)
        cleanup(request,Fail{"image_cancel_control_create_failed"})
    case Done{file}: supervised(program,expected,request,cancel,file)

def created(value: Result<&2,&2,String,Path.Request>,program: String,expected: Header.Expected,cancel: Chan(Unit)) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{message}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        Chan.close(Unit,cancel)
        return Fail{message}
    case Done{+request}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        opened : Result<&1,&1,U32 & String,File> <- Cancel.create(request)
        control_opened(opened,program,expected,request,cancel)

def admitted(valid: Bool,program: String,dir: String,expected: Header.Expected,cancel: Chan(Unit)) -> IO(Result<&2,&1,String,Image.Raster>):
  match valid:
    case False{}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        Chan.close(Unit,cancel)
        return Fail{"Invalid exact retained-image request or receipt"}
    case True{}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        request : Result<&2,&2,String,Path.Request> <- Path.create(dir)
        created(request,program,expected,cancel)

def read_control(program: String,dir: String,+expected: Header.Expected,cancel: Chan(Unit)) -> IO(Result<&2,&1,String,Image.Raster>):
  admitted(Legacy.expected_valid(expected),program,dir,expected,cancel)

def read(program: String,dir: String,expected: Header.Expected) -> IO(Result<&2,&1,String,Image.Raster>):
  do IO<Result<&2,&1,String,Image.Raster>>:
    cancel : Chan(Unit) <- Chan.new(Unit,1)
    read_control(program,dir,expected,cancel)

def emitted(value: Result<&2,&2,String,Encode.Receipt>,request: Path.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,2,"image_spool_write_failed")
    case Done{Encode.Receipt{bytes,digest}}:
      Path.Request{_,nonce,_} = request
      IO.write(Protocol.format(nonce,bytes,digest))
def output_empty(value: Result<&2,&2,String,Unit>,+request: Path.Request,binding: J.Json,raster: Result<&2,&1,String,Image.Raster>) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,2,"image_spool_output_authority")
    case Done{_}:
      do IO<Unit>:
        written : Result<&2,&2,String,Encode.Receipt> <- Encode.decoded_checked(Cancel.Checked{request},binding,Path.output(request),raster)
        emitted(written,request)
def output_checked(value: Result<&2,&2,String,Path.Request>,binding: J.Json,raster: Result<&2,&1,String,Image.Raster>) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,2,"image_spool_output_authority")
    case Done{+request}:
      do IO<Unit>:
        empty : Result<&2,&2,String,Unit> <- Path.empty(request)
        output_empty(empty,request,binding,raster)
def output_ready(request: Path.Request,binding: J.Json,raster: Result<&2,&1,String,Image.Raster>) -> IO(Unit):
  do IO<Unit>:
    checked : Result<&2,&2,String,Path.Request> <- Path.check(request)
    output_checked(checked,binding,raster)
def display(value: Result<&2,&2,String,Legacy.Loaded>,+request: Path.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,2,"image_spool_retained_read_failed")
    case Done{Legacy.Loaded{binding,bytes}}:
      do IO<Unit>:
        raster : Result<&2,&1,String,Image.Raster> <- Decode.decode(bytes,Cancel.Checked{request})
        output_ready(request,binding,raster)
def opened(value: Result<&1,&1,U32 & String,U32>,request: Legacy.Request,spool: Path.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,2,"image_spool_library_open_failed")
    case Done{+db}:
      do IO<Unit>:
        setup : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"PRAGMA foreign_keys=ON",[],0)
        loaded : Result<&2,&2,String,Legacy.Loaded> <- Legacy.configured(setup,db,request)
        closed : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
        display(Legacy.closed(closed,loaded),spool)
def child_open(+spool: Path.Request,request: Legacy.Request) -> IO(Unit):
  Path.Request{dir,_,_} = spool
  do IO<Unit>:
    Cancel.check(Cancel.Checked{spool})
    opening : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(dir ++ "/juice-bend.sqlite",0)
    opened(opening,request,spool)
def child_control(value: Result<&2,&2,String,Unit>,spool: Path.Request,request: Legacy.Request) -> IO(Unit):
  match value:
    case Fail{_}: IO.die(Unit,3,Cancel.error())
    case Done{_}: child_open(spool,request)

def child_checked(value: Result<&2,&2,String,Path.Request>,request: Result<&2,&2,String,Legacy.Request>) -> IO(Unit):
  match value request:
    case Done{+spool} Done{request}:
      do IO<Unit>:
        valid : Result<&2,&2,String,Unit> <- Cancel.readable(spool)
        child_control(valid,spool,request)
    case _ _: IO.die(Unit,2,"image_spool_invalid_request")
def child_valid(valid: Bool,spool: Path.Request,request: Result<&2,&2,String,Legacy.Request>) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,2,"image_spool_invalid_request")
    case True{}:
      do IO<Unit>:
        checked : Result<&2,&2,String,Path.Request> <- Path.check(spool)
        child_checked(checked,request)
def parse_request(external: Bool,args: List<String>) -> Result<&2,&2,String,Legacy.Request>:
  match external:
    case True{}: Legacy.parsed_external(ExternalWorker.parse(args))
    case False{}: Legacy.parsed_inline(InlineWorker.parse(args))
def root(dir: String,args: List<String>,external: Bool) -> IO(Unit):
  match args:
    case nonce <> +identity <> rest:
      child_valid(Bool.not(String.is_empty(identity)),Path.Request{dir,nonce,identity},
        parse_request(external,rest))
    case _: IO.die(Unit,2,"image_spool_invalid_request")
def inline_root(dir: String,args: List<String>) -> IO(Unit): root(dir,args,False{})
def external_root(dir: String,args: List<String>) -> IO(Unit): root(dir,args,True{})
