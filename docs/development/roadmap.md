# kii — Roadmap

> **Forward-facing only.** Shipped work is **deleted** from this file rather than
> checked off in place — the record lives in [`../../CHANGELOG.md`](../../CHANGELOG.md)
> (per-release detail) and [`state.md`](state.md) (the current snapshot). If an item
> below has shipped, it should not be here. kii is post-v1; current release **v1.6.2**.

The roadmap is **smallest-first** per AGNOS bite-discipline: each release is a single
coherent cycle that ships a working binary doing demonstrably more than the last.

## Open debt

Carried since the v1.0 freeze. None blocks a release.

- **Cross-terminal verification** — Linux console / xterm / Alacritty / kitty / tmux.
  Needs a human-eye per-terminal pass; kii ships byte-stable, so this can land any time
  without gating a cut.
- **Marketplace recipe in zugot** — blocked on zugot tooling, not on kii.
- **The test and fuzz/bench entry points exit with a literal `syscall(60, …)`**
  (found during the 1.6.0 release, 2026-10-12): `tests/{ascii,cli,decode,quant,render}.tcyr`,
  `tests/kii.fcyr`, `tests/kii.bcyr`. 60 is `exit` on x86_64 only. On aarch64 it is
  correct today only because the backend rewrites it to 93, and on AGNOS 60 is
  `winsize`. Use the stdlib's `SYS_EXIT` (or `sys_exit`). One exception: if a binary is
  built `--agnos` but run on a Linux host, it needs the host's exit number, as
  darshana's `tests/agnos.tcyr` explains. Check how each build is run before choosing.
- **Three `sankoch` upstream CVE-class transfers** (CVE-2004-0797 / 2005-1849 /
  2005-2096) — file as `sankoch` issues; track impact. Distinct from the
  limitations in the next section, which this repo found itself.
- **First BBS / MUD downstream consumer integrated** — a downstream-cycle deliverable,
  tracked here only because v1.0 named it. It is off kii's own roadmap: kii is the
  substrate, and ADR-level scope is explicit that v1.0 does not bundle consumer
  integration with the substrate ship.

## Upstream: `sankoch` limitations — flagged for later review

Found by the v1.5.1 P-1 sweep, **all in vendored `lib/`**, which kii must not
edit (CLAUDE.md). None is a kii defect and none blocks a kii release; each needs
a decision from the `sankoch` side, and kii should re-check them on every
toolchain bump because `sankoch` ships inside the Cyrius stdlib. **Last
re-verified at the cyrius 6.7.9 pin (kii v1.6.0, sankoch 2.8.3)**: S-1 and S-2
are still open; the third (S-3, the `crc32_table` singleton that `alloc_reset()`
invalidated) is fixed upstream — sankoch's arena canary (`_sankoch_arena_guard`,
2.7.10+) drops every memoized table when the arena is rewound, and a
20,000-cycle decode + `alloc_reset()` probe with kii's workaround removed decoded
every cycle with no pixel byte differing — so it has left this table (CHANGELOG
1.6.0). kii's `crc32_table = 0` beside each fuzz `alloc_reset()` is now
redundant and is kept as a belt-and-braces line.

| # | Item | Where | Impact on kii | Status |
|---|---|---|---|---|
| **S-1** | `_huff_decode` is **O(bits × num_symbols)** — the symbol scan is nested inside the bit-length loop and rescans from the first symbol at every code length, where the canonical `mincode`/`maxcode`/`valptr` form is O(bits). | `lib/sankoch.cyr` `_huff_decode`, slow path (~:1242-1259 at sankoch 2.8.3) | **~93 % of kii's entire end-to-end render time.** It is the single reason RAMGON (1152×925) takes ~660 ms to reach an 80×24 frame; kii's own downscale + quantize + emit are together under 2 %. A drop-in canonical decoder measured **~3.7× end-to-end**, output byte-identical. | Open (re-verified at 6.7.9: unchanged) — highest-value optimization available to kii, and it is not in kii |
| **S-2** | `DECOMPRESS_MAX_OUTPUT` is **16 MiB** (`enum Limits`), far below the 256 MB ceiling kii's own diagnostics advertise. | `lib/sankoch.cyr:67` | Any PNG above **~5.6 megapixels** inflates past the cap and cannot be decoded. The *diagnostic* half is closed: chitra 1.0.1 refuses such a file before allocating, with its own `CHITRA_ERR_INFLATE_LIMIT`, and kii v1.6.0 maps it to `PNG_ERR_INFLATE_LIMIT` — "image too large to decode (… 16 MiB ceiling)" — where v1.5.2 printed "malformed PNG". kii still cannot raise the cap. | Open — the cap is sankoch's; accepted risk |

**Review trigger**: re-verify both at the next `cyrius` pin bump. S-1 is worth
raising as a `sankoch` issue on its own merits — every stdlib consumer that
inflates anything pays for it, not just kii. See
[`docs/audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md) § 5 and
[`docs/benchmarks.md`](../benchmarks.md) § v1.5.1 for the measurements.

## Out of scope (durable scope guards)

Durable boundaries on what kii is (not a v1.0-only gate):

- **JPEG / GIF / BMP decoders in-repo** — kii does not carry format decoders; it consumes them from the `chitra` substrate on a `[deps.chitra]` re-pin. PNG since v1.2.0, baseline JPEG since v1.4.0 (chitra 0.3.0), **BMP + GIF since v1.5.0** (chitra 1.0.0) — the last of which needed no decode change at all, which is the anti-goal working as designed. See [ADR 0006](../adr/0006-adopt-chitra-decoder.md) + [ADR 0008](../adr/0008-jpeg-via-chitra.md) + [ADR 0009](../adr/0009-bmp-gif-via-chitra.md).
- **Animated GIF / video-frame-pipe** — explicit post-v2 scope.
- **Output to stdout-other-than-TTY-styled file formats** — e.g. no HTML output, no SVG output. kii is image → ANSI, full stop.
- **Image transformations** — no crop, no rotate, no scale-other-than-fit-terminal. Use upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live-resize-on-terminal-resize, no animation, no scroll. One frame in, one frame out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan. Loop in the shell.

## Roadmap ahead (not yet committed)

Ordered roughly by readiness. All four input formats (PNG / baseline JPEG / BMP /
GIF-first-frame) and both render lanes (half-block, `--mode ascii`) are done; what
remains is colour fidelity, one more format, richer glyph vocabularies, and one
mechanical rename.

- **Tier 2 — 256-colour + truecolour.** `--color 256` and `--color tc` (24-bit SGR)
  emit, then ordered / Floyd-Steinberg dithering as `--dither` choices. Orthogonal to
  `--mode` (composes with both lanes) and self-contained in the emit/quant layer.
  Amends [ADR 0003](../adr/0003-color-tier-discipline.md)'s tier-1-only stance.
  The `--color` flag already carries a real tier mechanism as of v1.5.1 (`quant_set_tier`
  in `src/quant.cyr`, driven from `main.cyr`), so this extends an existing seam rather
  than cutting a new one. The escape side needs no kii-local code: darshana
  (pinned 1.3.0) carries all four composers it uses — `tty_fg_256_buf` /
  `tty_bg_256_buf` for 256-colour and `tty_fg_rgb_buf` / `tty_bg_rgb_buf` for
  24-bit, each with the same reject-and-write-nothing contract the half-block
  row already chains. **The likeliest next minor.**

- **Progressive-DCT JPEG** — the one remaining format gap. chitra is baseline-only and
  rejects progressive cleanly (`unsupported JPEG feature …`). It lands in chitra first
  and reaches kii on a `[deps.chitra]` re-pin, exactly as PNG, baseline JPEG, BMP and
  GIF did — no in-repo decoder ([ADR 0006](../adr/0006-adopt-chitra-decoder.md)). kii's
  side of that work is diagnostics, not decode, which
  [ADR 0009](../adr/0009-bmp-gif-via-chitra.md) now sets the pattern for.

- **ASCII shape-vector refinements** — the two pieces deferred from Alex Harri's blog at
  v1.3.1: **directional contrast enhancement** (normalize-by-max → power → denormalize
  on the cell vector before matching, sharpening edges) and a **k-d-tree** lookup to
  replace the 27-glyph linear scan. See [ADR 0007](../adr/0007-rendering-mode-taxonomy.md).

- **Format-neutral rename of the image front-end.** Rename `kii_decode_png` →
  `kii_decode_image`, `src/png.cyr` → `src/image.cyr`, and the `PNG_ERR_*` code space →
  `IMG_ERR_*`. Measured blast radius: **28 distinct symbols across 290 call sites** (one more
  since, `PNG_ERR_INFLATE_LIMIT` at v1.6.0) in 4
  source and 5 test files, plus 10 `include "src/png.cyr"` sites. Deferred at v1.4.0 and
  again at v1.5.0 to keep those cuts tight and byte-identical-verifiable; the v1.5.1 P-1
  sweep judged it **materially overdue** — the names now cover four formats and actively
  mislead. It is mechanical and fully test-covered, but it is a wide diff with no
  behaviour change, so it wants its own cut rather than a ride-along. **Take it at the
  next minor.** See [ADR 0008](../adr/0008-jpeg-via-chitra.md) § Error-space + naming.

- **Full Block Elements glyph vocab** (v2.0.0) — expand the half-block emit from `▀`
  alone to the Unicode Block Elements range (U+2580..U+259F): quarter-blocks (`▘▝▖▗`)
  for 4-corner colour, eighth-blocks (`▁▂▃▄▅▆▇` / `▏▎▍▌▋▊▉`) for sub-cell gradients,
  shade blocks (`░▒▓`). Closes the byte-verbosity and detail gap with chafa measured in
  [`../audit/chafa-comparison.md`](../audit/chafa-comparison.md) (kii emits 5.9×–69×
  more bytes for the same frame). Needs a ~32-arm glyph dispatch plus 4-corner quantize;
  trades byte-stability for fidelity — earns a new ADR superseding
  [ADR 0004](../adr/0004-half-block-floor-glyph.md) when scoped.

- **Tier 3 — Sixel / Kitty / iTerm2 protocols** (v2.0.0) — direct image-protocol output
  where the terminal supports it, with the ASCII/half-block lanes staying the fallback
  default. Possibly a major cut depending on CLI-surface impact.

Captured deferrals become ADRs when the decision crystallizes.
