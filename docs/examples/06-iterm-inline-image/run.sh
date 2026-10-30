#!/bin/sh
# kii's first image protocol: the picture itself, as one iTerm2 inline image.
# In iTerm2 or WezTerm it draws the logo in full colour, in a 40 x 20 cell box;
# elsewhere it draws nothing. Requires /usr/share/pixmaps/archlinux-logo.png (as
# examples 02, 04 and 05; otherwise substitute any image).
./build/kii --mode iterm --width 40 /usr/share/pixmaps/archlinux-logo.png
