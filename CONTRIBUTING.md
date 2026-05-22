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

- `sankoch` (DEFLATE) lands at M3 (v0.4.0)
- `darshana` (ANSI primitives) lands at M5 (v0.6.0)

Other deps need a written rationale in the PR (what does it own that we can't do in-tree? does an AGNOS-family substrate already exist? has the substrate-extraction trigger fired?). See [`first-party-standards.md § Own the Stack`](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md#own-the-stack).

## Tests

Every behavior change needs at least:

- One happy-path test in `tests/kii.tcyr`
- One error-path test (malformed input, out-of-range arg, etc.)
- For image-decode contributions: at least one fuzz seed in `tests/kii.fcyr`

PRs without test coverage will be asked to add it.

## Commits and PRs

- Conventional Commits style preferred: `feat: …`, `fix: …`, `docs: …`, `test: …`, `refactor: …`, `chore: …`
- One concern per commit (mirror of CLAUDE.md "ONE change at a time")
- PRs reference the milestone they target if applicable
- The maintainer handles all releases and tagging — do not include `VERSION` bumps in feature PRs unless explicitly asked

## Code of Conduct

Participation in this project is governed by the [Code of Conduct](CODE_OF_CONDUCT.md). By contributing you agree to abide by its terms.
