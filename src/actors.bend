import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./evidence.bend as Evidence
import ./request_evidence.bend as Request
import ./request_origin.bend as Origin

# Only verified retained records establish actor identity and eligibility.
# These bounds are reported by the file-evidence surface.
type Actor is Data:
  Actor{provider: String,source: String,snapshot: String,session: String,
    repo: String,parent: String,request: String,key: String,blocked: String}

def empty(provider: String,source: String,snapshot: String) -> Actor:
  Actor{provider,source,snapshot,"","","","","",""}

def snapshot(actor: Actor) -> String:
  Actor{_,_,value,_,_,_,_,_,_} = actor
  value

def key(actor: Actor) -> String:
  Actor{_,_,_,_,_,_,_,value,_} = actor
  value

def session(actor: Actor) -> String:
  Actor{_,_,_,value,_,_,_,_,_} = actor
  value

def provider(actor: Actor) -> String:
  Actor{value,_,_,_,_,_,_,_,_} = actor
  value

def parent(actor: Actor) -> String:
  Actor{_,_,_,_,_,value,_,_,_} = actor
  value

def repository(actor: Actor) -> String:
  Actor{_,_,_,_,value,_,_,_,_} = actor
  value

def request_preview(actor: Actor) -> String:
  Actor{_,_,_,_,_,_,value,_,_} = actor
  value

def request_policy() -> String:
  Request.policy()

def scope(+repo: String,actor: Actor) -> Bool:
  Actor{_,_,_,_,+cwd,_,_,_,_} = actor
  String.eq(cwd,repo) || String.starts_with(cwd,repo ++ "/")

def own_eligible(actor: Actor) -> Bool:
  Actor{_,_,_,id,repo,_,request,key,blocked} = actor
  Bool.not(String.is_empty(id)) && Bool.not(String.is_empty(repo)) &&
    Bool.not(String.is_empty(request)) && Bool.not(String.is_empty(key)) &&
    String.is_empty(blocked)

def find_snapshot(actors: List<&2,Actor>,+wanted: String) -> Maybe<&2,Actor>:
  match actors:
    case []:
      None{}
    case +actor <> rest:
      Bool.pick(Maybe<&2,Actor>,String.eq(snapshot(actor),wanted),
        Some{actor},find_snapshot(rest,wanted))

def matching(actors: List<&2,Actor>,+wanted_provider: String,+wanted_id: String,
  +repo: String) -> List<&2,Actor>:
  match actors:
    case []:
      []
    case +actor <> rest:
      +tail = matching(rest,wanted_provider,wanted_id,repo)
      Bool.pick(List<&2,Actor>,String.eq(provider(actor),wanted_provider) &&
        String.eq(session(actor),wanted_id) && scope(repo,actor),actor <> tail,tail)

def single(actors: List<&2,Actor>) -> Maybe<&2,Actor>:
  match actors:
    case actor <> Nil{}:
      Some{actor}
    case _:
      None{}

def parent_actor(+actor: Actor,actors: List<&2,Actor>,repo: String) -> Maybe<&2,Actor>:
  single(matching(actors,provider(actor),parent(actor),repo))

def allowed_parent(value: Maybe<&2,Actor>,next: Actor -> Bool) -> Bool:
  match value:
    case None{}:
      False{}
    case Some{actor}:
      next(actor)

def allowed_step(has_parent: Bool,+actor: Actor,+all: List<&2,Actor>,
  +repo: String,next: Actor -> Bool) -> Bool:
  match has_parent:
    case False{}:
      own_eligible(actor)
    case True{}:
      own_eligible(actor) && allowed_parent(parent_actor(actor,all,repo),next)

def allowed(fuel: Nat,+actor: Actor,+all: List<&2,Actor>,+repo: String) -> Bool:
  match fuel:
    case 0n:
      False{}
    case 1n+rest:
      scope(repo,actor) && allowed_step(Bool.not(String.is_empty(parent(actor))),
        actor,all,repo,p => allowed(rest,p,all,repo))

def negative_origin(+value: String) -> Bool:
  Bool.not(String.is_empty(value)) && Bool.not(String.eq(value,"userWork")) &&
    Bool.not(String.eq(value,"user_work")) && Bool.not(String.eq(value,"external"))

def json_value(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{value}:
      value
    case Fail{_}:
      Json.JNull{}

def decoded_value(result: Result<&2,&2,String,String>) -> Json.Json:
  match result:
    case Done{text}:
      json_value(Json.parse(text))
    case Fail{_}:
      Json.JNull{}

def blocked_header(+raw: Json.Json) -> String:
  +payload = Json.field(raw,"payload")
  +origin = Store.nonempty(Json.get(raw,"origin"),Json.get(payload,"origin"))
  Bool.pick(String,String.eq(Json.get(raw,"excluded"),"true") ||
    String.eq(Json.get(payload,"excluded"),"true") || negative_origin(origin),
    "explicit non-user-work or excluded origin","")

def codex_parent(+raw: Json.Json) -> String:
  +source = Json.field(Json.field(raw,"payload"),"source")
  Json.get(Json.field(Json.field(source,"subagent"),"thread_spawn"),"parent_thread_id")

def header_actor(+raw: Json.Json,actor: Actor) -> Actor:
  Actor{+provider,source,snapshot,session,repo,parent,request,key,blocked} = actor
  +subagent = Json.field(Json.field(Json.field(raw,"payload"),"source"),"subagent")
  +child = codex_parent(raw)
  +unsupported_child = String.eq(provider,"codex") &&
    Bool.not(String.eq(Json.encode(subagent),"null")) && String.is_empty(child)
  Actor{provider,source,snapshot,session,repo,Store.nonempty(child,parent),request,key,
    Store.nonempty(blocked,Store.nonempty(blocked_header(raw),
      Bool.pick(String,unsupported_child,"unsupported or parentless Codex subagent","")))}

def guarded_text(+text: String) -> String:
  Bool.pick(String,String.contains(text,"[juice:benchmark-synthetic:v1]"),
    "synthetic marker or source namespace",
    Bool.pick(String,String.starts_with(text,"## ") || String.starts_with(text,"# Diagnostic") ||
      String.contains(text,"[juice:internal") || String.contains(text,"[juice:scratchpad"),
      "origin requires review: diagnostic-style first request",""))

def request_state(candidate: Bool,provider: String,meta: Origin.MetaFlag,hint: Maybe<&2,String>,
  +event: Providers.Record) -> String & String:
  match candidate:
    case False{}: ("","")
    case True{}:
      Providers.ProviderEvent{_,text,_,_,_,_,_,_,_,_,_,_,_} = event
      +assessment = Request.assess_aligned(provider,meta,hint,event)
      +request = Request.request(assessment)
      (request,Store.nonempty(guarded_text(text),
        Store.nonempty(Request.uncertainty(assessment),guarded_text(request))))

def event_state(state: String & String,r: String,+s: String,record: Evidence.Verified,
  index: U32,actor: Actor) -> Actor:
  (+selected,uncertain) = state
  Actor{provider,source,snapshot,+session,repo,parent,+request,key,blocked} = actor
  +chosen = Bool.not(String.is_empty(selected)) && String.is_empty(request)
  +identity_conflict = Bool.not(String.is_empty(session)) && Bool.not(String.is_empty(s)) &&
    Bool.not(String.eq(session,s))
  Actor{provider,source,snapshot,Store.nonempty(session,s),Store.nonempty(repo,r),parent,
    Bool.pick(String,chosen,String.take(selected,2048n),request),
    Bool.pick(String,chosen,Evidence.citation(record,index),key),
    Store.nonempty(blocked,Store.nonempty(uncertain,
      Bool.pick(String,identity_conflict,"conflicting captured session identities","")))}

def event_actor(+event: Providers.Record,meta: Origin.MetaFlag,hint: Maybe<&2,String>,record: Evidence.Verified,index: U32,
  +actor: Actor) -> Actor:
  Providers.ProviderEvent{role,text,_,_,_,_,r,s,_,_,_,_,_} = event
  event_state(request_state(String.eq(role,"user") && Bool.not(String.is_empty(text)) &&
    String.is_empty(request_preview(actor)),provider(actor),meta,hint,event),r,s,record,index,actor)

def event_scan(events: List<&2,Providers.Record>,hints: List<&2,Maybe<&2,String>>,
  +meta: Origin.MetaFlag,+record: Evidence.Verified,
  +index: U32,actor: Actor) -> Actor:
  match events hints:
    case [] _:
      actor
    case Con{event,rest} Con{hint,tail}:
      event_scan(rest,tail,meta,record,U32.add(index,1),event_actor(event,meta,hint,record,index,actor))
    case Con{event,rest} Nil{}:
      event_scan(rest,[],meta,record,U32.add(index,1),event_actor(event,meta,None{},record,index,actor))

def request_header(+raw: Json.Json,actor: Actor) -> Actor:
  Actor{+provider,source,snapshot,session,repo,parent,+request,key,blocked} = actor
  Actor{provider,source,snapshot,session,repo,parent,request,key,Store.nonempty(blocked,
    Bool.pick(String,String.is_empty(request),Request.frame_issue(provider,raw),""))}

def scanned(+record: Evidence.Verified,+raw: Json.Json,+actor: Actor) -> Actor:
  Evidence.Verified{_,_,_,_,_,_,events} = record
  event_scan(events,Request.texts(provider(actor),raw),Origin.metadata(raw),record,0,
    request_header(raw,header_actor(raw,actor)))

def frame_json(+rows: List<&2,List<&2,Sql.Cell>>) -> Json.Json:
  Bool.pick(Json.Json,String.eq(Store.field(Store.first(rows),6n),"0"),
    decoded_value(Domain.decode(Store.blob(Store.cell(Store.first(rows),5n)))),Json.JNull{})

def scan(fuel: Nat,+db: U32,+snapshot: String,+ordinal: U32,actor: Actor) -> IO(Actor):
  match fuel:
    case 0n:
      IO.pure(Actor,actor)
    case 1n+rest:
      do IO<Actor>:
        +rows : List<&2,List<&2,Sql.Cell>> <- Evidence.record_rows(db,snapshot,ordinal)
        record : Evidence.Verified <- Evidence.verified_row(db,snapshot,ordinal,rows)
        +header : List<&2,Sql.Cell> = Store.first(rows)
        raw : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,Store.field(header,0n),
          Store.number(Store.field(header,1n)),Store.number(Store.field(header,2n)),ordinal)
        scan(rest,db,snapshot,U32.add(ordinal,1),scanned(record,frame_json([raw]),actor))

def child_path(parts: List<&2,String>) -> String:
  match parts:
    case _ <> "subagents" <> parent <> _:
      parent
    case _:
      ""

def leaf(parts: List<&2,String>) -> String:
  match parts:
    case h <> _:
      h
    case _:
      ""

def complete_actor(actor: Actor) -> Actor:
  Actor{+provider,+source,snapshot,+session,repo,parent,+request,key,+blocked} = actor
  +path_parent = Bool.pick(String,String.eq(provider,"claude"),
    child_path(List.reverse(&2,String,String.split(source,'/'))),"")
  +filename = leaf(List.reverse(&2,String,String.split(source,'/')))
  +stem = String.take(filename,Nat.sub(String.length(filename),6n))
  +id = Bool.pick(String,String.is_empty(path_parent),session,path_parent ++ "/" ++ stem)
  +marker = String.contains(request,"[juice:benchmark-synthetic:v1]") ||
    String.starts_with(id,"juice-benchmark-v1-")
  +diagnostic = String.starts_with(request,"## ") || String.starts_with(request,"# Diagnostic") ||
    String.contains(request,"[juice:internal") || String.contains(request,"[juice:scratchpad")
  Actor{provider,source,snapshot,id,repo,Store.nonempty(path_parent,parent),request,key,
    Store.nonempty(blocked,Bool.pick(String,marker,"synthetic marker or source namespace",
      Bool.pick(String,diagnostic,"origin requires review: diagnostic-style first request","")))}

def collect(rows: List<&2,List<&2,Sql.Cell>>,+db: U32) -> IO(List<&2,Actor>):
  match rows:
    case []:
      IO.pure(List<&2,Actor>,[])
    case +row <> rest:
      +snapshot = Store.field(row,0n)
      do IO<List<&2,Actor>>:
        actor : Actor <- scan(U32.to_nat(U32.min(Store.number(Store.field(row,3n)),16)),
          db,snapshot,0,empty(Store.field(row,1n),Store.field(row,2n),snapshot))
        tail : List<&2,Actor> <- collect(rest,db)
        return complete_actor(actor) <> tail

def load(+db: U32) -> IO(List<&2,Actor>):
  do IO<List<&2,Actor>>:
    rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,s.provider,s.locator,p.records FROM snapshots p JOIN generations g ON g.id=p.generation JOIN sources s ON s.id=g.source WHERE p.accepted=1 AND p.id=(SELECT max(x.id) FROM snapshots x WHERE x.generation=p.generation AND x.accepted=1) ORDER BY p.id DESC LIMIT 64",[],64)
    collect(rows,db)
