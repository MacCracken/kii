# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**1.3.1** — cut 2026-06-26. **ASCII shape-vector glyph matching.** Upgrades `--mode ascii`
from the 1.3.0 luminance ramp to shape-aware selection: each cell sampled in a 2×3 sub-grid,
matched (6-region nearest-Euclidean) to the glyph whose ink-coverage vector is closest — tracks
orientation (`/ \ | - _ ( ) ^`), not just density. 27-glyph coverage table computed offline from
Liberation-Mono (normalized 0..255). Attribution: Alex Harri's blog (cited in `src/ascii.cyr` +
ADR 0007); deferred refinements: directional contrast + k-d-tree. Half-block byte-identical.
`print_version` → `kii 1.3.1`. 369 assertions.

**1.3.0** — cut 2026-06-26. **Character-glyph ASCII mode (`--mode ascii`).** A second
rendering lane beside half-block — kii's jp2a/namesake "ASCII art": text glyphs by
luminance (ramp `" .:-=+*#%@"`, Rec.709 luma), colored per cell. Shares decode →
downscale → quantize; forks only at emit. Half-block default byte-identical. New
`src/ascii.cyr` module + `--mode {halfblock|ascii}` flag (`-m`). See
[ADR 0007](../adr/0007-rendering-mode-taxonomy.md). Advanced shape-vector glyph matching
(Harri blog) deferred. `print_version` → `kii 1.3.0`. 371 assertions.

**1.2.2** — cut 2026-06-26. **Full PNG matrix via chitra 0.2.1.** Re-pins
`[deps.chitra]` `0.2.0` → `0.2.1` (which added sub-byte depths 1/2/4 + Adam7 interlace).
kii now **renders 1/2/4-bit + interlaced PNGs it used to reject** — zero code change, the
adapter just forwards chitra's RGBA8. Depth-8/16 frames stay byte-identical (golden
unchanged). `PNG_ERR_BITDEPTH`/`_INTERLACE` messages corrected for the wider surface;
capability tests added. `print_version` → `kii 1.2.2`.

**1.2.1** — cut 2026-06-26. **Fix: `emit_halfblock` per-row buffer overflow at large
`--width`.** Pre-existing M6 bug (not from the re-fold): the per-row scratch was a fixed
`line_buf[2048]` (2048 bytes, sized for 80 cols), so a row wider than ~89 cells overran it
(`kii --width 200` wrote ~4 KB/row into 2 KB of stack). Now heap-allocated and sized from
the width (`sw*26+16`). Output byte-identical at every width. (Also folds in the v1.2.0
test-portability fix: `tests/decode.tcyr` tmp fixtures now write to `/tmp`, not a
session-specific scratchpad that broke CI.)

**1.2.0** — cut 2026-06-26. **The PNG re-fold — kii adopts the `chitra` distlib and
deletes its own decoder.** `src/png.cyr` drops from 813 lines to a thin adapter over
`[deps.chitra]` `0.2.0` (the release that made chitra a strict superset of kii's decoder:
16-bit depth + every M7(c)/M8 guard). `kii_decode_png` slurps the file (256 MB pre-read
cap), calls `chitra_png_decode`, and writes the RGBA8 into the pstruct as a depth-8 ct6
image so `downscale`/`quant`/`emit` are untouched — **frames byte-identical** (RAMGON
golden diff at 40/80/120/200/default + verbose). Same extract-on-2nd-consumer move as the
cmdit CLI re-fold (v1.1.0). Test suite split into `tests/{cli,quant,render,decode}.tcyr`;
decoder-internal coverage retired to chitra. See [ADR 0006](../adr/0006-adopt-chitra-decoder.md).

**1.1.2** — cut 2026-06-26. **Toolchain + darshana refresh.** cyrius pin `6.2.36` →
`6.2.44` with `lib/` re-vendored from the 6.2.44 stdlib snapshot; `[deps.darshana]`
`0.8.0` → `0.8.1` (`[deps.cmdit]` stays `1.1.0`). No functional change; rendering
byte-identical. `print_version` literal → `kii 1.1.2`.

**1.1.1** — cut 2026-06-25. **cmdit pin advance.** `[deps.cmdit]` `0.1.0` → `1.1.0`
(cmdit froze its API at 1.0.0; 1.1.0 added `cmdit_help_flags` — both backward-compatible
supersets of the 0.1.0 surface kii uses). No functional change; 468/468 green, rendering
byte-identical. `print_version` literal → `kii 1.1.1`.

**1.1.0** — 2026-06-25. **CLI re-fold: adopted the `cmdit` distlib** (the stdlib flags
parser productized + extended) — dropped the hand-rolled parsing + `build_argv_array` +
`KII_ARGV_MAX`; now `cmdit_new`/`cmdit_parse`/`cmdit_get_*`/`cmdit_positional` with auto
`--help`/`--version`. kii is cmdit's **first consumer** (validates the extraction). Stdlib
`flags` dropped (`args` kept). Tests rewired. See `agnosticos/docs/development/planning/cmdit.md`.

**1.0.1** — toolchain + dependency refresh — 2026-06-18. (v1.0.0 M8 freeze closeout was 2026-05-23.)

## Toolchain

- **Cyrius pin**: `6.2.44` (in `cyrius.cyml [package].cyrius`). `lib/` re-vendored from the 6.2.44 stdlib snapshot at 1.1.2 (was 6.2.22 / re-vendored at 1.0.1).

## Surface

Full PNG → terminal-fit ANSI half-block frame pipeline (unchanged at the user-facing layer from v0.7.0):

- `kii image.png` in a TTY → detects terminal cols × rows via `tty_winsize(1)`, fits the image into `cols × (rows - 1)` aspect-preservingly, emits a frame sized to that envelope on stdout. Exit 0.
- `kii image.png > out.ansi` (non-TTY) → falls back to 80×24 BBS-default; identical frame shape regardless of where stdout lands.
- `kii --width N image.png` → exactly N cells wide; height aspect-derived without a row cap.
- `kii --verbose image.png` adds the M4-shape summary line to **stderr** after the frame.
- `kii --mode ascii image.png` → character-glyph "ASCII art" lane (v1.3.1 shape-vector: 2×3 sub-grid matched to glyph coverage → orientation-aware `/ \ | - _ ( ) ^`, colored fg) instead of the half-block default. `--mode halfblock` (default) is the `▀` floor. See [ADR 0007](../adr/0007-rendering-mode-taxonomy.md).
- Missing IEND → frame + stderr warning + exit 0 (per spec § 5.3 tolerance).
- **Decode rejection paths** (the M7(c)/M8 guards now live inside chitra; kii maps
  `ChitraErr` → `PNG_ERR_*` for byte-stable stderr): dimensions/ratio bombs →
  `PNG_ERR_DIMENSIONS` (12); OOM / IDAT-too-large → `PNG_ERR_IDAT_TOO_LARGE` (13);
  duplicate/late PLTE, palette-OOB, non-zero IEND, bad chunk → `PNG_ERR_HEADER` (4);
  color_type=3 + bit_depth=16 → `PNG_ERR_BITDEPTH` (8); zero IDAT → `PNG_ERR_NO_IDAT` (9).
  Reserved (unreachable via chitra, kept for the stable code space): `PNG_ERR_TRUNCATED`
  (2, a <8-byte file now reports `not a PNG`) and `PNG_ERR_RATIO_TOO_HIGH` (14, the ratio
  bomb arrives as `DIMENSIONS`). See [ADR 0006](../adr/0006-adopt-chitra-decoder.md).
- **New `PNG_ERR_FILE_TOO_LARGE` (15)** — input file > 256 MB rejected before the in-memory
  slurp (a DoS guard the old streaming decoder didn't need).
- **M7(c) stderr hardening** (stays in kii, never decoder code): filenames containing C0 control bytes or DEL are substituted with `<path containing control bytes — suppressed>` before stderr emit; CVE-2021-25743-analog injection vector closed.

Module map:

- `src/main.cyr` — I/O glue + dispatch. Two-path geometry resolver (`--width N` → M6(a); else `tty_winsize`-detect → M6(b) fit). M7(c) added `_eprint_path_safe` helper routing path bytes through the sanitizer.
- `src/cli.cyr` — CLI parse helpers + `KII_F_*` indices (width/color/verbose/**mode**). M7(c) added `kii_path_has_control_bytes(path)`; v1.3.0 added `kii_validate_mode` / `kii_mode_is_ascii` for `--mode`.
- `src/ascii.cyr` — **character-glyph lane** (v1.3.0 ramp → v1.3.1 shape-vector): `_ascii_luma` (Rec.709), `_ascii_match` (6-region nearest-glyph) + `_ascii_shape_init` (27-glyph coverage table, offline-generated), `emit_ascii_shape_row_buf` (testable) + `emit_ascii_shape`. Per-row buffer heap-allocated from width.
- `src/png.cyr` — **chitra adapter** (post-re-fold; was the 813-line native decoder). Keeps the `PNG_ERR_*` code space + 20-slot `STRUCT_*_OFFSET` pstruct (160 bytes, +`STRUCT_SRC_COLOR_TYPE_OFFSET`=144) + `_png_color_channels` / `png_color_type_name`. Adds `kii_decode_png(path,&pstruct)` (size-capped slurp → `chitra_png_decode` → RGBA8 as a depth-8 ct6 image), `kii_file_size` (lseek SEEK_END), and `_kii_map_chitra_err` (`ChitraErr`→`PNG_ERR_*`). All signature/IHDR/CRC/inflate/unfilter/PLTE + security caps now live in chitra.
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — `quantize_nearest_rgb` (scalar) + `quantize_rgb_buf` / `quantize_downscaled` (production pipeline). The M4 `quantize_nearest_image` was removed at the re-fold (it read native color_type/PLTE that no longer reach the pstruct).
- `src/downscale.cyr` — Nearest-neighbor RGB resampler. Post-re-fold the live input is always ct6 (chitra RGBA8); the `_extract_rgb` color_type table is retained. Called as `downscale_to_rgb(pstruct, target_w, target_src_rows)`.
- `src/emit.cyr` — Half-block ANSI emit + geometry primitives (`_kii_compute_target_geometry` for explicit-width, `_kii_compute_fit_geometry` for terminal-fit). Default constants `EMIT_DEFAULT_COLS = 80` / `EMIT_DEFAULT_ROWS = 24`. Local `_emit_bg_256_buf` while darshana's BG-256 twin isn't shipped.
- `tests/` — split from the monolithic `tests/kii.tcyr` into focused standalone suites at the re-fold (matches chitra's `tests/tcyr/*.tcyr` convention): `tests/cli.tcyr` (cmdit/flags + path-sanitizer), `tests/quant.tcyr` (palette + quantize), `tests/render.tcyr` (downscale + emit + geometry), `tests/decode.tcyr` (`kii_decode_png` e2e + `_kii_map_chitra_err` + adapter + sankoch zlib round-trip). **336 assertions** total (cli 57 + quant 109 + render 129 + decode 41); ~132 decoder-internal assertions retired to chitra (its suite is 322).
- `tests/kii.fcyr` — fuzz surfaces (arg-parser, path-sanitizer, geometry, emit-pipeline, PNG); the PNG surface re-aimed through `kii_decode_png`.
- `tests/kii.bcyr` — benches (quantize + end-to-end RAMGON + decode latency); decode bench re-aimed through `kii_decode_png`.
- `tests/fixtures/RAMGON.png` — real-world fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: ~145 KB at v0.8.0 (unchanged from v0.7.0; compiler still reports ~430 unreachable fns DCE-eliminable). M7(c) hardening commits are small additive changes; no new modules.

## Tests + bench

- `cyrius test` → **336 assertions, all pass** across 4 split suites (cli 57 / quant 109 / render 129 / decode 41). Down from 468 at v1.1.2: ~132 decoder-internal assertions retired to chitra (322 there) at the v1.2.0 re-fold; `decode.tcyr` adds the `kii_decode_png` adapter + `_kii_map_chitra_err` mapping coverage.
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → **3,011,000 iters, all clean**. Surfaces: 10k arg-parser + 1M path-sanitizer + 1M geometry + 1k emit-pipeline + 1M PNG (re-aimed through `kii_decode_png` → chitra at the re-fold).
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

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `sankoch`, `thread` (`flags` dropped at the v1.1.0 cmdit re-fold). `sankoch` + `thread` stay post-decoder-re-fold — chitra's dist resolves `zlib_decompress`/`crc32`/`mutex` from kii's stdlib list, and kii's tests call `zlib_decompress` directly.
- **External**: `darshana 0.8.1` + `cmdit 1.1.0` + **`chitra 0.2.1`** (PNG decoder; added at the v1.2.0 re-fold, re-pinned 0.2.0 → 0.2.1 at v1.2.2). darshana's `tty_winsize` + ANSI primitives drive emit (BG-256 twin still absent → kii keeps the inline `_emit_bg_256_buf`); cmdit owns CLI parsing; chitra owns PNG decode (`dist/chitra.cyr`) — now the **full PNG matrix**: all bit depths 1/2/4/8/16 + Adam7 interlace.

## Cycle context

v1.0.0 ships during agnos kernel cycle **1.32.x networking-arc**. kii lands as substrate for the BBS / MUD apps that are downstream cycles (ideated but not yet built); v1.0 freeze is explicit about NOT bundling consumer integration with the substrate ship.

## Next

**v1.x — Tier-2 (post-v1)**. Sub-bites (not yet scoped to milestones):

- `--color 256` and `--color tc` modes (truecolor SGR emit).
- Floyd-Steinberg + ordered-Bayer dithering as `--dither` choices.
- `--filter {nearest,bilinear,box}` selection.
- **JPEG + other formats arrive via chitra** (0.2.1 = sub-byte depths 1/2/4 + Adam7; 0.3+ = JPEG) on a `[deps.chitra]` re-pin — post-re-fold kii consumes new formats from the substrate rather than an in-repo decoder (see ADR 0006).
- **Character-glyph ASCII mode** (`--mode ascii`) — luminance-ramp floor + shape-vector glyph matching; review item in `docs/development/roadmap.md` § Post-v1 (attribution: Alex Harri's ASCII-rendering blog for the shape-vector/contrast logic).
- Re-render the chafa visual-review fixture set (deferred from M8) once chafa is installed in the dev environment.
- Cross-terminal verification (Linux console / xterm / Alacritty / kitty / tmux) on a wider terminal set.
- Three sankoch upstream items (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers) — file as sankoch issues; track impact.

**Carry-forward debt at v1.0**: chafa visual review (`docs/audit/chafa-comparison-deferred.md`), cross-terminal verification, marketplace recipe in zugot, three sankoch upstream items. None block the v1.0 tag; documented for v1.x pickup.

**v2.0 horizon**: Tier-3 — Sixel / Kitty / iTerm2 inline-image protocols. Major-version cut depending on CLI surface impact.
