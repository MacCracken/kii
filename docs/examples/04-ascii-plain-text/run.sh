#!/bin/sh
# kii's ASCII lane with no colour: --color none writes glyphs and newlines and
# nothing else, so the frame is plain text for a file, a log or a mail.
# Requires /usr/share/pixmaps/archlinux-logo.png (as example 02; otherwise
# substitute any image).
./build/kii --mode ascii --color none --width 60 /usr/share/pixmaps/archlinux-logo.png
