import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/maintenance.bend as Maintenance
import ./publication_crash.bend as Check

def line(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"append-batch-fixture\",\"cwd\":\"/synthetic/append-batches\",\"message\":{\"content\":" ++ Json.quote(text) ++ "}}\n"

def baseline() -> String:
  String.repeat(line("baseline stable"),390n)

def added() -> String:
  line("appended stable")

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  Check.equal_scalar(db,sql,args,expected,label)

def success(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = result
  Check.assert(U32.is_eq(code,0),label ++ " " ++ out ++ err)

def failure(result: U32 & (String & String),needle: String,label: String) -> IO(Unit):
  (code,(out,err)) = result
  Check.assert(U32.is_ne(code,0) && String.contains(out ++ err,needle),label)

def run(self: String,mode: String,prefix: String) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,[mode,prefix],"",8192,30000))

def equivalent(+db: U32,+left: String,+right: String,+label: String) -> IO(Unit):
  +columns = {"ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage" : String}
  do IO<Unit>:
    scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++ " FROM events WHERE snapshot=? EXCEPT SELECT " ++ columns ++ " FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{left},Sql.Cell.Integer{right}],"0",label ++ " forward")
    scalar(db,"SELECT count(*) FROM (SELECT " ++ columns ++ " FROM events WHERE snapshot=? EXCEPT SELECT " ++ columns ++ " FROM events WHERE snapshot=?)",
      [Sql.Cell.Integer{right},Sql.Cell.Integer{left}],"0",label ++ " reverse")

def retained(+db: U32,+snapshot: String,+expected: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"SELECT group_concat(body,'') FROM (SELECT CAST(r.bytes AS TEXT) AS body FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal)",
      [Sql.Cell.Integer{snapshot}],expected,label ++ " exact captured bytes")
    Maintenance.verify(db,snapshot)
    IO.print("PASS " ++ label ++ " complete raw verification")

def reuse(db: U32,old: String,latest: String,count: String,label: String) -> IO(Unit):
  scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
    [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],count,label)

# Restore only deliberate test corruption, then compare every persisted cell
# with the pre-attempt baseline. Any additional publication leak remains visible.
def restore(+db: U32) -> IO(Unit):
  Store.statements([
    "UPDATE raw SET (generation,ordinal,offset,n,digest,bytes,complete,oversized)=(SELECT generation,ordinal,offset,n,digest,bytes,complete,oversized FROM before_raw b WHERE b.id=raw.id)",
    "DELETE FROM records",
    "INSERT INTO records SELECT * FROM before_records",
    "UPDATE snapshots SET extent=(SELECT extent FROM before_snapshots b WHERE b.id=snapshots.id)"
  ],db)

def corrupt(+self: String,+db: U32,+prefix: String,sql: String,args: List<&2,Sql.Cell>,needle: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"PRAGMA foreign_keys=OFF",[])
    Store.exec(db,sql,args)
    Store.exec(db,"PRAGMA foreign_keys=ON",[])
    result : U32 & (String & String) <- run(self,"raw",prefix)
    failure(result,needle,label ++ " rejects append")
    restore(db)
    Check.unchanged_tables(Check.tables(),db,label)

def boundary_corruption(+self: String) -> IO(Unit):
  +prefix = {".build/raw-batches" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",baseline())
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    Store.write_text(prefix ++ "-other.jsonl","w",baseline())
    +other : String <- Store.import_file(db,"claude",prefix ++ "-other.jsonl")
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",added())
    +batch : List<&2,List<&2,Sql.Cell>> <- Store.verify_batch(db,old,0,390)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,batch),128n) &&
      String.eq(Store.field(Store.batch_last(batch,[]),8n),"127"),"raw verification first batch ends exactly at ordinal127")
    +second : List<&2,List<&2,Sql.Cell>> <- Store.verify_batch(db,old,128,390)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,second),128n) &&
      String.eq(Store.field(Store.first(second),8n),"128") &&
      String.eq(Store.field(Store.batch_last(second,[]),8n),"255"),"raw verification second batch spans ordinals128 through255")
    corrupt(self,db,prefix,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=127)",
      [Sql.Cell.Integer{old}],"integrity","last raw row of first batch")
    corrupt(self,db,prefix,"UPDATE raw SET bytes=CAST(bytes AS TEXT) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=128)",
      [Sql.Cell.Integer{old}],"integrity","first raw row of second batch must remain a BLOB")
    corrupt(self,db,prefix,"UPDATE raw SET oversized=1 WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=255)",
      [Sql.Cell.Integer{old}],"integrity","oversized coverage at second batch end")
    corrupt(self,db,prefix,"UPDATE raw SET complete=0 WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=256)",
      [Sql.Cell.Integer{old}],"integrity","newline coverage at third batch start")
    corrupt(self,db,prefix,"UPDATE raw SET digest='damaged-final-digest' WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=389)",
      [Sql.Cell.Integer{old}],"integrity","final partial-batch raw digest")
    corrupt(self,db,prefix,"UPDATE records SET raw=9000000000 WHERE snapshot=? AND ordinal=128",
      [Sql.Cell.Integer{old}],"integrity","missing raw JOIN target cannot skip a boundary row")
    corrupt(self,db,prefix,"UPDATE records SET raw=(SELECT raw FROM records WHERE snapshot=? AND ordinal=255) WHERE snapshot=? AND ordinal=255",
      [Sql.Cell.Integer{other},Sql.Cell.Integer{old}],"integrity","identical boundary bytes from another generation")
    corrupt(self,db,prefix,"UPDATE records SET raw=(SELECT raw FROM records WHERE snapshot=? AND ordinal=257) WHERE snapshot=? AND ordinal=256",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{old}],"integrity","adjacent raw occurrence cannot replace expected ordinal")
    corrupt(self,db,prefix,"UPDATE records SET ordinal=999 WHERE snapshot=? AND ordinal=256",
      [Sql.Cell.Integer{old}],"integrity","map gap with unchanged count cannot skip a boundary row")
    corrupt(self,db,prefix,"UPDATE snapshots SET extent=extent+1 WHERE id=?",
      [Sql.Cell.Integer{old}],"integrity","last record must close the exact snapshot extent")
    +latest : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    reuse(db,old,latest,"390","restored append reuses all three verified prefix batches")
    retained(db,latest,baseline() ++ added(),"restored boundary append")
    scalar(db,"SELECT count(*) FROM search WHERE search MATCH 'appended'",[],"1","restored append publishes only one new lexical occurrence")
    IO.try(Unit,Sql.close(db))

def staged_change(mode: String,+prefix: String) -> IO(Unit):
  match mode:
    case "prefix":
      Store.write_text(prefix ++ ".jsonl","w",String.repeat(line("baseline stable"),255n) ++
        line("baseline forged") ++ String.repeat(line("baseline stable"),134n) ++ added())
    case "tail":
      Store.write_text(prefix ++ ".jsonl","w",baseline() ++ line("appended forged"))
    case "truncate":
      Store.write_text(prefix ++ ".jsonl","w",baseline())
    case "beyond":
      Store.write_text(prefix ++ ".jsonl","a",line("future extension"))
    case _:
      IO.die(Unit,2,"Unknown staged mutation")

def staged_action(stage: String,+mode: String,+prefix: String) -> IO(Unit):
  match stage:
    case "staged":
      do IO<Unit>:
        staged_change(mode,prefix)
        Store.write_text(prefix ++ ".marker","w","staged:" ++ mode ++ "\n")
    case _:
      IO.pure(Unit,Unit{})

def observer(fuel: Nat,+mode: String,+prefix: String) -> Store.ImportObserver:
  match fuel:
    case 0n:
      Store.Unobserved{}
    case 1n+rest:
      Store.Observed{phase => do IO<Store.ImportObserver>:
        staged_action(Store.phase_name(phase),mode,prefix)
        return observer(rest,mode,prefix)}

def stable_rejection(+self: String,+mode: String) -> IO(Unit):
  +prefix = ".build/staged-" ++ mode
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",baseline())
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",added())
    result : U32 & (String & String) <- run(self,mode,prefix)
    failure(result,"Source changed during capture",mode ++ " mutation at Staged rejects publication")
    marker : String <- Check.file_text(prefix ++ ".marker")
    Check.assert(String.eq(marker,"staged:" ++ mode ++ "\n"),mode ++ " exact marker proves source changed after staging")
    Check.unchanged_tables(Check.tables(),db,mode ++ " source stability")
    retained(db,old,baseline(),mode ++ " old immutable snapshot")
    scalar(db,"SELECT count(*) FROM search WHERE search MATCH 'baseline'",[],"390",mode ++ " rollback preserves every old lexical hit")
    scalar(db,"SELECT count(*) FROM search WHERE search MATCH 'appended'",[],"0",mode ++ " rollback publishes no tail hits")
    Store.write_text(prefix ++ ".jsonl","w",baseline() ++ added())
    +retry : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    reuse(db,old,retry,"390",mode ++ " retry reuses unchanged original prefix")
    retained(db,retry,baseline() ++ added(),mode ++ " retry captures exact stable input")
    IO.try(Unit,Sql.close(db))

def beyond_extent(+self: String) -> IO(Unit):
  +prefix = {".build/staged-beyond" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",baseline())
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    Store.write_text(prefix ++ ".jsonl","a",added())
    result : U32 & (String & String) <- run(self,"beyond",prefix)
    success(result,"append beyond observed extent preserves a valid bounded capture")
    marker : String <- Check.file_text(prefix ++ ".marker")
    Check.assert(String.eq(marker,"staged:beyond\n"),"beyond-extent mutation happened at Staged")
    +latest : String <- Check.scalar(db,"SELECT latest FROM sources",[])
    scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{latest}],"391","bounded capture excludes bytes appended after observed extent")
    retained(db,latest,baseline() ++ added(),"bounded post-observation snapshot")
    scalar(db,"SELECT count(*) FROM search WHERE search MATCH 'future'",[],"0","beyond-extent text remains absent until next capture")
    +next : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    reuse(db,latest,next,"391","next capture reuses exact previously observed prefix")
    retained(db,next,baseline() ++ added() ++ line("future extension"),"next snapshot includes later extension")
    retained(db,old,baseline(),"original snapshot remains pinned across both extensions")
    IO.try(Unit,Sql.close(db))

def large_records(+self: String) -> IO(Unit):
  +prefix = {".build/large-raw-batches" : String}
  +raw = String.repeat(line(String.repeat("x",220000n)),9n)
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",raw)
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.verify_batch(db,old,0,9)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),4n) &&
      String.eq(Store.field(Store.batch_last(rows,[]),8n),"3"),"large legal raw rows cut verification batches by bytes before row limit")
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",added())
    corrupt(self,db,prefix,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=4)",
      [Sql.Cell.Integer{old}],"integrity","first raw row after byte-budget cut")
    +latest : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    reuse(db,old,latest,"9","large byte-bound verification preserves every prefix occurrence")
    retained(db,latest,raw ++ added(),"large byte-bound append")
    IO.try(Unit,Sql.close(db))

def fragments(+self: String) -> IO(Unit):
  +prefix = {".build/fragment-raw-batches" : String}
  +raw = String.repeat(line("ordinary prefix"),127n) ++ String.repeat("x",786432n) ++
    line("continuation must remain unsupported") ++ line("ordinary after fragment")
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",raw)
    +old : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{old}],"132","fragment fixture crosses raw row-count and continuation boundaries")
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",added())
    corrupt(self,db,prefix,"UPDATE raw SET oversized=0 WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=128)",
      [Sql.Cell.Integer{old}],"integrity","continued oversized flag at next raw batch")
    +latest : String <- Store.import_file(db,"claude",prefix ++ ".jsonl")
    reuse(db,old,latest,"132","fragment-aware verification reuses all complete prefix occurrences")
    scalar(db,"SELECT count(*) FROM raw r JOIN records i ON i.raw=r.id WHERE i.snapshot=? AND i.ordinal BETWEEN 127 AND 130 AND r.oversized=1",
      [Sql.Cell.Integer{latest}],"4","all logical oversized-line fragments retain unsupported coverage")
    +continuation : String <- Store.page(db,latest,130,1)
    Check.assert(String.contains(continuation,"oversized_record_fragment") && Bool.not(String.contains(continuation,"continuation must remain unsupported")),
      "valid JSON suffix after cross-batch continuation is never parsed as an independent record")
    +ordinary : String <- Store.page(db,latest,131,1)
    Check.assert(String.contains(ordinary,"ordinary after fragment") && Bool.not(String.contains(ordinary,"oversized_record_fragment")),
      "newline ending continuation restores ordinary parsing for next physical record")
    retained(db,latest,raw ++ added(),"fragment-crossing append")
    IO.try(Unit,Sql.close(db))

def message(body: String) -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(body) ++ "}]}}\n"

def model(name: String) -> String:
  "{\"type\":\"turn_context\",\"payload\":{\"model\":" ++ Json.quote(name) ++ "}}\n"

def context_input() -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"batch-context\",\"cwd\":\"/synthetic/context-batches\"}}\n" ++
    model("model-M") ++ String.repeat(message("before clear"),29n) ++
    "{\"type\":\"turn_context\",\"payload\":{}}\n" ++ message("unknown after clear") ++
    model("model-N") ++ String.repeat(message("after replacement"),30n) ++ model("model-P") ++ message("last prefix")

def context_model(value: Maybe<&2,Store.Context>,expected: String) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{Store.Context{repo,session,model,parent}}:
      String.eq(repo,"/synthetic/context-batches") && String.eq(session,"batch-context") &&
        String.eq(model,expected) && String.is_empty(parent)

def check_context(+db: U32,+snapshot: String,ordinal: U32,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT generation,extent,records FROM snapshots WHERE id=?",[Sql.Cell.Integer{snapshot}],1)
    +header : List<&2,Sql.Cell> = Store.first(rows)
    context : Maybe<&2,Store.Context> <- Store.context_before(db,snapshot,Store.field(header,0n),Store.number(Store.field(header,1n)),Store.number(Store.field(header,2n)),ordinal)
    Check.assert(context_model(context,expected),label)

def context_copy(+self: String) -> IO(Unit):
  +prefix = {".build/context-batches" : String}
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    Store.write_text(prefix ++ ".jsonl","w",context_input())
    +old : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    scalar(db,"SELECT records FROM snapshots WHERE id=?",[Sql.Cell.Integer{old}],"66","context fixture spans three32-row copy batches")
    Check.remember_tables(Check.tables(),db)
    Store.write_text(prefix ++ ".jsonl","a",message("appended context"))
    Store.exec(db,"CREATE TRIGGER fail_late_context BEFORE INSERT ON snapshot_context WHEN NEW.snapshot<>" ++ old ++ " AND NEW.ordinal=64 BEGIN SELECT RAISE(ABORT,'late context fixture fault'); END",[])
    result : U32 & (String & String) <- run(self,"context",prefix)
    failure(result,"constraint failed","third context INSERT batch fails at independently chosen ordinal64")
    Check.unchanged_tables(Check.tables(),db,"late context batch failure")
    Store.exec(db,"DROP TRIGGER fail_late_context",[])
    +latest : String <- Store.import_file(db,"codex",prefix ++ ".jsonl")
    reuse(db,old,latest,"66","context batch retry retains every verified prefix raw occurrence")
    scalar(db,"SELECT count(*) FROM snapshot_context a JOIN snapshot_context b ON a.ordinal=b.ordinal AND a.digest<>b.digest WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{latest}],"66","every copied context digest is resealed for new snapshot and extent")
    check_context(db,latest,31,"model-M","record31 context precedes explicit model clear")
    check_context(db,latest,32,"","record32 at new context batch starts with cleared model")
    check_context(db,latest,63,"model-N","record63 retains replacement model at batch end")
    check_context(db,latest,64,"model-N","record64 context remains incoming before next model replacement")
    check_context(db,latest,65,"model-P","record65 sees newly recorded model")
    check_context(db,latest,66,"model-P","appended record inherits verified terminal context")
    check_context(db,old,32,"","old snapshot context remains readable and unchanged")
    Store.write_text(prefix ++ "-fresh.jsonl","w",context_input() ++ message("appended context"))
    +fresh : String <- Store.import_file(db,"codex",prefix ++ "-fresh.jsonl")
    equivalent(db,latest,fresh,"batched context copy equals fresh raw parsing")
    retained(db,latest,context_input() ++ message("appended context"),"batched context snapshot")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    boundary_corruption(self)
    stable_rejection(self,"prefix")
    stable_rejection(self,"tail")
    stable_rejection(self,"truncate")
    beyond_extent(self)
    large_records(self)
    fragments(self)
    context_copy(self)
    IO.print("Append batch suite passed")

def import_child(+db: U32,mode: String,+prefix: String) -> IO(String):
  match mode:
    case "raw":
      Store.import_file(db,"claude",prefix ++ ".jsonl")
    case "context":
      Store.import_file(db,"codex",prefix ++ ".jsonl")
    case _:
      Store.import_observed(db,"claude",prefix ++ ".jsonl",observer(9n,mode,prefix))

def child(mode: String,+prefix: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(prefix ++ ".sqlite")
    snapshot : String <- import_child(db,mode,prefix)
    IO.try(Unit,Sql.close(db))
    IO.print("Accepted snapshot " ++ snapshot)

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case Con{self,Nil{}}:
      suite(self)
    case Con{_,Con{mode,Con{prefix,Nil{}}}}:
      child(mode,prefix)
    case _:
      IO.die(Unit,2,"Append batch test expects zero arguments or its owned child arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
