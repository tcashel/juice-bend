import Base
import ../src/cli.bend as Cli
import ../src/catalog.bend as Catalog
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

# Empty accepted snapshots are catalog-only synthetic metadata. Real append,
# rewrite, retained raw and complete identity checks belong to catalog.bend.
def add_versions(fuel: Nat,+db: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Store.exec(db,"INSERT INTO snapshots(generation,extent,records,accepted) VALUES(1,0,0,1)",[])
        add_versions(rest,db)

def fixture(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT INTO sources(id,provider,locator,latest) VALUES(1,'claude','synthetic://catalog-cli',1)",[])
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(1,1)",[])
    add_versions(100n,db)

def page(value: Cli.Page,offset: U32,count: Nat,more: Bool,first: String,name: String) -> IO(Unit):
  Cli.Page{from,+rows,available} = value
  assert(U32.is_eq(from,offset) && Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),count) &&
    Bool.not(Bool.xor(available,more)) && String.eq(Store.field(Store.first(rows),0n),first),name)

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{message}:
      IO.die(Json.Json,1,"Catalog CLI produced invalid JSON: " ++ message)

def result_json(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    assert(U32.is_eq(code,0),"catalog command exits successfully")
    parsed(Json.parse(String.trim(out)))

def run(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"command" <> args,"",65536,10000))

def good(self: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- run(self,args)
    result_json(result)

def bad_result(result: U32 & (String & String),message: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,message),name)

def bad(self: String,args: List<String>,message: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- run(self,args)
    bad_result(result,message,name)

def json_field(value: Json.Json,key: String,expected: String,name: String) -> IO(Unit):
  assert(String.eq(Json.encode(Json.field(value,key)),expected),name)

def commands(+self: String) -> IO(Unit):
  do IO<Unit>:
    +first : Json.Json <- good(self,["versions","1"])
    json_field(first,"columns","[\"snapshot\",\"generation\",\"extent\",\"records\",\"is_latest\"]","version columns are explicit")
    json_field(first,"offset","0","default version offset is numeric zero")
    json_field(first,"limit","100","version page limit is numeric 100")
    json_field(first,"has_more","true","first version page exposes lookahead")
    +second : Json.Json <- good(self,["versions","1","100"])
    json_field(second,"rows","[[\"1\",\"1\",\"0\",\"0\",\"0\"]]","second page preserves exact quoted integer cells")
    json_field(second,"has_more","false","last page disables Next")
    +current : Json.Json <- good(self,["latest","1"])
    json_field(current,"snapshot","\"101\"","latest resolves current source target")
    json_field(current,"anchor_snapshot","\"1\"","latest echoes exact requested anchor")
    bad(self,["versions"],"usage: versions","missing versions anchor rejected")
    bad(self,["latest","1","extra"],"usage: latest","extra latest argument rejected")
    bad(self,["versions","01"],"positive canonical","noncanonical anchor rejected")
    bad(self,["versions","1","4294967196"],"offset must be from","lookahead offset overflow rejected")
    bad(self,["versions","1","4294967296"],"offset must be an integer","unsigned offset overflow rejected")
    bad(self,["versions","999"],"accepted snapshot not found","absent version anchor fails")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +reader : U32 <- Store.open(".build/catalog-cli.sqlite")
    fixture(reader)
    initial : Cli.Page <- Cli.versions_page(reader,"1",0)
    page(initial,0,100n,False{},"100","exactly 100 versions has no next page")
    +writer : U32 <- Store.open(".build/catalog-cli.sqlite")
    Store.exec(reader,"BEGIN",[])
    initial_rows : List<&2,List<&2,Sql.Cell>> <- Catalog.versions(reader,"1",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,initial_rows),100n),"reader establishes original catalog snapshot")
    add_versions(1n,writer)
    Store.exec(writer,"UPDATE sources SET latest=101 WHERE id=1",[])
    old_more : Bool <- Cli.versions_more(reader,"1",0,True{})
    assert(Bool.not(old_more),"lookahead ignores concurrent catalog publication inside read transaction")
    Store.exec(reader,"COMMIT",[])
    next : Cli.Page <- Cli.versions_page(reader,"1",0)
    page(next,0,100n,True{},"101","new command sees concurrent accepted version")
    tail : Cli.Page <- Cli.versions_page(reader,"1",100)
    page(tail,100,1n,False{},"1","last catalog page reaches oldest snapshot")
    far : Cli.Page <- Cli.versions_page(reader,"1",4294967195)
    page(far,4294967195,0n,False{},"","largest safe lookahead offset stays exact")
    commands(self)
    Store.exec(writer,"UPDATE sources SET latest=NULL WHERE id=1",[])
    bad(self,["latest","1"],"Catalog unavailable","missing latest is not replaced with newest ID")
    IO.try(Unit,Sql.close(writer))
    IO.try(Unit,Sql.close(reader))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case self <> "command" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/catalog-cli.sqlite")
        Cli.command(db,"",command,rest)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Catalog CLI suite requires zero arguments or its own command child")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
