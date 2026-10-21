# Capabilities

This is an evidence ledger, not an acceptance declaration. Product acceptance
is recorded in `acceptance.md`.

| Boundary | Current evidence |
|---|---|
| Native CPU compilation | `scripts/build` compiled upstream hello and window examples to arm64 Mach-O; hello ran and printed `Hello, world!` |
| Native runtime | Actual macOS arm64 app launched and interacted with; browse/search/transcript, explicit capture, Blame/Why/export, Pause, Usage, rebuild and filters observed. See `native-validation.md` for build identities and remaining checks |
| Capture scheduling and guest resources | The historical Bend trace measured callback progress; the final uninstrumented Tart build visibly accepted input and Pause during a successful 100,016-record capture. An intermediate candidate with the final GUI measured 1.55% of one core at settled idle. Final GUI physical footprint after capture/rebuild was 46.2M. Input-to-photon remains unmeasured. See `performance.md` and the separately identified receipts |
| Compiler host | `scripts/bend version` executes Bend through mise-pinned Bun |
| Application language / runtime | Application/UI/test/proof sources remain Bend 2, with one maintained native source `native/sqlite.c`. Fresh `otool -L` on app `784d48c4…` shows SQLite, libSystem/libobjc and upstream macOS frameworks; no Lean dependency. Bun hosts the compiler; optional Lean checks BendTT proofs during development. Neither runs application behavior |
| Integrated native tests | The expanded suite completed 40 executables and 2,960 named checks, including 87 GUI-state checks, 226 append-batch checks and 27 publication crash cuts. All recorded inputs remained unchanged. See `receipts/test-parity-summary.txt`; the earlier 33-executable baseline receipt is preserved |
| SQLite boundary / FTS5 | Native boundary suite covers typed/NUL/binary/exact-integer round trips, FTS5, rollback/reopen, stale handles, statement failure cleanup, BUSY, cancellation, registry exhaustion/reuse and timer responsiveness; current integrated counts belong in `acceptance.md` |
| Exact file addressing | Pinned Base uses U32 file sizes/offsets; application must reject unsupported sizes explicitly |
| Raw file input / maintenance | `scripts/test tests/maintenance.bend` passed 30 checks, including exact UTF-8/NUL/invalid bytes, stale source independence, immutable append snapshots, oversized boundaries, full verification, rollback on rebuild failure and atomic export destination protection |
| Source identity | Native maintenance tests confirm relative, absolute and explicit symlink aliases resolve to one canonical source |
| Explicit source refresh | Native sources suite passes 24 checks; real main CLI registration, discovery/import, disabling and refresh were also observed with synthetic folders |
| Scoped transcript / Why | Native scoped reader suite passed 18 checks, including frozen provider/repository/role/date scopes, inherited context, projection forgery rejection and corrupt checkpoint failure |
| Displayed evidence export | Native CLI suite passed 9 checks for exact Unicode/citations, one MiB input bound, malformed UTF-8 rejection and existing-destination protection |
| Git Blame / file and commit Why | Native file-evidence suite passed 35 checks plus 36 unified-diff cases; real synthetic Git workflows cover per-hunk content, explicit-trailer exact identity, body-reference probable identity, ambiguity, linked worktrees and eligible child navigation |
| Current application CLI | Final executable passed isolated demo/status/search/scoped-read/verify/rebuild and identical-bundle launcher status. Earlier broader export/Usage/file/commit checks retain their separate build identities in `receipts/cli-final.txt` |
| Native Files browser | Candidate `0e1d1018…` passed actual pinned-commit source/evidence navigation, 107-entry directory paging, Unicode paths, unsupported-entry refusal, exact copy/export and captured History restoration. Focused CLI/GUI gates passed 351 checks. See `receipts/repository-files.txt` and `native-validation.md` |
| Recorded tool activity | Candidate `5ef9603d…` passed payload-first native viewports, actual Refresh with selected old text preserved, explicit latest after source removal, wheel scrolling, exact Unicode copy and exports. Readability gates passed 219 focused checks after the preceding 435-check integration gate. Pairing is confined to verified scoped occurrences; ambiguity and missing counterparts stay explicit. No complete-session or execution-success claim |
| Related captures | Candidate `784d48c4…` passed actual two-page navigation, scoped target/Tools, exact reader/list/query/scroll/selection restoration, old watermark after concurrent native capture, retained reads after hiding 22 synthetic sources, 13 clipboard and 3 export comparisons. Backend/CLI gates passed 163 checks. Coverage and ambiguity remain bounded and explicit; see `receipts/relations-host-lifecycle.txt` and `native-validation.md` |
| Read-only processes | Pinned Base exposes bounded output and timeout; application allowlist remains a Bend responsibility |
| Clipboard / Unicode / modifiers | Candidate `98283d91…` passed native Option+E/E composition to exact `café`, Command+A/C/V with exact `café 中文 🙂`, replacement and Shift+Arrow selection. Physical typing, complete IME and font shaping remain unverified; earlier failed injection retains its separate receipt |
| Result pages / saved captures / Storage | Candidate `98283d91…` passed native History/Search paging, saved-capture selection, explicit Open latest and read-only owned inventory. A new capture307 left the reader pinned to306 until explicit navigation. Storage logical/reusable quantities are not physical reclaimable bytes |
| Stronger kernel | Twelve production laws pass the pinned BendTT kernel with exact Lean 4.34.0 on macOS arm64. Optional repository-local setup verifies the official archive; missing prerequisites still fail `scripts/prove`. See `receipts/lean-toolchain.txt` and `receipts/prove-inputs.sha256` |

`scripts/test` builds Bend test entry points and launches each from its own
temporary directory. `scripts/bench` executes Bend workload logic from an
isolated directory. Missing test/benchmark/proof implementations are failures,
never successful empty runs.

Run/test/benchmark/UI-smoke wrappers set `umask 077`. `scripts/run --demo`
creates an isolated temporary directory unless an explicit `--data-dir` is
supplied. A source path is never inferred from a private home history.

Root discovery is limited to one enabled directory per refresh, two seconds,
256 KiB of entry output and 2,048 entries. Each refresh attempts at most eight
files, with independent failures in its JSON report. Discovered symlinks are
excluded and canonical paths rechecked; upstream lacks an atomic no-follow
file-open primitive, so hostile concurrent path replacement is not a claimed
filesystem sandbox. A running refresh can finish its bounded batch after pause;
pause prevents subsequent automatic refreshes.

Each import worker permits at most five minutes. The GUI refresh worker has a ten-minute outer
limit. An unusually slow eight-file batch can exceed that outer limit: its
result is a partial/failed refresh, and earlier independently committed captures
remain available. A timed-out batch must not be reported as fully successful.

Large projection/FTS publication is batched in Bend within the original atomic
transaction. The bridge deadline is unchanged. The final guest capture and
source-independent rebuild both published 125,020 searchable events. FTS cleanup
still scans the current index per source. A separate frozen 100-source/100k-record
workload measured 27.875 s initial import, 50 ms unchanged last source and 477 ms
middle-source append, with independent integrity and untouched-source checks.
This does not establish scaling for arbitrary library shapes; see `performance.md`.
