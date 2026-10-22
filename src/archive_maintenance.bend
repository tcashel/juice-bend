import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./paths.bend as Paths
import ./maintenance.bend as Maintenance
import ./archive_meta.bend as ArchiveMeta
import ./zstd/frame.bend as Frame
import ./zstd/stream.bend as Decoder
import ./zstd/pair.bend as Pair
import ./zstd/bytes.bend as Bytes
import ./archive_stream.bend as Streaming
import ./domain.bend as Domain
import ./archive_compare.bend as Compare

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

def logical_collected(h: Maintenance.Header,offset: U32,
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
      logical_collected(h,offset,reversed,expected)
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
  ArchiveMeta.Origin{_,_,_,_,_,extent,+records,_,_,_,logical_sha} = origin
  do IO<List<&2,List<&2,U32>>>:
    Store.checked(U32.is_le(extent,ArchiveMeta.output_limit()),"Legacy logical collection exceeds batch bound; use streamed verification or export")
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
# Only one validated retained raw row is pending. This cursor is reused for
# transform verification and immutable old-logical-prefix append checks.
type Logical is Data:
  Logical{origin: ArchiveMeta.Origin,ordinal: U32,offset: U32,continued: Bool,
    pending: List<&2,U32>,hash: Domain.HashContext,consumed: U32}

def logical_begin(+db: U32,+origin: ArchiveMeta.Origin) -> IO(Logical):
  ArchiveMeta.Origin{snapshot,_,_,_,_,_,records,_,_,_,_} = origin
  do IO<Logical>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT count(*) FROM records WHERE snapshot=?",
      [Sql.Cell.Integer{snapshot}],1)
    record_count(rows,records)
    return Logical{origin,0,0,False{},[],ArchiveMeta.initial_hash(),0}

def logical_loaded(cursor: Logical,+row: List<&2,Sql.Cell>) -> IO(Logical):
  Logical{origin,ordinal,offset,_,_,hash,consumed} = cursor
  +bytes = Store.blob(Store.cell(row,5n))
  do IO<Logical>:
    Store.checked(typed_record(row),"Archive raw record has a wrong SQLite storage type")
    return Logical{origin,U32.inc(ordinal),U32.add(offset,Store.number(Store.field(row,3n))),
      Maintenance.next_continued(row),bytes,Domain.hash_bytes(bytes,hash),consumed}

def logical_load(+db: U32,+cursor: Logical) -> IO(Logical):
  Logical{+origin,+ordinal,offset,continued,_,_,_} = cursor
  ArchiveMeta.Origin{snapshot,_,_,_,_,_,count,_,_,_,_} = origin
  do IO<Logical>:
    Store.checked(U32.is_lt(ordinal,count),"Archive decoded output exceeds retained logical records")
    row : List<&2,Sql.Cell> <- Maintenance.record(db,snapshot,origin_header(origin),ordinal,offset,continued)
    logical_loaded(cursor,row)

def logical_complete(cursor: Logical) -> IO(Unit):
  Logical{origin,ordinal,offset,_,pending,hash,consumed} = cursor
  ArchiveMeta.Origin{_,_,_,_,_,+extent,count,_,_,_,sha} = origin
  Store.checked(U32.is_eq(ordinal,count) && U32.is_eq(offset,extent) && U32.is_eq(consumed,extent) &&
    List.is_empty(&2,U32,pending) && String.eq(Domain.hash_finish(hash),sha),
    "Archive logical bytes, extent or SHA256 do not match its origin")

def equal_parts(cursor: Logical,count: U32,left: Pair.Duo(List<&2,U32>,List<&2,U32>),
  right: Pair.Duo(List<&2,U32>,List<&2,U32>),next: Logical -> List<&2,U32> -> IO(Logical)) -> IO(Logical):
  Logical{origin,ordinal,offset,continued,_,hash,consumed} = cursor
  (expected,remaining) = left
  (actual,tail) = right
  do IO<Logical>:
    Store.checked(Compare.equal([expected],[actual]),"Archive decoded bytes disagree with immutable logical raw bytes")
    next(Logical{origin,ordinal,offset,continued,remaining,hash,U32.add(consumed,count)},tail)

def logical_compare_empty(finished: Bool,prefix: Bool,db: U32,cursor: Logical,next: Logical -> IO(Logical)) -> IO(Logical):
  match finished prefix:
    case True{} True{}: IO.pure(Logical,cursor)
    case True{} False{}: IO.die(Logical,1,"Archive decoded output exceeds retained logical extent")
    case False{} _:
      do IO<Logical>:
        loaded : Logical <- logical_load(db,cursor)
        next(loaded)

def logical_compare_loop(fuel: Nat,bytes: List<&2,U32>,+remaining: U32,+db: U32,+cursor: Logical,+prefix: Bool) -> IO(Logical):
  match fuel bytes:
    case _ Nil{}: IO.pure(Logical,cursor)
    case 0n _: IO.die(Logical,1,"Archive logical comparison exhausted bounded byte count")
    case 1n+rest +input:
      Logical{ArchiveMeta.Origin{_,_,_,_,_,extent,_,_,_,_,_},_,_,_,pending,_,consumed} = cursor
      match pending:
        case []:
          logical_compare_empty(U32.is_eq(consumed,extent),prefix,db,cursor,next => logical_compare_loop(rest,input,remaining,db,next,prefix))
        case +raw:
          +count = U32.min(U32.from_nat(List.length(&2,U32,raw)),remaining)
          do IO<Logical>:
            left : Pair.Duo(List<&2,U32>,List<&2,U32>) <- Streaming.data_result(Pair.Duo(List<&2,U32>,List<&2,U32>),Bytes.take(raw,count))
            right : Pair.Duo(List<&2,U32>,List<&2,U32>) <- Streaming.data_result(Pair.Duo(List<&2,U32>,List<&2,U32>),Bytes.take(input,count))
            equal_parts(cursor,count,left,right,next => tail => logical_compare_loop(rest,tail,U32.sub(remaining,count),db,next,prefix))

def logical_compare(fuel: Nat,db: U32,cursor: Logical,+bytes: List<&2,U32>,prefix: Bool) -> IO(Logical):
  logical_compare_loop(fuel,bytes,U32.from_nat(List.length(&2,U32,bytes)),db,cursor,prefix)

# A data-bound state wrapper avoids retaining decoder blocks between visits.
type Check is Data:
  Check{db: U32,cursor: Logical,prefix: Bool}

def check_consume(fuel: Nat,state: Check,+bytes: List<&2,U32>) -> IO(Streaming.Visitor<Check>):
  match fuel:
    case 0n: IO.die(Streaming.Visitor<Check>,1,"Archive verification visits exceeded bounded input")
    case 1n+rest:
      Check{+db,cursor,+prefix} = state
      do IO<Streaming.Visitor<Check>>:
        next : Logical <- logical_compare(U32.to_nat(U32.add(U32.mul(U32.from_nat(List.length(&2,U32,bytes)),2),2)),db,cursor,bytes,prefix)
        return Streaming.Visitor{Check{db,next,prefix},state => chunk => check_consume(rest,state,chunk)}

def checked_stream(result: Check & Decoder.Summary,expected: U32) -> IO(Unit):
  (Check{_,cursor,_},Decoder.Summary{_,output,_}) = result
  do IO<Unit>:
    logical_complete(cursor)
    Store.checked(U32.is_eq(output,expected),"Archive decoded output extent disagrees with origin")

def logical_advance(cursor: Logical) -> Logical:
  Logical{origin,ordinal,+offset,continued,_,hash,_} = cursor
  Logical{origin,ordinal,offset,continued,[],hash,offset}

def logical_validate_walk(fuel: Nat,+db: U32,cursor: Logical) -> IO(Unit):
  match fuel:
    case 0n: logical_complete(cursor)
    case 1n+rest:
      do IO<Unit>:
        next : Logical <- logical_load(db,cursor)
        logical_validate_walk(rest,db,logical_advance(next))

def validate_logical(+db: U32,+origin: ArchiveMeta.Origin) -> IO(Unit):
  ArchiveMeta.Origin{_,_,_,_,_,_,records,_,_,_,_} = origin
  do IO<Unit>:
    cursor : Logical <- logical_begin(db,origin)
    logical_validate_walk(U32.to_nat(records),db,cursor)

def validate_opened(+db: U32,opened: ArchiveMeta.Open) -> IO(Unit):
  ArchiveMeta.Open{origin,reader} = opened
  do IO<Unit>:
    ArchiveMeta.validate_reader(db,reader)
    validate_logical(db,origin)

def verified_open(+db: U32,opened: ArchiveMeta.Open) -> IO(Unit):
  ArchiveMeta.Open{+origin,reader} = opened
  ArchiveMeta.Origin{_,_,_,_,_,extent,_,_,_,_,_} = origin
  do IO<Unit>:
    cursor : Logical <- logical_begin(db,origin)
    result : Check & Decoder.Summary <- Streaming.run(Check,db,reader,Streaming.Visitor{Check{db,cursor,False{}},state => chunk => check_consume(67108864n,state,chunk)})
    checked_stream(result,extent)

def verify_owned(+db: U32,snapshot: String,accepted: Bool) -> IO(Unit):
  do IO<Unit>:
    opened : ArchiveMeta.Open <- ArchiveMeta.open_reader(db,snapshot,accepted)
    verified_open(db,opened)

def verify(+db: U32,+snapshot: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    verify_owned(db,snapshot,True{})
    Store.exec(db,"COMMIT",[])

def export_step(read: ArchiveMeta.Read,file: File,next: ArchiveMeta.Reader -> File -> IO(File)) -> IO(File):
  ArchiveMeta.Read{reader,bytes} = read
  match bytes:
    case None{}: IO.pure(File,file)
    case Some{chunk}:
      do IO<File>:
        written : File <- write_chunks([chunk],file)
        next(reader,written)

def export_walk(fuel: Nat,+db: U32,reader: ArchiveMeta.Reader,file: File) -> IO(File):
  match fuel:
    case 0n: IO.die(File,1,"Archive export exceeded bounded chunk count")
    case 1n+rest:
      do IO<File>:
        read : ArchiveMeta.Read <- ArchiveMeta.next(db,reader)
        export_step(read,file,next => out => export_walk(rest,db,next,out))

def export_opened(+db: U32,path: String,opened: ArchiveMeta.Open) -> IO(Unit):
  ArchiveMeta.Open{ArchiveMeta.Origin{_,_,_,_,_,_,_,_,chunks,_,_},+reader} = opened
  do IO<Unit>:
    ArchiveMeta.validate_reader(db,reader)
    +canonical : String <- Paths.destination(path)
    Maintenance.output_canonical(db,canonical)
    +temp : String <- Maintenance.temporary(canonical)
    file : File <- IO.try(File,File.open(temp,"w"))
    written : File <- export_walk(U32.to_nat(U32.inc(chunks)),db,reader,file)
    File.close(written)
    Store.exec(db,"COMMIT",[])
    Maintenance.publish(temp,canonical)

def export_container(+db: U32,+snapshot: String,path: String) -> IO(Unit):
  do IO<Unit>:
    Store.exec(db,"BEGIN",[])
    opened : ArchiveMeta.Open <- ArchiveMeta.open_reader(db,snapshot,True{})
    export_opened(db,path,opened)
