# kii — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

The roadmap is **smallest-first** per AGNOS bite-discipline. Each milestone is sized to be a single coherent cycle of work (~3-7 days of focused effort), and each one ships a working binary that demonstrably does more than the previous one.

## v1.0 criteria

The contract for tagging v1.0:

- [x] CLI surface frozen — `--help`, `--version`, `--width N`, positional path arg, `--color N` (8 or 16), `--verbose` all stable (shipped at v0.2.0 / M1; `--verbose` activated at v0.6.0 / M5)
- [x] Half-block glyph emission at terminal-detected geometry works (half-block emit at v0.6.0 / M5; terminal-detection at v0.7.0 / M6)
- [x] Test coverage: 100+ assertions across all modules (426 as of v0.7.0)
- [ ] **Security audit pass** — external CVE / 0-day research compiled into `docs/audit/YYYY-MM-DD-audit.md`; PNG fuzz harness clean at 10⁶ iterations; ANSI-escape-injection paths reviewed; decode-latency matrix at 256² / 1024² / 2048² for DoS-bound validation (M7 / v0.8.0)
- [ ] PNG decoder handles the W3C test suite's "basic" image set without crashing on any malformed input from the "broken" set (M7 audit work)
- [ ] 16-color quantization output passes visual review against `chafa --colors 16` on a curated 10-image test set (M8 freeze work)
- [ ] At least one downstream consumer (BBS or MUD app) integrated and green (M8 freeze work)
- [ ] Cross-terminal verification — Linux console, xterm, Alacritty, kitty, tmux (M8 freeze work)
- [ ] CHANGELOG complete from v0.1.0 onward — rolling per release (currently v0.1.0–v0.7.0 entered)
- [ ] All ADRs written for design decisions made during M0-M6 (0001 PNG-in-repo landed at M6; 0002 security-model + any others land at M7 / M8)
- [ ] Docs / guides / examples all current per `docs/doc-health.md` (M8 freeze work)
- [ ] Marketplace recipe in zugot (M8 freeze work)

## Shipped milestones (M0 → M6, v0.1.0 → v0.7.0)

All shipped 2026-05-22. Per-milestone delivered lists, sub-bite cadences, deferrals, and deps added live in [`../../CHANGELOG.md`](../../CHANGELOG.md) — this table is the index.

| Milestone | Version | Headline | Deps added |
|---|---|---|---|
| M0 — Scaffold | [v0.1.0](../../CHANGELOG.md#010--2026-05-22) | `cyrius init` + doc tree + smoke test (2 assertions) | stdlib baseline (string/fmt/alloc/io/vec/str/syscalls/assert/bench/args) |
| M1 — CLI flag surface | [v0.2.0](../../CHANGELOG.md#020--2026-05-22) | `--help` / `--version` / positional path / `--width N` / `--color N` parsed + frozen; arg-parser fuzz | stdlib `flags` |
| M2 — PNG structural decoder | [v0.3.0](../../CHANGELOG.md#030--2026-05-22) | Signature + IHDR + CRC32 + chunk walker + IEND; PNG-decoder fuzz | — |
| M3 — sankoch DEFLATE → pixels | [v0.4.0](../../CHANGELOG.md#040--2026-05-22) | sankoch zlib_decompress + spec § 9 filter undo (None/Sub/Up/Avg/Paeth) | stdlib `sankoch`, `thread` |
| M4 — 16-color quantization | [v0.5.0](../../CHANGELOG.md#050--2026-05-22) | Linux-console palette + Euclidean-RGB nearest-neighbor + PLTE capture; first bench | — |
| M5 — Half-block ANSI emit | [v0.6.0](../../CHANGELOG.md#060--2026-05-22) | ▀ glyph + per-row 256-color escapes; downscale.cyr + emit.cyr; `--verbose` activated | external `darshana 0.5.3` (first git dep) |
| M6 — Terminal-size detect | [v0.7.0](../../CHANGELOG.md#070--2026-05-22) | `tty_winsize` auto-detect + `--width N` honored; aspect-preserving fit; multi-resolution bench; ADR 0001 + architecture/README backfill | — |

**At v0.7.0**: 426 assertions all pass; four benches captured; CLI surface feature-complete for v1.0; production pipeline (structure → pixels → downscale → quantize → emit) is the path through all five v0.x cycles.

## In-flight + remaining milestones

### M7 — Security audit cycle (v0.8.0)

**Goal**: External-source-informed security audit of kii's threat surface. No new user-facing features; output is a comprehensive audit document + hardening commits + scaled fuzz coverage. This is the work the original "M7 = v1.0 freeze" lumped together with socialization — separated here because the security audit is its own dedicated cycle with **external web research for 0-days and CVEs against the substrate libraries kii draws on**.

**Threat surfaces** (per [`../../SECURITY.md`](../../SECURITY.md)):

1. **PNG decoder surface** — malformed / malicious PNG input. `src/png.cyr` parses untrusted bytes; integer overflows on dimension multiplication, IHDR / PLTE / IDAT ordering tricks, CRC bypass attempts, and chunk-truncation edge cases are all in scope.
2. **DEFLATE / zlib surface** — decompression amplification ("zip bombs"). sankoch is the Cyrius-native DEFLATE impl, but the algorithm has the same attack surface as zlib regardless of language; bugs in the underlying spec mechanics transfer.
3. **ANSI escape injection** — path argument + filename flow through `_eprint*` family to stderr; a maliciously-named file is the kii-controlled stdout/stderr injection vector. Terminal-emulator escape sequence parsing bugs are out of scope but worth surveying for context.

**Acceptance criteria**:

- [ ] **External CVE/0-day research compiled into `docs/audit/2026-MM-DD-audit.md`**:
  - libpng CVEs from 2010+ — every advisory walked, kii-applicability assessed per class
  - lodepng + stb_image bug histories — same treatment
  - zlib CVEs (CVE-2018-25032 / CVE-2022-37434 / CVE-2023-45853 + any later) — kii uses sankoch (stdlib), but cross-impl bug-class transfer
  - Terminal emulator escape sequence CVEs (CVE-2022-31202 / CVE-2003-0859 / etc.) — context only; out of kii's bug-fix scope
  - W3C PNG test suite "broken" set — each broken-case PoC fed through `kii` to confirm clean rejection or document the gap
- [ ] PNG fuzz harness scales from 2k → **10⁶ iterations clean** in `tests/kii.fcyr`
- [ ] **New fuzz surfaces** added: random valid-PNG fixture → random downscale dims → emit_halfblock_row_buf; random target-geometry inputs into `_kii_compute_target_geometry` + `_kii_compute_fit_geometry`. Covers the M5+M6 modules previously fuzz-untested.
- [ ] Integer-overflow review on every size-derivation multiplication (`width × height × bpp`, `dst_w × dst_src_rows × 3`, `idat_total_size`); add explicit caps where the kernel allows attacker-controlled inputs to overflow i64
- [ ] **Decompression-amplification cap**: cap `idat_total_size` and the inflate output buffer to a configurable max (e.g. 256 MB) so a malformed IDAT claiming pathological dimensions can't OOM-DoS the host
- [ ] ANSI escape injection review: enumerate every byte path from user input (path argument) to stderr; document constraints + add defenses (path-sanitization or refusal to emit non-printable bytes in `_eprint_path_msg`)
- [ ] **Decode-latency matrix** at 256² / 1024² / 2048² source resolutions captured in `docs/benchmarks.md` — establishes the DoS-relevant worst-case timing envelope
- [ ] `docs/adr/0002-security-model.md` (or similar) — captures kii's threat model + audit findings + accepted residual risks
- [ ] CHANGELOG + VERSION → 0.8.0

**Sub-bite cadence**:

- **(a)** External research compilation — WebSearch + WebFetch across the CVE databases (NVD / CVE.org / Mitre / GitHub Security Advisories), libpng release notes, zlib changelogs, and any AGNOS first-party security-review playbook. Audit doc shape: per-CVE row with date / severity / class / kii-applicable? / remediation. Ship the doc before any code lands so the rest of the cycle is informed by the research.
- **(b)** Fuzz scaling (2k → 10⁶) + new fuzz surfaces (downscale + quant + emit + geometry). Iteration count change is small; the new surfaces are the real work.
- **(c)** Hardening commits for any vulnerabilities found in (a) + integer-overflow / bounds review + decompression-amplification cap.
- **(d)** Decode-latency bench matrix at three source resolutions + ADR 0002 + close-out (CHANGELOG, state.md, doc-health, version bump).

**Deps gates**: none expected. May add stdlib `bounds` if not already in (for size-cap helpers); confirmed during sub-bite (a).

### M8 — v1.0 freeze cycle (v1.0.0)

**Goal**: socialize, harden the integration story, ship the marketplace listing. No new code paths; no security work (M7 owned that). The signaling milestone — "kii is done, you can build on it."

**Acceptance criteria**:

- [ ] First BBS / MUD downstream consumer integrated and green (likely `bannermanor`'s MOTD path — `kii motd.png | bnrmr` style pipeline)
- [ ] Cross-terminal verification: Linux console (`TERM=linux`), xterm-256color, Alacritty, kitty, tmux. The 256-color escape codes are widely compatible, but `TERM=linux` may need a fallback path through named SGR 30–37 / 40–47 / 90–97 / 100–107.
- [ ] Visual review against `chafa --colors 16 --size 80x24 image.png` on a curated 5-image fixtures dir (`tests/fixtures/`) — RAMGON.png migrates from the top level into the fixtures dir as part of this
- [ ] `docs/guides/getting-started.md` backfilled — first runnable user-facing guide (overdue since M5)
- [ ] `docs/examples/` populated — first image-in → terminal-ANSI-out transcript (overdue since M5)
- [ ] All ADRs written for design decisions made during M0–M6 (0001 PNG-in-repo at M6, 0002 security-model at M7; M8 lands any others — color-tier discipline, nearest-neighbor downscale, half-block-as-floor are candidates if not already covered in CLAUDE.md + architecture/README)
- [ ] Marketplace recipe in zugot
- [ ] Doc-health ledger walks every Tier-1 row; all fresh
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] VERSION → 1.0.0; git tag

**Sub-bite cadence**:

- **(a)** First-consumer integration (bannermanor or chosen alternative) — kii substrate consumed at runtime; integration tests in the consumer's repo, not kii's.
- **(b)** Cross-terminal verification + curated fixtures dir; visual review captured as screenshots or text comparisons in `docs/audit/` or `docs/examples/`.
- **(c)** Docs backfill — getting-started, examples, remaining ADRs.
- **(d)** Marketplace + VERSION 1.0.0 + git tag + final CHANGELOG pass.

**Deps gates**: none expected.

## Out of scope (for v1.0)

The list keeps future contributors from adding to v1.0 by accident:

- **Tier 2 / 3 color modes** — 256-color, truecolor, dithering, Sixel, Kitty image protocol. All deferred to post-v1 per CLAUDE.md color-tier discipline.
- **JPEG / GIF / BMP decoders** — PNG only at v1.0. Other formats land as v1.x bites once a consumer needs them.
- **Animated GIF / video-frame-pipe** — explicit post-v2 scope.
- **Output to stdout-other-than-TTY-styled file formats** — e.g. no HTML output, no SVG output. kii is image → ANSI, full stop.
- **Image transformations** — no crop, no rotate, no scale-other-than-fit-terminal. Use upstream tools (ImageMagick) to pre-transform; kii consumes the result.
- **Interactive mode** — no live-resize-on-terminal-resize, no animation, no scroll. One frame in, one frame out, exit.
- **Filesystem traversal** — kii takes ONE file path. No glob, no recursive directory scan. Loop in the shell.

## Post-v1 considerations (informational, not commitments)

- **Tier 2 — 256-color + truecolor** (v1.1.0) — `--color 256` and `--color tc` modes; ordered/Floyd-Steinberg dither.
- **JPEG decoder** (v1.2.0) — JFIF subset via in-repo decoder OR via `tarang`-equivalent media-codec lib if it exists by then.
- **PNG substrate extraction** — when a second consumer needs PNG decoding, extract `src/png.cyr` → Sanskrit-named substrate lib (`chitra` / `rupa` / TBD per the tools-stable naming convention). See [ADR 0001](../adr/0001-png-decoder-in-repo.md).
- **Tier 3 — Sixel / Kitty protocols** (v2.0.0) — direct-image-protocol output for terminals that support it; the ASCII-art fallback stays the default. Possibly a major-version cut depending on CLI surface impact.

Captured deferrals will live as ADRs when the decision crystallizes.
