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
Pairing is page-local and conservative; child/subagent navigation remains open.
Priority order: finish long-history append improvements; close remaining
native validation gaps; child/subagent navigation; Settings;
richer provider/archive
support; full Usage and deterministic context preparation; owned-storage
management and explicit opt-in connection/subscription surfaces. UI polish
follows functional parity. These are outstanding capabilities, not claims that
the current app implements them. Existing language, privacy, no-inference and
no-distribution boundaries remain in force. Tests use synthetic providers and
must not query real accounts or alter provider configuration by default.

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
| Recorded usage | `Discovery/ClaudeCallUsage.swift`, `Discovery/CodexForkUsage.swift` under `JuiceCore` | Verified raw view: Claude session/message keys use bucket maxima; Codex adjacent cumulative deltas exclude first baseline, resets and known fork/unknown metadata attribution | 29 native Usage checks; exact decimal strings above 2^53. Maximum 100 selected records is explicitly incomplete. Missing counts remain unknown; no full-session, billing or quota total is claimed. Repository/role/date filtered GUI views cannot open an unfiltered usage summary |
| Claude nested discovery | `JuiceCore/Discovery/ClaudeCodeDiscoverer.swift` | Explicit enabled roots recursively include parent histories and nested `subagents`; no default private-home scan or discovered symlink traversal | Native source tests cover enabled/disabled roots, canonical paths, nested files, missing sources and retry fairness. Discovery enumerates at most 2048 entries within 256 KiB / 2 seconds |
| Codex active/archived discovery | `JuiceCore/Discovery/CodexDiscoverer.swift` | The same explicit-root walk covers active and archived plain JSONL paths; one root and at most four new plus four registered files per refresh | Maximum 32 configured roots. Oversized/failed enumeration retains the prior queue. `.jsonl.zst` decompression is unsupported. Extension selection does not imply support for arbitrary multiline `.json` documents |
| Content threshold | `JuiceCore/Blame/ContentMatcher.swift` | Nonempty eligible sequence; exact singleton or at least two hits and 60% overlap | `tests/provenance.bend`; production calls `Domain.eligible_match` |
| Repeated lines and whitespace | `JuiceCore/Blame/FileEdit.swift` | Preserve repeated hunk occurrences and leading indentation; trim trailing ASCII whitespace | Native tests pass; non-ASCII-only lines conservatively cannot establish content attribution |
| Deterministic attribution | `JuiceCore/Blame/BlameService.swift` | Exact rational score, newest normalized UTC timestamp rank, stable captured key | Nine native timestamp-attribution checks include equal offset instants, one-nanosecond differences and production content selection. No floating-point or incompatible epoch/calendar comparison; production calls `Domain.prefer_candidate` |
| Attribution ambiguity/scope | Same | Wrong repository and ineligible evidence rejected; distinct captured identities remain ambiguous | Native tests pass; evidence integration also rejects forged SQL scope and ignores forged projection arguments |
| Read-only Git | Same | Literal `/usr/bin/git` command; helper disabling; path validation; ≤500 lines / 1 MiB / 3 seconds | Native test exercised actual Git against public destination `AGENTS.md`; parser synthetic Unicode and overflow tests pass |
| Per-region evidence | Same | File evidence matches individual commit diff hunks using original-line coordinates; unmatched regions never borrow a neighboring match. Unique eligible final session trailers provide exact identity association; standalone body IDs remain probable | `tests/file_evidence.bend` and `tests/git_diff.bend`; final integration receipts are in `acceptance.md`. Exact identity association does not prove sole authorship or tool success |
| Child attribution/model | Same | Claude nested-path and Codex recorded-parent identities retain the child actor; parent requests receive separate citations for navigation | No parent event ordinal or model replaces the child. Missing, ambiguous, cyclic or unsupported parent identity makes attribution ineligible. Final integrated child/orphan receipts are in `acceptance.md` |
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
