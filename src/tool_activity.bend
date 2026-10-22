import Base
import ./providers.bend as Providers
import ./evidence.bend as Evidence
import ./domain.bend as Domain
import ./provenance.bend as P
import ./json.bend as Json

# Pure presentation of a caller-verified, contextualized selected page. This
# module never reads storage, verifies raw bytes, executes a tool or infers a
# result. Citations remain occurrence identities, including snapshot/extent.
type Occurrence is Data:
  Occurrence{citation: Evidence.Descriptor, record: Providers.Record}

type ActivityKind is Data:
  ToolCall{}
  ToolResult{}
  Coverage{}

type Link is Data:
  Unique{peer: Evidence.Descriptor}
  NoId{}
  UnknownIdentity{}
  UncertainId{}
  CounterpartAbsent{}
  Ambiguous{calls: U32, results: U32}
  UncertainShape{occurrences: U32}
  OrderConflict{}
  CoverageOnly{}

type Row is Data:
  Row{occurrence: Occurrence, kind: ActivityKind, link: Link}

type Stats is Data:
  Stats{events: U32, calls: U32, results: U32, pairs: U32, tool_errors: U32,
    coverage: U32, unpaired: U32}

type Page is Data:
  Page{rows: List<&2,Row>, stats: Stats}

def record(occurrence: Occurrence) -> Providers.Record:
  Occurrence{_,record} = occurrence
  record

def citation(occurrence: Occurrence) -> Evidence.Descriptor:
  Occurrence{citation,_} = occurrence
  citation

def descriptor_text(value: Evidence.Descriptor) -> String:
  Evidence.Descriptor{Domain.EvidenceKey{provider,source,generation,snapshot,ordinal,_},extent,_,event} = value
  Evidence.citation(Evidence.Verified{provider,source,generation,snapshot,extent,ordinal,[]},event)

def descriptor_strings(value: Evidence.Descriptor) -> List<&2,String>:
  Evidence.Descriptor{Domain.EvidenceKey{provider,source,generation,snapshot,ordinal,event},extent,_,_} = value
  [provider,source,generation,snapshot,ordinal,event,extent]

def record_strings(value: Providers.Record) -> List<&2,String>:
  Providers.ProviderEvent{role,text,tool,id,args,result,repo,session,time,model,usage,parent,coverage} = value
  [role,text,tool,id,args,result,repo,session,time,model,usage,parent,coverage]

def numeric(+text: String) -> Bool:
  P.decimal_valid(text) && Bool.not(Cmp.is_gt(P.decimal_compare(text,"4294967295")))

def descriptor_valid(value: Evidence.Descriptor) -> Bool:
  Evidence.Descriptor{Domain.EvidenceKey{+provider,+source,generation,snapshot,ordinal,event},extent,n,e} = value
  (String.eq(provider,"claude") || String.eq(provider,"codex")) &&
    Bool.not(String.is_empty(source)) && Nat.is_le(String.length(source),4096n) &&
    Evidence.positive_id(generation) && Evidence.positive_id(snapshot) && numeric(extent) &&
    String.eq(ordinal,U32.show(n)) && String.eq(event,U32.show(e))

def same_citation(a: Evidence.Descriptor,b: Evidence.Descriptor) -> Bool:
  Evidence.Descriptor{key,extent,_,_} = a
  Evidence.Descriptor{other,other_extent,_,_} = b
  Domain.ref_equal(key,other)

def repeated(+key: Evidence.Descriptor,items: List<&2,Occurrence>) -> Bool:
  match items:
    case []:
      False{}
    case item <> rest:
      same_citation(key,citation(item)) || repeated(key,rest)

# All limits count actual UTF-8 bytes, not characters or provider field sizes.
def byte_step(valid: Bool,budget: U32,next: U32 -> Maybe<&2,U32>) -> Maybe<&2,U32>:
  match valid:
    case False{}:
      None{}
    case True{}:
      next(budget)

def consume(text: String,+budget: U32) -> Maybe<&2,U32>:
  match text:
    case SNil{}:
      Some{budget}
    case SCon{Chr{+cp},rest}:
      +size = U32.inc(Domain.encode_width(cp))
      byte_step(Domain.scalar(cp) && U32.is_le(size,budget),U32.sub(budget,size),left => consume(rest,left))

def consume_next(left: Maybe<&2,U32>,next: U32 -> Maybe<&2,U32>) -> Maybe<&2,U32>:
  match left:
    case None{}:
      None{}
    case Some{budget}:
      next(budget)

def consume_fields(fields: List<&2,String>,budget: U32) -> Maybe<&2,U32>:
  match fields:
    case []:
      Some{budget}
    case text <> rest:
      consume_next(consume(text,budget),left => consume_fields(rest,left))

def validation_step(valid: Bool,left: Maybe<&2,U32>,next: U32 -> Result<&2,&2,String,Unit>) -> Result<&2,&2,String,Unit>:
  match valid left:
    case False{} _:
      Fail{"Tool activity requires valid, distinct immutable occurrence citations"}
    case _ None{}:
      Fail{"Tool activity page exceeds 524288 UTF-8 bytes or contains an invalid scalar; no content was truncated"}
    case True{} Some{budget}:
      next(budget)

def validate(items: List<&2,Occurrence>,fuel: Nat,budget: U32) -> Result<&2,&2,String,Unit>:
  match items fuel:
    case Nil{} _:
      Done{Unit{}}
    case _ 0n:
      Fail{"Tool activity page exceeds 256 events; choose a smaller page"}
    case Con{+item,+rest} 1n+left:
      validation_step(descriptor_valid(citation(item)) && Bool.not(repeated(citation(item),rest)),
        consume_fields(List.append(&2,String,descriptor_strings(citation(item)),record_strings(record(item))),budget),
        remaining => validate(rest,left,remaining))

def recognized_coverage(+coverage: String) -> Bool:
  String.eq(coverage,"complete") || String.eq(coverage,"tool_error") ||
    String.eq(coverage,"metadata") || String.eq(coverage,"metadata_context")

def kind_role(+role: String,+value: Providers.Record) -> Maybe<&2,ActivityKind>:
  match role:
    case "tool":
      Bool.pick(Maybe<&2,ActivityKind>,String.is_empty(Providers.tool(value)) && String.is_empty(Providers.arguments(value)),
        Some{ToolResult{}},Some{Coverage{}})
    case "assistant":
      Bool.pick(Maybe<&2,ActivityKind>,Bool.not(String.is_empty(Providers.tool(value))) && String.is_empty(Providers.result(value)),
        Some{ToolCall{}},Bool.pick(Maybe<&2,ActivityKind>,Bool.not(String.is_empty(Providers.call_id(value))) ||
          Bool.not(String.is_empty(Providers.arguments(value))) || Bool.not(String.is_empty(Providers.result(value))) ||
          Bool.not(recognized_coverage(Providers.coverage(value))),Some{Coverage{}},None{}))
    case _:
      Bool.pick(Maybe<&2,ActivityKind>,String.eq(role,"unsupported") || String.eq(role,"error") ||
        Bool.not(recognized_coverage(Providers.coverage(value))) || Bool.not(String.is_empty(Providers.tool(value))) ||
        Bool.not(String.is_empty(Providers.call_id(value))) || Bool.not(String.is_empty(Providers.arguments(value))) ||
        Bool.not(String.is_empty(Providers.result(value))),Some{Coverage{}},None{})

def kind(+value: Providers.Record) -> Maybe<&2,ActivityKind>:
  kind_role(Providers.role(value),value)

def same_capture(a: Evidence.Descriptor,b: Evidence.Descriptor) -> Bool:
  Evidence.Descriptor{Domain.EvidenceKey{p,s,g,n,_,_},extent,_,_} = a
  Evidence.Descriptor{Domain.EvidenceKey{pp,ss,gg,nn,_,_},other_extent,_,_} = b
  String.eq(p,pp) && String.eq(s,ss) && String.eq(g,gg) && String.eq(n,nn) && String.eq(extent,other_extent)

def same_identity(+a: Occurrence,+b: Occurrence) -> Bool:
  same_capture(citation(a),citation(b)) &&
    String.eq(Providers.session(record(a)),Providers.session(record(b))) &&
    String.eq(Providers.repository(record(a)),Providers.repository(record(b)))

def known_identity(+item: Occurrence) -> Bool:
  Bool.not(String.is_empty(String.trim(Providers.session(record(item))))) &&
    String.starts_with(Providers.repository(record(item)),"/") &&
    Bool.not(String.contains(Providers.repository(record(item)),"\0"))

# Providers.Record retains normalized strings, not the raw JSON field types.
# Withhold unusual IDs that could be coerced scalars/containers until a future
# verified-raw adapter can supply typed identity metadata. Do not guess that an
# all-numeric recorded string ID was really a string in the captured source.
def identifier_shape(parsed: Result<&2,&2,String,Json.Json>) -> Bool:
  match parsed:
    case Done{Json.JString{_}}:
      False{}
    case Done{_}:
      True{}
    case Fail{_}:
      False{}

def uncertain_identifier(+text: String) -> Bool:
  +trimmed = String.trim(text)
  String.starts_with(trimmed,"[") || String.starts_with(trimmed,"{") || identifier_shape(Json.parse(text))

def same_group(+a: Occurrence,+b: Occurrence) -> Bool:
  same_identity(a,b) && String.eq(Providers.call_id(record(a)),Providers.call_id(record(b)))

type Matches is Data:
  Matches{calls: U32, results: U32, uncertain: U32, call: Maybe<&2,Evidence.Descriptor>, result: Maybe<&2,Evidence.Descriptor>}

def add_match(found: Matches,kind: Maybe<&2,ActivityKind>,key: Evidence.Descriptor) -> Matches:
  Matches{calls,results,uncertain,call,result} = found
  match kind:
    case Some{ToolCall{}}:
      Matches{U32.inc(calls),results,uncertain,Some{key},result}
    case Some{ToolResult{}}:
      Matches{calls,U32.inc(results),uncertain,call,Some{key}}
    case Some{Coverage{}}:
      Matches{calls,results,U32.inc(uncertain),call,result}
    case _:
      Matches{calls,results,uncertain,call,result}

def match_if(found: Matches,+item: Occurrence,valid: Bool) -> Matches:
  match valid:
    case True{}:
      add_match(found,kind(record(item)),citation(item))
    case False{}:
      found

def matches(+target: Occurrence,items: List<&2,Occurrence>,found: Matches) -> Matches:
  match items:
    case []:
      found
    case +item <> rest:
      matches(target,rest,match_if(found,item,same_group(target,item)))

def before(a: Evidence.Descriptor,b: Evidence.Descriptor) -> Bool:
  Evidence.Descriptor{_,_,+ordinal,event} = a
  Evidence.Descriptor{_,_,+other,other_event} = b
  U32.is_lt(ordinal,other) || (U32.is_eq(ordinal,other) && U32.is_lt(event,other_event))

def ordered_link(kind: ActivityKind,call: Evidence.Descriptor,result: Evidence.Descriptor,valid: Bool) -> Link:
  match kind valid:
    case _ False{}:
      OrderConflict{}
    case ToolCall{} True{}:
      Unique{result}
    case _ True{}:
      Unique{call}

def unmatched(+calls: U32,+results: U32,uncertain: U32,unclear: Bool) -> Link:
  match unclear:
    case True{}:
      UncertainShape{uncertain}
    case False{}:
      Bool.pick(Link,U32.is_gt(calls,1) || U32.is_gt(results,1),Ambiguous{calls,results},CounterpartAbsent{})

def matched_link(kind: ActivityKind,found: Matches) -> Link:
  match found:
    case Matches{1,1,0,Some{+call},Some{+result}}:
      ordered_link(kind,call,result,before(call,result))
    case Matches{calls,results,+uncertain,_,_}:
      unmatched(calls,results,uncertain,U32.is_gt(uncertain,0))

def typed_link(kind: ActivityKind,item: Occurrence,items: List<&2,Occurrence>,uncertain: Bool) -> Link:
  match uncertain:
    case True{}:
      UncertainId{}
    case False{}:
      matched_link(kind,matches(item,items,Matches{0,0,0,None{},None{}}))

def identified_link(kind: ActivityKind,+item: Occurrence,items: List<&2,Occurrence>,known: Bool,no_id: Bool) -> Link:
  match known no_id:
    case _ True{}:
      NoId{}
    case False{} _:
      UnknownIdentity{}
    case True{} False{}:
      typed_link(kind,item,items,uncertain_identifier(Providers.call_id(record(item))) ||
        uncertain_identifier(Providers.session(record(item))))

def link(kind: ActivityKind,+item: Occurrence,items: List<&2,Occurrence>) -> Link:
  match kind:
    case Coverage{}:
      CoverageOnly{}
    case other:
      identified_link(other,item,items,known_identity(item),String.is_empty(Providers.call_id(record(item))))

def row_next(+item: Occurrence,kind: Maybe<&2,ActivityKind>,items: List<&2,Occurrence>,rest: List<&2,Row>) -> List<&2,Row>:
  match kind:
    case None{}:
      rest
    case Some{+value}:
      Row{item,value,link(value,item,items)} <> rest

def rows(remaining: List<&2,Occurrence>,+all: List<&2,Occurrence>) -> List<&2,Row>:
  match remaining:
    case []:
      []
    case +item <> rest:
      row_next(item,kind(record(item)),all,rows(rest,all))

def is_unique(value: Link) -> Bool:
  match value:
    case Unique{_}:
      True{}
    case _:
      False{}

def error_first(parts: List<&2,String>) -> Bool:
  match parts:
    case []:
      False{}
    case first <> _:
      String.eq(String.trim(first),"tool_error")

def explicit_error(value: String) -> Bool:
  error_first(String.split(value,';'))

def stats_kind(stats: Stats,kind: ActivityKind,+link: Link,+gap: Bool,+error: Bool) -> Stats:
  Stats{events,calls,results,pairs,errors,coverage,unpaired} = stats
  match kind:
    case ToolCall{}:
      Stats{events,U32.inc(calls),results,U32.add(pairs,Bool.to_u32(is_unique(link))),
        U32.add(errors,Bool.to_u32(error)),U32.add(coverage,Bool.to_u32(gap)),U32.add(unpaired,Bool.to_u32(Bool.not(is_unique(link))))}
    case ToolResult{}:
      Stats{events,calls,U32.inc(results),pairs,U32.add(errors,Bool.to_u32(error)),
        U32.add(coverage,Bool.to_u32(gap)),U32.add(unpaired,Bool.to_u32(Bool.not(is_unique(link))))}
    case Coverage{}:
      Stats{events,calls,results,pairs,U32.add(errors,Bool.to_u32(error)),U32.inc(coverage),unpaired}

def stats_row(stats: Stats,row: Row) -> Stats:
  Row{item,kind,link} = row
  +value = record(item)
  stats_kind(stats,kind,link,Bool.not(recognized_coverage(Providers.coverage(value))),explicit_error(Providers.coverage(value)))

def stats(rows: List<&2,Row>,value: Stats) -> Stats:
  match rows:
    case []:
      value
    case row <> rest:
      stats(rest,stats_row(value,row))

def analyzed(+items: List<&2,Occurrence>,valid: Result<&2,&2,String,Unit>) -> Result<&2,&2,String,Page>:
  match valid:
    case Fail{message}:
      Fail{message}
    case Done{_}:
      +result = rows(items,items)
      Done{Page{result,stats(result,Stats{U32.from_nat(List.length(&2,Occurrence,items)),0,0,0,0,0,0})}}

def event_limit(items: List<&2,Occurrence>,fuel: Nat) -> Bool:
  match items fuel:
    case Nil{} _:
      True{}
    case _ 0n:
      False{}
    case Con{_,rest} 1n+n:
      event_limit(rest,n)

def analyze_bounded(+items: List<&2,Occurrence>,bounded: Bool) -> Result<&2,&2,String,Page>:
  match bounded:
    case False{}:
      Fail{"Tool activity page exceeds 256 events; choose a smaller page"}
    case True{}:
      analyzed(items,validate(items,256n,524288))

def analyze(+items: List<&2,Occurrence>) -> Result<&2,&2,String,Page>:
  analyze_bounded(items,event_limit(items,256n))

def kind_text(kind: ActivityKind) -> String:
  match kind:
    case ToolCall{}:
      "Recorded tool call"
    case ToolResult{}:
      "Recorded tool result"
    case Coverage{}:
      "Coverage / unsupported occurrence"

def link_text(link: Link) -> String:
  match link:
    case Unique{peer}:
      "Unique counterpart in this selected page: " ++ descriptor_text(peer)
    case NoId{}:
      "Unpaired: no recorded call ID; a counterpart may be outside this selected page."
    case UnknownIdentity{}:
      "Unpaired: recorded session or absolute repository identity is incomplete; no actor match was inferred."
    case UncertainId{}:
      "Unpaired: normalized call/session ID can represent a non-string JSON value; raw field type is unavailable, so identity matching is withheld."
    case CounterpartAbsent{}:
      "Unpaired: counterpart is not in this selected page; it may exist elsewhere."
    case Ambiguous{calls,results}:
      "Ambiguous in this selected page: " ++ U32.show(calls) ++ " call occurrences and " ++ U32.show(results) ++ " result occurrences share this scoped call ID."
    case UncertainShape{occurrences}:
      "Unpaired: " ++ U32.show(occurrences) ++ " unsupported tool-shaped occurrences share this scoped call ID; uniqueness is unknown."
    case OrderConflict{}:
      "Unpaired: result precedes call in captured occurrence order; no chronological match was inferred."
    case CoverageOnly{}:
      "Unsupported or partial occurrence retained; no tool pairing was inferred."

def optional(label: String,value: String) -> String:
  match value:
    case "":
      ""
    case text:
      label ++ ": " ++ Json.quote(text) ++ "\n"

# A short status precedes payloads. The complete explanation and immutable
# counterpart descriptor remain in the numbered evidence section below.
def link_summary(link: Link) -> String:
  match link:
    case Unique{_}:
      "Paired within this selected page."
    case NoId{}:
      "Unpaired: no recorded call ID."
    case UnknownIdentity{}:
      "Unpaired: actor/repository incomplete."
    case UncertainId{}:
      "Unpaired: recorded ID type uncertain."
    case CounterpartAbsent{}:
      "Unpaired: counterpart not in this page."
    case Ambiguous{calls,results}:
      "Ambiguous: " ++ U32.show(calls) ++ " calls / " ++ U32.show(results) ++ " results in page."
    case UncertainShape{occurrences}:
      "Unpaired: " ++ U32.show(occurrences) ++ " unsupported same-ID occurrences."
    case OrderConflict{}:
      "Unpaired: result precedes call."
    case CoverageOnly{}:
      "Unsupported/partial captured occurrence."

def row_text(row: Row) -> String:
  Row{Occurrence{key,value},kind,link} = row
  Providers.ProviderEvent{role,text,tool,id,args,result,repo,session,time,model,usage,parent,coverage} = value
  kind_text(kind) ++ " | Tool: " ++ Json.quote(tool) ++ "\n" ++ link_summary(link) ++ "\n" ++
    Bool.pick(String,explicit_error(coverage),"Recorded tool_error: true\n","") ++
    "Captured arguments (JSON string): " ++ Json.quote(args) ++ "\n" ++
    "Captured result (JSON string): " ++ Json.quote(result) ++ "\n" ++
    optional("Captured text",text) ++ "\n"

def row_details(row: Row) -> String:
  Row{Occurrence{key,value},kind,link} = row
  Providers.ProviderEvent{role,text,tool,id,args,result,repo,session,time,model,usage,parent,+coverage} = value
  "Citation: " ++ descriptor_text(key) ++ "\n" ++ link_text(link) ++ "\n" ++
    "Recorded role: " ++ Json.quote(role) ++ "\nSession: " ++ Json.quote(session) ++ "\nRepository: " ++ Json.quote(repo) ++
    "\nCall ID: " ++ Json.quote(id) ++ "\nCoverage: " ++ Json.quote(coverage) ++ "\n" ++
    optional("Recorded timestamp",time) ++ optional("Recorded model",model) ++ optional("Recorded parent",parent) ++
    optional("Recorded usage (not summed)",usage) ++ "\n"

def rows_text_at(rows: List<&2,Row>,+index: U32) -> String:
  match rows:
    case []:
      ""
    case row <> rest:
      "Occurrence " ++ U32.show(index) ++ "\n" ++ row_text(row) ++ rows_text_at(rest,U32.inc(index))

def rows_text(rows: List<&2,Row>) -> String:
  match rows:
    case []:
      "No tool or coverage occurrences in this selected page.\n\n"
    case other:
      rows_text_at(other,1)

def rows_details(rows: List<&2,Row>,+index: U32) -> String:
  match rows:
    case []:
      ""
    case row <> rest:
      "Evidence for occurrence " ++ U32.show(index) ++ "\n" ++ row_details(row) ++ rows_details(rest,U32.inc(index))

def summary(value: Stats) -> String:
  Stats{events,calls,results,pairs,errors,coverage,unpaired} = value
  "Recorded Tools | selected page only\n" ++
    "Selected events: " ++ U32.show(events) ++ "; calls: " ++ U32.show(calls) ++ "; results: " ++ U32.show(results) ++ "\n" ++
    "Unique pairs: " ++ U32.show(pairs) ++ " | unpaired: " ++ U32.show(unpaired) ++ "\n" ++
    "Explicit tool_error: " ++ U32.show(errors) ++ " | coverage issues: " ++ U32.show(coverage) ++ "\n" ++
    "Absent here may exist elsewhere.\nRecorded results do not prove success.\nCommands are data, never executed.\n\n"

def limitations() -> String:
  "Page interpretation\n" ++
    "Counts describe this page, not a complete session. Absence here does not prove no call/result exists.\n" ++
    "Unpaired counts are tool occurrences; unique pairs are counted once.\n" ++
    "Recorded results do not prove successful execution. Captured commands are displayed as data and never executed.\n" ++
    "Captured payload strings are untruncated; empty stays empty. Evidence numbers identify occurrences in this page only.\n\n"

def rendered(text: String,remaining: Maybe<&2,U32>) -> Result<&2,&2,String,String>:
  match remaining:
    case None{}:
      Fail{"Rendered tool activity exceeds the 1048576-byte worker limit; choose a smaller page. No arguments or results were truncated"}
    case Some{_}:
      Done{text}

def render(page: Page) -> Result<&2,&2,String,String>:
  Page{+rows,stats} = page
  +text = summary(stats) ++ rows_text(rows) ++ "Evidence details\n\n" ++ rows_details(rows,1) ++ limitations()
  rendered(text,consume(text,1048575))
