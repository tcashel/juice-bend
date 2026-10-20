# Native interaction observations

## Parity candidate — catalog and storage

The native candidate SHA-256
`98283d91b51229f90eaacb90888466b91ea5ec3570ea96860ac5976ba431decd`
(5,917,312 bytes) ran in the dedicated macOS 27.0 arm64 Tart guest with host-only
networking. All 32 application/build input hashes matched before and after
build. The separate Bend fixture generated 206 sources, 306 accepted captures,
306 current search events and 101 saved versions through production capture.

Observed window interactions: History pages 1–100, 101–200 and 201–206; Search
through 301–306; saved captures through 101–101; selecting capture 206;
explicitly returning to latest capture 306; transcript page beginning at record
80. List paging retained the existing reader snapshot. Codex scope showed no
results and retained the reader; Claude reset the result page. Storage displayed
the owned counts, refused transcript export while showing inventory, and
returned to the selected source. After moving this run's original synthetic
source away, Open latest and bounded evidence export still succeeded.
The export was inspected as a 5,774-byte mode-0600 Markdown file containing
the retained Unicode and snapshot descriptor. A subsequent Bend-generated
append accepted capture 307 while the window stayed pinned to 306; clicking
Open latest then explicitly loaded 307. Native Command+Q closed the test
window. Final SQLite quick_check was `ok`, with 307 accepted captures and 307
current search events; no foreign-key violations were returned. The owned Tart
runner stopped its child and verified the VM stopped before releasing its lease.

Native keyboard checks used the guest's existing input tools: ASCII `caf`,
Option+E followed by E produced exact UTF-8 `café`; Command+A/C/V preserved
`café 中文 🙂`; replacement yielded `keyboard-ok`; Shift+Left twice selected
exact `ok`. Transcript copy also preserved Unicode. This observes one native
dead-key composition path, not full IME, physical keyboard or font-shaping
coverage. Unsupported glyphs still render as boxes. No input-to-display latency
or scroll-frequency measurement is claimed for this run; host tests overlapped.

Raw synthetic screenshots, clipboard bytes and orchestration records are under
ignored `build/tart/catalog.U5y5pY/artifacts`. The earlier observations below
remain tied to their own executable identities.

## Earlier core workflow observations

2026-10-20. Native windows used the pinned Bend runtime on the host desktop
(macOS 27.0.1 arm64) and a coordinated Tart guest (macOS 27.0 arm64,
Tart 2.40.1). All libraries and sources were synthetic. These are observed
interactions, not input-to-photon or complete accessibility acceptance.

The final guest-observed executable is 4,708,120 bytes, SHA-256
`05cdff4f599edcd16646fc3363e27c3856bda4b073f52a92f23264887ef5ba35`.
Earlier observations and timing measurements retain their separate build
identities below; they are not silently transferred to this executable.

## Final Tart workflow — 2026-10-20

The final executable ran in its own local bundle with a fresh isolated library.
Guest automation supplied explicit native modifier down/up events through
`cliclick`; clipboard contents were compared inside the guest.

| Interaction | Observed result |
|---|---|
| Fresh launch | Empty-library window opened before any source was enabled |
| Large capture | Settings captured 100,016 physical records into accepted snapshot 1: 35,607,307 bytes and 125,020 normalized events |
| Input during capture | `live-capture-ok` became visible and Pause worked while the capture was active; the in-flight capture subsequently completed |
| Source unavailable | The original synthetic JSONL was renamed away within the experiment's owned root; its configured path remained absent for retained reads and rebuild |
| Retained search and reader | Search, result opening, scrolling and drag selection worked from the owned library |
| Reader clipboard | Drag-selection copied the exact eight bytes `[assista` |
| Why and export | Why displayed retained evidence; export produced 11,796 bytes with mode 0600 and SHA-256 `2639d7ef4eed2580e813f355b73f9286faccd00190afecafc7d36885101ff0d2` |
| Verified rebuild | Settings displayed “Verified search rows rebuilt for Snapshot 1. Captured evidence remains retained.” while the source path was absent |
| Post-rebuild storage | Snapshot 1 remained accepted with 100,016 records and extent 35,607,307; events and FTS each held 125,020 rows, `preservation` had 75,012 hits, and `quick_check` returned `ok` |
| Command clipboard | Explicit Command+A/C/V preserved exact `café 中文 🙂` through the guest clipboard |
| Replacement and Shift | Keyboard replacement produced `keyboard-ok`; Shift+Arrow selection copied exact `ok` |

Direct Unicode keystroke injection through the automation tool produced
corrupted committed text (`cafa aa aa`). The exact Unicode clipboard roundtrip
therefore establishes paste/copy behavior, not correct direct Unicode typing.
Physical-keyboard input and IME remain unverified. Unsupported glyphs still
render as boxes while copy/export retain their underlying text.

The final GUI's `vmmap` physical footprint was 41.1M, with a 41.5M peak before
rebuild, and 46.2M with a 46.2M peak afterward. These are the GUI process's
reported physical-footprint values, not total worker memory or virtual size.
The owned GUI/workers were closed, the VM stopped, and the shared lease and
cleanup locks released after validation. Local screenshots and raw receipts
remain in the ignored `build/tart/native-c6dldcyb/session-artifacts` directory.

## Tart timing boundaries — intermediate builds

The 80 ms idle scheduler was measured on intermediate executable
`0a6243d583e3ebc4dcb0200e4d45b7a50b64c2bc85f27d5bffce3820894452f0`:
settled CPU was 1.55% of one core. Its GUI source hash matches the final
executable's GUI source, but this is not a final-binary CPU measurement.
The earlier 60 ms candidate measured 3.4%; the original settled loop measured
15.25%. The active input/dirty/pending-work path retains its 1 ms sleep.

The 60 ms executable
`6c5ee83b4a9326c210dac874079b953c901ffe5644a5bdebbd4bfb011128161a`
had a 1,308 ms observed startup upper bound that includes an intentional
one-second observation wait. This is not an exact startup-to-interactive
duration or a repeated-trial percentile. Input-to-photon latency and sustained
60 Hz scrolling have not been measured; neither is claimed by the visible
interaction results or callback traces.

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

## Historical unlocked follow-up — 2026-10-20

The 4,621,176-byte
`6a1287727e86e6d956dbfa7bf42bb6a1551d2fe064f110c805e14f6e8b85a32c`
production executable was observed on the unlocked host desktop using a new
private synthetic library. Settings displayed the isolated data root.

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
supplied callback timing evidence. The final Tart run above adds visible input
and resource observations; input-to-photon acceptance remains incomplete.

The desktop temporarily relocked, then the owner unlocked it for the diagnostic.
The owner did not complete the requested physical keyboard check; no physical
modifier or IME success is inferred. Both validation windows were subsequently
closed and the production bundle's ordinary launcher restored.

## Historical automation limits

Unsupported glyphs display boxes; backend tests and inspected exports preserve
the original Unicode. The UI tool's attempted committed text
`Unicode café 你好 🙂` stopped after the ASCII prefix. A separate input probe
also showed its `super+a`/`Meta_L+a` events carried ambiguous native key code
zero rather than the documented Command codes. Full Unicode commit, IME and
physical Command/Shift interaction were therefore unverified in those host
runs. The later Tart run supplied reliable explicit Command/Shift events and
exact Unicode clipboard comparisons; physical typing and IME remain unverified.
The app does not guess which modifier an ambiguous event represents.

Host-shell `pbpaste` comparisons did not observe the host desktop clipboard.
Those historical clipboard observations rely on the visible in-app roundtrip.
The final Tart clipboard comparisons ran inside the guest and succeeded.

During the earlier large capture, several native accessibility/action calls
timed out after about five seconds. A later screenshot showed the typed query and
completed results; that does not establish when input became visible.
Similar tool timeouts occurred around a small rebuild. The later callback trace
rules out a continuous callback freeze during its capture, while the cause of
automation timeouts remains unresolved. The later Tart observation establishes
visible input during capture; input-to-visible p95 remains unmeasured.

An earlier empty-library attempt was blocked by the locked desktop. The
unlocked follow-up subsequently observed that state on its identified build.
No OS setting or permission was changed in those host runs.

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
pixel-display timing remained unmeasured by this audit. The final Tart run
above separately records physical footprint and intermediate-build idle CPU.

## Bounded native callback trace — 2026-10-20

`benchmarks/native_trace.bend` wraps the production `Gui.view` and `Gui.tick`
callbacks without modifying them. Its 4,821,704-byte executable has SHA-256
`537145d12c3442e073fda1325e64dcf42e2cfdfdfff3da9fd8f89cb8a6585328`.
It ran in a separately identified local bundle against a fresh private library.
The then-current production executable's hash remained unchanged.

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

Build with `mise run build`, then launch `./scripts/run --demo` in an unlocked
desktop session or use the coordinated `mise run vm-session` workflow.
Remaining acceptance requires physical-keyboard/IME observations and actual
input-to-visible/scroll timestamps. Final-binary idle CPU and total active
worker memory remain separate from the intermediate-build idle and final GUI
footprint measurements above. Use only synthetic sources and isolated roots.

To reproduce the observed empty state, launch `build/juice-bend --data-dir`
with a new private temporary directory and no `--demo`. No provider scan or network
request should occur. The restricted shell has no display access; use a
desktop terminal or the local `.app`.
