import Base
import ../src/attachment_asset_identity.bend as A
import ../src/attachment_inventory.bend as I
import ../src/archive_meta.bend as Meta
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ../src/json.bend as J
import ../src/paths.bend as Paths

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need(-T: Kind(&2),result: Result<&2,&2,I.Failure,T>) -> IO(T):
  match result:
    case Done{value}: IO.pure(T,value)
    case Fail{I.Failure{code,_}}: IO.die(T,1,code)

def failed(result: Result<&2,&2,I.Failure,A.Resolved>,expected: String) -> Bool:
  match result:
    case Done{_}: False{}
    case Fail{I.Failure{code,_}}: String.eq(code,expected)

def strings(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case x <> xs y <> ys: String.eq(x,y) && strings(xs,ys)
    case _ _: False{}

def digest() -> String:
  "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

def header() -> Meta.Header:
  Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",40,2,20,1,True{},"identity"}

def with_header(capture: Meta.Header) -> A.Resolved:
  A.Resolved{capture,1,20,20,digest(),2,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}

def altered_header(index: U32) -> Meta.Header:
  match index:
    case 0: Meta.Header{"4","2","3","claude","/synthetic/原文",40,2,20,1,True{},"identity"}
    case 1: Meta.Header{"9223372036854775807","4","3","claude","/synthetic/原文",40,2,20,1,True{},"identity"}
    case 2: Meta.Header{"9223372036854775807","2","4","claude","/synthetic/原文",40,2,20,1,True{},"identity"}
    case 3: Meta.Header{"9223372036854775807","2","3","codex","/synthetic/原文",40,2,20,1,True{},"identity"}
    case 4: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/other",40,2,20,1,True{},"identity"}
    case 5: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",41,2,20,1,True{},"identity"}
    case 6: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",40,3,20,1,True{},"identity"}
    case 7: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",40,2,21,1,True{},"identity"}
    case 8: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",40,2,20,2,True{},"identity"}
    case 9: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",40,2,20,1,False{},"identity"}
    case _: Meta.Header{"9223372036854775807","2","3","claude","/synthetic/原文",40,2,20,1,True{},"zstd-jsonl-v1"}

def altered_tail(index: U32) -> A.Resolved:
  match index:
    case 0: A.Resolved{header(),0,20,20,digest(),2,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}
    case 1: A.Resolved{header(),1,21,20,digest(),2,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}
    case 2: A.Resolved{header(),1,20,19,digest(),2,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}
    case 3: A.Resolved{header(),1,20,20,"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",2,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}
    case 4: A.Resolved{header(),1,20,20,digest(),3,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}
    case 5: A.Resolved{header(),1,20,20,digest(),2,"/message/content/3/source/path","document",A.LocalPath{"/synthetic/a%20b#q"}}
    case 6: A.Resolved{header(),1,20,20,digest(),2,"/message/content/2/source/path","image",A.LocalPath{"/synthetic/a%20b#q"}}
    case 7: A.Resolved{header(),1,20,20,digest(),2,"/message/content/2/source/path","document",A.LocalFileURL{"/synthetic/a%20b#q"}}
    case _: A.Resolved{header(),1,20,20,digest(),2,"/message/content/2/source/path","document",A.LocalPath{"/synthetic/a b#q"}}

def headers(fuel: Nat,+index: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        assert(Bool.not(A.same(with_header(header()),with_header(altered_header(index)))),"same compares capture field " ++ U32.show(index))
        headers(rest,U32.inc(index))

def tails(fuel: Nat,+index: U32) -> IO(Unit):
  match fuel:
    case 0n: IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        assert(Bool.not(A.same(with_header(header()),altered_tail(index))),"same compares raw/reference field " ++ U32.show(index))
        tails(rest,U32.inc(index))

def repeat(fuel: Nat,+text: String) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: text ++ repeat(rest,text)

def pure() -> IO(Unit):
  do IO<Unit>:
    assert(strings(A.fields(with_header(header())),["9223372036854775807","2","3","claude","/synthetic/原文","40","2","20","1","true","identity",
      "1","20","20",digest(),"2","/message/content/2/source/path","document","local_path","/synthetic/a%20b#q"]),"all20 fields retain exact declared order and signed64 strings")
    assert(A.valid(with_header(header())) && A.same(with_header(header()),with_header(header())),"well-formed complete local identity validates and compares equal")
    assert(A.request_valid(A.request(with_header(header()))) && Bool.not(A.request_valid(A.Request{"01",0,0,"/x"})) &&
      Bool.not(A.request_valid(A.Request{"1",0,64,"/x"})) && Bool.not(A.request_valid(A.Request{"1",0,0,"relative"})),"request bounds preserve canonical snapshot and exact structural path")
    assert(A.request_valid(A.Request{"1",0,0,"/" ++ repeat(2047n,"a")}) &&
      Bool.not(A.request_valid(A.Request{"1",0,0,"/" ++ repeat(2048n,"a")})) &&
      Bool.not(A.request_valid(A.Request{"1",0,0,"/" ++ repeat(1024n,"é")})),"structural path bound counts exact UTF8 bytes")
    assert(Bool.not(A.valid(with_header(altered_header(9)))) && Bool.not(A.valid(altered_tail(0))) && Bool.not(A.valid(altered_tail(1))) &&
      Bool.not(A.valid(altered_tail(7))),"invalid acceptance physical bounds and mismatched local variants are refused")
    headers(11n,0)
    tails(9n,0)

def command_result(result: U32 & (String & String)) -> IO(String):
  match result:
    case (0,(out,_)): IO.pure(String,out)
    case _: IO.die(String,1,"Synthetic test OS primitive failed")

def command(program: String,args: List<String>) -> IO(String):
  do IO<String>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",8192,10000))
    command_result(result)

def create_root() -> IO(String):
  do IO<String>:
    temporary : String <- command("/usr/bin/mktemp",["-d","/tmp/juice-bend-asset-identity.XXXXXX"])
    +root : String <- Paths.resolve(String.trim(temporary))
    Store.write_text(root ++ "/owned-test","w","attachment-asset-identity-v1\n")
    return root

def root_valid(+root: String) -> Bool:
  (String.starts_with(root,"/private/tmp/juice-bend-asset-identity.") || String.starts_with(root,"/tmp/juice-bend-asset-identity.")) &&
    Bool.not(String.contains(root,"/../")) && Bool.not(String.contains(root,"\0")) &&
    Nat.is_eq(List.length(&2,String,String.split(root,'/')),Bool.pick(Nat,String.starts_with(root,"/private/"),4n,3n))

def read_closed(value: File & Result<&1,&1,U32 & String,List<&2,U32>>) -> IO(List<&2,U32>):
  (file,result) = value
  do IO<List<&2,U32>>:
    File.close(file)
    IO.try(List<&2,U32>,IO.pure(Result<&1,&1,U32 & String,List<&2,U32>>,result))

def guard(+root: String) -> IO(Unit):
  do IO<Unit>:
    assert(root_valid(root),"only owned synthetic root accepted")
    canonical : String <- Paths.resolve(root)
    assert(String.eq(canonical,root),"synthetic root is canonical")
    file : File <- IO.try(File,File.open(root ++ "/owned-test","r"))
    got : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,64)
    marker : List<&2,U32> <- read_closed(got)
    assert(D.bytes_equal(marker,D.encode("attachment-asset-identity-v1\n")),"owned synthetic root marker verified")

def write_bytes(path: String,bytes: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    Store.write_closed(written)

def remove(path: String) -> IO(Unit):
  do IO<Unit>:
    removed : String <- command("/bin/rm",["--",path])
    return Unit{}

def image(path: String) -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":" ++ J.quote(path) ++ "}}"

def record(content: String) -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[" ++ content ++ "]}}\n"

def local_value() -> String: "/synthetic/never-read a%20b#q.png"
def file_url() -> String: "file://localhost/synthetic/a%20b%2Fc.png?raw=%25#fragment"

def fixture() -> String:
  record(image(local_value())) ++ record(image(local_value()) ++ "," ++ image(local_value()) ++
    ",{\"type\":\"tool_result\",\"content\":[{\"type\":\"document\",\"source\":{\"type\":\"file\",\"path\":" ++ J.quote(file_url()) ++ "}}]}")

def path(index: U32) -> String:
  "/message/content/" ++ U32.show(index) ++ "/source/path"

def get(db: U32,snapshot: String,record: U32,reference: U32,path: String) -> IO(A.Resolved):
  do IO<A.Resolved>:
    result : Result<&2,&2,I.Failure,A.Resolved> <- A.resolve(db,A.Request{snapshot,record,reference,path})
    need(A.Resolved,result)

def request_failure(db: U32,request: A.Request,code: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,I.Failure,A.Resolved> <- A.resolve(db,request)
    assert(failed(result,code),label)

def local_equals(value: A.Resolved,expected: String,fileurl: Bool) -> Bool:
  match value fileurl:
    case A.Resolved{_,_,_,_,_,_,_,_,A.LocalPath{actual}} False{}: String.eq(actual,expected)
    case A.Resolved{_,_,_,_,_,_,_,_,A.LocalFileURL{actual}} True{}: String.eq(actual,expected)
    case _ _: False{}

# Independent constants bind Store's documented generation/position framing,
# not just the payload SHA. A bare-byte digest would weaken physical identity.
def exact_first(value: A.Resolved,root: String,encoding: String) -> Bool:
  A.Resolved{Meta.Header{snapshot,source,generation,provider,locator,extent,records,_,_,accepted,codec},ordinal,offset,length,sha,reference,path,kind,local} = value
  String.eq(snapshot,"1") && String.eq(source,"1") && String.eq(generation,"1") && String.eq(provider,"claude") &&
    String.eq(locator,root ++ "/plain.jsonl") && U32.is_eq(extent,U32.from_nat(List.length(&2,U32,D.encode(fixture())))) &&
    U32.is_eq(records,2) && accepted && String.eq(codec,encoding) && U32.is_eq(ordinal,0) && U32.is_eq(offset,0) &&
    U32.is_eq(length,U32.from_nat(List.length(&2,U32,D.encode(record(image(local_value())))))) &&
    String.eq(sha,"02c63cd1a0eba41887bd88c0d8f91e357cd679b5d15e4dbe02332d04007a8b3a") && U32.is_eq(reference,0) &&
    String.eq(path,"/message/content/0/source/path") && String.eq(kind,"image") &&
    strings(A.local_fields(local),["local_path",local_value()])

def json_fields(fields: List<&2,String>) -> List<&2,J.Json>:
  match fields:
    case []: []
    case value <> rest: J.JString{value} <> json_fields(rest)

def identity_json(value: A.Resolved) -> String:
  J.encode(J.JArray{json_fields(A.fields(value))})

def child_result(value: U32 & (String & String),success: Bool,needle: String,label: String) -> IO(Unit):
  (+code,(out,err)) = value
  assert(Bool.pick(Bool,success,U32.is_eq(code,0),U32.is_ne(code,0)) && String.contains(out ++ err,needle),label)

def child(self: String,root: String,snapshot: String,record: String,reference: String,path: String,success: Bool,needle: String,label: String) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(self,["resolve",root,snapshot,record,reference,path],"",8192,30000))
    child_result(result,success,needle,label)

def plain(+db: U32,+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(root ++ "/plain.jsonl","w",fixture())
    +snapshot : String <- Capture.import_file(db,"claude",root ++ "/plain.jsonl")
    +first : A.Resolved <- get(db,snapshot,0,0,path(0))
    +duplicate_a : A.Resolved <- get(db,snapshot,1,0,path(0))
    +duplicate_b : A.Resolved <- get(db,snapshot,1,1,path(1))
    nested : A.Resolved <- get(db,snapshot,1,2,"/message/content/2/content/0/source/path")
    assert(exact_first(first,root,"identity") && A.valid(first),"image-only physical record resolves exact retained plain identity")
    assert(local_equals(duplicate_a,local_value(),False{}) && local_equals(duplicate_b,local_value(),False{}) &&
      Bool.not(A.same(first,duplicate_a)) && Bool.not(A.same(duplicate_a,duplicate_b)),"equal references remain distinct across raw records and content positions")
    assert(local_equals(nested,file_url(),True{}),"nested document fileURL spelling preserves percent escapes query and fragment exactly")
    request_failure(db,A.Request{snapshot,1,0,path(1)},"attachment_occurrence_path_mismatch","wrong path cannot redirect an existing reference ordinal")
    request_failure(db,A.Request{snapshot,1,0,"/message/content/00/source/path"},"attachment_occurrence_path_mismatch","equivalent-looking array path cannot alias occurrence identity")
    request_failure(db,A.Request{snapshot,1,3,path(0)},"attachment_occurrence_not_found","unseen reference ordinal is refused")
    request_failure(db,A.Request{snapshot,2,0,path(0)},"attachment_record_not_found","past-end physical record is refused")
    request_failure(db,A.Request{"9223372036854775807",0,0,path(0)},"attachment_snapshot_not_found","missing signed64 snapshot fails without numeric truncation")
    request_failure(db,A.Request{"01",0,0,path(0)},"attachment_invalid_request","noncanonical snapshot is refused before transaction")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    borrowed : Result<&2,&2,I.Failure,A.Resolved> <- A.resolve(db,A.Request{snapshot,0,0,path(0)})
    assert(failed(borrowed,"attachment_transaction_unavailable"),"public resolver does not borrow or roll back caller transaction")
    owned : Result<&2,&2,I.Failure,A.Resolved> <- A.resolve_owned(db,A.Request{snapshot,0,0,path(0)})
    exact : A.Resolved <- need(A.Resolved,owned)
    assert(A.same(first,exact),"internal resolver uses the caller-owned write transaction without ending it")
    Store.exec(db,"ROLLBACK",[])
    Store.exec(db,"UPDATE events SET body='forged',arguments='forged' WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    Store.write_text(root ++ "/plain.jsonl","w",record(image("/synthetic/new-reference.png")))
    rewritten : String <- Capture.import_file(db,"claude",root ++ "/plain.jsonl")
    assert(Bool.not(String.eq(snapshot,rewritten)),"rewritten source creates a separate pinned capture")
    remove(root ++ "/plain.jsonl")
    old : A.Resolved <- get(db,snapshot,0,0,path(0))
    assert(A.same(first,old),"source rewrite removal and forged projection cannot change retained reference authority")
    child(self,root,snapshot,"0","0",path(0),True{},"RESOLVED " ++ identity_json(first),"new process reopens exact original local reference after source loss")

def raw_frame(+bytes: List<&2,U32>) -> List<&2,U32>:
  +descriptor = U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),8),1)
  List.append(&2,U32,[40,181,47,253,0,56,U32.and(descriptor,255),U32.and(U32.shrn(descriptor,8n),255),U32.and(U32.shrn(descriptor,16n),255)],bytes)

def archive_value(value: A.Resolved) -> Bool:
  A.Resolved{Meta.Header{snapshot,source,generation,provider,_,+extent,records,_,_,accepted,encoding},ordinal,offset,length,sha,reference,path,kind,local} = value
  String.eq(snapshot,"3") && String.eq(source,"2") && String.eq(generation,"3") &&
    String.eq(provider,"claude") && String.eq(encoding,"zstd-jsonl-v1") && accepted && U32.is_eq(records,1) &&
    U32.is_eq(extent,U32.from_nat(List.length(&2,U32,D.encode(record(image(file_url())))))) &&
    U32.is_eq(ordinal,0) && U32.is_eq(offset,0) && U32.is_eq(length,extent) && U32.is_eq(reference,0) &&
    String.eq(path,"/message/content/0/source/path") && String.eq(kind,"image") &&
    String.eq(sha,"5cb7aaf69810338a88a91e6c97414e659decc8319ec4ed2a0c6a91972dcbcb50") && strings(A.local_fields(local),["local_file_url",file_url()])

def archive(+db: U32,+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    write_bytes(root ++ "/local.jsonl.zst",raw_frame(D.encode(record(image(file_url())))))
    +snapshot : String <- Capture.import_file(db,"claude",root ++ "/local.jsonl.zst")
    +before : A.Resolved <- get(db,snapshot,0,0,path(0))
    assert(archive_value(before) && A.valid(before),"real zstd retained logical record resolves exact local-fileURL identity")
    remove(root ++ "/local.jsonl.zst")
    after : A.Resolved <- get(db,snapshot,0,0,path(0))
    assert(A.same(before,after),"compressed source deletion preserves every capture and raw reference field")
    child(self,root,snapshot,"0","0",path(0),True{},"RESOLVED " ++ identity_json(before),"new process resolves archive-owned local reference with original source absent")

def codex_value(value: A.Resolved) -> Bool:
  A.Resolved{Meta.Header{_,_,_,provider,_,_,_,_,_,_,encoding},ordinal,offset,_,_,reference,path,kind,local} = value
  String.eq(provider,"codex") && String.eq(encoding,"identity") && U32.is_eq(ordinal,0) && U32.is_eq(offset,0) &&
    U32.is_eq(reference,0) && String.eq(path,"/payload/content/0/image_url/url") && String.eq(kind,"input_image") &&
    strings(A.local_fields(local),["local_file_url","file:///synthetic/a%20b#q"])

def codex(+db: U32,+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(root ++ "/codex.jsonl","w","{\"type\":\"response_item\",\"payload\":{\"type\":\"message\",\"role\":\"user\",\"content\":[{\"type\":\"input_image\",\"image_url\":{\"url\":\"file:///synthetic/a%20b#q\"}}]}}\n")
    snapshot : String <- Capture.import_file(db,"codex",root ++ "/codex.jsonl")
    +value : A.Resolved <- get(db,snapshot,0,0,"/payload/content/0/image_url/url")
    assert(codex_value(value) && A.valid(value),"Codex nested image URL retains exact local variant kind and structural path")

def refusals(+db: U32,+root: String) -> IO(Unit):
  +fixture = record("{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/never-fetch\"}}") ++
    record("{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"data\":\"AA==\"}}") ++
    record("{\"type\":\"image\",\"source\":{\"type\":\"future_blob\",\"id\":\"synthetic\"}}") ++ "{bad}\n" ++
    "{\"type\":\"user\",\"type\":\"assistant\",\"message\":{\"content\":[" ++ image(local_value()) ++ "]}}\n" ++ record(image("not-an-absolute-local-path.png"))
  do IO<Unit>:
    Store.write_text(root ++ "/refusals.jsonl","w",fixture)
    +snapshot : String <- Capture.import_file(db,"claude",root ++ "/refusals.jsonl")
    request_failure(db,A.Request{snapshot,0,0,"/message/content/0/source/url"},"attachment_not_supported_local","remote URL remains unfetched and is not a local reference")
    request_failure(db,A.Request{snapshot,1,0,"/message/content/0/source/data"},"attachment_not_supported_local","inline representation is not external local authority")
    request_failure(db,A.Request{snapshot,2,0,"/message/content/0/source"},"attachment_not_supported_local","unknown source type cannot authorize a file")
    request_failure(db,A.Request{snapshot,3,0,path(0)},"attachment_malformed_json","malformed retained JSON is typed refusal")
    request_failure(db,A.Request{snapshot,4,0,path(0)},"attachment_malformed_json","duplicate JSON keys cannot provide ambiguous authority")
    request_failure(db,A.Request{snapshot,5,0,path(0)},"attachment_not_supported_local","relative references are not normalized into external authority")
    write_bytes(root ++ "/invalid.jsonl",List.append(&2,U32,[255,10],D.encode(repeat(262145n,"x") ++ "\n")))
    +invalid : String <- Capture.import_file(db,"claude",root ++ "/invalid.jsonl")
    request_failure(db,A.Request{invalid,0,0,path(0)},"attachment_invalid_utf8","nonUTF8 retained raw is refused before JSON")
    request_failure(db,A.Request{invalid,1,0,path(0)},"attachment_oversized_record","oversized raw prefix is refused before JSON")
    request_failure(db,A.Request{invalid,2,0,path(0)},"attachment_oversized_record","oversized raw continuation is refused with exact predecessor validation")
    Store.write_text(root ++ "/partial.jsonl","w",record("{\"type\":\"future_unknown\"}," ++ image(local_value())))
    partial : String <- Capture.import_file(db,"claude",root ++ "/partial.jsonl")
    +known : A.Resolved <- get(db,partial,0,0,path(1))
    assert(local_equals(known,local_value(),False{}) && A.valid(known),"known exact local occurrence remains usable beside unknown content without claiming complete coverage")
    Store.exec(db,"UPDATE snapshots SET accepted=0 WHERE id=?",[Sql.Cell.Integer{snapshot}])
    request_failure(db,A.Request{snapshot,0,0,path(0)},"attachment_snapshot_not_accepted","unaccepted capture is typed refusal")

def integrity(+db: U32,+root: String,+self: String) -> IO(Unit):
  do IO<Unit>:
    Store.write_text(root ++ "/corrupt.jsonl","w",record(image(local_value())) ++ record(image(local_value())))
    +snapshot : String <- Capture.import_file(db,"claude",root ++ "/corrupt.jsonl")
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{snapshot}])
    child(self,root,snapshot,"0","0",path(0),False{},"integrity","stale selected raw digest is refused by unchanged authoritative verifier")
    child(self,root,snapshot,"1","0",path(0),False{},"predecessor integrity","stale predecessor cannot supply the next physical boundary")
    Store.write_text(root ++ "/giant.jsonl","w",record(image(local_value())))
    +giant : String <- Capture.import_file(db,"claude",root ++ "/giant.jsonl")
    Store.exec(db,"UPDATE raw SET n=1048576,bytes=zeroblob(1048576) WHERE id=(SELECT raw FROM records WHERE snapshot=? AND ordinal=0)",[Sql.Cell.Integer{giant}])
    child(self,root,giant,"0","0",path(0),False{},"payload type or size admission","metadata admission refuses oversized corrupt BLOB before loading raw bytes")

def suite(self: String) -> IO(Unit):
  do IO<Unit>:
    pure()
    +root : String <- create_root()
    guard(root)
    +program : String <- Paths.resolve(self)
    +db : U32 <- Store.open(root ++ "/library.sqlite")
    plain(db,root,program)
    archive(db,root,program)
    codex(db,root)
    refusals(db,root)
    integrity(db,root,program)
    IO.try(Unit,Sql.close(db))
    IO.print("Synthetic asset identity test root: " ++ root)

def child_resolve(+root: String,snapshot: String,record: String,reference: String,path: String) -> IO(Unit):
  do IO<Unit>:
    guard(root)
    +db : U32 <- IO.try(U32,Sql.open_existing(root ++ "/library.sqlite",0))
    +value : A.Resolved <- get(db,snapshot,Store.number(record),Store.number(reference),path)
    assert(A.valid(value),"reopened identity is complete and bounded")
    IO.try(Unit,Sql.close(db))
    IO.print("RESOLVED " ++ identity_json(value))

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "resolve" <> root <> snapshot <> record <> reference <> path <> []: child_resolve(root,snapshot,record,reference,path)
    case _: IO.die(Unit,2,"Invalid owned synthetic asset identity test arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
