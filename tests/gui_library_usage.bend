import Base
import ../src/gui_library_usage.bend as M
import ../src/library_usage_types.bend as T
import ../src/library_usage_aggregate.bend as A
import ../src/session_usage.bend as S
import ../src/session_usage_counts.bend as C

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def row(provider: String,id: String,session: String,sha: String) -> T.CaptureRow:
  T.CaptureRow{S.Capture{provider,"17","/synthetic/original.jsonl","23",id,50,1},session,sha,"ordinary",
    C.Counters{"10","2","3","","4"},"eligible","verified synthetic call",None{}}

def report() -> T.Report:
  +rows : List<&2,T.CaptureRow> = [row("claude","101","one","aaa"),row("claude","102","one","aaa"),row("codex","103","two","bbb")]
  T.Report{True{},3,3,150,T.defaults(),rows,A.summarize(rows,True{})}

def model(change: M.Change) -> M.Model:
  M.Change{model,_} = change
  model

def effects(change: M.Change) -> List<&2,M.Effect>:
  M.Change{_,effects} = change
  effects

def none(effects: List<&2,M.Effect>) -> Bool:
  match effects:
    case []: True{}
    case _: False{}

def started() -> M.Model:
  model(M.start(1,T.defaults(),M.initial()))

def ready_model() -> M.Model:
  M.received(started(),1,report())

def phase_id(phase: M.Phase) -> U32:
  match phase:
    case M.IdlePhase{}: 0
    case M.LoadingPhase{}: 1
    case M.ReadyPhase{}: 2
    case M.FailedPhase{}: 3
    case M.CancelledPhase{}: 4

def phase(model: M.Model) -> U32:
  phase_id(M.phase(model))

def progress(model: M.Model) -> String:
  M.Model{_,_,_,_,value,_,_,_,_} = model
  match value:
    case None{}: "none"
    case Some{M.ScanProgress{sources,complete,records,bytes}}:
      U32.show(sources) ++ ":" ++ U32.show(complete) ++ ":" ++ U32.show(records) ++ ":" ++ U32.show(bytes)

def load(effects: List<&2,M.Effect>,nonce: U32) -> Bool:
  match effects:
    case [M.RequestLoad{actual,limits}]: U32.is_eq(actual,nonce) && M.limits_equal(limits,T.defaults())
    case _: False{}

def retire(effects: List<&2,M.Effect>) -> Bool:
  match effects:
    case [M.RetireLoad{nonce}]: U32.is_eq(nonce,1)
    case _: False{}

def restore(effects: List<&2,M.Effect>) -> Bool:
  match effects:
    case [M.RestoreOrigin{},M.RetireLoad{nonce}]: U32.is_eq(nonce,1)
    case _: False{}

def no_target(value: Maybe<&2,S.Capture>) -> Bool:
  match value:
    case None{}: True{}
    case Some{_}: False{}

def exact(value: Maybe<&2,S.Capture>,snapshot: String,provider: String) -> Bool:
  match value:
    case Some{S.Capture{actual,source,locator,generation,id,extent,records}}:
      String.eq(id,snapshot) && String.eq(actual,provider) && String.eq(source,"17") &&
        String.eq(locator,"/synthetic/original.jsonl") && String.eq(generation,"23") &&
        U32.is_eq(extent,50) && U32.is_eq(records,1)
    case _: False{}

def opened(effects: List<&2,M.Effect>) -> Bool:
  match effects:
    case [M.OpenRetained{capture}]: exact(Some{capture},"102","claude")
    case _: False{}

def begin_and_progress() -> IO(Unit):
  +start : M.Change = M.start(1,T.defaults(),M.initial())
  +first : M.Model = M.progressed(model(start),1,M.ScanProgress{3,1,1,50})
  +second : M.Model = M.progressed(first,1,M.ScanProgress{3,2,2,100})
  do IO<Unit>:
    check(U32.is_eq(phase(M.initial()),0) && Bool.not(M.busy(M.initial())) && no_target(M.target(M.initial())),"idle model has no worker, report or open target")
    check(load(effects(start),1) && U32.is_eq(phase(model(start)),1) && M.busy(model(start)),"fresh request enters loading with exact limits and one worker effect")
    check(none(effects(M.start(2,T.defaults(),model(start)))),"loading cannot launch a second worker")
    check(String.eq(progress(second),"3:2:2:100"),"bounded progress advances actual capture and verified-byte counts")
    check(String.eq(progress(M.progressed(second,1,M.ScanProgress{3,1,1,50})),progress(second)),"regressive progress is ignored")
    check(String.eq(progress(M.progressed(second,1,M.ScanProgress{4,2,2,100})),progress(second)),"catalog identity cannot change during progress")
    check(String.eq(progress(M.progressed(second,1,M.ScanProgress{3,4,1000001,134217729})),progress(second)),"over-bound progress cannot reach presentation")
    check(String.eq(progress(M.progressed(second,9,M.ScanProgress{3,3,3,150})),progress(second)),"stale progress cannot update current request")
    check(U32.is_eq(phase(M.received(second,9,report())),1) && M.busy(M.received(second,9,report())),"stale terminal reply neither accepts totals nor releases current worker")
    check(U32.is_eq(phase(M.received(second,1,report())),2) && Bool.not(M.busy(M.received(second,1,report()))),"matching actual typed report reaches ready after monotonic progress")
    check(String.eq(M.status_text(second),"Checked 2 of 3 captured sources. Totals will appear when the scan finishes."),"loading presentation uses actual source progress without duration or completion estimates")

def wrong_limits(report: T.Report) -> T.Report:
  T.Report{complete,selected,records,bytes,_,rows,aggregate} = report
  T.Report{complete,selected,records,bytes,T.Limits{255,1000000,134217728},rows,aggregate}

def wrong_rows(report: T.Report) -> T.Report:
  T.Report{complete,_,records,bytes,limits,rows,aggregate} = report
  T.Report{complete,4,records,bytes,limits,rows,aggregate}

def final_admission() -> IO(Unit):
  +badlimits : M.Model = M.received(started(),1,wrong_limits(report()))
  +badrows : M.Model = M.received(started(),1,wrong_rows(report()))
  do IO<Unit>:
    check(U32.is_eq(phase(badlimits),3) && Bool.not(M.busy(badlimits)) && no_target(M.target(badlimits)),"terminal report with different limits fails without accepting totals")
    check(U32.is_eq(phase(badrows),3) && Bool.not(M.busy(badrows)),"terminal capture coverage must match its retained drilldown rows")
    check(U32.is_eq(phase(M.received(M.progressed(started(),1,M.ScanProgress{3,2,4,200}),1,report())),3),"final report cannot erase already observed verified progress")
    check(none(effects(M.start(0,T.defaults(),M.initial()))) && none(effects(M.start(1,T.defaults(),ready_model()))),"zero and reused request identities cannot start a scan")
    check(none(effects(M.start(1,T.Limits{257,1000000,134217728},M.initial()))),"unsupported request bounds are refused before a worker starts")

def cancellation() -> IO(Unit):
  +cancel : M.Change = M.cancel(started())
  +back : M.Change = M.back(started())
  +late : M.Model = M.received(model(cancel),1,report())
  +closed : M.Model = M.retired(model(cancel),1)
  do IO<Unit>:
    check(U32.is_eq(phase(model(cancel)),4) && M.busy(model(cancel)) && retire(effects(cancel)),"cancel retires exact worker but retains its single-flight slot until terminal")
    check(none(effects(M.start(2,T.defaults(),model(cancel)))),"cancelled pending worker prevents an overlapping replacement")
    check(restore(effects(back)) && U32.is_eq(phase(model(back)),4),"Back requests original bookmark restoration and exact worker retirement")
    check(U32.is_eq(phase(late),4) && Bool.not(M.busy(late)) && no_target(M.target(late)),"late successful reply after cancel is discarded while releasing only its slot")
    check(U32.is_eq(phase(closed),4) && Bool.not(M.busy(closed)),"acknowledged retired worker preserves cancellation instead of showing an error")
    check(M.busy(M.retired(model(cancel),9)),"wrong terminal identity cannot release a retired worker")
    check(load(effects(M.start(2,T.defaults(),closed)),2),"fresh request may start only after actual worker termination")
    check(U32.is_eq(phase(M.retired(started(),1)),3),"active worker ending without a report is a visible failure")

def failures_and_drilldown() -> IO(Unit):
  +failure : M.Model = M.failed(started(),1,"Synthetic read failed")
  +provider : M.Model = M.select_provider(ready_model(),"claude")
  +selected : M.Model = M.select_capture(provider,"102")
  do IO<Unit>:
    check(U32.is_eq(phase(failure),3) && Bool.not(M.busy(failure)) && String.eq(M.message(failure),"Synthetic read failed"),"matching failure has no totals and releases its ended worker")
    check(U32.is_eq(phase(M.failed(started(),8,"late")),1) && M.busy(M.failed(started(),8,"late")),"stale failure leaves current loading state intact")
    check(no_target(M.target(M.select_capture(started(),"101"))),"loading cannot choose or open a capture")
    check(exact(M.target(M.select_capture(ready_model(),"103")),"103","codex"),"All providers overview opens its exact displayed captured descriptor")
    check(exact(M.target(selected),"102","claude") && opened(effects(M.open(selected))),"provider drilldown opens the selected exact alias snapshot and original full descriptor")
    check(no_target(M.target(M.select_capture(provider,"103"))),"a capture from another provider cannot cross the selected provider scope")
    check(no_target(M.target(M.select_provider(selected,"codex"))),"switching provider clears prior capture selection")
    check(no_target(M.target(M.select_provider(selected,""))) && exact(M.target(M.select_capture(M.select_provider(selected,""),"103")),"103","codex"),"returning to All providers clears selection and permits either provider without retargeting")
    check(exact(M.target(M.select_capture(M.select_provider(selected,"codex"),"103")),"103","codex"),"second provider chooses its own immutable capture without latest retargeting")
    check(exact(M.target(M.received(selected,1,wrong_limits(report()))),"102","claude"),"duplicate terminal replies cannot replace accepted selection")
    check(exact(M.target(M.select_capture(selected,"999")),"102","claude"),"invalid capture selection cannot retarget the existing exact selection")
    check(no_target(M.target(model(M.back(selected)))),"Back leaves no Usage capture target behind")
    check(Bool.not(String.contains(M.status_text(M.failed(started(),1,"bad\nrow\0")),"\n")) && String.contains(M.status_text(M.failed(started(),1,"bad\nrow\0")),"\\u000a"),"visible failure escapes recorded control characters")

def repeat(left: Nat) -> String:
  match left:
    case Zero{}: ""
    case Succ{rest}: "x" ++ repeat(rest)

def bounded_failure() -> IO(Unit):
  +original : String = repeat(4096n) ++ "recorded tail"
  +failure : M.Model = M.failed(started(),1,original)
  do IO<Unit>:
    check(String.eq(M.message(failure),original),"bounded failure chrome preserves the exact original error for details")
    check(String.eq(M.status_text(failure),"Could not read library Usage. " ++ repeat(256n) ++ "..."),"failure chrome inspects at most 257 scalars and shows a bounded prefix")

def main() -> IO(Unit):
  do IO<Unit>:
    begin_and_progress()
    final_admission()
    cancellation()
    failures_and_drilldown()
    bounded_failure()
