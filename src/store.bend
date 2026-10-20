import Base
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./paths.bend as Paths
import ./query.bend as Query
import ./timestamp.bend as Timestamp
import ./json.bend as Json
import ./projection_seal.bend as Seal

type Context is Data:
  Context{repository: String, session: String, model: String, parent: String}

type Piece is Data:
  Piece{bytes: List<&2, U32>, length: U32, newline: Bool, oversized: Bool}

type Split is Data:
  Split{pieces: List<&2, Piece>, tail: List<&2, U32>, length: U32, oversized: Bool}

# Explicit observation of the real capture transaction. The ordinary entry
# point supplies Unobserved; tests may hold an owned child at a named boundary.
# No environment/DB switch enables this, and no callback runs per record.
type ImportPhase is Data:
  BeforeTransaction{}
  Staged{}
  Reverified{}
  Sealed{}
  Accepted{}
  SearchRemoved{}
  LatestRepointed{}
  BeforeCommit{}
  Committed{}

def phase_name(phase: ImportPhase) -> String:
  match phase:
    case BeforeTransaction{}:
      "before_transaction"
    case Staged{}:
      "staged"
    case Reverified{}:
      "reverified"
    case Sealed{}:
      "sealed"
    case Accepted{}:
      "accepted"
    case SearchRemoved{}:
      "search_removed"
    case LatestRepointed{}:
      "latest_repointed"
    case BeforeCommit{}:
      "before_commit"
    case Committed{}:
      "committed"

type ImportObserver is Type:
  Unobserved{}
  Observed{step: ImportPhase -> IO(ImportObserver)}

# Functions are affine in Bend. Each callback therefore returns the observer
# for the next boundary instead of copying a closure or consulting global state.
def observe_phase(observer: ImportObserver,phase: ImportPhase) -> IO(ImportObserver):
  match observer:
    case Unobserved{}:
      IO.pure(ImportObserver,Unobserved{})
    case Observed{step}:
      step(phase)

type ImportState is Type:
  ImportState{db: U32, file: File, provider: String, source: String,
    generation: String, snapshot: String, extent: U32, offset: U32, ordinal: U32,
    checkpoint: U32, checkpoint_ordinal: U32, context: Context,
    observe: ImportObserver, seal: Seal.Validation}

def text(cell: Sql.Cell) -> String:
  match cell:
    case Sql.Cell.Text{s}:
      s
    case Sql.Cell.Integer{s}:
      s
    case Sql.Cell.Real{s}:
      s
    case _:
      ""

def cell(row: List<&2, Sql.Cell>, n: Nat) -> Sql.Cell:
  match row n:
    case [] _:
      Sql.Cell.Null{}
    case h <> t 0n:
      h
    case h <> t 1n+p:
      cell(t, p)

def field(row: List<&2, Sql.Cell>, n: Nat) -> String:
  text(cell(row, n))

def first(rows: List<&2, List<&2, Sql.Cell>>) -> List<&2, Sql.Cell>:
  match rows:
    case []:
      []
    case h <> t:
      h

def number.read(n: Maybe<&2, U32>) -> U32:
  match n:
    case Some{x}:
      x
    case None{}:
      0

def number(s: String) -> U32:
  number.read(Domain.parse_u32(s))

def numeric(+s: String) -> Bool:
  String.eq(U32.show(number(s)),s)

def q(db: U32, sql: String, args: List<&2, Sql.Cell>, limit: U32) ->
  IO(List<&2, List<&2, Sql.Cell>>):
  IO.try(List<&2, List<&2, Sql.Cell>>, Sql.query(db, sql, args, limit))

def exec(db: U32, sql: String, args: List<&2, Sql.Cell>) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2, List<&2, Sql.Cell>> <- q(db, sql, args, 1)
    return Unit{}

def statements(sqls: List<&2, String>, +db: U32) -> IO(Unit):
  match sqls:
    case []:
      IO.pure(Unit, Unit{})
    case sql <> rest:
      do IO<Unit>:
        exec(db, sql, [])
        statements(rest, db)

def schema_base(+db: U32) -> IO(Unit):
  statements([
    "PRAGMA foreign_keys=ON",
    "PRAGMA journal_mode=WAL",
    "PRAGMA synchronous=FULL",
    "CREATE TABLE IF NOT EXISTS sources(id INTEGER PRIMARY KEY,provider TEXT NOT NULL,locator TEXT NOT NULL,latest INTEGER,UNIQUE(provider,locator))",
    "CREATE TABLE IF NOT EXISTS generations(id INTEGER PRIMARY KEY,source INTEGER NOT NULL REFERENCES sources(id))",
    "CREATE TABLE IF NOT EXISTS snapshots(id INTEGER PRIMARY KEY,generation INTEGER NOT NULL REFERENCES generations(id),extent INTEGER NOT NULL,checkpoint INTEGER NOT NULL DEFAULT 0,checkpoint_ordinal INTEGER NOT NULL DEFAULT 0,records INTEGER NOT NULL DEFAULT 0,accepted INTEGER NOT NULL DEFAULT 0)",
    "CREATE TABLE IF NOT EXISTS raw(id INTEGER PRIMARY KEY,generation INTEGER NOT NULL REFERENCES generations(id),ordinal INTEGER NOT NULL,offset INTEGER NOT NULL,n INTEGER NOT NULL,digest TEXT NOT NULL,bytes BLOB NOT NULL,complete INTEGER NOT NULL,oversized INTEGER NOT NULL,CHECK(n=length(bytes)))",
    "CREATE TABLE IF NOT EXISTS records(snapshot INTEGER NOT NULL REFERENCES snapshots(id),ordinal INTEGER NOT NULL,raw INTEGER NOT NULL REFERENCES raw(id),PRIMARY KEY(snapshot,ordinal)) WITHOUT ROWID",
    "CREATE TABLE IF NOT EXISTS events(snapshot INTEGER NOT NULL REFERENCES snapshots(id),ordinal INTEGER NOT NULL,event INTEGER NOT NULL,role TEXT NOT NULL,body TEXT NOT NULL,tool TEXT NOT NULL,call_id TEXT NOT NULL,arguments TEXT NOT NULL,result TEXT NOT NULL,repository TEXT NOT NULL,session TEXT NOT NULL,timestamp TEXT NOT NULL,model TEXT NOT NULL,usage TEXT NOT NULL,parent TEXT NOT NULL,coverage TEXT NOT NULL,PRIMARY KEY(snapshot,ordinal,event))",
    "CREATE INDEX IF NOT EXISTS event_scope ON events(repository,role,timestamp,snapshot,ordinal)",
    "CREATE INDEX IF NOT EXISTS source_latest ON sources(latest)",
    "CREATE VIRTUAL TABLE IF NOT EXISTS search USING fts5(body,arguments,result,tool,snapshot UNINDEXED,ordinal UNINDEXED,event UNINDEXED,tokenize='unicode61')",
    "CREATE TABLE IF NOT EXISTS projection_checks(snapshot INTEGER PRIMARY KEY REFERENCES snapshots(id),version TEXT NOT NULL,digest TEXT NOT NULL)",
    "CREATE TABLE IF NOT EXISTS snapshot_context(snapshot INTEGER NOT NULL REFERENCES snapshots(id),ordinal INTEGER NOT NULL,repository TEXT NOT NULL,session TEXT NOT NULL,model TEXT NOT NULL,parent TEXT NOT NULL,version TEXT NOT NULL,digest TEXT NOT NULL,PRIMARY KEY(snapshot,ordinal)) WITHOUT ROWID",
    "CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)"
  ], db)

# FTS is a latest-only projection. Raw generations, record maps and historical
# events stay intact; their immutable evidence keys do not use events.rowid.
# FTS rowid mirrors the current event rowid to avoid unindexed virtual-column
# conversions and a composite-index lookup for every candidate.
def batch_last(rows: List<&2,List<&2,Sql.Cell>>,last: List<&2,Sql.Cell>) -> List<&2,Sql.Cell>:
  match rows:
    case []:
      last
    case row <> rest:
      batch_last(rest,row)

# SQL writes share the caller's transaction, but each statement has bounded
# work. The bridge retains its two-second progress deadline. Only keys cross
# the bridge; payloads stay in SQLite and keep their exact cell types.
def event_batch(db: U32,snapshot: String,ordinal: String,event: String,stop: String) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  q(db,
    "SELECT ordinal,event FROM (SELECT e.*,row_number() OVER (ORDER BY ordinal,event) AS rn,sum(payload_bytes) OVER (ORDER BY ordinal,event) AS total_bytes FROM (SELECT ordinal,event,length(CAST(role AS BLOB))+length(CAST(body AS BLOB))+length(CAST(tool AS BLOB))+length(CAST(call_id AS BLOB))+length(CAST(arguments AS BLOB))+length(CAST(result AS BLOB))+length(CAST(repository AS BLOB))+length(CAST(session AS BLOB))+length(CAST(timestamp AS BLOB))+length(CAST(model AS BLOB))+length(CAST(usage AS BLOB))+length(CAST(parent AS BLOB))+length(CAST(coverage AS BLOB))+256 AS payload_bytes FROM events WHERE snapshot=? AND (ordinal,event)>(?,?) AND ordinal<? ORDER BY ordinal,event LIMIT 64) e) WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal,event",
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{event},Sql.Cell.Integer{stop}],64)

def index_search_batch(db: U32,snapshot: String,ordinal: String,event: String,
  rows: List<&2,List<&2,Sql.Cell>>,next: String -> String -> IO(Unit)) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case row <> more:
      +last = batch_last(row <> more,[])
      do IO<Unit>:
        exec(db,
          "INSERT INTO search(rowid,body,arguments,result,tool,snapshot,ordinal,event) SELECT e.rowid,e.body,e.arguments,e.result,e.tool,e.snapshot,e.ordinal,e.event FROM events e JOIN snapshots p ON p.id=e.snapshot AND p.accepted=1 JOIN sources s ON s.latest=p.id WHERE e.snapshot=? AND (e.ordinal,e.event)>(?,?) AND (e.ordinal,e.event)<=(?,?) ORDER BY e.ordinal,e.event",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{event},
           Sql.Cell.Integer{field(last,0n)},Sql.Cell.Integer{field(last,1n)}])
        next(field(last,0n),field(last,1n))

def index_search_walk(fuel: Nat,+db: U32,+snapshot: String,+ordinal: String,+event: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Search publication batch budget exhausted")
    case 1n+rest:
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- event_batch(db,snapshot,ordinal,event,"4294967295")
        index_search_batch(db,snapshot,ordinal,event,rows,
          ord => evt => index_search_walk(rest,db,snapshot,ord,evt))

def index_search_current(db: U32,snapshot: String,current: Bool) -> IO(Unit):
  match current:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      index_search_walk(4294967295n,db,snapshot,"-1","-1")

def index_search_snapshot(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT p.id FROM snapshots p JOIN sources s ON s.latest=p.id WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    index_search_current(db,snapshot,Bool.not(List.is_empty(&2,List<&2,Sql.Cell>,rows)))

def search_key_batch(db: U32,cursor: Maybe<&2,String>) -> IO(List<&2,List<&2,Sql.Cell>>):
  match cursor:
    case None{}:
      q(db,"SELECT key FROM (SELECT e.*,row_number() OVER (ORDER BY key) AS rn,sum(payload_bytes) OVER (ORDER BY key) AS total_bytes FROM (SELECT rowid AS key,coalesce(length(CAST(body AS BLOB)),0)+coalesce(length(CAST(arguments AS BLOB)),0)+coalesce(length(CAST(result AS BLOB)),0)+coalesce(length(CAST(tool AS BLOB)),0)+128 AS payload_bytes FROM search ORDER BY rowid LIMIT 128) e) WHERE total_bytes<=1048576 OR rn=1 ORDER BY key",[],128)
    case Some{key}:
      q(db,"SELECT key FROM (SELECT e.*,row_number() OVER (ORDER BY key) AS rn,sum(payload_bytes) OVER (ORDER BY key) AS total_bytes FROM (SELECT rowid AS key,coalesce(length(CAST(body AS BLOB)),0)+coalesce(length(CAST(arguments AS BLOB)),0)+coalesce(length(CAST(result AS BLOB)),0)+coalesce(length(CAST(tool AS BLOB)),0)+128 AS payload_bytes FROM search WHERE rowid>? ORDER BY rowid LIMIT 128) e) WHERE total_bytes<=1048576 OR rn=1 ORDER BY key",[Sql.Cell.Integer{key}],128)

def delete_search_range(db: U32,snapshot: Maybe<&2,String>,start: String,stop: String) -> IO(Unit):
  match snapshot:
    case None{}:
      exec(db,"DELETE FROM search WHERE rowid>=? AND rowid<=?",
        [Sql.Cell.Integer{start},Sql.Cell.Integer{stop}])
    case Some{snap}:
      exec(db,"DELETE FROM search WHERE rowid>=? AND rowid<=? AND snapshot=?",
        [Sql.Cell.Integer{start},Sql.Cell.Integer{stop},Sql.Cell.Integer{snap}])

# Scan the FTS rowid key once, including orphaned entries. Looking up deletions
# through events would leave stale FTS rows after projection corruption.
def clear_search_batch(db: U32,snapshot: Maybe<&2,String>,rows: List<&2,List<&2,Sql.Cell>>,
  next: String -> IO(Unit)) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case +row <> more:
      +last = batch_last(row <> more,[])
      do IO<Unit>:
        delete_search_range(db,snapshot,field(row,0n),field(last,0n))
        next(field(last,0n))

def clear_search_walk(fuel: Nat,+db: U32,+snapshot: Maybe<&2,String>,cursor: Maybe<&2,String>) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Search removal batch budget exhausted")
    case 1n+rest:
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- search_key_batch(db,cursor)
        clear_search_batch(db,snapshot,rows,
          key => clear_search_walk(rest,db,snapshot,Some{key}))

def clear_search_snapshot(db: U32,snapshot: String) -> IO(Unit):
  clear_search_walk(4294967295n,db,Some{snapshot},None{})

def clear_source_cell(db: U32,latest: Sql.Cell) -> IO(Unit):
  match latest:
    case Sql.Cell.Null{}:
      IO.pure(Unit,Unit{})
    case Sql.Cell.Integer{snapshot}:
      clear_search_snapshot(db,snapshot)
    case _:
      IO.die(Unit,1,"Source latest snapshot identity is corrupt")

def clear_source_search(+db: U32,source: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,"SELECT latest FROM sources WHERE id=?",
      [Sql.Cell.Integer{source}],1)
    clear_source_cell(db,cell(first(rows),0n))

# Caller owns the transaction. Used after verified projection replay, including
# an old snapshot: only a still-current accepted snapshot is made searchable.
def refresh_search(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    clear_search_snapshot(db,snapshot)
    index_search_snapshot(db,snapshot)

def index_source_rows(rows: List<&2,List<&2,Sql.Cell>>,+db: U32) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case row <> rest:
      do IO<Unit>:
        index_search_snapshot(db,field(row,0n))
        index_source_rows(rest,db)

def index_sources_batch(db: U32,rows: List<&2,List<&2,Sql.Cell>>,next: String -> IO(Unit)) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case row <> more:
      +batch : List<&2,List<&2,Sql.Cell>> = row <> more
      last = batch_last(batch,[])
      do IO<Unit>:
        index_source_rows(batch,db)
        next(field(last,0n))

def index_sources_walk(fuel: Nat,+db: U32,cursor: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Search migration batch budget exhausted")
    case 1n+rest:
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- q(db,
          "SELECT id FROM snapshots WHERE id>? AND accepted=1 AND EXISTS(SELECT 1 FROM sources WHERE latest=snapshots.id) ORDER BY id LIMIT 64",
          [Sql.Cell.Integer{cursor}],64)
        index_sources_batch(db,rows,key => index_sources_walk(rest,db,key))

def migrate_search(+db: U32) -> IO(Unit):
  do IO<Unit>:
    exec(db,"BEGIN IMMEDIATE",[])
    exec(db,"DROP TRIGGER IF EXISTS event_search",[])
    clear_search_walk(4294967295n,db,None{},None{})
    index_sources_walk(4294967295n,db,"0")
    exec(db,"PRAGMA user_version=2",[])
    exec(db,"COMMIT",[])

def schema_version(db: U32,version: String) -> IO(Unit):
  match version:
    case "0":
      migrate_search(db)
    case "1":
      migrate_search(db)
    case "2":
      IO.pure(Unit,Unit{})
    case _:
      IO.die(Unit,1,"Unsupported Juice Bend library schema version")

def schema(+db: U32) -> IO(Unit):
  do IO<Unit>:
    schema_base(db)
    version : List<&2,List<&2,Sql.Cell>> <- q(db,"PRAGMA user_version",[],1)
    schema_version(db,field(first(version),0n))

def open(+path: String) -> IO(U32):
  do IO<U32>:
    +db : U32 <- IO.try(U32, Sql.open(path))
    schema(db)
    return db

def last_id(db: U32) -> IO(String):
  do IO<String>:
    rows : List<&2, List<&2, Sql.Cell>> <- q(db, "SELECT last_insert_rowid()", [], 1)
    return field(first(rows), 0n)

def source(+db: U32, +provider: String, +path: String) -> IO(String):
  do IO<String>:
    exec(db, "INSERT OR IGNORE INTO sources(provider,locator) VALUES(?,?)",
      [Sql.Cell.Text{provider}, Sql.Cell.Text{path}])
    rows : List<&2, List<&2, Sql.Cell>> <- q(db,
      "SELECT id FROM sources WHERE provider=? AND locator=?",
      [Sql.Cell.Text{provider}, Sql.Cell.Text{path}], 1)
    return field(first(rows), 0n)

def status(db: U32) -> IO(List<&2, List<&2, Sql.Cell>>):
  q(db, "SELECT (SELECT count(*) FROM sources),(SELECT count(*) FROM generations),(SELECT count(*) FROM snapshots WHERE accepted=1),(SELECT coalesce(sum(n),0) FROM raw),(SELECT count(*) FROM events)", [], 1)

def history(db: U32, +provider: String, +repo: String, limit: U32, offset: U32) ->
  IO(List<&2, List<&2, Sql.Cell>>):
  q(db, "SELECT s.id,s.provider,s.locator,p.id,p.generation,p.extent,p.records," ++
    "coalesce((SELECT substr(e.body,1,90) FROM events e WHERE e.snapshot=p.id AND e.role NOT IN ('metadata','unsupported') AND e.body<>'' AND (?='' OR e.repository=?) ORDER BY e.ordinal,e.event LIMIT 1),'Captured source')," ++
    "coalesce((SELECT e.repository FROM events e WHERE e.snapshot=p.id AND e.repository<>'' AND (?='' OR e.repository=?) ORDER BY e.ordinal,e.event LIMIT 1),'')," ++
    "coalesce((SELECT e.ordinal FROM events e WHERE e.snapshot=p.id AND e.role NOT IN ('metadata','unsupported') AND e.body<>'' AND (?='' OR e.repository=?) ORDER BY e.ordinal,e.event LIMIT 1)," ++
    "(SELECT e.ordinal FROM events e WHERE e.snapshot=p.id AND (?='' OR e.repository=?) ORDER BY e.ordinal,e.event LIMIT 1),0) " ++
    "FROM sources s JOIN snapshots p ON p.id=s.latest AND p.accepted=1 WHERE (?='' OR s.provider=?) AND (?='' OR EXISTS(SELECT 1 FROM events e WHERE e.snapshot=p.id AND e.repository=?)) ORDER BY p.id DESC LIMIT ? OFFSET ?",
    [Sql.Cell.Text{repo},Sql.Cell.Text{repo},Sql.Cell.Text{repo},Sql.Cell.Text{repo},
     Sql.Cell.Text{repo},Sql.Cell.Text{repo},Sql.Cell.Text{repo},Sql.Cell.Text{repo},
     Sql.Cell.Text{provider},Sql.Cell.Text{provider},Sql.Cell.Text{repo},Sql.Cell.Text{repo},
     Sql.Cell.Integer{U32.show(U32.min(limit,100))},Sql.Cell.Integer{U32.show(offset)}],100)

def literal.quote(s: String) -> String:
  match s:
    case SNil{}:
      ""
    case SCon{'"', t}:
      "\"\"" ++ literal.quote(t)
    case SCon{h, t}:
      SCon{h, literal.quote(t)}

def literal(s: String) -> String:
  "\"" ++ literal.quote(s) ++ "\""

def search.terms(db: U32, terms: String, +provider: String, +repo: String,
  +role: String, +after: String, limit: U32, offset: U32) ->
  IO(List<&2, List<&2, Sql.Cell>>):
  match terms:
    case "":
      q(db, "SELECT e.snapshot,e.ordinal,e.event,s.provider,e.role,substr(CASE WHEN e.body<>'' THEN e.body WHEN e.arguments<>'' THEN e.arguments ELSE e.result END,1,220),e.repository,e.session,e.timestamp,p.generation FROM sources s JOIN snapshots p ON p.id=s.latest AND p.accepted=1 JOIN generations g ON g.id=p.generation AND g.source=s.id JOIN events e ON e.snapshot=p.id WHERE (?='' OR s.provider=?) AND (?='' OR e.repository=?) AND (?='' OR e.role=?) AND (?='' OR (length(e.timestamp)=30 AND substr(e.timestamp,11,1)='T' AND substr(e.timestamp,30,1)='Z' AND e.timestamp>=?)) ORDER BY e.snapshot DESC,e.ordinal,e.event LIMIT ? OFFSET ?",
        [Sql.Cell.Text{provider},Sql.Cell.Text{provider},Sql.Cell.Text{repo},Sql.Cell.Text{repo},
         Sql.Cell.Text{role},Sql.Cell.Text{role},Sql.Cell.Text{after},Sql.Cell.Text{after},
         Sql.Cell.Integer{U32.show(U32.min(limit,100))},Sql.Cell.Integer{U32.show(offset)}],100)
    case _:
      q(db, "SELECT e.snapshot,e.ordinal,e.event,s.provider,e.role,substr(snippet(search,-1,'','',' … ',32),1,220),e.repository,e.session,e.timestamp,p.generation FROM search JOIN events e ON e.rowid=search.rowid AND e.snapshot=search.snapshot AND e.ordinal=search.ordinal AND e.event=search.event JOIN snapshots p ON p.id=e.snapshot AND p.accepted=1 JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source AND s.latest=p.id WHERE search MATCH ? AND (?='' OR s.provider=?) AND (?='' OR e.repository=?) AND (?='' OR e.role=?) AND (?='' OR (length(e.timestamp)=30 AND substr(e.timestamp,11,1)='T' AND substr(e.timestamp,30,1)='Z' AND e.timestamp>=?)) ORDER BY bm25(search),e.snapshot DESC,e.ordinal,e.event LIMIT ? OFFSET ?",
        [Sql.Cell.Text{terms},Sql.Cell.Text{provider},Sql.Cell.Text{provider},
         Sql.Cell.Text{repo},Sql.Cell.Text{repo},Sql.Cell.Text{role},Sql.Cell.Text{role},Sql.Cell.Text{after},
         Sql.Cell.Text{after},Sql.Cell.Integer{U32.show(U32.min(limit,100))},
         Sql.Cell.Integer{U32.show(offset)}],100)

def search(db: U32, query: String, provider: String, repo: String,
  role: String, after: String, limit: U32, offset: U32) ->
  IO(List<&2, List<&2, Sql.Cell>>):
  search.terms(db, Query.fts(query), provider, repo, role, after, limit, offset)

def split.finish(done: List<&2, Piece>, tail: List<&2,U32>, len: U32,
  oversized: Bool) -> Split:
  Split{List.reverse(&2,Piece,done),tail,len,oversized}

def split.step(tail: List<&2,U32>, len: U32,
  oversized: Bool, done: List<&2,Piece>, full: Bool,
  next: List<&2,U32> -> U32 -> Bool -> List<&2,Piece> -> Split) -> Split:
  match full:
    case False{}:
      next(tail,len,oversized,done)
    case True{}:
      next([],0,True{},
        Piece{List.reverse(&2,U32,tail),len,False{},True{}} <> done)

def split(bytes: List<&2,U32>,tail: List<&2,U32>,len: U32,
  oversized: Bool,done: List<&2,Piece>) -> Split:
  match bytes:
    case []:
      split.finish(done,tail,len,oversized)
    case 10 <> rest:
      split(rest,[],0,False{},
        Piece{List.reverse(&2,U32,10 <> tail),(len + 1 : U32),True{},oversized} <> done)
    case b <> rest:
      +n = len
      split.step(b <> tail,(n + 1 : U32),oversized,done,
        (n >= 262143 : U32),xs => size => over => pieces => split(rest,xs,size,over,pieces))

def nonempty(+s: String, fallback: String) -> String:
  Bool.pick(String,String.is_empty(s),fallback,s)

# The same pure contextualization drives capture and verified transcript replay.
# A Codex turn_context is a replacement: an absent model explicitly clears it.
def contextualize(provider: String,context: Context,event: Providers.Record) -> Context & Providers.Record:
  Context{repo,session,model,parent} = context
  Providers.ProviderEvent{role,body,tool,call_id,args,result,r,s,+stamp,+m,usage,p,+coverage} = event
  +nr = nonempty(r,repo)
  +ns = nonempty(s,session)
  +nm = Bool.pick(String,String.eq(provider,"codex") && Bool.not(String.eq(coverage,"metadata_context")),nonempty(m,model),m)
  +np = nonempty(p,parent)
  +time = Timestamp.value(Timestamp.parse(stamp))
  status = Bool.pick(String,Bool.not(String.is_empty(stamp)) && String.is_empty(time),coverage ++ "; invalid_timestamp",coverage)
  (Context{nr,ns,nm,np},Providers.ProviderEvent{role,body,tool,call_id,args,result,nr,ns,time,nm,usage,np,status})

def put_contextualized(+db: U32,snapshot: String,ordinal: U32,index: U32,
  projected: Context & Providers.Record) -> IO(Context):
  (context,Providers.ProviderEvent{role,body,tool,call_id,args,result,repo,session,stamp,model,usage,parent,coverage}) = projected
  do IO<Context>:
    exec(db, "INSERT INTO events VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},
       Sql.Cell.Integer{U32.show(index)},Sql.Cell.Text{role},Sql.Cell.Text{body},
       Sql.Cell.Text{tool},Sql.Cell.Text{call_id},Sql.Cell.Text{args},
       Sql.Cell.Text{result},Sql.Cell.Text{repo},Sql.Cell.Text{session},
       Sql.Cell.Text{stamp},Sql.Cell.Text{model},Sql.Cell.Text{usage},
       Sql.Cell.Text{parent},Sql.Cell.Text{coverage}])
    return context

def put_event(db: U32,snapshot: String,ordinal: U32,index: U32,
  provider: String,context: Context,event: Providers.Record) -> IO(Context):
  put_contextualized(db,snapshot,ordinal,index,contextualize(provider,context,event))

def put_events(events: List<&2,Providers.Record>, +db: U32, +snapshot: String,
  +ordinal: U32, +index: U32, +provider: String, context: Context) -> IO(Context):
  match events:
    case []:
      IO.pure(Context,context)
    case event <> rest:
      do IO<Context>:
        ctx : Context <- put_event(db,snapshot,ordinal,index,provider,context,event)
        put_events(rest,db,snapshot,ordinal,(index + 1 : U32),provider,ctx)

def decoded(result: Result<&2,&2,String,String>, provider: String) ->
  List<&2,Providers.Record>:
  match result:
    case Fail{error}:
      [Providers.ProviderEvent{"unsupported","","","","","","","","","","","","invalid_utf8: " ++ error}]
    case Done{raw}:
      Providers.parse(provider,raw)

def piece_events(oversized: Bool, provider: String, raw: List<&2,U32>) ->
  List<&2,Providers.Record>:
  match oversized:
    case True{}:
      [Providers.ProviderEvent{"unsupported","","","","","","","","","","","","oversized_record_fragment"}]
    case False{}:
      decoded(Domain.decode(raw),provider)

def raw_digest(generation: String, ordinal: U32, offset: U32, len: U32,
  raw: List<&2,U32>) -> String:
  Domain.digest(List.append(&2,U32,Domain.encode(generation ++ "|" ++
    U32.show(ordinal) ++ "|" ++ U32.show(offset) ++ "|" ++ U32.show(len) ++ "|"),raw))

def blob(cell: Sql.Cell) -> List<&2,U32>:
  match cell:
    case Sql.Cell.Blob{raw}:
      raw
    case _:
      []

def checked(ok: Bool, message: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      IO.die(Unit,1,message)

def read_result(-A: Type, got: File & Result<&1,&1,U32 & String,List<&2,U32>>,
  k: File -> List<&2,U32> -> IO(A)) -> IO(A):
  (f,result) = got
  do IO<A>:
    bytes : List<&2,U32> <- IO.try(List<&2,U32>,
      IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))
    k(f,bytes)

def read(-A: Type,file: File,offset: U32,len: U32,
  k: File -> List<&2,U32> -> IO(A)) -> IO(A):
  IO.bind(File & Result<&1,&1,U32 & String,List<&2,U32>>,A,
    File.read_at(file,offset,len),got => read_result(A,got,k))

def is_blob(cell: Sql.Cell) -> Bool:
  match cell:
    case Sql.Cell.Blob{_}:
      True{}
    case _:
      False{}

def last_byte(bytes: List<&2,U32>,last: U32) -> U32:
  match bytes:
    case []:
      last
    case byte <> rest:
      last_byte(rest,byte)

def row_newline(row: List<&2,Sql.Cell>) -> Bool:
  U32.is_eq(last_byte(blob(cell(row,5n)),0),10)

# The first six columns are the immutable raw identity and bytes. SQLite's
# dynamic typing and CHECK constraints are not substitutes for this boundary.
def row_valid(+row: List<&2,Sql.Cell>) -> Bool:
  +length = number(field(row,3n))
  is_blob(cell(row,5n)) &&
    numeric(field(row,1n)) && numeric(field(row,2n)) && numeric(field(row,3n)) &&
    U32.is_gt(length,0) && U32.is_le(length,262144) &&
    Nat.is_eq(List.length(&2,U32,blob(cell(row,5n))),U32.to_nat(length)) &&
    String.eq(field(row,4n),raw_digest(field(row,0n),number(field(row,1n)),
      number(field(row,2n)),length,blob(cell(row,5n))))

# Shared record shape: generation, ordinal, offset, n, digest, bytes,
# oversized, complete, map ordinal. Payload validation deliberately does not
# trust oversized: a selected record derives continuation from its predecessor.
def record_payload_valid(+row: List<&2,Sql.Cell>,generation: String,+extent: U32,
  +records: U32,+ordinal: U32) -> Bool:
  +offset = number(field(row,2n))
  +length = number(field(row,3n))
  +newline = row_newline(row)
  +last = U32.is_eq(U32.add(ordinal,1),records)
  row_valid(row) &&
    String.eq(field(row,0n),generation) &&
    String.eq(field(row,1n),U32.show(ordinal)) &&
    String.eq(field(row,8n),U32.show(ordinal)) &&
    U32.is_lt(ordinal,records) &&
    (U32.is_ne(ordinal,0) || U32.is_eq(offset,0)) &&
    U32.is_le(offset,extent) &&
    U32.is_le(length,U32.sub(extent,offset)) &&
    (Bool.not(last) || U32.is_eq(U32.add(offset,length),extent)) &&
    (last || U32.is_lt(U32.add(offset,length),extent)) &&
    (last || newline || U32.is_eq(length,262144)) &&
    String.eq(field(row,7n),U32.show(Bool.to_u32(newline)))

def record_valid(+row: List<&2,Sql.Cell>,generation: String,extent: U32,
  records: U32,ordinal: U32,offset: U32,continued: Bool) -> Bool:
  +oversized = continued ||
    (U32.is_eq(number(field(row,3n)),262144) && Bool.not(row_newline(row)))
  record_payload_valid(row,generation,extent,records,ordinal) &&
    String.eq(field(row,2n),U32.show(offset)) &&
    String.eq(field(row,6n),U32.show(Bool.to_u32(oversized)))

def check_records(rows: List<&2,List<&2,Sql.Cell>>,+generation: String,+extent: U32,
  +records: U32,+ordinal: U32,+offset: U32,continued: Bool) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case +row <> rest:
      do IO<Unit>:
        checked(record_valid(row,generation,extent,records,ordinal,offset,continued),
          "Captured raw integrity, generation binding, position or coverage metadata mismatch")
        check_records(rest,generation,extent,records,U32.add(ordinal,1),
          U32.add(offset,number(field(row,3n))),Bool.not(row_newline(row)))

def selected_checked(rows: List<&2,List<&2,Sql.Cell>>,+generation: String,+extent: U32,
  +records: U32,start: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  match rows start:
    case +selected 0:
      do IO<List<&2,List<&2,Sql.Cell>>>:
        check_records(selected,generation,extent,records,0,0,False{})
        return selected
    case Nil{} _:
      IO.die(List<&2,List<&2,Sql.Cell>>,1,"Captured predecessor integrity check failed")
    case Con{+previous,+selected} +ordinal:
      do IO<List<&2,List<&2,Sql.Cell>>>:
        checked(record_payload_valid(previous,generation,extent,records,U32.sub(ordinal,1)),
          "Captured predecessor integrity, generation binding or position mismatch")
        check_records(selected,generation,extent,records,ordinal,
          U32.add(number(field(previous,2n)),number(field(previous,3n))),
          Bool.not(row_newline(previous)))
        return selected

def selected_nonempty(+db: U32,snapshot: String,generation: String,extent: U32,
  records: U32,+start: U32,+count: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  +before = Bool.to_u32(U32.is_gt(start,0))
  do IO<List<&2,List<&2,Sql.Cell>>>:
    +rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT r.generation,r.ordinal,r.offset,r.n,r.digest,r.bytes,r.oversized,r.complete,i.ordinal FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal>=? AND i.ordinal<? ORDER BY i.ordinal",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(U32.sub(start,before))},
       Sql.Cell.Integer{U32.show(U32.add(start,count))}],101)
    checked(U32.is_eq(U32.from_nat(List.length(&2,List<&2,Sql.Cell>,rows)),U32.add(count,before)),
      "Record location index integrity is incomplete or corrupt")
    selected_checked(rows,generation,extent,records,start)

# A page reads at most 100 selected records and one predecessor. Verification
# does not require scanning earlier pages or trusting mutable coverage flags.
def selected_records(db: U32,snapshot: String,generation: String,extent: U32,
  records: U32,start: U32,count: U32) -> IO(List<&2,List<&2,Sql.Cell>>):
  match count:
    case 0:
      IO.pure(List<&2,List<&2,Sql.Cell>>,[])
    case _:
      selected_nonempty(db,snapshot,generation,extent,records,start,count)

def selected_record(db: U32,snapshot: String,generation: String,extent: U32,
  +records: U32,+ordinal: U32) -> IO(List<&2,Sql.Cell>):
  do IO<List<&2,Sql.Cell>>:
    checked(U32.is_lt(ordinal,records),"Captured record integrity range mismatch")
    rows : List<&2,List<&2,Sql.Cell>> <-
      selected_records(db,snapshot,generation,extent,records,ordinal,1)
    return first(rows)

# Incoming parser state is a bounded derivative, sealed when real raw parsing
# produces it. The seal binds the snapshot, complete raw identity and parser
# version. Like raw digests, this detects corruption relative to trusted
# metadata; an actor rewriting both data and checksums is outside the boundary.
def projection_version() -> String:
  "providers-v4-utc-context-relay"

def projection_cell(value: Sql.Cell) -> String:
  match value:
    case Sql.Cell.Null{}:
      "null"
    case Sql.Cell.Integer{number}:
      "integer:" ++ Json.quote(number)
    case Sql.Cell.Text{string}:
      "text:" ++ Json.quote(string)
    case Sql.Cell.Real{number}:
      "real:" ++ Json.quote(number)
    case Sql.Cell.Blob{bytes}:
      "blob:" ++ Domain.digest(bytes)

def projection_cells(cells: List<&2,Sql.Cell>) -> String:
  match cells:
    case []:
      ""
    case head <> tail:
      projection_cell(head) ++ ":" ++ projection_cells(tail)

def context_version() -> String:
  projection_version() ++ "|incoming-context-v1"

def context_digest(snapshot: String,generation: String,extent: U32,ordinal: U32,
  offset: U32,length: U32,digest: String,context: Context) -> String:
  Context{repository,session,model,parent} = context
  Domain.digest(Domain.encode(context_version() ++ "|" ++
    projection_cells([Sql.Cell.Text{snapshot},Sql.Cell.Text{generation},
      Sql.Cell.Integer{U32.show(extent)},Sql.Cell.Integer{U32.show(ordinal)},
      Sql.Cell.Integer{U32.show(offset)},Sql.Cell.Integer{U32.show(length)},
      Sql.Cell.Text{digest},Sql.Cell.Text{repository},Sql.Cell.Text{session},
      Sql.Cell.Text{model},Sql.Cell.Text{parent}])))

def context_cells(+snapshot: String,generation: String,extent: U32,
  +ordinal: U32,offset: U32,length: U32,digest: String,+context: Context) -> List<&2,Sql.Cell>:
  Context{repository,session,model,parent} = context
  [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},
     Sql.Cell.Text{repository},Sql.Cell.Text{session},Sql.Cell.Text{model},
     Sql.Cell.Text{parent},Sql.Cell.Text{context_version()},
     Sql.Cell.Text{context_digest(snapshot,generation,extent,ordinal,offset,length,digest,context)}]

def put_context(db: U32,snapshot: String,generation: String,extent: U32,
  ordinal: U32,offset: U32,length: U32,digest: String,context: Context) -> IO(Unit):
  exec(db,"INSERT OR REPLACE INTO snapshot_context(snapshot,ordinal,repository,session,model,parent,version,digest) VALUES(?,?,?,?,?,?,?,?)",
    context_cells(snapshot,generation,extent,ordinal,offset,length,digest,context))

# Caller supplies the standard, already verified raw row used for replay.
def put_record_context(db: U32,snapshot: String,extent: U32,+row: List<&2,Sql.Cell>,
  context: Context) -> IO(Unit):
  put_context(db,snapshot,field(row,0n),extent,number(field(row,1n)),
    number(field(row,2n)),number(field(row,3n)),field(row,4n),context)

def checkpoint_context(+row: List<&2,Sql.Cell>) -> Context:
  Context{field(row,0n),field(row,1n),field(row,2n),field(row,3n)}

def is_text(value: Sql.Cell) -> Bool:
  match value:
    case Sql.Cell.Text{_}:
      True{}
    case _:
      False{}

def context_checked(snapshot: String,extent: U32,+raw: List<&2,Sql.Cell>,
  +row: List<&2,Sql.Cell>,current: Bool) -> IO(Maybe<&2,Context>):
  match current:
    case False{}:
      IO.pure(Maybe<&2,Context>,None{})
    case True{}:
      +context = checkpoint_context(row)
      do IO<Maybe<&2,Context>>:
        checked(is_text(cell(row,0n)) && is_text(cell(row,1n)) &&
          is_text(cell(row,2n)) && is_text(cell(row,3n)) &&
          String.eq(field(row,5n),context_digest(snapshot,field(raw,0n),extent,
          number(field(raw,1n)),number(field(raw,2n)),number(field(raw,3n)),
          field(raw,4n),context)),"Captured context checkpoint integrity mismatch; rebuild from retained raw")
        return Some{context}

def context_rows(snapshot: String,extent: U32,raw: List<&2,Sql.Cell>,
  rows: List<&2,List<&2,Sql.Cell>>) -> IO(Maybe<&2,Context>):
  match rows:
    case []:
      IO.pure(Maybe<&2,Context>,None{})
    case +row <> _:
      context_checked(snapshot,extent,raw,row,String.eq(field(row,4n),context_version()))

# Missing or old-version checkpoints use the caller's verified legacy replay.
# Damaged current checkpoints fail explicitly. Only the selected raw record and
# its immediate predecessor are read; earlier raw ranges are not rechecked.
def context_before(+db: U32,+snapshot: String,generation: String,+extent: U32,
  records: U32,+ordinal: U32) -> IO(Maybe<&2,Context>):
  do IO<Maybe<&2,Context>>:
    raw : List<&2,Sql.Cell> <- selected_record(db,snapshot,generation,extent,records,ordinal)
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT repository,session,model,parent,version,digest FROM snapshot_context WHERE snapshot=? AND ordinal=?",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],1)
    context_rows(snapshot,extent,raw,rows)

def put_piece(state: ImportState, piece: Piece) -> IO(ImportState):
  ImportState{+db,file,+provider,+source,+gen,+snap,+extent,+off,+ord,+checkpoint,+checkpoint_ord,+ctx,observe,seal} = state
  Piece{+bytes,+len,+newline,+oversized} = piece
  do IO<ImportState>:
    exec(db,"INSERT INTO raw(generation,ordinal,offset,n,digest,bytes,complete,oversized) VALUES(?,?,?,?,?,?,?,?)",
      [Sql.Cell.Integer{gen},Sql.Cell.Integer{U32.show(ord)},Sql.Cell.Integer{U32.show(off)},
       Sql.Cell.Integer{U32.show(len)},Sql.Cell.Text{raw_digest(gen,ord,off,len,bytes)},
       Sql.Cell.Blob{bytes},Sql.Cell.Integer{U32.show(Bool.to_u32(newline))},
       Sql.Cell.Integer{U32.show(Bool.to_u32(oversized))}])
    rid : String <- last_id(db)
    exec(db,"INSERT INTO records VALUES(?,?,?)",[Sql.Cell.Integer{snap},Sql.Cell.Integer{U32.show(ord)},Sql.Cell.Integer{rid}])
    put_context(db,snap,gen,extent,ord,off,len,raw_digest(gen,ord,off,len,bytes),ctx)
    next : Context <- put_events(piece_events(oversized,provider,bytes),db,snap,ord,0,provider,ctx)
    return ImportState{db,file,provider,source,gen,snap,extent,(off + len : U32),(ord + 1 : U32),
      Bool.pick(U32,newline,(off + len : U32),checkpoint),
      Bool.pick(U32,newline,(ord + 1 : U32),checkpoint_ord),next,observe,seal}

def put_pieces(pieces: List<&2,Piece>, state: ImportState) -> IO(ImportState):
  match pieces:
    case []:
      IO.pure(ImportState,state)
    case piece <> rest:
      do IO<ImportState>:
        next : ImportState <- put_piece(state,piece)
        put_pieces(rest,next)

def compare_record(+row: List<&2,Sql.Cell>, file: File) -> IO(File & Bool):
  read(File & Bool,file,number(field(row,2n)),number(field(row,3n)),
    f => bytes => IO.pure(File & Bool,(f,Domain.bytes_equal(blob(cell(row,5n)),bytes))))

def verify_result(got: File & Bool,next: File -> IO(File & Bool)) -> IO(File & Bool):
  (file,ok) = got
  match ok:
    case False{}:
      IO.pure(File & Bool,(file,False{}))
    case True{}:
      next(file)

type Verify is Data:
  Verify{snapshot: String,generation: String,extent: U32,count: U32,ordinal: U32,offset: U32,continued: Bool}

# Select the bounded map window before joining raw. LEFT JOIN retains a missing
# raw target as an invalid row, and the carried ordinal catches missing maps.
# The byte budget uses actual bytes, never the unverified stored length.
def verify_batch(db: U32,snapshot: String,ordinal: U32,count: U32) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  q(db,
    "SELECT generation,raw_ordinal,offset,n,digest,bytes,oversized,complete,map_ordinal FROM (SELECT r.generation,r.ordinal AS raw_ordinal,r.offset,r.n,r.digest,r.bytes,r.oversized,r.complete,i.ordinal AS map_ordinal,row_number() OVER (ORDER BY i.ordinal) AS rn,sum(coalesce(length(CAST(r.bytes AS BLOB)),0)+coalesce(length(CAST(r.digest AS BLOB)),0)+256) OVER (ORDER BY i.ordinal) AS total_bytes FROM (SELECT ordinal,raw FROM records WHERE snapshot=? AND ordinal>=? AND ordinal<? ORDER BY ordinal LIMIT 128) i LEFT JOIN raw r ON r.id=i.raw) WHERE total_bytes<=1048576 OR rn=1 ORDER BY map_ordinal",
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},
     Sql.Cell.Integer{U32.show(count)}],128)

def verify_batch_prepend(bytes: List<&2,U32>,following: Verify & List<&2,U32>) ->
  Verify & List<&2,U32>:
  (after,tail) = following
  (after,List.append(&2,U32,bytes,tail))

def verify_batch_records(rows: List<&2,List<&2,Sql.Cell>>,state: Verify) ->
  IO(Verify & List<&2,U32>):
  match rows:
    case []:
      IO.pure(Verify & List<&2,U32>,(state,[]))
    case +row <> rest:
      Verify{snap,+gen,+extent,+count,+ordinal,+offset,continued} = state
      do IO<Verify & List<&2,U32>>:
        checked(record_valid(row,gen,extent,count,ordinal,offset,continued),
          "Retained raw integrity, snapshot binding or coverage mismatch; capture refused")
        following : Verify & List<&2,U32> <- verify_batch_records(rest,
          Verify{snap,gen,extent,count,U32.add(ordinal,1),
            U32.add(offset,number(field(row,3n))),Bool.not(row_newline(row))})
        return verify_batch_prepend(blob(cell(row,5n)),following)

def verify_batch_source(file: File,+offset: U32,got: Verify & List<&2,U32>,
  next: Verify -> File -> IO(File & Bool)) -> IO(File & Bool):
  (+state,expected) = got
  Verify{snap,gen,extent,count,ordinal,+end,continued} = state
  do IO<File & Bool>:
    checked(U32.is_gt(end,offset),"Missing retained record; capture refused")
    result : File & Bool <- read(File & Bool,file,offset,U32.sub(end,offset),
      f => bytes => IO.pure(File & Bool,(f,Domain.bytes_equal(expected,bytes))))
    verify_result(result,f => next(state,f))

def verify_step(+db: U32,file: File,state: Verify,done: Bool,
  next: Verify -> File -> IO(File & Bool)) -> IO(File & Bool):
  Verify{+snap,gen,+extent,+count,+ordinal,+offset,continued} = state
  match done:
    case True{}:
      do IO<File & Bool>:
        checked(U32.is_eq(offset,extent),"Retained extent is incomplete; capture refused")
        return (file,True{})
    case False{}:
      do IO<File & Bool>:
        rows : List<&2,List<&2,Sql.Cell>> <- verify_batch(db,snap,ordinal,count)
        batch : Verify & List<&2,U32> <- verify_batch_records(rows,
          Verify{snap,gen,extent,count,ordinal,offset,continued})
        verify_batch_source(file,offset,batch,next)

def verify_walk(fuel: Nat,+db: U32,state: Verify,file: File) -> IO(File & Bool):
  match fuel:
    case 0n:
      IO.die(File & Bool,1,"Record verification budget exhausted")
    case 1n+rest:
      Verify{snap,gen,extent,+count,+ordinal,offset,continued} = state
      verify_step(db,file,Verify{snap,gen,extent,count,ordinal,offset,continued},(ordinal >= count : U32),
        s => f => verify_walk(rest,db,s,f))

def verify_header(fuel: Nat,db: U32,snap: String,file: File,
  rows: List<&2,List<&2,Sql.Cell>>) -> IO(File & Bool):
  match rows:
    case []:
      IO.die(File & Bool,1,"Snapshot missing")
    case header <> rest:
      +h = header
      do IO<File & Bool>:
        checked((numeric(field(h,1n)) && numeric(field(h,2n))
          && String.eq(field(h,2n),field(h,3n))),"Snapshot record count or numeric metadata is corrupt")
        verify_walk(fuel,db,Verify{snap,field(h,0n),number(field(h,1n)),number(field(h,2n)),0,0,False{}},file)

def verify_loop(fuel: Nat,+db: U32,+snap: String,ordinal: U32,file: File) -> IO(File & Bool):
  do IO<File & Bool>:
    checked(U32.is_eq(ordinal,0),"Verification must begin at zero")
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT generation,extent,records,(SELECT count(*) FROM records WHERE snapshot=p.id) FROM snapshots p WHERE id=?",
      [Sql.Cell.Integer{snap}],1)
    verify_header(fuel,db,snap,file,rows)

# Seals cover the exact projection and checkpoint metadata, not rowids. They
# detect accidental projection/checkpoint damage before copying an append prefix.
# Raw bytes retain their separate integrity check; a failed/missing seal replays
# a verified full capture. Version changes cannot silently reuse parser state.
def projection_rows(rows: List<&2,List<&2,Sql.Cell>>,digest: String) -> String:
  match rows:
    case []:
      digest
    case row <> rest:
      projection_rows(rest,Domain.digest(Domain.encode(digest ++ "|" ++ projection_cells(row))))

def projection_last(rows: List<&2,List<&2,Sql.Cell>>,last: List<&2,Sql.Cell>) -> List<&2,Sql.Cell>:
  match rows:
    case []:
      last
    case row <> rest:
      projection_last(rest,row)

def projection_continue(done: Bool,digest: String,next: Unit -> IO(String)) -> IO(String):
  match done:
    case True{}:
      IO.pure(String,digest)
    case False{}:
      next(Unit{})

# Legacy digest diagnostic retained for existing tuple-equivalence tests.
# Production verification and publication use the versioned Seal codec below.
# A tuple cursor lets the composite primary key seek beyond the previous page.
# The equivalent OR predicate scans the snapshot prefix for each bound query.
def projection_walk(fuel: Nat,+db: U32,+snapshot: String,+ordinal: String,event: String,digest: String) -> IO(String):
  match fuel:
    case 0n:
      IO.die(String,1,"Projection verification budget exhausted")
    case 1n+rest:
      do IO<String>:
        +rows : List<&2,List<&2,Sql.Cell>> <- q(db,
          "SELECT ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM (SELECT e.*,row_number() OVER (ORDER BY ordinal,event) AS rn,sum(length(CAST(role AS BLOB))+length(CAST(body AS BLOB))+length(CAST(tool AS BLOB))+length(CAST(call_id AS BLOB))+length(CAST(arguments AS BLOB))+length(CAST(result AS BLOB))+length(CAST(repository AS BLOB))+length(CAST(session AS BLOB))+length(CAST(timestamp AS BLOB))+length(CAST(model AS BLOB))+length(CAST(usage AS BLOB))+length(CAST(parent AS BLOB))+length(CAST(coverage AS BLOB))+256) OVER (ORDER BY ordinal,event) AS total_bytes FROM (SELECT * FROM events WHERE snapshot=? AND (ordinal,event)>(?,?) ORDER BY ordinal,event LIMIT 64) e) WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal,event",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{event}],64)
        +last : List<&2,Sql.Cell> = projection_last(rows,[])
        +next : String = projection_rows(rows,digest)
        projection_continue(List.is_empty(&2,List<&2,Sql.Cell>,rows),next,
          unused => projection_walk(rest,db,snapshot,field(last,0n),field(last,1n),next))

def projection_digest(+db: U32,+snapshot: String) -> IO(String):
  do IO<String>:
    header : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT p.id,p.generation,p.extent,p.checkpoint,p.checkpoint_ordinal,p.records,s.provider,s.locator FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{snapshot}],1)
    seed : String = Domain.digest(Domain.encode(projection_version() ++ "|" ++ projection_cells(first(header))))
    projection_walk(4294967295n,db,snapshot,"-1","-1",seed)

# Parser and incoming-context versions remain unchanged. Only the derivative
# event seal has a new explicit format; old writers see an unknown tag and take
# their existing verified full replay path in the same schema.
def has_triggers(db: U32) -> IO(Bool):
  Seal.has_triggers(db)

def seal_projection(db: U32,snapshot: String) -> IO(Unit):
  Seal.write_full(db,snapshot,projection_version())

def projection_version_valid(db: U32,snapshot: String,expected: String,current: Bool) -> IO(Bool):
  match current:
    case False{}:
      IO.pure(Bool,False{})
    case True{}:
      do IO<Bool>:
        actual : String <- projection_digest(db,snapshot)
        return String.eq(actual,expected)

def projection_check_rows(db: U32,snapshot: String,rows: List<&2,List<&2,Sql.Cell>>) -> IO(Bool):
  match rows:
    case []:
      IO.pure(Bool,False{})
    case row <> rest:
      +r = row
      projection_version_valid(db,snapshot,field(r,1n),String.eq(field(r,0n),projection_version()))

def projection_valid(db: U32,snapshot: String) -> IO(Bool):
  do IO<Bool>:
    verified : Seal.Validation <- Seal.verify(db,snapshot,projection_version())
    return Seal.is_verified(verified)

def finish_verified(+db: U32,+source: String,+snap: String,got: File & Bool,
  observe: ImportObserver,seal: Seal.Validation) -> IO(String):
  (file,stable) = got
  do IO<String>:
    File.close(file)
    checked(stable,"Source changed during capture; transaction discarded")
    verified_observer : ImportObserver <- observe_phase(observe,Reverified{})
    Seal.write(db,snap,projection_version(),seal)
    sealed_observer : ImportObserver <- observe_phase(verified_observer,Sealed{})
    exec(db,"UPDATE snapshots SET accepted=1 WHERE id=?",[Sql.Cell.Integer{snap}])
    accepted_observer : ImportObserver <- observe_phase(sealed_observer,Accepted{})
    clear_source_search(db,source)
    removed_observer : ImportObserver <- observe_phase(accepted_observer,SearchRemoved{})
    exec(db,"UPDATE sources SET latest=? WHERE id=?",[Sql.Cell.Integer{snap},Sql.Cell.Integer{source}])
    latest_observer : ImportObserver <- observe_phase(removed_observer,LatestRepointed{})
    index_search_snapshot(db,snap)
    commit_observer : ImportObserver <- observe_phase(latest_observer,BeforeCommit{})
    exec(db,"COMMIT",[])
    finished_observer : ImportObserver <- observe_phase(commit_observer,Committed{})
    return snap

def finish(state: ImportState) -> IO(String):
  ImportState{+db,file,provider,+source,gen,+snap,+extent,off,ord,checkpoint,checkpoint_ord,ctx,observe,seal} = state
  do IO<String>:
    checked(U32.is_eq(off,extent),"Capture extent mismatch")
    exec(db,"UPDATE snapshots SET checkpoint=?,checkpoint_ordinal=?,records=? WHERE id=?",
      [Sql.Cell.Integer{U32.show(checkpoint)},Sql.Cell.Integer{U32.show(checkpoint_ord)},
       Sql.Cell.Integer{U32.show(ord)},Sql.Cell.Integer{snap}])
    staged_observer : ImportObserver <- observe_phase(observe,Staged{})
    verified : File & Bool <- verify_loop(4294967295n,db,snap,0,file)
    finish_verified(db,source,snap,verified,staged_observer,seal)

def finish_tail(state: ImportState, tail: List<&2,U32>, len: U32, oversized: Bool) ->
  IO(String):
  match tail:
    case []:
      finish(state)
    case h <> t:
      do IO<String>:
        next : ImportState <- put_piece(state,Piece{List.reverse(&2,U32,h <> t),len,False{},oversized})
        finish(next)

def capture_split(state: ImportState, cursor: U32, split: Split,
  next: ImportState -> U32 -> List<&2,U32> -> U32 -> Bool -> IO(String)) -> IO(String):
  Split{pieces,tail,len,oversized} = split
  do IO<String>:
    updated : ImportState <- put_pieces(pieces,state)
    IO.sleep(1)
    next(updated,cursor,tail,len,oversized)

def capture_bytes(state: ImportState,cursor: U32,tail: List<&2,U32>,
  len: U32,oversized: Bool,+bytes: List<&2,U32>,
  next: ImportState -> U32 -> List<&2,U32> -> U32 -> Bool -> IO(String)) -> IO(String):
  +size = U32.from_nat(List.length(&2,U32,bytes))
  do IO<String>:
    checked((size > 0 : U32),"Unexpected EOF while capturing")
    capture_split(state,(cursor + size : U32),split(bytes,tail,len,oversized,[]),next)

def capture_step(state: ImportState, +cursor: U32, tail: List<&2,U32>,
  len: U32, oversized: Bool, done: Bool,
  next: ImportState -> U32 -> List<&2,U32> -> U32 -> Bool -> IO(String)) -> IO(String):
  ImportState{db,file,provider,source,gen,snap,+extent,off,ord,checkpoint,cpord,ctx,observe,seal} = state
  match done:
    case True{}:
      finish_tail(ImportState{db,file,provider,source,gen,snap,extent,off,ord,checkpoint,cpord,ctx,observe,seal},tail,len,oversized)
    case False{}:
      read(String,file,cursor,U32.min(65536,(extent - cursor : U32)),
        f => bytes => capture_bytes(
          ImportState{db,f,provider,source,gen,snap,extent,off,ord,checkpoint,cpord,ctx,observe,seal},
          cursor,tail,len,oversized,bytes,next))

def capture_loop(fuel: Nat,state: ImportState,cursor: U32,tail: List<&2,U32>,
  length: U32,oversized: Bool) -> IO(String):
  match fuel:
    case 0n:
      IO.die(String,1,"Capture budget exhausted")
    case 1n+rest:
      ImportState{db,file,provider,source,gen,snap,+extent,off,ord,checkpoint,cpord,ctx,observe,seal} = state
      +pos = cursor
      capture_step(ImportState{db,file,provider,source,gen,snap,extent,off,ord,checkpoint,cpord,ctx,observe,seal},
        pos,tail,length,oversized,(pos >= extent : U32),
        st => cur => pending => len => over => capture_loop(rest,st,cur,pending,len,over))

def new_capture(+db: U32, file: File, provider: String, +source: String, +extent: U32,
  observe: ImportObserver) ->
  IO(String):
  do IO<String>:
    exec(db,"INSERT INTO generations(source) VALUES(?)",[Sql.Cell.Integer{source}])
    +gen : String <- last_id(db)
    exec(db,"INSERT INTO snapshots(generation,extent) VALUES(?,?)",
      [Sql.Cell.Integer{gen},Sql.Cell.Integer{U32.show(extent)}])
    snap : String <- last_id(db)
    capture_loop(65537n,ImportState{db,file,provider,source,gen,snap,extent,0,0,0,0,Context{"","","",""},observe,Seal.SealReplay{}},
      0,[],0,False{})

def append_context(row: List<&2,Sql.Cell>) -> Context:
  +r = row
  Context{field(r,0n),field(r,1n),field(r,2n),field(r,3n)}

# Prefix rows omit the BLOB because the import transaction has already verified
# every old raw record against both its digest and source bytes. Batch size is
# bounded by UTF-8 payload bytes as well as row count.
def context_prefix_rows(db: U32,+snapshot: String,ordinal: U32,count: U32) ->
  IO(List<&2,List<&2,Sql.Cell>>):
  q(db,
    "SELECT generation,ordinal,offset,n,raw_digest,repository,session,model,parent,version,digest FROM (SELECT r.generation,i.ordinal,r.offset,r.n,r.digest AS raw_digest,c.repository,c.session,c.model,c.parent,c.version,c.digest,row_number() OVER (ORDER BY i.ordinal) AS rn,sum(coalesce(length(CAST(c.repository AS BLOB))+length(CAST(c.session AS BLOB))+length(CAST(c.model AS BLOB))+length(CAST(c.parent AS BLOB)),0)+512) OVER (ORDER BY i.ordinal) AS total_bytes FROM (SELECT ordinal,raw FROM records WHERE snapshot=? AND ordinal>=? AND ordinal<? ORDER BY ordinal LIMIT 32) i JOIN raw r ON r.id=i.raw LEFT JOIN snapshot_context c ON c.snapshot=? AND c.ordinal=i.ordinal) WHERE total_bytes<=1048576 OR rn=1 ORDER BY ordinal",
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},
     Sql.Cell.Integer{U32.show(count)},Sql.Cell.Integer{snapshot}],32)

def prefix_context(+row: List<&2,Sql.Cell>) -> Context:
  Context{field(row,5n),field(row,6n),field(row,7n),field(row,8n)}

def prefix_context_valid(+row: List<&2,Sql.Cell>,snapshot: String,+generation: String,
  extent: U32,+ordinal: U32) -> Bool:
  numeric(field(row,1n)) && numeric(field(row,2n)) && numeric(field(row,3n)) &&
    is_text(cell(row,5n)) && is_text(cell(row,6n)) &&
    is_text(cell(row,7n)) && is_text(cell(row,8n)) &&
    String.eq(field(row,0n),generation) && String.eq(field(row,1n),U32.show(ordinal)) &&
    String.eq(field(row,9n),context_version()) &&
    String.eq(field(row,10n),context_digest(snapshot,generation,extent,ordinal,
      number(field(row,2n)),number(field(row,3n)),field(row,4n),prefix_context(row)))

def context_prefix_valid_rows(rows: List<&2,List<&2,Sql.Cell>>,+snapshot: String,
  +generation: String,+extent: U32,+ordinal: U32) -> Bool:
  match rows:
    case []:
      True{}
    case row <> rest:
      prefix_context_valid(row,snapshot,generation,extent,ordinal) &&
        context_prefix_valid_rows(rest,snapshot,generation,extent,U32.add(ordinal,1))

def context_prefix_continue(valid: Bool,next: Unit -> IO(Bool)) -> IO(Bool):
  match valid:
    case False{}:
      IO.pure(Bool,False{})
    case True{}:
      next(Unit{})

def context_prefix_walk(fuel: Nat,+db: U32,+snapshot: String,+generation: String,
  +extent: U32,+count: U32,+ordinal: U32,done: Bool) -> IO(Bool):
  match fuel done:
    case _ True{}:
      IO.pure(Bool,True{})
    case 0n False{}:
      IO.pure(Bool,False{})
    case 1n+rest False{}:
      do IO<Bool>:
        +rows : List<&2,List<&2,Sql.Cell>> <- context_prefix_rows(db,snapshot,ordinal,count)
        +next : U32 = U32.add(ordinal,U32.from_nat(List.length(&2,List<&2,Sql.Cell>,rows)))
        context_prefix_continue(U32.is_gt(next,ordinal) &&
          context_prefix_valid_rows(rows,snapshot,generation,extent,ordinal),
          unused => context_prefix_walk(rest,db,snapshot,generation,extent,count,next,
            U32.is_ge(next,count)))

def context_prefix_valid(db: U32,+previous: List<&2,Sql.Cell>,projection_ok: Bool) -> IO(Bool):
  context_prefix_continue(projection_ok,unused =>
    context_prefix_walk(4294967295n,db,field(previous,1n),field(previous,0n),
      number(field(previous,2n)),number(field(previous,4n)),0,
      U32.is_eq(number(field(previous,4n)),0)))

def copy_context_cells(rows: List<&2,List<&2,Sql.Cell>>,+snapshot: String,+extent: U32) ->
  List<&2,Sql.Cell>:
  match rows:
    case []:
      []
    case +row <> rest:
      List.append(&2,Sql.Cell,
        context_cells(snapshot,field(row,0n),extent,number(field(row,1n)),
          number(field(row,2n)),number(field(row,3n)),field(row,4n),prefix_context(row)),
        copy_context_cells(rest,snapshot,extent))

# The existing context reader supplies at most32 rows/1MiB. Re-seal every row
# with the same snapshot/extent-bound digest, then use one typed INSERT for the
# batch instead of one SQLite round trip per checkpoint. No checksum is reused.
def copy_context_rows(rows: List<&2,List<&2,Sql.Cell>>,db: U32,snapshot: String,
  extent: U32) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case row <> +rest:
      do IO<Unit>:
        checked(Nat.is_lt(List.length(&2,List<&2,Sql.Cell>,rest),32n),
          "Context checkpoint insertion batch exceeds its bound")
        exec(db,"INSERT OR REPLACE INTO snapshot_context(snapshot,ordinal,repository,session,model,parent,version,digest) VALUES(?,?,?,?,?,?,?,?)" ++
          String.repeat(",(?,?,?,?,?,?,?,?)",List.length(&2,List<&2,Sql.Cell>,rest)),
          copy_context_cells(row <> rest,snapshot,extent))

def copy_context_walk(fuel: Nat,+db: U32,+old: String,+snapshot: String,+extent: U32,
  +count: U32,+ordinal: U32,done: Bool) -> IO(Unit):
  match fuel done:
    case _ True{}:
      IO.pure(Unit,Unit{})
    case 0n False{}:
      IO.die(Unit,1,"Context checkpoint copy budget exhausted")
    case 1n+rest False{}:
      do IO<Unit>:
        +rows : List<&2,List<&2,Sql.Cell>> <- context_prefix_rows(db,old,ordinal,count)
        +next : U32 = U32.add(ordinal,U32.from_nat(List.length(&2,List<&2,Sql.Cell>,rows)))
        checked(U32.is_gt(next,ordinal),"Context checkpoint prefix integrity is incomplete")
        copy_context_rows(rows,db,snapshot,extent)
        copy_context_walk(rest,db,old,snapshot,extent,count,next,U32.is_ge(next,count))

def copy_record_batch(db: U32,old: String,snapshot: String,count: U32,+ordinal: U32,
  done: Bool,next: U32 -> IO(Unit)) -> IO(Unit):
  match done:
    case True{}:
      IO.pure(Unit,Unit{})
    case False{}:
      +stop = U32.add(ordinal,U32.min(256,U32.sub(count,ordinal)))
      do IO<Unit>:
        exec(db,"INSERT INTO records SELECT ?,ordinal,raw FROM records WHERE snapshot=? AND ordinal>=? AND ordinal<? ORDER BY ordinal",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{old},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(stop)}])
        next(stop)

def copy_record_walk(fuel: Nat,+db: U32,+old: String,+snapshot: String,+count: U32,+ordinal: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Record map copy batch budget exhausted")
    case 1n+rest:
      copy_record_batch(db,old,snapshot,count,ordinal,U32.is_ge(ordinal,count),
        stop => copy_record_walk(rest,db,old,snapshot,count,stop))

def copy_event_batch(db: U32,old: String,snapshot: String,ordinal: String,event: String,
  rows: List<&2,List<&2,Sql.Cell>>,next: String -> String -> IO(Unit)) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case row <> more:
      +last = batch_last(row <> more,[])
      do IO<Unit>:
        exec(db,
          "INSERT INTO events SELECT ?,ordinal,event,role,body,tool,call_id,arguments,result,repository,session,timestamp,model,usage,parent,coverage FROM events WHERE snapshot=? AND (ordinal,event)>(?,?) AND (ordinal,event)<=(?,?) ORDER BY ordinal,event",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{old},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{event},
           Sql.Cell.Integer{field(last,0n)},Sql.Cell.Integer{field(last,1n)}])
        next(field(last,0n),field(last,1n))

def copy_event_walk(fuel: Nat,+db: U32,+old: String,+snapshot: String,+count: String,
  +ordinal: String,+event: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.die(Unit,1,"Event copy batch budget exhausted")
    case 1n+rest:
      do IO<Unit>:
        rows : List<&2,List<&2,Sql.Cell>> <- event_batch(db,old,ordinal,event,count)
        copy_event_batch(db,old,snapshot,ordinal,event,rows,
          ord => evt => copy_event_walk(rest,db,old,snapshot,count,ord,evt))

def append_copy_with_seal(+db: U32,file: File,provider: String,source: String,+extent: U32,
  +previous: List<&2,Sql.Cell>,observe: ImportObserver,seal: Seal.Validation) -> IO(String):
  +gen = field(previous,0n)
  +old = field(previous,1n)
  +checkpoint = number(field(previous,3n))
  +ord = number(field(previous,4n))
  do IO<String>:
    exec(db,"INSERT INTO snapshots(generation,extent) VALUES(?,?)",
      [Sql.Cell.Integer{gen},Sql.Cell.Integer{U32.show(extent)}])
    +snap : String <- last_id(db)
    copy_record_walk(4294967295n,db,old,snap,ord,0)
    copy_event_walk(4294967295n,db,old,snap,U32.show(ord),"-1","-1")
    copy_context_walk(4294967295n,db,old,snap,extent,ord,0,U32.is_eq(ord,0))
    ctxrows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT repository,session,model,parent FROM events WHERE snapshot=? ORDER BY ordinal DESC,event DESC LIMIT 1",
      [Sql.Cell.Integer{snap}],1)
    capture_loop(65537n,ImportState{db,file,provider,source,gen,snap,extent,checkpoint,ord,checkpoint,ord,append_context(first(ctxrows)),observe,seal},
      checkpoint,[],0,False{})

# Compatibility entry for diagnostics that explicitly request a full new seal.
def append_copy(db: U32,file: File,provider: String,source: String,extent: U32,
  previous: List<&2,Sql.Cell>,observe: ImportObserver) -> IO(String):
  append_copy_with_seal(db,file,provider,source,extent,previous,observe,Seal.SealReplay{})

# The source prefix was already checked against immutable raw records by
# existing_verified. On seal mismatch, re-read and verify a full same-generation
# capture; never copy damaged derived events or derive context from them.
def append_replay(+db: U32,file: File,provider: String,source: String,+extent: U32,
  previous: List<&2,Sql.Cell>,observe: ImportObserver) -> IO(String):
  +generation = field(previous,0n)
  do IO<String>:
    exec(db,"INSERT INTO snapshots(generation,extent) VALUES(?,?)",[Sql.Cell.Integer{generation},Sql.Cell.Integer{U32.show(extent)}])
    snapshot : String <- last_id(db)
    capture_loop(65537n,ImportState{db,file,provider,source,generation,snapshot,extent,0,0,0,0,Context{"","","",""},observe,Seal.SealReplay{}},0,[],0,False{})

def append_checked(db: U32,file: File,provider: String,source: String,extent: U32,
  previous: List<&2,Sql.Cell>,valid: Bool,observe: ImportObserver) -> IO(String):
  match valid:
    case True{}:
      append_copy(db,file,provider,source,extent,previous,observe)
    case False{}:
      append_replay(db,file,provider,source,extent,previous,observe)

def append_prefix_checked(db: U32,file: File,provider: String,source: String,extent: U32,
  previous: List<&2,Sql.Cell>,observe: ImportObserver,prefix: Seal.Prefix,valid: Bool) -> IO(String):
  match valid:
    case True{}:
      append_copy_with_seal(db,file,provider,source,extent,previous,observe,Seal.SealVerified{prefix})
    case False{}:
      append_replay(db,file,provider,source,extent,previous,observe)

def append_verified(+db: U32,file: File,+provider: String,+source: String,extent: U32,
  +previous: List<&2,Sql.Cell>,observe: ImportObserver,result: Seal.Validation) -> IO(String):
  match result:
    case Seal.SealReplay{}:
      append_replay(db,file,provider,source,extent,previous,observe)
    case Seal.SealVerified{prefix}:
      do IO<String>:
        bound : Seal.Prefix <- Seal.require_import(db,prefix,source,provider,field(previous,0n),
          field(previous,1n),field(previous,2n),field(previous,3n),field(previous,4n))
        valid : Bool <- context_prefix_valid(db,previous,True{})
        append_prefix_checked(db,file,provider,source,extent,previous,observe,bound,valid)

def append_capture(+db: U32,file: File,provider: String,source: String,extent: U32,
  +previous: List<&2,Sql.Cell>,observe: ImportObserver) -> IO(String):
  do IO<String>:
    verified : Seal.Validation <- Seal.verify(db,field(previous,1n),projection_version())
    append_verified(db,file,provider,source,extent,previous,observe,verified)

def existing_same(+db: U32,file: File,provider: String,source: String,extent: U32,
  previous: List<&2,Sql.Cell>,unchanged: Bool,observe: ImportObserver) -> IO(String):
  match unchanged:
    case True{}:
      do IO<String>:
        File.close(file)
        commit_observer : ImportObserver <- observe_phase(observe,BeforeCommit{})
        exec(db,"COMMIT",[])
        finished_observer : ImportObserver <- observe_phase(commit_observer,Committed{})
        return field(previous,1n)
    case False{}:
      append_capture(db,file,provider,source,extent,previous,observe)

def existing_result(+db: U32,file: File,provider: String,source: String,+extent: U32,
  +previous: List<&2,Sql.Cell>,same: Bool,observe: ImportObserver) -> IO(String):
  match same:
    case False{}:
      new_capture(db,file,provider,source,extent,observe)
    case True{}:
      existing_same(db,file,provider,source,extent,previous,
        U32.is_eq(extent,number(field(previous,2n))),observe)

def existing_verified(db: U32,provider: String,source: String,+extent: U32,
  +old: List<&2,Sql.Cell>,got: File & Bool,observe: ImportObserver) -> IO(String):
  (f,same) = got
  existing_result(db,f,provider,source,extent,old,
    (same && (extent >= number(field(old,2n)) : U32)),observe)

def existing(+db: U32,file: File,+provider: String,+source: String,+extent: U32,
  rows: List<&2,List<&2,Sql.Cell>>,observe: ImportObserver) -> IO(String):
  match rows:
    case []:
      new_capture(db,file,provider,source,extent,observe)
    case previous <> rest:
      +old = previous
      do IO<String>:
        checked(String.eq(field(old,5n),source),"Latest snapshot belongs to another source; capture refused")
        verified : File & Bool <- verify_loop(4294967295n,db,field(old,1n),0,file)
        existing_verified(db,provider,source,extent,old,verified,observe)

def import_sized(+db: U32,+provider: String,+path: String,
  got: File & Result<&1,&1,U32 & String,U32>,observe: ImportObserver) -> IO(String):
  (f,size) = got
  do IO<String>:
    +extent : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,size))
    transaction_observer : ImportObserver <- observe_phase(observe,BeforeTransaction{})
    exec(db,"BEGIN IMMEDIATE",[])
    +src : String <- source(db,provider,path)
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT p.generation,p.id,p.extent,p.checkpoint,p.checkpoint_ordinal,g.source FROM sources s JOIN snapshots p ON p.id=s.latest AND p.accepted=1 JOIN generations g ON g.id=p.generation WHERE s.id=?",
      [Sql.Cell.Integer{src}],1)
    existing(db,f,provider,src,extent,rows,transaction_observer)

def import_canonical(+db: U32,+provider: String,+path: String,
  observe: ImportObserver) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    sized : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    import_sized(db,provider,path,sized,observe)

def import_observed(db: U32,+provider: String,path: String,
  observe: ImportObserver) -> IO(String):
  do IO<String>:
    checked((String.eq(provider,"claude") || String.eq(provider,"codex")),
      "Provider must be claude or codex")
    canonical : String <- Paths.resolve(path)
    import_canonical(db,provider,canonical,observe)

def import_file(db: U32,provider: String,path: String) -> IO(String):
  import_observed(db,provider,path,Unobserved{})

def write_closed(got: File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = got
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def write_text(path: String,mode: String,content: String) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,mode))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write(file,content)
    write_closed(written)

def display_field(label: String,value: String) -> String:
  match value:
    case "":
      ""
    case _:
      "\n" ++ label ++ ": " ++ value ++ "\n"

def display_event(event: Providers.Record) -> String:
  Providers.ProviderEvent{role,body,tool,callid,args,result,repo,session,time,model,usage,parent,coverage} = event
  "[" ++ role ++ "] " ++ nonempty(time,"time not captured") ++ "\n" ++ body ++ "\n" ++
    display_field("Tool",tool) ++ display_field("Call ID",callid) ++
    display_field("Arguments",args) ++ display_field("Result",result) ++
    display_field("Recorded model",model) ++
    display_field("Recorded usage (source fact; mirrors are not additive)",usage) ++
    display_field("Parent reference",parent) ++
    "\nCoverage: " ++ coverage ++ "\n"

def display_events(events: List<&2,Providers.Record>) -> String:
  match events:
    case []:
      ""
    case event <> rest:
      display_event(event) ++ "\n" ++ display_events(rest)

def page_rows(rows: List<&2,List<&2,Sql.Cell>>, +provider: String) -> IO(String):
  match rows:
    case []:
      IO.pure(String,"")
    case row <> rest:
      +r = row
      +offset = number(field(r,2n))
      +len = number(field(r,3n))
      do IO<String>:
        tail : String <- page_rows(rest,provider)
        return "Record " ++ field(r,1n) ++ " · bytes " ++ U32.show(offset) ++
          ".." ++ U32.show((offset + len : U32)) ++ "\n" ++
          display_events(piece_events(U32.is_ne(number(field(r,6n)),0),
            provider,blob(cell(r,5n)))) ++ tail

def page_header(+db: U32,+snapshot: String,+start: U32,count: U32,
  rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case []:
      IO.die(String,1,"Accepted snapshot not found")
    case header <> rest:
      +h = header
      +n = Domain.bounded_count(start,U32.min(count,100),number(field(h,2n)))
      do IO<String>:
        checked((numeric(field(h,1n)) && numeric(field(h,2n))),"Snapshot numeric metadata is corrupt")
        records : List<&2,List<&2,Sql.Cell>> <- selected_records(db,snapshot,field(h,0n),
          number(field(h,1n)),number(field(h,2n)),start,n)
        content : String <- page_rows(records,field(h,3n))
        return "Juice Bend · captured evidence\nSnapshot " ++ snapshot ++
          " · generation " ++ field(h,0n) ++ " · " ++ field(h,1n) ++
          " retained bytes\nProvider: " ++ field(h,3n) ++
          "\nIntegrity: selected records verified; other ranges not checked.\n\n" ++ content

def page(+db: U32,+snapshot: String,start: U32,count: U32) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- q(db,
      "SELECT p.generation,p.extent,p.records,s.provider FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    page_header(db,snapshot,start,count,rows)
