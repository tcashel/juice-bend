import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./paths.bend as Paths
import ./maintenance.bend as Maintenance
import ./archive_meta.bend as ArchiveMeta
import ./zstd/frame.bend as Frame

# There is no original-source IO in this module. Both transformations and
# exports use the exact two byte spaces owned by one SQLite read transaction.
# The transaction-free helpers also serve the capture transaction before and
# after its accepted flag changes; their caller must retain that transaction.

type Cursor is Data:
  Cursor{current: List<&2,U32>,remaining: List<&2,List<&2,U32>>}

type ByteStep is Data:
  ByteStep{value: U32,next: Cursor}

# The outer list shrinks only while crossing a chunk boundary. Ordinary byte
# consumption never copies, slices or flattens the logical output stream.
def next_byte(chunks: List<&2,List<&2,U32>>,current: List<&2,U32>) -> Maybe<&2,ByteStep>:
  match chunks current:
    case remaining Con{byte,tail}:
      Some{ByteStep{byte,Cursor{tail,remaining}}}
    case Nil{} Nil{}:
      None{}
    case Con{chunk,rest} Nil{}:
      next_byte(rest,chunk)

def same_byte(expected: U32,step: ByteStep) -> Maybe<&2,Cursor>:
  ByteStep{actual,next} = step
  Bool.pick(Maybe<&2,Cursor>,U32.is_eq(expected,actual),Some{next},None{})

def consume(bytes: List<&2,U32>,cursor: Cursor) -> Maybe<&2,Cursor>:
  match bytes:
    case Nil{}:
      Some{cursor}
    case Con{byte,rest}:
      Cursor{current,chunks} = cursor
      do Maybe<&2,Cursor>:
        step : ByteStep <- next_byte(chunks,current)
        next : Cursor <- same_byte(byte,step)
        consume(rest,next)

def empty_chunks(chunks: List<&2,List<&2,U32>>) -> Bool:
  match chunks:
    case Nil{}:
      True{}
    case Con{chunk,rest}:
      List.is_empty(&2,U32,chunk) && empty_chunks(rest)

def exhausted(cursor: Cursor) -> Bool:
  Cursor{current,chunks} = cursor
  List.is_empty(&2,U32,current) && empty_chunks(chunks)

def equal_walk(chunks: List<&2,List<&2,U32>>,cursor: Maybe<&2,Cursor>) -> Bool:
  match chunks cursor:
    case _ None{}:
      False{}
    case Nil{} Some{next}:
      exhausted(next)
    case Con{chunk,rest} Some{next}:
      equal_walk(rest,consume(chunk,next))

def equal_chunks(expected: List<&2,List<&2,U32>>,actual: List<&2,List<&2,U32>>) -> Bool:
  equal_walk(actual,Some{Cursor{Nil{},expected}})

def required(origin: Maybe<&2,ArchiveMeta.Origin>) -> IO(ArchiveMeta.Origin):
  match origin:
    case None{}:
      IO.die(ArchiveMeta.Origin,1,"Snapshot is not a captured archive")
    case Some{value}:
      IO.pure(ArchiveMeta.Origin,value)

def origin_header(origin: ArchiveMeta.Origin) -> Maintenance.Header:
  ArchiveMeta.Origin{_,_,generation,provider,_,extent,records,_,_,_,_} = origin
  Maintenance.Header{generation,extent,records,provider}

# Maintenance.record checks raw digests, positions and coverage. This stricter
# archive boundary also rejects values whose textual form happens to resemble
# the required SQLite storage class.
def typed_record(row: List<&2,Sql.Cell>) -> Bool:
  match row:
    case [Sql.Cell.Integer{_},Sql.Cell.Integer{_},Sql.Cell.Integer{_},Sql.Cell.Integer{_},
      Sql.Cell.Text{_},Sql.Cell.Blob{_},Sql.Cell.Integer{_},Sql.Cell.Integer{_},Sql.Cell.Integer{_}]:
      True{}
    case _:
      False{}

def logical_complete(h: Maintenance.Header,offset: U32,
  reversed: List<&2,List<&2,U32>>,expected: String) -> IO(List<&2,List<&2,U32>>):
  do IO<List<&2,List<&2,U32>>>:
    Maintenance.complete(h,offset)
    +chunks : List<&2,List<&2,U32>> = List.reverse(&2,List<&2,U32>,reversed)
    Store.checked(String.eq(ArchiveMeta.digest_chunks(chunks),expected),
      "Archive logical SHA-256 disagrees with retained raw bytes")
    return chunks

def logical_walk(fuel: Nat,+db: U32,+snapshot: String,+h: Maintenance.Header,
  +ordinal: U32,+offset: U32,continued: Bool,reversed: List<&2,List<&2,U32>>,
  expected: String) -> IO(List<&2,List<&2,U32>>):
  match fuel:
    case 0n:
      logical_complete(h,offset,reversed,expected)
    case 1n+rest:
      do IO<List<&2,List<&2,U32>>>:
        +row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,h,ordinal,offset,continued)
        Store.checked(typed_record(row),"Archive logical raw storage types are corrupt")
        logical_walk(rest,db,snapshot,h,U32.add(ordinal,1),
          U32.add(offset,Store.number(Store.field(row,3n))),Maintenance.next_continued(row),
          Con{Store.blob(Store.cell(row,5n)),reversed},expected)

def record_count(rows: List<&2,List<&2,Sql.Cell>>,expected: U32) -> IO(Unit):
  match rows:
    case [[Sql.Cell.Integer{actual}]]:
      Store.checked(String.eq(actual,U32.show(expected)),"Archive logical record count disagrees with snapshot")
    case _:
      IO.die(Unit,1,"Archive logical record count has invalid SQLite type")

def logical_origin(+db: U32,+snapshot: String,+origin: ArchiveMeta.Origin) -> IO(List<&2,List<&2,U32>>):
  ArchiveMeta.Origin{_,_,_,_,_,_,+records,_,_,_,logical_sha} = origin
  do IO<List<&2,List<&2,U32>>>:
    count : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM records WHERE snapshot=?",[Sql.Cell.Integer{snapshot}],1)
    record_count(count,records)
    logical_walk(U32.to_nat(records),db,snapshot,origin_header(origin),0,0,False{},Nil{},logical_sha)

# Full typed origin validation also permits an unaccepted snapshot only when
# the owning capture transaction explicitly passes False.
def logical(+db: U32,+snapshot: String,accepted: Bool) -> IO(List<&2,List<&2,U32>>):
  do IO<List<&2,List<&2,U32>>>:
    maybe : Maybe<&2,ArchiveMeta.Origin> <- ArchiveMeta.read(db,snapshot,accepted)
    origin : ArchiveMeta.Origin <- required(maybe)
    logical_origin(db,snapshot,origin)

def decoded(result: Result<&2,&2,String,List<&2,List<&2,U32>>>) -> IO(List<&2,List<&2,U32>>):
  match result:
    case Fail{error}:
      IO.die(List<&2,List<&2,U32>>,1,"Retained archive cannot be decoded: " ++ error)
    case Done{chunks}:
      IO.pure(List<&2,List<&2,U32>>,chunks)

def limits() -> Frame.Limits:
  Frame.Limits{ArchiveMeta.input_limit(),ArchiveMeta.output_limit(),8388608,64,4096}

def verify_owned(+db: U32,+snapshot: String,+accepted: Bool) -> IO(Unit):
  do IO<Unit>:
    maybe : Maybe<&2,ArchiveMeta.Origin> <- ArchiveMeta.read(db,snapshot,accepted)
    origin : ArchiveMeta.Origin <- required(maybe)
    container : List<&2,List<&2,U32>> <- ArchiveMeta.container(db,snapshot,accepted)
    expected : List<&2,List<&2,U32>> <- decoded(Frame.decode(List.concat(&2,U32,container),limits()))
    actual : List<&2,List<&2,U32>> <- logical_origin(db,snapshot,origin)
    Store.checked(equal_chunks(expected,actual),
      "Retained archive decode does not exactly match captured logical raw bytes")

def verify(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    verify_owned(db,snapshot,True{})
    Store.exec(db,"COMMIT",[])

def write_chunks(chunks: List<&2,List<&2,U32>>,file: File) -> IO(File):
  match chunks:
    case Nil{}:
      IO.pure(File,file)
    case Con{chunk,rest}:
      do IO<File>:
        written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,chunk)
        next : File <- Maintenance.write_result(written)
        write_chunks(rest,next)

# Validate every container row before creating output, retain the transaction
# through writing, then reuse the existing private-temp atomic no-clobber link.
# Publication never opens or replaces the source, even when it has disappeared.
def export_container(+db: U32,+snapshot: String,path: String) -> IO(Unit):
  do IO<Unit>:
    +canonical : String <- Paths.destination(path)
    Store.exec(db,"BEGIN",[])
    chunks : List<&2,List<&2,U32>> <- ArchiveMeta.container(db,snapshot,True{})
    Maintenance.output_canonical(db,canonical)
    +temp : String <- Maintenance.temporary(canonical)
    file : File <- IO.try(File,File.open(temp,"w"))
    finished : File <- write_chunks(chunks,file)
    File.close(finished)
    Store.exec(db,"COMMIT",[])
    Maintenance.publish(temp,canonical)
