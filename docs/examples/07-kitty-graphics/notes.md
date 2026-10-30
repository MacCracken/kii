# 07 — The kitty graphics protocol (`--mode kitty`)

Demonstrates Tier 3's second protocol, new in v2.5.0
([ADR 0014](../../adr/0014-tier-3-image-protocols.md) § v2.5.0). The picture
goes as APC escapes, its base64 in chunks of 4,096 characters, and kitty (or any
terminal that reads the protocol) draws it.

**The keys**: `a=T` transmits and displays at once; `f=100` says the payload is
a PNG, the very one the iTerm2 lane sends (example 06); `q=2` suppresses any
reply, which would otherwise land in the shell after kii exits; `c=40` sizes
the image to 40 columns. Only one of `c` and `r` is sent: given both, kitty
stretches the image to fill them, and kii's rows are only as right as its
cell (measured since v2.7.0, else 10x20). Given one, kitty works out the other
from its real cell size.

**Checked with kitty itself**: kitty's own parser, run headless through
`kitty +runpy`, reads this frame as one 256 x 256 image whose pixels equal
ImageMagick's decode of the original, placed over exactly 40 columns, with no
reply written back.

**Elsewhere**: a terminal that does not know the protocol ignores APC
escapes, the Linux console included, and draws nothing; kii does not fall
back. `--color`, `--dither` and `--invert` are refused with this mode.
