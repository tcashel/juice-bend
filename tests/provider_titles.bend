import Base
import ./history_titles.bend as Check
import ../src/history_titles.bend as Titles
import ../src/provider_title.bend as Recorded
import ../src/providers.bend as Providers
import ../src/request_evidence.bend as Request
import ../src/request_origin.bend as Origin
import ../src/store.bend as Store
import ../src/maintenance.bend as Maintenance
import ../src/projection_seal.bend as Seal
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/scoped_reader.bend as Scoped

# Exact documented shape observed in the read-only reference at 829ff9b5.
# All values and paths here are invented synthetic fixtures.
def title(text: String) -> String:
  "{\"type\":\"ai-title\",\"aiTitle\":" ++ Json.quote(text) ++ "}\n"

def request() -> String:
  Check.user("/synthetic/title","Safe recorded request")

def parsed(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{raw}: raw
    case Fail{_}: Json.JNull{}

def unavailable(value: Recorded.Title) -> Bool:
  match value:
    case Recorded.Unavailable{}: True{}
    case _: False{}

def metadata_event(values: List<&2,Providers.Record>) -> Bool:
  match values:
    case [event]: String.eq(Providers.role(event),"metadata")
    case _: False{}

def not_request(values: List<&2,Providers.Record>,raw: Json.Json) -> Bool:
  match values:
    case [event]: Bool.not(Origin.eligible(Request.assess("claude",raw,0,event)))
    case _: False{}

def scalar(+db: U32,sql: String,args: List<&2,Sql.Cell>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,args,1)
    Check.assert(String.eq(Store.field(Store.first(rows),0n),expected),label)

def raw_identity(+db: U32,snapshot: String) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT i.ordinal,i.raw,r.generation,r.ordinal,r.offset,r.n,r.digest FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? ORDER BY i.ordinal",
      [Sql.Cell.Integer{snapshot}],1000)
    return Domain.digest(Domain.encode(Store.projection_cells(List.concat(&2,Sql.Cell,rows))))

def basics(+db: U32) -> IO(Unit):
  +latest = {"  Recorded café 中文 🙂 é\n  title  " : String}
  do IO<Unit>:
    +snapshot : String <- Check.capture(db,"recorded.jsonl",request() ++ title("Earlier title") ++ title(latest) ++
      String.repeat("{\"type\":\"future-record\"}\n",80n))
    +digest : String <- Store.projection_digest(db,snapshot)
    +raw : String <- raw_identity(db,snapshot)
    +search : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"Safe","","","","",100,0)
    Check.expect(db,snapshot,Check.scope(),"Recorded café 中文 🙂 é title","latest exact recorded title survives 80 later unsupported records")
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=? AND coverage='recorded_title'",
      [Sql.Cell.Integer{snapshot}],"2","recorded title locator has one event per physical title record")
    scalar(db,"SELECT count(*) FROM events WHERE snapshot=? AND role='metadata' AND body='[Recorded session title metadata]'",
      [Sql.Cell.Integer{snapshot}],"2","title projection carries fixed metadata marker rather than title request text")
    +events : List<&2,Providers.Record> = Providers.parse("claude",title(latest))
    Check.assert(metadata_event(events) && not_request(events,parsed(Json.parse(title(latest)))),
      "title metadata never normalizes to a user event or eligible human request")
    +after : String <- Store.projection_digest(db,snapshot)
    raw_after : String <- raw_identity(db,snapshot)
    search_after : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"Safe","","","","",100,0)
    Check.assert(String.eq(digest,after) && String.eq(raw,raw_after) && Check.rows(search,search_after,False{}),
      "title read preserves projection raw identity and exact request search rows")
    scalar(db,"SELECT count(*) FROM search WHERE search MATCH 'metadata' AND snapshot=?",
      [Sql.Cell.Integer{snapshot}],"2","only fixed metadata marker is searchable; title content stays raw")
    scalar(db,"SELECT count(*) FROM search WHERE search MATCH 'café' AND snapshot=?",
      [Sql.Cell.Integer{snapshot}],"0","recorded title text is not copied into lexical request index")
    Store.write_text("recorded.jsonl","w","source replaced after capture")
    Check.expect(db,snapshot,Check.scope(),"Recorded café 中文 🙂 é title","title reads owned retained bytes after original source replacement")
    long : String <- Check.capture(db,"long-provider-title.jsonl",request() ++ title(String.repeat("🙂",91n)))
    Check.expect(db,long,Check.scope(),String.repeat("🙂",89n) ++ "…","recorded title uses existing 90-scalar display bound")

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(written)

def malformed_case(+db: U32,+name: String,latest: String) -> IO(Unit):
  do IO<Unit>:
    snapshot : String <- Check.capture(db,name ++ ".jsonl",request() ++ title("Older tempting title") ++ latest)
    Check.expect(db,snapshot,Check.scope(),"Safe recorded request",name ++ " uses safe request fallback rather than older title")

def malformed(+db: U32) -> IO(Unit):
  do IO<Unit>:
    malformed_case(db,"blank-title",title(" \n\t "))
    malformed_case(db,"wrong-type-title","{\"type\":\"ai-title\",\"aiTitle\":42}\n")
    malformed_case(db,"missing-title","{\"type\":\"ai-title\"}\n")
    malformed_case(db,"null-title","{\"type\":\"ai-title\",\"aiTitle\":null}\n")
    malformed_case(db,"duplicate-title","{\"type\":\"ai-title\",\"aiTitle\":\"One\",\"aiTitle\":\"Two\"}\n")
    malformed_case(db,"duplicate-type","{\"type\":\"ai-title\",\"type\":\"user\",\"aiTitle\":\"Ambiguous\"}\n")
    malformed_case(db,"broken-json","{\"type\":\"ai-title\",\"aiTitle\":\"Unclosed\n")
    malformed_case(db,"oversized-title",title(String.repeat("x",262200n)))
    malformed_case(db,"wrong-type-timestamp","{\"type\":\"ai-title\",\"aiTitle\":\"Unsafe\",\"timestamp\":42}\n")
    malformed_case(db,"wrong-type-repository","{\"type\":\"ai-title\",\"aiTitle\":\"Unsafe\",\"cwd\":42}\n")
    malformed_case(db,"conflicting-repositories","{\"type\":\"ai-title\",\"aiTitle\":\"Unsafe\",\"cwd\":\"/synthetic/title\",\"repository\":\"/synthetic/other\"}\n")
    malformed_case(db,"conflicting-sessions","{\"type\":\"ai-title\",\"aiTitle\":\"Unsafe\",\"sessionId\":\"history-title-session\",\"session_id\":\"other\"}\n")
    malformed_case(db,"different-session","{\"type\":\"ai-title\",\"aiTitle\":\"Unsafe\",\"sessionId\":\"other\"}\n")
    write_bytes("invalid-utf8-title.jsonl",List.append(&2,U32,
      Domain.encode(request() ++ title("Older tempting title")),[255,10]))
    invalid_utf8 : String <- Store.import_file(db,"claude","invalid-utf8-title.jsonl")
    Check.expect(db,invalid_utf8,Check.scope(),"Safe recorded request","unreadable UTF8 record blocks stale recorded title preference")
    +constructed : Json.Json = Json.JObject{[Json.JField{"type",Json.JString{"ai-title"}},
      Json.JField{"aiTitle",Json.JString{"One"}},Json.JField{"aiTitle",Json.JString{"Two"}}]}
    Check.assert(unavailable(Recorded.recorded(constructed,"")),"duplicate manually constructed fields cannot establish a recorded title")
    fallback : String <- Check.capture(db,"no-title.jsonl",request() ++ "{\"type\":\"custom-title\",\"aiTitle\":\"Not supported\"}\n")
    Check.expect(db,fallback,Check.scope(),"Safe recorded request","unrecognized title shape preserves existing request fallback")
    neutral : String <- Check.capture(db,"neutral-title.jsonl",title("\n"))
    Check.expect(db,neutral,Check.scope(),"Captured source","unusable title without a request preserves neutral fallback")

def scopes(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- Check.capture(db,"scope-title.jsonl",request() ++
      "{\"type\":\"ai-title\",\"aiTitle\":\"Scoped metadata title\",\"sessionId\":\"history-title-session\",\"timestamp\":\"2026-10-20T12:00:00Z\"}\n")
    Check.expect(db,snapshot,Scoped.Scope{"claude","/synthetic/title","","2026-10-20"},"Scoped metadata title","verified incoming repository and local date admit title")
    Check.expect(db,snapshot,Scoped.Scope{"claude","/synthetic/other","",""},"Captured source","raw repository scope excludes title and request")
    Check.expect(db,snapshot,Scoped.Scope{"codex","","",""},"Captured source","provider scope excludes Claude title")
    Check.expect(db,snapshot,Scoped.Scope{"claude","","user",""},"Safe recorded request","explicit user role preserves user request fallback instead of metadata title")
    Check.expect(db,snapshot,Scoped.Scope{"","","assistant",""},"Captured source","assistant role cannot expose metadata title or user fallback")
    Check.expect(db,snapshot,Scoped.Scope{"","","","2026-10-21"},"Captured source","later date excludes both recorded title and request")
    undated : String <- Check.capture(db,"undated-title.jsonl",request() ++ title("Undated metadata"))
    Check.expect(db,undated,Scoped.Scope{"","","","2026-10-20"},"Safe recorded request","undated title cannot borrow a request timestamp for date scope")
    Store.exec(db,"UPDATE events SET repository='/synthetic/other',timestamp='2026-10-21T00:00:00.000000000Z',body='Forged title' WHERE snapshot=? AND coverage='recorded_title'",[Sql.Cell.Integer{snapshot}])
    Check.expect(db,snapshot,Scoped.Scope{"claude","/synthetic/other","","2026-10-21"},"Captured source","forged projection metadata cannot widen retained title scopes")
    +forged : String <- Check.capture(db,"forged-title-locator.jsonl",request() ++ Check.record("assistant","/synthetic/title","2026-10-20T12:00:00Z","","Not a title"))
    Store.exec(db,"UPDATE events SET coverage='recorded_title' WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{forged}])
    Check.expect(db,forged,Check.scope(),"Safe recorded request","forged title locator cannot promote assistant body to title")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{snapshot}])
    Check.expect(db,snapshot,Scoped.Scope{"claude","/synthetic/title","",""},"Safe recorded request","missing title context cannot invent inherited repository")

def bounds(+db: U32) -> IO(Unit):
  +raw_title = title("Bounded retained metadata")
  +padding = Check.record("assistant","/synthetic/title","2026-10-20T12:00:00Z","","Synthetic padding")
  do IO<Unit>:
    +snapshot : String <- Check.capture(db,"late-bounded-title.jsonl",request() ++ String.repeat(padding,64n) ++ raw_title)
    +base : List<&2,List<&2,Sql.Cell>> <- Check.history_row(db,snapshot)
    +raw_cost : U32 = U32.from_nat(List.length(&2,U32,Domain.encode(padding ++ raw_title)))
    +zero : List<&2,List<&2,Sql.Cell>> <- Titles.enrich_budget(db,base,Check.scope(),0)
    Check.assert(String.eq(Store.field(Store.first(zero),7n),"Captured source"),"zero raw byte budget performs no title read")
    +exact : List<&2,List<&2,Sql.Cell>> <- Titles.enrich_budget(db,base,Check.scope(),raw_cost)
    Check.assert(String.eq(Store.field(Store.first(exact),7n),"Bounded retained metadata"),"exact title and predecessor byte budget succeeds")
    +shared : List<&2,List<&2,Sql.Cell>> <- Titles.enrich_budget(db,List.append(&2,List<&2,Sql.Cell>,base,base),Check.scope(),raw_cost)
    Check.assert(String.eq(Store.field(Store.first(shared),7n),"Bounded retained metadata") &&
      String.eq(Store.field(Store.first(List.drop(&2,List<&2,Sql.Cell>,shared,1n)),7n),"Captured source"),
      "recorded title byte budget is shared across rows")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    Check.expect(db,snapshot,Scoped.Scope{"claude","/synthetic/title","",""},"Bounded retained metadata","late title verifies selected bytes and context without reading damaged earlier prefix")
    +plan : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "EXPLAIN QUERY PLAN SELECT ordinal FROM events WHERE snapshot=? AND (coverage IN ('recorded_title','recorded_title; invalid_timestamp','oversized_record_fragment') OR coverage GLOB 'invalid_utf8:*' OR role='error') ORDER BY ordinal DESC LIMIT 1",
      [Sql.Cell.Integer{snapshot}],10)
    Check.assert(String.contains(Store.projection_cells(List.concat(&2,Sql.Cell,plan)),"events_recorded_title"),
      "latest title lookup uses exact partial index without scanning unrelated events")

def migration(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +old : String <- Check.capture(db,"legacy-title.jsonl",request() ++ title("Retained legacy title"))
    +raw : String <- raw_identity(db,old)
    Store.exec(db,"UPDATE events SET role='unsupported',body='[Unsupported Claude record type]',coverage='unsupported' WHERE snapshot=? AND coverage='recorded_title'",[Sql.Cell.Integer{old}])
    Seal.write_full(db,old,"providers-v4-utc-context-relay")
    +valid : Bool <- Store.projection_valid(db,old)
    Check.assert(Bool.not(valid),"synthetic v4 projection seal cannot be reused under title-aware version")
    Check.expect(db,old,Check.scope(),"Safe recorded request","legacy title projection retains safe fallback until explicit rebuild")
    Store.write_text("legacy-title.jsonl","w","source no longer available")
    Maintenance.rebuild(db,old)
    Check.expect(db,old,Check.scope(),"Retained legacy title","owned raw rebuild restores exact title after source replacement")
    raw_after : String <- raw_identity(db,old)
    Check.assert(String.eq(raw,raw_after),"title-aware rebuild preserves immutable raw IDs generations ordinals offsets and digests")
    scalar(db,"SELECT version FROM projection_checks WHERE snapshot=?",[Sql.Cell.Integer{old}],Seal.version(Store.projection_version()),"rebuild stores title-aware projection version")
    +append_path : String = "append-title.jsonl"
    +first : String <- Check.capture(db,append_path,request() ++ title("Initial title"))
    Store.write_text(append_path,"a",title("Revised appended title") ++ String.repeat("{\"type\":\"future-record\"}\n",12n))
    +second : String <- Store.import_file(db,"claude",append_path)
    Check.expect(db,second,Check.scope(),"Revised appended title","append capture selects latest revised title")
    +first_rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT s.id,s.provider,s.locator,p.id,p.generation,p.extent,p.records,'',1,0 FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=?",
      [Sql.Cell.Integer{first}],1)
    +retained : List<&2,List<&2,Sql.Cell>> <- Titles.enrich(db,first_rows,Check.scope())
    Check.assert(String.eq(Store.field(Store.first(retained),7n),"Initial title"),"historical snapshot title stays bound after append")

# Selected corruption must fail rather than silently display a stale fallback.
def rejected(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  Check.assert(U32.is_eq(code,1) && String.contains(out ++ err,"integrity"),"corrupt selected title raw is rejected with integrity diagnostic")

def corrupt(+db: U32,self: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- Check.capture(db,"corrupt-provider-title.jsonl",request() ++ title("Never trust damaged title"))
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=1)",[Sql.Cell.Integer{snapshot}])
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["corrupt",snapshot],"",8192,30000))
    rejected(result)

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/provider-titles.sqlite")
    basics(db)
    malformed(db)
    scopes(db)
    bounds(db)
    migration(db)
    corrupt(db,self)
    IO.try(Unit,Sql.close(db))

def child(snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/provider-titles.sqlite")
    rows : List<&2,List<&2,Sql.Cell>> <- Check.history_row(db,snapshot)
    result : List<&2,List<&2,Sql.Cell>> <- Titles.enrich(db,rows,Check.scope())
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,3,"UNEXPECTED corrupt title accepted")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "corrupt" <> snapshot <> []: child(snapshot)
    case _: IO.die(Unit,2,"Unexpected provider title test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
