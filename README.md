# kii

**kii** (Hawaiian: *image / picture / likeness*) — image → ANSI/ASCII-art converter for terminal display.

Cyrius-native equivalent of [`chafa`](https://hpjansson.org/chafa/) / [`jp2a`](https://github.com/Talinx/jp2a) / [`viu`](https://github.com/atanunq/viu). Reads raster image input (PNG, baseline JPEG, BMP, and GIF first-frame), quantizes to a terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to the terminal's cols × rows.

## Status

**v1.5.1** (2026-08-25). Four input formats through the [`chitra`](https://github.com/MacCracken/chitra) substrate, two render lanes, terminal-fit geometry. Builds on host, on the AGNOS target (`--agnos`), and on aarch64.

`kii image.png` reads any spec-clean PNG (greyscale / RGB / palette / grey+alpha / RGBA, bit depths 1/2/4/8/16, interlaced or not), a **baseline JPEG** (`kii photo.jpg` — greyscale / YCbCr / RGB, 4:4:4 / 4:2:2 / 4:2:0), a **BMP** (`BI_RGB` 1/4/8/16/24/32 bpp, RLE4/RLE8, BITFIELDS) or a **GIF** (first frame), quantizes to the 8- or 16-color ANSI palette, and emits half-block (`▀`) glyphs to stdout sized to the terminal:

```
$ kii tests/fixtures/RAMGON.png        # renders half-block ANSI to the terminal
$ kii --verbose tests/fixtures/RAMGON.png > out.ansi
tests/fixtures/RAMGON.png: 1152x925 1065600 pixels (RGBA) → 16-color   # (stderr, --verbose)
```

Terminal size auto-detects on a TTY (`cols × rows`); non-TTY output falls back to an 80×24 BBS-default frame. On AGNOS the console grid is read from the framebuffer via the `winsize` syscall (darshana branch), so output sizes to the real console rather than the 80×24 default.

See [`docs/development/state.md`](docs/development/state.md) for the current snapshot, [`docs/development/roadmap.md`](docs/development/roadmap.md) for what is still open (it is forward-facing only — shipped work is deleted from it, not checked off), and [`CHANGELOG.md`](CHANGELOG.md) for the full release record.

### How it got here

Per-release detail is in [`CHANGELOG.md`](CHANGELOG.md); this is the shape of the arc.

**v0.1.0 → v1.0.0** built the whole pipeline in-repo: CLI surface, a PNG structural
decoder, DEFLATE through `sankoch`, 16-colour quantization, half-block emit, terminal-size
detection, then a security-audit cycle and the v1.0 freeze (ADRs, a W3C PngSuite walk, and
a visual review against `chafa`).

**Post-v1 has been a sequence of re-folds** — kii keeps deleting its own code in favour of
shared substrate, which is the point:

- **v1.1.0** — CLI parsing moved onto the `cmdit` distlib; the hand-rolled flag parser deleted.
- **v1.2.0** — the **PNG re-fold**: the 813-line native decoder deleted in favour of the
  `chitra` distlib ([ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)), output byte-identical.
- **v1.3.x** — the `--mode ascii` character-glyph lane, upgraded to shape-vector matching.
- **v1.4.0** — baseline **JPEG**, on a `chitra` re-pin.
- **v1.5.0** — **BMP + GIF**, on another `chitra` re-pin, with *zero decode change*: the
  adapter already called the format-sniffing entry point, so the release was diagnostics.
- **v1.5.1** — a P-1 audit sweep: a `--width` overflow that segfaulted, a truncated JPEG
  that rendered silently, a fuzz surface that had been testing nothing, a C1
  ANSI-injection hole, unchecked writes, and `--color 8` finally doing something.
  ([full report](docs/audit/2026-08-25-audit.md))

### Supported input formats

All four arrive from the [`chitra`](https://github.com/MacCracken/chitra) substrate — kii carries no decoder of its own (see [ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)):

- **PNG** — the full matrix: bit depths 1/2/4/8/16, every color type, Adam7 interlace (since v1.2.2)
- **Baseline JPEG** — greyscale + YCbCr (since v1.4.0), Adobe-APP14 **RGB** (since v1.5.0); 4:4:4 / 4:2:2 / 4:2:0 plus general `Hi,Vi` box upsampling; interleaved / non-interleaved / multi-scan; DRI/RST restart markers
- **BMP** — `BI_RGB` 1/4/8/16/24/32 bpp, `BI_RLE4`/`BI_RLE8`, `BI_BITFIELDS` with V4/V5 headers (since v1.5.0)
- **GIF** — GIF87a/89a, LZW, interlaced; **first frame only** (since v1.5.0)

### Not yet supported (deferred per scope)

- **Animated GIF beyond frame 1** — kii is a still-frame renderer; chitra decodes the first frame by design (chitra ADR 0005)
- **Progressive / arithmetic / 12-bit / CMYK JPEG** — rejected cleanly as `unsupported JPEG feature …` (chitra is baseline-only)
- **256-color + truecolor + dithering** — tier-2; explicit post-v1 work
- **Sixel / Kitty / iTerm2 image protocols** — tier-3; explicit post-v1 work

## Usage

```
kii [OPTIONS] <image>
```

| Flag | Default | What it does |
|---|---|---|
| `-w, --width <N>` | `0` (match terminal) | Output width in columns. Height is aspect-derived. Capped at 100000. |
| `-c, --color <N>` | `16` | Colour tier: `16` uses the full ANSI palette, `8` restricts to the normal-intensity half. |
| `-m, --mode <M>` | `halfblock` | `halfblock` emits `▀` cells at double vertical resolution; `ascii` emits text glyphs chosen by shape. |
| `-v, --verbose` | off | Print a dimensions/format summary to **stderr** after the frame. |
| `-h, --help` | — | Show help and exit. |
| `-V, --version` | — | Print version and exit. |

```sh
kii photo.jpg                      # any of the four formats, detected by signature
kii --width 120 image.png          # explicit width; height follows the aspect ratio
kii --mode ascii image.png         # text-glyph art instead of half-blocks
kii --color 8 image.png            # 8-colour tier for the strictest terminals
kii image.png > frame.ansi         # pure ANSI on stdout; diagnostics stay on stderr
```

The frame goes to **stdout** and every diagnostic to **stderr**, so `kii img.png | …`
pipes clean. Exit codes: `0` success, `1` runtime failure, `2` usage error.

Two conditions render a frame *and* warn on stderr, exiting `0`: a PNG with no `IEND`,
and a truncated JPEG or GIF (the partial frame is what decoded).

## Color-tier roadmap

The world prior art (`chafa`) ships every tier from monochrome through 24-bit truecolor. kii chooses the order deliberately:

- **Tier 1 — shipped**: 8/16-color ANSI palette + half-block (`▀`/`▄`) glyph quantization. Historically-correct rendering target for BBS / MUD clients of the early-90s era; maximum terminal compatibility; well-defined floor. Palette quantization landed at v0.5.0, glyph emit at v0.6.0, terminal-size detection at v0.7.0, and the tier was completed at **v1.5.1**, when `--color 8` stopped being a flag that parsed its argument and ignored it.
- **Tier 2 — post-v1**: 256-color ANSI palette + 24-bit truecolor escape sequences (`\x1b[38;2;R;G;Bm`) + dithering schemes (Floyd-Steinberg, ordered/Bayer) for higher fidelity.
- **Tier 3 — future**: Sixel / Kitty / iTerm2 image-protocol direct rendering (skips ASCII art entirely on supporting terminals). Animated GIF / video frame-pipe support.

## Naming

- **Repo + binary**: `kii` (ASCII-safe form)
- **Display form**: `kiʻi` with ʻokina when written formally
- **Bare name** (no `cyrius-` prefix) — that prefix is reserved for games. kii is a tool, sibling to `hapi` (stow-equivalent), `anuenue` (lolcat-equivalent), `bannermanor` (figlet-equivalent), `mihi` (sys-info probe). Hawaiian micro-cluster on the user-tool surface.

## Substrate

- [`sankoch`](https://github.com/MacCracken/sankoch) — DEFLATE/zlib decompression. **Wired at v0.4.0** for PNG IDAT decompression. (Now folded into Cyrius stdlib at v5.8.65, so it's a stdlib-list add, not an external git dep.)
- [`darshana`](https://github.com/MacCracken/darshana) — TTY/ANSI primitives (color escape sequences, cursor positioning, `tty_winsize`). External dep since v0.6.0 / M5 when ANSI emit went live; pinned at `1.0.0` (darshana's API freeze) since v1.5.0.
- [`cmdit`](https://github.com/MacCracken/cmdit) — getopt-long CLI parsing (the Cyrius stdlib `flags` parser productized and extended). **Adopted at v1.1.0** in the CLI re-fold: kii's own flag set seeded cmdit's design and kii is its first consumer, so the hand-rolled parser and the stdlib `flags` dep were both dropped. `src/cli.cyr` registers into a cmdit context. Pinned via `[deps.cmdit]`.
- [`chitra`](https://github.com/MacCracken/chitra) — the image-decode substrate (pure-Cyrius PNG + JPEG + BMP + GIF → canonical RGBA8). **Forked from kii's own `src/png.cyr` and adopted back** at v1.2.0 (the PNG re-fold, [ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)) when `mabda` became the second consumer; `src/png.cyr` is now a thin adapter calling `chitra_image_decode`. JPEG arrived on the `chitra 0.3.0` re-pin at v1.4.0 ([ADR 0008](docs/adr/0008-jpeg-via-chitra.md)); BMP + GIF on the `chitra 1.0.0` re-pin at v1.5.0, with **no decode change at all** ([ADR 0009](docs/adr/0009-bmp-gif-via-chitra.md)). Pinned via `[deps.chitra]`.
- **In-repo palette + quantizer** (`src/palette.cyr` + `src/quant.cyr`) — Linux-console 16-color RGB table + nearest-neighbour Euclidean quantization, with the active tier (8 or 16) selected by `--color`. These two modules and the emit/downscale layer are the only image code kii still owns.

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

Toolchain pin: `cyrius = "6.5.35"` (in [`cyrius.cyml`](cyrius.cyml)).

### Running the test + bench + fuzz suites

```sh
cyrius test                           # 550 assertions across 5 suites (cli/quant/render/ascii/decode)
cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz   # 8 fuzz surfaces, 6,011,000 iters (arg/path/geom/emit/PNG/JPEG/BMP/GIF)
cyrius bench tests/kii.bcyr                                     # 7 benches (quantize, end-to-end, decode-latency)
```

Benchmark results are captured per release in [`docs/benchmarks.md`](docs/benchmarks.md).

## License

GPL-3.0-only. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md). All contributions GPL-3.0-only.

## Reporting security issues

See [SECURITY.md](SECURITY.md). Image decoders are a known-malicious-input surface; the threat model is explicit there.
