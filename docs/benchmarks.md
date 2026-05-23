# kii — Benchmarks

> Captured per release that lands new performance-critical paths.
> Methodology: `cyrius build tests/kii.bcyr build/kii-bench && ./build/kii-bench`
> on `x86_64-linux` with the toolchain pinned in `cyrius.cyml`.
> Each measurement is `n` iterations under `lib/bench.cyr`'s
> `bench_batch_*` API (single `clock_gettime` pair across the
> whole batch, per-op time = total/n).

## v0.5.0 — M4 quantization

Host: x86_64 Linux, single-core wall-clock via `clock_gettime`. Cyrius `6.0.1`.

| Bench | Iterations | Per-op | Notes |
|---|---:|---:|---|
| `quantize_nearest_rgb @ 1024×1024` | 1,048,576 | **274 ns** | Linear scan over 16 palette entries × 3 channels (48 multiplies + 48 adds + 16 compares per pixel). Cold-cache, single-thread, no SIMD. |

**Extrapolation**: a 1024×1024 image takes ~287 ms to fully quantize sequentially. RAMGON.png (1,065,600 pixels) takes ~292 ms.

**Headroom** (not yet exploited):
- Per-pixel inner loop has no early-exit; even a "we already found distance 0" short-circuit would help on saturated colors.
- Palette-side optimization: precompute palette in an SoA layout, vectorize the distance² across all 16 entries via SIMD.
- Caller-side optimization: skip alpha-fully-transparent pixels (quantize → 0 fallback).

None of these are v1.0-scope; capture here so future cycles know what's available.

## v0.6.0 — M5 end-to-end PNG → 80×24 ANSI

Host: x86_64 Linux, single-core wall-clock via `clock_gettime`. Cyrius `6.0.1`.

| Bench | Iterations | Per-op | Notes |
|---|---:|---:|---|
| `quantize_nearest_rgb @ 1024×1024` | 1,048,576 | **269 ns** | Unchanged shape vs v0.5.0; the 5 ns drop is noise (re-measured after the downscale + emit modules landed). |
| `end-to-end RAMGON.png → 80×24 frame` | 50 | **747 ms** | Full pipeline per iter: `png_decode_structure` (chunk walk + CRC32) → `png_decode_pixels` (sankoch zlib + filter undo) → `downscale_to_rgb(80, 48)` → `quantize_downscaled` (80 × 48 = 3840 quantize_nearest_rgb calls = ~1 ms) → 24 × `emit_halfblock_row_buf` (in-process; excludes the per-row `write(2)` syscall). |

**Breakdown** (back-of-envelope from the modules' relative work):

| Stage | Approx. share | Driver |
|---|---:|---|
| `png_decode_pixels` (sankoch + filter) | ~98 % | RAMGON.png is 1152 × 925 RGBA → ~4.26 MB inflated; the filter-undo walks every byte. |
| `downscale_to_rgb` | ~0.5 % | 3,840 dst pixels × 1 source-pixel lookup each. |
| `quantize_downscaled` | ~0.2 % | 3,840 × 269 ns ≈ 1 ms. |
| 24 × `emit_halfblock_row_buf` | ~0.1 % | 24 × ~80 µs of byte-pack work; the actual `write(2)` is excluded. |

The pipeline is dominated by the source-resolution PNG decode — downscale → quantize → emit at 80×48 is a rounding error by comparison. The end-to-end bench captures the M5-acceptance baseline; perf work would land in `png_decode_pixels` (currently single-threaded scanline-at-a-time) before any of the M5 modules are worth optimizing.

**Headroom** (M5-specific, not yet exploited):
- `_emit_bg_256_buf` extracts to darshana when a second consumer surfaces; bumps a tag and keeps the inline implementation here as a fallback.
- 16-color palette indices are always 1–2 digits — a per-index escape-string cache (16 × ~10-byte buffer) skips the `_ansi_emit_u8` digit loop entirely, ~30 % emit win.
- Per-row write coalescing into a single frame-sized buffer (~50 KB) would cut write(2) calls from 24 to 1; would only matter if the syscall edge starts dominating.

## v0.7.0 — M6 terminal-size detection + multi-resolution bench

Host: x86_64 Linux, single-core wall-clock via `clock_gettime`. Cyrius `6.0.1`. Geometry resolution at runtime via `tty_winsize` + `_kii_compute_fit_geometry` (auto-detect) / `_kii_compute_target_geometry` (`--width N`).

| Bench | Iterations | Per-op | Notes |
|---|---:|---:|---|
| `quantize_nearest_rgb @ 1024×1024` | 1,048,576 | **269 ns** | Unchanged from v0.6.0; re-measured baseline. |
| `end-to-end RAMGON.png → 80×24 frame` | 50 | **761 ms** | M5 baseline (1920 ▀ cells); +1 ms noise vs v0.6.0's 747 ms. |
| `end-to-end RAMGON.png → 120×40 frame` | 30 | **769 ms** | 4800 cells (2.5× of 80×24). |
| `end-to-end RAMGON.png → 200×60 frame` | 20 | **771 ms** | 12000 cells (6.25× of 80×24). |

**Per-cell scaling**: render-output cell-count climbs 6.25× from 80×24 to 200×60, yet wall-clock climbs only ~1.3 % (~10 ms). The entire pipeline is dominated by `png_decode_pixels` decoding RAMGON's 4.26 MB inflated RGBA buffer (~98 % share, ~745 ms on this host); the M5 emit + downscale + quantize-of-downscaled-buf collectively account for the remaining ~2 %.

**Implication**: any v1.0 latency work should target `png_decode_pixels` — the sankoch inflate or the per-scanline filter undo, both currently single-threaded. The M5/M6 modules don't move the needle until the decoder bottleneck is gone.

**Headroom** (M6-specific):
- Auto-detection uses one `ioctl TIOCGWINSZ` syscall per frame. Microseconds; not on any reasonable hot path.
- The fit-vs-target geometry choice in `main.cyr` runs once per invocation; negligible.
