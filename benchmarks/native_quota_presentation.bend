import Base
import ../src/gui_quota.bend as G
import ../src/gui_settings.bend as Shape
import ../src/quota_cli.bend as C
import ../src/quota_store.bend as S
import ../src/json.bend as J

# Native acceptance oracle only. Reuses the frozen production presenter and
# strict response decoder; no database/provider/configuration IO or mutation.
# Input is an actual saved synthetic CLI receipt, supplied on bounded stdin.
def answer() -> Data:
  Result<&2,&2,String,String>

def rows(values: List<&2,String>) -> String:
  match values:
    case []: ""
    case [value]: J.quote(value)
    case value <> rest: J.quote(value) ++ "," ++ rows(rest)

def text_envelope(text: String) -> String:
  "{\"text\":" ++ J.quote(text) ++ ",\"rows\":[]}"

def envelope(+model: G.Model,program: String) -> String:
  "{\"text\":" ++ J.quote(G.body(model,program)) ++ ",\"rows\":[" ++ rows(G.rows(model)) ++ "]}"

def fragment(value: C.result_type()) -> answer():
  match value:
    case Done{text}: Done{text_envelope(text)}
    case Fail{_}: Fail{"Expected acknowledged enabled state for exact setup fragment"}

def success_text(kind: String,+model: G.Model,program: String) -> answer():
  match kind:
    case "fragment": fragment(G.setup(model,program))
    case "setup":
      do Result<&2,&2,String,String>:
        Unit <- G.guard(G.can_setup(model))
        return envelope(G.setup_view(model),program)
    case _: Done{envelope(model,program)}

def success(kind: String,program: String,root: String,value: J.Json,+operation: G.Operation) -> answer():
  do Result<&2,&2,String,String>:
    view : S.View <- G.success(value,operation,0n)
    return_result : String <- success_text(kind,G.applied(G.initial(root),view,operation),program)
    return return_result

def unavailable(program: String,root: String,+value: J.Json) -> answer():
  do Result<&2,&2,String,String>:
    Unit <- G.guard(Shape.exact_object(value,["kind","outcome","code","message"]) &&
      Shape.text_is(J.field(value,"kind"),C.protocol()) &&
      Shape.text_is(J.field(value,"outcome"),"error") &&
      Shape.text_is(J.field(value,"code"),"quota_root") && G.bounded(J.field(value,"message"),8192))
    return envelope(G.failed(G.initial(root),G.failure_text("quota_root")),program)

def mode(kind: String,program: String,root: String,value: J.Json) -> answer():
  match kind:
    case "summary": success("summary",program,root,value,G.Status{})
    case "history": success("history",program,root,value,G.History{0})
    case "setup": success("setup",program,root,value,G.Status{})
    case "fragment": success("fragment",program,root,value,G.Status{})
    case "unavailable": unavailable(program,root,value)
    case _: Fail{"Expected summary, history, setup, fragment or unavailable mode"}

def render(+kind: String,+program: String,+root: String,raw: String) -> answer():
  do Result<&2,&2,String,String>:
    Unit <- G.guard(C.path(program) && C.path(root))
    value : J.Json <- G.transport_json(raw,String.eq(kind,"unavailable"),True{})
    text : String <- mode(kind,program,root,value)
    return text

def emit(result: answer()) -> IO(Unit):
  match result:
    case Done{text}: IO.print(text)
    case Fail{message}: IO.die(Unit,2,message)

def input(kind: String,program: String,root: String,value: C.result_type()) -> IO(Unit):
  match value:
    case Done{raw}: emit(render(kind,program,root,raw))
    case Fail{_}: IO.die(Unit,2,"Expected bounded strict UTF8 synthetic receipt on stdin")

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> kind <> program <> root <> []:
      do IO<Unit>:
        value : C.result_type() <- C.stdin()
        input(kind,program,root,value)
    case _: IO.die(Unit,2,"Expected MODE PROGRAM ROOT with actual synthetic CLI receipt on stdin")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
