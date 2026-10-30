# 06 — An iTerm2 inline image (`--mode iterm`)

Demonstrates Tier 3's first protocol, new in v2.4.0
([ADR 0014](../../adr/0014-tier-3-image-protocols.md)). Instead of drawing the
picture with characters, kii sends it: one `OSC 1337 ; File=` sequence that
iTerm2, WezTerm and other terminals implementing the protocol draw as an image,
in full colour and resolution, with its transparency.

**What is sent**: a PNG kii writes from the pixels chitra decoded, never the
file's own bytes. So the terminal's image decoder only ever sees a minimal PNG
(IHDR, IDAT, IEND), whatever the input was: a JPEG with metadata, a BMP, or an
animated GIF (its first frame). That was chosen over sending the file as read
(ADR 0014 § Decision).

**The box**: `width=40;height=20` are the cells kii's geometry gives every lane
for this image at `--width 40`. With `preserveAspectRatio=1` the terminal draws
the largest undistorted image that fits them.

**Check it without such a terminal**:

```sh
sh docs/examples/06-iterm-inline-image/run.sh \
  | sed 's/^.*://; s/\x07$//' | base64 -d > /tmp/logo.png && file /tmp/logo.png
# /tmp/logo.png: PNG image data, 256 x 256, 8-bit/color RGBA, non-interlaced
```

**Elsewhere**: a terminal that does not know the protocol, the Linux console
included, draws nothing for it. kii does not detect the terminal and does not
fall back; use a cell lane (`--mode halfblock`, the default) there. Inside tmux
the sequence is dropped unless tmux passes it through.

**Refusals**: `--color`, `--dither` and `--invert` act on cells, so with
`--mode iterm` each is refused, exit 2: `kii: --color does not apply to --mode
iterm (the terminal draws the image)`.
