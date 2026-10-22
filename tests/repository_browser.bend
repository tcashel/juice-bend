import Base
import ../src/repository_browser.bend as B
import ../src/file_evidence.bend as Evidence
import ../src/repo_scope.bend as Scope
import ../src/provenance.bend as P
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ./file_evidence.bend as Fixture

def need(-A: Kind(&2),result: Result<&2,&2,B.Problem,A>) -> IO(A):
  match result:
    case Done{value}:
      IO.pure(A,value)
    case Fail{error}:
      IO.die(A,1,"FAIL browser fixture: " ++ B.problem_text(error))

def fails(-A: Kind(&2),result: Result<&2,&2,B.Problem,A>,expected: String,label: String) -> IO(Unit):
  match result:
    case Done{_}:
      IO.die(Unit,1,"FAIL expected browser error: " ++ label)
    case Fail{B.Problem{+actual,_}}:
      Fixture.assert(String.eq(actual,expected),label ++ " (" ++ actual ++ ")")

def next_is(value: Maybe<&2,U32>,expected: U32) -> Bool:
  match value:
    case Some{number}:
      U32.is_eq(number,expected)
    case None{}:
      False{}

def last(value: Maybe<&2,U32>) -> Bool:
  match value:
    case None{}:
      True{}
    case Some{_}:
      False{}

def node_found(nodes: List<&2,B.Node>,+path: String,+kind: String) -> Bool:
  match nodes:
    case []:
      False{}
    case B.Node{actual,actual_kind,_,_} <> rest:
      (String.eq(actual,path) && String.eq(actual_kind,kind)) || node_found(rest,path,kind)

def lines_equal(lines: List<&2,B.Line>,expected: List<&2,B.Line>) -> Bool:
  match lines expected:
    case Nil{} Nil{}:
      True{}
    case Con{B.Line{a,x},rest} Con{B.Line{b,y},tail}:
      U32.is_eq(a,b) && String.eq(x,y) && lines_equal(rest,tail)
    case _ _:
      False{}

def source_fields(value: B.Source,commit: String,path: String,total: U32,start: U32,
  expected: List<&2,B.Line>,label: String) -> IO(Unit):
  B.Source{actual_commit,actual_path,blob,bytes,actual_total,actual_start,lines,next,newline} = value
  Fixture.assert(String.eq(actual_commit,commit) && String.eq(actual_path,path) &&
    U32.is_eq(actual_total,total) && U32.is_eq(actual_start,start) && lines_equal(lines,expected),label)

def source_expected(result: Result<&2,&2,B.Problem,B.Source>,commit: String,path: String,
  total: U32,start: U32,expected: List<&2,B.Line>,label: String) -> IO(Unit):
  do IO<Unit>:
    value : B.Source <- need(B.Source,result)
    source_fields(value,commit,path,total,start,expected,label)

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    result : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(result)

def make_files(fuel: Nat,+root: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Store.write_text(root ++ "/file-" ++ U32.show(index) ++ ".txt","w","bounded child\n")
        make_files(rest,root,U32.inc(index))

def source_rows(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+rest:
      "row " ++ U32.show(index) ++ "\n" ++ source_rows(rest,U32.inc(index))

def commit_all(+repo: String,message: String) -> IO(String):
  do IO<String>:
    added : String <- Fixture.git(repo,["add","--all"])
    committed : String <- Fixture.git(repo,["commit","--quiet","-m",message])
    sha : String <- Fixture.git(repo,["rev-parse","HEAD"])
    return String.trim(sha)

def pure() -> IO(Unit):
  +sha = {"1234567890123456789012345678901234567890" : String}
  do IO<Unit>:
    fails(List<&2,B.Node>,B.tree_result(Done{"100644 blob " ++ sha ++ " 7\tfile"},""),
      "invalid_tree","truncated tree output never becomes a complete directory")
    fails(List<&2,B.Node>,B.tree_result(Done{"100644 blob " ++ sha ++ " 7\t../outside\0"},""),
      "unsupported_tree_entry","tree paths cannot traverse out of the repository")
    fails(List<&2,B.Node>,B.tree_result(Done{"100644 blob " ++ sha ++ " 7\tbroken�name\0"},""),
      "unsupported_tree_entry","lossy decoded filename is rejected")
    fails(List<&2,B.Node>,B.tree_result(Done{String.repeat("100644 blob " ++ sha ++ " 7\tfile\0",4097n)},""),
      "directory_too_large","directory hard bound rejects excess entries instead of silently dropping them")
    fails(List<&2,P.Region>,B.parsed_blame(Done{[P.Region{sha,1,2,"0","wrong"}]},[B.Line{2,"expected"}]),
      "invalid_blame","source text mismatch cannot be presented as pinned blame")
    fails(List<&2,P.Region>,B.parsed_blame(Done{[]},[B.Line{2,"expected"}]),
      "invalid_blame","missing blame lines cannot become a successful selection")

def root_fields(value: B.Directory,id: String) -> IO(Unit):
  B.Directory{commit,path,+nodes,_,_} = value
  do IO<Unit>:
    Fixture.assert(String.eq(commit,id) && String.eq(path,"") &&
      node_found(nodes,"many","directory") && node_found(nodes,"nested space","directory"),
      "root page has pinned identity and immediate directory nodes")
    Fixture.assert(node_found(nodes,"symbolic","symlink") && node_found(nodes,"linked","submodule"),
      "symlink and gitlink are classified without opening their targets")
    Fixture.assert(Bool.not(node_found(nodes,"nested space/deep.txt","file")),
      "root listing does not recursively enumerate nested directories")

def first_fields(value: B.Directory,id: String) -> IO(Unit):
  B.Directory{commit,path,+nodes,total,next} = value
  Fixture.assert(String.eq(commit,id) && String.eq(path,"many") && U32.is_eq(total,107) &&
    Nat.is_eq(List.length(&2,B.Node,nodes),100n) && next_is(next,100) &&
    node_found(nodes,"many/file-0.txt","file") && Bool.not(node_found(nodes,"many/file-99.txt","file")),
    "first directory page follows stable Git tree order and exposes exact continuation")

def second_fields(value: B.Directory,id: String) -> IO(Unit):
  B.Directory{commit,_,+nodes,total,next} = value
  Fixture.assert(String.eq(commit,id) && U32.is_eq(total,107) && Nat.is_eq(List.length(&2,B.Node,nodes),7n) &&
    last(next) && node_found(nodes,"many/file-99.txt","file"),"second directory page returns remaining seven entries")

def empty_fields(value: B.Directory) -> IO(Unit):
  B.Directory{_,_,nodes,total,next} = value
  Fixture.assert(List.is_empty(&2,B.Node,nodes) && U32.is_eq(total,107) && last(next),
    "directory offset at total is an explicit final empty page")

def listing(+view: B.View,+id: String) -> IO(Unit):
  do IO<Unit>:
    root_result : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"",0,100)
    root : B.Directory <- need(B.Directory,root_result)
    root_fields(root,id)
    first_result : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"many",0,100)
    first : B.Directory <- need(B.Directory,first_result)
    first_fields(first,id)
    second_result : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"many",100,100)
    second : B.Directory <- need(B.Directory,second_result)
    second_fields(second,id)
    empty_result : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"many",107,100)
    empty : B.Directory <- need(B.Directory,empty_result)
    empty_fields(empty)
    too_far : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"many",108,100)
    fails(B.Directory,too_far,"invalid_range","directory offsets beyond the stable total fail clearly")
    traversal : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"../outside",0,100)
    fails(B.Directory,traversal,"invalid_request","directory traversal is rejected before Git")
    zero : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"",0,0)
    fails(B.Directory,zero,"invalid_request","zero directory page size is rejected")

def unsupported(+view: B.View) -> IO(Unit):
  do IO<Unit>:
    symlink : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"symbolic",1,1)
    fails(B.Source,symlink,"unsupported_symlink","source refuses symlink target bytes")
    through : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"symbolic/secret.txt",1,1)
    fails(B.Source,through,"not_in_revision","path below symlink never follows filesystem target")
    linked : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"linked",1,1)
    fails(B.Source,linked,"unsupported_submodule","gitlink does not traverse into another repository")
    directory : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"many",1,1)
    fails(B.Source,directory,"unsupported_directory","directory is not misread as a source blob")
    not_directory : Result<&2,&2,B.Problem,B.Directory> <- B.children(view,"symbolic",0,10)
    fails(B.Directory,not_directory,"not_directory","tree navigation refuses a symlink")
    binary : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"binary.dat",1,1)
    fails(B.Source,binary,"unsupported_binary","NUL blob is explicitly unsupported binary")
    encoding : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"invalid-utf8.dat",1,1)
    fails(B.Source,encoding,"unsupported_encoding","invalid UTF8 subprocess replacement is not displayed as source")
    replacement : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"replacement.txt",1,1)
    fails(B.Source,replacement,"unsupported_encoding","literal replacement scalar is conservatively unsupported")
    big : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"large.txt",1,1)
    fails(B.Source,big,"source_too_large","over-limit blob rejected from metadata before content read")
    absent : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"missing.txt",1,1)
    fails(B.Source,absent,"not_in_revision","missing committed path has explicit revision-relative absence")
    untracked : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"untracked.txt",1,1)
    fails(B.Source,untracked,"not_in_revision","untracked working-tree content is not exposed")
    staged : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"staged-only.txt",1,1)
    fails(B.Source,staged,"not_in_revision","staged-only content is not claimed as committed source")
    traversal : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"nested space/../../outside/secret.txt",1,1)
    fails(B.Source,traversal,"invalid_request","source traversal is rejected before lookup")

def exact_fields(result: Result<&2,&2,B.Problem,B.Source>) -> IO(Unit):
  match result:
    case Done{B.Source{_,_,_,bytes,1,1,[B.Line{1,text}],next,False{}}}:
      Fixture.assert(String.eq(bytes,"262144") && Nat.is_eq(String.length(text),262144n) && last(next),
        "exact 256KiB blob limit preserves the complete long line")
    case _:
      IO.die(Unit,1,"FAIL exact-limit source shape")

def pages(+view: B.View,+id: String) -> IO(Unit):
  do IO<Unit>:
    initial : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"a.bend",1,2)
    source_expected(initial,id,"a.bend",3,1,[B.Line{1,"alpha"},B.Line{2,"βeta"}],
      "source preserves original Unicode text and exact 1-based lines")
    final : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"a.bend",3,100)
    source_expected(final,id,"a.bend",3,3,[B.Line{3,"omega"}],"last unterminated line remains a line without phantom trailing content")
    empty : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"empty.txt",1,100)
    source_expected(empty,id,"empty.txt",0,1,[],"empty blob has zero source lines")
    blanks : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"blank-lines.txt",1,100)
    source_expected(blanks,id,"blank-lines.txt",2,1,[B.Line{1,""},B.Line{2,""}],"two newlines represent exactly two empty lines")
    crlf : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"crlf.txt",1,100)
    source_expected(crlf,id,"crlf.txt",2,1,[B.Line{1,"one\r"},B.Line{2,"two\r"}],"CRLF retains source carriage returns without adding a terminal line")
    nested : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"nested space/deep.txt",1,1)
    source_expected(nested,id,"nested space/deep.txt",1,1,[B.Line{1,"nested literal"}],"nested directory and space path resolve literally")
    option : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"--help",1,1)
    source_expected(option,id,"--help",1,1,[B.Line{1,"option name"}],"option-like filename never becomes a Git option")
    magic : Result<&2,&2,B.Problem,B.Source> <- B.source(view,":(glob)*",1,1)
    source_expected(magic,id,":(glob)*",1,1,[B.Line{1,"literal magic"}],"pathspec magic is treated as an exact filename")
    late : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"rows.txt",128,100)
    source_expected(late,id,"rows.txt",130,128,[B.Line{128,"row 128"},B.Line{129,"row 129"},B.Line{130,"row 130"}],
      "bounded late source page ends at the actual committed line count")
    invalid : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"rows.txt",131,10)
    fails(B.Source,invalid,"invalid_range","source start after final line is rejected")
    zero : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"rows.txt",0,10)
    fails(B.Source,zero,"invalid_request","zero source line is rejected")
    over : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"rows.txt",1,101)
    fails(B.Source,over,"invalid_request","source line page cannot exceed 100")
    overflow : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"rows.txt",4294967295,2)
    fails(B.Source,overflow,"invalid_request","source line arithmetic cannot wrap at U32")
    exact : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"exact-limit.txt",1,1)
    exact_fields(exact)

def commit_message(result: Result<&2,&2,String,String>) -> IO(Unit):
  match result:
    case Done{text}:
      Fixture.assert(String.eq(String.trim(text),"pinned tree"),
        "shared file-evidence helper ignores replacement commit message")
    case Fail{error}:
      IO.die(Unit,1,"FAIL production commit metadata helper: " ++ error)

def literal_diff(value: Evidence.Commit) -> IO(Unit):
  match value:
    case Evidence.Commit{_,_,_,_,[Evidence.HunkResult{1,1,P.Content{"literal-key",1n,1n}}],""}:
      Fixture.assert(True{},"production commit diff selects literal magic filename rather than decoy file")
    case _:
      IO.die(Unit,1,"FAIL literal pathspec commit diff selected wrong content")

def evidence_checks(+view: B.View,+repo: String,+id: String,+future: String,base: String) -> IO(Unit):
  do IO<Unit>:
    regions_result : Result<&2,&2,B.Problem,List<&2,P.Region>> <- B.blame(view,"a.bend",1,3)
    +regions : List<&2,P.Region> <- need(List<&2,P.Region>,regions_result)
    Fixture.assert(B.regions_match(regions,[B.Line{1,"alpha"},B.Line{2,"βeta"},B.Line{3,"omega"}]),
      "explicit-commit blame retains old selected text after HEAD and worktree move")
    option_result : Result<&2,&2,B.Problem,List<&2,P.Region>> <- B.blame(view,"--help",1,1)
    option : List<&2,P.Region> <- need(List<&2,P.Region>,option_result)
    Fixture.assert(B.regions_match(option,[B.Line{1,"option name"}]),"blame also protects option-like paths")
    literal_result : Result<&2,&2,B.Problem,List<&2,P.Region>> <- B.blame(view,":(literal)decoy.txt",1,1)
    literal : List<&2,P.Region> <- need(List<&2,P.Region>,literal_result)
    Fixture.assert(B.regions_match(literal,[B.Line{1,"literal target line"}]),"magic filename blame cannot substitute a decoy file")
    literal_commit : Evidence.Commit <- Evidence.load_commit(repo,repo,":(literal)decoy.txt",base,[],
      [P.Candidate{repo,"literal-key","0",["literal target line"],True{}}])
    literal_diff(literal_commit)
    replaced : String <- Fixture.git(repo,["replace",id,future])
    +again : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"a.bend",1,1)
    source_expected(again,id,"a.bend",3,1,[B.Line{1,"alpha"}],"replacement object cannot alter pinned committed source")
    after_replace : Result<&2,&2,B.Problem,List<&2,P.Region>> <- B.blame(view,"a.bend",1,3)
    unchanged : List<&2,P.Region> <- need(List<&2,P.Region>,after_replace)
    Fixture.assert(B.regions_match(unchanged,[B.Line{1,"alpha"},B.Line{2,"βeta"},B.Line{3,"omega"}]),
      "replacement object cannot alter pinned blame source text")
    +db : U32 <- Store.open(".build/browser.sqlite")
    result : Result<&2,&2,B.Problem,String> <- B.evidence(db,view,"a.bend",1,1,True{})
    +text : String <- need(String,result)
    Fixture.assert(String.contains(text,"Pinned commit tree: " ++ id) && String.contains(text,"alpha") &&
      Bool.not(String.contains(text,"replacement rationale")) && String.contains(text,"not_indexed"),
      "pinned evidence includes its commit and honest missing-capture state without replacement metadata")
    message_result : Result<&2,&2,String,String> <- Evidence.git(repo,["show","-s","--format=%B",id,"--"])
    commit_message(message_result)
    IO.try(Unit,Sql.close(db))

def fixture(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  do IO<Unit>:
    initialized : String <- Fixture.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    directories : String <- Fixture.command("/bin/mkdir",[repo ++ "/many",repo ++ "/nested space",root ++ "/outside"])
    Store.write_text(root ++ "/outside/secret.txt","w","outside target must never be read\n")
    symlink : String <- Fixture.command("/bin/ln",["-s",root ++ "/outside",repo ++ "/symbolic"])
    Store.write_text(repo ++ "/a.bend","w","alpha\nβeta\nomega")
    Store.write_text(repo ++ "/nested space/deep.txt","w","nested literal\n")
    Store.write_text(repo ++ "/--help","w","option name\n")
    Store.write_text(repo ++ "/:(glob)*","w","literal magic\n")
    Store.write_text(repo ++ "/:(literal)decoy.txt","w","literal target line\n")
    Store.write_text(repo ++ "/decoy.txt","w","decoy sentinel\n")
    Store.write_text(repo ++ "/empty.txt","w","")
    Store.write_text(repo ++ "/blank-lines.txt","w","\n\n")
    Store.write_text(repo ++ "/crlf.txt","w","one\r\ntwo\r\n")
    Store.write_text(repo ++ "/rows.txt","w",source_rows(130n,1))
    Store.write_text(repo ++ "/binary.dat","w","before\0after")
    write_bytes(repo ++ "/invalid-utf8.dat",[255,10])
    Store.write_text(repo ++ "/replacement.txt","w","literal �\n")
    Store.write_text(repo ++ "/large.txt","w",String.repeat("a",262145n))
    Store.write_text(repo ++ "/exact-limit.txt","w",String.repeat("b",262144n))
    Store.write_text(repo ++ "/.gitattributes","w","a.bend diff=browser-test\n")
    make_files(107n,repo ++ "/many",0)
    +base : String <- commit_all(repo,"base source")
    linked : String <- Fixture.git(repo,["update-index","--add","--cacheinfo","160000," ++ base ++ ",linked"])
    pinned_commit : String <- Fixture.git(repo,["commit","--quiet","-m","pinned tree"])
    opened : Result<&2,&2,B.Problem,B.View> <- B.open(repo)
    +view : B.View <- need(B.View,opened)
    +id : String = B.commit(view)
    future : String <- Fixture.git(repo,["config","diff.external","/usr/bin/false"])
    textconv : String <- Fixture.git(repo,["config","diff.browser-test.textconv","/usr/bin/false"])
    Store.write_text(repo ++ "/untracked.txt","w","private untracked content")
    Store.write_text(repo ++ "/staged-only.txt","w","private staged content")
    staged : String <- Fixture.git(repo,["add","--","staged-only.txt"])
    +before : String <- Fixture.git(repo,["hash-object","--no-filters","--",".git/index"])
    listing(view,id)
    pages(view,id)
    unsupported(view)
    after : String <- Fixture.git(repo,["hash-object","--no-filters","--",".git/index"])
    Fixture.assert(String.eq(before,after),"browser queries leave synthetic Git index bytes unchanged")
    Store.write_text(repo ++ "/a.bend","w","new HEAD contents\n")
    +new_id : String <- commit_all(repo,"replacement rationale")
    Store.write_text(repo ++ "/a.bend","w","dirty worktree contents\n")
    old_again : Result<&2,&2,B.Problem,B.Source> <- B.source(view,"a.bend",1,1)
    source_expected(old_again,id,"a.bend",3,1,[B.Line{1,"alpha"}],"pinned source ignores newer commit and dirty worktree")
    refreshed : Result<&2,&2,B.Problem,B.View> <- B.open(repo)
    +new_view : B.View <- need(B.View,refreshed)
    Fixture.assert(String.eq(B.commit(new_view),new_id) && Bool.not(String.eq(id,new_id)),
      "opening an explicit new view observes new HEAD without mutating old view")
    new_source : Result<&2,&2,B.Problem,B.Source> <- B.source(new_view,"a.bend",1,1)
    source_expected(new_source,new_id,"a.bend",1,1,[B.Line{1,"new HEAD contents"}],
      "new view still reads committed blob rather than dirty worktree")
    evidence_checks(view,repo,id,new_id,base)

def append_commits(fuel: Nat,+repo: String,+index: U32) -> IO(List<&2,String>):
  match fuel:
    case 0n:
      IO.pure(List<&2,String>,[])
    case 1n+rest:
      do IO<List<&2,String>>:
        Store.write_text(repo ++ "/lines.txt","a","distinct row " ++ U32.show(index) ++ "\n")
        id : String <- commit_all(repo,"append row " ++ U32.show(index))
        tail : List<&2,String> <- append_commits(rest,repo,U32.inc(index))
        return id <> tail

def commits_match(regions: List<&2,P.Region>,ids: List<&2,String>) -> Bool:
  match regions ids:
    case Nil{} Nil{}:
      True{}
    case Con{P.Region{actual,_,_,_,_},rest} Con{expected,tail}:
      String.eq(actual,expected) && commits_match(rest,tail)
    case _ _:
      False{}

def wide_selection(root: String) -> IO(Unit):
  +repo = root ++ "/nine-commits"
  do IO<Unit>:
    initialized : String <- Fixture.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet",repo])
    Store.write_text(repo ++ "/lines.txt","w","")
    +ids : List<&2,String> <- append_commits(9n,repo,1)
    opened : Result<&2,&2,B.Problem,B.View> <- B.open(repo)
    +view : B.View <- need(B.View,opened)
    blamed : Result<&2,&2,B.Problem,List<&2,P.Region>> <- B.blame(view,"lines.txt",1,9)
    +regions : List<&2,P.Region> <- need(List<&2,P.Region>,blamed)
    Fixture.assert(Nat.is_eq(List.length(&2,String,ids),9n) &&
      Nat.is_eq(List.length(&2,P.Region,regions),9n) && commits_match(regions,ids),
      "nine-line fixture resolves each line to its independently created distinct commit")
    +db : U32 <- Store.open(".build/browser-wide.sqlite")
    wide : Result<&2,&2,B.Problem,String> <- B.evidence(db,view,"lines.txt",1,9,True{})
    fails(String,wide,"evidence_range_too_wide","nine-commit evidence range returns structured error without terminating worker")
    allowed : Result<&2,&2,B.Problem,String> <- B.evidence(db,view,"lines.txt",1,8,True{})
    +text : String <- need(String,allowed)
    Fixture.assert(String.contains(text,"Pinned commit tree: " ++ B.commit(view)) &&
      String.contains(text,"Line 8 ·") && Bool.not(String.contains(text,"Line 9 ·")),
      "same worker still produces bounded evidence for exactly eight commits")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    +root : String <- IO.try(String,IO.get_env("PWD"))
    Fixture.assert(String.contains(root,"juice-bend-test-repository_browser."),"all browser fixture writes are scoped to isolated test root")
    pure()
    fixture(root)
    wide_selection(root)
