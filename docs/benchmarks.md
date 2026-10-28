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

## v1.7.0 — no performance change

1.7.0 is a rename plus code-health work, with one change on the hot path: both render
lanes now reach their row builder through one indirect call per row (`_kii_emit_frame`,
`callptr`). Checked against v1.6.4 on the same host (load average 7–12, so CPU time rather
than wall clock): a 256² icon at `--mode ascii --width 200` used 2.29 / 2.33 / 2.45 s of
user CPU per 100 runs, against 2.25 / 2.37 / 2.39 s for v1.6.4; at `--width 200` the
half-block lane ran 7.72 / 7.81 ms per run against 7.76 / 7.76 ms. The first interleaved
`kii-bench` round matched v1.6.4 within noise (quantize 69 vs 70 ns; RAMGON 80×24 204 vs
200 ms); a second round was disturbed by load and is not recorded. The v1.6.4 figures stand.

## v1.8.0 — the emit rework: output size per tier

Same host and toolchain; the v1.7.0 binary for comparison. v1.8.0 changes every frame's
bytes (ADR 0010): tier 1 moved to the plain SGR codes, repeated escapes are elided, and
the 256 and truecolour tiers arrived. Output bytes for RAMGON (1152×925):

| frame | v1.7.0 (tier 16) | v1.8.0 tier 8 | tier 16 | tier 256 | truecolour |
|---|---:|---:|---:|---:|---:|
| half-block, `--width 80` | 54,353 | 13,380 | **14,609** | 46,390 | 94,307 |
| ascii, `--width 80` | 25,908 | 5,190 | **5,125** | 19,797 | 40,126 |
| half-block, `--width 200` | 339,051 | 74,350 | **79,044** | 261,091 | 585,568 |
| ascii, `--width 200` | 161,488 | 27,305 | **26,955** | 106,423 | 244,982 |

**Reading**: the default tier's frames are 73–83 % smaller than v1.7.0's; across the
test fixtures and 466 system images (996 tier-8 / tier-16 frames) the total went from
71.99 MB to 10.87 MB (−85 %), with every frame replaying to the same cells (glyph, fg, bg).
The higher tiers cost more because their colours vary more from cell to cell: 256 is ~3×
and truecolour ~6× tier 16. On a 9600-baud line an 80×24 tier-16 frame now takes ~15 s
instead of ~57 s.

CPU per render drops with the output (user time for 50 renders of a 256² icon at
`--width 200`, load average 5–10): half-block tier 16 0.25 s (v1.7.0 0.35–0.42 s), ascii
tier 16 0.39–0.50 s (0.58 s); truecolour 0.19 s and 256 0.22–0.23 s, cheaper than tier 16
because they skip the 16-entry palette search. Large images are unchanged: their time is
chitra's decode.

## v1.9.0 — dithering: output size and CPU per mode

Same host and toolchain, load average ~1; the v1.8.0 binary for comparison, interleaved, two
rounds. `--dither none` is the default, and its frames differ from v1.8.0's only by
pixel-centre sampling (ADR 0005 amendment), which moves sizes by under 2 %. Output bytes for
RAMGON (1152×925):

| frame | v1.8.0 | v1.9.0 none | ordered | fs |
|---|---:|---:|---:|---:|
| half-block, `--width 80`, tier 8 | 13,380 | 13,330 | 20,740 | 21,990 |
| half-block, `--width 80`, tier 16 | 14,609 | **14,553** | 23,222 | 23,753 |
| half-block, `--width 80`, tier 256 | 46,390 | 47,097 | 60,164 | 51,771 |
| ascii, `--width 80`, tier 16 | 5,125 | 5,080 | 8,890 | 8,770 |
| half-block, `--width 200`, tier 16 | 79,044 | 79,633 | 140,243 | 145,686 |
| half-block, `--width 200`, tier 256 | 261,091 | 259,783 | 378,252 | 309,929 |
| ascii, `--width 200`, tier 16 | 26,955 | 27,295 | 53,390 | 55,295 |

Over the 466-image corpus at `--width 60`, against `none`:

| lane / tier | none | ordered | fs |
|---|---:|---:|---:|
| half-block 8 | 6.25 MB | 9.20 MB (×1.47) | 8.49 MB (×1.36) |
| half-block 16 | 6.48 MB | 11.86 MB (×1.83) | 12.12 MB (×1.87) |
| half-block 256 | 8.34 MB | 35.23 MB (×4.22) | 27.80 MB (×3.33) |
| ascii 8 | 2.61 MB | 4.11 MB (×1.57) | 3.71 MB (×1.42) |
| ascii 16 | 2.73 MB | 5.32 MB (×1.95) | 5.38 MB (×1.97) |
| ascii 256 | 4.00 MB | 16.97 MB (×4.24) | 13.50 MB (×3.38) |

**Reading**: dithering costs bytes because escape elision works on runs of one colour, and
a dither pattern is two colours alternating. Tier 256 pays most: its offset (±19) spans
several grey-ramp levels, so a pattern there mixes more distinct codes, each a longer
escape. Even so, a tier-16 `fs` frame stays well under v1.7.0's undithered 54,353 bytes.

User CPU per 50 renders of a 256² icon (`/usr/share/pixmaps/kitty.png`) at `--width 200`,
two rounds:

| frame | v1.8.0 | none | ordered | fs |
|---|---:|---:|---:|---:|
| half-block, tier 16 | 0.238 / 0.247 s | 0.240 / 0.244 s | 0.273 / 0.274 s | 0.332 / 0.327 s |
| half-block, tier 256 | 0.226 / 0.227 s | 0.214 / 0.217 s | 0.262 / 0.256 s | 0.310 / 0.324 s |
| ascii, tier 16 | 0.358 / 0.357 s | 0.356 / 0.368 s | 0.375 / 0.370 s | 0.461 / 0.472 s |

**Reading**: `none` costs what v1.8.0 did in both lanes. Ordered adds ~0.6 ms a render
(one table lookup and three clamps a pixel). `fs` adds ~1.8 ms in half-block and ~2.2 ms in
ASCII: the error rows, and in ASCII the extra pass that computes every cell's mean before
the rows are built. An early draft ran that pass for every mode and made the default ASCII
lane ~19 % slower (0.355 → 0.423 s). It now runs only under `fs`. On RAMGON at
`--width 200` all four are within noise (0.98–1.04 s per 5 renders), because chitra's decode
dominates.

## v1.9.1 — toolchain 6.7.12 → 6.7.18, deps to newest

Host: x86_64 Linux, 16 cores, Cyrius `6.7.18` (sankoch **2.8.9** in the stdlib), chitra
`1.3.1`, darshana `1.6.0`, cmdit `1.5.0`. The v1.9.0 bench (Cyrius 6.7.12, built from
`git archive HEAD` with its vendored `lib/`) ran interleaved with the new one, three rounds
each, at load average 0.3–0.9. Each figure is one full `kii-bench` run.

| Bench | v1.9.1 (3 runs) | v1.9.0 (3 runs, same session) |
|---|---:|---:|
| `quantize_nearest_rgb @ 1024×1024` | 68 / 67 / 67 ns | 69 / 68 / 67 ns |
| `end-to-end RAMGON.png → 80×24` | 192.3 / 192.4 / 192.9 ms | 191.0 / 194.1 / 193.5 ms |
| `end-to-end RAMGON.png → 120×40` | 192.8 / 193.1 / 193.3 ms | 192.9 / 194.2 / 193.6 ms |
| `end-to-end RAMGON.png → 200×60` | 194.0 / 194.1 / 194.1 ms | 194.5 / 195.4 / 195.6 ms |
| `png_decode (256² class)` — archlinux-logo | 1.09 / 1.10 / 1.14 ms | 1.12 / 1.11 / 1.11 ms |
| `png_decode (1024² class)` — starfield | SKIPPED | SKIPPED |
| `png_decode (2048² class)` — elarun 2560×1600 | 359.1 / 359.5 / 359.6 ms | 359.5 / 361.0 / 361.5 ms |

**Reading**: no change. Every row agrees within ~1 %, inside run-to-run noise. None of the
bench fixtures crosses 16 MiB of scanlines, so chitra 1.3.x's in-place unfilter and
single-IDAT inflate save memory here but no measurable time.

**PNGs past 16 MiB** decode for the first time, so they have no v1.9.0 row. Peak RSS and wall
clock for one `kii --width 80` render:

| Input | File | v1.9.1 |
|---|---:|---|
| `tests/fixtures/oversize.png`, 2370² black RGB8 | 16 KB | 41 MB, 0.15 s |
| kitty `screenshot.png`, 3880×2168 RGBA8 | 891 KB | 71 MB, 0.31 s |
| 3000×2000 plasma RGB8 | 9.9 MB | 81 MB, 1.0 s |
| 4096² plasma RGBA16 | 97 MB | 513 MB, 9.7 s |
| 4096² plasma RGBA16, Adam7 | 99 MB | 643 MB, 10.5 s |
| 4096² noise RGBA16, Adam7, padded to 255 MB | 255 MB | 913 MB, 7.2 s |

The last row is the largest file but not the slowest: only 79 MB of it is IDAT, and the
other 176 MB is one ancillary chunk that chitra CRC-checks and skips. Its memory is the
highest because the read alone costs ~517 MB (v1.9.0 paid the same before refusing it). The
worst-case bounds are recorded in [ADR 0002](adr/0002-security-model.md) § v1.9.1 amendment.

## v1.10.0 — the ASCII lane's contrast pass, and the k-d tree that was not taken

Host: x86_64 Linux, 16 cores, Cyrius `6.7.18`, load average 1.1–1.9. CPU per run (user + system),
three interleaved rounds against the v1.9.1 binary, minimum shown:

| Render | v1.9.1 | v1.10.0 | change |
|---|---:|---:|---:|
| `--mode ascii --width 200`, archlinux-logo 256² | 5.26 ms | 5.98 ms | +14 % |
| `--mode ascii --width 200`, RAMGON 1152×925 | 203.9 ms | 207.3 ms | +1.7 % |
| `--mode ascii --width 200`, kitty screenshot 3880×2168 | 324.3 ms | 324.2 ms | 0 |
| `--width 200` (half-block), archlinux-logo | 3.12 ms | 3.12 ms | 0 |

The ASCII cost is the contrast pass and the luminance plane it reads, about 45 ns a cell on the
icon. Decode dominates the larger images. How the first draft's +44 % came down:

| Step | icon, ms/run |
|---|---:|
| v1.9.1 | 5.26 |
| first draft: ten helper calls per cell for the samples around it | 7.65 |
| one luminance plane per frame | 6.69 |
| no call for a value that is its own ceiling or 0 | 6.59 |
| power table built in one sweep (511 steps, was 65,280) | 6.11 |
| the plane's luma written out, mask and no-mask loops apart | 5.93 |

A reciprocal for the step's division by M changed nothing measurable (6.59 → 6.60 ms), and it
stays only because it is exact over the whole domain. The `kii-bench` rows, which never reach
the ASCII lane, match v1.9.1 within 1 % across two interleaved rounds (RAMGON 80×24
197.0–197.6 ms, 2048² decode 367.2–368.4 ms).

**The k-d tree.** Nearest-glyph lookup, exact against the scan, per vector:

| Lookup | 2 M random vectors | 2 M real cells |
|---|---:|---:|
| linear scan with early exit | 331 ns | 203 ns |
| k-d tree, recursive | 444 ns | 233 ns |
| k-d tree, iterative | 803 ns | 449 ns |

The real cells are each sample image's ASCII sampling at 200 × 80 cells, for RAMGON, the kitty
screenshot and the archlinux logo. The tree was not adopted
([ADR 0007](adr/0007-rendering-mode-taxonomy.md) § v1.10.0 amendment).

## v1.11.0 — the ASCII lane's area sampler

Host: x86_64 Linux, 16 cores, Cyrius `6.7.18`, load average 1.0–1.4. CPU per run (user + system),
three to five interleaved rounds against the v1.10.0 binary, minimum shown. "All pixels" is the first
version, which averaged every pixel of every span; v1.11.0 reads a span whole only up to 4
pixels and takes 4 taps beyond ([ADR 0005](adr/0005-nearest-neighbor-downscale.md) § v1.11.0
amendment).

| Render (`--mode ascii`) | v1.10.0 | all pixels | v1.11.0 |
|---|---:|---:|---:|
| archlinux-logo 256², `--width 200` | 5.93 ms | 5.90 ms | 5.96 ms |
| archlinux-logo 256², `--width 80` | 2.46 ms | 2.82 ms | 2.88 ms (+17 %) |
| RAMGON 1152×925, `--width 80` | 201.4 ms | 206.2 ms | 202.9 ms (+0.7 %) |
| RAMGON, `--width 200` | 209.8 ms | 215.3 ms | 216.3 ms (+3.1 %) |
| 3000×2000 BMP, `--width 80` | 101.5 ms | 127.3 ms (+25 %) | 102.7 ms (+1.2 %) |
| kitty screenshot 3880×2168, `--width 80` | 320.4 ms | 360.3 ms (+12 %) | 321.1 ms (+0.2 %) |
| 4000×4000 PNG, `--width 48` | 451.8 ms | 519.2 ms (+15 %) | 452.2 ms (+0.1 %) |
| 3000×2000 BMP, `--width 400` | 132.2 ms | 162.5 ms | 162.0 ms (+23 %) |

- **Each source pixel read costs about 6–7 ns.** The cost follows how many pixels the frame
  reads: all of them up to a 4× reduction, at most 16 per sample beyond. So it is small when
  the image is much larger than the frame, and largest when the frame is wide: at `--width 400`
  every sample reads about 15 pixels.
- **The largest frame the cell cap allows,** `--width 1448` on the 4000 × 4000 PNG, takes
  566 → 701 ms, and the kitty screenshot at that width 490 → 560 ms. Peak RSS is unchanged
  (140.6 MB and, for RAMGON at 80 columns, 18.6 MB).
- **The icon at `--width 200` is enlarged on both axes,** so the sampler hands it to
  `downscale_to_rgb` and it costs nothing. Before that hand-off, the general loop cost +11 %
  there (5.92 → 6.58 ms). A one-pixel fast path inside the loop recovered only 0.1 ms.
- **Not memory-bound.** An inner loop with one 32-bit load per pixel instead of four byte loads
  measured the same (126.9 → 127.3 ms on the BMP).
- **A fixed 4 × 4 supersample** at every geometry cost +0.2–1.2 % on the large images, but +158 %
  on the icon at `--width 200` (15.2 ms), where it read 16 pixels per sample of a 256-pixel
  source. Hence the hybrid: read short spans whole, tap long ones, hand off enlargements.

**`kii-bench`**, two interleaved rounds against v1.10.0. The existing rows, which never reach the
ASCII lane, match within ~1 % (RAMGON 80×24 193.0–195.1 ms against 193.0–197.3; 2048² decode
359.4–359.5 ms against 359.3–373.2, the 373.2 being v1.10.0's first round). The four new rows
downscale a decoded RAMGON to the ASCII lane's grid:

| Sampling | 160 × 96 (80 columns) | 400 × 240 (200 columns) |
|---|---:|---:|
| `downscale_to_rgb`, one point per sample | 0.11 ms | 0.65–0.70 ms |
| `downscale_area_to_rgb` | 1.65 ms | 7.79–7.87 ms |

At 80 columns every span is over 4 pixels, so each sample takes 16 taps. At 200 columns the
spans are about 3 × 4 pixels, so they are read whole and every source pixel is read once.
