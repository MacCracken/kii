# 0010 — Tier 2 colour, and how a frame is encoded

**Status**: Accepted
**Date**: 2026-10-15
**Supersedes**: the parts of [0003](0003-color-tier-discipline.md) that limit `--color` to
tier 1 and choose `38;5;N` for it. **Extends**: [0004](0004-half-block-floor-glyph.md) ·
[0007](0007-rendering-mode-taxonomy.md)

## Context

[ADR 0003](0003-color-tier-discipline.md) committed v1.0 to tier 1 (8/16 colours) and left
tier 2 for later, saying tier 2 "requires new ADRs, not just code": which palette, how
truecolour is encoded, and whether the environment picks the tier. It also chose to send
tier 1 as the 256-colour escape `38;5;N` / `48;5;N`, while its own Consequences said no byte
would need a terminal feature under 30 years old. The v1.6.4 sweep confirmed the
contradiction (finding C-11): the tier meant for strict 16-colour terminals and BBS clients
sent an escape some of them cannot parse.

The same sweep measured two more things the encoding could do better. Every cell repeated
its fg and bg escapes even when they matched the cell before (O-5: 61–87 % of a frame's
bytes). And transparent pixels, after v1.6.4, were composited over black, so on a light
terminal theme a transparent icon became a black box.

All three change every frame's bytes. 1.8.0 takes them together with tier 2, so a
captured frame changes once rather than three times.

## Decision

### 1. `--color 8 | 16 | 256 | tc`

- `--color` is a cmdit enum. **16 stays the default.**
- kii stays environment-blind: it does not read `COLORTERM` or `TERM`. 0003's reason
  still holds — the same command must give the same bytes in CI and on a desk.
- A `--color auto` that does read them can come later as an opt-in. It would not be the
  default.

### 2. What each tier sends

| tier | fg / bg | palette |
|---|---|---|
| 8 | SGR 30–37 / 40–47 | Linux console entries 0–7 |
| 16 | 30–37 / 40–47, plus 90–97 / 100–107 for 8–15 | Linux console entries 0–15 |
| 256 | `38;5;N` / `48;5;N` | xterm indices 16–255 |
| tc | `38;2;R;G;B` / `48;2;R;G;B` | the pixel's own RGB |
| any (transparent) | 39 / 49 | the terminal's default colour |

- **Tier 8 is the strictest set.** It refuses an index past 7 rather than sending 90–97.
- **Bright colours use the aixterm codes 90–97 / 100–107**, not bold or blink. Bold
  changes the glyph's weight on most terminals. Bright backgrounds through blink need
  iCE-colour mode. 90–107 are what the Linux console and every xterm descendant
  understand.
- **Tier 256 skips indices 0–15.** Their RGB is whatever each terminal's theme says, so a
  nearest-colour match against them would be a guess. Tiers 8 and 16 use those entries
  by name instead.
- **All escapes come from darshana's composers**: `tty_sgr_buf`, `tty_fg/bg_256_buf`,
  `tty_fg/bg_rgb_buf`. Each refuses an out-of-range value and writes nothing.

### 3. Tier 256 quantization

- The nearest entry is found exactly by Euclidean distance in sRGB-coded RGB, the same
  metric tier 1 uses.
  - **Cube (16–231):** the nearest point is the nearest level per channel.
  - **Grey ramp (232–255):** the nearest grey is the level nearest the channel mean.
  - The two candidates are compared; ties go to the lower index.
- That is exactly what a full scan of all 240 entries in index order picks, and the test
  suite checks it against one.
- No gamma linearization, and no perceptual metric (CIE Lab, ΔE). Those are quality work
  for a later release, and they would make tier 1 and tier 2 disagree about distance.

### 4. Elision

- Each row tracks the fg and bg it last set, and skips an escape that would repeat it.
- The state starts **unknown** at every row. The first cell sets what it uses, so a row
  never relies on the one above it.
- Every row still ends with SGR 0 and a newline.
- A space cell takes no fg escape: nothing is drawn in it.

### 5. Transparency

- A pixel with alpha below **128** is transparent; that is chafa's default threshold.
- At 128 and above a pixel is opaque, and partial alpha is still composited over black.
- In the half-block lane a transparent half takes the default colour (39 / 49), and the
  glyph keeps the opaque half's colour:
  - **bottom transparent:** `▀`, fg = top.
  - **top transparent:** `▄`, fg = bottom.
  - **both transparent:** a space.

  `▄` is the half-block floor's own pair glyph ([0004](0004-half-block-floor-glyph.md)), so
  this stays inside the floor.
- In the ASCII lane a transparent sample counts as no ink and is left out of the cell's
  mean colour, so a fully transparent cell is a space.

## Consequences

**Positive**

- **Tier 1 now keeps 0003's promise.** No byte needs a feature under 30 years old: 30–37
  and 40–47 for tier 8, plus the aixterm brights for 16.
- **Photographic output for those who ask.** `--color 256` and `--color tc` render
  gradients that 16 colours band.
- **Much smaller output.** Across the test fixtures and 466 system images, tier-8 and
  tier-16 frames are ~85 % smaller (71.99 MB → 10.87 MB over 996 frames;
  `docs/benchmarks.md` § v1.8.0). That matters on the serial links and BBS pipes the
  tier-1 floor exists for.
- **Transparent images look right on any terminal background.**
- **Opaque tier-8 and tier-16 frames look the same as before.** A replay of every escape
  into (glyph, fg, bg) per cell matches 1.7.0 for every opaque image tested (996 frames,
  both lanes). In transparent images, every half drawn opaque matches too (1,344 frames).

**Negative**

- **Every captured frame's bytes change once, at 1.8.0.** A consumer that pinned frame
  bytes needs new fixtures. 0003's "byte-stable across minor cuts" is broken here,
  deliberately, and holds again from 1.8.0.
- **Tier-1 colours now follow the terminal's palette.** Its 16 named colours replace the
  fixed `38;5;0–15` indices. On almost every terminal those are the same colours.
- **Transparent cells follow the terminal too:** they show its default background, not
  black.
- **Tier 256 never uses the 16 system colours**, even when a pixel matches one exactly.

**Neutral**

- **The emit surface is still SGR only.** No OSC, DCS or APC. The parameter space grows to
  `38;2` and `48;2` with three bounded channels. [0002](0002-security-model.md)'s
  restricted-emit posture holds.
- **The worst-case cell grows from 25 to 41 bytes** (two 19-byte truecolour escapes and a
  glyph). The frame cap (`KII_MAX_CELLS`) still bounds the frame, at roughly 43 MB of
  truecolour output.

## Alternatives considered

- **Keep `38;5;N` for tier 1.**
  - Rejected: it is the C-11 contradiction.
- **Bold and blink for the brights.**
  - Rejected: bold also changes the glyph's weight, and blink-as-bright needs iCE mode.
  - A BBS client that wants that form is a case for a separate tier, not for the default.
- **Tier 256 over all 256 entries.**
  - Rejected: entries 0–15 have no fixed RGB to match against.
- **Auto-detect truecolour from `COLORTERM`.**
  - Rejected as a default for 0003's reason. It is possible later as an opt-in `--color auto`.
- **Keep compositing transparency over black.**
  - Rejected: it is wrong on every light-background terminal.
- **Elide across rows.**
  - Rejected: each row would then depend on the one above, and a cut or interleaved frame
    would render in the wrong colours.

## References

- [`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md) § 6: C-11, O-5, and the
  transparency deferral.
- xterm's 256-colour layout, the 6×6×6 cube over 0/95/135/175/215/255, and the grey ramp
  8–238; also `tmux`'s and chafa's quantizers, which make the same split.
- chafa's `--threshold` (alpha), default 0.5.

## Amendment — v2.1.0 (what the Linux console does with the brights)

This ADR remains **Accepted**, and tier 16 keeps the aixterm codes. One claim in § Decision
is corrected: "90–107 are what the Linux console and every xterm descendant understand". The
console accepts them, but it does not draw them as an xterm does (`drivers/tty/vt/vt.c`,
`csi_m`, read 2026-10-29):
- **100–107 are drawn as 40–47.** The console has no bright backgrounds, so a bright colour
  sent as a background shows dim.
- **90–97 set bold and the colour.** Bold is how the console draws a bright foreground, and
  a later 30–37 changes only the colour, so every dim foreground after a bright one in the
  same row shows bright until the row's SGR 0.

Modelled on the corpus, a 2.0.1 frame at tier 16 had 27.6 % of its cell halves (no
dithering) in the wrong colour on the console. 2.1.0's half-block lane keeps bright colours
in the foreground wherever a cell allows it, which brings that to 0.60 %
([ADR 0004](0004-half-block-floor-glyph.md) § v2.1.0). The rest is cells of two different
brights, one of which must be a background, and the stuck bold. The blocks lane is
unchanged: the console's CP437 fonts cannot draw its glyphs anyway
([ADR 0012](0012-block-elements-lane.md)). The ASCII lane draws one colour a cell, always as
a foreground, so it meets only the stuck bold. Clearing that (SGR 22 before a dim
foreground that follows a bright one) is a roadmap candidate.

## Amendment — v2.2.0 (a tier with no colour, and a light background)

This ADR remains **Accepted**. `--color` gains a fifth value, and § 5's compositing rule gains
a case. Without them every frame is byte-identical to 2.1.0.

**1. `--color none`.** `--color` is the enum `8 | 16 | 256 | tc | none`, still defaulting to
16. `none` (`KII_TIER_NONE`) is the tier with no colours, and it sends no SGR at all:
- `_kii_sgr_fg` and `_kii_sgr_bg` refuse every code at this tier, including the default
  colour's 39 and 49, so no lane can send an escape at it;
- the ASCII lane, the one lane that takes it, drops the foreground escapes and the row's
  closing SGR 0, which leaves glyphs and newlines ([ADR 0007](0007-rendering-mode-taxonomy.md)
  § v2.2.0);
- the half-block and blocks lanes refuse it as a usage error;
- `--dither` changes nothing at this tier, since nothing is quantized, just as at `tc`.

A frame at `none` sets nothing, so it resets nothing either: it shows in whatever attributes
the terminal already has. An unknown `--color` now reads `kii: --color must be 8, 16, 256, tc
or none`, and `--verbose` reports `→ no color`.

**2. `NO_COLOR` is not read.** The [no-color.org](https://no-color.org) convention asks
programs to drop colour when that variable is set. kii stays environment-blind for 0003's
reason, the reason it does not read `COLORTERM`: the same command must give the same bytes
everywhere. `--color none` is the explicit form. A caller that honours `NO_COLOR` can pass it.

**3. § 5, transparency, under `--invert`.** Partial alpha (128–254) is composited over
**white** when `--invert` is on, and over black otherwise, as before. `--invert` is the ASCII
lane's light-background setting ([ADR 0007](0007-rendering-mode-taxonomy.md) § v2.2.0), so the
image is taken to sit on white. The composite is `255 − ⌊((255 − c) a + 127) / 255⌋`, the
negative's composite over black, negated back, which keeps an inverted frame exactly its
negative's glyphs. The threshold (128) and the mask are unchanged, and a transparent pixel
still has no ink and no colour.
