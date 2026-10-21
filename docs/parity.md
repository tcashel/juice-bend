# Reference parity

Inspected read-only Juice revision:
`ca66da7d9cc56f665900ba71ee9d97c37787c77d`. Reference locations below are relative
to its source tree. No reference source or personal history is copied here.
This matrix records contracts and current evidence, not a completed port.

## Expanded owner goal — 2026-10-20

The owner now requests feature parity with the SwiftUI app, excluding embeddings,
followed by UI polish. The current comparison uses the immutable, already-cached
Juice commit `829ff9b50c6583b1f5b2f5fa663920bdda316b5a` (including Storage
settings). The original checkout remains at `a9767a7296886301bf813fd3d3f99fa03fea05d0`
with its existing edits untouched. Reference inspection uses read-only Git
objects; no source snapshots or real histories are copied here.

Bounded result paging, saved-version navigation and read-only Storage inventory
are implemented and observed in the native app. The committed-repository
browser is connected to CLI and native Files UI, with explicit pinned commits,
directory/source paging, displayed-range Blame/Why and exact text exports.
Focused CLI/GUI gates passed 351 checks; native Tart interaction passed commit
pinning across changed HEAD/dirty worktree and retained History restoration.
Recorded Tools now has a retained, scoped reader, CLI and native control.
Its 435 focused checks and actual Tart observations cover page boundaries,
old snapshots after append/source removal, explicit latest and exact exports.
Pairing is page-local and conservative. Related now provides bounded retained
parent/child navigation, distinct recorded-parent/path-association labels,
exact target captures and two-level Back restoration. It does not reconstruct
a complete historical graph or resolve every provider's child convention.
The combined event-seal/readability candidate passed 2,262 storage and 219
presentation checks, plus actual native Refresh, retained text and exports.
Tools payloads now precede their full citations; normal scoped transcripts
still put the citation first. Standard 100k append improved from
33.392 to 28.226 seconds in single observations; the following context-prefix
cache measured 27.262 seconds and passed 990 focused checks. It still needs work.
The retained-chunk comparator passed 2,225 checks, including all 27 crash cuts,
but the next standard run measured 27.728 seconds; it does not establish an
append improvement over 27.262 seconds. The separate 100-source benchmark measured a 477 ms middle-source append;
that is a different workload, not a long-session speedup claim.
Settings now has explicit provider/path Add folder, Import file, selected-root
Enable/Disable and persisted automatic refresh intervals. Native Tart app
`2e3191d9…` passed actual restart, manual refresh while paused, exact origin
restoration and source-only append/search; 154 backend/CLI checks and 388 GUI
assertions have separate receipts. This closes the named Settings workflow,
not every native input or timing requirement.
Portable context v2 subsequently passed 1,896 live storage checks, 812 adversarial
context checks and 45 actual old-writer checks. Native app `503f1098…` passed old
v1 reads, native v2 Refresh, pinned text and exact copy/export. The next 100k
observation measured append24.678s versus27.728s, but first import37.564s versus
33.582s. Long-history preservation performance is still an active gap.
Whole-session Usage is now integrated with exact retained capture identity,
verified bounded raw reads, Claude call maxima and Codex cumulative/fork rules.
Separate scan, attribution and bucket completeness prevent unknown counts from
appearing as zero. Native app `91a147f0…` passed retained old/latest summaries,
manual and automatic History capture, copy/export and pending-worker Back.
See `receipts/session-usage-native.txt` and `receipts/usage-ui-native.txt`.

Native reading polish is now integrated: a licensed grayscale font, grouped
controls, word-aware rows, full status inspection and an effective capture-hold
hint. App `fabcd506…` passed actual Files/Settings/History selection restoration,
keyboard paging, exact Why export, Unicode clipboard/Delete and pending-Usage
Back; 604 focused checks passed. See `receipts/polish-native.txt`. CJK/emoji still
use fallback boxes, and full shaping/IME/accessibility/resize remain open.

Current priority: recorded-request eligibility in file/commit Why, remaining
validation gaps, richer provider/archive support, deterministic context
preparation, owned-storage actions and explicit opt-in connection/subscription
surfaces. Further marginal append tuning is deferred. Functional parity also
requires pleasant interaction and visual quality; exact SwiftUI layout matching
is unnecessary. These remaining items are not implemented claims. Synthetic
fixtures only; no real account access or provider configuration changes by default.

The pinned upstream window API cannot resize windows or expose font shaping.
An upstream-supported compatible revision may resolve that boundary; first-party
native UI adapters remain excluded. Complete shaping/accessibility parity is
not established by the current bitmap reader.

## Existing core behavior

| Behavior | Reference location | Bend contract / status | Evidence or difference |
|---|---|---|---|
| Separate owned history | `docs/adr/0037-preserve-search-and-provenance.md` | Raw capture authority; original logs and Juice storage remain read-only | Storage integration acceptance recorded in `acceptance.md` |
| Immutable append snapshots | `docs/adr/0038-incremental-session-indexing.md` | Provider + canonical locator + generation + accepted extent + record/event identity; append preserves old snapshots | 49 native append-integrity checks include deleted/modified projections, changed SQLite cell types, damaged context checkpoints and verified full replay equivalence. Parser/context versions prevent silent checkpoint reuse |
| Bounded transcript reads | `docs/adr/0040-indexed-owned-transcript-reads.md` | At most 100 selected physical records plus predecessor validation; repository scope uses a verified raw-bound context checkpoint | Selected ranges do not verify the whole archive. Missing legacy context may require prefix replay; corrupt checkpoints fail visibly. Complete raw export verifies the entire accepted extent |
| Scoped history lists | Native History repository selection | Repository filters constrain source eligibility, displayed excerpt, repository label and opening record | `tests/store_query.bend` includes a mixed source whose selected repository starts after the first 40 records; empty in-scope text uses a neutral title instead of another repository's excerpt |
| Claude normalization | `Juice/Packages/Sources/JuiceCore/Transcript/MessageExtraction.swift` | Ordered text, thinking, tool-use and tool-result events; complete arguments/results, call IDs and record-local model/usage facts | `tests/providers.bend`. Unknown blocks and attachments retain raw bytes with explicit coverage. Tool calls/results remain independent occurrences; no ambiguous global call-ID merge. `toolUseResult.agentId` remains raw-only |
| Codex normalization | Same | Session/turn metadata, response messages, legacy and current function calls, outputs, readable agent relays, compaction and reasoning coverage | Known event mirrors emit no duplicate display turn. Custom tool support exceeds the pinned display extractor. Encrypted relay fields and unsupported shapes remain partial; encrypted reasoning is never represented as fully readable |
| Model and chronology | Same | Codex model context carries through subsequent events; model-free turn context clears it. Claude missing model remains unknown. RFC3339 timestamps normalize to exact UTC through nanoseconds | Provider, timestamp, scoped-reader and append tests. Invalid dates, missing zones, unsupported leap seconds/precision and unspecified numeric timestamp units remain unknown; original bytes are unchanged |
| Recorded usage | `Discovery/ClaudeCallUsage.swift`, `Discovery/CodexForkUsage.swift` under `JuiceCore` | Whole pinned capture: Claude exact call-key bucket maxima; Codex cumulative deltas, first ordinary total, repeated/reset/fork/reviewer distinctions; missing counts remain unknown | Native reader 105, Codex 68, adapter 85, dispatch 48 and GUI 88 checks. Real Tart summaries/export/Back passed. Limits and scan/bucket/attribution coverage are explicit; no billing/quota total. Repository/role/date filtered views refuse unfiltered Usage. Legacy bounded-page CLI remains separate |
| Claude nested discovery | `JuiceCore/Discovery/ClaudeCodeDiscoverer.swift` | Explicit enabled roots recursively include parent histories and nested `subagents`; no default private-home scan or discovered symlink traversal | Native source tests cover enabled/disabled roots, canonical paths, nested files, missing sources and retry fairness. Discovery enumerates at most 2048 entries within 256 KiB / 2 seconds |
| Codex active/archived discovery | `JuiceCore/Discovery/CodexDiscoverer.swift` | The same explicit-root walk covers active and archived plain JSONL paths; one root and at most four new plus four registered files per refresh | Maximum 32 configured roots. Oversized/failed enumeration retains the prior queue. `.jsonl.zst` decompression is unsupported. Extension selection does not imply support for arbitrary multiline `.json` documents |
| Source and refresh Settings | Native Settings / indexing controls | Explicit provider/path registration, separate file import, authoritative selected-root Enable/Disable; atomic durable enabled/interval pair; manual Refresh while paused | App `2e3191d9…` observed both providers, no implicit capture on registration, restart persistence, exact Back and append/search. Automatic deadlines are checked; no elapsed two-hour timer acceptance claim. Inventory is bounded to 32 roots |
| Content threshold | `JuiceCore/Blame/ContentMatcher.swift` | Nonempty eligible sequence; exact singleton or at least two hits and 60% overlap | `tests/provenance.bend`; production calls `Domain.eligible_match` |
| Repeated lines and whitespace | `JuiceCore/Blame/FileEdit.swift` | Preserve repeated hunk occurrences and leading indentation; trim trailing ASCII whitespace | Native tests pass; non-ASCII-only lines conservatively cannot establish content attribution |
| Deterministic attribution | `JuiceCore/Blame/BlameService.swift` | Exact rational score, newest normalized UTC timestamp rank, stable captured key | Nine native timestamp-attribution checks include equal offset instants, one-nanosecond differences and production content selection. No floating-point or incompatible epoch/calendar comparison; production calls `Domain.prefer_candidate` |
| Attribution ambiguity/scope | Same | Wrong repository and ineligible evidence rejected; distinct captured identities remain ambiguous | Native tests pass; evidence integration also rejects forged SQL scope and ignores forged projection arguments |
| Read-only Git | Same | Literal `/usr/bin/git` command; helper disabling; path validation; ≤500 lines / 1 MiB / 3 seconds | Native test exercised actual Git against public destination `AGENTS.md`; parser synthetic Unicode and overflow tests pass |
| Per-region evidence | Same | File evidence matches individual commit diff hunks using original-line coordinates; unmatched regions never borrow a neighboring match. Unique eligible final session trailers provide exact identity association; standalone body IDs remain probable | `tests/file_evidence.bend` and `tests/git_diff.bend`; final integration receipts are in `acceptance.md`. Exact identity association does not prove sole authorship or tool success |
| Child attribution/model | Same | Claude nested-path and Codex recorded-parent identities retain the child actor; parent requests receive separate citations for navigation | No parent event ordinal or model replaces the child. Missing, ambiguous, cyclic or unsupported parent identity makes attribution ineligible. Final integrated child/orphan receipts are in `acceptance.md` |
| Related capture navigation | Reference parent/subagent links | Fixed accepted-ID watermark, exact snapshot references, bounded verified metadata, distinct recorded-parent/path association labels, preserved target filters and original reader | 163 backend/CLI checks. Native app `784d48c4…` passed two pages, scoped target/Tools, both Back levels, concurrent native capture, retained rereads after source removal and exact exports. Role/date scope applies to target readers, not metadata discovery. Self/direct two-way cycles only; incomplete or page-local evidence does not prove global absence/uniqueness |
| Why | `Juice/Packages/Sources/JuiceXPC/WhyBuilder.swift` | Transcript, file/range and exact-commit entry points quote captured requests/tool intent with immutable descriptors; no generated rationale | Descriptor consumption verifies provider, locator, generation, snapshot, extent, record and event. File evidence inspects at most 64 generation snapshots, the first 16 actor records, newest 256 edit events and eight commits per selected range. Recorded commit-command SHA mapping and time-only probable attribution are not implemented |
| Origin and repository eligibility | Same | Verified raw metadata excludes explicit non-user-work/excluded origins, synthetic markers and unsupported orphan actors. Explicit Git checkout/worktree roots map to a shared canonical repository | Diagnostic-style Markdown first requests are conservatively held for review. Relative edit cwd lookup is bounded to 16 records. This is a conservative supported subset, not complete reference origin classification |
| Evidence exports | Preserve/search ADRs | Full retained raw export verifies all bytes; bounded transcript/Why exports retain selected scope and snapshot. GUI file evidence and Usage export the exact displayed text | Non-replacing atomic publication protects original locators and existing paths. Displayed-text exports explicitly say they are not reverified and do not rerun mutable Git attribution |
| Native reading/search | Reference native History and transcript views | Native Bend UI; no Swift process, webview or inference dependency | Native interaction evidence recorded in `acceptance.md` |
| Retained rebuild and capture responsiveness | Preserve/search ADRs | Atomic bounded SQL publication with immutable raw ownership; monotonic refresh and idle scheduling | Final Tart build captured 100,016 records, accepted visible input/Pause during capture, and rebuilt 125,020 search events after the source was moved away. Direct IME and input-to-display latency remain unverified |

Migration from the original Juice database, semantic/model features, signed
releases and retired inference-based advice remain excluded. The expanded
parity goal includes explicit opt-in connection/subscription behavior; those
surfaces are still unimplemented and must not read private accounts by default.

Backend evidence: `tests/provenance.bend` passes 36 assertions;
`tests/evidence.bend` passes 38 assertions and four isolated fixture commands.
The latter creates a synthetic Git commit, captures its recorded Write input,
links Blame to retained content, removes the original JSONL, confirms unchanged
Blame, and distinguishes a subsequent uncommitted edit. These are backend
receipts, not native UI interaction evidence.

The final source suite passes 24 checks and scoped-reader suite passes 18.
Each refresh import has a 300-second limit; an unusually slow eight-file batch
can exceed the GUI worker's 600-second limit after earlier files were committed.
Discovery excludes symlinks and rechecks canonical paths before import, but the
upstream runtime has no atomic open-without-following primitive; hostile
concurrent filesystem replacement is outside that guarantee.
