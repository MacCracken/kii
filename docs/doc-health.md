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
| `README.md` | 1 | 2026-08-25 (v1.5.1) | Status block refreshed to v1.5.1 and now names both render lanes. **New § Usage** — the README previously documented no flags at all, so `--mode` and `--color` were undiscoverable from it; the table, examples, exit codes and warning behaviour are all verified against the binary. Milestone list replaced by § How it got here, covering the post-v1 re-fold arc rather than stopping at v1.0. `cmdit` added to § Substrate (it owns all CLI parsing since v1.1.0 and was missing entirely). JPEG-RGB re-attributed to v1.5.0 (chitra 0.6.1), not v1.4.0. Counts: 550 assertions, 7 benches. All 13 internal links resolve. |
| `CLAUDE.md` | 1 | 2026-08-25 (v1.5.1) | Identity line lists all four formats. **Toolchain pin de-inlined** — it read `6.0.1` for eleven releases past the real pin, so the number is now a pointer to `cyrius.cyml`, matching the file's own VERSION rule. |
| `CHANGELOG.md` | 1 | 2026-06-27 (v1.4.0) | `[1.4.0]` JPEG entry added; rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-08-25 (v1.5.1) | Test section rewritten: the five split suites (the monolithic `tests/kii.tcyr` it used to name was retired at v1.2.0), eight fuzz surfaces with the `alloc_reset()`/`crc32_table` pairing requirement, the no-vanishing-bench rule, and current counts (550 / 6,011,000 / 7). |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-08-25 (v1.5.1) | Rewritten at the P-1 sweep. The "Adam7 + sub-byte depths rejected" claim (false since v1.2.2) replaced by the real refusal list; CRC bullet notes the non-PNG formats have no chunk CRC; buffer-bounds bullet covers the `--width` cap; the ANSI-filter bullet is now ✅ and documents the C1 guard in both encodings; fuzz bullet at eight surfaces. |
| `cyrius.cyml` | 1 | 2026-06-27 (v1.4.0) | `[deps.chitra] tag = "0.3.0"` (re-pin comment refreshed for the JPEG wiring); `[deps.darshana] 0.8.1` + `[deps.cmdit] 1.1.0`; version interpolates `${file:VERSION}` = 1.4.0. |
| `docs/development/state.md` | 1 | 2026-08-25 (v1.5.1) | v1.5.1 snapshot: **550 assertions** (cli 77 / quant 125 / render 164 / ascii 17 / decode 167), 6,011,000 fuzz iters across 8 surfaces (~136 MB peak), toolchain 6.5.35, `lib/` 39 files, binary 668 KB. § Next collapsed to a pointer at `roadmap.md` so the two stop drifting. **Bump per release.** |
| `docs/benchmarks.md` | 1 | 2026-05-23 (v0.8.0 — M7d capture) | M4 scalar + M5/M6 end-to-end (3 sizes) + M7(d) decode-latency matrix + M7(b) fuzz-coverage summary. No v1.0 perf-critical changes; no refresh needed. |
| `docs/development/roadmap.md` | 1 | 2026-08-25 (v1.5.1) | **Rewritten forward-facing only.** The three historical sections (v1.0 criteria, the M0–M8 milestone table, the post-v1 shipped log) were **deleted** rather than checked off — the CHANGELOG is the record — per the convention the header now states. What remains is open debt, the three `sankoch` limitations (S-1/S-2/S-3, with a re-verify-at-next-pin-bump trigger), durable scope guards, and § Roadmap ahead, whose stale version predictions were corrected and whose rename item now carries a measured blast radius. |
| `docs/audit/2026-05-22-audit.md` | 1 | 2026-05-23 (v1.0.0 close + Appendix A) | 140 CVE/issue rows + 10 kii-specific findings + § Appendix A W3C PngSuite walk (added at M8 close). Load-bearing reference for ADR 0002. |
| `docs/audit/chafa-comparison.md` | 1 | 2026-05-23 (v1.0.0 close) | **NEW at M8(b3).** kii vs `chafa --colors 16` across 6 curated fixtures. Byte-stream metrics + qualitative findings + acceptance-criterion close-out. Validates ADRs 0003 / 0004 / 0005 against chafa as reference impl. |
| `docs/adr/README.md` | 2 | 2026-08-24 (v1.5.0) | Index lists ADRs 0001–0009 (0009 BMP/GIF-via-chitra added). |
| `docs/adr/0008-jpeg-via-chitra.md` | 2 | 2026-08-24 (v1.5.0) | JPEG via chitra 0.3.0: signature-based format dispatch + JPEG validation posture (no CRC → structural). Realizes ADR 0006's JPEG line. Still accurate at v1.5.0; extended by ADR 0009. |
| `docs/adr/0009-bmp-gif-via-chitra.md` | 2 | 2026-08-24 (v1.5.0) | **NEW.** BMP + GIF via chitra 1.0.0 — the re-pin that needed no decode change; sets the rule that a format kii renders is a format kii must be able to name in an error. Extends ADR 0008, discharges ADR 0006. |
| `docs/audit/2026-08-25-audit.md` | 2 | 2026-08-25 (v1.5.1) | **NEW.** The P-1 sweep: 41 findings raised / 2 refuted / 39 folded into 16 work items, plus a "What the sweep did NOT find" section, the refuted findings, and four accepted risks (TAB/LF allow-list, sankoch's 16 MiB inflate cap, the sankoch Huffman hot spot, the deferred `png.*` → `image.*` rename). |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-05-22 (v0.7.0 — first ADR) | First ADR; captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. |
| `docs/adr/0002-security-model.md` | 2 | 2026-08-25 (v1.5.1) | Threat model + M7(c) hardening commitments (C1–C4) + accepted residual risks. **Amended at v1.5.1** (appended, not edited in place): the "eliminated CVE classes" list describes the pre-v1.2.0 in-repo decoder and no longer matches chitra's capabilities; and the C1-rejection alternative it declined was declined on a false premise — reversed, with the sanitizer now walking UTF-8 structure. |
| `docs/adr/0003-color-tier-discipline.md` | 2 | 2026-08-25 (v1.5.1) | Captures tier-1 (8/16-color) scope; tier-2/tier-3 deferral. **Amended at v1.5.1**: the "`--color 8` reservation without activation" is resolved — the flag had parsed and ignored its argument since M1 and now selects a real tier. |
| `docs/adr/0004-half-block-floor-glyph.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c2).** Captures `▀`/`▄` glyph-pair-as-floor choice; quarter-blocks + braille post-v1. |
| `docs/adr/0005-nearest-neighbor-downscale.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c3).** Captures nearest-neighbor downscale choice; bilinear/Lanczos defer to tier-2 alongside dithering. |
| `docs/architecture/README.md` | 2 | 2026-05-23 (v1.0.0 close) | **Backfilled.** Module map + 6 numbered items (pstruct layout, half-block aspect math, pipe-purity, darshana BG-256 inline copy, quant.cyr dual-surface rationale, 80×24 non-TTY fallback). Was overdue M2 → M6; landed at M6 close. |
| `docs/guides/getting-started.md` | 2 | 2026-08-25 (v1.5.1) | Install → first render → CLI flags → pipelines → error reference → unsupported list. **Three repairs at v1.5.1**: the toolchain pin said `6.0.1`; the `--help` block was stale and is now the binary's verbatim output (diff-verified); and § "What v1.0 does NOT support" listed JPEG/GIF/BMP, Adam7 and sub-byte depths — all five supported for releases — so it told readers to convert files kii reads natively. |
| `docs/examples/README.md` | 3 | 2026-05-23 (v1.0.0 close) | **Backfilled at M8(c5).** Index + convention for the examples dir. |
| `docs/examples/01-ramgon-fixed-width/` | 3 | 2026-08-25 (v1.5.1) | RAMGON.png happy path (RGBA color_type=6). Corrected: `expected.txt` claimed the frame ends with an "implicit" reset and "no trailing escape" — it ends with an explicit `ESC [ 0 m`, which is what protects the prompt. |
| `docs/examples/02-archlinux-logo-palette/` | 3 | 2026-08-25 (v1.5.1) | Palette PNG (color_type=3). Corrected: the notes described `_extract_rgb` doing the PLTE lookup, which moved into chitra at the v1.2.0 re-fold. |
| `docs/examples/03-not-a-png-rejection/` | 3 | 2026-08-25 (v1.5.1) | Error-path diagnostic + exit-code contract. Corrected at v1.5.1: `expected.txt` expected `not a PNG`, unemittable since v1.2.0 — running the example's own `run.sh` falsified it. Now re-verified by execution. |
| `tests/{cli,quant,render,ascii,decode}.tcyr` | 2 | 2026-06-27 (v1.4.0) | **431 assertions** across the 5 split suites (cli 63 / quant 109 / render 137 / ascii 17 / decode 105). Split from the retired monolithic `tests/kii.tcyr` at the v1.2.0 re-fold; ascii suite added v1.3.0; decode grew 51 → 105 (+54 JPEG) and render +8 (JPEG e2e) at v1.4.0. |
| `tests/fixtures/{gradient,color}.jpg` | 3 | 2026-06-27 (v1.4.0) | **NEW.** Baseline JPEG fixtures: 16×16 grayscale (chitra's ImageMagick-verified gradient, src ctype 257) + 8×8 YCbCr 4:4:4 (src ctype 259). |
| `tests/kii.bcyr` | 2 | 2026-05-23 (v1.0.0 close) | **Seven benches**: M4 scalar + M5/M6 end-to-end (3 sizes) + **M7(d) decode-latency matrix (3 source-resolution classes)**. |
| `tests/kii.fcyr` | 2 | 2026-08-25 (v1.5.1) | **Eight fuzz surfaces at 6,011,000 total iters**: arg-parser (10k) + path-sanitizer (1M) + geometry (1M) + emit-pipeline (1k) + PNG (1M) + JPEG (1M) + **BMP (1M)** + **GIF (1M)**, each decode surface prefixing its real format signature so the payload reaches that decoder. Every `alloc_reset()` is paired with `crc32_table = 0` — without it the reset invalidates sankoch's cached CRC table and silently voids the surface (v1.5.1 finding A-3). Peak RSS ~136 MB; deterministic-LCG. |
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
- **P-1 sweep (v1.5.1) closed most of this ledger's debt.** `SECURITY.md`,
  `CONTRIBUTING.md`, `README.md`, `CLAUDE.md`, `docs/guides/getting-started.md`,
  `docs/architecture/README.md`, `docs/benchmarks.md` and
  `docs/development/state.md` were each walked claim-by-claim against the tree and
  corrected; see [`docs/audit/2026-08-25-audit.md`](audit/2026-08-25-audit.md)
  § A-11. The stale-claim debt noted below from the v1.5.0 dep audit is **closed**.
  What remains open is the `docs/examples/` set and ADR 0002's C1–C4 commitment
  table, whose code anchors moved in the v1.2.0 re-fold.
- **Ledger reconciliation debt (v1.1 → v1.4)**: this ledger lapsed after the v1.0.0 close — several rows still carry v1.0-era dates/facts (`README.md` Status/Substrate blocks, `benchmarks.md`, `guides/getting-started.md`, `examples/`, `architecture/README.md`, the `0001–0007` ADR rows) that postdate the cmdit re-fold (v1.1), the chitra re-fold (v1.2), and the `--mode ascii` lanes (v1.3). The v1.4.0 cut refreshed only the rows it directly touched (the JPEG wiring). A full walk of every Tier-1/2 row against current reality is owed and tracked here.

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
