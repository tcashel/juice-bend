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

def fixture() -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"checkpoint-session\",\"cwd\":\"/synthetic/checkpoint\"}}\n" ++
    "{\"type\":\"turn_context\",\"payload\":{\"model\":\"checkpoint-model\"}}\n" ++
    "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"retained before append\"}]}}\n"

def tail() -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"retained appended turn\"}]}}\n"

def summary(context: Store.Context) -> String:
  Store.Context{repository,session,model,parent} = context
  repository ++ "|" ++ session ++ "|" ++ model ++ "|" ++ parent

def has(value: Maybe<&2,Store.Context>,expected: String) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{context}:
      String.eq(summary(context),expected)

def missing(value: Maybe<&2,Store.Context>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{_}:
      False{}

def context(+db: U32,+snapshot: String,ordinal: U32) -> IO(Maybe<&2,Store.Context>):
  do IO<Maybe<&2,Store.Context>>:
    headers : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT generation,extent,records FROM snapshots WHERE id=?",
      [Sql.Cell.Integer{snapshot}],1)
    +header : List<&2,Sql.Cell> = Store.first(headers)
    Store.context_before(db,snapshot,Store.field(header,0n),Store.number(Store.field(header,1n)),
      Store.number(Store.field(header,2n)),ordinal)

def scalar(db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),name)

def rejected(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,"integrity"),name)

def check_child(self: String,snapshot: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,[snapshot],"",8192,10000))
    rejected(result,name)

def corruption(+db: U32,+self: String,+snapshot: String,sql: String,
  label: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,sql,[Sql.Cell.Integer{snapshot}])
    check_child(self,snapshot,label)
    Maintenance.rebuild(db,snapshot)
    restored : Maybe<&2,Store.Context> <- context(db,snapshot,2)
    assert(has(restored,"/synthetic/checkpoint|checkpoint-session|checkpoint-model|"),
      "verified raw rebuild restores valid context")

def replay_missing(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("missing-context.jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex","missing-context.jsonl")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=1",
      [Sql.Cell.Integer{old}])
    absent : Maybe<&2,Store.Context> <- context(db,old,1)
    assert(missing(absent),"missing legacy checkpoint requests verified prefix fallback")
    Store.write_text("missing-context.jsonl","a",tail())
    +new : String <- Store.import_file(db,"codex","missing-context.jsonl")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"0",
      "missing context checkpoint triggers complete verified append replay")
    scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"1",
      "context replay retains exact-append generation")
    recovered : Maybe<&2,Store.Context> <- context(db,new,3)
    assert(has(recovered,"/synthetic/checkpoint|checkpoint-session|checkpoint-model|"),
      "append replay produces complete inherited context from raw")

def large(+db: U32) -> IO(Unit):
  +repository = "/synthetic/" ++ String.repeat("r",230000n)
  +record = "{\"type\":\"user\",\"cwd\":" ++ Json.quote(repository) ++
    ",\"message\":{\"content\":\"large context\"}}\n"
  do IO<Unit>:
    Store.write_text("large-context.jsonl","w",String.repeat(record,7n))
    +old : String <- Store.import_file(db,"claude","large-context.jsonl")
    Store.write_text("large-context.jsonl","a",
      "{\"type\":\"user\",\"message\":{\"content\":\"large context append\"}}\n")
    +new : String <- Store.import_file(db,"claude","large-context.jsonl")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"7",
      "context copying bounds large fields by bytes and retains verified prefix")
    found : Maybe<&2,Store.Context> <- context(db,new,7)
    assert(has(found,repository ++ "|||"),"large inherited repository survives context resealing")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/context.sqlite")
    Store.write_text("context.jsonl","w",fixture())
    +old : String <- Store.import_file(db,"codex","context.jsonl")
    first : Maybe<&2,Store.Context> <- context(db,old,0)
    assert(has(first,"|||"),"first record checkpoint has empty incoming parser context")
    before : Maybe<&2,Store.Context> <- context(db,old,2)
    assert(has(before,"/synthetic/checkpoint|checkpoint-session|checkpoint-model|"),
      "checkpoint contains inherited state before selected record")
    scalar(db,"SELECT count(*) FROM snapshot_context WHERE snapshot=?",
      [Sql.Cell.Integer{old}],"3","capture creates exactly one checkpoint per physical record")
    Store.write_text("context.jsonl","a",tail())
    +new : String <- Store.import_file(db,"codex","context.jsonl")
    scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"3","valid checkpoints preserve append prefix reuse")
    scalar(db,"SELECT count(*) FROM snapshot_context a JOIN snapshot_context b ON a.ordinal=b.ordinal AND a.digest<>b.digest WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}],"3","copied checkpoints are resealed to new snapshot and extent")
    old_context : Maybe<&2,Store.Context> <- context(db,old,2)
    assert(has(old_context,"/synthetic/checkpoint|checkpoint-session|checkpoint-model|"),
      "append leaves old accepted context readable and stable")
    latest : Maybe<&2,Store.Context> <- context(db,new,3)
    assert(has(latest,"/synthetic/checkpoint|checkpoint-session|checkpoint-model|"),
      "new appended record receives complete incoming context")
    corruption(db,self,new,"UPDATE snapshot_context SET repository='/forged' WHERE snapshot=? AND ordinal=2",
      "repository mutation fails checkpoint integrity")
    corruption(db,self,new,"UPDATE snapshot_context SET parent=x'' WHERE snapshot=? AND ordinal=2",
      "blob cannot masquerade as an empty text context field")
    corruption(db,self,new,"UPDATE snapshot_context SET digest='broken' WHERE snapshot=? AND ordinal=2",
      "checkpoint checksum mutation is rejected")
    Store.exec(db,"UPDATE snapshot_context SET digest=(SELECT digest FROM snapshot_context WHERE snapshot=? AND ordinal=2) WHERE snapshot=? AND ordinal=2",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{new}])
    check_child(self,new,"checkpoint from another snapshot cannot replace selected identity")
    Maintenance.rebuild(db,new)
    Store.exec(db,"UPDATE snapshot_context SET version='future-parser' WHERE snapshot=? AND ordinal=2",
      [Sql.Cell.Integer{new}])
    stale : Maybe<&2,Store.Context> <- context(db,new,2)
    assert(missing(stale),"stale parser version requests verified raw fallback")
    Maintenance.rebuild(db,new)
    Store.exec(db,"DELETE FROM events WHERE snapshot=?",[Sql.Cell.Integer{new}])
    detached : Maybe<&2,Store.Context> <- context(db,new,2)
    assert(has(detached,"/synthetic/checkpoint|checkpoint-session|checkpoint-model|"),
      "checkpoint resolution does not depend on mutable projected event rows")
    Maintenance.rebuild(db,new)
    replay_missing(db)
    large(db)
    IO.try(Unit,Sql.close(db))

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> Nil{}:
      suite(self)
    case _ <> snapshot <> Nil{}:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/context.sqlite")
        value : Maybe<&2,Store.Context> <- context(db,snapshot,2)
        assert(Bool.not(missing(value)),"child resolved a valid current checkpoint")
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Invalid isolated context test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
