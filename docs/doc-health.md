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
| `CHANGELOG.md` | 1 | 2026-05-23 (v0.8.0 close) | `[0.7.0]` … `[0.1.0]` entries; rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-05-22 | Fresh. Standard + kii-specific milestone-alignment notes. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-05-22 | Fresh. Threat model explicit; image-decoder hardening discipline captured. |
| `cyrius.cyml` | 1 | 2026-05-23 (v0.8.0 close) | Description filled; stdlib deps + toolchain pin set. `[deps.darshana] tag = "0.5.3"`. No deltas at M6 (M6 uses already-pinned `tty_winsize`). |
| `docs/development/state.md` | 1 | 2026-05-23 (v0.8.0 close) | M7 close snapshot: **470 assertions**, M7(c) hardening commits landed, 3M+ fuzz iters across 5 surfaces, 7 benches (incl. decode-latency matrix). **Bump per release.** |
| `docs/benchmarks.md` | 1 | 2026-05-23 (v0.8.0 close) | M4 scalar + M5/M6 end-to-end (3 sizes) + **M7(d) decode-latency matrix at 256² / 1024² / 2048² source classes** + M7(b) fuzz-coverage summary. **Bump per release that lands perf-critical paths.** |
| `docs/development/roadmap.md` | 1 | 2026-05-23 (v0.8.0 close) | M0-M8 milestones; M0-M7 condensed into "Shipped milestones" table; M8 (v1.0.0 — freeze + consumer integration + W3C broken-set walk) remaining. |
| `docs/audit/2026-05-22-audit.md` | 1 | 2026-05-23 (v0.8.0 close) | **NEW at M7(a).** 140 CVE/issue rows across libpng / lodepng+stb_image / zlib / terminal-emulator corpora + 10 kii-specific findings with severity + remediation status. Load-bearing reference for ADR 0002. |
| `docs/adr/README.md` | 2 | 2026-05-23 (v0.8.0 close) | Index updated. ADRs 0001 + 0002 land. |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-05-22 (v0.7.0 — first ADR) | First ADR; captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. |
| `docs/adr/0002-security-model.md` | 2 | 2026-05-23 (v0.8.0 close) | **NEW at M7(d).** Threat model + M7(c) hardening commitments (C1–C4) + accepted residual risks. Cross-links audit doc + SECURITY.md. |
| `docs/architecture/README.md` | 2 | 2026-05-23 (v0.8.0 close) | **Backfilled.** Module map + 6 numbered items (pstruct layout, half-block aspect math, pipe-purity, darshana BG-256 inline copy, quant.cyr dual-surface rationale, 80×24 non-TTY fallback). Was overdue M2 → M6; landed at M6 close. |
| `docs/guides/getting-started.md` | 2 | 2026-05-22 (cyrius init template) | Template-only. Carried to M8 (v1.0 freeze) — pairs with the cross-terminal visual review and curated fixtures dir. |
| `docs/examples/.gitkeep` | 3 | 2026-05-22 (cyrius init template) | Empty. Carried to M8 (v1.0 freeze) — first image-in → terminal-ANSI-out transcript pairs with the M8 fixtures dir. |
| `tests/kii.tcyr` | 2 | 2026-05-23 (v0.8.0 close) | **470 assertions** (was 426 at v0.7.0; +44 M7(c): 24 path-sanitizer + 16 dimension/cross-product caps + 2 ratio + 2 chunk-ordering FSM). Expand per milestone. |
| `tests/kii.bcyr` | 2 | 2026-05-23 (v0.8.0 close) | **Seven benches**: M4 scalar + M5/M6 end-to-end (3 sizes) + **M7(d) decode-latency matrix (3 source-resolution classes)**. |
| `tests/kii.fcyr` | 2 | 2026-05-23 (v0.8.0 close) | **Five fuzz surfaces at 3,011,000 total iters**: arg-parser (10k) + path-sanitizer (1M, M7(b) new) + geometry (1M, M7(b) new) + emit-pipeline (1k, M7(b) new) + PNG-decoder (1M, scaled from 2k at M7(b)). All deterministic-LCG; ~16.4 s wall-clock total. |
| `.github/workflows/ci.yml` | 1 | 2026-05-22 (post-0.2.0) | `workflow_call:` + binary-name fix + version-drift smoke + fuzz step landed. **Still pending**: CHANGELOG-extracted release notes, aarch64 cross-build (tracked in `[Unreleased]` CHANGELOG). |
| `.github/workflows/release.yml` | 1 | 2026-05-22 (post-0.2.0) | Binary-name fix landed. CHANGELOG-extracted release notes + multi-arch builds pending. |
| `LICENSE` | 1 | 2026-05-22 | GPL-3.0-only header (parity with bannermanor/hapi/etc.). |
| `.gitignore` | 2 | 2026-05-22 | Standard scaffold. |

## Debt summary at v0.8.0

- **Tier-1 docs**: all fresh. **Carry-forward** from v0.3.0: `release.yml` multi-arch / CHANGELOG-extracted-notes / Sigstore punch list still pending a dedicated CI cycle. **CI doesn't yet run benchmarks** — should be a follow-up step alongside the version-drift + fuzz + test steps already wired. Build-only would be enough.
- **Tier-2 docs**: **`adr/0002-security-model.md` LANDED at M7(d)** (was scoped at M7 close). Remaining cyrius-init-template stubs (`adr/template`, `guides/getting-started`, `examples/.gitkeep`) — carried to **M8** (v1.0 freeze) alongside the curated-fixtures dir + cross-terminal visual review.
- **Fuzz coverage**: M7(b) raised iteration counts 2k → 10⁶ for PNG-decoder and added three new surfaces (path-sanitizer, geometry, emit-pipeline). All five surfaces clean at full scale.
- **Per-chunk length cap table** (audit doc Finding 6, libpng CVE-2017-12652 class): carried to **M8**. IDAT cumulative cap from M7(c) C3 covers the OOM-DoS leverage; per-chunk caps are marginal-value.
- **W3C PNG test-suite "broken" set walk**: deferred from M7(a) → **M8** alongside cross-terminal verification (the broken set is hosted in the W3C test corpus; needs download + automation).
- **Cross-terminal verification + visual review vs `chafa --colors 16`**: M8 work. Needs curated fixtures dir + chafa install + each-terminal manual pass.
- **Three sankoch upstream items** (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers): file as sankoch issues; track as kii v1.0 release gate.
- **Repo hygiene**: `RAMGON.png` (1973 KB) committed at top level as a real-world test fixture. Move to `tests/fixtures/` at M8 alongside the curated-set acquisition.

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
