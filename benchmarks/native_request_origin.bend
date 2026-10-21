import Base
import ./native_repository.bend as Safe
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ../src/domain.bend as Domain
import ../src/actors.bend as Actors
import ../src/evidence.bend as Evidence
import ../src/file_evidence.bend as FileEvidence
import ../src/repository_browser.bend as Browser
import ../src/provenance.bend as P
import ../src/maintenance.bend as Maintenance

# Native UI fixture only. All bytes are synthetic. The only accepted operation
# creates a NEW canonical /private/tmp/juice-bend-repository-fixture-origin-UUID
# directory. Existing roots fail mkdir before any fixture file is written.
# Reuses the native repository fixture's bounded literal-argv Git commands,
# canonical regular-path checks, disabled hooks and Git environment guard.
type Captured is Data:
  Captured{index: U32,commit: String,snapshot: String}

def checked(ok: Bool,message: String) -> IO(Unit):
  Store.checked(ok,"Native request-origin fixture: " ++ message)

def hex(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+c},rest}:
      ((U32.is_ge(c,48) && U32.is_le(c,57)) ||
       (U32.is_ge(c,65) && U32.is_le(c,70)) ||
       (U32.is_ge(c,97) && U32.is_le(c,102))) && hex(rest)

def hex_part(+text: String,size: Nat) -> Bool:
  Nat.is_eq(String.length(text),size) && hex(text)

def uuid(parts: List<&2,String>) -> Bool:
  match parts:
    case a <> b <> c <> d <> e <> []:
      hex_part(a,8n) && hex_part(b,4n) && hex_part(c,4n) && hex_part(d,4n) && hex_part(e,12n)
    case _: False{}

def root_shape(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-repository-fixture-origin-" : String}
  String.starts_with(root,prefix) &&
    uuid(String.split(String.drop(root,String.length(prefix)),'-'))

def name(index: U32) -> String:
  match index:
    case 1: "01-wrapped-request"
    case 2: "02-long-context-unicode"
    case 3: "03-context-only"
    case 4: "04-relay-only"
    case 5: "05-meta-only"
    case _: "06-malformed-wrapper"

def session(index: U32) -> String:
  "origin-session-000" ++ U32.show(index)

def path(index: U32) -> String:
  name(index) ++ ".txt"

def content(+index: U32) -> String:
  "let origin_case_" ++ U32.show(index) ++ " = " ++ U32.show(index) ++ "\n" ++
    "let retained_marker_" ++ U32.show(index) ++ " = 42\n" ++
    "let final_marker_" ++ U32.show(index) ++ " = 99\n"

def preview(index: U32) -> String:
  match index:
    case 1: "\n  Preserve the wrapped calculation café 中文 🙂. \n"
    case 2: "\n\tKeep café 中文 🙂 é exact.  \n"
    case _: ""

def user_text(index: U32) -> String:
  match index:
    case 1: "<system-reminder>Retained setup before the request.</system-reminder>" ++ preview(1)
    case 2: "<system-reminder>" ++ String.repeat("x",3000n) ++ "</system-reminder>" ++ preview(2)
    case 3: "<environment_context>Captured context without a request.</environment_context> \n"
    case 4: "<teammate-message>Relayed work must not become a recorded user request.</teammate-message>"
    case 5: "Metadata-only command must not establish recorded intent."
    case _: "<system-reminder>Unclosed context must remain uncertain."

def user(+repo: String,index: U32,meta: String,typed_content: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(session(index)) ++
    ",\"cwd\":" ++ Json.quote(repo) ++ "," ++ meta ++
    "\"message\":{\"content\":" ++ typed_content ++ "}}\n"

def request_records(+repo: String,+index: U32) -> String:
  Bool.pick(String,U32.is_le(index,2),
    user(repo,index,"",Json.quote("<environment_context>Earlier context-only physical record.</environment_context>")) ++
      user(repo,index,"","[{\"type\":\"image\",\"source\":{\"type\":\"synthetic\"}}," ++
        "{\"type\":\"text\",\"text\":" ++ Json.quote(user_text(index)) ++ "}]"),
    user(repo,index,Bool.pick(String,U32.is_eq(index,5),"\"isMeta\":true,",""),Json.quote(user_text(index))))

def captured_bytes(+repo: String,+index: U32) -> String:
  request_records(repo,index) ++
    "{\"type\":\"assistant\",\"sessionId\":" ++ Json.quote(session(index)) ++
    ",\"cwd\":" ++ Json.quote(repo) ++ ",\"timestamp\":\"2026-10-21T12:00:00Z\"," ++
    "\"message\":{\"model\":\"synthetic-recorded-model\",\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\"," ++
    "\"id\":\"origin-write-" ++ U32.show(index) ++ "\",\"input\":{\"file_path\":" ++
    Json.quote(path(index)) ++ ",\"content\":" ++ Json.quote(content(index)) ++ "}}]}}\n"

def record_count(index: U32) -> U32:
  Bool.pick(U32,U32.is_le(index,2),3,2)

def create_one(+root: String,+repo: String,+db: U32,+index: U32) -> IO(Captured):
  +source = root ++ "/captures/" ++ name(index) ++ ".jsonl"
  do IO<Captured>:
    Store.write_text(repo ++ "/" ++ path(index),"w",content(index))
    commit : String <- Safe.commit(repo,"Create " ++ name(index) ++ "\n\nClaude-Session: " ++ session(index))
    Store.write_text(source,"w",captured_bytes(repo,index))
    +snapshot : String <- Store.import_file(db,"claude",source)
    checked(String.eq(snapshot,U32.show(index)),"expected six independent captures in fixture order")
    return Captured{index,commit,snapshot}

def create_all(fuel: Nat,+root: String,+repo: String,+db: U32,+index: U32) -> IO(List<&2,Captured>):
  match fuel:
    case 0n: IO.pure(List<&2,Captured>,[])
    case 1n+rest:
      do IO<List<&2,Captured>>:
        one : Captured <- create_one(root,repo,db,index)
        tail : List<&2,Captured> <- create_all(rest,root,repo,db,U32.inc(index))
        return one <> tail

def actor_found(value: Maybe<&2,Actors.Actor>) -> IO(Actors.Actor):
  match value:
    case Some{actor}: IO.pure(Actors.Actor,actor)
    case None{}: IO.die(Actors.Actor,1,"Native request-origin fixture: captured actor missing")

def read_closed(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,value) = result
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,value))

def bytes(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,65536)
    read_closed(result)

def positive_why(+text: String,+value: Actors.Actor,+index: U32) -> IO(Unit):
  checked(String.contains(text,"\nexact\nCitation: " ++ Actors.key(value)) &&
    String.contains(text,"Recorded request policy: recorded-request-v1") &&
    String.contains(text,"not proof of human authorship") &&
    String.contains(text,"Recorded request preview (at most 2048 decoded characters):\n" ++ preview(index) ++ "\nRetained") &&
    String.contains(text,"text, arguments, result: at most 2048 decoded characters each") &&
    String.contains(text,"context prefixes remain quoted; complete bytes remain available in raw export") &&
    String.contains(text,Actors.key(value)) && String.contains(text,"<system-reminder>"),
    name(index) ++ " Why must show exact attribution, exact suffix preview, bounded retained excerpt and immutable citation")

def negative_why(+text: String,index: U32) -> IO(Unit):
  checked(String.contains(text,"not_indexed") &&
    Bool.not(String.contains(text,"\nexact\nCitation:")) &&
    Bool.not(String.contains(text,"probable ·")) &&
    Bool.not(String.contains(text,"Recorded request preview")) &&
    Bool.not(String.contains(text,"Selected captured evidence:")),
    name(index) ++ " excluded input must not become exact/probable request evidence")

def blocked(value: Actors.Actor) -> String:
  Actors.Actor{_,_,_,_,_,_,_,_,reason} = value
  reason

def verify_actor(positive: Bool,+db: U32,+repo: String,+snapshot: String,+index: U32,
  +value: Actors.Actor,+all: List<&2,Actors.Actor>,direct: String,browser: String) -> IO(Unit):
  match positive:
    case True{}:
      do IO<Unit>:
        checked(Actors.own_eligible(value) && String.eq(Actors.request_preview(value),preview(index)),
          name(index) ++ " preview must retain exact whitespace and Unicode suffix")
        +record : Evidence.Verified <- Evidence.read_record(db,snapshot,1)
        checked(String.eq(Actors.key(value),Evidence.citation(record,1)),
          name(index) ++ " request citation must select physical record 1 and event 1")
        checked(String.eq(P.attribution_name(FileEvidence.commit_identity(repo,
          "Claude-Session: " ++ session(index),all)),"exact"),name(index) ++ " must have unique exact trailer identity")
        positive_why(direct,value,index)
        positive_why(browser,value,index)
    case False{}:
      do IO<Unit>:
        checked(Bool.not(Actors.own_eligible(value)) && String.is_empty(Actors.key(value)) &&
          String.is_empty(Actors.request_preview(value)),name(index) ++ " must remain ineligible without a request citation")
        checked(Bool.not(U32.is_eq(index,6)) ||
          String.contains(blocked(value),"recognized envelope has no matching closing tag"),
          "malformed wrapper must retain its explicit uncertainty reason")
        checked(String.eq(P.attribution_name(FileEvidence.commit_identity(repo,
          "Claude-Session: " ++ session(index),all)),"not_indexed") &&
          String.eq(P.attribution_name(FileEvidence.commit_body(repo,
          "Discussed with " ++ session(index) ++ ".",all)),"not_indexed"),
          name(index) ++ " must reject both exact trailer and probable body association")
        negative_why(direct,index)
        negative_why(browser,index)

def entry(+root: String,+repo: String,+index: U32,commit: String,+snapshot: String,+value: Actors.Actor) -> String:
  "{\"name\":" ++ Json.quote(name(index)) ++ ",\"path\":" ++ Json.quote(path(index)) ++
    ",\"session\":" ++ Json.quote(session(index)) ++ ",\"commit\":" ++ Json.quote(commit) ++
    ",\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"source\":" ++ Json.quote(root ++ "/captures/" ++ name(index) ++ ".jsonl") ++
    ",\"records\":" ++ U32.show(record_count(index)) ++
    ",\"expected_attribution\":" ++ Json.quote(Bool.pick(String,U32.is_le(index,2),"exact","not_indexed")) ++
    ",\"expected_request\":" ++ Json.quote(preview(index)) ++
    ",\"eligible\":" ++ Bool.pick(String,U32.is_le(index,2),"true","false") ++
    ",\"request_citation\":" ++ Bool.pick(String,String.is_empty(Actors.key(value)),"null",Actors.key(value)) ++
    ",\"raw_bytes\":" ++ Nat.show(List.length(&2,U32,Domain.encode(captured_bytes(repo,index)))) ++
    ",\"raw_export\":" ++ Json.quote(root ++ "/evidence/" ++ name(index) ++ ".raw.jsonl") ++
    ",\"file_why\":" ++ Json.quote(root ++ "/evidence/" ++ name(index) ++ ".file-why.txt") ++
    ",\"browser_why\":" ++ Json.quote(root ++ "/evidence/" ++ name(index) ++ ".browser-why.txt") ++ "}"

def verify_one(captured: Captured,+root: String,+repo: String,+db: U32,+view: Browser.View,
  +all: List<&2,Actors.Actor>) -> IO(String):
  Captured{+index,commit,+snapshot} = captured
  +export = root ++ "/evidence/" ++ name(index) ++ ".raw.jsonl"
  do IO<String>:
    +before : String <- Store.projection_digest(db,snapshot)
    +value : Actors.Actor <- actor_found(Actors.find_snapshot(all,snapshot))
    +direct : String <- FileEvidence.why(db,repo,path(index),1,3)
    browser_result : Result<&2,&2,Browser.Problem,String> <- Browser.evidence(db,view,path(index),1,3,True{})
    +browser : String <- Safe.need(String,browser_result)
    verify_actor(U32.is_le(index,2),db,repo,snapshot,index,value,all,direct,browser)
    checked(String.ends_with(browser,direct),name(index) ++ " pinned Browser Why must contain the exact production file evidence body")
    Maintenance.export_raw(db,snapshot,export)
    raw : List<&2,U32> <- bytes(export)
    checked(Domain.bytes_equal(raw,Domain.encode(captured_bytes(repo,index))),name(index) ++ " verified raw export must preserve every original JSONL byte")
    after : String <- Store.projection_digest(db,snapshot)
    checked(String.eq(before,after),name(index) ++ " read-time policy must not modify normalized projection")
    Store.write_text(root ++ "/evidence/" ++ name(index) ++ ".file-why.txt","w",direct)
    Store.write_text(root ++ "/evidence/" ++ name(index) ++ ".browser-why.txt","w",browser)
    return entry(root,repo,index,commit,snapshot,value)

def verify_all(values: List<&2,Captured>,+root: String,+repo: String,+db: U32,
  +view: Browser.View,+all: List<&2,Actors.Actor>) -> IO(List<&2,String>):
  match values:
    case []: IO.pure(List<&2,String>,[])
    case value <> rest:
      do IO<List<&2,String>>:
        one : String <- verify_one(value,root,repo,db,view,all)
        tail : List<&2,String> <- verify_all(rest,root,repo,db,view,all)
        return one <> tail

def manifest(+root: String,commit: String,entries: List<&2,String>) -> String:
  "{\"fixture\":\"juice-bend-request-origin-v1\",\"policy\":\"recorded-request-v1\"," ++
    "\"synthetic\":true,\"root\":" ++ Json.quote(root) ++
    ",\"repository\":" ++ Json.quote(root ++ "/repository") ++
    ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"commit\":" ++ Json.quote(commit) ++
    ",\"cases\":[" ++ String.join(entries,",") ++
    "],\"checks\":{\"file_why\":true,\"pinned_browser_why\":true,\"raw_bytes_exact\":true,\"projection_unchanged\":true}}"

def prepare(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  do IO<Unit>:
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(repo)
    Safe.directory(root ++ "/library")
    Safe.directory(root ++ "/captures")
    Safe.directory(root ++ "/evidence")
    initialized : String <- Safe.git(repo,["-c","init.defaultBranch=main","init","--quiet","--template="])
    +db : U32 <- Store.open(root ++ "/library/juice-bend.sqlite")
    captures : List<&2,Captured> <- create_all(6n,root,repo,db,1)
    +commit_raw : String <- Safe.git(repo,["rev-parse","HEAD"])
    +commit : String = String.trim(commit_raw)
    opened : Result<&2,&2,Browser.Problem,Browser.View> <- Browser.open_at(repo,commit)
    view : Browser.View <- Safe.need(Browser.View,opened)
    +actors : List<&2,Actors.Actor> <- Actors.load(db)
    checked(Nat.is_eq(List.length(&2,Actors.Actor,actors),6n),"exactly six captured actors required")
    entries : List<&2,String> <- verify_all(captures,root,repo,db,view,actors)
    IO.try(Unit,Sql.close(db))
    status : String <- Safe.git(repo,["status","--porcelain","--untracked-files=all"])
    checked(String.is_empty(status),"new repository must remain pristine")
    +description : String = manifest(root,commit,entries)
    Store.write_text(root ++ "/.juice-bend-request-origin-v1.json","w",description ++ "\n")
    protected : String <- Safe.command("/bin/chmod",["400",root ++ "/.juice-bend-request-origin-v1.json"])
    IO.print(description)

def fixture(+path: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(path),"requires a new /private/tmp/juice-bend-repository-fixture-origin-UUID root")
    +canonical : String <- Paths.destination(path)
    checked(String.eq(path,canonical),"root spelling must already be canonical")
    prepare(canonical)

# Advance is a one-shot mutation of this fixture's own six original captures.
# Reconstruct the entire immutable marker from fixed fixture values and actual
# pristine Git commits before opening the existing library for writes.
def expected_actor(+root: String,+repo: String,+index: U32) -> Actors.Actor:
  +source = root ++ "/captures/" ++ name(index) ++ ".jsonl"
  +snapshot = U32.show(index)
  +citation = Evidence.citation(Evidence.Verified{"claude",source,snapshot,snapshot,
    Nat.show(List.length(&2,U32,Domain.encode(captured_bytes(repo,index)))),"1",[]},1)
  Actors.Actor{"claude",source,snapshot,session(index),repo,"",preview(index),
    Bool.pick(String,U32.is_le(index,2),citation,""),""}

def regular_one(+path: String) -> IO(Unit):
  do IO<Unit>:
    Safe.regular_path(path,False{})
    links : String <- Safe.command("/usr/bin/stat",["-q","-f","%l","--",path])
    checked(String.eq(String.trim(links),"1"),"fixture file has another hard link")

def private_directory(+path: String) -> IO(Unit):
  do IO<Unit>:
    Safe.regular_path(path,True{})
    mode : String <- Safe.command("/usr/bin/stat",["-q","-f","%Op","--",path])
    checked(String.eq(String.trim(mode),"40700"),"fixture directory is not private mode 0700")

def test_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Bool):
  match result:
    case Done{(0,_)}: IO.pure(Bool,True{})
    case Done{(1,_)}: IO.pure(Bool,False{})
    case _: IO.die(Bool,1,"Native request-origin fixture: path-existence test failed")

def test(flag: String,path: String) -> IO(Bool):
  do IO<Bool>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/test",[flag,path],"",1024,2000)
    test_result(result)

def absent(+path: String) -> IO(Unit):
  do IO<Unit>:
    exists : Bool <- test("-e",path)
    linked : Bool <- test("-L",path)
    checked(Bool.not(exists) && Bool.not(linked),"advance destination already exists")

def optional_regular(exists: Bool,path: String) -> IO(Unit):
  match exists:
    case True{}: regular_one(path)
    case False{}: IO.pure(Unit,Unit{})

def database_sidecar(+path: String) -> IO(Unit):
  do IO<Unit>:
    linked : Bool <- test("-L",path)
    checked(Bool.not(linked),"database sidecar is a symlink")
    exists : Bool <- test("-e",path)
    optional_regular(exists,path)

def known_entries(fuel: Nat,+root: String,+repo: String,+index: U32) -> IO(List<&2,String>):
  match fuel:
    case 0n: IO.pure(List<&2,String>,[])
    case 1n+rest:
      +source = root ++ "/captures/" ++ name(index) ++ ".jsonl"
      do IO<List<&2,String>>:
        regular_one(source)
        original : String <- Safe.read_small(source)
        checked(String.eq(original,captured_bytes(repo,index)),name(index) ++ " original capture bytes changed; refusing advance")
        regular_one(repo ++ "/" ++ path(index))
        contents : String <- Safe.read_small(repo ++ "/" ++ path(index))
        checked(String.eq(contents,content(index)),"fixture committed source content changed")
        +sha_raw : String <- Safe.git(repo,["log","-1","--format=%H","--",path(index)])
        +sha : String = String.trim(sha_raw)
        checked(P.valid_sha(sha),"fixture file has no valid original commit")
        tail : List<&2,String> <- known_entries(rest,root,repo,U32.inc(index))
        return entry(root,repo,index,sha,U32.show(index),expected_actor(root,repo,index)) <> tail

def filenames(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: name(index) ++ ".jsonl\n" ++ filenames(rest,U32.inc(index))

def advance_guard(+root: String,+repo: String) -> IO(Unit):
  +marker = root ++ "/.juice-bend-request-origin-v1.json"
  do IO<Unit>:
    checked(root_shape(root),"advance requires its exact canonical origin-UUID root")
    private_directory(root)
    private_directory(root ++ "/library")
    private_directory(root ++ "/captures")
    private_directory(root ++ "/evidence")
    Safe.regular_path(repo,True{})
    Safe.regular_path(repo ++ "/.git",True{})
    regular_one(marker)
    mode : String <- Safe.command("/usr/bin/stat",["-q","-f","%Op","--",marker])
    checked(String.eq(String.trim(mode),"100400"),"fixture marker is not immutable mode 0400")
    +original_marker : String <- Safe.read_small(marker)
    children : String <- Safe.command("/bin/ls",["-A1","--",root ++ "/captures"])
    checked(String.eq(children,filenames(6n,1)),"captures directory has unexpected or missing entries")
    status : String <- Safe.git(repo,["status","--porcelain","--untracked-files=all"])
    checked(String.is_empty(status),"fixture Git repository is no longer pristine")
    commits : String <- Safe.git(repo,["rev-list","--count","HEAD"])
    checked(String.eq(String.trim(commits),"6"),"fixture Git history has changed")
    +commit : String <- Safe.git(repo,["rev-parse","HEAD"])
    entries : List<&2,String> <- known_entries(6n,root,repo,1)
    checked(String.eq(original_marker,manifest(root,String.trim(commit),entries) ++ "\n"),
      "entire immutable marker differs from the known original fixture")
    regular_one(root ++ "/library/juice-bend.sqlite")
    database_sidecar(root ++ "/library/juice-bend.sqlite-wal")
    database_sidecar(root ++ "/library/juice-bend.sqlite-shm")
    absent(root ++ "/captures-retired")
    absent(root ++ "/evidence/01-wrapped-request.after.raw.jsonl")
    absent(root ++ "/.juice-bend-request-origin-advanced-v1.json")

def resolved(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{reason}: IO.die(String,1,"Native request-origin fixture: citation unavailable: " ++ reason)

def rewritten(repo: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"origin-rewritten-0001\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":\"Different synthetic generation; original request remains retained.\"}}\n"

def initial_library(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  +row = Store.first(rows)
  checked(String.eq(Store.field(row,0n),"6") && String.eq(Store.field(row,1n),"6") &&
    String.eq(Store.field(row,2n),"6") && String.eq(Store.field(row,3n),"6"),
    "advance requires exactly the six original sources, generations and accepted snapshots")

def original_actor(+db: U32,source: String) -> IO(Actors.Actor):
  do IO<Actors.Actor>:
    value : Actors.Actor <- Actors.scan(3n,db,"1",0,Actors.empty("claude",source,"1"))
    return Actors.complete_actor(value)

def later_actor(db: U32,+snapshot: String,source: String,count: Nat) -> IO(Actors.Actor):
  do IO<Actors.Actor>:
    value : Actors.Actor <- Actors.scan(count,db,snapshot,0,Actors.empty("claude",source,snapshot))
    return Actors.complete_actor(value)

def generation(record: Evidence.Verified) -> String:
  Evidence.Verified{_,_,value,_,_,_,_} = record
  value

def advance(+root: String) -> IO(Unit):
  +repo = root ++ "/repository"
  +source = root ++ "/captures/" ++ name(1) ++ ".jsonl"
  +output = root ++ "/evidence/01-wrapped-request.after.raw.jsonl"
  +expected = expected_actor(root,repo,1)
  do IO<Unit>:
    advance_guard(root,repo)
    +db : U32 <- Store.open(root ++ "/library/juice-bend.sqlite")
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM sources),(SELECT count(*) FROM generations),(SELECT count(*) FROM snapshots),(SELECT count(*) FROM snapshots WHERE accepted=1)",[],1)
    initial_library(rows)
    +before : String <- Store.projection_digest(db,"1")
    record : Evidence.Verified <- Evidence.read_record(db,"1",1)
    +key : String = Evidence.citation(record,1)
    checked(String.eq(key,Actors.key(expected)),"original request citation differs from the exact fixture identity")
    +original : Actors.Actor <- original_actor(db,source)
    checked(Actors.own_eligible(original) && String.eq(Actors.request_preview(original),preview(1)) &&
      String.eq(Actors.key(original),key),"original captured actor differs from expected request")
    quote_result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,key)
    +quote : String <- resolved(quote_result)
    +context : String <- FileEvidence.actor_context(Some{original},[original],db,repo)
    Store.write_text(source,"a",user(repo,1,"",Json.quote("A later recorded request in the synthetic append.")))
    +appended : String <- Store.import_file(db,"claude",source)
    checked(String.eq(appended,"7"),"append must publish snapshot 7")
    +append_actor : Actors.Actor <- later_actor(db,appended,source,4n)
    +append_record : Evidence.Verified <- Evidence.read_record(db,appended,1)
    checked(Actors.own_eligible(append_actor) && String.eq(Actors.request_preview(append_actor),preview(1)) &&
      String.eq(Actors.key(append_actor),Evidence.citation(append_record,1)) && String.eq(generation(append_record),"1"),
      "append must retain the original generation and request occurrence with a new snapshot citation")
    Store.write_text(source,"w",rewritten(repo))
    +rewritten_snapshot : String <- Store.import_file(db,"claude",source)
    checked(String.eq(rewritten_snapshot,"8"),"rewrite must publish distinct snapshot 8")
    rewritten_actor : Actors.Actor <- later_actor(db,rewritten_snapshot,source,1n)
    rewritten_record : Evidence.Verified <- Evidence.read_record(db,rewritten_snapshot,0)
    checked(String.eq(Actors.session(rewritten_actor),"origin-rewritten-0001") &&
      Bool.not(String.eq(generation(rewritten_record),"1")),"rewrite must have a different generation and session identity")
    moved : String <- Safe.command("/bin/mv",["-n","--",root ++ "/captures",root ++ "/captures-retired"])
    absent(root ++ "/captures")
    private_directory(root ++ "/captures-retired")
    after_record : Evidence.Verified <- Evidence.read_record(db,"1",1)
    checked(String.eq(Evidence.citation(after_record,1),key),"old physical/event identity changed after advance")
    after_quote_result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,key)
    after_quote : String <- resolved(after_quote_result)
    checked(String.eq(quote,after_quote),"old retained citation excerpt changed after source absence")
    +after_actor : Actors.Actor <- original_actor(db,source)
    checked(Actors.own_eligible(after_actor) && String.eq(Actors.request_preview(after_actor),preview(1)) &&
      String.eq(Actors.key(after_actor),key),"old captured request selection changed after advance")
    after_context : String <- FileEvidence.actor_context(Some{after_actor},[after_actor],db,repo)
    checked(String.eq(context,after_context),"old request preview and immutable citation changed after advance")
    Maintenance.export_raw(db,"1",output)
    raw : List<&2,U32> <- bytes(output)
    checked(Domain.bytes_equal(raw,Domain.encode(captured_bytes(repo,1))),"original snapshot 1 bytes changed after append/rewrite/source absence")
    after : String <- Store.projection_digest(db,"1")
    checked(String.eq(before,after),"original snapshot 1 projection changed after advance")
    IO.try(Unit,Sql.close(db))
    +description : String = "{\"fixture\":\"juice-bend-request-origin-advance-v1\",\"root\":" ++ Json.quote(root) ++
      ",\"repository\":" ++ Json.quote(repo) ++ ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++
      ",\"original_snapshot\":\"1\",\"appended_snapshot\":" ++ Json.quote(appended) ++
      ",\"rewritten_snapshot\":" ++ Json.quote(rewritten_snapshot) ++ ",\"request_citation\":" ++ key ++
      ",\"raw_export\":" ++ Json.quote(output) ++
      ",\"checks\":{\"source_absent\":true,\"old_citation_exact\":true,\"old_preview_exact\":true,\"old_raw_bytes_exact\":true,\"old_projection_unchanged\":true}}"
    Store.write_text(root ++ "/.juice-bend-request-origin-advanced-v1.json","w",description ++ "\n")
    protected : String <- Safe.command("/bin/chmod",["400",root ++ "/.juice-bend-request-origin-advanced-v1.json"])
    IO.print(description)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []: fixture(root)
    case _ <> "advance" <> root <> []: advance(root)
    case _: IO.die(Unit,2,"Usage: native-request-origin fixture NEW_ROOT | advance ORIGINAL_ROOT; roots must be canonical /private/tmp/juice-bend-repository-fixture-origin-UUID")

def main() -> IO(Unit):
  do IO<Unit>:
    Safe.environment(["GIT_DIR","GIT_WORK_TREE","GIT_COMMON_DIR","GIT_INDEX_FILE",
      "GIT_OBJECT_DIRECTORY","GIT_ALTERNATE_OBJECT_DIRECTORIES","GIT_CONFIG",
      "GIT_CONFIG_PARAMETERS","GIT_CONFIG_COUNT","GIT_TEMPLATE_DIR","GIT_SHALLOW_FILE"])
    args : List<String> <- IO.args()
    arguments(args)
