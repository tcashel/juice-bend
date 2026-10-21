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

The derivative event seal is `event-seal-v1`; schema version 2 and the
provider parser remain unchanged. A full typed scan binds actual event
rows, exact snapshot/source/generation identities, extent, checkpoint and counts.
Its freshly verified complete-record prefix may be carried only through the
same uninterrupted write transaction. Before reuse, copied maps/events must
match in both directions, including SQLite storage types; the unfinished tail
is parsed again. Main/temp triggers force full fresh sealing. Missing, damaged
or older seals take verified raw replay; malformed new state fails/rolls back.
Older writers safely treat the new version as unfamiliar and replay too.
IDs remain signed-64-bit decimal strings; bounded event counts are checked U32.

New context checkpoints use `incoming-context-v2`: the parser, provider,
canonical locator, source and generation bind the exact raw ID, ordinal,
offset, length, raw digest and incoming context fields. The accepted snapshot
still selects and validates the raw mapping. V1 snapshot-bound checkpoints
retain their exact validator; old-format append takes verified raw replay.
Unknown selected formats fall back to verified prefix replay. Unchanged refresh
never silently migrates an accepted capture. This changes only a derivative
checkpoint format, not raw bytes or public evidence identities.

A fresh complete typed context scan can authorize copying unchanged checksums
only on the same connection and uninterrupted `BEGIN IMMEDIATE`. The witness
is an affine internal contract, not an opaque security boundary. Before COMMIT,
old headers and prefix raw maps/context must still match in both directions,
including types; the fresh tail is validated. Main/temp triggers force a full
target scan. The final context gate follows all publication SQL and BeforeCommit
observers. Rebuild also gates context after refreshing search. Both complete
raw/source comparison passes remain in capture. Privileged callbacks replacing
trusted anchors and checksums are outside the corruption guarantee.

Context queries inspect at most 32 candidates. Counted context/digest payload
uses a 1 MiB budget with a first-row progress exception and fixed metadata
allowances. Those allowances are not allocation measurements or guarantees for
malformed metadata; the bridge separately rejects transport above 4 MiB. There
is no 1 MiB total-memory or SQLite-work claim. Cursors continue strictly after
the last accepted key, including fractional/mistyped keys between valid rows.
Only complete identical header blocks are cached for hashing.

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

Related captures own a deferred read transaction and reject an existing caller
transaction. The anchor is an exact provider/source/generation/snapshot/extent
reference. A fixed accepted-ID watermark chooses one accepted capture per
candidate source across generations. A page scans at most 15 candidate sources,
up to 16 verified physical records per source plus anchor: 256 records and
2 MiB aggregate retained raw bytes. CLI output, including JSON escaping and
newline, is bounded to 1 MiB. Partial/skipped/conflicting/unsupported coverage
is explicit; a cursor advances through candidate sources rather than links.

The first Codex session metadata header controls recorded parent authority.
Later conflicting headers cannot create a new parent. Claude nested locator
association is separately labeled; parentUuid alone is not a session edge.
No parent event ordinal is invented. Ambiguity is page-local; only self/direct
two-way cycles are detected. Missing links do not prove absence or uniqueness.
Provider/repository constrain relationship discovery. Role/date remain frozen
target-reader filters and do not silently discard metadata relationships.

Native Related navigation saves the complete origin and one Related page.
Targets open exact row snapshots with the frozen filters. Back returns to the
saved page, then origin text, list/query, range, selection and scroll. Refresh
rereads the current watermark; fresh entry after Back explicitly reanchors.
Automatic capture is suspended while navigating Related. Already-running
capture completion cannot replace its anchor, page or target. Copy/export use
the same displayed string, and a loading placeholder is not exportable evidence.

Refresh preferences are a complete owned pair: `refresh.enabled` is TEXT
`true` or `false`; `refresh.interval_seconds` is TEXT `30`, `7200`, `14400`,
`28800` or `86400`. Missing keys load independent defaults without writing.
Malformed values fail visibly. Save owns an immediate transaction and requires
both exact keys and values on readback before committing; ignored writes cannot
look successful because a missing key happens to default to the desired value.
Neither operation takes over an existing caller transaction.

The GUI uses one serialized writer for capture and preference changes. It keeps
the latest desired complete pair separate from acknowledged values. Automatic
capture is disarmed while preferences are unknown, failed or pending, during
forms and while the writer is occupied. Deadlines use checked monotonic Nat
milliseconds; Pause does not cancel an active capture or disable manual Refresh.
Source mutations require exact provider/path acknowledgments and a fresh typed
inventory. A source-list operation nonce rejects older inventory replies.
Settings saves the exact originating view independently of global preferences.
Completed origins restore without another read; a request already pending at
entry resumes with its original snapshot, range and scope.

Whole-session Usage owns one deferred read transaction only after successful
BEGIN. An existing caller transaction is refused and remains untouched. The
reader pins provider/source/locator/generation/snapshot/extent/record count,
checks typed raw mappings and consumes at most 128 records/about 1 MiB per window.
Defaults stop at 1M records, 1 GiB verified bytes, 100k Claude call keys or 16 MiB of
logical key descriptors; limits yield explicit partial coverage. Known decimal
counts remain exact strings; missing buckets stay unknown. A complete byte scan
does not imply complete attribution or accounting. Claude uses exact call keys
and maxima for mirrors; Codex ordinary first totals and inherited fork baselines
are distinct. This is captured evidence, not provider billing or subscription data.

The GUI saves the exact reader origin before whole-capture Usage. Provider-only
entry is allowed; repository/role/date scope cannot silently widen. Back restores
text/selection/scroll without rereading and retires the pending view request;
the sole OS worker completes or times out before another read starts. Successful
cross-snapshot text loads clear stale view metadata, whereas failed/pending reads
preserve the old identity. Copy/export uses exact displayed evidence. Automatic
capture remains suspended during Usage; History's actual interval is observed.
