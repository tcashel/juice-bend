import Base
import ./attachment_asset_identity.bend as Identity
import ./attachment_worker_protocol.bend as Worker
import ./attachment_inventory.bend as Inventory
import ./archive_meta.bend as Meta
import ./domain.bend as Domain

# Stored bytes describe an observation at capture time. They are never promoted
# into a claim about the historical original referenced by the retained log.
type RootEvidence is Data:
  RootEvidence{identity: String,canonical_path: String,policy_revision: String,enabled: Bool}

type Admission is Data:
  Admission{occurrence: Identity.Resolved,root: RootEvidence,observed_at_ms: String,payload: Worker.Payload}

type Receipt is Data:
  Receipt{occurrence: Identity.Resolved,root: RootEvidence,observed_at_ms: String,
    count: U32,chunks: U32,sha256: String,commitment: String}

type Chunk is Data:
  Chunk{ordinal: U32,offset: U32,length: U32,digest: String,bytes: List<&2,U32>}

type Owned is Data:
  Owned{receipt: Receipt,chunks: List<&2,Chunk>}

type Outcome is Data:
  Initialized{}
  Published{receipt: Receipt,retry: Bool}
  Loaded{value: Owned}
  Exported{receipt: Receipt,destination: String}

type Phase is Data:
  AssociationInserted{}
  ChunkInserted{ordinal: U32}
  BeforeCommit{}

# A fresh continuation comes back after each test observation. No environment
# switch or production fault route exists. Ordinary publication uses Inert.
type Observer is Type:
  Inert{}
  Observed{step: Phase -> IO(Result<&2,&1,Inventory.Failure,Observer>)}

def unit_result() -> Data: Result<&2,&2,Inventory.Failure,Unit>
def answer() -> Data: Result<&2,&2,Inventory.Failure,Outcome>

def profile() -> String: "external-attachment-bytes-v1"
def semantics() -> String: "external bytes observed at attachment capture time"
def byte_limit() -> U32: 1048576
def chunk_limit() -> U32: 65536
def chunk_count_limit() -> U32: 16

def failure(code: String,message: String) -> Inventory.Failure:
  Inventory.Failure{code,message}

def valid_time(+time: String) -> Bool:
  String.eq(time,"0") || Meta.identity(time)

def root_fields(value: RootEvidence) -> List<&2,String>:
  RootEvidence{identity,path,revision,enabled} = value
  [identity,path,revision,Bool.pick(String,enabled,"true","false")]

def root_valid(value: RootEvidence) -> Bool:
  RootEvidence{identity,path,revision,enabled} = value
  enabled && Meta.identity(identity) && Meta.identity(revision) && Worker.absolute(path)

def payload_bounded(valid: Bool,value: Worker.Payload) -> Bool:
  match valid:
    case False{}: False{}
    case True{}:
      Worker.Payload{+count,+digest,+bytes} = value
      Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(count)) &&
        Meta.digest_valid(digest) && String.eq(Domain.digest(bytes),digest)

def payload_valid(+value: Worker.Payload) -> Bool:
  Worker.Payload{count,_,bytes} = value
  payload_bounded(U32.is_le(count,byte_limit()) && Worker.byte_scan(bytes,byte_limit()),value)

def admission_valid(value: Admission) -> Bool:
  Admission{occurrence,root,time,payload} = value
  Identity.valid(occurrence) && root_valid(root) && valid_time(time) && payload_valid(payload)

def chunk_count(+count: U32) -> U32:
  U32.div(U32.add(count,U32.sub(chunk_limit(),1)),chunk_limit())

def fields(value: Receipt) -> List<&2,String>:
  Receipt{occurrence,root,time,count,chunks,digest,_} = value
  List.append(&2,String,[profile(),semantics()],List.append(&2,String,Identity.fields(occurrence),
    List.append(&2,String,root_fields(root),[time,"unix_milliseconds",U32.show(count),U32.show(chunks),digest,
      U32.show(byte_limit()),U32.show(chunk_limit()),U32.show(chunk_count_limit())])))

def commitment(value: Receipt) -> String:
  Domain.hash_finish(Meta.hash_fields(fields(value),Meta.initial_hash()))

def sealed(+value: Receipt) -> Receipt:
  Receipt{occurrence,root,time,count,chunks,digest,_} = value
  Receipt{occurrence,root,time,count,chunks,digest,commitment(value)}

def receipt(value: Admission) -> Receipt:
  Admission{occurrence,root,time,Worker.Payload{+count,digest,_}} = value
  sealed(Receipt{occurrence,root,time,count,chunk_count(count),digest,""})

def receipt_valid(+value: Receipt) -> Bool:
  Receipt{occurrence,root,time,+count,chunks,digest,seal} = value
  Identity.valid(occurrence) && root_valid(root) && valid_time(time) &&
    U32.is_le(count,byte_limit()) && U32.is_eq(chunks,chunk_count(count)) &&
    Meta.digest_valid(digest) && Meta.digest_valid(seal) && String.eq(seal,commitment(value))

def strings_equal(a: List<&2,String>,b: List<&2,String>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case av <> ar bv <> br: String.eq(av,bv) && strings_equal(ar,br)
    case _ _: False{}

def same(a: Receipt,b: Receipt) -> Bool:
  strings_equal(fields(a),fields(b))

def frames(values: List<&2,String>) -> String:
  match values:
    case []: ""
    case +value <> rest:
      Nat.show(List.length(&2,U32,Domain.encode(value))) ++ ":" ++ value ++ frames(rest)

# Exact length-framed metadata, compared to a freshly verified occurrence on
# every read. SQL stores this opaque text and never parses it or performs JSON.
def identity_text(value: Identity.Resolved) -> String:
  frames("attachment-local-occurrence-v1" <> Identity.fields(value))

def split(fuel: Nat,bytes: List<&2,U32>,+ordinal: U32,+offset: U32) -> List<&2,Chunk>:
  match fuel bytes:
    case _ Nil{}: []
    case 0n _: []
    case 1n+left +bytes:
      +part = List.take(&2,U32,bytes,65536n)
      +size = U32.from_nat(List.length(&2,U32,part))
      Chunk{ordinal,offset,size,Domain.digest(part),part} <>
        split(left,List.drop(&2,U32,bytes,65536n),U32.inc(ordinal),U32.add(offset,size))

def payload_chunks(value: Worker.Payload) -> List<&2,Chunk>:
  Worker.Payload{_,_,bytes} = value
  split(16n,bytes,0,0)

def chunk_bytes(chunks: List<&2,Chunk>) -> List<&2,List<&2,U32>>:
  match chunks:
    case []: []
    case Chunk{_,_,_,_,bytes} <> rest: bytes <> chunk_bytes(rest)

def chunks_equal(a: List<&2,Chunk>,b: List<&2,Chunk>) -> Bool:
  match a b:
    case Nil{} Nil{}: True{}
    case Chunk{ao,ap,an,ad,ab} <> ar Chunk{bo,bp,bn,bd,bb} <> br:
      U32.is_eq(ao,bo) && U32.is_eq(ap,bp) && U32.is_eq(an,bn) && String.eq(ad,bd) &&
        Domain.bytes_equal(ab,bb) && chunks_equal(ar,br)
    case _ _: False{}

def chunks_valid(chunks: List<&2,Chunk>,+ordinal: U32,+offset: U32,+total: U32) -> Bool:
  match chunks:
    case []: U32.is_eq(offset,total) && U32.is_eq(ordinal,chunk_count(total))
    case Chunk{actual,at,+n,digest,+bytes} <> rest:
      U32.is_lt(ordinal,chunk_count_limit()) && U32.is_eq(actual,ordinal) && U32.is_eq(at,offset) &&
        U32.is_le(offset,total) && U32.is_eq(n,U32.min(chunk_limit(),U32.sub(total,offset))) && U32.is_gt(n,0) &&
        Nat.is_eq(List.length(&2,U32,bytes),U32.to_nat(n)) && Worker.byte_scan(bytes,chunk_limit()) &&
        String.eq(Domain.digest(bytes),digest) && chunks_valid(rest,U32.inc(ordinal),U32.add(offset,n),total)

def owned_valid(value: Owned) -> Bool:
  Owned{+receipt,+chunks} = value
  Receipt{_,_,_,count,_,digest,_} = receipt
  receipt_valid(receipt) && chunks_valid(chunks,0,0,count) && String.eq(Meta.digest_chunks(chunk_bytes(chunks)),digest)
