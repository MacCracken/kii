# kii

**kii** (Hawaiian: *image / picture / likeness*) — image → ANSI/ASCII-art converter for terminal display.

Cyrius-native equivalent of [`chafa`](https://hpjansson.org/chafa/) / [`jp2a`](https://github.com/Talinx/jp2a) / [`viu`](https://github.com/atanunq/viu). Reads raster image input (PNG, JPEG, GIF, BMP planned), quantizes to a terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to the terminal's cols × rows.

## Status

**Pre-alpha — v0.1.0 scaffold** (2026-05-22). Compiles + prints version banner. No working image-decode or ANSI-emit features yet. See [`docs/development/roadmap.md`](docs/development/roadmap.md) for the milestone path to v1.0.

Scaffolded during the agnos 1.32.x networking-arc cycle as the userland-aesthetic substrate the BBS/MUD apps will eventually consume.

## Color-tier roadmap

The world prior art (`chafa`) ships every tier from monochrome through 24-bit truecolor. kii chooses the order deliberately:

- **Tier 1 — v0.x → v1.0**: 8/16-color ANSI palette + half-block (`▀`/`▄`) glyph quantization. Historically-correct rendering target for BBS / MUD clients of the early-90s era; maximum terminal compatibility; well-defined floor.
- **Tier 2 — post-v1**: 256-color ANSI palette + 24-bit truecolor escape sequences (`\x1b[38;2;R;G;Bm`) + dithering schemes (Floyd-Steinberg, ordered/Bayer) for higher fidelity.
- **Tier 3 — future**: Sixel / Kitty / iTerm2 image-protocol direct rendering (skips ASCII art entirely on supporting terminals). Animated GIF / video frame-pipe support.

## Naming

- **Repo + binary**: `kii` (ASCII-safe form)
- **Display form**: `kiʻi` with ʻokina when written formally
- **Bare name** (no `cyrius-` prefix) — that prefix is reserved for games. kii is a tool, sibling to `hapi` (stow-equivalent), `anuenue` (lolcat-equivalent), `bannermanor` (figlet-equivalent), `mihi` (sys-info probe). Hawaiian micro-cluster on the user-tool surface.

## Substrate

- [`darshana`](https://github.com/MacCracken/darshana) — TTY/ANSI primitives (color escape sequences, cursor positioning). Added as a dep at v0.6.0 when ANSI emit lands.
- [`sankoch`](https://github.com/MacCracken/sankoch) — DEFLATE/zlib decompression. Added as a dep at v0.4.0 when PNG IDAT decompression lands (PNG's IDAT chunks are deflate-compressed streams).
- **In-repo PNG decoder** at v0.2.0 → v0.4.0 — signature + IHDR + IDAT extraction land first; the full RGB-out path lands when sankoch is wired in. Graduates to a separate Sanskrit-named substrate lib (`chitra` / `rupa` / TBD) once a second consumer surfaces, per the `mihi → iam/chakshu` extract-on-2nd-consumer pattern.

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
cyrius test                           # run [build].test + tests/*.tcyr
./build/kii --version                 # smoke run
```

Toolchain pin: `cyrius = "6.0.1"` (in [`cyrius.cyml`](cyrius.cyml)).

## License

GPL-3.0-only. See [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and [CLAUDE.md](CLAUDE.md). All contributions GPL-3.0-only.

## Reporting security issues

See [SECURITY.md](SECURITY.md). Image decoders are a known-malicious-input surface; the threat model is explicit there.
