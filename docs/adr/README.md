# Architecture Decision Records

Decisions about kii — what we chose, the context, and the consequences we accept. Use these when a future reader would reasonably ask *"why did we do it this way?"*

## Conventions

- **Filename**: `NNNN-kebab-case-title.md`, zero-padded to four digits. Never renumber.
- **One decision per ADR.** If a decision supersedes a prior one, add a new ADR and set the old one's status to `Superseded by NNNN`.
- **Status lifecycle**: `Proposed` → `Accepted` → (optionally) `Superseded` or `Deprecated`.
- Use [`template.md`](template.md) as the starting point.

## ADR vs. architecture note vs. guide

| Kind | Lives in | Answers |
|---|---|---|
| ADR | `docs/adr/` | *Why did we choose X over Y?* |
| Architecture note | `docs/architecture/` | *What non-obvious constraint is true about the code?* |
| Guide | `docs/guides/` | *How do I do X?* |

## Index

| ADR | Status | Subject |
|---|---|---|
| [0001](0001-png-decoder-in-repo.md) | Superseded by [0006](0006-adopt-chitra-decoder.md) | PNG decoder lives in-repo (not as a substrate library) until a second consumer surfaces |
| [0002](0002-security-model.md) | Accepted | Security model: untrusted-image input + restricted-emit posture (M7 audit cycle) |
| [0003](0003-color-tier-discipline.md) | Accepted; tier-1-only and its `38;5;N` choice superseded by [0010](0010-tier-2-colour-and-emit-encoding.md) | Color-tier discipline: tier-1 (8/16-color) only at v1.0 |
| [0004](0004-half-block-floor-glyph.md) | Accepted (amended v2.0.0: Block Elements arrive opt-in, not as a successor; v2.1.0: `▀`/`▄`/`█`/space chosen per cell, bright colours kept in the fg at tier 16) | Half-block (`▀`/`▄`) as the floor glyph |
| [0005](0005-nearest-neighbor-downscale.md) | Accepted (amended v1.9.0: pixel-centre sampling; v1.11.0: the ASCII lane samples areas) | Nearest-neighbor downscale (no Lanczos / bilinear at v1.0) |
| [0006](0006-adopt-chitra-decoder.md) | Accepted | Adopt the chitra distlib; delete the in-repo PNG decoder (completes 0001) |
| [0007](0007-rendering-mode-taxonomy.md) | Accepted (amended v2.2.0: `--invert` and `--color none`, the ASCII lane's own, refused in the other lanes) | Rendering-mode taxonomy: half-block + character-glyph (`--mode ascii`) lanes |
| [0008](0008-jpeg-via-chitra.md) | Accepted | JPEG via chitra 0.3.0: signature-based format dispatch + JPEG validation posture (realizes 0006) |
| [0009](0009-bmp-gif-via-chitra.md) | Accepted | BMP + GIF via chitra 1.0.0: the re-pin that needed no decode change — a rendered format must be a nameable format (extends 0008) |
| [0010](0010-tier-2-colour-and-emit-encoding.md) | Accepted (amended v2.1.0: what the Linux console does with 90–107; v2.2.0: `--color none`, and partial alpha over white under `--invert`) | Tier 2 colour (`--color 256` / `tc`) and how a frame is encoded: real 8/16-colour SGR, elision, transparency (supersedes part of 0003) |
| [0011](0011-dithering.md) | Accepted | Dithering: `--dither none \| ordered \| fs` in the quantize layer, default `none` (extends 0003, 0005, 0010) |
| [0012](0012-block-elements-lane.md) | Accepted | The Block Elements lane, `--mode blocks`: 8 × 8 samples a cell, the least-error split in two colours, complements for fewer escapes, shades as a dither (amends 0004; extends 0005, 0007, 0011) |
