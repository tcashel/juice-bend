import Base
import ../src/cli.bend as Cli
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/domain.bend as Domain
import ../src/evidence.bend as Evidence
import ../src/brief_cli.bend as Shape
import ./zstd/frame_vectors.bend as Vectors
import ./archive_maintenance.bend as Fixture

# The native runner supplies a private synthetic cwd with .build. Every suite
# additionally creates its own mode0700 nonce directory. Each product command
# runs through Cli.command in this executable's child, against its exact DB.
# No Main/GUI, default history roots, borrowed services or external decoder.

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match value:
    case Done{value}: IO.pure(Json.Json,value)
    case Fail{error}: IO.die(Json.Json,1,"FAIL actual archive CLI returned invalid JSON: " ++ error)

# Process failure includes timeout; it never becomes an expected rejection.
def completed(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> IO(U32 & (String & String)):
  match result:
    case Done{value}: IO.pure(U32 & (String & String),value)
    case Fail{(code,error)}:
      IO.die(U32 & (String & String),1,"FAIL owned CLI child did not complete: " ++ U32.show(code) ++ " " ++ error)

def execute(self: String,db: String,args: List<String>) -> IO(U32 & (String & String)):
  do IO<U32 & (String & String)>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run(self,"archive-worker" <> db <> args,"",1048576,30000)
    completed(result)

def good_result(result: U32 & (String & String)) -> IO(Json.Json):
  (code,(out,err)) = result
  do IO<Json.Json>:
    check(U32.is_eq(code,0) && String.is_empty(err),"actual archive CLI exits0 without stderr")
    parsed(Json.parse(String.trim(out)))

def good(self: String,db: String,args: List<String>) -> IO(Json.Json):
  do IO<Json.Json>:
    result : U32 & (String & String) <- execute(self,db,args)
    good_result(result)

def field(value: Json.Json,key: String,expected: String,label: String) -> IO(Unit):
  check(String.eq(Json.encode(Json.field(value,key)),expected),label)

def text_value(value: Json.Json) -> IO(String):
  match value:
    case Json.JString{text}: IO.pure(String,text)
    case _: IO.die(String,1,"FAIL CLI snapshot must be an exact JSON string")

def imported(+self: String,+db: String,source: String) -> IO(String):
  do IO<String>:
    +reply : Json.Json <- good(self,db,["import","claude",source])
    check(Shape.shape(reply,["accepted_snapshot"]),"archive import has the exact success response shape")
    +snapshot : String <- text_value(Json.field(reply,"accepted_snapshot"))
    check(Cli.snapshot_valid(snapshot),"archive import returns a canonical accepted snapshot ID")
    return snapshot

# This independent fixture grammar is the original100-record input to the
# fixed ordinary Huffman/FSE+checksum vector, not a decoder-derived expectation.
def records(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest:
      +role = Bool.pick(String,U32.is_eq(U32.mod(index,3),0),"user","assistant")
      "{\"type\":\"" ++ role ++ "\",\"sessionId\":\"synthetic-zstd\",\"message\":{\"role\":\"" ++ role ++
        "\",\"content\":\"Archive record " ++ U32.show(index) ++ ": keep exact cafe and code path src/" ++
        U32.show(U32.mod(index,7)) ++ ".bend; value=" ++ U32.show(U32.mul(index,index)) ++ "\"}}\n" ++ records(rest,U32.add(index,1))

def one_hit(value: Json.Json,snapshot: String) -> Bool:
  match value:
    case Json.JArray{[Json.JArray{[Json.JString{actual},Json.JString{"42"},Json.JString{"0"},
      Json.JString{"claude"},Json.JString{"user"},Json.JString{snippet},Json.JString{""},
      Json.JString{"synthetic-zstd"},Json.JString{""},Json.JString{generation}]}]}:
      String.eq(actual,snapshot) && String.contains(snippet,"Archive record 42") && Cli.snapshot_valid(generation)
    case _: False{}

def search(+self: String,+db: String,snapshot: String) -> IO(Json.Json):
  do IO<Json.Json>:
    +reply : Json.Json <- good(self,db,["search","\"Archive record 42\"","claude","","user",""])
    check(Shape.shape(reply,["columns","rows","offset","limit","has_more"]),"actual archive search returns the closed paged shape")
    field(reply,"columns","[\"snapshot\",\"record\",\"event\",\"provider\",\"role\",\"snippet\",\"repository\",\"session\",\"timestamp\",\"generation\"]",
      "archive search columns preserve their public order")
    field(reply,"offset","0","archive search starts at the requested first page")
    field(reply,"limit","100","archive search retains its bounded page size")
    field(reply,"has_more","false","exact phrase has no hidden next result")
    check(one_hit(Json.field(reply,"rows"),snapshot),"actual lexical phrase and provider/role scope find exactly captured record42")
    return reply

def selected(+self: String,+db: String,+snapshot: String) -> IO(Json.Json):
  do IO<Json.Json>:
    +reply : Json.Json <- good(self,db,["session-scope",snapshot,"95","10","claude","","",""])
    check(Shape.shape(reply,["snapshot","start","requested_records","selected_records","kind","byte_space","complete_export","text"]),
      "actual selected range has the exact UI transport shape")
    field(reply,"snapshot",Json.quote(snapshot),"selected range remains pinned to the accepted snapshot")
    field(reply,"start","95","selected range retains its logical record cursor")
    field(reply,"requested_records","10","selected range distinguishes requested count")
    field(reply,"selected_records","5","selected range reports the actual five-record tail")
    field(reply,"kind","\"scoped_transcript_page\"","selected range identifies a scoped transcript")
    field(reply,"byte_space","\"logical_source_bytes\"","selected range identifies decompressed logical byte space")
    field(reply,"complete_export","false","selected range never claims a complete export")
    +text : String <- text_value(Json.field(reply,"text"))
    check(String.contains(text,"Archive record 95") && String.contains(text,"Archive record 99") &&
      Bool.not(String.contains(text,"Archive record 94")) && String.contains(text,"logical source bytes"),
      "selected archive text is readable and bounded with the byte-space disclosure")
    return reply

def session(+self: String,+db: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +reply : Json.Json <- good(self,db,["session",snapshot,"95","10"])
    check(Shape.shape(reply,["snapshot","start","requested_records","maximum_records","verification","byte_space","complete_export","kind","rationale","text"]),
      "unscoped transcript retains its closed public shape")
    field(reply,"byte_space","\"logical_source_bytes\"","unscoped transcript labels logical source bytes")
    field(reply,"verification","\"selected_records_only\"","unscoped transcript states bounded verification")
    field(reply,"complete_export","false","unscoped transcript is not a complete export")

def descriptor(+path: String,snapshot: String) -> IO(String):
  do IO<String>:
    +db : U32 <- Store.open(path)
    record : Evidence.Verified <- Evidence.read_record(db,snapshot,96)
    +citation : String = Evidence.citation(record,0)
    IO.try(Unit,Sql.close(db))
    return citation

def citation(self: String,db: String,descriptor: String) -> IO(Json.Json):
  do IO<Json.Json>:
    +reply : Json.Json <- good(self,db,["citation",descriptor])
    check(Shape.shape(reply,["kind","text"]),"actual citation command returns its exact closed shape")
    field(reply,"kind","\"captured_citation\"","actual citation resolves retained captured evidence")
    check(String.contains(Json.get(reply,"text"),"Archive record 96") &&
      String.contains(Json.get(reply,"text"),"value=9216"),"citation resolves the independently expected record text")
    return reply

def maintained(self: String,db: String,command: String,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +reply : Json.Json <- good(self,db,[command,snapshot])
    check(Shape.shape(reply,["snapshot","verification","raw_bytes_unchanged"]),"maintenance response has the exact closed shape")
    field(reply,"snapshot",Json.quote(snapshot),"maintenance preserves the explicit snapshot ID")
    field(reply,"verification","\"complete_accepted_extent\"","maintenance reports complete retained verification")
    field(reply,"raw_bytes_unchanged","true","maintenance preserves captured raw evidence")

def export_metadata(+reply: Json.Json,snapshot: String,path: String,+container: Bool) -> IO(Unit):
  do IO<Unit>:
    check(Shape.shape(reply,["path","snapshot","format","byte_space","complete_export","verification"]),"actual archive export has the exact closed response shape")
    field(reply,"snapshot",Json.quote(snapshot),"export is pinned to its accepted snapshot")
    field(reply,"path",Json.quote(path),"export acknowledges the exact requested destination")
    field(reply,"complete_export","true","export acknowledges its complete byte stream")
    field(reply,"format",Json.quote(Bool.pick(String,container,"retained_zstd_container","retained_raw_bytes")),"export distinguishes original container from logical raw bytes")
    field(reply,"byte_space",Json.quote(Bool.pick(String,container,"compressed_container_bytes","logical_source_bytes")),"export names its actual byte space")
    field(reply,"verification",Json.quote(Bool.pick(String,container,"complete_owned_container","complete_accepted_extent")),"export reports verification of the selected byte stream")

def reject_result(result: U32 & (String & String),needle: String,label: String) -> IO(Unit):
  (+code,(out,err)) = result
  check((U32.is_eq(code,1) || U32.is_eq(code,2)) && String.is_empty(out) && String.contains(err,needle),label)

def reject(self: String,db: String,args: List<String>,needle: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- execute(self,db,args)
    reject_result(result,needle,label)

def exact_file(path: String,expected: List<&2,U32>,label: String) -> IO(Unit):
  do IO<Unit>:
    bytes : List<&2,U32> <- Fixture.read_bytes(path)
    check(Domain.bytes_equal(bytes,expected),label)

def exports(+self: String,+db: String,+snapshot: String,+directory: String) -> IO(Unit):
  +logical = directory ++ "/logical.jsonl"
  +container = directory ++ "/original.zst"
  do IO<Unit>:
    raw : Json.Json <- good(self,db,["export-all",snapshot,logical])
    export_metadata(raw,snapshot,logical,False{})
    zipped : Json.Json <- good(self,db,["export-container",snapshot,container])
    export_metadata(zipped,snapshot,container,True{})
    exact_file(logical,Domain.encode(records(100n,0)),"CLI logical export exactly matches all independent original JSONL bytes")
    exact_file(container,Vectors.jsonl_check(),"CLI container export exactly matches the captured compressed fixture without recompression")
    reject(self,db,["export-all",snapshot,logical],"already exists","CLI logical export refuses to clobber an existing destination")
    reject(self,db,["export-container",snapshot,container],"already exists","CLI container export refuses to clobber an existing destination")
    exact_file(logical,Domain.encode(records(100n,0)),"failed logical no-clobber leaves every destination byte unchanged")
    exact_file(container,Vectors.jsonl_check(),"failed container no-clobber leaves every destination byte unchanged")

def source_guards(+self: String,+db: String,+snapshot: String,+source: String) -> IO(Unit):
  do IO<Unit>:
    reject(self,db,["export-all",snapshot,source],"source locator","CLI logical export refuses even a vanished original source locator")
    reject(self,db,["export-container",snapshot,source],"source locator","CLI container export refuses even a vanished original source locator")
    missing : Result<&1,&1,U32 & String,File> <- File.open(source,"r")
    Fixture.absent(missing,"neither refused export recreates the removed original source")

def stable(+self: String,+db: String,+snapshot: String,+before_search: Json.Json,+before_page: Json.Json,
  +reference: String,+before_citation: Json.Json,+label: String) -> IO(Unit):
  do IO<Unit>:
    searched : Json.Json <- search(self,db,snapshot)
    check(String.eq(Json.encode(searched),Json.encode(before_search)),label ++ " exact lexical search response is stable")
    page : Json.Json <- selected(self,db,snapshot)
    check(String.eq(Json.encode(page),Json.encode(before_page)),label ++ " exact selected transcript response is stable")
    resolved : Json.Json <- citation(self,db,reference)
    check(String.eq(Json.encode(resolved),Json.encode(before_citation)),label ++ " exact old citation response is stable")
    actual_reference : String <- descriptor(db,snapshot)
    check(String.eq(actual_reference,reference),label ++ " original citation identity and extent are unchanged")

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    first : U32 <- IO.try(U32,IO.random_u32())
    second : U32 <- IO.try(U32,IO.random_u32())
    +directory : String = ".build/archive-cli-" ++ U32.show(first) ++ "-" ++ U32.show(second)
    +db : String = directory ++ "/cli.sqlite"
    +source : String = directory ++ "/synthetic.jsonl.zst"
    made : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/mkdir",["-m","700",directory],"",4096,2000))
    Fixture.process_ok(made,"create a fresh private archive CLI directory")
    Fixture.write_bytes(source,Vectors.jsonl_check())
    +snapshot : String <- imported(self,db,source)
    +before_search : Json.Json <- search(self,db,snapshot)
    +before_page : Json.Json <- selected(self,db,snapshot)
    session(self,db,snapshot)
    +reference : String <- descriptor(db,snapshot)
    +before_citation : Json.Json <- citation(self,db,reference)
    maintained(self,db,"verify",snapshot)
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--",source],"",4096,2000))
    Fixture.process_ok(removed,"remove only this suite's nonce-owned synthetic archive")
    missing : Result<&1,&1,U32 & String,File> <- File.open(source,"r")
    Fixture.absent(missing,"the original synthetic archive is absent")
    stable(self,db,snapshot,before_search,before_page,reference,before_citation,"source removed")
    maintained(self,db,"verify",snapshot)
    exports(self,db,snapshot,directory)
    source_guards(self,db,snapshot,source)
    maintained(self,db,"rebuild",snapshot)
    maintained(self,db,"verify",snapshot)
    stable(self,db,snapshot,before_search,before_page,reference,before_citation,"source removed and rebuilt")
    exact_file(directory ++ "/logical.jsonl",Domain.encode(records(100n,0)),"rebuild leaves the previously exported logical bytes unchanged")
    exact_file(directory ++ "/original.zst",Vectors.jsonl_check(),"rebuild leaves the previously exported container bytes unchanged")
    IO.print("Archive CLI route suite passed")

def dispatch(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "archive-worker" <> path <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(path)
        Cli.command(db,"",command,rest)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Archive CLI test expects no arguments or its owned worker command")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    dispatch(args)
