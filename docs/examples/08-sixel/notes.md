# 08 — Sixel (`--mode sixel`)

Demonstrates Tier 3's third protocol, new in v2.6.0
([ADR 0014](../../adr/0014-tier-3-image-protocols.md) § v2.6.0). Unlike the
iTerm2 and kitty lanes, which send a PNG for the terminal to scale, Sixel is drawn
in device pixels from at most 256 colour registers, so kii encodes it:

1. **Pixel size.** The cell box (here 40 columns, the rows from the image's aspect)
   times the cell's size in pixels. kii cannot measure that yet, so it is
   `--cell-size`, `10x20` by default. A wrong size makes the image larger or
   smaller than the box, never distorted.
2. **Resample and quantize.** The area sampler brings the image to 400 x 400, and
   the 256-colour quantizer (or `--color 8` / `16`, with `--dither`) gives each
   pixel a register.
3. **Encode.** Six-row bands, one colour at a time, runs as `!n<char>`.
   Transparent pixels are never drawn, so the terminal's background shows (`P2 = 1`).

**Checked**: a Sixel decoder written from the VT340 manual, independent of kii's
encoder, reads this frame back as 400 x 400 with five registers and 119,419 unset
(transparent) pixels; across the corpus, every frame decodes to exactly the
pixels kii's pipeline produced.

**Quality**: the registers come from a fixed palette, so a flat colour like this
logo's blue lands on its nearest palette entry; a palette fitted to the image
(chafa's way) would be closer. That is a roadmap candidate.
