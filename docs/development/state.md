# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**1.1.0** — Unreleased. **CLI re-fold: adopted the `cmdit` distlib** (the stdlib flags
parser productized + extended) — dropped the hand-rolled parsing + `build_argv_array` +
`KII_ARGV_MAX`; now `cmdit_new`/`cmdit_parse`/`cmdit_get_*`/`cmdit_positional` with auto
`--help`/`--version`. kii is cmdit's **first consumer** (validates the extraction). Stdlib
`flags` dropped (`args` kept). Tests rewired. See `agnosticos/docs/development/planning/cmdit.md`.

**1.0.1** — toolchain + dependency refresh — 2026-06-18. (v1.0.0 M8 freeze closeout was 2026-05-23.)

## Toolchain

- **Cyrius pin**: `6.2.22` (in `cyrius.cyml [package].cyrius`). `lib/` re-vendored from the 6.2.22 stdlib snapshot at 1.0.1.

## Surface

Full PNG → terminal-fit ANSI half-block frame pipeline (unchanged at the user-facing layer from v0.7.0):

- `kii image.png` in a TTY → detects terminal cols × rows via `tty_winsize(1)`, fits the image into `cols × (rows - 1)` aspect-preservingly, emits a frame sized to that envelope on stdout. Exit 0.
- `kii image.png > out.ansi` (non-TTY) → falls back to 80×24 BBS-default; identical frame shape regardless of where stdout lands.
- `kii --width N image.png` → exactly N cells wide; height aspect-derived without a row cap.
- `kii --verbose image.png` adds the M4-shape summary line to **stderr** after the frame.
- Missing IEND → frame + stderr warning + exit 0 (per spec § 5.3 tolerance).
- **M7(c) new rejection paths**:
  - `PNG_ERR_DIMENSIONS` (12) — image dimensions exceed kii policy ceiling (max 4096×4096, 256 MB raw)
  - `PNG_ERR_IDAT_TOO_LARGE` (13) — accumulated IDAT > 256 MB
  - `PNG_ERR_RATIO_TOO_HIGH` (14) — DEFLATE ratio > 1100:1 (above theoretical 1032:1 ceiling)
  - Plus duplicate-PLTE / PLTE-after-IDAT rejected as `PNG_ERR_HEADER`
  - Plus color_type=3 + bit_depth=16 rejected as `PNG_ERR_BITDEPTH` (PNG § 11.2.2 violation)
- **M7(c) stderr hardening**: filenames containing C0 control bytes or DEL are substituted with `<path containing control bytes — suppressed>` before stderr emit; CVE-2021-25743-analog injection vector closed.

Module map:

- `src/main.cyr` — I/O glue + dispatch. Two-path geometry resolver (`--width N` → M6(a); else `tty_winsize`-detect → M6(b) fit). M7(c) added `_eprint_path_safe` helper routing path bytes through the sanitizer.
- `src/cli.cyr` — CLI parse helpers + `KII_F_*` indices. M7(c) added `kii_path_has_control_bytes(path)` predicate (ANSI-injection defense).
- `src/png.cyr` — PNG decoder: signature, IHDR, CRC32, chunk walker, PLTE, sankoch zlib_decompress, filter undo. 18-slot pstruct layout (160 bytes). M7(c) added KII_MAX_PIXELS / KII_MAX_DIM / KII_MAX_RAW_BYTES policy ceilings, 3 new `PNG_ERR_*` codes, dimension/ratio/IDAT-accumulator caps, duplicate-PLTE + PLTE-after-IDAT rejection.
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — Two surfaces: M4 image-wide `quantize_nearest_image` (kept for test coverage of per-color_type extraction) + M5+ `quantize_rgb_buf` / `quantize_downscaled` (production pipeline).
- `src/downscale.cyr` — Nearest-neighbor RGB resampler with per-color_type extraction. Variable target size (called as `downscale_to_rgb(pstruct, target_w, target_src_rows)`).
- `src/emit.cyr` — Half-block ANSI emit + geometry primitives (`_kii_compute_target_geometry` for explicit-width, `_kii_compute_fit_geometry` for terminal-fit). Default constants `EMIT_DEFAULT_COLS = 80` / `EMIT_DEFAULT_ROWS = 24`. Local `_emit_bg_256_buf` while darshana's BG-256 twin isn't shipped.
- `tests/kii.tcyr` — **471 assertions** (+45 from v0.7.0: 24 path-sanitizer, 16 dimension/cross-product caps, 2 ratio, 2 chunk-ordering FSM, 1 IEND-length-zero per-chunk cap).
- `tests/kii.fcyr` — **five fuzz surfaces** at **3,011,000 total iters**: arg-parser (10k), path-sanitizer (1M), geometry (1M), emit-pipeline (1k), png-decoder (1M, scaled from 2k).
- `tests/kii.bcyr` — **seven benches**: M4 quantize + M5/M6 end-to-end RAMGON (3 sizes) + M7 decode-latency matrix (3 source resolutions).
- `tests/fixtures/RAMGON.png` — real-world fixture (1152×925 RGBA, ~2 MB). Moved from top level to curated fixtures dir at M8(b1).

## Binary size

Build: ~145 KB at v0.8.0 (unchanged from v0.7.0; compiler still reports ~430 unreachable fns DCE-eliminable). M7(c) hardening commits are small additive changes; no new modules.

## Tests + bench

- `cyrius test` → **471 assertions, all pass** (was 426 at v0.7.0; +45: 24 path-sanitizer, 16 dimension/cross-product caps, 2 compression-ratio, 2 chunk-ordering FSM, 1 IEND-length-zero per-chunk cap from M8(b2)).
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → **3,011,000 iters in ~16.4 s, all clean**. Surfaces: 10k arg-parser + 1M path-sanitizer + 1M geometry + 1k emit-pipeline + 1M PNG-decoder.
- Bench (see [`docs/benchmarks.md`](../benchmarks.md)):
  - `quantize_nearest_rgb @ 1024×1024`: **268 ns/op** (v0.7.0: 269 ns; noise)
  - `end-to-end RAMGON.png → 80×24 frame`: **752 ms/iter**
  - `end-to-end RAMGON.png → 120×40 frame`: **751 ms/iter**
  - `end-to-end RAMGON.png → 200×60 frame`: **756 ms/iter**
  - **M7(d) decode-latency matrix** (DoS-bound):
    - `png_decode 256² class` (archlinux-logo 256×256, palette): **1.8 ms**
    - `png_decode 1024² class` (starfield 1597×1198, RGB): **647 ms**
    - `png_decode 2048² class` (elarun-bg 2560×1600, RGB): **474 ms**
    - Per-pixel decode throughput is content-dependent (compression-ratio-driven), not strictly size-dependent.

## Dependencies

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`, `sankoch`, `thread` (no deltas vs v0.6.0).
- **External**: `darshana 0.7.1` (pinned; bumped from 0.5.3 at 1.0.1). M6 uses `tty_winsize` (darshana v0.3.0+) in addition to the M5 ANSI primitives; the BG-256 twin is still absent from darshana's surface, so kii keeps the inline `_emit_bg_256_buf`.

## Cycle context

v1.0.0 ships during agnos kernel cycle **1.32.x networking-arc**. kii lands as substrate for the BBS / MUD apps that are downstream cycles (ideated but not yet built); v1.0 freeze is explicit about NOT bundling consumer integration with the substrate ship.

## Next

**v1.x — Tier-2 (post-v1)**. Sub-bites (not yet scoped to milestones):

- `--color 256` and `--color tc` modes (truecolor SGR emit).
- Floyd-Steinberg + ordered-Bayer dithering as `--dither` choices.
- `--filter {nearest,bilinear,box}` selection.
- JPEG decoder (likely v1.2.0).
- Re-render the chafa visual-review fixture set (deferred from M8) once chafa is installed in the dev environment.
- Cross-terminal verification (Linux console / xterm / Alacritty / kitty / tmux) on a wider terminal set.
- Three sankoch upstream items (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers) — file as sankoch issues; track impact.

**Carry-forward debt at v1.0**: chafa visual review (`docs/audit/chafa-comparison-deferred.md`), cross-terminal verification, marketplace recipe in zugot, three sankoch upstream items. None block the v1.0 tag; documented for v1.x pickup.

**v2.0 horizon**: Tier-3 — Sixel / Kitty / iTerm2 inline-image protocols. Major-version cut depending on CLI surface impact.
