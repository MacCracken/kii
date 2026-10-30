#!/bin/sh
# kii's second image protocol: the picture by the kitty graphics protocol. In
# kitty it draws the logo 40 columns wide, the rows from kitty's own cell size;
# elsewhere it draws nothing. Requires /usr/share/pixmaps/archlinux-logo.png
# (as examples 02, 04, 05 and 06; otherwise substitute any image).
./build/kii --mode kitty --width 40 /usr/share/pixmaps/archlinux-logo.png
