# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.3.0] — 2026-05-22

### Added

- **M2 — PNG structural decoder**. Valid PNGs now print `<path>: <W>x<H> bit_depth=<N> color_type=<T>` to **stdout** + exit 0 (pipe-pure — consumers can `kii image.png | grep ...`). Distinct error paths surface specific failure modes on stderr + exit 1:
  - `<path>: cannot open file` — open syscall failed (not found, permissions).
  - `<path>: not a PNG (file shorter than 8 bytes)` — truncated before signature.
  - `<path>: not a PNG` — first 8 bytes don't match the W3C magic.
  - `<path>: malformed PNG header` — IHDR chunk truncated, wrong type, or claims length ≠ 13.
  - `<path>: CRC check failed` — IHDR or any post-IHDR chunk fails CRC32.
  - `<path>: malformed PNG (chunk truncated after IHDR)` — chunk header / data / CRC read returned partial bytes.
  - `<path>: warning: incomplete PNG (no IEND chunk seen)` — soft warning per spec § 5.3 tolerance; structural summary still emitted, exit 0.
- **`src/png.cyr`** — new module owning the full structural-decode surface:
  - `PNG_MAGIC` + `PNG_MAGIC_LEN` (W3C § 5.2 signature: detects 7-bit gateways, line-ending mangling, naive `type` cmd).
  - `PNG_OK` / `PNG_ERR_OPEN` / `PNG_ERR_TRUNCATED` / `PNG_ERR_NOT_PNG` / `PNG_ERR_HEADER` / `PNG_ERR_CRC` / `PNG_ERR_CHUNK` codes.
  - `IHDR_*_OFFSET` + `STRUCT_*_OFFSET` field layouts (aligned at the first four slots so summary helpers work on either buf).
  - `png_check_signature(buf)` + `png_validate_file_signature(path)` + `png_read_u32_be(buf, off)` (matches `lib/sha1.cyr`'s big-endian pattern).
  - `png_crc_init()` + `_png_crc_update(crc, buf, len)` + `png_crc32(buf, len)` — Ethernet CRC-32 (reversed polynomial 0xEDB88320, same as zlib / gzip). 256-entry lookup table, idempotent init. First first-party CRC32 in the AGNOS ecosystem; extracts to stdlib if a second consumer surfaces (per the extract-on-2nd-consumer pattern).
  - `png_decode_header(path, out_ihdr)` — signature + IHDR + IHDR-CRC.
  - `png_decode_structure(path, out_struct)` — single-fd open: signature → IHDR (with CRC) → walk subsequent chunks → IDAT count + total-size accumulation → IEND detection. Chunk data streamed through a 4 KB scratch buffer (bounded memory regardless of input size).
- **Multi-source convergent port** per CLAUDE.md hard rule: decoder shape drawn from W3C PNG Specification (1.3) + `libpng` + `stb_image.h` + `lodepng`. Not single-source.

### Changed

- `src/main.cyr` — replaced M1 placeholder dispatch with `png_decode_structure` orchestration. New `_print_ihdr_summary` (stdout) helper for the success line; `_eprint_path_msg` (stderr) for errors + warnings. Missing-IEND warning lands on stderr while the structural summary stays on stdout (pipe-purity).
- `tests/kii.fcyr` — gained a **second fuzz surface**. The same binary now runs both arg-parser fuzz (10k iters, ~50 ms) and **PNG-decoder fuzz** (2k iters, ~50 ms). PNG fuzz: deterministic LCG-driven random byte buffers written to `/tmp/kii-fuzz-png.bin`; 50% of iters prepend a valid signature + IHDR so the post-IHDR chunk walker is exercised. M7 audit raises both counts to 10⁶ per the v1.0 acceptance criterion.

### Tests

- `tests/kii.tcyr` — 88 assertions (was 36 at v0.2.0). New coverage: M2(a) signature check (10), M2(b) BE-u32 decode + IHDR parse over four color types + four malformed cases (25), M2(c) CRC32 canonical (zlib reference + IEND constant + empty buf) + structure walker happy-path + missing-IEND warning + IHDR/IEND CRC bit-flip + truncated mid-chunk (17). Helpers `_ut_put_u32_be` + `_ut_build_min_png` make valid PNG fixtures from runtime-computed CRCs (replaces the pre-(c) "XXXX" placeholders that wouldn't pass CRC validation).

### CI / Release

- `ci.yml` — added **version-drift smoke** (compares `./build/kii --version`'s first line against `VERSION` file; trips CI on mismatch). The M1 close-out cycle hit this drift class once locally — the smoke would have caught it before merge.
- `ci.yml` — added **fuzz step** (`tests/kii.fcyr`, now covers both arg-parser + PNG-decoder surfaces). 12k iters total, ~0.07 s.
- `ci.yml` + `release.yml` — fixed binary-name template default (`${{ github.event.repository.name }}` → hardcoded `kii`). The cyrius-init scaffold assumed repo-name = binary-name; kii's repo is `cyrius-kii` but the binary is `kii` per `cyrius.cyml [build].output` and CLAUDE.md Quick Start.
- **Still deferred** (CI/release thorough setup): CHANGELOG-extracted release notes, aarch64 cross-build, macOS / Windows cross-build, Sigstore / SLSA. Tracked in this section; reassess at v1.0 audit.

### Dependencies

- stdlib unchanged from v0.2.0 (still `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`, `flags`). PNG decoder uses only what's already in.
- External: still none. **`sankoch` lands at M3 (v0.4.0)** for DEFLATE-through-IDAT decompression.

## [0.2.0] — 2026-05-22

### Added

- **M1 — CLI arg parsing**. Full flag surface frozen at the syntactic level (the surface is contractually stable from here through v1.0):
  - `--help` / `-h` — prints usage to stderr (pipe-pure stdout); exits 0.
  - `--version` / `-V` — prints `kii 0.2.0` + the Hawaiian etymology line to stdout; exits 0.
  - `--width N` / `-w N` — output width in columns; default `0` is the M6 sentinel for "match terminal" (auto-detected via `ioctl TIOCGWINSZ` once M6 lands).
  - `--color N` / `-c N` — color tier; only `8` or `16` valid per CLAUDE.md tier-1 color-discipline. Tier-2 modes (256 / truecolor) explicitly rejected; deferred to post-v1.
  - Positional `<image.png>` — captured into `flags_positional`; zero or 2+ rejected with `kii: missing image path` / `kii: too many arguments` (exit 2).
- **src/cli.cyr** — new module. Owns `KII_EXIT_*`, `KII_F_*` flag indices, `kii_register_flags(fs)`, `kii_validate_color(color)`. Split out of main.cyr so unit tests + fuzz harness can drive kii's exact flag set in-process.
- **Placeholder dispatch** — `kii image.png` (and any valid path) prints `<path>: decoder not yet implemented (width=N color=N)` to stderr + exits 1. The width/color echo proves the flag values were captured into module state. Superseded at M2 when the structural decoder lands.

### Changed

- `src/main.cyr` — `args_init` + `alloc_init` + `kii_register_flags` + `flags_parse` + dispatch. Scaffold no-args banner removed in favor of the missing-path usage error (kii now requires a positional path).
- `cyrius.cyml` — `[deps].stdlib` gained `"flags"` (consumer: CLI flag parsing).

### Tests

- `tests/kii.tcyr` — 36 assertions (was 2). Coverage: smoke + math (2), `kii_validate_color` happy/sad table (8), flag-parse happy paths over the full flag set (long/short/attached forms, defaults, positional capture — 14), each `FLAG_ERR_*` variant (unknown / missing value / bad int / bundled — 8), multi-positional capture (2), version-literal regression baseline left for v0.3.0 (intentionally deferred; the literal isn't auto-generated yet).
- `tests/kii.fcyr` — wired. Deterministic Numerical-Recipes LCG (seed = 1) drives 10,000 iterations of random argv against kii's flag set. Bias toward `-x` / `--foo` prefixes (50% of args) so the parser exercises its flag-recognition path. M7 audit raises to 10⁶ iterations per the v1.0 acceptance criterion. Catches arg-parser crash regressions; PNG-decoder fuzz comes at M2 in a separate harness.

### Dependencies

- stdlib: + `"flags"` (was `args`-only for CLI). All other stdlib modules unchanged.
- External: still none (sankoch lands at M3, darshana at M5).

### CI / Release

- `.github/workflows/ci.yml` — added `workflow_call:` trigger so `release.yml` can gate on it via `uses: ./.github/workflows/ci.yml`. **This was the minimum fix required** to make a v0.2.0 tag actually release rather than blow up at the CI-gate dispatch.
- **Deferred (CI/release thorough setup)** — captured here as the punch list for a dedicated cycle:
  - Run the fuzz harness in CI (`cyrius build tests/kii.fcyr build/kii-fuzz && ./build/kii-fuzz`) on every PR.
  - Add a binary-version smoke step after build (`./build/kii --version | grep "^kii $(cat VERSION)$"`) so a stale `print_version` literal trips CI rather than silently drifting (the M1 work already hit this drift class once).
  - Extract release notes from `CHANGELOG.md`'s `[X.Y.Z]` section rather than relying on GitHub's PR-title `generate_release_notes: true`.
  - aarch64 cross-build (`cyrius build --aarch64`) — release ships only x86_64 today; cyrius supports aarch64 natively.
  - macOS / Windows cross-build (post-v1 — out of v0.2.0 scope).
  - Sigstore / SLSA provenance attestation (probably overkill for kii's threat model; reassess at v1.0 audit).

## [0.1.0] — 2026-05-22

### Added

- `cyrius init kii` scaffold:
  - `VERSION`, `cyrius.cyml`, `LICENSE` (GPL-3.0-only), `.gitignore`
  - `src/main.cyr` — entry point; prints version banner + Hawaiian etymology + scaffold-status line
  - `src/test.cyr` — test entry routing to `tests/kii.tcyr`
  - `tests/kii.tcyr` — primary test suite (smoke + math; 2 assertions, all pass)
  - `tests/kii.bcyr` — benchmark stub (wired at M4)
  - `tests/kii.fcyr` — fuzz stub (wired at M2)
  - `docs/adr/`, `docs/architecture/`, `docs/guides/`, `docs/examples/` skeleton
  - `.github/workflows/ci.yml` + `release.yml`
- First-party-standards docs:
  - `CLAUDE.md` — Project Identity, Goal, color-tier discipline (tier 1 = 8/16-color + half-block; tier 2 post-v1), domain rules (half-block floor, CRC validation, no file writes), naming-lane notes
  - `README.md` — Hawaiian etymology, status, color-tier roadmap, substrate plan (darshana + sankoch + in-repo PNG decoder), multi-source prior art table (chafa / jp2a / viu / libcaca + PNG spec)
  - `CONTRIBUTING.md` — dev workflow, milestone-aligned contributions, dep-add discipline, tests requirement
  - `CODE_OF_CONDUCT.md` — Contributor Covenant v2.1 pointer
  - `SECURITY.md` — explicit threat surface (malformed image input, decompression amplification, ANSI escape injection), mitigations in code, reporting channel
  - `docs/development/state.md` — initial scaffold snapshot
  - `docs/development/roadmap.md` — M0-M7 milestones to v1.0 with acceptance criteria + dep gates
  - `docs/doc-health.md` — per-file currency ledger; tier classification; refresh discipline

### Toolchain

- Cyrius pin: `6.0.1`

### Dependencies

- stdlib: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`
- External: none yet (sankoch + darshana lands at M3 + M5 respectively)

### Naming

- Repo + binary: `kii` (ASCII-safe form; no `cyrius-` prefix — that's reserved for games per AGNOS `project_game_naming_convention`)
- Display form: `kiʻi` with ʻokina punctuation
- Lane: Polynesian-direct (Hawaiian micro-cluster — sibling to `hapi`, `anuenue`)
