# 0008 — JPEG via chitra: format dispatch + validation posture

**Status**: Accepted
**Date**: 2026-06-27
**Relates to**: [0006](0006-adopt-chitra-decoder.md) (realizes its "JPEG arrives on a re-pin" line)

## Context

[ADR 0006](0006-adopt-chitra-decoder.md) settled the *direction*: kii does not
carry in-repo format decoders; it consumes them from the `chitra` substrate on a
`[deps.chitra]` re-pin, and "chitra 0.3+ (JPEG) flow[s] to kii for free on a
re-pin." chitra **0.3.0** shipped baseline (SOF0) JPEG — grayscale + YCbCr, 4:4:4
/ 4:2:2 / 4:2:0 chroma subsampling, DRI/RST restart markers — normalizing to the
**same canonical RGBA8** `ChitraImage` it already produces for PNG, plus a
format-sniffing `chitra_image_decode` entry point.

The PNG matrix re-pin (chitra 0.2.0 → 0.2.1 at v1.2.2) needed **no** ADR — it was
pure execution of 0006: same `chitra_png_decode` call, wider input acceptance, zero
new decision. JPEG is different on two axes 0006/PNG never faced, which is why this
warrants its own ADR rather than a silent re-pin:

1. **Format dispatch** — a PNG-only kii never chose *how* to decide which decoder
   runs. With two formats, that is a real decision.
2. **Validation posture** — CLAUDE.md's hard rule is "CRC / signature validation on
   every image input." JPEG has **no** CRC and is a **lossy** codec; the rule was
   written for PNG and needs a JPEG-aware restatement.

## Decision

**kii decodes baseline JPEG by re-pinning `[deps.chitra]` to `0.3.0` and routing all
input through `chitra_image_decode`** (the signature sniffer), replacing the
`chitra_png_decode` call in the `src/png.cyr` adapter. A JPEG produces the same
depth-8 `color_type=6` RGBA8 image a PNG does, so `downscale` / `quant` / `emit` —
and every PNG output frame — are **byte-for-byte unchanged**.

### Format dispatch — sniff, never extension

Dispatch is by **content signature**, never by file extension. `chitra_image_decode`
checks the 8-byte PNG magic, then the JPEG SOI (`0xFFD8`), and routes accordingly; an
unrecognized signature is `CHITRA_ERR_SIGNATURE`. kii's adapter mirrors the same sniff
(`chitra_png_check_signature` / `chitra_jpeg_check_signature`) **before** the decode
call to record a `KII_FMT_*` tag in the pstruct, so a *failed* decode (which returns no
image) can still be diagnosed per format. Rationale: a renamed `.png` that is really a
JPEG (or vice versa) renders correctly rather than misleading the user; extension is
advisory metadata, signature is truth. This matches `chafa` / `file(1)` behavior.

### Validation posture for JPEG (extends 0002 / the CLAUDE.md rule)

The "CRC on every input" rule is **PNG-specific and stays so** — it is the right bar
for PNG and chitra still enforces it on the PNG path. JPEG has no chunk CRC, so the
JPEG bar is **structural validation at the spec layer**: chitra validates the SOI,
every marker and 16-bit segment length, SOF0 dimensions/precision/component/sampling
fields (incl. the CVE-2018-11212 zero-sampling-factor divide-by-zero guard), DQT/DHT
table bounds and Huffman-code subscription, SOS selectors, and the entropy stream
(undecodable code / coefficient overrun / missing restart marker) — rejecting
malformed input rather than guessing. The same DoS caps that bound PNG apply to JPEG:
the 256 MB pre-read file cap, `CHITRA_MAX_DIM` / `CHITRA_MAX_PIXELS`, and the
`w*h*4 ≤ CHITRA_MAX_RAW_BYTES` output cap (which also bounds the chroma-subsampling
upsample-bomb). **Baseline only**: progressive, arithmetic-coded, 12-bit, hierarchical
/ lossless / differential SOF modes, and CMYK/YCCK 4-component JPEG are *valid but
unsupported* and rejected cleanly (chitra 0.3.0 is baseline-only) — kii surfaces these
as a distinct `PNG_ERR_UNSUPPORTED` ("unsupported JPEG feature …"), kept separate from
the PNG `BITDEPTH` path so the diagnostic never cites the PNG §11.2.2 table for a JPEG.

### Error-space + naming

The 11 JPEG `ChitraErr` codes map onto kii's existing `PNG_ERR_*` space: malformed
structure → `PNG_ERR_HEADER` (phrased "malformed JPEG …" via the format tag), the five
deferred modes → the new `PNG_ERR_UNSUPPORTED`. The historical `png_` / `PNG_ERR_*`
symbol names and the `src/png.cyr` filename are **retained** — renaming the public
contract (`kii_decode_png` → `kii_decode_image`), the file, and the code space to
format-neutral names is a deliberate **deferred follow-up** (tracked in
`docs/development/roadmap.md`), kept out of this cut so the functional wiring stays a
tight, byte-identical-verifiable change.

## Consequences

- **Positive** — kii gains a second major input format with zero in-repo decoder code
  and zero pipeline change; one substrate decoder serves every consumer. PNG output is
  provably unchanged (golden frames byte-identical at every width + `--verbose`). The
  format sniff means correct rendering regardless of file extension. Diagnostics are
  per-format, so a corrupt or unsupported JPEG gets an accurate message instead of PNG
  jargon.
- **Negative** — kii now also tracks chitra's JPEG release line (a JPEG decode fix or a
  progressive-mode addition needs a chitra release + re-pin, not an in-repo edit) — the
  same coupling already accepted for PNG, `cmdit`, `darshana`. The `png_`/`PNG_ERR_*`
  names are now historical-not-literal until the deferred rename lands.
- **Neutral** — JPEG decoder-internal coverage (Huffman, IDCT, chroma upsample, the
  malformed-marker corpus) lives in chitra's own suite, the decoder's owner. kii's tests
  pin only the *adapter* surface: the 11 error mappings, the sentinel names, the format
  tag, and e2e decode of a grayscale + YCbCr baseline JPEG.

## Alternatives considered

- **Dispatch by file extension.** Rejected: a mislabeled file would render wrong or
  error spuriously; extension is advisory, not authoritative. Signature sniff is the
  same posture `file(1)` / `chafa` take and is what chitra already does.
- **Write an in-repo JFIF decoder.** Rejected outright by ADR 0006 — kii does not carry
  format decoders. The substrate (chitra) owns decode; kii owns the terminal-emit lane.
- **Generalize the error space to `IMG_ERR_*` and rename `png.cyr` now.** Rejected *for
  this cut* (not forever): bundling a ~50-reference mechanical rename + a large doc/audit
  citation sweep into the functional JPEG wiring inflates the review surface and risks a
  typo against the byte-identical-PNG bar. Tracked as a follow-up; the entry-point rename
  is the natural trigger now realized, the codespace/file rename deferred.
- **Map unsupported JPEG modes onto the existing `PNG_ERR_BITDEPTH`.** Rejected: that
  path's message cites "PNG §11.2.2," which is wrong for a progressive/arithmetic/12-bit
  JPEG. A distinct `PNG_ERR_UNSUPPORTED` keeps the diagnostic honest.

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**. One correction from the v1.6.4 sweep
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)): § Validation posture lists
"the 256 MB pre-read file cap". Since v1.6.4 there is no size check ahead of the read. kii
reads the file once with the stdlib's `file_read_whole_max`, which stops at
`KII_MAX_RAW_BYTES` (256 MB, defined as chitra's `CHITRA_MAX_RAW_BYTES`) and reports
`file exceeds size ceiling (max 256 MB)`. The cap still applies to every format before any
decode starts.

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

This closes the deferral in § Error-space + naming: the rename it postponed is done, as
its own release, so the JPEG wiring stayed the tight change this ADR wanted.
