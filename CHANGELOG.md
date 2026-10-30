# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [2.7.0] - 2026-10-30

**Every lane at the terminal's own cell shape** ([ADR 0015](docs/adr/0015-measured-cell.md)).
darshana 1.7.0 reports the window's size in pixels, so kii measures the cell instead of
assuming it is twice as tall as wide.

⚠ **The default output changes on a terminal that reports a cell whose shape is not 1:2.**
There, 2.6.0 drew every image too tall: 5.6 % on a 9x19 cell, 10 % on a 10x22 one. 2.7.0 draws
it at its own aspect. Every frame is byte-identical to 2.6.0 in three cases: off a terminal, on
a terminal that reports no pixels, and on any 1:2 cell (36,584 of 36,584 corpus cases).

### Added

- **The measured cell.** kii reads the terminal once, with darshana's `tty_winsize_px`.
  - The rows and columns size the frame, as before.
  - The window's pixels over them give the cell, each side rounded down. It is used when all
    four values are reported and both sides are 1–256; otherwise the cell is 10x20, the 2:1
    cell every lane assumed through 2.6.0.
  - Off a terminal there is nothing to read. A frame written to a file or a pipe is the same
    wherever it was made, under `--width N` too.
- **Every lane fits the cell's shape.** For a cell `cw` × `ch` pixels:
  - a frame `C` columns wide gets `(src_h × C × cw) / (src_w × ch)` rows;
  - when the terminal's rows bind, the frame gets `(rows × ch × src_w) / (src_h × cw)` columns.

  A k × 2k cell gives 2.6.0's arithmetic exactly. The cell lanes, the iTerm2 box, the kitty
  lane's `c=` / `r=` choice and the Sixel box all follow it, and Sixel draws in the cell's
  pixels with no `--cell-size`.
- `--verbose` names the cell when it was measured or given, as `…, cell 9x19 (measured)`. The
  default cell adds nothing.

### Changed

- **`--cell-size WxH` applies to every lane** and wins over the measurement. It was Sixel's
  alone and the other lanes refused it, so `kii: --cell-size applies to --mode sixel only` is
  gone. A malformed value is refused in every lane. Give the flag to make a frame independent
  of the terminal it is drawn on.
- **darshana 1.6.0 → 1.7.0**, for `tty_winsize_px`. `cyrius.lock` was regenerated, and only
  darshana's commit pin and bundle hash changed.
- `--help` describes `--cell-size` for every lane, and its Sixel example no longer asks for
  the cell size.

### Fixed

- **A Sixel image could be taller than the terminal.** 2.6.0 chose which side bounds the box at
  2:1, whatever `--cell-size` said. With a cell flatter than 1:2, the image could need one row
  more than the terminal had. A 1000x300 image at `--cell-size 10x10` on a 24-row pty drew 240
  pixels: 24 rows, one past the 23 above the prompt. 2.7.0 draws 230.

### Measured (832-image corpus, 820 that decode)

- **Against 2.6.0**, 36,584 cases, none differing:
  - off a terminal: every lane, fit and `--width`, with tiers, dithers and `--verbose`;
  - a 24x80 pty with no pixels;
  - an 8x16 cell (Sixel against 2.6.0 given `--cell-size 8x16`);
  - a 9x19 cell with `--cell-size 10x20`, against 2.6.0 given nothing.
- **1,640 end-to-end checks on a 9x19-cell pty**: the fitted half-block frame's rows and
  columns, its rows at `--width 40`, and the Sixel raster size, each computed from the image's
  size.
- **How many frames a measured cell changes**, fitted into a 24x80 terminal:

  | Cell | Frames changed | 2.6.0's frame, drawn, vs true height |
  |---|---:|---:|
  | 10x20, 9x18 | 0 | — |
  | 9x19 | 702 (85.6 %) | +5.6 % |
  | 8x17 | 715 (87.2 %) | +6.3 % |
  | 7x15 | 744 (90.7 %) | +7.1 % |
  | 12x26 | 751 (91.6 %) | +8.3 % |
  | 10x22 | 756 (92.2 %) | +10.0 % |

### Tests

- **1,246 assertions**, up from 1,223:
  - cli 257 → 268: `kii_measured_cell`, and `--cell-size` outside Sixel;
  - render 263 → 275: geometry at other cells, and 28,224 comparisons of four 1:2 cells
    against 10x20.
- **A 21st fuzz surface** (1,000,000 iterations, 9,711,000 in all) checks:
  - geometry at random cells, against its defining inequalities;
  - any k × 2k cell against 10x20;
  - `kii_measured_cell`.
- **Planted defects.** Of 12 in the new geometry and cell code, the unit suites catch 11. The
  twelfth drops the explicit test of a 0 pixel field, and is equivalent: such a field already
  gives a side under 1, which is refused. Of 6 in main's wiring, the corpus checks catch all 6.
- `scripts/check-builds-agree.sh` gains three `--cell-size` lanes, 266 → 293 cases.

### Documentation

- **ADR 0015** (new): the measured cell, `--cell-size` in every lane, and why the protocols
  keep the decoded resolution. On a HiDPI display, whether the pixel fields count device
  pixels or points is not known for each terminal.
- ADRs 0004, 0007 and 0014 are amended to point at it.
- **The roadmap**:
  - the darshana gate is removed, since it shipped;
  - the protocols-at-the-box's-pixels candidate records why it waits;
  - the stuck-bold candidate no longer says darshana has no composer for `22;31`.
    `tty_sgr_list_buf` (darshana 1.3.0) is one.
- README, the getting-started guide, examples 07 and 08, and the architecture notes are
  updated.

## [2.6.0] - 2026-10-29

**Tier 3's third protocol: Sixel, `--mode sixel`, encoded by kii**
([ADR 0014](docs/adr/0014-tier-3-image-protocols.md) § v2.6.0). Every pin of the 2.x roadmap has
now shipped. Every older lane is byte-identical to 2.5.0 (13,312 of 13,312 cases over the new
832-image corpus).

### Added

- **`--mode sixel`** writes one DCS: `ESC P 0;1;0 q "1;1;W;H`, the registers as `#r;2;R;G;B` in
  percent, the image in six-row bands, `ESC \` and a newline.
  - **kii encodes it.** Sixel is drawn in device pixels from colour registers, so kii resamples
    the image to the cell box in pixels (the area sampler), quantizes it, and writes each band a
    colour at a time, with runs of four or more as `!n<char>`.
  - **Colours**: the 256-colour quantizer by default, or `--color 8` / `16`, with `--dither` as
    in the cell lanes. `--color tc`, `--color none` and `--invert` are refused.
  - **Transparency**: pixels below alpha 128 are never drawn (`P2 = 1`), so the terminal's
    background shows.
  - **Frame cap**: at most 16,777,216 pixels; past that kii refuses with `Sixel image too
    large`.
  - `--verbose` reports `→ Sixel WxH pixels, N of T colours`.
- **`--cell-size WxH`** (default `10x20`, each side 1–256): the terminal's cell size in pixels,
  which Sixel needs and kii cannot measure yet (darshana does not report the window's pixel
  size). It is used only with `--mode sixel`; other modes refuse it. A wrong size makes the
  image too large or small, never distorted. 10 × 20 is kii's 2:1 cell and chafa's fallback.
- **`scripts/corpus.sh`** prints the image corpus releases are measured over: every PNG, JPEG,
  GIF and BMP under `/usr/share` outside the icon themes, then the fixtures. It replaces a
  472-image list whose recipe was never kept and which was lost with a scratch directory. It
  gives 832 images here.
- **Example 08**: the Arch logo as Sixel.

### Changed

- An unknown `--mode` reads `kii: --mode must be halfblock, ascii, blocks, braille, iterm,
  kitty or sixel`.

### Measured (832-image corpus)

- **Checked by an independent decoder.** No Sixel terminal is installed, and this host's
  ImageMagick decodes every Sixel as black, its own included. A decoder written from the VT340
  manual, in Python, read every frame against kii's own pipeline under three sets of width,
  cell size, tier and dither:
  - all 2,427 frames decode to exactly the pixels kii's pipeline produced, transparency
    included;
  - 36 cases are refused as the half-block lane refuses them;
  - 33 are refused by the pixel ceiling alone: strips 1–6 pixels wide.
- **Quality.** The palette is the fixed xterm one. On the Arch logo kii is within 14.1 a channel
  of a box resize, against chafa's 4.4 with a palette fitted to the image, so an adaptive palette
  is a roadmap candidate. RAMGON is within 7.15 (10.62 with `fs`).
- **Size and CPU** at `--width 80`:

  | Image | Bytes | Bytes with `fs` | CPU | Half-block | iTerm2 |
  |---|---:|---:|---:|---:|---:|
  | RAMGON | 433 KB | 605 KB | 250 ms | 197 ms | 851 ms |
  | archlinux logo | 8.5 KB | 179 KB | 21 ms | 2.0 ms | 13 ms |

### Tests

- **1,223 assertions**, up from 1,193.
  - A new suite, `tests/sixel.tcyr` (25): percent colours, the register map, the head, every
    band form, the masks left clean, `--cell-size`, the refusals.
  - cli 252 → 257.
- **A 20th fuzz surface** (20,000 iterations, 8,711,000 in all): random frames at tiers 8, 16
  and 256 with transparency, decoded back to their codes by a reference decoder.
- Of 15 planted defects, the unit suite catches all 15 and the fuzz surface 9.
- `scripts/check-builds-agree.sh` gains two Sixel lanes and four CLI cases: 244 → 266.

### Documentation

- ADR 0014 is amended with § v2.6.0: the encoding, colours, sizing, the independent check, the
  quality, and the new corpus.
- ADRs 0002, 0003, 0007 and 0011 are amended: the DCS grammar, tier 3 complete, `sixel` and
  `--cell-size`, and dithering's registers.
- The roadmap's last pin is removed. Nothing is pinned; what remains is gated on upstream
  (darshana's pixel size among it) or a candidate (an adaptive Sixel palette is new).

## [2.5.0] - 2026-10-29

**Tier 3's second protocol: kitty graphics, `--mode kitty`**
([ADR 0014](docs/adr/0014-tier-3-image-protocols.md) § v2.5.0). The same PNG the iTerm2 lane
sends, as APC escapes kitty reads, and checked with kitty's own parser. Every other lane is
byte-identical to 2.4.0 (7,080 of 7,080 corpus cases, the iTerm2 lane included).

### Added

- **`--mode kitty`** writes `ESC _ G a=T,f=100,q=2,c=C,m=1 ;` and the first 4,096 base64
  characters, `ESC _ G m=1 ;` for each next chunk, `m=0` on the last, then LF.
  - **The payload is the iTerm2 lane's PNG**, byte for byte.
  - **No reply**: no image id is sent, and `q=2` suppresses replies besides.
  - **No file or shared memory**: the data travels in the escapes (`t=d`).
  - **Sized by one side only.** `c=` is the columns: always under `--width N`, and when the
    terminal's columns bind. `r=` is the rows, when its rows bind. Given both, kitty stretches
    the image to fill them. Given one, it works out the other from its real cell size, so the
    aspect is always true.
  - **`--color`, `--dither` and `--invert` are refused** with it whenever given, as with
    `--mode iterm`.
  - `--verbose` reports `→ kitty graphics (N-byte PNG)`.
- **Example 07**: the Arch logo by the kitty protocol, and what kitty's parser reads from it.

### Changed

- An unknown `--mode` reads `kii: --mode must be halfblock, ascii, blocks, braille, iterm or
  kitty`.

### Measured

- **The payload.** Over 456 images:

  | Payload | Bytes | Encode |
  |---|---:|---:|
  | PNG | 26.0 MB | 14.3 s |
  | raw RGBA with zlib | 32.5 MB | 7.2 s |
  | raw RGBA | 226 MB | none |

  The PNG is smallest and is shared with the iTerm2 lane. zlib-raw is half the encode for a
  quarter more bytes. Raw is 8.7× the bytes.
- **kitty's own parser** (`kitty +runpy`, its `Screen` and graphics manager, no window), over
  the 472-image corpus at two widths:
  - 911 frames, each read as one image placed over exactly the columns asked, with no reply;
  - 31 refusals that match the half-block lane's;
  - every chunk but the last exactly 4,096 characters;
  - at `--width 40`, kitty's decoded pixels equal ImageMagick's decode of the PNG in all 456
    frames.
- **The aspect, in kitty's parser.** RAMGON at `c=80` took 32.1, 25.7 and 30.4 rows at three
  cell sizes, its true aspect each time. A 200 × 20 terminal sized it by rows (`r=19`), 47.3 ×
  19 cells.
- **CPU** matches the iTerm2 lane (RAMGON 841 against 838 ms): the encode is the cost.
- **Found:** when the image fills the terminal's width, kitty moves the cursor to the next line
  itself, so kii's LF leaves a blank line. It is a roadmap candidate.

### Fixed (documentation)

- **ADR 0014 § 4 said the kitty lane would send both `c=` and `r=`.** That stretches the image.
  It is corrected: one of them, as above.

### Tests

- **1,193 assertions**, up from 1,151.
  - A new suite, `tests/kitty.tcyr` (31): the head's keys, and chunking at six payload sizes
    read back by an independent walker, in one batch and in two. Plus the guards.
  - cli 244 → 252: `--mode kitty`, its refusals, `kii_mode_is_protocol`.
- **A 19th fuzz surface** (20,000 iterations, 8,691,000 in all): random payloads in random
  batches of chunks, read back key by key and chunk by chunk to the payload.
- Of 12 planted defects, the unit suite catches all 12 and the fuzz surface the 10 in the
  escapes.
- `scripts/check-builds-agree.sh` gains a kitty lane and two CLI cases: 233 → 244.

### Documentation

- ADR 0014 is amended with § v2.5.0: the escapes, the payload measured, the `c`/`r` correction,
  the check in kitty's parser, and the cursor.
- ADRs 0002 and 0007 are amended for the APC escapes and the sixth `--mode`.
- The roadmap's 2.5.0 section is removed; 2.6.0 (Sixel) is the last Tier 3 pin. A new
  candidate covers the blank line at full width.

## [2.4.0] - 2026-10-29

**Tier 3 opens: iTerm2 inline images, `--mode iterm`**
([ADR 0014](docs/adr/0014-tier-3-image-protocols.md)). kii sends the picture itself as one
OSC 1337 sequence, and the terminal draws it: true colour, full resolution and real
transparency, in iTerm2, WezTerm and other terminals that read the protocol. The four cell
lanes are byte-identical to 2.3.0 (6,608 of 6,608 corpus cases).

### Added

- **`--mode iterm`** writes `ESC ] 1337 ; File=inline=1;size=N;width=C;height=R;preserveAspectRatio=1 :`,
  the payload's base64, BEL and a newline.
  - **The payload is a PNG kii writes from the decoded pixels**, never the file it read: IHDR
    (8-bit RGBA), one IDAT and IEND, with adaptive filters and sankoch's zlib (`src/png.cyr`).
    The user chose this on 2026-10-29. So the terminal's decoder sees only a minimal PNG of
    what chitra decoded, with no metadata, colour profile, trailing data or second GIF frame.
  - **The box is the cell lanes'**: their columns and rows, with the aspect ratio kept, so
    the terminal draws the largest undistorted image that fits.
  - **Chosen by flag only.** kii does not detect the terminal, and does not fall back. A
    terminal without the protocol draws nothing; the Linux console swallows the sequence
    (`vt.c`), and tmux drops it.
  - **`--color`, `--dither` and `--invert` are refused** with it whenever given, at their
    defaults too (exit 2): `kii: --color does not apply to --mode iterm (the terminal draws
    the image)`.
  - `--verbose` reports `→ iTerm2 inline image (N-byte PNG)`.
- **Example 06**: the Arch logo as an iTerm2 image, and how to check its PNG without such a
  terminal.

### Changed

- An unknown `--mode` reads `kii: --mode must be halfblock, ascii, blocks, braille or iterm`.

### Measured (472-image corpus)

- **Structure.** All 942 iTerm2 cases match the half-block lane's exit code and stderr: 911
  frames and 31 refusals. Every frame is exactly the head, strict base64, BEL and LF, with
  the half-block frame's box.
- **ImageMagick reads all 456 PNGs** as clean 8-bit RGBA.
- **Pixels.**
  - Every PNG draws byte-identical frames to its original in kii's own lanes.
  - For the 425 images ImageMagick decodes as chitra does, its pixels of kii's PNG are its
    pixels of the original.
- **Size against the file as read**: BMP 0.08×, GIF 0.63×, PNG 1.01×, JPEG 5.29×.
- **CPU**, most of it the PNG encode (zlib 520 ms and filters 117 ms on RAMGON):
  - RAMGON: 881 ms, against 201 ms in the half-block lane;
  - a 4.5-megapixel JPEG: 3.1 s;
  - the archlinux logo: 13 ms.
- **Not seen on a live terminal**: none that reads the protocol is installed here. The
  sequence follows iTerm2's documentation and matches chafa's `-f iterm` keys.

### Tests

- **1,151 assertions**, up from 1,101.
  - A new suite, `tests/iterm.tcyr` (41): RFC 4648 base64; the PNG's chunks and CRCs; its
    filter choice against a reference on rows that take all five filters; ties; the round
    trip through chitra; the OSC head; the refusals.
  - cli 232 → 244: `--mode iterm`, each refusal, `cmdit_seen`.
- **An 18th fuzz surface** (20,000 iterations, 8,671,000 in all).
  - Each random image's PNG is checked chunk by chunk, CRC by CRC.
  - chitra must read it back to the same pixels.
  - Its base64, written in random pieces, is checked against a reference decoder.
- Of 18 planted defects, the unit suite catches 17 and the fuzz surface 12 (between them all
  18).
- `scripts/check-builds-agree.sh` gains an iTerm2 lane and three CLI cases: 221 → 233.

### Documentation

- **ADR 0014**, Tier 3: how a protocol is chosen, what it promises where it is missing, how
  each sizes to the cell box, and the iTerm2 sequence and its PNG.
- ADR 0002 is amended: the first non-SGR escape, and why the restricted-emit posture holds.
  ADR 0003 records that tier 3 has opened, and ADR 0007 gains a protocol among the modes.
- The roadmap's 2.4.0 section is removed. 2.5.0 (Kitty) now weighs raw RGBA against the PNG
  writer. New candidates: iTerm2 inside tmux, and protocols at the box's pixel size.

## [2.3.0] - 2026-10-29

**A fourth lane: Braille, `--mode braille`**
([ADR 0013](docs/adr/0013-braille-lane.md)). Each cell is one of the 256 Braille Patterns:
2 × 4 dots, each inked or not, in one colour on the terminal's own background. It is opt-in;
the half-block, ASCII and blocks lanes are byte-identical to 2.2.0 (5,192 of 5,192 corpus
cases).

### Added

- **`--mode braille`** draws the finest shapes of any lane, for logos, line art and one-colour
  images.
  - **Sampling**: the area sampler on the dot grid (`cols·2 × rows·4`), at 16 × 8 taps a dot,
    the blocks lane's density.
  - **Ink, under `--dither none`**: one level for the whole frame, Otsu's (the split of the
    dots' ink histogram with the largest between-class variance, computed exactly). The user
    chose it on 2026-10-29 from renders of four rules. A fixed 128 erased the Arch logo,
    whose blue has a luma of 125, and lost 3 px lines. The cell's own mean hollowed filled
    areas. Error diffusion broke lines into dots.
  - **Under `--dither ordered` or `fs`** the dots are dithered for tone: a Bayer threshold per
    dot, or Floyd-Steinberg against 128. This applies at `tc` and `--color none` too.
  - **Colour**: a cell's colour is the mean of its inked dots, quantized at the tier (as one
    field under `fs`).
  - **`--invert` and `--color none` apply**, as in the ASCII lane. An inverted frame draws
    exactly its negative's dots, and a colourless one is the coloured one with its escapes
    removed.
- **Example 05**: the Arch logo in Braille (`docs/examples/05-braille-logo/`).

### Changed

- The refusal lines name the new lane: `kii: --invert applies to --mode ascii or braille
  only`, and the same for `--color none`.
- An unknown `--mode` reads `kii: --mode must be halfblock, ascii, blocks or braille`.
- `downscale_area_to_rgb` is now `downscale_area_taps` at 4 × 4 taps, with tap counts per
  axis. ASCII bytes and CPU are unchanged.

### Measured (472-image corpus)

- **2,826 Braille cases**: every tier and dither, with and without `--invert`, widths 40 and
  120.
  - All 2,733 frames are exactly `cols` cells a row.
  - The 93 refused cases are refused as in the ASCII lane.
  - Every colourless frame is the coloured one with its escapes removed.
- **`--invert` against ImageMagick negatives**: 422 of 422 images match under each rule, at
  both widths.
- **Blank frames**: 94 frames ink no dot.
  - 93 of them are blank in the ASCII lane too: black content when light is ink, or no pixel
    at alpha ≥ 128.
  - One is a near-white image under `--invert --dither fs`.
- **Size**: 0.92× half-block's bytes at `--width 40`.
- **CPU**: RAMGON at `--width 200` takes 205.7 ms, against 246.5 ms in the blocks lane. The
  archlinux logo there takes 6.57 ms, against 36.16 ms.

### Tests

- **1,101 assertions**, up from 1,035.
  - A new suite, `tests/braille.tcyr` (60): the dot order and UTF-8, the exact mul-div at
    the lane's widest products, Otsu on hand-checked histograms, each ink rule against a
    reference, cell colours, rows at each tier, `--invert`, `--color none`, the refusals.
  - cli 226 → 232: `--mode braille`, and the wider refusals.
- **A 17th fuzz surface** (30,000 iterations, 8,651,000 in all).
  - Random images and their negatives are sampled at 16 × 8. The samples are checked
    against the area reference.
  - The inked dots are checked against reimplementations of each rule, and against the
    negative's.
  - Every row is checked for structure, and against its escape-stripped twin.
- Of 25 defects planted in the lane, the unit suite catches all 25 and the fuzz surface 15.
- `scripts/check-builds-agree.sh` gains five Braille lanes and one CLI case: 175 → 221 cases.

### Documentation

- **ADR 0013**, the Braille lane.
- ADRs 0002, 0004, 0005, 0007 and 0011 are amended: the emit surface, the opt-in lane, the
  per-axis taps, the fourth `--mode`, and `--dither` on the dots.
- The roadmap's 2.3.0 section is removed; 2.4.0 (iTerm2 images) is next. A fixed-level
  override for the lane is a new candidate.

## [2.2.0] - 2026-10-29

**The ASCII lane on light backgrounds, and without colour**
([ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md) and
[ADR 0010](docs/adr/0010-tier-2-colour-and-emit-encoding.md), § v2.2.0). Two opt-in
settings for `--mode ascii`. Without them every frame in every lane is byte-identical to
2.1.0: 5,192 of 5,192 corpus cases (472 images, 11 flag sets over the three lanes), with the
same stderr and exit codes.

### Added

- **`--invert` / `-i`: dark is ink.** The ASCII lane has read light as ink, so on a light
  terminal its art came out as a negative. With `--invert`, an opaque pixel's ink is its
  negative's luminance, and partial alpha (128–254) composites over white rather than black.
  A transparent pixel still has no ink, and each glyph keeps its cell's colour. An inverted
  frame therefore draws exactly the glyphs of the image's negative (each channel `255 − c`,
  alpha kept).
  - Over the corpus's 422 PNG, GIF and BMP images, at `--width 40` and `120`, every inverted
    frame draws its ImageMagick negative's glyphs exactly (843 frames, plus one both refuse as
    too large). ImageMagick's decode was first checked against chitra's for each image.
  - Glyph colours are unchanged in the 91 images without partial alpha. Of all 2,686,892
    cells drawn in both frames, 206,559 (7.7 %) change colour, every one in the 331 images
    with partial alpha, from the white composite.
- **`--color none`: glyphs only.** A row is its glyphs and a newline. There are no colour
  escapes and no closing reset, so the output is plain text, the `jp2a` kind, for files,
  logs and mail.
  - Because a glyph never depends on its colour, a colourless frame is the coloured frame
    with its escapes removed. That holds in all 2,826 corpus cases tried (six flag sets: every
    tier and dither, with and without `--invert`, both widths).
  - `--dither` changes nothing at `none`, as at `tc`.
  - The name is chafa's (`--colors none`). kii does not read `NO_COLOR`, as it does not read
    `COLORTERM`; `--color none` is the explicit form.
  - jp2a's default output is `--mode ascii --color none --invert`.
- **Both are refused in the half-block and blocks lanes** (exit 2, with the help):
  `kii: --invert applies to --mode ascii only` and
  `kii: --color none applies to --mode ascii only`. Those lanes draw colours, not ink, and
  refusing keeps both names free for a later meaning there.
- `--verbose` reports `→ no color`, and `, inverted` under `--invert`. An unknown `--color`
  now reads `kii: --color must be 8, 16, 256, tc or none`. `--help` shows both settings.
- **Example 04**: the Arch logo as plain text (`docs/examples/04-ascii-plain-text/`).

### Performance

- **Without the new flags, CPU is unchanged** within run-to-run noise. Interleaved, fastest
  run: RAMGON `--mode ascii --width 200` 221.42 → 221.35 ms; a 256-pixel icon there
  5.03 → 5.04 ms; RAMGON in the half-block lane at `--width 120` 205.21 → 205.32 ms.
  - A first draft folded the inverted and plain point-plane loops into one. It cost the icon
    2.6 %, so the inverted loop is separate.
- `--invert` costs 0.7–1.1 % on RAMGON, which has more cells with ink to match under it.
- `--color none` is faster: the archlinux logo 5.90 → 5.39 ms.

### Tests

- **1,035 assertions**, up from 984.
  - cli 206 → 226: `--color none`, `--invert` / `-i` / `--invert=1`, and every lane pairing
    of the refusal.
  - quant 171 → 172.
  - render 243 → 263: the inverted area and point planes, white compositing, and composers
    that refuse every code at `none`.
  - ascii 67 → 77: inverted rows, and colourless rows with and without codes.
- **A 16th fuzz surface** (50,000 iterations, 8,621,000 in all). A random image and its
  negative are sampled through both plane builders: the inverted plane must equal the
  negative's byte for byte. Each colourless row must equal the coloured row, at a random tier
  and dither, with its escapes removed, and be exactly `cols` glyphs and a LF. It draws from
  `_fuzz_rand`'s high bits.
- Of 16 defects planted in the new code, the unit suite catches all 16. The fuzz surface
  catches the 11 that change a frame; the other five are in the CLI and the escape
  composers.
- `scripts/check-builds-agree.sh` gains three ASCII lanes (`--invert`, `--color none`, both
  with `--dither fs --verbose`) and four CLI cases: 144 → 175 cases.

### Documentation

- ADR 0007 amended: `--invert` and `--color none`, why both are refused in the other lanes,
  and its old rejection of `--color none` revisited. ADR 0010 amended: the `none` tier, `NO_COLOR`,
  and white compositing under `--invert`. ADR 0002: the emit surface does not grow.
- The roadmap's 2.2.0 section is removed; 2.3.0 (Braille) is next.

## [2.1.0] - 2026-10-29

**The half-block lane reuses its colour state**
([ADR 0004](docs/adr/0004-half-block-floor-glyph.md) § v2.1.0). Every cell shows the same
two colours in the same places as before, in about half the bytes.

### Changed

- ⚠ **The default output's bytes change.** `kii image.png` frames are re-encoded; on a
  terminal with 16 background colours they look the same. Until now every opaque cell was
  `▀` with the top colour in the foreground. Now each cell takes the encoding that needs
  fewest escapes, given the colours the row has already set:
  - two colours: `▀`, or `▄` with the colours swapped (a tie keeps `▀`);
  - one colour: a space on that background, or `█` when the foreground already has it;
  - a transparent half: as before (`▀` or `▄` on the default background, a space when both
    halves are transparent).
- **At 16 colours a bright colour (8–15) stays in the foreground** wherever the cell allows:
  a one-colour bright cell is `█`, and a cell with one bright half puts it in the
  foreground. The Linux console draws SGR 100–107 as 40–47 (no bright backgrounds), so this
  shows far more of a frame in its intended colours there than 2.0.1 did (below). The rule
  was chosen on 2026-10-29 over the blocks lane's plain rule, which saves more bytes but
  would have made the console worse.
- Measured over the 472-image corpus, every tier and dither, `--width 40` and `120`:
  - every one of 10,932 frames shows exactly 2.0.1's colour in every cell (each frame
    decoded as a terminal reads it), and the 372 refused cases give the same errors;
  - bytes: tier 8 −50.8 %, tier 16 −50.1 %, tier 256 −40.4 %, truecolour −36.8 %; one
    frame grew, by 2 bytes;
  - on a model of the Linux console's SGR handling, the share of cell halves shown in the
    wrong colour at tier 16 falls from 27.6 % to 0.60 % (no dither), 40.6 % to 1.27 %
    (`ordered`) and 36.1 % to 3.63 % (`fs`);
  - CPU is unchanged within run-to-run noise.
- The ASCII and blocks lanes are byte-identical to 2.0.1.

### Fixed (documentation)

- **ADR 0010 said the Linux console understands SGR 90–107.** It accepts them, but draws
  100–107 as dim backgrounds, and draws 90–97 by setting bold, which a later 30–37 does not
  clear, so dim foregrounds after a bright one in a row show bright. ADR 0010 is amended,
  and the stuck bold is a roadmap candidate.

### Tests

- `tests/render.tcyr` 223 → 243: the rule for one and two colours, ties, each tier-16
  bright case, truecolour codes 8–15 (RGB there, not brights), and a transparent half that
  must stay in the background. Four expectations from v1.8.0 now show the new encoding, and
  the JPEG / BMP / GIF end-to-end rows count 16 cells rather than look for a `▀`.
- **A 15th fuzz surface** (200,000 rows): random two-row strips at every tier, with
  transparent pixels, read back as a terminal would. Every cell must show its input colours,
  no escape may repeat the colour already set, and every glyph must be the rule's. Of 14
  defects planted in the rule, the unit suite and the surface each catch 13; the 14th is
  equivalent.
- **Found: `_fuzz_rand`'s low bits repeat.** It returns the whole LCG state, so bit 0
  alternates and bits 0–1 repeat every four draws. The new surface first drew `% 4` that
  way and missed a planted defect; it now draws from bits 16 and up, and catches it. The
  older surfaces still use the low bits (the blocks and area surfaces' pixel bytes repeat
  every 256). Changing that would change their random streams, so it is a roadmap
  candidate.

## [2.0.1] - 2026-10-28

**Release engineering.** No frame changes: every output is byte-identical to 2.0.0's, apart
from `--version`.

### Added

- **CI builds and tests aarch64.** A second job cross-builds with `--aarch64`, checks the
  binary's `--version` under qemu-user, runs every suite with `cyrius test --aarch64`, and
  checks that the aarch64 binary answers each case exactly as the x86_64 one does. Until now
  all three were steps of each cut, run by hand.
- **Three release binaries**, with `SHA256SUMS`: `kii-X.Y.Z-x86_64-linux`,
  `kii-X.Y.Z-aarch64-linux` and `kii-X.Y.Z-x86_64-agnos`.
- **Release notes from the CHANGELOG.** `scripts/release-notes.sh X.Y.Z` prints that version's
  section, with its repository links pointed into the tagged tree (a release page resolves a
  relative link against itself). The release publishes it in place of GitHub's generated list
  of commits. CI fails if `VERSION` has no CHANGELOG section, so the CHANGELOG header joins the
  version-sync check.
- **The benches compile in CI** (not run: timings depend on the runner).
- **`scripts/check-builds-agree.sh A B [RUNNER…]`**: two kii binaries must give the same
  stdout, stderr and exit code on 144 cases (the nine fixtures in all three lanes, every
  tier and dither, plus help, version and each kind of refusal). CI runs it for the DCE build
  and for aarch64 under qemu.
- **`scripts/build-strict.sh`**: `cyrius build` that fails on a compiler warning. cyrius
  exits 0 on one, and a call to an undefined function is only a warning when DCE proves the
  call unreachable. agnodrm 1.5.2 shipped a broken `--agnos` binary that way. Every build in
  CI and the release goes through it. kii builds with no warnings on every target, with and
  without DCE.

### Changed

- ⚠ **The release assets are renamed.** Through 2.0.0 a release carried one file, `kii`
  (x86_64 Linux). A script that downloads `…/releases/download/<tag>/kii` needs the new names
  above.
- **The x86_64 Linux and agnos release binaries are built with `CYRIUS_DCE=1`**, dead code
  eliminated: 1,048,976 → 463,248 bytes and 1,063,248 → 465,232. Each was measured against its
  plain build over the 472-image corpus: 2,832 half-block and ASCII cases (stdout, stderr and
  exit code) and 2,832 blocks frames, all byte-identical, plus 33 CLI cases. The agnos pair
  was run under mirshi 1.11.3, and its half-block and ASCII output also matches the Linux
  build's. aarch64 ships plain: cyrius cannot compact an aarch64 ELF yet, so DCE would only
  NOP-fill the dead code, and the binary would stay 1,245,288 bytes.
- **The toolchain pin is validated before the installer runs.** A lost or reformatted
  `cyrius = "…"` line made the grep print nothing, and the installer reads an empty version
  as "the latest release", so CI would have passed on a toolchain nobody pinned.
- `ci.yml`'s header no longer lists v0.2.0's pending work (this release is that work), and
  the comment naming the repository `cyrius-kii` is gone. The manifest description names the
  blocks lane.

### Found

- **On agnos a directory argument reads as `cannot open file`**, where Linux says `is a
  directory, not an image file` (both exit 1). kii recognizes a directory by the read's
  `EISDIR`, and under mirshi the agnos read error does not carry it. Both agnos builds agree,
  so DCE is not the cause. Not fixed here: a frame or diagnostic change does not belong in a
  release-engineering cut.

### Verified

- 964 assertions on x86_64 and aarch64; 8,371,000 fuzz iterations, clean.
- Every corpus frame, in all three lanes, is byte-identical to 2.0.0's.
- `check-builds-agree.sh`: 144 of 144 for the DCE build and for aarch64 under qemu; for agnos
  under mirshi, 143 of 144 for each build (the directory above).
- Both workflows parse, and every `run:` step was executed locally in a copy of the files a
  checkout holds, with the release's tag set, except the toolchain and qemu installs and the
  upload. The shell was `bash -eo pipefail`, stricter than the `bash -e` GitHub uses for a
  step that names none. It caught `--version | head -1` failing under qemu: `head` closes the
  pipe after one line, and the slower binary's second line then dies of SIGPIPE. The checks
  read the first line with `sed -n 1p`, which reads all of its input.

## [2.0.0] - 2026-10-28

**A third render lane: `--mode blocks`, the full Block Elements vocabulary**
([ADR 0012](docs/adr/0012-block-elements-lane.md)). Each cell is sampled 8 × 8 and drawn
with the Block Element that fits it best, in two colours. That covers the eighths from the
bottom and the left, the upper and right eighths, the halves, the quadrants and their
complements, the diagonals and `█`, with `░ ▒ ▓` as colour mixes. Edges and outlines
follow the image at an eighth of a cell. Per-pixel error is lower than half-block's on
every test image (RAMGON 38.9 → 32.1, white text 39.6 → 23.6), and at 16 colours the
frames are smaller (RAMGON at 80 columns: 14,553 → 8,080 bytes).

**The lane is opt-in, and the default does not change.** `kii image.png` is still the
half-block lane. CP437-era console fonts lack the quadrants and eighths, so a blocks frame
needs a modern font. That was the user's call for this release; ADR 0004 is amended, not
superseded. Over 472 images × 6 flag sets, every half-block and ASCII frame is
byte-identical to v1.11.0 (2,832 of 2,832).

The major version marks the new lane and the reworked roadmap: 2.0.1 through 2.6.0 are
pinned. ⚠ Two visible changes beyond the new lane:
- `--help` lists `<halfblock|ascii|blocks>` and one more example.
- An unknown `--mode` now reads `kii: --mode must be halfblock, ascii or blocks`.

**964 assertions** pass on x86_64 and under `cyrius test --aarch64` (cli 203 → 206, and the
new `tests/blocks.tcyr`, 84). aarch64 frames match x86_64 in 406 of 406 runs, 290 of them in
the blocks lane. **8,371,000 fuzz iterations**
are all clean, including two new blocks surfaces. Every target and suite builds with zero
warnings.

### Added
- **`--mode blocks`** (`src/blocks.cyr`):
  - **Sampling.** Each cell's 64 samples are read straight from the decoded pixels through
    the area sampler's taps: the mean of each span, read whole up to 4 pixels a side, by 4
    taps beyond. A sample is transparent when more than half its pixels are.
  - **Shape.** 19 splits: the lower and left half, four quadrants, `▚`, and the lower and
    left 1, 2, 3, 5, 6 and 7 eighths. The split whose two region means leave the least squared
    error wins. That is computed from row, column and quadrant sums and compared exactly, in
    cross-multiplied integers. Ties go to the earlier split; a cell no split improves stays
    one colour.
  - **Colour.** The ink colours and the other colours form two fields, quantized through
    `quantize_rgb_buf`, so `--color` and `--dither` apply as in the other lanes.
  - **Glyph.** Twenty glyphs are complements in pairs (`▀▄ ▌▐ ▇▔ ▉▕ ▘▟ ▝▙ ▖▜ ▗▛ ▚▞`, the space
    and `█`). Each cell is drawn with whichever of a glyph and its complement needs fewer
    colour escapes after the cell before. A cell whose two colours quantize to one is a
    space or `█`, whichever needs no escape.
  - **Shades.** Under `--dither ordered` or `fs`, at 8 or 16 colours only, a cell drawn flat
    becomes `░`, `▒` or `▓` when a 1/4, 1/2 or 3/4 mix of two of the four palette colours
    nearest its mean is strictly nearer than the flat colour. `--dither none` never draws a
    shade, so ADR 0011's promise holds.
  - **Transparency.** A cell with no opaque sample is a space on the default background. A
    cell with both is the glyph whose ink best covers the opaque samples, over the default
    background.
- **`_area_taps_from`** (`src/downscale.cyr`): the tap table for a range of positions, so
  the blocks lane builds its row taps one cell row at a time. `_area_taps` is now its
  whole-range call, with the same output.
- **`tests/blocks.tcyr`**, 84 assertions:
  - the glyph table and complements;
  - the shape choice on crafted cells, and against a brute-force reference on 400;
  - transparency, the half-coverage rule, whole rows at each tier (the complement and
    flat-cell choices), shades and their search, and the guards.
- **Two fuzz surfaces**, the 13th and 14th, run after the others:
  - the shape choice against brute force on 200,000 random cells;
  - 20,000 random frames at every tier and dither, rendered from copies of the image between
    pads of 0 and of 255. The bytes must match, and every row must be exactly `cols` cells
    of space or Block Elements, with shades only when they are on.
- **Two bench rows**: a blocks frame of RAMGON at 80 × 32 cells (13.9–14.0 ms) and 200 × 80
  (52.8–53.2 ms), decode excluded. The existing rows match v1.11.0's within
  run-to-run noise.
- `tests/cli.tcyr`: `--mode blocks` parses to `KII_MODE_BLOCKS`, and `block` (singular)
  is refused.

### Changed
- `--mode` takes `halfblock|ascii|blocks`; `KII_MODE_BLOCKS = 2`. `--help` and the
  `--mode` error line say so.
- **The roadmap is reworked for 2.x.** Pinned:
  - 2.0.1 release engineering;
  - 2.1.0 the half-block lane reuses its colour state;
  - 2.2.0 the ASCII lane on light backgrounds and without colour;
  - 2.3.0 a Braille lane;
  - 2.4.0–2.6.0 iTerm2, Kitty and Sixel.

  Gated on upstream: progressive and SOF1 JPEG (chitra), the terminal's cell aspect
  (darshana), and file-read memory (cyrius). Seven candidates are listed with what each
  needs before a pin. Two rules are stated for every 2.x release: no surprise change to the
  default output, and no environment sniffing.
- **The cost of the blocks lane**, CPU per run (half-block → blocks): a 256² icon at
  `--width 80` 1.92 → 9.26 ms and at 200 3.05 → 38.22 ms; RAMGON 205.8 → 220.1 ms at 80 and
  208.3 → 261.8 ms at 200. The largest frame the cell cap allows (1.05 M cells from a 16 MP
  PNG) takes 3.84 s of wall time against 0.65 s, with peak RSS 132.7 against 126.7 MB.
- `build/kii` 1,020,648 → 1,048,976 bytes (unstripped, DCE off). `--agnos` 1,039,024 →
  1,063,248, `--aarch64` 1,241,600 → 1,245,288.

### Known limits
- **Fonts.** The lane needs the quadrants (U+2596..U+259F) and the eighths; a CP437-era
  console font shows replacement glyphs.
- **Thin colour averages away.** A coloured stroke much thinner than a sample becomes a dim
  mix, which at 8 and 16 colours often quantizes to grey: red and yellow text in a terminal
  screenshot at 100 columns reads as grey strokes, where half-block shows coloured dots. The
  strokes are in the right places and the per-pixel error is lower, but the colour is lost.
- **Truecolour frames can be larger than half-block's**, when detail gives most cells two
  distinct colours (the screenshot at 80 columns: 12,939 → 30,761 bytes).

### Docs
- New [ADR 0012](docs/adr/0012-block-elements-lane.md). ADR 0004, 0007, 0011 and 0002 gain
  v2.0.0 amendments.
- Refreshed: the roadmap (above), `docs/benchmarks.md` § v2.0.0, `state.md`, the README
  (status, arc, flags, prior art, counts), CONTRIBUTING, SECURITY.md, the getting-started
  guide (`--help`, a `--mode` section, two error rows), the architecture map, the ADR index
  and `docs/doc-health.md`.

## [1.11.0] - 2026-10-28

**The ASCII lane samples areas.** Each of a cell's six region values is now the mean over the
source pixels that region covers, not one pixel at its centre
([ADR 0005](docs/adr/0005-nearest-neighbor-downscale.md) and
[ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md) § v1.11.0 amendments). Thin lines and
edges stop dropping out: in a test of 2 px lines at `--width 48`, cells with ink drawn as a space
fall from 127 of 291 to 18, and the horizontal and vertical lines, which drew nothing, now draw.
The half-block lane still reads one pixel per cell.

⚠ **ASCII frames that are reduced change; nothing else does.** Over 472 images (every JPEG, GIF
and BMP under `/usr/share`, every seventh PNG there, and the 7 fixtures) × 6 flag sets:
- **Half-block:** 1,888 of 1,888 frames are byte-identical to v1.10.0.
- **ASCII:** 328 of the 912 frames that render change, under the corpus's two ASCII flag sets.
  At `--mode ascii --width 30`, 1.6 % of glyph cells change, in 158 frames. Every frame
  enlarged on both axes is byte-identical (276 at that width).

**877 assertions** pass on x86_64 and under `cyrius test --aarch64` (render 194 → 223).
aarch64 frames match x86_64 in 348 of 348 runs. **8,151,000 fuzz iterations** are all clean,
including a new area-sampler surface. Every target and suite builds with zero warnings.

### Added
- **`downscale_area_to_rgb`** (`src/downscale.cyr`), used only by the ASCII lane. Per axis, a
  sample's span is the source pixels whose centres fall in it.
  - **A span of at most 4 pixels (`KII_AREA_TAPS`) is read whole,** so up to about a 4×
    reduction the mean is exact.
  - **A longer span takes 4 evenly spaced taps,** so no sample reads more than 16 pixels and the
    cost does not grow with the source. Averaging every pixel was tried first and cost +12 % to
    +25 % on 6–16 MP images; the taps cost about 1 % there and pick the same glyph as full
    averaging in 97.5 % of cells.
  - **No reduction on either axis** gives nearest-neighbour's bytes exactly, so the sampler
    hands the frame to `downscale_to_rgb`. The general loop had cost +11 % on a 256² icon at
    `--width 200`.
  - **Transparency.** A sample is transparent only when none of its pixels is opaque. Its colour
    is the mean of its opaque pixels. Its luminance counts transparent pixels as 0, so a stroke
    on a transparent background reads at its real coverage.
  - **Exact integers:** colour means round half up, and luminance floors as `_ascii_luma` does.
- **An area-sampler fuzz surface**, the twelfth, run after the others so their random stream is
  unchanged. Each of its 100,000 iterations downscales a random image (up to 48 × 48, three alpha
  mixes) to a random 1–96 × 1–64.
  - The image sits between pads of 0 and then of 255, and both copies must give the same
    samples, mask and plane.
  - Every sample must match the definition, computed separately: each source pixel's centre is
    tested against the span.
- **Four bench rows** in `tests/kii.bcyr`: point against area sampling of a decoded RAMGON at the
  ASCII lane's 80- and 200-column grids.

### Changed
- **The luminance plane moves to the sampler.** `downscale_area_to_rgb` leaves it at pstruct +40
  (luminance over the whole span), and `emit_ascii_shape` builds one only when the slot is 0.
  `downscale_to_rgb` now clears the slot, so a plane from an earlier call is never reused.
- **The cost.** CPU per run, interleaved with v1.10.0, minimum of three to five rounds:

  | Render | v1.10.0 | v1.11.0 |
  |---|---:|---:|
  | 256² icon, `--mode ascii --width 200` | 5.93 ms | 5.96 ms |
  | 256² icon, `--mode ascii --width 80` | 2.46 ms | 2.88 ms (+17 %) |
  | RAMGON, `--mode ascii --width 80` | 201.4 ms | 202.9 ms (+0.7 %) |
  | RAMGON, `--mode ascii --width 200` | 209.8 ms | 216.3 ms (+3.1 %) |
  | 6 MP BMP, `--mode ascii --width 80` | 101.5 ms | 102.7 ms (+1.2 %) |
  | 16 MP PNG, `--mode ascii --width 48` | 451.8 ms | 452.2 ms |
  | 6 MP BMP, `--mode ascii --width 400` | 132.2 ms | 162.0 ms (+23 %) |

  The cost is about 6–7 ns per source pixel read. It is largest when the frame is wide enough
  for every sample to read many pixels; the largest frame the cell cap allows
  (`--width 1448` on a 4000²) takes 566 → 701 ms. `docs/benchmarks.md` § v1.11.0 has the rest.
- `build/kii` 1,016,552 → 1,020,648 bytes (unstripped, DCE off). `--agnos` 1,030,824 →
  1,039,024, `--aarch64` 1,241,592 → 1,241,600.

### Tests
- `tests/render.tcyr` 194 → **223**: a white pixel that point sampling misses and area sampling
  keeps, an exact 10 → 3 and a tapped 10 → 1 (and a pixel between the taps, pinned), the
  identity and 2×–4× enlargements equal to `downscale_to_rgb` with no plane, one axis reduced,
  coverage-weighted luminance and the mask with transparency, partial alpha, a stale plane
  cleared, and the overflow guard.
- **Eleven planted defects in the sampler; nine fail the fuzz surface** (3,100–10,088 of 20,000
  iterations each). The other two are equivalent rewrites, shown by enumeration. One was a
  special case in the span bound for i = 0, which the formula already handles, so it was
  removed.

### Docs
- **Roadmap:** current release v1.11.0. No 1.x release is pinned after it.
- ADR 0005, ADR 0007 and ADR 0002 gain v1.11.0 amendments. `docs/benchmarks.md` § v1.11.0,
  `state.md`, the README (status, arc, test counts), CONTRIBUTING, SECURITY.md, the architecture
  module map and `docs/doc-health.md` are refreshed.

## [1.10.0] - 2026-10-28

**The ASCII lane's refinements.** Its glyph table now comes from a checked-in generator, and
every cell goes through directional and then global contrast enhancement before it is matched,
after Alex Harri's write-up ([ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md) § v1.10.0
amendment). The third item pinned here, a k-d-tree lookup, was built and measured. It is exact
but slower than the scan, so it was not taken.

⚠ **ASCII frames change; half-block frames do not.** Over 472 images (every JPEG, GIF and BMP
under `/usr/share`, every seventh PNG there, and the 7 fixtures) × 6 flag sets:
- **Half-block:** 1,888 of 1,888 frames are byte-identical to v1.9.1.
- **ASCII:** 836 of the 912 frames that render change, under the corpus's two ASCII flag sets.
  At `--mode ascii --width 30`, 8.7 % of glyph cells change: 5.6 % from the new table and 5.7 %
  from contrast, which overlap.

**848 assertions** pass on x86_64 and under `cyrius test --aarch64` (ascii 37 → 67).
aarch64 frames match x86_64 in 240 of 240 runs, 200 of them in the ASCII lane. **8,051,000 fuzz
iterations** are all clean, including a new ASCII surface. Every target and suite builds with
zero warnings.

### Added
- **`scripts/gen-shape-table.sh`** generates `src/ascii_shape.cyr`, the 27-glyph coverage table
  that was inline in `src/ascii.cyr`; `--check` exits 1 if the committed file differs.
  - Liberation Mono Regular at 40 px, in a 24 × 48 cell with the baseline at y = 35. Each
    12 × 16 px region's ink is summed and scaled so each row's most-inked glyph reads 255, in
    integer arithmetic.
  - It needs ImageMagick 7 and the font, so CI does not run it. `tests/ascii.tcyr` pins what the
    matcher relies on instead: the glyph order, a space with no ink, each row's 255, values in
    range, mirror pairs within 2 units, and every glyph matching its own vector.
  - ⚠ **The table is new.** The v1.3.1 table's scratch generator was lost, and no setting of
    size, placement, antialiasing or scaling reproduced its values (the closest came within 33
    units per value). The new table differs from it by 18.2 units per value on average.
  - Scaled **per row** rather than Harri's per region: the left and right maxima come from
    asymmetric glyphs, and scaled apart a symmetric `.` read 51 / 76 and the mirrored pairs
    `/` `\`, `(` `)`, `<` `>` stopped being mirrors.
- **Contrast enhancement** (`_ascii_contrast`), on every cell with any light:
  - **Directional.** Each region's ceiling is the largest of its own value and the external
    samples beside it, per Harri's mapping. They are ten sub-samples just outside the cell:
    two above, three on each side, two below. A sample past the frame's edge or a transparent
    one counts as 0.
  - **Global.** The ceiling is the cell's brightest region after the directional step.
  - Both use x → (x / M)^p · M with **p = 1.5**, from the article's range of 1 to 2. It was
    chosen by comparing renders; at 2 photographs turned noisy.
  - Exact integers: a 256-entry power table, a reciprocal for the division by M, and a shift
    for / 255, each checked over its whole domain. So every target picks the same glyphs.
- **The luminance plane** (`_ascii_lum_plane`): one byte per sample, built once per frame and
  kept at pstruct +40, one of the slots v1.7.0 retired. It is at most 6 MiB under the frame cap
  ([ADR 0002](docs/adr/0002-security-model.md) § v1.10.0 amendment).
- **An ASCII-lane fuzz surface**, the eleventh, run after the others so their random stream is
  unchanged.
  - Each of its 40,000 iterations renders a random frame (up to 64 × 60 samples, random RGB,
    a random mask half the time) twice: once with the plane between pads of 0 and once between
    pads of 255. The two must be byte-identical.
  - Every row must also end in the reset and LF, with only table glyphs between escapes.
  - Dropping the top or the bottom edge guard makes 2,851 and 2,837 of 3,000 frames fail.

### Changed
- `emit_ascii_shape_row_buf` takes the luminance plane and the sample height:
  `(rgb, mask, lum, codes, sub_w, sub_h, cy, cols, buf, pos)`. Each cell's six values now come
  from the plane.
- **An all-dark cell is a space at once,** without the contrast pass or the match. That is
  exact: contrast keeps zeros at zero, and the space has no ink and wins every tie.
- **The cost.** Per run, interleaved with v1.9.1:

  | Render | v1.9.1 | v1.10.0 |
  |---|---:|---:|
  | a 256² icon, `--mode ascii --width 200` | 5.26 ms | 5.98 ms (+14 %) |
  | RAMGON, `--mode ascii --width 200` | 203.9 ms | 207.3 ms (+1.7 %) |
  | the kitty screenshot, `--mode ascii --width 200` | 324.3 ms | 324.2 ms |
  | a 256² icon, half-block `--width 200` | 3.12 ms | 3.12 ms |

  A first draft cost +44 % on the icon. `docs/benchmarks.md` § v1.10.0 has the steps that
  brought it down.
- `build/kii` 1,008,328 → 1,016,552 bytes (unstripped, DCE off). `--agnos` 1,022,600 →
  1,030,824, `--aarch64` 1,237,464 → 1,241,592.

### Not taken
- **The k-d tree.** An exact tree over the 27 glyph vectors agreed with the scan on 2,000,000
  random vectors and on 710 near each glyph. It was slower: 444 ns against the scan's 331 ns
  on random vectors, and 233 ns against 203 ns on real cells. An iterative version took 803 and
  449 ns. With 27 points in 6 dimensions it prunes little, and the scan already stops scoring a
  glyph after three terms. A cache of answers, which Harri pairs with the tree, does not help
  photographs either: 15,974 of RAMGON's 16,000 cells at that size are distinct.

### Tests
- `tests/ascii.tcyr` 37 → **67**.
  - The generated table's properties, and every glyph matching its own vector.
  - The power table at six points, monotone and never above t.
  - The step: it equals plain division on all 32,896 (x, m) pairs, and keeps its fixed points.
  - Contrast scenarios from a reference written apart from the code: a bright row above, a
    uniform corner, and a lone cell.
  - **All ten external samples lit one at a time,** each reaching exactly its regions.
  - The plane's luma equals `_ascii_luma` per sample, and a masked sample is 0.
- **Eight planted defects, each caught.** Six fail the unit suite:
  - three in the mapping;
  - an external read one row low;
  - the frame's edge read as bright;
  - a skipped global pass.

  The other two, the top and bottom edge guards, are caught by the fuzz surface. The first round
  let a mapping defect through (v0's ceiling reading the right-hand sample), and the
  one-at-a-time cell was added for it.

### Docs
- **Roadmap:** the 1.10.0 section is deleted. No 1.x release is pinned after it.
- ADR 0007 and ADR 0002 gain v1.10.0 amendments. `docs/benchmarks.md` § v1.10.0, `state.md`,
  the README (status, arc, prior art, and the test counts, which still said 813 at v1.9.1),
  CONTRIBUTING, SECURITY.md, the getting-started diagnostics table, the architecture module
  map and `docs/doc-health.md` are refreshed.

## [1.9.1] - 2026-10-28

**Toolchain `6.7.12` → `6.7.18`, and every dependency to its newest tag:** darshana `1.3.0` →
`1.6.0`, cmdit `1.4.0` → `1.5.0`, chitra `1.2.0` → `1.3.1`. No kii code changed except the
`--version` literal and comments. ⚠ **One thing kii does changes: a PNG past 16 MiB of
scanlines now renders** instead of being refused (chitra 1.3.0). Every other frame is
byte-identical to v1.9.0.

Output was compared against v1.9.0 over 472 images × 6 flag sets (stdout, stderr and exit
status). The images are every JPEG, GIF and BMP under `/usr/share`, every seventh PNG there,
and the 7 fixtures.
- **Toolchain alone**, deps held at the v1.9.0 tags: 2,832 of 2,832 are identical.
- **With the new deps**: 2,820 of 2,832 are identical. The other 12 are the two PNGs past
  16 MiB in the set (`tests/fixtures/oversize.png` and kitty's 3880×2168 `screenshot.png`),
  under each flag set. v1.9.0 refused both; v1.9.1 renders them.

**818 assertions** pass on x86_64 and under `cyrius test --aarch64` (decode 208 → 213).
aarch64 frames match x86_64 in 240 of 240 runs. **8,011,000 fuzz iterations** are all clean,
at 123 MB peak RSS. Every target and suite builds with zero warnings. The bench is unchanged
within ~1 % (`docs/benchmarks.md` § v1.9.1).

### Changed
- **Toolchain `6.7.12` → `6.7.18`.**
  - `lib/` re-vendored from clean (`rm -rf lib && mkdir lib && rm cyrius.lock && cyrius deps`).
    It is still 40 files. 23 stdlib files change, plus the three dep bundles.
  - 6.7.13–6.7.17's migration notes cover struct values, generics, multi-value returns,
    receives and vector values. kii uses none of them. 6.7.18 changes no language rule.
  - **The stdlib's sankoch moves 2.8.7 → 2.8.9.** 2.8.8 is a toolchain bump. 2.8.9 moves batch
    inflate's 32-byte bit reader onto the stack, so a decode no longer keeps 32 B of the arena.
    Inflate logic is unchanged, so the v1.6.4 audit's three CVE-class results still hold.
  - `build/kii` 1,012,280 → 1,008,328 bytes (unstripped, DCE off; 1,004,104 with the deps held).
    `--agnos` 1,026,520 → 1,022,600, `--aarch64` 1,237,312 → 1,237,464.
- **`[deps.chitra]` `1.2.0` → `1.3.1`.** Nothing frozen moved: the 11 chitra names kii calls
  and every `ChitraErrCode` value are as before.
  - ⚠ **A PNG past 16 MiB of inflated scanlines decodes** (1.3.0). From v1.6.0 to v1.9.0 chitra
    refused it from the header, and kii printed `image too large to decode (pixel data
    inflates past the decompressor's 16 MiB ceiling)`. That covered any 8-bit RGB PNG above
    ~5.6 MP and any RGBA one above ~4.2 MP. chitra now inflates to the exact size IHDR implies
    (`zlib_decompress_capped`), up to its unchanged 4096² pixel cap.
  - So `IMG_ERR_INFLATE_LIMIT` (17) is unreachable, as chitra's code 35 behind it is. kii keeps
    the code, its map arm and its text: chitra keeps 35 defined, and the map stays total.
  - **Checked against a decoder v1.9.0 already trusted.** Three large PNGs (`oversize.png`,
    kitty's screenshot, a 3000×2000 plasma) were re-encoded as BMPs, whose path never inflates.
    The screenshot has alpha, so its BMP is 32 bpp with an alpha mask, composited the way kii
    does. v1.9.1's render of each PNG equals v1.9.0's render of its BMP in 24 of 24 cases
    (8 flag sets each, including `--color tc --width 200` in both lanes).
  - 1.3.1 unfilters non-interlaced rows in place and inflates a single IDAT chunk where it
    lies, so a large PNG costs less than under 1.3.0. Below 16 MiB, output is byte-identical
    (the corpus above).
- **`[deps.darshana]` `1.3.0` → `1.6.0`.** Nothing kii calls changed. 1.4.0 adds two SGR
  scanners and 1.6.0 a predicate. 1.5.0 makes `tty_isatty` per-fd, and console echo-off and
  flush work, on agnos 1.57.13 and later. kii calls `tty_winsize`, not `tty_isatty`, and all
  ten darshana functions it calls are body-identical. darshana's AGNOS arm needs cyrius ≥
  6.7.11, which 6.7.18 is.
- **`[deps.cmdit]` `1.4.0` → `1.5.0`.** 1.4.1 is a toolchain bump. 1.5.0 fixes bash and fish
  file completion, which kii does not emit.
  - **A command line over 2 MiB is read whole** (1.4.2), now that the stdlib's `args_init`
    reads to EOF. Through v1.9.0 kii refused one with `kii: could not read the full command
    line`. Measured with 25 arguments of 100,000 bytes under `ulimit -s 65536`: v1.9.0 prints
    that line, v1.9.1 prints `kii: too many arguments (expected one image path)`. A command
    line of exactly 2,097,152 bytes is still refused: it is the one length an older stdlib
    cannot tell from a cut.
- **`cyrius.lock`** regenerated from clean. It has four commit pins: chitra 1.3.1, cmdit 1.5.0,
  darshana 1.6.0, and chitra's transitive sankoch, now 2.8.9 to match the stdlib leaf.

### Security
- ⚠ **What a valid PNG can cost rises, by chitra's design.** ADR 0002 bounded an input at
  ~256 MB and ~5–6 s. Measured at v1.9.1 (peak RSS, wall clock, `--width 80`):

  | Input | File | v1.9.0 | v1.9.1 |
  |---|---:|---|---|
  | 4096² black RGB8 | 49 KB | refused, 13 MB | 117 MB, 0.45 s |
  | 4096² flat RGBA16, Adam7 | 147 KB | refused, 13 MB | 327 MB, 1.7 s |
  | 4096² plasma RGBA16 | 97 MB | refused, 227 MB | 513 MB, 9.7 s |
  | 4096² plasma RGBA16, Adam7 | 99 MB | refused, 227 MB | 643 MB, 10.5 s |
  | 4096² noise RGBA16, Adam7, padded to 255 MB | 255 MB | refused, 517 MB | 913 MB, 7.2 s |

  - The worst is a file at kii's 256 MB read cap that is also at chitra's pixel cap, Adam7,
    16-bit. About 517 MB of it is the read, which v1.9.0 paid too: the stdlib's
    `file_read_whole_max` grows its buffer, and the bump allocator keeps each one it outgrows.
  - A small file buys up to ~327 MB and ~1.7 s (147 KB of valid Adam7 RGBA16).
  - The caps are unchanged: the 256 MB read, and chitra's 4096² pixel, 256 MB raw-byte and
    1100:1 ratio caps. Under `ulimit -v`, from 60 MB to 400 MB, the 97 MB file fails cleanly
    with `out of memory or image too large`, exit 1.
  - [ADR 0002](docs/adr/0002-security-model.md) gains a v1.9.1 amendment with these figures
    and the decision. SECURITY.md's decompression line is rewritten.

### Tests
- `tests/decode.tcyr` 208 → 213. Group (e2) now pins that `oversize.png` decodes: `IMG_OK`,
  2370×2370, source colour type 2, `seen_iend`, and every one of its 5,616,900 pixels opaque
  black. A mutant expecting `0xFE000000` fails it with 5,616,900 mismatches. The
  `DECOMPRESS_MAX_OUTPUT` = 16 MiB pin is gone, because the line that quoted it can no longer
  print.

### Docs
- **Roadmap**: "PNG past 16 MiB inflated" is deleted from § Gated on upstream, since this
  re-pin ships it. Progressive JPEG is the one gated item left.
- `state.md`, the README, the getting-started diagnostics table, SECURITY.md, ADR 0002,
  `docs/benchmarks.md` § v1.9.1 and `docs/doc-health.md` are refreshed.

## [1.9.0] - 2026-10-16

**Dithering, and pixel-centre sampling.** `--dither ordered` (a 4×4 Bayer matrix) and
`--dither fs` (Floyd-Steinberg) turn the flat bands of a gradient into a mix of two
neighbouring colours, at tiers 8, 16 and 256 and in both lanes. The default stays `none`.
The decision is [ADR 0011](docs/adr/0011-dithering.md).

The same release fixes C-7, which the v1.6.4 sweep pinned here: the downscale sampled each
span's start, so frames sat half a span up and to the left of the image, and a downscale
never read the last source row or column. It now samples the span's centre
([ADR 0005](docs/adr/0005-nearest-neighbor-downscale.md) amendment).

⚠ **Every downscaled frame's bytes change, with or without `--dither`:**
- **Corpus:** 2,504 of the 2,504 frames the 466-image corpus renders change (six flag
  sets per image). The 292 that do not are decode rejections.
- **Identity scales and integer upscales** are byte-identical, since both formulas pick the
  same pixel there.
- **Sampling is the only cause.** A build of v1.8.0 with only the new formula gives the same
  bytes as v1.9.0 on all 2,796 frames, so the quantize and ASCII changes around it alter
  nothing at `--dither none`.

**813 assertions** pass on x86_64 and under `cyrius test --aarch64`. aarch64 frames match
x86_64 in every tier × dither × lane combination tested (648 of 648). **8,011,000 fuzz
iterations** are all clean.

### Added
- **`--dither none|ordered|fs`** (`-d`), a cmdit enum, default `none`. It is independent of
  `--mode` and `--color`, and changes nothing at `--color tc`, where nothing is quantized.
  - **ordered** adds a 4×4 Bayer offset, `((2m + 1)·step)/32 − step/2`, to R, G and B alike.
    `step` is the tier's level spacing: 170 at tier 8, 85 at 16, 40 at 256.
    - The offset stays inside ±step/2, so a palette colour never moves.
    - A colour between two levels becomes a mix of the two.
  - **fs** carries each pixel's error 7/16 right, 3/16 down-left, 5/16 down and 1/16
    down-right.
    - The arithmetic is exact integers (errors ×16 in two i64 rows), so every target gives
      the same bytes.
    - Error is measured against the RGB the chosen code stands for at the tier.
    - A transparent pixel neither takes error nor passes it on.
  - **The ASCII lane dithers cell colours.** Ordered applies per cell. Under `fs` every
    cell's mean colour is quantized first, as one field. Glyph choice is unchanged.
  - **The effect, on a 64×256 grey ramp** (mean error of each column's brightness):

    | tier | none | ordered | fs |
    |---|---:|---:|---:|
    | 8 | 34.7 | 27.2 | 16.2 |
    | 16 | 21.2 | 11.8 | 5.0 |
    | 256 | 2.6 | 1.9 | 2.1 |

  - **The cost:** dithered frames are larger, because a pattern breaks the runs that escape
    elision skips. Over the corpus, the factor is 1.4–1.6 at tier 8, 1.8–2.0 at tier 16 and
    3.3–4.2 at tier 256. `fs` adds ~1.8–2.2 ms per render of a 256² icon at `--width 200`.
    `docs/benchmarks.md` § v1.9.0 has the detail.
- **`--dither` errors and help.**
  - Any other value prints `kii: --dither must be none, ordered or fs` and exits 2.
  - `--help` gains `-d, --dither <none|ordered|fs>	dithering (default: none)` and a
    `--dither fs` example.
- **`--verbose` names an active dither mode:** `→ 16-color, fs dither`. At `none`, and at
  truecolour, the line is unchanged.

### Changed
- ⚠ **Pixel-centre sampling (C-7).** `sx = ((2·dx + 1)·W) / (2·dst_w)`, and the same for
  `sy`; it was `dx·W / dst_w`.
  - At 10:1 the frame moves five source pixels toward the image's real centre, and a 1-px
    border now shows on all four sides.
  - The formula stays in bounds: `sx ≤ W − W/(2·dst_w) < W`.
  - Example 01's first bytes and size changed (14,609 → 14,553 bytes), and example 02's size
    (6,085 → 6,150); both `expected.txt` files say so.
- **The quantize API takes the frame's shape.** It is now `quantize_rgb_buf(rgb, mask, w,
  h, out)`, because ordered needs each pixel's position and Floyd-Steinberg its
  neighbours. With `--dither none` it runs the v1.8.0 loop exactly.
  - `kii_color_code_at(r, g, b, x, y)` is the one-pixel form, with the ordered offset.
  - `emit_ascii_shape_row_buf` takes an optional cell-code buffer.
  - `_ascii_cell_codes` builds that buffer, and runs only under `fs`.
- **No speed change at `--dither none`.** An early draft ran the ASCII field pass for every
  mode and made the default ASCII lane ~19 % slower on a small icon (7.1 → 8.5 ms). The
  pass now runs only under `fs`, and both lanes match v1.8.0 within noise.
- **Sizes.**
  - `build/kii`: 1,003,824 → 1,012,280 bytes.
  - `--agnos`: 1,018,072 → 1,026,520.
  - `--aarch64`: 1,237,064 → 1,237,312.
- **The manifest's `description`** said kii renders "16-color" frames, which has been
  short since v1.8.0's tiers. It now names the tiers.

### Tests
- **813 assertions** (was 738).
  - **cli 184 → 203:** each `--dither` value and its mode, `-d`, the default, refusals
    naming `--dither`, and the BAD_ENUM line.
  - **quant 133 → 171:**
    - the `quant_set_dither` contract;
    - the Bayer constant is a permutation of 0–15, and every offset is inside ±step/2 at
      each tier's step;
    - `_quant_code_channel` inverts each tier's code;
    - black, red, bright black and white stay put under every mode;
    - mid-grey 128 at tier 16: all light grey under `none`, exactly half and half under
      ordered, and under fs both greys with a mean within 4 of 128;
    - fs's carried error on two pixels;
    - masked pixels at tiers 8, 16 and 256 under every mode;
    - truecolour identical under every mode.
  - **ascii 23 → 37:** the cell-code field, given codes winning over the cell's mean, a
    transparent cell, Floyd-Steinberg across cells, and a per-cell ordered row matching the
    field-coded one byte for byte.
  - **render 190 → 194:** the 2×2 → 1×1 shrink now picks src (1,1), and a 10-pixel row
    downscaled to 1, 2, 5 and 10 picks pixel 5; 2 and 7; 1 3 5 7 9; and the identity.
- **Fuzz:** the emit surface rotates the dither mode every four calls, as it does the tier,
  so twelve calls cover every pair. It takes no extra random draw, and the counts match
  v1.8.0's.

### Documentation
- New ADR 0011 (dithering). ADR 0005 gains a v1.9.0 amendment covering the sampling
  change, the byte-stability cost, and dithering arriving without `--filter`. ADR 0002 gains
  one: dithering adds no emit surface, and its allocations are bounded.
- Updated for the new flag:
  - **README:** the flag table, an example, the arc, and the tier roadmap. The dithering line
    under "Not yet supported" is gone, and the assertion count is corrected (it still read
    709).
  - **getting-started:** `--help` matches the binary byte for byte; there is a `--dither`
    section, a pipeline, and its error line.
  - **architecture:** module map v1.9.0, and new item 007, on Floyd-Steinberg being the one
    quantize step that reads its neighbours.
  - **SECURITY.md:** the new allocations and the fuzz rotation.
  - **The examples.**
- **Stale text fixed in passing:**
  - the architecture map's `kii_validate_color`, gone since v1.8.0;
  - example 01's notes still described `38;5;N` emit;
  - example 02's `expected.txt` stopped at v1.6.4.
- The roadmap's 1.9.0 section is deleted. Next is 1.10.0: the ASCII shape-vector
  refinements.

## [1.8.0] - 2026-10-15

**Tier 2 colour, and the emit rework.** `--color 256` and `--color tc` (24-bit truecolour)
join 8 and 16. Three other changes ride the same release because each alters every frame's
bytes, so captured frames change once rather than three times:
- tier 1 moves to the plain 8/16-colour SGR codes a strict terminal understands;
- repeated escapes are elided;
- transparent pixels are drawn in the terminal's own default colours.

The decisions are recorded in
[ADR 0010](docs/adr/0010-tier-2-colour-and-emit-encoding.md), which supersedes ADR 0003's
tier-1-only limit and its `38;5;N` encoding.

⚠ **Every frame's bytes change.** What a terminal shows does not, for opaque images at the
default tiers:
- **Opaque images:** a replay of every escape into (glyph, fg, bg) per cell gives the same
  grid as v1.7.0 for every opaque image tested. That is 996 frames: the test fixtures and
  the opaque system images, both lanes, tiers 8 and 16, two widths.
- **Transparent images:** every half drawn opaque matches too (1,344 frames).
- **Size:** output is ~85 % smaller over those frames (71.99 MB → 10.87 MB).

**738 assertions** pass on x86_64 and under `cyrius test --aarch64`, and aarch64 frames
match x86_64 at every tier on both lanes. **8,011,000 fuzz iterations** are all clean.

### Added
- **`--color 256`.** Uses the xterm 6×6×6 cube and grey ramp, indices 16–255.
  - Indices 0–15 are skipped: each terminal's theme sets their RGB, so they cannot be
    matched.
  - The nearest entry is exact without a scan. For the cube, the nearest level is chosen per
    channel; for the grey ramp, the level nearest the channel mean. The two candidates are
    compared, and ties go to the lower index.
  - `quantize_256` is checked against a full scan of all 240 entries on a 5,832-colour grid
    and every grey.
- **`--color tc`.** 24-bit truecolour: each pixel's own RGB as `38;2;R;G;B` / `48;2;R;G;B`.
- **`--color` is a cmdit enum, `8|16|256|tc`.** 16 is still the default. kii still does not
  read `COLORTERM` or `TERM`, so the same command gives the same bytes everywhere.
- **`--verbose` names the tier:** `→ 256-color` or `→ truecolor`.

### Changed
- ⚠ **Tiers 8 and 16 now send the plain SGR codes.**

  | tier | through v1.7.0 | since v1.8.0 |
  |---|---|---|
  | 8 | `38;5;N` / `48;5;N` | 30–37 / 40–47 |
  | 16 | `38;5;N` / `48;5;N` | 30–37 and 90–97 / 40–47 and 100–107 |

  This resolves the v1.6.4 sweep's C-11: the tier for strict 16-colour terminals and BBS
  clients was sending an escape some of them cannot parse. Tier 8 also refuses a bright
  index rather than send 90–97.
- ⚠ **Repeated escapes are elided** (O-5).
  - A row writes an fg or bg escape only when it changes from the previous cell. The state
    starts unknown on every row, so each row is still self-contained.
  - A cell drawn as a space takes no fg escape.
  - RAMGON at `--width 80` is 14,609 bytes (was 54,353). An 80×24 frame over a 9600-baud
    line takes ~15 s instead of ~57 s.
  - Small images also render faster: a 256² icon at `--width 200` takes 0.25 s of CPU per
    50 renders, down from 0.35–0.42 s (`docs/benchmarks.md` § v1.8.0).
- ⚠ **Transparent pixels are drawn in the terminal's default colours** (SGR 39 / 49). Through
  v1.7.0 they were composited over black.
  - A pixel with alpha below 128 (chafa's default threshold) is transparent. Downscale marks
    it in a mask, kept in the pstruct slot at offset 32, which v1.7.0 had freed.
  - In the half-block lane, the glyph keeps the opaque half's colour:
    - bottom transparent: `▀`;
    - top transparent: `▄`;
    - both: a space.
  - In the ASCII lane, a transparent sample counts as no ink and is left out of the cell's
    colour.
  - Alpha at 128 or above is still composited over black.
- ⚠ **`--color` error and help text.** Any value other than 8, 16, 256 or tc now fails the
  parse:
  - `--color 7` prints `kii: --color must be 8, 16, 256 or tc`; it was `… must be 8 or 16`.
  - `--help` reads `-c, --color <8|16|256|tc>	colour tier (default: 16)` and gains a
    `--color 256` example.
  - `kii_validate_color` is gone. `kii_parse_error_line` takes the flag name, so BAD_ENUM
    names `--color` or `--mode`.
- **The quantize stage now passes colour codes to emit.**
  - Each pixel gets a 32-bit code: a palette index (tiers 8 / 16 / 256), a packed `0xRRGGBB`
    (tc), or `KII_COLOR_DEFAULT` for a transparent pixel.
  - The quantized buffer is 4 bytes a pixel (was 1).
  - `quantize_rgb_buf` takes the transparency mask.
  - `emit_ascii_shape_row_buf` takes the mask too, and the ASCII frame loop reaches it
    through the pstruct.
- **Sizes.**
  - `build/kii`: 999,568 → 1,003,824 bytes.
  - `--agnos`: 1,013,816 → 1,018,072.
  - `--aarch64`: 1,171,360 → 1,237,064. This is 64 KiB of segment-alignment padding again;
    the text crossed the boundary.
  - The worst-case cell grows from 25 to 41 bytes (two 19-byte truecolour escapes and a
    glyph). The frame cap still bounds a frame, at ~43 MB of truecolour output.

### Tests
- **738 assertions** (was 710).
  - **cli 171 → 184:** every `--color` value and its tier, refusals naming `--color`, and
    both BAD_ENUM lines.
  - **quant 115 → 133:** `quantize_256` against a full scan (5,832 grid colours and all 256
    greys), colour codes at each tier, and the mask → `KII_COLOR_DEFAULT`.
  - **render 199 → 190:** the 33 single-byte offset pins of the old `38;5;N` rows are
    replaced by 24 new checks:
    - every tier;
    - tier 8 refusing a bright index;
    - elision: only the changed escape, and self-contained rows;
    - each transparency case (`▄`, `▀`, a space, and truecolour);
    - the transparency mask at the 127 / 128 threshold.
  - **ascii 17 → 23:** exact rows, a fully and a partly transparent cell, and elision at
    three tiers.
- **Fuzz:** the emit surface rotates through all four tiers and now fails if a row is
  refused. Its line buffer grew to fit 200 truecolour cells.

### Documentation
- New ADR 0010. ADR 0003 is marked partly superseded. ADR 0002 gains a v1.8.0 amendment:
  the emit surface is still SGR only, and its set is listed.
- Updated for the new tiers: README (the `--color` flag, a transparency note, the tier
  roadmap), the getting-started guide (its `--help` block matches the binary byte for
  byte), the architecture notes (colour codes, the tier composers, the 41-byte cell
  budget), SECURITY.md (the frame cap at truecolour), and example 01's expected bytes.
- The roadmap's 1.8.0 section is deleted. Next is 1.9.0: dithering and pixel-centre
  sampling.

## [1.7.0] - 2026-10-15

**The format-neutral rename, and the three code-health items the v1.6.4 sweep pinned to
it.** kii's image front-end has been named for PNG since v0.3.0, and four releases ago those
names started covering JPEG, BMP and GIF too. The rename changes no behaviour: with only the
rename applied, the build is **byte-identical** to v1.6.4.

Every rendered frame is byte-identical to v1.6.4:
- **113 of 130** standard cases match: all 96 render cases (6 images × both lanes × 8
  width/flag combinations, including `--verbose`) and every decode diagnostic. The 17
  that differ are usage errors and `--help`, which print the help text (below).
- **932 of 932** runs over 466 system images match.

The only output changes are the `--width` / `--mode` error lines and one `--help` line
(below). **710 assertions** pass on x86_64 and under `cyrius test --aarch64`; the aarch64
frames match x86_64 on both lanes. **8,011,000 fuzz iterations** are all clean.

### Changed
- **`src/png.cyr` is `src/image.cyr`**, and its names are format-neutral, with every numeric
  code unchanged:
  - `kii_decode_png` → `kii_decode_image`
  - `png_color_type_name` → `kii_source_type_name`
  - `PNG_OK` / `PNG_ERR_*` → `IMG_OK` / `IMG_ERR_*`

  Each code is named for what it means:

  | through v1.6.4 | since v1.7.0 |
  |---|---|
  | `PNG_ERR_HEADER` (4) | `IMG_ERR_MALFORMED` |
  | `PNG_ERR_CHUNK` (6) | `IMG_ERR_TRUNCATED` |
  | `PNG_ERR_TRUNCATED` (2, reserved) | `IMG_ERR_SHORT_FILE` (frees the name for 6) |
  | `PNG_ERR_NOT_PNG` (3) | `IMG_ERR_UNRECOGNIZED` |
  | `PNG_ERR_NO_IDAT` (9) | `IMG_ERR_NO_IMAGE_DATA` |
  | `PNG_ERR_INFLATE` (10) | `IMG_ERR_DECOMPRESS` (DEFLATE or LZW) |
  | `PNG_ERR_IDAT_TOO_LARGE` (13) | `IMG_ERR_MEMORY` |
  | every other `PNG_ERR_X` | `IMG_ERR_X` |

  The fuzz and bench names that really are about PNG (`PNG_FUZZ_*`, the PNG surface, the
  `png_decode` benches) keep theirs.
- **Downscale accepts only RGBA8** (R-2). chitra has normalized every format to RGBA8 since
  the v1.2.0 re-fold. So the per-colour-type `_extract_rgb` (greyscale, RGB, palette,
  grey+alpha, 16-bit) and `_png_color_channels` were reachable only from tests, and both are
  removed. `downscale_to_rgb` now reads RGBA8 directly and refuses any other format, or a
  pixel buffer smaller than width × height × 4.
  - The six pstruct slots only the native decoder used are retired: IDAT count, size and
    buffer; interlace; PLTE buffer and size.
  - Their offsets are left unused, so every live slot keeps the offset it has always had.
- **Both render lanes share one frame loop** (R-8). `emit_halfblock` and `emit_ascii_shape`
  each carried the same row loop: allocate a line buffer, build each row, write it, and
  return -1 or -2. They also carried the same row ending (SGR reset + newline). Now:
  - `_kii_emit_frame` (`src/emit.cyr`) runs the loop and takes each lane's row builder by
    address, called with `callptr`.
  - `_kii_row_end` is the shared ending.
- **cmdit checks `--width` and `--mode`** (R-7).
  - `--width` uses `cmdit_range(0, KII_MAX_COLS)`, and `--mode` is a
    `cmdit_enum("halfblock|ascii")` read through `cmdit_get_enum` with `KII_MODE_*`.
  - kii's own `kii_validate_mode`, `kii_mode_is_ascii` and `kii_width_error_line` are gone.
  - ⚠ **Two error lines change**:

    | input | through v1.6.4 | since v1.7.0 |
    |---|---|---|
    | `--width -5` | `kii: --width must not be negative (0 = fit the terminal)` | `kii: --width must be between 0 and 100000 (0 = fit the terminal)` |
    | `--width 100001` | `kii: --width exceeds the maximum of 100000 columns` | the same new line |

    `--mode bogus` keeps `kii: --mode must be halfblock or ascii`. All exit 2, as before.
  - Because cmdit now refuses these during the parse, a bad `--width` or `--mode` is
    reported before a bad `--color`. `kii --color 7 --mode bogus` used to name `--color`;
    it now names `--mode`.
  - `--help`'s `--mode` line reads `-m, --mode <halfblock|ascii>	render mode (default:
    halfblock)`. It was `<str>	render mode: halfblock or ascii (default: halfblock)`.
- Sizes: `build/kii` 999,656 → 999,568 bytes. `--agnos` 1,013,904 → 1,013,816. `--aarch64`
  1,236,984 → 1,171,360: the text shrank back under the 64 KiB segment boundary that v1.6.4
  crossed.

### Tests
- **710 assertions** (was 709):
  - **cli 163 → 171:** `--width` at 0, 1, 100000, 100001, -5 and a huge negative; `--mode`
    bogus, empty, ascii and the default. Each refusal names its flag. The OUT_OF_RANGE and
    BAD_ENUM lines are pinned.
  - **quant 123 → 115:** the `_png_color_channels` group is gone with its function.
  - **render 198 → 199:** the three `_extract_rgb` checks are gone. Four new ones show
    downscale refusing colour type 2, bit depth 16 and a short buffer, then accepting RGBA8
    again.

### Documentation
- The architecture map, state.md, the getting-started guide (its `--help` block matches the
  binary byte for byte), SECURITY.md, the README and two examples use the new names.
- ADRs 0002, 0005, 0006, 0008 and 0009 each gain a v1.7.0 amendment with the name mapping.
  Their bodies keep the names they were written with. 0008's deferral is closed.
- The roadmap's 1.7.0 section is deleted. Next up is 1.8.0: tier 2 colour and the emit
  rework.
- state.md's test-count line still said 642 after v1.6.4. It now says 710.

## [1.6.4] - 2026-10-15

**The P(-1) sweep.** Five audit lenses — correctness, security, refactor,
optimization, docs — plus a verification of the three zlib CVE-class transfers
ran over v1.6.3. Every material finding went to an independent refuter. Full
report: [`docs/audit/2026-10-15-audit.md`](docs/audit/2026-10-15-audit.md).

- **Found:** 56 findings. Repaired with regression tests: 1 MEDIUM, 9 LOW and
  1 INFO. Also fixed: code health and ~30 doc corrections.
- **Changed:** 9 findings deferred, each to a pinned roadmap version; 3
  byte-identical optimizations adopted; 2 hypotheses refuted.
- **CVE classes:** all three hold against the linked sankoch 2.8.7, so nothing
  is filed.
- **Output:** every opaque image renders byte-identically to v1.6.3. That covers
  130 standard cases and 466 system images. What changed:
  - transparent images (below);
  - the new and reworded diagnostics;
  - two `--help` lines.
- **Tests:** **709 assertions** (was 642) pass on x86_64 and under
  `cyrius test --aarch64`. **8,011,000 fuzz iterations** are all clean.

### Security
- **A small image could produce gigabytes of output** (MEDIUM). `--width N`
  derives the row count from the image's aspect, and nothing limited it. A
  392-byte 1×65535 GIF at `--width 80` asked for 2.6 million rows: about 4.4 GB
  of ANSI after minutes at 1.6 GB RSS. New `KII_MAX_CELLS` (1,048,576 character
  cells) is checked after geometry on both lanes. Past it, kii prints
  `<path>: frame too large (over 1048576 cells); use a smaller --width` and exits
  1. Ordinary sizes are unaffected: `--width 1000` of a square image is 500,000
  cells.

### Fixed
- **Pipes, `/dev/stdin`, process substitution and FIFOs now render; a directory
  says so.** kii measured the file with `lseek`, then opened it a second time to
  read it. That broke three things:
  - a pipe printed "cannot open file";
  - an ext4 directory printed "file exceeds size ceiling (max 256 MB)";
  - the path could change between the size check and the read.

  kii now reads with the stdlib's `file_read_whole_max`: one open, read to EOF,
  capped at 256 MB. A directory prints `is a directory, not an image file`
  (new `PNG_ERR_IS_DIR`, 18). `cat image.png | kii /dev/stdin` works.
- ⚠ **Transparent pixels render black instead of their hidden colour.** kii
  dropped alpha, which ADR 0006 had recorded as deliberate. So a GIF whose
  transparent palette entry is magenta drew magenta where the image is empty,
  and a PNG storing `rgba(255,255,255,0)` drew white. Alpha is now composited
  over black as `(c·a + 127) / 255`. At alpha 255 that is exactly `c`, so
  opaque images are byte-identical. Of 466 system images, the 325 whose output
  changed are all transparent. Real transparency (the terminal's default
  background) is pinned to 1.8.0.
- **GIF errors named a PNG chunk.**
  - A corrupt LZW stream printed `DEFLATE decompression failed (corrupt IDAT)`.
    It now prints `corrupt GIF image data (bad LZW stream)`.
  - A GIF with no image printed `no IDAT chunks`. It now prints
    `no image in GIF (no image descriptor)`.
  - The incomplete-frame warning said "tail zero-filled". chitra actually fills
    the tail with palette entry 0. It now says `(image data ran out; the rest is
    drawn in palette colour 0)`.
- **A zero width or height** printed "image dimensions exceed policy ceiling".
  It now prints `image dimensions are zero or past the policy ceiling (…)`.
- **BMP features named none of the causes.** An OS/2 Huffman or `BI_CMYK` BMP
  printed "unsupported BMP feature (bit depth, BI_JPEG/BI_PNG compression, …)".
  It now prints `(bit depth, compression method, or channel mask)`.
- **A negative `--width`** (`-5`, `=-5`, `-w -5`) silently meant "fit the
  terminal". It now prints `kii: --width must not be negative (0 = fit the
  terminal)` and exits 2.
- **`--verbose` said "→ 16-color" under `--color 8`.** It prints the active tier
  now.
- **A terminal reporting 0 rows got no row for the prompt.** That is how a serial
  line or a telnet session without size negotiation looks. kii drew 24 rows and
  the top one scrolled off a 24-row screen. It now draws 23, as a measured
  24-row terminal gets. Output to a pipe is unchanged.
- **The short-flag error gave the wrong advice.** `-w5` and `-v=1` were told to
  "use -x -y, not -xy". The message is now `kii: short flags take no attached
  value and cannot be bundled (use -w 40 -v, not -w40 or -wv)`. In `--help`,
  `--mode` no longer says "(default)" twice, and an example no longer claims
  "(80x24)".
- **The pstruct is zeroed before decode.** `main`'s `var pstruct[160]` is
  uninitialized stack, which made the "has this stage run?" checks in quantize
  and emit dead code. There was no production impact, because every slot was
  written before it was read.
- **No raw syscall numbers remain.** `SYS_EXIT` replaces `syscall(60, …)` in the
  seven test, fuzz and bench entry points, and `sys_write` replaces five
  `syscall(1, …)` writes in `src/`.
- **The geometry fuzz surface could only fail by crashing.** It now checks the
  geometry contract. A one-off row error fails 999,970 of 1M iterations.

### Changed
- **Faster on small images.** None of these changes the output.
  - `quantize_nearest_rgb` reads the palette inline: ~4×, with all 2²⁴ RGB
    values identical at both tiers.
  - The ASCII matcher stops scoring a glyph once it cannot win (an exact early
    exit): ~2×.
  - RGBA downscale has a fast path.

  A 256² icon at `--width 200` renders in 7.7 ms (was 16.7). Large PNGs do not
  move, because their time is chitra's inflate (`docs/benchmarks.md` § v1.6.4).
- **The decode diagnostics are testable.** They moved out of `main` into
  `kii_decode_error_text` and `kii_incomplete_warning_text` (`src/png.cyr`).
  The `--width` checks moved into `kii_width_error_line` (`src/cli.cyr`).
  `KII_MAX_RAW_BYTES` is now chitra's `CHITRA_MAX_RAW_BYTES`; both are 256 MB.
- **Binary sizes.** `build/kii` is 999,328 → 999,656 bytes and `--agnos`
  1,013,568 → 1,013,904. `--aarch64` is 1,171,128 → 1,236,984, but 64 KiB of
  that is segment-alignment padding: the text grew 2,280 bytes and crossed a
  64 KiB boundary.

### Verified
- **The three zlib CVE classes hold** against sankoch 2.8.7: CVE-2004-0797,
  -2005-1849 and -2005-2096. They were recorded in 2026-05 as "to file
  upstream" and never were.
  - The streams tried: 95 hand-built streams, 73,806 truncations, 300,000
    mutants and 100,000 random dynamic headers.
  - They ran under poison redzones against zlib as the reference.
  - The result: 0 crashes, 0 overruns, 0 verdict disagreements.

### Tests
- **67 assertions** (642 → 709):
  - cli 141 → 163: the width line, the frame cap, `-m`.
  - decode 171 → 208: every decode line per format, a directory → IS_DIR, pstruct
    zeroing, the 256 MB pin, chitra's code space pinned at 35.
  - render 188 → 198: alpha compositing on both paths.
  - quant 125 → 123: the dead `_color_dist2` group became a 4,096-colour grid
    check against the old quantizer body, at both tiers.
- Labels fixed: a false "JPEG seen_iend forced 1", a stale comment, and a
  duplicated assertion.

### Documentation
- **Corrected against the tree:** README, SECURITY, CONTRIBUTING, the
  getting-started guide, the architecture map, ADRs 0002–0009 (as amendments),
  the examples, and the doc-health ledger.
  - The getting-started guide's error table now lists every message, including
    the exit-2 usage lines.
  - The architecture map no longer draws the pre-v1.2.0 decoder.
- **Roadmap:** the 1.6.4 section is gone. The deferred findings joined their
  pinned versions:
  - 1.7.0: dead decoder branches, the shared emit loop, cmdit range/enum.
  - 1.8.0: true 16-colour SGR codes, SGR elision, real transparency.
  - 1.9.0: pixel-centre sampling.
  - 1.10.0: the missing glyph-table generator.

## [1.6.3] - 2026-10-15

**Toolchain `6.7.9` → `6.7.12` and `[deps.chitra]` `1.1.3` → `1.2.0`. Renders about 3.5×
faster with byte-identical output.** darshana 1.3.0 and cmdit 1.4.0 are still the newest
tags. No kii source changed except the `--version` literal and two comments.

Output was compared against 1.6.2:
- **130 of 130** standard cases (6 images × both lanes × 8 width/flag combinations, plus the
  decode diagnostics, usage errors and `--help`) are byte-identical.
- **932 of 932** runs over 466 system images are byte-identical. That is every JPEG, GIF and
  BMP under `/usr/share` plus every seventh PNG, at `--width 40` and `--mode ascii --width 30`;
  456 decode and 10 are refused identically.

**642 assertions** pass on x86_64 and under `cyrius test --aarch64`. **8,011,000 fuzz
iterations** are all clean. Every target builds with zero warnings.

### Changed
- **Toolchain `6.7.9` → `6.7.12`.** The 6.7.10–6.7.12 changelog was audited against kii's
  source for anything that changes what it compiles to: new or reserved identifiers,
  precedence, literal folding, argument evaluation, `var buf[N]` sizing, struct and
  multi-value semantics, and the stdlib modules kii links. Nothing applies, because kii uses
  no struct, enum, generic, float, destructure or typed local, and no new stdlib name
  collides with a kii global. Confirmed directly: with chitra held at 1.1.3, the 6.7.12
  compiler builds **byte-identical** binaries to 6.7.9 for `src/main.cyr`, `src/test.cyr`,
  every suite and both harnesses.
  - `lib/` re-vendored from clean (`rm -rf lib && mkdir lib && rm cyrius.lock && cyrius deps`).
    It is still 40 files, and 17 of them change.
  - `args_init` now reads `/proc/self/cmdline` to the end instead of stopping at 2 MiB.
    kii does not call it directly, and cmdit 1.4.0 still refuses a command line of 2 MiB or
    more with `could not read the full command line` (1.6.2), so kii's behaviour is unchanged.
- **The stdlib's sankoch moves 2.8.3 → 2.8.7**, bringing 2.8.4–2.8.6 with it:
  - ⭐ **About 3.5× faster end to end.** sankoch 2.8.6 replaced `_huff_decode`'s slow path,
    the O(bits × num_symbols) nested scan the v1.5.1 sweep measured as ~93 % of kii's render,
    with canonical count/offset decoding (as zlib's `puff.c`). RAMGON → 80×24 went 723–839 ms
    → 206–233 ms, and the 256² PNG decode 2.4–2.6 ms → 1.2–1.4 ms, interleaved in one session
    (`docs/benchmarks.md` § v1.6.3). The roadmap's S-1 item closes upstream.
  - **Inflate now refuses what zlib refuses.** Over-subscribed or incomplete Huffman code sets,
    and `hdist` 31/32, are rejected. A PNG carrying such a stream used to decode and now reports
    `DEFLATE decompression failed (corrupt IDAT)`. This closes the sankoch-floor caveat recorded
    at 1.6.1. No valid image is affected: the 466-image run above is byte-identical.
  - CRC-32 uses PCLMULQDQ on x86_64, with bit-identical results.
  - `DECOMPRESS_MAX_OUTPUT` is still 16 MiB, so PNGs above ~5.6 megapixels are still refused
    with `image too large to decode`.
  - `build/kii` 924,088 → 999,328 bytes (unstripped, DCE off), almost all of it sankoch 2.8.7's
    larger bundle (its new Brotli encoder), which kii links as a stdlib leaf.
    `--agnos` → 1,013,568, `--aarch64` → 1,171,128.
- **`[deps.chitra]` `1.1.3` → `1.2.0`.** Nothing frozen changed, and decode output is
  byte-identical to 1.1.4. 1.2.0 renames chitra's 46 internal `chitra_*` functions to
  `_chitra_*`. All 11 chitra functions kii calls are frozen names and still present. One
  comment in `tests/kii.fcyr` cited `chitra_jpeg_scan_markers` and now uses the new name.
- `tests/kii.fcyr`: a comment cited `lib/sankoch.cyr` by line number for the CRC-32 table
  singleton. Those lines moved, so it now names `crc32_table` / `crc32_init_table` instead.
  The `crc32_table = 0` beside each `alloc_reset()` is unchanged, and still redundant with
  sankoch's arena guard.

### Roadmap
- `docs/development/roadmap.md` rebuilt around **pinned versions**:
  - **1.6.4** — a P(-1) sweep. It carries in the literal `syscall(60)` exits, the three zlib
    CVE-class transfers (to verify against sankoch 2.8.7's new checks), and the doc-health
    debt.
  - **1.7.0** — the format-neutral `image.*` / `IMG_ERR_*` rename.
  - **1.8.0** — 256-colour and truecolour.
  - **1.9.0** — dithering, split out of the old single Tier 2 item.
  - **1.10.0** — the ASCII shape-vector refinements.

  Progressive JPEG and PNG past 16 MiB wait on chitra re-pins. The two 2.0 items are listed as
  open. Completed work is gone: the sankoch S-1 row (fixed upstream above) and the
  limitations table it lived in.

## [1.6.2] - 2026-10-15

**kii now names the three parse errors cmdit 1.3.x added, instead of printing `argument parse
error`.** 1.6.1 moved to cmdit 1.4.0, and kii's error switch had no arm for these codes. Every
other output is **byte-identical** to 1.6.1: 130 cases compared (the 124 from 1.6.1 plus six
more flag forms), and 125 are identical. The other 5 are the bool `=value` forms below. Their
exit code (2) and the usage text after the line are unchanged. **642 assertions** (was 599),
passing on x86_64 and under `cyrius test --aarch64`.

### Changed
- **A bool flag given a value names the flag.** `kii --verbose=0 img.png` now prints
  `kii: --verbose takes no value`, as do `--verbose=1` and `--verbose=`. `--help=x` and
  `--version=1` likewise print `kii: --help takes no value` and `kii: --version takes no value`.
  In 1.6.1 each printed `kii: argument parse error`, and before 1.6.1 `--verbose=0` turned
  verbose **on**. The short form `-v=1` was already a bundled-flag error and still is. The value
  the user typed is not echoed, so no argv byte reaches stderr. The flag name is kii's own
  registration literal. (`CMDIT_ERR_UNEXPECTED_VALUE`, cmdit 1.3.1.)
- **A command line the stdlib cannot read whole** prints `kii: could not read the full command
  line` (`CMDIT_ERR_ARGV`, cmdit 1.3.2). This happens with arguments over 2 MiB in total, or
  with no `/proc` mounted. cmdit refuses to parse a prefix.
- **A refused allocation while parsing** prints `kii: out of memory` (`CMDIT_ERR_NOMEM`, cmdit
  1.3.1). That includes `cmdit_new` returning a 0 handle, which cmdit 1.3.2 made safe to pass
  on.
- The lines moved out of `main`'s nested `if`/`else` into `kii_parse_error_line(err)` and
  `kii_err_flag_name(fs)` in `src/cli.cyr`, so tests can check the exact bytes. The four lines
  that existed before are byte-for-byte what `main` printed inline. Codes kii's flag set cannot
  produce (required, enum, range, verb, positional-count, repeated) keep the generic line.

### Added
- **43 assertions** in `tests/cli.tcyr` (98 → 141):
  - `--verbose=0`, `--verbose=`, `--help=x` and `--version=1` each give `UNEXPECTED_VALUE`
    naming the right flag, and verbose stays off.
  - `-v=1` is `BUNDLED`; `--width=5 --mode=ascii` still parse.
  - `UNKNOWN` and `BUNDLED` name no flag.
  - The exact line for every reachable code, and the generic line for each unreachable one and
    for a code past the taxonomy.
  - A 0 handle reports `NOMEM` and names no flag.

  Three seeded reverts are caught, each as a failing verdict: the flag name, the `NOMEM` line
  and the `ARGV` line. The flag-name checks test for 0 before comparing strings. Without that,
  a regression crashed the suite with SIGSEGV instead of failing it.

## [1.6.1] - 2026-10-15

**Dependencies to the newest tags that build on cyrius 6.7.9, and `cyrius.cyml` cut back to a
manifest.** `[deps.cmdit]` `1.2.5` → `1.4.0` and `[deps.chitra]` `1.0.3` → `1.1.3`;
`[deps.darshana]` stays at `1.3.0`, its newest tag. The toolchain stays at `6.7.9`. No kii source
changed except the `--version` literal. Every rendered frame is **byte-identical** to v1.6.0: 124
cases compared (6 images × both lanes × 8 width/flag combinations, plus the decode diagnostics,
usage errors and `--help`). 121 are identical. The other 3 are the cmdit change below.
**599 assertions** pass on x86_64 and under `cyrius test --aarch64`, and **8,011,000 fuzz
iterations** are all clean.

### Changed
- **`[deps.cmdit]` `1.2.5` → `1.4.0`.** Append-only on the frozen 1.0 surface, and `--help` is
  byte-identical. Two 1.3.x repairs change what kii accepts:
  - ⚠ **A bool flag given a value is refused** (cmdit 1.3.1, `CMDIT_ERR_UNEXPECTED_VALUE`).
    `kii --verbose=0 img.png` used to turn verbose **on**, the opposite of what was typed. Now it,
    `--verbose=1` and `--help=x` exit 2 with `kii: argument parse error` and the usage text.
    kii's `cmdit_error` switch has no arm for the new code, so it prints the generic line.
  - A command line that the stdlib cannot read whole (over 2 MiB, or no `/proc`) now fails with
    `CMDIT_ERR_ARGV` instead of parsing a prefix (cmdit 1.3.2). This also gets the generic line.
- **`[deps.chitra]` `1.0.3` → `1.1.3`.** Nothing frozen moved: kii calls the same names, and the
  `ChitraErrCode` values are unchanged. chitra 1.1.1's audit moved several refusals to more
  precise codes, so kii's mapping now prints a better message for each:
  - a second IHDR: `unsupported image feature …` → `malformed PNG (bad chunk, …)`;
  - a sankoch OOM during inflate: `DEFLATE decompression failed` → `out of memory or image too
    large …`;
  - a truncated JPEG scan: `malformed JPEG …` → `truncated image (unexpected end of data)`;
  - SOF1/2/9 with 16-bit quant tables (every `cjpeg -quality` ≤ 23 file): `malformed JPEG …` →
    `unsupported JPEG feature …`;
  - OS/2 2.x BMP with compression 3: `malformed BMP …` → `unsupported BMP feature …`.

  Some files decode differently, always toward the reference decoders (`djpeg -nosmooth`,
  ImageMagick):
  - **now decode:** End-less GIFs whose padding fills a code, and truncated restart-interval
    JPEGs (partial image, with the missing-end warning);
  - **now refused:** JPEGs with JPG/DHP/EXP or `0xF0`–`0xFD` segments, and scans whose components
    are out of frame order;
  - **different pixels:** a short `JFIF` APP0 next to an Adobe transform, BMPs with
    `bfOffBits = 0`, and BMP channels wider than 8 bits.

  chitra 1.1.0 also stopped linking all of sankoch. It now declares its own `[deps.sankoch]`
  (`zlib` profile, 2.8.7). kii's stdlib `sankoch` leaf takes precedence (closest-wins), so the
  profile is not vendored and kii links the same sankoch as before. `cyrius.lock` records the
  transitive sankoch 2.8.7 commit pin.
- **`cyrius.cyml` is a manifest again**: 126 lines → 39. The pin history, release notes and
  adoption rationale that had built up in its comments are gone. That record belongs in this
  file, `docs/development/state.md` and the ADRs, which already hold it. Each dep keeps a one-line
  comment saying what it is for.
  - `repository` corrected from `MacCracken/cyrius-kii`, which does not exist, to
    `MacCracken/kii`. The same wrong URL is fixed in the getting-started clone line.
  - `description` now says what kii is, not which version planned what.
- **`cyrius.lock`** regenerated from a clean `lib/`. It drops five stale commit pins for tags no
  longer in the manifest (chitra 1.0.0 and 1.0.3, cmdit 1.2.4 and 1.2.5, darshana 1.0.0). `lib/`
  is still 40 files. Only `chitra.cyr` and `cmdit.cyr` changed.
- `build/kii` 898,344 → 923,976 bytes (unstripped, DCE off), all from the two larger bundles.
  `--agnos` 908,376 → 938,088; `--aarch64` 1,086,544 → 1,087,600.

### Not taken
- **chitra 1.1.4 and 1.2.0 pin cyrius 6.7.12**, so they are out of reach on 6.7.9. 1.2.0 renames
  46 internal `chitra_*` functions to `_chitra_*`. kii calls none of them in code; one comment in
  `tests/kii.fcyr` cites `chitra_jpeg_scan_markers`.
- ⚠ **The sankoch floor.** chitra 1.1.1 documents that inflate is only as strict as zlib from
  sankoch **2.8.6**. cyrius 6.7.9's stdlib ships **2.8.3**, and kii links the stdlib leaf. So, as
  in v1.6.0, kii's PNG path still accepts five deflate stream classes that zlib refuses (Kraft
  over-subscription and incompleteness, `hdist` 31/32). Moving to cyrius ≥ 6.7.11, whose stdlib
  sankoch is 2.8.7, closes this.

## [1.6.0] - 2026-10-12

**The cyrius 6.7 language minor, darshana 1.3.0, and the end of the `path` overrides.**
Toolchain `6.6.2` → `6.7.9`; `[deps.darshana]` `1.0.0` → `1.3.0`, with kii adopting two of
the primitives darshana built on kii's own code; and the manifest's tags reconciled with
what kii actually compiles. Every rendered frame is **byte-identical** to v1.5.2: 190 frames
compared (8 fixtures × both lanes × 6 widths, `--color 8`, `--verbose`, plus 54 runs on a
pty at nine window sizes from 0×0 to 50×200), along with `--help`, nine usage errors and the
not-an-image / missing-file diagnostics; the `--aarch64` build, run under qemu, produces the
same bytes as x86_64 on all 187 non-pty cases. Two outputs change on purpose — the path
sanitizer's verdict on four classes of malformed UTF-8, and the message for a valid PNG too
large to inflate — both below. **599 assertions** (was 550), passing on x86_64 and under
`cyrius test --aarch64`; **8,011,000 fuzz iterations**, all clean, peak RSS 137,848 KB (was
6,011,000).

### Changed
- **Toolchain `6.6.2` → `6.7.9`.** No kii source needed a repair. The 6.7 series is a
  language minor, so the tree was audited against each change that alters what compiled code
  does, not just against the build: no lone `!` (a real operator since 6.7.3, silently dropped
  before), no unary `-` / `~` on a constant (re-folded at 6.7.9), no typed or narrow-pointer
  dereference (6.7.8), no compound assignment at all, no `struct` / `enum` / `const` / `trait`,
  and no identifier that 6.7 reserves. Every target builds with **zero warnings**: host,
  `--agnos`, `--aarch64`, `tests/kii.fcyr`, `tests/kii.bcyr` and all six test entries.
  `lib/` re-vendored (`rm -rf lib && mkdir lib && cyrius deps`): 39 → 40 files — `alloc_cx.cyr`
  and `poison.cyr` arrive with the 6.7.9 allocator, and `flags.cyr` leaves, because chitra
  1.0.1 dropped `flags` from its `.deps` sidecar and nothing else kii links asks for it. `build/kii` grows
  683,584 → 898,344 bytes (unstripped, DCE off) with the new toolchain and the larger darshana
  bundle; nothing in kii's own source grew. End-to-end render time is roughly 5–15 %
  slower than the v1.5.2 binary run interleaved in the same session (a loaded host, so a
  range, not a figure; `docs/benchmarks.md` § v1.6.0) — the toolchain's, since the render is
  ~93 % sankoch's inflate.
- **The `path = "../X"` overrides are gone, and the tags now say what kii compiles.** Through
  v1.5.2 each `[deps.X]` named a sibling checkout beside its tag, and the pre-6.7.6 resolver
  vendored the checkout. So v1.5.2's manifest said darshana 1.0.0 / cmdit 1.2.4 / chitra
  1.0.0 while the binary was built from **darshana 1.1.2 / cmdit 1.2.5 / chitra 1.0.3**
  (read from the vendored bundles' headers), and CI, which has no siblings, compiled the
  tags — local and CI builds were not the same program. From cyrius 6.7.6 a `path` beside a
  tag is a `--local`-only dev override, and nothing in kii documented a reason for any of the
  three, so all three are dropped. The tags move to what was really compiled:
  - `[deps.darshana]` `1.0.0` → **`1.3.0`** (below).
  - `[deps.cmdit]` `1.2.4` → **`1.2.5`** — not a change of code: 1.2.5 is what v1.5.2 shipped.
    Leaving the tag would have downgraded the bundle under git-first resolution.
  - `[deps.chitra]` `1.0.0` → **`1.0.3`** — likewise what v1.5.2 shipped. A 1.0.0 tag would
    have dropped chitra 1.0.3's repairs (a SIGSEGV on the first PNG decoded under memory
    pressure, a truncated JPEG scan reported as cleanly closed, every RLE BMP whose width is
    not a multiple of 4 refused). The suite passes on either tag: the downgrade is the reason,
    not a build failure.
  - `cyrius.lock` regenerated; it now carries commit pins for the three deps (cyrius 6.7.6).
- **`[deps.darshana]` `1.0.0` → `1.3.0`.** darshana 1.1–1.3 is additive on its frozen 1.0
  surface and changes no byte kii already emitted. ⚠ darshana ≥ 1.3.0 needs cyrius ≥ 6.7.2
  (its bundle uses `const`), which is why the toolchain moved first.
- **The background colour composer is darshana's.** `tty_bg_256_buf` (darshana 1.2.0) replaces
  kii's local `_emit_bg_256_buf`, which kii carried from v0.6.0 because darshana had no
  background twin. kii was that composer's first consumer; darshana extracted it when thoth
  became the second — exactly the trigger the local helper's comment named. Its bytes are
  identical for **all 256 indices**, at a fresh and a chained position, and it writes nothing
  past the escape it returns (asserted against the retired body, kept verbatim in
  `tests/render.tcyr`). This also retires the stale comment that cited darshana's
  `_ansi_emit_u8`, a helper darshana deleted at 1.1.0.
- **The stderr path-echo sanitizer is darshana's `tty_has_ctl`, and it is slightly stricter.**
  `kii_path_has_control_bytes` is now `tty_has_ctl(path, strlen(path), TTY_SANITIZE_UTF8,
  TTY_KEEP_TAB | TTY_KEEP_LF)`. darshana shaped that predicate (1.3.0) on this function, so
  every class kii already refused is still refused — C0 except TAB/LF, DEL, raw C1, the
  `C2 80`–`C2 9F` spelling of C1, and malformed UTF-8 — and it adds one: **strict RFC 3629**.
  ⚠ **Behaviour change**: a filename holding an overlong 3- or 4-byte form (`E0 80`–`9F …`,
  `F0 80`–`8F …`), a UTF-16 surrogate (`ED A0`–`BF …`) or a code point past U+10FFFF
  (`F4 90`–`BF …`) is now printed as `<path containing control bytes — suppressed>`; v1.5.2
  echoed it, because its walk checked only that each continuation byte was `0x80`–`0xBF`. None
  of these is valid UTF-8, so no legitimate filename carries one, and the overlong forms are a
  live vector: `E0 82 9B` is an overlong spelling of U+009B (CSI), which a lenient UTF-8
  decoder in the terminal turns back into the control the C1 rule exists to stop. A
  1,000,000-iteration differential fuzz surface proves that set is the **only** change: on
  every input the new verdict equals the v1.5.2 walk's, except exactly where the input holds
  one of those four forms (≈ 203,000 such inputs and ≈ 284,000 accepted by both, per run).
- **The terminal-size rule moved into `_kii_term_envelope` (`src/emit.cyr`)** so it can be
  tested; it computed the same values inline in `main.cyr`, untested. darshana's
  `tty_winsize_or` (1.2.0), which exists to replace hand-written zero guards, was considered
  and **not adopted**: it treats a 0 in *either* dimension as "size unknown" and substitutes
  both defaults, while kii decides columns and rows separately (the v1.5.1 A-8 repair). On a
  serial or BBS-style line after `stty cols 40` with no `stty rows`, `tty_winsize` reports
  0 × 40; kii keeps the 40 columns, where the both-or-neither rule would draw an 80-column
  frame onto a 40-column line. Output is unchanged at all nine pty sizes tested.

### Fixed
- **A valid PNG too large to inflate was reported as "malformed PNG".** chitra 1.0.1 gave
  this case its own code, `CHITRA_ERR_INFLATE_LIMIT` (35): an image whose pixel data inflates
  past sankoch's 16 MiB `DECOMPRESS_MAX_OUTPUT` (about 5.6 megapixels of RGB) is refused
  before anything is allocated. `_kii_map_chitra_err` had no arm for 35, so a 2370×2370 RGB
  PNG that ImageMagick reads without complaint fell through to the generic fallback and kii
  printed `malformed PNG (bad chunk, ordering, or palette)` — present in v1.5.2, which
  already compiled chitra 1.0.3, and found by re-reading chitra 1.0.1–1.0.3 for this pin.
  New `PNG_ERR_INFLATE_LIMIT` (17) → `image too large to decode (pixel data inflates past the
  decompressor's 16 MiB ceiling)`, exit 1. A test pins `DECOMPRESS_MAX_OUTPUT` at 16 MiB so
  the message cannot drift from the ceiling it quotes. New fixture
  `tests/fixtures/oversize.png` (2370×2370 black RGB, 16,447 bytes, verified with ImageMagick).
- **The fuzz harness could not fail on a contract violation.** Each surface tallied a `bad`
  count, printed it, and the harness still said `fuzz: ok` and exited 0 — so CI's
  `./build/kii-fuzz` step could go red on a crash and on nothing else. It now prints
  `fuzz: FAIL` and exits 1 when any surface reports a bad iteration.
- `emit_halfblock`'s docstring had been split in two by `_kii_write_all`, which v1.5.1
  inserted into the middle of it, and promised an end-of-frame reset the function has never
  emitted (each row ends with its own reset). Comment-only; reassembled and corrected.
- `kii_path_has_control_bytes`'s docstring still said the C1 range is *not* rejected — false
  since v1.5.1. Rewritten with the predicate.

### Added
- **49 assertions** (550 → 599): cli 77 → 98 (strict RFC 3629 boundaries on both sides of each
  forbidden range, the two overlong CSI spellings, and the wiring to `tty_has_ctl`'s mode and
  keep bits), render 164 → 188 (the 256-index byte-identity sweep against the retired
  composer, and `_kii_term_envelope` including the 1-row and half-set cases), decode
  167 → 171 (`PNG_ERR_INFLATE_LIMIT` mapping, the oversize fixture end to end, its format tag,
  and the ceiling pin).
- **Two fuzz surfaces**, run after the existing eight so those see exactly the random stream
  they did through v1.5.2: the path-sanitizer differential against the v1.5.2 walk (1M, with a
  UTF-8-shaped generator, since random bytes are almost never valid text) and the terminal
  envelope feeding the fit geometry (1M; the frame is never wider than a measured column
  count). Both were checked to fire: the old walk fails the differential on every
  strict-only input, and a both-or-neither envelope fails the envelope surface.

### Upstream re-verification (the review trigger in `roadmap.md`)
- **sankoch S-1** (O(bits × symbols) Huffman slow path): unchanged at sankoch 2.8.3 — open.
- **sankoch S-2** (16 MiB inflate cap): the cap stands; its wrong-diagnostic half is the
  fix above.
- **sankoch S-3** (`crc32_table` invalidated by `alloc_reset()`): **fixed upstream** by
  sankoch's arena canary (2.7.10+). 20,000 decode + `alloc_reset()` cycles with kii's
  `crc32_table = 0` workaround removed: every decode succeeded and no pixel byte differed. The
  workaround stays in the fuzz harness as a harmless second line; the row leaves the roadmap.

### Documentation
- `docs/development/state.md` was not refreshed at v1.5.2 (it still read 1.5.1, toolchain
  6.5.35); refreshed for 1.6.0. `roadmap.md` drops the three darshana items and the cyrius
  6.7.6 note this release acts on, and records the sankoch re-verification. README, SECURITY,
  `docs/architecture/README.md` item 004, ADR 0002 (amendment), CONTRIBUTING and
  `docs/doc-health.md` updated to match.

## [1.5.2] - 2026-09-11

### Changed

- **Toolchain `6.5.35` → `6.6.2`.** No source change; the value form needed none.
  Build, tests, and any bench/fuzz/distlib target the repo ships re-verified at the new pin.


## [1.5.1] — 2026-08-25

**P-1 audit / refactor / hardening / optimization / security sweep.** Five audit
lenses (correctness, security, refactor, optimization, docs + deferred-item) over
the full surface, every material finding put through an adversarial refutation
pass: **41 raised, 2 refuted, 39 folded into 16 work items**. Full report in
[`docs/audit/2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md).

Rendering is **byte-identical** at the default colour tier — 22/22 golden
artifacts across four formats, five widths, both render lanes, `--verbose` stderr
and `--help`. **550 assertions** (was 511); 6,011,000 fuzz iterations clean, one
million of which were previously measuring nothing.

### Fixed
- **Memory safety: unbounded `--width` wrapped an allocation and the resampler
  wrote past it.** `dst_w * dst_h * 3` is an unchecked 64-bit product;
  `alloc()` rejects only `size <= 0` and `size > ALLOC_MAX`, so a product that
  wraps to a small positive value was honoured. With a 1×1 PNG,
  `kii --width 4611686018427387902` wrapped to a **12-byte** allocation and died
  with **SIGSEGV** — an out-of-bounds heap *write*, on both render lanes. Now
  capped at `KII_MAX_COLS` in `main.cyr` (with a real usage diagnostic) **and**
  guarded independently inside `downscale_to_rgb`, so the resampler is safe for
  any caller. ([`src/main.cyr`](src/main.cyr), [`src/downscale.cyr`](src/downscale.cyr))
- **A truncated JPEG rendered silently.** The `seen_iend` gate had no JPEG arm,
  and its comment claimed chitra *"reports 1 unconditionally for JPEG"* — false;
  chitra sets the flag from a real `closed` decision made by the scan driver. A
  truncated or EOI-stripped JPEG produced a partial frame, empty stderr, exit 0.
- **The 1,000,000-iteration PNG fuzz surface had been testing nothing.** The
  per-iteration `alloc_reset()` that bounds the never-free heap also invalidated
  `sankoch`'s cached CRC-32 table (a lazy-init singleton holding a heap pointer),
  so from iteration 2 onward the table aliased live decode memory. A return-code
  tally showed **2999 of 3000** iterations dying at the signature check instead
  of reaching the chunk walker, inflate, unfilter or the PLTE bounds. Every
  `alloc_reset()` is now paired with `crc32_table = 0`; the post-fix tally is
  identical to a no-reset run.
- **The ANSI-injection sanitizer covered C0 but not C1.** A filename of
  `9D 30 3B 50 57 4E 45 44 9C` — a complete C0-free `OSC 0;PWNED ST` — reached
  stderr **byte-for-byte**, through the guard that exists to stop exactly that,
  while its C0 spelling was correctly suppressed. The predicate now walks UTF-8
  structure (rather than testing a flat byte range, which would break ordinary
  non-Latin filenames) and rejects raw C1, the `C2 80`–`C2 9F` UTF-8 spelling,
  and malformed UTF-8. A test asserting `a\x80b` was *safe* — justified as a
  "UTF-8 ergonomics" relaxation — is superseded: a bare `0x80` has no lead byte,
  so it is not valid UTF-8 and no legitimate filename produces it.
- **Every `write(2)` to stdout was unchecked.** `kii img.png > out.ansi` on a
  full filesystem exited **0** having written nothing, so `kii … > out && use out`
  consumed the empty file. Short writes would have truncated the stream mid-row.
  New `_kii_write_all` drains the buffer, retries `EINTR`, and both lanes report
  `failed to write frame to stdout` and exit 1. SIGPIPE keeps its default
  disposition deliberately.
- **A JPEG could be told about the PNG § 11.2.2 bit-depth table.**
  `CHITRA_ERR_UNSUPPORTED` mapped to `PNG_ERR_BITDEPTH`, but that chitra code
  spans formats — including an Adobe APP14 transform, which is a JPEG. This was
  the one path producing exactly the outcome `PNG_ERR_UNSUPPORTED`'s own comment
  says the split prevents. Now maps to `PNG_ERR_UNSUPPORTED`;
  `CHITRA_ERR_BIT_DEPTH` still maps to `PNG_ERR_BITDEPTH`.
- **A 1-row terminal discarded its own valid column count.** The winsize result
  was gated by one combined condition whose `term_rows > 1` clause scoped over
  the whole assignment, so a successful detection reporting good columns was
  thrown away wholesale and kii fell back to 80 — emitting a frame wider than the
  terminal it had just measured.
- **`_emit_bg_256_buf` diverged from the darshana twin it mirrors**, missing the
  negative-`pos` guard darshana 0.9.3 added to all seven of its own `_buf`
  composers — despite sitting in the same per-cell chain, taking the FG
  composer's return value as its `pos`.
- **A benchmark vanished instead of failing.** The three fixture-guarded decode
  benches had no `else`, so the `1024²` row silently disappeared when its system
  fixture stopped shipping, while `docs/benchmarks.md` kept quoting `647 ms` for
  it. All three now print an explicit `SKIPPED` line.

### Added
- **`--color 8` now does something.** It had been parsed and range-validated
  since M1 and then ignored, so `kii --color 8` emitted output byte-identical to
  `--color 16` while its help text promised *"color tier: 8 or 16"*. The
  quantizer's search is now bounded by `quant_set_tier`; the low 8 palette
  entries *are* the 8-colour tier, so no second table exists. `--color 16` is
  unchanged. **This changes `--color 8` output** — that is the repair.
- 39 assertions: C1 sanitizer coverage in both encodings plus malformed-UTF-8
  and boundary cases, the `--color` tier contract, the `downscale_to_rgb`
  overflow guard, and the `_emit_bg_256_buf` negative-`pos` guard.
- **`docs/audit/2026-08-25-audit.md`** — the P-1 report, including a
  "What the sweep did NOT find" section and the refuted findings.

### Changed
- **`docs/benchmarks.md` gains a v1.5.1 re-baseline.** Every bench reproduces
  within noise (a prior audit had speculated the 6.5.x toolchain removed an
  instrument — it did not). Stage-splitting the render puts **~93 % of wall-clock
  inside `sankoch`'s Huffman decoder**, which is O(bits × num_symbols) where the
  canonical form is O(bits); a drop-in replacement measured **~3.7× end-to-end**
  with byte-identical output. kii's own downscale + quantize + emit are together
  **under 2 %**. Filed upstream — there is no meaningful latency work inside kii,
  and the entry says so explicitly so nobody spends a cycle on it.
- **Documentation corrected across nine files** where claims had outlived the
  code: `SECURITY.md` (Adam7 + sub-byte depths described as *rejected* — false
  since v1.2.2), `docs/guides/getting-started.md` (seven of twelve quoted error
  messages unemittable since v1.2.0), `docs/architecture/README.md` item 005
  (argued for keeping a function deleted at v1.2.0, citing a test file retired in
  the same release), `CLAUDE.md` + `README.md` (BMP/GIF still *planned*; Status
  block reading v1.0.3), `CONTRIBUTING.md` (pointed at the retired
  `tests/kii.tcyr`, published v0.5.0 counts), `docs/development/state.md` (chafa
  review listed as deferred though it closed at v1.0.0, linked to a filename that
  has never existed, and a binary-size figure **4.6× low**), plus stale headers
  and `--help` wording in `src/`.
- **Three `sankoch` limitations are now tracked for later review** in
  [`docs/development/roadmap.md`](docs/development/roadmap.md) § Upstream, with
  their measurements and an explicit review trigger (re-verify at the next
  `cyrius` pin bump): the O(bits × num_symbols) Huffman decoder (S-1), the 16 MiB
  inflate cap that makes any PNG above ~5.6 megapixels report `corrupt IDAT`
  (S-2), and the un-invalidatable `crc32_table` singleton (S-3). All three are in
  vendored `lib/`, which kii must not edit — none is a kii defect and none blocks
  a kii release. S-1 is worth raising as a `sankoch` issue on its own merits:
  every stdlib consumer that inflates anything pays for it, not just kii.
- `PNG_ERR_CHUNK`'s inner `if/else` had two byte-identical arms; collapsed. The
  dead `_print` helper — the only unreachable function in `src/` — removed.

## [1.5.0] — 2026-08-24

**The format broadening — BMP + GIF arrive on a `chitra` re-pin, and kii's diagnostics
grow to meet them.** Re-pins [`[deps.chitra]`](cyrius.cyml) `0.3.0` → `1.0.0`, which
carries BMP decode (chitra 0.4.0) and GIF first-frame decode (chitra 0.5.0) alongside
the PNG + baseline-JPEG surface kii already had. **The decode path needed no change at
all**: [`src/png.cyr`](src/png.cyr)'s adapter has always called the format-sniffing
`chitra_image_decode` unconditionally, so both formats normalized to canonical RGBA8 and
rendered the moment the pin moved — exactly the payoff ADR 0006 predicted when kii
deleted its own decoder. This is the third consecutive format kii has gained without
writing a decoder (PNG re-fold v1.2.0 → JPEG v1.4.0 → BMP/GIF v1.5.0).

What did **not** come free is the diagnostics, and that is the bulk of this cut. Because
BMP and GIF arrived silently, four code sites were factually wrong at runtime rather than
merely stale: a corrupt `.bmp` reported `malformed PNG (bad chunk, ordering, or palette)`,
`--verbose` printed `(?)` for every BMP/GIF source type, all eleven new `ChitraErr` codes
(24–34) collapsed into the generic malformed fallback, and the unrecognized-format message
still said "expected PNG or JPEG" while `kii art.gif` worked. All four are fixed here.

Also folds in the toolchain and the other two dep pins, all of which had drifted behind
what the tree was actually building. **PNG and JPEG frames are byte-for-byte unchanged** —
17/17 golden artifacts identical across RAMGON at 40/80/120/200/default, `--mode ascii` at
40/80/120, both JPEG fixtures, `--verbose` stderr, and `--help`.

### Added
- **BMP rendering** — `kii image.bmp`. Via chitra: `BI_RGB` at 1/4/8/16/24/32 bpp, `BI_RLE4`
  / `BI_RLE8` run-length, and `BI_BITFIELDS` with V4/V5 headers. `--verbose` names the source
  precisely (`24bpp (BMP)`, `4bpp palette (BMP)`, …) from chitra's `0x200 | bpp` sentinel.
- **GIF rendering** — `kii image.gif`. Via chitra: GIF87a/89a, LZW, interlaced frames.
  **First frame only** (chitra ADR 0005) — an animation renders its opening frame, which is
  the correct behavior for a still-frame terminal renderer. Source named `palette (GIF)` from
  the `0x300 | min_code_size` sentinel.
- `KII_FMT_BMP` / `KII_FMT_GIF` format tags, fed by chitra's frozen `chitra_bmp_check_signature`
  / `chitra_gif_check_signature` predicates. The pre-decode sniff is now a four-way chain in
  the same PNG→JPEG→BMP→GIF order chitra routes internally.
- `_kii_map_chitra_err` arms for the eleven `ChitraErr` codes chitra added (BMP 24–27 + 32–33,
  GIF 28–31, `CHITRA_ERR_BUDGET` 34). Structural corruption maps to `PNG_ERR_HEADER`; a bpp
  outside `{1,4,8,16,24,32}`, `BI_JPEG`/`BI_PNG`, and a bad `BI_BITFIELDS` mask are "valid file,
  chitra declines it" → `PNG_ERR_UNSUPPORTED`; GIF LZW → `PNG_ERR_INFLATE`; a GIF with no image
  descriptor → `PNG_ERR_NO_IDAT` (the GIF analogue of a zero-IDAT PNG).
- `png_color_type_name` learns nine new source sentinels: the six BMP `0x200 | bpp` values, the
  GIF `0x300 | min_code_size` range, and JPEG's `0x113` **RGB** sentinel (chitra 0.6.1 — an
  Adobe `transform=0` file that previously reported as YCbCr).
- **Two new fuzz surfaces** — 1M BMP + 1M GIF iterations through `kii_decode_png`, signature-
  prefixed so the payload actually reaches each decoder. Total **6,011,000 iterations, all
  clean** (was 4,011,000), peak RSS ~136 MB. The GIF surface is the highest-value of the four:
  LZW builds a dictionary from attacker-controlled codes, the classic GIF-decoder CVE class.
- **BMP + GIF test fixtures + coverage** — `tests/fixtures/gradient.bmp` (16×16 24-bpp `BI_RGB`
  ramp) and `tests/fixtures/color.gif` (16×16 GIF89a, four flat quadrants), both pixel-verified
  against ImageMagick as the oracle. **511 assertions** (was 431): decode 105 → 166, render
  137 → 156.

### Changed
- Toolchain pin `cyrius = "6.4.20"` → `"6.5.35"`, with `lib/` re-vendored from the 6.5.35
  snapshot. No signature change, removal, or constant change on any stdlib symbol kii calls;
  `sankoch`'s `zlib_decompress` + `crc32` bodies are byte-identical across the fold.
- `[deps.darshana]` `0.8.2` → `1.0.0` — **darshana's API freeze**, byte-identical to 0.9.4.
  All three names kii calls (`tty_fg_256_buf`, `tty_sgr_reset_buf`, `tty_winsize`) are inside
  the frozen 29. The 0.9.3 pre-freeze break — the seven `_buf` composers now reject a negative
  incoming `pos` with `-1` instead of laundering it into an out-of-bounds write — reaches zero
  kii call sites: every `pos` accumulator enters at literal `0` and only grows. Also closes the
  pin mismatch darshana's own 1.0.0 notes flagged against kii by name.
- `[deps.cmdit]` `1.1.0` → `1.2.4` — append-only on the frozen 1.0.0 surface (verb introspection,
  shell completions, `--` forwarding fixes, audit repairs). kii uses none of the verb machinery,
  and `CMDIT_CTX_SIZE`'s growth 160 → 168 is invisible because kii allocates its handle through
  `cmdit_new`, never by hand.
- **`lib/` re-vendored properly**: 104 files → **39**. The tree had been carrying 62 undeclared
  stdlib bundles (`mabda`, `sigil`, `sandhi`, `patra`, `yukti`, `bayan`, …) that kii references
  nowhere, left over from an old full-snapshot vendor; they shadowed the pinned versions and
  produced a standing build warning. `cyrius lib sync` cannot remove them — only
  `rm -rf lib && mkdir lib && cyrius deps` does, which is now also what CI runs.
- The `seen_iend` warning gate is no longer PNG-only. chitra 0.7.0 generalized the field to
  "did the stream end the way its format says it should", and GIF reports a real
  `frame_complete`; a truncated LZW stream is tolerated as a clean end with the tail
  zero-filled, so kii now warns `incomplete GIF (truncated frame — tail zero-filled)` instead
  of rendering a half-decoded frame silently. JPEG and BMP report `1` unconditionally and never
  reach the warning.
- **16-bit PNG output changes** — chitra 0.7.x replaced high-byte truncation with the spec
  § 13.13 rescale. This is a correctness fix kii inherits, not a kii change; depth-8 PNG and
  every JPEG variant stay byte-identical. Noted here so nobody bisects it later.
- `ALLOC_MAX` in the vendored allocator rises 256 MiB → 2 GiB with the toolchain. kii's binding
  input limit is unchanged: `KII_MAX_RAW_BYTES` (256 MB, still matching `CHITRA_MAX_RAW_BYTES`)
  plus chitra's own dimension and IDAT caps.

### Fixed
- **CI would have hard-failed on this bump.** Both workflows hand-rolled a flat tarball copy into
  `~/.cyrius/{bin,lib}`, which never creates the `~/.cyrius/versions/<pin>/lib` layout `cyrius deps`
  resolves against. That only ever worked because of a pre-6.5.25 bug in `_dep_find_stdlib_dir()`
  that treated any tree containing `src/main.cyr` as the cyrius repo and silently fell back to the
  project's **own** `./lib`. 6.5.25 fixed it, so from this pin onward `cyrius deps` exits with
  `pins version 6.5.35 but it is not installed at …/versions/6.5.35/lib`. Both workflows now use
  the upstream installer, matching chitra's CI. Reproduced in a simulated CI layout before fixing.
- **`tests/quant.tcyr` had not compiled since v1.2.0** and its 109 assertions never ran. 48 of the
  palette-table calls passed two arguments to the three-argument `assert_eq(a, b, name)`; the suite
  failed with a compile error that the v1.4.1 cut missed because it verified only the render suite
  ("137/137 green"). Restored to the one-assertion-per-line named form the other suites use — the
  suite passes at exactly the 109 assertions it always claimed.
- A corrupt or truncated BMP/GIF no longer reports PNG chunk-ordering wording, and
  `unrecognized image format` now names all four formats it accepts.

## [1.4.1] — 2026-07-08

**agnos-target build fix + toolchain pin → `6.4.20`.** The committed `lib/` stdlib
snapshot had drifted *behind* kii's own pin: the vendored agnos syscall peer
(`lib/syscalls_x86_64_agnos.cyr`) predated `SYS_LSEEK = 58`, so
`cyrius build --agnos src/main.cyr` failed with `undefined variable 'SYS_LSEEK'` at
[`src/png.cyr:216`](src/png.cyr) — the `lseek(fd, 0, SEEK_END)` file-size probe in
`kii_file_size`. The Linux target was unaffected (`SYS_LSEEK = 8` is long-standing in
the linux peer). Fixed by re-vendoring the stdlib subset (`cyrius lib sync`) against the
advanced pin — **no source change**. Unblocks kii from the agnosticos agnos-dev docker
image ([`docker/build-dev.sh`](https://github.com/MacCracken/agnosticos)), where it had
been auto-skipped on the failing `--agnos` build. Every PNG/JPEG render path is byte-for-byte
unchanged (Linux + agnos-under-mirshi both re-verified on RAMGON).

### Changed
- Toolchain pin `cyrius = "6.2.44"` → `"6.4.20"` — aligns the manifest with the active
  toolchain and removes the standing pin-drift warning; vendored `lib/` re-synced from the
  6.4.20 snapshot.
- `[deps.darshana]` `0.8.1` → `0.8.2` — 0.8.2 is AGNOS parity for the TTY-mode primitives
  (`tty_isatty` / `tty_raw` / `tty_cooked` agnos peers, the same `#ifdef CYRIUS_TARGET_AGNOS`
  pattern as `tty_winsize`). Additive superset of the surface kii uses; render byte-identical.

### Fixed
- `cyrius build --agnos` no longer fails on `SYS_LSEEK` — the vendored agnos syscall peer
  now carries the full frozen syscall set including `#58 lseek`.

## [1.4.0] — 2026-06-27

**Baseline JPEG decode via chitra 0.3.0.** Re-pins `[deps.chitra]` `0.2.1` → `0.3.0`
and switches the decode adapter from `chitra_png_decode` to the format-sniffing
`chitra_image_decode`, so `kii photo.jpg` now renders **baseline (SOF0) JPEG** —
grayscale + YCbCr, 4:4:4 / 4:2:2 / 4:2:0 chroma subsampling, DRI/RST restart markers —
alongside the full PNG matrix. chitra normalizes JPEG to the **same canonical RGBA8**
it produces for PNG, so the whole downscale → quantize → emit pipeline is untouched and
**every PNG frame stays byte-identical** (RAMGON golden at 40/80/120/200/default +
`--verbose`). `--mode ascii`, `--width`, `--verbose`, and terminal-fit all work for JPEG
identically to PNG. See [ADR 0008](docs/adr/0008-jpeg-via-chitra.md).

### Added
- **Baseline JPEG input.** `kii image.jpg` / `image.jpeg` decodes through chitra's JPEG
  path — the formats share everything after decode (one canonical RGBA8 buffer).
- `src/png.cyr`: the 11 JPEG `ChitraErr` codes mapped onto kii's `PNG_ERR_*` — malformed
  structure (marker / SOF / DQT / DHT / SOS / entropy) → `PNG_ERR_HEADER`; the five
  valid-but-unsupported deferred modes (progressive, arithmetic, 12-bit, non-baseline
  SOF, CMYK 4-component) → a new `PNG_ERR_UNSUPPORTED`. A `KII_FMT_*` format tag
  (`STRUCT_FORMAT_OFFSET`, set from the pre-decode signature sniff) drives format-aware
  diagnostics. `png_color_type_name` names the JPEG source sentinels (257 →
  `greyscale (JPEG)`, 259 → `YCbCr (JPEG)`) for the `--verbose` line.
- `tests/decode.tcyr`: **+54 assertions** (51 → 105) — the 11 JPEG error mappings, the
  sentinel names, the format tag, and e2e decode of a grayscale + a YCbCr baseline JPEG
  (`tests/fixtures/{gradient,color}.jpg`) with decoded-pixel checks against the
  ImageMagick reference (grayscale R==G==B invariant, a row-equality scan, and red/blue
  chroma corners), plus a progressive-stub → `UNSUPPORTED` and a malformed-marker →
  `HEADER` path. `tests/render.tcyr`: **+8** — a JPEG render e2e (gradient.jpg all the way
  through downscale → quantize → emit, asserting real ANSI bytes + a `▀` glyph). Suite
  total **431** (was 369).
- `tests/kii.fcyr`: a **1,000,000-iter JPEG adapter crash-safety** surface (SOI + random
  bytes). Each PNG/JPEG decode iter calls `alloc_reset()` to rewind the never-free bump
  allocator (a present SOI makes chitra allocate ~22 KB of marker scratch before failing),
  keeping the run bounded — peak RSS **~134 MB** over **4,011,000** iters across 6
  surfaces, all clean.

### Changed
- `[deps.chitra]` tag `0.2.1` → `0.3.0` (`cyrius.cyml`); `print_version` → `kii 1.4.0`.
- `src/png.cyr` is now the **image** front-end (the adapter calls `chitra_image_decode`,
  which routes PNG vs JPEG by signature). PNG decode path is byte-for-byte unchanged.
- Decode diagnostics in `src/main.cyr` are format-aware where the path is shared:
  `not a PNG` → `unrecognized image format (expected PNG or JPEG)`; the malformed/truncated
  branches read `malformed JPEG …` / `truncated JPEG …` for a JPEG and keep their PNG
  wording for a PNG; `PNG decode failed` → `image decode failed`; `IDAT too large` →
  `image too large`. PNG-only paths (CRC, IDAT, filter, interlace, IEND warning) keep
  their PNG wording — chitra routes by signature, so a JPEG never reaches them.

### Note
- The historical `png_` / `PNG_ERR_*` symbol names and the `src/png.cyr` filename are
  retained (they predate JPEG); a rename to `image.*` / `IMG_ERR_*` is a tracked
  follow-up (`docs/development/roadmap.md`), deferred to keep this cut a tight functional
  wiring per the smallest-first discipline.

## [1.3.1] — 2026-06-26

**ASCII shape-vector glyph matching.** Upgrades `--mode ascii` from the v1.3.0
luminance ramp to **shape-aware** glyph selection: each cell is sampled in a 2×3
sub-grid and matched (nearest squared-Euclidean over the 6 regions) to the glyph
whose ink-coverage vector is closest — so the output tracks glyph *orientation*
(`/ \ | - _ ( ) ^` …), not just density. Half-block remains byte-identical.

### Changed
- `src/ascii.cyr`: replaced the ramp (`_ascii_glyph`/`emit_ascii`) with the
  shape-vector matcher — `_ascii_match` (6-region nearest-glyph), a 27-glyph
  coverage table (`_ascii_shape_init`, computed offline from Liberation-Mono,
  normalized to the 0..255 luminance scale), `emit_ascii_shape_row_buf` +
  `emit_ascii_shape`. `_ascii_luma` retained. `main.cyr`'s ASCII lane downscales
  to (cols·2 × rows·3) for the sub-cell grid; foreground is the cell's mean color
  quantized (no separate `quantize_downscaled` pass in this lane).
- `tests/ascii.tcyr` rewired to the matcher (luma, self-match per glyph, exact
  row bytes, guards).

### Attribution
- The shape-vector technique (per-cell N-region coverage vectors + nearest-glyph
  match) is from **Alex Harri, "ASCII Art Rendering"
  (<https://alexharri.com/blog/ascii-rendering>)** — cited in `src/ascii.cyr` and
  [ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md). kii uses a 6-region (2×3)
  variant; the Euclidean NN + Rec.709 luma are standard. Deferred from the blog:
  directional contrast enhancement + k-d-tree lookup (tracked).

## [1.3.0] — 2026-06-26

**Character-glyph ASCII mode (`--mode ascii`).** A second rendering lane beside
the half-block default — kii's `jp2a` / namesake "ASCII art" lane: render the
image as text glyphs chosen by luminance, drawn in each cell's quantized color.
The two modes share the whole decode → downscale → quantize front and fork only
at emit. The default (half-block) is **byte-identical** (RAMGON + all color-type
goldens unchanged). See [ADR 0007](docs/adr/0007-rendering-mode-taxonomy.md).

### Added
- **`--mode {halfblock|ascii}`** (`-m`), default `halfblock`. `ascii` maps each
  downscaled cell to a density ramp `" .:-=+*#%@"` by Rec.709 relative luminance
  (`0.2126/0.7152/0.0722`, integer 54/183/19 ÷256 — W3C/Wikipedia standard), and
  colors the glyph with the cell's 16-color foreground. One cell per character
  (vs half-block's two stacked rows), so the source is downscaled to half the
  rows — keeping aspect right in the terminal's ~2:1 cells.
- `src/ascii.cyr`: `_ascii_luma` / `_ascii_glyph` / `emit_ascii_row_buf` (buffer
  variant, testable) / `emit_ascii`. Per-row buffer is heap-allocated and sized
  from the width (no fixed-stack overflow — the v1.2.1 lesson).
- `tests/ascii.tcyr` (luma, glyph, exact row bytes, emit guards) + `--mode`
  validation in `tests/cli.tcyr`.

### Deferred (tracked)
- The **advanced shape-vector glyph matching** (Alex Harri's blog — edge-aware
  `/ \ | -` via per-cell coverage vectors + contrast) is a follow-up; it needs
  glyph-coverage data and would be **attributed**. The luminance ramp is the
  complete, dependency-free floor. See `docs/development/roadmap.md` § Post-v1.

## [1.2.2] — 2026-06-26

**Full PNG matrix via chitra 0.2.1.** Re-pins `[deps.chitra]` `0.2.0` → `0.2.1`,
which completed the PNG bit-depth/interlace matrix. kii now **renders PNGs it
previously rejected** — sub-byte bit depths 1/2/4 (grayscale + palette) and Adam7
interlace — at zero code cost: the adapter is format-agnostic (chitra normalizes
everything to RGBA8, written into the pstruct as ct6), so the depth-8/16
non-interlaced path stays **byte-identical** (RAMGON + all 5 color-type golden
frames unchanged).

### Changed
- `[deps.chitra]` tag `0.2.0` → `0.2.1` (`cyrius.cyml`); `print_version` → `kii 1.2.2`.
- Error messages corrected for the wider support surface: `PNG_ERR_BITDEPTH` →
  "unsupported bit depth for this color type (PNG § 11.2.2)" (1/2/4 are no longer
  rejected; only spec-illegal combos like ct2-at-sub-byte or ct3+depth16 are);
  `PNG_ERR_INTERLACE` → "unsupported interlace method" (Adam7 now decodes; only an
  invalid interlace byte ≥2 is rejected).

### Added
- `tests/decode.tcyr`: capability tests that a sub-byte (gray depth-2) and an Adam7
  interlaced PNG now decode to `PNG_OK` (were `PNG_ERR_BITDEPTH` / `PNG_ERR_INTERLACE`),
  with the adapter forcing ct6 and `SRC_COLOR_TYPE` carrying the real source format.
  Verified end-to-end: a kii-rendered interlaced frame equals the non-interlaced frame.

## [1.2.1] — 2026-06-26

**Fix: `emit_halfblock` per-row buffer overflow at large `--width`.** A pre-existing
bug (in the M6 `--width` feature, unrelated to the v1.2.0 re-fold), surfaced by the
re-fold's adversarial review.

### Fixed
- `src/emit.cyr`: the per-row scratch was a fixed `var line_buf[2048]` — 2048 **bytes**
  at function scope, sized for an 80-column row. Each emitted cell is up to 25 bytes
  (256-color FG + BG escapes + a 3-byte half-block glyph), so a row wider than ~89
  cells overran the buffer; `kii --width 200 image.png` wrote ~4 KB/row into 2 KB of
  stack, clobbering adjacent stack memory (the output looked correct only because the
  same `write(2)` read the contiguous overflow back). Now the scratch is heap-allocated
  and sized from the actual width (`sw * 26 + 16`); an absurd width fails the alloc and
  returns cleanly instead of smashing the stack. **Output is byte-identical** for all
  widths (verified against v1.2.0 golden frames incl. `--width 200`).

## [1.2.0] — 2026-06-26

**The PNG re-fold: kii adopts the `chitra` distlib and deletes its own decoder.**
The 813-line native PNG decoder (`src/png.cyr`) was forked into the sibling `chitra`
package so mabda could consume it; at **chitra 0.2.0** that fork became a strict
SUPERSET of kii's decoder (16-bit depth + every M7(c)/M8 security guard backported).
kii now consumes it back — the same extract-on-2nd-consumer move kii made for CLI
parsing with `cmdit` at v1.1.0. **Output frames are byte-identical** to the native
decoder across all widths (RAMGON.png golden-frame diff: identical at 40/80/120/200 +
default + `--verbose` stderr), and **16-bit support is preserved** (chitra reads the
high byte, exactly as kii's downscale/quant did). See [ADR 0006](docs/adr/0006-adopt-chitra-decoder.md).

### Changed
- **`[deps.chitra]` added** (`git` + `path=../chitra` + `tag="0.2.0"`,
  `modules=["dist/chitra.cyr"]`). stdlib `sankoch` + `thread` STAY — chitra's
  strip-include dist resolves `zlib_decompress`/`crc32`/`mutex` from kii's stdlib list,
  and kii's tests call `zlib_decompress` directly.
- **`src/png.cyr` trimmed from 813 lines to a thin chitra adapter**: keeps the
  `PNG_ERR_*` code space + `STRUCT_*_OFFSET` pstruct contract + `_png_color_channels` +
  `png_color_type_name`, and adds `kii_decode_png(path, &pstruct)` (file-slurp →
  `chitra_png_decode` → RGBA8 written into the pstruct as a depth-8 `color_type=6`
  image, so `downscale`/`quant`/`emit` are untouched) plus a `ChitraErr`→`PNG_ERR_*`
  mapping. Deleted the signature/IHDR/CRC32/chunk-walk/PLTE/inflate/unfilter bodies
  and the M7(c) IHDR/ratio/IDAT caps (all now enforced inside chitra).
- **`src/main.cyr`**: the two-call decode (`png_decode_structure` + `png_decode_pixels`)
  + ~22 error branches collapse to one `kii_decode_png` call + a compact mapped-error
  ladder. Missing-IEND still emits the frame + stderr warning + exit 0 (via
  `chitra_image_seen_iend`); `--verbose` reports the source color_type (via
  `chitra_image_source_color_type`), so it stays byte-identical.
- **New DoS guard**: `kii_decode_png` rejects an input file larger than 256 MB
  (`PNG_ERR_FILE_TOO_LARGE`) before the slurp — the in-memory boundary holds the whole
  file, which the old streaming reader didn't. Exact-`fstat`-sized alloc (via
  `lseek(SEEK_END)`), no 256 MB overcommit.
- **Test suite split** from the 1941-line monolithic `tests/kii.tcyr` into focused
  standalone files (`tests/cli.tcyr`, `tests/quant.tcyr`, `tests/render.tcyr`,
  `tests/decode.tcyr`), matching chitra's `tests/tcyr/*.tcyr` convention. Decoder-internal
  assertions retired to chitra (322 assertions there); kii keeps the CLI / palette /
  quant / downscale / emit / geometry / path-sanitizer surface and adds `kii_decode_png`
  e2e + `ChitraErr`-mapping + adapter coverage. Fuzz (`tests/kii.fcyr`) + bench
  (`tests/kii.bcyr`) PNG surfaces re-aimed through `kii_decode_png`.
- **Removed** the dead `quantize_nearest_image` (its per-color_type extraction read
  native pstruct fields that no longer exist post-flip).

### Accepted diagnostic deltas (documented in ADR 0006; security guards all intact)
- A `<8`-byte file reports `not a PNG` (chitra's signature check), so the dedicated
  "shorter than 8 bytes" message is unreachable (`PNG_ERR_TRUNCATED` reserved).
- The decompression-ratio bomb cap reports `dimensions exceed ceiling`
  (`CHITRA_ERR_DIMENSIONS`) rather than a distinct ratio code (`PNG_ERR_RATIO_TOO_HIGH`
  reserved); the guard fires identically.
- A corrupt palette index is a hard reject (chitra `BAD_CHUNK` → `malformed PNG`) rather
  than the old graceful map-to-black. Stricter; affects corrupt input only.

## [1.1.2] — 2026-06-26

**Toolchain + dep refresh.** Maintenance release. No functional change: the PNG →
terminal-ANSI pipeline is byte-identical and tests stay green.

### Changed
- **cyrius toolchain pin `6.2.36` → `6.2.44`** (`cyrius.cyml [package].cyrius`); `lib/`
  re-vendored from the 6.2.44 stdlib snapshot via `cyrius deps` (no hand-edits).
- **darshana** (`cyrius.cyml [deps.darshana]`): `0.8.0` → `0.8.1`. `[deps.cmdit]` stays at
  `1.1.0`.
- `print_version` literal → `kii 1.1.2`.

## [1.1.1] - 2026-06-25

**cmdit pin advance.** Bumps the `[deps.cmdit]` pin `0.1.0` → **`1.1.0`** — cmdit froze
its public API at 1.0.0 and 1.1.0 added `cmdit_help_flags`, both backward-compatible
supersets of the 0.1.0 surface kii consumes. No functional change: **468/468** tests
green and rendering byte-identical against cmdit 1.1.0.

### Changed
- `[deps.cmdit]` tag `0.1.0` → `1.1.0` (`cyrius.cyml`); `print_version` literal → `kii 1.1.1`.

## [1.1.0] - 2026-06-25

**CLI parsing adopts cmdit (the re-fold).** kii's flag-set seeded cmdit's design (the
2026-06-25 ecosystem CLI review); adopting cmdit back is its first consumer and validates
the extraction.

### Changed
- **Dropped the hand-rolled CLI on stdlib `flags` for the `[deps.cmdit]` distlib.**
  `kii_register_flags` registers via `cmdit_int`/`cmdit_bool`; `main` parses via
  `cmdit_parse` (which owns `args_init` + the argc/argv→`cstr*` materialize bridge),
  dispatches on `CMDIT_HELP`/`CMDIT_VERSION`/`CMDIT_RESULT_ERR`, and reads values via
  `cmdit_get_*`/`cmdit_positional`. Removed `build_argv_array` and the self-imposed
  `KII_ARGV_MAX` argv cap (cmdit materializes dynamically).
- `--help`/`--version` are now auto-registered by `cmdit_new` (kii no longer tracks their
  flag indices). The `--help` flag list is now cmdit-generated; kii keeps its banner +
  Examples around it.
- Stdlib deps: dropped `flags` (kept `args` — cmdit's materialize bridge needs it).

### Notes
- Behavior preserved: flag parsing, error codes, `0/1/2` exit codes, and rendering are
  unchanged; only the `--help` text layout shifts to cmdit's generated form.
- Tests (`tests/kii.tcyr`, `tests/kii.fcyr`) rewired to the cmdit API + return-code model.

## [1.0.3] — 2026-06-22

### Changed

- **cyrius toolchain pin `6.2.22` → `6.2.36`** — aligns with the latest cyrius (6.2.31–6.2.36
  agnos-stdlib fixes). Host + `--agnos` builds re-verified clean. No source change.

## [1.0.2] — 2026-06-22

### Added — real console sizing on AGNOS (winsize#60 / darshana 0.8.0)

- **Drop the agnos `tty_winsize` gate** (`src/main.cyr`): the `#ifndef CYRIUS_TARGET_AGNOS`
  guard around the `tty_winsize(1, …)` detection is removed. agnos now provides
  `tty_winsize` via the **`winsize`#60** syscall (agnos kernel 1.45.13) consumed through
  **darshana 0.8.0**'s `CYRIUS_TARGET_AGNOS` branch, so kii sizes its ASCII-art output to
  the real framebuffer console grid instead of the 80×24 `EMIT_DEFAULT_*` fallback. The
  old gate's `kill`#16 number-collision rationale is obsolete (the agnos branch calls
  `winsize`#60 directly, never `ioctl`). The 80×24 default remains as the failure path
  (FB not up → -1). `[deps.darshana]` 0.7.1 → 0.8.0.

### Changed — agnos-readiness port (2026-06-12)

Source-level work to make kii build/run on the AGNOS target (`CYRIUS_TARGET_AGNOS`),
matching the established agnos-tool pattern (anuenue/owl/kriya/bnrmr). **Host build
unaffected** (`cyrius build src/main.cyr build/kii` → clean, 258 KB).

- **Entry point** (`src/main.cyr`): `var r = main();` → a bare `_agnos_entry()`
  top-level call. On agnos a module-scope `var = main()` runs `main` during
  gvar-init *before* cycc's init-rsp capture, so `argc()`/`argv()` would read
  0/null and kii would see no image path. The bare statement runs in `PARSE_PROG`,
  after the capture. `SYS_EXIT` (already used) is correct on both targets.
- **Terminal size** (`src/main.cyr`): `tty_winsize` (darshana, `ioctl TIOCGWINSZ`)
  is now gated behind `#ifndef CYRIUS_TARGET_AGNOS`. agnos has no `ioctl` syscall
  (num 16 is `kill`); leaving the call in would invoke `kill(pid=1, sig=TIOCGWINSZ)`
  by number-collision (returns −1 by luck since sig≥64). On agnos kii uses the
  EMIT_DEFAULT 80×24 fit. A real FB-console window-size syscall is slotted for
  **agnos 1.45.x** (FB px ÷ glyph dims → char grid; drops this fallback).
- **Toolchain pin** (`cyrius.cyml`): `6.0.1` → `6.1.14` + re-vendored `lib/` (gets
  the `fnptr.cyr` `CYRIUS_TARGET_AGNOS` fncall branch — without it `alloc_via`/
  `vec_new` return 0 on agnos → null-backed vecs → crash; the owl/kriya class).

**BLOCKED — agnos build does not yet link** (`cyrius build --agnos` →
`lib/mmap.cyr: undefined variable 'CLONE_VM'`). Not a kii bug: sankoch's PNG
zlib path calls `_sankoch_lock`/`_unlock` → `mutex_lock` → the Linux clone-based
`thread`/`mmap` stdlib (`CLONE_VM`), which has no agnos branch (agnos userland is
single-threaded). kii is the first agnos consumer of sankoch. Tracked upstream:
`cyrius/docs/development/issues/2026-06-12-sankoch-locks-not-agnos-compatible.md`
(recommended fix: no-op the sankoch locks under `CYRIUS_TARGET_AGNOS`). The agnos
build completes once that lands; the kii source above is ready.

## [1.0.1] — 2026-06-18

### Changed — toolchain + dependency refresh

Maintenance release. No user-facing behavior change; the PNG → terminal-ANSI
pipeline is byte-identical (471 assertions pass unchanged).

- **Toolchain pin** (`cyrius.cyml`): `6.1.14` → `6.2.22`. `lib/` removed and
  re-vendored from the 6.2.22 stdlib snapshot (`cyrius lib sync` → 98 `.cyr`
  files) so the vendored stdlib tracks the new pin exactly.
- **darshana** (`cyrius.cyml [deps.darshana]`): `0.5.3` → `0.7.1`. kii's emit
  layer still uses `tty_fg_256_buf` + `tty_winsize` (both present in 0.7.1); the
  BG-256 twin is still absent from darshana's surface, so the inline
  `_emit_bg_256_buf` stays. `cyrius.lock` re-locked (99 deps).
- **Version string** (`src/main.cyr`): `print_version` → `kii 1.0.1`.

> Note: `cyrius deps --verify` under 6.2.22 mis-parses the final `cyrius.lock`
> entry (`lib/result.cyr` → reported as `lib/resu`, "cannot hash"). The lockfile
> is correct — the file's sha256 matches byte-for-byte — so this is a cosmetic
> toolchain-side parser quirk on the trailing line, not a kii integrity issue.

## [1.0.0] — 2026-05-23

### v1.0 freeze cycle (M8)

The freeze ships kii at v1.0 with the production PNG → terminal-ANSI pipeline locked in, all ADRs written, the security model committed (per ADR 0002), and the W3C PNG test-suite walked. Consumer integration is OFF the v1.0 acceptance set — BBS / MUD apps are downstream cycles, not v1.0 blockers.

### Added

- **`tests/fixtures/`** directory — RAMGON.png moved from top level (`git mv`); references in `kii.tcyr` / `kii.fcyr` / `kii.bcyr` updated to `tests/fixtures/RAMGON.png`. Sets up the curated-fixtures dir per M8 acceptance.
- **Per-chunk-type length cap** (`src/png.cyr`) — IEND must be exactly 0 bytes per PNG spec § 11.2.5; any chunk exceeding the absolute 256 MB ceiling rejected as `PNG_ERR_HEADER`. Closes the audit-doc Finding 6 (libpng CVE-2017-12652 class). +1 test assertion (471 total).
- **`docs/adr/0003-color-tier-discipline.md`** — captures the tier-1 (8/16-color) v1.0 scope rationale; tier-2 / tier-3 deferral.
- **`docs/adr/0004-half-block-floor-glyph.md`** — captures the `▀`/`▄` glyph-pair-as-floor choice; quarter-blocks + braille post-v1 rationale.
- **`docs/adr/0005-nearest-neighbor-downscale.md`** — captures the nearest-neighbor algorithm choice; bilinear/Lanczos defer to tier-2 alongside dithering.
- **`docs/guides/getting-started.md`** backfilled — first runnable user guide (overdue since M5). Install / first render / CLI surface / common pipelines / error reference / deferred-features list / where-to-next.
- **`docs/examples/`** populated with three runnable transcripts:
  - `01-ramgon-fixed-width/` — happy path, RGBA color_type=6
  - `02-archlinux-logo-palette/` — palette color_type=3 code path
  - `03-not-a-png-rejection/` — error-path diagnostic + exit code
- **W3C PngSuite walk** appended to `docs/audit/2026-05-22-audit.md` § Appendix A. Results: **14/14 broken-set PNGs rejected cleanly with explicit diagnostics; 82/162 valid-set PNGs decoded OK; remaining 80 rejected as deferred features (45 sub-byte depths + 35 Adam7 interlaced). Zero crashes, zero hangs, zero silent corruptions.**
- **chafa visual review** (M8(b3)) — once chafa was installed mid-cycle. Curated 6-fixture comparison (PngSuite basics + RAMGON + archlinux-logo + starfield) in `docs/audit/chafa-comparison.md`. **kii is 5.9×–69× bytewise larger than chafa** for equivalent visual content — direct consequence of the per-cell byte-stable encoding (ADR 0003) + half-block-only glyph vocab (ADR 0004) + 256-color SGR over compact SGR-30-37. Validates the kii design tradeoffs against chafa as reference impl; closes the v1.0 acceptance criterion.
- **`tests/fixtures/visual-review/`** dir with 3 W3C PngSuite basic-set PNGs (RGB / palette / RGBA) for the comparison.

### Changed

- `print_version` literal bumped to `kii 1.0.0`.
- `README.md` example invocation updated to `kii tests/fixtures/RAMGON.png`.
- `docs/development/state.md` refreshed with v1.0 snapshot.

### Deferred to v1.x (not v1.0 blockers)

- **First BBS / MUD consumer integration** — those apps are downstream cycles (only ideated, not built); v1.0 ships as substrate.
- **Cross-terminal verification** (Linux console / xterm / Alacritty / kitty / tmux) — needs human eyes per terminal. v1.0 ships byte-stable; downstream verification can land any time.
- **Marketplace recipe in zugot** — depends on zugot tooling; v1.x.
- **Three sankoch upstream items** filed during the M7 audit (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers) remain open — kii's pre-inflate caps cover the impact, but sankoch-internal Huffman-table-construction validation is the proper fix.

### Deps

- No deltas. `darshana 0.5.3` and stdlib unchanged.

## [0.8.0] — 2026-05-23

### Security

- **M7 audit cycle** (see [`docs/audit/2026-05-22-audit.md`](docs/audit/2026-05-22-audit.md)). External research across libpng / lodepng / stb_image / zlib / terminal-emulator CVE corpora (140 CVE/issue rows walked) compiled into a kii-specific findings doc with 10 prioritized items. Hardening commits C1–C4 land below.
- **C1 — stderr ANSI-injection defense**. `kii_path_has_control_bytes(path)` predicate in `src/cli.cyr` + `_eprint_path_safe` helper in `src/main.cyr`. Filenames containing C0 controls (0x00–0x1F except `\t`/`\n`) or DEL (0x7F) are substituted with `<path containing control bytes — suppressed>` before stderr emit. UTF-8 paths pass through (AGNOS naming surface). Closes the CVE-2021-25743-analog exposure on `_eprint_path_msg` / `_eprint_quant_summary`.
- **C2 — IHDR dimension caps + PNG spec § 11.2.2 enforcement**. New `KII_MAX_PIXELS = 4096²`, `KII_MAX_DIM = 65535/side`, `KII_MAX_RAW_BYTES = 256 MB` ceilings checked at `png_decode_pixels` entry. Lying-IHDR zip-bomb (e.g. 65535×65535×RGBA-16bit → 34 GB alloc attempt) rejected with new `PNG_ERR_DIMENSIONS`. PNG spec § 11.2.2 Table 11.1 cross-product enforced: `color_type=3 + bit_depth=16` (spec-illegal; stb #1928 Bug 6 class) rejected with `PNG_ERR_BITDEPTH`.
- **C3 — Decompression-amplification caps**. `idat_total > 256 MB` rejected with new `PNG_ERR_IDAT_TOO_LARGE` (stb OSS-Fuzz #32803 / #1928 Bug 7 / lodepng #165 class). Compression-ratio > 1100:1 (above DEFLATE's 1032:1 theoretical max per RFC 1951 § 3.2.5) rejected with new `PNG_ERR_RATIO_TOO_HIGH` — first-line defense against zip-bombs before any sankoch inflate.
- **C4 — Chunk-ordering FSM (partial)**. Duplicate PLTE chunks (PNG spec § 5.6 violation; alloc-leak in previous code) and PLTE-after-IDAT rejected with `PNG_ERR_HEADER` in the structural walker.
- **ADR 0002** ([`docs/adr/0002-security-model.md`](docs/adr/0002-security-model.md)) captures the threat model + commitments + accepted residual risks. Cross-references the audit doc + SECURITY.md.

### Added

- **M7(b) fuzz coverage** — `tests/kii.fcyr` scaled from 12k iters total to **3,011,000 iters** across five surfaces, all clean in ~16.4 s wall-clock:
  - `arg-parser` (10k, unchanged)
  - `path-sanitizer` (**1M new**) — random byte paths through `kii_path_has_control_bytes`
  - `geometry` (**1M new**) — random src/envelope dims through `_kii_compute_target_geometry` + `_kii_compute_fit_geometry`
  - `emit-pipeline` (**1k new**) — decode-once-then-randomize-target-dims on RAMGON.png through `downscale_to_rgb` → `quantize_downscaled` → `emit_halfblock_row_buf`
  - `png-decoder` (**scaled 2k → 1M**) — random bytes (50% prefixed with valid sig+IHDR) through `png_decode_structure`
- **M7(d) decode-latency matrix** at three source-resolution classes — captured in [`docs/benchmarks.md`](docs/benchmarks.md): `archlinux-logo.png` 256×256 (1.8 ms), `starfield.png` 1597×1198 (647 ms), `elarun background.png` 2560×1600 (474 ms). Surprise: per-pixel decode throughput is content-dependent (compression-ratio-driven), not strictly size-dependent — the 2048² class is faster than the 1024² class because its source compresses tighter.
- **44 new unit-test assertions** covering each new error path, cap boundary, and predicate behavior. Total: 470 assertions, all pass.
- 3 new `PNG_ERR_*` codes (`DIMENSIONS = 12`, `IDAT_TOO_LARGE = 13`, `RATIO_TOO_HIGH = 14`) with matching `main.cyr` dispatch entries.

### Changed

- `print_version` literal bumped to `kii 0.8.0`.
- `_eprint_path_msg` + `_eprint_quant_summary` now route path bytes through `_eprint_path_safe` (and thence `kii_path_has_control_bytes`) before stderr emit.
- Audit doc Finding 5 (palette-index OOB) marked OK rather than DEFER after code re-read confirmed both PLTE-lookup sites (`downscale.cyr:73`, `quant.cyr:129`) already bounds-check and substitute black on OOB.
- Audit doc Finding 2 (IDAT-accumulator cap) reformulated to absolute `KII_MAX_RAW_BYTES` ceiling rather than the doc's initial relative `1.5 × inflated_size` cap — relative cap failed on tiny inflated payloads where constant zlib/DEFLATE header overhead exceeds the multiplier.

### Deferred to M8

- Per-chunk-type length cap table (libpng CVE-2017-12652 class) — IDAT cumulative cap from C3 covers the OOM-DoS leverage; per-chunk caps for IHDR / IEND would catch trivially malformed inputs at slightly earlier signal, but CRC32 already fires there. Net value marginal.
- W3C PNG test-suite "broken" set walk — would need download + automation; deferred to M8 alongside cross-terminal verification.
- Three sankoch upstream items (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers, Huffman-table-construction surface). kii's pre-inflate caps reduce impact; sankoch fixes tracked as v1.0 release gate.

### Deps

- No deltas. `darshana 0.5.3` and stdlib (incl. sankoch) unchanged.

## [0.7.0] — 2026-05-22

### Added

- **M6 — terminal-size auto-detect + `--width N` override**. `kii image.png` now fills the current terminal aspect-preservingly: stdout-TTY → `tty_winsize(1)`-detected `cols × (rows - 1)`; non-TTY → 80×24 BBS-default fallback. `--width N` (M1-frozen flag, finally consumed) honors the exact width without any row cap — useful for `kii --width 200 img.png > big.ansi` captures.
- **`src/emit.cyr` extensions**:
  - `_kii_compute_target_geometry(src_w, src_h, width_flag, out_dst_w, out_dst_src_rows)` — width-driven aspect-preserving height (used when `--width` is explicit). Formula: `dst_src_h = (src_h × dst_cols) / src_w`, clamped to ≥ 2 (1 terminal row min).
  - `_kii_compute_fit_geometry(src_w, src_h, max_cols, max_rows, out_dst_w, out_dst_src_rows)` — aspect-preserving FIT into a (cols × rows) envelope. Picks width-binding when the aspect-true height fits inside `max_rows`; otherwise switches to row-binding and shrinks the width accordingly. `max_cols ≤ 0` / `max_rows ≤ 0` substitute `EMIT_DEFAULT_COLS` (80) / `EMIT_DEFAULT_ROWS` (24).
- **`src/main.cyr`**: terminal-size detection via darshana's `tty_winsize(1, &rows, &cols)`. Two-path resolver:
  - `--width N > 0` → M6(a) `_kii_compute_target_geometry` (no row cap; user knows what they're doing).
  - `--width 0` (default) → `tty_winsize` succeeds → fit-within `cols × (rows - 1)`; failure → fit-within 80×24.

### Changed

- `src/emit.cyr`: `EMIT_COLS` / `EMIT_ROWS` / `EMIT_SRC_ROWS` (module-scope mutable) → `EMIT_DEFAULT_COLS` / `EMIT_DEFAULT_ROWS` (immutable fallbacks). `EMIT_SRC_ROWS` removed (callers compute `2 × rows` where needed).
- `src/main.cyr`: pipeline replaces the hardcoded `downscale_to_rgb(&pstruct, 80, 48)` with `downscale_to_rgb(&pstruct, target_w, target_src_rows)` where `target_*` come from the M6 resolver above. The downstream `quantize_downscaled` + `emit_halfblock` already read `STRUCT_DOWNSCALED_W/_H` from pstruct, so they pick up the new dimensions without code changes.
- `print_version` literal bumped to `kii 0.7.0`.
- `cyrius.cyml [deps.darshana] tag = "0.5.3"` unchanged — M6 uses the already-pinned `tty_winsize` (darshana v0.3.0).

### Tests

- `tests/kii.tcyr` — **426 assertions** (was 382 at v0.6.0).
  - **M6(a) target-geometry** (24): RAMGON 1152×925 at widths 40 / 80 / 120 produce the expected aspect-true heights; `width=0` falls back to 80-col default; square / wide-landscape / tall-portrait synthetic shapes pin the formula; 800×1 degenerate clamps to ≥ 1 terminal row; invalid source dims return -1.
  - **M6(b) fit-geometry** (17): width-binding case (1000×100 in 120×40 → 120×6 term, dst_src_rows=12); row-binding case (RAMGON in 120×40 → 99×40 term); square 100×100 in 80×24 → 48×24 row-binds; zero-envelope falls back to (80, 24); single-pixel src clamps; invalid src dims return -1.

### Bench

- `quantize_nearest_rgb @ 1024×1024`: **269 ns/op** (unchanged from v0.6.0).
- **`end-to-end RAMGON.png → 80×24 frame`: 761 ms/iter** (50 iters; ~1 ms slower than v0.6.0's 747 ms — measurement noise, well under the resolution we have to begin with).
- **`end-to-end RAMGON.png → 120×40 frame`: 769 ms/iter** (30 iters).
- **`end-to-end RAMGON.png → 200×60 frame`: 771 ms/iter** (20 iters).

Render cell-count (1920 / 4800 / 12000) climbs 6.25× from 80×24 to 200×60, but the M5 emit + downscale + quantize-of-downscaled-buf are sub-millisecond — the entire bench is dominated by `png_decode_pixels` on RAMGON's 4.26 MB inflated buffer (~98 % share).

### Docs

- `docs/adr/0001-png-decoder-in-repo.md` — first ADR, captures the M3-era decision to keep the PNG decoder in-repo until a 2nd consumer surfaces. Carried forward from M3 → M4 → M5 → M6; finally lands.
- `docs/architecture/README.md` — backfilled. Module map + six numbered items: (1) pstruct byte-offset layout invariants, (2) half-block aspect math gotcha (src-rows vs term-rows), (3) pipe-purity and stdout discipline, (4) darshana dep + BG-256 inline copy rationale, (5) why `quantize_nearest_image` stays after M5 superseded it, (6) the 80×24 BBS-default non-TTY fallback. Carried M2 → M5; finally lands.
- `docs/benchmarks.md` — `## v0.7.0` section added.
- `docs/development/{state.md, roadmap.md}` + `docs/doc-health.md` — refreshed per release.

### Real-world smoke

- `kii RAMGON.png` in a 200×60 terminal renders ~200×40 (row-binding from RAMGON's aspect).
- `kii RAMGON.png > out.ansi` → exactly 80 cells wide × 24 rows tall (non-TTY 80×24 fallback).
- `kii --width 60 RAMGON.png` → 60 ▀ glyphs per row × 24 rows.
- `kii --width 200 RAMGON.png` → 200 ▀ glyphs per row × 80 rows (aspect-true, no row cap on explicit --width).

### Out of scope (deferred per M6 acceptance)

- **Visual review against `chafa --colors 16 --size 80x24`** on a curated 5-image set — carried from M5 again; the geometry is stable now, but a `chafa` install + curated fixtures is M7-audit work.
- **SIGWINCH-driven live re-render** — kii is one-frame-in-one-frame-out per `CLAUDE.md` § domain rules; interactive resize would be a v2 scope expansion. Captured here so the next contributor doesn't try to add it.
- **`tty_winsize` on stderr / explicit fd choice** — kii detects on fd 1 (stdout). A future `--detect-tty stderr` would be useful for `kii img.png | tee out.ansi` (where stdout is the pipe but stderr is the terminal) but no consumer has asked yet.

## [0.6.0] — 2026-05-22

### Added

- **M5 — half-block (`▀`) ANSI emit + per-row 256-color escapes**. `kii image.png` now reads a PNG, decodes it, downscales to 80×48 RGB triples (nearest-neighbor), quantizes to 16-color palette indices, and emits half-block glyphs to **stdout** sized to a hardcoded 80×24 — the first user-visible terminal output. Pipe-pure (`kii img.png > frame.ansi` captures just the frame). Per-character format: `\x1b[38;5;<fg>m\x1b[48;5;<bg>m▀` (top half = FG, bottom half = BG); `\x1b[0m\n` per row.
- **`src/downscale.cyr`** — new module. Nearest-neighbor RGB resampler. `downscale_to_rgb(pstruct, dst_w, dst_h)` walks each dst pixel, computes `sx = (dx × src_w) / dst_w` (integer truncation), and writes a packed RGB triple at the source `(sx, sy)` per the color_type. Per-color_type extraction (`_extract_rgb`) handles greyscale broadcast / RGB pass-through / PLTE expansion / alpha-drop / 16-bit-depth truncation in one place. Output: `STRUCT_DOWNSCALED_BUF` + `_W` + `_H`.
- **`src/emit.cyr`** — new module. Half-block emit layer.
  - `_emit_bg_256_buf(buf, pos, n)` — CSI `48;5;Nm` byte-pack (darshana's BG-256 twin not yet shipped; extract on 2nd consumer per the AGNOS pattern).
  - `emit_halfblock_row_buf(qbuf, sw, row, buf, pos)` — buffer-targeting variant; unit-testable without subprocessing stdout.
  - `emit_halfblock(pstruct)` — fd-1 wrapper, one `write(2)` per terminal row (~2 KB each, 24 writes per frame).
- **`src/quant.cyr` extensions**:
  - `quantize_rgb_buf(rgb_buf, n_pixels, out_buf)` — PNG-agnostic RGB-triple → palette-index transform. Reusable for future animated-frame / multi-format consumers.
  - `quantize_downscaled(pstruct)` — struct-aware wrapper that allocs `dw × dh` bytes, calls `quantize_rgb_buf`, stores into `STRUCT_QUANTIZED_BUF/_SIZE`. The M5+ pipeline replacement for `quantize_nearest_image`; the older fn stays for M4-test backward compat.
- **`src/png.cyr` extensions**: struct grew from 15 to 18 slots (160 bytes): `STRUCT_DOWNSCALED_BUF_OFFSET` (120) + `_W_OFFSET` (128) + `_H_OFFSET` (136).
- **`src/cli.cyr`**: activated `--verbose` / `-v` (was reserved in M1's flag indices). With the frame now on stdout, the M4 `<path>: <W>x<H> N pixels … → 16-color` summary moves behind this flag and rides stderr.
- **`darshana` 0.5.3 added to `cyrius.cyml [deps.darshana]`** — first external git dep. Provides `tty_fg_256_buf` (foreground CSI 38;5;Nm) + `tty_sgr_reset_buf` (CSI 0m for buffer composition). The BG twin lives in `src/emit.cyr` locally; extracts to darshana when a 2nd consumer surfaces.

### Changed

- `src/main.cyr`:
  - Pipeline restructured: `png_decode_structure` → `png_decode_pixels` → `downscale_to_rgb(80, 48)` → `quantize_downscaled` → `emit_halfblock`. Three new error paths (downscale / quantize / emit failures) each with a distinct stderr line.
  - `_print_quant_summary` → `_eprint_quant_summary` (now writes the M4-shape summary to stderr, gated behind `--verbose`).
  - `print_usage` Examples list updated: replaced "render to terminal (M5+)" placeholder with concrete 80×24 + `--verbose` + capture examples.
  - `var pstruct[128]` → `var pstruct[160]` to cover the 20-slot M5(b)-extended layout.
- `print_version` literal bumped to `kii 0.6.0`.

### Tests

- `tests/kii.tcyr` — **382 assertions** (was 287 at v0.5.0).
  - **M5(b) downscale** (38): identity 2×2 → 2×2 byte-identical; 2×2 → 4×4 nearest replicate (every quadrant covers source pixel); 2×2 → 1×1 top-left wins; rejects ungated calls + `dst_w <= 0`; RAMGON 1152×925 → 80×48 (11,520 bytes, non-zero); palette-PNG (archlinux-logo.png) per-color_type normalization.
  - **M5(c) emit** (57): `quantize_rgb_buf` 4-pixel canonical (red→1, blue→4, black→0, white→15); `quantize_downscaled` end-to-end + ungated reject; `_emit_bg_256_buf` exact byte sequences for 1/2/3-digit indices + bounds reject; `emit_halfblock_row_buf` exact byte layout for single-char (26 bytes), 2-col checkerboard (49 bytes), 4-col solid (89 bytes); `emit_halfblock` rejects ungated calls + odd source height + zero width.

### Bench

- `quantize_nearest_rgb @ 1024×1024`: **269 ns/op** (re-measured; ~5 ns noise vs the 274 at v0.5.0).
- **`end-to-end RAMGON.png → 80×24 frame`: 747 ms/iter** (50 iters; full pipeline including PNG decode + downscale + quantize + 24 in-process row builds). Dominated by `png_decode_pixels` on the 4.26 MB inflated RGBA buffer (~98 % share).

### Real-world smoke

- `RAMGON.png` (1152×925 RGBA) → 40,770 bytes of ANSI on stdout, exit 0. `--verbose` adds the M4-shape summary line on stderr.
- `/usr/share/pixmaps/archlinux-logo.png` (256×256 palette via PLTE) → renders cleanly.
- `/usr/share/pixmaps/kitty.png` (256×256 RGBA) → renders cleanly.

### Out of scope (deferred per M5 acceptance)

- **Bilinear / Lanczos downscale** — nearest-neighbor is the tier-1 floor; perceptually-better filters land in post-v1 alongside dithering.
- **Terminal-size detection** — hardcoded 80×24 at v0.6.0; `ioctl TIOCGWINSZ` is M6 / v0.7.0 work.
- **Visual review against `chafa --colors 16`** — carried to M6 alongside the reproducible terminal-size story.
- **Render-a-real-checkerboard-PNG end-to-end** — in-process `emit_halfblock_row_buf` shape tests pin the emit contract; the fixture-PNG variant adds a checkerboard builder that's not strictly required for M5 acceptance.
- **`tty_bg_256_buf` extraction to darshana** — kept inline in `src/emit.cyr` until a second consumer surfaces.
- **Fuzz coverage for downscale / quantize / emit** — captured in `docs/doc-health.md` as M7-audit work; needs a valid-PNG-fixture-then-random-dst-dims surface.

## [0.5.0] — 2026-05-22

### Added

- **M4 — 16-color ANSI palette + RGB → nearest quantization**. Valid PNGs now quantize through the full pipeline and print `<path>: <W>x<H> <N> pixels (<color_type_name>) → 16-color` to stdout + exit 0. The arrow visually separates source format from quantization target.
- **`src/palette.cyr`** — Linux-console / CGA-derived 16-color ANSI palette. Module-scope `_ANSI_PALETTE_RGB[16]` packed-byte buffer + `palette_init()` (idempotent) + `palette_r(idx)` / `palette_g(idx)` / `palette_b(idx)` accessors with lazy-init defense. Entries 0–7 are normal (dim) CGA originals; 8–15 are bright. Source: Linux kernel `drivers/tty/vt/vt.c default_color_table`.
- **`src/quant.cyr`** — RGB → palette-index quantization.
  - `_color_dist2(r1, g1, b1, r2, g2, b2)` — squared Euclidean distance. Skips sqrt (monotonic for minimum-finding); max value 3 × 255² = 195,075 fits comfortably in i64.
  - `quantize_nearest_rgb(r, g, b)` — scalar per-pixel: linear scan over 16 palette entries, ties broken by lowest index.
  - `quantize_nearest_image(pstruct)` — image-wide: walks pixel buffer, dispatches per color_type (greyscale / RGB / palette via PLTE / grey+alpha / RGBA), drops alpha + low-bytes for depth=16 (truncation quantization — full-precision 16-bit is tier-2). Stashes 1-byte-per-pixel result in pstruct.
- **`src/png.cyr` extensions**:
  - PLTE chunk capture: walker now allocates a heap buffer + memcpy's PLTE bytes during the existing CRC-streaming pass. Spec § 11.2.3 validation: `chunk_len ≤ 768` AND `chunk_len % 3 == 0`, both → `PNG_ERR_HEADER`.
  - `_png_is_plte(type_buf)` chunk-type predicate.
  - Struct grew from 11 to 15 slots (120 bytes): `STRUCT_PLTE_BUF_OFFSET` (88) + `STRUCT_PLTE_SIZE_OFFSET` (96) + `STRUCT_QUANTIZED_BUF_OFFSET` (104) + `STRUCT_QUANTIZED_SIZE_OFFSET` (112).
- **`tests/kii.bcyr`** — wired. First kii benchmark: `quantize_nearest_rgb` at 1,048,576 iterations. **274 ns/op** on x86_64-linux; captured in [`docs/benchmarks.md`](docs/benchmarks.md). 1024×1024 full-image quantization extrapolates to ~287 ms.

### Changed

- `src/main.cyr`:
  - Wired `quantize_nearest_image` into dispatch after `png_decode_pixels`. Single new error path: `quantization failed (palette PNG missing PLTE, or OOM)`.
  - Replaced `_print_pixel_summary` (M3 shape: `decoded N pixels`) with `_print_quant_summary` (M4 shape: `N pixels (<name>) → 16-color`).
  - Added `_print` helper (stdout equivalent of `_eprint`) so the UTF-8 arrow in the success line doesn't need hand-counted byte widths.
  - `pstruct[96]` → `pstruct[128]` to cover the 16-slot M4(d)-extended layout.

### Tests

- `tests/kii.tcyr` — **287 assertions** (was 163 at v0.4.0).
  - **M4(a) palette** (51): size + lazy-init + every RGB entry 0–15 byte-pinned + bounds check that every byte ∈ [0, 255].
  - **M4(b) quantizer scalar** (37): all four acceptance-criteria pixels (red→1, blue→4, white→15, black→0) plus green/yellow/cyan/magenta + every palette entry round-trips to its own index + brightness gradient (luminance non-decreasing) + `_color_dist2` sanity.
  - **M4(c) PLTE capture** (21): 3-entry red/green/blue palette byte-for-byte verify + non-PLTE leaves nulls + malformed PLTE rejection (not multiple of 3, > 768 bytes) + real archlinux-logo.png PLTE invariants.
  - **M4(d) end-to-end** (15): 2x2 canonical RGB fixture quantizes to `[1, 4, 0, 15]` for red/blue/black/white; ungated-call rejection; archlinux-logo.png quantizes via PLTE (256×256 = 65,536 indices).

### Real-world smoke

- `RAMGON.png` (1152×925 RGBA) → `1,065,600 pixels (RGBA) → 16-color`.
- `/usr/share/pixmaps/archlinux-logo.png` (256×256 palette via PLTE) → `65,536 pixels (palette) → 16-color`.
- `/usr/share/pixmaps/kitty.png` (256×256 RGBA) → `65,536 pixels (RGBA) → 16-color`.

### Out of scope (deferred per M4 acceptance)

- **CIE Lab / perceptual color spaces** — Euclidean RGB is the tier-1 floor. Lab + perceptual metrics are post-v1 scope per CLAUDE.md color-tier discipline.
- **Dithering** (Floyd-Steinberg / ordered / Bayer) — explicitly tier-2 / post-v1.
- **Full-precision 16-bit-depth quantization** — current code truncates to high byte per channel. Full sampling lands when a consumer needs the fidelity.

## [0.4.0] — 2026-05-22

### Added

- **M3 — PNG pixel decode**. Valid PNGs now decode through the full DEFLATE → filter undo pipeline and print `<path>: <W>x<H> decoded <N> pixels (<color_type_name>)` to stdout + exit 0. The success line shape per the M3 acceptance contract; `<N>` is pixel count (W×H), `<color_type_name>` is one of `greyscale` / `RGB` / `palette` / `grey+alpha` / `RGBA`.
- **`sankoch` + `thread` added to `[deps].stdlib`** in `cyrius.cyml`. The `thread` add is a transitive dep (sankoch's `_sankoch_lock`/`_sankoch_unlock` wrap `mutex_lock`/`mutex_unlock` from `lib/thread.cyr`).
- **`src/png.cyr` extensions**:
  - 5 new error codes (7–11): `PNG_ERR_INTERLACE`, `PNG_ERR_BITDEPTH`, `PNG_ERR_NO_IDAT`, `PNG_ERR_INFLATE`, `PNG_ERR_FILTER`.
  - Struct grew from 7 to 11 slots (88 bytes): `STRUCT_INTERLACE_OFFSET` (56), `STRUCT_IDAT_BUF_OFFSET` (64), `STRUCT_PIXELS_BUF_OFFSET` (72), `STRUCT_PIXELS_SIZE_OFFSET` (80). Aligned at first four slots with `IHDR_*_OFFSET` so summary helpers work on either buf.
  - `_png_is_idat(type_buf)` + `_png_is_iend(type_buf)` chunk-type predicates (refactored the existing nested-if walker).
  - `_png_copy_idat(path, idat_buf, expected_total)` — phase-2 walker that re-opens the file, skips past sig + IHDR, walks chunks copying IDAT data directly into a pre-allocated buffer. No CRC re-validation (phase 1 already did it).
  - `_png_color_channels(color_type)` — color-type → channels-per-pixel mapping.
  - `png_color_type_name(color_type)` — color-type → short human-readable name.
  - `_png_paeth(a, b, c)` — spec § 9.4 Paeth predictor.
  - `_png_unfilter_row(prev, curr_in, out, row_bytes, bpp, filter_type)` — one-row filter undo for spec § 9 filter types 0 (None) / 1 (Sub) / 2 (Up) / 3 (Average) / 4 (Paeth). Returns -1 on unknown filter byte.
  - `png_decode_pixels(pstruct)` — top-level pixel decode: M3 rejection rules (Adam7 + sub-byte) → `zlib_decompress` IDAT into a height × (1 + row_bytes) buffer → row-by-row filter undo into a height × row_bytes pixel buffer → stash in struct.
  - `png_decode_structure` now captures the interlace byte + (when IDATs exist) allocates a contiguous IDAT buffer via the phase-2 walker.

### Changed

- `src/main.cyr`:
  - Wired `png_decode_pixels` into the dispatch after `png_decode_structure`. Five new error-path branches for the new `PNG_ERR_*` codes; each gets a distinct user-facing message.
  - Replaced `_print_ihdr_summary` (M2 structural shape) with `_print_pixel_summary` (M3 shape). Old helper deleted per no-dead-code rule.
  - `pstruct[64]` → `pstruct[96]` (struct grew by 4 slots between M2 and M3).
- `tests/kii.fcyr` — PNG fuzz harness now exercises the full inflate + filter-undo path when its random-byte payload happens to contain valid-ish IDAT data after the valid prefix.

### Tests

- `tests/kii.tcyr` — **163 assertions** (was 88 at v0.3.0).
  - **M3(a)** sankoch round-trip: zlib_compress / zlib_decompress / dst-cap-too-small (5).
  - **M3(b)** interlace capture (both 0 and 1) + IDAT buffer accumulation byte-identical to fixture + no-IDAT-leaves-idat_buf-null (14).
  - **M3(c)** Paeth predictor canonical cases (5) + each filter type 0–4 round-trip + unknown-filter rejection (28) + color_channels mapping (8) + 2x2 RGB end-to-end decode (8) + Adam7/sub-byte/no-IDAT rejection (3) + **RAMGON.png** real-world decode → exact 4,262,400-byte buffer size (4).
- **Real-world smoke** (manual, not in `cyrius test`):
  - `RAMGON.png` (1152×925 RGBA) → `1065600 pixels (RGBA)`.
  - `/usr/share/pixmaps/archlinux-logo.png` (256×256 palette) → `65536 pixels (palette)`.
  - `/usr/share/pixmaps/kitty.png` (256×256 RGBA) → `65536 pixels (RGBA)`.

### Dependencies

- stdlib: **+ `sankoch`** (PNG IDAT zlib_decompress), **+ `thread`** (sankoch transitive). No external git deps yet — sankoch folded into Cyrius stdlib at v5.8.65, so this is a stdlib-list addition, not a `[deps.sankoch]` block. `darshana` (external) still lands at M5/v0.6.0.

### Out of scope (deferred per M3 acceptance)

- **Adam7 interlace** — rejected with `interlaced PNGs (Adam7) not supported in v0.x`. Defer-don't-half-implement per CLAUDE.md.
- **1/2/4-bit sub-byte depths** — rejected with `unsupported bit depth or color type (tier-1: 8/16-bit only)`. Same rationale.
- **PLTE → RGB lookup** — palette PNGs (color_type=3) emit palette INDICES at this layer. PLTE chunk handling lands at M4 alongside quantization.

## [0.3.0] — 2026-05-22

### Added

- **M2 — PNG structural decoder**. Valid PNGs now print `<path>: <W>x<H> bit_depth=<N> color_type=<T>` to **stdout** + exit 0 (pipe-pure — consumers can `kii image.png | grep ...`). Distinct error paths surface specific failure modes on stderr + exit 1:
  - `<path>: cannot open file` — open syscall failed (not found, permissions).
  - `<path>: not a PNG (file shorter than 8 bytes)` — truncated before signature.
  - `<path>: not a PNG` — first 8 bytes don't match the W3C magic.
  - `<path>: malformed PNG header` — IHDR chunk truncated, wrong type, or claims length ≠ 13.
  - `<path>: CRC check failed` — IHDR or any post-IHDR chunk fails CRC32.
  - `<path>: malformed PNG (chunk truncated after IHDR)` — chunk header / data / CRC read returned partial bytes.
  - `<path>: warning: incomplete PNG (no IEND chunk seen)` — soft warning per spec § 5.3 tolerance; structural summary still emitted, exit 0.
- **`src/png.cyr`** — new module owning the full structural-decode surface:
  - `PNG_MAGIC` + `PNG_MAGIC_LEN` (W3C § 5.2 signature: detects 7-bit gateways, line-ending mangling, naive `type` cmd).
  - `PNG_OK` / `PNG_ERR_OPEN` / `PNG_ERR_TRUNCATED` / `PNG_ERR_NOT_PNG` / `PNG_ERR_HEADER` / `PNG_ERR_CRC` / `PNG_ERR_CHUNK` codes.
  - `IHDR_*_OFFSET` + `STRUCT_*_OFFSET` field layouts (aligned at the first four slots so summary helpers work on either buf).
  - `png_check_signature(buf)` + `png_validate_file_signature(path)` + `png_read_u32_be(buf, off)` (matches `lib/sha1.cyr`'s big-endian pattern).
  - `png_crc_init()` + `_png_crc_update(crc, buf, len)` + `png_crc32(buf, len)` — Ethernet CRC-32 (reversed polynomial 0xEDB88320, same as zlib / gzip). 256-entry lookup table, idempotent init. First first-party CRC32 in the AGNOS ecosystem; extracts to stdlib if a second consumer surfaces (per the extract-on-2nd-consumer pattern).
  - `png_decode_header(path, out_ihdr)` — signature + IHDR + IHDR-CRC.
  - `png_decode_structure(path, out_struct)` — single-fd open: signature → IHDR (with CRC) → walk subsequent chunks → IDAT count + total-size accumulation → IEND detection. Chunk data streamed through a 4 KB scratch buffer (bounded memory regardless of input size).
- **Multi-source convergent port** per CLAUDE.md hard rule: decoder shape drawn from W3C PNG Specification (1.3) + `libpng` + `stb_image.h` + `lodepng`. Not single-source.

### Changed

- `src/main.cyr` — replaced M1 placeholder dispatch with `png_decode_structure` orchestration. New `_print_ihdr_summary` (stdout) helper for the success line; `_eprint_path_msg` (stderr) for errors + warnings. Missing-IEND warning lands on stderr while the structural summary stays on stdout (pipe-purity).
- `tests/kii.fcyr` — gained a **second fuzz surface**. The same binary now runs both arg-parser fuzz (10k iters, ~50 ms) and **PNG-decoder fuzz** (2k iters, ~50 ms). PNG fuzz: deterministic LCG-driven random byte buffers written to `/tmp/kii-fuzz-png.bin`; 50% of iters prepend a valid signature + IHDR so the post-IHDR chunk walker is exercised. M7 audit raises both counts to 10⁶ per the v1.0 acceptance criterion.

### Tests

- `tests/kii.tcyr` — 88 assertions (was 36 at v0.2.0). New coverage: M2(a) signature check (10), M2(b) BE-u32 decode + IHDR parse over four color types + four malformed cases (25), M2(c) CRC32 canonical (zlib reference + IEND constant + empty buf) + structure walker happy-path + missing-IEND warning + IHDR/IEND CRC bit-flip + truncated mid-chunk (17). Helpers `_ut_put_u32_be` + `_ut_build_min_png` make valid PNG fixtures from runtime-computed CRCs (replaces the pre-(c) "XXXX" placeholders that wouldn't pass CRC validation).

### CI / Release

- `ci.yml` — added **version-drift smoke** (compares `./build/kii --version`'s first line against `VERSION` file; trips CI on mismatch). The M1 close-out cycle hit this drift class once locally — the smoke would have caught it before merge.
- `ci.yml` — added **fuzz step** (`tests/kii.fcyr`, now covers both arg-parser + PNG-decoder surfaces). 12k iters total, ~0.07 s.
- `ci.yml` + `release.yml` — fixed binary-name template default (`${{ github.event.repository.name }}` → hardcoded `kii`). The cyrius-init scaffold assumed repo-name = binary-name; kii's repo is `cyrius-kii` but the binary is `kii` per `cyrius.cyml [build].output` and CLAUDE.md Quick Start.
- **Still deferred** (CI/release thorough setup): CHANGELOG-extracted release notes, aarch64 cross-build, macOS / Windows cross-build, Sigstore / SLSA. Tracked in this section; reassess at v1.0 audit.

### Dependencies

- stdlib unchanged from v0.2.0 (still `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`). PNG decoder uses only what's already in.
- External: still none. **`sankoch` lands at M3 (v0.4.0)** for DEFLATE-through-IDAT decompression.

## [0.2.0] — 2026-05-22

### Added

- **M1 — CLI arg parsing**. Full flag surface frozen at the syntactic level (the surface is contractually stable from here through v1.0):
  - `--help` / `-h` — prints usage to stderr (pipe-pure stdout); exits 0.
  - `--version` / `-V` — prints `kii 0.2.0` + the Hawaiian etymology line to stdout; exits 0.
  - `--width N` / `-w N` — output width in columns; default `0` is the M6 sentinel for "match terminal" (auto-detected via `ioctl TIOCGWINSZ` once M6 lands).
  - `--color N` / `-c N` — color tier; only `8` or `16` valid per CLAUDE.md tier-1 color-discipline. Tier-2 modes (256 / truecolor) explicitly rejected; deferred to post-v1.
  - Positional `<image.png>` — captured into `flags_positional`; zero or 2+ rejected with `kii: missing image path` / `kii: too many arguments` (exit 2).
- **src/cli.cyr** — new module. Owns `KII_EXIT_*`, `KII_F_*` flag indices, `kii_register_flags(fs)`, `kii_validate_color(color)`. Split out of main.cyr so unit tests + fuzz harness can drive kii's exact flag set in-process.
- **Placeholder dispatch** — `kii image.png` (and any valid path) prints `<path>: decoder not yet implemented (width=N color=N)` to stderr + exits 1. The width/color echo proves the flag values were captured into module state. Superseded at M2 when the structural decoder lands.

### Changed

- `src/main.cyr` — `args_init` + `alloc_init` + `kii_register_flags` + `flags_parse` + dispatch. Scaffold no-args banner removed in favor of the missing-path usage error (kii now requires a positional path).
- `cyrius.cyml` — `[deps].stdlib` gained `"flags"` (consumer: CLI flag parsing).

### Tests

- `tests/kii.tcyr` — 36 assertions (was 2). Coverage: smoke + math (2), `kii_validate_color` happy/sad table (8), flag-parse happy paths over the full flag set (long/short/attached forms, defaults, positional capture — 14), each `FLAG_ERR_*` variant (unknown / missing value / bad int / bundled — 8), multi-positional capture (2), version-literal regression baseline left for v0.3.0 (intentionally deferred; the literal isn't auto-generated yet).
- `tests/kii.fcyr` — wired. Deterministic Numerical-Recipes LCG (seed = 1) drives 10,000 iterations of random argv against kii's flag set. Bias toward `-x` / `--foo` prefixes (50% of args) so the parser exercises its flag-recognition path. M7 audit raises to 10⁶ iterations per the v1.0 acceptance criterion. Catches arg-parser crash regressions; PNG-decoder fuzz comes at M2 in a separate harness.

### Dependencies

- stdlib: + `"flags"` (was `args`-only for CLI). All other stdlib modules unchanged.
- External: still none (sankoch lands at M3, darshana at M5).

### CI / Release

- `.github/workflows/ci.yml` — added `workflow_call:` trigger so `release.yml` can gate on it via `uses: ./.github/workflows/ci.yml`. **This was the minimum fix required** to make a v0.2.0 tag actually release rather than blow up at the CI-gate dispatch.
- **Deferred (CI/release thorough setup)** — captured here as the punch list for a dedicated cycle:
  - Run the fuzz harness in CI (`cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz`) on every PR.
  - Add a binary-version smoke step after build (`./build/kii --version | grep "^kii $(cat VERSION)$"`) so a stale `print_version` literal trips CI rather than silently drifting (the M1 work already hit this drift class once).
  - Extract release notes from `CHANGELOG.md`'s `[X.Y.Z]` section rather than relying on GitHub's PR-title `generate_release_notes: true`.
  - aarch64 cross-build (`cyrius build --aarch64`) — release ships only x86_64 today; cyrius supports aarch64 natively.
  - macOS / Windows cross-build (post-v1 — out of v0.2.0 scope).
  - Sigstore / SLSA provenance attestation (probably overkill for kii's threat model; reassess at v1.0 audit).

## [0.1.0] — 2026-05-22

### Added

- `cyrius init kii` scaffold:
  - `VERSION`, `cyrius.cyml`, `LICENSE` (GPL-3.0-only), `.gitignore`
  - `src/main.cyr` — entry point; prints version banner + Hawaiian etymology + scaffold-status line
  - `src/test.cyr` — test entry routing to `tests/kii.tcyr`
  - `tests/kii.tcyr` — primary test suite (smoke + math; 2 assertions, all pass)
  - `tests/kii.bcyr` — benchmark stub (wired at M4)
  - `tests/kii.fcyr` — fuzz stub (wired at M2)
  - `docs/adr/`, `docs/architecture/`, `docs/guides/`, `docs/examples/` skeleton
  - `.github/workflows/ci.yml` + `release.yml`
- First-party-standards docs:
  - `CLAUDE.md` — Project Identity, Goal, color-tier discipline (tier 1 = 8/16-color + half-block; tier 2 post-v1), domain rules (half-block floor, CRC validation, no file writes), naming-lane notes
  - `README.md` — Hawaiian etymology, status, color-tier roadmap, substrate plan (darshana + sankoch + in-repo PNG decoder), multi-source prior art table (chafa / jp2a / viu / libcaca + PNG spec)
  - `CONTRIBUTING.md` — dev workflow, milestone-aligned contributions, dep-add discipline, tests requirement
  - `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1 pointer
  - `SECURITY.md` — explicit threat surface (malformed image input, decompression amplification, ANSI escape injection), mitigations in code, reporting channel
  - `docs/development/state.md` — initial scaffold snapshot
  - `docs/development/roadmap.md` — M0-M7 milestones to v1.0 with acceptance criteria + dep gates
  - `docs/doc-health.md` — per-file currency ledger; tier classification; refresh discipline

### Toolchain

- Cyrius pin: `6.0.1`

### Dependencies

- stdlib: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`
- External: none yet (sankoch + darshana lands at M3 + M5 respectively)

### Naming

- Repo + binary: `kii` (ASCII-safe form; no `cyrius-` prefix — that's reserved for games per AGNOS `project_game_naming_convention`)
- Display form: `kiʻi` with ʻokina punctuation
- Lane: Polynesian-direct (Hawaiian micro-cluster — sibling to `hapi`, `anuenue`)
