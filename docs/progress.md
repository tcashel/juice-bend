# Implementation checkpoint

## Goal and boundaries

Functional and pleasant native UX parity with SwiftUI Juice, excluding embeddings
and model features, remains **in progress**. No user answer or approval is pending.
The goal is active. All maintained app behavior/UI is Bend 2; the unchanged
418-line SQLite bridge is the native exception. Lean is optional proof checking,
not runtime. Mise pins Bun 1.4.2 and Bend 2.0.37 at
60ca80aedeec9d8f0629b5f10dd19457d8ad67af. Original Juice and provider data remain
read-only; validation is synthetic. Only update tcashel/juice-bend draft PR #1;
no merge, force push or distribution. Preserve all local changes and protected
checkout index. Publication uses an explicit allowlist and separate index in
ignored build/publication.git.

## Working executable and observed slice

Standard `build/juice-bend`, named `build/juice-bend-brief-keyboard`, and
`build/Juice Bend Brief Keyboard.app` contain observed native binary
`78c396eb02c15fed7d4c3266185244ffe851d7333872042090d9bb14cbb66935`
(14,732,920 bytes, 62 unchanged app inputs and all 88 upstream hashes verified).
Isolated empty-library launcher status passed. Prior Brief/History/Reading and
other named apps remain. `mise run run -- --demo` builds current source into an
isolated synthetic demo.

The new continuation brief freezes the exact opened range/filters and requires an
explicit repository. Copy/export recheck the entire preview. Root edits and Back
retire pending effects. Native selection now collapses to the correct edge on
plain Left/Right; Shift extends from the active caret.

Actual Tart passed eight query clipboard cases, held native Delete, Brief selected
and whole copy, two exact private exports, empty/edited-root refusal, retained
reads and identical Back text/pixels. Both exports equal the checked 2,524-byte
preview. Snapshot 2 remained selected while the fixture mutated another source
into 7/8 and moved all original source paths away. Separate fixture assertions
cover that other source's old capture; this is not a timed native stale-worker
race. First-run query-clear and Dock shortcut failures remain separately saved.
Held native key51 Delete and explicit Clear search passed without app changes.

First candidate `1c661eb…` passed five production gates (84/85/123/46/53 PASS
lines including documented fixture/command checks and banners). The corrected
selection path passed 46 assertions; the final app passed the existing verified
53-line runtime driver. These are distinct builds, not a new full-suite, proof or
performance run. See `receipts/brief-native.txt`, `receipts/brief-build-inputs.sha256`
and `benchmarks/results/tart-brief-summary.json`.

Earlier History: 199 focused checks, six native titles/scopes/copy/export/Back.
Reading: 107 focused checks, six native Why cases, four exports, selected-snapshot
Rebuild and retained restart. Earlier full suite: 40 executables / 2,960 checks;
twelve production laws passed BendTT and Lean 4.34. Linux passed 300 portable
checks. Context batching passed 3,315 checks including 27 crash cuts. Physical-Mac
100k timings: initial 36.194 s, unchanged 3.910 s, append 16 records 23.816 s;
search/late/scoped-late p95 42/7/17 ms. Marginal tuning is deferred per owner
priorities. No Swift comparison; any comparison must use the same host and work.
Exact historical build scopes remain in native-validation.md and performance.md.

## Exact continuation

1. This checkpoint accompanies the Brief source, tests and native receipts.
   Earlier published base is History `cc5a0397a4804530af4ae97a85143caba92533db`,
   tree `811e00905a360b0c7ef3d60889e3b605ba3a80d9`. Brief publication uses
   `build/brief-publication.json` and `build/brief-remote.json`. Verify the live
   PR head before the next expected-SHA fast-forward. Keep PR open/draft/unmerged.
2. Brief native run `build/tart/brief-keyboard-plan` is complete. Resumed guest
   steps exited 0, all owned windows closed, original Boolean Dock 0 restored,
   runner 40123 exited 130, VM stopped and lease absent. Original failed attempts
   remain under first-run-artifacts and resume-1-artifacts. Native summary and
   promotion: `build/tart/brief-keyboard-plan/artifacts/native-summary.json` and
   `build/brief-keyboard-promotion.json`. No root compiler or VM remains running.
3. Archive integration remains isolated under `build/archive-integration`.
   Agent archive_decoder owns the compiler for its remaining focused gates.
   Production is unchanged. It has reported native metadata 90, maintenance 60,
   compressed capture 40 and atomic safety 3,412 assertions, including 43 rejection
   cases, 30 owned-process kill boundaries and an actual old-writer schema fence.
   Read current receipts/HANDOFF before adoption; broad-regression orchestration
   and genuine old-schema fixture corrections have separate failed attempts.
   Resource-cap and real CLI-route gates remain to verify. Decoder's earlier 485
   assertions are separate. Keep helper modules out of top-level standalone test
   glob. Archive profile initially bounds input 1 MiB / logical 4 MiB; that is not full
   archive parity or a peak-memory claim. Review schema3 migration, exact owned
   container plus logical stream, byte-space labels, final publication gates,
   source-independent dual exports/rebuild, and all failure paths together.
4. Request-first Brief readability is isolated in `build/brief-readability`.
   Its patch passes `git apply --check`, but has no runtime verdict: new layout,
   omitted empty fields, full policy/citations after facts, format v2 and 34
   declared assertions. Root still needs code review, compilation, tests and
   actual visual validation. Merge archive's logical_source_bytes commitment and
   wording explicitly; never overwrite either source wholesale. Do not weaken
   preview identity, byte bounds, request eligibility or full revalidation.
5. Remaining parity includes archive/attachment coverage, explicit opt-in
   connection/subscription surfaces and pleasant interaction/visual quality.
   CJK/emoji/combining glyphs, shaping/IME/accessibility, resize and measured
   input-to-photon latency remain open/upstream-limited. No implicit account
   access, provider changes, billing invention, models or model-storage cleanup.
