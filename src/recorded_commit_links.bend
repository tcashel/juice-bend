import Base
import ./recorded_commit.bend as C
import ./recorded_commit_raw.bend as Raw
import ./repo_scope.bend as Scope
import ./json.bend as Json

type Request is Data:
  Request{citation: String,preview: String}

type Call is Data:
  Call{id: String,citation: String,position: U32,tool: String,args: String,
    repository: String,request: Maybe<&2,Request>}

type Output is Data:
  Output{id: String,citation: String,position: U32,status: String,markers: List<&2,C.Marker>}

type Evidence is Data:
  Evidence{state: String,prefix: String,call: String,result: String,request: Maybe<&2,Request>}

def call_id(value: Call) -> String:
  Call{id,_,_,_,_,_,_} = value
  id

def output_id(value: Output) -> String:
  Output{id,_,_,_,_} = value
  id

def calls_count(items: List<&2,Call>,+id: String) -> U32:
  match items:
    case []: 0
    case value <> rest: U32.add(Bool.to_u32(String.eq(call_id(value),id)),calls_count(rest,id))

def outputs(items: List<&2,Output>,+id: String) -> List<&2,Output>:
  match items:
    case []: []
    case +value <> rest:
      +tail = outputs(rest,id)
      Bool.pick(List<&2,Output>,String.eq(output_id(value),id),value <> tail,tail)

def in_repository(+scope: Scope.Scope,path: String) -> Bool:
  +canonical = Scope.canonical(scope)
  +normalized = Scope.normalize(scope,path)
  # A textual descendant can be a nested repository, submodule or traversal.
  # Only an exact already-resolved worktree-root alias establishes ownership.
  String.eq(canonical,normalized)

def repository_reason(+scope: Scope.Scope,path: String) -> String:
  +normalized = Scope.normalize(scope,path)
  +canonical = Scope.canonical(scope)
  # Relative, traversal and descendant paths cannot establish which repository
  # owns the command without reading a logged path. Preserve that uncertainty.
  Bool.pick(String,String.starts_with(normalized,"/") &&
    Bool.not(String.starts_with(normalized,canonical ++ "/")) &&
    Bool.not(String.contains(normalized,"//")) &&
    Bool.not(String.contains(normalized,"/../")) && Bool.not(String.contains(normalized,"/./")) &&
    Bool.not(String.ends_with(normalized,"/..")) && Bool.not(String.ends_with(normalized,"/.")),
    "command_repository_mismatch","command_repository_unresolved")

def command_scope(command: C.Command,+scope: Scope.Scope,+cwd: String,+workdir: String) ->
  Result<&2,&2,String,C.Command>:
  C.Command{quiet,+directory} = command
  +effective = Bool.pick(String,String.is_empty(workdir),cwd,workdir)
  +selected = Bool.pick(String,String.is_empty(directory),effective,directory)
  Bool.pick(Result<&2,&2,String,C.Command>,in_repository(scope,selected),
    Done{C.Command{quiet,selected}},Fail{repository_reason(scope,selected)})

def command_pair(pair: C.Arguments,scope: Scope.Scope,cwd: String) -> Result<&2,&2,String,C.Command>:
  C.Arguments{text,workdir} = pair
  do Result<&2,&2,String,C.Command>:
    parsed : C.Command <- C.command(text)
    command_scope(parsed,scope,cwd,workdir)

def command(tool: String,args: String,scope: Scope.Scope,cwd: String) -> Result<&2,&2,String,C.Command>:
  do Result<&2,&2,String,C.Command>:
    raw : Json.Json <- Json.parse(args)
    pair : C.Arguments <- C.arguments(tool,raw)
    command_pair(pair,scope,cwd)

def marker_evidence(markers: List<&2,C.Marker>,quiet: Bool,call: String,result: String,
  request: Maybe<&2,Request>) -> Evidence:
  match markers:
    case C.Marker{sha,_,_} <> Nil{}: Evidence{"recorded_success",sha,call,result,request}
    case Nil{}: Evidence{Bool.pick(String,quiet,"quiet_output","output_sha_missing"),"",call,result,request}
    case _: Evidence{"ambiguous_output","",call,result,request}

def ordered_output(ordered: Bool,markers: List<&2,C.Marker>,quiet: Bool,call: String,
  result: String,request: Maybe<&2,Request>) -> Evidence:
  match ordered:
    case False{}: Evidence{"pair_order_conflict","",call,result,request}
    case True{}: marker_evidence(markers,quiet,call,result,request)

def paired_status(succeeded: Bool,status: String,call: String,position: U32,after: U32,
  markers: List<&2,C.Marker>,quiet: Bool,result: String,request: Maybe<&2,Request>) -> Evidence:
  match succeeded:
    case True{}: ordered_output(U32.is_lt(position,after),markers,quiet,call,result,request)
    case False{}: Evidence{status,"",call,result,request}

def paired_output(value: Output,call: String,position: U32,quiet: Bool,request: Maybe<&2,Request>) -> Evidence:
  Output{_,result,after,+status,markers} = value
  paired_status(String.eq(status,"succeeded"),status,call,position,after,markers,quiet,result,request)

def paired(values: List<&2,Output>,call: String,position: U32,quiet: Bool,request: Maybe<&2,Request>) -> Evidence:
  match values:
    case []: Evidence{"missing_result","",call,"",request}
    case value <> Nil{}: paired_output(value,call,position,quiet,request)
    case _: Evidence{"ambiguous_pair","",call,"",request}

def unique_call(valid: Bool,results: List<&2,Output>,key: String,position: U32,quiet: Bool,
  request: Maybe<&2,Request>) -> Evidence:
  match valid:
    case False{}: Evidence{"ambiguous_pair","",key,"",request}
    case True{}: paired(results,key,position,quiet,request)

def parsed(value: Result<&2,&2,String,C.Command>,call: Call,all: List<&2,Call>,results: List<&2,Output>) -> Evidence:
  match value call:
    case Fail{reason} Call{_,key,_,_,_,_,request}:
      Evidence{"unsupported_command: " ++ reason,"",key,"",request}
    case Done{C.Command{quiet,_}} Call{+id,key,position,_,_,_,request}:
      unique_call(Raw.valid_id(id) && U32.is_eq(calls_count(all,id),1),outputs(results,id),key,position,quiet,request)

def analyze(+call: Call,all: List<&2,Call>,results: List<&2,Output>,scope: Scope.Scope) -> Evidence:
  Call{_,_,_,tool,args,repo,_} = call
  parsed(command(tool,args,scope,repo),call,all,results)

def candidate(call: Call) -> Bool:
  Call{_,_,_,_,+args,_,_} = call
  String.contains(args,"git") && String.contains(args,"commit")

def analyze_if(valid: Bool,call: Call,all: List<&2,Call>,results: List<&2,Output>,scope: Scope.Scope,
  rest: List<&2,Evidence>) -> List<&2,Evidence>:
  match valid:
    case False{}: rest
    case True{}: analyze(call,all,results,scope) <> rest

def analyze_all(items: List<&2,Call>,+all: List<&2,Call>,+results: List<&2,Output>,+scope: Scope.Scope) -> List<&2,Evidence>:
  match items:
    case []: []
    case +call <> rest: analyze_if(candidate(call),call,all,results,scope,analyze_all(rest,all,results,scope))
