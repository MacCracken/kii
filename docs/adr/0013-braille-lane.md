# 0013 — The Braille lane (`--mode braille`)

**Status**: Accepted
**Date**: 2026-10-29
**Extends**: [0004](0004-half-block-floor-glyph.md) · [0005](0005-nearest-neighbor-downscale.md) ·
[0007](0007-rendering-mode-taxonomy.md) · [0011](0011-dithering.md)

## Context

The Braille Patterns block (U+2800..U+28FF) holds all 256 patterns of a 2 × 4 dot grid. Drawn
in a foreground colour on the terminal's background, a cell carries eight independent dots:
the finest shape of any glyph set that terminal fonts commonly carry, at the price of one
colour a cell. [ADR 0004](0004-half-block-floor-glyph.md) placed Braille post-v2 as a
different aesthetic, suited to line art and one-colour images more than photographs. The
roadmap pinned it to 2.3.0 with three points:
- reuse the blocks lane's sampler, whose 8 × 8 samples a cell reduce to 2 × 4;
- one foreground colour a cell, the mean of the inked dots, on the terminal's default
  background;
- leave the threshold between ink and paper to this ADR, naming three candidates: a fixed
  level, the cell's own mean, or error diffusion.

The ink is the ASCII lane's: brightness on a dark terminal, darkness under `--invert`
(2.2.0). So the lane needs a one-bit decision per dot from a value in 0..255. CP437 has no
Braille, so the Linux console cannot draw the lane.

## Decision

**1. A fourth opt-in lane.** `--mode braille` uses the ASCII and blocks lanes' cell grid
(cols × half-block rows). Each cell is 2 × 4 dots, so the dot grid is `cols·2 × rows·4`, and a
dot is square in a 1 : 2 cell.

**2. Sampling: the area sampler at the blocks lane's density.** main downscales to the dot
grid with `downscale_area_taps(…, 16, 8)`. A dot's span is read whole up to 16 pixels across
and 8 down, and by that many evenly spaced taps beyond. That is the blocks lane's density: 8 × 8
samples of up to 4 × 4 taps a cell, which is 16 × 8 per dot. The roadmap's other route, the
blocks sampler itself, was not taken:
- **It decides transparency at half coverage per sample.** A dot's ink is a coverage, best
  measured over its taps.
- **It keeps no luminance plane.** The area sampler writes one, with 2.2.0's `--invert`
  arithmetic, so an inverted frame is exactly its negative's here too.

Each dot gets the mean colour of its opaque pixels. Its ink is the mean luma over all its taps,
with transparent ones as 0, or under `--invert` its negative's.

**3. Ink: one level a frame (Otsu's), or a dither.** The rule follows `--dither`:
- **`none`**: Otsu's level for the frame. The split of the opaque dots' ink histogram (256
  bins) that maximizes the between-class variance; a dot at that level or above is inked.
  - The variance is compared exactly. N dots of total ink S, w0 of them below t with total
    s0, give ⌊(S·w0 − N·s0)² / (w0·(N − w0))⌋. `brl_mul_div` forms that without a product
    wider than 64 bits, and the frame cap keeps N ≤ 2²³.
  - A tie goes to the lowest level.
  - With no opaque dot, nothing is inked. With one ink value, every dot with any ink is.
- **`ordered`**: the 4 × 4 Bayer matrix quant.cyr dithers colour with, as a threshold per dot:
  16m + 8 for entry m.
- **`fs`**: Floyd-Steinberg over the dots against 128, with the colour pass's weights, clamp
  and ×16 integer error.
- **A dot with no opaque tap is never inked.** Under `fs` it carries no error.

The user chose Otsu for `none` on 2026-10-29, from four options with renders of the Arch
logo and of 3 px lines (§ Measurements): Otsu, a fixed 128, the cell's own mean, and error
diffusion always. Otsu was not one of the roadmap's three. It was added when the fixed
level erased the logo.

**4. Colour.** A cell's colour is the rounded mean of its inked dots' colours, quantized at the
tier:
- under `--dither fs`, every cell's colour as one field through `quantize_rgb_buf`;
- otherwise each cell through `kii_color_code_at`, which applies the ordered offset at the
  cell's position.

The background is the terminal's own, and a cell with no inked dot is a space.

**5. Glyph and row.** A cell is U+2800 plus its dot bits in Unicode's order: dots 1–3 down the
left column, 4–6 down the right, 7 and 8 below them. That is `E2, A0 + (b >> 6), 80 + (b &
63)`; a cell with no dots is a space, not U+2800. A row elides a repeated foreground and ends
with SGR 0 and a newline, as in the ASCII lane. At `--color none` it ends with the newline
alone and holds no escape.

**6. `--invert` and `--color none` apply.** The lane draws ink, so
`kii_lane_conflict_line` accepts both for `braille` ([ADR 0007](0007-rendering-mode-taxonomy.md)
§ v2.3.0). `--dither` changes bytes here even at `tc` and `none`, since the dots are still
quantized ([ADR 0011](0011-dithering.md) § v2.3.0).

## Measurements

**The threshold, prototyped** (Python, with ImageMagick's box resize for the dot ink, so close
to the lane's sampler but not its exact bytes). Columns 2–4 are the RMS error of each cell's
dot coverage against its mean ink, on a 0–255 scale; the last two describe renders.

| Rule | RAMGON, 40 cols | Arch logo, 30 | gradient, 30 | the logo | 3 px lines on white, `--invert` |
|---|---:|---:|---:|---|---|
| fixed 128 | 51.6 | 59.5 | 71.1 | blank (its blue has luma 125) | diagonals only; circle and box lost |
| Otsu | 49.8 | 63.5 | 71.1 | solid | every line, unbroken |
| cell's own mean | 47.8 | 59.3 | 71.1 | outline only (flat cells fall back to 128) | every line |
| Floyd-Steinberg | 18.1 | 6.6 | 14.7 | half-density stipple | broken into sparse dots |
| ordered | 16.7 | 6.2 | — | regular stipple | — |

Error diffusion and ordered dithering reproduce tone, as their errors show. A threshold
reproduces shape. Otsu was the only threshold that drew both test shapes. So the default
draws shape, and `--dither` gives tone.

**The lane, over the 472-image corpus:**
- **2,826 cases**, from six flag sets: every tier, every dither, with and without `--invert`,
  widths 40 and 120.
  - 2,733 frames are exactly `cols` cells of spaces and Braille Patterns a row.
  - 93 cases are refused exactly as the ASCII lane refuses them.
  - Every colourless frame is the coloured frame with its escapes removed.
- **Under `--invert`, every image draws its negative's dots** (ImageMagick `-negate`): 422 of
  422, under each of the three rules at both widths.
- **94 frames ink no dot.**
  - 93 of them are blank in the ASCII lane too: black content when light is ink, or images
    with no pixel at alpha 128 or above.
  - The other is a near-white image under `--invert --dither fs`, whose diffused ink never
    reaches a dot.
- **The other lanes are unchanged:** half-block, ASCII and blocks are byte-identical to 2.2.0
  (5,192 of 5,192 cases).
- **Frame size**, at `--width 40` and 16 colours: 0.92× half-block's bytes (blocks 0.69×, ASCII
  0.50×). RAMGON at `--width 80`: 6,248 bytes, against 7,441 half-block.

**CPU** per run (user + system), fastest of three rounds:

| Render | blocks | Braille |
|---|---:|---:|
| RAMGON, `--width 80` | 207.9 ms | 200.6 ms |
| RAMGON, `--width 200` | 246.5 ms | 205.7 ms |
| archlinux-logo, `--width 60` | 6.61 ms | 2.52 ms |
| archlinux-logo, `--width 200` | 36.16 ms | 6.57 ms |

Most of RAMGON's time is the decode. The ASCII lane, which now reaches the sampler through
`downscale_area_taps`, is unchanged against 2.2.0 (RAMGON at `--width 200`: 210.68 against
210.66 ms). The dithers add 0.6–1.4 % on RAMGON.

**Tests:**
- `tests/braille.tcyr`, 60 assertions: the dot order and UTF-8, `brl_mul_div` at the widest
  products the lane forms, Otsu on hand-checked histograms, each rule on dot patterns checked
  against a reference, the cell colour at truecolour, rows at each tier, and the refusals.
- A 17th fuzz surface, 30,000 random images.
  - It checks the sampler at 16 × 8 against the area reference.
  - It checks each rule against its own reimplementation: Otsu by direct division, the Bayer
    threshold, and Floyd-Steinberg over a whole error plane.
  - It checks the negative, and the escapes stripped from every row.
- Of 25 defects planted in the lane, the unit suite catches all 25 and the fuzz surface 15.

## Consequences

**Positive**
- **The finest shapes of any lane.** Logos, line art and text keep their edges at half a cell
  across and a quarter down, with eight independent dots a cell.
- **One-colour output.** With `--color none` the frame is plain text. With `--dither fs` as
  well, it is dithered Braille art in the terminal's own colour.
- **It is fast.** The logo at `--width 200` takes 6.57 ms, against 36.16 ms in the blocks
  lane.
- **2.2.0's settings carry over unchanged.** `--invert` is exact, and `--color none` is
  exact.

**Negative**
- **One colour a cell.** A cell with two colours shows one of them, and the dark one is lost
  on a dark terminal.
- **Brightness depends on the font.** Dots are drawn small, so a solid region looks darker
  than the half-block lane's. How much depends on the font's dot size, which kii cannot
  know.
- **Otsu's level is global.** The same picture at another width can get a slightly
  different level, and an image whose subject is a mid tone among other mid tones may split
  where the eye does not. There is no fixed-level override yet (a roadmap candidate).
- **No Braille in CP437.** The Linux console cannot draw the lane.

**Neutral**
- **The area sampler takes per-axis tap counts** ([ADR 0005](0005-nearest-neighbor-downscale.md)
  § v2.3.0).
- **In this lane, `--dither` also covers the dots** ([ADR 0011](0011-dithering.md) § v2.3.0).

## Alternatives considered

- **A fixed level at 128.** It erased the Arch logo and the 3 px lines (§ Measurements).
- **The cell's own mean.** It draws edges, but hollows every flat region.
- **Error diffusion always, even at `--dither none`.** It is the most faithful for tone, but
  it breaks lines and stipples flat colours, and it would break ADR 0011's promise that
  `none` dithers nothing.
- **The blocks sampler.** § Decision 2.
- **U+2800 for an empty cell.** A space takes the same column, needs no glyph from the font,
  copies as a space, and matches the other lanes.
- **A background colour as well** (chafa's braille symbols take one). That would be the
  blocks lane's two-colour fit with smaller shapes. The roadmap fixed one colour on the
  terminal's background, which is the form that `--color none` and `--invert` apply to.

## References

- The Unicode Standard, Braille Patterns (U+2800..U+28FF): the dot order.
- N. Otsu, "A Threshold Selection Method from Gray-Level Histograms", IEEE Trans. SMC 9(1), 1979.
- `drawille` (the 2 × 4 dot canvas), `chafa`'s braille symbols, and image-to-Braille converters
  that threshold and optionally dither.
