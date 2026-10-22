import Base

# Resolve namespace before HOME lookup, mkdir or capture-library open. Existing
# capture status/history commands retain their original meaning. Only the first
# command token is classified; search/export operands named quota remain data.
type Route is Data:
  Quota{root: String,args: List<&2,String>}
  Capture{root: Maybe<&2,String>,args: List<&2,String>}
  Rejected{}

def quota_only(command: String) -> Bool:
  match command:
    case "quota": True{}
    case "--quota": True{}
    case "enable": True{}
    case "disconnect": True{}
    case "observe-claude": True{}
    case "statusline-claude": True{}
    case _: False{}

def ordinary_allowed(root: Maybe<&2,String>,args: List<&2,String>,reserved: Bool) -> Route:
  match reserved:
    case True{}: Rejected{}
    case False{}: Capture{root,args}

def ordinary(root: Maybe<&2,String>,args: List<&2,String>) -> Route:
  match args:
    case []: Capture{root,[]}
    case +command <> rest: ordinary_allowed(root,command <> rest,quota_only(command))

def explicit(root: String,args: List<&2,String>) -> Route:
  match args:
    case "quota" <> rest: Quota{root,rest}
    case rest: ordinary(Some{root},rest)

def classify(args: List<&2,String>) -> Route:
  match args:
    case "--data-dir" <> root <> rest: explicit(root,rest)
    case "--data-dir" <> []: Rejected{}
    case rest: ordinary(None{},rest)

def linear(args: List<&2,String>) -> List<String>:
  match args:
    case []: []
    case value <> rest: value <> linear(rest)
