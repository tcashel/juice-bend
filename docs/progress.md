# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains **in progress**. No user answer or approval is pending.
Application/UI/parser/policy stay Bend 2; the narrow SQLite bridge is 454 lines.
Lean is an optional development proof checker, never an app dependency.
Mise pins Bun 1.4.2 and Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`. Use synthetic isolated data only.
Original Juice/provider data remain read-only. Update the implementation branch
and draft PR #1; never merge. Preserve the protected checkout index and edits.
Publication uses explicit paths and a separate index in `build/publication.git`.

## Working executable and source

The accepted `build/juice-bend`, `build/juice-bend-reader` and
`build/Juice Bend Reader.app` remain SHA256 `fcbbbfbde90ad072c26fb20ab044522487a6ee4bbe9890f72300765a18518701`.
`mise run run -- --demo` opens an isolated demo. Its native reader journey passed
cross-wrap copy, paging/wheel movement, inert entry and exact Back restoration.
See `docs/receipts/native-validation-followup.txt`; native result `c61781c0…`.
The 97-assertion production replay is adopted. Earlier executables and failed
input-delivery experiments remain preserved; no runtime patch was made.

Maintained source includes reviewed reader/Connections/archive/worker changes,
the recorded-title backend (650 Linux checks and 49 Mac checks), worker equality
dispatch (55 Mac checks), and two literal dispatch rewrites (141 Mac checks).
Adoption manifests: `build/reader-attachments-adoption`,
`build/provider-title-adoption`, `build/worker-dispatch-adoption` and
`build/literal-dispatch-adoption`. Later source changes are not automatically in
the accepted executable. Combined capture/PNG/ATIF/discovery remains isolated;
its full app does not include title-v5 yet.

Latest verified published head before this follow-up: `e0b69acd28a89631f0c21f72368ae8e223cd36dc`,
tree `0131ae566909ca163f36628d85f8190cab5603af`, open/draft/unmerged.
Remote object: `build/worker-dispatch-remote.json`; bare ref
`codex/published-worker-dispatch`. Do not reset the protected checkout to it.

## Current native result

The full combined app now builds. Long literal-pattern expansion was reduced
using Bend equality dispatch. A typed observation then located one 260-slot
continuation against the pinned 247-slot limit: UI.event returns 29 slots while
retaining Gui (97) and pending preview (134). Final Bend wrapper `8f7894fc…`
boxes pending **before UI.event**, restoring it afterward without changing
schemas, channels or bookmarks. Eight actual A.event Mac checks passed. The
earlier box around Gui.event was too late and remains a failed experiment.
No compiler/runtime limit changed.

Normal frontend `92de6110` passed in 157.615s. Same C `a46e9a6a…` compiled at
native -O0 in 351.906s (`42930ca1`), producing `e0be4e4b…` (268,058,776 bytes).
All 143 app files and 93 pins stayed unchanged. Apple clang 21 -O3 and -O1 both
failed with `live register clobbered by inserted prologue instructions`; exact
reproducers and the earlier missing-SDK failure remain preserved. These are
build results, not performance acceptance. Matching helper `787b104d` passed
-O3, prepare/guard/no-clobber; all 70 shared paths match. Build chain:
`build/preview-input-box-integration/native-build-binding.json`.

**Actual integrated Tart v4 failed.** Run `build/integrated-assets-native-v4-run`,
nonce `35c2b432-a95a-427c-b3e0-00c539980347`: actual GUI folder add/select and
exact PNG capture (6,555 bytes, SHA `2fadba06…`) passed with original occurrence
and policy revision. All 12 image checks remained on “Opening verified retained
image” across about 16 seconds. Normal close timed out while the app remained
alive. Source deletion, restart, retained exports and ATIF were **not run**.
The app later exited; recovery verified no app/window and saved the guarded
unchanged synthetic fixture. Original failed receipts remain intact. Owned
wrapper ended 143 after stopping only its own Tart child; VM stopped and lease
released. Root inspected five screenshots. Result SHA `4efe0a3a…`, full record
`native-result.json` in that run. A macOS Tips overlay and missing CJK/emoji glyphs
remain visual limitations.

Source shows pure PNG decoding on the parent UI path after bytes arrive. This
is a plausible cause of the pending/close delay; no live sample was obtained
before exit, so the exact cause is not proven.

## Exact continuation

1. Same-C optimized diagnostic `669b85cf` (session 80312) ended with the same
   clang error after 216.638s, without timeout. Disabling shrink wrapping did
   not fix it; receipt `6f4ac57a…`, sources/C/pins unchanged, processes absent.
   Mac compiler is released. Investigate a concrete upstream compiler fix;
   do not repeat blind flag changes or promote an untested binary.
2. Build the full app with supervised PNG/JPEG decode and exact startup routes.
   `build/jpeg-wrapper-integration/HANDOFF.md` binds 31 files and 21 native Linux
   wrapper checks, preserving its initial compile timeout and successful same-C
   retry. Child decode and bounded parent raster admission replace UI-path
   decoding. Cancellation retains channel ownership until drain. JPEG owner is
   assembling against exact final 143-file source; no title/G15/polish overlay.
3. Run actual capture/retained preview/export/ATIF and prepared JPEG cancellation/
   restart journeys. `build/jpeg-native-plan/HANDOFF.md` requires final app/helper
   receipts, control binding and observed child lifecycle. Cancellation checks
   remain read-only until child exit so clipboard cannot mask ignored Escape/Back.
4. Reconcile root preimages before adoption, rebuild with title-v5 and run affected
   tests. Never blindly apply candidate-relative patches over root. Keep PR #1
   current with failed and unrun scopes. Default executable stays unchanged.

## Other slices and evidence

- Worker/storage/capture checks include 120 finite path-race observations and
  16 actual Capture.run composition assertions. Streaming publication includes
  30 abrupt interruptions. Standalone PNG passed 175 Mac checks and 21 actual
  Tart checks/70,253 pixel samples; this is not combined-app acceptance.
- ATIF core passed 69 Mac checks; CLI/UI passed 204 Linux checks; six actual
  exports passed official v1.8 schema. Actual combined ATIF UI remains pending.
- Resumable discovery passed 169 Mac checks, then 145 affected checks including
  Unicode-child starvation. Six-file handoff is in the combined candidate;
  full-app refresh interaction and aliases remain open.
- JPEG decoder/transport passed scoped tests for real source-deleted captures,
  exact receipt binding, incremental hashing/array assembly and cooperative
  yields. Async wrapper passed 21 Linux checks. Progressive and other JPEG/PNG
  formats remain unfinished; no broad format or actual UI acceptance.
- Recorded successful-commit evidence: 15-file handoff at
  `build/recorded-commit-integration/HANDOFF.md`, 106 Linux checks including real
  Git, retained Claude/Codex records, source loss and bounded/path uncertainty.
  Mac app/Why acceptance pending.
- Child-result navigation is isolated in `build/result-link-ui-integration`.
  Worker/protocol checks passed; actual GUI/CLI gates remain in progress.
- `build/reader-hierarchy-candidate` prepares shorter reader headings with exact
  metadata retained in details. Not compiled or visually validated; no accepted
  presentation/oracle replaced.

## Remaining goal and measured limits

`build/parity-gap-audit/GAPS.md` records 18 journeys against read-only Juice
`829ff9b5…`. Remaining work includes aliases, provider presentation, installed
quota clients, per-window history, read-only agent Connect/MCP, library usage/
pricing, multi-source Briefs, deliberate excluded-content removal and comfortable
formatted reading. Missing features are not excluded from the goal. CJK/emoji/
combining glyphs, shaping/IME, accessibility, resizing and measured input latency
remain open. Functional and visual parity both remain required.

Historical broad evidence: 40 executables/2,960 checks and 12 production laws
checked by BendTT/Lean. Focused checks do not replace a fresh complete suite.
Physical-Mac 100k: import 36.194s, unchanged 3.910s, append 16 records 23.816s;
search/late/scoped-late p95 = 42/7/17ms. Marginal tuning is deferred per owner.
Separate streaming-archive 100k: 26,936,113 logical / 7,654,948 compressed bytes
captured in 139.055s; retained verify/read/search/dual exports after source removal
took 44.475s combined. Different workloads; no Swift comparison. Future comparisons
must use equivalent work on the same host.
