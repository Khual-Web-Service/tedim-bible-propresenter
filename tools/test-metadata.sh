#!/bin/sh
# Check how both build paths handle the template's DBL metadata.
#
# ProPresenter has shipped more than one DBL 2.x header shape — 2.1 wrote id=
# first, the 2.2.1 packages it downloads today write version= first — and a
# check that depended on either the exact version string or the attribute order
# left the installer rejecting every freshly downloaded template. So this runs
# the synthetic templates from tools/make-test-template.sh through both build
# paths, in both shapes, and asserts that:
#
#   * a DBL 2.x template is accepted whatever its attribute order,
#   * a DBL 1.2 template is still rejected,
#   * the bundle id on <DBLMetadata …> is replaced wherever it sits in the tag,
#   * no other id in the document is touched,
#   * the publication <content> map survives,
#   * the book names are localized in every <names> entry shape.
#
# Usage:
#   tools/test-metadata.sh [CODE]      # default: TDB

set -eu

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
code="${1:-TDB}"

work="$(mktemp -d "${TMPDIR:-/tmp}/rvtest.XXXXXX")"
trap 'rm -rf "$work"' EXIT

failures=0
pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1" >&2; failures=$((failures + 1)); }
check() { if [ "$2" = "yes" ]; then pass "$1"; else fail "$1"; fi; }

dbl_header() {
    awk '
        { buf = buf $0 "\n" }
        END {
            if (match(buf, /<DBLMetadata[^>]*>/)) {
                tag = substr(buf, RSTART, RLENGTH)
                gsub(/[\n\t]+/, " ", tag)
                print tag
            }
        }
    '
}

# The template's own bundle id, which a built package must no longer carry.
template_id="bb5a17ca143f4866"

assert_package() {
    label="$1" package="$2"
    meta="$work/$(basename "$package").metadata.xml"
    unzip -p "$package" metadata.xml >"$meta"

    header="$(dbl_header <"$meta")"

    case "$header" in
        *'version="2.'*) pass "$label: header is still DBL 2.x ($header)" ;;
        *) fail "$label: header is not DBL 2.x ($header)" ;;
    esac

    case "$header" in
        *"id=\"$template_id\""*) fail "$label: bundle id was not replaced" ;;
        *'id="'*) pass "$label: bundle id was replaced" ;;
        *) fail "$label: header lost its id attribute" ;;
    esac

    # Everything else that carries an id must be untouched.
    check "$label: <systemId><id> untouched" \
        "$(grep -c '<id>06125adad2d5898a0bfd9b8e13fb698fa5a2d0d8</id>' "$meta" >/dev/null && echo yes || echo no)"
    check "$label: publication id untouched" \
        "$(grep -q '<publication id="p1"' "$meta" && echo yes || echo no)"
    check "$label: name entry ids untouched" \
        "$([ "$(grep -o '<name id="book-' "$meta" | wc -l)" -eq 5 ] && echo yes || echo no)"

    # The <content> map tells ProPresenter where the books are.
    check "$label: <content> map intact" \
        "$(grep -q '<content name="book-gen" src="release/USX_1/GEN.usx" role="GEN"/>' "$meta" \
            && echo yes || echo no)"

    # Book names, in each of the entry shapes the fixture uses: multi-line,
    # one-line, self-closing <abbr/> and <abbr />, and two entries on one line.
    check "$label: multi-line entry localized" \
        "$(grep -q '<long>Piancilna</long>' "$meta" && echo yes || echo no)"
    check "$label: one-line entry localized" \
        "$(grep -q '<name id="book-exo"><abbr>Pai</abbr>' "$meta" && echo yes || echo no)"
    check "$label: self-closing <abbr/> filled in" \
        "$(grep -q '<abbr>Siam</abbr>' "$meta" && echo yes || echo no)"
    check "$label: shared-line entries localized separately" \
        "$(grep -q '<name id="book-num"><abbr>Gam</abbr>.*<name id="book-deu"><abbr>Thkna</abbr>' "$meta" \
            && echo yes || echo no)"
    check "$label: no template book name left behind" \
        "$(grep -q '<long>Genesis</long>' "$meta" && echo no || echo yes)"
}

for shape in 2.1 2.2.1; do
    template="$("$repo_root/tools/make-test-template.sh" "$work/template-$shape.rvbible" "$shape")"

    python3 "$repo_root/tools/build_rvbible.py" --template "$template" \
        --out "$work/py-$shape" >/dev/null
    assert_package "py $shape" "$work/py-$shape/$code.rvbible"

    mkdir -p "$work/dest-$shape"
    # dist/ holds verified packages, so the shell path builds into scratch.
    (cd "$repo_root" && RVBIBLE_TEMPLATE="$template" RVBIBLE_DIST="$work/sh-$shape" \
        DRY_RUN= "$repo_root/tools/install-macos.sh" "$work/dest-$shape" >/dev/null)
    assert_package "sh $shape" "$work/dest-$shape/$code.rvbible"
done

# DBL 1.2 is not a usable template and must stay rejected in both paths.
old="$("$repo_root/tools/make-test-template.sh" "$work/template-1.2.rvbible" 1.2)"

if python3 "$repo_root/tools/build_rvbible.py" --template "$old" \
        --out "$work/py-old" >/dev/null 2>&1; then
    fail "py: a DBL 1.2 template was accepted"
else
    pass "py: a DBL 1.2 template is rejected"
fi

mkdir -p "$work/dest-old"
if (cd "$repo_root" && RVBIBLE_TEMPLATE="$old" RVBIBLE_DIST="$work/sh-old" DRY_RUN= \
        "$repo_root/tools/install-macos.sh" "$work/dest-old" >/dev/null 2>&1); then
    fail "sh: a DBL 1.2 template was accepted"
else
    pass "sh: a DBL 1.2 template is rejected"
fi

echo
if [ "$failures" -eq 0 ]; then
    echo "All metadata checks passed."
else
    echo "$failures check(s) failed." >&2
fi
exit "$failures"
