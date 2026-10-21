# Performance observations

Measured on 2026-10-20 with Bend 2.0.37 at
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`, native Apple clang `-O3`.
Backend benchmarks ran on the macOS 27.0.1 (26A434), arm64 host; the separately
identified GUI resource observations ran in a macOS 27.0 arm64 Tart guest.
The host also ran implementation/testing work. These are observations, not an
isolated machine comparison or a Swift Juice comparison. Earlier candidates
retain their own results and identities below.

Run `mise run bench -- 10000` or `mise run bench -- 100000`. The wrapper creates a
private temporary working directory. Fixture generation is Bend code and is
excluded from operation timers. Generator v1, seed 1337, creates one long
Claude-format session with varied Unicode text, integer payloads, paths,
repositories, timestamps, tool arguments/results and usage. Each four physical
JSONL records yield five normalized events. Events include tools and are not
presented as five independent human/assistant messages.

## Current backend candidate — identical context hash prefixes

The context-prefix cache preserves the exact scalar digest bytes while sharing
complete SHA blocks for each bounded context batch. Both scans and every row
comparison remain. Its [990-check native gate](receipts/context-prefix-native.txt)
and independent reviews passed. The unchanged standard 100k fixture measured
first import 33,304 ms, unchanged refresh 4,579 ms and append **27,262 ms**.
That is 3.4% below the preceding 28,226 ms observation; the small single-run
difference is not a statistical guarantee. Long-session append remains slow.
Warm search/late/scoped-late p95 were 40/8/17 ms. Five-trial p95 is the maximum.

Frozen native binary `5ecad019…` is 3,067,408 bytes. All 19 transitive inputs and
88 upstream hashes matched before/after build and run. Benchmark assertions,
independent prefix equivalence, exact counts, latest-only FTS and database
integrity passed; logical page bytes remained 216,109,056. No task build, test
or Tart workload overlapped timers; unrelated host activity was uncontrolled.
See [raw results](../benchmarks/results/100000-context-prefix.jsonl),
[build/input receipt](../benchmarks/results/100000-context-prefix-build.txt) and
[postflight](../benchmarks/results/100000-context-prefix-db-check.json).

A separate many-source fixture contains 100 independent Claude/Codex sources,
each with 1,000 physical records and 1,000 normalized events. Source paths,
session IDs and repositories are distinct; generator version 1 uses seed 1337.
This differs from the long-session fixture and is not a direct speed comparison.

| Many-source observation | Duration |
|---|---:|
| Import all 100 sources | 27,875 ms |
| Unchanged refresh of last source | 50 ms |
| Append 16 records to middle source | 477 ms |
| Warm scoped search median / p95 | 17 / 17 ms |
| Warm scoped late page median / p95 | 15 / 15 ms |

The middle source is Claude; separate small native correctness runs covered
Claude and Codex append targets with clocks disabled. The timed run preserved
all 99 untouched source/header/seal records and FTS cells/types/rowids. It also
preserved the old target page, citation and event values, verified both target
seals and shared raw IDs, and passed exact current-only index/integrity checks.
It does not compare every unrelated non-FTS context byte. Latest search contains
100,016 events; database logical page bytes are 110,604,288.

Binary `d6402fa4…` is 3,732,376 bytes, with 19 unchanged recorded inputs and
88 upstream hashes. Fixture generation and validation are outside timers; the
first search follows index validation and is not cold-cache. The fresh private
working directory is required. No task build/test/Tart overlapped timings.
See [raw results](../benchmarks/results/100000-many-sources.jsonl),
[build receipt](../benchmarks/results/100000-many-sources-build.txt) and
[postflight](../benchmarks/results/100000-many-sources-db-check.json).
These observations do not measure UI latency, memory or a 1M stress workload.

## Preceding backend candidate — reusable verified event prefix

The new event-seal candidate appended 16 records in **28,226 ms**, versus the
preceding 33,392 ms observation: a 15.5% reduction. Append remains slow. This is
one observation per version, not a statistical or Swift Juice comparison. The
same unchanged generator, 100k workload and assertions were used. Both full
raw/source verification passes remain; a freshly verified event-chain prefix
is reused only within one uninterrupted write transaction, after typed equality
checks of the copied prefix. Legacy or damaged seals use verified full replay.

| Observation | Event-seal candidate |
|---|---:|
| First import | 32,940 ms |
| Unchanged refresh | 4,519 ms |
| Append 16 raw records / 20 events | 28,226 ms |
| Warm scoped search median / p95 | 39 / 41 ms |
| Warm late page median / p95 | 7 / 8 ms |
| Warm repository-scoped late page median / p95 | 16 / 17 ms |
| Existing database reopen and status | 16 ms |

The native executable is `28d47af5f8b8f0f96090df70850247c13496ef29167b415a3c33909cf5ae915b`
(3,032,536 bytes). All 19 transitive source/build inputs and 88 upstream hashes
were verified before/after build and execution. No task build, test or Tart
workload overlapped operation timers; unrelated host activity was uncontrolled.
The child and orchestration both exited 0. Independent read-only SQLite checks
passed integrity, foreign keys, exact raw/map/event/context/current-FTS counts,
and old/new prefix-event equality in both directions. There were two accepted
snapshots and 125,020 current search events; logical page bytes stayed 216,109,056.
Five-trial p95 is the observed maximum. UI latency and memory are not measured.

See [raw results](../benchmarks/results/100000-event-seal.jsonl),
[build receipt](../benchmarks/results/100000-event-seal-build.txt),
[database checks](../benchmarks/results/100000-event-seal-db-check.json) and
[correctness gate](receipts/event-seal-native.txt).

The subsequent [production observer diagnostic](../benchmarks/append_observed.bend)
measured 28,352 ms from import entry through commit on a fresh 100k fixture.
It calls the unchanged production import path, accumulates nine boundary clock
samples, and prints them only at commit. There are no per-record clock calls.

| Interval ending at | Duration |
|---|---:|
| Before transaction | 1 ms |
| Staged | 20,466 ms |
| Raw reverified | 4,446 ms |
| Projection sealed | 1,022 ms |
| Accepted | 0 ms |
| Old search removed | 875 ms |
| Latest repointed | 0 ms |
| Before commit | 1,166 ms |
| Committed | 376 ms |

These are aggregate production phases, including callback overhead. Staging
includes old-capture verification, copied projection/context work and tail
parsing; it is not a SHA-only measurement. Sealing includes header, trigger and
prefix comparisons. The nine deltas sum to the observed total. Fixture setup,
independent preflight and postflight checks were outside the timer. The native
binary `ef008e1f…`, 20 inputs and 88 upstream hashes stayed unchanged. Both event
seals, 100k shared raw IDs, all old typed capture fingerprints, database counts,
foreign keys and integrity passed. No task build, test or Tart workload overlapped
the timer. One observed run identifies the next profiling target, not a latency
guarantee. The 400-record correctness mode has timing disabled; its zero values
are not measurements. See [raw phases](../benchmarks/results/100000-append-observed.jsonl),
[build receipt](../benchmarks/results/100000-append-observed-build.txt) and
[postflight](../benchmarks/results/100000-append-observed-db-check.json).
The shared-projection prototype remains unintegrated.

## Preceding backend candidate — bounded verification and aligned SHA

The immutable optimized candidate appended 16 records in **33,392 ms**, compared
with the published baseline's 40,103 ms. This is an observed 16.7% reduction,
not an isolated statistical comparison; append remains slow. Full integrity
checks and the unchanged benchmark assertions were retained.

| Observation | 100k candidate |
|---|---:|
| Source physical records / normalized events | 100,000 / 125,000 |
| Source bytes | 35,601,602 |
| First import | 32,780 ms |
| Unchanged refresh | 4,547 ms |
| Append 16 raw records / 20 events | 33,392 ms |
| Warm scoped search median / p95 | 39 / 41 ms |
| Warm late page median / p95 | 7 / 8 ms |
| Warm repository-scoped late page median / p95 | 17 / 18 ms |
| SQLite logical page bytes after append | 216,109,056 |
| Existing database reopen and status | 16 ms |

The benchmark child exited 0. Independent read-only SQLite checks found
`quick_check=ok`, no foreign-key violations and the exact two-snapshot raw,
projection, context and latest-search counts. No task builds, tests or VM ran
over these operation timers; unrelated host activity was not controlled.
Five-trial p95 is the observed maximum. Native UI latency is not measured here.

The executable remained SHA-256
`ef5f01f9605b52bc7e00060134bf65e0a9c9039955803d9dd2416f157a8c7af6`
(2,816,072 bytes). Its 18 build inputs and 88 upstream files matched at build.
An approved Git pathspec correction changed `src/provenance.bend` during the
run; the other 17 inputs and upstream files remained unchanged. The benchmark
does not invoke Git. These measurements identify the frozen executable, not a
claim that every working-tree source remained unchanged; the orchestration's
post-run hash check correctly reported that edit.

See [raw results](../benchmarks/results/100000-aligned.jsonl),
[build and input receipt](../benchmarks/results/100000-aligned-build.txt), and
[independent database checks](../benchmarks/results/100000-aligned-db-check.json).
The batching-only diagnostic separately reduced append from 42,784 to 35,657 ms;
it times internal phases and is not substituted for this standard benchmark.
Aligned SHA microbenchmarks improved, but their gains are not extrapolated to
the application's end-to-end timing. A shared-projection prototype is separate
work, not integrated or included in these results.

## Published backend baseline — bounded SQL batches

The final working-source benchmark completed successfully in a fresh isolated
library. Warm search and late-page reads passed the provisional backend
targets, while appending 16 records to the long history still took 40.1 seconds.

| Observation | 100k current source |
|---|---:|
| Raw records / normalized events before append | 100,000 / 125,000 |
| Source bytes before append | 35,601,602 |
| Empty database open | 9 ms |
| First import | 35,570 ms |
| Unchanged refresh | 6,831 ms |
| Append 16 raw records / 20 events | 40,103 ms |
| First scoped search after import | 39 ms |
| Warm scoped search median / p95 | 39 / 39 ms |
| First beginning / middle / late page | 8 / 8 / 8 ms |
| Warm late page median / p95 | 8 / 8 ms |
| First repository-scoped late page | 18 ms |
| Warm repository-scoped late page median / p95 | 18 / 18 ms |
| SQLite logical page bytes after append | 216,109,056 |
| Existing database reopen and status | 16 ms |

All expected-count, unchanged-identity, selected-range and scope assertions
passed. The library retained two accepted snapshots; the latest held 100,016
physical records and 125,020 normalized events. The full test suite and Tart
session finished before the run, and no other task builds/tests overlapped the
operation timers. The host was not otherwise isolated. Five-trial p95 remains
the observed maximum, not a population estimate. These are backend measurements,
not GUI latency or memory figures.

All 31 source/build-input hashes were captured before build/run and verified
unchanged afterward. The benchmark executable identity was captured only after
completion: 2,335,648 bytes, SHA-256
`35fe14921388db47a3965dfdbc9f6bb3742e6023f2d03ce9287ea2ffa45407aa`.
Its build duration was not separately measured. See the
[raw results](../benchmarks/results/100000-sql-batches.jsonl),
[build identity and method](../benchmarks/results/100000-sql-batches-build.txt),
and [source manifest](../benchmarks/results/100000-sql-batches-sources.sha256).

## Historical backend candidates

| Observation | 10k baseline | 100k baseline | 100k FTS schema v2 | 100k verified-context baseline |
|---|---:|---:|---:|---:|
| Raw records / normalized events | 10,000 / 12,500 | 100,000 / 125,000 | 100,000 / 125,000 | 100,000 / 125,000 |
| Source bytes before append | 3,545,358 | 35,601,602 | 35,601,602 | 35,601,602 |
| Empty database open | 8 ms | 5 ms | 7 ms | 18 ms |
| First import | 3,004 ms | 43,780 ms | 26,945 ms | 56,525 ms |
| Unchanged refresh | 637 ms | 10,916 ms | 7,305 ms | 10,860 ms |
| Append 16 raw records / 20 events | 1,238 ms | 20,109 ms | 16,283 ms | 71,368 ms |
| First scoped search after import | 27 ms | 345 ms | 37 ms | 59 ms |
| Warm scoped search median / p95 | 24 / 26 ms | 334 / 340 ms | 37 / 38 ms | 59 / 60 ms |
| First beginning / middle / late page | 8 / 9 / 8 ms | 7 / 7 / 7 ms | 7 / 7 / 8 ms | 13 / 12 / 14 ms |
| Warm late page median / p95 | 7 / 8 ms | 6 / 7 ms | 9 / 9 ms | 13 / 20 ms |
| First repository-scoped late page | Not measured | Not measured | Not measured | 35 ms |
| Warm repository-scoped late page median / p95 | Not measured | Not measured | Not measured | 25 / 30 ms |
| SQLite logical page bytes after append | 19,480,576 | 193,630,208 | 179,728,384 | 224,432,128 |
| Existing database reopen and status | 4 ms | 22 ms | 18 ms | 23 ms |

Raw results: [10k baseline](../benchmarks/results/10000.jsonl),
[100k baseline](../benchmarks/results/100000.jsonl),
[100k FTS v2](../benchmarks/results/100000-fts-v2.jsonl), and
[verified-context baseline](../benchmarks/results/100000-context-v1.jsonl). Search and warm late-page statistics
use five trials; p95 is the nearest-rank fifth value, so it is the observed
maximum of this small sample. Other operations have one final-run observation.
All measurements use the upstream monotonic millisecond clock. “First” means
the first invocation in that sequence; imports/verification have already warmed
filesystem/database caches. There is no disk-cold claim.

Search returns at most 100 rows, with provider, repository, role and date
filters. The benchmark checks every returned row's scope and the independent
expected normalized-event counts. Pages contain 100 physical records, normally
125 events, and verify retained raw bytes before formatting. The benchmark
checks independently named first records at beginning/middle/end. It also
checks unchanged snapshot reuse and the actual append snapshot/record/event
counts before reporting them.

The projection-checksum cursor subsequently changed from
`ordinal > ? OR (ordinal = ? AND event > ?)` to the equivalent tuple comparison
`(ordinal, event) > (?, ?)`. With separate bound ordinal parameters, SQLite
used only the snapshot prefix of the composite key for the former predicate;
the tuple permits a range seek. A read-only diagnostic traversed the same
125,000 synthetic events in 1,955 queries. The prior query used 887,951,664 VM
steps and took 6.40/6.15 seconds; the tuple used 32,528,654 steps and took
0.597/0.597 seconds. These SQL-only observations exclude Bend hashing and
file verification, and are not full-application savings estimates.
[Exact plans and method](../benchmarks/results/projection-cursor-plan.txt)
are retained. Twelve native regression assertions compare the entire
production checksum against the prior traversal, including page boundaries
within one physical record, corruption immediately after those boundaries,
byte-limited batches and empty snapshots. Row ordering, payload bounds,
checksum encoding, raw verification and context checks are unchanged.

A fresh run of the immutable tuple-cursor candidate completed all benchmark
assertions. Its [raw results](../benchmarks/results/100000-projection-tuple.jsonl)
and [source/executable identities](../benchmarks/results/100000-projection-tuple-build.txt)
are retained separately from the baseline. This candidate predates the later
capture-publication observer work.

| Observation | Verified-context baseline | Tuple-cursor candidate | Historical observer + tuple candidate |
|---|---:|---:|---:|
| First import | 56,525 ms | 37,499 ms | 36,381 ms |
| Unchanged refresh | 10,860 ms | 7,047 ms | 7,019 ms |
| Append 16 raw records / 20 events | 71,368 ms | 40,999 ms | 39,945 ms |
| Warm scoped search median / p95 | 59 / 60 ms | 48 / 48 ms | 49 / 51 ms |
| Warm late page median / p95 | 13 / 20 ms | 8 / 8 ms | 8 / 8 ms |
| Warm repository-scoped late page median / p95 | 25 / 30 ms | 18 / 18 ms | 18 / 19 ms |
| SQLite logical page bytes after append | 224,432,128 | 224,604,160 | 224,604,160 |
| Existing database reopen and status | 23 ms | 17 ms | 17 ms |

The tuple run retained two accepted snapshots and exactly 100,016 raw records
and 125,020 events in the latest one. The affected test suites and SQL diagnostic
completed before it began. The host was not isolated, and unchanged
refresh also became faster despite not using the checksum cursor. The full
wall-time difference therefore cannot be attributed entirely to this change.

The historical run named `final-combined` includes the explicit linear capture
observer and uses the ordinary `Unobserved` application entry point. It predates
the later idle scheduler and bounded SQL batching changes. All correctness
checks passed;
all 31 source/build hashes and the executable hash were unchanged before and
after execution. Its [raw results](../benchmarks/results/100000-final-combined.jsonl),
[build identity](../benchmarks/results/100000-final-combined-build.txt), and
[source manifest](../benchmarks/results/100000-final-combined-sources.sha256)
are retained. Focused tests finished before this run; that candidate's integrated
suite and application builds started afterward.

The baseline 100k search p95 missed the provisional 150 ms target. Schema v2
indexes only current accepted snapshots and joins the FTS rowid directly to the
event rowid. The historical observer + tuple run's 51 ms p95 passed that backend
target; the five actual warm trials were 48, 48, 49, 49 and 51 ms. The append run retains 250,020 event
rows across both immutable snapshots but indexes 125,020 current events.
Backend late-page reads are below 200 ms, including near the end. Backend reopen
is not native startup-to-interactive. Unchanged refresh verifies the retained prefix without
provider decoding; append verifies that prefix, checks projection integrity,
copies projection/context rows into a new immutable snapshot and verifies the
accepted extent again. After correcting the repeated checksum-prefix scans,
these costs remain linear in the existing session. That candidate's observed
39.9-second append of 16 records was a material preservation performance
limitation despite its passing read targets. Backend durations do not establish
UI responsiveness; the separate Tart observations below cover visible input
during capture. Historical raw and event rows remain
available for pinned evidence even though historical matches are omitted from
the default FTS index.

Repository-scoped reads use raw-bound context checkpoints instead of decoding
the complete prefix to recover repository/model/session state. A separate
[isolated-copy experiment](../benchmarks/results/100000-scoped-context.jsonl)
measured 10,407 ms for a late legacy read without checkpoints and 38,702 ms to
verify/rebuild the selected snapshot. Subsequent repository-scoped trials were
20, 19, 18, 18 and 18 ms (median 18, p95 20); record-local scope trials were
19, 18, 18, 19 and 19 ms (median 19, p95 19). That test checks independently
expected counts of 9 and 25 visible events at physical record 99,900.
Its copied database was 199,024,640 logical bytes after rebuilding one snapshot;
it is distinct from the historical fresh database with both snapshots checkpointed.

## Historical baseline source size and native builds

This historical source audit at 2026-10-20 20:00:46 UTC uses physical newline counts,
including comments and blank lines, and exact file bytes. The
[per-file inventory](receipts/code-size.tsv) records every counted path and
SHA-256; categories do not overlap. No cached test binaries or repeated generated
C outputs are included in application source counts. These counts predate the
current combined app; its 9,091,528-byte build is recorded separately in
[the combined receipt](receipts/seal-tools-native.txt).

| Category | Files | Lines | Bytes |
|---|---:|---:|---:|
| First-party Bend application, excluding bitmap asset below | 24 | 8,861 | 382,399 |
| First-party Bend tests | 33 | 5,149 | 281,666 |
| First-party Bend benchmarks and native diagnostic | 3 | 650 | 27,038 |
| First-party Bend laws/proofs | 2 | 165 | 4,206 |
| SQLite C bridge | 1 | 418 | 14,863 |
| Build/run/test and VM orchestration shell wrappers | 11 | 403 | 15,909 |
| Hand-authored bitmap asset and its Bend accessors | 1 | 222 | 4,695 |
| Synthetic JSONL fixture assets | 2 | 11 | 2,723 |
| mise configuration and compiler hash manifest | 2 | 138 | 10,024 |
| Retained upstream license text | 1 | 202 | 11,344 |
| Vendored dependency implementation | 0 | 0 | 0 |
| Ignored upstream compiler/Base/runtime cache, including guides and inventory | 90 | 27,050 | 907,029 |
| Local upstream toolchain patches | 0 | 0 | 0 |
| Generated C for this historical application | 1 | 452,274 | 22,950,088 |

Application Bend including its bitmap asset is 9,083 lines. All maintained Bend
including tests, benchmarks, laws and assets is 15,047 lines. The 418-line bridge
contains SQLite bindings; generated C also contains the upstream runtime and
compiler expansion. It is not an additional maintained native application
implementation. SQLite is the system library and is not vendored. All 88 pinned
upstream files passed the [hash verification](receipts/toolchain-integrity.txt);
the cache's two additional files are source revision/inventory metadata.

This baseline's guest-validated executable, `build/juice-bend-validated`, is
4,708,120 bytes, SHA-256
`05cdff4f599edcd16646fc3363e27c3856bda4b073f52a92f23264887ef5ba35`.
The generated C is SHA-256
`c4dbb00f7291bb94361aeddadd54207a1fc35ccd571d719fc44583d84aa1f997`.
These are file sizes, not filesystem allocation or process memory. Its
fresh-library capture, retained search/copy/Why/export and verified rebuild
observations are recorded in [native validation](native-validation.md).

Two earlier application builds used the then-frozen source and pinned installed
compiler, producing a 4,621,176-byte executable with SHA-256
`6a1287727e86e6d956dbfa7bf42bb6a1551d2fe064f110c805e14f6e8b85a32c`.
These build-resource measurements do not describe the final validated artifact.
The first started with an empty Clang module-cache directory; the previous cache
was moved to an ignored backup, not deleted. Installed Bun/compiler and OS
caches were retained. The repeat used the populated module cache and included
local `.app` packaging; it produced the exact same executable hash.

| Earlier native build | Elapsed | User / system CPU time | Maximum RSS |
|---|---:|---:|---:|
| Fresh Clang module cache: `mise run build -- src/main.bend build/juice-bend` | 63.89 s | 71.97 / 6.13 s | 6,809,216 KiB |
| Repeat build and local bundle: `mise run app -- "build/Juice Bend Current.app"` | 62.85 s | 70.29 / 3.68 s | 7,914,448 KiB |

Both exited 0. The zsh `time` keyword reports `%M` in KiB. These are process
resource observations on this shared host, not an isolated speed comparison.
The wrapper always regenerates C and recompiles; it has no incremental compiler
artifact reuse, so the second figure is a repeat full build, not a true incremental
build. Receipts: [fresh cache](../benchmarks/results/main-clean-build.txt),
[repeat and package](../benchmarks/results/main-repeat-build.txt).

The baseline benchmark executable was 1,745,904 bytes, SHA-256
`9a701f6c7007d1b236e3f3022aba092c14e466ac316566065e6ce9169db19d1d`.
The FTS v2 benchmark executable was 1,799,936 bytes, SHA-256
`0578938c541a5086f3eb116c407d7024c05216c4f1e2bbf53c1f8ade67cdbcf4`;
its build duration was not separately measured. The historical context benchmark
executable was 2,245,520 bytes, SHA-256
`96a49cb6ddf0126b97958cacec6ff721162004af26c10ec1224ae62dd390d97a`;
its build duration was also not separately measured. Opening and migrating an
isolated copy of the original 100k v1 database took 3,020 ms, retaining all
250,020 historical event rows while rebuilding 125,020 current FTS rows.
One full wrapper build of this target with the installed toolchain took
13.05 seconds (`/usr/bin/time -p ./scripts/build benchmarks/main.bend build/juice-bend-bench`).
The wrapper emits C and recompiles; this is not a measured clean/incremental
application build pair. Ordinary proof checking took 0.46 seconds. At that
attempt, the exact Lean 4.34.0 toolchain was unavailable. Subsequent local setup
closed that gap; [the kernel receipt](receipts/prove.stdout.txt) records all
twelve production laws passing.

An earlier application candidate, including native window support, was built
with `/usr/bin/time -l ./scripts/build src/main.bend build/juice-bend-measured`.
The build succeeded in 73.52 seconds elapsed (81.02 user, 7.69 system).
The executable is 4,602,768 bytes, SHA-256
`dd31e19ae0f588492b8e494fc65b661c5c9d93b2b4986381a95dad22c87fc082`.
This is one wrapper build using the existing compiler/module caches, not a
clean versus incremental comparison. The timer then exited 1 with
`sysctl kern.clockrate: Operation not permitted`, so it supplied no RSS:
[build receipt](../benchmarks/results/final-build-resources.txt).
The same timer completed a scoped page in 0.03 seconds before the same resource
query failure: [page attempt](../benchmarks/results/final-page-time-resources.txt).

The pre-existing macOS zsh 5.9 `time` keyword successfully reported process
resource usage through `%M` (maximum RSS in KiB, as documented by the local
`zshparam(1)` manual). These commands used that earlier native executable
against an isolated APFS copy of the already generated 100,016-record library.
Copying and fixture generation were outside the measurements. A verified
rebuild first updated that copy's derived state to parser version 4. The page
and search therefore ran with warm data and current context checkpoints.

| Native backend command | Elapsed | User / system CPU time | Maximum RSS |
|---|---:|---:|---:|
| Verify raw and rebuild snapshot 2 | 46.39 s | 37.62 / 6.03 s | 104,400 KiB |
| Scoped late 100-record page | 0.03 s | 0.03 / 0.01 s | 12,592 KiB |
| Scoped lexical search | 0.07 s | 0.04 / 0.02 s | 19,920 KiB |

All three commands exited 0. Rebuild reported unchanged raw bytes and complete
accepted-extent verification; the scoped page returned the independently
expected 9 visible events. These are one-observation process peaks and total
CPU times, not sustained GUI CPU, aggregate concurrent-process memory, or
ingestion peak-memory measurements. Receipts:
[rebuild](../benchmarks/results/final-rebuild-rusage.txt),
[page](../benchmarks/results/final-page-rusage.txt),
[search](../benchmarks/results/final-search-rusage.txt).
The exact measurement commands, from the repository directory, were:

```sh
/bin/zsh -f -c 'TIMEFMT="elapsed_seconds=%E user_seconds=%U system_seconds=%S maximum_rss_kib=%M"; time /Users/tcashel/repositories/juice-bend/build/juice-bend-measured --data-dir /tmp/juice-bend-resource.856lHU rebuild 2'
/bin/zsh -f -c 'TIMEFMT="elapsed_seconds=%E user_seconds=%U system_seconds=%S maximum_rss_kib=%M"; time /Users/tcashel/repositories/juice-bend/build/juice-bend-measured --data-dir /tmp/juice-bend-resource.856lHU session-scope 2 99900 100 claude /synthetic/bend/repoA user 2026-01-01'
/bin/zsh -f -c 'TIMEFMT="elapsed_seconds=%E user_seconds=%U system_seconds=%S maximum_rss_kib=%M"; time /Users/tcashel/repositories/juice-bend/build/juice-bend-measured --data-dir /tmp/juice-bend-resource.856lHU search lemon claude /synthetic/bend/repoA user 2026-01-10'
```

Those earlier host-side resource attempts could not use `ps` or the requested
hardware `sysctl` reads. The later Tart observations below provide separate GUI
measurements. Actual input-to-photon latency, precise startup-to-interactive,
uninstrumented scroll cadence and aggregate active GUI/worker peak memory remain
unmeasured. The 1M-record stress corpus was not run.

## Tart GUI resources — 2026-10-20

These observations used the coordinated macOS 27.0 arm64 guest under Tart
2.40.1. Settled idle CPU was calculated from the process CPU-time delta divided
by elapsed wall time; 100% means one fully occupied core. Each row is one
observation with a different sampling interval, not a repeated-trial average.

| Intermediate executable | CPU time before / after | Wall interval | Settled idle CPU |
|---|---:|---:|---:|
| Original loop, `d6dc2b79…` | 3.16 / 4.38 s | 8 s | 15.25% of one core |
| 60 ms idle sleep, `6c5ee83b…` | 1.22 / 1.56 s | 10 s | 3.4% of one core |
| 80 ms idle sleep, `0a6243d5…` | 0.50 / 0.81 s | 20 s | 1.55% of one core |

The full SHA-256 identities, in the same order, are
`d6dc2b797268eb377f7c0c9ffba1c3178cf7ce14594d34679d74a00f8b58558a`,
`6c5ee83b4a9326c210dac874079b953c901ffe5644a5bdebbd4bfb011128161a`,
and `0a6243d583e3ebc4dcb0200e4d45b7a50b64c2bc85f27d5bffce3820894452f0`.
The final validated executable uses the same 80 ms GUI source, SHA-256
`5ea2e41250cdec93f47386e459b95d6a18dc14c183ffed9e506535f78c955ac6`,
but its Store implementation differs from these intermediate builds. Its idle
CPU was not separately measured. Active events, dirty state and pending work
retain the 1 ms sleep path.

The 80 ms candidate's observed idle RSS ranged from 87,904 to 88,208 KiB.
During the final `05cdff4f…` executable's capture, concurrent process samples
reported worker RSS of 106,192 KiB and GUI RSS of 105,888 KiB. They do not
establish an aggregate or peak memory figure.
For the final validated executable, `vmmap` reported GUI physical footprint
41.1M with a 41.5M peak before rebuild, and 46.2M with a 46.2M peak after the
100,016-record capture and verified rebuild. These are `vmmap`'s displayed
physical-footprint units for the GUI process; they are distinct from RSS and
exclude capture-worker memory.

The 60 ms candidate had an observed startup upper bound of 1,308 ms from the
pre-launch timestamp to the screenshot observation. That interval includes an
intentional one-second wait and screenshot overhead. It is neither a precise
startup-to-interactive duration nor a p95 result. On the final executable,
native input and Pause visibly worked while the 100,016-record capture was
active, and capture subsequently completed. These observations establish
interaction during work without measuring input-to-photon latency. See
[native validation](native-validation.md) for the workflow and limitations.
Raw guest receipts remain local in the ignored `build/tart` directory.

## Historical instrumented native capture trace — 2026-10-20

The diagnostic [Bend entry point](../benchmarks/native_trace.bend) reuses
production `Gui.view` and `Gui.tick`, including the ordinary native writer
commands. This historical trace predates the idle scheduler and SQL batching
changes. Its then-current source SHA-256 was
`1595e9b528d9f986fac5b2f9b7cfdfb10e083d13e5465b99401ed62b41eea5b7`;
the diagnostic executable is
`537145d12c3442e073fda1325e64dcf42e2cfdfdfff3da9fd8f89cb8a6585328`.
During that run the production executable remained unchanged at `6a128772…`
and contained no trace entry point. The diagnostic creates a private trace directory, logs at
most 12,000 paired ticks and omits query text unless explicitly enabled.
This run enabled query logging only for the synthetic interaction.

The native run produced 9,061 complete entry/exit pairs and a final close
event. The analyzed interval is frames 3,005–8,073, whose tick exits retain an
active writer. An earlier three-tick empty automatic refresh is excluded.
The worker-state observation interval, from the first active tick exit to
the first cleared tick exit at frame 8,074, was 61.909 seconds. This is not a
standalone import timer. The final isolated library held one accepted snapshot
with 100,016 physical records and 125,020 normalized events.

| Observation during the writer-active interval | Samples | Median | p95 | Maximum |
|---|---:|---:|---:|---:|
| Production `Gui.tick` call, after entry logging | 5,069 | 2 ms | 3 ms | 3 ms |
| Successive frame-return/tick-entry observations | 5,069 | 12 ms | 18 ms | 45 ms |
| Tick exit to next frame-return/tick-entry observation | 5,069 | 10 ms | 16 ms | 42 ms |

No sample in these three series exceeded 100 ms. Percentiles use nearest-rank
ordering of this single run's observations; these are not independent trials.
The query became `active-capture-check` at tick exit 4,379 while the writer
remained active. The next frame-return observation occurred 9 ms later.
Pause first became true at tick exit 4,385, also with the writer active.
The completed capture and final query were subsequently visible, and native
close ended the run. Accessibility and screenshot calls still timed out
during capture; that transport behavior remains unexplained.

The upstream loop calls `Gui.view`, then `Window.frame`, then the tick callback.
Thus tick entry follows a frame return; it does not timestamp a visible pixel.
The trace adds two file writes, three clock reads, event counting, formatting
and retained state per tick. Tick duration excludes the entry log write, but
the instrumentation can change scheduling, allocation and frame cost. These
numbers establish progress of the instrumented event loop and acceptance of
query/Pause state while capture was pending. They do not establish input
injection-to-paint, input-to-photon, uninstrumented performance or GUI resources.

The [sanitized summary](../benchmarks/results/native-trace-summary.json)
records exact identities, distributions and witnesses. An independent review
recomputed all three distributions, paired-frame coverage and witnesses from
the retained raw trace, SHA-256
`7e35936723160537a877668ca2500604bbff96479237a707ad20e7e49df78270`.
The raw trace and synthetic library remain in the private temporary directory;
only the diagnostic source and sanitized summary are published.

The final local packaging compile produced byte-identical generated C but a
different Mach-O hash/UUID. Its output is preserved separately. The runnable
standard executable and `Juice Bend Validated.app` package the exact `05cdff4f…`
binary observed in Tart; deterministic binary linking is not claimed.
