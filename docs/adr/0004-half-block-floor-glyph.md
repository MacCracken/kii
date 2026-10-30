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
  2.0 — open. Closes the bytewise + visual-detail gap
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

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**. One correction: § Trigger for revisit cited the roadmap's
"§ Roadmap ahead", a section that no longer exists. The Block Elements item now sits under
roadmap § 2.0 — open, still unpinned. The citation was corrected in place.

## Amendment — v2.0.0 (the Block Elements lane, opt-in)

This ADR remains **Accepted**, and half-block remains the default. § Trigger for revisit
expected the full Block Elements vocabulary to supersede it. At 2.0.0 the vocabulary
arrived as an opt-in lane instead, `--mode blocks`
([ADR 0012](0012-block-elements-lane.md)), on the user's decision of 2026-10-28.
- **Why not the default.** CP437 carries `▀▄█▌▐░▒▓` and none of the quadrants or eighths,
  so a console font of that lineage cannot draw a blocks frame. That keeps § Positive's
  "universal terminal-font support" argument for half-block as strong as when this ADR was
  written. (§ Positive's claim that Linux console fonts carry "the full Block Elements range
  by default" is too broad for fonts of CP437 lineage; it is left as written.)
- **The `▀ / ▄` choice** that § Negative named as a possible optimization is what the blocks
  lane does for every complementary pair. Bringing it to the half-block lane is pinned to
  2.1.0: visually identical frames in fewer bytes, but different bytes for the default lane.
- **Braille**, which § Decision placed post-v2, is pinned to 2.3.0 as its own lane.

## Amendment — v2.1.0 (the half-block lane reuses its colour state)

This ADR remains **Accepted**. The lane still draws two pixels a cell, top over bottom, and is
still the default. What changes is how a cell is encoded, which § Alternatives considered
set aside as premature (per-cell `▀` / `▄` / `█` / space): since 2.1.0 the lane draws it.
- **The rule** (`emit_halfblock_row_buf`). Each row tracks the fg and bg it last set, as
  since v1.8.0. A cell of two colours is `▀` (fg = top, bg = bottom) or `▄` (fg = bottom,
  bg = top), whichever needs fewer escapes, and a tie keeps `▀`. A cell of one colour is a
  space on that bg, or `█` in that fg when the fg already has it and the bg does not. A
  transparent half is the terminal's default background, so a cell with one is drawn as
  before: `▀` or `▄` on SGR 49, or a space when both halves are transparent. All four
  glyphs are in CP437, so § Positive's font argument is unchanged.
- **At tier 16 a bright colour stays in the foreground when it can.** A one-colour bright
  cell is `█`, and a cell with exactly one bright half puts that half in the fg. Only a cell
  of two different brights still has a bright background, as every such cell did before.
  The reason is the Linux console (`drivers/tty/vt/vt.c`, `csi_m`, read 2026-10-29). It
  draws SGR 100–107 as 40–47, so it has no bright backgrounds. It draws 90–97 by setting
  bold, which a later 30–37 does not clear, so later dim foregrounds in the row show bright
  until the reset. A rule that moved bright colours into the background freely would show
  more of them dim there.
- **The choice was the user's**, on 2026-10-29, from three measured options: the plain rule
  (the blocks lane's, [ADR 0012](0012-block-elements-lane.md)); this one; and this one plus
  SGR 22 folded into a dim foreground after a bright one, to clear the console's stuck bold.

### Measurements (2.1.0 against 2.0.1)

Over the 472-image corpus, in every tier and dither at `--width 40` and `120`
(11,304 cases):
- **Colours.** Each of the 10,932 frames was decoded as a terminal reads it, into the top
  and bottom colour of every cell. Every cell matches 2.0.1's, and no half is drawn in the
  default foreground. The 372 inputs both refuse give the same error and exit code.
- **Bytes.** Tier 8 −50.8 %, tier 16 −50.1 %, tier 256 −40.4 %, truecolour −36.8 %. At
  tier 16, `none` −28.1 %, `ordered` −57.9 %, `fs` −51.8 %. Glyphs drawn: 40.7 M spaces,
  8.4 M `▀`, 5.5 M `▄`, 5.5 M `█`. One frame of 10,932 is larger, by 2 bytes (1,746 →
  1,748): the choice is greedy, so saving an escape now can cost one later in the row.
- **The Linux console, modelled from `csi_m`** (not observed on a console; reading
  `/dev/vcsa` needs root). Cell halves shown in a colour other than the one meant, at
  tier 16: `none` 27.6 % → 0.60 %, `ordered` 40.6 % → 1.27 %, `fs` 36.1 % → 3.63 %.
  The decision was taken on the same model at `--width 80`, tier 16, `none`: the plain rule
  38.3 % wrong at −50.8 % bytes, this rule 0.80 % at −30.2 %, the SGR 22 option 0.34 % at
  −30.0 %.
- **The ASCII and blocks lanes** are byte-identical to 2.0.1's (5,664 cases).
- **CPU**: within run-to-run noise (a 256² icon at `--width 200` 3.11 → 3.20 ms best of
  five; RAMGON unchanged at ~220 ms).
- **The greedy rule against an exact one.** Per row, the fewest bytes over every encoding
  of the same colours is a shortest path over the colour state. On a 40-image sample at
  tier 16, `--width 80`, the plain rule saved 50.9 % against the exact optimum's 55.3 %, and
  looking two cells ahead saved 54.4 %. Left as a roadmap candidate.
- **Tests.** A fuzz surface (200,000 rows) decodes each row and checks the colours, that no
  escape repeats the colour already set, and that each glyph is the rule's. Of 14 defects
  planted in the rule, the unit suite and the fuzz surface each catch 13. The 14th is
  equivalent: for a dim colour, no cell leaves the fg and the bg equal to it, so the `█`
  rule's "and the bg does not" never decides.

## Amendment — v2.3.0 (the Braille lane, opt-in)

This ADR remains **Accepted**. The Braille Patterns, which § Decision placed post-v2, ship
as their own opt-in lane, `--mode braille` ([ADR 0013](0013-braille-lane.md)). Each cell
is 2 × 4 dots in one colour on the terminal's background. The half-block lane is the
default and is byte-identical to 2.2.0.

## Amendment — v2.7.0 (the cell's measured shape)

This ADR remains **Accepted**. The half-block lane's two halves are square only in a cell
twice as tall as wide, which every lane assumed through 2.6.0. Since 2.7.0 the rows come from
the cell kii measures from the terminal, or `--cell-size`, or 10x20
([ADR 0015](0015-measured-cell.md)), so the image keeps its aspect on any cell. On a 1:2 cell,
off a terminal, and where the terminal reports no pixels, the lane is byte-identical to 2.6.0.
