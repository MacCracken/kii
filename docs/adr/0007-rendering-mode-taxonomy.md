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

The ASCII lane ships as the **floor**: a luminance→ramp mapping with the
standard Rec.709 relative-luminance weights (`0.2126/0.7152/0.0722`,
integer-scaled 54/183/19 ÷256 — a W3C/Wikipedia multi-source standard, not
from any single source). It is **colored by default** (composes with the
color tier) rather than monochrome, matching kii's identity as a color
tool. Scope held to PNG-feature-parity-with-the-default: no new color tier,
no dithering — those remain separate post-v1 items.

**Out of scope (tracked follow-up):** the *advanced* shape-vector glyph
matching from Alex Harri's "ASCII Art Rendering"
(<https://alexharri.com/blog/ascii-rendering>) — per-cell N-D coverage
vectors + nearest-glyph search + directional contrast, which yields
edge-aware `/ \ | -` glyphs. It needs per-glyph coverage data (glyph
rasterization) and is a larger build; if adopted, **the blog must be
attributed** in source + an ADR (its shape-vector + contrast methods are
original to that post). The luminance-ramp floor needs none of that and is
a complete, dependency-free feature on its own.

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
- **Ship the shape-vector matcher now** — rejected for this cut: it needs
  glyph-coverage data / rasterization and a contrast pass — a much larger
  build. The luminance ramp is the correct, complete floor; the advanced
  matcher is a clean follow-up increment on top of it.
- **Monochrome ASCII by default** — rejected: kii is a color tool; colored
  glyphs compose with the color tier and are the richer default. A future
  `--mode ascii` + a "no color" axis can offer monochrome.
