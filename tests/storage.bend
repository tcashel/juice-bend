import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/storage.sqlite")
    Store.write_text("source.jsonl","w","{\"type\":\"user\",\"sessionId\":\"s1\",\"cwd\":\"/synthetic/repo\",\"message\":{\"role\":\"user\",\"content\":\"preserve lemon evidence\"}}\n")
    +first : String <- Store.import_file(db,"claude","source.jsonl")
    +again : String <- Store.import_file(db,"claude","source.jsonl")
    assert(String.eq(first,again),"unchanged capture reuses snapshot")
    Store.write_text("source.jsonl","a","{\"type\":\"assistant\",\"message\":{\"role\":\"assistant\",\"content\":[{\"type\":\"text\",\"text\":\"second captured turn\"}]}}\n")
    +appended : String <- Store.import_file(db,"claude","source.jsonl")
    assert(Bool.not(String.eq(first,appended)),"append has new snapshot")
    +old : String <- Store.page(db,first,0,100)
    IO.print(old)
    +latest : String <- Store.page(db,appended,0,100)
    IO.print(latest)
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"lemon","","","","",20,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),1n),"search current snapshot only")
    Store.write_text("source.jsonl","w","{\"type\":\"user\",\"message\":{\"content\":\"rewritten generation\"}}\n")
    rewritten : String <- Store.import_file(db,"claude","source.jsonl")
    generations : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM generations",[],1)
    assert(String.eq(Store.field(Store.first(generations),0n),"2"),"rewrite creates generation")
    retained : String <- Store.page(db,first,0,100)
    assert(String.eq(retained,old),"old snapshot survives rewrite")
    IO.try(Unit,Sql.close(db))
