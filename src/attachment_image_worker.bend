import Base
import ./attachment_image_binding.bend as Header
import ./attachment_image_stream.bend as Stream
import ./attachment_image_encode.bend as Encode
import ./attachment_image_types.bend as Image
import ./attachment_preview_worker.bend as InlineWorker
import ./attachment_preview_external_worker.bend as ExternalWorker
import ./attachment_preview_packet.bend as InlinePacket
import ./attachment_preview_external_packet.bend as ExternalPacket
import ./attachment_inline.bend as Inline
import ./attachment_assets.bend as Assets
import ./attachment_asset_types.bend as Asset
import ./attachment_asset_identity.bend as Identity
import ./attachment_inventory.bend as Inventory
import ./attachment_capture_output.bend as Output
import ./attachment_decode.bend as Bytes
import ./attachment_refs.bend as Ref
import ./gui_attachments.bend as Attachments
import ./json.bend as J
import ./sql.bend as Sql

# Fresh explicit existing-library routes. The child verifies retained evidence,
# closes SQLite, then decodes/serializes in its own process. No source-file or
# URL authority, application initialization, original-byte export, or write API.
def inline_command() -> String: "attachment-preview-image-inline-v1"
def external_command() -> String: "attachment-preview-image-retained-v1"
def timeout() -> U32: 120000

type Request is Data:
  ReadInline{request: Inline.Request}
  ReadExternal{expected: ExternalPacket.External}
type Loaded is Data:
  Loaded{binding: J.Json,bytes: List<&2,U32>}

def inline_bytes(binding: J.Json,value: Bytes.Bytes) -> Loaded:
  Bytes.Bytes{bytes,_,_} = value
  Loaded{binding,bytes}

def inline_loaded(value: Result<&2,&2,Inventory.Failure,Inline.Resolved>) -> Result<&2,&2,String,Loaded>:
  match value:
    case Fail{Inventory.Failure{_,message}}: Fail{message}
    case Done{+value}:
      do Result<&2,&2,String,Loaded>:
        binding : J.Json <- Header.inline(value)
        Done{inline_bytes(binding,InlinePacket.resolved_data(value))}

def external_loaded(expected: ExternalPacket.External,value: Asset.answer()) -> Result<&2,&2,String,Loaded>:
  match value:
    case Fail{Inventory.Failure{_,message}}: Fail{message}
    case Done{Asset.Loaded{+owned}}:
      do Result<&2,&2,String,Loaded>:
        binding : J.Json <- Header.external(expected,owned)
        Done{Loaded{binding,ExternalPacket.owned_bytes(owned)}}
    case _: Fail{"Retained-image reader did not return verified owned bytes"}

def load(db: U32,request: Request) -> IO(Result<&2,&2,String,Loaded>):
  match request:
    case ReadInline{request}:
      do IO<Result<&2,&2,String,Loaded>>:
        value : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.resolve(db,request)
        return inline_loaded(value)
    case ReadExternal{+expected}:
      do IO<Result<&2,&2,String,Loaded>>:
        value : Asset.answer() <- Assets.read(db,ExternalPacket.request(expected))
        return external_loaded(expected,value)

def configured(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,db: U32,request: Request) -> IO(Result<&2,&2,String,Loaded>):
  match result:
    case Done{[]}: load(db,request)
    case _: IO.pure(Result<&2,&2,String,Loaded>,Fail{"Cannot configure the retained-image read-only connection"})

def closed(result: Result<&1,&1,U32 & String,Unit>,prior: Result<&2,&2,String,Loaded>) -> Result<&2,&2,String,Loaded>:
  match result:
    case Done{_}: prior
    case Fail{_}: Fail{"The retained-image database did not close cleanly"}

def emit(value: Result<&2,&2,String,String>) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{text}: IO.write(text)

def display(value: Result<&2,&2,String,Loaded>) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{Loaded{binding,bytes}}: emit(Encode.encode(binding,bytes))

def opened(result: Result<&1,&1,U32 & String,U32>,request: Request) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,2,"Cannot open the existing selected retained-image library")
    case Done{+db}:
      do IO<Unit>:
        setup : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"PRAGMA foreign_keys=ON",[],0)
        value : Result<&2,&2,String,Loaded> <- configured(setup,db,request)
        result : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
        display(closed(result,value))

def root_valid(valid: Bool,dir: String,request: Result<&2,&2,String,Request>) -> IO(Unit):
  match valid request:
    case True{} Done{request}:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(dir ++ "/juice-bend.sqlite",0)
        opened(result,request)
    case _ _: IO.die(Unit,2,"Invalid explicit image library or exact occurrence request")

def parsed_inline(value: Result<&2,&2,String,Inline.Request>) -> Result<&2,&2,String,Request>:
  match value:
    case Fail{message}: Fail{message}
    case Done{request}: Done{ReadInline{request}}

def parsed_external(value: Result<&2,&2,String,ExternalPacket.External>) -> Result<&2,&2,String,Request>:
  match value:
    case Fail{message}: Fail{message}
    case Done{expected}: Done{ReadExternal{expected}}

def inline_root(+dir: String,args: List<String>) -> IO(Unit):
  root_valid(String.starts_with(dir,"/") && Ref.bounded(dir,4000),dir,parsed_inline(InlineWorker.parse(args)))

def external_root(+dir: String,args: List<String>) -> IO(Unit):
  root_valid(String.starts_with(dir,"/") && Ref.bounded(dir,4000),dir,parsed_external(ExternalWorker.parse(args)))

def arguments(dir: String,value: Header.Expected) -> List<String>:
  match value:
    case Header.ExpectedInline{InlinePacket.Expected{_,snapshot,Attachments.OccurrenceKey{record,reference,path,_,_,_,_,_,_}}}:
      ["--data-dir",dir,inline_command(),snapshot,U32.show(record),U32.show(reference),path]
    case Header.ExpectedExternal{ExternalPacket.External{Identity.Request{snapshot,record,reference,path},receipt}}:
      ["--data-dir",dir,external_command(),snapshot,U32.show(record),U32.show(reference),path,Output.receipt(receipt)]

def successful(valid: Bool,expected: Header.Expected,out: String) -> IO(Result<&2,&1,String,Image.Raster>):
  match valid:
    case False{}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"The supervised retained-image decoder failed; your capture and reader selection are unchanged."})
    case True{}: Stream.read(expected,out)

def completed(expected: Header.Expected,value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Result<&2,&1,String,Image.Raster>):
  match value:
    case Fail{_}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"The retained-image decoder could not complete within its bounded process limits."})
    case Done{(code,(out,error))}: successful(U32.is_eq(code,0) && String.is_empty(error),expected,out)

def admitted(valid: Bool,program: String,dir: String,+expected: Header.Expected) -> IO(Result<&2,&1,String,Image.Raster>):
  match valid:
    case False{}: IO.pure(Result<&2,&1,String,Image.Raster>,Fail{"Invalid exact retained-image request or receipt"})
    case True{}:
      do IO<Result<&2,&1,String,Image.Raster>>:
        value : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run(program,arguments(dir,expected),"",Stream.max_output(),timeout())
        completed(expected,value)

def expected_valid(value: Header.Expected) -> Bool:
  match value:
    case Header.ExpectedInline{expected}: InlinePacket.expected_valid(expected)
    case Header.ExpectedExternal{+expected}:
      ExternalPacket.expected_valid(expected) && Ref.bounded(Output.receipt(ExternalPacket.receipt(expected)),65536)

def read(program: String,dir: String,+expected: Header.Expected) -> IO(Result<&2,&1,String,Image.Raster>):
  admitted(expected_valid(expected),program,dir,expected)
