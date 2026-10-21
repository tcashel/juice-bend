import Base
import ./native_activity.bend as Safe
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths
import ../src/maintenance.bend as Maintenance
import ../src/scoped_reader.bend as Scoped

# This fixture owns a newly created private /private/tmp child only. Candidate
# files stay outside the original capture folder. It never registers roots or
# saves refresh preferences; those changes belong to the real Settings UI.
def checked(valid: Bool,message: String) -> IO(Unit):
  Store.checked(valid,"Native Settings fixture: " ++ message)

def root_shape(+root: String) -> Bool:
  +name = Safe.leaf_parts(List.reverse(&2,String,String.split(root,'/')))
  String.eq(root,"/private/tmp/" ++ name) &&
    (String.eq(name,"juice-bend-settings-fixture") || String.starts_with(name,"juice-bend-settings-fixture-")) &&
    Safe.name_chars(name) && Nat.is_le(String.length(name),100n)

def repo() -> String:
  "/synthetic/settings"

def claude(session: String,role: String,text: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"sessionId\":" ++ Json.quote(session) ++
    ",\"cwd\":" ++ Json.quote(repo()) ++ ",\"timestamp\":\"2026-10-20T12:00:00Z\"," ++
    "\"message\":{\"content\":[{\"type\":\"text\",\"text\":" ++ Json.quote(text) ++ "}]}}\n"

def filler(fuel: Nat,+ordinal: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+rest:
      claude("settings-origin-session","assistant","Ordinary origin record " ++ U32.show(ordinal)) ++
        filler(rest,U32.inc(ordinal))

def origin() -> String:
  filler(40n,0) ++ claude("settings-origin-session","assistant","settings-origin café 中文 🙂") ++
    claude("settings-origin-session","assistant","Original final record 41; restore this same captured reader range.")

def codex_message(role: String,text: String) -> String:
  "{\"type\":\"response_item\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"payload\":{\"type\":\"message\",\"role\":" ++
    Json.quote(role) ++ ",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(text) ++ "}]}}\n"

def initial(index: U32) -> String:
  match index:
    case 1:
      origin()
    case 2:
      claude("settings-claude-session","user","settings-claude candidate folder") ++
        claude("settings-claude-session","assistant","Claude candidate café 中文 🙂")
    case 3:
      "{\"type\":\"session_meta\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"payload\":{\"id\":\"settings-codex-session\",\"cwd\":" ++
        Json.quote(repo()) ++ ",\"source\":\"cli\"}}\n" ++
        codex_message("user","settings-codex candidate folder") ++
        codex_message("assistant","Codex candidate café 中文 🙂")
    case _:
      claude("settings-import-session","user","settings-import explicit file outside both candidate folders") ++
        claude("settings-import-session","assistant","Explicit imported file café 中文 🙂")

def appended() -> String:
  claude("settings-claude-session","assistant","settings-refresh café 中文 🙂 — manual refresh while automatic capture is paused.")

def provider(index: U32) -> String:
  Bool.pick(String,U32.is_eq(index,3),"codex","claude")

def folder(root: String,index: U32) -> String:
  match index:
    case 1: root ++ "/origin"
    case 2: root ++ "/candidates/claude"
    case 3: root ++ "/candidates/codex"
    case _: root ++ "/explicit"

def source(root: String,+index: U32) -> String:
  folder(root,index) ++ "/" ++ Bool.pick(String,U32.is_eq(index,1),"origin.jsonl","source.jsonl")

def database(root: String) -> String:
  root ++ "/library/juice-bend.sqlite"

def marker(root: String) -> String:
  root ++ "/.juice-bend-settings-fixture-v1"

def count(text: String) -> U32:
  U32.from_nat(Nat.sub(List.length(&2,String,String.split(text,'\n')),1n))

def description(+root: String,snapshot: String) -> String:
  "{\"fixture\":\"juice-bend-settings-fixture-v1\",\"root\":" ++ Json.quote(root) ++
    ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"repository\":" ++ Json.quote(repo()) ++
    ",\"origin_source\":" ++ Json.quote(source(root,1)) ++ ",\"origin_snapshot\":" ++ Json.quote(snapshot) ++
    ",\"origin_generation\":\"1\",\"origin_records\":42,\"origin_start\":40,\"origin_query\":\"settings-origin\"," ++
    "\"claude_folder\":" ++ Json.quote(folder(root,2)) ++ ",\"claude_source\":" ++ Json.quote(source(root,2)) ++
    ",\"claude_initial_records\":2,\"claude_appended_records\":3,\"append_query\":\"settings-refresh\"," ++
    "\"codex_folder\":" ++ Json.quote(folder(root,3)) ++ ",\"codex_source\":" ++ Json.quote(source(root,3)) ++
    ",\"codex_records\":3,\"import_provider\":\"claude\",\"import_file\":" ++ Json.quote(source(root,4)) ++
    ",\"import_records\":2,\"registered_roots\":0,\"refresh_preference_keys_present\":false}"

def source_files(fuel: Nat,+root: String,+index: U32,+advanced: Bool) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Safe.regular_path(folder(root,index),True{})
        Safe.exact_file(source(root,index),initial(index) ++ Bool.pick(String,
          advanced && U32.is_eq(index,2),appended(),""))
        Safe.absent(source(root,index) ++ ".retained")
        source_files(rest,root,U32.inc(index),advanced)

def create_files(fuel: Nat,+root: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Safe.directory(folder(root,index))
        Store.write_text(source(root,index),"w",initial(index))
        Safe.private_file(source(root,index),"600")
        create_files(rest,root,U32.inc(index))

def exact_capture(+db: U32,+snapshot: String,text: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.bytes FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal LIMIT 64",
      [Sql.Cell.Integer{snapshot}],64)
    bytes : List<&2,U32> <- Safe.need(List<&2,U32>,Safe.captured_bytes(rows))
    checked(Domain.bytes_equal(bytes,Domain.encode(text)),"retained bytes differ from the exact owned source")
    Maintenance.verify(db,snapshot)

def origin_state(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    Safe.scalar(db,"SELECT count(*) FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE s.id=1 AND s.provider='claude' AND s.locator=? AND s.latest=1 AND g.id=1 AND p.id=1 AND p.accepted=1 AND p.records=42 AND p.extent=?",
      [Sql.Cell.Text{source(root,1)},Sql.Cell.Integer{U32.show(U32.from_nat(List.length(&2,U32,Domain.encode(origin()))))}],"1")
    exact_capture(db,"1",origin())
    +page : String <- Scoped.page(db,"1",40,40,Scoped.Scope{"claude",repo(),"assistant","2026-10-20"},False{})
    checked(String.contains(page,"settings-origin café 中文 🙂") && String.contains(page,"Original final record 41") &&
      Bool.not(String.contains(page,"Ordinary origin record")),"nonzero origin range or exact scoped reader changed")

def initial_state(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Safe.scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    Safe.scalar(db,"SELECT count(*) FROM sources",[],"1")
    Safe.scalar(db,"SELECT count(*) FROM generations",[],"1")
    Safe.scalar(db,"SELECT count(*) FROM snapshots",[],"1")
    Safe.scalar(db,"SELECT count(*) FROM raw",[],"42")
    Safe.scalar(db,"SELECT count(*) FROM records",[],"42")
    Safe.scalar(db,"SELECT count(*) FROM events",[],"42")
    Safe.scalar(db,"SELECT count(*) FROM search",[],"42")
    Safe.scalar(db,"SELECT count(*) FROM sqlite_schema WHERE type='table' AND name='source_roots'",[],"0")
    Safe.scalar(db,"SELECT count(*) FROM settings WHERE key IN ('refresh.enabled','refresh.interval_seconds')",[],"0")
    origin_state(db,root)

def fixture(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"new root must be a direct /private/tmp child named juice-bend-settings-fixture with optional safe suffix")
    canonical : String <- Paths.destination(root)
    checked(String.eq(canonical,root),"new root parent must be canonical")
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(root ++ "/library")
    Safe.directory(root ++ "/candidates")
    create_files(4n,root,1)
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    Safe.private_file(database(root),"600")
    Store.schema(db)
    +snapshot : String <- Store.import_file(db,"claude",source(root,1))
    checked(String.eq(snapshot,"1"),"unexpected initial capture identity")
    initial_state(db,root)
    IO.try(Unit,Sql.close(db))
    Store.write_text(marker(root),"w",description(root,snapshot) ++ "\n")
    Safe.private_file(marker(root),"400")
    source_files(4n,root,1,False{})
    IO.print(description(root,snapshot))

def owned(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"invalid owned root")
    Safe.regular_path(root,True{})
    Safe.exact_file(marker(root),description(root,"1") ++ "\n")
    Safe.regular_path(root ++ "/library",True{})
    Safe.regular_path(root ++ "/candidates",True{})
    Safe.regular_path(database(root),False{})
    Safe.optional_file(database(root) ++ "-wal")
    Safe.optional_file(database(root) ++ "-shm")
    Safe.optional_file(database(root) ++ "-journal")
    source_files(4n,root,1,False{})

def source_index(fuel: Nat,+root: String,+index: U32,+kind: String,+path: String) -> U32:
  match fuel:
    case 0n:
      0
    case 1n+rest:
      Bool.pick(U32,String.eq(provider(index),kind) && String.eq(source(root,index),path),index,
        source_index(rest,root,U32.inc(index),kind,path))

def captured_sources(rows: List<&2,List<&2,Sql.Cell>>,+db: U32,+root: String) -> IO(Unit):
  match rows:
    case []:
      IO.pure(Unit,Unit{})
    case +row <> rest:
      +id = Store.field(row,0n)
      +index = source_index(4n,root,1,Store.field(row,1n),Store.field(row,2n))
      do IO<Unit>:
        checked(U32.is_ge(index,1) && U32.is_le(index,4),"database contains a foreign source")
        Safe.scalar(db,"SELECT count(*) FROM sources s JOIN generations g ON g.source=s.id JOIN snapshots p ON p.generation=g.id WHERE s.id=? AND s.latest=s.id AND g.id=s.id AND p.id=s.id AND p.accepted=1 AND p.records=?",
          [Sql.Cell.Integer{id},Sql.Cell.Integer{U32.show(count(initial(index)))}],"1")
        exact_capture(db,id,initial(index))
        captured_sources(rest,db,root)

# Settings may have captured any subset of the three candidates and changed
# preferences. Only the four exact owned initial captures are accepted here.
# The fixture itself neither creates UI settings tables nor updates the DB.
def before_append(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Safe.scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT id,provider,locator FROM sources ORDER BY id LIMIT 5",[],5)
    +size : U32 = U32.from_nat(List.length(&2,List<&2,Sql.Cell>,rows))
    checked(U32.is_ge(size,1) && U32.is_le(size,4),"unexpected source count")
    Safe.scalar(db,"SELECT count(*) FROM generations",[],U32.show(size))
    Safe.scalar(db,"SELECT count(*) FROM snapshots",[],U32.show(size))
    captured_sources(rows,db,root)
    origin_state(db,root)

def append_only(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    before_append(db,root)
    IO.try(Unit,Sql.close(db))
    Safe.exact_file(source(root,2),initial(2))
    Store.write_text(source(root,2),"a",appended())
    source_files(4n,root,1,True{})
    IO.print("{\"source_changed\":\"claude_append\",\"capture_requested\":false,\"source\":" ++ Json.quote(source(root,2)) ++
      ",\"records_before\":2,\"records_after\":3,\"origin_snapshot\":\"1\"}")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []:
      fixture(root)
    case _ <> "append-only" <> root <> []:
      append_only(root)
    case _:
      IO.die(Unit,2,"Usage: native-settings fixture NEW_ROOT | append-only ROOT; roots must be new canonical /private/tmp/juice-bend-settings-fixture[-suffix] paths")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
