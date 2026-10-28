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

- **Eliminated CVE classes** *(as scoped at v0.8.0 — see the amendment
  below)*: by rejecting Adam7 interlacing, sub-byte
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
  sanitizer**. Considered and rejected at v0.8.0 — **this rejection was
  itself wrong, and was reversed at v1.5.1; see the amendment below.**
  The v0.8.0 reasoning was that it would break UTF-8 paths
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
- [`../../CHANGELOG.md`](../../CHANGELOG.md) § [0.8.0] — the M7 acceptance criteria and what met them. (This cited `roadmap.md` § M7; that section was deleted when the roadmap became forward-facing only at v1.5.1 — shipped milestones live in the CHANGELOG.)
- [W3C PNG spec, 2nd ed (Nov 2003)](https://www.w3.org/TR/PNG/) — § 5.6 chunk ordering, § 11.2.2 table 11.1
- RFC 1951 (DEFLATE), RFC 1950 (zlib), RFC 2083 (PNG-in-zlib constraints)

---

## Amendment — v1.5.1 (P-1 sweep)

This ADR remains **Accepted**; its threat model and its C1–C4 commitments still
stand. Two statements above have been overtaken by later releases and are
amended here rather than edited in place, because the reasoning they record is
part of the decision history.

**1. The "eliminated CVE classes" list no longer describes the decoder.** It was
written at v0.8.0, when kii carried its own PNG decoder that genuinely refused
Adam7 and sub-byte depths. The v1.2.0 re-fold ([ADR 0006](0006-adopt-chitra-decoder.md))
replaced that decoder with `chitra`, and v1.2.2 re-pinned to a chitra that
**decodes both** — `tests/decode.tcyr` asserts `PNG_OK` for exactly those inputs.
Ancillary chunks and APNG are still not decoded. The elimination-by-refusal
argument therefore applies to a narrower set than it claims, and the guards it
credited now live in chitra rather than in kii. What did not change is the
posture: unsupported means *refused with a distinct error*, never guessed at.

**2. The C1 rejection was reversed — the alternative was rejected for a reason
that turned out to be false.** v0.8.0 declined to reject `0x80–0x9F` on the
grounds that it "would break UTF-8 paths". That is true only of a **flat byte-range
test**, which is what was imagined. It is not true of a UTF-8-structure-aware
predicate: a bare `0x80` has no lead byte, so it is not valid UTF-8 at all and no
legitimate filename produces one. The v1.5.1 sweep found the consequence — a
filename built from 8-bit C1 introducers delivered a complete
`OSC 0;PWNED ST` to stderr **byte-for-byte**, through the very sanitizer this ADR
commits to (finding A-4). `kii_path_has_control_bytes` now walks UTF-8 structure
and rejects raw C1, the `C2 80`–`C2 9F` UTF-8 spelling, and malformed UTF-8,
while passing every real multi-byte sequence. The Hawaiian / Sanskrit /
East-Asian paths this alternative was rejected to protect are covered by test.

See [`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md) § A-4.

## Amendment — v1.6.0 (the sanitizer moves to darshana)

The C1 commitment is unchanged; its **implementation** moved. `kii_path_has_control_bytes`
is now a thin wrapper over darshana's `tty_has_ctl` (darshana 1.3.0) in `TTY_SANITIZE_UTF8`
mode with `TTY_KEEP_TAB | TTY_KEEP_LF` — the reject-only twin of `tty_sanitize_buf`, which
darshana shaped on kii's own predicate (darshana ADR 0004). Every class the v1.5.1 walk
refused is still refused.

The swap tightens the rule by one class, deliberately: darshana validates **strict RFC 3629**,
so overlong 3- and 4-byte forms (`E0 80`–`9F …`, `F0 80`–`8F …`), UTF-16 surrogates
(`ED A0`–`BF …`) and code points past U+10FFFF (`F4 90`–`BF …`) are suppressed too. kii's
walk had accepted them because it checked only that continuation bytes were `0x80`–`0xBF`.
That was a residual gap in this ADR's commitment, not a nicety: `E0 82 9B` is an overlong
spelling of U+009B (CSI), and a terminal whose UTF-8 decoder accepts overlong forms turns it
back into the C1 control the amendment above exists to stop. No legitimate filename is
affected, since none of the four forms is valid UTF-8.

The change is pinned two ways: `tests/cli.tcyr` asserts both sides of every forbidden range,
and a 1,000,000-iteration differential surface in `tests/kii.fcyr` checks that the new verdict
equals the v1.5.2 walk's on every input except exactly those carrying one of the four forms.
Owning the rule in darshana also means the next consumer that echoes untrusted text to a
terminal inherits it rather than writing its own.

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**. The v1.6.4 sweep
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)) checked each claim above
against the tree. The corrections:

**1. The C1–C4 table's code anchors predate the v1.2.0 re-fold.** Every C2–C4 guard now
lives in `chitra` and reaches kii through `_kii_map_chitra_err` (`src/png.cyr`). Current
anchors, cited by function and constant name rather than by `lib/chitra.cyr` line:

| # | Defense | Code today |
|---|---|---|
| C1 | Stderr path-echo sanitization | `kii_path_has_control_bytes` (`src/cli.cyr`, wraps darshana's `tty_has_ctl`) + `_eprint_path_safe` (`src/main.cyr`) — unchanged |
| C2 | Dimension caps (4096² pixels, 65535 per side, 256 MB) | chitra's `_chitra_parse_ihdr` with `CHITRA_MAX_DIM` (65535) and `CHITRA_MAX_PIXELS` (4096²), plus the `CHITRA_MAX_RAW_BYTES` (256 MB) inflated- and pixel-size caps in `_chitra_png_parse_raw` → `CHITRA_ERR_DIMENSIONS` → `PNG_ERR_DIMENSIONS` |
| C2 | PNG § 11.2.2 cross-product | the depth table in `_chitra_parse_ihdr` → `CHITRA_ERR_BIT_DEPTH` → `PNG_ERR_BITDEPTH` |
| C3 | IDAT-accumulator cap (256 MB) | `_chitra_png_parse_raw`, `idat_total > CHITRA_MAX_RAW_BYTES` → `CHITRA_ERR_OOM` → `PNG_ERR_IDAT_TOO_LARGE`. kii's own cap before decode is the read itself: `file_read_whole_max(path, KII_MAX_RAW_BYTES, …)` |
| C3 | Compression-ratio cap (1100:1) | `CHITRA_MAX_INFLATE_RATIO` in `_chitra_png_parse_raw` → `CHITRA_ERR_DIMENSIONS` → `PNG_ERR_DIMENSIONS`. `PNG_ERR_RATIO_TOO_HIGH` is reserved and never produced ([ADR 0006](0006-adopt-chitra-decoder.md)) |
| C4 | Duplicate PLTE, PLTE after IDAT | the `seen_plte` / `seen_idat` checks in `_chitra_png_parse_raw` → `CHITRA_ERR_BAD_CHUNK` → `PNG_ERR_HEADER` |

**2. `KII_MAX_PIXELS` and `KII_MAX_DIM` do not exist.** § Decision names them. The pixel
and per-side ceilings are chitra's `CHITRA_MAX_PIXELS` and `CHITRA_MAX_DIM`. kii defines
only `KII_MAX_RAW_BYTES`, which since v1.6.4 is `CHITRA_MAX_RAW_BYTES` (256 MB).

**3. Three commitments added since v1.0.**

- **The 16 MiB inflate ceiling** (v1.6.0). chitra refuses a PNG whose pixel data would
  inflate past sankoch's `DECOMPRESS_MAX_OUTPUT` before allocating anything
  (`CHITRA_ERR_INFLATE_LIMIT` → `PNG_ERR_INFLATE_LIMIT`, "image too large to decode").
- **The frame-size cap** (v1.6.4). `--width` is bounded by `KII_MAX_COLS` (100000, v1.5.1),
  but the row count follows the image's aspect, so a 392-byte 1×65535 GIF at `--width 80`
  asked for 2,621,400 rows, about 4.4 GB of ANSI. `kii_frame_cells_ok` (`src/cli.cyr`) now refuses any frame
  over `KII_MAX_CELLS` (1,048,576 character cells) before downscale: `frame too large (…)`,
  exit 1.
- **The single-open read** (v1.6.4). `kii_decode_png` reads the input with the stdlib's
  `file_read_whole_max`: one open, read to EOF, stop at `KII_MAX_RAW_BYTES`. It replaced an
  `lseek` size probe followed by a second open, which misreported pipes and directories and
  let the path change between the size check and the read. A pipe or `/dev/stdin` now takes
  the same path as a file.

**4. The three sankoch items were never filed, and they hold.** § Consequences (Neutral)
says the CVE-2004-0797 / 2005-1849 / 2005-2096 class transfers were "filed during the
audit" and gated v1.0. They were never filed. The v1.6.4 sweep verified all three against
the sankoch kii links (2.8.7), with ~474,000 crafted streams under poison redzones and no
crash, overrun or verdict disagreement. The covering checks: Kraft completeness and
over-subscription in `_huff_build`; the HLIT ≤ 286 and HDIST ≤ 30 bounds; and fixed
512-entry root tables with no variable sub-tables, so there is no oversized-table case to
reach. Nothing is left to file.

**5. The coverage figures are v0.8.0's.** "3M+ iterations across five surfaces" and "470
unit-test assertions" in § Decision were true at v0.8.0. At v1.6.4 they are 8,011,000
iterations across ten surfaces and 709 assertions.

**6. The restricted-emit list omits the ASCII lane.** Since v1.3.0, `--mode ascii` emits one
printable ASCII glyph per cell, drawn from a fixed 27-entry table (`0x20`–`0x7E`), each after
a foreground `38;5;N` only. The emit subset is therefore SGR `0` / `38;5;N` / `48;5;N`, `▀`,
those glyphs, and LF. kii emits `▀` only; `▄` is allowed by the list but unused.

**7. The palette alternative's citations are stale.** § Alternatives says
`downscale.cyr:73` and `quant.cyr:129` bounds-check palette indices and substitute black.
Since the v1.2.0 re-fold an out-of-range index never reaches kii: chitra rejects the file
(`CHITRA_ERR_BAD_CHUNK` → `malformed PNG (bad chunk, ordering, or palette)`), which is
stricter. `quant.cyr` has had no palette-lookup code since its image quantizer was deleted
at v1.2.0, and the `downscale.cyr` branch (`_extract_rgb`'s `color_type == 3` path) is
reached by no production input.

## Amendment — v1.7.0 (the format-neutral rename)

The names this ADR uses were renamed at v1.7.0 (the format-neutral rename, roadmap 1.7.0),
with every numeric code unchanged and behaviour byte-identical (the rename alone compiles to
the same binary):

| through v1.6.4 | since v1.7.0 |
|---|---|
| `src/png.cyr` | `src/image.cyr` |
| `kii_decode_png` | `kii_decode_image` |
| `png_color_type_name` | `kii_source_type_name` |
| `PNG_OK` / `PNG_ERR_*` | `IMG_OK` / `IMG_ERR_*` |
| `PNG_ERR_HEADER` (4) | `IMG_ERR_MALFORMED` |
| `PNG_ERR_CHUNK` (6) | `IMG_ERR_TRUNCATED` |
| `PNG_ERR_TRUNCATED` (2, reserved) | `IMG_ERR_SHORT_FILE` (reserved) |
| `PNG_ERR_NOT_PNG` (3) | `IMG_ERR_UNRECOGNIZED` |
| `PNG_ERR_NO_IDAT` (9) | `IMG_ERR_NO_IMAGE_DATA` |
| `PNG_ERR_INFLATE` (10) | `IMG_ERR_DECOMPRESS` |
| `PNG_ERR_IDAT_TOO_LARGE` (13) | `IMG_ERR_MEMORY` |

Every other `PNG_ERR_X` is now `IMG_ERR_X`. The text above keeps the names it was written with.

## Amendment — v1.8.0 (the emit surface widens, still SGR only)

[ADR 0010](0010-tier-2-colour-and-emit-encoding.md) adds tier-2 colour and re-encodes
tier 1. The restricted-emit posture holds: every byte kii writes to stdout is still a
printable glyph (`▀`, `▄`, a space, or the ASCII lane's 27-glyph table), a newline, or an
SGR escape (`ESC [ … m`). There is no OSC, DCS, APC or PM. The SGR set grows to:

- 0 (the row-end reset);
- 30–37, 40–47, 90–97 and 100–107 (tiers 8 and 16);
- 39 / 49 (a transparent half: the terminal's default colour);
- `38;5;N` / `48;5;N` with N in 16–255 (tier 256);
- `38;2;R;G;B` / `48;2;R;G;B` with each channel in 0–255 (truecolour).

Every value comes from darshana's composers, which reject anything outside its range and
write nothing when they do. The emit layer also refuses a code that is not a colour of the
active tier (`_kii_sgr_fg` / `_kii_sgr_bg`), so no tier can send another tier's escapes.
A cell's worst case grows from 25 to 41 bytes, and the frame cap (`KII_MAX_CELLS`) still
bounds a frame, at ~43 MB of truecolour output.


## Amendment — v1.9.0 (dithering adds no emit surface)

[ADR 0011](0011-dithering.md) adds `--dither none|ordered|fs`. It changes which colour code a
pixel gets, never which escapes exist. Every code still comes from the active tier's
quantizer, and the emit layer still refuses a code outside that tier, so the SGR set from
the v1.8.0 amendment is unchanged.

The new allocations are bounded by limits already in force:

- **Floyd-Steinberg** keeps two error rows of `(w + 2) × 3` i64, so 48 · (w + 2) bytes. `w`
  is the frame's width in pixels (half-block) or cells (ASCII), at most `KII_MAX_COLS`
  (100,000).
- **The ASCII lane's cell field** (under `fs` only) takes 8 bytes a cell. That is at most
  8 MB under `KII_MAX_CELLS`.

Every allocation is checked, and a failure is reported as an error (exit 1). The arithmetic
is exact integers: the carried error stays within ±16·255 per channel, far inside an i64.
The fuzz harness's emit surface now rotates through every tier × dither pair.


## Amendment — v1.9.1 (a valid PNG can cost more, by chitra's design)

chitra 1.3.0 drops the 16 MiB inflate ceiling recorded in the v1.6.4 amendment (item 3). A
PNG past 16 MiB of scanlines is no longer refused from the header: chitra inflates through
`zlib_decompress_capped` with the exact size IHDR implies as the ceiling, so the file decodes.
`IMG_ERR_INFLATE_LIMIT` is unreachable from v1.9.1, as chitra's code 35 behind it is.

The caps that bound an input are unchanged: kii's 256 MB read (`KII_MAX_RAW_BYTES`), chitra's
4096² pixel cap, its 256 MB raw-byte cap and its 1100:1 compression-ratio cap. What changes
is the cost inside them. § Consequences bounded a PNG at ~256 MB and ~5–6 s. Measured on the
x86_64 dev host at v1.9.1 (peak RSS, wall clock, `--width 80`):

| Input | File | v1.9.0 | v1.9.1 |
|---|---:|---|---|
| 4096² black RGB8 | 49 KB | refused, 13 MB | 117 MB, 0.45 s |
| 4096² flat RGBA16, Adam7 | 147 KB | refused, 13 MB | 327 MB, 1.7 s |
| 4096² plasma RGBA16 | 97 MB | refused, 227 MB | 513 MB, 9.7 s |
| 4096² plasma RGBA16, Adam7 | 99 MB | refused, 227 MB | 643 MB, 10.5 s |
| 4096² noise RGBA16, Adam7, padded to 255 MB | 255 MB | refused, 517 MB | 913 MB, 7.2 s |

- **The worst case is ~0.9 GB and ~10 s.** The largest figure is a file at the read cap that is
  also at the pixel cap, interlaced and 16-bit. About 517 MB of it is the read, which v1.9.0
  paid too: the stdlib's `file_read_whole_max` grows its buffer, and the bump allocator keeps
  each one it outgrows. The rest is chitra's working set, which its 1.3.1 notes put at ~3× the
  RGBA8 output for a non-interlaced PNG and ~5× for Adam7, plus the compressed size when the
  IDAT is split.
- **A small file buys up to ~327 MB and ~1.7 s.** That is the amplification the ratio cap
  allows at the pixel cap: 147 KB of valid, highly compressible Adam7 RGBA16.
- **The decision.** kii takes chitra's posture rather than keeping a ceiling of its own.
  Refusing ordinary photos (anything above ~5.6 MP of RGB) was the larger cost, and the
  roadmap had pinned this re-pin as the fix since v1.6.3. A caller that must hold kii to a
  smaller footprint can run it under `ulimit -v`. A failed allocation is reported as
  `out of memory or image too large`, exit 1.


## Amendment — v1.10.0 (the ASCII lane reads around each cell)

[ADR 0007](0007-rendering-mode-taxonomy.md) § v1.10.0 amendment adds contrast enhancement to
the ASCII lane. It changes which glyph a cell gets, never which bytes exist: every glyph is
still one of the 27 in the table, and every colour still comes from the active tier, so the
emit surface of the v1.8.0 amendment is unchanged.

- **One new allocation.** `_ascii_lum_plane` takes one byte per downscaled sample, `cols · 2 ×
  rows · 3`. Under `KII_MAX_CELLS` that is at most 6 MiB (6,291,456 bytes). It is checked, and a
  failure is an error (exit 1).
- **The new reads stay inside the plane.** The contrast pass reads the ten samples around each
  cell, and four guards keep them in bounds: none above row 0, below the last row, left of
  column 0 or right of the last column. A sample past an edge counts as 0. A new fuzz surface
  renders every frame twice, with the plane between pads of 0 and then of 255, and requires the
  same bytes (40,000 random frames a run). Dropping the top or the bottom guard makes 2,851 and
  2,837 of 3,000 frames differ.
- **The arithmetic is exact integers** (a 256-entry power table, an exact reciprocal for one
  division and an exact shift for the other, each checked over its whole domain in
  `tests/ascii.tcyr`), so every target computes the same glyphs.
