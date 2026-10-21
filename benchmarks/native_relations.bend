import Base
import ./native_activity.bend as Safe
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths
import ../src/maintenance.bend as Maintenance
import ../src/relations.bend as R
import ../src/relations_cli.bend as Wire
import ../src/scoped_reader.bend as Scoped
import ../src/activity_reader.bend as ActivityReader
import ../src/tool_activity.bend as Activity

# All synthetic log semantics are Bend. Only an explicitly named new private
# root is accepted. The source-only mutations do not capture: pause automatic
# refresh, append-only, rewrite-only, then use the real app's Refresh command.
# The shared fixture's narrow OS/path helpers never receive a foreign root.
def checked(valid: Bool,message: String) -> IO(Unit):
  Store.checked(valid,"Native Related fixture: " ++ message)

def need(-A: Kind(&2),value: Result<&2,&2,String,A>) -> IO(A):
  match value:
    case Done{value}:
      IO.pure(A,value)
    case Fail{message}:
      IO.die(A,1,"Native Related fixture: " ++ message)

def root_shape(+root: String) -> Bool:
  +name = Safe.leaf_parts(List.reverse(&2,String,String.split(root,'/')))
  String.starts_with(root,"/") && Nat.is_le(String.length(root),4000n) &&
    (String.eq(name,"juice-bend-relations-fixture") || String.starts_with(name,"juice-bend-relations-fixture-")) &&
    Safe.name_chars(name) && Nat.is_le(String.length(name),100n) && Bool.not(String.contains(root,"\0"))

def repo() -> String:
  "/synthetic/relations"

def current() -> String:
  "2026-10-20T12:00:00Z"

def meta(id: String,repository: String,+parent: String) -> String:
  "{\"type\":\"session_meta\",\"timestamp\":" ++ Json.quote(current()) ++
    ",\"payload\":{\"id\":" ++ Json.quote(id) ++ ",\"cwd\":" ++ Json.quote(repository) ++
    ",\"source\":" ++ Bool.pick(String,String.is_empty(parent),"\"cli\"",
      "{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":" ++ Json.quote(parent) ++ "}}}") ++ "}}\n"

def item(time: String,payload: String) -> String:
  "{\"type\":\"response_item\",\"timestamp\":" ++ Json.quote(time) ++ ",\"payload\":" ++ payload ++ "}\n"

def message(role: String,time: String,text: String) -> String:
  item(time,"{\"type\":\"message\",\"role\":" ++ Json.quote(role) ++
    ",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(text) ++ "}]}")

def call(id: String,text: String) -> String:
  item(current(),"{\"type\":\"function_call\",\"name\":\"Bash\",\"call_id\":" ++ Json.quote(id) ++
    ",\"arguments\":" ++ Json.quote("{\"command\":" ++ Json.quote(text) ++ "}") ++ "}")

def result(id: String,text: String) -> String:
  item(current(),"{\"type\":\"function_call_output\",\"call_id\":" ++ Json.quote(id) ++
    ",\"output\":" ++ Json.quote(text) ++ "}")

def filler(fuel: Nat,+ordinal: U32) -> String:
  match fuel:
    case 0n:
      ""
    case 1n+rest:
      message("assistant",current(),"Parent ordinary record " ++ U32.show(ordinal)) ++ filler(rest,U32.inc(ordinal))

def parent() -> String:
  meta("parent-café",repo(),"") ++ filler(39n,1) ++
    message("assistant",current(),"originneedle café 中文 🙂 — the exact old reader begins at physical record 40.") ++
    call("origin-call","origin argument café 中文 🙂, displayed only") ++
    result("origin-call","origin result must be excluded by assistant-only scope") ++
    message("user",current(),"excluded-origin-user") ++ message("assistant",current(),"Original final assistant record 44.")

def child(+changed: Bool) -> String:
  meta("child-中文",repo(),Bool.pick(String,changed,"detached-after-rewrite","parent-café")) ++
    message("assistant","2026-10-19T23:59:59Z","excluded-old-date-child") ++
    message("assistant",current(),Bool.pick(String,changed,"rewritten-child-only", "eligible child café 中文 🙂")) ++
    call("child-call",Bool.pick(String,changed,"rewritten child argument", "eligible child argument café 中文 🙂")) ++
    result("child-call","excluded-child-tool-result") ++ message("user",current(),"excluded-child-user")

def claude(text: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":\"claude-parent-café\",\"cwd\":" ++ Json.quote(repo()) ++
    ",\"parentUuid\":\"message-parent-not-session\",\"timestamp\":" ++ Json.quote(current()) ++
    ",\"message\":{\"content\":[{\"type\":\"text\",\"text\":" ++ Json.quote(text) ++ "}]}}\n"

def initial(+index: U32) -> String:
  match index:
    case 1:
      parent()
    case 2:
      child(False{})
    case 3:
      message("assistant",current(),"unknown metadata candidate")
    case 4:
      meta("conflicting-child",repo(),"parent-café") ++ meta("conflicting-child",repo(),"different-parent") ++
        message("assistant",current(),"conflicting declarations cannot become a link")
    case 5:
      meta("unrelated-session",repo(),"") ++ message("assistant",current(),"unrelated candidate")
    case 6:
      meta("wrong-repository","/synthetic/relations/nested","parent-café") ++
        message("assistant",current(),"excluded-repository-prefix-child")
    case 7:
      meta("old-date-child",repo(),"parent-café") ++
        message("assistant","2026-10-19T23:59:59Z","excluded-old-date-only-child")
    case 8:
      meta("user-only-child",repo(),"parent-café") ++ message("user",current(),"excluded-user-only-child")
    case 9:
      meta("duplicate-child",repo(),"parent-café") ++ message("assistant",current(),"First separate duplicate actor capture.")
    case 10:
      meta("duplicate-child",repo(),"parent-café") ++ message("assistant",current(),"Second separate duplicate actor capture.")
    case 17:
      meta("late-child-🙂",repo(),"parent-café") ++ message("assistant",current(),"Second candidate page child café 中文 🙂") ++
        call("late-call","second page argument") ++ result("late-call","second page result")
    case 19:
      "{\"type\":\"session_meta\",\"payload\":{\"id\":\"missing-repository\",\"source\":{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":\"parent-café\"}}}}}\n"
    case 20:
      "{\"type\":\"session_meta\",\"payload\":{\"id\":\"unsupported-parent\",\"cwd\":" ++ Json.quote(repo()) ++
        ",\"source\":{\"subagent\":{\"thread_spawn\":{\"parent_thread_id\":7}}}}}\n"
    case 21:
      claude("claudeneedle parent retained path association café 中文 🙂")
    case 22:
      claude("Claude child keeps its raw parent-valued sessionId; its locator is a separately labeled association.")
    case _:
      meta("unrelated-" ++ U32.show(index),repo(),"") ++ message("assistant",current(),"Candidate filler " ++ U32.show(index))

def appended() -> String:
  call("future-call","future-parent-argument must not enter snapshot 1") ++ result("future-call","future-parent-result")

def source_text(+index: U32,+phase: U32) -> String:
  match index:
    case 1:
      initial(index) ++ Bool.pick(String,U32.is_gt(phase,0),appended(),"")
    case 2:
      child(U32.is_eq(phase,2))
    case _:
      initial(index)

def provider(index: U32) -> String:
  Bool.pick(String,U32.is_lt(index,21),"codex","claude")

def relative(index: U32) -> String:
  match index:
    case 1:
      "codex/01-parent café.jsonl"
    case 2:
      "codex/02-child 中文.jsonl"
    case 21:
      "claude/parent-café.jsonl"
    case 22:
      "claude/parent-café/subagents/agent-中文.jsonl"
    case _:
      "codex/source-" ++ U32.show(index) ++ ".jsonl"

def source(root: String,index: U32) -> String:
  root ++ "/captures/" ++ relative(index)

def database(root: String) -> String:
  root ++ "/library/juice-bend.sqlite"

def marker(root: String) -> String:
  root ++ "/.juice-bend-relations-fixture-v1"

def records(text: String) -> U32:
  U32.from_nat(Nat.sub(List.length(&2,String,String.split(text,'\n')),1n))

def total(fuel: Nat,+index: U32) -> U32:
  match fuel:
    case 0n:
      0
    case 1n+rest:
      U32.add(records(initial(index)),total(rest,U32.inc(index)))

def reference(+root: String,+index: U32) -> R.SnapshotRef:
  R.SnapshotRef{provider(index),source(root,index),U32.show(index),U32.show(index),
    U32.show(U32.from_nat(List.length(&2,U32,Domain.encode(initial(index)))))}

def references(fuel: Nat,+root: String,+index: U32) -> List<&2,R.SnapshotRef>:
  match fuel:
    case 0n:
      []
    case 1n+rest:
      reference(root,index) <> references(rest,root,U32.inc(index))

def reference_strings(refs: List<&2,R.SnapshotRef>) -> List<&2,String>:
  match refs:
    case []:
      []
    case ref <> rest:
      Wire.reference_json(ref) <> reference_strings(rest)

def description(+root: String,refs: List<&2,R.SnapshotRef>) -> String:
  "{\"fixture\":\"juice-bend-relations-fixture-v1\",\"root\":" ++ Json.quote(root) ++
    ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"repository\":" ++ Json.quote(repo()) ++
    ",\"origin_query\":\"originneedle\",\"origin_start\":40,\"scope\":{\"provider\":\"codex\",\"repository\":" ++
    Json.quote(repo()) ++ ",\"role\":\"assistant\",\"after\":\"2026-10-20\"},\"sources\":[" ++
    String.join(reference_strings(refs),",") ++ "]}"

def capture_all(fuel: Nat,+db: U32,+root: String,+index: U32) -> IO(List<&2,R.SnapshotRef>):
  match fuel:
    case 0n:
      IO.pure(List<&2,R.SnapshotRef>,[])
    case 1n+rest:
      do IO<List<&2,R.SnapshotRef>>:
        Store.write_text(source(root,index),"w",initial(index))
        Safe.private_file(source(root,index),"600")
        +snapshot : String <- Store.import_file(db,provider(index),source(root,index))
        checked(String.eq(snapshot,U32.show(index)),"initial snapshot sequence differs")
        loaded : Result<&2,&2,String,R.Header> <- R.load_header(db,snapshot)
        h : R.Header <- need(R.Header,loaded)
        +ref : R.SnapshotRef = R.header_reference(h)
        checked(R.same_ref(ref,reference(root,index)),"captured reference differs from exact fixture identity")
        following : List<&2,R.SnapshotRef> <- capture_all(rest,db,root,U32.inc(index))
        return ref <> following

def files(fuel: Nat,+root: String,+index: U32,+phase: U32,+hidden: Bool) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        Safe.exact_file(source(root,index) ++ Bool.pick(String,hidden,".retained",""),source_text(index,phase))
        Safe.absent(source(root,index) ++ Bool.pick(String,hidden,"",".retained"))
        files(rest,root,U32.inc(index),phase,hidden)

def exact_capture(+db: U32,snapshot: String,text: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.bytes FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal LIMIT 64",
      [Sql.Cell.Integer{snapshot}],64)
    bytes : List<&2,U32> <- need(List<&2,U32>,Safe.captured_bytes(rows))
    checked(Domain.bytes_equal(bytes,Domain.encode(text)),"retained bytes differ from exact fixture")

def original_captures(fuel: Nat,+db: U32,+root: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        loaded : Result<&2,&2,String,R.Header> <- R.load_header(db,U32.show(index))
        header : R.Header <- need(R.Header,loaded)
        checked(R.same_ref(R.header_reference(header),reference(root,index)),"original capture identity changed")
        Safe.scalar(db,"SELECT count(*) FROM sources WHERE id=? AND provider=? AND locator=?",
          [Sql.Cell.Integer{U32.show(index)},Sql.Cell.Text{provider(index)},Sql.Cell.Text{source(root,index)}],"1")
        Maintenance.verify(db,U32.show(index))
        exact_capture(db,U32.show(index),initial(index))
        original_captures(rest,db,root,U32.inc(index))

def initial_state(+db: U32,+root: String) -> IO(Unit):
  +count = U32.show(total(22n,1))
  do IO<Unit>:
    Safe.scalar(db,"PRAGMA user_version",[],"2")
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Safe.scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    Safe.scalar(db,"SELECT count(*) FROM sources",[],"22")
    Safe.scalar(db,"SELECT count(*) FROM generations",[],"22")
    Safe.scalar(db,"SELECT count(*) FROM snapshots",[],"22")
    Safe.scalar(db,"SELECT count(*) FROM sources WHERE latest=id",[],"22")
    Safe.scalar(db,"SELECT count(*) FROM raw",[],count)
    Safe.scalar(db,"SELECT count(*) FROM records",[],count)
    Safe.scalar(db,"SELECT count(*) FROM events",[],count)
    Safe.scalar(db,"SELECT count(*) FROM search",[],count)
    original_captures(22n,db,root,1)

def page_rows(page: R.Page) -> List<&2,R.Row>:
  R.Page{_,_,_,_,_,_,_,_,_,_,rows} = page
  rows

def contains(rows: List<&2,R.Row>,+snapshot: String) -> Bool:
  match rows:
    case []:
      False{}
    case R.Row{facts,_,_,_,_,_} <> rest:
      String.eq(R.ref_id(R.facts_ref(facts)),snapshot) || contains(rest,snapshot)

def paging(page: R.Page,watermark: String,cursor: String,scanned: U32,row_count: Nat) -> Bool:
  R.Page{_,_,id,_,next,limit,count,_,_,_,rows} = page
  String.eq(id,watermark) && String.eq(Wire.next_json(next),cursor) && U32.is_eq(limit,15) &&
    U32.is_eq(count,scanned) && Nat.is_eq(List.length(&2,R.Row,rows),row_count)

def old_relations(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    first_result : Result<&2,&2,String,R.Page> <- R.page(db,reference(root,1),repo(),"22","0",15)
    +first : R.Page <- need(R.Page,first_result)
    checked(paging(first,"22","\"16\"",15,5n) && contains(page_rows(first),"2") &&
      contains(page_rows(first),"7") && contains(page_rows(first),"8") && contains(page_rows(first),"9") &&
      contains(page_rows(first),"10"),"first Related page does not have exact inspected candidates/links")
    second_result : Result<&2,&2,String,R.Page> <- R.page(db,reference(root,1),repo(),"22","16",15)
    +second : R.Page <- need(R.Page,second_result)
    checked(paging(second,"22","null",4,1n) && contains(page_rows(second),"17"),
      "second Related page did not retain exact source cursor and watermark")
    claude_result : Result<&2,&2,String,R.Page> <- R.page(db,reference(root,21),repo(),"22","0",15)
    +claude_page : R.Page <- need(R.Page,claude_result)
    checked(paging(claude_page,"22","null",1,1n) && contains(page_rows(claude_page),"22") &&
      String.contains(Wire.render(claude_page,Scoped.Scope{"claude",repo(),"assistant","2026-10-20"}),"retained_path_association"),
      "Claude captured locator association was not kept separate")

def scope() -> Scoped.Scope:
  Scoped.Scope{"codex",repo(),"assistant","2026-10-20"}

def readers(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +origin : String <- Scoped.page(db,"1",40,40,scope(),False{})
    checked(String.contains(origin,"originneedle café 中文 🙂") && String.contains(origin,"origin argument") &&
      Bool.not(String.contains(origin,"excluded-origin-user")) && Bool.not(String.contains(origin,"origin result")) &&
      Bool.not(String.contains(origin,"future-parent")),"origin range or exact reader scope changed")
    +child : String <- Scoped.page(db,"2",0,40,scope(),False{})
    checked(String.contains(child,"eligible child café 中文 🙂") && String.contains(child,"eligible child argument") &&
      Bool.not(String.contains(child,"excluded-")) && Bool.not(String.contains(child,"rewritten-child-only")),
      "child old capture or exact role/date scope changed")
    activity_result : Result<&2,&2,String,ActivityReader.Page> <- ActivityReader.read(db,"2",0,40,scope())
    activity : ActivityReader.Page <- need(ActivityReader.Page,activity_result)
    checked(String.eq(Safe.counts(activity),"2|1|0|0|0|0|1"),"filtered child Tools lost scoped unpaired occurrence")
    all_result : Result<&2,&2,String,ActivityReader.Page> <- ActivityReader.read(db,"2",0,40,Scoped.Scope{"","","",""})
    all : ActivityReader.Page <- need(ActivityReader.Page,all_result)
    checked(String.eq(Safe.counts(all),"6|1|1|1|0|0|0"),"unfiltered child Tools pair differs")

def owned(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"invalid absolute fixture root")
    Safe.regular_path(root,True{})
    Safe.exact_file(marker(root),description(root,references(22n,root,1)) ++ "\n")
    Safe.regular_path(root ++ "/library",True{})
    Safe.regular_path(root ++ "/captures",True{})
    Safe.regular_path(root ++ "/captures/codex",True{})
    Safe.regular_path(root ++ "/captures/claude",True{})
    Safe.regular_path(root ++ "/captures/claude/parent-café",True{})
    Safe.regular_path(root ++ "/captures/claude/parent-café/subagents",True{})
    Safe.regular_path(database(root),False{})
    Safe.optional_file(database(root) ++ "-wal")
    Safe.optional_file(database(root) ++ "-shm")
    Safe.optional_file(database(root) ++ "-journal")

def fixture(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"new canonical root must use juice-bend-relations-fixture basename and optional safe suffix")
    checked(Nat.is_le(List.length(&2,U32,Domain.encode(description(root,references(22n,root,1)) ++ "\n")),65536n),
      "encoded root-bound marker exceeds its 64 KiB verification bound")
    canonical : String <- Paths.destination(root)
    checked(String.eq(canonical,root),"new root's existing parent must be canonical")
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(root ++ "/library")
    Safe.directory(root ++ "/captures")
    Safe.directory(root ++ "/captures/codex")
    Safe.directory(root ++ "/captures/claude")
    Safe.directory(root ++ "/captures/claude/parent-café")
    Safe.directory(root ++ "/captures/claude/parent-café/subagents")
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    Safe.private_file(database(root),"600")
    Store.schema(db)
    +captures : List<&2,R.SnapshotRef> <- capture_all(22n,db,root,1)
    initial_state(db,root)
    old_relations(db,root)
    readers(db)
    IO.try(Unit,Sql.close(db))
    Store.write_text(marker(root),"w",description(root,captures) ++ "\n")
    Safe.private_file(marker(root),"400")
    IO.print(description(root,captures))

def change(+root: String,+rewrite: Bool) -> IO(Unit):
  +phase = Bool.pick(U32,rewrite,1,0)
  +index = Bool.pick(U32,rewrite,2,1)
  do IO<Unit>:
    owned(root)
    files(22n,root,1,phase,False{})
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    initial_state(db,root)
    IO.try(Unit,Sql.close(db))
    Safe.exact_file(source(root,index),source_text(index,phase))
    Store.write_text(source(root,index),Bool.pick(String,rewrite,"w","a"),
      Bool.pick(String,rewrite,child(True{}),appended()))
    files(22n,root,1,U32.inc(phase),False{})
    IO.print("{\"source_changed\":" ++ Json.quote(Bool.pick(String,rewrite,"child_rewrite","parent_append")) ++
      ",\"capture_requested\":false,\"root\":" ++ Json.quote(root) ++ ",\"prior_watermark\":\"22\"}")

def latest(+db: U32,index: U32) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT latest FROM sources WHERE id=?",
      [Sql.Cell.Integer{U32.show(index)}],1)
    return Store.field(Store.first(rows),0n)

def changed_capture(+db: U32,+root: String,+index: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    checked(String.eq(snapshot,"23") || String.eq(snapshot,"24"),"changed source did not receive one of the two new snapshots")
    Safe.scalar(db,"SELECT count(*) FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1 AND p.records=? AND g.id=? AND s.id=? AND s.locator=? AND s.provider='codex'",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(records(source_text(index,2)))},
       Sql.Cell.Integer{Bool.pick(String,U32.is_eq(index,1),"1","23")},Sql.Cell.Integer{U32.show(index)},
       Sql.Cell.Text{source(root,index)}],"1")
    Maintenance.verify(db,snapshot)
    exact_capture(db,snapshot,source_text(index,2))

def final_state(+db: U32,+root: String) -> IO(Unit):
  +count = total(22n,1)
  do IO<Unit>:
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Safe.scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    Safe.scalar(db,"SELECT count(*) FROM sources",[],"22")
    Safe.scalar(db,"SELECT count(*) FROM generations",[],"23")
    Safe.scalar(db,"SELECT count(*) FROM snapshots",[],"24")
    Safe.scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1",[],"24")
    Safe.scalar(db,"SELECT count(*) FROM sources WHERE id>2 AND latest=id",[],"20")
    Safe.scalar(db,"SELECT count(*) FROM raw",[],U32.show(U32.add(count,8)))
    Safe.scalar(db,"SELECT count(*) FROM records",[],U32.show(U32.add(count,53)))
    Safe.scalar(db,"SELECT count(*) FROM events",[],U32.show(U32.add(count,53)))
    Safe.scalar(db,"SELECT count(*) FROM search",[],U32.show(U32.add(count,2)))
    original_captures(22n,db,root,1)
    +parent_snapshot : String <- latest(db,1)
    +child_snapshot : String <- latest(db,2)
    checked(Bool.not(String.eq(parent_snapshot,child_snapshot)),"new captures were conflated")
    changed_capture(db,root,1,parent_snapshot)
    changed_capture(db,root,2,child_snapshot)
    old_relations(db,root)
    readers(db)
    new_result : Result<&2,&2,String,R.Page> <- R.page(db,reference(root,1),repo(),"24","0",15)
    +new_page : R.Page <- need(R.Page,new_result)
    checked(paging(new_page,"24","\"16\"",15,4n) && Bool.not(contains(page_rows(new_page),"2")) &&
      Bool.not(contains(page_rows(new_page),child_snapshot)),"fresh inventory incorrectly resurrected the rewritten parent relationship")

def hide_files(fuel: Nat,+root: String,+index: U32) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        moved : String <- Safe.command("/bin/mv",["-n",source(root,index),source(root,index) ++ ".retained"])
        Safe.absent(source(root,index))
        Safe.exact_file(source(root,index) ++ ".retained",source_text(index,2))
        hide_files(rest,root,U32.inc(index))

def hide(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    files(22n,root,1,2,False{})
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    final_state(db,root)
    hide_files(22n,root,1)
    files(22n,root,1,2,True{})
    old_relations(db,root)
    readers(db)
    IO.try(Unit,Sql.close(db))
    IO.print("{\"hidden_sources\":22,\"accepted_snapshots\":24,\"old_watermark\":\"22\",\"new_watermark\":\"24\",\"root\":" ++ Json.quote(root) ++ "}")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []:
      fixture(root)
    case _ <> "append-only" <> root <> []:
      change(root,False{})
    case _ <> "rewrite-only" <> root <> []:
      change(root,True{})
    case _ <> "hide" <> root <> []:
      hide(root)
    case _:
      IO.die(Unit,2,"Usage: native-relations fixture NEW_ROOT | append-only ROOT | rewrite-only ROOT (before app capture) | hide ROOT (after app accepts both changes)")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
