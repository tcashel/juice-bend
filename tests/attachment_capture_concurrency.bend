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
import ./attachment_asset_identity.bend as F
import ./attachment_assets.bend as AT
import ./attachment_capture.bend as CT

def sent(value: Result<&1,&1,Unit,Unit>) -> IO(Unit):
  match value:
    case Done{_}: IO.pure(Unit,Unit{})
    case Fail{_}: IO.die(Unit,1,"Synthetic capture barrier unexpectedly closed")

def received(value: Maybe<&1,Unit>) -> IO(Unit):
  match value:
    case Some{_}: IO.pure(Unit,Unit{})
    case None{}: IO.die(Unit,1,"Synthetic capture barrier unexpectedly closed")

def signal(channel: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    value : Result<&1,&1,Unit,Unit> <- Chan.send(Unit,channel,Unit{})
    sent(value)

def wait(channel: Chan(Unit)) -> IO(Unit):
  do IO<Unit>:
    value : Maybe<&1,Unit> <- Chan.recv(Unit,channel)
    received(value)

def observe(request: W.Request,entered: Chan(Unit),release: Chan(Unit)) -> IO(C.worker_result()):
  do IO<C.worker_result()>:
    F.assert(W.valid_request(request),"serialized observer receives a valid trusted request")
    signal(entered)
    wait(release)
    return Done{AT.payload([0,1,254,255])}

def queued(started: Chan(Unit),coordinator: C.Coordinator,db: U32,request: C.Request) -> IO(C.result()):
  do IO<C.result()>:
    signal(started)
    C.run_with_worker(coordinator,db,request,r => CT.deny(r))

def pending(value: Poll<&1,&1,Maybe<&1,C.result()>,Unit>) -> Bool:
  match value:
    case Wait{_}: True{}
    case _: False{}

def suite() -> IO(Unit):
  do IO<Unit>:
    +directory : String <- F.create_root()
    F.guard(directory)
    +root : String = directory ++ "/authorized"
    made : String <- F.command("/bin/mkdir",["-m","700",root])
    +db : U32 <- Store.open(directory ++ "/library.sqlite")
    assets : T.answer() <- A.initialize(db)
    F.assert(AT.initialized(assets),"concurrency fixture explicitly initializes asset storage")
    initialized : Result<&2,&2,Inventory.Failure,Unit> <- P.initialize(db)
    done : Unit <- F.need(Unit,initialized)
    root_value : T.RootEvidence <- CT.enabled(db,root)
    Store.write_text(directory ++ "/capture.jsonl","w",F.record(F.image(root ++ "/binary.bin")))
    snapshot : String <- Capture.import_file(db,"claude",directory ++ "/capture.jsonl")
    occurrence : I.Resolved <- F.get(db,snapshot,0,0,F.path(0))
    +request : C.Request = C.Request{occurrence,root_value}
    +other : U32 <- IO.try(U32,Sql.open_existing(directory ++ "/library.sqlite",1))
    Store.exec(other,"PRAGMA foreign_keys=ON",[])
    created : Result<&2,&2,C.Failure,C.Coordinator> <- C.create("/synthetic/juice-bend")
    +coordinator : C.Coordinator <- CT.need(created)
    Store.exec(other,"CREATE TABLE test_capture_transaction(value INTEGER NOT NULL)",[])
    Store.exec(other,"BEGIN IMMEDIATE",[])
    Store.exec(other,"INSERT INTO test_capture_transaction VALUES(1)",[])
    borrowed : C.result() <- C.run_with_worker(coordinator,other,request,r => CT.deny(r))
    F.assert(CT.failed(borrowed,"attachment_transaction_unavailable",False{}),"capture refuses caller-owned transaction before any byte observation")
    inside : List<&2,List<&2,Sql.Cell>> <- Store.q(other,"SELECT count(*),count(*) FROM test_capture_transaction",[],1)
    F.assert(CT.counts(inside,"1"),"capture refusal preserves the caller's uncommitted row and transaction")
    Store.exec(other,"ROLLBACK",[])
    rolled : List<&2,List<&2,Sql.Cell>> <- Store.q(other,"SELECT count(*),count(*) FROM test_capture_transaction",[],1)
    F.assert(CT.counts(rolled,"0"),"caller rollback still controls its uncommitted row after capture refusal")
    +entered : Chan(Unit) <- Chan.new(Unit,1)
    +release : Chan(Unit) <- Chan.new(Unit,1)
    +started : Chan(Unit) <- Chan.new(Unit,1)
    first : Chan(C.result()) <- IO.fork(C.result(),C.run_with_worker(coordinator,db,request,r => observe(r,entered,release)))
    wait(entered)
    +second : Chan(C.result()) <- IO.fork(C.result(),queued(started,coordinator,other,request))
    wait(started)
    early : Poll<&1,&1,Maybe<&1,C.result()>,Unit> <- Chan.try_recv(C.result(),second,30)
    F.assert(pending(early),"second explicit request stays queued while first observation is held open")
    signal(release)
    first_value : C.result() <- IO.join(C.result(),first)
    +saved : T.Receipt <- CT.receipt(first_value,False{})
    second_value : C.result() <- IO.join(C.result(),second)
    retained : T.Receipt <- CT.receipt(second_value,True{})
    CT.same_receipt(retained,saved)
    F.assert(True{},"queued request rechecks owned state and reuses exact first receipt without another worker")
    IO.try(Unit,Sql.close(other))
    IO.try(Unit,Sql.close(db))
    Chan.close(Unit,entered)
    Chan.close(Unit,release)
    Chan.close(Unit,started)
    IO.print("Synthetic queued capture root: " ++ directory)

def main() -> IO(Unit): suite()
