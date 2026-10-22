import Base
import ../src/evidence.bend as Evidence
import ../src/provenance.bend as P
import ../src/store.bend as Store
import ../src/sql.bend as Sql

def assert(ok: Bool, name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def lines_equal(a: List<&2, String>, b: List<&2, String>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case h <> t hh <> tt:
      String.eq(h, hh) && lines_equal(t, tt)
    case _ _:
      False{}

def matching(result: P.Attribution) -> Bool:
  match result:
    case P.Content{_, _, _}:
      True{}
    case _:
      False{}

def resolved_text(result: Result<&2,&2,String,String>) -> String:
  match result:
    case Fail{_}:
      ""
    case Done{text}:
      text

def rejected_citation(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Fail{_}:
      True{}
    case Done{_}:
      False{}

def changed_descriptor(record: Evidence.Verified,field: U32) -> String:
  Evidence.Verified{provider,source,generation,snapshot,extent,ordinal,events} = record
  match field:
    case 0:
      Evidence.citation(Evidence.Verified{"codex",source,generation,snapshot,extent,ordinal,events},0)
    case 1:
      Evidence.citation(Evidence.Verified{provider,"other-source",generation,snapshot,extent,ordinal,events},0)
    case 2:
      Evidence.citation(Evidence.Verified{provider,source,"999999",snapshot,extent,ordinal,events},0)
    case 3:
      Evidence.citation(Evidence.Verified{provider,source,generation,"999999",extent,ordinal,events},0)
    case 4:
      Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,"1",ordinal,events},0)
    case 5:
      Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,extent,"999999",events},0)
    case _:
      Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,extent,ordinal,events},1)

def rejected_fields(fuel: Nat,+db: U32,+record: Evidence.Verified,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,
          changed_descriptor(record,index))
        assert(rejected_citation(result),"citation identity component rejected " ++ U32.show(index))
        rejected_fields(rest,db,record,U32.add(index,1))

def command_result(result: Result<&1, &1, U32 & String, U32 & (String & String)>) -> IO(Unit):
  match result:
    case Fail{(code, _)}:
      IO.die(Unit, code, "Synthetic fixture command failed")
    case Done{(code, (_, _))}:
      assert(U32.is_eq(code, 0), "synthetic fixture command")

def command(program: String, args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
      Process.run(program, args, "", 65536, 5000)
    command_result(result)

def git_fixture(+db: U32, +repo: String) -> IO(Unit):
  do IO<Unit>:
    command("/usr/bin/git", ["-c", "init.defaultBranch=main", "init", "--quiet", repo])
    Store.write_text(repo ++ "/a.bend", "w", "let answer = 42\n")
    command("/usr/bin/git", ["-C", repo, "-c", "core.hooksPath=/dev/null",
      "-c", "core.fsmonitor=false", "add", "--", "a.bend"])
    command("/usr/bin/git", ["-C", repo, "-c", "user.name=Synthetic",
      "-c", "user.email=fixture@example.invalid", "-c", "core.hooksPath=/dev/null",
      "-c", "core.fsmonitor=false", "-c", "commit.gpgSign=false",
      "commit", "--quiet", "-m", "synthetic provenance fixture", "--", "a.bend"])
    Store.write_text("git-evidence.jsonl", "w",
      "{\"type\":\"user\",\"cwd\":" ++ Evidence.quote(repo) ++ ",\"message\":{\"content\":\"Please record the answer.\"}}\n" ++
      "{\"type\":\"assistant\",\"timestamp\":\"200\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"write-1\",\"name\":\"Write\",\"input\":{\"file_path\":\"a.bend\",\"content\":\"let answer = 42\\n\"}}]}}\n")
    snapshot : String <- Store.import_file(db, "claude", "git-evidence.jsonl")
    +before : String <- Evidence.blame(db, repo, "a.bend", 1, 1)
    assert(String.contains(before, "content · 1/1 eligible lines"), "live Git line links captured tool content")
    assert(String.contains(before, "\"snapshot\":\"" ++ snapshot ++ "\""), "live Blame cites exact capture")
    command("/bin/rm", ["--", "git-evidence.jsonl"])
    after : String <- Evidence.blame(db, repo, "a.bend", 1, 1)
    assert(String.eq(before, after), "live Blame survives original fixture deletion")
    Store.write_text(repo ++ "/a.bend", "w", "let answer = 99\n")
    changed : String <- Evidence.blame(db, repo, "a.bend", 1, 1)
    assert(String.contains(changed, "uncommitted · no committed authorship claimed"),
      "working-tree line remains uncommitted")

def tests() -> IO(Unit):
  do IO<Unit>:
    +root : String <- IO.try(String, IO.get_env("PWD"))
    Store.checked(String.contains(root, "juice-bend-test-evidence."),
      "Run with ./scripts/test tests/evidence.bend in its isolated fixture root")
    assert(lines_equal(Evidence.edit_lines("Edit",
      "{\"file_path\":\"/synthetic/repo/a.bend\",\"old_string\":\"old\",\"new_string\":\"first\\nsecond\"}",
      "/synthetic/repo", "a.bend"), ["first", "second"]), "captured Edit path and new text")
    assert(lines_equal(Evidence.edit_lines("Write",
      "{\"file_path\":\"a.bend\",\"content\":\"written\"}", "/synthetic/repo", "a.bend"), ["written"]),
      "captured relative Write")
    assert(lines_equal(Evidence.edit_lines("Edit",
      "{\"file_path\":\"/other/a.bend\",\"new_string\":\"wrong\"}", "/synthetic/repo", "a.bend"), []),
      "same suffix outside repository excluded")
    assert(lines_equal(Evidence.edit_lines("Bash",
      "{\"command\":\"echo first > a.bend\"}", "/synthetic/repo", "a.bend"), []),
      "shell text cannot invent an edit")
    assert(lines_equal(Evidence.edit_lines("apply_patch",
      "*** Begin Patch\n*** Update File: a.bend\n@@\n-old\n+first\n+second\n*** Update File: other.bend\n+outside\n*** End Patch",
      "/synthetic/repo", "a.bend"), ["first", "second"]), "patch selected file only")
    assert(lines_equal(Evidence.edit_lines("apply_patch",
      "*** Begin Patch\n*** Add File: a.bend\n+added\n*** End Patch",
      "/synthetic/repo", "a.bend"), ["added"]), "patch Add File")
    assert(lines_equal(Evidence.edit_lines("apply_patch",
      "*** Begin Patch\n*** Update File: a.bend\n*** Move to: b.bend\n+changed\n*** End Patch",
      "/synthetic/repo", "a.bend"), []), "unsupported patch rename does not fabricate a match")
    assert(lines_equal(Evidence.edit_lines("apply_patch",
      "*** Begin Patch\n*** Update File: a.bend\n+truncated",
      "/synthetic/repo", "a.bend"), []), "incomplete patch excluded")
    assert(String.eq(Evidence.citation(Evidence.Verified{"codex", "quoted\"source",
      "3", "5", "120", "7", []}, 2),
      "{\"provider\":\"codex\",\"source\":\"quoted\\\"source\",\"generation\":\"3\",\"snapshot\":\"5\",\"extent\":\"120\",\"record\":\"7\",\"event\":\"2\"}"),
      "citation escapes complete immutable descriptor")
    +db : U32 <- Store.open(":memory:")
    Store.write_text("evidence.jsonl", "w",
      "{\"type\":\"user\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"fixture\",\"message\":{\"content\":\"Please preserve the useful calculation.\"}}\n" ++
      "{\"type\":\"assistant\",\"timestamp\":\"100\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"edit-1\",\"name\":\"Edit\",\"input\":{\"file_path\":\"/synthetic/repo/a.bend\",\"old_string\":\"old\",\"new_string\":\"let answer = 42\"}}]}}\n")
    +snapshot : String <- Store.import_file(db, "claude", "evidence.jsonl")
    +captured : Evidence.Verified <- Evidence.read_record(db,snapshot,1)
    +descriptor : String <- IO.pure(String,Evidence.citation(captured,0))
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,descriptor)
    +original_citation : String <- IO.pure(String,resolved_text(resolved))
    assert(String.contains(original_citation,"let answer = 42"),"consumed citation resolves authoritative event")
    rejected_fields(7n,db,captured,0)
    missing_fields : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,
      "{\"snapshot\":\"1\",\"record\":\"1\",\"event\":\"0\"}")
    assert(rejected_citation(missing_fields),"incomplete citation cannot guess identity")
    malformed : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,"not JSON")
    assert(rejected_citation(malformed),"malformed citation rejected")
    oversized : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,String.repeat("x",16385n))
    assert(rejected_citation(oversized),"citation input size enforced")
    +why : String <- Evidence.why(db, snapshot, 0, 20)
    assert(String.contains(why, "Please preserve the useful calculation."), "Why quotes captured request")
    assert(String.contains(why, "\"snapshot\":\"" ++ snapshot ++ "\""), "Why includes exact snapshot citation")
    assert(String.contains(why, "\"record\":\"1\",\"event\":\"0\""), "Why cites tool physical record and event")
    assert(String.contains(why, "successful changes are not inferred"), "Why does not claim tool success")
    rows : List<&2, List<&2, Sql.Cell>> <- Evidence.candidate_rows(db, "/synthetic/repo")
    +pool : List<&2, P.Candidate> <- Evidence.candidates(rows, db, "/synthetic/repo", "a.bend")
    assert(matching(P.content("/synthetic/repo", ["let answer = 42"], pool)),
      "stored tool candidate uses retained raw arguments")
    assert(Bool.not(matching(P.content("/synthetic/repo", ["malicious replacement"], pool))),
      "unrelated content remains not indexed")
    Store.exec(db, "UPDATE events SET arguments=? WHERE tool='Edit'",
      [Sql.Cell.Text{"{\"file_path\":\"a.bend\",\"new_string\":\"malicious replacement\"}"}])
    changed_rows : List<&2, List<&2, Sql.Cell>> <- Evidence.candidate_rows(db, "/synthetic/repo")
    +verified_pool : List<&2, P.Candidate> <- Evidence.candidates(changed_rows, db, "/synthetic/repo", "a.bend")
    assert(matching(P.content("/synthetic/repo", ["let answer = 42"], verified_pool)),
      "damaged projection cannot replace captured edit")
    assert(Bool.not(matching(P.content("/synthetic/repo", ["malicious replacement"], verified_pool))),
      "damaged projection cannot fabricate content attribution")
    Store.exec(db, "UPDATE events SET repository='/other' WHERE tool='Edit'", [])
    foreign_rows : List<&2, List<&2, Sql.Cell>> <- Evidence.candidate_rows(db, "/other")
    foreign_pool : List<&2, P.Candidate> <- Evidence.candidates(foreign_rows, db, "/other", "a.bend")
    assert(Bool.not(matching(P.content("/other", ["let answer = 42"], foreign_pool))),
      "damaged repository projection cannot leak attribution")
    Store.write_text("evidence.jsonl", "w", "original source replaced\n")
    retained_why : String <- Evidence.why(db, snapshot, 0, 20)
    assert(String.eq(why, retained_why), "Why is independent of replaced original source")
    invalid : String <- Evidence.blame(db, "/synthetic/repo", "a.bend", 4294967295, 2)
    assert(String.starts_with(invalid, "Blame unavailable:"), "Blame line overflow fails before Git")
    absent : String <- Evidence.why(db, "999999", 0, 10)
    assert(String.starts_with(absent, "Why unavailable:"), "missing snapshot explicit")
    Store.write_text("evidence.jsonl","w",
      "{\"type\":\"user\",\"cwd\":\"/synthetic/repo\",\"sessionId\":\"fixture\",\"message\":{\"content\":\"Please preserve the useful calculation.\"}}\n" ++
      "{\"type\":\"assistant\",\"timestamp\":\"100\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"id\":\"edit-1\",\"name\":\"Edit\",\"input\":{\"file_path\":\"/synthetic/repo/a.bend\",\"old_string\":\"old\",\"new_string\":\"let answer = 42\"}}]}}\n" ++
      "{\"type\":\"assistant\",\"message\":{\"content\":\"A later appended record\"}}\n")
    appended : String <- Store.import_file(db,"claude","evidence.jsonl")
    after_append : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,descriptor)
    assert(String.eq(resolved_text(after_append),original_citation),"consumed citation remains pinned after append")
    Store.write_text("evidence.jsonl","w","{\"type\":\"user\",\"message\":{\"content\":\"Rewritten generation\"}}\n")
    rewritten : String <- Store.import_file(db,"claude","evidence.jsonl")
    after_rewrite : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,descriptor)
    assert(String.eq(resolved_text(after_rewrite),original_citation),"consumed citation retains old generation after rewrite")
    git_fixture(db, root ++ "/fixture-repository")
    IO.try(Unit, Sql.close(db))
    IO.print("evidence: independent citation, provenance and isolated Git fixture assertions passed")

def main() -> IO(Unit):
  tests()
