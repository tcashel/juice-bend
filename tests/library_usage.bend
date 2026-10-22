import Base
import ../src/library_usage.bend as L
import ../src/library_usage_types.bend as T
import ../src/session_usage.bend as S
import ../src/session_usage_counts.bend as Counts
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as D
import ../src/json.bend as J

def check(value: Bool,label: String) -> IO(Unit):
  match value:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def need_run(result: Result<&2,&1,S.Failure,L.Run>) -> IO(L.Run):
  match result:
    case Done{run}: IO.pure(L.Run,run)
    case Fail{S.Failure{code,message}}: IO.die(L.Run,1,code ++ ": " ++ message)

def drive(fuel: Nat,step: L.Step) -> IO(T.Report):
  match fuel step:
    case _ L.Finished{report}: IO.pure(T.Report,report)
    case _ L.Failed{S.Failure{code,message}}: IO.die(T.Report,1,code ++ ": " ++ message)
    case 1n+rest L.More{run}:
      do IO<T.Report>:
        next : L.Step <- L.step(run)
        drive(rest,next)
    case 0n L.More{run}:
      do IO<T.Report>:
        closed : Result<&2,&2,S.Failure,Unit> <- L.cancel(run)
        IO.die(T.Report,1,"test fuel exhausted")

def scan(+db: U32,limits: T.Limits) -> IO(T.Report):
  do IO<T.Report>:
    result : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,limits)
    run : L.Run <- need_run(result)
    first : L.Step <- L.step(run)
    drive(10000n,first)

def providers(report: T.Report) -> List<&2,T.Provider>:
  T.Report{_,_,_,_,_,_,T.Aggregate{_,values,_}} = report
  values

def provider(values: List<&2,T.Provider>,+name: String) -> T.Provider:
  match values:
    case []: T.Provider{name,0,0,0,0,T.Metric{"",0,0,0},T.Metric{"",0,0,0},T.Metric{"",0,0,0},T.Metric{"",0,0,0},T.Metric{"",0,0,0}}
    case +value <> rest:
      T.Provider{actual,_,_,_,_,_,_,_,_,_} = value
      Bool.pick(T.Provider,String.eq(actual,name),value,provider(rest,name))

def shape_provider(value: T.Provider) -> String:
  T.Provider{_,sessions,aliases,ambiguous,excluded,T.Metric{input,known,unknown,_},_,_,_,T.Metric{output,_,_,_}} = value
  U32.show(sessions) ++ "|" ++ U32.show(aliases) ++ "|" ++ U32.show(ambiguous) ++ "|" ++ U32.show(excluded) ++ "|" ++ input ++ "|" ++ output ++ "|" ++ U32.show(known) ++ "|" ++ U32.show(unknown)

def shape(report: T.Report,name: String) -> String:
  shape_provider(provider(providers(report),name))

def covered(report: T.Report) -> Bool:
  T.Report{complete,selected,records,_,_,rows,_} = report
  complete && U32.is_eq(selected,4) && U32.is_eq(records,9) && Nat.is_eq(List.length(&2,T.CaptureRow,rows),4n)

def withheld(report: T.Report) -> Bool:
  T.Report{all,_,_,_,_,_,T.Aggregate{available,groups,_}} = report
  Bool.not(all || available) && Nat.is_eq(List.length(&2,T.Provider,groups),0n)

def none_verified(report: T.Report) -> Bool:
  T.Report{complete,_,records,bytes,_,_,_} = report
  complete && U32.is_eq(records,0) && U32.is_eq(bytes,0)

def row(session: String,id: String,input: String,output: String) -> String:
  "{\"type\":\"assistant\",\"sessionId\":" ++ J.quote(session) ++ ",\"timestamp\":\"2026-10-22T10:00:00Z\",\"message\":{\"id\":" ++ J.quote(id) ++ ",\"model\":\"synthetic\",\"usage\":{\"input_tokens\":" ++ input ++ ",\"cache_read_input_tokens\":2,\"cache_creation_input_tokens\":3,\"output_tokens\":" ++ output ++ "},\"content\":\"synthetic\"}}\n"

def meta(id: String,source: String) -> String:
  "{\"type\":\"session_meta\",\"payload\":{\"id\":" ++ J.quote(id) ++ ",\"source\":" ++ source ++ ",\"timestamp\":\"2026-10-22T10:00:00Z\"}}\n"

def token(input: String,cached: String,output: String) -> String:
  "{\"type\":\"event_msg\",\"timestamp\":\"2026-10-22T10:01:00Z\",\"payload\":{\"type\":\"token_count\",\"info\":{\"total_token_usage\":{\"input_tokens\":" ++ input ++ ",\"cached_input_tokens\":" ++ cached ++ ",\"output_tokens\":" ++ output ++ "}}}}\n"

def capture(+db: U32,provider: String,+path: String,raw: String) -> IO(String):
  do IO<String>:
    Store.write_text(path,"w",raw)
    Store.import_file(db,provider,path)

def command_result(result: U32 & (String & String)) -> IO(Unit):
  (code,_) = result
  check(U32.is_eq(code,0),"synthetic fixture command completed")

def command(program: String,args: List<&1,String>) -> IO(Unit):
  do IO<Unit>:
    result : U32 & (String & String) <- IO.try(U32 & (String & String),Process.run(program,args,"",4096,5000))
    command_result(result)

def totals() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/library.sqlite")
    empty : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(empty,"claude"),"0|0|0|0|||0|0"),"empty library has no measured zero token counter")
    +raw : String = row("A","call","10","4") ++ row("A","call","10","5")
    +a : String <- capture(db,"claude","A.jsonl",raw)
    command("/bin/mkdir",["alias"])
    alias : String <- capture(db,"claude","alias/A.jsonl",raw)
    b : String <- capture(db,"codex","B.jsonl",meta("B","\"cli\"") ++ token("100","20","10") ++ token("200","30","30"))
    c : String <- capture(db,"codex","review.jsonl",meta("R","{\"subagent\":{\"other\":\"guardian\"}}") ++ token("500","50","60"))
    +initial : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(initial,"claude"),"1|1|0|0|10|5|1|0"),"full raw-identical moved Claude aliases count one mirrored call exactly")
    check(String.eq(shape(initial,"codex"),"1|0|0|1|170|30|1|0"),"Codex adjacent deltas retain noncached input and reviewers stay separate")
    check(covered(initial),"catalog physical raw coverage and all immutable alias/reviewer drilldown captures are explicit")
    Store.exec(db,"UPDATE events SET usage='forged',session='projection-is-not-authority'",[])
    after_projection : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(after_projection,"claude"),"1|1|0|0|10|5|1|0"),"projected usage/session tampering cannot change raw aggregate authority")
    Store.write_text("A.jsonl","a",row("A","new","7","2"))
    fresh : String <- Store.import_file(db,"claude","A.jsonl")
    +changed : T.Report <- scan(db,T.defaults())
    check(Bool.not(String.eq(a,fresh)) && String.eq(shape(changed,"claude"),"0|0|1|0|||0|0"),"latest append plus stale alias makes whole recorded identity ambiguous rather than choosing larger counters")
    limited : T.Report <- scan(db,T.Limits{1,1000000,134217728})
    check(withheld(limited),"truncated source catalog withholds aggregate because unseen aliases may conflict")
    IO.try(Unit,Sql.close(db))

def success(result: Result<&2,&2,S.Failure,Unit>) -> Bool:
  match result:
    case Done{_}: True{}
    case Fail{_}: False{}

def unknowns() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/unknown.sqlite")
    snapshot : String <- capture(db,"claude","unknown.jsonl",row("unknown","id","null","9"))
    +unknown : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(unknown,"claude"),"1|0|0|0|||0|1"),"one missing required counter yields an explicit unknown contribution without silently summing other buckets")
    zero : String <- capture(db,"claude","zero.jsonl",row("zero","id","0","0"))
    +mixed : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(mixed,"claude"),"2|0|0|0|0|0|1|1"),"measured zero stays distinct from an unknown identity group's counters")
    missing : String <- capture(db,"claude","empty-counters.jsonl","{\"type\":\"assistant\",\"sessionId\":\"empty-counters\",\"message\":{\"id\":\"present\",\"usage\":{}}}\n")
    entirely_unknown : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(entirely_unknown,"claude"),"3|0|0|0|0|0|1|2"),"raw-backed own call with every bucket missing remains an unknown contribution rather than losing session identity")
    +budget : T.Report <- scan(db,T.Limits{256,1,1})
    check(none_verified(budget) && String.eq(shape(budget,"claude"),"0|0|0|3|||0|0"),"capture allocation budget excludes whole captures without claiming verified raw or zero usage")
    IO.try(Unit,Sql.close(db))

def available(+db: U32,label: String) -> IO(Unit):
  do IO<Unit>:
    started : Result<&2,&2,S.Failure,Unit> <- S.start(db)
    closed : Result<&2,&2,S.Failure,Unit> <- S.cleanup(db)
    check(success(started) && success(closed),label)

def refused(result: Result<&2,&1,S.Failure,L.Run>) -> IO(Unit):
  match result:
    case Fail{S.Failure{code,_}}: check(String.eq(code,"usage_transaction_unavailable"),"existing caller transaction is refused explicitly")
    case Done{run}:
      do IO<Unit>:
        closed : Result<&2,&2,S.Failure,Unit> <- L.cancel(run)
        check(False{},"existing caller transaction was incorrectly accepted")

def transactions() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/transaction.sqlite")
    result : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    run : L.Run <- need_run(result)
    closed : Result<&2,&2,S.Failure,Unit> <- L.cancel(run)
    available(db,"explicit library cancellation releases its own read transaction")
    Store.exec(db,"BEGIN IMMEDIATE",[])
    Store.exec(db,"INSERT INTO settings(key,value) VALUES('caller','uncommitted')",[])
    result : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    refused(result)
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT value FROM settings WHERE key='caller'",[],1)
    check(String.eq(Store.field(Store.first(rows),0n),"uncommitted"),"failed begin does not roll back caller transaction")
    Store.exec(db,"ROLLBACK",[])
    IO.try(Unit,Sql.close(db))

def durable() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/durable.sqlite")
    +old : String <- capture(db,"claude","durable.jsonl",row("durable","one","9007199254740993","2"))
    started : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    run : L.Run <- need_run(started)
    +other : U32 <- Store.open(".build/durable.sqlite")
    Store.write_text("durable.jsonl","a",row("durable","two","7","3"))
    +later : String <- Store.import_file(other,"claude","durable.jsonl")
    IO.try(Unit,Sql.close(other))
    first : L.Step <- L.step(run)
    pinned : T.Report <- drive(10000n,first)
    check(Bool.not(String.eq(old,later)) && String.eq(shape(pinned,"claude"),"1|0|0|0|9007199254740993|2|1|0"),
      "catalog read view remains pinned while another WAL connection publishes an append")
    +before : T.Report <- scan(db,T.defaults())
    check(String.eq(shape(before,"claude"),"1|0|0|0|9007199254741000|5|1|0"),"fresh read chooses explicit current latest and preserves exact wide decimal addition")
    IO.try(Unit,Sql.close(db))
    command("/bin/rm",["--","durable.jsonl"])
    +reopened : U32 <- Store.open(".build/durable.sqlite")
    after : T.Report <- scan(reopened,T.defaults())
    check(String.eq(shape(before,"claude"),shape(after,"claude")),"source deletion and fresh SQLite reopen preserve library accounting")
    IO.try(Unit,Sql.close(reopened))

def failure(fuel: Nat,step: L.Step,+expected: String) -> IO(Unit):
  match fuel step:
    case _ L.Failed{S.Failure{code,_}}: check(String.eq(code,expected),"corrupt retained authority returns the exact failure without an aggregate")
    case _ L.Finished{_}: check(False{},"corrupt retained authority incorrectly produced an aggregate")
    case 1n+rest L.More{run}:
      do IO<Unit>:
        next : L.Step <- L.step(run)
        failure(rest,next,expected)
    case 0n L.More{run}:
      do IO<Unit>:
        closed : Result<&2,&2,S.Failure,Unit> <- L.cancel(run)
        check(False{},"corruption test fuel exhausted")

def corrupted_begin(result: Result<&2,&1,S.Failure,L.Run>) -> IO(Unit):
  match result:
    case Fail{S.Failure{code,_}}: check(String.eq(code,"library_usage_catalog_integrity"),"dangling latest pointer is an integrity failure")
    case Done{run}:
      do IO<Unit>:
        closed : Result<&2,&2,S.Failure,Unit> <- L.cancel(run)
        check(False{},"dangling latest pointer incorrectly opened a library run")

def corrupt() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/corrupt.sqlite")
    snapshot : String <- capture(db,"claude","corrupt.jsonl",row("corrupt","id","10","1"))
    Store.exec(db,"UPDATE raw SET digest='0000000000000000000000000000000000000000000000000000000000000000'",[])
    started : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    run : L.Run <- need_run(started)
    first : L.Step <- L.step(run)
    failure(100n,first,"usage_raw_integrity")
    available(db,"raw corruption releases the library-owned read transaction")
    Store.exec(db,"UPDATE sources SET latest=999999",[])
    denied : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    corrupted_begin(denied)
    available(db,"catalog corruption releases the library-owned read transaction")
    IO.try(Unit,Sql.close(db))

def unscanned(report: T.Report) -> Bool:
  T.Report{_,_,records,bytes,_,rows,_} = report
  match rows:
    case [T.CaptureRow{_,_,sha,_,_,status,_,None{}}]:
      U32.is_eq(records,0) && U32.is_eq(bytes,0) && String.is_empty(sha) && String.eq(status,"limited")
    case _: False{}

def admission_bound() -> IO(Unit):
  do IO<Unit>:
    +db : U32 <- Store.open(".build/admission.sqlite")
    snapshot : String <- capture(db,"claude","admission.jsonl",row("admission","id","1","2"))
    # Only this synthetic owned test DB is mutated. The huge BLOB stays inside
    # SQLite until the reader rejects it by length; no bytes enter Bend.
    Store.exec(db,"UPDATE raw SET bytes=zeroblob(1048577),n=1048577",[])
    report : T.Report <- scan(db,T.defaults())
    check(unscanned(report),"oversized stored BLOB is refused before payload allocation with no verified-byte or digest claim")
    Store.exec(db,"UPDATE raw SET bytes='x',n=1",[])
    result : Result<&2,&1,S.Failure,L.Run> <- L.begin(db,T.defaults())
    run : L.Run <- need_run(result)
    first : L.Step <- L.step(run)
    failure(100n,first,"library_usage_raw_integrity")
    available(db,"raw BLOB type refusal releases the owned transaction")
    IO.try(Unit,Sql.close(db))

def main() -> IO(Unit):
  do IO<Unit>:
    +cwd : String <- IO.try(String,IO.get_env("PWD"))
    Store.checked(String.contains(cwd,"juice-bend-test-library_usage."),"Synthetic test runner only")
    totals()
    unknowns()
    transactions()
    durable()
    corrupt()
    admission_bound()
