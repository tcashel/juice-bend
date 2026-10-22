import Base
import ./session_usage.bend as S

# Presentation-only values. Exact accounting and capture identity stay separate
# from clipped labels; UI adapters must never derive an Open request from text.
type MetricStyle is Data:
  RecordedValue{}
  KnownSubtotal{}
  UnknownValue{}
  NotApplicableValue{}
  UnobservedValue{}
  WithheldValue{}

type Measure is Data:
  Measure{label: String,value: String,style: MetricStyle,detail: String}

type Notice is Data:
  Notice{warning: Bool,text: String}

type ProviderCard is Data:
  ProviderCard{key: String,label: String,sessions: U32,aliases: U32,
    ambiguous: U32,excluded: U32,measures: List<&2,Measure>}

type CaptureItem is Data:
  CaptureItem{capture: S.Capture,title: String,status: String,summary: String,
    canonical_snapshot: String}

type View is Data:
  View{heading: String,scope: String,notices: List<&2,Notice>,totals_available: Bool,
    providers: List<&2,ProviderCard>,selected_provider: String,captures: List<&2,CaptureItem>}
