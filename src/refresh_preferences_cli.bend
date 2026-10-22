import Base
import ./refresh_preferences.bend as Refresh
import ./json.bend as Json

# Closed commands only. No arbitrary settings key, SQL, path, source operation,
# or caller-owned transaction is accepted. The backend owns its transaction.
def failure(-A: Type,error: Refresh.Failure) -> IO(A):
  Refresh.Failure{code,message} = error
  IO.die(A,2,"{\"error\":" ++ Json.quote(message) ++ ",\"code\":" ++ Json.quote(code) ++ "}")

def require(result: Result<&2,&2,Refresh.Failure,Refresh.Preferences>) -> IO(Refresh.Preferences):
  match result:
    case Done{preferences}: IO.pure(Refresh.Preferences,preferences)
    case Fail{error}: failure(Refresh.Preferences,error)

# All output fields have closed values and this complete JSON is below 256
# ASCII bytes, including IO.print's newline. No paths or stored values echo.
def encode(preferences: Refresh.Preferences) -> String:
  Refresh.Preferences{enabled,+interval} = preferences
  "{\"kind\":\"refresh_preferences\",\"enabled\":" ++ Refresh.enabled_text(enabled) ++
    ",\"interval_seconds\":" ++ U32.show(Refresh.seconds(interval)) ++
    ",\"interval_milliseconds\":" ++ Nat.show(Refresh.milliseconds(interval)) ++ "}"

def get(db: U32) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.load(db)
    preferences : Refresh.Preferences <- require(result)
    IO.print(encode(preferences))

def set(db: U32,enabled: String,interval: String) -> IO(Unit):
  do IO<Unit>:
    preferences : Refresh.Preferences <- require(Refresh.parse(enabled,interval))
    result : Result<&2,&2,Refresh.Failure,Refresh.Preferences> <- Refresh.save(db,preferences)
    saved : Refresh.Preferences <- require(result)
    IO.print(encode(saved))

def command(db: U32,mode: String,args: List<String>) -> IO(Unit):
  match mode args:
    case "refresh-preferences" Nil{}: get(db)
    case "refresh-preferences-set" Con{enabled,Con{interval,Nil{}}}: set(db,enabled,interval)
    case _ _: failure(Unit,Refresh.Failure{"usage","usage: refresh-preferences | refresh-preferences-set true|false SECONDS; SECONDS is 30, 7200, 14400, 28800, or 86400"})
