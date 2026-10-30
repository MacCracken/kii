# 0011 — Dithering: `--dither none | ordered | fs`

**Status**: Accepted
**Date**: 2026-10-16
**Extends**: [0003](0003-color-tier-discipline.md) · [0005](0005-nearest-neighbor-downscale.md) ·
[0010](0010-tier-2-colour-and-emit-encoding.md)

## Context

Through v1.8.0 kii mapped each pixel to its nearest palette colour on its own. With 8 or 16
colours a smooth gradient becomes a few flat bands. At 256 colours the bands are narrower but
still there in skies and skin. [ADR 0003](0003-color-tier-discipline.md) left the dithering
choice (Floyd-Steinberg or ordered/Bayer) to a later ADR. [ADR 0005](0005-nearest-neighbor-downscale.md)
deferred it to "tier 2", together with a `--filter` option. The roadmap pinned
`--dither none|ordered|fs` to 1.9.0, as a self-contained change to the quantize layer.

Dithering is a choice, not a fix. It trades flat bands for a fine pattern of two neighbouring
colours. That pattern costs bytes, because the escape elision from [ADR 0010](0010-tier-2-colour-and-emit-encoding.md)
works on runs of equal colour, and the 8/16-colour floor exists for slow links.

## Decision

### 1. The flag

- `--dither none | ordered | fs` (`-d`) is a cmdit enum. **The default is `none`**, and
  `--dither none` gives the same bytes as omitting the flag.
- The flag is independent of `--mode` and `--color`. It works at tiers 8, 16 and 256. At
  truecolour nothing is quantized, so the flag changes no byte.
- kii stays environment-blind: no tier or terminal turns dithering on by itself.

### 2. Where it happens

- **In the quantize layer** (`quantize_rgb_buf`, `src/quant.cyr`), after the downscale.
  Dithering at source resolution would be wasted, because the nearest-neighbour downscale
  keeps one pixel in each span and would alias the pattern away.
- **Half-block lane:** the downscaled grid is dithered pixel by pixel; each pixel is half a
  cell.
- **ASCII lane:** the unit is the cell. A cell's colour is the mean of its opaque samples,
  so the cell colours are dithered as one field of cols × rows. Glyph choice is unchanged:
  it comes from the undithered samples' brightness.
  - Ordered dithering needs only the cell's position, so the row applies it per cell.
  - Floyd-Steinberg needs the cells before it, so under `fs` (and only then) the lane first
    quantizes every cell colour as one field.
- **Transparent pixels** keep the terminal's default colour (ADR 0010). They neither take
  nor pass on Floyd-Steinberg error.

### 3. Ordered: a 4×4 Bayer matrix

- Pixel (x, y) takes the matrix entry m = B[y mod 4][x mod 4], from 0 to 15. The offset
  ((2m + 1) · step) / 32 − step / 2 is added to R, G and B alike before the nearest-colour
  match.
- `step` is the spacing of the tier's levels: **170** at tier 8, **85** at tier 16, and
  **40** at tier 256 (the cube's step above its first level).
- **The offset stays strictly inside ±step/2.** A colour already in the palette never moves,
  and the test suite checks this on black, red, bright black and white under every mode. A
  colour between two levels becomes a mix of those two, in proportion to where it sits.
- **The same offset on all three channels** moves a pixel along the grey axis. Independent
  per-channel offsets would add colour noise that a 16-colour palette renders as speckles of
  unrelated hues.
- **4×4** is the smallest Bayer matrix with 16 levels, and 16 levels between two palette
  levels are more than a cell can show. A larger tile repeats less often, and at terminal
  resolution that repeat is the visible pattern.

### 4. Floyd-Steinberg

- The scan runs left to right, top to bottom. Each pixel's error (wanted minus shown, per
  channel) passes on 7/16 to the right, 3/16 down-left, 5/16 down and 1/16 down-right.
- **The arithmetic is exact integers.** Errors are kept ×16 in two rows of i64. A pixel
  plus its carried error is clamped to 0–255 before the match, and its error is measured
  from that clamped value, so error cannot run away across a saturated area.
- The error is measured against **the RGB the chosen code stands for** at the active tier:
  the palette entry at tiers 8 and 16, and the cube or grey level at 256.
- **The output is the same on every target.** x86_64 and aarch64 give identical frames
  under every mode (648 of 648 frames compared, both lanes, all four tiers).

### 5. Not decided here

- **Error is diffused in sRGB-coded values**, the same space the quantizer measures in
  (ADR 0010 § 3). Diffusing in linear light is more faithful in the mid-tones but needs a
  gamma table, and it would make the dithered and undithered tiers disagree about distance.
  That is quality work for a later release.
- **No `--filter`.** ADR 0005's pairing of `--filter box` with `--dither fs` stays
  unscheduled: nearest-neighbour remains the only downscale.

## Consequences

**Positive**

- **Gradients follow the source.** On a 64×256 grey ramp at `--width 64`, the mean error of
  each column's average brightness, against the ramp it shows:

  | tier | none | ordered | fs |
  |---|---:|---:|---:|
  | 8 | 34.7 | 27.2 | 16.2 |
  | 16 | 21.2 | 11.8 | **5.0** |
  | 256 | 2.6 | 1.9 | 2.1 |

  At tier 16, Floyd-Steinberg cuts the error by three quarters. At 256 the levels are
  already close, and both modes mostly add texture.
- **Opt-in.** The default frame is what it would be without the flag.
- **Deterministic.** The same image, width and flags give the same bytes on every target.

**Negative**

- **Dithered frames are larger.** A pattern of two colours breaks the runs that elision
  skips. Measured on RAMGON at `--width 80` (half-block) and in `docs/benchmarks.md`
  § v1.9.0:
  - tier 16: 14,553 bytes, against 23,222 ordered and 23,753 fs (+60 %).
  - tier 8: 13,330, against 20,740 and 21,990.
  - tier 256: 47,097, against 60,164 and 51,771.

  Over the 466-image corpus at `--width 60`, both modes multiply output by 1.4–1.6 at
  tier 8 and by 1.8–2.0 at tier 16. At tier 256 the factor is 3.3–4.2, because a pattern
  there mixes many more distinct codes.
- **At tier 256 near-grey pixels get more texture than they need.** The step is the cube's
  40, but the grey ramp's levels are 10 apart, so an ordered offset can move a grey across
  several of them. The ramp's error still drops (2.6 → 1.9). A step chosen per pixel would
  fix this, at the cost of a second rule.
- **It costs CPU.** For a 256² icon at `--width 200`, user time per render rises from
  4.8 ms to 5.5 ms with ordered and 6.6 ms with fs (half-block, tier 16). On large images
  the decode dominates and the difference is under the noise.
- **Tier 8 ordered is coarse.** Its step is 170, so the pattern has only black and one
  intensity per channel to mix.

**Neutral**

- **In the ASCII lane a space cell still takes part in Floyd-Steinberg.** Its colour is not
  drawn, but its error carries on. Space cells are the darkest, where the error is small.
  Leaving them out would make the colour field depend on the glyph choice.
- **No new escapes.** Dithering only chooses among the codes each tier already emits, so the
  restricted-emit posture of [0002](0002-security-model.md) is untouched.

## Alternatives considered

- **Dither by default at tiers 8 and 16.**
  - Rejected: it would change every default frame and enlarge it by ~60 % on exactly the
    slow links the 8/16-colour floor is for.
- **Dither before the downscale.**
  - Rejected: the nearest-neighbour downscale keeps one pixel per span, which aliases the
    pattern into noise.
- **An 8×8 Bayer matrix, or blue noise.**
  - Rejected for now: both need a larger table, and 16 levels already exceed what a cell can
    show between two palette colours.
  - Blue noise hides the tile better and could be a fourth mode later.
- **Serpentine Floyd-Steinberg** (alternate row direction), **Atkinson**,
  **Jarvis-Judice-Ninke**, **Sierra**.
  - Not rejected on merit. Plain Floyd-Steinberg is the reference the others are measured
    against, and each could be another enum value.
  - Jarvis and Sierra carry error two rows down, which needs a third error row.
- **Shade glyphs (`░ ▒ ▓`) as a dither.**
  - Rejected here: that is a glyph choice, outside the half-block floor
    ([0004](0004-half-block-floor-glyph.md)), and belongs to a rendering mode, not to
    quantization.

## References

- R. W. Floyd and L. Steinberg, "An adaptive algorithm for spatial greyscale" (1976); B. E.
  Bayer, "An optimum method for two-level rendition of continuous-tone pictures" (1973).
- chafa's `--dither none|ordered|diffusion`, and libcaca's dither set (`ordered2/4/8`,
  `fstein`): the same two families, ordered and error diffusion.
- [`../development/roadmap.md`](../development/roadmap.md), where 1.9.0 was pinned at v1.6.3,
  and [`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md) § 6, which deferred C-7
  (sampling) to the same release. The sampling change is recorded in
  [0005](0005-nearest-neighbor-downscale.md)'s v1.9.0 amendment, not here.

## Amendment — v2.0.0 (dithering in the blocks lane)

This ADR remains **Accepted**. § Alternatives rejected shade glyphs as a dither for the
quantize layer because they are "a glyph choice … and belong to a rendering mode". The
blocks lane ([ADR 0012](0012-block-elements-lane.md)) is that rendering mode, and it uses
them that way:
- **Its two colour fields** (each cell's ink colour, and its other colour) go through
  `quantize_rgb_buf` like any field: ordered offsets by cell position, Floyd-Steinberg error
  carried from cell to cell within each field.
- **Under `ordered` or `fs`, at tiers 8 and 16, a cell drawn flat may become `░`, `▒` or `▓`**:
  a 1/4, 1/2 or 3/4 mix of two of the four palette colours nearest its mean, when that mix is
  strictly nearer the mean than the flat colour.
- **Under `none` no shade is drawn**, so this ADR's promise holds in every lane: `none` maps
  each colour to its nearest on its own.

## Amendment — v2.3.0 (the Braille lane dithers its dots)

This ADR remains **Accepted**. In the Braille lane ([ADR 0013](0013-braille-lane.md))
`--dither` also decides which dots are inked, a one-bit quantization of each dot's ink:
- **`none`**: one level for the whole frame (Otsu's), each dot on its own against it.
- **`ordered`**: the same 4 × 4 Bayer matrix, as a threshold per dot (16m + 8).
- **`fs`**: Floyd-Steinberg over the dots against 128, with the same weights, the same
  clamp and the same ×16 integer error as the colour pass.

The cells' colours are dithered as in the other lanes. Two consequences:
- **In this lane `--dither` changes bytes at `tc` and at `--color none`.** Their colours
  are not quantized, but the dots still are. § Decision's "at truecolour the flag changes
  no byte" holds for colour only.
- **`none` still quantizes each dot on its own.** It is against one level for the frame
  rather than a fixed 128, so this ADR's promise for `none` holds.
