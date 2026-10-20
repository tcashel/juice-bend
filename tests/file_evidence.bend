import Base
import ../src/file_evidence.bend as F
import ../src/actors.bend as A
import ../src/provenance.bend as P
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ../src/repo_scope.bend as Scope

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def actor(provider: String,id: String,repo: String,parent: String,+key: String,blocked: String) -> A.Actor:
  A.Actor{provider,"/synthetic/source",key,id,repo,parent,"Captured request",key,blocked}

def pure() -> IO(Unit):
  +one = actor("claude","session-alpha-0001","/synthetic/repo","","one","")
  +two = actor("claude","session-alpha-0001","/synthetic/repo","","two","")
  +other = actor("codex","session-alpha-0001","/synthetic/other","","other","")
  +child = actor("claude","child-alpha-0001","/synthetic/repo","session-alpha-0001","child","")
  do IO<Unit>:
    assert(F.trailer("Change\n\nClaude-Session: session-alpha-0001\n",one),"explicit final provider trailer accepted")
    assert(Bool.not(F.trailer("Claude-Session: session-alpha-0001\n\nordinary body",one)),
      "session-looking line outside final trailer block is not exact")
    assert(Bool.not(F.trailer("Codex-Session: session-alpha-0001",one)),
      "provider-specific trailer cannot bind another provider")
    assert(F.body_mention("Discussed with session-alpha-0001.",one),"body mention respects punctuation boundaries")
    assert(Bool.not(F.body_mention("session-alpha-0001-extra",one)),"identifier substring is not body evidence")
    assert(String.eq(P.attribution_name(F.commit_identity("/synthetic/repo",
      "Change\n\nClaude-Session: session-alpha-0001",[one,other])),"exact"),
      "exact identity is scoped to captured repository and provider")
    assert(String.eq(P.attribution_name(F.commit_identity("/synthetic/repo",
      "Change\n\nClaude-Session: session-alpha-0001",[one,two])),"ambiguous"),
      "distinct captured sources with same session ID remain ambiguous")
    assert(String.eq(P.attribution_name(F.commit_identity("/synthetic/repo",
      "Change\n\nClaude-Session: session-alpha-0001\nCodex-Session: uncaptured-session-0001",[one])),"ambiguous"),
      "conflicting explicit trailers remain ambiguous when only one identity is captured")
    assert(String.eq(P.attribution_name(F.commit_attribution(P.Ambiguous{"conflict"},
      P.Probable{"key","mention"},[F.HunkResult{1,1,P.Content{"key",1n,1n}}],1)),"ambiguous"),
      "ambiguous explicit identity cannot become probable or content evidence")
    assert(String.eq(P.attribution_name(F.commit_body("/synthetic/repo",
      "Discussed with session-alpha-0001.",[one])),"probable"),"body-only link remains probable")
    assert(A.allowed(8n,child,[one,child],"/synthetic/repo"),"child inherits eligible unique parent")
    assert(Bool.not(A.allowed(8n,child,[child],"/synthetic/repo")),"orphan child cannot supply evidence")
    assert(Bool.not(A.allowed(8n,child,[one,two,child],"/synthetic/repo")),"ambiguous parent cannot supply evidence")
    assert(Bool.not(A.allowed(8n,child,[actor("claude","session-alpha-0001","/synthetic/repo","","p","excluded"),child],
      "/synthetic/repo")),"excluded parent blocks child evidence")
    assert(Bool.not(A.own_eligible(A.complete_actor(A.Actor{"claude","/synthetic/source","1",
      "juice-benchmark-v1-fixture","/synthetic/repo","","[juice:benchmark-synthetic:v1]\nrequest","key",""}))),
      "synthetic marker and identity are not user-work evidence")
    assert(Bool.not(A.own_eligible(A.complete_actor(A.Actor{"claude","/synthetic/source","1",
      "session-alpha-0001","/synthetic/repo","","## Diagnostic analysis\nrequest","key",""}))),
      "unclassified diagnostic-style prompt fails closed")
    assert(Bool.not(A.own_eligible(A.header_actor(F.parse_json(Json.parse("{\"origin\":\"juiceInternal\"}")),one))),
      "captured diagnostic origin blocks ordinary evidence")
    assert(Bool.not(A.allowed(2n,actor("claude","loop","/synthetic/repo","loop","loop",""),
      [actor("claude","loop","/synthetic/repo","loop","loop","")],"/synthetic/repo")),
      "parent cycle exhausts bounded eligibility without recursion escape")
    assert(String.eq(Scope.normalize(Scope.Scope{"/trees/child","/repo",["/repo","/trees/child"]},
      "/trees/child/src"),"/repo/src"),"linked checkout scope maps relative cwd to canonical repository")
    assert(String.eq(Scope.normalize(Scope.Scope{"/repo","/repo",["/repo"]},
      "/repository-other"),"/repository-other"),"repository root prefix does not admit neighboring names")

def command_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match result:
    case Done{(0,(out,_))}:
      IO.pure(String,out)
    case _:
      IO.die(String,1,"Synthetic fixture command failed")

def command(program: String,args: List<String>) -> IO(String):
  do IO<String>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(program,args,"",65536,10000)
    command_result(result)

def git(+repo: String,args: List<String>) -> IO(String):
  command("/usr/bin/git","-C" <> repo <> "-c" <> "core.hooksPath=/dev/null" <>
    "-c" <> "core.fsmonitor=false" <> "-c" <> "user.name=Synthetic" <>
    "-c" <> "user.email=fixture@example.invalid" <> "-c" <> "commit.gpgSign=false" <> args)

def commit(+repo: String,message: String) -> IO(String):
  do IO<String>:
    added : String <- git(repo,["add","--","a.bend"])
    committed : String <- git(repo,["commit","--quiet","-m",message,"--","a.bend"])
    sha : String <- git(repo,["rev-parse","HEAD"])
    return String.trim(sha)

def request(+repo: String,id: String,text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(id) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":" ++ Json.quote(text) ++ "}}\n"

def edit(+repo: String,text: String) -> String:
  "{\"type\":\"assistant\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"timestamp\":\"200\",\"message\":{\"model\":\"captured-child-model\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Edit\",\"id\":\"edit-1\",\"input\":{\"file_path\":\"a.bend\",\"new_string\":" ++
    Json.quote(text) ++ "}}]}}\n"

def contents(first: String,last: String) -> String:
  first ++ "\nlet keep_a = 1\nlet keep_b = 2\nlet keep_c = 3\nlet keep_d = 4\n" ++ last ++ "\n"

def codex_metadata(repo: String,id: String,+parent: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":" ++ Json.quote(id) ++
    ",\"cwd\":" ++ Json.quote(repo) ++ ",\"source\":" ++
    Bool.pick(String,String.is_empty(parent),"\"cli\"",
      "{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":" ++ Json.quote(parent) ++ "}}}") ++ "}}\n"

def codex_request(text: String,model: String) -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"model\":" ++
    Json.quote(model) ++ ",\"content\":[{\"type\":\"input_text\",\"text\":" ++ Json.quote(text) ++ "}]}}\n"

def child_navigation(+db: U32,+root: String,+repo: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(root ++ "/codex-parent.jsonl","w",codex_metadata(repo,"codex-parent-0001","") ++
      codex_request("Please coordinate the captured child.","recorded-parent-model"))
    parent : String <- Store.import_file(db,"codex",root ++ "/codex-parent.jsonl")
    Store.write_text(root ++ "/codex-child.jsonl","w",codex_metadata(repo,"codex-child-0001","codex-parent-0001") ++
      codex_request("Child observed request.","recorded-child-model"))
    +child : String <- Store.import_file(db,"codex",root ++ "/codex-child.jsonl")
    Store.write_text(repo ++ "/a.bend","w",contents("let alpha = 46","let omega = 99"))
    sha : String <- commit(repo,"child identity\n\nCodex-Session: codex-child-0001")
    +why : String <- F.commit_why(db,repo,sha)
    assert(String.contains(why,"\nexact\nCitation:") && String.contains(why,"\"snapshot\":\"" ++ child ++ "\""),
      "child exact association retains child capture identity")
    assert(String.contains(why,"Parent request for navigation only") &&
      String.contains(why,"Please coordinate the captured child."),"child Why provides a separately cited parent request")
    assert(String.contains(why,"recorded model: recorded-child-model"),
      "parent navigation does not replace recorded child model")

def negative_captures(+db: U32,+root: String,+repo: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(root ++ "/blocked.jsonl","w",
      "{\"type\":\"user\",\"origin\":\"juiceInternal\",\"sessionId\":\"blocked-session-0001\",\"cwd\":" ++
      Json.quote(repo) ++ ",\"message\":{\"content\":\"Diagnostic request that must not become ordinary evidence.\"}}\n")
    blocked : String <- Store.import_file(db,"claude",root ++ "/blocked.jsonl")
    Store.write_text(root ++ "/orphan.jsonl","w",codex_metadata(repo,"orphan-session-0001","missing-parent-0001") ++
      codex_request("Orphan child request.","orphan-model"))
    orphan : String <- Store.import_file(db,"codex",root ++ "/orphan.jsonl")
    +actors : List<&2,A.Actor> <- A.load(db)
    assert(String.eq(P.attribution_name(F.commit_identity(repo,
      "Claude-Session: blocked-session-0001",actors)),"not_indexed"),
      "verified captured diagnostic origin cannot supply exact association")
    assert(String.eq(P.attribution_name(F.commit_identity(repo,
      "Codex-Session: orphan-session-0001",actors)),"not_indexed"),
      "verified captured orphan metadata cannot supply exact association")

def after_found(found: Bool,text: String,marker: String,next: Unit -> String) -> String:
  match found:
    case True{}:
      String.drop(text,String.length(marker))
    case False{}:
      next(Unit{})

def after_marker(+text: String,+marker: String) -> String:
  match text:
    case SNil{}:
      ""
    case SCon{_,rest}:
      after_found(String.starts_with(text,marker),text,marker,_ => after_marker(rest,marker))

def run_fixture(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  +source = root ++ "/parent.jsonl"
  do IO<Unit>:
    initialized : String <- command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/a.bend","w",contents("let alpha = 0","let omega = 0"))
    baseline : String <- commit(repo,"synthetic baseline")
    Store.write_text(repo ++ "/a.bend","w",contents("let alpha = 42","let omega = 99"))
    changed : String <- commit(repo,"two independent changed regions")
    Store.write_text(source,"w",request(repo,"session-alpha-0001","Please change the first calculation.") ++ edit(repo,"let alpha = 42"))
    +db : U32 <- Store.open(root ++ "/.build/file-evidence.sqlite")
    +snapshot : String <- Store.import_file(db,"claude",source)
    +blame : String <- F.blame(db,repo,"a.bend",1,6)
    assert(String.contains(blame,"content · 1/1 eligible lines"),"real Git diff hunk links retained Edit")
    assert(String.contains(after_marker(blame,"Line 6 ·"),"not_indexed") &&
      Bool.not(String.contains(after_marker(blame,"Line 6 ·"),"content ·")),
      "unmatched sibling hunk does not borrow matching first region")
    +why : String <- F.why(db,repo,"a.bend",1,1)
    assert(String.contains(why,"Please change the first calculation.") &&
      String.contains(why,"\"snapshot\":\"" ++ snapshot ++ "\""),"file Why resolves captured request and exact snapshot")
    removed : String <- command("/bin/rm",["--",source])
    retained : String <- F.why(db,repo,"a.bend",1,1)
    assert(String.eq(why,retained),"file Why survives deletion of original captured history")
    Store.write_text(repo ++ "/a.bend","w",contents("let alpha = 43","let omega = 99"))
    +exact_sha : String <- commit(repo,"explicit identity\n\nClaude-Session: session-alpha-0001")
    +exact : String <- F.commit_why(db,repo,exact_sha)
    assert(String.contains(exact,"\nexact\nCitation:") &&
      String.contains(exact,"Please change the first calculation."),"exact commit Why uses unique eligible explicit trailer")
    linked : String <- git(repo,["worktree","add","--quiet","--detach",root ++ "/linked-checkout",exact_sha])
    +linked_why : String <- F.why(db,root ++ "/linked-checkout","a.bend",1,1)
    assert(String.contains(linked_why,"\nexact\nCitation:") &&
      String.contains(linked_why,"Please change the first calculation."),"linked worktree uses canonical captured repository identity")
    Store.write_text(root ++ "/foreign.jsonl","w",request("/synthetic/foreign","session-alpha-0001","Different repository"))
    foreign : String <- Store.import_file(db,"claude",root ++ "/foreign.jsonl")
    scoped : String <- F.commit_why(db,repo,exact_sha)
    assert(String.contains(scoped,"\nexact\nCitation:"),"cross-repository session collision cannot steal exact commit")
    Store.write_text(repo ++ "/a.bend","w",contents("let alpha = 44","let omega = 99"))
    probable_sha : String <- commit(repo,"Discussed with session-alpha-0001.")
    probable : String <- F.commit_why(db,repo,probable_sha)
    assert(String.contains(probable,"probable · explicit session identifier"),"body session mention is probable in actual commit workflow")
    child_navigation(db,root,repo)
    negative_captures(db,root,repo)
    Store.write_text(root ++ "/collision.jsonl","w",request(repo,"session-alpha-0001","Different captured source with colliding ID"))
    collision : String <- Store.import_file(db,"claude",root ++ "/collision.jsonl")
    +ambiguous : String <- F.commit_why(db,repo,exact_sha)
    assert(String.contains(ambiguous,"ambiguous ·") && Bool.not(String.contains(ambiguous,"\nexact\n")),
      "same-repository source collision downgrades actual commit identity")
    Store.write_text(repo ++ "/a.bend","w",contents("let alpha = 45","let omega = 99"))
    dirty : String <- F.blame(db,repo,"a.bend",1,1)
    assert(String.contains(dirty,"uncommitted · no committed authorship claimed"),"working-tree line bypasses commit attribution")
    IO.try(Unit,Sql.close(db))

def gui_fixture(+root: String) -> IO(Unit):
  +repo = root ++ "/gui-repository"
  do IO<Unit>:
    initialized : String <- command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/a.bend","w","let display = 42\n")
    sha : String <- commit(repo,"captured GUI provenance\n\nClaude-Session: gui-session-0001")
    Store.write_text(root ++ "/gui-demo.jsonl","w",
      request(repo,"gui-session-0001","Please preserve the display calculation for the native provenance check.") ++
      edit(repo,"let display = 42"))
    IO.print("GUI fixture source: " ++ root ++ "/gui-demo.jsonl")
    IO.print("GUI Blame form: " ++ repo ++ "|a.bend|1|1")

def main() -> IO(Unit):
  do IO<Unit>:
    raw_root : String <- IO.try(String,IO.get_env("PWD"))
    +root : String <- Paths.resolve(raw_root)
    Store.checked(String.contains(root,"juice-bend-test-file_evidence."),
      "Run using ./scripts/test tests/file_evidence.bend in its isolated directory")
    pure()
    run_fixture(root)
    gui_fixture(root)
    IO.print("File evidence pure and native Git workflow passed")
