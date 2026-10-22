import Base
import ../src/attachment_assets.bend as A
import ../src/attachment_asset_types.bend as T
import ../src/attachment_asset_identity.bend as Identity
import ../src/attachment_root_policy.bend as Policy
import ../src/attachment_worker_protocol.bend as Worker
import ../src/attachment_inventory.bend as Inventory
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ../src/paths.bend as Paths
import ./attachment_asset_identity.bend as Fixture
import ./attachment_assets.bend as Tests

def value(occurrence: Identity.Resolved,root: T.RootEvidence) -> T.Admission:
  T.Admission{occurrence,root,"1792540800123",Worker.Payload{4,"c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4",[0,1,254,255]}}

def enabled(+db: U32,path: String) -> IO(T.RootEvidence):
  do IO<T.RootEvidence>:
    result : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- Policy.enable(db,None{},path)
    Fixture.need(T.RootEvidence,result)

def disabled(db: U32) -> IO(T.RootEvidence):
  do IO<T.RootEvidence>:
    result : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- Policy.disable(db,"1")
    Fixture.need(T.RootEvidence,result)

def root_state(value: T.RootEvidence,directory: String,revision: String,enabled: Bool) -> Bool:
  T.RootEvidence{id,path,actual,flag} = value
  String.eq(id,"1") && String.eq(path,directory ++ "/authorized") && String.eq(actual,revision) &&
    U32.is_eq(Bool.to_u32(flag),Bool.to_u32(enabled))

def sink(value: T.answer(),expected: String) -> Bool:
  match value:
    case Done{T.Exported{receipt,path}}: T.receipt_valid(receipt) && String.eq(path,expected)
    case _: False{}

def child_verify(+directory: String) -> IO(Unit):
  do IO<Unit>:
    Fixture.guard(directory)
    +db : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",0))
    Store.exec(db,"PRAGMA foreign_keys=ON",[])
    current_result : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- Policy.read(db,"1")
    current : T.RootEvidence <- Fixture.need(T.RootEvidence,current_result)
    Fixture.assert(root_state(current,directory,"4",False{}),"new process sees authoritative disabled revision4")
    +occurrence : Identity.Resolved <- Fixture.get(db,"1",0,0,Fixture.path(0))
    +expected : T.Receipt = T.receipt(value(occurrence,T.RootEvidence{"1",directory ++ "/authorized","3",True{}}))
    loaded : T.answer() <- A.read(db,Identity.request(occurrence))
    Fixture.assert(Tests.loaded(loaded,expected,[0,1,254,255]),"immutable asset keeps accepted revision3 after current root revision4 disable")
    exported : T.answer() <- A.export(db,Identity.request(occurrence),directory ++ "/./policy-copy.bin")
    Fixture.assert(sink(exported,directory ++ "/policy-copy.bin"),"export acknowledgement identifies actual canonical destination through alias parent")
    bytes : List<&2,U32> <- Tests.read_file(directory ++ "/policy-copy.bin")
    Fixture.assert(D.bytes_equal(bytes,[0,1,254,255]),"source loss plus real-policy disable preserves exact owned binary bytes")
    IO.try(Unit,Sql.close(db))
    IO.print("POLICY EXPORT COMPLETE")

def child_result(value: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = value
  Fixture.assert(U32.is_eq(code,0) && String.eq(err,"") && String.contains(out,"POLICY EXPORT COMPLETE"),
    "fresh process read and export succeed after actual policy revoke and source removal")

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    +directory : String <- Fixture.create_root()
    Fixture.guard(directory)
    made : String <- Fixture.command("/bin/mkdir",["-m","700",directory ++ "/authorized"])
    Fixture.write_bytes(directory ++ "/authorized/photo.bin",[0,1,254,255])
    +program : String <- Paths.resolve(self)
    +db : U32 <- Store.open(directory ++ "/library.sqlite")
    initialized : T.answer() <- A.initialize(db)
    Fixture.assert(Tests.initialized(initialized),"asset additive schema initialized in synthetic library")
    policy_result : Result<&2,&2,Inventory.Failure,Unit> <- Policy.initialize(db)
    policy_initialized : Unit <- Fixture.need(Unit,policy_result)
    +original : T.RootEvidence <- enabled(db,directory ++ "/authorized")
    Fixture.assert(root_state(original,directory,"1",True{}),"real policy explicitly enables canonical synthetic root revision1")
    Store.write_text(directory ++ "/capture.jsonl","w",Fixture.record(Fixture.image(directory ++ "/authorized/photo.bin")))
    snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl")
    +occurrence : Identity.Resolved <- Fixture.get(db,snapshot,0,0,Fixture.path(0))
    +observed_before_revoke : T.Admission = value(occurrence,original)
    +before : String <- Tests.state(db)
    revoked : T.RootEvidence <- disabled(db)
    Fixture.assert(root_state(revoked,directory,"2",False{}),"real root revocation commits before worker-result publication")
    refused : T.answer() <- A.publish(db,observed_before_revoke,d => root => Policy.validate_owned(d,root))
    Fixture.assert(Tests.failed(refused,"attachment_root_revoked"),"same-transaction authoritative callback rejects bytes observed under revoked revision1")
    Tests.unchanged(db,before,"real-policy refusal leaves all asset tables exact")
    +current : T.RootEvidence <- enabled(db,directory ++ "/authorized")
    Fixture.assert(root_state(current,directory,"3",True{}),"explicit re-enable creates new policy revision3")
    stale : T.answer() <- A.publish(db,observed_before_revoke,d => root => Policy.validate_owned(d,root))
    Fixture.assert(Tests.failed(stale,"attachment_root_revoked"),"re-enabled root never accepts stale revision1 authorization")
    Tests.unchanged(db,before,"stale-revision refusal cannot insert immutable asset association")
    published : T.answer() <- A.publish(db,value(occurrence,current),d => root => Policy.validate_owned(d,root))
    +accepted : T.Receipt <- Tests.receipt(published,False{})
    +saved : String <- Tests.state(db)
    later : T.RootEvidence <- disabled(db)
    Fixture.assert(root_state(later,directory,"4",False{}),"accepted bytes survive subsequent real root disable")
    retry : T.answer() <- A.publish(db,value(occurrence,current),d => root => Policy.validate_owned(d,root))
    Fixture.assert(Tests.failed(retry,"attachment_root_revoked"),"exact retry also invokes current authoritative policy validator")
    Tests.unchanged(db,saved,"retry refusal preserves original accepted observation receipt and chunks")
    Fixture.remove(directory ++ "/capture.jsonl")
    Fixture.remove(directory ++ "/authorized/photo.bin")
    read : T.answer() <- A.read(db,Identity.request(occurrence))
    Fixture.assert(Tests.loaded(read,accepted,[0,1,254,255]),"owned read is independent of currently disabled root and missing external file")
    IO.try(Unit,Sql.close(db))
    child : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,["verify",directory],"",16384,30000))
    child_result(child)
    +reopened : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",0))
    Store.exec(reopened,"PRAGMA foreign_keys=ON",[])
    Tests.unchanged(reopened,saved,"real-policy source-loss export leaves all owned asset tables exact")
    IO.try(Unit,Sql.close(reopened))
    IO.print("Synthetic real-policy asset root: " ++ directory)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "verify" <> root <> []: child_verify(root)
    case _: IO.die(Unit,2,"Invalid synthetic asset policy test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
