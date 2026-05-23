# Architecture Decision Records

Decisions about kii — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| ADR | Status | Subject |
|---|---|---|
| [0001](0001-png-decoder-in-repo.md) | Accepted | PNG decoder lives in-repo (not as a substrate library) until a second consumer surfaces |
| [0002](0002-security-model.md) | Accepted | Security model: untrusted-image input + restricted-emit posture (M7 audit cycle) |
| [0003](0003-color-tier-discipline.md) | Accepted | Color-tier discipline: tier-1 (8/16-color) only at v1.0 |
| [0004](0004-half-block-floor-glyph.md) | Accepted | Half-block (`▀`/`▄`) as the floor glyph |
| [0005](0005-nearest-neighbor-downscale.md) | Accepted | Nearest-neighbor downscale (no Lanczos / bilinear at v1.0) |
