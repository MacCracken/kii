# 0002 — Security model: untrusted-image input + restricted-emit posture

**Status**: Accepted
**Date**: 2026-05-23

## Context

kii reads attacker-controllable image files (PNG at v1.0; JPEG / GIF /
BMP at v1.x) and writes ANSI escape sequences to attacker-readable
terminals (stdout, stderr). Both surfaces are historically high-CVE:
libpng has shipped ~40 advisories since 2010; terminal emulators
shipped ~25 ANSI-escape-injection CVEs in the same window. M7's audit
([`../audit/2026-05-22-audit.md`](../audit/2026-05-22-audit.md)) walked
both corpora and extracted a hardening checklist; this ADR captures
the threat model + commitments + accepted residual risks that drive
those decisions.

The decision space is shaped by three constraints:

1. **Stdlib substrate is shared** (sankoch DEFLATE, darshana ANSI
   primitives). Bugs in the substrate are upstream's problem; kii's
   defense is at the perimeter (IHDR validation, output-byte
   restriction).
2. **Tier-1 floor is BBS-era 8/16-color half-block ANSI**. The emit
   surface is structurally narrow — kii commits to emitting a strict
   subset of CSI SGR (0 / 38;5;N / 48;5;N with bound-checked
   N ∈ [0,255]), half-block glyphs (`▀`/`▄`), spaces, newlines. No
   OSC, no DCS, no APC, no PM. This eliminates entire CVE classes
   structurally.
3. **No file writes, no process spawn, no network, no persistent
   state**. kii's interface is `(args + image file) → stdout ANSI`,
   exit. Privilege model is whatever the invoking shell user has.

## Decision

kii's security model is **defense-at-perimeter + restricted emit**:

- **Inbound (image input)**: every byte parsed from the IHDR / PLTE /
  IDAT chunks is validated before any allocation depends on it.
  Compile-time policy ceilings (KII_MAX_PIXELS, KII_MAX_RAW_BYTES,
  KII_MAX_DIM) cap the largest single allocation kii will ever
  request. The PNG spec table § 11.2.2 is enforced as an allow-list.
  IDAT-accumulator and compression-ratio caps defend against
  decompression-amplification (zip-bomb) attacks.
- **Outbound (stdout / stderr)**: stdout emits only the restricted
  ANSI subset above, with all parameters bound-checked at quantize
  time. stderr routes user-controlled bytes (path arguments) through
  `kii_path_has_control_bytes` and substitutes when control bytes
  are detected, defending against the CVE-2021-25743 / DECRQSS-echoback /
  OSC-injection class.
- **Threat model boundary**: bugs in downstream terminal emulators
  that misparse or execute on kii's emitted byte stream are
  **outside kii's threat model** (the kii output is a constrained
  subset; downstream emulator bugs are upstream's). Bugs in sankoch
  / darshana are upstream's; kii catches symptoms at its boundary
  (output-size mismatch → PNG_ERR_INFLATE) but does not attempt to
  fix substrate causes.

The specific hardening commitments (per M7(c) hardening commits C1–C4
in `../audit/2026-05-22-audit.md` § 4):

| # | Defense | Code |
|---|---|---|
| C1 | Stderr path-echo sanitization | `kii_path_has_control_bytes` (src/cli.cyr) + `_eprint_path_safe` (src/main.cyr) |
| C2 | IHDR dimension caps (4096² pixels, 65535 per-side, 256 MB inflated) | `PNG_ERR_DIMENSIONS` (src/png.cyr) |
| C2 | PNG § 11.2.2 cross-product enforcement | color_type=3 + bit_depth=16 reject (src/png.cyr) |
| C3 | IDAT-accumulator absolute cap (256 MB) | `PNG_ERR_IDAT_TOO_LARGE` (src/png.cyr) |
| C3 | Compression-ratio cap (1100:1, above DEFLATE's 1032:1 ceiling) | `PNG_ERR_RATIO_TOO_HIGH` (src/png.cyr) |
| C4 | Chunk-ordering: duplicate PLTE + PLTE-after-IDAT rejected | `seen_plte` / `idat_count` checks in png_decode_structure walker |

Coverage: fuzz harness scaled to 3M+ iterations across five surfaces
(arg-parser / path-sanitizer / geometry / emit-pipeline / png-decoder);
470 unit-test assertions verify each cap and rejection path.

## Consequences

**Positive**:

- **Eliminated CVE classes**: by rejecting Adam7 interlacing, sub-byte
  bit depths, ancillary chunks (tEXt/iTXt/zTXt/iCCP/eXIf/sCAL), and
  APNG, kii structurally cannot ship any bug whose root cause lives
  in those code paths. ~60 % of lodepng's published bug surface is
  inaccessible at v1.0.
- **Bounded resource consumption**: an attacker-supplied PNG can
  allocate at most ~256 MB and decode in at most ~5–6 s on the
  reference host. Both are inside any reasonable DoS window.
- **Stdout is byte-pure** by construction: a `kii img.png > out.ansi`
  pipeline produces a deterministic, attack-byte-free file regardless
  of input maliciousness. Suitable for downstream consumers (BBS
  banners, MUD rooms, MOTD splashes) that themselves may not validate
  the bytes they relay.
- **stderr is sanitized**: a malicious filename can no longer hijack
  the user's terminal via OSC / DECRQSS / window-title injection.

**Negative**:

- **Some legitimate images rejected**: ultra-high-resolution PNGs
  (> 4096² pixels) are now refused at IHDR. Wallpaper-class images
  exceeding this cap (e.g. 8K screenshots) need pre-downscaling via
  ImageMagick before piping into kii. This is a deliberate tradeoff;
  the BBS-era use case doesn't need 4K+ inputs.
- **Cycle of distrust between layers**: the multi-layer cap design
  (IHDR-dimensions cap → idat_total cap → ratio cap → sankoch
  output-cap) is defense-in-depth but adds branches per decode.
  Cost is negligible (microseconds) but the code surface is larger.
- **Carries new error codes** (PNG_ERR_DIMENSIONS / IDAT_TOO_LARGE /
  RATIO_TOO_HIGH). main.cyr's dispatch table grows by three entries
  with user-facing messages. Each must remain accurate as the caps
  evolve.

**Neutral**:

- **Future post-v1 expansions need re-audit**: any addition of
  tEXt/iTXt/zTXt decode (post-v1 PNG metadata), Sixel / Kitty /
  iTerm2 image-protocols (tier-3), or new image formats (JPEG / GIF /
  BMP at v1.x) reopens emit surfaces and requires a new audit pass
  with the same shape as M7. CLAUDE.md § Domain-specific rules
  documents the spec-only-feature-set discipline that enforces this.
- **Three sankoch upstream items** filed during the audit
  (CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers). kii's
  pre-inflate caps reduce the impact, but a sankoch-internal Huffman-
  table-construction bug would still be a finding; tracked as gate
  for kii v1.0 release.
- **Decode-latency content-dependency** (the bench surprise where
  2048²-class is faster than 1024²-class on test fixtures) means
  worst-case DoS bound is content-driven, not dimension-driven. The
  256 MB / 4096² cap is the absolute backstop regardless.

## Alternatives considered

- **Per-PNG-chunk-type length cap table** (libpng CVE-2017-12652).
  Considered for M7(c); deferred to M8. The IDAT cumulative cap
  (Finding 2) covers the high-leverage OOM case; per-chunk caps for
  IHDR / IEND would catch trivially malformed inputs at slightly
  earlier signal, but those already trip CRC32 / structure failures.
  Net value: marginal; defer.
- **Outright reject color_type=3 (palette PNGs) at v0.8**. Audit's
  initial recommendation; reversed after code re-read showed
  `downscale.cyr:73` and `quant.cyr:129` both bounds-check PLTE
  index access and substitute black on OOB. No feature regression
  needed.
- **Stricter C1 0x80–0x9F (C1 control range) rejection in path-echo
  sanitizer**. Considered and rejected — would break UTF-8 paths
  (AGNOS naming surface uses Hawaiian / Sanskrit / East-Asian
  characters whose continuation bytes routinely land in 0x80–0xBF).
  Adopted the coreutils-`ls` rule instead: reject only C0 + DEL.
  Residual risk: 8-bit C1-mode terminals (rare today; UTF-8 mode is
  the modern default) can still be reached via 0x9B / 0x9D aliases —
  accepted for v0.8.0.
- **Relative idat_total cap** (`1.5 × inflated_size`). Initial
  audit recommendation; failed in practice because zlib/DEFLATE
  header overhead is constant (~10–20 bytes), so for tiny inflated
  payloads (e.g. 14 bytes for a 2×2 RGB PNG) the legitimate
  idat:inflated ratio exceeds 1.5. Switched to absolute cap at
  KII_MAX_RAW_BYTES; same defense, no edge-case failure.
- **Sixel / Kitty graphics protocol emit (tier-3)**. Out of scope
  at v1.0 per CLAUDE.md color-tier discipline. Adopting these would
  move kii into the same opcode family as CVE-2017-14146 /
  CVE-2026-41253 attack classes; needs its own threat-model section
  when scoped.

## References

- [`../audit/2026-05-22-audit.md`](../audit/2026-05-22-audit.md) — full M7 audit (140 CVE/issue corpus + 10 kii-specific findings)
- [`../../SECURITY.md`](../../SECURITY.md) — public-facing security policy
- [`../development/roadmap.md`](../development/roadmap.md) § M7 — acceptance criteria
- [W3C PNG spec, 2nd ed (Nov 2003)](https://www.w3.org/TR/PNG/) — § 5.6 chunk ordering, § 11.2.2 table 11.1
- RFC 1951 (DEFLATE), RFC 1950 (zlib), RFC 2083 (PNG-in-zlib constraints)
