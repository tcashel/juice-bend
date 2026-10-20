# Version record

Observed locally on 2026-10-20:

| Component | Selection / observation |
|---|---|
| Host | macOS 27.0.1 (26A434), arm64 |
| mise | 2026.9.12; repository `mise.toml` |
| Bun, compiler host only | 1.4.2, pinned through mise |
| Bend | 2.0.37, upstream `60ca80aedeec9d8f0629b5f10dd19457d8ad67af` |
| C compiler | Apple clang 21.0.0 (clang-2100.3.34.2) |
| Native CPU flags | `-std=c11 -O3 -lpthread -lm -lsqlite3`; upstream window runtime adds `-x objective-c -fobjc-arc -fmodules` |
| System SQLite diagnostic | `/usr/bin/sqlite3`: 3.54.0, FTS5 enabled; bridge probe is authoritative for the linked library |
| Owned library schema | SQLite `user_version=2`; latest-only FTS rowids, with additive `projection_checks` and `snapshot_context` tables |
| Derived parser state | `providers-v4-utc-context-relay`; context seals add `incoming-context-v1`. Missing or stale state requires verified replay |
| Stronger proof kernel | Pinned upstream requires Lean 4.34.0; not installed at initial inspection |
| Juice baseline | `ca66da7d9cc56f665900ba71ee9d97c37787c77d` from the specification |
| Read-only Juice checkout HEAD | `a9767a7296886301bf813fd3d3f99fa03fea05d0` at inspection |

`./scripts/doctor` refreshes local prerequisites without installing or changing
global tools. `toolchain/bend.sha256` locks the inspected upstream source files;
their Git blob IDs were verified against the selected revision before SHA-256
lock generation. Setup and doctor recheck those hashes.
The source/compiler cache is ignored under `.tools`; generated C,
native executables and the module cache are ignored under `build`. Bun does not
run in the shipped native application process.

The system SDK and SQLite are capability requirements rather than vendored
packages. Run the SQLite boundary tests when either changes. Do not substitute
the `sqlite3` found on PATH: this Mac also has a separate Conda SQLite 3.45.3.
