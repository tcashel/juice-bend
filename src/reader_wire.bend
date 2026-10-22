import Base
import ./json.bend as Json
import ./reader_document.bend as Doc

# Optional transcript-only metadata. The caller supplies the already guarded
# response's canonical text and its fresh local revision. No copied text,
# numeric snapshot conversion, provider parsing, or database authority lives here.
def kind_name(kind: Doc.PartKind) -> String:
  match kind:
    case Doc.PageNotice{}: "page_notice"
    case Doc.EventHeading{}: "event_heading"
    case Doc.MessageText{}: "message_text"
    case Doc.FencedCode{}: "fenced_code"
    case Doc.ToolName{}: "tool_name"
    case Doc.ToolArguments{}: "tool_arguments"
    case Doc.ToolResult{}: "tool_result"
    case Doc.EvidenceDetails{}: "evidence_details"

def part_json(part: Doc.Part) -> String:
  Doc.Part{Doc.PartKey{snapshot,record,event,index},kind,Doc.Span{start,count},role,tool,collapsible} = part
  "{\"snapshot\":" ++ Json.quote(snapshot) ++ ",\"record\":" ++ Json.quote(record) ++
    ",\"event\":" ++ U32.show(event) ++ ",\"part\":" ++ U32.show(index) ++
    ",\"kind\":" ++ Json.quote(kind_name(kind)) ++ ",\"start\":" ++ U32.show(start) ++
    ",\"length\":" ++ U32.show(count) ++ ",\"role\":" ++ Json.quote(role) ++
    ",\"tool\":" ++ Json.quote(tool) ++ ",\"collapsible\":" ++ Bool.pick(String,collapsible,"true","false") ++ "}"

def parts_json(parts: List<&2,Doc.Part>) -> List<&2,String>:
  match parts:
    case []: []
    case part <> rest: part_json(part) <> parts_json(rest)

# Every escaped Unicode scalar occupies at most six UTF8 JSON bytes. The
# fixed allowance covers field names, punctuation, kind, booleans and U32s.
# Reject excessive repeated metadata before building its encoded String.
def part_budget(part: Doc.Part) -> Nat:
  Doc.Part{Doc.PartKey{snapshot,record,_,_},_,_,role,tool,_} = part
  Nat.add(256n,Nat.mul(6n,Nat.add(Nat.add(String.length(snapshot),String.length(record)),
    Nat.add(String.length(role),String.length(tool)))))

def budget_next(valid: Bool,next: Unit -> Bool) -> Bool:
  match valid:
    case False{}: False{}
    case True{}: next(Unit{})

def metadata_fits(parts: List<&2,Doc.Part>,+budget: Nat) -> Bool:
  match parts:
    case []: True{}
    case part <> rest:
      +cost = part_budget(part)
      budget_next(Nat.is_le(cost,budget),_ => metadata_fits(rest,Nat.sub(budget,cost)))

def encode_parts(parts: List<&2,Doc.Part>,fits: Bool) -> String:
  match fits:
    case False{}: "{\"version\":1,\"mode\":\"plain\"}"
    case True{}:
      "{\"version\":1,\"mode\":\"structured\",\"parts\":[" ++ String.join(parts_json(parts),",") ++ "]}"

def encode_normal(document: Doc.Document) -> String:
  match document:
    case Doc.Plain{_,_}: "{\"version\":1,\"mode\":\"plain\"}"
    case Doc.Structured{_,_,+parts}: encode_parts(parts,metadata_fits(parts,1048512n))

def encode(document: Doc.Document) -> String: encode_normal(Doc.normalize(document))

def guard(valid: Bool) -> Result<&2,&2,Unit,Unit>:
  match valid:
    case True{}: Done{Unit{}}
    case False{}: Fail{Unit{}}

def has_name(names: List<&2,String>,+name: String) -> Bool:
  match names:
    case []: False{}
    case first <> rest: String.eq(first,name) || has_name(rest,name)

def keep_name(first: String,rest: List<&2,String>,same: Bool) -> List<&2,String>:
  match same:
    case True{}: rest
    case False{}: first <> rest

def remove_name(names: List<&2,String>,+name: String) -> List<&2,String>:
  match names:
    case []: []
    case +first <> rest: keep_name(first,remove_name(rest,name),String.eq(first,name))

def fields_match(fuel: Nat,fields: List<&2,Json.Field>,+names: List<&2,String>) -> Bool:
  match fuel fields:
    case _ Nil{}: List.is_empty(&2,String,names)
    case 0n _: False{}
    case 1n+rest Con{Json.JField{+name,_},tail}:
      has_name(names,name) && fields_match(rest,tail,remove_name(names,name))

def exact_object(value: Json.Json,+names: List<&2,String>) -> Bool:
  match value:
    case Json.JObject{fields}: fields_match(List.length(&2,String,names),fields,names)
    case _: False{}

def read_text(value: Json.Json) -> Result<&2,&2,Unit,String>:
  match value:
    case Json.JString{text}: Done{text}
    case _: Fail{Unit{}}

def read_bool(value: Json.Json) -> Result<&2,&2,Unit,Bool>:
  match value:
    case Json.JBool{boolean}: Done{boolean}
    case _: Fail{Unit{}}

def digit_add(value: U32,digit: U32,valid: Bool) -> Result<&2,&2,Unit,U32>:
  match valid:
    case False{}: Fail{Unit{}}
    case True{}: Done{U32.add(U32.mul(value,10),digit)}

def digit_checked(+value: U32,code: U32,valid: Bool) -> Result<&2,&2,Unit,U32>:
  match valid:
    case False{}: Fail{Unit{}}
    case True{}:
      +digit = U32.sub(code,48)
      digit_add(value,digit,U32.is_lt(value,429496729) ||
        (U32.is_eq(value,429496729) && U32.is_le(digit,5)))

def digit(value: U32,+code: U32) -> Result<&2,&2,Unit,U32>:
  digit_checked(value,code,U32.is_ge(code,48) && U32.is_le(code,57))

def digits(fuel: Nat,text: String,value: U32) -> Result<&2,&2,Unit,U32>:
  match fuel text:
    case _ SNil{}: Done{value}
    case 0n _: Fail{Unit{}}
    case 1n+rest SCon{Chr{code},tail}:
      do Result<&2,&2,Unit,U32>:
        next : U32 <- digit(value,code)
        digits(rest,tail,next)

def unsigned(+text: String) -> Result<&2,&2,Unit,U32>:
  do Result<&2,&2,Unit,U32>:
    _ : Unit <- guard(Bool.not(String.is_empty(text)))
    +value : U32 <- digits(10n,text,0)
    _ : Unit <- guard(String.eq(text,U32.show(value)))
    return value

def read_u32(value: Json.Json) -> Result<&2,&2,Unit,U32>:
  match value:
    case Json.JNumber{text}: unsigned(text)
    case _: Fail{Unit{}}

def kind(text: String) -> Result<&2,&2,Unit,Doc.PartKind>:
  match text:
    case "page_notice": Done{Doc.PageNotice{}}
    case "event_heading": Done{Doc.EventHeading{}}
    case "message_text": Done{Doc.MessageText{}}
    case "fenced_code": Done{Doc.FencedCode{}}
    case "tool_name": Done{Doc.ToolName{}}
    case "tool_arguments": Done{Doc.ToolArguments{}}
    case "tool_result": Done{Doc.ToolResult{}}
    case "evidence_details": Done{Doc.EvidenceDetails{}}
    case _: Fail{Unit{}}

def read_kind(value: Json.Json) -> Result<&2,&2,Unit,Doc.PartKind>:
  do Result<&2,&2,Unit,Doc.PartKind>:
    name : String <- read_text(value)
    kind(name)

def read_part(+value: Json.Json) -> Result<&2,&2,Unit,Doc.Part>:
  do Result<&2,&2,Unit,Doc.Part>:
    _ : Unit <- guard(exact_object(value,["snapshot","record","event","part","kind","start","length","role","tool","collapsible"]))
    snapshot : String <- read_text(Json.field(value,"snapshot"))
    record : String <- read_text(Json.field(value,"record"))
    event : U32 <- read_u32(Json.field(value,"event"))
    index : U32 <- read_u32(Json.field(value,"part"))
    tag : Doc.PartKind <- read_kind(Json.field(value,"kind"))
    start : U32 <- read_u32(Json.field(value,"start"))
    count : U32 <- read_u32(Json.field(value,"length"))
    role : String <- read_text(Json.field(value,"role"))
    tool : String <- read_text(Json.field(value,"tool"))
    collapsible : Bool <- read_bool(Json.field(value,"collapsible"))
    return Doc.Part{Doc.PartKey{snapshot,record,event,index},tag,Doc.Span{start,count},role,tool,collapsible}

def read_parts(fuel: Nat,items: List<&2,Json.Json>) -> Result<&2,&2,Unit,List<&2,Doc.Part>>:
  match fuel items:
    case _ Nil{}: Done{[]}
    case 0n _: Fail{Unit{}}
    case 1n+rest Con{item,tail}:
      do Result<&2,&2,Unit,List<&2,Doc.Part>>:
        part : Doc.Part <- read_part(item)
        remaining : List<&2,Doc.Part> <- read_parts(rest,tail)
        return part <> remaining

def read_array(value: Json.Json) -> Result<&2,&2,Unit,List<&2,Doc.Part>>:
  match value:
    case Json.JArray{items}: read_parts(Doc.part_limit(),items)
    case _: Fail{Unit{}}

def structured(+value: Json.Json) -> Result<&2,&2,Unit,List<&2,Doc.Part>>:
  do Result<&2,&2,Unit,List<&2,Doc.Part>>:
    _ : Unit <- guard(exact_object(value,["version","mode","parts"]))
    version : U32 <- read_u32(Json.field(value,"version"))
    mode : String <- read_text(Json.field(value,"mode"))
    _ : Unit <- guard(U32.is_eq(version,1) && String.eq(mode,"structured"))
    read_array(Json.field(value,"parts"))

def decoded(canonical: String,revision: U32,parts: Result<&2,&2,Unit,List<&2,Doc.Part>>) -> Doc.Document:
  match parts:
    case Fail{_}: Doc.Plain{canonical,revision}
    case Done{parts}: Doc.admit(canonical,revision,parts)

# Receive the reader_view value, not the entire CLI response. Missing metadata,
# plain mode, unknown schema/version, and every malformed table keep all text.
def decode(canonical: String,value: Json.Json,revision: U32) -> Doc.Document:
  decoded(canonical,revision,structured(value))

def snapshot_matches(parts: List<&2,Doc.Part>,+snapshot: String) -> Bool:
  match parts:
    case []: True{}
    case Doc.Part{Doc.PartKey{actual,_,_,_},_,_,_,_,_} <> rest:
      String.eq(actual,snapshot) && snapshot_matches(rest,snapshot)

def bind_snapshot(document: Doc.Document,valid: Bool) -> Doc.Document:
  match valid:
    case True{}: document
    case False{}:
      +plain = document
      Doc.Plain{Doc.text(plain),Doc.revision(plain)}

def for_snapshot(+document: Doc.Document,snapshot: String) -> Doc.Document:
  bind_snapshot(document,snapshot_matches(Doc.parts(document),snapshot))

# Production response admission also binds every exact descriptor identity to
# the already verified outer snapshot. Standalone decode remains schema-only.
def decode_for(canonical: String,value: Json.Json,revision: U32,snapshot: String) -> Doc.Document:
  for_snapshot(decode(canonical,value,revision),snapshot)
