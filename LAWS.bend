import Base
import ./src/domain.bend as Domain

# These are pure production guarantees. Filesystem capture coherence, SQLite
# commit atomicity, UTF8/FFI validity, compiler lowering and UI remain tested
# trust boundaries. The assertions do not assume their external correctness.

law pinned_snapshot_survives_append:
  for +selected: String
  for before: String
  for after: String
  {Domain.select_snapshot(Some{selected}, before) ==
    Domain.select_snapshot(Some{selected}, after) : String}

law generation_isolation:
  for provider: Bool
  for source: Bool
  for snapshot: Bool
  for record: Bool
  for event: Bool
  {Domain.identity_guard(provider, source, False{}, snapshot, record, event) ==
    False{} : Bool}

law page_within_request:
  for +start: Nat
  for +count: Nat
  for +extent: Nat
  {Nat.is_le(Domain.count_nat(start, count, extent), count) == True{} : Bool}

law page_within_snapshot:
  for +start: Nat
  for +count: Nat
  for +extent: Nat
  {Nat.is_le(Domain.count_nat(start, count, extent), Nat.sub(extent, start)) ==
    True{} : Bool}

law excluded_provider:
  for repository: Bool
  {Domain.scope_guard(False{}, repository) == False{} : Bool}

law excluded_repository:
  for provider: Bool
  {Domain.scope_guard(provider, False{}) == False{} : Bool}

law missing_not_exact:
  for key: String
  {Domain.identity_insert(key, False{}, Domain.MissingIdentity{}) ==
    Domain.MissingIdentity{} : Domain.IdentityEvidence}

law ambiguous_not_exact:
  for key: String
  for eligible: Bool
  {Domain.identity_insert(key, eligible, Domain.AmbiguousIdentity{}) ==
    Domain.AmbiguousIdentity{} : Domain.IdentityEvidence}

law empty_hunk_never_matches:
  for matched: Nat
  {Domain.eligible_match(matched, 0n) == False{} : Bool}

law threshold_below_never_matches:
  for +matched: Nat
  for +tail: Nat
  for below: {Nat.is_ge(Nat.mul(5n, matched), Nat.mul(3n, 2n+tail)) ==
    False{} : Bool}
  {Domain.eligible_nonzero(matched, 2n+tail) == False{} : Bool}

law lower_score_never_wins:
  for time: Cmp
  for key: Cmp
  {Domain.prefer_candidate(LT{}, time, key) == False{} : Bool}

law stable_tie_policy:
  for key: Cmp
  {Domain.prefer_candidate(EQ{}, EQ{}, key) == Cmp.is_le(key) : Bool}
