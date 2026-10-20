import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/maintenance.bend as Maintenance

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),name)

def line(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"fts-regression\",\"cwd\":\"/synthetic/search\",\"message\":{\"role\":\"user\",\"content\":\"" ++ text ++ "\"}}\n"

def hit(+db: U32,query: String,snapshot: String,name: String) -> IO(Unit):
  do IO<Unit>:
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.search(db,query,"claude","/synthetic/search","user","",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),1n) &&
      String.eq(Store.field(Store.first(rows),0n),snapshot),name)

def no_hit(db: U32,query: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.search(db,query,"","","","",100,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,rows),name)

def staging(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO snapshots(generation,extent) SELECT generation,extent FROM snapshots WHERE accepted=1 ORDER BY id DESC LIMIT 1",[])
    +pending : String <- Store.last_id(db)
    Store.exec(db,"INSERT INTO events SELECT ?,ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=(SELECT latest FROM sources LIMIT 1)",
      [Sql.Cell.Integer{pending}])
    scalar(db,"SELECT count(*) FROM search",[],"1","staging events never appear in FTS before publication")
    Store.exec(db,"ROLLBACK",[])

def legacy_fixture(+db: U32) -> IO(Unit):
  Store.statements([
    "BEGIN IMMEDIATE",
    "DELETE FROM search",
    "INSERT INTO search(body,arguments,result,tool,snapshot,ordinal,event) SELECT body,arguments,result,tool,snapshot,ordinal,event FROM events",
    "CREATE TRIGGER event_search AFTER INSERT ON events BEGIN INSERT INTO search(body,arguments,result,tool,snapshot,ordinal,event) VALUES(new.body,new.arguments,new.result,new.tool,new.snapshot,new.ordinal,new.event); END",
    "PRAGMA user_version=1",
    "COMMIT"
  ],db)

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/storage-search.sqlite")
    scalar(db,"PRAGMA user_version",[],"2","new libraries use FTS rowid schema v2")
    Store.write_text("search-source.jsonl","w",line("old citrus evidence"))
    +old : String <- Store.import_file(db,"claude","search-source.jsonl")
    +old_text : String <- Store.page(db,old,0,100)
    scalar(db,"SELECT count(*) FROM search",[],"1","first capture indexes one current event")
    Store.write_text("search-source.jsonl","a",line("new apricot evidence"))
    +appended : String <- Store.import_file(db,"claude","search-source.jsonl")
    scalar(db,"SELECT count(*) FROM events",[],"3","append preserves historical projection events")
    scalar(db,"SELECT count(*) FROM search",[],"2","append indexes current events without duplicate history")
    scalar(db,"SELECT count(*) FROM search JOIN events e ON e.rowid=search.rowid WHERE e.snapshot=search.snapshot AND e.ordinal=search.ordinal AND e.event=search.event",[],"2",
      "FTS rowids map to exact current event rows")
    hit(db,"citrus",appended,"inherited prefix returns current snapshot once")
    hit(db,"apricot",appended,"append-only text returns current snapshot")
    Store.write_text("search-source.jsonl","w",line("replacement mango evidence"))
    +latest : String <- Store.import_file(db,"claude","search-source.jsonl")
    scalar(db,"SELECT count(*) FROM search",[],"1","rewrite removes previous current FTS projection only")
    scalar(db,"SELECT count(*) FROM events",[],"4","rewrite retains historical event projections")
    hit(db,"mango",latest,"rewrite is searchable")
    no_hit(db,"citrus","historical-only words do not leak into latest search")
    restored : String <- Store.page(db,old,0,100)
    assert(String.eq(old_text,restored),"FTS replacement leaves old captured transcript unchanged")
    Maintenance.rebuild(db,old)
    scalar(db,"SELECT count(*) FROM search",[],"1","rebuilding historical snapshot does not reindex history")
    no_hit(db,"citrus","historical rebuild remains excluded from latest search")
    hit(db,"mango",latest,"historical rebuild leaves current search intact")
    Maintenance.rebuild(db,latest)
    scalar(db,"SELECT count(*) FROM search",[],"1","current rebuild replaces index without duplicates")
    hit(db,"mango",latest,"current rebuilt event rowid remains searchable")
    staging(db)
    legacy_fixture(db)
    scalar(db,"SELECT count(*) FROM search",[],"4","legacy fixture contains historical duplicate FTS rows")
    IO.try(Unit,Sql.close(db))
    +migrated : U32 <- Store.open(".build/storage-search.sqlite")
    scalar(migrated,"PRAGMA user_version",[],"2","legacy FTS migration advances schema atomically")
    scalar(migrated,"SELECT count(*) FROM search",[],"1","migration indexes only accepted current events")
    scalar(migrated,"SELECT count(*) FROM events",[],"4","migration preserves all historical event rows")
    scalar(migrated,"SELECT count(*) FROM sqlite_master WHERE type='trigger' AND name='event_search'",[],"0",
      "legacy eager FTS trigger is removed")
    hit(migrated,"mango",latest,"migrated current event rowid is searchable")
    no_hit(migrated,"citrus","migrated historical event stays out of current search")
    retained : String <- Store.page(migrated,old,0,100)
    assert(String.eq(old_text,retained),"migration and rebuild preserve exact old transcript")
    Maintenance.rebuild(migrated,appended)
    scalar(migrated,"SELECT count(*) FROM search",[],"1","old appended snapshot rebuild preserves current FTS cardinality")
    hit(migrated,"mango",latest,"search still works after migration and old append rebuild")
    IO.try(Unit,Sql.close(migrated))
