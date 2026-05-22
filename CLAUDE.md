# kii — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

---

## Project Identity

**kii** (Hawaiian: *image / picture / likeness*) — image → ANSI/ASCII-art converter for terminal display. Cyrius-native equivalent of `chafa` / `jp2a` / `viu`. Reads raster image input (PNG, JPEG, GIF, BMP planned), quantizes to a terminal-renderable color palette + glyph set, emits ANSI escape sequences sized to terminal cols × rows.

- **Type**: Binary (user-facing CLI tool)
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`, currently `6.0.1`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Genesis repo**: [agnosticos](https://github.com/MacCracken/agnosticos)
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/first-party-documentation.md)
- **Shared crates**: [shared-crates.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/planning/shared-crates.md)
- **Naming lane**: Polynesian-direct (Hawaiian micro-cluster with `hapi`, `anuenue`)

## Goal

Own the *image-to-terminal* conversion surface for AGNOS. Read a raster image; emit ANSI escapes that approximate it at a chosen color tier + glyph set. The contract is: one-image-in, one-frame-of-ANSI-out, sized to the caller's terminal geometry. Stable enough to be the MOTD-banner producer for BBS apps, the room-illustration renderer for MUD apps, and the `iam`-style splash component for arbitrary shells.

## Color-tier discipline (durable)

The color-tier roadmap is deliberate:

- **Tier 1 (v0.x → v1.0)**: 8/16-color ANSI palette + half-block (`▀`/`▄`) glyph quantization. This is the historically-correct rendering target for BBS / MUD clients of the early-90s era — maximum terminal compatibility, well-defined floor.
- **Tier 2 (post-v1)**: 256-color ANSI + 24-bit truecolor escape sequences + dithering schemes (Floyd-Steinberg, ordered/Bayer).
- **Tier 3 (future)**: Sixel / Kitty / iTerm2 image-protocols (skip ASCII art entirely on supporting terminals).

**Why tier 1 first**: BBS/MUD clients of the 1990s rendered 8/16-color ANSI; that's the cycle this tool was scoped in. Higher tiers are skip-able at runtime when the consumer wants them, but the FLOOR is what the BBS revival aesthetic needs.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, surface area, in-flight work, consumers, dep gaps.
> Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init kii` on 2026-05-22 (greenfield). **Do not manually create project structure** — use the tools. If a tool is missing something, fix the tool.

## Quick Start

```sh
cyrius deps                          # resolve stdlib deps
cyrius build src/main.cyr build/kii  # compile
cyrius test                          # run [build].test + tests/*.tcyr
./build/kii --version                # smoke run
```

## Key Principles

- **Correctness over cleverness** — if it's wrong, the bugs own you
- Test after every change, not after the feature is "done"
- ONE change at a time — never bundle unrelated changes
- Build with `cyrius build`, not raw `cat file | cycc` — the manifest auto-resolves deps and prepends includes
- Source files only need project includes — stdlib / external deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N **bytes** at function scope, N×u64 at module scope (per AGNOS feedback memory `cyrius_var_array_u64_units`)
- `&&` / `||` short-circuit; mixed expressions require explicit parens
- **Multi-source convergent port discipline**: image-decode and color-quantization shapes come from MULTI-SOURCE prior art — `chafa` (canonical) + `jp2a` + `viu` + `libcaca` + PNG/JPEG specs. Never single-source from one ref.

## Domain-specific rules (kii)

- **Half-block (`▀`/`▄`) glyph aesthetic is the FLOOR** — every output mode renders at half-block density by default; quarter-blocks (`▘`/`▝`/`▖`/`▗`) or full pixels (`█`) are opt-in. Half-block doubles vertical resolution per character row for free.
- **CRC / signature validation on every image input** — corrupt PNGs are an attack surface; reject malformed files at the spec layer, do not "guess" geometry.
- **No file writes** — kii is a stdin/argument → stdout renderer. Reads input, writes ANSI, exits. No persistent state.
- **Terminal-size detection via `ioctl TIOCGWINSZ`** at v0.7.0; `--width N` override always available; fall back to 80×24 (BBS-default) if both fail.
- **Color-quantization defaults to nearest-RGB in 16-color ANSI palette** — Floyd-Steinberg + ordered dither are post-v1 tier-2 work, not v1.0 scope.

## Rules (Hard Constraints)

- **Read the genesis repo's CLAUDE.md first** — [agnosticos/CLAUDE.md](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md)
- **Do not commit or push** — the user handles all git operations
- **NEVER use `gh` CLI** — use `curl` to the GitHub API if needed
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection
- Do not trust external data (image files, args) without validation — every parser path must bound-check
- Do not modify `lib/` files (vendored stdlib / dep symlinks)
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth
- Do not add Cyrius stdlib includes in individual src files — the manifest resolves them
- Do not pre-add dep entries to `cyrius.cyml` before a consumer surfaces — add `darshana` at v0.6.0 (when ANSI emit lands), `sankoch` at v0.4.0 (when DEFLATE-through-IDAT lands)

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos
- [`docs/examples/`](docs/examples/) — Runnable examples
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0
- [`docs/doc-health.md`](docs/doc-health.md) — Per-file doc-currency ledger

## Process

1. **Work phase** — features, roadmap items, bug fixes (always smallest-first; one milestone per cycle)
2. **Build check** — `cyrius build`
3. **Test + benchmark additions** for new code (parser-path fuzz harnesses for image decoders)
4. **Internal review** — performance, memory, correctness, edge cases (malformed input = parser stress)
5. **Documentation** — update CHANGELOG, `docs/development/state.md`, any ADR the change earned
6. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header

## Naming

- **Repo + binary**: `kii` (ASCII-safe form)
- **Display form**: `kiʻi` with ʻokina punctuation when written formally
- **Repo prefix**: NO `cyrius-` prefix — that's reserved for games per the AGNOS `project_game_naming_convention` memory; kii is a tool, gets a bare name (sibling to `hapi`, `anuenue`, `bannermanor`, `mihi`)
