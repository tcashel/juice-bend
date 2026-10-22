import Base
import ../src/recorded_commit_observation.bend as O
import ../src/recorded_commit_links.bend as L
import ../src/recorded_commit.bend as C
import ../src/repo_scope.bend as Scope

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def issue(state: String) -> String:
  O.collect([L.Evidence{state,"","call","result",None{}}])

def unrelated() -> String:
  +call : L.Call = L.Call{"other","citation",1,"unsupported custom wrapper: functions.exec","return 1","/synthetic/repo",None{}}
  scope : Scope.Scope = Scope.Scope{"/synthetic/repo","/synthetic/repo",["/synthetic/repo"]}
  O.collect(L.analyze_all([call],[call],[],scope))

def repeated_slash() -> String:
  +known : L.Call = L.Call{"known","known-call",1,"Bash","{\"command\":\"git commit -m x\"}","/synthetic/repo",None{}}
  +uncertain : L.Call = L.Call{"uncertain","uncertain-call",3,"Bash","{\"command\":\"git commit -m x\"}","/synthetic//repo",None{}}
  result : L.Output = L.Output{"known","known-result",2,"succeeded",[C.Marker{"abcdef1","main","x"}]}
  other : L.Output = L.Output{"uncertain","uncertain-result",4,"succeeded",[C.Marker{"abcdef1","main","x"}]}
  scope : Scope.Scope = Scope.Scope{"/synthetic/repo","/synthetic/repo",["/synthetic/repo"]}
  O.collect(L.analyze_all([known,uncertain],[known,uncertain],[result,other],scope))

def main() -> IO(Unit):
  do IO<Unit>:
    assert(Bool.not(String.is_empty(issue("output_bound"))),"candidate output bound is incomplete coverage")
    assert(Bool.not(String.is_empty(issue("unsupported_result"))),"malformed candidate completion is incomplete coverage")
    assert(Bool.not(String.is_empty(issue("ambiguous_output"))),"multiple candidate markers cannot imply unique coverage")
    assert(Bool.not(String.is_empty(issue("ambiguous_pair"))),"duplicate candidate IDs cannot imply unique coverage")
    assert(Bool.not(String.is_empty(issue("completion_unknown"))),"unknown candidate completion remains incomplete")
    assert(Bool.not(String.is_empty(issue("unsupported_command: unsupported executable or shell wrapper"))),"commit-looking unsupported wrapper is visible incompleteness")
    assert(String.is_empty(issue("unsupported_command: command_repository_mismatch")),"known other repository is outside selected candidate coverage")
    assert(Bool.not(String.is_empty(issue("unsupported_command: command_repository_unresolved"))),"unresolved command repository prevents a unique coverage label")
    assert(String.is_empty(issue("failed")),"known failed command does not erase an independent verified match")
    assert(String.is_empty(issue("quiet_output")),"quiet command stays explicit without an invented object")
    assert(String.is_empty(issue("output_sha_missing")),"completed no-marker output stays explicit without an invented object")
    assert(String.is_empty(unrelated()),"unrelated custom tool does not poison candidate coverage")
    assert(Bool.not(String.is_empty(repeated_slash())),"exact-root match plus repeated-slash candidate cannot claim unique coverage")
