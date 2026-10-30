# 05 — The Braille lane (`--mode braille`)

Demonstrates the fourth render lane, new in v2.3.0
([ADR 0013](../../adr/0013-braille-lane.md)). Each cell is one of the 256
Braille Patterns: 2 × 4 dots, each inked or not, in one colour on the
terminal's own background. Its shapes are finer than any other lane's, which
suits logos and line art.

**Why this logo**: its blue (`#1793D1`) has a luma of 125, just under half
brightness. A fixed threshold at 128 inks none of its dots, and the frame
comes out blank. kii inks at one level chosen for the frame from its own ink
histogram (Otsu's method), so the logo is drawn solid. The choice between the
two, a per-cell mean, and error diffusion was made on renders like this one
(ADR 0013 § Decision).

**Tone instead of shape**: add `--dither fs` (or `ordered`) and the dots are
dithered against a fixed mid level. The blue then shows as a half-density
stipple, which is closer to its brightness and further from its shape. This is
the lane's way to draw photographs and gradients.

**Light terminals**: `--invert` makes dark the ink, as in the ASCII lane. The
dots are then exactly those of the image's negative.

**Fonts**: Braille is not in CP437, so the Linux console cannot draw this
frame. How large a font draws its dots decides how dark a full cell (`⣿`)
looks.
