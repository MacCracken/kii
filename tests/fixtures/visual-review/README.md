# Visual-review fixtures

Curated PNG set for the M8(b3) `kii` vs `chafa --colors 16` visual
comparison. See [`docs/audit/chafa-comparison.md`](../../../docs/audit/chafa-comparison.md)
for the rendered comparison and findings.

## Contents

| File | Source | Color type | Dims | Why this fixture |
|---|---|---|---|---|
| `basn2c08.png` | [W3C PngSuite](http://www.schaik.com/pngsuite/) | RGB (color_type=2) | 32×32 | Basic-set RGB; standardized test pattern |
| `basn3p08.png` | W3C PngSuite | Palette (color_type=3) | 32×32 | Basic-set palette; tests PLTE lookup |
| `basn6a08.png` | W3C PngSuite | RGBA (color_type=6) | 32×32 | Basic-set RGBA; tests alpha handling |

## Comparison runs also reference (not bundled — system paths)

- `/usr/share/pixmaps/archlinux-logo.png` — 256×256 palette logo (Arch trademark; not bundled)
- `/usr/share/grub/themes/starfield/starfield.png` — 1597×1198 RGBA large source
- `../RAMGON.png` (one level up) — 1152×925 RGBA real-world photo-class

## Licensing

The PngSuite fixtures are public-domain test data per Willem van Schaik's
PngSuite license: "Permission to use, copy, modify and distribute these
images for any purpose and without fee is hereby granted." Bundled
unmodified.
