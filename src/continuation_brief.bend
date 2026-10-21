import Base
import ./store.bend as Store
import ./sql.bend as Sql
import ./json.bend as Json
import ./domain.bend as Domain
import ./providers.bend as Providers
import ./evidence.bend as Evidence
import ./scoped_reader.bend as Scoped
import ./activity_reader.bend as Reader
import ./tool_activity.bend as Activity
import ./maintenance.bend as Maintenance
import ./repo_scope.bend as Repo
import ./request_evidence.bend as Request
import ./request_origin.bend as Origin
import ./brief_safe_text.bend as Safe

# Stateless continuation brief rendering and verified retained evidence.
# No writes, models, original-source reads, latest resolution or captured-text execution.
type Input is Data:
  Input{snapshot: String,start: U32,count: U32,scope: Scoped.Scope,repository: String}
type Problem is Data:
  Problem{code: String,detail: String}
type RequestState is Data:
  Missing{excluded: U32}
  Unique{citation: Evidence.Descriptor}
  Multiple{eligible: U32,uncertain: U32}
  Uncertain{eligible: U32,uncertain: U32}
type Notice is Data:
  Notice{kind: String,fields: U32}
type Coverage is Data:
  Coverage{selected_records: U32,verified_records: U32,eligible_events: U32,
    included_events: U32,omitted_budget: U32,excluded_scope: U32,partial_events: U32}
type Anchor is Data:
  Anchor{input: Input,repository: Repo.Scope,provider: String,source: String,
    generation: String,extent: U32,total_records: U32}
type Preview is Data:
  Preview{anchor: Anchor,policy: String,request_policy: String,parser_policy: String,
    source_fingerprint: String,evidence_fingerprint: String,
    references: List<&2,Evidence.Descriptor>,request: RequestState,coverage: Coverage,
    notices: List<&2,Notice>,text: String,utf8_bytes: U32}
type Fact is Data:
  Fact{occurrence: Activity.Occurrence,request: U32,suffix: String,prefixes: U32}
type Collected is Data:
  Collected{facts: List<&2,Fact>,eligible: U32,uncertain: U32,excluded: U32,
    outside: U32,partial: U32,attachments: U32,manifest: String}
type Group is Data:
  Group{remaining: List<&2,Activity.Occurrence>,collected: Collected}
type Paint is Data:
  Paint{text: String,credentials: U32,paths: U32,controls: U32,prefixes: U32}
type Layout is Data:
  Layout{opening: String,details: String}
type Packed is Data:
  Packed{parts: List<&2,String>,citations: List<&2,String>,references: List<&2,Evidence.Descriptor>,count: U32,
    omitted: U32,credentials: U32,paths: U32,controls: U32,prefixes: U32,left: U32}

def policy() -> String:
  "continuation-brief-v2|" ++ Safe.policy() ++ "|brief-citation-v1"

def strings(values: List<&2,String>) -> String:
  match values:
    case []: ""
    case value <> rest: Json.quote(value) ++ ":" ++ strings(rest)

def scope_strings(scope: Scoped.Scope) -> List<&2,String>:
  Scoped.Scope{provider,repo,role,after} = scope
  [provider,repo,role,after]

def input_strings(input: Input) -> List<&2,String>:
  Input{snapshot,start,count,scope,repo} = input
  "logical_source_bytes" <> snapshot <> U32.show(start) <> U32.show(count) <> repo <> scope_strings(scope)

def anchor_text(anchor: Anchor) -> String:
  Anchor{input,Repo.Scope{checkout,canonical,roots},provider,source,generation,extent,total} = anchor
  strings(List.append(&2,String,input_strings(input),
    provider <> source <> generation <> U32.show(extent) <> U32.show(total) <>
    checkout <> canonical <> roots))

def chain(previous: String,value: String) -> String:
  Domain.digest(Domain.encode("juice-bend-brief-evidence-v1|" ++ strings([previous,value])))

def descriptor_key(+descriptor: Evidence.Descriptor) -> String:
  Evidence.Descriptor{_,_,ordinal,event} = descriptor
  strings(List.append(&2,String,Activity.descriptor_strings(descriptor),[U32.show(ordinal),U32.show(event)]))

def raw_manifest(+row: List<&2,Sql.Cell>,identity: Sql.Cell) -> String:
  Store.projection_cells([identity]) ++ Store.projection_cells(List.take(&2,Sql.Cell,row,5n)) ++
    Store.projection_cells(List.drop(&2,Sql.Cell,row,6n))

def event_manifest(occurrence: Activity.Occurrence) -> String:
  Activity.Occurrence{descriptor,event} = occurrence
  strings(descriptor_key(descriptor) <> Activity.record_strings(event))

def scope_path(+path: String) -> Bool:
  String.starts_with(path,"/") && Bool.not(String.contains(path,"\0")) &&
    Bool.not(String.contains(path,"/../")) && Bool.not(String.ends_with(path,"/..")) &&
    Bool.not(String.contains(path,"/./")) && Bool.not(String.ends_with(path,"/.")) &&
    Bool.not(String.contains(path,"//"))

def repository_allowed(+repo: Repo.Scope,event: Providers.Record) -> Bool:
  Repo.Scope{_,canonical,roots} = repo
  Providers.ProviderEvent{_,_,_,_,_,_,+cwd,_,_,_,_,_,_} = event
  scope_path(cwd) && Bool.not(String.is_empty(Repo.best_root(roots,cwd,""))) &&
    Repo.root_match(canonical,Repo.normalize(repo,cwd))

def parsed(result: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match result:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def decoded(result: Result<&2,&2,String,String>) -> Json.Json:
  match result:
    case Done{text}: parsed(Json.parse(text))
    case Fail{_}: Json.JNull{}

def raw_json(+row: List<&2,Sql.Cell>) -> Json.Json:
  Bool.pick(Json.Json,String.eq(Store.field(row,6n),"0"),
    decoded(Domain.decode(Store.blob(Store.cell(row,5n)))),Json.JNull{})

def assessed(+occurrence: Activity.Occurrence,+assessment: Origin.Assessment) -> Fact:
  Origin.Assessment{_,_,disposition} = assessment
  match disposition:
    case Origin.RecordedRequest{_,prefixes}:
      Fact{occurrence,1,Request.request(assessment),prefixes}
    case Origin.Uncertain{_}:
      Fact{occurrence,2,"",0}
    case _:
      Fact{occurrence,3,"",0}

def request_assessed(uncertain: Bool,occurrence: Activity.Occurrence,next: Activity.Occurrence -> Fact) -> Fact:
  match uncertain:
    case True{}: Fact{occurrence,2,"",0}
    case False{}: next(occurrence)

def known_coverage(+coverage: String) -> Bool:
  String.eq(coverage,"complete") || String.eq(coverage,"metadata") ||
    String.eq(coverage,"metadata_context") || String.eq(coverage,"tool_error")

def request_fact(+occurrence: Activity.Occurrence,provider: String,meta: Origin.MetaFlag,hint: Maybe<&2,String>,role: String,issue: String) -> Fact:
  match role:
    case "attachment": Fact{occurrence,4,"",0}
    case "user": request_assessed(Bool.not(String.is_empty(issue)),occurrence,
      value => assessed(value,Request.assess_aligned(provider,meta,hint,Activity.record(occurrence))))
    case _:
      coverage = Providers.coverage(Activity.record(occurrence))
      Fact{occurrence,Bool.pick(U32,known_coverage(coverage) && String.is_empty(issue),0,2),"",0}

def add_fact(+fact: Fact,+allowed: Bool,collected: Collected) -> Collected:
  Fact{+occurrence,+kind,_,_} = fact
  Collected{+facts,eligible,uncertain,excluded,outside,partial,attachments,manifest} = collected
  coverage = Providers.coverage(Activity.record(occurrence))
  Collected{Bool.pick(List<&2,Fact>,allowed && U32.is_lt(kind,3),fact <> facts,facts),
    U32.add(eligible,Bool.to_u32(allowed && U32.is_eq(kind,1))),
    U32.add(uncertain,Bool.to_u32(allowed && U32.is_eq(kind,2))),
    U32.add(excluded,Bool.to_u32(allowed && U32.is_eq(kind,3))),
    U32.add(outside,Bool.to_u32(Bool.not(allowed))),
    U32.add(partial,Bool.to_u32(allowed && Bool.not(known_coverage(coverage)))),
    U32.add(attachments,Bool.to_u32(allowed && U32.is_eq(kind,4))),
    chain(manifest,event_manifest(occurrence))}

def hint_head(values: List<&2,Maybe<&2,String>>) -> Maybe<&2,String>:
  match values:
    case []: None{}
    case value <> _: value

def hint_tail(values: List<&2,Maybe<&2,String>>) -> List<&2,Maybe<&2,String>>:
  match values:
    case []: []
    case _ <> rest: rest

def group_more(same: Bool,occurrence: Activity.Occurrence,rest: List<&2,Activity.Occurrence>,
  collected: Collected,next: Collected -> Group) -> Group:
  match same:
    case False{}: Group{occurrence <> rest,collected}
    case True{}: next(collected)

def group(values: List<&2,Activity.Occurrence>,+ordinal: U32,+provider: String,
  +repo: Repo.Scope,+meta: Origin.MetaFlag,+issue: String,hints: List<&2,Maybe<&2,String>>,cursor: U32,collected: Collected) -> Group:
  match values:
    case []: Group{[],collected}
    case +head <> +rest:
      Activity.Occurrence{Evidence.Descriptor{_,_,index,+event_index},+event} = head
      Providers.ProviderEvent{role,_,_,_,_,_,_,_,_,_,_,_,_} = event
      +tail = List.drop(&2,Maybe<&2,String>,hints,U32.to_nat(U32.sub(event_index,cursor)))
      group_more(U32.is_eq(ordinal,index),head,rest,collected,next =>
        group(rest,ordinal,provider,repo,meta,issue,hint_tail(tail),U32.inc(event_index),
          add_fact(request_fact(head,provider,meta,hint_head(tail),role,issue),repository_allowed(repo,event),next)))

def raw_identity(rows: List<&2,List<&2,Sql.Cell>>) -> IO(Sql.Cell):
  match rows:
    case [[Sql.Cell.Integer{+identity}]]:
      do IO<Sql.Cell>:
        Store.checked(Evidence.positive_id(identity),"Brief raw mapping identity is invalid")
        return Sql.Cell.Integer{identity}
    case _: IO.die(Sql.Cell,1,"Brief raw mapping identity is missing or has an invalid storage type")

def scan_next(grouped: Group,next: List<&2,Activity.Occurrence> -> Collected -> IO(Collected)) -> IO(Collected):
  Group{remaining,collected} = grouped
  next(remaining)(collected)

def scan(fuel: Nat,+db: U32,+snapshot: String,+generation: String,+extent: U32,
  +total: U32,+ordinal: U32,+provider: String,+repo: Repo.Scope,
  values: List<&2,Activity.Occurrence>,collected: Collected) -> IO(Collected):
  match fuel:
    case 0n:
      do IO<Collected>:
        Store.checked(List.is_empty(&2,Activity.Occurrence,values),"Brief occurrence lies outside its verified range")
        return collected
    case 1n+rest:
      Collected{facts,eligible,uncertain,excluded,outside,partial,attachments,manifest} = collected
      do IO<Collected>:
        +row : List<&2,Sql.Cell> <- Store.selected_record(db,snapshot,generation,extent,total,ordinal)
        identities : List<&2,List<&2,Sql.Cell>> <- Store.q(db,"SELECT raw FROM main.records WHERE snapshot=? AND ordinal=?",
          [Sql.Cell.Integer{snapshot},Sql.Cell.Integer{U32.show(ordinal)}],1)
        identity : Sql.Cell <- raw_identity(identities)
        +raw : Json.Json = raw_json(row)
        scan_next(group(values,ordinal,provider,repo,Origin.metadata(raw),Request.frame_issue(provider,raw),Request.texts(provider,raw),0,
          Collected{facts,eligible,uncertain,excluded,outside,partial,attachments,chain(manifest,raw_manifest(row,identity))}),
          remaining => next => scan(rest,db,snapshot,generation,extent,total,U32.inc(ordinal),provider,repo,remaining,next))

def first_request(facts: List<&2,Fact>) -> Maybe<&2,Evidence.Descriptor>:
  match facts:
    case []: None{}
    case Fact{Activity.Occurrence{citation,_},1,_,_} <> _: Some{citation}
    case _ <> rest: first_request(rest)

def unique_request(found: Maybe<&2,Evidence.Descriptor>) -> RequestState:
  match found:
    case Some{citation}: Unique{citation}
    case None{}: Uncertain{1,1}

def request_state(+facts: List<&2,Fact>,+eligible: U32,+uncertain: U32,excluded: U32) -> RequestState:
  match eligible uncertain:
    case 0 0: Missing{excluded}
    case 1 0: unique_request(first_request(facts))
    case _ 0: Multiple{eligible,0}
    case _ _: Uncertain{eligible,uncertain}

def request_text(state: RequestState) -> String:
  match state:
    case Missing{excluded}: "No eligible recorded request in this range; excluded envelopes: " ++ U32.show(excluded)
    case Unique{_}: "One eligible recorded request in this range (not proof of human authorship)"
    case Multiple{n,u}: "Multiple recorded requests; eligible " ++ U32.show(n) ++ ", uncertain " ++ U32.show(u)
    case Uncertain{n,u}: "Recorded request uncertain; eligible " ++ U32.show(n) ++ ", uncertain " ++ U32.show(u)

def request_key(state: RequestState) -> String:
  match state:
    case Unique{citation}: "unique|" ++ descriptor_key(citation)
    case other: request_text(other)

def brief_citation(descriptor: Evidence.Descriptor) -> String:
  Evidence.Descriptor{Domain.EvidenceKey{provider,source,generation,snapshot,record,event},extent,_,_} = descriptor
  "juice-bend-brief-citation-v1 {\"provider\":" ++ Json.quote(provider) ++
    ",\"source_sha256\":" ++ Json.quote(Domain.digest(Domain.encode(source))) ++
    ",\"generation\":" ++ Json.quote(generation) ++ ",\"snapshot\":" ++ Json.quote(snapshot) ++
    ",\"extent\":" ++ Json.quote(extent) ++ ",\"record\":" ++ Json.quote(record) ++ ",\"event\":" ++ Json.quote(event) ++ "}"

def field_paint(name: String,value: Safe.Transform,paint: Paint) -> Paint:
  Safe.Transform{text,credentials,paths,controls} = value
  Paint{before,c,p,z,prefixes} = paint
  Paint{before ++ name ++ ": " ++ Json.quote(text) ++ "\n",U32.add(c,credentials),
    U32.add(p,paths),U32.add(z,controls),prefixes}

def optional_field(empty: Bool,name: String,value: String,roots: List<&2,String>,source: String,paint: Paint) -> Paint:
  match empty:
    case True{}: paint
    case False{}: field_paint(name,Safe.transform(value,roots,source),paint)

def fields(names: List<&2,String>,values: List<&2,String>,+roots: List<&2,String>,
  +source: String,paint: Paint) -> Paint:
  match names values:
    case name <> more +value <> rest:
      fields(more,rest,roots,source,optional_field(String.is_empty(value),name,value,roots,source,paint))
    case _ _: paint

def fact_label(citation: Evidence.Descriptor,kind: U32) -> String:
  Evidence.Descriptor{_,_,ordinal,event} = citation
  Bool.pick(String,U32.is_eq(kind,1),"Recorded request","Recorded fact") ++
    " | captured record " ++ U32.show(ordinal) ++ ", event " ++ U32.show(event) ++ "\n"

def paint_suffix(paint: Paint) -> Paint:
  Paint{text,c,p,z,+prefixes} = paint
  Paint{text ++ Bool.pick(String,U32.is_gt(prefixes,0),
    "Recorded request uses eligible suffix; context prefix blocks omitted: " ++ U32.show(prefixes) ++ "\n",""),c,p,z,prefixes}

def paint(fact: Fact,repo: Repo.Scope,source: String) -> Paint:
  Fact{Activity.Occurrence{citation,event},+kind,suffix,prefixes} = fact
  Providers.ProviderEvent{role,text,tool,call,args,result,_,_,time,model,_,_,coverage} = event
  Repo.Scope{_,_,roots} = repo
  paint_suffix(fields(["Text","Tool","Arguments","Recorded result","Role","Recorded time","Recorded model","Coverage","Call ID"],
    [Bool.pick(String,U32.is_eq(kind,1),suffix,text),tool,args,result,role,time,model,coverage,call],roots,source,
    Paint{fact_label(citation,kind),0,0,0,prefixes}))

def selected_request(state: RequestState) -> Maybe<&2,Evidence.Descriptor>:
  match state:
    case Unique{citation}: Some{citation}
    case _: None{}

def preferred(citation: Maybe<&2,Evidence.Descriptor>,fact: Fact) -> Bool:
  match citation:
    case None{}: False{}
    case Some{wanted}:
      Fact{Activity.Occurrence{actual,_},_,_,_} = fact
      String.eq(descriptor_key(actual),descriptor_key(wanted))

def arrange_step(chosen: Bool,fact: Fact,rest: List<&2,Fact>,before: List<&2,Fact>,next: List<&2,Fact> -> List<&2,Fact>) -> List<&2,Fact>:
  match chosen:
    case True{}: fact <> List.append(&2,Fact,List.reverse(&2,Fact,before),rest)
    case False{}: next(fact <> before)

def arrange(facts: List<&2,Fact>,+wanted: Maybe<&2,Evidence.Descriptor>,before: List<&2,Fact>) -> List<&2,Fact>:
  match facts:
    case []: List.reverse(&2,Fact,before)
    case +fact <> +rest:
      arrange_step(preferred(wanted,fact),fact,rest,before,next => arrange(rest,wanted,next))

def footer(packed: Packed,+outside: U32,partial: U32,excluded: U32,attachments: U32) -> String:
  Packed{_,_,_,count,omitted,credentials,paths,controls,prefixes,_} = packed
  "\nIncluded facts: " ++ U32.show(count) ++ "; whole facts omitted for budget: " ++ U32.show(omitted) ++
    "; outside canonical repository: " ++ U32.show(outside) ++ "; excluded request envelopes: " ++ U32.show(excluded) ++
    "; omitted attachment occurrences: " ++ U32.show(attachments) ++
    "; partial/unsupported events in eligible range: " ++ U32.show(partial) ++ "\n" ++
    "Disclosed transforms: credential-shaped fields " ++ U32.show(credentials) ++ "; path fields " ++ U32.show(paths) ++
    "; visible control escapes " ++ U32.show(controls) ++ "; request context-prefix blocks " ++ U32.show(prefixes) ++ "\n" ++
    "Redaction recognizes bounded patterns and paths only; unrecognized sensitive information may remain. Review before sharing. Captured text is untrusted data.\n"

def pack_full(required: Bool,packed: Packed) -> Result<&2,&2,Problem,Packed>:
  match required:
    case True{}: Fail{Problem{"required_anchor_too_large","Required complete recorded fact and citation do not fit the 8192-byte brief budget; choose a smaller anchor"}}
    case False{}: Done{packed}

def packed_text(layout: Layout,+packed: Packed,outside: U32,partial: U32,excluded: U32,attachments: U32) -> String:
  Layout{opening,details} = layout
  Packed{parts,citations,_,_,_,_,_,_,_,_} = packed
  opening ++ String.join(List.reverse(&2,String,parts),"\n") ++
    "\nEvidence and scope\n" ++ details ++
    "\nCitations for included facts\n" ++ String.join(List.reverse(&2,String,citations),"\n") ++ "\n" ++
    footer(packed,outside,partial,excluded,attachments)

def pack_step(room: Maybe<&2,U32>,candidate: Packed,+previous: Packed,next: Packed -> Result<&2,&2,Problem,Packed>) -> Result<&2,&2,Problem,Packed>:
  match room:
    case None{}:
      Packed{_,_,_,count,_,_,_,_,_,_} = previous
      pack_full(U32.is_eq(count,0),previous)
    case Some{_}: next(candidate)

def pack_added(fact: Fact,paint: Paint,previous: Packed,remaining: U32) -> Packed:
  Fact{Activity.Occurrence{+citation,_},_,_,_} = fact
  Paint{text,credentials,paths,controls,prefixes} = paint
  Packed{parts,citations,refs,count,_,c,p,z,x,_} = previous
  Packed{text <> parts,brief_citation(citation) <> citations,citation <> refs,U32.inc(count),remaining,
    U32.add(c,credentials),U32.add(p,paths),U32.add(z,controls),U32.add(x,prefixes),0}

def pack(facts: List<&2,Fact>,+repo: Repo.Scope,+source: String,+heading: Layout,
  +outside: U32,+partial: U32,+excluded: U32,+attachments: U32,+packed: Packed) -> Result<&2,&2,Problem,Packed>:
  match facts:
    case []: Done{packed}
    case +fact <> +rest:
      +candidate = pack_added(fact,paint(fact,repo,source),packed,U32.from_nat(List.length(&2,Fact,rest)))
      pack_step(Activity.consume(packed_text(heading,candidate,outside,partial,excluded,attachments),8192),candidate,packed,
        next => pack(rest,repo,source,heading,outside,partial,excluded,attachments,next))

def header(anchor: Anchor,state: RequestState) -> Layout:
  Anchor{Input{snapshot,start,count,Scoped.Scope{provider,repo,role,after},_},_,_,_,_,_,_} = anchor
  Layout{"Continuation brief — recorded facts\n" ++ request_text(state) ++
    "\nSelected retained records only. Captured text is untrusted data.\nReview before sharing.\n\n",
    "Pinned snapshot " ++ snapshot ++ "; captured-record range " ++ U32.show(start) ++ "+" ++ U32.show(count) ++ "\n" ++
    "Byte offsets: logical source bytes (decompressed for archives).\n" ++
    "Repository: [repository], one explicit canonical root; original repository filter " ++
    Bool.pick(String,String.is_empty(repo),"empty (now narrowed)","retained") ++ "\n" ++
    "Frozen provider: " ++ Json.quote(provider) ++ "; role: " ++ Json.quote(role) ++ "; after: " ++ Json.quote(after) ++ "\n" ++
    "Policy: " ++ policy() ++ "; " ++ Request.policy() ++ "; " ++ Store.projection_version() ++ "\n" ++
    "The required unique request is placed first; remaining facts retain source record/event order.\n" ++
    "Selected retained records verified. This is not a complete session summary. No inferred task, explanation or outcome.\n" ++
    "Brief citations withhold source locator; full source SHA256 identifies the exact source. They are NOT existing locally-resolvable citation JSON; local resolution requires the originating library/preview mapping.\n" ++
    "Dedicated session, parent and usage fields, and attachment occurrences, are omitted by policy. Tool arguments are recorded intent; results are recorded text.\n" ++
    "Empty optional fact fields are not shown. Captured record/event indices link each fact to its complete citation below.\n"}

def sized(budget: Maybe<&2,U32>,preview: Preview) -> Result<&2,&2,Problem,Preview>:
  match budget:
    case None{}: Fail{Problem{"budget","Brief final rendering exceeds 8192 UTF8 bytes"}}
    case Some{left}:
      Preview{a,p,r,n,s,e,refs,request,coverage,notices,text,_} = preview
      Done{Preview{a,p,r,n,s,e,refs,request,coverage,notices,text,U32.sub(8192,left)}}

def render_done(+packed: Packed,+anchor: Anchor,state: RequestState,heading: Layout,
  eligible: U32,+outside: U32,+partial: U32,excluded: U32,+attachments: U32,manifest: String) -> Result<&2,&2,Problem,Preview>:
  Packed{_,_,refs,included,omitted,c,p,z,x,_} = packed
  Anchor{Input{_,_,+count,_,_},_,_,source,_,_,_} = anchor
  +text = packed_text(heading,packed,outside,partial,excluded,attachments)
  sized(Activity.consume(text,8192),Preview{anchor,policy(),Request.policy(),Store.projection_version(),Domain.digest(Domain.encode(source)),
    manifest,List.reverse(&2,Evidence.Descriptor,refs),state,
    Coverage{count,count,eligible,included,omitted,outside,partial},
    [Notice{"credential_fields",c},Notice{"path_fields",p},Notice{"control_scalars",z},Notice{"request_prefix_blocks",x},Notice{"attachment_occurrences",attachments}],text,0})

def render_packed(result: Result<&2,&2,Problem,Packed>,anchor: Anchor,state: RequestState,
  heading: Layout,eligible: U32,outside: U32,partial: U32,excluded: U32,attachments: U32,manifest: String) -> Result<&2,&2,Problem,Preview>:
  match result:
    case Fail{problem}: Fail{problem}
    case Done{packed}: render_done(packed,anchor,state,heading,eligible,outside,partial,excluded,attachments,manifest)

def render_nonempty(nonempty: Bool,+anchor: Anchor,+facts: List<&2,Fact>,+state: RequestState,
  +heading: Layout,+outside: U32,+partial: U32,+excluded: U32,+attachments: U32,manifest: String) -> Result<&2,&2,Problem,Preview>:
  match nonempty:
    case False{}: Fail{Problem{"empty_scope","No eligible recorded facts in the exact range and canonical repository"}}
    case True{}:
      Anchor{_,repo,_,source,_,_,_} = anchor
      +count = U32.from_nat(List.length(&2,Fact,facts))
      render_packed(pack(arrange(facts,selected_request(state),[]),repo,source,heading,outside,partial,excluded,attachments,
        Packed{[],[],[],0,count,0,0,0,0,0}),anchor,state,heading,count,outside,partial,excluded,attachments,manifest)

def render(+anchor: Anchor,collected: Collected) -> Result<&2,&2,Problem,Preview>:
  Collected{reversed,eligible,uncertain,+excluded,outside,partial,attachments,manifest} = collected
  +facts = List.reverse(&2,Fact,reversed)
  +state = request_state(facts,eligible,uncertain,excluded)
  +heading = header(anchor,state)
  # Every candidate includes its exact final footer and omission counts.
  # At most256 candidates and8192 output bytes are admitted; no reservation
  # can reject a complete required fact that actually fits the final budget.
  render_nonempty(Bool.not(List.is_empty(&2,Fact,facts)),anchor,facts,state,heading,outside,partial,excluded,attachments,manifest)

def context_text(context: Store.Context) -> String:
  Store.Context{repo,session,model,parent} = context
  strings([repo,session,model,parent])

def incoming_text(context: Maybe<&2,Store.Context>) -> String:
  match context:
    case Some{value}: "present|" ++ context_text(value)
    case None{}: "missing"

def has_budget(value: Maybe<&2,U32>) -> Bool:
  match value:
    case Some{_}: True{}
    case None{}: False{}

def source_text(rows: List<&2,List<&2,Sql.Cell>>) -> IO(String):
  match rows:
    case [[Sql.Cell.Text{+source}]]:
      do IO<String>:
        Store.checked(scope_path(source) && has_budget(Activity.consume(source,4096)),
          "Brief canonical source locator is invalid or oversized")
        return source
    case _: IO.die(String,1,"Brief source locator is missing or has an invalid storage type")

def gathered(result: Result<&2,&2,String,Reader.Gather>,+db: U32,+anchor: Anchor,incoming: String) -> IO(Result<&2,&2,Problem,Preview>):
  match result:
    case Fail{message}: IO.pure(Result<&2,&2,Problem,Preview>,Fail{Problem{"needs_rebuild_or_smaller_range",message}})
    case Done{+gather}:
      Reader.Gather{context,_,_,_} = gather
      Anchor{Input{snapshot,start,count,_,_},repo,provider,_,generation,extent,total} = anchor
      do IO<Result<&2,&2,Problem,Preview>>:
        collected : Collected <- scan(U32.to_nat(count),db,snapshot,generation,extent,total,start,provider,repo,
          Reader.gathered_items(gather),Collected{[],0,0,0,0,0,0,chain(chain(chain("",anchor_text(anchor)),incoming),context_text(context))})
        return render(anchor,collected)

def read_range(valid: Bool,+db: U32,+input: Input,+repo: Repo.Scope,+header: Maintenance.Header) -> IO(Result<&2,&2,Problem,Preview>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,Problem,Preview>,Fail{Problem{"range","The exact selected range is outside this immutable snapshot"}})
    case True{}:
      Input{+snapshot,+start,count,scope,_} = input
      Maintenance.Header{+generation,+extent,+total,provider} = header
      do IO<Result<&2,&2,Problem,Preview>>:
        rows : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT s.locator FROM main.snapshots p JOIN main.generations g ON g.id=p.generation JOIN main.sources s ON s.id=g.source WHERE p.id=? AND p.accepted=1",
          [Sql.Cell.Integer{snapshot}],1)
        source : String <- source_text(rows)
        +incoming : Maybe<&2,Store.Context> <- Store.context_before(db,snapshot,generation,extent,total,start)
        result : Result<&2,&2,String,Reader.Gather> <- Reader.cached(incoming,db,snapshot,start,count,scope)
        gathered(result,db,Anchor{input,repo,provider,source,generation,extent,total},incoming_text(incoming))

def header_total(header: Maintenance.Header) -> U32:
  Maintenance.Header{_,_,total,_} = header
  total

def header_valid(header: Maintenance.Header) -> Bool:
  Maintenance.Header{generation,_,_,+provider} = header
  Evidence.positive_id(generation) && (String.eq(provider,"claude") || String.eq(provider,"codex"))

def transaction_read(clear: Bool,+db: U32,+input: Input,repo: Repo.Scope) -> IO(Result<&2,&2,Problem,Preview>):
  match clear:
    case False{}: IO.pure(Result<&2,&2,Problem,Preview>,Fail{Problem{"shadowed_capture","Temporary objects shadow retained capture tables; use a fresh library connection"}})
    case True{}:
      Input{snapshot,+start,+count,_,_} = input
      do IO<Result<&2,&2,Problem,Preview>>:
        +header : Maintenance.Header <- Maintenance.header(db,snapshot)
        Store.checked(header_valid(header),"Brief provider or generation identity is invalid")
        +total : U32 = header_total(header)
        read_range(U32.is_lt(start,total) && U32.is_le(count,U32.sub(total,start)),db,input,repo,header)

def transaction(started: Result<&2,&2,String,Unit>,+db: U32,input: Input,repo: Repo.Scope) -> IO(Result<&2,&2,Problem,Preview>):
  match started:
    case Fail{message}: IO.pure(Result<&2,&2,Problem,Preview>,Fail{Problem{"transaction",message}})
    case Done{_}:
      do IO<Result<&2,&2,Problem,Preview>>:
        shadow : List<&2,List<&2,Sql.Cell>> <- Store.q(db,
          "SELECT count(*) FROM temp.sqlite_master WHERE type IN('table','view') AND name COLLATE NOCASE IN('sources','generations','snapshots','raw','records','snapshot_context','events','projection_seals','search')",[],1)
        result : Result<&2,&2,Problem,Preview> <- transaction_read(String.eq(Store.field(Store.first(shadow),0n),"0"),db,input,repo)
        Store.exec(db,"ROLLBACK",[])
        return result

def repository(result: Result<&2,&2,String,Repo.Scope>,+db: U32,input: Input) -> IO(Result<&2,&2,Problem,Preview>):
  match result:
    case Fail{message}: IO.pure(Result<&2,&2,Problem,Preview>,Fail{Problem{"repository",message}})
    case Done{repo}:
      do IO<Result<&2,&2,Problem,Preview>>:
        started : Result<&2,&2,String,Unit> <- Reader.transaction(db)
        transaction(started,db,input,repo)

def prepare_valid(valid: Bool,db: U32,+input: Input) -> IO(Result<&2,&2,Problem,Preview>):
  match valid:
    case False{}: IO.pure(Result<&2,&2,Problem,Preview>,Fail{Problem{"input","Brief requires a pinned positive snapshot, exact 1..100-record range, frozen scope, and explicit repository"}})
    case True{}:
      Input{_,_,_,_,explicit} = input
      do IO<Result<&2,&2,Problem,Preview>>:
        resolved : Result<&2,&2,String,Repo.Scope> <- Repo.resolve(explicit)
        repository(resolved,db,input)

def prepare(db: U32,+input: Input) -> IO(Result<&2,&2,Problem,Preview>):
  Input{snapshot,_,+count,scope,explicit} = input
  prepare_valid(Evidence.positive_id(snapshot) && U32.is_gt(count,0) && U32.is_le(count,100) &&
    Scoped.valid(scope) && scope_path(explicit),db,input)

def references(values: List<&2,Evidence.Descriptor>) -> String:
  match values:
    case []: ""
    case value <> rest: Json.quote(descriptor_key(value)) ++ ":" ++ references(rest)

def notices(values: List<&2,Notice>) -> String:
  match values:
    case []: ""
    case Notice{kind,count} <> rest: strings([kind,U32.show(count)]) ++ notices(rest)

def coverage_text(coverage: Coverage) -> String:
  Coverage{a,b,c,d,e,f,g} = coverage
  strings([U32.show(a),U32.show(b),U32.show(c),U32.show(d),U32.show(e),U32.show(f),U32.show(g)])

# Include every public Preview field. A forged field is never ignored just
# because its text or a cached digest happens to match a fresh preparation.
def preview_text(preview: Preview) -> String:
  Preview{anchor,p,r,n,s,e,refs,request,coverage,seen,text,bytes} = preview
  "juice-bend-brief-preview-v1|" ++ strings([anchor_text(anchor),p,r,n,s,e,references(refs),
    request_key(request),coverage_text(coverage),notices(seen),text,U32.show(bytes)])

def compared(result: Result<&2,&2,Problem,Preview>,+previous: Preview) -> Result<&2,&2,Problem,String>:
  match result:
    case Fail{problem}: Fail{problem}
    case Done{fresh}:
      Preview{_,_,_,_,_,_,_,_,_,_,text,_} = previous
      Bool.pick(Result<&2,&2,Problem,String>,String.eq(preview_text(previous),preview_text(fresh)),
        Done{text},Fail{Problem{"stale","Pinned evidence, scope, repository, policy or preview changed; prepare a new brief before copying"}})

def revalidate(db: U32,+preview: Preview) -> IO(Result<&2,&2,Problem,String>):
  Preview{Anchor{input,_,_,_,_,_,_},_,_,_,_,_,_,_,_,_,_,_} = preview
  do IO<Result<&2,&2,Problem,String>>:
    fresh : Result<&2,&2,Problem,Preview> <- prepare(db,input)
    return compared(fresh,preview)
