import Base
import ./attachment_asset_types.bend as T
import ./attachment_asset_identity.bend as I
import ./attachment_root_policy.bend as P
import ./attachment_capture_roots.bend as Roots
import ./attachment_inventory.bend as E
import ./attachment_inventory_output.bend as O
import ./attachment_refs.bend as Ref
import ./archive_meta.bend as Meta
import ./attachment_capture_command.bend as Command

type Knowledge is Data:
  NoMutation{}
  CaptureUncertain{}
  RootUncertain{}
  ExportUncertain{}
type Failure is Data:
  Failure{phase: String,cause: E.Failure,knowledge: Knowledge}

def result() -> Data: Result<&2,&2,Failure,String>
def refused(phase: String,code: String,knowledge: Knowledge) -> result():
  Fail{Failure{phase,E.Failure{code,"Attachment operation was not acknowledged as successful"},knowledge}}
def checked(value: Result<&2,&2,E.Failure,String>,phase: String,knowledge: Knowledge) -> result():
  match value:
    case Done{text}: Done{text}
    case Fail{error}: Fail{Failure{phase,error,knowledge}}
def knowledge(value: Knowledge) -> String:
  match value:
    case NoMutation{}: "not_attempted"
    case CaptureUncertain{}: "capture_uncertain"
    case RootUncertain{}: "root_mutation_uncertain"
    case ExportUncertain{}: "export_uncertain"
def error_fields(value: Failure) -> String:
  Failure{phase,E.Failure{code,message},state} = value
  "{\"kind\":\"attachment_capture_error\",\"profile\":\"attachment-capture-cli-v1\",\"phase\":" ++ O.quote(phase) ++
    ",\"code\":" ++ O.quote(code) ++ ",\"message\":" ++ O.quote(message) ++ ",\"mutation\":" ++ O.quote(knowledge(state)) ++ "}"
def error_checked(valid: Bool,value: Failure) -> String:
  match valid:
    case True{}: error_fields(value)
    case False{}: error_fields(Failure{"output",E.Failure{"attachment_capture_error_limit","Diagnostic exceeds bounded metadata contract"},CaptureUncertain{}})
def error(+value: Failure) -> String:
  Failure{phase,E.Failure{code,message},_} = value
  error_checked(Ref.bounded(phase,64) && Ref.bounded(code,128) && Ref.bounded(message,2048),value)
def bounded(text: String) -> Result<&2,&2,E.Failure,String>:
  do Result<&2,&2,E.Failure,String>:
    buffer : O.Buffer <- O.put(text,O.Buffer{262143,[]})
    return O.finish(buffer)
def root(value: T.RootEvidence) -> String:
  T.RootEvidence{id,path,revision,enabled} = value
  "{\"id\":" ++ O.quote(id) ++ ",\"canonical_path\":" ++ O.quote(path) ++ ",\"revision\":" ++ O.quote(revision) ++
    ",\"enabled\":" ++ O.bool(enabled) ++ "}"
def root_ack_checked(valid: Bool,operation: String,value: T.RootEvidence) -> result():
  match valid:
    case False{}: refused("root_ack","attachment_root_invalid",RootUncertain{})
    case True{}: checked(bounded("{\"kind\":\"attachment_root\",\"profile\":\"explicit-attachment-roots-v1\",\"operation\":" ++
      O.quote(operation) ++ ",\"root\":" ++ root(value) ++ "}"),"root_ack",RootUncertain{})
def root_ack(+operation: String,+value: T.RootEvidence) -> result():
  root_ack_checked(P.valid(value) && (String.eq(operation,"add") || String.eq(operation,"enable") || String.eq(operation,"disable")),operation,value)
def rows_valid(rows: List<&2,T.RootEvidence>) -> Bool:
  match rows:
    case []: True{}
    case value <> rest: P.valid(value) && rows_valid(rest)
def write_roots(rows: List<&2,T.RootEvidence>,buffer: O.Buffer,first: Bool) -> Result<&2,&2,E.Failure,O.Buffer>:
  match rows:
    case []: Done{buffer}
    case value <> rest:
      do Result<&2,&2,E.Failure,O.Buffer>:
        next : O.Buffer <- O.put(Bool.pick(String,first,"",",") ++ root(value),buffer)
        write_roots(rest,next,False{})
def cursor(value: Maybe<&2,String>) -> String:
  match value:
    case None{}: "null"
    case Some{id}: O.quote(id)
def page_fields(value: Roots.Page) -> Result<&2,&2,E.Failure,String>:
  Roots.Page{after,count,rows,next} = value
  do Result<&2,&2,E.Failure,String>:
    opened : O.Buffer <- O.put("{\"kind\":\"attachment_roots\",\"profile\":\"explicit-attachment-roots-v1\",\"after\":" ++
      O.quote(after) ++ ",\"requested\":" ++ U32.show(count) ++ ",\"next\":" ++ cursor(next) ++ ",\"roots\":[",O.Buffer{262143,[]})
    written : O.Buffer <- write_roots(rows,opened,True{})
    closed : O.Buffer <- O.put("]}",written)
    return O.finish(closed)
def page_checked(valid: Bool,value: Roots.Page) -> result():
  match valid:
    case True{}: checked(page_fields(value),"root_list",NoMutation{})
    case False{}: refused("root_list","attachment_root_invalid",NoMutation{})
def page(+value: Roots.Page) -> result():
  Roots.Page{_,+count,+rows,_} = value
  page_checked(U32.is_gt(count,0) && U32.is_le(count,40) && Nat.is_le(List.length(&2,T.RootEvidence,rows),U32.to_nat(count)) && rows_valid(rows),value)
def capture(value: Meta.Header) -> String:
  Meta.Header{snapshot,source,generation,provider,locator,extent,records,checkpoint,ordinal,accepted,encoding} = value
  "{\"snapshot\":" ++ O.quote(snapshot) ++ ",\"source_id\":" ++ O.quote(source) ++ ",\"generation\":" ++ O.quote(generation) ++
    ",\"provider\":" ++ O.quote(provider) ++ ",\"source\":" ++ O.quote(locator) ++ ",\"extent\":" ++ U32.show(extent) ++
    ",\"byte_space\":\"logical_source_bytes\",\"total_records\":" ++ U32.show(records) ++ ",\"checkpoint\":" ++ U32.show(checkpoint) ++
    ",\"checkpoint_ordinal\":" ++ U32.show(ordinal) ++ ",\"accepted\":" ++ O.bool(accepted) ++ ",\"encoding\":" ++ O.quote(encoding) ++ "}"
def local(value: I.LocalReference) -> String:
  match value:
    case I.LocalPath{path}: "{\"type\":\"local_path\",\"value\":" ++ O.quote(path) ++ "}"
    case I.LocalFileURL{url}: "{\"type\":\"local_file_url\",\"value\":" ++ O.quote(url) ++ "}"
def occurrence(value: I.Resolved) -> String:
  I.Resolved{header,record,offset,length,digest,reference,path,kind,value} = value
  "{\"capture\":" ++ capture(header) ++ ",\"byte_space\":\"logical_source_bytes\",\"record\":" ++ U32.show(record) ++ ",\"offset\":" ++ U32.show(offset) ++
    ",\"length\":" ++ U32.show(length) ++ ",\"raw_sha256\":" ++ O.quote(digest) ++ ",\"reference\":" ++ U32.show(reference) ++
    ",\"json_path\":" ++ O.quote(path) ++ ",\"attachment_kind\":" ++ O.quote(kind) ++ ",\"local_reference\":" ++ local(value) ++ "}"
def receipt(value: T.Receipt) -> String:
  T.Receipt{identity,chosen,time,count,chunks,digest,commitment} = value
  "{\"occurrence\":" ++ occurrence(identity) ++ ",\"root\":" ++ root(chosen) ++ ",\"observed_at_ms\":" ++ O.quote(time) ++
    ",\"time_unit\":\"unix_milliseconds\",\"semantics\":" ++ O.quote(T.semantics()) ++ ",\"count\":" ++ U32.show(count) ++
    ",\"chunks\":" ++ U32.show(chunks) ++ ",\"sha256\":" ++ O.quote(digest) ++ ",\"commitment\":" ++ O.quote(commitment) ++ "}"
def destination(value: Maybe<&2,String>) -> String:
  match value:
    case None{}: ""
    case Some{path}: ",\"destination\":" ++ O.quote(path)
def destination_valid(value: Maybe<&2,String>) -> Bool:
  match value:
    case None{}: True{}
    case Some{path}: Command.export_path(path)
def asset_checked(valid: Bool,state: String,value: T.Receipt,path: Maybe<&2,String>,knowledge: Knowledge) -> result():
  match valid:
    case False{}: refused("asset_ack","attachment_capture_ack",knowledge)
    case True{}: checked(bounded("{\"kind\":\"attachment_asset\",\"profile\":" ++ O.quote(T.profile()) ++
      ",\"state\":" ++ O.quote(state) ++ ",\"receipt\":" ++ receipt(value) ++ destination(path) ++ "}"),"asset_ack",knowledge)
def asset(+state: String,+value: T.Receipt,+path: Maybe<&2,String>,knowledge: Knowledge) -> result():
  asset_checked(T.receipt_valid(value) && destination_valid(path) &&
    (String.eq(state,"captured") || String.eq(state,"already_captured") || String.eq(state,"retained") || String.eq(state,"exported")),
    state,value,path,knowledge)
