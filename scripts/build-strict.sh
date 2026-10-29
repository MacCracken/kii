#!/usr/bin/env bash
# build-strict.sh — `cyrius build` that fails on a compiler warning.
#
#   ./scripts/build-strict.sh src/main.cyr build/kii
#   CYRIUS_DCE=1 ./scripts/build-strict.sh --agnos src/main.cyr build/kii-agnos
#
# The arguments go to `cyrius build` unchanged, and so does the environment
# (CYRIUS_DCE). cyrius exits 0 when it only warns, and one warning is a broken
# binary: a call to a function that was never defined is a warning, not an
# error, when DCE proves the call unreachable. agnodrm 1.5.2 shipped an --agnos
# build that way, its getenv() jumping to a symbol no module defined. kii builds
# with no warnings on every target, so CI fails on the first one. Every warning
# cyrius prints begins `warning:`.

set -uo pipefail

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
cyrius build "$@" > "$log" 2>&1
rc=$?
cat "$log"
[ "$rc" = 0 ] || exit "$rc"
if grep -q 'warning:' "$log"; then
    echo "build-strict: cyrius warned (cyrius build $*)" >&2
    exit 1
fi
