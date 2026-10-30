# 0005 — Nearest-neighbor downscale (no Lanczos / bilinear at v1.0)

**Status**: Accepted
**Date**: 2026-05-23

## Context

kii's pipeline downscales a source PNG (potentially thousands of
pixels per side) to the terminal-fit target (~80×48 at the 80×24 BBS
default; up to ~200×120 at wide-terminal sizes). The downscale
algorithm choice trades sharpness against smoothness:

| Algorithm | Cost | Aesthetic |
|---|---|---|
| Nearest-neighbor | 1 source-pixel lookup per dst pixel | Crisp; pixel-art-preserving; visible blockiness on photo-class inputs |
| Bilinear | 4 source-pixel reads + 3 lerps per dst | Smoother; soft on hard edges |
| Bicubic / Lanczos | 16+ source-pixel reads + cubic/sinc weights | Smoothest; tunable ringing |
| Box-filter (average over source-block) | (block_w × block_h) reads per dst | Smooth without ringing; halos on hard edges |

The 16-color quantization stage runs AFTER downscale, and the choice
of downscale algorithm interacts with quantization in a way that
matters more than the raw aesthetic question.

## Decision

**kii uses nearest-neighbor downscale (`src/downscale.cyr`) for
all v1.0 rendering.** Bilinear / bicubic / Lanczos / box-filter
alternatives defer to tier-2 (post-v1) where dithering choices land
together.

The implementation: `downscale_to_rgb(pstruct, dst_w, dst_h)` walks
each destination pixel, computes `(sx, sy) = (dx × src_w / dst_w,
dy × src_h / dst_h)`, and reads ONE source pixel at that position
through the per-color_type extraction path in `_extract_rgb`. No
interpolation, no averaging.

## Consequences

**Positive**:

- **Preserves pixel-art crispness**. A 16×16 sprite scaled up to
  80×48 stays sharp under nearest-neighbor; bilinear would soften
  every edge into a gradient that the 16-color quantizer then
  hardens back into ugly bands. This matches the BBS / MUD
  aesthetic — pixel-art-style banners, MOTDs, and room
  illustrations look right under nearest-neighbor.
- **Smoothing-before-quantize amplifies banding**, not reduces it.
  Bilinear / Lanczos producing a smooth gradient gets quantized
  hard into 16 buckets; the result is banded gradients (e.g. a
  blurred edge becomes 4–5 visible bands of different palette
  entries instead of one crisp 2-color boundary). Nearest-neighbor
  + 16-color quantize produces a result that looks like the source
  through a low-resolution filter — visually honest.
- **Cheapest possible cost**. One source-pixel lookup per dst
  pixel, no arithmetic except integer-divide once per pixel pair.
  `docs/benchmarks.md` § v0.6.0 Breakdown shows downscale is ~0.5%
  of total decode time; no further optimization needed.
- **Deterministic byte output**. No floating-point arithmetic, no
  weight-table precomputation, no rounding choices. A given (src,
  dst_w, dst_h) tuple always produces the same RGB triples.
  Important for the "byte-stable across runs" invariant carried
  forward from [ADR 0003](0003-color-tier-discipline.md).
- **Per-color_type extraction lives in one place** (`_extract_rgb`
  in `downscale.cyr`). Bilinear / bicubic would each need to
  understand all 5 color types (greyscale / RGB / palette / grey+alpha
  / RGBA) and average across channel-counts differently. Nearest-
  neighbor sidesteps this entirely — the source pixel is decoded
  to RGB exactly once, no inter-channel weighting.

**Negative**:

- **Photographic source images look blocky** at low terminal sizes.
  A 1920×1080 photo downscaled to 80×48 via nearest-neighbor picks
  3,840 representative pixels out of 2M source pixels — most of the
  visual information is *discarded*, not averaged. For BBS use this
  is fine (the aesthetic matches); for "use kii to preview photos"
  it's wrong (use chafa or viu).
- **Aliasing on high-frequency content**. A checkerboard pattern at
  source-resolution shows moire / aliasing at most dst sizes
  because nearest-neighbor doesn't low-pass-filter. Real images
  rarely have content this pathological; pre-downscale via
  ImageMagick if needed.
- **No anti-aliasing on hard edges**. A diagonal line at source
  resolution stairs-steps visibly under nearest-neighbor at any
  dst size that doesn't share the source's aspect ratio exactly.

**Neutral**:

- **Tier-2 work (post-v1)** revisits this. If users want
  photo-style smoothing, the right shape is `--filter
  {nearest,bilinear,box}` plus `--dither {none,fs,bayer}` together,
  not just a bilinear default. Capturing both together at tier-2
  cycle start.
- **Pixel-aspect ratio handling** is separate from the algorithm.
  kii's geometry helpers (`_kii_compute_target_geometry`,
  `_kii_compute_fit_geometry`) produce a (dst_w, dst_src_rows) pair
  where dst_src_rows is 2× terminal_rows (because half-block — see
  [ADR 0004](0004-half-block-floor-glyph.md)). The downscale
  algorithm choice doesn't affect this math.

## Alternatives considered

- **Bilinear interpolation**. Rejected: smoothing-then-quantizing
  amplifies banding (see Consequences § Positive). A bilinear
  pre-pass would need a quantization-aware dither stage afterward
  to look acceptable, which is tier-2 scope per [ADR 0003](0003-color-tier-discipline.md).
- **Box-filter (averaging over source-block)**. Rejected for v1.0
  for the same reason as bilinear; the average-then-quantize result
  is washed-out compared to nearest-neighbor + quantize. Box-filter
  is the right choice for a hypothetical
  `--filter box --dither fs` tier-2 mode where the FS dither
  recovers the apparent detail; useless without the dither
  companion.
- **Bicubic / Lanczos**. Same rejection as bilinear, with an extra
  cost penalty (16-tap kernel per dst pixel). The cost would be ~5%
  of total decode time vs nearest-neighbor's ~0.5%; not worth it
  for the negative aesthetic outcome at 16-color quantization.
- **Two-stage: bilinear downscale to 2× target, then nearest to
  target**. Rejected as overengineering for v1.0 — would require
  the bilinear path anyway, plus a dst-side buffer at 2× the final
  size. Cleaner is to land the full tier-2 toolkit (filters +
  dithers) at v1.1.
- **Per-color_type custom downscale** (e.g. palette PNGs nearest;
  RGB PNGs bilinear). Considered briefly; rejected as
  inconsistency-breeder. A user who renders both palette PNGs and
  RGB PNGs as MOTDs would see them looking visibly different in
  ways that aren't about content. One algorithm at v1.0.

## Trigger for revisit

- Tier-2 cycle start (v1.1). Lands `--filter {nearest,bilinear,box}`
  + `--dither {none,fs,bayer}` together; nearest stays default to
  preserve byte-stability for existing fixtures.
- A first BBS / MUD consumer reports that nearest-neighbor renders
  their MOTD source badly. (Hypothesis: this won't happen for
  pixel-art MOTDs; might happen for photographic splash screens —
  which is then the trigger to ship tier-2.)
- Cross-terminal verification at M8 close uncovers a real-world
  fixture where the nearest-neighbor result looks materially worse
  than `chafa --colors 16` on the same input. Worth lifting the
  chafa algorithm choice (chafa uses an average-pixel-color
  approach via libavif's resampler when available) into kii's
  comparison set.

## References

- [`../../CLAUDE.md`](../../CLAUDE.md) § Domain-specific rules (color-quantization defaults to nearest-RGB)
- [`0003-color-tier-discipline.md`](0003-color-tier-discipline.md) § Consequences (banding amplification)
- [`0004-half-block-floor-glyph.md`](0004-half-block-floor-glyph.md) § geometry interaction
- [`../benchmarks.md`](../benchmarks.md) § v0.6.0 Breakdown (downscale is ~0.5% of pipeline cost)

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**. The v1.6.4 sweep
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)) records three changes:

**1. Tier 2 is not "at v1.1".** § Alternatives and § Trigger for revisit place the tier-2
toolkit at v1.1. The roadmap pins dithering (`--dither none|ordered|fs`) to 1.9.0. A
`--filter` option is not on the roadmap.

**2. The sampling formula misses the last source column and row (finding C-7).**
`sx = (dx × src_w) / dst_w` reaches at most `((dst_w − 1) × src_w) / dst_w`, which on a
downscale is below `src_w − 1`; the same holds for `sy`. Column 0 and row 0 are always
sampled. So an image with a 1-px border shows it on the top and left only. The fix is
pixel-centre sampling, `sx = ((2·dx + 1) × src_w) / (2 · dst_w)`, which stays in bounds and
keeps the identity case. It changes every downscaled frame, so it is pinned to 1.9.0 with
the dithering work rather than shipped in a patch release.

**3. The extraction path changed.** § Decision says each pixel is read through
`_extract_rgb`. Since v1.6.4 `downscale_to_rgb` reads the depth-8 RGBA that the chitra
adapter always supplies on a fast path, with the same `sx` / `sy` and the same bytes;
`_extract_rgb` serves the other colour types, which only tests reach. Both paths now
composite alpha over black (`_over_black`, `(c·a + 127) / 255`) instead of dropping it, so
opaque images are byte-identical and a transparent pixel renders black
([ADR 0006](0006-adopt-chitra-decoder.md) amendment).

## Amendment — v1.7.0 (the format-neutral rename)

The names this ADR uses were renamed at v1.7.0 (the format-neutral rename, roadmap 1.7.0),
with every numeric code unchanged and behaviour byte-identical (the rename alone compiles to
the same binary):

| through v1.6.4 | since v1.7.0 |
|---|---|
| `src/png.cyr` | `src/image.cyr` |
| `kii_decode_png` | `kii_decode_image` |
| `png_color_type_name` | `kii_source_type_name` |
| `PNG_OK` / `PNG_ERR_*` | `IMG_OK` / `IMG_ERR_*` |
| `PNG_ERR_HEADER` (4) | `IMG_ERR_MALFORMED` |
| `PNG_ERR_CHUNK` (6) | `IMG_ERR_TRUNCATED` |
| `PNG_ERR_TRUNCATED` (2, reserved) | `IMG_ERR_SHORT_FILE` (reserved) |
| `PNG_ERR_NOT_PNG` (3) | `IMG_ERR_UNRECOGNIZED` |
| `PNG_ERR_NO_IDAT` (9) | `IMG_ERR_NO_IMAGE_DATA` |
| `PNG_ERR_INFLATE` (10) | `IMG_ERR_DECOMPRESS` |
| `PNG_ERR_IDAT_TOO_LARGE` (13) | `IMG_ERR_MEMORY` |

Every other `PNG_ERR_X` is now `IMG_ERR_X`. The text above keeps the names it was written with.

`_extract_rgb` and its per-colour-type dispatch are gone too (R-2 of the v1.6.4 sweep):
chitra has handed kii RGBA8 for every format since v1.2.0, so `downscale_to_rgb` now reads
RGBA8 directly and refuses any other pixel format. The resampling rule this ADR chose —
nearest-neighbour, `sx = dx·W / dst_w` — is unchanged; pixel-centre sampling is still
pinned to 1.9.0.

## Amendment — v1.9.0 (pixel-centre sampling, dithering)

This ADR remains **Accepted**: the downscale is still nearest-neighbour, one source pixel
per destination pixel. v1.9.0 changes which pixel that is, and lands the dithering that
§ Neutral and § Trigger for revisit expected with tier 2.

**1. Pixel-centre sampling (C-7, fixed).** Each destination pixel covers the source span
`[dx·W / dst_w, (dx+1)·W / dst_w)`. kii now samples the pixel at the span's centre:

```
sx = ((2·dx + 1) × W) / (2 × dst_w)
sy = ((2·dy + 1) × H) / (2 × dst_h)
```

- **Through v1.8.0 it sampled the span's start.** That shifted every downscaled frame up and
  to the left by half a span (five source pixels at 10:1). A downscale never read the last
  source column or row, so a 1-px border showed on the top and left only.
- **Now the offset is at most half a source pixel.** A centre that falls exactly between two
  pixels takes the right / lower one.
- **The identity case and integer upscales sample exactly as before.** Both formulas give
  `⌊dx / k⌋` for a k× upscale.
- **The formula stays in bounds.** `dx ≤ dst_w − 1` gives `sx ≤ W − W / (2·dst_w) < W`.

**2. The byte-stability cost.** Every downscaled frame changes at 1.9.0, the second
deliberate break after v1.8.0's ([0010](0010-tier-2-colour-and-emit-encoding.md)):

- Over the 466-image corpus, 2,504 of 2,504 rendered frames changed. The 292 unchanged ones
  were all decode rejections.
- A build of v1.8.0 with only this formula changed gives the same bytes as v1.9.0 on all
  2,796 frames, so sampling is the only source of the change.
- Identity scales and integer upscales of the 16×16 and 8×8 fixtures are byte-identical.

**3. Dithering landed without `--filter`.** `--dither none|ordered|fs` arrived at 1.9.0 as
its own decision ([0011](0011-dithering.md)), applied after this downscale. The
`--filter {nearest,bilinear,box}` this ADR paired it with is not on the roadmap.
Nearest-neighbour stays the only resampler. A box filter with `--dither fs` (§ Alternatives)
remains the obvious next step if a consumer asks for photographic output at tier 1.

## Amendment — v1.11.0 (the ASCII lane samples areas)

This ADR remains **Accepted** for the half-block lane, which still reads one source pixel per
destination pixel. The ASCII lane no longer uses it: since v1.11.0 each of its sub-samples is
the mean over the source span it covers (`downscale_area_to_rgb`).

**1. Why the box-filter rejection does not carry over.** § Alternatives rejects a box filter
because averaging before a 16-colour quantize washes the colour out. The ASCII lane does not
quantize its sub-samples. It matches their luminance against glyph coverage, and colours each
cell with the mean of its six samples, which was already an average. With one point per
region, the match depended on where the point landed:
- a 2 px line in a 5 px span was either caught at full strength or missed outright;
- a run of cells along a thin horizontal or vertical line could lose it entirely;
- the centre rule's tie-break (right and down) made the two diagonals of an X render
  differently.

[ADR 0007](0007-rendering-mode-taxonomy.md) § v1.11.0 amendment has the measures.

**2. The rule.** Per axis, the span of destination i is the source pixels whose centres lie in
`[i·W / n, (i+1)·W / n)`; its first pixel is `(2·i·W + n − 1) / (2·n)`.
- **A span of at most `KII_AREA_TAPS` (4) pixels is read whole,** so up to about a 4× reduction
  the mean is exact and each source pixel is read once.
- **A longer span takes 4 evenly spaced taps,** the centre samples of a 4×-finer grid
  (`((2·(i·4 + j) + 1)·W) / (8·n)`). So no sample reads more than 16 pixels, and the cost
  stays proportional to the output, as nearest-neighbour's is. Averaging every pixel was
  measured first. It cost +12 % to +25 % on 6–16 MP images, against +0.1 % to +1.2 % with
  taps, and the two pick the same glyph in 97.5 % of cells.
- **A span with no pixel centre** (an axis being enlarged) takes the centre sample of the
  v1.9.0 amendment.
- **With no reduction on either axis** every span holds at most the pixel its centre lies on,
  so the result is nearest-neighbour's exactly, and the sampler hands the frame to
  `downscale_to_rgb`. Every enlarged ASCII frame is byte-identical to v1.10.0.

**3. Transparency.** A sample is transparent only when none of its pixels is opaque. Its colour
is the mean of the opaque pixels. Its luminance is the mean over all of them, with transparent
ones counted as 0, so a stroke on a transparent background reads at its real coverage. The
sampler writes that luminance plane itself (pstruct +40); `emit_ascii_shape` builds one only
when the slot is 0.

**4. Exact integers.** The colour means round half up. The luminance floors, as `_ascii_luma`
does, so a one-pixel span gives the point lane's value. aarch64 frames match x86_64's.

## Amendment — v2.3.0 (tap counts per axis)

This ADR remains **Accepted**. The area sampler takes its tap counts per axis:
`downscale_area_taps(pstruct, w, h, kx, ky)` reads a span of up to `kx` pixels across, or
`ky` down, whole, and takes that many evenly spaced taps over a longer one.
- **`downscale_area_to_rgb` is the same function at `KII_AREA_TAPS` (4) both ways.** ASCII
  frames are byte-identical to 2.2.0.
- **The Braille lane samples each dot at 16 × 8** ([ADR 0013](0013-braille-lane.md)). That
  is the density at which the blocks lane reads a cell: 8 × 8 samples of up to 4 × 4 taps
  each, 32 × 32 taps a cell, which is 16 × 8 per Braille dot.
