# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.7.0] — 2026-05-22

### Added

- **M6 — terminal-size auto-detect + `--width N` override**. `kii image.png` now fills the current terminal aspect-preservingly: stdout-TTY → `tty_winsize(1)`-detected `cols × (rows - 1)`; non-TTY → 80×24 BBS-default fallback. `--width N` (M1-frozen flag, finally consumed) honors the exact width without any row cap — useful for `kii --width 200 img.png > big.ansi` captures.
- **`src/emit.cyr` extensions**:
  - `_kii_compute_target_geometry(src_w, src_h, width_flag, out_dst_w, out_dst_src_rows)` — width-driven aspect-preserving height (used when `--width` is explicit). Formula: `dst_src_h = (src_h × dst_cols) / src_w`, clamped to ≥ 2 (1 terminal row min).
  - `_kii_compute_fit_geometry(src_w, src_h, max_cols, max_rows, out_dst_w, out_dst_src_rows)` — aspect-preserving FIT into a (cols × rows) envelope. Picks width-binding when the aspect-true height fits inside `max_rows`; otherwise switches to row-binding and shrinks the width accordingly. `max_cols ≤ 0` / `max_rows ≤ 0` substitute `EMIT_DEFAULT_COLS` (80) / `EMIT_DEFAULT_ROWS` (24).
- **`src/main.cyr`**: terminal-size detection via darshana's `tty_winsize(1, &rows, &cols)`. Two-path resolver:
  - `--width N > 0` → M6(a) `_kii_compute_target_geometry` (no row cap; user knows what they're doing).
  - `--width 0` (default) → `tty_winsize` succeeds → fit-within `cols × (rows - 1)`; failure → fit-within 80×24.

### Changed

- `src/emit.cyr`: `EMIT_COLS` / `EMIT_ROWS` / `EMIT_SRC_ROWS` (module-scope mutable) → `EMIT_DEFAULT_COLS` / `EMIT_DEFAULT_ROWS` (immutable fallbacks). `EMIT_SRC_ROWS` removed (callers compute `2 × rows` where needed).
- `src/main.cyr`: pipeline replaces the hardcoded `downscale_to_rgb(&pstruct, 80, 48)` with `downscale_to_rgb(&pstruct, target_w, target_src_rows)` where `target_*` come from the M6 resolver above. The downstream `quantize_downscaled` + `emit_halfblock` already read `STRUCT_DOWNSCALED_W/_H` from pstruct, so they pick up the new dimensions without code changes.
- `print_version` literal bumped to `kii 0.7.0`.
- `cyrius.cyml [deps.darshana] tag = "0.5.3"` unchanged — M6 uses the already-pinned `tty_winsize` (darshana v0.3.0).

### Tests

- `tests/kii.tcyr` — **426 assertions** (was 382 at v0.6.0).
  - **M6(a) target-geometry** (24): RAMGON 1152×925 at widths 40 / 80 / 120 produce the expected aspect-true heights; `width=0` falls back to 80-col default; square / wide-landscape / tall-portrait synthetic shapes pin the formula; 800×1 degenerate clamps to ≥ 1 terminal row; invalid source dims return -1.
  - **M6(b) fit-geometry** (17): width-binding case (1000×100 in 120×40 → 120×6 term, dst_src_rows=12); row-binding case (RAMGON in 120×40 → 99×40 term); square 100×100 in 80×24 → 48×24 row-binds; zero-envelope falls back to (80, 24); single-pixel src clamps; invalid src dims return -1.

### Bench

- `quantize_nearest_rgb @ 1024×1024`: **269 ns/op** (unchanged from v0.6.0).
- **`end-to-end RAMGON.png → 80×24 frame`: 761 ms/iter** (50 iters; ~1 ms slower than v0.6.0's 747 ms — measurement noise, well under the resolution we have to begin with).
- **`end-to-end RAMGON.png → 120×40 frame`: 769 ms/iter** (30 iters).
- **`end-to-end RAMGON.png → 200×60 frame`: 771 ms/iter** (20 iters).

Render cell-count (1920 / 4800 / 12000) climbs 6.25× from 80×24 to 200×60, but the M5 emit + downscale + quantize-of-downscaled-buf are sub-millisecond — the entire bench is dominated by `png_decode_pixels` on RAMGON's 4.26 MB inflated buffer (~98 % share).

### Docs

- `docs/adr/0001-png-decoder-in-repo.md` — first ADR, captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. Carried forward from M3 → M4 → M5 → M6; finally lands.
- `docs/architecture/README.md` — backfilled. Module map + six numbered items: (1) pstruct byte-offset layout invariants, (2) half-block aspect math gotcha (src-rows vs term-rows), (3) pipe-purity and stdout discipline, (4) darshana dep + BG-256 inline copy rationale, (5) why `quantize_nearest_image` stays after M5 superseded it, (6) the 80×24 BBS-default non-TTY fallback. Carried M2 → M5; finally lands.
- `docs/benchmarks.md` — `## v0.7.0` section added.
- `docs/development/{state.md, roadmap.md}` + `docs/doc-health.md` — refreshed per release.

### Real-world smoke

- `kii RAMGON.png` in a 200×60 terminal renders ~200×40 (row-binding from RAMGON's aspect).
- `kii RAMGON.png > out.ansi` → exactly 80 cells wide × 24 rows tall (non-TTY 80×24 fallback).
- `kii --width 60 RAMGON.png` → 60 ▀ glyphs per row × 24 rows.
- `kii --width 200 RAMGON.png` → 200 ▀ glyphs per row × 80 rows (aspect-true, no row cap on explicit --width).

### Out of scope (deferred per M6 acceptance)

- **Visual review against `chafa --colors 16 --size 80x24`** on a curated 5-image set — carried from M5 again; the geometry is stable now, but a `chafa` install + curated fixtures is M7-audit work.
- **SIGWINCH-driven live re-render** — kii is one-frame-in-one-frame-out per `CLAUDE.md` § domain rules; interactive resize would be a v2 scope expansion. Captured here so the next contributor doesn't try to add it.
- **`tty_winsize` on stderr / explicit fd choice** — kii detects on fd 1 (stdout). A future `--detect-tty stderr` would be useful for `kii img.png | tee out.ansi` (where stdout is the pipe but stderr is the terminal) but no consumer has asked yet.

## [0.6.0] — 2026-05-22

### Added

- **M5 — half-block (`▀`) ANSI emit + per-row 256-color escapes**. `kii image.png` now reads a PNG, decodes it, downscales to 80×48 RGB triples (nearest-neighbor), quantizes to 16-color palette indices, and emits half-block glyphs to **stdout** sized to a hardcoded 80×24 — the first user-visible terminal output. Pipe-pure (`kii img.png > frame.ansi` captures just the frame). Per-character format: `\x1b[38;5;<fg>m\x1b[48;5;<bg>m▀` (top half = FG, bottom half = BG); `\x1b[0m\n` per row.
- **`src/downscale.cyr`** — new module. Nearest-neighbor RGB resampler. `downscale_to_rgb(pstruct, dst_w, dst_h)` walks each dst pixel, computes `sx = (dx × src_w) / dst_w` (integer truncation), and writes a packed RGB triple at the source `(sx, sy)` per the color_type. Per-color_type extraction (`_extract_rgb`) handles greyscale broadcast / RGB pass-through / PLTE expansion / alpha-drop / 16-bit-depth truncation in one place. Output: `STRUCT_DOWNSCALED_BUF` + `_W` + `_H`.
- **`src/emit.cyr`** — new module. Half-block emit layer.
  - `_emit_bg_256_buf(buf, pos, n)` — CSI `48;5;Nm` byte-pack (darshana's BG-256 twin not yet shipped; extract on 2nd consumer per the AGNOS pattern).
  - `emit_halfblock_row_buf(qbuf, sw, row, buf, pos)` — buffer-targeting variant; unit-testable without subprocessing stdout.
  - `emit_halfblock(pstruct)` — fd-1 wrapper, one `write(2)` per terminal row (~2 KB each, 24 writes per frame).
- **`src/quant.cyr` extensions**:
  - `quantize_rgb_buf(rgb_buf, n_pixels, out_buf)` — PNG-agnostic RGB-triple → palette-index transform. Reusable for future animated-frame / multi-format consumers.
  - `quantize_downscaled(pstruct)` — struct-aware wrapper that allocs `dw × dh` bytes, calls `quantize_rgb_buf`, stores into `STRUCT_QUANTIZED_BUF/_SIZE`. The M5+ pipeline replacement for `quantize_nearest_image`; the older fn stays for M4-test backward compat.
- **`src/png.cyr` extensions**: struct grew from 15 to 18 slots (160 bytes): `STRUCT_DOWNSCALED_BUF_OFFSET` (120) + `_W_OFFSET` (128) + `_H_OFFSET` (136).
- **`src/cli.cyr`**: activated `--verbose` / `-v` (was reserved in M1's flag indices). With the frame now on stdout, the M4 `<path>: <W>x<H> N pixels … → 16-color` summary moves behind this flag and rides stderr.
- **`darshana` 0.5.3 added to `cyrius.cyml [deps.darshana]`** — first external git dep. Provides `tty_fg_256_buf` (foreground CSI 38;5;Nm) + `tty_sgr_reset_buf` (CSI 0m for buffer composition). The BG twin lives in `src/emit.cyr` locally; extracts to darshana when a 2nd consumer surfaces.

### Changed

- `src/main.cyr`:
  - Pipeline restructured: `png_decode_structure` → `png_decode_pixels` → `downscale_to_rgb(80, 48)` → `quantize_downscaled` → `emit_halfblock`. Three new error paths (downscale / quantize / emit failures) each with a distinct stderr line.
  - `_print_quant_summary` → `_eprint_quant_summary` (now writes the M4-shape summary to stderr, gated behind `--verbose`).
  - `print_usage` Examples list updated: replaced "render to terminal (M5+)" placeholder with concrete 80×24 + `--verbose` + capture examples.
  - `var pstruct[128]` → `var pstruct[160]` to cover the 20-slot M5(b)-extended layout.
- `print_version` literal bumped to `kii 0.6.0`.

### Tests

- `tests/kii.tcyr` — **382 assertions** (was 287 at v0.5.0).
  - **M5(b) downscale** (38): identity 2×2 → 2×2 byte-identical; 2×2 → 4×4 nearest replicate (every quadrant covers source pixel); 2×2 → 1×1 top-left wins; rejects ungated calls + `dst_w <= 0`; RAMGON 1152×925 → 80×48 (11,520 bytes, non-zero); palette-PNG (archlinux-logo.png) per-color_type normalization.
  - **M5(c) emit** (57): `quantize_rgb_buf` 4-pixel canonical (red→1, blue→4, black→0, white→15); `quantize_downscaled` end-to-end + ungated reject; `_emit_bg_256_buf` exact byte sequences for 1/2/3-digit indices + bounds reject; `emit_halfblock_row_buf` exact byte layout for single-char (26 bytes), 2-col checkerboard (49 bytes), 4-col solid (89 bytes); `emit_halfblock` rejects ungated calls + odd source height + zero width.

### Bench

- `quantize_nearest_rgb @ 1024×1024`: **269 ns/op** (re-measured; ~5 ns noise vs the 274 at v0.5.0).
- **`end-to-end RAMGON.png → 80×24 frame`: 747 ms/iter** (50 iters; full pipeline including PNG decode + downscale + quantize + 24 in-process row builds). Dominated by `png_decode_pixels` on the 4.26 MB inflated RGBA buffer (~98 % share).

### Real-world smoke

- `RAMGON.png` (1152×925 RGBA) → 40,770 bytes of ANSI on stdout, exit 0. `--verbose` adds the M4-shape summary line on stderr.
- `/usr/share/pixmaps/archlinux-logo.png` (256×256 palette via PLTE) → renders cleanly.
- `/usr/share/pixmaps/kitty.png` (256×256 RGBA) → renders cleanly.

### Out of scope (deferred per M5 acceptance)

- **Bilinear / Lanczos downscale** — nearest-neighbor is the tier-1 floor; perceptually-better filters land in post-v1 alongside dithering.
- **Terminal-size detection** — hardcoded 80×24 at v0.6.0; `ioctl TIOCGWINSZ` is M6 / v0.7.0 work.
- **Visual review against `chafa --colors 16`** — carried to M6 alongside the reproducible terminal-size story.
- **Render-a-real-checkerboard-PNG end-to-end** — in-process `emit_halfblock_row_buf` shape tests pin the emit contract; the fixture-PNG variant adds a checkerboard builder that's not strictly required for M5 acceptance.
- **`tty_bg_256_buf` extraction to darshana** — kept inline in `src/emit.cyr` until a second consumer surfaces.
- **Fuzz coverage for downscale / quantize / emit** — captured in `docs/doc-health.md` as M7-audit work; needs a valid-PNG-fixture-then-random-dst-dims surface.

## [0.5.0] — 2026-05-22

### Added

- **M4 — 16-color ANSI palette + RGB → nearest quantization**. Valid PNGs now quantize through the full pipeline and print `<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color` to stdout + exit 0. The arrow visually separates source format from quantization target.
- **`src/palette.cyr`** — Linux-console / CGA-derived 16-color ANSI palette. Module-scope `_ANSI_PALETTE_RGB[16]` packed-byte buffer + `palette_init()` (idempotent) + `palette_r(idx)` / `palette_g(idx)` / `palette_b(idx)` accessors with lazy-init defense. Entries 0–7 are normal (dim) CGA originals; 8–15 are bright. Source: Linux kernel `drivers/tty/vt/vt.c default_color_table`.
- **`src/quant.cyr`** — RGB → palette-index quantization.
  - `_color_dist2(r1, g1, b1, r2, g2, b2)` — squared Euclidean distance. Skips sqrt (monotonic for minimum-finding); max value 3 × 255² = 195,075 fits comfortably in i64.
  - `quantize_nearest_rgb(r, g, b)` — scalar per-pixel: linear scan over 16 palette entries, ties broken by lowest index.
  - `quantize_nearest_image(pstruct)` — image-wide: walks pixel buffer, dispatches per color_type (greyscale / RGB / palette via PLTE / grey+alpha / RGBA), drops alpha + low-bytes for depth=16 (truncation quantization — full-precision 16-bit is tier-2). Stashes 1-byte-per-pixel result in pstruct.
- **`src/png.cyr` extensions**:
  - PLTE chunk capture: walker now allocates a heap buffer + memcpy's PLTE bytes during the existing CRC-streaming pass. Spec § 11.2.3 validation: `chunk_len ≤ 768` AND `chunk_len % 3 == 0`, both → `PNG_ERR_HEADER`.
  - `_png_is_plte(type_buf)` chunk-type predicate.
  - Struct grew from 11 to 15 slots (120 bytes): `STRUCT_PLTE_BUF_OFFSET` (88) + `STRUCT_PLTE_SIZE_OFFSET` (96) + `STRUCT_QUANTIZED_BUF_OFFSET` (104) + `STRUCT_QUANTIZED_SIZE_OFFSET` (112).
- **`tests/kii.bcyr`** — wired. First kii benchmark: `quantize_nearest_rgb` at 1,048,576 iterations. **274 ns/op** on x86_64-linux; captured in [`docs/benchmarks.md`](docs/benchmarks.md). 1024×1024 full-image quantization extrapolates to ~287 ms.

### Changed

- `src/main.cyr`:
  - Wired `quantize_nearest_image` into dispatch after `png_decode_pixels`. Single new error path: `quantization failed (palette PNG missing PLTE, or OOM)`.
  - Replaced `_print_pixel_summary` (M3 shape: `decoded N pixels`) with `_print_quant_summary` (M4 shape: `N pixels (<name>) → 16-color`).
  - Added `_print` helper (stdout equivalent of `_eprint`) so the UTF-8 arrow in the success line doesn't need hand-counted byte widths.
  - `pstruct[96]` → `pstruct[128]` to cover the 16-slot M4(d)-extended layout.

### Tests

- `tests/kii.tcyr` — **287 assertions** (was 163 at v0.4.0).
  - **M4(a) palette** (51): size + lazy-init + every RGB entry 0–15 byte-pinned + bounds check that every byte ∈ [0, 255].
  - **M4(b) quantizer scalar** (37): all four acceptance-criteria pixels (red→1, blue→4, white→15, black→0) plus green/yellow/cyan/magenta + every palette entry round-trips to its own index + brightness gradient (luminance non-decreasing) + `_color_dist2` sanity.
  - **M4(c) PLTE capture** (21): 3-entry red/green/blue palette byte-for-byte verify + non-PLTE leaves nulls + malformed PLTE rejection (not multiple of 3, > 768 bytes) + real archlinux-logo.png PLTE invariants.
  - **M4(d) end-to-end** (15): 2x2 canonical RGB fixture quantizes to `[1, 4, 0, 15]` for red/blue/black/white; ungated-call rejection; archlinux-logo.png quantizes via PLTE (256×256 = 65,536 indices).

### Real-world smoke

- `RAMGON.png` (1152×925 RGBA) → `1,065,600 pixels (RGBA) → 16-color`.
- `/usr/share/pixmaps/archlinux-logo.png` (256×256 palette via PLTE) → `65,536 pixels (palette) → 16-color`.
- `/usr/share/pixmaps/kitty.png` (256×256 RGBA) → `65,536 pixels (RGBA) → 16-color`.

### Out of scope (deferred per M4 acceptance)

- **CIE Lab / perceptual color spaces** — Euclidean RGB is the tier-1 floor. Lab + perceptual metrics are post-v1 scope per CLAUDE.md color-tier discipline.
- **Dithering** (Floyd-Steinberg / ordered / Bayer) — explicitly tier-2 / post-v1.
- **Full-precision 16-bit-depth quantization** — current code truncates to high byte per channel. Full sampling lands when a consumer needs the fidelity.

## [0.4.0] — 2026-05-22

### Added

- **M3 — PNG pixel decode**. Valid PNGs now decode through the full DEFLATE → filter undo pipeline and print `<path>: <W>x<H> decoded <N> pixels (<color_type_name>)` to stdout + exit 0. The success line shape per the M3 acceptance contract; `<N>` is pixel count (W×H), `<color_type_name>` is one of `greyscale` / `RGB` / `palette` / `grey+alpha` / `RGBA`.
- **`sankoch` + `thread` added to `[deps].stdlib`** in `cyrius.cyml`. The `thread` add is a transitive dep (sankoch's `_sankoch_lock`/`_sankoch_unlock` wrap `mutex_lock`/`mutex_unlock` from `lib/thread.cyr`).
- **`src/png.cyr` extensions**:
  - 5 new error codes (7–11): `PNG_ERR_INTERLACE`, `PNG_ERR_BITDEPTH`, `PNG_ERR_NO_IDAT`, `PNG_ERR_INFLATE`, `PNG_ERR_FILTER`.
  - Struct grew from 7 to 11 slots (88 bytes): `STRUCT_INTERLACE_OFFSET` (56), `STRUCT_IDAT_BUF_OFFSET` (64), `STRUCT_PIXELS_BUF_OFFSET` (72), `STRUCT_PIXELS_SIZE_OFFSET` (80). Aligned at first four slots with `IHDR_*_OFFSET` so summary helpers work on either buf.
  - `_png_is_idat(type_buf)` + `_png_is_iend(type_buf)` chunk-type predicates (refactored the existing nested-if walker).
  - `_png_copy_idat(path, idat_buf, expected_total)` — phase-2 walker that re-opens the file, skips past sig + IHDR, walks chunks copying IDAT data directly into a pre-allocated buffer. No CRC re-validation (phase 1 already did it).
  - `_png_color_channels(color_type)` — color-type → channels-per-pixel mapping.
  - `png_color_type_name(color_type)` — color-type → short human-readable name.
  - `_png_paeth(a, b, c)` — spec § 9.4 Paeth predictor.
  - `_png_unfilter_row(prev, curr_in, out, row_bytes, bpp, filter_type)` — one-row filter undo for spec § 9 filter types 0 (None) / 1 (Sub) / 2 (Up) / 3 (Average) / 4 (Paeth). Returns -1 on unknown filter byte.
  - `png_decode_pixels(pstruct)` — top-level pixel decode: M3 rejection rules (Adam7 + sub-byte) → `zlib_decompress` IDAT into a height × (1 + row_bytes) buffer → row-by-row filter undo into a height × row_bytes pixel buffer → stash in struct.
  - `png_decode_structure` now captures the interlace byte + (when IDATs exist) allocates a contiguous IDAT buffer via the phase-2 walker.

### Changed

- `src/main.cyr`:
  - Wired `png_decode_pixels` into the dispatch after `png_decode_structure`. Five new error-path branches for the new `PNG_ERR_*` codes; each gets a distinct user-facing message.
  - Replaced `_print_ihdr_summary` (M2 structural shape) with `_print_pixel_summary` (M3 shape). Old helper deleted per no-dead-code rule.
  - `pstruct[64]` → `pstruct[96]` (struct grew by 4 slots between M2 and M3).
- `tests/kii.fcyr` — PNG fuzz harness now exercises the full inflate + filter-undo path when its random-byte payload happens to contain valid-ish IDAT data after the valid prefix.

### Tests

- `tests/kii.tcyr` — **163 assertions** (was 88 at v0.3.0).
  - **M3(a)** sankoch round-trip: zlib_compress / zlib_decompress / dst-cap-too-small (5).
  - **M3(b)** interlace capture (both 0 and 1) + IDAT buffer accumulation byte-identical to fixture + no-IDAT-leaves-idat_buf-null (14).
  - **M3(c)** Paeth predictor canonical cases (5) + each filter type 0–4 round-trip + unknown-filter rejection (28) + color_channels mapping (8) + 2x2 RGB end-to-end decode (8) + Adam7/sub-byte/no-IDAT rejection (3) + **RAMGON.png** real-world decode → exact 4,262,400-byte buffer size (4).
- **Real-world smoke** (manual, not in `cyrius test`):
  - `RAMGON.png` (1152×925 RGBA) → `1065600 pixels (RGBA)`.
  - `/usr/share/pixmaps/archlinux-logo.png` (256×256 palette) → `65536 pixels (palette)`.
  - `/usr/share/pixmaps/kitty.png` (256×256 RGBA) → `65536 pixels (RGBA)`.

### Dependencies

- stdlib: **+ `sankoch`** (PNG IDAT zlib_decompress), **+ `thread`** (sankoch transitive). No external git deps yet — sankoch folded into Cyrius stdlib at v5.8.65, so this is a stdlib-list addition, not a `[deps.sankoch]` block. `darshana` (external) still lands at M5/v0.6.0.

### Out of scope (deferred per M3 acceptance)

- **Adam7 interlace** — rejected with `interlaced PNGs (Adam7) not supported in v0.x`. Defer-don't-half-implement per CLAUDE.md.
- **1/2/4-bit sub-byte depths** — rejected with `unsupported bit depth or color type (tier-1: 8/16-bit only)`. Same rationale.
- **PLTE → RGB lookup** — palette PNGs (color_type=3) emit palette INDICES at this layer. PLTE chunk handling lands at M4 alongside quantization.

## [0.3.0] — 2026-05-22

### Added

- **M2 — PNG structural decoder**. Valid PNGs now print `<path>: <W>x<H> bit_depth=<N> color_type=<T>` to **stdout** + exit 0 (pipe-pure — consumers can `kii image.png | grep ...`). Distinct error paths surface specific failure modes on stderr + exit 1:
  - `<path>: cannot open file` — open syscall failed (not found, permissions).
  - `<path>: not a PNG (file shorter than 8 bytes)` — truncated before signature.
  - `<path>: not a PNG` — first 8 bytes don't match the W3C magic.
  - `<path>: malformed PNG header` — IHDR chunk truncated, wrong type, or claims length ≠ 13.
  - `<path>: CRC check failed` — IHDR or any post-IHDR chunk fails CRC32.
  - `<path>: malformed PNG (chunk truncated after IHDR)` — chunk header / data / CRC read returned partial bytes.
  - `<path>: warning: incomplete PNG (no IEND chunk seen)` — soft warning per spec § 5.3 tolerance; structural summary still emitted, exit 0.
- **`src/png.cyr`** — new module owning the full structural-decode surface:
  - `PNG_MAGIC` + `PNG_MAGIC_LEN` (W3C § 5.2 signature: detects 7-bit gateways, line-ending mangling, naive `type` cmd).
  - `PNG_OK` / `PNG_ERR_OPEN` / `PNG_ERR_TRUNCATED` / `PNG_ERR_NOT_PNG` / `PNG_ERR_HEADER` / `PNG_ERR_CRC` / `PNG_ERR_CHUNK` codes.
  - `IHDR_*_OFFSET` + `STRUCT_*_OFFSET` field layouts (aligned at the first four slots so summary helpers work on either buf).
  - `png_check_signature(buf)` + `png_validate_file_signature(path)` + `png_read_u32_be(buf, off)` (matches `lib/sha1.cyr`'s big-endian pattern).
  - `png_crc_init()` + `_png_crc_update(crc, buf, len)` + `png_crc32(buf, len)` — Ethernet CRC-32 (reversed polynomial 0xEDB88320, same as zlib / gzip). 256-entry lookup table, idempotent init. First first-party CRC32 in the AGNOS ecosystem; extracts to stdlib if a second consumer surfaces (per the extract-on-2nd-consumer pattern).
  - `png_decode_header(path, out_ihdr)` — signature + IHDR + IHDR-CRC.
  - `png_decode_structure(path, out_struct)` — single-fd open: signature → IHDR (with CRC) → walk subsequent chunks → IDAT count + total-size accumulation → IEND detection. Chunk data streamed through a 4 KB scratch buffer (bounded memory regardless of input size).
- **Multi-source convergent port** per CLAUDE.md hard rule: decoder shape drawn from W3C PNG Specification (1.3) + `libpng` + `stb_image.h` + `lodepng`. Not single-source.

### Changed

- `src/main.cyr` — replaced M1 placeholder dispatch with `png_decode_structure` orchestration. New `_print_ihdr_summary` (stdout) helper for the success line; `_eprint_path_msg` (stderr) for errors + warnings. Missing-IEND warning lands on stderr while the structural summary stays on stdout (pipe-purity).
- `tests/kii.fcyr` — gained a **second fuzz surface**. The same binary now runs both arg-parser fuzz (10k iters, ~50 ms) and **PNG-decoder fuzz** (2k iters, ~50 ms). PNG fuzz: deterministic LCG-driven random byte buffers written to `/tmp/kii-fuzz-png.bin`; 50% of iters prepend a valid signature + IHDR so the post-IHDR chunk walker is exercised. M7 audit raises both counts to 10⁶ per the v1.0 acceptance criterion.

### Tests

- `tests/kii.tcyr` — 88 assertions (was 36 at v0.2.0). New coverage: M2(a) signature check (10), M2(b) BE-u32 decode + IHDR parse over four color types + four malformed cases (25), M2(c) CRC32 canonical (zlib reference + IEND constant + empty buf) + structure walker happy-path + missing-IEND warning + IHDR/IEND CRC bit-flip + truncated mid-chunk (17). Helpers `_ut_put_u32_be` + `_ut_build_min_png` make valid PNG fixtures from runtime-computed CRCs (replaces the pre-(c) "XXXX" placeholders that wouldn't pass CRC validation).

### CI / Release

- `ci.yml` — added **version-drift smoke** (compares `./build/kii --version`'s first line against `VERSION` file; trips CI on mismatch). The M1 close-out cycle hit this drift class once locally — the smoke would have caught it before merge.
- `ci.yml` — added **fuzz step** (`tests/kii.fcyr`, now covers both arg-parser + PNG-decoder surfaces). 12k iters total, ~0.07 s.
- `ci.yml` + `release.yml` — fixed binary-name template default (`${{ github.event.repository.name }}` → hardcoded `kii`). The cyrius-init scaffold assumed repo-name = binary-name; kii's repo is `cyrius-kii` but the binary is `kii` per `cyrius.cyml [build].output` and CLAUDE.md Quick Start.
- **Still deferred** (CI/release thorough setup): CHANGELOG-extracted release notes, aarch64 cross-build, macOS / Windows cross-build, Sigstore / SLSA. Tracked in this section; reassess at v1.0 audit.

### Dependencies

- stdlib unchanged from v0.2.0 (still `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`). PNG decoder uses only what's already in.
- External: still none. **`sankoch` lands at M3 (v0.4.0)** for DEFLATE-through-IDAT decompression.

## [0.2.0] — 2026-05-22

### Added

- **M1 — CLI arg parsing**. Full flag surface frozen at the syntactic level (the surface is contractually stable from here through v1.0):
  - `--help` / `-h` — prints usage to stderr (pipe-pure stdout); exits 0.
  - `--version` / `-V` — prints `kii 0.2.0` + the Hawaiian etymology line to stdout; exits 0.
  - `--width N` / `-w N` — output width in columns; default `0` is the M6 sentinel for "match terminal" (auto-detected via `ioctl TIOCGWINSZ` once M6 lands).
  - `--color N` / `-c N` — color tier; only `8` or `16` valid per CLAUDE.md tier-1 color-discipline. Tier-2 modes (256 / truecolor) explicitly rejected; deferred to post-v1.
  - Positional `<image.png>` — captured into `flags_positional`; zero or 2+ rejected with `kii: missing image path` / `kii: too many arguments` (exit 2).
- **src/cli.cyr** — new module. Owns `KII_EXIT_*`, `KII_F_*` flag indices, `kii_register_flags(fs)`, `kii_validate_color(color)`. Split out of main.cyr so unit tests + fuzz harness can drive kii's exact flag set in-process.
- **Placeholder dispatch** — `kii image.png` (and any valid path) prints `<path>: decoder not yet implemented (width=N color=N)` to stderr + exits 1. The width/color echo proves the flag values were captured into module state. Superseded at M2 when the structural decoder lands.

### Changed

- `src/main.cyr` — `args_init` + `alloc_init` + `kii_register_flags` + `flags_parse` + dispatch. Scaffold no-args banner removed in favor of the missing-path usage error (kii now requires a positional path).
- `cyrius.cyml` — `[deps].stdlib` gained `"flags"` (consumer: CLI flag parsing).

### Tests

- `tests/kii.tcyr` — 36 assertions (was 2). Coverage: smoke + math (2), `kii_validate_color` happy/sad table (8), flag-parse happy paths over the full flag set (long/short/attached forms, defaults, positional capture — 14), each `FLAG_ERR_*` variant (unknown / missing value / bad int / bundled — 8), multi-positional capture (2), version-literal regression baseline left for v0.3.0 (intentionally deferred; the literal isn't auto-generated yet).
- `tests/kii.fcyr` — wired. Deterministic Numerical-Recipes LCG (seed = 1) drives 10,000 iterations of random argv against kii's flag set. Bias toward `-x` / `--foo` prefixes (50% of args) so the parser exercises its flag-recognition path. M7 audit raises to 10⁶ iterations per the v1.0 acceptance criterion. Catches arg-parser crash regressions; PNG-decoder fuzz comes at M2 in a separate harness.

### Dependencies

- stdlib: + `"flags"` (was `args`-only for CLI). All other stdlib modules unchanged.
- External: still none (sankoch lands at M3, darshana at M5).

### CI / Release

- `.github/workflows/ci.yml` — added `workflow_call:` trigger so `release.yml` can gate on it via `uses: ./.github/workflows/ci.yml`. **This was the minimum fix required** to make a v0.2.0 tag actually release rather than blow up at the CI-gate dispatch.
- **Deferred (CI/release thorough setup)** — captured here as the punch list for a dedicated cycle:
  - Run the fuzz harness in CI (`cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz`) on every PR.
  - Add a binary-version smoke step after build (`./build/kii --version | grep "^kii $(cat VERSION)$"`) so a stale `print_version` literal trips CI rather than silently drifting (the M1 work already hit this drift class once).
  - Extract release notes from `CHANGELOG.md`'s `[X.Y.Z]` section rather than relying on GitHub's PR-title `generate_release_notes: true`.
  - aarch64 cross-build (`cyrius build --aarch64`) — release ships only x86_64 today; cyrius supports aarch64 natively.
  - macOS / Windows cross-build (post-v1 — out of v0.2.0 scope).
  - Sigstore / SLSA provenance attestation (probably overkill for kii's threat model; reassess at v1.0 audit).

## [0.1.0] — 2026-05-22

### Added

- `cyrius init kii` scaffold:
  - `VERSION`, `cyrius.cyml`, `LICENSE` (GPL-3.0-only), `.gitignore`
  - `src/main.cyr` — entry point; prints version banner + Hawaiian etymology + scaffold-status line
  - `src/test.cyr` — test entry routing to `tests/kii.tcyr`
  - `tests/kii.tcyr` — primary test suite (smoke + math; 2 assertions, all pass)
  - `tests/kii.bcyr` — benchmark stub (wired at M4)
  - `tests/kii.fcyr` — fuzz stub (wired at M2)
  - `docs/adr/`, `docs/architecture/`, `docs/guides/`, `docs/examples/` skeleton
  - `.github/workflows/ci.yml` + `release.yml`
- First-party-standards docs:
  - `CLAUDE.md` — Project Identity, Goal, color-tier discipline (tier 1 = 8/16-color + half-block; tier 2 post-v1), domain rules (half-block floor, CRC validation, no file writes), naming-lane notes
  - `README.md` — Hawaiian etymology, status, color-tier roadmap, substrate plan (darshana + sankoch + in-repo PNG decoder), multi-source prior art table (chafa / jp2a / viu / libcaca + PNG spec)
  - `CONTRIBUTING.md` — dev workflow, milestone-aligned contributions, dep-add discipline, tests requirement
  - `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1 pointer
  - `SECURITY.md` — explicit threat surface (malformed image input, decompression amplification, ANSI escape injection), mitigations in code, reporting channel
  - `docs/development/state.md` — initial scaffold snapshot
  - `docs/development/roadmap.md` — M0-M7 milestones to v1.0 with acceptance criteria + dep gates
  - `docs/doc-health.md` — per-file currency ledger; tier classification; refresh discipline

### Toolchain

- Cyrius pin: `6.0.1`

### Dependencies

- stdlib: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`
- External: none yet (sankoch + darshana lands at M3 + M5 respectively)

### Naming

- Repo + binary: `kii` (ASCII-safe form; no `cyrius-` prefix — that's reserved for games per AGNOS `project_game_naming_convention`)
- Display form: `kiʻi` with ʻokina punctuation
- Lane: Polynesian-direct (Hawaiian micro-cluster — sibling to `hapi`, `anuenue`)
