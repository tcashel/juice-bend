import Base
import ./store.bend as Store
import ./sql.bend as Sql

# Persisted shallow traversal. find supplies only filesystem entries; Bend owns
# filename admission, escaping, partitioning, queue policy and completion.
# A pass may span refreshes/restarts. Found files are immediately eligible, but
# absence is applied only after every job finishes. Captured sources are never
# deleted. Per call: four jobs; per response: 64 KiB and 256 entries. Saturated
# flat directories split into disjoint literal-name prefixes rather than fail
# merely because the root contains more than one page of entries.
type Progress is Data:
  Progress{status: String, files: U32, error: String}

type Job is Data:
  Job{id: String, root: String, directory: String, kind: String, prefix: String}

def schema(db: U32) -> IO(Unit):
  Store.statements([
    "CREATE TABLE IF NOT EXISTS source_walk_pass(root INTEGER PRIMARY KEY REFERENCES source_roots(id) ON DELETE CASCADE)",
    "CREATE TABLE IF NOT EXISTS source_walk_jobs(id INTEGER PRIMARY KEY AUTOINCREMENT,root INTEGER NOT NULL REFERENCES source_walk_pass(root) ON DELETE CASCADE,directory TEXT NOT NULL,kind TEXT NOT NULL CHECK(kind IN ('d','f')),prefix TEXT NOT NULL)",
    "CREATE INDEX IF NOT EXISTS source_walk_pending ON source_walk_jobs(root,id)",
    "CREATE TABLE IF NOT EXISTS source_walk_excluded(job INTEGER NOT NULL REFERENCES source_walk_jobs(id) ON DELETE CASCADE,part TEXT NOT NULL,exact INTEGER NOT NULL CHECK(exact IN (0,1)),PRIMARY KEY(job,part,exact)) WITHOUT ROWID",
    "CREATE TABLE IF NOT EXISTS source_walk_seen(root INTEGER NOT NULL REFERENCES source_walk_pass(root) ON DELETE CASCADE,locator TEXT NOT NULL,PRIMARY KEY(root,locator)) WITHOUT ROWID",
    "CREATE TABLE IF NOT EXISTS source_walk_directories(root INTEGER NOT NULL REFERENCES source_walk_pass(root) ON DELETE CASCADE,locator TEXT NOT NULL,PRIMARY KEY(root,locator)) WITHOUT ROWID"
  ],db)

def cancel(db: U32,provider: String,path: String) -> IO(Unit):
  Store.exec(db,"DELETE FROM source_walk_pass WHERE root IN(SELECT id FROM source_roots WHERE provider=? AND canonical_root=?)",
    [Sql.Cell.Text{provider},Sql.Cell.Text{path}])

def candidate(+root: String,+path: String) -> Bool:
  String.starts_with(path,Bool.pick(String,String.eq(root,"/"),"/",root ++ "/")) &&
    Nat.is_le(String.length(path),4096n) &&
    (String.ends_with(path,".jsonl") || String.ends_with(path,".json") || String.ends_with(path,".jsonl.zst"))

# find -name uses glob syntax, independently of shell escaping. Prefixes and
# sampled characters are escaped one character at a time, including backslash.
def glob(text: String) -> String:
  match text:
    case SNil{}: ""
    case SCon{+c,rest}:
      Bool.pick(String,Char.is_eq(c,'*') || Char.is_eq(c,'?') || Char.is_eq(c,'[') ||
        Char.is_eq(c,']') || Char.is_eq(c,'\\'),"\\","") ++ SCon{c,glob(rest)}

def child_prefix(+directory: String) -> String:
  Bool.pick(String,String.eq(directory,"/"),"/",directory ++ "/")

def leaf(directory: String,path: String) -> String:
  String.drop(path,String.length(child_prefix(directory)))

def immediate(+directory: String,+path: String) -> Bool:
  +name = leaf(directory,path)
  String.starts_with(path,child_prefix(directory)) && Bool.not(String.is_empty(name)) &&
    Bool.not(String.eq(name,".")) && Bool.not(String.eq(name,"..")) &&
    Bool.not(String.contains(name,"/")) && Bool.not(String.contains(path,"\0")) &&
    Bool.not(String.contains(path,"�")) && Nat.is_le(String.length(path),4096n)

def excluded_match(+name: String,rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case []: False{}
    case +row <> rest:
      Bool.pick(Bool,String.eq(Store.field(row,1n),"1"),
        String.eq(name,Store.field(row,0n)),String.starts_with(name,Store.field(row,0n))) ||
        excluded_match(name,rest)

def valid_paths(paths: List<&2,String>,+directory: String,+prefix: String,
  +excluded: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match paths:
    case []: True{}
    case +path <> rest:
      immediate(directory,path) && String.starts_with(leaf(directory,path),prefix) &&
        Bool.not(excluded_match(leaf(directory,path),excluded)) &&
        valid_paths(rest,directory,prefix,excluded)

def decode_valid(+out: String,empty: Bool,terminated: Bool) -> Result<&2,&2,String,List<&2,String>>:
  match empty terminated:
    case True{} _: Done{[]}
    case _ False{}: Fail{"Directory enumeration returned incomplete entries; prior queue retained"}
    case _ True{}:
      Done{String.split(String.take(out,Nat.sub(String.length(out),1n)),'\0')}

def decode(+out: String) -> Result<&2,&2,String,List<&2,String>>:
  decode_valid(out,String.is_empty(out),String.ends_with(out,"\0"))

def exclusions(rows: List<&2,List<&2,Sql.Cell>>) -> List<String>:
  match rows:
    case []: []
    case +row <> rest:
      "!" <> "-name" <> (glob(Store.field(row,0n)) ++
        Bool.pick(String,String.eq(Store.field(row,1n),"1"),"","*")) <> exclusions(rest)

def append(xs: List<String>,ys: List<String>) -> List<String>:
  match xs:
    case []: ys
    case x <> rest: x <> append(rest,ys)

def argv(job: Job,rows: List<&2,List<&2,Sql.Cell>>,sample: Bool) -> List<String>:
  Job{_,_,directory,kind,prefix} = job
  append(["-P",directory,"-mindepth","1","-maxdepth","1","-type",kind,
    "-name",glob(prefix) ++ "*"],append(exclusions(rows),
      Bool.pick(List<String>,sample,["-print0","-quit"],["-print0"])))

# A character can require four UTF-8 bytes; this conservative argv estimate is
# independent of locale and avoids passing an oversized argument vector.
def argv_size(args: List<String>) -> Nat:
  match args:
    case []: 0n
    case arg <> rest: Nat.add(Nat.add(Nat.mul(String.length(arg),4n),1n),argv_size(rest))

def queue_file(+db: U32,+root: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT OR IGNORE INTO source_walk_seen(root,locator) VALUES(?,?)",
      [Sql.Cell.Integer{root},Sql.Cell.Text{path}])
    Store.exec(db,"INSERT INTO source_root_files(root,locator,available) VALUES(?,?,1) ON CONFLICT(root,locator) DO UPDATE SET available=1",
      [Sql.Cell.Integer{root},Sql.Cell.Text{path}])

def queue_directory(+db: U32,+root: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"INSERT INTO source_walk_jobs(root,directory,kind,prefix) SELECT ?,?,'d','' WHERE NOT EXISTS(SELECT 1 FROM source_walk_directories WHERE root=? AND locator=?)",
      [Sql.Cell.Integer{root},Sql.Cell.Text{path},Sql.Cell.Integer{root},Sql.Cell.Text{path}])
    Store.exec(db,"INSERT INTO source_walk_jobs(root,directory,kind,prefix) SELECT ?,?,'f','' WHERE NOT EXISTS(SELECT 1 FROM source_walk_directories WHERE root=? AND locator=?)",
      [Sql.Cell.Integer{root},Sql.Cell.Text{path},Sql.Cell.Integer{root},Sql.Cell.Text{path}])
    Store.exec(db,"INSERT OR IGNORE INTO source_walk_directories(root,locator) VALUES(?,?)",
      [Sql.Cell.Integer{root},Sql.Cell.Text{path}])

def accept_kind(db: U32,root: String,kind: String,path: String,valid: Bool) -> IO(Unit):
  match kind valid:
    case "d" _: queue_directory(db,root,path)
    case "f" True{}: queue_file(db,root,path)
    case _ _: IO.pure(Unit,Unit{})

def accept_one(db: U32,root: String,canonical: String,kind: String,+path: String) -> IO(Unit):
  accept_kind(db,root,kind,path,candidate(canonical,path))

def accept(+db: U32,+root: String,+canonical: String,+kind: String,paths: List<&2,String>) -> IO(Unit):
  match paths:
    case []: IO.pure(Unit,Unit{})
    case +path <> rest:
      do IO<Unit>:
        accept_one(db,root,canonical,kind,path)
        accept(db,root,canonical,kind,rest)

def active(db: U32,job: Job) -> IO(Bool):
  Job{id,root,_,_,_} = job
  do IO<Bool>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT j.id FROM source_walk_jobs j JOIN source_roots r ON r.id=j.root AND r.enabled=1 WHERE j.id=? AND j.root=?",
      [Sql.Cell.Integer{id},Sql.Cell.Integer{root}],1)
    return Bool.not(List.is_empty(&2,List<&2,Sql.Cell>,rows))

def applied(+db: U32,canonical: String,job: Job,paths: List<&2,String>,live: Bool) -> IO(String):
  Job{id,root,_,kind,_} = job
  match live:
    case False{}:
      do IO<String>:
        Store.exec(db,"COMMIT",[])
        return "cancelled"
    case True{}:
      do IO<String>:
        accept(db,root,canonical,kind,paths)
        Store.exec(db,"DELETE FROM source_walk_jobs WHERE id=?",[Sql.Cell.Integer{id}])
        Store.exec(db,"COMMIT",[])
        return ""

def apply(+db: U32,canonical: String,+job: Job,paths: List<&2,String>) -> IO(String):
  do IO<String>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    live : Bool <- active(db,job)
    applied(db,canonical,job,paths,live)

# Split on the next complete Unicode scalar in an actually returned filename.
# The positive child and excluded-prefix remainder are disjoint and exhaustive.
# A filename exactly equal to the current prefix is handled as one singleton.
def partition(+prefix: String,+name: String) -> String:
  prefix ++ String.take(String.drop(name,String.length(prefix)),1n)

def split_child(db: U32,canonical: String,root: String,directory: String,kind: String,
  part: String,sample: String,exact: Bool) -> IO(Unit):
  match exact:
    case True{}: accept_one(db,root,canonical,kind,sample)
    case False{}:
      Store.exec(db,"INSERT INTO source_walk_jobs(root,directory,kind,prefix) VALUES(?,?,?,?)",
        [Sql.Cell.Integer{root},Sql.Cell.Text{directory},Sql.Cell.Text{kind},Sql.Cell.Text{part}])

def split_part(+db: U32,canonical: String,+id: String,+root: String,directory: String,
  +kind: String,+part: String,sample: String,+exact: Bool) -> IO(String):
  do IO<String>:
    split_child(db,canonical,root,directory,kind,part,sample,exact)
    Store.exec(db,"INSERT INTO source_walk_excluded(job,part,exact) VALUES(?,?,?)",
      [Sql.Cell.Integer{id},Sql.Cell.Text{part},Sql.Cell.Integer{Bool.pick(String,exact,"1","0")}])
    # Move the remainder behind its new positive child and other pending jobs.
    # Existing exclusion rows follow the id change via this explicit copy.
    Store.exec(db,"INSERT INTO source_walk_jobs(root,directory,kind,prefix) SELECT root,directory,kind,prefix FROM source_walk_jobs WHERE id=?",[Sql.Cell.Integer{id}])
    Store.exec(db,"INSERT INTO source_walk_excluded(job,part,exact) SELECT (SELECT max(id) FROM source_walk_jobs),part,exact FROM source_walk_excluded WHERE job=?",[Sql.Cell.Integer{id}])
    Store.exec(db,"DELETE FROM source_walk_jobs WHERE id=?",[Sql.Cell.Integer{id}])
    Store.exec(db,"COMMIT",[])
    return ""

def split_live(db: U32,canonical: String,job: Job,+sample: String,live: Bool) -> IO(String):
  Job{+id,+root,+directory,+kind,+prefix} = job
  match live:
    case False{}:
      do IO<String>:
        Store.exec(db,"COMMIT",[])
        return "cancelled"
    case True{}:
      +name = leaf(directory,sample)
      split_part(db,canonical,id,root,directory,kind,partition(prefix,name),sample,String.eq(prefix,name))

def split(+db: U32,canonical: String,+job: Job,sample: String) -> IO(String):
  do IO<String>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    live : Bool <- active(db,job)
    split_live(db,canonical,job,sample,live)

def bounded_paths(db: U32,canonical: String,job: Job,+paths: List<&2,String>,small: Bool) -> IO(String):
  match paths small:
    case _ True{}: apply(db,canonical,job,paths)
    case path <> _ False{}: split(db,canonical,job,path)
    case [] _: IO.pure(String,"Directory enumeration returned an invalid saturated page")

def checked_paths(db: U32,canonical: String,job: Job,+paths: List<&2,String>,valid: Bool) -> IO(String):
  match valid:
    case False{}: IO.pure(String,"Directory entries exceeded path/encoding bounds or disagreed with the requested shard; prior queue retained")
    case True{}: bounded_paths(db,canonical,job,paths,Nat.is_le(List.length(&2,String,paths),256n))

def decoded(db: U32,canonical: String,+job: Job,+excluded: List<&2,List<&2,Sql.Cell>>,
  decoded: Result<&2,&2,String,List<&2,String>>) -> IO(String):
  Job{_,_,directory,_,prefix} = job
  match decoded:
    case Fail{error}: IO.pure(String,error)
    case Done{+paths}:
      checked_paths(db,canonical,job,paths,valid_paths(paths,directory,prefix,excluded))

def sample_checked(db: U32,canonical: String,job: Job,path: String,valid: Bool) -> IO(String):
  match valid:
    case True{}: split(db,canonical,job,path)
    case False{}: IO.pure(String,"Directory shard sample exceeds path/encoding bounds; prior queue retained")

def sample_decoded(db: U32,canonical: String,+job: Job,+excluded: List<&2,List<&2,Sql.Cell>>,
  decoded: Result<&2,&2,String,List<&2,String>>) -> IO(String):
  Job{_,_,directory,_,prefix} = job
  match decoded:
    case Done{+path <> []}:
      sample_checked(db,canonical,job,path,valid_paths([path],directory,prefix,excluded))
    case _:
      IO.pure(String,"Saturated directory changed during enumeration; prior queue retained; next refresh restarts")

def sample_result(db: U32,canonical: String,job: Job,excluded: List<&2,List<&2,Sql.Cell>>,
  result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Done{(0,(out,_))}: sample_decoded(db,canonical,job,excluded,decode(out))
    case _: IO.pure(String,"Directory shard sample could not complete within 2 seconds; prior queue retained")

def enumerated(+db: U32,+canonical: String,+job: Job,+excluded: List<&2,List<&2,Sql.Cell>>,
  result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Done{(0,(out,_))}: decoded(db,canonical,job,excluded,decode(out))
    case Fail{(27,_)}:
      # EFBIG is 27 on the pinned macOS host and portable Linux test host.
      do IO<String>:
        sample : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run("/usr/bin/find",argv(job,excluded,True{}),"",65536,2000)
        sample_result(db,canonical,job,excluded,sample)
    case _: IO.pure(String,"Directory enumeration failed or exceeded 2 seconds; prior queue retained; next refresh restarts")

def enumerate(+db: U32,+canonical: String,+job: Job,+excluded: List<&2,List<&2,Sql.Cell>>,valid: Bool) -> IO(String):
  match valid:
    case False{}: IO.pure(String,"Directory shard is invalid or exceeds the 64 KiB argument budget; prior queue retained; choose a narrower root")
    case True{}:
      do IO<String>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run("/usr/bin/find",argv(job,excluded,False{}),"",65536,2000)
        enumerated(db,canonical,job,excluded,result)

def valid_exclusion(+prefix: String,+part: String,exact: String) -> Bool:
  match exact:
    case "1": String.eq(prefix,part)
    case "0": String.starts_with(part,prefix) &&
      Nat.is_eq(String.length(String.drop(part,String.length(prefix))),1n) &&
      Bool.not(String.contains(part,"/")) && Bool.not(String.contains(part,"\0"))
    case _: False{}

def valid_exclusions(+prefix: String,rows: List<&2,List<&2,Sql.Cell>>) -> Bool:
  match rows:
    case []: True{}
    case +row <> rest:
      valid_exclusion(prefix,Store.field(row,0n),Store.field(row,1n)) && valid_exclusions(prefix,rest)

def canonical_checked(db: U32,canonical: String,+job: Job,+excluded: List<&2,List<&2,Sql.Cell>>,valid: Bool) -> IO(String):
  Job{_,_,_,_,prefix} = job
  match valid:
    case False{}: IO.pure(String,"Queued directory changed canonical path or became a symlink; prior queue retained; next refresh restarts")
    case True{}:
      enumerate(db,canonical,job,excluded,valid_exclusions(prefix,excluded) && Nat.is_le(List.length(&2,List<&2,Sql.Cell>,excluded),1638n) &&
        Nat.is_le(argv_size(argv(job,excluded,False{})),65536n))

def canonical_result(db: U32,canonical: String,+job: Job,+excluded: List<&2,List<&2,Sql.Cell>>,
  result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  Job{_,_,+directory,_,_} = job
  match result:
    case Done{(0,(out,_))}:
      canonical_checked(db,canonical,job,excluded,String.eq(out,directory ++ "\n"))
    case _: IO.pure(String,"Queued directory disappeared or cannot be canonicalized; prior queue retained; next refresh restarts")

def run_excluded(+db: U32,+canonical: String,+job: Job) -> IO(String):
  Job{id,_,directory,_,_} = job
  do IO<String>:
    +excluded : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT part,exact FROM source_walk_excluded WHERE job=? ORDER BY part,exact LIMIT 1639",
      [Sql.Cell.Integer{id}],1639)
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/realpath",["--",directory],"",32768,2000)
    canonical_result(db,canonical,job,excluded,result)

# Bound persisted exclusion extraction before loading it. The estimate charges
# eight bytes per scalar for UTF-8 plus glob escaping and forty bytes of argv
# overhead per exclusion. Thus a 64 KiB budget implies at most 1638 rows; the
# 1639th row above is only an overflow sentinel, not a sibling-name policy.
def exclusion_budget(+bytes: String) -> Bool:
  Store.numeric(bytes) && U32.is_le(Store.number(bytes),65536)

def run_budget(db: U32,canonical: String,job: Job,valid: Bool) -> IO(String):
  match valid:
    case False{}: IO.pure(String,"Directory shard exceeds the 64 KiB argument budget; prior queue retained; choose a narrower root")
    case True{}: run_excluded(db,canonical,job)

def run_prepared(+db: U32,+canonical: String,+job: Job) -> IO(String):
  Job{id,_,_,_,_} = job
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT coalesce(sum(8*length(part)+40),0) FROM source_walk_excluded WHERE job=?",
      [Sql.Cell.Integer{id}],1)
    run_budget(db,canonical,job,exclusion_budget(Store.field(Store.first(rows),0n)))

def valid_job(+canonical: String,job: Job) -> Bool:
  Job{_,_,+directory,+kind,+prefix} = job
  (String.eq(directory,canonical) || String.starts_with(directory,child_prefix(canonical))) &&
    Nat.is_le(String.length(directory),4096n) && Bool.not(String.contains(directory,"\0")) &&
    (String.eq(kind,"d") || String.eq(kind,"f")) &&
    Nat.is_le(String.length(prefix),4096n) && Bool.not(String.contains(prefix,"/")) &&
    Bool.not(String.contains(prefix,"\0"))

def run_valid(db: U32,canonical: String,job: Job,valid: Bool) -> IO(String):
  match valid:
    case False{}: IO.pure(String,"Persisted discovery job disagrees with its approved root or bounds; prior queue retained")
    case True{}: run_prepared(db,canonical,job)

def run_job(db: U32,+canonical: String,+job: Job) -> IO(String):
  run_valid(db,canonical,job,valid_job(canonical,job))

def start(+db: U32,+id: String,+canonical: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT OR IGNORE INTO source_walk_pass(root) SELECT id FROM source_roots WHERE id=? AND canonical_root=? AND enabled=1",
      [Sql.Cell.Integer{id},Sql.Cell.Text{canonical}])
    # The marker survives all job completion and makes initialization idempotent.
    Store.exec(db,"INSERT INTO source_walk_jobs(root,directory,kind,prefix) SELECT root,?,'d','' FROM source_walk_pass WHERE root=? AND NOT EXISTS(SELECT 1 FROM source_walk_directories WHERE root=?)",
      [Sql.Cell.Text{canonical},Sql.Cell.Integer{id},Sql.Cell.Integer{id}])
    Store.exec(db,"INSERT INTO source_walk_jobs(root,directory,kind,prefix) SELECT root,?,'f','' FROM source_walk_pass WHERE root=? AND NOT EXISTS(SELECT 1 FROM source_walk_directories WHERE root=?)",
      [Sql.Cell.Text{canonical},Sql.Cell.Integer{id},Sql.Cell.Integer{id}])
    Store.exec(db,"INSERT OR IGNORE INTO source_walk_directories(root,locator) SELECT root,? FROM source_walk_pass WHERE root=?",
      [Sql.Cell.Text{canonical},Sql.Cell.Integer{id}])
    Store.exec(db,"COMMIT",[])

def complete(+db: U32,+id: String,count: U32,done: Bool) -> IO(Progress):
  match done:
    case False{}:
      do IO<Progress>:
        Store.exec(db,"COMMIT",[])
        return Progress{"scanning",count,"Discovery is resumable; previously queued files remain available until this root pass completes"}
    case True{}:
      do IO<Progress>:
        Store.exec(db,"DELETE FROM source_root_files WHERE root=? AND NOT EXISTS(SELECT 1 FROM source_walk_seen s WHERE s.root=source_root_files.root AND s.locator=source_root_files.locator)",[Sql.Cell.Integer{id}])
        Store.exec(db,"DELETE FROM source_walk_pass WHERE root=?",[Sql.Cell.Integer{id}])
        Store.exec(db,"COMMIT",[])
        return Progress{"ok",count,""}

def finish_count(+db: U32,id: String,+count: String,pending: String,valid: Bool) -> IO(Progress):
  match valid:
    case False{}:
      do IO<Progress>:
        Store.exec(db,"COMMIT",[])
        return Progress{"failed",0,"Root discovery count exceeds the exact U32 reporting bound; prior queue retained"}
    case True{}: complete(db,id,Store.number(count),String.eq(pending,"0"))

def finish_rows(db: U32,id: String,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Progress):
  match rows:
    case []:
      do IO<Progress>:
        Store.exec(db,"COMMIT",[])
        return Progress{"cancelled",0,"Source root was disabled or its discovery pass was replaced"}
    case +row <> _:
      finish_count(db,id,Store.field(row,0n),Store.field(row,1n),Store.numeric(Store.field(row,0n)))

def finish(+db: U32,+id: String) -> IO(Progress):
  do IO<Progress>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM source_walk_seen WHERE root=p.root),(SELECT count(*) FROM source_walk_jobs WHERE root=p.root) FROM source_walk_pass p JOIN source_roots r ON r.id=p.root AND r.enabled=1 WHERE p.root=?",
      [Sql.Cell.Integer{id}],1)
    finish_rows(db,id,rows)

def advanced(+db: U32,+id: String,job_id: String,error: String,next: Unit -> IO(Progress)) -> IO(Progress):
  match error:
    case "": next(Unit{})
    case "cancelled": IO.pure(Progress,Progress{"cancelled",0,"Source settings or discovery pass changed while directory enumeration was in flight"})
    case _:
      do IO<Progress>:
        Store.exec(db,"DELETE FROM source_walk_pass WHERE root=? AND EXISTS(SELECT 1 FROM source_walk_jobs WHERE id=? AND root=?)",
          [Sql.Cell.Integer{id},Sql.Cell.Integer{job_id},Sql.Cell.Integer{id}])
        return Progress{"failed",0,error}

def advance_rows(+db: U32,+id: String,+canonical: String,
  rows: List<&2,List<&2,Sql.Cell>>,next: Unit -> IO(Progress)) -> IO(Progress):
  match rows:
    case []: finish(db,id)
    case +row <> _:
      do IO<Progress>:
        error : String <- run_job(db,canonical,Job{Store.field(row,0n),id,Store.field(row,1n),Store.field(row,2n),Store.field(row,3n)})
        advanced(db,id,Store.field(row,0n),error,next)

def advance(+db: U32,+id: String,+canonical: String,left: Nat) -> IO(Progress):
  match left:
    case 0n: finish(db,id)
    case 1n+rest:
      do IO<Progress>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT j.id,j.directory,j.kind,j.prefix FROM source_walk_jobs j JOIN source_roots r ON r.id=j.root AND r.enabled=1 WHERE j.root=? ORDER BY j.id LIMIT 1",
          [Sql.Cell.Integer{id}],1)
        advance_rows(db,id,canonical,rows,_ => advance(db,id,canonical,rest))

def discover(+db: U32,+id: String,+canonical: String) -> IO(Progress):
  do IO<Progress>:
    start(db,id,canonical)
    advance(db,id,canonical,4n)
