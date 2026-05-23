# Security Policy

## Threat surface

kii is an image-file → stdout-ANSI converter. It does not spawn processes, open network sockets, or write to the filesystem beyond standard output. **Image decoders are a known-malicious-input surface** — libpng, libjpeg-turbo, and friends have a long CVE history; kii's in-repo PNG decoder is held to the same defensive standard.

The realistic threats:

- **Malformed image file** — a crafted PNG / JPEG / GIF / BMP that triggers decoder bugs:
  - Out-of-bounds reads on truncated chunks
  - Integer overflow on declared image dimensions (e.g., width × height × bytes_per_pixel overflowing usize)
  - Infinite loops on circular IDAT chains
  - Zip-bomb-style decompression amplification through `sankoch`'s DEFLATE
  - CRC mismatches accepted as valid (validation gate bypass)
- **Pathologically large output** — a small input image at extreme dimensions producing an output frame that exhausts terminal memory or scrollback.
- **ANSI escape injection** — if image metadata (e.g., PNG `tEXt` chunks, or pixel data interpreted as palette indices that hit reserved bytes) emits literal ANSI escape sequences mid-frame, the output could alter terminal state in surprising ways.
- **Stdin-piping confusion** — `cat malformed.png | kii` and `kii malformed.png` must follow the same validation path; no "stdin gets a relaxed parser" shortcut.

## Mitigations in code (continuously enforced)

Status flags below: ✅ shipped, the discipline is in code today.

- ✅ **CRC validation on every PNG chunk** per PNG spec § 5.3 — shipped at v0.3.0 / M2. Failures abort decode (`PNG_ERR_CRC` → `CRC check failed` + exit 1); no partial-output emission.
- ✅ **Bounded buffers everywhere** — every `var buf[N]` is sized at compile time; no `malloc(user-controlled-size)` patterns without an upper-bound check. PLTE alloc gated at ≤ 768 bytes per spec § 11.2.3 (shipped at v0.5.0 / M4).
- ✅ **Spec-only feature set at v1.0** — Adam7 interlacing + 1/2/4-bit depths both rejected with distinct errors at v0.4.0 / M3 (`PNG_ERR_INTERLACE` / `PNG_ERR_BITDEPTH`). Apple `CgBI` chunks not yet encountered; same defer-don't-half-implement posture if they surface. Adding format-edge-case support past v1.0 requires a security-audit pass per AGNOS first-party-standards.
- ✅ **Decompression amplification cap** — at v0.4.0 / M3, the inflate destination buffer is sized exactly to `height × (1 + row_bytes)` derived from IHDR; if `zlib_decompress` returns a different size, `PNG_ERR_INFLATE` aborts. Prevents zip-bomb-style amplification.
- 🟡 **ANSI escape filter on metadata-derived strings** — no `tEXt` / `iTXt` / `zTXt` decoding in scope at v1.0, so no current emit path. Discipline reserved for post-v1: any future ancillary-chunk text that gets echoed must be sanitized of `\x1b` sequences before stdout-emit.
- ✅ **Fuzz harness** at `tests/kii.fcyr` — two surfaces shipped (arg-parser + PNG decoder); 12k iters/run on every CI run via the ci.yml Fuzz step. M7 audit raises iter counts to 10⁶ per the v1.0 acceptance criterion in [`docs/development/roadmap.md`](docs/development/roadmap.md).

## What kii does NOT do

For threat-modeling clarity, kii has no:

- Network access
- Filesystem writes (output is stdout only)
- Process spawning (`sys_system`, `exec_*`, etc.)
- Persistent state (no config files, no cache)
- Plugin / external-renderer loading
- TLS / crypto / hashing (no `sigil` dep)

This minimal-surface posture is durable per [`CLAUDE.md` § Domain-specific rules](CLAUDE.md). Expansions need explicit justification and a re-audit.

## Reporting Vulnerabilities

Report vulnerabilities privately to **security@agnos.dev**. Do not open public GitHub issues for security bugs.

We will:
- Acknowledge receipt within 48 hours
- Provide a fix timeline within one week
- Coordinate disclosure (default: 90 days from acknowledgment, or whenever a fix lands and propagates — whichever is sooner)

Image-format-specific CVEs (e.g., a known libpng vulnerability) — please cite the CVE ID. If kii inherits the vulnerability via the spec being implemented faithfully, the fix may involve hardening kii's parser beyond spec.

## Audit history

See `docs/audit/YYYY-MM-DD-audit.md` files (when present). First audit will land at the M7 (v1.0 freeze) cycle.
