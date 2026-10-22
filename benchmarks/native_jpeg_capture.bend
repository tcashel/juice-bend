import Base
import ./native_activity.bend as Safe
import ./native_request_origin.bend as Origin
import ./native_archive.bend as Archive
import ./jpeg_preview_fixture.bend as F
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/domain.bend as D
import ../src/json.bend as J
import ../src/paths.bend as Paths
import ../src/maintenance.bend as Maintenance
import ../src/attachment_inline.bend as Inline
import ../src/attachment_inventory.bend as Inventory
import ../src/attachment_decode.bend as Decode

def message(content: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"native-jpeg-synthetic\",\"cwd\":\"/synthetic/jpeg-preview\",\"timestamp\":\"2026-10-21T12:00:00Z\",\"message\":{\"content\":" ++ content ++ "}}\n"

def inline(media: String,data: String) -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"base64\",\"media_type\":" ++ J.quote(media) ++ ",\"data\":" ++ J.quote(data) ++ "}}"

# The first two deliberately incorrect MIME claims prove the preview uses
# verified retained signatures. They never authorize a remote/source fetch.
def fixture() -> String:
  message("[" ++ inline("image/png",F.image_data()) ++ ",{\"type\":\"text\",\"text\":\"retained-jpeg-preview-search café 中文 🙂. Select this captured transcript text before opening the image.\"}]") ++
    message("[" ++ inline("image/jpeg",F.png_data()) ++ "]") ++
    message("[" ++ inline("image/jpeg",F.progressive_data()) ++ "]") ++
    message("[" ++ inline("image/jpeg","/9j/") ++ "]") ++
    message("[{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/not-fetched.jpg\"}}]") ++
    message("[{\"type\":\"text\",\"text\":\"Final ordinary record for exact reader selection and source-loss restart.\"}]")

def root_shape(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-jpeg-fixture-" : String}
  String.starts_with(root,prefix) && Origin.uuid(String.split(String.drop(root,String.length(prefix)),'-'))

def source(root: String) -> String: root ++ "/sources/preview.jsonl.zst"
def marker(root: String) -> String: root ++ "/.juice-bend-jpeg-fixture-v1.json"
def database(root: String) -> String: root ++ "/library/juice-bend.sqlite"
def reference_path() -> String: "/message/content/0/source/data"

def manifest(+root: String) -> String:
  "{\"fixture\":\"juice-bend-jpeg-fixture-v1\",\"synthetic\":true,\"root\":" ++ J.quote(root) ++
    ",\"data_dir\":" ++ J.quote(root ++ "/library") ++ ",\"source\":" ++ J.quote(source(root)) ++
    ",\"snapshot\":\"1\",\"source_removed\":true,\"provider\":\"claude\",\"encoding\":\"zstd-jsonl-v1\",\"records\":6,\"jpeg_record\":0,\"jpeg_reference\":0,\"jpeg_path\":" ++ J.quote(reference_path()) ++
    ",\"jpeg_declared_media\":\"image/png\",\"png_record\":1,\"png_declared_media\":\"image/jpeg\",\"progressive_record\":2,\"malformed_record\":3,\"remote_record\":4,\"jpeg_bytes\":" ++ U32.show(F.image_count()) ++
    ",\"jpeg_sha256\":" ++ J.quote(F.image_digest()) ++ ",\"png_bytes\":" ++ U32.show(F.png_count()) ++ ",\"png_sha256\":" ++ J.quote(F.png_digest()) ++
    ",\"width\":1024,\"height\":640,\"search\":\"retained-jpeg-preview-search\"}"

def checked_inline(result: Result<&2,&2,Inventory.Failure,Inline.Resolved>,record: U32,media: String,count: U32,digest: String) -> IO(Unit):
  match result:
    case Fail{Inventory.Failure{code,detail}}: IO.die(Unit,1,code ++ ": " ++ detail)
    case Done{Inline.Resolved{_,actual,_,_,_,reference,path,claimed,+data}}:
      Decode.Bytes{_,actual_count,actual_digest} = data
      Store.checked(U32.is_eq(actual,record) && U32.is_eq(reference,0) && String.eq(path,reference_path()) && String.eq(claimed,media) &&
        U32.is_eq(actual_count,count) && String.eq(actual_digest,digest) && Decode.valid(data),"Exact retained image occurrence or bytes differ from independent fixture")

def occurrence(+db: U32,+record: U32,media: String,count: U32,digest: String) -> IO(Unit):
  do IO<Unit>:
    value : Result<&2,&2,Inventory.Failure,Inline.Resolved> <- Inline.resolve(db,Inline.Request{"1",record,0,reference_path()})
    checked_inline(value,record,media,count,digest)

def verify(+db: U32) -> IO(Unit):
  do IO<Unit>:
    Safe.exact_capture(db,"1",fixture())
    Safe.scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1 AND records=6",[],"1")
    Safe.scalar(db,"SELECT count(*) FROM records WHERE snapshot=1",[],"6")
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Maintenance.verify(db,"1")
    occurrence(db,0,"image/png",F.image_count(),F.image_digest())
    occurrence(db,1,"image/jpeg",F.png_count(),F.png_digest())
    occurrence(db,2,"image/jpeg",F.progressive_count(),F.progressive_digest())
    occurrence(db,3,"image/jpeg",3,"6e568e1f67fba258184c78181539e5e8fdee447e49bb706fc0ea34fbf12336a5")

def reopen(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(root_shape(root),"Expected an owned synthetic JPEG root")
    canonical : String <- Paths.destination(root)
    Store.checked(String.eq(canonical,root),"Synthetic JPEG root must be canonical")
    Safe.exact_file(marker(root),manifest(root) ++ "\n")
    Safe.absent(source(root))
    Safe.regular_path(database(root),False{})
    +db : U32 <- IO.try(U32,Sql.open_existing(database(root),0))
    Store.exec(db,"PRAGMA foreign_keys=ON",[])
    verify(db)
    IO.try(Unit,Sql.close(db))
    IO.print(manifest(root))

def prepare(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(root_shape(root),"Expected a new /private/tmp/juice-bend-jpeg-fixture-UUID")
    canonical : String <- Paths.destination(root)
    Store.checked(String.eq(canonical,root),"Synthetic JPEG root must be canonical")
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(root ++ "/sources")
    Safe.directory(root ++ "/library")
    Safe.absent(source(root))
    Archive.write(source(root),Archive.raw_frame(D.encode(fixture())))
    Safe.private_file(source(root),"600")
    +db : U32 <- Store.open(database(root))
    snapshot : String <- Capture.import_file(db,"claude",source(root))
    Store.checked(String.eq(snapshot,"1"),"Expected initial JPEG snapshot1")
    verify(db)
    IO.try(Unit,Sql.close(db))
    _ : String <- Safe.command("/bin/rm",["--",source(root)])
    Safe.absent(source(root))
    Safe.absent(marker(root))
    Store.write_text(marker(root),"w",manifest(root) ++ "\n")
    Safe.private_file(marker(root),"400")
    reopen(root)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case Con{_,Con{"prepare",Con{root,Nil{}}}}: prepare(root)
    case Con{_,Con{"verify",Con{root,Nil{}}}}: reopen(root)
    case _: IO.die(Unit,2,"Expected prepare|verify and one owned synthetic JPEG root")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
