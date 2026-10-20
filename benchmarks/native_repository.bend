import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ../src/provenance.bend as P
import ../src/repository_browser.bend as Browser
import ../tests/file_evidence.bend as Fixture

# Synthetic native browser fixture. No personal histories or existing checkout
# are accepted. Creation requires a new directory; advance requires its exact
# immutable marker and pristine pinned repository. No shell is invoked.
def checked(ok: Bool,message: String) -> IO(Unit):
  Store.checked(ok,"Native repository fixture: " ++ message)

def leaf_parts(parts: List<&2,String>) -> String:
  match parts:
    case name <> _:
      name
    case []:
      ""

def leaf(path: String) -> String:
  leaf_parts(List.reverse(&2,String,String.split(path,'/')))

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
  +name = leaf(path)
  String.starts_with(path,"/") && Nat.is_le(String.length(path),4000n) &&
    String.starts_with(name,"juice-bend-repository-fixture") &&
    Nat.is_le(String.length(name),100n) && name_chars(name) &&
    Bool.not(String.contains(path,"\0"))

def command(program: String,args: List<String>) -> IO(String):
  Fixture.command(program,args)

def environment_value(result: Result<&1,&1,U32 & String,String>) -> IO(Unit):
  match result:
    case Fail{_}:
      IO.pure(Unit,Unit{})
    case Done{value}:
      checked(String.is_empty(value),"Git environment override is set; refusing a redirected fixture")

def environment(names: List<&2,String>) -> IO(Unit):
  match names:
    case []:
      IO.pure(Unit,Unit{})
    case name <> rest:
      do IO<Unit>:
        value : Result<&1,&1,U32 & String,String> <- IO.get_env(name)
        environment_value(value)
        environment(rest)

def git(+repo: String,args: List<String>) -> IO(String):
  Fixture.git(repo,"--no-replace-objects" <> "--no-lazy-fetch" <> "--literal-pathspecs" <>
    "--git-dir" <> (repo ++ "/.git") <> "--work-tree" <> repo <>
    "-c" <> "core.attributesFile=/dev/null" <> "-c" <> "core.excludesFile=/dev/null" <>
    "-c" <> "diff.external=" <> args)

def directory(path: String) -> IO(Unit):
  do IO<Unit>:
    made : String <- command("/bin/mkdir",["-m","700","--",path])
    return Unit{}

def octal(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+c},rest}:
      U32.is_ge(c,48) && U32.is_le(c,55) && octal(rest)

def mode_valid(+mode: String,is_directory: Bool) -> Bool:
  octal(mode) && Bool.pick(Bool,is_directory,
    Nat.is_eq(String.length(mode),5n) && String.starts_with(mode,"40"),
    Nat.is_eq(String.length(mode),6n) && String.starts_with(mode,"10"))

def regular_path(+path: String,is_directory: Bool) -> IO(Unit):
  do IO<Unit>:
    mode : String <- command("/usr/bin/stat",["-q","-f","%Op","--",path])
    checked(mode_valid(String.trim(mode),is_directory),"refusing a symlink or unexpected file type")
    canonical : String <- Paths.resolve(path)
    checked(String.eq(path,canonical),"refusing a noncanonical or traversed path")

def read_finished(result: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,text) = result
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,text))

def read_small(+path: String) -> IO(String):
  do IO<String>:
    regular_path(path,False{})
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,String> <- File.read(file,16384)
    read_finished(result)

def source_path() -> String:
  "source café.txt"

def rows(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+rest:
      "let row_" ++ U32.show(index) ++ " = " ++ U32.show(index) ++ "\n" ++ rows(rest,U32.inc(index))

def content(first: String,last: String) -> String:
  "let alpha = " ++ first ++ "\n" ++ rows(128n,2) ++ "let omega = " ++ last ++ "\n"

def files(fuel: Nat,+root: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Store.write_text(root ++ "/file-" ++ U32.show(index) ++ ".txt","w","Synthetic browser child " ++ U32.show(index) ++ "\n")
        files(rest,root,U32.inc(index))

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(result)

def commit(+repo: String,message: String) -> IO(String):
  do IO<String>:
    staged : String <- git(repo,["add","--all","--","."])
    made : String <- git(repo,["commit","--quiet","-m",message])
    +id : String <- git(repo,["rev-parse","HEAD"])
    checked(P.valid_sha(String.trim(id)),"commit identity is not SHA-1")
    return String.trim(id)

def capture(+repo: String,+session: String,request: String,text: String,time: String) -> String:
  Fixture.request(repo,session,request) ++
    "{\"type\":\"assistant\",\"sessionId\":" ++ Json.quote(session) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"timestamp\":" ++ Json.quote(time) ++ ",\"message\":{\"model\":\"synthetic-recorded-model\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"id\":\"write-source\",\"input\":{\"file_path\":" ++
    Json.quote(source_path()) ++ ",\"content\":" ++ Json.quote(text) ++ "}}]}}\n"

def marker_path(root: String) -> String:
  root ++ "/.juice-bend-repository-fixture-v1"

def description(+root: String,base: String,pinned: String,+first: String,+second: String) -> String:
  "{\"fixture\":\"juice-bend-repository-fixture-v1\",\"root\":" ++ Json.quote(root) ++
    ",\"repository\":" ++ Json.quote(root ++ "/repository") ++
    ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"base_commit\":" ++ Json.quote(base) ++
    ",\"commit\":" ++ Json.quote(pinned) ++ ",\"path\":" ++ Json.quote(source_path()) ++
    ",\"first_snapshot\":" ++ Json.quote(first) ++ ",\"second_snapshot\":" ++ Json.quote(second) ++
    ",\"snapshots\":[" ++ Json.quote(first) ++ "," ++ Json.quote(second) ++ "]}"

def need(-A: Kind(&2),result: Result<&2,&2,Browser.Problem,A>) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{problem}:
      IO.die(A,1,"Native repository fixture: " ++ Browser.problem_text(problem))

def verify_page(value: Browser.Source,pinned: String) -> IO(Unit):
  Browser.Source{id,path,_,_,total,start,lines,next,_} = value
  checked(String.eq(id,pinned) && String.eq(path,source_path()) && U32.is_eq(total,130) &&
    U32.is_eq(start,101) && Nat.is_eq(List.length(&2,Browser.Line,lines),30n),"late source page differs from fixture")

def verify_directory(value: Browser.Directory) -> IO(Unit):
  Browser.Directory{_,_,nodes,total,_} = value
  checked(U32.is_eq(total,107) && Nat.is_eq(List.length(&2,Browser.Node,nodes),7n),"second directory page differs from fixture")

def verify(+db: U32,+repo: String,+pinned: String) -> IO(Unit):
  do IO<Unit>:
    opened : Result<&2,&2,Browser.Problem,Browser.View> <- Browser.open_at(repo,pinned)
    +view : Browser.View <- need(Browser.View,opened)
    page_result : Result<&2,&2,Browser.Problem,Browser.Source> <- Browser.source(view,source_path(),101,100)
    page : Browser.Source <- need(Browser.Source,page_result)
    verify_page(page,pinned)
    directory_result : Result<&2,&2,Browser.Problem,Browser.Directory> <- Browser.children(view,"many",100,100)
    directory : Browser.Directory <- need(Browser.Directory,directory_result)
    verify_directory(directory)
    why_result : Result<&2,&2,Browser.Problem,String> <- Browser.evidence(db,view,source_path(),1,3,True{})
    +why : String <- need(String,why_result)
    checked(String.contains(why,"exact") && String.contains(why,"Update the first and last calculations") &&
      String.contains(why,"Create the first synthetic source") &&
      String.contains(why,"\"snapshot\":\"1\"") &&
      String.contains(why,"\"snapshot\":\"2\""),"captured requests from both commits were not resolved")

def prepare(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  do IO<Unit>:
    directory(root)
    regular_path(root,True{})
    directory(repo)
    directory(root ++ "/library")
    directory(root ++ "/captures")
    initialized : String <- git(repo,["-c","init.defaultBranch=main","init","--quiet","--template="])
    directory(repo ++ "/many")
    directory(repo ++ "/nested space")
    files(107n,repo ++ "/many",0)
    Store.write_text(repo ++ "/nested space/hello 中文.txt","w","Synthetic Unicode child.\n")
    write_bytes(repo ++ "/binary.dat",[0,1,2,3,255])
    linked : String <- command("/bin/ln",["-s",source_path(),repo ++ "/symbolic"])
    Store.write_text(repo ++ "/" ++ source_path(),"w",content("1","1"))
    +base : String <- commit(repo,"Create synthetic repository source\n\nClaude-Session: repository-session-0001")
    Store.write_text(root ++ "/captures/first.jsonl","w",capture(repo,"repository-session-0001",
      "Create the first synthetic source with numbered calculations.",content("1","1"),"2026-10-20T12:00:00Z"))
    Store.write_text(repo ++ "/" ++ source_path(),"w",content("42","99"))
    +pinned : String <- commit(repo,"Update synthetic repository source\n\nClaude-Session: repository-session-0002")
    Store.write_text(root ++ "/captures/second.jsonl","w",capture(repo,"repository-session-0002",
      "Update the first and last calculations while retaining the middle lines.",content("42","99"),"2026-10-20T12:01:00Z"))
    +db : U32 <- Store.open(root ++ "/library/juice-bend.sqlite")
    +first : String <- Store.import_file(db,"claude",root ++ "/captures/first.jsonl")
    +second : String <- Store.import_file(db,"claude",root ++ "/captures/second.jsonl")
    checked(String.eq(first,"1") && String.eq(second,"2"),"fixture did not create exactly its first two captures")
    verify(db,repo,pinned)
    IO.try(Unit,Sql.close(db))
    Store.write_text(marker_path(root),"w",description(root,base,pinned,first,second) ++ "\n")
    protected : String <- command("/bin/chmod",["400",marker_path(root)])
    IO.print(description(root,base,pinned,first,second))

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{_}:
      IO.die(Json.Json,1,"Native repository fixture: invalid marker JSON")

def advance_marked(+root: String,+marker: String,+data: Json.Json) -> IO(Unit):
  +repo = root ++ "/repository"
  +base = Json.get(data,"base_commit")
  +pinned = Json.get(data,"commit")
  do IO<Unit>:
    checked(P.valid_sha(base) && P.valid_sha(pinned) &&
      String.eq(marker,description(root,base,pinned,"1","2") ++ "\n"),"marker content or exact paths do not match this fixture")
    regular_path(repo,True{})
    regular_path(repo ++ "/.git",True{})
    current : String <- git(repo,["rev-parse","HEAD"])
    checked(String.eq(String.trim(current),pinned),"HEAD already changed; refusing another advance")
    status : String <- git(repo,["status","--porcelain","--untracked-files=all"])
    checked(String.is_empty(status),"repository is not pristine; refusing to overwrite work")
    original : String <- read_small(repo ++ "/" ++ source_path())
    checked(String.eq(original,content("42","99")),"source is not the fixture's pinned content")
    Store.write_text(repo ++ "/" ++ source_path(),"w",content("314","271"))
    +advanced : String <- commit(repo,"Uncaptured third synthetic commit")
    Store.write_text(repo ++ "/" ++ source_path(),"w",content("999","777"))
    changed : String <- git(repo,["status","--porcelain","--",source_path()])
    checked(Bool.not(String.is_empty(changed)) && Bool.not(String.eq(advanced,pinned)),"advance did not change HEAD and dirty the worktree")
    old_source : String <- git(repo,["show",pinned ++ ":" ++ source_path()])
    checked(String.eq(old_source,content("42","99")),"original pinned commit source changed")
    IO.print("{\"root\":" ++ Json.quote(root) ++ ",\"repository\":" ++ Json.quote(repo) ++
      ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"commit\":" ++ Json.quote(pinned) ++
      ",\"advanced_commit\":" ++ Json.quote(advanced) ++ ",\"path\":" ++ Json.quote(source_path()) ++
      ",\"snapshots\":[\"1\",\"2\"],\"dirty\":true}")

def advance(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"invalid synthetic root basename")
    regular_path(root,True{})
    +marker : String <- read_small(marker_path(root))
    data : Json.Json <- parsed(Json.parse(marker))
    advance_marked(root,marker,data)

def fixture(path: String) -> IO(Unit):
  do IO<Unit>:
    +root : String <- Paths.destination(path)
    checked(root_shape(root),"new root must use the juice-bend-repository-fixture basename")
    prepare(root)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []:
      fixture(root)
    case _ <> "advance" <> root <> []:
      advance(root)
    case _:
      IO.die(Unit,2,"Usage: native-repository fixture NEW_ROOT | advance ROOT")

def main() -> IO(Unit):
  do IO<Unit>:
    environment(["GIT_DIR","GIT_WORK_TREE","GIT_COMMON_DIR","GIT_INDEX_FILE",
      "GIT_OBJECT_DIRECTORY","GIT_ALTERNATE_OBJECT_DIRECTORIES","GIT_CONFIG",
      "GIT_CONFIG_PARAMETERS","GIT_CONFIG_COUNT","GIT_TEMPLATE_DIR","GIT_SHALLOW_FILE"])
    args : List<String> <- IO.args()
    arguments(args)
