# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Module map (v1.7.0)

The pipeline runs top to bottom; each module owns one stage. The shared `pstruct` (function-scope `var pstruct[160]` in `src/main.cyr`) carries data between stages via byte-offset slots declared in `src/image.cyr`. kii has no decoder of its own: since the v1.2.0 re-fold every format is parsed inside `chitra` ([ADR 0006](../adr/0006-adopt-chitra-decoder.md)), and `src/image.cyr` (`src/png.cyr` until v1.7.0) is the adapter that feeds it. Redrawn at v1.6.4; the v0.7.0 map showed the in-repo chunk walk, sankoch inflate and filter undo that the re-fold deleted.

```
  argv ─► cli.cyr     flag table (cmdit checks --width's range and --mode's
             │        choices; kii checks --color);
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
          downscale.cyr  downscale_to_rgb: nearest-neighbour, alpha over black
             │           (half-block: cols × rows·2;  ascii: cols·2 × rows·3)
     ┌───────┴──────────────────────┐
     ▼ --mode halfblock (default)   ▼ --mode ascii
  quant.cyr  quantize_downscaled   ascii.cyr  emit_ascii_shape
  (palette.cyr; --color tier)        2×3 shape match picks the glyph;
     ▼                               the cell's mean colour goes through
  emit.cyr   emit_halfblock          quantize_nearest_rgb for its fg
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
| `src/cli.cyr` | Flag registration (`--width` through `cmdit_range`, `--mode` through `cmdit_enum` with `KII_MODE_*`, since v1.7.0) + `kii_validate_color`; `KII_F_*` indices; `KII_MAX_COLS`; `KII_MAX_CELLS` and `kii_frame_cells_ok` (the frame-size cap, v1.6.4); `kii_parse_error_line`; `kii_path_has_control_bytes` (a wrapper over darshana's `tty_has_ctl` since v1.6.0) | M1 + M7(c) |
| `src/image.cyr` | The chitra adapter (`src/png.cyr` until v1.7.0): `kii_decode_image` (read, sniff, decode, adapt); the `IMG_ERR_*` code space; `_kii_map_read_err` (read errno → `IMG_ERR_*`, v1.6.4); `_kii_map_chitra_err` (`ChitraErr` → `IMG_ERR_*`); `kii_decode_error_text` and `kii_incomplete_warning_text` (the text of every decode diagnostic and warning, v1.6.4); `kii_source_type_name`; the `STRUCT_*_OFFSET` layout | M2, adapter since v1.2.0 |
| `src/palette.cyr` | Linux-console 16-color ANSI palette + lazy init + accessors | M4(a) |
| `src/quant.cyr` | RGB → palette-index quantization: `quant_set_tier` (the `--color` tier), per-pixel `quantize_nearest_rgb`, and `quantize_rgb_buf` + `quantize_downscaled` for the half-block lane | M4(b)(d) + M5(c) |
| `src/downscale.cyr` | Nearest-neighbor RGB resampler: `downscale_to_rgb` over chitra's RGBA8 (the only pixel format since v1.7.0 removed the per-colour-type dispatch), with `_over_black` compositing alpha over black (v1.6.4) | M5(b) |
| `src/emit.cyr` | Half-block ANSI emit (darshana composers) + `_kii_compute_target_geometry` + `_kii_compute_fit_geometry` + `_kii_term_envelope` (v1.6.0) + `_kii_write_all`; the frame loop and row ending both lanes share, `_kii_emit_frame` and `_kii_row_end` (v1.7.0) | M5(c) + M6(a)(b) |
| `src/ascii.cyr` | The `--mode ascii` lane: the 27-glyph coverage table, `_ascii_match`, `emit_ascii_shape` | v1.3.0, shape-vector v1.3.1 |

## Items

### 001 — pstruct byte-offset layout

The `pstruct` buffer in `main.cyr` is **a packed array of 20 i64 slots**, accessed via the `STRUCT_*_OFFSET` constants in `src/image.cyr` (`STRUCT_WIDTH_OFFSET` at 0 through `STRUCT_FORMAT_OFFSET` at 152).

It is **not** a Cyrius `struct` type. The byte-offset approach was the simplest way to extend the layout per milestone without a typedef ceremony, and every stage and test now addresses slots this way. (This note used to say Cyrius had no first-class structs, citing v6.0.1; the stdlib declares some today, e.g. `struct Str` in `lib/str.cyr`, so the layout is kii's choice rather than a language limit.) `kii_decode_image` zeroes all 20 slots before it writes any (since v1.6.4), so a slot a stage has not filled reads 0. Every consumer (image, quant, downscale, emit, ascii, main) does `load64(pstruct + STRUCT_FOO_OFFSET)` to read; `store64(pstruct + STRUCT_BAR_OFFSET, v)` to write.

**Invariant**: when adding a slot, bump the offset to the next 8-aligned value AND bump `var pstruct[N]` in `main.cyr` to ≥ `last_offset + 8`. The 160-byte size covers offsets up to 152 inclusive (slot 19, `STRUCT_FORMAT_OFFSET`); slot 20 would need a bump to 168 minimum. The zeroing loop in `kii_decode_image` is bounded by the same 160.

The first four slots (WIDTH / HEIGHT / BIT_DEPTH / COLOR_TYPE) sit at offsets 0–24 because the M2 decoder's IHDR buffer used the same four offsets, so one summary helper could read either buffer. That decoder, its IHDR buffer and the helper were deleted in the v1.2.0 re-fold; the offsets stayed. Since then the adapter always writes BIT_DEPTH 8 and COLOR_TYPE 6, which now state the pixel format (`downscale_to_rgb` refuses anything else), and the real source colour type goes in `STRUCT_SRC_COLOR_TYPE_OFFSET` (144) for `--verbose`. The native decoder's `IDAT_*`, `PLTE_*` and `INTERLACE` slots were retired at v1.7.0; their offsets (32, 40, 56, 64, 88, 96) are left unused rather than the struct repacked, so every live slot keeps its offset.

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
  `tty_fg_256_buf`'s result straight into `tty_bg_256_buf`'s `pos`. That is safe only
  because both return -1 for an out-of-range index *or a negative incoming `pos`* and write
  nothing when they do (darshana 0.9.3). Any composer added to that chain must have the same
  contract; the row checks `pos < 0` after each colour composer.
- **The per-row budget is darshana's byte budgets added up**: ≤ 11 (FG) + ≤ 11 (BG) + 3 (▀)
  per cell, 4 (`tty_sgr_reset_buf`) + 1 (LF) per row — hence `sw * 26 + 16`. darshana writes
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

### 005 — the quantizer has one entry point, and `--color` selects the tier

`src/quant.cyr` exposes `quantize_nearest_rgb` (per-pixel, used directly by the
`--mode ascii` lane for each cell's foreground) and `quantize_downscaled` (the
pstruct-aware wrapper the half-block pipeline uses). Both read the module-scope
tier set by `quant_set_tier`, which `main.cyr` drives from `--color`: 16 scans
the whole palette, 8 restricts to the normal-intensity half. The low 8 entries
*are* the 8-colour tier, so no second table exists.

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
