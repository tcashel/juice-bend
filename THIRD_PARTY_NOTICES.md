# Dependency and asset notices

- **Bend compiler, Base and native runtime**: HigherOrderCO, Apache License 2.0.
  Pinned revision `60ca80aedeec9d8f0629b5f10dd19457d8ad67af`.
  License copied unmodified to `licenses/Bend-Apache-2.0.txt`. Sources are
  downloaded to ignored `.tools/bend`; generated native code includes upstream
  runtime facilities. No local upstream runtime patch is maintained.
- **SQLite**: the macOS system library, with FTS5 verified by the native bridge
  tests. Upstream SQLite is public domain. SQLite source is not vendored.
- **Bun 1.4.2**: compiler host managed by mise; not used by the native app.
- **macOS SDK/frameworks and command-line utilities**: supplied by the host.
  Upstream Bend uses AppKit/Metal for its window/rendering primitives.
  Application layout, text state and interactions remain Bend.
- **Font glyphs**: compact first-party bitmap patterns in `src/font.bend`.
  No system font file or third-party font asset was copied.
- **Juice reference**: inspected read-only at the specification's pinned
  revision for behavior. No private source snapshot or assets are included.

The application executes only explicit OS primitives with literal argv:
Git read-only inspection; `realpath`, `find` and `mkdir`; clipboard transport;
and `mktemp`/`link`/`rm` for atomic export publication and its own temporary
file cleanup. Tests additionally use local fixture setup/termination tools.
Recorded transcript commands are data and are never executed.

All maintained application modules, tests, benchmarks and laws are Bend.
`native/sqlite.c` is the only maintained first-party native adapter. Build
scripts contain compilation/launch/package steps, not application policy.
