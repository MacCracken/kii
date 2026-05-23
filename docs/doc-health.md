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
| `CHANGELOG.md` | 1 | 2026-05-23 (v1.0.0 close) | `[0.7.0]` … `[0.1.0]` entries; rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-05-22 | Fresh. Standard + kii-specific milestone-alignment notes. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-05-22 | Fresh. Threat model explicit; image-decoder hardening discipline captured. |
| `cyrius.cyml` | 1 | 2026-05-23 (v1.0.0 close) | Description filled; stdlib deps + toolchain pin set. `[deps.darshana] tag = "0.5.3"`. No deltas at M6 (M6 uses already-pinned `tty_winsize`). |
| `docs/development/state.md` | 1 | 2026-05-23 (v1.0.0 close) | v1.0 close snapshot: **471 assertions**, M8 hardening + ADRs + getting-started + examples + W3C walk landed. **Bump per release.** |
| `docs/benchmarks.md` | 1 | 2026-05-23 (v0.8.0 — M7d capture) | M4 scalar + M5/M6 end-to-end (3 sizes) + M7(d) decode-latency matrix + M7(b) fuzz-coverage summary. No v1.0 perf-critical changes; no refresh needed. |
| `docs/development/roadmap.md` | 1 | 2026-05-23 (v1.0.0 close) | All M0–M8 in "Shipped milestones" table. M8 close + v1.0 acceptance criteria checked; deferred-to-v1.x explicitly listed. |
| `docs/audit/2026-05-22-audit.md` | 1 | 2026-05-23 (v1.0.0 close + Appendix A) | 140 CVE/issue rows + 10 kii-specific findings + § Appendix A W3C PngSuite walk (added at M8 close). Load-bearing reference for ADR 0002. |
| `docs/audit/chafa-comparison.md` | 1 | 2026-05-23 (v1.0.0 close) | **NEW at M8(b3).** kii vs `chafa --colors 16` across 6 curated fixtures. Byte-stream metrics + qualitative findings + acceptance-criterion close-out. Validates ADRs 0003 / 0004 / 0005 against chafa as reference impl. |
| `docs/adr/README.md` | 2 | 2026-05-23 (v1.0.0 close) | Index updated. ADRs 0001 + 0002 + 0003 + 0004 + 0005 all listed. |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-05-22 (v0.7.0 — first ADR) | First ADR; captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. |
| `docs/adr/0002-security-model.md` | 2 | 2026-05-23 (v0.8.0 close) | Threat model + M7(c) hardening commitments (C1–C4) + accepted residual risks. Cross-links audit doc + SECURITY.md. |
| `docs/adr/0003-color-tier-discipline.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c1).** Captures tier-1 (8/16-color) v1.0 scope; tier-2/tier-3 deferral. |
| `docs/adr/0004-half-block-floor-glyph.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c2).** Captures `▀`/`▄` glyph-pair-as-floor choice; quarter-blocks + braille post-v1. |
| `docs/adr/0005-nearest-neighbor-downscale.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c3).** Captures nearest-neighbor downscale choice; bilinear/Lanczos defer to tier-2 alongside dithering. |
| `docs/architecture/README.md` | 2 | 2026-05-23 (v1.0.0 close) | **Backfilled.** Module map + 6 numbered items (pstruct layout, half-block aspect math, pipe-purity, darshana BG-256 inline copy, quant.cyr dual-surface rationale, 80×24 non-TTY fallback). Was overdue M2 → M6; landed at M6 close. |
| `docs/guides/getting-started.md` | 2 | 2026-05-23 (v1.0.0 close) | **Backfilled at M8(c4).** Install → first render → CLI flags → common pipelines → error reference → deferred-features list → where-to-next. |
| `docs/examples/README.md` | 3 | 2026-05-23 (v1.0.0 close) | **Backfilled at M8(c5).** Index + convention for the examples dir. |
| `docs/examples/01-ramgon-fixed-width/` | 3 | 2026-05-23 (v1.0.0 close) | RAMGON.png happy path (RGBA color_type=6). |
| `docs/examples/02-archlinux-logo-palette/` | 3 | 2026-05-23 (v1.0.0 close) | Palette PNG (color_type=3) — different code path. |
| `docs/examples/03-not-a-png-rejection/` | 3 | 2026-05-23 (v1.0.0 close) | Error-path diagnostic + exit-code contract. |
| `tests/kii.tcyr` | 2 | 2026-05-23 (v1.0.0 close) | **470 assertions** (was 426 at v0.7.0; +44 M7(c): 24 path-sanitizer + 16 dimension/cross-product caps + 2 ratio + 2 chunk-ordering FSM). Expand per milestone. |
| `tests/kii.bcyr` | 2 | 2026-05-23 (v1.0.0 close) | **Seven benches**: M4 scalar + M5/M6 end-to-end (3 sizes) + **M7(d) decode-latency matrix (3 source-resolution classes)**. |
| `tests/kii.fcyr` | 2 | 2026-05-23 (v1.0.0 close) | **Five fuzz surfaces at 3,011,000 total iters**: arg-parser (10k) + path-sanitizer (1M, M7(b) new) + geometry (1M, M7(b) new) + emit-pipeline (1k, M7(b) new) + PNG-decoder (1M, scaled from 2k at M7(b)). All deterministic-LCG; ~16.4 s wall-clock total. |
| `.github/workflows/ci.yml` | 1 | 2026-05-22 (post-0.2.0) | `workflow_call:` + binary-name fix + version-drift smoke + fuzz step landed. **Still pending**: CHANGELOG-extracted release notes, aarch64 cross-build (tracked in `[Unreleased]` CHANGELOG). |
| `.github/workflows/release.yml` | 1 | 2026-05-22 (post-0.2.0) | Binary-name fix landed. CHANGELOG-extracted release notes + multi-arch builds pending. |
| `LICENSE` | 1 | 2026-05-22 | GPL-3.0-only header (parity with bannermanor/hapi/etc.). |
| `.gitignore` | 2 | 2026-05-22 | Standard scaffold. |

## Debt summary at v1.0.0

- **Tier-1 docs**: all fresh. **Carry-forward** from v0.3.0: `release.yml` multi-arch / CHANGELOG-extracted-notes / Sigstore punch list still pending a dedicated CI cycle. **CI doesn't yet run benchmarks** — should be a follow-up step alongside the version-drift + fuzz + test steps already wired.
- **Tier-2 docs**: all 5 ADRs landed (0001–0005); getting-started + examples backfilled at M8. No tier-2 debt at v1.0.
- **Fuzz coverage**: 3M+ iters across 5 surfaces clean. No expansion needed at v1.0.
- **Per-chunk length cap table** (audit Finding 6): LANDED at M8(b2). IEND-length-zero + generic 256 MB per-chunk cap; covers the libpng CVE-2017-12652 class.
- **W3C PNG test-suite walk**: LANDED at M8(b4). 14/14 broken rejected, 82/162 valid OK, 0 crashes. Audit § Appendix A captures results.
- **Repo hygiene**: `tests/fixtures/RAMGON.png` (1973 KB) — moved from top level at M8(b1).

### Carried forward to v1.x (NOT v1.0 blockers)

- **Cross-terminal verification**: needs human-eye per-terminal pass (Linux console / xterm / Alacritty / kitty / tmux). v1.0 ships byte-stable; verification can land any time. (chafa visual review CLOSED at v1.0 — see `docs/audit/chafa-comparison.md`.)
- **Marketplace recipe in zugot**: depends on zugot tooling.
- **Three sankoch upstream items** (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers): file as sankoch issues.
- **CI bench step**: build-only would catch bitrot without per-PR timing noise.

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
