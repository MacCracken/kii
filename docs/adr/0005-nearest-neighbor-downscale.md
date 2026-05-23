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
