# Codex kickoff — Juice Bend

Read `JUICE_BEND_SPEC.md` completely and treat it as an implementation assignment.

Build `juice-bend`: a standalone native macOS/Apple Silicon reproduction of Juice's core preserve, browse, lexical-search, transcript, Blame and Why experience. All first-party application logic, UI, parsing, indexing, tests and proofs must be Bend 2. SQLite and a minimal SQLite bridge are the explicit native-code exception. Existing Bend runtime/OS facilities and minimal build scripts are allowed as specified. Do not substitute a Swift/Rust/C++ UI or core, webview, JavaScript app, Python worker, or the existing Juice service.

No semantic search, embeddings, inference, model downloads, signing/notarization project, or distribution work. It just needs to build and run locally. Keep the original Juice checkout, library, agent logs and repositories unchanged. Use synthetic data and isolated data directories by default.

Inspect the pinned Juice reference and the actual installed Bend guide/Base. Verify native window/text/input, SQLite/FTS5, raw bytes and numeric boundaries before assuming capabilities. Establish a real vertical slice: native UI → Bend parser → owned SQLite capture → FTS query → readable transcript. Then complete the specification's durable library, UI, provenance, tests, proofs and measured performance goals.

Act as the integration lead. Use available subagents for independent areas and review after settling shared contracts. Make ordinary engineering decisions without asking me to approve each step. Keep a working executable, commit coherent changes, and maintain concise progress/decision/acceptance records. Milestones are not stopping points. Do not return only a plan, scaffold or benchmark.

Do not weaken tests or laws, fabricate native test results, or hide application logic in the SQLite bridge. A genuine toolchain blocker needs a minimal reproducer and honest affected-scope report; continue other work rather than silently changing the language boundary. Save a precise continuation checkpoint if the execution context ends.

Finish with the runnable artifact where the environment permits, exact launch command, acceptance results, remaining limitations, proof boundaries, measured performance and a complete accounting of non-Bend code. Do not claim completion until the core workflow actually works in the native Bend application.

## Cloud execution addendum — owner authorization, 2026-10-20

The owner subsequently requested that this work be kicked off in Codex Cloud in the newly created `tcashel/juice-bend` repository. This addendum supersedes only the earlier specification's local-only/no-remote-publication restriction for this destination. Implementation commits and pull-request updates in `tcashel/juice-bend` are authorized; other repositories remain read-only. Continue on the task's existing implementation branch when permitted, return the work through its PR, and do not merge it automatically or publish releases/packages. Do not change repository visibility or branch protection.

The requested run configuration is **Astra with ultracode effort**, if that model/effort is available to the owner's Codex Cloud account. A sentence in this file is not proof that the service selected those settings. Record the actual setting only if the run exposes it; otherwise report it as unverified. Do not invent model IDs or configuration flags.

Inspect the actual cloud operating system, architecture, display access, compiler and permissions before deciding which probes can run. If the environment is Linux or headless, implement the macOS-targeted application and complete every portable build/test/proof task available, using an upstream-supported native Linux test backend only where useful. This does not change the product target. Do not replace the native UI with a website, and do not stop all work merely because macOS-specific execution is unavailable. Keep macOS UI/input/clipboard/Metal/signing-dependent observations explicitly **not run** until a real authorized macOS host is available. Provide precise local Mac build and validation commands. Headless render tests or Linux results are not macOS validation.

`tcashel/juice` may be private and may not be accessible from this cloud environment. Use it read-only only through existing authorized access; do not seek credentials, broaden permissions, or publish private source snapshots. If access is missing, record the exact limitation, implement from this detailed specification and synthetic fixtures, and mark reference-parity checks unverified rather than blocking unrelated work or fabricating inspection.

This repository is public. Commit only first-party implementation, appropriately licensed dependencies/assets, synthetic fixtures, and sanitized technical evidence. Never commit personal transcripts, credentials, production databases, private repository snapshots or screenshots of private history. Dependency downloads needed to build are allowed; inference/API spending, new hosted services and paid hosted CI are not authorized by this task.
