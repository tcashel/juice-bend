import Base
import ../src/attachment_inventory.bend as I
import ../src/attachment_inventory_output.bend as O
import ../src/attachment_extract.bend as E
import ../src/attachment_refs.bend as R
import ../src/archive_meta.bend as Meta
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/json.bend as J

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def need(-A: Kind(&2),result: Result<&2,&2,I.Failure,A>) -> IO(A):
  match result:
    case Done{value}: IO.pure(A,value)
    case Fail{I.Failure{code,message}}: IO.die(A,1,"FAIL " ++ code ++ ": " ++ message)

def failed(-A: Kind(&2),result: Result<&2,&2,I.Failure,A>,expected: String) -> Bool:
  match result:
    case Fail{I.Failure{code,_}}: String.eq(code,expected)
    case Done{_}: False{}

def valid_json(result: Result<&2,&2,String,J.Json>) -> Bool:
  match result:
    case Done{J.JObject{fields}}: String.eq(J.get(J.JObject{fields},"kind"),"attachment_inventory")
    case _: False{}

def buffer_left(result: Result<&2,&2,I.Failure,O.Buffer>) -> U32:
  match result:
    case Done{O.Buffer{left,_}}: left
    case Fail{_}: 4294967295

def read(db: U32,snapshot: String,start: U32,count: U32) -> IO(I.Page):
  do IO<I.Page>:
    page : Result<&2,&2,I.Failure,I.Page> <- I.read(db,snapshot,start,count)
    need(I.Page,page)

def encode(page: I.Page) -> IO(String):
  need(String,O.encode(page))

def repeat(n: Nat,+text: String) -> String:
  match n:
    case 0n: ""
    case 1n+left: text ++ repeat(left,text)

def refs(n: Nat,+text: String) -> List<&2,String>:
  match n:
    case 0n: []
    case 1n+left: text <> refs(left,text)

def image(path: String) -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":" ++ J.quote(path) ++ "}}"

def inline() -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"AAH+/w==\"}}"

def record(content: String) -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[" ++ content ++ "]}}\n"

def empty() -> String:
  record("{\"type\":\"text\",\"text\":\"ordinary prose /synthetic/not-an-attachment.png\"}")

def rows(page: I.Page) -> List<&2,I.Record>:
  I.Page{_,_,_,_,rows} = page
  rows

def totals_pair(start: U32,requested: U32,selected: U32,size: Nat,pair: U32 & U32) -> String:
  (complete,refs) = pair
  String.join([U32.show(start),U32.show(requested),U32.show(selected),
    Nat.show(size),U32.show(complete),U32.show(refs)],"|")

def totals(page: I.Page) -> String:
  I.Page{_,start,requested,selected,+rows} = page
  totals_pair(start,requested,selected,List.length(&2,I.Record,rows),I.record_counts(rows,0,0))

def first(rows: List<&2,I.Record>) -> I.Record:
  match rows:
    case row <> _: row
    case []: I.Record{4294967295,0,0,"",I.InvalidUtf8{}}

def first_report(record: I.Record) -> E.Report:
  match record:
    case I.Record{_,_,_,_,I.Extracted{report}}: report
    case _: E.partial("test_no_extracted_report")

def occurrence(report: E.Report) -> String:
  match report:
    case E.Report{E.Occurrence{ordinal,path,kind,ref} <> _,_}:
      U32.show(ordinal) ++ "|" ++ path ++ "|" ++ kind ++ "|" ++ R.summary(ref)
    case _: ""

def identity(page: I.Page) -> String:
  I.Page{Meta.Header{snapshot,source,generation,provider,_,_,total,_,_,_,encoding},_,_,_,_} = page
  String.join([provider,source,generation,snapshot,U32.show(total),encoding],"|")

def body_status(body: I.Body) -> String:
  match body:
    case I.InvalidUtf8{}: "invalid_utf8"
    case I.OversizedFragment{}: "oversized_fragment"
    case I.Extracted{+report}: Bool.pick(String,E.complete(report),"complete","partial")

def statuses(rows: List<&2,I.Record>) -> String:
  match rows:
    case []: ""
    case I.Record{ordinal,_,_,_,body} <> rest:
      U32.show(ordinal) ++ ":" ++ body_status(body) ++ ";" ++ statuses(rest)

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(written)

def process_ok(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  assert(U32.is_eq(code,0),"synthetic fixture command completed")

def remove(path: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--",path],"",1024,2000))
    process_ok(result)

def basic(+db: U32) -> IO(Unit):
  +fixture = record(inline()) ++ repeat(39n,empty()) ++ record(image("/synthetic/late.png"))
  do IO<Unit>:
    Store.write_text("paged.jsonl","w",fixture)
    +snapshot : String <- Store.import_file(db,"claude","paged.jsonl")
    +first_page : I.Page <- read(db,snapshot,0,40)
    +before : String <- encode(first_page)
    assert(String.eq(identity(first_page),"claude|1|1|1|41|identity"),"first synthetic capture preserves exact provider source generation snapshot encoding identities")
    assert(String.eq(totals(first_page),"0|40|40|40|40|1"),"first40 raw records preserve image-only recordzero and39 empty coverage entries")
    assert(String.eq(occurrence(first_report(first(rows(first_page)))),
      "0|/message/content/0/source/data|image|Inline bytes retained in raw record; valid base64, 4 decoded bytes"),
      "recordzero occurrence retains exact structural path and independent four-byte inline length")
    assert(String.contains(before,"\"next\":40") && String.contains(before,"\"covers_snapshot_record_range\":false") &&
      Bool.not(String.contains(before,"AAH+/w==")),"first page exposes remaining raw cursor and never inline payload")
    assert(valid_json(J.parse(before)),"bounded inventory output is a complete parseable JSON object")
    +late : I.Page <- read(db,snapshot,40,40)
    +late_json : String <- encode(late)
    assert(String.eq(totals(late),"40|40|1|1|1|1") && String.contains(late_json,"\"record\":40") &&
      String.contains(late_json,"\"next\":null") && String.contains(late_json,"late.png"),"late page uses immutable raw ordinal and preserves its filename")
    +past : I.Page <- read(db,snapshot,4294967295,40)
    +past_json : String <- encode(past)
    assert(String.eq(totals(past),"4294967295|40|0|0|0|0") && String.contains(past_json,"\"next\":null"),"beyondEOF raw range stays empty without cursor overflow")
    Store.exec(db,"UPDATE events SET body='forged projection',arguments='forged arguments' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"UPDATE snapshot_context SET session='forged context' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    +projection : I.Page <- read(db,snapshot,0,40)
    +projection_json : String <- encode(projection)
    assert(String.eq(before,projection_json),"attachment authority ignores corrupt mutable event and context projections")
    Store.write_text("paged.jsonl","w",empty())
    rewritten : String <- Store.import_file(db,"claude","paged.jsonl")
    remove("paged.jsonl")
    +retained : I.Page <- read(db,snapshot,0,40)
    retained_json : String <- encode(retained)
    assert(String.eq(before,retained_json) && Bool.not(String.eq(snapshot,rewritten)),"pinned inventory survives source rewrite newer generation and source deletion")

def limits(+db: U32) -> IO(Unit):
  +forty = record(String.join(refs(40n,image("/synthetic/forty.png")),","))
  +sixtyfive = record(String.join(refs(65n,image("/synthetic/sixtyfive.png")),","))
  +long_name = "/" ++ repeat(4000n,"x")
  +large = record(String.join(refs(40n,image(long_name)),","))
  do IO<Unit>:
    Store.write_text("counts.jsonl","w",forty ++ forty ++ sixtyfive)
    +snapshot : String <- Store.import_file(db,"claude","counts.jsonl")
    +page : I.Page <- read(db,snapshot,0,2)
    encoded : String <- encode(page)
    assert(String.eq(totals(page),"0|2|2|2|2|80") && String.contains(encoded,"\"returned_occurrences\":80"),"two40-reference records return all80 occurrences with no invented global64 cap")
    +limited : I.Page <- read(db,snapshot,2,1)
    +limited_json : String <- encode(limited)
    assert(String.eq(totals(limited),"2|1|1|1|0|64") && String.contains(limited_json,"\"truncated\":true") &&
      String.contains(limited_json,"total unknown"),"record65 reference limit returns64 and explicit per-record unknown total")
    Store.write_text("budget.jsonl","w",large ++ large)
    +budget_snapshot : String <- Store.import_file(db,"claude","budget.jsonl")
    +budget : I.Page <- read(db,budget_snapshot,0,2)
    assert(String.eq(totals(budget),"0|2|2|2|2|80") && failed(String,O.encode(budget),"attachment_output_limit"),"valid80 long filenames exceed final256KiB output bound with typed failure and no omitted rows")
    bad_count : Result<&2,&2,I.Failure,I.Page> <- I.read(db,snapshot,0,41)
    bad_zero : Result<&2,&2,I.Failure,I.Page> <- I.read(db,snapshot,0,0)
    bad_id : Result<&2,&2,I.Failure,I.Page> <- I.read(db,"01",0,1)
    assert(failed(I.Page,bad_count,"attachment_invalid_request") && failed(I.Page,bad_zero,"attachment_invalid_request") &&
      failed(I.Page,bad_id,"attachment_invalid_request"),"request admission rejects41 zero and noncanonical snapshot without a read transaction")
    assert(U32.is_eq(buffer_left(O.put("é",O.Buffer{2,[]})),0) &&
      failed(O.Buffer,O.put("é",O.Buffer{1,[]}),"attachment_output_limit"),"incremental output budget counts two-byte Unicode exactly and refuses incomplete chunks")

def coverage(+db: U32) -> IO(Unit):
  +bytes = List.append(&2,U32,[255,10],Domain.encode(repeat(262145n,"x") ++ "\n" ++ record(image("/synthetic/after.png")) ++ "{bad}\n"))
  do IO<Unit>:
    write_bytes("coverage.jsonl",bytes)
    +snapshot : String <- Store.import_file(db,"claude","coverage.jsonl")
    +page : I.Page <- read(db,snapshot,0,40)
    +text : String <- encode(page)
    assert(String.eq(statuses(rows(page)),"0:invalid_utf8;1:oversized_fragment;2:oversized_fragment;3:complete;4:partial;"),
      "invalidUTF8 oversized fragments and malformedJSON have typed distinct coverage without losing later image")
    assert(String.eq(totals(page),"0|40|5|5|1|1") && String.contains(text,"after.png") &&
      String.contains(text,"\"partial_extraction_records\":4"),"selected raw verification remains distinct from incomplete extraction")
    +tail : I.Page <- read(db,snapshot,2,1)
    assert(String.eq(statuses(rows(tail)),"2:oversized_fragment;"),"late oversized continuation derives classification from verified predecessor")

def display(+db: U32) -> IO(Unit):
  +path = "/synthetic/name\n" ++ SCon{Chr{8238},"café 中文 🙂.png"}
  +remote = {"{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/private?q=never-display\"}}" : String}
  +fixture = record(image(path) ++ "," ++ remote ++ "," ++ inline())
  do IO<Unit>:
    Store.write_text("names.jsonl","w",fixture)
    +snapshot : String <- Store.import_file(db,"claude","names.jsonl")
    page : I.Page <- read(db,snapshot,0,1)
    +text : String <- encode(page)
    assert(String.contains(text,"name\\\\u000a\\\\u202e") && String.contains(text,"café 中文 🙂.png") &&
      Bool.not(String.contains(text,SCon{Chr{8238},""})),"display filename controls are visibly escaped while ordinary Unicode stays intact")
    assert(Bool.not(String.contains(text,"/synthetic/")) && Bool.not(String.contains(text,"never-display")) &&
      Bool.not(String.contains(text,"AAH+/w==")) && String.contains(text,"external_bytes_uncaptured"),"default inventory omits original attachment paths remote queries and inline data without claiming missing or saved")
    assert(String.eq(O.quote(SCon{Chr{8238},""}),"\"\\u202e\""),"identity JSON encodes bidi control exactly rather than altering its decoded value")
    assert(String.eq(O.name(R.LocalFileURL{"file:///synthetic/picture.png?private=hidden#secret"}),"Local file URL"),
      "fileURL display label does not mistake query or fragment for a safe filename")

def provider_empty(+db: U32) -> IO(Unit):
  +fixture = "{\"type\":\"event_msg\",\"payload\":{\"type\":\"user_message\",\"message\":\"\",\"local_images\":[\"/synthetic/mirror.png\"]}}\n" ++
    "{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":\"/synthetic/mirror.png\"}]}}\n"
  do IO<Unit>:
    Store.write_text("codex.jsonl","w",fixture)
    +snapshot : String <- Store.import_file(db,"codex","codex.jsonl")
    +page : I.Page <- read(db,snapshot,0,2)
    +text : String <- encode(page)
    assert(String.eq(totals(page),"0|2|2|2|2|2") && String.contains(text,"\"provider\":\"codex\"") &&
      String.contains(text,"/payload/local_images/0") && String.contains(text,"/payload/content/0/image_url"),
      "Codex event and response mirrors remain distinct retained record occurrences with exact provider paths")
    Store.write_text("empty.jsonl","w","")
    +empty_snapshot : String <- Store.import_file(db,"claude","empty.jsonl")
    +empty_page : I.Page <- read(db,empty_snapshot,0,40)
    +empty_json : String <- encode(empty_page)
    assert(String.eq(totals(empty_page),"0|40|0|0|0|0") && String.contains(empty_json,"\"records\":[]") &&
      String.contains(empty_json,"\"covers_snapshot_record_range\":true"),"empty accepted capture retains explicit empty page identity and coverage")

def transaction(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("transaction.jsonl","w",empty())
    +snapshot : String <- Store.import_file(db,"claude","transaction.jsonl")
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"CREATE TABLE caller_marker(value INTEGER)",[])
    denied : Result<&2,&2,I.Failure,I.Page> <- I.read(db,snapshot,0,1)
    assert(failed(I.Page,denied,"attachment_transaction_unavailable"),"preexisting caller transaction is refused")
    Store.exec(db,"INSERT INTO caller_marker VALUES(7)",[])
    Store.exec(db,"ROLLBACK",[])
    check : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM sqlite_master WHERE name='caller_marker'",[],1)
    assert(String.eq(Store.field(Store.first(check),0n),"0"),"inventory refusal leaves caller transaction ownership and rollback intact")
    page : I.Page <- read(db,snapshot,0,1)
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(String.eq(totals(page),"0|1|1|1|1|0"),"successful inventory closes its owned transaction")

def child_result(result: U32 & (String & String),needle: String,label: String) -> IO(Unit):
  (code,(+out,err)) = result
  assert(U32.is_ne(code,0) && String.contains(out ++ err,needle) && Bool.not(String.contains(out,"attachment_inventory")),label)

def child(+self: String,snapshot: String,start: U32,needle: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["read",snapshot,U32.show(start)],"",65536,30000))
    child_result(result,needle,label)

def corruption(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("corrupt.jsonl","w",record(image("/synthetic/a.png")) ++ record(image("/synthetic/b.png")))
    +snapshot : String <- Store.import_file(db,"claude","corrupt.jsonl")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=1)",[Sql.Cell.Integer{snapshot}])
    +unselected : I.Page <- read(db,snapshot,0,1)
    assert(String.eq(totals(unselected),"0|1|1|1|1|1"),"selected page can succeed with unselected corruption without claiming whole snapshot verification")
    child(self,snapshot,1,"integrity","selected corrupted raw bytes hard-fail before any inventory output")
    Store.write_text("predecessor.jsonl","w",empty() ++ record(image("/synthetic/later.png")))
    +pre : String <- Store.import_file(db,"claude","predecessor.jsonl")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{pre}])
    child(self,pre,1,"predecessor integrity","corrupt predecessor cannot lend a trustworthy later record boundary")
    Store.write_text("index.jsonl","w",empty() ++ empty())
    +index : String <- Store.import_file(db,"claude","index.jsonl")
    Store.exec(db,"UPDATE records SET raw=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0) WHERE snapshot=? AND ordinal=1",
      [Sql.Cell.Integer{index},Sql.Cell.Integer{index}])
    child(self,index,1,"integrity","rebound record map cannot substitute another raw ordinal")
    Store.exec(db,"DELETE FROM records WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{index}])
    child(self,index,0,"record count","missing raw map row fails immutable header count even for other selected row")
    Store.write_text("giant.jsonl","w",empty())
    +giant : String <- Store.import_file(db,"claude","giant.jsonl")
    Store.exec(db,"UPDATE raw SET n=1048576,bytes=zeroblob(1048576) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{giant}])
    child(self,giant,0,"payload type or size admission","oneMiB corrupt BLOB is refused by metadata-only admission before bridge payload transfer")
    Store.write_text("unaccepted.jsonl","w",empty())
    +unaccepted : String <- Store.import_file(db,"claude","unaccepted.jsonl")
    Store.exec(db,"UPDATE snapshots SET accepted=0 WHERE id=?",[Sql.Cell.Integer{unaccepted}])
    child(self,unaccepted,0,"not accepted","unaccepted snapshot cannot provide inventory")

def concurrent(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("consistent.jsonl","w",record(image("/synthetic/stable.png")))
    +snapshot : String <- Store.import_file(db,"claude","consistent.jsonl")
    owned : Result<&2,&2,I.Failure,Unit> <- I.transaction(db)
    need(Unit,owned)
    h : Meta.Header <- Meta.header(db,snapshot,True{})
    +other : U32 <- Store.open(".build/attachment-inventory.sqlite")
    Store.exec(other,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    IO.try(Unit,Sql.close(other))
    page : I.Page <- I.read_header(db,snapshot,0,1)
    text : String <- encode(page)
    Store.exec(db,"ROLLBACK",[])
    assert(String.contains(text,"stable.png"),"inventory metadata and selected raw share established transaction view under concurrent writer")
    child(self,snapshot,0,"integrity","fresh inventory transaction observes concurrent corruption after prior read closes")

def raw_frame(+bytes: List<&2,U32>) -> List<&2,U32>:
  +descriptor = U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),8),1)
  List.append(&2,U32,[40,181,47,253,0,56,U32.and(descriptor,255),
    U32.and(U32.shrn(descriptor,8n),255),U32.and(U32.shrn(descriptor,16n),255)],bytes)

def archive(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    write_bytes("owned.jsonl.zst",raw_frame(Domain.encode(record(image("/synthetic/archive.png")))))
    +snapshot : String <- Capture.import_file(db,"claude","owned.jsonl.zst")
    +page : I.Page <- read(db,snapshot,0,1)
    +before : String <- encode(page)
    assert(String.contains(before,"zstd-jsonl-v1") && String.contains(before,"archive.png") &&
      String.contains(before,"\"byte_space\":\"logical_source_bytes\"") &&
      String.eq(totals(page),"0|1|1|1|1|1"),"compressed snapshot inventory uses verified owned logical raw record and archive metadata")
    remove("owned.jsonl.zst")
    +after_page : I.Page <- read(db,snapshot,0,1)
    after : String <- encode(after_page)
    assert(String.eq(before,after),"archive attachment inventory survives original compressed source deletion")
    Store.exec(db,"UPDATE archive_captures SET commitment='corrupt' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    child(self,snapshot,4294967295,"commitment","malformed archive envelope fails even for an empty beyondEOF range")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/attachment-inventory.sqlite")
    basic(db)
    limits(db)
    coverage(db)
    display(db)
    provider_empty(db)
    transaction(db)
    corruption(db,self)
    concurrent(db,self)
    archive(db,self)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "read" <> snapshot <> start <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/attachment-inventory.sqlite")
        page : I.Page <- read(db,snapshot,Store.number(start),1)
        text : String <- encode(page)
        IO.print(text)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Invalid synthetic attachment inventory arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
