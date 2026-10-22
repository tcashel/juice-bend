import Base
import ./atif_types.bend as T
import ./atif_format.bend as F
import ./atif_spool.bend as Spool
import ./session_usage.bend as U
import ./providers.bend as P
import ./store.bend as S
import ./sql.bend as Sql
import ./maintenance.bend as M
import ./archive_meta.bend as Archive
import ./paths.bend as Paths
import ./domain.bend as D
import ./json.bend as J

# This API follows existing maintenance exports: a refused operation terminates
# its dedicated worker. The worker's connection closes, dropping TEMP state and
# rolling back its owned transaction. A successful operation explicitly rolls
# back before publishing. No statement writes main database data or schema.
def require(-A: Kind(&2),result: Result<&2,&2,T.Failure,A>) -> IO(A):
  match result:
    case Done{value}: IO.pure(A,value)
    case Fail{T.Failure{code,message}}: IO.die(A,2,code ++ ": " ++ message)

def usage_required(-A: Kind(&2),result: Result<&2,&2,U.Failure,A>) -> IO(A):
  match result:
    case Done{value}: IO.pure(A,value)
    case Fail{U.Failure{code,message}}: IO.die(A,2,code ++ ": " ++ message)

def limits_valid(limits: T.Limits) -> Bool:
  T.Limits{+records,+bytes,+events,+step,+output} = limits
  U32.is_gt(records,0) && U32.is_le(records,1000000) && U32.is_gt(bytes,0) && U32.is_le(bytes,1073741824) &&
    U32.is_gt(events,0) && U32.is_le(events,2000000) && U32.is_gt(step,0) && U32.is_le(step,2097152) &&
    U32.is_gt(output,0) && U32.is_le(output,2147483648)

def archive_json(origin: Archive.Origin) -> String:
  Archive.Origin{snapshot,source,generation,provider,locator,extent,records,compressed,chunks,sha,logical} = origin
  "{\"snapshot\":" ++ J.quote(snapshot) ++ ",\"source_id\":" ++ J.quote(source) ++
    ",\"generation\":" ++ J.quote(generation) ++ ",\"provider\":" ++ J.quote(provider) ++
    ",\"locator\":" ++ J.quote(locator) ++ ",\"logical_extent\":" ++ U32.show(extent) ++
    ",\"records\":" ++ U32.show(records) ++ ",\"compressed_extent\":" ++ U32.show(compressed) ++
    ",\"chunks\":" ++ U32.show(chunks) ++ ",\"compressed_sha256\":" ++ J.quote(sha) ++
    ",\"logical_sha256\":" ++ J.quote(logical) ++ "}"

def origin(archive: Maybe<&2,Archive.Origin>,capture: U.Capture) -> T.Origin:
  match archive:
    case None{}: T.Origin{capture,"original-file-bytes","null"}
    case Some{value}: T.Origin{capture,"logical-decoded-jsonl-bytes",archive_json(value)}

def admitted(capture: U.Capture,limits: T.Limits) -> IO(Unit):
  U.Capture{_,_,_,_,_,extent,+records} = capture
  T.Limits{maxrecords,maxbytes,_,_,_} = limits
  S.checked(U32.is_gt(records,0) && U32.is_le(records,maxrecords) && U32.is_le(extent,maxbytes),
    "ATIF requires a nonempty complete snapshot within the record/byte supported envelope")

# Usage limits do not silently turn a full export into a partial page. A usage
# accumulator limit makes its report incomplete while raw export traversal
# continues independently and standard totals remain omitted.
type Accounting is Data:
  Counting{state: U.State}
  Unknown{report: U.Report}

def account_batch(batch: U.Batch) -> Accounting:
  match batch:
    case U.Advanced{state}: Counting{state}
    case U.Stopped{state,reason}: Unknown{U.report(state,False{},reason)}

def account(accounting: Accounting,row: List<&2,Sql.Cell>) -> Accounting:
  match accounting:
    case Counting{state}: account_batch(U.consume_row(row,state))
    case Unknown{report}: Unknown{report}

def report(accounting: Accounting) -> U.Report:
  match accounting:
    case Counting{state}: U.report(state,True{},"Complete retained snapshot scanned")
    case Unknown{value}: value

type Stage is Data:
  Stage{context: S.Context,events: U32,payload: U32}

# A presentation-only marker for a provider record with zero events must not
# change the context state that the normal typed traversal would retain.
def retain_context(context: S.Context,projected: S.Context & P.Record) -> S.Context & P.Record:
  (_,event) = projected
  (context,event)

def project_marker(marker: Bool,provider: String,+context: S.Context,event: P.Record) -> S.Context & P.Record:
  match marker:
    case True{}: retain_context(context,S.contextualize(provider,context,event))
    case False{}: S.contextualize(provider,context,event)

def project_event(provider: String,context: S.Context,+event: P.Record) -> S.Context & P.Record:
  P.ProviderEvent{_,_,_,_,_,_,_,_,_,_,_,_,coverage} = event
  project_marker(String.eq(coverage,"unmapped_record"),provider,context,event)

def contextualized(projected: S.Context & P.Record,number: U32,record: U32,slot: U32,
  +row: List<&2,Sql.Cell>,metadata: String) -> S.Context & T.AtifEvent:
  (context,value) = projected
  (context,T.AtifEvent{number,record,slot,S.number(S.field(row,2n)),S.number(S.field(row,3n)),S.field(row,4n),
    String.eq(S.field(row,7n),"1"),String.eq(S.field(row,6n),"1"),metadata,value})

def stage_one(projected: S.Context & T.AtifEvent,db: U32,payload: U32,limit: U32) -> IO(Stage):
  (context,+event) = projected
  T.AtifEvent{number,_,_,_,_,_,_,_,_,_} = event
  do IO<Stage>:
    size : U32 <- Spool.insert(db,event,payload,limit)
    return Stage{context,U32.inc(number),size}

def stage_events(values: List<&2,P.Record>,+db: U32,+provider: String,+record: U32,+slot: U32,
  +row: List<&2,Sql.Cell>,stage: Stage,+limits: T.Limits) -> IO(Stage):
  match values:
    case []: IO.pure(Stage,stage)
    case +value <> rest:
      Stage{context,+events,payload} = stage
      T.Limits{_,_,maxevents,_,output} = limits
      do IO<Stage>:
        S.checked(U32.is_lt(events,maxevents),"ATIF event supported envelope exceeded; no partial document published")
        next : Stage <- stage_one(contextualized(project_event(provider,context,value),events,record,slot,row,Spool.recorded(value)),db,payload,output)
        stage_events(rest,db,provider,record,U32.inc(slot),row,next,limits)

def events(values: List<&2,P.Record>) -> List<&2,P.Record>:
  match values:
    case []: [P.ProviderEvent{"unsupported","[Retained record has no mapped transcript events]","","","","","","","","","","","unmapped_record"}]
    case first <> rest: first <> rest

type Scan is Data:
  Scan{stage: Stage,accounting: Accounting,offset: U32,continued: Bool}

def scan_walk(fuel: Nat,+db: U32,+snapshot: String,+header: M.Header,+capture: U.Capture,
  +provider: String,+ordinal: U32,scan: Scan,+limits: T.Limits) -> IO(Scan):
  match fuel:
    case 0n:
      Scan{stage,accounting,+offset,continued} = scan
      do IO<Scan>:
        M.complete(header,offset)
        return Scan{stage,accounting,offset,continued}
    case 1n+rest:
      Scan{stage,accounting,+offset,+continued} = scan
      do IO<Scan>:
        +row : List<&2,Sql.Cell> <- M.record(db,snapshot,header,ordinal,offset,continued)
        S.checked(U.raw_valid(row,capture,U.Cursor{ordinal,offset,continued}),"ATIF retained raw typed identity or integrity mismatch")
        next : Stage <- stage_events(events(S.piece_events(String.eq(S.field(row,6n),"1"),provider,S.blob(S.cell(row,5n)))),db,provider,ordinal,0,row,stage,limits)
        scan_walk(rest,db,snapshot,header,capture,provider,U32.inc(ordinal),
          Scan{next,account(accounting,row),U32.add(offset,S.number(S.field(row,3n))),M.next_continued(row)},limits)

def scan(+db: U32,+capture: U.Capture,+limits: T.Limits) -> IO(Scan):
  U.Capture{+provider,_,_,+generation,+snapshot,+extent,+records} = capture
  scan_walk(U32.to_nat(records),db,snapshot,M.Header{generation,extent,records,provider},capture,provider,0,
    Scan{Stage{S.Context{"","","",""},0,0},Counting{U.initial(capture,U.defaults())},0,False{}},limits)

type Output is Type:
  Output{file: File,bytes: U32,steps: U32}

def write_bytes(output: Output,+bytes: List<&2,U32>,+limit: U32) -> IO(Output):
  Output{file,+count,steps} = output
  +size = U32.from_nat(List.length(&2,U32,bytes))
  do IO<Output>:
    S.checked(U32.is_le(count,limit) && U32.is_le(size,U32.sub(limit,count)),"ATIF output supported envelope exceeded; destination not published")
    written : File & Result<&1,&1,U32 & String,Unit> <- File.write_bytes(file,bytes)
    next : File <- M.write_result(written)
    return Output{next,U32.add(count,size),steps}

def write(output: Output,text: String,limit: U32) -> IO(Output):
  write_bytes(output,D.encode(text),limit)

def advance(output: Output) -> Output:
  Output{file,bytes,steps} = output
  Output{file,bytes,U32.inc(steps)}

def write_step(pair: Spool.Match,origin: T.Origin,event: T.AtifEvent,output: Output,limits: T.Limits) -> IO(Output):
  Spool.Match{other,skip,status} = pair
  match skip:
    case True{}: IO.pure(Output,output)
    case False{}:
      Output{file,bytes,+steps} = output
      T.Limits{_,_,_,step,maxbytes} = limits
      do IO<Output>:
        +text : String <- require(String,F.step(origin,event,other,U32.inc(steps),status))
        S.checked(Nat.is_le(List.length(&2,U32,D.encode(text)),U32.to_nat(step)),"ATIF step supported envelope exceeded")
        next : Output <- write(Output{file,bytes,steps},Bool.pick(String,U32.is_eq(steps,0),"",",") ++ text,maxbytes)
        return advance(next)

def write_walk(fuel: Nat,+db: U32,+origin: T.Origin,+ordinal: U32,output: Output,+limits: T.Limits) -> IO(Output):
  match fuel:
    case 0n: IO.pure(Output,output)
    case 1n+rest:
      do IO<Output>:
        +event : T.AtifEvent <- Spool.read(db,ordinal)
        pair : Spool.Match <- Spool.pair(db,event)
        next : Output <- write_step(pair,origin,event,output,limits)
        write_walk(rest,db,origin,U32.inc(ordinal),next,limits)

def finish(output: Output,origin: T.Origin,accounting: Accounting,events: U32,limit: U32) -> IO(Output):
  Output{file,bytes,+steps} = output
  do IO<Output>:
    S.checked(U32.is_gt(steps,0),"ATIF cannot publish an empty steps array")
    write(Output{file,bytes,steps},F.closing(origin,report(accounting),events,steps),limit)

def close_output(output: Output) -> IO(U32 & U32):
  Output{file,bytes,steps} = output
  do IO<U32 & U32>:
    File.close(file)
    return (bytes,steps)

def output(+db: U32,+origin: T.Origin,path: String,scan: Scan,+limits: T.Limits) -> IO(U32 & U32):
  Scan{Stage{_,+events,_},accounting,_,_} = scan
  T.Limits{_,_,_,_,+maxbytes} = limits
  do IO<U32 & U32>:
    file : File <- IO.try(File,File.open(path,"w"))
    started : Output <- write(Output{file,0,0},F.opening(origin),maxbytes)
    steps : Output <- write_walk(U32.to_nat(events),db,origin,0,started,limits)
    finished : Output <- finish(steps,origin,accounting,events,maxbytes)
    close_output(finished)

# Never open an existing destination (which could be a FIFO). Metadata-only
# preflight is bounded; the exact link primitive remains the no-clobber authority.
def absent(result: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Bool:
  match result:
    case Done{(code,(out,err))}: U32.is_eq(code,1) && String.is_empty(out) && String.is_empty(err)
    case _: False{}

def destination(+db: U32,+path: String) -> IO(Unit):
  do IO<Unit>:
    S.checked(Bool.not(String.contains(path,"\0")),"ATIF destination must not contain NUL")
    existing : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",["-e",path],"",8192,2000)
    symlink : Result<&1,&1,U32 & String,U32 & (String & String)> <- Process.run("/bin/test",["-L",path],"",8192,2000)
    S.checked(absent(existing) && absent(symlink),"ATIF destination exists or cannot be inspected; choose a new file")
    rows : List<&2,List<&2,Sql.Cell>> <- S.q(db,"SELECT count(*) FROM main.sources WHERE locator=?",[Sql.Cell.Text{path}],1)
    S.checked(String.eq(S.field(S.first(rows),0n),"0"),"ATIF destination is a source locator; sources remain read-only")

def receipt(capture: U.Capture,path: String,scan: Scan,counts: U32 & U32) -> T.Receipt:
  U.Capture{_,_,_,_,snapshot,_,records} = capture
  Scan{Stage{_,events,_},_,_,_} = scan
  (bytes,steps) = counts
  T.Receipt{snapshot,path,records,events,steps,bytes}

def export_limits(+db: U32,+snapshot: String,path: String,+limits: T.Limits) -> IO(T.Receipt):
  do IO<T.Receipt>:
    S.checked(Archive.identity(snapshot) && limits_valid(limits),"ATIF requires a canonical exact snapshot ID and supported positive limits")
    +canonical : String <- Paths.destination(path)
    S.exec(db,"BEGIN DEFERRED",[])
    captured : Result<&2,&2,U.Failure,U.Capture> <- U.header(db,snapshot)
    +capture : U.Capture <- usage_required(U.Capture,captured)
    admitted(capture,limits)
    archive : Maybe<&2,Archive.Origin> <- Archive.read(db,snapshot,True{})
    +source : T.Origin = origin(archive,capture)
    destination(db,canonical)
    Spool.initialize(db)
    +scanned : Scan <- scan(db,capture,limits)
    +temporary : String <- M.temporary(canonical)
    counts : U32 & U32 <- output(db,source,temporary,scanned,limits)
    S.exec(db,"ROLLBACK",[])
    M.publish(temporary,canonical)
    return receipt(capture,canonical,scanned,counts)

def export(db: U32,snapshot: String,path: String) -> IO(T.Receipt):
  export_limits(db,snapshot,path,T.defaults())
