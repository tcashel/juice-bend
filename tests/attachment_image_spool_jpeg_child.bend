import Base
import ../src/attachment_image_spool_worker.bend as W
import ../src/attachment_preview_packet.bend as P
import ../src/attachment_inline.bend as Inline
import ../src/attachment_image_types.bend as Image
import ../src/attachment_image_binding.bend as H
import ../src/attachment_image_stream.bend as Stream
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
import ./attachment_image_stream.bend as StreamTest

def fixture() -> String: "{\"type\":\"user\",\"uuid\":\"synthetic-preview\",\"message\":{\"role\":\"user\",\"content\":[{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":\"image/png\",\"data\":\"/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAQDAwQDAwQEAwQFBAQFBgoHBgYGBg0JCggKDw0QEA8NDw4RExgUERIXEg4PFRwVFxkZGxsbEBQdHx0aHxgaGxr/wAALCAAIAAgBAREA/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/9oACAEBAAA/APkmv//Z\"}}]}}\n"
# Independently calculated SHA256 of the committed 1|0|0|604| frame plus raw JSONL, not the bare source digest.
def raw_hash() -> String: "9bf2555fccb6e51e6877966e68255b263b02115deb7ada4ed7a7838d72c22a16"
def byte_hash() -> String: "9cf273c7a0673577f0fc1f07b764f177e16b577ff71de44fa42b18392a82586f"
def path() -> String: "/message/content/0/source/data"
def check(ok: Bool,label: String) -> IO(Unit): F.check(ok,label)

def json(value: Result<&2,&2,String,J.Json>) -> J.Json:
  match value:
    case Done{value}: value
    case Fail{_}: J.JNull{}

def expected(value: Inline.Resolved) -> P.Expected:
  Inline.Resolved{capture,_,_,_,_,_,_,_,_} = value
  P.Expected{json(J.parse(Output.capture(capture))),"1",A.OccurrenceKey{0,0,path(),0,604,raw_hash(),"image/png",333,True{}}}

def good(value: Result<&2,&1,String,Image.Raster>) -> Bool:
  match value:
    case Done{Image.Raster{8,8,64,64,pixels,False{}}}: StreamTest.array_equal(List.replicate(U32,64n,623191551),pixels,0)
    case _: False{}

def refused(value: Result<&2,&1,String,Image.Raster>) -> Bool:
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

def child(self: String,root: String,expected: P.Expected) -> IO(Result<&2,&1,String,Image.Raster>):
  W.read(self,root,H.ExpectedInline{expected})

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
    bytes : Result<&2,&1,String,Image.Raster> <- child(self,root,identity)
    check(good(bytes),"fresh private-file archive-backed child returns independently specified exact JPEG pixels from deliberately wrong PNG MIME after source deletion")
    +again : U32 <- Store.open(root ++ "/juice-bend.sqlite")
    +after : List<&2,List<&2,Sql.Cell>> <- Store.status(again)
    check(String.eq(Store.field(Store.first(before),3n),Store.field(Store.first(after),3n)) && String.eq(Store.field(Store.first(before),4n),Store.field(Store.first(after),4n)),"preview preserves raw byte and event counts")
    Store.exec(again,"UPDATE raw SET bytes=zeroblob(n) WHERE id=(SELECT raw FROM records WHERE snapshot=1 AND ordinal=0)",[])
    IO.try(Unit,Sql.close(again))
    corrupt : Result<&2,&1,String,Image.Raster> <- child(self,root,identity)
    check(refused(corrupt),"corrupt retained raw kills only child and produces nonfatal typed parent refusal")
    check(True{},"parent remains alive after corrupt owned raw child failure")

def route(valid: Bool,root: String,args: List<String>) -> IO(Unit):
  match valid:
    case True{}: W.inline_root(root,args)
    case False{}: IO.die(Unit,2,"Expected isolated image child gate")

def argv(args: List<String>) -> IO(Unit):
  match args:
    case self <> []: suite(self)
    case _ <> option <> root <> command <> rest:
      route(String.eq(option,"--data-dir") && String.eq(command,W.inline_command()),root,rest)
    case _: IO.die(Unit,2,"Expected isolated image child gate")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
