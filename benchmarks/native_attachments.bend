import Base
import ./native_activity.bend as Safe
import ./native_request_origin.bend as Origin
import ./native_archive.bend as ArchiveFixture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/domain.bend as Domain
import ../src/paths.bend as Paths
import ../src/json.bend as J

# Synthetic actual-app acceptance preparation. The only accepted operation
# creates a new canonical private /private/tmp/juice-bend-attachments-fixture-UUID
# root. All 42 physical records are retained in one real zstd archive snapshot.
# The source is closed and removed before completion; no external reference is
# opened. These expected positions and counts are specified independently of
# the extractor. Actual app navigation/export is a separate native gate.
def root_shape(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-attachments-fixture-" : String}
  String.starts_with(root,prefix) && Origin.uuid(String.split(String.drop(root,String.length(prefix)),'-'))

def source(root: String) -> String:
  root ++ "/sources/attachment-fixture.jsonl.zst"

def marker(root: String) -> String:
  root ++ "/.juice-bend-attachments-fixture-v1.json"

def message(role: String,content: String) -> String:
  "{\"type\":" ++ J.quote(role) ++ ",\"sessionId\":\"native-attachments-synthetic\",\"cwd\":\"/synthetic/attachments\"," ++
    "\"timestamp\":\"2026-10-20T12:00:00Z\",\"message\":{\"content\":" ++ content ++ "}}\n"

def inline(kind: String,data: String) -> String:
  "{\"type\":" ++ J.quote(kind) ++ ",\"source\":{\"type\":\"base64\",\"media_type\":\"application/octet-stream\",\"data\":" ++ J.quote(data) ++ "}}"

def binary_image() -> String:
  inline("image","AAH+/w==")

def zero_image() -> String:
  message("user","[" ++ inline("image","") ++ "]")

def text(body: String) -> String:
  message("user","[{\"type\":\"text\",\"text\":" ++ J.quote(body) ++ "}]")

def record(index: U32) -> String:
  match index:
    case 0: message("user","[" ++ binary_image() ++ "]")
    case 1: text("attachment-native-search — Preserve this synthetic attachment fixture, café 中文 🙂.\nKeep the exact tool request and result after source removal.\n```bend\nlet preserved = 42\n```\nThe first reader range contains four raw-record attachment pages.")
    case 2: zero_image()
    case 3: zero_image()
    case 4: message("user","[" ++ inline("image","AB==") ++ "]")
    case 5: message("user","[{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":\"/synthetic/never-read/local-photo.png\"}}]")
    case 6: message("user","[{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/never-fetched.png?synthetic=1\"}}]")
    case 7: message("user","[{\"type\":\"image\",\"source\":{\"type\":\"future_blob\",\"id\":\"synthetic-unsupported\"}}]")
    case 8: message("user","[{\"type\":\"tool_result\",\"tool_use_id\":\"synthetic-nested\",\"content\":[{\"type\":\"text\",\"text\":\"Nested retained attachment follows\"}," ++ binary_image() ++ "]}]")
    case 9: message("assistant","[{\"type\":\"tool_use\",\"name\":\"Write\",\"id\":\"synthetic-write-9\",\"input\":{\"file_path\":\"synthetic-only.txt\",\"content\":\"let preserved = 42\\n// café 中文 🙂\\n\",\"nested_artifact_probe\":[" ++ binary_image() ++ "]}}]")
    case 10: message("user","[" ++ binary_image() ++ "]")
    case 11: message("user","[]")
    case 12: message("user","[{\"type\":\"future_content_block\",\"note\":\"Synthetic unknown container; total unknown\"}]")
    case 13: text("Prose mention /synthetic/not-an-attachment.png and data:image/png;base64,AA== is text, not an attachment container.")
    case 14: "{\"type\":\"synthetic_future_record\",\"sessionId\":\"native-attachments-synthetic\",\"note\":\"Preserved unknown provider record\"}\n"
    case 15: message("user","[" ++ inline("document","AAH+/w==") ++ "]")
    case 16: message("user","[{\"type\":\"tool_result\",\"tool_use_id\":\"synthetic-write-9\",\"content\":\"Saved synthetic-only.txt; result marker attachment-tool-result café 中文 🙂.\\nThis is recorded synthetic evidence; no tool command was executed.\"}]")
    case 17: message("user","null")
    case 18: "{\"type\":\"system\",\"sessionId\":\"native-attachments-synthetic\",\"message\":\"Synthetic metadata only\"}\n"
    case 19: message("user","[]")
    case 20: message("user","[" ++ binary_image() ++ "]")
    case 21: message("user","[{\"type\":\"late_unknown_block\",\"note\":\"Late partial coverage remains visible\"}]")
    case 22: text("Final native attachments record: the source archive is absent and all retained records remain addressable.")
    case 40: text("attachment-late-40 café 中文 🙂\nThe second transcript page begins at physical record 40.\nCaptured text remains readable after the archive source was removed.")
    case 41: message("assistant",J.quote("attachment-late-41 — final retained record.\nExact response: preserved = 42; café 中文 🙂.\nThere are no attachment references on this final two-record page."))
    case other: text("Ordinary no-attachment trailing record " ++ U32.show(other) ++ ": preserved after source removal; transcript paging stays pinned.")

def records(fuel: Nat,+ordinal: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest: record(ordinal) ++ records(rest,U32.inc(ordinal))

def fixture() -> String:
  records(42n,0)

# Independent binary oracle: [0,1,254,255]. Empty exports are exactly zero bytes.
# Digest constants were independently calculated outside the Bend decoder.
def binary_sha256() -> String:
  "c5dbae22661af6db18a1f676db82a7ef7de46d27c3a263a872f00478b0d99fc4"

def empty_sha256() -> String:
  "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

def expected(record: U32,path: String,bytes: U32,digest: String) -> String:
  "{\"record\":" ++ U32.show(record) ++ ",\"reference\":0,\"path\":" ++ J.quote(path) ++
    ",\"decoded_bytes\":" ++ U32.show(bytes) ++ ",\"sha256\":" ++ J.quote(digest) ++ "}"

def direct_path() -> String:
  "/message/content/0/source/data"

def export_expectations() -> String:
  "[" ++ String.join([
    expected(0,direct_path(),4,binary_sha256()),
    expected(2,direct_path(),0,empty_sha256()),
    expected(3,direct_path(),0,empty_sha256()),
    expected(8,"/message/content/0/content/1/source/data",4,binary_sha256()),
    expected(10,direct_path(),4,binary_sha256()),
    expected(15,direct_path(),4,binary_sha256()),
    expected(20,direct_path(),4,binary_sha256())],",") ++ "]"

def manifest(+root: String,snapshot: String) -> String:
  "{\"fixture\":\"juice-bend-attachments-fixture-v1\",\"synthetic\":true,\"root\":" ++ J.quote(root) ++
    ",\"data_dir\":" ++ J.quote(root ++ "/library") ++ ",\"snapshot\":" ++ J.quote(snapshot) ++
    ",\"source\":" ++ J.quote(source(root)) ++ ",\"source_removed\":true,\"provider\":\"claude\",\"encoding\":\"zstd-jsonl-v1\"," ++
    "\"logical_bytes\":" ++ U32.show(U32.from_nat(List.length(&2,U32,Domain.encode(fixture())))) ++
    ",\"reader_start\":0,\"reader_requested\":40,\"reader_selected\":40,\"expected_reader_events\":38,\"physical_records\":42,\"raw_scope\":\"all references in captured records; no repository role or time filters\"," ++
    "\"pages\":[{\"start\":0,\"count\":10,\"occurrences\":8,\"complete\":10,\"partial\":0},{\"start\":10,\"count\":10,\"occurrences\":2,\"complete\":7,\"partial\":3},{\"start\":20,\"count\":10,\"occurrences\":1,\"complete\":9,\"partial\":1},{\"start\":30,\"count\":10,\"occurrences\":0,\"complete\":10,\"partial\":0}]," ++
    "\"second_reader_start\":40,\"second_reader_requested\":40,\"second_reader_selected\":2,\"expected_second_reader_events\":2,\"second_reader_pages\":[{\"start\":40,\"count\":2,\"occurrences\":0,\"complete\":2,\"partial\":0}]," ++
    "\"inline_exports\":" ++ export_expectations() ++ ",\"invalid_base64_record\":4,\"uncaptured_local_record\":5,\"remote_record\":6,\"unsupported_source_record\":7," ++
    "\"tool_arguments_ignored_record\":9,\"prose_ignored_record\":13,\"empty_records\":[11,19],\"partial_records\":[12,14,17,21]}"

def source_exact(+path: String,expected: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    Safe.regular_path(path,False{})
    file : File <- IO.try(File,File.open(path,"r"))
    got : File & Result<&1,&1,U32 & String,List<&2,U32>> <- File.read_bytes(file,131082)
    actual : List<&2,U32> <- Safe.read_finished(got)
    Store.checked(Domain.bytes_equal(actual,expected),"Native attachments archive bytes differ from the exact owned fixture")

def prepare(+root: String) -> IO(Unit):
  +bytes = Domain.encode(fixture())
  +compressed = ArchiveFixture.raw_frame(bytes)
  do IO<Unit>:
    Store.checked(U32.is_le(U32.from_nat(List.length(&2,U32,bytes)),131072),"Native attachment fixture must fit one standard zstd RAW block")
    Safe.directory(root)
    Safe.regular_path(root,True{})
    Safe.directory(root ++ "/sources")
    Safe.directory(root ++ "/library")
    Safe.absent(source(root))
    ArchiveFixture.write(source(root),compressed)
    Safe.private_file(source(root),"600")
    source_exact(source(root),compressed)
    +db : U32 <- Store.open(root ++ "/library/juice-bend.sqlite")
    +snapshot : String <- Capture.import_file(db,"claude",source(root))
    Store.checked(String.eq(snapshot,"1"),"Unexpected first native attachment capture identity")
    Safe.scalar(db,"SELECT count(*) FROM snapshots p JOIN generations g ON g.id=p.generation WHERE p.id=? AND p.accepted=1 AND p.records=42 AND g.encoding='zstd-jsonl-v1'",[Sql.Cell.Integer{snapshot}],"1")
    Safe.exact_capture(db,snapshot,fixture())
    Safe.scalar(db,"PRAGMA quick_check",[],"ok")
    Safe.scalar(db,"SELECT count(*) FROM pragma_foreign_key_check",[],"0")
    IO.try(Unit,Sql.close(db))
    source_exact(source(root),compressed)
    removed : String <- Safe.command("/bin/rm",["--",source(root)])
    Safe.absent(source(root))
    Safe.absent(marker(root))
    +description : String = manifest(root,snapshot)
    Store.write_text(marker(root),"w",description ++ "\n")
    Safe.private_file(marker(root),"400")
    IO.print(description)

def create(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(root_shape(root),"Expected a new /private/tmp/juice-bend-attachments-fixture-UUID root")
    canonical : String <- Paths.destination(root)
    Store.checked(String.eq(root,canonical),"Native attachment fixture root must already be canonical")
    prepare(root)

def arguments(args: List<String>) -> IO(Unit):
  match args:
    case _ <> root <> []: create(root)
    case _: IO.die(Unit,2,"Usage: native-attachments /private/tmp/juice-bend-attachments-fixture-UUID")

def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    arguments(args)
