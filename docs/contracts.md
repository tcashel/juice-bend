# Shared implementation contracts

All application behavior is Bend. SQLite bridge executes supplied prepared SQL;
it contains no application SQL, parsing, indexing or provenance policy.

Durable evidence key: provider + source locator + generation + accepted snapshot
extent + physical record ordinal + event ordinal. Database integer identities
cross FFI as canonical decimal strings. U32 is only for validated bounded page,
chunk and file offsets; File.size rejects sources above UINT32_MAX.

Source rows never merge based only on provider session ID or content. A verified
exact append retains generation and old snapshots. Any changed prefix/truncation
creates a new generation. Raw chunks and publication are transactional; normalized
events and FTS are projections, never authority. A selected snapshot never follows
latest implicitly.

Listing pages contain at most 100 rows and a same-transaction one-row
lookahead. CLI `offset` and `limit` are JSON numbers; `has_more` is Boolean.
Identifiers and SQLite quantities remain exact decimal strings in row cells.
The maximum listing offset is 4294967195 so the lookahead cannot wrap U32.
Saved versions are anchored to one exact source across its generations, ordered
by descending accepted snapshot ID. `latest SNAPSHOT` resolves an explicit
navigation target; a missing or foreign pointer is an error. The GUI retains
the prior reader until the newly requested snapshot passes its normal read.

`storage` returns a structured inventory plus readable text. Its row/page
counts share one SQLite read transaction; main/WAL/SHM file lengths are later
non-atomic samples. Logical sizes and reusable pages overlap and cannot be
summed into physical reclaimable storage. Inventory never changes selection,
purges raw data, checkpoints, or runs VACUUM.

Provider interface: `Providers.parse(provider: String, raw: String)` returns
`List<&2, Providers.Record>`; its `ProviderEvent` constructor has role, text, tool, call_id, arguments, result, repository,
session, timestamp, model, usage, parent, coverage (all String). Unknown fields
remain retained in the original raw bytes. No filesystem reads in providers.
The JSON parser must preserve number lexemes and expose parse errors.

SQLite interface: `Sql.open(path)` returns Result(U32 token), `Sql.query(token,
sql, bindings, max_rows)` returns Result(List(List(Cell))), `Sql.close(token)`
returns Result(Unit). Cells distinguish Null, Integer(String), Text(String),
Blob(List<&2,U32>), Real(String). Tokens are checked registry IDs, never pointers.
Queries bind all values; multiple statements are refused. Rows/bytes are bounded.

UI consumes storage/search functions and retains exact selected evidence keys.
Text state uses committed Text events. Copy exports underlying Unicode, never
glyph approximations. Renderers may show explicit missing-glyph boxes.

Recorded activity uses the same retained raw/context validation and frozen
scope. `activity-scope` accepts 1–100 physical records; the GUI requests 40.
Its envelope carries provider, canonical source locator, generation, snapshot
and extent as strings; bounded record counts and ordinals are JSON numbers.
The reader owns one deferred read transaction and refuses an existing caller
transaction. Missing or stale context checkpoints require verified rebuild;
there is no unbounded prefix replay in this interactive path. Selected events
are capped at 256 and 512 KiB of UTF-8; rendered text and the final escaped CLI
response are each bounded to 1 MiB. Exceeding a bound fails the whole page.

Calls/results remain separate cited occurrences. A unique ordered counterpart
requires the same provider, source, generation, snapshot, extent, session,
absolute repository and call ID. Duplicate, missing, order-conflicting or
type-uncertain IDs remain unresolved. The current normalizer cannot distinguish
some scalar/container-looking strings from coerced IDs, so pairing conservatively
withholds those cases. Recorded errors are explicit; recorded results are not
proof of successful execution. One canonical string serves display/copy/export.

No real home history scan by default. Synthetic demo and tests use explicit,
isolated data directories. Original Juice and source repositories are read-only.
