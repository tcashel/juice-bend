import Base
import ../src/quota_cli.bend as C
import ../src/quota_store.bend as S
import ../src/claude_quota.bend as Q
import ../src/domain.bend as Domain
import ../src/json.bend as Json
import ../src/sql.bend as Sql

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def need(result: C.result_type()) -> IO(String):
  match result:
    case Done{text}: IO.pure(String,text)
    case Fail{Q.Failure{code,message}}: IO.die(String,1,code ++ ": " ++ message)

def fail(result: C.result_type(),wanted: String,label: String) -> IO(Unit):
  match result:
    case Fail{Q.Failure{code,_}}: assert(String.eq(code,wanted),label)
    case Done{_}: assert(False{},label)

def command_name(command: C.Command) -> String:
  match command:
    case C.Status{}: "status"
    case C.Enable{}: "enable"
    case C.Disconnect{}: "disconnect"
    case C.History{offset}: "history:" ++ U32.show(offset)
    case C.Observe{epoch,footer}: "observe:" ++ Nat.show(epoch) ++ ":" ++ C.boolean(footer)

def parsed_name(result: Result<&2,&2,Q.Failure,C.Command>) -> String:
  match result:
    case Done{value}: command_name(value)
    case Fail{Q.Failure{code,_}}: code

def argument_rejected(mode: String,args: List<&2,String>) -> IO(Unit):
  assert(String.eq(parsed_name(C.parse(mode,args)),"quota_usage"),"closed command shape refuses unsupported args")

def arguments() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(parsed_name(C.parse("status",[])),"status"),"status parses without args")
    assert(String.eq(parsed_name(C.parse("history",["32768"])),"history:32768"),"history upper offset is exact")
    assert(String.eq(parsed_name(C.parse("observe-claude",["4294967296"])),"observe:4294967296:false"),"callback epoch remains exact beyond U32")
    assert(String.eq(parsed_name(C.parse("statusline-claude",["1"])),"observe:1:true"),"footer selects quiet rendering of same receiver")
    argument_rejected("enable",["true"])
    argument_rejected("disconnect",["1"])
    argument_rejected("history",["32769"])
    argument_rejected("history",["01"])
    argument_rejected("history",["1.0"])
    argument_rejected("observe-claude",["0"])
    argument_rejected("observe-claude",["281474976710656"])
    argument_rejected("observe-claude",["1","1700000000"])
    argument_rejected("auth",[])

def json_ok(result: Result<&2,&2,String,Json.Json>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def clock_text(result: Result<&2,&2,Q.Failure,Nat>) -> String:
  match result:
    case Done{value}: Nat.show(value)
    case Fail{Q.Failure{code,_}}: code

def transport() -> IO(Unit):
  do IO<Unit>:
    +view : S.View = S.View{S.State{Nat.add(4294967295n,1n),True{}},[
      S.Sample{Nat.add(4294967295n,2n),Nat.add(4294967295n,1n),Nat.add(4294967295n,3n),Q.Observation{Some{Q.QuotaWindow{Some{0},None{}}},Some{Q.QuotaWindow{None{},Some{Nat.add(Nat.mul(253n,1000000000n),402300799n)}}}}}],False{},"status"}
    +text : String = C.encode(view)
    assert(String.eq(text,"{\"kind\":\"claude_quota_v1\",\"outcome\":\"status\",\"enabled\":true,\"epoch\":\"4294967296\",\"samples\":[{\"sequence\":\"4294967297\",\"epoch\":\"4294967296\",\"received_at\":\"4294967298\",\"parser\":\"claude-statusline-v1\",\"five_hour\":{\"used_millionths\":0,\"resets_at\":null},\"seven_day\":{\"used_millionths\":null,\"resets_at\":\"253402300799\"}}],\"more\":false}"),"closed response preserves high IDs, unknowns and zero without float conversion")
    assert(json_ok(Json.parse(text)),"transport is strict JSON")
    assert(String.eq(C.footer(S.View{S.State{1n,True{}},[],False{},"accepted"}),"Juice Bend quota: received locally"),"footer calls receipt local without freshness or account claim")
    assert(String.eq(C.footer(S.View{S.State{1n,True{}},[],False{},"waiting"}),"Juice Bend quota: waiting for limits"),"missing quota is visibly waiting")
    assert(String.eq(clock_text(C.clock_value([[Sql.Cell.Text{"4294967296"}]])),"4294967296"),"clock supports timestamps beyond U32")
    assert(String.eq(clock_text(C.clock_value([[Sql.Cell.Real{"1"}]])),"quota_clock"),"unexpected clock storage type refused")
    assert(String.eq(clock_text(C.clock_value([[Sql.Cell.Text{"253402300800"}]])),"quota_clock"),"clock range is explicit")

def setup_command(command: Json.Json) -> IO(Unit):
  match command:
    case Json.JString{actual}:
      assert(String.eq(actual,"'/Applications/Juice Bend'\"'\"'$(never).app/juice' '--data-dir' '/private/tmp/quota '\"'\"'root'\"'\"'' 'quota' 'statusline-claude' '12'"),"manual config quotes apostrophes and shell-looking text literally")
    case _: assert(False{},"manual config quotes apostrophes and shell-looking text literally")

def json_need(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}: IO.pure(Json.Json,value)
    case Fail{_}: IO.die(Json.Json,1,"FAIL setup JSON")

def setup() -> IO(Unit):
  do IO<Unit>:
    text : String <- need(C.setup("/Applications/Juice Bend'$(never).app/juice","/private/tmp/quota 'root'",12n))
    value : Json.Json <- json_need(Json.parse(text))
    setup_command(Json.field(Json.field(value,"statusLine"),"command"))
    fail(C.setup("relative","/tmp/x",1n),"quota_setup","relative executable refused")
    fail(C.setup("/app","relative",1n),"quota_setup","relative data root refused")
    fail(C.setup("/app\ncommand","/tmp/x",1n),"quota_setup","control characters cannot enter generated command")
    fail(C.setup("/app","/tmp/x",0n),"quota_setup","zero connection epoch cannot generate setup")

def closed(written: File & Result<&1,&1,U32 & String,Unit>) -> IO(Unit):
  (file,result) = written
  do IO<Unit>:
    File.close(file)
    IO.try(Unit,IO.pure(Result<&1,&1,U32 & String,Unit>,result))

def read_bytes(bytes: List<&2,U32>) -> IO(C.result_type()):
  do IO<C.result_type()>:
    file : File <- IO.try(File,File.open("quota-input.bin","w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    closed(written)
    reader : File <- IO.try(File,File.open("quota-input.bin","r"))
    C.read(1048577n,0,[],reader)

def bytes() -> IO(Unit):
  do IO<Unit>:
    +boundary : String = String.repeat("x",4095n) ++ "🙂" ++ String.repeat("x",1044477n)
    result : C.result_type() <- read_bytes(Domain.encode(boundary))
    text : String <- need(result)
    assert(String.eq(text,boundary),"actual byte reader accepts exact1MiB with Unicode split at chunk boundary")
    result : C.result_type() <- read_bytes(Domain.encode(boundary ++ "x"))
    fail(result,"quota_input_limit","actual byte reader refuses byte1048577")
    result : C.result_type() <- read_bytes([255])
    fail(result,"quota_utf8","actual byte reader refuses invalid UTF8")
    result : C.result_type() <- read_bytes([240,159,153])
    fail(result,"quota_utf8","actual byte reader refuses incomplete Unicode at EOF")
    result : C.result_type() <- read_bytes([0])
    text : String <- need(result)
    assert(String.eq(text,"\0"),"strict decoder preserves NUL for JSON parser to reject rather than truncating")

def response(result: S.answer_type()) -> String:
  match result:
    case Fail{problem}: C.error(problem)
    case Done{view}: C.encode(view)

def receiver() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- IO.try(U32,Sql.open(":memory:"))
    result : S.answer_type() <- S.initialize(db)
    text : String <- need(C.encoded(result))
    result : S.answer_type() <- C.dispatch(db,C.Enable{},"")
    text : String <- need(C.encoded(result))
    result : S.answer_type() <- C.receive(db,1n,"{\"session_id\":\"private sentinel\",\"transcript_path\":\"/private/synthetic\",\"rate_limits\":{\"five_hour\":{\"used_percentage\":12.345678,\"resets_at\":4294967296}}}")
    +text : String <- need(C.encoded(result))
    assert(String.contains(text,"12345678") && Bool.not(String.contains(text,"private sentinel")) && Bool.not(String.contains(text,"synthetic")),"real local-clock receiver returns only allowlisted numeric fields")
    result : S.answer_type() <- C.receive(db,1n,"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":\"private sentinel\"}}}")
    +text : String = response(result)
    assert(String.contains(text,"invalid_percentage") && Bool.not(String.contains(text,"private sentinel")),"parser errors never serialize source content")
    result : S.answer_type() <- C.dispatch(db,C.Status{},"")
    text : String <- need(C.encoded(result))
    assert(String.contains(text,"12345678"),"invalid callback leaves previous quota observation intact")
    result : S.answer_type() <- C.dispatch(db,C.Disconnect{},"")
    text : String <- need(C.encoded(result))
    result : S.answer_type() <- C.receive(db,1n,"{\"rate_limits\":{\"five_hour\":{\"used_percentage\":99}}}")
    fail(C.encoded(result),"quota_epoch_retired","CLI delayed callback cannot reactivate disabled epoch")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    arguments()
    transport()
    setup()
    bytes()
    receiver()
