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

Latest verified published head: `1a9ca8b8d7809300748c4cc7aae1f8ae951434fd`,
retained attachments/images/ATIF/discovery, tree `1802a6901d4d3815b0606730750430c0b496f027`.
PR #1 was verified open, draft and unmerged. Publication record:
`build/llvm-pin-publication.json`; exact remote object
`build/llvm-pin-remote.json`; bare ref `codex/published-llvm-pin`.
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
   and patch `07868916…`. Root has not adopted it. The Mac frontend passed;
   reader_release_diagnostic owns maintained LLVM23-O1 build session32371 at
   `build/reader-ui-polish-v3-mac/runs/2a7a7feb-49da-4f39-a1f6-204550afacc6`.
   Do not mutate root/polish closure or start a second Mac compiler before collection.
2. Prefer one polished-app native journey rather than repeating the full e6
   acceptance for the intermediate455 build. Attachment owner is adapting the
   existing exact bytes/pixel/coverage tests to the tested new toolbar mappings
   and shorter canonical reader text. Required helpers are prepared at
   `build/polished-native-acceptance-helpers-v2`; build after the app slot releases.
   Include a correctly bracketed live parent sample after Open/child absence.
3. Archive decoder owns a small same-host Linux production raster-admission A/B
   with 128 versus 512-element chunks and concurrent heartbeat. This cannot prove
   native Metal/UI latency. A separate minimal native Close discriminator is
   prepared without changing production/runtime code. Preserve the actual 39.984s
   native window-close failure and fix future harness threshold enforcement.
4. The 129-path image/capture/ATIF/discovery/DC slice and corrected export target
   test are published in `1a9ca8b8…`; update remaining sanitized receipts and PR
   after each concrete result. Accepted default executable remains unchanged.
5. remaining_parity_audit is reconciling existing recorded successful-commit
   evidence (`build/recorded-commit-integration`, 106 prior Linux checks) onto
   polished v3 in a new isolated candidate. Actual Mac Why remains open.
   Child-result navigation remains at `build/result-link-ui-integration`.

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
