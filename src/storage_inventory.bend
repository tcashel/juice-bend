import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./provenance.bend as Provenance

# Counts describe owned rows, not an integrity or recoverability verdict.
# SQLite metadata shares one read transaction. File lengths are separate,
# non-atomic lstat observations and never estimates of physical reclaimability.
type FileSize is Data:
  Measured{bytes: String}
  Unavailable{reason: String}

type Files is Data:
  Files{main: FileSize,wal: FileSize,shm: FileSize}

type Pages is Data:
  Pages{page_count: String,page_size: String,freelist_count: String,
    logical_bytes: String,reusable_bytes: String}

type Rows is Data:
  Rows{sources: String,generations: String,accepted_snapshots: String,
    unaccepted_snapshots: String,raw_chunks: String,raw_bytes: String,
    record_links: String,projected_events: String,search_rows: String,
    context_rows: String,projection_checks: String,settings: String,
    archive_snapshots: String,container_chunks: String,container_bytes: String}

type Report is Data:
  Report{files: Files,pages: Pages,rows: Rows}

def quantity_valid(+value: String) -> Bool:
  Provenance.decimal_valid(value) &&
    Bool.not(Cmp.is_gt(Provenance.decimal_compare(value,"9223372036854775807")))

def quantities(values: List<&2,Sql.Cell>) -> Bool:
  match values:
    case []:
      True{}
    case Sql.Cell.Integer{value} <> rest:
      quantity_valid(value) && quantities(rest)
    case _:
      False{}

def scalar_rows(rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case [[Sql.Cell.Integer{+value}]]:
      do IO<String>:
        Store.checked(quantity_valid(value),"Storage inventory unavailable: invalid nonnegative SQLite quantity")
        return value
    case _:
      IO.die(String,1,"Storage inventory unavailable: expected one integer quantity")

def scalar(db: U32,sql: String) -> IO(String):
  do IO<String>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,sql,[],1)
    scalar_rows(rows)

def page_size_valid(value: String) -> Bool:
  Provenance.member(value,["512","1024","2048","4096","8192","16384","32768","65536"])

# The pinned runtime's Nat is bounded to 2^48-1. SQLite's largest page count
# (2^32-2) times its largest page size (65536) fits; check before Nat conversion.
def pages_valid(+count: String,+size: String,+free: String) -> Bool:
  quantity_valid(count) && quantity_valid(free) && page_size_valid(size) &&
    Bool.not(Cmp.is_gt(Provenance.decimal_compare(count,"4294967294"))) &&
    Bool.not(Cmp.is_gt(Provenance.decimal_compare(free,count)))

def product_values(a: Maybe<&2,Nat>,b: Maybe<&2,Nat>) -> IO(String):
  match a b:
    case Some{x} Some{y}:
      IO.pure(String,Nat.show(Nat.mul(x,y)))
    case _ _:
      IO.die(String,1,"Storage inventory unavailable: page arithmetic is outside the exact Nat bound")

def pages(+count: String,+size: String,+free: String) -> IO(Pages):
  do IO<Pages>:
    Store.checked(pages_valid(count,size,free),"Storage inventory unavailable: invalid SQLite page quantities")
    total : String <- product_values(Nat.read(count),Nat.read(size))
    reusable : String <- product_values(Nat.read(free),Nat.read(size))
    return Pages{count,size,free,total,reusable}

def rows_layout(row: List<&2,Sql.Cell>) -> IO(Rows):
  match row:
    case [Sql.Cell.Integer{sources},Sql.Cell.Integer{generations},
      Sql.Cell.Integer{accepted},Sql.Cell.Integer{unaccepted},Sql.Cell.Integer{raw},
      Sql.Cell.Integer{bytes},Sql.Cell.Integer{records},Sql.Cell.Integer{events},
      Sql.Cell.Integer{search},Sql.Cell.Integer{contexts},Sql.Cell.Integer{checks},Sql.Cell.Integer{settings},
      Sql.Cell.Integer{archives},Sql.Cell.Integer{containers},Sql.Cell.Integer{compressed}]:
      IO.pure(Rows,Rows{sources,generations,accepted,unaccepted,raw,bytes,records,events,search,contexts,checks,settings,archives,containers,compressed})
    case _:
      IO.die(Rows,1,"Storage inventory unavailable: unexpected owned row-count shape")

def rows_result(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Rows):
  match rows:
    case [+row]:
      do IO<Rows>:
        Store.checked(quantities(row),"Storage inventory unavailable: invalid owned row count or raw-byte sum")
        rows_layout(row)
    case _:
      IO.die(Rows,1,"Storage inventory unavailable: missing owned row counts")

def row_counts(db: U32) -> IO(Rows):
  do IO<Rows>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT (SELECT count(*) FROM main.sources),(SELECT count(*) FROM main.generations),(SELECT count(*) FROM main.snapshots WHERE accepted=1),(SELECT count(*) FROM main.snapshots WHERE accepted<>1),(SELECT count(*) FROM main.raw),(SELECT coalesce(sum(n),0) FROM main.raw),(SELECT count(*) FROM main.records),(SELECT count(*) FROM main.events),(SELECT count(*) FROM main.search),(SELECT count(*) FROM main.snapshot_context),(SELECT count(*) FROM main.projection_checks),(SELECT count(*) FROM main.settings),(SELECT count(*) FROM main.archive_captures),(SELECT count(*) FROM main.archive_chunks),(SELECT coalesce(sum(n),0) FROM main.archive_chunks)",[],1)
    rows_result(rows)

def octal_digits(value: String) -> Bool:
  match value:
    case SNil{}:
      True{}
    case SCon{Chr{+c},rest}:
      U32.is_ge(c,48) && U32.is_le(c,55) && octal_digits(rest)

def regular_mode(+mode: String) -> Bool:
  Nat.is_eq(String.length(mode),6n) && String.starts_with(mode,"10") && octal_digits(mode)

def stat_regular(+bytes: String,regular: Bool) -> FileSize:
  match regular:
    case False{}:
      Unavailable{"not_regular_file"}
    case True{}:
      Bool.pick(FileSize,quantity_valid(bytes),Measured{bytes},Unavailable{"invalid_stat_metadata"})

def stat_values(mode: String,bytes: String) -> FileSize:
  stat_regular(bytes,regular_mode(mode))

def stat_parts(parts: List<&2,String>) -> FileSize:
  match parts:
    case [mode,bytes]:
      stat_values(mode,bytes)
    case _:
      Unavailable{"invalid_stat_metadata"}

def stat_lines(lines: List<&2,String>) -> FileSize:
  match lines:
    case [line,""]:
      stat_parts(String.split(line,':'))
    case _:
      Unavailable{"invalid_stat_metadata"}

def stat_result(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> FileSize:
  match result:
    case Fail{_}:
      Unavailable{"stat_failed"}
    case Done{(0,(out,_))}:
      stat_lines(String.split(out,'\n'))
    case Done{_}:
      Unavailable{"missing_or_inaccessible"}

# The caller supplies only the main path returned by SQLite or its literal
# -wal/-shm sibling. stat defaults to lstat, never -L: links/special files are
# rejected without opening them. No shell, filesystem walk, or content read.
def file_size(path: String) -> IO(FileSize):
  do IO<FileSize>:
    result : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/usr/bin/stat",["-q","-f","%Op:%Dz","--",path],"",1024,2000)
    return stat_result(result)

def path_valid(+path: String) -> Bool:
  String.starts_with(path,"/") && Nat.is_le(String.length(path),4096n) &&
    Bool.not(String.contains(path,"\0"))

def files_absent(+reason: String) -> Files:
  Files{Unavailable{reason},Unavailable{reason},Unavailable{reason}}

def files_valid(+path: String,valid: Bool) -> IO(Files):
  match valid:
    case False{}:
      IO.pure(Files,files_absent("invalid_database_path"))
    case True{}:
      do IO<Files>:
        main : FileSize <- file_size(path)
        wal : FileSize <- file_size(path ++ "-wal")
        shm : FileSize <- file_size(path ++ "-shm")
        return Files{main,wal,shm}

def files_empty(+path: String,empty: Bool) -> IO(Files):
  match empty:
    case True{}:
      IO.pure(Files,files_absent("not_file_backed"))
    case False{}:
      files_valid(path,path_valid(path))

def files(+path: String) -> IO(Files):
  files_empty(path,String.is_empty(path))

def main_path(rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case [[Sql.Cell.Text{path}]]:
      IO.pure(String,path)
    case _:
      IO.die(String,1,"Storage inventory unavailable: main database path is missing or invalid")

# This operation owns its read transaction; call it on a connection without an
# active caller transaction. It changes no database content and never invokes
# checkpoint, VACUUM, source discovery, exports, deletion or external services.
def read(+db: U32) -> IO(Report):
  do IO<Report>:
    Store.exec(db,"BEGIN",[])
    locations : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT file FROM pragma_database_list WHERE name='main'",[],1)
    path : String <- main_path(locations)
    count : String <- scalar(db,"PRAGMA main.page_count")
    size : String <- scalar(db,"PRAGMA main.page_size")
    free : String <- scalar(db,"PRAGMA main.freelist_count")
    page_data : Pages <- pages(count,size,free)
    row_data : Rows <- row_counts(db)
    Store.exec(db,"COMMIT",[])
    file_data : Files <- files(path)
    return Report{file_data,page_data,row_data}

def file_json(value: FileSize) -> String:
  match value:
    case Measured{bytes}:
      "{\"status\":\"measured\",\"logical_bytes\":" ++ Json.quote(bytes) ++ "}"
    case Unavailable{reason}:
      "{\"status\":\"unavailable\",\"logical_bytes\":null,\"reason\":" ++ Json.quote(reason) ++ "}"

def files_json(value: Files) -> String:
  Files{main,wal,shm} = value
  "{\"main\":" ++ file_json(main) ++ ",\"wal\":" ++ file_json(wal) ++ ",\"shm\":" ++ file_json(shm) ++ "}"

def pages_json(value: Pages) -> String:
  Pages{count,size,free,total,reusable} = value
  "{\"page_count\":" ++ Json.quote(count) ++ ",\"page_size\":" ++ Json.quote(size) ++
    ",\"freelist_count\":" ++ Json.quote(free) ++ ",\"logical_bytes\":" ++ Json.quote(total) ++
    ",\"reusable_bytes\":" ++ Json.quote(reusable) ++ "}"

def rows_json(value: Rows) -> String:
  Rows{sources,generations,accepted,unaccepted,raw,bytes,records,events,search,contexts,checks,settings,archives,containers,compressed} = value
  "{\"sources\":" ++ Json.quote(sources) ++ ",\"generations\":" ++ Json.quote(generations) ++
    ",\"accepted_snapshots\":" ++ Json.quote(accepted) ++ ",\"unaccepted_snapshots\":" ++ Json.quote(unaccepted) ++
    ",\"raw_chunks\":" ++ Json.quote(raw) ++ ",\"raw_bytes\":" ++ Json.quote(bytes) ++
    ",\"record_links\":" ++ Json.quote(records) ++ ",\"projected_events\":" ++ Json.quote(events) ++
    ",\"search_rows\":" ++ Json.quote(search) ++ ",\"context_rows\":" ++ Json.quote(contexts) ++
    ",\"projection_checks\":" ++ Json.quote(checks) ++ ",\"settings\":" ++ Json.quote(settings) ++
    ",\"archive_snapshots\":" ++ Json.quote(archives) ++ ",\"container_chunks\":" ++ Json.quote(containers) ++
    ",\"compressed_container_bytes\":" ++ Json.quote(compressed) ++ "}"

def to_json(value: Report) -> String:
  Report{files,pages,rows} = value
  "{\"version\":1,\"files\":" ++ files_json(files) ++ ",\"sqlite\":" ++ pages_json(pages) ++
    ",\"rows\":" ++ rows_json(rows) ++ ",\"physical_reclaimable_bytes\":null," ++
    "\"database_consistency\":\"single_read_transaction\",\"file_consistency\":\"separate_non_atomic_samples\"," ++
    "\"accounting\":\"logical_file_lengths_and_reusable_sqlite_pages\"}"

def reason_text(+reason: String) -> String:
  Bool.pick(String,String.eq(reason,"not_file_backed"),"this library is not stored in a file",
    Bool.pick(String,String.eq(reason,"invalid_database_path"),"invalid database path",
      Bool.pick(String,String.eq(reason,"missing_or_inaccessible"),"file is absent or inaccessible",
        Bool.pick(String,String.eq(reason,"not_regular_file"),"path is a link or nonregular file",
          Bool.pick(String,String.eq(reason,"invalid_stat_metadata"),"invalid file metadata",
            Bool.pick(String,String.eq(reason,"stat_failed"),"file metadata request failed or timed out",reason))))))

def file_summary(label: String,value: FileSize) -> String:
  match value:
    case Measured{bytes}:
      label ++ ": " ++ bytes ++ " bytes\n"
    case Unavailable{reason}:
      label ++ ": unavailable (" ++ reason_text(reason) ++ ")\n"

def files_summary(value: Files) -> String:
  Files{main,wal,shm} = value
  "Logical file sizes\n" ++ file_summary("Main database",main) ++
    file_summary("Write-ahead log (WAL)",wal) ++ file_summary("Shared memory (SHM)",shm)

def page_label(+count: String) -> String:
  count ++ Bool.pick(String,String.eq(count,"1")," page"," pages")

def pages_summary(value: Pages) -> String:
  Pages{count,size,free,total,reusable} = value
  "SQLite space\nLogical database: " ++ page_label(count) ++ " x " ++ size ++ " bytes = " ++ total ++ " bytes\n" ++
    "Reusable inside SQLite: " ++ page_label(free) ++ " = " ++ reusable ++ " bytes\n"

def rows_summary(value: Rows) -> String:
  Rows{sources,generations,accepted,unaccepted,raw,bytes,records,events,search,contexts,checks,settings,archives,containers,compressed} = value
  "Owned capture and library metadata\nSources: " ++ sources ++ "\nGenerations: " ++ generations ++
    "\nAccepted saved versions: " ++ accepted ++ "\nUnaccepted captures: " ++ unaccepted ++
    "\nLogical raw chunks: " ++ raw ++ " (" ++ bytes ++ " bytes, counted once per owned chunk)\n" ++
    "Archive containers: " ++ archives ++ " (" ++ containers ++ " compressed chunks, " ++ compressed ++ " bytes)\n" ++
    "Record references: " ++ records ++ "\nSettings entries: " ++ settings ++
    "\n\nDerived data\nProjected events: " ++ events ++ "\nLexical index rows: " ++ search ++
    "\nContext rows: " ++ contexts ++ "\nProjection checks: " ++ checks ++ "\n"

# Presentation only: consume the already sampled report without any new IO.
def summary(value: Report) -> String:
  Report{files,pages,rows} = value
  "Owned storage inventory\n\n" ++ files_summary(files) ++ "\n" ++ pages_summary(pages) ++
    "\n" ++ rows_summary(rows) ++
    "\nThese views overlap: do not add SQLite logical bytes, raw bytes, and file lengths together. " ++
    "Reusable pages are available to SQLite. Physical reclaimable disk space is not measured.\n\n" ++
    "Database counts share one read transaction. File sizes are separate, non-atomic samples and may change during capture."
