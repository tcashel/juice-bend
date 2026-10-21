# Native app/CLI integration harness. Run with no args only in a fresh private cwd
# containing .build. Other arguments run the actual Main.argv path, including GUI.
import Base
import ./polish.bend as Polish
import ./ui.bend as UiTests
import ../src/main.bend as Main
import ../src/gui_brief.bend as Model
import ../src/query.bend as Query
import ../src/json.bend as Json
import ../src/store.bend as Store
import ../src/paths.bend as Paths

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}: IO.pure(Json.Json,value)
    case Fail{message}: IO.die(Json.Json,1,"FAIL invalid native JSON " ++ message)

def result_ok(result: U32 & (String & String)) -> IO(String):
  (code,(out,err)) = result
  do IO<String>:
    require(U32.is_eq(code,0) && String.is_empty(err),"native command exits0 without stderr")
    return out

def process(program: String,args: List<String>,body: String) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(program,args,body,65536,30000))

def command_done(result: U32 & (String & String)) -> IO(Unit):
  (code,(_,err)) = result
  require(U32.is_eq(code,0),"synthetic fixture command " ++ err)

def command(program: String,args: List<String>) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- process(program,args,"")
    command_done(result)

def git(args: List<String>) -> IO(Unit):
  command("/usr/bin/git","-c" <> "commit.gpgSign=false" <> "-c" <> "tag.gpgSign=false" <> "-c" <> "core.fsmonitor=false" <> "-c" <> "core.hooksPath=/dev/null" <> "-c" <> "core.attributesFile=/dev/null" <> args)

def call(self: String,args: List<String>,body: String) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- process(self,"--data-dir" <> ".build/library" <> args,body)
    text : String <- result_ok(result)
    parsed(Json.parse(text))

def refused_result(result: U32 & (String & String),label: String) -> IO(Unit):
  (code,(out,err)) = result
  require(Bool.not(U32.is_eq(code,0)) && String.is_empty(out),label)

def refused(self: String,args: List<String>,body: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- process(self,"--data-dir" <> ".build/library" <> args,body)
    refused_result(result,label)

def record(repo: String,role: String,text: String) -> String:
  "{\"type\":" ++ Json.quote(role) ++ ",\"cwd\":" ++ Json.quote(repo) ++ ",\"sessionId\":\"brief-ui-native-synthetic\",\"message\":{\"content\":" ++ Json.quote(text) ++ "}}\n"

def preview(result: Result<&2,&2,String,Model.Preview>) -> IO(Model.Preview):
  match result:
    case Done{value}: IO.pure(Model.Preview,value)
    case Fail{message}: IO.die(Model.Preview,1,"FAIL GUI could not admit native preview " ++ message)

def read_closed(got: File & Result<&1,&1,U32 & String,String>) -> IO(String):
  (file,result) = got
  do IO<String>:
    File.close(file)
    IO.try(String,IO.pure(Result<&1,&1,U32 & String,String>,result))

def read(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,String> <- File.read(file,16384)
    read_closed(got)

def exact_export(+self: String,+text: String) -> IO(Unit):
  do IO<Unit>:
    +ack : Json.Json <- call(self,["export-brief-text",".build/brief.txt"],text)
    require(String.eq(Json.get(ack,"kind"),"continuation_brief_text") && String.eq(Json.get(ack,"exact_supplied_text"),"true"),"exact brief sink acknowledges supplied text without new verification claim")
    copied : String <- read(".build/brief.txt")
    require(String.eq(copied,text),"brief export is byte-equivalent Unicode text without displayed-evidence header")
    permissions : U32 & (String & String) <- process("/usr/bin/stat",["-f","%Lp",".build/brief.txt"],"")
    mode : String <- result_ok(permissions)
    require(String.eq(mode,"600\n"),"exact brief export is private mode0600")
    refused(self,["export-brief-text",".build/brief.txt"],"replacement","existing brief export cannot be overwritten")
    kept : String <- read(".build/brief.txt")
    require(String.eq(kept,text),"no-clobber refusal preserves prior exact bytes")
    refused(self,["export-brief-text",".build/too-large.txt"],String.repeat("x",8193n),"8193-byte brief text cannot reach export")
    refused(self,["export-brief-text",".build/empty.txt"],"","empty brief text cannot reach export")
    refused(self,["export-brief-text",".build/nul.txt"],"x\0y","NUL brief text cannot reach export")

def brief(+self: String,+repo: String,+snapshot: String) -> IO(Unit):
  +model = {Model.Model{Model.Anchor{snapshot,0,2,Query.Filters{"","claude",repo,"",""}},repo,1,1,None{},Model.Whole{}} : Model.Model}
  do IO<Unit>:
    +prepared : Json.Json <- call(self,["brief-prepare"],Model.body(model))
    +value : Model.Preview <- preview(Model.decode(prepared,model))
    require(String.contains(Model.preview_text(value),"café 中文 🙂"),"native prepared preview retains eligible Unicode request")
    +checking : Model.Model <- IO.pure(Model.Model,Model.checking(Model.ready(model,value),False{},Model.Whole{}))
    +checked : Json.Json <- call(self,["brief-check"],Model.body(checking))
    accepted : Model.Preview <- preview(Model.decode(checked,checking))
    require(String.eq(Model.preview_text(accepted),Model.preview_text(value)),"real CLI check and GUI decoder bind the full exact prepared text")
    refused(self,["brief-prepare","unexpected"],Model.body(model),"prepare argv cannot bypass stdin-only shape")
    refused(self,["brief-check"],Model.body(model),"prepare body cannot authorize check")
    exact_export(self,Model.preview_text(value))

def captured(+self: String,+repo: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +page : Json.Json <- call(self,["session-scope",snapshot,"0","40","claude",repo,"",""],"")
    require(Model.range_metadata(page,snapshot,0) && String.eq(Json.get(page,"selected_records"),"2") && String.eq(Json.get(page,"requested_records"),"40"),"native scoped transport distinguishes exact physical count2 from requested40")
    +empty : Json.Json <- call(self,["session-scope",snapshot,"2","40","claude",repo,"",""],"")
    require(Model.range_metadata(empty,snapshot,2) && U32.is_eq(Model.selected_count(Model.range_args(empty,snapshot,2,[]),snapshot,2),0),"native empty range retains reading metadata but cannot enable brief")
    brief(self,repo,snapshot)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    Polish.status_tests()
    UiTests.tests()
    UiTests.buttons()
    command("/bin/mkdir",["-m","700",".build/repository café"])
    git(["init","-q",".build/repository café"])
    Store.write_text(".build/repository café/README","w","Synthetic brief UI fixture\n")
    git(["-C",".build/repository café","add","README"])
    git(["-C",".build/repository café","-c","user.name=Synthetic Fixture","-c","user.email=fixture@example.invalid","commit","-qm","synthetic initial"])
    +repo : String <- Paths.resolve(".build/repository café")
    Store.write_text(".build/source.jsonl","w",record(repo,"user","Continue synthetic café 中文 🙂 work.") ++ record(repo,"assistant","Recorded synthetic result."))
    imported : Json.Json <- call(self,["import","claude",".build/source.jsonl"],"")
    captured(self,repo,Json.get(imported,"accepted_snapshot"))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case other: Main.argv(other)

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
