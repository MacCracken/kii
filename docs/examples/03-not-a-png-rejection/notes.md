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

The `not a PNG` rejection specifically fires at the signature check
in `src/png.cyr:319` (`png_check_signature`). It's the earliest
rejection path and the cheapest — kii hasn't allocated anything or
read past the first 8 bytes.

**Cross-check** — try other rejection paths:

```sh
# Nonexistent file → "cannot open file"
./build/kii /nonexistent/path.png

# Truncated PNG (< 8 bytes) → "not a PNG (file shorter than 8 bytes)"
head -c 4 tests/fixtures/RAMGON.png > /tmp/truncated.png
./build/kii /tmp/truncated.png

# Filename with control bytes → "<path containing control bytes — suppressed>"
# (the M7(c) C1 ANSI-injection defense; see ADR 0002)
touch "/tmp/$(printf '\x1bbad').png"
./build/kii "/tmp/$(printf '\x1bbad').png"
```
