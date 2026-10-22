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

The default `build/juice-bend`, `build/juice-bend-connections` and
`build/Juice Bend Connections.app` retain observed executable
`0d4839d98088aff7c3c5a5581908ded7e877e5987e17ecafd592e03ce6d75988`.
Its native capture/search/reader, Connections and Back workflows passed with
synthetic fixtures. Earlier compact/archive binaries and bundles are preserved.
`mise run run -- --demo` opens an isolated demo.

The source tree now includes 63 reviewed changes: readable transcript formatting,
word wrapping, inline-attachment inventory/export, Connections presentation,
streaming archives and the confined attachment worker. Adoption manifest:
`build/reader-attachments-adoption/manifest.json` SHA `0774294e…`.
All root preimages were checked/backed up; the checkout index is unchanged.
The manual worker test is the exact successful v4 test, replacing a stale socket
expectation without changing application behavior.

This source builds executable
`fcbbbfbde90ad072c26fb20ab044522487a6ee4bbe9890f72300765a18518701`
at `build/next-parity-integration/mac/296cfc88-2887-4325-83d0-d5e2459b54f6/main`.
It is **not promoted as the default** while intermittent selection is unresolved.
All 103 combined main/reader build inputs and 93 pins still match the adopted
source. `docs/receipts/reader-attachments-native.txt` records passed and failed
scopes; its companion input manifest binds the build. Earlier GUI passes used
`fccb5209…`; do not present them as complete acceptance of the newest executable.

## Exact continuation

PR #1 was last checked open/draft/unmerged at
`3a0230da39b8e0bf68d870b0a5f53979032cf53b`. Publication of the adopted source and
qualified receipts is being prepared; no new remote commit is claimed yet.

1. **Reader release bug:** first full-GUI run changed a correct selection when
   moving to Copy. Second run passed both cross-wrap copies and exact Back pixels,
   then hit a wrong test expectation for copying an unprepared Brief. Third run
   corrected that expectation but reproduced changed selection in Connections.
   `build/reader-polish-native-v3-plan/v3-observed-result.json` SHA `e3ddb932…`
   preserves the latest failure; app cleanup/display restoration passed and VM
   stopped. A small native probe cleared drag on all nine mouse-up edges, which
   does not rule out full-GUI event/state loss.
2. **Active diagnostic:** `build/reader-full-gui-diagnostic/payload`, nonce
   `d93d6bc7-0488-40be-b4a0-ffe8bf65560f`, wrapper 51615, guest 13753.
   Exact readiness was verified and `run-all.sh` is running. The Bend-only instrumented
   GUI records native event → UI → handle → service states. Binary `a73524eb…`
   is diagnostic -O0; neither timings nor a passing run establish optimized
   acceptance. Agent `reader_release_diagnostic` owns trace analysis.
3. **Attachment capture passed:** full-app worker v4 passed all ten stages and
   120 finite races. Actual production Capture.run composition then passed 16
   native assertions: binary/empty/Unicode paths, missing refusal, original
   receipt and exact export after root disable/source loss. Report:
   `build/attachment-capture-native-run/native-result.json` SHA `60ecdf15…`.
   Guest45035/wrapper80946 ended0; VM stopped. Asset storage has220 Mac checks;
   capture coordinator has81 Mac checks. These modules remain isolated.
4. **Parallel integration:** `attachment_native_receipt` owns external capture
   CLI/folder-policy UI; `archive_adoption_review` owns ATIF CLI/UI (kind41);
   `remaining_parity_audit` owns PNG preview and affine app wrapper. Shared seams
   are coordinated, but no combined executable or UI acceptance exists yet.
   ATIF core passed69 Linux checks and six actual exports passed the pinned
   official v1.8 schema. PNG core passed96 Linux checks; preview passed79.
5. **Physical-Mac PNG/preview gate passed:** session97576 ended0, run
   `build/attachment-image-preview-integration/mac-root/984b4865-5a5b-4c0b-bccc-9ce70f44e2c3`.
   Four Bend suites passed175 assertions with empty runtime stderr; the
   standalone visual entry built successfully. All22 files/93pins are unchanged.
   Receipt SHA `7e4eb5a0…`; binary `057e3757…`. Actual visual interaction remains
   pending. Agent `archive_decoder` is preparing its Tart payload. Mac slot free.

Next collect the native diagnostic and Mac gate, fix selection from evidence,
publish the coherent adopted slice with its explicit limitation, then assemble
capture/ATIF/image UI seams into one new main build and validate actual use.
Stop only verified owned Tart children; preserve all failed attempts.

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
