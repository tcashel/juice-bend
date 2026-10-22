# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains in progress. No user answer or approval is pending. All
application logic, UI, parsing, policy, tests and benchmarks remain Bend 2.
SQLite's narrow bridge is the maintained native-code exception. Lean is an
optional development proof checker. Original Juice and histories are read-only;
validation uses synthetic isolated data.

Continue the implementation branch and draft PR #1; no merge has occurred.
Preserve the dirty checkout and index. Publication uses explicit paths and a
separate index in `build/publication.git`, never blanket staging or reset.
Mise pins Bun 1.4.2, Bend 2.0.37 at `60ca80aedeec9d8f0629b5f10dd19457d8ad67af`
and local LLVM 23.1.4. LLVM compiles unchanged generated C at -O1.

## Current executable and evidence

The exact 37-path Usage/prose delta is adopted. All 189 application inputs match
native executable `8d42430177b7ca2614c8eda393076bfe5ed5bbc5d2a3382ec6f119068675569c`.
The default `build/juice-bend`, `build/juice-bend-reader` and new
`build/Juice Bend Usage and Prose.app` contain that executable. `mise run demo`
opens the tested default with fresh synthetic data. Prior Reader Cards, UI
Foundation and Workspace bundles remain preserved, as do previous default binaries
in `build/library-usage-prose-root-adoption/executables-before`.

Message cards now use proportional, word-wrapped prose and warmer colors; code
and evidence retain monospace presentation. Shared cached text geometry controls
painting and selection. Library Usage provides all-time recorded totals,
explicit unknown coverage, provider filtering and retained-capture drill-down.
This is a functional textual report; the Swift-style chart dashboard remains open.
Reusable pure Bend Canvas, Label, Region and TextLine components are documented
in `src/bend_ui/README.md`. No separate package or first-party license is released.

- Full Mac build passed in 944.524s. All 189 source inputs, 96 pins and tools
  remained exact; owned processes exited. Build artifacts:
  `build/library-usage-ui-integration/mac-build-v2/8d6628bd-3cf0-4a68-a04a-95e0338d9f0b`.
- Combined focused Linux tests passed 156 assertions (47 controller, 20 actions,
  89 prose) plus two separate image writes. Earlier focused gates have their own
  source bindings and overlapping counts; they are not added into this total.
- Exact 8d424301 native Tart run passed prepare, interactions, source-loss restart,
  Library Usage, normal Close, cleanup and display restoration. It checked 32
  exact clipboard results, three summary contents, four forward/reverse prose
  drags, 24 native key pairs and three canonical private exports. Root reviewed
  11 actual window/display images. Ready Close was observed within 401ms for
  the parent and 561ms for the window; these are observation upper bounds.
- The original three snapshots survived a different-process restart. A fourth
  known-usage fixture was imported after that restart and its source removed;
  no second restart is claimed for the fourth snapshot. Missing combining/CJK/
  emoji glyphs remain visible boxes while original copied bytes stay exact.
- Guest/cleanup exited 0. The exact owned wrapper exited 143 after shutdown;
  VM stopped, lease released and 332 final artifacts were collected. Plan:
  `build/library-usage-native-addendum-v1`; run `run-01`, nonce
  `5202c832-44ce-42ab-8987-429fd8cf3430`.

Public evidence: `docs/receipts/library-usage-prose-build-tests.json` (43ab5a43…)
and `library-usage-prose-native.json` (bdba3b02…). Adoption receipt
`build/library-usage-prose-root-adoption/receipt.json` (9715ab82…) and executable
promotion receipt (f21eb9c9…) bind the root result. Exact inventory is
`build/library-usage-ui-integration/mac-candidate-v2/ADOPTION-INVENTORY-v2.json`
(6665f0a9…). Protected index remains
`309b1cdb9f1c2ba41c8f82ca21354d45d42f6ef2b3b01b8f9bb560b380a17b71`.

Earlier reader, UI foundation, History/JPEG, external attachment/ATIF and Why
native results remain separately scoped in `docs/acceptance.md` and their
receipts. Historical broad evidence is 40 executables/2960 checks and 12
production laws checked with BendTT/Lean. Current focused checks are not a fresh
full-suite or proof pass. Earlier compiler/harness/display failures are retained.

## Remaining defects and validation

- Inherited toolbar overlap: `tests/polish.bend` passed 35 assertions then failed
  “capture hint gap is inert” at (744,88). The broad fourth action rectangle
  overlaps the painted capture hint. Keep the assertion; repair painting and hit
  geometry together. The current native journey does not cover this coordinate.
- Pending Close remains defective: earlier production window 39.984s, Base-only
  forked-child reproducer 9.660s despite prompt App.run return. Both five-second
  checks failed. All processes eventually exited. Ready Close is separate.
- The 34-check attachment lifecycle/pacing entry remains unrun after three
  frontend memory-guard attempts; all 21 existing and 13 new cases remain intact.
  Scoped-reader frontend memory acceptance is also unrun. No blind retry or
  widened guard is queued. Native pending Escape/Back has earlier passing evidence.
- Missing glyphs, full shaping/IME, accessibility, resize and input-latency
  acceptance remain open. Date/cost Usage, charts, aliases, installed quota clients,
  Connect/MCP, multi-source Briefs, deliberate excluded-content removal and child
  results remain in the broader parity work. See `docs/parity.md`.
- Physical-Mac 100k import 36.194s, unchanged 3.910s and 16-record append 23.816s
  are historical observations. Search/late/scoped p95 were 42/7/17ms. The owner
  accepts import taking seconds; marginal append remains slow. No Swift speed
  comparison is claimed. Any comparison must use equivalent work on one host.

## Exact continuation

1. Publish the adopted 37 paths plus README, progress/parity/acceptance and two
   receipts, using explicit-path tree preparation in a separate index. Verified
   parent is reader commit `242475d173610af61f89d1f4ecee9a6de9c986b4`, on
   `ba8f3c9df633d73d37b9552ff103b8c32b6f65b7`. Keep PR #1 draft/unmerged.
   Record resulting commit/ref receipts under `build/library-usage-prose-publication`.
2. Repair toolbar geometry in isolated `build/toolbar-geometry-integration`.
   Preserve all 113 polish assertions, align painter and hits in every mode,
   and adjust future native click coordinates where the button genuinely moves.
3. Child-results candidate is `build/child-results-current-integration`, based
   on current Usage/prose. Backend 51, worker 31, route 6 and prose 89 assertions
   passed in separately bound runs. Its 24 GUI assertions remain unrun after a
   guarded frontend failure. A test-only boxed-state fixture/split is being
   prepared; production inputs and earlier failures remain intact. Require exact
   combined Mac/native validation before adoption.
4. Image-file transport candidate is `build/attachment-spool-integration`:
   13-file patch `3d7938df…`, 141 assertions passed, including supervised PNG,
   JPEG and retained-image workers. Private nonce-bound spool, bounded parent
   parsing and cleanup replace large stdout payloads. See HANDOFF.md and
   TRANSPORT.md for exact bindings and limits. It is not adopted or native-UI
   accepted, and does not alone fix pending Close. Reconcile with current sources
   before any combined app build. Pure decode and worker lifetime remain work.
5. No Mac compiler or Tart is running at this checkpoint. Host disk hit ENOSPC
   during evidence collection; completed artifacts are retained. Recover only
   scoped, losslessly verified generated artifacts before another Mac build.
   Run full Mac compilation and Tart sequentially. Do not alter other projects,
   original Juice, unrelated VMs or private data.
