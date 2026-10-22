import Base
import ../src/gui.bend as Gui
import ../src/json.bend as Json
import ../src/brief_cli.bend as BriefCLI
import ../src/continuation_brief.bend as Brief

# Exercise the actual GUI job functions through an owned copy of this native
# executable. The child only echoes literal argv and bounded stdin as JSON; it
# never opens a library, invokes a shell, or interprets captured text as code.
# Expected wire arguments below are explicit, independent of route categories.
type Example is Data:
  Example{label: String,args: List<&2,String>,wire: List<&2,String>,input: String}

def require(okay: Bool,label: String) -> IO(Unit):
  match okay:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL GUI job dispatch: " ++ label)

def directory() -> String: "/juice-bend-synthetic-dispatch/no-library"
def quota_root() -> String: "/juice-bend-synthetic-dispatch/quota root"
def body() -> String: "café 中文 🙂\n\"quoted\"; $(literal) 'text'\n"

def quoted(args: List<&2,String>) -> List<&2,String>:
  match args:
    case []: []
    case arg <> rest: Json.quote(arg) <> quoted(rest)

def echo(args: List<&2,String>,input: String) -> String:
  "{\"argv\":[" ++ String.join(quoted(args),",") ++ "],\"stdin\":" ++ Json.quote(input) ++ "}"

def echoed(reply: Gui.Reply,args: List<&2,String>,input: String) -> Bool:
  Gui.Reply{value} = reply
  match value:
    case Fail{_}: False{}
    case Done{value}: String.eq(Json.encode(value),echo(args,input))

def failed(reply: Gui.Reply) -> Bool:
  Gui.Reply{value} = reply
  match value:
    case Fail{message}: Bool.not(String.is_empty(message))
    case Done{_}: False{}

def read_examples() -> List<&2,Example>:
  [Example{"read quota removes request identity and uses selected root",
    ["quota-view",quota_root(),"ticket-31","7","status","literal ; $()"],
    ["--data-dir",quota_root(),"quota","status","literal ; $()"],""},
   Example{"read quota accepts an empty operation tail",
    ["quota-view",quota_root(),"ticket","0"],["--data-dir",quota_root(),"quota"],""},
   Example{"brief prepare sends body only on stdin",["brief-prepare",body()],
    ["--data-dir",directory(),"brief-prepare"],body()},
   Example{"brief check keeps its exact command and stdin",["brief-check",body()],
    ["--data-dir",directory(),"brief-check"],body()},
   Example{"latest view strips only the four GUI scope operands",
    ["latest-view","9007199254740993","claude","/repo space","user","2026-10-21"],
    ["--data-dir",directory(),"latest","9007199254740993"],""},
   Example{"read attachment roots forwards literal tail",["attachment-roots","0","40"],
    ["--data-dir",directory(),"attachment-roots","0","40"],""},
   Example{"read captured attachment forwards empty tail",["captured-attachment"],
    ["--data-dir",directory(),"captured-attachment"],""},
   Example{"read attachment inventory forwards filters",["attachments","12","café 中文 🙂",""],
    ["--data-dir",directory(),"attachments","12","café 中文 🙂",""],""},
   Example{"read session scope forwards empty tail",["session-scope"],
    ["--data-dir",directory(),"session-scope"],""},
   Example{"read why scope forwards tail",["why-scope","11","40","x"],
    ["--data-dir",directory(),"why-scope","11","40","x"],""},
   Example{"read activity scope forwards tail",["activity-scope","12"],
    ["--data-dir",directory(),"activity-scope","12"],""},
   Example{"read relations scope forwards tail",["relations-scope","13"],
    ["--data-dir",directory(),"relations-scope","13"],""},
   Example{"read relations page forwards tail",["relations-page","14","15"],
    ["--data-dir",directory(),"relations-page","14","15"],""},
   Example{"unknown read retains literal argv",["unknown ; $()",body(),""],
    ["--data-dir",directory(),"unknown ; $()",body(),""],""},
   Example{"short quota falls back unchanged",["quota-view",quota_root(),"ticket"],
    ["--data-dir",directory(),"quota-view",quota_root(),"ticket"],""},
   Example{"empty brief operands fall back unchanged",["brief-prepare"],
    ["--data-dir",directory(),"brief-prepare"],""},
   Example{"extra brief operand falls back instead of becoming stdin",["brief-check",body(),"extra"],
    ["--data-dir",directory(),"brief-check",body(),"extra"],""},
   Example{"short latest operands fall back unchanged",["latest-view","1","p","r","role"],
    ["--data-dir",directory(),"latest-view","1","p","r","role"],""},
   Example{"extra latest operand falls back unchanged",["latest-view","1","p","r","role","after","extra"],
    ["--data-dir",directory(),"latest-view","1","p","r","role","after","extra"],""},
   Example{"near-match command is not a route prefix",["brief-prepare-extra",body()],
    ["--data-dir",directory(),"brief-prepare-extra",body()],""}]

def write_examples() -> List<&2,Example>:
  [Example{"ATIF preserves snapshot and destination",["export-atif","9007199254740993","/literal path;$().json"],
    ["--data-dir",directory(),"export-atif","9007199254740993","/literal path;$().json"],""},
   Example{"write quota removes request identity and uses selected root",["quota-view",quota_root(),"ticket","0","refresh"],
    ["--data-dir",quota_root(),"quota","refresh"],""},
   Example{"display export sends body on stdin",["export-displayed","/literal path.txt",body()],
    ["--data-dir",directory(),"export-displayed","/literal path.txt"],body()},
   Example{"brief export sends body on stdin",["export-brief-text","/brief 中文.txt",body()],
    ["--data-dir",directory(),"export-brief-text","/brief 中文.txt"],body()},
   Example{"preference read retains zero operands",["refresh-preferences"],
    ["--data-dir",directory(),"refresh-preferences"],""},
   Example{"preference update retains two operands",["refresh-preferences-set","true","30"],
    ["--data-dir",directory(),"refresh-preferences-set","true","30"],""},
   Example{"attachment capture forwards its tail",["capture-attachment","1","2","3","4"],
    ["--data-dir",directory(),"capture-attachment","1","2","3","4"],""},
   Example{"attachment root add preserves literal path",["attachment-root-add","/folder with ; $(text)"],
    ["--data-dir",directory(),"attachment-root-add","/folder with ; $(text)"],""},
   Example{"attachment root enable forwards empty tail",["attachment-root-enable"],
    ["--data-dir",directory(),"attachment-root-enable"],""},
   Example{"attachment root disable forwards revision",["attachment-root-disable","1","2"],
    ["--data-dir",directory(),"attachment-root-disable","1","2"],""},
   Example{"captured attachment export forwards literal destination",["export-captured-attachment","1","/out path"],
    ["--data-dir",directory(),"export-captured-attachment","1","/out path"],""},
   Example{"empty write retains ordinary worker behavior",[],["--data-dir",directory()],""},
   Example{"unknown write retains literal operands",["unrecognized",body(),""],
    ["--data-dir",directory(),"unrecognized",body(),""],""},
   Example{"short ATIF arity falls back unchanged",["export-atif","1"],
    ["--data-dir",directory(),"export-atif","1"],""},
   Example{"extra ATIF arity falls back unchanged",["export-atif","1","/out","extra"],
    ["--data-dir",directory(),"export-atif","1","/out","extra"],""},
   Example{"short write quota falls back unchanged",["quota-view",quota_root(),"ticket"],
    ["--data-dir",directory(),"quota-view",quota_root(),"ticket"],""},
   Example{"short display export arity falls back unchanged",["export-displayed","/out"],
    ["--data-dir",directory(),"export-displayed","/out"],""},
   Example{"extra brief export arity keeps text in argv",["export-brief-text","/out",body(),"extra"],
    ["--data-dir",directory(),"export-brief-text","/out",body(),"extra"],""},
   Example{"short source add is not wrapped as a source change",["source-add","claude"],
    ["--data-dir",directory(),"source-add","claude"],""},
   Example{"extra source disable is not wrapped as a source change",["source-disable","claude","/root","extra"],
    ["--data-dir",directory(),"source-disable","claude","/root","extra"],""},
   Example{"extra preferences operand keeps ordinary write fallback",["refresh-preferences","extra"],
    ["--data-dir",directory(),"refresh-preferences","extra"],""},
   Example{"short preference update keeps ordinary write fallback",["refresh-preferences-set","true"],
    ["--data-dir",directory(),"refresh-preferences-set","true"],""},
   Example{"extra preference update keeps ordinary write fallback",["refresh-preferences-set","true","30","extra"],
    ["--data-dir",directory(),"refresh-preferences-set","true","30","extra"],""}]

def example(+program: String,write: Bool,value: Example) -> IO(Unit):
  Example{label,+args,wire,input} = value
  do IO<Unit>:
    reply : Gui.Reply <- Bool.pick(IO(Gui.Reply),write,Gui.write_job(program,directory(),args),Gui.read_job(program,directory(),args))
    require(echoed(reply,wire,input),label)

def examples(values: List<&2,Example>,+program: String,+write: Bool) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        example(program,write,value)
        examples(rest,program,write)

def changed(reply: Gui.Reply,command: String) -> Bool:
  Gui.Reply{value} = reply
  match value:
    case Fail{_}: False{}
    case Done{+value}:
      String.eq(Json.get(value,"kind"),"source_change") &&
      String.eq(Json.encode(Json.field(value,"ack")),echo(["--data-dir",directory(),command,"claude","/root 中文 ; $()"],"")) &&
      String.eq(Json.encode(Json.field(value,"sources")),echo(["--data-dir",directory(),"sources"],""))

def special(+program: String) -> IO(Unit):
  do IO<Unit>:
    empty : Gui.Reply <- Gui.read_job(program,directory(),[])
    require(failed(empty),"empty read preserves Client refusal before launch")
    added : Gui.Reply <- Gui.write_job(program,directory(),["source-add","claude","/root 中文 ; $()"])
    require(changed(added,"source-add"),"source add confirms original acknowledgement and fresh source list")
    disabled : Gui.Reply <- Gui.write_job(program,directory(),["source-disable","claude","/root 中文 ; $()"])
    require(changed(disabled,"source-disable"),"source disable confirms original acknowledgement and fresh source list")

# Output bounds distinguish routes whose ordinary wire arguments are identical.
# The child emits known spaces before valid JSON. These are finite output-limit
# probes, not deadline/performance measurements; deadlines are checked in review.
def bound_case(+program: String,write: Bool,+dir: String,+args: List<&2,String>,refused: Bool,label: String) -> IO(Unit):
  do IO<Unit>:
    +reply : Gui.Reply <- Bool.pick(IO(Gui.Reply),write,Gui.write_job(program,dir,args),Gui.read_job(program,dir,args))
    require(Bool.pick(Bool,refused,failed(reply),Bool.not(failed(reply))),label)

def bounds(+program: String) -> IO(Unit):
  do IO<Unit>:
    bound_case(program,True{},"/juice-bend-synthetic-dispatch/pad70000",["export-atif","1","/out"],True{},"exact ATIF route retains64KiB acknowledgement bound")
    bound_case(program,True{},"/juice-bend-synthetic-dispatch/pad70000",["export-atif","1","/out","extra"],False{},"malformed ATIF falls back to ordinary1MiB output bound")
    bound_case(program,False{},"/juice-bend-synthetic-dispatch/pad140000",["brief-prepare",body()],True{},"exact brief route retains128KiB output bound")
    bound_case(program,False{},"/juice-bend-synthetic-dispatch/pad140000",["brief-prepare",body(),"extra"],False{},"malformed brief retains Client1MiB output bound")
    bound_case(program,False{},directory(),["quota-view","/juice-bend-synthetic-dispatch/pad140000","t","0"],True{},"quota uses selected root and128KiB output bound")
    bound_case(program,False{},"/juice-bend-synthetic-dispatch/pad270000",["captured-attachment","1"],True{},"attachment read retains256KiB output bound")
    bound_case(program,True{},"/juice-bend-synthetic-dispatch/pad270000",["capture-attachment","1"],True{},"attachment write retains256KiB output bound")
    bound_case(program,False{},"/juice-bend-synthetic-dispatch/pad270000",["attachments","1"],False{},"scoped inventory remains1MiB rather than attachment-worker bound")
    bound_case(program,False{},"/juice-bend-synthetic-dispatch/warn",["captured-attachment"],True{},"attachment route refuses success with stderr")
    bound_case(program,False{},"/juice-bend-synthetic-dispatch/warn",["ordinary"],False{},"ordinary Client success preserves its stderr behavior")
    bound_case(program,False{},directory(),["quota-view","/juice-bend-synthetic-dispatch/warn","t","0"],True{},"quota route refuses success with stderr")

def padding(+dir: String) -> Nat:
  Bool.pick(Nat,String.eq(dir,"/juice-bend-synthetic-dispatch/pad70000"),70000n,
    Bool.pick(Nat,String.eq(dir,"/juice-bend-synthetic-dispatch/pad140000"),140000n,
      Bool.pick(Nat,String.eq(dir,"/juice-bend-synthetic-dispatch/pad270000"),270000n,0n)))

def child_input(args: List<&2,String>,+dir: String,result: Result<&2,&2,Brief.Problem,String>) -> IO(Unit):
  match result:
    case Fail{_}: IO.die(Unit,2,"Synthetic echo child could not read bounded stdin")
    case Done{input}:
      do IO<Unit>:
        IO.write(String.repeat(" ",padding(dir)))
        IO.print(echo(args,input))
        Bool.pick(IO(Unit),String.eq(dir,"/juice-bend-synthetic-dispatch/warn"),IO.print_err("synthetic stderr"),IO.pure(Unit,Unit{}))

def child(+args: List<&2,String>,dir: String) -> IO(Unit):
  do IO<Unit>:
    input : Result<&2,&2,Brief.Problem,String> <- BriefCLI.stdin()
    child_input(args,dir,input)

def suite(+program: String) -> IO(Unit):
  do IO<Unit>:
    examples(read_examples(),program,False{})
    examples(write_examples(),program,True{})
    special(program)
    bounds(program)
    IO.print("Completed actual GUI job dispatch checks; no window, database or timeout-duration acceptance.")

def shared_args(args: List<String>) -> List<&2,String>:
  match args:
    case Nil{}: []
    case Con{head,tail}: head <> shared_args(tail)

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{program,Nil{}}: suite(program)
    case Con{_,Con{"--data-dir",Con{+dir,rest}}}: child("--data-dir" <> dir <> shared_args(rest),dir)
    case _: IO.die(Unit,2,"Synthetic dispatcher accepts only its owned child invocation")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
