# Capabilities

This is an evidence ledger, not an acceptance declaration. Product acceptance
is recorded in `acceptance.md`.

| Boundary | Current evidence |
|---|---|
| Native CPU compilation | `scripts/build` compiled upstream hello and window examples to arm64 Mach-O; hello ran and printed `Hello, world!` |
| Native runtime | Actual macOS arm64 app launched and interacted with; browse/search/transcript, explicit capture, Blame/Why/export, Pause, Usage, rebuild and filters observed. See `native-validation.md` for build identities and remaining checks |
| Compiler host | `scripts/bend version` executes Bend through mise-pinned Bun |
| Integrated native tests | `mise run test` completed 31 executables and 2,007 named checks, including 34 GUI-state checks and 27 publication crash cuts. See `receipts/test-summary.txt` for exact scope and counts |
| SQLite boundary / FTS5 | Native boundary suite covers typed/NUL/binary/exact-integer round trips, FTS5, rollback/reopen, stale handles, statement failure cleanup, BUSY, cancellation, registry exhaustion/reuse and timer responsiveness; current integrated counts belong in `acceptance.md` |
| Exact file addressing | Pinned Base uses U32 file sizes/offsets; application must reject unsupported sizes explicitly |
| Raw file input / maintenance | `scripts/test tests/maintenance.bend` passed 30 checks, including exact UTF-8/NUL/invalid bytes, stale source independence, immutable append snapshots, oversized boundaries, full verification, rollback on rebuild failure and atomic export destination protection |
| Source identity | Native maintenance tests confirm relative, absolute and explicit symlink aliases resolve to one canonical source |
| Explicit source refresh | Native sources suite passes 24 checks; real main CLI registration, discovery/import, disabling and refresh were also observed with synthetic folders |
| Scoped transcript / Why | Native scoped reader suite passed 18 checks, including frozen provider/repository/role/date scopes, inherited context, projection forgery rejection and corrupt checkpoint failure |
| Displayed evidence export | Native CLI suite passed 9 checks for exact Unicode/citations, one MiB input bound, malformed UTF-8 rejection and existing-destination protection |
| Git Blame / file and commit Why | Native file-evidence suite passed 35 checks plus 36 unified-diff cases; real synthetic Git workflows cover per-hunk content, explicit-trailer exact identity, body-reference probable identity, ambiguity, linked worktrees and eligible child navigation |
| Current application CLI | Current executable passed nine capture/status/history/search/scoped-read/usage/verify/rebuild/export commands and identical-bundle status on isolated synthetic data. Earlier file/commit Why checks belong to the separately identified desktop-observed build; `receipts/cli-final.txt` distinguishes both receipts |
| Read-only processes | Pinned Base exposes bounded output and timeout; application allowlist remains a Bend responsibility |
| Clipboard / Unicode / modifiers | Pointer-driven query and selected transcript copy/paste roundtrips observed. Unicode/IME and physical modifiers remain unverified because automation input was unreliable |
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

Each import worker permits at most five minutes, covering the observed
39.9-second final 100k-record append. The GUI refresh worker has a ten-minute outer
limit. An unusually slow eight-file batch can exceed that outer limit: its
result is a partial/failed refresh, and earlier independently committed captures
remain available. A timed-out batch must not be reported as fully successful.
