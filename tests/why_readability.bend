import Base
import ../src/file_evidence.bend as F
import ../src/actors.bend as A
import ../src/provenance.bend as P
import ../src/evidence.bend as E
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths
import ../src/repo_scope.bend as Scope
import ../src/cli.bend as Cli
import ./file_evidence.bend as Fixture
import ./cli.bend as Export

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def notices() -> String:
  "\nRead-only current Git resolution; this may differ from a previously displayed Blame." ++
    "\nCaptured source bounds: 64 generation snapshots, first 16 records for actor identity, newest 256 edit events." ++
    "\nFile evidence is independent of transcript filters. Exact means a unique eligible captured identity named by an explicit commit trailer; it does not prove sole authorship." ++
    "\nContent uses each commit diff hunk and original-line coordinates; unmatched regions never borrow a neighboring match." ++
    "\nUnknown, excluded, diagnostic, synthetic, ambiguous or orphaned actors cannot supply user-work evidence. Diagnostic-style Markdown first requests are conservatively held for review." ++
    "\nTool arguments record intent; success and rationale are not inferred. No timestamp-only attribution.\n\n"

def coverage() -> String:
  "\nCoverage: unique eligible trailer/body associations only; no time-based guess or generated rationale. File content matching requires a selected file range.\n\n"

def request_head(preview: String,key: String) -> String:
  "Recorded request policy: recorded-request-v1; not proof of human authorship or an inferred reason.\n" ++
    "Recorded request preview (at most 2048 decoded characters):\n" ++ preview ++
    "\nRecorded request citation: " ++ key ++
    "\nRetained request event excerpt and immutable citation (text, arguments, result: at most 2048 decoded characters each; context prefixes remain quoted; complete bytes remain available in raw export):\n"

def pure() -> IO(Unit):
  +key : String = "{\"provider\":\"claude\",\"source\":\"/synthetic/source\",\"generation\":\"3\",\"snapshot\":\"5\",\"extent\":\"120\",\"record\":\"7\",\"event\":\"2\"}"
  value : A.Actor = A.Actor{"claude","/synthetic/source","5","session","/synthetic/repo","parent",
    "Fix café é 中文 🙂.",key,""}
  +scope : Scope.Scope = Scope.Scope{"/checkout","/synthetic/repo",["/synthetic/repo","/checkout"]}
  +selected : List<&2,F.Selection> = [F.Selection{1,"abc","let answer = 42",P.Exact{"selected-citation"}}]
  +commits : List<&2,F.Commit> = [F.Commit{"abc","Recorded commit message",P.NotIndexed{"unused"},P.NotIndexed{"unused"},[],"Recorded note"}]
  +head : String = "Juice Bend · file evidence\nCanonical repository: /synthetic/repo\nGit checkout: /checkout\nFile: a.bend"
  +details : String = notices() ++ "Line 1 · commit abc\nlet answer = 42\nexact\nCitation: selected-citation\n\n" ++
    "Read-only Git commit abc\nRecorded commit message\nRecorded note\n"
  do IO<Unit>:
    assert(String.eq(F.request_context(value,"retained request excerpt\n","parent navigation\n"),
      request_head("Fix café é 中文 🙂.",key) ++ "retained request excerpt\nparent navigation\n"),
      "request summary retains exact Unicode citation policy excerpt and parent content")
    assert(String.eq(F.file_text(False{},scope,"a.bend",selected,commits,""),head ++ details),
      "Blame output remains byte-identical including all notices rows citations and commit notes")
    assert(String.eq(F.file_text(True{},scope,"a.bend",selected,commits,"request evidence\n"),
      head ++ "\n\nrequest evidence\n" ++ details),
      "file Why moves request evidence before every unchanged notice row and commit note")
    assert(String.eq(F.commit_text("abc","Recorded commit message",P.Exact{"selected-citation"},"request evidence\n"),
      "Juice Bend · commit Why\nRead-only Git commit abc\nexact\nCitation: selected-citation" ++
      coverage() ++ "request evidence\nRead-only Git commit message:\nRecorded commit message\n"),
      "commit Why retains exact strength coverage request evidence and message in request-first order")
    assert(String.eq(F.commit_text("abc","Unlinked message",P.NotIndexed{"missing"},""),
      "Juice Bend · commit Why\nRead-only Git commit abc\nnot_indexed · missing" ++ coverage() ++
      "Read-only Git commit message:\nUnlinked message\n"),"missing commit association has no invented request")
    assert(String.eq(F.commit_text("abc","Conflicting message",P.Ambiguous{"conflicting sources"},""),
      "Juice Bend · commit Why\nRead-only Git commit abc\nambiguous · conflicting sources" ++ coverage() ++
      "Read-only Git commit message:\nConflicting message\n"),"ambiguous commit association retains uncertainty without a request")
    missing : String <- F.actor_context(None{},[],0,"/synthetic/repo")
    assert(String.eq(missing,"Actor metadata not indexed within the stated bound.\n"),
      "missing actor retains exact bounded-metadata disclosure")

def actor(value: Maybe<&2,A.Actor>) -> A.Actor:
  match value:
    case Some{found}: found
    case None{}: A.empty("","","")

def request() -> String:
  "Please change the display calculation. café é 中文 🙂"

def native(+self: String,+root: String) -> IO(Unit):
  +repo : String = root ++ "/repository"
  +source : String = root ++ "/long-context.jsonl"
  +wrapped : String = "<system-reminder>" ++ String.repeat("x",3000n) ++ "</system-reminder>" ++ request()
  +message : String = String.repeat("Commit context. ",319n) ++ "Commit context.\n\nClaude-Session: readability-session-0001"
  do IO<Unit>:
    initialized : String <- Fixture.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/a.bend","w","let display = 0\n")
    +baseline : String <- Fixture.commit(repo,"Unlinked baseline")
    Store.write_text(repo ++ "/a.bend","w","let display = 42\n")
    +sha : String <- Fixture.commit(repo,message)
    Store.write_text(source,"w",Fixture.request(repo,"readability-session-0001",wrapped) ++ Fixture.edit(repo,"let display = 42"))
    +db : U32 <- Store.open(".build/why.sqlite")
    +snapshot : String <- Store.import_file(db,"claude",source)
    +before : String <- Store.projection_digest(db,snapshot)
    +actors : List<&2,A.Actor> <- A.load(db)
    +value : A.Actor = actor(A.find_snapshot(actors,snapshot))
    +key : String = A.key(value)
    +why : String <- F.why(db,repo,"a.bend",1,1)
    assert(String.starts_with(why,"Juice Bend · file evidence\nCanonical repository: " ++ repo ++
      "\nGit checkout: " ++ repo ++ "\nFile: a.bend\n\n" ++ request_head(request(),key)),
      "real file Why shows exact suffix request and citation before long retained context and per-line evidence")
    event_result : Result<&2,&2,String,String> <- E.resolve_citation(db,key)
    +event : String = F.resolved_text(event_result)
    assert(String.contains(why,request_head(request(),key) ++ event) &&
      String.contains(why,"\nSelected captured evidence:\n" ++ event ++ "\n"),
      "request-first Why retains both complete previously bounded event excerpts")
    assert(String.contains(why,"<system-reminder>" ++ String.repeat("x",2031n)) &&
      String.contains(why,notices()) && String.contains(why,"Line 1 · commit " ++ sha) &&
      String.contains(why,"Read-only Git commit " ++ sha),
      "long context file Why preserves context prefix scope coverage attribution and commit notes")
    +commit : String <- F.commit_why(db,repo,sha)
    assert(String.starts_with(commit,"Juice Bend · commit Why\nRead-only Git commit " ++ sha ++
      "\nexact\nCitation: " ++ key ++ coverage() ++ request_head(request(),key)) &&
      String.contains(commit,"Read-only Git commit message:\n" ++ message),
      "real commit Why puts request before long commit message without dropping the message")
    exported_result : U32 & (String & String) <- Export.run(self,"why.md",why)
    Export.status(exported_result,True{},"\"exact_displayed_text\":true","Why displayed export accepts canonical reordered evidence")
    exported : String <- Export.read("why.md",65536)
    assert(String.eq(exported,"# Juice Bend displayed evidence\n\n" ++
      "This export copies the displayed evidence and its captured citations. It does not re-resolve Git or perform a new evidence verification.\n\n" ++ why),
      "Why displayed export preserves the exact complete canonical text and every citation")
    +missing : String <- F.commit_why(db,repo,baseline)
    assert(String.contains(missing,"not_indexed") && Bool.not(String.contains(missing,"Recorded request preview")),
      "real missing association does not acquire a request from another captured commit")
    Store.write_text(root ++ "/collision.jsonl","w",Fixture.request(repo,"readability-session-0001","Different captured source"))
    collision : String <- Store.import_file(db,"claude",root ++ "/collision.jsonl")
    +ambiguous : String <- F.commit_why(db,repo,sha)
    assert(String.contains(ambiguous,"ambiguous ·") && Bool.not(String.contains(ambiguous,"Recorded request preview")) &&
      Bool.not(String.contains(ambiguous,"Recorded request citation:")),
      "real ambiguous association remains uncertain and exposes no chosen request preview or citation")
    after : String <- Store.projection_digest(db,snapshot)
    assert(String.eq(before,after),"Why presentation and export leave the selected projection unchanged")
    IO.try(Unit,Sql.close(db))

def run(self: String) -> IO(Unit):
  do IO<Unit>:
    raw : String <- IO.try(String,IO.get_env("PWD"))
    +root : String <- Paths.resolve(raw)
    Store.checked(String.contains(root,"juice-bend-test-why_readability."),"requires isolated Why readability test root")
    pure()
    native(self,root)

def args(argv: List<String>) -> IO(Unit):
  match argv:
    case self <> []:
      run(self)
    case _ <> "worker" <> path <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/export.sqlite")
        Cli.export_displayed(db,path)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Invalid Why readability test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
