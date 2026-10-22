import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./maintenance.bend as Maintenance
import ./domain.bend as Domain
import ./evidence.bend as Evidence
import ./providers.bend as Providers
import ./actors.bend as Actors
import ./request_evidence.bend as Request
import ./request_origin.bend as Origin
import ./recorded_commit_raw.bend as Raw
import ./recorded_commit_links.bend as Links
import ./recorded_commit_git.bend as Git
import ./repo_scope.bend as Scope
import ./json.bend as Json
import ./recorded_commit_coverage.bend as Coverage
import ./recorded_commit_excerpt.bend as Excerpt
import ./recorded_commit_observation.bend as Observation

# Read-only, bounded, complete-snapshot scan. A partial snapshot cannot create
# a unique pair: later duplicate IDs or a conflicting request could be hidden.
# SQL is used only for immutable snapshot locators, never quoted authority.
type Scan is Data:
  Scan{context: Store.Context,position: U32,request: Maybe<&2,Links.Request>,
    calls: List<&2,Links.Call>,outputs: List<&2,Links.Output>,count: U32,issue: String}

type Report is Data:
  Report{items: List<&2,Links.Evidence>,coverage: String}

type Resolved is Data:
  Resolved{evidence: Links.Evidence,resolution: Git.Resolution,excerpt: String}

def empty() -> Scan:
  Scan{Store.Context{"","","",""},0,None{},[],[],0,""}

def issue(scan: Scan,reason: String) -> Scan:
  Scan{context,position,request,calls,outputs,count,prior} = scan
  Scan{context,position,request,calls,outputs,count,Store.nonempty(prior,reason)}

def request_state(assessment: Origin.Assessment,key: String,+prior: Maybe<&2,Links.Request>) -> Maybe<&2,Links.Request>:
  +text = Request.request(assessment)
  Bool.pick(Maybe<&2,Links.Request>,String.is_empty(text),prior,
    Bool.pick(Maybe<&2,Links.Request>,String.is_empty(Actors.guarded_text(text)),
      Some{Links.Request{key,String.take(text,2048n)}},None{}))

def request_update(is_user: Bool,provider: String,raw: Json.Json,index: U32,event: Providers.Record,
  key: String,prior: Maybe<&2,Links.Request>) -> Maybe<&2,Links.Request>:
  match is_user:
    case False{}: prior
    case True{}: request_state(Request.assess(provider,raw,index,event),key,prior)

def admitted(scan: Scan,item: Raw.Item,+event: Providers.Record,key: String) -> Scan:
  Scan{context,+position,+request,calls,outputs,count,prior} = scan
  match item:
    case Raw.Ignore{}: Scan{context,position,request,calls,outputs,count,prior}
    case Raw.Unsupported{reason}: Scan{context,position,request,calls,outputs,count,Store.nonempty(prior,reason)}
    case Raw.Call{id,tool,args}:
      Scan{context,position,request,
        Links.Call{id,key,position,tool,args,Providers.repository(event),request} <> calls,outputs,U32.inc(count),
        Store.nonempty(prior,Bool.pick(String,String.eq(Providers.role(event),"assistant"),"","unsupported call role"))}
    case Raw.Output{id,status,markers}:
      Scan{context,position,request,calls,Links.Output{id,key,position,status,markers} <> outputs,U32.inc(count),
        Store.nonempty(prior,Bool.pick(String,String.eq(Providers.role(event),"tool"),"","unsupported result role"))}

def bounded(available: Bool,item: Raw.Item,event: Providers.Record,key: String,scan: Scan) -> Scan:
  match available:
    case False{}: issue(scan,"snapshot tool event bound exceeded; no unique attribution claimed")
    case True{}: admitted(scan,item,event,key)

def event_step(pair: Store.Context & Providers.Record,+raw: Json.Json,+record: Evidence.Verified,
  +provider: String,+index: U32,scan: Scan) -> Scan:
  (context,+event) = pair
  Scan{_,position,request,calls,outputs,+count,prior} = scan
  +key = Evidence.citation(record,index)
  bounded(U32.is_lt(count,256),Raw.extract(provider,raw,index),event,key,
    Scan{context,U32.inc(position),request_update(String.eq(Providers.role(event),"user"),
      provider,raw,index,event,key,request),calls,outputs,count,prior})

def scan_context(scan: Scan) -> Store.Context:
  Scan{context,_,_,_,_,_,_} = scan
  context

def events(items: List<&2,Providers.Record>,+raw: Json.Json,+record: Evidence.Verified,+provider: String,
  +index: U32,+scan: Scan) -> Scan:
  match items:
    case []: scan
    case +head <> rest:
      events(rest,raw,record,provider,U32.inc(index),
        event_step(Store.contextualize(provider,scan_context(scan),head),raw,record,provider,index,scan))

def decoded(value: Result<&2,&2,String,Json.Json>,+record: Evidence.Verified,scan: Scan) -> Scan:
  match value:
    case Fail{_}: issue(scan,"malformed retained record; no complete snapshot pairing claimed")
    case Done{raw}:
      Evidence.Verified{provider,_,_,_,_,_,items} = record
      events(items,raw,record,provider,0,scan)

def frame_text(value: Result<&2,&2,String,String>,record: Evidence.Verified,scan: Scan) -> Scan:
  match value:
    case Fail{_}: issue(scan,"non-UTF8 retained record; no complete snapshot pairing claimed")
    case Done{text}: decoded(Json.parse(text),record,scan)

def frame(row: List<&2,Sql.Cell>,record: Evidence.Verified,scan: Scan) -> Scan:
  frame_text(Domain.decode(Store.blob(Store.cell(row,5n))),record,scan)

def walk(fuel: Nat,+db: U32,+snapshot: String,+source: String,+header: Maintenance.Header,+ordinal: U32,scan: Scan) -> IO(Scan):
  match fuel:
    case 0n: IO.pure(Scan,scan)
    case 1n+n:
      Maintenance.Header{+generation,+extent,records,+provider} = header
      do IO<Scan>:
        +row : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,extent,records,ordinal)
        record : Evidence.Verified = Evidence.Verified{provider,source,generation,snapshot,U32.show(extent),U32.show(ordinal),
          Store.piece_events(U32.is_ne(Store.number(Store.field(row,6n)),0),provider,Store.blob(Store.cell(row,5n)))}
        walk(n,db,snapshot,source,header,U32.inc(ordinal),frame(row,record,scan))

def finish(scan: Scan,scope: Scope.Scope) -> Report:
  Scan{_,_,_,+calls,outputs,_,issue} = scan
  +items = Links.analyze_all(calls,calls,outputs,scope)
  Report{items,Store.nonempty(issue,Observation.collect(items))}

def bounded_snapshot(valid: Bool,+db: U32,+snapshot: String,source: String,+header: Maintenance.Header,scope: Scope.Scope) -> IO(Report):
  match valid:
    case False{}: IO.pure(Report,Report{[],"eligible snapshot exceeds 1024 records or 8 MiB; no complete attribution claimed"})
    case True{}:
      Maintenance.Header{_,_,records,_} = header
      do IO<Report>:
        scan : Scan <- walk(U32.to_nat(records),db,snapshot,source,header,0,empty())
        return finish(scan,scope)

def snapshot_header(+header: Maintenance.Header,db: U32,snapshot: String,source: String,scope: Scope.Scope) -> IO(Report):
  Maintenance.Header{_,extent,records,_} = header
  bounded_snapshot(U32.is_le(records,1024) && U32.is_le(extent,8388608),db,snapshot,source,header,scope)

def snapshot(+db: U32,actor: Actors.Actor,scope: Scope.Scope) -> IO(Report):
  Actors.Actor{_,source,+snapshot,_,_,_,_,_,_} = actor
  do IO<Report>:
    +header : Maintenance.Header <- Maintenance.header(db,snapshot)
    snapshot_header(header,db,snapshot,source,scope)

def merge(left: Report,right: Report) -> Report:
  Report{items,coverage} = left
  Report{other,issue} = right
  Report{List.append(&2,Links.Evidence,items,other),Store.nonempty(coverage,issue)}

def allowed_actor(valid: Bool,coverage: String,db: U32,actor: Actors.Actor,scope: Scope.Scope) -> IO(Report):
  match valid:
    case False{}: IO.pure(Report,Report{[],coverage})
    case True{}: snapshot(db,actor,scope)

def actors(items: List<&2,Actors.Actor>,+all: List<&2,Actors.Actor>,+db: U32,+scope: Scope.Scope,+counts: List<&2,Coverage.Count>) -> IO(Report):
  match items:
    case []: IO.pure(Report,Report{[],""})
    case +actor <> rest:
      do IO<Report>:
        head : Report <- allowed_actor(Actors.allowed(8n,actor,all,Scope.canonical(scope)),
          Coverage.chain(8n,actor,all,Scope.canonical(scope),counts),db,actor,scope)
        tail : Report <- actors(rest,all,db,scope,counts)
        return merge(head,tail)

def resolved_excerpt(value: Result<&2,&2,String,String>,evidence: Links.Evidence,resolution: Git.Resolution) -> Resolved:
  match value:
    case Fail{reason}: Resolved{evidence,Git.Resolution{"retained_evidence_unavailable",""},reason}
    case Done{text}: Resolved{evidence,resolution,text}

def resolve_state(succeeded: Bool,state: String,+prefix: String,+call: String,+result: String,
  request: Maybe<&2,Links.Request>,repo: String,db: U32) -> IO(Resolved):
  match succeeded:
    case True{}:
      do IO<Resolved>:
        resolved : Git.Resolution <- Git.resolve(repo,prefix)
        excerpt : Result<&2,&2,String,String> <- Excerpt.read(db,call,result)
        return resolved_excerpt(excerpt,Links.Evidence{"recorded_success",prefix,call,result,request},resolved)
    case False{}: IO.pure(Resolved,Resolved{Links.Evidence{state,prefix,call,result,request},Git.Resolution{"not_resolved",""},""})

def resolve_one(value: Links.Evidence,repo: String,db: U32) -> IO(Resolved):
  Links.Evidence{+state,prefix,call,result,request} = value
  resolve_state(String.eq(state,"recorded_success"),state,prefix,call,result,request,repo,db)

def resolve_all(items: List<&2,Links.Evidence>,+repo: String,fuel: Nat,+db: U32) -> IO(List<&2,Resolved>):
  match items fuel:
    case Nil{} _: IO.pure(List<&2,Resolved>,[])
    case _ 0n: IO.pure(List<&2,Resolved>,[])
    case Con{head,rest} 1n+n:
      do IO<List<&2,Resolved>>:
        value : Resolved <- resolve_one(head,repo,db)
        tail : List<&2,Resolved> <- resolve_all(rest,repo,n,db)
        return value <> tail

def request_text(value: Maybe<&2,Links.Request>) -> String:
  match value:
    case None{}: "Preceding eligible recorded request: not_captured.\n"
    case Some{Links.Request{key,preview}}:
      "Preceding eligible recorded request (recorded-request-v1):\n" ++ preview ++
        "\nRequest citation: " ++ key ++ "\n"

def matched(value: Resolved,+target: String) -> Bool:
  Resolved{_,Git.Resolution{state,sha},_} = value
  String.eq(state,"resolved") && String.eq(sha,target)

def matching(items: List<&2,Resolved>,+target: String) -> List<&2,Resolved>:
  match items:
    case []: []
    case +head <> rest:
      +tail = matching(rest,target)
      Bool.pick(List<&2,Resolved>,matched(head,target),head <> tail,tail)

def details(value: Resolved) -> String:
  Resolved{Links.Evidence{state,prefix,call,result,request},Git.Resolution{resolution,sha},excerpt} = value
  "Recorded command state: " ++ state ++ " · Git resolution: " ++ resolution ++
    "\nRecorded object prefix: " ++ prefix ++ " · resolved object: " ++ sha ++
    "\nCall citation: " ++ call ++ "\nResult citation: " ++ result ++ "\n" ++ request_text(request) ++ excerpt

def diagnostics(items: List<&2,Resolved>) -> String:
  match items:
    case []: ""
    case head <> rest: details(head) ++ "\n" ++ diagnostics(rest)

def selected(items: List<&2,Resolved>,coverage: String) -> String:
  match items:
    case []: Bool.pick(String,String.is_empty(coverage),
      "Recorded commit attribution: not_captured within the reported scan.\n",
      "Recorded commit attribution: incomplete_coverage; no matching command was established in the inspected subset.\n")
    case _ <> Nil{}:
      Bool.pick(String,String.is_empty(coverage),
        "Recorded commit attribution: exact_git_commit_result (unique verified recorded evidence within inspected coverage; local object resolved).\n",
        "Recorded commit attribution: incomplete_coverage; observed match is not a unique attribution claim.\n")
    case _: "Recorded commit attribution: ambiguous; multiple retained calls resolve to this commit.\n"

def resolution_issue(value: Git.Resolution) -> String:
  Git.Resolution{+state,_} = value
  Bool.pick(String,String.eq(state,"ambiguous_object") || String.eq(state,"git_unavailable") ||
    String.eq(state,"unsupported_object_format") || String.eq(state,"retained_evidence_unavailable"),
    "candidate object or retained citation could not be uniquely verified","")

def resolution_coverage(items: List<&2,Resolved>) -> String:
  match items:
    case []: ""
    case Resolved{_,resolution,_} <> rest:
      Store.nonempty(resolution_issue(resolution),resolution_coverage(rest))

def rendered(+items: List<&2,Resolved>,target: String,+coverage: String) -> String:
  +complete = Store.nonempty(coverage,resolution_coverage(items))
  selected(matching(items,target),complete) ++
    "Coverage: " ++ Store.nonempty(complete,"all eligible snapshots inside the stated bounds were scanned") ++
    ". At most 64 latest generation snapshots; each at most 1024 records / 8 MiB, 256 tool events, 32 command observations resolved. Actor eligibility uses the first 16 retained records and at most 8 actors in an ancestry chain.\n" ++
    "This is recorded command evidence, not proof of sole authorship, human authorship, or inferred rationale. " ++
    "Citations remain pinned to retained snapshots; positions are logical source bytes for archives. " ++
    "Unsupported/quiet/failed commands do not infer a commit.\n" ++ diagnostics(items)

def report(+report: Report,db: U32,scope: Scope.Scope,target: String) -> IO(String):
  Report{+items,coverage} = report
  +bounded = Nat.is_le(List.length(&2,Links.Evidence,items),32n)
  do IO<String>:
    resolved : List<&2,Resolved> <- resolve_all(items,Scope.checkout(scope),32n,db)
    return rendered(resolved,target,Store.nonempty(coverage,
      Bool.pick(String,bounded,"","commit observation bound exceeded")))

def scoped_actor(actor: Actors.Actor,scope: Scope.Scope) -> Actors.Actor:
  Actors.Actor{provider,source,snapshot,session,repo,parent,request,key,blocked} = actor
  Actors.Actor{provider,source,snapshot,session,Scope.normalize(scope,repo),parent,request,key,blocked}

def scoped_actors(items: List<&2,Actors.Actor>,+scope: Scope.Scope) -> List<&2,Actors.Actor>:
  match items:
    case []: []
    case head <> rest: scoped_actor(head,scope) <> scoped_actors(rest,scope)

def snapshot_counts(rows: List<&2,List<&2,Sql.Cell>>) -> List<&2,Coverage.Count>:
  match rows:
    case []: []
    case +row <> rest:
      +tail = snapshot_counts(rest)
      Bool.pick(List<&2,Coverage.Count>,Store.numeric(Store.field(row,0n)) && Store.numeric(Store.field(row,1n)),
        Coverage.Count{Store.field(row,0n),Store.number(Store.field(row,1n))} <> tail,tail)

def read(+db: U32,+scope: Scope.Scope,target: String) -> IO(String):
  # Refuse nesting rather than ending a caller transaction; fatal integrity
  # errors terminate the worker and SQLite rolls back its owned connection.
  do IO<String>:
    Store.exec(db,"BEGIN DEFERRED",[])
    count : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT count(*) FROM snapshots p WHERE p.accepted=1 AND p.id=(SELECT max(x.id) FROM snapshots x WHERE x.generation=p.generation AND x.accepted=1)",[],1)
    counts : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
      "SELECT p.id,p.records FROM snapshots p WHERE p.accepted=1 AND p.id=(SELECT max(x.id) FROM snapshots x WHERE x.generation=p.generation AND x.accepted=1) ORDER BY p.id DESC LIMIT 64",[],64)
    raw : List<&2,Actors.Actor> <- Actors.load(db)
    +all : List<&2,Actors.Actor> = scoped_actors(raw,scope)
    value : Report <- actors(all,all,db,scope,snapshot_counts(counts))
    Store.exec(db,"ROLLBACK",[])
    report(merge(value,Report{[],Bool.pick(String,U32.is_le(Store.number(Store.field(Store.first(count),0n)),64),
      "","generation snapshot bound exceeded")}),db,scope,target)
