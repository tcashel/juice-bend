import Base
import ./repository_browser.bend as Browser
import ./repo_scope.bend as Scope
import ./provenance.bend as P
import ./json.bend as Json
import ./domain.bend as Domain

def failure(-A: Type,code: String,message: String) -> IO(A):
  IO.die(A,2,"{\"error\":" ++ Json.quote(message) ++ ",\"code\":" ++ Json.quote(code) ++ "}")

def require(-A: Kind(&2),result: Result<&2,&2,Browser.Problem,A>) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{Browser.Problem{code,detail}}:
      failure(A,code,detail)

def number(value: Maybe<&2,U32>,label: String) -> IO(U32):
  match value:
    case Some{value}:
      IO.pure(U32,value)
    case None{}:
      failure(U32,"invalid_number",label ++ " must be an integer from 0 to 4294967295")

def byte_step(valid: Bool,budget: U32,step: U32 -> Bool) -> Bool:
  match valid:
    case False{}:
      False{}
    case True{}:
      step(budget)

def within(text: String,+budget: U32) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{ch,rest}:
      +bytes = U32.inc(Domain.encode_width(Char.to_u32(ch)))
      byte_step(U32.is_le(bytes,budget),U32.sub(budget,bytes),left => within(rest,left))

def output_valid(valid: Bool,text: String) -> IO(Unit):
  match valid:
    case False{}:
      failure(Unit,"output_too_large","Escaped repository result exceeds the 1048576-byte worker bound; select a smaller range")
    case True{}:
      IO.print(text)

def output(+text: String) -> IO(Unit):
  output_valid(within(text,1048575),text)

def next_json(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}:
      "null"
    case Some{value}:
      U32.show(value)

def identity(+view: Browser.View) -> String:
  "\"repository\":" ++ Json.quote(Scope.canonical(Browser.scope(view))) ++
    ",\"checkout\":" ++ Json.quote(Scope.checkout(Browser.scope(view))) ++
    ",\"commit\":" ++ Json.quote(Browser.commit(view))

def heading(+view: Browser.View,path: String) -> String:
  "Juice Bend · pinned commit tree\nRepository: " ++ Scope.canonical(Browser.scope(view)) ++
    "\nCheckout: " ++ Scope.checkout(Browser.scope(view)) ++ "\nCommit: " ++ Browser.commit(view) ++
    "\nPath: " ++ path ++ "\nCommitted content; working-tree changes are excluded.\n\n"

def node_json(node: Browser.Node) -> String:
  Browser.Node{path,kind,object,bytes} = node
  "{\"path\":" ++ Json.quote(path) ++ ",\"kind\":" ++ Json.quote(kind) ++
    ",\"object\":" ++ Json.quote(object) ++ ",\"bytes\":" ++ Json.quote(bytes) ++ "}"

def nodes_json(nodes: List<&2,Browser.Node>) -> String:
  match nodes:
    case []:
      ""
    case [node]:
      node_json(node)
    case node <> rest:
      node_json(node) ++ "," ++ nodes_json(rest)

def nodes_text(nodes: List<&2,Browser.Node>) -> String:
  match nodes:
    case []:
      ""
    case Browser.Node{path,kind,_,bytes} <> rest:
      kind ++ "  " ++ path ++ "  [" ++ bytes ++ " bytes]\n" ++ nodes_text(rest)

def directory_json(+view: Browser.View,value: Browser.Directory,+offset: U32) -> String:
  Browser.Directory{_,+path,+nodes,+total,next} = value
  "{\"kind\":\"repository_directory\"," ++ identity(view) ++ ",\"path\":" ++ Json.quote(path) ++
    ",\"offset\":" ++ U32.show(offset) ++ ",\"limit\":100,\"total\":" ++ U32.show(total) ++
    ",\"next\":" ++ next_json(next) ++ ",\"nodes\":[" ++ nodes_json(nodes) ++ "],\"text\":" ++
    Json.quote(heading(view,path) ++ "Directory entries: " ++ U32.show(total) ++
      "; page offset " ++ U32.show(offset) ++ ".\n" ++ nodes_text(nodes)) ++ "}"

def line_json(line: Browser.Line) -> String:
  Browser.Line{number,text} = line
  "{\"number\":" ++ U32.show(number) ++ ",\"text\":" ++ Json.quote(text) ++ "}"

def lines_json(lines: List<&2,Browser.Line>) -> String:
  match lines:
    case []:
      ""
    case [line]:
      line_json(line)
    case line <> rest:
      line_json(line) ++ "," ++ lines_json(rest)

def lines_text(lines: List<&2,Browser.Line>) -> String:
  match lines:
    case []:
      ""
    case Browser.Line{number,text} <> rest:
      U32.show(number) ++ "  " ++ text ++ "\n" ++ lines_text(rest)

def source_json(+view: Browser.View,value: Browser.Source) -> String:
  Browser.Source{_,+path,blob,bytes,+total,start,+lines,next,newline} = value
  "{\"kind\":\"repository_source\"," ++ identity(view) ++ ",\"path\":" ++ Json.quote(path) ++
    ",\"blob\":" ++ Json.quote(blob) ++ ",\"bytes\":" ++ Json.quote(bytes) ++
    ",\"total_lines\":" ++ U32.show(total) ++ ",\"start\":" ++ U32.show(start) ++
    ",\"lines\":[" ++ lines_json(lines) ++ "],\"next\":" ++ next_json(next) ++
    ",\"final_newline\":" ++ Bool.pick(String,newline,"true","false") ++ ",\"text\":" ++
    Json.quote(heading(view,path) ++ "Source lines: " ++ U32.show(total) ++ ".\n" ++ lines_text(lines)) ++ "}"

def tree(+view: Browser.View,path: String,+offset: U32) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Browser.Problem,Browser.Directory> <- Browser.children(view,path,offset,100)
    directory : Browser.Directory <- require(Browser.Directory,result)
    output(directory_json(view,directory,offset))

def open(repo: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Browser.Problem,Browser.View> <- Browser.open(repo)
    view : Browser.View <- require(Browser.View,result)
    tree(view,"",0)

def pinned(repo: String,id: String) -> IO(Browser.View):
  do IO<Browser.View>:
    result : Result<&2,&2,Browser.Problem,Browser.View> <- Browser.open_at(repo,id)
    require(Browser.View,result)

def pinned_tree(repo: String,id: String,path: String,offset: String) -> IO(Unit):
  do IO<Unit>:
    from : U32 <- number(P.parse_u32(offset),"offset")
    view : Browser.View <- pinned(repo,id)
    tree(view,path,from)

def evidence_json(view: Browser.View,path: String,start: U32,count: U32,why: Bool,text: String) -> String:
  "{\"kind\":" ++ Json.quote(Bool.pick(String,why,"repository_why","repository_blame")) ++
    "," ++ identity(view) ++ ",\"path\":" ++ Json.quote(path) ++
    ",\"start\":" ++ U32.show(start) ++ ",\"count\":" ++ U32.show(count) ++
    ",\"text\":" ++ Json.quote(text) ++ "}"

def selection(db: U32,mode: String,+view: Browser.View,+path: String,+start: U32,+count: U32) -> IO(Unit):
  match mode:
    case "repo-source":
      do IO<Unit>:
        result : Result<&2,&2,Browser.Problem,Browser.Source> <- Browser.source(view,path,start,count)
        source : Browser.Source <- require(Browser.Source,result)
        output(source_json(view,source))
    case _:
      +why = String.eq(mode,"repo-why")
      do IO<Unit>:
        result : Result<&2,&2,Browser.Problem,String> <- Browser.evidence(db,view,path,start,count,why)
        text : String <- require(String,result)
        output(evidence_json(view,path,start,count,why,text))

def pinned_selection(db: U32,mode: String,repo: String,id: String,path: String,start: String,count: String) -> IO(Unit):
  do IO<Unit>:
    from : U32 <- number(P.parse_u32(start),"first line")
    size : U32 <- number(P.parse_u32(count),"count")
    view : Browser.View <- pinned(repo,id)
    selection(db,mode,view,path,from,size)

def selected(db: U32,+mode: String,args: List<String>) -> IO(Unit):
  match args:
    case repo <> id <> path <> start <> count <> []:
      pinned_selection(db,mode,repo,id,path,start,count)
    case _:
      failure(Unit,"usage","usage: " ++ mode ++ " REPO COMMIT PATH FIRST COUNT; 1–100 lines")

def command(db: U32,cmd: String,args: List<String>) -> IO(Unit):
  match cmd:
    case "repo-open":
      match args:
        case repo <> []:
          open(repo)
        case _:
          failure(Unit,"usage","usage: repo-open REPO")
    case "repo-tree":
      match args:
        case repo <> id <> path <> offset <> []:
          pinned_tree(repo,id,path,offset)
        case _:
          failure(Unit,"usage","usage: repo-tree REPO COMMIT PATH OFFSET; empty PATH is the root")
    case "repo-source":
      selected(db,"repo-source",args)
    case "repo-blame":
      selected(db,"repo-blame",args)
    case "repo-why":
      selected(db,"repo-why",args)
    case _:
      failure(Unit,"usage","Unknown repository browser command")
