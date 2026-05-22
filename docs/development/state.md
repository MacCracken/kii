# kii — Current State

> Refreshed every release. [`CLAUDE.md`](../../CLAUDE.md) is preferences /
> process / procedures (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-05-22 via `cyrius init kii`. No public release yet.

## Toolchain

- **Cyrius pin**: `6.0.1` (in `cyrius.cyml [package].cyrius`)

## Surface

Pre-alpha scaffold. Compiles + prints version banner. No image-decode or ANSI-emit functionality yet.

- `src/main.cyr` — entry point; prints scaffold banner.
- `src/test.cyr` — test entry; routes to `tests/kii.tcyr`.
- `tests/kii.tcyr` — primary test suite (smoke + math).
- `tests/kii.bcyr` — benchmark stub (no-op).
- `tests/kii.fcyr` — fuzz stub.

## Binary size

Build: TBD on first non-scaffold cut. Scaffold-only binary ~37 KB (mostly stdlib bring-up).

## Tests

- `cyrius test` — 2 assertions (smoke + math), pass.

## Dependencies

Direct (declared in `cyrius.cyml [deps]`):

- **stdlib**: `string`, `fmt`, `alloc`, `io`, `vec`, `str`, `syscalls`, `assert`, `bench`, `args`
- **External**: none yet. Pending dep gates per [`roadmap.md`](roadmap.md):
  - `sankoch` — added at v0.4.0 (PNG IDAT DEFLATE decompression)
  - `darshana` — added at v0.6.0 (ANSI emit primitives)

## Consumers (planned, not yet integrated)

- **BBS server** (TBD, agnosticos planned-repo) — MOTD / login banner ANSI art
- **MUD server** (TBD, agnosticos planned-repo) — room-description illustration art
- **End-user shells** — image preview / demo flair
- **`iam`** — possibly, for richer login splash art (TBD per `iam` minimalism principle)

No consumers yet — pre-MVP.

## Cycle context

Scaffolded during agnos kernel cycle **1.32.x networking-arc**. Strategic relevance: BBS/MUD apps that will consume kii are out-of-cycle parallel deliverables for that cycle (they exercise the same kernel `tcp_listen`/`tcp_accept` surface the cycle landed; kii feeds their MOTD aesthetic).

agnos 1.32.x cycle status at time of kii v0.1.0 scaffold:
- Bites A (TCP server) + F (UDP server) + G (DHCP client) + B Phases 1-4 (r8169 driver) all landed and code-complete.
- Iron Attempt 92+ PENDING IRON BURN — first real-LAN validation of the bundle.
- kii itself has no kernel-side dependency — it's a userland image→ANSI tool that runs in a normal shell.

## Next

See [`roadmap.md`](roadmap.md) for the milestone path to v1.0.
