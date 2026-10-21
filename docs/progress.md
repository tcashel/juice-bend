# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and models, remains **in progress**. No user answer/approval is pending.
Application/UI/parser/policy stay Bend 2; current production retains the unchanged
418-line SQLite bridge. Lean is an optional development proof checker. Mise pins
Bun 1.4.2 and Bend 2.0.37 at 60ca80aedeec9d8f0629b5f10dd19457d8ad67af.
Original Juice and provider data remain read-only. All tests use isolated synthetic
data. Update only codex/juice-bend-implementation and draft PR #1; never merge.
Preserve the protected checkout index/local edits. Publication uses explicit paths
and a separate index under build/publication.git.

## Working app and latest evidence

`build/juice-bend`, `build/juice-bend-compact` and `build/Juice Bend Compact.app`
contain observed binary
`e780c37b4866aa759f75c2471ae1c13be6bb0c910761b34fa322405f37bb86eb`.
It is 17,817,896 bytes; build 604.478s, 79 unchanged inputs, 88 upstream pins.
The prior archive binary/bundle `d06447f6…` remain preserved. Use
`mise run run -- --demo` for an isolated native demo.

The 1200×664 content / 1200×696 decorated window fits fully at actual 1280×800
with Dock shown. Native import/search/transcript, Page Down/Up, wheel, status
Close/Escape, Unicode toolbar copy, Brief, retained reads after source loss and
restart, complete/bounded exports and invalid-input refusals passed. Eighteen
clipboard comparisons, six private exports, 172 containment observations.
Final geometry/UI/polish gate: 190 checks; initial compact GUI gate: 359 including
its pure tests. These are distinct scopes, not a new full suite or proof run.

Receipts: `docs/receipts/compact-native.txt`, `compact-build-inputs.sha256`,
`benchmarks/results/tart-compact-summary.json`, `build/compact-promotion.json`.
Local evidence: `build/compact-production-v2`, `build/compact-native-v4-plan/artifacts`
and its `resume-1`. V3 missing cliclick keys and V4 stale-window shutdown race
are preserved; corrected external automation kept the app and fixture unchanged.
V4 guest 53821 ended1 after successful key/geometry/Brief steps; resume81289
ended0 for retained/refusal/cleanup. Runner72330 ended130; VM stopped, lease
absent, original display restored, Dock unchanged. No live VM is reserved.

## Publication and next integration

Latest verified remote head before compact publication:
`164348b0277daaf6463180ac8050679cc710bcd1`, tree
`2b6e8416089baa0900000e46f569efc9e509c90a` (PR open/draft/unmerged).
Prepare the compact-only tree with `build/prepare-compact-publication.py`;
verify its exact 19-path allowlist and app-input manifest, then expected-SHA
fast-forward and update PR #1. Do not publish all dirty/untracked checkout paths.

1. Connections candidate: `build/quota-ui-integration/HANDOFF.md`. Passive local
   Claude quota observations, explicit Enable, strict existing-store admission,
   unknown/zero separation and epoch retirement. WAL pre-open refusal now passed.
   Ten frozen Linux gates passed 492 printed assertions across separate scopes.
   Mac build/run sequence is live at `mac/6a39c755-6b8e-4d61-8d87-11e7f0f78380`,
   runner38322, main-build38337. Poll existing ownership/receipts; do not restart
   on an observation timeout. No production adoption or native UI acceptance yet.
2. Attachment extractor and retained inventory are frozen under
   `build/attachments-integration` and `build/attachment-inventory-integration`.
   Extractor75 Linux checks; inventory38 Mac assertions plus2 fixture receipts.
   Inline exact-byte resolver/export is in progress in a separate isolation.
   External asset capture is still missing. Strict Base-only sandbox attempt08
   failed before ready, exit134 in dyld ignition/cache startup; controls passed.
   Exact synthetic crash/log receipts are under compact-v4 artifacts. A reporting-
   only follow-up is being prepared; no outside-root content grant or signing.
3. Bounded archive streaming is being implemented in
   `build/archive-streaming-integration`: staged container, measured extent,
   bounded decode/replay/verify/export, separate immutable commitments. Not adopted.
   Existing production profile remains 1MiB compressed/4MiB logical/8MiB window;
   dictionaries refused. Schema3 preserves logical offsets and owned container.
4. Transcript readability isolation: `build/transcript-polish-integration`.
   Conversation first, exact citations/metadata appendix, one selectable/copyable
   canonical string; scoped/unscoped verification unchanged, Why unchanged.
   Pure formatter19 Linux checks passed; renderer integration still needs gates
   and actual native inspection before adoption.

## Remaining goal and measured limits

Wider provider/attachment/archive coverage, active-to-archive presentation aliases,
connection functionality and pleasant visual/interaction quality remain incomplete.
CJK/emoji/combining glyphs, full shaping/IME/accessibility, resize and measured
input-to-photon latency remain open/upstream-limited. A separate hypothesis or
portable test is never native acceptance. Keep the working app until successors
pass relevant actual interactions; original private source/data remain untouched.

Historical broad evidence: 40 executables/2960 checks; twelve production laws
checked by BendTT and Lean4.34; Linux portable300 checks. Later changes have their
own focused gates and are not covered by that old full-suite count. Physical-Mac
100k: import36.194s, unchanged3.910s, append16 records23.816s; search/late/scoped
late p95=42/7/17ms. Marginal tuning deferred per owner priority. No Swift timing
comparison; any future comparison must use the same host and equivalent work.
