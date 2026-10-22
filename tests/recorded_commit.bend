import Base
import ../src/recorded_commit.bend as C
import ../src/recorded_commit_raw.bend as R
import ../src/recorded_commit_links.bend as L
import ../src/json.bend as Json
import ../src/repo_scope.bend as Scope

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def accepted(value: Result<&2,&2,String,C.Command>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def quiet(value: Result<&2,&2,String,C.Command>) -> Bool:
  match value:
    case Done{C.Command{value,_}}: value
    case Fail{_}: False{}

def marker(value: Maybe<&2,C.Marker>) -> String:
  match value:
    case Some{C.Marker{sha,_,_}}: sha
    case None{}: ""

def parsed_json(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{raw}: raw
    case Fail{_}: Json.JNull{}

def json(value: String) -> Json.Json:
  parsed_json(Json.parse(value))

def status(value: R.Item) -> String:
  match value:
    case R.Output{_,state,_}: state
    case R.Unsupported{_}: "unsupported"
    case _: "other"

def claude(extra: String) -> Json.Json:
  json("{\"type\":\"tool_result\",\"tool_use_id\":\"call-1\",\"content\":\"[main abcdef1] changed\\n\"" ++ extra ++ "}")

def codex(output: String) -> Json.Json:
  json("{\"call_id\":\"call-1\",\"output\":" ++ output ++ "}")

def state(value: L.Evidence) -> String:
  L.Evidence{state,_,_,_,_} = value
  state

def call(id: String,position: U32,command: String) -> L.Call:
  L.Call{id,"call-citation",position,"Bash","{\"command\":" ++ Json.quote(command) ++ "}",
    "/synthetic/repo",Some{L.Request{"request-citation","Please implement this."}}}

def output(id: String,position: U32,status: String) -> L.Output:
  L.Output{id,"result-citation",position,status,[C.Marker{"abcdef1","main","changed"}]}

def invalid_json(value: Result<&2,&2,String,Json.Json>) -> Bool:
  match value:
    case Fail{_}: True{}
    case Done{_}: False{}

def duplicate_claude() -> Json.Json:
  Json.JObject{[Json.JField{"tool_use_id",Json.JString{"call-1"}},
    Json.JField{"content",Json.JString{"[main abcdef1] changed"}},
    Json.JField{"is_error",Json.JBool{False{}}},Json.JField{"is_error",Json.JBool{True{}}}]}

def duplicate_codex() -> Json.Json:
  Json.JObject{[Json.JField{"call_id",Json.JString{"call-1"}},
    Json.JField{"output",Json.JObject{[Json.JField{"exit_code",Json.JNumber{"0"}},
      Json.JField{"metadata",Json.JObject{[]}},Json.JField{"metadata",Json.JObject{[]}},
      Json.JField{"output",Json.JString{"[main abcdef1] changed"}}]}}]}

def parsed() -> IO(Unit):
  do IO<Unit>:
    assert(accepted(C.command("git commit -m 'Keep café 中文 🙂'")),"literal quoted Unicode commit message")
    assert(accepted(C.command("git add -- file.txt && /usr/bin/git commit --no-gpg-sign -m \"changed\"")),"single git add prefix")
    assert(accepted(C.command("git -C '/synthetic/repo' commit --amend --no-edit")),"literal per-command checkout")
    assert(quiet(C.command("git commit --quiet -m x")),"quiet flag recorded")
    assert(Bool.not(quiet(C.command("git commit -m '--quiet'"))),"message value cannot impersonate quiet flag")
    assert(Bool.not(accepted(C.command("echo git commit -m x"))),"prose command rejected")
    assert(Bool.not(accepted(C.command("git log --oneline"))),"git log output not a commit")
    assert(Bool.not(accepted(C.command("git commit -m $(whoami)"))),"substitution unsupported without execution")
    assert(Bool.not(accepted(C.command("git commit -m `whoami`"))),"backtick unsupported")
    assert(Bool.not(accepted(C.command("git commit -m x; printf fake"))),"semicolon cannot append fake output")
    assert(accepted(C.command("git\tcommit -m 'literal ; | < > ( ) # & characters'")),"tab separator and quoted operator characters stay literal")
    assert(Bool.not(accepted(C.command("git commit -m x | cat"))),"pipe operator rejected")
    assert(Bool.not(accepted(C.command("git commit -m x > out"))),"output redirection rejected")
    assert(Bool.not(accepted(C.command("git commit -m x < in"))),"input redirection rejected")
    assert(Bool.not(accepted(C.command("git commit -m x ( extra )"))),"grouping rejected")
    assert(Bool.not(accepted(C.command("git commit -m x # comment"))),"unquoted comment rejected")
    assert(Bool.not(accepted(C.command("git commit -m x &"))),"single trailing ampersand rejected")
    assert(Bool.not(accepted(C.command("git commit -m x && git commit -m y"))),"multiple commit commands ambiguous")
    assert(Bool.not(accepted(C.command("git commit -m 'unterminated"))),"unclosed quote refused")
    assert(Bool.not(accepted(C.command("git commit --dry-run -m x"))),"dry run is not commit success")
    assert(Bool.not(accepted(C.command("git commit -m"))),"missing argument value refused")
    assert(String.eq(marker(C.marker("[main abcdef1] changed")),"abcdef1"),"standard success marker")
    assert(String.eq(marker(C.marker("[main (root-commit) ABCDEF123] first")),"abcdef123"),"root commit and uppercase SHA")
    assert(String.eq(marker(C.marker("[detached HEAD abcdef1] changed")),"abcdef1"),"detached HEAD marker")
    assert(String.eq(marker(C.marker("[main (other-commit) abcdef1] changed")),""),"unsupported three-field marker tag rejected")
    assert(String.eq(marker(C.marker("[detached OTHER abcdef1] changed")),""),"detached marker requires exact HEAD tag")
    assert(String.eq(marker(C.marker("prose [main abcdef1] changed")),""),"marker must start output line")
    assert(String.eq(marker(C.marker("[main abcdef] too short")),""),"abbreviated object minimum seven digits")
    assert(String.eq(marker(C.marker("[main abcdef1] ")),""),"missing subject not marker")
    assert(String.eq(marker(C.marker("[main abcdeg1] changed")),""),"nonhex name refused")
    assert(String.eq(status(R.from_result(R.claude_result(claude(",\"is_error\":false")))),"succeeded"),"Claude explicit successful result")
    assert(String.eq(status(R.from_result(R.claude_result(claude(",\"is_error\":true")))),"failed"),"Claude explicit error remains failed")
    assert(String.eq(status(R.from_result(R.claude_result(claude("")))),"completion_unknown"),"missing Claude completion is unknown")
    assert(String.eq(status(R.from_result(R.claude_result(duplicate_claude()))),"unsupported_result"),"duplicate completion rejected")
    assert(invalid_json(Json.parse("{\"is_error\":false,\"is_error\":true}")),"wire JSON rejects duplicate completion before extraction")
    assert(String.eq(status(R.from_result(R.codex_result(codex("{\"exit_code\":0,\"output\":\"[main abcdef1] changed\"}")))),"succeeded"),"Codex structured zero exit")
    assert(String.eq(status(R.from_result(R.codex_result(codex("{\"exit_code\":1,\"output\":\"[main abcdef1] changed\"}")))),"failed"),"failure overrides success-looking output")
    assert(String.eq(status(R.from_result(R.codex_result(codex("{\"exit_code\":0,\"metadata\":{\"exit_code\":1},\"output\":\"[main abcdef1] changed\"}")))),"unsupported_result"),"conflicting structured completion cannot succeed")
    assert(String.eq(status(R.from_result(R.codex_result(codex("{\"exit_code\":0,\"metadata\":null,\"output\":\"[main abcdef1] changed\"}")))),"unsupported_result"),"malformed present completion metadata cannot succeed")
    assert(String.eq(status(R.from_result(R.codex_result(duplicate_codex()))),"unsupported_result"),"duplicate completion metadata cannot succeed")
    assert(invalid_json(Json.parse("{\"metadata\":{},\"metadata\":{}}")),"wire JSON rejects duplicate metadata before extraction")
    assert(String.eq(status(R.from_result(R.codex_result(codex(Json.quote("Wall time: 1 seconds\nProcess exited with code 0\nFinal output:\n[main abcdef1] changed\n"))))),"succeeded"),"Codex bounded legacy terminal wrapper")
    assert(String.eq(status(R.from_result(R.codex_result(codex(Json.quote("[main abcdef1] changed\n"))))),"completion_unknown"),"marker alone cannot prove Codex completion")
    assert(String.eq(status(R.from_result(R.codex_result(codex(Json.quote("Process exited with code 0\nProcess exited with code 1\nFinal output:\n[main abcdef1] changed"))))),"completion_unknown"),"duplicate terminal status rejected")
    assert(String.eq(status(R.from_result(R.codex_result(codex(Json.quote("Process running with session ID 42\nProcess exited with code 0\nFinal output:\n[main abcdef1] changed"))))),"incomplete"),"running marker cannot be overwritten by later terminal line")

def pairs() -> IO(Unit):
  +scope : Scope.Scope = Scope.Scope{"/synthetic/repo","/synthetic/repo",["/synthetic/repo"]}
  +one = call("call-1",1,"git commit -m x")
  +result = output("call-1",2,"succeeded")
  do IO<Unit>:
    assert(String.eq(state(L.analyze(one,[one],[result],scope)),"recorded_success"),"unique ordered same-snapshot pair")
    assert(String.eq(state(L.analyze(one,[one,one],[result],scope)),"ambiguous_pair"),"duplicate call IDs cannot pair")
    assert(String.eq(state(L.analyze(one,[one],[result,result],scope)),"ambiguous_pair"),"duplicate result IDs cannot pair")
    assert(String.eq(state(L.analyze(one,[one],[],scope)),"missing_result"),"missing result remains missing")
    assert(String.eq(state(L.analyze(one,[one],[output("call-1",0,"succeeded")],scope)),"pair_order_conflict"),"earlier result cannot bind later call")
    assert(String.eq(state(L.analyze(one,[one],[output("call-1",2,"failed")],scope)),"failed"),"failed recorded call is not attributed")
    assert(String.eq(state(L.analyze(one,[one],[L.Output{"call-1","r",2,"succeeded",[]}],scope)),"output_sha_missing"),"successful no-marker output is explicit")
    +q : L.Call = call("call-q",1,"git commit -q -m x")
    assert(String.eq(state(L.analyze(q,[q],[L.Output{"call-q","r",2,"succeeded",[]}],scope)),"quiet_output"),"quiet success cannot infer SHA")
    +foreign : L.Call = call("call-f",1,"git -C /other commit -m x")
    assert(String.contains(state(L.analyze(foreign,[foreign],[output("call-f",2,"succeeded")],scope)),"repository_mismatch"),"logged alternate checkout cannot select Git repository")
    assert(Bool.not(L.in_repository(scope,"/synthetic/repository-other")),"repository prefix collision excluded")
    assert(Bool.not(L.in_repository(scope,"/synthetic/repo/../other")),"logged traversal cannot claim repository ownership")
    assert(Bool.not(L.in_repository(scope,"/synthetic/repo/nested")),"unknown nested repository is not assumed owned")
    assert(String.eq(L.repository_reason(scope,"."),"command_repository_unresolved"),"relative checkout ownership remains unresolved")
    assert(String.eq(L.repository_reason(scope,"/synthetic/repo/nested"),"command_repository_unresolved"),"descendant checkout is unresolved rather than assumed another repository")
    assert(String.eq(L.repository_reason(scope,"/other/../synthetic/repo"),"command_repository_unresolved"),"outside traversal cannot masquerade as a known different repository")
    assert(String.eq(L.repository_reason(scope,"/synthetic//repo"),"command_repository_unresolved"),"repeated slash cannot masquerade as a known different repository")
    assert(String.eq(state(L.marker_evidence([C.Marker{"abcdef1","main","a"},C.Marker{"abcdef2","main","b"}],False{},"c","r",None{})),"ambiguous_output"),"multiple markers are ambiguous")

def main() -> IO(Unit):
  do IO<Unit>:
    parsed()
    pairs()
