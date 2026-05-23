# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.5.0** — M4 (16-color ANSI palette + RGB → nearest quantization) closeout — 2026-05-22.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

Full PNG → 16-color palette-index pipeline:

- `kii image.png` → `<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color` to **stdout** + exit 0.
- Missing IEND → same stdout line + a stderr warning + exit 0 (per spec § 5.3 tolerance).
- M3 error paths unchanged: Adam7 / sub-byte depth / no-IDAT / DEFLATE-failure / invalid-filter all rejected on stderr + exit 1.
- New M4 error path: `quantization failed (palette PNG missing PLTE, or OOM)` — defensive; should never fire for spec-clean PNGs.
- CLI surface from v0.2.0 unchanged: `--help` / `--version` / `--width N` / `--color N` / positional `<image.png>`.

Module map:

- `src/main.cyr` — I/O glue + dispatch (structure → pixels → quantize). `_print` / `_eprint` helpers.
- `src/cli.cyr` — CLI parse helpers.
- `src/png.cyr` — PNG decoder: signature, IHDR, CRC32, chunk walker, PLTE capture, filter undo, sankoch zlib_decompress.
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — RGB → 16-color quantization (scalar + image-wide; per-color_type pixel extraction).
- `tests/kii.tcyr` — 287 assertions.
- `tests/kii.fcyr` — two fuzz surfaces (10k arg + 2k PNG).
- `tests/kii.bcyr` — wired at M4: `quantize_nearest_rgb` micro-bench at 1M iterations.
- `docs/benchmarks.md` — captured per release that lands perf-critical paths.
- `RAMGON.png` — top-level fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: ~145 KB at v0.5.0 (compiler reports 402 unreachable fns / 115 KB DCE-eliminable, dominated by sankoch's encoder + format wrappers + transitive thread machinery). Set `CYRIUS_DCE=1` to trim.

## Tests + bench

- `cyrius test` → **287 assertions, all pass** (was 163 at v0.4.0; was 88 at v0.3.0).
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → 10k arg-parser iters + 2k PNG-decoder iters in ~0.07 s. Exit 0.
- Bench: `cyrius build tests/kii.bcyr build/kii-bench && ./build/kii-bench` → `quantize_nearest_rgb @ 1024×1024`: **274 ns/op**.
- Real-world smoke (manual): RAMGON.png → 1,065,600 pixels (RGBA); archlinux-logo.png → 65,536 pixels (palette via PLTE); kitty.png → 65,536 pixels (RGBA). All exit 0.

## Dependencies

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`, `sankoch`, `thread` (no deltas vs v0.4.0).
- **External**: still none. Next gate per [`roadmap.md`](roadmap.md):
  - `darshana` — added at v0.6.0 / M5 (ANSI emit primitives for half-block glyphs).

## Cycle context

v0.5.0 close lands during agnos kernel cycle **1.32.x networking-arc**. BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

M5 — half-block (`▀`) glyph emit + per-row ANSI color escapes (v0.6.0). Adds `darshana` as the first external dep. Replaces the M4 summary stdout line with actual ANSI escape sequences sized to a hardcoded 80×24. The quantized buffer at `STRUCT_QUANTIZED_BUF_OFFSET` is the input.
