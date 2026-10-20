# Juice Bend

An experimental, standalone native reproduction of Juice's core history and provenance workflow, written in Bend 2.

## Goal

Preserve local Claude Code and Codex session history, browse and lexically search it with SQLite FTS5, read captured transcripts, and inspect Blame/Why evidence in a native desktop application.

All first-party application logic and UI belong in Bend 2. SQLite and a minimal SQLite bridge are the explicit native-code exception. No semantic search, embeddings, inference, webview, or dependency on the existing Swift Juice process. The primary target is locally built macOS on Apple Silicon; signing/notarization and distribution infrastructure are not required.

## Status

Repository initialized for autonomous implementation. This README does not claim that an application has been implemented or tested yet. The implementation handoff will be supplied in the bootstrap pull request as `JUICE_BEND_SPEC.md`, `CODEX_KICKOFF.md`, and `AGENTS.md`.

Use synthetic data and isolated data directories. Never commit personal transcripts, credentials, real agent logs, private source snapshots, or screenshots containing private history. The existing Juice application, its data, and original provider logs remain unchanged.
