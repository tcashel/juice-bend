import Base
import ../src/attachment_cli.bend as C
import ../src/attachment_inventory.bend as Inventory
import ../src/attachment_inventory_output.bend as Output
import ../src/attachment_inline.bend as Inline
import ../src/attachment_decode.bend as Decode
import ../src/archive_meta.bend as Meta
import ../src/domain.bend as Domain
import ../src/json.bend as Json
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/paths.bend as Paths

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need(-T: Kind(&2),result: Result<&2,&2,Inventory.Failure,T>) -> IO(T):
  match result:
    case Done{value}: IO.pure(T,value)
    case Fail{Inventory.Failure{code,_}}: IO.die(T,1,code)

def inventory_request(result: Result<&2,&2,Inventory.Failure,C.Command>) -> Bool:
  match result:
    case Done{C.InventoryCommand{snapshot,start,count}}:
      String.eq(snapshot,"9223372036854775807") && U32.is_eq(start,4294967295) && U32.is_eq(count,40)
    case _: False{}

def export_request(result: Result<&2,&2,Inventory.Failure,C.Command>) -> Bool:
  match result:
    case Done{C.ExportCommand{Inline.Request{snapshot,record,reference,path},destination}}:
      String.eq(snapshot,"9007199254740993") && U32.is_eq(record,4294967295) &&
        U32.is_eq(reference,63) && String.eq(path,"/message/content/4/source/data") &&
        String.eq(destination,"chosen café.bin")
    case _: False{}

def rejected(result: Result<&2,&2,Inventory.Failure,C.Command>) -> Bool:
  match result:
    case Fail{Inventory.Failure{code,_}}: String.eq(code,"attachment_usage")
    case _: False{}

def parse_checks() -> IO(Unit):
  do IO<Unit>:
    check(inventory_request(C.parse("attachments",["9223372036854775807","4294967295","40"])),"inventory parser retains signed64 identity and maximum U32 start exactly")
    check(export_request(C.parse("export-inline",["9007199254740993","4294967295","63","/message/content/4/source/data","chosen café.bin"])),"export parser retains exact occurrence path and caller-selected Unicode destination")
    check(rejected(C.parse("attachments",["01","0","1"])) && rejected(C.parse("attachments",["0","0","1"])) &&
      rejected(C.parse("attachments",["9223372036854775808","0","1"])),"noncanonical and overflowing immutable IDs are rejected")
    check(rejected(C.parse("attachments",["1","00","1"])) && rejected(C.parse("attachments",["1","-1","1"])) &&
      rejected(C.parse("attachments",["1","4294967296","1"])),"raw start rejects leading zero sign and U32 overflow")
    check(rejected(C.parse("attachments",["1","0","0"])) && rejected(C.parse("attachments",["1","0","41"])) &&
      rejected(C.parse("attachments",["1","0","01"])),"inventory count is canonical and bounded1..40")
    check(rejected(C.parse("export-inline",["1","0","64","/data","out.bin"])) &&
      rejected(C.parse("export-inline",["1","0","00","/data","out.bin"])),"reference ordinal admits only canonical0..63")
    check(rejected(C.parse("export-inline",["1","0","0","data","out.bin"])) &&
      rejected(C.parse("export-inline",["1","0","0","/" ++ String.repeat("x",2048n),"out.bin"])) &&
      rejected(C.parse("export-inline",["1","0","0","/nul\0data","out.bin"])),"structural paths require exact leading slash and bounded scalar nonNUL text")
    check(rejected(C.parse("export-inline",["1","0","0","/data",""])) &&
      rejected(C.parse("export-inline",["1","0","0","/data","/tmp/"])) &&
      rejected(C.parse("export-inline",["1","0","0","/data","/tmp/.."])) &&
      rejected(C.parse("export-inline",["1","0","0","/data",String.repeat("é",128n)])),"destination leaf must exist syntactically and fit the private temporary-name budget")
    check(C.filename(String.repeat("a",244n)) && Bool.not(C.filename(String.repeat("a",245n))) &&
      C.filename(String.repeat("é",122n)) && Bool.not(C.filename(String.repeat("é",122n) ++ "a")),
      "exact244-byte destination leaf is admitted and245 bytes rejected including multibyte UTF8")
    check(rejected(C.parse("export-inline",["1","0","0","/data",String.repeat("x/",2049n) ++ "a"])) &&
      rejected(C.parse("export-inline",["1","0","0","/data","bad\0name"])),"destination total bytes and NUL admission precede filesystem access")
    check(rejected(C.parse("attachments",["1","0"])) && rejected(C.parse("attachments",["1","0","1","extra"])) &&
      rejected(C.parse("export-inline",["1","0","0","/data"])) && rejected(C.parse("unknown-secret-payload",[])),"unknown routes missing fields and extra fields are refused")

def fake_capture() -> Meta.Header:
  Meta.Header{"9007199254740993","9007199254740995","9007199254740997","claude",
    "/synthetic/source\"café\n.jsonl",100,3,0,0,True{},"identity"}

def fake_resolved() -> Inline.Resolved:
  Inline.Resolved{fake_capture(),1,12,80,String.repeat("a",64n),2,"/message/content/2/source/data",
    "application/octet-stream",Decode.Bytes{[97,98,99],3,"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"}}

def fields_count(value: Json.Json,expected: Nat) -> Bool:
  match value:
    case Json.JObject{fields}: Nat.is_eq(List.length(&2,Json.Field,fields),expected)
    case _: False{}

def ack_json(+value: Json.Json) -> Bool:
  +capture = Json.field(value,"capture")
  fields_count(value,13n) && String.eq(Json.get(value,"kind"),"attachment_inline_export") &&
    String.eq(Json.get(value,"profile"),"attachment-occurrences-v1") &&
    String.eq(Json.get(capture,"snapshot"),"9007199254740993") &&
    String.eq(Json.get(capture,"source_id"),"9007199254740995") &&
    String.eq(Json.get(capture,"generation"),"9007199254740997") &&
    String.eq(Json.get(capture,"source"),"/synthetic/source\"café\n.jsonl") &&
    String.eq(Json.get(capture,"byte_space"),"logical_source_bytes") &&
    String.eq(Json.get(value,"record"),"1") && String.eq(Json.get(value,"offset"),"12") &&
    String.eq(Json.get(value,"length"),"80") && String.eq(Json.get(value,"reference"),"2") &&
    String.eq(Json.get(value,"raw_digest"),String.repeat("a",64n)) &&
    String.eq(Json.get(value,"path"),"/message/content/2/source/data") &&
    String.eq(Json.get(value,"media_type"),"application/octet-stream") &&
    String.eq(Json.get(value,"decoded_bytes"),"3") &&
    String.eq(Json.get(value,"sha256"),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad") &&
    String.eq(Json.get(value,"destination"),"/synthetic/chosen \"café.bin")

def parsed_ack(result: Result<&2,&2,String,Json.Json>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{value}: ack_json(value)

def encoding_checks() -> IO(Unit):
  +diagnostic = C.error(Inventory.fail("attachment_usage","bounded static message"))
  do IO<Unit>:
    +ack : String <- need(String,C.acknowledge(fake_resolved(),"/synthetic/chosen \"café.bin"))
    check(parsed_ack(Json.parse(ack)),"ack JSON has exactly13 fields and preserves all wide identity bytecount digest path and destination values")
    check(Bool.not(String.contains(ack,"YWJj")) && Bool.not(String.contains(ack,"\"bytes\":")) &&
      Bool.not(String.contains(ack,"\"original\":")) && Nat.is_lt(String.length(ack),262144n),"ack includes no base64 decoded payload or original reference")
    check(String.contains(diagnostic,"\"kind\":\"attachment_error\"") && String.contains(diagnostic,"\"code\":\"attachment_usage\""),"typed adapter failures have metadata-only JSON shape")
    check(Bool.not(String.contains(C.error(Inventory.fail("bad",String.repeat("s",2049n))),String.repeat("s",50n))),"overlarge diagnostic is replaced without echoing caller content")

def fixture() -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"application/octet-stream\",\"data\":\"AAH+/w==\"}}]}}\n"

def path() -> String:
  "/message/content/0/source/data"

def child(self: String,command: String,args: List<String>) -> IO(U32 & (String & String)):
  do IO<U32 & (String & String)>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,"route" <> command <> args,"",262144,30000))
    return result

def good(result: U32 & (String & String),expected: String,label: String) -> IO(Unit):
  (code,(out,err)) = result
  check(U32.is_eq(code,0) && String.eq(out,expected ++ "\n") && String.is_empty(err),label)

def bad_fields(status: U32,out: String,+err: String,code: String,label: String) -> IO(Unit):
  check(U32.is_ne(status,0) && String.is_empty(out) &&
    String.contains(err,"\"kind\":\"attachment_error\"") && String.contains(err,"\"code\":\"" ++ code ++ "\""),label)

def bad(result: U32 & (String & String),code: String,label: String) -> IO(Unit):
  (status,(out,err)) = result
  bad_fields(status,out,err,code,label)

def absent_result(result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Fail{(code,_)}: check(U32.is_eq(code,2),"rejected CLI operation creates no destination")
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        check(False{},"rejected CLI operation creates no destination")

def absent() -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open("rejected.bin","r")
    absent_result(result)

def runtime(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("adapter.jsonl","w",fixture())
    +snapshot : String <- Store.import_file(db,"claude","adapter.jsonl")
    inventory : Result<&2,&2,Inventory.Failure,Inventory.Page> <- Inventory.read(db,snapshot,0,1)
    page : Inventory.Page <- need(Inventory.Page,inventory)
    +expected : String <- need(String,Output.encode(page))
    result : U32 & (String & String) <- child(self,"attachments",[snapshot,"0","1"])
    good(result,expected,"real attachments route emits the frozen inventory JSON unchanged with one newline")
    bad_count : U32 & (String & String) <- child(self,"attachments",[snapshot,"0","41"])
    bad(bad_count,"attachment_usage","actual route returns nonzero JSON for overlarge page request")
    wrong : U32 & (String & String) <- child(self,"export-inline",[snapshot,"0","0","/wrong","rejected.bin"])
    bad(wrong,"attachment_occurrence_path_mismatch","actual export route cannot redirect exact occurrence path")
    absent()
    malformed : U32 & (String & String) <- child(self,"export-inline",[snapshot,"0","0",path()])
    bad(malformed,"attachment_usage","actual export route rejects missing destination before publication")
    absent()
    Store.write_text("oversized.jsonl","w",String.repeat("x",262145n) ++ "\n")
    oversized : String <- Store.import_file(db,"claude","oversized.jsonl")
    too_large : U32 & (String & String) <- child(self,"export-inline",[oversized,"0","0",path(),"rejected.bin"])
    bad(too_large,"attachment_oversized_record","actual export route refuses oversized retained raw fragment")
    absent()
    Store.write_text("malformed.jsonl","w","{bad}\n")
    invalid : String <- Store.import_file(db,"claude","malformed.jsonl")
    bad_json : U32 & (String & String) <- child(self,"export-inline",[invalid,"0","0",path(),"rejected.bin"])
    bad(bad_json,"attachment_malformed_json","actual export route reports malformed retained JSON without output")
    absent()

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    parse_checks()
    encoding_checks()
    +db : U32 <- Store.open(".build/attachment-cli.sqlite")
    runtime(db,self)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "route" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/attachment-cli.sqlite")
        C.run(db,command,rest)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Invalid synthetic adapter arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
