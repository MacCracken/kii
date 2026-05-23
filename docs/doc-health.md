# kii — Doc Health Ledger

> Per-file doc-currency ledger. Modeled on the AGNOS doc-audit-discipline pattern
> ([feedback_doc_audit_discipline](https://github.com/MacCracken/agnosticos/blob/main/.claude/projects/-home-macro-Repos-agnosticos/memory/feedback_doc_audit_discipline.md)).
>
> Each row tracks one doc + its last-verified-fresh date + tier + any debt. Refresh
> at every minor cut.

## Tiers

- **Tier 1 — Load-bearing**: read by Claude Code at session start; consumers reference these for integration. Drift cost = high.
- **Tier 2 — Reference**: consulted on specific work (porting, contribution); rotation drift cost = medium.
- **Tier 3 — Historical / archival**: snapshots; rotation drift cost = low.

## Ledger

| Doc | Tier | Last verified | Debt / notes |
|---|---|---|---|
| `README.md` | 1 | 2026-05-22 (v0.1.0 scaffold) | Fresh. Customized from `cyrius init` template. |
| `CLAUDE.md` | 1 | 2026-05-22 | Fresh. Custom Project Identity + Goal + color-tier discipline + domain rules. |
| `CHANGELOG.md` | 1 | 2026-05-22 (v0.5.0 close) | `[0.5.0]` + `[0.4.0]` + `[0.3.0]` + `[0.2.0]` + `[0.1.0]` entries; rolls per release. |
| `CONTRIBUTING.md` | 1 | 2026-05-22 | Fresh. Standard + kii-specific milestone-alignment notes. |
| `CODE_OF_CONDUCT.md` | 1 | 2026-05-22 | Contributor Covenant 2.1 pointer. |
| `SECURITY.md` | 1 | 2026-05-22 | Fresh. Threat model explicit; image-decoder hardening discipline captured. |
| `cyrius.cyml` | 1 | 2026-05-22 (v0.4.0 close) | Description filled; stdlib deps + toolchain pin set. `"flags"` at v0.2.0; `"sankoch"` + `"thread"` at v0.4.0. No deltas at v0.5.0 (M5 will add `darshana` as first external dep). |
| `docs/development/state.md` | 1 | 2026-05-22 (v0.5.0 close) | M4 close snapshot: 287 assertions, full PNG→16-color pipeline, first bench captured. **Bump per release.** |
| `docs/benchmarks.md` | 1 | 2026-05-22 (v0.5.0 — first capture) | Wired at M4: `quantize_nearest_rgb @ 1024×1024 = 274 ns/op`. **Bump per release that lands perf-critical paths.** |
| `docs/development/roadmap.md` | 1 | 2026-05-22 | M0-M7 milestones laid out to v1.0; acceptance criteria + dep gates per milestone. |
| `docs/adr/README.md` | 2 | 2026-05-22 (cyrius init template) | No ADRs yet. **`0001-png-decoder-in-repo.md` overdue** — was M3-targeted; sankoch+png module structure now stable enough to capture. Land at M5 close-out. |
| `docs/adr/template.md` | 2 | 2026-05-22 (cyrius init template) | Fresh. |
| `docs/architecture/README.md` | 2 | 2026-05-22 (cyrius init template) | **Empty placeholder; overdue** — was M2-flagged. Decoder + palette + quantizer module structure all settled at v0.5.0; backfill at M5 close-out. |
| `docs/guides/getting-started.md` | 2 | 2026-05-22 (cyrius init template) | Template-only. Backfill at M5 close (was M5-flagged originally — keep the gate; visible-ANSI output is what makes a "getting started" guide meaningful). |
| `docs/examples/.gitkeep` | 3 | 2026-05-22 (cyrius init template) | Empty. Add at M5 close (first image-in → terminal-ANSI-out transcript). |
| `tests/kii.tcyr` | 2 | 2026-05-22 (v0.5.0 close) | 287 assertions: M1 + M2 + M3 + M4(a) palette + M4(b) quantizer + M4(c) PLTE + M4(d) E2E + archlinux-logo.png palette real-world. Expand per milestone. |
| `tests/kii.bcyr` | 2 | 2026-05-22 (v0.5.0 close) | Wired at M4(d): `quantize_nearest_rgb` at 1,048,576 iterations → 274 ns/op. Future bench targets: full-image quantize, ANSI emit (M5), end-to-end PNG → 80×24 ANSI (M5+). |
| `tests/kii.fcyr` | 2 | 2026-05-22 (v0.4.0 close) | Two fuzz surfaces: 10k arg-parser iters (M1(d)) + 2k PNG-decoder iters (M2(d)+(M3 inflate/filter through random-prefix path)). Both deterministic-LCG. |
| `.github/workflows/ci.yml` | 1 | 2026-05-22 (post-0.2.0) | `workflow_call:` + binary-name fix + version-drift smoke + fuzz step landed. **Still pending**: CHANGELOG-extracted release notes, aarch64 cross-build (tracked in `[Unreleased]` CHANGELOG). |
| `.github/workflows/release.yml` | 1 | 2026-05-22 (post-0.2.0) | Binary-name fix landed. CHANGELOG-extracted release notes + multi-arch builds pending. |
| `LICENSE` | 1 | 2026-05-22 | GPL-3.0-only header (parity with bannermanor/hapi/etc.). |
| `.gitignore` | 2 | 2026-05-22 | Standard scaffold. |

## Debt summary at v0.5.0

- **Tier-1 docs**: all fresh. Zero structural debt. **Carry-forward** from v0.3.0: `release.yml` multi-arch / CHANGELOG-extracted-notes / Sigstore punch list still pending a dedicated CI cycle. **CI doesn't yet run benchmarks** — should be a follow-up step alongside the version-drift + fuzz + test steps already wired. Build-only would be enough (catches bitrot without per-PR timing noise).
- **Tier-2 docs**: 5 cyrius-init-template stubs remaining (`adr/README`, `adr/template`, `architecture/README`, `guides/getting-started`, `examples/.gitkeep`). **`architecture/README` overdue** — decoder + palette + quantizer module structure now fully established. **`docs/adr/0001-png-decoder-in-repo.md` overdue** — captured the rationale at M3, didn't land at M4; should ship at M5. **`docs/examples/`** has zero content; the M5 close should add a sample input → terminal-output transcript.
- **Repo hygiene**: `RAMGON.png` (1973 KB) committed at top level as a real-world test fixture. Consider moving to `tests/fixtures/` when a second fixture surfaces.

## Refresh discipline

- At every milestone cut (M1, M2, …): bump the "Last verified" column for any doc that changed.
- At every release tag: walk the whole ledger; mark every Tier-1 row as either still-fresh or refresh-needed.
- At v1.0 freeze: every Tier-1 row MUST be ≤ 1 minor old (i.e. verified within the most recent two minor cuts). Stale Tier-1 docs block the v1.0 tag.

## Out of scope (intentional)

- `lib/*.cyr` — vendored stdlib snapshots; tracked by cyrius's own doc-health, not kii's.
- `build/*` — gitignored; no doc tracking needed.
