import Base
import ../src/cli.bend as Cli
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def status(result: U32 & (String & String),success: Bool,needle: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(Bool.not(Bool.xor(U32.is_eq(code,0),success)) && String.contains(out ++ err,needle),name)

def run(self: String,path: String,input: String) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),
    Process.run(self,["worker",path],input,8192,30000))

def read_closed(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(String):
  (file,result) = result
  do IO<String>:
    File.close(file)
    bytes : List<&2,U32> <- IO.try(List<&2,U32>,
      IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))
    Cli.displayed_decoded(Domain.decode(bytes))

def read(path: String,max: U32) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,max)
    read_closed(got)

def absent(result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"FAIL oversized displayed input created an output")
    case Fail{(code,_)}:
      assert(U32.is_eq(code,2),"oversized displayed input creates no destination")

def invalid_worker() -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(".build/invalid-utf8","r"))
    text : String <- Cli.displayed_read(1048577n,0,[],file)
    IO.print(text)

def suite(+self: String) -> IO(Unit):
  +text = String.repeat("x",4095n) ++ "Café é 中文 🧃\n" ++
    "Captured citation: {\"provider\":\"codex\",\"generation\":\"3\",\"snapshot\":\"4\"}\n" ++
    "Repository /synthetic/removed-repository; recorded candidate text only.\n"
  do IO<Unit>:
    result : U32 & (String & String) <- run(self,"displayed.md",text)
    status(result,True{},"\"verification\":\"not_reverified\"",
      "displayed export succeeds without resolving mutable Git or evidence")
    +exported : String <- read("displayed.md",16384)
    assert(String.ends_with(exported,text),
      "displayed export preserves exact Unicode and citation text across read chunks")
    assert(String.contains(exported,"does not re-resolve Git or perform a new evidence verification"),
      "displayed export states its original verification boundary")
    repeated : U32 & (String & String) <- run(self,"displayed.md","replacement")
    status(repeated,False{},"already exists","displayed export refuses existing destination")
    unchanged : String <- read("displayed.md",16384)
    assert(String.eq(unchanged,exported),"failed displayed export preserves existing destination")
    bounded : U32 & (String & String) <- run(self,"maximum.md",String.repeat("x",1048576n))
    status(bounded,True{},"\"exact_displayed_text\":true","displayed export accepts exactly one MiB")
    too_big : U32 & (String & String) <- run(self,"oversized.md",String.repeat("x",1048577n))
    status(too_big,False{},"exceeds 1048576","displayed export rejects input above one MiB")
    missing : Result<&1,&1,U32 & String,File> <- File.open("oversized.md","r")
    absent(missing)
    invalid_file : File <- IO.try(File,File.open(".build/invalid-utf8","w"))
    invalid_written : File & Result<&1,&1,U32 & String,Unit> <-
      File.write_bytes(invalid_file,[195,40])
    Store.write_closed(invalid_written)
    invalid : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["invalid"],"",8192,10000))
    status(invalid,False{},"not valid UTF-8","displayed export rejects malformed UTF-8")
    IO.print("CLI displayed export suite passed")

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "worker" <> path <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/cli.sqlite")
        Cli.run(db,".build",["export-displayed",path])
        IO.try(Unit,Sql.close(db))
    case _ <> "invalid" <> []:
      invalid_worker()
    case _:
      IO.die(Unit,2,"Invalid CLI test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
