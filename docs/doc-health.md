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
| `README.md` | 1 | 2026-10-15 (v1.7.0) | Status → v1.7.0; the arc gains the v1.7.0 bullet (the rename, the RGBA8-only downscale, the shared frame loop, cmdit range/enum). v1.6.4: § Building pin pointer and counts. |
| `CLAUDE.md` | 1 | 2026-10-15 (v1.6.4) | Process step 6 names `VERSION` (read by `cyrius.cyml`), the `print_version` literal and CI's drift check — it listed `cyrius.cyml`, which only interpolates the version. Toolchain pin stays a pointer to `cyrius.cyml` (since v1.5.1). |
| `CHANGELOG.md` | 1 | 2026-10-15 (v1.7.0) | `[1.7.0]` added (the name mapping, R-2 / R-7 / R-8, the two changed error lines, the `--help` line). Rolls per release; released entries are never edited. |
| `CONTRIBUTING.md` | 1 | 2026-10-15 (v1.6.4) | The retired M0–M7 milestone text replaced: contributions target the roadmap's next pinned release; tier 2 at 1.8.0 / 1.9.0; formats via a chitra re-pin; the dep list names cmdit and chitra; current state 709 / 8,011,000 / 7 benches. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-10-15 (v1.7.0) | Code names follow the v1.7.0 rename (`IMG_ERR_*`). v1.6.4: chitra (no in-repo decoder), `kii /dev/stdin`, the single-open read and frame cap, § Accepted risks, the audit history. |
| `cyrius.cyml` | 1 | 2026-10-15 (v1.6.3) | **Manifest only** (39 lines): package, build, stdlib list, three git + tag deps with a one-line purpose each. `cyrius = "6.7.12"`, chitra 1.2.0. Pin history and rationale live in CHANGELOG / state.md / ADRs, never here. |
| `docs/development/state.md` | 1 | 2026-10-15 (v1.7.0) | v1.7.0 entry; live sections use the new names (`src/image.cyr`, `IMG_ERR_*`, `kii_decode_image`); 710 assertions (cli 171 / quant 115 / render 199 / ascii 17 / decode 208) — the test-count line still said 642 after v1.6.4, now fixed; binary sizes; the open list starts at 1.8.0. |
| `docs/benchmarks.md` | 1 | 2026-10-15 (v1.6.4) | v1.6.4 section: 1.6.4 against 1.6.3 interleaved — quantize ~4×, a 256² icon ~2× at `--width 200`, RAMGON unchanged (its time is chitra's inflate). Earlier sections are historical captures. |
| `docs/development/roadmap.md` | 1 | 2026-10-15 (v1.7.0) | 1.7.0 section deleted (shipped). Pinned next: 1.8.0 (tier 2 colour + the emit rework), 1.9.0 (dithering + pixel-centre sampling), 1.10.0 (ASCII refinements + the glyph-table generator); then gated-on-upstream, not-scheduled, 2.0. |
| `docs/audit/2026-05-22-audit.md` | 1 | 2026-05-23 (v1.0.0 close + Appendix A) | 140 CVE/issue rows + 10 kii-specific findings + § Appendix A W3C PngSuite walk (added at M8 close). Load-bearing reference for ADR 0002. |
| `docs/audit/chafa-comparison.md` | 1 | 2026-05-23 (v1.0.0 close) | **NEW at M8(b3).** kii vs `chafa --colors 16` across 6 curated fixtures. Byte-stream metrics + qualitative findings + acceptance-criterion close-out. Validates ADRs 0003 / 0004 / 0005 against chafa as reference impl. |
| `docs/adr/README.md` | 2 | 2026-08-24 (v1.5.0) | Index lists ADRs 0001–0009 (0009 BMP/GIF-via-chitra added). |
| `docs/adr/0008-jpeg-via-chitra.md` | 2 | 2026-10-15 (v1.7.0) | JPEG via chitra 0.3.0. Amended at v1.6.4 (capped read) and **v1.7.0**: the rename it deferred is done. |
| `docs/adr/0009-bmp-gif-via-chitra.md` | 2 | 2026-10-15 (v1.7.0) | BMP + GIF via chitra 1.0.0; the nameable-format rule. Amended at v1.6.4 (11 chitra functions; GIF wording) and **v1.7.0** (names). |
| `docs/audit/2026-08-25-audit.md` | 2 | 2026-08-25 (v1.5.1) | The v1.5.1 P-1 sweep: 41 findings raised / 2 refuted / 39 folded into 16 work items. Dated record — not edited; its "forged text cannot contain control bytes" is qualified by the 2026-10-15 audit § 7 (bidi characters). |
| `docs/audit/2026-10-15-audit.md` | 2 | 2026-10-15 (v1.6.4) | **NEW.** The v1.6.4 P(-1) sweep: 56 findings; 1 MEDIUM + 9 LOW + 1 INFO repaired, 3 optimizations adopted, ~30 doc corrections, 9 deferred to pinned versions, 2 refuted; the three zlib CVE classes verified to hold. |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-10-15 (v1.6.4) | **Superseded by ADR 0006** (says so in its header). Historical. |
| `docs/adr/0002-security-model.md` | 2 | 2026-10-15 (v1.7.0) | Amended at v1.5.1, v1.6.0, v1.6.4 (current anchors, new commitments, the CVE items verified) and **v1.7.0** (the name mapping). |
| `docs/adr/0003-color-tier-discipline.md` | 2 | 2026-10-15 (v1.6.4) | Amended at v1.5.1 and **v1.6.4**: tier 2 → 1.8.0 / 1.9.0; the Consequences claim that no emit byte needs a feature under 30 years old is false (tier 1 emits `38;5;N`), resolved at 1.8.0. |
| `docs/adr/0004-half-block-floor-glyph.md` | 2 | 2026-10-15 (v1.6.4) | **Amended at v1.6.4**: roadmap citation → § 2.0 — open. |
| `docs/adr/0005-nearest-neighbor-downscale.md` | 2 | 2026-10-15 (v1.7.0) | Amended at v1.6.4 (C-7, pixel-centre sampling → 1.9.0) and **v1.7.0** (`_extract_rgb` removed; downscale reads RGBA8 only). |
| `docs/adr/0006-adopt-chitra-decoder.md` | 2 | 2026-10-15 (v1.7.0) | Amended at v1.6.4 (alpha over black, messages, the read) and **v1.7.0** (names; `_png_color_channels`, `_extract_rgb` and the dead pstruct slots gone). |
| `docs/adr/0007-rendering-mode-taxonomy.md` | 2 | 2026-10-15 (v1.6.4) | The `--mode` lanes. **Amended at v1.6.4**: `emit_ascii_shape`; the cols·2 × rows·3 downscale; the ascii lane quantizes each cell's mean, not via `quantize_downscaled`; shape-vector shipped at v1.3.1. |
| `docs/architecture/README.md` | 2 | 2026-10-15 (v1.7.0) | Module map and table renamed (`src/image.cyr`, `kii_decode_image`, `IMG_ERR_*`); the shared `_kii_emit_frame` drawn; cli's cmdit range/enum; downscale RGBA8-only; item 001 records the retired slots and their unused offsets. |
| `docs/guides/getting-started.md` | 2 | 2026-10-15 (v1.7.0) | `--help` block matches the v1.7.0 binary byte for byte (the `--mode <halfblock|ascii>` line); the usage table has the one `--width` range line. v1.6.4: complete error tables, four formats, `/dev/stdin`. |
| `docs/examples/README.md` | 3 | 2026-10-15 (v1.6.4) | `cd kii` (was `cd cyrius-kii`). |
| `docs/examples/01-ramgon-fixed-width/` | 3 | 2026-10-15 (v1.6.4) | Runs and matches (54,353 B, 32 rows). Notes: bench figures current, the time is sankoch's inflate inside chitra. |
| `docs/examples/02-archlinux-logo-palette/` | 3 | 2026-10-15 (v1.7.0) | Runs and matches. The PLTE lookup is chitra's, and the `_extract_rgb` palette branch the notes mentioned was removed at v1.7.0; 72 of 3,200 cells changed at v1.6.4 (alpha over black). |
| `docs/examples/03-not-a-png-rejection/` | 3 | 2026-10-15 (v1.7.0) | Runs and matches. Notes use `kii_decode_image` / `IMG_ERR_UNRECOGNIZED`. |
| `tests/{cli,quant,render,ascii,decode}.tcyr` | 2 | 2026-10-15 (v1.7.0) | **710 assertions** (cli 171 / quant 115 / render 199 / ascii 17 / decode 208). v1.7.0: cmdit's `--width` range and `--mode` enum, the RGBA8-only downscale guard; the dead colour-type helpers' tests removed with them. |
| `tests/fixtures/oversize.png` | 3 | 2026-10-12 (v1.6.0) | **NEW.** Valid 2370×2370 black RGB PNG (16,447 B; 16,853,070 B inflated), just past sankoch's 16 MiB ceiling; ImageMagick-verified. |
| `tests/fixtures/{gradient,color}.jpg` | 3 | 2026-06-27 (v1.4.0) | **NEW.** Baseline JPEG fixtures: 16×16 grayscale (chitra's ImageMagick-verified gradient, src ctype 257) + 8×8 YCbCr 4:4:4 (src ctype 259). |
| `tests/fixtures/{gradient.bmp,color.gif}` | 3 | 2026-08-24 (v1.5.0) | 16×16 24-bpp BI_RGB ramp and a 16×16 GIF89a with four flat quadrants; both pixel-verified against ImageMagick. |
| `tests/fixtures/visual-review/` | 3 | 2026-05-23 (v1.0.0 close) | The chafa-comparison fixture set (`docs/audit/chafa-comparison.md`); no test references it. |
| `tests/kii.bcyr` | 2 | 2026-10-15 (v1.6.4) | **Seven benches**: M4 scalar + end-to-end (3 sizes) + the M7(d) decode-latency matrix (3 classes; the 1024² fixture is absent on the dev host and prints an explicit skip, v1.5.1). Exit via `SYS_EXIT` since v1.6.4. |
| `tests/kii.fcyr` | 2 | 2026-10-15 (v1.6.4) | **Ten fuzz surfaces, 8,011,000 iterations.** v1.6.4: the geometry surface checks the geometry contract and the frame-cell predicate (an off-by-one fails 999,970 of 1M); the envelope reference follows the 0-row rule; exit via `SYS_EXIT`. |
| `.github/workflows/ci.yml` | 1 | 2026-08-24 (v1.5.0) | Installs the pinned toolchain from `cyrius.cyml`, `cyrius deps`, build, version-drift check, `cyrius test`, fuzz. **Still pending**: CHANGELOG-extracted release notes, an aarch64 cross-build step, a benchmark build. A comment still calls the repo `cyrius-kii` (cosmetic). |
| `.github/workflows/release.yml` | 1 | 2026-08-24 (v1.5.0) | Binary-name fix landed. CHANGELOG-extracted release notes + multi-arch builds pending. |
| `LICENSE` | 1 | 2026-05-22 | GPL-3.0-only header (parity with bannermanor/hapi/etc.). |
| `.gitignore` | 2 | 2026-05-22 | Standard scaffold. |

## Debt summary at v1.7.0

The v1.6.4 P(-1) sweep walked every Tier-1 and Tier-2 doc against the tree and the
binary ([`audit/2026-10-15-audit.md`](audit/2026-10-15-audit.md) § 3, P-14). It closed
the debt this ledger carried: ADR 0002's C1–C4 table has current anchors, all three
examples run and match, CONTRIBUTING no longer describes the retired v1.0 milestone
roadmap, the v1.1 → v1.4 row reconciliation is done (every row above re-dated), and the
three sankoch CVE-class items are verified to hold — nothing to file.

Still open:

- **CI**: no CHANGELOG-extracted release notes, no aarch64 cross-build step, no
  benchmark build (build-only would catch bitrot without per-PR timing noise). A
  `ci.yml` comment still calls the repo `cyrius-kii`.
- **Cross-terminal verification** and the **zugot marketplace recipe** — both outside
  kii's control (roadmap § Not scheduled).
- `docs/examples/03-…/expected.txt` says "~20 distinct error paths"; there are ~32 now.
  The example still runs and matches.

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
