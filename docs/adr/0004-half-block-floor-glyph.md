# 0004 — Half-block (▀/▄) as the floor glyph

**Status**: Accepted
**Date**: 2026-05-23

## Context

A character-cell terminal displays one glyph per (column, row) cell.
For image-to-terminal rendering, the question is: **how many image
pixels does one cell represent, and which glyph carries the color
information?**

The Unicode block-element corpus offers several densities:

| Glyph | Codepoint | Pixels per cell | Background fill |
|---|---|---|---|
| `█` (full block) | U+2588 | 1 (cell = 1 pixel of any color) | fg = pixel color, bg = unused |
| `▀` (upper half) + `▄` (lower half) | U+2580 / U+2584 | 2 (top + bottom half each independent) | fg = top half, bg = bottom half |
| `▘` `▝` `▖` `▗` (quarter blocks) + 11 others | U+2598..U+259F | 4 (corner per cell) | fg = 1+ corners, bg = the rest |
| Braille (`⠀..⣿`) | U+2800..U+28FF | 8 (2×4 dot matrix) | fg only (monochrome per cell) |

Each choice trades vertical resolution against color-channel count.

## Decision

**kii uses the half-block glyph pair (`▀` U+2580 + `▄` U+2584) as
the FLOOR rendering glyph at v1.0.** Every output mode renders at
half-block density by default. The implementation always emits `▀`
(upper-half) with the top-pixel color as foreground and the bottom-
pixel color as background — `▄` is reserved for inverse-emit modes
that aren't activated at v1.0.

Quarter-blocks and full-block are **opt-in at tier-2** (not v1.0).
Braille rendering is post-v2 (different aesthetic; suits monochrome
or 1-bit imagery, not 16-color photographic).

## Consequences

**Positive**:

- **Doubles vertical resolution per character row for free**. A
  80×24 terminal becomes a 80×48 image canvas with one glyph per
  pair-of-source-rows. This is the dominant per-cell information
  density gain available without going to quarter-blocks (which add
  brittleness — see negatives below).
- **Single bg-color escape per cell** vs. quarter-blocks which need
  a 16-glyph dispatch table per cell. kii's emit code is one branch
  in `emit_halfblock_row_buf`; quarter-block emit would be a
  16-arm match per cell. Smaller code, faster emit.
- **Universal terminal-font support**. `▀` (U+2580) and `▄` (U+2584)
  are in the Unicode 1.1 (1993) Block Elements range; every TTY
  font that ships with a Linux distro renders them correctly. The
  Linux console's `/usr/share/kbd/consolefonts/*.psf` fonts include
  the full Block Elements range by default.
- **BBS / MUD aesthetic fit**. The 1992–1996 BBS era used DOS code
  page 437 block-drawing characters (the ANSI escape art `▄▀█▌▐`
  glyphs) for image-style content. kii's half-block emit is the
  direct Unicode-era descendant of that aesthetic.

**Negative**:

- **Anisotropic pixel shape**. One character cell is typically
  ~5×9 to ~7×14 (col×row) pixels in screen-space; a half-block
  pair-of-cells covers ~5×9 worth of horizontal screen but ~9 of
  vertical. The source image's pixel aspect is preserved only at
  ~2:1 character-cell-aspect-ratio (which is roughly correct for
  most monospace fonts). Images appear slightly squished vertically
  on terminals with very tall cells.
- **Two-color limit per cell**. A cell can show exactly two colors
  (top half + bottom half). Quarter-blocks would offer four colors
  per cell (one per corner), and braille can show one foreground +
  one background across 8 dots — but neither buys enough resolution
  to justify the per-cell glyph-dispatch complexity at v1.0.
- **Hard-coded `▀`-only emit**. kii cannot currently emit `▄`-with-
  inverse-colors as a tile choice; the row processor always picks
  `▀` and routes top pixel to fg, bottom to bg. A `▄`-emit twin
  would let kii vary glyph per cell to minimize color-change escape
  sequences (cell N emits `▀`/colors; cell N+1 emits `▄`/colors —
  reusing the SGR state). Possible v1.x optimization; tracked in
  the emit-cyr headroom section of `docs/benchmarks.md`.

**Neutral**:

- **Two-row source consumption per emit row**. The downscale stage
  produces a buffer with `dst_h = 2 × terminal_rows` source rows;
  the emit walks two source rows per terminal row. This is reflected
  in the M5 geometry math (`_kii_compute_target_geometry`,
  `_kii_compute_fit_geometry`) and is part of the user-visible
  contract — `--width 80` with terminal-fit 24 rows uses a 80×48
  source-pixel canvas.

## Alternatives considered

- **Full block (`█`) only**. Each cell is one pixel of solid color.
  Rejected because it halves the vertical resolution for no
  compatibility gain — `▀` is just as universally supported as `█`
  on every font that has either.
- **Quarter-blocks (`▘▝▖▗▀▄▌▐█▙▟▛▜▞▚` + space)** for 4× the
  vertical-and-horizontal resolution. Rejected for v1.0 because (a)
  the glyph-dispatch table per cell is 16 arms instead of 1; (b)
  legacy terminal fonts on older systems sometimes ship without the
  full Block Elements range; (c) the apparent resolution gain is
  swamped by aliasing artifacts at 16-color quantization (a
  high-frequency image dithers badly onto a 4-corner cell because
  adjacent cells reuse the same 4 colors). Tier-2 work might
  reconsider with proper dithering.
- **Braille (`⠀..⣿`)** for 8-dot-per-cell resolution. Rejected as
  aesthetic mismatch: braille produces a high-contrast line-art look
  that fits monochrome ASCII art, not 16-color half-block BBS
  aesthetics. Post-v2 if a consumer wants it.
- **Space + bg-color** (no glyph, just colored background). Half
  the bytes-per-cell of `▀`-emit (no glyph codepoint, just SGR + ' ').
  Rejected because it halves the vertical resolution — equivalent
  to full-block-only with the colors inverted. The 2× resolution
  gain of `▀`/`▄` was the entire point.
- **Per-cell glyph variation** (kii picks `▀` or `▄` or `█` or `' '`
  to minimize SGR-change bytes between adjacent cells). Considered
  as a tier-1 optimization; rejected as premature. The emit cost
  is ~0.1% of total decode time per `docs/benchmarks.md` § v0.6.0
  Breakdown — optimizing it before perf becomes a real issue is
  over-engineering. Captured as v1.x headroom.

## Trigger for revisit

- **Scheduled**: **v2.0.0 — full Block Elements glyph vocab**
  (U+2580..U+259F). Captured in
  [`../development/roadmap.md`](../development/roadmap.md) §
  Post-v1 considerations. Closes the bytewise + visual-detail gap
  with chafa documented in
  [`../audit/chafa-comparison.md`](../audit/chafa-comparison.md)
  (kii's 5.9×–69× byte verbosity vs chafa is driven by
  half-block-only + per-cell SGR pair; richer vocab lets each cell
  encode more visual information per byte). When scoped, this ADR
  will be superseded by the v2 glyph-vocab ADR and ADR 0003
  (color-tier-discipline / byte-stability) will need amendment
  because per-cell glyph variation breaks the fixed-shape per-cell
  contract.
- A consumer asks for quarter-block density before v2.0 ship —
  candidate for accelerating into a v1.x bite if the demand surfaces
  (likely a TUI app that wants finer image previews than half-block
  provides).
- Cross-terminal verification at M8 close uncovers a font that
  fails on `▀` or `▄` — would force a fallback path through space +
  bg-color (full-block aesthetic). No known target terminal does
  this, but worth surfacing if it appears.
- Performance work on emit reveals that per-cell glyph variation
  saves > 10% of total render time on real workloads. Currently the
  emit stage is ~0.1% of total time so there's no leverage.

## References

- [`../../CLAUDE.md`](../../CLAUDE.md) § Domain-specific rules (half-block FLOOR rule)
- [`../architecture/README.md`](../architecture/README.md) § Half-block aspect math
- Unicode 16.0, Block Elements (U+2580..U+259F)
