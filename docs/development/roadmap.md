# kii — Roadmap

> **Forward-facing only.** Shipped work is **deleted** from this file rather than
> checked off in place — the record lives in [`../../CHANGELOG.md`](../../CHANGELOG.md)
> (per-release detail) and [`state.md`](state.md) (the current snapshot). If an item
> below has shipped, it should not be here. Current release **v2.0.0**; 2.0.1 through
> 2.6.0 are pinned below.

Each release is a single coherent cycle, smallest-first per AGNOS bite-discipline,
that ships a working binary doing demonstrably more than the last. **Versions here
are pinned**: a release takes the items listed under it, and an item moves to another
version only by editing this file. Work that depends on another repo shipping first
has no version until it does (§ Gated on upstream). Work that needs a decision or
evidence before it can be sized is a candidate (§ Candidates), not a pin.

Two rules hold for every 2.x release:
- **The default output does not change by surprise.** `kii image.png` stays the
  half-block lane at 16 colours ([ADR 0004](../adr/0004-half-block-floor-glyph.md),
  CLAUDE.md § Domain-specific rules). Every new lane or protocol is opt-in. A release
  that changes default bytes says so with ⚠ in the CHANGELOG and measures it over the
  corpus, as 1.8.0, 1.9.0 and 1.11.0 did.
- **kii stays environment-blind.** No lane, tier or protocol is picked from `TERM`,
  `COLORTERM` or a terminal query: the caller names it. Output depends only on the
  arguments, the image and the terminal's size.

## 2.0.1 — release engineering

No frame changes; every output byte-identical to 2.0.0.
- **CI builds and tests aarch64**: `cyrius build --aarch64` and `cyrius test --aarch64`
  as steps. They are run by hand at every cut today.
- **Release notes from the CHANGELOG**: the release workflow extracts the version's
  section rather than leaving the notes empty.
- **Multi-arch release binaries**: x86_64, aarch64 and `--agnos`.
- **A bench build in CI** (`tests/kii.bcyr` compiled, not timed), so a bench that stops
  compiling is caught.
- **Dead-code elimination for release binaries.** The compiler reports ~585 KB of
  unreachable functions. Build with `CYRIUS_DCE=1`, and ship it only if every frame of
  the corpus is byte-identical to the plain build.
- The cosmetic `cyrius-kii` comment in `ci.yml`.

## 2.1.0 — the half-block lane reuses its colour state

The half-block lane always draws `▀` with the top in front. The blocks lane (2.0.0)
draws whichever of a glyph and its complement needs fewer colour escapes, and a cell whose
two halves are one colour as a space or `█`. The half-block lane gains the same choice:
`▀` or `▄`, and a space or `█` for flat cells.
- **Visually identical, fewer bytes.** Every cell shows the same two colours in the same
  places; only the encoding changes. [ADR 0004](../adr/0004-half-block-floor-glyph.md)
  named this "possible v1.x optimization".
- ⚠ **It changes the default lane's bytes.** That is acceptable only with the corpus
  showing every frame decodes to the same cell colours (a rasterized comparison) and the
  byte saving per tier. ADR 0004 is amended with both.

## 2.2.0 — the ASCII lane on light backgrounds, and without colour

The ASCII lane reads brightness as ink, which assumes light text on a dark terminal. On a
light background its art comes out as a negative.
- **`--invert`**: darkness is ink. It applies to the ASCII lane only; half-block and blocks
  draw colours, not ink.
- **A colourless ASCII form** (`--color mono` or similar, named when scoped): glyphs only,
  no SGR at all, the classic `jp2a` output for pipes, logs and mail.
- An ADR amendment to [0007](../adr/0007-rendering-mode-taxonomy.md), and to
  [0010](../adr/0010-tier-2-colour-and-emit-encoding.md) for the tier.

## 2.3.0 — the Braille lane (`--mode braille`)

The Braille Patterns block (U+2800..U+28FF) gives 2 × 4 dots per cell in one colour, the
finest shape of any widely supported glyph set. [ADR 0004](../adr/0004-half-block-floor-glyph.md)
set it aside as post-v2; it suits line art and one-colour images more than photographs.
- Reuses the blocks lane's sampler (an 8 × 8 grid per cell reduces to 2 × 4).
- One foreground colour per cell, the mean of the inked dots; the background is the
  terminal's default.
- The threshold between ink and paper is the decision the ADR has to make (a fixed
  level, the cell's own mean, or an error-diffused one).

## 2.4.0 — Tier 3: iTerm2 inline images (`--mode iterm`)

The first image protocol, and the smallest: OSC 1337 `File=` with the image's own bytes,
base64-encoded, sized in cells. iTerm2 (and WezTerm, which reads the same protocol) decode
PNG, JPEG, GIF and BMP themselves, so kii sends the file it read rather than re-encoding.
- An ADR for Tier 3 as a whole: how a protocol is chosen (by flag, never by detection),
  what a protocol lane promises when the terminal ignores it (nothing: no fallback inside
  one run), and how cell sizing maps to each protocol.
- The decoded image still goes through chitra, so a file kii cannot decode is refused
  exactly as in the other lanes.

## 2.5.0 — Tier 3: the Kitty graphics protocol (`--mode kitty`)

APC `_G` transmissions of the decoded RGBA8 (`f=32`), base64 in 4096-byte chunks, placed
over the frame's cells (`c=`, `r=`). No encoder is needed. Transparency survives, which no
cell lane can show.

## 2.6.0 — Tier 3: Sixel (`--mode sixel`)

The oldest protocol and the widest (xterm with `-ti vt340`, mlterm, foot, WezTerm, and
others): pixels as six-row bands in up to 256 registers.
- kii encodes it itself: the 256-colour quantizer (and `--dither`) gives the registers,
  and each band is run-length encoded.
- Sixel is drawn in device pixels, so it needs the cell's pixel size: from the terminal
  when darshana exposes it (§ Gated on upstream), else a `--cell-size` default.

## Gated on upstream (no version until the dependency ships)

- **Progressive-DCT JPEG** (chitra). chitra is baseline-only and refuses progressive
  cleanly (`unsupported JPEG feature …`). Its roadmap lists it as a 1.x candidate needing
  coefficient buffering across scans. It reaches kii on a `[deps.chitra]` re-pin, as PNG,
  baseline JPEG, BMP and GIF did; kii's side is diagnostics, not decode
  ([ADR 0009](../adr/0009-bmp-gif-via-chitra.md)).
- **SOF1 extended-sequential JPEG, 8-bit Huffman** (chitra). Also a chitra 1.x candidate;
  the same re-pin path.
- **The terminal's cell aspect** (darshana). kii assumes cells are twice as tall as wide.
  `TIOCGWINSZ` also reports the window's pixel size, which gives the real ratio on most
  graphical terminals, but darshana's `tty_winsize` reads only rows and columns. Once it
  exposes the pixel fields, kii fits images to the measured aspect (falling back to 2:1
  where the fields are 0, as on the Linux console) and Sixel gets its pixel size.
- **Peak memory when reading a file** (cyrius stdlib). `file_read_whole_max` keeps the
  buffers it outgrows, so reading a file costs 2–4× its size
  (`cyrius/docs/development/issues/2026-10-28-file-read-whole-keeps-outgrown-buffers.md`).
  kii gets the fix on a toolchain re-pin. If upstream declines it, the fallback is
  kii-side: size the buffer from `fstat` first, measured at 1.00×.

## Candidates (need a decision or evidence before a pin)

- **Linear-light averaging.** The area sampler and every colour mean average sRGB values,
  which darkens mixes of light and dark (a black and white checkerboard averages to 128,
  not the ~188 that has the same light). Averaging in linear light is more correct but
  changes every reduced frame in every lane. It needs a corpus measurement and an ADR.
- **Perceptual colour distance** (weighted RGB or Oklab) for the nearest-colour search.
  CLAUDE.md names nearest-RGB as the default; a change touches every quantized frame.
- **Sextants and octants** (Symbols for Legacy Computing, U+1FB00 and Unicode 16's
  octants): 2 × 3 and 2 × 4 shapes in two colours, finer than Block Elements. Font support
  is still thin; worth a lane only when common terminal fonts carry them.
- **Quantization-aware shapes in the blocks lane.** 2.0.0 chooses a cell's shape from its
  exact colours and quantizes after. Scoring each shape with its quantized colours would
  suit tiers 8 and 16 better, at about 40 nearest-colour searches a cell.
- **`--height N`**, the counterpart of `--width`. Today the height is set only by the
  terminal's rows or by the image's aspect.
- **`-` for standard input** as a path. `/dev/stdin` works today; `-` is the usual
  spelling.
- **A man page, `kii(1)`**, and shell completions generated from the cmdit flag table.

## Not scheduled (outside kii's control)

- **Cross-terminal verification**: Linux console, xterm, Alacritty, kitty, tmux, now for
  three lanes. The blocks lane needs it most: quadrants (U+2596..U+259F) and the eighths
  are not in CP437, so a console font may not carry them. It needs a human eye on each
  terminal; kii ships byte-stable, so it can land at any time without gating a cut.
- **Marketplace recipe in zugot**: blocked on zugot tooling, not on kii.
- **First BBS / MUD downstream consumer integrated**: a downstream-cycle deliverable. It is
  tracked here only because v1.0 named it. kii is the substrate, and v1.0's ADR-level scope
  keeps consumer integration out of the substrate's releases.

## Out of scope (durable scope guards)

Durable boundaries on what kii is, not a version gate:

- **Format decoders in-repo** — kii does not carry format decoders; it consumes them from
  the `chitra` substrate on a `[deps.chitra]` re-pin. PNG since v1.2.0, baseline JPEG since
  v1.4.0, BMP + GIF since v1.5.0 — the last of which needed no decode change at all, which
  is the anti-goal working as designed. See [ADR 0006](../adr/0006-adopt-chitra-decoder.md),
  [ADR 0008](../adr/0008-jpeg-via-chitra.md) and [ADR 0009](../adr/0009-bmp-gif-via-chitra.md).
  (Sixel, 2.6.0, is a terminal protocol kii writes, not an image format it decodes.)
- **Animated GIF / video-frame-pipe** — out of scope through 2.x: an animation is many
  frames on a clock, which is interactive mode (below). The first frame renders, as today.
- **Output to non-terminal formats** — no HTML, no SVG. kii is image → terminal, full stop.
- **Image transformations** — no crop, no rotate, no scale other than fit-to-terminal. Use
  upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live resize, no animation, no scroll. One frame in, one frame
  out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan.
  Loop in the shell.
- **Terminal detection** — no protocol, tier or lane chosen from the environment or by
  querying the terminal (§ the two rules above).

Captured deferrals become ADRs when the decision crystallizes.
