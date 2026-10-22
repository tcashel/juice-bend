import Base
import ../src/attachment_cli.bend as C
import ../src/attachment_inventory.bend as Inventory
import ../src/attachment_inventory_output.bend as Output
import ../src/attachment_inline.bend as Inline
import ../src/attachment_decode.bend as Decode
import ../src/archive_meta.bend as Meta
import ../src/capture.bend as Capture
import ../src/domain.bend as Domain
import ../src/json.bend as Json
import ../src/paths.bend as Paths
import ../src/store.bend as Store
import ../src/sql.bend as Sql

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need(-T: Kind(&2),result: Result<&2,&2,Inventory.Failure,T>) -> IO(T):
  match result:
    case Done{value}: IO.pure(T,value)
    case Fail{Inventory.Failure{code,_}}: IO.die(T,1,code)

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
    read : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,1024)
    read_closed(read)

# A synthetic standard zstd frame with one final RAW block. These constants are
# a transport fixture, not a call into the archive decoder or an external codec.
def raw_frame(+bytes: List<&2,U32>) -> List<&2,U32>:
  +descriptor = U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),8),1)
  List.append(&2,U32,[40,181,47,253,0,56,U32.and(descriptor,255),
    U32.and(U32.shrn(descriptor,8n),255),U32.and(U32.shrn(descriptor,16n),255)],bytes)

def fixture() -> String:
  "{\"type\":\"user\",\"message\":{\"content\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"application/octet-stream\",\"data\":\"AAH+/w==\"}}]}}\n"

def path() -> String:
  "/message/content/0/source/data"

def raw_length() -> U32:
  U32.from_nat(List.length(&2,U32,Domain.encode(fixture())))

def resolved_bytes(value: Inline.Resolved) -> Bool:
  Inline.Resolved{Meta.Header{_,_,_,provider,_,extent,total,_,_,_,encoding},record,offset,length,_,reference,actual_path,_,Decode.Bytes{bytes,count,_}} = value
  String.eq(provider,"claude") && String.eq(encoding,"zstd-jsonl-v1") &&
    U32.is_eq(extent,raw_length()) && U32.is_eq(total,1) && U32.is_eq(record,0) &&
    U32.is_eq(offset,0) && U32.is_eq(length,raw_length()) && U32.is_eq(reference,0) &&
    String.eq(actual_path,path()) && U32.is_eq(count,4) && Domain.bytes_equal(bytes,[0,1,254,255])

def removed(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  check(U32.is_eq(code,0),"synthetic compressed source removed before restart")

def remove_source() -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--","owned-inline.jsonl.zst"],"",1024,2000))
    removed(result)

def absent_result(result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Fail{(code,_)}: check(U32.is_eq(code,2),"original compressed source remains absent")
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        check(False{},"original compressed source remains absent")

def absent_source() -> IO(Unit):
  do IO<Unit>:
    result : Result<&1,&1,U32 & String,File> <- File.open("owned-inline.jsonl.zst","r")
    absent_result(result)

def child(self: String,command: String,args: List<String>) -> IO(U32 & (String & String)):
  do IO<U32 & (String & String)>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run(self,"route" <> command <> args,"",262144,30000))
    return result

def successful(result: U32 & (String & String),expected: String,label: String) -> IO(Unit):
  (code,(out,err)) = result
  check(U32.is_eq(code,0) && String.eq(out,expected ++ "\n") && String.is_empty(err),label)

def no_clobber(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,err)) = result
  check(U32.is_ne(code,0) && String.is_empty(out) && String.contains(err,"already exists"),
    "second fresh process cannot replace an existing exported attachment")

def inventory_text(result: Result<&2,&2,Inventory.Failure,Inventory.Page>) -> IO(String):
  do IO<String>:
    page : Inventory.Page <- need(Inventory.Page,result)
    need(String,Output.encode(page))

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/attachment-archive-export.sqlite")
    write_bytes("owned-inline.jsonl.zst",raw_frame(Domain.encode(fixture())))
    +snapshot : String <- Capture.import_file(db,"claude","owned-inline.jsonl.zst")
    result : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.resolve(db,Inline.Request{snapshot,0,0,path()})
    +verified : Inline.Resolved <- need(Inline.Resolved,result)
    check(resolved_bytes(verified),"archive inline resolution uses exact retained logical record and independent binary octets")
    +destination : String <- Paths.destination("archive-owned.bin")
    +expected_ack : String <- need(String,C.acknowledge(verified,destination))
    check(String.contains(expected_ack,"\"encoding\":\"zstd-jsonl-v1\"") &&
      String.contains(expected_ack,"\"byte_space\":\"logical_source_bytes\"") &&
      Bool.not(String.contains(expected_ack,"AAH+/w==")),"archive acknowledgement identifies logical byte space without its inline payload")
    inventory : Result<&2,&2,Inventory.Failure,Inventory.Page> <- Inventory.read(db,snapshot,0,1)
    +expected_inventory : String <- inventory_text(inventory)
    IO.try(Unit,Sql.close(db))
    remove_source()
    absent_source()
    exported : U32 & (String & String) <- child(self,"export-inline",[snapshot,"0","0",path(),destination])
    successful(exported,expected_ack,"new process exports archive-retained inline bytes after database close and source deletion with exact acknowledgement")
    bytes : List<&2,U32> <- read_bytes("archive-owned.bin")
    check(Domain.bytes_equal(bytes,[0,1,254,255]),"exported archive attachment preserves literal NUL and nonUTF8 binary bytes")
    listed : U32 & (String & String) <- child(self,"attachments",[snapshot,"0","1"])
    successful(listed,expected_inventory,"new process inventory is byte-for-byte stable after compressed source loss")
    again : U32 & (String & String) <- child(self,"export-inline",[snapshot,"0","0",path(),destination])
    no_clobber(again)
    unchanged : List<&2,U32> <- read_bytes("archive-owned.bin")
    check(Domain.bytes_equal(unchanged,[0,1,254,255]),"refused repeated archive export preserves existing destination exactly")
    absent_source()

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "route" <> command <> rest:
      do IO<Unit>:
        +db : U32 <- Store.open(".build/attachment-archive-export.sqlite")
        C.run(db,command,rest)
        IO.try(Unit,Sql.close(db))
    case _: IO.die(Unit,2,"Invalid synthetic archive export arguments")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
