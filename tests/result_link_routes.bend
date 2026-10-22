import Base
import ./result_links.bend as T
import ../src/result_commands.bend as Commands
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/result_events.bend as E
import ../src/result_links_cli.bend as LC
import ../src/relations.bend as R
import ../src/json.bend as J

def response(value: U32 & (String & String),kind: String) -> IO(Unit):
  (code,(out,err)) = value
  do IO<Unit>:
    T.assert(U32.is_eq(code,0) && String.is_empty(err),"CLI child worker exits successfully without stderr")
    T.assert(String.contains(out,"\"kind\":\"" ++ kind ++ "\""),"CLI dispatcher routes exact child command to typed worker")

def route_candidate(self: String,reference: R.SnapshotRef) -> IO(Unit):
  R.SnapshotRef{provider,source,generation,snapshot,extent} = reference
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,
      ["result-link-page",provider,source,generation,snapshot,extent,"1","0","","0","15","claude","/synthetic/repo","tool",""],"",1048576,60000))
    response(result,"recorded_child_result")

def arguments(args: List<String>) -> String:
  match args:
    case []: ""
    case value <> []: value
    case value <> rest: value ++ "|" ++ arguments(rest)

def fallback(mode: String,args: List<String>) -> IO(Unit):
  IO.print("fallback:" ++ mode ++ ":" ++ arguments(args))

def unknown(value: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = value
  T.assert(U32.is_eq(code,0) && String.eq(out,"fallback:result-link-events-extra:x|y\n") && String.is_empty(err),
    "unknown child-like labels preserve exact command and arguments for existing CLI fallback")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    T.fixture("/bin/mkdir",["-p",".build/route/subagents"])
    +db : U32 <- Store.open(".build/routes.sqlite")
    +snapshot : String <- T.capture(db,"claude",".build/route.jsonl",T.metadata("parent","/synthetic/repo") ++ T.result_record("\"abc\"",T.result_block()))
    child : String <- T.capture(db,"claude",".build/route/subagents/agent-abc.jsonl",T.metadata("parent","/synthetic/repo"))
    +reference : R.SnapshotRef <- T.reference(db,snapshot)
    IO.try(Unit,Sql.close(db))
    event_args : List<String> = ["result-link-events",snapshot,"0","2","0","0","claude","/synthetic/repo","tool",""]
    event_result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,event_args,"",1048576,60000))
    response(event_result,"recorded_child_events")
    route_candidate(self,reference)
    passthrough : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["result-link-events-extra","x","y"],"",1048576,60000))
    unknown(passthrough)

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> command <> args:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/routes.sqlite")
        Commands.command(db,command,args,mode => rest => fallback(mode,rest))
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"missing executable path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
