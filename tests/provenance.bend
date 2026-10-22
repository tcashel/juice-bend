import Base
import ../src/provenance.bend as P

def assert(ok: Bool, name: String) -> IO(Unit):
  match ok:
    case True{}:
      IO.print("PASS " ++ name)
    case False{}:
      IO.die(Unit, 1, "FAIL " ++ name)

def is_score(result: Maybe<&2, P.Score>, m: Nat, n: Nat) -> Bool:
  match result:
    case None{}:
      False{}
    case Some{P.Score{actual_m, actual_n}}:
      Bool.and(Nat.is_eq(actual_m, m), Nat.is_eq(actual_n, n))

def no_score(result: Maybe<&2, P.Score>) -> Bool:
  match result:
    case None{}:
      True{}
    case Some{_}:
      False{}

def content_key(result: P.Attribution, expected: String) -> Bool:
  match result:
    case P.Content{key, _, _}:
      String.eq(key, expected)
    case _:
      False{}

def exact_key(result: P.Attribution, expected: String) -> Bool:
  match result:
    case P.Exact{key}:
      String.eq(key, expected)
    case _:
      False{}

def number(result: Maybe<&2, U32>, expected: U32) -> Bool:
  match result:
    case Some{value}:
      U32.is_eq(value, expected)
    case None{}:
      False{}

def no_number(result: Maybe<&2, U32>) -> Bool:
  match result:
    case Some{_}:
      False{}
    case None{}:
      True{}

def parsed_region(result: Result<&2, &2, String, List<&2, P.Region>>) -> Bool:
  match result:
    case Fail{_}:
      False{}
    case Done{P.Region{sha, original, current, time, text} <> Nil{}}:
      Bool.and(String.eq(sha, "1234567890123456789012345678901234567890"),
        Bool.and(U32.is_eq(original, 7), Bool.and(U32.is_eq(current, 9),
          Bool.and(String.eq(time, "9007199254740993"), String.eq(text, "let café = \"🍋\"")))))
    case Done{_}:
      False{}

def parse_failed(result: Result<&2, &2, String, List<&2, P.Region>>) -> Bool:
  match result:
    case Fail{_}:
      True{}
    case Done{_}:
      False{}

def tests() -> IO(Unit):
  do IO<Unit>:
    assert(is_score(P.score(["first", "second", "third", "fourth", "fifth"],
      ["first", "second", "third"]), 3n, 5n), "exact sixty-percent threshold")
    assert(no_score(P.score(["first", "second", "third", "fourth"],
      ["first", "second"])), "below threshold refuses")
    assert(no_score(P.score(["first", "second"], ["first"])), "two-line hunk requires two hits")
    assert(is_score(P.score(["first"], ["first"]), 1n, 1n), "singleton exact")
    assert(no_score(P.score(["first"], ["other"])), "singleton nonmatch")
    assert(no_score(P.score(["}", "// ---", "   "], ["}", "// ---"])), "low entropy excluded")
    assert(is_score(P.score(["first", "first", "third"], ["first"]), 2n, 3n),
      "repeated hunk occurrences remain separate")
    assert(is_score(P.score(["  value \t\r"], ["  value"]), 1n, 1n),
      "trailing whitespace normalized")
    assert(no_score(P.score(["  value"], ["value"])), "indentation stays significant")
    assert(no_score(P.score(["中文"], ["中文"])), "non-ASCII-only attribution conservative")
    assert(content_key(P.content("/repo", ["first"],
      [P.Candidate{"/repo", "older", "9007199254740992", ["first"], True{}},
       P.Candidate{"/repo", "newer", "9007199254740993", ["first"], True{}}]), "newer"),
      "timestamp ordering exact beyond float precision")
    assert(content_key(P.content("/repo", ["first"],
      [P.Candidate{"/repo", "z", "100", ["first"], True{}},
       P.Candidate{"/repo", "a", "100", ["first"], True{}}]), "a"), "stable lexical tie")
    assert(content_key(P.content("/repo", ["first"],
      [P.Candidate{"/repo", "a", "100", ["first"], True{}},
       P.Candidate{"/repo", "z", "100", ["first"], True{}}]), "a"), "tie independent of input order")
    assert(String.eq(P.attribution_name(P.content("/repo", ["first"],
      [P.Candidate{"/other", "wrong-scope", "100", ["first"], True{}}])), "not_indexed"),
      "content repository scope")
    assert(String.eq(P.attribution_name(P.content("/repo", ["first"],
      [P.Candidate{"/repo", "diagnostic", "100", ["first"], False{}}])), "not_indexed"),
      "ineligible evidence rejected")
    assert(String.eq(P.attribution_name(P.content("/repo", ["first"],
      [P.Candidate{"/repo", "bad-time", "0100", ["first"], True{}}])), "not_indexed"),
      "noncanonical timestamps rejected")
    assert(exact_key(P.exact("/repo",
      [P.Candidate{"/repo", "captured-key", "", [], True{}},
       P.Candidate{"/repo", "captured-key", "", [], True{}}]), "captured-key"),
      "duplicate reference is one identity")
    assert(String.eq(P.attribution_name(P.exact("/repo",
      [P.Candidate{"/repo", "claude:same-id", "", [], True{}},
       P.Candidate{"/repo", "codex:same-id", "", [], True{}}])), "ambiguous"),
      "provider collision stays ambiguous")
    assert(String.eq(P.attribution_name(P.exact("/repo",
      [P.Candidate{"/other", "outside", "", [], True{}}])), "not_indexed"),
      "exact repository scope")
    assert(String.eq(P.attribution_name(P.exact("/repo",
      [P.Candidate{"/repo", "", "", [], True{}}])), "not_indexed"), "empty capture key rejected")
    assert(String.eq(P.attribution_name(P.probable("/repo",
      [P.Candidate{"/repo", "key", "", [], True{}}], "temporal")), "probable"),
      "probable never promotes")
    assert(P.uncommitted("0000000000000000000000000000000000000000"), "zero SHA uncommitted")
    assert(number(P.parse_u32("4294967295"), 4294967295), "maximum U32 exact")
    assert(no_number(P.parse_u32("4294967296")), "overflow rejected")
    assert(no_number(P.parse_u32("-1")), "negative line rejected")
    assert(no_number(P.parse_u32("12x")), "invalid line suffix rejected")
    assert(parsed_region(P.porcelain(
      "1234567890123456789012345678901234567890 7 9 1\nauthor Synthetic\nauthor-time 9007199254740993\nfilename a.bend\n\tlet café = \"🍋\"\n", 1)),
      "porcelain preserves coordinates Unicode and exact time")
    assert(parse_failed(P.porcelain("\tuncaptured\n", 1)), "orphan content rejected")
    assert(parse_failed(P.porcelain(
      "1234567890123456789012345678901234567890 7 9 1\nauthor Synthetic\n", 1)),
      "incomplete record rejected")
    assert(parse_failed(P.porcelain(
      "1234567890123456789012345678901234567890 7 9 1\n\tfirst\n1234567890123456789012345678901234567890 8 10 1\n\tsecond\n", 1)),
      "bounded region count enforced")
    assert(parse_failed(P.porcelain("", 0)), "zero region budget rejected")
    assert(P.safe_path("Sources/a.bend"), "ordinary relative path accepted")
    assert(Bool.not(P.safe_path("../private")), "path traversal rejected")
    assert(Bool.not(P.safe_path("/absolute")), "absolute path rejected")
    assert(Bool.not(P.safe_path("a//b")), "empty path component rejected")
    assert(Bool.not(P.safe_path("a\0b")), "NUL path rejected")
    IO.print("provenance: 36 independent assertions passed")

def live_result(result: Result<&2, &2, String, List<&2, P.Region>>) -> IO(Unit):
  match result:
    case Fail{error}:
      IO.die(Unit, 1, error)
    case Done{P.Region{_, _, line, _, text} <> Nil{}}:
      assert(Bool.and(U32.is_eq(line, 1), Bool.not(String.is_empty(text))),
        "live read-only Git returns requested first line")
    case Done{_}:
      IO.die(Unit, 1, "live Git returned unexpected region count")

def live_args(args: List<String>) -> IO(Unit):
  match args:
    case _ <> "--git" <> repo <> path <> Nil{}:
      do IO<Unit>:
        result : Result<&2, &2, String, List<&2, P.Region>> <- P.git_blame(repo, path, 1, 1)
        live_result(result)
    case _:
      IO.pure(Unit, Unit{})

def main() -> IO(Unit):
  do IO<Unit>:
    tests()
    args : List<String> <- IO.args()
    live_args(args)
