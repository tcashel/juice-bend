import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/evidence.bend as Evidence
import ../src/maintenance.bend as Maintenance

# Full workflow uses only this test runner's isolated directory. The source
# removal is intentional: all later reads must use the captured authority.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def request(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"integration-session\",\"cwd\":\"/synthetic/integration\",\"message\":{\"content\":" ++
    Json.quote(text) ++ "}}\n"

def edit(text: String) -> String:
  "{\"type\":\"assistant\",\"timestamp\":\"100\",\"message\":{\"model\":\"synthetic-model\",\"content\":[{\"type\":\"tool_use\",\"id\":\"integration-edit\",\"name\":\"Write\",\"input\":{\"file_path\":\"answer.bend\",\"content\":" ++
    Json.quote(text) ++ "}}]}}\n"

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    return Store.field(Store.first(rows),0n)

def remove_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match result:
    case Done{(0,(_,_))}:
      IO.print("PASS original synthetic source removed")
    case _:
      IO.die(Unit,1,"FAIL isolated synthetic source removal")

def remove_source(path: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/rm",["--",path],"",4096,3000)
    remove_result(result)

def read_closed(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,bytes) = result
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,bytes))

def read_bytes(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    read : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65536)
    read_closed(read)

def only_snapshot(rows: List<&2,List<&2,Sql.Cell>>,+snapshot: String) -> Bool:
  match rows:
    case row <> Nil{}:
      String.eq(Store.field(row,0n),snapshot)
    case _:
      False{}

def reopened(+db_path: String,+root: String,+old: String,+appended: String,
  +latest: String,+old_page: String,+old_why: String,+old_raw: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(db_path)
    +read_old : String <- Store.page(db,old,0,100)
    assert(String.eq(read_old,old_page),"reopened library reads exact old snapshot after source deletion")
    +append_page : String <- Store.page(db,appended,0,100)
    assert(String.contains(append_page,"appended juniper") && String.contains(append_page,"original maple"),
      "appended snapshot retains its original and appended records after rewrite and deletion")
    +current_page : String <- Store.page(db,latest,0,100)
    assert(String.contains(current_page,"current evergreen") && Bool.not(String.contains(current_page,"original maple")),
      "new generation remains separate from old pinned transcript")
    +read_why : String <- Evidence.why(db,old,0,20)
    assert(String.eq(read_why,old_why),"reopened Why is stable after source rewrite and deletion")
    assert(String.contains(read_why,"\"snapshot\":\"" ++ old ++ "\"") &&
      String.contains(read_why,"\"record\":\"1\",\"event\":\"0\""),
      "retained Why cites old physical record and event identity")
    +hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"evergreen","claude","/synthetic/integration","user","",10,0)
    assert(only_snapshot(hits,latest),"search finds current removed-source capture with exact snapshot")
    absent : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"maple","claude","/synthetic/integration","","",10,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,absent),"default search does not duplicate retained historical generations")
    Maintenance.verify(db,old)
    Maintenance.verify(db,appended)
    Maintenance.verify(db,latest)
    IO.print("PASS full integrity verification accepts all retained snapshot extents")
    +hashes : String <- scalar(db,"SELECT group_concat(digest,'|') FROM raw ORDER BY id",[])
    Store.exec(db,"DELETE FROM events WHERE snapshot=? OR snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}])
    damaged_why : String <- Evidence.why(db,old,0,20)
    assert(String.eq(damaged_why,old_why),"Why does not depend on destroyed derived event projection")
    Maintenance.rebuild(db,old)
    Maintenance.rebuild(db,latest)
    +rebuilt_why : String <- Evidence.why(db,old,0,20)
    assert(String.eq(rebuilt_why,old_why),"rebuilding derived projections preserves exact Why evidence")
    +rebuilt_page : String <- Store.page(db,old,0,100)
    assert(String.eq(rebuilt_page,old_page),"rebuilding derived projections preserves exact pinned transcript")
    rebuilt_hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"evergreen","claude","/synthetic/integration","user","",10,0)
    assert(only_snapshot(rebuilt_hits,latest),"rebuilt search restores current source occurrence exactly once")
    historical_hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"maple","","","","",10,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,historical_hits),"historical rebuild cannot reintroduce obsolete search hits")
    same_hashes : String <- scalar(db,"SELECT group_concat(digest,'|') FROM raw ORDER BY id",[])
    assert(String.eq(same_hashes,hashes),"rebuild does not alter immutable raw identities")
    Maintenance.export_raw(db,old,root ++ "/old-snapshot.jsonl")
    old_export : List<&2,U32> <- read_bytes(root ++ "/old-snapshot.jsonl")
    assert(Domain.bytes_equal(old_export,Domain.encode(old_raw)),
      "full export reproduces original bytes without appended or rewritten content")
    Maintenance.export_raw(db,latest,root ++ "/new-snapshot.jsonl")
    latest_export : List<&2,U32> <- read_bytes(root ++ "/new-snapshot.jsonl")
    assert(Domain.bytes_equal(latest_export,Domain.encode(request("current evergreen") ++ edit("let answer = 99\n"))),
      "full export reproduces selected rewritten generation only")
    IO.try(Unit,Sql.close(db))

def suite(+root: String) -> IO(Unit):
  +source_path = root ++ "/integration-source.jsonl"
  +db_path = root ++ "/.build/integration.sqlite"
  +old_raw = request("original maple") ++ edit("let answer = 42\n")
  do IO<Unit>:
    Store.checked(String.contains(root,"juice-bend-test-integration."),
      "Run with ./scripts/test tests/integration.bend in its isolated fixture root")
    Store.write_text(source_path,"w",old_raw)
    +db : U32 <- Store.open(db_path)
    +old : String <- Store.import_file(db,"claude",source_path)
    +same : String <- Store.import_file(db,"claude",source_path)
    assert(String.eq(old,same),"unchanged import retains exact snapshot")
    +old_page : String <- Store.page(db,old,0,100)
    +old_why : String <- Evidence.why(db,old,0,20)
    Store.write_text(source_path,"a",request("appended juniper"))
    +appended : String <- Store.import_file(db,"claude",source_path)
    assert(Bool.not(String.eq(old,appended)),"append publishes a distinct immutable snapshot")
    +old_gen : String <- scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{old}])
    append_gen : String <- scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{appended}])
    assert(String.eq(old_gen,append_gen),"append stays within unchanged source generation")
    Store.write_text(source_path,"w",request("current evergreen") ++ edit("let answer = 99\n"))
    +latest : String <- Store.import_file(db,"claude",source_path)
    latest_gen : String <- scalar(db,"SELECT generation FROM snapshots WHERE id=?",[Sql.Cell.Integer{latest}])
    assert(Bool.not(String.eq(old_gen,latest_gen)),"rewrite publishes a separate source generation")
    IO.try(Unit,Sql.close(db))
    remove_source(source_path)
    reopened(db_path,root,old,appended,latest,old_page,old_why,old_raw)
    IO.print("Integrated preservation, search, transcript, Why, rebuild and export passed")

def main() -> IO(Unit):
  do IO<Unit>:
    root : String <- IO.try(String,IO.get_env("PWD"))
    suite(root)
