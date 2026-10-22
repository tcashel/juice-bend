import Base
import ./sql.bend as Sql
import ./store.bend as Store
import ./paths.bend as Paths
import ./json.bend as Json
import ./source_walk.bend as Walk

# Only explicitly enabled roots are enumerated. find supplies directory entries;
# filename filtering, queueing, source identity and refresh policy remain Bend.
# One root and at most eight files are processed per call. The persisted queue
# favors new paths, cycles failed candidates, and never follows discovered links.
type Discovery is Data:
  Discovery{status: String, root: String, files: U32, error: String}

type Outcome is Data:
  Outcome{provider: String, path: String, ok: Bool, snapshot: String, error: String}

def schema(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.statements([
    "CREATE TABLE IF NOT EXISTS source_roots(id INTEGER PRIMARY KEY,provider TEXT NOT NULL,canonical_root TEXT NOT NULL,enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),UNIQUE(provider,canonical_root))",
    "CREATE TABLE IF NOT EXISTS source_root_files(root INTEGER NOT NULL REFERENCES source_roots(id),locator TEXT NOT NULL,available INTEGER NOT NULL DEFAULT 1,attempts INTEGER NOT NULL DEFAULT 0,PRIMARY KEY(root,locator)) WITHOUT ROWID"
    ],db)
    Walk.schema(db)

def list(+db: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  do IO<List<&2,List<&2,Sql.Cell>>>:
    schema(db)
    Store.q(db,"SELECT provider,canonical_root,enabled FROM source_roots ORDER BY provider,canonical_root LIMIT 32",[],32)

def provider_valid(+provider: String) -> Bool:
  String.eq(provider,"claude") || String.eq(provider,"codex")

def directory_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>,
  root: String) -> IO(Unit):
  match result:
    case Done{(code,(out,_))}:
      Store.checked(U32.is_eq(code,0) && String.eq(out,root ++ "\0"),
        "Source root must be an existing directory")
    case Fail{_}:
      IO.die(Unit,2,"Cannot verify source root directory")

def add(+db: U32,+provider: String,path: String) -> IO(Unit):
  do IO<Unit>:
    schema(db)
    Store.checked(provider_valid(provider),"Source provider must be claude or codex")
    +canonical : String <- Paths.resolve(path)
    Store.checked(Nat.is_le(String.length(canonical),4096n),"Source root path exceeds 4096 characters")
    directory : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/find",["-P",canonical,"-prune","-type","d","-print0"],"",8192,2000)
    directory_result(directory,canonical)
    count : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM source_roots WHERE NOT(provider=? AND canonical_root=?)",
      [Sql.Cell.Text{provider},Sql.Cell.Text{canonical}],1)
    Store.checked(U32.is_lt(Store.number(Store.field(Store.first(count),0n)),32),
      "At most 32 explicit source roots are supported")
    Store.exec(db,
      "INSERT INTO source_roots(provider,canonical_root,enabled) VALUES(?,?,1) ON CONFLICT(provider,canonical_root) DO UPDATE SET enabled=1",
      [Sql.Cell.Text{provider},Sql.Cell.Text{canonical}])

def deactivate(+db: U32,+provider: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"UPDATE source_roots SET enabled=0 WHERE provider=? AND canonical_root=?",
      [Sql.Cell.Text{provider},Sql.Cell.Text{path}])
    Walk.cancel(db,provider,path)
    Store.exec(db,"COMMIT",[])

def disable_path(db: U32,provider: String,path: String,found: Bool) -> IO(Unit):
  match found:
    case True{}:
      deactivate(db,provider,path)
    case False{}:
      do IO<Unit>:
        canonical : String <- Paths.resolve(path)
        deactivate(db,provider,canonical)

# An exact persisted root can be disabled even after its directory disappears.
def disable(+db: U32,+provider: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    schema(db)
    Store.checked(provider_valid(provider),"Source provider must be claude or codex")
    found : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT id FROM source_roots WHERE provider=? AND canonical_root=?",
      [Sql.Cell.Text{provider},Sql.Cell.Text{path}],1)
    disable_path(db,provider,path,Bool.not(List.is_empty(&2,List<&2,Sql.Cell>,found)))

def setting(+db: U32,key: String,value: String) -> IO(Unit):
  Store.exec(db,"INSERT INTO settings(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
    [Sql.Cell.Text{key},Sql.Cell.Text{value}])

def next_root_wrap(db: U32,rows: List<&2,List<&2,Sql.Cell>>) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  match rows:
    case []:
      Store.q(db,"SELECT id,provider,canonical_root FROM source_roots WHERE enabled=1 ORDER BY id LIMIT 1",[],1)
    case row <> rest:
      IO.pure(List<&2,List<&2,Sql.Cell>>,row <> rest)

def next_root(+db: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  do IO<List<&2,List<&2,Sql.Cell>>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT id,provider,canonical_root FROM source_roots WHERE enabled=1 AND id>coalesce((SELECT CAST(value AS INTEGER) FROM settings WHERE key='source_root_cursor'),0) ORDER BY id LIMIT 1",[],1)
    next_root_wrap(db,rows)

def candidate(root: String,path: String) -> Bool:
  Walk.candidate(root,path)

def discovered(root: String,progress: Walk.Progress) -> Discovery:
  Walk.Progress{status,files,error} = progress
  Discovery{status,root,files,error}

def discover_row(+db: U32,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Discovery):
  match rows:
    case []:
      IO.pure(Discovery,Discovery{"none","",0,""})
    case +row <> _:
      +id = Store.field(row,0n)
      +root = Store.field(row,2n)
      do IO<Discovery>:
        setting(db,"source_root_cursor",id)
        progress : Walk.Progress <- Walk.discover(db,id,root)
        return discovered(root,progress)

def new_files(db: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  Store.q(db,
    "SELECT '',r.provider,f.locator FROM source_root_files f JOIN source_roots r ON r.id=f.root AND r.enabled=1 LEFT JOIN sources s ON s.provider=r.provider AND s.locator=f.locator WHERE f.available=1 AND s.id IS NULL GROUP BY r.provider,f.locator ORDER BY min(f.attempts),r.provider,f.locator LIMIT 4",[],4)

# Registered standalone imports remain eligible. Descendants of a disabled root
# are skipped unless an enabled root still explicitly authorizes that path.
def registered_sql() -> String:
  "SELECT s.id,s.provider,s.locator FROM sources s WHERE (NOT EXISTS(SELECT 1 FROM source_roots r WHERE r.provider=s.provider AND r.enabled=0 AND (r.canonical_root='/' OR substr(s.locator,1,length(r.canonical_root)+1)=r.canonical_root||'/')) OR EXISTS(SELECT 1 FROM source_roots r WHERE r.provider=s.provider AND r.enabled=1 AND (r.canonical_root='/' OR substr(s.locator,1,length(r.canonical_root)+1)=r.canonical_root||'/'))) "

def registered_wrap(db: U32,rows: List<&2,List<&2,Sql.Cell>>) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  match rows:
    case []:
      Store.q(db,registered_sql() ++ "ORDER BY s.id LIMIT 4",[],4)
    case row <> rest:
      IO.pure(List<&2,List<&2,Sql.Cell>>,row <> rest)

def registered(+db: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  do IO<List<&2,List<&2,Sql.Cell>>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,registered_sql() ++
      "AND s.id>coalesce((SELECT CAST(value AS INTEGER) FROM settings WHERE key='source_file_cursor'),0) ORDER BY s.id LIMIT 4",[],4)
    registered_wrap(db,rows)

def import_output(provider: String,path: String,result: Result<&2,&2,String,Json.Json>) -> Outcome:
  match result:
    case Fail{_}:
      Outcome{provider,path,False{},"","Import worker returned invalid JSON"}
    case Done{value}:
      +snapshot = Json.get(value,"accepted_snapshot")
      Outcome{provider,path,Bool.not(String.is_empty(snapshot)),snapshot,
        Bool.pick(String,String.is_empty(snapshot),"Import worker returned no accepted snapshot","")}

# Only fixed archive error markers become actionable messages. Never reflect a
# worker's free-form stderr, which may contain source text or local paths.
def archive_error(+error: String) -> String:
  Bool.pick(String,String.starts_with(error,"archive_limit:"),
    "archive_limit: Archive exceeds a bounded import limit (64 MiB compressed, 256 MiB logical, 8 MiB window, 64 frames, 4096 blocks per frame); retained captures remain available",
    Bool.pick(String,String.starts_with(error,"archive_dictionary:"),
      "archive_dictionary: External Zstandard dictionaries are unsupported; retained captures remain available",
      Bool.pick(String,String.starts_with(error,"archive_corrupt:"),
        "archive_corrupt: Archive framing, checksum or retained-byte integrity failed; retained captures remain available",
        Bool.pick(String,String.starts_with(error,"archive_changed:"),
          "archive_changed: Source changed during capture; refresh again when it is stable; retained captures remain available",""))))

def import_error(+path: String,+code: U32,error: String) -> String:
  Store.nonempty(Bool.pick(String,String.ends_with(path,".jsonl.zst"),archive_error(String.trim(error)),""),
    "Import worker exited " ++ U32.show(code) ++ "; retained captures remain available")

def import_exited(provider: String,+path: String,+code: U32,out: String,error: String) -> Outcome:
  match code:
    case 0:
      import_output(provider,path,Json.parse(out))
    case _:
      Outcome{provider,path,False{},"",import_error(path,code,error)}

def import_result(provider: String,path: String,
  result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Outcome:
  match result:
    case Fail{_}:
      Outcome{provider,path,False{},"","Import exceeded 300 seconds or output limit, or could not start"}
    case Done{(code,(out,error))}:
      import_exited(provider,path,code,out,error)

# Recheck canonical identity before invoking the importer. A discovered symlink
# or symlink directory introduced since enumeration is refused. Upstream lacks
# an atomic open-no-follow primitive, so hostile concurrent replacement remains
# a filesystem race boundary rather than a claimed sandbox.
def import_checked(program: String,data_dir: String,+provider: String,+path: String,valid: Bool) ->
  IO(Outcome):
  match valid:
    case False{}:
      IO.pure(Outcome,Outcome{provider,path,False{},"","Source path changed, disappeared, or became a symlink"})
    case True{}:
      do IO<Outcome>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
          Process.run(program,["--data-dir",data_dir,"import",provider,path],"",16384,300000)
        return import_result(provider,path,result)

def import_canonical(program: String,data_dir: String,provider: String,+path: String,
  result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Outcome):
  match result:
    case Fail{_}:
      IO.pure(Outcome,Outcome{provider,path,False{},"","Source path cannot be canonicalized"})
    case Done{(code,(out,_))}:
      import_checked(program,data_dir,provider,path,U32.is_eq(code,0) && String.eq(out,path ++ "\n"))

def import_one(+program: String,+data_dir: String,+provider: String,+path: String) -> IO(Outcome):
  do IO<Outcome>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/realpath",["--",path],"",8192,2000)
    import_canonical(program,data_dir,provider,path,result)

def attempted(+db: U32,id: String,+provider: String,+path: String) -> IO(Unit):
  match id:
    case "":
      Store.exec(db,
        "UPDATE source_root_files SET attempts=min(attempts+1,2147483647) WHERE locator=? AND root IN(SELECT id FROM source_roots WHERE provider=?)",
        [Sql.Cell.Text{path},Sql.Cell.Text{provider}])
    case _:
      setting(db,"source_file_cursor",id)

def import_rows(+db: U32,+data_dir: String,+program: String,
  rows: List<&2,List<&2,Sql.Cell>>) -> IO(List<&2,Outcome>):
  match rows:
    case []:
      IO.pure(List<&2,Outcome>,[])
    case +row <> rest:
      +provider = Store.field(row,1n)
      +path = Store.field(row,2n)
      do IO<List<&2,Outcome>>:
        attempted(db,Store.field(row,0n),provider,path)
        outcome : Outcome <- import_one(program,data_dir,provider,path)
        outcomes : List<&2,Outcome> <- import_rows(db,data_dir,program,rest)
        return outcome <> outcomes

def outcome_json(outcome: Outcome) -> String:
  Outcome{provider,path,ok,snapshot,error} = outcome
  "{\"provider\":" ++ Json.quote(provider) ++ ",\"path\":" ++ Json.quote(path) ++
    ",\"status\":" ++ Json.quote(Bool.pick(String,ok,"ok","failed")) ++
    ",\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"error\":" ++ Json.quote(error) ++ "}"

def outcomes_json(outcomes: List<&2,Outcome>) -> String:
  match outcomes:
    case []:
      ""
    case outcome <> []:
      outcome_json(outcome)
    case outcome <> rest:
      outcome_json(outcome) ++ "," ++ outcomes_json(rest)

def successes(outcomes: List<&2,Outcome>) -> U32:
  match outcomes:
    case []:
      0
    case Outcome{_,_,ok,_,_} <> rest:
      (Bool.pick(U32,ok,1,0) + successes(rest) : U32)

def report(discovery: Discovery,+outcomes: List<&2,Outcome>) -> String:
  Discovery{status,root,files,error} = discovery
  +count = U32.from_nat(List.length(&2,Outcome,outcomes))
  +ok = successes(outcomes)
  "{\"batch_limit\":8,\"attempted\":" ++ U32.show(count) ++ ",\"succeeded\":" ++
    U32.show(ok) ++ ",\"failed\":" ++ U32.show(U32.sub(count,ok)) ++
    ",\"discovery\":{\"status\":" ++ Json.quote(status) ++ ",\"root\":" ++
    Json.quote(root) ++ ",\"files\":" ++ U32.show(files) ++ ",\"error\":" ++ Json.quote(error) ++
    "},\"results\":[" ++ outcomes_json(outcomes) ++ "]}"

def refresh_all(+db: U32,+data_dir: String,+program: String) -> IO(String):
  do IO<String>:
    Store.checked(Bool.not(String.is_empty(data_dir)) && Bool.not(String.is_empty(program)),
      "Refresh requires explicit data directory and executable")
    schema(db)
    roots : List<&2,List<&2,Sql.Cell>> <- next_root(db)
    discovery : Discovery <- discover_row(db,roots)
    fresh : List<&2,List<&2,Sql.Cell>> <- new_files(db)
    existing : List<&2,List<&2,Sql.Cell>> <- registered(db)
    results : List<&2,Outcome> <- import_rows(db,data_dir,program,
      List.append(&2,List<&2,Sql.Cell>,fresh,existing))
    return report(discovery,results)
