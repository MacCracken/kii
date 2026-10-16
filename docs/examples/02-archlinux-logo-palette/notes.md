# 02 — Palette PNG (color_type=3)

Demonstrates kii decoding a PNG with `color_type=3` (palette /
indexed-color) — different from example 01's `color_type=6` (RGBA).
Palette PNGs carry one-byte pixel indices into a PLTE chunk. **Since the
v1.2.0 re-fold that lookup happens inside `chitra`**, which resolves PLTE
during decode and hands kii canonical RGBA8; `downscale.cyr`'s
`_extract_rgb` retains its `color_type == 3` branch for the pstruct
contract, but no production input reaches it any more. (Corrected at the
v1.5.1 P-1 sweep — this note described the pre-re-fold path.)

**Why this example**: covers the second-most-common PNG color type
(after RGB/RGBA). PLTE handling is one of the historically high-CVE
surfaces (libpng CVE-2013-6954, CVE-2025-64505, etc. — see
[`docs/audit/2026-05-22-audit.md`](../../audit/2026-05-22-audit.md) §
3.1). An out-of-range palette index never reaches kii: chitra rejects
the file during decode (`BAD_CHUNK`), and kii reports
`malformed PNG (bad chunk, ordering, or palette)`, exit 1. (Corrected
at v1.6.4: this cited a bounds check at `downscale.cyr:73` that
substituted black on an out-of-range index. That branch is in
`_extract_rgb`'s `color_type == 3` path, which no production input
reaches.)

**Transparency**: this logo carries a `tRNS` chunk, so chitra gives some
pixels alpha below 255. Since v1.6.4 kii composites alpha over black,
so a transparent pixel renders black rather than the colour its palette
entry stores, and a partly transparent one is darkened toward black. That changed 72 of this frame's 3,200 cells against
v1.6.3; earlier releases dropped alpha.

**Cross-check** — verify color_type detected as 3:

```sh
./build/kii --verbose --width 80 /usr/share/pixmaps/archlinux-logo.png > /dev/null
# stderr: ...: 256x256 65536 pixels (palette) → 16-color
```

**Alternative fixtures**: any indexed-color PNG works. GIMP /
ImageMagick can convert: `convert input.png -type Palette
output.png` produces a `color_type=3` PNG.
