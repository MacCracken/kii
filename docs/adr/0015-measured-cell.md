# 0015 — The cell's measured size: every lane at the terminal's cell shape

**Status**: Accepted
**Date**: 2026-10-30
**Extends**: [0004](0004-half-block-floor-glyph.md) · [0007](0007-rendering-mode-taxonomy.md) ·
[0014](0014-tier-3-image-protocols.md)

## Context

Through v2.6.0 every lane assumed a cell twice as tall as it is wide. The half-block lane's
two halves are then square, and every other lane's rows come from the same geometry. Sixel,
which draws in device pixels, took the cell's pixel size from `--cell-size`, with 10x20 as
the default, because kii had no way to measure it.

TIOCGWINSZ reports the window's size in pixels next to its rows and columns. The terminal
side fills those fields, and many terminal emulators do. darshana 1.7.0 exposes them as
`tty_winsize_px` ([darshana ADR 0009](https://github.com/MacCracken/darshana/blob/main/docs/adr/0009-winsize-pixels.md)).
On agnos, winsize#60 gives the grid alone, so the pixels are 0 there. The roadmap had held
three uses back for this:
- every lane fits the measured aspect;
- Sixel takes its cell size from the terminal;
- the image protocols send no more pixels than the cell box shows (a candidate).

Two roadmap rules bear on it. The first: the default output does not change by surprise.
The second: kii stays environment-blind, so output depends only on the arguments, the image
and the terminal's size.

## Decision

**1. One read, one cell.** main reads the terminal once, `tty_winsize_px(1, …)`. The rows
and columns size the frame when `--width` is not given, as `tty_winsize`'s did. The pixels
give the cell when `--cell-size` is not given. `kii_measured_cell` computes it as the
window's pixel width over its columns and its pixel height over its rows, each rounded down,
the way chafa does. It is used only when:
- the call succeeded;
- all four values are positive;
- both sides land in 1..256, the bounds `--cell-size` takes.

Otherwise the cell is 10x20. Off a terminal (a file, a pipe) the call fails, so a captured
frame never depends on the terminal it was made on. That holds under `--width N` too.

**2. `--cell-size` in every lane, over the measurement.** It was Sixel's flag, and other
lanes refused it. Now it is the cell everywhere, and a given cell wins over a measured one.
The flag also makes a frame reproducible: given, output depends only on the arguments and
the image (and, in fit mode, the terminal's rows and columns).

**3. Every lane's rows at the cell's shape.** For a cell of `cw` × `ch` pixels:
- a frame `cols` wide gets `(src_h × cols × cw) / (src_w × ch)` rows, at least 1;
- when the terminal's rows bind, the frame gets `(rows × ch × src_w) / (src_h × cw)`
  columns, at least 1.

A 1:2 cell (any k × 2k, 10x20 included) gives the v2.6.0 arithmetic exactly, rounding
included, so its frames are byte-identical. The cell lanes, the iTerm2 box, kitty's `c=`/`r=`
choice and the Sixel box all take their rows from this geometry. Sixel also draws in the
cell's pixels.

**4. The image protocols keep the decoded resolution.** The roadmap's pixel cap for
`--mode iterm` and `--mode kitty` is not taken. On a HiDPI display, a terminal's pixel fields
may count device pixels or points. That is not known for each terminal, and capping at points
would halve the image's resolution where the display has twice the pixels. It stays a
candidate.

**5. `--verbose` names the cell** when it was measured or given, as
`, cell 9x19 (measured)` or `, cell 9x19 (--cell-size)`. The default adds nothing, so a frame
sized as v2.6.0 sized it reports as it did.

**On the two rules.** The pixel fields are part of the terminal's size, which the second
rule names as an input. Nothing is read from `TERM`, `COLORTERM` or a terminal query. The
first rule allows a default-output change that says so with ⚠ and is measured over the
corpus (§ Measurements). The change is confined: only on a terminal that reports a cell
whose shape is not 1:2, and only when stdout is that terminal. There, v2.6.0's frames were
stretched, and the new ones are not.

## Measurements

Corpus (`scripts/corpus.sh`, 832 images, 820 that decode), v2.7.0 against v2.6.0, 36,584
cases, 0 differing:
- **Off a terminal**, stdout a pipe: every lane, fit and `--width`, with tiers, dithers and
  `--verbose`. Identical stdout, stderr and exit code.
- **A 24x80 pty reporting no pixels**: every lane, fit. Identical.
- **A 24x80 pty with an 8x16 cell (1:2)**: every lane identical. Sixel matches v2.6.0
  given `--cell-size 8x16`.
- **A 9x19-cell pty, v2.7.0 given `--cell-size 10x20`**: identical to v2.6.0 given
  nothing.
- **The 9x19-cell pty, measured**: 1,640 end-to-end checks, every one as the cell gives,
  computed independently from each image's size. The fit frame's rows and columns, the rows
  at `--width 40`, and the Sixel raster size.

How much a measured cell moves, for the 820 images fitted into a 24x80 terminal:

| Cell | h / w | Frames changed | v2.6.0's frame, drawn, vs the image's true height |
|---|---:|---:|---:|
| 10x20, 9x18 | 2.000 | 0 | — |
| 9x19 | 2.111 | 702 (85.6 %) | +5.6 % |
| 8x17 | 2.125 | 715 (87.2 %) | +6.3 % |
| 7x15 | 2.143 | 744 (90.7 %) | +7.1 % |
| 12x26 | 2.167 | 751 (91.6 %) | +8.3 % |
| 10x22 | 2.200 | 756 (92.2 %) | +10.0 % |

The frames that do not change are images too small, or too nearly at a rounding edge, for
the cell to move a row or column.

## Consequences

**Positive**
- An image is drawn at its own aspect on a terminal that reports its pixels. On the cells
  above, v2.6.0 stretched it 5.6 to 10 % vertically.
- Sixel is the box's size with no flag on such a terminal.
- **A v2.6.0 Sixel defect is fixed.** v2.6.0 chose the bound side at 2:1 whatever
  `--cell-size` said. With a cell flatter than 1:2, a fit-mode Sixel image could be taller
  than the terminal. A 1000x300 image at `--cell-size 10x10` on a 24-row pty drew 240 pixels:
  24 rows, one past the 23 left above the prompt. v2.7.0 draws 230.
- `--cell-size` makes any lane's frame independent of the terminal.

**Negative**
- The same command can give two frames: on the terminal at its cell, and redirected at
  10x20. That is the intent, since a file has no cell, but it is new.
- A terminal that counts its padding or margins in the pixel fields reports a cell slightly
  too large. kii takes the fields as given, as chafa does.
- One more ioctl under `--width N`, which used to issue none.

**Neutral**
- agnos reports no pixel size (winsize#60 is the grid alone), so its frames keep 10x20,
  as does any terminal that leaves either pixel field 0.
- `--verbose` lines gain the cell only off the default.

## Alternatives considered

- **Sixel only.** It would take the measured cell and leave every other lane at 2:1. That
  keeps the default output, but leaves the stretch the roadmap meant to remove. It would also
  make the Sixel box disagree with the cell lanes' rows.
- **The aspect as an exact ratio** (`ypix × cols : xpix × rows`) rather than whole-pixel
  sides. That is marginally more exact for the cell lanes. But Sixel needs whole-pixel sides
  anyway, and one cell for every lane keeps the lanes' boxes in agreement.
- **Ask the terminal in-band** (xterm's `CSI 16 t`). This would reach terminals that leave
  the ioctl fields 0, but it is a terminal query, which the second rule excludes, and it needs
  raw mode and a timed read.
- **Keep `--cell-size` Sixel-only.** Then there is no way to make a frame independent of the
  terminal it is drawn on, or to correct a terminal that reports a wrong size.

## References

- darshana `tty_winsize_px` (1.7.0) and its ADR 0009.
- chafa's terminal-size probe (the cell as the window's pixels over its cells) and its
  10x20 fallback (ADR 0014 § v2.6.0).
- `ioctl_tty(2)`: TIOCGWINSZ and `struct winsize`.
