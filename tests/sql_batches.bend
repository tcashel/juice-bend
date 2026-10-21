import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/maintenance.bend as Maintenance

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def value(db: U32,sql: String,args: List<&2,Sql.Cell>) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    return Store.field(Store.first(rows),0n)

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    actual : String <- value(db,sql,args)
    assert(String.eq(actual,expected),name)

def triple(+word: String) -> String:
  "{\"type\":\"assistant\",\"cwd\":\"/synthetic/sql-batches\",\"sessionId\":\"batch-session\",\"message\":{\"content\":[" ++
    "{\"type\":\"text\",\"text\":" ++ Json.quote(word ++ " first") ++ "}," ++
    "{\"type\":\"text\",\"text\":" ++ Json.quote(word ++ " second") ++ "}," ++
    "{\"type\":\"text\",\"text\":" ++ Json.quote(word ++ " third") ++ "}]}}\n"

def large() -> String:
  "{\"type\":\"user\",\"cwd\":\"/synthetic/sql-batches\",\"message\":{\"content\":" ++
    Json.quote(String.repeat("x",220000n) ++ " giantneedle") ++ "}}\n"

# Compare every indexed cell in both directions, including the event rowid.
# The expected set is a completed accepted projection, independently counted.
def index_exact(+db: U32,+snapshot: String,+count: String,+label: String) -> IO(Unit):
  +columns = {"rowid,body,arguments,result,tool,snapshot,ordinal,event" : String}
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],count,
      label ++ " independent event count")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],count,
      label ++ " complete FTS count")
    scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++ " FROM search WHERE snapshot=? EXCEPT SELECT " ++
      columns ++ " FROM events WHERE snapshot=?)",[Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot}],"0",
      label ++ " every FTS cell matches its event")
    scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++ " FROM events WHERE snapshot=? EXCEPT SELECT " ++
      columns ++ " FROM search WHERE snapshot=?)",[Sql.Cell.Integer{snapshot},Sql.Cell.Integer{snapshot}],"0",
      label ++ " every event is indexed once")

def matches(db: U32,word: String,count: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM search WHERE search MATCH ?",[Sql.Cell.Text{word}],count,label)

def valid(+db: U32,snapshot: String,label: String) -> IO(Unit):
  do IO<Unit>:
    ok : Bool <- Store.projection_valid(db,snapshot)
    assert(ok,label)

def copied(+db: U32,+old: String,+latest: String,+records: String,+label: String) -> IO(Unit):
  +columns = {"ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage" : String}
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],records,label ++ " reuses every verified prefix raw occurrence")
    scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++ " FROM events WHERE snapshot=? EXCEPT SELECT " ++
      columns ++ " FROM events WHERE snapshot=?)",[Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],"0",
      label ++ " preserves every old event field across copy batches")
    scalar(db,"SELECT count(*) FROM records WHERE snapshot=? AND ordinal>=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{records}],"0",label ++ " old record map remains bounded")
    valid(db,latest,label ++ " accepted copied projection seal verifies")

def orphan_cleanup(+db: U32,+old: String,+latest: String,+other: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) VALUES(-9223372036854775808,'orphannegative','','','',?,0,0)",
      [Sql.Cell.Integer{old}])
    Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) VALUES(9000000000,'orphanhigh','','','',?,0,0)",
      [Sql.Cell.Integer{old}])
    Store.clear_search_snapshot(db,old)
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{old}],"0",
      "bounded FTS deletion removes negative and high orphan rowids without event joins")
    index_exact(db,latest,"1641","orphan cleanup retains current first source")
    index_exact(db,other,"210","orphan cleanup retains unrelated second source")
    Store.exec(db,"COMMIT",[])
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.clear_search_snapshot(db,latest)
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{latest}],"0",
      "bounded FTS deletion exhausts more than two128-key pages")
    matches(db,"companion","210","deleting one snapshot leaves all other-source search hits")
    Store.exec(db,"ROLLBACK",[])
    index_exact(db,latest,"1641","caller rollback restores all completed deletion batches")

def migrate(+db: U32,+old: String,+latest: String,+other: String) -> IO(U32):
  do IO<U32>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    scalar(db,"SELECT EXISTS(SELECT 1 FROM archive_captures) OR EXISTS(SELECT 1 FROM archive_chunks) OR EXISTS(SELECT 1 FROM generations WHERE typeof(encoding)<>'text' OR encoding<>'identity')",[],"0",
      "batched legacy fixture has no archive evidence or nonidentity generation")
    Store.exec(db,"DROP TABLE archive_chunks",[])
    Store.exec(db,"DROP TABLE archive_captures",[])
    Store.exec(db,"ALTER TABLE generations DROP COLUMN encoding",[])
    Store.exec(db,"DELETE FROM search",[])
    Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) SELECT rowid,body,arguments,result,tool,snapshot,ordinal,event FROM events",[])
    Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) VALUES(-9223372036854775808,'legacynegative','','','',?,0,0)",
      [Sql.Cell.Integer{old}])
    Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) VALUES(9000000000,'legacyhigh','','','',?,0,0)",
      [Sql.Cell.Integer{old}])
    Store.exec(db,"PRAGMA user_version=1",[])
    Store.exec(db,"COMMIT",[])
    scalar(db,"SELECT count(*) FROM search",[],"3473","legacy migration fixture contains both historical events and signed64 orphan keys")
    scalar(db,"SELECT (SELECT count(*) FROM sqlite_master WHERE name IN ('archive_chunks','archive_captures'))+(SELECT count(*) FROM pragma_table_info('generations') WHERE name='encoding')",[],"0",
      "batched fixture has actual old schema before reopen")
    IO.try(Unit,Sql.close(db))
    +reopened : U32 <- Store.open(".build/sql-batches.sqlite")
    scalar(reopened,"PRAGMA user_version",[],"3","bounded legacy migration publishes schema version3")
    scalar(reopened,"SELECT EXISTS(SELECT 1 FROM archive_captures) OR EXISTS(SELECT 1 FROM archive_chunks) OR EXISTS(SELECT 1 FROM generations WHERE typeof(encoding)<>'text' OR encoding<>'identity')",[],"0",
      "bounded legacy migration keeps identity generations and empty archive metadata")
    Maintenance.verify(reopened,old)
    Maintenance.verify(reopened,latest)
    Maintenance.verify(reopened,other)
    scalar(reopened,"SELECT count(*) FROM search",[],"1851","bounded migration retains exactly both latest accepted projections")
    scalar(reopened,"SELECT count(*) FROM search WHERE rowid<0 OR rowid>4294967295",[],"0",
      "bounded migration clears INT64_MIN and greater-than-U32 orphan keys")
    index_exact(reopened,latest,"1641","migration reconstructs every current first-source event")
    index_exact(reopened,other,"210","migration reconstructs every current second-source event")
    matches(reopened,"original","1620","migration excludes historical duplicate lexical hits")
    return reopened

def tables() -> List<&2,String>:
  ["sources","generations","snapshots","raw","records","events","snapshot_context","projection_checks","search"]

def table_columns(table: String) -> String:
  match table:
    case "search":
      "rowid,*"
    case _:
      "*"

def remember(names: List<&2,String>,+db: U32) -> IO(Unit):
  match names:
    case []:
      IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        Store.exec(db,"CREATE TABLE before_" ++ name ++ " AS SELECT " ++ table_columns(name) ++ " FROM " ++ name,[])
        remember(rest,db)

def unchanged(names: List<&2,String>,+db: U32) -> IO(Unit):
  match names:
    case []:
      IO.pure(Unit,Unit{})
    case +name <> rest:
      do IO<Unit>:
        +forward : String <- value(db,"SELECT count(*) FROM (SELECT " ++ table_columns(name) ++ " FROM " ++
          name ++ " EXCEPT SELECT * FROM before_" ++ name ++ ")",[])
        reverse : String <- value(db,"SELECT count(*) FROM (SELECT * FROM before_" ++ name ++
          " EXCEPT SELECT " ++ table_columns(name) ++ " FROM " ++ name ++ ")",[])
        assert(String.eq(forward,"0") && String.eq(reverse,"0"),
          "late FTS batch failure rolls back every " ++ name ++ " cell")
        unchanged(rest,db)

# This observer runs after latest changes but before indexing. Row OFFSET130
# belongs to the third64-event batch (ordinal43,event1). The conflicting FTS
# row is itself transactional, so abrupt error exit must remove it as well.
def conflict_name(+db: U32,name: String) -> IO(Unit):
  match name:
    case "latest_repointed":
      do IO<Unit>:
        +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT e.rowid,e.ordinal,e.event FROM events e JOIN snapshots p ON p.id=e.snapshot JOIN sources s ON s.latest=p.id WHERE s.locator LIKE '%batch-a.jsonl' ORDER BY e.ordinal,e.event LIMIT 1 OFFSET 130",[],1)
        +row : List<&2,Sql.Cell> = Store.first(rows)
        Store.checked(String.eq(Store.field(row,1n),"43") && String.eq(Store.field(row,2n),"1"),
          "Late batch conflict fixture did not locate expected third-page event")
        Store.exec(db,"INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) SELECT rowid,body,arguments,result,tool,snapshot,ordinal,event FROM events WHERE rowid=?",
          [Sql.Cell.Integer{Store.field(row,0n)}])
        Store.write_text("batch-conflict.marker","w","third-fts-batch\n43\n1\n")
    case _:
      IO.pure(Unit,Unit{})

def conflict(db: U32,phase: Store.ImportPhase) -> IO(Unit):
  conflict_name(db,Store.phase_name(phase))

def conflict_observer(fuel: Nat,+db: U32) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        conflict(db,phase)
        return conflict_observer(rest,db)}

def child() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/sql-batches.sqlite")
    snap : String <- Store.import_observed(db,"claude","batch-a.jsonl",conflict_observer(9n,db))
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,1,"FAIL expected third-batch conflict but imported " ++ snap)

def file_closed(got: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (f,result) = got
  do IO<String>:
    File.close(f)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))

def file_text(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,String> <- File.read(file,4096)
    file_closed(got)

def failed(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  assert(Bool.not(U32.is_eq(code,0)) && String.contains(out ++ err,"constraint failed"),
    "owned import child fails on the injected late FTS primary-key conflict")

def late_failure(+self: String,+db: U32,+latest: String,+other: String) -> IO(Unit):
  do IO<Unit>:
    +old_page : String <- Store.page(db,latest,0,100)
    remember(tables(),db)
    Store.write_text("batch-a.jsonl","a",triple("recovered"))
    IO.try(Unit,Sql.close(db))
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["conflict"],"",8192,30000))
    failed(result)
    marker : String <- file_text("batch-conflict.marker")
    assert(String.eq(marker,"third-fts-batch\n43\n1\n"),"exact marker proves conflict was injected beyond two FTS batches")
    +reopened : U32 <- Store.open(".build/sql-batches.sqlite")
    unchanged(tables(),reopened)
    index_exact(reopened,latest,"1641","late failure retains old complete latest index")
    index_exact(reopened,other,"210","late failure retains unrelated complete index")
    matches(reopened,"original","1620","late failure preserves every old latest lexical hit")
    matches(reopened,"companion","210","late failure preserves every unrelated lexical hit")
    matches(reopened,"recovered","0","uncommitted late-batch text is absent from lexical search")
    restored : String <- Store.page(reopened,latest,0,100)
    assert(String.eq(restored,old_page),"late-batch failure leaves pinned old transcript bytes unchanged")
    Maintenance.verify(reopened,latest)
    IO.print("PASS late-batch failure retains fully verified old raw extent")
    +recovered : String <- Store.import_file(reopened,"claude","batch-a.jsonl")
    copied(reopened,latest,recovered,"547","retry after late batch failure")
    index_exact(reopened,recovered,"1644","retry publishes complete batched replacement index")
    matches(reopened,"recovered","3","retry publishes all three independent new fanout events")
    scalar(reopened,"SELECT count(*) FROM snapshots",[],"4","failed attempt left no pending or duplicate snapshot")
    again : String <- Store.import_file(reopened,"claude","batch-a.jsonl")
    assert(String.eq(again,recovered),"successful retry remains idempotent")
    IO.try(Unit,Sql.close(reopened))

def regular(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/sql-batches.sqlite")
    Store.write_text("batch-a.jsonl","w",String.repeat(triple("original"),540n))
    +old : String <- Store.import_file(db,"claude","batch-a.jsonl")
    +old_page : String <- Store.page(db,old,0,100)
    index_exact(db,old,"1620","initial many-batch capture")
    Store.write_text("batch-b.jsonl","w",String.repeat(triple("companion"),70n))
    +other : String <- Store.import_file(db,"claude","batch-b.jsonl")
    index_exact(db,other,"210","independent many-batch second source")
    Store.write_text("batch-a.jsonl","a",String.repeat(triple("appended"),7n))
    +latest : String <- Store.import_file(db,"claude","batch-a.jsonl")
    copied(db,old,latest,"540","three-chunk physical record copy")
    index_exact(db,latest,"1641","appended many-batch capture")
    matches(db,"original","1620","latest-only append exposes exactly one copy of every prefix event")
    matches(db,"appended","21","all appended fanout events become searchable")
    matches(db,"companion","210","append replacement preserves every other-source hit")
    scalar(db,"SELECT body FROM events WHERE snapshot=? AND ordinal=21 AND event=1",
      [Sql.Cell.Integer{latest}],"original second","first64-event boundary does not skip the rest of a physical record")
    scalar(db,"SELECT body FROM events WHERE snapshot=? AND ordinal=42 AND event=2",
      [Sql.Cell.Integer{latest}],"original third","second64-event boundary retains the final fanout event")
    scalar(db,"SELECT count(*) FROM search WHERE snapshot=?",[Sql.Cell.Integer{old}],"0",
      "old snapshot loses FTS projection after complete latest replacement")
    Maintenance.rebuild(db,old)
    index_exact(db,latest,"1641","historical replay preserves current batched index")
    matches(db,"original","1620","historical rebuild does not reintroduce duplicate search hits")
    retained : String <- Store.page(db,old,0,100)
    assert(String.eq(retained,old_page),"historical rebuild retains the pinned original transcript")
    Maintenance.rebuild(db,latest)
    index_exact(db,latest,"1641","current replay atomically rebuilds all index batches")
    orphan_cleanup(db,old,latest,other)
    migrated : U32 <- migrate(db,old,latest,other)
    late_failure(self,migrated,latest,other)

def byte_limited() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/sql-batches-large.sqlite")
    Store.write_text("batch-large.jsonl","w",String.repeat(large(),12n))
    +old : String <- Store.import_file(db,"claude","batch-large.jsonl")
    index_exact(db,old,"12","byte-limited initial FTS batches")
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=? AND length(body)=220012",
      [Sql.Cell.Integer{old}],"12","large fixture retains all twelve complete220012-character bodies")
    Store.write_text("batch-large.jsonl","a",large())
    +latest : String <- Store.import_file(db,"claude","batch-large.jsonl")
    copied(db,old,latest,"12","byte-limited large-event prefix copy")
    index_exact(db,latest,"13","byte-limited appended FTS batches")
    matches(db,"giantneedle","13","large payload batches preserve every searchable final token")
    Maintenance.rebuild(db,old)
    matches(db,"giantneedle","13","large historical replay stays excluded from current search")
    Maintenance.rebuild(db,latest)
    index_exact(db,latest,"13","byte-limited current rebuild is complete")
    Maintenance.verify(db,old)
    Maintenance.verify(db,latest)
    IO.print("PASS both large immutable raw extents fully verify after batched copy and rebuild")
    IO.try(Unit,Sql.close(db))

# A legal physical record is still capped at256KiB. This deliberately changes
# derived data inside a transaction to exercise the helpers' oversized-first-row
# progress rule; rollback restores the verified accepted capture afterwards.
def oversized_derived() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/sql-batches-oversized.sqlite")
    Store.write_text("batch-oversized-derived.jsonl","w",triple("fallback"))
    +snapshot : String <- Store.import_file(db,"claude","batch-oversized-derived.jsonl")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.clear_search_snapshot(db,snapshot)
    Store.exec(db,"UPDATE events SET body=? WHERE snapshot=? AND ordinal=0 AND event=0",
      [Sql.Cell.Text{String.repeat("x",1100000n) ++ " beyondbudget"},Sql.Cell.Integer{snapshot}])
    +event_keys : List<&2,List<&2,Sql.Cell>> <- Store.event_batch(db,snapshot,"-1","-1","4294967295")
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,event_keys),1n) &&
      String.eq(Store.field(Store.first(event_keys),0n),"0") &&
      String.eq(Store.field(Store.first(event_keys),1n),"0"),
      "event batching returns one oversized derived row to guarantee progress")
    Store.index_search_snapshot(db,snapshot)
    index_exact(db,snapshot,"3","oversized derived row indexing makes progress")
    scalar(db,"SELECT count(*) FROM search WHERE length(body)>1048576",[],"1",
      "synthetic oversized derived FTS body is retained without truncation")
    search_keys : List<&2,List<&2,Sql.Cell>> <- Store.search_key_batch(db,None{})
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,search_keys),1n),
      "FTS deletion batching returns the oversized first row instead of stopping")
    Store.clear_search_snapshot(db,snapshot)
    scalar(db,"SELECT count(*) FROM search",[],"0","FTS deletion advances past oversized derived body and remaining rows")
    Store.exec(db,"ROLLBACK",[])
    index_exact(db,snapshot,"3","oversized helper fixture rollback restores original complete index")
    valid(db,snapshot,"oversized derived mutation rollback restores original accepted projection seal")
    matches(db,"fallback","3","oversized derived mutation rollback restores original lexical hits")
    matches(db,"beyondbudget","0","oversized derived test content never survives rollback")
    Maintenance.verify(db,snapshot)
    IO.print("PASS legal original raw capture verifies after oversized derived helper stress")
    IO.try(Unit,Sql.close(db))

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    regular(self)
    byte_limited()
    oversized_derived()
    IO.print("SQL batch suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{_,Con{"conflict",Nil{}}}:
      child()
    case _:
      IO.die(Unit,2,"SQL batch suite expects zero arguments or its owned conflict child")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
