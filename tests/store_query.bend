import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/query.bend as Query

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def claude(+repo: String,+date: String,role: String,body: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"sessionId\":\"synthetic-query\",\"cwd\":" ++ Json.quote(repo) ++
    ",\"timestamp\":" ++ Json.quote(date) ++ ",\"message\":{\"content\":" ++ Json.quote(body) ++ "}}\n"

def codex(repo: String,date: String,body: String) -> String:
  "{\"type\":\"response_item\",\"cwd\":" ++ Json.quote(repo) ++ ",\"timestamp\":" ++ Json.quote(date) ++
    ",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_text\",\"text\":" ++ Json.quote(body) ++ "}]}}\n"

def count(+db: U32, query: String, provider: String, repo: String, role: String, after: String, expected: Nat, name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.search(db,query,provider,repo,role,after,100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),expected),name)

def parse_filters(result: Result<&2,&2,String,Query.Filters>) -> IO(Query.Filters):
  match result:
    case Done{filters}:
      IO.pure(Query.Filters, filters)
    case Fail{message}:
      IO.die(Query.Filters,1,message)

def filtered(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +filters : Query.Filters <- parse_filters(Query.parse("provider:claude repo:/synthetic/a role:user after:2026-10-02"))
    count(db,Query.query(filters),Query.provider(filters),Query.repo(filters),Query.role(filters),Query.after(filters),1n,
      "filter-only query preserves provider repo role and inclusive date")

def all_fields(rows: List<&2,List<&2,Sql.Cell>>,+provider: String,+repo: String,+role: String) -> Bool:
  match rows:
    case []:
      True{}
    case +row <> rest:
      String.eq(Store.field(row,3n),provider) && String.eq(Store.field(row,6n),repo) && String.eq(Store.field(row,4n),role) &&
        all_fields(rest,provider,repo,role)

def page_ids(rows: List<&2,List<&2,Sql.Cell>>) -> String:
  match rows:
    case []:
      ""
    case +row <> rest:
      Store.field(row,0n) ++ ":" ++ Store.field(row,1n) ++ ":" ++ Store.field(row,2n) ++ ";" ++ page_ids(rest)

def scalar(+db: U32,statement: String,bindings: List<&2,Sql.Cell>,expected: String,name: String) -> IO(Unit):
  do IO<Unit>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,statement,bindings,1)
    assert(String.eq(Store.field(Store.first(rows),0n),expected),name)

def provider_context(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("query-context-codex.jsonl","w","{\"type\":\"turn_context\",\"payload\":{\"model\":\"synthetic-first\",\"cwd\":\"/synthetic/context\"}}\n" ++
      codex("/synthetic/context","2026-10-08T12:00:00Z","first contextual turn"))
    +first : String <- Store.import_file(db,"codex","query-context-codex.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{first}],"synthetic-first",
      "Codex recorded turn-context model carries into following message")
    Store.write_text("query-context-codex.jsonl","a",codex("/synthetic/context","2026-10-08T12:01:00Z","appended contextual turn"))
    +next : String <- Store.import_file(db,"codex","query-context-codex.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=2",[Sql.Cell.Integer{next}],"synthetic-first",
      "Codex model checkpoint survives append")
    Store.write_text("query-context-codex.jsonl","a","{\"type\":\"turn_context\",\"payload\":{\"model\":\"synthetic-second\"}}\n" ++
      codex("/synthetic/context","2026-10-08T12:02:00Z","new contextual turn"))
    +changed : String <- Store.import_file(db,"codex","query-context-codex.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=4",[Sql.Cell.Integer{changed}],"synthetic-second",
      "Codex later context model updates only later projection")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{first}],"synthetic-first",
      "Codex later model does not reinterpret an old snapshot")
    Store.write_text("query-context-claude.jsonl","w","{\"type\":\"assistant\",\"message\":{\"model\":\"synthetic-claude\",\"content\":\"recorded model\"}}\n" ++
      claude("/synthetic/context","2026-10-09T12:00:00Z","assistant","model unknown"))
    +claude_first : String <- Store.import_file(db,"claude","query-context-claude.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{claude_first}],"",
      "Claude missing model is unknown rather than inherited")
    Store.write_text("query-context-claude.jsonl","a",claude("/synthetic/context","2026-10-09T12:01:00Z","assistant","appended model unknown"))
    +claude_next : String <- Store.import_file(db,"claude","query-context-claude.jsonl")
    scalar(db,"SELECT model FROM events WHERE snapshot=? AND ordinal=2",[Sql.Cell.Integer{claude_next}],"",
      "Claude missing model remains unknown after append")

def history_scope(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("mixed-history.jsonl","w",
      String.repeat(claude("/synthetic/history-a","2026-10-10T10:00:00Z","user","Outside-scope A excerpt"),45n) ++
      claude("/synthetic/history-b","2026-10-10T11:00:00Z","user","Visible B excerpt"))
    +snapshot : String <- Store.import_file(db,"claude","mixed-history.jsonl")
    +scoped : List<&2,List<&2,Sql.Cell>> <- Store.history(db,"claude","/synthetic/history-b",100,0)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,scoped),1n) &&
      String.eq(Store.field(Store.first(scoped),3n),snapshot),
      "repository-only history includes matching mixed-source snapshot once")
    assert(String.eq(Store.field(Store.first(scoped),7n),"Visible B excerpt"),
      "repository-only history excerpt comes from requested repository")
    assert(String.eq(Store.field(Store.first(scoped),8n),"/synthetic/history-b"),
      "repository-only history label comes from requested repository")
    assert(String.eq(Store.field(Store.first(scoped),9n),"45"),
      "repository-only history opens represented evidence beyond the first physical page")
    assert(Bool.not(String.contains(Store.field(Store.first(scoped),7n),"Outside-scope")) &&
      Bool.not(String.contains(Store.field(Store.first(scoped),8n),"history-a")),
      "repository-only history cannot expose another repository excerpt or label")
    +other : List<&2,List<&2,Sql.Cell>> <- Store.history(db,"claude","/synthetic/history-a",100,0)
    assert(String.eq(Store.field(Store.first(other),7n),"Outside-scope A excerpt") &&
      String.eq(Store.field(Store.first(other),8n),"/synthetic/history-a"),
      "opposite repository scope independently selects its own excerpt")
    wrong_provider : List<&2,List<&2,Sql.Cell>> <- Store.history(db,"codex","/synthetic/history-b",100,0)
    assert(List.is_empty(&2,List<&2,Sql.Cell>,wrong_provider),
      "history repository matching cannot bypass provider restriction")
    +unscoped : List<&2,List<&2,Sql.Cell>> <- Store.history(db,"claude","",100,0)
    assert(String.eq(Store.field(Store.first(unscoped),3n),snapshot) &&
      String.eq(Store.field(Store.first(unscoped),7n),"Outside-scope A excerpt") &&
      String.eq(Store.field(Store.first(unscoped),8n),"/synthetic/history-a"),
      "unfiltered history retains first captured excerpt and deterministic repository")
    Store.write_text("empty-scope-history.jsonl","w",
      claude("/synthetic/history-a","2026-10-11T10:00:00Z","user","Must not supply empty-scope title") ++
      claude("/synthetic/history-empty","2026-10-11T11:00:00Z","user",""))
    empty_snapshot : String <- Store.import_file(db,"claude","empty-scope-history.jsonl")
    +empty : List<&2,List<&2,Sql.Cell>> <- Store.history(db,"claude","/synthetic/history-empty",100,0)
    assert(String.eq(Store.field(Store.first(empty),7n),"Captured source") &&
      String.eq(Store.field(Store.first(empty),8n),"/synthetic/history-empty"),
      "empty in-scope text uses neutral history title instead of another repository")
    assert(String.eq(Store.field(Store.first(empty),9n),"1"),
      "history without readable in-scope text still opens its first matching record")

def main() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/store-query.sqlite")
    Store.write_text("query-a.jsonl","w",claude("/synthetic/a","2026-10-01T12:00:00Z","user","lemon counter src/lemon.bend") ++
      claude("/synthetic/a","2026-10-02T12:00:00Z","user","counter with fresh lemon") ++
      claude("/synthetic/a","2026-10-03T12:00:00Z","assistant","lemon counter assistant"))
    +first : String <- Store.import_file(db,"claude","query-a.jsonl")
    Store.write_text("query-b.jsonl","w",claude("/synthetic/b","2026-10-04T12:00:00Z","user","lemon counter other repository"))
    second : String <- Store.import_file(db,"claude","query-b.jsonl")
    Store.write_text("query-c.jsonl","w",codex("/synthetic/a","2026-10-05T12:00:00Z","lemon counter other provider"))
    third : String <- Store.import_file(db,"codex","query-c.jsonl")
    count(db,"lemon counter","","","","",5n,"Store.search defaults to AND instead of a whole phrase")
    count(db,"\"lemon counter\"","","","","",4n,"Store.search explicit phrase preserves adjacency")
    count(db,"src/lemon.bend","","","","",1n,"Store.search supports literal paths")
    count(db,"()[]{}:*!-+","","","","",0n,"Store.search punctuation-only input is safe")
    count(db,"x: OR 1=1 --","","","","",0n,"Store.search syntax-like input cannot broaden scope")
    count(db,"","","","","",5n,"empty query browses accepted latest events")
    count(db," \t\"\" ","","","","",5n,"empty tokens bypass MATCH safely")
    count(db,"","claude","","","",4n,"filter-only provider scope")
    count(db,"","","/synthetic/a","","",4n,"filter-only repository scope")
    count(db,"","","","assistant","",1n,"filter-only role scope")
    count(db,"","","","","2026-10-04",2n,"filter-only date scope")
    filtered(db)
    count(db,"lemon counter","claude","/synthetic/a","user","2026-10-02",1n,"lexical query retains all four scopes")
    count(db,"lemon","codex","/synthetic/b","user","",0n,"cross-provider repository combination cannot leak rows")
    +scoped : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"lemon","claude","/synthetic/a","user","",100,0)
    assert(all_fields(scoped,"claude","/synthetic/a","user"),"returned fields retain selected domain")
    +page0 : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"","claude","/synthetic/a","user","",1,0)
    +page1 : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"","claude","/synthetic/a","user","",1,1)
    page2 : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"","claude","/synthetic/a","user","",1,2)
    assert(String.eq(page_ids(page0),first ++ ":0:0;") && String.eq(page_ids(page1),first ++ ":1:0;") &&
      List.is_empty(&2,List<&2,Sql.Cell>,page2),"filter-only paging has stable occurrence order and bound")
    Store.write_text("query-a.jsonl","a",claude("/synthetic/a","2026-10-06T12:00:00Z","user","later lemon counter"))
    appended : String <- Store.import_file(db,"claude","query-a.jsonl")
    count(db,"lemon counter","claude","/synthetic/a","user","",3n,"append search contains latest occurrences once")
    count(db,"","claude","/synthetic/a","user","",3n,"append filter-only browse excludes old snapshots")
    Store.write_text("query-b.jsonl","w",claude("/synthetic/b","2026-10-07T12:00:00Z","user","rewritten history"))
    rewritten : String <- Store.import_file(db,"claude","query-b.jsonl")
    count(db,"lemon","claude","/synthetic/b","","",0n,"rewrite hides historical FTS matches from latest search")
    count(db,"","claude","/synthetic/b","","",1n,"rewrite filter-only selection returns latest generation only")
    Store.write_text("query-tool.jsonl","w","{\"type\":\"assistant\",\"cwd\":\"/synthetic/tool\",\"message\":{\"content\":[{\"type\":\"tool_use\",\"name\":\"Write\",\"id\":\"tool-query\",\"input\":{\"file_path\":\"src/unique-file.bend\",\"content\":\"synthetic\"}}]}}\n")
    tool : String <- Store.import_file(db,"claude","query-tool.jsonl")
    tool_hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"src/unique-file.bend","claude","/synthetic/tool","","",100,0)
    assert(String.contains(Store.field(Store.first(tool_hits),5n),"unique-file.bend"),"search snippet shows matching tool argument field")
    provider_context(db)
    history_scope(db)
    IO.try(Unit,Sql.close(db))
