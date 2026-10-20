# Decisions

- **2026-10-20 — Local macOS execution.** The owner's execution update supersedes
  the cloud host instructions. No cloud execution is needed for this app.
- **2026-10-20 — mise and exact source pin.** `mise.toml` pins Bun 1.4.2;
  `scripts/setup` selects Bend commit
  `60ca80aedeec9d8f0629b5f10dd19457d8ad67af`. Compiler telemetry is disabled.
  All build caches remain local to this repository.
- **2026-10-20 — Explicit native link.** Bend emits C; `scripts/build` applies
  the inspected upstream CPU flags plus `-lsqlite3`. Objective-C mode is used
  only when the generated upstream runtime contains framework imports.
- **2026-10-20 — Proof cache locality.** `scripts/prove` checks ordinary laws
  and proofs, builds the upstream Lean kernel locally when Lean 4.34.0 is
  available, then passes `BENDTT` to `--verdict`. Missing kernel prerequisites
  remain a failed gate; ordinary checking is recorded separately.
- **2026-10-20 — Test launch isolation.** Each native Bend test/benchmark gets a
  fresh temporary working directory. Shell wrappers own compilation/launch;
  fixtures, assertions, timings and statistics stay in Bend.
- **2026-10-20 — Canonical source identity.** Public import resolves the
  explicitly selected path through `/bin/realpath` before opening or registering
  it. Relative and symlink aliases converge; separate hard-link paths remain
  conservative separate sources. No private root is selected automatically.
- **2026-10-20 — Verified, non-replacing exports.** Complete raw export verifies
  every retained record inside a read transaction before writing a private
  sibling temporary file. `/bin/link` publishes it atomically only if the exact
  destination does not exist; this also rejects dangling symlinks and files
  created after preflight. Bounded text exports use the same publication path.
