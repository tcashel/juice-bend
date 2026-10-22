import Base
import ../src/reader_document.bend as Doc
import ../src/reader_wire.bend as Wire
import ../src/json.bend as Json

def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}: IO.print("PASS " ++ label)
    case False{}: IO.die(Unit,1,"FAIL " ++ label)

def parsed(value: Result<&2,&2,String,Json.Json>) -> Json.Json:
  match value:
    case Done{value}: value
    case Fail{_}: Json.JNull{}

def json(text: String) -> Json.Json: parsed(Json.parse(text))
def canonical() -> String: "é\t中文🙂\n"

def part(index: U32,start: U32,count: U32,kind: Doc.PartKind,collapsible: Bool) -> Doc.Part:
  Doc.Part{Doc.PartKey{"9007199254740993","18446744073709551615",4294967295,index},
    kind,Doc.Span{start,count},"assistant","quoted\"tool",collapsible}

def document() -> Doc.Document:
  Doc.admit(canonical(),7,[part(0,0,3,Doc.MessageText{},False{}),part(1,3,3,Doc.ToolResult{},True{})])

def packet(parts: List<&2,Json.Json>) -> Json.Json:
  Json.JObject{[Json.JField{"version",Json.JNumber{"1"}},Json.JField{"mode",Json.JString{"structured"}},Json.JField{"parts",Json.JArray{parts}}]}

def first() -> Json.Json: json(Wire.part_json(part(0,0,3,Doc.MessageText{},False{})))
def second() -> Json.Json: json(Wire.part_json(part(1,3,3,Doc.ToolResult{},True{})))

def changed_field(field: Json.Field,+name: String,+replacement: Json.Json) -> Json.Field:
  Json.JField{+key,value} = field
  Json.JField{key,Bool.pick(Json.Json,String.eq(key,name),replacement,value)}

def changed_fields(fields: List<&2,Json.Field>,+name: String,+replacement: Json.Json) -> List<&2,Json.Field>:
  match fields:
    case []: []
    case field <> rest: changed_field(field,name,replacement) <> changed_fields(rest,name,replacement)

def changed(value: Json.Json,name: String,replacement: Json.Json) -> Json.Json:
  match value:
    case Json.JObject{fields}: Json.JObject{changed_fields(fields,name,replacement)}
    case _: Json.JNull{}

def fallback(+value: Json.Json) -> Bool:
  +doc = Wire.decode(canonical(),value,19)
  Bool.not(Doc.structured(doc)) && String.eq(Doc.text(doc),canonical()) && U32.is_eq(Doc.revision(doc),19)

def identities(parts: List<&2,Doc.Part>) -> Bool:
  match parts:
    case []: True{}
    case Doc.Part{Doc.PartKey{snapshot,record,event,_},_,_,role,tool,_} <> rest:
      String.eq(snapshot,"9007199254740993") && String.eq(record,"18446744073709551615") &&
        U32.is_eq(event,4294967295) && String.eq(role,"assistant") && String.eq(tool,"quoted\"tool") && identities(rest)

def roundtrip() -> IO(Unit):
  +wire = Wire.encode(document())
  +decoded = Wire.decode(canonical(),json(wire),19)
  do IO<Unit>:
    check(Doc.structured(decoded) && String.eq(Doc.text(decoded),canonical()) && U32.is_eq(Doc.revision(decoded),19),"wire roundtrip retains full Unicode canonical text and binds fresh caller revision")
    check(identities(Doc.parts(decoded)) && Nat.is_eq(List.length(&2,Doc.Part,Doc.parts(decoded)),2n),"wire preserves exact wide string identities, max U32 event, role and escaped tool")
    check(String.eq(Wire.encode(Doc.Plain{canonical(),7}),"{\"version\":1,\"mode\":\"plain\"}"),"plain metadata is an explicit versioned object without a partial table")
    check(fallback(json("{\"version\":1,\"mode\":\"plain\"}")) && fallback(Json.JNull{}),"plain and missing metadata retain the complete plain reader")
    check(Bool.not(String.contains(wire,canonical())) && Bool.not(String.contains(wire,"revision")),"metadata does not duplicate canonical text or claim a transport revision")

def malformed_shape() -> IO(Unit):
  do IO<Unit>:
    check(fallback(changed(packet([first(),second()]),"version",Json.JNumber{"2"})),"unknown wire version falls back")
    check(fallback(changed(packet([first(),second()]),"version",Json.JString{"1"})),"version requires a JSON number")
    check(fallback(Json.JObject{[Json.JField{"version",Json.JNumber{"1"}},Json.JField{"mode",Json.JString{"structured"}}]}),"missing parts table falls back")
    check(fallback(changed(packet([]),"parts",Json.JString{"[]"})),"parts require an actual JSON array")
    check(fallback(Json.JObject{[Json.JField{"version",Json.JNumber{"1"}},Json.JField{"version",Json.JNumber{"1"}},Json.JField{"mode",Json.JString{"structured"}},Json.JField{"parts",Json.JArray{[]}}]}),"even externally constructed duplicate object keys are rejected")
    check(fallback(Json.JObject{[Json.JField{"version",Json.JNumber{"1"}},Json.JField{"mode",Json.JString{"structured"}},Json.JField{"parts",Json.JArray{[first(),second()]}},Json.JField{"extra",Json.JNull{}}]}),"unknown top-level fields are not silently accepted")
    check(fallback(packet([changed(first(),"snapshot",Json.JNumber{"9007199254740993"}),second()])),"snapshot identity requires a string without numeric coercion")
    check(fallback(packet([changed(first(),"kind",Json.JString{"inferred_heading"}),second()])),"unknown part kinds are rejected")
    check(fallback(packet([first(),changed(second(),"collapsible",Json.JString{"true"})])),"collapse eligibility requires a JSON boolean")
    check(fallback(packet([changed(first(),"role",Json.JNull{}),second()])),"role must be an explicit string")

def malformed_ranges() -> IO(Unit):
  do IO<Unit>:
    check(fallback(packet([first(),first()])),"duplicate part identity and overlapping source span fall back")
    check(fallback(packet([second(),first()])),"out-of-order descriptors fall back")
    check(fallback(packet([changed(first(),"length",Json.JNumber{"0"}),second()])),"zero-length descriptor falls back")
    check(fallback(packet([first()])),"missing canonical tail never yields a partial successful reader")
    check(fallback(packet([changed(first(),"collapsible",Json.JBool{True{}}),second()])),"message text cannot acquire collapse eligibility through metadata")
    check(fallback(packet([changed(first(),"event",Json.JNumber{"4294967296"}),second()])),"U32 overflow refuses numeric wrap")
    check(fallback(packet([changed(first(),"part",Json.JNumber{"-1"}),second()])),"negative part index is rejected")
    check(fallback(packet([changed(first(),"start",Json.JNumber{"0.0"}),second()])),"fractional numeric syntax is rejected")
    check(fallback(packet([changed(first(),"start",Json.JNumber{"0e0"}),second()])),"exponent numeric syntax is rejected")
    check(fallback(packet([changed(first(),"length",Json.JString{"3"}),second()])),"scalar counts are not coerced from strings")
    check(fallback(packet([first(),changed(second(),"start",Json.JNumber{"4294967295"})])),"start plus count overflow falls back before scalar slicing")
    check(fallback(packet([changed(first(),"event",Json.JNumber{"00"}),second()])),"externally constructed noncanonical numeric lexemes are rejected")

def many(fuel: Nat,+index: U32) -> List<&2,Json.Json>:
  match fuel:
    case 0n: []
    case 1n+rest:
      json(Wire.part_json(part(index,index,1,Doc.MessageText{},False{}))) <> many(rest,U32.inc(index))

def bounded() -> IO(Unit):
  +text = String.repeat("a",2049n)
  +doc = Wire.decode(text,packet(many(2049n,0)),19)
  do IO<Unit>:
    check(Bool.not(Doc.structured(doc)) && String.eq(Doc.text(doc),text),"2049 valid adjacent parts exceed the table budget and retain every canonical scalar")
    check(Doc.structured(Wire.decode("",packet([]),19)),"empty canonical document accepts an empty structured table")

def snapshot_binding() -> IO(Unit):
  +matching = Wire.decode_for(canonical(),packet([first(),second()]),19,"9007199254740993")
  +foreign = Wire.decode_for(canonical(),packet([first(),second()]),19,"other-snapshot")
  +mixed = Wire.decode_for(canonical(),packet([first(),changed(second(),"snapshot",Json.JString{"other-snapshot"})]),19,"9007199254740993")
  do IO<Unit>:
    check(Doc.structured(matching),"production wire binding admits only the guarded exact snapshot identity")
    check(Bool.not(Doc.structured(foreign)) && String.eq(Doc.text(foreign),canonical()) && U32.is_eq(Doc.revision(foreign),19),"foreign descriptor snapshots fall back with exact text and caller revision")
    check(Bool.not(Doc.structured(mixed)) && String.eq(Doc.text(mixed),canonical()),"mixed-snapshot descriptor tables are rejected together")

def long_metadata(fuel: Nat,+index: U32,+tool: String) -> List<&2,Doc.Part>:
  match fuel:
    case 0n: []
    case 1n+rest:
      Doc.Part{Doc.PartKey{"1","0",0,index},Doc.MessageText{},Doc.Span{index,1},"assistant",tool,False{}} <>
        long_metadata(rest,U32.inc(index),tool)

def metadata_budget() -> IO(Unit):
  +text = String.repeat("a",1000n)
  +doc = Doc.admit(text,7,long_metadata(1000n,0,String.repeat("t",1024n)))
  do IO<Unit>:
    check(Doc.structured(doc) && String.eq(Wire.encode(doc),"{\"version\":1,\"mode\":\"plain\"}") && String.eq(Doc.text(doc),text),
      "repeated long metadata falls back before encoding a huge table while preserving the complete canonical document")

def main() -> IO(Unit):
  do IO<Unit>:
    roundtrip()
    malformed_shape()
    malformed_ranges()
    bounded()
    snapshot_binding()
    metadata_budget()
