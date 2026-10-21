import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/maintenance.bend as Maintenance

# A deterministic interleaving, not a probabilistic scheduling stress test:
# contender reads the old version on connection A; connection B completes a
# migration; A enters schema_version with its genuinely stale observation.
# The schema1/0 fixture really lacks schema3's encoding and archive tables.

type TableState is Data:
  TableState{name: String,rows: List<&2,List<&2,Sql.Cell>>}

type Baseline is Data:
  Baseline{old: String,latest: String,old_page: String,latest_page: String,
    tables: List<&2,TableState>}

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def cell_equal(left: Sql.Cell,right: Sql.Cell) -> Bool:
  match left right:
    case Sql.Cell.Null{} Sql.Cell.Null{}: True{}
    case Sql.Cell.Integer{a} Sql.Cell.Integer{b}: String.eq(a,b)
    case Sql.Cell.Text{a} Sql.Cell.Text{b}: String.eq(a,b)
    case Sql.Cell.Real{a} Sql.Cell.Real{b}: String.eq(a,b)
    case Sql.Cell.Blob{a} Sql.Cell.Blob{b}: Domain.bytes_equal(a,b)
    case _ _: False{}

def row_equal(left: List<&2,Sql.Cell>,right: List<&2,Sql.Cell>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case a <> rest b <> tail: cell_equal(a,b) && row_equal(rest,tail)
    case _ _: False{}

def rows_equal(left: List<&2,List<&2,Sql.Cell>>,right: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match left right:
    case Nil{} Nil{}: True{}
    case a <> rest b <> tail: row_equal(a,b) && rows_equal(rest,tail)
    case _ _: False{}

def scalar_rows(rows: List<&2,List<&2,Sql.Cell>>,expected: String,name: String) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{actual}]]:
      assert(String.eq(actual,expected),name)
    case _:
      IO.die(Unit,1,"FAIL " ++ name ++ ": expected one SQLite integer")

def scalar(db: U32,sql: String,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],1)
    scalar_rows(rows,expected,name)

def table_query(+name: String) -> String:
  match name:
    case "search": "SELECT rowid,* FROM search ORDER BY rowid"
    case "events": "SELECT * FROM events ORDER BY snapshot,ordinal,event"
    case _: "SELECT * FROM " ++ name ++ " ORDER BY 1,2"

def remember(names: List<&2,String>,+db: U32,reversed: List<&2,TableState>) -> IO(List<&2,TableState>):
  match names:
    case []:
      IO.pure(List<&2,TableState>,List.reverse(&2,TableState,reversed))
    case +name <> rest:
      do IO<List<&2,TableState>>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,table_query(name),[],100)
        remember(rest,db,Con{TableState{name,rows},reversed})

def unchanged(tables: List<&2,TableState>,+db: U32,+label: String) -> IO(Unit):
  match tables:
    case []:
      IO.pure(Unit,Unit{})
    case TableState{+name,expected} <> rest:
      do IO<Unit>:
        actual : List<&2,List<&2,Sql.Cell>> <- Store.q(db,table_query(name),[],100)
        assert(rows_equal(actual,expected),label ++ " preserves every typed " ++ name ++ " cell")
        unchanged(rest,db,label)

def evidence_tables() -> List<&2,String>:
  ["sources","generations","snapshots","raw","records","events",
    "snapshot_context","projection_checks","search"]

def current_tables() -> List<&2,String>:
  List.append(&2,String,evidence_tables(),["archive_captures","archive_chunks"])

def line(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"migration-race\",\"cwd\":\"/synthetic/migration\",\"message\":{\"role\":\"user\",\"content\":\"" ++ text ++ "\"}}\n"

def downgrade(+db: U32,version: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    scalar(db,"SELECT EXISTS(SELECT 1 FROM archive_captures) OR EXISTS(SELECT 1 FROM archive_chunks) OR EXISTS(SELECT 1 FROM generations WHERE typeof(encoding)<>'text' OR encoding<>'identity')","0",
      "old-layout fixture proves no archive state exists before removing archive-only schema")
    Store.statements([
      "DROP TABLE archive_chunks",
      "DROP TABLE archive_captures",
      "ALTER TABLE generations DROP COLUMN encoding",
      "DELETE FROM search",
      "INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) SELECT rowid,body,arguments,result,tool,snapshot,ordinal,event FROM events",
      "CREATE TRIGGER event_search AFTER INSERT ON events BEGIN INSERT INTO search(body,arguments,result,tool,snapshot,ordinal,event) VALUES(new.body,new.arguments,new.result,new.tool,new.snapshot,new.ordinal,new.event); END",
      "PRAGMA user_version=" ++ version,
      "COMMIT"
    ],db)
    scalar(db,"SELECT (SELECT count(*) FROM sqlite_schema WHERE name IN ('archive_captures','archive_chunks'))+(SELECT count(*) FROM pragma_table_info('generations') WHERE name='encoding')","0",
      "old-layout fixture has no encoding column or archive tables")
    scalar(db,"SELECT count(*) FROM search","3","old-layout fixture contains both historical and latest FTS rows")

def prepared(+path: String,+source: String,version: String) -> IO(Baseline):
  do IO<Baseline>:
    +db : U32 <- Store.open(path)
    Store.write_text(source,"w",line("firstneedle café"))
    +old : String <- Store.import_file(db,"claude",source)
    Store.write_text(source,"a",line("secondneedle 中文"))
    +latest : String <- Store.import_file(db,"claude",source)
    old_page : String <- Store.page(db,old,0,100)
    latest_page : String <- Store.page(db,latest,0,100)
    tables : List<&2,TableState> <- remember(current_tables(),db,[])
    downgrade(db,version)
    IO.try(Unit,Sql.close(db))
    return Baseline{old,latest,old_page,latest_page,tables}

def observed(rows: List<&2,List<&2,Sql.Cell>>,expected: String) -> IO(String):
  match rows:
    case [[Sql.Cell.Integer{+version}]]:
      do IO<String>:
        assert(String.eq(version,expected),"contender records a real old typed version before winner migrates")
        return version
    case _:
      IO.die(String,1,"FAIL contender observation has invalid SQLite type")

def winner(path: String,archive: Bool) -> IO(U32):
  match archive:
    case True{}:
      Store.open(path)
    case False{}:
      do IO<U32>:
        +db : U32 <- IO.try(U32,Sql.open(path))
        Store.migrate_search(db)
        scalar(db,"PRAGMA user_version","2","winner completes the real legacy FTS migration to schema2")
        return db

def hit(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"secondneedle","claude","/synthetic/migration","user","",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),1n) &&
      String.eq(Store.field(Store.first(rows),0n),snapshot),"stale contender preserves current snapshot lexical search")
    scalar(db,"SELECT count(*) FROM search","2","stale contender preserves latest-only FTS cardinality")

def preserved(+db: U32,baseline: Baseline,+label: String) -> IO(Unit):
  Baseline{+old,+latest,old_page,latest_page,tables} = baseline
  do IO<Unit>:
    scalar(db,"PRAGMA user_version","3",label ++ " remains at schema3")
    scalar(db,"SELECT count(*) FROM generations WHERE typeof(encoding)<>'text' OR encoding<>'identity'","0",
      label ++ " preserves identity encoding")
    scalar(db,"SELECT count(*) FROM sqlite_schema WHERE type='table' AND name IN ('archive_captures','archive_chunks')","2",
      label ++ " retains both archive table definitions")
    scalar(db,"SELECT count(*) FROM sqlite_schema WHERE type='trigger' AND name='event_search'","0",
      label ++ " keeps obsolete eager FTS trigger removed")
    unchanged(tables,db,label)
    first : String <- Store.page(db,old,0,100)
    last : String <- Store.page(db,latest,0,100)
    assert(String.eq(first,old_page) && String.eq(last,latest_page),label ++ " preserves transcript content at both original snapshot IDs")
    Maintenance.verify(db,old)
    Maintenance.verify(db,latest)
    IO.print("PASS " ++ label ++ " verifies exact retained raw bytes and positions at both original snapshot IDs")
    hit(db,latest)

def race(+label: String,+old_version: String,+complete_archive: Bool) -> IO(Unit):
  +path = ".build/archive-migration-" ++ label ++ ".sqlite"
  do IO<Unit>:
    baseline : Baseline <- prepared(path,"archive-migration-" ++ label ++ ".jsonl",old_version)
    +contender : U32 <- IO.try(U32,Sql.open(path))
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(contender,"PRAGMA user_version",[],1)
    stale : String <- observed(rows,old_version)
    +other : U32 <- winner(path,complete_archive)
    scalar(other,"PRAGMA user_version",Bool.pick(String,complete_archive,"3","2"),
      "winner commits its newer schema before contender enters migration lock")
    Store.schema_version(contender,stale)
    preserved(contender,baseline,label)
    scalar(other,"PRAGMA user_version","3","winning connection sees schema3 after stale contender returns")
    IO.try(Unit,Sql.close(other))
    IO.try(Unit,Sql.close(contender))

def refused(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_eq(code,1) && String.contains(out ++ err,
    "Unsupported Juice Bend library schema version under migration lock"),
    "stale contender refuses the actual unknown version under lock")

def unknown_child(path: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(path))
    Store.schema_version(db,"1")
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,77,"UNKNOWN-MIGRATION-WAS-ACCEPTED")

def unknown(self: String) -> IO(Unit):
  +path = {".build/archive-migration-unknown.sqlite" : String}
  do IO<Unit>:
    baseline : Baseline <- prepared(path,"archive-migration-unknown.jsonl","1")
    +db : U32 <- IO.try(U32,Sql.open(path))
    Store.exec(db,"PRAGMA user_version=42",[])
    expected : List<&2,TableState> <- remember(List.append(&2,String,evidence_tables(),["sqlite_schema"]),db,[])
    IO.try(Unit,Sql.close(db))
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,["unknown-child",path],"",8192,30000))
    refused(result)
    +reopened : U32 <- IO.try(U32,Sql.open(path))
    scalar(reopened,"PRAGMA user_version","42","unknown version remains exact after owned worker exits")
    unchanged(expected,reopened,"unknown-version refusal")
    Store.exec(reopened,"BEGIN IMMEDIATE",[])
    Store.exec(reopened,"ROLLBACK",[])
    IO.print("PASS failed unknown-version migration releases its owned write transaction")
    IO.try(Unit,Sql.close(reopened))

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    race("stale1-winner3","1",True{})
    race("stale0-winner3","0",True{})
    race("stale1-winner2","1",False{})
    unknown(self)
    IO.print("Archive migration race suite passed")

def args(argv: List<String>) -> IO(Unit):
  match argv:
    case [self]: suite(self)
    case [_,"unknown-child",path]: unknown_child(path)
    case _: IO.die(Unit,2,"Invalid archive migration race arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
