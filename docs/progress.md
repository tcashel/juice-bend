# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains **in progress**. No user answer or approval is pending.
Application/UI/parser/policy stay Bend 2; the narrow SQLite bridge is 454 lines.
Lean is an optional development proof checker, never an app dependency.
Mise pins Bun 1.4.2 and Bend 2.0.37 at
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`.
Original Juice and provider data remain read-only. All evidence is synthetic.
Update only `codex/juice-bend-implementation` and draft PR #1; never merge.
Preserve the protected checkout index and local edits. Publication uses explicit
paths and a separate index under `build/publication.git`.

## Current working app

`build/juice-bend`, `build/juice-bend-connections` and
`build/Juice Bend Connections.app` contain the observed executable
`0d4839d98088aff7c3c5a5581908ded7e877e5987e17ecafd592e03ce6d75988`.
Physical-Mac build: 19,275,464 bytes, 712.306 seconds, 81 first-party main-closure
files and 93 runtime/build pins. Build duration is diagnostic, not a product
performance benchmark. Compact (`e780c37b…`) and archive (`d06447f6…`) executables
and bundles remain preserved. `mise run run -- --demo` opens an isolated demo.

Connections native acceptance passed in Tart at 1280×800 with the Dock shown:
Settings → Connections, explicit Enable, reviewed setup copy, known-zero and
partial observations, unknown/invalid feed handling, sampled history, Disconnect,
retired callbacks and root-edit refusals. Back restored exact Settings/reader
pixels and original transcript selection. Eighteen clipboard comparisons, four
inert-copy checks and 75 window-containment observations passed. Capture counts
stayed unchanged; full verification and an exact 8,313-byte private export passed.
This is passive local Claude statusline collection, not account authentication.

Nine focused Linux gates passed 387 assertions; six Mac gates passed 334, including
30 transport checks against this executable with HOME absent. Scopes overlap.
The Mac WAL fixture now uses a checkpointed standalone copy rather than assuming
Linux sidecar cleanup; 115 assertions passed with production unchanged.
No new full-suite/proof/performance claim follows from these focused gates.

Receipts: `docs/receipts/connections-native.txt`,
`docs/receipts/connections-build-inputs.sha256`,
`benchmarks/results/tart-connections-summary.json`,
`build/quota-ui-integration/validation-current.json` and
`build/connections-promotion.json`. Actual GUI results:
`build/quota-native-v2-plan/artifacts`, nonce
`97d942a4-7419-4841-9cc7-ad5c6c85a432`. Guest 52085 ended 0; runner 77756 ended
130 after stopping only its owned Tart process. Display restored, Dock unchanged,
VM stopped and lease absent. Driver v1 was prepared but not run; v2 fixes bounded
fresh window observation after process exit. No root VM session remains live.

Earlier compact evidence remains scoped to that preserved executable:
import/search/transcript, Page Down/Up, wheel, Close/Escape, Unicode toolbar copy,
Brief, restart/source-loss reads and exports passed; see `compact-native.txt`.

## Publication and exact continuation

Connections was adopted through the exact 25-path manifest in
`build/quota-ui-integration/adoption-manifest.json`; preimages are preserved in
`build/connections-adoption`. Its publication base is verified compact commit
`1bca130303db30ca34a89dad43df2d53875e9943`, tree
`2a8d3d922e5921eefbe3ebc4c6d256df2bcbe611`. Publish only the named implementation
and documentation/receipt paths; verify all main-closure hashes in the resulting
tree before an expected-SHA fast-forward. Publication receipts use
`build/connections-publication.json` and `build/connections-remote.json`.
Refresh PR #1's actual head before continuing; never stage all dirty/untracked paths.

The following work is isolated and **not adopted into the working app**:

1. Attachment extraction/inventory/inline export: frozen under
   `build/attachments-integration`, `build/attachment-inventory-integration` and
   `build/attachment-inline-integration`. Extractor: 75 Linux assertions.
   Inventory: 38 Mac assertions plus two fixture receipts. Inline: 88 Mac
   assertions plus a source-removal receipt; exact binary/empty output,
   no-clobber and fresh-process retained export passed. UI/CLI integration
   tests against frozen Connections, using mode 5 and workers 39/40.
   First frontend failures are preserved and being repaired. Exact prior
   reader/filter/selection restoration and actual native interaction remain gates.
2. External attachment capture: minimal sandbox attempt 12 started the Bend
   reader and passed binary/empty reads plus denial of its own executable.
   The sole new allowance reads the `/` directory vnode for dyld bootstrap;
   it grants no descendant regular-file bytes. Results:
   `build/attachment-reporting-native/summary.json` and
   `artifacts/attempt12-receipts`. Failed attempts 10/11 are preserved.
   This is not full-app capture acceptance. Next isolate the early worker route,
   bounded protocol and filesystem race tests before SQLite asset integration.
   Blocking file-open/type rejection and process timeout limits need actual
   native validation. No native bridge expansion.
3. Archive streaming: `build/archive-streaming-integration`. Linux component
   checks passed: decoder 46, metadata 99, profile 27; capture 40 and
   legacy/export-corruption 16. Gate `1fcbaa96` passed a >4 MiB logical fixture
   (76 printed PASS lines) and 43 refusal cases (1,928 printed PASS lines,
   including repeated table checks). Its frozen old SQLite bridge is explicitly
   recorded; refresh it before current-tree Mac claims. Actual old-executable
   compatibility, Mac interruption, 100k mixed archives and resource measurements
   remain pending. Actual 256 MiB expansion is unrun. Production still caps
   archives at 1 MiB compressed/4 MiB logical.
4. Transcript presentation: `build/transcript-polish-integration/HANDOFF.md`.
   Conversation first, complete citations/metadata appendix, one canonical text
   for display/selection/copy/export; Why unchanged. Pure formatter 19 Linux
   checks and captured Store/scoped gate 13 passed. Zero-event record intervals
   are retained. Adopt only its seven named files/hunks after integration checks;
   actual Mac/UI inspection remains required.
5. Connections presentation: `build/quota-presentation-integration`. Three files
   change summary/history/setup presentation and tests. UTC formatting, exact
   percentage precision, evidence retention and canonical copy are checked.
   The final Linux gate passed 57 presentation and 70 model checks, with all 107
   inputs unchanged. Exact three-file handoff is ready. No production or native
   UI claim.

Attachment integration currently owns the physical-Mac compiler slot; archive
validation follows its explicit release. Agents coordinate isolated compiler
runs. Root owns app promotion and Tart UI acceptance. Preserve the current
executable until successor workflows pass.

## Remaining goal and measured limits

Wider provider/attachment/archive coverage, active-to-archive presentation aliases,
and pleasant visual/interaction quality remain incomplete. Connections history
currently renders a newline as a fallback box and uses technical timestamps/prose.
CJK/emoji/combining glyphs, shaping/IME/accessibility, general resize and measured
input-to-photon latency remain open/upstream-limited.

Historical broad evidence: 40 executables/2,960 checks; twelve production laws
checked by BendTT and Lean 4.34; Linux portable 300 checks. Later changes have
focused gates and are not covered by that old full-suite count.
Physical-Mac 100k: import 36.194s, unchanged 3.910s, append 16 records 23.816s;
search/late/scoped late p95 = 42/7/17ms. Marginal tuning is deferred per owner
priority. No Swift timing comparison; future comparisons must use the same
host and equivalent work.
