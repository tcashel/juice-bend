import Base
import ../src/context_binding.bend as Binding
import ../src/domain.bend as Domain
import ../src/store.bend as Store
import ../src/sql.bend as Sql

# Pure codec tests. Store is used only as the unchanged legacy digest oracle.
# No SQLite connection, source file or persisted application state is opened.
def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def string_result(result: Result<&2,&2,String,String>) -> IO(String):
  match result:
    case Done{value}:
      IO.pure(String,value)
    case Fail{message}:
      IO.die(String,1,"FAIL expected valid codec digest: " ++ message)

def prefix_result(result: Result<&2,&2,String,Binding.Prefix>) -> IO(Binding.Prefix):
  match result:
    case Done{value}:
      IO.pure(Binding.Prefix,value)
    case Fail{message}:
      IO.die(Binding.Prefix,1,"FAIL expected valid codec prefix: " ++ message)

def failed(result: Result<&2,&2,String,String>,label: String) -> IO(Unit):
  match result:
    case Done{_}:
      assert(False{},label)
    case Fail{message}:
      assert(Bool.not(String.is_empty(message)),label)

def budget_failed(result: Result<&2,&2,String,String>,label: String) -> IO(Unit):
  match result:
    case Done{_}:
      assert(False{},label)
    case Fail{+message}:
      assert(String.contains(message,"budget") && String.contains(message,"U32_MAX"),label)

def prefix_failed(result: Result<&2,&2,String,Binding.Prefix>,label: String) -> IO(Unit):
  match result:
    case Done{_}:
      assert(False{},label)
    case Fail{message}:
      assert(Bool.not(String.is_empty(message)),label)

def raw_digest() -> String:
  "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

def sample_binding() -> Binding.Binding:
  Binding.Binding{"parser-α","9007199254740993","claude","/synthetic/café","9223372036854775807"}

def sample_raw() -> Binding.Raw:
  Binding.Raw{"9007199254740995",7,4294967295,0,raw_digest()}

def sample_context() -> Binding.Context:
  Binding.Context{"/repo/🍋","s\0\"\\:\n|","模型",""}

def store_context(context: Binding.Context) -> Store.Context:
  Binding.Context{repository,session,model,parent} = context
  Store.Context{repository,session,model,parent}

# Expected v2 framing is literal and independent of every codec cell encoder.
# Neither Binding.binding_cells nor Binding.raw_cells produces oracle bytes.
def expected_prefix() -> String:
  "parser-α|incoming-context-v2|text:\"parser-α\":integer:\"9007199254740993\":" ++
    "text:\"claude\":text:\"/synthetic/café\":integer:\"9223372036854775807\":"

def expected_raw() -> String:
  "integer:\"9007199254740995\":integer:\"7\":integer:\"4294967295\":integer:\"0\":" ++
    "text:\"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef\":"

def expected_context() -> String:
  "text:\"/repo/🍋\":text:\"s\\u0000\\\"\\\\:\\u000a|\":text:\"模型\":text:\"\":"

def legacy_case(+legacy: Binding.Legacy,+raw: Binding.Raw,+context: Binding.Context,label: String) -> IO(Unit):
  Binding.Legacy{snapshot,generation,extent} = legacy
  Binding.Raw{_,ordinal,offset,length,digest} = raw
  assert(String.eq(Binding.digest_v1(Store.projection_version(),legacy,raw,context),
    Store.context_digest(snapshot,generation,extent,ordinal,offset,length,digest,store_context(context))),label)

def legacy_compatibility() -> IO(Unit):
  +legacy = {Binding.Legacy{"9007199254740993","9223372036854775807",4294967295} : Binding.Legacy}
  +raw = sample_raw()
  +context = sample_context()
  +hash = Binding.digest_v1(Store.projection_version(),legacy,raw,context)
  do IO<Unit>:
    legacy_case(legacy,raw,context,"v1 bytes equal unchanged Store digest for wide identities Unicode NUL and maxima")
    legacy_case(Binding.Legacy{"","",0},Binding.Raw{"ignored",0,0,0,""},
      Binding.Context{"","","",""},"v1 scalar preserves empty lexemes and zero quantities exactly")
    legacy_case(Binding.Legacy{"quote\"\\\0🍋","generation-é",4294967295},
      Binding.Raw{"ignored",4294967295,4294967295,4294967295,"\0"},Binding.Context{"\0","\0","\0","\0"},
      "v1 scalar preserves escaped legacy lexemes and all U32 maxima")
    assert(String.eq(hash,Binding.digest_v1(Store.projection_version(),legacy,
      Binding.Raw{"9223372036854775807",7,4294967295,0,raw_digest()},context)),
      "legacy digest intentionally ignores the added raw identity field")
    assert(Binding.verify_v1(Store.projection_version(),legacy,raw,context,
      Binding.version_v1(Store.projection_version()),hash),"valid historical v1 tag and digest verify without reinterpretation")
    assert(Bool.not(Binding.verify_v1(Store.projection_version(),legacy,raw,context,
      Binding.version_v2(Store.projection_version()),hash)),"v1 verification rejects a v2 tag despite matching legacy digest")
    assert(Bool.not(Binding.verify_v1(Store.projection_version(),legacy,raw,context,
      Binding.version_v1(Store.projection_version()),"damaged")),"v1 verification rejects a changed stored digest")

def is_legacy(format: Binding.Format) -> Bool:
  match format:
    case Binding.Format.Legacy{}:
      True{}
    case _:
      False{}

def is_portable(format: Binding.Format) -> Bool:
  match format:
    case Binding.Format.Portable{}:
      True{}
    case _:
      False{}

def is_unknown(format: Binding.Format) -> Bool:
  match format:
    case Binding.Format.Unknown{}:
      True{}
    case _:
      False{}

def formats() -> IO(Unit):
  do IO<Unit>:
    assert(String.eq(Binding.format_v1(),"incoming-context-v1") &&
      String.eq(Binding.format_v2(),"incoming-context-v2"),"format names explicitly distinguish legacy and portable commitments")
    assert(String.eq(Binding.version_v1("parser"),"parser|incoming-context-v1") &&
      String.eq(Binding.version_v2("parser"),"parser|incoming-context-v2"),"version tags contain exact parser and format framing")
    assert(is_legacy(Binding.classify("parser","parser|incoming-context-v1")),"exact v1 tag is classified as historical")
    assert(is_portable(Binding.classify("parser","parser|incoming-context-v2")),"exact v2 tag is classified as portable")
    assert(is_unknown(Binding.classify("parser","other|incoming-context-v2")) &&
      is_unknown(Binding.classify("parser","parser|incoming-context-v20")) &&
      is_unknown(Binding.classify("parser","parser|incoming-context-v2\0")) &&
      is_unknown(Binding.classify("parser","")),"wrong parser unknown version suffix NUL and empty tags remain unknown")

def codec_vector() -> IO(Unit):
  +binding = sample_binding()
  +raw = sample_raw()
  +context = sample_context()
  +expected = Domain.digest(Domain.encode(expected_prefix() ++ expected_raw() ++ expected_context()))
  do IO<Unit>:
    assert(Nat.is_eq(List.length(&2,U32,Domain.encode(expected_prefix() ++ expected_raw() ++ expected_context())),353n) &&
      String.eq(expected,"867261d6c90da73bf16df82b3f385b5a3685282bb9e8c96fceaf394e9242e06e"),
      "independent353-byte vector agrees with external SHA256 oracle")
    +prefix : Binding.Prefix <- prefix_result(Binding.prefix(binding))
    +scalar : String <- string_result(Binding.digest_v2(binding,raw,context))
    cached : String <- string_result(Binding.digest_cached(prefix,raw,context))
    assert(String.eq(scalar,expected),"v2 scalar matches independently framed exact UTF8 typed preimage")
    assert(String.eq(cached,expected),"cached v2 matches the independent preimage")
    assert(Binding.verify_v2(prefix,raw,context,"parser-α|incoming-context-v2",expected),
      "valid portable tag and exact digest verify")
    assert(Bool.not(Binding.verify_v2(prefix,raw,context,"parser-α|incoming-context-v1",expected)) &&
      Bool.not(Binding.verify_v2(prefix,raw,context,"other|incoming-context-v2",expected)) &&
      Bool.not(Binding.verify_v2(prefix,raw,context,"parser-α|incoming-context-v2","damaged")),
      "portable verifier refuses legacy wrong-parser and changed digest inputs")

def changed_binding(cases: List<&2,Binding.Binding>,+original: String,+index: U32) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case +binding <> rest:
      do IO<Unit>:
        actual : String <- string_result(Binding.digest_v2(binding,sample_raw(),sample_context()))
        assert(Bool.not(String.eq(actual,original)),"portable commitment binds header field " ++ U32.show(index))
        changed_binding(rest,original,U32.inc(index))

def changed_raw(cases: List<&2,Binding.Raw>,+prefix: Binding.Prefix,+original: String,+index: U32) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case raw <> rest:
      do IO<Unit>:
        actual : String <- string_result(Binding.digest_cached(prefix,raw,sample_context()))
        assert(Bool.not(String.eq(actual,original)),"portable commitment binds raw field " ++ U32.show(index))
        changed_raw(rest,prefix,original,U32.inc(index))

def changed_context(cases: List<&2,Binding.Context>,+prefix: Binding.Prefix,+original: String,+index: U32) -> IO(Unit):
  match cases:
    case []:
      IO.pure(Unit,Unit{})
    case context <> rest:
      do IO<Unit>:
        actual : String <- string_result(Binding.digest_cached(prefix,sample_raw(),context))
        assert(Bool.not(String.eq(actual,original)),"portable commitment binds context field " ++ U32.show(index))
        changed_context(rest,prefix,original,U32.inc(index))

def all_bindings() -> IO(Unit):
  do IO<Unit>:
    +original : String <- string_result(Binding.digest_v2(sample_binding(),sample_raw(),sample_context()))
    +prefix : Binding.Prefix <- prefix_result(Binding.prefix(sample_binding()))
    changed_binding([
      Binding.Binding{"parser-β","9007199254740993","claude","/synthetic/café","9223372036854775807"},
      Binding.Binding{"parser-α","9007199254740992","claude","/synthetic/café","9223372036854775807"},
      Binding.Binding{"parser-α","9007199254740993","codex","/synthetic/café","9223372036854775807"},
      Binding.Binding{"parser-α","9007199254740993","claude","/synthetic/other","9223372036854775807"},
      Binding.Binding{"parser-α","9007199254740993","claude","/synthetic/café","9223372036854775806"}],original,0)
    changed_raw([
      Binding.Raw{"9007199254740994",7,4294967295,0,raw_digest()},
      Binding.Raw{"9007199254740995",8,4294967295,0,raw_digest()},
      Binding.Raw{"9007199254740995",7,4294967294,0,raw_digest()},
      Binding.Raw{"9007199254740995",7,4294967295,1,raw_digest()},
      Binding.Raw{"9007199254740995",7,4294967295,0,String.repeat("a",64n)}],prefix,original,0)
    changed_context([
      Binding.Context{"/other","s\0\"\\:\n|","模型",""},
      Binding.Context{"/repo/🍋","other","模型",""},
      Binding.Context{"/repo/🍋","s\0\"\\:\n|","other",""},
      Binding.Context{"/repo/🍋","s\0\"\\:\n|","模型","other"}],prefix,original,0)

def cell_equal(a: Sql.Cell,b: Sql.Cell) -> Bool:
  match a b:
    case Sql.Cell.Integer{x} Sql.Cell.Integer{y}:
      String.eq(x,y)
    case Sql.Cell.Text{x} Sql.Cell.Text{y}:
      String.eq(x,y)
    case _ _:
      False{}

def cells_equal(a: List<&2,Sql.Cell>,b: List<&2,Sql.Cell>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{first,rest} Con{other,tail}:
      cell_equal(first,other) && cells_equal(rest,tail)
    case _ _:
      False{}

type Section is Data:
  Header{}
  Raw{}
  Context{}

def binding_missing(value: Maybe<&2,Binding.Binding>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def raw_missing(value: Maybe<&2,Binding.Raw>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def context_missing(value: Maybe<&2,Binding.Context>) -> Bool:
  match value:
    case None{}:
      True{}
    case _:
      False{}

def missing(section: Section,cells: List<&2,Sql.Cell>) -> Bool:
  match section:
    case Header{}:
      binding_missing(Binding.decode_binding(cells))
    case Raw{}:
      raw_missing(Binding.decode_raw(cells))
    case Context{}:
      context_missing(Binding.decode_context(cells))

def decoded_binding(value: Maybe<&2,Binding.Binding>,expected: List<&2,Sql.Cell>) -> Bool:
  match value:
    case Some{binding}:
      cells_equal(Binding.binding_cells(binding),expected)
    case None{}:
      False{}

def decoded_raw(value: Maybe<&2,Binding.Raw>,expected: List<&2,Sql.Cell>) -> Bool:
  match value:
    case Some{raw}:
      cells_equal(Binding.raw_cells(raw),expected)
    case None{}:
      False{}

def decoded_context(value: Maybe<&2,Binding.Context>,expected: List<&2,Sql.Cell>) -> Bool:
  match value:
    case Some{context}:
      cells_equal(Binding.context_cells(context),expected)
    case None{}:
      False{}

def replace(cells: List<&2,Sql.Cell>,index: Nat,value: Sql.Cell) -> List<&2,Sql.Cell>:
  match cells index:
    case [] _:
      []
    case _ <> rest 0n:
      value <> rest
    case first <> rest 1n+left:
      first <> replace(rest,left,value)

def wrong_types(fuel: Nat,+index: Nat,+section: Section,+cells: List<&2,Sql.Cell>,+label: String) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        assert(missing(section,replace(cells,index,Sql.Cell.Null{})) &&
          missing(section,replace(cells,index,Sql.Cell.Real{"1"})) &&
          missing(section,replace(cells,index,Sql.Cell.Blob{[49]})),
          label ++ " rejects Null Real and Blob at field " ++ Nat.show(index))
        wrong_types(rest,1n+index,section,cells,label)

def malformed_values(values: List<&2,String>,+section: Section,+cells: List<&2,Sql.Cell>,
  +index: Nat,+label: String) -> IO(Unit):
  match values:
    case []:
      IO.pure(Unit,Unit{})
    case +value <> rest:
      do IO<Unit>:
        assert(missing(section,replace(cells,index,Sql.Cell.Integer{value})),
          label ++ " refuses noncanonical numeric lexeme " ++ value)
        malformed_values(rest,section,cells,index,label)

def bad_ids() -> List<&2,String>:
  ["","0","01","+1","-1","1.0","1e0"," 1","1 ","9223372036854775808","9007199254740993.0"]

def bad_u32() -> List<&2,String>:
  ["","-1","00","01","+0","1.0"," 0","4294967296"]

def malformed_digest(values: List<&2,String>,+cells: List<&2,Sql.Cell>) -> IO(Unit):
  match values:
    case []:
      IO.pure(Unit,Unit{})
    case value <> rest:
      do IO<Unit>:
        assert(missing(Raw{},replace(cells,4n,Sql.Cell.Text{value})),
          "raw decoder rejects noncanonical lowercase64hex digest")
        malformed_digest(rest,cells)

def unicode_columns(indices: List<&2,Nat>,+section: Section,+cells: List<&2,Sql.Cell>,+label: String) -> IO(Unit):
  match indices:
    case []:
      IO.pure(Unit,Unit{})
    case +index <> rest:
      do IO<Unit>:
        assert(missing(section,replace(cells,index,Sql.Cell.Text{SCon{Chr{55296},""}})) &&
          missing(section,replace(cells,index,Sql.Cell.Text{SCon{Chr{1114112},""}})),
          label ++ " rejects surrogate and above-Unicode scalars at field " ++ Nat.show(index))
        unicode_columns(rest,section,cells,label)

def decoders() -> IO(Unit):
  +header = Binding.binding_cells(sample_binding())
  +raw = Binding.raw_cells(sample_raw())
  +context = Binding.context_cells(sample_context())
  do IO<Unit>:
    assert(cells_equal(header,[Sql.Cell.Text{"parser-α"},Sql.Cell.Integer{"9007199254740993"},
      Sql.Cell.Text{"claude"},Sql.Cell.Text{"/synthetic/café"},Sql.Cell.Integer{"9223372036854775807"}]),
      "binding encoder preserves independent typed field order")
    assert(cells_equal(raw,[Sql.Cell.Integer{"9007199254740995"},Sql.Cell.Integer{"7"},
      Sql.Cell.Integer{"4294967295"},Sql.Cell.Integer{"0"},Sql.Cell.Text{raw_digest()}]),
      "raw encoder preserves exact wide identity and all quantities")
    assert(cells_equal(context,[Sql.Cell.Text{"/repo/🍋"},Sql.Cell.Text{"s\0\"\\:\n|"},
      Sql.Cell.Text{"模型"},Sql.Cell.Text{""}]),"context encoder preserves all four text fields")
    assert(decoded_binding(Binding.decode_binding(header),header),"strict binding decoder roundtrips wide signed64 values")
    assert(decoded_raw(Binding.decode_raw(raw),raw),"strict raw decoder roundtrips above2^53 identity without aliasing")
    assert(decoded_context(Binding.decode_context(context),context),"strict context decoder preserves Unicode NUL and empty text")
    +maximum : List<&2,Sql.Cell> = [Sql.Cell.Integer{"9223372036854775807"},Sql.Cell.Integer{"4294967295"},
      Sql.Cell.Integer{"4294967295"},Sql.Cell.Integer{"4294967295"},Sql.Cell.Text{raw_digest()}]
    assert(decoded_raw(Binding.decode_raw(maximum),maximum),"pure raw codec accepts signed64 maximum and all U32 maxima")
    wrong_types(5n,0n,Header{},header,"binding decoder")
    wrong_types(5n,0n,Raw{},raw,"raw decoder")
    wrong_types(4n,0n,Context{},context,"context decoder")
    assert(missing(Header{},replace(header,0n,Sql.Cell.Integer{"1"})) &&
      missing(Header{},replace(header,1n,Sql.Cell.Text{"9007199254740993"})) &&
      missing(Header{},replace(header,4n,Sql.Cell.Text{"9223372036854775807"})),
      "binding decoder never coerces Text identities or Integer parser")
    assert(missing(Raw{},replace(raw,0n,Sql.Cell.Text{"9007199254740995"})) &&
      missing(Raw{},replace(raw,1n,Sql.Cell.Text{"7"})) &&
      missing(Context{},replace(context,0n,Sql.Cell.Integer{"1"})),
      "raw and context decoders never coerce byte-equivalent scalar types")
    assert(missing(Header{},[]) && missing(Header{},List.take(&2,Sql.Cell,header,4n)) &&
      missing(Header{},List.append(&2,Sql.Cell,header,[Sql.Cell.Text{"extra"}])),
      "binding decoder rejects empty short and extra-field shapes")
    assert(missing(Raw{},[]) && missing(Raw{},List.take(&2,Sql.Cell,raw,4n)) &&
      missing(Raw{},List.append(&2,Sql.Cell,raw,[Sql.Cell.Text{"extra"}])),
      "raw decoder rejects empty short and extra-field shapes")
    assert(missing(Context{},[]) && missing(Context{},List.take(&2,Sql.Cell,context,3n)) &&
      missing(Context{},List.append(&2,Sql.Cell,context,[Sql.Cell.Text{"extra"}])),
      "context decoder rejects empty short and extra-field shapes")
    malformed_values(bad_ids(),Header{},header,1n,"source")
    malformed_values(bad_ids(),Header{},header,4n,"generation")
    malformed_values(bad_ids(),Raw{},raw,0n,"raw identity")
    malformed_values(bad_u32(),Raw{},raw,1n,"raw ordinal")
    malformed_values(bad_u32(),Raw{},raw,2n,"raw offset")
    malformed_values(bad_u32(),Raw{},raw,3n,"raw length")
    malformed_digest(["",String.repeat("a",63n),String.repeat("a",65n),String.repeat("A",64n),
      String.repeat("g",64n),String.repeat("é",64n),String.repeat("a",63n) ++ "\0"],raw)
    unicode_columns([0n,2n,3n],Header{},header,"binding decoder")
    unicode_columns([0n,1n,2n,3n],Context{},context,"context decoder")

def partition(prefix: Binding.Prefix,+bytes: List<&2,U32>) -> Bool:
  Binding.Prefix{_,+hash,+remainder} = prefix
  Domain.HashContext{_,pending,used,+size} = hash
  +length = U32.from_nat(List.length(&2,U32,bytes))
  +tail = U32.mod(length,64)
  U32.is_eq(used,0) && List.is_empty(&2,U32,pending) &&
    U32.is_eq(size,U32.sub(length,tail)) &&
    Domain.bytes_equal(remainder,List.drop(&2,U32,bytes,U32.to_nat(size))) &&
    String.eq(Domain.hash_finish(Domain.hash_bytes(remainder,hash)),Domain.digest(bytes))

def residual_binding(padding: String) -> Binding.Binding:
  Binding.Binding{"p","1","codex","/synthetic/" ++ padding,"2"}

def residual_prefix(padding: String) -> String:
  "p|incoming-context-v2|text:\"p\":integer:\"1\":text:\"codex\":text:\"/synthetic/" ++
    padding ++ "\":integer:\"2\":"

def prefix_residues(fuel: Nat,+index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +padding = String.repeat("x",index)
      +binding = residual_binding(padding)
      do IO<Unit>:
        +prefix : Binding.Prefix <- prefix_result(Binding.prefix(binding))
        assert(partition(prefix,Domain.encode(residual_prefix(padding))),
          "cached prefix preserves aligned blocks and exact forward remainder at residual offset " ++ Nat.show(index))
        scalar : String <- string_result(Binding.digest_v2(binding,sample_raw(),sample_context()))
        +cached : String <- string_result(Binding.digest_cached(prefix,sample_raw(),sample_context()))
        assert(String.eq(scalar,cached) && String.eq(cached,Domain.digest(Domain.encode(
          residual_prefix(padding) ++ expected_raw() ++ expected_context()))),
          "all64 prefix residues agree with scalar and independent framing " ++ Nat.show(index))
        prefix_residues(rest,1n+index)

def suffix_residues(fuel: Nat,+index: Nat,+prefix: Binding.Prefix) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +padding = String.repeat("x",index)
      +context = {Binding.Context{padding,"s\0\"\\:\n|","模型",""} : Binding.Context}
      do IO<Unit>:
        scalar : String <- string_result(Binding.digest_v2(sample_binding(),sample_raw(),context))
        +cached : String <- string_result(Binding.digest_cached(prefix,sample_raw(),context))
        expected : String = Domain.digest(Domain.encode(expected_prefix() ++ expected_raw() ++
          "text:\"" ++ padding ++ "\":text:\"s\\u0000\\\"\\\\:\\u000a|\":text:\"模型\":text:\"\":"))
        assert(String.eq(scalar,cached) && String.eq(cached,expected),
          "all128 suffix padding positions preserve exact UTF8 framing " ++ Nat.show(index))
        suffix_residues(rest,1n+index,prefix)

def cache_reuse() -> IO(Unit):
  +binding = sample_binding()
  +raw = sample_raw()
  +context = sample_context()
  do IO<Unit>:
    +prefix : Binding.Prefix <- prefix_result(Binding.prefix(binding))
    +first : String <- string_result(Binding.digest_cached(prefix,raw,context))
    middle : String <- string_result(Binding.digest_cached(prefix,raw,Binding.Context{"/different","","",""}))
    again : String <- string_result(Binding.digest_cached(prefix,raw,context))
    assert(String.eq(first,again) && Bool.not(String.eq(first,middle)),
      "A B A cache reuse preserves immutable header state without prior suffix bytes")
    suffix_residues(128n,0n,prefix)
    +large : Binding.Context = Binding.Context{String.repeat("é",530000n),"s\0","模型","🍋"}
    scalar : String <- string_result(Binding.digest_v2(binding,raw,large))
    cached : String <- string_result(Binding.digest_cached(prefix,raw,large))
    assert(String.eq(scalar,cached),"context over1MiB UTF8 hashes completely without truncation")

def invalid_inputs() -> IO(Unit):
  +raw = sample_raw()
  +context = sample_context()
  do IO<Unit>:
    +prefix : Binding.Prefix <- prefix_result(Binding.prefix(sample_binding()))
    prefix_failed(Binding.prefix(Binding.Binding{"p","01","claude","/synthetic","2"}),
      "prefix creation returns an explicit invalid-binding failure")
    prefix_failed(Binding.prefix(Binding.Binding{SCon{Chr{55296},""},"1","claude","/synthetic","2"}),
      "prefix creation rejects invalid Unicode before hashing")
    failed(Binding.digest_v2(Binding.Binding{"p","0","claude","/synthetic","2"},raw,context),
      "scalar digest returns explicit invalid-binding failure")
    failed(Binding.digest_v2(sample_binding(),raw,Binding.Context{SCon{Chr{55296},""},"","",""}),
      "scalar digest rejects invalid Unicode before encoding context")
    failed(Binding.digest_cached(prefix,Binding.Raw{"01",7,0,1,raw_digest()},context),
      "cached digest revalidates each raw identity")
    failed(Binding.digest_cached(prefix,Binding.Raw{"1",7,0,1,"bad"},context),
      "cached digest revalidates each raw digest")
    failed(Binding.digest_cached(prefix,raw,Binding.Context{SCon{Chr{1114112},""},"","",""}),
      "cached digest revalidates each context Unicode scalar")
    assert(Bool.not(Binding.verify_v2(prefix,Binding.Raw{"01",7,0,1,raw_digest()},context,
      "parser-α|incoming-context-v2","")),"invalid portable inputs cannot verify by matching an empty failure value")
    empty_prefix : Binding.Prefix <- prefix_result(Binding.prefix(Binding.Binding{"","1","","\0","2"}))
    empty_hash : String <- string_result(Binding.digest_cached(empty_prefix,raw,Binding.Context{"","","",""}))
    assert(Nat.is_eq(String.length(empty_hash),64n),"pure codec accepts empty and NUL scalar binding text without source-policy assumptions")

def byte_budget() -> IO(Unit):
  do IO<Unit>:
    assert(Binding.hash_room(4294967295,[]),"byte budget accepts no addition at exact U32 capacity")
    assert(Bool.not(Binding.hash_room(4294967295,[0])),"byte budget rejects one byte beyond U32 capacity")
    assert(Binding.hash_room(4294967291,[0,1,2,3]),"byte budget accepts exactly remaining bytes")
    assert(Bool.not(Binding.hash_room(4294967292,[0,1,2,3])),"byte budget rejects one-byte wraparound")
    assert(Binding.hash_room(4294967291,Domain.encode("🍋")) &&
      Bool.not(Binding.hash_room(4294967292,Domain.encode("🍋"))),
      "byte budget counts actual UTF8 bytes with bounded test allocations")
    budget_failed(Binding.digest_cached(Binding.Prefix{sample_binding(),
      Domain.HashContext{Domain.hash_initial(),[],0,4294967295},[]},sample_raw(),sample_context()),
      "cached digest returns explicit byte-budget failure before hashing a suffix")
    budget_failed(Binding.digest_cached(Binding.Prefix{sample_binding(),
      Domain.HashContext{Domain.hash_initial(),[],0,4294967290},[1,2,3,4,5,6]},sample_raw(),sample_context()),
      "cached digest counts its retained forward remainder in the byte budget")

def main() -> IO(Unit):
  do IO<Unit>:
    formats()
    legacy_compatibility()
    codec_vector()
    all_bindings()
    decoders()
    prefix_residues(64n,0n)
    cache_reuse()
    invalid_inputs()
    byte_budget()
    IO.print("Context binding codec suite passed")
