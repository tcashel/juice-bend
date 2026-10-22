# Decisions

- **2026-10-21 — Preserve archive containers and logical evidence separately.**
  Bend decodes Zstandard; schema 3 atomically retains the exact container and
  decoded JSONL with an immutable snapshot. Citations keep logical source-byte
  offsets. Full JSONL and compressed-container exports have distinct labels and
  remain available after source loss. The initial 1 MiB compressed / 4 MiB decoded
  profile is explicit; larger archives remain a parity gap. Old schema-2 builds
  are fenced at startup, not through connections they already opened.
- **2026-10-21 — Put Brief facts before supporting detail.** Format v2 puts the
  recorded request first, omits exactly empty fields, and moves full policy/scope
  and citations after the facts. The full preview, including those details,
  remains inside the existing byte bound and copy/export revalidation contract.

- **2026-10-21 — Freeze and recheck continuation briefs.** The explicit repository,
  capture, range and filters bind an 8,192-byte preview of retained recorded facts.
  Eligibility, omissions and pattern-based withholding are disclosed. Copy and
  export revalidate the full preview commitment; root/selection changes and Back
  retire pending effects. Ordinary Copy keeps scalar selection semantics; the
  whole-brief action copies all checked text. No inferred task or model runs.

- **2026-10-20 — Bound verification without changing captured identity.** Raw
  checks select at most 128 mappings and approximately 1 MiB before reading one
  contiguous source span; contexts insert at most 32 rows per statement. Every
  digest, typed field, ordinal, extent, full source pass and transaction boundary
  remains checked. The aligned Bend SHA path preserves the existing digest and
  streaming-buffer contract; native vectors and fresh kernel verdict pass.
- **2026-10-20 — Separate list navigation from retained reads.** History/search
  and saved-version pages have their own offset. Paging preserves the current
  reader; only explicit capture selection or Open latest changes its snapshot.
  Storage reports owned logical sizes/counts and preserves selected identity;
  it does not claim physical reclaimable space or perform maintenance.
- **2026-10-20 — Pin repository browsing.** The standalone browser resolves a
  commit once, then reads bounded literal paths/objects at that revision. Git
  replacement objects, lazy fetching and pathspec expansion are disabled. This
  backend remains separate from the current GUI until its navigation is wired.

- **2026-10-20 — Local macOS execution.** The owner's execution update supersedes
  the cloud host instructions. No cloud execution is needed for this app.
- **2026-10-20 — mise and exact source pin.** `mise.toml` pins Bun 1.4.2;
  `scripts/setup` selects Bend commit
  `60ca80aedeec9d8f0629b5f10dd19457d8ad67af`. Compiler telemetry is disabled.
  All build caches remain local to this repository.
- **2026-10-20 — Explicit native link.** Bend emits C; `scripts/build` applies
  the inspected upstream CPU flags plus `-lsqlite3`. Objective-C mode is used
  only when the generated upstream runtime contains framework imports.
- **2026-10-20 — Proof cache locality.** `scripts/prove` checks ordinary laws
  and proofs, builds the upstream Lean kernel locally when Lean 4.34.0 is
  available, then passes `BENDTT` to `--verdict`. Missing kernel prerequisites
  remain a failed gate; ordinary checking is recorded separately.
- **2026-10-20 — Test launch isolation.** Each native Bend test/benchmark gets a
  fresh temporary working directory. Shell wrappers own compilation/launch;
  fixtures, assertions, timings and statistics stay in Bend.
- **2026-10-20 — Canonical source identity.** Public import resolves the
  explicitly selected path through `/bin/realpath` before opening or registering
  it. Relative and symlink aliases converge; separate hard-link paths remain
  conservative separate sources. No private root is selected automatically.
- **2026-10-20 — Verified, non-replacing exports.** Complete raw export verifies
  every retained record inside a read transaction before writing a private
  sibling temporary file. `/bin/link` publishes it atomically only if the exact
  destination does not exist; this also rejects dangling symlinks and files
  created after preflight. Bounded text exports use the same publication path.
- **2026-10-20 — Indexed projection cursor.** Projection verification uses the
  composite `(ordinal,event)` range to seek beyond its previous page. Native
  regressions preserve the previous checksum across record and byte limits;
  the raw/context verification and immutable snapshot contract are unchanged.
- **2026-10-20 — Explicit linear capture observer.** Fault tests consume and
  return a Bend observer handle at nine real transaction boundaries. The app
  supplies `Unobserved`; no environment flag, native hook or alternative capture
  implementation enables faults. Process timeouts kill only owned synthetic
  children, and exact boundary markers are required before accepting a case.
- **2026-10-20 — Bounded SQL publication.** Native guest capture exposed a
  SQLite interrupt during large FTS publication. Bend now publishes/copies at
  most 64 event rows and approximately 1 MiB per statement, deletes FTS rows in
  at most 128-row/1 MiB batches, and copies record mappings in 256-row batches.
  One oversized row can advance a batch. Existing outer transactions, exact
  cursors and the bridge's two-second deadline remain unchanged. A final native
  100,016-record capture and retained rebuild passed; 131 new checks cover batch
  boundaries, signed rowids and rollback after a late failure.
- **2026-10-20 — Monotonic refresh and idle scheduling.** Automatic refresh uses
  a 30-second monotonic deadline, disarmed during forms, pause and writer work.
  Only event-free, clean, work-free GUI ticks sleep 80 ms; active ticks retain
  1 ms. This reduced measured settled guest CPU use, but does not establish
  input-to-display latency. No native runtime/input adapter was changed.
- **2026-10-20 — Coordinated local Tart validation.** The owner authorized the
  installed external-SSD VM and its required sandbox exception. The existing
  VM user released it before our nonce-owned lease; only synthetic payload and
  results were shared, with host-only networking. The app closed, the owned VM
  stopped, both shared locks were absent, and the other chat was notified.
- **2026-10-20 — Bounded retained Related navigation.** Relationship pages pin
  accepted-capture watermarks and exact target references. Recorded parent IDs
  and path associations stay distinct; coverage/ambiguity never imply a complete
  graph. Two saved navigation levels restore the exact origin. A Bend list holds
  the saved navigation indirectly to respect the pinned compiler's continuation
  arity bound. Native UI validation and focused tests have separate receipts.
- **2026-10-20 — Context-prefix hashing.** Reuse only identical complete header
  blocks within the existing bounded context batch. Keep the scalar digest as
  the comparison oracle, all predicates, both raw passes and transaction limits.
  The measured long-session improvement is small; no append-complete claim.
- **2026-10-20 — Portable context checkpoints.** Bind the derivative checkpoint
  to exact source/generation/raw identity instead of the containing snapshot.
  Retain V1 validation and conservative old-writer replay. A verified prefix
  may be copied only within one write transaction, with typed bidirectional
  equality and a final post-publication gate; triggers force a full scan.
  Preserve both source passes. Native compatibility and adversarial tests are
  separate from performance evidence; no speedup follows from the design alone.

- **2026-10-21 — Whole-capture Usage.** Retain exact snapshot identity in an owned
  deferred read transaction; stream bounded verified raw windows, expose unknown
  buckets and attribution separately, and preserve exact origin navigation.
  Back discards late view replies without spawning overlapping read workers.
  Repository/role/date filters refuse an unfiltered summary. Usage suspends
  automatic capture until History is restored; the UI must state this clearly.
- **2026-10-21 — Profile before further append changes.** The owner accepts
  tens-of-seconds initial import and prioritizes product parity and UX over
  marginal append tuning. The native CPU sample identifies string/reference
  costs but does not isolate append-only attribution. Keep raw traces private.
- **2026-10-21 — Upstream guidance.** Inspected the pinned guide/Base and public
  [Bend README](https://github.com/bendlang/bend) and
  [agent guidance](https://github.com/bendlang/bend/blob/main/AGENTS.md), plus
  [Victor Taelin's repositories](https://github.com/VictorTaelin). The actual
  pin uses linked character lists; append/drop/get can traverse them. The shader
  guide records a 247-word continuation/definition limit, relevant to boxed GUI
  state tests. No packaged official Bend skill was found in the searched repos.
  This is a bounded search, not exhaustive absence. Native compilation and
  actual interaction remain required; checker success alone is insufficient.
- **2026-10-21 — Native typography and retained navigation.** Keep all rendering,
  hit testing, text selection, wrapping and status inspection in Bend. A pinned
  open font is packed offline into static grayscale glyph data; the app loads
  neither a font engine nor a JavaScript runtime. Share one geometry contract
  across drawing and input. Files saves one boxed UI bookmark, clearing transient
  modifiers/drag without retaining an old image. Returning to an accepted History
  reader preserves text selection and exact capture identity without a reread;
  an explicit provider click still overrides the saved listing scope.

- File/commit request eligibility is a read-time policy over verified raw/event
  correspondence. It never rewrites normalized role/text or citation ordinals.
  Known context/relay/meta records remain readable; uncertainty before the first
  request stays ineligible. Why distinguishes exact request suffix previews
  from bounded retained excerpts and makes no human-authorship claim.

## Bend compiler representation boundaries

Long string patterns in a multi-case match expand into character/bit constructor
trees in the pinned compiler. For command/type labels, use String.eq and separate
bounded numeric/operand matching when measurements show pathological expansion.
Keep exact accepted strings, arity, fallback and coverage behavior; do not weaken
validation or patch the compiler to make the build pass.

The native compiler also flattens nonrecursive records across continuations.
An observed 260-slot preview input join exceeded its fixed 247-slot limit.
Boxing the exact pending value before UI.event with a persistent List resolved
the full-app code-generation error without changing schemas or state semantics.
Native optimized clang failures remain a separate issue; -O0 correctness builds
are not optimized performance evidence.
