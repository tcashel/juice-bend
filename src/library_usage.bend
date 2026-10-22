import Base
import ./library_usage_types.bend as T
import ./library_usage_aggregate.bend as Aggregate
import ./session_usage.bend as S
import ./session_usage_claude.bend as Claude
import ./session_usage_codex.bend as Codex
import ./session_usage_counts.bend as Counts
import ./catalog.bend as Catalog
import ./domain.bend as D
import ./sql.bend as Sql
import ./store.bend as Store
import ./provenance.bend as Provenance

# All-time retained-library accounting only. The affine Run owns one read
# transaction. No source, account, repository, provider or network I/O occurs.
type Scan is Data:
  Scan{usage: S.State,hash: D.HashContext}

type State is Data:
  State{limits: T.Limits,complete: Bool,selected: U32,pending: List<&2,String>,
    rows: List<&2,T.CaptureRow>,records: U32,bytes: U32,active: Maybe<&2,Scan>}

type Run is Type:
  Run{db: U32,state: State}

type Step is Type:
  More{run: Run}
  Finished{report: T.Report}
  Failed{failure: S.Failure}

type CatalogPage is Data:
  CatalogPage{complete: Bool,ids: List<&2,String>}

def fail(code: String,message: String) -> S.Failure:
  S.Failure{code,message}

def per_capture() -> S.Limits:
  S.Limits{100000,16777216,100000,16777216}

def catalog_row(row: List<&2,Sql.Cell>) -> Result<&2,&2,S.Failure,String>:
  match row:
    case [Sql.Cell.Integer{+source},Sql.Cell.Integer{+latest},Sql.Cell.Integer{snapshot},
      Sql.Cell.Integer{owner},Sql.Cell.Integer{accepted}]:
      do Result<&2,&2,S.Failure,String>:
        S.check(Catalog.identity_valid(source) && Catalog.identity_valid(latest) &&
          String.eq(latest,snapshot) && String.eq(source,owner) && String.eq(accepted,"1"),
          "library_usage_catalog_integrity","Source latest pointer does not identify its accepted retained snapshot")
        return latest
    case _: Fail{fail("library_usage_catalog_integrity","Source latest pointer has an invalid SQLite shape")}

def prepend(id: String,page: CatalogPage) -> CatalogPage:
  CatalogPage{complete,ids} = page
  CatalogPage{complete,id <> ids}

def catalog_rows(rows: List<&2,List<&2,Sql.Cell>>,+left: U32) -> Result<&2,&2,S.Failure,CatalogPage>:
  match rows:
    case []: Done{CatalogPage{True{},[]}}
    case row <> rest:
      do Result<&2,&2,S.Failure,CatalogPage>:
        id : String <- catalog_row(row)
        +page : CatalogPage <- Bool.pick(Result<&2,&2,S.Failure,CatalogPage>,U32.is_eq(left,0),
          Done{CatalogPage{False{},[]}},catalog_rows(rest,U32.sub(left,1)))
        return Bool.pick(CatalogPage,U32.is_eq(left,0),page,prepend(id,page))

def catalog_result(result: Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>>,limit: U32) -> Result<&2,&2,S.Failure,CatalogPage>:
  do Result<&2,&2,S.Failure,CatalogPage>:
    rows : List<&2,List<&2,Sql.Cell>> <- result
    catalog_rows(rows,limit)

def catalog(+db: U32,+limit: U32) -> IO(Result<&2,&2,S.Failure,CatalogPage>):
  do IO<Result<&2,&2,S.Failure,CatalogPage>>:
    rows : Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>> <- S.query(db,
      "SELECT s.id,s.latest,p.id,g.source,p.accepted FROM main.sources s LEFT JOIN main.snapshots p ON p.id=s.latest LEFT JOIN main.generations g ON g.id=p.generation WHERE s.latest IS NOT NULL OR EXISTS(SELECT 1 FROM main.generations x JOIN main.snapshots y ON y.generation=x.id WHERE x.source=s.id AND y.accepted=1) ORDER BY s.id LIMIT ?",
      [Sql.Cell.Integer{U32.show(U32.inc(limit))}],U32.inc(limit))
    return catalog_result(rows,limit)

def opened(result: Result<&2,&2,S.Failure,CatalogPage>,+db: U32,limits: T.Limits) -> IO(Result<&2,&1,S.Failure,Run>):
  match result:
    case Done{CatalogPage{complete,+ids}}:
      IO.pure(Result<&2,&1,S.Failure,Run>,Done{Run{db,State{limits,complete,U32.from_nat(List.length(&2,String,ids)),ids,[],0,0,None{}}}})
    case Fail{failure}:
      do IO<Result<&2,&1,S.Failure,Run>>:
        closed : Result<&2,&2,S.Failure,Unit> <- S.cleanup(db)
        return Fail{S.failed_cleanup(closed,failure)}

def begun(result: Result<&2,&2,S.Failure,Unit>,+db: U32,+limits: T.Limits) -> IO(Result<&2,&1,S.Failure,Run>):
  match result:
    case Fail{failure}: IO.pure(Result<&2,&1,S.Failure,Run>,Fail{failure})
    case Done{_}:
      T.Limits{sources,_,_} = limits
      do IO<Result<&2,&1,S.Failure,Run>>:
        page : Result<&2,&2,S.Failure,CatalogPage> <- catalog(db,sources)
        opened(page,db,limits)

def begin_valid(valid: Bool,+db: U32,limits: T.Limits) -> IO(Result<&2,&1,S.Failure,Run>):
  match valid:
    case False{}: IO.pure(Result<&2,&1,S.Failure,Run>,Fail{fail("library_usage_invalid_limits","Unsupported bounded library Usage limits")})
    case True{}:
      do IO<Result<&2,&1,S.Failure,Run>>:
        owned : Result<&2,&2,S.Failure,Unit> <- S.start(db)
        begun(owned,db,limits)

def begin(db: U32,+limits: T.Limits) -> IO(Result<&2,&1,S.Failure,Run>):
  begin_valid(T.valid(limits),db,limits)

def cancel(run: Run) -> IO(Result<&2,&2,S.Failure,Unit>):
  Run{db,_} = run
  S.cleanup(db)

def done_cleanup(result: Result<&2,&2,S.Failure,Unit>,report: T.Report) -> Step:
  match result:
    case Done{_}: Finished{report}
    case Fail{failure}: Failed{failure}

def finish(+db: U32,state: State) -> IO(Step):
  State{limits,+complete,selected,_,rows,records,bytes,_} = state
  +rows = List.reverse(&2,T.CaptureRow,rows)
  do IO<Step>:
    closed : Result<&2,&2,S.Failure,Unit> <- S.cleanup(db)
    return done_cleanup(closed,T.Report{complete,selected,records,bytes,limits,rows,Aggregate.summarize(rows,complete)})

def abort(+db: U32,failure: S.Failure) -> IO(Step):
  do IO<Step>:
    closed : Result<&2,&2,S.Failure,Unit> <- S.cleanup(db)
    return Failed{S.failed_cleanup(closed,failure)}

def available(capture: S.Capture,limits: T.Limits,records: U32,bytes: U32) -> Bool:
  S.Capture{_,_,_,_,_,+extent,+count} = capture
  T.Limits{_,maxrecords,maxbytes} = limits
  U32.is_le(count,100000) && U32.is_le(extent,16777216) &&
    U32.is_le(count,U32.sub(maxrecords,records)) && U32.is_le(extent,U32.sub(maxbytes,bytes))

def limited(db: U32,state: State,capture: S.Capture,reason: String) -> Step:
  State{limits,complete,selected,pending,rows,records,bytes,_} = state
  More{Run{db,State{limits,complete,selected,pending,
    T.CaptureRow{capture,"","","unknown",Counts.empty(),"limited",reason,None{}} <> rows,records,bytes,None{}}}}

def admission_rows(rows: List<&2,List<&2,Sql.Cell>>,records: U32) -> Result<&2,&2,S.Failure,Bool>:
  match rows:
    case [[Sql.Cell.Integer{count},Sql.Cell.Integer{+largest},Sql.Cell.Integer{bad}]]:
      do Result<&2,&2,S.Failure,Bool>:
        S.check(String.eq(count,U32.show(records)) && String.eq(bad,"0") &&
          Catalog.quantity_valid(largest),"library_usage_raw_integrity","Raw allocation preflight found invalid retained cell types or map links")
        return Bool.not(Cmp.is_gt(Provenance.decimal_compare(largest,"1048576")))
    case _: Fail{fail("library_usage_raw_integrity","Raw allocation preflight has an invalid result shape")}

def admission(db: U32,snapshot: String,records: U32) -> IO(Result<&2,&2,S.Failure,Bool>):
  do IO<Result<&2,&2,S.Failure,Bool>>:
    rows : Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>> <- S.query(db,
      "SELECT count(*),coalesce(max(length(CAST(r.bytes AS BLOB))),0),coalesce(sum(CASE WHEN typeof(r.bytes)!='blob' OR typeof(r.digest)!='text' OR length(CAST(r.digest AS BLOB))!=64 OR typeof(r.n)!='integer' OR r.n!=length(CAST(r.bytes AS BLOB)) THEN 1 ELSE 0 END),0) FROM main.records i LEFT JOIN main.raw r ON r.id=i.raw WHERE i.snapshot=?",[Sql.Cell.Integer{snapshot}],1)
    return do Result<&2,&2,S.Failure,Bool>:
      values : List<&2,List<&2,Sql.Cell>> <- rows
      admission_rows(values,records)

def admitted(result: Result<&2,&2,S.Failure,Bool>,db: U32,state: State,capture: S.Capture) -> IO(Step):
  match result:
    case Fail{failure}: abort(db,failure)
    case Done{False{}}: IO.pure(Step,limited(db,state,capture,"Retained raw BLOB exceeds the 1 MiB allocation bound; no payload read"))
    case Done{True{}}:
      State{limits,complete,selected,pending,rows,records,bytes,_} = state
      IO.pure(Step,More{Run{db,State{limits,complete,selected,pending,rows,records,bytes,
        Some{Scan{S.initial(capture,per_capture()),D.HashContext{D.hash_initial(),[],0,0}}}}}})

def admitted_budget(valid: Bool,+db: U32,state: State,+capture: S.Capture) -> IO(Step):
  match valid:
    case False{}: IO.pure(Step,limited(db,state,capture,"Capture or remaining library logical-byte/record budget exceeded"))
    case True{}:
      S.Capture{_,_,_,_,snapshot,_,records} = capture
      do IO<Step>:
        result : Result<&2,&2,S.Failure,Bool> <- admission(db,snapshot,records)
        admitted(result,db,state,capture)

def header_ready(result: Result<&2,&2,S.Failure,S.Capture>,db: U32,+state: State) -> IO(Step):
  match result:
    case Fail{failure}: abort(db,failure)
    case Done{+capture}:
      State{limits,_,_,_,_,records,bytes,_} = state
      admitted_budget(available(capture,limits,records,bytes),db,state,capture)

def next_capture(pending: List<&2,String>,+db: U32,state: State) -> IO(Step):
  match pending:
    case []: finish(db,state)
    case snapshot <> rest:
      State{limits,complete,selected,_,rows,records,bytes,_} = state
      do IO<Step>:
        result : Result<&2,&2,S.Failure,S.Capture> <- S.header(db,snapshot)
        header_ready(result,db,State{limits,complete,selected,rest,rows,records,bytes,None{}})

def own_call(value: Maybe<&2,Claude.Call>) -> Bool:
  match value:
    case Some{Claude.Call{_,_,_,_,group,conflict}}: U32.is_eq(group,0) && Bool.not(conflict)
    case None{}: False{}

# The bounded existing reducer map is the raw-backed witness. Empty counter
# strings do not erase a valid recorded call's identity. Later origin conflicts
# already move that call out of own group in the authoritative reducer.
def own_calls(calls: Map<&2,Maybe<&2,Claude.Call>>) -> Bool:
  match calls:
    case MTip{}: False{}
    case MLeaf{_,value}: own_call(value)
    case MNode{_,lo,hi}: own_calls(lo) || own_calls(hi)

def own_presence(account: S.Account) -> Bool:
  match account:
    case S.ClaudeAccount{Claude.State{calls,_,_,_,_,_,_,_,_,_,_,_,_}}: own_calls(calls)
    case S.CodexAccount{_}: False{}

def classified(+report: S.Report,sha256: String,own_present: Bool) -> T.CaptureRow:
  S.Report{capture,_,_,_,+scanned,+buckets,+attribution,reason,_,summary} = report
  match summary:
    case S.ClaudeSummary{Claude.Report{+own,_,_,_,+counts,_,_,_,_,_,_,_,_,_}}:
      +identity = Bool.not(String.is_empty(own)) && own_present
      T.CaptureRow{capture,Bool.pick(String,identity,own,""),sha256,"ordinary",counts,
        Bool.pick(String,Bool.not(identity),"identity_unknown",Bool.pick(String,scanned && buckets && attribution,"eligible","incomplete")),
        Bool.pick(String,Bool.not(identity),"No raw-backed own-session usage attribution; path alone cannot identify a contribution",
          Bool.pick(String,scanned && buckets && attribution,"Own-session recorded counts; copied and unattributed calls excluded",reason)),Some{report}}
    case S.CodexSummary{Codex.Report{+category,+session,_,_,counts,_,_,_,_,_,_,_,_,_}}:
      T.CaptureRow{capture,session,sha256,category,counts,
        Bool.pick(String,String.is_empty(session),"identity_unknown",Bool.pick(String,String.eq(category,"reviewer"),"reviewer",
          Bool.pick(String,scanned && buckets && attribution,"eligible","incomplete"))),reason,Some{report}}

def capture_finished(db: U32,state: State,scan: Scan,+complete: Bool,reason: String) -> Step:
  State{limits,all,selected,pending,rows,records,bytes,_} = state
  Scan{+usage,hash} = scan
  S.State{_,_,S.Cursor{count,extent,_},account,_} = usage
  More{Run{db,State{limits,all,selected,pending,
    classified(S.report(usage,complete,reason),Bool.pick(String,complete,D.hash_finish(hash),""),own_presence(account)) <> rows,
    U32.add(records,count),U32.add(bytes,extent),None{}}}}

def advanced_scan(result: S.Batch,hash: D.HashContext) -> Scan:
  match result:
    case S.Advanced{usage}: Scan{usage,hash}
    case S.Stopped{usage,_}: Scan{usage,hash}

type RawWindow is Data:
  RawWindow{scan: Scan,stopped: Bool,reason: String}

def window_next(result: Result<&2,&2,S.Failure,S.Batch>,row: List<&2,Sql.Cell>,hash: D.HashContext,
  next: Scan -> Result<&2,&2,S.Failure,RawWindow>) -> Result<&2,&2,S.Failure,RawWindow>:
  match result:
    case Fail{failure}: Fail{failure}
    case Done{S.Stopped{usage,reason}}: Done{RawWindow{Scan{usage,hash},True{},reason}}
    case Done{S.Advanced{usage}}: next(Scan{usage,D.hash_bytes(Store.blob(Store.cell(row,5n)),hash)})

def window(rows: List<&2,List<&2,Sql.Cell>>,scan: Scan) -> Result<&2,&2,S.Failure,RawWindow>:
  match rows:
    case []: Done{RawWindow{scan,False{},""}}
    case +row <> rest:
      Scan{usage,hash} = scan
      window_next(S.batch([row],usage),row,hash,next => window(rest,next))

def processed(result: Result<&2,&2,S.Failure,RawWindow>,db: U32,state: State) -> IO(Step):
  match result:
    case Fail{failure}: abort(db,failure)
    case Done{RawWindow{scan,True{},reason}}: IO.pure(Step,capture_finished(db,state,scan,False{},reason))
    case Done{RawWindow{scan,False{},_}}:
      State{limits,complete,selected,pending,rows,records,bytes,_} = state
      IO.pure(Step,More{Run{db,State{limits,complete,selected,pending,rows,records,bytes,Some{scan}}}})

def loaded(result: Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>>,db: U32,state: State,scan: Scan) -> IO(Step):
  match result:
    case Fail{failure}: abort(db,failure)
    case Done{[]}: abort(db,fail("library_usage_raw_integrity","Selected retained raw window is missing"))
    case Done{rows}: processed(window(rows,scan),db,state)

def scan_position(eof: Bool,covered: Bool,+db: U32,state: State,scan: Scan,snapshot: String,ordinal: U32,records: U32) -> IO(Step):
  match eof covered:
    case True{} True{}: IO.pure(Step,capture_finished(db,state,scan,True{},"Complete pinned retained extent scanned"))
    case True{} False{}: abort(db,fail("library_usage_raw_integrity","Final retained logical byte extent is inconsistent"))
    case False{} _:
      do IO<Step>:
        rows : Result<&2,&2,S.Failure,List<&2,List<&2,Sql.Cell>>> <- S.raw_window(db,snapshot,ordinal,records)
        loaded(rows,db,state,scan)

def active(scan: Scan,db: U32,state: State) -> IO(Step):
  Scan{+usage,hash} = scan
  S.State{S.Capture{_,_,_,_,snapshot,+extent,+records},_,S.Cursor{+ordinal,offset,_},_,_} = usage
  scan_position(U32.is_eq(ordinal,records),U32.is_eq(offset,extent),db,state,Scan{usage,hash},snapshot,ordinal,records)

def selected(value: Maybe<&2,Scan>,db: U32,+state: State) -> IO(Step):
  match value:
    case Some{scan}: active(scan,db,state)
    case None{}:
      State{_,_,_,pending,_,_,_,_} = state
      next_capture(pending,db,state)

def step(run: Run) -> IO(Step):
  Run{db,+state} = run
  State{_,_,_,_,_,_,_,scan} = state
  selected(scan,db,state)
