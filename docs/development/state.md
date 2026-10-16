# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**1.6.2** — cut 2026-10-15. **The three parse errors cmdit 1.3.x added now get their own
lines.** `kii --verbose=0` (and `=1`, `=`, `--help=x`, `--version=1`) prints `kii: --<flag> takes
no value`. A command line the stdlib cannot read whole prints `could not read the full command
line`, and a refused allocation prints `out of memory`. In 1.6.1 all three printed `argument
parse error`. The lines live in `kii_parse_error_line` / `kii_err_flag_name` (`src/cli.cyr`) so
tests pin their bytes. Everything else is byte-identical to 1.6.1 (125 of 130 cases; the 5 are
those bool forms, exit 2 as before). **642 assertions** (cli 98 → 141), x86_64 and aarch64;
8,011,000 fuzz iterations, clean. `print_version` → `kii 1.6.2`.

**1.6.1** — cut 2026-10-15. **Dependencies to the newest tags that build on cyrius 6.7.9:**
cmdit `1.2.5` → **`1.4.0`**, chitra `1.0.3` → **`1.1.3`**, darshana stays at **`1.3.0`**, its
newest tag. chitra 1.1.4 and 1.2.0 pin cyrius 6.7.12, so they were not taken. `cyrius.cyml`
went from 126 lines to 39: pin history and rationale moved out of the manifest, and the
`repository` URL was corrected to `MacCracken/kii`. No kii source changed except
`print_version` → `kii 1.6.1`. Frames are byte-identical to v1.6.0 (121 of 124 cases). The
other 3 are cmdit 1.3.1 refusing a bool flag given a value: `--verbose=0` used to turn verbose
on, and now exits 2 with the generic `argument parse error`. Several chitra 1.1.1 refusals now
reach kii's mapping with more precise codes. CHANGELOG 1.6.1 lists each one. **599
assertions** (x86_64 and aarch64); **8,011,000 fuzz iterations**, clean.

**1.6.0** — cut 2026-10-12. **Toolchain `6.6.2` → `6.7.9` (the 6.7 language minor),
darshana `1.0.0` → `1.3.0`, and the `path` overrides dropped.** No kii source needed a
language repair (audited, not just built: no lone `!`, no unary `-`/`~` on a constant, no
typed-pointer dereference, no compound assignment, no reserved-word identifier); every target
builds warning-free. The three `[deps.X]` `path = "../X"` entries are gone — through v1.5.2
they made local builds compile the sibling checkouts (darshana 1.1.2 / cmdit 1.2.5 / chitra
1.0.3) while the tags said 1.0.0 / 1.2.4 / 1.0.0 — and the tags now name what is compiled:
darshana **1.3.0**, cmdit **1.2.5**, chitra **1.0.3**. Two darshana primitives replace kii
code: `tty_bg_256_buf` (byte-identical for all 256 indices) for the local `_emit_bg_256_buf`,
and `tty_has_ctl` for the path sanitizer's own UTF-8 walk — the same rule plus strict RFC 3629,
so overlong forms, surrogates and code points past U+10FFFF in a filename are now suppressed
(**a deliberate behaviour change**). `tty_winsize_or` was not adopted (kii decides columns and
rows separately; see `_kii_term_envelope`). Fixed: a valid PNG over sankoch's 16 MiB inflate
ceiling reported "malformed PNG" (now `PNG_ERR_INFLATE_LIMIT`), and the fuzz harness could not
exit non-zero on a contract violation. **190 rendered frames byte-identical** to v1.5.2.
**599 assertions** (was 550); **8,011,000 fuzz iterations** (was 6,011,000). `print_version`
→ `kii 1.6.0`.

**1.5.2** — cut 2026-09-11. Toolchain `6.5.35` → `6.6.2`, no source change. (This file was not
refreshed at that cut; the entry is backfilled at 1.6.0.)

**1.5.1** — cut 2026-08-25. **P-1 audit / refactor / hardening / optimization /
security sweep.** Five audit lenses (correctness, security, refactor, optimization,
docs + deferred-item) over the full surface, every material finding put through an
adversarial refutation pass: **41 raised, 2 refuted, 39 folded into 16 work items**.
Rendering is **byte-identical** at the default tier (22/22 golden artifacts).

The load-bearing finds: an unbounded `--width` wrapped `dst_w * dst_h * 3` into a
12-byte allocation the resampler then wrote past — **a reproducible SIGSEGV and
heap corruption on both render lanes**, now capped at the CLI and guarded inside
`downscale_to_rgb`; a truncated JPEG **rendered silently** because the `seen_iend`
gate had no JPEG arm and its comment wrongly claimed chitra forces the flag to 1;
the **1,000,000-iteration PNG fuzz surface had been testing nothing** since its
second iteration, because `alloc_reset()` invalidated sankoch's cached CRC-32
table; the ANSI-injection sanitizer covered C0 but **not C1**, so a filename built
from 8-bit control introducers delivered a complete OSC window-title injection to
stderr byte-for-byte; every `write(2)` to stdout was unchecked, so `kii img > out`
on a full filesystem exited **0** having written nothing; and `--color 8` had been
parsed, range-validated and then silently ignored since M1. Also: `CHITRA_ERR_UNSUPPORTED`
no longer routes a JPEG to the PNG § 11.2.2 bit-depth message, a 1-row terminal no
longer discards its own valid column count, and a fixture-guarded benchmark now
reports a visible SKIP instead of vanishing from the output. **550 assertions**
(was 511). See [`docs/audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md).
`print_version` → `kii 1.5.1`.

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

- **Cyrius pin**: `6.7.9` (in `cyrius.cyml [package].cyrius`; the build reports `compiler: …/versions/6.7.9/bin/cycc`). `lib/` re-vendored from the 6.7.9 snapshot at 1.6.0 with `rm -rf lib && mkdir lib && cyrius deps` (was 6.6.2 at 1.5.2, 6.5.35 at 1.5.0).
- **Dependency resolution is git + tag only** (since 1.6.0). cyrius 6.7.6+ resolves the tag by default and checks the commit pin in `cyrius.lock`; kii's manifest no longer names any `path`, so a local build and CI compile the same bundles. To build against a sibling checkout, add its `path` in a local edit and use `cyrius build --local`.
- **`lib/` is 40 files** at 6.7.9 (39 at 1.5.x: the 6.7.9 allocator pulls in `alloc_cx.cyr` and `poison.cyr`, and `flags.cyr` is gone now that chitra ≥ 1.0.1's sidecar no longer lists it). History: it was 104 before 1.5.0. The tree had carried 62 undeclared stdlib bundles (`mabda`, `sigil`, `sandhi`, `patra`, `yukti`, `bayan`, `ganita`, `sakshi`, `vani`, …) that kii references nowhere — leftovers from an old full-snapshot vendor. They shadowed the pinned versions and produced a standing build warning. **`cyrius lib sync` cannot remove them** (it only overwrites declared modules); the canonical re-vendor is `rm -rf lib && mkdir lib && cyrius deps`, which is now also what CI runs.

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
- **New `PNG_ERR_INFLATE_LIMIT` (17)** (v1.6.0) — a valid PNG whose pixel data inflates past sankoch's 16 MiB `DECOMPRESS_MAX_OUTPUT` (≈ 5.6 MP of RGB) is refused before allocation (chitra 1.0.1's `CHITRA_ERR_INFLATE_LIMIT`) and reported as `image too large to decode (…)`; through v1.5.2 it read "malformed PNG".
- **M7(c) stderr hardening** (stays in kii, never decoder code): a filename that is not safe to echo is substituted with `<path containing control bytes — suppressed>` before stderr emit; CVE-2021-25743-analog injection vector closed. Since v1.6.0 the rule is darshana's `tty_has_ctl` in UTF-8 mode with TAB and LF kept: C0 except TAB/LF, DEL, raw C1, `C2 80`–`C2 9F`, and any malformed or non-RFC-3629 UTF-8 (overlong forms, surrogates and code points past U+10FFFF included).

Module map:

- `src/main.cyr` — I/O glue + dispatch. Two-path geometry resolver (`--width N` → M6(a); else `tty_winsize` → `_kii_term_envelope` → M6(b) fit). M7(c) added `_eprint_path_safe` helper routing path bytes through the sanitizer.
- `src/cli.cyr` — CLI parse helpers + `KII_F_*` indices (width/color/verbose/**mode**). v1.6.2 added `kii_parse_error_line(err)` (the stderr line for each cmdit error code) and `kii_err_flag_name(fs)` (the long name of the flag an error names). M7(c) added `kii_path_has_control_bytes(path)` — since v1.6.0 a wrapper over darshana's `tty_has_ctl`; v1.3.0 added `kii_validate_mode` / `kii_mode_is_ascii` for `--mode`.
- `src/ascii.cyr` — **character-glyph lane** (v1.3.0 ramp → v1.3.1 shape-vector): `_ascii_luma` (Rec.709), `_ascii_match` (6-region nearest-glyph) + `_ascii_shape_init` (27-glyph coverage table, offline-generated), `emit_ascii_shape_row_buf` (testable) + `emit_ascii_shape`. Per-row buffer heap-allocated from width.
- `src/png.cyr` — **the chitra image adapter** (post-re-fold; was the 813-line native decoder). Decodes all four formats: `kii_decode_png` slurps under a 256 MB cap, sniffs the signature four ways (PNG→JPEG→BMP→GIF, matching chitra's own routing order), calls `chitra_image_decode`, and writes the canonical RGBA8 into the pstruct as a depth-8 ct6 image. Owns the `PNG_ERR_*` code space (17 codes; `PNG_ERR_INFLATE_LIMIT` added at v1.6.0), the 20-slot `STRUCT_*_OFFSET` layout (160 bytes; `SRC_COLOR_TYPE`=144, `FORMAT`=152), `KII_FMT_*`, `_png_color_channels` / `png_color_type_name` (every PNG colour type plus the JPEG `0x100|ncomp`, BMP `0x200|bpp` and GIF `0x300|min_code_size` sentinels), `kii_file_size` (lseek SEEK_END), and `_kii_map_chitra_err` (all 35 `ChitraErr` codes; 35 = `CHITRA_ERR_INFLATE_LIMIT`, mapped at v1.6.0). Every parser and security guard — signature/IHDR/CRC/inflate/unfilter/PLTE, JPEG markers/Huffman/IDCT, BMP DIB/RLE/BITFIELDS, GIF LZW — lives in chitra. Historical `png_` / `PNG_ERR_*` / filename names retained; the rename to `image.*` / `IMG_ERR_*` is tracked and deferred (see the v1.5.1 audit § 5).
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — `quantize_nearest_rgb` (scalar) + `quantize_rgb_buf` / `quantize_downscaled` (production pipeline). The M4 `quantize_nearest_image` was removed at the re-fold (it read native color_type/PLTE that no longer reach the pstruct).
- `src/downscale.cyr` — Nearest-neighbor RGB resampler. Post-re-fold the live input is always ct6 (chitra RGBA8); the `_extract_rgb` color_type table is retained. Called as `downscale_to_rgb(pstruct, target_w, target_src_rows)`.
- `src/emit.cyr` — Half-block ANSI emit (darshana `tty_fg_256_buf` + `tty_bg_256_buf` + `tty_sgr_reset_buf`; the local `_emit_bg_256_buf` was retired at v1.6.0) + geometry primitives (`_kii_compute_target_geometry` for explicit-width, `_kii_compute_fit_geometry` for terminal-fit, and `_kii_term_envelope`, v1.6.0, turning a `tty_winsize` answer into the fit envelope — columns and rows decided separately, one row kept for the prompt). Default constants `EMIT_DEFAULT_COLS = 80` / `EMIT_DEFAULT_ROWS = 24`. `_kii_write_all` (short-write-safe stdout).
- `tests/` — split from the monolithic `tests/kii.tcyr` into focused standalone suites at the re-fold (matches chitra's `tests/tcyr/*.tcyr` convention): `tests/cli.tcyr` (cmdit/flags + path-sanitizer), `tests/quant.tcyr` (palette + quantize), `tests/render.tcyr` (downscale + emit + geometry), `tests/ascii.tcyr` (`--mode ascii` shape-vector), `tests/decode.tcyr` (`kii_decode_png` PNG **+ JPEG + BMP + GIF** e2e + `_kii_map_chitra_err` incl. the 11 JPEG and 11 BMP/GIF/budget codes and `INFLATE_LIMIT` + every source-sentinel name + `KII_FMT_*` tag + sankoch zlib round-trip), and `tests/render.tcyr` carries JPEG, BMP and GIF render e2e. **599 assertions** total (cli 98 + quant 125 + render 188 + ascii 17 + decode 171); at v1.6.0 cli grew 77 → 98, render 164 → 188 and decode 167 → 171. Decoder-internal coverage lives in chitra's suite.
- `tests/fixtures/oversize.png` — v1.6.0: a valid 2370×2370 black RGB PNG (16,447 bytes on disk, 16,853,070 inflated), just past sankoch's 16 MiB inflate ceiling; ImageMagick-verified. Drives `PNG_ERR_INFLATE_LIMIT` end to end.
- `tests/fixtures/gradient.bmp` + `tests/fixtures/color.gif` — v1.5.0 fixtures: 16×16 24-bpp `BI_RGB` white→black ramp (px0=0, px1=17, px2=34, stepping by 17) and a 16×16 GIF89a with four flat quadrants (red / lime / blue / white). Both pixel-verified against ImageMagick as the oracle.
- `tests/fixtures/{gradient,color}.jpg` — v1.4.0 JPEG fixtures: 16×16 grayscale (chitra's ImageMagick-verified gradient, src ctype 257) + 8×8 YCbCr 4:4:4 (src ctype 259).
- `tests/kii.fcyr` — **ten** fuzz surfaces (arg-parser, path-sanitizer, geometry, emit-pipeline, **PNG, JPEG, BMP, GIF**, and since v1.6.0 the **path-sanitizer differential** against the v1.5.2 walk and the **terminal envelope**); all four decode surfaces aimed through `kii_decode_png`, each prefixing its format signature so the payload reaches that decoder, and each pairing `alloc_reset()` with `crc32_table = 0` (JPEG = SOI + random bytes, generational/bounded). Since v1.6.0 a non-zero `bad` count on any surface exits 1 with `fuzz: FAIL`.
- `tests/kii.bcyr` — benches (quantize + end-to-end RAMGON + decode latency); decode bench re-aimed through `kii_decode_png`.
- `tests/fixtures/RAMGON.png` — real-world fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: **902 KB** on host at v1.6.1 (`build/kii` = 923,976 bytes, unstripped, DCE off; the compiler reports 1,140 unreachable fns, ~523 KB, eliminable with `CYRIUS_DCE=1`). The +25,632 bytes over v1.6.0 come from the cmdit 1.4.0 and chitra 1.1.3 bundles. kii's source is unchanged. `--agnos` 938,088 bytes; `--aarch64` 1,087,600 bytes. At v1.6.0 it was **877 KB** (898,344 bytes), up from 683,584 bytes for v1.5.2 rebuilt from its own tree at 6.6.2: the growth is the 6.7.9 toolchain and the larger darshana 1.3.0 bundle — kii's own source got smaller (the local BG composer and the hand-rolled UTF-8 walk are gone). `--agnos` 908,376 bytes; `--aarch64` 1,086,544 bytes. Earlier: **668 KB** at v1.5.1 (`build/kii` = 683,576 bytes, unstripped, DCE off). The `~145 KB` this section reported was measured at v0.8.0 and never refreshed across the cmdit fold, the chitra re-fold, or the JPEG/BMP/GIF folds — it was low by **4.6×**. Most of the size is the vendored `chitra` bundle carrying four decoders plus `sankoch`; the compiler reports ~942 unreachable fns (~390 KB) eliminable with `CYRIUS_DCE=1`. kii gained no module at v1.5.0 or v1.5.1. (Corrected at the v1.5.1 P-1 sweep.)

## Tests + bench

- `cyrius test` → **642 assertions, all pass** across 5 split suites (cli 141 / quant 125 / render 188 / ascii 17 / decode 171), plus the `[build].test` entry `src/test.cyr` (6 entries). v1.6.2 added 43 in cli: the bool `=value` refusal naming its flag, and the exact parse-error line for every cmdit code. v1.6.0 added 49: cli +21 (strict RFC 3629 boundaries, both overlong CSI spellings, the `tty_has_ctl` wiring), render +24 (all 256 BG indices byte-identical to the retired composer, `_kii_term_envelope` incl. 1-row and half-set winsizes), decode +4 (`PNG_ERR_INFLATE_LIMIT` mapping + oversize fixture + format tag + the 16 MiB pin). The same five suites also pass under `cyrius test --aarch64` (qemu-aarch64). v1.5.1 added 39 (P-1 regressions: C1 sanitizer coverage in both encodings, the `--color` tier contract, the downscale overflow guard, and the `_emit_bg_256_buf` negative-pos guard). At v1.5.0 decode grew 105 → 166 (+61: BMP + GIF e2e against ImageMagick-verified fixtures, the eleven BMP/GIF/budget error mappings, the nine new source-sentinel names plus four range-boundary guards, and a non-image UNKNOWN-tag case) and render grew 137 → 156 (+19: BMP and GIF decode→downscale→quantize→emit e2e, including a real content check that the GIF's pure-red and pure-lime quadrants quantize to palette entries 1 and 2 — the NORMAL entries, not the bright ones, because nearest-RGB puts pure (255,0,0) at 85² from entry 1 but 85²+85² from entry 9). **`tests/quant.tcyr`'s 109 assertions run again for the first time since v1.2.0** — 48 palette calls passed two arguments to the three-argument `assert_eq(a, b, name)`, so the suite had been failing to compile; the v1.4.1 cut missed it by verifying only the render suite. decode grew 51 → 105 at v1.4.0 (+54 JPEG: 11 error mappings + sentinel names + format tag + grayscale & YCbCr e2e with pixel/chroma/row checks + progressive/malformed stubs); render +8 (a JPEG decode→downscale→quantize→emit e2e). Decoder-internal coverage lives in chitra's suite.
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → **8,011,000 iters, all clean, exit 0** (peak RSS **137,848 KB**, ~99 s wall on a loaded host, v1.6.0). The v1.6.0 surfaces: the path-sanitizer differential (1M; per run ≈ 284k inputs both walks accept, ≈ 203k only the strict RFC 3629 rule refuses, the rest both refuse; `bad=0`) and the terminal envelope (1M, `bad=0`); both were checked to fire on a deliberately wrong implementation. At v1.5.1 the harness ran 6,011,000 iters at ~136 MB. **The PNG surface only became real at v1.5.1**: the per-iteration `alloc_reset()` that bounds the heap also invalidated sankoch's cached CRC-32 table (a lazy-init singleton holding a heap pointer), so from iteration 2 onward 2999 of every 3000 inputs died at the signature check rather than reaching the chunk walker, inflate, unfilter or the PLTE bounds. Every `alloc_reset()` is now paired with `crc32_table = 0`; the measured return-code tally afterwards matches a no-reset run exactly. Ten surfaces: 10k arg-parser + 1M path-sanitizer + 1M geometry + 1k emit-pipeline + 1M PNG + 1M JPEG + 1M BMP + 1M GIF + **1M path-sanitizer differential** + **1M terminal envelope** (the last two run after the rest, so the first eight consume the same random stream they did through v1.5.2). sankoch's arena canary (2.7.10+) now also drops the CRC table on a reset; the `crc32_table = 0` lines are kept as a second guard. Each decode surface prefixes the real format signature (`\x89PNG`, `\xFF\xD8`, `BM`, `GIF89a`) so the random payload actually reaches that decoder rather than bouncing off the sniff. All four decode surfaces call `alloc_reset()` to rewind the never-free bump allocator each iteration (a matched signature makes chitra allocate marker/header/palette scratch before the input fails) — without it the heap would grow unboundedly. The **GIF surface is the highest-value of the four**: LZW builds a dictionary from attacker-controlled codes, the classic GIF-decoder CVE class.
- Bench (see [`docs/benchmarks.md`](../benchmarks.md) § v1.6.0; measured at 6.7.9 on a loaded host, three runs, so ranges):
  - `quantize_nearest_rgb @ 1024×1024`: **301–307 ns/op**
  - `end-to-end RAMGON.png → 80×24 frame`: **765–786 ms/iter**
  - `end-to-end RAMGON.png → 120×40 frame`: **754–791 ms/iter**
  - `end-to-end RAMGON.png → 200×60 frame`: **759–806 ms/iter**
  - The v1.5.2 binary, interleaved in the same session, ran end-to-end in 682–747 ms: the 6.7.9 toolchain is ~5–15 % slower here, kii's own code unchanged in effect.
  - **M7(d) decode-latency matrix** (DoS-bound):
    - `png_decode 256² class` (archlinux-logo 256×256, palette): **2.3–2.5 ms**
    - `png_decode 1024² class` (starfield 1597×1198, RGB): **SKIPPED** — the system fixture no longer ships on the dev host; the bench prints an explicit skip line rather than vanishing (v1.5.1)
    - `png_decode 2048² class` (elarun-bg 2560×1600, RGB): **493–550 ms**
    - Per-pixel decode throughput is content-dependent (compression-ratio-driven), not strictly size-dependent.

## Dependencies

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `sankoch`, `thread` (`flags` dropped at the v1.1.0 cmdit re-fold). `sankoch` + `thread` stay post-decoder-re-fold — chitra's dist resolves `zlib_decompress`/`crc32`/`mutex` from kii's stdlib list, and kii's tests call `zlib_decompress` directly.
- **External** (git + tag, no `path` since v1.6.0): `darshana 1.3.0` + **`cmdit 1.4.0`** + **`chitra 1.1.3`** (image decoder; added at the v1.2.0 re-fold, re-pinned 0.2.0 → 0.2.1 at v1.2.2 → 0.3.0 at v1.4.0 → 1.0.0 at v1.5.0 → 1.0.3 at v1.6.0 → 1.1.3 at v1.6.1). Each is the newest tag that builds on cyrius 6.7.9. chitra 1.1.4 and later pin 6.7.12. chitra ≥ 1.1.0 declares its own `[deps.sankoch]` (`zlib` profile 2.8.7). kii's stdlib `sankoch` leaf takes precedence, so the profile is never vendored, and `cyrius.lock` carries only its commit pin. ⚠ The stdlib sankoch at 6.7.9 is 2.8.3, below the 2.8.6 floor chitra documents for zlib-strict inflate. A pin at cyrius ≥ 6.7.11 lifts it. Through v1.5.2 the manifest said darshana 1.0.0 / cmdit 1.2.4 / chitra 1.0.0 but the `path` overrides compiled 1.1.2 / 1.2.5 / 1.0.3. darshana supplies every escape kii writes (`tty_fg_256_buf`, `tty_bg_256_buf`, `tty_sgr_reset_buf`), the terminal size (`tty_winsize`) and the path-echo rule (`tty_has_ctl`); cmdit owns CLI parsing; chitra owns image decode (`dist/chitra.cyr`) via `chitra_image_decode` — the **full PNG matrix** (all bit depths 1/2/4/8/16 + Adam7 interlace) **plus baseline JPEG** (grayscale + YCbCr, 4:4:4 / 4:2:2 / 4:2:0, DRI/RST).

## Cycle context

v1.0.0 ships during agnos kernel cycle **1.32.x networking-arc**. kii lands as substrate for the BBS / MUD apps that are downstream cycles (ideated but not yet built); v1.0 freeze is explicit about NOT bundling consumer integration with the substrate ship.

## Next

**Sequencing lives in [`roadmap.md`](roadmap.md)** — this file is the current snapshot,
not a plan, and keeping a second ordered list here is how the two drift apart. The
roadmap is forward-facing only: anything shipped is deleted from it rather than checked
off, so if an item appears there it is genuinely still open.

In brief, what is open as of v1.6.2:

- **Tier 2 colour** (256 / truecolour + dithering) — the likeliest next minor. The
  `--color` flag already carries a real tier mechanism as of v1.5.1, so this extends an
  existing seam.
- **The `png.*` → `image.*` rename** — 28 symbols across 290 call sites; materially
  overdue now that those names cover four formats. Wants its own cut.
- **Progressive-DCT JPEG** — the one remaining format gap; arrives via a `chitra` re-pin.
- **ASCII shape-vector refinements** — directional contrast + k-d-tree lookup.
- **Two `sankoch` limitations** (S-1 Huffman slow path, S-2 16 MiB inflate cap) — re-verified open at 6.7.9; S-3 is fixed upstream. Re-verify at the next pin bump.
- Cross-terminal verification and the zugot marketplace recipe, both carried from v1.0.
- **v2.0 horizon**: full Block Elements glyph vocab, then Tier 3 (Sixel / Kitty / iTerm2).
