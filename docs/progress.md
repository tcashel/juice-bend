# Implementation checkpoint

The 201-input source overlay and executable are adopted; PR #1 is draft and unmerged.

## Goal and working app

Functional and pleasant native UX parity with Swift Juice, excluding embeddings
and models, remains active. No user response is pending. App logic, UI, policy,
tests and benchmarks are Bend 2; SQLite has the narrow native bridge. Lean is an
optional proof checker. Mise pins Bend 2.0.37, Bun 1.4.2 and LLVM 23.1.4.
Original Juice and private histories stay read-only; validation is synthetic.

`mise run demo` opens accepted executable `943eee7e…` with fresh synthetic data.
Its 201 application inputs match the tested native executable.
Preserve the dirty root HEAD/index. Publish only explicit paths through the
separate `build/publication.git` index. Do not merge automatically.

## Adopted 201-input app

Executable `943eee7e…` adds recorded Child-result navigation, aligned
toolbar drawing/hit areas, private-file image transport and equivalent boxed
glyph data. The diagnostic GC512 frontend and LLVM native build passed.
The full app has not yet been rebuilt with the maintained minimal GC preload.
That adapter passed exact generated-C equality through the pinned CLI/font gate;
include its three tooling paths because unchanged full-app compilation exceeds
the 16 GiB guard. The adapter affects compiler development tooling only.

- Reader/Usage passed 38 exact clipboard checks, three canonical exports, three
  inert-gap checks, four prose drags, 24 native key pairs and source-loss restart.
  Root reviewed 17 images. The fourth Usage capture was imported after restart;
  no second restart for it is claimed.
- Child navigation passed recorded result → retained candidate → transcript,
  expanded tools, canonical export and three Back actions restoring the original
  partial selection. Root reviewed five images. Reader ready Close upper bounds
  were 487ms parent/359ms window; this does not cover pending-worker Close.
- Retained-image features passed approved-folder capture, disable/source loss,
  different-process restart, four views ×1,085 exact pixel samples, the original
  6,555-byte export and selection restoration. Root reviewed seven images.
  The full profile failed because its harness had no normal-Close operation;
  it stopped before the click. Retained-profile Close remains unrun.
- JPEG/PNG observer v2 failed after 323 scans over 10s missed the tiny PNG worker;
  its preview was visible. JPEG Fit/actual pixels and original 9,277-byte export
  passed again. Guest 2/cleanup 0/wrapper 143; VM stopped and lease released.
  Preserve this failure and earlier harness failures. No complete inline-PNG
  profile pass is claimed. Existing retained-PNG checks cover decoding/transport;
  no further observer iteration gates 201 adoption. The next combined candidate
  will validate inline-PNG pixels/export/Back and report the observation gap.
  Final failure receipt is `build/gc512-native-png-observer-v2/jpeg-png/run-01/failure-result.json`
  (fca873e1); root reviewed four images. PNG pixels/Back/export and Close are unrun.
- The adjusted Child chrome gate passed all three assertions on Mac (`7b6bdfe6…`),
  with empty compiler/runtime diagnostics and exact inputs/pins. Export remains
  (552,96). The original environment-preflight failure (`f7844bbd…`) is preserved.

Public drafts and exact inventory: `build/native201-publication-terminal`.
The immutable baseline is `build/native201-publication-bundle-v3` (seal 811a09b2).
The 47 adoption paths and 52 publication paths are unchanged. Preserve 100755
for `scripts/test` and `scripts/bend`. All three defaults now contain `943eee7e…`;
old sources/binaries are preserved in `build/native201-root-adoption/previous/`.
Adoption receipt: `build/native201-root-adoption/receipt.json` (cf5f83bb).

## Separate work, not part of this candidate

Cancellation App12 passed on Linux: active Close 5, retired Close 5 and Escape 2.
Receipt `build/attachment-cancel-native-continuation/9c4bcb26-7d59-48ae-bf93-72da7334ca92/collected/results/receipt.json`
(`c1f0d8ae…`) binds actual app events and exact cleanup replies. Native-window
pending Close is still unrun; synchronous hashing and other workers are outside
that narrow guarantee. Earlier production and Base Close failures stay recorded.

Usage metric cards passed 130 Linux assertions in compile-fix-v3 (receipt42719aa3):
19 summary, 19 interaction, 20 existing UI, 47 controller and 25 list-row.
The pure Bend cards remain grounded in the Swift app's information hierarchy.
A separate 206-input combined candidate is building on Mac with these cards,
list polish, cancellation and event-seal bytes through the maintained preload.
It still requires fresh native review; its tests do not revalidate the 201 app.

The byte-oriented event-seal candidate passed 73 focused and 1,611 preservation
checks, including 27 crash cuts. The four-test collector correction is additive;
its original failure remains preserved. One same-physical-Mac benchmark pair
measured baseline/candidate import 45.304/42.028s, unchanged 4.405/5.570s and
16-record append 28.252/26.535s for 100k records. Exact bytes, prefix identities
and seals matched. This modest single-pair result does not solve slow append or
establish statistical significance. It is unadopted and outside the 201 bundle.
Receipt: `build/event-seal-bytes-integration/mac-paired-01/receipt.json` (0b0402d5).

## Exact continuation

1. For further PR updates, refresh head/draft status and publish only explicit paths,
   preserving script modes, parent history, unrelated files and root HEAD/index.
   Verify the published app closure. Keep PR draft and unmerged.
2. The command `python3 build/combined206-mac/runs/4f49b7aa-34e5-4476-90f9-824a7bd97875/run-mac.py`
   is already running in session 26497. Collect logs, receipt and process status
   from that directory first; do not restart if active. See `build/combined206-mac/HANDOFF.md`.
   Then exercise the combined app. Screenshot Usage Overview before Command+A switches to
   Report; validate both copy paths and drill-down. Test actual pending Close.
   Do not overlap Tart with compilation or claim unrun inline-PNG checks passed.

Missing glyphs, shaping/IME, accessibility, resizing, latency, Usage charts/date/
costs and broader parity remain open. Current focused gates are not a fresh
full-suite/proof run. No Swift performance comparison or goal completion is claimed.
