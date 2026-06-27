# kii — Roadmap

> Sequencing — what ships, in what order, against what dependency gates.
> State lives in [`state.md`](state.md). **kii is post-v1** (current:
> v1.3.1); this file keeps the v1.0 record, the post-v1 shipped log, and
> the not-yet-committed roadmap ahead.

The roadmap is **smallest-first** per AGNOS bite-discipline: each release is a single coherent cycle that ships a working binary doing demonstrably more than the last.

## v1.0 criteria (shipped 2026-05-23)

The contract that tagged v1.0 — all decode/render/security/docs gates met; three items were explicitly deferred to v1.x (see Carry-forward debt below):

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

M7 (v0.8.0 security audit) + M8 (v1.0.0 freeze) shipped 2026-05-23; outcomes
in CHANGELOG, [`docs/audit/2026-05-22-audit.md`](../audit/2026-05-22-audit.md),
and ADRs 0002–0005. The per-milestone acceptance detail lived here pre-execution;
it's retired now that the work shipped (the table above + CHANGELOG are the record).

## Post-v1 shipped (v1.1.x – v1.3.x)

Since the v1.0.0 freeze, per [`../../CHANGELOG.md`](../../CHANGELOG.md):

| Release | Headline |
|---|---|
| v1.1.0–1.1.2 | **CLI re-fold onto the `cmdit` distlib** (dropped the hand-rolled flag parser); toolchain → cyrius 6.2.44; darshana → 0.8.1 |
| v1.2.0 | **PNG re-fold** — adopted the `chitra` distlib + deleted the 813-line native decoder ([ADR 0006](../adr/0006-adopt-chitra-decoder.md), supersedes 0001); output byte-identical |
| v1.2.1 | Fixed a pre-existing `emit_halfblock` `--width` stack overflow (heap-sized per-row buffer) |
| v1.2.2 | Re-pinned `chitra 0.2.1` → kii renders the **full PNG matrix** (bit depths 1/2/4/8/16 + Adam7 interlace) |
| v1.3.0 | **`--mode ascii`** — character-glyph rendering lane (luminance ramp), [ADR 0007](../adr/0007-rendering-mode-taxonomy.md) |
| v1.3.1 | ASCII **shape-vector** glyph matching (orientation-aware; Alex Harri attribution) |

**Carry-forward debt** (none blocking; inherited from the v1.0 freeze):

- First BBS / MUD downstream consumer integrated — a downstream-cycle deliverable, off kii's own roadmap.
- Cross-terminal verification (Linux console / xterm / Alacritty / kitty / tmux) — needs a human-eye per-terminal pass; kii ships byte-stable so it can land any time.
- Marketplace recipe in zugot — depends on zugot tooling.
- Three sankoch upstream CVE-class items (CVE-2004-0797 / 2005-1849 / 2005-2096) — file as sankoch issues.

## Out of scope (durable scope guards)

Durable boundaries on what kii is (not a v1.0-only gate):

- **JPEG / GIF / BMP decoders in-repo** — kii does not carry format decoders; it consumes them from the `chitra` substrate on a `[deps.chitra]` re-pin (PNG already does; JPEG arrives at chitra 0.3). See [ADR 0006](../adr/0006-adopt-chitra-decoder.md).
- **Animated GIF / video-frame-pipe** — explicit post-v2 scope.
- **Output to stdout-other-than-TTY-styled file formats** — e.g. no HTML output, no SVG output. kii is image → ANSI, full stop.
- **Image transformations** — no crop, no rotate, no scale-other-than-fit-terminal. Use upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live-resize-on-terminal-resize, no animation, no scroll. One frame in, one frame out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan. Loop in the shell.

## Roadmap ahead (not yet committed)

Ordered roughly by readiness. Decoder substrate (PNG) and both render lanes
(half-block + ASCII) are done; what remains is color fidelity, the next
format, and richer glyph vocabularies.

- **Tier 2 — 256-color + truecolor** (next; likely v1.4.0) — `--color 256` and `--color tc` (24-bit SGR) emit, then ordered / Floyd-Steinberg dithering as `--dither` choices. Orthogonal to `--mode` (composes with both half-block and ASCII). Self-contained in the emit/quant layer; amends ADR 0003's tier-1-only stance.
- **JPEG (and beyond) via `chitra 0.3+`** — JFIF baseline (Huffman + IDCT + chroma upsample) lands in chitra; kii picks it up on a `[deps.chitra]` re-pin, exactly as it gained the full PNG matrix at v1.2.2. No in-repo decoder (ADR 0006).
- **ASCII shape-vector refinements** (small follow-up to v1.3.1) — the two pieces deferred from Alex Harri's blog: **directional contrast enhancement** (normalize-by-max → power → denormalize on the cell vector before matching, sharpening edges) and a **k-d-tree** lookup to replace the 27-glyph linear scan. See [ADR 0007](../adr/0007-rendering-mode-taxonomy.md).
- **Full Block Elements glyph vocab** (v2.0.0) — expand the half-block emit from `▀` alone to the Unicode Block Elements range (U+2580..U+259F): quarter-blocks (`▘▝▖▗`) for 4-corner color, eighth-blocks (`▁▂▃▄▅▆▇` / `▏▎▍▌▋▊▉`) for sub-cell gradients, shade blocks (`░▒▓`). Closes the byte-verbosity + detail gap with chafa ([`../audit/chafa-comparison.md`](../audit/chafa-comparison.md)). Needs a ~32-arm glyph-dispatch + 4-corner quantize; trades byte-stability (ADR 0003) for fidelity — new ADR superseding ADR 0004 when scoped.
- **Tier 3 — Sixel / Kitty / iTerm2 protocols** (v2.0.0) — direct-image-protocol output where supported; the ASCII/half-block lanes stay the fallback default. Possibly a major cut depending on CLI-surface impact.

Captured deferrals become ADRs when the decision crystallizes.
