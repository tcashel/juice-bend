import Base

# Query words are literal AND terms; double quotes group a phrase. All FTS
# syntax is generated here, never interpreted from untrusted query punctuation.
# after is an inclusive ISO calendar date, compared to captured timestamps.
type Filters is Data:
  Filters{query: String, provider: String, repo: String, role: String, after: String}

type Token is Data:
  Token{raw: String, text: String}

type Scanner is Data:
  Scanner{raw: String, text: String, quoted: Bool, escaped: Bool, tokens: List<&2, Token>}

def flush(raw: String, text: String, tokens: List<&2, Token>) -> List<&2, Token>:
  match raw:
    case "":
      tokens
    case _:
      Token{String.reverse(raw), String.reverse(text)} <> tokens

def outside(c: Char, raw: String, text: String, tokens: List<&2, Token>, space: Bool) -> Scanner:
  match space:
    case True{}:
      Scanner{"", "", False{}, False{}, flush(raw, text, tokens)}
    case False{}:
      +character = c
      Scanner{SCon{character, raw}, SCon{character, text}, False{}, False{}, tokens}

def scan_character(+state: Scanner, +c: Char) -> Scanner:
  match state:
    case Scanner{raw, text, True{}, True{}, tokens}:
      Scanner{SCon{c, raw}, SCon{c, text}, True{}, False{}, tokens}
    case Scanner{raw, text, True{}, False{}, tokens}:
      +code = Char.to_u32(c)
      Bool.pick(Scanner, U32.is_eq(code, 34),
        Scanner{SCon{c, raw}, text, False{}, False{}, tokens},
        Bool.pick(Scanner, U32.is_eq(code, 92),
          Scanner{SCon{c, raw}, text, True{}, True{}, tokens},
          Scanner{SCon{c, raw}, SCon{c, text}, True{}, False{}, tokens}))
    case Scanner{raw, text, False{}, escaped, tokens}:
      Bool.pick(Scanner, Char.is_eq(c, '"'),
        Scanner{SCon{c, raw}, text, True{}, False{}, tokens},
        outside(c, raw, text, tokens, Char.is_space(c)))

def scan_safe(state: Scanner, c: Char, valid: Bool) -> Result<&2, &2, String, Scanner>:
  match valid:
    case True{}:
      Done{scan_character(state, c)}
    case False{}:
      Fail{"Search query contains an unsupported control character."}

def scan_step(state: Scanner, +c: Char) -> Result<&2, &2, String, Scanner>:
  +code = Char.to_u32(c)
  scan_safe(state, c, Bool.and(Bool.or(U32.is_ge(code, 32), Char.is_space(c)),
    Bool.and(U32.is_le(code, 1114111), Bool.not(Bool.and(U32.is_ge(code, 55296), U32.is_le(code, 57343))))))

def scan_end(state: Scanner) -> Result<&2, &2, String, List<&2, Token>>:
  match state:
    case Scanner{raw, text, False{}, False{}, tokens}:
      Done{List.reverse(&2, Token, flush(raw, text, tokens))}
    case _:
      Fail{"Search has an unclosed quoted phrase or escape."}

def scan(raw: String, state: Scanner) -> Result<&2, &2, String, List<&2, Token>>:
  match raw:
    case SNil{}:
      scan_end(state)
    case SCon{c, rest}:
      do Result<&2, &2, String, List<&2, Token>>:
        next : Scanner <- scan_step(state, c)
        scan(rest, next)

def tokens(raw: String) -> Result<&2, &2, String, List<&2, Token>>:
  scan(raw, Scanner{"", "", False{}, False{}, []})

def quote_contents(raw: String) -> String:
  match raw:
    case SNil{}:
      ""
    case SCon{'"', rest}:
      "\"\"" ++ quote_contents(rest)
    case SCon{c, rest}:
      SCon{c, quote_contents(rest)}

def quote(raw: String) -> String:
  "\"" ++ quote_contents(raw) ++ "\""

def append_term(text: String, rest: List<&2, String>, empty: Bool) -> List<&2, String>:
  match empty:
    case True{}:
      rest
    case False{}:
      quote(text) <> rest

def terms(items: List<&2, Token>) -> List<&2, String>:
  match items:
    case Nil{}:
      []
    case Con{Token{raw, +text}, rest}:
      append_term(text, terms(rest), String.is_empty(String.trim(text)))

def fts_result(raw: String, result: Result<&2, &2, String, List<&2, Token>>) -> String:
  match result:
    case Done{items}:
      String.join(terms(items), " AND ")
    case Fail{error}:
      quote(raw)

# Normal callers validate through parse first. This total fallback remains
# literal if an internal caller supplies an unfinished phrase.
def fts(+raw: String) -> String:
  fts_result(raw, tokens(raw))

def month_days(month: U32, +year: U32) -> U32:
  match month:
    case 2:
      Bool.pick(U32, Bool.or(U32.is_eq(U32.mod(year, 400), 0),
        Bool.and(U32.is_eq(U32.mod(year, 4), 0), Bool.not(U32.is_eq(U32.mod(year, 100), 0)))), 29, 28)
    case 4:
      30
    case 6:
      30
    case 9:
      30
    case 11:
      30
    case _:
      31

def digit(c: Char) -> U32:
  U32.sub(Char.to_u32(c), 48)

def date_components(+year: U32, +month: U32, +day: U32, digits: Bool) -> Bool:
  Bool.and(digits, Bool.and(U32.is_ge(year, 1),
    Bool.and(U32.is_ge(month, 1), Bool.and(U32.is_le(month, 12),
      Bool.and(U32.is_ge(day, 1), U32.is_le(day, month_days(month, year)))))))

def date_chars(chars: List<&2, Char>) -> Bool:
  match chars:
    case [a, b, c, d, '-', e, f, '-', g, h]:
      +aa = a
      +bb = b
      +cc = c
      +dd = d
      +ee = e
      +ff = f
      +gg = g
      +hh = h
      date_components(U32.add(U32.add(U32.mul(digit(aa), 1000), U32.mul(digit(bb), 100)), U32.add(U32.mul(digit(cc), 10), digit(dd))),
        U32.add(U32.mul(digit(ee), 10), digit(ff)), U32.add(U32.mul(digit(gg), 10), digit(hh)),
        Bool.and(Char.is_digit(aa), Bool.and(Char.is_digit(bb), Bool.and(Char.is_digit(cc), Bool.and(Char.is_digit(dd),
          Bool.and(Char.is_digit(ee), Bool.and(Char.is_digit(ff), Bool.and(Char.is_digit(gg), Char.is_digit(hh)))))))))
    case _:
      False{}

def date_valid(value: String) -> Bool:
  date_chars(String.to_list(value))

def provider_valid(value: String) -> Bool:
  match value:
    case "claude":
      True{}
    case "codex":
      True{}
    case _:
      False{}

def role_valid(value: String) -> Bool:
  match value:
    case "user":
      True{}
    case "assistant":
      True{}
    case "tool":
      True{}
    case "thinking":
      True{}
    case "system":
      True{}
    case "metadata":
      True{}
    case "attachment":
      True{}
    case "error":
      True{}
    case "unsupported":
      True{}
    case _:
      False{}

def prefix(+raw: String) -> U32:
  Bool.pick(U32, String.starts_with(raw, "provider:"), 1,
    Bool.pick(U32, String.starts_with(raw, "repo:"), 2,
      Bool.pick(U32, String.starts_with(raw, "role:"), 3,
        Bool.pick(U32, String.starts_with(raw, "after:"), 4, 0))))

def length_ok(value: String, limit: Nat) -> Bool:
  match value limit:
    case SNil{} _:
      True{}
    case SCon{c, rest} 0n:
      False{}
    case SCon{c, rest} 1n+left:
      length_ok(rest, left)

def validate(ok: Bool, message: String) -> Result<&2, &2, String, Unit>:
  match ok:
    case True{}:
      Done{Unit{}}
    case False{}:
      Fail{message}

def put_query(filters: Filters, raw: String, empty: Bool) -> Filters:
  match filters empty:
    case Filters{query, provider, repo, role, after} True{}:
      Filters{query, provider, repo, role, after}
    case Filters{"", provider, repo, role, after} False{}:
      Filters{String.reverse(raw), provider, repo, role, after}
    case Filters{query, provider, repo, role, after} False{}:
      Filters{String.reverse(raw) ++ " " ++ query, provider, repo, role, after}

def put_provider(filters: Filters, +value: String) -> Result<&2, &2, String, Filters>:
  match filters:
    case Filters{query, provider, repo, role, after}:
      do Result<&2, &2, String, Filters>:
        validate(String.is_empty(provider), "Use provider: only once.")
        validate(provider_valid(value), "Provider must be claude or codex.")
        return Filters{query, value, repo, role, after}

def put_repo(filters: Filters, +value: String) -> Result<&2, &2, String, Filters>:
  match filters:
    case Filters{query, provider, repo, role, after}:
      do Result<&2, &2, String, Filters>:
        validate(String.is_empty(repo), "Use repo: only once.")
        validate(Bool.not(String.is_empty(value)), "Repository filter cannot be empty.")
        return Filters{query, provider, value, role, after}

def put_role(filters: Filters, +value: String) -> Result<&2, &2, String, Filters>:
  match filters:
    case Filters{query, provider, repo, role, after}:
      do Result<&2, &2, String, Filters>:
        validate(String.is_empty(role), "Use role: only once.")
        validate(role_valid(value), "Unknown role filter.")
        return Filters{query, provider, repo, value, after}

def put_after(filters: Filters, +value: String) -> Result<&2, &2, String, Filters>:
  match filters:
    case Filters{query, provider, repo, role, after}:
      do Result<&2, &2, String, Filters>:
        validate(String.is_empty(after), "Use after: only once.")
        validate(date_valid(value), "Date filter requires a valid YYYY-MM-DD calendar date.")
        return Filters{query, provider, repo, role, value}

def apply(kind: U32, filters: Filters, raw: String, +text: String) -> Result<&2, &2, String, Filters>:
  match kind:
    case 1:
      put_provider(filters, String.to_lower(String.drop(text, 9n)))
    case 2:
      put_repo(filters, String.drop(text, 5n))
    case 3:
      put_role(filters, String.to_lower(String.drop(text, 5n)))
    case 4:
      put_after(filters, String.drop(text, 6n))
    case _:
      Done{put_query(filters, raw, String.is_empty(String.trim(text)))}

# During parsing query holds reversed characters, so adding many terms never
# recopies the whole prefix. Only the final result reverses this accumulator.
def finish(filters: Filters) -> Filters:
  match filters:
    case Filters{query, provider, repo, role, after}:
      Filters{String.reverse(query), provider, repo, role, after}

def parse_tokens(items: List<&2, Token>, filters: Filters) -> Result<&2, &2, String, Filters>:
  match items:
    case Nil{}:
      Done{finish(filters)}
    case Con{Token{+raw, text}, rest}:
      do Result<&2, &2, String, Filters>:
        next : Filters <- apply(prefix(raw), filters, raw, text)
        parse_tokens(rest, next)

def parse_bound(+raw: String, limit: Nat, message: String) -> Result<&2, &2, String, Filters>:
  do Result<&2, &2, String, Filters>:
    validate(length_ok(raw, limit), message)
    items : List<&2, Token> <- tokens(raw)
    parse_tokens(items, Filters{"", "", "", "", ""})

def parse(raw: String) -> Result<&2, &2, String, Filters>:
  parse_bound(raw, 4096n, "Search query exceeds 4096 characters.")

def parse_ui(raw: String) -> Result<&2, &2, String, Filters>:
  parse_bound(raw, 512n, "Search query exceeds 512 characters.")

def query(filters: Filters) -> String:
  match filters:
    case Filters{query, provider, repo, role, after}:
      query

def provider(filters: Filters) -> String:
  match filters:
    case Filters{query, provider, repo, role, after}:
      provider

def repo(filters: Filters) -> String:
  match filters:
    case Filters{query, provider, repo, role, after}:
      repo

def role(filters: Filters) -> String:
  match filters:
    case Filters{query, provider, repo, role, after}:
      role

def after(filters: Filters) -> String:
  match filters:
    case Filters{query, provider, repo, role, after}:
      after
