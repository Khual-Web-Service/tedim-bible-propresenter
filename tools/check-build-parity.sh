#!/bin/sh
# Check that both build paths produce the same book names.
#
# tools/install-macos.sh (shell, for the Mac it runs on) and
# tools/build_rvbible.py (Python, for CI and manual builds) package the same
# bundles, and both rewrite the transplanted metadata's <names> section through
# tools/localize-book-names.sh. This builds each bible both ways and diffs that
# section — any difference means the two paths have drifted apart.
#
# With no template it checks both synthetic templates from
# tools/make-test-template.sh — the 2.2.1 header shape ProPresenter ships today
# (version= first, revision="11") and the older 2.1 shape (id= first) — so the
# check runs anywhere, CI included. Pass a template to check against a real one:
# any .rvbible ProPresenter installed itself.
#
# Usage:
#   tools/check-build-parity.sh [template.rvbible] [CODE ...]   # default: TDB BJB

set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

work="$(mktemp -d "${TMPDIR:-/tmp}/parity.XXXXXX")"
trap 'rm -rf "$work"' EXIT

templates=""
case "${1:-}" in
    "") ;;
    -*) echo "usage: check-build-parity.sh [template.rvbible] [CODE ...]" >&2; exit 2 ;;
    *.rvbible) templates="$1"; shift ;;
esac

if [ -z "$templates" ]; then
    for shape in 2.1 2.2.1; do
        templates="$templates $("$repo_root/tools/make-test-template.sh" \
            "$work/template-$shape.rvbible" "$shape")"
    done
fi

[ $# -gt 0 ] || set -- TDB BJB

names_section() {
    unzip -p "$1" metadata.xml | awk '/<names>/ { inside = 1 } inside { print } /<\/names>/ { inside = 0 }'
}

status=0
for template in $templates; do
    echo "Template: $(basename "$template")"
    out="$work/$(basename "$template" .rvbible)"

    # The shell path builds into dist/ and installs as a side effect, so point
    # both at scratch folders — dist/ holds verified packages.
    mkdir -p "$out/dest"
    (cd "$repo_root" && RVBIBLE_TEMPLATE="$template" RVBIBLE_DIST="$out/sh" DRY_RUN= \
        "$repo_root/tools/install-macos.sh" "$out/dest" >/dev/null)

    python3 "$repo_root/tools/build_rvbible.py" --template "$template" \
        --out "$out/py" >/dev/null

    for code in "$@"; do
        names_section "$out/sh/$code.rvbible" >"$out/$code.sh.names"
        names_section "$out/py/$code.rvbible" >"$out/$code.py.names"
        if [ ! -s "$out/$code.sh.names" ]; then
            echo "  $code: no <names> section — nothing was compared" >&2
            status=1
        elif diff -u "$out/$code.sh.names" "$out/$code.py.names" >"$out/$code.diff"; then
            echo "  $code: identical ($(grep -c '<name id=' "$out/$code.sh.names") entries)"
        else
            echo "  $code: the two build paths disagree" >&2
            cat "$out/$code.diff" >&2
            status=1
        fi
    done
done

exit "$status"
