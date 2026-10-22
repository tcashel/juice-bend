import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql

# Sparse fixture creation uses one literal OS utility. All size assertions,
# address checks and production-import verification are Bend.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def command_result(result: U32 & (String & String)) -> IO(Unit):
  (code,(_,err)) = result
  Store.checked(U32.is_eq(code,0),"Sparse fixture command failed: " ++ err)

def command(program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program,args,"",4096,5000))
    command_result(result)

def size_result(result: Result<&1,&1,U32 & String,U32>,expected: U32,
  reject: Bool) -> IO(Unit):
  match result reject:
    case Done{size} False{}:
      assert(U32.is_eq(size,expected),"File.size reports UINT32_MAX exactly")
    case Fail{(code,error)} True{}:
      assert(U32.is_ne(code,0) && String.contains(String.to_lower(error),"large"),
        "File.size explicitly rejects unsupported sparse size")
    case _ _:
      IO.die(Unit,1,"File.size accepted a wrapped size or refused a supported boundary")

def sized(got: File & Result<&1,&1,U32 & String,U32>,expected: U32,
  reject: Bool) -> IO(Unit):
  (file,result) = got
  do IO<Unit>:
    File.close(file)
    size_result(result,expected,reject)

def check_size(path: String,expected: U32,reject: Bool) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    sized(got,expected,reject)

def boundary_bytes(got: File & Result<&1,&1,U32 & String,List<&2,U32>>,
  +eof: Bool) -> IO(Unit):
  (file,result) = got
  do IO<Unit>:
    File.close(file)
    bytes : List<&2,U32> <- IO.try(List<&2,U32>,
      IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))
    assert(Nat.is_eq(List.length(&2,U32,bytes),Bool.pick(Nat,eof,0n,1n)),
      Bool.pick(String,eof,"read_at UINT32_MAX is EOF, not wrapped zero",
        "read_at UINT32_MAX minus one reads final sparse byte"))

def read_boundary(path: String,+eof: Bool) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,List<&2,U32>> <-
      File.read_at(file,Bool.pick(U32,eof,4294967295,4294967294),1)
    boundary_bytes(got,eof)

def child(path: String,source: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(path)
    snapshot : String <- Store.import_file(db,"claude",source)
    IO.die(Unit,1,"Unexpected accepted oversized snapshot " ++ snapshot)

def rejected_import(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  +message = String.append(out,err)
  assert(U32.is_ne(code,0) && String.contains(String.to_lower(message),"large") &&
    Bool.not(String.contains(message,"Unexpected accepted")),
    "production capture rejects source at 2^32 before publication")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +root : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(root,"juice-bend-test-file_limits."),
      "Run this test with scripts/test in its isolated directory")
    +maximum : String = root ++ "/max-source.jsonl"
    +overflow : String = root ++ "/overflow-source.jsonl"
    +overflow_one : String = root ++ "/overflow-plus-one.jsonl"
    +database : String = root ++ "/.build/limits.sqlite"
    command("/usr/bin/truncate",["-s","4294967295",maximum])
    command("/usr/bin/truncate",["-s","4294967296",overflow])
    command("/usr/bin/truncate",["-s","4294967297",overflow_one])
    check_size(maximum,4294967295,False{})
    read_boundary(maximum,False{})
    read_boundary(maximum,True{})
    check_size(overflow,0,True{})
    check_size(overflow_one,0,True{})
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[database,overflow],"",4096,10000))
    rejected_import(result)
    +db : U32 <- Store.open(database)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM snapshots),(SELECT count(*) FROM raw),(SELECT count(*) FROM sources)",
      [],1)
    +row : List<&2,Sql.Cell> = Store.first(rows)
    assert(String.eq(Store.field(row,0n),"0") && String.eq(Store.field(row,1n),"0") &&
      String.eq(Store.field(row,2n),"0"),
      "unsupported source creates no snapshot, raw bytes or registered source")
    IO.try(Unit,Sql.close(db))
    command("/bin/rm",["--",maximum,overflow,overflow_one])

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> Nil{}:
      suite(self)
    case _ <> path <> source <> Nil{}:
      child(path,source)
    case _:
      IO.die(Unit,2,"Invalid isolated file boundary arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
