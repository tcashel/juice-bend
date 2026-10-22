import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ../src/domain.bend as Domain
import ../src/maintenance.bend as Maintenance
import ../src/activity_reader.bend as Reader
import ../src/tool_activity.bend as Activity
import ../src/scoped_reader.bend as Scoped

# Synthetic native Tools fixture. Every mutation is under a newly created,
# canonical private root. Advance/hide require its exact marker, source bytes,
# single-link ordinary files, and expected captured database state. No shell,
# personal history, source deletion, or recorded command execution is involved.
def checked(ok: Bool,message: String) -> IO(Unit):
  Store.checked(ok,"Native activity fixture: " ++ message)

def need(-A: Kind(&2),result: Result<&2,&2,String,A>) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{message}:
      IO.die(A,1,"Native activity fixture: " ++ message)

def command_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Done{(0,(out,_))}:
      IO.pure(String,out)
    case _:
      IO.die(String,1,"Native activity fixture: OS primitive failed")

def command(program: String,args: List<String>) -> IO(String):
  do IO<String>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,args,"",8192,10000)
    command_result(result)

def test_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Bool):
  match result:
    case Done{(0,_)}:
      IO.pure(Bool,True{})
    case Done{(1,_)}:
      IO.pure(Bool,False{})
    case _:
      IO.die(Bool,1,"Native activity fixture: path existence could not be checked")

def test(flag: String,path: String) -> IO(Bool):
  do IO<Bool>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/test",[flag,path],"",1024,2000)
    test_result(result)

def leaf_parts(parts: List<&2,String>) -> String:
  match parts:
    case name <> _:
      name
    case []:
      ""

def name_chars(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+c},rest}:
      ((U32.is_ge(c,48) && U32.is_le(c,57)) ||
       (U32.is_ge(c,65) && U32.is_le(c,90)) ||
       (U32.is_ge(c,97) && U32.is_le(c,122)) ||
       U32.is_eq(c,45) || U32.is_eq(c,46) || U32.is_eq(c,95)) && name_chars(rest)

def root_shape(+path: String) -> Bool:
  +name = leaf_parts(List.reverse(&2,String,String.split(path,'/')))
  String.starts_with(path,"/") && Nat.is_le(String.length(path),4000n) &&
    (String.eq(name,"juice-bend-activity-fixture") ||
     String.starts_with(name,"juice-bend-activity-fixture-")) &&
    Nat.is_le(String.length(name),100n) && name_chars(name) &&
    Bool.not(String.contains(path,"\0"))

def regular_path(+path: String,is_directory: Bool) -> IO(Unit):
  do IO<Unit>:
    +mode : String <- command("/usr/bin/stat",["-q","-f","%Op|%l","--",path])
    checked(Bool.pick(Bool,is_directory,String.starts_with(mode,"40700|"),
      String.eq(String.trim(mode),"100600|1") || String.eq(String.trim(mode),"100400|1")),
      "refusing a symlink, hard-linked file, public directory, or unexpected file type/mode")
    canonical : String <- Paths.resolve(path)
    checked(String.eq(path,canonical),"refusing a noncanonical or traversed path")

def absent(+path: String) -> IO(Unit):
  do IO<Unit>:
    exists : Bool <- test("-e",path)
    linked : Bool <- test("-L",path)
    checked(Bool.not(exists) && Bool.not(linked),"destination already exists")

def optional_file_present(exists: Bool,path: String) -> IO(Unit):
  match exists:
    case False{}:
      IO.pure(Unit,Unit{})
    case True{}:
      regular_path(path,False{})

def optional_file(+path: String) -> IO(Unit):
  do IO<Unit>:
    linked : Bool <- test("-L",path)
    checked(Bool.not(linked),"refusing a database sidecar symlink")
    exists : Bool <- test("-e",path)
    optional_file_present(exists,path)

def directory(path: String) -> IO(Unit):
  do IO<Unit>:
    out : String <- command("/bin/mkdir",["-m","700","--",path])
    return Unit{}

def private_file(path: String,mode: String) -> IO(Unit):
  do IO<Unit>:
    out : String <- command("/bin/chmod",[mode,path])
    return Unit{}

def read_finished(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,bytes) = result
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,bytes))

def exact_file(+path: String,text: String) -> IO(Unit):
  do IO<Unit>:
    regular_path(path,False{})
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65536)
    bytes : List<&2,U32> <- read_finished(got)
    checked(Domain.bytes_equal(bytes,Domain.encode(text)),"file bytes differ from the exact synthetic fixture")

def source(root: String) -> String:
  root ++ "/captures/activity.jsonl"

def database(root: String) -> String:
  root ++ "/library/juice-bend.sqlite"

def marker_path(root: String) -> String:
  root ++ "/.juice-bend-activity-fixture-v1"

def description(+root: String) -> String:
  "{\"fixture\":\"juice-bend-activity-fixture-v1\",\"root\":" ++ Json.quote(root) ++
    ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"source\":" ++ Json.quote(source(root)) ++
    ",\"session\":\"activity-fixture-session\",\"repository\":\"/synthetic/activity\"," ++
    "\"first_snapshot\":\"1\",\"first_records\":43,\"second_snapshot\":\"2\",\"second_records\":45}"

def record(role: String,content: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"sessionId\":\"activity-fixture-session\"," ++
    "\"cwd\":\"/synthetic/activity\",\"timestamp\":\"2026-10-20T12:00:00Z\"," ++
    "\"message\":{\"content\":[" ++ content ++ "]}}\n"

def text(role: String,body: String) -> String:
  record(role,"{\"type\":\"text\",\"text\":" ++ Json.quote(body) ++ "}")

def call(id: String,argument: String) -> String:
  record("assistant","{\"type\":\"tool_use\",\"name\":\"Bash\",\"id\":" ++ Json.quote(id) ++
    ",\"input\":{\"command\":" ++ Json.quote(argument) ++ "}}")

def result(id: String,body: String,error: Bool) -> String:
  record("user","{\"type\":\"tool_result\",\"tool_use_id\":" ++ Json.quote(id) ++
    ",\"content\":" ++ Json.quote(body) ++ ",\"is_error\":" ++ Bool.pick(String,error,"true","false") ++ "}")

def filler(fuel: Nat,+ordinal: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+rest:
      text("assistant","Synthetic ordinary filler record " ++ U32.show(ordinal)) ++ filler(rest,U32.inc(ordinal))

def initial() -> String:
  text("user","activityneedle — inspect the retained synthetic tool activity.") ++
    call("alpha","printf 'café 中文 🙂' — captured text only, never executed") ++
    result("alpha","alpha result café 中文 🙂",False{}) ++ filler(35n,3) ++
    call("boundary","boundary argument at physical record 38") ++
    text("assistant","Physical record 39 separates the boundary call and result across pages.") ++
    result("boundary","boundary result at physical record 40",False{}) ++
    call("failure","failure argument at physical record 41") ++
    result("failure","synthetic failure: permission denied",True{})

def appended() -> String:
  call("delta","delta argument added after the first accepted snapshot") ++
    result("delta","delta result added in snapshot 2",False{})

def scope() -> Scoped.Scope:
  Scoped.Scope{"","","",""}

def counts(page: Reader.Page) -> String:
  Reader.Page{_,_,_,_,_,_,_,_,_,_,_,Activity.Page{_,Activity.Stats{events,calls,results,pairs,errors,coverage,unpaired}}} = page
  String.join([U32.show(events),U32.show(calls),U32.show(results),U32.show(pairs),U32.show(errors),U32.show(coverage),U32.show(unpaired)],"|")

def page_metadata(value: Reader.Page,root: String,+snapshot: String,total: U32,start: U32,+selected: U32) -> Bool:
  Reader.Page{provider,locator,generation,id,extent,records,offset,requested,size,verified,_,_} = value
  +expected_extent = U32.from_nat(List.length(&2,U32,Domain.encode(
    Bool.pick(String,String.eq(snapshot,"1"),initial(),initial() ++ appended()))))
  String.eq(provider,"claude") && String.eq(locator,source(root)) && String.eq(generation,"1") &&
    String.eq(id,snapshot) && U32.is_eq(extent,expected_extent) && U32.is_eq(records,total) && U32.is_eq(offset,start) &&
    U32.is_eq(requested,40) && U32.is_eq(size,selected) && U32.is_eq(verified,selected)

def page(+db: U32,+root: String,+snapshot: String,+total: U32,+start: U32,+selected: U32,expected: String) -> IO(String):
  do IO<String>:
    read : Result<&2,&2,String,Reader.Page> <- Reader.read(db,snapshot,start,40,scope())
    +value : Reader.Page <- need(Reader.Page,read)
    checked(page_metadata(value,root,snapshot,total,start,selected),"activity page identity or physical range differs")
    checked(String.eq(counts(value),expected),"activity counts or page-local pair states differ")
    need(String,Reader.render(value))

def verify_old(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    +first : String <- page(db,root,"1",43,0,40,"40|2|1|1|0|0|1")
    +last : String <- page(db,root,"1",43,40,3,"3|1|2|1|1|0|1")
    checked(String.contains(first,"café 中文 🙂") && String.contains(first,"alpha result") &&
      String.contains(first,"Unique counterpart") && String.contains(first,"boundary argument") &&
      String.contains(first,"counterpart is not in this selected page") &&
      Bool.not(String.contains(first,"boundary result")),"first page lost Unicode, exact arguments, result, or boundary gap")
    checked(String.contains(last,"boundary result") && String.contains(last,"synthetic failure: permission denied") &&
      String.contains(last,"Recorded tool_error: true") && String.contains(last,"counterpart is not in this selected page") &&
      Bool.not(String.contains(last,"boundary argument")) && Bool.not(String.contains(last,"delta")),
      "late old page lost explicit error/boundary coverage or acquired a future event")

def verify_new(+db: U32,root: String) -> IO(Unit):
  do IO<Unit>:
    +text : String <- page(db,root,"2",45,40,5,"5|2|3|2|1|0|1")
    checked(String.contains(text,"delta argument added") && String.contains(text,"delta result added"),
      "new snapshot did not retain both appended tool occurrences")

def scalar(+db: U32,query: String,bindings: List<&2,Sql.Cell>,expected: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,query,bindings,1)
    checked(String.eq(Store.field(Store.first(rows),0n),expected),"database state differs from the owned fixture")

def captured_bytes(rows: List<&2,List<&2,Sql.Cell>>) -> Result<&2,&2,String,List<&2,U32>>:
  match rows:
    case []:
      Done{[]}
    case (Sql.Cell.Blob{bytes} <> []) <> rest:
      do Result<&2,&2,String,List<&2,U32>>:
        tail : List<&2,U32> <- captured_bytes(rest)
        return List.append(&2,U32,bytes,tail)
    case _:
      Fail{"captured raw fixture contains a non-BLOB row"}

def exact_capture(+db: U32,snapshot: String,text: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.bytes FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal LIMIT 46",
      [Sql.Cell.Integer{snapshot}],46)
    bytes : List<&2,U32> <- need(List<&2,U32>,captured_bytes(rows))
    checked(Domain.bytes_equal(bytes,Domain.encode(text)),"captured raw bytes differ from the exact synthetic fixture")

def state(+db: U32,+root: String,+latest: String,+records: U32) -> IO(Unit):
  do IO<Unit>:
    scalar(db,"PRAGMA user_version",[],"2")
    scalar(db,"PRAGMA quick_check",[],"ok")
    scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    scalar(db,"SELECT count(*) FROM sources",[],"1")
    scalar(db,"SELECT count(*) FROM sources WHERE id=1 AND provider='claude' AND locator=? AND latest=?",
      [Sql.Cell.Text{source(root)},Sql.Cell.Integer{latest}],"1")
    scalar(db,"SELECT count(*) FROM generations WHERE id=1 AND source=1",[],"1")
    scalar(db,"SELECT count(*) FROM generations",[],"1")
    scalar(db,"SELECT count(*) FROM snapshots",[],latest)
    scalar(db,"SELECT count(*) FROM snapshots WHERE id=1 AND generation=1 AND accepted=1 AND records=43",[],"1")
    scalar(db,"SELECT count(*) FROM raw",[],U32.show(records))
    scalar(db,"SELECT count(*) FROM records",[],Bool.pick(String,String.eq(latest,"1"),"43","88"))
    scalar(db,"SELECT count(*) FROM events",[],Bool.pick(String,String.eq(latest,"1"),"43","88"))
    scalar(db,"SELECT count(*) FROM search",[],U32.show(records))
    Maintenance.verify(db,"1")
    exact_capture(db,"1",initial())
    verify_old(db,root)

def owned(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"invalid absolute synthetic root basename")
    regular_path(root,True{})
    exact_file(marker_path(root),description(root) ++ "\n")
    regular_path(root ++ "/captures",True{})
    regular_path(root ++ "/library",True{})
    regular_path(database(root),False{})
    optional_file(database(root) ++ "-wal")
    optional_file(database(root) ++ "-shm")
    optional_file(database(root) ++ "-journal")

def prepare(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"new root must be absolute with juice-bend-activity-fixture basename and optional safe suffix")
    canonical : String <- Paths.destination(root)
    checked(String.eq(canonical,root),"new root's parent must already be canonical")
    directory(root)
    regular_path(root,True{})
    directory(root ++ "/captures")
    directory(root ++ "/library")
    Store.write_text(source(root),"w",initial())
    private_file(source(root),"600")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    private_file(database(root),"600")
    Store.schema(db)
    +snapshot : String <- Store.import_file(db,"claude",source(root))
    checked(String.eq(snapshot,"1"),"initial capture did not create snapshot 1")
    state(db,root,"1",43)
    IO.try(Unit,Sql.close(db))
    Store.write_text(marker_path(root),"w",description(root) ++ "\n")
    private_file(marker_path(root),"400")
    IO.print(description(root))

def advance(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    exact_file(source(root),initial())
    absent(source(root) ++ ".retained")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    state(db,root,"1",43)
    Store.write_text(source(root),"a",appended())
    exact_file(source(root),initial() ++ appended())
    Store.schema(db)
    +snapshot : String <- Store.import_file(db,"claude",source(root))
    checked(String.eq(snapshot,"2"),"append did not create snapshot 2")
    state(db,root,"2",45)
    Maintenance.verify(db,"2")
    exact_capture(db,"2",initial() ++ appended())
    verify_new(db,root)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"advanced\":true,\"root\":" ++ Json.quote(root) ++ ",\"snapshots\":[\"1\",\"2\"],\"records\":[43,45]}")

# Pause app automatic refresh before this command when proving that a later
# manual GUI Refresh publishes the append. The original standalone capture is
# already eligible for refresh; this command registers no source root and calls
# neither Store.schema nor Store.import_file. The reader connection closes
# before the synthetic source append, so it cannot hold a read transaction over
# the app's subsequent capture.
def append_only(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    exact_file(source(root),initial())
    absent(source(root) ++ ".retained")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    state(db,root,"1",43)
    IO.try(Unit,Sql.close(db))
    exact_file(source(root),initial())
    Store.write_text(source(root),"a",appended())
    exact_file(source(root),initial() ++ appended())
    IO.print("{\"appended_only\":true,\"root\":" ++ Json.quote(root) ++
      ",\"source_records\":45,\"prior_snapshot\":\"1\",\"prior_records\":43,\"capture_requested\":false}")

def hide(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    exact_file(source(root),initial() ++ appended())
    absent(source(root) ++ ".retained")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    state(db,root,"2",45)
    Maintenance.verify(db,"2")
    exact_capture(db,"2",initial() ++ appended())
    verify_new(db,root)
    moved : String <- command("/bin/mv",["-n",source(root),source(root) ++ ".retained"])
    absent(source(root))
    exact_file(source(root) ++ ".retained",initial() ++ appended())
    verify_old(db,root)
    verify_new(db,root)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"hidden\":true,\"root\":" ++ Json.quote(root) ++ ",\"retained_source\":" ++
      Json.quote(source(root) ++ ".retained") ++ ",\"snapshots\":[\"1\",\"2\"],\"records\":[43,45]}")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []:
      prepare(root)
    case _ <> "advance" <> root <> []:
      advance(root)
    case _ <> "append-only" <> root <> []:
      append_only(root)
    case _ <> "hide" <> root <> []:
      hide(root)
    case _:
      IO.die(Unit,2,"Usage: native-activity fixture NEW_ROOT | advance ROOT | append-only ROOT | hide ROOT (after snapshot 2 is captured)")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
