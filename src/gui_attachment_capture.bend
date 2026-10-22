import Base
import ./json.bend as J
import ./gui_attachments.bend as G
import ./attachment_capture_ack.bend as Ack
import ./attachment_asset_identity.bend as I
import ./attachment_asset_types.bend as T
import ./attachment_root_policy.bend as Policy
import ./archive_meta.bend as Meta

type Target is Data:
  Target{capture: J.Json,key: G.OccurrenceKey,kind: String,local_kind: String}
type Retained is Data:
  Unknown{}
  Checking{}
  Uncaptured{}
  RetainedReady{receipt: T.Receipt}
  Failed{message: String}
  Capturing{}
type Model is Data:
  Model{inventory: J.Json,target: Maybe<&2,Target>,chosen: Maybe<&2,T.RootEvidence>,retained: Retained,nonce: U32,message: String}
def initial() -> Model: Model{J.JNull{},None{},None{},Unknown{},0,""}
def inventory(model: Model,value: J.Json) -> Model:
  Model{_,_,chosen,_,nonce,_} = model
  Model{value,None{},chosen,Unknown{},nonce,""}
def find(values: List<&2,J.Json>,+field: String,+wanted: String) -> J.Json:
  match values:
    case []: J.JNull{}
    case +value <> rest:
      Bool.pick(J.Json,String.eq(J.get(value,field),wanted),value,find(rest,field,wanted))
def local_kind(+kind: String) -> Bool:
  String.eq(kind,"local_path") || String.eq(kind,"local_file_url")
def target_valid(valid: Bool,value: Target) -> Maybe<&2,Target>:
  match valid:
    case True{}: Some{value}
    case False{}: None{}
def selected(+value: J.Json,+key: G.OccurrenceKey) -> Maybe<&2,Target>:
  G.OccurrenceKey{+record,+reference,+path,+offset,+length,+digest,_,_,_} = key
  +raw = find(J.items(J.field(value,"records")),"record",U32.show(record))
  +item = find(J.items(J.field(raw,"occurrences")),"reference",U32.show(reference))
  +kind = J.get(J.field(item,"descriptor"),"type")
  +header = J.field(value,"capture")
  target_valid(G.capture_valid(header,J.get(header,"snapshot")) && G.record_valid(raw,record,G.number(J.JNumber{J.get(header,"extent")})) &&
    G.occurrence_valid(item,reference) && local_kind(kind) && String.eq(J.get(item,"path"),path) && String.eq(J.get(raw,"digest"),digest) &&
    U32.is_eq(G.number(J.field(raw,"offset")),offset) && U32.is_eq(G.number(J.field(raw,"length")),length),
    Target{J.field(value,"capture"),key,J.get(item,"kind"),kind})
def select_key(model: Model,key: Maybe<&2,G.OccurrenceKey>) -> Model:
  Model{+value,_,chosen,_,nonce,_} = model
  match key:
    case None{}: Model{value,None{},chosen,Unknown{},nonce,""}
    case Some{key}: Model{value,selected(value,key),chosen,Unknown{},nonce,""}
def select(model: Model,attachments: G.Model) -> Model:
  select_key(model,G.key(G.selected(attachments)))
def request(value: Target) -> I.Request:
  Target{capture,G.OccurrenceKey{record,reference,path,_,_,_,_,_,_},_,_} = value
  I.Request{J.get(capture,"snapshot"),record,reference,path}
def args(value: Target) -> List<&2,String>:
  Target{capture,G.OccurrenceKey{record,reference,path,_,_,_,_,_,_},_,_} = value
  [J.get(capture,"snapshot"),U32.show(record),U32.show(reference),path]
def inspect_args(value: Target) -> List<&2,String>: "captured-attachment" <> args(value)
def target(model: Model) -> Maybe<&2,Target>:
  Model{_,target,_,_,_,_} = model
  target
def chosen(model: Model) -> Maybe<&2,T.RootEvidence>:
  Model{_,_,chosen,_,_,_} = model
  chosen
def nonce(model: Model) -> U32:
  Model{_,_,_,_,nonce,_} = model
  nonce
def retained(model: Model) -> Retained:
  Model{_,_,_,value,_,_} = model
  value
def begin(model: Model,nonce: U32,capture: Bool) -> Model:
  Model{inventory,target,chosen,_,_,_} = model
  Model{inventory,target,chosen,Bool.pick(Retained,capture,Capturing{},Checking{}),nonce,""}
def choose(model: Model,root: T.RootEvidence) -> Model:
  Model{inventory,target,_,retained,nonce,message} = model
  Model{inventory,target,Some{root},retained,nonce,message}
def valid_root(value: Maybe<&2,T.RootEvidence>) -> Bool:
  match value:
    case None{}: False{}
    case Some{+root}:
      T.RootEvidence{_,_,_,enabled} = root
      Policy.valid(root) && enabled
def can_capture(model: Model) -> Bool:
  Model{_,target,root,retained,_,_} = model
  match retained:
    case Uncaptured{}: Maybe.is_some(&2,Target,target) && valid_root(root)
    case _: False{}
def can_export(model: Model) -> Bool:
  Model{_,_,_,retained,_,_} = model
  match retained:
    case RetainedReady{receipt}: T.receipt_valid(receipt)
    case _: False{}
def capture_args(target: Target,root: T.RootEvidence) -> List<&2,String>:
  T.RootEvidence{id,_,revision,_} = root
  List.append(&2,String,"capture-attachment" <> args(target),[id,revision])
def same_local(kind: String,local: I.LocalReference) -> Bool:
  match kind local:
    case "local_path" I.LocalPath{_}: True{}
    case "local_file_url" I.LocalFileURL{_}: True{}
    case _ _: False{}
def matches(value: Target,receipt: T.Receipt) -> Bool:
  Target{+capture,G.OccurrenceKey{record,reference,path,offset,length,digest,_,_,_},kind,local_kind} = value
  T.Receipt{I.Resolved{Meta.Header{snapshot,source,generation,provider,locator,extent,records,_,_,_,encoding},actual_record,actual_offset,actual_length,actual_digest,actual_reference,actual_path,actual_kind,local},_,_,_,_,_,_} = receipt
  String.eq(snapshot,J.get(capture,"snapshot")) && String.eq(source,J.get(capture,"source_id")) && String.eq(generation,J.get(capture,"generation")) &&
    String.eq(provider,J.get(capture,"provider")) && String.eq(locator,J.get(capture,"source")) && String.eq(U32.show(extent),J.get(capture,"extent")) &&
    U32.is_eq(records,G.number(J.field(capture,"total_records"))) && String.eq(encoding,J.get(capture,"encoding")) &&
    U32.is_eq(record,actual_record) && U32.is_eq(reference,actual_reference) && String.eq(path,actual_path) && U32.is_eq(offset,actual_offset) &&
    U32.is_eq(length,actual_length) && String.eq(digest,actual_digest) && String.eq(kind,actual_kind) && same_local(local_kind,local)
def set(model: Model,value: Retained,message: String) -> Model:
  Model{inventory,target,chosen,_,nonce,_} = model
  Model{inventory,target,chosen,value,nonce,message}
def accepted(valid: Bool,model: Model,receipt: T.Receipt) -> Model:
  match valid:
    case True{}: set(model,RetainedReady{receipt},"Captured bytes are available from this library. The original file is no longer required.")
    case False{}: set(model,Failed{Ack.message()},Ack.message())
def asset_reply(model: Model,target: Target,value: Result<&2,&2,String,Ack.Asset>,capture: Bool) -> Model:
  match value:
    case Fail{+message}: set(model,Failed{message},message)
    case Done{Ack.Asset{+state,+receipt,destination}}:
      accepted(matches(target,receipt) && Bool.not(Maybe.is_some(&2,String,destination)) &&
        Bool.pick(Bool,capture,String.eq(state,"captured") || String.eq(state,"already_captured"),String.eq(state,"retained")),model,receipt)
def inspected_error(valid: Bool,model: Model,+value: J.Json) -> Model:
  match valid:
    case True{}: set(model,Uncaptured{},"This local reference has not been captured. Choose an enabled folder, then Capture file.")
    case False{}: set(model,Failed{J.get(value,"message")},J.get(value,"message"))
def inspected_error_or_asset(error: Bool,model: Model,target: Target,+value: J.Json) -> Model:
  match error:
    case True{}: inspected_error(String.eq(J.get(value,"phase"),"owned") && String.eq(J.get(value,"code"),"attachment_asset_not_captured") &&
      String.eq(J.get(value,"mutation"),"not_attempted"),model,value)
    case False{}: asset_reply(model,target,Ack.asset(value),False{})
def capture_response(error: Bool,model: Model,target: Target,+value: J.Json) -> Model:
  match error:
    case False{}: asset_reply(model,target,Ack.asset(value),True{})
    case True{}: set(model,Failed{J.get(value,"message")},J.get(value,"code") ++ ": " ++ J.get(value,"message") ++
      " (" ++ J.get(value,"mutation") ++ ")")
def response(model: Model,target: Target,+value: J.Json,capture: Bool) -> Model:
  match capture:
    case False{}:
      inspected_error_or_asset(Ack.error_valid(value),model,target,value)
    case True{}: capture_response(Ack.error_valid(value),model,target,value)
def reply(model: Model,target: Target,result: Result<&2,&2,String,J.Json>,capture: Bool) -> Model:
  match result:
    case Fail{+message}: set(model,Failed{message},message)
    case Done{value}: response(model,target,value,capture)
def apply_target(model: Model,target: Maybe<&2,Target>,state: Retained,result: Result<&2,&2,String,J.Json>) -> Model:
  match target state:
    case Some{target} Checking{}: reply(model,target,result,False{})
    case Some{target} Capturing{}: reply(model,target,result,True{})
    case _ _: model
def apply(+model: Model,result: Result<&2,&2,String,J.Json>) -> Model:
  apply_target(model,target(model),retained(model),result)
def root_text(value: Maybe<&2,T.RootEvidence>) -> String:
  match value:
    case None{}: "No capture folder selected. Choose Folders to add or select one."
    case Some{T.RootEvidence{id,path,revision,enabled}}:
      "Capture folder: " ++ G.shown(path) ++ "\nPolicy " ++ id ++ " revision " ++ revision ++
        Bool.pick(String,enabled," (enabled when selected)"," (disabled)")
def retained_text(value: Retained) -> String:
  match value:
    case Unknown{}: "Select a local attachment reference to inspect retained availability."
    case Checking{}: "Checking captured bytes in this library…"
    case Uncaptured{}: "Not captured. Capture file reads only this exact reference within the selected enabled folder."
    case Capturing{}: "Capturing the selected local file…"
    case Failed{message}: "Availability could not be confirmed. " ++ G.shown(message)
    case RetainedReady{T.Receipt{_,_,time,count,_,digest,_}}:
      "Retained asset · " ++ U32.show(count) ++ " bytes\nObserved at Unix millisecond " ++ time ++
        "\nSHA256: " ++ digest ++ "\nThese are bytes observed at capture time; they do not prove the file's earlier contents."
def text(model: Model) -> String:
  Model{_,_,root,state,_,message} = model
  retained_text(state) ++ "\n\n" ++ root_text(root) ++ "\n\n" ++ G.shown(message)
