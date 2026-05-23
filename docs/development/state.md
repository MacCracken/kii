# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.7.0** — M6 (terminal-size auto-detect + `--width N` override) closeout — 2026-05-22.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

Full PNG → terminal-fit ANSI half-block frame pipeline:

- `kii image.png` in a TTY → detects terminal cols × rows via `tty_winsize(1)`, fits the image into `cols × (rows - 1)` aspect-preservingly, emits a frame sized to that envelope on stdout. Exit 0.
- `kii image.png > out.ansi` (non-TTY) → falls back to 80×24 BBS-default; identical frame shape regardless of where stdout lands.
- `kii --width N image.png` → exactly N cells wide; height aspect-derived without a row cap (so `kii --width 200 img.png > big.ansi` captures a 200×80 frame for RAMGON).
- `kii --verbose image.png` adds the M4-shape summary line (`<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color`) to **stderr** after the frame.
- Missing IEND → frame + stderr warning + exit 0 (per spec § 5.3 tolerance).
- M3–M5 error paths unchanged. CLI surface is now feature-complete for v1.0 (all M1 flags consumed; `--verbose` activated at M5).

Module map:

- `src/main.cyr` — I/O glue + dispatch. Two-path geometry resolver (`--width N` → M6(a); else `tty_winsize`-detect → M6(b) fit).
- `src/cli.cyr` — CLI parse helpers + `KII_F_*` indices.
- `src/png.cyr` — PNG decoder: signature, IHDR, CRC32, chunk walker, PLTE, sankoch zlib_decompress, filter undo. 18-slot pstruct layout (160 bytes).
- `src/palette.cyr` — Linux-console 16-color RGB palette + accessors.
- `src/quant.cyr` — Two surfaces: M4 image-wide `quantize_nearest_image` (kept for test coverage of per-color_type extraction) + M5+ `quantize_rgb_buf` / `quantize_downscaled` (production pipeline).
- `src/downscale.cyr` — Nearest-neighbor RGB resampler with per-color_type extraction. Variable target size (called as `downscale_to_rgb(pstruct, target_w, target_src_rows)`).
- `src/emit.cyr` — Half-block ANSI emit + geometry primitives (`_kii_compute_target_geometry` for explicit-width, `_kii_compute_fit_geometry` for terminal-fit). Default constants `EMIT_DEFAULT_COLS = 80` / `EMIT_DEFAULT_ROWS = 24`. Local `_emit_bg_256_buf` while darshana's BG-256 twin isn't shipped.
- `tests/kii.tcyr` — 426 assertions.
- `tests/kii.fcyr` — two fuzz surfaces (10k arg + 2k PNG); downscale/emit/geometry fuzz surfaces + 2k → 10⁶ iteration scale deferred to M7 (security audit).
- `tests/kii.bcyr` — four benches: `quantize_nearest_rgb @ 1024×1024` (269 ns) + end-to-end RAMGON at 80×24 / 120×40 / 200×60.
- `RAMGON.png` — top-level fixture (1152×925 RGBA, ~2 MB).

## Binary size

Build: ~145 KB at v0.7.0 (compiler reports ~430 unreachable fns / ~120 KB DCE-eliminable, dominated by sankoch's encoder + darshana's termios/cursor modules + transitive thread machinery). Set `CYRIUS_DCE=1` to trim.

## Tests + bench

- `cyrius test` → **426 assertions, all pass** (was 382 at v0.6.0; +24 M6(a) target-geometry + +17 M6(b) fit-geometry + +3 extra rejection coverage).
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → 10k arg-parser + 2k PNG-decoder iters in ~0.07 s. Exit 0.
- Bench (see [`docs/benchmarks.md`](../benchmarks.md)):
  - `quantize_nearest_rgb @ 1024×1024`: **269 ns/op**
  - `end-to-end RAMGON.png → 80×24 frame`: **761 ms/iter**
  - `end-to-end RAMGON.png → 120×40 frame`: **769 ms/iter**
  - `end-to-end RAMGON.png → 200×60 frame`: **771 ms/iter**
  - Cell-count climbs 6.25× across the three end-to-end variants; wall-clock climbs ~1.3 % (PNG decode dominates).

## Dependencies

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`, `sankoch`, `thread` (no deltas vs v0.6.0).
- **External**: `darshana 0.5.3` (pinned). M6 uses `tty_winsize` (darshana v0.3.0+) in addition to the M5 ANSI primitives.

## Cycle context

v0.7.0 close lands during agnos kernel cycle **1.32.x networking-arc**. BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

**M7 — Security audit cycle (v0.8.0)**. Roadmap restructured: the original "M7 = v1.0 freeze" was split into M7 (security) and M8 (freeze), so security work gets a dedicated cycle. Deliverables:

- External CVE / 0-day research compiled into `docs/audit/2026-MM-DD-audit.md` — libpng / lodepng / stb_image / zlib advisories walked, kii-applicability assessed per class.
- PNG fuzz harness scales 2k → 10⁶ iterations clean.
- New fuzz surfaces: random valid-PNG → random downscale dims; random target-geometry inputs into the M6 helpers.
- Integer-overflow review on every size-derivation multiplication.
- Decompression-amplification cap on inflate output (defends against malformed-IDAT OOM-DoS).
- ANSI escape injection review on the path → stderr surface.
- Decode-latency matrix at 256² / 1024² / 2048² source resolutions.
- ADR 0002 (security-model) + CHANGELOG + VERSION → 0.8.0.

Then **M8 — v1.0 freeze (v1.0.0)** lands the first BBS/MUD consumer, cross-terminal verification, visual review vs `chafa --colors 16`, getting-started + examples doc backfill, marketplace recipe, and the v1.0 tag.

**Carry-forward debt cleared at M6**: `docs/architecture/README.md` backfilled (was overdue M2 → M6); `docs/adr/0001-png-decoder-in-repo.md` written (was overdue M3 → M6).
