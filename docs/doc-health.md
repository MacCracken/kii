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
| `README.md` | 1 | 2026-10-15 (v1.6.1) | Status block → v1.6.1; the post-v1 arc gains the v1.6.1 entry; § Substrate names the cmdit 1.4.0 and chitra 1.1.3 pins. |
| `CLAUDE.md` | 1 | 2026-08-25 (v1.5.1) | Identity line lists all four formats. **Toolchain pin de-inlined** — it read `6.0.1` for eleven releases past the real pin, so the number is now a pointer to `cyrius.cyml`, matching the file's own VERSION rule. |
| `CHANGELOG.md` | 1 | 2026-10-15 (v1.6.1) | `[1.6.1]` added (cmdit 1.4.0, chitra 1.1.3, the `--bool=value` refusal, chitra 1.1.1's re-coded refusals as kii prints them, the manifest cleanup, the sankoch-floor note); rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-10-12 (v1.6.0) | Fuzz bullet: ten surfaces, any `bad` fails the run, `crc32_table` note qualified (sankoch's arena canary covers it upstream). Current-state line → 599 / 8,011,000 / 7 benches. Line 19 still describes the v1.0 M0–M7 milestone roadmap, which no longer exists (pre-existing debt). |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-10-12 (v1.6.0) | Sanitizer bullet: darshana `tty_has_ctl`, strict RFC 3629 and why the overlong forms matter. Amplification bullet: the 16 MiB inflate ceiling and its own diagnostic. Fuzz bullet: ten surfaces / 8,011,000 iterations, failing exit. |
| `cyrius.cyml` | 1 | 2026-10-15 (v1.6.1) | **Manifest only** (126 → 39 lines): package, build, stdlib list, three git + tag deps with a one-line purpose each. Pin history and rationale live in CHANGELOG / state.md / ADRs, never here. `repository` corrected to `MacCracken/kii`. Version interpolates `${file:VERSION}`. |
| `docs/development/state.md` | 1 | 2026-10-15 (v1.6.1) | v1.6.1 entry; binary size refreshed (923,976 B host); External deps → darshana 1.3.0 / cmdit 1.4.0 / chitra 1.1.3 with the sankoch-floor note. Test and fuzz figures unchanged (599 / 8,011,000). |
| `docs/benchmarks.md` | 1 | 2026-10-12 (v1.6.0) | v1.6.0 section: the 6.7.9 binary against the v1.5.2 binary, interleaved in one session on a loaded host (end-to-end ~5–15 % slower, attributed to the toolchain; re-measure idle). Earlier sections are historical captures. |
| `docs/development/roadmap.md` | 1 | 2026-10-15 (v1.6.1) | Header → v1.6.1. No item shipped or opened at 1.6.1. |
| `docs/audit/2026-05-22-audit.md` | 1 | 2026-05-23 (v1.0.0 close + Appendix A) | 140 CVE/issue rows + 10 kii-specific findings + § Appendix A W3C PngSuite walk (added at M8 close). Load-bearing reference for ADR 0002. |
| `docs/audit/chafa-comparison.md` | 1 | 2026-05-23 (v1.0.0 close) | **NEW at M8(b3).** kii vs `chafa --colors 16` across 6 curated fixtures. Byte-stream metrics + qualitative findings + acceptance-criterion close-out. Validates ADRs 0003 / 0004 / 0005 against chafa as reference impl. |
| `docs/adr/README.md` | 2 | 2026-08-24 (v1.5.0) | Index lists ADRs 0001–0009 (0009 BMP/GIF-via-chitra added). |
| `docs/adr/0008-jpeg-via-chitra.md` | 2 | 2026-08-24 (v1.5.0) | JPEG via chitra 0.3.0: signature-based format dispatch + JPEG validation posture (no CRC → structural). Realizes ADR 0006's JPEG line. Still accurate at v1.5.0; extended by ADR 0009. |
| `docs/adr/0009-bmp-gif-via-chitra.md` | 2 | 2026-08-24 (v1.5.0) | **NEW.** BMP + GIF via chitra 1.0.0 — the re-pin that needed no decode change; sets the rule that a format kii renders is a format kii must be able to name in an error. Extends ADR 0008, discharges ADR 0006. |
| `docs/audit/2026-08-25-audit.md` | 2 | 2026-08-25 (v1.5.1) | **NEW.** The P-1 sweep: 41 findings raised / 2 refuted / 39 folded into 16 work items, plus a "What the sweep did NOT find" section, the refuted findings, and four accepted risks (TAB/LF allow-list, sankoch's 16 MiB inflate cap, the sankoch Huffman hot spot, the deferred `png.*` → `image.*` rename). |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-05-22 (v0.7.0 — first ADR) | First ADR; captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. |
| `docs/adr/0002-security-model.md` | 2 | 2026-10-12 (v1.6.0) | Threat model + M7(c) hardening commitments (C1–C4) + accepted residual risks. Amended at v1.5.1 (C1 reversal) and **at v1.6.0** (the sanitizer moves to darshana's `tty_has_ctl`; strict RFC 3629), both appended rather than edited in place. The C1–C4 table's code anchors still predate the v1.2.0 re-fold (carried debt). |
| `docs/adr/0003-color-tier-discipline.md` | 2 | 2026-08-25 (v1.5.1) | Captures tier-1 (8/16-color) scope; tier-2/tier-3 deferral. **Amended at v1.5.1**: the "`--color 8` reservation without activation" is resolved — the flag had parsed and ignored its argument since M1 and now selects a real tier. |
| `docs/adr/0004-half-block-floor-glyph.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c2).** Captures `▀`/`▄` glyph-pair-as-floor choice; quarter-blocks + braille post-v1. |
| `docs/adr/0005-nearest-neighbor-downscale.md` | 2 | 2026-05-23 (v1.0.0 close) | **NEW at M8(c3).** Captures nearest-neighbor downscale choice; bilinear/Lanczos defer to tier-2 alongside dithering. |
| `docs/architecture/README.md` | 2 | 2026-10-12 (v1.6.0, partial) | Item 004 rewritten (darshana now supplies every escape; the chained-`pos` contract, the per-row budget, `tty_has_ctl`'s arguments, why not `tty_winsize_or`); `cli.cyr` and `emit.cyr` module rows refreshed. **Still stale**: the `png.cyr` row describes the in-repo decoder deleted at v1.2.0, the `quant.cyr` row names the removed `quantize_nearest_image`, and `ascii.cyr` has no row. |
| `docs/guides/getting-started.md` | 2 | 2026-10-15 (v1.6.1) | Clone URL corrected (`cyrius-kii` → `kii`; the former does not exist). v1.6.0: pin line → 6.7.9, the `image too large to decode` row, the suppressed-path note. |
| `docs/examples/README.md` | 3 | 2026-05-23 (v1.0.0 close) | **Backfilled at M8(c5).** Index + convention for the examples dir. |
| `docs/examples/01-ramgon-fixed-width/` | 3 | 2026-08-25 (v1.5.1) | RAMGON.png happy path (RGBA color_type=6). Corrected: `expected.txt` claimed the frame ends with an "implicit" reset and "no trailing escape" — it ends with an explicit `ESC [ 0 m`, which is what protects the prompt. |
| `docs/examples/02-archlinux-logo-palette/` | 3 | 2026-08-25 (v1.5.1) | Palette PNG (color_type=3). Corrected: the notes described `_extract_rgb` doing the PLTE lookup, which moved into chitra at the v1.2.0 re-fold. |
| `docs/examples/03-not-a-png-rejection/` | 3 | 2026-08-25 (v1.5.1) | Error-path diagnostic + exit-code contract. Corrected at v1.5.1: `expected.txt` expected `not a PNG`, unemittable since v1.2.0 — running the example's own `run.sh` falsified it. Now re-verified by execution. |
| `tests/{cli,quant,render,ascii,decode}.tcyr` | 2 | 2026-10-12 (v1.6.0) | **599 assertions** across the 5 split suites (cli 98 / quant 125 / render 188 / ascii 17 / decode 171); v1.6.0 added 49 (strict RFC 3629, the 256-index BG composer sweep, `_kii_term_envelope`, `PNG_ERR_INFLATE_LIMIT`). |
| `tests/fixtures/oversize.png` | 3 | 2026-10-12 (v1.6.0) | **NEW.** Valid 2370×2370 black RGB PNG (16,447 B; 16,853,070 B inflated), just past sankoch's 16 MiB ceiling; ImageMagick-verified. |
| `tests/fixtures/{gradient,color}.jpg` | 3 | 2026-06-27 (v1.4.0) | **NEW.** Baseline JPEG fixtures: 16×16 grayscale (chitra's ImageMagick-verified gradient, src ctype 257) + 8×8 YCbCr 4:4:4 (src ctype 259). |
| `tests/kii.bcyr` | 2 | 2026-05-23 (v1.0.0 close) | **Seven benches**: M4 scalar + M5/M6 end-to-end (3 sizes) + **M7(d) decode-latency matrix (3 source-resolution classes)**. |
| `tests/kii.fcyr` | 2 | 2026-10-12 (v1.6.0) | **Ten fuzz surfaces at 8,011,000 total iters**: the eight from v1.5.1 plus the path-sanitizer differential against the v1.5.2 walk (1M) and the terminal envelope (1M), run last so the first eight keep their random streams. Any non-zero `bad` now exits 1. |
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
