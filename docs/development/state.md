# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**1.11.0** — cut 2026-10-28. **The ASCII lane samples areas**
([ADR 0005](../adr/0005-nearest-neighbor-downscale.md) and
[ADR 0007](../adr/0007-rendering-mode-taxonomy.md) § v1.11.0 amendments):
- **`downscale_area_to_rgb`** gives each of a cell's six samples the mean of the source pixels
  whose centres fall in its span: the whole span up to 4 pixels (`KII_AREA_TAPS`), 4 evenly
  spaced taps beyond, so no sample reads more than 16. With no reduction it hands off to
  `downscale_to_rgb`, byte for byte. It writes the luminance plane itself, with transparent
  pixels as 0.
- **Thin lines and edges stop dropping out.** Cells with ink drawn as a space: 127 → 18 of 291
  on 2 px lines at `--width 48`, 40 → 3 of 170 on a 5 px X; none at ≥ 15 % coverage.
- **Reduced ASCII frames change** (328 of 912; 1.6 % of cells at `--width 30`); enlarged ASCII
  frames and every half-block frame are byte-identical. The cost is ≤ 3.1 % on RAMGON and
  ≤ 1.2 % on 6–16 MP images, but +23 % on a 6 MP image at `--width 400`, where every sample
  reads many pixels.

**877 assertions** (x86_64 and aarch64; aarch64 frames match x86_64, 348 of 348); **8,151,000
fuzz iterations**, clean, with a new area-sampler surface (a pad differential and a reference).
`print_version` → `kii 1.11.0`.

**1.10.0** — cut 2026-10-28. **The ASCII lane's refinements**
([ADR 0007](../adr/0007-rendering-mode-taxonomy.md) § v1.10.0 amendment):
- **A generated glyph table.** `scripts/gen-shape-table.sh` writes `src/ascii_shape.cyr`
  (Liberation Mono, 40 px in 24 × 48, ink per 12 × 16 region, scaled per row to 255), and
  `--check` proves it. The v1.3.1 table could not be reproduced, so the table is new.
- **Contrast enhancement** on every lit cell: directional, then global,
  x → (x / M)^p · M with p = 1.5, after Harri's write-up. The ten external samples are the
  sub-samples around the cell, and the arithmetic is exact integers.
- **A luminance plane** per frame (pstruct +40, at most 6 MiB) feeds both.
- **The k-d tree was not taken.** It is exact, but 444 ns against the scan's 331 ns on random
  vectors, and 233 against 203 on real cells.
- **ASCII frames change** (836 of 912; 8.7 % of cells at `--width 30`); every half-block frame
  is byte-identical. The cost is +14 % on a 256² icon at `--width 200`, +1.7 % on RAMGON.

**848 assertions** (x86_64 and aarch64; aarch64 frames match x86_64, 240 of 240); **8,051,000
fuzz iterations**, clean, with a new ASCII surface (a pad differential on the plane's edges).
`print_version` → `kii 1.10.0`.

**1.9.1** — cut 2026-10-28. **Toolchain `6.7.12` → `6.7.18`, and every dependency to its
newest tag**: darshana `1.3.0` → `1.6.0`, cmdit `1.4.0` → `1.5.0`, chitra `1.2.0` → `1.3.1`.
The stdlib's sankoch moves 2.8.7 → 2.8.9. No kii code changed except `print_version` →
`kii 1.9.1` and comments.
- ⚠ **A PNG past 16 MiB of scanlines renders** (chitra 1.3.0) instead of being refused as
  `image too large to decode`. `IMG_ERR_INFLATE_LIMIT` is unreachable, kept so the map is
  total. Three large PNGs render identically to v1.9.0's render of the same pixels as BMP
  (24 of 24).
- ⚠ **What a valid PNG can cost rises**: up to ~913 MB peak RSS and ~10 s at the read and
  pixel caps, and ~327 MB from a 147 KB file
  ([ADR 0002](../adr/0002-security-model.md) § v1.9.1 amendment).
- A command line over 2 MiB is read whole (cmdit 1.4.2) instead of refused.
- Every other frame is byte-identical: 2,820 of 2,832 corpus cases (472 images × 6 flag sets),
  and the other 12 are those two oversize PNGs. With the deps held, the toolchain alone gives
  2,832 of 2,832.

**818 assertions** (x86_64 and aarch64; aarch64 frames match x86_64, 240 of 240); **8,011,000
fuzz iterations**, clean. Bench unchanged within ~1 %.

**1.9.0** — cut 2026-10-16. **Dithering and pixel-centre sampling**
([ADR 0011](../adr/0011-dithering.md), [ADR 0005](../adr/0005-nearest-neighbor-downscale.md)
amendment):
- **`--dither none|ordered|fs`** (`-d`) works at tiers 8, 16 and 256 in both lanes, and
  defaults to `none`. `ordered` is a 4×4 Bayer offset inside ±half a palette step;
  `fs` is Floyd-Steinberg in exact integers. On a grey ramp at tier 16, `fs` cuts the
  column-brightness error from 21.2 to 5.0. The ASCII lane dithers cell colours, as one
  field under `fs`. `--verbose` names an active mode.
- **Pixel-centre sampling** (C-7): `sx = ((2·dx + 1)·W) / (2·dst_w)`. Every downscaled
  frame changes (2,504 of 2,504 rendered corpus frames); identity and integer upscales do
  not. v1.8.0 with only this formula changed matches v1.9.0 byte for byte on all 2,796
  corpus frames, so the refactor around it changes nothing.

Dithered frames are larger (tier 16 ×1.8–2.0, tier 256 ×3.3–4.2 over the corpus) and, under `fs`,
cost 1.8 ms (half-block) to 2.2 ms (ASCII) more per render of a 256² icon at `--width 200`. The default path matches v1.8.0's
speed in both lanes: an early draft that ran the ASCII field pass for every mode cost
~19 %, so the pass now runs only under `fs`. **813 assertions** (x86_64 and aarch64;
aarch64 frames match x86_64 in every tier × mode, 648 of 648); **8,011,000 fuzz
iterations**, clean, with the emit surface rotating all 12 tier × dither pairs.
`print_version` → `kii 1.9.0`.

**1.8.0** — cut 2026-10-15. **Tier 2 colour and the emit rework**
([ADR 0010](../adr/0010-tier-2-colour-and-emit-encoding.md)). `--color` is now `8 | 16 |
256 | tc`, with 16 still the default and the environment still not consulted:
- **256** quantizes exactly to the xterm cube and grey ramp (indices 16–255);
- **tc** sends 24-bit `38;2;R;G;B`;
- **tiers 8 and 16** moved from `38;5;N` to the plain SGR 30–37 / 90–97 / 40–47 / 100–107
  a strict terminal parses (C-11);
- **elision:** each row writes an fg / bg escape only when it changes (O-5);
- **transparency:** alpha below 128 is drawn in the terminal's default colours, and
  half-block cells keep the opaque half with `▀` / `▄`.

Every frame's bytes changed, deliberately and once: opaque tier-8 / tier-16 frames replay
to the same cells as 1.7.0 (996 frames, both lanes); every opaque half of a transparent
image matches (1,344 frames); output is ~85 % smaller. **738 assertions** (x86_64 and
aarch64; aarch64 frames match x86_64 at every tier); **8,011,000 fuzz iterations**, clean,
with the emit surface now rotating all four tiers. `print_version` → `kii 1.8.0`.

**1.7.0** — cut 2026-10-15. **The format-neutral rename**, with the three code-health items
the v1.6.4 sweep pinned to it. `src/png.cyr` → `src/image.cyr`, `kii_decode_png` →
`kii_decode_image`, `png_color_type_name` → `kii_source_type_name`, and `PNG_ERR_*` →
`IMG_ERR_*` named for what each code means, every value unchanged. The rename alone
compiles to a byte-identical binary. Also: downscale accepts only chitra's RGBA8 (the
per-colour-type `_extract_rgb`, `_png_color_channels` and six dead pstruct slots are gone);
both render lanes share one frame loop (`_kii_emit_frame`, via `callptr`); and cmdit checks
`--width` (`cmdit_range`) and `--mode` (`cmdit_enum`), which changes those two flags' error
text and `--help`'s `--mode` line. Every frame is byte-identical to 1.6.4 (all 96 render cases of
the standard 130, and 932 runs over 466 system images). **710 assertions** (x86_64 and aarch64); **8,011,000 fuzz
iterations**, clean. `print_version` → `kii 1.7.0`.

**1.6.4** — cut 2026-10-15. **The P(-1) sweep**
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)): five lenses plus a
verification of the three zlib CVE-class transfers (all hold against sankoch 2.8.7),
every material finding refuted or confirmed independently. Repaired:
- **(MEDIUM)** a narrow image at an ordinary `--width` produced gigabytes of output
  (new `KII_MAX_CELLS` frame cap, 1,048,576 cells);
- pipes / `/dev/stdin` / FIFOs now render and a directory says so (single-open slurp
  via `file_read_whole_max`);
- transparent pixels composite over black instead of showing their hidden RGB;
- GIF errors no longer name PNG chunks; a zero dimension and the BMP compression line
  read correctly;
- a negative `--width` is a usage error; `--verbose` names the real tier; a 0-row TTY
  keeps its prompt row; the short-flag advice is right;
- the pstruct is zeroed; no raw syscall numbers remain; the geometry fuzz surface checks
  real invariants.

Three byte-identical speedups (quantize ~4×, ASCII matcher ~2×, an RGBA downscale fast
path) make small images ~2× faster at `--width 200`. Every opaque image renders
byte-identically to 1.6.3 (130 standard cases, 466 system images). **709 assertions**
(x86_64 and aarch64); **8,011,000 fuzz iterations**, clean. `print_version` → `kii 1.6.4`.

**1.6.3** — cut 2026-10-15. **Toolchain `6.7.9` → `6.7.12`, chitra `1.1.3` → `1.2.0`.**
darshana 1.3.0 and cmdit 1.4.0 are still the newest tags. No kii source changed except
`print_version` → `kii 1.6.3` and two comments. The 6.7.10–6.7.12 language changes were
audited against kii's source, not just built: the 6.7.12 compiler alone builds
byte-identical binaries to 6.7.9. The stdlib's sankoch moves 2.8.3 → **2.8.7**, which:
- **renders about 3.5× faster** end to end (RAMGON 723–863 ms → 204–245 ms), because 2.8.6
  replaced the Huffman slow path that was ~93 % of the render;
- **closes the 2.8.6 inflate floor** recorded at 1.6.1, so malformed deflate streams zlib
  refuses are now refused here too.

Output is byte-identical to 1.6.2: 130 of 130 cases, and 932 of 932 runs over 466 system
images. **642 assertions** (x86_64 and aarch64); **8,011,000 fuzz iterations**, clean. The
roadmap was rebuilt around pinned versions: a P(-1) sweep at 1.6.4, then 1.7.0–1.10.0, then 2.0.

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

- **Cyrius pin**: `6.7.18` (in `cyrius.cyml [package].cyrius`). `lib/` re-vendored from the 6.7.18 snapshot at 1.9.1 with `rm -rf lib && mkdir lib && rm cyrius.lock && cyrius deps` (was 6.7.12 at 1.6.3–1.9.0, 6.7.9 at 1.6.0–1.6.2, 6.6.2 at 1.5.2, 6.5.35 at 1.5.0). The stdlib's sankoch is **2.8.9** (2.8.7 at 6.7.12, 2.8.3 at 6.7.9).
- **Dependency resolution is git + tag only** (since 1.6.0). cyrius 6.7.6+ resolves the tag by default and checks the commit pin in `cyrius.lock`; kii's manifest no longer names any `path`, so a local build and CI compile the same bundles. To build against a sibling checkout, add its `path` in a local edit and use `cyrius build --local`.
- **`lib/` is 40 files** at 6.7.18, the same set as at 6.7.9 and 6.7.12 (39 at 1.5.x: the 6.7.9 allocator pulls in `alloc_cx.cyr` and `poison.cyr`, and `flags.cyr` is gone now that chitra ≥ 1.0.1's sidecar no longer lists it). History: it was 104 before 1.5.0. The tree had carried 62 undeclared stdlib bundles (`mabda`, `sigil`, `sandhi`, `patra`, `yukti`, `bayan`, `ganita`, `sakshi`, `vani`, …) that kii references nowhere — leftovers from an old full-snapshot vendor. They shadowed the pinned versions and produced a standing build warning. **`cyrius lib sync` cannot remove them** (it only overwrites declared modules); the canonical re-vendor is `rm -rf lib && mkdir lib && cyrius deps`. CI runs a plain `cyrius deps` on a fresh checkout, which amounts to the same thing (the committed `lib/` plus the lock).

## Surface

Full PNG + baseline JPEG + BMP + GIF → terminal-fit ANSI half-block frame pipeline (unchanged at the user-facing layer from v0.7.0; v1.4.0 added JPEG, v1.5.0 added BMP + GIF — same emit surface throughout):

- `kii image.png` in a TTY → detects terminal cols × rows via `tty_winsize(1)`, fits the image into `cols × (rows - 1)` aspect-preservingly, emits a frame sized to that envelope on stdout. Exit 0.
- `kii photo.jpg` (v1.4.0) → baseline JPEG decodes through chitra's JPEG path (signature-sniffed, not extension-keyed) and renders identically — `--mode ascii`, `--width`, `--verbose`, terminal-fit all apply. `--verbose` reports the source as `greyscale (JPEG)` / `YCbCr (JPEG)` / `RGB (JPEG)` (the `0x113` Adobe-`transform=0` sentinel, named since v1.5.0). Progressive / arithmetic / 12-bit / CMYK JPEG reject as `unsupported JPEG feature …` (chitra stays baseline-only).
- `kii art.bmp` (v1.5.0) → BMP renders through chitra: `BI_RGB` 1/4/8/16/24/32 bpp, `BI_RLE4`/`BI_RLE8`, `BI_BITFIELDS` with V4/V5 headers. `--verbose` names the source precisely from chitra's `0x200 | bpp` sentinel (`24bpp (BMP)`, `4bpp palette (BMP)`, …). Unsupported bpp / `BI_JPEG` / `BI_PNG` / a bad channel mask reject as `unsupported BMP feature …`.
- `kii art.gif` (v1.5.0) → GIF87a/89a renders through chitra's LZW path, interlaced frames included. **First frame only** (chitra ADR 0005) — correct for a still-frame renderer. Source named `palette (GIF)` from the `0x300 | min_code_size` sentinel. A GIF whose LZW stream ends early still renders, with the tail zero-filled and a `warning: incomplete GIF (truncated frame — tail zero-filled)` on stderr.
- `kii image.png > out.ansi` (non-TTY) → falls back to 80×24 BBS-default; identical frame shape regardless of where stdout lands.
- `kii --width N image.png` → exactly N cells wide; height aspect-derived without a row cap.
- `kii --verbose image.png` adds the M4-shape summary line to **stderr** after the frame.
- `kii --dither ordered|fs image.png` (v1.9.0) → the quantizer dithers, with a 4×4 Bayer offset or Floyd-Steinberg error diffusion, at tiers 8 / 16 / 256 in either lane. `none` is the default, and at `--color tc` the flag changes nothing. See [ADR 0011](../adr/0011-dithering.md).
- `kii --mode ascii image.png` → character-glyph "ASCII art" lane (v1.3.1 shape-vector: 2×3 sub-grid matched to glyph coverage → orientation-aware `/ \ | - _ ( ) ^`, colored fg; since v1.11.0 each sub-sample is its area's mean) instead of the half-block default. `--mode halfblock` (default) is the `▀` floor. See [ADR 0007](../adr/0007-rendering-mode-taxonomy.md).
- Missing IEND → frame + stderr warning + exit 0 (per spec § 5.3 tolerance).
- **Decode rejection paths** (the M7(c)/M8 guards now live inside chitra; kii maps
  `ChitraErr` → `IMG_ERR_*` for byte-stable stderr): dimensions/ratio bombs →
  `IMG_ERR_DIMENSIONS` (12); OOM / IDAT-too-large → `IMG_ERR_MEMORY` (13);
  duplicate/late PLTE, palette-OOB, non-zero IEND, bad chunk → `IMG_ERR_MALFORMED` (4);
  color_type=3 + bit_depth=16 → `IMG_ERR_BITDEPTH` (8); zero IDAT → `IMG_ERR_NO_IMAGE_DATA` (9).
  Reserved (unreachable via chitra, kept for the stable code space): `IMG_ERR_SHORT_FILE`
  (2, a <8-byte file now reports `unrecognized image format`) and `IMG_ERR_RATIO_TOO_HIGH` (14, the ratio
  bomb arrives as `DIMENSIONS`). See [ADR 0006](../adr/0006-adopt-chitra-decoder.md).
- **BMP + GIF rejection paths** (v1.5.0, chitra's eleven new `ChitraErr` codes 24–34 mapped onto the existing error-code space rather than minting new codes — see [ADR 0009](../adr/0009-bmp-gif-via-chitra.md)): BMP header/palette/RLE corruption and GIF header/palette corruption → `IMG_ERR_MALFORMED` (4), phrased per format; BMP bpp outside `{1,4,8,16,24,32}` / `BI_JPEG` / `BI_PNG` / bad `BI_BITFIELDS` mask → `IMG_ERR_UNSUPPORTED` (16); GIF LZW corruption → `IMG_ERR_DECOMPRESS` (10); a structurally valid GIF with no image descriptor → `IMG_ERR_NO_IMAGE_DATA` (9); `CHITRA_ERR_BUDGET` → `IMG_ERR_MEMORY` (13, unreachable today — kii calls the unbudgeted entry point).
- **New `IMG_ERR_FILE_TOO_LARGE` (15)** — input file > 256 MB rejected before the in-memory
  slurp (a DoS guard the old streaming decoder didn't need).
- **New `IMG_ERR_INFLATE_LIMIT` (17)** (v1.6.0) — a valid PNG whose pixel data inflates past sankoch's 16 MiB `DECOMPRESS_MAX_OUTPUT` (≈ 5.6 MP of RGB) is refused before allocation (chitra 1.0.1's `CHITRA_ERR_INFLATE_LIMIT`) and reported as `image too large to decode (…)`; through v1.5.2 it read "malformed PNG". **Unreachable since v1.9.1**: chitra 1.3.0 inflates to the size IHDR implies, so such a PNG decodes. The code, its arm and its text stay.
- **M7(c) stderr hardening** (stays in kii, never decoder code): a filename that is not safe to echo is substituted with `<path containing control bytes — suppressed>` before stderr emit; CVE-2021-25743-analog injection vector closed. Since v1.6.0 the rule is darshana's `tty_has_ctl` in UTF-8 mode with TAB and LF kept: C0 except TAB/LF, DEL, raw C1, `C2 80`–`C2 9F`, and any malformed or non-RFC-3629 UTF-8 (overlong forms, surrogates and code points past U+10FFFF included).

Module map:

- `src/main.cyr` — I/O glue + dispatch. Two-path geometry resolver (`--width N` → M6(a); else `tty_winsize` → `_kii_term_envelope` → M6(b) fit). M7(c) added `_eprint_path_safe` helper routing path bytes through the sanitizer.
- `src/cli.cyr` — CLI parse helpers + `KII_F_*` indices (width/color/verbose/**mode**). v1.6.2 added `kii_parse_error_line(err)` (the stderr line for each cmdit error code) and `kii_err_flag_name(fs)` (the long name of the flag an error names); v1.6.4 added the frame cap `KII_MAX_CELLS` / `kii_frame_cells_ok(cols, rows)`. Since v1.7.0 `--width` is range-checked by `cmdit_range` and `--mode` is a `cmdit_enum` (`KII_MODE_HALFBLOCK` / `KII_MODE_ASCII`); the hand-rolled `kii_validate_mode`, `kii_mode_is_ascii` and `kii_width_error_line` are gone. Since v1.8.0 `--color` is a `cmdit_enum` too (`8|16|256|tc`, mapped by `kii_color_tier`; `kii_validate_color` is gone), and `kii_parse_error_line(err, flag)` takes the flag so BAD_ENUM names `--color` or `--mode`. Since v1.9.0 `--dither` is a `cmdit_enum` (`none|ordered|fs`, short `-d`, mapped by `kii_dither_mode`), with its own BAD_ENUM line. M7(c) added `kii_path_has_control_bytes(path)` — since v1.6.0 a wrapper over darshana's `tty_has_ctl`.
- `src/ascii.cyr` — **character-glyph lane** (v1.3.0 ramp → v1.3.1 shape-vector): `_ascii_luma` (Rec.709), `_ascii_match` (6-region nearest-glyph), `_ascii_lum_plane` + `_ascii_contrast` (v1.10.0: the frame's luminance once per frame, then directional and global contrast enhancement per lit cell, exact integers), `emit_ascii_shape_row_buf` (testable; since v1.9.0 it takes an optional cell-code buffer, and since v1.10.0 the plane and the sample height) + `emit_ascii_shape`, which since v1.7.0 runs through the shared `_kii_emit_frame` (src/emit.cyr). `_ascii_cell_codes` (v1.9.0) quantizes every cell's mean colour as one field, which only `--dither fs` needs.
- `src/ascii_shape.cyr` — **generated** by `scripts/gen-shape-table.sh` (v1.10.0): the 27-glyph coverage table (`ASCII_SHAPE_*`, `_ascii_shape_init`), inline in `src/ascii.cyr` from v1.3.1 to v1.9.1. Never hand-edited; `./scripts/gen-shape-table.sh --check` proves the committed file is the script's output (ImageMagick 7 + Liberation Mono, so not in CI).
- `src/image.cyr` — **the chitra image adapter** (`src/png.cyr` until v1.7.0; before the v1.2.0 re-fold, the 813-line native decoder). Decodes all four formats: `kii_decode_image` zeroes the pstruct, reads the file once with `file_read_whole_max` under a 256 MB cap (`KII_MAX_RAW_BYTES` = chitra's `CHITRA_MAX_RAW_BYTES`; pipes and `/dev/stdin` work, a directory is `IMG_ERR_IS_DIR`), sniffs the signature four ways (PNG→JPEG→BMP→GIF, matching chitra's own routing order), calls `chitra_image_decode`, and writes the canonical RGBA8 into the pstruct as a depth-8 ct6 image. Owns the `IMG_ERR_*` code space (18 codes, renamed from `PNG_ERR_*` at v1.7.0 with every value unchanged; `IMG_ERR_INFLATE_LIMIT` added at v1.6.0, `IMG_ERR_IS_DIR` at v1.6.4) and the text of every decode diagnostic (`kii_decode_error_text`, `kii_incomplete_warning_text`, v1.6.4), the 20-slot `STRUCT_*_OFFSET` layout (160 bytes; `SRC_COLOR_TYPE`=144, `FORMAT`=152; the six dead native-decoder slots retired at v1.7.0, offsets kept), `KII_FMT_*`, `kii_source_type_name` (every PNG colour type plus the JPEG `0x100|ncomp`, BMP `0x200|bpp` and GIF `0x300|min_code_size` sentinels), `_kii_map_read_err` (the slurp's errno), and `_kii_map_chitra_err` (all 35 `ChitraErr` codes; 35 = `CHITRA_ERR_INFLATE_LIMIT`, mapped at v1.6.0, unreachable since chitra 1.3.0 / v1.9.1). Every parser and security guard — signature/IHDR/CRC/inflate/unfilter/PLTE, JPEG markers/Huffman/IDCT, BMP DIB/RLE/BITFIELDS, GIF LZW — lives in chitra.
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — the colour tier (`quant_set_tier`, `KII_TIER_8` / `_16` / `_256` / `_TC`) and colour codes: tier-1 `quantize_nearest_rgb` (since v1.6.4 it reads the packed palette inline, ~4× faster), tier-256 `quantize_256` (v1.8.0, exact over indices 16–255), `kii_color_code` (a pixel's 32-bit code at the active tier; `KII_COLOR_DEFAULT` = transparent) + `quantize_rgb_buf(rgb, mask, w, h, out)` / `quantize_downscaled` (4 bytes a pixel since v1.8.0; `w` and `h` since v1.9.0). Dithering (v1.9.0): `quant_set_dither` (`KII_DITHER_NONE` / `_ORDERED` / `_FS`), `_quant_bayer_offset` over the packed 4×4 matrix, `kii_color_code_at` (one pixel with its ordered offset), and `_quant_fs` (Floyd-Steinberg, errors ×16 in two i64 rows). The M4 `quantize_nearest_image` was removed at the re-fold (it read native color_type/PLTE that no longer reach the pstruct).
- `src/downscale.cyr` — the RGB resamplers over chitra's RGBA8, the only pixel format they accept since v1.7.0 removed the per-colour-type `_extract_rgb`; alpha below `KII_ALPHA_THRESHOLD` (128) is marked in the transparency mask (`STRUCT_ALPHA_MASK_OFFSET`, v1.8.0), and partial alpha above it is composited over black (`_over_black`). `downscale_to_rgb(pstruct, target_w, target_src_rows)` is nearest-neighbour, sampling each span's centre since v1.9.0 (C-7), for the half-block lane. `downscale_area_to_rgb(pstruct, cols * 2, rows * 3)` (v1.11.0) is the ASCII lane's area sampler: each sample is the mean of its span (whole up to `KII_AREA_TAPS` = 4 pixels, 4 taps beyond; `_area_bound`, `_area_taps`), it writes the luminance plane, and with no reduction it hands off to `downscale_to_rgb`.
- `src/emit.cyr` — Half-block ANSI emit: since v1.8.0 the tier-aware `_kii_sgr_fg` / `_kii_sgr_bg` (darshana `tty_sgr_buf`, `tty_fg/bg_256_buf`, `tty_fg/bg_rgb_buf`), per-row elision, and ▀ / ▄ / space for transparent halves (the local `_emit_bg_256_buf` was retired at v1.6.0) + geometry primitives (`_kii_compute_target_geometry` for explicit-width, `_kii_compute_fit_geometry` for terminal-fit, and `_kii_term_envelope`, v1.6.0, turning a `tty_winsize` answer into the fit envelope — columns and rows decided separately, one row kept for the prompt, including on a TTY that reports 0 rows since v1.6.4). Default constants `EMIT_DEFAULT_COLS = 80` / `EMIT_DEFAULT_ROWS = 24`. `_kii_write_all` (short-write-safe stdout); `_kii_emit_frame` and `_kii_row_end`, the frame loop and row ending both lanes share (v1.7.0).
- `tests/` — split from the monolithic `tests/kii.tcyr` into focused standalone suites at the re-fold (matches chitra's `tests/tcyr/*.tcyr` convention): `tests/cli.tcyr` (cmdit/flags + path-sanitizer), `tests/quant.tcyr` (palette + quantize), `tests/render.tcyr` (downscale + emit + geometry), `tests/ascii.tcyr` (`--mode ascii` shape-vector), `tests/decode.tcyr` (`kii_decode_image` PNG **+ JPEG + BMP + GIF** e2e + `_kii_map_chitra_err` incl. the 11 JPEG and 11 BMP/GIF/budget codes and `INFLATE_LIMIT` + every source-sentinel name + `KII_FMT_*` tag + sankoch zlib round-trip), and `tests/render.tcyr` carries JPEG, BMP and GIF render e2e. **877 assertions** total (cli 203 + quant 171 + render 223 + ascii 67 + decode 213); at v1.11.0 render went 194 → 223 (the area sampler: a pixel point sampling misses, exact and tapped spans, enlargements equal to `downscale_to_rgb`, one axis reduced, coverage-weighted luminance and the mask, a stale plane cleared); at v1.10.0 ascii went 37 → 67 (the generated table's properties, the power table and the step over its whole domain, contrast scenarios, all ten externals one at a time, the plane's luma); at v1.9.1 decode went 208 → 213 (`oversize.png` decodes, every pixel checked, and the 16 MiB pin dropped); at v1.9.0 cli went 184 → 203 (`--dither` parse, map and error line), quant 133 → 171 (the dither contract, the Bayer matrix, palette colours left alone, mid-grey mixes, Floyd-Steinberg's carried error, transparency and truecolour under every mode), ascii 23 → 37 (the cell-code field, and per-cell ordered agreeing with it) and render 190 → 194 (pixel-centre picks at 10 → 1 / 2 / 5 / 10). At v1.8.0 cli went 171 → 184 (the `--color` enum), quant 115 → 133 (tier 256 against a full scan, colour codes), ascii 17 → 23 and render 199 → 190 (byte-offset pins of the old `38;5;N` rows replaced by whole-row checks per tier, elision and transparency). Decoder-internal coverage lives in chitra's suite.
- `tests/fixtures/oversize.png` — v1.6.0: a valid 2370×2370 black RGB PNG (16,447 bytes on disk, 16,853,070 inflated), just past sankoch's 16 MiB `DECOMPRESS_MAX_OUTPUT`; ImageMagick-verified. Drove `IMG_ERR_INFLATE_LIMIT` end to end through v1.9.0; since v1.9.1 it pins that such a PNG decodes.
- `tests/fixtures/gradient.bmp` + `tests/fixtures/color.gif` — v1.5.0 fixtures: 16×16 24-bpp `BI_RGB` white→black ramp (px0=0, px1=17, px2=34, stepping by 17) and a 16×16 GIF89a with four flat quadrants (red / lime / blue / white). Both pixel-verified against ImageMagick as the oracle.
- `tests/fixtures/{gradient,color}.jpg` — v1.4.0 JPEG fixtures: 16×16 grayscale (chitra's ImageMagick-verified gradient, src ctype 257) + 8×8 YCbCr 4:4:4 (src ctype 259).
- `tests/kii.fcyr` — **ten** fuzz surfaces (arg-parser, path-sanitizer, geometry, emit-pipeline, **PNG, JPEG, BMP, GIF**, and since v1.6.0 the **path-sanitizer differential** against the v1.5.2 walk and the **terminal envelope**); all four decode surfaces aimed through `kii_decode_image`, each prefixing its format signature so the payload reaches that decoder, and each pairing `alloc_reset()` with `crc32_table = 0` (JPEG = SOI + random bytes, generational/bounded). Since v1.6.0 a non-zero `bad` count on any surface exits 1 with `fuzz: FAIL`. Since v1.6.4 the geometry surface checks the geometry contract and the frame-cell predicate, not just the return code (an off-by-one in the `--width` row count fails 999,970 of 1M iterations).
- `tests/kii.bcyr` — benches (quantize + end-to-end RAMGON + decode latency); decode bench re-aimed through `kii_decode_image`.
- `tests/fixtures/RAMGON.png` — real-world fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: **997 KB** on host at v1.11.0 (`build/kii` = 1,020,648 bytes, unstripped, DCE off). `--agnos` 1,039,024 bytes; `--aarch64` 1,241,600 bytes. At v1.10.0: 1,016,552 host, `--agnos` 1,030,824, `--aarch64` 1,241,592. At v1.9.1: 1,008,328 host (1,210 unreachable fns, ~585 KB, eliminable with `CYRIUS_DCE=1`), `--agnos` 1,022,600, `--aarch64` 1,237,464. At v1.9.0: 1,012,280 host, `--agnos` 1,026,520, `--aarch64` 1,237,312. At v1.8.0: 1,003,824 host, `--agnos` 1,018,072, `--aarch64` 1,237,064, back over the 64 KiB segment boundary (padding, not code). At v1.7.0: 999,568 host, `--agnos` 1,013,816, `--aarch64` 1,171,360. At v1.6.4: 999,656 bytes host (1,205 unreachable fns, ~572 KB, eliminable with `CYRIUS_DCE=1`), `--agnos` 1,013,904, `--aarch64` 1,236,984, of which 64 KiB was segment-alignment padding (the text grew 2,280 bytes across a 64 KiB boundary). At v1.6.3: 976 KB (`build/kii` = 999,328 bytes, unstripped, DCE off; the compiler reports 1,209 unreachable fns, ~574 KB, eliminable with `CYRIUS_DCE=1`). The +75,240 bytes over v1.6.2 (924,088) are the stdlib's sankoch 2.8.7 bundle, mostly its new Brotli encoder; kii links it as a stdlib leaf and calls only inflate and CRC-32. `--agnos` 1,013,568 bytes; `--aarch64` 1,171,128 bytes. At v1.6.1 it was 923,976 bytes, the growth from the cmdit 1.4.0 and chitra 1.1.3 bundles. At v1.6.0 it was **877 KB** (898,344 bytes), up from 683,584 bytes for v1.5.2 rebuilt from its own tree at 6.6.2: the growth is the 6.7.9 toolchain and the larger darshana 1.3.0 bundle — kii's own source got smaller (the local BG composer and the hand-rolled UTF-8 walk are gone). `--agnos` 908,376 bytes; `--aarch64` 1,086,544 bytes. Earlier: **668 KB** at v1.5.1 (`build/kii` = 683,576 bytes, unstripped, DCE off). The `~145 KB` this section reported was measured at v0.8.0 and never refreshed across the cmdit fold, the chitra re-fold, or the JPEG/BMP/GIF folds — it was low by **4.6×**. Most of the size is the vendored `chitra` bundle carrying four decoders plus `sankoch`; the compiler reports ~942 unreachable fns (~390 KB) eliminable with `CYRIUS_DCE=1`. kii gained no module at v1.5.0 or v1.5.1. (Corrected at the v1.5.1 P-1 sweep.)

## Tests + bench

- `cyrius test` → **877 assertions, all pass** across 5 split suites (cli 203 / quant 171 / render 223 / ascii 67 / decode 213), plus the `[build].test` entry `src/test.cyr` (6 entries). v1.6.2 added 43 in cli: the bool `=value` refusal naming its flag, and the exact parse-error line for every cmdit code. v1.6.0 added 49: cli +21 (strict RFC 3629 boundaries, both overlong CSI spellings, the `tty_has_ctl` wiring), render +24 (all 256 BG indices byte-identical to the retired composer, `_kii_term_envelope` incl. 1-row and half-set winsizes), decode +4 (`PNG_ERR_INFLATE_LIMIT` mapping + oversize fixture + format tag + the 16 MiB pin). The same five suites also pass under `cyrius test --aarch64` (qemu-aarch64). v1.5.1 added 39 (P-1 regressions: C1 sanitizer coverage in both encodings, the `--color` tier contract, the downscale overflow guard, and the `_emit_bg_256_buf` negative-pos guard). At v1.5.0 decode grew 105 → 166 (+61: BMP + GIF e2e against ImageMagick-verified fixtures, the eleven BMP/GIF/budget error mappings, the nine new source-sentinel names plus four range-boundary guards, and a non-image UNKNOWN-tag case) and render grew 137 → 156 (+19: BMP and GIF decode→downscale→quantize→emit e2e, including a real content check that the GIF's pure-red and pure-lime quadrants quantize to palette entries 1 and 2 — the NORMAL entries, not the bright ones, because nearest-RGB puts pure (255,0,0) at 85² from entry 1 but 85²+85² from entry 9). **`tests/quant.tcyr`'s 109 assertions run again for the first time since v1.2.0** — 48 palette calls passed two arguments to the three-argument `assert_eq(a, b, name)`, so the suite had been failing to compile; the v1.4.1 cut missed it by verifying only the render suite. decode grew 51 → 105 at v1.4.0 (+54 JPEG: 11 error mappings + sentinel names + format tag + grayscale & YCbCr e2e with pixel/chroma/row checks + progressive/malformed stubs); render +8 (a JPEG decode→downscale→quantize→emit e2e). Decoder-internal coverage lives in chitra's suite.
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → **8,151,000 iters, all clean, exit 0** (~64–87 s wall at v1.6.3–1.6.4, 59 s at v1.9.1, 71 s at v1.10.0, 86 s at v1.11.0; peak RSS **137,848 KB** at v1.6.0, ~123 MB at v1.9.1 through v1.11.0). v1.11.0 added the twelfth surface, the area sampler (100,000 random images up to 48 × 48 downscaled to up to 96 × 64; each between pads of 0 and of 255, which must match, and every sample checked against the definition; nine of eleven planted defects fail it, the other two are equivalent), run last. v1.10.0 added the eleventh surface, the ASCII lane (40,000 random frames, each rendered with the luminance plane between pads of 0 and of 255, which must match; dropping either edge guard fails ~95 % of frames), run last so the older surfaces keep their random stream. The v1.6.0 surfaces: the path-sanitizer differential (1M; per run ≈ 284k inputs both walks accept, ≈ 203k only the strict RFC 3629 rule refuses, the rest both refuse; `bad=0`) and the terminal envelope (1M, `bad=0`); both were checked to fire on a deliberately wrong implementation. At v1.5.1 the harness ran 6,011,000 iters at ~136 MB. **The PNG surface only became real at v1.5.1**: the per-iteration `alloc_reset()` that bounds the heap also invalidated sankoch's cached CRC-32 table (a lazy-init singleton holding a heap pointer), so from iteration 2 onward 2999 of every 3000 inputs died at the signature check rather than reaching the chunk walker, inflate, unfilter or the PLTE bounds. Every `alloc_reset()` is now paired with `crc32_table = 0`; the measured return-code tally afterwards matches a no-reset run exactly. Ten surfaces: 10k arg-parser + 1M path-sanitizer + 1M geometry + 1k emit-pipeline + 1M PNG + 1M JPEG + 1M BMP + 1M GIF + **1M path-sanitizer differential** + **1M terminal envelope** (the last two run after the rest, so the first eight consume the same random stream they did through v1.5.2). sankoch's arena canary (2.7.10+) now also drops the CRC table on a reset; the `crc32_table = 0` lines are kept as a second guard. Each decode surface prefixes the real format signature (`\x89PNG`, `\xFF\xD8`, `BM`, `GIF89a`) so the random payload actually reaches that decoder rather than bouncing off the sniff. All four decode surfaces call `alloc_reset()` to rewind the never-free bump allocator each iteration (a matched signature makes chitra allocate marker/header/palette scratch before the input fails) — without it the heap would grow unboundedly. The **GIF surface is the highest-value of the four**: LZW builds a dictionary from attacker-controlled codes, the classic GIF-decoder CVE class.
- Output size per tier is in [`docs/benchmarks.md`](../benchmarks.md) § v1.8.0 (RAMGON at 80 columns: 14,609 bytes at tier 16, was 54,353; 94,307 at truecolour), and per dither mode in § v1.9.0 (14,553 bytes at tier 16 with `none`, 23,222 `ordered`, 23,753 `fs`). Timing (§ v1.6.4; measured at 6.7.12, two runs, so ranges):
  - `quantize_nearest_rgb @ 1024×1024`: **71–74 ns/op** (was ~290 ns before v1.6.4's inline palette read)
  - `end-to-end RAMGON.png → 80×24 frame`: **202–213 ms/iter**
  - `end-to-end RAMGON.png → 120×40 frame`: **200–210 ms/iter**
  - `end-to-end RAMGON.png → 200×60 frame`: **203–209 ms/iter**
  - At v1.9.1 (§ v1.9.1, 6.7.18, three runs interleaved with v1.9.0): quantize 67–68 ns, RAMGON 192–194 ms at all three sizes, the 256² decode 1.09–1.14 ms, the 2048² decode 359–360 ms. Every row matches v1.9.0 within ~1 %.
  - At v1.11.0 (§ v1.11.0): the ASCII lane's area sampler costs 5.93 → 5.96 ms on a 256² icon at `--mode ascii --width 200` (handed off: no reduction), 2.46 → 2.88 ms at `--width 80`, RAMGON 201.4 → 202.9 ms at 80 and 209.8 → 216.3 ms at 200, a 16 MP PNG 451.8 → 452.2 ms, and a 6 MP BMP 132.2 → 162.0 ms at `--width 400`. The new `kii-bench` rows sample a decoded RAMGON: 0.11 ms by point against 1.65 ms by area at 160 × 96, 0.65–0.70 against 7.79–7.87 ms at 400 × 240; the existing rows match v1.10.0 within ~1 %.
  - At v1.10.0 (§ v1.10.0): the `kii-bench` rows match v1.9.1 within 1 %. The ASCII lane pays for contrast enhancement: a 256² icon at `--mode ascii --width 200` 5.26 → 5.98 ms per run, RAMGON 203.9 → 207.3 ms; half-block is unchanged (3.12 ms).
  - RAMGON's time is chitra's decode (~83 % sankoch's inflate); kii's own stages are ~0.6 %. On a 256² icon they dominate: `--width 200` renders in 7.7 ms whole-process (16.7 ms at v1.6.3), `--mode ascii --width 200` in 11.5 ms (22.8).
  - **M7(d) decode-latency matrix** (DoS-bound):
    - `png_decode 256² class` (archlinux-logo 256×256, palette): **1.18–1.19 ms**
    - `png_decode 1024² class` (starfield 1597×1198, RGB): **SKIPPED** — the system fixture no longer ships on the dev host; the bench prints an explicit skip line rather than vanishing (v1.5.1)
    - `png_decode 2048² class` (elarun-bg 2560×1600, RGB): **370–383 ms**
    - Per-pixel decode throughput is content-dependent (compression-ratio-driven), not strictly size-dependent.

## Dependencies

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `sankoch`, `thread` (`flags` dropped at the v1.1.0 cmdit re-fold). `sankoch` + `thread` stay post-decoder-re-fold — chitra's dist resolves `zlib_decompress`/`crc32`/`mutex` from kii's stdlib list, and kii's tests call `zlib_decompress` directly.
- **External** (git + tag, no `path` since v1.6.0): **`darshana 1.6.0`** + **`cmdit 1.5.0`** + **`chitra 1.3.1`** (image decoder; added at the v1.2.0 re-fold, re-pinned 0.2.0 → 0.2.1 at v1.2.2 → 0.3.0 at v1.4.0 → 1.0.0 at v1.5.0 → 1.0.3 at v1.6.0 → 1.1.3 at v1.6.1 → 1.2.0 at v1.6.3 → 1.3.1 at v1.9.1). All three are the newest tags at 1.9.1 (darshana was 1.3.0 and cmdit 1.4.0 from 1.6.1 to 1.9.0). chitra ≥ 1.1.0 declares its own `[deps.sankoch]` (`zlib` profile, 2.8.9 at chitra 1.3.1). kii's stdlib `sankoch` leaf takes precedence, so the profile is never vendored, and `cyrius.lock` carries only its commit pin. The stdlib sankoch at 6.7.18 is 2.8.9 (2.8.7 at 6.7.12), above the 2.8.6 floor chitra documents for zlib-strict inflate (it was 2.8.3, below it, through v1.6.2). Through v1.5.2 the manifest said darshana 1.0.0 / cmdit 1.2.4 / chitra 1.0.0 but the `path` overrides compiled 1.1.2 / 1.2.5 / 1.0.3. darshana supplies every escape kii writes (`tty_fg_256_buf`, `tty_bg_256_buf`, `tty_sgr_reset_buf`), the terminal size (`tty_winsize`) and the path-echo rule (`tty_has_ctl`); cmdit owns CLI parsing; chitra owns image decode (`dist/chitra.cyr`) via `chitra_image_decode` — the **full PNG matrix** (all bit depths 1/2/4/8/16 + Adam7 interlace) **plus baseline JPEG** (grayscale + YCbCr, 4:4:4 / 4:2:2 / 4:2:0, DRI/RST).

## Cycle context

v1.0.0 ships during agnos kernel cycle **1.32.x networking-arc**. kii lands as substrate for the BBS / MUD apps that are downstream cycles (ideated but not yet built); v1.0 freeze is explicit about NOT bundling consumer integration with the substrate ship.

## Next

**Sequencing lives in [`roadmap.md`](roadmap.md)** — this file is the current snapshot,
not a plan, and keeping a second ordered list here is how the two drift apart. The
roadmap is forward-facing only: anything shipped is deleted from it rather than checked
off, so if an item appears there it is genuinely still open.

In brief, what is open as of v1.11.0 (the roadmap pins each to a version; no 1.x release is pinned):

- **Gated on upstream** — progressive JPEG, on a `chitra` re-pin. (PNG past 16 MiB shipped at v1.9.1.)
- **Not scheduled** — cross-terminal verification, the zugot recipe, the first BBS/MUD consumer.
- **2.0** — full Block Elements glyph vocabulary, then Tier 3 (Sixel / Kitty / iTerm2).
