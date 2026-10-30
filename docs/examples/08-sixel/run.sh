#!/bin/sh
# kii's third image protocol: DEC Sixel, which kii encodes itself. In a Sixel
# terminal (xterm -ti vt340, foot, mlterm, WezTerm) it draws the logo 40 columns
# wide in the terminal's own cell, measured from its window size (v2.7.0): 400 x 400
# device pixels at a 10 x 20 cell. --cell-size (for example 9x19) overrides the
# measurement. Requires
# /usr/share/pixmaps/archlinux-logo.png (as examples 02 and 04–07; otherwise
# substitute any image).
./build/kii --mode sixel --width 40 /usr/share/pixmaps/archlinux-logo.png
