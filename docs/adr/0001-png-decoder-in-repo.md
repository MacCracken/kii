# 0001 — PNG decoder lives in-repo (not as a substrate library)

**Status**: Accepted
**Date**: 2026-05-22

## Context

kii's v1.0 scope is one image format: PNG. The PNG-decode surface is
nontrivial — chunk walker, CRC32 validation, DEFLATE-through-IDAT,
the five spec § 9 filter types, PLTE expansion, per-color_type pixel
extraction. Roughly 600 lines of Cyrius at v0.6.0.

Two reasonable homes for that code existed when M2 started:

1. **In-repo**: `src/png.cyr` is part of kii. The decoder is private
   to kii and evolves with its callers.
2. **Substrate library**: a separate repo (`chitra` / `rupa` / TBD
   under the AGNOS naming surface) that publishes a stable
   PNG-decode API, with kii consuming it via `cyrius.cyml [deps]`.

The decision had to be made before M2 close (v0.3.0) because the
shape of the module — including whether it exposes a struct layout
to callers — diverges between the two options. A library would want
opaque handles + reference counting; an in-repo module can use
inline struct slots referenced by byte offset (which `src/png.cyr`
does, with `STRUCT_*_OFFSET` constants the orchestrator in
`src/main.cyr` reads directly).

## Decision

**Keep the PNG decoder in-repo (`src/png.cyr`) until a second
first-party consumer surfaces.** When a second AGNOS userland tool
needs PNG decoding, extract the decoder to a Sanskrit-named
substrate lib (working name `chitra`, *image*; alt `rupa`, *form*)
under the AGNOS first-party deps pattern — the same path
`sankoch` (DEFLATE) took before being folded into the Cyrius
stdlib at v5.8.65.

Until then, the decoder is module-local code with no published
versioning contract. Callers (just `src/main.cyr` today) read the
`STRUCT_*_OFFSET` slots directly.

## Consequences

**Positive**:
- Zero dep-management overhead at v0.x scope. No `tag` pinning, no
  cross-repo lockstep cycles, no API-versioning discipline cost.
- The struct layout can grow per-milestone (M2 → M3 → M4 → M5 each
  added slots) without semver pressure. v0.6.0 has 18 slots; a
  substrate library would have had to ship a v0.2 / v0.3 / v0.4 / v0.5
  per growth.
- One-stop file for malicious-input hardening review (per
  `SECURITY.md` § PNG threats). A reviewer can audit ~600 lines
  in-repo rather than triangulate across two repos.

**Negative**:
- Duplicates effort if a second consumer ships before the extract.
  The cost is the extract itself — about a day's work to lift the
  module + rename internal helpers to public ones + write a
  consumer-facing README.
- Cannot benefit from external-library polish (fuzz harnesses, perf
  tuning) that a shared substrate would attract. Mitigated by kii's
  own fuzz harness (M2(d) onward).

**Neutral**:
- The day the extract becomes worth doing, the M5 `STRUCT_*_OFFSET`
  pattern needs to become opaque. That's a real cost but it's
  one-time, captured here for whoever does the extract.

## Alternatives considered

- **Substrate library from day one**: would have shipped slower
  (extra repo to bootstrap, extra docs, extra CI). The "one
  consumer" reality at v0.x makes the abstraction premature per the
  AGNOS first-party-standards "build for two consumers, not one"
  rule. Rejected.
- **Pull in `lodepng` / `stb_image` via a Cyrius C-FFI bridge**:
  works against the AGNOS "everything Cyrius-native" arc and would
  drag C build infrastructure into kii's CI. Rejected on
  ecosystem-purity grounds.
- **Use a hypothetical future PNG decoder in the Cyrius stdlib**:
  doesn't exist; `sankoch` (DEFLATE) is the closest analogue and
  was only stdlib-folded at v5.8.65, *after* the in-repo decision
  was already made. Not available at decision time; would have
  changed the answer if it had been.

## Trigger for revisit

- A second AGNOS first-party tool needs PNG decoding. Likely
  candidates (no commitments): `cyim` (editor — image-paste preview),
  `chakshu` (TUI viewer — image-aware file browser), a future
  thumbnail/contact-sheet generator.
- Cross-tool benchmarking shows kii's decoder is materially slower
  than `libpng` and the speed gap would benefit from being fixed
  once in a shared place.
