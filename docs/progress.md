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

Typed transcript cards are adopted from the exact 34-path reader delta. The
adoption receipt `build/reader-cards-root-adoption/receipt.json` (5fa82898…)
checks all 178 application inputs against tested executable
`c51b15927d5ee2ce1d4a32aaa61be6c27dd3cc27f8b032dea314a64992d77867`.
The protected index remains 309b1cdb….

That executable is promoted to `build/juice-bend`, `build/juice-bend-reader` and
new `build/Juice Bend Reader Cards.app`. Previous 1b6fd binaries are backed up in
`build/reader-cards-root-adoption/executables-before`; the UI Foundation and
Workspace bundles remain unchanged. `mise run demo` opens the tested default
with a fresh synthetic library.

The shared Canvas, Label and Region foundation remains used by the app and
standalone controls example. Its API is in `src/bend_ui/README.md`. No standalone
package or first-party license has been released. Proportional prose and Usage
are separate candidates awaiting a full combined Mac build/native run.

## Current validation

- Reader cards: native run-03 passed 13 exact clipboard comparisons, one canonical
  export, mouse and 24 native key pairs, selection reset/restoration, paging and
  filtered original references, plaintext fallback, source-loss/different-PID
  restart and ready Close. Root inspected 15 window/display images. Guest and all
  cleanup steps exited 0; wrapper exited 143, recorded stopped VM, and final
  collection occurred after shutdown. `receipts/reader-cards-native.json`
  (c5e32472…) binds the run; `reader-cards-build-tests.json` binds 461 assertions
  across 11 distinct entries plus the successful Mac build. Pending Close and
  the later proportional prose are not covered by this reader acceptance.
- UI foundation: component/focus/label/History checks passed with individually
  scoped results in `receipts/bend-ui-build-tests.json`. The native standalone
  example passed 12 visible states, 133,860 pixel checks, mouse/keyboard focus,
  disabled controls, Escape and Close (`bend-ui-controls-native.json`).
- Exact full app 1b6fd passed all 13 native journey/cleanup steps in fresh
  `build/ui-kit-native-plan/run-jpeg-02`: History, 223 image samples in 15 views,
  four exact exports, Unicode copies, pending Escape/Back, source-loss restart
  and ready Close. Root inspected 13 actual screenshots. Guest exited 0; owned
  wrapper exited 143, VM stopped and lease released before the next run.
  `receipts/bend-ui-app-native.json` (d909efe5…) binds 1,001 final artifacts.
  The prior ENOSPC interruption remains preserved as a failed run.

Earlier History-source baseline evidence remains separately scoped:

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

1. History/pacing, font assets/notices, demo alias and three current receipts
   published as e4a7f0b51fb00817062c92312a8e43d7be34e520 on parent3c92452a….
   Exact36-path tree d9e816db… is retained in `build/publication.git`.
   PR1 body/head were verified at this commit; it remains draft/open and unmerged.
   Root index must remain309b1cdb9f1c2ba41c8f82ca21354d45d42f6ef2b3b01b8f9bb560b380a17b71.
2. Community UI extraction is at `build/ui-kit-integration`:16 paths,
   pure Canvas/Label/Region,199 native assertions and exact History raster.
   Native example run01 exposed a2048-canvas/window scaling defect; its failed
   receipt50d93abd… is preserved. The four-file checked viewport correction in
   `build/ui-kit-viewport-fix` passed17 Mac assertions, including221184 actual
   submitted-frame pixel comparisons. Native run02 then passed all12 visible
   states and133860 exact samples, real keyboard/mouse/disabled-control behavior,
   Escape and native Close. Root inspected five full screenshots. Guest0,
   ownedwrapper143, VMstopped/leaseabsent;162 final artifacts remain bound.
   `docs/receipts/bend-ui-controls-native.json` (454c6da1…) records scope.
   Full extracted-app Mac build passed:172 inputs/96 pins, binary1b6fd416…ad672,
   `build/ui-kit-app-integration/runs/2eaed666-4582-4e5d-a77e-55bf17611982`.
   `docs/receipts/bend-ui-build-tests.json` (d34c905e…) binds individual gates.
   Full-app native run `build/ui-kit-native-plan/run-jpeg-01` failed during
   restart when host shared-result writes hit ENOSPC. Prepare, History, JPEG,
   pending Escape/Back and variants each exited 0, but no overall pass is claimed.
   `terminal-failure.json` preserves the pre-recovery artifacts and original
   guest exit 1. Scoped recovery cleanup and display restoration exited 0;
   owned wrapper 15449 exited 143, VM stopped, lease released. No process remains.
   Fresh `run-jpeg-02` passed after the Mac compiler completed. Exact kit source
   and executable are now adopted above; earlier binaries and failure evidence
   remain preserved. The explicit 24-path publication is
   `ba8f3c9df633d73d37b9552ff103b8c32b6f65b7`, on parent e4a7f0b5….
   `build/ui-kit-publication/metadata.json` records its tree/content hashes and
   non-force ref update; `pr-verified.json` records the published PR state.
3. Typed reader foundation in `build/reader-cards-integration`: formatter24 and
   projection57 native Linux assertions passed, including exact canonical bytes,
   hidden-copy gaps, mandatory warnings and stale events. Seven-file
   FOUNDATION5319af69… is frozen. Real message/evidence card integration is now
   in NEW `build/reader-cards-ui-integration` on the tested kit base.
   Keep expensive admission off pointer events and preserve the canonical grid.
   Include the scoped two-label Why fix from `build/why-association-wording-integration`.
   Final seven-entry Linux batch 0c003aeb passed 336 assertions; exact collection
   9363d0e6 binds 187 inputs and absent owned processes. Mac run 0e51cd96 failed
   at 274 seconds with ENOSPC before C output; source/default unchanged, all
   owned processes absent. Failure receipt 13879e88 is preserved. A fresh retry
   passed at `build/reader-cards-ui-integration/mac-v2/6558cd4e-7000-4d37-9d66-130dafdc0510`: 888.274 seconds,
   binary c51b1592…77867; all 178 sources, 96 pins and owned-process absence
   were verified. Reader c51b is now adopted and promoted as described above;
   the prior UI-foundation executable 1b6fd416… remains preserved.
   Native oracle helper 7bba24bb passed its Mac build (binary 41a9ff71…4d61d7f);
   reader native run-01 (nonce 02498a2c…88a6) failed at Settings copy: the
   harness left the empty path input focused. Earlier mouse/keyboard disclosure
   checks reached exact expanded-page copy, but no overall native pass is claimed.
   Guest exit 1, cleanup/display restoration 0, owned wrapper 143 and recorded
   VM-stopped evidence are finalized in run-01/terminal-failure.json; all 190
   final artifacts are bound and the original failure remains preserved.
   Fresh run-02 exited 2 in preflight because the shared VM was active, before
   lease acquisition; no guest/app ran. Its preflight-failure.json preserves five
   artifacts. The corrected harness adds one Settings-body focus click and keeps
   Back copy without reselection. Fresh run-03 passed after the shared VM was
   released. Nonce68b804f6…c5c3, seald9f363c6…fa4c and native-result728c8904…
   bind the exact run. Root reviewed 15 actual images; guest0/wrapper143 and
   final artifact hashes are verified. `build/reader-cards-publication/prepare.py`
   prepares the explicit 40-path reader commit on published kit ba8f3c9d.
   Native commands remain in `build/reader-cards-native-plan/HANDOFF.md`.
   A separate four-path follow-up at `build/reader-cards-polish-integration`
   passed 28 focused assertions and two production-rendered frames (9742d042).
   Root inspected both: warmer user cards, green assistant cards and one 24px
   nonselectable event gap. Mac acceptance and adoption are still pending.
   Proportional MessageText is now a tested ten-path follow-up in
   `build/reader-prose-integration`: 123 distinct Linux assertions and two
   production-rendered frames passed. Root inspected both frames; independent
   source review found no app blocker. Cached scalar/pixel boundaries preserve
   exact copy; code/tools remain mono. No Mac window/input/performance pass yet.
   Handoff, overlay710f6629 and validation2e9f74a9 bind this candidate.
4. Library Usage core in `build/library-usage-integration`:50 native assertions
   plus2 fixture commands passed6dc2d9eb,131 inputs unchanged. Five new Bend files,
   exact alias/unknown/coverage and retained snapshot drilldown; not adopted.
   New presentation/controller seam passed65 native checks; actual Usage
   integration is proceeding in a separate candidate without shared UI mutations.
   All-time first; no session-start cohort misrepresented as activity-date usage.
   Actual integration remains isolated at `build/library-usage-ui-integration`.
   Backend gate ea80 passed wire 37 and capture-page 23 checks; worker-only
   960e12d2 then passed 112 assertions after correcting the positive fixture's
   source/session identity and adding a mismatched-identity regression. Earlier
   binder/definition-order and fixture failures remain preserved. UI actions
   a56361d5 passed 20 assertions and controller 53bc4436 passed 31, bringing the
   actual integration checks to 223. A v2 screen-row reuse passed all 31 controller
   checks. On agentbox, both exact reader and Usage full frontends hit the same
   16 GiB guard without diagnostics; no further Linux full-entry retry is queued.
   A reconciled Mac candidate on reader + tested card spacing is prepared;
   combined structured Usage-reader tests remain pending. No native Usage pass.
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

## Resource recovery

After the ENOSPC interruption, all owned Mac/VM processes were collected and
stopped. Six completed compiler diagnostics were losslessly compressed from
1,497,515,020 to 112,250,943 bytes with round-trip SHA-256 checks; original bytes
are recoverable using the manifest in `build/disk-recovery-diagnostics`.
The task's experimental LLVM files now hardlink identical mise-managed files;
all 9,929 regular files, modes and link targets were checked. No immediate APFS
space gain is attributed to that deduplication. Sources, receipts, current tools
and executable bytes are unchanged. Observed free space recovered to 12.3 GB.
Run full compilers and Tart sequentially until capacity is stable.
