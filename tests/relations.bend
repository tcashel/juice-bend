import Base
import ../src/relations.bend as R
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json

def assert(value: Bool,label: String) -> IO(Unit):
  match value:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def need(-A: Kind(&2),value: Result<&2,&2,String,A>) -> IO(A):
  match value:
    case Done{value}:
      IO.pure(A,value)
    case Fail{message}:
      IO.die(A,1,"FAIL relationship test: " ++ message)

def failure(-A: Kind(&2),value: Result<&2,&2,String,A>,expected: String) -> Bool:
  match value:
    case Done{_}:
      False{}
    case Fail{message}:
      String.contains(message,expected)

def codex(id: String,repo: String,+parent: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":" ++ id ++ ",\"cwd\":" ++ repo ++
    ",\"source\":" ++ Bool.pick(String,String.is_empty(parent),"\"cli\"",
      "{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":" ++ parent ++ "}}}") ++ "}}\n"

def meta(id: String,repo: String,+parent: String) -> String:
  codex(Json.quote(id),Json.quote(repo),Bool.pick(String,String.is_empty(parent),"",Json.quote(parent)))

def claude(session: String,repo: String) -> String:
  "{\"type\":\"user\",\"sessionId\":" ++ Json.quote(session) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"parentUuid\":\"message-parent-not-session\",\"message\":{\"content\":\"Synthetic retained request\"}}\n"

def reference(provider: String,source: String) -> R.SnapshotRef:
  R.SnapshotRef{provider,source,"1","2","100"}

def facts(provider: String,source: String,raw: String) -> R.Facts:
  R.finished(R.parsed(Json.parse(String.trim(raw)),0,
    R.Facts{reference(provider,source),R.Missing{},R.Missing{},R.UnknownParent{},0,1,0,True{},""}))

def parent(facts: R.Facts) -> R.Parent:
  R.Facts{_,_,_,parent,_,_,_,_,_} = facts
  parent

def parent_kind(value: R.Parent) -> String:
  match value:
    case R.UnknownParent{}:
      "unknown"
    case R.RecordedParent{_,_}:
      "recorded"
    case R.PathAssociated{_,_,_}:
      "path"
    case R.UnsupportedParent{_}:
      "unsupported"
    case R.ConflictingParent{_}:
      "conflicting"

def path_alias(value: R.Parent) -> String:
  match value:
    case R.PathAssociated{locator,parent,child}:
      locator ++ "|" ++ parent ++ "|" ++ child
    case _:
      ""

def edge_count(anchor: R.Facts,target: R.Facts,repo: String) -> U32:
  U32.from_nat(List.length(&2,R.Row,R.edges(anchor,target,repo)))

def all_ambiguous(rows: List<&2,R.Row>) -> Bool:
  match rows:
    case []:
      True{}
    case R.Row{_,_,_,_,_,ambiguous} <> rest:
      ambiguous && all_ambiguous(rest)

def raw_types() -> IO(Unit):
  +root = facts("codex","/synthetic/root.jsonl",meta("parent","/synthetic/repo",""))
  do IO<Unit>:
    +child : R.Facts = facts("codex","/synthetic/child.jsonl",meta("child","/synthetic/repo","parent"))
    assert(String.eq(parent_kind(parent(child)),"recorded") && U32.is_eq(edge_count(root,child,""),1),
      "typed recorded Codex parent yields a separately identified child")
    assert(String.eq(R.facts_session(child),"child"),"child recorded session identity is not replaced by parent")
    assert(U32.is_eq(edge_count(root,child,"/synthetic/repo/nested"),0),"repository scope uses exact equality rather than prefix containment")
    assert(U32.is_eq(edge_count(root,facts("codex","/synthetic/other.jsonl",meta("child","/synthetic/repo/nested","parent")),""),0),
      "different canonical repositories cannot cross-match")
    assert(U32.is_eq(edge_count(root,facts("codex","/synthetic/unknown.jsonl",codex("\"child\"","null","\"parent\"")),""),0),
      "unknown repository cannot silently match known repository")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",codex("\"child\"","\"/synthetic/repo\"","7")))),"unsupported"),
      "numeric parent ID is never coerced to a session link")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",codex("\"child\"","\"/synthetic/repo\"","true")))),"unsupported"),
      "boolean parent ID is never coerced to a session link")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",codex("\"child\"","\"/synthetic/repo\"","{}")))),"unsupported"),
      "container parent ID is never coerced to a session link")
    assert(R.facts_bad(facts("codex","/synthetic/c.jsonl",codex("7","\"/synthetic/repo\"","\"parent\""))),
      "numeric session identity remains invalid despite a supported parent field")
    assert(R.facts_bad(facts("claude","/synthetic/c.jsonl","{\"sessionId\":false,\"cwd\":\"/synthetic/repo\"}")),
      "boolean Claude session identity remains invalid")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",codex("\"child\"","\"/synthetic/repo\"","\"bad\\u0000id\"")))),"unsupported"),
      "NUL-containing parent ID is refused")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",codex("\"child\"","\"/synthetic/repo\"",Json.quote(String.repeat("😀",2049n)))))),"unsupported"),
      "parent ID bound counts UTF-8 bytes")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",codex("\"child\"","\"/synthetic/repo\"",Json.quote(String.repeat("😀",2048n)))))),"recorded"),
      "exact8192-byte string parent identifier remains supported")
    assert(U32.is_eq(edge_count(facts("codex","/synthetic/numeric-string.jsonl",meta("7","/synthetic/repo","")),
      facts("codex","/synthetic/c.jsonl",meta("child","/synthetic/repo","7")),""),1),
      "typed numeric-looking string identity is preserved without scalar coercion")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl","{\"type\":\"response_item\",\"payload\":{\"source\":{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":\"parent\"}}}}}"))),"unknown"),
      "non-metadata payload cannot inject a recorded parent link")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl","{\"type\":\"session_meta\",\"payload\":{\"id\":\"c\",\"cwd\":\"/synthetic/repo\",\"source\":{\"subagent\":{\"other\":\"guardian\"}}}}"))),"unsupported"),
      "unsupported parentless Codex variant stays explicit")
    assert(String.eq(parent_kind(parent(facts("codex","/synthetic/c.jsonl",meta("same","/synthetic/repo","same")))),"conflicting"),
      "recorded self-parent is a conflict rather than navigation")
    +conflict : R.Facts = R.finished(R.parsed(Json.parse(String.trim(meta("child","/synthetic/repo","other"))),1,child))
    assert(String.eq(parent_kind(parent(conflict)),"conflicting") && U32.is_eq(edge_count(root,conflict,""),0),
      "conflicting recorded parents remain conflicting and cannot emit an edge")
    +identity : R.Facts = R.finished(R.parsed(Json.parse(String.trim(meta("changed","/synthetic/repo","parent"))),1,child))
    assert(R.facts_bad(identity),"conflicting recorded session declarations remain distinct from a known actor")
    +cycle : List<&2,R.Row> = R.edges(facts("codex","/synthetic/a.jsonl",meta("a","/synthetic/repo","b")),
      facts("codex","/synthetic/b.jsonl",meta("b","/synthetic/repo","a")),"")
    assert(Nat.is_eq(List.length(&2,R.Row,cycle),2n) && all_ambiguous(R.mark(cycle,cycle)),
      "two-way recorded cycle is bounded and marked ambiguous rather than traversed")
    assert(Bool.not(R.canonical_path("/synthetic/../repo")) && Bool.not(R.canonical_path("/synthetic//repo")),
      "repository matching refuses noncanonical lexical paths without filesystem access")

def paths() -> IO(Unit):
  +root = facts("claude","/synthetic/project/parent.jsonl",claude("parent","/synthetic/repo"))
  +child = facts("claude","/synthetic/project/parent/subagents/agent-abcd.jsonl",claude("parent","/synthetic/repo"))
  do IO<Unit>:
    assert(String.eq(parent_kind(parent(root)),"unknown"),"Claude parentUuid remains message ancestry, not a session link")
    assert(String.eq(parent_kind(parent(child)),"path"),"Claude nested locator is explicitly a path association")
    assert(String.eq(path_alias(parent(child)),"/synthetic/project/parent.jsonl|parent|parent/agent-abcd"),
      "path alias and expected parent locator remain separate fields")
    assert(String.eq(R.facts_session(child),"parent"),"raw Claude child sessionId is preserved even when it names the parent")
    assert(U32.is_eq(edge_count(root,child,""),1) && U32.is_eq(edge_count(child,root,""),1),
      "path association supports explicit child and parent navigation")
    assert(U32.is_eq(edge_count(facts("claude","/other/project/parent.jsonl",claude("parent","/synthetic/repo")),child,""),0),
      "same parent ID in another captured path does not satisfy a locator association")
    assert(String.eq(parent_kind(parent(facts("claude","/synthetic/parent/subagents/not-json",claude("parent","/synthetic/repo")))),"unknown"),
      "non-JSONL nested filename does not invent a child alias")

def capture(+db: U32,provider: String,+path: String,raw: String) -> IO(String):
  do IO<String>:
    Store.write_text(path,"w",raw)
    Store.import_file(db,provider,path)

def resolved(+db: U32,snapshot: String) -> IO(R.SnapshotRef):
  do IO<R.SnapshotRef>:
    value : Result<&2,&2,String,R.Header> <- R.load_header(db,snapshot)
    h : R.Header <- need(R.Header,value)
    return R.header_reference(h)

def opened(db: U32,snapshot: String,repo: String,limit: U32) -> IO(R.Page):
  do IO<R.Page>:
    value : Result<&2,&2,String,R.Page> <- R.open(db,snapshot,repo,limit)
    need(R.Page,value)

def page_rows(page: R.Page) -> List<&2,R.Row>:
  R.Page{_,_,_,_,_,_,_,_,_,_,rows} = page
  rows

def row_snapshot(row: R.Row) -> String:
  R.Row{facts,_,_,_,_,_} = row
  R.ref_id(R.facts_ref(facts))

def contains(rows: List<&2,R.Row>,+snapshot: String) -> Bool:
  match rows:
    case []:
      False{}
    case row <> rest:
      String.eq(row_snapshot(row),snapshot) || contains(rest,snapshot)

def row_count(page: R.Page) -> U32:
  U32.from_nat(List.length(&2,R.Row,page_rows(page)))

def anchor(page: R.Page) -> R.SnapshotRef:
  R.Page{facts,_,_,_,_,_,_,_,_,_,_} = page
  R.facts_ref(facts)

def watermark(page: R.Page) -> String:
  R.Page{_,_,value,_,_,_,_,_,_,_,_} = page
  value

def next(page: R.Page) -> String:
  R.Page{_,_,_,_,value,_,_,_,_,_,_} = page
  match value:
    case None{}:
      ""
    case Some{value}:
      value

def continuation(+db: U32,+prior: R.Page,limit: U32) -> IO(R.Page):
  do IO<R.Page>:
    value : Result<&2,&2,String,R.Page> <- R.page(db,anchor(prior),"",watermark(prior),next(prior),limit)
    need(R.Page,value)

def replay_page(db: U32,expected: R.SnapshotRef,mark: String) -> IO(R.Page):
  do IO<R.Page>:
    value : Result<&2,&2,String,R.Page> <- R.page(db,expected,"",mark,"0",16)
    need(R.Page,value)

def stable(+db: U32,+root: String,+child: String) -> IO(Unit):
  do IO<Unit>:
    +before : R.Page <- opened(db,root,"",16)
    assert(contains(page_rows(before),child),"related child is resolved from verified retained metadata")
    Store.write_text("child.jsonl","a","{}\n")
    +appended : String <- Store.import_file(db,"codex","child.jsonl")
    +append_page : R.Page <- opened(db,root,"",16)
    assert(U32.is_eq(row_count(append_page),1) && contains(page_rows(append_page),appended),
      "one accepted snapshot per source prevents append-version duplicates")
    +rewritten : String <- capture(db,"codex","child.jsonl",meta("child","/synthetic/repo","replacement"))
    +current : R.Page <- opened(db,root,"",16)
    assert(U32.is_eq(row_count(current),0),"rewritten source uses only its newest accepted generation at the new watermark")
    +old : R.Page <- replay_page(db,anchor(before),watermark(before))
    assert(contains(page_rows(old),child) && Bool.not(contains(page_rows(old),rewritten)),
      "fixed watermark keeps the original child snapshot across append and rewrite")
    assert(R.same_ref(anchor(before),anchor(old)),"old selected anchor remains immutable")
    Store.exec(db,"UPDATE events SET parent='forged',session='forged',repository='/forged'",[])
    +unchanged : R.Page <- replay_page(db,anchor(before),watermark(before))
    assert(contains(page_rows(unchanged),child),"mutable normalized event projection cannot forge relationship metadata")
    moved : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mv",["child.jsonl","child-moved.jsonl"],"",8192,10000))
    +retained : R.Page <- replay_page(db,anchor(before),watermark(before))
    assert(contains(page_rows(retained),child),"relationship navigation survives original source relocation")

def transactions(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"CREATE TABLE relation_owner(value TEXT)",[])
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"INSERT INTO relation_owner VALUES('pending')",[])
    refused : Result<&2,&2,String,R.Page> <- R.open(db,root,"",16)
    assert(failure(R.Page,refused,"transaction start failed"),"preexisting caller transaction is refused")
    inside : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM relation_owner",[],1)
    assert(String.eq(Store.field(Store.first(inside),0n),"1"),"refusal preserves uncommitted caller work")
    +other : U32 <- Store.open(".build/relations.sqlite")
    unseen : List<&2,List<&2,Sql.Cell>> <- Store.q(other,"SELECT count(*) FROM relation_owner",[],1)
    assert(String.eq(Store.field(Store.first(unseen),0n),"0"),"refusal does not commit caller work")
    IO.try(Unit,Sql.close(other))
    Store.exec(db,"ROLLBACK",[])
    page : R.Page <- opened(db,root,"",16)
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"successful relationship read ends only its own transaction")
    missing : Result<&2,&2,String,R.Page> <- R.open(db,"999999","",16)
    assert(failure(R.Page,missing,"missing"),"missing accepted anchor is an explicit ordinary failure")
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"ordinary anchor failure closes the owned transaction")
    invalid : Result<&2,&2,String,R.Page> <- R.open(db,"01","",16)
    assert(failure(R.Page,invalid,"valid snapshot"),"noncanonical snapshot identity is refused before reading")
    +ref : R.SnapshotRef <- resolved(db,root)
    facts : Result<&2,&2,String,R.Facts> <- R.read_facts(db,ref)
    +known : R.Facts <- need(R.Facts,facts)
    assert(String.eq(R.facts_session(known),"parent"),"standalone verified facts reader preserves the recorded session")
    wrong : Result<&2,&2,String,R.Facts> <- R.read_facts(db,R.SnapshotRef{"codex","/wrong/source","1",root,"0"})
    assert(failure(R.Facts,wrong,"does not match"),"forged selected source/generation/extent cannot rebind an anchor")
    no_watermark : Result<&2,&2,String,R.Page> <- R.page(db,ref,"","999999","0",16)
    assert(failure(R.Page,no_watermark,"unavailable"),"watermark must name an accepted snapshot")
    wrong_cursor : Result<&2,&2,String,R.Page> <- R.page(db,ref,"",root,"01",16)
    assert(failure(R.Page,wrong_cursor,"cursor"),"source cursor is a canonical exact decimal identity")

def prefix() -> String:
  meta("child","/synthetic/repo","parent") ++ String.repeat("{}\n",15n)

def many(fuel: Nat,+db: U32,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        snapshot : String <- capture(db,"codex","many-" ++ U32.show(index) ++ ".jsonl",prefix())
        many(rest,db,U32.inc(index))

def page_counts(page: R.Page) -> String:
  R.Page{_,_,_,_,_,limit,scanned,records,_,_,_} = page
  U32.show(limit) ++ "|" ++ U32.show(scanned) ++ "|" ++ U32.show(records)

def complete(facts: R.Facts) -> Bool:
  R.Facts{_,_,_,_,_,_,_,complete,_} = facts
  complete

def pagination() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/relations-pages.sqlite")
    +root : String <- capture(db,"codex","page-parent.jsonl",meta("parent","/synthetic/repo","") ++ String.repeat("{}\n",15n))
    many(17n,db,0)
    +first : R.Page <- opened(db,root,"",16)
    assert(String.eq(page_counts(first),"15|15|256"),"candidate clamp reserves anchor and verifies at most256 physical records")
    assert(U32.is_eq(row_count(first),15) && all_ambiguous(page_rows(first)),
      "duplicate child session IDs across sources stay separate ambiguous captures")
    assert(Bool.not(String.is_empty(next(first))),"one-row lookahead returns an exact source cursor")
    added : String <- capture(db,"codex","after-watermark.jsonl",meta("new","/synthetic/repo","parent"))
    +second : R.Page <- continuation(db,first,16)
    assert(String.eq(page_counts(second),"15|2|48") && String.is_empty(next(second)),"continuation stays bounded and excludes sources accepted after watermark")
    assert(R.same_ref(anchor(first),anchor(second)) && String.eq(watermark(first),watermark(second)),
      "continuation preserves exact anchor and inventory watermark")
    +late : String <- capture(db,"codex","late-parent.jsonl",meta("late","/synthetic/repo","") ++ String.repeat("{}\n",15n) ++ meta("late","/synthetic/repo","parent"))
    ref : R.SnapshotRef <- resolved(db,late)
    value : Result<&2,&2,String,R.Facts> <- R.read_facts(db,ref)
    +facts : R.Facts <- need(R.Facts,value)
    assert(Bool.not(complete(facts)) && String.eq(parent_kind(parent(facts)),"unknown"),
      "parent metadata beyond16 records stays unexamined and explicitly partial")
    IO.try(Unit,Sql.close(db))

def skipped(page: R.Page) -> U32:
  R.Page{_,_,_,_,_,_,_,_,_,R.Coverage{_,_,_,_,skipped},_} = page
  skipped

def budgets() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/relations-budget.sqlite")
    +root : String <- capture(db,"codex","budget-parent.jsonl",meta("parent","/synthetic/repo",""))
    +large : String <- capture(db,"codex","budget-large.jsonl",meta("large","/synthetic/repo","parent") ++
      String.repeat("{\"type\":\"event_msg\",\"payload\":{\"type\":\"agent_message\",\"message\":" ++ Json.quote(String.repeat("x",240000n)) ++ "}}\n",9n))
    +small : String <- capture(db,"codex","budget-small.jsonl",meta("small","/synthetic/repo","parent"))
    +first : R.Page <- opened(db,root,"",1)
    assert(U32.is_eq(skipped(first),1) && U32.is_eq(row_count(first),0) && Bool.not(String.is_empty(next(first))),
      "oversized candidate reports unexamined budget coverage and an advancing cursor")
    +second : R.Page <- continuation(db,first,1)
    assert(contains(page_rows(second),small) && String.is_empty(next(second)),
      "single oversized source cannot trap pagination before a later related source")
    refused : Result<&2,&2,String,R.Page> <- R.open(db,large,"",1)
    assert(failure(R.Page,refused,"2097152-byte"),"oversized anchor fails explicitly rather than inventing anchor identity")
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"anchor budget failure closes its owned transaction")
    IO.try(Unit,Sql.close(db))

def child_failure(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,"integrity"),"corrupt retained raw fails hard before relationship evidence is emitted")

def corrupt(+db: U32,self: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"codex","corrupt.jsonl",meta("corrupt","/synthetic/repo","parent"))
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["corrupt",snapshot],"",8192,30000))
    child_failure(result)

def retained_facts(+db: U32,snapshot: String) -> IO(R.Facts):
  do IO<R.Facts>:
    ref : R.SnapshotRef <- resolved(db,snapshot)
    value : Result<&2,&2,String,R.Facts> <- R.read_facts(db,ref)
    need(R.Facts,value)

def authority() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/relations-authority.sqlite")
    +root : String <- capture(db,"codex","authority-parent.jsonl",meta("parent","/synthetic/repo",""))
    +added : String <- capture(db,"codex","authority-added.jsonl",
      meta("child","/synthetic/repo","") ++ meta("child","/synthetic/repo","parent"))
    +facts : R.Facts <- retained_facts(db,added)
    assert(String.eq(R.facts_session(facts),"child") && String.eq(parent_kind(parent(facts)),"conflicting"),
      "later same-ID metadata cannot upgrade an ordinary first header into a child")
    +page : R.Page <- opened(db,root,"",15)
    assert(Bool.not(contains(page_rows(page),added)),"later metadata parent injection emits no captured navigation edge")
    +fork : String <- capture(db,"codex","authority-fork.jsonl",
      meta("fork-self","/synthetic/repo","") ++ meta("historical-parent","/synthetic/other","ancestor"))
    +facts : R.Facts <- retained_facts(db,fork)
    assert(String.eq(R.facts_session(facts),"fork-self") && String.eq(R.facts_repo(facts),"/synthetic/repo"),
      "retained fork metadata cannot replace the first header actor or repository")
    assert(String.eq(parent_kind(parent(facts)),"conflicting"),"retained fork parent disagreement remains explicit conflict")
    +same : String <- capture(db,"codex","authority-same.jsonl",
      meta("direct-child","/synthetic/repo","parent") ++ meta("direct-child","/synthetic/repo","parent") ++
      "{\"type\":\"event_msg\",\"session_id\":\"imposter\",\"cwd\":\"/other\",\"payload\":{\"session_id\":\"other\",\"cwd\":\"/elsewhere\"}}\n")
    +facts : R.Facts <- retained_facts(db,same)
    assert(String.eq(R.facts_session(facts),"direct-child") && String.eq(R.facts_repo(facts),"/synthetic/repo") &&
      String.eq(parent_kind(parent(facts)),"recorded"),"duplicate metadata and event-local identity fields do not replace first-header authority")
    +page : R.Page <- opened(db,root,"",15)
    assert(contains(page_rows(page),same),"a consistent duplicate header preserves the first recorded relationship")
    +missing : String <- capture(db,"codex","authority-missing.jsonl",
      "{\"type\":\"session_meta\",\"payload\":{\"source\":\"cli\"}}\n" ++ meta("later","/synthetic/repo","parent"))
    +facts : R.Facts <- retained_facts(db,missing)
    assert(String.is_empty(R.facts_session(facts)) && String.is_empty(R.facts_repo(facts)) &&
      String.eq(parent_kind(parent(facts)),"conflicting"),"a missing first-header identity stays unknown instead of borrowing later fork metadata")
    +delayed : String <- capture(db,"codex","authority-delayed.jsonl",
      "{\"type\":\"event_msg\",\"session_id\":\"imposter\",\"cwd\":\"/other\"}\n" ++
      meta("delayed","/synthetic/repo","parent"))
    +facts : R.Facts <- retained_facts(db,delayed)
    assert(String.eq(R.facts_session(facts),"delayed") && String.eq(R.facts_repo(facts),"/synthetic/repo"),
      "the first actual metadata header owns identity even after nonmetadata records")
    IO.try(Unit,Sql.close(db))

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    raw_types()
    paths()
    authority()
    +db : U32 <- Store.open(".build/relations.sqlite")
    +root : String <- capture(db,"codex","parent.jsonl",meta("parent","/synthetic/repo",""))
    +child : String <- capture(db,"codex","child.jsonl",meta("child","/synthetic/repo","parent"))
    other_repo : String <- capture(db,"codex","wrong-repo.jsonl",meta("child","/synthetic/other","parent"))
    other_provider : String <- capture(db,"claude","wrong-provider.jsonl",claude("parent","/synthetic/repo"))
    +duplicate : String <- capture(db,"codex","duplicate.jsonl",meta("parent","/synthetic/repo",""))
    +parents : R.Page <- opened(db,child,"/synthetic/repo",16)
    assert(U32.is_eq(row_count(parents),2) && contains(page_rows(parents),root) && contains(page_rows(parents),duplicate) &&
      all_ambiguous(page_rows(parents)),"scoped duplicate parent identities remain separate ambiguous target captures")
    wrong_scope : R.Page <- opened(db,child,"/synthetic/other",16)
    assert(U32.is_eq(row_count(wrong_scope),0),"explicit repository scope never widens to anchor repository")
    stable(db,root,child)
    transactions(db,root)
    pagination()
    budgets()
    corrupt(db,self)
    IO.try(Unit,Sql.close(db))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "corrupt" <> snapshot <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/relations.sqlite")
        page : R.Page <- opened(db,snapshot,"",1)
        IO.try(Unit,Sql.close(db))
        IO.die(Unit,1,"Corruption was not detected")
    case _:
      IO.die(Unit,2,"Unsupported relationship test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
