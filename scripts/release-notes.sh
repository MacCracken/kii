#!/usr/bin/env bash
# release-notes.sh — print one version's section of CHANGELOG.md: the lines after
# its `## [X.Y.Z]` heading, up to the next `## [` heading.
#
#   ./scripts/release-notes.sh 2.0.1            # the notes release.yml publishes
#   ./scripts/release-notes.sh "$(cat VERSION)"  # what CI checks exists
#
# Exits 1 if the CHANGELOG has no section for the version, or an empty one, so a
# release cannot publish without notes and CI catches a VERSION bump that the
# CHANGELOG never got. The heading is matched as a fixed string, so `2.0.1` does
# not match `[2.0.10]` and the dots are not regex wildcards.
#
# The CHANGELOG's links are relative to the repository root (`docs/adr/…`), and a
# release page would resolve them against itself. They are printed as links into
# the tagged tree instead: `[repository]` in cyrius.cyml, then `/blob/X.Y.Z/`.

set -euo pipefail

[ $# = 1 ] || { echo "usage: release-notes.sh X.Y.Z" >&2; exit 2; }
REPO="$(cd "$(dirname "$0")/.." && pwd)"
URL="$(sed -n 's/^repository = "\(.*\)"$/\1/p' "$REPO/cyrius.cyml" | head -1)"
[ -n "$URL" ] || { echo "release-notes: no repository = \"…\" in cyrius.cyml" >&2; exit 2; }

notes="$(awk -v head="## [$1]" '
    index($0, head) == 1 { found = 1; next }
    found && /^## \[/ { exit }
    found { print }
' "$REPO/CHANGELOG.md")"

# The section's own blank lines stay; the ones around it go.
notes="$(printf '%s\n' "$notes" | sed -e '/./,$!d')"
if [ -z "${notes//[[:space:]]/}" ]; then
    echo "release-notes: CHANGELOG.md has no notes under ## [$1]" >&2
    exit 1
fi
# A link target with no `:` (so not `https:` or `mailto:`) that does not start
# with `#` is a path in the repository.
printf '%s\n' "$notes" | sed -E "s#\]\(([^):\#][^):]*)\)#](${URL}/blob/$1/\1)#g"
