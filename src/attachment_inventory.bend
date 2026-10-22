import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./archive_meta.bend as Meta
import ./maintenance.bend as Maintenance
import ./attachment_extract.bend as Extract

# Retained raw records are the sole attachment authority. This module owns one
# read transaction; no event projection, original file or external asset is read.
type Failure is Data:
  Failure{code: String,message: String}

type Body is Data:
  Extracted{report: Extract.Report}
  OversizedFragment{}
  InvalidUtf8{}

type Record is Data:
  Record{ordinal: U32,offset: U32,length: U32,digest: String,body: Body}

type Page is Data:
  Page{capture: Meta.Header,start: U32,requested: U32,selected: U32,
    records: List<&2,Record>}

def fail(code: String,message: String) -> Failure:
  Failure{code,message}

def transaction_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> Result<&2,&2,Failure,Unit>:
  match result:
    case Done{_}: Done{Unit{}}
    case Fail{(code,_)}:
      Fail{fail("attachment_transaction_unavailable","Cannot own attachment read transaction (SQLite " ++
        U32.show(code) ++ "); any existing caller transaction remains untouched")}

def transaction(db: U32) -> IO(Result<&2,&2,Failure,Unit>):
  do IO<Result<&2,&2,Failure,Unit>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"BEGIN DEFERRED",[],0)
    return transaction_result(result)

def cleanup_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>,page: Page) -> Result<&2,&2,Failure,Page>:
  match result:
    case Done{_}: Done{page}
    case Fail{(code,_)}:
      Fail{fail("attachment_cleanup_failed","Owned attachment read rollback failed (SQLite " ++
        U32.show(code) ++ "); resolve connection transaction state before reuse")}

# Admission transfers only lengths/types before any BLOB. Selected_record still
# verifies digest, generation, exact map ordinal, extent and predecessor boundary.
def admitted(row: List<&2,Sql.Cell>) -> Bool:
  match row:
    case [Sql.Cell.Integer{+n},Sql.Cell.Text{"blob"},Sql.Cell.Integer{length}]:
      Store.numeric(n) && U32.is_gt(Store.number(n),0) &&
        U32.is_le(Store.number(n),262144) && String.eq(n,length)
    case _: False{}

def admit_rows(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  match rows:
    case []: IO.pure(Unit,Unit{})
    case row <> rest:
      do IO<Unit>:
        Store.checked(admitted(row),"Attachment raw payload type or size admission failed")
        admit_rows(rest)

def admission(+db: U32,snapshot: String,+ordinal: U32) -> IO(Unit):
  +before = Bool.to_u32(U32.is_gt(ordinal,0))
  do IO<Unit>:
    +rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT r.n,typeof(r.bytes),length(r.bytes) FROM records i LEFT JOIN raw r ON r.id=i.raw WHERE i.snapshot=? AND i.ordinal>=? AND i.ordinal<=? ORDER BY i.ordinal",
      [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(U32.sub(ordinal,before))},Sql.Cell.Integer{U32.show(ordinal)}],2)
    Store.checked(Nat.is_eq(List.length(&2,List<&2,Sql.Cell>,rows),U32.to_nat(U32.inc(before))),
      "Attachment record location index admission failed")
    admit_rows(rows)

def decoded(provider: String,result: Result<&2,&2,String,String>) -> Body:
  match result:
    case Fail{_}: InvalidUtf8{}
    case Done{text}: Extracted{Extract.analyze(provider,text)}

def body(oversized: Bool,provider: String,bytes: List<&2,U32>) -> Body:
  match oversized:
    case True{}: OversizedFragment{}
    case False{}: decoded(provider,Domain.decode(bytes))

def record(provider: String,+ordinal: U32,+row: List<&2,Sql.Cell>) -> Record:
  Record{ordinal,Store.number(Store.field(row,2n)),Store.number(Store.field(row,3n)),
    Store.field(row,4n),body(U32.is_ne(Store.number(Store.field(row,6n)),0),provider,Store.blob(Store.cell(row,5n)))}

def walk(fuel: Nat,+db: U32,+capture: Meta.Header,+ordinal: U32,records: List<&2,Record>) -> IO(List<&2,Record>):
  match fuel:
    case 0n: IO.pure(List<&2,Record>,List.reverse(&2,Record,records))
    case 1n+left:
      Meta.Header{+snapshot,_,+generation,+provider,_,+extent,+total,_,_,_,_} = capture
      do IO<List<&2,Record>>:
        admission(db,snapshot,ordinal)
        raw : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,extent,total,ordinal)
        walk(left,db,capture,U32.inc(ordinal),record(provider,ordinal,raw) <> records)

def same_header(h: Maintenance.Header,capture: Meta.Header) -> Bool:
  Maintenance.Header{generation,extent,total,provider} = h
  Meta.Header{_,_,actual_generation,actual_provider,_,actual_extent,actual_total,_,_,_,_} = capture
  String.eq(generation,actual_generation) && String.eq(provider,actual_provider) &&
    U32.is_eq(extent,actual_extent) && U32.is_eq(total,actual_total)

# Internal seam after transaction ownership. Both headers share the established
# SQLite view; Maintenance.header verifies archive envelope and full map count.
def collect_header(+db: U32,verified: Maintenance.Header,+capture: Meta.Header,+start: U32,+count: U32) -> IO(Page):
  Meta.Header{_,_,_,_,_,_,total,_,_,_,_} = capture
  +size = Domain.bounded_count(start,count,total)
  do IO<Page>:
    Store.checked(same_header(verified,capture),"Attachment capture header changed within read view")
    records : List<&2,Record> <- walk(U32.to_nat(size),db,capture,start,[])
    return Page{capture,start,count,size,records}

def read_header(+db: U32,+snapshot: String,start: U32,count: U32) -> IO(Page):
  do IO<Page>:
    verified : Maintenance.Header <- Maintenance.header(db,snapshot)
    capture : Meta.Header <- Meta.header(db,snapshot,True{})
    collect_header(db,verified,capture,start,count)

def read_owned(owned: Result<&2,&2,Failure,Unit>,+db: U32,snapshot: String,start: U32,count: U32) -> IO(Result<&2,&2,Failure,Page>):
  match owned:
    case Fail{failure}: IO.pure(Result<&2,&2,Failure,Page>,Fail{failure})
    case Done{_}:
      do IO<Result<&2,&2,Failure,Page>>:
        page : Page <- read_header(db,snapshot,start,count)
        closed : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"ROLLBACK",[],0)
        return cleanup_result(closed,page)

def read_valid(valid: Bool,+db: U32,snapshot: String,start: U32,count: U32) -> IO(Result<&2,&2,Failure,Page>):
  match valid:
    case False{}:
      IO.pure(Result<&2,&2,Failure,Page>,Fail{fail("attachment_invalid_request",
        "Requires an immutable positive signed64 snapshot ID and 1..40 raw records")})
    case True{}:
      do IO<Result<&2,&2,Failure,Page>>:
        owned : Result<&2,&2,Failure,Unit> <- transaction(db)
        read_owned(owned,db,snapshot,start,count)

# Fatal database integrity failures terminate the worker; its connection teardown
# releases the owned read transaction. Ordinary Result paths roll back explicitly.
def read(db: U32,+snapshot: String,start: U32,+count: U32) -> IO(Result<&2,&2,Failure,Page>):
  read_valid(Meta.identity(snapshot) && U32.is_gt(count,0) && U32.is_le(count,40),db,snapshot,start,count)

def complete_body(body: Body) -> Bool:
  match body:
    case Extracted{report}: Extract.complete(report)
    case _: False{}

def body_count(body: Body) -> U32:
  match body:
    case Extracted{report}: Extract.count(report)
    case _: 0

def record_counts(rows: List<&2,Record>,complete: U32,refs: U32) -> U32 & U32:
  match rows:
    case []: (complete,refs)
    case Record{_,_,_,_,+body} <> rest:
      record_counts(rest,U32.add(complete,Bool.to_u32(complete_body(body))),U32.add(refs,body_count(body)))

def next(+total: U32,+start: U32,+selected: U32) -> Maybe<&2,U32>:
  Bool.pick(Maybe<&2,U32>,U32.is_gt(selected,0) && U32.is_le(start,total) &&
    U32.is_lt(selected,U32.sub(total,start)),Some{U32.add(start,selected)},None{})
