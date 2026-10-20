import Base
import ../src/storage_inventory.bend as Inventory
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/json.bend as Json
import ../src/maintenance.bend as Maintenance

def assert(ok: Bool,name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ name)

def measured(value: Inventory.FileSize,expected: String) -> Bool:
  match value:
    case Inventory.Measured{bytes}:
      String.eq(bytes,expected)
    case _:
      False{}

def unavailable(value: Inventory.FileSize,expected: String) -> Bool:
  match value:
    case Inventory.Unavailable{reason}:
      String.eq(reason,expected)
    case _:
      False{}

def parsed(result: Result<&2,&2,String,Json.Json>) -> IO(Json.Json):
  match result:
    case Done{value}:
      IO.pure(Json.Json,value)
    case Fail{error}:
      IO.die(Json.Json,1,"FAIL inventory JSON: " ++ error)

def section(report: Inventory.Report,name: String) -> IO(Json.Json):
  do IO<Json.Json>:
    value : Json.Json <- parsed(Json.parse(Inventory.to_json(report)))
    return Json.field(value,name)

def string_value(value: Json.Json,expected: String) -> Bool:
  match value:
    case Json.JString{text}:
      String.eq(text,expected)
    case _:
      False{}

def number_string(+value: Json.Json,name: String,expected: String,label: String) -> IO(Unit):
  assert(string_value(Json.field(value,name),expected),label)

def null_value(value: Json.Json) -> Bool:
  match value:
    case Json.JNull{}:
      True{}
    case _:
      False{}

def mode_parser() -> IO(Unit):
  do IO<Unit>:
    assert(measured(Inventory.stat_lines(["100644:0",""]),"0"),"observed empty regular file has an exact measured zero")
    assert(measured(Inventory.stat_lines(["107777:4294967296",""]),"4294967296"),"regular mode accepts permission bits and sizes above U32")
    assert(measured(Inventory.stat_lines(["100600:9223372036854775807",""]),"9223372036854775807"),"file size parser preserves the signed64 boundary exactly")
    assert(unavailable(Inventory.stat_lines(["100600:9223372036854775808",""]),"invalid_stat_metadata"),"overflowing size is unavailable rather than rounded")
    assert(unavailable(Inventory.stat_lines(["100600:-1",""]),"invalid_stat_metadata"),"negative size is unavailable rather than wrapped")
    assert(unavailable(Inventory.stat_lines(["100600:01",""]),"invalid_stat_metadata"),"noncanonical file quantity is rejected")
    assert(unavailable(Inventory.stat_lines(["120777:4",""]),"not_regular_file"),"symlink mode is refused")
    assert(unavailable(Inventory.stat_lines(["40755:4",""]),"not_regular_file"),"directory mode is refused")
    assert(unavailable(Inventory.stat_lines(["10644:4",""]),"not_regular_file"),"FIFO mode is refused")
    assert(unavailable(Inventory.stat_lines(["100888:4",""]),"not_regular_file"),"invalid octal mode is refused")
    assert(unavailable(Inventory.stat_lines(["100644:4"]),"invalid_stat_metadata"),"truncated stat output is rejected")
    assert(unavailable(Inventory.stat_lines(["100644:4", "100644:9", ""]),"invalid_stat_metadata"),"unexpected additional stat rows are rejected")
    assert(unavailable(Inventory.stat_result(Done{(1,("","ignored private error"))}),"missing_or_inaccessible"),"stat failure remains unavailable without publishing stderr")
    assert(unavailable(Inventory.stat_result(Fail{(60,"timeout")}),"stat_failed"),"bounded process timeout is explicit unavailable data")
    assert(Inventory.path_valid("/synthetic/owned.sqlite") &&
      Bool.not(Inventory.path_valid("relative.sqlite")) &&
      Bool.not(Inventory.path_valid("/synthetic/owned\0suffix")),"file observations require bounded absolute non-NUL database paths")

def arithmetic() -> IO(Unit):
  do IO<Unit>:
    +wide : Inventory.Pages <- Inventory.pages("4294967294","65536","4294967293")
    +json : Json.Json <- parsed(Json.parse(Inventory.pages_json(wide)))
    number_string(json,"logical_bytes","281474976579584","maximum SQLite page product remains exact within pinned Nat")
    number_string(json,"reusable_bytes","281474976514048","maximum freelist product remains exact within pinned Nat")
    assert(Bool.not(Inventory.pages_valid("4294967295","65536","0")),"page count above SQLite bound is rejected before multiplication")
    assert(Bool.not(Inventory.pages_valid("2","4096","3")),"freelist cannot exceed the database page count")
    assert(Bool.not(Inventory.pages_valid("2","1000","0")),"invalid SQLite page size is rejected")
    assert(Bool.not(Inventory.pages_valid("-1","4096","0")),"negative page metadata is rejected")
    assert(Bool.not(Inventory.quantities([Sql.Cell.Real{"1.5"}])) &&
      Bool.not(Inventory.quantities([Sql.Cell.Integer{"-1"}])) &&
      Bool.not(Inventory.quantities([Sql.Cell.Null{}])),"typed quantities reject fractional negative and absent SQLite values")

def command(result: Result<&1,&1,U32 & String,U32 & (String & String)>,name: String) -> IO(Unit):
  match result:
    case Done{(0,_)}:
      assert(True{},name)
    case _:
      IO.die(Unit,1,"FAIL owned fixture command: " ++ name)

def filesystem() -> IO(Unit):
  do IO<Unit>:
    Store.write_text("inventory literal ; $(echo marker).bin","w","abc\n")
    size : Inventory.FileSize <- Inventory.file_size("inventory literal ; $(echo marker).bin")
    assert(measured(size,"4"),"macOS stat receives a literal filename without shell evaluation")
    linked : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/ln",
      ["-s","inventory literal ; $(echo marker).bin","inventory-link"],"",4096,2000)
    command(linked,"create only the synthetic symlink fixture")
    link : Inventory.FileSize <- Inventory.file_size("inventory-link")
    assert(unavailable(link,"not_regular_file"),"actual symlink is not followed to its target")
    piped : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/usr/bin/mkfifo",
      ["inventory-pipe"],"",4096,2000)
    command(piped,"create only the synthetic FIFO fixture")
    pipe : Inventory.FileSize <- Inventory.file_size("inventory-pipe")
    assert(unavailable(pipe,"not_regular_file"),"actual FIFO metadata is inspected without opening or blocking")
    directory : Inventory.FileSize <- Inventory.file_size(".build")
    assert(unavailable(directory,"not_regular_file"),"actual directory is not measured as a database file")
    absent : Inventory.FileSize <- Inventory.file_size("inventory-absent")
    assert(unavailable(absent,"missing_or_inaccessible"),"absent file is not silently reported as zero bytes")

def file_length_result(result: File & Result<&1,&1,U32 & String,U32>) -> IO(String):
  (file,size) = result
  do IO<String>:
    File.close(file)
    value : U32 <- IO.try(U32,IO.pure(Result<&1,&1,U32 & String,U32>,size))
    return U32.show(value)

def file_length(path: String) -> IO(String):
  do IO<String>:
    file : File <- IO.try(File,File.open(path,"r"))
    result : File & Result<&1,&1,U32 & String,U32> <- File.size(file)
    file_length_result(result)

def file_observations(files: Inventory.Files,main: String,wal: String,shm: String) -> IO(Unit):
  Inventory.Files{a,b,c} = files
  assert(measured(a,main) && measured(b,wal) && measured(c,shm),"main WAL and SHM logical bytes agree with independent small-file fstat observations")

def report_files(report: Inventory.Report) -> Inventory.Files:
  Inventory.Report{files,pages,rows} = report
  files

def line(text: String) -> String:
  "{\"type\":\"user\",\"sessionId\":\"inventory-fixture\",\"cwd\":\"/synthetic/inventory\",\"message\":{\"role\":\"user\",\"content\":\"" ++ text ++ "\"}}\n"

def retained_rows(+rows: Json.Json,raw_bytes: String) -> IO(Unit):
  do IO<Unit>:
    number_string(rows,"sources","1","inventory counts one exact captured source")
    number_string(rows,"generations","2","inventory includes append generation and rewrite generation")
    number_string(rows,"accepted_snapshots","3","inventory retains all accepted saved versions")
    number_string(rows,"unaccepted_snapshots","0","published fixture has no staged snapshots")
    number_string(rows,"raw_chunks","3","raw chunk count measures unique owned captured chunks")
    number_string(rows,"raw_bytes",raw_bytes,"raw byte total counts owned chunks once rather than summing snapshot extents")
    number_string(rows,"record_links","4","record references include the retained shared prefix")
    number_string(rows,"projected_events","4","projected event count includes retained historical versions")
    number_string(rows,"search_rows","1","lexical index count describes the current projection only")
    number_string(rows,"context_rows","4","context projection rows are counted separately")
    number_string(rows,"projection_checks","3","projection seals are counted separately")
    number_string(rows,"settings","0","settings count does not expose their values")

def reusable(report: Inventory.Report) -> IO(Unit):
  Inventory.Report{files,Inventory.Pages{count,size,free,total,reusable},rows} = report
  assert(Bool.not(String.eq(free,"0")) && Bool.not(String.eq(reusable,"0")),
    "dropped synthetic allocation is reported as SQLite reusable pages")

def library() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/storage-inventory.sqlite")
    +empty : Inventory.Report <- Inventory.read(db)
    +empty_rows : Json.Json <- section(empty,"rows")
    number_string(empty_rows,"raw_bytes","0","empty library reports an observed raw-byte zero")
    number_string(empty_rows,"accepted_snapshots","0","empty library has no accepted captures")
    +first : String = line("old retained citrus")
    +second : String = line("append apricot")
    +replacement : String = line("replacement mango")
    Store.write_text("inventory-source.jsonl","w",first)
    +old : String <- Store.import_file(db,"claude","inventory-source.jsonl")
    +old_page : String <- Store.page(db,old,0,10)
    Store.write_text("inventory-source.jsonl","a",second)
    appended : String <- Store.import_file(db,"claude","inventory-source.jsonl")
    Store.write_text("inventory-source.jsonl","w",replacement)
    current : String <- Store.import_file(db,"claude","inventory-source.jsonl")
    main_bytes : String <- file_length(".build/storage-inventory.sqlite")
    wal_bytes : String <- file_length(".build/storage-inventory.sqlite-wal")
    shm_bytes : String <- file_length(".build/storage-inventory.sqlite-shm")
    +before_changes : String <- Inventory.scalar(db,"SELECT total_changes()")
    +report : Inventory.Report <- Inventory.read(db)
    after_changes : String <- Inventory.scalar(db,"SELECT total_changes()")
    assert(String.eq(before_changes,after_changes),"inventory makes no database row changes")
    file_observations(report_files(report),main_bytes,wal_bytes,shm_bytes)
    +rows : Json.Json <- section(report,"rows")
    retained_rows(rows,Nat.show(String.length(first ++ second ++ replacement)))
    +json : Json.Json <- parsed(Json.parse(Inventory.to_json(report)))
    assert(null_value(Json.field(json,"physical_reclaimable_bytes")),"inventory never equates logical bytes with physical reclaimability")
    assert(String.eq(Json.get(json,"database_consistency"),"single_read_transaction") &&
      String.eq(Json.get(json,"file_consistency"),"separate_non_atomic_samples"),"JSON contract discloses database and file sampling consistency separately")
    assert(Bool.not(String.contains(Inventory.to_json(report),"inventory-source")) &&
      Bool.not(String.contains(Inventory.to_json(report),"retained citrus")),"inventory exports no source path or captured transcript content")
    Maintenance.rebuild(db,old)
    rebuilt : Inventory.Report <- Inventory.read(db)
    rebuilt_rows : Json.Json <- section(rebuilt,"rows")
    assert(String.eq(Json.encode(rows),Json.encode(rebuilt_rows)),"verified historical rebuild preserves owned inventory counts")
    Store.exec(db,"INSERT INTO snapshots(generation,extent) SELECT generation,0 FROM snapshots WHERE id=?",[Sql.Cell.Integer{old}])
    staged : Inventory.Report <- Inventory.read(db)
    +staged_rows : Json.Json <- section(staged,"rows")
    number_string(staged_rows,"accepted_snapshots","3","unaccepted staging metadata does not inflate accepted count")
    number_string(staged_rows,"unaccepted_snapshots","1","unaccepted staging metadata has a separate count")
    Store.exec(db,"ATTACH DATABASE '.build/inventory-attached.sqlite' AS extra",[])
    Store.exec(db,"CREATE TABLE extra.sources(value TEXT)",[])
    Store.exec(db,"INSERT INTO extra.sources VALUES('unrelated synthetic attached data')",[])
    Store.exec(db,"CREATE TEMP TABLE sources(value TEXT)",[])
    Store.exec(db,"INSERT INTO temp.sources VALUES('unrelated synthetic temporary data')",[])
    scoped : Inventory.Report <- Inventory.read(db)
    scoped_rows : Json.Json <- section(scoped,"rows")
    assert(String.eq(Json.encode(staged_rows),Json.encode(scoped_rows)),"main qualification excludes attached and shadowing temporary tables")
    Store.exec(db,"DROP TABLE temp.sources",[])
    Store.exec(db,"CREATE TABLE main.inventory_free_fixture(bytes BLOB)",[])
    Store.exec(db,"INSERT INTO main.inventory_free_fixture VALUES(zeroblob(65536))",[])
    Store.exec(db,"DROP TABLE main.inventory_free_fixture",[])
    free : Inventory.Report <- Inventory.read(db)
    reusable(free)
    removed : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/mv",
      ["inventory-source.jsonl","inventory-source-retired.jsonl"],"",4096,2000)
    command(removed,"move only the synthetic original source fixture")
    owned : Inventory.Report <- Inventory.read(db)
    owned_rows : Json.Json <- section(owned,"rows")
    assert(String.eq(Json.encode(staged_rows),Json.encode(owned_rows)),"inventory remains available after original source path disappears")
    retained : String <- Store.page(db,old,0,10)
    assert(String.eq(retained,old_page),"inventory leaves accepted raw capture and transcript readable")
    IO.try(Unit,Sql.close(db))

def memory() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(":memory:")
    report : Inventory.Report <- Inventory.read(db)
    +json : Json.Json <- section(report,"files")
    assert(String.eq(Json.get(Json.field(json,"main"),"reason"),"not_file_backed") &&
      String.eq(Json.get(Json.field(json,"wal"),"reason"),"not_file_backed") &&
      String.eq(Json.get(Json.field(json,"shm"),"reason"),"not_file_backed"),"memory database reports all file lengths unavailable")
    IO.try(Unit,Sql.close(db))

def summary_text() -> IO(Unit):
  report : Inventory.Report = Inventory.Report{
    Inventory.Files{Inventory.Measured{"0"},Inventory.Unavailable{"missing_or_inaccessible"},Inventory.Measured{"4294967296"}},
    Inventory.Pages{"2","4096","1","8192","4096"},
    Inventory.Rows{"2","3","4","1","10","2500","15","20","8","15","4","1"}}
  +text : String = Inventory.summary(report)
  do IO<Unit>:
    assert(String.contains(text,"Main database: 0 bytes"),"summary distinguishes an observed empty file from unavailable size")
    assert(String.contains(text,"Write-ahead log (WAL): unavailable (file is absent or inaccessible)"),"summary preserves unavailable file reason in readable language")
    assert(String.contains(text,"Shared memory (SHM): 4294967296 bytes"),"summary retains exact file quantities above U32")
    assert(String.contains(text,"Logical database: 2 pages x 4096 bytes = 8192 bytes") &&
      String.contains(text,"Reusable inside SQLite: 1 page = 4096 bytes"),"summary separates logical database bytes from reusable page bytes")
    assert(String.contains(text,"Accepted saved versions: 4") && String.contains(text,"Unaccepted captures: 1") &&
      String.contains(text,"Raw chunks: 10 (2500 bytes, counted once per owned chunk)"),"summary distinguishes accepted history and unique owned raw chunks")
    assert(String.contains(text,"Projected events: 20") && String.contains(text,"Lexical index rows: 8") &&
      String.contains(text,"Context rows: 15") && String.contains(text,"Projection checks: 4"),"summary exposes derived counts separately from raw capture")
    assert(String.contains(text,"These views overlap: do not add SQLite logical bytes, raw bytes, and file lengths together.") &&
      String.contains(text,"Physical reclaimable disk space is not measured."),"summary explicitly avoids overlapping totals and physical reclaimability claims")
    assert(String.contains(text,"Database counts share one read transaction.") &&
      String.contains(text,"File sizes are separate, non-atomic samples"),"summary preserves the report's sampling consistency limits")
    assert(String.contains(Inventory.file_summary("Main",Inventory.Unavailable{"not_file_backed"}),"not stored in a file") &&
      String.contains(Inventory.file_summary("WAL",Inventory.Unavailable{"not_regular_file"}),"link or nonregular file") &&
      String.contains(Inventory.file_summary("SHM",Inventory.Unavailable{"stat_failed"}),"failed or timed out"),"summary renders memory special-file and timed-out observations honestly")

def main() -> IO(Unit):
  do IO<Unit>:
    mode_parser()
    arithmetic()
    filesystem()
    library()
    memory()
    summary_text()
