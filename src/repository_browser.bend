import Base
import ./repo_scope.bend as Scope
import ./provenance.bend as P
import ./file_evidence.bend as Evidence
import ./domain.bend as Domain

# A browser view is a pinned committed tree, never working-tree contents.
# Git objects supply paths and bytes: no directory walk, file read, symlink
# following, textconv, external diff, replacement objects or lazy network fetch.
type Problem is Data:
  Problem{code: String,detail: String}

type Split is Data:
  Split{header: String,path: String}

type View is Data:
  View{scope: Scope.Scope,commit: String}

type Node is Data:
  Node{path: String,kind: String,object: String,bytes: String}

type Directory is Data:
  Directory{commit: String,path: String,nodes: List<&2,Node>,total: U32,next: Maybe<&2,U32>}

type Line is Data:
  Line{number: U32,text: String}

type Source is Data:
  Source{commit: String,path: String,blob: String,bytes: String,total_lines: U32,
    start: U32,lines: List<&2,Line>,next: Maybe<&2,U32>,final_newline: Bool}

def problem_text(problem: Problem) -> String:
  Problem{code,detail} = problem
  code ++ ": " ++ detail

def commit(view: View) -> String:
  View{_,value} = view
  value

def scope(view: View) -> Scope.Scope:
  View{value,_} = view
  value

def view_valid(+view: View) -> Bool:
  P.safe_repo(Scope.checkout(scope(view))) && P.valid_sha(commit(view)) &&
    Bool.not(P.uncommitted(commit(view)))

def converted(result: Result<&2,&2,String,String>) -> Result<&2,&2,Problem,String>:
  match result:
    case Done{text}:
      Done{text}
    case Fail{detail}:
      Fail{Problem{"git_unavailable",detail}}

# The existing helper supplies the fixed executable, disabled hooks/fsmonitor/
# attributes/helpers, and a combined 1MiB/3s process bound. Its global flags
# prevent object replacement, pathspec expansion and lazy fetching.
def git(view: View,args: List<String>) -> IO(Result<&2,&2,Problem,String>):
  do IO<Result<&2,&2,Problem,String>>:
    result : Result<&2,&2,String,String> <- Evidence.git(Scope.checkout(scope(view)),args)
    return converted(result)

def opened(result: Result<&2,&2,String,String>,scope: Scope.Scope) -> Result<&2,&2,Problem,View>:
  match result:
    case Fail{_}:
      Fail{Problem{"missing_commit","HEAD has no readable committed revision"}}
    case Done{text}:
      +id = String.trim(text)
      Bool.pick(Result<&2,&2,Problem,View>,P.valid_sha(id) && Bool.not(P.uncommitted(id)),
        Done{View{scope,id}},Fail{Problem{"unsupported_object_format","Require an exact SHA-1 commit identity"}})

def open_scope(result: Result<&2,&2,String,Scope.Scope>) -> IO(Result<&2,&2,Problem,View>):
  match result:
    case Fail{detail}:
      IO.pure(Result<&2,&2,Problem,View>,Fail{Problem{"invalid_repository",detail}})
    case Done{+resolved}:
      do IO<Result<&2,&2,Problem,View>>:
        result : Result<&2,&2,String,String> <- Evidence.git(Scope.checkout(resolved),
          ["--no-lazy-fetch","--no-replace-objects","rev-parse","--verify","HEAD^{commit}"])
        return opened(result,resolved)

def open(repo: String) -> IO(Result<&2,&2,Problem,View>):
  do IO<Result<&2,&2,Problem,View>>:
    resolved : Result<&2,&2,String,Scope.Scope> <- Scope.resolve(repo)
    open_scope(resolved)

# Subsequent worker commands reconstruct canonical scope while retaining the
# exact requested commit. A tag/tree/blob or missing object is not repinned.
def at_object(result: Result<&2,&2,String,String>,scope: Scope.Scope,id: String) -> Result<&2,&2,Problem,View>:
  match result:
    case Done{text}:
      Bool.pick(Result<&2,&2,Problem,View>,String.eq(String.trim(text),"commit"),
        Done{View{scope,id}},Fail{Problem{"invalid_commit","Requested object is not a commit"}})
    case Fail{_}:
      Fail{Problem{"missing_commit","Requested commit is unavailable in this repository"}}

def at_scope(result: Result<&2,&2,String,Scope.Scope>,+id: String) -> IO(Result<&2,&2,Problem,View>):
  match result:
    case Fail{detail}:
      IO.pure(Result<&2,&2,Problem,View>,Fail{Problem{"invalid_repository",detail}})
    case Done{+resolved}:
      do IO<Result<&2,&2,Problem,View>>:
        result : Result<&2,&2,String,String> <- Evidence.git(Scope.checkout(resolved),["cat-file","-t",id])
        return at_object(result,resolved,id)

def at_valid(valid: Bool,repo: String,id: String) -> IO(Result<&2,&2,Problem,View>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,Problem,View>,Fail{Problem{"invalid_commit","Require an exact nonzero lowercase SHA-1 commit identity"}})
    case True{}:
      do IO<Result<&2,&2,Problem,View>>:
        resolved : Result<&2,&2,String,Scope.Scope> <- Scope.resolve(repo)
        at_scope(resolved,id)

def open_at(repo: String,+id: String) -> IO(Result<&2,&2,Problem,View>):
  at_valid(P.valid_sha(id) && Bool.not(P.uncommitted(id)),repo,id)

def words(xs: List<&2,String>) -> List<&2,String>:
  match xs:
    case []:
      []
    case "" <> rest:
      words(rest)
    case word <> rest:
      word <> words(rest)

def tab(text: String,header: String) -> Maybe<&2,Split>:
  match text:
    case SNil{}:
      None{}
    case SCon{'\t',rest}:
      Some{Split{String.reverse(header),rest}}
    case SCon{ch,rest}:
      tab(rest,SCon{ch,header})

def kind(mode: String,object_type: String) -> String:
  match mode object_type:
    case "040000" "tree":
      "directory"
    case "100644" "blob":
      "file"
    case "100755" "blob":
      "file"
    case "120000" "blob":
      "symlink"
    case "160000" "commit":
      "submodule"
    case _ _:
      "unsupported"

def path_join(prefix: String,name: String) -> String:
  match prefix:
    case "":
      name
    case _:
      prefix ++ "/" ++ name

def node_fields(fields: List<&2,String>,+path: String) -> Result<&2,&2,Problem,Node>:
  match fields:
    case [mode,object_type,+object,+bytes]:
      +node_kind = kind(mode,object_type)
      Bool.pick(Result<&2,&2,Problem,Node>,P.valid_sha(object) && P.safe_path(path) &&
        Bool.not(String.contains(path,"�")) &&
        Bool.pick(Bool,String.eq(node_kind,"directory") || String.eq(node_kind,"submodule"),
          String.eq(bytes,"-"),P.decimal_valid(bytes)),
        Done{Node{path,node_kind,object,bytes}},
        Fail{Problem{"unsupported_tree_entry","Invalid object metadata, encoding or unsafe path in committed tree"}})
    case _:
      Fail{Problem{"invalid_tree","Git tree entry has unexpected metadata"}}

def node_split(split: Maybe<&2,Split>,prefix: String) -> Result<&2,&2,Problem,Node>:
  match split:
    case None{}:
      Fail{Problem{"invalid_tree","Git tree entry lacks its path delimiter"}}
    case Some{Split{header,name}}:
      node_fields(words(String.split(header,' ')),path_join(prefix,name))

def parse_entries_next(result: Result<&2,&2,Problem,Node>,
  continue: Node -> Result<&2,&2,Problem,List<&2,Node>>) -> Result<&2,&2,Problem,List<&2,Node>>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{node}:
      continue(node)

def parse_entries(entries: List<&2,String>,+prefix: String,fuel: Nat,done: List<&2,Node>) ->
  Result<&2,&2,Problem,List<&2,Node>>:
  match entries fuel:
    case [] _:
      Fail{Problem{"invalid_tree","Git tree output lacks its terminal NUL"}}
    case [""] _:
      Done{List.reverse(&2,Node,done)}
    case _ 0n:
      Fail{Problem{"directory_too_large","Directory exceeds 4096 immediate entries"}}
    case entry <> rest 1n+left:
      parse_entries_next(node_split(tab(entry,""),prefix),node => parse_entries(rest,prefix,left,node <> done))

def tree_result(result: Result<&2,&2,Problem,String>,prefix: String) -> Result<&2,&2,Problem,List<&2,Node>>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{text}:
      parse_entries(String.split(text,'\0'),prefix,4096n,[])

def single(result: Result<&2,&2,Problem,List<&2,Node>>,+path: String) -> Result<&2,&2,Problem,Node>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{[]}:
      Fail{Problem{"not_in_revision","Path is absent from the pinned commit; untracked and staged-only files are not browsed"}}
    case Done{[Node{+actual,kind,object,bytes}]}:
      Bool.pick(Result<&2,&2,Problem,Node>,String.eq(actual,path),Done{Node{actual,kind,object,bytes}},
        Fail{Problem{"invalid_tree","Git returned a different path"}})
    case Done{_}:
      Fail{Problem{"invalid_tree","Exact path resolved to multiple entries"}}

def lookup(+view: View,+path: String) -> IO(Result<&2,&2,Problem,Node>):
  do IO<Result<&2,&2,Problem,Node>>:
    result : Result<&2,&2,Problem,String> <- git(view,["ls-tree","-z","-l","--full-tree",commit(view),"--",path])
    return single(tree_result(result,""),path)

def directory_node(result: Result<&2,&2,Problem,Node>,view: View,+path: String) ->
  IO(Result<&2,&2,Problem,List<&2,Node>>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,Problem,List<&2,Node>>,Fail{error})
    case Done{Node{_,"directory",object,_}}:
      do IO<Result<&2,&2,Problem,List<&2,Node>>>:
        result : Result<&2,&2,Problem,String> <- git(view,["ls-tree","-z","-l",object])
        return tree_result(result,path)
    case Done{Node{_,kind,_,_}}:
      IO.pure(Result<&2,&2,Problem,List<&2,Node>>,Fail{Problem{"not_directory","Selected entry is " ++ kind}})

def directory_tree(+view: View,path: String) -> IO(Result<&2,&2,Problem,List<&2,Node>>):
  match path:
    case "":
      do IO<Result<&2,&2,Problem,List<&2,Node>>>:
        result : Result<&2,&2,Problem,String> <- git(view,["ls-tree","-z","-l",commit(view)])
        return tree_result(result,"")
    case _:
      +chosen = path
      do IO<Result<&2,&2,Problem,List<&2,Node>>>:
        node : Result<&2,&2,Problem,Node> <- lookup(view,chosen)
        directory_node(node,view,chosen)

def next_page(+position: U32,total: U32) -> Maybe<&2,U32>:
  Bool.pick(Maybe<&2,U32>,U32.is_lt(position,total),Some{position},None{})

def directory_page(result: Result<&2,&2,Problem,List<&2,Node>>,view: View,path: String,
  +offset: U32,limit: U32) -> Result<&2,&2,Problem,Directory>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{+nodes}:
      +total = U32.from_nat(List.length(&2,Node,nodes))
      +selected = List.take(&2,Node,List.drop(&2,Node,nodes,U32.to_nat(offset)),U32.to_nat(limit))
      Bool.pick(Result<&2,&2,Problem,Directory>,U32.is_le(offset,total),
        Done{Directory{commit(view),path,selected,total,
          next_page(U32.add(offset,U32.from_nat(List.length(&2,Node,selected))),total)}},
        Fail{Problem{"invalid_range","Directory offset exceeds its entry count"}})

def children_valid(valid: Bool,+view: View,+path: String,offset: U32,limit: U32) ->
  IO(Result<&2,&2,Problem,Directory>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,Problem,Directory>,Fail{Problem{"invalid_request","Require a valid pinned view, relative directory and 1–100 entries"}})
    case True{}:
      do IO<Result<&2,&2,Problem,Directory>>:
        nodes : Result<&2,&2,Problem,List<&2,Node>> <- directory_tree(view,path)
        return directory_page(nodes,view,path,offset,limit)

def children(+view: View,+path: String,offset: U32,+limit: U32) -> IO(Result<&2,&2,Problem,Directory>):
  children_valid(view_valid(view) && (String.is_empty(path) || P.safe_path(path)) &&
    U32.is_gt(limit,0) && U32.is_le(limit,100),view,path,offset,limit)

# NUL/control bytes indicate unsupported binary text. The pinned runtime
# replaces malformed UTF-8 with U+FFFD, so that scalar is conservatively refused
# even when it was literal, rather than presenting possibly lossy source lines.
def readable(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+cp},rest}:
      ((U32.is_ge(cp,32) && U32.is_ne(cp,127)) || U32.is_eq(cp,9) ||
        U32.is_eq(cp,10) || U32.is_eq(cp,13)) && readable(rest)

def final_lines(reversed: List<&2,String>) -> List<&2,String>:
  match reversed:
    case "" <> rest:
      List.reverse(&2,String,rest)
    case _:
      List.reverse(&2,String,reversed)

def numbered(lines: List<&2,String>,+start: U32) -> List<&2,Line>:
  match lines:
    case []:
      []
    case text <> rest:
      Line{start,text} <> numbered(rest,U32.inc(start))

def source_lines(+text: String,view: View,path: String,blob: String,bytes: String,+start: U32,count: U32) ->
  Result<&2,&2,Problem,Source>:
  +all = final_lines(List.reverse(&2,String,String.lines(text)))
  +total = U32.from_nat(List.length(&2,String,all))
  +chosen = List.take(&2,String,List.drop(&2,String,all,U32.to_nat(U32.sub(start,1))),U32.to_nat(count))
  +following = U32.add(start,U32.from_nat(List.length(&2,String,chosen)))
  Bool.pick(Result<&2,&2,Problem,Source>,U32.is_le(start,total) || (U32.is_eq(start,1) && U32.is_eq(total,0)),
    Done{Source{commit(view),path,blob,bytes,total,start,numbered(chosen,start),next_page(following,U32.inc(total)),
      String.ends_with(text,"\n")}},Fail{Problem{"invalid_range","Source start exceeds its line count"}})

def source_text(result: Result<&2,&2,Problem,String>,view: View,path: String,blob: String,+bytes: String,start: U32,count: U32) ->
  Result<&2,&2,Problem,Source>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{+text}:
      Bool.pick(Result<&2,&2,Problem,Source>,String.contains(text,"�"),
        Fail{Problem{"unsupported_encoding","UTF-8 replacement scalar is refused; subprocess decoding may have been lossy"}},
        Bool.pick(Result<&2,&2,Problem,Source>,Bool.not(readable(text)),
          Fail{Problem{"unsupported_binary","Blob contains NUL or unsupported control characters"}},
          Bool.pick(Result<&2,&2,Problem,Source>,String.eq(U32.show(U32.from_nat(List.length(&2,U32,Domain.encode(text)))),bytes),
            source_lines(text,view,path,blob,bytes,start,count),
            Fail{Problem{"invalid_blob","Decoded byte count disagrees with Git object size"}})))

def source_size(valid: Bool,+view: View,path: String,+blob: String,bytes: String,start: U32,count: U32) ->
  IO(Result<&2,&2,Problem,Source>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,Problem,Source>,Fail{Problem{"source_too_large","Committed blob exceeds 262144 bytes"}})
    case True{}:
      do IO<Result<&2,&2,Problem,Source>>:
        result : Result<&2,&2,Problem,String> <- git(view,["cat-file","blob",blob])
        return source_text(result,view,path,blob,bytes,start,count)

def source_node(result: Result<&2,&2,Problem,Node>,view: View,path: String,start: U32,count: U32) ->
  IO(Result<&2,&2,Problem,Source>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,Problem,Source>,Fail{error})
    case Done{Node{_,"file",blob,+bytes}}:
      source_size(Bool.not(Cmp.is_gt(P.decimal_compare(bytes,"262144"))),view,path,blob,bytes,start,count)
    case Done{Node{_,kind,_,_}}:
      IO.pure(Result<&2,&2,Problem,Source>,Fail{Problem{"unsupported_" ++ kind,"Only committed regular-file blobs can be read"}})

def source_valid(valid: Bool,+view: View,+path: String,start: U32,count: U32) ->
  IO(Result<&2,&2,Problem,Source>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,Problem,Source>,Fail{Problem{"invalid_request","Require a valid pinned view, safe relative file and 1–100 lines starting at 1 or later"}})
    case True{}:
      do IO<Result<&2,&2,Problem,Source>>:
        node : Result<&2,&2,Problem,Node> <- lookup(view,path)
        source_node(node,view,path,start,count)

def source(+view: View,+path: String,+start: U32,+count: U32) -> IO(Result<&2,&2,Problem,Source>):
  source_valid(view_valid(view) && P.safe_path(path) && U32.is_gt(start,0) &&
    U32.is_gt(count,0) && U32.is_le(count,100) && U32.is_le(start,U32.sub(4294967295,count)),
    view,path,start,count)

def regions_match(regions: List<&2,P.Region>,lines: List<&2,Line>) -> Bool:
  match regions lines:
    case Nil{} Nil{}:
      True{}
    case Con{P.Region{+sha,_,number,_,text},rest} Con{Line{expected,wanted},tail}:
      P.valid_sha(sha) && Bool.not(P.uncommitted(sha)) && U32.is_eq(number,expected) &&
        String.eq(text,wanted) && regions_match(rest,tail)
    case _ _:
      False{}

def parsed_blame(result: Result<&2,&2,String,List<&2,P.Region>>,lines: List<&2,Line>) -> Result<&2,&2,Problem,List<&2,P.Region>>:
  match result:
    case Fail{detail}:
      Fail{Problem{"invalid_blame",detail}}
    case Done{+regions}:
      Bool.pick(Result<&2,&2,Problem,List<&2,P.Region>>,regions_match(regions,lines),Done{regions},
        Fail{Problem{"invalid_blame","Blame lines disagree with selected committed blob"}})

def blame_result(result: Result<&2,&2,Problem,String>,limit: U32,lines: List<&2,Line>) -> Result<&2,&2,Problem,List<&2,P.Region>>:
  match result:
    case Fail{error}:
      Fail{error}
    case Done{text}:
      parsed_blame(P.porcelain(text,limit),lines)

def source_blame(result: Result<&2,&2,Problem,Source>,+view: View) -> IO(Result<&2,&2,Problem,List<&2,P.Region>>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,Problem,List<&2,P.Region>>,Fail{error})
    case Done{Source{_,path,_,_,_,+start,+lines,_,_}}:
      +count = U32.from_nat(List.length(&2,Line,lines))
      Bool.pick(IO(Result<&2,&2,Problem,List<&2,P.Region>>),U32.is_eq(count,0),
        IO.pure(Result<&2,&2,Problem,List<&2,P.Region>>,Done{[]}),
        do IO<Result<&2,&2,Problem,List<&2,P.Region>>>:
          result : Result<&2,&2,Problem,String> <- git(view,["blame","--line-porcelain","--no-ext-diff","--no-textconv",
            "-L",U32.show(start) ++ "," ++ U32.show(U32.sub(U32.add(start,count),1)),commit(view),"--",path])
          return blame_result(result,count,lines))

def blame(+view: View,path: String,start: U32,count: U32) -> IO(Result<&2,&2,Problem,List<&2,P.Region>>):
  do IO<Result<&2,&2,Problem,List<&2,P.Region>>>:
    selected : Result<&2,&2,Problem,Source> <- source(view,path,start,count)
    source_blame(selected,view)

def evidence_bounded(valid: Bool,db: U32,+view: View,path: String,regions: List<&2,P.Region>,why: Bool) ->
  IO(Result<&2,&2,Problem,String>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,Problem,String>,Fail{Problem{"evidence_range_too_wide",
        "Pinned commit " ++ commit(view) ++ ": selected lines span more than 8 commits; select a smaller range"}})
    case True{}:
      do IO<Result<&2,&2,Problem,String>>:
        text : String <- Evidence.file_result(db,scope(view),path,regions,why)
        return Done{"Pinned commit tree: " ++ commit(view) ++ "\nDisplayed source and Blame use this committed revision; working-tree changes are excluded.\n\n" ++ text}

def evidence_result(result: Result<&2,&2,Problem,List<&2,P.Region>>,db: U32,view: View,path: String,why: Bool) ->
  IO(Result<&2,&2,Problem,String>):
  match result:
    case Fail{error}:
      IO.pure(Result<&2,&2,Problem,String>,Fail{error})
    case Done{+regions}:
      evidence_bounded(Nat.is_le(List.length(&2,String,Evidence.commit_ids(regions,[])),8n),
        db,view,path,regions,why)

def evidence(db: U32,+view: View,+path: String,start: U32,count: U32,why: Bool) -> IO(Result<&2,&2,Problem,String>):
  do IO<Result<&2,&2,Problem,String>>:
    regions : Result<&2,&2,Problem,List<&2,P.Region>> <- blame(view,path,start,count)
    evidence_result(regions,db,view,path,why)
