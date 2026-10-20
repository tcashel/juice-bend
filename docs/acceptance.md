# Acceptance evidence

Local macOS arm64 implementation, 2026-10-20. M0–M5 are **in progress**.
“Passed” below applies only to the named test scope. Module tests, a native
window, and backend benchmarks do not establish the complete GUI workflow.
The integrated native suite passed 29 executables and 790 named checks; the
final focused GUI follow-up passed 34 checks after two additional regressions.
Native interaction observations remain separate. Tests use synthetic fixtures
in isolated directories. See the [sanitized test receipt](receipts/test-summary.txt).

| ID | Current result | Evidence and remaining work |
|---|---|---|
| A01 | Partial | Final native executable builds and opens against the retained synthetic library. Fresh empty-library launch was blocked when the Mac locked; fresh network setup remains unobserved. |
| A02 | Observed core workflow | Actual native browse, typed search, result opening, scroll, drag selection/copy/paste, explicit source capture, file Blame/Why and export worked. Final-build filters, Usage and verified rebuild were also observed. See `native-validation.md` for exact build identities and scope. |
| A03 | Partial | `tests/providers.bend`: 61 checks; `tests/store_query.bend`: 37 including carried Codex context, old snapshot stability and repository-scoped history excerpts/opening ordinals. The bounded Usage view deduplicates Claude session/message IDs using per-bucket maxima and shows Codex cumulative differences with conservative baseline/reset/fork exclusions; it makes no complete-session or billing claim. Unknown/encrypted content stays partial. |
| A04 | Passed backend scope | Integration, query and benchmark tests verify unchanged snapshot reuse and no duplicate current search rows. Unchanged refresh compares retained bytes without provider decoding; it still reads the complete retained prefix. |
| A05 | Passed backend scope | Storage edge tests compare append projection with independent fresh capture in both SQL `EXCEPT` directions. Integration and citation tests verify earlier snapshots retain their meaning after append. |
| A06 | Passed backend scope | Rewrite creates a new generation; older captures remain readable and citations resolve unchanged. Storage edge tests keep colliding provider IDs in distinct sources. Maintenance tests verify relative/absolute/symlink aliases converge to one canonical source and snapshot. |
| A07 | Passed backend scope | `tests/integration.bend` closes/reopens the library after source deletion and reads pinned transcripts, Why, search and exact exports. Evidence test also runs real synthetic Git Blame after deleting the original JSONL. |
| A08 | Partial | Storage edge suite abruptly terminates only its own synthetic capture child and checks rollback/recovery. Exhaustive injection before/after every publication boundary and GUI cancellation acceptance are not established. |
| A09 | Passed tested cases | Tests preserve malformed/invalid UTF-8 bytes, unfinished tails, completed tails and oversized fragments. The shared selected-record validator derives fragment coverage from verified bytes and the immediate predecessor; page, Why and citation regressions reject a corrupted oversized flag. |
| A10 | Passed tested cases | Domain/parser/provider suites cover strict UTF-8, escapes, surrogate pairs, NUL and invalid encodings. Maintenance exports exact Unicode/NUL/invalid bytes. Capture tests cover fragmented reads and tail completion. This is finite fixture coverage, not a proof of every parser input. |
| A11 | Passed boundary suite | 49 native SQLite assertions reported: typed/binary/NUL/exact integer values, FTS5, bound input, error cleanup, rollback/reopen, stale handles, registry exhaustion, BUSY, cancellation and independent timer responsiveness. |
| A12 | Passed backend scope | Query: 48 checks including actual FTS5; store query: 37; storage search: 28; scoped reader: 18. Words AND, phrases, paths, punctuation, provider/repository/role/date scope, deterministic paging, latest-only indexing and frozen scope across retained transcript/Why/export are exercised. |
| A13 | Passed backend scope | Final fresh synthetic 100k corpus checks independently expected records at beginning/middle/end. Warm late read p95 is 20 ms; repository-scoped late reads are 30 ms p95 using verified context checkpoints. GUI rendering/scroll latency remains separate. |
| A14 | Passed tested cases | Corrupt raw bytes, missing ordinal, wrong generation and out-of-range extent are rejected. Rebuild verifies complete raw extent before publication. The reproduced oversized-flag corruption now fails closed in page, Why and citation reads. Twenty-four selected-read regressions cover continuation flags, predecessor bytes/mapping/complete flags, blob types, exact boundary and final extent. |
| A15 | Passed backend fixture scope | File evidence: 35 checks; unified diff parser: 36. Real isolated Git fixtures exercise commit-hunk content mapping, unmatched neighboring regions, unique explicit-trailer exact identity, explicit-body probable identity, ambiguity and uncommitted lines. Linked worktrees share canonical repository scope. Exact identity does not establish sole authorship or tool success. Native workflow observations remain separate. |
| A16 | Passed tested cases | Provenance: 36 checks cover scope, collisions, ambiguity, exact rational scores, decimal timestamps above 2^53, ties, repeated/low-entropy lines and safe paths. File-evidence checks additionally require an eligible unique parent for child evidence; orphaned, ambiguous, excluded and cyclic identities remain unresolved. Parent navigation retains the child's captured citation/model rather than fabricating parent authorship. |
| A17 | Passed tested/observed scope | Citation consumer verifies full provider/source/generation/snapshot/extent/record/event identity against retained bytes. 38 evidence assertions plus four synthetic Git fixture commands pass, including old references after append/rewrite. Actual file Why quoted captured intent, and GUI export produced inspected mode-0600 Markdown with the displayed citations. Atomic no-overwrite exports pass race/symlink regressions. |
| A18 | Audited implementation boundary | Maintained application modules, tests, benchmarks and proofs are Bend; the native first-party exception is the 418-line SQLite bridge. Final `otool -L` shows only system SQLite/libSystem and upstream macOS UI frameworks. Source/process audit found no semantic, model, vector or network application subsystem. This is a dependency/source audit, not packet tracing. |
| A19 | Partial native observation | ASCII typing, visible copy/clear/paste roundtrip, reader drag selection, scrolling and close were observed. Unicode commit and physical Command/Shift/IME remain unverified because the automation transport did not supply reliable events. See `native-validation.md`. |
| A20 | Unresolved native timing | Large synthetic capture completed and Pause displayed its scheduling state. Accessibility/action calls timed out during capture; later visible input does not establish responsiveness during it. Scheduler/state tests pass, but input/frame latency and GUI CPU/RSS remain unmeasured. |
| A21 | Passed scoped audit | Wrappers use private temporary roots and `umask 077`; source/process audit confirms explicit roots, bounded read-only Git and no implicit provider-home scan. Publication inventory contains synthetic tests/receipts, no private logs, databases or reference-source snapshots. Original Juice was used read-only and its pre-existing edits remain present. |
| A22 | Partial | Twelve production laws pass ordinary Bend checking and BendTT translation. Stronger kernel execution is **not run** because exact Lean 4.34.0 is unavailable. See the production mapping below. |
| A23 | Passed tested boundaries | Exact decimal/SQLite boundaries, U32 overflow rejection and large timestamp comparisons pass. Seven native sparse-file tests confirm exact maximum size/addressing, explicit overflow at 2^32 and 2^32+1, and production capture refusal with no publication. A complete UINT32_MAX-sized import and total-library maximum are not measured. |
| A24 | Passed implementation/review scope | Provider/repository/role/date scopes cross parser, storage, CLI, reader and GUI through frozen selection metadata. Independent review found and corrected an unscoped history excerpt and a lost initial hit ordinal; mixed-repository history and late-hit GUI regressions pass. See the maintainability record below; native interactions retain their separate acceptance status. No native bridge change was needed. |

Observed commands include:

- `./scripts/test tests/domain.bend`: 53 assertions.
- `./scripts/test tests/providers.bend`: 61 checks.
- `./scripts/test tests/query.bend`: 48 assertions.
- `./scripts/test tests/store_query.bend`: 37 checks.
- `./scripts/test tests/timestamp.bend`: 18 assertions for exact canonical UTC date/time normalization and rejection of unsupported or invalid timestamps.
- `./scripts/test tests/append_integrity.bend`: 49 checks including typed projection corruption detection, repaired append/fresh-import equivalence and exact metadata context.
- `./scripts/test tests/storage_search.bend`: 28 assertions.
- `./scripts/test tests/provenance.bend`: 36 assertions.
- `./scripts/test tests/git_diff.bend`: 36 pure unified-zero patch cases, including exact line counts, overlapping regions, Unicode, binary/combined/multiple-file rejection, 128-hunk and 1 MiB byte limits.
- `./scripts/test tests/file_evidence.bend`: 35 checks of actual Git hunk/commit associations, linked worktrees, explicit trailers/body references, conflicting identities, retained evidence after source removal and eligible child navigation.
- `./scripts/test tests/evidence.bend`: 38 assertions and four isolated Git setup/removal commands.
- `./scripts/test tests/coverage_integrity.bend`: four checks proving page, Why and citation cannot reinterpret an oversized fragment after corruption of its flag.
- `./scripts/test tests/selected_integrity.bend`: 24 checks for selected/predecessor coverage and payload metadata, refresh refusal and exact fragment/extent boundaries.
- `./scripts/test tests/context.bend`: 22 checks of raw-bound repository/model/session context checkpoints and scoped replay.
- `./scripts/test tests/usage.bend`: 29 checks for exact decimal arithmetic, typed Claude identities/mirror deduplication, separate cache buckets, Codex baselines/deltas/resets/fork exclusion, raw authority, immutable citations and the 100-record bound.
- `./scripts/test tests/integration.bend`: 21 named checks, including fixture removal and complete-extent verification.
- `./scripts/test tests/maintenance.bend`: 30 named scenarios, including canonical source aliases, atomic publication, existing destinations, dangling symlinks and a destination created after preflight.
- `./scripts/test tests/file_limits.bend`: seven assertions using isolated sparse files; fixtures removed afterward.
- `./scripts/test tests/sources.bend`: 19 behavior checks and five synthetic setup checks, including explicit canonical roots, bounded recursive discovery, no discovered symlink traversal, disable/re-enable, failure isolation and durable reopen.
- `./scripts/test tests/cli.bend`: nine native checks for exporting the exact displayed evidence, Unicode across read boundaries, the 1 MiB limit, invalid UTF-8 rejection and preservation of existing destinations.
- `./scripts/test tests/scoped_reader.bend`: 18 checks of provider/repository/role/date scope, inherited metadata, rejected forged projections/corrupt checkpoints and retained references after append/source replacement.
- Final focused GUI run: 34 native coordinator assertions exercise initial selection at a late matching record, repository-scoped history opening ordinals, pinned refresh, stale/current replies, mode guards and Usage range/scope restrictions. These are state tests, not observed screen interaction.
- `./scripts/bend PROOF.bend --check-only`: `ALL PROOFS CHECK`.
- `./scripts/bend PROOF.bend -o /tmp/juice-bend-domain-laws.bendtt`: translation succeeds.
- `./scripts/prove`: exits 1 after ordinary checking because the stronger kernel prerequisites are unavailable. Exact [stdout](receipts/prove.stdout.txt), [stderr](receipts/prove.stderr.txt) and [exit status](receipts/prove.exit.txt) are retained.

The completed `./scripts/test` run and final focused GUI follow-up are recorded
in [test-summary.txt](receipts/test-summary.txt) and
[gui-final.txt](receipts/gui-final.txt). The final application binary's CLI
integration is recorded in [cli-final.txt](receipts/cli-final.txt).
Performance raw results and trial definitions are in [performance.md](performance.md).
Reference behavior and known gaps are in [parity.md](parity.md).

## Maintainability exercise

The extension carries provider/repository/role/date scope from lexical queries
through result selection, transcript pages, Why and exports. `query.bend`
validates filters; `store.bend` applies search/history scope and captures verified
context; `scoped_reader.bend` reuses `Store.contextualize` and
`Domain.scope_allowed` over retained bytes. `cli.bend` exposes explicit scoped
commands. `gui.bend` freezes scope and starting ordinal in result/selection
state and includes them in asynchronous requests.

Independent read-only review found two defects: a repository-filtered history
row could show another repository's excerpt, and an initial search selection
could discard a late hit's ordinal. The corrected history query scopes excerpt,
repository and opening ordinal together. GUI initial selection retains the
first hit's ordinal, including the history opening field. Store regressions use
a matching repository beginning at physical record 45; GUI regressions use
record 500 with frozen filters and an older-row fallback. Independent static
follow-up confirmed both findings resolved. Shared raw verification,
normalization and scope predicates remain in production use. No maintained
native code was added for this extension. Review and native contract tests do
not substitute for the screen/input observations in A19–A20.

## Law-to-production mapping

| Laws | Production function and use | Tested external boundary |
|---|---|---|
| Pinned snapshot survives append | `Domain.select_snapshot` in `GUI.with_rows` | Native coordinator tests exercise initial snapshot 9 and pinned snapshot 7 surviving newer row 9; real screen refresh observation remains pending |
| Generation isolation | `Domain.identity_guard` through `Domain.ref_equal`, called by `Evidence.resolve_citation` | All seven descriptor components are changed independently and rejected; old valid descriptor resolves after rewrite |
| Page within request and extent | `Domain.count_nat`, used by `Domain.bounded_count` in storage reads | Zero, beyond extent and maximum U32 arithmetic; actual beginning/middle/end pages |
| Provider/repository exclusions | `Domain.scope_guard`, used in provenance candidate eligibility | Cross-repository content and forged projection scope cannot become evidence |
| Missing/ambiguous not exact | `Domain.identity_insert`, used by `Provenance.unique_go` | Duplicate full keys deduplicate; distinct full keys remain ambiguous |
| Empty hunk/below threshold | `Domain.eligible_match` and its `eligible_nonzero` branch, used by content scoring | Singleton and multi-line threshold cases, repeated lines and low-entropy exclusions |
| Lower score/stable tie | `Domain.prefer_candidate`, used by production best-candidate comparison | Exact rational scores, decimal timestamp order and lexical captured-key tie break |

The laws cover those pure functions, not SQLite atomicity, filesystem coherence,
SHA-256 implementation correctness, compiler lowering, foreign effects, UI
events or macOS clipboard delivery. Those boundaries require their independent
tests and observations. No unsafe proof or separate proof-only algorithm is
used. `scripts/prove` fails visibly when the stronger kernel prerequisite is
missing; ordinary checking is not represented as kernel verification.
The local mise registry has no Lean entry. An explicit
`github:leanprover/lean4@4.34.0` install dry run with all mise data/state/cache
paths inside this repository fails DNS resolution. No global installation,
permission escalation or substitute kernel version was attempted.

## Size and coverage boundaries

The pinned native `File.size` implementation performs `fstat`, compares
`st_size` to `UINT32_MAX`, and returns `EOVERFLOW` above that bound. Store capture
unwraps the result before creating a snapshot; it must never accept a saturated
or wrapped file size as complete. Native sparse fixtures verify an exact size
of 4,294,967,295 bytes, one byte read at offset 4,294,967,294, and EOF at offset
4,294,967,295. Sizes 4,294,967,296 and 4,294,967,297 return overflow; production
capture at the first unsupported size exits without inserting a source, snapshot
or raw row. A complete import at the largest addressable size was not run.
This is a per-source addressing ceiling, not a 4 GiB total-library ceiling;
no total-library maximum has been measured.

Capture chunks are bounded to 262,144 bytes. Oversized physical records remain
raw evidence with explicit unsupported fragment coverage; fragments are not
independent complete events. JSON parsing and bridge response bounds are also
explicit. Full export/rebuild verifies the complete requested extent; a bounded
transcript/evidence read verifies only the requested retained records.
