import Base
import ./attachment_asset_identity.bend as Identity
import ./attachment_asset_types.bend as T
import ./attachment_assets.bend as Assets
import ./attachment_inventory.bend as Inventory
import ./attachment_root_policy.bend as Policy
import ./attachment_root_rules.bend as Rules
import ./attachment_worker_protocol.bend as Worker
import ./attachment_worker_parent.bend as Parent
import ./attachment_capture_path.bend as Path
import ./attachment_capture_clock.bend as Clock
import ./domain.bend as D

type Request is Data:
  Request{occurrence: Identity.Resolved,root: T.RootEvidence}

type Publication is Data:
  NoPublicationAttempt{}
  PublicationUncertain{}

type Failure is Data:
  Failure{phase: String,cause: Inventory.Failure,publication: Publication}

type Outcome is Data:
  AlreadyCaptured{receipt: T.Receipt}
  Captured{receipt: T.Receipt}

# App lifecycle creates one instance. Copies share this one permit: queued
# explicit captures cannot launch overlapping workers. No DB lock spans IO.
type Coordinator is Data:
  Coordinator{program: String,permit: Chan(Unit)}

def result() -> Data: Result<&2,&2,Failure,Outcome>
def worker_result() -> Data: Result<&2,&2,String,Worker.Payload>
def pure(value: result()) -> IO(result()): IO.pure(result(),value)
def failure(phase: String,error: Inventory.Failure) -> result():
  Fail{Failure{phase,error,NoPublicationAttempt{}}}
def refused(phase: String,code: String) -> result():
  failure(phase,Inventory.Failure{code,"Explicit local attachment capture was not accepted"})

def created(value: Result<&1,&1,Unit,Unit>,program: String,permit: Chan(Unit)) -> Result<&2,&2,Failure,Coordinator>:
  match value:
    case Done{_}: Done{Coordinator{program,permit}}
    case Fail{_}: Fail{Failure{"lifecycle",Inventory.Failure{"attachment_capture_closed","Capture coordinator is closed"},NoPublicationAttempt{}}}

def create_checked(valid: Bool,program: String) -> IO(Result<&2,&2,Failure,Coordinator>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,Failure,Coordinator>,Fail{Failure{"request",Inventory.Failure{"attachment_capture_program","Expected trusted absolute application executable"},NoPublicationAttempt{}}})
    case True{}:
      do IO<Result<&2,&2,Failure,Coordinator>>:
        +permit : Chan(Unit) <- Chan.new(Unit,1)
        sent : Result<&1,&1,Unit,Unit> <- Chan.send(Unit,permit,Unit{})
        return created(sent,program,permit)

def create(+trusted_program: String) -> IO(Result<&2,&2,Failure,Coordinator>):
  create_checked(Rules.path(trusted_program),trusted_program)

def nonce_part(value: Result<&1,&1,U32 & String,U32>) -> Result<&2,&2,String,String>:
  match value:
    case Fail{_}: Fail{"attachment_capture_random"}
    case Done{word}: Done{D.hex_word(word)}

def nonce_more(value: Result<&2,&2,String,String>,prior: String,
  next: String -> IO(Result<&2,&2,String,String>)) -> IO(Result<&2,&2,String,String>):
  match value:
    case Fail{error}: IO.pure(Result<&2,&2,String,String>,Fail{error})
    case Done{part}: next(prior ++ part)

def nonce(left: Nat,prior: String) -> IO(Result<&2,&2,String,String>):
  match left:
    case 0n: IO.pure(Result<&2,&2,String,String>,Done{prior})
    case 1n+rest:
      do IO<Result<&2,&2,String,String>>:
        value : Result<&1,&1,U32 & String,U32> <- IO.random_u32()
        nonce_more(nonce_part(value),prior,parts => nonce(rest,parts))

def acknowledged(valid: Bool,receipt: T.Receipt) -> result():
  match valid:
    case True{}: Done{Captured{receipt}}
    case False{}: Fail{Failure{"publish",Inventory.Failure{"attachment_capture_ack","Publication acknowledgement does not match the requested retained occurrence"},PublicationUncertain{}}}

def publication(value: T.answer(),wanted: T.Receipt) -> result():
  match value:
    case Done{T.Published{+receipt,_}}:
      acknowledged(T.receipt_valid(receipt) && T.same(wanted,receipt),receipt)
    case Fail{error}: Fail{Failure{"publish",error,PublicationUncertain{}}}
    case _: Fail{Failure{"publish",Inventory.Failure{"attachment_capture_ack","Publication returned an unexpected acknowledgement"},PublicationUncertain{}}}

def timed(value: Clock.result(),db: U32,+occurrence: Identity.Resolved,root: T.RootEvidence,payload: Worker.Payload) -> IO(result()):
  match value:
    case Fail{code}: pure(refused("clock",code))
    case Done{time}:
      do IO<result()>:
        +admission : T.Admission = T.Admission{occurrence,root,time,payload}
        published : T.answer() <- Assets.publish(db,admission,d => r => Policy.validate_owned(d,r))
        return publication(published,T.receipt(admission))

def observed_valid(valid: Bool,+db: U32,occurrence: Identity.Resolved,root: T.RootEvidence,payload: Worker.Payload) -> IO(result()):
  match valid:
    case False{}: pure(refused("worker","attachment_capture_payload_invalid"))
    case True{}:
      do IO<result()>:
        time : Clock.result() <- Clock.now(db)
        timed(time,db,occurrence,root,payload)

def observed(value: worker_result(),db: U32,occurrence: Identity.Resolved,root: T.RootEvidence) -> IO(result()):
  match value:
    case Fail{code}: pure(refused("worker",code))
    case Done{+payload}:
      observed_valid(T.payload_valid(payload),db,occurrence,root,payload)

def invoke(valid: Bool,request: Worker.Request,db: U32,occurrence: Identity.Resolved,root: T.RootEvidence,
  worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match valid:
    case False{}: pure(refused("request","attachment_worker_arguments"))
    case True{}:
      do IO<result()>:
        payload : worker_result() <- worker(request)
        observed(payload,db,occurrence,root)

def nonced(value: Result<&2,&2,String,String>,db: U32,occurrence: Identity.Resolved,+root: T.RootEvidence,
  program: String,relative: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case Fail{code}: pure(refused("nonce",code))
    case Done{nonce}:
      T.RootEvidence{_,path,_,_} = root
      +request : Worker.Request = Worker.Request{program,path,relative,nonce}
      invoke(Worker.valid_request(request),request,db,occurrence,root,worker)

def target(value: Path.answer(),db: U32,occurrence: Identity.Resolved,root: T.RootEvidence,
  program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case Fail{code}: pure(refused("path",code))
    case Done{relative}:
      do IO<result()>:
        token : Result<&2,&2,String,String> <- nonce(4n,"")
        nonced(token,db,occurrence,root,program,relative,worker)

def mapped(value: Path.answer(),db: U32,occurrence: Identity.Resolved,+root: T.RootEvidence,
  program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case Fail{code}: pure(refused("path",code))
    case Done{path}:
      T.RootEvidence{_,base,_,_} = root
      target(Path.relative(base,path),db,occurrence,root,program,worker)

def local(value: Identity.LocalReference) -> Path.answer():
  match value:
    case Identity.LocalPath{path}: Path.path(path)
    case Identity.LocalFileURL{url}: Path.url(url)

def root_matches(valid: Bool,db: U32,+occurrence: Identity.Resolved,root: T.RootEvidence,
  program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match valid:
    case False{}: pure(refused("root","attachment_root_revoked"))
    case True{}:
      Identity.Resolved{_,_,_,_,_,_,_,_,reference} = occurrence
      mapped(local(reference),db,occurrence,root,program,worker)

def authorized(value: Result<&2,&2,Inventory.Failure,T.RootEvidence>,db: U32,occurrence: Identity.Resolved,
  wanted: T.RootEvidence,program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case Fail{error}: pure(failure("root",error))
    case Done{+actual}:
      T.RootEvidence{_,_,_,enabled} = actual
      root_matches(enabled && Policy.same(actual,wanted),db,occurrence,actual,program,worker)

def new_capture_checked(valid: Bool,+db: U32,occurrence: Identity.Resolved,+root: T.RootEvidence,program: String,
  worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match valid:
    case False{}: pure(refused("root","attachment_root_revoked"))
    case True{}:
      T.RootEvidence{identity,_,_,_} = root
      do IO<result()>:
        current : Result<&2,&2,Inventory.Failure,T.RootEvidence> <- Policy.read(db,identity)
        authorized(current,db,occurrence,root,program,worker)

def new_capture(db: U32,occurrence: Identity.Resolved,+root: T.RootEvidence,program: String,
  worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  T.RootEvidence{_,_,_,enabled} = root
  new_capture_checked(Policy.valid(root) && enabled,db,occurrence,root,program,worker)

def retained(valid: Bool,receipt: T.Receipt) -> IO(result()):
  match valid:
    case True{}: pure(Done{AlreadyCaptured{receipt}})
    case False{}: pure(refused("owned","attachment_capture_identity_changed"))

def uncaptured(missing: Bool,error: Inventory.Failure,db: U32,occurrence: Identity.Resolved,
  root: T.RootEvidence,program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match missing:
    case True{}: new_capture(db,occurrence,root,program,worker)
    case False{}: pure(failure("owned",error))

def existing(value: T.answer(),db: U32,+occurrence: Identity.Resolved,root: T.RootEvidence,program: String,
  worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case Done{T.Loaded{T.Owned{+receipt,_}}}:
      T.Receipt{actual,_,_,_,_,_,_} = receipt
      retained(T.receipt_valid(receipt) && Identity.same(actual,occurrence),receipt)
    case Fail{+error}:
      Inventory.Failure{code,_} = error
      uncaptured(String.eq(code,"attachment_asset_not_captured"),error,db,occurrence,root,program,worker)
    case _: pure(refused("owned","attachment_capture_ack"))

def resolved_same(valid: Bool,+db: U32,+actual: Identity.Resolved,
  root: T.RootEvidence,program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match valid:
    case False{}: pure(refused("identity","attachment_capture_identity_changed"))
    case True{}:
      do IO<result()>:
        owned : T.answer() <- Assets.read(db,Identity.request(actual))
        existing(owned,db,actual,root,program,worker)

def resolved(value: Result<&2,&2,Inventory.Failure,Identity.Resolved>,db: U32,wanted: Identity.Resolved,
  root: T.RootEvidence,program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case Fail{error}: pure(failure("identity",error))
    case Done{+actual}:
      resolved_same(Identity.same(actual,wanted),db,actual,root,program,worker)

def admitted(valid: Bool,+db: U32,request: Request,program: String,worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match valid:
    case False{}: pure(refused("request","attachment_capture_request"))
    case True{}:
      Request{+occurrence,root} = request
      do IO<result()>:
        value : Result<&2,&2,Inventory.Failure,Identity.Resolved> <- Identity.resolve(db,Identity.request(occurrence))
        resolved(value,db,occurrence,root,program,worker)

def released(value: Result<&1,&1,Unit,Unit>,outcome: result()) -> result():
  # Closing a permit does not change the already-observed storage outcome.
  match value:
    case Done{_}: outcome
    case Fail{_}: outcome

def acquired(value: Maybe<&1,Unit>,+permit: Chan(Unit),db: U32,+request: Request,+program: String,
  worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  match value:
    case None{}: pure(refused("lifecycle","attachment_capture_closed"))
    case Some{_}:
      Request{occurrence,_} = request
      do IO<result()>:
        outcome : result() <- admitted(Identity.valid(occurrence) && Rules.path(program),db,request,program,worker)
        sent : Result<&1,&1,Unit,Unit> <- Chan.send(Unit,permit,Unit{})
        return released(sent,outcome)

# Internal test seam only: real identity/policy/storage remain in the path.
# Production callers use run, which fixes the actual confined subprocess.
def run_with_worker(coordinator: Coordinator,db: U32,request: Request,
  worker: Worker.Request -> IO(worker_result())) -> IO(result()):
  Coordinator{program,+permit} = coordinator
  do IO<result()>:
    ready : Maybe<&1,Unit> <- Chan.recv(Unit,permit)
    acquired(ready,permit,db,request,program,worker)

def run(coordinator: Coordinator,db: U32,request: Request) -> IO(result()):
  run_with_worker(coordinator,db,request,r => Parent.run(r))
