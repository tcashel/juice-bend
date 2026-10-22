import Base
import ../src/domain.bend as Domain

def check(name: String, passed: Bool) -> IO(Unit):
  match passed:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      do IO<Unit>:
        IO.print("FAIL " ++ name)
        IO.exit(1)

def decoded_equal(result: Result<&2, &2, String, String>, expected: String) -> Bool:
  match result:
    case Fail{_}:
      False{}
    case Done{text}:
      String.eq(text, expected)

def rejected(result: Result<&2, &2, String, String>) -> Bool:
  match result:
    case Fail{_}:
      True{}
    case Done{_}:
      False{}

def number_is(result: Maybe<&2, U32>, expected: U32) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{n}:
      U32.is_eq(n, expected)

def number_rejected(result: Maybe<&2, U32>) -> Bool:
  match result:
    case None{}:
      True{}
    case Some{_}:
      False{}

def is_ambiguous(evidence: Domain.IdentityEvidence) -> Bool:
  match evidence:
    case Domain.AmbiguousIdentity{}:
      True{}
    case _:
      False{}

def is_missing(evidence: Domain.IdentityEvidence) -> Bool:
  match evidence:
    case Domain.MissingIdentity{}:
      True{}
    case _:
      False{}

def main() -> IO(Unit):
  do IO<Unit>:
    check("SHA256 empty", String.eq(Domain.digest([]),
      "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"))
    check("SHA256 abc", String.eq(Domain.digest(Domain.encode("abc")),
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"))
    check("SHA256 multi-block FIPS vector", String.eq(Domain.digest(Domain.encode(
      "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq")),
      "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1"))
    check("SHA256 pad boundary 55", String.eq(
      Domain.digest(List.replicate(U32, 55n, 97)),
      "9f4390f8d30c2dd92ec9f095b65e2b9ae9b0a925a5258e241c9f1e910f734318"))
    check("SHA256 pad boundary 56", String.eq(
      Domain.digest(List.replicate(U32, 56n, 97)),
      "b35439a4ac6f0948b6d6f9e3c6af0f5f590ce20f1bde7090ef7970686ec6738a"))
    check("SHA256 block boundary 63", String.eq(
      Domain.digest(List.replicate(U32, 63n, 97)),
      "7d3e74a05d7db15bce4ad9ec0658ea98e3f06eeecf16b4c6fff2da457ddc2f34"))
    check("SHA256 block boundary 64", String.eq(
      Domain.digest(List.replicate(U32, 64n, 97)),
      "ffe054fe7ae0cb6dc65c3af9b61d5209f439851db43d0ba5997337df154668eb"))
    check("SHA256 block boundary 65", String.eq(
      Domain.digest(List.replicate(U32, 65n, 97)),
      "635361c48bb9eab14198e76ea8ab7f1a41685d6ad62aa9146d301d4f17eb0ae0"))
    check("SHA256 binary NUL", String.eq(Domain.digest([0,255,128,0,10,13,254]),
      "06613ac1cd22886f0b69ca3217b15d98435cd0b5b598261940964a4394295f6d"))
    check("UTF8 independent emoji bytes", Domain.bytes_equal(
      Domain.encode("é中😀"), [195,169,228,184,173,240,159,152,128]))
    check("UTF8 decode nonASCII", decoded_equal(
      Domain.decode([195,169,228,184,173,240,159,152,128]), "é中😀"))
    check("UTF8 embedded NUL", decoded_equal(Domain.decode([65,0,66]),
      SCon{Chr{65}, SCon{Chr{0}, SCon{Chr{66}, SNil{}}}}))
    check("UTF8 overlong", rejected(Domain.decode([192,128])))
    check("UTF8 overlong three", rejected(Domain.decode([224,128,128])))
    check("UTF8 surrogate", rejected(Domain.decode([237,160,128])))
    check("UTF8 beyond max scalar", rejected(Domain.decode([244,144,128,128])))
    check("UTF8 truncated", rejected(Domain.decode([240,159,152])))
    check("UTF8 bad continuation", rejected(Domain.decode([226,65,128])))
    check("UTF8 invalid byte integer", rejected(Domain.decode([256])))
    check("UTF8 max scalar", decoded_equal(Domain.decode([244,143,191,191]),
      SCon{Chr{1114111}, SNil{}}))
    check("match empty rejected", Bool.not(Domain.eligible_match(0n, 0n)))
    check("match one exact", Domain.eligible_match(1n, 1n))
    check("match one missing", Bool.not(Domain.eligible_match(0n, 1n)))
    check("match sixty percent", Domain.eligible_match(3n, 5n))
    check("match below threshold", Bool.not(Domain.eligible_match(2n, 5n)))
    check("match invalid counts", Bool.not(Domain.eligible_match(6n, 5n)))
    check("match two minimum", Bool.not(Domain.eligible_match(1n, 2n)))
    check("bounded read normal", U32.is_eq(Domain.bounded_count(10, 20, 50), 20))
    check("bounded read clips", U32.is_eq(Domain.bounded_count(40, 20, 50), 10))
    check("bounded read beyond extent", U32.is_eq(Domain.bounded_count(60, 20, 50), 0))
    check("bounded read max U32", U32.is_eq(
      Domain.bounded_count(4294967290, 100, 4294967295), 5))
    check("bounded read no addition overflow", U32.is_eq(
      Domain.bounded_count(4294967295, 4294967295, 4294967295), 0))
    check("snapshot remains pinned", String.eq(
      Domain.select_snapshot(Some{"9007199254740993"}, "9007199254740994"),
      "9007199254740993"))
    check("generation isolation", Bool.not(Domain.ref_equal(
      Domain.EvidenceKey{"codex","source","1","10","9","0"},
      Domain.EvidenceKey{"codex","source","2","10","9","0"})))
    check("provider isolation", Bool.not(Domain.ref_equal(
      Domain.EvidenceKey{"claude","source","1","10","9","0"},
      Domain.EvidenceKey{"codex","source","1","10","9","0"})))
    check("event occurrence isolation", Bool.not(Domain.ref_equal(
      Domain.EvidenceKey{"codex","source","1","10","9","0"},
      Domain.EvidenceKey{"codex","source","1","10","9","1"})))
    check("scope provider excluded", Bool.not(
      Domain.scope_allowed("claude","repo","codex","repo")))
    check("scope repository excluded", Bool.not(
      Domain.scope_allowed("codex","other","codex","repo")))
    check("scope wildcards explicit", Domain.scope_allowed("codex","repo","",""))
    check("missing evidence never exact", is_missing(
      Domain.identity_insert("excluded",False{},Domain.MissingIdentity{})))
    check("ambiguous evidence never exact", is_ambiguous(
      Domain.identity_insert("third",True{},Domain.AmbiguousIdentity{})))
    check("distinct identities ambiguous", is_ambiguous(
      Domain.identity_insert("second",True{},Domain.UniqueIdentity{"first"})))
    check("tie uses key", Domain.prefer_candidate(EQ{},EQ{},LT{}))
    check("tie rejects greater key", Bool.not(Domain.prefer_candidate(EQ{},EQ{},GT{})))
    check("score precedes key", Bool.not(Domain.prefer_candidate(LT{},GT{},LT{})))
    check("parse U32 zero", number_is(Domain.parse_u32("0"), 0))
    check("parse U32 max", number_is(Domain.parse_u32("4294967295"), 4294967295))
    check("parse U32 2^32 rejects", number_rejected(Domain.parse_u32("4294967296")))
    check("parse U32 beyond 2^53 rejects", number_rejected(Domain.parse_u32("9007199254740993")))
    check("parse U32 negative rejects", number_rejected(Domain.parse_u32("-1")))
    check("parse U32 empty rejects", number_rejected(Domain.parse_u32("")))
    check("parse U32 leading zero rejects", number_rejected(Domain.parse_u32("01")))
    check("parse U32 nondigit rejects", number_rejected(Domain.parse_u32("1a")))
    IO.print("domain tests passed")
