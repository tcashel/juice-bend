import Base
import ./session_usage.bend as Session
import ./session_usage_counts.bend as Counts

type Limits is Data:
  Limits{sources: U32,records: U32,bytes: U32}

# status: eligible / incomplete / identity_unknown / reviewer / limited.
# Raw SHA is populated only after complete logical-byte verification.
type CaptureRow is Data:
  CaptureRow{capture: Session.Capture,session: String,sha256: String,category: String,
    counts: Counts.Counters,status: String,reason: String,report: Maybe<&2,Session.Report>}

type Metric is Data:
  Metric{sum: String,known: U32,unknown: U32,not_applicable: U32}

type Provider is Data:
  Provider{provider: String,sessions: U32,aliases: U32,ambiguous: U32,excluded: U32,
    input: Metric,cached: Metric,created: Metric,created1h: Metric,output: Metric}

type Decision is Data:
  Decision{capture: Session.Capture,session: String,status: String,
    canonical_snapshot: String,reason: String}

type Aggregate is Data:
  Aggregate{available: Bool,providers: List<&2,Provider>,decisions: List<&2,Decision>}

type Report is Data:
  Report{catalog_complete: Bool,selected_sources: U32,verified_records: U32,
    verified_bytes: U32,limits: Limits,rows: List<&2,CaptureRow>,aggregate: Aggregate}

def defaults() -> Limits:
  Limits{256,1000000,134217728}

def valid(limits: Limits) -> Bool:
  Limits{+sources,+records,+bytes} = limits
  U32.is_gt(sources,0) && U32.is_le(sources,256) &&
    U32.is_gt(records,0) && U32.is_le(records,1000000) &&
    U32.is_gt(bytes,0) && U32.is_le(bytes,134217728)
