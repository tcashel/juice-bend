import Base
import ./native_activity.bend as Safe
import ./native_request_origin.bend as Origin
import ./native_archive.bend as Archive
import ./native_preview_capture.bend as ImageFixture
import ./native_attachment_oracle.bend as JsonFile
import ../src/attachment_decode.bend as Decode
import ../src/attachment_asset_identity.bend as Identity
import ../src/attachment_asset_types.bend as Asset
import ../src/attachment_assets.bend as Assets
import ../src/attachment_capture_output.bend as Output
import ../src/attachment_capture_ack.bend as Ack
import ../src/archive_meta.bend as Meta
import ../src/capture.bend as Capture
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ../src/json.bend as J
import ../src/paths.bend as Paths
import ../tests/attachment_asset_identity.bend as BytesFile
import ../tests/attachment_assets.bend as BytesRead

# Test-only native fixture/oracle. No approval or asset capture is performed by
# prepare: the actual app's folder/capture controls must perform those actions.
def root_shape(+root: String) -> Bool:
  +prefix = {"/private/tmp/juice-bend-integrated-assets-" : String}
  String.starts_with(root,prefix) && Origin.uuid(String.split(String.drop(root,String.length(prefix)),'-'))
def source(root: String) -> String: root ++ "/sources/integrated.jsonl.zst"
def marker(root: String) -> String: root ++ "/.juice-bend-integrated-assets-v1.json"
def path() -> String: "/message/content/0/source/path"
def visible() -> String: "integrated-assets-visible café 中文 🙂"
def hidden_one() -> String: "integrated-assets-hidden-answer outside the user filter"
def hidden_two() -> String: "integrated-assets-hidden-tail remains in full ATIF"
def image(path: String) -> String:
  "{\"type\":\"image\",\"source\":{\"type\":\"file\",\"path\":" ++ J.quote(path) ++ "}}"
def message(role: String,content: String) -> String:
  "{\"type\":" ++ J.quote(role) ++ ",\"sessionId\":\"integrated-assets-synthetic\",\"cwd\":\"/synthetic/integrated-assets\"," ++
    "\"timestamp\":\"2026-10-21T12:00:00Z\",\"message\":{\"content\":" ++ content ++ "}}\n"
def fixture(+root: String) -> String:
  message("user","[" ++ image(root ++ "/authorized/bands.png") ++ "," ++ image(root ++ "/authorized/binary.bin") ++ "," ++
    image(root ++ "/authorized/empty.bin") ++ "," ++ image(root ++ "/authorized/café #?.bin") ++ "," ++
    image(root ++ "/authorized/missing.bin") ++ "," ++
    "{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/never-fetched.png\"}}," ++
    image(root ++ "/authorized/uncaptured.png") ++ "," ++
    "{\"type\":\"text\",\"text\":" ++ J.quote(visible()) ++ "}]") ++
    message("assistant",J.quote(hidden_one())) ++ message("assistant",J.quote(hidden_two()))
def manifest(+root: String) -> String:
  "{\"fixture\":\"juice-bend-integrated-assets-v1\",\"synthetic\":true,\"root\":" ++ J.quote(root) ++
    ",\"data_dir\":" ++ J.quote(root ++ "/library") ++ ",\"authorized\":" ++ J.quote(root ++ "/authorized") ++
    ",\"source\":" ++ J.quote(source(root)) ++ ",\"snapshot\":\"1\",\"provider\":\"claude\",\"records\":3,\"events\":10," ++
    "\"record\":0,\"reference\":0,\"json_path\":" ++ J.quote(path()) ++ ",\"filter\":\"role:user\",\"search\":\"integrated-assets-visible\"," ++
    "\"png_bytes\":6555,\"png_sha256\":\"2fadba069c92c7b9981c87e6d05b7251de6e6ec8c72afc571eaadad49578d64f\"," ++
    "\"preapproved_roots\":0,\"precaptured_assets\":0}"
def png_result(result: Result<&2,&2,String,Decode.Bytes>) -> IO(List<&2,U32>):
  match result:
    case Fail{error}: IO.die(List<&2,U32>,2,error)
    case Done{Decode.Bytes{bytes,count,digest}}:
      do IO<List<&2,U32>>:
        Store.checked(U32.is_eq(count,6555) && String.eq(digest,"2fadba069c92c7b9981c87e6d05b7251de6e6ec8c72afc571eaadad49578d64f"),"Frozen PNG fixture changed")
        return bytes
def png() -> IO(List<&2,U32>): png_result(Decode.decode(ImageFixture.image_data()))
def guard(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(root_shape(root),"Expected exact integrated synthetic root prefix and UUID")
    Safe.regular_path(root,True{})
    Safe.exact_file(marker(root),manifest(root) ++ "\n")
    Safe.regular_path(root ++ "/library",True{})
    Safe.regular_path(root ++ "/authorized",True{})
def prepare(+root: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(root_shape(root),"Expected a fresh integrated synthetic root")
    canonical : String <- Paths.destination(root)
    Store.checked(String.eq(root,canonical),"Synthetic root must be canonical")
    Safe.absent(root)
    Safe.directory(root)
    Safe.directory(root ++ "/library")
    Safe.directory(root ++ "/sources")
    Safe.directory(root ++ "/authorized")
    Safe.directory(root ++ "/evidence")
    +bytes : List<&2,U32> <- png()
    BytesFile.write_bytes(root ++ "/authorized/bands.png",bytes)
    BytesFile.write_bytes(root ++ "/authorized/uncaptured.png",bytes)
    BytesFile.write_bytes(root ++ "/authorized/binary.bin",[0,1,254,255])
    BytesFile.write_bytes(root ++ "/authorized/empty.bin",[])
    BytesFile.write_bytes(root ++ "/authorized/café #?.bin",[255,0,10])
    Safe.private_file(root ++ "/authorized/bands.png","600")
    Safe.private_file(root ++ "/authorized/uncaptured.png","600")
    Safe.private_file(root ++ "/authorized/binary.bin","600")
    Safe.private_file(root ++ "/authorized/empty.bin","600")
    Safe.private_file(root ++ "/authorized/café #?.bin","600")
    Archive.write(source(root),Archive.raw_frame(D.encode(fixture(root))))
    Safe.private_file(source(root),"600")
    +db : U32 <- Store.open(root ++ "/library/juice-bend.sqlite")
    snapshot : String <- Capture.import_file(db,"claude",source(root))
    Store.checked(String.eq(snapshot,"1"),"Expected initial accepted snapshot 1")
    Safe.exact_capture(db,"1",fixture(root))
    Safe.scalar(db,"SELECT count(*) FROM snapshots WHERE accepted=1 AND records=3",[],"1")
    Safe.scalar(db,"SELECT count(*) FROM events",[],"10")
    Safe.scalar(db,"SELECT count(*) FROM sqlite_master WHERE name IN ('attachment_assets','attachment_roots')",[],"0")
    IO.try(Unit,Sql.close(db))
    Safe.absent(marker(root))
    Store.write_text(marker(root),"w",manifest(root) ++ "\n")
    Safe.private_file(marker(root),"400")
    IO.print(manifest(root))
def loaded(value: Asset.answer(),expected: List<&2,U32>) -> IO(Asset.Receipt):
  match value:
    case Done{Asset.Loaded{+owned}}:
      Asset.Owned{+receipt,chunks} = owned
      do IO<Asset.Receipt>:
        Store.checked(Asset.owned_valid(owned) && D.bytes_equal(Assets.bytes(chunks),expected),"Retained PNG bytes differ")
        return receipt
    case _: IO.die(Asset.Receipt,2,"Expected verified retained PNG")
def local_exact(value: Identity.LocalReference,expected: String) -> Bool:
  match value:
    case Identity.LocalPath{path}: String.eq(path,expected)
    case _: False{}
def exact_receipt(+root: String,+receipt: Asset.Receipt) -> IO(Unit):
  Asset.Receipt{Identity.Resolved{Meta.Header{snapshot,_,_,provider,locator,_,records,_,_,accepted,encoding},record,_,_,_,reference,json_path,_,local},
    Asset.RootEvidence{id,chosen,revision,enabled},time,count,_,digest,_} = receipt
  do IO<Unit>:
    Store.checked(String.eq(snapshot,"1") && String.eq(provider,"claude") && String.eq(locator,source(root)) && U32.is_eq(records,3) && accepted && String.eq(encoding,"zstd-jsonl-v1"),"Pinned captured archive identity changed")
    Store.checked(Asset.receipt_valid(receipt) && U32.is_eq(record,0) && U32.is_eq(reference,0) && String.eq(json_path,path()),"Retained occurrence changed")
    Store.checked(local_exact(local,root ++ "/authorized/bands.png"),"Original local PNG reference changed")
    Store.checked(String.eq(id,"1") && String.eq(chosen,root ++ "/authorized") && String.eq(revision,"1") && enabled && Asset.valid_time(time),"Original explicit policy receipt changed")
    Store.checked(U32.is_eq(count,6555) && String.eq(digest,"2fadba069c92c7b9981c87e6d05b7251de6e6ec8c72afc571eaadad49578d64f"),"Retained byte commitment changed")
def receipt_save(+root: String,text: String,remember: Bool) -> IO(Unit):
  match remember:
    case True{}:
      do IO<Unit>:
        Safe.absent(root ++ "/evidence/original-receipt.json")
        Store.write_text(root ++ "/evidence/original-receipt.json","w",text ++ "\n")
        Safe.private_file(root ++ "/evidence/original-receipt.json","400")
    case False{}: Safe.exact_file(root ++ "/evidence/original-receipt.json",text ++ "\n")
def retained(+root: String,remember: Bool) -> IO(Unit):
  do IO<Unit>:
    guard(root)
    expected : List<&2,U32> <- png()
    +db : U32 <- IO.try(U32,Sql.open_existing(root ++ "/library/juice-bend.sqlite",0))
    Store.exec(db,"PRAGMA foreign_keys=ON",[])
    answer : Asset.answer() <- Assets.read(db,Identity.Request{"1",0,0,path()})
    +receipt : Asset.Receipt <- loaded(answer,expected)
    exact_receipt(root,receipt)
    Safe.exact_capture(db,"1",fixture(root))
    IO.try(Unit,Sql.close(db))
    receipt_save(root,Output.receipt(receipt),remember)
    IO.print("PASS exact retained PNG and original occurrence/policy/time commitment")
def remove_file(+path: String,expected: List<&2,U32>) -> IO(Unit):
  do IO<Unit>:
    Safe.regular_path(path,False{})
    actual : List<&2,U32> <- BytesRead.read_file(path)
    Store.checked(D.bytes_equal(actual,expected),"Refuse removal of changed synthetic source")
    removed : String <- Safe.command("/bin/rm",["--",path])
    Safe.absent(path)
def remove(+root: String) -> IO(Unit):
  do IO<Unit>:
    retained(root,False{})
    +bytes : List<&2,U32> <- png()
    remove_file(root ++ "/authorized/bands.png",bytes)
    remove_file(root ++ "/authorized/uncaptured.png",bytes)
    remove_file(root ++ "/authorized/binary.bin",[0,1,254,255])
    remove_file(root ++ "/authorized/empty.bin",[])
    remove_file(root ++ "/authorized/café #?.bin",[255,0,10])
    remove_file(source(root),Archive.raw_frame(D.encode(fixture(root))))
    IO.print("PASS removed only exact marker-owned synthetic originals")
def admitted_output(+root: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    guard(root)
    Store.checked(String.starts_with(path,root ++ "/library/") && Bool.not(String.contains(path,"/../")),"Output outside synthetic library")
    Safe.regular_path(path,False{})
    mode : String <- Safe.command("/usr/bin/stat",["-f","%Lp",path])
    Store.checked(String.eq(String.trim(mode),"600"),"Export must be private mode 0600")
def exported(+root: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    admitted_output(root,path)
    expected : List<&2,U32> <- png()
    actual : List<&2,U32> <- BytesRead.read_file(path)
    Store.checked(D.bytes_equal(actual,expected),"Actual GUI export PNG differs")
    retained(root,False{})
    IO.print("PASS exact native exported PNG after source loss")
def item(values: List<&2,J.Json>,index: Nat) -> J.Json:
  match values index:
    case value <> _ 0n: value
    case _ <> rest 1n+n: item(rest,n)
    case [] _: J.JNull{}
def extra(value: J.Json) -> J.Json: J.field(J.field(value,"extra"),"juice_bend")
def atif_step(+step: J.Json,record: String,text: String) -> Bool:
  String.eq(J.get(step,"message"),text) && String.eq(J.get(J.field(extra(step),"citation"),"record"),record) &&
    String.eq(J.get(J.field(extra(step),"citation"),"byte_space"),"logical-decoded-jsonl-bytes")
def atif_images(steps: List<&2,J.Json>,expected: List<&2,String>,+slot: U32) -> Bool:
  match steps expected:
    case _ Nil{}: True{}
    case Con{+step,rest} Con{args,tail}:
      atif_step(step,"0","[Image metadata retained; image rendering unavailable]") &&
        String.eq(J.get(J.field(extra(step),"citation"),"slot"),U32.show(slot)) &&
        String.eq(J.get(J.field(extra(step),"normalized_event"),"arguments"),args) &&
        String.eq(J.get(J.field(extra(step),"normalized_event"),"coverage"),"unsupported_attachment") &&
        atif_images(rest,tail,U32.inc(slot))
    case _ _: False{}
def image_expectations(+root: String) -> List<&2,String>:
  [image(root ++ "/authorized/bands.png"),image(root ++ "/authorized/binary.bin"),
    image(root ++ "/authorized/empty.bin"),image(root ++ "/authorized/café #?.bin"),
    image(root ++ "/authorized/missing.bin"),
    "{\"type\":\"image\",\"source\":{\"type\":\"url\",\"url\":\"https://example.invalid/never-fetched.png\"}}",
    image(root ++ "/authorized/uncaptured.png")]
def atif(+root: String,+path: String) -> IO(Unit):
  do IO<Unit>:
    admitted_output(root,path)
    +doc : J.Json <- JsonFile.input(path)
    +steps : List<&2,J.Json> = J.items(J.field(doc,"steps"))
    +meta : J.Json = extra(doc)
    Store.checked(String.eq(J.get(doc,"schema_version"),"ATIF-v1.8") && String.eq(J.get(doc,"trajectory_id"),"juice-bend-snapshot-1"),"ATIF schema or immutable snapshot differs")
    Store.checked(Nat.is_eq(List.length(&2,J.Json,steps),10n) && String.eq(J.get(meta,"normalized_events"),"10") && String.eq(J.get(meta,"exported_steps"),"10") && String.eq(J.get(meta,"processed_records"),"3") && String.eq(J.get(meta,"retained_scan_complete"),"true"),"ATIF lost full captured scope")
    Store.checked(atif_images(steps,image_expectations(root),0),"ATIF omitted or changed the seven captured attachment metadata events")
    Store.checked(atif_step(item(steps,7n),"0",visible()) && atif_step(item(steps,8n),"1",hidden_one()) && atif_step(item(steps,9n),"2",hidden_two()),"ATIF omitted known records outside user filter or changed citations")
    Store.checked(String.eq(J.get(meta,"attachment_bytes_embedded"),"false") && String.eq(J.get(meta,"byte_space"),"logical-decoded-jsonl-bytes"),"ATIF attachment or byte-space disclosure changed")
    retained(root,False{})
    IO.print("PASS native full-snapshot ATIF includes both assistant records outside user filter")
def root_page(root: String,value: Ack.RootPage,+enabled: Bool) -> IO(Unit):
  Ack.RootPage{_,_,rows,next} = value
  match rows:
    case [Asset.RootEvidence{id,path,revision,actual}]:
      Store.checked(String.eq(id,"1") && String.eq(path,root ++ "/authorized") &&
        String.eq(revision,Bool.pick(String,enabled,"1","2")) && U32.is_eq(Bool.to_u32(actual),Bool.to_u32(enabled)) &&
        Bool.not(Maybe.is_some(&2,String,next)),"Explicit folder list state differs")
    case _: IO.die(Unit,2,"Expected one explicit synthetic root")
def policy(+root: String,path: String,enabled: Bool) -> IO(Unit):
  do IO<Unit>:
    guard(root)
    value : J.Json <- JsonFile.input(path)
    page : Ack.RootPage <- Safe.need(Ack.RootPage,Ack.page(value,"0",40))
    root_page(root,page,enabled)
    IO.print("PASS exact explicit folder ID revision and enabled state")
def reader(+root: String,path: String) -> IO(Unit):
  do IO<Unit>:
    guard(root)
    +value : J.Json <- JsonFile.input(path)
    +text : String = J.get(value,"text")
    Store.checked(String.eq(J.get(value,"snapshot"),"1") && String.eq(J.get(value,"selected_records"),"3") &&
      String.eq(J.get(value,"byte_space"),"logical_source_bytes") && String.eq(J.get(value,"complete_export"),"false"),"Filtered reader changed pinned scope")
    Store.checked(String.contains(text,visible()) && Bool.not(String.contains(text,hidden_one())) &&
      Bool.not(String.contains(text,hidden_two())),"User-role reader must exclude both known assistant bodies")
    IO.print("PASS role-filtered reader hides known assistant records")
def argv(args: List<String>) -> IO(Unit):
  match args:
    case [_self,"prepare",root]: prepare(root)
    case [_self,"guard",root]: guard(root)
    case [_self,"remember",root]: retained(root,True{})
    case [_self,"retained",root]: retained(root,False{})
    case [_self,"remove",root]: remove(root)
    case [_self,"export",root,path]: exported(root,path)
    case [_self,"atif",root,path]: atif(root,path)
    case [_self,"enabled",root,path]: policy(root,path,True{})
    case [_self,"disabled",root,path]: policy(root,path,False{})
    case [_self,"reader",root,path]: reader(root,path)
    case _: IO.die(Unit,64,"Expected integrated synthetic fixture operation")
def main() -> IO(Unit):
  do IO<Unit>:
    args : List<String> <- IO.args()
    argv(args)
