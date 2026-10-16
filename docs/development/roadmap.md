# kii — Roadmap

> **Forward-facing only.** Shipped work is **deleted** from this file rather than
> checked off in place — the record lives in [`../../CHANGELOG.md`](../../CHANGELOG.md)
> (per-release detail) and [`state.md`](state.md) (the current snapshot). If an item
> below has shipped, it should not be here. kii is post-v1; current release **v1.7.0**.

Each release is a single coherent cycle, smallest-first per AGNOS bite-discipline,
that ships a working binary doing demonstrably more than the last. **Versions here
are pinned**: a release takes the items listed under it, and an item moves to another
version only by editing this file. Work that depends on another repo shipping first
has no version until it does (§ Gated on upstream).

## 1.8.0 — Tier 2 colour, and the emit rework

`--color 256` and `--color tc` (24-bit SGR) emit, on both render lanes. It extends an
existing seam: since v1.5.1 `--color` drives a real tier mechanism (`quant_set_tier` in
`src/quant.cyr`). The escape side needs no kii-local code, because darshana (pinned 1.3.0)
carries all four composers: `tty_fg_256_buf` / `tty_bg_256_buf` for 256-colour and
`tty_fg_rgb_buf` / `tty_bg_rgb_buf` for 24-bit. Each has the same reject-and-write-nothing
contract the half-block row already chains. Amends
[ADR 0003](../adr/0003-color-tier-discipline.md)'s tier-1-only stance.

The emit rework changes every frame's bytes, so the other emit changes the v1.6.4 sweep
found ride the same release (one golden-output change, not three):

- **Tier 1 on real 8/16-colour codes.** `--color 8` and `--color 16` emit the 256-colour
  `38;5;N` / `48;5;N` today, which a strict 16-colour terminal or BBS client — the tier-1
  floor's audience — may not parse. Move them to SGR 30–37 / 90–97 and 40–47 / 100–107
  (C-11; ADR 0003's own Consequences promise this).
- **SGR elision.** Skip an fg/bg escape that repeats the previous cell's in the same row
  (per-row state, so each row stays self-contained). Measured 61–87 % smaller output and
  ~2.6× faster over a 9600-baud line, with no visual difference in 128 runs (O-5).
- **Real transparency.** v1.6.4 composites alpha over black; draw a transparent cell in
  the terminal's default colours (SGR 39 / 49) instead, choosing `▀` or `▄` so an opaque
  half keeps its colour.

## 1.9.0 — Tier 2 dithering, and pixel-centre sampling

`--dither none|ordered|fs`: ordered (Bayer) and Floyd-Steinberg error diffusion, on every
colour tier. Orthogonal to `--mode`. Self-contained in the quantize layer. Default stays
`none`, so existing frames do not change.

Same release, because it also changes every downscaled frame: **pixel-centre sampling.**
Nearest-neighbour `sx = dx·W/dst_w` never samples the last source column or row on a
downscale, so a 1-px border shows on the top and left only (C-7). Sample centres,
`((2dx+1)·W) / (2·dst_w)`, which stays in bounds and keeps the identity case. Amends
[ADR 0005](../adr/0005-nearest-neighbor-downscale.md).

## 1.10.0 — ASCII shape-vector refinements

The two pieces deferred from Alex Harri's write-up at v1.3.1:

- **Directional contrast enhancement**: normalize-by-max → power → denormalize on the cell
  vector before matching, to sharpen edges.
- **A k-d-tree lookup** in place of the 27-glyph linear scan.
- **Recreate the coverage-table generator.** `src/ascii.cyr`'s 27-glyph table was
  generated offline (`gen_shape.py`, Liberation-Mono) by a scratch script that is not in
  the repo, so the table cannot be regenerated today (R-12). Check the generator in.

See [ADR 0007](../adr/0007-rendering-mode-taxonomy.md).

## Gated on upstream (1.x, no version until the dependency ships)

- **Progressive-DCT JPEG.** The one remaining format gap. chitra is baseline-only and
  refuses progressive cleanly (`unsupported JPEG feature …`). chitra's own roadmap lists it
  as genuinely open: it needs coefficient buffering across scans, a decode-model change, so
  "revisit only when a consumer demonstrably needs it". It reaches kii on a `[deps.chitra]`
  re-pin, as PNG, baseline JPEG, BMP and GIF did, and kii's side is diagnostics, not decode
  ([ADR 0009](../adr/0009-bmp-gif-via-chitra.md)).
- **PNG past 16 MiB inflated.** `zlib_decompress` still stops at sankoch's 16 MiB
  `DECOMPRESS_MAX_OUTPUT` (unchanged at 2.8.7). The limit is on inflated scanline bytes,
  so a PNG above ~5.6 MP of 8-bit RGB (≈4.2 MP of RGBA; greyscale goes past 16 MP) is
  refused.
  Since v1.6.0 kii says so: `image too large to decode (… 16 MiB ceiling)`. sankoch 2.7.13
  shipped `zlib_decompress_capped`, a caller-set ceiling, and chitra's roadmap pins using
  it to chitra 1.3.0. kii takes it on that re-pin, and the diagnostic then fires only past
  chitra's new ceiling. sankoch is a stdlib leaf, so re-check the cap at every toolchain
  bump.

## Not scheduled (outside kii's control)

- **Cross-terminal verification**: Linux console, xterm, Alacritty, kitty, tmux. Needs a
  human eye on each terminal. kii ships byte-stable, so this can land at any time without
  gating a cut.
- **Marketplace recipe in zugot**: blocked on zugot tooling, not on kii.
- **First BBS / MUD downstream consumer integrated**: a downstream-cycle deliverable. It is
  tracked here only because v1.0 named it. kii is the substrate, and v1.0's ADR-level scope
  keeps consumer integration out of the substrate's releases.

## 2.0 — open

Nothing here is pinned. Each item changes the default output or the CLI surface enough
to need a major, and each earns an ADR when it is scoped.

- **Full Block Elements glyph vocabulary.** Expand the half-block emit from `▀` alone to
  the Unicode Block Elements range (U+2580..U+259F): quarter-blocks (`▘▝▖▗`) for 4-corner
  colour, eighth-blocks (`▁▂▃▄▅▆▇` / `▏▎▍▌▋▊▉`) for sub-cell gradients, shade blocks
  (`░▒▓`). Closes the byte-verbosity and detail gap with chafa measured in
  [`../audit/chafa-comparison.md`](../audit/chafa-comparison.md) (kii emits 5.9×–69× more
  bytes for the same frame). Needs a ~32-arm glyph dispatch plus 4-corner quantize. Trades
  byte-stability for fidelity, so it supersedes
  [ADR 0004](../adr/0004-half-block-floor-glyph.md).
- **Tier 3 — Sixel / Kitty / iTerm2 image protocols.** Direct image-protocol output where
  the terminal supports it, with the half-block and ASCII lanes staying the fallback
  default.

## Out of scope (durable scope guards)

Durable boundaries on what kii is, not a version gate:

- **Format decoders in-repo** — kii does not carry format decoders; it consumes them from
  the `chitra` substrate on a `[deps.chitra]` re-pin. PNG since v1.2.0, baseline JPEG since
  v1.4.0, BMP + GIF since v1.5.0 — the last of which needed no decode change at all, which
  is the anti-goal working as designed. See [ADR 0006](../adr/0006-adopt-chitra-decoder.md),
  [ADR 0008](../adr/0008-jpeg-via-chitra.md) and [ADR 0009](../adr/0009-bmp-gif-via-chitra.md).
- **Animated GIF / video-frame-pipe** — explicit post-v2 scope.
- **Output to non-terminal formats** — no HTML, no SVG. kii is image → ANSI, full stop.
- **Image transformations** — no crop, no rotate, no scale other than fit-to-terminal. Use
  upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live resize, no animation, no scroll. One frame in, one frame
  out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan.
  Loop in the shell.

Captured deferrals become ADRs when the decision crystallizes.
