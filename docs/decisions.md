# Decisions

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
