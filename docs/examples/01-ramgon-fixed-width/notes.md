# 01 — RAMGON.png → 80-column ANSI frame

RAMGON.png is a 1152×925 RGBA real-world image fixture (~2 MB on
disk; ~4.3 MB inflated). At `--width 80`, kii picks a 80×N aspect-
preserving target where N = `(80 × 925) / (1152 × 2) = 32` terminal rows
(64 source rows) per the half-block math — so the rendered frame is 80
cells wide and 32 terminal rows tall. (This read "≈ 32 source rows"
until v1.6.4: the count is terminal rows, the trap
[architecture item 002](../../architecture/README.md) describes.)

**Why this example**: covers the dominant production code path —
RGBA color_type=6, bit_depth=8, real-world IDAT-fusing (121 IDAT
chunks, fused inside `chitra`), and the default tier-16 emit: plain
SGR codes, each written only when it changes (ADR 0010). Every pixel is
opaque, so neither v1.6.4's alpha compositing nor v1.8.0's transparency
touches this frame. v1.9.0's pixel-centre sampling does: it moves every
cell half a cell toward the image's true centre (ADR 0005).

**What you should see**: a colorful half-block rendering of the
RAMGON fixture. The image looks like a low-res palette-quantized
version of the source, drawn in the terminal's own 16 named colours.
`--dither ordered` or `--dither fs` trades the flat bands for a
pattern of two neighbouring colours (ADR 0011).

**Cross-check**:

```sh
./build/kii --verbose --width 80 tests/fixtures/RAMGON.png > /dev/null
# stderr: tests/fixtures/RAMGON.png: 1152x925 1065600 pixels (RGBA) → 16-color
```

**Bench reference**: the nearest bench is `end-to-end RAMGON.png →
80×24 frame`, which runs ~200–235 ms per iteration at v1.6.3–v1.6.4
(`docs/benchmarks.md` § v1.6.3 and § v1.6.4). About 83 % of that is
sankoch's inflate inside chitra's PNG decode; kii's own downscale,
quantize and emit are under 1 %. (This cited ~752 ms "dominated by
`png_decode_pixels`" from § v0.7.0, a kii function deleted in the
v1.2.0 re-fold.)
