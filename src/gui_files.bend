# Pure native Files state. Repository objects never become capture snapshots.
import Base
import ./json.bend as Json
import ./provenance.bend as P
import ./ui.bend as UI

type Node is Data:
  Node{path: String, kind: String}

type Identity is Data:
  Identity{repository: String, checkout: String, commit: String}

type Directory is Data:
  Directory{path: String, offset: U32, total: U32, next: U32, nodes: List<&2,Node>}

type Source is Data:
  Source{path: String, first: U32, count: U32, next: U32, kind: U32}

# A zero/one bookmark retains text selection without expanding every Gui State
# continuation or keeping an old image. Invalid/multiple values are not ready.
type Saved is Data:
  Saved{views: List<&2,UI.Bookmark>}

type State is Data:
  State{input: String, identity: Identity, directory: Directory, source: Source, saved: Saved}

def empty() -> State:
  State{"",Identity{"","",""},Directory{"",0,0,0,[]},Source{"",1,0,0,0},Saved{[]}}

def identity(state: State) -> Identity:
  State{input,identity,directory,source,saved} = state
  identity

def directory(state: State) -> Directory:
  State{input,identity,directory,source,saved} = state
  directory

def source(state: State) -> Source:
  State{input,identity,directory,source,saved} = state
  source

def input(state: State) -> String:
  State{input,identity,directory,source,saved} = state
  input

def saved(state: State) -> Saved:
  State{input,identity,directory,source,saved} = state
  saved

def edit(state: State,input: String) -> State:
  State{old,identity,directory,source,saved} = state
  State{input,identity,directory,source,saved}

def begin(state: State,saved: Saved) -> State:
  State{input,identity,directory,source,old} = state
  State{input,Identity{"","",""},Directory{"",0,0,0,[]},Source{"",1,0,0,0},saved}

def parsed_number(value: Maybe<&2,U32>) -> U32:
  match value:
    case Some{value}:
      value
    case None{}:
      0

def number(text: String) -> U32:
  parsed_number(P.parse_u32(text))

def number_valid(value: Json.Json) -> Bool:
  match value:
    case Json.JNumber{+text}:
      P.decimal_valid(text) && Bool.not(Cmp.is_gt(P.decimal_compare(text,"4294967295")))
    case _:
      False{}

def text_valid(value: Json.Json) -> Bool:
  match value:
    case Json.JString{text}:
      True{}
    case _:
      False{}

def next(value: Json.Json) -> U32:
  number(Json.text(value))

def next_valid(value: Json.Json,+expected: U32,+total: U32) -> Bool:
  match value:
    case Json.JNull{}:
      U32.is_ge(expected,total)
    case Json.JNumber{+text}:
      String.eq(text,U32.show(expected)) && U32.is_lt(expected,total)
    case _:
      False{}

def nodes_list(items: List<&2,Json.Json>) -> List<&2,Node>:
  match items:
    case []:
      []
    case +node <> rest:
      Node{Json.get(node,"path"),Json.get(node,"kind")} <> nodes_list(rest)

def nodes(value: Json.Json) -> List<&2,Node>:
  nodes_list(Json.items(value))

def node_titles(nodes: List<&2,Node>) -> List<&2,String>:
  match nodes:
    case []:
      []
    case Node{path,kind} <> rest:
      (kind ++ "  " ++ path) <> node_titles(rest)

def node_at(nodes: List<&2,Node>,index: U32) -> Maybe<&2,Node>:
  match nodes index:
    case [] _:
      None{}
    case node <> rest 0:
      Some{node}
    case node <> rest n:
      node_at(rest,U32.sub(n,1))

def parent_parts(parts: List<&2,String>) -> List<&2,String>:
  match parts:
    case []:
      []
    case [last]:
      []
    case first <> rest:
      first <> parent_parts(rest)

def parent(path: String) -> String:
  String.join(parent_parts(String.split(path,'/')),"/")

def pinned(identity: Identity) -> Bool:
  Identity{repository,checkout,commit} = identity
  String.starts_with(repository,"/") && String.starts_with(checkout,"/") && P.valid_sha(commit)

def matches(+identity: Identity,+value: Json.Json) -> Bool:
  Identity{repository,checkout,commit} = identity
  String.eq(Json.get(value,"repository"),repository) && String.eq(Json.get(value,"checkout"),checkout) &&
    String.eq(Json.get(value,"commit"),commit)

def response_identity(+value: Json.Json) -> Identity:
  Identity{Json.get(value,"repository"),Json.get(value,"checkout"),Json.get(value,"commit")}

def requested(+identity: Identity,args: List<&2,String>,+value: Json.Json) -> Bool:
  Identity{repository,+checkout,+commit} = identity
  match args:
    case "repo-open" <> root <> []:
      pinned(response_identity(value)) && String.eq(Json.get(value,"path"),"") && String.eq(Json.get(value,"offset"),"0")
    case "repo-tree" <> root <> sha <> path <> offset <> []:
      pinned(identity) && matches(identity,value) && String.eq(root,checkout) && String.eq(sha,commit) &&
        String.eq(Json.get(value,"path"),path) && String.eq(Json.get(value,"offset"),offset)
    case cmd <> root <> sha <> path <> first <> count <> []:
      pinned(identity) && matches(identity,value) && String.eq(root,checkout) && String.eq(sha,commit) &&
        String.eq(Json.get(value,"path"),path) && String.eq(Json.get(value,"start"),first)
    case _:
      False{}

def array_size(value: Json.Json) -> U32:
  U32.from_nat(List.length(&2,Json.Json,Json.items(value)))

def node_fields(items: List<&2,Json.Json>) -> Bool:
  match items:
    case []:
      True{}
    case +node <> rest:
      text_valid(Json.field(node,"path")) && P.safe_path(Json.get(node,"path")) && Bool.not(String.is_empty(Json.get(node,"path"))) &&
        text_valid(Json.field(node,"kind")) && node_fields(rest)

def is_array(value: Json.Json) -> Bool:
  match value:
    case Json.JArray{items}:
      True{}
    case _:
      False{}

def directory_valid(+value: Json.Json) -> Bool:
  number_valid(Json.field(value,"offset")) && number_valid(Json.field(value,"total")) &&
    String.eq(Json.get(value,"limit"),"100") && is_array(Json.field(value,"nodes")) &&
    U32.is_le(number(Json.get(value,"offset")),number(Json.get(value,"total"))) &&
    U32.is_eq(array_size(Json.field(value,"nodes")),U32.min(100,U32.sub(number(Json.get(value,"total")),number(Json.get(value,"offset"))))) &&
    next_valid(Json.field(value,"next"),U32.add(number(Json.get(value,"offset")),array_size(Json.field(value,"nodes"))),number(Json.get(value,"total"))) &&
    node_fields(Json.items(Json.field(value,"nodes")))

def line_fields(items: List<&2,Json.Json>,+expected: Nat) -> Bool:
  match items:
    case []:
      True{}
    case +line <> rest:
      number_valid(Json.field(line,"number")) && String.eq(Json.get(line,"number"),Nat.show(expected)) &&
        text_valid(Json.field(line,"text")) && line_fields(rest,Nat.add(expected,1n))

# Calculate the exclusive line end in Nat. A valid final line at UINT32_MAX
# must not wrap to zero or appear to have another source page.
def source_next_value(+value: Json.Json,next: Json.Json,+end: Nat) -> Bool:
  match next:
    case Json.JNull{}:
      Nat.is_gt(end,U32.to_nat(number(Json.get(value,"total_lines"))))
    case Json.JNumber{+text}:
      String.eq(text,Nat.show(end)) && Bool.not(Cmp.is_gt(P.decimal_compare(text,"4294967295"))) &&
        Nat.is_le(end,U32.to_nat(number(Json.get(value,"total_lines"))))
    case _:
      False{}

def UI_minus(+a: U32,+b: U32) -> U32:
  Bool.pick(U32,U32.is_gt(a,b),U32.sub(a,b),0)

def source_shape(+value: Json.Json,+requested: U32) -> Bool:
  number_valid(Json.field(value,"start")) && number_valid(Json.field(value,"total_lines")) &&
    U32.is_gt(number(Json.get(value,"start")),0) && is_array(Json.field(value,"lines")) &&
    U32.is_le(array_size(Json.field(value,"lines")),requested) &&
    U32.is_eq(array_size(Json.field(value,"lines")),U32.min(requested,
      UI_minus(number(Json.get(value,"total_lines")),UI_minus(number(Json.get(value,"start")),1)))) &&
    P.valid_sha(Json.get(value,"blob")) && line_fields(Json.items(Json.field(value,"lines")),U32.to_nat(number(Json.get(value,"start")))) &&
    source_next_value(value,Json.field(value,"next"),Nat.add(U32.to_nat(number(Json.get(value,"start"))),U32.to_nat(array_size(Json.field(value,"lines")))))

def source_valid(args: List<&2,String>,value: Json.Json) -> Bool:
  match args:
    case "repo-source" <> root <> sha <> path <> first <> +count <> []:
      U32.is_gt(number(count),0) && U32.is_le(number(count),100) && source_shape(value,number(count))
    case _:
      False{}

def evidence_count(command: String,args: List<&2,String>,value: Json.Json) -> Bool:
  match args:
    case cmd <> root <> sha <> path <> first <> count <> []:
      String.eq(command,cmd) && String.eq(Json.get(value,"count"),count)
    case _:
      False{}

def kind_valid(kind: U32,+args: List<&2,String>,+value: Json.Json) -> Bool:
  match kind:
    case 20:
      String.eq(Json.get(value,"kind"),"repository_directory") && directory_valid(value)
    case 21:
      String.eq(Json.get(value,"kind"),"repository_source") && source_valid(args,value)
    case 22:
      String.eq(Json.get(value,"kind"),"repository_blame") && evidence_count("repo-blame",args,value)
    case 23:
      String.eq(Json.get(value,"kind"),"repository_why") && evidence_count("repo-why",args,value)
    case _:
      False{}

def valid(kind: U32,+state: State,+args: List<&2,String>,+value: Json.Json) -> Bool:
  requested(identity(state),args,value) && text_valid(Json.field(value,"text")) && kind_valid(kind,args,value)

def apply(kind: U32,state: State,+value: Json.Json) -> State:
  match kind:
    case 20:
      State{input,identity,directory,source,saved} = state
      State{input,response_identity(value),Directory{Json.get(value,"path"),number(Json.get(value,"offset")),
        number(Json.get(value,"total")),next(Json.field(value,"next")),nodes(Json.field(value,"nodes"))},Source{"",1,0,0,20},saved}
    case 21:
      State{input,identity,directory,source,saved} = state
      State{input,identity,directory,Source{Json.get(value,"path"),number(Json.get(value,"start")),
        array_size(Json.field(value,"lines")),next(Json.field(value,"next")),21},saved}
    case k:
      State{input,identity,directory,source,saved} = state
      Source{path,first,count,next,old} = source
      State{input,identity,directory,Source{path,first,count,next,k},saved}

def tree_args(identity: Identity,path: String,offset: U32) -> List<&2,String>:
  Identity{repository,checkout,commit} = identity
  ["repo-tree",checkout,commit,path,U32.show(offset)]

def source_args(command: String,identity: Identity,path: String,first: U32,count: U32) -> List<&2,String>:
  Identity{repository,checkout,commit} = identity
  [command,checkout,commit,path,U32.show(first),U32.show(count)]

def title(state: State) -> String:
  State{input,Identity{repository,checkout,commit},directory,Source{path,+first,+count,next,kind},saved} = state
  "Pinned " ++ String.take(commit,10n) ++ Bool.pick(String,U32.is_eq(kind,20)," | directory",
    Bool.pick(String,U32.is_eq(count,0)," | empty file",
      " | lines " ++ U32.show(first) ++ "-" ++ U32.show(U32.add(first,UI_minus(count,1)))))
