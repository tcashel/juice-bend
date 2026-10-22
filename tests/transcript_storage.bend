import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/scoped_reader.bend as Scoped
import ../src/evidence.bend as Evidence
import ../src/providers.bend as Providers

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def body() -> String:
  "Useful first message café é 中文 🙂\n" ++ String.repeat("b",4096n) ++ "\nBODY END"

def argument() -> String:
  String.repeat("a",4096n) ++ " ARGUMENT END 中文 🙂"

def result() -> String:
  "saved result\n" ++ String.repeat("r",4096n) ++ " RESULT END café 🙂"

def fixture() -> String:
  "{\"type\":\"assistant\",\"cwd\":\"/synthetic/polish\",\"sessionId\":\"polish-session\"," ++
    "\"parentUuid\":\"polish-parent\",\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{" ++
    "\"model\":\"polish-model\",\"usage\":{\"output_tokens\":9007199254740993},\"content\":[" ++
    "{\"type\":\"text\",\"text\":" ++ Json.quote(body()) ++ "}," ++
    "{\"type\":\"tool_use\",\"id\":\"polish-call\",\"name\":\"Write\",\"input\":{\"content\":" ++ Json.quote(argument()) ++ "}}," ++
    "{\"type\":\"tool_result\",\"tool_use_id\":\"polish-call\",\"content\":" ++ Json.quote(result()) ++ "}]}}\n"

def scope() -> Scoped.Scope:
  Scoped.Scope{"claude","/synthetic/polish","",""}

def empty_record() -> String:
  "{\"type\":\"assistant\",\"message\":{\"content\":[]}}\n"

def bytes(text: String) -> U32:
  U32.from_nat(List.length(&2,U32,Domain.encode(text)))

def tool_at(time: String) -> Providers.Record:
  Providers.ProviderEvent{"assistant","","Write","polish-call","{\"content\":" ++ Json.quote(argument()) ++ "}","",
    "/synthetic/polish","polish-session",time,"polish-model","","polish-parent","complete"}

def payloads(+page: String) -> Bool:
  String.contains(page,body()) && String.contains(page,"Tool: Write\nCall ID: polish-call\nArguments: {\"content\":" ++ Json.quote(argument()) ++ "}\n") &&
    String.contains(page,"Call ID: polish-call\nResult: " ++ result() ++ "\n")

def metadata(+page: String) -> Bool:
  String.contains(page,"Captured repository: /synthetic/polish\nSession reference: polish-session\n") &&
    String.contains(page,"Recorded model: polish-model\n") &&
    String.contains(page,"Recorded usage (source fact; mirrors are not additive): {\"output_tokens\":9007199254740993}\n") &&
    String.contains(page,"Parent reference: polish-parent\nCoverage: complete\n")

def cited(result: Result<&2,&2,String,String>,needle: String) -> Bool:
  match result:
    case Done{text}: String.contains(text,needle)
    case Fail{_}: False{}

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/transcript-storage.sqlite")
    Store.write_text("polish.jsonl","w",fixture() ++ empty_record())
    +snapshot : String <- Store.import_file(db,"claude","polish.jsonl")
    +all : String <- Store.page(db,snapshot,0,40)
    +filtered : String <- Scoped.page(db,snapshot,0,40,scope(),False{})
    check(payloads(all) && payloads(filtered),"both captured readers preserve every long Unicode body, tool argument and result")
    check(metadata(all) && metadata(filtered),"both captured readers retain all recorded metadata without rounding wide usage")
    check(String.starts_with(all,"Captured page · 3 events · snapshot " ++ snapshot ++ "\n") &&
      String.starts_with(filtered,"Captured page · 3 events · snapshot " ++ snapshot ++ "\n"),
      "All providers and repository-filtered pages share content-first presentation")
    check(String.contains(all,"[assistant] · [r0:e0]\n" ++ body()) &&
      String.contains(filtered,"[assistant] · [r0:e0]\n" ++ body()) &&
      String.contains(all,"Recorded time: 2026-10-20T12:00:00Z\n") &&
      String.contains(filtered,"Recorded time: 2026-10-20T12:00:00.000000000Z\n"),
      "captured first event keeps a compact reference; appendix preserves raw or normalized timestamp behavior")
    +record : Evidence.Verified <- Evidence.read_record(db,snapshot,0)
    check(String.contains(filtered,"Citation: " ++ Evidence.citation(record,0) ++ "\n") &&
      String.contains(filtered,"Citation: " ++ Evidence.citation(record,1) ++ "\n") &&
      String.contains(filtered,"Citation: " ++ Evidence.citation(record,2) ++ "\n"),
      "filtered appendix preserves exact frozen identities for all events in one physical record")
    resolved : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,Evidence.citation(record,1))
    check(cited(resolved,Evidence.why_event(record,1,tool_at("2026-10-20T12:00:00Z"))),"exact retained tool citation resolves to the unchanged bounded evidence excerpt")
    check(String.contains(all,"Record 0 · bytes 0.." ++ U32.show(bytes(fixture()))) &&
      String.contains(all,"Source locator and full machine citations are not included by this unfiltered reader.") &&
      Bool.not(String.contains(all,"Citation: {")),"unfiltered appendix preserves the exact record byte interval and does not invent a machine citation")
    check(String.contains(all,"Record 1 · bytes " ++ U32.show(bytes(fixture())) ++ ".." ++
      U32.show(bytes(fixture() ++ empty_record())) ++ "\nNo displayable transcript event in this captured record.\n"),
      "mixed unfiltered page retains the exact byte interval of a selected zero-event record")
    check(String.contains(filtered,"Provider: claude · repository: /synthetic/polish · role: all · after: all") &&
      String.contains(filtered,"the complete snapshot was not reverified"),"filtered appendix retains scope and bounded integrity disclosure")
    +why : String <- Scoped.page(db,snapshot,0,40,scope(),True{})
    check(String.starts_with(why,"Juice Bend · scoped captured Why evidence\n") &&
      String.contains(why,Evidence.why_event(record,1,tool_at("2026-10-20T12:00:00.000000000Z"))),
      "Why keeps its existing evidence presentation")
    Store.write_text("polish.jsonl","a","{\"type\":\"user\",\"message\":{\"content\":\"newer unselected\"}}\n")
    newer : String <- Store.import_file(db,"claude","polish.jsonl")
    frozen_all : String <- Store.page(db,snapshot,0,40)
    frozen_filtered : String <- Scoped.page(db,snapshot,0,40,scope(),False{})
    check(String.eq(all,frozen_all) && String.eq(filtered,frozen_filtered),"both polished readers remain bound to their original immutable snapshot after append")
    Store.write_text("polish.jsonl","w","source replaced")
    retained_all : String <- Store.page(db,snapshot,0,40)
    retained_filtered : String <- Scoped.page(db,snapshot,0,40,scope(),False{})
    check(String.eq(all,retained_all) && String.eq(filtered,retained_filtered),"both polished readers remain exact after original source replacement")
    Store.write_text("polish-empty.jsonl","w",empty_record())
    +empty_snapshot : String <- Store.import_file(db,"claude","polish-empty.jsonl")
    +empty_page : String <- Store.page(db,empty_snapshot,0,40)
    check(String.starts_with(empty_page,"Captured page · 0 events · snapshot " ++ empty_snapshot ++ "\n") &&
      String.contains(empty_page,"No transcript events in this captured page.\n") &&
      String.contains(empty_page,"Record 0 · bytes 0.." ++ U32.show(bytes(empty_record())) ++ "\n"),
      "all-zero-event page keeps selected physical record coverage without inventing an event")
    IO.try(Unit,Sql.close(db))
