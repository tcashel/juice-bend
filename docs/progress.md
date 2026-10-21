# Implementation checkpoint

## Goal and working result

The active owner goal is SwiftUI Juice feature parity without embeddings, then
UI polish. Fix long-history append and close validation gaps along the way.
This is not complete. All maintained app/UI/parser/policy/test/benchmark logic
remains **Bend 2**; the unchanged 418-line SQLite bridge is the native exception.
Lean is optional development-time proof checking, not an app dependency.

PR #1 is open, draft and unmerged on `codex/juice-bend-implementation`.
Verified published Settings commit: `d400401801d392b1259096d9841223f7ca5a07de`,
tree `ed75d25d4e87b0f00b83e35a9493f20663170fb4` (16 commits in draft PR #1).
It advances from Related `75cc3e03…`; inspect the live PR head and ignored
`build/settings-remote.json` before further publication. Bare published refs
retain the exact remote identity without changing the protected checkout index.
Publication is authorized only in `tcashel/juice-bend`; never merge automatically.
Original Juice checkout, database and logs remain read-only. Use synthetic data.

The current observed executable is `build/juice-bend-context-v2`, 11,908,344 bytes,
SHA-256 `503f1098ef910c153db717074311c692bd864030e1cf818f3484ad0b60a90694`.
The standard `build/juice-bend` and `build/Juice Bend Context.app` contain this
exact binary. Its isolated empty-library launcher status check passed. All 48
application inputs and 88 upstream hashes stayed unchanged. Prior named
Settings, Related, Seal Tools, Tools, Files, Parity and Validated artifacts remain.

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
- **Retained-chunk comparator:** the comparator and Store
  integration passed 2,225 native checks, including all 27 crash cuts, with all
  100 recorded regression inputs unchanged. The fresh production 100k benchmark
  passed all assertions and independent postflight: first import 33.582 s,
  unchanged 4.088 s, append 27.728 s. This does not establish an append speedup
  over 27.262 s. Binary `1e3a30ae…`, all 20 inputs and 88 upstream hashes are frozen.
  See `receipts/raw-chunks-native.txt` and `performance.md`.
- **Settings:** refresh preferences backend/CLI passed 154 native
  checks with 15 unchanged inputs. Atomic writes require strict presence and
  value readback; tests cover ignored writes, rollback and commit failures.
  Combined CLI dispatch is connected. GUI integration uses boxed saved origins,
  authoritative source inventory and acknowledged durable preferences. All
  388 focused GUI assertions passed; one test-only indentation failure is
  retained separately. Production sources stayed frozen through those gates.
  The isolated Settings fixture passed its native
  build and host CLI lifecycle (24 stable inputs, binary `7cff09dd…`): 42→49→50
  retained raw records, unchanged scoped origin, source-only append and refusal
  checks. Actual combined Settings app `2e3191d9…` then passed host-only Tart
  interaction: both source providers, registration without capture, selected
  Enable/Disable, explicit Import file, durable Pause/2h through restart, manual
  batches while paused, exact scoped record-40 restoration and appended search.
  Seven clipboard and four pixel-region checks passed; final integrity/FK checks
  passed. See `receipts/settings-ui-native.txt` and `native-validation.md`.
  All 46 application inputs and 88 upstream hashes stayed unchanged. Both
  owned windows closed, runner exit 130, VM stopped and leases absent.

## Next execution steps

1. Portable context v2 is validated and promoted locally; publish its explicit
   allowlist in `build/context-v2-publication-files.txt` on top of Settings
   `d4004018…`, checking live PR head first. Never merge or force push. Current
   application build/benchmark manifests must match the prepared staged tree.
2. Live Store `7241d1bc…`, Maintenance `4248e415…`, ContextStore `2a29ab4e…`
   and codec `6f69cc3e…` are frozen. The codec comment change is documented.
   Storage passed 1,896 checks across ten targets, including all 27 crash cuts,
   with 102 stable inputs. Isolated portable tests passed 812 and the actual
   old-writer/held-connection driver passed 45; prior pure codec passed 402.
   See `receipts/context-v2-native.txt` and ignored combined validation JSON.
   Corrected byte accounting and earlier harness/compile failures remain
   separately recorded; no weakened predicates. Both raw/source passes remain.
   The complete post-publication context gate precedes COMMIT.

   Production 100k binary `755adddd…` measured first import37.564s,
   unchanged3.922s, append24.678s; preceding33.582/4.088/27.728s. This is an
   initial-import regression alongside a shorter append observation, not a
   finished performance goal. All22inputs/88upstreamhashes stayed unchanged;
   independent counts, typed prefix contexts/events, rawIDs, FTS and integrity
   passed. An inefficient external postflight join was interrupted after timers;
   corrected point-lookup postflight passed against the same data. See receipt.

   Native app503f1098 passed oldv1 capture read, native v2 Refresh, exact pinned
   reader/selection, new scoped search and export in Tart. Five clipboard checks,
   one pixel-region comparison and a921-byte mode0600 export passed. Full verify
   passed for all3captures. V1 migration replay allocates all3rawrecords, so44→47;
   oldtext/contextstayexact. Standardapp promoted; prior namedapp retained.
   Run `build/tart/context-v2-4it0t0dm` is closed: runner130, VMstopped, leasesabsent.

   Next isolated candidate owner sqlite_bridge: bind the duplicate raw_digest
   once in put_piece, then128-key context paging with key/length selection before
   payload materialization. Preserve all final map checks, source passes,
   fractional/type/negative/byte-cut handling and trigger fallback. Files only
   under `build/context-batched-candidate`; do not apply until review and native
   gates. No new timing or speedup claim exists. Root owns final application
   integration, quiet timing, native validation and publication.
3. The isolated recorded-request classifier passed 110 native checks and exact
   text/Unicode-span review. It is not imported or published. Integrating it
   requires parser-version/rebuild and event-ordinal/scope compatibility tests;
   do not silently reinterpret existing captured evidence. Inline attachments
   and compressed archives also remain outstanding.
4. Complete retained-session Usage backend is unimported and under test:
   affine owned DEFERRED read transaction, bounded verified raw batches,
   exact decimal counters and bounded Base.Map call dedup. Scan completeness
   is distinct from attribution completeness. Claude mirrors/copies and the
   inspected Codex ordinary/fork/reviewer reducers retain unknowns explicitly.
   Codex reducer passed68nativechecks with95stableinputs; providers owns the
   complete-reader/Claude gates and review fixes for main-table qualification
   and duplicate metadata. No scratch ledger, billing/account lookup or current
   UI/parser mutation.
   Continue provider/archive coverage, deterministic context preparation, owned-storage management and
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
Related, Settings and context-v2 runs stopped cleanly. Never terminate unrelated processes.
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
Related/cache refs use `local-relations-validation` and
`published-relations-validation` suffixes. Settings uses the corresponding
`local-settings-validation` and `published-settings-validation` refs.
Exact commit/tree identities are in the ignored publication/remote JSON files.
The Settings allowlist includes preference/comparator implementation, tests and
receipts; isolated context-binding/request-origin modules and shared-projection
prototypes remain excluded.
Reconcile ordinary checkout metadata only in a session with normal Git access.

Repeatable gates: `mise run test`, `mise run prove`, `mise run bench -- 100000`.
Local full-test discovery also sees unintegrated experimental files; use
explicit focused gates during active work and identify the tested tree.
