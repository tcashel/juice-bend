import Base
import ./attachment_capture_command.bend as Cmd
import ./attachment_capture_output.bend as O
import ./attachment_capture_roots.bend as Roots
import ./attachment_capture.bend as C
import ./attachment_asset_identity.bend as I
import ./attachment_asset_types.bend as T
import ./attachment_assets.bend as A
import ./attachment_root_policy.bend as P
import ./attachment_root_schema.bend as S
import ./attachment_inventory.bend as E
import ./paths.bend as Paths

def pure(value: O.result()) -> IO(O.result()): IO.pure(O.result(),value)
def failure(phase: String,error: E.Failure,state: O.Knowledge) -> O.result(): Fail{O.Failure{phase,error,state}}
def root_result(value: S.result(T.RootEvidence),operation: String) -> O.result():
  match value:
    case Fail{error}: failure("root",error,O.RootUncertain{})
    case Done{root}: O.root_ack(operation,root)
def roots_result(value: S.result(Roots.Page)) -> O.result():
  match value:
    case Fail{error}: failure("root_list",error,O.NoMutation{})
    case Done{page}: O.page(page)
def publication(value: C.Publication) -> O.Knowledge:
  match value:
    case C.NoPublicationAttempt{}: O.NoMutation{}
    case C.PublicationUncertain{}: O.CaptureUncertain{}
def captured(value: C.result()) -> O.result():
  match value:
    case Fail{C.Failure{phase,error,state}}: failure(phase,error,publication(state))
    case Done{C.Captured{receipt}}: O.asset("captured",receipt,None{},O.CaptureUncertain{})
    case Done{C.AlreadyCaptured{receipt}}: O.asset("already_captured",receipt,None{},O.NoMutation{})
def created(value: Result<&2,&2,C.Failure,C.Coordinator>,db: U32,occurrence: I.Resolved,root: T.RootEvidence) -> IO(O.result()):
  match value:
    case Fail{C.Failure{phase,error,state}}: pure(failure(phase,error,publication(state)))
    case Done{coordinator}:
      do IO<O.result()>:
        value : C.result() <- C.run(coordinator,db,C.Request{occurrence,root})
        return captured(value)
def chosen(valid: Bool,program: String,db: U32,occurrence: I.Resolved,root: T.RootEvidence) -> IO(O.result()):
  match valid:
    case False{}: pure(O.refused("root","attachment_root_revoked",O.NoMutation{}))
    case True{}:
      do IO<O.result()>:
        value : Result<&2,&2,C.Failure,C.Coordinator> <- C.create(program)
        created(value,db,occurrence,root)
def root_read(value: S.result(T.RootEvidence),program: String,db: U32,occurrence: I.Resolved,revision: String) -> IO(O.result()):
  match value:
    case Fail{error}: pure(failure("root",error,O.NoMutation{}))
    case Done{+root}:
      T.RootEvidence{_,_,actual,enabled} = root
      chosen(enabled && String.eq(actual,revision),program,db,occurrence,root)
def missing(valid: Bool,error: E.Failure,program: String,+db: U32,occurrence: I.Resolved,id: String,revision: String) -> IO(O.result()):
  match valid:
    case False{}: pure(failure("owned",error,O.NoMutation{}))
    case True{}:
      do IO<O.result()>:
        root : S.result(T.RootEvidence) <- P.read(db,id)
        root_read(root,program,db,occurrence,revision)
def retained(valid: Bool,receipt: T.Receipt,state: String) -> O.result():
  match valid:
    case True{}: O.asset(state,receipt,None{},O.NoMutation{})
    case False{}: O.refused("owned","attachment_capture_identity_changed",O.NoMutation{})
def capture_prior(value: T.answer(),program: String,db: U32,occurrence: I.Resolved,id: String,revision: String) -> IO(O.result()):
  match value:
    case Done{T.Loaded{T.Owned{+receipt,_}}}:
      T.Receipt{actual,_,_,_,_,_,_} = receipt
      pure(retained(I.same(actual,occurrence),receipt,"already_captured"))
    case Fail{+error}:
      E.Failure{code,_} = error
      missing(String.eq(code,"attachment_asset_not_captured"),error,program,db,occurrence,id,revision)
    case _: pure(O.refused("owned","attachment_capture_ack",O.NoMutation{}))
def capture_resolved(value: Result<&2,&2,E.Failure,I.Resolved>,program: String,+db: U32,id: String,revision: String) -> IO(O.result()):
  match value:
    case Fail{error}: pure(failure("identity",error,O.NoMutation{}))
    case Done{+occurrence}:
      do IO<O.result()>:
        prior : T.answer() <- A.read(db,I.request(occurrence))
        capture_prior(prior,program,db,occurrence,id,revision)
def capture(program: String,+db: U32,request: I.Request,id: String,revision: String) -> IO(O.result()):
  do IO<O.result()>:
    value : Result<&2,&2,E.Failure,I.Resolved> <- I.resolve(db,request)
    capture_resolved(value,program,db,id,revision)
def inspected(value: T.answer()) -> O.result():
  match value:
    case Fail{error}: failure("owned",error,O.NoMutation{})
    case Done{T.Loaded{T.Owned{receipt,_}}}: O.asset("retained",receipt,None{},O.NoMutation{})
    case _: O.refused("owned","attachment_capture_ack",O.NoMutation{})
def export_ack(valid: Bool,text: String) -> O.result():
  match valid:
    case True{}: Done{text}
    case False{}: O.refused("export","attachment_capture_ack",O.ExportUncertain{})
def exported(value: T.answer(),expected: T.Receipt,path: String,ack: String) -> O.result():
  match value:
    case Fail{error}: failure("export",error,O.ExportUncertain{})
    case Done{T.Exported{+actual,destination}}:
      export_ack(T.receipt_valid(actual) && T.same(actual,expected) && String.eq(destination,path),ack)
    case _: O.refused("export","attachment_capture_ack",O.ExportUncertain{})
def export_write(+db: U32,request: I.Request,expected: T.Receipt,+path: String,ack: String) -> IO(O.result()):
  do IO<O.result()>:
    value : T.answer() <- A.export(db,request,path)
    return exported(value,expected,path,ack)

def destination_test(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Maybe<&2,Bool>:
  match value:
    case Done{(0,("",""))}: Some{True{}}
    case Done{(1,("",""))}: Some{False{}}
    case _: None{}
def destination_status(exists: Maybe<&2,Bool>,link: Maybe<&2,Bool>,db: U32,request: I.Request,expected: T.Receipt,path: String,ack: String) -> IO(O.result()):
  match exists link:
    case Some{False{}} Some{False{}}: export_write(db,request,expected,path,ack)
    case Some{_} Some{_}: pure(O.refused("export","attachment_asset_export_exists",O.NoMutation{}))
    case _ _: pure(O.refused("export","attachment_asset_export_unavailable",O.NoMutation{}))
def export_ready(value: O.result(),db: U32,request: I.Request,expected: T.Receipt,+path: String) -> IO(O.result()):
  match value:
    case Fail{error}: pure(Fail{error})
    case Done{ack}:
      do IO<O.result()>:
        exists : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",["-e",path],"",1024,2000)
        link : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",["-L",path],"",1024,2000)
        destination_status(destination_test(exists),destination_test(link),db,request,expected,path,ack)
def export_read(value: T.answer(),db: U32,request: I.Request,+path: String) -> IO(O.result()):
  match value:
    case Fail{error}: pure(failure("owned",error,O.NoMutation{}))
    case Done{T.Loaded{T.Owned{+receipt,_}}}:
      export_ready(O.asset("exported",receipt,Some{path},O.NoMutation{}),db,request,receipt,path)
    case _: pure(O.refused("owned","attachment_capture_ack",O.NoMutation{}))
def export_valid(valid: Bool,+db: U32,+request: I.Request,path: String) -> IO(O.result()):
  match valid:
    case False{}: pure(failure("export",Cmd.usage(),O.NoMutation{}))
    case True{}:
      do IO<O.result()>:
        value : T.answer() <- A.read(db,request)
        export_read(value,db,request,path)
def execute(program: String,+db: U32,command: Cmd.Command) -> IO(O.result()):
  match command:
    case Cmd.Roots{after,count}:
      do IO<O.result()>:
        value : S.result(Roots.Page) <- Roots.list(db,after,count)
        return roots_result(value)
    case Cmd.AddRoot{path}:
      do IO<O.result()>:
        value : S.result(T.RootEvidence) <- P.enable(db,None{},path)
        return root_result(value,"add")
    case Cmd.EnableRoot{id}:
      do IO<O.result()>:
        value : S.result(T.RootEvidence) <- Roots.enable(db,id)
        return root_result(value,"enable")
    case Cmd.DisableRoot{id}:
      do IO<O.result()>:
        value : S.result(T.RootEvidence) <- P.disable(db,id)
        return root_result(value,"disable")
    case Cmd.Capture{request,id,revision}: capture(program,db,request,id,revision)
    case Cmd.Inspect{request}:
      do IO<O.result()>:
        value : T.answer() <- A.read(db,request)
        return inspected(value)
    case Cmd.Export{request,path}:
      do IO<O.result()>:
        +canonical : String <- Paths.destination(path)
        export_valid(Cmd.export_path(canonical),db,request,canonical)
def dispatch(program: String,db: U32,value: Cmd.result()) -> IO(O.result()):
  match value:
    case Fail{error}: pure(failure("request",error,O.NoMutation{}))
    case Done{command}: execute(program,db,command)
def emit(value: O.result()) -> IO(Unit):
  match value:
    case Done{text}: IO.print(text)
    case Fail{error}: IO.die(Unit,2,O.error(error))

def initialized_roots(value: S.result(Unit)) -> IO(Unit):
  match value:
    case Done{_}: IO.pure(Unit,Unit{})
    case Fail{error}: emit(failure("root_setup",error,O.RootUncertain{}))
def initialized_assets(value: T.answer(),db: U32) -> IO(Unit):
  match value:
    case Done{T.Initialized{}}:
      do IO<Unit>:
        roots : S.result(Unit) <- P.initialize(db)
        initialized_roots(roots)
    case Fail{error}: emit(failure("asset_setup",error,O.CaptureUncertain{}))
    case _: emit(O.refused("asset_setup","attachment_capture_ack",O.CaptureUncertain{}))

# Explicit application-startup migration. Reads and command execution never
# call this helper, so listing/inspection cannot silently create policy schema.
def initialize(+db: U32) -> IO(Unit):
  do IO<Unit>:
    assets : T.answer() <- A.initialize(db)
    initialized_assets(assets,db)

# Only the application startup API supplies program. Fatal retained-integrity
# diagnostics still exit this isolated command child; the parent rejects it.
def run(program: String,db: U32,command: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    value : O.result() <- dispatch(program,db,Cmd.parse(command,args))
    emit(value)
