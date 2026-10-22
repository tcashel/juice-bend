import Base
import ../src/attachment_preview_worker.bend as W
import ../src/attachment_preview_packet.bend as P
import ../src/attachment_inline.bend as Inline
import ../src/attachment_decode.bend as Decode
import ../src/attachment_inventory_output.bend as Output
import ../src/attachment_inventory.bend as Inventory
import ../src/gui_attachments.bend as A
import ../src/json.bend as J
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/domain.bend as D
import ../src/paths.bend as Paths
import ./attachment_archive_export.bend as F
import ./png_fixtures.bend as PNG

def fixture() -> String: "{\"type\":\"user\",\"uuid\":\"synthetic-preview\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"iVBORw0KGgoAAAANSUhEUgAAAAIAAAABCAIAAAB7QOjdAAAAD0lEQVR42mPgUbLwi6oGAAPyAYpUTVf7AAAAAElFTkSuQmCC\"}}]}}\n"
# Independently calculated SHA256 of the committed 1|0|0|256| frame plus raw JSONL, not the bare source digest.
def raw_hash() -> String: "f6d310d3f5439af0a59d214e0bb84372a0676805053b11114acf780a943d79d3"
def byte_hash() -> String: "abe34935a44b0714231889bd0d8768c80ec1ca4a221928956c8e5f1af914f3c9"
def path() -> String: "/message/content/0/source/data"
def check(ok: Bool,label: String) -> IO(Unit): F.check(ok,label)

def json(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def expected(value: Inline.Resolved) -> P.Expected:
  Inline.Resolved{capture,_,_,_,_,_,_,_,_} = value
  P.Expected{json(J.parse(Output.capture(capture))),"1",A.OccurrenceKey{0,0,path(),0,256,raw_hash(),"image/png",72,True{}}}

def good(value: Result<&2,&2,String,Decode.Bytes>) -> Bool:
  match value:
    case Fail{_}: False{}
    case Done{Decode.Bytes{bytes,count,digest}}:
      U32.is_eq(count,72) && String.eq(digest,byte_hash()) && D.bytes_equal(bytes,PNG.rgb())

def refused(value: Result<&2,&2,String,Decode.Bytes>) -> Bool:
  match value:
    case Fail{_}: True{}
    case Done{_}: False{}

def absent(result: U32 & (String & String)) -> IO(Unit):
  (code,(out,error)) = result
  check(U32.is_eq(code,0) && String.is_empty(out) && String.is_empty(error),"synthetic source removed before fresh preview child")

def source_loss() -> IO(Unit):
  do IO<Unit>:
    value : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run("/bin/rm",["--","preview-source.jsonl.zst"],"",1024,2000))
    absent(value)

def child(+self: String,+root: String,+expected: P.Expected) -> IO(Result<&2,&2,String,Decode.Bytes>):
  do IO<Result<&2,&2,String,Decode.Bytes>>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run(self,"route" <> W.arguments(root,expected),"",2162688,30000)
    return W.completed(expected,result)

def suite(+self: String) -> IO(Unit):
  do IO<Unit>:
    +root : String <- Paths.destination(".build")
    +db : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    F.write_bytes("preview-source.jsonl.zst",F.raw_frame(D.encode(fixture())))
    +snapshot : String <- Capture.import_file(db,"claude","preview-source.jsonl.zst")
    check(String.eq(snapshot,"1"),"independent synthetic archive snapshot identity")
    resolved : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.resolve(db,Inline.Request{snapshot,0,0,path()})
    +value : Inline.Resolved <- F.need(Inline.Resolved,resolved)
    +identity : P.Expected = expected(value)
    +before : List<&2,List<&2,Sql.Cell>> <- Store.status(db)
    IO.try(Unit,Sql.close(db))
    source_loss()
    bytes : Result<&2,&2,String,Decode.Bytes> <- child(self,root,identity)
    check(good(bytes),"fresh archive-backed child returns independently specified exact PNG bytes after source deletion")
    +again : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    +after : List<&2,List<&2,Sql.Cell>> <- Store.status(again)
    check(String.eq(Store.field(Store.first(before),3n),Store.field(Store.first(after),3n)) && String.eq(Store.field(Store.first(before),4n),Store.field(Store.first(after),4n)),"preview preserves raw byte and event counts")
    Store.exec(again,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=1 AND ordinal=0)",[])
    IO.try(Unit,Sql.close(again))
    corrupt : Result<&2,&2,String,Decode.Bytes> <- child(self,root,identity)
    check(refused(corrupt),"corrupt retained raw kills only child and produces nonfatal typed parent refusal")
    check(True{},"parent remains alive after corrupt owned raw child failure")

def argv(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> "route" <> "--data-dir" <> root <> "attachment-preview-inline-v1" <> rest: W.root(root,rest)
    case _: IO.die(Unit,2,"Expected isolated preview child gate")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
