# Implementation checkpoint

The working default is `4ffb4903…` with all 206 tested application inputs adopted.
PR #1 remains draft and unmerged. Prior 201-input sources and binaries are preserved.

## Goal and boundaries

Continue functional and pleasant native UX parity with Swift Juice, excluding
embeddings/models. All application logic, UI, policy, tests and benchmarks are
Bend 2; SQLite has the narrow native bridge. Lean is an optional proof checker.
Mise pins Bend 2.0.37, Bun 1.4.2 and LLVM 23.1.4. Original Juice and histories stay
read-only. Fixtures and libraries are synthetic and isolated. No user answer is pending.

`mise run demo` launches the accepted 206-input default. Preserve the dirty root,
index and prior binaries. Use explicit publication paths through the separate
`build/publication.git` index; do not merge automatically.

## Current executable and native evidence

Exact executable `4ffb4903…` binds 206 inputs from
`build/combined-polish-cancel-seal-v1/tree`: Usage metric cards with Overview/Report,
list readability, cooperative JPEG cancellation/Close acknowledgment and byte-oriented
event sealing. The SQLite bridge and existing identity/preservation contracts are unchanged.

The full Mac build passed through original pinned CLI/main with the maintained
minimal GC512 preload, without telemetry or a relocated compiler copy. Frontend
271.646s and LLVM -O1 compilation 557.623s are build diagnostics, not app timings.
This closes the full-app maintained-compiler validation gap; it was the equivalent
runner setup, not a literal `scripts/build` invocation. Receipt c5c55080:
`build/combined206-mac/runs/4f49b7aa-34e5-4476-90f9-824a7bd97875/receipt.json`.

- Usage native PASS: 17 exact clipboard comparisons, 10 canonical report comparisons,
  one canonical export, provider filtering, capture reopen, two Back levels and
  restored partial Unicode selection. The original three captures survived a
  different-process source-loss restart; the fourth was imported afterward, with
  no second restart claimed. Root reviewed all 15 actual images. Receipts:
  `build/native206-staging/usage-summary/run-01/{native-result,root-visual-review}.json`
  (b31321dc / 81f5119a).
- Pending JPEG Close PASS: the child was observed live before and after the click;
  window gone within 394ms, parent/child within 762ms; no orphan and exact nonce
  spool removed before harness cleanup. These are observation upper bounds for
  this fixture, not a global cancellation guarantee. Root reviewed three images.
  `build/native206-staging/pending-close/run-01/pending-close-result.json` (2592bff6).
- Inline-PNG functional checks passed 8 Fit/3 actual pixels, original 72-byte
  export, Escape selection restoration, source loss and ready Close. Root reviewed
  six images. Additive collector b258bb6b used the already sealed PNG collector;
  the incorrect generic JPEG collector failure is preserved. No rerun or artifact
  edits occurred. Strict JPEG/PNG and worker-creation observation remain unaccepted.

Older 201-input native reader/Child/retained-PNG results remain historical and
bound to `943eee7e…`; they are not fresh 206 validation. See scoped public receipts.

## Focused tests and append measurement

Usage 130 passed on Linux (summary 19, interaction 19, existing UI 20, controller 47,
list-row 25). Cancellation App12 passed actual Bend events (active 5, retired 5,
Escape 2). Exact generated-C continuation after the earlier compile timeout is
recorded separately. These are component tests, not a combined full-suite pass.

Event-seal bytes passed 73 focused assertions plus 1,611 preservation assertions,
including 27 crash cuts. The original collector failed on the unchanged crash
footer; additive read-only collection accepted the existing outputs without a
rerun or changed assertion. Its fourth C/binary hashes are post-run bindings;
only the first three retained durable pre/post hashes.

One matched physical-Mac pair measured baseline/candidate import 45.304/42.028s,
unchanged 4.405/5.570s and 16-record append 28.252/26.535s at 100k records. Bytes,
prefix identities and seals matched. This modest single pair does not solve slow
append or show significance; unchanged refresh was slower. No Swift comparison.
Receipt: `build/event-seal-bytes-integration/mac-paired-01/receipt.json` (0b0402d5).

## Exact continuation

1. The 30 source/test/tooling paths and all three default binaries are adopted. Receipt
   `build/native206-root-adoption/receipt.json` (808b2736) binds the exact 206 closure;
   originals remain in `build/native206-root-adoption/previous/`. HEAD/index stayed
   unchanged. Future PR updates use explicit paths/modes and preserve history.
2. The runner skips redundant App12 aggregate discovery; all three split entries
   and explicit aggregate invocation remain. Its build-stub check proves discovery,
   not Bend assertions. The Child fixture's shape-only summary constructor adapter
   retains Export 552 and assertions; adapted 3/4/4 tests were not rerun.
3. Button207 is a separate native build, already running in session 25809:
   `python3 build/button207-mac/runs/4742f192-5926-445f-a35c-ae62f1cf837d/run-mac.py`.
   Collect current receipt/process status before continuation; do not restart if
   active. See `build/button207-mac/HANDOFF.md`. Its separate Linux 42+103 checks
   passed; no native acceptance is claimed. Default 4ff remains protected.
4. Sidebar polish is active in isolation. Continue using Swift Juice's information
   hierarchy and real Bend screenshots. Keep Tart and Mac compilation sequential.

Remaining: dense toolbar/metadata, singular counts, stale generic copy status,
missing CJK/emoji glyphs, shaping/IME, accessibility, resizing and input latency.
Usage date charts/costs and broader parity remain open. Synchronous retained
hashing, PNG/container allocation and generic workers retain cancellation gaps.
No new kernel proof, global test suite or complete-goal claim is made.
