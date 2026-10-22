import Base
import ./recorded_commit_native.bend as N
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/file_evidence.bend as F
import ../src/json.bend as Json
import ../src/paths.bend as Paths

def filler(fuel: Nat) -> String:
  match fuel:
    case 0n: ""
    case 1n+n: "{\"type\":\"system\",\"content\":\"synthetic context\"}\n" ++ filler(n)

def late(+repo: String,+session: String,excluded: Bool,output: String) -> String:
  "{\"type\":\"system\",\"sessionId\":" ++ Json.quote(session) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"excluded\":" ++ Bool.pick(String,excluded,"true","false") ++ ",\"content\":\"synthetic header\"}\n" ++
    filler(15n) ++ N.request(repo,session,"Please commit the retained late request.") ++
    N.call("git commit -m late","late-call") ++ N.result(output,"late-call","false")

def native(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  do IO<Unit>:
    initialized : String <- N.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/change.txt","w","synthetic coverage fixture\n")
    added : String <- N.git(repo,["add","--","change.txt"])
    +output : String <- N.git(repo,["commit","-m","coverage fixture"])
    raw_sha : String <- N.git(repo,["rev-parse","HEAD"])
    +sha : String = String.trim(raw_sha)
    +db : U32 <- Store.open(root ++ "/.build/recorded.sqlite")
    Store.write_text(root ++ "/early.jsonl","w",N.request(repo,"early-session","Please commit this captured change.") ++
      N.call("git commit -m early","early-call") ++ N.result(output,"early-call","false"))
    first : String <- Store.import_file(db,"claude",root ++ "/early.jsonl")
    early : String <- F.commit_why(db,repo,sha)
    N.assert(String.contains(early,"exact_git_commit_result"),"early eligible request establishes initial unique recorded evidence")
    Store.write_text(root ++ "/excluded.jsonl","w",late(repo,"excluded-session",True{},output))
    excluded : String <- Store.import_file(db,"claude",root ++ "/excluded.jsonl")
    after_excluded : String <- F.commit_why(db,repo,sha)
    N.assert(String.contains(after_excluded,"exact_git_commit_result"),"explicit excluded late request does not become incomplete eligible coverage")
    Store.write_text(root ++ "/other.jsonl","w",late("/synthetic/other","other-session",False{},output))
    other : String <- Store.import_file(db,"claude",root ++ "/other.jsonl")
    after_other : String <- F.commit_why(db,repo,sha)
    N.assert(String.contains(after_other,"exact_git_commit_result"),"known other-repository late request stays outside selected coverage")
    Store.write_text(root ++ "/late.jsonl","w",late(repo,"late-session",False{},output))
    last : String <- Store.import_file(db,"claude",root ++ "/late.jsonl")
    +after_late : String <- F.commit_why(db,repo,sha)
    N.assert(String.contains(after_late,"incomplete_coverage") && String.contains(after_late,"first 16 retained records") &&
      Bool.not(String.contains(after_late,"exact_git_commit_result")),"second same-repository command hidden by context bound prevents false unique claim")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    N.environment(["GIT_DIR","GIT_WORK_TREE","GIT_COMMON_DIR","GIT_INDEX_FILE",
      "GIT_OBJECT_DIRECTORY","GIT_ALTERNATE_OBJECT_DIRECTORIES","GIT_CONFIG",
      "GIT_CONFIG_PARAMETERS","GIT_CONFIG_COUNT","GIT_TEMPLATE_DIR","GIT_SHALLOW_FILE","GIT_NAMESPACE"])
    cwd : String <- IO.try(String,IO.get_env("PWD"))
    +root : String <- Paths.resolve(cwd)
    Store.checked(String.contains(root,"juice-bend-test-recorded_commit_coverage_native."),"Synthetic coverage fixture requires its isolated test directory")
    native(root)
