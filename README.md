# kii

**kii** (Hawaiian: *image / picture / likeness*) — image → ANSI/ASCII-art converter for terminal display.

Cyrius-native equivalent of [`chafa`](https://hpjansson.org/chafa/) / [`jp2a`](https://github.com/Talinx/jp2a) / [`viu`](https://github.com/atanunq/viu). Reads raster image input (PNG today; JPEG / GIF / BMP planned), quantizes to a terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to the terminal's cols × rows.

## Status

**Mid-alpha — v0.5.0** (2026-05-22). The PNG → 16-color palette-index pipeline is complete; ANSI emission to terminal lands at M5 (v0.6.0).

Today `kii image.png` decodes any spec-clean PNG (greyscale / RGB / palette / grey+alpha / RGBA at bit-depth 8 or 16, non-interlaced) all the way through:

```
$ kii tests/fixtures/RAMGON.png
tests/fixtures/RAMGON.png: 1152x925 1065600 pixels (RGBA) → 16-color
```

What's NOT yet visible: actual half-block (`▀`) glyphs to stdout. That's M5 — the quantized indices live internally, but darshana (the ANSI primitives dep) is the M5 gate.

See [`docs/development/state.md`](docs/development/state.md) for the per-release snapshot, [`docs/development/roadmap.md`](docs/development/roadmap.md) for the path to v1.0, and [`CHANGELOG.md`](CHANGELOG.md) for shipped work.

### Shipped through v0.5.0

- **M0** (v0.1.0): scaffold + first-party docs + CI/release workflows
- **M1** (v0.2.0): CLI surface — `--help`, `--version`, `--width N`, `--color N`, positional path; arg-parser fuzz harness
- **M2** (v0.3.0): PNG structural decoder — signature + IHDR + CRC32 + chunk walker through IEND
- **M3** (v0.4.0): PNG pixel decoder — sankoch `zlib_decompress` + filter undo (spec § 9 filter types 0–4); PNG-decoder fuzz harness
- **M4** (v0.5.0): 16-color ANSI palette + Euclidean-RGB nearest quantization; PLTE chunk capture for palette PNGs; first benchmark (`quantize_nearest_rgb`: 274 ns/op)

### Not yet supported (deferred per scope)

- **Adam7 interlacing** — rejected with `interlaced PNGs (Adam7) not supported in v0.x`
- **1/2/4-bit sub-byte depths** — rejected with `unsupported bit depth or color type`
- **JPEG / GIF / BMP** — PNG only at v1.0
- **256-color + truecolor + dithering** — tier-2; explicit post-v1 work
- **Sixel / Kitty / iTerm2 image protocols** — tier-3; explicit post-v1 work

## Color-tier roadmap

The world prior art (`chafa`) ships every tier from monochrome through 24-bit truecolor. kii chooses the order deliberately:

- **Tier 1 — v0.x → v1.0**: 8/16-color ANSI palette + half-block (`▀`/`▄`) glyph quantization. Historically-correct rendering target for BBS / MUD clients of the early-90s era; maximum terminal compatibility; well-defined floor. **Palette quantization shipped at v0.5.0; glyph emit lands at v0.6.0; terminal-size detection at v0.7.0.**
- **Tier 2 — post-v1**: 256-color ANSI palette + 24-bit truecolor escape sequences (`\x1b[38;2;R;G;Bm`) + dithering schemes (Floyd-Steinberg, ordered/Bayer) for higher fidelity.
- **Tier 3 — future**: Sixel / Kitty / iTerm2 image-protocol direct rendering (skips ASCII art entirely on supporting terminals). Animated GIF / video frame-pipe support.

## Naming

- **Repo + binary**: `kii` (ASCII-safe form)
- **Display form**: `kiʻi` with ʻokina when written formally
- **Bare name** (no `cyrius-` prefix) — that prefix is reserved for games. kii is a tool, sibling to `hapi` (stow-equivalent), `anuenue` (lolcat-equivalent), `bannermanor` (figlet-equivalent), `mihi` (sys-info probe). Hawaiian micro-cluster on the user-tool surface.

## Substrate

- [`sankoch`](https://github.com/MacCracken/sankoch) — DEFLATE/zlib decompression. **Wired at v0.4.0** for PNG IDAT decompression. (Now folded into Cyrius stdlib at v5.8.65, so it's a stdlib-list add, not an external git dep.)
- [`darshana`](https://github.com/MacCracken/darshana) — TTY/ANSI primitives (color escape sequences, cursor positioning). Lands as an external dep at v0.6.0 / M5 when ANSI emit goes live.
- **In-repo PNG decoder** (`src/png.cyr`) — signature + IHDR + CRC32 + chunk walker + IDAT inflate + filter undo (filter types 0–4) + PLTE capture. Multi-source convergent port from the W3C spec + `libpng` + `stb_image.h` + `lodepng`. Graduates to a separate Sanskrit-named substrate lib (`chitra` / `rupa` / TBD) once a second consumer surfaces, per the `mihi → iam/chakshu` extract-on-2nd-consumer pattern.
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

Toolchain pin: `cyrius = "6.0.1"` (in [`cyrius.cyml`](cyrius.cyml)).

### Running the test + bench + fuzz suites

```sh
cyrius test                           # 287 assertions across M1–M4 surface
cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz   # arg-parser + PNG-decoder fuzz
cyrius build tests/kii.bcyr build/kii-bench && ./build/kii-bench # quantization micro-bench
```

Benchmark results are captured per release in [`docs/benchmarks.md`](docs/benchmarks.md).

## License

GPL-3.0-only. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md). All contributions GPL-3.0-only.

## Reporting security issues

See [SECURITY.md](SECURITY.md). Image decoders are a known-malicious-input surface; the threat model is explicit there.
