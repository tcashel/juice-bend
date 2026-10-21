import Base
import ./json.bend as Json
import ./usage.bend as Legacy
import ./provenance.bend as Provenance

# Recorded counters remain exact decimal strings. Empty means unknown or not
# applicable, never a measured zero. This helper imports only the old Usage
# arithmetic; the old selected-page reader and its policy remain unchanged.
type Counters is Data:
  Counters{input: String,cached: String,created: String,created1h: String,output: String}

def empty() -> Counters:
  Counters{"","","","",""}

def number(value: Json.Json) -> String:
  Legacy.number(value)

def add(a: String,b: String) -> String:
  Legacy.add(a,b)

def subtract(a: String,b: String) -> String:
  Legacy.subtract(a,b)

def maximum(a: String,b: String) -> String:
  Legacy.maximum(a,b)

def known_sum(a: String,b: String) -> String:
  Legacy.known_add(a,b)

def sum(a: Counters,b: Counters) -> Counters:
  Counters{ai,ac,ar,ah,ao} = a
  Counters{bi,bc,br,bh,bo} = b
  Counters{known_sum(ai,bi),known_sum(ac,bc),known_sum(ar,br),known_sum(ah,bh),known_sum(ao,bo)}

def maxima(a: Counters,b: Counters) -> Counters:
  Counters{ai,ac,ar,ah,ao} = a
  Counters{bi,bc,br,bh,bo} = b
  Counters{maximum(ai,bi),maximum(ac,bc),maximum(ar,br),maximum(ah,bh),maximum(ao,bo)}

def growth(+a: String,+b: String) -> String:
  Bool.pick(String,String.is_empty(a),"",Bool.pick(String,String.is_empty(b),a,
    Bool.pick(String,Cmp.is_ge(Provenance.decimal_compare(a,b)),subtract(a,b),"0")))

def delta(a: Counters,b: Counters) -> Counters:
  Counters{ai,ac,ar,ah,ao} = a
  Counters{bi,bc,br,bh,bo} = b
  Counters{growth(ai,bi),growth(ac,bc),growth(ar,br),growth(ah,bh),growth(ao,bo)}

def equal(a: Counters,b: Counters) -> Bool:
  Counters{ai,ac,ar,ah,ao} = a
  Counters{bi,bc,br,bh,bo} = b
  String.eq(ai,bi) && String.eq(ac,bc) && String.eq(ar,br) && String.eq(ah,bh) && String.eq(ao,bo)

def backwards(a: Counters,b: Counters) -> Bool:
  Counters{ai,ac,ar,ah,ao} = a
  Counters{bi,bc,br,bh,bo} = b
  Legacy.decreased(ai,bi) || Legacy.decreased(ac,bc) || Legacy.decreased(ar,br) ||
    Legacy.decreased(ah,bh) || Legacy.decreased(ao,bo)

def complete_codex(value: Counters) -> Bool:
  Counters{input,cached,_,_,output} = value
  Bool.not(String.is_empty(input)) && Bool.not(String.is_empty(cached)) && Bool.not(String.is_empty(output))

def complete_claude(value: Counters) -> Bool:
  Counters{input,cached,created,_,output} = value
  Bool.not(String.is_empty(input)) && Bool.not(String.is_empty(cached)) &&
    Bool.not(String.is_empty(created)) && Bool.not(String.is_empty(output))

type Field is Data:
  Absent{}
  Present{value: Json.Json}
  Duplicate{}

def selected(found: Field,value: Json.Json) -> Field:
  match found:
    case Absent{}: Present{value}
    case _: Duplicate{}

def select(fields: List<&2,Json.Field>,+name: String,+found: Field) -> Field:
  match fields:
    case []: found
    case Json.JField{key,value} <> rest:
      select(rest,name,Bool.pick(Field,String.eq(key,name),selected(found,value),found))

def lookup(value: Json.Json,name: String) -> Field:
  match value:
    case Json.JObject{fields}: select(fields,name,Absent{})
    case _: Duplicate{}

def field_value(value: Field) -> Json.Json:
  match value:
    case Present{value}: value
    case _: Json.JNull{}

def field(value: Json.Json,name: String) -> Json.Json:
  field_value(lookup(value,name))

# The optional split remains unknown when absent. A present invalid split is
# coverage loss, and a valid split follows the reference's clamp to creation.
def split_valid(value: Field) -> Bool:
  match value:
    case Absent{}: True{}
    case Present{value}: Bool.not(String.is_empty(number(value)))
    case Duplicate{}: False{}

def split_object(value: Field) -> Bool:
  match value:
    case Absent{}: True{}
    case Present{Json.JObject{fields}}: split_valid(select(fields,"ephemeral_1h_input_tokens",Absent{}))
    case _: False{}

def claude_split_valid(usage: Json.Json) -> Bool:
  split_object(lookup(usage,"cache_creation"))

def split(+created: String,+value: String) -> String:
  Bool.pick(String,String.is_empty(created) || String.is_empty(value),"",
    Bool.pick(String,Cmp.is_gt(Provenance.decimal_compare(value,created)),created,value))

def claude(+usage: Json.Json) -> Counters:
  +created = number(field(usage,"cache_creation_input_tokens"))
  Counters{number(field(usage,"input_tokens")),number(field(usage,"cache_read_input_tokens")),created,
    split(created,number(field(field(usage,"cache_creation"),"ephemeral_1h_input_tokens"))),
    number(field(usage,"output_tokens"))}

def codex_valid(valid: Bool,input: String,+cached: String,output: String) -> Maybe<&2,Counters>:
  match valid:
    case False{}: None{}
    case True{}: Some{Counters{growth(input,cached),cached,"","",output}}

def codex(+usage: Json.Json) -> Maybe<&2,Counters>:
  +input = number(field(usage,"input_tokens"))
  +cached = number(field(usage,"cached_input_tokens"))
  +output = number(field(usage,"output_tokens"))
  codex_valid(Bool.not(String.is_empty(input)) && Bool.not(String.is_empty(cached)) &&
    Bool.not(String.is_empty(output)),input,cached,output)

def fields(value: Counters) -> List<&2,String>:
  Counters{input,cached,created,created1h,output} = value
  [input,cached,created,created1h,output]

def shown(value: String) -> String:
  Legacy.shown(value)

def text(value: Counters) -> String:
  Counters{input,cached,created,created1h,output} = value
  "input_tokens (noncached for Codex): " ++ shown(input) ++
    "\ncache_read/cached_input_tokens: " ++ shown(cached) ++
    "\ncache_creation_input_tokens: " ++ shown(created) ++
    "\ncache_creation.ephemeral_1h_input_tokens: " ++ shown(created1h) ++
    "\noutput_tokens: " ++ shown(output) ++ "\n"
