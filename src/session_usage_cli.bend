import Base
import ./session_usage.bend as Reader
import ./session_usage_counts.bend as Counts
import ./session_usage_claude.bend as Claude
import ./session_usage_codex.bend as Codex
import ./catalog.bend as Catalog
import ./provenance.bend as P
import ./json.bend as Json

# Whole pinned capture only. There is no implicit lexical/provider/role/date
# scope widening here; the existing selected-page Usage command stays separate.
# Reader alone owns BEGIN/ROLLBACK. The adapter never starts an outer transaction.
def failure(-A: Type,error: Reader.Failure) -> IO(A):
  Reader.Failure{code,message} = error
  IO.die(A,2,"{\"error\":" ++ Json.quote(message) ++ ",\"code\":" ++ Json.quote(code) ++ "}")

def require(-A: Kind(&2),result: Result<&2,&2,Reader.Failure,A>) -> IO(A):
  match result:
    case Done{value}: IO.pure(A,value)
    case Fail{error}: failure(A,error)

def stopped(result: Result<&2,&2,Reader.Failure,Unit>) -> Result<&2,&2,Reader.Failure,Reader.Report>:
  match result:
    case Fail{error}: Fail{error}
    case Done{_}: Fail{Reader.Failure{"usage_step_limit","Whole-capture step limit reached; the owned read transaction was rolled back and no complete report was emitted"}}

def cancel(run: Reader.Run) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  do IO<Result<&2,&2,Reader.Failure,Reader.Report>>:
    closed : Result<&2,&2,Reader.Failure,Unit> <- Reader.cancel(run)
    return stopped(closed)

def drive(fuel: Nat,result: Reader.Step) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  match fuel result:
    case _ Reader.Finished{report}: IO.pure(Result<&2,&2,Reader.Failure,Reader.Report>,Done{report})
    case _ Reader.Failed{error}: IO.pure(Result<&2,&2,Reader.Failure,Reader.Report>,Fail{error})
    case 0n Reader.More{run,_}: cancel(run)
    case 1n+rest Reader.More{run,_}:
      do IO<Result<&2,&2,Reader.Failure,Reader.Report>>:
        next : Reader.Step <- Reader.step(run)
        drive(rest,next)

def first(fuel: Nat,run: Reader.Run) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  match fuel:
    case 0n: cancel(run)
    case 1n+rest:
      do IO<Result<&2,&2,Reader.Failure,Reader.Report>>:
        next : Reader.Step <- Reader.step(run)
        drive(rest,next)

def begun(result: Result<&2,&1,Reader.Failure,Reader.Run>,fuel: U32) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  match result:
    case Fail{error}: IO.pure(Result<&2,&2,Reader.Failure,Reader.Report>,Fail{error})
    case Done{run}: first(U32.to_nat(fuel),run)

def run_valid(valid: Bool,db: U32,snapshot: String,limits: Reader.Limits,steps: U32) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,Reader.Failure,Reader.Report>,
      Fail{Reader.Failure{"usage_invalid_request","Whole-capture step limit must be from 0 through 1000001"}})
    case True{}:
      do IO<Result<&2,&2,Reader.Failure,Reader.Report>>:
        started : Result<&2,&1,Reader.Failure,Reader.Run> <- Reader.begin(db,snapshot,limits)
        begun(started,steps)

# A zero step budget deliberately exercises cancellation after successful begin.
# Every continuing raw window consumes at least one record; records+1 allows
# even one-record windows plus the final EOF check. This is not a time limit.
def run_steps(db: U32,snapshot: String,limits: Reader.Limits,+steps: U32) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  run_valid(U32.is_le(steps,1000001),db,snapshot,limits,steps)

def run(db: U32,snapshot: String,+limits: Reader.Limits) -> IO(Result<&2,&2,Reader.Failure,Reader.Report>):
  Reader.Limits{records,_,_,_} = limits
  run_steps(db,snapshot,limits,U32.inc(records))

def optional(+value: String) -> String:
  Bool.pick(String,String.is_empty(value),"null",Json.quote(value))

def counters(value: Counts.Counters) -> String:
  Counts.Counters{input,cached,created,created1h,output} = value
  "{\"input_tokens\":" ++ optional(input) ++ ",\"cached_input_tokens\":" ++ optional(cached) ++
    ",\"cache_creation_input_tokens\":" ++ optional(created) ++ ",\"cache_creation_1h_input_tokens\":" ++
    optional(created1h) ++ ",\"output_tokens\":" ++ optional(output) ++ "}"

def limits_json(value: Reader.Limits) -> String:
  Reader.Limits{records,bytes,keys,descriptors} = value
  "{\"records\":" ++ U32.show(records) ++ ",\"bytes\":" ++ U32.show(bytes) ++
    ",\"keys\":" ++ U32.show(keys) ++ ",\"descriptor_bytes\":" ++ U32.show(descriptors) ++ "}"

def witness_items(values: List<&2,Reader.Witness>,separator: String) -> String:
  match values:
    case []: ""
    case Reader.Witness{record,reason} <> rest:
      separator ++ "{\"physical_record\":" ++ U32.show(record) ++ ",\"reason\":" ++ Json.quote(reason) ++ "}" ++ witness_items(rest,",")

def coverage_json(value: Reader.Coverage) -> String:
  Reader.Coverage{decoded,malformed,oversized,issues,witnesses} = value
  "{\"decoded\":" ++ U32.show(decoded) ++ ",\"malformed\":" ++ U32.show(malformed) ++
    ",\"oversized\":" ++ U32.show(oversized) ++ ",\"issues\":" ++ U32.show(issues) ++
    ",\"witnesses\":[" ++ witness_items(List.reverse(&2,Reader.Witness,witnesses),"") ++ "]}"

def summary_json(value: Reader.Summary) -> String:
  match value:
    case Reader.ClaudeSummary{Claude.Report{session,keys,bytes,observed,own,copied,unknown,records,missing,incomplete,conflicts,mirrors,buckets,attribution}}:
      "{\"provider\":\"claude\",\"source_session_path_association\":" ++ optional(session) ++
        ",\"observed\":" ++ counters(observed) ++ ",\"source_associated\":" ++ counters(own) ++
        ",\"copied_session\":" ++ counters(copied) ++ ",\"unattributed\":" ++ counters(unknown) ++
        ",\"usage_records\":" ++ U32.show(records) ++ ",\"distinct_call_keys\":" ++ U32.show(keys) ++
        ",\"descriptor_bytes\":" ++ U32.show(bytes) ++ ",\"missing_ids\":" ++ U32.show(missing) ++
        ",\"incomplete_observations\":" ++ U32.show(incomplete) ++ ",\"conflicting_calls\":" ++ U32.show(conflicts) ++
        ",\"repeat_observations\":" ++ U32.show(mirrors) ++ ",\"bucket_complete\":" ++ Reader.boolean(buckets) ++
        ",\"attribution_complete\":" ++ Reader.boolean(attribution) ++ "}"
    case Reader.CodexSummary{Codex.Report{category,session,parent,basis,accounted,observed,accepted,duplicates,resets,excluded,uncertain,first,last,complete}}:
      "{\"provider\":\"codex\",\"category\":" ++ Json.quote(category) ++ ",\"session\":" ++ optional(session) ++
        ",\"recorded_parent_thread_id\":" ++ optional(parent) ++ ",\"fork_basis\":" ++ Json.quote(basis) ++
        ",\"accounted\":" ++ counters(accounted) ++ ",\"observations\":" ++ U32.show(observed) ++
        ",\"accepted\":" ++ U32.show(accepted) ++ ",\"duplicates\":" ++ U32.show(duplicates) ++
        ",\"resets\":" ++ U32.show(resets) ++ ",\"excluded\":" ++ U32.show(excluded) ++
        ",\"uncertain\":" ++ U32.show(uncertain) ++ ",\"first_ordinal\":" ++ optional(first) ++
        ",\"last_ordinal\":" ++ optional(last) ++ ",\"accounting_complete\":" ++ Reader.boolean(complete) ++ "}"

def json(report: Reader.Report,text: String) -> String:
  Reader.Report{capture,limits,records,bytes,scan,buckets,attribution,reason,coverage,summary} = report
  "{\"kind\":\"session_usage\",\"capture\":" ++ Reader.capture_text(capture) ++
    ",\"processed_records\":" ++ U32.show(records) ++ ",\"verified_bytes\":" ++ U32.show(bytes) ++
    ",\"scan_complete\":" ++ Reader.boolean(scan) ++ ",\"bucket_complete\":" ++ Reader.boolean(buckets) ++
    ",\"attribution_complete\":" ++ Reader.boolean(attribution) ++ ",\"stop_reason\":" ++ Json.quote(reason) ++
    ",\"limits\":" ++ limits_json(limits) ++ ",\"coverage\":" ++ coverage_json(coverage) ++
    ",\"summary\":" ++ summary_json(summary) ++ ",\"text\":" ++ Json.quote(text) ++ "}"

def same(+a: Bool,+b: Bool) -> Bool:
  (a && b) || (Bool.not(a) && Bool.not(b))

def counter_valid(+value: String) -> Bool:
  String.is_empty(value) || (Nat.is_le(String.length(value),70n) && P.decimal_valid(value))

def counters_valid(value: Counts.Counters) -> Bool:
  Counts.Counters{a,b,c,d,e} = value
  counter_valid(a) && counter_valid(b) && counter_valid(c) && counter_valid(d) && counter_valid(e)

def summary_valid(value: Reader.Summary,provider: String) -> Bool:
  match value:
    case Reader.ClaudeSummary{Claude.Report{_,_,_,a,b,c,d,_,_,_,_,_,_,_}}:
      String.eq(provider,"claude") && counters_valid(a) && counters_valid(b) && counters_valid(c) && counters_valid(d)
    case Reader.CodexSummary{Codex.Report{_,_,_,_,counts,_,_,_,_,_,_,_,_,_}}:
      String.eq(provider,"codex") && counters_valid(counts)

def witnesses_valid(items: List<&2,Reader.Witness>,+total: U32) -> Bool:
  match items:
    case []: True{}
    case Reader.Witness{record,reason} <> rest:
      U32.is_lt(record,total) && Claude.fits_result(Claude.remaining(reason,512)) && witnesses_valid(rest,total)

def coverage_valid(value: Reader.Coverage,+processed: U32,+total: U32) -> Bool:
  Reader.Coverage{+decoded,+malformed,+oversized,issues,+witnesses} = value
  U32.is_le(decoded,processed) && U32.is_le(malformed,processed) && U32.is_le(oversized,processed) &&
    U32.is_eq(U32.add(U32.add(decoded,malformed),oversized),processed) && U32.is_le(issues,processed) &&
    Nat.is_le(List.length(&2,Reader.Witness,witnesses),16n) && witnesses_valid(witnesses,total)

def valid(report: Reader.Report) -> Bool:
  Reader.Report{Reader.Capture{+provider,source,+locator,generation,snapshot,+extent,+total},+limits,
    +processed,+bytes,+scan,buckets,attribution,reason,+coverage,+summary} = report
  Reader.Limits{maxrecords,maxbytes,_,_} = limits
  Catalog.identity_valid(source) && Catalog.identity_valid(generation) && Catalog.identity_valid(snapshot) &&
    Reader.provider_valid(provider) && String.starts_with(locator,"/") && Bool.not(String.contains(locator,"\0")) &&
    Claude.fits_result(Claude.remaining(locator,8192)) && Reader.limits_valid(limits) &&
    U32.is_le(processed,total) && U32.is_le(processed,maxrecords) && U32.is_le(bytes,extent) && U32.is_le(bytes,maxbytes) &&
    (Bool.not(scan) || (U32.is_eq(processed,total) && U32.is_eq(bytes,extent))) &&
    same(buckets,scan && Reader.coverage_complete(coverage) && Reader.summary_bucket(summary)) &&
    same(attribution,scan && Reader.coverage_complete(coverage) && Reader.summary_attribution(summary)) &&
    Claude.fits_result(Claude.remaining(reason,512)) && coverage_valid(coverage,processed,total) && summary_valid(summary,provider)

def bounded(text: String,budget: Maybe<&2,U32>) -> Result<&2,&2,Reader.Failure,String>:
  match budget:
    case Some{_}: Done{text}
    case None{}: Fail{Reader.Failure{"usage_output_limit","Escaped whole-capture usage report exceeds1048576 bytes including newline; no identity, counters or text were truncated"}}

def encoded(ok: Bool,report: Reader.Report,text: String) -> Result<&2,&2,Reader.Failure,String>:
  match ok:
    case False{}: Fail{Reader.Failure{"usage_report_integrity","Whole-capture report identity, coverage or bounded counters are inconsistent"}}
    case True{}:
      +output = json(report,text)
      bounded(output,Claude.remaining(output,1048575))

def encode(+report: Reader.Report,text: String) -> Result<&2,&2,Reader.Failure,String>:
  encoded(valid(report),report,text)

def rendered(+report: Reader.Report) -> Result<&2,&2,Reader.Failure,String>:
  do Result<&2,&2,Reader.Failure,String>:
    text : String <- Reader.render(report)
    encode(report,text)

def selected(db: U32,snapshot: String,limits: Reader.Limits) -> IO(Unit):
  do IO<Unit>:
    result : Result<&2,&2,Reader.Failure,Reader.Report> <- run(db,snapshot,limits)
    report : Reader.Report <- require(Reader.Report,result)
    output : String <- require(String,rendered(report))
    IO.print(output)

def command(db: U32,args: List<String>) -> IO(Unit):
  match args:
    case snapshot <> []: selected(db,snapshot,Reader.defaults())
    case _: failure(Unit,Reader.Failure{"usage","usage: session-usage SNAPSHOT; reads the whole pinned capture with explicit default limits"})
