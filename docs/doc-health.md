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
| `CHANGELOG.md` | 1 | 2026-05-22 (v0.7.0 close) | `[0.7.0]` … `[0.1.0]` entries; rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-05-22 | Fresh. Standard + kii-specific milestone-alignment notes. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-05-22 | Fresh. Threat model explicit; image-decoder hardening discipline captured. |
| `cyrius.cyml` | 1 | 2026-05-22 (v0.7.0 close) | Description filled; stdlib deps + toolchain pin set. `[deps.darshana] tag = "0.5.3"`. No deltas at M6 (M6 uses already-pinned `tty_winsize`). |
| `docs/development/state.md` | 1 | 2026-05-22 (v0.7.0 close) | M6 close snapshot: 426 assertions, full PNG → terminal-fit ANSI pipeline, four benches. **Bump per release.** |
| `docs/benchmarks.md` | 1 | 2026-05-22 (v0.7.0 — third capture) | M4 scalar + M5 end-to-end 80×24 + M6 end-to-end at 80×24 / 120×40 / 200×60. **Bump per release that lands perf-critical paths.** |
| `docs/development/roadmap.md` | 1 | 2026-05-22 (v0.7.0 close) | M0-M7 milestones laid out to v1.0; M6 marked ✅ shipped. |
| `docs/adr/README.md` | 2 | 2026-05-22 (v0.7.0 close) | Index updated. ADR 0001 lands. |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-05-22 (v0.7.0 — first ADR) | First ADR; captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. Was overdue M3 → M6; landed at M6 close. |
| `docs/architecture/README.md` | 2 | 2026-05-22 (v0.7.0 close) | **Backfilled.** Module map + 6 numbered items (pstruct layout, half-block aspect math, pipe-purity, darshana BG-256 inline copy, quant.cyr dual-surface rationale, 80×24 non-TTY fallback). Was overdue M2 → M6; landed at M6 close. |
| `docs/guides/getting-started.md` | 2 | 2026-05-22 (cyrius init template) | Template-only. Carried to M7 — pairs with the cross-terminal visual review and curated fixtures dir. |
| `docs/examples/.gitkeep` | 3 | 2026-05-22 (cyrius init template) | Empty. Carried to M7 — first image-in → terminal-ANSI-out transcript pairs with the M7 fixtures dir. |
| `tests/kii.tcyr` | 2 | 2026-05-22 (v0.7.0 close) | 426 assertions: M1-M4 (287) + M5 (95) + M6(a) target-geometry (24) + M6(b) fit-geometry + rejection coverage (20). Expand per milestone. |
| `tests/kii.bcyr` | 2 | 2026-05-22 (v0.7.0 close) | Four benches: `quantize_nearest_rgb @ 1024×1024` (M4) + `end-to-end RAMGON → 80×24 / 120×40 / 200×60` (M5 + M6). Future targets: decode-latency matrix at 256² / 1024² / 2048² SOURCE resolutions for M7 v1.0 acceptance. |
| `tests/kii.fcyr` | 2 | 2026-05-22 (v0.4.0 close) | Two fuzz surfaces: 10k arg-parser iters (M1(d)) + 2k PNG-decoder iters (M2(d)+(M3 inflate/filter through random-prefix path)). Both deterministic-LCG. |
| `.github/workflows/ci.yml` | 1 | 2026-05-22 (post-0.2.0) | `workflow_call:` + binary-name fix + version-drift smoke + fuzz step landed. **Still pending**: CHANGELOG-extracted release notes, aarch64 cross-build (tracked in `[Unreleased]` CHANGELOG). |
| `.github/workflows/release.yml` | 1 | 2026-05-22 (post-0.2.0) | Binary-name fix landed. CHANGELOG-extracted release notes + multi-arch builds pending. |
| `LICENSE` | 1 | 2026-05-22 | GPL-3.0-only header (parity with bannermanor/hapi/etc.). |
| `.gitignore` | 2 | 2026-05-22 | Standard scaffold. |

## Debt summary at v0.7.0

- **Tier-1 docs**: all fresh. Zero structural debt. **Carry-forward** from v0.3.0: `release.yml` multi-arch / CHANGELOG-extracted-notes / Sigstore punch list still pending a dedicated CI cycle. **CI doesn't yet run benchmarks** — should be a follow-up step alongside the version-drift + fuzz + test steps already wired. Build-only would be enough (catches bitrot without per-PR timing noise).
- **Tier-2 docs**: **`architecture/README.md` BACKFILLED at M6** (cleared 4-milestone overdue). **`adr/0001-png-decoder-in-repo.md` BACKFILLED at M6** (cleared 3-milestone overdue). Remaining cyrius-init-template stubs (`adr/template`, `guides/getting-started`, `examples/.gitkeep`) — carried to M7 alongside the curated-fixtures dir + cross-terminal visual review.
- **Fuzz coverage**: M5 + M6 added `downscale_to_rgb` + `quantize_downscaled` + `emit_halfblock` + the two geometry helpers; the fuzz harness still only covers arg-parser + structural-decoder. A "valid-PNG-fixture-then-random-{downscale-dims,target-geometry-inputs}" surface lands at M7 (security audit) — captured here so it doesn't slip silently.
- **Cross-terminal verification**: M5 + M6 visual review against `chafa --colors 16` deferred again — needs a curated fixtures dir + chafa install. M7-audit work; the geometry is stable now, so the comparison itself is reproducible.
- **Repo hygiene**: `RAMGON.png` (1973 KB) committed at top level as a real-world test fixture. Consider moving to `tests/fixtures/` when a second fixture surfaces (likely alongside M7's curated set).

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
