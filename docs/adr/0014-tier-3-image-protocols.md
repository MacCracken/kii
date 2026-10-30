# 0014 — Tier 3: image protocols, and iTerm2 inline images first

**Status**: Accepted
**Date**: 2026-10-29
**Extends**: [0002](0002-security-model.md) · [0003](0003-color-tier-discipline.md) ·
[0007](0007-rendering-mode-taxonomy.md)

## Context

CLAUDE.md's tier discipline ends at Tier 3: terminal image protocols, which skip character
cells on terminals that read them. The roadmap pinned three, smallest first: iTerm2 inline
images at 2.4.0, the Kitty graphics protocol at 2.5.0, Sixel at 2.6.0. It asked this release
for an ADR on Tier 3 as a whole:
- how a protocol is chosen;
- what a protocol lane promises when the terminal ignores it;
- how cell sizing maps to each protocol.

iTerm2's protocol is one escape: `ESC ] 1337 ; File = [key=value;...] : <base64> BEL` (or ST).
Its keys are `name`, `size` (used only for a progress indicator), `width`, `height`
(a bare number is character cells), `preserveAspectRatio` (default 1) and `inline` (default
0, which downloads the file instead of drawing it). iTerm2 draws any format macOS reads,
animated GIFs included. WezTerm reads the same protocol. iTerm2 3.5 added a multipart form
for its tmux integration. iTerm2's own `imgcat` sends the file as read; chafa's `-f iterm`
sends an image it encodes itself.

The roadmap planned to send the file kii read. Doing so would put the input's own bytes in
front of the terminal's decoder, which on iTerm2 is macOS ImageIO. That includes everything
chitra validates and then skips: metadata, colour profiles, trailing data, the frames after a
GIF's first.

## Decision

**1. A protocol is a `--mode` value, chosen by the caller.** `--mode iterm` now; `kitty` and
`sixel` follow. kii reads no `TERM`, `TERM_PROGRAM` or `LC_TERMINAL`, and sends no query
(no DA1, XTGETTCAP or Kitty `a=q`). This is the roadmap's second 2.x rule: output depends
only on the arguments, the image and the terminal's size.

**2. A protocol lane promises the protocol, and nothing on terminals without it.** There is
no fallback inside one run: a caller that wants cells runs a cell lane. What such a terminal
does is its own. Observed and read so far:
- **The Linux console swallows it.** `drivers/tty/vt/vt.c` enters `ESosc` on `ESC ]` and a
  digit, ignores every byte, and leaves on BEL.
- **xterm-family terminals ignore an OSC they do not know.**
- **tmux drops it** unless the sequence is wrapped for passthrough, which kii does not do.

So a terminal without the protocol usually draws nothing, then the newline.

**3. The payload is a PNG kii writes, not the file it read.** The user chose this on
2026-10-29 over the file as read and over a per-format hybrid (§ Alternatives).
- **The PNG holds chitra's RGBA8 and nothing else**: IHDR (8-bit RGBA, no interlace), one
  IDAT and IEND (`src/png.cyr`).
  - Each row takes the adaptive filter with the least sum of |byte|, the PNG
    specification's heuristic; a tie goes to the lower filter type.
  - The rows go through sankoch's `zlib_compress` at level 6.
- **Why:**
  - The terminal's decoder sees only a minimal PNG of what kii decoded
    ([ADR 0002](0002-security-model.md) § v2.4.0).
  - A GIF shows its first frame, which keeps the scope guard on animation.
  - Every format arrives as PNG, the one every implementation of the protocol reads.
  - Transparency is exact, alpha and all.
  - The writer is there for Kitty (2.5.0).
- **It is the decoded resolution.** kii does not know the cell's pixel size (darshana does
  not expose it; roadmap § Gated on upstream), so it does not guess one. The terminal scales.

**4. Sizing: the cell box every lane fills.** `width` and `height` are the columns and rows
of kii's geometry: `--width N`, or the terminal's size, with rows derived at kii's 2 : 1 cell
assumption. With `preserveAspectRatio=1` the terminal draws the largest undistorted image
that fits the box. On a terminal whose cells are not 2 : 1 it fills the box one way and stops
short the other, but is never stretched. The frame-cell cap applies to the box as to every
lane.
- **iTerm2** takes the box in cells directly.
- **Kitty** (2.5.0) takes it as `c=` and `r=`.
- **Sixel** (2.6.0) is drawn in device pixels, so it needs the cell's pixel size. Without
  darshana's pixel fields that means a default (the roadmap's `--cell-size`).

**5. The sequence.** It is
`ESC ] 1337 ; File=inline=1;size=N;width=C;height=R;preserveAspectRatio=1 : <base64> BEL`,
then LF.
- The keys are written in that order, `size` is the PNG's length, and no `name` is sent.
- BEL ends it, as `imgcat` and chafa write it.
- It is the single `File=` form, which every implementation reads, not iTerm2 3.5's
  `MultipartFile`.
- The base64 is written in 48 KiB pieces, so no buffer holds the whole text.

**6. The cell lanes' settings are refused.** `--color`, `--dither` and `--invert` act on
cells, so with a protocol each is a usage error whenever it is given, at its default too
(`cmdit_seen`).

**7. The input is decoded and refused as in every lane.** A file chitra cannot read is refused
with the same line and exit code before anything is written, and the incomplete-file warning
still follows a frame.

## Measurements

Over the 472-image corpus at `--width 40` and `120`:
- **Structure.** All 942 cases match the half-block lane's exit code and stderr: 911 frames
  and 31 refusals. Each frame is exactly the head, strict base64 and `BEL LF`. Its `size` is
  the PNG's length, and its `width` and `height` are the half-block frame's columns and
  rows.
- **ImageMagick reads every PNG** (456 of 456, with `-regard-warnings`) as a clean 8-bit RGBA
  PNG.
- **The pixels are chitra's.** Every PNG draws byte-identical frames to its original in kii's
  own lanes (half-block truecolour at 40 and 200 columns, ASCII truecolour at 80).
- **An independent decoder agrees.** For the 425 images ImageMagick decodes as chitra does,
  ImageMagick's pixels of kii's PNG are exactly its pixels of the original.
- **The other lanes are unchanged.** Half-block, ASCII and blocks match 2.3.0 in 5,192 of
  5,192 cases, and Braille in 1,416 of 1,416.

**The PNG against the file as read:**

| Format | Images | Original bytes | kii's PNG | Ratio |
|---|---:|---:|---:|---:|
| BMP | 4 | 537,824 | 41,653 | 0.08× |
| GIF | 26 | 367,352 | 229,649 | 0.63× |
| JPEG | 31 | 3,890,289 | 20,595,326 | 5.29× |
| PNG | 395 | 5,090,111 | 5,134,143 | 1.01× |

On the wire, base64 adds a third.

**CPU** per run, fastest of three rounds, `--width 80` (a busy host, load ~2.4):

| Image | half-block | `--mode iterm` |
|---|---:|---:|
| archlinux-logo, 256² | 1.94 ms | 13.2 ms |
| RAMGON, 1152 × 925 | 200.7 ms | 880.9 ms |
| background.jpg, 2592 × 1754 | 565.1 ms | 3,140.5 ms |

Most of the difference is the encode. On RAMGON the filter pass takes 117 ms and zlib 520 ms.
A first draft of the filter pass called a function per byte and took 318 ms. zlib at level 1
would take 228 ms but write 36 % more (2.53 MB against 1.86 MB); level 6 is smaller than
RAMGON's own file (1.97 MB).

**Tests:**
- `tests/iterm.tcyr`, 41 assertions.
  - RFC 4648's base64 vectors, and the 256-byte table at once and in pieces.
  - The PNG's chunks and CRCs, and its filter choice against a reference on an image whose
    rows take all five filters.
  - A tie going to None, the round trip through chitra, the OSC head, and the refusals.
- cli: `--mode iterm`, each refusal, and `cmdit_seen` telling an explicit `--color 16` from
  the default.
- An 18th fuzz surface, 20,000 random images.
  - Each PNG's chunk structure and every CRC.
  - chitra reading it back to the same pixels.
  - Base64 in random pieces against the one-shot text and a reference decoder.
- Of 18 defects planted in base64, the PNG writer, the head and the refusals, the unit suite
  catches 17 and the fuzz surface 12. The one the unit suite misses, a Paeth tie in the
  writer, the fuzz surface catches.

**Not verified on a live terminal.** No terminal that reads the protocol is installed on the
development host. The sequence's form follows iTerm2's documentation and matches chafa's
`-f iterm` output, which uses the same keys. Showing it in iTerm2 and WezTerm is part of the
roadmap's cross-terminal verification.

## Consequences

**Positive**
- **True colour, the full resolution and real transparency** on terminals that read the
  protocol, with no cell grid.
- **The terminal's decoder parses only a minimal PNG of kii's pixels**, whatever the input
  held.
- **One still frame**, GIFs included, which keeps the animation scope guard.
- **The PNG writer serves the next protocol.**

**Negative**
- **JPEG photographs are 5.3× larger** than the file as read: a 1 MB photo becomes about 7 MB
  of base64.
- **The encode is slow for large images**, mostly sankoch's deflate: 3.1 s for a
  4.5-megapixel JPEG. Sending only the box's pixels needs the cell size (a roadmap
  candidate).
- **Nothing is drawn where the protocol is missing**, tmux included. The caller must know its
  terminal.
- **Colour profiles and gamma are dropped** with the rest of the metadata. A file that
  depends on its profile shows its raw values, as it does in every cell lane.
- **iTerm2's page states a 1,048,576-byte limit without saying what it bounds** (it appears
  in the multipart section). kii sends one sequence, as `imgcat` does for files of any size.

**Neutral**
- **kii now writes PNG.** It is still not a decoder, and it writes nothing to disk: the PNG
  exists only inside the escape on stdout.

## Alternatives considered

- **The file as read** (the roadmap's plan, `imgcat`'s way). It is smallest for JPEG and needs
  no encoder. It was rejected for passing the input's own bytes to the terminal's decoder,
  and for letting a GIF animate.
- **A hybrid**: PNG and JPEG as read, BMP and GIF as PNG. Smaller JPEGs, but the metadata
  exposure remains for the two common formats, and there are two paths to test.
- **Detecting the terminal** (`TERM_PROGRAM`, `LC_TERMINAL`, a DA or capability query) to pick
  a protocol or fall back. Rejected by the environment-blind rule. A query would also need a
  read from the terminal, which kii does not do.
- **iTerm2 3.5's `MultipartFile`.** It is needed only for iTerm2's tmux integration, and older
  versions and other implementations lack it. It is a candidate for a tmux flag.
- **ST rather than BEL.** iTerm2 accepts either. BEL is what `imgcat` and chafa write.
- **Sending `name=`.** It would put the path, base64-encoded, on the wire for nothing an
  inline image uses.
- **Downscaling to a guessed cell size.** It would make the output smaller and faster, but it
  is a guess. It waits for the measured cell size.

## References

- iTerm2, "Inline Images Protocol", <https://iterm2.com/documentation-images.html> (read
  2026-10-29).
- W3C, *Portable Network Graphics (PNG) Specification* (Third Edition), § 7 (filtering) and
  § 12.8 (filter selection).
- RFC 4648, *The Base16, Base32, and Base64 Data Encodings*, § 4.
- Linux `drivers/tty/vt/vt.c`: `ESnonstd`, `ESosc`, `handle_ascii`.
- chafa 1.18.3, `-f iterm`; iTerm2's `imgcat`.
