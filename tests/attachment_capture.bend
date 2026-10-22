import Base
import ../src/attachment_capture.bend as C
import ../src/attachment_asset_identity.bend as I
import ../src/attachment_asset_types.bend as T
import ../src/attachment_assets.bend as A
import ../src/attachment_root_policy.bend as P
import ../src/attachment_inventory.bend as Inventory
import ../src/attachment_worker_protocol.bend as W
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ./attachment_asset_identity.bend as F
import ./attachment_assets.bend as AT

def need(value: Result<&2,&2,C.Failure,C.Coordinator>) -> IO(C.Coordinator):
  match value:
    case Done{value}: IO.pure(C.Coordinator,value)
    case _: IO.die(C.Coordinator,1,"Cannot initialize synthetic capture coordinator")

def receipt(value: C.result(),reuse: Bool) -> IO(T.Receipt):
  match value:
    case Done{C.Captured{+receipt}}:
      do IO<T.Receipt>:
        F.assert(Bool.not(reuse) && T.receipt_valid(receipt),"new capture returns a fully valid exact receipt")
        return receipt
    case Done{C.AlreadyCaptured{+receipt}}:
      do IO<T.Receipt>:
        F.assert(reuse && T.receipt_valid(receipt),"already captured retains a fully valid original receipt")
        return receipt
    case Fail{C.Failure{phase,Inventory.Failure{code,_},_}}: IO.die(T.Receipt,1,"Unexpected " ++ phase ++ ": " ++ code)

def uncertain(value: C.Publication) -> Bool:
  match value:
    case C.PublicationUncertain{}: True{}
    case _: False{}

def failed(value: C.result(),expected: String,is_uncertain: Bool) -> Bool:
  match value:
    case Fail{C.Failure{_,Inventory.Failure{code,_},state}}:
      String.eq(code,expected) && U32.is_eq(Bool.to_u32(is_uncertain),Bool.to_u32(uncertain(state)))
    case _: False{}

def deny(request: W.Request) -> IO(C.worker_result()):
  IO.die(C.worker_result(),1,"Forbidden worker invocation in a refusal or retained-read path")

def called(+db: U32,+request: W.Request,root: String,relative: String) -> IO(Unit):
  W.Request{program,actual,path,nonce} = request
  do IO<Unit>:
    F.assert(W.valid_request(request) && String.eq(program,"/synthetic/juice-bend") && String.eq(actual,root) && String.eq(path,relative),
      "worker receives only exact trusted executable chosen root and retained-derived relative path")
    Store.exec(db,"INSERT INTO test_capture_calls(nonce) VALUES(?)",[Sql.Cell.Text{nonce}])

def bytes(+db: U32,request: W.Request,root: String,relative: String,+payload: List<&2,U32>) -> IO(C.worker_result()):
  do IO<C.worker_result()>:
    called(db,request,root,relative)
    return Done{AT.payload(payload)}

def lost(db: U32,request: W.Request,root: String,relative: String) -> IO(C.worker_result()):
  do IO<C.worker_result()>:
    called(db,request,root,relative)
    return Fail{"attachment_worker_missing"}

def invalid(db: U32,request: W.Request,root: String,relative: String) -> IO(C.worker_result()):
  do IO<C.worker_result()>:
    called(db,request,root,relative)
    return Done{W.Payload{4,"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",[0,1,254,255]}}

def revoke(db: U32,other: U32,request: W.Request,root: String,relative: String) -> IO(C.worker_result()):
  do IO<C.worker_result()>:
    called(db,request,root,relative)
    changed : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- P.disable(other,"1")
    value : T.RootEvidence <- F.need(T.RootEvidence,changed)
    return Done{AT.payload([0,1,254,255])}

def enabled(db: U32,root: String) -> IO(T.RootEvidence):
  do IO<T.RootEvidence>:
    value : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- P.enable(db,None{},root)
    F.need(T.RootEvidence,value)

def same_receipt(actual: T.Receipt,expected: T.Receipt) -> IO(Unit):
  F.assert(T.same(actual,expected),"retained receipt keeps original root revision time identity count and digest")

def changed(value: I.Resolved) -> I.Resolved:
  I.Resolved{capture,record,offset,length,digest,ref,path,kind,_} = value
  I.Resolved{capture,record,offset,length,digest,ref,path,kind,I.LocalPath{"/synthetic/forged"}}

def counts(rows: List<&2,List<&2,Sql.Cell>>,+expected: String) -> Bool:
  match rows:
    case [[Sql.Cell.Integer{count},Sql.Cell.Integer{distinct}]]:
      String.eq(count,expected) && String.eq(distinct,expected)
    case _: False{}

def exported(value: T.answer(),expected: T.Receipt,path: String) -> Bool:
  match value:
    case Done{T.Exported{receipt,destination}}: T.same(receipt,expected) && String.eq(destination,path)
    case _: False{}

def calls(db: U32,expected: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*),count(DISTINCT nonce) FROM test_capture_calls",[],1)
    F.assert(counts(rows,expected),"exact worker count and fresh nonce for every admitted operation")

def suite() -> IO(Unit):
  do IO<Unit>:
    +directory : String <- F.create_root()
    F.guard(directory)
    +root : String = directory ++ "/authorized"
    made : String <- F.command("/bin/mkdir",["-m","700",root])
    F.write_bytes(root ++ "/binary.bin",[0,1,254,255])
    +db : U32 <- Store.open(directory ++ "/library.sqlite")
    asset_init : T.answer() <- A.initialize(db)
    F.assert(AT.initialized(asset_init),"coordinator fixture explicitly initializes owned assets")
    policy_init : Result<&2,&2,Inventory.Failure,Unit> <- P.initialize(db)
    policy_done : Unit <- F.need(Unit,policy_init)
    +enabled_root : T.RootEvidence <- enabled(db,root)
    Store.exec(db,"CREATE TABLE test_capture_calls(nonce TEXT NOT NULL)",[])
    Store.write_text(directory ++ "/capture.jsonl","w",
      F.record(F.image(root ++ "/binary.bin")) ++ F.record(F.image(root ++ "/empty.bin")) ++
      F.record(F.image("file://localhost" ++ root ++ "/caf%C3%A9%20%23%3F.bin")) ++
      F.record(F.image(directory ++ "/outside.bin")) ++ F.record(F.image("file://" ++ root ++ "/bad%zz")) ++
      F.record(F.image("file://" ++ root ++ "/bad?query")) ++ F.record(F.image(root ++ "/binary.bin")) ++
      F.record(F.image(root ++ "/race.bin")) ++ F.record(F.image(root ++ "/missing.bin")) ++
      F.record(F.image(root ++ "/invalid.bin")))
    +snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl")
    +first : I.Resolved <- F.get(db,snapshot,0,0,F.path(0))
    +empty : I.Resolved <- F.get(db,snapshot,1,0,F.path(0))
    +url : I.Resolved <- F.get(db,snapshot,2,0,F.path(0))
    +outside : I.Resolved <- F.get(db,snapshot,3,0,F.path(0))
    +malformed : I.Resolved <- F.get(db,snapshot,4,0,F.path(0))
    +unsupported : I.Resolved <- F.get(db,snapshot,5,0,F.path(0))
    +duplicate : I.Resolved <- F.get(db,snapshot,6,0,F.path(0))
    +race : I.Resolved <- F.get(db,snapshot,7,0,F.path(0))
    +missing : I.Resolved <- F.get(db,snapshot,8,0,F.path(0))
    +invalid_occurrence : I.Resolved <- F.get(db,snapshot,9,0,F.path(0))
    coordinator_result : Result<&2,&2,C.Failure,C.Coordinator> <- C.create("/synthetic/juice-bend")
    +coordinator : C.Coordinator <- need(coordinator_result)
    +before : String <- AT.state(db)
    forged : C.result() <- C.run_with_worker(coordinator,db,C.Request{changed(first),enabled_root},r => deny(r))
    F.assert(failed(forged,"attachment_capture_identity_changed",False{}),"caller cannot substitute retained local path")
    absent : C.result() <- C.run_with_worker(coordinator,db,C.Request{first,T.RootEvidence{"99",root,"1",True{}}},r => deny(r))
    F.assert(failed(absent,"attachment_root_missing",False{}),"missing explicit root does not invoke a worker")
    external : C.result() <- C.run_with_worker(coordinator,db,C.Request{outside,enabled_root},r => deny(r))
    F.assert(failed(external,"attachment_capture_outside_root",False{}),"retained outside-root reference cannot read bytes")
    bad_url : C.result() <- C.run_with_worker(coordinator,db,C.Request{malformed,enabled_root},r => deny(r))
    F.assert(failed(bad_url,"attachment_capture_url_malformed",False{}),"malformed retained URL stays distinct from missing file")
    query_url : C.result() <- C.run_with_worker(coordinator,db,C.Request{unsupported,enabled_root},r => deny(r))
    F.assert(failed(query_url,"attachment_capture_url_unsupported",False{}),"query-bearing retained URL never silently changes filename")
    calls(db,"0")
    AT.unchanged(db,before,"all pre-worker refusals preserve every owned asset table")
    first_value : C.result() <- C.run_with_worker(coordinator,db,C.Request{first,enabled_root},r => bytes(db,r,root,"binary.bin",[0,1,254,255]))
    +first_receipt : T.Receipt <- receipt(first_value,False{})
    empty_value : C.result() <- C.run_with_worker(coordinator,db,C.Request{empty,enabled_root},r => bytes(db,r,root,"empty.bin",[]))
    +empty_receipt : T.Receipt <- receipt(empty_value,False{})
    url_value : C.result() <- C.run_with_worker(coordinator,db,C.Request{url,enabled_root},r => bytes(db,r,root,"café #?.bin",[0,1,254,255]))
    url_receipt : T.Receipt <- receipt(url_value,False{})
    duplicate_value : C.result() <- C.run_with_worker(coordinator,db,C.Request{duplicate,enabled_root},r => bytes(db,r,root,"binary.bin",[0,1,254,255]))
    duplicate_receipt : T.Receipt <- receipt(duplicate_value,False{})
    F.assert(Bool.not(T.same(first_receipt,duplicate_receipt)),"same local file at another physical record remains a distinct owned observation")
    calls(db,"4")
    +saved : String <- AT.state(db)
    missing_result : C.result() <- C.run_with_worker(coordinator,db,C.Request{missing,enabled_root},r => lost(db,r,root,"missing.bin"))
    F.assert(failed(missing_result,"attachment_worker_missing",False{}),"exact worker missing remains typed with no publication attempt")
    payload_result : C.result() <- C.run_with_worker(coordinator,db,C.Request{invalid_occurrence,enabled_root},r => invalid(db,r,root,"invalid.bin"))
    F.assert(failed(payload_result,"attachment_capture_payload_invalid",False{}),"bad byte digest from worker seam is rejected before publication")
    AT.unchanged(db,saved,"failed worker payloads never publish success or chunks")
    +other : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",1))
    Store.exec(other,"PRAGMA foreign_keys=ON",[])
    revoked : C.result() <- C.run_with_worker(coordinator,db,C.Request{race,enabled_root},r => revoke(db,other,r,root,"race.bin"))
    F.assert(failed(revoked,"attachment_root_revoked",True{}),"other connection revocation during byte observation refuses publication without success acknowledgement")
    AT.unchanged(db,saved,"atomic real-policy revalidation leaves all saved assets unchanged")
    stale : C.result() <- C.run_with_worker(coordinator,db,C.Request{race,enabled_root},r => deny(r))
    F.assert(failed(stale,"attachment_root_revoked",False{}),"already-revoked root blocks the next byte read")
    again : C.result() <- C.run_with_worker(coordinator,db,C.Request{first,enabled_root},r => deny(r))
    original : T.Receipt <- receipt(again,True{})
    same_receipt(original,first_receipt)
    +new_root : T.RootEvidence <- enabled(db,root)
    old_revision : C.result() <- C.run_with_worker(coordinator,db,C.Request{race,enabled_root},r => deny(r))
    F.assert(failed(old_revision,"attachment_root_revoked",False{}),"re-enable does not revive stale chosen root revision")
    fresh : C.result() <- C.run_with_worker(coordinator,db,C.Request{race,new_root},r => bytes(db,r,root,"race.bin",[0,1,254,255]))
    fresh_receipt : T.Receipt <- receipt(fresh,False{})
    calls(db,"8")
    disabled : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- P.disable(db,"1")
    disabled_root : T.RootEvidence <- F.need(T.RootEvidence,disabled)
    F.remove(directory ++ "/capture.jsonl")
    F.remove(root ++ "/binary.bin")
    still_saved : C.result() <- C.run_with_worker(coordinator,db,C.Request{first,disabled_root},r => deny(r))
    retained : T.Receipt <- receipt(still_saved,True{})
    same_receipt(retained,first_receipt)
    owned_empty : T.answer() <- A.read(db,I.request(empty))
    F.assert(AT.loaded(owned_empty,empty_receipt,[]),"zero-byte capture is a retained asset with zero chunks")
    export_result : T.answer() <- A.export(db,I.request(first),directory ++ "/retained.bin")
    F.assert(exported(export_result,first_receipt,directory ++ "/retained.bin"),"retained export succeeds with exact receipt independently of disabled root")
    retained_bytes : List<&2,U32> <- AT.read_file(directory ++ "/retained.bin")
    F.assert(D.bytes_equal(retained_bytes,[0,1,254,255]),"exact owned bytes survive provider and external source deletion")
    calls(db,"8")
    IO.try(Unit,Sql.close(other))
    IO.try(Unit,Sql.close(db))
    IO.print("Synthetic explicit capture root: " ++ directory)

def main() -> IO(Unit): suite()
