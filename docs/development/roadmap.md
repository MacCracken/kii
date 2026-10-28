# kii — Roadmap

> **Forward-facing only.** Shipped work is **deleted** from this file rather than
> checked off in place — the record lives in [`../../CHANGELOG.md`](../../CHANGELOG.md)
> (per-release detail) and [`state.md`](state.md) (the current snapshot). If an item
> below has shipped, it should not be here. kii is post-v1; current release **v1.10.0**. No 1.x release is pinned after it.

Each release is a single coherent cycle, smallest-first per AGNOS bite-discipline,
that ships a working binary doing demonstrably more than the last. **Versions here
are pinned**: a release takes the items listed under it, and an item moves to another
version only by editing this file. Work that depends on another repo shipping first
has no version until it does (§ Gated on upstream).

## Gated on upstream (1.x, no version until the dependency ships)

- **Progressive-DCT JPEG.** The one remaining format gap. chitra is baseline-only and
  refuses progressive cleanly (`unsupported JPEG feature …`). chitra's own roadmap lists it
  as genuinely open: it needs coefficient buffering across scans, a decode-model change, so
  "revisit only when a consumer demonstrably needs it". It reaches kii on a `[deps.chitra]`
  re-pin, as PNG, baseline JPEG, BMP and GIF did, and kii's side is diagnostics, not decode
  ([ADR 0009](../adr/0009-bmp-gif-via-chitra.md)).

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
