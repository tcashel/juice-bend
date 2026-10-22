import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/file_evidence.bend as F
import ../src/recorded_commit_git.bend as Git
import ../src/evidence.bend as Evidence
import ../src/json.bend as Json
import ../src/paths.bend as Paths

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def command_result(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match value:
    case Done{(0,(text,_))}: IO.pure(String,text)
    case _: IO.die(String,1,"Synthetic fixture command failed")

def command(program: String,args: List<String>) -> IO(String):
  do IO<String>:
    value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(program,args,"",65536,10000)
    command_result(value)

def git(+repo: String,args: List<String>) -> IO(String):
  command("/usr/bin/git","-C" <> repo <> "--no-replace-objects" <> "--no-lazy-fetch" <>
    "--literal-pathspecs" <> "--git-dir" <> (repo ++ "/.git") <> "--work-tree" <> repo <> "-c" <> "user.name=Synthetic" <>
    "-c" <> "user.email=fixture@example.invalid" <> "-c" <> "commit.gpgSign=false" <>
    "-c" <> "core.hooksPath=/dev/null" <> "-c" <> "core.fsmonitor=false" <>
    "-c" <> "core.attributesFile=/dev/null" <> "-c" <> "core.excludesFile=/dev/null" <> args)

def request(repo: String,session: String,text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(session) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":" ++ Json.quote(text) ++ "}}\n"

def call(text: String,id: String) -> String:
  "{\"type\":\"assistant\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Bash\",\"id\":" ++
    Json.quote(id) ++ ",\"input\":{\"command\":" ++ Json.quote(text) ++ "}}]}}\n"

def result(text: String,id: String,error: String) -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":" ++
    Json.quote(id) ++ ",\"is_error\":" ++ error ++ ",\"content\":" ++ Json.quote(text) ++ "}]}}\n"

def resolution(value: Git.Resolution) -> String:
  Git.Resolution{state,_} = value
  state

def cited(value: Result<&2,&2,String,String>,needle: String) -> Bool:
  match value:
    case Done{text}: String.contains(text,needle)
    case Fail{_}: False{}

def environment_value(value: Result<&1,&1,U32 & String,String>) -> IO(Unit):
  match value:
    case Fail{_}: IO.pure(Unit,Unit{})
    case Done{text}: Store.checked(String.is_empty(text),"Synthetic fixture refuses Git environment overrides")

def environment(names: List<&2,String>) -> IO(Unit):
  match names:
    case []: IO.pure(Unit,Unit{})
    case name <> rest:
      do IO<Unit>:
        value : Result<&1,&1,U32 & String,String> <- IO.get_env(name)
        environment_value(value)
        environment(rest)

def native(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  +source = root ++ "/recorded.jsonl"
  do IO<Unit>:
    initialized : String <- command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/change.txt","w","independent synthetic content\n")
    added : String <- git(repo,["add","--","change.txt"])
    +commit_output : String <- git(repo,["commit","-m","recorded native fixture"])
    raw_sha : String <- git(repo,["rev-parse","HEAD"])
    +sha : String = String.trim(raw_sha)
    +content : String = request(repo,"recorded-session-0001","Please prepare the repository.") ++
      request(repo,"recorded-session-0001","Please commit this exact retained change café 中文 🙂.") ++
      call("git commit -m 'recorded native fixture'","call-1") ++ result(commit_output,"call-1","false")
    Store.write_text(source,"w",content)
    +db : U32 <- Store.open(root ++ "/.build/recorded.sqlite")
    +snapshot : String <- Store.import_file(db,"claude",source)
    +why : String <- F.commit_why(db,repo,sha)
    assert(String.contains(why,"exact_git_commit_result"),"actual Git success resolves exact retained command")
    assert(String.contains(why,"Please commit this exact retained change café 中文 🙂."),"nearest preceding eligible request quoted")
    assert(String.contains(why,"\"snapshot\":\"" ++ snapshot ++ "\"") && String.contains(why,"Call citation:") &&
      String.contains(why,"Result citation:") && String.contains(why,"Request citation:"),"separate immutable request call result citations")
    assert(String.contains(why,"not proof of sole authorship"),"recorded evidence never claims sole authorship")
    assert(String.contains(why,"Retained command call (verified excerpt") &&
      String.contains(why,"git commit -m 'recorded native fixture'") && String.contains(why,commit_output),
      "exact retained call and successful output are readable after citation revalidation")
    +record : Evidence.Verified <- Evidence.read_record(db,snapshot,2)
    +call_key : String = Evidence.citation(record,0)
    short : Git.Resolution <- Git.resolve(repo,String.take(sha,7n))
    assert(String.eq(resolution(short),"resolved"),"abbreviated object resolves uniquely in selected repository")
    absent : Git.Resolution <- Git.resolve(repo,"ffffffffffffffffffffffffffffffffffffffff")
    assert(String.eq(resolution(absent),"missing_object"),"missing local Git object is explicit")
    blob_sha : String <- git(repo,["hash-object","-w","--","change.txt"])
    blob : Git.Resolution <- Git.resolve(repo,String.trim(blob_sha))
    assert(String.eq(resolution(blob),"not_commit"),"existing blob cannot masquerade as a commit")
    Store.write_text(source,"a",request(repo,"recorded-session-0001","A later request cannot replace historical evidence."))
    appended : String <- Store.import_file(db,"claude",source)
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,call_key)
    assert(cited(resolved,"git commit -m 'recorded native fixture'"),"historical call citation survives append")
    removed : String <- command("/bin/rm",["--",source])
    +retained : String <- F.commit_why(db,repo,sha)
    assert(String.contains(retained,"exact_git_commit_result") && String.contains(retained,"Please commit this exact retained change"),
      "command and preceding request survive original source loss")
    Store.write_text(root ++ "/quiet.jsonl","w",request(repo,"quiet-session-0001","Record an unrelated quiet command.") ++
      call("git commit --quiet -m quiet","quiet-call") ++ result("","quiet-call","false"))
    quiet : String <- Store.import_file(db,"claude",root ++ "/quiet.jsonl")
    +with_quiet : String <- F.commit_why(db,repo,sha)
    assert(String.contains(with_quiet,"quiet_output") && String.contains(with_quiet,"exact_git_commit_result"),
      "unrelated quiet command is explicit and does not erase verified match")
    Store.write_text(root ++ "/failed.jsonl","w",request(repo,"failed-session-0001","This failed command must not attribute.") ++
      call("git commit -m failed","failed-call") ++ result(commit_output,"failed-call","true"))
    failed : String <- Store.import_file(db,"claude",root ++ "/failed.jsonl")
    +with_failure : String <- F.commit_why(db,repo,sha)
    assert(String.contains(with_failure,"Recorded command state: failed") && String.contains(with_failure,"exact_git_commit_result"),
      "failed success-looking output remains failed and cannot create ambiguity")
    Store.write_text(root ++ "/collision.jsonl","w",request(repo,"collision-session-0001","A distinct captured source records the same commit.") ++
      call("git commit -m collision","other-call") ++ result(commit_output,"other-call","false"))
    collision : String <- Store.import_file(db,"claude",root ++ "/collision.jsonl")
    +ambiguous : String <- F.commit_why(db,repo,sha)
    assert(String.contains(ambiguous,"Recorded commit attribution: ambiguous") && Bool.not(String.contains(ambiguous,"exact_git_commit_result")),
      "distinct captured occurrences resolving same object remain ambiguous")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    environment(["GIT_DIR","GIT_WORK_TREE","GIT_COMMON_DIR","GIT_INDEX_FILE",
      "GIT_OBJECT_DIRECTORY","GIT_ALTERNATE_OBJECT_DIRECTORIES","GIT_CONFIG",
      "GIT_CONFIG_PARAMETERS","GIT_CONFIG_COUNT","GIT_TEMPLATE_DIR","GIT_SHALLOW_FILE","GIT_NAMESPACE"])
    cwd : String <- IO.try(String,IO.get_env("PWD"))
    +root : String <- Paths.resolve(cwd)
    Store.checked(String.contains(root,"juice-bend-test-recorded_commit_native."),"Synthetic recorded commit fixture requires its isolated test directory")
    native(root)
