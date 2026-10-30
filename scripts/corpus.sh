#!/usr/bin/env bash
# corpus.sh — print the image corpus kii's releases are measured over, one path a
# line, in a fixed order.
#
#   ./scripts/corpus.sh > corpus.txt
#
# Every PNG, JPEG, GIF and BMP under /usr/share outside the icon themes, then
# every one under tests/fixtures. The icon themes are left out because they are
# thousands of near-identical small PNGs. The list depends on what the host has
# installed, so a release's CHANGELOG states its count. Through 2.5.0 the corpus
# was a 472-image list whose recipe was not kept; from 2.6.0 it is this one.

set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
img() { find "$1" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \
        -o -iname '*.gif' -o -iname '*.bmp' \) "${@:2}" 2>/dev/null | LC_ALL=C sort; }

img /usr/share -not -path '/usr/share/icons/*'
img "$REPO/tests/fixtures"
