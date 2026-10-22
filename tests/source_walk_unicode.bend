import Base
import ../src/source_walk.bend as Walk
import ../src/sources.bend as Sources
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths
import ./source_walk.bend as Harness

# 128 different first Unicode scalars, eight files each: after 64 completed
# branches, 512 files still remain. No branch can be silently skipped.
def members(left: Nat,+root: String,+prefix: String) -> IO(Unit):
  match left:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+ +rest:
      do IO<Unit>:
        Store.write_text(root ++ "/" ++ prefix ++ "-" ++ U32.show(U32.from_nat(rest)) ++ ".jsonl","w","")
        members(rest,root,prefix)

def groups(left: Nat,+root: String) -> IO(Unit):
  match left:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+ +rest:
      do IO<Unit>:
        members(8n,root,SCon{Char.from_u32((19968 + U32.from_nat(rest) : U32)),SNil{}})
        groups(rest,root)

def main() -> IO(Unit):
  do IO<Unit>:
    Harness.command("/bin/mkdir",["-p","unicode-groups"],"create isolated Unicode-group root")
    groups(128n,"unicode-groups")
    +root : String <- Paths.resolve("unicode-groups")
    +db : U32 <- Store.open(".build/unicode.sqlite")
    Sources.add(db,"codex",root)
    +id : String <- Harness.scalar(db,"SELECT id FROM source_roots WHERE canonical_root=?",[Sql.Cell.Text{root}])
    Store.exec(db,"INSERT INTO source_root_files(root,locator) VALUES(?,?)",[Sql.Cell.Integer{id},Sql.Cell.Text{root ++ "/stale.jsonl"}])
    +complete : Walk.Progress <- Harness.drain(db,id,root,300n,1)
    Harness.assert(U32.is_eq(Harness.count(complete),1024),"128 distinct next Unicode scalars complete with all 1024 files")
    queued : String <- Harness.scalar(db,"SELECT count(*) FROM source_root_files WHERE root=?",[Sql.Cell.Integer{id}])
    Harness.assert(String.eq(queued,"1024"),"Unicode shard completion removes the stale path without losing any sibling")
    jobs : String <- Harness.pending(db,id)
    Harness.assert(String.eq(jobs,"0"),"Unicode root leaves no permanently saturated remainder")
    IO.try(Unit,Sql.close(db))
    IO.print("Unicode source walk suite passed")
