# Architecture

Juice Bend is a native Bend application. The compiler's generated C and upstream
window/runtime implementation are build artifacts and dependencies. The only
maintained native adapter is the narrow SQLite bridge. It accepts typed values
and prepared statements; application SQL and policy remain in Bend.

`docs/contracts.md` defines shared interfaces and durable evidence identities.
Preserved source bytes are authoritative. Search, transcript and provenance
projections must remain bound to accepted immutable generations and snapshots.
Selected evidence never silently follows a mutable latest pointer.

`store.bend` owns SQL orchestration and immutable capture; `providers.bend`
normalizes supported records without replacing retained bytes. `maintenance.bend`
verifies complete accepted extents, rebuilds only derived state, and streams
raw exports. Export publication uses a private sibling temporary file and an
atomic filesystem link, so an existing destination is never replaced.
`paths.bend` canonicalizes explicitly selected source paths before assigning
source identity. No home history path is inferred.
`sources.bend` persists enabled roots and bounded discovery queues. Native
worker processes execute the same Bend import command so one missing or failed
source becomes a reportable result while previous captures remain available.

`scoped_reader.bend` keeps provider, repository, role and date filters attached
to selected snapshots, transcript ranges and exports. It applies the shared
normalization and scope predicates to retained records, never to quoted SQL
projection fields. Repository context checkpoints are created during real raw
parsing and bound by checksums to the snapshot, parser version and selected raw
identity. A read verifies that binding and the selected raw record/predecessor.
Missing legacy checkpoints fall back to verified prefix replay; damaged current
checkpoints fail explicitly. Rebuild creates checkpoints only after complete
raw verification. These checks detect corruption relative to trusted metadata;
they do not authenticate a database whose data and checksums were both replaced.

The UI and CLI consume the same storage, provider and provenance modules.
`catalog.bend` resolves accepted saved versions for one exact source and an
explicit latest target. Result and version pages use a bounded lookahead in the
same SQLite read transaction; navigating the listing never silently changes a
pinned reader. `storage_inventory.bend` reads owned row/page counts and samples
only the main database and its WAL/SHM sibling lengths. Its logical/reusable
numbers are not estimates of physical disk space that could be reclaimed.
Tests exercise these production modules through Bend-native entry points.
`LAWS.bend`/`PROOF.bend` depend only on the pure production functions they verify;
runtime effects, SQLite, compiler translation and native interaction remain
outside the proof boundary.
The upstream proof kernel uses Lean only during development. The app, UI and
its same-executable workers contain no Lean runtime dependency.

`mise.toml` organizes repository tasks. `scripts/bend` hosts the pinned compiler;
`scripts/build` produces native executables; the other wrappers launch the
application, Bend tests, proofs and benchmarks. They contain no product parsing,
capture, search, provenance or benchmark calculations.
