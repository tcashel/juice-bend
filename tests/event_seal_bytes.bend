import Base
import ../src/projection_seal.bend as Seal
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain
import ../src/json.bend as Json

# The unchanged scalar codec is the byte-compatibility oracle. Neither the
# oracle nor the explicit wire vectors call any new byte-encoder helper.
def check(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def old_preimage(domain: String,cells: List<&2,Sql.Cell>) -> List<&2,U32>:
  Domain.encode(Seal.format() ++ "|" ++ domain ++ "|" ++ Seal.encoded(cells))

def old_digest(domain: String,cells: List<&2,Sql.Cell>) -> String:
  Domain.digest(old_preimage(domain,cells))

def case_bytes(+domain: String,+cells: List<&2,Sql.Cell>,+label: String) -> IO(Unit):
  do IO<Unit>:
    check(Domain.bytes_equal(Seal.encoded_bytes_onto(cells,[]),Domain.encode(Seal.encoded(cells))),
      label ++ " exact typed field bytes")
    check(Domain.bytes_equal(Seal.preimage_bytes(domain,cells),old_preimage(domain,cells)),
      label ++ " exact complete checksum preimage")
    check(String.eq(Seal.digest(domain,cells),old_digest(domain,cells)),
      label ++ " exact historical checksum")

def literal(cells: List<&2,Sql.Cell>,wire: String,label: String) -> IO(Unit):
  check(Domain.bytes_equal(Seal.encoded_bytes_onto(cells,[]),Domain.encode(wire)),label)

def codepoints(codes: List<&2,U32>) -> String:
  match codes:
    case []:
      ""
    case cp <> rest:
      SCon{Chr{cp},codepoints(rest)}

def ascii_range(count: Nat,+cp: U32) -> String:
  match count:
    case 0n:
      ""
    case 1n+rest:
      SCon{Chr{cp},ascii_range(rest,U32.add(cp,1))}

def controls_wire() -> String:
  "\"\\u0000\\u0001\\u0002\\u0003\\u0004\\u0005\\u0006\\u0007\\u0008\\u0009\\u000a\\u000b\\u000c\\u000d\\u000e\\u000f\\u0010\\u0011\\u0012\\u0013\\u0014\\u0015\\u0016\\u0017\\u0018\\u0019\\u001a\\u001b\\u001c\\u001d\\u001e\\u001f\""

def scalar_edges() -> String:
  codepoints([127,128,2047,2048,55295,57344,65535,65536,1114111])

def boundary_cases(lengths: List<&2,Nat>) -> IO(Unit):
  match lengths:
    case []:
      IO.pure(Unit,Unit{})
    case +size <> rest:
      do IO<Unit>:
        case_bytes("event",[Sql.Cell.Text{String.repeat("x",size)}],
          "ASCII payload length " ++ Nat.show(size))
        boundary_cases(rest)

def suffix_cases() -> IO(Unit):
  +suffix = {[0,255,128,58,124] : List<&2,U32>}
  +text = "quote \" slash \\ café 中文 🙂" ++ codepoints([0,10,31])
  +cells = {[Sql.Cell.Text{text},Sql.Cell.Integer{"9007199254740993"}] : List<&2,Sql.Cell>}
  do IO<Unit>:
    check(Domain.bytes_equal(Seal.text_bytes_onto(text,suffix),
      List.append(&2,U32,Domain.encode(text),suffix)),"raw UTF-8 attaches an arbitrary binary suffix exactly once")
    check(Domain.bytes_equal(Seal.quoted_bytes_onto(text,suffix),
      List.append(&2,U32,Domain.encode(Json.quote(text)),suffix)),"quoted text preserves its arbitrary binary suffix")
    check(Domain.bytes_equal(Seal.encoded_bytes_onto(cells,suffix),
      List.append(&2,U32,Domain.encode(Seal.encoded(cells)),suffix)),"typed cells preserve order and the untouched suffix")
    check(Domain.bytes_equal(Seal.encoded_bytes_onto([],suffix),suffix),"empty cells return the complete supplied suffix")

def parser() -> String:
  "providers-v5-utc-context-relay-title"

def header() -> Seal.Header:
  Seal.Header{"9007199254740993","42","9223372036854775807","claude",
    "/synthetic/café/中文/history.jsonl",4096,4,3072,3}

def event_fields(body: String) -> List<&2,Sql.Cell>:
  [Sql.Cell.Text{"assistant"},Sql.Cell.Text{body},Sql.Cell.Text{"tool"},
   Sql.Cell.Text{"call\"\\"},Sql.Cell.Text{"{\"path\":\"src/a.bend\"}"},
   Sql.Cell.Text{"result\nline"},Sql.Cell.Text{"/synthetic/repository"},
   Sql.Cell.Text{"session"},Sql.Cell.Text{"2026-10-22T12:00:00Z"},
   Sql.Cell.Text{"model"},Sql.Cell.Text{"{\"tokens\":9007199254740993}"},
   Sql.Cell.Text{""},Sql.Cell.Text{"captured"}]

def event(ordinal: String,index: String,body: String) -> List<&2,Sql.Cell>:
  Sql.Cell.Integer{ordinal} <> Sql.Cell.Integer{index} <> event_fields(body)

def require_scan(value: Maybe<&2,Seal.Scan>) -> IO(Seal.Scan):
  match value:
    case Some{scan}:
      IO.pure(Seal.Scan,scan)
    case None{}:
      IO.die(Seal.Scan,1,"FAIL fixed valid event fixture rejected")

def old_commitment(prefix: String,chain: String) -> String:
  old_digest("snapshot",Sql.Cell.Text{parser()} <>
    List.append(&2,Sql.Cell,Seal.header_cells(header()),
      [Sql.Cell.Integer{"3"},Sql.Cell.Text{prefix},Sql.Cell.Integer{"4"},Sql.Cell.Text{chain}]))

def chain_cases() -> IO(Unit):
  +a = event("0","0","first\nmessage")
  +b = event("2","0","café é 中文 🙂")
  +c = event("2","1",codepoints([0,1,9,10,13,31,34,92]))
  +d = event("3","0","last|:text:\"quoted\"")
  +root = old_digest("seed",[Sql.Cell.Text{parser()}])
  +one = old_digest("event",Sql.Cell.Text{root} <> a)
  +two = old_digest("event",Sql.Cell.Text{one} <> b)
  +three = old_digest("event",Sql.Cell.Text{two} <> c)
  +four = old_digest("event",Sql.Cell.Text{three} <> d)
  +commitment = old_commitment(three,four)
  +wire = Seal.format() ++ "|3|" ++ three ++ "|4|" ++ four ++ "|" ++ commitment
  do IO<Unit>:
    check(String.eq(Seal.seed(parser()),root),"seed digest matches historical scalar codec")
    +scan : Seal.Scan <- require_scan(Seal.feed(header(),0,[a,b,c,d],Seal.start(parser())))
    check(String.eq(Seal.encode(Seal.finish(header(),parser(),scan)),wire),
      "complete event chain and checkpoint envelope match historical codec")
    check(String.eq(Seal.commitment(header(),parser(),3n,three,4n,four),commitment),
      "snapshot commitment preserves exact large IDs and Unicode locator")
    check(Seal.matches(header(),parser(),scan,wire),"historical sealed snapshot remains accepted")
    resumed : Seal.Scan <- require_scan(Seal.feed(header(),3,[d],Seal.resume(three,3n)))
    check(String.eq(Seal.encode(Seal.finish(header(),parser(),resumed)),wire),
      "verified-prefix resume has the identical final envelope")

def main() -> IO(Unit):
  do IO<Unit>:
    case_bytes("event",[],"empty cell list")
    case_bytes("",[Sql.Cell.Text{""},Sql.Cell.Integer{"0"}],"empty domain and text")
    literal([Sql.Cell.Text{""},Sql.Cell.Integer{"0"}],"text:\"\":integer:\"0\":",
      "explicit empty-field tags quotes and trailing separators")
    literal([Sql.Cell.Text{"a\"b\\c"}],"text:\"a\\\"b\\\\c\":",
      "explicit quote and backslash escaping")
    check(Domain.bytes_equal(Seal.quoted_bytes_onto(ascii_range(32n,0),[]),Domain.encode(controls_wire())),
      "all 32 controls use exact lowercase six-byte Unicode escapes")
    case_bytes("event",[Sql.Cell.Text{ascii_range(128n,0)}],"all ASCII scalars including NUL and DEL")
    case_bytes("event",[Sql.Cell.Text{scalar_edges()}],"UTF-8 width and scalar boundaries")
    case_bytes("event",[Sql.Cell.Text{"café é 中文 🙂"}],"accent combining CJK emoji")
    case_bytes("event|domain:中文",[Sql.Cell.Text{"\":text:\"|event|"},Sql.Cell.Text{""}],
      "quoted separators and non-ASCII domain")
    case_bytes("event",[Sql.Cell.Integer{"0"},Sql.Cell.Integer{"-9223372036854775808"},
      Sql.Cell.Integer{"2147483648"},Sql.Cell.Integer{"4294967296"},
      Sql.Cell.Integer{"9007199254740993"},Sql.Cell.Integer{"9223372036854775807"}],
      "integer decimal lexemes remain exact across numeric boundaries")
    case_bytes("event",[Sql.Cell.Integer{"0001"},Sql.Cell.Integer{"-0"},Sql.Cell.Integer{""}],
      "encoder preserves lexemes without changing separate numeric validators")
    literal([Sql.Cell.Null{},Sql.Cell.Real{"1.0"},Sql.Cell.Blob{[0,255]}],
      "invalid:invalid:invalid:","unsupported storage classes retain historical invalid markers")
    case_bytes("event",[Sql.Cell.Text{"same"},Sql.Cell.Text{"same"},Sql.Cell.Integer{"7"},
      Sql.Cell.Null{},Sql.Cell.Real{"1.0"},Sql.Cell.Blob{[0,255]}],"repeated fields and invalid classes")
    boundary_cases([0n,1n,55n,56n,63n,64n,65n,127n,128n,129n])
    case_bytes("event",[Sql.Cell.Text{String.repeat("argument \"café\" \\ 中文 🙂\n",4096n)},
      Sql.Cell.Text{String.repeat("result",8192n)}],"long escaped tool arguments and results")
    suffix_cases()
    chain_cases()
