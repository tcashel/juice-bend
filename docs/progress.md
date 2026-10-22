# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains **in progress**. No user answer or approval is pending.
Application/UI/parser/policy stay Bend 2; the narrow SQLite bridge is 454 lines.
Lean is an optional development proof checker, never an app dependency.
Mise pins Bun 1.4.2 and Bend 2.0.37 revision
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`. All evidence is synthetic; original
Juice/provider data remain read-only. Update only the implementation branch and
draft PR #1; never merge. Preserve the protected checkout index and local edits.
Publication uses explicit paths and a separate index in `build/publication.git`.

## Current executable and adopted source

The default `build/juice-bend`, `build/juice-bend-reader` and
`build/Juice Bend Reader.app` now contain native-tested executable
`fcbbbfbde90ad072c26fb20ab044522487a6ee4bbe9890f72300765a18518701`.
Its full reader journey passed with synthetic fixtures. The earlier executable
`0d4839d98088aff7c3c5a5581908ded7e877e5987e17ecafd592e03ce6d75988`
is preserved in `build/juice-bend-connections` and its Connections app bundle.
Earlier compact/archive binaries and bundles are also preserved.
`mise run run -- --demo` opens an isolated demo.

The source tree now includes 63 reviewed changes: readable transcript formatting,
word wrapping, inline-attachment inventory/export, Connections presentation,
streaming archives and the confined attachment worker. Adoption manifest:
`build/reader-attachments-adoption/manifest.json` SHA `0774294e…`.
All root preimages were checked/backed up; the checkout index is unchanged.
The manual worker test is the exact successful v4 test, replacing a stale socket
expectation without changing application behavior.

Six separately reviewed recorded-title backend/test files are now adopted;
preimages and exact hashes are in `build/provider-title-adoption/receipt.json`
(`da95d0fc…`). They passed650 focused Linux-native assertions and49 Mac-native
title assertions, and are disjoint
from the pending92-file capture/preview/ATIF/discovery adoption. The accepted
Mac executable and current frozen main build do not include title-v5 yet.

The worker command classifier is now a separately adopted Bend-only equality
dispatcher; exact arity, reserved-prefix refusals and ordinary arguments are
unchanged. New routing27 + existing protocol28 assertions passed on the physical
Mac with normal clang-O3. See `docs/receipts/worker-dispatch-native.txt` and
`build/worker-dispatch-adoption/receipt.json`. The accepted reader is unchanged.

The prior reader source snapshot built executable
`fcbbbfbde90ad072c26fb20ab044522487a6ee4bbe9890f72300765a18518701`
at `build/next-parity-integration/mac/296cfc88-2887-4325-83d0-d5e2459b54f6/main`.
It is promoted after the uninstrumented reader journey passed. Promotion receipt:
`build/reader-polish-promotion/receipt.json`; native result `c61781c0…`.
Its103 build inputs and93 pins are frozen separately; the later title backend
changes are not in that binary. `docs/receipts/reader-attachments-native.txt` records passed and failed
scopes; its companion input manifest binds the build. Earlier GUI passes used
`fccb5209…`; do not present them as complete acceptance of the newest executable.

## Exact continuation

PR #1 remains open/draft/unmerged, verified at published commit
`9a459555cd8bf0086c7432d2f6ec53bf4042e398` (tree `71bbcd59…`), which adds the
recorded-title backend. Its remote receipt is `build/provider-title-remote.json`.
Earlier reader and event-replay publications remain in the branch history.
No combined attachment UI claim follows.

1. **Reader release bug:** first full-GUI run changed a correct selection when
   moving to Copy. Second run passed both cross-wrap copies and exact Back pixels,
   then hit a wrong test expectation for copying an unprepared Brief. Third run
   corrected that expectation but reproduced changed selection in Connections.
   `build/reader-polish-native-v3-plan/v3-observed-result.json` SHA `e3ddb932…`
   preserves the latest failure; app cleanup/display restoration passed and VM
   stopped. A small native probe cleared drag on all nine mouse-up edges, which
   does not rule out full-GUI event/state loss.
2. **Active diagnostic:** `build/reader-full-gui-diagnostic/payload`, nonce
   `d93d6bc7-0488-40be-b4a0-ffe8bf65560f`, wrapper 51615 and guest13753 both ended0.
   The corrected entire driver passed; cleanup/display restoration passed and
   the VM stopped. The Bend-only instrumented
   GUI records native event → UI → handle → service states. Binary `a73524eb…`
   is diagnostic -O0; neither timings nor this passing run establish optimized
   acceptance. The trace had296 ordered events and50 mouse-up edges, all clearing
   drag, with no resurrection. Optimized diagnostic `9daaed9c…` linked from
   the same frozen C; the isolated CLI smoke passed. Its ten-cycle Connections
   driver stopped before selection cycles: its shortened navigation clicked
   Usage from History instead of opening Settings first. This is a driver error,
   not a new selection result. `build/reader-connections-o3-plan/native-result.json`
   preserves the attempt; guest99695 ended1, cleanup2, final windows empty,
   display restoration0, wrapper83794 ended0 and VM stopped. The diagnostic
   owner's fresh `build/reader-connections-o3-v2-plan` checks Settings before
   Connections and uses one process-identity observation during cleanup.
   It reproduced the failure on cycle2: the endpoint Mouse-up is absent from
   both native frame and handler logs. All62events match; all11received releases
   clear dragging; no service/view resurrection. Guest90296 ended1, cleanup/
   display/wrapper28691 ended0, VM stopped. Result SHA `37656250…`.
   Fresh `build/reader-connections-o3-v3-plan` passed all10cycles after adding
   a trailing same-process wait after cliclick's final release; no app/runtime
   change or replay. All37releases arrived; every copy matched21bytes and no
   service/view state resurrection occurred. Root checked clipboards and images.
   Guest29676/wrapper39736/cleanup/display ended0; owned VM stopped.
   Completion receipt `ccc4f215…` supports input-delivery timing, not proof of
   the exact native cause. Previous failures remain preserved.
   The uninstrumented executable passed the unchanged full reader assertions
   at `build/reader-polish-native-v4-plan`, nonce
   `6dc746d1-9d4e-47da-9630-7113d93490aa`, wrapper95138/guest3513,
   owned Tart9330. Both cross-wrap copies, page/wheel movement, inert entry,
   exact Back images and retained-capture checks passed. Root inspected16images.
   Guest/cleanup/display ended0; the wrapper propagated143 after explicit TERM
   of its verified owned VM child. VM stopped and lease released. Result
   `c61781c0…`. No full quota/attachment/export/restart/IME/performance claim.
   Separately, actual production Gui/UI replay passed97 Mac-O3 checks across
   event/service/view boundaries, including the exact473-character missing-Up
   negative control. The exact tested entry is adopted at
   `tests/reader_release_replay.bend`;46production dependencies/93pins match.
   See `docs/receipts/native-validation-followup.txt`. No app/runtime fix was
   made. Diagnostic instrumentation prevents transferring its pass to production.
3. **Attachment capture passed:** full-app worker v4 passed all ten stages and
   120 finite races. Actual production Capture.run composition then passed 16
   native assertions: binary/empty/Unicode paths, missing refusal, original
   receipt and exact export after root disable/source loss. Report:
   `build/attachment-capture-native-run/native-result.json` SHA `60ecdf15…`.
   Guest45035/wrapper80946 ended0; VM stopped. Asset storage has220 Mac checks;
   capture coordinator has81 Mac checks. These modules remain isolated.
4. **Parallel integration:** `attachment_native_receipt` owns the sole combined
   capture/ATIF/discovery/preview main/CLI/UI assembly in
   `build/attachment-capture-ui-integration/tree`. Its20 Ack/model native checks
   and whole-GUI frontend check passed. The final combined GUI callback/control
   and attachment UI suites passed114 Linux-native assertions; actual combined
   window acceptance is still pending.
   `remaining_parity_audit` owns PNG preview and affine app wrapper. External
   retained-preview backend passed96 Linux-native checks, including10 actual
   child checks after source loss and root disable. Mac wrapper gate `d7fad47b`
   stopped before tests at an Apple clang-O3 backend crash; exact generated C
   and reproducer are preserved. Same-C O1 correctness retry is prepared but
   waits behind the combined app; no runtime/application patch was made.
   Native helper `55476de6` passed prepare/guard/existing-root-refusal, producing
   exactly3retained records/10events and the synthetic PNG without preapproved
   folders/assets. Binary `fe486d12…`, receipt `e50531f3…`.
   Frozen combined main Mac build `38f78e5a` timed out after1200.125seconds
   before C output, with empty diagnostics; all142source/bridge files/93pins
   remained unchanged. Session19754 ended1 and its owned process group is absent.
   Its Linux frontend also exceeded300seconds without emitting C; neither
   timeout is a semantic failure or a pass. Default reader is untouched.
   Source-identical profiled retry `baa66041-e59b-403d-95b8-5d4dde1a2408`
   ended with SIGKILL(-9) after531.740seconds, before its2400s timeout and before
   C emission. The runner did not timeout-kill it. Darwin reported15,100,510,208
   bytes peak child RSS; the exact kill cause is unknown. No CPU profile exists.
   All142 inputs/93 pins/compiler-tool hashes stayed unchanged, and the owned
   processes are absent. Receipt `7e8ba8aa…`, manifest `ef48a14d…`.
   A bounded Linux diagnostic (`ea0fbca4`, receipt `a4f6bf54…`) completed loading
   all142 modules/7082 definitions in23.511s, then hit its8GiB memory guard while
   checking definitions. This localizes the current problem to validation,
   without proving the Mac kill cause. A transparent per-definition observer
   (`7766ba9f`) then reached the worker classifier before the same guard;
   after its verified equality-dispatch rewrite, `ea4945b6` passed that function
   and reached `Gui.read_job`. Root's isolated GUI read/write dispatcher refactor
   preserves command arity and fallback behavior; a fresh native subprocess gate
   passed57 assertions. Its114 existing GUI regression checks and the bounded
   full-app observer are next. Do not repeat an unbounded full build before
   checking the resulting memory behavior.
   Neither diagnostic is application, UI or performance acceptance.
   The reviewed integrated Tart plan is in
   `build/integrated-assets-native-v3-plan/HANDOFF.md`; final exact main/helper
   receipts, control hashes and retained-preview binding are required to stage.
   V3 keeps build source/receipt evidence on the host outside VM shares; its
   native assertions and fixture expectations are unchanged from tested v2.
   No combined executable or UI acceptance exists yet.
   ATIF core passed69 Linux checks and six actual exports passed the pinned
   official v1.8 schema. PNG core passed96 Linux checks; preview passed79.
5. **Physical-Mac PNG/preview gate passed:** session97576 ended0, run
   `build/attachment-image-preview-integration/mac-root/984b4865-5a5b-4c0b-bccc-9ce70f44e2c3`.
   Four Bend suites passed175 assertions with empty runtime stderr; the
   standalone visual entry built successfully. All22 files/93pins are unchanged.
   Receipt SHA `7e4eb5a0…`; binary `057e3757…`. Standalone native preview
   rendered its initial Fit image visibly, but the initial pixel oracle failed
   after converting screenshot colors to sRGB. No zoom/pan/Back/JPEG checks ran.
   Original failed attempt is frozen at `build/attachment-preview-native-run` with
   result SHA `efcb853d…`; guest68785 ended1, cleanup/display0, wrapper34972
   ended0 and VM stopped. The independently corrected zero-tolerance/profile-bound
   oracle then passed the complete fresh native journey in
   `build/attachment-preview-native-v2-run`: 21checks/70,253sample comparisons,
   all9required screenshots inspected by root, Fit/actual/pan/clamps/Back/Escape/
   unsupportedJPEG/reopen observed. Guest57870, cleanup/display and wrapper44355
   all ended0; VM stopped. Report SHA `92e8a150…`. This is standalone component
   acceptance, not full-app retained-asset loading or source-loss acceptance.
6. **ATIF core Mac gate passed:** initial staging failed before compilation
   because the isolated tree omitted its native bridge. Separate
   `build/atif-export-mac-stage/tree` now contains the exact frozen bridge
   `44b2aa26…` from the successful Linux receipt; the original tree is unchanged.
   Run `b8e9f577-52d9-43c6-bb99-5e0f0cb659ad` passed69 native checks
   (22formatter/47export), empty runtime stderr, exact49inputs/93pins unchanged.
   Receipt SHA `4a54ef19…`; runner15080 ended0.
   ATIF CLI/UI integration passed204 focused Linux assertions at explicit-O1.
   Its final handoff is frozen (`build/atif-cli-ui-integration/HANDOFF.md`);
   capture UI owner will assemble all shared-file changes once preview is frozen.
7. **Large-root discovery:** `discovery_parity` owns isolated
   `build/discovery-parity-integration`: persisted bounded traversal and prefix
   shards replace the whole-root2048-entry refusal, retaining old queues on
   incomplete/failed passes. Root cancellation fences stale callbacks. Mac
   gate7fee518c passed169 Mac assertions, including2100accepted/700rejected files
   and nested/metacharacter/symlink/restart cases. Review exposed a64-Unicode-child
   starvation limit; the independent128-child/1024-file regression reproduced it
   before the fix. Final wording gate3e85b21d passed145 affected assertions.
   Six-file patch `daaefac5…` and manifest `8e2aaa79…` are delivered to the
   combined GUI owner, with the discovery progress summary hook. Full-app
   refresh interaction and source-alias presentation remain open.
8. **Independent next slices:** recorded Claude titles have a frozen six-file
   handoff at `build/provider-title-integration/HANDOFF-SOURCES.json`
   (`dd9f8c2c…`). Final focused title suite passed49 assertions; five unchanged
   suites passed601 in the preceding run, whose separate test-oracle failure
   remains preserved. A real stale-title bug after oversized records was fixed
   with unreadable-record barriers. Backend source adoption is complete;
   Physical-Mac run `0cb148aa` passed49 title assertions with normal clang-O3;
   root verified all37 source/bridge inputs,93 pins and output hashes. Receipt
   `40d6137c…`; see `docs/receipts/provider-titles-native.txt`. No Mac title UI or combined
   application acceptance yet. Verified child-result links (`discovery_parity`),
   bounded JPEG decode (`remaining_parity_audit`) and recorded successful-commit
   provenance (`archive_decoder`) continue in separate ignored trees. They do
   not alter the frozen combined app or its input manifests.

Next keep PR #1 current with explicit limitations, then assemble
capture/ATIF/image UI seams into one new main build and validate actual use.
Stop only verified owned Tart children; preserve all failed attempts.

Latest app-source publication verified: implementation branch `9a459555…`,
tree `71bbcd59…`, exact bare ref `codex/published-provider-titles`; protected
index unchanged. PR metadata confirmed that head and open/draft/unmerged state.
The Mac title receipt and terminal compiler diagnostics are the current follow-up.
No Tart session remains active.

## Remaining goal and measured limits

Full parity is incomplete. `build/parity-gap-audit/GAPS.md` records18 concrete
journeys against read-only Juice commit `829ff9b5…`, without private source copies.
Remaining work includes large-root discovery/archive aliases, provider-specific
presentation, external attachments/images, ATIF, installed-provider quota clients,
per-window history, read-only agent Connect/MCP, library Usage/pricing,
multi-source Briefs, recorded commit-result attribution, deliberate excluded-content
removal and comfortable formatted reading. Missing features are not excluded.

CJK/emoji/combining glyphs, shaping/IME/accessibility, resizing and measured
input-to-photon latency remain open/upstream-limited. Basic copy/scroll success
does not establish these behaviors. Warm, usable native UX remains part of the goal.

Historical broad evidence:40 executables/2,960 checks and12 production laws
checked by BendTT/Lean. Later focused checks do not replace a fresh complete suite.
Physical-Mac100k: import36.194s, unchanged3.910s, append16 records23.816s;
search/late/scoped-late p95=42/7/17ms. Marginal tuning is deferred per owner.
Separate quiet streaming-archive100k:26,936,113 logical /7,654,948 compressed
bytes captured in139.055s; retained verification/read/search/dual exports after
source removal took44.475s combined. Different workloads; no Swift comparison.
Future comparisons must run equivalent work on the same host.
