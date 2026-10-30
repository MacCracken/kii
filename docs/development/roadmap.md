# kii — Roadmap

> **Forward-facing only.** Shipped work is **deleted** from this file rather than
> checked off in place — the record lives in [`../../CHANGELOG.md`](../../CHANGELOG.md)
> (per-release detail) and [`state.md`](state.md) (the current snapshot). If an item
> below has shipped, it should not be here. Current release **v2.6.0**. Every 2.x pin has
> shipped, Tier 3 with it; what remains is gated on upstream, a candidate, or unscheduled.

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
  corpus, as 1.8.0, 1.9.0, 1.11.0 and 2.1.0 did.
- **kii stays environment-blind.** No lane, tier or protocol is picked from `TERM`,
  `COLORTERM` or a terminal query: the caller names it. Output depends only on the
  arguments, the image and the terminal's size.

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
  where the fields are 0, as on the Linux console). Sixel then takes its cell size from them;
  until then it uses `--cell-size` (2.6.0, default 10x20), and the image protocols could send
  no more pixels than the box shows (§ Candidates).
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
- **The fewest bytes per row, exactly.** Both cell lanes choose each cell's encoding greedily,
  from the colours the row has set so far. The exact minimum over every encoding of the same
  colours is a shortest path over the colour state (at most 13 states a row at tier 16 on a
  40-image sample, 139 at truecolour). On that sample, at tier 16 and `--width 80`, the
  plain greedy rule saved 50.9 % of 2.0.1's bytes and the exact one 55.3 % (2.1.0's bright
  rule, which constrains the choice, was not measured this way). It would change the default
  lane's bytes again, so it needs the same corpus proof as 2.1.0.
- **The Linux console's stuck bold.** The console draws SGR 90–97 by setting bold, and a later
  30–37 does not clear it, so a dim foreground after a bright one in the same row shows
  bright ([ADR 0010](../adr/0010-tier-2-colour-and-emit-encoding.md) § v2.1.0). Folding SGR 22
  into such an escape (`22;31`) fixes it: modelled on the corpus, the half-block lane's wrong
  halves at tier 16 go from 0.80 % to 0.34 % for 0.2 % more bytes. The ASCII lane draws only
  foregrounds, so every bright-to-dim change in its rows meets it (not measured). It is a new
  escape form, which darshana has no
  composer for, and a byte change to the default lane.
- **The fuzz generator's low bits.** `_fuzz_rand` returns the whole 32-bit LCG state, whose low
  bits repeat (bit 0 every 2 draws, the low byte every 256), and most surfaces take
  `_fuzz_rand() % n` or `& 255`. The blocks and area surfaces' random images are therefore a
  256-byte pattern, repeated. The half-block surface (2.1.0) draws from bits 16 and up, after
  the low bits hid a planted defect from it. Changing the shared generator changes every
  surface's random stream, so the fix should be one release, with each surface re-checked
  against its planted defects.
- **iTerm2 images inside tmux.** tmux drops an OSC it does not know. iTerm2 3.5's
  `MultipartFile` form works in its tmux integration, and a DCS-wrapped passthrough works where
  tmux's `allow-passthrough` is on. kii sends the single `File=` form and does not know when it
  is inside tmux, so either would be a flag (ADR 0014).
- **An adaptive palette for Sixel.** Sixel's registers can hold any colours, and 2.6.0 fills
  them from the fixed xterm 256-colour palette, as the roadmap pinned. On the Arch logo that
  errs by 14.1 a channel where chafa's palette, fitted to the image, errs by 4.4 (ADR 0014
  § v2.6.0). A median-cut or octree palette per frame is a new quantizer, and it would change
  every Sixel frame.
- **The kitty lane's blank line at full width.** When the image fills the terminal's width,
  kitty moves the cursor to the next line itself, and the LF kii writes after the image then
  leaves a blank line. kii does not know the terminal's width under `--width N`; in fit mode it
  does, so it could leave the LF out there. It was seen with kitty's own parser (ADR 0014
  § v2.5.0); other terminals that read the protocol may move the cursor differently.
- **The image protocols at the cell box's pixel size.** `--mode iterm` and `--mode kitty` send the
  decoded image at its own resolution, and the terminal scales it; a 1-megapixel image costs about 0.65 s to
  write. With the cell's pixel size (§ Gated on upstream, darshana) kii could send no more pixels
  than the box shows.
- **The Braille lane's level by hand** (`--threshold N` or similar). The lane inks dots at one
  level per frame, Otsu's ([ADR 0013](../adr/0013-braille-lane.md)), so the same picture at
  another width, or a set of frames meant to match, may get different levels. A fixed level
  is the obvious override; whether callers need it is not known.
- **The directory diagnostic on agnos.** Run under mirshi, the agnos build reports a
  directory as `cannot open file`, not `is a directory, not an image file`: kii recognizes a
  directory by the read's `EISDIR`, and the agnos read error does not carry it (found at
  2.0.1). Whether the agnos kernel reports it, or mirshi drops it in translation, decides
  whether the fix is kii's (an `fstat` before the read) or upstream's.

## Not scheduled (outside kii's control)

- **Cross-terminal verification**: Linux console, xterm, Alacritty, kitty, tmux, now for
  four lanes. The blocks and Braille lanes need it most: quadrants (U+2596..U+259F), the
  eighths and the Braille Patterns are not in CP437, so a console font may not carry them,
  and how large a font draws a Braille dot decides how dark a cell of dots looks. It needs a human eye on each
  terminal; kii ships byte-stable, so it can land at any time without gating a cut. The
  Linux console can also be read back: `/dev/vcsaN` holds each cell's glyph and attribute,
  which would check 2.1.0's console model against the kernel itself (it needs root).
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
