# Getting started with kii

**kii** (Hawaiian: *image / picture / likeness*) renders a PNG image
into ANSI escape sequences sized to your terminal. Pipe the output to
your screen, capture it to a file, or feed it into a BBS/MUD app that
wants pre-rendered terminal art.

## Install

```sh
git clone https://github.com/MacCracken/cyrius-kii
cd cyrius-kii
cyrius deps                                 # resolve stdlib + darshana
cyrius build src/main.cyr build/kii         # compile
./build/kii --version
```

You'll need the Cyrius toolchain pinned in `cyrius.cyml` (currently
`6.0.1`). If `cyrius` isn't on your PATH yet, see
[agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
for the bootstrap.

## First render

In a TTY (your terminal window):

```sh
./build/kii tests/fixtures/RAMGON.png
```

kii detects your terminal size via `ioctl TIOCGWINSZ`, fits the
image aspect-preservingly into `cols × (rows - 1)`, and emits a
half-block ANSI frame to stdout. Exit code 0 on success.

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

Usage:
  kii [OPTIONS] <image.png>

Options:
  -h, --help                show this help and exit
  -V, --version             print version and exit
  -w, --width N             output width in columns (0 = match terminal)
  -c, --color N             color tier: 8 or 16 (tier-2 modes post-v1)
  -v, --verbose             print decode summary to stderr after the frame

Examples:
  kii --version                              # version + etymology
  kii --help                                 # this text
  kii image.png                              # render to terminal (80x24)
  kii --verbose image.png                    # frame + dimensions/format on stderr
  kii image.png > frame.ansi                 # capture pure ANSI bytes
```

### Flag details

- **`--width N`** — Override terminal-fit width. With `--width 200`,
  kii emits exactly 200 columns; height is aspect-derived without a
  row cap. Use this when you're capturing to a file that will be
  consumed by a wider terminal than the one you're invoking from
  (e.g. building MOTD assets on a laptop for a 200-col SSH session).
- **`--color N`** — Color tier. v1.0 supports `8` and `16`; both
  currently route through the 256-color SGR escape sequence
  (`\x1b[48;5;Nm`) with the index bound to the 16-color ANSI
  palette. Tier-2 (256-color, truecolor, dithering) is post-v1 —
  see [ADR 0003](../adr/0003-color-tier-discipline.md).
- **`--verbose`** — Adds a stderr summary line after the frame:
  `<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color`.
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

**Decode-only check** — confirm a PNG parses without rendering it:

```sh
kii --verbose img.png > /dev/null
```

The verbose summary line lands on stderr; the frame is discarded.
Useful for batch-validating a fixtures directory before deploying.

## When kii rejects an image

kii errors are explicit on stderr and exit 1. Common causes:

| Stderr line | Cause |
|---|---|
| `<path>: cannot open file` | File doesn't exist or no read permission |
| `<path>: not a PNG` | First 8 bytes don't match the PNG signature |
| `<path>: malformed PNG header` | IHDR truncated, wrong length, or wrong type |
| `<path>: CRC check failed` | Per-chunk CRC32 mismatch — file corruption or tampering |
| `<path>: interlaced PNGs (Adam7) not supported in v0.x` | PNG uses Adam7 interlacing; not implemented at v1.0 |
| `<path>: unsupported bit depth or color type (tier-1: 8/16-bit only)` | Sub-byte depth (1/2/4) or palette+16-bit (spec violation) |
| `<path>: no IDAT chunks (nothing to decode)` | Structurally valid PNG with zero pixel data |
| `<path>: DEFLATE decompression failed (corrupt IDAT)` | Inflate failed or produced wrong byte count |
| `<path>: invalid PNG filter type (spec § 9 allows 0–4)` | Filter byte ∉ {0,1,2,3,4} |
| `<path>: image dimensions exceed kii policy ceiling (max 4096×4096, 256 MB raw)` | IHDR claims too-large dimensions |
| `<path>: IDAT total exceeds 1.5× inflated size (malformed or decompression bomb)` | IDAT accumulator over policy cap |
| `<path>: DEFLATE ratio exceeds 1100:1 ceiling (decompression bomb)` | Compression ratio above DEFLATE's theoretical max |

If the filename itself contains control bytes (a possible
shell-injection vector), kii substitutes
`<path containing control bytes — suppressed>` to defend the
user's terminal — see [ADR 0002](../adr/0002-security-model.md).

## What v1.0 does NOT support

By design, deferred to v1.x or v2.0:

- **JPEG / GIF / BMP** — PNG only at v1.0. Convert via `convert
  input.jpg input.png` first.
- **Adam7 interlacing** — non-interlaced PNGs only.
- **Sub-byte bit depths** (1/2/4) — bit depth 8 or 16 only.
- **Animated GIFs / video frames** — explicit post-v2 scope.
- **256-color or truecolor SGR** — tier-2 work (post-v1).
- **Floyd-Steinberg / ordered dithering** — tier-2 work.
- **Sixel / Kitty / iTerm2 image protocols** — tier-3 work
  (post-v2).
- **Filesystem traversal** — kii takes ONE path. Loop in the shell
  (`for f in *.png; do kii "$f" > "${f%.png}.ansi"; done`).
- **Interactive resize / animation** — one frame in, one frame
  out, exit.

## Where to go from here

- **Architecture & non-obvious constraints**: [`docs/architecture/README.md`](../architecture/README.md)
- **Roadmap to v1.0 + post-v1 scope**: [`docs/development/roadmap.md`](../development/roadmap.md)
- **Per-release state**: [`docs/development/state.md`](../development/state.md)
- **Benchmarks**: [`docs/benchmarks.md`](../benchmarks.md)
- **Security model + threat analysis**: [`SECURITY.md`](../../SECURITY.md), [ADR 0002](../adr/0002-security-model.md), [audit doc](../audit/2026-05-22-audit.md)
- **All design decisions**: [`docs/adr/`](../adr/)
- **CHANGELOG**: [`CHANGELOG.md`](../../CHANGELOG.md)

## Contributing

See [`CONTRIBUTING.md`](../../CONTRIBUTING.md). Short version: read
[`CLAUDE.md`](../../CLAUDE.md), follow smallest-first bite discipline,
test after every change, never bundle unrelated changes, and don't
commit (the user owns git).
