import Base
import ../../src/attachment_capture_output.bend as O
import ../../src/attachment_asset_identity.bend as I
import ../../src/attachment_asset_types.bend as T
import ../../src/attachment_assets.bend as A
import ../../src/capture.bend as Capture
import ../../src/store.bend as Store
import ../../src/sql.bend as Sql
import ../../src/json.bend as J
import ../../src/domain.bend as D
import ../attachment_asset_identity.bend as F
import ../attachment_assets.bend as AT
import ../attachment_capture_cli.bend as CT
import ../attachment_capture_command.bend as Pure

# Root-owned Mac test. This argument is the frozen trusted full application
# with the startup patch applied; no local test worker/self-dispatch exists.
def command(program: String,directory: String,command: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(program,"--data-dir" <> directory <> command <> args,"",262144,30000))
def captured(+text: String,expected: T.Receipt) -> IO(Unit):
  do IO<Unit>:
    +value : J.Json <- Pure.parsed(J.parse(text))
    F.assert(String.eq(J.get(value,"state"),"captured") && String.eq(J.get(value,"kind"),"attachment_asset"),"actual full application acknowledges a newly captured occurrence")
    wanted : String <- Pure.need(O.asset("captured",expected,None{},O.NoMutation{}))
    F.assert(String.eq(text,wanted),"new-capture CLI acknowledgement preserves every field of the verified owned receipt")
def read(value: T.answer(),bytes: List<&2,U32>) -> IO(T.Receipt):
  match value:
    case Done{T.Loaded{T.Owned{+receipt,payload}}}:
      do IO<T.Receipt>:
        F.assert(D.bytes_equal(A.bytes(payload),bytes),"actual CLI byte worker retained exact bytes")
        return receipt
    case _: IO.die(T.Receipt,1,"Expected verified retained CLI capture")
def suite(+program: String) -> IO(Unit):
  do IO<Unit>:
    +directory : String <- F.create_root()
    F.guard(directory)
    +chosen : String = directory ++ "/authorized"
    made : String <- F.command("/bin/mkdir",["-m","700",chosen])
    F.write_bytes(chosen ++ "/binary.bin",[0,1,254,255])
    F.write_bytes(chosen ++ "/empty.bin",[])
    F.write_bytes(chosen ++ "/café #?.bin",[255,0,10])
    add : U32 & (String & String) <- command(program,directory,"attachment-root-add",[chosen])
    added : String <- CT.success(add,"actual full application explicitly initializes capture storage and adds chosen root")
    CT.root(added,"1","1","true")
    +db : U32 <- Store.open(directory ++ "/juice-bend.sqlite")
    Store.write_text(directory ++ "/capture.jsonl","w",F.record(F.image(chosen ++ "/binary.bin")) ++ F.record(F.image(chosen ++ "/empty.bin")) ++
      F.record(F.image("file://localhost" ++ chosen ++ "/caf%C3%A9%20%23%3F.bin")) ++ F.record(F.image(chosen ++ "/missing.bin")))
    +snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl")
    binary : U32 & (String & String) <- command(program,directory,"capture-attachment",CT.capture_args(snapshot,"0","1","1"))
    binary_text : String <- CT.success(binary,"actual capture CLI confines binary source read to explicit root")
    binary_owned : T.answer() <- A.read(db,I.Request{snapshot,0,0,F.path(0)})
    +binary_receipt : T.Receipt <- read(binary_owned,[0,1,254,255])
    captured(binary_text,binary_receipt)
    empty : U32 & (String & String) <- command(program,directory,"capture-attachment",CT.capture_args(snapshot,"1","1","1"))
    empty_text : String <- CT.success(empty,"actual capture CLI accepts existing empty source")
    empty_owned : T.answer() <- A.read(db,I.Request{snapshot,1,0,F.path(0)})
    empty_receipt : T.Receipt <- read(empty_owned,[])
    captured(empty_text,empty_receipt)
    unicode : U32 & (String & String) <- command(program,directory,"capture-attachment",CT.capture_args(snapshot,"2","1","1"))
    unicode_text : String <- CT.success(unicode,"actual capture CLI resolves retained Unicode file URL once")
    unicode_owned : T.answer() <- A.read(db,I.Request{snapshot,2,0,F.path(0)})
    unicode_receipt : T.Receipt <- read(unicode_owned,[255,0,10])
    captured(unicode_text,unicode_receipt)
    +before : String <- AT.state(db)
    missing : U32 & (String & String) <- command(program,directory,"capture-attachment",CT.capture_args(snapshot,"3","1","1"))
    CT.failure(missing,"attachment_worker_missing","missing local source is typed without publication success")
    disabled : U32 & (String & String) <- command(program,directory,"attachment-root-disable",["1"])
    disabled_text : String <- CT.success(disabled,"actual full application disables the selected root")
    CT.root(disabled_text,"1","2","false")
    F.remove(directory ++ "/capture.jsonl")
    F.remove(chosen ++ "/binary.bin")
    F.remove(chosen ++ "/empty.bin")
    F.remove(chosen ++ "/café #?.bin")
    wanted : String <- Pure.need(O.asset("already_captured",binary_receipt,None{},O.NoMutation{}))
    reused : U32 & (String & String) <- command(program,directory,"capture-attachment",CT.capture_args(snapshot,"0","1","1"))
    CT.expected(reused,wanted,"actual capture CLI returns original receipt despite revoked revision and source loss")
    export_wanted : String <- Pure.need(O.asset("exported",binary_receipt,Some{directory ++ "/retained.bin"},O.NoMutation{}))
    exported : U32 & (String & String) <- command(program,directory,"export-captured-attachment",[snapshot,"0","0",F.path(0),directory ++ "/retained.bin"])
    CT.expected(exported,export_wanted,"actual retained export returns full original receipt after root disable")
    bytes : List<&2,U32> <- AT.read_file(directory ++ "/retained.bin")
    F.assert(D.bytes_equal(bytes,[0,1,254,255]),"full application retained export bytes exactly match captured binary")
    duplicate : U32 & (String & String) <- command(program,directory,"export-captured-attachment",[snapshot,"0","0",F.path(0),directory ++ "/retained.bin"])
    CT.failure(duplicate,"attachment_asset_export_exists","actual duplicate export does not clobber or acknowledge success")
    AT.unchanged(db,before,"missing source revocation repeated capture and export preserve immutable owned assets")
    IO.try(Unit,Sql.close(db))
    IO.print("Synthetic full-app capture CLI root: " ++ directory)
def argv(args: List<String>) -> IO(Unit):
  match args:
    case [_test,program]: suite(program)
    case _: IO.die(Unit,64,"Expected trusted full application executable argument")
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
