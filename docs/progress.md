# Implementation checkpoint

## Goal and working result

The active owner goal is SwiftUI Juice feature parity without embeddings, then
UI polish. Fix long-history append and close validation gaps along the way.
This is not complete. All maintained app/UI/parser/policy/test/benchmark logic
remains **Bend 2**; the unchanged 418-line SQLite bridge is the native exception.
Lean is optional development-time proof checking, not an app dependency.

PR #1 is open, draft and unmerged on `codex/juice-bend-implementation`.
This validated slice advances the preceding published commit
`960873a2aa95c30be9e8dcba75ab8bc7a7458a80`, tree
`22efb6739a7b376166466e1afe53c2f28aff2ef4`. Inspect the live PR head before
further publication; the bare published-ref record below tracks the update.
Publication is authorized only in `tcashel/juice-bend`; never merge automatically.
Original Juice checkout, database and logs remain read-only. Use synthetic data.

The current observed executable is `build/juice-bend-relations`, 10,462,024 bytes,
SHA-256 `784d48c4d180b5e711613dbf43797c869c526a2cbf8082c53f6b3bbb9e789ab2`.
The standard `build/juice-bend` and `build/Juice Bend Related.app` contain
this exact binary. Its isolated empty-library launcher check passed.
Previous named Seal Tools, Tools, Files, Parity and Validated artifacts remain intact.

Mise pins Bun 1.4.2 and Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`; 88 upstream hashes verify.
Host is macOS 27.0.1 (26A434), arm64; system SQLite 3.54.0 has FTS5.
From a desktop terminal, `mise run run -- --demo` builds a fresh synthetic demo.
It rebuilds the standard executable; use the named frozen binary for validation.
For a new local bundle, choose an unused path with `mise run app -- PATH.app`.

## Published evidence

The app preserves explicit Claude/Codex JSONL in owned SQLite, retains immutable
captures, provides lexical search with frozen filters, transcript selection/copy,
conservative Blame/Why, bounded Usage facts, exports, source settings and rebuild.
History/Search paging, saved captures, Open latest, read-only Storage inventory,
pinned-commit Files browsing and retained Tools are integrated.

The latest event-seal change passed 2,262 native checks, including all 27
process-crash cuts, typed corruption and actual old-writer/open-connection
compatibility. Both raw/source verification passes remain. Verified event-prefix
reuse is confined to the same uninterrupted write transaction. Schema/parser/
context versions are unchanged. Payload-first Tools passed 219 focused checks.
Actual combined Tart interaction passed Refresh 43→45 records, unchanged selected
old text, explicit latest after source removal, wheel scrolling, exact Unicode
copy and two mode-0600 exports. All 39 build inputs stayed unchanged.
See `receipts/event-seal-native.txt`, `receipts/seal-tools-native.txt`,
`native-validation.md` and `benchmarks/results/tart-seal-tools-summary.json`.

The preceding full regression passed 40 executables / 2,960 named checks.
Later focused gates have separate receipts; do not describe them as another
full-suite run. Twelve production Bend laws pass the pinned BendTT/Lean 4.34.0
kernel. Domain `f2f68a4a…` remains unchanged; rerun proofs after Domain changes.
Historical host/guest results and their limitations remain in acceptance,
performance and native-validation records.

## Validated Related and context-prefix slice

- **Context hash-prefix cache:** Store `c5b0e679…` is frozen. Scalar digest bytes,
  SQL, schema, bounds and verification remain unchanged. Seven native entry
  points passed 990 checks, including 362 scalar-equivalence cases. Independent
  reviews cleared the exact delta. See `receipts/context-prefix-native.txt`.
- **Production 100k long-session benchmark:** frozen binary `5ecad019…` passed,
  with 19 unchanged inputs and 88 upstream hashes. First import 33.304 s,
  unchanged refresh 4.579 s, append 27.262 s; search/late/scoped-late p95
  40/8/17 ms. Previous event-seal append was 28.226 s. These are individual
  observations, and long-session append remains slow. Independent counts,
  prefix equivalence and database integrity passed.
- **Many-source validation:** new Bend benchmark `many_sources.bend` passed
  small Claude/Codex correctness cases and the frozen 100×1000 run. Initial
  import 27.875 s, last-source unchanged 50 ms, middle-source append 477 ms,
  scoped search/late-page p95 17/15 ms. The append target is Claude. Untouched
  99 source headers/seals and FTS cells/types/rowids stayed identical; this does
  not claim bytewise comparison of all unrelated context rows. Current index
  has 100,016 events. Raw results and independent postflight are under
  `benchmarks/results/100000-many-sources*`. Both timing windows excluded
  task builds/tests/Tart; unrelated host activity was uncontrolled.
- **Related captures:** `relations.bend` and `relations_cli.bend`, plus actual
  CLI dispatch, passed 163 native checks with all 38 inputs unchanged.
  Exact references, an accepted-ID watermark, bounded verified raw reads,
  explicit parent/path-association distinctions and partial coverage remain.
  The first Codex metadata header controls relationship authority; later
  headers cannot silently add a parent. Read-only review cleared the fix.
  Role/date remain frozen target-reader filters, not relationship metadata
  filters. Self/direct two-way cycles are detected; longer cycles are not.
- **Related native UI:** the combined normal-O3 native app built successfully:
  `build/juice-bend-relations`, SHA `784d48c4d180b5e711613dbf43797c869c526a2cbf8082c53f6b3bbb9e789ab2`,
  10,462,024 bytes, all 42 inputs unchanged. Saved navigation uses an indirect
  Bend list to stay within the compiler's continuation arity limit. The new
  focused test passed all 51 assertions at normal O3 after test-only boxing
  fixed an Apple Clang continuation crash. Saved-state comparisons were
  strengthened; failed attempts remain separate. Existing GUI/Tools/Files/UI/
  trace gates passed 240 named checks, for 291 across separate invocations.
  Native Tart acceptance passed: 13 exact clipboard comparisons,
  three mode-0600 exports, seven pixel-region restoration checks, two Related
  pages, scoped target/Tools, concurrent actual Refresh 22→24 snapshots, source
  removal, old watermark 22 and explicit fresh watermark 24. See
  `receipts/relations-ui-native.txt`, `receipts/relations-gui-tests.txt` and
  `benchmarks/results/tart-relations-summary.json`.
- **Related native fixture:** `build/native-relations-bounded-fixture`,
  SHA `50d553d1…`, is frozen with 26 unchanged inputs. It creates 22 isolated
  sources, checks source-only parent append/child rewrite and refusal cases.
  Host lifecycle passed with the exact app: one refresh accepted snapshots 23/24,
  hide preserved all owned sources as `.retained`, and eight actual CLI reads
  plus integrity/refusal checks passed. See `receipts/relations-host-lifecycle.txt`.
  The isolated Tart run `build/tart/relations-v9utxn_y` is complete: both owned
  windows closed, runner exit 130, VM stopped and both leases absent.
- **Next-slice preparation, not integrated:** refresh preferences backend/tests
  and a pure retained-chunk comparator are being implemented in new files.
  They are excluded from the Related app/build and publication allowlist.

## Next execution steps

1. Verify the Related/cache publication completed using PR #1 and
   `refs/heads/codex/published-relations-validation` in the ignored bare store.
   If absent, publish the validated allowlist over `960873a2…` with the expected-
   head guard. Prepared files/orchestration are `build/relations-publication-files.txt`
   and `build/prepare-relations-publication.py`. Never merge or force push.
2. Integrate the new pure chunk comparator only after its exact equality and
   emitted-loop checks pass. Preserve every raw/digest/coverage predicate and
   both source-verification passes. Run focused capture regressions and a fresh
   standard100k production benchmark in a quiet task window; no performance
   improvement is established by comparator unit tests.
3. Integrate persisted refresh preferences and real source controls into
   Settings, with explicit error states and exact originating-reader restoration.
   New backend modules are isolated pending review; no default private scans.
4. Continue provider/archive coverage, full
   Usage, deterministic context preparation, owned-storage management and
   explicit opt-in connection/subscription surfaces, then UI polish. Do not
   read real accounts or provider configuration by default.

The 100k phase diagnostic before the cache measured 28.352 s through commit:
20.466 s staging, 4.446 s raw recheck, 1.022 s sealing, and bounded search/commit
work. Do not replace production timing with engine-only prototype results.
The independent shared-projection v2 prototype and rejected SHA partial-block
experiment remain preserved locally, excluded from the published application.

Tart `juice-tests` uses the external SSD at `/Volumes/VM_disks/tart`.
The owner authorizes necessary Tart sandbox access and no longer requires
cross-chat coordination. Still acquire the exclusive runner lease and use
host-only networking with isolated synthetic shares. Both the seal/Tools and
Related runs stopped cleanly. Never terminate unrelated processes.
Full IME/shaping/accessibility, exact input-to-display/scroll performance,
fresh-network setup and some resource measurements remain unverified.
Do not ask the owner to repeat unexplained physical-keyboard rituals.

## Publication mechanics

Checkout `.git` metadata is read-only in this session. Its local branch ref
still points to `b647310636e59543668ecadb27571b9a7c5ae9e4`; apparent local
changes include already published work. **Do not discard them.**
Use ignored `build/publication.git` with a separate explicit-file index, check
the staged tree against frozen manifests, then publish through the GitHub
connector with an expected-head fast-forward guard. Preserve local/remote
commit identities in that bare store; never force push.
Published seal/readability ref: `refs/heads/codex/published-seal-tools-validation`.
Prepared local commit: `57e797e23fd9f144b47c1297cc267fb384d15ba6`.
The next Related/cache local and published refs use the same names with
`local-relations-validation` and `published-relations-validation` suffixes.
Their exact commit/tree identities are in ignored `build/relations-publication.json`
and `build/relations-remote.json` after publication. Shared-projection and
next-slice preference/comparator files are excluded from that allowlist.
Reconcile ordinary checkout metadata only in a session with normal Git access.

Repeatable gates: `mise run test`, `mise run prove`, `mise run bench -- 100000`.
Local full-test discovery also sees unintegrated experimental files; use
explicit focused gates during active work and identify the tested tree.
