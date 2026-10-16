# 0006 — Adopt the chitra distlib; delete the in-repo PNG decoder

**Status**: Accepted
**Date**: 2026-06-26

## Context

[ADR 0001](0001-png-decoder-in-repo.md) kept the PNG decoder in-repo
(`src/png.cyr`) "until a second first-party consumer surfaces," at which
point it would extract to a Sanskrit-named substrate lib (working name
`chitra`). That second consumer arrived: **mabda** needed
`gpu_texture_load_png`, so the mabda agent forked kii's decoder into the
**`chitra`** package (0.1.0, 2026-06-19). That left the AGNOS ecosystem
with two diverging copies of the same fuzz-hardened decoder and a manual
backport burden — exactly what the extract-on-2nd-consumer pattern exists
to avoid.

chitra 0.1.0 was PNG depth-8 / non-interlaced only, so it was not yet a
safe drop-in: kii's decoder already handled **16-bit** depth (high-byte
truncation), and kii carried M7(c)/M8 security guards the fork hadn't all
inherited. Adopting a decoder weaker than the one it replaces would be a
regression. So before kii could flip, chitra had to reach parity.

**chitra 0.2.0** (2026-06-26) closed that gap: 16-bit decode for color
types 0/2/4/6 (the same high-byte reduction kii used) plus a guard-parity
backport (IEND-length check, distinct `CHITRA_ERR_NO_IDAT`,
`chitra_image_seen_iend` / `chitra_image_source_color_type` accessors). A
4-lens adversarial review confirmed chitra 0.2.0 is a strict **superset**
of kii's decoder. This is the same move kii made for CLI parsing when it
adopted the `cmdit` distlib at v1.1.0 — kii seeds an extraction, then
consumes it back.

## Decision

**kii deletes its in-repo PNG decoder and consumes `chitra` via
`[deps.chitra]` (pinned `0.2.0`), completing ADR 0001's extract-on-2nd-
consumer plan.** `src/png.cyr` is trimmed from 813 lines to a thin
adapter that keeps the kii-side contract:

- the `PNG_ERR_*` code space + `STRUCT_*_OFFSET` pstruct layout + the
  `_png_color_channels` / `png_color_type_name` helpers downstream
  modules consume;
- a `kii_decode_png(path, &pstruct)` front-end that owns the file I/O
  boundary chitra deliberately doesn't (chitra takes in-memory bytes):
  it slurps the file with an exact-`fstat`-sized alloc, rejects inputs
  over 256 MB (`PNG_ERR_FILE_TOO_LARGE`) before reading, calls
  `chitra_png_decode`, and writes the canonical RGBA8 result into the
  pstruct **as a depth-8 `color_type=6` image** so `downscale` /
  `quant` / `emit` are byte-for-byte unchanged (downscale's RGBA
  drop-alpha branch absorbs it);
- a `ChitraErr` → `PNG_ERR_*` mapping that preserves kii's per-error
  stderr diagnostics and the missing-IEND exit-0 warning.

**In scope**: PNG. **Out of scope / future**: chitra 0.2.1 (sub-byte
depths 1/2/4 + Adam7) and chitra 0.3+ (JPEG) flow to kii for free on a
re-pin — kii will prefer consuming chitra's JPEG over an in-repo JFIF
decoder (this retires the in-repo JPEG/GIF/BMP line from the roadmap's
out-of-scope list in favor of the substrate).

stdlib `sankoch` + `thread` stay in kii's `[deps].stdlib`: chitra's
strip-include dist resolves `zlib_decompress` / `crc32` / `mutex` from
the consumer, and kii's own tests call `zlib_decompress` directly.

## Consequences

- **Positive** — one decoder for the ecosystem, not two; a kii bug-fix or
  a new format lands once, in chitra, for every consumer. ~700 lines of
  the hardest-to-audit untrusted-parser surface leave kii. The downstream
  pipeline (the riskiest rendering code) is provably unchanged: RAMGON.png
  golden frames are byte-identical at 40/80/120/200/default widths and on
  the `--verbose` stderr line. 16-bit support is preserved; kii gains
  chitra's tRNS handling (invisible today — alpha is dropped — but ready
  for any future alpha-compositing tier).
- **Negative** — kii now tracks chitra releases (a decode fix or new
  format needs a chitra release + re-pin, not an in-repo edit), the same
  coupling kii accepted for `cmdit` / `darshana`. The whole file is read
  into memory before decode (bounded by the new 256 MB pre-read cap)
  where the old reader streamed IDAT through a 4 KB scratch. A handful of
  diagnostic labels coalesce (see below).
- **Neutral** — the decoder-internal test surface (CRC vectors, Paeth /
  unfilter, malformed-PNG rejection, the IHDR caps) moves to chitra's
  suite (322 assertions); kii's tests split into focused files
  (`tests/{cli,quant,render,decode}.tcyr`) covering only kii's surface
  plus the new adapter / error-mapping / e2e coverage.

### Accepted diagnostic deltas (every security guard remains intact)

- A `<8`-byte file reports `not a PNG` (chitra's signature check), so the
  dedicated "shorter than 8 bytes" message is unreachable —
  `PNG_ERR_TRUNCATED` is reserved.
- The decompression-ratio bomb cap reports `dimensions exceed ceiling`
  (`CHITRA_ERR_DIMENSIONS`) rather than a distinct ratio code —
  `PNG_ERR_RATIO_TOO_HIGH` is reserved; the guard fires identically.
- The IDAT-accumulator cap arrives via `CHITRA_ERR_OOM` and is reported
  with neutral "out of memory or IDAT too large" wording.
- A corrupt (out-of-range) palette index is a hard reject (chitra
  `BAD_CHUNK` → `malformed PNG`) rather than the old graceful map-to-black
  — stricter, and only affects corrupt input.

## Alternatives considered

- **Keep the in-repo decoder.** Rejected: it perpetuates two diverging
  copies + a manual backport burden, the exact cost ADR 0001 deferred
  rather than endorsed. The second consumer has surfaced.
- **Flip onto chitra 0.1.0 now, accept the 16-bit regression.** Rejected:
  16-bit PNGs go from rendered to rejected — a real capability loss
  against kii's byte-identical/no-loss bar (the cmdit precedent). Gating
  the flip on chitra 0.2.0 made shipping the regression structurally
  impossible.
- **Keep kii's native depth-16 path as a fallback alongside chitra.**
  Rejected: it retains the entire inflate + unfilter + IHDR core — the
  hardest-to-audit surface the re-fold exists to remove — and leaves two
  decoders to maintain. Adding depth-16 to chitra achieves no-regression
  with one decoder.
- **Drop stdlib `sankoch` + `thread` after the flip.** Rejected: verified
  the chitra dist resolves them from the consumer's stdlib list and kii's
  tests call `zlib_decompress` directly. Both stay.

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**; kii still carries no decoder. The v1.6.4 sweep
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)) corrects four statements
and supersedes one decision.

**1. The file read was never `fstat`-sized, and is now a single capped read.** § Decision
says the adapter "slurps the file with an exact-`fstat`-sized alloc" and rejects inputs over
256 MB before reading. At v1.2.0 it sized the file with `lseek(SEEK_END)` and then opened it a
second time to read it. That misreported pipes and `/dev/stdin` ("cannot open file") and
an ext4 directory ("file exceeds size ceiling"), and let the path change between the two opens.
Since v1.6.4 it calls the stdlib's `file_read_whole_max(path, KII_MAX_RAW_BYTES, &n)`: one
open, read to EOF, stop with `-EFBIG` past 256 MB. A directory now reports `is a directory,
not an image file` (`PNG_ERR_IS_DIR`, 18). (The decode call itself became
`chitra_image_decode` at v1.4.0; see [ADR 0008](0008-jpeg-via-chitra.md).)

**2. The quoted diagnostics have changed wording.** In § Accepted diagnostic deltas:

- `not a PNG` now reads `unrecognized image format (expected PNG, JPEG, BMP, or GIF)`.
- `dimensions exceed ceiling` now reads `image dimensions are zero or past the policy
  ceiling (max 16.7M px / 65535 per side / 256 MB)`; chitra raises the same code for a zero
  width or height.
- `out of memory or IDAT too large` now reads `out of memory or image too large (possible
  decompression bomb)`.

The mappings themselves are unchanged. Every line's text is now in
`kii_decode_error_text` (`src/png.cyr`), pinned by `tests/decode.tcyr`.

**3. "Alpha is dropped" is superseded.** § Decision and § Consequences describe
downscale's RGBA branch as dropping alpha, and call chitra's tRNS handling "invisible
today". That held through v1.6.3, and it meant a transparent pixel rendered whatever RGB it
stored: a GIF's transparent palette entry drew its colour, and a PNG storing
`rgba(255,255,255,0)` drew white. Since v1.6.4 `downscale_to_rgb` composites each channel
over black (`_over_black`, `(c·a + 127) / 255`, `src/downscale.cyr`). Alpha 255 returns the
channel unchanged, so every opaque image is byte-identical; a fully transparent pixel
renders black. Real transparency, drawing those cells in the terminal's default
background, is roadmap work pinned to 1.8.0.

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

The adapter also shed what only the native decoder needed (R-2 of the v1.6.4 sweep):
`_png_color_channels` and downscale's per-colour-type `_extract_rgb` are removed, and the
pstruct's `IDAT_*`, `PLTE_*` and `INTERLACE` slots are retired (their offsets left unused,
so every live slot keeps its offset). The adapter's "depth-8 colour type 6" is now the one
pixel format downscale accepts.
