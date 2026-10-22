import Base
import ../src/refresh_preferences_cli.bend as Command
import ../src/refresh_preferences.bend as Refresh
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ./refresh_preferences.bend as Fixture

# This is a native worker test of the ready adapter. Shared CLI dispatch is
# deliberately not imported or changed until the integration owner wires it.
def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}: IO.pure(Json.Json,value)
    case Fail{error}: IO.die(Json.Json,1,"FAIL preference worker JSON: " ++ error)

def execute(self: String,args: List<String>) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,"worker" <> args,"",16384,10000))

def success(result: U32 & (String & String),label: String) -> IO(Json.Json):
  (code,(output,err)) = result
  +out : String = output
  do IO<Json.Json>:
    Fixture.assert(U32.is_eq(code,0) && String.is_empty(err) && String.ends_with(out,"\n") &&
      Nat.is_le(String.length(out),256n),label ++ " emits one bounded success JSON line")
    parsed(Json.parse(String.trim(out)))

def good(self: String,args: List<String>,label: String) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- execute(self,args)
    success(result,label)

def failed(result: U32 & (String & String),wanted: String,+label: String) -> IO(Unit):
  (code,(out,error)) = result
  +err : String = error
  do IO<Unit>:
    Fixture.assert(U32.is_eq(code,2) && String.is_empty(out) && Nat.is_le(String.length(err),512n),
      label ++ " exits2 with bounded error and no success output")
    +value : Json.Json <- parsed(Json.parse(String.trim(err)))
    Fixture.assert(String.eq(Json.get(value,"code"),wanted) && Bool.not(String.is_empty(Json.get(value,"error"))),
      label ++ " has the correct structured failure class")
    Fixture.assert(Bool.not(String.contains(err,"private-invalid-sentinel")),label ++ " does not echo stored or supplied content")

def bad(self: String,args: List<String>,wanted: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,args)
    failed(result,wanted,label)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  Fixture.assert(String.eq(Json.encode(Json.field(value,key)),expected),label)

def envelope(+value: Json.Json,enabled: String,seconds: String,milliseconds: String,+label: String) -> IO(Unit):
  do IO<Unit>:
    field(value,"kind","\"refresh_preferences\"",label ++ " has explicit kind")
    field(value,"enabled",enabled,label ++ " enabled is a JSON boolean")
    field(value,"interval_seconds",seconds,label ++ " seconds is a JSON number")
    field(value,"interval_milliseconds",milliseconds,label ++ " milliseconds is an exact JSON number")

def values(+self: String,+db: U32) -> IO(Unit):
  do IO<Unit>:
    initial : Json.Json <- good(self,["refresh-preferences"],"get defaults")
    envelope(initial,"true","30","30000","defaults")
    Fixture.check(db,"SELECT count(*) FROM main.settings","0","worker default read does not write keys")
    saved : Json.Json <- good(self,["refresh-preferences-set","false","86400"],"save daily disabled")
    envelope(saved,"false","86400","86400000","save reply")
    reopened : Json.Json <- good(self,["refresh-preferences"],"get reopened")
    envelope(reopened,"false","86400","86400000","reopened worker")
    second : Json.Json <- good(self,["refresh-preferences-set","true","7200"],"save two hours enabled")
    envelope(second,"true","7200","7200000","second save reply")
    Fixture.check(db,"SELECT count(*) FROM main.settings","2","worker writes only the two namespaced preferences")
    Fixture.check(db,"SELECT typeof(value) FROM main.settings WHERE key='refresh.enabled'","text","boolean persistence uses the specified TEXT encoding")
    Fixture.check(db,"SELECT typeof(value) FROM main.settings WHERE key='refresh.interval_seconds'","text","interval persistence uses the specified TEXT encoding")

def invalid(+self: String,+db: U32) -> IO(Unit):
  do IO<Unit>:
    bad(self,["unknown"],"usage","unknown command")
    bad(self,["refresh-preferences","extra"],"usage","extra get argument")
    bad(self,["refresh-preferences-set","false"],"usage","missing interval argument")
    bad(self,["refresh-preferences-set","false","30","extra"],"usage","extra set argument")
    bad(self,["refresh-preferences-set","1","30"],"invalid_preference","nonboolean argument")
    bad(self,["refresh-preferences-set","false","030"],"invalid_preference","noncanonical interval argument")
    bad(self,["refresh-preferences-set","false","31"],"invalid_preference","unsupported interval argument")
    bad(self,["refresh-preferences-set","private-invalid-sentinel","30"],"invalid_preference","untrusted flag argument")
    Fixture.loaded(db,Refresh.Preferences{True{},Refresh.Hours2{}},"invalid worker arguments cannot change persisted preferences")
    Fixture.put(db,Refresh.enabled_key(),Sql.Cell.Text{"private-invalid-sentinel"})
    bad(self,["refresh-preferences"],"invalid_stored_preference","get invalid stored value")
    bad(self,["refresh-preferences-set","false","30"],"invalid_stored_preference","set invalid existing value")
    Fixture.check(db,"SELECT value FROM main.settings WHERE key='refresh.enabled'","private-invalid-sentinel", "CLI does not silently repair invalid existing values")
    Fixture.put(db,Refresh.enabled_key(),Sql.Cell.Text{"true"})
    Fixture.exec(db,"CREATE TRIGGER fail_interval BEFORE UPDATE ON settings WHEN NEW.key='refresh.interval_seconds' BEGIN SELECT RAISE(FAIL,'synthetic private-invalid-sentinel'); END",[])
    bad(self,["refresh-preferences-set","false","30"],"preference_database_error","database write failure")
    Fixture.loaded(db,Refresh.Preferences{True{},Refresh.Hours2{}},"failed worker write leaves the original pair committed")
    Fixture.exec(db,"DROP TRIGGER fail_interval",[])

def bounds() -> IO(Unit):
  do IO<Unit>:
    Fixture.assert(Nat.is_le(String.length(Command.encode(Refresh.Preferences{False{},Refresh.Daily{}})),255n),
      "largest closed success envelope plus newline fits the 256-byte contract")
    Fixture.assert(String.eq(Command.encode(Refresh.Preferences{False{},Refresh.Live30{}}),
      "{\"kind\":\"refresh_preferences\",\"enabled\":false,\"interval_seconds\":30,\"interval_milliseconds\":30000}"),
      "success envelope has only the agreed fixed typed fields")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    bounds()
    +db : U32 <- Fixture.open(".build/refresh-cli.sqlite")
    values(self,db)
    invalid(self,db)
    Fixture.exec(db,"DROP TABLE main.settings",[])
    bad(self,["refresh-preferences"],"preference_database_error","missing preference table")
    Fixture.check(db,"SELECT count(*) FROM sqlite_master","0","worker does not install missing schema")
    IO.try(Unit,Sql.close(db))

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "worker" <> mode <> rest:
      do IO<Unit>:
        +db : U32 <- IO.try(U32,Sql.open(".build/refresh-cli.sqlite"))
        Command.command(db,mode,rest)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Unsupported refresh preference test mode")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
