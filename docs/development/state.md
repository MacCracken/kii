# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.3.0** — M2 (PNG structural decoder) closeout — 2026-05-22.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

PNG structural decode complete; pixel decode pending (M3 / sankoch). Binary parses + validates + emits the M2 success line:

- `kii image.png` → `<path>: <W>x<H> bit_depth=<N> color_type=<T>` to **stdout** + exit 0 (valid + CRC-clean PNG, IEND seen).
- Missing IEND → same stdout line + a stderr warning + exit 0 (per spec § 5.3 tolerance).
- Errors all on stderr + exit 1, distinct messages per failure mode (cannot open / not a PNG / malformed header / CRC failure / chunk truncated).
- CLI surface from v0.2.0 unchanged: `--help` / `--version` / `--width N` (default 0 = match terminal, M6) / `--color N` (8 or 16) / positional `<image.png>`.

Module map:

- `src/main.cyr` — I/O glue: `print_version`, `print_usage`, `_eprint`, `_eprint_path_msg`, `_print_ihdr_summary` (stdout), `build_argv_array`, `main` + PNG dispatch.
- `src/cli.cyr` — testable CLI bits: `KII_EXIT_*` codes, `KII_F_*` flag indices, `kii_register_flags(fs)`, `kii_validate_color(c)`.
- `src/png.cyr` — PNG structural decoder: signature/IHDR/CRC32/chunk-walker. Public API: `png_check_signature`, `png_validate_file_signature`, `png_read_u32_be`, `png_crc_init`, `png_crc32`, `png_decode_header`, `png_decode_structure`.
- `src/test.cyr` — test entry routing.
- `tests/kii.tcyr` — 88 assertions across smoke + `kii_validate_color` + flag-parse paths + PNG signature + IHDR parse + CRC32 canonical + structure walker + corruption cases.
- `tests/kii.fcyr` — **two fuzz surfaces**: 10k-iter arg-parser fuzz + 2k-iter PNG-decoder fuzz. Both deterministic-LCG, both ~0.04 s.
- `tests/kii.bcyr` — still a no-op stub (wires at M4 per roadmap).

## Binary size

Build: ~50 KB at v0.3.0 (compiler reports 268 unreachable fns / 41 KB DCE-eliminable). Set `CYRIUS_DCE=1` for a leaner artifact when measuring against the v1.0 size budget.

## Tests

- `cyrius test` → **88 assertions, all pass** (was 36 at v0.2.0; was 2 at v0.1.0).
- Fuzz: `cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz` → 10k arg-parser iters + 2k PNG-decoder iters in ~0.07 s on x86_64 Linux. Exit 0. Both wired into CI per the v0.3.0 ci.yml Fuzz step.

## Dependencies

Direct (declared in `cyrius.cyml [deps]`):

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags` (unchanged from v0.2.0).
- **External**: none yet. Pending dep gates per [`roadmap.md`](roadmap.md):
  - `sankoch` — added at v0.4.0 (PNG IDAT DEFLATE decompression). **Next milestone**.
  - `darshana` — added at v0.6.0 (ANSI emit primitives).

## Real-PNG smoke

Tested against `/usr/share/pixmaps/archlinux-logo.png` (256×256, palette) and `/usr/share/pixmaps/kitty.png` (256×256, RGBA) — both walk all chunks cleanly with CRC validation.

## Consumers (planned, not yet integrated)

Unchanged from v0.2.0:

- **BBS server** (TBD, agnosticos planned-repo) — MOTD / login banner ANSI art
- **MUD server** (TBD, agnosticos planned-repo) — room-description illustration art
- **End-user shells** — image preview / demo flair
- **`iam`** — possibly, for richer login splash art (TBD per `iam` minimalism principle)

No consumers yet — pre-MVP.

## Cycle context

v0.3.0 close lands during agnos kernel cycle **1.32.x networking-arc**. Strategic relevance unchanged: BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle.

## Next

M3 — sankoch DEFLATE → raw RGB pixels (v0.4.0). First external dep gets added (`sankoch ≥ 2.2.5` in `cyrius.cyml [deps]`). Replaces the structural-summary stdout line with a `<path>: <W>x<H> decoded <N> pixels (<color_type_name>)` line at acceptance. See [`roadmap.md`](roadmap.md) for the full M3 acceptance criteria.
