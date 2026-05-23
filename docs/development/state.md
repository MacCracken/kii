# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.6.0** — M5 (half-block ANSI emit + per-row 256-color escapes) closeout — 2026-05-22.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

Full PNG → 80×24 ANSI half-block frame pipeline:

- `kii image.png` → 24 rows of `▀` (U+2580) glyphs with paired CSI 38;5;N + CSI 48;5;N escapes per character on **stdout** (~40 KB at 80×24); exit 0. Pipe-pure — `kii image.png > frame.ansi` captures just the frame.
- `kii --verbose image.png` adds the M4-shape summary line (`<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color`) to **stderr** after the frame.
- Missing IEND → frame + stderr warning + exit 0 (per spec § 5.3 tolerance).
- M3 / M4 error paths unchanged: Adam7 / sub-byte depth / no-IDAT / DEFLATE-failure / invalid-filter all rejected on stderr + exit 1.
- New M5 error paths: `downscale failed (palette PNG missing PLTE, or OOM)` + `quantization failed (OOM)` + `ANSI emit failed (downscale or quantize not run)` — defensive; should never fire for spec-clean PNGs.
- CLI surface: M1 set + new `-v` / `--verbose` (was reserved in M1's flag indices; activated at M5 alongside the stderr summary). Frozen surface from here through v1.0.

Module map:

- `src/main.cyr` — I/O glue + dispatch (structure → pixels → downscale → quantize → emit). `_print` / `_eprint` / `_eprint_quant_summary` helpers.
- `src/cli.cyr` — CLI parse helpers + `KII_F_VERBOSE`.
- `src/png.cyr` — PNG decoder: signature, IHDR, CRC32, chunk walker, PLTE capture, filter undo, sankoch zlib_decompress. Struct grew from 15 to 18 slots (160 bytes).
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — RGB → 16-color quantization. Added `quantize_rgb_buf` (PNG-agnostic) + `quantize_downscaled` (pstruct-aware wrapper) at M5.
- `src/downscale.cyr` — nearest-neighbor RGB resampler with per-color_type extraction. New module at M5(b).
- `src/emit.cyr` — half-block ANSI emit (`emit_halfblock` to fd 1 + `emit_halfblock_row_buf` for testable buffer composition). New module at M5(c). Local `_emit_bg_256_buf` while darshana's BG twin isn't yet shipped.
- `tests/kii.tcyr` — 382 assertions.
- `tests/kii.fcyr` — two fuzz surfaces (10k arg + 2k PNG). Downscale/emit fuzz surface deferred to M7.
- `tests/kii.bcyr` — two benches: `quantize_nearest_rgb @ 1024×1024` (269 ns/op) + `end-to-end RAMGON.png → 80×24 frame` (747 ms/iter).
- `docs/benchmarks.md` — captured per release that lands perf-critical paths.
- `RAMGON.png` — top-level fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: ~145 KB at v0.6.0 (compiler reports 431 unreachable fns / ~121 KB DCE-eliminable; dominated by sankoch's encoder + darshana's termios/cursor modules + transitive thread machinery). Set `CYRIUS_DCE=1` to trim.

## Tests + bench

- `cyrius test` → **382 assertions, all pass** (was 287 at v0.5.0; +38 M5(b) downscale + +57 M5(c) quantize/emit).
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → 10k arg-parser iters + 2k PNG-decoder iters in ~0.07 s. Exit 0.
- Bench: `cyrius build tests/kii.bcyr build/kii-bench && ./build/kii-bench`:
  - `quantize_nearest_rgb @ 1024×1024`: **269 ns/op**
  - `end-to-end RAMGON.png → 80×24 frame`: **747 ms/iter** (50 iters; dominated by `png_decode_pixels` on the 4.26 MB inflated buffer).
- Real-world smoke (manual): RAMGON.png → 40,770 bytes of ANSI on stdout, exit 0. archlinux-logo.png and kitty.png both render cleanly.

## Dependencies

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`, `sankoch`, `thread` (no stdlib deltas vs v0.5.0).
- **External**: **`darshana` 0.5.3** — first external git dep, landed at v0.6.0 / M5. Provides `tty_fg_256_buf` + `tty_sgr_reset_buf` for the half-block emit; the BG-256 twin lives in `src/emit.cyr` locally (extract to darshana on 2nd consumer).

## Cycle context

v0.6.0 close lands during agnos kernel cycle **1.32.x networking-arc**. BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

M6 — terminal-size auto-detect via `ioctl TIOCGWINSZ` + `--width N` override (v0.7.0). Replaces the hardcoded 80×24 in `src/emit.cyr` with a runtime-detected geometry from `darshana`'s `tty_winsize`; fallback chain is `--width N` > detected > 80×24. Doc-debt carry-forward (`docs/architecture/README.md`, `docs/adr/0001-png-decoder-in-repo.md`, `docs/examples/`) targeted for M6 close.
