# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains in progress. No user answer or approval is pending.
Application, UI, parsing, policy, tests and benchmarks remain Bend 2. SQLite's
narrow bridge is the maintained native-code exception. Lean is an optional
proof checker, not application code. Original Juice and histories are read-only;
all validation uses synthetic isolated data.

Update implementation branch and PR #1. The owner authorized a merge commit
retaining history and a fresh branch if useful on Oct22; no merge has occurred.
Preserve the dirty checkout and index. Publication uses explicit paths and a
separate index in `build/publication.git`, not blanket staging or reset.

Mise pins Bun1.4.2, Bend2.0.37 (`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`)
and repository-local LLVM23.1.4. LLVM compiles unchanged generated C at-O1,
resolving Apple clang's backend register error without an ABI/runtime override.

## Maintained source and executable

History navigation and static Inter typography are now adopted on top of
recorded-commit evidence, with settled image work using existing80ms GUI pacing.
All171 application inputs match the tested native executable
`981e84fd4f5a77f3e778cc98ee7d0aa65f276bb10dccd52b46fb51a96fa0c633`.
The28-path adoption receipt is `build/history-root-adoption/receipt.json`
(cb143dc8…). Existing index SHA309b1cdb… is preserved.

That executable is promoted to `build/juice-bend`, `build/juice-bend-reader` and
the new `build/Juice Bend Workspace.app`. Previous fcbbbfb… binaries are preserved
under `build/history-root-adoption/executables-before`; old app bundles remain.
`mise run demo` opens the existing build with a fresh synthetic library, avoiding
a second compile. `mise run run -- --demo` still rebuilds first. The demo wrapper
passed shell syntax and argument refusal; its new alias is not a separate GUI
acceptance run. Both native journeys below used the exact promoted binary.

## Current validation

- Combined History/geometry/painter checks:429 PASS lines across five entries,
  with overlapping imported assertions explicitly identified. Earlier gui88 and
  gui_activity48 remain separately scoped. Full Mac build passed in886.702s.
  `docs/receipts/history-workspace-build-tests.json` binds source/compiler evidence.
- History/JPEG native: all13 journey/cleanup steps passed. Root inspected17 full
  screenshots;223 exact image samples, progressive/invalid chrome, exact Unicode
  copies and four0600 exports passed. Source loss and different-process restart
  preserve bytes/selection. One Escape and one Back were bracketed by the same
  active child; its late result never replaced the restored screen. Idle-window
  Close was observed within277ms, parent within454ms. Times include observation.
  `docs/receipts/history-workspace-jpeg-native.json` (6c36cca7…).
- External attachment/ATIF native: approved folder/capture, Fit/pan/copy, disable,
  source removal, different-process restart and exact0600 exports passed. All7595
  exact pixel samples,37 independent ATIF content checks and both official1.8
  schema checks passed. Root inspected eight full screenshots.
  `docs/receipts/history-workspace-external-native.json` (9411935d…).
- Both native guest drivers exited0; owned VM wrappers exited143 after explicit
  shutdown. The VM is stopped, lease released, candidate processes/windows gone,
  and display/dock restored. Final artifact sets bind1001JPEG and505external files.
- Recorded-commit Why:56 focused native Linux assertions, native Mac form/copy/
  export/source-loss/restart;3080-byte copy and three3251-byte0600 exports exact.
  `docs/receipts/recorded-commit-native.json`. Unique successful call/result evidence
  augments commit Why; ambiguous/failed/unsupported/missing evidence stays explicit.

Earlier broad evidence is historical:40 executables/2960 checks and12 production
laws checked with BendTT/Lean. Focused current checks are not a fresh full-suite
or proof pass. Earlier failed compiler/harness/display attempts remain preserved.

## Remaining validation limits

The34-check attachment lifecycle/pacing unit entry hit a12GiB frontend guard in
both original runs and a test-only table traversal retry. No assertion ran in
those attempts; all21 existing and13 new cases are preserved. No blind retry or
guard widening is queued. Actual native pending Escape/Back is covered above.
Scoped-reader frontend memory acceptance also remains unrun.

Actual pending Close remains defective: old production window39.984s; Base-only
forked-child reproducer9.660s despite prompt Close handling/App.run return. Both
five-second checks failed. All processes eventually exited. Inspected upstream
main has no compatible fix; no new native runtime patch is authorized.
`native-close-latency.json` and `native-close-discriminator.json` preserve this.

A correctly bracketed pending-admission sample put895/997 main observations in
Window.frame, including879 in Cocoa wait. Same-VM1/80ms probe timings were
12.618s/730frames and0.901s/8frames; all12 native assertions passed in each, but
an external observer missed the shorter window, so its aggregate harness remains
failed. `image-admission-cadence.json` and `image-admission-profile/` preserve scope.
The new full-app runs establish behavior, not a controlled performance comparison.

## Exact continuation

1. Complete explicit-path publication of the adopted History/pacing source,
   font assets/notices, demo alias and three current receipts; update draft PR1.
   Prior published parent3c92452a41c0ebac2ef54df7bd89c581e89cece0.
   Root index must remain309b1cdb9f1c2ba41c8f82ca21354d45d42f6ef2b3b01b8f9bb560b380a17b71.
2. Community UI extraction is isolated in `build/ui-kit-integration`: pure Canvas,
   Label and Region; duplicate-safe focus. Region48/Label15/example8 passed, and
   standalone Mac example compiled. Native Shift-code mismatch was then found
   and is being fixed/tested; use the corrected new binary for a compact native
   example run. History121 plus2 path-label checks and corrected example13 are
   running in Linux812e7c51. No kit adoption/native example claim yet.
3. Typed reader foundation in `build/reader-cards-integration`: formatter24 and
   projection57 native Linux assertions passed, including exact canonical bytes,
   hidden-copy gaps, mandatory warnings and stale events. Freeze the seven-file
   handoff then integrate actual message/evidence cards with the tested UI kit.
   Keep expensive admission off pointer events and preserve the canonical grid.
   Include the scoped two-label Why fix from `build/why-association-wording-integration`.
4. Library Usage core in `build/library-usage-integration`:50 native assertions
   plus2 fixture commands passed6dc2d9eb,131 inputs unchanged. Five new Bend files,
   exact alias/unknown/coverage and retained snapshot drilldown; not adopted.
   New presentation/controller seam is proceeding without shared UI mutations.
   All-time first; no session-start cohort misrepresented as activity-date usage.
5. Child-result navigation remains at `build/result-link-ui-integration`.
   Continue actual user-visible integration; do not finish at pure foundations.

## UI direction and parity

The owner's actual Swift screenshots ground polish: green persistent navigation,
yellow selection, clear proportional hierarchy, spacious session rows, readable
message/code groups, collapsible evidence details and useful usage charts.
Never publish those private reference screenshots. The native History shell is
observed; the dense mono transcript, missing glyphs and broader UX still need work.

The owner wants a community UI framework. Extract components through actual Juice
screens with no database/provider dependency, standalone examples and tests.
No first-party repository license was found; no license was silently chosen.
A standalone release needs that choice. Components alone do not supply missing
native shaping, IME, accessibility or resize facilities.

Remaining journeys are in `build/parity-gap-audit/GAPS.md`: library Usage/pricing,
alias/provider presentation, installed quota clients, per-window history,
read-only agent Connect/MCP, multi-source Briefs, deliberate excluded-content
removal and formatted reading. Broader image formats and input latency remain.

Owner accepted tens-of-seconds imports; marginal append tuning is deferred.
Physical-Mac100k: import36.194s, unchanged3.910s, append16records23.816s;
search/late/scoped-late p95=42/7/17ms. Separate archive100k capture139.055s and
retained verify/read/search/dual-export44.475s are different workloads. Swift
comparisons require equivalent work on the same host; none is claimed here.
