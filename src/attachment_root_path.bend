import Base
import ./attachment_root_rules.bend as Rules
import ./attachment_root_schema.bend as Schema

# Explicit enable only: fixed metadata utilities and literal arguments. No
# file contents, directory listing, captured URL interpretation or HOME lookup.
def repeated(value: Maybe<&2,String>,canonical: String) -> IO(Schema.result(String)):
  match value:
    case Some{+actual}: Schema.branch(IO(Schema.result(String)),String.eq(actual,canonical),
      _ => Schema.pure(String,Done{actual}),_ => Schema.fail(String,"attachment_root_path_changed"))
    case None{}: Schema.fail(String,"attachment_root_path")

def checked_directory(valid: Bool,requested: String,canonical: String) -> IO(Schema.result(String)):
  match valid:
    case False{}: Schema.fail(String,"attachment_root_not_directory")
    case True{}:
      do IO<Schema.result(String)>:
        value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/realpath",["--",requested],"",8192,2000)
        repeated(Rules.resolved(value),canonical)

def first(value: Maybe<&2,String>,requested: String) -> IO(Schema.result(String)):
  match value:
    case None{}: Schema.fail(String,"attachment_root_path")
    case Some{+canonical}:
      do IO<Schema.result(String)>:
        result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",["-d",canonical],"",1024,2000)
        checked_directory(Rules.directory(result),requested,canonical)

def resolve_checked(valid: Bool,+requested: String) -> IO(Schema.result(String)):
  match valid:
    case False{}: Schema.fail(String,"attachment_root_path")
    case True{}:
      do IO<Schema.result(String)>:
        value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/realpath",["--",requested],"",8192,2000)
        first(Rules.resolved(value),requested)

def resolve(+requested: String) -> IO(Schema.result(String)):
  resolve_checked(Rules.path(requested),requested)
