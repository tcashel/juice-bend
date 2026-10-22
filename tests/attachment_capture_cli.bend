import Base
import ../src/attachment_capture_cli.bend as C
import ../src/attachment_capture_output.bend as O
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_asset_types.bend as T
import ../src/attachment_assets.bend as A
import ../src/attachment_root_policy.bend as P
import ../src/attachment_root_schema.bend as S
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as J
import ../src/domain.bend as D
import ../src/paths.bend as Paths
import ./attachment_asset_identity.bend as F
import ./attachment_assets.bend as AT
import ./attachment_capture_command.bend as Pure

def child(self: String,directory: String,command: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"route" <> directory <> command <> args,"",262144,30000))
def success_parts(code: U32,+out: String,err: String,label: String) -> IO(String):
  do IO<String>:
    F.assert(U32.is_eq(code,0) && String.is_empty(err) && String.ends_with(out,"\n") &&
      Bool.not(String.contains(String.take(out,Nat.sub(String.length(out),1n)),"\n")),label)
    return String.take(out,Nat.sub(String.length(out),1n))
def success(value: U32 & (String & String),label: String) -> IO(String):
  (code,(out,err)) = value
  success_parts(code,out,err,label)
def expected(value: U32 & (String & String),text: String,label: String) -> IO(Unit):
  (code,(out,err)) = value
  F.assert(U32.is_eq(code,0) && String.eq(out,text ++ "\n") && String.is_empty(err),label)
def failure_parts(status: U32,out: String,+err: String,code: String,label: String) -> IO(Unit):
  F.assert(U32.is_eq(status,2) && String.is_empty(out) && String.contains(err,"\"kind\":\"attachment_capture_error\"") &&
    String.contains(err,"\"code\":\"" ++ code ++ "\""),label)
def failure(value: U32 & (String & String),code: String,label: String) -> IO(Unit):
  (status,(out,err)) = value
  failure_parts(status,out,err,code,label)
def root(text: String,id: String,revision: String,enabled: String) -> IO(Unit):
  do IO<Unit>:
    +value : J.Json <- Pure.parsed(J.parse(text))
    +root : J.Json = J.field(value,"root")
    F.assert(String.eq(J.get(value,"kind"),"attachment_root") && String.eq(J.get(root,"id"),id) &&
      String.eq(J.get(root,"revision"),revision) && String.eq(J.get(root,"enabled"),enabled),"root acknowledgement reports exact identity revision and enabled state")
def page_rows(value: J.Json,first: String) -> Bool:
  match value:
    case J.JArray{[]}: String.is_empty(first)
    case J.JArray{[root]}: String.eq(J.get(root,"id"),first)
    case _: False{}
def page_value(value: J.Json,first: String,next: String) -> Bool:
  match value:
    case J.JObject{fields}:
      +object : J.Json = J.JObject{fields}
      page_rows(J.field(object,"roots"),first) && String.eq(J.get(object,"next"),next)
    case _: False{}
def page(text: String,first: String,next: String) -> IO(Unit):
  do IO<Unit>:
    value : J.Json <- Pure.parsed(J.parse(text))
    F.assert(page_value(value,first,next),"root page is explicit exact and complete for its returned cursor range")
def seed(+db: U32,occurrence: I.Resolved,root: T.RootEvidence,bytes: List<&2,U32>) -> IO(T.Receipt):
  do IO<T.Receipt>:
    value : T.answer() <- A.publish(db,T.Admission{occurrence,root,"9007199254740993",AT.payload(bytes)},d => r => P.validate_owned(d,r))
    AT.receipt(value,False{})
def args(snapshot: String,record: String) -> List<String>:
  [snapshot,record,"0",F.path(0)]
def capture_args(snapshot: String,record: String,root: String,revision: String) -> List<String>:
  [snapshot,record,"0",F.path(0),root,revision]
def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +directory : String <- F.create_root()
    F.guard(directory)
    +chosen : String = directory ++ "/approved"
    +second : String = directory ++ "/other-approved"
    made : String <- F.command("/bin/mkdir",["-m","700",chosen,second])
    F.write_bytes(chosen ++ "/binary.bin",[0,1,254,255])
    F.write_bytes(chosen ++ "/empty.bin",[])
    +db : U32 <- Store.open(directory ++ "/library.sqlite")
    C.initialize(db)
    empty : U32 & (String & String) <- child(self,directory,"attachment-roots",["0","1"])
    empty_text : String <- success(empty,"real root list emits bounded JSON for initialized empty library")
    page(empty_text,"","")
    added : U32 & (String & String) <- child(self,directory,"attachment-root-add",[chosen])
    added_text : String <- success(added,"real root add accepts only explicitly chosen canonical directory")
    root(added_text,"1","1","true")
    second_value : U32 & (String & String) <- child(self,directory,"attachment-root-add",[second])
    second_text : String <- success(second_value,"second explicitly approved directory receives its own root identity")
    root(second_text,"2","1","true")
    first_page : U32 & (String & String) <- child(self,directory,"attachment-roots",["0","1"])
    first_text : String <- success(first_page,"real root pagination emits only requested first root")
    page(first_text,"1","1")
    last_page : U32 & (String & String) <- child(self,directory,"attachment-roots",["1","1"])
    last_text : String <- success(last_page,"real root pagination resumes after exact signed64 cursor")
    page(last_text,"2","")
    Store.write_text(directory ++ "/capture.jsonl","w",F.record(F.image(chosen ++ "/binary.bin")) ++ F.record(F.image(chosen ++ "/uncaptured.bin")) ++
      F.record(F.image(chosen ++ "/empty.bin")) ++ F.record(F.image("https://example.invalid/never-fetch")))
    +snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl")
    +occurrence : I.Resolved <- F.get(db,snapshot,0,0,F.path(0))
    empty_occurrence : I.Resolved <- F.get(db,snapshot,2,0,F.path(0))
    root_value : S.result(T.RootEvidence) <- P.read(db,"1")
    +root_evidence : T.RootEvidence <- F.need(T.RootEvidence,root_value)
    +receipt : T.Receipt <- seed(db,occurrence,root_evidence,[0,1,254,255])
    +empty_receipt : T.Receipt <- seed(db,empty_occurrence,root_evidence,[])
    +before : String <- AT.state(db)
    disabled : U32 & (String & String) <- child(self,directory,"attachment-root-disable",["1"])
    disabled_text : String <- success(disabled,"explicit disable revokes future byte admission")
    root(disabled_text,"1","2","false")
    wanted_existing : String <- Pure.need(O.asset("already_captured",receipt,None{},O.NoMutation{}))
    reused : U32 & (String & String) <- child(self,directory,"capture-attachment",capture_args(snapshot,"0","1","1"))
    expected(reused,wanted_existing,"capture command returns entire original receipt after selected root revision was disabled")
    revoked : U32 & (String & String) <- child(self,directory,"capture-attachment",capture_args(snapshot,"1","1","1"))
    failure(revoked,"attachment_root_revoked","uncaptured local reference cannot read under a disabled selected root")
    unknown : U32 & (String & String) <- child(self,directory,"capture-attachment",capture_args(snapshot,"1","99","1"))
    failure(unknown,"attachment_root_missing","unknown explicit root remains distinct from revoked root")
    absent : U32 & (String & String) <- child(self,directory,"captured-attachment",args(snapshot,"1"))
    failure(absent,"attachment_asset_not_captured","uncaptured inspection is typed and never triggers a worker")
    remote : U32 & (String & String) <- child(self,directory,"capture-attachment",capture_args(snapshot,"3","1","1"))
    failure(remote,"attachment_not_supported_local","remote retained reference is refused before root lookup or byte worker")
    mismatch : U32 & (String & String) <- child(self,directory,"captured-attachment",[snapshot,"0","0","/wrong"])
    failure(mismatch,"attachment_occurrence_path_mismatch","retained inspection cannot substitute a structural occurrence path")
    enabled : U32 & (String & String) <- child(self,directory,"attachment-root-enable",["1"])
    enabled_text : String <- success(enabled,"enable uses root's retained path rather than a caller replacement")
    root(enabled_text,"1","3","true")
    stale : U32 & (String & String) <- child(self,directory,"capture-attachment",capture_args(snapshot,"1","1","1"))
    failure(stale,"attachment_root_revoked","re-enabled root does not revive stale selected revision")
    disabled_again : U32 & (String & String) <- child(self,directory,"attachment-root-disable",["1"])
    disabled_again_text : String <- success(disabled_again,"second disable keeps explicit revision history")
    root(disabled_again_text,"1","4","false")
    F.remove(directory ++ "/capture.jsonl")
    F.remove(chosen ++ "/binary.bin")
    F.remove(chosen ++ "/empty.bin")
    wanted_read : String <- Pure.need(O.asset("retained",receipt,None{},O.NoMutation{}))
    retained : U32 & (String & String) <- child(self,directory,"captured-attachment",args(snapshot,"0"))
    expected(retained,wanted_read,"retained inspection survives provider and external source deletion with original metadata")
    wanted_empty : String <- Pure.need(O.asset("retained",empty_receipt,None{},O.NoMutation{}))
    empty_asset : U32 & (String & String) <- child(self,directory,"captured-attachment",args(snapshot,"2"))
    expected(empty_asset,wanted_empty,"zero-byte retained asset remains a successful exact receipt rather than missing state")
    wanted_export : String <- Pure.need(O.asset("exported",receipt,Some{directory ++ "/chosen.bin"},O.NoMutation{}))
    exported : U32 & (String & String) <- child(self,directory,"export-captured-attachment",[snapshot,"0","0",F.path(0),directory ++ "/chosen.bin"])
    expected(exported,wanted_export,"retained export acknowledges exact original receipt and chosen destination after disable")
    bytes : List<&2,U32> <- AT.read_file(directory ++ "/chosen.bin")
    F.assert(D.bytes_equal(bytes,[0,1,254,255]),"retained CLI export is exact binary bytes")
    no_clobber : U32 & (String & String) <- child(self,directory,"export-captured-attachment",[snapshot,"0","0",F.path(0),directory ++ "/chosen.bin"])
    failure(no_clobber,"attachment_asset_export_exists","retained CLI export refuses existing destination without success")
    same : List<&2,U32> <- AT.read_file(directory ++ "/chosen.bin")
    F.assert(D.bytes_equal(same,[0,1,254,255]),"failed duplicate export preserves the existing chosen file")
    bad : U32 & (String & String) <- child(self,directory,"secret-unknown-command",[])
    failure(bad,"attachment_capture_usage","unknown command is bounded typed failure with no stdout success")
    AT.unchanged(db,before,"root and read/export commands never alter retained asset or capture tables")
    IO.try(Unit,Sql.close(db))
    IO.print("Synthetic capture CLI root: " ++ directory)
def route(+directory: String,program: String,command: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    Store.checked(F.root_valid(directory),"Only owned synthetic child directory accepted")
    canonical : String <- Paths.resolve(directory)
    Store.checked(String.eq(directory,canonical),"Synthetic child directory must be canonical")
    file : File <- IO.try(File,File.open(directory ++ "/owned-test","r"))
    got : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,64)
    marker : List<&2,U32> <- F.read_closed(got)
    Store.checked(D.bytes_equal(marker,D.encode("attachment-asset-identity-v1\n")),"Synthetic child marker must match")
    +db : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",1))
    Store.exec(db,"PRAGMA foreign_keys=ON",[])
    C.run(program,db,command,args)
    IO.try(Unit,Sql.close(db))
def argv(args: List<String>) -> IO(Unit):
  match args:
    case [self]: suite(self)
    case self <> "route" <> directory <> command <> rest: route(directory,self,command,rest)
    case _: IO.die(Unit,64,"Invalid synthetic capture CLI arguments")
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
