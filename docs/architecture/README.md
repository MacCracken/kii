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
| `src/cli.cyr` | Flag registration + `kii_validate_color`; `KII_F_*` indices | M1 |
| `src/png.cyr` | PNG decoder: signature, IHDR, CRC32, chunk walk, PLTE, IDAT, sankoch inflate, filter undo, pixel buffer; `STRUCT_*_OFFSET` layout | M2 + M3 + M4(c) PLTE |
| `src/palette.cyr` | Linux-console 16-color ANSI palette + lazy init + accessors | M4(a) |
| `src/quant.cyr` | RGB → palette-index quantization: scalar `quantize_nearest_rgb`, image-wide `quantize_nearest_image` (M4-test surface), `quantize_rgb_buf` + `quantize_downscaled` (M5+ pipeline) | M4(b)(d) + M5(c) |
| `src/downscale.cyr` | Nearest-neighbor RGB resampler with per-color_type normalize | M5(b) |
| `src/emit.cyr` | Half-block ANSI emit + `_kii_compute_target_geometry` + `_kii_compute_fit_geometry`; local `_emit_bg_256_buf` | M5(c) + M6(a)(b) |

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

### 004 — darshana dep + the BG-256 inline copy

kii uses darshana 0.5.3 for foreground 256-color escapes (`tty_fg_256_buf`), the SGR reset (`tty_sgr_reset_buf`), and terminal detection (`tty_winsize`). It does **not** use darshana for background 256-color escapes — darshana hadn't shipped a `tty_bg_256_buf` as of v0.5.3, with a comment saying "Background twin not yet shipped — wait for a consumer ask."

`src/emit.cyr` carries a kii-local `_emit_bg_256_buf` that mirrors `tty_fg_256_buf`'s shape but emits `CSI 48;5;Nm`. The extract-to-darshana trigger is **a second consumer in the AGNOS surface needing the same BG-256 helper** (the standard AGNOS extract-on-2nd-consumer pattern). Until then, the local copy is intentional duplication.

### 005 — quantize_nearest_image kept for M4-test backward compat

`src/quant.cyr` exposes both `quantize_nearest_image` (the M4 image-wide entry, walks `STRUCT_PIXELS_BUF` with per-color_type dispatch) AND the M5+ `quantize_downscaled` (reads `STRUCT_DOWNSCALED_BUF`, an already-RGB-normalized buffer). The production pipeline (M5+) routes through the latter; the former is no longer in `main.cyr`'s call graph.

**It stays anyway**. The M4 test surface (`tests/kii.tcyr` lines ~1108–1202) exercises the per-color_type pixel-extraction code paths in `quantize_nearest_image`. The same extraction logic now lives in `downscale.cyr`'s `_extract_rgb`, so the M4 tests provide independent coverage of equivalent code paths. Removing `quantize_nearest_image` would lose that coverage without saving meaningful binary size (DCE eliminates it from release builds when `CYRIUS_DCE=1`).

### 006 — non-TTY default is the BBS-era 80×24 frame

When stdout is not a TTY (piped, redirected to a file, captured in a CI job), `tty_winsize(1, …)` returns -1 and `main.cyr` falls through to a hardcoded `(EMIT_DEFAULT_COLS=80) × (EMIT_DEFAULT_ROWS=24)` envelope.

**Why this specific size**: it's the canonical VT100 / DOS / BBS frame. kii's project identity (per `CLAUDE.md` § Color-tier discipline) is the BBS revival aesthetic floor; an unrecognized-environment default that lands in a 80×24 envelope is on-brand. It also matches what `chafa` does without arguments in a non-TTY context.
