import Base
import ../src/result_link.bend as Link
import ../src/result_links.bend as Links
import ../src/result_links_cli.bend as CLI
import ../src/relations.bend as R
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/scoped_reader.bend as Scoped
import ../src/providers.bend as Providers
import ../src/evidence.bend as Evidence

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need(-A: Kind(&2),value: Result<&2,&2,String,A>) -> IO(A):
  match value:
    case Done{value}: IO.pure(A,value)
    case Fail{reason}: IO.die(A,1,"FAIL child-result test: " ++ reason)

def failure(-A: Kind(&2),value: Result<&2,&2,String,A>,expected: String) -> Bool:
  match value:
    case Done{_}: False{}
    case Fail{reason}: String.contains(reason,expected)

def fixture_result(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),"synthetic fixture command completed")

def fixture(command: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(command,args,"",8192,10000))
    fixture_result(result)

def metadata(session: String,repo: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(session) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"message\":{\"content\":\"Synthetic request\"}}\n"

def result_block() -> String:
  "{\"type\":\"tool_result\",\"tool_use_id\":\"t1\",\"content\":\"child finished\",\"is_error\":false}"

def result_record(id: String,blocks: String) -> String:
  "{\"type\":\"user\",\"timestamp\":\"2026-10-21T10:00:00Z\",\"toolUseResult\":{\"agentId\":" ++ id ++
    "},\"message\":{\"role\":\"user\",\"content\":[" ++ blocks ++ "]}}\n"

def recorded(value: Result<&2,&2,String,Json.Json>,event: U32) -> Link.Recorded:
  match value:
    case Fail{_}: Link.Unsupported{"invalid JSON"}
    case Done{raw}: Link.decode(raw,event,"parent")

def state(text: String,event: U32) -> String:
  Link.status(recorded(Json.parse(String.trim(text)),event))

def pure() -> IO(Unit):
  +one = result_record("\"a9c45ea8a66917762\"",result_block())
  do IO<Unit>:
    assert(String.eq(state(one,0),"recorded"),"observed typed Claude toolUseResult.agentId shape is admitted")
    assert(String.eq(state(one,1),"missing"),"out-of-range event slot cannot borrow another result")
    assert(String.eq(state(result_record("\"abc\"","{\"type\":\"text\",\"text\":\"context\"}," ++ result_block()),1),"recorded"),
      "selected normalized event index stays aligned after preceding text")
    assert(String.eq(state(result_record("\"abc\"",result_block() ++ "," ++ result_block()),0),"ambiguous"),
      "one agent envelope over multiple result blocks remains ambiguous")
    assert(String.eq(state(result_record("17",result_block()),0),"unsupported"),"numeric agentId is not coerced")
    assert(String.eq(state("{\"type\":\"user\",\"toolUseResult\":42,\"message\":{\"content\":[" ++ result_block() ++ "]}}",0),"unsupported"),
      "scalar envelope is unsupported rather than missing")
    assert(String.eq(state("{\"type\":\"user\",\"toolUseResult\":null,\"message\":{\"content\":[" ++ result_block() ++ "]}}",0),"unsupported"),
      "null envelope is unsupported rather than missing")
    assert(String.eq(state(result_record("null",result_block()),0),"unsupported"),"null agentId is not coerced")
    assert(String.eq(state(result_record("\"../escape\"",result_block()),0),"unsupported"),"agentId cannot traverse paths")
    assert(String.eq(state(result_record("\"a/b\"",result_block()),0),"unsupported"),"agentId cannot supply path separators")
    assert(String.eq(state(result_record("\"a\\u0000b\"",result_block()),0),"unsupported"),"agentId cannot contain NUL")
    assert(String.eq(state(result_record(Json.quote(String.repeat("a",129n)),result_block()),0),"unsupported"),"agentId size bound is explicit")
    assert(String.eq(state(result_record("\"abc\"","{\"type\":\"tool_use\",\"id\":\"t1\",\"name\":\"Task\"}"),0),"missing"),
      "tool_use event does not acquire result-only child metadata")
    assert(String.eq(state("{\"type\":\"user\",\"message\":{\"content\":[" ++ result_block() ++ "]}}",0),"missing"),
      "missing recorded envelope stays missing")
    assert(String.eq(state("{\"type\":\"user\",\"toolUseResult\":{\"agentId\":\"a\",\"agentId\":\"b\"},\"message\":{\"content\":[" ++ result_block() ++ "]}}",0),"unsupported"),
      "duplicate agentId JSON cannot silently choose a child")
    assert(String.eq(state("{\"type\":\"user\",\"sessionId\":\"other\",\"toolUseResult\":{\"agentId\":\"a\"},\"message\":{\"content\":[" ++ result_block() ++ "]}}",0),"unsupported"),
      "selected result session conflicts with retained incoming context")
    assert(Link.target("/p/parent.jsonl","abc","/p/parent/subagents/agent-abc.jsonl"),"parent locator names exact literal child path")
    assert(Link.target("/p/parent/subagents/agent-current.jsonl","abc","/p/parent/subagents/agent-abc.jsonl"),
      "a child result may link another retained child in its enclosing parent namespace")
    assert(Bool.not(Link.target("/p/parent.jsonl","abc","/p/parent2/subagents/agent-abc.jsonl")),"parent path matching respects component boundary")
    assert(Bool.not(Link.target("/p/parent.jsonl","abc","/p/parent/subagents/deeper/agent-abc.jsonl")),"nested unrelated basename cannot widen direct namespace")
    assert(Bool.not(Link.target("/p/parent.jsonl","abc","/p/parent/subagents/agent-abcd.jsonl")),"agent basename match is exact")
    assert(Bool.not(Link.target("/p/parent.jsonl","abc","/p/parent/subagents/../agent-abc.jsonl")),"candidate noncanonical lexical path is refused")

def capture(+db: U32,provider: String,+path: String,raw: String) -> IO(String):
  do IO<String>:
    Store.write_text(path,"w",raw)
    Store.import_file(db,provider,path)

def reference(db: U32,snapshot: String) -> IO(R.SnapshotRef):
  do IO<R.SnapshotRef>:
    value : Result<&2,&2,String,R.Header> <- R.load_header(db,snapshot)
    header : R.Header <- need(R.Header,value)
    return R.header_reference(header)

def open(db: U32,ref: R.SnapshotRef,ordinal: U32,event: U32,scope: Scoped.Scope,limit: U32) -> IO(Links.Page):
  do IO<Links.Page>:
    value : Result<&2,&2,String,Links.Page> <- Links.open(db,ref,ordinal,event,scope,limit)
    need(Links.Page,value)

def rows(page: Links.Page) -> List<&2,R.Row>:
  Links.Page{_,_,_,_,_,_,_,_,_,rows} = page
  rows

def count(page: Links.Page) -> U32:
  U32.from_nat(List.length(&2,R.Row,rows(page)))

def contains(items: List<&2,R.Row>,+snapshot: String) -> Bool:
  match items:
    case []: False{}
    case R.Row{facts,_,_,_,_,_} <> rest:
      String.eq(R.ref_id(R.facts_ref(facts)),snapshot) || contains(rest,snapshot)

def watermark(page: Links.Page) -> String:
  Links.Page{_,watermark,_,_,_,_,_,_,_,_} = page
  watermark

def cursor(page: Links.Page) -> String:
  Links.Page{_,_,_,next,_,_,_,_,_,_} = page
  match next:
    case Some{next}: next
    case None{}: ""

def citation(page: Links.Page) -> String:
  Links.Page{Links.Selected{_,_,_,_,_,_,citation,_},_,_,_,_,_,_,_,_,_} = page
  citation

def inspected(page: Links.Page) -> U32:
  Links.Page{_,_,_,_,_,_,records,_,_,_} = page
  records

def frozen(db: U32,ref: R.SnapshotRef,scope: Scoped.Scope,mark: String,cursor: String,limit: U32) -> IO(Links.Page):
  do IO<Links.Page>:
    value : Result<&2,&2,String,Links.Page> <- Links.page(db,ref,41,1,scope,mark,cursor,limit)
    need(Links.Page,value)

def integration(+db: U32,+ref: R.SnapshotRef,+child: String,+scope: Scoped.Scope) -> IO(Unit):
  do IO<Unit>:
    +page : Links.Page <- open(db,ref,41,1,scope,15)
    assert(U32.is_eq(count(page),1) && contains(rows(page),child),"late selected result resolves retained child without prefix replay")
    assert(U32.is_le(inspected(page),8),"late result reads only selected predecessor and bounded candidate prefixes")
    assert(String.contains(citation(page),"\"record\":\"41\"") && String.contains(citation(page),"\"event\":\"1\""),
      "result witness retains exact selected raw ordinal and normalized event slot")
    +encoded : String <- need(String,CLI.encode(page))
    assert(String.contains(encoded,"recorded_tool_result_agent_id") && String.contains(encoded,"candidate_on_page"),
      "additive output distinguishes recorded result links from retained path association")
    assert(String.contains(encoded,"\"agent_id\":\"abc\"") && String.contains(encoded,"\"tool_use_id\":\"t1\""),
      "recorded child ID and optional call ID remain separately visible")
    assert(String.contains(encoded,"\"role\":\"tool\"") && String.contains(encoded,"2026-10-20"),
      "output preserves target-reader role and date scope")
    +user : Links.Page <- open(db,ref,41,1,Scoped.Scope{"claude","/synthetic/repo","user",""},15)
    assert(U32.is_eq(count(user),0) && String.eq(CLI.status(user),"unsupported"),"a result never satisfies a human user role filter")
    +other : Links.Page <- open(db,ref,41,1,Scoped.Scope{"claude","/synthetic/repo/nested","",""},15)
    assert(U32.is_eq(count(other),0),"selected result repository filter uses exact equality")
    +future : Links.Page <- open(db,ref,41,1,Scoped.Scope{"claude","/synthetic/repo","tool","2026-10-22"},15)
    assert(U32.is_eq(count(future),0),"selected result must satisfy retained normalized date filter")
    +wrong_event : Links.Page <- open(db,ref,41,0,scope,15)
    assert(U32.is_eq(count(wrong_event),0) && String.eq(CLI.status(wrong_event),"missing"),"selected text cannot borrow adjacent result agentId")
    Store.exec(db,"UPDATE events SET repository='/forged',session='forged',role='user',body='forged'",[])
    +unchanged : Links.Page <- frozen(db,ref,scope,watermark(page),"0",15)
    assert(contains(rows(unchanged),child),"mutable event projection cannot forge or erase verified result link")
    fixture("/bin/mv",[".build/parent.jsonl",".build/parent-moved.jsonl"])
    fixture("/bin/mv",[".build/parent/subagents/agent-abc.jsonl",".build/child-moved.jsonl"])
    +retained : Links.Page <- frozen(db,ref,scope,watermark(page),"0",15)
    assert(contains(rows(retained),child),"result navigation survives loss of both original source logs")
    +replacement : String <- capture(db,"claude",".build/parent/subagents/agent-abc.jsonl",metadata("parent","/synthetic/other"))
    +current : Links.Page <- open(db,ref,41,1,scope,15)
    assert(U32.is_eq(count(current),0),"latest child rewrite with another repository is not silently linked")
    +historical : Links.Page <- frozen(db,ref,scope,watermark(page),"0",15)
    assert(contains(rows(historical),child) && Bool.not(contains(rows(historical),replacement)),"fixed watermark retains prior exact child generation")
    +first : Links.Page <- frozen(db,ref,scope,watermark(page),"0",1)
    assert(Bool.not(String.is_empty(cursor(first))) && Bool.not(Links.complete(first)),"remaining candidate pages are reported incomplete")
    +second : Links.Page <- frozen(db,ref,scope,watermark(page),cursor(first),1)
    assert(Bool.not(String.eq(cursor(first),cursor(second))),"candidate continuation advances the exact source cursor")
    Store.exec(db,"BEGIN",[])
    blocked : Result<&2,&2,String,Links.Page> <- Links.open(db,ref,41,1,scope,15)
    assert(failure(Links.Page,blocked,"caller transaction was not ended"),"link reader does not end a caller-owned transaction")
    Store.exec(db,"ROLLBACK",[])
    missing : Result<&2,&2,String,Links.Page> <- Links.open(db,ref,999,1,scope,15)
    assert(failure(Links.Page,missing,"outside"),"out-of-range selected record fails honestly")
    +after_fail : Links.Page <- frozen(db,ref,scope,watermark(page),"0",15)
    assert(contains(rows(after_fail),child),"ordinary selected-record failure closes only its owned transaction")

def budget_skipped(page: Links.Page) -> U32:
  Links.Page{_,_,_,_,_,_,_,_,R.Coverage{_,_,_,_,skipped},_} = page
  skipped

def budget_bytes(page: Links.Page) -> U32:
  Links.Page{_,_,_,_,_,_,_,bytes,_,_} = page
  bytes

def budgets() -> IO(Unit):
  do IO<Unit>:
    fixture("/bin/mkdir",["-p",".build/budget-parent/subagents"])
    +db : U32 <- Store.open(".build/result-budget.sqlite")
    +root : String <- capture(db,"claude",".build/budget-parent.jsonl",
      metadata("parent","/synthetic/repo") ++ result_record("\"abc\"",result_block()))
    +ref : R.SnapshotRef <- reference(db,root)
    +large : String = metadata("parent","/synthetic/repo") ++
      String.repeat("{\"type\":\"progress\",\"text\":" ++ Json.quote(String.repeat("x",71000n)) ++ "}\n",15n)
    filler : String <- capture(db,"claude",".build/budget-filler.jsonl",large)
    +child : String <- capture(db,"claude",".build/budget-parent/subagents/agent-abc.jsonl",large)
    +page : Links.Page <- open(db,ref,1,0,Scoped.Scope{"claude","/synthetic/repo","tool",""},15)
    assert(U32.is_eq(budget_skipped(page),1) && U32.is_eq(count(page),0) && String.eq(CLI.status(page),"incomplete"),
      "aggregate retained budget skips child honestly without selecting unverified metadata")
    assert(U32.is_le(budget_bytes(page),2097152),"shared 2MiB budget includes selected raw predecessor and candidate prefixes")
    +first : Links.Page <- open(db,ref,1,0,Scoped.Scope{"claude","/synthetic/repo","tool",""},1)
    next : Result<&2,&2,String,Links.Page> <- Links.page(db,ref,1,0,Scoped.Scope{"claude","/synthetic/repo","tool",""},
      watermark(first),cursor(first),1)
    +second : Links.Page <- need(Links.Page,next)
    assert(contains(rows(second),child),"fresh continuation budget can inspect previously unexamined child source")
    IO.try(Unit,Sql.close(db))

def corrupt_result(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && (String.contains(out,"integrity") || String.contains(err,"integrity")),
    "tampered selected raw fails integrity verification before navigation")

def corrupt(+db: U32,self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=41)",[Sql.Cell.Integer{snapshot}])
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["corrupt",snapshot],"",8192,10000))
    corrupt_result(result)

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    pure()
    budgets()
    fixture("/bin/mkdir",["-p",".build/parent/subagents",".build/other/subagents"])
    +db : U32 <- Store.open(".build/result-links.sqlite")
    +snapshot : String <- capture(db,"claude",".build/parent.jsonl",metadata("parent","/synthetic/repo") ++
      String.repeat("{}\n",40n) ++ result_record("\"abc\"","{\"type\":\"text\",\"text\":\"context\"}," ++ result_block()))
    +ref : R.SnapshotRef <- reference(db,snapshot)
    +child : String <- capture(db,"claude",".build/parent/subagents/agent-abc.jsonl",metadata("parent","/synthetic/repo"))
    other : String <- capture(db,"claude",".build/other/subagents/agent-abc.jsonl",metadata("parent","/synthetic/repo"))
    prefix : String <- capture(db,"claude",".build/parent/subagents/agent-abcd.jsonl",metadata("parent","/synthetic/repo"))
    ignored : String <- capture(db,"codex",".build/other-provider.jsonl","{\"type\":\"session_meta\",\"payload\":{\"id\":\"abc\",\"cwd\":\"/synthetic/repo\"}}\n")
    child_ref : R.SnapshotRef <- reference(db,child)
    child_facts : Result<&2,&2,String,R.Facts> <- R.read_facts(db,child_ref)
    f : R.Facts <- need(R.Facts,child_facts)
    assert(String.eq(R.facts_session(f),"parent"),"child raw provider sessionId is never replaced with agentId")
    +nested : String <- capture(db,"claude",".build/parent/subagents/agent-current.jsonl",
      metadata("parent","/synthetic/repo") ++ result_record("\"abc\"",result_block()))
    nested_ref : R.SnapshotRef <- reference(db,nested)
    +nested_page : Links.Page <- open(db,nested_ref,1,0,Scoped.Scope{"claude","/synthetic/repo","tool",""},15)
    assert(contains(rows(nested_page),child),"standalone child result links sibling retained capture without a recovered tool call")
    integration(db,ref,child,Scoped.Scope{"claude","/synthetic/repo","tool","2026-10-20"})
    corrupt(db,self,snapshot)
    IO.try(Unit,Sql.close(db))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "corrupt" <> snapshot <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/result-links.sqlite")
        ref : R.SnapshotRef <- reference(db,snapshot)
        page : Links.Page <- open(db,ref,41,1,Scoped.Scope{"claude","/synthetic/repo","tool",""},15)
        IO.try(Unit,Sql.close(db))
        IO.die(Unit,1,"Corruption was not detected")
    case _: IO.die(Unit,2,"Unsupported result-link test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
