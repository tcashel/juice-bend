# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains **in progress**. No user answer or approval is pending.
Application, UI, parsing, policy and tests remain Bend 2. SQLite's narrow bridge
is the native exception. Lean is an optional development proof checker only.
Use synthetic isolated data; original Juice and provider histories are read-only.
Update the implementation branch and draft PR #1; never merge. Preserve the
checkout index and edits. Publication uses explicit paths and a separate index
in `build/publication.git`.

Mise pins Bun 1.4.2, Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`, and repository-local LLVM 23.1.4.
Apple clang 21 failed optimized generated C with a backend register error.
Official LLVM 23 compiled the same C at -O1 with required ABI attributes intact.
Agentbox Clang 22 passed an ABI/cross-target probe; GCC lacks required
`preserve_most` support and was not forced. No Bend runtime/ABI override exists.

## Published and working source

Latest verified published head: `6caadb0fd1a4dfa0ba99f9c849460da60fb1c8ec`,
sanitized native evidence, tree `90dcc5bde3d491cf771f8ceb4707419faf55b7c2`.
PR #1 was verified open, draft and unmerged at this head. Publication record:
`build/native-image-evidence-publication.json`; exact remote object
`build/native-image-evidence-remote-commit.json`; bare ref `codex/published-image-evidence`.
Do not reset the protected checkout to it.

Combined capture/PNG/JPEG/ATIF/discovery and the JPEG DC shortcut are adopted in
maintained source, retaining title-v5. `build/root-image-adoption/receipt.json`
(`fbe7e24b…`) binds 129 paths. The separate corrected `tests/polish.bend` expects
ATIF at (16,568) and Archive at (120,568); application geometry is unchanged.
This feature slice is published on top of the LLVM commit. Exact manifest and
remote objects: `build/image-feature-publication.json` and
`build/image-feature-remote-commit.json`; bare ref `codex/published-images`.

The accepted `build/juice-bend`, `build/juice-bend-reader` and reader app remain
SHA256 `fcbbbfbde90ad072c26fb20ab044522487a6ee4bbe9890f72300765a18518701`.
`mise run run -- --demo` opens an isolated demo. Its prior native reader journey
passed wrap selection/copy, paging, wheel movement and exact Back restoration;
see `docs/receipts/native-validation-followup.txt`. Do not confuse that accepted
executable with later source or image candidates.

A fresh **maintained-wrapper build passed** in
`build/current-native/1dd7456a-c762-45ad-9385-163fb5c2f787`: 785.670s,
binary `455179e67f30104c6473446418fa1184d3a616239abe7b903171efc1856f5e8d`,
C `ca8abd542610ad6c5a4cd141ffd746f828313b34d53d6e10ac3c1d1a32757598`.
All 167 maintained inputs, 88 pinned Bend files, compiler and protected state
remained unchanged. Normal scripts/build, LLVM23 -O1, no compiler diagnostics;
stderr contains its expected Built line. This exact binary has **not run UI**.
`docs/receipts/current-image-build.json` records build-only scope.

## Current native evidence

The optimized image candidate `e6bf90ee…` predates the current title/DC overlay.
Its unchanged-C LLVM23 receipt is `docs/receipts/llvm23-native.json`.

**JPEG Tart v3: partial pass, preserved terminal failures.**
`build/jpeg-native-v3-plan/run-01`, nonce
`b261027d-3f7b-4bd7-a4ed-720b730858fc`, result SHA `2938e0c1…`.
Actual JPEG Fit/actual size/pan/clamps/reopen, pending Escape and Back with exact
restored selection, PNG viewing/export, readable unsupported/truncated errors,
and source-absent second-process restart with exact JPEG exports passed.
The close-during-pending step stopped before clicking because its ps executable
field was truncated. Cleanup termination briefly left a decoder child; later
read-only recovery found no owned app/child/window and recovered the unchanged
synthetic fixture. Display resolution restored, but visible-frame height shifted
three points; the original restoration failure remains recorded. VM stopped and
lease released. No native Close-during-pending pass is claimed.
Public scope: `docs/receipts/optimized-image-native.json`.

**External PNG/ATIF run: notification-contaminated pixel oracle.**
`build/external-async-native-v2-plan/run-01`, nonce
`cf9dd950-9816-4cef-83cb-697416375764`, result SHA `3f504d69…`.
Actual folder approval/Use/capture passed: exact 6,555 bytes, original immutable
occurrence and policy revision. The original fullscreen Fit oracle failed.
Root inspection found two macOS notification banners/shadows over the matte.
The contemporaneous owned-window screenshot passes all **1,085 exact pixel
samples** using the unchanged oracle geometry and zero tolerance. Decoder child
was present in only the first seven observations. This is not evidence of a
150-second render delay; the original fullscreen failure remains failed.
Later pan/source-loss/restart/export/ATIF stages were not run. Cleanup, fixture
verification/copy, payload integrity and display restoration passed.
Public scope: `docs/receipts/external-image-native.json`.

**Fresh external workflow passed.**
`build/external-notification-native-plan/run-01`, result `01b4c748…`, uses the
same optimized e6 app/helper with a new synthetic root and guarded banner dismissal.
Actual folder approval/capture, PNG Fit/actual size/pan/wheel/Back, GUI disable to
revision2, original removal, different-PID restart, retained display/Escape,
two exact 6,555-byte 0600 exports and full ATIF export passed. Seven pixel stages
checked 7,595 samples at zero tolerance. Official pinned ATIF 1.8 validation passed
16,310bytes/10steps, with 37 independent checks including hidden assistant records.
All guest/cleanup/fixture/display checks passed. Root inspected actual screens.
Wrapper13034 ended143 on requested stop; VM stopped and its lease was released.
`docs/receipts/external-image-native-followup.json` is the sanitized record.
A 3s parent sample accidentally preceded Open; it does not profile admission.
Observed child absence preceded first retained pixels by about 53s, so actual
parent admission/presentation remains a responsiveness concern, not a decoder claim.

**Native Close during decode failed its latency gate.**
`build/jpeg-native-close-plan/artifacts/close-observations.json` records the
same child around the real AX-guarded native Close click: child exit 36,778ms,
parent 39,781ms, window 39,984ms, no orphan. Parent/window exceed the original 5s
threshold. A shell AND-list mistakenly bypassed errexit when its first threshold
check failed; original guest exit0 remains preserved and is NOT acceptance.
Future harness uses independent required assertions. Cleanup/fixture/display
checks passed; optional post-close window screenshot returned 2. Root inspected
immediate/final screenshots. Wrapper23106 ended143 on requested stop; VM stopped,
lease released. `docs/receipts/native-close-latency.json` records the failure.
A small Bend App+fork/process close probe is being prepared to distinguish the
application from runtime scheduling; no runtime or native adapter patch is allowed.

Earlier integrated PNG v4 and unoptimized async JPEG v2 failures remain intact;
see their separate native-result receipts and `docs/receipts/async-image-native.txt`.
They are not overwritten by later compiler, component or pixel results.

## Focused tests and profiling

Current-root Linux regression plus corrected polish: **720 checks / 16 suites**.
Receipts `4ba9945d…` and `a57ea9ce…`; original stale-coordinate failure retained.
A bounded 12GiB rerun then passed capture UI38 and ATIF UI171 checks; those
entrypoints include imported checks and are not 209 additional unique laws.
Receipt `d27a26f2…`, run
`build/root-guarded-linux-regression/linux/41916e09-48a8-44d3-a968-4b08a667911d`.
All inputs/tools unchanged; no owned Linux process remains from those runs.
ATIF CLI and preview wrapper hit the Linux frontend memory guard. Their unchanged
Mac tests subsequently passed **11 + 21 assertions**, exit0/empty runtime stderr,
using the maintained LLVM wrapper; neither hit its 16GiB guard. Receipt
`c28da5e6…`, run `build/current-root-two-tests-mac/runs/89cef2d7-9f82-4c9d-9783-6f4b86c1ceb7`.
All155 inputs/96pins/2compiler binaries unchanged; owned processes absent.

Mac tests through the new maintained LLVM wrapper passed 71 DC/pixel checks;
logs are in `build/root-image-adoption/llvm-dc-tests.*`.
Earlier 159 distinct decoder checks passed on Linux. One same-host Linux -O0
fixture pair changed only the DC shortcut: 44.833s to 5.840s, 52 checks on both.
This is not Mac/UI/Swift timing or arbitrary-JPEG performance. Full coefficient
validation and exact sequential F32 arithmetic remain; dense blocks keep their
original algorithm. Sanitized sampled-stack SVG and scoped evidence are in
`docs/receipts/jpeg-diagnostic/`. It is a sampled weighted tree, not a timeline.

## Next implementation and acceptance

1. Reader polish v3 passed 364 native Linux checks across 10 suites; all 15 app/test
   delta paths remain exact except the repaired affine test binding. The earlier
   scoped-reader 12GiB frontend guard remains unrun, not a test pass.
   `build/reader-ui-polish-v3-integration/HANDOFF.md` binds manifest `93cd7ed1…`
   and patch `07868916…`. The maintained LLVM23-O1 Mac build passed in876.669s (frontend323.483s),
   binary `5d67eba5de1ffa2490771e98e8294eba22192b59ed1b961130e8335e966351dc`,
   run `build/reader-ui-polish-v3-mac/runs/2a7a7feb-49da-4f39-a1f6-204550afacc6`.
   Root adopted these exact15paths after collection, receipt
   `build/root-polish-adoption/receipt.json` (`a7346cbb…`). Default fcbbb stays
   unchanged. Both matching helpers built successfully; exact bindings are in
   `build/polished-native-acceptance-helpers-v2/BUILT.json`.
2. Corrected polished external run passed actual transcript copy, folder approval,
   capture, preview/pan, source removal, different-process restart, two exact0600
   exports and complete ATIF export. All7,595 exact pixels and37 ATIF content
   checks passed; both ATIF copies pass the pinned official schema. Guest cleanup,
   fixture preservation and display restoration passed. Root inspected the native
   screenshots. VM stopped and lease released. Receipt:
   `docs/receipts/polished-external-native.json` (`0ef11a68…`).
   JPEG run is active at `build/polished-native-acceptance-v2-plan/run-jpeg-01`,
   wrapper66943, driver19351; root owns it. Same app5d67 and exact matching helper.
   The earlier first polished native run passed initial transcript copy and exact local
   attachment capture, then a harness `/usr/bin/date` path failed after Open.
   Original capture2/cleanup1/display-holder1 remain failures. Later independent
   recovery verified app/child/window absence and preserved the marker-owned
   fixture. VM stopped and lease released. Corrected external/JPEG runs
   are in `build/polished-native-acceptance-v2-plan`; `/bin/date` now has
   an early preflight. Same binaries, source, pixel oracles and limits. Run these
   sequentially; include the correctly bracketed parent sample after child exit.
3. Same-host Linux admission A/B completed: 128/512-element chunks took
   5.799/5.773s, heartbeat gaps3/5ms, all exact pixels/padding checks passed.
   No meaningful improvement; retain128. This does not explain native latency.
   The Base-only native Close discriminator actually ran: idle window714ms,
   forked window9660ms after click. The forked App.run returned immediately after
   handling Close, but the visible window persisted until the ten-second child
   completed. Both process/window5s checks failed; all processes gone by20s.
   Exact traces are in `build/native-close-discriminator-plan/artifacts`;
   public receipt `docs/receipts/native-close-discriminator.json`. Inspected
   upstream main has no compatible fix; no new native patch is authorized.
   Separately, the correctly bracketed image-admission sample shows895/997
   main-thread observations in Window.frame,879 in its Cocoa run-loop wait.
   `docs/receipts/image-admission-profile/` contains the weighted flame graph.
   Archive decoder now owns a small same-VM1/80ms redraw-pacing diagnostic;
   root will run it after JPEG. Keep128-pixel admission chunks unchanged.
4. The 129-path image/capture/ATIF/discovery/DC slice and corrected export target
   test are published in `1a9ca8b8…`; update remaining sanitized receipts and PR
   after each concrete result. Accepted default executable remains unchanged.
5. Recorded successful-commit evidence is reconciled onto polished v3 in
   `build/recorded-commit-polish-integration`; four affected suites passed56
   native Linux assertions. Full maintained Mac build run1ef71a55 passed,
   unified session57010 exit0,907.098s, binaryf1713174…7952. No native Why run yet.
   remaining_parity_audit is preparing its matching helper; archive decoder has
   the next Mac compile slot. Root source/default remain unchanged by G15.
   Child-result navigation remains at `build/result-link-ui-integration`.

Owner's actual Swift-app screenshots are the visual baseline: persistent dark
green navigation with yellow selection, clear proportional type hierarchy,
spacious dated session rows, readable message groups, collapsible evidence
details and useful usage charts/controls. Current Bend chrome is only an initial
improvement, not visual parity. Inspect the Swift app read-only and use synthetic
content for shared comparisons. Never publish the owner's reference screenshots.
An isolated first History-workspace implementation now owns navigation hierarchy,
static licensed sans chrome/list titles and reachable grouped actions; its source
is under `build/history-workspace-integration`. It preserves canonical reader
text, scalar offsets and existing body geometry. Not adopted or native-tested yet.

## Remaining parity and measured limits

`build/parity-gap-audit/GAPS.md` records 18 journeys against read-only Juice
`829ff9b5…`. Aliases/provider presentation, installed quota clients, per-window
history, read-only agent Connect/MCP, library usage/pricing, multi-source Briefs,
deliberate excluded-content removal and comfortable formatted reading remain.
Missing CJK/emoji glyphs are visible; Unicode byte preservation is not shaping,
IME or accessibility acceptance. Resizing/input latency and broader image formats
remain open. Functional and visual parity both remain required.

Historical broad evidence: 40 executables/2,960 checks and 12 production laws
checked by BendTT/Lean. Focused checks do not replace a fresh complete suite.
Physical-Mac 100k: import36.194s, unchanged3.910s, append16records23.816s;
search/late/scoped-late p95=42/7/17ms. Marginal tuning is deferred per owner.
Separate streaming-archive100k: 26,936,113 logical / 7,654,948 compressed bytes
captured in139.055s; retained verify/read/search/dual exports after removal took
44.475s combined. Different workloads; no Swift comparison. Future comparisons
must use equivalent work on the same host.
