import Base
import ../src/history_titles.bend as Titles
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/scoped_reader.bend as Scoped
import ../src/query.bend as Query

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def scope() -> Scoped.Scope:
  Scoped.Scope{"","","",""}

def cell(a: Sql.Cell,b: Sql.Cell) -> Bool:
  match a b:
    case Sql.Cell.Null{} Sql.Cell.Null{}: True{}
    case Sql.Cell.Text{x} Sql.Cell.Text{y}: String.eq(x,y)
    case Sql.Cell.Integer{x} Sql.Cell.Integer{y}: String.eq(x,y)
    case Sql.Cell.Real{x} Sql.Cell.Real{y}: String.eq(x,y)
    case Sql.Cell.Blob{x} Sql.Cell.Blob{y}: Domain.bytes_equal(x,y)
    case _ _: False{}

def cells(a: List<&2,Sql.Cell>,b: List<&2,Sql.Cell>,+index: U32,+skip_title: Bool) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{x,xs} Con{y,ys}:
      ((skip_title && U32.is_eq(index,7)) || cell(x,y)) && cells(xs,ys,U32.inc(index),skip_title)
    case _ _: False{}

def rows(a: List<&2,List<&2,Sql.Cell>>,b: List<&2,List<&2,Sql.Cell>>,+skip_title: Bool) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Con{+x,xs} Con{y,ys}:
      Nat.is_eq(List.length(&2,Sql.Cell,x),10n) && cells(x,y,0,skip_title) && rows(xs,ys,skip_title)
    case _ _: False{}

def chosen(values: List<&2,List<&2,Sql.Cell>>,+snapshot: String) -> List<&2,List<&2,Sql.Cell>>:
  match values:
    case []: []
    case +value <> rest:
      Bool.pick(List<&2,List<&2,Sql.Cell>>,String.eq(Store.field(value,3n),snapshot),
        [value],chosen(rest,snapshot))

def history_row(+db: U32,snapshot: String) -> IO(List<&2,List<&2,Sql.Cell>>):
  do IO<List<&2,List<&2,Sql.Cell>>>:
    values : List<&2,List<&2,Sql.Cell>> <- Store.history(db,"","",100,0)
    return chosen(values,snapshot)

def expect(+db: U32,snapshot: String,scoped: Scoped.Scope,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    +before : List<&2,List<&2,Sql.Cell>> <- history_row(db,snapshot)
    +after : List<&2,List<&2,Sql.Cell>> <- Titles.enrich(db,before,scoped)
    assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,after),1n) &&
      String.eq(Store.field(Store.first(after),7n),expected) && rows(before,after,True{}),label)

def record(role: String,repo: String,date: String,meta: String,text: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"sessionId\":\"history-title-session\",\"cwd\":" ++
    Json.quote(repo) ++ ",\"timestamp\":" ++ Json.quote(date) ++ "," ++ meta ++
    "\"message\":{\"content\":" ++ Json.quote(text) ++ "}}\n"

def user(repo: String,text: String) -> String:
  record("user",repo,"2026-10-20T12:00:00Z","",text)

def capture(+db: U32,+path: String,text: String) -> IO(String):
  do IO<String>:
    Store.write_text(path,"w",text)
    Store.import_file(db,"claude",path)

def basics(+db: U32) -> IO(Unit):
  +raw = record("assistant","/synthetic/a","2026-10-20T12:00:00Z","","Earlier assistant opening") ++
    user("/synthetic/a","<system-reminder>" ++ String.repeat("x",3000n) ++
      "</system-reminder> \n\tKeep café 中文 🙂 é exact.  \n")
  do IO<Unit>:
    +snapshot : String <- capture(db,"wrapped.jsonl",raw)
    +digest : String <- Store.projection_digest(db,snapshot)
    +search_before : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"Keep","","","","",100,0)
    expect(db,snapshot,scope(),"Keep café 中文 🙂 é exact.","long context yields exact Unicode request title; all nine other cells preserved")
    +base : List<&2,List<&2,Sql.Cell>> <- history_row(db,snapshot)
    +enriched : List<&2,List<&2,Sql.Cell>> <- Titles.history(db,Query.Filters{"","","","",""},100,0)
    assert(rows(base,chosen(enriched,snapshot),True{}) && String.eq(Store.field(Store.first(base),9n),"0") &&
      String.eq(Store.field(Store.first(chosen(enriched,snapshot)),7n),"Keep café 中文 🙂 é exact."),
      "history wrapper preserves the assistant opening ordinal instead of jumping to title request")
    search_after : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"Keep","","","","",100,0)
    assert(rows(search_before,search_after,False{}),"title enrichment leaves lexical search rows byte-for-byte equivalent")
    after_digest : String <- Store.projection_digest(db,snapshot)
    assert(String.eq(digest,after_digest),"title read leaves normalized projection unchanged")
    +page : String <- Store.page(db,snapshot,0,3)
    assert(String.contains(page,"<system-reminder>" ++ String.repeat("x",3000n)) &&
      String.contains(page," \n\tKeep café 中文 🙂 é exact.  \n"),"canonical transcript keeps full wrapper and exact request whitespace")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=1",[Sql.Cell.Integer{snapshot}])
    expect(db,snapshot,Scoped.Scope{"claude","/synthetic/a","user",""},"Keep café 中文 🙂 é exact.",
      "explicit in-record repository remains usable without an incoming checkpoint")
    long : String <- capture(db,"long-title.jsonl",user("/synthetic/a",String.repeat("🙂",91n)))
    expect(db,long,scope(),String.repeat("🙂",89n) ++ "…","title truncation is at most 90 decoded scalars including ellipsis")

def excluded(+db: U32) -> IO(Unit):
  do IO<Unit>:
    context : String <- capture(db,"context.jsonl",user("/synthetic/a","<environment_context>Context only</environment_context>"))
    expect(db,context,scope(),"Captured source","context-only capture uses neutral title")
    relay : String <- capture(db,"relay.jsonl",user("/synthetic/a","<teammate-message>Relayed request</teammate-message>"))
    expect(db,relay,scope(),"Captured source","relay-only capture uses neutral title")
    meta : String <- capture(db,"meta.jsonl",record("user","/synthetic/a","2026-10-20T12:00:00Z","\"isMeta\":true,","Metadata command"))
    expect(db,meta,scope(),"Captured source","typed Claude metadata does not become a request title")
    skipped : String <- capture(db,"skipped.jsonl",user("/synthetic/a","<environment_context>Context</environment_context>") ++
      record("user","/synthetic/a","2026-10-20T12:00:00Z","\"isMeta\":true,","Metadata command") ++
      user("/synthetic/a","<teammate-message>Relay</teammate-message>") ++ user("/synthetic/a","Fourth candidate request"))
    expect(db,skipped,scope(),"Fourth candidate request","known context metadata and relay skip to the fourth request candidate")
    uncertain : String <- capture(db,"uncertain.jsonl",user("/synthetic/a","<system-reminder>Unclosed") ++ user("/synthetic/a","Later tempting request"))
    expect(db,uncertain,scope(),"Captured source","uncertain first candidate stops before later request")
    malformed : String <- capture(db,"meta-malformed.jsonl",record("user","/synthetic/a","2026-10-20T12:00:00Z","\"isMeta\":\"true\",","Untyped metadata") ++ user("/synthetic/a","Later tempting request"))
    expect(db,malformed,scope(),"Captured source","unsupported typed metadata stops request title selection")
    limit : String <- capture(db,"fifth.jsonl",String.repeat(user("/synthetic/a","<system-reminder>Context</system-reminder>"),4n) ++ user("/synthetic/a","Fifth request unavailable"))
    expect(db,limit,scope(),"Captured source","fifth distinct user record stays beyond the four-candidate bound")

def isolation(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"scope.jsonl",user("/synthetic/a","Scoped recorded request"))
    expect(db,snapshot,Scoped.Scope{"claude","/synthetic/a","user","2026-10-20"},"Scoped recorded request","matching provider repository role and inclusive date admit request")
    expect(db,snapshot,Scoped.Scope{"codex","","",""},"Captured source","provider mismatch cannot leak a request title")
    expect(db,snapshot,Scoped.Scope{"","/synthetic/b","",""},"Captured source","repository mismatch cannot leak a request title")
    expect(db,snapshot,Scoped.Scope{"","","assistant",""},"Captured source","assistant-only scope cannot expose a user request title")
    expect(db,snapshot,Scoped.Scope{"","","","2026-10-21"},"Captured source","date scope cannot expose an earlier request title")
    +forged : String <- capture(db,"forged.jsonl",record("user","/synthetic/b","2026-09-01T12:00:00Z","","Outside raw scope"))
    Store.exec(db,"UPDATE events SET repository='/synthetic/a',timestamp='2026-10-20T12:00:00.000000000Z',body='Forged matching request' WHERE snapshot=?",[Sql.Cell.Integer{forged}])
    expect(db,forged,Scoped.Scope{"claude","/synthetic/a","user","2026-10-20"},"Captured source","forged projection repository date and body cannot widen raw scope")
    +assistant : String <- capture(db,"forged-role.jsonl",record("assistant","/synthetic/a","2026-10-20T12:00:00Z","","Assistant must stay excluded"))
    Store.exec(db,"UPDATE events SET role='user' WHERE snapshot=?",[Sql.Cell.Integer{assistant}])
    expect(db,assistant,scope(),"Captured source","forged SQL user locator cannot turn an assistant raw record into a title")

def checkpoint(+db: U32) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"late.jsonl",record("assistant","/synthetic/a","2026-10-20T12:00:00Z","","Initial context") ++
      String.repeat(record("assistant","","2026-10-20T12:00:00Z","","Padding"),16n) ++
      record("assistant","/synthetic/b","2026-10-20T12:00:00Z","","Changed repository") ++ user("","Late inherited request"))
    expect(db,snapshot,Scoped.Scope{"claude","/synthetic/b","user",""},"Late inherited request","verified incoming checkpoint supplies changed repository beyond 16 physical records")
    expect(db,snapshot,Scoped.Scope{"claude","/synthetic/a","user",""},"Captured source","late title cannot borrow the first repository")
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=? AND ordinal=18",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    expect(db,snapshot,Scoped.Scope{"claude","/synthetic/b","user",""},"Captured source","missing checkpoint yields neutral title without replaying a corrupt earlier prefix")

def budgets(+db: U32) -> IO(Unit):
  +text = user("/synthetic/a","<system-reminder>" ++ String.repeat("x",512n) ++ "</system-reminder>Budget request")
  do IO<Unit>:
    one : String <- capture(db,"budget-one.jsonl",text)
    two : String <- capture(db,"budget-two.jsonl",text)
    +first : List<&2,List<&2,Sql.Cell>> <- history_row(db,one)
    second : List<&2,List<&2,Sql.Cell>> <- history_row(db,two)
    +both : List<&2,List<&2,Sql.Cell>> = List.append(&2,List<&2,Sql.Cell>,first,second)
    +zero : List<&2,List<&2,Sql.Cell>> <- Titles.enrich_budget(db,both,scope(),0)
    assert(String.eq(Store.field(Store.first(zero),7n),"Captured source") &&
      String.eq(Store.field(Store.first(List.drop(&2,List<&2,Sql.Cell>,zero,1n)),7n),"Captured source") && rows(both,zero,True{}),
      "zero budget is neutral for every row and preserves row identity")
    +limited : List<&2,List<&2,Sql.Cell>> <- Titles.enrich_budget(db,both,scope(),U32.from_nat(List.length(&2,U32,Domain.encode(text))))
    assert(String.eq(Store.field(Store.first(limited),7n),"Budget request") &&
      String.eq(Store.field(Store.first(List.drop(&2,List<&2,Sql.Cell>,limited,1n)),7n),"Captured source") &&
      rows(both,limited,True{}),"raw-byte budget is shared across page rows, not reset per snapshot")
    predecessor : String <- capture(db,"budget-predecessor.jsonl",
      record("assistant","/synthetic/a","2026-10-20T12:00:00Z","","Required predecessor") ++ text)
    +with_predecessor : List<&2,List<&2,Sql.Cell>> <- history_row(db,predecessor)
    +short : List<&2,List<&2,Sql.Cell>> <- Titles.enrich_budget(db,with_predecessor,scope(),U32.from_nat(List.length(&2,U32,Domain.encode(text))))
    assert(String.eq(Store.field(Store.first(short),7n),"Captured source") && rows(with_predecessor,short,True{}),
      "candidate budget includes its immediate raw predecessor bytes")

def rejected(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  assert(U32.is_eq(code,1) && String.contains(out ++ err,"integrity"),"corrupt selected raw fails with integrity diagnostic in isolated child")

def corruption(+db: U32,self: String) -> IO(Unit):
  do IO<Unit>:
    +snapshot : String <- capture(db,"corrupt.jsonl",user("/synthetic/a","Never trust corrupt bytes"))
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["corrupt",snapshot],"",8192,30000))
    rejected(result)

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/history-titles.sqlite")
    basics(db)
    excluded(db)
    isolation(db)
    checkpoint(db)
    budgets(db)
    corruption(db,self)
    IO.try(Unit,Sql.close(db))

def child(snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/history-titles.sqlite")
    values : List<&2,List<&2,Sql.Cell>> <- history_row(db,snapshot)
    result : List<&2,List<&2,Sql.Cell>> <- Titles.enrich(db,values,scope())
    IO.try(Unit,Sql.close(db))
    IO.die(Unit,3,"UNEXPECTED corrupt title raw accepted")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "corrupt" <> snapshot <> []: child(snapshot)
    case _: IO.die(Unit,2,"Unexpected history-title test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
