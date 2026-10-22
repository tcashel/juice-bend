import Base
import ../src/client.bend as Client
import ../src/json.bend as Json
import ../src/sql.bend as Sql

def failure(value: Result<&2,&2,String,Json.Json>) -> Bool:
  match value:
    case Fail{message}:
      Bool.not(String.is_empty(message))
    case Done{value}:
      False{}

def rows_failure(value: Result<&2,&2,String,List<&2,List<&2,Sql.Cell>>>) -> Bool:
  match value:
    case Fail{message}:
      True{}
    case Done{value}:
      False{}

def text_failure(value: Result<&2,&2,String,String>) -> Bool:
  match value:
    case Fail{message}:
      True{}
    case Done{value}:
      False{}

def require(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def main() -> IO(Unit):
  do IO<Unit>:
    require(U32.is_eq(Client.timeout_ms(["session-usage","9007199254740993"]),120000),
      "whole-capture usage receives the bounded longer worker deadline")
    require(U32.is_eq(Client.timeout_ms(["session-usage","1","extra"]),10000) &&
      U32.is_eq(Client.timeout_ms(["session-usage"]),10000),
      "malformed usage command shapes keep the ordinary worker deadline")
    require(U32.is_eq(Client.timeout_ms(["session","1","0","40"]),10000) &&
      U32.is_eq(Client.timeout_ms(["usage","1"]),10000) &&
      U32.is_eq(Client.timeout_ms(["status"]),10000),
      "paged reads and other workers retain their original deadline")
    missing : Result<&2,&2,String,Json.Json> <- Client.call("/juice-bend-test-missing-executable","/tmp/juice-bend-client-test",["status"])
    require(failure(missing),"missing worker executable returns data instead of terminating GUI")
    nonzero : Result<&2,&2,String,Json.Json> <- Client.call("/usr/bin/false","/tmp/juice-bend-client-test",["status"])
    require(failure(nonzero),"nonzero worker status remains an explicit failure")
    empty : Result<&2,&2,String,Json.Json> <- Client.call("","/tmp/juice-bend-client-test",["status"])
    require(failure(empty),"missing program identity fails before launch")
    require(failure(Client.completed(Done{(0,("not JSON",""))})),"malformed successful worker output is rejected")
    require(rows_failure(Client.rows_result(Done{Json.JObject{[]}})),"missing rows field is rejected")
    require(text_failure(Client.text_result(Done{Json.JObject{[]}})),"missing text field is rejected")
