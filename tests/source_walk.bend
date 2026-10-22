import Base
import ../src/source_walk.bend as Walk
import ../src/sources.bend as Sources
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths

# All filesystem mutations are confined to the runner's new synthetic cwd.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def command_result(result: U32 & (String & String),name: String) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),name)

def command(program: String,args: List<String>,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",8192,5000))
    command_result(result,name)

def job_id(job: Walk.Job) -> String:
  Walk.Job{id,_,_,_,_} = job
  id

def scalar(db: U32,sql: String,params: List<&2,Sql.Cell>) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,params,1)
    return Store.field(Store.first(rows),0n)

def root_name() -> String:
  "root [*]? café"

def basename(index: U32) -> String:
  "café 中文 🙂 [*]?\\ shared-prefix-" ++ U32.show(index)

def create_files(+root: String,count: Nat) -> IO(Unit):
  match count:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+ +rest:
      do IO<Unit>:
        Store.write_text(root ++ "/" ++ basename(U32.from_nat(rest)) ++ ".jsonl","w","")
        create_files(root,rest)

def rejected(+root: String,count: Nat) -> IO(Unit):
  match count:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+ +rest:
      do IO<Unit>:
        Store.write_text(root ++ "/" ++ basename(U32.from_nat(rest)) ++ ".txt","w","")
        rejected(root,rest)

def deep(left: Nat,+root: String) -> IO(Unit):
  match left:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+ +rest:
      +path = root ++ "/nested-" ++ U32.show(U32.from_nat(rest))
      do IO<Unit>:
        command("/bin/mkdir",["-p",path],"create a synthetic nested directory")
        Store.write_text(path ++ "/accepted.json","w","")
        Store.write_text(path ++ "/archive.jsonl.zst","w","")
        Store.write_text(path ++ "/wrong.json.zst","w","")
        deep(rest,path)

def finished(progress: Walk.Progress) -> Bool:
  Walk.Progress{status,_,_} = progress
  String.eq(status,"ok")

def status(progress: Walk.Progress) -> String:
  Walk.Progress{value,_,_} = progress
  value

def count(progress: Walk.Progress) -> U32:
  Walk.Progress{_,value,_} = progress
  value

def pending(db: U32,id: String) -> IO(String):
  scalar(db,"SELECT count(*) FROM source_walk_jobs WHERE root=?",[Sql.Cell.Integer{id}])

def drain_next(round: U32,+progress: Walk.Progress,done: Bool,next: Unit -> IO(Walk.Progress)) -> IO(Walk.Progress):
  match done:
    case True{}:
      do IO<Walk.Progress>:
        assert(U32.is_gt(round,0),"large root requires and completes multiple bounded refreshes")
        return progress
    case False{}:
      do IO<Walk.Progress>:
        assert(String.eq(status(progress),"scanning"),"each incomplete root batch remains explicitly scanning")
        next(Unit{})

def drain(+db: U32,+id: String,+root: String,left: Nat,+round: U32) -> IO(Walk.Progress):
  match left:
    case 0n: IO.die(Walk.Progress,1,"FAIL bounded discovery did not finish within 300 refreshes")
    case 1n+ +rest:
      do IO<Walk.Progress>:
        +progress : Walk.Progress <- Walk.discover(db,id,root)
        drain_next(round,progress,finished(progress),_ => drain(db,id,root,rest,(round + 1 : U32)))

def pure() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(Walk.glob("a*[b]?\\c"),"a\\*\\[b\\]\\?\\\\c"),"literal shard prefixes escape every glob metacharacter")
    assert(String.eq(Walk.glob("café 中文 🙂"),"café 中文 🙂"),"glob escaping preserves Unicode scalars")
    assert(String.eq(Walk.partition("café ","café 中文"),"café 中"),"shard split consumes one complete Unicode scalar")
    assert(String.eq(Walk.partition("exact","exact"),"exact"),"exact-prefix filename is a singleton partition")
    assert(Walk.immediate("/synthetic","/synthetic/new\nline.jsonl"),"newline filename is accepted as one NUL-delimited entry")
    assert(Bool.not(Walk.immediate("/synthetic","/synthetic/nested/file.jsonl")) &&
      Bool.not(Walk.immediate("/synthetic","/syntheticish/file.jsonl")),"shallow entries cannot escape into another directory or root")
    assert(Bool.not(Walk.immediate("/synthetic","/synthetic/..")) &&
      Bool.not(Walk.immediate("/synthetic","/synthetic/�.jsonl")),"unsafe or lossy filename spellings fail explicitly")
    assert(Walk.candidate("/root","/root/active.jsonl") && Walk.candidate("/root","/root/archive.jsonl.zst") &&
      Bool.not(Walk.candidate("/root","/root/archive.json.zst")),"archive admission remains exact and agrees with the capture dispatcher")
    assert(Bool.not(Result.is_done(&2,&2,String,List<&2,String>,Walk.decode("incomplete"))),"unterminated enumeration fails instead of accepting a partial page")

def fixtures() -> IO(Unit):
  do IO<Unit>:
    command("/bin/mkdir",["-p",root_name(),"outside"],"create isolated roots")
    create_files(root_name(),2100n)
    rejected(root_name(),700n)
    deep(12n,root_name())
    Store.write_text(root_name() ++ "/new\nline.jsonl","w","")
    Store.write_text(root_name() ++ "/exact.json","w","")
    Store.write_text("outside/no-read.jsonl","w","must remain outside discovery")
    command("/bin/ln",["-s","../outside/no-read.jsonl",root_name() ++ "/link.jsonl"],"create synthetic file symlink")
    command("/bin/ln",["-s","../outside",root_name() ++ "/link-directory"],"create synthetic directory symlink")

def first_pass(+db: U32,+id: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT INTO source_root_files(root,locator,attempts) VALUES(?,?,7)",
      [Sql.Cell.Integer{id},Sql.Cell.Text{root ++ "/previously-queued.jsonl"}])
    +progress : Walk.Progress <- Walk.discover(db,id,root)
    assert(String.eq(status(progress),"scanning"),"more than 2048 flat entries start resumable discovery instead of failing")
    kept : String <- scalar(db,"SELECT attempts FROM source_root_files WHERE root=? AND locator=?",
      [Sql.Cell.Integer{id},Sql.Cell.Text{root ++ "/previously-queued.jsonl"}])
    assert(String.eq(kept,"7"),"incomplete pass retains the prior queue and retry counts")
    queued : String <- pending(db,id)
    assert(U32.is_gt(Store.number(queued),0),"unfinished traversal jobs are durable")

def completed(+db: U32,+id: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    +progress : Walk.Progress <- drain(db,id,root,300n,1)
    assert(U32.is_eq(count(progress),2126),"all 2100 flat files plus 24 nested and two special files were discovered")
    exact : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE root=?",[Sql.Cell.Integer{id}])
    assert(String.eq(exact,"2126"),"large-root queue contains exactly the independently expected accepted paths")
    stale : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE locator LIKE '%previously-queued%'",[])
    assert(String.eq(stale,"0"),"stale paths leave the queue only after the complete root pass")
    wrong : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE locator LIKE '%.txt' OR locator LIKE '%.json.zst' OR locator LIKE '%link%' OR locator LIKE '%outside%'",[])
    assert(String.eq(wrong,"0"),"wrong extensions and file/directory symlinks never enter the queue")
    exact_name : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE root=? AND locator=?",
      [Sql.Cell.Integer{id},Sql.Cell.Text{root ++ "/" ++ basename(2099) ++ ".jsonl"}])
    assert(String.eq(exact_name,"1"),"literal shared-prefix Unicode/metacharacter filenames survive sharding exactly once")
    jobs : String <- pending(db,id)
    seen : String <- scalar(db,"SELECT count(*) FROM source_walk_seen",[])
    assert(String.eq(jobs,"0") && String.eq(seen,"0"),"completed traversal releases only its temporary jobs and seen set")

def first_job(db: U32,+id: String) -> IO(Walk.Job):
  do IO<Walk.Job>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT id,directory,kind,prefix FROM source_walk_jobs WHERE root=? ORDER BY id LIMIT 1",[Sql.Cell.Integer{id}],1)
    +row : List<&2,Sql.Cell> = Store.first(rows)
    return Walk.Job{Store.field(row,0n),id,Store.field(row,1n),Store.field(row,2n),Store.field(row,3n)}

def disable_fence(+db: U32,+id: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    Walk.start(db,id,root)
    +old : Walk.Job <- first_job(db,id)
    Sources.disable(db,"claude",root)
    jobs : String <- pending(db,id)
    assert(String.eq(jobs,"0"),"disabling a source root atomically cancels its pending traversal")
    stopped : Walk.Progress <- Walk.discover(db,id,root)
    assert(String.eq(status(stopped),"cancelled"),"disabled source cannot begin a replacement pass")
    Sources.add(db,"claude",root)
    Walk.start(db,id,root)
    +new : Walk.Job <- first_job(db,id)
    assert(Bool.not(String.eq(job_id(old),job_id(new))),"re-enabled root receives a new monotonic traversal identity")
    reply : String <- Walk.apply(db,root,old,[root ++ "/late-old-result.jsonl"])
    assert(String.eq(reply,"cancelled"),"late callback from a disabled traversal cannot admit paths after re-enable")
    bad : String <- scalar(db,"SELECT count(*) FROM source_walk_directories WHERE locator LIKE '%late-old-result%'",[])
    assert(String.eq(bad,"0"),"stale discovery callback has no directory side effect")
    Sources.disable(db,"claude",root)
    Sources.add(db,"claude",root)

def failed_pass(+db: U32,+id: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    before : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE root=?",[Sql.Cell.Integer{id}])
    Walk.start(db,id,root)
    job : Walk.Job <- first_job(db,id)
    +failure : Walk.Progress <- Walk.advanced(db,id,job_id(job),"synthetic failure",_ => Walk.finish(db,id))
    assert(String.eq(status(failure),"failed"),"failed traversal reports failure rather than complete discovery")
    after : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE root=?",[Sql.Cell.Integer{id}])
    jobs : String <- pending(db,id)
    assert(String.eq(before,after) && String.eq(jobs,"0"),"failed traversal preserves the previous queue and discards only incomplete traversal state")

def changed_directory(+db: U32,+id: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    command("/bin/mkdir",["-p",root ++ "/race-directory"],"create synthetic traversal-race directory")
    Walk.start(db,id,root)
    Walk.queue_directory(db,id,root ++ "/race-directory")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT id FROM source_walk_jobs WHERE root=? AND directory=? AND kind='f'",
      [Sql.Cell.Integer{id},Sql.Cell.Text{root ++ "/race-directory"}],1)
    +jid : String = Store.field(Store.first(rows),0n)
    command("/bin/rmdir",["--",root ++ "/race-directory"],"remove only the empty synthetic race directory")
    command("/bin/ln",["-s","../outside",root ++ "/race-directory"],"replace synthetic queued directory with an outside symlink")
    +error : String <- Walk.run_job(db,root,Walk.Job{jid,id,root ++ "/race-directory","f",""})
    assert(String.contains(error,"symlink"),"a queued directory changed to a symlink is refused before enumeration")
    failed : Walk.Progress <- Walk.advanced(db,id,jid,error,_ => Walk.finish(db,id))
    assert(String.eq(status(failed),"failed"),"canonical-path failure abandons the incomplete pass honestly")
    outside : String <- scalar(db,"SELECT count(*) FROM source_root_files WHERE locator LIKE '%race-directory/%'",[])
    assert(String.eq(outside,"0"),"outside symlink target supplies no discovery paths")

def main() -> IO(Unit):
  do IO<Unit>:
    pure()
    fixtures()
    +db : U32 <- Store.open(".build/discovery.sqlite")
    Sources.add(db,"claude",root_name())
    +root : String <- Paths.resolve(root_name())
    +id : String <- scalar(db,"SELECT id FROM source_roots WHERE canonical_root=?",[Sql.Cell.Text{root}])
    first_pass(db,id,root)
    +before : String <- pending(db,id)
    IO.try(Unit,Sql.close(db))
    +reopened : U32 <- Store.open(".build/discovery.sqlite")
    +after : String <- pending(reopened,id)
    assert(String.eq(before,after),"closing and reopening the library preserves exact pending traversal progress")
    completed(reopened,id,root)
    disable_fence(reopened,id,root)
    failed_pass(reopened,id,root)
    changed_directory(reopened,id,root)
    IO.try(Unit,Sql.close(reopened))
    IO.print("Source walk suite passed")
