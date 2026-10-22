import Base
import ../src/store.bend as Store
import ../src/providers.bend as Providers

def require(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def main() -> IO(Unit):
  +shown = Store.display_event(Providers.ProviderEvent{"assistant","Café é 中文 😀",
    "Write","call-1","{\"path\":\"x\"}","recorded result","/synthetic/repo",
    "session","2026-10-20T00:00:00Z","recorded-model",
    "{\"input_tokens\":9007199254740993}","parent-session","partial_content"})
  +unknown = Store.display_event(Providers.ProviderEvent{"user","request",
    "","","","","","","","","","","complete"})
  do IO<Unit>:
    require(String.contains(shown,"Tool: Write") && String.contains(shown,"Call ID: call-1"),
      "tool name and call identity have separate labels")
    require(String.contains(shown,"Arguments: {\"path\":\"x\"}") &&
      String.contains(shown,"Result: recorded result"),"complete tool fields remain visible")
    require(String.contains(shown,"9007199254740993") &&
      String.contains(shown,"mirrors are not additive"),"usage retains exact recorded quantities without a false total")
    require(String.contains(shown,"Recorded model: recorded-model") &&
      String.contains(shown,"Parent reference: parent-session"),"model and parent facts remain visible")
    require(String.contains(shown,"Café é 中文 😀") &&
      String.contains(shown,"Coverage: partial_content"),"display text retains Unicode and coverage")
    require(String.contains(unknown,"time not captured") &&
      Bool.not(String.contains(unknown,"tokens")),"missing recorded facts are not invented as zeros")
