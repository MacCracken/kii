# 03 — Non-PNG input rejected with diagnostic

Demonstrates kii's error path: explicit stderr diagnostic + exit
code 1 on rejection. No partial output reaches stdout — the
[pipe-purity invariant](../../architecture/README.md) means a
failed `kii img.png > frame.ansi` doesn't leave a half-rendered
`frame.ansi` behind.

**Why this example**: covers the rejection contract at v1.0. Every
documented error message in
[`docs/guides/getting-started.md`](../../guides/getting-started.md)
§ When kii rejects an image follows this shape — `<path>: <message>`
on stderr, exit 1, no stdout.

The `unrecognized image format` rejection fires at the signature
sniff. `kii_decode_image` (`src/image.cyr`) reads the whole file first
(one open, capped at 256 MB), then `chitra_image_decode` finds none
of the four signatures and returns `CHITRA_ERR_SIGNATURE`, which kii
maps to `IMG_ERR_UNRECOGNIZED`. It is the earliest decode rejection: no
image buffer has been allocated yet. (Corrected at v1.6.4: this cited
a `png_check_signature` at `src/png.cyr:319` that the v1.2.0 re-fold
deleted, and said kii had not read past the first 8 bytes. kii has
read the whole file at that point since v1.2.0.)

**Cross-check** — try other rejection paths:

```sh
# Nonexistent file → "cannot open file"
./build/kii /nonexistent/path.png

# Truncated PNG (< 8 bytes) → "unrecognized image format (expected PNG, JPEG, BMP, or GIF)"
# (the dedicated "file shorter than 8 bytes" message is gone since v1.2.0)
head -c 4 tests/fixtures/RAMGON.png > /tmp/truncated.png
./build/kii /tmp/truncated.png

# A directory → "is a directory, not an image file" (since v1.6.4)
./build/kii /tmp

# Filename with control bytes → "<path containing control bytes — suppressed>"
# (hardening commitment C1 in ADR 0002, the path-echo sanitizer; ESC is a
# C0 control, which the sanitizer has refused since v0.8.0)
touch "/tmp/$(printf '\x1bbad').png"
./build/kii "/tmp/$(printf '\x1bbad').png"
```
