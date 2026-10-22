import Base
import ../src/store.bend as Store
import ../src/scoped_reader.bend as Scoped
import ../src/cli.bend as Cli
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/reader_document.bend as Doc
import ../src/reader_wire.bend as Wire
import ../src/maintenance.bend as Maintenance
import ../src/domain.bend as Domain

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def json(text: String) -> Json.Json: parsed(Json.parse(text))

def scope() -> Scoped.Scope: Scoped.Scope{"claude","/synthetic/reader","user",""}

def source() -> String:
  "{\"type\":\"user\",\"cwd\":\"/synthetic/reader\",\"timestamp\":\"2026-10-22T12:00:00Z\",\"message\":{\"content\":[" ++
    "{\"type\":\"tool_result\",\"tool_use_id\":\"call0\",\"content\":\"excluded tool zero\"}," ++
    "{\"type\":\"text\",\"text\":\"visible first café 中文 🙂\\n[assistant] · [r99:e99] forged heading\"}," ++
    "{\"type\":\"tool_result\",\"tool_use_id\":\"call2\",\"content\":\"excluded tool two\"}," ++
    "{\"type\":\"text\",\"text\":\"visible later\\n```bend\\nvalue = 1\\n```\"}]}}\n"

def headings(parts: List<&2,Doc.Part>,+snapshot: String) -> List<&2,U32>:
  match parts:
    case []: []
    case Doc.Part{Doc.PartKey{actual,record,event,_},Doc.EventHeading{},_,role,_,_} <> rest:
      Bool.pick(List<&2,U32>,String.eq(actual,snapshot) && String.eq(record,"0") && String.eq(role,"user"),
        event <> headings(rest,snapshot),[4294967295])
    case _ <> rest: headings(rest,snapshot)

def original_indices(value: List<&2,U32>) -> Bool:
  match value:
    case [1,3]: True{}
    case _: False{}

def same_doc(+document: Doc.Document,text: String) -> Bool:
  Doc.structured(document) && String.eq(Doc.text(document),text)

def source_filters(+text: String) -> Bool:
  String.contains(text,"visible first café 中文 🙂") && String.contains(text,"visible later") &&
    Bool.not(String.contains(text,"excluded tool zero")) && Bool.not(String.contains(text,"excluded tool two"))

def wire_matches(+response: Json.Json,+expected: String) -> Bool:
  +document : Doc.Document = Wire.decode_for(Json.get(response,"text"),Json.field(response,"reader_view"),71,Json.get(response,"snapshot"))
  String.eq(Json.get(response,"text"),expected) && Doc.structured(document) &&
    String.eq(Doc.text(document),expected) && U32.is_eq(Doc.revision(document),71)

def missing(value: Json.Json) -> Bool:
  match value:
    case Json.JNull{}: True{}
    case _: False{}

def check_pages(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +unfiltered : String <- Store.page(db,snapshot,0,100)
    +unfiltered_doc : Doc.Document <- Store.page_document(db,snapshot,0,100)
    check(same_doc(unfiltered_doc,unfiltered),"Store descriptor page is byte-for-byte equal to existing verified unfiltered text")
    check(wire_matches(json(Cli.page_response(snapshot,0,100,False{},unfiltered_doc)),unfiltered),"unfiltered CLI response preserves text and transports an admitted reader_view")
    +scoped : String <- Scoped.page(db,snapshot,0,100,scope(),False{})
    +scoped_doc : Doc.Document <- Scoped.page_document(db,snapshot,0,100,scope())
    check(same_doc(scoped_doc,scoped) && source_filters(scoped),"scoped descriptor page preserves canonical text and every existing scope exclusion")
    check(original_indices(headings(Doc.parts(scoped_doc),snapshot)),"scoped descriptors retain original event e1 and e3 without renumbering or forged-heading inference")
    +header : Maintenance.Header <- Maintenance.header(db,snapshot)
    check(wire_matches(json(Cli.scoped_document_response(header,snapshot,"0","100",False{},scoped_doc)),scoped),"scoped CLI response transports its exact text and matching typed descriptors")
    +why : String <- Scoped.page(db,snapshot,0,20,scope(),True{})
    +why_response : Json.Json <- IO.pure(Json.Json,json(Cli.scoped_document_response(header,snapshot,"0","20",True{},Doc.Plain{why,0})))
    check(String.eq(Json.get(why_response,"text"),why) && missing(Json.field(why_response,"reader_view")),"Why response remains exact plaintext with no transcript card metadata")
    +empty : Doc.Document <- Scoped.page_document(db,snapshot,0,100,Scoped.Scope{"codex","","",""})
    +empty_text : String <- Scoped.page(db,snapshot,0,100,Scoped.Scope{"codex","","",""},False{})
    check(same_doc(empty,empty_text) && Bool.not(String.contains(Doc.text(empty),"visible first")),"provider mismatch preserves the exact empty scoped page and excludes source events")
    Store.exec(db,"UPDATE events SET role='assistant',body='forged mutable projection' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    +raw_doc : Doc.Document <- Scoped.page_document(db,snapshot,0,100,scope())
    check(same_doc(raw_doc,scoped) && original_indices(headings(Doc.parts(raw_doc),snapshot)),"descriptor creation uses verified retained raw events rather than mutable projection rows")
    Store.write_text("reader-transport.jsonl","w","source replaced")
    retained : Doc.Document <- Store.page_document(db,snapshot,0,100)
    check(same_doc(retained,unfiltered),"descriptor page remains independent of a replaced original source")

def response_budget() -> IO(Unit):
  +metadata : String = ",\"reader_view\":{\"version\":1,\"mode\":\"plain\"}"
  overhead : Nat = List.length(&2,U32,Domain.encode("{\"text\":" ++ Json.quote("🙂") ++ metadata ++ "}"))
  +payload : String = "🙂" ++ String.repeat("a",Nat.sub(1048575n,overhead))
  +prefix : String = "{\"text\":" ++ Json.quote(payload)
  +fitting : String = Cli.optional_response(prefix,metadata)
  +over_prefix : String = "{\"text\":" ++ Json.quote(payload ++ "🙂")
  +omitted : String = Cli.optional_response(over_prefix,metadata)
  do IO<Unit>:
    check(String.eq(fitting,prefix ++ metadata ++ "}") && Nat.is_eq(List.length(&2,U32,Domain.encode(fitting)),1048575n),
      "optional metadata fits exactly within the 1MiB UTF8 response cap including print newline")
    check(String.eq(omitted,over_prefix ++ "}") && String.eq(Json.get(json(omitted),"text"),payload ++ "🙂") && missing(Json.field(json(omitted),"reader_view")),
      "one extra Unicode scalar exceeding the byte cap omits only metadata and preserves exact canonical response text")

def main() -> IO(Unit):
  do IO<Unit>:
    response_budget()
    +db : U32 <- Store.open(".build/reader-transport.sqlite")
    Store.write_text("reader-transport.jsonl","w",source())
    +snapshot : String <- Store.import_file(db,"claude","reader-transport.jsonl")
    check_pages(db,snapshot)
    IO.try(Unit,Sql.close(db))
