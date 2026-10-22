import Base
import ./attachment_preview_external_packet.bend as Packet
import ./attachment_preview_packet.bend as Wire
import ./attachment_preview_worker.bend as InlineWorker
import ./attachment_asset_identity.bend as I
import ./attachment_asset_types.bend as T
import ./attachment_assets.bend as Assets
import ./attachment_capture_command.bend as Command
import ./attachment_capture_output.bend as Output
import ./attachment_capture_ack.bend as Ack
import ./attachment_inventory.bend as Inventory
import ./attachment_decode.bend as Decode
import ./attachment_refs.bend as Ref
import ./json.bend as J
import ./sql.bend as Sql

# A separate same-app, existing-library read-only route. The receipt describes
# immutable accepted bytes, not permission to read an original external file.
def command() -> String: "attachment-preview-retained-v1"
def input_limit() -> U32: 65536

def identity(value: Command.result()) -> Result<&2,&2,String,I.Request>:
  match value:
    case Done{Command.Inspect{request}}: Done{request}
    case _: Fail{"Invalid exact retained-image occurrence request"}

def parsed(snapshot: String,record: String,reference: String,path: String,+metadata: String) -> Result<&2,&2,String,Packet.External>:
  do Result<&2,&2,String,Packet.External>:
    _ : Unit <- Wire.guard(Ref.bounded(metadata,input_limit()),"Retained-image receipt exceeds its metadata limit")
    request : I.Request <- identity(Command.parse("captured-attachment",[snapshot,record,reference,path]))
    json : J.Json <- J.parse(metadata)
    receipt : T.Receipt <- Ack.receipt(json)
    +expected : Packet.External = Packet.External{request,receipt}
    _ : Unit <- Wire.guard(Packet.expected_valid(expected),"Retained-image request does not match its complete receipt")
    return expected

def parse(args: List<String>) -> Result<&2,&2,String,Packet.External>:
  match args:
    case snapshot <> record <> reference <> path <> metadata <> []:
      parsed(snapshot,record,reference,path,metadata)
    case _: Fail{"Invalid exact retained-image argument count"}

def loaded(expected: Packet.External,value: T.answer()) -> Result<&2,&2,String,String>:
  match value:
    case Done{T.Loaded{owned}}: Packet.encode(expected,owned)
    case Fail{Inventory.Failure{_,message}}: Fail{message}
    case _: Fail{"Retained-image reader did not return verified owned bytes"}

def execute(db: U32,expected: Result<&2,&2,String,Packet.External>) -> IO(Result<&2,&2,String,String>):
  match expected:
    case Fail{message}: IO.pure(Result<&2,&2,String,String>,Fail{message})
    case Done{+expected}:
      do IO<Result<&2,&2,String,String>>:
        value : T.answer() <- Assets.read(db,Packet.request(expected))
        return loaded(expected,value)

def emit(value: Result<&2,&2,String,String>) -> IO(Unit):
  match value:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{text}: IO.write(text)

# Foreign-key enforcement is a connection setting, not a schema/data mutation.
# Assets.read validates it on every owned transaction; preserve that invariant
# on this fresh READONLY handle instead of weakening the schema validator.
def configured(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,db: U32,expected: Packet.External) -> IO(Result<&2,&2,String,String>):
  match result:
    case Done{[]}: execute(db,Done{expected})
    case _: IO.pure(Result<&2,&2,String,String>,Fail{"Cannot configure the retained-image read-only connection"})

def opened(result: Result<&1,&1,U32 & String,U32>,expected: Packet.External) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,2,"Cannot open the existing selected retained-image library")
    case Done{+db}:
      do IO<Unit>:
        setup : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"PRAGMA foreign_keys=ON",[],0)
        value : Result<&2,&2,String,String> <- configured(setup,db,expected)
        result : Result<&1,&1,U32 & String,Unit> <- Sql.close(db)
        emit(InlineWorker.closed(result,value))

def root_valid(valid: Bool,dir: String,expected: Result<&2,&2,String,Packet.External>) -> IO(Unit):
  match valid expected:
    case True{} Done{expected}:
      do IO<Unit>:
        result : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(dir ++ "/juice-bend.sqlite",0)
        opened(result,expected)
    case _ _: IO.die(Unit,2,"Invalid explicit retained-image library or occurrence receipt")

def root(+dir: String,args: List<String>) -> IO(Unit):
  root_valid(String.starts_with(dir,"/") && Ref.bounded(dir,4000),dir,parse(args))

def arguments(dir: String,value: Packet.External,metadata: String) -> List<String>:
  Packet.External{I.Request{snapshot,record,reference,path},_} = value
  ["--data-dir",dir,command(),snapshot,U32.show(record),U32.show(reference),path,metadata]

def output_ok(valid: Bool,expected: Packet.External,out: String) -> Result<&2,&2,String,Decode.Bytes>:
  match valid:
    case False{}: Fail{"The retained-byte reader failed. The capture and reader selection are unchanged."}
    case True{}: Packet.verify(expected,out)

def completed(expected: Packet.External,result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,String,Decode.Bytes>:
  match result:
    case Fail{_}: Fail{"The retained-byte reader could not complete within its process limits."}
    case Done{(code,(out,error))}: output_ok(U32.is_eq(code,0) && String.is_empty(error),expected,out)

def admitted(valid: Bool,program: String,dir: String,+expected: Packet.External,metadata: String) -> IO(Result<&2,&2,String,Decode.Bytes>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Decode.Bytes>,Fail{"Retained-image request exceeds its exact metadata contract"})
    case True{}:
      do IO<Result<&2,&2,String,Decode.Bytes>>:
        value : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run(program,arguments(dir,expected,metadata),"",Wire.max_output(),60000)
        return completed(expected,value)

def bounded(program: String,dir: String,+expected: Packet.External,+metadata: String) -> IO(Result<&2,&2,String,Decode.Bytes>):
  admitted(Ref.bounded(metadata,input_limit()),program,dir,expected,metadata)

def valid(valid: Bool,program: String,dir: String,+expected: Packet.External) -> IO(Result<&2,&2,String,Decode.Bytes>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,String,Decode.Bytes>,Fail{"Invalid retained-image identity or receipt"})
    case True{}: bounded(program,dir,expected,Output.receipt(Packet.receipt(expected)))

def read(program: String,dir: String,+expected: Packet.External) -> IO(Result<&2,&2,String,Decode.Bytes>):
  valid(Packet.expected_valid(expected),program,dir,expected)
