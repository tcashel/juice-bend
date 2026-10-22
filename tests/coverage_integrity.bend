import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/evidence.bend as Evidence

# An oversized physical line can have a valid JSON prefix. Its fragment flag is
# evidence metadata: changing that flag must not promote the prefix to a turn.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def resolved(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}:
      IO.pure(String,text)
    case Fail{error}:
      IO.die(String,1,error)

def action(db: U32,value: String,mode: String) -> IO(String):
  match mode:
    case "page":
      Store.page(db,value,0,1)
    case "why":
      Evidence.why(db,value,0,1)
    case "citation":
      do IO<String>:
        result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,value)
        resolved(result)
    case _:
      IO.die(String,2,"Invalid coverage fixture operation")

def child(+path: String,+snapshot: String,mode: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    text : String <- action(db,snapshot,mode)
    IO.print(text)
    IO.try(Unit,Sql.close(db))

def rejected(result: U32 & (String & String),mode: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(Bool.not(U32.is_eq(code,0)) && String.contains(out ++ err,"integrity"),
    mode ++ " rejects corrupt oversized coverage before interpreting raw fragment")

def check_child(self: String,path: String,snapshot: String,+mode: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[path,snapshot,mode],"",4096,10000))
    rejected(result,mode)

def suite(+self: String) -> IO(Unit):
  +prefix = {"{\"type\":\"user\",\"message\":{\"content\":\"must stay unsupported\"}}" : String}
  do IO<Unit>:
    +root : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(root,"juice-bend-test-coverage_integrity."),
      "Run this test using ./scripts/test in its isolated directory")
    +source : String = root ++ "/oversized-coverage.jsonl"
    +path : String = root ++ "/.build/coverage.sqlite"
    Store.write_text(source,"w",prefix ++ String.repeat(" ",Nat.sub(262144n,String.length(prefix))) ++ "trailing-invalid-data\n")
    +db : U32 <- Store.open(path)
    +snapshot : String <- Store.import_file(db,"claude",source)
    captured : Evidence.Verified <- Evidence.read_record(db,snapshot,0)
    +descriptor : String = Evidence.citation(captured,0)
    +before : String <- Store.page(db,snapshot,0,1)
    assert(String.contains(before,"oversized_record_fragment") &&
      Bool.not(String.contains(before,"must stay unsupported")),
      "valid JSON prefix inside an oversized physical line is unsupported")
    Store.exec(db,"UPDATE raw SET oversized=0 WHERE ordinal=0",[])
    IO.try(Unit,Sql.close(db))
    check_child(self,path,snapshot,"page")
    check_child(self,path,snapshot,"why")
    check_child(self,path,descriptor,"citation")

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> Nil{}:
      suite(self)
    case _ <> path <> snapshot <> mode <> Nil{}:
      child(path,snapshot,mode)
    case _:
      IO.die(Unit,2,"Invalid isolated coverage test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
