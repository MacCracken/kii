# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.8.0** — M7 (security audit cycle) closeout — 2026-05-23.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

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
- `tests/kii.tcyr` — **470 assertions** (+44 from v0.7.0: 24 path-sanitizer, 16 dimension/cross-product caps, 2 ratio, 2 chunk-ordering FSM).
- `tests/kii.fcyr` — **five fuzz surfaces** at **3,011,000 total iters**: arg-parser (10k), path-sanitizer (1M), geometry (1M), emit-pipeline (1k), png-decoder (1M, scaled from 2k).
- `tests/kii.bcyr` — **seven benches**: M4 quantize + M5/M6 end-to-end RAMGON (3 sizes) + M7 decode-latency matrix (3 source resolutions).
- `RAMGON.png` — top-level fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: ~145 KB at v0.8.0 (unchanged from v0.7.0; compiler still reports ~430 unreachable fns DCE-eliminable). M7(c) hardening commits are small additive changes; no new modules.

## Tests + bench

- `cyrius test` → **470 assertions, all pass** (was 426 at v0.7.0; +44: 24 path-sanitizer, 16 dimension/cross-product caps, 2 compression-ratio, 2 chunk-ordering FSM).
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
- **External**: `darshana 0.5.3` (pinned). M6 uses `tty_winsize` (darshana v0.3.0+) in addition to the M5 ANSI primitives.

## Cycle context

v0.8.0 close lands during agnos kernel cycle **1.32.x networking-arc**. BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

**M8 — v1.0 freeze (v1.0.0)**. Sub-bites:

- First BBS / MUD downstream consumer integrated and green (likely `bannermanor`'s MOTD path — `kii motd.png | bnrmr` style pipeline).
- Cross-terminal verification: Linux console (`TERM=linux`), xterm-256color, Alacritty, kitty, tmux.
- W3C PNG test-suite "broken" set walked through kii — confirms clean rejection on every malformed-input case from the spec test corpus (carried over from M7(a) deferral).
- Visual review against `chafa --colors 16 --size 80x24 image.png` on a curated 5-image fixtures dir.
- `docs/guides/getting-started.md` + `docs/examples/` backfill (overdue since M5).
- Per-chunk-type length cap table (M7 Finding 6, deferred — libpng CVE-2017-12652 class).
- Three sankoch upstream items filed during M7 — close out as v1.0 release gates.
- Marketplace recipe in zugot; VERSION → 1.0.0; git tag.

**Carry-forward debt cleared at M7**: M7(a) audit doc + M7(b) fuzz coverage + M7(c) hardening + M7(d) bench matrix + ADR 0002. Doc-currency ledger walked at M7(d) close.
