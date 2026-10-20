import Base
import ../src/cli.bend as Cli
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/query.bend as Query

# Listing-only fixtures deliberately populate synthetic projections directly.
# They exercise ordering, filtering and read transactions, not raw preservation.
# scripts/test supplies the isolated working directory and its .build folder.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def identity(base: Nat,n: U32) -> String:
  Nat.show(Nat.add(base,U32.to_nat(n)))

def source(db: U32,+id: String,provider: String) -> IO(Unit):
  Store.exec(db,"INSERT INTO sources(id,provider,locator,latest) VALUES(?,?,?,?)",
    [Sql.Cell.Integer{id},Sql.Cell.Text{provider},
     Sql.Cell.Text{"synthetic://list-pagination/" ++ id},Sql.Cell.Integer{id}])

def source_rows_checked(fuel: Nat,+db: U32,+base: Nat,+at: U32,+count: U32,done: Bool) -> IO(Unit):
  match fuel done:
    case _ True{}:
      IO.pure(Unit,Unit{})
    case 0n False{}:
      IO.die(Unit,1,"Synthetic source fixture budget exhausted")
    case 1n+rest False{}:
      do IO<Unit>:
        source(db,identity(base,at),"claude")
        source_rows_checked(rest,db,base,U32.add(at,1),count,U32.is_ge(at,count))

def source_rows(+db: U32,+base: Nat,+at: U32,+count: U32) -> IO(Unit):
  source_rows_checked(Nat.add(U32.to_nat(count),1n),db,base,at,count,U32.is_gt(at,count))

def index_all(db: U32) -> IO(Unit):
  Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) SELECT rowid,body,arguments,result,tool,snapshot,ordinal,event FROM events",[])

def fixture(+db: U32,base: Nat,count: U32) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    source_rows(db,base,1,count)
    Store.exec(db,"INSERT INTO generations(id,source) SELECT id,id FROM sources",[])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent,records,accepted) SELECT id,id,1,1,1 FROM sources",[])
    Store.exec(db,"INSERT INTO events SELECT id,0,0,'user','pagingneedle','','','','','/synthetic/list-target','listing-fixture','2026-10-02T00:00:00.000000000Z','','','','complete' FROM sources",[])
    index_all(db)
    Store.exec(db,"COMMIT",[])

def filters(query: String) -> Query.Filters:
  Query.Filters{query,"claude","/synthetic/list-target","user","2026-10-02"}

def history_filters() -> Query.Filters:
  Query.Filters{"","claude","/synthetic/list-target","",""}

def refs(rows: List<&2,List<&2,Sql.Cell>>,+history: Bool) -> String:
  match rows:
    case []:
      ""
    case +row <> rest:
      Store.field(row,Bool.pick(Nat,history,3n,0n)) ++
        Bool.pick(String,history,";",":" ++ Store.field(row,1n) ++ ":" ++ Store.field(row,2n) ++ ";") ++ refs(rest,history)

def expected_refs(count: Nat,+base: Nat,+first: U32,+history: Bool) -> String:
  match count:
    case 0n:
      ""
    case 1n+rest:
      identity(base,first) ++ Bool.pick(String,history,";",":0:0;") ++
        expected_refs(rest,base,U32.sub(first,1),history)

def expected_page(base: Nat,total: U32,offset: U32,count: U32,history: Bool) -> String:
  match count:
    case 0:
      ""
    case n:
      expected_refs(U32.to_nat(n),base,U32.sub(total,offset),history)

def page(+value: Cli.Page,base: Nat,total: U32,+offset: U32,+count: U32,
  more: Bool,+history: Bool,+label: String) -> IO(Unit):
  Cli.Page{actual_offset,+rows,has_more} = value
  do IO<Unit>:
    assert(U32.is_eq(actual_offset,offset) &&
      Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(count)),
      label ++ " exact offset and bounded row count")
    assert(Bool.not(Bool.xor(has_more,more)),label ++ " exact lookahead availability")
    assert(String.eq(refs(rows,history),expected_page(base,total,offset,count,history)),
      label ++ " independent ordered occurrence identities")

def boundary_pages(+db: U32,+total: U32,first: U32,first_more: Bool,
  second: U32,second_more: Bool,third: U32,+history: Bool) -> IO(Unit):
  +selected = Bool.pick(Query.Filters,history,history_filters(),filters("pagingneedle"))
  +label = Bool.pick(String,history,"history ","search ") ++ U32.show(total)
  do IO<Unit>:
    a : Cli.Page <- Cli.list_page(db,history,selected,0)
    page(a,0n,total,0,first,first_more,history,label ++ " first page")
    b : Cli.Page <- Cli.list_page(db,history,selected,100)
    page(b,0n,total,100,second,second_more,history,label ++ " second page")
    c : Cli.Page <- Cli.list_page(db,history,selected,200)
    page(c,0n,total,200,third,False{},history,label ++ " third page")

def boundary_case(+total: U32,+first: U32,+first_more: Bool,
  +second: U32,+second_more: Bool,+third: U32) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/list-boundary-" ++ U32.show(total) ++ ".sqlite")
    fixture(db,0n,total)
    boundary_pages(db,total,first,first_more,second,second_more,third,True{})
    boundary_pages(db,total,first,first_more,second,second_more,third,False{})
    IO.try(Unit,Sql.close(db))

def event(+db: U32,+id: String,+ordinal: U32,role: String,repo: String,date: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT INTO events VALUES(?,?,0,?,'pagingneedle','','','','',?,'listing-fixture',?,'','','','complete')",
      [Sql.Cell.Integer{id},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Text{role},Sql.Cell.Text{repo},Sql.Cell.Text{date}])
    Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) SELECT rowid,body,arguments,result,tool,snapshot,ordinal,event FROM events WHERE snapshot=? AND ordinal=? AND event=0",
      [Sql.Cell.Integer{id},Sql.Cell.Integer{U32.show(ordinal)}])

def extra_source(+db: U32,+id: String,provider: String,repo: String) -> IO(Unit):
  do IO<Unit>:
    source(db,id,provider)
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(?,?)",[Sql.Cell.Integer{id},Sql.Cell.Integer{id}])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent,records,accepted) VALUES(?,?,1,1,1)",[Sql.Cell.Integer{id},Sql.Cell.Integer{id}])
    event(db,id,0,"user",repo,"2026-10-02T00:00:00.000000000Z")

def scoped_rows(rows: List<&2,List<&2,Sql.Cell>>,+history: Bool) -> Bool:
  match rows:
    case []:
      True{}
    case +row <> rest:
      String.eq(Store.field(row,Bool.pick(Nat,history,1n,3n)),"claude") &&
      String.eq(Store.field(row,Bool.pick(Nat,history,8n,6n)),"/synthetic/list-target") &&
      (history || (String.eq(Store.field(row,4n),"user") &&
        String.eq(Store.field(row,8n),"2026-10-02T00:00:00.000000000Z"))) && scoped_rows(rest,history)

def scoped_result(+value: Cli.Page,base: Nat,offset: U32,count: U32,more: Bool,
  +history: Bool,+label: String) -> IO(Unit):
  Cli.Page{from,rows,available} = value
  do IO<Unit>:
    page(value,base,201,offset,count,more,history,label)
    assert(scoped_rows(rows,history),label ++ " every row retains its requested listing scope")

def scoped_page(db: U32,base: Nat,+offset: U32,count: U32,more: Bool,
  +history: Bool,selected: Query.Filters,label: String) -> IO(Unit):
  do IO<Unit>:
    value : Cli.Page <- Cli.list_page(db,history,selected,offset)
    scoped_result(value,base,offset,count,more,history,label)

def scoped() -> IO(Unit):
  +base = Nat.add(4294967295n,1000n)
  do IO<Unit>:
    +db : U32 <- Store.open(".build/list-scoped.sqlite")
    fixture(db,base,201)
    Store.exec(db,"BEGIN IMMEDIATE",[])
    extra_source(db,identity(base,202),"codex","/synthetic/list-target")
    extra_source(db,identity(base,203),"claude","/synthetic/list-other")
    event(db,identity(base,1),1,"assistant","/synthetic/list-target","2026-10-02T00:00:00.000000000Z")
    event(db,identity(base,1),2,"user","/synthetic/list-target","2026-10-01T23:59:59.000000000Z")
    Store.exec(db,"COMMIT",[])
    scoped_page(db,base,0,100,True{},True{},history_filters(),"scoped high-identity history first page")
    scoped_page(db,base,100,100,True{},True{},history_filters(),"scoped high-identity history second page")
    scoped_page(db,base,200,1,False{},True{},history_filters(),"scoped high-identity history final page")
    scoped_page(db,base,0,100,True{},False{},filters("pagingneedle"),"scoped lexical first page")
    scoped_page(db,base,100,100,True{},False{},filters("pagingneedle"),"scoped lexical second page")
    scoped_page(db,base,200,1,False{},False{},filters("pagingneedle"),"scoped lexical final page")
    scoped_page(db,base,100,100,True{},False{},filters(""),"filter-only second page")
    scoped_page(db,base,200,1,False{},False{},filters(""),"filter-only final page")
    +edge : Cli.Page <- Cli.list_page(db,False{},filters("pagingneedle"),4294967195)
    page(edge,base,201,4294967195,0,False{},False{},"largest supported listing offset")
    IO.try(Unit,Sql.close(db))
    skipped : Bool <- Cli.list_more(db,False{},filters("pagingneedle"),4294967295,False{})
    assert(Bool.not(skipped),"a short page performs no lookahead query even with a closed connection")

# The mutation is committed by a distinct connection after the first SELECT.
# Production list_rows/list_more must share this caller-owned read snapshot.
# The full list_page transaction wrapper is additionally checked by review.
def snapshot_case(+history: Bool) -> IO(Unit):
  +path = ".build/list-snapshot-" ++ Bool.pick(String,history,"history","search") ++ ".sqlite"
  +selected = Bool.pick(Query.Filters,history,history_filters(),filters("pagingneedle"))
  +label = Bool.pick(String,history,"history","search") ++ " concurrent lookahead"
  do IO<Unit>:
    +reader : U32 <- Store.open(path)
    fixture(reader,0n,100)
    +writer : U32 <- Store.open(path)
    Store.exec(reader,"BEGIN",[])
    +rows : List<&2,List<&2,Sql.Cell>> <- Cli.list_rows(reader,history,selected,100,0)
    assert(String.eq(refs(rows,history),expected_refs(100n,0n,100,history)),
      label ++ " initial rows establish the independent ordered snapshot")
    Store.exec(writer,"BEGIN IMMEDIATE",[])
    extra_source(writer,"101","claude","/synthetic/list-target")
    Store.exec(writer,"COMMIT",[])
    +before : Bool <- Cli.list_more(reader,history,selected,0,True{})
    assert(Bool.not(before),label ++ " ignores a later writer commit in the same read transaction")
    Store.exec(reader,"COMMIT",[])
    +fresh : Cli.Page <- Cli.list_page(reader,history,selected,0)
    page(fresh,0n,101,0,100,True{},history,label ++ " later command sees the new listing")
    +last : Cli.Page <- Cli.list_page(reader,history,selected,100)
    page(last,0n,101,100,1,False{},history,label ++ " later command reaches the new final page")
    IO.try(Unit,Sql.close(writer))
    IO.try(Unit,Sql.close(reader))

def invalid_worker(value: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/list-invalid.sqlite")
    Store.exec(db,"BEGIN",[])
    Cli.history(db,["","",value])
    IO.die(Unit,1,"FAIL invalid offset was accepted")

def rejected_result(result: U32 & (String & String),needle: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(Bool.not(U32.is_eq(code,0)) && String.contains(out ++ err,needle),name)

def rejected(self: String,value: String,needle: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["invalid",value],"",8192,10000))
    rejected_result(result,needle,name)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    boundary_case(0,0,False{},0,False{},0)
    boundary_case(99,99,False{},0,False{},0)
    boundary_case(100,100,False{},0,False{},0)
    boundary_case(101,100,True{},1,False{},0)
    boundary_case(200,100,True{},100,False{},0)
    boundary_case(201,100,True{},100,True{},1)
    scoped()
    snapshot_case(True{})
    snapshot_case(False{})
    rejected(self,"4294967196","offset must be from 0 to 4294967195",
      "CLI rejects lookahead overflow before attempting a nested transaction")
    rejected(self,"4294967296","offset must be an integer from 0 to 4294967295",
      "CLI rejects greater-than-U32 offsets before listing transaction creation")
    IO.print("Listing pagination suite passed; synthetic SQL projections only")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case self <> "invalid" <> value <> []:
      invalid_worker(value)
    case _:
      IO.die(Unit,2,"Listing pagination suite expects zero arguments or its owned invalid-offset child")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
