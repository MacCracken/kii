#!/bin/sh
# kii on a palette PNG (color_type=3) — exercises the PLTE-lookup
# code path in src/downscale.cyr::_extract_rgb. Different from the
# RGBA path in example 01.
# Requires /usr/share/pixmaps/archlinux-logo.png (most Arch installs
# ship this; otherwise substitute any palette PNG).
./build/kii --width 80 /usr/share/pixmaps/archlinux-logo.png
