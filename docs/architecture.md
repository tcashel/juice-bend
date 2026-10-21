# Architecture

Juice Bend is a native Bend 2 application. The compiler's generated C and upstream
window/runtime implementation are build artifacts and dependencies. The only
maintained native adapter is the narrow SQLite bridge. It accepts typed values
and prepared statements; application SQL and policy remain in Bend.

[Shared contracts](contracts.md) define interfaces and durable evidence identities.
Preserved source bytes are authoritative. Search, transcript and provenance
projections must remain bound to accepted immutable generations and snapshots.
Selected evidence never silently follows a mutable latest pointer.

`capture.bend` validates the provider and canonical source path, then dispatches
the exact `.jsonl.zst` suffix to `archive_capture.bend` and plain sources to
`store.bend`. Store owns shared SQL orchestration, raw records and publication;
`providers.bend` normalizes logical JSONL without replacing retained bytes.
`archive_capture.bend` owns bounded decompression, container/prefix comparison
and the final retained-transform and projection guards. Changed archives replay
the complete bounded logical stream; unchanged containers retain their snapshot
without another decode or parse. Recompression creates a new generation even
when its logical bytes match an earlier capture.

`src/zstd/` contains the Bend decoder: framing, raw/RLE/ordinary compressed
blocks, Huffman/FSE and repeat tables, LZ copies and checksums. It supports
concatenated and skippable frames without an external decoder process or new
native bridge. Dictionaries are unsupported. Its initial archive profile is
1 MiB compressed input, 4 MiB logical output, an 8 MiB advertised window,
64 frames total and 4,096 blocks per ordinary frame. These are explicit bounds,
not a claim of full archive parity.

`archive_meta.bend` owns schema-3 archive metadata and typed validation. Each
archive snapshot retains independently hashed compressed-container chunks and
logical source records in SQLite. The origin commitment binds both streams to
the exact provider, locator, source, generation, snapshot, quantities and
profile. Records and citations address `logical_source_bytes`; container
exports address `compressed_container_bytes`. A chunk query bounds BLOB
admission to 64 KiB before bridge transfer, while Bend validates the complete
chunk and origin. This is not a SQLite pager-memory bound.

Store's legacy migration and the archive migration each recheck the typed
schema version after acquiring the write lock. A waiting stale observer cannot
downgrade schema 3 or repeat its migration. Existing identity captures retain
their IDs and raw bytes. The tested older executable refuses to open schema 3 at
startup; already-open older connections are outside that fence.

`maintenance.bend` verifies accepted logical extents, rebuilds derived state
and streams complete logical exports. `archive_maintenance.bend` verifies owned
containers, checks their exact decode against retained logical bytes and exports
the original compressed container. These operations remain available after the
source disappears. Export publication uses a private sibling temporary file
and an atomic filesystem link, so an existing destination is never replaced.
`paths.bend` canonicalizes explicitly selected source paths before assigning
source identity. No home history path is inferred.
`sources.bend` persists enabled roots and bounded discovery queues. Native
worker processes execute the same Bend import command so one missing or failed
source becomes a reportable result while previous captures remain available.

`scoped_reader.bend` keeps provider, repository, role and date filters attached
to selected snapshots, transcript ranges and bounded evidence exports. It applies
the shared normalization and scope predicates to retained records, never to quoted SQL
projection fields. Repository context checkpoints are created during real raw
parsing. V1 checksums bind the snapshot; V2 binds the parser, source/generation
and exact retained raw identity so an unchanged prefix can be copied without
resealing every row. A read validates the accepted snapshot mapping, matching
versioned binding and selected raw record/predecessor. `context_binding.bend`
owns the pure codec; `context_store.bend` owns bounded typed scans and the
transaction-local reuse gate immediately before commit.
Missing legacy checkpoints fall back to verified prefix replay; damaged current
checkpoints fail explicitly. Rebuild creates checkpoints only after complete
raw verification. These checks detect corruption relative to trusted metadata;
they do not authenticate a database whose data and checksums were both replaced.

The UI and CLI consume the same storage, provider and provenance modules.
`Export evidence` keeps the bounded range/scope contract. `Export full JSONL`
and `Export archive` invoke `export-all` and `export-container` through the same
serialized Bend worker. Both require an opened History transcript, pin its
snapshot and disclose that they include records outside the current filters.
The archive action rejects identity captures. Exact typed acknowledgments bind
the destination, snapshot, format, byte space and verification level before the
GUI reports success. Native archive-window acceptance remains pending; focused
decoder/storage/state suites do not establish a final merged-app test result.

`catalog.bend` resolves accepted saved versions for one exact source and an
explicit latest target. Result and version pages use a bounded lookahead in the
same SQLite read transaction; navigating the listing never silently changes a
pinned reader. `storage_inventory.bend` reads owned row/page counts and samples
only the main database and its WAL/SHM sibling lengths. Compressed-container
counts and bytes are separate from logical raw-byte counts. Its logical/reusable
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
