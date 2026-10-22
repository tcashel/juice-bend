import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./providers.bend as Providers
import ./provenance.bend as P
import ./evidence.bend as Evidence
import ./actors.bend as Actors
import ./git_diff.bend as Diff
import ./repo_scope.bend as Scope
import ./recorded_commit_store.bend as RecordedCommit

type HunkResult is Data:
  HunkResult{start: U32,count: U32,result: P.Attribution}

type Commit is Data:
  Commit{sha: String,message: String,identity: P.Attribution,
    body: P.Attribution,hunks: List<&2,HunkResult>,error: String}

type Selection is Data:
  Selection{line: U32,sha: String,text: String,result: P.Attribution}

def scoped_actor(scope: Scope.Scope,actor: Actors.Actor) -> Actors.Actor:
  Actors.Actor{provider,source,snapshot,session,repo,parent,request,key,blocked} = actor
  Actors.Actor{provider,source,snapshot,session,Scope.normalize(scope,repo),parent,request,key,blocked}

def scoped_actors(actors: List<&2,Actors.Actor>,+scope: Scope.Scope) -> List<&2,Actors.Actor>:
  match actors:
    case []:
      []
    case actor <> rest:
      scoped_actor(scope,actor) <> scoped_actors(rest,scope)

def attribution_key(result: P.Attribution) -> String:
  match result:
    case P.Exact{key}:
      key
    case P.Content{key,_,_}:
      key
    case P.Probable{key,_}:
      key
    case _:
      ""

def session_token(+id: String) -> Bool:
  Nat.is_ge(String.length(id),8n) && Nat.is_le(String.length(id),256n) &&
    Bool.not(String.contains(id," ")) && Bool.not(String.contains(id,"\n")) &&
    Bool.not(String.contains(id,"\t")) && Bool.not(String.contains(id,"\0"))

# Trailer strength is reserved for explicit final-paragraph session keys.
# A body mention remains probable; URLs and arbitrary strings are not trailers.
def trailer_value(+line: String,+actor: Actors.Actor) -> Bool:
  +id = Actors.session(actor)
  session_token(id) &&
    (String.eq(line,"Session-ID: " ++ id) || String.eq(line,"Juice-Session: " ++ id) ||
      (String.eq(Actors.provider(actor),"claude") && String.eq(line,"Claude-Session: " ++ id)) ||
      (String.eq(Actors.provider(actor),"codex") && String.eq(line,"Codex-Session: " ++ id)))

def trailer_lines(lines: List<&2,String>,+actor: Actors.Actor) -> Bool:
  match lines:
    case []:
      False{}
    case "" <> _:
      False{}
    case line <> rest:
      trailer_value(String.trim_end(line),actor) || trailer_lines(rest,actor)

def trailer(+message: String,actor: Actors.Actor) -> Bool:
  trailer_lines(List.reverse(&2,String,String.lines(String.trim(message))),actor)

def explicit_trailer(+line: String) -> Bool:
  String.starts_with(line,"Session-ID: ") || String.starts_with(line,"Juice-Session: ") ||
    String.starts_with(line,"Claude-Session: ") || String.starts_with(line,"Codex-Session: ")

def trailer_entries(lines: List<&2,String>,+seen: List<&2,String>) -> List<&2,String>:
  match lines:
    case []:
      seen
    case "" <> _:
      seen
    case +line <> rest:
      trailer_entries(rest,Bool.pick(List<&2,String>,
        explicit_trailer(line) && Bool.not(P.member(line,seen)),line <> seen,seen))

def conflicting_trailers(message: String) -> Bool:
  Nat.is_gt(List.length(&2,String,
    trailer_entries(List.reverse(&2,String,String.lines(String.trim(message))),[])),1n)

def token_char(+c: Char) -> Bool:
  Char.is_alpha(c) || Char.is_digit(c) || Char.is_eq(c,'-') ||
    Char.is_eq(c,'_') || Char.is_eq(c,'/')

type Words is Data:
  Words{current: String,done: List<&2,String>}

def word_step(accepted: Bool,c: Char,current: String,done: List<&2,String>) -> Words:
  match accepted:
    case True{}:
      Words{SCon{c,current},done}
    case False{}:
      Words{"",String.reverse(current) <> done}

def words(chars: String,state: Words) -> List<&2,String>:
  match chars:
    case SNil{}:
      Words{current,done} = state
      String.reverse(current) <> done
    case SCon{+c,rest}:
      Words{current,done} = state
      words(rest,word_step(token_char(c),c,current,done))

def body_mention(message: String,+actor: Actors.Actor) -> Bool:
  +id = Actors.session(actor)
  session_token(id) && P.member(id,words(message,Words{"",[]}))

def identity_candidates(actors: List<&2,Actors.Actor>,+all: List<&2,Actors.Actor>,
  +repo: String,+message: String,+strong: Bool) -> List<&2,P.Candidate>:
  match actors:
    case []:
      []
    case +actor <> rest:
      +tail = identity_candidates(rest,all,repo,message,strong)
      +mentioned = Bool.pick(Bool,strong,trailer(message,actor),body_mention(message,actor))
      Bool.pick(List<&2,P.Candidate>,mentioned && Actors.allowed(8n,actor,all,repo),
        P.Candidate{repo,Actors.key(actor),"0",[],True{}} <> tail,tail)

def commit_identity(+repo: String,+message: String,+actors: List<&2,Actors.Actor>) -> P.Attribution:
  Bool.pick(P.Attribution,conflicting_trailers(message),
    P.Ambiguous{"multiple distinct explicit session trailers; capture availability cannot resolve the conflict"},
    P.exact(repo,identity_candidates(actors,actors,repo,message,True{})))

def commit_body(+repo: String,message: String,+actors: List<&2,Actors.Actor>) -> P.Attribution:
  P.probable(repo,identity_candidates(actors,actors,repo,message,False{}),
    "explicit session identifier in commit body; association, not proof of authorship")

def parse_json(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{value}:
      value
    case Fail{_}:
      Json.JNull{}

def actor_for_key(key: String,actors: List<&2,Actors.Actor>) -> Maybe<&2,Actors.Actor>:
  Actors.find_snapshot(actors,Json.get(parse_json(Json.parse(key)),"snapshot"))

def relative_target(+repo: String,+path: String,+cwd: String) -> Maybe<&2,String>:
  +absolute = repo ++ "/" ++ path
  Bool.pick(Maybe<&2,String>,String.starts_with(absolute,cwd ++ "/"),
    Some{String.drop(absolute,Nat.add(String.length(cwd),1n))},None{})

def candidate_path(target: Maybe<&2,String>,repo: String,key: String,time: String,
  tool: String,arguments: String,cwd: String) -> Maybe<&2,P.Candidate>:
  match target:
    case None{}:
      None{}
    case Some{relative}:
      Some{P.Candidate{repo,key,Evidence.candidate_time(time),
        Evidence.edit_lines(tool,arguments,cwd,relative),True{}}}

def candidate_event(event: Maybe<&2,Providers.Record>,context: String,scope: Scope.Scope,
  +record: Evidence.Verified,index: U32,+repo: String,+path: String) -> Maybe<&2,P.Candidate>:
  match event:
    case None{}:
      None{}
    case Some{value}:
      Providers.ProviderEvent{_,_,tool,_,arguments,_,r,_,stamp,_,_,_,coverage} = value
      +cwd = Store.nonempty(r,context)
      Bool.pick(Maybe<&2,P.Candidate>,String.eq(coverage,"complete"),
        candidate_path(relative_target(repo,path,Scope.normalize(scope,cwd)),repo,Evidence.citation(record,index),
          stamp,tool,arguments,cwd),None{})

def candidate_actor(actor: Maybe<&2,Actors.Actor>,+all: List<&2,Actors.Actor>,
  +record: Evidence.Verified,+index: U32,+repo: String,path: String,context: String,scope: Scope.Scope) -> Maybe<&2,P.Candidate>:
  match actor:
    case None{}:
      None{}
    case Some{+value}:
      Bool.pick(Maybe<&2,P.Candidate>,Actors.allowed(8n,value,all,repo),
        candidate_event(Evidence.record_event(record,index),context,scope,record,index,repo,path),None{})

def previous_context(found: String,next: Unit -> IO(String)) -> IO(String):
  match found:
    case "":
      next(Unit{})
    case _:
      IO.pure(String,found)

def context_scan(fuel: Nat,+db: U32,+snapshot: String,+ordinal: U32) -> IO(String):
  match fuel:
    case 0n:
      IO.pure(String,"")
    case 1n+rest:
      do IO<String>:
        record : Evidence.Verified <- Evidence.read_record(db,snapshot,ordinal)
        previous_context(Evidence.record_repo(record),_ =>
          Bool.pick(IO(String),U32.is_eq(ordinal,0),IO.pure(String,""),
            context_scan(rest,db,snapshot,U32.sub(ordinal,1))))

def candidates(rows: List<&2,List<&2,Sql.Cell>>,+db: U32,+all: List<&2,Actors.Actor>,
  +repo: String,+path: String,+scope: Scope.Scope) -> IO(List<&2,P.Candidate>):
  match rows:
    case []:
      IO.pure(List<&2,P.Candidate>,[])
    case +row <> rest:
      +snapshot = Store.field(row,0n)
      +index = Store.number(Store.field(row,2n))
      do IO<List<&2,P.Candidate>>:
        Store.checked(Store.numeric(Store.field(row,1n)) && Store.numeric(Store.field(row,2n)),
          "Candidate ordinal integrity mismatch")
        +record : Evidence.Verified <- Evidence.read_record(db,snapshot,Store.number(Store.field(row,1n)))
        context : String <- context_scan(16n,db,snapshot,Store.number(Store.field(row,1n)))
        tail : List<&2,P.Candidate> <- candidates(rest,db,all,repo,path,scope)
        return Evidence.candidates_add(candidate_actor(Actors.find_snapshot(all,snapshot),
          all,record,index,repo,path,context,scope),tail)

def load_candidates(+db: U32,actors: List<&2,Actors.Actor>,repo: String,path: String,scope: Scope.Scope) ->
  IO(List<&2,P.Candidate>):
  do IO<List<&2,P.Candidate>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT e.snapshot,e.ordinal,e.event FROM events e JOIN snapshots p ON p.id=e.snapshot AND p.accepted=1 WHERE p.id=(SELECT max(x.id) FROM snapshots x WHERE x.generation=p.generation AND x.accepted=1) AND e.tool IN ('Edit','Write','apply_patch','functions.apply_patch') ORDER BY p.id DESC,e.ordinal DESC,e.event LIMIT 256",[],256)
    candidates(rows,db,actors,repo,path,scope)

def git_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) ->
  Result<&2,&2,String,String>:
  match result:
    case Fail{(code,_)}:
      Fail{"Read-only Git operation failed or exceeded its bound (" ++ U32.show(code) ++ ")"}
    case Done{(0,(out,_))}:
      Done{out}
    case Done{(code,(_,_))}:
      Fail{"Read-only Git command failed (" ++ U32.show(code) ++ "); missing, binary or unsupported input"}

def git(repo: String,args: List<String>) -> IO(Result<&2,&2,String,String>):
  do IO<Result<&2,&2,String,String>>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/usr/bin/git",
      "--no-pager" <> "--no-optional-locks" <> "--no-replace-objects" <> "--no-lazy-fetch" <> "--literal-pathspecs" <> "-c" <> "core.hooksPath=/dev/null" <>
      "-c" <> "core.fsmonitor=false" <> "-c" <> "diff.external=" <> "-c" <>
      "core.attributesFile=/dev/null" <> "-c" <> "color.ui=false" <> "-C" <> repo <> args,
      "",1048576,3000)
    return git_result(result)

def hunk_results(hunks: List<&2,Diff.Hunk>,+repo: String,+pool: List<&2,P.Candidate>) ->
  List<&2,HunkResult>:
  match hunks:
    case []:
      []
    case Diff.Hunk{start,count,lines} <> rest:
      HunkResult{start,count,P.content(repo,lines,pool)} <> hunk_results(rest,repo,pool)

def commit_diff(result: Result<&2,&2,String,List<&2,Diff.Hunk>>,sha: String,message: String,
  identity: P.Attribution,body: P.Attribution,repo: String,pool: List<&2,P.Candidate>) -> Commit:
  match result:
    case Fail{error}:
      Commit{sha,message,identity,body,[],"Diff coverage unavailable: " ++ error}
    case Done{hunks}:
      Commit{sha,message,identity,body,hunk_results(hunks,repo,pool),""}

def diff_output(result: Result<&2,&2,String,String>,sha: String,message: String,
  identity: P.Attribution,body: P.Attribution,repo: String,pool: List<&2,P.Candidate>) -> Commit:
  match result:
    case Fail{error}:
      Commit{sha,message,identity,body,[],error}
    case Done{text}:
      commit_diff(Diff.parse(text),sha,message,identity,body,repo,pool)

def commit_message(result: Result<&2,&2,String,String>,checkout: String,+repo: String,path: String,+sha: String,
  +actors: List<&2,Actors.Actor>,pool: List<&2,P.Candidate>) -> IO(Commit):
  match result:
    case Fail{+error}:
      IO.pure(Commit,Commit{sha,"",P.NotIndexed{error},P.NotIndexed{error},[],error})
    case Done{+message}:
      do IO<Commit>:
        diff : Result<&2,&2,String,String> <- git(checkout,["show","-m","--first-parent",
          "--unified=0","--format=","--no-ext-diff","--no-textconv",sha,"--",path])
        return diff_output(diff,sha,String.take(message,8192n),commit_identity(repo,message,actors),
          commit_body(repo,message,actors),repo,pool)

def load_commit(+checkout: String,repo: String,path: String,+sha: String,actors: List<&2,Actors.Actor>,
  pool: List<&2,P.Candidate>) -> IO(Commit):
  do IO<Commit>:
    message : Result<&2,&2,String,String> <- git(checkout,["show","-s","--format=%B",
      "--no-ext-diff","--no-textconv",sha,"--"])
    commit_message(message,checkout,repo,path,sha,actors,pool)

def region_sha(region: P.Region) -> String:
  P.Region{sha,_,_,_,_} = region
  sha

def commit_ids(regions: List<&2,P.Region>,done: List<&2,String>) -> List<&2,String>:
  match regions:
    case []:
      List.reverse(&2,String,done)
    case region <> rest:
      +sha = region_sha(region)
      +prior = done
      commit_ids(rest,Bool.pick(List<&2,String>,P.uncommitted(sha) || P.member(sha,prior),prior,sha <> prior))

def load_commits(ids: List<&2,String>,+checkout: String,+repo: String,+path: String,
  +actors: List<&2,Actors.Actor>,+pool: List<&2,P.Candidate>) -> IO(List<&2,Commit>):
  match ids:
    case []:
      IO.pure(List<&2,Commit>,[])
    case sha <> rest:
      do IO<List<&2,Commit>>:
        commit : Commit <- load_commit(checkout,repo,path,sha,actors,pool)
        tail : List<&2,Commit> <- load_commits(rest,checkout,repo,path,actors,pool)
        return commit <> tail

def any_content(hunks: List<&2,HunkResult>) -> Bool:
  match hunks:
    case []:
      False{}
    case HunkResult{_,_,result} <> rest:
      String.eq(P.attribution_name(result),"content") || any_content(rest)

def region_hunk(hunks: List<&2,HunkResult>,+original: U32) -> P.Attribution:
  match hunks:
    case []:
      P.NotIndexed{"selected original line is outside parsed commit diff hunks"}
    case HunkResult{+start,+count,result} <> rest:
      Bool.pick(P.Attribution,U32.is_ge(original,start) &&
        U32.is_lt(U32.sub(original,start),count),result,region_hunk(rest,original))

def fallback(identity: P.Attribution,body: P.Attribution) -> P.Attribution:
  match body:
    case P.Probable{key,basis}:
      P.Probable{key,basis}
    case P.Ambiguous{reason}:
      P.Ambiguous{reason}
    case _:
      identity

def commit_attribution(identity: P.Attribution,body: P.Attribution,
  +hunks: List<&2,HunkResult>,original: U32) -> P.Attribution:
  match identity:
    case P.Exact{key}:
      P.Exact{key}
    case P.Ambiguous{reason}:
      P.Ambiguous{reason}
    case _:
      Bool.pick(P.Attribution,any_content(hunks),region_hunk(hunks,original),fallback(identity,body))

def lookup_commit(commits: List<&2,Commit>,+sha: String,+original: U32) -> P.Attribution:
  match commits:
    case []:
      P.NotIndexed{"commit metadata unavailable"}
    case Commit{+id,_,identity,body,hunks,_} <> rest:
      Bool.pick(P.Attribution,String.eq(id,sha),commit_attribution(identity,body,hunks,original),
        lookup_commit(rest,sha,original))

def selections(regions: List<&2,P.Region>,+commits: List<&2,Commit>) -> List<&2,Selection>:
  match regions:
    case []:
      []
    case P.Region{+sha,original,line,_,text} <> rest:
      Selection{line,sha,text,Bool.pick(P.Attribution,P.uncommitted(sha),P.Uncommitted{},
        lookup_commit(commits,sha,original))} <> selections(rest,commits)

def render_selections(selections: List<&2,Selection>) -> String:
  match selections:
    case []:
      ""
    case Selection{line,sha,text,result} <> rest:
      "Line " ++ U32.show(line) ++ " · commit " ++ sha ++ "\n" ++ String.take(text,400n) ++
        "\n" ++ Evidence.attribution_text(result) ++ "\n\n" ++ render_selections(rest)

def selection_keys(selections: List<&2,Selection>,done: List<&2,String>) -> List<&2,String>:
  match selections:
    case []:
      List.reverse(&2,String,done)
    case Selection{_,_,_,result} <> rest:
      +key = attribution_key(result)
      +prior = done
      selection_keys(rest,Bool.pick(List<&2,String>,String.is_empty(key) || P.member(key,prior),prior,key <> prior))

def resolved_text(result: Result<&2,&2,String,String>) -> String:
  match result:
    case Done{text}:
      text
    case Fail{error}:
      "not_captured: " ++ error ++ "\n"

def parent_text(parent: Maybe<&2,Actors.Actor>,+db: U32) -> IO(String):
  match parent:
    case None{}:
      IO.pure(String,"Parent navigation: unavailable or ambiguous; child identity is retained.\n")
    case Some{actor}:
      do IO<String>:
        text : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,Actors.key(actor))
        return "Parent request for navigation only; child actor, model and event ordinal are unchanged:\n" ++ resolved_text(text)

def request_context(+actor: Actors.Actor,request: String,parent: String) -> String:
  "Recorded request policy: " ++ Actors.request_policy() ++ "; not proof of human authorship or an inferred reason.\n" ++
    "Recorded request preview (at most 2048 decoded characters):\n" ++ Actors.request_preview(actor) ++
    "\nRecorded request citation: " ++ Actors.key(actor) ++
    "\nRetained request event excerpt and immutable citation (text, arguments, result: at most 2048 decoded characters each; context prefixes remain quoted; complete bytes remain available in raw export):\n" ++
    request ++ parent

def actor_context(actor: Maybe<&2,Actors.Actor>,+all: List<&2,Actors.Actor>,+db: U32,
  +repo: String) -> IO(String):
  match actor:
    case None{}:
      IO.pure(String,"Actor metadata not indexed within the stated bound.\n")
    case Some{+value}:
      do IO<String>:
        request : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,Actors.key(value))
        parent : String <- Bool.pick(IO(String),String.is_empty(Actors.parent(value)),
          IO.pure(String,""),parent_text(Actors.parent_actor(value,all,repo),db))
        return request_context(value,resolved_text(request),parent)

def quote_keys(keys: List<&2,String>,+db: U32,+actors: List<&2,Actors.Actor>,+repo: String) -> IO(String):
  match keys:
    case []:
      IO.pure(String,"")
    case +key <> rest:
      do IO<String>:
        event : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,key)
        context : String <- actor_context(actor_for_key(key,actors),actors,db,repo)
        tail : String <- quote_keys(rest,db,actors,repo)
        return context ++ "\nSelected captured evidence:\n" ++ resolved_text(event) ++ "\n" ++ tail

def commit_notes(commits: List<&2,Commit>) -> String:
  match commits:
    case []:
      ""
    case Commit{sha,message,_,_,_,error} <> rest:
      "Read-only Git commit " ++ sha ++ "\n" ++ String.take(message,2048n) ++
        "\n" ++ error ++ "\n" ++ commit_notes(rest)

def file_notices() -> String:
  "\nRead-only current Git resolution; this may differ from a previously displayed Blame." ++
    "\nCaptured source bounds: 64 generation snapshots, first 16 records for actor identity, newest 256 edit events." ++
    "\nFile evidence is independent of transcript filters. Exact means a unique eligible captured identity named by an explicit commit trailer; it does not prove sole authorship." ++
    "\nContent uses each commit diff hunk and original-line coordinates; unmatched regions never borrow a neighboring match." ++
    "\nUnknown, excluded, diagnostic, synthetic, ambiguous or orphaned actors cannot supply user-work evidence. Diagnostic-style Markdown first requests are conservatively held for review." ++
    "\nTool arguments record intent; success and rationale are not inferred. No timestamp-only attribution.\n\n"

def file_text(why: Bool,+scope: Scope.Scope,path: String,selected: List<&2,Selection>,
  commits: List<&2,Commit>,excerpts: String) -> String:
  head = "Juice Bend · file evidence\nCanonical repository: " ++ Scope.canonical(scope) ++
    "\nGit checkout: " ++ Scope.checkout(scope) ++ "\nFile: " ++ path
  details = file_notices() ++ render_selections(selected) ++ commit_notes(commits)
  head ++ Bool.pick(String,why,"\n\n" ++ excerpts,"") ++ details

def file_result(+db: U32,+scope: Scope.Scope,+path: String,+regions: List<&2,P.Region>,+why: Bool) -> IO(String):
  +ids = commit_ids(regions,[])
  +repo = Scope.canonical(scope)
  do IO<String>:
    Store.checked(Nat.is_le(List.length(&2,String,ids),8n),
      "File evidence range spans more than 8 commits; select a smaller range")
    raw_actors : List<&2,Actors.Actor> <- Actors.load(db)
    +actors : List<&2,Actors.Actor> = scoped_actors(raw_actors,scope)
    pool : List<&2,P.Candidate> <- load_candidates(db,actors,repo,path,scope)
    +commits : List<&2,Commit> <- load_commits(ids,Scope.checkout(scope),repo,path,actors,pool)
    +selected : List<&2,Selection> = selections(regions,commits)
    excerpts : String <- Bool.pick(IO(String),why,
      quote_keys(selection_keys(selected,[]),db,actors,repo),IO.pure(String,""))
    return file_text(why,scope,path,selected,commits,excerpts)

def blamed(result: Result<&2,&2,String,List<&2,P.Region>>,db: U32,scope: Scope.Scope,path: String,
  why: Bool) -> IO(String):
  match result:
    case Fail{error}:
      IO.pure(String,"Blame unavailable: " ++ error)
    case Done{regions}:
      file_result(db,scope,path,regions,why)

def file_scope(result: Result<&2,&2,String,Scope.Scope>,db: U32,+path: String,+start: U32,
  count: U32,why: Bool) -> IO(String):
  match result:
    case Fail{error}:
      IO.pure(String,"Blame unavailable: " ++ error)
    case Done{+scope}:
      do IO<String>:
        result : Result<&2,&2,String,List<&2,P.Region>> <- P.git_blame(Scope.checkout(scope),path,start,U32.sub(U32.add(start,count),1))
        blamed(result,db,scope,path,why)

def file_valid(valid: Bool,db: U32,+repo: String,+path: String,+start: U32,count: U32,why: Bool) -> IO(String):
  match valid:
    case False{}:
      IO.pure(String,"Blame unavailable: require absolute repository, relative safe file and 1–100 valid lines")
    case True{}:
      do IO<String>:
        scope : Result<&2,&2,String,Scope.Scope> <- Scope.resolve(repo)
        file_scope(scope,db,path,start,count,why)

def file(db: U32,+repo: String,+path: String,+start: U32,+count: U32,why: Bool) -> IO(String):
  file_valid(P.safe_repo(repo) && P.safe_path(path) && U32.is_gt(start,0) &&
    U32.is_gt(count,0) && U32.is_le(count,100) && U32.is_le(start,U32.sub(4294967295,count)),
    db,repo,path,start,count,why)

def blame(db: U32,repo: String,path: String,start: U32,count: U32) -> IO(String):
  file(db,repo,path,start,count,False{})

def why(db: U32,repo: String,path: String,start: U32,count: U32) -> IO(String):
  file(db,repo,path,start,count,True{})

def commit_text(sha: String,message: String,link: P.Attribution,excerpts: String) -> String:
  "Juice Bend · commit Why\nRead-only Git commit " ++ sha ++ "\n" ++ Evidence.attribution_text(link) ++
    "\nCoverage: unique eligible trailer/body associations only; no time-based guess or generated rationale. File content matching requires a selected file range.\n\n" ++
    excerpts ++ "Read-only Git commit message:\n" ++ String.take(message,8192n) ++ "\n"

def commit_why_message(result: Result<&2,&2,String,String>,+db: U32,+scope: Scope.Scope,+sha: String) -> IO(String):
  match result:
    case Fail{error}:
      IO.pure(String,"Why unavailable: " ++ error)
    case Done{+message}:
      do IO<String>:
        raw_actors : List<&2,Actors.Actor> <- Actors.load(db)
        +actors : List<&2,Actors.Actor> = scoped_actors(raw_actors,scope)
        +repo : String = Scope.canonical(scope)
        +link : P.Attribution = commit_attribution(commit_identity(repo,message,actors),commit_body(repo,message,actors),[],0)
        excerpts : String <- quote_keys(Bool.pick(List<&2,String>,String.is_empty(attribution_key(link)),[],[attribution_key(link)]),
          db,actors,repo)
        recorded : String <- RecordedCommit.read(db,scope,sha)
        return commit_text(sha,message,link,excerpts) ++ "\nRecorded commit-command evidence:\n" ++ recorded

def commit_scope(result: Result<&2,&2,String,Scope.Scope>,+db: U32,+sha: String) -> IO(String):
  match result:
    case Fail{error}:
      IO.pure(String,"Why unavailable: " ++ error)
    case Done{+scope}:
      do IO<String>:
        message : Result<&2,&2,String,String> <- git(Scope.checkout(scope),["show","-s","--format=%B","--no-ext-diff","--no-textconv",sha,"--"])
        commit_why_message(message,db,scope,sha)

def commit_why_valid(valid: Bool,+db: U32,+repo: String,+sha: String) -> IO(String):
  match valid:
    case False{}:
      IO.pure(String,"Why unavailable: require an absolute repository and exact 40-character commit SHA")
    case True{}:
      do IO<String>:
        scope : Result<&2,&2,String,Scope.Scope> <- Scope.resolve(repo)
        commit_scope(scope,db,sha)

def commit_why(db: U32,+repo: String,+sha: String) -> IO(String):
  commit_why_valid(P.safe_repo(repo) && P.valid_sha(sha) && Bool.not(P.uncommitted(sha)),db,repo,sha)
