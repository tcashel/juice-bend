import Base
import ../../src/attachment_capture.bend as C
import ../../src/attachment_asset_identity.bend as I
import ../../src/attachment_asset_types.bend as T
import ../../src/attachment_assets.bend as A
import ../../src/attachment_root_policy.bend as P
import ../../src/attachment_inventory.bend as Inventory
import ../../src/capture.bend as Capture
import ../../src/store.bend as Store
import ../../src/sql.bend as Sql
import ../../src/domain.bend as D
import ../attachment_asset_identity.bend as F
import ../attachment_assets.bend as AT
import ../attachment_capture.bend as CT

# Root-owned Mac gate. The argument is the frozen, trusted full application's
# executable; this test does not implement its own worker or dispatch shortcut.
def suite(program: String) -> IO(Unit):
  do IO<Unit>:
    +directory : String <- F.create_root()
    F.guard(directory)
    +root : String = directory ++ "/authorized"
    made : String <- F.command("/bin/mkdir",["-m","700",root])
    F.write_bytes(root ++ "/binary.bin",[0,1,254,255])
    F.write_bytes(root ++ "/empty.bin",[])
    F.write_bytes(root ++ "/café #?.bin",[255,0,10])
    +db : U32 <- Store.open(directory ++ "/library.sqlite")
    assets : T.answer() <- A.initialize(db)
    F.assert(AT.initialized(assets),"native fixture explicitly initializes owned asset storage")
    initialized : Result<&2,&2,Inventory.Failure,Unit> <- P.initialize(db)
    done : Unit <- F.need(Unit,initialized)
    +chosen : T.RootEvidence <- CT.enabled(db,root)
    Store.write_text(directory ++ "/capture.jsonl","w",F.record(F.image(root ++ "/binary.bin")) ++
      F.record(F.image(root ++ "/empty.bin")) ++ F.record(F.image("file://localhost" ++ root ++ "/caf%C3%A9%20%23%3F.bin")) ++
      F.record(F.image(root ++ "/missing.bin")))
    +snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl")
    +binary : I.Resolved <- F.get(db,snapshot,0,0,F.path(0))
    +empty : I.Resolved <- F.get(db,snapshot,1,0,F.path(0))
    +unicode : I.Resolved <- F.get(db,snapshot,2,0,F.path(0))
    missing : I.Resolved <- F.get(db,snapshot,3,0,F.path(0))
    created : Result<&2,&2,C.Failure,C.Coordinator> <- C.create(program)
    +coordinator : C.Coordinator <- CT.need(created)
    first : C.result() <- C.run(coordinator,db,C.Request{binary,chosen})
    +binary_receipt : T.Receipt <- CT.receipt(first,False{})
    binary_read : T.answer() <- A.read(db,I.request(binary))
    F.assert(AT.loaded(binary_read,binary_receipt,[0,1,254,255]),"actual confined full-app worker publishes exact binary bytes through the production coordinator")
    second : C.result() <- C.run(coordinator,db,C.Request{empty,chosen})
    +empty_receipt : T.Receipt <- CT.receipt(second,False{})
    empty_read : T.answer() <- A.read(db,I.request(empty))
    F.assert(AT.loaded(empty_read,empty_receipt,[]),"actual worker preserves an empty asset with zero chunks")
    third : C.result() <- C.run(coordinator,db,C.Request{unicode,chosen})
    unicode_receipt : T.Receipt <- CT.receipt(third,False{})
    unicode_read : T.answer() <- A.read(db,I.request(unicode))
    F.assert(AT.loaded(unicode_read,unicode_receipt,[255,0,10]),"actual worker receives retained-derived decoded Unicode and punctuation filename")
    +before : String <- AT.state(db)
    absent : C.result() <- C.run(coordinator,db,C.Request{missing,chosen})
    F.assert(CT.failed(absent,"attachment_worker_missing",False{}),"actual missing local file remains distinct from root revocation with no publication attempt")
    AT.unchanged(db,before,"actual missing-file observation preserves every owned asset table")
    changed : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- P.disable(db,"1")
    disabled : T.RootEvidence <- F.need(T.RootEvidence,changed)
    F.remove(directory ++ "/capture.jsonl")
    F.remove(root ++ "/binary.bin")
    F.remove(root ++ "/empty.bin")
    F.remove(root ++ "/café #?.bin")
    retained_result : C.result() <- C.run(coordinator,db,C.Request{binary,disabled})
    retained : T.Receipt <- CT.receipt(retained_result,True{})
    CT.same_receipt(retained,binary_receipt)
    exported : T.answer() <- A.export(db,I.request(binary),directory ++ "/retained.bin")
    F.assert(CT.exported(exported,binary_receipt,directory ++ "/retained.bin"),"actual captured bytes remain exportable with exact original receipt after disable and source loss")
    bytes : List<&2,U32> <- AT.read_file(directory ++ "/retained.bin")
    F.assert(D.bytes_equal(bytes,[0,1,254,255]),"native composition export contains exact previously captured binary bytes")
    IO.try(Unit,Sql.close(db))
    IO.print("Synthetic native capture root: " ++ directory)

def argv(args: List<String>) -> IO(Unit):
  match args:
    case [_test,program]: suite(program)
    case _: IO.die(Unit,64,"Expected one trusted full application executable argument")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
