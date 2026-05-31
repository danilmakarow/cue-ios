# Cue iOS — docs/

This directory is the source of truth for **intent and decisions**.
The code is the source of truth for **behavior**.

## Layout

- **`architecture.md`** — one-page app overview. The 10,000-ft view a new contributor reads on day one. Updated rarely.
- **`adr/`** — Architecture Decision Records. One file per decision. Immutable once accepted; supersede with a new ADR rather than editing in place.
- **`specs/`** — Design docs. One file per significant feature or screen. Written *before* a non-trivial implementation, updated as the design evolves, archived when superseded.
- **DocC** (in source, not here) — symbol documentation lives as `///` comments on public types and is rendered via DocC. `docs/` covers the *why*; DocC covers the *what / API surface*.

The HTTP contract with the backend lives in [`cue-api/docs/api/openapi.yaml`](../../cue-api/docs/api/openapi.yaml).

## When to write what

| Situation | Artifact |
|---|---|
| Architectural decision (UI framework, persistence, navigation) | New [`adr/NNNN-*.md`](adr/) |
| Designing a new screen / feature / sub-flow | New [`specs/<feature>.md`](specs/) **before** coding |
| Public type / API documentation | DocC `///` comment in the source |
| Onboarding context that's neither a decision nor a feature | Update [`architecture.md`](architecture.md) |
| One-off note for *one* PR | The PR description — not a doc |

## How to write each kind

- **ADRs**: copy [`adr/TEMPLATE.md`](adr/TEMPLATE.md). Number sequentially (`0002-...`, `0003-...`). Title in kebab-case. State the decision and *why this not that*. Aim for one screen.
- **Specs**: copy [`specs/TEMPLATE.md`](specs/TEMPLATE.md). Lead with **Context → Goals → Non-goals**. Spend more time on **Alternatives considered** than on the chosen design. Mark **Open questions** explicitly.
- **DocC**: short `///` on every public type and non-trivial function. Skip on `body` and obvious SwiftUI boilerplate.

## Rules of the road

- **Living documents.** If code drifts from a spec, update the spec or write an ADR that supersedes it.
- **Short over long.** If a spec grows past ~2 screens, split it.
- **Diagrams inline as Mermaid.** No external image files unless Mermaid cannot express it.
- **Link liberally** between docs with relative paths.
- **The ADR log is append-only.** To overturn a past decision, write a new ADR that references and supersedes it; do not edit the original.
- **Cross-repo references**: when a spec depends on or constrains the BE, link the matching `cue-api/docs/specs/...` file.
