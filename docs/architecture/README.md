# Architecture notes

Non-obvious constraints, quirks, and invariants that a reader cannot derive from the code alone. Numbered chronologically — never renumber.

Not decisions (those live in [`../adr/`](../adr/)) and not guides (those live in [`../guides/`](../guides/)). An item here describes *how the world is*, not *what we chose* or *how to do something*.

## Module map (v0.7.0)

The pipeline runs left-to-right; each module owns one stage. The shared `pstruct` (function-scope `var pstruct[160]` in `src/main.cyr`) carries data between stages via byte-offset slots declared in `src/png.cyr`.

```
                    ┌──────────────────────────────────────────────┐
                    │  pstruct[160] — 20 i64 slots, byte-offset    │
                    │  layout via STRUCT_*_OFFSET in png.cyr       │
                    └──────────────────────────────────────────────┘
                                       ▲    ▲    ▲    ▲
                                       │    │    │    │
   ┌────────────┐    ┌──────────┐    ┌─┴────┴────┴────┴────┐
   │ main.cyr   │    │ cli.cyr  │    │ png.cyr (structure) │
   │ orchestrator    │ flags    │    │ + IDAT + PLTE walk  │
   └────┬───────┘    └──────────┘    └─────────────────────┘
        │                                       ▲
        ▼                                       │
   ┌──────────────┐    ┌──────────────────┐    ┌┴────────────────┐
   │ png decode   │───►│ png decode       │    │ palette.cyr     │
   │ structure    │    │ pixels (sankoch  │    │ (Linux console  │
   │              │    │ + filter undo)   │    │  16-color RGB)  │
   └──────────────┘    └────────┬─────────┘    └────────┬────────┘
                                │                       │
                                ▼                       │
   ┌────────────────┐    ┌──────────────────┐           │
   │ emit.cyr       │    │ downscale.cyr    │           │
   │ (geometry      │◄───│ nearest-neighbor │◄──────────┘
   │  + half-block  │    │ + per-color_type │
   │  ANSI)         │    │ RGB normalize    │
   └───────┬────────┘    └──────────────────┘
           │
           ▼ stdout (fd 1)
       80×24 ANSI frame
```

| Module | Owns | M-where |
|---|---|---|
| `src/main.cyr` | I/O + orchestration; dispatches each stage; gates `--verbose` summary | M0+, restructured each milestone |
| `src/cli.cyr` | Flag registration + `kii_validate_color` / `kii_validate_mode`; `KII_F_*` indices; `kii_path_has_control_bytes` (a wrapper over darshana's `tty_has_ctl` since v1.6.0) | M1 + M7(c) |
| `src/png.cyr` | PNG decoder: signature, IHDR, CRC32, chunk walk, PLTE, IDAT, sankoch inflate, filter undo, pixel buffer; `STRUCT_*_OFFSET` layout | M2 + M3 + M4(c) PLTE |
| `src/palette.cyr` | Linux-console 16-color ANSI palette + lazy init + accessors | M4(a) |
| `src/quant.cyr` | RGB → palette-index quantization: scalar `quantize_nearest_rgb`, image-wide `quantize_nearest_image` (M4-test surface), `quantize_rgb_buf` + `quantize_downscaled` (M5+ pipeline) | M4(b)(d) + M5(c) |
| `src/downscale.cyr` | Nearest-neighbor RGB resampler with per-color_type normalize | M5(b) |
| `src/emit.cyr` | Half-block ANSI emit (darshana composers) + `_kii_compute_target_geometry` + `_kii_compute_fit_geometry` + `_kii_term_envelope` (v1.6.0) + `_kii_write_all` | M5(c) + M6(a)(b) |

## Items

### 001 — pstruct byte-offset layout

The `pstruct` buffer in `main.cyr` is **a packed array of 20 i64 slots**, accessed via the `STRUCT_*_OFFSET` constants in `src/png.cyr` (lines 84–98).

It is **not** a Cyrius struct type — Cyrius doesn't have first-class structs in v6.0.1, and the byte-offset approach was the simplest way to extend the layout per milestone without a typedef ceremony. Every consumer (png, palette, quant, downscale, emit) does `load64(pstruct + STRUCT_FOO_OFFSET)` to read; `store64(pstruct + STRUCT_BAR_OFFSET, v)` to write.

**Invariant**: when adding a slot, bump the offset to the next 8-aligned value AND bump `var pstruct[N]` in `main.cyr` to ≥ `last_offset + 8`. The 160-byte size at v0.7.0 covers offsets up to 152 inclusive (slot 19); slot 20 would need a bump to 168 minimum.

The first four slots (WIDTH / HEIGHT / BIT_DEPTH / COLOR_TYPE) are deliberately at offsets 0–24 so `IHDR_*_OFFSET` (used by `png_decode_header`) and `STRUCT_*_OFFSET` (used by `png_decode_structure`) overlap there — same `_print_ihdr_summary` helper at M2 worked on either buffer. M3+ slots diverge after offset 32.

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
