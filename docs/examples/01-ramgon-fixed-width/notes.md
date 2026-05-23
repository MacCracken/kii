# 01 — RAMGON.png → 80-column ANSI frame

RAMGON.png is a 1152×925 RGBA real-world image fixture (~2 MB on
disk; ~4.3 MB inflated). At `--width 80`, kii picks a 80×N aspect-
preserving target where N = `(80 × 925) / 1152 / 2 ≈ 32` source rows
per the half-block math — so the rendered frame is 80 cells wide and
32 terminal rows tall.

**Why this example**: covers the dominant production code path —
RGBA color_type=6, bit_depth=8, real-world IDAT-fusing (multiple
IDAT chunks), 256-color SGR emit via 16-color palette quantization.

**What you should see**: a colorful half-block rendering of the
RAMGON fixture. The image looks like a low-res palette-quantized
version of the source; on a 256-color terminal the SGR escapes
render as the closest of the 16-color ANSI palette entries.

**Cross-check**:

```sh
./build/kii --verbose --width 80 tests/fixtures/RAMGON.png > /dev/null
# stderr: tests/fixtures/RAMGON.png: 1152x925 1065600 pixels (RGBA) → 16-color
```

**Bench reference**: per `docs/benchmarks.md` § v0.7.0, this exact
shape takes ~752 ms per iteration (dominated by `png_decode_pixels`).
