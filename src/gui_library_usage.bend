import Base
import ./library_usage_types.bend as T
import ./session_usage.bend as S
import ./brief_safe_text.bend as Safe

# Pure controller for a typed report returned by the owned library reader.
# It does not parse untrusted transport JSON. A future child transport must
# validate its closed schema before calling these typed-result functions.
# The caller owns the complete original reader bookmark and its restoration.
type Phase is Data:
  IdlePhase{}
  LoadingPhase{}
  ReadyPhase{}
  FailedPhase{}
  CancelledPhase{}

type ScanProgress is Data:
  ScanProgress{selected_sources: U32,completed_sources: U32,
    verified_records: U32,verified_bytes: U32}

type Model is Data:
  Model{nonce: U32,phase: Phase,pending: Bool,limits: T.Limits,
    progress: Maybe<&2,ScanProgress>,report: List<&2,T.Report>,
    provider: String,selected_snapshot: String,message: String}

type Effect is Data:
  RequestLoad{nonce: U32,limits: T.Limits}
  RetireLoad{nonce: U32}
  RestoreOrigin{}
  OpenRetained{capture: S.Capture}

type Change is Data:
  Change{model: Model,effects: List<&2,Effect>}

def initial() -> Model:
  Model{0,IdlePhase{},False{},T.defaults(),None{},[],"","","Choose Library Usage to read retained captures."}

def loading(phase: Phase) -> Bool:
  match phase:
    case LoadingPhase{}: True{}
    case _: False{}

def ready(phase: Phase) -> Bool:
  match phase:
    case ReadyPhase{}: True{}
    case _: False{}

def phase(model: Model) -> Phase:
  Model{_,value,_,_,_,_,_,_,_} = model
  value

def busy(model: Model) -> Bool:
  Model{_,_,pending,_,_,_,_,_,_} = model
  pending

def message(model: Model) -> String:
  Model{_,_,_,_,_,_,_,_,value} = model
  value

def notice(model: Model,text: String) -> Model:
  Model{nonce,phase,pending,limits,progress,report,provider,selected,_} = model
  Model{nonce,phase,pending,limits,progress,report,provider,selected,text}

def unchanged(model: Model) -> Change:
  Change{model,[]}

def start_ready(allowed: Bool,+nonce: U32,+limits: T.Limits,model: Model) -> Change:
  match allowed:
    case False{}: unchanged(notice(model,"Library Usage request was not started: finish the previous scan and use a fresh request identity."))
    case True{}: Change{Model{nonce,LoadingPhase{},True{},limits,None{},[],"","",
      "Reading retained captures. No Usage totals are available yet."},[RequestLoad{nonce,limits}]}

def start(+nonce: U32,+limits: T.Limits,+model: Model) -> Change:
  Model{prior,_,pending,_,_,_,_,_,_} = model
  start_ready(Bool.not(pending) && U32.is_gt(nonce,prior) && T.valid(limits),nonce,limits,model)

def valid_values(progress: ScanProgress,limits: T.Limits) -> Bool:
  ScanProgress{+selected,complete,records,bytes} = progress
  T.Limits{maxsources,maxrecords,maxbytes} = limits
  U32.is_le(selected,maxsources) && U32.is_le(complete,selected) &&
    U32.is_le(records,maxrecords) && U32.is_le(bytes,maxbytes)

def monotonic(prior: Maybe<&2,ScanProgress>,next: ScanProgress) -> Bool:
  match prior:
    case None{}: True{}
    case Some{ScanProgress{selected,complete,records,bytes}}:
      ScanProgress{newselected,newcomplete,newrecords,newbytes} = next
      U32.is_eq(selected,newselected) && U32.is_le(complete,newcomplete) &&
        U32.is_le(records,newrecords) && U32.is_le(bytes,newbytes)

def active(+model: Model,nonce: U32) -> Bool:
  Model{expected,phase,pending,_,_,_,_,_,_} = model
  U32.is_eq(nonce,expected) && pending && loading(phase)

def progress_allowed(allowed: Bool,model: Model,next: ScanProgress) -> Model:
  match allowed:
    case False{}: model
    case True{}:
      Model{nonce,phase,pending,limits,_,report,provider,selected,message} = model
      Model{nonce,phase,pending,limits,Some{next},report,provider,selected,message}

def progressed(+model: Model,+nonce: U32,+next: ScanProgress) -> Model:
  Model{_,_,_,limits,prior,_,_,_,_} = model
  progress_allowed(active(model,nonce) && valid_values(next,limits) && monotonic(prior,next),model,next)

def limits_equal(a: T.Limits,b: T.Limits) -> Bool:
  T.Limits{asources,arecords,abytes} = a
  T.Limits{bsources,brecords,bbytes} = b
  U32.is_eq(asources,bsources) && U32.is_eq(arecords,brecords) && U32.is_eq(abytes,bbytes)

def final_progress(report: T.Report) -> ScanProgress:
  T.Report{_,+selected,records,bytes,_,_,_} = report
  ScanProgress{selected,selected,records,bytes}

def report_matches(model: Model,+report: T.Report) -> Bool:
  Model{_,_,_,+limits,prior,_,_,_,_} = model
  T.Report{+complete,selected,_,_,actual,rows,T.Aggregate{available,_,_}} = report
  limits_equal(limits,actual) && U32.is_eq(selected,U32.from_nat(List.length(&2,T.CaptureRow,rows))) &&
    Bool.not(Bool.xor(complete,available)) && valid_values(final_progress(report),limits) && monotonic(prior,final_progress(report))

def terminal_pending(model: Model) -> Model:
  Model{nonce,phase,_,limits,progress,report,provider,selected,message} = model
  Model{nonce,phase,False{},limits,progress,report,provider,selected,message}

def report_ready(valid: Bool,model: Model,+report: T.Report) -> Model:
  match valid:
    case False{}:
      Model{nonce,_,_,limits,_,_,_,_,_} = model
      Model{nonce,FailedPhase{},False{},limits,None{},[],"","",
        "Library Usage reply did not match its request or progress. No totals were accepted."}
    case True{}:
      Model{nonce,_,_,limits,_,_,_,_,_} = model
      Model{nonce,ReadyPhase{},False{},limits,Some{final_progress(report)},[report],"","",
        "All time across captured records. Choose a provider to inspect its retained captures."}

def received_match(matches: Bool,+model: Model,nonce: U32,+report: T.Report) -> Model:
  match matches:
    case False{}: model
    case True{}:
      Model{_,phase,_,_,_,_,_,_,_} = model
      match phase:
        case LoadingPhase{}: report_ready(report_matches(model,report),model,report)
        case _: terminal_pending(model)

def received(+model: Model,+nonce: U32,report: T.Report) -> Model:
  Model{expected,_,pending,_,_,_,_,_,_} = model
  received_match(U32.is_eq(nonce,expected) && pending,model,nonce,report)

def failure_active(is_loading: Bool,model: Model,text: String) -> Model:
  match is_loading:
    case False{}: terminal_pending(model)
    case True{}:
      Model{nonce,_,_,limits,progress,_,_,_,_} = model
      Model{nonce,FailedPhase{},False{},limits,progress,[],"","",text}

def failed_match(matches: Bool,+model: Model,text: String) -> Model:
  match matches:
    case False{}: model
    case True{}: failure_active(loading(phase(model)),model,text)

def failed(+model: Model,nonce: U32,text: String) -> Model:
  Model{expected,_,pending,_,_,_,_,_,_} = model
  failed_match(U32.is_eq(nonce,expected) && pending,model,text)

def cancelled(model: Model) -> Model:
  Model{nonce,_,pending,limits,progress,_,_,_,_} = model
  Model{nonce,CancelledPhase{},pending,limits,progress,[],"","",
    "Usage scan cancelled. Late results will be ignored; another scan waits for this worker to finish."}

def retirement(pending: Bool,nonce: U32) -> List<&2,Effect>:
  match pending:
    case False{}: []
    case True{}: [RetireLoad{nonce}]

def cancel(+model: Model) -> Change:
  Model{nonce,_,pending,_,_,_,_,_,_} = model
  Change{cancelled(model),retirement(pending,nonce)}

def back(+model: Model) -> Change:
  Model{nonce,_,pending,_,_,_,_,_,_} = model
  Change{cancelled(model),RestoreOrigin{} <> retirement(pending,nonce)}

# Caller emits this only after its exact worker ended; cancel/back alone do not
# release the slot. An active worker ending without a result is a failure.
def retired(+model: Model,nonce: U32) -> Model:
  Model{expected,phase,pending,_,_,_,_,_,_} = model
  failed_match(U32.is_eq(nonce,expected) && pending,model,
    "Library Usage worker ended without a report. No totals were accepted.")

def provider_valid(+name: String) -> Bool:
  String.is_empty(name) || String.eq(name,"claude") || String.eq(name,"codex")

def provider_selected(valid: Bool,model: Model,name: String) -> Model:
  match valid:
    case False{}: model
    case True{}:
      Model{nonce,phase,pending,limits,progress,report,_,_,message} = model
      Model{nonce,phase,pending,limits,progress,report,name,"",message}

def select_provider(+model: Model,+name: String) -> Model:
  provider_selected(ready(phase(model)) && provider_valid(name),model,name)

def capture_match(row: T.CaptureRow,+provider: String,snapshot: String) -> Maybe<&2,S.Capture>:
  T.CaptureRow{+capture,_,_,_,_,_,_,_} = row
  S.Capture{actual,_,_,_,id,_,_} = capture
  Bool.pick(Maybe<&2,S.Capture>,(String.is_empty(provider) || String.eq(actual,provider)) && String.eq(id,snapshot),Some{capture},None{})

def find_capture(rows: List<&2,T.CaptureRow>,+provider: String,+snapshot: String) -> Maybe<&2,S.Capture>:
  match rows:
    case []: None{}
    case row <> rest: Maybe.or(&2,S.Capture,capture_match(row,provider,snapshot),find_capture(rest,provider,snapshot))

def captured(reports: List<&2,T.Report>,provider: String,snapshot: String) -> Maybe<&2,S.Capture>:
  match reports:
    case [T.Report{_,_,_,_,_,rows,_}]: find_capture(rows,provider,snapshot)
    case _: None{}

def exists(value: Maybe<&2,S.Capture>) -> Bool:
  match value:
    case Some{_}: True{}
    case None{}: False{}

def capture_selected(valid: Bool,model: Model,snapshot: String) -> Model:
  match valid:
    case False{}: model
    case True{}:
      Model{nonce,phase,pending,limits,progress,report,provider,_,message} = model
      Model{nonce,phase,pending,limits,progress,report,provider,snapshot,message}

def select_capture(+model: Model,+snapshot: String) -> Model:
  Model{_,phase,_,_,_,report,provider,_,_} = model
  capture_selected(ready(phase) && exists(captured(report,provider,snapshot)),model,snapshot)

def target_ready(valid: Bool,reports: List<&2,T.Report>,provider: String,snapshot: String) -> Maybe<&2,S.Capture>:
  match valid:
    case False{}: None{}
    case True{}: captured(reports,provider,snapshot)

def target(model: Model) -> Maybe<&2,S.Capture>:
  Model{_,phase,_,_,_,report,provider,snapshot,_} = model
  target_ready(ready(phase),report,provider,snapshot)

def open_target(value: Maybe<&2,S.Capture>,model: Model) -> Change:
  match value:
    case None{}: unchanged(model)
    case Some{capture}: Change{model,[OpenRetained{capture}]}

def open(+model: Model) -> Change:
  open_target(target(model),model)

# Only status chrome is clipped. The original error remains in Model.message;
# exact capture identity is never reconstructed from these strings.
def shown(text: String) -> String:
  match text:
    case SNil{}: ""
    case SCon{+c,rest}: Bool.pick(String,Safe.control(c),Safe.escaped(c),SCon{c,SNil{}}) ++ shown(rest)

def display_prefix(+prefix: String) -> String:
  shown(String.take(prefix,256n)) ++ Bool.pick(String,Nat.is_gt(String.length(prefix),256n),"...","")

def display_message(text: String) -> String:
  display_prefix(String.take(text,257n))

def progress_text(value: Maybe<&2,ScanProgress>) -> String:
  match value:
    case None{}: "Reading the captured library. Totals will appear when the scan finishes."
    case Some{ScanProgress{selected,complete,_,_}}:
      "Checked " ++ U32.show(complete) ++ " of " ++ U32.show(selected) ++ " captured sources. Totals will appear when the scan finishes."

def status_text(model: Model) -> String:
  Model{_,phase,pending,_,progress,_,_,_,message} = model
  match phase:
    case IdlePhase{}: "See recorded usage across captured sessions."
    case LoadingPhase{}: progress_text(progress)
    case ReadyPhase{}: "All time across captured records. Choose a provider to inspect its captures."
    case FailedPhase{}: "Could not read library Usage. " ++ display_message(message)
    case CancelledPhase{}: Bool.pick(String,pending,"Cancelled. Waiting for the previous scan to finish.","Cancelled. Captured data is unchanged.")
