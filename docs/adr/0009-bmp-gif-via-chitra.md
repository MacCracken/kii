# 0009 — BMP + GIF via chitra: the re-pin that needed no decode change

**Status**: Accepted
**Date**: 2026-08-24
**Supersedes**: nothing. **Realizes**: [0006](0006-adopt-chitra-decoder.md) · **Extends**: [0008](0008-jpeg-via-chitra.md)

## Context

[ADR 0006](0006-adopt-chitra-decoder.md) deleted kii's 813-line PNG decoder and made kii a
consumer of the `chitra` distlib. Its closing argument was that new formats would arrive on a
`[deps.chitra]` re-pin rather than as in-repo decoder work. [ADR 0008](0008-jpeg-via-chitra.md)
tested that once, for baseline JPEG, and it held — but only partly, because 0008 still had to
switch the adapter's entry point from `chitra_png_decode` to `chitra_image_decode` and add a
whole format-tag mechanism.

This cut is the first re-pin that tests the claim with **nothing left to switch**. chitra 1.0.0
carries BMP (chitra 0.4.0) and GIF first-frame (chitra 0.5.0) decode, and freezes its surface:
29 names, the `ChitraImage` / `ChitraErr` layouts, and the *numeric* `ChitraErrCode` values
(chitra ADR 0010). All nine names kii calls sit inside that frozen block.

## Decision

**Take the formats, and pay only for the diagnostics.**

### The decode path does not change

`kii_decode_png` already called the format-sniffing `chitra_image_decode` unconditionally. A
`.bmp` or `.gif` therefore decoded to canonical RGBA8 and rendered *the moment the pin moved* —
verified before any source edit was made. The adapter writes RGBA8 into the pstruct as a depth-8
`color_type=6` image, `downscale.cyr`'s ct6 branch consumes it verbatim, and the resampler /
quantizer / emit layer never learn a fourth format exists.

This is the payoff 0006 promised, arriving in full: **three consecutive formats gained without
writing a decoder** (PNG re-fold v1.2.0 → JPEG v1.4.0 → BMP + GIF v1.5.0).

### The diagnostics do change, and that is the whole cut

Silent capability is not the same as *correct* capability. Because both formats started working
without kii noticing, four sites became wrong at runtime rather than merely stale:

1. `png_color_type_name` printed `(?)` for every BMP and GIF source under `--verbose`.
2. `_kii_map_chitra_err` had no arm for `ChitraErr` 24–34, so all eleven new codes fell through
   to the generic malformed fallback.
3. `KII_FMT_*` had no BMP or GIF member, so a corrupt `.bmp` reported
   `malformed PNG (bad chunk, ordering, or palette)` — a message that is not merely unhelpful but
   *false*, naming a format the file is not.
4. The unrecognized-format message still read "expected PNG or JPEG" while `kii art.gif` worked.

The rule this ADR sets: **a format kii renders is a format kii must be able to talk about.** A
re-pin that adds a decoder is not finished when the pixels appear; it is finished when a *failing*
file in that format produces a message naming that format.

### Error-code mapping stays inside the existing `PNG_ERR_*` space

The eleven new codes map onto codes kii already has rather than minting new ones. Structural
corruption (BMP header/palette/RLE, GIF header/palette) → `PNG_ERR_HEADER`, phrased per format by
`main.cyr`. "Valid file, chitra declines it" (BMP bpp outside `{1,4,8,16,24,32}`, `BI_JPEG`/`BI_PNG`,
bad `BI_BITFIELDS` mask) → `PNG_ERR_UNSUPPORTED`, which already carried exactly that meaning for
JPEG. GIF LZW → `PNG_ERR_INFLATE`, since it is a compression-stream failure. A structurally valid
GIF with no image descriptor → `PNG_ERR_NO_IDAT`, its exact PNG analogue.

**Why not new codes**: the `PNG_ERR_*` space is kii's stable stderr contract, and each new code is
a permanent name. The shared meanings are real, not forced — the same argument chitra made for
keeping `CHITRA_ERR_UNSUPPORTED` as one code before its own freeze.

### GIF is first-frame-only, and that is correct here

chitra ADR 0005 decodes frame 1 and stops. For a still-frame terminal renderer that is not a
limitation to work around — kii emits one frame of ANSI and exits, so there is no second frame to
put anywhere. Documented as behavior, not as a deferral.

### `seen_iend` stops being PNG-only

chitra 0.7.0 generalized the field from "was there an IEND chunk" to "did the stream end the way
its format says it should". GIF reports a real `frame_complete`, and a truncated LZW stream is
*tolerated* as a clean end with the tail zero-filled — so without a warning kii would render a
half-decoded frame silently. The gate now covers GIF with GIF-specific wording.

**Corrected at v1.5.1.** This paragraph originally continued "JPEG and BMP report
`1` unconditionally and never reach it." That is true for BMP and **false for
JPEG** — chitra sets the flag from a real `closed` decision made by the scan
driver, so a truncated or EOI-stripped JPEG decoded to a partial frame and kii
rendered it with no warning at all. The v1.5.1 P-1 sweep caught it as finding
A-2 (HIGH); the gate now carries a JPEG arm plus a defensive fallback. See
[`../audit/2026-08-25-audit.md`](../audit/2026-08-25-audit.md) § A-2. The name stays `seen_iend` because chitra kept it, and
chitra kept it because kii calls it (chitra ADR 0010 § 1).

## Consequences

**Good.** Four formats, one adapter, no decoder in kii. The security surface stays in chitra, which
fuzzes and audits it as its primary job; kii's own fuzz harness grew two signature-prefixed surfaces
(1M BMP + 1M GIF, total 6,011,000 iterations clean) that verify the *adapter* never crashes on
attacker-controlled bytes, which is kii's half of the contract.

**Cost.** kii's diagnostics now encode knowledge of chitra's sentinel encoding (`0x200 | bpp`,
`0x300 | min_code_size`) and its error-code numbering. Both are frozen by chitra ADR 0010, so this
is a dependency on a promise rather than on an implementation detail — but it is a real coupling,
and a fifth format will require the same diagnostics work again. That is the correct trade: the
alternative is rendering formats kii cannot name in an error message.

**Accepted staleness.** The historical `png_`/`PNG_ERR_*`/`png.cyr` names now cover four formats and
are actively misleading. The rename to `image.*`/`IMG_ERR_*` remains tracked
(`docs/development/roadmap.md`) and deferred, on the same smallest-first grounds as at v1.4.0 — but
the case for it is now materially stronger than it was with two formats.

## Amendment — v1.6.4 (P(-1) sweep)

This ADR remains **Accepted**. The v1.6.4 sweep
([`../audit/2026-10-15-audit.md`](../audit/2026-10-15-audit.md)) found that kii had not
fully met this ADR's own rule, *a format kii renders is a format kii must be able to talk
about*, and corrected three statements:

**1. kii calls 11 chitra functions, not nine.** § Context says "all nine names kii calls".
kii called eleven at v1.5.0 and still does: the four signature predicates
(`chitra_png_check_signature`, `chitra_jpeg_check_signature`, `chitra_bmp_check_signature`,
`chitra_gif_check_signature`), `chitra_image_decode`, `chitra_err_code`, and five
accessors (`chitra_image_width`, `_height`, `_pixels`, `_seen_iend`,
`_source_color_type`). All eleven are frozen names in chitra 1.2.0.

**2. Two GIF diagnostics named the wrong format.** § Error-code mapping maps GIF LZW to
`PNG_ERR_INFLATE` and an image-less GIF to `PNG_ERR_NO_IDAT`. `main.cyr` phrased
`HEADER`, `CHUNK` and `UNSUPPORTED` per format, but these two only for PNG, so through
v1.6.3 a corrupt GIF printed `DEFLATE decompression failed
(corrupt IDAT)` and an image-less one `no IDAT chunks (nothing to decode)`. Since v1.6.4
they print `corrupt GIF image data (bad LZW stream)` and `no image in GIF (no image
descriptor)`. The BMP line also changed, to `unsupported BMP feature (bit depth, compression
method, or channel mask)`, because chitra refuses OS/2 Huffman 1D and `BI_CMYK` as well as
`BI_JPEG` / `BI_PNG`. The text of every line moved from `main.cyr` to
`kii_decode_error_text` (`src/png.cyr`), and `tests/decode.tcyr` pins each one per format.

**3. A truncated GIF is not "zero-filled".** § `seen_iend` stops being PNG-only says the missing tail is
zero-filled. chitra fills it with palette entry 0 at full alpha, so it draws in whatever
colour that entry is. The warning, now `kii_incomplete_warning_text`, reads
`warning: incomplete GIF (image data ran out; the rest is drawn in palette colour 0)`.

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
