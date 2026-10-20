# Implementation checkpoint

2026-10-20, local macOS 27.0.1 arm64. Implementation branch:
`codex/juice-bend-implementation`; existing draft PR #1. The native core
workflow is implemented and observed. **Full M0–M5 acceptance is incomplete**
at the boundaries listed below; do not report the whole matrix as passed.

## Runnable result

`build/juice-bend` and `build/Juice Bend.app` contain the final native build,
4,619,552 bytes, SHA-256
`4ad55c63cb542b68740e032f05ff528c25c3ce7250a6f07c1bfbd0d3f25f5d49`.
The local test bundle uses only `/private/tmp/juice-bend-native-validation`.
Build outputs and data are ignored, never published.

Mise pins Bun 1.4.2 as compiler host and selects Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`; all 88 source hashes verify.
Use `mise run build` and `mise run run -- --demo` from an unlocked desktop
terminal. Bun is not an application runtime. `mise run app -- "build/Juice Bend Local.app"`
creates a new local bundle; choose an unused path.

The app captures explicit Claude/Codex JSONL into owned SQLite raw records,
retains immutable generations/snapshots, searches lexical FTS, pages verified
transcripts, copies selections, filters provider/repository/role/date, displays
bounded usage facts, performs conservative file/commit Blame and Why, and
exports retained evidence. Source settings support bounded root discovery,
refresh, pause and verified derived-index rebuild. GUI workers are the same
native Bend executable; there is no Juice-process dependency.

## Completed validation

- Full native suite: 29 executables, 790 named checks, exit 0. The final
  focused GUI run passed 34 checks after two additional ordinal regressions.
  Counts overlap; see `docs/receipts/test-summary.txt` and `gui-final.txt`.
- Actual desktop: browse/search/open/scroll, query and reader copy/paste,
  explicit synthetic capture, file Blame/Why/export, Pause, Usage, verified
  rebuild and combined provider/role/date filters. Exact build identities
  and limitations are in `docs/native-validation.md`.
- Storage tests include abrupt termination of only the synthetic worker,
  rollback, raw/index corruption, append versus fresh-import equivalence,
  retained citations after source deletion/rewrite and exact size boundaries.
- Twelve production laws pass ordinary checking and BendTT translation.
  Stronger Lean kernel verification did not run; `scripts/prove` exits 1
  with an explicit prerequisite error. Exact receipts are retained.
- Final fresh 100k workload: search p95 60 ms, late page p95 20 ms,
  repository-scoped late page p95 30 ms. First capture 56.5 s; append of
  16 records 71.4 s, a material remaining performance limitation.
  Backend peak RSS measurements and code-size inventory are in
  `docs/performance.md`; they are not GUI resource measurements.
- Independent review found and fixed mixed-repository preview leakage and
  late search/history opening at record zero. Regression checks pass.

## Exact continuation

1. Inspect `git status` and branch/PR state; preserve all local work. The
   original Juice checkout and its existing edits are read-only references.
2. Unlock the Mac for native automation. The final empty-library launch was
   blocked by the locked-screen tool response. Observe a new private data
   directory without `--demo`; do not scan private provider homes.
3. Reproduce large-capture input using the synthetic benchmark generator.
   Native accessibility calls timed out during capture and around a small
   rebuild. Distinguish automation targeting of same-executable workers from
   a real event-loop stall. A later screenshot is not an input-latency proof.
   Measure startup, input/frame latency and settled/active GUI CPU/RSS.
4. Verify physical Command/Shift and Unicode/IME input. The automation tool
   emitted ambiguous modifier events and truncated non-ASCII committed input.
   Pointer clipboard roundtrips worked; do not weaken modifier handling.
5. Obtain the exact Lean 4.34.0 prerequisite through the pinned upstream path
   and run `mise run prove`. DNS/network restrictions blocked local installation;
   no permission escalation or substitute kernel was used.
6. Extend controlled crash injection across remaining publication boundaries
   and investigate linear append verification/projection copying without
   weakening raw durability, immutable snapshots or corruption detection.

`mise run test`, `mise run prove`, and `mise run bench -- 100000` are the
repeatable gates. Use targeted suites for fixes, then the required integrated
checks. Ordinary checking is not stronger-kernel verification. Keep PR #1
draft while these acceptance gaps remain; do not merge automatically.

Repository publication is authorized only to `tcashel/juice-bend`. SSH push
failed DNS in this execution context; the GitHub connector can publish the
same verified Git tree with a fast-forward expected-head check. Preserve local
commits when reconciling connector-created commit identities. No force push,
release, signing, paid service, private history or reference-source copy belongs
in this continuation.
