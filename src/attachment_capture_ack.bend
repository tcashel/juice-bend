# Strict metadata acknowledgement decoder. No source reads, byte payloads or
# mutation authority arise from presentation. Owned preview re-verifies bytes.
import Base
import ./json.bend as J
import ./gui_settings.bend as Shape
import ./gui_attachments.bend as G
import ./attachment_asset_types.bend as T
import ./attachment_asset_identity.bend as I
import ./attachment_root_policy.bend as P
import ./attachment_root_rules.bend as Rules
import ./attachment_capture_command.bend as Command
import ./archive_meta.bend as Meta
import ./provenance.bend as Numeric

type Asset is Data:
  Asset{state: String,receipt: T.Receipt,destination: Maybe<&2,String>}
type RootPage is Data:
  RootPage{after: String,count: U32,rows: List<&2,T.RootEvidence>,next: Maybe<&2,String>}
def message() -> String: "Attachment acknowledgement did not match its bounded immutable metadata contract"
def guard(valid: Bool) -> Result<&2,&2,String,Unit>:
  Bool.pick(Result<&2,&2,String,Unit>,valid,Done{Unit{}},Fail{message()})
def root_value(+value: J.Json) -> T.RootEvidence:
  T.RootEvidence{J.get(value,"id"),J.get(value,"canonical_path"),J.get(value,"revision"),G.true(J.field(value,"enabled"))}
def root_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["id","canonical_path","revision","enabled"]) && G.identity(J.field(value,"id")) &&
    G.identity(J.field(value,"revision")) && G.bounded(J.field(value,"canonical_path"),4096) &&
    Rules.path(J.get(value,"canonical_path")) && Shape.boolean(J.field(value,"enabled"))
def root(+value: J.Json) -> Result<&2,&2,String,T.RootEvidence>:
  do Result<&2,&2,String,T.RootEvidence>:
    _ : Unit <- guard(root_shape(value))
    return root_value(value)
def header_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["snapshot","source_id","generation","provider","source","extent","byte_space","total_records","checkpoint","checkpoint_ordinal","accepted","encoding"]) &&
    G.identity(J.field(value,"snapshot")) && G.identity(J.field(value,"source_id")) && G.identity(J.field(value,"generation")) &&
    G.bounded(J.field(value,"provider"),16) && G.bounded(J.field(value,"source"),4096) && G.bounded(J.field(value,"encoding"),32) &&
    Shape.text_is(J.field(value,"byte_space"),"logical_source_bytes") && Shape.boolean(J.field(value,"accepted")) &&
    G.numeric(J.field(value,"extent")) && G.numeric(J.field(value,"total_records")) && G.numeric(J.field(value,"checkpoint")) && G.numeric(J.field(value,"checkpoint_ordinal"))
def header(+value: J.Json) -> Meta.Header:
  Meta.Header{J.get(value,"snapshot"),J.get(value,"source_id"),J.get(value,"generation"),J.get(value,"provider"),J.get(value,"source"),
    G.number(J.field(value,"extent")),G.number(J.field(value,"total_records")),G.number(J.field(value,"checkpoint")),
    G.number(J.field(value,"checkpoint_ordinal")),G.true(J.field(value,"accepted")),J.get(value,"encoding")}
def local_value(kind: String,value: String) -> Result<&2,&2,String,I.LocalReference>:
  match kind:
    case "local_path": Done{I.LocalPath{value}}
    case "local_file_url": Done{I.LocalFileURL{value}}
    case _: Fail{message()}
def local(+value: J.Json) -> Result<&2,&2,String,I.LocalReference>:
  do Result<&2,&2,String,I.LocalReference>:
    _ : Unit <- guard(Shape.exact_object(value,["type","value"]) && G.bounded(J.field(value,"type"),32) && G.bounded(J.field(value,"value"),4096))
    local_value(J.get(value,"type"),J.get(value,"value"))
def occurrence_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["capture","byte_space","record","offset","length","raw_sha256","reference","json_path","attachment_kind","local_reference"]) &&
    header_shape(J.field(value,"capture")) && Shape.text_is(J.field(value,"byte_space"),"logical_source_bytes") &&
    G.numeric(J.field(value,"record")) && G.numeric(J.field(value,"offset")) && G.numeric(J.field(value,"length")) && G.numeric(J.field(value,"reference")) &&
    G.bounded(J.field(value,"raw_sha256"),64) && G.bounded(J.field(value,"json_path"),2048) && G.bounded(J.field(value,"attachment_kind"),32)
def occurrence(+value: J.Json) -> Result<&2,&2,String,I.Resolved>:
  do Result<&2,&2,String,I.Resolved>:
    _ : Unit <- guard(occurrence_shape(value))
    reference : I.LocalReference <- local(J.field(value,"local_reference"))
    return I.Resolved{header(J.field(value,"capture")),G.number(J.field(value,"record")),G.number(J.field(value,"offset")),
      G.number(J.field(value,"length")),J.get(value,"raw_sha256"),G.number(J.field(value,"reference")),J.get(value,"json_path"),J.get(value,"attachment_kind"),reference}
def receipt_valid(valid: Bool,value: T.Receipt) -> Result<&2,&2,String,T.Receipt>:
  match valid:
    case True{}: Done{value}
    case False{}: Fail{message()}
def receipt_shape(+value: J.Json) -> Bool:
  Shape.exact_object(value,["occurrence","root","observed_at_ms","time_unit","semantics","count","chunks","sha256","commitment"]) &&
    G.bounded(J.field(value,"observed_at_ms"),19) && Shape.text_is(J.field(value,"time_unit"),"unix_milliseconds") &&
    Shape.text_is(J.field(value,"semantics"),T.semantics()) && G.numeric(J.field(value,"count")) && G.numeric(J.field(value,"chunks")) &&
    G.bounded(J.field(value,"sha256"),64) && G.bounded(J.field(value,"commitment"),64)
def receipt(+value: J.Json) -> Result<&2,&2,String,T.Receipt>:
  do Result<&2,&2,String,T.Receipt>:
    _ : Unit <- guard(receipt_shape(value))
    identity : I.Resolved <- occurrence(J.field(value,"occurrence"))
    chosen : T.RootEvidence <- root(J.field(value,"root"))
    +result : T.Receipt = T.Receipt{identity,chosen,J.get(value,"observed_at_ms"),G.number(J.field(value,"count")),G.number(J.field(value,"chunks")),J.get(value,"sha256"),J.get(value,"commitment")}
    receipt_valid(T.receipt_valid(result),result)
def asset_shape(state: String,+value: J.Json) -> Bool:
  match state:
    case "captured": Shape.exact_object(value,["kind","profile","state","receipt"])
    case "already_captured": Shape.exact_object(value,["kind","profile","state","receipt"])
    case "retained": Shape.exact_object(value,["kind","profile","state","receipt"])
    case "exported": Shape.exact_object(value,["kind","profile","state","receipt","destination"]) && G.bounded(J.field(value,"destination"),4096) && Command.export_path(J.get(value,"destination"))
    case _: False{}
def destination(state: String,value: J.Json) -> Maybe<&2,String>:
  match state:
    case "exported": Some{J.get(value,"destination")}
    case _: None{}
def asset(+value: J.Json) -> Result<&2,&2,String,Asset>:
  do Result<&2,&2,String,Asset>:
    _ : Unit <- guard(Shape.text_is(J.field(value,"kind"),"attachment_asset") && Shape.text_is(J.field(value,"profile"),T.profile()) && asset_shape(J.get(value,"state"),value))
    owned : T.Receipt <- receipt(J.field(value,"receipt"))
    return Asset{J.get(value,"state"),owned,destination(J.get(value,"state"),value)}
def root_ack(+value: J.Json,operation: String) -> Result<&2,&2,String,T.RootEvidence>:
  do Result<&2,&2,String,T.RootEvidence>:
    _ : Unit <- guard(Shape.exact_object(value,["kind","profile","operation","root"]) && Shape.text_is(J.field(value,"kind"),"attachment_root") &&
      Shape.text_is(J.field(value,"profile"),"explicit-attachment-roots-v1") && Shape.text_is(J.field(value,"operation"),operation))
    root(J.field(value,"root"))
def roots(values: List<&2,J.Json>,after: String) -> Result<&2,&2,String,List<&2,T.RootEvidence>>:
  match values:
    case []: Done{[]}
    case +value <> rest:
      do Result<&2,&2,String,List<&2,T.RootEvidence>>:
        chosen : T.RootEvidence <- root(value)
        _ : Unit <- guard(Cmp.is_gt(Numeric.decimal_compare(J.get(value,"id"),after)))
        rows : List<&2,T.RootEvidence> <- roots(rest,J.get(value,"id"))
        return chosen <> rows
def cursor(value: J.Json) -> Result<&2,&2,String,Maybe<&2,String>>:
  match value:
    case J.JNull{}: Done{None{}}
    case J.JString{+text}:
      do Result<&2,&2,String,Maybe<&2,String>>:
        _ : Unit <- guard(Rules.identity(text))
        return Some{text}
    case _: Fail{message()}
def last_root(rows: List<&2,T.RootEvidence>,last: String) -> String:
  match rows:
    case []: last
    case T.RootEvidence{id,_,_,_} <> rest: last_root(rest,id)
def next_valid(next: Maybe<&2,String>,+rows: List<&2,T.RootEvidence>,count: U32) -> Bool:
  match next:
    case None{}: True{}
    case Some{value}: Nat.is_eq(List.length(&2,T.RootEvidence,rows),U32.to_nat(count)) && String.eq(value,last_root(rows,""))
def page(+value: J.Json,+after: String,+count: U32) -> Result<&2,&2,String,RootPage>:
  do Result<&2,&2,String,RootPage>:
    _ : Unit <- guard(Shape.exact_object(value,["kind","profile","after","requested","next","roots"]) &&
      Shape.text_is(J.field(value,"kind"),"attachment_roots") && Shape.text_is(J.field(value,"profile"),"explicit-attachment-roots-v1") &&
      Shape.text_is(J.field(value,"after"),after) && (String.eq(after,"0") || Rules.identity(after)) && U32.is_gt(count,0) && U32.is_le(count,40) &&
      Shape.number_is(J.field(value,"requested"),U32.show(count)) && G.array(J.field(value,"roots")) && U32.is_le(G.size(J.field(value,"roots")),count))
    +rows : List<&2,T.RootEvidence> <- roots(J.items(J.field(value,"roots")),after)
    +next : Maybe<&2,String> <- cursor(J.field(value,"next"))
    _ : Unit <- guard(next_valid(next,rows,count))
    return RootPage{after,count,rows,next}
def error_valid(+value: J.Json) -> Bool:
  Shape.exact_object(value,["kind","profile","phase","code","message","mutation"]) &&
    Shape.text_is(J.field(value,"kind"),"attachment_capture_error") && Shape.text_is(J.field(value,"profile"),"attachment-capture-cli-v1") &&
    G.bounded(J.field(value,"phase"),64) && G.bounded(J.field(value,"code"),128) && G.bounded(J.field(value,"message"),2048) &&
    (Shape.text_is(J.field(value,"mutation"),"not_attempted") || Shape.text_is(J.field(value,"mutation"),"capture_uncertain") ||
     Shape.text_is(J.field(value,"mutation"),"root_mutation_uncertain") || Shape.text_is(J.field(value,"mutation"),"export_uncertain"))
def parsed_error(value: Result<&2,&2,String,J.Json>) -> Result<&2,&2,String,J.Json>:
  match value:
    case Fail{_}: Fail{message()}
    case Done{+value}:
      do Result<&2,&2,String,J.Json>:
        _ : Unit <- guard(error_valid(value))
        return value
def completed_status(code: U32,+out: String,+err: String) -> Result<&2,&2,String,J.Json>:
  match code:
    case 0:
      do Result<&2,&2,String,J.Json>:
        _ : Unit <- guard(String.is_empty(err))
        J.parse(out)
    case 2:
      do Result<&2,&2,String,J.Json>:
        _ : Unit <- guard(String.is_empty(out))
        parsed_error(J.parse(err))
    case _: Fail{"Attachment command ended without a confirmed acknowledgement"}
def completed(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,String,J.Json>:
  match value:
    case Fail{_}: Fail{"Attachment command could not complete"}
    case Done{(code,(out,err))}: completed_status(code,out,err)
