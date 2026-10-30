#!/usr/bin/env bash
# check-builds-agree.sh — two kii binaries must answer every case alike: the same
# stdout, the same stderr, the same exit code, byte for byte.
#
#   ./scripts/check-builds-agree.sh build/kii build/kii-dce
#   ./scripts/check-builds-agree.sh build/kii build/kii-aarch64 qemu-aarch64
#
# CI runs it twice. Plain against CYRIUS_DCE=1: the release ships the DCE build,
# so it must be the program the tests describe. x86_64 against aarch64 (the
# trailing arguments run the second binary, here under qemu-user): the frames do
# not depend on the architecture.
#
# The cases are the fixtures under tests/fixtures in every lane, tier and dither,
# the ASCII lane's --invert and --color none (2.2.0), the Braille lane
# (2.3.0) and the iTerm2 and kitty protocols (2.4.0, 2.5.0), plus the CLI's own paths: help,
# version, each kind of refusal. Every case names
# its width or fails before rendering, so neither binary reads the terminal size.
# 2.0.1 measured the same comparison over a 472-image corpus (CHANGELOG [2.0.1]);
# this is the subset CI can carry.

set -uo pipefail

[ $# -ge 2 ] || { echo "usage: check-builds-agree.sh A B [RUNNER...]" >&2; exit 2; }
A="$1"; B="$2"; shift 2
REPO="$(cd "$(dirname "$0")/.." && pwd)"
F="$REPO/tests/fixtures"

IMAGES=("$F/RAMGON.png" "$F/color.gif" "$F/color.jpg" "$F/gradient.bmp" "$F/gradient.jpg"
        "$F/oversize.png" "$F/visual-review/basn2c08.png" "$F/visual-review/basn3p08.png"
        "$F/visual-review/basn6a08.png")
LANES=("--width 40" "--width 80 --color 8" "--width 60 --color 256 --dither ordered"
       "--width 50 --color tc" "--width 40 --dither fs"
       "--mode ascii --width 30" "--mode ascii --width 70 --color 256 --dither fs"
       "--mode blocks --width 40" "--mode blocks --width 30 --color 8 --dither ordered"
       "--mode blocks --width 60 --color tc" "--mode blocks --width 50 --color 256 --dither fs"
       "--width 1" "--mode blocks --width 2" "--mode ascii --width 1"
       "--mode ascii --width 40 --invert" "--mode ascii --width 60 --color none"
       "--mode ascii --width 30 --invert --color none --dither fs --verbose"
       "--mode braille --width 40" "--mode braille --width 30 --color 8 --dither ordered"
       "--mode braille --width 60 --color tc --dither fs --invert"
       "--mode braille --width 50 --color none --verbose" "--mode braille --width 1"
       "--mode iterm --width 40" "--mode kitty --width 40")
CLI=("" "--help" "-h" "--version" "--bogus" "--width" "--width 0" "--width -3" "--width 99999"
     "--width abc" "--mode" "--mode block" "--color 7" "--dither x" "--width 40 $F"
     "--width 40 /nonexistent.png" "--width 40 /dev/null" "--width 40 $F/RAMGON.png $F/color.gif"
     "--width 40 --invert $F/RAMGON.png" "--mode blocks --color none --width 40 $F/RAMGON.png"
     "--color mono" "--invert=1" "--mode Braille"
     "--mode iterm --width 10 --verbose $F/color.gif" "--mode iterm --color 16 $F/color.gif"
     "--mode iterm --dither none --width 10 $F/color.gif"
     "--mode kitty --width 10 --verbose $F/color.gif" "--mode kitty --invert $F/color.gif")

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
ok=0; bad=0

check() {
    "$A" "$@" > "$tmp/ao" 2> "$tmp/ae" < /dev/null; local ac=$?
    "${RUN[@]}" "$B" "$@" > "$tmp/bo" 2> "$tmp/be" < /dev/null; local bc=$?
    if [ "$ac" = "$bc" ] && cmp -s "$tmp/ao" "$tmp/bo" && cmp -s "$tmp/ae" "$tmp/be"; then
        ok=$((ok + 1))
    else
        bad=$((bad + 1)); echo "differ (exit $ac/$bc): kii $*"
    fi
}

RUN=("$@")
for img in "${IMAGES[@]}"; do
    [ -r "$img" ] || { echo "check-builds-agree: missing fixture $img" >&2; exit 2; }
    for lane in "${LANES[@]}"; do
        # shellcheck disable=SC2086  # each lane is a list of words
        check $lane "$img"
    done
done
for c in "${CLI[@]}"; do
    # shellcheck disable=SC2086
    check $c
done

echo "check-builds-agree: $ok cases agree, $bad differ ($(basename "$A") vs $(basename "$B"))"
[ "$bad" = 0 ]
