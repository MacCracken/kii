# Getting started with kii

**kii** (Hawaiian: *image / picture / likeness*) renders a PNG,
baseline JPEG, BMP or GIF (first frame) image into ANSI escape
sequences sized to your terminal. Pipe the output to
your screen, capture it to a file, or feed it into a BBS/MUD app that
wants pre-rendered terminal art.

## Install

```sh
git clone https://github.com/MacCracken/kii
cd kii
cyrius deps                                 # resolve stdlib + darshana / cmdit / chitra
cyrius build src/main.cyr build/kii         # compile
./build/kii --version
```

You'll need the Cyrius toolchain version pinned by the `cyrius = "…"`
line in `cyrius.cyml`. The manifest is the source of truth, so read the
version there. If `cyrius` isn't on your PATH yet, see
[agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
for the bootstrap.

## First render

In a TTY (your terminal window):

```sh
./build/kii tests/fixtures/RAMGON.png
```

kii detects your terminal size via `ioctl TIOCGWINSZ`, fits the
image aspect-preservingly into `cols × (rows - 1)`, and emits a
half-block ANSI frame to stdout. Exit code 0 on success. (A terminal
that reports 0 rows, as a serial line can, gets 23 frame rows.)

kii takes a path, not stdin. To render from a pipe, name the pipe:

```sh
cat tests/fixtures/RAMGON.png | ./build/kii /dev/stdin
```

`kii <(…)` works the same way. Both have worked since v1.6.4.

Non-TTY (piped or redirected):

```sh
./build/kii tests/fixtures/RAMGON.png > frame.ansi
```

Terminal-size detection falls back to 80×24 (the historically-correct
BBS default). The resulting `frame.ansi` is byte-pure ANSI — `cat
frame.ansi` reproduces the render in any 256-color-capable terminal.

## CLI surface

```sh
$ ./build/kii --help
kii — kiʻi (Hawaiian: image / picture / likeness). Image → ANSI art.

Usage: kii [options] [args]

Options:
  -h, --help	show this help and exit
  -V, --version	print version and exit
  -w, --width <int>	output width in columns (0 = match terminal)
  -c, --color <int>	color tier: 8 or 16 (tier-2 modes post-v1)
  -v, --verbose	print decode summary to stderr after the frame
  -m, --mode <halfblock|ascii>	render mode (default: halfblock)

Examples:
  kii --version                              # version + etymology
  kii --help                                 # this text
  kii image.png                              # render, fitted to the terminal
  kii photo.jpg                              # baseline JPEG works too
  kii art.bmp                                # ...as do BMP and GIF (first frame)
  kii --verbose image.png                    # frame + dimensions/format on stderr
  kii --mode ascii image.png                 # text-glyph art (shape-vector, colored)
  kii image.png > frame.ansi                 # capture pure ANSI bytes
```

### Flag details

- **`--width N`** — Override terminal-fit width. With `--width 200`,
  kii emits exactly 200 columns; height is aspect-derived and is not
  limited to your terminal's rows. Use this when you're capturing to a file that will be
  consumed by a wider terminal than the one you're invoking from
  (e.g. building MOTD assets on a laptop for a 200-col SSH session).
  `0` (the default) means fit the terminal; the maximum is 100000 and
  negative values are refused. The frame itself is capped at
  1,048,576 character cells (since v1.6.4), which a very narrow
  image can reach at an ordinary width; kii then says
  `frame too large (…)` and exits 1.
- **`--color N`** — Color tier: `8` or `16`. `16` uses the whole
  ANSI palette, `8` the normal-intensity half. Both currently emit
  the 256-color SGR escapes (`\x1b[38;5;Nm` / `\x1b[48;5;Nm`) with
  the index bound to that palette. Tier-2 is pinned in the roadmap:
  256-color and truecolor at 1.8.0 (which also moves tier 1 to the
  plain 8/16-color SGR codes), dithering at 1.9.0 — see
  [ADR 0003](../adr/0003-color-tier-discipline.md).
- **`--verbose`** — Adds a stderr summary line after the frame:
  `<path>: <W>x<H> <N> pixels (<color_type_name>) → <T>-color`, where
  `<T>` is the active `--color` tier (8 or 16).
  Stdout stays pipe-pure (only the ANSI frame); stderr is human
  diagnostic.

## Common pipelines

**MOTD banner** — render a fixed-size frame for a known-width SSH banner:

```sh
kii --width 80 motd.png > /etc/motd.ansi
```

The 80-column constraint makes the output reproducible across login
shells regardless of who's connecting from what terminal.

**Auto-fit terminal view** — drop into a running shell:

```sh
kii pic.png                                # uses your actual cols × rows-1
```

**Captured for downstream** — write to a file for a BBS / MUD app to
pipe later:

```sh
kii --width 80 room-illustration.png > rooms/cave.ansi
```

**Decode-only check** — confirm an image parses without rendering it:

```sh
kii --verbose img.png > /dev/null
```

The verbose summary line lands on stderr; the frame is discarded.
Useful for batch-validating a fixtures directory before deploying.

## When kii rejects an image

kii errors are explicit on stderr and exit 1. Nothing reaches stdout.
Reading and decoding the file:

| Stderr line | Cause |
|---|---|
| `<path>: cannot open file` | File doesn't exist, no read permission, or another open/read error |
| `<path>: is a directory, not an image file` | The path is a directory (since v1.6.4; it used to read "file exceeds size ceiling") |
| `<path>: file exceeds size ceiling (max 256 MB)` | Input larger than `KII_MAX_RAW_BYTES`; the read stops at the cap |
| `<path>: unrecognized image format (expected PNG, JPEG, BMP, or GIF)` | Signature matched none of the four, including an empty or very short file |
| `<path>: malformed PNG (bad chunk, ordering, or palette)` | PNG chunk length/type/order, IEND length, or palette violation (including an out-of-range palette index) |
| `<path>: malformed JPEG (bad marker, segment, or entropy data)` | JPEG marker/segment framing or entropy stream |
| `<path>: malformed BMP (bad DIB header, palette, or RLE stream)` | BMP header, palette bounds, or RLE walk |
| `<path>: malformed GIF (bad descriptor or color table)` | GIF screen/image descriptor or colour table |
| `<path>: malformed PNG (truncated chunk stream)` | PNG ended mid-chunk |
| `<path>: truncated image (unexpected end of data)` | JPEG/BMP/GIF ended mid-stream |
| `<path>: CRC check failed` | Per-chunk CRC32 mismatch — PNG only; corruption or tampering |
| `<path>: unsupported interlace method (only 0=none / 1=Adam7 are valid)` | A PNG interlace method other than 0 or 1 (Adam7 itself is supported) |
| `<path>: unsupported bit depth for this color type (PNG § 11.2.2)` | A depth/colour-type pair the PNG spec forbids |
| `<path>: unsupported JPEG feature (progressive, arithmetic, 12-bit, non-baseline, CMYK/4-component, or an Adobe colour transform)` | A valid JPEG that chitra's baseline decoder declines |
| `<path>: unsupported BMP feature (bit depth, compression method, or channel mask)` | Bit depth outside `{1,4,8,16,24,32}`, a compression method chitra refuses (`BI_JPEG`, `BI_PNG`, OS/2 Huffman 1D, `BI_CMYK`), or a bad channel mask |
| `<path>: unsupported image feature (unrecognized critical chunk, compression method, or color type)` | Unrecognized PNG critical chunk, compression or filter method, or colour type |
| `<path>: no IDAT chunks (nothing to decode)` | Structurally valid PNG with zero pixel data |
| `<path>: no image in GIF (no image descriptor)` | Structurally valid GIF with no image in it (since v1.6.4; it used to read "no IDAT chunks") |
| `<path>: DEFLATE decompression failed (corrupt IDAT)` | PNG inflate failed or produced the wrong byte count |
| `<path>: corrupt GIF image data (bad LZW stream)` | GIF LZW stream is corrupt (since v1.6.4; it used to read "DEFLATE decompression failed") |
| `<path>: invalid PNG filter type (spec § 9 allows 0–4)` | Filter byte ∉ {0,1,2,3,4} |
| `<path>: image dimensions are zero or past the policy ceiling (max 16.7M px / 65535 per side / 256 MB)` | A zero width or height, or dimensions or compression ratio past the bomb-defence caps |
| `<path>: out of memory or image too large (possible decompression bomb)` | An allocation failed, or a PNG's compressed IDAT data past the 256 MB cap |
| `<path>: image too large to decode (pixel data inflates past the decompressor's 16 MiB ceiling)` | A valid PNG bigger than sankoch can inflate — about 5.6 megapixels of 8-bit RGB, 4.2 of RGBA (since v1.6.0; it used to read "malformed PNG"). Downscale it first, e.g. with ImageMagick |
| `<path>: image decode failed` | A decode error with no specific message. Not expected; please report it |

After a successful decode:

| Stderr line | Cause |
|---|---|
| `<path>: could not compute output geometry` | Degenerate source dimensions |
| `<path>: frame too large (over 1048576 cells); use a smaller --width` | The frame would exceed 1,048,576 character cells — usually a very narrow image at an explicit `--width` (since v1.6.4) |
| `<path>: downscale failed (out of memory)` | The resampled buffer could not be allocated |
| `<path>: quantization failed (OOM)` | The palette-index buffer could not be allocated |
| `<path>: ANSI emit failed (downscale or quantize not run)` | Internal ordering error in the half-block lane. Not expected; please report it |
| `<path>: ANSI emit failed (downscale not run)` | The same, in the `--mode ascii` lane |
| `<path>: failed to write frame to stdout` | write(2) to stdout failed — e.g. the destination filesystem is full |

Three warnings do **not** abort — the frame still renders and kii exits 0:

| Stderr line | Meaning |
|---|---|
| `<path>: warning: incomplete PNG (no IEND chunk seen)` | Pixels decoded, but the stream never closed (spec § 5.3 tolerance) |
| `<path>: warning: incomplete JPEG (truncated scan or no EOI marker)` | Partial scan; the frame is what decoded |
| `<path>: warning: incomplete GIF (image data ran out; the rest is drawn in palette colour 0)` | LZW ended early; chitra fills the missing pixels with palette entry 0 |

### Usage errors (exit 2)

A bad command line prints one `kii: …` line on stderr, then the
`--help` text, and exits 2:

| Stderr line | Cause |
|---|---|
| `kii: unknown flag` | A flag kii does not define |
| `kii: flag missing value` | `--width`, `--color` or `--mode` with nothing after it |
| `kii: bad integer value` | `--width` or `--color` given something that is not an integer |
| `kii: short flags take no attached value and cannot be bundled (use -w 40 -v, not -w40 or -wv)` | `-w40`, `-wv`, `-v=1` and similar |
| `kii: --verbose takes no value` | A switch given `=value`; the line names it (`--help`, `--version` likewise) |
| `kii: flag takes no value` | The same, when no flag can be named |
| `kii: --color must be 8 or 16` | Any other `--color` value |
| `kii: --width must be between 0 and 100000 (0 = fit the terminal)` | `--width` over 100000 or negative (one line since v1.7.0, when cmdit took over the check; a negative width meant "fit the terminal" before v1.6.4) |
| `kii: --mode must be halfblock or ascii` | Any other `--mode` value |
| `kii: missing image path` | No path given |
| `kii: too many arguments (expected one image path)` | More than one path |
| `kii: out of memory` | The parser could not allocate |
| `kii: could not read the full command line` | The command line is over 2 MiB, or `/proc` is unavailable |
| `kii: argument parse error` | Any other parse error |

Interlaced (Adam7) PNGs and sub-byte bit depths **are** supported — since v1.2.2.
This table listed them as rejections for three releases after that stopped being
true; corrected at the v1.5.1 P-1 sweep along with six other rows naming messages
kii has not emitted since the v1.2.0 decoder re-fold.

If the filename itself contains control bytes (a possible
terminal-injection vector), kii substitutes
`<path containing control bytes — suppressed>` to defend the
user's terminal — see [ADR 0002](../adr/0002-security-model.md).
"Control bytes" covers C0 (TAB and LF excepted), DEL, C1 in raw and
UTF-8 form, and any byte sequence that is not well-formed UTF-8 —
since v1.6.0 by the strict RFC 3629 rule, so an overlong form or a
surrogate in a filename is suppressed too. Ordinary non-Latin
filenames echo unchanged. So do Unicode bidi and format characters
such as U+202E, which are valid UTF-8; that is an accepted risk (see
[`SECURITY.md`](../../SECURITY.md) § Accepted risks).

## What kii does NOT support

By design, deferred, or refused upstream:

- **Progressive / arithmetic / 12-bit / CMYK JPEG** — rejected cleanly as
  `unsupported JPEG feature …`. chitra is baseline-only; progressive would arrive
  on a `[deps.chitra]` re-pin, exactly as the other formats did.
- **Animated GIF beyond the first frame** — kii is a still-frame renderer and
  chitra decodes frame 1 by design (chitra ADR 0005). A `.gif` renders its
  opening frame.
- **BMP bit depths outside `{1,4,8,16,24,32}`, `BI_JPEG` / `BI_PNG` /
  OS/2 Huffman 1D / `BI_CMYK` compression, or a malformed `BI_BITFIELDS`
  mask** — rejected as `unsupported BMP feature …`.
- **Ancillary PNG chunks** (`tEXt` / `iTXt` / `zTXt` / `iCCP` / `eXIf` / `sCAL`)
  and **APNG** — not decoded; skipped or refused per chunk criticality.
- **Transparency** — since v1.6.4 alpha is composited over black, so a
  fully transparent pixel renders black. Drawing it in the terminal's
  own background colour is pinned to 1.8.0 in the roadmap.
- **256-color or truecolor SGR**, and **Floyd-Steinberg / ordered dithering** —
  tier-2 work, pinned to 1.8.0 and 1.9.0 in the roadmap (see
  [ADR 0003](../adr/0003-color-tier-discipline.md)).
- **Sixel / Kitty / iTerm2 image protocols** — tier-3 work, open for 2.0.
- **Filesystem traversal** — kii takes ONE path. Loop in the shell
  (`for f in *.png; do kii "$f" > "${f%.png}.ansi"; done`).
- **Interactive resize / animation** — one frame in, one frame
  out, exit.

**Corrected at v1.5.1.** This section was headed "What v1.0 does NOT support" and
listed **JPEG / GIF / BMP** ("PNG only at v1.0. Convert via `convert input.jpg
input.png` first"), **Adam7 interlacing** and **sub-byte bit depths** (1/2/4).
All five have been supported for releases — Adam7 and sub-byte depths since
v1.2.2, JPEG since v1.4.0, BMP and GIF since v1.5.0 — so the guide was telling
readers to convert files kii reads natively.

## Where to go from here

- **Architecture & non-obvious constraints**: [`docs/architecture/README.md`](../architecture/README.md)
- **Roadmap** (open work, each item pinned to a version): [`docs/development/roadmap.md`](../development/roadmap.md)
- **Per-release state**: [`docs/development/state.md`](../development/state.md)
- **Benchmarks**: [`docs/benchmarks.md`](../benchmarks.md)
- **Security model + threat analysis**: [`SECURITY.md`](../../SECURITY.md), [ADR 0002](../adr/0002-security-model.md), the audits in [`docs/audit/`](../audit/)
- **All design decisions**: [`docs/adr/`](../adr/)
- **CHANGELOG**: [`CHANGELOG.md`](../../CHANGELOG.md)

## Contributing

See [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Short version: read
[`CLAUDE.md`](../../CLAUDE.md), follow smallest-first bite discipline,
test after every change, never bundle unrelated changes, and don't
commit (the user owns git).
