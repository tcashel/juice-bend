# Implementation checkpoint

## Goal and boundaries

The owner goal is functional and UX/visual parity with SwiftUI Juice, excluding
embeddings and model features. This is **not complete**. Tens-of-seconds initial
import is acceptable; further marginal append tuning is deferred while product
work advances. All maintained application behavior remains **Bend 2**. The
unchanged 418-line SQLite bridge is the native exception. Lean is optional
proof checking and is not linked into the app. Mise pins Bun 1.4.2 and Bend 2.0.37
revision 60ca80aedeec9d8f0629b5f10dd19457d8ad67af; 88 upstream hashes verify.

PR #1 remains draft and unmerged on `codex/juice-bend-implementation`.
Publication is authorized only in `tcashel/juice-bend`, without force pushes.
Original Juice, its database and provider logs remain read-only. All fixtures
and native observations use isolated synthetic storage. Do not discard the
checkout's existing changes; its protected index predates published commits.

## Working executable and validated changes

`build/juice-bend-polish`, standard `build/juice-bend`, and
`build/Juice Bend Polished.app` contain the exact observed native executable:
SHA256 `fabcd5069359c929455412003623990927b2a2e371ade7352841b2a57844945e`,
13,039,632 bytes. All 55 app inputs and 88 upstream hashes stayed unchanged.
Isolated empty-library launcher status passed. Earlier named working apps remain.
Use the named executable for repeatable validation; `mise run run -- --demo`
builds current source and creates a synthetic demo.

- Reading polish passed 604 focused native checks with 131 unchanged inputs.
  Actual final-binary Tart observations passed Files → Settings → History exact
  selection/pixel restoration, Why export, Page Down/Up, fresh empty-library
  Unicode clipboard/Delete/replacement and Back during a real 100,001-record
  Usage worker. Licensed grayscale font, word-aware rows, full status inspection
  and effective capture-hold status are integrated. See `receipts/polish-native.txt`.

- Whole-session Usage now scans verified retained raw bytes in its own bounded
  SQLite read transaction. Claude call mirrors, Codex cumulative/fork accounting,
  unknown counts and partial coverage stay explicit. Separate native gates:
  reader 105, Codex 68, adapter 85, actual CLI dispatch 48, client 9; final GUI 88 plus
  265 existing regressions. These do not constitute a new full-suite run.
- Actual Tart interaction passed exact Claude/Codex summaries, scope refusal,
  Back/Why/Tools transitions, two exact mode 0600 exports, manual append capture,
  a real 30-second automatic rewrite capture from History, and retained old/latest
  reads after source paths were hidden. A 100,001-record pending Usage worker
  could finish after Back without changing the restored text/selection/screenshot.
  The initial provider-transition failure was fixed and retested; strict capture
  identity guards remain. See `receipts/usage-ui-native.txt` and the sanitized
  `benchmarks/results/tart-usage-summary.json`.
- Context batching passed 3,315 checks across 12 native targets, including all 27
  actual crash cuts, with 106 unchanged inputs. No schema/codec change or removed
  verification pass. Physical-Mac 100k observation: initial 36.194 s, unchanged 3.910 s,
  append 16 records 23.816 s; search/late/scoped-late p95 42/7/17 ms. Single observations
  do not establish statistical speedups. See `receipts/context-batched-native.txt`.
- One native Time Profiler recording resolved 42,190 CPU samples. String building
  and reference-count costs warrant investigation, but its whole-process sample
  percentages cannot be attributed solely to append. Sanitized flamegraph and
  exact caveats are in `receipts/append-profile-native.txt`.
- The authorized Linux laptop passed 300 portable checks across six unchanged
  executables and 116 unchanged inputs. Its first integration harness refusal was
  corrected without changing the binary. No macOS UI/performance/proof claim
  follows. See `benchmarks/results/linux-portable-summary.json`.

The preceding full suite passed 40 executables / 2,960 checks. Twelve production
Bend laws passed BendTT and pinned Lean 4.34.0; Domain `f2f68a4a…` is unchanged.
Historical Files, Tools, Related, Settings, preservation and export receipts
remain linked from `acceptance.md` and `native-validation.md`.

## Exact continuation

1. Validated Usage/context batching is published at
   `e354d4bd83946dc81084ddb5283b9940be893347`, tree
   `03b8c3686334a2c9c3f520e1f459ea783fa96a09` (18 commits in draft PR #1).
   Bare ref `published-usage-validation`, `build/usage-remote.json` and the
   explicit `build/usage-publication-*` files retain the exact identity. Verify
   live PR head before the next fast-forward; never merge. The source tree was
   bound to the app and context-batched benchmark input manifests.
2. Verified polish is prepared for publication through the explicit
   `build/polish-publication-files.txt` allowlist and separate bare Git index.
   `build/polish-publication.json` will record exact tree/commit identity; refresh
   live PR head before fast-forwarding. Do not stage the protected checkout index
   or publish ignored fixtures/traces. Standard and named polished apps are ready.
3. Normal scoped transcripts still put citations before payload; an older parity
   sentence incorrectly generalized the payload-first Tools change. Corrected
   documentation distinguishes them. Consider that small presentation change
   with exact text/copy/export tests; no evidence may be omitted.
4. Usage suspends capture; the UI now shows Capture suspended / Back to History.
   Back retires its request but cannot cancel the upstream OS worker handle.
   Final native observation confirms late completion preserves the restored view.
5. Next isolated provider slice is frozen in `build/request-origin-integration`:
   206 native checks (61 integration, 110 classifier, 35 file-evidence) passed
   with unchanged inputs. `adoption.patch` SHA256 `585e01d0…` adds read-time
   recorded-request eligibility and honest bounded Why excerpts; no parser,
   raw/projection identity or rebuild change. Review `result.json`, then adopt
   after the polish publication, rerun production provenance/export gates and
   observe native Why. It is not integrated or claimed as current behavior.
6. Resume the outstanding parity rows after native typography acceptance:
   provider/archive coverage, deterministic context preparation, owned-storage
   actions and explicit opt-in account/connection surfaces. Do not invent billing
   facts or access real histories/accounts by default. Full IME/shaping,
   accessibility, resize and latency remain unverified/upstream-limited.

Tart run `build/tart/usage-batched-5n_wbswg` is complete: owned windows closed,
runner 92760 exited 130, VM `juice-tests` stopped and owned lease was released.
Raw trace/XML, remote payloads and all private synthetic artifacts stay ignored.
Linux validation has no remaining owned processes. No Swift timing comparison
has run; any comparison must use the same host or same VM and equivalent work.

Upstream research confirmed linked-list String operations and continuation
arity limits in the actual pin. No separately packaged official Bend skill was
found in the searched public repositories. See `decisions.md`; this is not an
exhaustive claim about all repositories or a reason to move app logic out of Bend.

Polish Tart run `build/tart/polish-jnqg_ft_` is complete. All owned windows
closed, Dock autohide was restored to 0, runner62007 exited130, VM juice-tests
stopped and the exact owned lease was released. Final native receipt files are
under its ignored artifacts directory. No user input or approval is pending.
