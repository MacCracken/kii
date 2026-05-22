# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.2.0** — M1 (CLI arg parsing) closeout — 2026-05-22.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

CLI flag surface frozen at the syntactic level; no image decode yet. The binary parses + dispatches:

- `--help` / `-h` — usage to stderr; exit 0
- `--version` / `-V` — `kii 0.2.0` + Hawaiian etymology to stdout; exit 0
- `--width N` / `-w N` — width (default `0` = M6 sentinel for "match terminal")
- `--color N` / `-c N` — 8 or 16 only; anything else → `kii: --color must be 8 or 16` + exit 2
- Positional `<image.png>` — required; zero or 2+ → usage error + exit 2; one → `<path>: decoder not yet implemented (width=N color=N)` to stderr + exit 1

Module map:

- `src/main.cyr` — I/O glue: `print_version`, `print_usage`, `_eprint`, `_eprint_placeholder`, `build_argv_array`, `main` + dispatch.
- `src/cli.cyr` — testable bits: `KII_EXIT_*` codes, `KII_F_*` flag indices, `kii_register_flags(fs)`, `kii_validate_color(c)`.
- `src/test.cyr` — test entry routing.
- `tests/kii.tcyr` — 36 assertions across smoke + `kii_validate_color` + flag-parse happy paths + each `FLAG_ERR_*` variant + multi-positional capture.
- `tests/kii.fcyr` — 10k-iter deterministic-LCG fuzz over kii's flag set (arg-parser crash-safety).
- `tests/kii.bcyr` — still a no-op stub (wires at M4 per roadmap).

## Binary size

Build: ~50 KB at v0.2.0 (compiler reports 278 unreachable fns / 41 KB DCE-eliminable). Set `CYRIUS_DCE=1` for a leaner artifact when measuring against the v1.0 size budget.

## Tests

- `cyrius test` — **36 assertions, all pass** (was 2 at v0.1.0).
- Fuzz — `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` runs 10,000 iterations in ~0.04s on x86_64 Linux. Exit 0. CI wiring deferred per the v0.2.0 CHANGELOG CI/release punch list.

## Dependencies

Direct (declared in `cyrius.cyml [deps]`):

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`
  - `flags` added at v0.2.0 sub-bite (a) — consumer surfaced (CLI parsing).
- **External**: none yet. Pending dep gates per [`roadmap.md`](roadmap.md):
  - `sankoch` — added at v0.4.0 (PNG IDAT DEFLATE decompression)
  - `darshana` — added at v0.6.0 (ANSI emit primitives)

## Consumers (planned, not yet integrated)

Unchanged from v0.1.0:

- **BBS server** (TBD, agnosticos planned-repo) — MOTD / login banner ANSI art
- **MUD server** (TBD, agnosticos planned-repo) — room-description illustration art
- **End-user shells** — image preview / demo flair
- **`iam`** — possibly, for richer login splash art (TBD per `iam` minimalism principle)

No consumers yet — pre-MVP.

## Cycle context

Scaffolded + M1 both landed during agnos kernel cycle **1.32.x networking-arc**. Strategic relevance unchanged: BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

M2 — PNG structural decoder (v0.3.0). See [`roadmap.md`](roadmap.md) for the acceptance criteria + dep gates. First in-repo module: `src/png.cyr`.
