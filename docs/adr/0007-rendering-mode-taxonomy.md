# 0007 — Rendering-mode taxonomy: half-block + character-glyph lanes

**Status**: Accepted
**Date**: 2026-06-26

## Context

Through v1.2.x kii had exactly one rendering lane: half-block (`▀`) with a
256-color foreground + background per character cell, two source rows
packed into each cell. [ADR 0004](0004-half-block-floor-glyph.md) fixed
that as the *floor* glyph and CLAUDE.md names it the default aesthetic.

But kii's identity (CLAUDE.md, README) is explicitly the `chafa` / `jp2a`
/ `viu` lineage — and `jp2a` is the *character-glyph* ("ASCII art") lane:
render the image as a grid of text characters chosen by brightness, not
colored blocks. That lane was a tracked post-v1 roadmap item. With the
decoder substrate now feature-complete (chitra 0.2.1 — the full PNG
matrix), the rendering surface is the natural place to grow, and the
character lane is the most-requested, most on-brand addition.

Introducing a second lane forces a structural decision: is it a *replacement*,
a *flag on the existing emit*, or a *parallel mode*? And how do the two
lanes share the pipeline (decode → downscale → quantize) without each
re-implementing it?

## Decision

**kii has two co-equal rendering lanes selected by `--mode`:
`halfblock` (default) and `ascii`.** They share the entire front of the
pipeline (decode → geometry → downscale → quantize) and diverge only at
the emit step:

- **`halfblock`** (unchanged): `emit_halfblock` — 2 source rows per cell,
  `▀` with fg/bg color. The default; ADR 0004 still governs it.
- **`ascii`** (new, `src/ascii.cyr`): `emit_ascii` — ONE source cell per
  character, mapped by **luminance** to a density ramp `" .:-=+*#%@"`,
  drawn in the cell's quantized foreground color. Because a character is
  one cell (not two stacked sub-pixels), `main.cyr` downscales to half the
  source rows in this mode, keeping the aspect correct in the terminal's
  ~2:1 character cells.

The lane shipped in two steps. **v1.3.0 — the floor:** a luminance→ramp
mapping with the standard Rec.709 weights (`0.2126/0.7152/0.0722`,
integer 54/183/19 ÷256 — a W3C/Wikipedia multi-source standard). **v1.3.1 —
the shape-vector upgrade:** `--mode ascii` now samples each cell in a 2×3
sub-grid and picks the glyph whose ink-coverage vector is nearest
(squared-Euclidean over the 6 regions), so it tracks glyph *orientation*
(`/ \ | - _ ( ) ^`), not just density. The per-glyph coverage table (27
glyphs) is computed offline from Liberation-Mono and normalized to the
0..255 luminance scale. Both steps are **colored by default** (compose with
the color tier). Scope stays off the color tier + dithering (separate post-v1
items).

**Attribution:** the shape-vector technique (per-cell N-region coverage
vectors + nearest-glyph match) is **Alex Harri's**, "ASCII Art Rendering"
(<https://alexharri.com/blog/ascii-rendering>) — cited in `src/ascii.cyr`.
kii uses a 6-region (2×3) variant; the Euclidean NN + Rec.709 luma are
standard CS (no attribution needed).

**Out of scope (tracked follow-up):** the further refinements from the blog —
directional **contrast enhancement** (normalize-by-max → power → denormalize
on the cell vector before matching) and a **k-d-tree** lookup to replace the
linear glyph scan. The 6-region raw-luminance match is a complete feature
without them; they sharpen edges / speed the hot path.

## Consequences

- **Positive** — kii now fills its namesake ASCII-art lane; the two modes
  share decode/downscale/quantize so the addition is ~one module
  (`ascii.cyr`) + a `--mode` flag + a one-line pipeline fork. Half-block
  output is **byte-identical** (the default path is untouched; RAMGON +
  all color-type goldens unchanged). ASCII glyphs are single-byte ASCII,
  so unlike the half-block `▀` they carry no UTF-8 cell-width risk.
- **Negative** — a second emit path to maintain and test; `--mode` widens
  the frozen-since-v1.0 CLI surface (a value flag, backward-compatible —
  default is the prior behavior). The shape-vector "real" ASCII art people
  may expect is deferred, so the floor can look blockier than tools that do
  edge-aware glyph selection.
- **Neutral** — establishes the mode taxonomy that future lanes slot into
  (e.g. a v2.0 full-Block-Elements vocab, or Sixel/Kitty image protocols
  would be `--mode sixel`). This ADR is the registry those amend.

## Alternatives considered

- **Make ASCII a `--color` value (e.g. `--color none`)** — rejected:
  conflates the color tier (how many colors) with the glyph lane (blocks
  vs text); they're orthogonal (ASCII can be colored). A separate `--mode`
  axis keeps them composable.
- **Replace half-block with ASCII / pick one** — rejected: half-block is
  the documented floor (ADR 0004) and the higher-fidelity default for the
  BBS/MUD aesthetic; ASCII is a distinct deliverable, not a replacement.
- **Ship the shape-vector matcher in the first cut (v1.3.0)** — deferred,
  not rejected: the luminance ramp landed first as the dependency-free floor
  (v1.3.0), and the shape-vector matcher followed as a clean increment on top
  (v1.3.1) once the coverage table was generated. Staging kept each release
  small and verifiable.
- **Monochrome ASCII by default** — rejected: kii is a color tool; colored
  glyphs compose with the color tier and are the richer default. A future
  `--mode ascii` + a "no color" axis can offer monochrome.

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**: two co-equal lanes, selected by `--mode`. The v1.6.4 sweep
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)) found that the `ascii`
bullet in § Decision still describes the v1.3.0 floor, which v1.3.1 replaced:

**1. The entry point is `emit_ascii_shape`.** `emit_ascii` and its luminance ramp were
removed at v1.3.1. The lane is `emit_ascii_shape` / `emit_ascii_shape_row_buf` with
`_ascii_match` (`src/ascii.cyr`).

**2. The lane does not take "half the source rows".** That was v1.3.0's geometry. Since
v1.3.1 `main.cyr` downscales to `cols·2 × rows·3`, a 2×3 sub-grid per character cell, where
`rows` is the half-block lane's character-row count.

**3. The lane does not share quantize.** § Decision and § Consequences say both lanes share
decode → geometry → downscale → quantize. Since v1.3.1 the ASCII lane skips
`quantize_downscaled`: it averages each cell's six samples and quantizes that mean colour
with `quantize_nearest_rgb`, under the same `--color` tier. The lanes share decode,
geometry, the frame-size cap (v1.6.4) and downscale.

**4. Shape-vector matching shipped.** § Consequences (Negative) calls the shape-vector
matcher "deferred"; it shipped at v1.3.1, as the paragraph after § Decision's bullets says.
The follow-ups that remain open, directional contrast enhancement and a k-d-tree lookup,
are pinned to roadmap 1.10.0, together with checking in the coverage-table generator: the
offline script that produced the 27-glyph table is not in the repo, so the table cannot be
regenerated today.

## Amendment — v1.10.0 (the shape-vector refinements)

This ADR remains **Accepted**. The three items the v1.6.4 amendment pinned to 1.10.0 are
settled: the table has a generator, contrast enhancement runs before every match, and the
k-d tree was built, measured and not taken. Half-block output is byte-identical; ASCII output
changes.

**1. The coverage table is generated, and it is a new table.**
`scripts/gen-shape-table.sh` writes `src/ascii_shape.cyr`, and `--check` proves the committed
file is its output.
- **Method.** Each glyph is rasterized in Liberation Mono Regular at 40 px, in a 24 × 48 cell.
  The advance is exactly 24 px, and the 45 px line box sits on a baseline at y = 35. The ink of
  each 12 × 16 px region is summed, then scaled so each row's most-inked glyph reads 255, with
  integer rounding. The header records the font hash, ImageMagick and FreeType.
- **The v1.3.1 table could not be reproduced.** Its scratch generator is gone, and no transcript
  on the dev host holds it. A search over size (32–56 px), placement (gravity, offsets,
  subpixel phase), antialiasing on and off, and global or per-region scaling (scale fitted by
  least squares) never came within 33 units per value of it. Symmetric glyphs in it read
  heavier on the left (`|` 119 / 81), which no centred rendering gives. The new table differs
  from it by 18.2 units per value on average.
- **Scaled per row, not per region.** Scaling each dimension apart is Harri's normalization:
  unscaled, most glyphs carry little ink in the top and bottom rows, so a bright top or bottom
  region has no glyph near it. Harri scales each region alone. kii shares one maximum between
  a row's two regions, because the left and right maxima come from asymmetric glyphs (`%`,
  `@`). Scaled per region, `.` reads 51 / 76 and the mirrored pairs stop being mirrors. Per row,
  `/` `\`, `(` `)` and `<` `>` mirror within 2 units, which `tests/ascii.tcyr` pins. Of the
  three scalings, per row is also the closest to the v1.3.1 table (18.2 against 21.4 per region
  and 32.0 global).

**2. Contrast enhancement runs on every cell before the match** (`_ascii_contrast`). It follows
Harri's write-up: x → (x / M)^p · M against a ceiling M, first directional, then global.
- **Directional.** Region i's ceiling is the largest of its own value and the external samples
  that affect it, per Harri's `AFFECTING_EXTERNAL_INDICES`. The article shows where the ten
  external circles sit only in a figure. kii places them on the sub-samples the mapping
  implies: two above the cell, three on each side, two below. A sample past the frame's edge,
  or a transparent one, counts as 0.
- **Global.** The ceiling is the cell's largest value after the directional step.
- **Order.** The prose gives none. The article's GPU pipeline runs directional first, then
  global, and kii follows it.
- **p = 1.5.** The article's exponent control runs from 1 to 2. 1.5 was chosen by comparing
  renders, not by a measure: at 2, photographs turn noisy with scattered `.` and `` ` ``.
  The exponent is `ASCII_CONTRAST_R / ASCII_CONTRAST_Q`.
- **Exact integers.** A 256-entry power table built at init (the exact half-up rounding of
  255 · (t / 255)^p), a reciprocal table for the one division by M, and an exact shift for
  / 255. Each is checked over its whole domain in `tests/ascii.tcyr`. aarch64 frames match
  x86_64's.
- **The cost.** The frame's luminance is built once per frame (`_ascii_lum_plane`, one byte a
  sample, stored at pstruct +40) instead of per cell. Per run, interleaved with v1.9.1: a 256²
  icon at `--width 200` takes 5.26 → 5.98 ms (+14 %), RAMGON 203.9 → 207.3 ms (+1.7 %), and
  kitty's 3880 × 2168 screenshot 324.3 → 324.2 ms. A first draft cost +44 % on the icon. The
  savings came from the plane, from skipping a step whose value is its ceiling or 0, from
  sending an all-dark cell straight to a space, and from building the power table in one sweep
  (511 steps, not 65,280).

**3. The k-d tree is not taken.** An exact tree over the 27 glyph vectors was built, splitting
on the widest dimension at the median. Ties go to the lower index, as in the scan. It agrees
with the scan on 2,000,000 random vectors and on 710 vectors within ±2 of a glyph. It is
slower:

| Lookup | Random vectors | Real cells (RAMGON, kitty, archlinux) |
|---|---:|---:|
| linear scan with early exit (`_ascii_match`) | 331 ns | 203 ns |
| k-d tree, recursive | 444 ns | 233 ns |
| k-d tree, iterative (explicit stack) | 803 ns | 449 ns |

With 27 points in 6 dimensions the tree prunes little, and the scan already stops scoring a
glyph after three terms. Harri pairs a tree with a cache of answers. That only helps when
cells repeat, and in a photograph they do not: 15,974 of RAMGON's 16,000 cells at that size are
distinct, against 670 of 16,000 for the archlinux logo.

**Effect on output.** Over 472 images, `--mode ascii --width 30` changes 8.7 % of glyph cells:
5.6 % from the table and 5.7 % from contrast enhancement, which overlap. Under the corpus's two
ASCII flag sets, 836 of the 912 frames that render change. Every half-block frame is
byte-identical (1,888 of 1,888).

## Amendment — v1.11.0 (area sampling)

This ADR remains **Accepted**. Each cell's six region values are now means over the source area
each region covers, not one point per region
([ADR 0005](0005-nearest-neighbor-downscale.md) § v1.11.0 amendment). The table, the contrast
pass and the match are unchanged. Half-block output is byte-identical.

**What one point per region got wrong.** Whether a thin feature showed depended on where the
points fell.
- In a 480 × 480 test of 2 px lines at `--width 48`, the horizontal and vertical lines drew no
  glyph at all, and the circle broke into pieces. Both now draw, as a row of `` ` `` and a
  column of `:`, and the circle is unbroken.
- The two diagonals of a 480 × 240 X at `--width 60` rendered differently (`*>x_` one way,
  `_o/*` the other), because the centre rule's ties go right and down. They are now exact
  mirrors (`*>x_.` and `._x<*`).

**Ink drawn as a space.** For each cell with ink, its coverage was measured with an ImageMagick
box filter, then the cell's glyph was checked:

| Test image | Cells with ≥ 5 % ink | v1.10.0 draws a space | v1.11.0 |
|---|---:|---:|---:|
| 2 px lines and circle, `--width 48` | 291 | 127 | 18 |
| the same, `--width 80` | 519 | 142 | 40 |
| 12 px lines, 4000 × 4000, `--width 48` | 248 | 80 | 4 |
| 5 px X, `--width 60` | 170 | 40 | 3 |
| white serif text, `--width 60` | 90 | 24 | 3 |
| 3 px ring on transparency, `--width 40` | 99 | 24 | 4 |

At 15 % coverage and above, v1.11.0 draws a glyph in every cell, where v1.10.0 left up to 26 of
134 blank. Its remaining blanks are faint fringe cells, 5–15 % coverage, where a space is the
nearest glyph. Neither version draws a glyph where there is no ink.

**The trade-off.** A thin line is light ink, so it now draws as `.` `` ` `` `:` `'` instead of
as a bold `\` or `/` with gaps. That is its real coverage. Photos lose their salt-and-pepper
texture: RAMGON changes 26–39 % of its cells between `--width 30` and `--width 100`, and the
Arch logo 2–6 %, mostly along its edges, which become symmetric.

**Effect on output.** Over the 472-image corpus, 328 of the 912 ASCII frames that render change,
under the corpus's two ASCII flag sets. At `--mode ascii --width 30`, 1.6 % of glyph cells
change, in 158 frames. Every frame that changes is reduced on some axis; the 276 enlarged on
both are byte-identical. Every half-block frame is byte-identical (1,888 of 1,888).

## Amendment — v2.0.0 (a third lane)

This ADR remains **Accepted**. `--mode` gains a third choice, `blocks`
([ADR 0012](0012-block-elements-lane.md)): `halfblock | ascii | blocks`, still a cmdit
enum, default `halfblock`. The blocks lane shares the ASCII lane's cell grid (cols ×
half-block rows) and the area sampler's tap tables, but samples each cell 8 × 8 straight
from the decoded pixels and draws a Block Element in two colours rather than a glyph in
one. An unknown `--mode` value now reads `kii: --mode must be halfblock, ascii or blocks`.
The half-block and ASCII lanes are byte-identical to 1.11.0.

## Amendment — v2.2.0 (the ASCII lane's ink and colour)

This ADR remains **Accepted**. The ASCII lane gains two settings of its own, `--invert` and
`--color none`, and the half-block and blocks lanes refuse both. Without them, every frame in
every lane is byte-identical to 2.1.0 (5,192 of 5,192 corpus cases, 11 flag sets over the three
lanes).

**1. `--invert` (`-i`): dark is ink.** Since v1.3.0 the lane has read light as ink, which
suits light glyphs on a dark terminal; on a light one its art comes out as a negative. With
`--invert`:
- each opaque pixel's ink is its negative's luminance, `(65280 − (54 r + 183 g + 19 b)) / 256`
  rather than `(54 r + 183 g + 19 b) / 256`, in both plane builders (the area sampler and, for
  a frame with no reduction, `_ascii_lum_plane`);
- partial alpha (128–254) is composited over white rather than black
  ([ADR 0010](0010-tier-2-colour-and-emit-encoding.md) § v2.2.0), since the image now sits on
  a light terminal;
- a transparent pixel still has no ink, and each glyph keeps its cell's mean colour.

Together these make the inverted plane exactly the plain plane of the image's negative (each
channel `255 − c`, alpha kept). Compositing over white is the negative's composite over black,
negated back (`255 − ⌊((255 − c) a + 127) / 255⌋`), and the area sampler takes the negative's sum
per tap, where it knows how many taps are opaque. So an inverted frame draws exactly the glyphs
its negative draws, in the image's own colours.

Two simpler forms were rejected:
- **`255 − Y` on the finished plane.** A sample whose span is partly transparent holds its
  opaque taps' luma over all its taps, so subtracting from 255 would count the transparent
  taps as full ink. White on half-transparent paper would read as half ink.
- **Inverting only the plane, still compositing over black.** The anti-aliased edge of a white
  icon on transparency would be grey, which is ink when dark is ink: the frame would gain an
  outline the image does not have.

Measured on the corpus: 422 images, the PNG, GIF and BMP files at 8 bits or fewer. For each,
ImageMagick's decode was first checked against chitra's by a truecolour round trip, and
matched for all 422. At `--width 40` and `120` every inverted frame draws exactly its
negative's glyphs (843 frames, and one that both refuse as too large). Colours:
- In the 91 images without partial alpha, every glyph keeps its colour.
- Of all 2,686,892 cells drawn in both frames, 206,559 change colour. Every one is in the 331
  images with partial alpha, where the colour now composites over white.

A 16th fuzz surface checks the identity byte for byte on 50,000 random images, through both
plane builders.

**2. `--color none`: glyphs only.** The tier is [ADR 0010](0010-tier-2-colour-and-emit-encoding.md)
§ v2.2.0's. In this lane a row at `none` is its glyphs and a newline: no foreground escape and no
closing SGR 0, so the output is plain text for pipes, logs and mail. A cell's glyph never
depends on its colour, so the colourless frame is the coloured one with its escapes removed.
On the corpus that holds for all 2,826 cases: 472 images under six flag sets (tiers 8, 16,
256 and tc, each dither, with and without `--invert`, widths 40 and 120), of which 2,733
render and 93 are refused alike. The fuzz surface checks it on every row at a random tier
and dither.

**3. Refused in the other lanes.** `--invert` or `--color none` with `--mode halfblock` or
`blocks` is a usage error (exit 2):
- `kii: --invert applies to --mode ascii only`
- `kii: --color none applies to --mode ascii only`

Those lanes draw colours, not ink. A negative half-block image, or a one-colour half-block
lane, would be a feature of its own. Refusing both settings keeps the names free for one.
Ignoring them would mean a later release changes what an accepted command draws.

**4. § Alternatives, revisited.** The rejected alternative "Make ASCII a `--color` value (e.g.
`--color none`)" was about selecting the lane by its colour. `--color none` does not select a
lane: `--mode` still does, and `none` is the colour axis at zero colours.
- A separate `--no-color` switch was the other way. It would allow the meaningless
  `--color 256 --no-color`.
- The name is chafa's (`--colors none`).
- jp2a's default output is, in kii's terms, `--mode ascii --color none --invert`: jp2a reads
  dark as ink unless given its own `--invert`.

**Effect on speed.** Without the new flags, CPU is unchanged within run-to-run noise. Interleaved
runs, fastest of each:
- `--mode ascii --width 200`: RAMGON 221.42 → 221.35 ms; a 256-pixel icon, which takes the point
  plane, 5.03 → 5.04 ms. A first draft folded the inverted and plain point-plane loops into one
  loop, and cost the icon 2.6 %.
- The half-block lane: RAMGON at `--width 120`, 205.21 → 205.32 ms.

The new flags, in two later sets of runs:
- **`--invert`** costs RAMGON 0.7–1.1 % (213.7 against 212.2 ms, and 224.6 against 222.1 ms on
  a busier host), because more of its cells have ink to match: 15,693 of 16,000, against 12,976.
- **`--color none`** is faster, since no cell is quantized and fewer bytes are written: RAMGON
  212.2 → 210.6 ms, and the archlinux logo 5.90 → 5.39 ms.

## Amendment — v2.3.0 (a fourth lane)

This ADR remains **Accepted**. `--mode` gains a fourth choice, `braille`
([ADR 0013](0013-braille-lane.md)): `halfblock | ascii | blocks | braille`, still a cmdit
enum, default `halfblock`. An unknown `--mode` now reads
`kii: --mode must be halfblock, ascii, blocks or braille`.
- **The cell grid is the ASCII and blocks lanes'** (cols × half-block rows). Each cell is
  2 × 4 dots, sampled through the area sampler at 16 × 8 taps a dot.
- **The Braille lane draws ink, as the ASCII lane does**, so it takes `--invert` and
  `--color none` as well. The refusal lines now name both lanes:
  `kii: --invert applies to --mode ascii or braille only`, and the same for `--color none`.
  Under `--invert` the dots are exactly those of the image's negative, because the lane
  reads the same plane 2.2.0's ASCII lane does.

The half-block, ASCII and blocks lanes are byte-identical to 2.2.0.

## Amendment — v2.4.0 (a protocol among the modes)

This ADR remains **Accepted**. `--mode` gains `iterm`
([ADR 0014](0014-tier-3-image-protocols.md)), the first value that is not a cell lane: kii
sends the picture and the terminal draws it. The enum is
`halfblock | ascii | blocks | braille | iterm`, and an unknown value reads
`kii: --mode must be halfblock, ascii, blocks, braille or iterm`.
- **It shares the cell lanes' geometry**: the same columns and half-block rows give the cell
  box the terminal draws into.
- **It takes none of their settings.** `--color`, `--dither` and `--invert` act on cells and
  glyphs, so `--mode iterm` refuses each one when it is given, even at its default, with
  `kii: --color does not apply to --mode iterm (the terminal draws the image)` (and
  likewise for the other two). `cmdit_seen` tells a given flag from a default.

The four cell lanes are byte-identical to 2.3.0.
