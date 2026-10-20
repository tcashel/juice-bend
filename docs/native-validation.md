# Native interaction observations

2026-10-20, macOS 27.0.1 arm64, actual desktop windows through the pinned
Bend runtime. Only synthetic libraries were used. These are observed
interactions, not automated latency or complete accessibility acceptance.

The last desktop-observed native executable is 4,619,552 bytes, SHA-256
`4ad55c63cb542b68740e032f05ff528c25c3ce7250a6f07c1bfbd0d3f25f5d49`.
It is preserved locally as `build/juice-bend-next` and in `build/Juice Bend.app`.
The subsequent storage-hardening build is identified in `progress.md` and
CLI-tested separately. It has not been observed on the locked desktop.
The main validation library is `/private/tmp/juice-bend-native-validation`.

## Observed workflow

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

During the large capture, several native accessibility/action calls timed out
after about five seconds. A later screenshot showed the typed query and
completed results; that does not establish when input became visible.
Similar tool timeouts occurred around a small rebuild. Whether this is target
selection around same-executable workers or a real event-loop stall remains
unresolved. A20 and input latency p95 are not accepted.

The final empty-library launch attempt was blocked because the native
automation tool reported that the Mac was locked and could not unlock it.
No OS setting or permission was changed. Empty-library native acceptance
remains pending until a fresh desktop launch is observed.

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
hypothesis. A future unlocked-desktop diagnostic should retain the known
GUI PID/window identity before capture and compare a short sample of that
exact process with visible input while its child remains active. Tool
round-trip time is not input/frame latency. No application semantics were
changed by this audit, and A20 remains unaccepted.

## Reproduce remaining checks

Run `mise run build`, then `./scripts/run --demo` in an unlocked desktop
session. Verify physical Command/Shift selection, Unicode paste/commit and
IME. Use Settings with a synthetic benchmark JSONL, then type and scroll
while capture is active; record actual input/frame timestamps and UI CPU/RSS.
Pause must stop new automatic work while an in-flight capture finishes safely.

For the empty-state check, launch `build/juice-bend --data-dir` with a new
private temporary directory and no `--demo`. No provider scan or network
request should occur. The restricted shell has no display access; use a
desktop terminal or the local `.app`.
