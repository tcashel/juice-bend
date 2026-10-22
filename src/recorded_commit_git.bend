import Base
import ./recorded_commit.bend as C
import ./provenance.bend as P
import ./repo_scope.bend as Scope

# The only subprocesses are literal, bounded, helper-free Git object reads in
# the checkout explicitly selected by the caller. Logged paths/commands are
# never substituted into argv. Resolve all object types before requiring commit
# type, so a colliding blob cannot be silently ignored.
type Resolution is Data:
  Resolution{state: String,sha: String}

def object_type(value: Result<&2,&2,String,String>,sha: String) -> Resolution:
  match value:
    case Done{"commit"}: Resolution{"resolved",sha}
    case Done{_}: Resolution{"not_commit",""}
    case Fail{_}: Resolution{"git_unavailable",""}

def object_checked(valid: Bool,repo: String,+sha: String) -> IO(Resolution):
  match valid:
    case False{}: IO.pure(Resolution,Resolution{"unsupported_object_format",""})
    case True{}:
      do IO<Resolution>:
        kind : Result<&2,&2,String,String> <- Scope.git(repo,["cat-file","-t",sha])
        return object_type(kind,sha)

def unique_object(lines: List<&2,String>,repo: String) -> IO(Resolution):
  match lines:
    case "" <> Nil{}: IO.pure(Resolution,Resolution{"missing_object",""})
    case Nil{}: IO.pure(Resolution,Resolution{"missing_object",""})
    case +sha <> Nil{}: object_checked(P.valid_sha(sha),repo,sha)
    case _: IO.pure(Resolution,Resolution{"ambiguous_object",""})

def disambiguated(value: Result<&2,&2,String,String>,repo: String) -> IO(Resolution):
  match value:
    case Fail{_}: IO.pure(Resolution,Resolution{"git_unavailable",""})
    case Done{text}: unique_object(String.lines(text),repo)

def resolve_checked(valid: Bool,+repo: String,prefix: String) -> IO(Resolution):
  match valid:
    case False{}: IO.pure(Resolution,Resolution{"invalid_object_name",""})
    case True{}:
      do IO<Resolution>:
        objects : Result<&2,&2,String,String> <- Scope.git(repo,["rev-parse","--disambiguate=" ++ prefix])
        disambiguated(objects,repo)

def resolve(+repo: String,+prefix: String) -> IO(Resolution):
  resolve_checked(P.safe_repo(repo) && C.object_name(prefix),repo,String.to_lower(prefix))
