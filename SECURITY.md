# Security Policy

## Threat surface

kii is an image-file → stdout-ANSI converter. It does not spawn processes, open network sockets, or write to the filesystem beyond standard output. **Image decoders are a known-malicious-input surface** — libpng, libjpeg-turbo, and friends have a long CVE history. kii has carried no decoder of its own since v1.2.0: PNG, JPEG, BMP and GIF decode in the [`chitra`](https://github.com/MacCracken/chitra) substrate, which is held to that defensive standard, and kii rejects what chitra rejects ([ADR 0006](docs/adr/0006-adopt-chitra-decoder.md)).

The realistic threats:

- **Malformed image file** — a crafted PNG / JPEG / GIF / BMP that triggers decoder bugs:
  - Out-of-bounds reads on truncated chunks
  - Integer overflow on declared image dimensions (e.g., width × height × bytes_per_pixel overflowing usize)
  - Infinite loops on circular IDAT chains
  - Zip-bomb-style decompression amplification through `sankoch`'s DEFLATE
  - CRC mismatches accepted as valid (validation gate bypass)
- **Pathologically large output** — a small input image at extreme dimensions producing an output frame that exhausts terminal memory or scrollback.
- **ANSI escape injection** — if image metadata (e.g., PNG `tEXt` chunks, or pixel data interpreted as palette indices that hit reserved bytes) emits literal ANSI escape sequences mid-frame, the output could alter terminal state in surprising ways.
- **Stdin-piping confusion** — `cat malformed.png | kii /dev/stdin` and `kii malformed.png` must follow the same validation path; no "stdin gets a relaxed parser" shortcut. Since v1.6.4 they do by construction: kii reads every input with one open, to EOF, under the same 256 MB cap, so a pipe, `/dev/stdin` or `<(…)` reaches chitra exactly as a file does. (Before v1.6.4 a pipe failed with `cannot open file`.)

## Mitigations in code (continuously enforced)

Status flags below: ✅ shipped, the discipline is in code today.

- ✅ **CRC validation on every PNG chunk** per PNG spec § 5.3 — shipped at v0.3.0 / M2, and owned by the `chitra` substrate since the v1.2.0 re-fold. Failures abort decode (`IMG_ERR_CRC` → `CRC check failed` + exit 1); no partial-output emission. JPEG, BMP and GIF carry no chunk CRC, so their bar is structural validation (marker/segment bounds, DIB header, LZW chain) under the same DoS caps — see [ADR 0008](docs/adr/0008-jpeg-via-chitra.md) and [ADR 0009](docs/adr/0009-bmp-gif-via-chitra.md).
- ✅ **Bounded buffers everywhere** — no `alloc(user-controlled-size)` without an upper-bound check. Per-row emit scratch is heap-allocated and sized from the actual width (a fixed 2048-byte stack buffer overflowed past ~89 columns; fixed at v1.2.1). `--width` is capped at `KII_MAX_COLS` and `downscale_to_rgb` refuses a `dst_w * dst_h * 3` product that would overflow — **added at the v1.5.1 P-1 sweep**, which found that an unbounded `--width` wrapped that product to a 12-byte allocation the resampler then wrote past (a reproducible SIGSEGV and heap corruption on both render lanes). **Since v1.6.4** the input is read by the stdlib's `file_read_whole_max` with one open, stopping at `KII_MAX_RAW_BYTES` (256 MB, chitra's own `CHITRA_MAX_RAW_BYTES`); it replaced a size probe followed by a second open, which also let the path change between the check and the read.
- ✅ **Frame-size cap** (since v1.6.4) — the mitigation for pathologically large output. `--width` bounds the columns, but the row count follows the image's aspect, so a 392-byte 1×65535 GIF at `--width 80` asked for 2.6 million rows and about 4.4 GB of ANSI. kii now refuses any frame over `KII_MAX_CELLS` (1,048,576 character cells, `src/cli.cyr` `kii_frame_cells_ok`) before it downscales: `<path>: frame too large (over 1048576 cells); use a smaller --width`, exit 1. That bounds the worst case at roughly 26 MB of output at the default tier (43 MB at `--color tc`, whose cells can take 41 bytes).
- ✅ **Defer-don't-half-implement on format edge cases** — what is *refused* is refused with a distinct error rather than guessed at. As of v1.5.x that list is: progressive / arithmetic / 12-bit / non-baseline / CMYK JPEG (`IMG_ERR_UNSUPPORTED`), BMP bit depths outside `{1,4,8,16,24,32}` plus `BI_JPEG` / `BI_PNG` compression, and unrecognized PNG critical chunks or compression/filter methods. **Corrected at the v1.5.1 P-1 sweep**: this bullet used to say "Adam7 interlacing + 1/2/4-bit depths both rejected with distinct errors", which stopped being true at **v1.2.2** — chitra decodes Adam7 and every sub-byte depth, and `tests/decode.tcyr` asserts `PNG_OK` for exactly those inputs. Apple `CgBI` chunks are still not handled. Adding format-edge-case support requires a security-audit pass per AGNOS first-party-standards.
- ✅ **Decompression amplification cap** — at v0.4.0 / M3, the inflate destination buffer is sized exactly to `height × (1 + row_bytes)` derived from IHDR; if `zlib_decompress` returns a different size, decode aborts (`IMG_ERR_DECOMPRESS` since v1.7.0's rename). Prevents zip-bomb-style amplification. A valid PNG whose pixel data would inflate past sankoch's 16 MiB `DECOMPRESS_MAX_OUTPUT` is refused by chitra before anything is allocated and, since v1.6.0, reported as such (`IMG_ERR_INFLATE_LIMIT`, "image too large to decode") rather than as a malformed file.
- ✅ **ANSI-injection sanitizer on every echoed path** — `kii_path_has_control_bytes` (`src/cli.cyr`) gates every filename kii writes to stderr; a path carrying control bytes is replaced with a fixed placeholder rather than echoed. It rejects C0 (except the allow-listed TAB/LF), DEL, **and — since the v1.5.1 P-1 sweep — the C1 range `0x80–0x9F` in both encodings**: raw 8-bit (where `0x9B` IS CSI and `0x9D` IS OSC) and the UTF-8 spelling `C2 80`–`C2 9F`. Before that fix a filename built only from C1 bytes defeated the guard entirely and a complete OSC window-title injection reached stderr byte-for-byte. The check walks UTF-8 structure rather than testing a flat byte range, so ordinary non-Latin filenames still echo normally. **Since v1.6.0** the predicate is darshana's `tty_has_ctl` (UTF-8 mode, TAB + LF kept), which applies the same rule with **strict RFC 3629** validation: overlong 3- and 4-byte forms, UTF-16 surrogates and code points past U+10FFFF are refused too. kii's own walk had accepted them, and the overlong forms are not academic — `E0 82 9B` is an overlong spelling of U+009B (CSI) that a lenient terminal decoder turns back into the control.
- 🟡 **Metadata-derived strings** — no `tEXt` / `iTXt` / `zTXt` decoding in scope, so there is no current emit path for image-supplied text. If ancillary-chunk text is ever echoed it must go through the same sanitizer.
- ✅ **Fuzz harness** at `tests/kii.fcyr` — **ten surfaces, 8,011,000 iterations/run**: arg-parser, path-sanitizer, geometry, emit-pipeline, one per input format (PNG / JPEG / BMP / GIF), each prefixing that format's real signature so the random payload actually reaches its decoder, and (v1.6.0) a path-sanitizer **differential** against the v1.5.2 walk plus the terminal-envelope geometry. Since v1.6.0 a contract violation on any surface fails the run (`fuzz: FAIL`, exit 1); before, the harness reported the count and still exited 0. The v1.5.1 P-1 sweep found the PNG surface had been **silently voided**: the per-iteration `alloc_reset()` that bounds the never-free heap also invalidated sankoch's cached CRC-32 table, so 2999 of every 3000 iterations died at the signature check instead of reaching the chunk walker. Clearing the cache alongside the reset restored full coverage.

### Accepted risks

- **TAB and LF are echoed in paths** (the coreutils-`ls` convention, pinned by test). A filename containing a newline can split a kii diagnostic and forge what looks like a second message. The forged text still cannot carry control bytes.
- **Unicode bidi and format characters are echoed in paths**: U+202A–202E, U+2066–2069, U+200E/F, U+061C, U+2028 and U+FEFF. They are valid UTF-8, not control bytes, so the sanitizer passes them. On a terminal that renders bidi text, an RLO (U+202E) in a filename can reorder how the rest of that diagnostic line is displayed. This is weaker than the TAB/LF risk above: it changes how one line looks, but cannot add a line.
- **A FIFO with no writer blocks in `open()`**, as `cat` does.

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

Audits live in [`docs/audit/`](docs/audit/):

- [`2026-05-22-audit.md`](docs/audit/2026-05-22-audit.md) — the M7 security audit before the v1.0 freeze (v0.8.0).
- [`2026-08-25-audit.md`](docs/audit/2026-08-25-audit.md) — the v1.5.1 P-1 sweep.
- [`2026-10-15-audit.md`](docs/audit/2026-10-15-audit.md) — the v1.6.4 P(-1) sweep, including the check that the three zlib CVE classes (CVE-2004-0797, CVE-2005-1849, CVE-2005-2096) hold against the linked sankoch.
