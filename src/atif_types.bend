import Base
import ./providers.bend as Providers
import ./session_usage.bend as Usage

# Each event refers to exactly one verified retained physical raw row. For
# compressed captures offset/length are logical decoded JSONL byte positions.
type AtifEvent is Data:
  AtifEvent{number: U32,record: U32,slot: U32,offset: U32,length: U32,
    digest: String,complete: Bool,oversized: Bool,recorded_metadata: String,
    value: Providers.Record}

type Origin is Data:
  Origin{capture: Usage.Capture,byte_space: String,archive: String}

type Limits is Data:
  Limits{records: U32,bytes: U32,events: U32,step_bytes: U32,output_bytes: U32}

type Failure is Data:
  Failure{code: String,message: String}

type Receipt is Data:
  Receipt{snapshot: String,destination: String,records: U32,events: U32,
    steps: U32,bytes: U32}

def defaults() -> Limits:
  Limits{1000000,1073741824,2000000,2097152,2147483648}

def failure(-A: Kind(&2),code: String,message: String) -> Result<&2,&2,Failure,A>:
  Fail{Failure{code,message}}

def check(ok: Bool,code: String,message: String) -> Result<&2,&2,Failure,Unit>:
  Bool.pick(Result<&2,&2,Failure,Unit>,ok,Done{Unit{}},Fail{Failure{code,message}})
