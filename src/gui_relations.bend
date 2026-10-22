# Pure protocol and navigation data for bounded Related capture pages.
import Base
import ./json.bend as Json
import ./query.bend as Query
import ./provenance.bend as P
import ./gui_files.bend as F
import ./domain.bend as Domain

type Reference is Data:
  Reference{provider: String,source: String,generation: String,snapshot: String,extent: String}

type Row is Data:
  Row{target: Reference,direction: String,basis: String,ambiguous: Bool}

type Page is Data:
  Page{anchor: Reference,watermark: String,after: String,next: String,
    scanned: U32,rows: List<&2,Row>,text: String,filters: Query.Filters}

def object(value: Json.Json) -> Bool:
  match value:
    case Json.JObject{_}: True{}
    case _: False{}

def array(value: Json.Json) -> Bool:
  match value:
    case Json.JArray{_}: True{}
    case _: False{}

def boolean(value: Json.Json) -> Bool:
  match value:
    case Json.JBool{_}: True{}
    case _: False{}

def bytes_step(valid: Bool,left: U32,next: U32 -> Bool) -> Bool:
  match valid:
    case True{}: next(left)
    case False{}: False{}

def fits(value: String,+left: U32) -> Bool:
  match value:
    case SNil{}: True{}
    case SCon{Chr{+cp},rest}:
      +width = U32.inc(Domain.encode_width(cp))
      bytes_step(Domain.scalar(cp) && U32.is_le(width,left),U32.sub(left,width),remaining => fits(rest,remaining))

def text(+value: Json.Json) -> Bool:
  F.text_valid(value) && Bool.not(String.contains(Json.text(value),"\0")) && fits(Json.text(value),8192)

def nonempty(+value: Json.Json) -> Bool:
  text(value) && Bool.not(String.is_empty(Json.text(value)))

def id(+value: Json.Json) -> Bool:
  F.text_valid(value) && P.decimal_valid(Json.text(value)) && Bool.not(String.eq(Json.text(value),"0")) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(Json.text(value),"9223372036854775807")))

def cursor(+value: Json.Json) -> Bool:
  id(value) || (F.text_valid(value) && String.eq(Json.text(value),"0"))

def components(parts: List<&2,String>) -> Bool:
  match parts:
    case []: True{}
    case +part <> rest:
      Bool.not(String.is_empty(part)) && Bool.not(String.eq(part,".")) && Bool.not(String.eq(part,"..")) && components(rest)

def path(+value: Json.Json) -> Bool:
  nonempty(value) && (String.eq(Json.text(value),"/") ||
    (String.starts_with(Json.text(value),"/") && components(String.split(String.drop(Json.text(value),1n),'/'))))

def reference_valid(+value: Json.Json) -> Bool:
  object(value) && F.text_valid(Json.field(value,"provider")) &&
    (String.eq(Json.get(value,"provider"),"claude") || String.eq(Json.get(value,"provider"),"codex")) &&
    path(Json.field(value,"source")) && id(Json.field(value,"generation")) && id(Json.field(value,"snapshot")) &&
    F.text_valid(Json.field(value,"extent")) && F.number_valid(Json.JNumber{Json.get(value,"extent")})

def reference(+value: Json.Json) -> Reference:
  Reference{Json.get(value,"provider"),Json.get(value,"source"),Json.get(value,"generation"),Json.get(value,"snapshot"),Json.get(value,"extent")}

def same(a: Reference,b: Reference) -> Bool:
  Reference{ap,as,ag,ai,ae} = a
  Reference{bp,bs,bg,bi,be} = b
  String.eq(ap,bp) && String.eq(as,bs) && String.eq(ag,bg) && String.eq(ai,bi) && String.eq(ae,be)

def snapshot(value: Reference) -> String:
  Reference{_,_,_,snapshot,_} = value
  snapshot

def anchor(page: Page) -> Reference:
  Page{anchor,_,_,_,_,_,_,_} = page
  anchor

def watermark(page: Page) -> String:
  Page{_,watermark,_,_,_,_,_,_} = page
  watermark

def after(page: Page) -> String:
  Page{_,_,after,_,_,_,_,_} = page
  after

def next(page: Page) -> String:
  Page{_,_,_,next,_,_,_,_} = page
  next

def observed_record(+value: Json.Json,inspected: U32) -> Bool:
  F.number_valid(value) && U32.is_lt(F.number(Json.text(value)),inspected)

def identity_kind(kind: String,+value: Json.Json,+inspected: U32,repo: Bool) -> Bool:
  match kind:
    case "missing": True{}
    case "known":
      Bool.pick(Bool,repo,path(Json.field(value,"value")),nonempty(Json.field(value,"value"))) &&
        observed_record(Json.field(value,"record"),inspected)
    case "invalid": nonempty(Json.field(value,"reason"))
    case "conflicting": nonempty(Json.field(value,"reason"))
    case _: False{}

def identity_valid(+value: Json.Json,inspected: U32,repo: Bool) -> Bool:
  object(value) && F.text_valid(Json.field(value,"kind")) && identity_kind(Json.get(value,"kind"),value,inspected,repo)

def parent_kind(kind: String,+value: Json.Json,inspected: U32) -> Bool:
  match kind:
    case "unknown": True{}
    case "recorded": nonempty(Json.field(value,"id")) && observed_record(Json.field(value,"record"),inspected)
    case "path_associated": path(Json.field(value,"locator")) && nonempty(Json.field(value,"parent_alias")) && nonempty(Json.field(value,"child_alias"))
    case "unsupported": nonempty(Json.field(value,"reason"))
    case "conflicting": nonempty(Json.field(value,"reason"))
    case _: False{}

def parent_valid(+value: Json.Json,inspected: U32) -> Bool:
  object(value) && F.text_valid(Json.field(value,"kind")) && parent_kind(Json.get(value,"kind"),value,inspected)

def numbers(+value: Json.Json,keys: List<&2,String>) -> Bool:
  match keys:
    case []: True{}
    case key <> rest: F.number_valid(Json.field(value,key)) && numbers(value,rest)

def facts_valid(+value: Json.Json) -> Bool:
  +inspected = F.number(Json.get(value,"inspected"))
  +total = F.number(Json.get(value,"total_records"))
  object(value) && reference_valid(Json.field(value,"reference")) && numbers(value,["inspected","total_records","bytes"]) &&
    U32.is_le(inspected,16) && U32.is_le(inspected,total) && U32.is_le(F.number(Json.get(value,"bytes")),2097152) &&
    identity_valid(Json.field(value,"session"),inspected,False{}) && identity_valid(Json.field(value,"repository"),inspected,True{}) &&
    parent_valid(Json.field(value,"parent"),inspected) && boolean(Json.field(value,"complete")) && text(Json.field(value,"coverage")) &&
    (Bool.not(String.eq(Json.get(value,"complete"),"true")) || U32.is_eq(inspected,total))

def scope_valid(+value: Json.Json,filters: Query.Filters) -> Bool:
  Query.Filters{_,provider,repository,role,after} = filters
  object(value) && text(Json.field(value,"provider")) && text(Json.field(value,"repository")) &&
    text(Json.field(value,"role")) && text(Json.field(value,"after")) &&
    String.eq(Json.get(value,"provider"),provider) && String.eq(Json.get(value,"repository"),repository) &&
    String.eq(Json.get(value,"role"),role) && String.eq(Json.get(value,"after"),after)

def null(value: Json.Json) -> Bool:
  match value:
    case Json.JNull{}: True{}
    case _: False{}

def row_record_kind(basis: String,+value: Json.Json,inspected: U32) -> Bool:
  match basis:
    case "recorded_parent_thread_id": observed_record(Json.field(value,"record"),inspected)
    case "retained_path_association": null(Json.field(value,"record"))
    case _: False{}

def row_record(+value: Json.Json,inspected: U32) -> Bool:
  F.text_valid(Json.field(value,"basis")) && row_record_kind(Json.get(value,"basis"),value,inspected)

def row_valid(+value: Json.Json,+anchor: Json.Json,+watermark: String,+repository: String) -> Bool:
  +target = Json.field(value,"target")
  +direction = Json.get(value,"direction")
  +witness = Bool.pick(Json.Json,String.eq(direction,"parent"),anchor,target)
  object(value) && facts_valid(target) && boolean(Json.field(value,"ambiguous_on_page")) &&
    F.text_valid(Json.field(value,"direction")) && (String.eq(direction,"parent") || String.eq(direction,"child")) &&
    reference_valid(Json.field(value,"witness")) && same(reference(Json.field(value,"witness")),reference(Json.field(witness,"reference"))) &&
    Bool.not(String.eq(Json.get(Json.field(target,"reference"),"source"),Json.get(Json.field(anchor,"reference"),"source"))) &&
    String.eq(Json.get(Json.field(target,"reference"),"provider"),Json.get(Json.field(anchor,"reference"),"provider")) &&
    String.eq(Json.get(Json.field(target,"repository"),"kind"),"known") && String.eq(Json.get(Json.field(anchor,"repository"),"kind"),"known") &&
    String.eq(Json.get(Json.field(target,"repository"),"value"),Json.get(Json.field(anchor,"repository"),"value")) &&
    (String.is_empty(repository) || String.eq(Json.get(Json.field(target,"repository"),"value"),repository)) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(Json.get(Json.field(target,"reference"),"snapshot"),watermark))) &&
    row_record(value,F.number(Json.get(witness,"inspected")))

def rows_valid(values: List<&2,Json.Json>,+anchor: Json.Json,+watermark: String,+repository: String) -> Bool:
  match values:
    case []: True{}
    case value <> rest: row_valid(value,anchor,watermark,repository) && rows_valid(rest,anchor,watermark,repository)

def rows(values: List<&2,Json.Json>) -> List<&2,Row>:
  match values:
    case []: []
    case +value <> rest:
      Row{reference(Json.field(Json.field(value,"target"),"reference")),Json.get(value,"direction"),Json.get(value,"basis"),
        String.eq(Json.get(value,"ambiguous_on_page"),"true")} <> rows(rest)

def next_valid(value: Json.Json,+after: String,scanned: U32) -> Bool:
  match value:
    case Json.JNull{}: True{}
    case +value: id(value) && Cmp.is_gt(P.decimal_compare(Json.text(value),after)) && U32.is_eq(scanned,15)

def valid(+value: Json.Json,+filters: Query.Filters) -> Bool:
  Query.Filters{_,+provider,repository,_,_} = filters
  +anchor = Json.field(value,"anchor")
  +watermark = Json.get(value,"watermark")
  +scanned = F.number(Json.get(value,"scanned_sources"))
  +coverage = Json.field(value,"coverage")
  object(value) && String.eq(Json.get(value,"kind"),"related_captures") && facts_valid(anchor) && id(Json.field(value,"watermark")) &&
    Bool.not(Cmp.is_gt(P.decimal_compare(Json.get(Json.field(anchor,"reference"),"snapshot"),watermark))) &&
    cursor(Json.field(value,"after_source")) && next_valid(Json.field(value,"next_source"),Json.get(value,"after_source"),scanned) &&
    numbers(value,["requested_limit","limit","scanned_sources","inspected_records","inspected_bytes"]) &&
    String.eq(Json.get(value,"requested_limit"),"15") && String.eq(Json.get(value,"limit"),"15") && U32.is_le(scanned,15) &&
    U32.is_le(F.number(Json.get(value,"inspected_records")),256) && U32.is_le(F.number(Json.get(value,"inspected_bytes")),2097152) &&
    object(coverage) && numbers(coverage,["unknown","conflicting","unsupported","partial","unexamined_budget"]) &&
    scope_valid(Json.field(value,"scope"),filters) &&
    (String.is_empty(provider) || String.eq(Json.get(Json.field(anchor,"reference"),"provider"),provider)) && array(Json.field(value,"rows")) &&
    Nat.is_le(List.length(&2,Json.Json,Json.items(Json.field(value,"rows"))),U32.to_nat(U32.mul(scanned,2))) &&
    rows_valid(Json.items(Json.field(value,"rows")),anchor,watermark,repository) && F.text_valid(Json.field(value,"text")) && fits(Json.get(value,"text"),1048575)

def decode_valid(valid: Bool,+value: Json.Json,filters: Query.Filters) -> Result<&2,&2,String,Page>:
  match valid:
    case False{}: Fail{"Related response violates its typed identity, scope, cursor or bounded-page contract; displayed evidence is unchanged."}
    case True{}:
      Done{Page{reference(Json.field(Json.field(value,"anchor"),"reference")),Json.get(value,"watermark"),Json.get(value,"after_source"),
        Json.get(value,"next_source"),F.number(Json.get(value,"scanned_sources")),rows(Json.items(Json.field(value,"rows"))),Json.get(value,"text"),filters}}

def decode(+value: Json.Json,+filters: Query.Filters) -> Result<&2,&2,String,Page>:
  decode_valid(valid(value,filters),value,filters)

def open_args(snapshot: String,filters: Query.Filters) -> List<&2,String>:
  Query.Filters{_,provider,repo,role,after} = filters
  ["relations-scope",snapshot,"15",provider,repo,role,after]

def page_args(page: Page,cursor: String) -> List<&2,String>:
  Page{Reference{provider,source,generation,snapshot,extent},watermark,_,_,_,_,_,Query.Filters{_,fp,repo,role,after}} = page
  ["relations-page",provider,source,generation,snapshot,extent,watermark,cursor,"15",fp,repo,role,after]

def titles(values: List<&2,Row>) -> List<&2,String>:
  match values:
    case []: []
    case Row{Reference{_,_,_,snapshot,_},direction,+basis,ambiguous} <> rest:
      (direction ++ " snap " ++ snapshot ++ " | " ++ Bool.pick(String,String.eq(basis,"recorded_parent_thread_id"),"recorded parent","path association") ++
        Bool.pick(String,ambiguous," | page ambiguity","")) <> titles(rest)

def select(values: List<&2,Row>,index: U32) -> Maybe<&2,Row>:
  match values index:
    case [] _: None{}
    case row <> rest 0: Some{row}
    case row <> rest n: select(rest,U32.sub(n,1))
