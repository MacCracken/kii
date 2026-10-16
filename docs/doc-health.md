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
| `README.md` | 1 | 2026-10-15 (v1.6.4) | Status → v1.6.4; arc gains the v1.6.4 bullet; § Building's pin is a pointer to `cyrius.cyml` (it read `6.5.35`) and its counts are 709 / ten surfaces / 8,011,000; `/dev/stdin`, the frame cap and the negative-`--width` refusal noted. |
| `CLAUDE.md` | 1 | 2026-10-15 (v1.6.4) | Process step 6 names `VERSION` (read by `cyrius.cyml`), the `print_version` literal and CI's drift check — it listed `cyrius.cyml`, which only interpolates the version. Toolchain pin stays a pointer to `cyrius.cyml` (since v1.5.1). |
| `CHANGELOG.md` | 1 | 2026-10-15 (v1.6.4) | `[1.6.4]` added (the P(-1) sweep: frame cap, single-open read, alpha over black, per-format diagnostics, the speedups, the CVE verification). Rolls per release; released entries are never edited. |
| `CONTRIBUTING.md` | 1 | 2026-10-15 (v1.6.4) | The retired M0–M7 milestone text replaced: contributions target the roadmap's next pinned release; tier 2 at 1.8.0 / 1.9.0; formats via a chitra re-pin; the dep list names cmdit and chitra; current state 709 / 8,011,000 / 7 benches. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-10-15 (v1.6.4) | No in-repo decoder (chitra since v1.2.0); `cat x \| kii /dev/stdin`; the single-open read and the frame-size cap as mitigations; new § Accepted risks (TAB/LF, bidi/format characters, a writerless FIFO); the audit history lists all three audits. |
| `cyrius.cyml` | 1 | 2026-10-15 (v1.6.3) | **Manifest only** (39 lines): package, build, stdlib list, three git + tag deps with a one-line purpose each. `cyrius = "6.7.12"`, chitra 1.2.0. Pin history and rationale live in CHANGELOG / state.md / ADRs, never here. |
| `docs/development/state.md` | 1 | 2026-10-15 (v1.6.4) | v1.6.4 entry; 709 assertions (cli 163 / quant 123 / render 198 / ascii 17 / decode 208); module map names the v1.6.4 helpers; binary sizes incl. the aarch64 alignment padding; bench ranges from § v1.6.4; the CI re-vendor and `<8-byte file` claims corrected; the open list matches the roadmap. |
| `docs/benchmarks.md` | 1 | 2026-10-15 (v1.6.4) | v1.6.4 section: 1.6.4 against 1.6.3 interleaved — quantize ~4×, a 256² icon ~2× at `--width 200`, RAMGON unchanged (its time is chitra's inflate). Earlier sections are historical captures. |
| `docs/development/roadmap.md` | 1 | 2026-10-15 (v1.6.4) | 1.6.4 section deleted (shipped). The sweep's deferred findings joined their pinned versions: 1.7.0 (dead decoder branches, shared emit loop, cmdit range/enum), 1.8.0 (tier 1 on real 8/16-colour SGR, SGR elision, real transparency), 1.9.0 (pixel-centre sampling), 1.10.0 (the glyph-table generator). The 16 MiB limit is stated per colour type. |
| `docs/audit/2026-05-22-audit.md` | 1 | 2026-05-23 (v1.0.0 close + Appendix A) | 140 CVE/issue rows + 10 kii-specific findings + § Appendix A W3C PngSuite walk (added at M8 close). Load-bearing reference for ADR 0002. |
| `docs/audit/chafa-comparison.md` | 1 | 2026-05-23 (v1.0.0 close) | **NEW at M8(b3).** kii vs `chafa --colors 16` across 6 curated fixtures. Byte-stream metrics + qualitative findings + acceptance-criterion close-out. Validates ADRs 0003 / 0004 / 0005 against chafa as reference impl. |
| `docs/adr/README.md` | 2 | 2026-08-24 (v1.5.0) | Index lists ADRs 0001–0009 (0009 BMP/GIF-via-chitra added). |
| `docs/adr/0008-jpeg-via-chitra.md` | 2 | 2026-10-15 (v1.6.4) | JPEG via chitra 0.3.0: signature dispatch + structural validation. **Amended at v1.6.4**: the "256 MB pre-read file cap" is now a capped read. Extended by ADR 0009. |
| `docs/adr/0009-bmp-gif-via-chitra.md` | 2 | 2026-10-15 (v1.6.4) | BMP + GIF via chitra 1.0.0; the nameable-format rule. **Amended at v1.6.4**: kii calls 11 chitra functions (not nine); the GIF LZW / no-image / tail-fill wording now follows the rule. |
| `docs/audit/2026-08-25-audit.md` | 2 | 2026-08-25 (v1.5.1) | The v1.5.1 P-1 sweep: 41 findings raised / 2 refuted / 39 folded into 16 work items. Dated record — not edited; its "forged text cannot contain control bytes" is qualified by the 2026-10-15 audit § 7 (bidi characters). |
| `docs/audit/2026-10-15-audit.md` | 2 | 2026-10-15 (v1.6.4) | **NEW.** The v1.6.4 P(-1) sweep: 56 findings; 1 MEDIUM + 9 LOW + 1 INFO repaired, 3 optimizations adopted, ~30 doc corrections, 9 deferred to pinned versions, 2 refuted; the three zlib CVE classes verified to hold. |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/adr/0001-png-decoder-in-repo.md` | 2 | 2026-10-15 (v1.6.4) | **Superseded by ADR 0006** (says so in its header). Historical. |
| `docs/adr/0002-security-model.md` | 2 | 2026-10-15 (v1.6.4) | Amended at v1.5.1, v1.6.0 and **v1.6.4**: the C1–C4 table's anchors now name current functions (chitra by function and constant, not line); new commitments for the 16 MiB ceiling, the 1M-cell frame cap and the single-open read; the three sankoch CVE items recorded as never filed and now verified to hold. |
| `docs/adr/0003-color-tier-discipline.md` | 2 | 2026-10-15 (v1.6.4) | Amended at v1.5.1 and **v1.6.4**: tier 2 → 1.8.0 / 1.9.0; the Consequences claim that no emit byte needs a feature under 30 years old is false (tier 1 emits `38;5;N`), resolved at 1.8.0. |
| `docs/adr/0004-half-block-floor-glyph.md` | 2 | 2026-10-15 (v1.6.4) | **Amended at v1.6.4**: roadmap citation → § 2.0 — open. |
| `docs/adr/0005-nearest-neighbor-downscale.md` | 2 | 2026-10-15 (v1.6.4) | **Amended at v1.6.4**: tier 2 → 1.9.0; records C-7 (the last source row and column are never sampled) and pixel-centre sampling pinned to 1.9.0. |
| `docs/adr/0006-adopt-chitra-decoder.md` | 2 | 2026-10-15 (v1.6.4) | The v1.2.0 PNG re-fold (supersedes 0001). **Amended at v1.6.4**: alpha is composited over black (its "alpha is dropped" decision is superseded); quoted messages updated; the read was lseek-sized, now `file_read_whole_max`. |
| `docs/adr/0007-rendering-mode-taxonomy.md` | 2 | 2026-10-15 (v1.6.4) | The `--mode` lanes. **Amended at v1.6.4**: `emit_ascii_shape`; the cols·2 × rows·3 downscale; the ascii lane quantizes each cell's mean, not via `quantize_downscaled`; shape-vector shipped at v1.3.1. |
| `docs/architecture/README.md` | 2 | 2026-10-15 (v1.6.4) | Module map redrawn for v1.6.4 (it still drew the pre-v1.2.0 decoder): file read → chitra → adapter → downscale → quantize / emit, plus the ascii lane; the module table lists the v1.6.4 helpers; item 001 cites `STRUCT_*` by name. |
| `docs/guides/getting-started.md` | 2 | 2026-10-15 (v1.6.4) | Four formats; pin pointer; `/dev/stdin`; the error tables list every decode, post-decode and warning line plus a new exit-2 usage table, each checked against the binary; the orphan fragment and the v1.0 roadmap link fixed. |
| `docs/examples/README.md` | 3 | 2026-10-15 (v1.6.4) | `cd kii` (was `cd cyrius-kii`). |
| `docs/examples/01-ramgon-fixed-width/` | 3 | 2026-10-15 (v1.6.4) | Runs and matches (54,353 B, 32 rows). Notes: bench figures current, the time is sankoch's inflate inside chitra. |
| `docs/examples/02-archlinux-logo-palette/` | 3 | 2026-10-15 (v1.6.4) | Runs and matches. The PLTE lookup is chitra's; the logo is a palette PNG with transparency, so 72 of its 3,200 cells changed at v1.6.4 (alpha over black) — `expected.txt` pins no frame bytes. |
| `docs/examples/03-not-a-png-rejection/` | 3 | 2026-10-15 (v1.6.4) | Runs and matches. Notes: kii reads the whole file and chitra's sniff refuses it; a <8-byte file prints `unrecognized image format`; ESC is C0. |
| `tests/{cli,quant,render,ascii,decode}.tcyr` | 2 | 2026-10-15 (v1.6.4) | **709 assertions** (cli 163 / quant 123 / render 198 / ascii 17 / decode 208). v1.6.4 added the width line, the frame cap, `-m`, every decode line per format, IS_DIR, pstruct zeroing, the 256 MB pin, chitra's code space, alpha compositing, and a quantizer reference grid. |
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

## Debt summary at v1.6.4

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
