# Capabilities

This is an evidence ledger, not an acceptance declaration. Product acceptance
is recorded in `acceptance.md`.

| Boundary | Current evidence |
|---|---|
| Native CPU compilation | `scripts/build` compiled upstream hello and window examples to arm64 Mach-O; hello ran and printed `Hello, world!` |
| Native runtime | Actual macOS arm64 app launched and interacted with; browse/search/transcript, explicit capture, Blame/Why/export, Pause, Usage, rebuild and filters observed. See `native-validation.md` for build identities and remaining checks |
| Capture scheduling and guest resources | The historical Bend trace measured callback progress; the final uninstrumented Tart build visibly accepted input and Pause during a successful 100,016-record capture. An intermediate candidate with the final GUI measured 1.55% of one core at settled idle. Final GUI physical footprint after capture/rebuild was 46.2M. Input-to-photon remains unmeasured. See `performance.md` and the separately identified receipts |
| Compiler host | `scripts/bend version` executes Bend through mise-pinned Bun |
| Integrated native tests | `scripts/test` (the mise test task) completed 33 executables and 2,166 named checks, including 52 GUI-state checks, 131 SQL-batch checks and 27 publication crash cuts. See `receipts/test-summary.txt` for exact scope and counts |
| SQLite boundary / FTS5 | Native boundary suite covers typed/NUL/binary/exact-integer round trips, FTS5, rollback/reopen, stale handles, statement failure cleanup, BUSY, cancellation, registry exhaustion/reuse and timer responsiveness; current integrated counts belong in `acceptance.md` |
| Exact file addressing | Pinned Base uses U32 file sizes/offsets; application must reject unsupported sizes explicitly |
| Raw file input / maintenance | `scripts/test tests/maintenance.bend` passed 30 checks, including exact UTF-8/NUL/invalid bytes, stale source independence, immutable append snapshots, oversized boundaries, full verification, rollback on rebuild failure and atomic export destination protection |
| Source identity | Native maintenance tests confirm relative, absolute and explicit symlink aliases resolve to one canonical source |
| Explicit source refresh | Native sources suite passes 24 checks; real main CLI registration, discovery/import, disabling and refresh were also observed with synthetic folders |
| Scoped transcript / Why | Native scoped reader suite passed 18 checks, including frozen provider/repository/role/date scopes, inherited context, projection forgery rejection and corrupt checkpoint failure |
| Displayed evidence export | Native CLI suite passed 9 checks for exact Unicode/citations, one MiB input bound, malformed UTF-8 rejection and existing-destination protection |
| Git Blame / file and commit Why | Native file-evidence suite passed 35 checks plus 36 unified-diff cases; real synthetic Git workflows cover per-hunk content, explicit-trailer exact identity, body-reference probable identity, ambiguity, linked worktrees and eligible child navigation |
| Current application CLI | Final executable passed isolated demo/status/search/scoped-read/verify/rebuild and identical-bundle launcher status. Earlier broader export/Usage/file/commit checks retain their separate build identities in `receipts/cli-final.txt` |
| Read-only processes | Pinned Base exposes bounded output and timeout; application allowlist remains a Bend responsibility |
| Clipboard / Unicode / modifiers | Final native Command+A/C/V, exact `café 中文 🙂` clipboard roundtrip, replacement and Shift+Arrow selection passed in Tart with explicit modifier events. Direct Unicode typing/IME remains unverified: the automation transport itself delivered altered native Text events |
| Stronger kernel | Requires exact Lean 4.34.0 or an explicit built `BENDTT`; missing prerequisites fail `scripts/prove` |

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
still scans the current index per source; many-source scaling is not measured.
