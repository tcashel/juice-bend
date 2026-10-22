import Base
import ./sql.bend as Sql
import ./domain.bend as Domain
import ./json.bend as Json

# Pure context checksum codecs. Legacy bytes are frozen
# independently of the portable format; a tag is never silently reinterpreted.
# This module does not authenticate raw records, snapshot mappings or a reusable
# prefix. Those remain the importing transaction's responsibility.
type Context is Data:
  Context{repository: String,session: String,model: String,parent: String}

type Legacy is Data:
  Legacy{snapshot: String,generation: String,extent: U32}

type Binding is Data:
  Binding{parser: String,source: String,provider: String,locator: String,generation: String}

type Raw is Data:
  Raw{identity: String,ordinal: U32,offset: U32,length: U32,digest: String}

type Format is Data:
  Format.Legacy{}
  Format.Portable{}
  Format.Unknown{}

# Internal Bend state, not a persisted capability. The constructor is exported
# by Bend: callers must obtain this state through prefix, not deserialize it.
# Validate immutable identity and text once, then clone the aligned hash state
# per row without rescanning or re-encoding its source locator.
type Prefix is Data:
  Prefix{binding: Binding,hash: Domain.HashContext,remainder: List<&2,U32>}

def format_v1() -> String:
  "incoming-context-v1"

def format_v2() -> String:
  "incoming-context-v2"

def version_v1(parser: String) -> String:
  parser ++ "|" ++ format_v1()

def version_v2(parser: String) -> String:
  parser ++ "|" ++ format_v2()

def classified(legacy: Bool,portable: Bool) -> Format:
  match legacy portable:
    case True{} _:
      Format.Legacy{}
    case False{} True{}:
      Format.Portable{}
    case False{} False{}:
      Format.Unknown{}

def classify(+parser: String,+tag: String) -> Format:
  classified(String.eq(tag,version_v1(parser)),String.eq(tag,version_v2(parser)))

def encoded_cell(cell: Sql.Cell) -> String:
  match cell:
    case Sql.Cell.Integer{value}:
      "integer:" ++ Json.quote(value)
    case Sql.Cell.Text{value}:
      "text:" ++ Json.quote(value)
    case _:
      "invalid"

# Only typed constructors below feed these encoders. Strict row decoders reject
# all other SQLite storage classes before hashing, including byte-equal BLOBs.
def encoded(cells: List<&2,Sql.Cell>) -> String:
  match cells:
    case []:
      ""
    case cell <> rest:
      encoded_cell(cell) ++ ":" ++ encoded(rest)

def context_cells(context: Context) -> List<&2,Sql.Cell>:
  Context{repository,session,model,parent} = context
  [Sql.Cell.Text{repository},Sql.Cell.Text{session},Sql.Cell.Text{model},Sql.Cell.Text{parent}]

def binding_cells(binding: Binding) -> List<&2,Sql.Cell>:
  Binding{parser,source,provider,locator,generation} = binding
  [Sql.Cell.Text{parser},Sql.Cell.Integer{source},Sql.Cell.Text{provider},
    Sql.Cell.Text{locator},Sql.Cell.Integer{generation}]

def raw_cells(raw: Raw) -> List<&2,Sql.Cell>:
  Raw{identity,ordinal,offset,length,digest} = raw
  [Sql.Cell.Integer{identity},Sql.Cell.Integer{U32.show(ordinal)},
    Sql.Cell.Integer{U32.show(offset)},Sql.Cell.Integer{U32.show(length)},Sql.Cell.Text{digest}]

# Preserve v1 exactly, including Text (not Integer) snapshot/generation cells,
# omission of raw identity, the old parser tag and trailing field separators.
# These arguments came from existing validated raw/context paths; intentionally
# do not introduce the stricter portable decoder into historical validation.
def digest_v1(parser: String,legacy: Legacy,raw: Raw,context: Context) -> String:
  Legacy{snapshot,generation,extent} = legacy
  Raw{_,ordinal,offset,length,digest} = raw
  Domain.digest(Domain.encode(version_v1(parser) ++ "|" ++ encoded(
    List.append(&2,Sql.Cell,[Sql.Cell.Text{snapshot},Sql.Cell.Text{generation},
      Sql.Cell.Integer{U32.show(extent)},Sql.Cell.Integer{U32.show(ordinal)},
      Sql.Cell.Integer{U32.show(offset)},Sql.Cell.Integer{U32.show(length)},Sql.Cell.Text{digest}],
      context_cells(context)))))

def verify_v1(+parser: String,legacy: Legacy,raw: Raw,context: Context,tag: String,stored: String) -> Bool:
  String.eq(tag,version_v1(parser)) && String.eq(stored,digest_v1(parser,legacy,raw,context))

def digits(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+code},rest}:
      U32.is_ge(code,48) && U32.is_le(code,57) && digits(rest)

def positive_decimal(+text: String) -> Bool:
  match text:
    case SCon{Chr{+code},rest}:
      U32.is_ge(code,49) && U32.is_le(code,57) && digits(rest)
    case SNil{}:
      False{}

# Never convert SQLite identities to Nat, U32 or floating point. The strict
# decimal lexeme retains every bit of positive signed64 identity.
def identity(+text: String) -> Bool:
  positive_decimal(text) &&
    (Nat.is_lt(String.length(text),19n) ||
      (Nat.is_eq(String.length(text),19n) &&
        Bool.not(Cmp.is_gt(String.order(text,"9223372036854775807")))))

def hex_digits(text: String) -> Bool:
  match text:
    case SNil{}:
      True{}
    case SCon{Chr{+code},rest}:
      ((U32.is_ge(code,48) && U32.is_le(code,57)) ||
        (U32.is_ge(code,97) && U32.is_le(code,102))) && hex_digits(rest)

def raw_valid(raw: Raw) -> Bool:
  Raw{identity_text,_,_,_,+digest} = raw
  identity(identity_text) && Nat.is_eq(String.length(digest),64n) && hex_digits(digest)

def binding_valid(binding: Binding) -> Bool:
  Binding{parser,source,provider,locator,generation} = binding
  identity(source) && identity(generation) && Domain.scalar_string(parser) &&
    Domain.scalar_string(provider) && Domain.scalar_string(locator)

def context_valid(context: Context) -> Bool:
  Context{repository,session,model,parent} = context
  Domain.scalar_string(repository) && Domain.scalar_string(session) &&
    Domain.scalar_string(model) && Domain.scalar_string(parent)

def binding_decoded(binding: Binding,valid: Bool) -> Maybe<&2,Binding>:
  match valid:
    case True{}:
      Some{binding}
    case False{}:
      None{}

def decode_binding(cells: List<&2,Sql.Cell>) -> Maybe<&2,Binding>:
  match cells:
    case [Sql.Cell.Text{parser},Sql.Cell.Integer{source},Sql.Cell.Text{provider},
        Sql.Cell.Text{locator},Sql.Cell.Integer{generation}]:
      +binding = {Binding{parser,source,provider,locator,generation} : Binding}
      binding_decoded(binding,binding_valid(binding))
    case _:
      None{}

def raw_decoded(raw: Raw,valid: Bool) -> Maybe<&2,Raw>:
  match valid:
    case True{}:
      Some{raw}
    case False{}:
      None{}

def raw_numbers(identity_text: String,ordinal: Maybe<&2,U32>,offset: Maybe<&2,U32>,
  length: Maybe<&2,U32>,digest: String) -> Maybe<&2,Raw>:
  match ordinal offset length:
    case Some{o} Some{p} Some{n}:
      +raw = {Raw{identity_text,o,p,n,digest} : Raw}
      raw_decoded(raw,raw_valid(raw))
    case _ _ _:
      None{}

def decode_raw(cells: List<&2,Sql.Cell>) -> Maybe<&2,Raw>:
  match cells:
    case [Sql.Cell.Integer{id},Sql.Cell.Integer{ordinal},Sql.Cell.Integer{offset},
        Sql.Cell.Integer{length},Sql.Cell.Text{digest}]:
      raw_numbers(id,Domain.parse_u32(ordinal),Domain.parse_u32(offset),Domain.parse_u32(length),digest)
    case _:
      None{}

def context_decoded(context: Context,valid: Bool) -> Maybe<&2,Context>:
  match valid:
    case True{}:
      Some{context}
    case False{}:
      None{}

def decode_context(cells: List<&2,Sql.Cell>) -> Maybe<&2,Context>:
  match cells:
    case [Sql.Cell.Text{repository},Sql.Cell.Text{session},Sql.Cell.Text{model},Sql.Cell.Text{parent}]:
      +context = {Context{repository,session,model,parent} : Context}
      context_decoded(context,context_valid(context))
    case _:
      None{}

# SHA's saved message length is U32. Check the full serialized message bytes
# as Nat before any narrowing/feed; SHA padding is not serialized message data.
def hash_room(used: U32,bytes: List<&2,U32>) -> Bool:
  Nat.is_le(List.length(&2,U32,bytes),U32.to_nat(U32.sub(4294967295,used)))

def finish_checked(bytes: List<&2,U32>,hash: Domain.HashContext,room: Bool) ->
  Result<&2,&2,String,String>:
  match room:
    case False{}:
      Fail{"Context checksum serialized byte budget exceeds U32_MAX"}
    case True{}:
      Done{Domain.hash_finish(Domain.hash_bytes(bytes,hash))}

def finish_bytes(+bytes: List<&2,U32>,+hash: Domain.HashContext) -> Result<&2,&2,String,String>:
  Domain.HashContext{_,_,_,used} = hash
  finish_checked(bytes,hash,hash_room(used,bytes))

def prefix_text(+binding: Binding) -> String:
  Binding{parser,_,_,_,_} = binding
  version_v2(parser) ++ "|" ++ encoded(binding_cells(binding))

def suffix_text(raw: Raw,context: Context) -> String:
  encoded(List.append(&2,Sql.Cell,raw_cells(raw),context_cells(context)))

# Independent one-shot scalar oracle; does not call the cached implementation.
def digest_valid(binding: Binding,raw: Raw,context: Context,valid: Bool) ->
  Result<&2,&2,String,String>:
  match valid:
    case False{}:
      Fail{"Invalid portable context identity, raw digest or Unicode scalar"}
    case True{}:
      finish_bytes(Domain.encode(prefix_text(binding) ++ suffix_text(raw,context)),
        Domain.HashContext{Domain.hash_initial(),[],0,0})

def digest_v2(+binding: Binding,+raw: Raw,+context: Context) -> Result<&2,&2,String,String>:
  digest_valid(binding,raw,context,binding_valid(binding) && raw_valid(raw) && context_valid(context))

def prefix_partition(binding: Binding,+bytes: List<&2,U32>,+complete: Nat) -> Prefix:
  Prefix{binding,Domain.hash_bytes(List.take(&2,U32,bytes,complete),
    Domain.HashContext{Domain.hash_initial(),[],0,0}),List.drop(&2,U32,bytes,complete)}

def prefix_budget(binding: Binding,+bytes: List<&2,U32>,room: Bool) -> Result<&2,&2,String,Prefix>:
  match room:
    case False{}:
      Fail{"Context checksum serialized prefix budget exceeds U32_MAX"}
    case True{}:
      +size = List.length(&2,U32,bytes)
      Done{prefix_partition(binding,bytes,Nat.sub(size,Nat.mod(size,64n)))}

def prefix_valid(+binding: Binding,valid: Bool) -> Result<&2,&2,String,Prefix>:
  match valid:
    case False{}:
      Fail{"Invalid portable context binding identity or Unicode scalar"}
    case True{}:
      +bytes = Domain.encode(prefix_text(binding))
      prefix_budget(binding,bytes,hash_room(0,bytes))

def prefix(+binding: Binding) -> Result<&2,&2,String,Prefix>:
  prefix_valid(binding,binding_valid(binding))

def cached_feed(prefix: Prefix,raw: Raw,context: Context) -> Result<&2,&2,String,String>:
  Prefix{_,hash,remainder} = prefix
  finish_bytes(List.append(&2,U32,remainder,Domain.encode(suffix_text(raw,context))),hash)

def cached_valid(prefix: Prefix,raw: Raw,context: Context,valid: Bool) -> Result<&2,&2,String,String>:
  match valid:
    case False{}:
      Fail{"Invalid portable context raw identity, digest or Unicode scalar"}
    case True{}:
      cached_feed(prefix,raw,context)

def digest_cached(prefix: Prefix,+raw: Raw,+context: Context) -> Result<&2,&2,String,String>:
  cached_valid(prefix,raw,context,raw_valid(raw) && context_valid(context))

def matches(result: Result<&2,&2,String,String>,stored: String) -> Bool:
  match result:
    case Fail{_}:
      False{}
    case Done{digest}:
      String.eq(digest,stored)

def verify_v2(+prefix: Prefix,raw: Raw,context: Context,tag: String,stored: String) -> Bool:
  Prefix{Binding{parser,_,_,_,_},_,_} = prefix
  String.eq(tag,version_v2(parser)) && matches(digest_cached(prefix,raw,context),stored)
