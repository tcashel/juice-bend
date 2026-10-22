import Base
import ../src/brief_cli.bend as A
import ../src/continuation_brief.bend as B
import ./continuation_brief.bend as F
import ../src/domain.bend as Domain
import ../src/json.bend as Json
import ../src/scoped_reader.bend as Scoped
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/maintenance.bend as Maintenance
import ../src/paths.bend as Paths

# Native synthetic harness. Run only in a newly-created private cwd with .build.
# It never discovers a source or touches an existing library/repository.
def accepted(value: Result<&2,&2,B.Problem,A.Command>) -> Bool:
  match value:
    case Done{_}: True{}
    case Fail{_}: False{}

def input() -> B.Input:
  B.Input{"9007199254740995",0,3,Scoped.Scope{"claude","/synthetic/repository","user","2026-10-21"},"/synthetic/repository"}

def fields(values: List<&2,Json.Field>,+key: String,+value: Json.Json) -> List<&2,Json.Field>:
  match values:
    case []: []
    case Json.JField{+name,prior} <> rest:
      Json.JField{name,Bool.pick(Json.Json,String.eq(name,key),value,prior)} <> fields(rest,key,value)

def replace(value: Json.Json,key: String,next: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{fields(values,key,next)}
    case other: other

def extra(value: Json.Json,key: String,next: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{values}: Json.JObject{Json.JField{key,next} <> values}
    case other: other

def input_field(+request: Json.Json,key: String,next: Json.Json) -> Json.Json:
  replace(request,"input",replace(Json.field(request,"input"),key,next))

def scope_field(+request: Json.Json,key: String,next: Json.Json) -> Json.Json:
  +anchor = Json.field(request,"input")
  replace(request,"input",replace(anchor,"scope",replace(Json.field(anchor,"scope"),key,next)))

def refused(value: Json.Json) -> Bool:
  F.failed(A.Command,A.parsed_operation("brief-prepare",value),"invalid_request")

def invalid_values(values: List<&2,String>,+request: Json.Json,+key: String,+index: U32) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        F.assert(refused(input_field(request,key,Json.JString{value})),"noncanonical " ++ key ++ " rejected " ++ U32.show(index))
        invalid_values(rest,request,key,U32.inc(index))

def pure_shape(+request: Json.Json) -> IO(Unit):
  do IO<Unit>:
    F.assert(accepted(A.parsed_operation("brief-prepare",request)),"canonical prepare preserves exact wide snapshot strings")
    F.assert(F.failed(A.Command,A.parse("brief-check",A.prepare_request(input())),"invalid_request"),"prepare envelope cannot be used for check")
    F.assert(F.failed(A.Command,A.parsed_operation("brief-prepare",replace(request,"protocol",Json.JString{"other"})),"protocol"),"unknown protocol rejected")
    F.assert(F.failed(A.Command,A.parse("other",A.prepare_request(input())),"usage"),"unknown operation rejected")
    F.assert(refused(extra(request,"unexpected",Json.JNull{})),"unknown top field rejected")
    F.assert(refused(extra(request,"input",Json.field(request,"input"))),"constructed duplicate input field rejected")
    F.assert(F.failed(A.Command,A.parse("brief-prepare","{\"protocol\":\"a\",\"protocol\":\"b\",\"input\":{}}"),"invalid_json"),"parsed duplicate field rejected")
    F.assert(refused(input_field(request,"snapshot",Json.JNumber{"9007199254740995"})),"numeric snapshot rejected before rounding")
    F.assert(refused(input_field(request,"start",Json.JNumber{"0"})),"numeric start rejected")
    F.assert(refused(input_field(request,"count",Json.JNumber{"3"})),"numeric count rejected")
    F.assert(refused(replace(request,"input",Json.JNull{})),"missing input fields rejected")
    F.assert(refused(input_field(request,"scope",Json.JObject{[]})),"missing scope fields rejected")
    F.assert(refused(input_field(request,"scope",extra(Json.field(Json.field(request,"input"),"scope"),"extra",Json.JString{"x"}))),"unknown scope field rejected")
    F.assert(refused(scope_field(request,"provider",Json.JString{"other"})),"unsupported provider rejected")
    F.assert(refused(scope_field(request,"role",Json.JString{"other"})),"unsupported role rejected")
    F.assert(refused(scope_field(request,"after",Json.JString{"2026-99-99"})),"invalid frozen date rejected")
    F.assert(refused(input_field(request,"repository",Json.JString{"relative"})),"implicit relative checkout rejected")
    F.assert(refused(input_field(request,"repository",Json.JString{"/a/../b"})),"traversal checkout rejected")
    F.assert(refused(input_field(request,"repository",Json.JString{"/a\0b"})),"NUL checkout rejected")
    invalid_values(["","0","01","-1","+1","1.0","1e2","9223372036854775808"],request,"snapshot",0)
    invalid_values(["","01","-1","+1","1.0","1e2","4294967296"],request,"start",0)
    invalid_values(["","0","01","101","-1","4294967296"],request,"count",0)

def bounds(+long_path: String,+escaped_path: String,+text: String) -> IO(Unit):
  +wide = {B.Input{"9223372036854775807",4294967295,100,Scoped.Scope{"codex",long_path,"assistant","2026-10-21"},long_path} : B.Input}
  +escaped = {B.Input{"9223372036854775807",4294967295,100,Scoped.Scope{"codex",escaped_path,"assistant","2026-10-21"},escaped_path} : B.Input}
  +wire = A.check_request(escaped,String.repeat("a",64n),text)
  do IO<Unit>:
    F.assert(A.valid_input(wide),"4096 scalar path accepted with exact high numeric limits")
    F.assert(Bool.not(A.valid_input(B.Input{"1",0,1,F.all(),long_path ++ "x"})),"4097 scalar path rejected")
    F.assert(accepted(A.parse("brief-check",wire)),"worst escape canonical input plus8192 byte text fits transport")
    F.assert(U32.is_lt(U32.from_nat(List.length(&2,U32,Domain.encode(wire))),A.stdin_limit()),"independent encoded worst-case check request below131072 bytes")
    F.assert(accepted(A.parse("brief-check",A.check_request(input(),String.repeat("a",64n),String.repeat("😀",2048n)))),"8192 decoded multibyte text accepted")
    F.assert(F.failed(A.Command,A.parse("brief-check",A.check_request(input(),String.repeat("a",64n),String.repeat("😀",2048n) ++ "x")),"invalid_request"),"8193 decoded multibyte text rejected")
    F.assert(F.failed(A.Command,A.parse("brief-check",A.check_request(input(),String.repeat("A",64n),"text")),"invalid_request"),"uppercase token rejected")
    F.assert(F.failed(A.Command,A.parse("brief-check",A.check_request(input(),String.repeat("a",63n),"text")),"invalid_request"),"short token rejected")
    F.assert(F.failed(A.Command,A.parse("brief-check",A.check_request(input(),String.repeat("a",63n) ++ "g","text")),"invalid_request"),"nonhex token rejected")
    F.assert(F.failed(A.Command,A.parse("brief-prepare",String.repeat("x",131073n)),"input_limit"),"wire byte cap checked before JSON")
    F.assert(F.failed(A.Command,A.parse("brief-prepare",SCon{Chr{55296},SNil{}}),"input_limit"),"constructed invalid Unicode rejected before parser")

def mutation_commitments(values: List<&2,B.Preview>,+fresh: B.Preview,+index: U32) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case +value <> rest:
      do IO<Unit>:
        F.assert(Bool.not(String.eq(A.commitment(value),A.commitment(fresh))) &&
          F.failed(String,A.checked(Done{fresh},A.commitment(value),F.body(fresh)),"stale"),
          "full retained Preview mutation changes transport commitment " ++ U32.show(index))
        mutation_commitments(rest,fresh,U32.inc(index))

def commitment_tests(+preview: B.Preview) -> IO(Unit):
  do IO<Unit>:
    +prepared : String <- F.need(String,A.prepared(Done{preview}))
    +value : Json.Json = F.raw(prepared)
    F.assert(A.shape(value,["protocol","kind","snapshot","start","count","commitment","text","utf8_bytes"]),"prepared response has eight closed fields")
    F.assert(String.eq(Json.get(value,"text"),F.body(preview)) && String.eq(Json.get(value,"snapshot"),"9007199254740995"),"response retains exact preview and wide snapshot")
    F.assert(Bool.not(String.contains(prepared,"/synthetic/source.jsonl")) && Bool.not(String.contains(prepared,"/synthetic/repository")),"transport response withholds private source and Input repository")
    F.assert(String.contains(F.body(preview),"Dedicated session, parent and usage fields"),"new literal describes dedicated omitted fields")
    +checked : String <- F.need(String,A.checked(Done{preview},A.commitment(preview),F.body(preview)))
    F.assert(String.eq(Json.get(F.raw(checked),"kind"),"checked") && String.eq(Json.get(F.raw(checked),"text"),F.body(preview)),"exact prepared commitment and text accepted")
    F.assert(F.failed(String,A.checked(Done{preview},A.commitment(preview),F.body(preview) ++ "x"),"stale"),"text mismatch refused even with matching full token")
    F.assert(F.failed(String,A.checked(Done{preview},String.repeat("0",64n),F.body(preview)),"stale"),"token mismatch refused with unchanged text")
    mutation_commitments(F.mutations(preview),preview,0)
    F.assert(Bool.not(String.eq(A.commitment(F.changed_ref(preview,F.descriptor(1,9))),A.commitment(preview))),"redundant reference event participates in transport token")
    F.assert(F.failed(String,A.bounded_response(String.repeat("x",32768n)),"output_limit"),"response reserves newline inside32768 byte envelope")
    response : String <- F.need(String,A.bounded_response(String.repeat("x",32767n)))
    F.assert(Nat.is_eq(String.length(response),32767n),"exact response envelope bound accepted")

# Same production byte reader as stdin, exercised with actual byte files so
# invalid UTF8 can be supplied without an upstream string encoder intervening.
def read_bytes(+bytes: List<&2,U32>) -> IO(Result<&2,&2,B.Problem,String>):
  do IO<Result<&2,&2,B.Problem,String>>:
    file : File <- IO.try(File,File.open("bytes.bin","w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(written)
    reader : File <- IO.try(File,File.open("bytes.bin","r"))
    A.read(131073n,0,[],reader)

def bytes_tests() -> IO(Unit):
  do IO<Unit>:
    +boundary : String = String.repeat("x",4095n) ++ "😀" ++ String.repeat("x",126973n)
    edge : Result<&2,&2,B.Problem,String> <- read_bytes(Domain.encode(boundary))
    value : String <- F.need(String,edge)
    F.assert(String.eq(value,boundary),"strict byte reader accepts exact131072 with UTF8 spanning chunk boundary")
    over : Result<&2,&2,B.Problem,String> <- read_bytes(Domain.encode(boundary ++ "x"))
    F.assert(F.failed(String,over,"input_limit"),"byte reader refuses131073rd byte")
    bad : Result<&2,&2,B.Problem,String> <- read_bytes([255])
    F.assert(F.failed(String,bad,"invalid_utf8"),"byte reader rejects invalid UTF8")
    truncated : Result<&2,&2,B.Problem,String> <- read_bytes([240,159,152])
    F.assert(F.failed(String,truncated,"invalid_utf8"),"byte reader rejects truncated UTF8 at EOF")
    empty : Result<&2,&2,B.Problem,String> <- read_bytes([])
    value : String <- F.need(String,empty)
    F.assert(String.is_empty(value),"byte reader permits EOF then parser owns empty JSON refusal")

def process(+self: String,operation: String,body: String) -> IO(U32 & (String & String)):
  IO.try(U32 & (String & String),Process.run(self,["worker",operation],body,65536,30000))

def success(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    F.assert(U32.is_eq(code,0) && String.is_empty(err),"native worker success exit and empty stderr")
    return F.raw(out)

def denied(result: U32 & (String & String),code: String,name: String) -> IO(Unit):
  (exit,(out,err)) = result
  F.assert(U32.is_ne(exit,0) && String.is_empty(out) && String.eq(Json.get(F.raw(err),"code"),code),name)

def current_check(+self: String,+anchor: B.Input,+token: String,+text: String,name: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- process(self,"brief-check",A.check_request(anchor,token,text))
    +response : Json.Json <- success(result)
    F.assert(String.eq(Json.get(response,"kind"),"checked") && String.eq(Json.get(response,"commitment"),token) && String.eq(Json.get(response,"text"),text),name)

def corrupt_result(result: U32 & (String & String)) -> IO(Unit):
  (exit,(out,err)) = result
  F.assert(U32.is_ne(exit,0) && String.is_empty(out) && String.contains(err,"integrity"),"native context corruption cannot emit checked text")

def integration(+self: String) -> IO(Unit):
  do IO<Unit>:
    F.command("/usr/bin/git",["-c","init.defaultBranch=main","init","--quiet","adapter-repo"])
    +repo : String <- Paths.resolve("adapter-repo")
    +db : U32 <- Store.open(".build/adapter.sqlite")
    +snapshot : String <- F.capture(db,"claude","adapter-source.jsonl",F.claude(repo,"user","Implement the fixed selected request") ++ F.claude(repo,"assistant","Recorded result café 😀"))
    +anchor : B.Input = {B.Input{snapshot,0,2,F.all(),repo} : B.Input}
    result : U32 & (String & String) <- process(self,"brief-prepare",A.prepare_request(anchor))
    +response : Json.Json <- success(result)
    +token : String = Json.get(response,"commitment")
    +text : String = Json.get(response,"text")
    F.assert(String.eq(Json.get(response,"kind"),"prepared") && A.commitment_valid(token) && String.contains(text,"Implement the fixed selected request"),"real capture prepares exact bounded redacted preview")
    current_check(self,anchor,token,text,"fresh worker revalidates retained captured evidence")
    wrong : U32 & (String & String) <- process(self,"brief-check",A.check_request(anchor,token,text ++ "x"))
    denied(wrong,"stale","native text tampering cannot authorize copy")
    changed : U32 & (String & String) <- process(self,"brief-check",A.check_request(B.Input{snapshot,0,1,F.all(),repo},token,text))
    denied(changed,"stale","changed exact physical range cannot reuse token")
    scoped : U32 & (String & String) <- process(self,"brief-check",A.check_request(B.Input{snapshot,0,2,Scoped.Scope{"claude","","user",""},repo},token,text))
    denied(scoped,"stale","changed frozen role scope cannot reuse token")
    Store.write_text("adapter-source.jsonl","a",F.claude(repo,"assistant","Later source append outside pinned snapshot"))
    newer : String <- Store.import_file(db,"claude","adapter-source.jsonl")
    F.assert(Bool.not(String.eq(newer,snapshot)),"fixture append publishes a distinct latest snapshot")
    current_check(self,anchor,token,text,"new latest snapshot does not replace pinned brief")
    F.command("/bin/rm",["--","adapter-source.jsonl"])
    current_check(self,anchor,token,text,"source deletion leaves retained capture check available")
    Maintenance.rebuild(db,snapshot)
    current_check(self,anchor,token,text,"equivalent verified rebuild retains full preview commitment")
    invalid : Result<&2,&2,B.Problem,String> <- A.dispatch(0,A.Prepare{B.Input{"01",0,2,F.all(),repo}})
    F.assert(F.failed(String,invalid,"invalid_request"),"direct dispatch rejects invalid input before touching invalid DB handle")
    malformed : U32 & (String & String) <- process(self,"brief-prepare","{}")
    denied(malformed,"invalid_request","native malformed input returns closed error without preview")
    Store.exec(db,"UPDATE snapshot_context SET model='forged' WHERE snapshot=? AND ordinal=0",[Sql.Cell.Integer{snapshot}])
    corrupt : U32 & (String & String) <- process(self,"brief-check",A.check_request(anchor,token,text))
    corrupt_result(corrupt)
    IO.try(Unit,Sql.close(db))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    pure_shape(F.raw(A.prepare_request(input())))
    bounds("/" ++ String.repeat("😀",4095n),"/" ++ String.repeat("\u{0001}",4095n),String.repeat("\u{0001}",8192n))
    +preview : B.Preview <- F.pure("<system-reminder>context </system-reminder>Fix café 😀 safely.")
    commitment_tests(preview)
    bytes_tests()
    integration(self)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "worker" <> operation <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/adapter.sqlite")
        A.run(db,operation)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Invalid isolated adapter test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
