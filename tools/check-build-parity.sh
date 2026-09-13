#!/bin/sh
# Check that both build paths produce the same book names.
#
# tools/install-macos.sh (shell, for the Mac it runs on) and
# tools/build_rvbible.py (Python, for CI and manual builds) package the same
# bundles, and both rewrite the transplanted metadata's <names> section through
# tools/localize-book-names.sh. This builds each bible both ways and diffs that
# section — any difference means the two paths have drifted apart.
#
# Needs a template: any .rvbible ProPresenter installed itself.
#
# Usage:
#   tools/check-build-parity.sh <template.rvbible> [CODE ...]   # default: TDB BJB

set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

if [ $# -lt 1 ]; then
    echo "usage: check-build-parity.sh <template.rvbible> [CODE ...]" >&2
    exit 2
fi

template="$1"
shift
[ $# -gt 0 ] || set -- TDB BJB

work="$(mktemp -d "${TMPDIR:-/tmp}/parity.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# The shell path installs as a side effect, so point it at a scratch folder.
mkdir -p "$work/dest"
(cd "$repo_root" && DRY_RUN= "$repo_root/tools/install-macos.sh" "$work/dest" >/dev/null)
mkdir -p "$work/sh"
for code in "$@"; do
    cp "$repo_root/dist/$code.rvbible" "$work/sh/$code.rvbible"
done

python3 "$repo_root/tools/build_rvbible.py" --template "$template" --out "$work/py" >/dev/null

names_section() {
    unzip -p "$1" metadata.xml | awk '/<names>/ { inside = 1 } inside { print } /<\/names>/ { inside = 0 }'
}

status=0
for code in "$@"; do
    names_section "$work/sh/$code.rvbible" >"$work/$code.sh.names"
    names_section "$work/py/$code.rvbible" >"$work/$code.py.names"
    if [ ! -s "$work/$code.sh.names" ]; then
        echo "$code: no <names> section — nothing was compared" >&2
        status=1
    elif diff -u "$work/$code.sh.names" "$work/$code.py.names" >"$work/$code.diff"; then
        echo "$code: identical ($(grep -c '<name id=' "$work/$code.sh.names") entries)"
    else
        echo "$code: the two build paths disagree" >&2
        cat "$work/$code.diff" >&2
        status=1
    fi
done

exit "$status"
