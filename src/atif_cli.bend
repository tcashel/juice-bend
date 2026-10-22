import Base
import ./atif_command.bend as Command
import ./atif_export.bend as Export
import ./atif_types.bend as T
import ./paths.bend as Paths

def printed(result: Result<&2,&2,String,String>) -> IO(Unit):
  match result:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{text}: IO.print(text)

# This route is executed by the existing isolated CLI child. Export owns its
# read transaction; never call it on a GUI actor's live SQLite connection.
def canonical_ready(valid: Bool,+db: U32,+value: Command.Command,+canonical: String) -> IO(Unit):
  match valid:
    case False{}: IO.die(Unit,2,"ATIF destination exceeded its canonical path contract")
    case True{}:
      Command.Command{snapshot,_} = value
      do IO<Unit>:
        receipt : T.Receipt <- Export.export(db,snapshot,canonical)
        printed(Command.acknowledge(value,canonical,receipt))

def parsed(db: U32,result: Result<&2,&2,String,Command.Command>) -> IO(Unit):
  match result:
    case Fail{message}: IO.die(Unit,2,message)
    case Done{+value}:
      Command.Command{_,destination} = value
      do IO<Unit>:
        +canonical : String <- Paths.destination(destination)
        canonical_ready(Command.preflight(value,canonical),db,value,canonical)

def run(db: U32,args: List<String>) -> IO(Unit):
  parsed(db,Command.parse(args))
