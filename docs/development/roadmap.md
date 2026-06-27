# kii — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

The roadmap is **smallest-first** per AGNOS bite-discipline. Each milestone is sized to be a single coherent cycle of work (~3-7 days of focused effort), and each one ships a working binary that demonstrably does more than the previous one.

## v1.0 criteria

The contract for tagging v1.0:

- [x] CLI surface frozen — `--help`, `--version`, `--width N`, positional path arg, `--color N` (8 or 16), `--verbose` all stable (shipped at v0.2.0 / M1; `--verbose` activated at v0.6.0 / M5)
- [x] Half-block glyph emission at terminal-detected geometry works (half-block emit at v0.6.0 / M5; terminal-detection at v0.7.0 / M6)
- [x] Test coverage: 100+ assertions across all modules (426 as of v0.7.0)
- [x] **Security audit pass** — external CVE / 0-day research compiled into [`docs/audit/2026-05-22-audit.md`](../audit/2026-05-22-audit.md); PNG fuzz harness clean at 10⁶ iterations; ANSI-escape-injection paths reviewed (Finding 6 — closed via `_eprint_path_safe`); decode-latency matrix at 256² / 1024² / 2048² for DoS-bound validation captured at v0.8.0 / M7
- [x] PNG decoder handles the W3C test suite's "basic" image set without crashing on any malformed input from the "broken" set — closed at M8(b4); 14/14 broken rejected, 82/162 valid OK, 0 crashes (see [audit § Appendix A](../audit/2026-05-22-audit.md))
- [x] 16-color quantization output passes visual review against `chafa --colors 16` — closed at M8(b3-redo) with a 6-fixture curated set; results captured in [`docs/audit/chafa-comparison.md`](../audit/chafa-comparison.md)
- [ ] At least one downstream consumer (BBS or MUD app) integrated and green — **explicitly OFF the v1.0 acceptance set**; BBS/MUD apps are downstream cycles (ideated, not built)
- [ ] Cross-terminal verification — Linux console, xterm, Alacritty, kitty, tmux — **deferred to v1.x** (needs human-eye per-terminal pass; kii ships byte-stable so verification can land any time)
- [x] CHANGELOG complete from v0.1.0 onward — rolling per release (v0.1.0 through v1.0.0 entered)
- [x] All ADRs written for design decisions made during M0–M6 — 0001 PNG-in-repo (M6), 0002 security-model (M7), 0003 color-tier-discipline (M8), 0004 half-block-floor-glyph (M8), 0005 nearest-neighbor-downscale (M8)
- [x] Docs / guides / examples all current per `docs/doc-health.md` — getting-started backfilled at M8(c4); examples/ populated at M8(c5)
- [ ] Marketplace recipe in zugot — **deferred to v1.x** (depends on zugot tooling)

## Shipped milestones (M0 → M8, v0.1.0 → v1.0.0)

M0–M6 shipped 2026-05-22; M7 + M8 shipped 2026-05-23. Per-milestone delivered lists, sub-bite cadences, deferrals, and deps added live in [`../../CHANGELOG.md`](../../CHANGELOG.md) — this table is the index.

| Milestone | Version | Headline | Deps added |
|---|---|---|---|
| M0 — Scaffold | [v0.1.0](../../CHANGELOG.md#010--2026-05-22) | `cyrius init` + doc tree + smoke test (2 assertions) | stdlib baseline (string/fmt/alloc/io/vec/str/syscalls/assert/bench/args) |
| M1 — CLI flag surface | [v0.2.0](../../CHANGELOG.md#020--2026-05-22) | `--help` / `--version` / positional path / `--width N` / `--color N` parsed + frozen; arg-parser fuzz | stdlib `flags` |
| M2 — PNG structural decoder | [v0.3.0](../../CHANGELOG.md#030--2026-05-22) | Signature + IHDR + CRC32 + chunk walker + IEND; PNG-decoder fuzz | — |
| M3 — sankoch DEFLATE → pixels | [v0.4.0](../../CHANGELOG.md#040--2026-05-22) | sankoch zlib_decompress + spec § 9 filter undo (None/Sub/Up/Avg/Paeth) | stdlib `sankoch`, `thread` |
| M4 — 16-color quantization | [v0.5.0](../../CHANGELOG.md#050--2026-05-22) | Linux-console palette + Euclidean-RGB nearest-neighbor + PLTE capture; first bench | — |
| M5 — Half-block ANSI emit | [v0.6.0](../../CHANGELOG.md#060--2026-05-22) | ▀ glyph + per-row 256-color escapes; downscale.cyr + emit.cyr; `--verbose` activated | external `darshana 0.5.3` (first git dep) |
| M6 — Terminal-size detect | [v0.7.0](../../CHANGELOG.md#070--2026-05-22) | `tty_winsize` auto-detect + `--width N` honored; aspect-preserving fit; multi-resolution bench; ADR 0001 + architecture/README backfill | — |
| M7 — Security audit cycle | [v0.8.0](../../CHANGELOG.md#080--2026-05-23) | External CVE/0-day audit (140 rows); hardening commits C1–C4 (path-sanitize + IHDR caps + IDAT/ratio caps + chunk-order FSM); fuzz 2k → 3M+; decode-latency matrix; ADR 0002 | — |
| M8 — v1.0 freeze | [v1.0.0](../../CHANGELOG.md#100--2026-05-23) | Per-chunk length cap (audit Finding 6); ADRs 0003/0004/0005; getting-started backfill; examples/; tests/fixtures/; W3C PngSuite walk (14/14 broken rejected, 82/162 valid OK, 0 crashes) | — |

**At v1.0.0**: 471 assertions all pass (+1 from v0.8.0); 3M+ fuzz iters across 5 surfaces clean; seven benches (incl. M7(d) decode-latency matrix); 5 ADRs landed; W3C PngSuite walked cleanly. Threat model + commitments captured in ADR 0002.

## In-flight + remaining milestones

### M7 — Security audit cycle (v0.8.0) — SHIPPED 2026-05-23

Closed out 2026-05-23. Outcomes captured in CHANGELOG [v0.8.0],
[`docs/audit/2026-05-22-audit.md`](../audit/2026-05-22-audit.md), and
[`docs/adr/0002-security-model.md`](../adr/0002-security-model.md).
Deferred to M8: W3C broken-set walk, per-chunk-type length cap table.

### (former) M7 acceptance — for historical reference

**Goal**: External-source-informed security audit of kii's threat surface. No new user-facing features; output is a comprehensive audit document + hardening commits + scaled fuzz coverage. This is the work the original "M7 = v1.0 freeze" lumped together with socialization — separated here because the security audit is its own dedicated cycle with **external web research for 0-days and CVEs against the substrate libraries kii draws on**.

**Threat surfaces** (per [`../../SECURITY.md`](../../SECURITY.md)):

1. **PNG decoder surface** — malformed / malicious PNG input. `src/png.cyr` parses untrusted bytes; integer overflows on dimension multiplication, IHDR / PLTE / IDAT ordering tricks, CRC bypass attempts, and chunk-truncation edge cases are all in scope.
2. **DEFLATE / zlib surface** — decompression amplification ("zip bombs"). sankoch is the Cyrius-native DEFLATE impl, but the algorithm has the same attack surface as zlib regardless of language; bugs in the underlying spec mechanics transfer.
3. **ANSI escape injection** — path argument + filename flow through `_eprint*` family to stderr; a maliciously-named file is the kii-controlled stdout/stderr injection vector. Terminal-emulator escape sequence parsing bugs are out of scope but worth surveying for context.

**Acceptance criteria**:

- [ ] **External CVE/0-day research compiled into `docs/audit/2026-MM-DD-audit.md`**:
  - libpng CVEs from 2010+ — every advisory walked, kii-applicability assessed per class
  - lodepng + stb_image bug histories — same treatment
  - zlib CVEs (CVE-2018-25032 / CVE-2022-37434 / CVE-2023-45853 + any later) — kii uses sankoch (stdlib), but cross-impl bug-class transfer
  - Terminal emulator escape sequence CVEs (CVE-2022-31202 / CVE-2003-0859 / etc.) — context only; out of kii's bug-fix scope
  - W3C PNG test suite "broken" set — each broken-case PoC fed through `kii` to confirm clean rejection or document the gap
- [ ] PNG fuzz harness scales from 2k → **10⁶ iterations clean** in `tests/kii.fcyr`
- [ ] **New fuzz surfaces** added: random valid-PNG fixture → random downscale dims → emit_halfblock_row_buf; random target-geometry inputs into `_kii_compute_target_geometry` + `_kii_compute_fit_geometry`. Covers the M5+M6 modules previously fuzz-untested.
- [ ] Integer-overflow review on every size-derivation multiplication (`width × height × bpp`, `dst_w × dst_src_rows × 3`, `idat_total_size`); add explicit caps where the kernel allows attacker-controlled inputs to overflow i64
- [ ] **Decompression-amplification cap**: cap `idat_total_size` and the inflate output buffer to a configurable max (e.g. 256 MB) so a malformed IDAT claiming pathological dimensions can't OOM-DoS the host
- [ ] ANSI escape injection review: enumerate every byte path from user input (path argument) to stderr; document constraints + add defenses (path-sanitization or refusal to emit non-printable bytes in `_eprint_path_msg`)
- [ ] **Decode-latency matrix** at 256² / 1024² / 2048² source resolutions captured in `docs/benchmarks.md` — establishes the DoS-relevant worst-case timing envelope
- [ ] `docs/adr/0002-security-model.md` (or similar) — captures kii's threat model + audit findings + accepted residual risks
- [ ] CHANGELOG + VERSION → 0.8.0

**Sub-bite cadence**:

- **(a)** External research compilation — WebSearch + WebFetch across the CVE databases (NVD / CVE.org / Mitre / GitHub Security Advisories), libpng release notes, zlib changelogs, and any AGNOS first-party security-review playbook. Audit doc shape: per-CVE row with date / severity / class / kii-applicable? / remediation. Ship the doc before any code lands so the rest of the cycle is informed by the research.
- **(b)** Fuzz scaling (2k → 10⁶) + new fuzz surfaces (downscale + quant + emit + geometry). Iteration count change is small; the new surfaces are the real work.
- **(c)** Hardening commits for any vulnerabilities found in (a) + integer-overflow / bounds review + decompression-amplification cap.
- **(d)** Decode-latency bench matrix at three source resolutions + ADR 0002 + close-out (CHANGELOG, state.md, doc-health, version bump).

**Deps gates**: none expected. May add stdlib `bounds` if not already in (for size-cap helpers); confirmed during sub-bite (a).

### M8 — v1.0 freeze cycle (v1.0.0) — SHIPPED 2026-05-23

Closed out 2026-05-23. Per-bite outcomes:

- **(b1)** RAMGON.png moved to `tests/fixtures/`; test/bench/fuzz references updated.
- **(b2)** Per-chunk-type length cap (audit Finding 6, carry-forward) — IEND-length-zero + generic 256 MB per-chunk cap.
- **(b3)** chafa visual review — initially deferred; re-run after chafa installed. Closed at v1.0 with 6-fixture comparison + byte-stream metrics + qualitative findings in `docs/audit/chafa-comparison.md`. Validates ADRs 0003 / 0004 / 0005 against chafa as reference impl.
- **(b4)** W3C PngSuite walk — 14/14 broken rejected, 82/162 valid OK, 0 crashes (audit doc § Appendix A).
- **(c1)** ADR 0003 — color-tier discipline (8/16-color v1.0).
- **(c2)** ADR 0004 — half-block (▀/▄) as the floor glyph.
- **(c3)** ADR 0005 — nearest-neighbor downscale (no Lanczos at v1).
- **(c4)** `docs/guides/getting-started.md` backfilled.
- **(c5)** `docs/examples/` populated with 3 runnable transcripts (happy path / palette code path / error path).
- **(d)** Close-out: VERSION 0.8.0 → 1.0.0, CHANGELOG v1.0.0 entry, state.md refreshed, doc-health walked, roadmap collapsed.

**Deferred to v1.x** (none block v1.0 tag):

- First BBS / MUD downstream consumer integrated — **explicitly OFF the v1.0 acceptance set** (downstream apps ideated, not built; integration is a downstream-cycle deliverable).
- Cross-terminal verification (Linux console / xterm / Alacritty / kitty / tmux).
<!-- chafa visual review: CLOSED at v1.0 (chafa installed; comparison shipped) -->
- Marketplace recipe in zugot.

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident:

- **Tier 2 / 3 color modes** — 256-color, truecolor, dithering, Sixel, Kitty image protocol. All deferred to post-v1 per CLAUDE.md color-tier discipline.
- **JPEG / GIF / BMP decoders** — PNG only at v1.0. Other formats land as v1.x bites once a consumer needs them.
- **Animated GIF / video-frame-pipe** — explicit post-v2 scope.
- **Output to stdout-other-than-TTY-styled file formats** — e.g. no HTML output, no SVG output. kii is image → ANSI, full stop.
- **Image transformations** — no crop, no rotate, no scale-other-than-fit-terminal. Use upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live-resize-on-terminal-resize, no animation, no scroll. One frame in, one frame out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan. Loop in the shell.

## Post-v1 considerations (informational, not commitments)

- **Tier 2 — 256-color + truecolor** (v1.1.0) — `--color 256` and `--color tc` modes; ordered/Floyd-Steinberg dither.
- **New formats — via chitra re-pin, not an in-repo decoder** (superseded the old "in-repo JFIF at v1.2.0" plan). Post-re-fold kii consumes formats from the substrate on a `[deps.chitra]` re-pin: **chitra 0.2.1** (sub-byte depths 1/2/4 + Adam7 interlace) is **DONE — consumed by kii v1.2.2**, completing the PNG matrix (kii now renders 1/2/4-bit + interlaced PNGs it used to reject). **chitra 0.3+** adds JPEG (Huffman + IDCT + chroma upsample) — kii will pick it up the same way. Prefer chitra over any in-repo decoder (retires the in-repo JPEG/GIF/BMP line). See [ADR 0006](../adr/0006-adopt-chitra-decoder.md).
- **~~Adopt `chitra`~~ — DONE at v1.2.0 (the PNG re-fold).** `chitra` 0.1.0 (2026-06-19) forked kii's `src/png.cyr` core for **mabda** (`gpu_texture_load_png`); **chitra 0.2.0** (2026-06-26) made the fork a strict superset of kii's decoder (16-bit depth + every M7(c)/M8 guard); **kii v1.2.0** then switched to `[deps.chitra]` and trimmed `src/png.cyr` to a thin adapter, closing the extract-on-2nd-consumer loop with byte-identical output. See [ADR 0006](../adr/0006-adopt-chitra-decoder.md) (supersedes [ADR 0001](../adr/0001-png-decoder-in-repo.md)). *(Mirrored on the ecosystem roadmap in `agnosticos/docs/development/roadmap.md` § Parallel cycle work.)*
- **Full Block Elements glyph vocab** (v2.0.0) — supersedes ADR 0004's half-block-only floor. Expands the emit-glyph set from `▀` alone to the full Unicode Block Elements range (U+2580..U+259F): quarter-blocks (`▘▝▖▗`) for 4-corner-per-cell color encoding, eighth-blocks (`▁▂▃▄▅▆▇`) for sub-cell vertical gradients, the horizontal eighth-blocks (`▏▎▍▌▋▊▉`), and the shade blocks (`░▒▓`). Closes the bytewise + visual-detail gap with chafa documented in [`../audit/chafa-comparison.md`](../audit/chafa-comparison.md) (kii's 5.9×–69× byte verbosity vs chafa is driven by half-block-only + per-cell SGR pair; richer vocab lets each cell encode more visual information per byte). Requires a per-cell glyph-dispatch table (~32 arms vs current 1-arm `▀`-only) and a 4-corner color clustering at quantize-time. Trades byte-stability (ADR 0003) for visual fidelity — needs a new ADR superseding 0004 + amending 0003 when scoped.
- **Character-glyph ASCII mode (`--mode ascii` / charset rendering)** (post-v1, version TBD — review item, not yet a commitment) — a SECOND rendering lane alongside the half-block color floor: render the image as a grid of **text characters only** (the `jp2a` / classic-ASCII-art lane named in CLAUDE.md's identity), no color blocks required. Two tiers to review:
    - **Floor — luminance ramp**: per-cell average luminance → index into a density-ordered glyph ramp (e.g. `" .:-=+*#%@"`). Luminance via the standard relative-luminance formula (`0.2126·R + 0.7152·G + 0.0722·B` on linearized sRGB) — a **multi-source standard** (W3C *Relative Luminance* / Wikipedia), pinned convergently per CLAUDE.md's no-single-source discipline, NOT from any one blog.
    - **Advanced — shape-vector glyph matching**: instead of one brightness per cell, sample N coverage "circles" per cell (2D → 6D *shape vectors*), precompute each candidate glyph's coverage vector, and pick the glyph by nearest-neighbor (Euclidean) in shape-vector space — this captures glyph *orientation*, so `/ \ | -` edges emerge implicitly with no explicit Sobel / difference-of-Gaussians. Plus a global + directional contrast-enhancement pass (`normalize-by-max → pow(exponent) → denormalize`) and a k-d-tree / quantized-vector cache for the lookup hot path.
    - **Insight source + attribution**: review **Alex Harri, "ASCII Art Rendering" — <https://alexharri.com/blog/ascii-rendering>** for the technique above. The **shape-vector glyph-matching and directional contrast-enhancement methods are original to that post — attribute it explicitly** (source comment + ADR) if kii adopts that logic/those formulas. The Euclidean-distance nearest-neighbour and k-d tree are standard CS (no attribution needed); relative-luminance is the W3C/Wikipedia standard (multi-source, convergent pin).
    - **Fit with existing tiers**: orthogonal to the color tiers — a charset mode can compose with 16/256/truecolor (colored glyphs) or run monochrome, and reuses the existing downscale stage (extended with supersampling/cell-averaging for anti-aliasing). Slots under a `--mode` / `--charset` surface; earns its own ADR (rendering-mode taxonomy, sibling to ADR 0004's half-block floor) when scoped.
- **Tier 3 — Sixel / Kitty protocols** (v2.0.0) — direct-image-protocol output for terminals that support it; the ASCII-art fallback stays the default. Possibly a major-version cut depending on CLI surface impact.

Captured deferrals will live as ADRs when the decision crystallizes.
