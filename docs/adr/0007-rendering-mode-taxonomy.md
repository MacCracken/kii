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
