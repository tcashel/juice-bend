import Base
import ./result_events_cli.bend as Events
import ./result_links_cli.bend as Links

# The CLI and focused subprocess tests share this exact command boundary.
# Unknown labels are passed unchanged to the host CLI's existing dispatcher.
def linked(known: Bool,db: U32,cmd: String,args: List<String>,fallback: String -> List<String> -> IO(Unit)) -> IO(Unit):
  match known:
    case True{}: Links.command(db,cmd,args)
    case False{}: fallback(cmd,args)

def events(known: Bool,db: U32,+cmd: String,args: List<String>,fallback: String -> List<String> -> IO(Unit)) -> IO(Unit):
  match known:
    case True{}: Events.command(db,cmd,args)
    case False{}: linked(String.eq(cmd,"result-link-page"),db,cmd,args,fallback)

def command(db: U32,+cmd: String,args: List<String>,fallback: String -> List<String> -> IO(Unit)) -> IO(Unit):
  events(String.eq(cmd,"result-link-events"),db,cmd,args,fallback)
