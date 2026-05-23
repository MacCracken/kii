# kii — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

The roadmap is **smallest-first** per AGNOS bite-discipline. Each milestone is sized to be a single coherent cycle of work (~3-7 days of focused effort), and each one ships a working binary that demonstrably does more than the previous one.

## v1.0 criteria

The contract for tagging v1.0:

- [x] CLI surface frozen — `--help`, `--version`, `--width N`, positional path arg, `--color N` (8 or 16) all stable (shipped at v0.2.0 / M1)
- [ ] PNG decoder handles the W3C test suite's "basic" image set without crashing on any malformed input from the "broken" set (PNG decoder shipped at v0.4.0 / M3; W3C-suite acceptance pass still future)
- [ ] 16-color quantization output passes visual review against `chafa --colors 16` on a curated 10-image test set (quantizer shipped at v0.5.0 / M4; visual review pending M5 emit)
- [ ] Half-block glyph emission at terminal-detected geometry works in Linux console, xterm, Alacritty, kitty, and tmux (M5 + M6 work)
- [ ] At least one downstream consumer (BBS or MUD app) integrated and green
- [x] CHANGELOG complete from v0.1.0 onward (rolling per release; v0.1.0–v0.5.0 all entered)
- [ ] Security audit pass — PNG fuzz harness clean, ANSI-escape-injection paths reviewed (`docs/audit/YYYY-MM-DD-audit.md`)
- [x] Test coverage: 100+ assertions across all modules (287 as of v0.5.0)
- [ ] Benchmarks captured in `docs/benchmarks.md` — image-decode latency at 256×256 / 1024×1024 / 2048×2048; quantization latency at terminal-sized output (quantization bench at 1024×1024 captured at v0.5.0 / M4; decode-latency matrix at three resolutions still pending)

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-22

- `cyrius init` scaffold landed
- Doc-tree per first-party-documentation
- ADRs / architecture notes / guides / examples folders ready
- `main.cyr` prints version banner; `cyrius test` runs the 2-assertion smoke suite green
- CLAUDE.md, README, CHANGELOG, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY all populated

### M1 — CLI arg parsing (v0.2.0) — ✅ shipped 2026-05-22

CLI surface frozen at the syntactic level. The binary parses `--help` / `--version` / positional path / `--width N` / `--color N` and dispatches accordingly. Path + width + color are captured into module state for downstream milestones to consume.

**Delivered**:
- ✅ `kii --help` / `-h` prints usage to stderr (pipe-pure stdout); exits 0
- ✅ `kii --version` / `-V` prints `kii X.Y.Z` + Hawaiian etymology to stdout; exits 0
- ✅ `kii image.png` parses path; placeholder "decoder not yet implemented" emitted at M1, exit 1 (the placeholder is now superseded by the M4 success line on stdout, exit 0)
- ✅ `kii --width N image.png` parses width override (default 0 = "match terminal" sentinel for M6)
- ✅ `kii --color N image.png` parses color override; 8 or 16 valid; anything else rejects with `kii: --color must be 8 or 16` + exit 2
- ✅ `kii --width abc image.png` rejects with `kii: bad integer value` + exit 2 (no crash)
- ✅ Tests cover happy path + every `FLAG_ERR_*` variant + multi-positional capture
- ✅ Fuzz harness wired (`tests/kii.fcyr`) — deterministic LCG, 10k iters of random argv against kii's flag set; never crashes

**Deps added at M1**: stdlib `flags` (consumer: CLI parser).

**Sub-bite cadence** (smallest-first): (a) `--help` + `--version` only → (b) positional path → (c) `--width` + `--color` → (d) fuzz harness.

### M2 — PNG structural decoder (v0.3.0) — ✅ shipped 2026-05-22

PNG file parsed structurally — signature validated, IHDR decoded, all chunks walked through IEND, CRC32 validated on every chunk. No pixel decoding yet (M3 work); IDAT bytes are concatenated into a buffer but not inflated.

**Delivered**:
- ✅ `kii image.png` prints structural summary (M2 shape: `bit_depth=N color_type=T`; superseded at M3+M4)
- ✅ Malformed signature → `not a PNG` error; exits 1
- ✅ Truncated IHDR → `malformed PNG header` error; exits 1
- ✅ Missing IEND → `warning: incomplete PNG (no IEND chunk seen)` soft warning + still emits summary; exits 0 (M3+)
- ✅ CRC32 validation on every chunk per spec § 5.3; CRC failure → `CRC check failed` + exit 1
- ✅ Truncated mid-chunk → `malformed PNG (chunk truncated after IHDR)` + exit 1
- ✅ All four pixel color types parse cleanly (greyscale / RGB / palette / RGBA + grey+alpha)
- ✅ PNG-decoder fuzz harness wired (`tests/kii.fcyr` second surface) — 2k iters of random byte sequences, sometimes with valid sig+IHDR prefix; never crashes

**Deps added at M2**: none new.

**Sub-bite cadence**: (a) signature only → (b) IHDR parse → (c) CRC32 + chunk walker → (d) close-out (stdout/exit 0 + fuzz).

### M3 — sankoch DEFLATE → raw pixels (v0.4.0) — ✅ shipped 2026-05-22

IDAT bytes inflated via `sankoch`'s `zlib_decompress`; resulting row stream undone per PNG spec § 9 filter types 0–4; output is a contiguous pixel buffer.

**Delivered**:
- ✅ `kii image.png` prints `<path>: <W>x<H> decoded <N> pixels (<color_type_name>)` for valid PNGs (M3 shape; superseded at M4)
- ✅ Greyscale + RGB + palette + grey+alpha + RGBA all decode correctly (all five PNG color types, including palette PNGs at the index-output level)
- ✅ Interlaced (Adam7) PNGs → `interlaced PNGs (Adam7) not supported in v0.x` + exit 1
- ✅ 1/2/4-bit-depth PNGs → `unsupported bit depth or color type` + exit 1
- ✅ Filter types 0 (None) / 1 (Sub) / 2 (Up) / 3 (Average) / 4 (Paeth) all unfiltered correctly; unknown filter byte → `invalid PNG filter type` + exit 1
- ✅ Memory: chunk walk streams through 4 KB scratch buffer; IDAT accumulation allocates exactly `idat_total_size` bytes (single bump-alloc) plus inflate output sized to `height × (1 + row_bytes)` + pixel buffer sized to `height × row_bytes`
- ✅ Real-world: RAMGON.png (1152×925 RGBA) decodes to exactly 4,262,400 bytes

**Deps added at M3**: stdlib `sankoch` (zlib_decompress) + stdlib `thread` (sankoch's mutex transitive). NB: sankoch was folded into Cyrius stdlib at v5.8.65; the roadmap originally anticipated it as an external git dep, but the fold-in changed it to a stdlib-list entry.

**Sub-bite cadence**: (a) sankoch round-trip + dep wiring → (b) IDAT buffer accumulation + interlace capture → (c) inflate + filter undo + Adam7/sub-byte rejection → (d) close-out (stdout/exit 0 + PNG fuzz surface in `kii.fcyr`).

### M4 — 16-color ANSI palette + RGB→nearest quantization (v0.5.0) — ✅ shipped 2026-05-22

Decoded pixels mapped to the Linux-console 16-color ANSI palette via Euclidean-RGB nearest-neighbor. Internal output: 1 byte per pixel (palette index 0–15). Still no ANSI emit (M5 gate); just the quantized buffer ready for half-block emission.

**Delivered**:
- ✅ `src/palette.cyr` defines the 16-color ANSI palette (Linux-console / CGA-derived RGB triples; matches xterm 0–15)
- ✅ `src/quant.cyr` exposes `quantize_nearest_rgb(r, g, b) → idx` (scalar) and `quantize_nearest_image(pstruct)` (image-wide; per-color_type dispatch including PLTE lookup for color_type=3)
- ✅ Pure-red pixel → palette index 1, pure-blue → 4, white → 15, black → 0 (all roadmap acceptance pixels)
- ✅ Brightness gradient maps to monotonically-non-decreasing palette-luminance
- ✅ PLTE chunk captured during phase-1 walker with spec § 11.2.3 validation (length ≤ 768, multiple of 3)
- ✅ Bench: `quantize_nearest_rgb @ 1024×1024 = 274 ns/op`; captured in [`docs/benchmarks.md`](../benchmarks.md)
- ✅ Output line: `<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color` to stdout, exit 0

**Deps added at M4**: none new.

**Sub-bite cadence**: (a) palette table + accessors → (b) scalar quantizer → (c) PLTE capture → (d) image-wide quantizer + close-out (bench + version bump).

### M5 — Half-block glyph emit + per-row ANSI color (v0.6.0)

**Goal**: the working CLI. `kii image.png` reads a PNG, decodes it, quantizes to 16 colors, emits half-block glyphs (`▀`) to stdout with per-character FG/BG ANSI color escapes. Each terminal character represents two source pixels stacked vertically (top half color = FG, bottom half = BG). Output is sized to a hardcoded 80×24 (terminal-size detection at M6).

**Acceptance criteria**:
- [ ] `kii image.png` produces visible ANSI art on stdout
- [ ] Output is exactly 80 chars wide × 24 rows tall (each row = `▀` glyphs with paired FG/BG colors)
- [ ] Source PNG is downscaled (bilinear or nearest — pick at impl time) to 80×48 source pixels before quantization
- [ ] ANSI escape format: `\x1b[38;5;<fg>m\x1b[48;5;<bg>m▀` per character; final `\x1b[0m` reset at end of line + end of frame
- [ ] Test: render a checkerboard PNG; assert checkerboard pattern in output
- [ ] Test: render a solid-color PNG; assert all-same-glyph output
- [ ] Visual review: side-by-side comparison against `chafa --colors 16 --size 80x24 image.png` on a curated 5-image test set
- [ ] CHANGELOG + VERSION → 0.6.0

**Dep gates**: `darshana` ≥ 0.3.5 added to `cyrius.cyml [deps]` (for ANSI escape primitives + reset codes).

### M6 — Terminal-size auto-detect + `--width` override (v0.7.0)

**Goal**: kii detects the terminal's actual size via `ioctl TIOCGWINSZ` and emits an appropriately-sized frame. `--width N` overrides; `--width 0` means "match terminal". If both fail (not a TTY, ioctl unavailable), fall back to 80×24.

**Acceptance criteria**:
- [ ] `kii image.png` in an 120×40 terminal produces ~120×40 output (height auto-derived from aspect ratio)
- [ ] `kii --width 60 image.png` produces exactly 60-char-wide output
- [ ] `kii image.png > out.txt` (non-TTY) falls back to 80×24 with no error
- [ ] Bench: end-to-end latency at 1920×1080 → terminal-output for 80×24 / 120×40 / 200×60
- [ ] CHANGELOG + VERSION → 0.7.0

**Dep gates**: none new — `ioctl TIOCGWINSZ` is in stdlib `syscalls`.

### M7 — v1.0 freeze cycle (v1.0.0)

**Goal**: harden, audit, soak. No new features. Frozen CLI surface. Comprehensive test + benchmark coverage. Security audit pass.

**Acceptance criteria** (all v1.0 criteria above plus):

- [ ] Test suite: 100+ assertions
- [ ] Benchmarks: latency captured at three resolutions (256² / 1024² / 2048²)
- [ ] Security audit: PNG fuzz harness runs 10⁶ iterations clean; ANSI-escape-injection paths reviewed
- [ ] At least one BBS or MUD downstream consumer integrated against kii and green
- [ ] All ADRs written for design decisions made during M0-M6
- [ ] Docs / guides / examples all current per `docs/doc-health.md`
- [ ] Marketplace recipe in zugot
- [ ] CHANGELOG complete; VERSION → 1.0.0; git tag

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident:

- **Tier 2 / 3 color modes** — 256-color, truecolor, dithering, Sixel, Kitty image protocol. All deferred to post-v1 per CLAUDE.md color-tier discipline.
- **JPEG / GIF / BMP decoders** — PNG only at v1.0. Other formats land as v1.x bites once a consumer needs them.
- **Animated GIF / video-frame-pipe** — explicit post-v2 scope.
- **Output to stdout-other-than-TTY-styled file formats** — e.g. no HTML output, no SVG output. kii is image → ANSI, full stop.
- **Image transformations** — no crop, no rotate, no scale-other-than-fit-terminal. Use upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live-resize-on-terminal-resize, no animation, no scroll. One frame in, one frame out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan. Loop in the shell.

## Post-v1 considerations (informational, not commitments)

- **Tier 2 — 256-color + truecolor** (v1.1.0) — `--color 256` and `--color tc` modes; ordered/Floyd-Steinberg dither.
- **JPEG decoder** (v1.2.0) — JFIF subset via in-repo decoder OR via `tarang`-equivalent media-codec lib if it exists by then.
- **PNG substrate extraction** — when a second consumer needs PNG decoding, extract `src/png.cyr` → Sanskrit-named substrate lib (`chitra` / `rupa` / TBD per the tools-stable naming convention).
- **Tier 3 — Sixel / Kitty protocols** (v2.0.0) — direct-image-protocol output for terminals that support it; the ASCII-art fallback stays the default. Possibly a major-version cut depending on CLI surface impact.

Captured deferrals will live as ADRs (e.g., `docs/adr/0001-no-tier-2-in-v1.md`) when the decision crystallizes.
