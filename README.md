# Juice Bend

An experimental, standalone native reproduction of Juice's core history and provenance workflow, written in Bend 2.

## Run locally

Requires an Apple Silicon Mac, Xcode command-line tools, and
[mise](https://mise.jdx.dev/). The compiler host is Bun 1.4.2, pinned in
`mise.toml`. Bend 2.0.37 is pinned by revision and source hashes. SQLite must
provide FTS5; `doctor` and the bridge tests check it.

```sh
mise trust
mise install
mise run setup
mise run doctor
mise run build
mise run run -- --demo
```

The demo uses a new private temporary directory and entirely synthetic history.
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

## Capture your selected sources

Without `--demo`, the default library is
`~/Library/Application Support/JuiceBend/`. No provider history is scanned
automatically. Settings lets you choose Claude or Codex and enter an explicit
local file or directory. Registration is opt-in. Refresh processes registered
roots in bounded batches; Pause stops automatic refresh scheduling.

CLI commands use the same Bend storage and parsing code:

```sh
APP=./build/juice-bend
DATA=/tmp/juice-bend-explicit-library
"$APP" --data-dir "$DATA" source-add claude /absolute/selected/history
"$APP" --data-dir "$DATA" refresh-all
"$APP" --data-dir "$DATA" history
"$APP" --data-dir "$DATA" search '"captured evidence"' claude '' assistant ''
"$APP" --data-dir "$DATA" session 1 0 20
"$APP" --data-dir "$DATA" why 1 0 20
"$APP" --data-dir "$DATA" verify 1
"$APP" --data-dir "$DATA" export-range 1 0 20 /tmp/selected-evidence.md
"$APP" --data-dir "$DATA" export-all 1 /tmp/complete-retained.jsonl
"$APP" --data-dir "$DATA" help
```

Use snapshot IDs returned by your library. `export-all` preserves every raw
byte in that accepted extent, including malformed input. Output destinations
must not exist. `rebuild SNAPSHOT` verifies retained bytes before rebuilding
derived events/search; it never repairs raw bytes by changing their hashes.
Refresh reports can contain per-source failures: inspect `failed` and discovery
coverage even when the reporting command exits successfully.

Search supports literal words, quoted phrases, and GUI filters such as
`provider:claude repo:"/selected/repository" role:assistant after:2026-10-01`.
Blame uses an explicitly selected repository and relative path. Recorded tool
intent and matching content do not by themselves prove a successful change or
authorship.

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
Tests, fixture generators, benchmarks and proof logic are Bend.

`mise run build-trace` builds the optional bounded GUI callback diagnostic;
its measurements and limits are in [native validation](docs/native-validation.md).
`mise run build-vm` produces a separate macOS 26-compatible executable.
The optional `mise run vm-session -- PAYLOAD NEW_ARTIFACTS` reserves the existing
external-SSD `juice-tests` VM with isolated shares. Coordinate with other VM
users first; it starts a VM session only, not an app or test, and refuses an
active VM or existing lease.
Networking defaults to host-only. For an explicit toolchain download session,
`JUICE_BEND_VM_NETWORK=shared mise run vm-session -- PAYLOAD NEW_ARTIFACTS`
uses Tart's shared NAT; the selected mode is recorded in the artifacts. Native
app validation should normally keep the host-only default.

Implementation and native acceptance are still in progress. See
[acceptance](docs/acceptance.md), [performance](docs/performance.md),
[capabilities](docs/capabilities.md), and the exact
[continuation checkpoint](docs/progress.md). Backend timing does not establish
native responsiveness. The tested renderer uses a fixed practical window and
ASCII glyph set; complete shaping, IME and accessibility parity are not claimed.

All maintained application logic and UI are Bend 2. The sole maintained native
adapter is the narrow SQLite bridge. The compiled app needs neither Bun nor the
existing Juice process. No semantic search, inference, downloads of models,
webview, signing, notarization or distribution service is included.

Use synthetic data for tests. Never commit personal transcripts, credentials,
real logs, private source snapshots, or screenshots of private history.
The original Juice checkout/database and provider sources remain read-only.
