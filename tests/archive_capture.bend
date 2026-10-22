import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/capture.bend as Capture
import ../src/archive_meta.bend as Meta
import ../src/archive_maintenance.bend as Archive
import ../src/archive_compare.bend as Compare
import ../src/maintenance.bend as Maintenance
import ../src/domain.bend as Domain
import ../src/evidence.bend as Evidence
import ../src/storage_inventory.bend as Inventory
import ../src/json.bend as Json
import ./zstd/frame_vectors.bend as Vectors
import ./zstd/multiblock_vectors.bend as Multiple
import ./archive_maintenance.bend as Fixture
import ./publication_crash.bend as Check

# Expected text is built independently of the decoder from the fixed synthetic
# fixture grammar. Original zstd1.5.6 fixture receipts remain under archive-decoder.
def role(user: Bool) -> String:
  match user:
    case True{}: "user"
    case False{}: "assistant"

def records(fuel: Nat,+index: U32) -> String:
  match fuel:
    case 0n: ""
    case 1n+rest:
      +r = role(U32.is_eq(U32.mod(index,3),0))
      "{\"type\":\"" ++ r ++ "\",\"sessionId\":\"synthetic-zstd\",\"message\":{\"role\":\"" ++ r ++ "\",\"content\":\"Archive record " ++ U32.show(index) ++ ": keep exact cafe and code path src/" ++ U32.show(U32.mod(index,7)) ++ ".bend; value=" ++ U32.show(U32.mul(index,index)) ++ "\"}}\n" ++ records(rest,U32.add(index,1))

def expected_records(count: U32) -> IO(String):
  IO.pure(String,records(U32.to_nat(count),0))

def tail() -> String:
  "{\"type\":\"user\",\"sessionId\":\"synthetic-zstd\",\"message\":{\"content\":\"tailneedle café 中文 🙂\"}}\n"

def appended() -> List<&2,U32>:
  List.append(&2,U32,Vectors.jsonl_check(),Fixture.raw_frame(Domain.encode(tail())))

def rewritten() -> List<&2,U32>:
  List.append(&2,U32,Vectors.jsonl(),Fixture.raw_frame(Domain.encode(tail())))

def exact_logical(+db: U32,+snapshot: String,expected: String,label: String) -> IO(Unit):
  do IO<Unit>:
    actual : List<&2,List<&2,U32>> <- Archive.logical(db,snapshot,True{})
    Check.assert(Compare.equal(actual,[Domain.encode(expected)]),label)
    Archive.verify(db,snapshot)

def comparisons() -> IO(Unit):
  do IO<Unit>:
    Check.assert(Compare.equal([[1,2],[],[3]],[[1],[2,3],[]]),"archive comparison crosses unrelated chunk boundaries")
    Check.assert(Compare.prefix([[1,2]],[[1],[2,3]]),"archive physical append accepts exact prefix")
    Check.assert(Bool.not(Compare.prefix([[1,2,3]],[[1],[2]])),"archive prefix comparison rejects truncation")
    Check.assert(Bool.not(Compare.prefix([[1,2]],[[1],[9,2]])),"archive prefix comparison rejects changed bytes")
    Check.assert(Bool.not(Compare.equal([[1,2]],[[1],[2,3]])),"archive full equality rejects suffix")
    Check.assert(Compare.prefix([],[[],[1]]),"empty logical extent remains a valid prefix")

def unchanged(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    +count : String <- Check.scalar(db,"SELECT count(*) FROM raw",[])
    same : String <- Capture.import_file(db,"claude","capture-small.jsonl.zst")
    Check.assert(String.eq(snapshot,same),"unchanged compressed bytes retain exact accepted snapshot identity")
    Check.equal_scalar(db,"SELECT count(*) FROM snapshots",[],"1","unchanged archive creates no snapshot")
    Check.equal_scalar(db,"SELECT count(*) FROM raw",[],count,"unchanged archive creates no raw rows")

def append_capture(+db: U32,+old: String) -> IO(String):
  do IO<String>:
    Fixture.write_bytes("capture-small.jsonl.zst",appended())
    +next : String <- Capture.import_file(db,"claude","capture-small.jsonl.zst")
    Check.assert(Bool.not(String.eq(old,next)),"complete frame append creates new snapshot")
    Check.equal_scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{next}],"1","physical and logical prefix append retains generation")
    Check.equal_scalar(db,"SELECT count(*) FROM records a JOIN records b ON a.raw=b.raw WHERE a.snapshot=? AND b.snapshot=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{next}],"0","archive first slice reparses with fresh raw rows while retaining old snapshot")
    exact_logical(db,next,records(100n,0) ++ tail(),"archive append exact logical bytes include Unicode tail")
    return next

def rewrite_capture(+db: U32,+previous: String) -> IO(String):
  do IO<String>:
    Fixture.write_bytes("capture-small.jsonl.zst",rewritten())
    +next : String <- Capture.import_file(db,"claude","capture-small.jsonl.zst")
    Check.equal_scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{previous},Sql.Cell.Integer{next}],"0","recompression creates generation even when logical bytes are identical")
    exact_logical(db,next,records(100n,0) ++ tail(),"recompression preserves independently expected logical stream")
    return next

def stale_evidence(+db: U32,+old: String,old_page: String,citation: String,quoted: String) -> IO(Unit):
  do IO<Unit>:
    current : String <- Store.page(db,old,0,3)
    Check.assert(String.eq(old_page,current),"append and recompression preserve historical rendered transcript")
    result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    actual : String <- Check.quote_result(result)
    Check.assert(String.eq(quoted,actual),"historical archive citation resolves exact old record")
    exact_logical(db,old,records(100n,0),"historical archive raw bytes remain immutable")

def inventory_row(value: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match value:
    case Done{json}: IO.pure(Json.Json,Json.field(json,"rows"))
    case Fail{_}: IO.die(Json.Json,1,"FAIL archive inventory did not return JSON")

def inventory(+db: U32) -> IO(Unit):
  do IO<Unit>:
    before : String <- Check.scalar(db,"SELECT total_changes()",[])
    report : Inventory.Report <- Inventory.read(db)
    after : String <- Check.scalar(db,"SELECT total_changes()",[])
    Check.assert(String.eq(before,after),"archive inventory observes without database mutation")
    +rows : Json.Json <- inventory_row(Json.parse(Inventory.to_json(report)))
    Check.assert(String.eq(Json.get(rows,"archive_snapshots"),"3") &&
      String.eq(Json.get(rows,"container_chunks"),"3"),"inventory counts immutable compressed snapshots and container chunks separately")
    Check.assert(String.eq(Json.get(rows,"compressed_container_bytes"),
      Nat.show(Nat.add(List.length(&2,U32,Vectors.jsonl_check()),
        Nat.add(List.length(&2,U32,appended()),List.length(&2,U32,rewritten()))))),
      "inventory sums exact retained compressed bytes without estimating reclaimability")
    Check.assert(String.eq(Json.get(rows,"raw_bytes"),Nat.show(List.length(&2,U32,
      Domain.encode(records(100n,0) ++ records(100n,0) ++ tail() ++ records(100n,0) ++ tail())))),
      "inventory raw-byte count remains logical capture storage and excludes compressed container bytes")

def dual_export(+db: U32,+latest: String) -> IO(Unit):
  do IO<Unit>:
    removed : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/bin/rm",["--","capture-small.jsonl.zst"],"",4096,2000))
    Fixture.process_ok(removed,"remove only synthetic archive source")
    +hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"tailneedle","claude","","","",10,0)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),1n) && Check.all_snapshot(hits,latest),
      "lexical search remains owned and latest-scoped after source deletion")
    Maintenance.export_raw(db,latest,"capture-logical.jsonl")
    Archive.export_container(db,latest,"capture-container.zst")
    logical : List<&2,U32> <- Fixture.read_bytes("capture-logical.jsonl")
    Check.assert(Domain.bytes_equal(logical,Domain.encode(records(100n,0) ++ tail())),
      "source-removed logical export is exact original decompressed bytes")
    container : List<&2,U32> <- Fixture.read_bytes("capture-container.zst")
    Check.assert(Domain.bytes_equal(container,rewritten()),"source-removed container export is exact captured compressed bytes")
    Maintenance.rebuild(db,latest)
    Archive.verify(db,latest)
    Check.equal_scalar(db,"SELECT count(*) FROM snapshots",[],"3","rebuild never changes archive identities")
    inventory(db)

def lifecycle() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-capture.sqlite")
    Fixture.write_bytes("capture-small.jsonl.zst",Vectors.jsonl_check())
    +old : String <- Capture.import_file(db,"claude","capture-small.jsonl.zst")
    Check.equal_scalar(db,"PRAGMA user_version",[],"3","archive-capable library activates schema3 fence")
    Check.equal_scalar(db,"SELECT count(*) FROM raw",[],"100","ordinary compressed blocks produce 100 owned JSONL records")
    exact_logical(db,old,records(100n,0),"ordinary Huffman/FSE archive equals independent expected JSONL")
    hits : List<&2,List<&2,Sql.Cell>> <- Store.search(db,"Archive","claude","","","",100,0)
    Check.assert(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,hits),100n),"native lexical search finds all100 ordinary compressed records")
    +page : String <- Store.page(db,old,0,3)
    Check.assert(String.contains(page,"Archive record 0") && String.contains(page,"logical source bytes"),
      "native transcript is readable and labels logical byte space")
    record : Evidence.Verified <- Evidence.read_record(db,old,0)
    +citation : String = Evidence.citation(record,0)
    result : Result<&2,&2,String,String> <- Evidence.resolve_citation(db,citation)
    quote : String <- Check.quote_result(result)
    unchanged(db,old)
    appended_snapshot : String <- append_capture(db,old)
    +latest : String <- rewrite_capture(db,appended_snapshot)
    stale_evidence(db,old,page,citation,quote)
    dual_export(db,latest)
    Check.check_integrity(db,"archive capture lifecycle")
    IO.try(Unit,Sql.close(db))

def multiple() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-multiple.sqlite")
    Fixture.write_bytes("capture-multiple.jsonl.zst",Multiple.records_check())
    +snapshot : String <- Capture.import_file(db,"claude","capture-multiple.jsonl.zst")
    Check.equal_scalar(db,"SELECT count(*) FROM raw",[],"2000","five compressed blocks capture 2000 exact JSONL records")
    expected : String <- expected_records(2000)
    exact_logical(db,snapshot,expected,"multi-block Huffman/FSE table reuse survives real SQLite capture")
    page : String <- Store.page(db,snapshot,1997,3)
    Check.assert(String.contains(page,"Archive record 1999"),"late bounded transcript page reads retained multi-block record")
    Archive.export_container(db,snapshot,"capture-multiple-out.zst")
    exported : List<&2,U32> <- Fixture.read_bytes("capture-multiple-out.zst")
    Check.assert(Domain.bytes_equal(exported,Multiple.records_check()),"multiple-block original container exports without recompression")
    IO.try(Unit,Sql.close(db))

def extra_frames() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/archive-empty-frame.sqlite")
    Fixture.write_bytes("capture-extra.jsonl.zst",Vectors.jsonl_check())
    +old : String <- Capture.import_file(db,"claude","capture-extra.jsonl.zst")
    Fixture.write_bytes("capture-extra.jsonl.zst",List.append(&2,U32,Vectors.jsonl_check(),[80,42,77,24,3,0,0,0,1,2,3]))
    +next : String <- Capture.import_file(db,"claude","capture-extra.jsonl.zst")
    Check.assert(Bool.not(String.eq(old,next)),"appended skippable frame creates a physical-evidence snapshot despite unchanged logical extent")
    Check.equal_scalar(db,"SELECT count(*) FROM snapshots a JOIN snapshots b ON a.generation=b.generation AND a.extent=b.extent WHERE a.id=? AND b.id=?",
      [Sql.Cell.Integer{old},Sql.Cell.Integer{next}],"1","empty-output frame append retains generation and logical extent")
    Archive.verify(db,next)
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    comparisons()
    lifecycle()
    multiple()
    extra_frames()
    IO.print("Archive capture lifecycle suite passed")
