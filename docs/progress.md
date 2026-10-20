# Implementation checkpoint

2026-10-20, local macOS 27.0.1 arm64. Branch:
`codex/juice-bend-implementation`; existing draft PR #1. The native core workflow
is implemented and observed. **Full M0–M5 acceptance remains incomplete** at the
specific boundaries below; do not report the whole matrix as passed.

## Runnable result

The current `build/juice-bend` and `build/Juice Bend Current.app` contain the
same 4,621,176-byte native executable, SHA-256
`6a1287727e86e6d956dbfa7bf42bb6a1551d2fe064f110c805e14f6e8b85a32c`.
Both passed isolated native CLI smoke checks. The desktop-observed earlier
4ad55c63 build remains in `build/juice-bend-next` and `build/Juice Bend.app`;
that test bundle uses only `/private/tmp/juice-bend-native-validation`.
All build outputs and data are ignored. The current bundle has the ordinary
launcher; pass an explicit isolated data directory for further testing.

Mise pins Bun 1.4.2 and selects Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`; all 88 source hashes verify.
Use `mise run run -- --demo` from an unlocked desktop terminal. It builds and
opens a fresh synthetic demo. Bun is only the compiler host, not an application
runtime. `mise run app -- "build/Juice Bend Local.app"` creates a new local
bundle; choose an unused path. SQLite 3.54.0 with FTS5 was verified on this Mac.

The app captures explicit Claude/Codex JSONL into owned SQLite raw records,
retains immutable generations/snapshots, searches lexical FTS, pages verified
transcripts, copies selections, filters provider/repository/role/date, displays
bounded usage facts, performs conservative file/commit Blame and Why, and
exports retained evidence. Settings supports bounded root discovery, refresh,
pause and verified derived-index rebuild. All maintained application/UI logic
is Bend. The 418-line SQLite bridge is the native exception; same-executable
Bend workers have no dependency on the existing Juice process.

## Completed validation

- Final integrated `mise run test`: 31 executables, 2,007 named checks, exit 0,
  including 34 GUI-state checks. See `docs/receipts/test-summary.txt`.
- Deterministic process recovery: 27 exact initial/append/rewrite cuts across
  nine production transaction boundaries, 1,203 checks. Closed nonce markers
  distinguish a reached cut from an early failure; only owned synthetic child
  processes are terminated. Precommit rollback, postcommit survival, retry,
  old pinned evidence and fresh-replay equivalence pass. This is not power loss.
- Actual desktop: browse/search/open/scroll, query and reader copy/paste,
  explicit synthetic capture, file Blame/Why/export, Pause, Usage, verified
  rebuild and combined filters. Exact candidates and limitations are in
  `docs/native-validation.md`. The newest storage-hardening build is CLI-tested
  but has not been observed on the locked desktop.
- Twelve production laws pass ordinary checking and BendTT translation.
  Final `mise run prove` again passed ordinary checking then exited 1 because
  exact Lean/leanc 4.34.0 is unavailable. Stronger-kernel verification did not run.
- Final fresh 100k benchmark: first import 36.381 s; unchanged 7.019 s; append
  16 records 39.945 s; search p95 51 ms; late page p95 8 ms; repository-scoped
  late page p95 19 ms. All correctness assertions and frozen-input checks pass.
  Append remains materially slow. See `docs/performance.md` for receipts,
  sample sizes, source inventory and separate earlier backend RSS observations.
- Final build: 63.89 s with a fresh Clang module cache; repeat full build/local
  packaging: 62.85 s, identical executable. True incremental compilation is
  not implemented. No signing or distribution project was added.
- Independent review verified final source invariants and public receipt safety.
  All captures/fixtures are synthetic; original Juice checkout/data stayed read-only.

## Exact continuation

1. Inspect Git status and branch/PR state; preserve all local work. Keep PR #1
   draft while acceptance gaps remain. Original Juice and its pre-existing edits
   are read-only. Publication is authorized only in `tcashel/juice-bend`.
2. Unlock the Mac. Automation still reported a locked desktop at the final
   check. Launch the current bundle with a new private directory and no demo:
   `DATA=$(mktemp -d /tmp/juice-bend-empty.XXXXXX)` then
   `open "build/Juice Bend Current.app" --args --data-dir "$DATA"`.
   Verify the empty state, then explicit synthetic capture/search/reader/export.
   Do not scan private provider homes.
3. Reproduce indexing interaction with `mise run bench -- 100000` synthetic
   output. Accessibility calls previously timed out during large capture and
   small rebuild. Resolve same-executable-worker targeting versus an event-loop
   stall; read the A20 audit in `native-validation.md`. Measure startup, actual
   input/frame latency, settled/active GUI CPU and aggregate worker/GUI RSS.
4. Verify physical Command/Shift and Unicode/IME input. Automation produced
   ambiguous modifier events and truncated non-ASCII committed input. Pointer
   clipboard roundtrips worked; do not weaken modifier handling to fit the tool.
5. Obtain exact Lean 4.34.0 through the pinned upstream path and run
   `mise run prove`. DNS/network restrictions blocked installation; no substitute
   kernel, permission escalation or blanket OS setting change was used.
6. Investigate remaining linear raw-prefix verification and immutable projection
   copying in long-history append without weakening raw durability, stable
   evidence identity or corruption detection. The tuple-cursor rescan fix is
   already included and has 12 regression checks; do not repeat that fix.

Repeatable gates: `mise run test`, `mise run prove`, `mise run bench -- 100000`.
SSH publication failed DNS; the GitHub connector can publish the exact verified
Git tree using a fast-forward expected-head check. Preserve local commit identities
on backup branches when reconciling connector commits. No force push, merge,
release, private history or reference-source snapshot belongs in this work.
