#!/bin/sh
# kii on a palette PNG (color_type=3) with a tRNS chunk. chitra resolves
# the PLTE lookup and the transparency during decode, so kii receives
# RGBA8 as it does for example 01; what differs is the input path.
# Requires /usr/share/pixmaps/archlinux-logo.png (most Arch installs
# ship this; otherwise substitute any palette PNG).
./build/kii --width 80 /usr/share/pixmaps/archlinux-logo.png
