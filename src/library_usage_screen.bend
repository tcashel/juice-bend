import Base
import ./gui_library_usage.bend as M
import ./library_usage_presentation.bend as P
import ./library_usage_view_types.bend as V
import ./library_usage_types.bend as T
import ./session_usage.bend as S

# Native chrome receives display text and exact typed row identities separately.
type Screen is Data:
  Screen{title: String,text: String,status: String,provider: String,phase: U32,rows: List<&2,V.CaptureItem>}

def phase(value: M.Phase) -> U32:
  match value:
    case M.LoadingPhase{}: 1
    case M.ReadyPhase{}: 2
    case M.FailedPhase{}: 3
    case M.CancelledPhase{}: 4
    case _: 4

def nonce(model: M.Model) -> U32:
  M.Model{value,_,_,_,_,_,_,_,_} = model
  value

def provider(model: M.Model) -> String:
  M.Model{_,_,_,_,_,_,value,_,_} = model
  value

def summary(view: V.View) -> String:
  V.View{heading,scope,notices,available,providers,selected,_} = view
  P.text(V.View{heading,scope,notices,available,providers,selected,[]})

def ready_view(view: V.View,status: String) -> Screen:
  V.View{heading,scope,notices,available,providers,+selected,rows} = view
  Screen{"Library usage | all time",summary(V.View{heading,scope,notices,available,providers,selected,[]}),status,selected,2,rows}

def report_view(reports: List<&2,T.Report>,provider: String,status: String) -> Screen:
  match reports:
    case [report]: ready_view(P.report(report,provider),status)
    case _: Screen{"Library usage | unavailable","No accepted Usage report. Reload to inspect captured records.",status,provider,3,[]}

def view(+model: M.Model) -> Screen:
  M.Model{_,+state,_,_,_,reports,provider,_,message} = model
  match state:
    case M.ReadyPhase{}: report_view(reports,provider,M.status_text(model))
    case _: Screen{"Library usage | all time",M.status_text(model) ++ "\n\nCounters are recorded provider facts. Missing counters remain unknown.\nNo prices, inferred costs or activity-date chart are calculated.",M.status_text(model),provider,phase(state),[]}

def titles(rows: List<&2,V.CaptureItem>) -> List<&2,String>:
  match rows:
    case []: []
    case V.CaptureItem{_,title,status,summary,_} <> rest: (title ++ "\n" ++ status ++ " · " ++ summary) <> titles(rest)

def row(rows: List<&2,V.CaptureItem>,index: Nat) -> Maybe<&2,S.Capture>:
  match rows index:
    case Nil{} _: None{}
    case Con{V.CaptureItem{capture,_,_,_,_},_} 0n: Some{capture}
    case Con{_,rest} 1n+n: row(rest,n)

def selected_view(value: Screen,index: U32) -> Maybe<&2,S.Capture>:
  Screen{_,_,_,_,_,rows} = value
  row(rows,U32.to_nat(index))

def selected(model: M.Model,index: U32) -> Maybe<&2,S.Capture>:
  selected_view(view(model),index)
