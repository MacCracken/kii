#!/bin/sh
# kii's third image protocol: DEC Sixel, which kii encodes itself. In a Sixel
# terminal (xterm -ti vt340, foot, mlterm, WezTerm) it draws the logo 400 x 400
# device pixels: 40 columns of the default 10 x 20 cell. Give your own cell size
# with --cell-size (for example 9x19). Requires
# /usr/share/pixmaps/archlinux-logo.png (as examples 02 and 04–07; otherwise
# substitute any image).
./build/kii --mode sixel --width 40 /usr/share/pixmaps/archlinux-logo.png
