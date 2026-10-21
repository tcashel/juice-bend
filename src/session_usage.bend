import Base
import ./sql.bend as Sql
import ./store.bend as Store
import ./catalog.bend as Catalog
import ./json.bend as Json
import ./domain.bend as Domain
import ./session_usage_counts.bend as Counts
import ./session_usage_claude.bend as Claude
import ./session_usage_codex.bend as Codex

# Unintegrated whole-capture accounting. A successful begin transfers exclusive
# use of the supplied connection until step finishes or cancel returns. Run is
# affine; callers must not issue unrelated statements through a copied token.
# Only successful BEGIN establishes transaction ownership. Every ordinary
# failure, limit, completion and cancellation rolls back that owned read view.
type Failure is Data:
  Failure{code: String,message: String}

type Capture is Data:
  Capture{provider: String,source_id: String,locator: String,generation: String,
    snapshot: String,extent: U32,records: U32}

type Limits is Data:
  Limits{records: U32,bytes: U32,keys: U32,descriptor_bytes: U32}

type Cursor is Data:
  Cursor{ordinal: U32,offset: U32,continued: Bool}

type Witness is Data:
  Witness{record: U32,reason: String}

type Coverage is Data:
  Coverage{decoded: U32,malformed: U32,oversized: U32,issues: U32,witnesses: List<&2,Witness>}

type Account is Data:
  ClaudeAccount{state: Claude.State}
  CodexAccount{state: Codex.State}

type State is Data:
  State{capture: Capture,limits: Limits,cursor: Cursor,account: Account,coverage: Coverage}

type Run is Type:
  Run{db: U32,state: State}

type Summary is Data:
  ClaudeSummary{value: Claude.Report}
  CodexSummary{value: Codex.Report}

type Progress is Data:
  Progress{snapshot: String,processed_records: U32,total_records: U32,verified_bytes: U32,total_bytes: U32}

type Report is Data:
  Report{capture: Capture,limits: Limits,processed_records: U32,verified_bytes: U32,
    scan_complete: Bool,bucket_complete: Bool,attribution_complete: Bool,
    stop_reason: String,coverage: Coverage,summary: Summary}

type Step is Type:
  More{run: Run,progress: Progress}
  Finished{report: Report}
  Failed{failure: Failure}

type Batch is Data:
  Advanced{state: State}
  Stopped{state: State,reason: String}

def defaults() -> Limits:
  Limits{1000000,1073741824,100000,16777216}

def limits_valid(limits: Limits) -> Bool:
  Limits{+records,+bytes,+keys,+descriptors} = limits
  U32.is_gt(records,0) && U32.is_le(records,1000000) && U32.is_gt(bytes,0) && U32.is_le(bytes,1073741824) &&
    U32.is_gt(keys,0) && U32.is_le(keys,100000) && U32.is_gt(descriptors,0) && U32.is_le(descriptors,67108864)

def fail(code: String,message: String) -> Failure:
  Failure{code,message}

def check(valid: Bool,code: String,message: String) -> Result<&2,&2,Failure,Unit>:
  Bool.pick(Result<&2,&2,Failure,Unit>,valid,Done{Unit{}},Fail{fail(code,message)})

def sql_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>>:
  match result:
    case Done{rows}: Done{rows}
    case Fail{(code,_)}: Fail{fail("usage_database_error","Recorded usage query failed (SQLite " ++ U32.show(code) ++ ")")}

def query(db: U32,sql: String,bindings: List<&2,Sql.Cell>,limit: U32) -> IO(Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>>):
  do IO<Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,sql,bindings,limit)
    return sql_result(result)

def start_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> Result<&2,&2,Failure,Unit>:
  match result:
    case Done{_}: Done{Unit{}}
    case Fail{(code,_)}: Fail{fail("usage_transaction_unavailable","Cannot own a read transaction (SQLite " ++ U32.show(code) ++
      "); any existing caller transaction remains untouched")}

def start(db: U32) -> IO(Result<&2,&2,Failure,Unit>):
  do IO<Result<&2,&2,Failure,Unit>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"BEGIN DEFERRED",[],0)
    return start_result(result)

def cleanup_result(result: Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>>) -> Result<&2,&2,Failure,Unit>:
  match result:
    case Done{_}: Done{Unit{}}
    case Fail{(code,_)}: Fail{fail("usage_cleanup_error","Owned read rollback failed (SQLite " ++ U32.show(code) ++
      "); connection transaction state must be resolved before reuse")}

def cleanup(db: U32) -> IO(Result<&2,&2,Failure,Unit>):
  do IO<Result<&2,&2,Failure,Unit>>:
    result : Result<&1,&1,U32 & String,List<&2,List<&2,Sql.Cell>>> <- Sql.query(db,"ROLLBACK",[],0)
    return cleanup_result(result)

def provider_valid(provider: String) -> Bool:
  match provider:
    case "claude": True{}
    case "codex": True{}
    case _: False{}

def header_row(rows: List<&2,List<&2,Sql.Cell>>,expected: String) -> Result<&2,&2,Failure,Capture>:
  match rows:
    case [[Sql.Cell.Integer{+snapshot},Sql.Cell.Integer{+generation},Sql.Cell.Integer{+extent},Sql.Cell.Integer{+records},
      Sql.Cell.Integer{accepted},Sql.Cell.Integer{generation_id},Sql.Cell.Integer{+source},Sql.Cell.Integer{source_id},
      Sql.Cell.Text{+provider},Sql.Cell.Text{+locator},Sql.Cell.Integer{actual},Sql.Cell.Integer{bad}]]:
      do Result<&2,&2,Failure,Capture>:
        check(Catalog.identity_valid(snapshot) && Catalog.identity_valid(generation) && Catalog.identity_valid(source) &&
          String.eq(snapshot,expected) && String.eq(generation,generation_id) && String.eq(source,source_id) &&
          String.eq(accepted,"1"),"usage_header_integrity","Pinned accepted capture identity is corrupt")
        check(Catalog.quantity_valid(extent) && Catalog.quantity_valid(records) && String.eq(records,actual) &&
          String.eq(bad,"0"),"usage_map_integrity","Capture map count, key type, or complete ordinal range is corrupt")
        check(provider_valid(provider) && String.starts_with(locator,"/") && Bool.not(String.contains(locator,"\0")) &&
          Claude.fits_result(Claude.remaining(locator,8192)),"usage_header_integrity","Provider or retained source locator is unsupported")
        return Capture{provider,source,locator,generation,snapshot,Store.number(extent),Store.number(records)}
    case []: Fail{fail("usage_not_found","Pinned accepted capture does not exist")}
    case _: Fail{fail("usage_header_integrity","Capture metadata has missing or invalid SQLite cell types")}

def header(+db: U32,+snapshot: String) -> IO(Result<&2,&2,Failure,Capture>):
  # These global count/type guards inspect the whole map under the bridge's
  # statement deadline. The128-row bound applies to raw payload windows below,
  # not to the work needed to establish absence of hidden corrupt map keys.
  do IO<Result<&2,&2,Failure,Capture>>:
    rows : Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>> <- query(db,
      "SELECT p.id,p.generation,p.extent,p.records,p.accepted,g.id,g.source,s.id,s.provider,s.locator,(SELECT count(*) FROM main.records i WHERE i.snapshot=p.id),(SELECT count(*) FROM main.records i WHERE i.snapshot=p.id AND (typeof(i.ordinal)!='integer' OR i.ordinal<0 OR i.ordinal>=p.records OR typeof(i.raw)!='integer' OR i.raw<=0)) FROM main.snapshots p LEFT JOIN main.generations g ON g.id=p.generation LEFT JOIN main.sources s ON s.id=g.source WHERE p.id=?",[Sql.Cell.Integer{snapshot}],1)
    return do Result<&2,&2,Failure,Capture>:
      values : List<&2,List<&2,Sql.Cell>> <- rows
      header_row(values,snapshot)

# This is only an explicit lexical association retained with the capture. It
# is not proof of who authored a call, and no original path is opened.
def session_parts(parts: List<&2,String>) -> String:
  match parts:
    case +leaf <> "subagents" <> +session <> _:
      Bool.pick(String,String.ends_with(leaf,".jsonl") && String.starts_with(leaf,"agent-") && Claude.identifier(session),session,"")
    case +leaf <> _:
      +stem = String.take(leaf,Nat.sub(String.length(leaf),6n))
      Bool.pick(String,String.ends_with(leaf,".jsonl") && Claude.identifier(stem),stem,"")
    case _: ""

def own_session(locator: String) -> String:
  session_parts(List.reverse(&2,String,String.split(locator,'/')))

def account(provider: String,locator: String) -> Account:
  match provider:
    case "claude": ClaudeAccount{Claude.new(own_session(locator))}
    case _: CodexAccount{Codex.new()}

def initial(+capture: Capture,limits: Limits) -> State:
  Capture{provider,_,locator,_,_,_,_} = capture
  State{capture,limits,Cursor{0,0,False{}},account(provider,locator),Coverage{0,0,0,0,[]}}

def failed_cleanup(result: Result<&2,&2,Failure,Unit>,prior: Failure) -> Failure:
  match result:
    case Done{_}: prior
    case Fail{failure}: failure

def begin_header(result: Result<&2,&2,Failure,Capture>,+db: U32,limits: Limits) -> IO(Result<&2,&1,Failure,Run>):
  match result:
    case Done{capture}: IO.pure(Result<&2,&1,Failure,Run>,Done{Run{db,initial(capture,limits)}})
    case Fail{failure}:
      do IO<Result<&2,&1,Failure,Run>>:
        closed : Result<&2,&2,Failure,Unit> <- cleanup(db)
        return Fail{failed_cleanup(closed,failure)}

def begun(result: Result<&2,&2,Failure,Unit>,+db: U32,snapshot: String,limits: Limits) -> IO(Result<&2,&1,Failure,Run>):
  match result:
    case Fail{failure}: IO.pure(Result<&2,&1,Failure,Run>,Fail{failure})
    case Done{_}:
      do IO<Result<&2,&1,Failure,Run>>:
        capture : Result<&2,&2,Failure,Capture> <- header(db,snapshot)
        begin_header(capture,db,limits)

def begin_valid(valid: Bool,+db: U32,snapshot: String,limits: Limits) -> IO(Result<&2,&1,Failure,Run>):
  match valid:
    case False{}: IO.pure(Result<&2,&1,Failure,Run>,Fail{fail("usage_invalid_request","Requires a canonical positive snapshot ID and supported nonzero limits")})
    case True{}:
      do IO<Result<&2,&1,Failure,Run>>:
        owned : Result<&2,&2,Failure,Unit> <- start(db)
        begun(owned,db,snapshot,limits)

def begin(db: U32,+snapshot: String,+limits: Limits) -> IO(Result<&2,&1,Failure,Run>):
  begin_valid(Catalog.identity_valid(snapshot) && limits_valid(limits),db,snapshot,limits)

def cancel(run: Run) -> IO(Result<&2,&2,Failure,Unit>):
  Run{db,_} = run
  cleanup(db)

def summary(account: Account) -> Summary:
  match account:
    case ClaudeAccount{state}: ClaudeSummary{Claude.report(state)}
    case CodexAccount{state}: CodexSummary{Codex.report(state)}

def summary_bucket(value: Summary) -> Bool:
  match value:
    case ClaudeSummary{Claude.Report{_,_,_,_,_,_,_,_,_,_,_,_,complete,_}}: complete
    case CodexSummary{Codex.Report{_,_,_,_,_,_,_,_,_,_,_,_,_,complete}}: complete

def summary_attribution(value: Summary) -> Bool:
  match value:
    case ClaudeSummary{Claude.Report{_,_,_,_,_,_,_,_,_,_,_,_,_,complete}}: complete
    case CodexSummary{Codex.Report{_,_,_,_,_,_,_,_,_,_,_,_,_,complete}}: complete

def coverage_complete(value: Coverage) -> Bool:
  Coverage{_,malformed,oversized,issues,_} = value
  U32.is_eq(malformed,0) && U32.is_eq(oversized,0) && U32.is_eq(issues,0)

def reported(capture: Capture,limits: Limits,ordinal: U32,offset: U32,+complete: Bool,reason: String,
  +quality: Coverage,+summary: Summary) -> Report:
  +covered = complete && coverage_complete(quality)
  Report{capture,limits,ordinal,offset,complete,covered && summary_bucket(summary),covered && summary_attribution(summary),
    reason,quality,summary}

def report(state: State,complete: Bool,reason: String) -> Report:
  State{capture,limits,Cursor{ordinal,offset,_},account,quality} = state
  reported(capture,limits,ordinal,offset,complete,reason,quality,summary(account))

def finished_cleanup(result: Result<&2,&2,Failure,Unit>,report: Report) -> Step:
  match result:
    case Done{_}: Finished{report}
    case Fail{failure}: Failed{failure}

def finish(+db: U32,state: State,complete: Bool,reason: String) -> IO(Step):
  do IO<Step>:
    closed : Result<&2,&2,Failure,Unit> <- cleanup(db)
    return finished_cleanup(closed,report(state,complete,reason))

def abort(+db: U32,failure: Failure) -> IO(Step):
  do IO<Step>:
    closed : Result<&2,&2,Failure,Unit> <- cleanup(db)
    return Failed{failed_cleanup(closed,failure)}

def raw_typed(row: List<&2,Sql.Cell>) -> Bool:
  match row:
    case [Sql.Cell.Integer{generation},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{offset},Sql.Cell.Integer{length},
      Sql.Cell.Text{_},Sql.Cell.Blob{_},Sql.Cell.Integer{+oversized},Sql.Cell.Integer{+complete},Sql.Cell.Integer{map_ordinal}]:
      Catalog.identity_valid(generation) && Catalog.quantity_valid(ordinal) && Catalog.quantity_valid(offset) &&
        Catalog.quantity_valid(length) && Catalog.quantity_valid(map_ordinal) &&
        (String.eq(oversized,"0") || String.eq(oversized,"1")) && (String.eq(complete,"0") || String.eq(complete,"1"))
    case _: False{}

def raw_valid(+row: List<&2,Sql.Cell>,capture: Capture,cursor: Cursor) -> Bool:
  Capture{_,_,_,generation,_,extent,records} = capture
  Cursor{ordinal,offset,continued} = cursor
  raw_typed(row) && Store.record_valid(row,generation,extent,records,ordinal,offset,continued)

def witness(+ordinal: U32,+reason: String,+items: List<&2,Witness>) -> List<&2,Witness>:
  Bool.pick(List<&2,Witness>,String.is_empty(reason) || Nat.is_ge(List.length(&2,Witness,items),16n),
    items,Witness{ordinal,reason} <> items)

def coverage(value: Coverage,ordinal: U32,+reason: String,+malformed: Bool,+oversized: Bool) -> Coverage:
  Coverage{decoded,bad,large,issues,items} = value
  Coverage{U32.add(decoded,Bool.to_u32(Bool.not(malformed || oversized))),U32.add(bad,Bool.to_u32(malformed)),
    U32.add(large,Bool.to_u32(oversized)),U32.add(issues,Bool.to_u32(Bool.not(String.is_empty(reason)))),witness(ordinal,reason,items)}

def note_usage(usage: Bool,quality: Coverage,ordinal: U32) -> Coverage:
  Coverage{a,b,c,d,+items} = quality
  Coverage{a,b,c,d,Bool.pick(List<&2,Witness>,usage,witness(ordinal,"recorded usage observation",items),items)}

def object(value: Json.Json) -> Bool:
  match value:
    case Json.JObject{_}: True{}
    case _: False{}

def usage_record(+value: Json.Json) -> Bool:
  +kind = Claude.text(Json.field(value,"type"))
  (String.eq(kind,"assistant") && object(Json.field(Json.field(value,"message"),"usage"))) ||
    (String.eq(kind,"event_msg") && String.eq(Claude.text(Json.field(Json.field(value,"payload"),"type")),"token_count"))

def invalid_account(account: Account,ordinal: U32) -> Account:
  match account:
    case ClaudeAccount{state}: ClaudeAccount{state}
    case CodexAccount{state}: CodexAccount{Codex.invalid(state,ordinal)}

def bad_record(state: State,+ordinal: U32,reason: String,+oversized: Bool) -> Batch:
  State{capture,limits,cursor,account,quality} = state
  Advanced{State{capture,limits,cursor,invalid_account(account,ordinal),coverage(quality,ordinal,reason,Bool.not(oversized),oversized)}}

def claude_updated(result: Claude.Update,capture: Capture,limits: Limits,cursor: Cursor,quality: Coverage,ordinal: U32) -> Batch:
  match result:
    case Claude.Limited{state,reason}: Stopped{State{capture,limits,cursor,ClaudeAccount{state},quality},reason}
    case Claude.Accepted{state,reason}: Advanced{State{capture,limits,cursor,ClaudeAccount{state},coverage(quality,ordinal,reason,False{},False{})}}

def decoded_account(account: Account,value: Json.Json,capture: Capture,limits: Limits,cursor: Cursor,
  quality: Coverage,+ordinal: U32,keys: U32,bytes: U32) -> Batch:
  match account:
    case ClaudeAccount{state}: claude_updated(Claude.observe(value,state,keys,bytes),capture,limits,cursor,quality,ordinal)
    case CodexAccount{state}:
      Advanced{State{capture,limits,cursor,CodexAccount{Codex.observe(state,ordinal,value)},coverage(quality,ordinal,"",False{},False{})}}

def decoded_value(+value: Json.Json,state: State,+ordinal: U32) -> Batch:
  State{capture,+limits,cursor,account,prior} = state
  Limits{_,_,keys,bytes} = limits
  decoded_account(account,value,capture,limits,cursor,note_usage(usage_record(value),prior,ordinal),ordinal,keys,bytes)

def decoded_json(result: Result<&2,&2,String,Json.Json>,state: State,ordinal: U32) -> Batch:
  match result:
    case Fail{_}: bad_record(state,ordinal,"malformed JSON record",False{})
    case Done{value}: decoded_value(value,state,ordinal)

def decoded_text(result: Result<&2,&2,String,String>,state: State,ordinal: U32) -> Batch:
  match result:
    case Fail{_}: bad_record(state,ordinal,"invalid UTF8 record",False{})
    case Done{text}: decoded_json(Json.parse(text),state,ordinal)

def decode(oversized: Bool,row: List<&2,Sql.Cell>,state: State,ordinal: U32) -> Batch:
  match oversized:
    case True{}: bad_record(state,ordinal,"oversized logical record fragment",True{})
    case False{}: decoded_text(Domain.decode(Store.blob(Store.cell(row,5n))),state,ordinal)

def advanced(result: Batch,+next: Cursor) -> Batch:
  match result:
    case Stopped{state,reason}: Stopped{state,reason}
    case Advanced{State{capture,limits,_,account,quality}}: Advanced{State{capture,limits,next,account,quality}}

def consume_row(+row: List<&2,Sql.Cell>,state: State) -> Batch:
  State{capture,limits,Cursor{+ordinal,+offset,continued},account,quality} = state
  +length = Store.number(Store.field(row,3n))
  advanced(decode(String.eq(Store.field(row,6n),"1"),row,
    State{capture,limits,Cursor{ordinal,offset,continued},account,quality},ordinal),
    Cursor{U32.inc(ordinal),U32.add(offset,length),Bool.not(Store.row_newline(row))})

def batch_next(result: Batch,next: State -> Result<&2,&2,Failure,Batch>) -> Result<&2,&2,Failure,Batch>:
  match result:
    case Stopped{state,reason}: Done{Stopped{state,reason}}
    case Advanced{state}: next(state)

def row_allowed(valid: Bool,budget: Bool,+row: List<&2,Sql.Cell>,state: State,
  next: State -> Result<&2,&2,Failure,Batch>) -> Result<&2,&2,Failure,Batch>:
  match valid budget:
    case False{} _: Fail{fail("usage_raw_integrity","Retained raw type, checksum, identity, position or coverage is corrupt")}
    case True{} False{}: Done{Stopped{state,"Verified raw byte or physical record limit reached"}}
    case True{} True{}: batch_next(consume_row(row,state),next)

def batch(rows: List<&2,List<&2,Sql.Cell>>,state: State) -> Result<&2,&2,Failure,Batch>:
  match rows:
    case []: Done{Advanced{state}}
    case +row <> rest:
      State{+capture,+limits,+cursor,account,quality} = state
      Limits{maxrecords,maxbytes,_,_} = limits
      Cursor{ordinal,+offset,_} = cursor
      row_allowed(raw_valid(row,capture,cursor),U32.is_lt(ordinal,maxrecords) && U32.is_le(offset,maxbytes) &&
        U32.is_le(Store.number(Store.field(row,3n)),U32.sub(maxbytes,offset)),row,
        State{capture,limits,cursor,account,quality},next => batch(rest,next))

def raw_window(db: U32,snapshot: String,ordinal: U32,count: U32) -> IO(Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>>):
  query(db,
    "SELECT generation,raw_ordinal,offset,n,digest,bytes,oversized,complete,map_ordinal FROM (SELECT r.generation,r.ordinal AS raw_ordinal,r.offset,r.n,r.digest,r.bytes,r.oversized,r.complete,i.ordinal AS map_ordinal,row_number() OVER (ORDER BY i.ordinal) AS rn,sum(coalesce(length(CAST(r.bytes AS BLOB)),0)+coalesce(length(CAST(r.digest AS BLOB)),0)+256) OVER (ORDER BY i.ordinal) AS total_bytes FROM (SELECT ordinal,raw FROM main.records WHERE snapshot=? AND ordinal>=? AND ordinal<? ORDER BY ordinal LIMIT 128) i LEFT JOIN main.raw r ON r.id=i.raw) WHERE total_bytes<=1048576 OR rn=1 ORDER BY map_ordinal",
    [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(count)}],128)

def progressed(+db: U32,state: State) -> Step:
  State{+capture,limits,+cursor,account,quality} = state
  Capture{_,_,_,_,snapshot,extent,records} = capture
  Cursor{ordinal,offset,_} = cursor
  More{Run{db,State{capture,limits,cursor,account,quality}},Progress{snapshot,ordinal,records,offset,extent}}

def processed(result: Result<&2,&2,Failure,Batch>,db: U32) -> IO(Step):
  match result:
    case Fail{failure}: abort(db,failure)
    case Done{Stopped{state,reason}}: finish(db,state,False{},reason)
    case Done{Advanced{state}}: IO.pure(Step,progressed(db,state))

def loaded(result: Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>>,db: U32,state: State) -> IO(Step):
  match result:
    case Fail{failure}: abort(db,failure)
    case Done{[]}: abort(db,fail("usage_map_integrity","Expected retained raw window is missing"))
    case Done{rows}: processed(batch(rows,state),db)

def step_position(eof: Bool,covered: Bool,limited: Bool,+db: U32,state: State,snapshot: String,ordinal: U32,records: U32) -> IO(Step):
  match eof covered limited:
    case True{} True{} _: finish(db,state,True{},"Complete pinned retained extent scanned")
    case True{} False{} _: abort(db,fail("usage_raw_integrity","Final verified byte extent does not cover the accepted capture"))
    case False{} _ True{}: finish(db,state,False{},"Verified raw byte or physical record limit reached")
    case False{} _ False{}:
      do IO<Step>:
        rows : Result<&2,&2,Failure,List<&2,List<&2,Sql.Cell>>> <- raw_window(db,snapshot,ordinal,records)
        loaded(rows,db,state)

def step_state(+db: U32,state: State) -> IO(Step):
  State{+capture,+limits,+cursor,account,quality} = state
  Capture{_,_,_,_,snapshot,+extent,+records} = capture
  Limits{maxrecords,maxbytes,_,_} = limits
  Cursor{+ordinal,+offset,_} = cursor
  step_position(U32.is_eq(ordinal,records),U32.is_eq(offset,extent),
    U32.is_ge(ordinal,maxrecords) || U32.is_ge(offset,maxbytes),db,
    State{capture,limits,cursor,account,quality},snapshot,ordinal,records)

def step(run: Run) -> IO(Step):
  Run{db,state} = run
  step_state(db,state)

def boolean(value: Bool) -> String:
  Bool.pick(String,value,"true","false")

def capture_text(capture: Capture) -> String:
  Capture{provider,source,locator,generation,snapshot,extent,records} = capture
  "{\"provider\":" ++ Json.quote(provider) ++ ",\"source_id\":" ++ Json.quote(source) ++
    ",\"source\":" ++ Json.quote(locator) ++ ",\"generation\":" ++ Json.quote(generation) ++
    ",\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"extent\":" ++ Json.quote(U32.show(extent)) ++
    ",\"records\":" ++ Json.quote(U32.show(records)) ++ "}"

def witness_text(values: List<&2,Witness>,+capture: Capture) -> String:
  match values:
    case []: ""
    case Witness{+ordinal,reason} <> rest:
      "Raw record " ++ U32.show(ordinal) ++ ": " ++ reason ++ "\n" ++
        "{\"capture\":" ++ capture_text(capture) ++ ",\"physical_record\":" ++ Json.quote(U32.show(ordinal)) ++
        ",\"kind\":\"raw_usage_witness\"}\n" ++ witness_text(rest,capture)

def summary_text(value: Summary) -> String:
  match value:
    case ClaudeSummary{Claude.Report{session,keys,bytes,observed,own,copied,unattributed,records,missing,incomplete,conflicts,mirrors,complete,attributed}}:
      "Claude recorded call maxima across this capture\n" ++ Counts.text(observed) ++
        "Known one-hour cache creation is capped at recorded total creation before call maxima; absent split stays unknown.\n" ++
        "\nSource-session path association: " ++ Json.quote(session) ++ "\nSource-associated calls:\n" ++ Counts.text(own) ++
        "Copied-session calls retained separately (not cross-library deduplicated):\n" ++ Counts.text(copied) ++
        "Unknown or contradictory source attribution:\n" ++ Counts.text(unattributed) ++
        "Usage records: " ++ U32.show(records) ++ " | exact distinct call keys: " ++ U32.show(keys) ++
        " | repeat observations: " ++ U32.show(mirrors) ++ "\nMissing/invalid IDs excluded: " ++ U32.show(missing) ++
        " | incomplete bucket observations: " ++ U32.show(incomplete) ++ " | contradictory calls: " ++ U32.show(conflicts) ++
        "\nBucket observations complete: " ++ boolean(complete) ++ " | source attribution complete: " ++ boolean(attributed) ++
        "\nRetained logical UTF8 descriptor bytes: " ++ U32.show(bytes) ++
        " (not native heap or RSS). First origin/model/hour stays bound to its call.\n"
    case CodexSummary{Codex.Report{category,session,parent,basis,accounted,observations,accepted,duplicates,resets,excluded,uncertain,first,last,complete}}:
      "Codex category: " ++ category ++ " | recorded session: " ++ Json.quote(session) ++
        " | recorded parent_thread_id: " ++ Json.quote(parent) ++ "\nAccounting boundary policy: " ++ basis ++
        "\nAccounted recorded buckets (reviewer category is separate from coding-session usage):\n" ++ Counts.text(accounted) ++
        "Usage observations: " ++ U32.show(observations) ++ " | accepted: " ++ U32.show(accepted) ++
        " | duplicate totals: " ++ U32.show(duplicates) ++ " | restarts: " ++ U32.show(resets) ++
        " | excluded: " ++ U32.show(excluded) ++ " | uncertain: " ++ U32.show(uncertain) ++
        "\nFirst/last raw usage record: " ++ first ++ "/" ++ last ++ " | accounting complete: " ++ boolean(complete) ++
        "\nCached input is separated from inclusive input. total_tokens and reasoning subsets are not added again.\n"

def rendered(valid: Bool,text: String) -> Result<&2,&2,Failure,String>:
  Bool.pick(Result<&2,&2,Failure,String>,valid,Done{text},Fail{fail("usage_output_limit","Whole usage report exceeds1MiB UTF8; no captured identity or subtotal was truncated")})

def render(value: Report) -> Result<&2,&2,Failure,String>:
  Report{+capture,Limits{maxrecords,maxbytes,maxkeys,maxdescriptors},processed,bytes,complete,buckets,attributed,reason,
    Coverage{decoded,malformed,oversized,issues,items},summary} = value
  +text = "Juice Bend · retained-capture usage\n" ++ capture_text(capture) ++
    "\nScan complete: " ++ boolean(complete) ++ " | processed physical records: " ++ U32.show(processed) ++
    " | verified bytes: " ++ U32.show(bytes) ++ "\nRequired provider buckets complete: " ++ boolean(buckets) ++
    " | source attribution complete: " ++ boolean(attributed) ++ "\n" ++ reason ++
    "\nDecoded records: " ++ U32.show(decoded) ++ " | malformed: " ++ U32.show(malformed) ++
    " | oversized fragments: " ++ U32.show(oversized) ++ " | other coverage observations: " ++ U32.show(issues) ++
    "\nLimits: " ++ U32.show(maxrecords) ++ " records / " ++ U32.show(maxbytes) ++ " verified bytes / " ++
    U32.show(maxkeys) ++ " exact call keys / " ++ U32.show(maxdescriptors) ++ " logical UTF8 descriptor bytes.\n\n" ++
    summary_text(summary) ++ "\nUnknown buckets are not zero. Scan completion does not imply complete provider usage or source attribution. " ++
    "These are retained-record accounting facts, not a bill, quota, authorship proof, or a cross-library total. " ++
    "No source logs, accounts, network, prices, or models were consulted.\n" ++
    "At most16 raw-record witnesses follow; full original bytes remain in the cited immutable capture.\n" ++
    witness_text(List.reverse(&2,Witness,items),capture)
  rendered(Claude.fits_result(Claude.remaining(text,1048575)),text)
