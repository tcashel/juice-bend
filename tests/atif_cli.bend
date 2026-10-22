import Base
import ../src/cli.bend as Cli
import ../src/atif_command.bend as Command
import ../src/store.bend as S
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths
import ../src/json.bend as J
import ../src/domain.bend as Domain

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def json(value: Result<&2,&2,String,J.Json>) -> IO(J.Json):
  match value:
    case Done{value}: IO.pure(J.Json,value)
    case Fail{message}: IO.die(J.Json,1,"FAIL CLI JSON response: " ++ message)

def reply(value: U32 & (String & String)) -> IO(J.Json):
  (code,(out,err)) = value
  do IO<J.Json>:
    require(U32.is_eq(code,0) && String.is_empty(err),"actual CLI child exits successfully with no diagnostics")
    json(J.parse(out))

def rejected(value: U32 & (String & String),needle: String,label: String) -> IO(Unit):
  (code,(out,err)) = value
  require(U32.is_ne(code,0) && String.is_empty(out) && String.contains(err,needle),label)

def child(dbpath: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open_existing(dbpath,0))
    Cli.run(db,"unused-synthetic-root",args)
    IO.try(Unit,Sql.close(db))

def launch(self: String,db: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"cli" <> db <> args,"",65536,60000))

def canonical(+value: J.Json,snapshot: String,path: String,actual: String) -> IO(Unit):
  require(String.eq(J.get(value,"kind"),"atif_export") && String.eq(J.get(value,"schema_version"),"ATIF-v1.8") &&
    String.eq(J.get(value,"snapshot"),snapshot) && String.eq(J.get(value,"requested_path"),path) &&
    String.eq(J.get(value,"path"),actual) && Command.received_counts(value),"real CLI route binds exact snapshot requested literal path and canonical published receipt")

def text(value: Result<&2,&2,String,String>) -> IO(String):
  match value:
    case Done{text}: IO.pure(String,text)
    case Fail{message}: IO.die(String,1,message)

def read_result(value: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(String):
  (file,result) = value
  do IO<String>:
    File.close(file)
    bytes : List<&2,U32> <- IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))
    text(Domain.decode(bytes))

def read(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    value : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65536)
    read_result(value)

def absent(value: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match value:
    case Fail{_}: IO.print("PASS malformed CLI arguments create no destination")
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL malformed CLI arguments created a destination")

def user(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"atif-command-session\",\"message\":{\"content\":" ++ J.quote(text) ++ "}}\n"

def removed(value: U32 & (String & String)) -> IO(Unit):
  (code,(_,err)) = value
  require(U32.is_eq(code,0) && String.is_empty(err),"only synthetic provider source is removed before actual CLI export")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- S.open(".build/atif-cli.sqlite")
    S.write_text("command.jsonl","w",user("command-first Café 中文 🙂") ++ user("command-last"))
    +snapshot : String <- S.import_file(db,"claude","command.jsonl")
    S.write_text("command.jsonl","a",user("newer-not-selected"))
    +newer : String <- S.import_file(db,"claude","command.jsonl")
    require(Bool.not(String.eq(snapshot,newer)),"actual CLI fixture distinguishes pinned old and newer accepted snapshots")
    IO.try(Unit,Sql.close(db))
    +dbpath : String <- Paths.resolve(".build/atif-cli.sqlite")
    removal : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--","command.jsonl"],"",4096,2000))
    removed(removal)
    +destination : String = "literal ; $(not-a-command) café.atif.json"
    +actual : String <- Paths.destination(destination)
    raw : U32 & (String & String) <- launch(self,dbpath,["export-atif",snapshot,destination])
    +value : J.Json <- reply(raw)
    canonical(value,snapshot,destination,actual)
    require(String.eq(J.get(value,"records"),"2") && String.eq(J.get(value,"steps"),"2"),"real command exports the complete exact old snapshot")
    +exported : String <- read(actual)
    +doc : J.Json <- json(J.parse(exported))
    require(String.eq(J.get(doc,"schema_version"),"ATIF-v1.8") && String.contains(exported,"command-first Café 中文 🙂") && String.contains(exported,"command-last") && Bool.not(String.contains(exported,"newer-not-selected")),"published JSON retains all old bodies after source loss without newer substitution")
    again : U32 & (String & String) <- launch(self,dbpath,["export-atif",snapshot,destination])
    rejected(again,"destination exists","real CLI refuses a preexisting destination instead of clobbering it")
    unchanged : String <- read(actual)
    require(String.eq(exported,unchanged),"no-clobber CLI refusal leaves exact published bytes intact")
    malformed : U32 & (String & String) <- launch(self,dbpath,["export-atif",snapshot,"not-published.atif.json","extra"])
    rejected(malformed,"usage: export-atif","actual command rejects extra arguments before publication")
    empty : Result<&1,&1,U32 & String,File> <- File.open("not-published.atif.json","r")
    absent(empty)
    bad_id : U32 & (String & String) <- launch(self,dbpath,["export-atif","07","not-published.atif.json"])
    rejected(bad_id,"usage: export-atif","actual command rejects noncanonical snapshot identity")

def argv(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "cli" <> db <> rest: child(db,rest)
    case _: IO.die(Unit,2,"Invalid synthetic CLI test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
