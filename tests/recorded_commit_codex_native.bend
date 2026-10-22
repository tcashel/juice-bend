import Base
import ./recorded_commit_native.bend as N
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/file_evidence.bend as F
import ../src/json.bend as Json
import ../src/paths.bend as Paths

def content(+repo: String,output: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"codex-recorded-session\",\"cwd\":" ++ Json.quote(repo) ++ ",\"source\":\"cli\"}}\n" ++
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":\"Please commit this Codex change café 中文 🙂.\"}]}}\n" ++
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"custom_tool_call\",\"call_id\":\"unrelated\",\"name\":\"functions.exec\",\"input\":\"return 1\"}}\n" ++
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"custom_tool_call_output\",\"call_id\":\"unrelated\",\"output\":\"1\"}}\n" ++
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call\",\"name\":\"functions.exec_command\",\"call_id\":\"commit-call\",\"arguments\":" ++
    Json.quote("{\"cmd\":\"git commit -m 'codex native fixture'\",\"workdir\":" ++ Json.quote(repo) ++ "}") ++ "}}\n" ++
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"function_call_output\",\"call_id\":\"commit-call\",\"output\":" ++
    Json.quote("{\"exit_code\":0,\"output\":" ++ Json.quote(output) ++ "}") ++ "}}\n"

def native(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  +source = root ++ "/codex.jsonl"
  do IO<Unit>:
    initialized : String <- N.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/change.txt","w","synthetic Codex fixture\n")
    added : String <- N.git(repo,["add","--","change.txt"])
    output : String <- N.git(repo,["commit","-m","codex native fixture"])
    raw_sha : String <- N.git(repo,["rev-parse","HEAD"])
    +sha : String = String.trim(raw_sha)
    +db : U32 <- Store.open(root ++ "/.build/recorded.sqlite")
    Store.write_text(source,"w",content(repo,output))
    +snapshot : String <- Store.import_file(db,"codex",source)
    +why : String <- F.commit_why(db,repo,sha)
    N.assert(String.contains(why,"exact_git_commit_result") && String.contains(why,"Please commit this Codex change café 中文 🙂."),
      "Codex structured exec completion resolves with preceding eligible retained request")
    N.assert(String.contains(why,"functions.exec_command") && String.contains(why,"codex native fixture") &&
      String.contains(why,"\"snapshot\":\"" ++ snapshot ++ "\""),"Codex native path retains separate call result and snapshot citations")
    N.assert(Bool.not(String.contains(why,"incomplete_coverage")),"unrelated custom tool wrapper does not poison verifiable command coverage")
    removed : String <- N.command("/bin/rm",["--",source])
    retained : String <- F.commit_why(db,repo,sha)
    N.assert(String.contains(retained,"exact_git_commit_result"),"Codex command evidence survives original source deletion")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    N.environment(["GIT_DIR","GIT_WORK_TREE","GIT_COMMON_DIR","GIT_INDEX_FILE",
      "GIT_OBJECT_DIRECTORY","GIT_ALTERNATE_OBJECT_DIRECTORIES","GIT_CONFIG",
      "GIT_CONFIG_PARAMETERS","GIT_CONFIG_COUNT","GIT_TEMPLATE_DIR","GIT_SHALLOW_FILE","GIT_NAMESPACE"])
    cwd : String <- IO.try(String,IO.get_env("PWD"))
    +root : String <- Paths.resolve(cwd)
    Store.checked(String.contains(root,"juice-bend-test-recorded_commit_codex_native."),"Synthetic Codex fixture requires its isolated test directory")
    native(root)
