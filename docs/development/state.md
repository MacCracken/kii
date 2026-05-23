# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.4.0** — M3 (PNG pixel decode) closeout — 2026-05-22.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

Full PNG pixel decode pipeline working end-to-end:

- `kii image.png` → `<path>: <W>x<H> decoded <N> pixels (<color_type_name>)` to **stdout** + exit 0 (CRC-clean, supported PNG).
- Missing IEND → same stdout line + a stderr warning + exit 0 (per spec § 5.3 tolerance).
- New M3 error paths (all stderr + exit 1, distinct messages):
  - `interlaced PNGs (Adam7) not supported in v0.x`
  - `unsupported bit depth or color type (tier-1: 8/16-bit only)`
  - `no IDAT chunks (nothing to decode)`
  - `DEFLATE decompression failed (corrupt IDAT)`
  - `invalid PNG filter type (spec § 9 allows 0–4)`
- M2 error paths unchanged: `cannot open file` / `not a PNG` / `malformed PNG header` / `CRC check failed` / `malformed PNG (chunk truncated after IHDR)`.
- CLI surface from v0.2.0 unchanged: `--help` / `--version` / `--width N` / `--color N` / positional `<image.png>`.

Module map:

- `src/main.cyr` — I/O glue: `print_version`, `print_usage`, `_eprint`, `_eprint_path_msg`, `_print_pixel_summary` (stdout, M3 shape), `build_argv_array`, `main` + PNG dispatch (structure → pixels).
- `src/cli.cyr` — testable CLI bits: `KII_EXIT_*` codes, `KII_F_*` flag indices, `kii_register_flags(fs)`, `kii_validate_color(c)`.
- `src/png.cyr` — PNG decoder. Public API: `png_check_signature`, `png_validate_file_signature`, `png_read_u32_be`, `png_crc_init`, `png_crc32`, `png_decode_header`, `png_decode_structure`, `png_decode_pixels`, `png_color_type_name`.
- `src/test.cyr` — test entry routing.
- `tests/kii.tcyr` — 163 assertions across smoke + `kii_validate_color` + flag-parse + PNG signature/IHDR/CRC32/walker + sankoch round-trip + interlace + IDAT accumulation + Paeth predictor + per-filter undo + end-to-end pixel decode + Adam7/sub-byte rejection + RAMGON.png real-world.
- `tests/kii.fcyr` — two fuzz surfaces: 10k arg-parser iters + 2k PNG-decoder iters (PNG fuzz now exercises the full inflate + filter-undo path when random bytes happen to look like valid IDATs).
- `tests/kii.bcyr` — still a no-op stub (wires at M4 per roadmap).
- `RAMGON.png` — top-level fixture (1152×925 RGBA, ~2 MB). Real-world end-to-end target.

## Binary size

Build: ~135 KB at v0.4.0 (compiler reports 403 unreachable fns / 116 KB DCE-eliminable, dominated by sankoch's encoder + format wrappers we don't yet use). Set `CYRIUS_DCE=1` to trim. Substantial growth from v0.3.0's ~50 KB driven by sankoch DEFLATE machinery.

## Tests

- `cyrius test` → **163 assertions, all pass** (was 88 at v0.3.0; was 36 at v0.2.0; was 2 at v0.1.0).
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → 10k arg-parser iters + 2k PNG-decoder iters in ~0.07 s on x86_64 Linux. Exit 0.
- Real-world smoke (manual): RAMGON.png (1152×925 RGBA) → 1,065,600 pixels; archlinux-logo.png (256×256 palette) → 65,536 pixels; kitty.png (256×256 RGBA) → 65,536 pixels. All exit 0.

## Dependencies

Direct (declared in `cyrius.cyml [deps]`):

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`, **`sankoch`**, **`thread`** (last two added at v0.4.0 / M3 — `thread` is sankoch's transitive dep for mutex primitives).
- **External**: still none. Pending dep gate per [`roadmap.md`](roadmap.md):
  - `darshana` — added at v0.6.0 (ANSI emit primitives).

## Consumers (planned, not yet integrated)

Unchanged from v0.3.0:

- **BBS server** (TBD, agnosticos planned-repo) — MOTD / login banner ANSI art
- **MUD server** (TBD, agnosticos planned-repo) — room-description illustration art
- **End-user shells** — image preview / demo flair
- **`iam`** — possibly, for richer login splash art (TBD per `iam` minimalism principle)

No consumers yet — pre-MVP.

## Cycle context

v0.4.0 close lands during agnos kernel cycle **1.32.x networking-arc**. Strategic relevance unchanged: BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

M4 — 16-color ANSI palette + RGB→nearest quantization (v0.5.0). Adds `src/palette.cyr` (Linux console 16-color palette) + `src/quant.cyr` (`quantize_nearest(pixels, w, h) → palette_indices[]`). For color_type=3 (palette) input, M4 ALSO handles PLTE → RGB lookup so quantization sees actual colors. No new external deps. First benchmark (`tests/kii.bcyr`) wires at M4 for quantization latency at 1024×1024.
