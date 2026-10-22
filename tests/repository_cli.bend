import Base
import ../src/cli.bend as Cli
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/provenance.bend as P
import ../src/paths.bend as Paths
import ./file_evidence.bend as Fixture
import ./repository_browser.bend as BrowserFixture

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{error}:
      IO.die(Json.Json,1,"FAIL repository CLI JSON: " ++ error)

def execute(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"command" <> args,"",1048576,30000))

def good_result(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    Fixture.assert(U32.is_eq(code,0) && String.is_empty(err),"repository command exits successfully without stderr")
    parsed(Json.parse(String.trim(out)))

def good(self: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- execute(self,args)
    good_result(result)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  Fixture.assert(String.eq(Json.encode(Json.field(value,key)),expected),label)

def bad_result(result: U32 & (String & String),expected: String,+label: String) -> IO(Unit):
  (code,(out,err)) = result
  do IO<Unit>:
    Fixture.assert(U32.is_eq(code,2) && String.is_empty(out),label ++ " has nonzero exit and no success output")
    +value : Json.Json <- parsed(Json.parse(String.trim(err)))
    Fixture.assert(String.eq(Json.text(Json.field(value,"code")),expected) &&
      Bool.not(String.is_empty(Json.text(Json.field(value,"error")))),label ++ " has structured code and error")

def bad(self: String,args: List<String>,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,args)
    bad_result(result,code,label)

def first_node(nodes: Json.Json) -> Json.Json:
  match nodes:
    case Json.JArray{node <> _}:
      node
    case _:
      Json.JNull{}

def array_size(value: Json.Json) -> Nat:
  match value:
    case Json.JArray{rows}:
      List.length(&2,Json.Json,rows)
    case _:
      9999n

def expected_lines(value: Json.Json) -> Bool:
  match value:
    case Json.JArray{[+first,+second]}:
      String.eq(Json.encode(Json.field(first,"number")),"1") &&
        String.eq(Json.text(Json.field(first,"text")),"first \"quoted\" café") &&
        String.eq(Json.encode(Json.field(second,"number")),"2") &&
        String.eq(Json.text(Json.field(second,"text")),"second\tline")
    case _:
      False{}

def pages(+self: String,+repo: String,+id: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    +first : Json.Json <- good(self,["repo-tree",repo,id,"many","0"])
    field(first,"kind","\"repository_directory\"","tree has stable directory kind")
    field(first,"commit",Json.quote(id),"tree echoes exact requested commit")
    field(first,"path","\"many\"","tree directory identity is explicit")
    field(first,"offset","0","directory offset is numeric")
    field(first,"limit","100","directory limit is fixed numeric100")
    field(first,"total","101","directory total is exact")
    field(first,"next","100","first tree page exposes numeric continuation")
    Fixture.assert(Nat.is_eq(array_size(Json.field(first,"nodes")),100n),"first tree page has exactly100 nodes")
    +node : Json.Json = first_node(Json.field(first,"nodes"))
    field(node,"kind","\"file\"","directory node kind is explicit")
    field(node,"bytes","\"14\"","node byte size remains a decimal string")
    Fixture.assert(P.valid_sha(Json.text(Json.field(node,"object"))),"node object identity is a complete SHA1")
    +last : Json.Json <- good(self,["repo-tree",repo,id,"many","100"])
    field(last,"next","null","last tree page has null continuation")
    Fixture.assert(Nat.is_eq(array_size(Json.field(last,"nodes")),1n),"last tree page returns one remaining child")
    +source : Json.Json <- good(self,["repo-source",repo,id,path,"1","2"])
    field(source,"kind","\"repository_source\"","source has distinct result kind")
    field(source,"repository",Json.quote(repo),"source canonical repository is JSON escaped")
    field(source,"checkout",Json.quote(repo),"source retains actual checkout separately")
    field(source,"path",Json.quote(path),"source path round-trips spaces Unicode quotes")
    field(source,"total_lines","3","source line total is numeric")
    field(source,"start","1","source start is numeric and1-based")
    field(source,"next","3","source continuation is next1-based line")
    field(source,"final_newline","false","source final-newline state is boolean")
    Fixture.assert(expected_lines(Json.field(source,"lines")),"source line JSON preserves quotes tabs and Unicode exactly")
    Fixture.assert(String.contains(Json.text(Json.field(source,"text")),"Commit: " ++ id) &&
      String.contains(Json.text(Json.field(source,"text")),"1  first \"quoted\" café"),
      "source readable text contains committed identity and line numbers")
    +tail : Json.Json <- good(self,["repo-source",repo,id,path,"3","40"])
    field(tail,"next","null","source final short page disables continuation")
    Fixture.assert(Nat.is_eq(array_size(Json.field(tail,"lines")),1n),"source final short page clamps atEOF")
    +literal : Json.Json <- good(self,["repo-source",repo,id,":(literal)decoy.txt","1","1"])
    Fixture.assert(String.contains(Json.text(Json.field(literal,"text")),"actual literal") &&
      Bool.not(String.contains(Json.text(Json.field(literal,"text")),"decoy sentinel")),"CLI preserves literal pathspec-looking filename")
    +root : Json.Json <- good(self,["repo-tree",repo,id,"","0"])
    field(root,"path","\"\"","empty path explicitly requests pinned tree root")

def invalid(+self: String,+repo: String,+id: String,+path: String,blob: String) -> IO(Unit):
  do IO<Unit>:
    bad(self,["repo-open"],"usage","missing explicit repository")
    bad(self,["repo-tree",repo,id,""],"usage","missing directory offset")
    bad(self,["repo-source",repo,id,path,"1"],"usage","missing source count")
    bad(self,["repo-source",repo,"HEAD",path,"1","1"],"invalid_commit","symbolic revision is rejected")
    bad(self,["repo-tree",repo,String.take(id,12n),"","0"],"invalid_commit","abbreviated revision is rejected")
    bad(self,["repo-tree",repo,blob,"","0"],"invalid_commit","blob object is not accepted as a commit")
    bad(self,["repo-tree",repo,"ffffffffffffffffffffffffffffffffffffffff","","0"],"missing_commit","missing commit never repins HEAD")
    bad(self,["repo-tree",repo,id,"../outside","0"],"invalid_request","directory traversal")
    bad(self,["repo-source",repo,id,"../outside","1","1"],"invalid_request","source traversal")
    bad(self,["repo-source",repo,id,"untracked.txt","1","1"],"not_in_revision","untracked file")
    bad(self,["repo-source",repo,id,"missing.txt","1","1"],"not_in_revision","absent committed path")
    bad(self,["repo-source",repo,id,"symbolic","1","1"],"unsupported_symlink","symlink source")
    bad(self,["repo-source",repo,id,"binary.dat","1","1"],"unsupported_binary","binary source")
    bad(self,["repo-source",repo,id,"large-json.txt","1","1"],"output_too_large","escaped output larger than worker bound")
    bad(self,["repo-source",repo,id,path,"0","1"],"invalid_request","zero source line")
    bad(self,["repo-source",repo,id,path,"1","101"],"invalid_request","oversized source page")
    bad(self,["repo-source",repo,id,path,"4","1"],"invalid_range","source beyond final line")
    bad(self,["repo-tree",repo,id,"many","102"],"invalid_range","directory beyond total")
    bad(self,["repo-tree",repo,id,"many","4294967296"],"invalid_number","overflowing offset")
    bad(self,["repo-source",repo,id,path,"bad","1"],"invalid_number","nonnumeric source line")

def evidence(+self: String,+repo: String,+id: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    +blame : Json.Json <- good(self,["repo-blame",repo,id,path,"1","2"])
    field(blame,"kind","\"repository_blame\"","blame JSON kind is explicit")
    field(blame,"commit",Json.quote(id),"blame remains pinned to selected commit")
    field(blame,"start","1","blame source start is numeric")
    field(blame,"count","2","blame requested count is numeric")
    Fixture.assert(String.contains(Json.text(Json.field(blame,"text")),"first \"quoted\" café") &&
      Bool.not(String.contains(Json.text(Json.field(blame,"text")),"dirty worktree")),"blame worker uses pinned source rather than dirty working tree")
    +why : Json.Json <- good(self,["repo-why",repo,id,path,"3","1"])
    field(why,"kind","\"repository_why\"","Why JSON kind is explicit")
    field(why,"path",Json.quote(path),"Why preserves exact selected file")
    Fixture.assert(String.contains(Json.text(Json.field(why,"text")),"Pinned commit tree: " ++ id) &&
      String.contains(Json.text(Json.field(why,"text")),"not_indexed"),"Why keeps pinned identity and honest uncaptured result")

def worktree(+self: String,+root: String,+repo: String,+id: String,+path: String) -> IO(Unit):
  +checkout = root ++ "/linked checkout"
  do IO<Unit>:
    created : String <- Fixture.git(repo,["worktree","add","--quiet","--detach",checkout,id])
    +opened : Json.Json <- good(self,["repo-open",checkout])
    field(opened,"repository",Json.quote(repo),"linked worktree retains primary canonical repository")
    field(opened,"checkout",Json.quote(checkout),"linked worktree exposes its actual checkout")
    field(opened,"commit",Json.quote(id),"linked worktree pins its own HEAD rather than primary HEAD")
    +source : Json.Json <- good(self,["repo-source",Json.text(Json.field(opened,"checkout")),id,path,"1","2"])
    Fixture.assert(expected_lines(Json.field(source,"lines")),"source command using returned checkout preserves linked worktree commit")

def suite(+self: String,+root: String) -> IO(Unit):
  +repo = root ++ "/repository \"quoted\""
  +path = {"src dir/café \"notes\".txt" : String}
  do IO<Unit>:
    initialized : String <- Fixture.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    made : String <- Fixture.command("/bin/mkdir",[repo ++ "/src dir",repo ++ "/many"])
    Store.write_text(repo ++ "/" ++ path,"w","first \"quoted\" café\nsecond\tline\nlast😀")
    Store.write_text(repo ++ "/binary.dat","w","bad\0binary")
    Store.write_text(repo ++ "/large-json.txt","w",String.repeat("\"",262144n))
    Store.write_text(repo ++ "/:(literal)decoy.txt","w","actual literal\n")
    Store.write_text(repo ++ "/decoy.txt","w","decoy sentinel\n")
    linked : String <- Fixture.command("/bin/ln",["-s",root,repo ++ "/symbolic"])
    BrowserFixture.make_files(101n,repo ++ "/many",0)
    +id : String <- BrowserFixture.commit_all(repo,"original pinned source")
    +opened : Json.Json <- good(self,["repo-open",repo])
    field(opened,"kind","\"repository_directory\"","repo-open returns initial directory")
    field(opened,"commit",Json.quote(id),"repo-open pins observed HEAD once")
    field(opened,"path","\"\"","repo-open begins at tree root")
    +blob : String <- Fixture.git(repo,["rev-parse",id ++ ":" ++ path])
    Store.write_text(repo ++ "/untracked.txt","w","untracked contents")
    pages(self,repo,id,path)
    invalid(self,repo,id,path,String.trim(blob))
    Store.write_text(repo ++ "/" ++ path,"w","new committed source\n")
    +new_id : String <- BrowserFixture.commit_all(repo,"later HEAD")
    Store.write_text(repo ++ "/" ++ path,"w","dirty worktree\n")
    +again : Json.Json <- good(self,["repo-source",repo,id,path,"1","2"])
    Fixture.assert(expected_lines(Json.field(again,"lines")),"later worker reconstructs old commit without repinning moved HEAD")
    +latest : Json.Json <- good(self,["repo-open",repo])
    field(latest,"commit",Json.quote(new_id),"only explicit new repo-open observes changed HEAD")
    evidence(self,repo,id,path)
    worktree(self,root,repo,id,path)
    +help : Json.Json <- good(self,["help"])
    Fixture.assert(String.contains(Json.encode(Json.field(help,"commands")),"repo-why REPO COMMIT PATH FIRST COUNT"),
      "CLI help advertises the pinned repository commands")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      do IO<Unit>:
        +requested : String <- IO.try(String,IO.get_env("PWD"))
        Fixture.assert(String.contains(requested,"juice-bend-test-repository_cli."),"CLI fixture is isolated from real repositories")
        root : String <- Paths.resolve(requested)
        suite(self,root)
    case _ <> "command" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/repository-cli.sqlite")
        Cli.command(db,"",command,rest)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Unsupported repository CLI test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
