import Base
import ../src/attachment_inline.bend as A
import ../src/attachment_decode.bend as D
import ../src/attachment_inventory.bend as I
import ../src/archive_meta.bend as Meta
import ../src/maintenance.bend as Maintenance
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/json.bend as J
import ../src/paths.bend as Paths

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ name)
    case False{}: IO.die(Unit,1,"FAIL " ++ name)

def need(-T: Kind(&2),result: Result<&2,&2,I.Failure,T>) -> IO(T):
  match result:
    case Done{value}: IO.pure(T,value)
    case Fail{I.Failure{code,_}}: IO.die(T,1,code)

def failed(-T: Kind(&2),result: Result<&2,&2,I.Failure,T>,expected: String) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{I.Failure{code,_}}: String.eq(code,expected)

def decoded(result: Result<&2,&2,String,D.Bytes>,expected: List<&2,U32>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{D.Bytes{+bytes,count,digest}}:
      Domain.bytes_equal(bytes,expected) && Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(count)) &&
        String.eq(Domain.digest(bytes),digest)

def rejected(result: Result<&2,&2,String,D.Bytes>) -> Bool:
  match result:
    case Fail{_}: True{}
    case Done{_}: False{}

def zeroes(bytes: List<&2,U32>) -> Bool:
  match bytes:
    case []: True{}
    case byte <> rest: U32.is_eq(byte,0) && zeroes(rest)

def maximum(result: Result<&2,&2,String,D.Bytes>) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{D.Bytes{+bytes,count,_}}:
      U32.is_eq(count,786432) && Nat.is_eq(List.length(&2,U32,bytes),786432n) && zeroes(bytes)

def known_digest(result: Result<&2,&2,String,D.Bytes>,expected: String) -> Bool:
  match result:
    case Fail{_}: False{}
    case Done{D.Bytes{_,_,digest}}: String.eq(digest,expected)

def repeat(n: Nat,+s: String) -> String:
  match n:
    case 0n: ""
    case 1n+left: s ++ repeat(left,s)

def bad_vectors(values: List<&2,String>) -> IO(Unit):
  match values:
    case []: IO.pure(Unit,Unit{})
    case +value <> rest:
      do IO<Unit>:
        assert(rejected(D.decode(value)),"strict base64 rejects malformed vector " ++ J.quote(value))
        bad_vectors(rest)

def pure() -> IO(Unit):
  do IO<Unit>:
    assert(decoded(D.decode(""),[]),"empty canonical base64 preserves zero bytes")
    assert(decoded(D.decode("AA=="),[0]),"one NUL byte decodes without text conversion")
    assert(decoded(D.decode("/w=="),[255]),"one invalidUTF8 byte remains255")
    assert(decoded(D.decode("AAE="),[0,1]),"two-byte padding vector")
    assert(decoded(D.decode("AAH/"),[0,1,255]),"un-padded complete quartet vector")
    assert(decoded(D.decode("AAH+/w=="),[0,1,254,255]),"independent binary vector includes zero and nonUTF8 octets")
    assert(decoded(D.decode("Zm9vYmFy"),[102,111,111,98,97,114]),"two-quartet RFC4648 foobar vector")
    assert(decoded(D.decode("8J+Zgg=="),[240,159,153,130]),"UTF8 bytes are preserved without Unicode transcoding")
    assert(decoded(D.decode("wyg="),[195,40]) && decoded(D.decode("7aCA"),[237,160,128]),"malformedUTF8 and surrogate encoding octets remain exact binary")
    assert(known_digest(D.decode(""),"e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") &&
      known_digest(D.decode("YWJj"),"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"),"decoded SHA256 matches independent empty and abc constants")
    bad_vectors(["A","AA","AAA","A===","=AAA","AA=A","AAAA=","AA==AAAA","AB==","AAB=","AA-_/w==","AA==\n"," AA==","éA=="])
    assert(rejected(D.decode(repeat(262145n,"AAAA"))),"encoded payload beyond1MiB is rejected before decode")
    assert(maximum(D.decode(repeat(262144n,"AAAA"))),"exact1MiB encoded limit yields786432 independently expected zero octets")
    assert(Bool.not(D.valid(D.Bytes{[256],1,Domain.digest([256])})),"export admission rejects nonoctet values even with matching digest")
    assert(Bool.not(D.valid(D.Bytes{[0],2,Domain.digest([0])})) &&
      Bool.not(D.valid(D.Bytes{[0],1,"wrong"})),"export admission rejects wrong byte count or digest")

def image(data: String) -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":" ++ J.quote(data) ++ "}}"

def record(blocks: String) -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[" ++ blocks ++ "]}}\n"

def path(index: U32) -> String:
  "/message/content/" ++ U32.show(index) ++ "/source/data"

def bytes(value: A.Resolved) -> List<&2,U32>:
  A.Resolved{_,_,_,_,_,_,_,_,D.Bytes{bytes,_,_}} = value
  bytes

def identity(value: A.Resolved) -> String:
  A.Resolved{Meta.Header{snapshot,source,generation,provider,_,_,_,_,_,_,encoding},record,offset,_,_,reference,path,media,D.Bytes{_,count,_}} = value
  String.join([snapshot,source,generation,provider,encoding,U32.show(record),U32.show(offset),U32.show(reference),path,media,U32.show(count)],"|")

def get(+db: U32,snapshot: String,record: U32,reference: U32,path: String) -> IO(A.Resolved):
  do IO<A.Resolved>:
    result : Result<&2,&2,I.Failure,A.Resolved> <- A.resolve(db,A.Request{snapshot,record,reference,path})
    need(A.Resolved,result)

def export(db: U32,snapshot: String,record: U32,reference: U32,path: String,destination: String) -> IO(A.Resolved):
  do IO<A.Resolved>:
    result : Result<&2,&2,I.Failure,A.Resolved> <- A.export(db,A.Request{snapshot,record,reference,path},destination)
    need(A.Resolved,result)

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(written)

def read_closed(result: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,bytes) = result
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,bytes))

def read_bytes(path: String) -> IO(List<&2,U32>):
  do IO<List<&2,U32>>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1048576)
    read_closed(result)

def absent_result(result: Result<&1,&1,U32 & String,File>,label: String) -> IO(Unit):
  match result:
    case Fail{(code,_)}: assert(U32.is_eq(code,2),label)
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        assert(False{},label)

def absent(path: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    absent_result(result,label)

def child_result(result: U32 & (String & String),success: Bool,needle: String,label: String) -> IO(Unit):
  (+code,(out,err)) = result
  assert(Bool.pick(Bool,success,U32.is_eq(code,0),U32.is_ne(code,0)) && String.contains(out ++ err,needle),label)

def child(self: String,args: List<String>,success: Bool,needle: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,args,"",8192,30000))
    child_result(result,success,needle,label)

def remove(path: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--",path],"",1024,2000))
    child_result(result,True{},"","synthetic source removal completed")

def request_failure(db: U32,request: A.Request,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,I.Failure,A.Resolved> <- A.export(db,request,"should-not-exist.bin")
    assert(failed(A.Resolved,result,code),label)
    absent("should-not-exist.bin","failed request publishes no output")

def basic(+db: U32,+self: String) -> IO(Unit):
  +fixture = record(image("AAH+/w==") ++ "," ++ image("AAH+/w==") ++
    ",{\"type\":\"tool_result\",\"content\":[" ++ image("/w==") ++ "]}")
  do IO<Unit>:
    Store.write_text("source.jsonl","w",fixture)
    +snapshot : String <- Store.import_file(db,"claude","source.jsonl")
    +first : A.Resolved <- get(db,snapshot,0,0,path(0))
    +second : A.Resolved <- get(db,snapshot,0,1,path(1))
    assert(Domain.bytes_equal(bytes(first),[0,1,254,255]) && Domain.bytes_equal(bytes(second),[0,1,254,255]),
      "equal inline values at separate positions resolve without deduplication")
    assert(String.eq(identity(first),"1|1|1|claude|identity|0|0|0|/message/content/0/source/data|image/png|4") &&
      String.eq(identity(second),"1|1|1|claude|identity|0|0|1|/message/content/1/source/data|image/png|4"),
      "exact capture recordzero occurrence paths and ordinals remain distinct")
    nested : A.Resolved <- get(db,snapshot,0,2,"/message/content/2/content/0/source/data")
    assert(Domain.bytes_equal(bytes(nested),[255]),"known nested tool-result attachment resolves its exact path")
    request_failure(db,A.Request{snapshot,0,0,path(1)},"attachment_occurrence_path_mismatch","wrong path cannot redirect an otherwise valid occurrence ordinal")
    request_failure(db,A.Request{snapshot,0,3,path(0)},"attachment_occurrence_not_found","unseen ordinal cannot use an existing path")
    request_failure(db,A.Request{snapshot,1,0,path(0)},"attachment_record_not_found","pastEOF raw record fails as typed request")
    request_failure(db,A.Request{"01",0,0,path(0)},"attachment_invalid_request","noncanonical snapshot rejected before transaction")
    request_failure(db,A.Request{"9223372036854775807",0,0,path(0)},"attachment_snapshot_not_found","missing signed64 snapshot remains exact and fails as typed request")
    request_failure(db,A.Request{snapshot,0,64,path(0)},"attachment_invalid_request","reference ordinal64 exceeds admitted extractor prefix")
    exported : A.Resolved <- export(db,snapshot,0,0,path(0),"owned.bin")
    output : List<&2,U32> <- read_bytes("owned.bin")
    assert(Domain.bytes_equal(output,[0,1,254,255]) && Domain.bytes_equal(bytes(exported),[0,1,254,255]),"real exported binary exactly matches independent octets")
    child(self,["export",snapshot,"0","0",path(0),"owned.bin"],False{},"already exists","existing output is not overwritten")
    unchanged : List<&2,U32> <- read_bytes("owned.bin")
    assert(Domain.bytes_equal(unchanged,[0,1,254,255]),"existing destination bytes survive refused export")
    Store.exec(db,"UPDATE events SET body='forged',arguments='forged' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    Store.write_text("source.jsonl","w",record(image("AA==")))
    rewritten : String <- Store.import_file(db,"claude","source.jsonl")
    remove("source.jsonl")
    assert(Bool.not(String.eq(snapshot,rewritten)),"source rewrite creates a new capture identity")
    child(self,["export",snapshot,"0","1",path(1),"restarted.bin"],True{},"EXPORTED","new process exports original pinned bytes after source rewrite deletion and projection mutation")
    reopened : List<&2,U32> <- read_bytes("restarted.bin")
    assert(Domain.bytes_equal(reopened,[0,1,254,255]),"restart export retains exact original binary")
    child(self,["export",snapshot,"0","0",path(0),"source.jsonl"],False{},"source locator","removed original source locator remains protected from export")
    absent("source.jsonl","source locator refusal does not recreate original log")

def providers(+db: U32) -> IO(Unit):
  +codex = {"{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":{\"url\":\"data:image/png;base64,AAH+/w==\"}}]}}\n" : String}
  do IO<Unit>:
    Store.write_text("codex.jsonl","w",codex ++ codex)
    +snapshot : String <- Store.import_file(db,"codex","codex.jsonl")
    +first : A.Resolved <- get(db,snapshot,0,0,"/payload/content/0/image_url/url")
    second : A.Resolved <- get(db,snapshot,1,0,"/payload/content/0/image_url/url")
    assert(Domain.bytes_equal(bytes(first),[0,1,254,255]) && Domain.bytes_equal(bytes(second),[0,1,254,255]),"Codex object dataURL mirrors remain separate raw record occurrences")
    Store.write_text("empty.jsonl","w",record(image("")))
    empty : String <- Store.import_file(db,"claude","empty.jsonl")
    zero : A.Resolved <- export(db,empty,0,0,path(0),"empty.bin")
    zero_bytes : List<&2,U32> <- read_bytes("empty.bin")
    assert(Domain.bytes_equal(bytes(zero),[]) && Domain.bytes_equal(zero_bytes,[]),"zero-length inline attachment publishes exact empty file")
    Store.write_text("partial.jsonl","w",record("{\"type\":\"future_unknown\"}," ++ image("AA==")))
    partial : String <- Store.import_file(db,"claude","partial.jsonl")
    known : A.Resolved <- get(db,partial,0,0,path(1))
    assert(Domain.bytes_equal(bytes(known),[0]),"known exact occurrence remains resolvable alongside an unsupported content block")

def malformed(+db: U32) -> IO(Unit):
  +unsupported = {"{\"type\":\"input_image\",\"image_url\":\"data:image/png;utf8,hello\"}" : String}
  +local = {"{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":\"/synthetic/never-read.png\"}}" : String}
  do IO<Unit>:
    Store.write_text("bad.jsonl","w",record(image("AB==")) ++ record(local) ++ record(unsupported) ++ "{bad}\n")
    +snapshot : String <- Store.import_file(db,"claude","bad.jsonl")
    request_failure(db,A.Request{snapshot,0,0,path(0)},"attachment_invalid_base64","noncanonical unused pad bits rejected from owned raw")
    request_failure(db,A.Request{snapshot,1,0,"/message/content/0/source/path"},"attachment_not_supported_inline","local reference cannot trigger external file read")
    request_failure(db,A.Request{snapshot,2,0,"/message/content/0/image_url"},"attachment_not_supported_inline","unsupported dataURL encoding cannot enter byte decoder")
    request_failure(db,A.Request{snapshot,3,0,path(0)},"attachment_malformed_json","malformed retained JSON is a typed format failure")
    write_bytes("invalid.jsonl",List.append(&2,U32,[255,10],Domain.encode(repeat(262145n,"x") ++ "\n")))
    +invalid : String <- Store.import_file(db,"claude","invalid.jsonl")
    request_failure(db,A.Request{invalid,0,0,path(0)},"attachment_invalid_utf8","invalidUTF8 raw record is refused before JSON parsing")
    request_failure(db,A.Request{invalid,1,0,path(0)},"attachment_oversized_record","first oversized raw fragment is refused")
    request_failure(db,A.Request{invalid,2,0,path(0)},"attachment_oversized_record","continuation oversized fragment is refused through predecessor boundary")
    Store.exec(db,"BEGIN",[])
    held : Result<&2,&2,I.Failure,A.Resolved> <- A.resolve(db,A.Request{snapshot,0,0,path(0)})
    assert(failed(A.Resolved,held,"attachment_transaction_unavailable"),"existing caller transaction is never borrowed or ended")
    Store.exec(db,"ROLLBACK",[])
    Store.exec(db,"BEGIN",[])
    Store.exec(db,"ROLLBACK",[])
    assert(True{},"typed format failures release their own transactions")

def positional(+db: U32) -> IO(Unit):
  +local = {"{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":\"/synthetic/no-read.png\"}}" : String}
  +remote = {"{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/no-fetch\"}}" : String}
  do IO<Unit>:
    Store.write_text("positions.jsonl","w",record(local ++ "," ++ image("AA==") ++ "," ++ remote ++ "," ++ image("/w==")))
    +snapshot : String <- Store.import_file(db,"claude","positions.jsonl")
    first : A.Resolved <- get(db,snapshot,0,1,path(1))
    third : A.Resolved <- get(db,snapshot,0,3,path(3))
    assert(Domain.bytes_equal(bytes(first),[0]) && Domain.bytes_equal(bytes(third),[255]),"inline ordinals count intervening local and remote occurrences")
    request_failure(db,A.Request{snapshot,0,1,"/message/content/01/source/data"},"attachment_occurrence_path_mismatch","equivalent-looking noncanonical array path cannot alias exact identity")
    request_failure(db,A.Request{snapshot,0,2,"/message/content/2/source/url"},"attachment_not_supported_inline","remote occurrence is refused without fetch")
    Store.write_text("escaped.jsonl","w","{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"data\":\"\\u0041\\u0041==\"}}]}}\n")
    escaped : String <- Store.import_file(db,"claude","escaped.jsonl")
    exact : A.Resolved <- get(db,escaped,0,0,path(0))
    assert(Domain.bytes_equal(bytes(exact),[0]),"JSON escapes resolve through parsed string value without substring guessing")
    Store.write_text("duplicate.jsonl","w","{\"type\":\"user\",\"type\":\"assistant\",\"message\":{\"content\":[" ++ image("AA==") ++ "]}}\n")
    duplicate : String <- Store.import_file(db,"claude","duplicate.jsonl")
    request_failure(db,A.Request{duplicate,0,0,path(0)},"attachment_malformed_json","duplicate object keys cannot create ambiguous inline authority")
    Store.write_text("unaccepted.jsonl","w",record(image("AA==")))
    +unaccepted : String <- Store.import_file(db,"claude","unaccepted.jsonl")
    Store.exec(db,"UPDATE snapshots SET accepted=0 WHERE id=?",[Sql.Cell.Integer{unaccepted}])
    request_failure(db,A.Request{unaccepted,0,0,path(0)},"attachment_snapshot_not_accepted","unaccepted immutable capture is an ordinary typed request failure")

def integrity(+db: U32,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text("corrupt.jsonl","w",record(image("AA==")) ++ record(image("/w==")))
    +snapshot : String <- Store.import_file(db,"claude","corrupt.jsonl")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    child(self,["export",snapshot,"0","0",path(0),"corrupt.bin"],False{},"integrity","raw digest corruption fails before any publication")
    absent("corrupt.bin","corrupt raw publishes no destination")
    child(self,["export",snapshot,"1","0",path(0),"predecessor.bin"],False{},"predecessor integrity","predecessor corruption cannot lend a later physical boundary")
    absent("predecessor.bin","corrupt predecessor publishes no destination")
    Store.write_text("giant.jsonl","w",record(image("AA==")))
    +giant : String <- Store.import_file(db,"claude","giant.jsonl")
    Store.exec(db,"UPDATE raw SET n=1048576,bytes=zeroblob(1048576) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{giant}])
    child(self,["export",giant,"0","0",path(0),"giant.bin"],False{},"payload type or size admission","metadata-only admission rejects overlarge BLOB before payload transfer")
    absent("giant.bin","overlarge raw publishes no destination")
    child(self,["race"],False{},"destination appeared","publication race cannot replace exact destination")
    winner : List<&2,U32> <- read_bytes("race.bin")
    assert(Domain.bytes_equal(winner,[119,105,110,110,101,114]),"publication race preserves independently created winner bytes")

def race() -> IO(Unit):
  do IO<Unit>:
    +destination : String <- Paths.destination("race.bin")
    +temp : String <- Maintenance.temporary(destination)
    write_bytes(temp,[0,1,254,255])
    Store.write_text("race.bin","w","winner")
    Maintenance.publish(temp,destination)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    pure()
    +db : U32 <- Store.open(".build/attachment-inline.sqlite")
    basic(db,self)
    providers(db)
    malformed(db)
    positional(db)
    integrity(db,self)
    IO.try(Unit,Sql.close(db))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "export" <> snapshot <> record <> reference <> path <> destination <> []:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/attachment-inline.sqlite")
        value : A.Resolved <- export(db,snapshot,Store.number(record),Store.number(reference),path,destination)
        IO.try(Unit,Sql.close(db))
        IO.print("EXPORTED")
    case _ <> "race" <> []: race()
    case _: IO.die(Unit,2,"Invalid synthetic inline test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
