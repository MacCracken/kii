# 02 — Palette PNG (color_type=3)

Demonstrates kii decoding a PNG with `color_type=3` (palette /
indexed-color) — different from example 01's `color_type=6` (RGBA).
Palette PNGs carry one-byte pixel indices into a PLTE chunk; kii's
`_extract_rgb` (in `src/downscale.cyr`) does the index → RGB lookup
during downscale.

**Why this example**: covers the second-most-common PNG color type
(after RGB/RGBA). PLTE handling is one of the historically high-CVE
surfaces (libpng CVE-2013-6954, CVE-2025-64505, etc. — see
[`docs/audit/2026-05-22-audit.md`](../../audit/2026-05-22-audit.md) §
3.1). kii's bounds-check at `downscale.cyr:73` (`po + 2 < plte_size`)
substitutes black on OOB indices rather than reading past the
palette buffer.

**Cross-check** — verify color_type detected as 3:

```sh
./build/kii --verbose --width 80 /usr/share/pixmaps/archlinux-logo.png > /dev/null
# stderr: ...: 256x256 65536 pixels (palette) → 16-color
```

**Alternative fixtures**: any indexed-color PNG works. GIMP /
ImageMagick can convert: `convert input.png -type Palette
output.png` produces a `color_type=3` PNG.
