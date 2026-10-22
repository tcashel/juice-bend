import Base
import ./json.bend as Json
import ./gui_relations.bend as R
import ./gui_files.bend as F
import ./query.bend as Query
import ./provenance.bend as P
import ./result_link.bend as Link

type ResultEvent is Data:
  ResultEvent{record: U32,event: U32,status: String,id: String,call: String,reason: String}

type Cursor is Data:
  Cursor{record: U32,event: U32}

type Events is Data:
  Events{reference: R.Reference,start: U32,count: U32,cursor: Cursor,next: Cursor,
    more: Bool,rows: List<&2,ResultEvent>,text: String}

type Candidates is Data:
  Candidates{watermark: String,after: String,next: String,rows: List<&2,R.Row>,text: String}

type Model is Data:
  Model{phase: U32,expected: List<&2,String>,events: Maybe<&2,Events>,selected: Maybe<&2,ResultEvent>,
    candidates: Maybe<&2,Candidates>,previous: List<&2,Cursor>,target: Maybe<&2,R.Reference>}

def empty() -> Model:
  Model{0,[],None{},None{},None{},[],None{}}

def numeric(+value: Json.Json,+key: String,expected: U32) -> Bool:
  F.number_valid(Json.field(value,key)) && U32.is_eq(F.number(Json.get(value,key)),expected)

def citation(+value: Json.Json,+reference: R.Reference,record: U32,event: U32) -> Bool:
  R.reference_valid(value) && R.same(R.reference(value),reference) &&
    F.text_valid(Json.field(value,"record")) && F.text_valid(Json.field(value,"event")) &&
    String.eq(Json.get(value,"record"),U32.show(record)) && String.eq(Json.get(value,"event"),U32.show(event))

def recorded(+value: Json.Json) -> Bool:
  +kind = Json.get(value,"kind")
  R.object(value) && R.text(Json.field(value,"reason")) &&
    ((String.eq(kind,"recorded") && F.text_valid(Json.field(value,"agent_id")) &&
      Link.safe_id(Json.get(value,"agent_id")) && R.text(Json.field(value,"tool_use_id"))) ||
     String.eq(kind,"missing") || String.eq(kind,"unsupported") || String.eq(kind,"ambiguous"))

def event(+value: Json.Json) -> ResultEvent:
  +r = Json.field(value,"recorded")
  ResultEvent{F.number(Json.get(value,"record")),F.number(Json.get(value,"event")),Json.get(r,"kind"),
    Json.get(r,"agent_id"),Json.get(r,"tool_use_id"),Json.get(r,"reason")}

def same_event(a: ResultEvent,b: ResultEvent) -> Bool:
  ResultEvent{ar,ae,ak,ai,ac,_} = a
  ResultEvent{br,be,bk,bi,bc,_} = b
  U32.is_eq(ar,br) && U32.is_eq(ae,be) && String.eq(ak,bk) && String.eq(ai,bi) && String.eq(ac,bc)

def cursor_after(a: Cursor,b: Cursor) -> Bool:
  Cursor{+ar,ae} = a
  Cursor{+br,be} = b
  U32.is_gt(ar,br) || (U32.is_eq(ar,br) && U32.is_gt(ae,be))

def row_valid(+value: Json.Json,+reference: R.Reference,+start: U32,+count: U32,+cursor: Cursor) -> Bool:
  +record = F.number(Json.get(value,"record"))
  +slot = F.number(Json.get(value,"event"))
  R.object(value) && R.numbers(value,["record","event"]) && U32.is_ge(record,start) &&
    U32.is_lt(record,U32.add(start,count)) && U32.is_le(slot,262144) &&
    Bool.not(cursor_after(cursor,Cursor{record,slot})) && recorded(Json.field(value,"recorded")) &&
    citation(Json.field(value,"citation"),reference,record,slot)

def events_valid(values: List<&2,Json.Json>,+reference: R.Reference,+start: U32,+count: U32,
  +cursor: Cursor) -> Bool:
  match values:
    case []: True{}
    case +head <> rest:
      row_valid(head,reference,start,count,cursor) &&
        events_valid(rest,reference,start,count,Cursor{F.number(Json.get(head,"record")),U32.inc(F.number(Json.get(head,"event")))})

def events(values: List<&2,Json.Json>) -> List<&2,ResultEvent>:
  match values:
    case []: []
    case head <> rest: event(head) <> events(rest)

def rows_before(values: List<&2,Json.Json>,+next: Cursor) -> Bool:
  match values:
    case []: True{}
    case +head <> rest:
      cursor_after(next,Cursor{F.number(Json.get(head,"record")),F.number(Json.get(head,"event"))}) && rows_before(rest,next)

def list_valid(+value: Json.Json,+snapshot: String,+start: U32,+count: U32,+cursor: Cursor,
  filters: Query.Filters) -> Bool:
  Cursor{record,slot} = cursor
  +reference = Json.field(value,"reference")
  +next = {Cursor{F.number(Json.get(value,"next_record")),F.number(Json.get(value,"next_event"))} : Cursor}
  R.object(value) && String.eq(Json.get(value,"kind"),"recorded_child_events") && R.reference_valid(reference) &&
    String.eq(Json.get(reference,"provider"),"claude") && String.eq(Json.get(reference,"snapshot"),snapshot) &&
    numeric(value,"start",start) && numeric(value,"count",count) && numeric(value,"record",record) && numeric(value,"event",slot) &&
    R.numbers(value,["next_record","next_event","scanned_records","inspected_bytes","unavailable_records"]) &&
    U32.is_le(F.number(Json.get(value,"next_record")),U32.add(start,count)) &&
    U32.is_le(F.number(Json.get(value,"next_event")),262144) &&
    U32.is_le(F.number(Json.get(value,"scanned_records")),10) && U32.is_le(F.number(Json.get(value,"inspected_bytes")),2097152) &&
    U32.is_le(F.number(Json.get(value,"unavailable_records")),F.number(Json.get(value,"scanned_records"))) &&
    Bool.not(cursor_after(cursor,next)) && rows_before(Json.items(Json.field(value,"rows")),next) &&
    (String.eq(Json.get(value,"more"),"true") || numeric(value,"next_event",0)) &&
    R.boolean(Json.field(value,"more")) && (Bool.not(String.eq(Json.get(value,"more"),"true")) || cursor_after(next,cursor)) &&
    R.scope_valid(Json.field(value,"scope"),filters) && R.array(Json.field(value,"rows")) &&
    Nat.is_le(List.length(&2,Json.Json,Json.items(Json.field(value,"rows"))),20n) &&
    events_valid(Json.items(Json.field(value,"rows")),R.reference(reference),start,count,cursor) &&
    F.text_valid(Json.field(value,"text")) && R.fits(Json.get(value,"text"),1048575)

def list_checked(yes: Bool,+value: Json.Json) -> Result<&2,&2,String,Events>:
  match yes:
    case False{}: Fail{"Child result list did not match its captured range, typed events, scope or cursor; original reader is retained."}
    case True{}:
      Done{Events{R.reference(Json.field(value,"reference")),F.number(Json.get(value,"start")),F.number(Json.get(value,"count")),
        Cursor{F.number(Json.get(value,"record")),F.number(Json.get(value,"event"))},
        Cursor{F.number(Json.get(value,"next_record")),F.number(Json.get(value,"next_event"))},
        String.eq(Json.get(value,"more"),"true"),events(Json.items(Json.field(value,"rows"))),Json.get(value,"text")}}

def decode_events(+value: Json.Json,snapshot: String,start: U32,count: U32,cursor: Cursor,filters: Query.Filters) -> Result<&2,&2,String,Events>:
  list_checked(list_valid(value,snapshot,start,count,cursor,filters),value)

# Selected facts use the exact selected raw ordinal, not a prefix index. Candidate
# facts retain the existing bounded-prefix validator unchanged.
def selected_identity(+value: Json.Json,ordinal: U32,repo: Bool) -> Bool:
  +kind = Json.get(value,"kind")
  R.object(value) && ((String.eq(kind,"known") && numeric(value,"record",ordinal) &&
    Bool.pick(Bool,repo,R.path(Json.field(value,"value")),R.nonempty(Json.field(value,"value")))) ||
    String.eq(kind,"missing") || ((String.eq(kind,"conflicting") || String.eq(kind,"invalid")) && R.nonempty(Json.field(value,"reason"))))

def selected_parent(+value: Json.Json,+ordinal: U32) -> Bool:
  R.parent_valid(value,U32.inc(ordinal)) &&
    (Bool.not(String.eq(Json.get(value,"kind"),"recorded")) || numeric(value,"record",ordinal))

def facts_supported(+value: Json.Json) -> Bool:
  +session = Json.get(Json.field(value,"session"),"kind")
  +repo = Json.get(Json.field(value,"repository"),"kind")
  +parent = Json.get(Json.field(value,"parent"),"kind")
  Bool.not(String.eq(session,"invalid") || String.eq(session,"conflicting") ||
    String.eq(repo,"invalid") || String.eq(repo,"conflicting") ||
    String.eq(parent,"unsupported") || String.eq(parent,"conflicting"))

def selected_facts(+value: Json.Json,+reference: R.Reference,+ordinal: U32) -> Bool:
  R.object(value) && R.reference_valid(Json.field(value,"reference")) && R.same(R.reference(Json.field(value,"reference")),reference) &&
    numeric(value,"inspected",1) && R.numbers(value,["total_records","bytes"]) &&
    U32.is_lt(ordinal,F.number(Json.get(value,"total_records"))) && U32.is_le(F.number(Json.get(value,"bytes")),2097152) &&
    selected_parent(Json.field(value,"parent"),ordinal) &&
    selected_identity(Json.field(value,"session"),ordinal,False{}) && selected_identity(Json.field(value,"repository"),ordinal,True{}) &&
    R.boolean(Json.field(value,"complete")) && R.text(Json.field(value,"coverage"))

def selected_valid(+value: Json.Json,+reference: R.Reference,+expected: ResultEvent,filters: Query.Filters) -> Bool:
  ResultEvent{+record,+slot,_,_,_,_} = expected
  R.object(value) && R.reference_valid(Json.field(value,"reference")) && R.same(R.reference(Json.field(value,"reference")),reference) &&
    numeric(value,"record",record) && numeric(value,"event",slot) && R.scope_valid(Json.field(value,"scope"),filters) &&
    recorded(Json.field(value,"recorded")) && (same_event(event(value),expected) || String.eq(Json.get(Json.field(value,"recorded"),"kind"),"unsupported")) &&
    citation(Json.field(value,"citation"),reference,record,slot) && selected_facts(Json.field(value,"facts"),reference,record) &&
    R.numbers(value,["selected_and_predecessor_bytes"]) && U32.is_le(F.number(Json.get(value,"selected_and_predecessor_bytes")),524288)

def candidate_valid(+value: Json.Json,+selected: Json.Json,+watermark: String,+repository: String,+ambiguous: Bool) -> Bool:
  +target = Json.field(value,"target")
  +ref = Json.field(selected,"reference")
  +target_ref = Json.field(target,"reference")
  +repo = Json.field(Json.field(selected,"facts"),"repository")
  R.object(value) && R.facts_valid(target) && R.boolean(Json.field(value,"ambiguous_on_page")) &&
    U32.is_eq(Bool.to_u32(String.eq(Json.get(value,"ambiguous_on_page"),"true")),Bool.to_u32(ambiguous)) &&
    String.eq(Json.get(value,"direction"),"child") && String.eq(Json.get(value,"basis"),"recorded_tool_result_agent_id") &&
    R.reference_valid(Json.field(value,"witness")) && R.same(R.reference(Json.field(value,"witness")),R.reference(ref)) &&
    numeric(value,"record",F.number(Json.get(selected,"record"))) &&
    String.eq(Json.get(Json.field(selected,"recorded"),"kind"),"recorded") &&
    Bool.not(String.eq(Json.get(ref,"source"),Json.get(target_ref,"source"))) &&
    facts_supported(target) && facts_supported(Json.field(selected,"facts")) &&
    Bool.not(String.eq(Json.get(Json.field(target,"parent"),"kind"),"conflicting")) &&
    Bool.not(String.eq(Json.get(Json.field(target,"parent"),"kind"),"unsupported")) &&
    Link.target(Json.get(ref,"source"),Json.get(Json.field(selected,"recorded"),"agent_id"),Json.get(target_ref,"source")) &&
    String.eq(Json.get(target_ref,"provider"),"claude") &&
    String.eq(Json.get(repo,"kind"),"known") && String.eq(Json.get(Json.field(target,"repository"),"kind"),"known") &&
    String.eq(Json.get(repo,"value"),Json.get(Json.field(target,"repository"),"value")) &&
    (String.is_empty(repository) || String.eq(Json.get(repo,"value"),repository)) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(Json.get(target_ref,"snapshot"),watermark)))

def candidates_valid(rows: List<&2,Json.Json>,+selected: Json.Json,+watermark: String,+repo: String,+ambiguous: Bool) -> Bool:
  match rows:
    case []: True{}
    case row <> rest: candidate_valid(row,selected,watermark,repo,ambiguous) && candidates_valid(rest,selected,watermark,repo,ambiguous)

def complete_valid(+value: Json.Json) -> Bool:
  +coverage = Json.field(value,"coverage")
  +complete = R.null(Json.field(value,"next_source")) && numeric(coverage,"unknown",0) &&
    numeric(coverage,"conflicting",0) && numeric(coverage,"unsupported",0) &&
    numeric(coverage,"partial",0) && numeric(coverage,"unexamined_budget",0)
  U32.is_eq(Bool.to_u32(complete),Bool.to_u32(String.eq(Json.get(value,"page_metadata_complete"),"true")))

def candidate_page_valid(+value: Json.Json,+reference: R.Reference,selected: ResultEvent,+filters: Query.Filters,
  +watermark: String,+after: String) -> Bool:
  Query.Filters{_,_,repo,_,_} = filters
  +rows = Json.items(Json.field(value,"rows"))
  +wm = Json.get(value,"watermark")
  R.object(value) && String.eq(Json.get(value,"kind"),"recorded_child_result") &&
    selected_valid(Json.field(value,"selected"),reference,selected,filters) &&
    R.id(Json.field(value,"watermark")) && (String.is_empty(watermark) || String.eq(watermark,wm)) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(R.snapshot(reference),wm))) &&
    R.cursor(Json.field(value,"after_source")) && String.eq(Json.get(value,"after_source"),after) &&
    R.next_valid(Json.field(value,"next_source"),after,F.number(Json.get(value,"scanned_sources"))) &&
    numeric(value,"limit",15) && R.numbers(value,["scanned_sources","inspected_records","inspected_bytes"]) &&
    U32.is_le(F.number(Json.get(value,"scanned_sources")),15) && U32.is_le(F.number(Json.get(value,"inspected_records")),242) &&
    U32.is_le(F.number(Json.get(value,"inspected_bytes")),2097152) && R.boolean(Json.field(value,"page_metadata_complete")) && complete_valid(value) &&
    R.object(Json.field(value,"coverage")) && R.numbers(Json.field(value,"coverage"),["unknown","conflicting","unsupported","partial","unexamined_budget"]) &&
    R.array(Json.field(value,"rows")) && Nat.is_le(List.length(&2,Json.Json,rows),U32.to_nat(F.number(Json.get(value,"scanned_sources")))) &&
    candidates_valid(rows,Json.field(value,"selected"),wm,repo,Nat.is_gt(List.length(&2,Json.Json,rows),1n)) &&
    F.text_valid(Json.field(value,"text")) && R.fits(Json.get(value,"text"),1048575)

def candidates_checked(yes: Bool,+value: Json.Json) -> Result<&2,&2,String,Candidates>:
  match yes:
    case False{}: Fail{"Child candidates did not match the exact selected result, retained locator, scope or watermark; original reader is retained."}
    case True{}: Done{Candidates{Json.get(value,"watermark"),Json.get(value,"after_source"),Json.get(value,"next_source"),R.rows(Json.items(Json.field(value,"rows"))),Json.get(value,"text")}}

def decode_candidates(+value: Json.Json,reference: R.Reference,selected: ResultEvent,filters: Query.Filters,watermark: String,after: String) -> Result<&2,&2,String,Candidates>:
  candidates_checked(candidate_page_valid(value,reference,selected,filters,watermark,after),value)

def event_args(snapshot: String,start: U32,count: U32,cursor: Cursor,filters: Query.Filters) -> List<&2,String>:
  Cursor{record,event} = cursor
  Query.Filters{_,provider,repo,role,after} = filters
  ["result-link-events",snapshot,U32.show(start),U32.show(count),U32.show(record),U32.show(event),provider,repo,role,after]

def candidate_args(reference: R.Reference,selected: ResultEvent,filters: Query.Filters,watermark: String,cursor: String) -> List<&2,String>:
  R.Reference{provider,source,generation,snapshot,extent} = reference
  ResultEvent{record,event,_,_,_,_} = selected
  Query.Filters{_,fp,repo,role,after} = filters
  ["result-link-page",provider,source,generation,snapshot,extent,U32.show(record),U32.show(event),watermark,cursor,"15",fp,repo,role,after]

def select(values: List<&2,ResultEvent>,index: U32) -> Maybe<&2,ResultEvent>:
  match values index:
    case [] _: None{}
    case head <> _ 0: Some{head}
    case _ <> rest n: select(rest,U32.sub(n,1))

def titles(values: List<&2,ResultEvent>) -> List<&2,String>:
  match values:
    case []: []
    case ResultEvent{record,event,+status,id,call,_} <> rest:
      ("Result " ++ U32.show(record) ++ ":" ++ U32.show(event) ++ " | " ++ status ++ " | " ++
        Bool.pick(String,String.eq(status,"recorded"),"agent " ++ id,call)) <> titles(rest)

def candidate_titles(values: List<&2,R.Row>) -> List<&2,String>:
  match values:
    case []: []
    case R.Row{R.Reference{_,_,_,snapshot,_},_,_,ambiguous} <> rest:
      ("Child snap " ++ snapshot ++ " | recorded result | " ++ Bool.pick(String,ambiguous,"ambiguous on page","candidate on page")) <> candidate_titles(rest)

def trail(step: U32,old: Maybe<&2,Events>,previous: List<&2,Cursor>) -> List<&2,Cursor>:
  match step old previous:
    case 1 Some{Events{_,_,_,cursor,_,_,_,_}} previous: cursor <> previous
    case 2 _ _ <> rest: rest
    case _ _ previous: previous

def same_prior(page: Events,old: Maybe<&2,Events>) -> Bool:
  Events{reference,_,_,_,_,_,_,_} = page
  match old:
    case None{}: True{}
    case Some{Events{prior,_,_,_,_,_,_,_}}: R.same(reference,prior)
