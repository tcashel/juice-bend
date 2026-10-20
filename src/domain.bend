import Base

# Pure byte and evidence operations shared by capture, parsing and provenance.
# Every byte supplied to digest/encode is an integer in [0,255]. The raw FFI
# validates this boundary. decode independently checks every byte/scalar.

def bytes_equal(xs: List<&2, U32>, ys: List<&2, U32>) -> Bool:
  match xs:
    case Nil{}:
      List.is_empty(&2, U32, ys)
    case Con{x, xt}:
      match ys:
        case Nil{}:
          False{}
        case Con{y, yt}:
          Bool.and(U32.is_eq(x, y), bytes_equal(xt, yt))

def scalar(+x: U32) -> Bool:
  Bool.and(U32.is_le(x, 1114111),
    Bool.or(U32.is_lt(x, 55296), U32.is_gt(x, 57343)))

def encode_scalar(+cp: U32, tail: List<&2, U32>, mode: U32) -> List<&2, U32>:
  match mode:
    case 0:
      Con{cp, tail}
    case 1:
      Con{(192 + U32.div(cp, 64) : U32),
        Con{(128 + U32.mod(cp, 64) : U32), tail}}
    case 2:
      Con{(224 + U32.div(cp, 4096) : U32),
        Con{(128 + U32.mod(U32.div(cp, 64), 64) : U32),
          Con{(128 + U32.mod(cp, 64) : U32), tail}}}
    case _:
      Con{(240 + U32.div(cp, 262144) : U32),
        Con{(128 + U32.mod(U32.div(cp, 4096), 64) : U32),
          Con{(128 + U32.mod(U32.div(cp, 64), 64) : U32),
            Con{(128 + U32.mod(cp, 64) : U32), tail}}}}

def encode_width(+cp: U32) -> U32:
  (Bool.to_u32(U32.is_ge(cp, 128)) +
    Bool.to_u32(U32.is_ge(cp, 2048)) +
    Bool.to_u32(U32.is_ge(cp, 65536)) : U32)

# Caller must supply scalar-valued String (Json.parse/decode guarantee this).
def encode(s: String) -> List<&2, U32>:
  match s:
    case SNil{}:
      Nil{}
    case SCon{Chr{+cp}, rest}:
      encode_scalar(cp, encode(rest), encode_width(cp))

def scalar_string(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{Chr{+cp}, rest}:
      Bool.and(scalar(cp), scalar_string(rest))

def encode_checked_if(s: String, valid: Bool) -> Result<&2, &2, String, List<&2, U32>>:
  match valid:
    case False{}:
      Fail{"invalid Unicode scalar"}
    case True{}:
      Done{encode(s)}

def encode_checked(+s: String) -> Result<&2, &2, String, List<&2, U32>>:
  encode_checked_if(s, scalar_string(s))

type DecodeState is Data:
  DecodeState{remaining: U32, point: U32, minimum: U32, text: String}

def decode_done(state: DecodeState) -> Result<&2, &2, String, String>:
  match state:
    case DecodeState{0, _, _, text}:
      Done{String.reverse(text)}
    case _:
      Fail{"truncated UTF-8 sequence"}

def decode_emit_if(cp: U32, text: String, valid: Bool) ->
  Result<&2, &2, String, DecodeState>:
  match valid:
    case False{}:
      Fail{"invalid UTF-8 scalar or overlong sequence"}
    case True{}:
      Done{DecodeState{0, 0, 0, SCon{Chr{cp}, text}}}

def decode_continue_finish(remaining: U32, +cp: U32, minimum: U32, text: String) ->
  Result<&2, &2, String, DecodeState>:
  match remaining:
    case 1:
      decode_emit_if(cp, text, Bool.and(scalar(cp), U32.is_ge(cp, minimum)))
    case _:
      Done{DecodeState{(remaining - 1 : U32), cp, minimum, text}}

def decode_continue_if(remaining: U32, cp: U32, minimum: U32,
  text: String, byte: U32, valid: Bool) -> Result<&2, &2, String, DecodeState>:
  match valid:
    case False{}:
      Fail{"invalid UTF-8 continuation byte"}
    case True{}:
      decode_continue_finish(remaining, (cp * 64 + byte - 128 : U32), minimum, text)

def decode_lead_width(byte: U32, text: String, width: U32) ->
  Result<&2, &2, String, DecodeState>:
  match width:
    case 1:
      Done{DecodeState{1, (byte - 192 : U32), 128, text}}
    case 2:
      Done{DecodeState{2, (byte - 224 : U32), 2048, text}}
    case 3:
      Done{DecodeState{3, (byte - 240 : U32), 65536, text}}
    case _:
      Fail{"invalid UTF-8 leading byte"}

def decode_lead_non_ascii(+byte: U32, text: String, valid: Bool) ->
  Result<&2, &2, String, DecodeState>:
  match valid:
    case False{}:
      Fail{"invalid UTF-8 leading byte"}
    case True{}:
      decode_lead_width(byte, text,
        (1 + Bool.to_u32(U32.is_ge(byte, 224)) + Bool.to_u32(U32.is_ge(byte, 240)) : U32))

def decode_lead(+byte: U32, text: String, ascii: Bool) ->
  Result<&2, &2, String, DecodeState>:
  match ascii:
    case True{}:
      Done{DecodeState{0, 0, 0, SCon{Chr{byte}, text}}}
    case False{}:
      decode_lead_non_ascii(byte, text,
        Bool.and(U32.is_ge(byte, 194), U32.is_le(byte, 244)))

def decode_byte(state: DecodeState, +byte: U32) -> Result<&2, &2, String, DecodeState>:
  match state:
    case DecodeState{0, _, _, text}:
      decode_lead(byte, text, U32.is_lt(byte, 128))
    case DecodeState{remaining, cp, minimum, text}:
      decode_continue_if(remaining, cp, minimum, text, byte,
        Bool.and(U32.is_ge(byte, 128), U32.is_le(byte, 191)))

def decode_go(bytes: List<&2, U32>, state: Result<&2, &2, String, DecodeState>) ->
  Result<&2, &2, String, String>:
  match bytes:
    case Nil{}:
      match state:
        case Fail{error}:
          Fail{error}
        case Done{s}:
          decode_done(s)
    case Con{byte, rest}:
      match state:
        case Fail{error}:
          Fail{error}
        case Done{s}:
          decode_go(rest, decode_byte(s, byte))

def decode(bytes: List<&2, U32>) -> Result<&2, &2, String, String>:
  decode_go(bytes, Done{DecodeState{0, 0, 0, ""}})

def eligible_nonzero(+matched: Nat, eligible: Nat) -> Bool:
  match eligible:
    case 0n:
      False{}
    case 1n+rest:
      match rest:
        case 0n:
          Nat.is_eq(matched, 1n)
        case 1n+tail:
          Bool.and(Nat.is_ge(matched, 2n),
            Nat.is_ge(Nat.mul(5n, matched), Nat.mul(3n, 2n+tail)))

def eligible_valid(matched: Nat, eligible: Nat, valid: Bool) -> Bool:
  match valid:
    case False{}:
      False{}
    case True{}:
      eligible_nonzero(matched, eligible)

# Exact arithmetic: no U32 multiplication and no floating-point rounding.
def eligible_match(+matched: Nat, +eligible: Nat) -> Bool:
  eligible_valid(matched, eligible, Nat.is_le(matched, eligible))

# SHA-256, FIPS 180-4. The implementation uses wrapped U32 word arithmetic.
# Archive chunks are bounded before entering digest (at most 4 MiB); bit-length
# encoding nevertheless carries the high three bits into the high length word.
type HashState is Data:
  HashState{a: U32, b: U32, c: U32, d: U32, e: U32, f: U32, g: U32, h: U32}

def hash_initial() -> HashState:
  HashState{1779033703, 3144134277, 1013904242, 2773480762,
    1359893119, 2600822924, 528734635, 1541459225}

def rotate(+x: U32, +n: Nat) -> U32:
  U32.or(U32.shrn(x, n), U32.shln(x, Nat.sub(32n, n)))

def small0(+x: U32) -> U32:
  U32.xor(U32.xor(rotate(x, 7n), rotate(x, 18n)), U32.shrn(x, 3n))

def small1(+x: U32) -> U32:
  U32.xor(U32.xor(rotate(x, 17n), rotate(x, 19n)), U32.shrn(x, 10n))

def large0(+x: U32) -> U32:
  U32.xor(U32.xor(rotate(x, 2n), rotate(x, 13n)), rotate(x, 22n))

def large1(+x: U32) -> U32:
  U32.xor(U32.xor(rotate(x, 6n), rotate(x, 11n)), rotate(x, 25n))

def choice(+e: U32, f: U32, g: U32) -> U32:
  U32.xor(U32.and(e, f), U32.and(U32.not(e), g))

def majority(+a: U32, +b: U32, +c: U32) -> U32:
  U32.xor(U32.xor(U32.and(a, b), U32.and(a, c)), U32.and(b, c))

def hash_constants() -> List<&2, U32>:
  [1116352408,1899447441,3049323471,3921009573,961987163,1508970993,
   2453635748,2870763221,3624381080,310598401,607225278,1426881987,
   1925078388,2162078206,2614888103,3248222580,3835390401,4022224774,
   264347078,604807628,770255983,1249150122,1555081692,1996064986,
   2554220882,2821834349,2952996808,3210313671,3336571891,3584528711,
   113926993,338241895,666307205,773529912,1294757372,1396182291,
   1695183700,1986661051,2177026350,2456956037,2730485921,2820302411,
   3259730800,3345764771,3516065817,3600352804,4094571909,275423344,
   430227734,506948616,659060556,883997877,958139571,1322822218,
   1537002063,1747873779,1955562222,2024104815,2227730452,2361852424,
   2428436474,2756734187,3204031479,3329325298]

type HashSchedule is Data:
  HashSchedule{w0:U32,w1:U32,w2:U32,w3:U32,w4:U32,w5:U32,w6:U32,w7:U32,
    w8:U32,w9:U32,w10:U32,w11:U32,w12:U32,w13:U32,w14:U32,w15:U32}

def hash_round_finish(a: U32, b: U32, c: U32, d: U32, e: U32, f: U32,
  g: U32, +t1: U32, t2: U32) -> HashState:
  HashState{(t1 + t2 : U32), a, b, c, (d + t1 : U32), e, f, g}

def hash_round(state: HashState, k: U32, w: U32) -> HashState:
  match state:
    case HashState{+a, +b, +c, d, +e, +f, +g, h}:
      hash_round_finish(a, b, c, d, e, f, g,
        (h + large1(e) + choice(e, f, g) + k + w : U32),
        (large0(a) + majority(a, b, c) : U32))

def hash_rounds(constants: List<&2, U32>, words: HashSchedule,
  state: HashState) -> HashState:
  match constants:
    case Nil{}:
      state
    case Con{k, rest}:
      match words:
        case HashSchedule{+a,+b,c,d,e,f,g,h,i,+j,l,m,n,o,+p,q}:
          hash_rounds(rest, HashSchedule{b,c,d,e,f,g,h,i,j,l,m,n,o,p,q,
            (small1(p) + j + small0(b) + a : U32)}, hash_round(state, k, a))

def pack_words(bytes: List<&2, U32>, partial: U32, used: U32,
  acc: List<&2, U32>) -> List<&2, U32>:
  match bytes:
    case Nil{}:
      List.reverse(&2, U32, acc)
    case Con{byte, rest}:
      match used:
        case 3:
          pack_words(rest, 0, 0, Con{(partial * 256 + byte : U32), acc})
        case _:
          pack_words(rest, (partial * 256 + byte : U32), (used + 1 : U32), acc)

def hash_add(old: HashState, next: HashState) -> HashState:
  match old next:
    case HashState{a,b,c,d,e,f,g,h} HashState{i,j,k,l,m,n,o,p}:
      HashState{(a + i : U32), (b + j : U32), (c + k : U32), (d + l : U32),
        (e + m : U32), (f + n : U32), (g + o : U32), (h + p : U32)}

def hash_schedule(words: List<&2, U32>) -> HashSchedule:
  match words:
    case a <> b <> c <> d <> e <> f <> g <> h <> i <> j <> k <> l <> m <> n <> o <> p <> []:
      HashSchedule{a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p}
    case _:
      # Internal only: hash_feed submits exactly 64 bytes and pack_words
      # emits exactly 16 words. Runtime tests cover both padding block counts.
      HashSchedule{0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0}

def hash_block(bytes: List<&2, U32>, +state: HashState) -> HashState:
  hash_add(state, hash_rounds(hash_constants(),
    hash_schedule(pack_words(bytes, 0, 0, [])), state))

type HashContext is Data:
  HashContext{state: HashState, pending: List<&2, U32>, used: U32, size: U32}

def hash_feed(context: HashContext, byte: U32) -> HashContext:
  match context:
    case HashContext{state, pending, 63, size}:
      HashContext{hash_block(List.reverse(&2, U32, Con{byte, pending}), state),
        [], 0, (size + 1 : U32)}
    case HashContext{state, pending, used, size}:
      HashContext{state, Con{byte, pending}, (used + 1 : U32), (size + 1 : U32)}

def hash_bytes(bytes: List<&2, U32>, context: HashContext) -> HashContext:
  match bytes:
    case Nil{}:
      context
    case Con{byte, rest}:
      hash_bytes(rest, hash_feed(context, byte))

def word_bytes(+word: U32) -> List<&2, U32>:
  [U32.and(U32.shrn(word, 24n), 255), U32.and(U32.shrn(word, 16n), 255),
    U32.and(U32.shrn(word, 8n), 255), U32.and(word, 255)]

def hash_padding(+size: U32, +used: U32) -> List<&2, U32>:
  List.append(&2, U32,
    Con{128, List.replicate(U32, U32.to_nat(U32.mod((119 - used : U32), 64)), 0)},
    List.append(&2, U32, word_bytes(U32.shrn(size, 29n)),
      word_bytes(U32.shln(size, 3n))))

def hex_digit_if(n: U32, small: Bool) -> Char:
  match small:
    case True{}:
      Chr{(48 + n : U32)}
    case False{}:
      Chr{(87 + n : U32)}

def hex_digit(+n: U32) -> Char:
  hex_digit_if(n, U32.is_lt(n, 10))

def hex_word_go(fuel: Nat, +word: U32, acc: String) -> String:
  match fuel:
    case 0n:
      acc
    case 1n+rest:
      hex_word_go(rest, U32.shrn(word, 4n),
        SCon{hex_digit(U32.and(word, 15)), acc})

def hex_word(word: U32) -> String:
  hex_word_go(8n, word, "")

def hash_show(context: HashContext) -> String:
  match context:
    case HashContext{HashState{a,b,c,d,e,f,g,h}, _, _, _}:
      hex_word(a) ++ hex_word(b) ++ hex_word(c) ++ hex_word(d) ++
        hex_word(e) ++ hex_word(f) ++ hex_word(g) ++ hex_word(h)

def hash_finish(context: HashContext) -> String:
  match context:
    case HashContext{state, pending, +used, +size}:
      hash_show(hash_bytes(hash_padding(size, used),
        HashContext{state, pending, used, size}))

def digest(bytes: List<&2, U32>) -> String:
  hash_finish(hash_bytes(bytes, HashContext{hash_initial(), [], 0, 0}))

# Explicit selection is sticky: callers pass Some for every previously opened
# citation. Only a new, unpinned browse request is allowed to follow latest.
def select_snapshot(requested: Maybe<&2, String>, latest: String) -> String:
  match requested:
    case None{}:
      latest
    case Some{snapshot}:
      snapshot

type EvidenceKey is Data:
  EvidenceKey{provider: String, source: String, generation: String,
    snapshot: String, record: String, event: String}

def identity_guard(provider: Bool, source: Bool, generation: Bool,
  snapshot: Bool, record: Bool, event: Bool) -> Bool:
  Bool.and(provider, Bool.and(source, Bool.and(generation,
    Bool.and(snapshot, Bool.and(record, event)))))

def ref_equal(a: EvidenceKey, b: EvidenceKey) -> Bool:
  match a b:
    case EvidenceKey{p,s,g,n,r,e} EvidenceKey{pp,ss,gg,nn,rr,ee}:
      identity_guard(String.eq(p,pp), String.eq(s,ss), String.eq(g,gg),
        String.eq(n,nn), String.eq(r,rr), String.eq(e,ee))

# Bounded count uses exact Nat internally. The public U32 wrapper cannot
# truncate: count_nat is proved <= the U32 requested count.
def count_nat(start: Nat, count: Nat, extent: Nat) -> Nat:
  Nat.min(count, Nat.sub(extent, start))

def bounded_count(start: U32, count: U32, extent: U32) -> U32:
  U32.from_nat(count_nat(U32.to_nat(start), U32.to_nat(count), U32.to_nat(extent)))

def scope_guard(provider_allowed: Bool, repository_allowed: Bool) -> Bool:
  Bool.and(provider_allowed, repository_allowed)

def scope_allowed(provider: String, repository: String,
  +wanted_provider: String, +wanted_repository: String) -> Bool:
  scope_guard(
    Bool.or(String.is_empty(wanted_provider), String.eq(provider, wanted_provider)),
    Bool.or(String.is_empty(wanted_repository), String.eq(repository, wanted_repository)))

# Exact attribution's pure accumulator is shared by the resolver and proofs.
# Invalid/out-of-scope candidates are ignored. Multiple distinct eligible
# captured keys make ambiguity permanent; no later input can erase it.
type IdentityEvidence is Data:
  MissingIdentity{}
  UniqueIdentity{key: String}
  AmbiguousIdentity{}

def identity_same(old: String, same: Bool) -> IdentityEvidence:
  match same:
    case True{}:
      UniqueIdentity{old}
    case False{}:
      AmbiguousIdentity{}

def identity_insert(+key: String, eligible: Bool, prior: IdentityEvidence) ->
  IdentityEvidence:
  match eligible:
    case False{}:
      prior
    case True{}:
      match prior:
        case MissingIdentity{}:
          UniqueIdentity{key}
        case UniqueIdentity{+old}:
          identity_same(old, String.eq(key, old))
        case AmbiguousIdentity{}:
          AmbiguousIdentity{}

# Deterministic winner selection after exact-rational score comparison and time
# comparison. EQ falls through to the stable key comparator; identical keys
# retain the earlier candidate rather than inventing a new identity.
def tie_key(key_order: Cmp) -> Bool:
  Cmp.is_le(key_order)

def tie_time(time_order: Cmp, key_order: Cmp) -> Bool:
  match time_order:
    case GT{}:
      True{}
    case LT{}:
      False{}
    case EQ{}:
      tie_key(key_order)

def prefer_candidate(score_order: Cmp, time_order: Cmp, key_order: Cmp) -> Bool:
  match score_order:
    case GT{}:
      True{}
    case LT{}:
      False{}
    case EQ{}:
      tie_time(time_order, key_order)

# Base.U32.read wraps on overflow. Never use it for persisted offsets/lengths or
# CLI page boundaries. Accept canonical unsigned decimal only, no leading zero.
def parse_digit_if(acc: U32, code: U32, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case False{}:
      None{}
    case True{}:
      Some{(acc * 10 + code - 48 : U32)}

def parse_digit(+acc: U32, +code: U32) -> Maybe<&2, U32>:
  parse_digit_if(acc, code, Bool.and(
    Bool.and(U32.is_ge(code, 48), U32.is_le(code, 57)),
    Bool.or(U32.is_lt(acc, 429496729),
      Bool.and(U32.is_eq(acc, 429496729), U32.is_le(code, 53)))))

def parse_u32_tail(s: String, result: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      result
    case SCon{Chr{code}, tail}:
      match result:
        case None{}:
          None{}
        case Some{acc}:
          parse_u32_tail(tail, parse_digit(acc, code))

def parse_u32(s: String) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      None{}
    case SCon{'0', SNil{}}:
      Some{0}
    case SCon{'0', _}:
      None{}
    case SCon{Chr{code}, tail}:
      parse_u32_tail(tail, parse_digit(0, code))
