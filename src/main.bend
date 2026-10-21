import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./gui.bend as Gui
import ./cli.bend as Cli
import ./demo.bend as Demo
import ./quota_entry.bend as Quota
import ./quota_route.bend as Route

def mkdir_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit,1,"Cannot create private Juice Bend data directory")
    case Done{(code,(out,error))}:
      Store.checked(U32.is_eq(code,0),"Cannot create private Juice Bend data directory")

def dispatch(+db: U32,+dir: String,program: String,args: List<String>) -> IO(Unit):
  match args:
    case []:
      Gui.run(db,dir,program)
    case "--demo" <> []:
      do IO<Unit>:
        Demo.prepare(db,dir)
        Gui.run(db,dir,program)
    case "--demo" <> rest:
      do IO<Unit>:
        Demo.prepare(db,dir)
        Cli.run(db,dir,rest)
    case "--gui" <> []:
      Gui.run(db,dir,program)
    case rest:
      Cli.run(db,dir,rest)

def run(+dir: String,program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    Store.checked(Bool.not(String.is_empty(dir)),"Data directory must not be empty")
    made : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/mkdir",["-p","-m","700",dir],"",4096,5000)
    mkdir_result(made)
    +db : U32 <- Store.open(dir ++ "/juice-bend.sqlite")
    dispatch(db,dir,program,args)
    IO.try(Unit,Sql.close(db))

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

def argv(args: List<String>) -> IO(Unit):
  match args:
    case []:
      IO.die(Unit,2,"Missing executable identity")
    case program <> rest:
      options(program,rest)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
