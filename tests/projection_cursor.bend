import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

# This is the previous production cursor predicate. The production row encoder
# and checksum chain are shared; only traversal is compared independently.
def previous_walk(fuel: Nat,+db: U32,+snapshot: String,+ordinal: String,event: String,digest: String) -> IO(String):
  match fuel:
    case 0n:
      IO.die(String,1,"Previous cursor test budget exhausted")
    case 1n+rest:
      do IO<String>:
        +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM (SELECT e.*,row_number() OVER (ORDER BY ordinal,event) AS rn,sum(length(CAST(role AS BLOB))+length(CAST(body AS BLOB))+length(CAST(tool AS BLOB))+length(CAST(call_id AS BLOB))+length(CAST(arguments AS BLOB))+length(CAST(result AS BLOB))+length(CAST(repository AS BLOB))+length(CAST(session AS BLOB))+length(CAST(timestamp AS BLOB))+length(CAST(model AS BLOB))+length(CAST(usage AS BLOB))+length(CAST(parent AS BLOB))+length(CAST(coverage AS BLOB))+256) OVER (ORDER BY ordinal,event) AS total_bytes FROM (SELECT * FROM events WHERE snapshot=? AND (ordinal>? OR (ordinal=? AND event>?)) ORDER BY ordinal,event LIMIT 64) e) WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal,event",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{event}],64)
        +last : List<&2,Sql.Cell> = Store.projection_last(rows,[])
        +next : String = Store.projection_rows(rows,digest)
        Store.projection_continue(List.is_empty(&2,List<&2,Sql.Cell>,rows),next,
          unused => previous_walk(rest,db,snapshot,Store.field(last,0n),Store.field(last,1n),next))

def previous_digest(+db: U32,+snapshot: String) -> IO(String):
  do IO<String>:
    header : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.generation,p.extent,p.checkpoint,p.checkpoint_ordinal,p.records,s.provider,s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    seed : String = Domain.digest(Domain.encode(Store.projection_version() ++ "|" ++ Store.projection_cells(Store.first(header))))
    previous_walk(1024n,db,snapshot,"-1","-1",seed)

def equivalent(+db: U32,+snapshot: String,label: String) -> IO(Unit):
  do IO<Unit>:
    expected : String <- previous_digest(db,snapshot)
    actual : String <- Store.projection_digest(db,snapshot)
    assert(String.eq(actual,expected),label)

def valid(+db: U32,snapshot: String,expected: Bool,label: String) -> IO(Unit):
  do IO<Unit>:
    +actual : Bool <- Store.projection_valid(db,snapshot)
    assert(Bool.pick(Bool,expected,actual,Bool.not(actual)),label)

def triple() -> String:
  "{\"type\":\"assistant\",\"cwd\":\"/synthetic/cursor\",\"message\":{\"content\":[{\"type\":\"text\",\"text\":\"first event\"},{\"type\":\"text\",\"text\":\"second event\"},{\"type\":\"text\",\"text\":\"third event\"}]}}\n"

def large() -> String:
  "{\"type\":\"assistant\",\"message\":{\"content\":" ++ Json.quote(String.repeat("x",200000n)) ++ "}}\n"

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/projection-cursor.sqlite")
    Store.write_text("cursor-many.jsonl","w",String.repeat(triple(),48n))
    +snapshot : String <- Store.import_file(db,"claude","cursor-many.jsonl")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM events WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],1)
    assert(String.eq(Store.field(Store.first(rows),0n),"144"),
      "cursor fixture spans multiple64-event pages with three events per physical record")
    equivalent(db,snapshot,"tuple cursor preserves previous projection seal across split physical records")
    valid(db,snapshot,True{},"accepted tuple-cursor projection seal verifies")
    Store.exec(db,"UPDATE events SET body='changed boundary event' WHERE snapshot=? AND ordinal=21 AND event=1",
      [Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,False{},"event immediately after first cursor boundary remains covered by seal")
    equivalent(db,snapshot,"changed first-boundary event has same checksum under both traversals")
    Store.exec(db,"UPDATE events SET body='second event' WHERE snapshot=? AND ordinal=21 AND event=1",
      [Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,True{},"restoring first-boundary event restores original seal")
    Store.exec(db,"UPDATE events SET body='changed second boundary' WHERE snapshot=? AND ordinal=42 AND event=2",
      [Sql.Cell.Integer{snapshot}])
    valid(db,snapshot,False{},"event immediately after second cursor boundary remains covered by seal")
    equivalent(db,snapshot,"changed second-boundary event has same checksum under both traversals")
    Store.write_text("cursor-large.jsonl","w",String.repeat(large(),9n))
    +large_snapshot : String <- Store.import_file(db,"claude","cursor-large.jsonl")
    equivalent(db,large_snapshot,"tuple cursor preserves byte-limited batches below64events")
    valid(db,large_snapshot,True{},"byte-limited projection seal verifies")
    Store.write_text("cursor-empty.jsonl","w","")
    +empty_snapshot : String <- Store.import_file(db,"claude","cursor-empty.jsonl")
    equivalent(db,empty_snapshot,"tuple cursor preserves empty-snapshot seed seal")
    valid(db,empty_snapshot,True{},"empty accepted snapshot seal verifies")
    IO.try(Unit,Sql.close(db))
