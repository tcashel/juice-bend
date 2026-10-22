# Implementation checkpoint

The accepted default is `429410ee…` (207 inputs), with the shared Button adopted
after focused native acceptance. PR #1 remains draft and unmerged.

## Goal and boundaries

Continue functional and pleasant native UX parity with Swift Juice, excluding
embeddings/models. App logic, UI, policy, tests and benchmarks remain Bend 2;
SQLite has the narrow native bridge. Lean is a development proof checker.
Mise pins Bend 2.0.37, Bun 1.4.2 and LLVM 23.1.4. Original Juice and histories stay
read-only; fixtures and libraries are synthetic. No user response is pending.

`mise run demo` launches the accepted default. Preserve root HEAD/index and all
unrelated changes. Publish explicit paths through `build/publication.git`; keep
PR draft and unmerged. Prior sources/binaries remain preserved.

## Shared Button slice

Executable `429410ee…` binds 207 application inputs. The 12-path candidate adds a
pure Button painter shared by the real toolbar and controls example, with
rounded edges, clear disabled/focus styles and proportional labels. Existing
seven app targets/action IDs remain unchanged. The app still owns selection,
dispatch and focus; app toolbar keyboard focus is not added by this slice.
Bounds, label work and corner masks are fixed/bounded; cutouts preserve underlay.

Full Mac build passed through original pinned CLI/main plus the maintained
minimal GC512 preload, then LLVM -O1: frontend 264.105s/native 553.046s. Empty
diagnostics, exact inputs/pins and no owned compiler groups. This is the bound
maintained setup, not literal `scripts/build` execution or app-performance evidence.
Receipt: `build/button207-mac/runs/4742f192-5926-445f-a35c-ae62f1cf837d/receipt.json`
(1ae85506). Existing Linux gates passed 42 (Button 15/example 17/toolbar 10) and 103
(attachments 76/layout 27). Four necessary paint expectations changed; action and
bounds assertions remain. No fresh full suite or proof pass is claimed.

Native207 Usage passed 17 exact clipboard comparisons, 10 canonical reports and
one export, provider/capture/Back actions and source-loss restart. Root reviewed
seven representative images from 15 captured: rounded edges, underlay and labels
accepted, no new clipping; toolbar density remains. Receipt bb5785ef is in
`build/native207-staging/usage-summary/run-01/native-result.json`. PNG functional
checks passed 8 Fit/3 actual pixels, 72-byte export and Escape restoration; root
reviewed six images (receipt 24c5defc, review c3d86992). Strict combined JPEG/PNG and
worker-creation observation remain unaccepted. Earlier 206 results retain 4ff bindings.

Adoption receipt `build/native207-root-adoption/receipt.json` (2cc196ce)
verifies all 12 source/test paths, all 207 app inputs and three executable defaults.
Earlier sources/binaries are preserved under `build/native207-root-adoption/previous`;
root HEAD/index are unchanged. A component README count correction is docs-only.

The component API and example are an extraction prototype for community reuse.
No separate repository/package or first-party license has been published.
Hover/pressed lifecycle, accessibility, resizing and shaping/IME remain outside
this component. Sidebar and daily-Usage work are separate isolated candidates.

## Preserved prior evidence

The adopted 206 source/default receipt is `build/native206-root-adoption/receipt.json`
(808b2736); publication receipt is `build/native206-publication/receipt.json`.
The separately scoped Usage 17-copy/15-image, live-JPEG Close and functional-PNG
results are in `docs/receipts/native206-native.json`. Close was one observed
fixture, not a global bound; strict JPEG/PNG/worker-creation observation remains
unaccepted. The PNG generic-collector failure and additive collection are preserved.

Append remains slow. One same-physical-Mac pair measured import 45.304→42.028s,
append 16 records 28.252→26.535s and unchanged 4.405→5.570s at 100k records, with
matching bytes/IDs/seals. This was a modest single-pair result, not significance
or a Swift comparison. Focused component tests and crash-collector caveats stay
in `docs/receipts/native206-build-tests.json`; they are not rerun 207 claims.

## Exact continuation

1. Button207 is adopted; Usage/PNG run-01 terminal and visual results are collected,
   with VM stopped and lease released. Do not rerun the completed adoption runner.
2. For this or a future publication, refresh PR head/draft status and use only the
   explicit reviewed path/mode inventory, preserving root HEAD/index and unrelated
   work. Verify full app closure afterward. The sealed Button207 bundle is
   `build/native207-publication-terminal`; its 16 paths include one compact receipt
   and the component README wording correction. All modes are 100644.
3. Continue the isolated sidebar and daily-Usage candidates. Inspect their current
   receipts/process status before starting or restarting any build. Keep Tart and
   Mac compilation sequential; preserve the accepted 429410ee default until a
   replacement passes source binding, focused tests and native acceptance.
4. Ground the next layout slice in Swift Juice and actual Bend screenshots, then
   complete the bounded user journey before expanding component APIs.

Missing glyphs, dense metadata, wording, shaping/IME, accessibility, resize,
latency and broader parity remain open. No global Close guarantee, new proof,
global suite or complete-goal claim is made.
