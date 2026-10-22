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
and repository-local LLVM23.1.4. LLVM compiled unchanged generated C at-O1,
resolving Apple clang's backend register error without an ABI/runtime override.

## Current maintained source and executable

Published parent: `18cbc41e69201a05e0823994a615ab09c4c6cbf9`, reader polish on
the retained capture/PNG/JPEG/ATIF/discovery slice. PR #1 was verified open/draft.
This update adopts 15 recorded-commit evidence files: eight Bend modules, six
tests and the existing file-evidence hook. Exact preimages and preserved index
are in `build/root-recorded-commit-adoption/receipt.json` (35a208a8…).
Unique successful call/result evidence now augments commit Why; ambiguous,
incomplete, failed, unsupported and missing-object cases remain explicit.

The accepted default `build/juice-bend` and reader executable remain
`fcbbbfbde90ad072c26fb20ab044522487a6ee4bbe9890f72300765a18518701`.
`mise run run -- --demo` uses an isolated demo. This old default is preserved
until the combined native candidate passes; do not confuse it with latest source.

## Current validation

- Reader polish: 364 focused native Linux checks, full maintained Mac build
  `5d67eba5…` in876.669s. Scoped-reader frontend memory limit remains unrun.
  `docs/receipts/reader-polish-build-tests.json`.
- Current external attachment workflow passed: approved folder/capture, copy,
  Fit/pan, disable, original removal, different-process restart, exact exports,
  complete ATIF. All7595 exact pixel samples,37 independent ATIF content checks
  and both official-v1.8 schema validations passed. Cleanup/display restored.
  `docs/receipts/polished-external-native.json`.
- Matching current JPEG workflow passed:14 views,193 exact pixel samples,
  progressive/invalid chrome checks, three distinct exact0600 JPEG exports and
  one PNG export, original loss/restart and exact selection restoration.
  `docs/receipts/polished-jpeg-native.json` (53b024e1…). This is not a pending-Close
  or performance acceptance result.
- Recorded-commit Why:56 focused native Linux assertions, full Mac build
  `f1713174…` in907.098s, then actual native form/copy/export/source-loss/restart.
  Eleven journey/cleanup/display steps passed;3080-byte Unicode copy and three
  distinct3251-byte0600 exports matched exactly; all four retained records were
  independently verified. Root inspected nine full-display screenshots.
  `docs/receipts/recorded-commit-native.json` (657c6b66…). Native negative fixtures
  are not covered by this positive GUI journey. The old generic “not indexed”
  trailer/body summary is misleading above successful command evidence and needs
  a scoped label in the next reader pass.

Earlier broad evidence is historical:40 executables/2960 checks and12 production
laws checked with BendTT/Lean. Focused current checks are not a fresh full-suite
or proof pass. Earlier harness/display failures remain preserved in their
receipts and ignored run folders; corrected runs never relabel them as passed.

## Image admission and Close

A correctly bracketed pending-admission sample put895/997 main-thread observations
inside Window.frame, including879 in Cocoa run-loop wait. The sanitized flame
graph and scope are in `docs/receipts/image-admission-profile/`.

Same-VM1/80ms pacing probe:12.618s/730frames versus0.901s/8frames, with all12 native
pixel/lifecycle assertions passing in each case and unchanged Stream128. The
external observer missed the shorter window, so the overall harness remains
failed. `docs/receipts/image-admission-cadence.json` (4e786e8a…) preserves that
limit and the prior visible-frame invariant failure. Both owned processes/windows
are absent, VM stopped, wrapper143. This supports a full-app candidate test, not
an already-shipped performance claim.

Actual pending Close remains defective: old production window39.984s; Base-only
forked-child reproducer9.660s despite prompt Close handling/App.run return. Both
five-second checks failed. All owned processes eventually exited. Inspected
upstream main has no compatible fix; no new native runtime patch is authorized.
See `docs/receipts/native-close-latency.json` and `native-close-discriminator.json`.

## Exact continuation

1. Root owns full combined Mac build session57365, run
   `build/history-workspace-integration/mac/1f05893d-93f0-47d3-8b22-861e19613620`.
   Candidate combines Swift-grounded History navigation/static Inter typography,
   recorded-commit evidence and the two-line pacing change. Source is frozen;
   root-added17-path manifest is `root-added-slices.json` (28d4fa7a…). Collect
   terminal build before binding the native payload. It has not run native UI.
2. UI agent finishes focused History/geometry/painter checks plus34 preview-app
   pacing assertions on Linux. Existing `tests/gui.bend`88 and
   `tests/gui_activity.bend`48 checks passed; preserve their corrected
   `session-usage|7` expectations. These two local corrections are not yet in
   the published parent. Do not restore stale expectations.
3. Attachment agent prepares native controls/payloads for the combined app:
   History/filter/search/copy, retained image Open and pending navigation/Back,
   exact pixels/export/restart. Reuse independently versioned fixture helpers
   only when their actual exercised data/protocol is compatible; bind all actual
   binaries. Root owns VM execution and screenshot review. No VM is running now.
4. After focused/native acceptance, adopt only reviewed History and pacing
   deltas, publish a coherent commit, update PR #1 and promote a verified default
   executable with the old one preserved. No automatic merge is required.
5. Independent ongoing slices: All-time library Usage/provider drilldown in
   `build/library-usage-integration`; reusable pure Bend Canvas/Label/Region in
   `build/ui-kit-integration`. Neither is adopted or accepted yet. Child-result
   navigation remains at `build/result-link-ui-integration`.

## UI direction and remaining parity

The owner's actual Swift screenshots ground polish: green persistent navigation,
yellow selection, clear proportional hierarchy, spacious session rows, readable
message/code groups, collapsible evidence details and useful usage charts.
Never publish those private reference screenshots. The new History preview is
synthetic Linux rendering, not Mac acceptance or completed visual parity.

The owner wants the emerging UI layer to benefit the community. Build reusable
components through actual Juice screens, with no database/provider dependency,
a small standalone example and focused tests. First-party licensing must be
settled before a standalone release; no repository-wide license was silently
chosen. A component library cannot supply missing native shaping/a11y/resizing
facilities by itself.

Remaining journeys are tracked in `build/parity-gap-audit/GAPS.md` against the
read-only Swift reference, with completed image/ATIF/discovery/G15 work accounted
for above. Library usage/pricing, aliases/provider presentation, installed quota
clients, per-window history, read-only agent Connect/MCP, multi-source Briefs,
deliberate excluded-content removal and formatted reading remain. Missing glyphs,
IME/accessibility, resizing/input latency and broader image formats remain open.

Owner accepted tens-of-seconds imports; marginal append tuning is deferred.
Physical-Mac100k: import36.194s, unchanged3.910s, append16records23.816s;
search/late/scoped-late p95=42/7/17ms. Separate archive100k capture139.055s and
retained verify/read/search/dual-export44.475s are different workloads. Any Swift
comparison must perform equivalent work on the same host; none is claimed here.
