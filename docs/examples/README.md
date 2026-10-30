# kii — Examples

Runnable examples demonstrating kii's behavior on real inputs. Each
example is a directory with:

- `run.sh` — exactly one shell command (the invocation)
- `expected.txt` — what to look for in the output (first bytes, or a
  diagnostic line, or an exit-code assertion)
- `notes.md` — what the example demonstrates and why it's
  representative

Every example is run from the kii repo root (`cd kii && ./build/kii ...`).
All five were last run against their `expected.txt` at v2.3.0. Byte-exact
reproduction across minor cuts is part of the [v1.0 stable-emit contract](../adr/0003-color-tier-discipline.md);
when a release changes emitted bytes on purpose, as v1.6.4 did for
transparent pixels, v1.8.0 for the emit encoding, v1.9.0 for sampling and
v2.1.0 for the half-block glyph choice,
the CHANGELOG lists it and the affected example says so.

## Index

| Dir | Demonstrates |
|---|---|
| [`01-ramgon-fixed-width/`](01-ramgon-fixed-width/) | Happy path — RAMGON.png → 80-column ANSI frame |
| [`02-archlinux-logo-palette/`](02-archlinux-logo-palette/) | Palette PNG (color_type=3) — different code path, same output shape |
| [`03-not-a-png-rejection/`](03-not-a-png-rejection/) | Error path — non-PNG input rejected with diagnostic on stderr |
| [`04-ascii-plain-text/`](04-ascii-plain-text/) | `--mode ascii --color none` (v2.2.0) — plain-text art, no escapes |
| [`05-braille-logo/`](05-braille-logo/) | `--mode braille` (v2.3.0) — a logo whose blue a fixed threshold would erase |

## Adding an example

1. Pick a representative input — either a fixture in
   `tests/fixtures/` or a system PNG kii is known to decode.
2. Capture the invocation in `run.sh`; capture the relevant output
   in `expected.txt` (a few representative bytes, not the full
   frame).
3. Document the demonstrated behavior in `notes.md` — what aspect
   of kii's surface this exercises that the prior examples don't.
4. Append to the index above; bump the row count.

Examples are part of the user-facing surface. Adding code paths
that change emit bytes invalidates captured outputs; bump each
affected example's `expected.txt` in the same change.
