import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./paths.bend as Paths

# These operations never consult the original source. Raw bytes, positions and
# digests are checked in a single SQLite snapshot before any projection change.
type Header is Data:
  Header{generation: String, extent: U32, records: U32, provider: String}

def header_row(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Header):
  match rows:
    case Nil{}:
      IO.die(Header,1,"Accepted snapshot not found")
    case Con{+row,_}:
      do IO<Header>:
        Store.checked(Store.numeric(Store.field(row,1n)) &&
          Store.numeric(Store.field(row,2n)) &&
          Store.numeric(Store.field(row,4n)) &&
          String.eq(Store.field(row,2n),Store.field(row,4n)),
          "Snapshot numeric metadata or record count is corrupt")
        return Header{Store.field(row,0n),Store.number(Store.field(row,1n)),
          Store.number(Store.field(row,2n)),Store.field(row,3n)}

def header(db: U32,snapshot: String) -> IO(Header):
  do IO<Header>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.generation,p.extent,p.records,s.provider,(SELECT count(*) FROM records r WHERE r.snapshot=p.id) FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
      [Sql.Cell.Integer{snapshot}],1)
    header_row(rows)

def record_checked(rows: List<&2,List<&2,Sql.Cell>>,h: Header,
  ordinal: U32,offset: U32,continued: Bool) -> IO(List<&2,Sql.Cell>):
  match rows:
    case Nil{}:
      IO.die(List<&2,Sql.Cell>,1,"Snapshot record location is missing")
    case Con{+row,_}:
      Header{generation,extent,records,_} = h
      do IO<List<&2,Sql.Cell>>:
        Store.checked(Store.record_valid(row,generation,extent,records,ordinal,offset,continued),
          "Captured raw integrity, generation, position or coverage metadata mismatch")
        return row

def record(db: U32,snapshot: String,h: Header,+ordinal: U32,
  offset: U32,continued: Bool) -> IO(List<&2,Sql.Cell>):
  do IO<List<&2,Sql.Cell>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.generation,r.ordinal,r.offset,r.n,r.digest,r.bytes,r.oversized,r.complete,i.ordinal FROM records i JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal=?",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],1)
    record_checked(rows,h,ordinal,offset,continued)

def next_continued(row: List<&2,Sql.Cell>) -> Bool:
  String.eq(Store.field(row,7n),"0")

def complete(h: Header,offset: U32) -> IO(Unit):
  Header{_,extent,_,_} = h
  Store.checked(U32.is_eq(extent,offset),"Raw record extents do not cover the complete accepted snapshot")

def verify_walk(fuel: Nat,+db: U32,+snapshot: String,+h: Header,
  +ordinal: U32,+offset: U32,continued: Bool) -> IO(Unit):
  match fuel:
    case 0n:
      complete(h,offset)
    case 1n+rest:
      do IO<Unit>:
        +row : List<&2,Sql.Cell> <- record(db,snapshot,h,ordinal,offset,continued)
        verify_walk(rest,db,snapshot,h,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),next_continued(row))

def verify_header(+db: U32,+snapshot: String,+h: Header) -> IO(Unit):
  Header{_,_,records,_} = h
  verify_walk(U32.to_nat(records),db,snapshot,h,0,0,False{})

def verify(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    h : Header <- header(db,snapshot)
    verify_header(db,snapshot,h)
    Store.exec(db,"COMMIT",[])

def output_absent(result: Result<&1,&1,U32 & String,File>) -> IO(Unit):
  match result:
    case Done{file}:
      do IO<Unit>:
        File.close(file)
        IO.die(Unit,1,"Export destination already exists; choose a new file")
    case Fail{(code,message)}:
      Store.checked(U32.is_eq(code,2),"Export destination cannot be safely inspected: " ++ message)

def output_canonical(+db: U32,+path: String) -> IO(Unit):
  do IO<Unit>:
    Store.checked(Bool.not(String.is_empty(path)) && Bool.not(String.contains(path,"\0")),
      "Export destination must be a nonempty filesystem path")
    sources : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM sources WHERE locator=?",[Sql.Cell.Text{path}],1)
    Store.checked(String.eq(Store.field(Store.first(sources),0n),"0"),
      "Export destination is a source locator; sources remain read-only")
    opened : Result<&1,&1,U32 & String,File> <- File.open(path,"r")
    output_absent(opened)

def output_path(+db: U32,path: String) -> IO(Unit):
  do IO<Unit>:
    canonical : String <- Paths.destination(path)
    output_canonical(db,canonical)

def process_ok(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Bool:
  match result:
    case Fail{_}:
      False{}
    case Done{(code,_)}:
      U32.is_eq(code,0)

def temporary_result(destination: String,result: U32 & (String & String)) -> IO(String):
  (code,(out,_)) = result
  do IO<String>:
    +path : String <- Paths.canonical_output(code,out)
    Store.checked(String.starts_with(path,destination ++ ".tmp."),
      "Temporary export path did not match requested parent")
    return path

def temporary(+destination: String) -> IO(String):
  do IO<String>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),
      Process.run("/usr/bin/mktemp",[destination ++ ".tmp.XXXXXX"],"",8192,2000))
    temporary_result(destination,result)

# /bin/link is the OS link(2) utility: unlike ln's directory convenience
# behavior, it names one exact new destination and fails if any entry exists.
def publish(+temporary: String,destination: String) -> IO(Unit):
  do IO<Unit>:
    linked : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/link",[temporary,destination],"",8192,2000)
    removed : Result<&1,&1,U32 & String,U32 & (String & String)> <-
      Process.run("/bin/rm",["--",temporary],"",8192,2000)
    Store.checked(process_ok(linked),
      "Export destination appeared or atomic publication failed; destination was not replaced")
    Store.checked(process_ok(removed),
      "Export published, but its private temporary file could not be removed")

def write_text(+db: U32,path: String,text: String) -> IO(Unit):
  do IO<Unit>:
    +canonical : String <- Paths.destination(path)
    output_canonical(db,canonical)
    +temp : String <- temporary(canonical)
    Store.write_text(temp,"w",text)
    publish(temp,canonical)

def write_result(result: File & Result<&1,&1,U32 & String,Unit>) -> IO(File):
  (file,written) = result
  match written:
    case Done{_}:
      IO.pure(File,file)
    case Fail{(code,message)}:
      do IO<File>:
        File.close(file)
        IO.die(File,code,"Raw export failed; output may be partial: " ++ message)

def export_walk(fuel: Nat,+db: U32,+snapshot: String,+h: Header,
  +ordinal: U32,+offset: U32,continued: Bool,file: File) -> IO(File):
  match fuel:
    case 0n:
      do IO<File>:
        complete(h,offset)
        return file
    case 1n+rest:
      do IO<File>:
        +row : List<&2,Sql.Cell> <- record(db,snapshot,h,ordinal,offset,continued)
        written : File & Result<&1,&1,U32 & String,Unit> <-
          File.write_bytes(file,Store.blob(Store.cell(row,5n)))
        next : File <- write_result(written)
        export_walk(rest,db,snapshot,h,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),next_continued(row),next)

def export_header(+db: U32,+snapshot: String,path: String,+h: Header) -> IO(Unit):
  Header{_,_,records,_} = h
  do IO<Unit>:
    file : File <- IO.try(File,File.open(path,"w"))
    finished : File <- export_walk(U32.to_nat(records),db,snapshot,h,0,0,False{},file)
    File.close(finished)

def export_raw(+db: U32,+snapshot: String,path: String) -> IO(Unit):
  do IO<Unit>:
    +canonical : String <- Paths.destination(path)
    Store.exec(db,"BEGIN",[])
    +h : Header <- header(db,snapshot)
    verify_header(db,snapshot,h)
    output_canonical(db,canonical)
    +temp : String <- temporary(canonical)
    export_header(db,snapshot,temp,h)
    Store.exec(db,"COMMIT",[])
    publish(temp,canonical)

def replay_walk(fuel: Nat,+db: U32,+snapshot: String,+h: Header,
  +ordinal: U32,+offset: U32,continued: Bool,+context: Store.Context) -> IO(Unit):
  match fuel:
    case 0n:
      complete(h,offset)
    case 1n+rest:
      Header{_,extent,_,+provider} = h
      do IO<Unit>:
        +row : List<&2,Sql.Cell> <- record(db,snapshot,h,ordinal,offset,continued)
        Store.put_record_context(db,snapshot,extent,row,context)
        next : Store.Context <- Store.put_events(Store.piece_events(
          String.eq(Store.field(row,6n),"1"),provider,Store.blob(Store.cell(row,5n))),
          db,snapshot,ordinal,0,provider,context)
        replay_walk(rest,db,snapshot,h,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),next_continued(row),next)

def rebuild_header(+db: U32,+snapshot: String,+h: Header) -> IO(Unit):
  Header{_,_,records,_} = h
  do IO<Unit>:
    Store.exec(db,"DELETE FROM search WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"DELETE FROM events WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    Store.exec(db,"DELETE FROM snapshot_context WHERE snapshot=?",[Sql.Cell.Integer{snapshot}])
    replay_walk(U32.to_nat(records),db,snapshot,h,0,0,False{},Store.Context{"","","",""})
    Store.seal_projection(db,snapshot)
    Store.refresh_search(db,snapshot)

def rebuild(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN IMMEDIATE",[])
    +h : Header <- header(db,snapshot)
    verify_header(db,snapshot,h)
    rebuild_header(db,snapshot,h)
    Store.exec(db,"COMMIT",[])
