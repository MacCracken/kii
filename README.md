# kii

**kii** (Hawaiian: *image / picture / likeness*) — image → ANSI/ASCII-art converter for terminal display.

Cyrius-native equivalent of [`chafa`](https://hpjansson.org/chafa/) / [`jp2a`](https://github.com/Talinx/jp2a) / [`viu`](https://github.com/atanunq/viu). Reads raster image input (PNG, baseline JPEG, BMP, and GIF first-frame), quantizes to a terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to the terminal's cols × rows.

## Status

**v2.5.0** (2026-10-29). Four input formats through the [`chitra`](https://github.com/MacCracken/chitra) substrate, four render lanes and two image protocols (iTerm2, kitty), terminal-fit geometry. Builds on host, on the AGNOS target (`--agnos`), and on aarch64; each release ships a binary for all three (§ Building).

`kii image.png` reads any spec-clean PNG (greyscale / RGB / palette / grey+alpha / RGBA, bit depths 1/2/4/8/16, interlaced or not), a **baseline JPEG** (`kii photo.jpg` — greyscale / YCbCr / RGB, 4:4:4 / 4:2:2 / 4:2:0), a **BMP** (`BI_RGB` 1/4/8/16/24/32 bpp, RLE4/RLE8, BITFIELDS) or a **GIF** (first frame), quantizes to a colour tier (the 16 ANSI colours by default; 8, 256 or 24-bit truecolour on request), optionally dithered, and emits half-block (`▀`) glyphs to stdout sized to the terminal (or, on request, text glyphs, also as dark-on-light or plain text, the full Block Elements set, or Braille dots):

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
- **v1.6.0** — the cyrius 6.7 language minor and darshana 1.3.0, and two more re-folds:
  the background colour escape and the filename sanitizer are now darshana's (the
  sanitizer gaining strict RFC 3629), every frame byte-identical. The manifest's dep tags
  now name what is actually compiled.
- **v1.6.1** — dependencies moved to the newest tags that build on cyrius 6.7.9 (cmdit 1.4.0,
  chitra 1.1.3), with every frame byte-identical. `cyrius.cyml` was cut back to a plain
  manifest.
- **v1.6.2** — the CLI names the parse errors cmdit 1.3.x added: `--verbose=0` reports
  `--verbose takes no value` instead of a generic parse error.
- **v1.6.3** — cyrius 6.7.12 and chitra 1.2.0. Rendering is about 3.5× faster with
  byte-identical output, because the stdlib's sankoch replaced the Huffman decode path that
  dominated every render.
- **v1.6.4** — a P(-1) audit sweep. A 392-byte GIF that `--width 80` turned into ~4.4 GB of
  ANSI is now stopped by a 1,048,576-cell frame cap. Pipes, `/dev/stdin` and directories are
  read correctly, transparent pixels render black instead of their hidden colour, and small
  images render about 2× faster at wide output; every opaque frame is byte-identical.
  ([full report](docs/audit/2026-10-15-audit.md))
- **v1.7.0** — the format-neutral rename: `src/png.cyr` is `src/image.cyr`, `kii_decode_png`
  is `kii_decode_image`, and the `PNG_ERR_*` codes are `IMG_ERR_*`, named for what they mean.
  The dead per-colour-type decoder paths are gone, both render lanes share one frame loop, and
  cmdit checks `--width` and `--mode`. Every frame is byte-identical.
- **v1.8.0** — tier 2 colour and the emit rework: `--color 256` and `--color tc` (24-bit), tier 1
  on the plain 8/16-colour SGR codes a strict terminal understands, repeated escapes elided
  (frames ~83 % smaller), and transparent pixels drawn in the terminal's own background
  ([ADR 0010](docs/adr/0010-tier-2-colour-and-emit-encoding.md)).
- **v1.9.0** — dithering: `--dither ordered` (4×4 Bayer) or `--dither fs` (Floyd-Steinberg)
  at tiers 8, 16 and 256, in both lanes; on a grey ramp at tier 16, `fs` cuts the brightness
  error by three quarters ([ADR 0011](docs/adr/0011-dithering.md)). The default stays `none`.
  The downscale now samples each span's centre rather than its start, which changes every
  downscaled frame ([ADR 0005](docs/adr/0005-nearest-neighbor-downscale.md) amendment).
- **v1.9.1** — cyrius 6.7.18 and every dependency at its newest tag (darshana 1.6.0, cmdit
  1.5.0, chitra 1.3.1). A PNG past 16 MiB of scanlines (above ~5.6 MP of RGB) now renders
  instead of being refused; every other frame is byte-identical. Such a PNG can cost up to
  ~0.9 GB and ~10 s ([ADR 0002](docs/adr/0002-security-model.md) § v1.9.1 amendment).
- **v1.10.0** — the ASCII lane's refinements: a checked-in generator for its glyph table
  (`scripts/gen-shape-table.sh`), and directional + global contrast enhancement before each
  cell is matched, which sharpens edges ([ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md)
  § v1.10.0 amendment). A k-d-tree lookup was built, found exact but slower than the scan, and
  not taken. ASCII frames change; half-block frames are byte-identical.
- **v1.11.0** — the ASCII lane samples areas: each region of a cell is the mean of the source
  pixels it covers, not one pixel, so thin lines and edges stop dropping out (cells with ink
  drawn as a space fall from 127 of 291 to 18 on a test of 2 px lines). Large photos cost at
  most ~3 % more at up to 200 columns, and more on very wide frames (+23 % at 400)
  ([ADR 0005](docs/adr/0005-nearest-neighbor-downscale.md) § v1.11.0 amendment). Reduced ASCII
  frames change; half-block frames are byte-identical.
- **v2.0.0** — a third lane, `--mode blocks`: every cell sampled 8 × 8 and drawn as the Block
  Element that fits it best (eighths, quadrants, diagonals, halves) in two colours, with
  `░ ▒ ▓` as colour mixes under `--dither`. Lower per-pixel error than half-block on every
  test image, and smaller frames at 16 colours. Opt-in, because CP437-era console fonts lack
  the quadrants and eighths ([ADR 0012](docs/adr/0012-block-elements-lane.md)). Half-block and
  ASCII frames are byte-identical to 1.11.0.
- **v2.0.1** — release engineering: CI builds and tests aarch64, releases carry x86_64,
  aarch64 and agnos binaries (the x86_64 ones dead-code eliminated, 56 % smaller, measured
  byte-identical), and the release notes are the CHANGELOG's. No frame changes.
- **v2.1.0** — the half-block lane reuses its colour state: each cell is `▀`, `▄`, `█` or a
  space, whichever needs fewest escapes for the same two colours, so default frames are about
  half the bytes (−50 % at 8 and 16 colours, −37 % at truecolour) and look the same. At 16
  colours a bright colour stays in the foreground, because the Linux console has no bright
  backgrounds ([ADR 0004](docs/adr/0004-half-block-floor-glyph.md) § v2.1.0).
- **v2.2.0** — the ASCII lane on light backgrounds and without colour: `--invert` reads dark
  as ink (exactly the glyphs of the image's negative, in its own colours), and `--color none`
  writes glyphs and newlines only, with no escapes. Both are `--mode ascii` only
  ([ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md) § v2.2.0). Every other frame is
  byte-identical to 2.1.0.

### Supported input formats

All four arrive from the [`chitra`](https://github.com/MacCracken/chitra) substrate — kii carries no decoder of its own (see [ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)):

- **PNG** — the full matrix: bit depths 1/2/4/8/16, every color type, Adam7 interlace (since v1.2.2)
- **Baseline JPEG** — greyscale + YCbCr (since v1.4.0), Adobe-APP14 **RGB** (since v1.5.0); 4:4:4 / 4:2:2 / 4:2:0 plus general `Hi,Vi` box upsampling; interleaved / non-interleaved / multi-scan; DRI/RST restart markers
- **BMP** — `BI_RGB` 1/4/8/16/24/32 bpp, `BI_RLE4`/`BI_RLE8`, `BI_BITFIELDS` with V4/V5 headers (since v1.5.0)
- **GIF** — GIF87a/89a, LZW, interlaced; **first frame only** (since v1.5.0)

### Not yet supported (deferred per scope)

- **Animated GIF beyond frame 1** — kii is a still-frame renderer; chitra decodes the first frame by design (chitra ADR 0005)
- **Progressive / arithmetic / 12-bit / CMYK JPEG** — rejected cleanly as `unsupported JPEG feature …` (chitra is baseline-only)
- **Sixel** — tier 3, pinned to 2.6.0 ([roadmap](docs/development/roadmap.md)); iTerm2's protocol shipped at 2.4.0 and kitty's at 2.5.0

## Usage

```
kii [OPTIONS] <image>
```

| Flag | Default | What it does |
|---|---|---|
| `-w, --width <N>` | `0` (match terminal) | Output width in columns. Height is aspect-derived. Capped at 100000; negative values are refused. |
| `-c, --color <8\|16\|256\|tc\|none>` | `16` | Colour tier. `16` uses the 16 ANSI colours (SGR 30–37 / 90–97), `8` the normal-intensity half only (30–37, for the strictest terminals), `256` the xterm 6×6×6 cube and grey ramp, `tc` 24-bit truecolour. `none` (v2.2.0, `--mode ascii` and `braille` only) writes no escapes at all: glyphs and newlines, for pipes, logs and mail. kii never reads `COLORTERM` or `NO_COLOR`: the tier is what you ask for. |
| `-m, --mode <M>` | `halfblock` | `halfblock` emits two colours per cell at double vertical resolution (`▀`, `▄`, `█` or a space, whichever needs fewest escapes); `ascii` emits text glyphs chosen by shape; `blocks` (v2.0.0) emits whichever Block Element fits each cell's 8 × 8 samples best, in two colours (needs a font with the quadrants and eighths). `braille` (v2.3.0) emits Braille Patterns, 2 × 4 dots a cell in one colour: the finest shapes, for line art and logos; dots are inked above one level for the whole frame (Otsu's), or dithered under `--dither`. `iterm` (v2.4.0) sends the picture itself as one iTerm2 inline image (OSC 1337), for iTerm2, WezTerm and other terminals that read that protocol: a PNG kii writes from the decoded pixels, scaled by the terminal into the cell box; it takes no `--color`, `--dither` or `--invert`, and a terminal without the protocol draws nothing. `kitty` (v2.5.0) sends the same PNG by the kitty graphics protocol (APC escapes in 4,096-character chunks), for kitty and other terminals that read it, sized by columns (or by rows when the terminal's rows bind), so the terminal keeps the aspect with its own cell size; it too takes no `--color`, `--dither` or `--invert`. |
| `-d, --dither <none\|ordered\|fs>` | `none` | Dithering at tiers 8, 16 and 256. `ordered` adds a 4×4 Bayer pattern; `fs` diffuses each pixel's error (Floyd-Steinberg). Both turn bands into a mix of two neighbouring colours, and make the frame larger. No effect at `tc`. In `--mode braille` it also decides which dots are inked, so it applies at `tc` and `none` too. |
| `-i, --invert` | off | `--mode ascii` and `braille` only (v2.2.0, v2.3.0): dark is ink, for a light terminal. The glyphs are the image's negative's, in the image's own colours; partial alpha sits on white. |
| `-v, --verbose` | off | Print a dimensions/format summary to **stderr** after the frame. |
| `-h, --help` | — | Show help and exit. |
| `-V, --version` | — | Print version and exit. |

```sh
kii photo.jpg                      # any of the four formats, detected by signature
kii --width 120 image.png          # explicit width; height follows the aspect ratio
kii --mode ascii image.png         # text-glyph art instead of half-blocks
kii --mode blocks image.png        # eighths, quadrants and diagonals: finer edges
kii --mode braille logo.png        # Braille dots, 2 x 4 a cell: line art and logos
kii --mode iterm photo.jpg         # the picture itself, in iTerm2 or WezTerm
kii --mode kitty photo.jpg         # the picture itself, in kitty
kii --mode ascii --invert img.png  # dark ink, for a light terminal
kii --mode ascii --color none img.png > art.txt   # plain text, no escapes
kii --color 8 image.png            # 8-colour tier for the strictest terminals
kii --color tc photo.jpg           # 24-bit truecolour
kii --dither fs photo.jpg          # smooth gradients in 16 colours (or --dither ordered)
kii image.png > frame.ansi         # pure ANSI on stdout; diagnostics stay on stderr
```

The frame goes to **stdout** and every diagnostic to **stderr**, so `kii img.png | …`
pipes clean. Exit codes: `0` success, `1` runtime failure, `2` usage error.

Transparent pixels (alpha below 128) are drawn in the terminal's own default colours, so a
logo with a transparent background sits on whatever background your terminal has.

To read an image from a pipe, name it as a path: `cat img.png | kii /dev/stdin` (or
`kii <(…)`). A frame over 1,048,576 character cells is refused with
`frame too large (…); use a smaller --width`.

Two conditions render a frame *and* warn on stderr, exiting `0`: a PNG with no `IEND`,
and a truncated JPEG or GIF (the partial frame is what decoded).

## Color-tier roadmap

The world prior art (`chafa`) ships every tier from monochrome through 24-bit truecolor. kii chooses the order deliberately:

- **Tier 1 — shipped**: 8/16-color ANSI palette + half-block (`▀`/`▄`) glyph quantization. Historically-correct rendering target for BBS / MUD clients of the early-90s era; maximum terminal compatibility; well-defined floor. Palette quantization landed at v0.5.0, glyph emit at v0.6.0, terminal-size detection at v0.7.0, and the tier was completed at **v1.5.1**, when `--color 8` stopped being a flag that parsed its argument and ignored it.
- **Tier 2 — shipped**: `--color 256` (the xterm cube and grey ramp) and `--color tc` (24-bit, `\x1b[38;2;R;G;Bm`) landed at **v1.8.0** ([ADR 0010](docs/adr/0010-tier-2-colour-and-emit-encoding.md)); ordered and Floyd-Steinberg dithering (`--dither`, for tiers 8, 16 and 256) at **v1.9.0** ([ADR 0011](docs/adr/0011-dithering.md)).
- **Tier 3 — in progress**: the image protocols, which skip cells entirely on terminals that read them ([ADR 0014](docs/adr/0014-tier-3-image-protocols.md)). iTerm2 inline images (`--mode iterm`) landed at **v2.4.0** and the kitty graphics protocol (`--mode kitty`) at **v2.5.0**; Sixel is pinned to 2.6.0. Each is chosen by flag, never detected. Animation stays out of scope: kii sends one still frame.

## Naming

- **Repo + binary**: `kii` (ASCII-safe form)
- **Display form**: `kiʻi` with ʻokina when written formally
- **Bare name** (no `cyrius-` prefix) — that prefix is reserved for games. kii is a tool, sibling to `hapi` (stow-equivalent), `anuenue` (lolcat-equivalent), `bannermanor` (figlet-equivalent), `mihi` (sys-info probe). Hawaiian micro-cluster on the user-tool surface.

## Substrate

- [`sankoch`](https://github.com/MacCracken/sankoch) — DEFLATE/zlib decompression. **Wired at v0.4.0** for PNG IDAT decompression. (Now folded into Cyrius stdlib at v5.8.65, so it's a stdlib-list add, not an external git dep.)
- [`darshana`](https://github.com/MacCracken/darshana) — TTY/ANSI primitives (color escape sequences, cursor positioning, `tty_winsize`). External dep since v0.6.0 / M5 when ANSI emit went live; pinned at `1.6.0` since v1.9.1. At v1.6.0 (darshana `1.3.0`) kii's own background-colour composer and its filename sanitizer moved onto darshana's `tty_bg_256_buf` and `tty_has_ctl`, both of which darshana built with kii as their first consumer.
- [`cmdit`](https://github.com/MacCracken/cmdit) — getopt-long CLI parsing (the Cyrius stdlib `flags` parser productized and extended). **Adopted at v1.1.0** in the CLI re-fold: kii's own flag set seeded cmdit's design and kii is its first consumer, so the hand-rolled parser and the stdlib `flags` dep were both dropped. `src/cli.cyr` registers into a cmdit context. Pinned at `1.5.0` via `[deps.cmdit]`.
- [`chitra`](https://github.com/MacCracken/chitra) — the image-decode substrate (pure-Cyrius PNG + JPEG + BMP + GIF → canonical RGBA8). **Forked from kii's own `src/png.cyr` and adopted back** at v1.2.0 (the PNG re-fold, [ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)) when `mabda` became the second consumer; `src/png.cyr` is now a thin adapter calling `chitra_image_decode`. JPEG arrived on the `chitra 0.3.0` re-pin at v1.4.0 ([ADR 0008](docs/adr/0008-jpeg-via-chitra.md)); BMP + GIF on the `chitra 1.0.0` re-pin at v1.5.0, with **no decode change at all** ([ADR 0009](docs/adr/0009-bmp-gif-via-chitra.md)); PNGs past 16 MiB of scanlines on the `chitra 1.3.x` re-pin at v1.9.1. Pinned at `1.3.1` via `[deps.chitra]`.
- **In-repo palette + quantizer** (`src/palette.cyr` + `src/quant.cyr`) — Linux-console 16-color RGB table + nearest-colour Euclidean quantization at the tier `--color` selects (8, 16, 256 or truecolour), plus the ordered and Floyd-Steinberg dithering `--dither` selects. These two modules and the emit/downscale layer are the only image code kii still owns.

## Multi-source prior art

Per AGNOS `feedback_redesign_dont_reinvent` the convergent shape comes from multiple references, not a single port:

| Layer | Primary reference | Cross-validation |
|---|---|---|
| Image-to-terminal conversion (overall shape) | [`chafa`](https://hpjansson.org/chafa/) — canonical, sophisticated dithering, glyph quantization | `jp2a` (JPEG-focused monochrome-leaning), `viu` (256/truecolor biased), `libcaca` (substrate library most others rooted from) |
| PNG decoder | [W3C PNG Specification](https://www.w3.org/TR/png/) (1.3) | Reference impl: `libpng`; minimal-port refs: `stb_image.h`, `lodepng` |
| 16-color ANSI palette | Linux console color table (CGA-derived) | xterm 16-color set (identical for ANSI 0-7 + bright 0-7) |
| Dithering (v1.9.0) | Floyd & Steinberg (1976); Bayer (1973) ordered matrix | `chafa` (`--dither ordered\|diffusion`), `libcaca` (`ordered2/4/8`, `fstein`) |
| Character-glyph matching (`--mode ascii`) | Alex Harri, ["ASCII characters are not pixels"](https://alexharri.com/blog/ascii-rendering): shape vectors (v1.3.1), per-dimension normalization and contrast enhancement (v1.10.0), several samples per region (supersampling; kii averages each region's area, v1.11.0) | `chafa` (`--symbols`), `jp2a` (the luminance ramp v1.3.0 started from) |
| Half-block glyph quantization | `chafa` source `chafa-canvas.c` glyph-selection routines | Various ASCII-art-converter tutorials; Unicode Block Elements block (`U+2580`-`U+259F`) spec |
| Block Elements lane (`--mode blocks`, v2.0.0) | `chafa`'s `block` symbols: two colours per cell, each region's mean, least error | notcurses' quadrant blitter (per-cell colour pair); the complement choice ADR 0004 noted for `▀`/`▄` |
| Braille lane (`--mode braille`, v2.3.0) | The Unicode Braille Patterns chart (U+2800..U+28FF: the dot order, dots 1–3 and 7 down the left); Otsu (1979) for the frame's ink level | `drawille` (the 2 × 4 dot canvas), `chafa`'s braille symbols, image-to-Braille tools that threshold and optionally dither (Floyd-Steinberg, ordered) |
| iTerm2 inline images (`--mode iterm`, v2.4.0) | iTerm2's "Inline Images Protocol" (OSC 1337 `File=`); the PNG specification (W3C, 3rd edition) for the writer, with its adaptive-filter heuristic | iTerm2's `imgcat`, `chafa -f iterm` (the same keys, its own re-encoded image), WezTerm's support for the protocol; RFC 4648 base64 |
| kitty graphics (`--mode kitty`, v2.5.0) | The kitty graphics protocol specification (APC `_G`, `a=T`, `f=100`, chunking, `q`) | kitty's own parser, run headless on kii's output (`kitty +runpy`, its `Screen` and graphics manager); `chafa -f kitty`; `kitten icat` |

## Building

```sh
cyrius deps                           # resolve stdlib deps
cyrius build src/main.cyr build/kii   # compile
./build/kii --version                 # smoke run
./build/kii image.png                 # quantize a PNG
```

Toolchain pin: the `cyrius = "…"` line in [`cyrius.cyml`](cyrius.cyml) is the source of
truth, so read it there.

### Release binaries

Each [release](https://github.com/MacCracken/kii/releases) since v2.0.1 carries
`kii-X.Y.Z-x86_64-linux`, `kii-X.Y.Z-aarch64-linux` and `kii-X.Y.Z-x86_64-agnos`, with
`SHA256SUMS`. The x86_64 Linux and agnos binaries are built with `CYRIUS_DCE=1` (dead code
eliminated); CI checks that the DCE build answers like the plain one, and that aarch64
answers like x86_64 (`scripts/check-builds-agree.sh`). Releases up to v2.0.0 carried one
x86_64 Linux binary named `kii`.

### Running the test + bench + fuzz suites

```sh
cyrius test                           # 1,193 assertions across 9 suites (cli/quant/render/ascii/blocks/braille/iterm/kitty/decode)
cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz   # 19 fuzz surfaces, 8,691,000 iters (arg/path/path-diff/envelope/geom/emit/PNG/JPEG/BMP/GIF/ASCII/area/blocks ×2/half-block rows/invert + none/braille/PNG writer/kitty)
./scripts/gen-shape-table.sh --check                            # the ASCII glyph table is the generator's output (needs ImageMagick 7 + Liberation Mono)
cyrius bench tests/kii.bcyr                                     # 13 benches (quantize, end-to-end, ASCII sampling, blocks, decode-latency)
```

Benchmark results are captured per release in [`docs/benchmarks.md`](docs/benchmarks.md).

## License

GPL-3.0-only. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md). All contributions GPL-3.0-only.

## Reporting security issues

See [SECURITY.md](SECURITY.md). Image decoders are a known-malicious-input surface; the threat model is explicit there.
