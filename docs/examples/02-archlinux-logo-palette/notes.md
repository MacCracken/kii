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
