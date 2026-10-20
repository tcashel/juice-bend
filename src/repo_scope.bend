import Base
import ./provenance.bend as P

type Scope is Data:
  Scope{checkout: String,canonical: String,roots: List<&2,String>}

def checkout(scope: Scope) -> String:
  Scope{value,_,_} = scope
  value

def canonical(scope: Scope) -> String:
  Scope{_,value,_} = scope
  value

def root_match(+root: String,+path: String) -> Bool:
  String.eq(path,root) || String.starts_with(path,root ++ "/")

def best_root(roots: List<&2,String>,+path: String,+best: String) -> String:
  match roots:
    case []:
      best
    case +root <> rest:
      best_root(rest,path,Bool.pick(String,root_match(root,path) &&
        Nat.is_gt(String.length(root),String.length(best)),root,best))

def normalize(+scope: Scope,+path: String) -> String:
  Scope{_,+canonical,roots} = scope
  +root = best_root(roots,path,"")
  Bool.pick(String,String.is_empty(root),path,
    canonical ++ String.drop(path,String.length(root)))

def roots(lines: List<&2,String>,+done: List<&2,String>) -> List<&2,String>:
  match lines:
    case []:
      List.reverse(&2,String,done)
    case +line <> rest:
      roots(rest,Bool.pick(List<&2,String>,String.starts_with(line,"worktree /"),
        String.drop(line,9n) <> done,done))

def valid_roots(roots: List<&2,String>) -> Bool:
  match roots:
    case []:
      True{}
    case root <> rest:
      P.safe_repo(root) && valid_roots(rest)

def finish(+checkout: String,+common: String,+worktrees: String,+alias: String) ->
  Result<&2,&2,String,Scope>:
  +paths = {alias <> roots(String.lines(worktrees),[]) : List<&2,String>}
  +primary = Bool.pick(String,String.ends_with(common,"/.git"),
    String.take(common,Nat.sub(String.length(common),5n)),checkout)
  Bool.pick(Result<&2,&2,String,Scope>,P.safe_repo(checkout) && P.safe_repo(common) &&
    P.safe_repo(primary) && valid_roots(paths) && P.member(checkout,paths) &&
    Nat.is_le(List.length(&2,String,paths),64n),
    Done{Scope{checkout,primary,paths}},
    Fail{"Unsupported Git worktree path metadata; use an ordinary absolute checkout path"})

def result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) ->
  Result<&2,&2,String,String>:
  match result:
    case Done{(0,(text,_))}:
      Done{String.trim_end(text)}
    case _:
      Fail{"Cannot resolve explicit Git checkout and worktree metadata"}

def git(repo: String,args: List<String>) -> IO(Result<&2,&2,String,String>):
  do IO<Result<&2,&2,String,String>>:
    output : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/git","--no-pager" <> "--no-optional-locks" <> "-c" <>
        "core.hooksPath=/dev/null" <> "-c" <> "core.fsmonitor=false" <> "-c" <>
        "core.attributesFile=/dev/null" <> "-c" <> "diff.external=" <> "-C" <> repo <> args,
        "",65536,3000)
    return result(output)

def worktree_result(result: Result<&2,&2,String,String>,checkout: String,common: String,alias: String) ->
  Result<&2,&2,String,Scope>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{worktrees}:
      finish(checkout,common,worktrees,alias)

def common_result(result: Result<&2,&2,String,String>,+checkout: String,alias: String) ->
  IO(Result<&2,&2,String,Scope>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,String,Scope>,Fail{error})
    case Done{common}:
      do IO<Result<&2,&2,String,Scope>>:
        worktrees : Result<&2,&2,String,String> <- git(checkout,["worktree","list","--porcelain"])
        return worktree_result(worktrees,checkout,common,alias)

def checkout_result(result: Result<&2,&2,String,String>,alias: String) -> IO(Result<&2,&2,String,Scope>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,String,Scope>,Fail{error})
    case Done{+checkout}:
      do IO<Result<&2,&2,String,Scope>>:
        common : Result<&2,&2,String,String> <- git(checkout,["rev-parse","--path-format=absolute","--git-common-dir"])
        common_result(common,checkout,alias)

def prefix_result(result: Result<&2,&2,String,String>,+repo: String) -> IO(Result<&2,&2,String,Scope>):
  match result:
    case Done{""}:
      do IO<Result<&2,&2,String,Scope>>:
        checkout : Result<&2,&2,String,String> <- git(repo,["rev-parse","--show-toplevel"])
        checkout_result(checkout,repo)
    case _:
      IO.pure(Result<&2,&2,String,Scope>,Fail{"Use the explicit Git checkout root, not a subdirectory"})

def resolve_valid(+repo: String,valid: Bool) -> IO(Result<&2,&2,String,Scope>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,String,Scope>,Fail{"Repository must be an absolute path"})
    case True{}:
      do IO<Result<&2,&2,String,Scope>>:
        prefix : Result<&2,&2,String,String> <- git(repo,["rev-parse","--show-prefix"])
        prefix_result(prefix,repo)

def resolve(+repo: String) -> IO(Result<&2,&2,String,Scope>):
  resolve_valid(repo,P.safe_repo(repo))
