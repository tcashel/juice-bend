# Implementation checkpoint

## Active parity goal

The owner's follow-up requests fixing slow append, closing validation gaps,
matching the SwiftUI Juice feature set without embeddings, and then UI polish.
This goal is active. The published baseline is PR #1 commit
`cf066af054346c2ee900ea8324f3a23f8e81482c`; its measured results follow below.
Current iteration: bounded raw verification/context insertion and bit-identical
SHA throughput work; bounded result paging and saved-version navigation; owned
storage inventory. The exact Lean 4.34.0 archive was obtained through the
authorized Tart guest, independently hash-checked and installed locally.
The pinned BendTT kernel now passes all twelve production laws. Its exact input
hashes are in `docs/receipts/prove-inputs.sha256`; SHA optimization will require
a fresh verdict. New uncommitted application changes
are not covered by the baseline test counts until rerun. Root owns integration
and Tart lifecycle. The owner no longer requires cross-chat VM coordination;
the runner still checks stopped state and acquires its exclusive lease.

## Published baseline

2026-10-20, local macOS 27.0.1 arm64. Branch:
`codex/juice-bend-implementation`; existing draft PR #1. The native core workflow
is implemented and observed on both the host and the coordinated local Tart
Mac guest. **Full M0–M5 acceptance remains incomplete** at the specific limits
below; do not report the entire matrix as passed.

## Runnable result

The final native candidate is `build/juice-bend-validated`, 4,708,120 bytes,
SHA-256 `05cdff4f599edcd16646fc3363e27c3856bda4b073f52a92f23264887ef5ba35`.
The standard executable `build/juice-bend` and local bundle
`build/Juice Bend Validated.app` use this same candidate. Earlier bundles remain
preserved and are not the current candidate. Outputs and synthetic data are
ignored; use an explicit isolated data directory for validation.

Mise pins Bun 1.4.2 and Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`; all 88 source hashes verify.
From a desktop terminal, `mise run run -- --demo` builds and opens a fresh
synthetic library. `mise run app -- "build/Juice Bend Local.app"` creates a new
bundle; choose an unused path. Bun hosts the compiler only. System SQLite
3.54.0 with FTS5 was observed on host and guest.

The app captures explicit Claude/Codex JSONL into owned SQLite raw records,
retains immutable generations/snapshots, searches lexical FTS, pages verified
transcripts, copies selections, filters provider/repository/role/date, displays
bounded usage facts, performs conservative file/commit Blame and Why, and
exports retained evidence. Settings supports bounded root discovery, refresh,
pause and verified derived-index rebuild. All maintained application/UI logic
is Bend; the unchanged 418-line SQLite bridge is the native exception.
Same-executable Bend workers do not depend on the existing Juice process.

## Completed validation

- Full native suite: **33 executables, 2,166 named checks**, exit 0. Includes
  52 GUI-state, 131 SQL-batch and 10 diagnostic checks; exact counts are in
  `docs/receipts/test-summary.txt`.
- Crash recovery: 27 initial/append/rewrite cuts across nine real transaction
  boundaries, 1,203 checks. Nonce markers verify reached cuts; only owned
  synthetic children are terminated. Rollback, postcommit survival, retry,
  pinned evidence and independent fresh replay pass. This is not power loss.
- Final native Tart build: fresh empty launch; capture of **100,016 physical
  records / 125,020 events**; visible query input and Pause while capture ran;
  retained search/open/scroll/selection/copy/Why/export after moving the source
  away; verified rebuild with source still absent. Rebuilt index count was
  125,020, and SQLite quick_check returned `ok`. Export was inspected mode-0600
  Markdown with retained citations. Earlier host observations cover file Blame,
  Usage and combined filters; candidate boundaries remain explicit in
  `docs/native-validation.md`.
- Final native Command+A/C/V, exact `café 中文 🙂` clipboard roundtrip,
  replacement with `keyboard-ok`, and Shift+Arrow selection passed. Direct
  Unicode typing/IME remains unverified: external automation delivered altered
  native Text events. The app's input logic was not weakened to fit the tool.
- Large guest capture exposed an interrupted bulk FTS statement in the earlier
  candidate. Bend now bounds SQL row/payload batches inside the existing
  transaction. Final capture and retained rebuild passed without changing the
  bridge deadline. New tests cover multi-event boundaries, oversized fields,
  signed rowids, late-failure rollback and retry.
- Monotonic 30-second refresh and an 80 ms settled idle delay replace frame-count
  scheduling. An intermediate build with the final GUI measured **1.55% of one
  core** at idle, versus 15.25% initially. Final GUI physical footprint after
  capture/rebuild was **46.2M**, not aggregate GUI-plus-worker memory. Precise
  input-to-display latency and scroll cadence remain unmeasured.
- Fresh final-source 100k benchmark: first import **35.570 s**, unchanged
  **6.831 s**, append 16 records **40.103 s**, search p95 **39 ms**, late page
  p95 **8 ms**, repository-scoped late page p95 **18 ms**. All assertions and
  31 frozen source/build-input hashes passed. Five-trial p95 is the observed
  maximum. See `docs/performance.md`; long-history append remains slow.
- At this baseline, twelve production laws passed ordinary checking and BendTT
  translation. The subsequent local Lean installation closes the stronger
  kernel gap: `scripts/prove` exits 0 with `ALL PROOFS CHECK`. Historical
  unavailability receipts are preserved as `prove-before-lean.*`.
- Independent review found no blocking source/ownership/publication regression.
  No app source, bridge or upstream runtime changed after the full suite.

## VM handoff and exact continuation

The owner authorized Tart and its required sandbox exception. The chat
“Add app storage management” released `juice-tests` before our run. The runner
used isolated synthetic shares and host-only networking. Our app/workers closed
normally; the runner stopped only its owned Tart child and exited 130 after
Ctrl-C. `juice-tests` is **stopped**, both shared runner/cleanup locks are
**absent**, and the other chat was notified. No live VM/process lease remains.
Original Juice checkout/data and prior VM results were left untouched.

Raw screenshots, traces and isolated payloads are ignored under
`build/tart/native-c6dldcyb/session-artifacts`; the guest synthetic root is
`/private/tmp/juice-bend-tart.oMg430yg`. The committed sanitized summary is
`benchmarks/results/tart-native-summary.json`. Never publish real history or
reference-source snapshots.

1. Inspect Git status and branch/PR state; preserve local changes. PR #1 remains
   draft, with publication authorized only in `tcashel/juice-bend`. No merge.
2. Re-run `mise run prove` after domain changes. Exact Lean/leanc 4.34.0 and the
   pinned upstream kernel are now installed under `.tools`; no global install.
3. Acquire a new Tart lease before further guest work. The owner no longer
   requires cross-chat coordination. The dependency-download guest used
   explicit shared networking and is stopped with its lease removed. Normal
   native validation still defaults to host-only networking. Current native
   Command/Shift/clipboard checks are complete; remaining input work is direct
   Unicode typing/IME plus precise input-to-display and scroll measurements.
   Use the diagnostic's opt-in native event log to distinguish injected events
   from application behavior. Do not ask the owner to repeat an unexplained
   physical-keyboard ritual. Unsupported glyphs still display boxes while
   copy/export retain Unicode; complete shaping/accessibility are not claimed.
4. Investigate linear raw-prefix verification and immutable projection copying
   in long-history append without weakening integrity or stable citations.
   Per-source FTS cleanup still scans the current index; many-source and 1M
   stress scaling remain unmeasured. The tuple-cursor and bounded-statement
   fixes are already included; do not repeat them.
5. Fresh-machine setup and the remaining acceptance rows retain their explicit
   partial/not-run status in `docs/acceptance.md`. No signing, distribution,
   semantic search, model runtime or existing Juice service is in scope.

Repeatable gates: `mise run test`, `mise run prove`, `mise run bench -- 100000`.
The GitHub connector can publish the exact verified tree with a fast-forward
expected-head check when shell DNS is unavailable. Preserve local commit
identities on backup branches when reconciling connector commits; no force push.

This session's checkout `.git` metadata is read-only (`index.lock` creation was
denied). Publication therefore uses the ignored `build/publication.git` object
store and a separate index, preserving a coherent local commit without changing
the checkout metadata. The working files contain the published tree; the local
implementation-branch ref still points at `b647310636e59543668ecadb27571b9a7c5ae9e4`
until it can be reconciled with the remote. Do not discard these apparent local
changes. Verify the remote tree and preserve the local publication commit before
advancing the checkout's ref in a session with ordinary Git write access.
