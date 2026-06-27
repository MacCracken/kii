# kii

**kii** (Hawaiian: *image / picture / likeness*) — image → ANSI/ASCII-art converter for terminal display.

Cyrius-native equivalent of [`chafa`](https://hpjansson.org/chafa/) / [`jp2a`](https://github.com/Talinx/jp2a) / [`viu`](https://github.com/atanunq/viu). Reads raster image input (PNG and baseline JPEG today; GIF / BMP planned), quantizes to a terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to the terminal's cols × rows.

## Status

**v1.0.3** (2026-06-22). The full PNG → 16-color half-block ANSI pipeline is locked in (v1.0 freeze at v1.0.0). Builds on host and on the AGNOS target (`--agnos`).

Today `kii image.png` reads any spec-clean PNG (greyscale / RGB / palette / grey+alpha / RGBA, bit depths 1/2/4/8/16, interlaced or not) or a **baseline JPEG** (`kii photo.jpg` — grayscale + YCbCr, 4:4:4 / 4:2:2 / 4:2:0), quantizes to the 16-color ANSI palette, and emits half-block (`▀`) glyphs to stdout sized to the terminal:

```
$ kii tests/fixtures/RAMGON.png        # renders half-block ANSI to the terminal
$ kii --verbose tests/fixtures/RAMGON.png > out.ansi
tests/fixtures/RAMGON.png: 1152x925 1065600 pixels (RGBA) → 16-color   # (stderr, --verbose)
```

Terminal size auto-detects on a TTY (`cols × rows`); non-TTY output falls back to an 80×24 BBS-default frame. On AGNOS the console grid is read from the framebuffer via the `winsize` syscall (darshana branch), so output sizes to the real console rather than the 80×24 default.

See [`docs/development/state.md`](docs/development/state.md) for the per-release snapshot, [`docs/development/roadmap.md`](docs/development/roadmap.md) for the path to v1.0, and [`CHANGELOG.md`](CHANGELOG.md) for shipped work.

### Shipped through v1.0

- **M0** (v0.1.0): scaffold + first-party docs + CI/release workflows
- **M1** (v0.2.0): CLI surface — `--help`, `--version`, `--width N`, `--color N`, positional path; arg-parser fuzz harness
- **M2** (v0.3.0): PNG structural decoder — signature + IHDR + CRC32 + chunk walker through IEND
- **M3** (v0.4.0): PNG pixel decoder — sankoch `zlib_decompress` + filter undo (spec § 9 filter types 0–4); PNG-decoder fuzz harness
- **M4** (v0.5.0): 16-color ANSI palette + Euclidean-RGB nearest quantization; PLTE chunk capture for palette PNGs; first benchmark (`quantize_nearest_rgb`: 274 ns/op)
- **M5** (v0.6.0): half-block (`▀`) ANSI emit to stdout via darshana (256-color SGR per cell)
- **M6** (v0.7.0): terminal-size auto-detect + `--width N` override (aspect-preserving fit)
- **M7** (v0.8.0): security audit cycle — input-cap / decompression-amplification / ANSI-injection hardening; fuzz scaled to 3M+ iters
- **M8** (v1.0.0): v1.0 freeze — ADRs, W3C PngSuite walk, chafa visual review

### Not yet supported (deferred per scope)

- **GIF / BMP** — not yet supported (baseline JPEG landed at v1.4.0 via chitra 0.3.0; PNG is the full 1/2/4/8/16-bit + Adam7 matrix since v1.2.2)
- **Progressive / arithmetic / 12-bit / CMYK JPEG** — rejected cleanly as `unsupported JPEG feature …` (chitra 0.3.0 is baseline-only)
- **256-color + truecolor + dithering** — tier-2; explicit post-v1 work
- **Sixel / Kitty / iTerm2 image protocols** — tier-3; explicit post-v1 work

## Color-tier roadmap

The world prior art (`chafa`) ships every tier from monochrome through 24-bit truecolor. kii chooses the order deliberately:

- **Tier 1 — v0.x → v1.0**: 8/16-color ANSI palette + half-block (`▀`/`▄`) glyph quantization. Historically-correct rendering target for BBS / MUD clients of the early-90s era; maximum terminal compatibility; well-defined floor. **Shipped: palette quantization (v0.5.0), glyph emit (v0.6.0), terminal-size detection (v0.7.0); v1.0 freeze at v1.0.0.**
- **Tier 2 — post-v1**: 256-color ANSI palette + 24-bit truecolor escape sequences (`\x1b[38;2;R;G;Bm`) + dithering schemes (Floyd-Steinberg, ordered/Bayer) for higher fidelity.
- **Tier 3 — future**: Sixel / Kitty / iTerm2 image-protocol direct rendering (skips ASCII art entirely on supporting terminals). Animated GIF / video frame-pipe support.

## Naming

- **Repo + binary**: `kii` (ASCII-safe form)
- **Display form**: `kiʻi` with ʻokina when written formally
- **Bare name** (no `cyrius-` prefix) — that prefix is reserved for games. kii is a tool, sibling to `hapi` (stow-equivalent), `anuenue` (lolcat-equivalent), `bannermanor` (figlet-equivalent), `mihi` (sys-info probe). Hawaiian micro-cluster on the user-tool surface.

## Substrate

- [`sankoch`](https://github.com/MacCracken/sankoch) — DEFLATE/zlib decompression. **Wired at v0.4.0** for PNG IDAT decompression. (Now folded into Cyrius stdlib at v5.8.65, so it's a stdlib-list add, not an external git dep.)
- [`darshana`](https://github.com/MacCracken/darshana) — TTY/ANSI primitives (color escape sequences, cursor positioning, `tty_winsize`). External dep since v0.6.0 / M5 when ANSI emit went live.
- [`chitra`](https://github.com/MacCracken/chitra) — the image-decode substrate (pure-Cyrius PNG + baseline-JPEG → canonical RGBA8). **Forked from kii's own `src/png.cyr` and adopted back** at v1.2.0 (the PNG re-fold, [ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)) when `mabda` became the second consumer; `src/png.cyr` is now a thin adapter calling `chitra_image_decode`. JPEG arrived on the `chitra 0.3.0` re-pin at v1.4.0 ([ADR 0008](docs/adr/0008-jpeg-via-chitra.md)). Pinned via `[deps.chitra]`.
- **In-repo palette + quantizer** (`src/palette.cyr` + `src/quant.cyr`) — Linux-console 16-color RGB table + nearest-neighbor Euclidean quantization.

## Multi-source prior art

Per AGNOS `feedback_redesign_dont_reinvent` the convergent shape comes from multiple references, not a single port:

| Layer | Primary reference | Cross-validation |
|---|---|---|
| Image-to-terminal conversion (overall shape) | [`chafa`](https://hpjansson.org/chafa/) — canonical, sophisticated dithering, glyph quantization | `jp2a` (JPEG-focused monochrome-leaning), `viu` (256/truecolor biased), `libcaca` (substrate library most others rooted from) |
| PNG decoder | [W3C PNG Specification](https://www.w3.org/TR/png/) (1.3) | Reference impl: `libpng`; minimal-port refs: `stb_image.h`, `lodepng` |
| 16-color ANSI palette | Linux console color table (CGA-derived) | xterm 16-color set (identical for ANSI 0-7 + bright 0-7) |
| Half-block glyph quantization | `chafa` source `chafa-canvas.c` glyph-selection routines | Various ASCII-art-converter tutorials; Unicode Block Elements block (`U+2580`-`U+259F`) spec |

## Building

```sh
cyrius deps                           # resolve stdlib deps
cyrius build src/main.cyr build/kii   # compile
./build/kii --version                 # smoke run
./build/kii image.png                 # quantize a PNG
```

Toolchain pin: `cyrius = "6.2.44"` (in [`cyrius.cyml`](cyrius.cyml)).

### Running the test + bench + fuzz suites

```sh
cyrius test                           # 431 assertions across 5 suites (cli/quant/render/ascii/decode)
cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz   # 6 fuzz surfaces, 4,011,000 iters (arg/path/geom/emit/PNG/JPEG)
cyrius build tests/kii.bcyr build/kii-bench && ./build/kii-bench # quantization micro-bench
```

Benchmark results are captured per release in [`docs/benchmarks.md`](docs/benchmarks.md).

## License

GPL-3.0-only. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md). All contributions GPL-3.0-only.

## Reporting security issues

See [SECURITY.md](SECURITY.md). Image decoders are a known-malicious-input surface; the threat model is explicit there.
