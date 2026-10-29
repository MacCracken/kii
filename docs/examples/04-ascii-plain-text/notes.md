# 04 — Plain-text ASCII art (`--color none`)

Demonstrates the colourless form of the ASCII lane, new in v2.2.0
([ADR 0007](../../adr/0007-rendering-mode-taxonomy.md) and
[ADR 0010](../../adr/0010-tier-2-colour-and-emit-encoding.md), § v2.2.0
amendments). `--color none` sends no SGR at all: each row is its glyphs and a
newline, with no colour escapes and no closing reset. The output is the
classic `jp2a` kind, safe to keep in a text file, a log or a mail.

**Why this example**: the other three show coloured frames or a refusal. This
one shows the one form whose bytes are all printable. It is also the coloured
ASCII frame with its escapes removed, glyph for glyph, since a cell's glyph
never depends on its colour:

```sh
./build/kii --mode ascii --width 60 /usr/share/pixmaps/archlinux-logo.png \
  | sed 's/\x1b\[[0-9;]*m//g' | cmp - <(sh docs/examples/04-ascii-plain-text/run.sh)
# no output: identical
```

**On a light terminal**, add `--invert` (`-i`): dark becomes ink rather than
light. The glyphs are then exactly those of the image's negative, in the
image's own colours when colour is on. This logo is a mid blue on
transparency, so it reads as ink either way: 10 of its 1,800 cells change,
along the edges. A photograph changes far more.

**Refused elsewhere**: `--color none` and `--invert` belong to `--mode ascii`.
With the half-block or blocks lane kii prints
`kii: --color none applies to --mode ascii only` (or the `--invert` line),
then the help, and exits 2.
