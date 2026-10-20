import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def context() -> String:
  "{\"type\":\"session_meta\",\"timestamp\":\"2026-10-01T00:00:00Z\",\"payload\":{\"id\":\"append-session\",\"cwd\":\"/synthetic/append\"}}\n{\"type\":\"turn_context\",\"payload\":{\"model\":\"recorded-model\"}}\n"

def message(body: String) -> String:
  "{\"type\":\"response_item\",\"timestamp\":\"2026-10-01T12:00:00Z\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(body) ++ "}]}}\n"

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),label)

def equivalent(+db: U32,+left: String,+right: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM (SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=? EXCEPT SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{left},Sql.Cell.Integer{right}],"0",label ++ " forward")
    scalar(db,"SELECT count(*) FROM (SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=? EXCEPT SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{right},Sql.Cell.Integer{left}],"0",label ++ " reverse")

def damaged(+db: U32,+path: String,+mutation: String,+label: String) -> IO(Unit):
  +initial = context() ++ message("before append")
  +tail = message("after append")
  do IO<Unit>:
    Store.write_text(path,"w",initial)
    +old : String <- Store.import_file(db,"codex",path)
    good : Bool <- Store.projection_valid(db,old)
    assert(good,label ++ " initial seal verified")
    Store.exec(db,mutation,[Sql.Cell.Integer{old}])
    bad : Bool <- Store.projection_valid(db,old)
    assert(Bool.not(bad),label ++ " corruption detected before append")
    Store.write_text(path,"a",tail)
    +appended : String <- Store.import_file(db,"codex",path)
    Store.write_text(path ++ "-fresh","w",initial ++ tail)
    +fresh : String <- Store.import_file(db,"codex",path ++ "-fresh")
    equivalent(db,appended,fresh,label ++ " repaired append equals independently fresh import")
    scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{appended}],"1",label ++ " replay retains append generation")
    valid : Bool <- Store.projection_valid(db,appended)
    assert(valid,label ++ " repaired accepted projection sealed")
    scalar(db,"SELECT repository||'|'||session||'|'||model FROM events WHERE snapshot=? AND ordinal=3",
      [Sql.Cell.Integer{appended}],"/synthetic/append|append-session|recorded-model",label ++ " inherited context restored from raw")

def clear_model(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("model-clear.jsonl","w",context() ++ message("first"))
    first : String <- Store.import_file(db,"codex","model-clear.jsonl")
    Store.write_text("model-clear.jsonl","a","{\"type\":\"turn_context\",\"payload\":{}}\n{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"name\":\"exec_command\",\"call_id\":\"clear-call\",\"arguments\":\"{}\"}}\n")
    +cleared : String <- Store.import_file(db,"codex","model-clear.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=4",[Sql.Cell.Integer{cleared}],"",
      "explicit model-free Codex turn context clears inherited model before tool")
    Store.write_text("model-clear.jsonl","a",message("still unknown"))
    +next : String <- Store.import_file(db,"codex","model-clear.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=5",[Sql.Cell.Integer{next}],"",
      "cleared Codex model remains unknown across append checkpoint")

def damaged_context(+db: U32) -> IO(Unit):
  +initial = context() ++ message("before context corruption")
  +tail = message("after context corruption")
  do IO<Unit>:
    Store.write_text("changed-context.jsonl","w",initial)
    +old : String <- Store.import_file(db,"codex","changed-context.jsonl")
    Store.exec(db,"UPDATE snapshot_context SET repository='/forged/context',model='forged-context-model' WHERE snapshot=? AND ordinal=2",
      [Sql.Cell.Integer{old}])
    event_seal_valid : Bool <- Store.projection_valid(db,old)
    assert(event_seal_valid,"context checkpoint corruption is independently checked when event seal remains valid")
    Store.write_text("changed-context.jsonl","a",tail)
    +appended : String <- Store.import_file(db,"codex","changed-context.jsonl")
    Store.write_text("changed-context-fresh.jsonl","w",initial ++ tail)
    +fresh : String <- Store.import_file(db,"codex","changed-context-fresh.jsonl")
    equivalent(db,appended,fresh,"modified context checkpoint append equals independently fresh import")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{appended}],"0","modified context checkpoint takes verified full replay")
    scalar(db,"SELECT repository||'|'||session||'|'||model FROM events WHERE snapshot=? AND ordinal=3",
      [Sql.Cell.Integer{appended}],"/synthetic/append|append-session|recorded-model","modified context checkpoint cannot poison inherited scope or model")

def timestamp_record(stamp: String,body: String) -> String:
  "{\"type\":\"user\",\"timestamp\":" ++ Json.quote(stamp) ++ ",\"message\":{\"content\":" ++ Json.quote(body) ++ "}}\n"

def dates(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("date-scope.jsonl","w",timestamp_record("unknown","dateprobe unknown") ++
      timestamp_record("2026-10-99T00:00:00Z","dateprobe invalid") ++
      timestamp_record("2026-10-01T00:30:00+02:00","dateprobe previous day") ++
      timestamp_record("2026-09-30T23:30:00-02:00","dateprobe next day"))
    +snap : String <- Store.import_file(db,"claude","date-scope.jsonl")
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=? AND timestamp='' AND coverage LIKE '%invalid_timestamp%'",
      [Sql.Cell.Integer{snap}],"2","unknown and malformed dates are explicitly excluded from chronology")
    scalar(db,"SELECT timestamp FROM events WHERE snapshot=? AND ordinal=2",[Sql.Cell.Integer{snap}],
      "2026-09-30T22:30:00.000000000Z","positive offset normalized across filter date")
    scalar(db,"SELECT timestamp FROM events WHERE snapshot=? AND ordinal=3",[Sql.Cell.Integer{snap}],
      "2026-10-01T01:30:00.000000000Z","negative offset normalized across filter date")
    +hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"dateprobe","claude","","","2026-10-01",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),1n) && String.eq(Store.field(Store.first(hits),1n),"3"),
      "date scope includes only known UTC instant on or after date")

def large_projection(+db: U32) -> IO(Unit):
  +body = message(String.repeat("x",230000n))
  do IO<Unit>:
    Store.write_text("large-seal.jsonl","w",String.repeat(body,5n))
    +first : String <- Store.import_file(db,"codex","large-seal.jsonl")
    initial : Bool <- Store.projection_valid(db,first)
    assert(initial,"projection hashing pages large rows below SQLite aggregate byte bound")
    Store.write_text("large-seal.jsonl","a",message("small append"))
    +next : String <- Store.import_file(db,"codex","large-seal.jsonl")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{first},Sql.Cell.Integer{next}],"5","valid large projection append reuses verified prefix without reparsing")
    valid : Bool <- Store.projection_valid(db,next)
    assert(valid,"large-row appended projection seal includes every batch")

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/append-integrity.sqlite")
    damaged(db,"deleted-events.jsonl","DELETE FROM events WHERE snapshot=?","deleted projection")
    damaged(db,"changed-events.jsonl","UPDATE events SET model='forged-model',repository='/wrong/repo' WHERE snapshot=?","modified projection")
    damaged(db,"typed-events.jsonl","UPDATE events SET arguments=x'0001' WHERE snapshot=?","modified projection cell type")
    damaged(db,"missing-checkpoint.jsonl","DELETE FROM projection_checks WHERE snapshot=?","missing parser seal")
    damaged(db,"changed-checkpoint.jsonl","UPDATE snapshots SET checkpoint=0,checkpoint_ordinal=0 WHERE id=?","modified checkpoint metadata")
    damaged_context(db)
    clear_model(db)
    dates(db)
    large_projection(db)
    IO.try(Unit,Sql.close(db))
