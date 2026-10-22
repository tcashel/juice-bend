# Juice Bend

An experimental, standalone native reproduction of Juice's core history and provenance workflow, written in Bend 2.

## Run locally

Requires an Apple Silicon Mac, Xcode command-line tools, and
[mise](https://mise.jdx.dev/). The compiler host is Bun 1.4.2, pinned in
`mise.toml`. Bend 2.0.37 is pinned by revision and source hashes. The native
compiler is official LLVM 23.1.4, pinned by asset, SHA-256 and size in
`toolchain/llvm/mise.toml`. SQLite must provide FTS5; `doctor` and the bridge
tests check it.

```sh
mise trust
mise install
mise run setup
mise run setup-llvm
mise run doctor
mise run build
mise run demo
```

LLVM setup downloads 1.57 GB and requires about 12 GB free for extraction.
It installs only in this repository's ignored tool directories; build selects
that verified compiler explicitly without changing global PATH or the system
compiler. Ordinary build never downloads LLVM or falls back to Apple clang.

`mise run demo` launches the existing build without compiling it again.
`mise run run -- --demo` rebuilds first. Each demo uses a new private temporary
directory and entirely synthetic history.
Search for `preservation`, open a result, scroll its transcript, and use Why or
Export. The exported Markdown identifies the selected snapshot and verification
extent. Unsupported glyphs display boxes; copy and export retain original Unicode.

An optional local `.app` requires no signing project:

```sh
mise run app -- "build/Juice Bend Local.app"
open "build/Juice Bend Local.app" --args --data-dir /tmp/juice-bend-demo --demo
```

Choose an unused bundle path: packaging refuses to overwrite a running or
existing bundle. Direct GUI launch needs a desktop session. Restricted shell
agents may lack display access even on a Mac.

The fixed native window uses a green History navigation rail, yellow selection,
provider filters, proportional UI labels and a selectable monospace transcript. Click the footer status to
read or copy its full message; Escape closes it. Wheel and Page Up/Down scroll
the reader. Usage and Related show when automatic capture is suspended until
you return to History; the saved Pause/Resume preference remains separate.

Font data is pinned to JetBrains Mono 2.304 for selectable text and Inter 4.1
for UI labels, with their SIL OFL licenses included. `mise run font-check` and
`mise run sans-font-check` verify the checked-in Bend atlases. These are static
Latin-1/punctuation glyph sets, not general Unicode shaping or font fallback.
Offline font packing adds no application runtime. See the
[mono](assets/fonts/jetbrains-mono/README.md) and
[UI font](assets/fonts/inter-ui/README.md) asset records.

## Local quota observations

Settings → Connections offers explicit local Claude usage collection. Enable,
review Manual setup, then copy its fragment if you choose to install it yourself.
Juice Bend does not install provider configuration or access an account. Until a
usable feed arrives, usage remains unknown; a recorded zero stays distinct.
Disconnect rejects callbacks from that connection and preserves sampled history.
These observations are separate from captured-session usage and billed spend.
See [native validation](docs/receipts/connections-native.txt) for tested behavior
and remaining presentation/provider-integration limits.

## Capture your selected sources

Without `--demo`, the default library is
`~/Library/Application Support/JuiceBend/`. No provider history is scanned
automatically. In Settings, choose Claude or Codex and enter a literal absolute
path. **Add folder** registers a directory; **Import file** captures one JSONL
file or `.jsonl.zst` archive. Select a registered folder before using Enable or
Disable. Disabling a folder preserves its captured history. Refresh processes
bounded batches.

Archive capture uses a Bend 2 Zstandard decoder and preserves both the exact
compressed container and decoded JSONL in the owned library. The initial
streaming profile accepts at most 64 MiB compressed, 256 MiB decoded, an 8 MiB window,
64 frames and 4,096 blocks per ordinary frame. Raw, RLE and ordinary compressed
blocks, checksums, concatenated frames and skippable frames are supported;
external dictionaries are not. These archive limits leave plain JSONL limits
unchanged and do not establish full archive parity.

Transcript pages show readable event text and citations, with word wrapping that
preserves the original copied text. **Attachments** opens the retained occurrence
inventory for the selected page. Supported inline base64 bytes can be exported to
a new private file. A selected local file can also be captured under an explicitly approved
folder; its retained bytes remain available after that folder is disabled or
the source disappears. Remote references are never fetched. Basic PNG and
baseline JPEG previews support Fit, actual pixels and panning. Unsupported
formats retain explicit coverage and byte export. Back restores the opened
transcript and its selection.

Pause/Resume and the 30-second, 2-hour, 4-hour, 8-hour or daily interval are saved
in the owned library. The UI distinguishes pending changes from acknowledged
preferences. An active capture finishes safely; manual Refresh remains available
while automatic refresh is paused. Back restores the prior reader and selection.

CLI commands use the same Bend storage and parsing code:

```sh
APP=./build/juice-bend
DATA=/tmp/juice-bend-explicit-library
"$APP" --data-dir "$DATA" source-add claude /absolute/selected/history
"$APP" --data-dir "$DATA" refresh-all
"$APP" --data-dir "$DATA" refresh-preferences
"$APP" --data-dir "$DATA" refresh-preferences-set false 7200
"$APP" --data-dir "$DATA" history
"$APP" --data-dir "$DATA" search '"captured evidence"' claude '' assistant ''
"$APP" --data-dir "$DATA" session 1 0 20
"$APP" --data-dir "$DATA" session-usage 1
"$APP" --data-dir "$DATA" why 1 0 20
"$APP" --data-dir "$DATA" verify 1
"$APP" --data-dir "$DATA" export-range 1 0 20 /tmp/selected-evidence.md
"$APP" --data-dir "$DATA" export-all 1 /tmp/complete-retained.jsonl
"$APP" --data-dir "$DATA" help
```

Use snapshot IDs returned by your library. `export-all` preserves every logical
source byte in that accepted extent, including malformed JSONL. For archives,
these are the decoded bytes; citations also use decoded byte offsets.
`export-container SNAPSHOT PATH` writes the exact retained `.jsonl.zst`
container. Both exports work after the original source disappears. Output
destinations must not exist and cannot replace the original source locator.
`verify SNAPSHOT` checks both retained streams and their transformation for an
archive. `rebuild SNAPSHOT` verifies retained bytes before rebuilding
derived events/search; it never repairs raw bytes by changing their hashes.
Refresh reports can contain per-source failures: inspect `failed` and discovery
coverage even when the reporting command exits successfully.

With a transcript open in History, **Export evidence** keeps the displayed
range and scope. **Export full JSONL** and **Export archive** export the complete
pinned capture, including records outside current filters; the latter requires
an archive capture. The app writes private files in its data directory and
shows the path in its status message. Actual Tart interaction passed import,
filtered search, copy, both full exports and retained reads/exports after source
removal and restart. See [archive validation](docs/receipts/archive-native.txt).

Opening an existing Juice Bend library upgrades it to schema 3 while preserving
plain captures and their identities. Earlier builds that support only schema 2
refuse to open the upgraded library. This is separate from the original Juice
database, which is never migrated or modified.

Usage reads the whole pinned captured session from verified owned bytes, within
explicit record/byte/key limits. It separates scan coverage from accounting
coverage, deduplicates supported Claude mirrors and interprets recorded Codex
counters conservatively. Unknown values remain unknown; these are recorded token
facts, not billing or subscription totals. Back restores the original reader.
Repository/role/date-scoped views refuse widening to a whole-session summary.

Search supports literal words, quoted phrases, and GUI filters such as
`provider:claude repo:"/selected/repository" role:assistant after:2026-10-01`.
Blame uses an explicitly selected repository and relative path. Recorded tool
intent and matching content do not by themselves prove a successful change or
authorship.

Files opens an explicit local checkout at a pinned commit. Paste its absolute
path and choose Open repo, then select folders or committed source files.
Prev/Next list pages directory entries; Prev/Next text pages source lines.
Blame and Why inspect the displayed range. Copy and Export preserve the exact
displayed text. History restores your retained transcript selection. Files
does not follow symlinks or show uncommitted changes; Open repo explicitly pins
the current HEAD again. The `repo-open`, `repo-tree`, `repo-source`, `repo-blame`
and `repo-why` CLI commands expose the same bounded operations.

Tools (or Command+T) opens recorded tool activity for the selected capture and
filters. Prev/Next text pages 40 captured records; calls and results retain
their own citations. A missing counterpart may be outside this page, and a
recorded result does not prove successful execution. Copy and Export retain
the displayed text. `activity-scope SNAPSHOT START COUNT PROVIDER REPOSITORY
ROLE AFTER` exposes the same reader through the CLI, with at most 100 records.

Related (or Command+G) opens bounded parent/child links from retained metadata.
It pins an accepted-capture watermark and keeps the selected reader's filters.
Prev/Next list pages candidate sources; selecting a row opens its exact capture.
Back returns to the Related page, then the original reader and selection.
Recorded parent IDs and retained path associations have distinct labels;
missing or ambiguous links remain explicit. Refresh rereads the pinned page;
Back and a new Related entry explicitly choose a fresh watermark. The CLI
commands `relations-scope` and `relations-page` expose the same evidence.

## Validation and current limits

```sh
mise run test
mise run prove
mise run bench -- 100000
mise run smoke-ui
```

`prove` distinguishes ordinary Bend checking from the stronger kernel.
Both now pass for the twelve production laws on the implementation host.
The optional `mise run setup-lean` installs the exact Lean 4.34.0 archive into
`.tools` after SHA-256 verification; it needs `zstd` on PATH. An already
downloaded official archive can be supplied as its only argument. No global
tool installation is performed. See the [toolchain receipt](docs/receipts/lean-toolchain.txt).
Lean is a development-time dependency of Bend's upstream proof checker. It is
not linked into the application or required to build, launch or use the app.
Tests, fixture generators, benchmarks and proof logic are Bend.

`mise run build-trace` builds the optional bounded GUI callback diagnostic;
its measurements and limits are in [native validation](docs/native-validation.md).
`mise run build-vm` produces a separate macOS 26-compatible executable.
The optional `mise run vm-session -- PAYLOAD NEW_ARTIFACTS` reserves the existing
external-SSD `juice-tests` VM with isolated shares and an exclusive lease.
It starts a VM session only, not an app or test, and refuses an active VM or
existing lease.
Networking defaults to host-only. For an explicit toolchain download session,
`JUICE_BEND_VM_NETWORK=shared mise run vm-session -- PAYLOAD NEW_ARTIFACTS`
uses Tart's shared NAT; the selected mode is recorded in the artifacts. Native
app validation should normally keep the host-only default.

Implementation and native acceptance are still in progress. See
[acceptance](docs/acceptance.md), [performance](docs/performance.md),
[capabilities](docs/capabilities.md), and the exact
[continuation checkpoint](docs/progress.md). Backend timing does not establish
native responsiveness. The tested renderer uses a fixed 1200×664 content window
and a limited 204-glyph atlas. Its entire decorated window fits at 1280×800 with
the Dock shown; native paging, selection, copy and exports passed. See the
[compact native receipt](docs/receipts/compact-native.txt). General resizing,
complete shaping, IME and accessibility parity are not claimed.

All maintained application logic and UI are Bend 2. The sole maintained native
adapter is the narrow SQLite bridge. The compiled app needs neither Bun nor the
existing Juice process. No semantic search, inference, downloads of models,
webview, signing, notarization or distribution service is included.

Use synthetic data for tests. Never commit personal transcripts, credentials,
real logs, private source snapshots, or screenshots of private history.
The original Juice checkout/database and provider sources remain read-only.
