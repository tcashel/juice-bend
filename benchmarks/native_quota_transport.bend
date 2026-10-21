import Base
import ../src/quota_route.bend as Route
import ../src/quota_cli.bend as C
import ../src/gui_quota.bend as Adapter
import ../src/gui_settings.bend as Shape
import ../src/quota_store.bend as Store
import ../src/claude_quota.bend as Quota
import ../src/json.bend as J
import ../src/paths.bend as Paths

def require(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def envelope(+body: J.Json,error: Bool) -> Bool:
  match error:
    case True{}: Shape.exact_object(body,["kind","outcome","code","message"]) &&
      Adapter.bounded(J.field(body,"code"),128) && Adapter.bounded(J.field(body,"message"),8192)
    case False{}: Shape.exact_object(body,["kind","outcome","enabled","epoch","samples","more"])

def zero_history(value: Result<&2,&2,String,Store.View>) -> Bool:
  match value:
    case Done{Store.View{Store.State{1n,False{}},[Store.Sample{1n,1n,receipt,Quota.Observation{Some{Quota.QuotaWindow{Some{0},None{}}},None{}}}],False{},"history"}}:
      Nat.is_gt(receipt,0n)
    case _: False{}

def reply_parts(+code: U32,+out: String,+err: String,expected: U32,outcome: String) -> IO(J.Json):
  +body = parsed(J.parse(Bool.pick(String,U32.is_eq(code,0),out,err)))
  do IO<J.Json>:
    require(U32.is_eq(code,expected) && envelope(body,Bool.not(U32.is_eq(code,0))) && String.eq(J.get(body,"kind"),C.protocol()) &&
      String.eq(J.get(body,"outcome"),outcome) && String.is_empty(Bool.pick(String,U32.is_eq(code,0),err,out)),"actual main emits closed quota protocol on its correct exit channel")
    return body

def reply(value: Result<&1,&1,U32 & String,U32 & (String & String)>,expected: U32,outcome: String) -> IO(J.Json):
  match value:
    case Done{(code,(out,err))}: reply_parts(code,out,err,expected,outcome)
    case _: IO.die(J.Json,1,"FAIL actual main child did not finish")

# The candidate runs with HOME unset to exercise absence of a default app root.
# This does not claim that platform library initialization never consults HOME.
def invoke(program: String,args: List<&2,String>,body: String,expected: U32,outcome: String) -> IO(J.Json):
  do IO<J.Json>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/env","-u" <> "HOME" <> program <> Route.linear(args),body,131072,10000)
    reply(result,expected,outcome)

def absent_result(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Bool:
  match value:
    case Done{(1,("",""))}: True{}
    case _: False{}

def absent(path: String) -> IO(Unit):
  do IO<Unit>:
    value : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",["-e",path],"",1024,2000)
    require(absent_result(value),"quota-only route leaves capture and missing destinations absent")

def made(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(Unit):
  match value:
    case Done{(0,("",""))}: IO.pure(Unit,Unit{})
    case _: IO.die(Unit,1,"FAIL create own new synthetic quota route root")

def scenarios(+program: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    a : J.Json <- invoke(program,["quota","status"],"",2,"error")
    b : J.Json <- invoke(program,["enable"],"",2,"error")
    c : J.Json <- invoke(program,["--data-dir",root,"disconnect"],"",2,"error")
    d : J.Json <- invoke(program,["observe-claude","1"],"",2,"error")
    e : J.Json <- invoke(program,["statusline-claude","1"],"",2,"error")
    f : J.Json <- invoke(program,["--quota","status"],"",2,"error")
    g : J.Json <- invoke(program,["--data-dir",root,"quota"],"",2,"error")
    h : J.Json <- invoke(program,["--data-dir",root,"quota","status"],"",2,"error")
    i : J.Json <- invoke(program,["--data-dir",root,"quota","enable"],"",2,"error")
    absent(root)
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/mkdir",["-m","700",root],"",1024,2000)
    made(result)
    +off : J.Json <- invoke(program,["--data-dir",root,"quota","status"],"",0,"status")
    require(String.eq(J.get(off,"epoch"),"0") && String.eq(J.encode(J.field(off,"enabled")),"false"),"actual missing quota store is acknowledged off with no default data root")
    absent(root ++ "/quota-observations.sqlite")
    absent(root ++ "/juice-bend.sqlite")
    +on : J.Json <- invoke(program,["--data-dir",root,"quota","enable"],"",0,"enabled")
    require(String.eq(J.get(on,"epoch"),"1"),"actual native executable creates explicit enabled epoch1")
    observed : J.Json <- invoke(program,["--data-dir",root,"quota","observe-claude","1"],"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":0}}}",0,"accepted")
    stopped : J.Json <- invoke(program,["--data-dir",root,"quota","disconnect"],"",0,"disconnected")
    +late : J.Json <- invoke(program,["--data-dir",root,"quota","observe-claude","1"],"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":25}}}",2,"error")
    +history : J.Json <- invoke(program,["--data-dir",root,"quota","history","0"],"",0,"history")
    require(String.eq(J.get(late,"code"),"quota_epoch_retired"),"retired epoch callback is rejected with its exact protocol reason")
    require(zero_history(Adapter.success(history,Adapter.History{0},1n)),"known zero remains a typed local observation after disconnect and rejected late callback")
    absent(root ++ "/juice-bend.sqlite")

def capture_reply(value: Result<&1,&1,U32 & String,U32 & (String & String)>,+history: Bool) -> IO(Unit):
  match value:
    case Done{(0,(out,""))}:
      +body = parsed(J.parse(out))
      do IO<Unit>:
        require(String.is_empty(J.get(body,"kind")) &&
          String.eq(J.encode(J.field(body,"columns")),Bool.pick(String,history,
            "[\"source\",\"provider\",\"locator\",\"snapshot\",\"generation\",\"extent\",\"records\",\"excerpt\",\"repository\",\"first_event_ordinal\"]",
            "[\"sources\",\"generations\",\"accepted_snapshots\",\"raw_bytes\",\"projected_events\"]")) &&
          Bool.pick(Bool,history,String.eq(J.encode(J.field(body,"rows")),"[]"),True{}),
          "ordinary capture command keeps its existing response schema")
    case _: IO.die(Unit,1,"FAIL ordinary capture status/history did not finish successfully")

def capture_compatibility(+program: String,+root: String) -> IO(Unit):
  do IO<Unit>:
    absent(root)
    status : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/env",["-u","HOME",program,"--data-dir",root,"status"],"",131072,30000)
    capture_reply(status,False{})
    history : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/env",["-u","HOME",program,"--data-dir",root,"history"],"",131072,30000)
    capture_reply(history,True{})
    absent(root ++ "/quota-observations.sqlite")

def token_chars(text: String) -> Bool:
  match text:
    case SNil{}: True{}
    case SCon{Chr{+c},rest}:
      (((c >= 48 && c <= 57 : U32) || (c >= 65 && c <= 90 : U32) ||
        (c >= 97 && c <= 122 : U32)) && token_chars(rest))

def temporary_prefix(+root: String,+prefix: String) -> Bool:
  String.starts_with(root,prefix) && Nat.is_eq(String.length(root),Nat.add(String.length(prefix),8n)) &&
    token_chars(String.drop(root,String.length(prefix)))

def temporary_shape(+root: String) -> Bool:
  temporary_prefix(root,"/tmp/juice-bend-quota-main.") || temporary_prefix(root,"/private/tmp/juice-bend-quota-main.")

def temporary(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(String):
  match value:
    case Done{(0,(text,""))}:
      +root = String.trim(text)
      do IO<String>:
        require(temporary_shape(root),"OS temporary test root has expected bounded identity")
        return root
    case _: IO.die(String,1,"FAIL create unique private quota main test root")

def run(+program: String) -> IO(Unit):
  do IO<Unit>:
    made : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/mktemp",["-d","/tmp/juice-bend-quota-main.XXXXXXXX"],"",1024,2000)
    created : String <- temporary(made)
    +parent : String <- Paths.resolve(created)
    require(temporary_shape(parent),"fresh OS temporary root canonicalizes to its exact scoped Mac or Linux name")
    +root : String <- Paths.destination(parent ++ "/private")
    absent(root)
    scenarios(program,root)
    capture_compatibility(program,parent ++ "/capture-compatibility")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> program <> []: run(program)
    case _: IO.die(Unit,1,"Expected one exact Juice Bend native candidate executable path")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
