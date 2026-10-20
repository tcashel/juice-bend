import Base
import ./domain.bend as Domain

# Candidates must refer to committed captured records. `key` carries the complete
# provider/locator/generation/snapshot/record/event identity, never a provider ID.
# Times are canonical decimal ordering ranks, not floating point or Unix time.
# Captured provider times use normalized UTC calendar ranks, or 0 when unknown.
type Candidate is Data:
  Candidate{repo: String, key: String, time: String, lines: List<&2, String>,
    evidence_eligible: Bool}

type Attribution is Data:
  Exact{key: String}
  Content{key: String, matched: Nat, eligible: Nat}
  Probable{key: String, basis: String}
  NotIndexed{reason: String}
  Ambiguous{reason: String}
  Uncommitted{}

type Score is Data:
  Score{matched: Nat, eligible: Nat}

type Match is Data:
  Match{candidate: Candidate, matched: Nat, eligible: Nat}

type Region is Data:
  Region{sha: String, original: U32, current: U32, author_time: String, text: String}

type Header is Data:
  Header{sha: String, original: U32, current: U32, author_time: String}

# ASCII-only eligibility is conservative for this first content matcher.
# Non-ASCII letters are preserved, but cannot by themselves establish attribution.
type ParseState is Data:
  Parsing{header: Maybe<&2, Header>, remaining: U32, regions: List<&2, Region>}
  ParseFailed{error: String}

def has_letter_or_digit(s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{+h, t}:
      Bool.or(Bool.or(Char.is_alpha(h), Char.is_digit(h)), has_letter_or_digit(t))

def normalized_lines(xs: List<&2, String>) -> List<&2, String>:
  match xs:
    case Nil{}:
      []
    case h <> t:
      String.trim_end(h) <> normalized_lines(t)

def member(+needle: String, xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      False{}
    case h <> t:
      Bool.or(String.eq(needle, h), member(needle, t))

# Preserve repeated hunk occurrences: only the edit side uses membership.
def score_counts(pair: Score) -> Maybe<&2, Score>:
  Score{+matched, +eligible} = pair
  Bool.pick(Maybe<&2, Score>, Domain.eligible_match(matched, eligible),
    Some{Score{matched, eligible}}, None{})

def digits(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{h, t}:
      Bool.and(Char.is_digit(h), digits(t))

def decimal_compare_length(a: String, b: String, order: Cmp) -> Cmp:
  match order:
    case LT{}:
      LT{}
    case GT{}:
      GT{}
    case EQ{}:
      String.order(a, b)

def content_result(result: Maybe<&2, Match>) -> Attribution:
  match result:
    case None{}:
      NotIndexed{"no eligible captured content match"}
    case Some{Match{Candidate{_, key, _, _, _}, matched, eligible}}:
      Content{key, matched, eligible}

# Repeated references to the same complete key are not ambiguity. Other
# in-scope identities are, regardless of their provider session ID spelling.
def probable_result(result: Attribution, basis: String) -> Attribution:
  match result:
    case Exact{k}:
      Probable{k, basis}
    case Content{k, m, e}:
      Content{k, m, e}
    case Probable{k, b}:
      Probable{k, b}
    case NotIndexed{r}:
      NotIndexed{r}
    case Ambiguous{r}:
      Ambiguous{r}
    case Uncommitted{}:
      Uncommitted{}

def attribution_name(a: Attribution) -> String:
  match a:
    case Exact{_}:
      "exact"
    case Content{_, _, _}:
      "content"
    case Probable{_, _}:
      "probable"
    case NotIndexed{_}:
      "not_indexed"
    case Ambiguous{_}:
      "ambiguous"
    case Uncommitted{}:
      "uncommitted"

def uncommitted(sha: String) -> Bool:
  String.eq(sha, "0000000000000000000000000000000000000000")

def hex_chars(s: String) -> Bool:
  match s:
    case SNil{}:
      True{}
    case SCon{+h, t}:
      +n = Char.to_u32(h)
      Bool.and(Bool.or(Char.is_digit(h), Bool.and(U32.is_ge(n, 97), U32.is_le(n, 102))),
        hex_chars(t))

def parse_header_values(sha: String, original: Maybe<&2, U32>, current: Maybe<&2, U32>) -> Maybe<&2, Header>:
  match original current:
    case Some{+a} Some{+b}:
      Bool.pick(Maybe<&2, Header>, Bool.and(U32.is_gt(a, 0), U32.is_gt(b, 0)),
        Some{Header{sha, a, b, ""}}, None{})
    case _ _:
      None{}

def safe_component(+s: String) -> Bool:
  Bool.and(Bool.not(String.is_empty(s)),
    Bool.and(Bool.not(String.eq(s, ".")), Bool.not(String.eq(s, ".."))))

def safe_repo(+repo: String) -> Bool:
  Bool.and(String.starts_with(repo, "/"),
    Bool.and(Bool.not(String.contains(repo, "\0")), Nat.is_le(String.length(repo), 4096n)))

# No caller-supplied executable, Git command, revision, option, shell or script.
# The configured repo is explicit; path is relative, bounded and traversal-free.
def unique_result(evidence: Domain.IdentityEvidence) -> Attribution:
  match evidence:
    case Domain.MissingIdentity{}:
      NotIndexed{"no eligible captured identity in this repository"}
    case Domain.UniqueIdentity{key}:
      Exact{key}
    case Domain.AmbiguousIdentity{}:
      Ambiguous{"multiple eligible captured identities in this repository"}

def parse_u32_digit(+value: U32, +digit: U32, valid: Bool) -> Maybe<&2, U32>:
  match valid:
    case False{}:
      None{}
    case True{}:
      Bool.pick(Maybe<&2, U32>, Bool.or(U32.is_gt(value, 429496729),
        Bool.and(U32.is_eq(value, 429496729), U32.is_gt(digit, 5))),
        None{}, Some{U32.add(U32.mul(value, 10), digit)})

def porcelain_content(full: Bool, h: Header, line: String, remaining: U32,
  acc: List<&2, Region>) -> ParseState:
  match full:
    case True{}:
      ParseFailed{"Git blame region limit exceeded"}
    case False{}:
      Header{sha, a, b, time} = h
      Parsing{None{}, U32.sub(remaining, 1),
        Region{sha, a, b, time, String.drop(line, 1n)} <> acc}

def porcelain_time(valid: Bool, h: Header, remaining: U32,
  acc: List<&2, Region>, value: String) -> ParseState:
  match valid:
    case False{}:
      ParseFailed{"invalid Git author timestamp"}
    case True{}:
      Header{sha, a, b, _} = h
      Parsing{Some{Header{sha, a, b, value}}, remaining, acc}

def porcelain_finish(state: ParseState) -> Result<&2, &2, String, List<&2, Region>>:
  match state:
    case ParseFailed{e}:
      Fail{e}
    case Parsing{Some{_}, _, _}:
      Fail{"incomplete Git blame record"}
    case Parsing{None{}, _, acc}:
      Done{List.reverse(&2, Region, acc)}

def counts_step(+line: String, edit: List<&2, String>, prior: Score) -> Score:
  Score{matched, eligible} = prior
  +included = has_letter_or_digit(line)
  Score{Nat.add(Bool.pick(Nat, Bool.and(included, member(line, edit)), 1n, 0n), matched),
    Nat.add(Bool.pick(Nat, included, 1n, 0n), eligible)}

def decimal_valid(+s: String) -> Bool:
  match s:
    case SNil{}:
      False{}
    case SCon{+h, +t}:
      Bool.and(digits(SCon{h, t}),
        Bool.or(Bool.not(Char.is_eq(h, '0')), String.is_empty(t)))

def decimal_compare(+a: String, +b: String) -> Cmp:
  decimal_compare_length(a, b, Nat.cmp(String.length(a), String.length(b)))

def valid_sha(+s: String) -> Bool:
  Bool.and(Nat.is_eq(String.length(s), 40n), hex_chars(s))

def safe_components(xs: List<&2, String>) -> Bool:
  match xs:
    case Nil{}:
      True{}
    case h <> t:
      Bool.and(safe_component(h), safe_components(t))

def unique_go(xs: List<&2, Candidate>, +repo: String) -> Domain.IdentityEvidence:
  match xs:
    case Nil{}:
      Domain.MissingIdentity{}
    case Candidate{scope, +key, _, _, eligible} <> rest:
      Domain.identity_insert(key, Bool.and(Domain.scope_guard(eligible,
        String.eq(repo, scope)), Bool.not(String.is_empty(key))), unique_go(rest, repo))

def parse_u32_step(state: Maybe<&2, U32>, +h: Char) -> Maybe<&2, U32>:
  match state:
    case None{}:
      None{}
    case Some{value}:
      parse_u32_digit(value, U32.sub(Char.to_u32(h), 48), Char.is_digit(h))

def exact(repo: String, positively_linked: List<&2, Candidate>) -> Attribution:
  unique_result(unique_go(positively_linked, repo))

def counts(hunk: List<&2, String>, +edit: List<&2, String>) -> Score:
  match hunk:
    case Nil{}:
      Score{0n, 0n}
    case h <> t:
      counts_step(String.trim_end(h), edit, counts(t, edit))

def safe_path(+path: String) -> Bool:
  Bool.and(Bool.not(String.contains(path, "\0")),
    Bool.and(Bool.not(String.contains(path, "\n")),
      Bool.and(Bool.not(String.contains(path, "\r")),
        Bool.and(Nat.is_le(String.length(path), 4096n), safe_components(String.split(path, '/'))))))

def parse_u32_go(s: String, state: Maybe<&2, U32>) -> Maybe<&2, U32>:
  match s:
    case SNil{}:
      state
    case SCon{h, t}:
      parse_u32_go(t, parse_u32_step(state, h))

def porcelain_metadata(author_time: Bool, line: String, h: Header, remaining: U32,
  acc: List<&2, Region>) -> ParseState:
  match author_time:
    case False{}:
      Parsing{Some{h}, remaining, acc}
    case True{}:
      +value = String.drop(line, 12n)
      porcelain_time(decimal_valid(value), h, remaining, acc, value)

def parse_u32_empty(s: String, empty: Bool) -> Maybe<&2, U32>:
  match empty:
    case True{}:
      None{}
    case False{}:
      parse_u32_go(s, Some{0})

def probable(repo: String, candidates: List<&2, Candidate>, basis: String) -> Attribution:
  probable_result(exact(repo, candidates), basis)

def score(hunk: List<&2, String>, edit: List<&2, String>) -> Maybe<&2, Score>:
  score_counts(counts(hunk, normalized_lines(edit)))

def better_score(ca: Candidate, cb: Candidate, order: Cmp) -> Bool:
  Candidate{_, ka, ta, _, _} = ca
  Candidate{_, kb, tb, _, _} = cb
  Domain.prefer_candidate(order, decimal_compare(ta, tb), String.order(ka, kb))

def porcelain_header(parsed: Maybe<&2, Header>, header: Maybe<&2, Header>,
  +line: String, remaining: U32, acc: List<&2, Region>) -> ParseState:
  match parsed:
    case Some{h}:
      match header:
        case None{}:
          Parsing{Some{h}, remaining, acc}
        case Some{_}:
          ParseFailed{"Git blame header replaced before its content"}
    case None{}:
      match header:
        case None{}:
          Bool.pick(ParseState, String.is_empty(line), Parsing{None{}, remaining, acc},
            ParseFailed{"unexpected Git blame output"})
        case Some{h}:
          porcelain_metadata(String.starts_with(line, "author-time "), line, h, remaining, acc)

def parse_u32(+s: String) -> Maybe<&2, U32>:
  parse_u32_empty(s, String.is_empty(s))

def better(a: Match, b: Match) -> Bool:
  Match{ca, ma, ea} = a
  Match{cb, mb, eb} = b
  better_score(ca, cb, Nat.cmp(Nat.mul(ma, eb), Nat.mul(mb, ea)))

def parse_header_parts(sha: String, original: String, current: String) -> Maybe<&2, Header>:
  parse_header_values(sha, parse_u32(original), parse_u32(current))

def choose(candidate: Match, prior: Maybe<&2, Match>) -> Maybe<&2, Match>:
  match prior:
    case None{}:
      Some{candidate}
    case Some{+old}:
      +new = candidate
      Bool.pick(Maybe<&2, Match>, better(new, old), Some{new}, Some{old})

def parse_header_valid(sha: String, original: String, current: String, valid: Bool) -> Maybe<&2, Header>:
  match valid:
    case True{}:
      parse_header_parts(sha, original, current)
    case False{}:
      None{}

def best_score(candidate: Candidate, prior: Maybe<&2, Match>, result: Maybe<&2, Score>) -> Maybe<&2, Match>:
  match result:
    case None{}:
      prior
    case Some{Score{matched, count}}:
      choose(Match{candidate, matched, count}, prior)

def parse_header_words(words: List<&2, String>) -> Maybe<&2, Header>:
  match words:
    case +sha <> original <> current <> rest:
      parse_header_valid(sha, original, current,
        Bool.and(valid_sha(sha), Nat.is_le(List.length(&2, String, rest), 1n)))
    case _:
      None{}

def best_valid(valid: Bool, +candidate: Candidate, hunk: List<&2, String>, prior: Maybe<&2, Match>) -> Maybe<&2, Match>:
  match valid:
    case False{}:
      prior
    case True{}:
      Candidate{_, _, _, lines, _} = candidate
      best_score(candidate, prior, score(hunk, lines))

def parse_header(line: String) -> Maybe<&2, Header>:
  parse_header_words(String.split(line, ' '))

def best_go(xs: List<&2, Candidate>, +repo: String, +hunk: List<&2, String>) -> Maybe<&2, Match>:
  match xs:
    case Nil{}:
      None{}
    case +candidate <> rest:
      Candidate{scope, +key, +time, _, eligible} = candidate
      best_valid(Bool.and(Domain.scope_guard(eligible, String.eq(repo, scope)),
        Bool.and(decimal_valid(time), Bool.not(String.is_empty(key)))),
        candidate, hunk, best_go(rest, repo, hunk))

def content(repo: String, hunk: List<&2, String>, xs: List<&2, Candidate>) -> Attribution:
  content_result(best_go(xs, repo, hunk))

def porcelain_line(content_line: Bool, header: Maybe<&2, Header>, +line: String,
  +remaining: U32, acc: List<&2, Region>) -> ParseState:
  match content_line:
    case True{}:
      match header:
        case None{}:
          ParseFailed{"Git blame content without a validated header"}
        case Some{h}:
          porcelain_content(U32.is_eq(remaining, 0), h, line, remaining, acc)
    case False{}:
      porcelain_header(parse_header(line), header, line, remaining, acc)

def porcelain_step(state: ParseState, +line: String) -> ParseState:
  match state:
    case ParseFailed{e}:
      ParseFailed{e}
    case Parsing{h, remaining, acc}:
      porcelain_line(String.starts_with(line, "\t"), h, line, remaining, acc)

def porcelain_go(lines: List<&2, String>, state: ParseState) -> Result<&2, &2, String, List<&2, Region>>:
  match lines:
    case Nil{}:
      porcelain_finish(state)
    case line <> rest:
      porcelain_go(rest, porcelain_step(state, line))

def porcelain_limit(text: String, max_regions: U32, valid: Bool) -> Result<&2, &2, String, List<&2, Region>>:
  match valid:
    case True{}:
      porcelain_go(String.lines(text), Parsing{None{}, max_regions, []})
    case False{}:
      Fail{"Git blame limit must be 1 through 500"}

def porcelain(text: String, +max_regions: U32) -> Result<&2, &2, String, List<&2, Region>>:
  porcelain_limit(text, max_regions, Bool.and(U32.is_gt(max_regions, 0), U32.is_le(max_regions, 500)))

def git_exit(code: U32, out: String, limit: U32, success: Bool) -> Result<&2, &2, String, List<&2, Region>>:
  match success:
    case True{}:
      porcelain(out, limit)
    case False{}:
      Fail{"Git blame exited: " ++ U32.show(code)}
def git_result(result: Result<&1, &1, U32 & String, U32 & (String & String)>,
  limit: U32) -> Result<&2, &2, String, List<&2, Region>>:
  match result:
    case Fail{(code, _)}:
      Fail{"Git process failed: " ++ U32.show(code)}
    case Done{(+code, (out, _))}:
      git_exit(code, out, limit, U32.is_eq(code, 0))

def git_blame_valid(repo: String, path: String, +start: U32, +end: U32, valid: Bool) ->
  IO(Result<&2, &2, String, List<&2, Region>>):
  match valid:
    case False{}:
      IO.pure(Result<&2, &2, String, List<&2, Region>>,
        Fail{"invalid repository, relative path or bounded line range"})
    case True{}:
      do IO<Result<&2, &2, String, List<&2, Region>>>:
        result : Result<&1, &1, U32 & String, U32 & (String & String)> <-
          Process.run("/usr/bin/git",
            ["--no-pager", "--no-optional-locks",
             "-c", "core.hooksPath=/dev/null", "-c", "core.fsmonitor=false",
             "-c", "diff.external=", "-c", "core.attributesFile=/dev/null",
             "-c", "color.ui=false", "-C", repo,
             "blame", "--line-porcelain", "--no-ext-diff", "--no-textconv",
             "-L", U32.show(start) ++ "," ++ U32.show(end), "--", path],
            "", 1048576, 3000)
        return git_result(result, U32.add(U32.sub(end, start), 1))

def git_blame(+repo: String, +path: String, +start: U32, +end: U32) ->
  IO(Result<&2, &2, String, List<&2, Region>>):
  git_blame_valid(repo, path, start, end, Bool.and(Bool.and(safe_repo(repo), safe_path(path)),
    Bool.and(U32.is_gt(start, 0), Bool.and(U32.is_ge(end, start),
      U32.is_lt(U32.sub(end, start), 500)))))
