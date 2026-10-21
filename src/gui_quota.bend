# Pure Connections protocol/state. No filesystem, process, account or config IO.
import Base
import ./json.bend as J
import ./gui_settings.bend as Shape
import ./claude_quota.bend as Q
import ./quota_store.bend as S
import ./quota_cli.bend as C

type Operation is Data:
  Status{}
  Enable{}
  Disconnect{}
  History{offset: U32}

type Request is Data:
  Request{token: String,root: String,operation: Operation,minimum_epoch: Nat}

# phase0 unacknowledged,1 pending,2 acknowledged,3 unavailable.
# view0 summary,1 sampled history,2 reviewed manual setup.
type Model is Data:
  Model{root: String,phase: U32,ack: Maybe<&2,S.State>,current: Maybe<&2,S.Sample>,
    history: List<&2,S.Sample>,offset: U32,more: Bool,view: U32,selected: U32,
    pending: Maybe<&2,Request>,notice: String}

def invalid(-A: Data) -> Result<&2,&2,String,A>:
  Fail{"Quota reply did not match the complete requested protocol. Refresh to inspect acknowledged state."}

def guard(ok: Bool) -> Result<&2,&2,String,Unit>:
  S.branch(Result<&2,&2,String,Unit>,ok,_ => Done{Unit{}},_ => invalid(Unit))

def from_maybe(-A: Data,value: Maybe<&2,A>) -> Result<&2,&2,String,A>:
  match value:
    case None{}: invalid(A)
    case Some{value}: Done{value}

def time_max() -> Nat:
  Nat.add(Nat.mul(253n,1000000000n),402300799n)

def string_nat(value: J.Json,maximum: Nat) -> Result<&2,&2,String,Nat>:
  match value:
    case J.JString{text}: from_maybe(Nat,S.natural(text,maximum))
    case _: invalid(Nat)

def boolean(value: J.Json) -> Result<&2,&2,String,Bool>:
  match value:
    case J.JBool{flag}: Done{flag}
    case _: invalid(Bool)

def used_value(value: J.Json) -> Result<&2,&2,String,Maybe<&2,U32>>:
  match value:
    case J.JNull{}: Done{None{}}
    case J.JNumber{text}:
      do Result<&2,&2,String,Maybe<&2,U32>>:
        n : Nat <- from_maybe(Nat,S.natural(text,100000000n))
        return Some{U32.from_nat(n)}
    case _: invalid(Maybe<&2,U32>)

def reset_value(value: J.Json) -> Result<&2,&2,String,Maybe<&2,Nat>>:
  match value:
    case J.JNull{}: Done{None{}}
    case other:
      do Result<&2,&2,String,Maybe<&2,Nat>>:
        n : Nat <- string_nat(other,time_max())
        return Some{n}

def window(value: J.Json) -> Result<&2,&2,String,Maybe<&2,Q.QuotaWindow>>:
  match value:
    case J.JNull{}: Done{None{}}
    case +other:
      do Result<&2,&2,String,Maybe<&2,Q.QuotaWindow>>:
        Unit <- guard(Shape.exact_object(other,["used_millionths","resets_at"]))
        used : Maybe<&2,U32> <- used_value(J.field(other,"used_millionths"))
        reset : Maybe<&2,Nat> <- reset_value(J.field(other,"resets_at"))
        return Some{Q.QuotaWindow{used,reset}}

def sample(+value: J.Json,+epoch: Nat) -> Result<&2,&2,String,S.Sample>:
  do Result<&2,&2,String,S.Sample>:
    Unit <- guard(Shape.exact_object(value,["sequence","epoch","received_at","parser","five_hour","seven_day"]) &&
      Shape.text_is(J.field(value,"parser"),S.policy()))
    +sequence : Nat <- string_nat(J.field(value,"sequence"),S.cap())
    +sample_epoch : Nat <- string_nat(J.field(value,"epoch"),S.cap())
    receipt : Nat <- string_nat(J.field(value,"received_at"),time_max())
    Unit <- guard(Nat.is_gt(sequence,0n) && Nat.is_gt(sample_epoch,0n) && Nat.is_le(sample_epoch,epoch))
    +five : Maybe<&2,Q.QuotaWindow> <- window(J.field(value,"five_hour"))
    +seven : Maybe<&2,Q.QuotaWindow> <- window(J.field(value,"seven_day"))
    Unit <- guard(Bool.not(Q.empty(Q.Observation{five,seven})))
    return S.Sample{sequence,sample_epoch,receipt,Q.Observation{five,seven}}

def sequence(value: S.Sample) -> Nat:
  S.Sample{n,_,_,_} = value
  n

def sample_epoch(value: S.Sample) -> Nat:
  S.Sample{_,n,_,_} = value
  n

def ordered(prior: Maybe<&2,Nat>,current: Nat) -> Bool:
  match prior:
    case None{}: True{}
    case Some{prior}: Nat.is_lt(current,prior)

def samples(values: List<&2,J.Json>,fuel: Nat,+epoch: Nat,prior: Maybe<&2,Nat>,prior_epoch: Nat) -> Result<&2,&2,String,List<&2,S.Sample>>:
  match values fuel:
    case [] _: Done{[]}
    case _ 0n: invalid(List<&2,S.Sample>)
    case value <> rest 1n+n:
      do Result<&2,&2,String,List<&2,S.Sample>>:
        +item : S.Sample <- sample(value,epoch)
        Unit <- guard(ordered(prior,sequence(item)) && Nat.is_le(sample_epoch(item),prior_epoch))
        tail : List<&2,S.Sample> <- samples(rest,n,epoch,Some{sequence(item)},sample_epoch(item))
        return item <> tail

def array(value: J.Json,+epoch: Nat) -> Result<&2,&2,String,List<&2,S.Sample>>:
  match value:
    case J.JArray{values}: samples(values,40n,epoch,None{},epoch)
    case _: invalid(List<&2,S.Sample>)

def single_current(values: List<&2,S.Sample>,epoch: Nat) -> Bool:
  match values:
    case []: True{}
    case [value]: Nat.is_eq(sample_epoch(value),epoch)
    case _: False{}

def operation_name(operation: Operation) -> String:
  match operation:
    case Status{}: "status"
    case Enable{}: "enabled"
    case Disconnect{}: "disconnected"
    case History{_}: "history"

def valid_result(operation: Operation,+minimum: Nat,+epoch: Nat,+enabled: Bool,+values: List<&2,S.Sample>,more: Bool) -> Bool:
  match operation:
    case Status{}: Nat.is_ge(epoch,minimum) && single_current(values,epoch) && Bool.not(more)
    case Enable{}: enabled && Nat.is_gt(epoch,minimum) && List.is_empty(&2,S.Sample,values) && Bool.not(more)
    case Disconnect{}: Bool.not(enabled) && Nat.is_eq(epoch,minimum) && List.is_empty(&2,S.Sample,values) && Bool.not(more)
    case History{+offset}: U32.is_le(offset,32768) && Nat.is_ge(epoch,minimum) &&
      Nat.is_le(Nat.add(U32.to_nat(offset),List.length(&2,S.Sample,values)),32768n) &&
      (Bool.not(more) || (Nat.is_eq(List.length(&2,S.Sample,values),40n) &&
        Nat.is_lt(Nat.add(U32.to_nat(offset),List.length(&2,S.Sample,values)),32768n)))

def success(+value: J.Json,+operation: Operation,+minimum: Nat) -> Result<&2,&2,String,S.View>:
  do Result<&2,&2,String,S.View>:
    Unit <- guard(Shape.exact_object(value,["kind","outcome","enabled","epoch","samples","more"]) &&
      Shape.text_is(J.field(value,"kind"),C.protocol()) && Shape.text_is(J.field(value,"outcome"),operation_name(operation)))
    +epoch : Nat <- string_nat(J.field(value,"epoch"),S.cap())
    +enabled : Bool <- boolean(J.field(value,"enabled"))
    +more : Bool <- boolean(J.field(value,"more"))
    +values : List<&2,S.Sample> <- array(J.field(value,"samples"),epoch)
    Unit <- guard((Nat.is_gt(epoch,0n) || (Bool.not(enabled) && List.is_empty(&2,S.Sample,values))) &&
      valid_result(operation,minimum,epoch,enabled,values,more))
    return S.View{S.State{epoch,enabled},values,more,operation_name(operation)}

def bounded(value: J.Json,budget: U32) -> Bool:
  match value:
    case J.JString{+text}: Bool.not(String.is_empty(text)) && Maybe.is_some(&2,U32,Q.consume(text,budget)) && Bool.not(String.contains(text,"\0"))
    case _: False{}

def failure_text(code: String) -> String:
  match code:
    case "quota_root": "Choose an existing data directory owned by this user with private 0700 permissions. No directory was created."
    case "quota_file": "Quota storage has unexpected ownership, permissions or file links. It was not repaired."
    case "quota_acl": "Quota storage grants access through a macOS ACL. It was not repaired."
    case "quota_orphan": "Quota sidecars exist without their database. They were left untouched."
    case "quota_epoch_retired": "This connection epoch is retired. Refresh to inspect the current local state."
    case _: "Local quota request was not confirmed. Refresh before making another change or copying setup."

def failure(+value: J.Json) -> Result<&2,&2,String,S.View>:
  do Result<&2,&2,String,S.View>:
    Unit <- guard(Shape.exact_object(value,["kind","outcome","code","message"]) &&
      Shape.text_is(J.field(value,"kind"),C.protocol()) && Shape.text_is(J.field(value,"outcome"),"error") &&
      bounded(J.field(value,"code"),128) && bounded(J.field(value,"message"),8192))
    Fail{failure_text(J.get(value,"code"))}

def decode_kind(value: J.Json,operation: Operation,minimum: Nat,error: Bool) -> Result<&2,&2,String,S.View>:
  match error:
    case True{}: failure(value)
    case False{}: success(value,operation,minimum)

def decode(+value: J.Json,operation: Operation,minimum: Nat) -> Result<&2,&2,String,S.View>:
  decode_kind(value,operation,minimum,Shape.text_is(J.field(value,"outcome"),"error"))

def initial(root: String) -> Model:
  Model{root,0,None{},None{},[],0,False{},0,0,None{},"Local collection state has not been read. Refresh inspects only this selected data directory."}

def root(model: Model) -> String:
  Model{root,_,_,_,_,_,_,_,_,_,_} = model
  root

def phase(model: Model) -> U32:
  Model{_,phase,_,_,_,_,_,_,_,_,_} = model
  phase

def epoch_state(value: Maybe<&2,S.State>) -> Nat:
  match value:
    case None{}: 0n
    case Some{S.State{epoch,_}}: epoch

def epoch(model: Model) -> Nat:
  Model{_,_,ack,_,_,_,_,_,_,_,_} = model
  epoch_state(ack)

def enabled_state(value: Maybe<&2,S.State>) -> Bool:
  match value:
    case None{}: False{}
    case Some{S.State{_,enabled}}: enabled

def enabled(model: Model) -> Bool:
  Model{_,_,ack,_,_,_,_,_,_,_,_} = model
  enabled_state(ack)

def acknowledged(model: Model) -> Bool:
  Model{_,_,ack,_,_,_,_,_,_,_,_} = model
  Maybe.is_some(&2,S.State,ack)

def view(model: Model) -> U32:
  Model{_,_,_,_,_,_,_,view,_,_,_} = model
  view

def offset(model: Model) -> U32:
  Model{_,_,_,_,_,offset,_,_,_,_,_} = model
  offset

def more(model: Model) -> Bool:
  Model{_,_,_,_,_,_,more,_,_,_,_} = model
  more

def notice(model: Model) -> String:
  Model{_,_,_,_,_,_,_,_,_,_,notice} = model
  notice

def same_operation(a: Operation,b: Operation) -> Bool:
  match a b:
    case Status{} Status{}: True{}
    case Enable{} Enable{}: True{}
    case Disconnect{} Disconnect{}: True{}
    case History{a} History{b}: U32.is_eq(a,b)
    case _ _: False{}

def same_request(a: Request,b: Request) -> Bool:
  Request{at,ar,ao,ae} = a
  Request{bt,br,bo,be} = b
  String.eq(at,bt) && String.eq(ar,br) && same_operation(ao,bo) && Nat.is_eq(ae,be)

def pending_matches(value: Maybe<&2,Request>,request: Request) -> Bool:
  match value:
    case None{}: False{}
    case Some{prior}: same_request(prior,request)

def matches(model: Model,+request: Request) -> Bool:
  Model{root,phase,_,_,_,_,_,_,_,pending,_} = model
  Request{_,selected,_,_} = request
  U32.is_eq(phase,1) && String.eq(root,selected) && pending_matches(pending,request)

def ready(+model: Model) -> Bool:
  U32.is_eq(phase(model),2) && acknowledged(model)

def can_enable(+model: Model) -> Bool:
  ready(model) && Bool.not(enabled(model))

def can_disconnect(+model: Model) -> Bool:
  ready(model) && enabled(model)

def can_setup(+model: Model) -> Bool:
  ready(model) && enabled(model) && Nat.is_gt(epoch(model),0n) && C.path(root(model))

def can_copy(+model: Model) -> Bool:
  can_setup(model) && U32.is_eq(view(model),2)

def begin_unchecked(model: Model,request: Request) -> Model:
  Model{root,_,ack,current,history,offset,more,view,selected,_,_} = model
  Model{root,1,ack,current,history,offset,more,view,selected,Some{request},"Reading local quota state; receipt time is not provider freshness."}

def failed(model: Model,message: String) -> Model:
  Model{root,_,ack,current,history,offset,more,view,selected,_,_} = model
  Model{root,3,ack,current,history,offset,more,view,selected,None{},message}

def first(values: List<&2,S.Sample>) -> Maybe<&2,S.Sample>:
  match values:
    case []: None{}
    case value <> _: Some{value}

def keep_current(value: Maybe<&2,S.Sample>,epoch: Nat) -> Maybe<&2,S.Sample>:
  match value:
    case None{}: None{}
    case Some{+value}: Bool.pick(Maybe<&2,S.Sample>,Nat.is_eq(sample_epoch(value),epoch),Some{value},None{})

def applied(model: Model,response: S.View,operation: Operation) -> Model:
  Model{root,_,_,current,history,offset,more,view,selected,_,_} = model
  S.View{+state,values,next,outcome} = response
  S.State{epoch,enabled} = state
  match operation:
    case Status{}: Model{root,2,Some{state},first(values),history,offset,more,0,0,None{},"Local state loaded. No account or subscription identity was queried."}
    case Enable{}: Model{root,2,Some{state},None{},history,offset,more,0,0,None{},"Collection enabled locally. Review manual setup; no provider settings were changed."}
    case Disconnect{}: Model{root,2,Some{state},keep_current(current,epoch),history,offset,more,0,0,None{},"Collection off. Retained observations remain history; remove manual provider setup separately."}
    case History{offset}: Model{root,2,Some{state},keep_current(current,epoch),values,offset,next,1,0,None{},"Sampled local history loaded. New observations can shift offset pages."}

def decoded(model: Model,operation: Operation,result: Result<&2,&2,String,S.View>) -> Model:
  match result:
    case Fail{message}: failed(model,message)
    case Done{response}: applied(model,response,operation)

def received(model: Model,request: Request,result: Result<&2,&2,String,J.Json>) -> Model:
  Request{_,_,+operation,minimum} = request
  match result:
    case Fail{_}: failed(model,"Local quota worker did not complete. A change may have committed; Refresh to inspect state.")
    case Done{value}: decoded(model,operation,decode(value,operation,minimum))

def apply_if(model: Model,request: Request,result: Result<&2,&2,String,J.Json>,current: Bool) -> Model:
  match current:
    case False{}: model
    case True{}: received(model,request,result)

def apply(+model: Model,+request: Request,result: Result<&2,&2,String,J.Json>) -> Model:
  apply_if(model,request,result,matches(model,request))

def edit_if(model: Model,root: String,same: Bool) -> Model:
  match same:
    case True{}: model
    case False{}: initial(root)

def edit(+model: Model,+next: String) -> Model:
  edit_if(model,next,String.eq(root(model),next))

def setup_view(model: Model) -> Model:
  Model{root,phase,ack,current,history,offset,more,_,selected,pending,notice} = model
  Model{root,phase,ack,current,history,offset,more,2,selected,pending,notice}

def setup(+model: Model,program: String) -> C.result_type():
  S.branch(C.result_type(),can_setup(model),_ => C.setup(program,root(model),epoch(model)),
    _ => Fail{Q.Failure{"quota_setup","Refresh an enabled connection before reviewing manual setup"}})

def selected(model: Model,+index: U32) -> Model:
  Model{root,phase,ack,current,+history,offset,more,+view,prior,pending,notice} = model
  Model{root,phase,ack,current,history,offset,more,view,
    Bool.pick(U32,U32.is_eq(view,1) && U32.is_lt(index,U32.from_nat(List.length(&2,S.Sample,history))),index,prior),pending,notice}

def is_write(operation: Operation) -> Bool:
  match operation:
    case Enable{}: True{}
    case Disconnect{}: True{}
    case _: False{}

def operation_args(operation: Operation) -> List<&2,String>:
  match operation:
    case Status{}: ["status"]
    case Enable{}: ["enable"]
    case Disconnect{}: ["disconnect"]
    case History{offset}: ["history",U32.show(offset)]


def request_allowed(+model: Model,operation: Operation) -> Bool:
  match operation:
    case Status{}: Bool.not(U32.is_eq(phase(model),1))
    case Enable{}: can_enable(model)
    case Disconnect{}: can_disconnect(model)
    case History{offset}: ready(model) && U32.is_le(offset,32768)

def request_valid(+model: Model,request: Request) -> Bool:
  Request{+token,+selected_root,operation,minimum} = request
  Maybe.is_some(&2,Nat,S.natural(token,S.cap())) && Bool.not(String.eq(token,"0")) && String.eq(selected_root,root(model)) &&
    C.path(selected_root) && Nat.is_eq(minimum,epoch(model)) && request_allowed(model,operation)

def begin_if(model: Model,request: Request,valid: Bool) -> Model:
  match valid:
    case True{}: begin_unchecked(model,request)
    case False{}: model

def begin(+model: Model,+request: Request) -> Model:
  begin_if(model,request,request_valid(model,request))

def pending(model: Model) -> Maybe<&2,Request>:
  Model{_,_,_,_,_,_,_,_,_,pending,_} = model
  pending

def selected_index(model: Model) -> U32:
  Model{_,_,_,_,_,_,_,_,selected,_,_} = model
  selected

def history(model: Model) -> List<&2,S.Sample>:
  Model{_,_,_,_,history,_,_,_,_,_,_} = model
  history

def args(request: Request) -> List<&2,String>:
  Request{token,root,operation,minimum} = request
  List.append(&2,String,["quota-view",root,token,Nat.show(minimum)],operation_args(operation))

# Both success stdout and failure stderr carry closed JSON. Never expose child
# diagnostics or accept an error envelope on the success exit channel.
def transport_json(+raw: String,error: Bool,quiet: Bool) -> Result<&2,&2,String,J.Json>:
  do Result<&2,&2,String,J.Json>:
    Unit <- guard(quiet && Maybe.is_some(&2,U32,Q.consume(raw,131072)))
    +value : J.Json <- J.parse(raw)
    Unit <- guard(Bool.not(Bool.xor(error,Shape.text_is(J.field(value,"outcome"),"error"))))
    return value

def transport_exit(code: U32,out: String,err: String) -> Result<&2,&2,String,J.Json>:
  match code:
    case 0: transport_json(out,False{},String.is_empty(err))
    case 2: transport_json(err,True{},String.is_empty(out))
    case _: invalid(J.Json)

def completed(value: Result<&1,&1,U32 & String,U32 & (String & String)>) -> Result<&2,&2,String,J.Json>:
  match value:
    case Fail{_}: invalid(J.Json)
    case Done{(code,(out,err))}: transport_exit(code,out,err)

def percentage(value: Maybe<&2,U32>) -> String:
  match value:
    case None{}: "unknown"
    case Some{+n}: U32.show(U32.div(n,1000000)) ++ "." ++
      String.drop(U32.show(U32.add(1000000,U32.mod(n,1000000))),1n) ++ "% used"

def reset_text(value: Maybe<&2,Nat>) -> String:
  match value:
    case None{}: "unknown"
    case Some{n}: Nat.show(n) ++ " Unix seconds (provider field)"

def window_text(value: Maybe<&2,Q.QuotaWindow>,name: String) -> String:
  match value:
    case None{}: name ++ ": not supplied\n"
    case Some{Q.QuotaWindow{used,reset}}:
      name ++ ": " ++ percentage(used) ++ "\nReset: " ++ reset_text(reset) ++ "\n"

def observation_text(value: S.Sample) -> String:
  S.Sample{seq,epoch,receipt,Q.Observation{five,seven}} = value
  window_text(five,"Five-hour window") ++ "\n" ++ window_text(seven,"Seven-day window") ++
  "\nLocal receipt: " ++ Nat.show(receipt) ++ " Unix seconds\n" ++
  "Receipt order: " ++ Nat.show(seq) ++ " | connection epoch: " ++ Nat.show(epoch) ++ "\n" ++
  "This is a local receipt, not provider freshness. Device clock changes can reverse receipt times. " ++
  "Account, plan and billing identity were not queried.\n"

def sample_at(values: List<&2,S.Sample>,index: Nat) -> Maybe<&2,S.Sample>:
  match values index:
    case [] _: None{}
    case value <> _ 0n: Some{value}
    case _ <> rest 1n+n: sample_at(rest,n)

def sample_text(value: Maybe<&2,S.Sample>) -> String:
  match value:
    case None{}: "No usable quota fields have been received for this connection epoch. Unknown is different from zero.\n"
    case Some{sample}: observation_text(sample)

def history_text(value: Maybe<&2,S.Sample>) -> String:
  match value:
    case None{}: "No retained samples on this offset page. This does not establish whether another page or epoch contains observations.\n"
    case Some{sample}: observation_text(sample)

def summary_state(ack: Maybe<&2,S.State>,current: Maybe<&2,S.Sample>) -> String:
  match ack:
    case None{}: "Local connection state is not acknowledged. Refresh to inspect this selected directory.\n"
    case Some{S.State{epoch,+enabled}}:
      Bool.pick(String,enabled,"Collection enabled locally","Collection off") ++ " | epoch " ++ Nat.show(epoch) ++ "\n\n" ++
      Bool.pick(String,enabled,"Latest observation in this epoch:\n","Retained observation from this epoch (collection is off):\n") ++ sample_text(current)

def setup_text(value: C.result_type()) -> String:
  match value:
    case Fail{_}: "Refresh an enabled connection before reviewing manual setup."
    case Done{fragment}: "MANUAL SETUP / CLAUDE CODE\n\n" ++
      "Review this fragment before manually merging its statusLine entry into your chosen Claude Code settings. " ++
      "It replaces that status-line command, including any existing keyboard shortcut hints shown there. " ++
      "Juice Bend does not edit provider settings or read credentials.\n\n" ++ fragment ++
      "\n\nCopy setup copies only the exact fragment. Copying does not install it, authenticate an account, or prove a feed was received. " ++
      "The first usable quota feed will appear after Claude Code runs this manually installed status line. " ++
      "Remove it separately when disconnecting. No provider command is run by Juice Bend."

def phase_text(phase: U32) -> String:
  match phase:
    case 1: "REQUEST PENDING. The state and observations below were last acknowledged before this request.\n\n"
    case 3: "LOCAL STATE UNAVAILABLE. A change may have committed. The state and observations below are only the last acknowledgement; Refresh to confirm.\n\n"
    case _: ""

def body_view(+model: Model,program: String,view: U32) -> String:
  Model{root,phase,ack,current,history,offset,more,_,selected,pending,notice} = model
  match view:
    case 2: setup_text(setup(model,program))
    case 1: "SAMPLED LOCAL HISTORY\n\n" ++ history_text(sample_at(history,U32.to_nat(selected))) ++
      "\nHistory survives disconnect. Sequence orders accepted local receipts; it does not establish provider chronology. " ++
      "History retains the latest accepted sample per epoch and five-minute slot. Older receipts are trimmed when a new usable observation arrives, with a hard cap of 32,768 samples. " ++
      "New samples can shift these offset pages.\n"
    case _: "CONNECTIONS / CLAUDE CODE\n\n" ++ summary_state(ack,current) ++
      "\nExplicit local opt-in only. Enable creates a dedicated private quota store in the selected Juice Bend data directory. " ++
      "Then review Manual setup. No provider command, configuration change, credential read, network request or inference occurs here.\n\n" ++
      "Quota observations are separate from captured conversation usage and API-equivalent estimates. " ++
      "They do not identify an account, subscription or billed spend.\n"

def body(+model: Model,program: String) -> String:
  phase_text(phase(model)) ++ body_view(model,program,view(model))

def sample_title(value: S.Sample) -> String:
  S.Sample{seq,epoch,receipt,_} = value
  "Receipt " ++ Nat.show(seq) ++ " | epoch " ++ Nat.show(epoch) ++ "\nLocal " ++ Nat.show(receipt)

def titles(values: List<&2,S.Sample>) -> List<&2,String>:
  match values:
    case []: []
    case value <> rest: sample_title(value) <> titles(rest)

def rows_view(model: Model,view: U32) -> List<&2,String>:
  Model{_,_,_,current,history,_,_,_,_,_,_} = model
  match view:
    case 1: titles(history)
    case _: []

def rows(+model: Model) -> List<&2,String>:
  rows_view(model,view(model))
