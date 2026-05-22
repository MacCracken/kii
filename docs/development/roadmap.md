# kii — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

The roadmap is **smallest-first** per AGNOS bite-discipline. Each milestone is sized to be a single coherent cycle of work (~3-7 days of focused effort), and each one ships a working binary that demonstrably does more than the previous one.

## v1.0 criteria

The contract for tagging v1.0:

- [ ] CLI surface frozen — `--help`, `--version`, `--width N`, positional path arg, `--color N` (8 or 16) all stable
- [ ] PNG decoder handles the W3C test suite's "basic" image set without crashing on any malformed input from the "broken" set
- [ ] 16-color quantization output passes visual review against `chafa --colors 16` on a curated 10-image test set
- [ ] Half-block glyph emission at terminal-detected geometry works in Linux console, xterm, Alacritty, kitty, and tmux
- [ ] At least one downstream consumer (BBS or MUD app) integrated and green
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass — PNG fuzz harness clean, ANSI-escape-injection paths reviewed (`docs/audit/YYYY-MM-DD-audit.md`)
- [ ] Test coverage: 100+ assertions across all modules
- [ ] Benchmarks captured in `docs/benchmarks.md` — image-decode latency at 256×256 / 1024×1024 / 2048×2048; quantization latency at terminal-sized output

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-05-22

- `cyrius init` scaffold landed
- Doc-tree per first-party-documentation
- ADRs / architecture notes / guides / examples folders ready
- `main.cyr` prints version banner; `cyrius test` runs the 2-assertion smoke suite green
- CLAUDE.md, README, CHANGELOG, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY all populated

### M1 — CLI arg parsing (v0.2.0)

**Goal**: arg surface frozen at the syntactic level. The binary parses `--help` / `--version` / positional path / `--width N` / `--color N` and prints help text + exits for the first two. Path + width + color are remembered in module state but not yet used.

**Acceptance criteria**:
- [ ] `kii --help` prints usage; exits 0
- [ ] `kii --version` prints `kii 0.2.0` + the Hawaiian etymology line; exits 0
- [ ] `kii image.png` parses path; placeholder "decoder not yet implemented" prints; exits 1
- [ ] `kii --width 80 image.png` parses width override
- [ ] `kii --color 8 image.png` parses color override (8 or 16 valid; anything else rejects with a usage error)
- [ ] `kii --width abc image.png` rejects with a usage error (no crash on non-integer)
- [ ] Tests cover happy path + malformed args
- [ ] CHANGELOG updated; VERSION bumped to 0.2.0

**Dep gates**: stdlib `args` (already in `cyrius.cyml`).

**Smallest-first sub-bites**: (a) `--help` + `--version` only → (b) add positional path → (c) add `--width` + `--color` → (d) add fuzz tests for malformed args.

### M2 — PNG structural decoder (v0.3.0)

**Goal**: PNG file is parsed structurally — signature validated, IHDR decoded (width/height/bit-depth/color-type), IDAT chunks identified and concatenated, IEND seen. No actual pixel decoding yet — IDAT bytes are NOT inflated (sankoch dep lands at M3).

**Acceptance criteria**:
- [ ] `kii image.png` prints `image.png: <W>x<H> bit_depth=<N> color_type=<T>` for valid PNGs
- [ ] Malformed signature → "not a PNG" error; exits 1
- [ ] Truncated IHDR → "malformed PNG header" error; exits 1
- [ ] Missing IEND → "incomplete PNG" warning; continues with what was read
- [ ] CRC validation on every chunk (PNG spec § 5.3); CRC failure → error
- [ ] Test set: W3C PNG suite "basic" images (basn*.png) all parse to correct dimensions
- [ ] Fuzz harness: random-byte input never crashes; only errors out cleanly
- [ ] Tests cover all four PNG color types (greyscale, RGB, palette, RGBA)
- [ ] CHANGELOG + VERSION → 0.3.0

**Dep gates**: none new. In-repo PNG decoder lives at `src/png.cyr`.

### M3 — sankoch DEFLATE → raw pixels (v0.4.0)

**Goal**: IDAT bytes from M2 get inflated via `sankoch`'s DEFLATE codec; the resulting stream is filter-undone per PNG spec § 9 (filter types 0-4); the output is a contiguous RGB or RGBA pixel buffer. No quantization yet; no ANSI emit yet.

**Acceptance criteria**:
- [ ] `kii image.png` prints `image.png: <W>x<H> decoded <N> pixels (<color_type_name>)` for valid PNGs
- [ ] Greyscale + RGB + palette + RGBA all decode correctly
- [ ] Interlaced PNG (Adam7) NOT supported at v0.4.0 — reject with clear error
- [ ] 1/2/4-bit-depth NOT supported at v0.4.0 — reject with clear error
- [ ] Test: W3C "basic" set decodes match-pixel-perfect against `pngcrush -d` output
- [ ] Memory: peak-memory-during-decode capped at 4×(W×H) bytes (no large scratch buffers)
- [ ] CHANGELOG + VERSION → 0.4.0

**Dep gates**: `sankoch` ≥ 2.2.5 added to `cyrius.cyml [deps]`.

### M4 — 16-color ANSI palette + RGB→nearest quantization (v0.5.0)

**Goal**: decoded RGB pixels get mapped to the 16-color ANSI palette via nearest-neighbor in RGB space. Output is internal — a 2D array of palette indices (0-15), one per source pixel. Still no ANSI emit; just internal quantization.

**Acceptance criteria**:
- [ ] Module `src/palette.cyr` defines the 16-color ANSI palette (Linux console / CGA-derived RGB triples)
- [ ] Module `src/quant.cyr` exposes `quantize_nearest(pixels, w, h) → palette_indices[]`
- [ ] Test: pure-red pixel → palette index 1 (red); pure-blue → 4; white → 15; black → 0
- [ ] Test: gradient PNG → palette indices monotone-vary across the gradient
- [ ] Bench: quantization latency at 1024×1024 captured in `docs/benchmarks.md`
- [ ] CHANGELOG + VERSION → 0.5.0

**Dep gates**: none new.

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
