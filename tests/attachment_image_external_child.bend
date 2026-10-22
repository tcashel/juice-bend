import Base
import ../src/attachment_image_worker.bend as W
import ../src/attachment_preview_external_packet.bend as P
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_asset_types.bend as T
import ../src/attachment_assets.bend as Assets
import ../src/attachment_root_policy.bend as Policy
import ../src/attachment_worker_protocol.bend as Worker
import ../src/attachment_image_types.bend as Image
import ../src/attachment_image_binding.bend as H
import ../src/attachment_image_stream.bend as Stream
import ./attachment_image_child.bend as Child
import ../src/attachment_inventory.bend as E
import ../src/attachment_capture_output.bend as Output
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/domain.bend as D
import ../src/json.bend as J
import ../src/paths.bend as Paths
import ./attachment_archive_export.bend as F
import ./png_fixtures.bend as PNG

def check(ok: Bool,label: String) -> IO(Unit): F.check(ok,label)
def byte_hash() -> String: "abe34935a44b0714231889bd0d8768c80ec1ca4a221928956c8e5f1af914f3c9"
def empty_hash() -> String: "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
def path(index: U32) -> String: "/message/content/" ++ U32.show(index) ++ "/source/path"
def image(path: String) -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":" ++ J.quote(path) ++ "}}"
def fixture(+root: String) -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[" ++ image(root ++ "/authorized/image.png") ++ "," ++ image(root ++ "/authorized/empty.png") ++ "]}}\n"
def get(+db: U32,+index: U32) -> IO(I.Resolved):
  do IO<I.Resolved>:
    result : Result<&2,&2,E.Failure,I.Resolved> <- I.resolve(db,I.Request{"1",0,index,path(index)})
    F.need(I.Resolved,result)
def initialized(value: T.answer()) -> Bool:
  match value:
    case Done{T.Initialized{}}: True{}
    case _: False{}
def receipt(value: T.answer()) -> IO(T.Receipt):
  match value:
    case Done{T.Published{receipt,False{}}}: IO.pure(T.Receipt,receipt)
    case _: IO.die(T.Receipt,1,"Expected a new synthetic owned asset")
def publish(db: U32,occurrence: I.Resolved,root: T.RootEvidence,payload: Worker.Payload) -> IO(T.Receipt):
  do IO<T.Receipt>:
    result : T.answer() <- Assets.publish(db,T.Admission{occurrence,root,"1792540800123",payload},d => evidence => Policy.validate_owned(d,evidence))
    receipt(result)
def cell(value: Sql.Cell) -> String:
  match value:
    case Sql.Cell.Null{}: "null"
    case Sql.Cell.Integer{text}: "integer:" ++ text
    case Sql.Cell.Text{text}: "text:" ++ text
    case Sql.Cell.Blob{+bytes}: "blob:" ++ U32.show(U32.from_nat(List.length(&2,U32,bytes))) ++ ":" ++ D.digest(bytes)
    case Sql.Cell.Real{text}: "real:" ++ text
def fields(values: List<&2,Sql.Cell>) -> List<&2,String>:
  match values:
    case []: []
    case value <> rest: cell(value) <> fields(rest)
def rows(values: List<&2,List<&2,Sql.Cell>>) -> List<&2,String>:
  match values:
    case []: []
    case value <> rest: T.frames(fields(value)) <> rows(rest)
def table(db: U32,sql: String) -> IO(String):
  do IO<String>:
    value : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],8)
    return T.frames(rows(value))
def state(+db: U32) -> IO(String):
  do IO<String>:
    raw : String <- table(db,"SELECT * FROM raw ORDER BY id")
    records : String <- table(db,"SELECT * FROM records ORDER BY snapshot,ordinal")
    snapshots : String <- table(db,"SELECT * FROM snapshots ORDER BY id")
    assets : String <- table(db,"SELECT * FROM attachment_assets ORDER BY snapshot,record,reference")
    chunks : String <- table(db,"SELECT * FROM attachment_asset_chunks ORDER BY snapshot,record,reference,ordinal")
    return T.frames([raw,records,snapshots,assets,chunks])
def empty_failure(value: Result<&2,&1,String,Image.Raster>) -> Bool:
  match value:
    case Fail{message}: String.starts_with(message,"unsupported_image_format:")
    case _: False{}
def refused(value: Result<&2,&1,String,Image.Raster>) -> Bool:
  match value:
    case Fail{_}: True{}
    case Done{_}: False{}
def child(+program: String,+root: String,+expected: P.External) -> IO(Result<&2,&1,String,Image.Raster>):
  do IO<Result<&2,&1,String,Image.Raster>>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,"route" <> W.arguments(root,H.ExpectedExternal{expected}),"",Stream.max_output(),W.timeout())
    W.completed(H.ExpectedExternal{expected},result)
def success(value: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = value
  check(U32.is_eq(code,0) && String.is_empty(out) && String.is_empty(err),label)
def wrong_receipt(value: T.Receipt) -> T.Receipt:
  T.Receipt{occurrence,root,_,count,chunks,digest,_} = value
  T.sealed(T.Receipt{occurrence,root,"1792540800124",count,chunks,digest,""})
def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +root : String <- Paths.destination(".build")
    +program : String <- Paths.resolve(self)
    made : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/mkdir",["-m","700",root ++ "/authorized"],"",1024,2000))
    success(made,"private synthetic authorized directory created")
    F.write_bytes(root ++ "/authorized/image.png",PNG.rgb())
    F.write_bytes(root ++ "/authorized/empty.png",[])
    +db : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    schema : T.answer() <- Assets.initialize(db)
    check(initialized(schema),"additive owned asset schema initializes in isolated library")
    policy : Result<&2,&2,E.Failure,Unit> <- Policy.initialize(db)
    _ : Unit <- F.need(Unit,policy)
    enabled : Result<&2,&2,E.Failure,T.RootEvidence> <- Policy.enable(db,None{},root ++ "/authorized")
    +evidence : T.RootEvidence <- F.need(T.RootEvidence,enabled)
    F.write_bytes(root ++ "/source.jsonl.zst",F.raw_frame(D.encode(fixture(root))))
    snapshot : String <- Capture.import_file(db,"claude",root ++ "/source.jsonl.zst")
    check(String.eq(snapshot,"1"),"external preview fixture is real archive-backed snapshot1")
    +first : I.Resolved <- get(db,0)
    +second : I.Resolved <- get(db,1)
    +saved : T.Receipt <- publish(db,first,evidence,Worker.Payload{72,byte_hash(),PNG.rgb()})
    +empty : T.Receipt <- publish(db,second,evidence,Worker.Payload{0,empty_hash(),[]})
    revoked : Result<&2,&2,E.Failure,T.RootEvidence> <- Policy.disable(db,"1")
    _ : T.RootEvidence <- F.need(T.RootEvidence,revoked)
    +before : String <- state(db)
    IO.try(Unit,Sql.close(db))
    remove : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--",root ++ "/source.jsonl.zst",root ++ "/authorized/image.png",root ++ "/authorized/empty.png"],"",1024,2000))
    success(remove,"only synthetic source files removed before fresh read child")
    +wanted : P.External = P.External{I.request(first),saved}
    png : Result<&2,&1,String,Image.Raster> <- child(program,root,wanted)
    check(Child.good(png),"fresh retained child reads exact independent PNG pixels after root disable and both original sources disappear")
    zero : Result<&2,&1,String,Image.Raster> <- child(program,root,P.External{I.request(second),empty})
    check(empty_failure(zero),"empty retained occurrence returns a bound unsupported-format reason after source loss")
    wrong : Result<&2,&1,String,Image.Raster> <- child(program,root,P.External{I.request(first),wrong_receipt(saved)})
    check(refused(wrong),"fresh child refuses a valid but different observation receipt")
    +again : U32 <- IO.try(U32,Sql.open_existing(root ++ "/juice-bend.sqlite",1))
    after : String <- state(again)
    check(String.eq(before,after),"all owned raw records snapshots associations and byte chunks remain exact after preview reads")
    Store.exec(again,"UPDATE attachment_asset_chunks SET bytes=zeroblob(n) WHERE snapshot=1 AND record=0 AND reference=0",[])
    IO.try(Unit,Sql.close(again))
    corrupt : Result<&2,&1,String,Image.Raster> <- child(program,root,wanted)
    check(refused(corrupt),"corrupt owned asset bytes produce a typed parent refusal")
    check(True{},"parent remains alive after retained-byte child refusal")
def route(valid: Bool,root: String,args: List<String>) -> IO(Unit):
  match valid:
    case True{}: W.external_root(root,args)
    case False{}: IO.die(Unit,2,"Expected isolated retained image child gate")
def argv(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> marker <> option <> root <> command <> rest:
      route(String.eq(marker,"route") && String.eq(option,"--data-dir") && String.eq(command,W.external_command()),root,rest)
    case _: IO.die(Unit,2,"Expected isolated retained image child gate")
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
