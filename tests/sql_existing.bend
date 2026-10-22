import Base
import ../src/sql.bend as Sql

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.pure(Unit,Unit{})
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def process_result(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,_) = result
  require(U32.is_eq(code,0),label)

def process(program: String,args: List<String>,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(program,args,"",4096,2000))
    process_result(result,label)

def exec(db: U32,sql: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- IO.try(List<&2,List<&2,Sql.Cell>>,Sql.query(db,sql,[],0))
    return Unit{}

def scalar_rows(rows: List<&2,List<&2,Sql.Cell>>,wanted: String,label: String) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{value}]]: assert(String.eq(value,wanted),label)
    case _: assert(False{},label)

def scalar(db: U32,sql: String,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- IO.try(List<&2,List<&2,Sql.Cell>>,Sql.query(db,sql,[],1))
    scalar_rows(rows,wanted,label)

def query_failed(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,code: U32,label: String) -> IO(Unit):
  match result:
    case Fail{(actual,_)}: assert(U32.is_eq(U32.and(actual,255),code),label)
    case Done{_}: assert(False{},label)

def open_failed(result: Result<&1,&1,U32 & String,U32>,code: U32,label: String) -> IO(Unit):
  match result:
    case Fail{(actual,_)}: require(U32.is_eq(U32.and(actual,255),code),label)
    case Done{token}:
      do IO<Unit>:
        IO.try(Unit,Sql.close(token))
        require(False{},label)

def failure(path: String,mode: U32,code: U32,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,U32> <- Sql.open_existing(path,mode)
    open_failed(result,code,label)

def absent_result(result: Result<&1,&1,U32 & String,File>,label: String) -> IO(Unit):
  match result:
    case Fail{(code,_)}: assert(U32.is_eq(code,2),label)
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        assert(False{},label)

def absent(path: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent_result(result,label)

def close_failed(result: Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  match result:
    case Fail{(code,_)}: assert(U32.is_eq(code,21),"double close refuses retired existing-open token")
    case Done{_}: assert(False{},"double close refuses retired existing-open token")

def repeated_failures(left: Nat,+path: String) -> IO(Unit):
  match left:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        failure(path,1,14,"repeated missing open must fail CANTOPEN without leaking a slot")
        repeated_failures(rest,path)

def open_many(left: Nat,+path: String,tokens: List<&2,U32>) -> IO(List<&2,U32>):
  match left:
    case 0n: IO.pure(List<&2,U32>,tokens)
    case 1n+rest:
      do IO<List<&2,U32>>:
        token : U32 <- IO.try(U32,Sql.open_existing(path,0))
        open_many(rest,path,token <> tokens)

def close_many(tokens: List<&2,U32>) -> IO(Unit):
  match tokens:
    case Nil{}: IO.pure(Unit,Unit{})
    case Con{token,rest}:
      do IO<Unit>:
        IO.try(Unit,Sql.close(token))
        close_many(rest)

def registry(+path: String,missing: String) -> IO(Unit):
  do IO<Unit>:
    repeated_failures(130n,missing)
    tokens : List<&2,U32> <- open_many(64n,path,[])
    failure(path,0,13,"65th live connection reaches bounded registry")
    close_many(tokens)
    token : U32 <- IO.try(U32,Sql.open_existing(path,1))
    IO.try(Unit,Sql.close(token))
    assert(True{},"130 failed opens preserve all64 slots and closed slots remain reusable")

def mode_and_lifetime(+path: String) -> IO(Unit):
  do IO<Unit>:
    +readonly : U32 <- IO.try(U32,Sql.open_existing(path,0))
    scalar(readonly,"SELECT count(*) FROM probe","1","read-only existing open reads original data")
    denied : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <-
      Sql.query(readonly,"INSERT INTO probe VALUES(2)",[],0)
    query_failed(denied,8,"read-only existing open refuses mutation")
    scalar(readonly,"SELECT count(*) FROM probe","1","read-only write refusal preserves data and handle")
    IO.try(Unit,Sql.close(readonly))
    +writable : U32 <- IO.try(U32,Sql.open_existing(path,1))
    assert(Bool.not(U32.is_eq(readonly,writable)),"existing-open tokens are never reused after close")
    stale : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(readonly,"SELECT 1",[],1)
    query_failed(stale,21,"stale token cannot address a reused registry slot")
    twice : Result<&1,&1,U32 & String,Unit> <- Sql.close(readonly)
    close_failed(twice)
    exec(writable,"INSERT INTO probe VALUES(2)")
    scalar(writable,"SELECT count(*) FROM probe","2","read-write existing open writes successfully")
    IO.try(Unit,Sql.close(writable))
    +again : U32 <- IO.try(U32,Sql.open_existing(path,0))
    scalar(again,"SELECT count(*) FROM probe","2","read-write change persists after reopening read-only")
    IO.try(Unit,Sql.close(again))

def suite(+directory: String) -> IO(Unit):
  +path = directory ++ "/database.sqlite"
  +missing = directory ++ "/missing.sqlite"
  do IO<Unit>:
    process("/bin/mkdir",["-m","700",directory],"create fresh private synthetic test root")
    failure(missing,0,14,"read-only missing open fails")
    failure(missing,1,14,"read-write missing open fails")
    absent(missing,"neither access mode creates a missing database")
    failure(missing,2,21,"unsupported mode is refused before open")
    failure(missing,4294967295,21,"maximum invalid U32 mode is refused before open")
    absent(missing,"invalid modes do not create a database")
    +created : U32 <- IO.try(U32,Sql.open(path))
    exec(created,"CREATE TABLE probe(value INTEGER NOT NULL)")
    exec(created,"INSERT INTO probe VALUES(1)")
    IO.try(Unit,Sql.close(created))
    process("/bin/ln",["-s","database.sqlite",directory ++ "/linked.sqlite"],"create synthetic leaf symlink")
    process("/bin/ln",["-s","absent-target.sqlite",directory ++ "/dangling.sqlite"],"create synthetic dangling symlink")
    failure(directory ++ "/linked.sqlite",0,14,"read-only refuses a leaf symlink")
    failure(directory ++ "/linked.sqlite",1,14,"read-write refuses a leaf symlink")
    failure(directory ++ "/dangling.sqlite",0,14,"read-only refuses a dangling symlink")
    failure(directory ++ "/dangling.sqlite",1,14,"read-write refuses a dangling symlink")
    absent(directory ++ "/absent-target.sqlite","dangling link target remains absent after both open modes")
    mode_and_lifetime(path)
    registry(path,missing)
    absent(missing,"repeated failed opens never provision a missing database")

def main() -> IO(Unit):
  do IO<Unit>:
    nonce : U32 <- IO.try(U32,IO.random_u32())
    suite(".build/sql-existing-" ++ U32.show(nonce))
