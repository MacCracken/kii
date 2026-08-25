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

## Milestone-aligned contributions

The roadmap to v1.0 is broken into eight milestones (M0-M7) in [`docs/development/roadmap.md`](docs/development/roadmap.md). Contributions are easiest to land when they fit the current open milestone's acceptance criteria. If you have something larger in mind, open an issue first to discuss sequencing.

## Adding a new color-tier mode

Tier-2 (256-color, truecolor, dithering) and tier-3 (Sixel, Kitty, iTerm2 image protocols) are **deferred to post-v1** per [`CLAUDE.md` § Color-tier discipline](CLAUDE.md). PRs that introduce these before v1.0 freezes will be redirected to a v1.x milestone discussion. The deliberate-order rationale is documented in [`docs/development/roadmap.md`](docs/development/roadmap.md).

## Adding a new image format

PNG is the v1.0-required format. JPEG / GIF / BMP and friends are v1.x bites. Same pattern as color tiers — open an issue to confirm sequencing before writing the code.

## Adding a new dep

Per `CLAUDE.md`, deps are added **at the milestone gate that requires them**, not pre-emptively:

- `sankoch` (DEFLATE) — landed at v0.4.0 / M3. Now a stdlib entry (folded into Cyrius stdlib at v5.8.65); not a `[deps.sankoch]` block.
- `darshana` (ANSI primitives) — lands at v0.6.0 / M5 as the first external git dep.

Other deps need a written rationale in the PR (what does it own that we can't do in-tree? does an AGNOS-family substrate already exist? has the substrate-extraction trigger fired?). See [`first-party-standards.md § Own the Stack`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md#own-the-stack).

## Tests

Every behavior change needs at least:

- One happy-path test in the suite that owns the area. The monolithic `tests/kii.tcyr` was **retired at v1.2.0** and split into five standalone suites: `tests/cli.tcyr` (flag parsing + the path sanitizer), `tests/quant.tcyr` (palette + quantizer), `tests/render.tcyr` (downscale + emit + geometry), `tests/ascii.tcyr` (`--mode ascii`), `tests/decode.tcyr` (the chitra adapter, per format).
- One error-path test (malformed input, out-of-range arg, etc.)
- For image-decode contributions: at least one fuzz seed in `tests/kii.fcyr` — it hosts **eight** surfaces (arg-parser, path-sanitizer, geometry, emit-pipeline, PNG, JPEG, BMP, GIF); add to whichever the change touches. If you add a surface that calls `alloc_reset()`, it **must** also clear `crc32_table` — see the note in `fuzz_png_iter`, where omitting it silently voided a million iterations.
- For performance-critical paths: a bench in `tests/kii.bcyr` with the result captured in `docs/benchmarks.md`. A bench guarded on a system fixture must report a visible SKIP when the fixture is absent, never vanish from the output.

PRs without test coverage will be asked to add it. Current state: **550 unit assertions + 6,011,000 fuzz iters/run + 7 benches** as of v1.5.1.

## Commits and PRs

- Conventional Commits style preferred: `feat: …`, `fix: …`, `docs: …`, `test: …`, `refactor: …`, `chore: …`
- One concern per commit (mirror of CLAUDE.md "ONE change at a time")
- PRs reference the milestone they target if applicable
- The maintainer handles all releases and tagging — do not include `VERSION` bumps in feature PRs unless explicitly asked

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By contributing you agree to abide by its terms.
