# kii — Doc Health Ledger

> Per-file doc-currency ledger. Modeled on the AGNOS doc-audit-discipline pattern
> ([feedback_doc_audit_discipline](https://github.com/MacCracken/agnosticos/blob/main/.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_doc_audit_discipline.md)).
>
> Each row tracks one doc + its last-verified-fresh date + tier + any debt. Refresh
> at every minor cut.

## Tiers

- **Tier 1 — Load-bearing**: read by Claude Code at session start; consumers reference these for integration. Drift cost = high.
- **Tier 2 — Reference**: consulted on specific work (porting, contribution); rotation drift cost = medium.
- **Tier 3 — Historical / archival**: snapshots; rotation drift cost = low.

## Ledger

| Doc | Tier | Last verified | Debt / notes |
|---|---|---|---|
| `README.md` | 1 | 2026-05-22 (v0.1.0 scaffold) | Fresh. Customized from `cyrius init` template. |
| `CLAUDE.md` | 1 | 2026-05-22 | Fresh. Custom Project Identity + Goal + color-tier discipline + domain rules. |
| `CHANGELOG.md` | 1 | 2026-05-22 (v0.3.0 close) | `[0.3.0]` + `[0.2.0]` + `[0.1.0]` entries; rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-05-22 | Fresh. Standard + kii-specific milestone-alignment notes. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-05-22 | Fresh. Threat model explicit; image-decoder hardening discipline captured. |
| `cyrius.cyml` | 1 | 2026-05-22 (v0.2.0 close) | Description filled; stdlib deps + toolchain pin set. `"flags"` added at v0.2.0. No deltas at v0.3.0 (M3 will add `sankoch`). |
| `docs/development/state.md` | 1 | 2026-05-22 (v0.3.0 close) | M2 close snapshot: 88 assertions, full PNG structural decode, two fuzz surfaces. **Bump per release.** |
| `docs/development/roadmap.md` | 1 | 2026-05-22 | M0-M7 milestones laid out to v1.0; acceptance criteria + dep gates per milestone. |
| `docs/adr/README.md` | 2 | 2026-05-22 (cyrius init template) | No ADRs yet; first ADR likely at M3 (sankoch dep adoption). |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/architecture/README.md` | 2 | 2026-05-22 (cyrius init template) | Empty placeholder. **Backfill at M2** when PNG decoder module structure crystallizes. |
| `docs/guides/getting-started.md` | 2 | 2026-05-22 (cyrius init template) | Template-only. **Backfill at M5** when the binary actually does something visible. |
| `docs/examples/.gitkeep` | 3 | 2026-05-22 (cyrius init template) | Empty. **Add at M5** (first image-in / ANSI-out example). |
| `tests/kii.tcyr` | 2 | 2026-05-22 (v0.3.0 close) | 88 assertions: smoke + `kii_validate_color` + flag-parse + PNG signature/IHDR/CRC32/walker. Expand per milestone. |
| `tests/kii.bcyr` | 2 | 2026-05-22 (cyrius init scaffold) | Stub. **Wire at M4** (first benchmark = quantization latency). |
| `tests/kii.fcyr` | 2 | 2026-05-22 (v0.3.0 close) | Two fuzz surfaces in one binary: 10k arg-parser iters (M1(d)) + 2k PNG-decoder iters (M2(d)). Both deterministic-LCG. |
| `.github/workflows/ci.yml` | 1 | 2026-05-22 (post-0.2.0) | `workflow_call:` + binary-name fix + version-drift smoke + fuzz step landed. **Still pending**: CHANGELOG-extracted release notes, aarch64 cross-build (tracked in `[Unreleased]` CHANGELOG). |
| `.github/workflows/release.yml` | 1 | 2026-05-22 (post-0.2.0) | Binary-name fix landed. CHANGELOG-extracted release notes + multi-arch builds pending. |
| `LICENSE` | 1 | 2026-05-22 | GPL-3.0-only header (parity with bannermanor/hapi/etc.). |
| `.gitignore` | 2 | 2026-05-22 | Standard scaffold. |

## Debt summary at v0.3.0

- **Tier-1 docs**: all fresh. Zero structural debt. **Carry-forward** from v0.2.0: `release.yml` still has the multi-arch / CHANGELOG-extracted-notes / Sigstore punch list pending a dedicated CI cycle. `workflow_call`, version-drift smoke, fuzz step, and binary-name fix all shipped between v0.2.0 and v0.3.0.
- **Tier-2 docs**: 5 cyrius-init-template stubs remaining (`adr/README`, `adr/template`, `architecture/README`, `guides/getting-started`, `examples/.gitkeep`) — `architecture/README` is the next due (M2-flagged backfill — file structure of the PNG decoder is now stable enough to document). `tests/kii.fcyr` graduated at M1(d); a `docs/adr/0001-png-decoder-in-repo.md` is the natural first ADR at M3 if the PNG decoder gets extracted to a substrate lib alongside `sankoch` adoption.

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
