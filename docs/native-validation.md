# Native interaction observations

2026-10-20, macOS 27.0.1 arm64, actual desktop windows through the pinned
Bend runtime. Only synthetic libraries were used. These are observed
interactions, not automated latency or complete accessibility acceptance.

The current desktop-observed executable is 4,621,176 bytes, SHA-256
`6a1287727e86e6d956dbfa7bf42bb6a1551d2fe064f110c805e14f6e8b85a32c`.
The dated unlocked follow-up below records its fresh-library workflow.
Earlier observations belong to the separate candidates identified below;
their results are not silently transferred to the current build.

## Historical workflow — earlier candidates

The preceding integrated candidate
`426ae88331e52b0f9cecc93fc23e29d23ec0b4e79c44d3856ce6bc26c0fc13be`
completed this actual native workflow:

| Interaction | Observed result |
|---|---|
| Launch and browse | Native window displayed captured Claude/Codex sessions and retained transcript |
| Search | Typed `preservation` appeared intact and returned 21 Claude hits |
| Transcript | Result selection opened the captured snapshot; full text, code, arguments and tool results displayed |
| Scroll | Reader moved through retained records |
| Query clipboard | Select all → Copy → Clear visibly emptied the field; Paste restored `clipboard-check-2048` |
| Reader clipboard | Drag-selected `let display = 42` in the evidence reader; Copy and Paste restored that exact text in the Settings field |
| Explicit capture | Settings imported the synthetic `gui-demo.jsonl`; the owned library gained snapshot 3 |
| Blame | Explicit fixture repository/file/range displayed line 1, `let display = 42`, exact session-trailer association and immutable citation |
| Why | File Why displayed captured user intent and disclosed that intent is not proof of success or an inferred rationale |
| Export | Created `evidence-file-1122732995-0.md`, 2,606 bytes, mode 0600; inspection confirmed the displayed citations and captured request |
| Large capture | Settings imported the synthetic 100,016-record benchmark source; final library had four accepted snapshots and 125,054 projected events |
| Close | Native close control closed the window before replacing its executable |

The later `4ad55c63cb542b68740e032f05ff528c25c3ce7250a6f07c1bfbd0d3f25f5d49`
executable was then launched against the retained library:

| Interaction | Observed result |
|---|---|
| Retained long session | Snapshot 4 opened at record 0 with full captured fields and tools |
| Pause | Button displayed “Automatic refresh paused. In-flight work finishes safely; manual Refresh still works.” |
| Usage | Displayed the bounded 0–40 record range, raw recorded buckets, citations and explicit unknown subtotals for missing message identities |
| Provider selection | Codex sidebar returned one captured source; opening it started at its first readable event, record 2 |
| Verified rebuild | Settings rebuilt snapshot 2 and displayed success while retaining captured evidence |
| Combined filters | `provider:codex role:assistant after:2026-10-01` returned two results |
| Scoped reader | Opening the first filtered result showed record 3, exactly two assistant events, the selected date/provider scope and captured model/tool arguments |
| Close | Window closed through its native close control |

Snapshot 2 was created by an earlier development parser. Its old timestamp
projection initially returned no date-filtered results. The observed rebuild
verified raw bytes and regenerated the current projection, after which the
combined filter returned the expected two events. Historical bytes and capture
identity did not change.

## Unlocked follow-up — 2026-10-20

The current `6a1287727e86e6d956dbfa7bf42bb6a1551d2fe064f110c805e14f6e8b85a32c`
production executable was observed on the unlocked desktop using a new private
synthetic library. Settings displayed the isolated data root.

| Interaction | Observed result |
|---|---|
| Fresh launch | Empty-library native state displayed before explicit capture |
| Explicit capture | Settings imported the selected synthetic source: 24 physical records and 25 normalized events |
| Search and transcript | `preservation` returned 21 results; opening a result displayed physical record 1 |
| Reader clipboard | Drag-selection, Copy and Paste returned the exact word `snapshot` |
| Why | Displayed captured evidence with its selected scope |
| Export | Created an 11,866-byte evidence file with mode 0600; SHA-256 `d6dc211b682bae98af26d74af83e986429683d3d9fead6ec300dccad02ee1fd3` |
| Large capture | The synthetic 100,016-record source became accepted snapshot 2 with 125,020 events; both snapshots together held 125,045 events |

Accessibility and screenshot calls timed out at about five seconds while the
large capture was active. A later observation showed the retained query
`during-capture-1`; this establishes neither when it was painted nor input
latency during capture. The GUI process identity was retained, but process
inspection and sampling were denied. The bounded Bend trace below subsequently
supplied callback timing evidence; A20's full input-to-visible and resource
acceptance remains incomplete.

The desktop temporarily relocked, then the owner unlocked it for the diagnostic.
The owner did not complete the requested physical keyboard check; no physical
modifier or IME success is inferred. Both validation windows were subsequently
closed and the production bundle's ordinary launcher restored.

## Unverified input and timing boundaries

Unsupported glyphs display boxes; backend tests and inspected exports preserve
the original Unicode. The UI tool's attempted committed text
`Unicode café 你好 🙂` stopped after the ASCII prefix. A separate input probe
also showed its `super+a`/`Meta_L+a` events carried ambiguous native key code
zero rather than the documented Command codes. Full Unicode commit, IME and
physical Command/Shift interaction therefore remain **unverified**. The app
does not guess which modifier an ambiguous event represents.

Shell `pbpaste` comparisons did not observe the desktop clipboard. Clipboard
acceptance above is based on the visible in-app copy/clear/paste roundtrip,
not on a successful process exit or those failed shell comparisons.

During the earlier large capture, several native accessibility/action calls
timed out after about five seconds. A later screenshot showed the typed query and
completed results; that does not establish when input became visible.
Similar tool timeouts occurred around a small rebuild. The later callback trace
rules out a continuous callback freeze during its capture, while the cause of
automation timeouts remains unresolved. A20 and input-to-visible p95 are not
accepted.

An earlier empty-library attempt was blocked by the locked desktop. The
unlocked follow-up above subsequently observed that state on the current
production build. No OS setting or permission was changed.

## Read-only A20 investigation — 2026-10-20

The source audit at `c6e5d18` verified the installed Bend revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af` against
`toolchain/bend.sha256`. In `src/gui.bend`, capture and rebuild use
`start_write` → `IO.fork` → `Process.run`; reader/writer polling uses
`Chan.try_recv(..., 0)`. The pinned runtime's
`bend2/base.bend` (`IO.fork`), `bend2/effs/process_run.c`
(`process_run_run`) and `bend2/comp.ts` (`io_work`, `io_help`) queue the
child-process wait on helper threads. `bend2/effs/chan.c` (`chan_try`)
returns immediately when a zero-timeout receive has no result. No direct
capture/rebuild process wait was found in the GUI tick.

This does not prove responsiveness. Bend's IO scheduler is cooperative:
`process_pack` reconstructs returned strings, `src/client.bend` parses
completed JSON, and `src/ui.bend` wraps/renders returned text before the
next frame. Forking does not preempt those pure computations. Replies are
capped at 1 MiB, but their completion-time frame cost is unmeasured.
Copy/paste also await their clipboard command within the GUI tick, with a
2,000 ms timeout.

CLI workers reuse the GUI executable but dispatch to CLI commands without
opening a window (`src/main.bend`). Whether automation resolved one of
those workers instead of the window-owning process remains an unresolved
hypothesis. The subsequent bounded diagnostic below provides timing evidence
from the GUI callbacks while capture is pending. Tool round-trip time is not
input/frame latency. No application semantics were changed by this audit;
remaining pixel-display and resource measurements are still required.

## Bounded native callback trace — 2026-10-20

`benchmarks/native_trace.bend` wraps the production `Gui.view` and `Gui.tick`
callbacks without modifying them. Its 4,821,704-byte executable has SHA-256
`537145d12c3442e073fda1325e64dcf42e2cfdfdfff3da9fd8f89cb8a6585328`.
It ran in a separately identified local bundle against a fresh private library.
The current production executable's hash remained unchanged.

The native window imported the 100,016-record synthetic source, accepted one
35,607,307-byte snapshot and projected 125,020 events. While capture was pending,
automated input changed the Settings field to `active-capture-check` and toggled
Pause. The trace recorded the completed query at frame 4,379, a subsequent frame
return 9 ms later, and Pause at frame 4,385. All still had a pending writer.
External read-only SQLite observations also saw zero accepted snapshots then;
the later screenshot showed the completed capture and retained input.

The capture's pending-writer interval spanned 5,069 ticks and 61,909 ms. Frame
return intervals were median 12 ms, p95 18 ms, maximum 45 ms, with none over
100 ms. Production tick duration was median 2 ms, p95/max 3 ms. The complete
trace contained 9,061 paired ticks and an observed normal close. An earlier
three-tick empty automatic refresh is excluded from capture statistics.
[Machine-readable summary and witnesses](../benchmarks/results/native-trace-summary.json)
identify the source, binaries and retained raw trace hash.

Accessibility and screenshot requests still timed out at about five seconds
during this interval. The trace rules out a continuous callback freeze in this
instrumented run. It does not identify the automation timeout's cause, establish
input-arrival or pixel-display timing, or measure uninstrumented performance.
Each traced tick adds two file writes, three clock reads and formatting work;
`writer_present` means a pending GUI job, not a direct OS child-process sample.

The harness requires an explicit absolute data directory, logs query text only
with `--trace-query`, and stops logging after 12,000 paired ticks while the app
continues. These bounds and callback reuse were source-reviewed. Native build,
missing/relative-directory rejection and real CLI worker dispatch passed.
The 12,000-tick cutoff was not reached in this run.

Build with `./scripts/build benchmarks/native_trace.bend build/juice-bend-native-trace`.
Launch `build/juice-bend-native-trace --trace-ui --data-dir /absolute/isolated-dir`
from an unlocked desktop terminal, or use a coordinated Tart guest. Trace files
are private under a fresh `native-trace.XXXXXX` directory in that root.
Add `--trace-query` only for explicitly synthetic input. Raw traces remain
local; the public summary includes only synthetic input and timing witnesses.

## Reproduce remaining checks

Run `mise run build`, then `./scripts/run --demo` in an unlocked desktop
session. Verify physical Command/Shift selection, Unicode paste/commit and
IME. Use Settings with a synthetic benchmark JSONL, then type and scroll
while capture is active; record actual input/frame timestamps and UI CPU/RSS.
Pause must stop new automatic work while an in-flight capture finishes safely.

To reproduce the observed empty state, launch `build/juice-bend --data-dir`
with a new private temporary directory and no `--demo`. No provider scan or network
request should occur. The restricted shell has no display access; use a
desktop terminal or the local `.app`.
