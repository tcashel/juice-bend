import Base
import ../src/cli.bend as Cli
import ../src/relations_cli.bend as Command
import ../src/relations.bend as R
import ../src/scoped_reader.bend as Scoped
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ./relations.bend as Fixture

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{error}:
      IO.die(Json.Json,1,"FAIL relationship CLI JSON: " ++ error)

def execute(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"command" <> args,"",1048576,30000))

def good_result(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    Fixture.assert(U32.is_eq(code,0) && String.is_empty(err),"relationship command succeeds without stderr")
    parsed(Json.parse(String.trim(out)))

def good(self: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- execute(self,args)
    good_result(result)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  Fixture.assert(String.eq(Json.encode(Json.field(value,key)),expected),label)

def bad_result(result: U32 & (String & String),expected: String,+label: String) -> IO(Unit):
  (code,(out,err)) = result
  do IO<Unit>:
    Fixture.assert(U32.is_eq(code,2) && String.is_empty(out),label ++ " fails without success output")
    +value : Json.Json <- parsed(Json.parse(String.trim(err)))
    Fixture.assert(String.eq(Json.get(value,"code"),expected) && Bool.not(String.is_empty(Json.get(value,"error"))),
      label ++ " has an explicit structured error")

def bad(self: String,args: List<String>,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,args)
    bad_result(result,expected,label)

def args(snapshot: String,limit: String,provider: String,repo: String,role: String,after: String) -> List<String>:
  ["relations-scope",snapshot,limit,provider,repo,role,after]

def continuation(reference: R.SnapshotRef,watermark: String,cursor: String,limit: String,
  scope: Scoped.Scope) -> List<String>:
  R.SnapshotRef{provider,source,generation,snapshot,extent} = reference
  Scoped.Scope{filter_provider,repository,role,after} = scope
  ["relations-page",provider,source,generation,snapshot,extent,watermark,cursor,limit,
    filter_provider,repository,role,after]

def count(value: Json.Json) -> Nat:
  List.length(&2,Json.Json,Json.items(Json.field(value,"rows")))

def row_first(rows: List<&2,Json.Json>) -> Json.Json:
  match rows:
    case first <> _:
      first
    case _:
      Json.JNull{}

def first_row(value: Json.Json) -> Json.Json:
  row_first(Json.items(Json.field(value,"rows")))

def parent_id() -> String:
  "parent \"café\" 😀"

def repo() -> String:
  "/synthetic/related café"

def frozen() -> Scoped.Scope:
  Scoped.Scope{"codex",repo(),"tool","2026-10-20"}

def metadata(+value: Json.Json,root: R.SnapshotRef) -> IO(Unit):
  do IO<Unit>:
    field(value,"kind","\"related_captures\"","relationship response kind is explicit")
    field(Json.field(value,"anchor"),"reference",Command.reference_json(root),"anchor carries exact nested immutable reference strings")
    field(value,"scope",Command.scope_json(frozen()),"provider repository role and date scope survive exactly")
    field(value,"requested_limit","16","requested candidate count echoes caller limit")
    field(value,"limit","15","effective candidate bound reserves sixteen anchor records")
    field(value,"after_source","\"0\"","first source cursor is the quoted zero sentinel")
    field(value,"inspected_records","4","record verification count includes the anchor and candidates")
    Fixture.assert(String.contains(Json.get(value,"text"),"Role/date filters are preserved") &&
      String.contains(Json.get(value,"text"),"do not establish global uniqueness or absence"),
      "displayed evidence explains frozen reader scope and page-local ambiguity")
    Fixture.assert(String.contains(Json.get(value,"text"),"longer graph cycles are not detected"),
      "renderer does not claim general graph cycle detection")

def pages(+self: String,+db: U32,+snapshot: String,+child: String) -> IO(Unit):
  do IO<Unit>:
    +root : R.SnapshotRef <- Fixture.resolved(db,snapshot)
    +whole : Json.Json <- good(self,args(snapshot,"16","codex",repo(),"tool","2026-10-20"))
    metadata(whole,root)
    Fixture.assert(Nat.is_eq(count(whole),1n),"role/date filters do not hide recorded relationship metadata")
    +row : Json.Json = first_row(whole)
    field(row,"direction","\"child\"","relationship direction is explicit")
    field(row,"basis","\"recorded_parent_thread_id\"","recorded provider parent basis remains distinct")
    field(row,"record","0","recorded edge cites a physical record rather than an invented event")
    field(row,"ambiguous_on_page","false","lack of observed collision is explicitly page-local")
    +target : Json.Json = Json.field(row,"target")
    field(Json.field(target,"reference"),"snapshot",Json.quote(child),"target is the exact accepted snapshot")
    field(Json.field(target,"session"),"value","\"child\"","target keeps its own actor identity")
    field(Json.field(target,"parent"),"id",Json.quote(parent_id()),"parent identifier preserves quotes and Unicode")
    field(row,"witness",Json.encode(Json.field(target,"reference")),"child metadata has its own complete witness reference")
    field(row,"event","null","event ordinal is not fabricated")
    +first : Json.Json <- good(self,args(snapshot,"1","codex",repo(),"tool","2026-10-20"))
    field(first,"scanned_sources","1","one-candidate limit is honored")
    field(first,"next_source","\"2\"","continuation uses an exact numeric-source cursor string")
    field(first,"inspected_records","2","one candidate plus anchor verification is bounded")
    +watermark : String = Json.get(first,"watermark")
    later : String <- Fixture.capture(db,"codex","after-watermark.jsonl",Fixture.meta("late-child",repo(),parent_id()))
    +tail : Json.Json <- good(self,continuation(root,watermark,Json.get(first,"next_source"),"15",frozen()))
    field(tail,"watermark",Json.quote(watermark),"continuation retains the original accepted-ID watermark")
    field(tail,"scanned_sources","2","newly accepted sources stay outside the fixed watermark")
    field(tail,"next_source","null","end of this frozen source page has no cursor loop")
    Fixture.assert(Nat.is_eq(count(tail),0n) && String.contains(Json.get(tail,"text"),"No related capture was established in this inspected page"),
      "empty rows retain bounded uncertainty rather than claiming no relatives")
    +wrong : Json.Json <- good(self,args(snapshot,"15","codex","/synthetic/unrelated","tool","2026-10-20"))
    Fixture.assert(Nat.is_eq(count(wrong),0n),"exact repository scope does not silently widen")
    bad(self,args(snapshot,"15","claude",repo(),"tool","2026-10-20"),"scope_mismatch","provider mismatch")
    bad(self,continuation(root,"9223372036854775807","0","15",frozen()),"relations_unavailable","missing accepted watermark")
    bad(self,continuation(root,watermark,"01","15",frozen()),"relations_unavailable","noncanonical source cursor")
    bad(self,continuation(R.SnapshotRef{"codex","/wrong/source","1",snapshot,"1"},watermark,"0","15",frozen()),
      "relations_unavailable","forged anchor descriptor")

def invalid(+self: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    bad(self,["relations-scope"],"usage","missing open arguments")
    bad(self,["relations-page","extra"],"usage","missing continuation arguments")
    bad(self,args("0","15","","","",""),"relations_unavailable","zero snapshot")
    bad(self,args("01","15","","","",""),"relations_unavailable","noncanonical snapshot")
    bad(self,args("999","15","","","",""),"relations_unavailable","missing accepted snapshot")
    bad(self,args(snapshot,"0","","","",""),"relations_unavailable","zero candidate limit")
    bad(self,args(snapshot,"17","","","",""),"relations_unavailable","candidate limit above bound")
    bad(self,args(snapshot,"4294967296","","","",""),"invalid_number","overflowing candidate limit")
    bad(self,args(snapshot,"x","","","",""),"invalid_number","nonnumeric candidate limit")
    bad(self,args(snapshot,"15","other","","",""),"invalid_scope","unknown provider scope")
    bad(self,args(snapshot,"15","","/synthetic/../repo","",""),"invalid_scope","noncanonical repository scope")
    bad(self,args(snapshot,"15","","","other",""),"invalid_scope","unknown role scope")
    bad(self,args(snapshot,"15","","","","2026-02-30"),"invalid_scope","invalid calendar date")

def large_reference() -> R.SnapshotRef:
  R.SnapshotRef{"codex","/synthetic/retained \"café\".jsonl","9007199254740993","9007199254740995","4294967295"}

def pure_page(next: Maybe<&2,String>,scanned: U32) -> R.Page:
  R.Page{R.Facts{large_reference(),R.Known{"actor",0},R.Known{repo(),0},R.UnknownParent{},1,1,100,True{},""},
    "","9007199254740996","0",next,15,scanned,1,100,R.Coverage{0,0,0,0,0},[]}

def encoded(value: Result<&2,&2,String,String>) -> IO(Json.Json):
  do IO<Json.Json>:
    text : String <- Fixture.need(String,value)
    parsed(Json.parse(text))

def refused(value: Result<&2,&2,String,String>,label: String) -> IO(Unit):
  match value:
    case Fail{message}:
      Fixture.assert(Bool.not(String.is_empty(message)),label)
    case Done{_}:
      IO.die(Unit,1,"FAIL " ++ label)

def pure() -> IO(Unit):
  +scope = {Scoped.Scope{"","","",""} : Scoped.Scope}
  do IO<Unit>:
    +value : Json.Json <- encoded(Command.encode(pure_page(None{},0),scope,16,"quoted \"text\"\n😀"))
    field(Json.field(Json.field(value,"anchor"),"reference"),"generation","\"9007199254740993\"",">2^53 generation remains an exact string")
    field(Json.field(Json.field(value,"anchor"),"reference"),"snapshot","\"9007199254740995\"",">2^53 snapshot remains an exact string")
    field(Json.field(Json.field(value,"anchor"),"reference"),"extent","\"4294967295\"","maximum captured extent remains an exact string")
    field(value,"text",Json.quote("quoted \"text\"\n😀"),"Unicode and controls survive complete-envelope encoding")
    refused(Command.encode(pure_page(None{},0),scope,16,String.repeat("\"",524288n)),"escaped envelope budget includes outer fields and trailing newline")
    refused(Command.encode(pure_page(Some{"0"},15),scope,16,""),"nonadvancing source cursor is rejected")
    refused(Command.encode(pure_page(None{},16),scope,16,""),"more scanned candidates than effective bound is rejected")
    refused(Command.encode(pure_page(None{},0),Scoped.Scope{"claude","","",""},16,""),"encoding cannot silently clear a mismatched provider")
    conflict : Json.Json <- parsed(Json.parse(Command.identity_json(R.Conflicting{"retained conflict"})))
    field(conflict,"kind","\"conflicting\"","identity conflict remains a tagged JSON state")

def moved(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  Fixture.assert(U32.is_eq(code,0),"synthetic source relocation succeeded")

def retained(+self: String,+db: U32,+root: String,+child: String) -> IO(Unit):
  do IO<Unit>:
    +reference : R.SnapshotRef <- Fixture.resolved(db,child)
    +source : String = R.ref_source(reference)
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/mv",[source,source ++ ".moved"],"",8192,30000))
    moved(result)
    +page : Json.Json <- good(self,args(child,"15","codex",repo(),"user","2026-10-20"))
    Fixture.assert(String.eq(Json.get(first_row(page),"direction"),"parent"),"parent navigation remains available after source relocation")
    +watermark : String = Json.get(page,"watermark")
    rewritten : String <- Fixture.capture(db,"codex",source,Fixture.meta("rewritten",repo(),""))
    +old : Json.Json <- good(self,continuation(reference,watermark,"0","15",Scoped.Scope{"codex",repo(),"user","2026-10-20"}))
    field(Json.field(old,"anchor"),"reference",Command.reference_json(reference),"old anchor remains pinned after source rewrite")
    Fixture.assert(String.eq(Json.get(first_row(old),"direction"),"parent"),"historical relationship still comes from retained first-header bytes")

def ambiguous_count(rows: List<&2,Json.Json>) -> U32:
  match rows:
    case []:
      0
    case row <> rest:
      U32.add(Bool.to_u32(String.eq(Json.get(row,"ambiguous_on_page"),"true")),ambiguous_count(rest))

def ambiguity(+self: String,+db: U32,root: String) -> IO(Unit):
  do IO<Unit>:
    duplicate : String <- Fixture.capture(db,"codex","duplicate-child.jsonl",Fixture.meta("child",repo(),parent_id()))
    +value : Json.Json <- good(self,args(root,"15","codex",repo(),"",""))
    Fixture.assert(U32.is_eq(ambiguous_count(Json.items(Json.field(value,"rows"))),2),
      "duplicate captured actor IDs survive as two page-ambiguous navigation rows")
    Fixture.assert(String.contains(Json.get(value,"text"),"ambiguity observed in this page"),
      "copyable text preserves observed ambiguity instead of choosing a unique actor")

def created(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  Fixture.assert(U32.is_eq(code,0),"synthetic Claude subagent fixture directory created")

def path_association(+self: String,+db: U32) -> IO(Unit):
  do IO<Unit>:
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-p","claude/parent/subagents"],"",8192,30000))
    created(made)
    +root : String <- Fixture.capture(db,"claude","claude/parent.jsonl",Fixture.claude("raw-parent",repo()))
    +child : String <- Fixture.capture(db,"claude","claude/parent/subagents/agent-café.jsonl",Fixture.claude("raw-parent",repo()))
    +value : Json.Json <- good(self,args(root,"15","claude",repo(),"assistant","2026-10-20"))
    Fixture.assert(Nat.is_eq(count(value),1n),"retained Claude path association appears in the command envelope")
    +row : Json.Json = first_row(value)
    field(row,"basis","\"retained_path_association\"","path evidence remains distinct from recorded parent metadata")
    field(row,"record","null","path association does not invent a raw record witness")
    +target : Json.Json = Json.field(row,"target")
    field(Json.field(target,"session"),"value","\"raw-parent\"","Claude child keeps its raw parent-named session identity")
    field(Json.field(target,"parent"),"kind","\"path_associated\"","parent evidence is explicitly tagged as a path association")
    field(Json.field(target,"parent"),"child_alias",Json.quote("parent/agent-café"),"path actor alias stays separate from raw session identity")
    field(Json.field(target,"reference"),"snapshot",Json.quote(child),"path navigation pins the child accepted snapshot")
    +root_ref : R.SnapshotRef <- Fixture.resolved(db,root)
    field(Json.field(target,"parent"),"locator",Json.quote(R.ref_source(root_ref)),"path association names only the exact captured parent locator")
    Fixture.assert(String.contains(Json.get(value,"text"),"Path associations do not prove a recorded session parent"),
      "copyable evidence keeps the path-association limitation")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    pure()
    +db : U32 <- Store.open(".build/relations-cli.sqlite")
    +root : String <- Fixture.capture(db,"codex","root \"café\".jsonl",Fixture.meta(parent_id(),repo(),""))
    +child : String <- Fixture.capture(db,"codex","child.jsonl",Fixture.meta("child",repo(),parent_id()))
    unrelated : String <- Fixture.capture(db,"codex","other.jsonl",Fixture.meta("other",repo(),""))
    unknown : String <- Fixture.capture(db,"codex","unknown.jsonl","{\"type\":\"event_msg\"}\n")
    pages(self,db,root,child)
    invalid(self,root)
    ambiguity(self,db,root)
    retained(self,db,root,child)
    path_association(self,db)
    +help : Json.Json <- good(self,["help"])
    Fixture.assert(String.contains(Json.encode(Json.field(help,"commands")),"relations-scope SNAPSHOT LIMIT") &&
      String.contains(Json.encode(Json.field(help,"commands")),"relations-page PROVIDER SOURCE GENERATION SNAPSHOT EXTENT WATERMARK AFTER_SOURCE LIMIT"),
      "production CLI help exposes both relationship commands")
    IO.try(Unit,Sql.close(db))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []:
      suite(self)
    case _ <> "command" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/relations-cli.sqlite")
        Cli.command(db,"",command,rest)
        IO.try(Unit,Sql.close(db))
    case _:
      IO.die(Unit,2,"Unsupported relationship CLI test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
