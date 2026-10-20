# Implementation checkpoint

## Active parity goal

The owner's follow-up requests fixing slow append, closing validation gaps,
matching the SwiftUI Juice feature set without embeddings, and then UI polish.
This goal is active. PR #1 remains draft and unmerged. The native-validated
Tools integration is published at `3e9d9d5938d3a6bb4d49e2f113bb18cb3749f306`
(tree `2337f14ba9473b6826ddaae7b4d29dabcdc0325b`). The preceding
Files integration is published at `40e22d92bbebac93dc1d1c4fe47ca3a91e5b0747`
(tree `0f4d0503cb7621e97496d3ac9bd32c2846197130`). The preceding paging,
saved-capture, inventory and append-batching change is published at
`5cb5f0cd457288414904ed715f1dc949a5682cd8` (tree
`473c2b2645343cee8178e55cd68c399366f538b0`). It builds on toolchain commit
`edfeadd6bf3149739b3af00a6c92671354208584` and application baseline
`cf066af054346c2ee900ea8324f3a23f8e81482c`, whose historical results remain below.
Current iteration: the append event-seal optimization passed its backend gates
and actual combined native interaction. Tools payloads now precede full citations.
This validated change is prepared for publication over the Tools commit above.
The exact Lean 4.34.0 archive was obtained through the
authorized Tart guest, independently hash-checked and installed locally.
The pinned BendTT kernel now passes all twelve production laws. Its exact input
hashes are in `docs/receipts/prove-inputs.sha256`. A fresh verdict also passes
against the selected SHA optimization (`src/domain.bend` SHA-256 `f2f68a4a…`).
Lean is only Bend's development-time proof checker dependency. Application/UI,
tests, fixture generators, benchmarks and law definitions remain Bend 2; the
application neither links to nor runs Lean. Current application validation is
recorded separately from the historical baseline below. Root owns integration
and Tart lifecycle. The owner no longer requires cross-chat VM coordination;
the runner still checks stopped state and acquires its exclusive lease.

The preceding candidate `build/juice-bend-parity2` built with all 32 input
hashes unchanged: 5,917,312 bytes, SHA-256
`98283d91b51229f90eaacb90888466b91ea5ec3570ea96860ac5976ba431decd`.
It contains bounded result paging, saved-version navigation, Open latest,
read-only Storage inventory, literal Git paths and the append/hash changes.
Native Tart interaction checks passed, including exact dead-key composition,
retained export and explicit navigation from capture 306 to 307; see
`native-validation.md`. The expanded regression suite passed 40 executables
and 2,960 named checks, with all 74 first-party and 72 pinned-toolchain input
hashes unchanged. The historical validated binary remains intact.
The subsequent Files integration builds on that published commit. Its CLI/
browser/export gate passed 167 checks and GUI/Files/UI/trace gate passed 184.
Current app `build/juice-bend-files` is 8,265,920 bytes, SHA-256
`0e1d10180fa875ca225a1bae25f60b968689e6d0440ad1a21e82f4b7bbeb1434`;
all 35 build inputs remained unchanged and 88 upstream hashes passed.
Actual Tart interaction passed directory/source paging, Blame/Why, exact copy/
export, unsupported-entry refusal and captured History restoration. Source and
Why remained byte-identical after HEAD/worktree changes until explicit Open
repo pinned the new commit. The guest app closed and VM/leases were released.
Receipts: `docs/receipts/repository-files.txt`, `docs/native-validation.md` and
`benchmarks/results/tart-files-summary.json`; raw artifacts remain under
ignored `build/tart/files-f1sdqqfi`.
The Bend native catalog fixture passed host checks for 206 sources, 306 accepted
snapshots, 306 current search events and 101 saved versions. The frozen standard
100k benchmark passed: append 33.392 s, unchanged refresh 4.547 s, search p95
41 ms, late page 8 ms and scoped late page 18 ms. Append remains slow. The immutable binary and the known concurrent
Git-only source edit are recorded in `performance.md`. The host-only Tart
session stopped cleanly and released its lease; raw synthetic observations are
under `build/tart/catalog.U5y5pY/artifacts`.
The standalone shared-projection prototype is unintegrated and excluded from
the published app. Its v1 gate passed 1,304 checks. Bounded verification
reduced the engine-only 100k append diagnostic from 44.950 s to 21.446 s;
the latter exited 0 and passed independent database/event equivalence checks.
It excludes raw/source verification, FTS and capture, so it does not establish
an application append improvement. The subsequent phase diagnostic measured
18.183 s in Bend validation and 2.967 s in SQL/bridge/orchestration. Experimental
v2 uses two record digests and passed 1,591 checks. Its frozen, separate 100k
engine run exited 0: append 18.380 s, including 18.252 s verification; initial
projection 26.982 s. Independent postflight passed exact event equivalence,
unchanged raw/maps/metadata, database integrity and all frozen hashes. These
are engine-only results. No production migration follows from these diagnostics alone. Preserve the
working v2 store until migration, one-corpus FTS ranking, typed recovery,
snapshot reads and all crash boundaries are covered. Engine-only profiles are
diagnostic measurements, never app append performance.

The Tools candidate `build/juice-bend-activity` is 8,823,088 bytes, SHA-256
`68d221e24b7aed7635d2986783f4567c31004a14ff5424ed79a8b510780104db`.
All 38 build inputs remained unchanged and all 88 upstream hashes passed.
Its focused native gates passed 435 named checks across eight executables. Actual Tart interaction
passed page boundaries, exact copy, retained old pages after append/source
removal, Why/Files return, explicit Open latest, wheel scrolling and two exact
displayed-body exports. The app closed, VM stopped and leases were released.
See `docs/receipts/recorded-activity.txt` and `docs/native-validation.md`.
This preceding app's first viewport was metadata-heavy. The new payload-first
presentation passed 219 focused checks and actual combined native interaction.
No new latency/scroll-cadence claim is made.

The frozen event-seal candidate passed 2,262 native checks, including 27 crash
cuts, actual old-writer/old-open-connection compatibility and retained readers.
Store `31b7f8d5…` and Seal `eba657f6…` remain frozen. Standard 100k benchmark
`28d47af5…` passed append **28.226 s**, first import 32.940 s, unchanged 4.519 s,
and search/late/scoped-late p95 41/8/17 ms. All 19 inputs and 88 upstream hashes
remained unchanged; independent database counts and old/new prefix equivalence
passed. This is a 15.5% observed reduction from 33.392 s, still slow. A real
nine-callback production diagnostic passed at 28.352 s: staging 20.466 s,
raw recheck 4.446 s, sealing 1.022 s, search removal 0.875 s, search population
1.166 s and commit 0.376 s. All old typed capture fingerprints stayed unchanged;
both seals, raw sharing, counts and database integrity passed. See performance.md.
The combined app `5ef9603d…` passed actual Refresh (43→45 records), unchanged
selected old Tools text, explicit latest after source removal, payload-first
viewports, wheel scrolling, exact Unicode copies and two mode-0600 exports.
App windows closed, Tart stopped and leases were released. The working Tools
executable remains preserved. Relations backend work remains unintegrated.

## Published baseline

2026-10-20, local macOS 27.0.1 arm64. Branch:
`codex/juice-bend-implementation`; existing draft PR #1. The native core workflow
is implemented and observed on both the host and the coordinated local Tart
Mac guest. **Full M0–M5 acceptance remains incomplete** at the specific limits
below; do not report the entire matrix as passed.

## Runnable result

The current validated candidate is `build/juice-bend-seal-tools`, 9,091,528 bytes,
SHA-256 `5ef9603de4cb1f618476e7885170ea0ac174370ceef2fa30023cea1d5b3a87ca`.
All 39 transitive build inputs remained unchanged. The standard executable
`build/juice-bend` and new `build/Juice Bend Seal Tools.app` contain this exact
binary. Its bundle launcher passed an isolated empty-library status check.
Tools (`68d221e2…`), Files (`0e1d1018…`), Parity (`98283d91…`) and
Validated (`05cdff4f…`) executables/bundles remain preserved.
Outputs and synthetic data are ignored; use an explicit isolated data directory.

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

## Published baseline validation

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
   The unintegrated shared-projection verifier has a frozen SQL-versus-Bend
   phase diagnostic in `benchmarks/projection_verify.bend`; its isolated run
   passed at 21.153 s (18.183 s Bend validation, 2.967 s SQL/bridge, remaining
   metadata/loop overhead), with the database hash unchanged after rollback.
   The experimental two-digest record format passed 1,591 native checks and
   independent source review; its one frozen timing run exited 0 at 18.380 s
   engine append; independent database/event-equivalence postflight passed.
   Preserve the c750 baseline. A separate bit-identical SHA partial-block
   packing experiment passed equivalence checks but showed no reliable gain
   in three paired trials and was not promoted. It remains confined to ignored
   `build/hash-partial-candidate`; production Domain remains unchanged. Preserve
   production v2 and do not promote an engine-only timing into an app result.
   The narrower `event-seal-v1` optimization passed validation in
   `src/projection_seal.bend`, `src/store.bend` and focused tests. Typed corruption,
   copied-prefix equality, trigger compatibility, actual old-writer
   compatibility, all 27 crash cuts, reader gates and the frozen 100k production
   workload have passed. Preserve validated Store/Seal while profiling cost.
   IDs remain exact decimal strings; event counts are checked U32. Reuse is
   confined to one uninterrupted write transaction after fresh verification.
   The combined native app interaction check also passed. Publish this coherent
   seal/readability slice over `3e9d9d59…`, preserving frozen apps and manifests;
   exclude the separate shared-projection prototype and unintegrated Relations.
   The production observer isolates staging as the largest remaining append
   phase. Analyze it without weakening raw verification or immutable snapshots.
   Tools displays recorded arguments/results before full citations, retaining
   one canonical display/copy/export string. Child navigation, full Usage and remaining
   Settings/provider/connection surfaces remain in the parity backlog.
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
