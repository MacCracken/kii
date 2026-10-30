# Contributing to kii

Contributions are welcome. All contributions must be licensed under GPL-3.0-only.

## Development

Follow the conventions in [`CLAUDE.md`](CLAUDE.md) and the AGNOS [first-party standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md).

Build and test before submitting:

```sh
cyrius deps
cyrius build src/main.cyr build/kii
cyrius test
```

## Roadmap-aligned contributions

The roadmap ([`docs/development/roadmap.md`](docs/development/roadmap.md)) pins each open item to a version; contributions land easiest against the next pinned release. Open an issue first for anything larger.

## Adding a new color-tier mode

Tier-2 has shipped: 256-color and truecolor at 1.8.0 ([ADR 0010](docs/adr/0010-tier-2-colour-and-emit-encoding.md)), dithering at 1.9.0 ([ADR 0011](docs/adr/0011-dithering.md)). Tier-3 (iTerm2, Kitty and Sixel image protocols) is pinned to 2.4.0–2.6.0. See [`CLAUDE.md` § Color-tier discipline](CLAUDE.md) and [ADR 0003](docs/adr/0003-color-tier-discipline.md) for why the tiers come in this order. A PR for either should target the release the roadmap pins it to.

## Adding a new image format

kii carries no decoders. A new format arrives on a `[deps.chitra]` re-pin once [`chitra`](https://github.com/MacCracken/chitra) decodes it, and kii's side is diagnostics: a format kii renders must be one it can name in an error ([ADR 0006](docs/adr/0006-adopt-chitra-decoder.md), [ADR 0009](docs/adr/0009-bmp-gif-via-chitra.md)). Decoder work belongs in chitra. Open an issue to confirm sequencing before writing the kii side.

## Adding a new dep

Per `CLAUDE.md`, deps are added **when a consumer needs them**, not pre-emptively. The current set, with tags in [`cyrius.cyml`](cyrius.cyml):

- `sankoch` (DEFLATE) — wired at v0.4.0 / M3. A stdlib entry since Cyrius v5.8.65, not a `[deps.sankoch]` block; chitra's PNG path resolves its inflate from it.
- `darshana` (ANSI escapes, terminal size, the path sanitizer) — `[deps.darshana]` since v0.6.0 / M5, the first external git dep.
- `cmdit` (CLI parsing) — `[deps.cmdit]` since v1.1.0.
- `chitra` (PNG / JPEG / BMP / GIF decode) — `[deps.chitra]` since v1.2.0.

Other deps need a written rationale in the PR (what does it own that we can't do in-tree? does an AGNOS-family substrate already exist? has the substrate-extraction trigger fired?). See [`first-party-standards.md § Own the Stack`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md#own-the-stack).

## Tests

Every behavior change needs at least:

- One happy-path test in the suite that owns the area. The monolithic `tests/kii.tcyr` was **retired at v1.2.0** and split into standalone suites, eight since v2.4.0: `tests/cli.tcyr` (flag parsing + the path sanitizer), `tests/quant.tcyr` (palette + quantizer), `tests/render.tcyr` (downscale + emit + geometry), `tests/ascii.tcyr` (`--mode ascii`), `tests/blocks.tcyr` (`--mode blocks`), `tests/braille.tcyr` (`--mode braille`), `tests/iterm.tcyr` (`--mode iterm`, base64, the PNG writer), `tests/decode.tcyr` (the chitra adapter, per format).
- One error-path test (malformed input, out-of-range arg, etc.)
- For image-decode contributions: at least one fuzz seed in `tests/kii.fcyr` — it hosts **eighteen** surfaces (arg-parser, path-sanitizer, geometry, emit-pipeline, PNG, JPEG, BMP, GIF, the path-sanitizer differential, the terminal envelope, the ASCII lane, v1.10.0, its area sampler, v1.11.0, the blocks lane's shape choice and frames, v2.0.0, half-block rows read back to their colours, v2.1.0, `--invert` against the negative with `--color none` against the stripped escapes, v2.2.0, the Braille lane's sampler, ink rules, negative and escapes, v2.3.0, and the PNG writer read back by chitra with base64 against a reference, v2.4.0); a new surface goes after the last one, so the older surfaces keep the random stream they have always drawn; add to whichever the change touches, and give a new surface a `bad` count — any non-zero count fails the run. If you add a surface that calls `alloc_reset()`, also clear `crc32_table` — see the note in `fuzz_png_iter`, where omitting it once silently voided a million iterations. (sankoch's arena canary has covered this upstream since 2.7.10, re-verified at cyrius 6.7.9; the line stays as a second guard.)
- For performance-critical paths: a bench in `tests/kii.bcyr` with the result captured in `docs/benchmarks.md`. A bench guarded on a system fixture must report a visible SKIP when the fixture is absent, never vanish from the output.

- The ASCII lane's glyph table, `src/ascii_shape.cyr`, is generated: change `scripts/gen-shape-table.sh`, run `./scripts/gen-shape-table.sh > src/ascii_shape.cyr`, and confirm with `./scripts/gen-shape-table.sh --check`. It needs ImageMagick 7 (`magick`) and Liberation Mono, so CI does not run it; `tests/ascii.tcyr` pins the properties the matcher relies on instead.

PRs without test coverage will be asked to add it. Current state: **1,151 unit assertions + 8,671,000 fuzz iters/run + 13 benches** as of v2.4.0.

## Commits and PRs

- Conventional Commits style preferred: `feat: …`, `fix: …`, `docs: …`, `test: …`, `refactor: …`, `chore: …`
- One concern per commit (mirror of CLAUDE.md "ONE change at a time")
- PRs name the roadmap release they target, if any
- The maintainer handles all releases and tagging — do not include `VERSION` bumps in feature PRs unless explicitly asked

## Releases

The maintainer cuts releases. Pushing a tag `X.Y.Z` that matches `VERSION` runs
[`release.yml`](.github/workflows/release.yml): the whole of CI as a gate, then three binaries
(`kii-X.Y.Z-x86_64-linux`, `-aarch64-linux`, `-x86_64-agnos`) with `SHA256SUMS`, and the
version's CHANGELOG section as the notes.

CI ([`ci.yml`](.github/workflows/ci.yml)) runs on every push and pull request:
- the build, the version check (the binary, `VERSION` and a CHANGELOG section must agree), the
  suites, the fuzz harness, and the benches compiled but not run;
- the DCE build, checked against the plain build with `scripts/check-builds-agree.sh`;
- the agnos build;
- an aarch64 job: the suites under qemu-user, and the aarch64 binary checked against x86_64.

Every build goes through `scripts/build-strict.sh`, which fails on a compiler warning.

Before a cut, the maintainer also runs what CI cannot:
- `./scripts/gen-shape-table.sh --check` (needs ImageMagick 7 and Liberation Mono);
- the agnos build under [mirshi](https://github.com/MacCracken/mirshi), which runs an agnos
  binary on Linux:

  ```sh
  CYRIUS_DCE=1 cyrius build --agnos src/main.cyr build/kii-agnos
  scripts/check-builds-agree.sh build/kii build/kii-agnos mirshi --root /
  ```

  One case differs today, a directory argument (roadmap § Candidates);
- for a release that claims frames are unchanged, the same comparison over a large image
  corpus against the previous release's binary, in every lane.

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By contributing you agree to abide by its terms.
