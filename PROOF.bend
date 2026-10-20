import Base
import ./LAWS.bend as Laws
import ./src/domain.bend as Domain

def and_false_left(a: Bool) -> {Bool.and(a, False{}) == False{} : Bool}:
  match a:
    case False{}:
      {==}
    case True{}:
      {==}

def le_refl(a: Nat) -> {Nat.is_le(a, a) == True{} : Bool}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      le_refl(p)

def min_le_left(+a: Nat, +b: Nat) ->
  {Nat.is_le(Nat.min(a, b), a) == True{} : Bool}:
  match a b:
    case 0n _:
      {==}
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      min_le_left(ap, bp)

def min_le_right(+a: Nat, +b: Nat) ->
  {Nat.is_le(Nat.min(a, b), b) == True{} : Bool}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+bp:
      {==}
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      min_le_right(ap, bp)

def Laws.pinned_snapshot_survives_append(selected, before, after):
  {==}

def Laws.generation_isolation(provider, source, snapshot, record, event):
  match provider source:
    case False{} _:
      {==}
    case True{} False{}:
      {==}
    case True{} True{}:
      {==}

def Laws.page_within_request(start, count, extent):
  min_le_left(count, Nat.sub(extent, start))

def Laws.page_within_snapshot(start, count, extent):
  min_le_right(count, Nat.sub(extent, start))

def Laws.excluded_provider(repository):
  {==}

def Laws.excluded_repository(provider):
  and_false_left(provider)

def Laws.missing_not_exact(key):
  {==}

def Laws.ambiguous_not_exact(key, eligible):
  match eligible:
    case False{}:
      {==}
    case True{}:
      {==}

def Laws.empty_hunk_never_matches(matched):
  match matched:
    case 0n:
      {==}
    case 1n+p:
      {==}

def Laws.threshold_below_never_matches(matched, tail, below):
  %Equal.sym(Bool, Nat.is_ge(Nat.mul(5n, matched), Nat.mul(3n, 2n+tail)),
    False{}, below) : {Bool.and(Nat.is_ge(matched, 2n), _) == False{} : Bool}
  and_false_left(Nat.is_ge(matched, 2n))

def Laws.lower_score_never_wins(time, key):
  {==}

def Laws.stable_tie_policy(key):
  {==}
