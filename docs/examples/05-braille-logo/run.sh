#!/bin/sh
# kii's Braille lane: 2 x 4 dots a cell, one colour, the finest shape kii draws.
# --color none keeps the frame to plain text so it reads here; drop it for the
# logo's blue. Requires /usr/share/pixmaps/archlinux-logo.png (as examples 02
# and 04; otherwise substitute any logo or line drawing).
./build/kii --mode braille --color none --width 30 /usr/share/pixmaps/archlinux-logo.png
