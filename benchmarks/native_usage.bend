import Base
import ./native_activity.bend as Safe
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths
import ../src/maintenance.bend as Maintenance
import ../src/session_usage.bend as Usage
import ../src/session_usage_cli.bend as Wire
import ../src/session_usage_counts.bend as Counts
import ../src/session_usage_claude.bend as Claude
import ../src/session_usage_codex.bend as Codex
import ../src/scoped_reader.bend as Scoped

# Synthetic native Usage fixture. Only fixture creates/imports the database.
# Subsequent mutations require the exact immutable root-bound marker and exact
# private single-link source bytes; they never open the DB. The real GUI owns
# Refresh. Hide is a no-clobber move into this same private root, not deletion.
def checked(ok: Bool,message: String) -> IO(Unit):
  Store.checked(ok,"Native Usage fixture: " ++ message)

def root_shape(+root: String) -> Bool:
  +name = Safe.leaf_parts(List.reverse(&2,String,String.split(root,'/')))
  String.eq(root,"/private/tmp/" ++ name) && String.starts_with(name,"juice-bend-usage-fixture-") &&
    Nat.is_gt(String.length(name),25n) && Nat.is_le(String.length(name),100n) && Safe.name_chars(name)

def repository() -> String:
  "/synthetic/usage"

def timestamp() -> String:
  "2026-10-20T12:00:00Z"

def provider(index: U32) -> String:
  Bool.pick(String,U32.is_eq(index,1),"claude","codex")

def session(index: U32) -> String:
  provider(index) ++ "-usage-session"

def source(+root: String,+index: U32) -> String:
  root ++ "/captures/" ++ provider(index) ++ "/" ++ session(index) ++ ".jsonl"

def database(root: String) -> String:
  root ++ "/library/juice-bend.sqlite"

def marker(root: String) -> String:
  root ++ "/.juice-bend-usage-fixture-v1"

def claude(role: String,repo: String,time: String,body: String,id: String,usage: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"sessionId\":\"claude-usage-session\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"timestamp\":" ++ Json.quote(time) ++ ",\"message\":{\"id\":" ++ Json.quote(id) ++
    ",\"model\":\"synthetic-model\",\"content\":[{\"type\":\"text\",\"text\":" ++ Json.quote(body) ++ "}]" ++ usage ++ "}}\n"

def claude_count(id: String,a: String,b: String,c: String,d: String,body: String) -> String:
  claude("assistant",repository(),timestamp(),body,id,",\"usage\":{\"input_tokens\":" ++ a ++
    ",\"cache_read_input_tokens\":" ++ b ++ ",\"cache_creation_input_tokens\":" ++ c ++
    ",\"output_tokens\":" ++ d ++ "}")

def codex_message(role: String,repo: String,time: String,body: String) -> String:
  "{\"type\":\"response_item\",\"cwd\":" ++ Json.quote(repo) ++ ",\"timestamp\":" ++ Json.quote(time) ++
    ",\"payload\":{\"type\":\"message\",\"role\":" ++ Json.quote(role) ++
    ",\"content\":[{\"type\":\"output_text\",\"text\":" ++ Json.quote(body) ++ "}]}}\n"

def codex_meta() -> String:
  "{\"type\":\"session_meta\",\"timestamp\":" ++ Json.quote(timestamp()) ++
    ",\"payload\":{\"id\":\"codex-usage-session\",\"cwd\":" ++ Json.quote(repository()) ++ ",\"source\":\"cli\"}}\n"

def codex_count(a: String,b: String,c: String) -> String:
  "{\"type\":\"event_msg\",\"cwd\":" ++ Json.quote(repository()) ++ ",\"timestamp\":" ++ Json.quote(timestamp()) ++
    ",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":" ++ a ++
    ",\"cached_input_tokens\":" ++ b ++ ",\"output_tokens\":" ++ c ++ "}}}}\n"

def message(index: U32,role: String,repo: String,time: String,body: String) -> String:
  match index:
    case 1: claude(role,repo,time,body,"","")
    case _: codex_message(role,repo,time,body)

def neutral(+index: U32,+ordinal: U32) -> String:
  message(index,"assistant",repository(),timestamp(),provider(index) ++ " neutral physical record " ++ U32.show(ordinal))

def claude_record(ordinal: U32) -> String:
  match ordinal:
    case 38: claude_count("mirrored-call","10","2","3","4","First usage before UI page boundary.")
    case 41: claude_count("mirrored-call","20","3","4","5","Mirror increases the same call maxima after record40.")
    case 127: claude_count("second-call","7","1","2","3","Distinct call immediately before scan window boundary.")
    case 128: claude_count("mirrored-call","30","4","5","6","Third mirror after128 records; do not sum mirrors.")
    case 129: claude_count("third-call","11","2","3","4","Distinct call after128 records.")
    case n: neutral(1,n)

def codex_record(ordinal: U32) -> String:
  match ordinal:
    case 0: codex_meta()
    case 38: codex_count("100","20","10")
    case 41: codex_count("150","30","20")
    case 127: codex_count("180","40","25")
    case 128: codex_count("200","50","30")
    case 129: codex_count("200","50","30")
    case n: neutral(2,n)

def record(+index: U32,ordinal: U32,+rewrite: Bool) -> String:
  match ordinal:
    case 40: message(index,"assistant",repository(),timestamp(),
      Bool.pick(String,rewrite,"rewrittenneedle","originneedle") ++ " café 中文 🙂 — original reader begins at physical record40.")
    case 42: message(index,"assistant",repository(),"2026-10-19T23:59:59Z","excluded-old-date usage fixture")
    case 43: message(index,"assistant",repository() ++ "/nested",timestamp(),"excluded-repository-prefix usage fixture")
    case 44: message(index,"user",repository(),timestamp(),"excluded-user-role usage fixture")
    case 45: message(index,"assistant",repository(),timestamp(),"eligible-scope café 中文 🙂 at physical record45.")
    case +n: Bool.pick(String,U32.is_eq(index,1),claude_record(n),
      Bool.pick(String,rewrite && U32.is_eq(n,38),codex_count("70","10","9"),
        Bool.pick(String,rewrite && U32.is_ge(n,41),neutral(index,n),codex_record(n))))

def records(fuel: Nat,+index: U32,+ordinal: U32,+rewrite: Bool) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: record(index,ordinal,rewrite) ++ records(rest,index,U32.inc(ordinal),rewrite)

def initial(index: U32) -> String:
  records(132n,index,0,False{})

def appended(index: U32) -> String:
  match index:
    case 1: claude_count("append-call","13","3","2","5","future-usage added after snapshot1.") ++
      message(1,"assistant",repository(),timestamp(),"future-transcript Claude append record133.")
    case _: codex_count("250","60","40") ++
      message(2,"assistant",repository(),timestamp(),"future-transcript Codex append record133.")

def source_text(+index: U32,phase: U32) -> String:
  match phase:
    case 0: initial(index)
    case 1: initial(index) ++ appended(index)
    case _: Bool.pick(String,U32.is_eq(index,1),initial(index) ++ appended(index),records(132n,2,0,True{}))

def extent(text: String) -> U32:
  U32.from_nat(List.length(&2,U32,Domain.encode(text)))

def reference(+root: String,+index: U32) -> Usage.Capture:
  Usage.Capture{provider(index),U32.show(index),source(root,index),U32.show(index),U32.show(index),extent(initial(index)),132}

def description(+root: String) -> String:
  "{\"fixture\":\"juice-bend-usage-fixture-v1\",\"root\":" ++ Json.quote(root) ++
    ",\"data_dir\":" ++ Json.quote(root ++ "/library") ++ ",\"repository\":" ++ Json.quote(repository()) ++
    ",\"origin_query\":\"originneedle provider:claude\",\"origin_start\":40," ++
    "\"scope_query\":\"originneedle provider:claude repo:/synthetic/usage role:assistant after:2026-10-20\"," ++
    "\"phase_order\":[\"fixture\",\"append-only\",\"rewrite-only\",\"hide\"]," ++
    "\"source_records\":{\"initial\":[132,132],\"appended\":[134,134],\"rewritten\":[134,132]}," ++
    "\"session_usage_arguments\":[[\"--data-dir\"," ++ Json.quote(root ++ "/library") ++ ",\"session-usage\",\"1\"]," ++
    "[\"--data-dir\"," ++ Json.quote(root ++ "/library") ++ ",\"session-usage\",\"2\"]]," ++
    "\"captures\":[" ++ Usage.capture_text(reference(root,1)) ++ "," ++ Usage.capture_text(reference(root,2)) ++ "]," ++
    "\"expected\":{\"claude_fields\":[\"input\",\"cached\",\"created\",\"output\"]," ++
    "\"claude_after40\":[10,2,3,4],\"claude_after128\":[27,4,6,8],\"claude_full\":[48,7,10,13]," ++
    "\"claude_appended\":[61,10,12,18],\"codex_fields\":[\"uncached_input\",\"cached\",\"output\"]," ++
    "\"codex_after40\":[80,20,10],\"codex_after128\":[140,40,25],\"codex_full\":[150,50,30]," ++
    "\"codex_appended\":[190,60,40],\"codex_rewritten\":[60,10,9]}}"

def owned(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"root must be a direct /private/tmp/juice-bend-usage-fixture-SUFFIX path")
    Safe.regular_path(root,True{})
    Safe.exact_file(marker(root),description(root) ++ "\n")
    Safe.regular_path(root ++ "/library",True{})
    Safe.regular_path(root ++ "/captures",True{})
    Safe.regular_path(root ++ "/captures/claude",True{})
    Safe.regular_path(root ++ "/captures/codex",True{})
    Safe.regular_path(database(root),False{})
    Safe.optional_file(database(root) ++ "-wal")
    Safe.optional_file(database(root) ++ "-shm")
    Safe.optional_file(database(root) ++ "-journal")

def files(+root: String,+phase: U32,+hidden: Bool) -> IO(Unit):
  +suffix = Bool.pick(String,hidden,".retained","")
  +other = Bool.pick(String,hidden,"",".retained")
  do IO<Unit>:
    Safe.exact_file(source(root,1) ++ suffix,source_text(1,phase))
    Safe.exact_file(source(root,2) ++ suffix,source_text(2,phase))
    Safe.absent(source(root,1) ++ other)
    Safe.absent(source(root,2) ++ other)

def require(-A: Kind(&2),result: Result<&2,&2,Usage.Failure,A>) -> IO(A):
  match result:
    case Done{value}: IO.pure(A,value)
    case Fail{Usage.Failure{code,message}}: IO.die(A,1,"Native Usage fixture: " ++ code ++ " " ++ message)

def shape(value: Counts.Counters) -> String:
  Counts.Counters{a,b,c,_,d} = value
  String.join([a,b,c,d],"|")

def expected(index: U32,phase: U32) -> String:
  match index phase:
    case 1 0: "48|7|10|13"
    case 1 _: "61|10|12|18"
    case _ 0: "150|50||30"
    case _ 1: "190|60||40"
    case _ _: "60|10||9"

def summary(value: Usage.Summary,+wanted: String) -> Bool:
  match value:
    case Usage.ClaudeSummary{Claude.Report{session,keys,_,+observed,own,_,_,records,missing,incomplete,conflicts,mirrors,buckets,attribution}}:
      String.eq(session,"claude-usage-session") && String.eq(shape(observed),wanted) && String.eq(shape(own),wanted) &&
        U32.is_eq(U32.sub(records,keys),2) && U32.is_eq(mirrors,2) && U32.is_eq(missing,0) &&
        U32.is_eq(incomplete,0) && U32.is_eq(conflicts,0) && buckets && attribution
    case Usage.CodexSummary{Codex.Report{category,session,_,basis,counts,observed,accepted,duplicates,resets,excluded,uncertain,_,_,complete}}:
      String.eq(category,"ordinary") && String.eq(session,"codex-usage-session") && String.eq(basis,"none") &&
        String.eq(shape(counts),wanted) && U32.is_eq(U32.add(accepted,duplicates),observed) &&
        U32.is_eq(resets,0) && U32.is_eq(excluded,0) && U32.is_eq(uncertain,0) && complete

def verified_report(+report: Usage.Report,+root: String,+snapshot: String,+index: U32,
  generation: String,+phase: U32,+text: String,+count: U32) -> IO(Usage.Capture):
  Usage.Report{+capture,_,processed,verified_bytes,scan,buckets,attribution,_,Usage.Coverage{decoded,malformed,oversized,issues,_},facts} = report
  do IO<Usage.Capture>:
    checked(String.eq(Usage.capture_text(capture),Usage.capture_text(Usage.Capture{provider(index),U32.show(index),
      source(root,index),generation,snapshot,extent(text),count})),"capture identity or extent differs")
    checked(U32.is_eq(processed,count) && U32.is_eq(decoded,count) && U32.is_eq(verified_bytes,extent(text)) &&
      scan && buckets && attribution && U32.is_eq(malformed,0) && U32.is_eq(oversized,0) && U32.is_eq(issues,0) &&
      summary(facts,expected(index,phase)),"whole-capture usage totals or completeness differ")
    rendered : String <- require(String,Wire.rendered(report))
    return capture

def verified(+db: U32,+root: String,+snapshot: String,+index: U32,+generation: String,+phase: U32) -> IO(Usage.Capture):
  +text = source_text(index,phase)
  +count = Bool.pick(U32,U32.is_eq(phase,0) || (U32.is_eq(index,2) && U32.is_eq(phase,2)),132,134)
  do IO<Usage.Capture>:
    Maintenance.verify(db,snapshot)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.bytes FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal LIMIT 256",
      [Sql.Cell.Integer{snapshot}],256)
    bytes : List<&2,U32> <- Safe.need(List<&2,U32>,Safe.captured_bytes(rows))
    checked(Domain.bytes_equal(bytes,Domain.encode(text)),"retained raw bytes differ from the exact fixture")
    got : Result<&2,&2,Usage.Failure,Usage.Report> <- Wire.run(db,snapshot,Usage.defaults())
    report : Usage.Report <- require(Usage.Report,got)
    verified_report(report,root,snapshot,index,generation,phase,text,count)

def readers(+db: U32,+snapshot: String,+index: U32) -> IO(Unit):
  do IO<Unit>:
    +ordinary : String <- Scoped.page(db,snapshot,40,40,Scoped.Scope{provider(index),"","",""},False{})
    checked(String.contains(ordinary,"originneedle café 中文 🙂") && String.contains(ordinary,"eligible-scope") &&
      String.contains(ordinary,"excluded-user-role") && Bool.not(String.contains(ordinary,"future-transcript")),
      "original physical40 page lost neutral content or acquired a future append")
    +filtered : String <- Scoped.page(db,snapshot,40,40,Scoped.Scope{provider(index),repository(),"assistant","2026-10-20"},False{})
    checked(String.contains(filtered,"originneedle café 中文 🙂") && String.contains(filtered,"eligible-scope") &&
      Bool.not(String.contains(filtered,"excluded-")),"role/date/exact repository scope differs")

def fixture(+root: String) -> IO(Unit):
  do IO<Unit>:
    checked(root_shape(root),"new root must be direct /private/tmp/juice-bend-usage-fixture-SUFFIX")
    canonical : String <- Paths.destination(root)
    checked(String.eq(root,canonical),"new root parent must be canonical")
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(root ++ "/library")
    Safe.directory(root ++ "/captures")
    Safe.directory(root ++ "/captures/claude")
    Safe.directory(root ++ "/captures/codex")
    Store.write_text(source(root,1),"w",initial(1))
    Safe.private_file(source(root,1),"600")
    Store.write_text(source(root,2),"w",initial(2))
    Safe.private_file(source(root,2),"600")
    files(root,0,False{})
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    Safe.private_file(database(root),"600")
    Store.schema(db)
    first : String <- Store.import_file(db,"claude",source(root,1))
    checked(String.eq(first,"1"),"first snapshot must be1")
    second : String <- Store.import_file(db,"codex",source(root,2))
    checked(String.eq(second,"2"),"second snapshot must be2")
    first_capture : Usage.Capture <- verified(db,root,"1",1,"1",0)
    second_capture : Usage.Capture <- verified(db,root,"2",2,"2",0)
    readers(db,"1",1)
    readers(db,"2",2)
    IO.try(Unit,Sql.close(db))
    Store.write_text(marker(root),"w",description(root) ++ "\n")
    Safe.private_file(marker(root),"400")
    owned(root)
    IO.print(description(root))

def append_only(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    files(root,0,False{})
    Store.write_text(source(root,1),"a",appended(1))
    Store.write_text(source(root,2),"a",appended(2))
    files(root,1,False{})
    IO.print("{\"source_changed\":\"both_appended\",\"capture_requested\":false,\"records_each\":134,\"root\":" ++ Json.quote(root) ++ "}")

def rewrite_only(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    files(root,1,False{})
    Store.write_text(source(root,2),"w",source_text(2,2))
    files(root,2,False{})
    IO.print("{\"source_changed\":\"codex_rewritten\",\"capture_requested\":false,\"codex_records\":132,\"root\":" ++ Json.quote(root) ++ "}")

def hide(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    files(root,2,False{})
    first : String <- Safe.command("/bin/mv",["-n",source(root,1),source(root,1) ++ ".retained"])
    second : String <- Safe.command("/bin/mv",["-n",source(root,2),source(root,2) ++ ".retained"])
    files(root,2,True{})
    IO.print("{\"hidden_sources\":2,\"capture_requested\":false,\"root\":" ++ Json.quote(root) ++ "}")

def capture_row(+db: U32,+root: String,row: List<&2,Sql.Cell>) -> IO(String):
  match row:
    case [Sql.Cell.Integer{+snapshot},Sql.Cell.Integer{+generation},Sql.Cell.Integer{+source_id}]:
      +index = Store.number(source_id)
      +original = String.eq(snapshot,source_id)
      +rewrite = String.eq(generation,"3")
      do IO<String>:
        checked((String.eq(source_id,"1") && String.eq(generation,"1")) ||
          (String.eq(source_id,"2") && (String.eq(generation,"2") || rewrite)),"unexpected source or generation")
        capture : Usage.Capture <- verified(db,root,snapshot,index,generation,
          Bool.pick(U32,original,0,Bool.pick(U32,rewrite,2,1)))
        return Usage.capture_text(capture)
    case _: IO.die(String,1,"Native Usage fixture: invalid capture metadata types")

def capture_rows(rows: List<&2,List<&2,Sql.Cell>>,+db: U32,+root: String) -> IO(List<&2,String>):
  match rows:
    case []: IO.pure(List<&2,String>,[])
    case row <> rest:
      do IO<List<&2,String>>:
        value : String <- capture_row(db,root,row)
        following : List<&2,String> <- capture_rows(rest,db,root)
        return value <> following

# Verification sets SQLite query_only before all reads. It never imports,
# rebuilds, changes schema/settings, or touches the original provider paths.
def verify(+root: String) -> IO(Unit):
  do IO<Unit>:
    owned(root)
    +db : U32 <- IO.try(U32,Sql.open(database(root)))
    query_only : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"PRAGMA query_only=ON",[],0)
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Safe.scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    Safe.scalar(db,"SELECT count(*) FROM sources",[],"2")
    Safe.scalar(db,"SELECT count(*) FROM snapshots WHERE accepted!=1",[],"0")
    original_claude : Usage.Capture <- verified(db,root,"1",1,"1",0)
    original_codex : Usage.Capture <- verified(db,root,"2",2,"2",0)
    readers(db,"1",1)
    readers(db,"2",2)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.generation,g.source FROM snapshots p JOIN generations g ON g.id=p.generation ORDER BY p.id LIMIT 6",[],6)
    +captures : List<&2,String> <- capture_rows(rows,db,root)
    checked(Nat.is_ge(List.length(&2,String,captures),2n) && Nat.is_le(List.length(&2,String,captures),5n),
      "unexpected accepted capture count")
    IO.try(Unit,Sql.close(db))
    IO.print("{\"fixture_verified\":true,\"original_totals_verified\":true,\"original_reader_scopes_verified\":true,\"root\":" ++
      Json.quote(root) ++ ",\"captures\":[" ++ String.join(captures,",") ++ "]}")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "fixture" <> root <> []: fixture(root)
    case _ <> "append-only" <> root <> []: append_only(root)
    case _ <> "rewrite-only" <> root <> []: rewrite_only(root)
    case _ <> "hide" <> root <> []: hide(root)
    case _ <> "verify" <> root <> []: verify(root)
    case _: IO.die(Unit,2,"Usage: native-usage fixture NEW_ROOT | append-only ROOT | rewrite-only ROOT | hide ROOT | verify ROOT")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
