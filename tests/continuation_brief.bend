import Base
import ../src/continuation_brief.bend as B
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/evidence.bend as Evidence
import ../src/scoped_reader.bend as Scoped
import ../src/tool_activity.bend as Activity
import ../src/providers.bend as Providers
import ../src/repo_scope.bend as Repo
import ../src/request_evidence.bend as Request
import ../src/request_origin.bend as Origin
import ../src/maintenance.bend as Maintenance
import ../src/json.bend as Json
import ../src/paths.bend as Paths

# Synthetic-only harness. Run from a fresh private cwd. No real histories.
def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def need(-A: Kind(&2),value: Result<&2,&2,B.Problem,A>) -> IO(A):
  match value:
    case Done{value}: IO.pure(A,value)
    case Fail{B.Problem{code,detail}}: IO.die(A,1,"FAIL " ++ code ++ ": " ++ detail)

def failed(-A: Kind(&2),value: Result<&2,&2,B.Problem,A>,code: String) -> Bool:
  match value:
    case Fail{B.Problem{actual,_}}: String.eq(actual,code)
    case Done{_}: False{}

def all() -> Scoped.Scope:
  Scoped.Scope{"","","",""}

def descriptor(+ordinal: U32,+event: U32) -> Evidence.Descriptor:
  Evidence.Descriptor{Domain.EvidenceKey{"claude","/synthetic/source.jsonl","9007199254740993","9007199254740995",
    U32.show(ordinal),U32.show(event)},"50000",ordinal,event}

def record(role: String,text: String) -> Providers.Record:
  Providers.ProviderEvent{role,text,"","","","","/synthetic/repository","private-session",
    "2026-10-21T00:00:00.000000000Z","recorded-model","{\"total\":1}","private-parent","complete"}

def fact(ordinal: U32,text: String,kind: U32) -> B.Fact:
  B.Fact{Activity.Occurrence{descriptor(ordinal,0),record("assistant",text)},kind,"",0}

def anchor() -> B.Anchor:
  B.Anchor{B.Input{"9007199254740995",0,3,all(),"/synthetic/repository"},
    Repo.Scope{"/synthetic/repository","/synthetic/repository",["/synthetic/repository","/synthetic/worktree"]},
    "claude","/synthetic/source.jsonl","9007199254740993",50000,3}

def body(preview: B.Preview) -> String:
  B.Preview{_,_,_,_,_,_,_,_,_,_,text,_} = preview
  text

def request(preview: B.Preview) -> B.RequestState:
  B.Preview{_,_,_,_,_,_,_,state,_,_,_,_} = preview
  state

def stats(preview: B.Preview) -> B.Coverage:
  B.Preview{_,_,_,_,_,_,_,_,coverage,_,_,_} = preview
  coverage

def refs(preview: B.Preview) -> List<&2,Evidence.Descriptor>:
  B.Preview{_,_,_,_,_,_,references,_,_,_,_,_} = preview
  references

def bytes(preview: B.Preview) -> U32:
  B.Preview{_,_,_,_,_,_,_,_,_,_,_,size} = preview
  size

def is_unique(value: B.RequestState) -> Bool:
  match value:
    case B.Unique{_}: True{}
    case _: False{}

def is_missing(value: B.RequestState) -> Bool:
  match value:
    case B.Missing{_}: True{}
    case _: False{}

def is_multiple(value: B.RequestState) -> Bool:
  match value:
    case B.Multiple{2,0}: True{}
    case _: False{}

def is_uncertain(value: B.RequestState) -> Bool:
  match value:
    case B.Uncertain{_,_}: True{}
    case _: False{}

def captured(preview: B.Preview) -> B.Anchor:
  B.Preview{anchor,_,_,_,_,_,_,_,_,_,_,_} = preview
  anchor

def parsed(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def raw(text: String) -> Json.Json:
  parsed(Json.parse(text))

def pure(+wrapped: String) -> IO(B.Preview):
  +first = fact(0,"Complete literal café 😀 result",0)
  +occ = {Activity.Occurrence{descriptor(1,0),record("user",wrapped)} : Activity.Occurrence}
  +request_fact = B.assessed(occ,Request.assess("claude",raw("{\"type\":\"user\",\"message\":{\"content\":" ++ Json.quote(wrapped) ++ "}}"),0,record("user",wrapped)))
  do IO<B.Preview>:
    +preview : B.Preview <- need(B.Preview,B.render(anchor(),B.Collected{[request_fact,first],1,0,0,0,0,0,"synthetic-evidence"}))
    assert(is_unique(request(preview)),"production request policy recognizes unique eligible suffix")
    assert(String.contains(body(preview),"Fix café 😀 safely.") && Bool.not(String.contains(body(preview),"context context")),"required request uses complete eligible suffix and omits oversized context wrapper")
    assert(String.contains(body(preview),"context prefix blocks omitted: 1"),"request prefix omission is explicit")
    assert(String.contains(body(preview),"source_sha256") && Bool.not(String.contains(body(preview),"/synthetic/source.jsonl")),"brief-only citation contains source fingerprint without locator")
    assert(String.contains(body(preview),"9007199254740993") && String.contains(body(preview),"9007199254740995"),"generation and snapshot IDs above2^53 remain exact decimal strings")
    assert(String.contains(body(preview),"NOT existing locally-resolvable citation JSON"),"new citation format discloses local resolver incompatibility")
    assert(Bool.not(String.contains(body(preview),"private-session")) && Bool.not(String.contains(body(preview),"private-parent")),"session and parent IDs excluded from rendered facts")
    assert(U32.is_eq(bytes(preview),U32.from_nat(List.length(&2,U32,Domain.encode(body(preview))))) && U32.is_le(bytes(preview),8192),"reported final UTF8 bytes equal independent encoded byte count")
    assert(is_missing(B.request_state([first],0,0,3)),"no request stays missing with excluded-envelope count")
    assert(is_multiple(B.request_state([request_fact,request_fact],2,0,0)),"multiple requests remain ambiguous")
    assert(is_uncertain(B.request_state([request_fact],1,1,0)),"one eligible plus one uncertain candidate is not unique")
    assert(failed(B.Preview,B.render(anchor(),B.Collected{[fact(0,String.repeat("😀",3000n),0)],0,0,0,0,0,0,"m"}),"required_anchor_too_large"),"oversized mandatory whole fact is refused without truncation")
    +omitted : B.Preview <- need(B.Preview,B.render(anchor(),B.Collected{[fact(2,"third omitted whole",0),fact(1,String.repeat("😀",3000n),0),first],0,0,0,0,0,0,"m"}))
    assert(String.contains(body(omitted),"whole facts omitted for budget: 2") && Bool.not(String.contains(body(omitted),"third omitted whole")),"packing stops at first non-fitting fact and counts every remaining whole occurrence")
    assert(B.has_budget(Activity.consume(String.repeat("😀",2048n),8192)) && Bool.not(B.has_budget(Activity.consume(String.repeat("😀",2048n) ++ "x",8192))),"8192-byte Unicode boundary counts scalars by UTF8 width")
    # Use a nonempty seed so omitted empty-field labels do not alter payload overhead.
    +base : B.Preview <- need(B.Preview,B.render(anchor(),B.Collected{[fact(0,"x",0)],0,0,0,0,0,0,"m"}))
    +fill : String = "x" ++ String.repeat("x",U32.to_nat(U32.sub(8192,bytes(base))))
    +edge : B.Preview <- need(B.Preview,B.render(anchor(),B.Collected{[fact(0,fill,0)],0,0,0,0,0,0,"m"}))
    assert(U32.is_eq(bytes(edge),8192),"whole mandatory fact exactly8192 UTF8 bytes is accepted including final footer")
    assert(failed(B.Preview,B.render(anchor(),B.Collected{[fact(0,fill ++ "x",0)],0,0,0,0,0,0,"m"}),"required_anchor_too_large"),"whole mandatory fact at8193 bytes fails without budget reservation or truncation")
    assert(B.repository_allowed(Repo.Scope{"/synthetic/repository","/synthetic/repository",["/synthetic/repository","/synthetic/worktree"]},
      Providers.ProviderEvent{"assistant","x","","","","","/synthetic/worktree/sub","","","","","","complete"}),"known linked worktree cwd is normalized to one canonical repository")
    assert(Bool.not(B.repository_allowed(Repo.Scope{"/synthetic/repository","/synthetic/repository",["/synthetic/repository"]},
      Providers.ProviderEvent{"assistant","x","","","","","/synthetic/repository/../other","","","","","","complete"})),"captured traversal cwd is excluded rather than executed or normalized permissively")
    return preview

# Each top-level field and every redundant citation component participates in
# comparison. No cached fingerprint bypasses a changed field or rendered text.
def mutations(+p: B.Preview) -> List<&2,B.Preview>:
  B.Preview{+a,+policy,+request_policy,+parser,+source,+evidence,+references,+request,+coverage,+notices,+text,+size} = p
  B.Anchor{+input,+repo,+provider,+locator,+generation,+extent,+total} = a
  B.Input{+snapshot,+start,+count,+scope,+explicit} = input
  [B.Preview{a,policy ++ "x",request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{a,policy,request_policy ++ "x",parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{a,policy,request_policy,parser ++ "x",source,evidence,references,request,coverage,notices,text,size},
   B.Preview{a,policy,request_policy,parser,source ++ "x",evidence,references,request,coverage,notices,text,size},
   B.Preview{a,policy,request_policy,parser,source,evidence ++ "x",references,request,coverage,notices,text,size},
   B.Preview{a,policy,request_policy,parser,source,evidence,[],request,coverage,notices,text,size},
   B.Preview{a,policy,request_policy,parser,source,evidence,references,B.Missing{0},coverage,notices,text,size},
   B.Preview{a,policy,request_policy,parser,source,evidence,references,request,B.Coverage{1,1,1,1,1,1,1},notices,text,size},
   B.Preview{a,policy,request_policy,parser,source,evidence,references,request,coverage,[],text,size},
   B.Preview{a,policy,request_policy,parser,source,evidence,references,request,coverage,notices,text ++ "x",size},
   B.Preview{a,policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,U32.inc(size)},
   B.Preview{B.Anchor{B.Input{snapshot,U32.inc(start),count,scope,explicit},repo,provider,locator,generation,extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{B.Input{snapshot,start,U32.inc(count),scope,explicit},repo,provider,locator,generation,extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{B.Input{snapshot,start,count,Scoped.Scope{"claude","","user",""},explicit},repo,provider,locator,generation,extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{input,Repo.Scope{"changed","changed",[]},provider,locator,generation,extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{input,repo,"codex",locator,generation,extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{input,repo,provider,locator ++ "x",generation,extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{input,repo,provider,locator,generation ++ "0",extent,total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{input,repo,provider,locator,generation,U32.inc(extent),total},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size},
   B.Preview{B.Anchor{input,repo,provider,locator,generation,extent,U32.inc(total)},policy,request_policy,parser,source,evidence,references,request,coverage,notices,text,size}]

def changed_ref(p: B.Preview,descriptor: Evidence.Descriptor) -> B.Preview:
  B.Preview{a,p,r,n,s,e,_,request,c,notices,text,bytes} = p
  B.Preview{a,p,r,n,s,e,[descriptor],request,c,notices,text,bytes}

def changed_request(p: B.Preview,descriptor: Evidence.Descriptor) -> B.Preview:
  B.Preview{a,p,r,n,s,e,refs,_,c,notices,text,bytes} = p
  B.Preview{a,p,r,n,s,e,refs,B.Unique{descriptor},c,notices,text,bytes}

def rejection_loop(values: List<&2,B.Preview>,+fresh: B.Preview,+index: U32) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        assert(failed(String,B.compared(Done{fresh},value),"stale"),"forged retained preview field rejected " ++ U32.show(index))
        rejection_loop(rest,fresh,U32.inc(index))

def equality_fields(+preview: B.Preview,+actual: Evidence.Descriptor) -> IO(Unit):
  Evidence.Descriptor{+key,+extent,n,+event} = actual
  Domain.EvidenceKey{+provider,+source,+generation,+snapshot,+record,_} = key
  +bad_n = {Evidence.Descriptor{key,extent,U32.inc(n),event} : Evidence.Descriptor}
  +bad_e = {Evidence.Descriptor{Domain.EvidenceKey{provider,source,generation,snapshot,record,"9"},extent,1,event} : Evidence.Descriptor}
  do IO<Unit>:
    copy : String <- need(String,B.compared(Done{preview},preview))
    assert(String.eq(copy,body(preview)),"unchanged fresh preparation authorizes exact original text")
    rejection_loop(mutations(preview),preview,0)
    assert(Bool.not(String.eq(B.descriptor_key(actual),B.descriptor_key(bad_n))) &&
      Bool.not(String.eq(B.descriptor_key(actual),B.descriptor_key(bad_e))),"descriptor encoding binds redundant ordinal and key event independently")
    assert(failed(String,B.compared(Done{preview},changed_request(preview,bad_n)),"stale") &&
      failed(String,B.compared(Done{preview},changed_request(preview,bad_e)),"stale"),"unique request state cannot hide forged redundant descriptor fields")
    assert(failed(String,B.compared(Done{preview},changed_ref(preview,bad_n)),"stale") &&
      failed(String,B.compared(Done{preview},changed_ref(preview,bad_e)),"stale"),"retained reference list cannot hide forged redundant descriptor fields")
    assert(Bool.not(String.eq(B.raw_manifest([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Text{"d"},Sql.Cell.Blob{[10]},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"}],Sql.Cell.Integer{"1"}),
      B.raw_manifest([Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Text{"d"},Sql.Cell.Blob{[10]},Sql.Cell.Integer{"0"},Sql.Cell.Integer{"1"},Sql.Cell.Integer{"0"}],Sql.Cell.Integer{"2"}))),"evidence commitment binds exact raw mapping ID even with identical bytes")

def equality(preview: B.Preview) -> IO(Unit):
  equality_fields(preview,descriptor(1,0))

# Every process below uses fixed executable plus literal synthetic argv.
def command_result(result: U32 & (String & String)) -> IO(Unit):
  (code,(_,error)) = result
  assert(U32.is_eq(code,0),"synthetic fixture command " ++ error)

def command_args(program: String,args: List<String>) -> List<String>:
  match program:
    case "/usr/bin/git": "-c" <> "commit.gpgSign=false" <> "-c" <> "tag.gpgSign=false" <> "-c" <> "core.fsmonitor=false" <> "-c" <> "core.hooksPath=/dev/null" <> "-c" <> "core.attributesFile=/dev/null" <> args
    case _: args

def command(+program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,command_args(program,args),"",65536,30000))
    command_result(result)

def claude(repo: String,role: String,text: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"cwd\":" ++ Json.quote(repo) ++ ",\"sessionId\":\"brief-synthetic\",\"message\":{\"content\":" ++ Json.quote(text) ++ "}}\n"

def codex_meta(repo: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":\"brief-codex\",\"cwd\":" ++ Json.quote(repo) ++ ",\"source\":\"cli\"}}\n"

def codex(text: String) -> String:
  "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":" ++ Json.quote(text) ++ "}]}}\n"

def capture(+db: U32,provider: String,+path: String,text: String) -> IO(String):
  do IO<String>:
    Store.write_text(path,"w",text)
    Store.import_file(db,provider,path)

def prepared(+db: U32,snapshot: String,start: U32,count: U32,scope: Scoped.Scope,repo: String) -> IO(B.Preview):
  do IO<B.Preview>:
    result : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{snapshot,start,count,scope,repo})
    need(B.Preview,result)

def fresh(+db: U32,+preview: B.Preview,name: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,B.Problem,String> <- B.revalidate(db,preview)
    value : String <- need(String,result)
    assert(String.eq(value,body(preview)),name)

def scope_tests(+db: U32,+repo: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"claude","scopes.jsonl",claude(repo,"user","Do the selected work") ++
      claude(repo ++ "/elsewhere","assistant","child cwd retained") ++ claude("/outside/never-executed","user","OUTSIDE SECRET MARKER") ++
      claude(repo,"assistant","Complete retained result"))
    +preview : B.Preview <- prepared(db,snapshot,0,4,all(),repo)
    assert(is_unique(request(preview)) && Bool.not(String.contains(body(preview),"OUTSIDE SECRET MARKER")),"explicit canonical repository narrows an empty repository scope")
    assert(String.contains(body(preview),"outside canonical repository: 1") && String.contains(body(preview),"child cwd retained"),"repository narrowing counts exclusion and retains known-root descendants")
    +only_user : B.Preview <- prepared(db,snapshot,0,4,Scoped.Scope{"claude",repo,"user",""},repo)
    assert(Bool.not(String.contains(body(only_user),"child cwd retained")) && Bool.not(String.contains(body(only_user),"Complete retained result")),"frozen exact repository and role filters are not widened")
    mismatch : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{snapshot,0,4,Scoped.Scope{"codex","","",""},repo})
    assert(failed(B.Preview,mismatch,"empty_scope"),"mismatched frozen provider cannot reveal selected source")
    range : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{snapshot,3,2,all(),repo})
    assert(failed(B.Preview,range,"range"),"range extending beyond capture is rejected without clipping")
    invalid : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{snapshot,0,0,all(),repo})
    assert(failed(B.Preview,invalid,"input"),"zero selected records rejected before repository or capture reads")
    Store.exec(db,"CREATE TEMP VIEW SOURCES AS SELECT * FROM main.sources",[])
    shadow : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{snapshot,0,1,all(),repo})
    assert(failed(B.Preview,shadow,"shadowed_capture"),"temporary table or view cannot shadow main capture readers")
    Store.exec(db,"DROP VIEW temp.SOURCES",[])
    Store.exec(db,"BEGIN",[])
    owned : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{snapshot,0,1,all(),repo})
    assert(failed(B.Preview,owned,"transaction"),"brief refuses existing caller transaction")
    Store.exec(db,"CREATE TEMP TABLE brief_transaction_marker(value INTEGER)",[])
    Store.exec(db,"INSERT INTO brief_transaction_marker VALUES(1)",[])
    Store.exec(db,"ROLLBACK",[])
    marker : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM sqlite_temp_master WHERE name='brief_transaction_marker'",[],1)
    assert(String.eq(Store.field(Store.first(marker),0n),"0"),"brief refusal did not end caller transaction")
    Store.write_text("scopes.jsonl","a",claude(repo,"user","New latest request"))
    latest : String <- Store.import_file(db,"claude","scopes.jsonl")
    assert(Bool.not(String.eq(snapshot,latest)),"synthetic append produces a new immutable snapshot")
    fresh(db,preview,"new latest capture does not change pinned preview")
    command("/bin/rm",["scopes.jsonl"])
    fresh(db,preview,"source deletion does not affect retained brief revalidation")
    Maintenance.rebuild(db,snapshot)
    fresh(db,preview,"equivalent rebuild preserves exact raw-derived brief fingerprint")

def classifications(+db: U32,+repo: String) -> IO(Unit):
  do IO<Unit>:
    +missing : String <- capture(db,"claude","missing.jsonl",claude(repo,"user","<environment_context>setup only</environment_context>") ++ claude(repo,"assistant","Recorded completion text"))
    +missing_page : B.Preview <- prepared(db,missing,0,2,all(),repo)
    assert(is_missing(request(missing_page)) && String.contains(body(missing_page),"excluded request envelopes: 1"),"context-only user envelope yields explicit no-request with retained assistant fact")
    +multiple : String <- capture(db,"claude","multiple.jsonl",claude(repo,"user","First request") ++ claude(repo,"user","Second request"))
    multiple_page : B.Preview <- prepared(db,multiple,0,2,all(),repo)
    assert(is_multiple(request(multiple_page)),"two physical user requests remain multiple")
    +uncertain : String <- capture(db,"claude","uncertain.jsonl",claude(repo,"user","<system-reminder>unclosed context") ++ claude(repo,"assistant","No inferred task"))
    uncertain_page : B.Preview <- prepared(db,uncertain,0,2,all(),repo)
    assert(is_uncertain(request(uncertain_page)),"unclosed recognized wrapper stays uncertain")
    +relay : String <- capture(db,"claude","relay.jsonl",claude(repo,"user","<teammate-message>Relay instructions</teammate-message>") ++ claude(repo,"assistant","Recorded answer"))
    relay_page : B.Preview <- prepared(db,relay,0,2,all(),repo)
    assert(is_missing(request(relay_page)),"recorded relay cannot become a user request")
    +attachment : String <- capture(db,"claude","attachment.jsonl","{\"type\":\"user\",\"cwd\":" ++ Json.quote(repo) ++ ",\"message\":{\"content\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"data\":\"PRIVATE_ATTACHMENT_MARKER\"}},{\"type\":\"text\",\"text\":\"Inspect the retained facts\"}]}}\n")
    +attachment_page : B.Preview <- prepared(db,attachment,0,1,all(),repo)
    assert(is_unique(request(attachment_page)) && String.contains(body(attachment_page),"omitted attachment occurrences: 1") && Bool.not(String.contains(body(attachment_page),"PRIVATE_ATTACHMENT_MARKER")),"attachment payload cannot leak and aligned following text remains eligible")
    assert(String.contains(body(attachment_page),"\"event\":\"1\""),"request keeps original event index after omitted attachment")
    +malformed : String <- capture(db,"claude","malformed.jsonl",claude(repo,"user","Eligible first request") ++
      "{\"type\":\"user\",\"cwd\":" ++ Json.quote(repo) ++ ",\"message\":{\"content\":42}}\n")
    malformed_page : B.Preview <- prepared(db,malformed,0,2,all(),repo)
    assert(is_uncertain(request(malformed_page)),"malformed selected user frame prevents false uniqueness of another request")
    +partial : String <- capture(db,"claude","partial.jsonl",claude(repo,"user","Eligible first request") ++
      "{\"type\":\"new-unsupported-type\",\"cwd\":" ++ Json.quote(repo) ++ "}\n")
    partial_page : B.Preview <- prepared(db,partial,0,2,all(),repo)
    assert(is_uncertain(request(partial_page)),"unsupported selected frame keeps request uncertainty explicit")
    +error_snapshot : String <- capture(db,"claude","tool-error.jsonl",claude(repo,"user","Eligible request") ++
      "{\"type\":\"user\",\"cwd\":" ++ Json.quote(repo) ++ ",\"message\":{\"content\":[{\"type\":\"tool_result\",\"tool_use_id\":\"synthetic\",\"is_error\":true,\"content\":\"Recorded failure\"}]}}\n")
    +error_page : B.Preview <- prepared(db,error_snapshot,0,2,all(),repo)
    assert(is_unique(request(error_page)) && String.contains(body(error_page),"Recorded failure"),"known tool_error fact does not invent another uncertain user request")
    +codex_snapshot : String <- capture(db,"codex","codex.jsonl",codex_meta(repo) ++ codex("Implement the Codex slice"))
    +codex_page : B.Preview <- prepared(db,codex_snapshot,1,1,all(),repo)
    assert(is_unique(request(codex_page)) && String.contains(body(codex_page),"Implement the Codex slice"),"Codex selected late record uses verified carried repository context")
    +codex_full : B.Preview <- prepared(db,codex_snapshot,0,2,all(),repo)
    assert(is_unique(request(codex_full)) && String.contains(body(codex_full),"partial/unsupported events in eligible range: 0"),"known Codex metadata plus request preserves uniqueness and honest partial count")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{codex_snapshot}])
    missing_context : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{codex_snapshot,1,1,all(),repo})
    assert(failed(B.Preview,missing_context,"needs_rebuild_or_smaller_range"),"missing late checkpoint refuses implicit prefix replay")
    Maintenance.rebuild(db,codex_snapshot)
    fresh(db,codex_page,"restored equivalent checkpoint revalidates unchanged pinned Codex brief")
    +oversized : String <- capture(db,"claude","oversized.jsonl",claude(repo,"user",String.repeat("x",12000n)))
    too_large : Result<&2,&2,B.Problem,B.Preview> <- B.prepare(db,B.Input{oversized,0,1,all(),repo})
    assert(failed(B.Preview,too_large,"required_anchor_too_large"),"real imported oversized request returns no truncated continuation")

def child_result(result: U32 & (String & String),needle: String,name: String) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,needle),name)

def worker(+self: String,snapshot: String,repo: String,needle: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["read",snapshot,repo],"",65536,30000))
    child_result(result,needle,name)

def corruption(+db: U32,+self: String,+repo: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"claude","corrupt.jsonl",claude(repo,"user","Recorded original") ++ claude(repo,"assistant","Recorded later"))
    +preview : B.Preview <- prepared(db,snapshot,1,1,all(),repo)
    Store.exec(db,"UPDATE snapshot_context SET model='forged' WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{snapshot}])
    worker(self,snapshot,repo,"integrity","corrupt selected incoming context cannot produce a brief")
    Maintenance.rebuild(db,snapshot)
    fresh(db,preview,"equivalent context repair does not invent a different pinned brief")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=1)",[Sql.Cell.Integer{snapshot}])
    worker(self,snapshot,repo,"integrity","corrupt retained raw fails closed before preview text")

def linked(+db: U32,+repo: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(repo ++ "/synthetic.txt","w","Synthetic fixture\n")
    command("/usr/bin/git",["-C",repo,"add","--","synthetic.txt"])
    command("/usr/bin/git",["-c","user.name=Juice Bend Synthetic","-c","user.email=synthetic@example.invalid","-c","core.hooksPath=/dev/null","-C",repo,"commit","--quiet","-m","Synthetic brief fixture"])
    command("/usr/bin/git",["-c","core.hooksPath=/dev/null","-C",repo,"worktree","add","--quiet","--detach","../linked-repo","HEAD"])
    +other : String <- Paths.resolve("linked-repo")
    +snapshot : String <- capture(db,"claude","worktree.jsonl",claude(other,"user","Linked worktree request") ++ claude(repo,"assistant","Primary recorded result"))
    +page : B.Preview <- prepared(db,snapshot,0,2,all(),repo)
    assert(is_unique(request(page)) && String.contains(body(page),"Primary recorded result"),"real linked worktree metadata narrows to one canonical repository")
    +strict : B.Preview <- prepared(db,snapshot,0,2,Scoped.Scope{"claude",repo,"",""},repo)
    assert(is_missing(request(strict)) && Bool.not(String.contains(body(strict),"Linked worktree request")),"linked normalization never widens a frozen exact repository filter")
    command("/usr/bin/git",["-C",repo,"worktree","remove","--force","../linked-repo"])
    changed : Result<&2,&2,B.Problem,String> <- B.revalidate(db,page)
    assert(failed(String,changed,"stale"),"changed explicit worktree mapping invalidates prepared preview")

def wide_identity(+repo: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/brief-wide.sqlite")
    Store.exec(db,"INSERT INTO sources(id,provider,locator) VALUES(9007199254740994,'claude','/synthetic/unused-seed')",[])
    Store.exec(db,"INSERT INTO generations(id,source) VALUES(9007199254740994,9007199254740994)",[])
    Store.exec(db,"INSERT INTO snapshots(id,generation,extent) VALUES(9007199254740994,9007199254740994,0)",[])
    Store.exec(db,"INSERT INTO raw(id,generation,ordinal,offset,n,digest,bytes,complete,oversized) VALUES(9007199254740994,9007199254740994,0,0,1,?,?,0,0)",
      [Sql.Cell.Text{Domain.digest([120])},Sql.Cell.Blob{[120]}])
    +snapshot : String <- capture(db,"claude","wide.jsonl",claude(repo,"user","Exact wide identity request"))
    +page : B.Preview <- prepared(db,snapshot,0,1,all(),repo)
    assert(String.eq(snapshot,"9007199254740995") && String.contains(body(page),"\"generation\":\"9007199254740995\"") &&
      String.contains(body(page),"\"snapshot\":\"9007199254740995\""),"actual imported wide source generation raw and snapshot IDs retain odd decimal identities beyond2^53")
    fresh(db,page,"actual wide-ID captured brief revalidates without numeric rounding")
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +pure_preview : B.Preview <- pure("<system-reminder>" ++ String.repeat("context ",4000n) ++ "</system-reminder>Fix café 😀 safely.")
    equality(pure_preview)
    command("/usr/bin/git",["-c","init.defaultBranch=main","-c","core.hooksPath=/dev/null","init","--quiet","fixture-repo"])
    +repo : String <- Paths.resolve("fixture-repo")
    +db : U32 <- Store.open(".build/brief.sqlite")
    scope_tests(db,repo)
    classifications(db,repo)
    corruption(db,self,repo)
    linked(db,repo)
    wide_identity(repo)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "read" <> snapshot <> repo <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/brief.sqlite")
        preview : B.Preview <- prepared(db,snapshot,1,1,all(),repo)
        IO.print(body(preview))
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Invalid synthetic brief arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
