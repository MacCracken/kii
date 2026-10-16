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

## v0.8.0 — M7 decode-latency matrix (DoS-bound)

Host: x86_64 Linux, single-core wall-clock via `clock_gettime`. Cyrius `6.0.1`.
Acceptance criterion (docs/development/roadmap.md § M7): capture decode
latency across small / medium / large source resolutions to establish
the DoS-relevant worst-case timing envelope. Decode-only — isolates
`png_decode_structure + png_decode_pixels` from M5 pipeline cost.

| Bench | Source | Pixels | Iterations | Per-op |
|---|---|---:|---:|---:|
| `png_decode (256² class)` | `/usr/share/pixmaps/archlinux-logo.png` (256×256, palette) | 65,536 | 50 | **1.8 ms** |
| `png_decode (1024² class)` | `/usr/share/grub/themes/starfield/starfield.png` (1597×1198, RGB) | 1,913,206 | 20 | **647 ms** |
| `png_decode (2048² class)` | `/usr/share/sddm/themes/elarun/images/background.png` (2560×1600, RGB) | 4,096,000 | 10 | **474 ms** |

**Surprise**: the 2048² class is **faster** than the 1024² class
(474 ms vs 647 ms), despite carrying 2.1× the pixel count. The 1024²
fixture (starfield) is more visually complex → harder DEFLATE
compression → larger relative IDAT → slower per-pixel inflate
throughput. The 2048² fixture (a flat-gradient sddm background)
compresses tighter and inflates faster despite being bigger.
**Per-pixel decode throughput is content-dependent**, not strictly
size-dependent.

**Absolute upper bound at v0.8** is set by the M7(c) Finding 1 caps:
`KII_MAX_PIXELS = 16,777,216` (4096²) and `KII_MAX_RAW_BYTES = 256 MB`.
Any PNG breaching these is rejected at IHDR-validation with
`PNG_ERR_DIMENSIONS` before any inflate or allocation. Extrapolating
from the starfield-class throughput (~340 ns/pixel), worst-case
4096²-class decode lands near **5–6 s** — well outside an attacker's
useful DoS window, and bounded.

**Implication**: future bench work would benefit from a multi-fixture
sample per resolution class (flat gradient + high-entropy photo) to
capture both content extremes per size class.

## v0.8.0 — fuzz coverage (M7(b))

Fuzz harness (`tests/kii.fcyr`) scaled to **3,011,000 iterations
total** across five surfaces, all clean in **~16.4 s wall-clock**:

| Surface | Iterations | Surface tested |
|---|---:|---|
| arg-parser | 10,000 | `kii_register_flags` + `flags_parse` against random argv |
| **path-sanitizer** | **1,000,000** | `kii_path_has_control_bytes` against random byte paths |
| **geometry** | **1,000,000** | `_kii_compute_target_geometry` + `_kii_compute_fit_geometry` against random dims |
| **emit-pipeline** | **1,000** | `downscale_to_rgb` → `quantize_downscaled` → `emit_halfblock_row_buf` against random target dims on a real PNG |
| **png-decoder** | **1,000,000** | `png_decode_structure` against random bytes (50% prefixed with valid sig+IHDR) |

All five report zero crashes / contract violations.

## v1.5.1 — P-1 re-baseline + the real hotspot

Host: x86_64 Linux, Cyrius `6.5.35`, chitra `1.0.0`, measured timer floor
1.33 µs (subtracted from every sample). Re-run because a dependency audit
had speculated the 6.5.x toolchain removed a bench instrument — **it did
not**; every bench reproduces within noise of its recorded value.

| Bench | Iterations | v1.5.1 | Previously recorded | Delta |
|---|---:|---:|---:|---|
| `quantize_nearest_rgb @ 1024×1024` | 1,048,576 | **276 ns** | 269 ns | noise |
| `end-to-end RAMGON.png → 80×24` | 50 | **660 ms** | 761 ms | −13 % (toolchain) |
| `end-to-end RAMGON.png → 120×40` | 30 | **662 ms** | 769 ms | −14 % |
| `end-to-end RAMGON.png → 200×60` | 20 | **666 ms** | 771 ms | −14 % |
| `png_decode (256² class)` — archlinux-logo | 50 | **2.17 ms** | 1.8 ms | +20 % |
| `png_decode (1024² class)` — starfield | — | **SKIPPED** | 647 ms | fixture absent |
| `png_decode (2048² class)` — elarun 2560×1600 | 10 | **484 ms** | 474 ms | noise |

### The 1024² row was silently vanishing

`tests/kii.bcyr` guards each system-fixture bench with
`if (kii_decode_png(path, &probe) == PNG_OK) { ... }` and had **no else**.
`/usr/share/grub/themes/starfield/starfield.png` no longer ships on this host,
so that row simply disappeared from the output while this document went on
quoting `647 ms` for it — a number nobody could reproduce and nothing flagged.
All three guarded benches now print an explicit `SKIPPED: fixture not present
on this host` line. A benchmark that can vanish is worse than one that fails.

### Where the time actually goes

Stage-splitting the end-to-end render (RAMGON 1152×925 → 80×24) puts
**~93 % of wall-clock inside `sankoch`'s Huffman decoder**, not in kii at all.
`_huff_decode` (`lib/sankoch.cyr` ~:1205-1215) nests its symbol scan inside the
bit-length loop and rescans from the first symbol at every code length, making
it O(bits × num_symbols) where the canonical
`mincode`/`maxcode`/`valptr` form is O(bits). A drop-in replacement was measured
at **~3.7× end-to-end** with byte-identical output.

kii's own three stages — downscale, quantize, emit — are collectively **under
2 %** of the render. Concretely: the output cell count grows 6.25× from 80×24 to
200×60 and wall-clock moves ~1 %, which is the same observation the v0.7.0 entry
made and the reason its "Implication" line still points the right way.

**Implication**: there is no meaningful latency work available *inside kii*.
The one high-value optimization is upstream in `sankoch`, and it is filed there
(see `docs/development/state.md` § Upstream items). Optimizing kii's resampler
or quantizer would be tuning 2 % of the problem. This entry exists so nobody
spends a cycle on that.

## v1.6.0 — toolchain 6.6.2 → 6.7.9

Host: x86_64 Linux, Cyrius `6.7.9` (sankoch 2.8.3 in the stdlib), chitra `1.0.3`.
⚠ **Measured on a loaded host** — load average 5–7 from unrelated concurrent jobs
throughout — so the v1.5.2 binary (Cyrius 6.6.2, built from the committed v1.5.2
`lib/`) was run in the same session, interleaved with the new one, rather than
compared against the v1.5.1 table above. Each figure is one full `kii-bench` run.

| Bench | v1.6.0 (3 runs) | v1.5.2 (2 runs, same session) |
|---|---:|---:|
| `quantize_nearest_rgb @ 1024×1024` | 302 / 307 / 301 ns | 289 / 299 ns |
| `end-to-end RAMGON.png → 80×24` | 768 / 786 / 765 ms | 682 / 724 ms |
| `end-to-end RAMGON.png → 120×40` | 776 / 791 / 754 ms | 687 / 737 ms |
| `end-to-end RAMGON.png → 200×60` | 762 / 806 / 759 ms | 687 / 747 ms |
| `png_decode (256² class)` — archlinux-logo | 2.35 / 2.50 / 2.32 ms | 2.18 / 2.52 ms |
| `png_decode (1024² class)` — starfield | SKIPPED | SKIPPED |
| `png_decode (2048² class)` — elarun 2560×1600 | 493 / 550 / 497 ms | 483 / 527 ms |

**Reading**: end-to-end is roughly **5–15 % slower** at 6.7.9, inside a noise band
this host could not narrow. It is not kii's code: the only hot-path source change is
the background escape moving to darshana's `tty_bg_256_buf`, which issues 2–3 wide stores
per escape where the composer it replaced issued 9–11 single-byte ones, and the render is still ~93 %
sankoch's Huffman decoder (§ v1.5.1). The difference arrives with the toolchain —
the compiler and the stdlib it vendors, sankoch included — and is recorded so the
next pin bump has a same-session baseline to compare against. Re-measure on an idle
host before drawing a finer conclusion.

## v1.6.3 — toolchain 6.7.9 → 6.7.12

Host: x86_64 Linux, 16 cores, Cyrius `6.7.12` (sankoch **2.8.7** in the stdlib), chitra
`1.2.0`. ⚠ **Measured on a loaded host**: the load average was 7–11 during the runs, with a
fuzz run and other jobs alongside. So the v1.6.2 binary (Cyrius 6.7.9, sankoch 2.8.3) was
run in the same session, interleaved with the new one, three rounds each. Each figure is
one full `kii-bench` run.

| Bench | v1.6.3 (3 runs) | v1.6.2 (3 runs, same session) |
|---|---:|---:|
| `quantize_nearest_rgb @ 1024×1024` | 324 / 295 / 334 ns | 305 / 340 / 280 ns |
| `end-to-end RAMGON.png → 80×24` | **233 / 206 / 214 ms** | 777 / 839 / 723 ms |
| `end-to-end RAMGON.png → 120×40` | **240 / 205 / 204 ms** | 793 / 802 / 748 ms |
| `end-to-end RAMGON.png → 200×60` | **245 / 207 / 208 ms** | 863 / 814 / 767 ms |
| `png_decode (256² class)` — archlinux-logo | **1.40 / 1.19 / 1.17 ms** | 2.56 / 2.42 / 2.56 ms |
| `png_decode (1024² class)` — starfield | SKIPPED | SKIPPED |
| `png_decode (2048² class)` — elarun 2560×1600 | **451 / 370 / 375 ms** | 536 / 516 / 507 ms |

**Reading**: end-to-end render is about **3.5× faster** (723–863 ms → 204–245 ms), and
the 256² PNG decode about 2×. None of it is kii's code: the only source changes in 1.6.3
are a version literal and two comments. With chitra held at 1.1.3, the 6.7.12 compiler
alone builds byte-identical binaries to 6.7.9. The gain is the stdlib's sankoch moving
2.8.3 → 2.8.7. **sankoch 2.8.6 replaced `_huff_decode`'s slow path**, the
O(bits × num_symbols) nested scan that § v1.5.1 measured as ~93 % of the render, with
canonical count/offset decoding (as zlib's `puff.c` does). § v1.5.1 predicted ~3.7× for
exactly that change. The 2048² decode improves less (~20–30 %), consistent with a large
photo spending more of its time outside the Huffman slow path. Quantize is unchanged within
noise, as expected: it never touches sankoch.

## v1.6.4 — the P(-1) sweep's speedups

Same host and toolchain as § v1.6.3 (Cyrius `6.7.12`, sankoch 2.8.7, chitra
`1.2.0`), load average 3–8. The v1.6.3 binary was run interleaved with the new one,
two rounds of `kii-bench` each, then 200 whole-process runs per row on a 256² icon
(`/usr/share/pixmaps/kitty.png`), where kii's own stages are most of the work.

| Bench | v1.6.4 | v1.6.3 (same session) |
|---|---:|---:|
| `quantize_nearest_rgb @ 1024×1024` | **74 / 71 ns** | 517 / 289 ns |
| `end-to-end RAMGON.png → 80×24` | 213 / 202 ms | 213 / 203 ms |
| `end-to-end RAMGON.png → 120×40` | 210 / 200 ms | 208 / 199 ms |
| `end-to-end RAMGON.png → 200×60` | 209 / 203 ms | 212 / 202 ms |
| `png_decode (256² class)` — archlinux-logo | 1.19 / 1.18 ms | 1.21 / 1.14 ms |
| `png_decode (2048² class)` — elarun 2560×1600 | 383 / 370 ms | 396 / 369 ms |
| icon 256², `--width 200`, whole process | **7.65 / 7.67 ms** | 16.6 / 16.8 ms |
| icon 256², `--mode ascii --width 200`, whole process | **11.5 / 11.5 ms** | 22.8 / 22.9 ms |
| icon 256², default 80×24, whole process | **3.73 / 3.74 ms** | 4.27 / 4.27 ms |

**Reading**: quantize is ~4× faster (the first v1.6.3 run's 517 ns is an outlier; 289
ns is typical) from reading the packed palette inline (O-1). Large-PNG renders do not
move, because kii's own stages are 0.6 % of a RAMGON render; the time is chitra's
decode, ~83 % of it sankoch's inflate. Small images are where it shows: an icon at
`--width 200` renders ~2.2× faster, ~2× in ASCII mode (O-1 plus the matcher's exact
early exit, O-3), and ~13 % faster at the default size. Output is byte-identical for
every opaque image (`docs/audit/2026-10-15-audit.md` § 3, P-12).
