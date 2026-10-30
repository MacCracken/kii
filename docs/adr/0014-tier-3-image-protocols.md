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

## Amendment — v2.5.0 (the kitty graphics protocol)

This ADR remains **Accepted**. `--mode kitty` is Tier 3's second protocol. § Decision 1, 2, 3, 6
and 7 apply unchanged: it is chosen by flag only, has no fallback, sends a PNG kii writes, refuses
the cell settings, and decodes and refuses as every lane does. Two things differ, and one claim
in § 4 is corrected.

**1. The escapes.** The picture goes as APC escapes, its base64 split in chunks of 4,096
characters (3,072 bytes), the protocol's limit, then LF:

    ESC _ G a=T,f=100,q=2,c=C,m=1 ; <chunk> ESC \      the first (m=0 when it is the only one)
    ESC _ G m=1 ; <chunk> ESC \                        each next one
    ESC _ G m=0 ; <chunk> ESC \                        the last

- **`a=T`** transmits and displays at once, at the cursor. **`t`** stays at its default `d`: the
  data travels in the escapes, since kii writes no file and no shared memory.
- **`f=100`** sends the PNG of § 3, byte for byte the iTerm2 lane's.
- **`q=2`** suppresses every reply. kitty sends none to a command with no image id, and kii sends
  no id, but a reply would land in the shell's input after kii exits, so `q=2` makes sure.
- **No `C`**: the cursor moves past the image, and the LF starts the next line.

**2. The payload, measured.** The roadmap left it open between raw RGBA8 (`f=32`), raw with zlib
(`f=32,o=z`), and the PNG. Over the 456 corpus images kii decodes:

| Payload | Bytes | Encode |
|---|---:|---:|
| PNG, adaptive filters, zlib 6 (`f=100`) | 26,000,771 | 14.3 s |
| raw RGBA8, zlib 6 (`f=32,o=z`) | 32,513,949 (1.25×) | 7.2 s |
| raw RGBA8 (`f=32`) | 226,080,028 (8.70×) | none |

zlib-raw is a little smaller for BMP and GIF (0.83–0.86×), the same for PNG (1.02×), and 1.31×
for JPEG. The PNG was taken: it is the smallest overall, it reuses § 3's one encoder, and it
leaves both protocols sending the same bytes. zlib-raw would halve the encode at a quarter more on
the wire. Raw would need no encode, but at 8.7× the bytes.

**3. § 4 corrected: one of `c` and `r`, never both.** § 4 said "Kitty (2.5.0) takes it as `c=`
and `r=`". That would distort the picture: given both, kitty stretches the image to fill exactly
`c × r` cells. Run in kitty's own parser, a 2 : 1 image given `c=10,r=10` filled 10 × 10 cells.
Given one, kitty works out the other from its real cell size and keeps the aspect. So kii sends
the side its geometry is bound by:
- `c` for `--width N`, or an image the terminal's columns bind;
- `r` for one its rows bind.

At 10 × 20, 8 × 20 and 9 × 19-pixel cells, RAMGON at `c=80` took 32.1, 25.7 and 30.4 rows, its
true aspect each time. In a 200 × 20 terminal it went by `r=19`, which drew 47.3 × 19 cells.

**4. Checked with kitty itself.** kitty 0.49.2's Python modules carry its `Screen` and graphics
manager, the same parser the terminal runs. Run headless through `kitty +runpy`, with no window,
they read kii's escapes as a kitty window would. Over the 472-image corpus at `--width 40` and
`120`:
- **All 942 cases match the half-block lane's exit code and stderr**: 911 frames and 31 refusals.
- **Every frame has the form above.** Each chunk but the last is exactly 4,096 characters,
  nothing lies outside the escapes but the LF, and the payload is the iTerm2 lane's PNG byte for
  byte.
- **kitty reads every frame as one image**, placed over exactly the columns asked, and writes no
  reply.
- **Its decoded pixels equal ImageMagick's decode of kii's PNG** in all 456 frames at
  `--width 40`. That is two independent PNG decoders agreeing, on pixels § Measurements showed
  are chitra's.

So this lane, unlike the iTerm2 one, is checked against the terminal it targets, short of the
screen itself.

**5. What kitty does with the cursor, and the console.** After the image the cursor sits to the
right of its last row. When the image fills the terminal's width, kitty moves it to the start of
the next line itself, so kii's LF then leaves one blank line. That is a roadmap candidate. The
Linux console enters `ESapc` on `ESC _` and ignores every byte until ESC, so it draws nothing.

**Size and time.** The PNG is § 3's, and the escapes add one 7-byte head per 4,096 characters.
The archlinux logo at `--width 40` is 11,711 bytes, against 11,738 for iTerm2. CPU matches the
iTerm2 lane within noise: 12.9 against 13.1 ms for the logo, 841 against 838 ms for RAMGON.

**Tests.**
- `tests/kitty.tcyr`, 31 assertions: the head's keys, the chunking at 1, 3,071, 3,072, 3,073,
  6,144 and 20,000 bytes read back by an independent walker, the chunks written in batches,
  and the guards.
- cli: `--mode kitty` and its refusals.
- A 19th fuzz surface, 20,000 random payloads in random batches, read back key by key and
  chunk by chunk to the payload.
- Of 12 defects planted in the escapes and the CLI, the unit suite catches all 12 and the fuzz
  surface the 10 in the escapes.
- Every 2.4.0 lane, iTerm2 included, is byte-identical: 7,080 of 7,080 corpus cases.

## Amendment — v2.6.0 (Sixel)

This ADR remains **Accepted**. `--mode sixel` is Tier 3's third protocol, and the last the roadmap
pinned. § Decision 1, 2 and 7 apply: it is chosen by flag only, has no fallback, and decodes and
refuses as every lane does. It differs from the other two in what it sends and in how it sizes.

**1. kii encodes the pixels itself.** Sixel is drawn in device pixels from colour registers, so
there is no PNG for the terminal to scale. The frame is:

    ESC P 0;1;0 q "1;1;W;H  #r;2;R;G;B ...  <bands>  ESC \   LF

- **`P2 = 1`**: a pixel no colour sets keeps the terminal's background, so a transparent pixel
  (below alpha 128, as in every lane) is never drawn.
- **`"1;1;W;H`**: square pixels, and the image's size.
- **The registers are the colour codes the frame uses**, numbered 0, 1, ... in code order. Each
  is defined once, as the RGB its code stands for at the tier, in percent and rounded.
- **A band is six pixel rows.** For each colour in it, in register order, comes `#r` and then one
  character a column (0x3F plus a bit for each of the six rows that colour holds, the top row
  the low bit). The characters run from column 0 to the colour's last column, and a run of four
  or more becomes `!n<char>`. `$` goes back to the band's start between colours, and `-` moves to
  the next band.
- **One pass a band** builds a column mask per colour, so the cost is the band's pixels plus
  each colour's span.

**2. Colour: the cell lanes' quantizer, 256 colours unless told.** The roadmap pinned the
256-colour quantizer. `--mode sixel` uses the xterm cube and grey ramp at `--color 256`, which is
its default when `--color` is not given. It also takes `--color 8` and `16`, and `--dither none |
ordered | fs`, exactly as the cell lanes apply them. It refuses three settings:
- `--color tc`: Sixel holds at most 256 registers;
- `--color none`: it draws colours;
- `--invert`: it draws no ink.

**3. Sizing: the cell box in pixels, from `--cell-size`.** The box's bound side (the columns,
or the rows when the terminal's rows bind) times the cell's pixel size gives one dimension. The
image's aspect gives the other, rounded, so the image is never distorted. kii cannot measure the
cell yet: darshana reads the window's rows and columns but not its pixel fields (roadmap
§ Gated on upstream). So the size is `--cell-size WxH`, each side 1 to 256, with a default of
`10x20`. That is kii's 2:1 cell, and the size chafa itself falls back to when it cannot ask; for
`--size 40x20` chafa drew 400 × 400. A wrong cell size gives an image too large or too small for
the box, but never a distorted one. `--cell-size` with any other mode is a usage error.

A frame's pixels are capped at 16,777,216, chitra's own decode ceiling. The cell cap alone would
allow a million cells of up to 256 × 256 pixels. Past the ceiling kii says `Sixel image too large
(over 16777216 pixels); use a smaller --width or --cell-size`, exit 1.

**4. Checked by a decoder written from the manual.** No Sixel terminal is installed here, and this
host's ImageMagick (7.1.2-34) decodes every Sixel as black, even its own, so it cannot check.
Instead a decoder written from the VT330/VT340 manual, in Python and independent of kii's
Cyrius encoder, read kii's output. A Cyrius tool ran kii's pipeline up to the encoder (area
sample, quantize) and dumped the colour each pixel should have.
- **Over the corpus** (832 images; 2.6.0's corpus, § 6) under three sets (`--width 40`, 10 × 20
  cells, 256 colours; `60`, 9 × 19, 16 colours, `fs`; `40`, 8 × 16, 8 colours, `ordered`): every
  one of 2,427 frames decodes to exactly the pixels the pipeline produced. Transparency matches
  too, and nothing lies outside the raster.
- 36 cases are refused as the half-block lane refuses them.
- 33 are refused by the pixel ceiling alone. They are strips 1 or 6 pixels wide (a 1 × 400 strip
  at `--width 40` is 400 × 160,000 pixels), which the half-block lane, capped by cells, draws.
- Frames use at most 197 registers.

The same decoder read chafa's `-f sixel` output without trouble, and its image matched a box
resize of the source within 4.4 a channel.

**5. Quality and size.** The registers come from a fixed palette, not one fitted to the image.
On the Arch logo kii's frame is within 14.1 a channel of a box resize, against chafa's 4.4 with
a fitted palette (17 registers). On RAMGON at 400 × 321, kii is within 7.15 without dither and
10.62 with `fs`. An adaptive palette is a roadmap candidate. Sizes at `--width 80`:

| Image | No dither | `--dither fs` |
|---|---:|---:|
| archlinux-logo | 8,541 bytes | 179,109 bytes |
| RAMGON | 432,598 bytes | 605,462 bytes |

A flat colour dithered into cube colours breaks the runs. CPU per run (`--width 80`, fastest of
three):

| Image | Half-block | Sixel | Sixel `fs` | iTerm2 |
|---|---:|---:|---:|---:|
| archlinux-logo | 2.01 ms | 20.98 ms | 41.35 ms | 13.11 ms |
| RAMGON | 197.4 ms | 250.4 ms | 295.3 ms | 851.4 ms |

Sixel needs no zlib, so it is cheaper than the PNG protocols on photographs.

**6. A new corpus.** Through 2.5.0 the corpus was a 472-image list whose recipe was not kept,
and the list itself was lost with a scratch directory. From 2.6.0, `scripts/corpus.sh` prints it:
every PNG, JPEG, GIF and BMP under `/usr/share` outside the icon themes, then the fixtures. That
is 832 images here (763 PNG, 40 JPEG, 26 GIF, 3 BMP). Every older lane is byte-identical to 2.5.0
over it: 13,312 of 13,312 cases, 16 flag sets across half-block, ASCII, blocks, Braille, iTerm2
and kitty.

**Tests.**
- `tests/sixel.tcyr`, 25 assertions: percent colours, the register map, the head, each band form
  (bits, `$`, `-`, a partial band, an empty band, runs of three, four and 200), the masks left
  clean, `--cell-size`, and the refusals.
- cli: `--mode sixel` and the `--cell-size` default.
- A 20th fuzz surface, 20,000 random frames at tiers 8, 16 and 256 with transparency, decoded
  back to their codes by a reference decoder in the fuzz file.
- Of 15 defects planted in the encoder and its parser, the unit suite catches all 15 and the
  fuzz surface 9. The six it cannot see are:
  - the percent rounding and the register order, which it takes from the code it checks;
  - a `-` after the last band, which its decoder accepts as harmless;
  - two defects in the `--cell-size` parser, and the `tc` refusal, which it never calls.

**Consequences.** Sixel reaches the terminals the other protocols do not: xterm (with `-ti vt340`
or a Sixel-enabled build), foot, mlterm, and WezTerm, which reads all three. It costs a guess at
the cell size until darshana can say, and a fixed palette's error on flat colours. It also writes
more bytes than the PNG protocols: RAMGON's frame is 433 KB, against the iTerm2 lane's 2.48 MB of
base64 at full resolution, but at 800 × 642 pixels.
