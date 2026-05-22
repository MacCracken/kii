# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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
