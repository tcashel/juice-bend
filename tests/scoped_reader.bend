import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/scoped_reader.bend as Scoped
import ../src/cli.bend as Cli
import ../src/evidence.bend as Evidence
import ../src/providers.bend as Providers
import ../src/domain.bend as Domain

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def record(role: String,repo: String,time: String,body: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"cwd\":" ++ Json.quote(repo) ++
    ",\"timestamp\":" ++ Json.quote(time) ++ ",\"sessionId\":\"scoped-fixture\"," ++
    "\"message\":{\"content\":" ++ Json.quote(body) ++ "}}\n"

def scope() -> Scoped.Scope:
  Scoped.Scope{"claude","/synthetic/a","user","2026-10-02"}

def first_record_extent() -> String:
  first = record("user","/synthetic/a","2026-10-01T12:00:00Z","excluded-old-date")
  U32.show(U32.from_nat(List.length(&2,U32,Domain.encode(first))))

def presentation() -> IO(Unit):
  +record = {Evidence.Verified{"claude","/synthetic/quoted\"café 中文 🙂.jsonl","3","5","120","7",[]} : Evidence.Verified}
  +event = {Providers.ProviderEvent{"assistant","Café é 中文 🙂\nsecond line","Write","call-1",
      "{\"path\":\"x\"}","recorded result","/synthetic/repo","session",
      "2026-10-20T00:00:00Z","recorded-model","{\"input_tokens\":9007199254740993}",
      "parent-session","partial_content"} : Providers.Record}
  shown = Scoped.event_text(False{},record,2,event)
  details = Scoped.event_details(False{},record,2,event)
  expected = "[assistant] · [r7:e2] · coverage: partial_content\n" ++
    "Café é 中文 🙂\nsecond line\nTool: Write\nCall ID: call-1\nArguments: {\"path\":\"x\"}\n" ++
    "Result: recorded result\n\n"
  expected_details = "[r7:e2]\nRole: assistant\nRecorded time: 2026-10-20T00:00:00Z\n" ++
    "Captured repository: /synthetic/repo\nSession reference: session\nRecorded model: recorded-model\n" ++
    "Recorded usage (source fact; mirrors are not additive): {\"input_tokens\":9007199254740993}\n" ++
    "Parent reference: parent-session\nCoverage: partial_content\n" ++
    "Citation: {\"provider\":\"claude\",\"source\":\"/synthetic/quoted\\\"café 中文 🙂.jsonl\",\"generation\":\"3\",\"snapshot\":\"5\",\"extent\":\"120\",\"record\":\"7\",\"event\":\"2\"}\n\n"
  do IO<Unit>:
    assert(String.eq(shown,expected),"scoped transcript shows complete payload and adjacent partial warning before appendix")
    assert(String.eq(details,expected_details),"scoped appendix retains exact immutable citation and every recorded metadata field")
    assert(String.eq(Scoped.event_text(True{},record,2,event),Evidence.why_event(record,2,event)) &&
      String.is_empty(Scoped.event_details(True{},record,2,event)),"Why event behavior remains unchanged by transcript formatting")

def citation_choice(found: Bool,line: String,next: Unit -> String) -> String:
  match found:
    case True{}: String.drop(line,10n)
    case False{}: next(Unit{})

def first_citation(lines: List<&2,String>) -> String:
  match lines:
    case []: ""
    case +line <> rest:
      citation_choice(String.starts_with(line,"Citation: "),line,_ => first_citation(rest))

def resolved(result: Result<&2,&2,String,String>) -> Bool:
  match result:
    case Done{value}: String.contains(value,"visible-a-first")
    case Fail{_}: False{}

def long_body() -> String:
  "visible-a-first\n" ++ String.repeat("x",4096n) ++ "\nTAIL café é 中文 🙂 END"

def allowed(+text: String) -> Bool:
  String.contains(text,"visible-a-first") && String.contains(text,"visible-a-later") &&
    Bool.not(String.contains(text,"excluded-old-date")) &&
    Bool.not(String.contains(text,"excluded-assistant")) &&
    Bool.not(String.contains(text,"excluded-other-repo")) &&
    Bool.not(String.contains(text,"excluded-inherited-repo")) &&
    Bool.not(String.contains(text,"excluded-invalid-date"))

def child_result(result: U32 & (String & String),success: Bool,name: String) -> IO(Unit):
  (code,_) = result
  assert(Bool.not(Bool.xor(U32.is_eq(code,0),success)),name)

def command(self: String,args: List<String>,success: Bool,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,args,"",65536,30000))
    child_result(result,success,name)

def read_closed(result: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,text) = result
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,text))

def read(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,String> <- File.read(file,65536)
    read_closed(got)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    presentation()
    +db : U32 <- Store.open(".build/scoped.sqlite")
    Store.write_text("scope.jsonl","w",
      record("user","/synthetic/a","2026-10-01T12:00:00Z","excluded-old-date") ++
      record("user","","2026-10-02T12:00:00Z",long_body()) ++
      record("assistant","","2026-10-03T12:00:00Z","excluded-assistant") ++
      record("user","/synthetic/b","2026-10-03T12:00:00Z","excluded-other-repo") ++
      record("user","","2026-10-04T12:00:00Z","excluded-inherited-repo") ++
      record("user","/synthetic/a","not-a-date","excluded-invalid-date") ++
      record("user","","2026-10-05T12:00:00Z","visible-a-later"))
    +snapshot : String <- Store.import_file(db,"claude","scope.jsonl")
    +page : String <- Scoped.page(db,snapshot,0,100,scope(),False{})
    +unfiltered : String <- Store.page(db,snapshot,0,100)
    assert(allowed(page),"transcript preserves provider repository role and date scope")
    assert(String.contains(page,long_body()),
      "scoped transcript retains the complete payload beyond 4096 characters and its Unicode tail")
    assert(String.contains(page,"Visible events in this captured range: 2"),
      "scoped count includes only visible events in selected physical range")
    assert(String.starts_with(page,"Captured page · 2 events · snapshot " ++ snapshot ++ "\n") &&
      String.starts_with(unfiltered,"Captured page · 7 events · snapshot " ++ snapshot ++ "\n"),
      "filtered and All providers pages use the same content-first presentation")
    assert(String.contains(unfiltered,long_body()) && String.contains(unfiltered,"excluded-assistant") &&
      String.contains(unfiltered,"excluded-other-repo"),"unfiltered presentation preserves complete bodies outside filtered scope")
    assert(String.contains(unfiltered,"Record 0 · bytes 0.." ++ first_record_extent()) &&
      String.contains(unfiltered,"Source locator and full machine citations are not included") &&
      Bool.not(String.contains(unfiltered,"Citation: {")),"unfiltered appendix retains exact logical interval without inventing a source citation")
    original : Evidence.Verified <- Evidence.read_record(db,snapshot,1)
    +descriptor : String <- IO.pure(String,first_citation(String.split(page,'\n')))
    assert(String.eq(descriptor,Evidence.citation(original,0)),"actual displayed appendix preserves the original frozen citation descriptor exactly")
    resolution : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,descriptor)
    assert(resolved(resolution),"copied full appendix citation resolves to its captured request")
    +late : String <- Scoped.page(db,snapshot,4,3,scope(),False{})
    assert(String.contains(late,"visible-a-later") &&
      Bool.not(String.contains(late,"excluded-inherited-repo")),
      "late scoped page reconstructs preceding repository changes from verified raw")
    +local : String <- Scoped.page(db,snapshot,4,3,
      Scoped.Scope{"claude","","user","2026-10-04"},False{})
    assert(String.contains(local,"visible-a-later") &&
      String.contains(local,"excluded-inherited-repo") &&
      Bool.not(String.contains(local,"excluded-invalid-date")),
      "provider role and date scopes use only verified selected records")
    why : String <- Scoped.page(db,snapshot,0,20,scope(),True{})
    assert(allowed(why),"scoped Why excludes records outside the selected domain")
    +mismatch : String <- Scoped.page(db,snapshot,0,100,
      Scoped.Scope{"codex","/synthetic/a","",""},False{})
    assert(Bool.not(String.contains(mismatch,"visible-a")) &&
      String.contains(mismatch,"Visible events in this captured range: 0"),
      "provider mismatch never exposes transcript events")
    Store.exec(db,"UPDATE events SET repository='/synthetic/a',role='user',timestamp='2026-10-09' WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}])
    forged : String <- Scoped.page(db,snapshot,0,100,scope(),False{})
    assert(String.eq(forged,page),"forged projection fields cannot widen raw transcript scope")
    command(self,["export-range-scope",snapshot,"0","100","claude","/synthetic/a","user","2026-10-02","scoped.md"],
      True{},"scoped CLI export succeeds with frozen selection filters")
    +exported : String <- read("scoped.md")
    assert(allowed(exported),"scoped export contains only the visible captured events")
    assert(String.eq(exported,"# Juice Bend scoped captured evidence\n\n" ++
      "This is a bounded captured-record range, not a complete transcript export. Byte offsets refer to logical source bytes (decompressed for archives).\n\n" ++ page),
      "scoped export preserves exact displayed page including full payload citations and scope disclosure")
    command(self,["export-why-scope",snapshot,"0","20","claude","/synthetic/a","user","2026-10-02","scoped-why.md"],
      True{},"scoped Why export uses the same visibility rules")
    exported_why : String <- read("scoped-why.md")
    assert(allowed(exported_why),"scoped Why export excludes other repositories and roles")
    command(self,["session-scope",snapshot,"0","100","claude","","","2026-02-30"],
      False{},"scoped reader rejects invalid calendar dates")
    Store.exec(db,"UPDATE snapshot_context SET repository='/synthetic/a' WHERE snapshot=? AND ordinal=4",
      [Sql.Cell.Integer{snapshot}])
    command(self,["session-scope",snapshot,"4","3","claude","/synthetic/a","user","2026-10-02"],
      False{},"corrupt incoming context cannot widen repository scope")
    # Restore derived projection before append; raw is the authority.
    Cli.maintain(db,snapshot,True{})
    Store.write_text("scope.jsonl","a",
      record("user","/synthetic/a","2026-10-06T12:00:00Z","newer-unselected-append"))
    newer : String <- Store.import_file(db,"claude","scope.jsonl")
    pinned : String <- Scoped.page(db,snapshot,0,100,scope(),False{})
    assert(String.eq(pinned,page),"scoped selection stays on its immutable snapshot after append")
    all_pinned : String <- Store.page(db,snapshot,0,100)
    assert(String.eq(all_pinned,unfiltered),"unfiltered content and exact references stay on immutable snapshot after append")
    Store.write_text("scope.jsonl","w","original source replaced")
    retained : String <- Scoped.page(db,snapshot,0,100,scope(),False{})
    assert(String.eq(retained,page),"scoped transcript is independent of replaced original source")
    all_retained : String <- Store.page(db,snapshot,0,100)
    assert(String.eq(all_retained,unfiltered),"unfiltered content and exact references survive source replacement")
    Store.write_text("scope-codex.jsonl","w",
      "{\"type\":\"turn_context\",\"payload\":{\"cwd\":\"/synthetic/model\",\"model\":\"synthetic-scope-model\"}}\n" ++
      "{\"type\":\"response_item\",\"timestamp\":\"2026-10-06T12:00:00Z\",\"payload\":{\"type\":\"message\",\"role\":\"assistant\",\"content\":[{\"type\":\"output_text\",\"text\":\"scoped model context\"}]}}\n")
    codex : String <- Store.import_file(db,"codex","scope-codex.jsonl")
    model : String <- Scoped.page(db,codex,1,1,Scoped.Scope{"codex","","assistant",""},True{})
    assert(String.contains(model,"synthetic-scope-model"),
      "record-local Why uses verified inherited model context when available")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",
      [Sql.Cell.Integer{snapshot}])
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=4",
      [Sql.Cell.Integer{snapshot}])
    command(self,["session-scope",snapshot,"4","3","claude","/synthetic/a","user","2026-10-02"],
      False{},"missing legacy context replays prefix and rejects corrupt earlier metadata")
    command(self,["session-scope",snapshot,"4","3","claude","","user","2026-10-04"],
      True{},"record-local scopes do not require unrelated earlier raw records")
    IO.try(Unit,Sql.close(db))
    IO.print("Scoped reader suite passed")

def args(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> command_args:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/scoped.sqlite")
        Cli.run(db,".build",command_args)
        IO.try(Unit,Sql.close(db))
    case []:
      IO.die(Unit,2,"Missing scoped reader test program")

def main() -> IO(Unit):
  do IO<Unit>:
    argv : List<String> <- IO.args()
    args(argv)
