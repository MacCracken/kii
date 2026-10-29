# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Module map (v2.0.0)

The pipeline runs top to bottom; each module owns one stage. The shared `pstruct` (function-scope `var pstruct[160]` in `src/main.cyr`) carries data between stages via byte-offset slots declared in `src/image.cyr`. kii has no decoder of its own: since the v1.2.0 re-fold every format is parsed inside `chitra` ([ADR 0006](../adr/0006-adopt-chitra-decoder.md)), and `src/image.cyr` (`src/png.cyr` until v1.7.0) is the adapter that feeds it. Redrawn at v1.6.4; the v0.7.0 map showed the in-repo chunk walk, sankoch inflate and filter undo that the re-fold deleted.

```
  argv ─► cli.cyr     flag table (cmdit checks --width's range and the
             │        --color / --mode / --dither choices);
             │        path sanitizer for every echoed filename
             ▼
          main.cyr    orchestrator; every diagnostic goes to stderr as
             │        "<path>: <msg>"
             ▼
          image.cyr   kii_decode_image
             │          file_read_whole_max(path, 256 MB)   one open, read to EOF
             │          signature sniff → KII_FMT_*         for per-format messages
             │          chitra_image_decode ─────────────►  [deps.chitra]: PNG / JPEG /
             │                                              BMP / GIF parsing and every
             │                                              input guard → RGBA8
             │          adapter: RGBA8 into pstruct as depth-8 color_type 6
             ▼
          emit.cyr    geometry: --width N, or the terminal via _kii_term_envelope
          cli.cyr     kii_frame_cells_ok: at most KII_MAX_CELLS (1,048,576) cells
             ▼
          downscale.cyr  half-block: downscale_to_rgb, nearest-neighbour at
             │           each span's centre (v1.9.0), cols × rows·2
             │           ascii: downscale_area_to_rgb, each span's mean
             │           (v1.11.0), cols·2 × rows·3, + the luminance plane
             │           alpha < 128 → the transparency mask, partial
             │           alpha over black
     ┌───────┴──────────────────────┐
     ▼ --mode halfblock (default)   ▼ --mode ascii   (--mode blocks: blocks.cyr,
                                                       8×8 samples a cell from the
                                                       decoded pixels, v2.0.0)
  quant.cyr  quantize_downscaled   ascii.cyr  emit_ascii_shape
  (a 32-bit colour code per pixel   2×3 shape match picks the glyph;
   for the --color tier, dithered   the cell's mean colour goes through
   per --dither)                     kii_color_code_at for its fg (under
     ▼                               --dither fs, every cell's colour is
  emit.cyr   emit_halfblock          quantized first, as one field)
  (tier SGR, elision, ▀ / ▄ / space for transparency)
     │                                    │
     └──────────────┬─────────────────────┘
                    ▼
          emit.cyr  _kii_emit_frame: one row at a time, written with
                    _kii_write_all (both lanes share it since v1.7.0)
                    ▼
            stdout (fd 1): the ANSI frame, nothing else
```

| Module | Owns | Since |
|---|---|---|
| `src/main.cyr` | I/O + orchestration; dispatches each stage; prints every diagnostic via `_eprint_path_msg` / `_eprint_path_safe`; gates the `--verbose` summary | M0, restructured each milestone |
| `src/cli.cyr` | Flag registration (`--width` through `cmdit_range`; `--mode`, `--color` and `--dither` through `cmdit_enum`, since v1.7.0, v1.8.0 and v1.9.0) and the maps from an enum choice to kii's constant (`KII_MODE_*`, `kii_color_tier`, `kii_dither_mode`); `KII_F_*` indices; `KII_MAX_COLS`; `KII_MAX_CELLS` and `kii_frame_cells_ok` (the frame-size cap, v1.6.4); `kii_parse_error_line`; `kii_path_has_control_bytes` (a wrapper over darshana's `tty_has_ctl` since v1.6.0) | M1 + M7(c) |
| `src/image.cyr` | The chitra adapter (`src/png.cyr` until v1.7.0): `kii_decode_image` (read, sniff, decode, adapt); the `IMG_ERR_*` code space; `_kii_map_read_err` (read errno → `IMG_ERR_*`, v1.6.4); `_kii_map_chitra_err` (`ChitraErr` → `IMG_ERR_*`); `kii_decode_error_text` and `kii_incomplete_warning_text` (the text of every decode diagnostic and warning, v1.6.4); `kii_source_type_name`; the `STRUCT_*_OFFSET` layout | M2, adapter since v1.2.0 |
| `src/palette.cyr` | Linux-console 16-color ANSI palette + lazy init + accessors | M4(a) |
| `src/quant.cyr` | RGB → colour codes: `quant_set_tier` (the `--color` tier: `KII_TIER_8` / `_16` / `_256` / `_TC`), tier-1 `quantize_nearest_rgb`, tier-256 `quantize_256` (v1.8.0), `kii_color_code` (a pixel's code at the active tier; `KII_COLOR_DEFAULT` = transparent), and `quantize_rgb_buf` + `quantize_downscaled` for the half-block lane; dithering (v1.9.0): `quant_set_dither`, the 4×4 Bayer offset, `kii_color_code_at` (one pixel, with its ordered offset), and the Floyd-Steinberg pass `_quant_fs` | M4(b)(d) + M5(c) + v1.9.0 |
| `src/downscale.cyr` | The RGB resamplers over chitra's RGBA8 (the only pixel format since v1.7.0 removed the per-colour-type dispatch), with `_over_black` compositing alpha over black (v1.6.4). `downscale_to_rgb`: nearest-neighbour, sampling each span's centre since v1.9.0, for the half-block lane. `downscale_area_to_rgb` (v1.11.0): the ASCII lane's area sampler, each sample the mean of its span (whole up to 4 pixels, 4 taps beyond, via `_area_bound` / `_area_taps`), which also writes the luminance plane; with no reduction it hands off to `downscale_to_rgb` (ADR 0005 amendments) | M5(b), area v1.11.0 |
| `src/emit.cyr` | Half-block ANSI emit (darshana composers) + `_kii_compute_target_geometry` + `_kii_compute_fit_geometry` + `_kii_term_envelope` (v1.6.0) + `_kii_write_all`; the frame loop and row ending both lanes share, `_kii_emit_frame` and `_kii_row_end` (v1.7.0); the tier-aware SGR composers `_kii_sgr_fg` / `_kii_sgr_bg` and the row's elision and transparency glyph rules (v1.8.0) | M5(c) + M6(a)(b) |
| `src/ascii.cyr` | The `--mode ascii` lane: `_ascii_lum_plane` (the frame's luminance, once per frame) and `_ascii_contrast` (directional then global contrast enhancement, v1.10.0), `_ascii_match`, `emit_ascii_shape`; `_ascii_cell_codes`, the cell-colour field `--dither fs` needs (v1.9.0) | v1.3.0, shape-vector v1.3.1 |
| `src/blocks.cyr` | The `--mode blocks` lane (v2.0.0, ADR 0012): the 32 Block Elements (`_BLK_B2`, `_BLK_MASK`, `_BLK_FLIP`), `_blk_sample` (8 × 8 samples a cell through the area taps), `blk_choose` (the least-error split from row / column / quadrant sums; transparency), `blk_prepare` (every cell, then both colour fields through `quantize_rgb_buf`), `_blk_shade` (░ ▒ ▓ under dither at tiers 8 / 16), `emit_blocks_row_buf` (complement and flat-cell choice) and `emit_blocks` | v2.0.0 |
| `src/ascii_shape.cyr` | **Generated** by `scripts/gen-shape-table.sh`: the 27-glyph coverage table (`ASCII_SHAPE_*`, `_ascii_shape_init`). Never hand-edited; `--check` proves it is the script's output | v1.10.0 (inline in `src/ascii.cyr` since v1.3.1) |

## Items

### 001 — pstruct byte-offset layout

The `pstruct` buffer in `main.cyr` is **a packed array of 20 i64 slots**, accessed via the `STRUCT_*_OFFSET` constants in `src/image.cyr` (`STRUCT_WIDTH_OFFSET` at 0 through `STRUCT_FORMAT_OFFSET` at 152).

It is **not** a Cyrius `struct` type. The byte-offset approach was the simplest way to extend the layout per milestone without a typedef ceremony, and every stage and test now addresses slots this way. (This note used to say Cyrius had no first-class structs, citing v6.0.1; the stdlib declares some today, e.g. `struct Str` in `lib/str.cyr`, so the layout is kii's choice rather than a language limit.) `kii_decode_image` zeroes all 20 slots before it writes any (since v1.6.4), so a slot a stage has not filled reads 0. Every consumer (image, quant, downscale, emit, ascii, main) does `load64(pstruct + STRUCT_FOO_OFFSET)` to read; `store64(pstruct + STRUCT_BAR_OFFSET, v)` to write.

**Invariant**: when adding a slot, bump the offset to the next 8-aligned value AND bump `var pstruct[N]` in `main.cyr` to ≥ `last_offset + 8`. The 160-byte size covers offsets up to 152 inclusive (slot 19, `STRUCT_FORMAT_OFFSET`); slot 20 would need a bump to 168 minimum. The zeroing loop in `kii_decode_image` is bounded by the same 160.

The first four slots (WIDTH / HEIGHT / BIT_DEPTH / COLOR_TYPE) sit at offsets 0–24 because the M2 decoder's IHDR buffer used the same four offsets, so one summary helper could read either buffer. That decoder, its IHDR buffer and the helper were deleted in the v1.2.0 re-fold; the offsets stayed. Since then the adapter always writes BIT_DEPTH 8 and COLOR_TYPE 6, which now state the pixel format (`downscale_to_rgb` refuses anything else), and the real source colour type goes in `STRUCT_SRC_COLOR_TYPE_OFFSET` (144) for `--verbose`. The native decoder's `IDAT_*`, `PLTE_*` and `INTERLACE` slots were retired at v1.7.0; their offsets (32, 40, 56, 64, 88, 96) were left unused rather than the struct repacked, so every live slot keeps its offset. v1.8.0 reuses 32 for `STRUCT_ALPHA_MASK_OFFSET`, downscale's transparency mask (0 when nothing is transparent). v1.10.0 reuses 40 for `STRUCT_LUMA_PLANE_OFFSET`, the ASCII lane's luminance plane; since v1.11.0 the area sampler writes it, `downscale_to_rgb` clears it, and `emit_ascii_shape` builds one only when it is 0.

### 002 — half-block aspect math (cell-vs-source-pixel asymmetry)

A terminal "row" carries **two** source pixels stacked vertically (top half = FG of the ▀ glyph, bottom half = BG). A terminal "column" carries **one** source pixel horizontally.

This means **a terminal cell is effectively 1:2 (cols:src-rows)**. Aspect-preserving the rendering — so a 100×100 square source produces a square-looking image in the terminal — requires:

```
dst_src_h = (src_h × dst_cols) / src_w
dst_term_rows = dst_src_h / 2
```

`_kii_compute_target_geometry` in `src/emit.cyr` implements this directly; `_kii_compute_fit_geometry` adds an envelope: when the aspect-derived height would exceed `max_rows`, the formula inverts (row-binding) and `dst_cols` derives from `max_rows` instead.

**Why this is a footgun**: an early version of the M6 tests counted `dst_src_h` and `dst_term_rows` as if they were the same thing, and every "square / portrait / landscape" assertion was wrong by 2×. The code was right; the test author (me) confused the two. Future M6 readers — if you write `dst_h` as a single name, you will fall into the same trap. Use `dst_src_h` and `dst_term_rows` always.

### 003 — pipe-purity and stdout discipline

kii's contract for piping: **stdout carries exactly the ANSI frame bytes**, nothing else. This is what makes `kii img.png > frame.ansi` produce a clean captured artifact and what makes `kii img.png | tee out.ansi` work.

Rules that enforce this:
- All user-facing diagnostics ride **stderr** (`_eprint*` family in `main.cyr`).
- The M4 `<path>: <W>x<H> N pixels (…) → 16-color` summary lived on stdout at v0.5.0. **At M5 it moved behind `--verbose` and now rides stderr**. Reverting that would break pipe-pure consumers.
- The missing-IEND warning rides stderr per spec § 5.3 tolerance — stdout still gets the frame, exit 0.
- Each emit row ends with `\x1b[0m\n` so a SIGPIPE truncation leaves the terminal in a sane (uncolored) state.

### 004 — darshana dep: every escape kii writes is darshana's

**Rewritten at v1.6.0.** This item used to document a kii-local `_emit_bg_256_buf` —
kept because darshana had no `tty_bg_256_buf`, with the extract-to-darshana trigger set at
"a second consumer". That trigger fired (thoth), darshana shipped the composer at 1.2.0, and
kii v1.6.0 deleted its copy. What stays non-obvious:

- **The half-block cell is one chained `pos`.** `emit_halfblock_row_buf` feeds
  the fg composer's result straight into the bg composer's `pos` (since v1.8.0 those are
  `_kii_sgr_fg` / `_kii_sgr_bg`, which pick darshana's `tty_sgr_buf`, `tty_fg/bg_256_buf` or
  `tty_fg/bg_rgb_buf` by tier). That is safe only
  because both return -1 for an out-of-range index *or a negative incoming `pos`* and write
  nothing when they do (darshana 0.9.3). Any composer added to that chain must have the same
  contract; the row checks `pos < 0` after each colour composer.
- **The per-row budget is darshana's byte budgets added up**: since v1.8.0 ≤ 19 (a
  truecolour FG) + ≤ 19 (BG) + 3 (▀ / ▄) per cell — `EMIT_CELL_MAX` = 41 — and 4
  (`tty_sgr_reset_buf`) + 1 (LF) per row, hence `sw * 42 + 16` (it was `sw * 26 + 16` while
  every escape was the 11-byte `38;5;N`). Elision only ever makes a row shorter. darshana writes
  with wide stores (an 8-byte prefix, then the index field) but never past the length it
  returns; `tests/render.tcyr` checks that for all 256 indices.
- **The path sanitizer is `tty_has_ctl`** with `TTY_SANITIZE_UTF8` and `TTY_KEEP_TAB |
  TTY_KEEP_LF`. darshana shaped that predicate on kii's rule; switching modes or keep bits
  changes what kii echoes to stderr, so `tests/cli.tcyr` pins the arguments.
- **Terminal size is `tty_winsize`, not `tty_winsize_or`.** The latter treats a 0 in either
  dimension as "unknown" and substitutes both defaults; kii decides columns and rows
  separately (`_kii_term_envelope`), because a half-set winsize — `stty cols 40` on a line
  whose size was never set reports 0 × 40 — would otherwise get an 80-column frame. On AGNOS
  `tty_winsize` reads the console grid, which is global, not per-fd: `kii img > file` there
  still sizes to the console.

### 005 — quantize hands emit colour codes, and `--color` selects the tier

`src/quant.cyr` turns a pixel into a 32-bit colour code at the module-scope tier
`quant_set_tier` sets from `--color` (v1.8.0, ADR 0010): a Linux-console palette index
at tiers 8 and 16 (`quantize_nearest_rgb`; 8 restricts the scan to the normal-intensity
half, which *is* the 8-colour tier, so no second table exists), an xterm index 16–255 at
tier 256 (`quantize_256`, exact without a scan), a packed 0xRRGGBB at truecolour, or
`KII_COLOR_DEFAULT` (1 << 24, outside every tier) for a pixel downscale marked
transparent. `kii_color_code_at` is the per-pixel entry point the `--mode ascii` lane uses
for each cell (it is `kii_color_code` plus the ordered-dither offset, v1.9.0);
`quantize_downscaled` fills a 4-byte-per-pixel buffer for the half-block lane.
The emit layer interprets a code by the same tier, so the two must never disagree:
`_kii_sgr_fg` refuses a code that is not a colour of the active tier (an index ≥ 8 at
tier 8, for instance) rather than sending something else.

**Superseded at v1.5.1.** This item used to argue that a third function,
`quantize_nearest_image`, "stays anyway" for M4-test backward compat, citing
`tests/kii.tcyr` lines ~1108–1202. Both had already been deleted — the function
in the v1.2.0 PNG re-fold (its per-`color_type` dispatch had no live inputs once
chitra normalized everything to RGBA8) and the monolithic test file in the same
release, when the suite split into five. The item was therefore justifying the
retention of code that did not exist, on the strength of coverage that did not
exist, and `src/quant.cyr` carries an explicit tombstone saying so. The genuinely
load-bearing fact is the one above.

### 006 — non-TTY default is the BBS-era 80×24 frame

When stdout is not a TTY (piped, redirected to a file, captured in a CI job), `tty_winsize(1, …)` returns -1 and `main.cyr` falls through to a hardcoded `(EMIT_DEFAULT_COLS=80) × (EMIT_DEFAULT_ROWS=24)` envelope.

**Why this specific size**: it's the canonical VT100 / DOS / BBS frame. kii's project identity (per `CLAUDE.md` § Color-tier discipline) is the BBS revival aesthetic floor; an unrecognized-environment default that lands in a 80×24 envelope is on-brand. It also matches what `chafa` does without arguments in a non-TTY context.

### 007 — Floyd-Steinberg is the one quantize step that reads its neighbours

Everything else in the pipeline maps a pixel (or a cell) to its code on its own, in any
order. `--dither fs` (v1.9.0, [ADR 0011](../adr/0011-dithering.md)) does not: a pixel's
code depends on the error carried from the pixels before it in raster order. Three things
follow.

- **The whole field goes through `quantize_rgb_buf` at once.** The half-block lane already
  quantized the downscaled buffer in one pass. The ASCII lane quantized each cell inside its
  row builder, so under `fs` (and only then) `emit_ascii_shape` first computes every cell's
  mean colour, quantizes that cols × rows field (`_ascii_cell_codes`), and parks the codes
  in the pstruct's `QUANTIZED` slot for the row builder to read. Under `none` and
  `ordered` the slot is 0, and the row quantizes each cell itself: the ordered offset
  depends only on the cell's position, so the two paths give the same bytes (a test pins
  it).
- **The cell mean is computed in two places that must agree.** The row builder sums a
  cell's opaque samples for its glyph and its colour; `_ascii_cell_codes` sums the same
  samples for the field. Both use the same rule (opaque samples only, integer mean, a cell
  with none is transparent). Changing one without the other makes `fs` frames disagree
  with `none` frames about a cell's colour.
- **A transparent pixel passes no error on.** It takes `KII_COLOR_DEFAULT`, and the error
  carried into it is dropped. The pixels after it get only what their opaque neighbours
  send.
