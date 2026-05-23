# 0003 — Color-tier discipline: tier-1 (8/16-color) only at v1.0

**Status**: Accepted
**Date**: 2026-05-23

## Context

kii's color-output choices span a wide range of fidelity / compatibility
tradeoffs. The full menu, by what terminals actually support:

| Tier | Output bytes | Terminal support |
|---|---|---|
| 1a | 8-color SGR (30–37 fg / 40–47 bg) | every VT100-compatible terminal since 1978 |
| 1b | 16-color SGR (+ bright variants 90–97 / 100–107) | every modern Linux console, xterm, all DEC-descendant emulators |
| 2a | 256-color SGR (`38;5;N` / `48;5;N`) | xterm-256color, ~all modern emulators (~2010+) |
| 2b | 24-bit truecolor SGR (`38;2;R;G;B` / `48;2;R;G;B`) | most modern emulators with `COLORTERM=truecolor` |
| 3a | Sixel (`ESC P q ... ESC \`) | xterm with `--enable-sixel-graphics`, mlterm, foot, wezterm |
| 3b | Kitty graphics protocol (`ESC _ G ... ESC \`) | kitty, ghostty (in-progress) |
| 3c | iTerm2 inline-image (`ESC ] 1337 ; File=... BEL`) | iTerm2, WezTerm |

kii's framing question: which subset does v1.0 commit to?

Two constraints shape the answer:

1. **Use case is BBS / MUD aesthetic**. The historically-correct
   rendering target for the cycle kii was scoped against (early-90s
   BBS clients, mid-90s MUD clients) is 8/16-color ANSI half-block.
   Going higher than 16 color is *anachronistic* to the corpus, not
   just unnecessary.
2. **Security surface grows with tier**. Tier-2 widens the SGR
   parameter space (numeric range from [0,15] to [0,255] or
   [0,255]³). Tier-3 moves into the same OSC / DCS opcode family as
   CVE-2017-14146 / CVE-2026-41253 / CVE-2022-44702 attack classes;
   any kii emit of those payloads needs its own threat model
   (see [`0002-security-model.md`](0002-security-model.md) § Tier-3
   expansions).

## Decision

**v1.0 commits to tier-1 (8/16-color SGR) only.** Specifically:

- `--color 16` (default) emits 256-color SGR escapes (`48;5;N`)
  where N is bound-checked against the 16-color ANSI palette via
  `palette.cyr` — this gives 16-color fidelity using the broadly-
  compatible 256-color escape sequence, sidestepping `TERM=linux`
  console's 8-color limit in practice while staying within the
  16-color *visual* contract.
- `--color 8` (opt-in) is reserved in the CLI flag-surface for the
  pure SGR 30-37/40-47 path; activation deferred to v1.x if/when a
  consumer needs it (no current consumer; CLAUDE.md flag-table
  documents the reservation).
- Tier-2 (256-color, truecolor, dithering) is **post-v1**.
- Tier-3 (Sixel, Kitty, iTerm2 inline) is **post-v2**.

The CLI flag `--color N` is frozen at 8 / 16 only at v1.0;
`--color 256` / `--color tc` lands at v1.1 (Tier 2) with new
sub-ADRs covering dither selection.

## Consequences

**Positive**:

- **Maximum terminal compatibility** at v1.0. Linux console, every
  xterm-descendant, every tmux/screen multiplexer renders kii output
  correctly. No emit byte requires a terminal feature less than 30
  years old.
- **Smallest attack surface**. tier-1 emit is the SGR-only subset
  documented in ADR 0002 (`48;5;N`/`38;5;N` with N bound-checked);
  zero OSC, zero DCS, zero APC, zero PM. Eliminates the CVE-2017-14146
  / CVE-2026-41253 / CVE-2022-44702 attack class structurally.
- **Stable visual contract**. A `kii img.png > frame.ansi` at v0.6
  reproduces byte-for-byte at v1.0; downstream consumers' captured
  fixtures don't break across kii minor cuts.
- **Aesthetic fit**. The BBS / MUD revival corpus is 8/16-color by
  design; tier-2 fidelity would *break* the aesthetic, not improve
  it. (A 256-color "photographic" rendering of a MOTD splash looks
  wrong against the surrounding 16-color UI chrome.)

**Negative**:

- **No photographic fidelity at v1.0**. A high-color-depth source
  PNG quantizes hard into 16 buckets; subtle gradients get banded.
  Users who want photographic terminal display today must use chafa
  or viu instead. Documented in README + getting-started.
- **`--color 8` reservation without activation**. The flag is
  defined but currently equivalent to `--color 16` (both route
  through the same 256-color-escape-of-16-palette path). Eventual
  activation requires a `palette.cyr` 8-color variant + a code path
  branch. Captured as a v1.x bite when a consumer asks.

**Neutral**:

- **Tier-2 requires new ADRs**, not just code. Dithering algorithm
  choice (Floyd-Steinberg vs ordered/Bayer), gamma handling, sRGB
  awareness, and the truecolor-vs-256-color cutoff are all
  decisions that need explicit capture at v1.1 cycle start.
- **`COLORTERM` environment variable not consulted**. tier-2 work
  would change that — runtime detection of `truecolor` would auto-
  upgrade the emit path. At v1.0 kii is deliberately
  environment-blind.

## Alternatives considered

- **Ship tier-2 (256-color + truecolor) at v1.0**. Rejected as
  premature: would require dither algorithm selection (Floyd-Steinberg
  vs ordered/Bayer), gamma-correct quantization, sRGB-table lookup,
  and `COLORTERM` runtime detection — each their own decision. The
  v1.0 ship date matters more than the fidelity gain; defer to v1.1.
- **Ship tier-3 (Sixel / Kitty graphics) at v1.0**. Rejected on
  security grounds: tier-3 emit moves kii into the OSC/DCS opcode
  family responsible for the dominant CVE class against terminal
  emulators (see [audit doc § 3.4](../audit/2026-05-22-audit.md)).
  Doing it correctly requires the kind of threat modeling that ADR
  0002 captures for stdin, applied to a much wider emit surface.
- **`--color auto` with `COLORTERM`-based runtime promotion**.
  Considered for v1.0; rejected because it conflicts with the
  "byte-stable across runs" invariant. A pipeline that produces
  16-color output in CI and 256-color output on the dev box would
  produce diff-noisy fixtures. v1.x with `--color auto` as opt-in
  is the right place.
- **Drop `--color 8` from the surface entirely** (reduce to just
  `--color 16`). Rejected because the M1 flag-surface was frozen at
  v0.2.0 and unfreezing breaks the user contract; the `--color 8`
  flag is accepted today and produces identical output to `--color
  16`. Activation lands when a consumer asks.

## Trigger for revisit

- A first BBS/MUD downstream consumer asks for tier-2 (more likely
  to be ordered-Bayer dithered 256-color than truecolor, given the
  aesthetic).
- A terminal with native sixel support becomes the project's
  primary dev environment (currently: xterm-256color via kitty).
- Cross-terminal verification at M8 close reveals `TERM=linux`
  rendering bugs that require an SGR 30-37 fallback path; activates
  the dormant `--color 8`.

## References

- [`../../CLAUDE.md`](../../CLAUDE.md) § Color-tier discipline (durable)
- [`0002-security-model.md`](0002-security-model.md) § Tier-3 expansions
- [`../audit/2026-05-22-audit.md`](../audit/2026-05-22-audit.md) § 3.4 terminal-emulator CVEs
