# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**1.5.0** — cut 2026-08-24. **The format broadening: BMP + GIF via chitra 1.0.0, plus the
toolchain/dep catch-up.** Re-pins `[deps.chitra]` `0.3.0` → `1.0.0`, which carries BMP (chitra
0.4.0) and GIF first-frame (chitra 0.5.0) decode. **The decode path needed no change** — the
adapter already called the format-sniffing `chitra_image_decode` unconditionally, so both
formats rendered the moment the pin moved (verified before any source edit). The cut is
therefore **diagnostics**: `KII_FMT_BMP`/`KII_FMT_GIF` tags fed by chitra's frozen bmp/gif
signature predicates, `png_color_type_name` learning nine new source sentinels (six BMP
`0x200|bpp`, the GIF `0x300|min_code_size` range, JPEG's `0x113` RGB), and `_kii_map_chitra_err`
gaining arms for the eleven `ChitraErr` codes (24–34) that previously all collapsed into the
generic malformed fallback — which is why a corrupt `.bmp` used to report "malformed PNG".
Also: toolchain `6.4.20` → `6.5.35`, `[deps.darshana]` `0.8.2` → `1.0.0` (its API freeze),
`[deps.cmdit]` `1.1.0` → `1.2.4`, and `lib/` re-vendored 104 → **39** files (62 undeclared
stdlib bundles removed). **PNG + JPEG frames byte-for-byte unchanged** (17/17 golden artifacts
identical). **511 assertions** (decode 105 → 166, render 137 → 156); fuzz **6,011,000 iters**
(+1M BMP, +1M GIF), peak RSS ~136 MB. Fixed: CI would have hard-failed on this pin (flat
toolchain layout vs the versioned one `cyrius deps` resolves against, previously masked by a
pre-6.5.25 resolver bug), and `tests/quant.tcyr` had not compiled since v1.2.0 — 48 two-arg
`assert_eq` calls meant its 109 assertions never ran. See [ADR 0009](../adr/0009-bmp-gif-via-chitra.md).
`print_version` → `kii 1.5.0`.

**1.4.1** — cut 2026-07-08. **agnos-target build fix + toolchain pin `6.2.44` → `6.4.20` +
darshana `0.8.1` → `0.8.2`.** darshana 0.8.2 lands AGNOS parity for the TTY-mode primitives
(`tty_isatty` / `tty_raw` / `tty_cooked` agnos peers); additive superset of the surface kii
uses, render byte-identical.
The committed `lib/` snapshot had drifted *behind* the pin: the vendored agnos syscall peer
(`lib/syscalls_x86_64_agnos.cyr`) predated `SYS_LSEEK = 58`, so `cyrius build --agnos src/main.cyr`
failed `undefined variable 'SYS_LSEEK'` at `src/png.cyr:216` (the `kii_file_size` `lseek(…, SEEK_END)`
size probe). Linux was unaffected (`SYS_LSEEK = 8` long-standing in the linux peer). Fixed by
`cyrius lib sync` re-vendoring the stdlib subset from the advanced pin — **no source change**;
rendering byte-identical (RAMGON re-verified on Linux **and** agnos-under-mirshi, 137/137 suite green).
Unblocks kii from the agnosticos agnos-dev docker image (`docker/build-dev.sh`), where it had been
auto-skipped on the failing `--agnos` build. `print_version` literal → `kii 1.4.1`.

**1.4.0** — cut 2026-06-27. **Baseline JPEG decode via chitra 0.3.0.** Re-pins
`[deps.chitra]` `0.2.1` → `0.3.0` and switches the decode adapter from `chitra_png_decode`
to the format-sniffing `chitra_image_decode`, so `kii photo.jpg` renders **baseline (SOF0)
JPEG** (grayscale + YCbCr, 4:4:4 / 4:2:2 / 4:2:0 subsampling, DRI/RST restart markers)
beside the full PNG matrix. chitra normalizes JPEG to the same canonical RGBA8 as PNG, so
downscale/quant/emit are untouched and **PNG frames stay byte-identical** (RAMGON golden at
40/80/120/200/default + verbose). The 11 JPEG `ChitraErr` codes map onto `PNG_ERR_*` (a new
`PNG_ERR_UNSUPPORTED` for the deferred modes — progressive/arithmetic/12-bit/non-baseline/
CMYK); a `KII_FMT_*` tag (`STRUCT_FORMAT_OFFSET`, set from the signature sniff) drives
format-aware diagnostics ("malformed JPEG …" vs "malformed PNG …"); `png_color_type_name`
names the JPEG source sentinels 257/259 for `--verbose`. Historical `png_`/`PNG_ERR_*`/
`png.cyr` names retained (rename to `image.*`/`IMG_ERR_*` tracked). `print_version` → `kii
1.4.0`. **431 assertions** (decode 51 → 105, render +8 JPEG e2e); fuzz **4,011,000 iters**
(+1M JPEG, alloc-reset-bounded, peak ~134 MB). See [ADR 0008](../adr/0008-jpeg-via-chitra.md).

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

- **Cyrius pin**: `6.5.35` (in `cyrius.cyml [package].cyrius`). `lib/` re-vendored from the 6.5.35 stdlib snapshot at 1.5.0 (was 6.4.20 / re-vendored at 1.4.1).
- **`lib/` is 39 files, not 104.** The tree had carried 62 undeclared stdlib bundles (`mabda`, `sigil`, `sandhi`, `patra`, `yukti`, `bayan`, `ganita`, `sakshi`, `vani`, …) that kii references nowhere — leftovers from an old full-snapshot vendor. They shadowed the pinned versions and produced a standing build warning. **`cyrius lib sync` cannot remove them** (it only overwrites declared modules); the canonical re-vendor is `rm -rf lib && mkdir lib && cyrius deps`, which is now also what CI runs.

## Surface

Full PNG + baseline JPEG + BMP + GIF → terminal-fit ANSI half-block frame pipeline (unchanged at the user-facing layer from v0.7.0; v1.4.0 added JPEG, v1.5.0 added BMP + GIF — same emit surface throughout):

- `kii image.png` in a TTY → detects terminal cols × rows via `tty_winsize(1)`, fits the image into `cols × (rows - 1)` aspect-preservingly, emits a frame sized to that envelope on stdout. Exit 0.
- `kii photo.jpg` (v1.4.0) → baseline JPEG decodes through chitra's JPEG path (signature-sniffed, not extension-keyed) and renders identically — `--mode ascii`, `--width`, `--verbose`, terminal-fit all apply. `--verbose` reports the source as `greyscale (JPEG)` / `YCbCr (JPEG)` / `RGB (JPEG)` (the `0x113` Adobe-`transform=0` sentinel, named since v1.5.0). Progressive / arithmetic / 12-bit / CMYK JPEG reject as `unsupported JPEG feature …` (chitra stays baseline-only).
- `kii art.bmp` (v1.5.0) → BMP renders through chitra: `BI_RGB` 1/4/8/16/24/32 bpp, `BI_RLE4`/`BI_RLE8`, `BI_BITFIELDS` with V4/V5 headers. `--verbose` names the source precisely from chitra's `0x200 | bpp` sentinel (`24bpp (BMP)`, `4bpp palette (BMP)`, …). Unsupported bpp / `BI_JPEG` / `BI_PNG` / a bad channel mask reject as `unsupported BMP feature …`.
- `kii art.gif` (v1.5.0) → GIF87a/89a renders through chitra's LZW path, interlaced frames included. **First frame only** (chitra ADR 0005) — correct for a still-frame renderer. Source named `palette (GIF)` from the `0x300 | min_code_size` sentinel. A GIF whose LZW stream ends early still renders, with the tail zero-filled and a `warning: incomplete GIF (truncated frame — tail zero-filled)` on stderr.
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
- **BMP + GIF rejection paths** (v1.5.0, chitra's eleven new `ChitraErr` codes 24–34 mapped onto the existing `PNG_ERR_*` space rather than minting new codes — see [ADR 0009](../adr/0009-bmp-gif-via-chitra.md)): BMP header/palette/RLE corruption and GIF header/palette corruption → `PNG_ERR_HEADER` (4), phrased per format; BMP bpp outside `{1,4,8,16,24,32}` / `BI_JPEG` / `BI_PNG` / bad `BI_BITFIELDS` mask → `PNG_ERR_UNSUPPORTED` (16); GIF LZW corruption → `PNG_ERR_INFLATE` (10); a structurally valid GIF with no image descriptor → `PNG_ERR_NO_IDAT` (9); `CHITRA_ERR_BUDGET` → `PNG_ERR_IDAT_TOO_LARGE` (13, unreachable today — kii calls the unbudgeted entry point).
- **New `PNG_ERR_FILE_TOO_LARGE` (15)** — input file > 256 MB rejected before the in-memory
  slurp (a DoS guard the old streaming decoder didn't need).
- **M7(c) stderr hardening** (stays in kii, never decoder code): filenames containing C0 control bytes or DEL are substituted with `<path containing control bytes — suppressed>` before stderr emit; CVE-2021-25743-analog injection vector closed.

Module map:

- `src/main.cyr` — I/O glue + dispatch. Two-path geometry resolver (`--width N` → M6(a); else `tty_winsize`-detect → M6(b) fit). M7(c) added `_eprint_path_safe` helper routing path bytes through the sanitizer.
- `src/cli.cyr` — CLI parse helpers + `KII_F_*` indices (width/color/verbose/**mode**). M7(c) added `kii_path_has_control_bytes(path)`; v1.3.0 added `kii_validate_mode` / `kii_mode_is_ascii` for `--mode`.
- `src/ascii.cyr` — **character-glyph lane** (v1.3.0 ramp → v1.3.1 shape-vector): `_ascii_luma` (Rec.709), `_ascii_match` (6-region nearest-glyph) + `_ascii_shape_init` (27-glyph coverage table, offline-generated), `emit_ascii_shape_row_buf` (testable) + `emit_ascii_shape`. Per-row buffer heap-allocated from width.
- `src/png.cyr` — **chitra image adapter** (v1.5.0: four-way signature sniff PNG→JPEG→BMP→GIF matching chitra's own routing order; `KII_FMT_BMP`/`KII_FMT_GIF`; nine new `png_color_type_name` sentinels; eleven new `_kii_map_chitra_err` arms) (post-re-fold; was the 813-line native decoder). Now decodes PNG **and** baseline JPEG: `kii_decode_png` sniffs the signature, calls `chitra_image_decode` (v1.4.0; was `chitra_png_decode`), and writes the canonical RGBA8 into the pstruct as a depth-8 ct6 image. Keeps the `PNG_ERR_*` code space (+ `PNG_ERR_UNSUPPORTED`=16 for deferred JPEG modes) + the now-20-slot `STRUCT_*_OFFSET` pstruct (160 bytes; +`STRUCT_SRC_COLOR_TYPE_OFFSET`=144, +`STRUCT_FORMAT_OFFSET`=152) + `KII_FMT_*` + `_png_color_channels` / `png_color_type_name` (extended with JPEG sentinels 257/259) + `kii_file_size` (lseek SEEK_END) + `_kii_map_chitra_err` (`ChitraErr`→`PNG_ERR_*`, incl. the 11 JPEG codes). All signature/IHDR/CRC/inflate/unfilter/PLTE on the PNG path and markers/Huffman/IDCT on the JPEG path + security caps live in chitra. Historical `png_`/`PNG_ERR_*`/filename names retained (rename tracked).
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — `quantize_nearest_rgb` (scalar) + `quantize_rgb_buf` / `quantize_downscaled` (production pipeline). The M4 `quantize_nearest_image` was removed at the re-fold (it read native color_type/PLTE that no longer reach the pstruct).
- `src/downscale.cyr` — Nearest-neighbor RGB resampler. Post-re-fold the live input is always ct6 (chitra RGBA8); the `_extract_rgb` color_type table is retained. Called as `downscale_to_rgb(pstruct, target_w, target_src_rows)`.
- `src/emit.cyr` — Half-block ANSI emit + geometry primitives (`_kii_compute_target_geometry` for explicit-width, `_kii_compute_fit_geometry` for terminal-fit). Default constants `EMIT_DEFAULT_COLS = 80` / `EMIT_DEFAULT_ROWS = 24`. Local `_emit_bg_256_buf` while darshana's BG-256 twin isn't shipped.
- `tests/` — split from the monolithic `tests/kii.tcyr` into focused standalone suites at the re-fold (matches chitra's `tests/tcyr/*.tcyr` convention): `tests/cli.tcyr` (cmdit/flags + path-sanitizer), `tests/quant.tcyr` (palette + quantize), `tests/render.tcyr` (downscale + emit + geometry), `tests/ascii.tcyr` (`--mode ascii` shape-vector), `tests/decode.tcyr` (`kii_decode_png` PNG **+ JPEG + BMP + GIF** e2e + `_kii_map_chitra_err` incl. the 11 JPEG and 11 BMP/GIF/budget codes + every source-sentinel name + `KII_FMT_*` tag + sankoch zlib round-trip), and `tests/render.tcyr` carries JPEG, BMP and GIF render e2e. **511 assertions** total (cli 63 + quant 109 + render 156 + ascii 17 + decode 166); at v1.5.0 decode grew 105 → 166 and render 137 → 156. Decoder-internal coverage lives in chitra's suite.
- `tests/fixtures/gradient.bmp` + `tests/fixtures/color.gif` — v1.5.0 fixtures: 16×16 24-bpp `BI_RGB` white→black ramp (px0=0, px1=17, px2=34, stepping by 17) and a 16×16 GIF89a with four flat quadrants (red / lime / blue / white). Both pixel-verified against ImageMagick as the oracle.
- `tests/fixtures/{gradient,color}.jpg` — v1.4.0 JPEG fixtures: 16×16 grayscale (chitra's ImageMagick-verified gradient, src ctype 257) + 8×8 YCbCr 4:4:4 (src ctype 259).
- `tests/kii.fcyr` — fuzz surfaces (arg-parser, path-sanitizer, geometry, emit-pipeline, PNG, **JPEG**); PNG + JPEG surfaces aimed through `kii_decode_png` (JPEG = SOI + random bytes, generational/bounded).
- `tests/kii.bcyr` — benches (quantize + end-to-end RAMGON + decode latency); decode bench re-aimed through `kii_decode_png`.
- `tests/fixtures/RAMGON.png` — real-world fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: ~145 KB at v0.8.0 (unchanged from v0.7.0). At v1.5.0 the compiler reports ~942 unreachable fns (~390 KB DCE-eliminable) — the growth is the vendored chitra bundle carrying four decoders where it once carried one, not kii code; kii gained no module at v1.5.0.

## Tests + bench

- `cyrius test` → **511 assertions, all pass** across 5 split suites (cli 63 / quant 109 / render 156 / ascii 17 / decode 166). At v1.5.0 decode grew 105 → 166 (+61: BMP + GIF e2e against ImageMagick-verified fixtures, the eleven BMP/GIF/budget error mappings, the nine new source-sentinel names plus four range-boundary guards, and a non-image UNKNOWN-tag case) and render grew 137 → 156 (+19: BMP and GIF decode→downscale→quantize→emit e2e, including a real content check that the GIF's pure-red and pure-lime quadrants quantize to palette entries 1 and 2 — the NORMAL entries, not the bright ones, because nearest-RGB puts pure (255,0,0) at 85² from entry 1 but 85²+85² from entry 9). **`tests/quant.tcyr`'s 109 assertions run again for the first time since v1.2.0** — 48 palette calls passed two arguments to the three-argument `assert_eq(a, b, name)`, so the suite had been failing to compile; the v1.4.1 cut missed it by verifying only the render suite. decode grew 51 → 105 at v1.4.0 (+54 JPEG: 11 error mappings + sentinel names + format tag + grayscale & YCbCr e2e with pixel/chroma/row checks + progressive/malformed stubs); render +8 (a JPEG decode→downscale→quantize→emit e2e). Decoder-internal coverage lives in chitra's suite.
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → **6,011,000 iters, all clean** (peak RSS **~136 MB**). Eight surfaces: 10k arg-parser + 1M path-sanitizer + 1M geometry + 1k emit-pipeline + 1M PNG + 1M JPEG + **1M BMP** + **1M GIF**. Each decode surface prefixes the real format signature (`\x89PNG`, `\xFF\xD8`, `BM`, `GIF89a`) so the random payload actually reaches that decoder rather than bouncing off the sniff. All four decode surfaces call `alloc_reset()` to rewind the never-free bump allocator each iteration (a matched signature makes chitra allocate marker/header/palette scratch before the input fails) — without it the heap would grow unboundedly. The **GIF surface is the highest-value of the four**: LZW builds a dictionary from attacker-controlled codes, the classic GIF-decoder CVE class.
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
- **External**: `darshana 1.0.0` + `cmdit 1.2.4` + **`chitra 1.0.0`** (image decoder; added at the v1.2.0 re-fold, re-pinned 0.2.0 → 0.2.1 at v1.2.2 → 0.3.0 at v1.4.0). darshana's `tty_winsize` + ANSI primitives drive emit (BG-256 twin still absent → kii keeps the inline `_emit_bg_256_buf`); cmdit owns CLI parsing; chitra owns image decode (`dist/chitra.cyr`) via `chitra_image_decode` — the **full PNG matrix** (all bit depths 1/2/4/8/16 + Adam7 interlace) **plus baseline JPEG** (grayscale + YCbCr, 4:4:4 / 4:2:2 / 4:2:0, DRI/RST).

## Cycle context

v1.0.0 ships during agnos kernel cycle **1.32.x networking-arc**. kii lands as substrate for the BBS / MUD apps that are downstream cycles (ideated but not yet built); v1.0 freeze is explicit about NOT bundling consumer integration with the substrate ship.

## Next

**v1.x — Tier-2 (post-v1)**. Sub-bites (not yet scoped to milestones):

- `--color 256` and `--color tc` modes (truecolor SGR emit).
- Floyd-Steinberg + ordered-Bayer dithering as `--dither` choices.
- `--filter {nearest,bilinear,box}` selection.
- **Baseline JPEG shipped at v1.4.0** (chitra 0.3.0, [ADR 0008](../adr/0008-jpeg-via-chitra.md)); **BMP + GIF shipped at v1.5.0** (chitra 1.0.0, [ADR 0009](../adr/0009-bmp-gif-via-chitra.md)) — the latter with **zero decode change**, which is ADR 0006's thesis fully discharged. The remaining format item is progressive-DCT JPEG, which chitra still refuses; it would arrive the same way, on a re-pin. **The rename `png.*` → `image.*` / `PNG_ERR_*` → `IMG_ERR_*` is now materially overdue** — those names cover four formats.
- **Character-glyph ASCII mode** (`--mode ascii`) — luminance-ramp floor + shape-vector glyph matching; review item in `docs/development/roadmap.md` § Post-v1 (attribution: Alex Harri's ASCII-rendering blog for the shape-vector/contrast logic).
- Re-render the chafa visual-review fixture set (deferred from M8) once chafa is installed in the dev environment.
- Cross-terminal verification (Linux console / xterm / Alacritty / kitty / tmux) on a wider terminal set.
- Three sankoch upstream items (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers) — file as sankoch issues; track impact.

**Carry-forward debt at v1.0**: chafa visual review (`docs/audit/chafa-comparison-deferred.md`), cross-terminal verification, marketplace recipe in zugot, three sankoch upstream items. None block the v1.0 tag; documented for v1.x pickup.

**v2.0 horizon**: Tier-3 — Sixel / Kitty / iTerm2 inline-image protocols. Major-version cut depending on CLI surface impact.
