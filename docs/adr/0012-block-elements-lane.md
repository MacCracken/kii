# 0012 — The Block Elements lane (`--mode blocks`)

**Status**: Accepted
**Date**: 2026-10-28
**Amends**: [0004](0004-half-block-floor-glyph.md) · **Extends**: [0005](0005-nearest-neighbor-downscale.md) ·
[0007](0007-rendering-mode-taxonomy.md) · [0011](0011-dithering.md)

## Context

The half-block lane gives each character cell two colours, one per half: two pixels a
cell. The Unicode Block Elements (U+2580..U+259F) have 32 glyphs that split a cell
other ways: eighths from the bottom and from the left (`▁`..`▇`, `▏`..`▉`), the upper and
right eighth (`▔` `▕`), the four quadrants and their complements (`▘▝▖▗`, `▟▙▜▛`), the
two diagonals (`▚▞`), the halves, the full block, and three shades (`░▒▓`). Drawn in two
colours, they let a cell carry a shape at a finer scale than half a cell: an edge
anywhere along eighths, a corner, a diagonal. chafa's `block` symbol class renders this
way. The roadmap had held "the full Block Elements vocabulary" open since v1.0 as a 2.0
item that would supersede [ADR 0004](0004-half-block-floor-glyph.md).

Two things argued against making it the default:
- **Fonts.** CP437, the code page the BBS aesthetic descends from, has `▀▄█▌▐░▒▓` and
  nothing else in the range. The eighths are in Unicode 1.1, but the quadrants only arrived
  in Unicode 3.2, and Linux console fonts built from CP437-era sets may lack either. A
  half-block frame renders everywhere; a blocks frame needs a modern font.
- **CLAUDE.md's floor rule**: half-block density is the default, and quarter-blocks or
  full pixels are opt-in.

On 2026-10-28 the user chose the opt-in form for 2.0.0.

## Decision

**`--mode blocks` is a third render lane, opt-in.** `kii image.png` stays the half-block
lane; ADR 0004 is amended, not superseded.

### 1. Geometry and sampling

- **Cells as in the ASCII lane.** cols = the target width, rows = the half-block row count,
  so the frame has the half-block frame's size and aspect.
- **8 × 8 samples per cell.** The eighths need eight steps a side, and every other Block
  Element's edge falls on that grid.
- **Each sample is read through the area sampler's tap tables** (`_area_taps`,
  [ADR 0005](0005-nearest-neighbor-downscale.md) § v1.11.0 amendment): the mean of its span,
  read whole up to 4 pixels a side, by 4 evenly spaced taps beyond. The lane samples each
  cell straight from the decoded pixels, without a downscaled frame in between, so its
  memory is the per-cell records, not the 64 samples of every cell.
- **A sample is transparent when more than half its pixels are.** The lane's shapes are
  binary per sample, so half coverage or more rounds to opaque. The area sampler marks a
  sample transparent only when no pixel is opaque; the ASCII lane keeps the coverage in
  its luminance instead, which this lane has no place for.

### 2. The shape of an opaque cell

- **19 splits**: the lower and the left half, the four quadrants, the diagonal `▚`, and
  the lower and the left 1, 2, 3, 5, 6 and 7 eighths. With their complements (§ 4) they
  are every Block Element except the shades.
- **Least squared error wins.** Each split's two regions are drawn in their mean
  colours. The split whose drawing has the least squared error against the 64 samples is
  the one with the largest |S₁|²/n₁ + |S₂|²/n₂ (S the region's colour sum, n its size),
  which needs only the region sums. Those come from per-row, per-column and per-quadrant
  sums, so a cell costs one pass over its samples and 19 constant-time scores.
- **Exact.** The scores are compared cross-multiplied, in integers (below 2⁴⁸). Ties keep
  the earlier split, in the order above. A cell no split improves keeps one colour: only a
  cell whose regions all have the same mean, such as a uniform cell or a sample-level
  checkerboard.
- The means are rounded half up.

This is chafa's method (two colours per cell, each region's mean, least error); the fast
scoring from region sums is kii's.

### 3. Colour

The cells' ink colours form one field and their other colours a second, each cols × rows,
and both go through `quantize_rgb_buf`. So `--color` and `--dither` act as in the other
lanes: ordered offsets by cell position, Floyd-Steinberg error carried from cell to cell
within each field. A cell drawn in one colour uses its background field's code.

### 4. The glyph

- **Complements.** Twenty shape glyphs pair up as complements: `▀▄`, `▌▐`, `▇▔`, `▉▕`,
  `▘▟`, `▝▙`, `▖▜`, `▗▛`, `▚▞`, and the space with `█`. A split can be drawn as its glyph
  with the ink colour in front, or as the complement with the colours swapped. The row
  draws whichever needs fewer colour escapes after the cell before it; a tie keeps the
  split's own glyph. [ADR 0004](0004-half-block-floor-glyph.md) named this for `▀ / ▄` as a
  possible optimization.
- **Flat cells.** A split whose two colours quantize to the same code, and a one-colour
  cell, are drawn flat: a space when the background is already that colour, `█` when only
  the foreground is (no escape either way), else a space after one background escape.
  The space is one byte, `█` three.
- **Escapes.** A space needs only a background escape, `█` only a foreground one, and
  every other glyph both. Each row starts with its colours unknown and ends with the
  reset, as in the other lanes.

### 5. The shades

`░▒▓` draw the foreground over the background at 1/4, 1/2 and 3/4. As a shape they mean
little: chafa keeps them in a separate `stipple` class, and with both classes on it chose
two of 2,640 cells on RAMGON. As a mix they are what the 8 and 16-colour palettes lack:
a colour between two entries. So kii uses them as the lane's dither:
- **Only under `--dither ordered` or `fs`.** [ADR 0011](0011-dithering.md) promises that
  `none` maps each colour to its nearest on its own, and a mix is a dither.
- **Only at tiers 8 and 16.** The 256 cube's steps are fine enough, and truecolour has
  every colour.
- **Only for cells drawn flat.** The cell's mean is compared with the 1/4, 1/2 and 3/4 mixes
  of every pair among the four palette colours nearest it, in order of nearness. The
  nearest mix replaces the flat colour if it is strictly nearer the mean. Ties keep the
  first found. The errors are kept ×16, so the quarters are exact integers.
- `░` with `a` over `b` reads as `▓` with `b` over `a`, and `▒` either way, so a shade too
  takes whichever orientation needs fewer escapes.

### 6. Transparency

- **A cell with no opaque sample** is a space on the terminal's default background.
- **A cell with both** is drawn with the glyph whose ink best covers its opaque samples, in
  their mean colour, over the default background. Each sample on the wrong side costs the
  largest colour error a sample can have (3 · 255²), plus the squared error of the opaque
  samples under the ink about their mean. Every shape glyph is a candidate, the space and
  `█` included. The best may be the space, which makes the cell clear.

### 7. Integers everywhere

Sampling, scoring, means, the shade search and the quantizers are integer arithmetic, so
every target draws the same bytes.

## Consequences

**Positive**
- A cell carries a shape: an edge at any eighth, a corner, a diagonal, in two colours.
  Outlines that the half-block lane steps in half-cell stairs follow the image.
- At 8 and 16 colours frames are smaller than the half-block lane's at the same size,
  because flat cells are a space and complements reuse the colours already set. At
  truecolour they can be larger: detail gives a cell two distinct colours where half-block
  often repeats one (§ Measurements).
- The default output, and every half-block and ASCII frame, is unchanged.

**Negative**
- **Fonts.** The lane needs a font with the quadrants and eighths. On a CP437-era console
  font, cells show replacement glyphs. That is why the lane is opt-in, and why
  cross-terminal verification matters most for it (roadmap § Not scheduled).
- **Cost.** About 2–3 µs a cell for sampling and scoring, which is more than the other lanes'
  per-cell work (§ measurements).
- **Thin colour averages away.** A sample is the mean of its span, so a coloured stroke
  much thinner than a sample comes out as a dim mix with its background. At 8 and 16 colours
  that mix often quantizes to grey or black, where the half-block lane's single pixel keeps
  the stroke's full colour: on a 3880-pixel terminal screenshot at 100 columns, red and
  yellow text that half-block shows as scattered coloured dots reads as grey strokes here.
  The strokes are in the right places, and the per-pixel error is still lower
  (§ measurements), but the colour is gone. `--dither` and `--color 256` / `tc` recover
  some of it. This is the effect [ADR 0005](0005-nearest-neighbor-downscale.md) § Alternatives
  gave for not averaging in the half-block lane.
- **The shape is chosen before quantization.** At 8 and 16 colours a split whose colours
  quantize together is drawn flat, and a better split for the quantized colours may exist.
  Choosing shapes with quantized colours is a roadmap candidate.

**Neutral**
- The lane adds a module (`src/blocks.cyr`), a unit suite (`tests/blocks.tcyr`) and two fuzz
  surfaces.

## Measurements (v2.0.0)

All at tier 16 unless stated; CPU per run, three interleaved rounds, minimum.

**Fidelity.** Each lane's frame rasterized (8 × 16 pixels a cell, Block Elements from their
geometry) and compared with the source box-filtered to the same size; RMS error per channel,
and the frame's bytes, at `--width 80`:

| Image | half-block RMS | blocks RMS | half-block bytes | blocks bytes |
|---|---:|---:|---:|---:|
| RAMGON 1152 × 925 | 38.9 | 32.1 | 14,553 | 8,080 |
| RAMGON, truecolour | 28.0 | 18.0 | 94,244 | 94,298 |
| archlinux-logo 256² | 19.1 | 17.9 | 6,150 | 5,577 |
| 2 px lines and a circle, 480² | 45.6 | 30.7 | 13,057 | 7,791 |
| white serif text, 600 × 200 | 39.6 | 23.6 | 4,103 | 2,390 |
| kitty screenshot 3880 × 2168 | 57.1 | 36.5 | 7,288 | 5,260 |
| the screenshot, truecolour | 47.7 | 24.4 | 12,939 | 30,761 |

**Corpus.** 471 images × 5 flag sets (tiers 8, 16, 256 and truecolour, the three dither
modes): every case exits with the same code and stderr as the half-block lane; the 2,280
frames that render are all well formed (exactly `cols` cells a row, each a space or a Block
Element); together they are 0.63× the half-block lane's bytes; all 32 Block Elements and the
space occur. The half-block and ASCII lanes are byte-identical to v1.11.0 on all 2,832 of the
corpus's frames.

**Cost.**

| Render | half-block | blocks |
|---|---:|---:|
| archlinux-logo, `--width 80` | 1.92 ms | 9.26 ms |
| archlinux-logo, `--width 200` | 3.05 ms | 38.22 ms |
| RAMGON, `--width 80` | 205.8 ms | 220.1 ms |
| RAMGON, `--width 200` | 208.3 ms | 261.8 ms |
| kitty screenshot, `--width 80` | 332.7 ms | 347.3 ms |
| 4000² PNG at the cell cap (`--width 1448`, 1.05 M cells), wall | 0.65 s | 3.84 s |

About 2–3 µs a cell, half of it the shape choice and most of the rest the sampling; dropping
the divisions for one-pixel samples saved 1 %. Peak RSS at the cell cap is 132.7 MB against
126.7 MB. The `kii-bench` rows (decode excluded): 13.9–14.0 ms for RAMGON at 80 × 32 cells,
52.8–53.2 ms at 200 × 80.

**Tests.** 84 assertions in `tests/blocks.tcyr`. Of 18 defects planted in `src/blocks.cyr`,
17 fail the suite, and the fuzz surface that checks the shape choice against brute force
catches the six in the scoring on its own. The 18th is an equivalent rewrite: a mixed cell's
background code is already the default colour.

## Alternatives considered

- **Blocks as the default** (the roadmap's original wording). Declined by the user for the
  font reason above; it would also have changed every default frame.
- **Shades as shapes**, scored like the other glyphs on a stipple bitmap, as chafa does.
  Rejected: they are almost never chosen that way, their dot pattern differs from font to
  font, and they are worth something only as a mix of palette colours.
- **Scoring every glyph by its own mask over the 64 samples.** Exact and simple, but a pass
  over all 64 samples per split instead of one sum. It is kept as the fuzz harness's
  reference, which checks the fast scoring against it.
- **Quadrants only** (2 × 2 samples, notcurses' quadrant blitter). Simpler, but drops the
  eighths, which carry most of the gain on smooth edges.
- **Sextants and octants** (Symbols for Legacy Computing). Finer, but outside the Block
  Elements and in few fonts; a roadmap candidate.
- **Braille.** One colour per cell and a different aesthetic; pinned to 2.3.0 as its own
  lane.

## References

- [ADR 0004](0004-half-block-floor-glyph.md) § v2.0.0 amendment
- chafa 1.18.3 `--symbols block` and `--symbols stipple` (compared on RAMGON, 2026-10-28)
- notcurses' quadrant blitter: two colours per 2 × 2 cell, chosen per cell
- Unicode 15.1, Block Elements (U+2580..U+259F)
