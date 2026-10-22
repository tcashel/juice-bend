import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./attachment_preview_app.bend as PreviewApp
import ./attachment_preview_worker.bend as PreviewWorker
import ./attachment_preview_external_worker.bend as ExternalPreviewWorker
import ./attachment_image_worker.bend as ImageWorker
import ./cli.bend as Cli
import ./demo.bend as Demo
import ./quota_entry.bend as Quota
import ./quota_route.bend as Route
import ./attachment_worker_protocol.bend as AttachmentProtocol
import ./attachment_worker.bend as AttachmentWorker
import ./attachment_capture_cli.bend as AttachmentCapture
import ./attachment_capture_command.bend as AttachmentCommand

def mkdir_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit,1,"Cannot create private Juice Bend data directory")
    case Done{(code,(out,error))}:
      Store.checked(U32.is_eq(code,0),"Cannot create private Juice Bend data directory")

def capture_command(known: Bool,db: U32,dir: String,program: String,command: String,args: List<String>) -> IO(Unit):
  match known:
    case True{}: AttachmentCapture.run(program,db,command,args)
    case False{}: Cli.run(db,dir,command <> args)

def cli(db: U32,dir: String,program: String,args: List<String>) -> IO(Unit):
  match args:
    case +command <> rest: capture_command(AttachmentCommand.known(command),db,dir,program,command,rest)
    case []: Cli.run(db,dir,[])

def dispatch(+db: U32,+dir: String,program: String,args: List<String>) -> IO(Unit):
  match args:
    case []:
      PreviewApp.run(db,dir,program)
    case "--demo" <> []:
      do IO<Unit>:
        Demo.prepare(db,dir)
        PreviewApp.run(db,dir,program)
    case "--demo" <> rest:
      do IO<Unit>:
        Demo.prepare(db,dir)
        cli(db,dir,program,rest)
    case "--gui" <> []:
      PreviewApp.run(db,dir,program)
    case rest:
      cli(db,dir,program,rest)

def run_ordinary(+dir: String,program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    Store.checked(Bool.not(String.is_empty(dir)),"Data directory must not be empty")
    made : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/mkdir",["-p","-m","700",dir],"",4096,5000)
    mkdir_result(made)
    +db : U32 <- Store.open(dir ++ "/juice-bend.sqlite")
    AttachmentCapture.initialize(db)
    dispatch(db,dir,program,args)
    IO.try(Unit,Sql.close(db))

def preview_kind(+command: String) -> U32:
  Bool.pick(U32,String.eq(command,"attachment-preview-inline-v1"),0,
    Bool.pick(U32,String.eq(command,"attachment-preview-retained-v1"),1,
      Bool.pick(U32,String.eq(command,ImageWorker.inline_command()),3,
        Bool.pick(U32,String.eq(command,ImageWorker.external_command()),4,2))))

def run_command(kind: U32,dir: String,program: String,command: String,args: List<String>) -> IO(Unit):
  match kind:
    case 0: PreviewWorker.root(dir,args)
    case 1: ExternalPreviewWorker.root(dir,args)
    case 3: ImageWorker.inline_root(dir,args)
    case 4: ImageWorker.external_root(dir,args)
    case _: run_ordinary(dir,program,command <> args)

def run(dir: String,program: String,args: List<String>) -> IO(Unit):
  match args:
    case []: run_ordinary(dir,program,[])
    case +command <> rest: run_command(preview_kind(command),dir,program,command,rest)

def capture_root(program: String,args: List<&2,String>,root: Maybe<&2,String>) -> IO(Unit):
  match root:
    case Some{dir}: run(dir,program,Route.linear(args))
    case None{}:
      do IO<Unit>:
        home : String <- IO.try(String,IO.get_env("HOME"))
        run(home ++ "/Library/Application Support/JuiceBend",program,Route.linear(args))

def routed(program: String,route: Route.Route) -> IO(Unit):
  match route:
    case Route.Quota{root,args}: Quota.argv("--data-dir" <> root <> "quota" <> Route.linear(args))
    case Route.Rejected{}: Quota.argv([])
    case Route.Capture{root,args}: capture_root(program,args,root)

def options(program: String,args: List<String>) -> IO(Unit):
  routed(program,Route.classify(Quota.copied_args(args)))

def attachment_entry(program: String,route: AttachmentProtocol.Route) -> IO(Unit):
  match route:
    case AttachmentProtocol.Worker{request}: AttachmentWorker.run(request)
    case AttachmentProtocol.Rejected{}: IO.die(Unit,64,"attachment_worker_arguments")
    case AttachmentProtocol.Ordinary{args}: options(program,Route.linear(args))

def argv(args: List<String>) -> IO(Unit):
  match args:
    case []:
      IO.die(Unit,2,"Missing executable identity")
    case +program <> rest:
      attachment_entry(program,AttachmentProtocol.classify(program,Quota.copied_args(rest)))

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
