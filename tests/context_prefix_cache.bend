import Base
import ../src/store.bend as Store
import ../src/sql.bend as Sql
import ../src/domain.bend as Domain

# The unchanged scalar production digest is the compatibility oracle. These
# tests exercise the cache's byte partition, not a second hash implementation.
type Suffix is Data:
  Suffix{ordinal: U32,offset: U32,length: U32,raw: String,context: Store.Context}

def assert(ok: Bool,label: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ label)
    case False{}:
      IO.die(Unit,1,"FAIL " ++ label)

def sample() -> Suffix:
  Suffix{7,4096,99,"raw-digest",Store.Context{"/synthetic/repo","session","model","parent"}}

def scalar(snapshot: String,generation: String,extent: U32,value: Suffix) -> String:
  Suffix{ordinal,offset,length,raw,context} = value
  Store.context_digest(snapshot,generation,extent,ordinal,offset,length,raw,context)

def cached(prefix: Store.ContextPrefix,value: Suffix) -> String:
  Suffix{ordinal,offset,length,raw,context} = value
  Store.context_digest_cached(prefix,ordinal,offset,length,raw,context)

def equivalent(+snapshot: String,+generation: String,+extent: U32,+value: Suffix,label: String) -> IO(Unit):
  assert(String.eq(cached(Store.context_prefix(snapshot,generation,extent),value),
    scalar(snapshot,generation,extent,value)),label)

def prefix_bytes(snapshot: String,generation: String,extent: U32) -> List<&2,U32>:
  Domain.encode(Store.context_version() ++ "|" ++ Store.projection_cells(
    [Sql.Cell.Text{snapshot},Sql.Cell.Text{generation},Sql.Cell.Integer{U32.show(extent)}]))

def partition(prefix: Store.ContextPrefix,+bytes: List<&2,U32>) -> Bool:
  Store.ContextPrefix{_,_,_,+hash,+remainder} = prefix
  Domain.HashContext{_,pending,used,size} = hash
  +total = U32.from_nat(List.length(&2,U32,bytes))
  +tail = U32.mod(total,64)
  U32.is_eq(used,0) && List.is_empty(&2,U32,pending) &&
    U32.is_eq(size,U32.sub(total,tail)) &&
    Domain.bytes_equal(remainder,List.drop(&2,U32,bytes,U32.to_nat(size))) &&
    String.eq(Domain.hash_finish(Domain.hash_bytes(remainder,hash)),Domain.digest(bytes))

# Pure codecs accept String header lexemes; long synthetic IDs here cover all
# 64 residual positions. They are not claims that those IDs pass database gates.
def prefix_residues(fuel: Nat,+index: Nat) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +snapshot = "9007199254740993" ++ String.repeat("7",index)
      do IO<Unit>:
        assert(partition(Store.context_prefix(snapshot,"9223372036854775807",4294967295),
          prefix_bytes(snapshot,"9223372036854775807",4294967295)),
          "cached prefix keeps only complete blocks and exact residual at offset " ++ Nat.show(index))
        equivalent(snapshot,"9223372036854775807",4294967295,sample(),
          "scalar-compatible digest for prefix residual offset " ++ Nat.show(index))
        prefix_residues(rest,1n+index)

def suffix_residues(fuel: Nat,+index: Nat,+prefix: Store.ContextPrefix) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +value = {Suffix{0,4294967295,0,"digest" ++ String.repeat("x",index),
        Store.Context{"/café/😀","session\0\n\"\\","模型",""}} : Suffix}
      do IO<Unit>:
        assert(String.eq(cached(prefix,value),scalar("9007199254740993","9007199254740995",4294967295,value)),
          "all SHA padding residues preserve Unicode and JSON escaping at suffix offset " ++ Nat.show(index))
        suffix_residues(rest,1n+index,prefix)

def changed(which: U32) -> Suffix:
  match which:
    case 0:
      Suffix{8,4096,99,"raw-digest",Store.Context{"/synthetic/repo","session","model","parent"}}
    case 1:
      Suffix{7,4097,99,"raw-digest",Store.Context{"/synthetic/repo","session","model","parent"}}
    case 2:
      Suffix{7,4096,100,"raw-digest",Store.Context{"/synthetic/repo","session","model","parent"}}
    case 3:
      Suffix{7,4096,99,"raw-digest-changed",Store.Context{"/synthetic/repo","session","model","parent"}}
    case 4:
      Suffix{7,4096,99,"raw-digest",Store.Context{"/synthetic/other","session","model","parent"}}
    case 5:
      Suffix{7,4096,99,"raw-digest",Store.Context{"/synthetic/repo","session-other","model","parent"}}
    case 6:
      Suffix{7,4096,99,"raw-digest",Store.Context{"/synthetic/repo","session","model-other","parent"}}
    case _:
      Suffix{7,4096,99,"raw-digest",Store.Context{"/synthetic/repo","session","model","parent-other"}}

def suffix_bindings(fuel: Nat,+which: U32,+prefix: Store.ContextPrefix) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +value = changed(which)
      do IO<Unit>:
        assert(String.eq(cached(prefix,value),scalar("1","2",10000,value)) &&
          Bool.not(String.eq(cached(prefix,value),cached(prefix,sample()))),
          "each of eight context suffix bindings remains independently sealed " ++ U32.show(which))
        suffix_bindings(rest,U32.inc(which),prefix)

def header_case(+snapshot: String,+generation: String,+extent: U32,+label: String) -> IO(Unit):
  do IO<Unit>:
    equivalent(snapshot,generation,extent,sample(),label)
    assert(Bool.not(String.eq(scalar(snapshot,generation,extent,sample()),scalar("1","2",10000,sample()))),
      "changed header binding changes digest " ++ label)

def reuse() -> IO(Unit):
  +prefix = Store.context_prefix("9007199254740993","9007199254740995",10000)
  do IO<Unit>:
    +first : String = cached(prefix,sample())
    +middle : String = cached(prefix,changed(7))
    +again : String = cached(prefix,sample())
    assert(String.eq(first,again) && Bool.not(String.eq(first,middle)) &&
      String.eq(first,scalar("9007199254740993","9007199254740995",10000,sample())),
      "A B A cache reuse never carries prior row suffix or finalized state")
    header_case("9007199254740993","2",10000,"odd snapshot above2^53")
    header_case("1","9007199254740995",10000,"odd generation above2^53")
    header_case("9223372036854775807","9223372036854775806",4294967295,"signed64 header maximum and U32 extent maximum")
    header_case("1","2",10001,"changed snapshot extent")
    equivalent("","",0,Suffix{0,0,0,"",Store.Context{"","","",""}},"empty codec fields preserve separators and zero quantities")
    equivalent("1","2",4294967295,Suffix{4294967295,4294967295,4294967295,"\0",Store.Context{"\0","\0","\0","\0"}},
      "all U32 maxima and NUL fields preserve exact scalar preimage")
    equivalent("quote\"\\\0😀","generation-é",0,sample(),"header JSON escaping and UTF8 stay bit-identical")

def row_context(+snapshot: String,+generation: String,+extent: U32,+ordinal: U32,+context: Store.Context) -> List<&2,Sql.Cell>:
  Store.Context{repository,session,model,parent} = context
  [Sql.Cell.Integer{generation},Sql.Cell.Integer{U32.show(ordinal)},Sql.Cell.Integer{U32.show(ordinal)},
    Sql.Cell.Integer{"1"},Sql.Cell.Text{"raw"},Sql.Cell.Text{repository},Sql.Cell.Text{session},
    Sql.Cell.Text{model},Sql.Cell.Text{parent},Sql.Cell.Text{Store.context_version()},
    Sql.Cell.Text{Store.context_digest(snapshot,generation,extent,ordinal,ordinal,1,"raw",context)}]

def row(snapshot: String,generation: String,extent: U32,+ordinal: U32) -> List<&2,Sql.Cell>:
  row_context(snapshot,generation,extent,ordinal,
    Store.Context{"/synthetic/é","session-" ++ U32.show(ordinal),"model\0","parent😀"})

def replace(cells: List<&2,Sql.Cell>,index: Nat,value: Sql.Cell) -> List<&2,Sql.Cell>:
  match cells index:
    case [] _:
      []
    case _ <> rest 0n:
      value <> rest
    case first <> rest 1n+left:
      first <> replace(rest,left,value)

def invalid_context_types(fuel: Nat,+index: Nat,+good: List<&2,Sql.Cell>,+prefix: Store.ContextPrefix) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      +changed = replace(good,index,Sql.Cell.Blob{Domain.encode(Store.field(good,index))})
      do IO<Unit>:
        assert(Bool.not(Store.prefix_context_valid(changed,"1","2",10000,7)) &&
          Bool.not(Store.prefix_context_valid_cached(changed,prefix,7)),
          "cached validator rejects byte-equivalent BLOB context field " ++ Nat.show(index))
        invalid_context_types(rest,1n+index,good,prefix)

def cell_variants() -> List<&2,Sql.Cell>:
  [Sql.Cell.Null{},Sql.Cell.Real{"7"},Sql.Cell.Blob{Domain.encode("7")},Sql.Cell.Text{"7"},
    Sql.Cell.Integer{"-1"},Sql.Cell.Integer{"4294967296"}]

def mutations(values: List<&2,Sql.Cell>,+index: Nat,+good: List<&2,Sql.Cell>,+prefix: Store.ContextPrefix) -> IO(Unit):
  match values:
    case []:
      IO.pure(Unit,Unit{})
    case +value <> rest:
      +changed = replace(good,index,value)
      do IO<Unit>:
        assert(U32.is_eq(Bool.to_u32(Store.prefix_context_valid_cached(changed,prefix,7)),
          Bool.to_u32(Store.prefix_context_valid(changed,"1","2",10000,7))),
          "cached validator preserves scalar type/value handling column " ++ Nat.show(index) ++ " " ++ Store.projection_cell(value))
        mutations(rest,index,good,prefix)

def columns(fuel: Nat,+index: Nat,+good: List<&2,Sql.Cell>,+prefix: Store.ContextPrefix) -> IO(Unit):
  match fuel:
    case 0n:
      IO.pure(Unit,Unit{})
    case 1n+rest:
      do IO<Unit>:
        mutations(cell_variants(),index,good,prefix)
        columns(rest,1n+index,good,prefix)

def validators() -> IO(Unit):
  +good = row("1","2",10000,7)
  +prefix = Store.context_prefix("1","2",10000)
  do IO<Unit>:
    assert(Store.prefix_context_valid(good,"1","2",10000,7) &&
      Store.prefix_context_valid_cached(good,prefix,7),"scalar and cached validators accept the same valid typed row")
    assert(Bool.not(Store.prefix_context_valid_cached(good,Store.context_prefix("3","2",10000),7)) &&
      Bool.not(Store.prefix_context_valid_cached(good,Store.context_prefix("1","3",10000),7)) &&
      Bool.not(Store.prefix_context_valid_cached(good,Store.context_prefix("1","2",10001),7)) &&
      Bool.not(Store.prefix_context_valid_cached(good,prefix,8)),"wrong snapshot generation extent and expected ordinal cannot reuse a valid seal")
    invalid_context_types(4n,5n,good,prefix)
    columns(11n,0n,good,prefix)
    assert(Bool.not(Store.prefix_context_valid_cached([],prefix,7)) &&
      Bool.not(Store.prefix_context_valid_cached(List.take(&2,Sql.Cell,good,10n),prefix,7)),
      "missing and truncated checkpoint rows fail cached validation")

def cell_equal(a: Sql.Cell,b: Sql.Cell) -> Bool:
  match a b:
    case Sql.Cell.Text{x} Sql.Cell.Text{y}:
      String.eq(x,y)
    case Sql.Cell.Integer{x} Sql.Cell.Integer{y}:
      String.eq(x,y)
    case _ _:
      False{}

def cells_equal(a: List<&2,Sql.Cell>,b: List<&2,Sql.Cell>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Con{x,xs} Con{y,ys}:
      cell_equal(x,y) && cells_equal(xs,ys)
    case _ _:
      False{}

def rows(fuel: Nat,+ordinal: U32) -> List<&2,List<&2,Sql.Cell>>:
  match fuel:
    case 0n:
      []
    case 1n+rest:
      row("9007199254740993","9007199254740995",10000,ordinal) <> rows(rest,U32.inc(ordinal))

def scalar_cells(values: List<&2,List<&2,Sql.Cell>>,+snapshot: String,+extent: U32) -> List<&2,Sql.Cell>:
  match values:
    case []:
      []
    case +value <> rest:
      List.append(&2,Sql.Cell,Store.context_cells(snapshot,Store.field(value,0n),extent,
        Store.number(Store.field(value,1n)),Store.number(Store.field(value,2n)),Store.number(Store.field(value,3n)),
        Store.field(value,4n),Store.prefix_context(value)),scalar_cells(rest,snapshot,extent))

def split_cells(+values: List<&2,List<&2,Sql.Cell>>,+at: Nat) -> List<&2,Sql.Cell>:
  List.append(&2,Sql.Cell,Store.copy_context_cells(List.take(&2,List<&2,Sql.Cell>,values,at),"9007199254740997",10001),
    Store.copy_context_cells(List.drop(&2,List<&2,Sql.Cell>,values,at),"9007199254740997",10001))

def batch_split(+at: Nat,+values: List<&2,List<&2,Sql.Cell>>) -> IO(Unit):
  assert(cells_equal(split_cells(values,at),scalar_cells(values,"9007199254740997",10001)),
    "typed copied cells match scalar across empty or split batch at " ++ Nat.show(at))

def batches() -> IO(Unit):
  +values = rows(33n,0)
  do IO<Unit>:
    assert(Store.context_prefix_valid_rows(List.take(&2,List<&2,Sql.Cell>,values,32n),
      "9007199254740993","9007199254740995",10000,0),"real32-row validation batch preserves every ordinal and seal")
    batch_split(0n,values)
    batch_split(1n,values)
    batch_split(7n,values)
    batch_split(31n,values)
    batch_split(32n,values)
    batch_split(33n,values)
    assert(cells_equal(Store.copy_context_cells([],"9007199254740997",10001),[]),"empty copy emits no typed values")
    +mixed : List<&2,List<&2,Sql.Cell>> = List.append(&2,List<&2,Sql.Cell>,rows(31n,0),
      [row("9007199254740993","9007199254740999",10000,31),row("9007199254740993","9007199254740995",10000,32)])
    assert(cells_equal(Store.copy_context_cells(mixed,"9007199254740997",10001),
      scalar_cells(mixed,"9007199254740997",10001)),"mixed-generation copy preserves each row generation through scalar fallback")
    assert(Bool.not(Store.context_prefix_valid_rows(mixed,"9007199254740993","9007199254740995",10000,0)),
      "a wrong-generation checkpoint late in the batch is not hidden by the first row cache")
    assert(Bool.not(cells_equal(Store.copy_context_cells(values,"9007199254740997",10001),
      scalar_cells(values,"9007199254740993",10000))),"new snapshot and extent re-seal copied rows rather than reusing old digests")

def large() -> IO(Unit):
  +context = {Store.Context{String.repeat("é",530000n),"session\0","模型","😀"} : Store.Context}
  do IO<Unit>:
    equivalent("9007199254740993","9007199254740995",4294967295,
      Suffix{32,262144,262144,"captured-digest",context},
      "synthetic context over1MiB UTF8 preserves full scalar digest without truncation")
    +value : List<&2,Sql.Cell> = [Sql.Cell.Integer{"9007199254740995"},Sql.Cell.Integer{"32"},
      Sql.Cell.Integer{"262144"},Sql.Cell.Integer{"262144"},Sql.Cell.Text{"captured-digest"},
      Sql.Cell.Text{String.repeat("é",530000n)},Sql.Cell.Text{"session\0"},Sql.Cell.Text{"模型"},Sql.Cell.Text{"😀"},
      Sql.Cell.Text{Store.context_version()},Sql.Cell.Text{"unused-copy-input-seal"}]
    assert(cells_equal(Store.copy_context_cells([value],"9007199254740997",4294967295),
      scalar_cells([value],"9007199254740997",4294967295)),"single oversized synthetic copy keeps all four context strings and eight typed cells")

def main() -> IO(Unit):
  do IO<Unit>:
    prefix_residues(64n,0n)
    suffix_residues(128n,0n,Store.context_prefix("9007199254740993","9007199254740995",4294967295))
    suffix_bindings(8n,0,Store.context_prefix("1","2",10000))
    reuse()
    validators()
    batches()
    large()
