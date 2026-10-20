# Performance observations

Measured on 2026-10-20, macOS 27.0.1 (26A434), arm64, Bend 2.0.37 at
`60ca80aedeec9d8f0629b5f10dd19457d8ad67af`, native Apple clang `-O3`.
The host also ran implementation/testing work; these are observations, not an
isolated machine comparison or a Swift Juice comparison.

Run `./scripts/bench 10000` or `./scripts/bench 100000`. The wrapper creates a
private temporary working directory. Fixture generation is Bend code and is
excluded from operation timers. Generator v1, seed 1337, creates one long
Claude-format session with varied Unicode text, integer payloads, paths,
repositories, timestamps, tool arguments/results and usage. Each four physical
JSONL records yield five normalized events. Events include tools and are not
presented as five independent human/assistant messages.

| Observation | 10k baseline | 100k baseline | 100k FTS schema v2 | Final fresh 100k with verified context |
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
[final fresh 100k](../benchmarks/results/100000-context-v1.jsonl). Search and warm late-page statistics
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

The baseline 100k search p95 missed the provisional 150 ms target. Schema v2
indexes only current accepted snapshots and joins the FTS rowid directly to the
event rowid. The final fresh run's 60 ms p95 passes that backend target; the
five actual warm trials were 60, 59, 60, 58 and 58 ms. The append run retains 250,020 event
rows across both immutable snapshots but indexes 125,020 current events.
Backend late-page reads are below 200 ms, including near the end. Backend reopen
is not native startup-to-interactive. Unchanged refresh verifies the retained prefix without
provider decoding; append verifies that prefix, checks projection integrity,
copies projection/context rows into a new immutable snapshot and verifies the
accepted extent again. Those costs remain linear in the existing session.
The final observed 71.4-second append of 16 records is a material preservation
performance limitation, even though read targets pass. Capture/refresh UI
responsiveness must be measured separately; these durations are not evidence
that input remains responsive. Historical raw and event rows remain
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
it is distinct from the final fresh database with both snapshots checkpointed.

The source audit at 2026-10-20 16:50:32 UTC uses physical newline counts,
including comments and blank lines, and exact file bytes. The
[per-file inventory](receipts/code-size.tsv) records every counted path and
SHA-256; categories do not overlap. No cached test binaries or repeated generated
C outputs are included in application source counts.

| Category | Files | Lines | Bytes |
|---|---:|---:|---:|
| First-party Bend application, excluding bitmap asset below | 24 | 8,556 | 368,180 |
| First-party Bend tests | 29 | 4,136 | 227,398 |
| First-party Bend benchmarks | 2 | 391 | 16,826 |
| First-party Bend laws/proofs | 2 | 165 | 4,206 |
| SQLite C bridge | 1 | 418 | 14,863 |
| Build/run/test shell wrappers | 10 | 281 | 9,652 |
| Hand-authored bitmap asset and its Bend accessors | 1 | 222 | 4,695 |
| Synthetic JSONL fixture assets | 2 | 11 | 2,723 |
| mise configuration and compiler hash manifest | 2 | 125 | 9,530 |
| Retained upstream license text | 1 | 202 | 11,344 |
| Vendored dependency implementation | 0 | 0 | 0 |
| Ignored upstream compiler/Base/runtime cache, including guides and inventory | 90 | 27,050 | 907,029 |
| Local upstream toolchain patches | 0 | 0 | 0 |
| Generated C for one final application candidate | 1 | 445,988 | 22,687,415 |

Application Bend including its bitmap asset is 8,778 lines. All maintained Bend
including tests, benchmarks, laws and assets is 13,470 lines. The 418-line bridge
contains SQLite bindings; generated C also contains the upstream runtime and
compiler expansion. It is not an additional maintained native application
implementation. SQLite is the system library and is not vendored. All 88 pinned
upstream files passed the [hash verification](receipts/toolchain-integrity.txt);
the cache's two additional files are source revision/inventory metadata.

The audited `build/juice-bend-next` candidate is 4,619,552 bytes, SHA-256
`4ad55c63cb542b68740e032f05ff528c25c3ce7250a6f07c1bfbd0d3f25f5d49`.
Its generated C is SHA-256
`c78f1edabba528da8806ea0b5d24442c82c276507b7773a2b319f4213311cad2`.
That candidate's build duration was not timed. The separately timed application
build below has its own executable identity. These are file sizes, not
filesystem allocation or process memory.

The baseline benchmark executable was 1,745,904 bytes, SHA-256
`9a701f6c7007d1b236e3f3022aba092c14e466ac316566065e6ce9169db19d1d`.
The FTS v2 benchmark executable was 1,799,936 bytes, SHA-256
`0578938c541a5086f3eb116c407d7024c05216c4f1e2bbf53c1f8ade67cdbcf4`;
its build duration was not separately measured. The final context benchmark
executable was 2,245,520 bytes, SHA-256
`96a49cb6ddf0126b97958cacec6ff721162004af26c10ec1224ae62dd390d97a`;
its build duration was also not separately measured. Opening and migrating an
isolated copy of the original 100k v1 database took 3,020 ms, retaining all
250,020 historical event rows while rebuilding 125,020 current FTS rows.
One full wrapper build of this target with the installed toolchain took
13.05 seconds (`/usr/bin/time -p ./scripts/build benchmarks/main.bend build/juice-bend-bench`).
The wrapper emits C and recompiles; this is not a measured clean/incremental
application build pair. Ordinary proof checking took 0.46 seconds. Stronger
kernel checking remains unavailable pending the exact Lean 4.34.0 toolchain.

The final application entry point, including native window support, was built
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
`zshparam(1)` manual). These commands used the same final native executable
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

Native startup-to-interactive, input latency during indexing, scroll cadence,
and GUI idle/active CPU were **not measured here**. `ps` and the requested
hardware `sysctl` reads were denied; no GUI resource figures are inferred from
the backend commands. Render/input acceptance belongs to the separate observed
native UI checks. The 1M-record stress corpus was not run.
