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

No real home history scan by default. Synthetic demo and tests use explicit,
isolated data directories. Original Juice and source repositories are read-only.
