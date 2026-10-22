import Base
import ./json.bend as J
import ./gui_attachments.bend as G
import ./attachment_capture_ack.bend as Ack
import ./attachment_asset_types.bend as T
import ./attachment_root_rules.bend as Rules

type Model is Data:
  Model{after: String,previous: List<&2,String>,page: Maybe<&2,Ack.RootPage>,selected: U32,
    phase: U32,nonce: U32,request: List<&2,String>,message: String}
def initial() -> Model: Model{"0",[],None{},0,0,0,[],""}
def phase(model: Model) -> U32:
  Model{_,_,_,_,phase,_,_,_} = model
  phase
def nonce(model: Model) -> U32:
  Model{_,_,_,_,_,nonce,_,_} = model
  nonce
def request(model: Model) -> List<&2,String>:
  Model{_,_,_,_,_,_,request,_} = model
  request
def args(after: String) -> List<&2,String>: ["attachment-roots",after,"40"]
def load(model: Model,nonce: U32) -> Model:
  Model{+after,previous,page,selected,_,_,_,_} = model
  Model{after,previous,page,selected,1,nonce,args(after),""}
def fail(model: Model,message: String) -> Model:
  Model{after,previous,_,_,_,nonce,_,_} = model
  Model{after,previous,None{},0,2,nonce,[],message}
def loaded(+model: Model,result: Result<&2,&2,String,Ack.RootPage>) -> Model:
  Model{after,previous,_,_,_,nonce,_,_} = model
  match result:
    case Fail{message}: fail(model,message)
    case Done{page}:
      Model{after,previous,Some{page},0,2,nonce,[],"Select an enabled folder to authorize a future capture. Existing retained assets remain available when folders are disabled."}
def response(+model: Model,result: Result<&2,&2,String,J.Json>) -> Model:
  Model{after,_,_,_,_,_,_,_} = model
  match result:
    case Fail{message}: fail(model,message)
    case Done{value}: loaded(model,Ack.page(value,after,40))
def rows_page(value: Maybe<&2,Ack.RootPage>) -> List<&2,T.RootEvidence>:
  match value:
    case None{}: []
    case Some{Ack.RootPage{_,_,rows,_}}: rows
def rows(model: Model) -> List<&2,T.RootEvidence>:
  Model{_,_,page,_,_,_,_,_} = model
  rows_page(page)
def item(values: List<&2,T.RootEvidence>,index: Nat) -> Maybe<&2,T.RootEvidence>:
  match values index:
    case [] _: None{}
    case value <> _ 0n: Some{value}
    case _ <> rest 1n+left: item(rest,left)
def selected(+model: Model) -> Maybe<&2,T.RootEvidence>:
  Model{_,_,_,index,_,_,_,_} = model
  item(rows(model),U32.to_nat(index))
def selected_index(model: Model) -> U32:
  Model{_,_,_,index,_,_,_,_} = model
  index
def select_valid(valid: Bool,model: Model,index: U32) -> Model:
  match valid:
    case False{}: model
    case True{}:
      Model{after,previous,page,_,phase,nonce,request,message} = model
      Model{after,previous,page,index,phase,nonce,request,message}
def select(+model: Model,+index: U32) -> Model:
  select_valid(U32.is_eq(phase(model),2) && Maybe.is_some(&2,T.RootEvidence,item(rows(model),U32.to_nat(index))),model,index)
def enabled(value: Maybe<&2,T.RootEvidence>) -> Bool:
  match value:
    case Some{T.RootEvidence{_,_,_,enabled}}: enabled
    case None{}: False{}
def can_choose(+model: Model) -> Bool: U32.is_eq(phase(model),2) && enabled(selected(model))
def can_enable(+model: Model) -> Bool:
  U32.is_eq(phase(model),2) && Maybe.is_some(&2,T.RootEvidence,selected(model)) && Bool.not(enabled(selected(model)))
def can_disable(+model: Model) -> Bool: can_choose(model)
def next_page(value: Maybe<&2,Ack.RootPage>) -> Maybe<&2,String>:
  match value:
    case None{}: None{}
    case Some{Ack.RootPage{_,_,_,next}}: next
def next(+model: Model) -> Bool:
  Model{_,_,page,_,_,_,_,_} = model
  U32.is_eq(phase(model),2) && Maybe.is_some(&2,String,next_page(page))
def previous(+model: Model) -> Bool:
  Model{_,history,_,_,_,_,_,_} = model
  U32.is_eq(phase(model),2) && Nat.is_gt(List.length(&2,String,history),0n)
def advance_next(+model: Model,value: Maybe<&2,String>) -> Model:
  Model{prior,history,_,_,_,nonce,_,_} = model
  match value:
    case None{}: model
    case Some{after}:
      Model{after,prior <> history,None{},0,0,nonce,[],""}
def advance_previous(+model: Model,history: List<&2,String>) -> Model:
  Model{_,_,_,_,_,nonce,_,_} = model
  match history:
    case []: model
    case after <> rest:
      Model{after,rest,None{},0,0,nonce,[],""}
def advance(+model: Model,forward: Bool) -> Model:
  Model{_,history,page,_,_,_,_,_} = model
  match forward:
    case True{}: advance_next(model,next_page(page))
    case False{}: advance_previous(model,history)
def writing(model: Model,nonce: U32,args: List<&2,String>) -> Model:
  Model{after,previous,page,selected,_,_,_,_} = model
  Model{after,previous,page,selected,3,nonce,args,"Updating the explicit folder policy…"}
def root_title(value: T.RootEvidence) -> String:
  T.RootEvidence{_,path,_,enabled} = value
  Bool.pick(String,enabled,"Enabled · ","Disabled · ") ++ G.shown(path)
def titles(values: List<&2,T.RootEvidence>) -> List<&2,String>:
  match values:
    case []: []
    case value <> rest: root_title(value) <> titles(rest)
def root_text(value: Maybe<&2,T.RootEvidence>) -> String:
  match value:
    case None{}: "No folder selected. Enter an absolute folder path above, then Add folder."
    case Some{T.RootEvidence{id,path,revision,enabled}}:
      G.shown(path) ++ "\n\n" ++ Bool.pick(String,enabled,"Enabled for an explicitly selected file capture.","Disabled. New reads and publication are blocked.") ++
      "\nFolder ID " ++ id ++ " · revision " ++ revision ++
      "\n\nUse folder selects this exact policy revision for the attachment you were viewing.\nDisabling never removes previously retained assets."
def text(+model: Model) -> String:
  Model{_,_,_,_,_,_,_,message} = model
  "Capture folders\n\nOnly explicitly chosen folders authorize a new local attachment read. Nothing is scanned here. Remote URLs are never fetched.\n\n" ++
    root_text(selected(model)) ++ "\n\n" ++ G.shown(message)
