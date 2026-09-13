#!/usr/bin/env bash
# Installs the Tedim (Chin) Bible bundles into ProPresenter 7 on macOS.
#
# ProPresenter stores each Bible on macOS as a .rvbible file (a zip of a bundle)
# under RVBibles/v2, which is the same format its own Bible downloads use. This
# script builds those packages and copies them in, so ProPresenter registers
# them itself — there is no preference file to edit, unlike on Windows.
#
# Two things about that format are easy to get wrong, and ProPresenter says
# nothing useful when you do — it either reports "We don't handle the file type"
# or quietly ignores the Bible:
#
#   1. The books do not live at the root of the zip. A package ProPresenter
#      accepts looks like:
#          metadata.xml
#          rvmetadata.xml
#          release/USX_1/GEN.usx …
#          release/styles.xml
#          release/versification.vrs
#          release/*.ldml
#   2. metadata.xml must be DBL 2.1 (<DBLMetadata id="…" revision="…"
#      version="2.1">). The metadata.xml files in this repository are DBL 1.2,
#      which ProPresenter does not parse.
#
# Rather than inventing 2.1 metadata, this script borrows it: it takes a
# .rvbible that ProPresenter itself installed, uses it as a template, swaps our
# books and rvmetadata.xml in, and rewrites the identifying fields of the
# template's metadata.xml. So you need at least one working Bible installed
# first — any free one from ProPresenter's Options > Bibles will do.
#
# It needs nothing beyond what macOS already has: no Python, no Xcode command
# line tools.
#
# Quit ProPresenter first. If a destination needs administrator rights, the
# script re-runs that copy with sudo and macOS will ask for your password.
#
# Usage:
#   tools/install-macos.sh [bibles-folder]
#   DRY_RUN=1 tools/install-macos.sh      # show what would happen, change nothing

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dry_run="${DRY_RUN:-}"

system_dest="/Library/Application Support/RenewedVision/RVBibles/v2"
user_dest="$HOME/Library/Application Support/RenewedVision/RVBibles/v2"

# zsh (the default shell on macOS) passes a pasted trailing comment through as
# arguments, so `tools/install-macos.sh   # install` arrives here as two stray
# words. Drop anything from the first '#' on rather than treating it as a path.
args=()
for arg in "$@"; do
    case "$arg" in
        '#'*) break ;;
        *) args+=("$arg") ;;
    esac
done
set -- ${args[@]+"${args[@]}"}

# Some installs read only the per-user folder, others only the system one, and
# nothing in ProPresenter says which. Install into both unless told otherwise.
if [ $# -ge 1 ]; then
    destinations=("$1")
else
    destinations=("$system_dest" "$user_dest")
fi

if pgrep -x ProPresenter >/dev/null 2>&1; then
    echo "ProPresenter is running. Quit it first, then run this script again." >&2
    exit 1
fi

# Write with sudo only where the destination actually needs it.
run_write() {
    local target_dir="$1"
    shift
    if [ -n "$dry_run" ]; then
        echo "  would run: $*"
    elif [ -w "$target_dir" ] || { [ ! -e "$target_dir" ] && [ -w "$(dirname "$target_dir")" ]; }; then
        "$@"
    else
        sudo "$@"
    fi
}

work="$(mktemp -d "${TMPDIR:-/tmp}/rvbible.XXXXXX")"
trap 'rm -rf "$work"' EXIT

# --- find a template ---------------------------------------------------------
#
# A usable template is a .rvbible ProPresenter installed itself: it has the
# release/USX_1/ layout and DBL 2.1 metadata. The American Standard Version is
# the usual free download, so prefer it, but any valid package works.

# `unzip | grep -q` is deliberately avoided: grep exits at the first match,
# unzip dies of SIGPIPE, and pipefail then fails the whole pipeline. Capture the
# listing first and grep that.
zip_contains() {
    local listing
    listing="$(unzip -l "$1" 2>/dev/null || true)"
    case "$listing" in
        *"$2"*) return 0 ;;
        *) return 1 ;;
    esac
}

is_valid_template() {
    local candidate="$1" metadata
    zip_contains "$candidate" 'release/USX_1/' || return 1
    metadata="$(unzip -p "$candidate" metadata.xml 2>/dev/null || true)"
    case "$metadata" in
        *'version="2.1"'*) return 0 ;;
        *) return 1 ;;
    esac
}

find_template() {
    local dir candidate
    # Preferred name first, then anything else that validates.
    for dir in "$user_dest" "$system_dest"; do
        [ -d "$dir" ] || continue
        for candidate in "$dir"/publicdomain_American_Standard_Version*.rvbible; do
            [ -f "$candidate" ] || continue
            if is_valid_template "$candidate"; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    for dir in "$user_dest" "$system_dest"; do
        [ -d "$dir" ] || continue
        for candidate in "$dir"/*.rvbible; do
            [ -f "$candidate" ] || continue
            if is_valid_template "$candidate"; then
                printf '%s\n' "$candidate"
                return 0
            fi
        done
    done
    return 1
}

shopt -s nullglob

template=""
if ! template="$(find_template)"; then
    cat >&2 <<'EOF'
No usable .rvbible template was found.

This script copies the package structure from a Bible ProPresenter installed
itself, because ProPresenter only accepts its own metadata format. To get one:

  1. Open ProPresenter.
  2. Go to Options (or Preferences) > Bibles.
  3. Download any free Bible — "American Standard Version" under Public Domain
     is the one this script looks for first, but any of them will do.
  4. Quit ProPresenter and run this script again.

Looked in:
EOF
    printf '  %s\n' "$system_dest" "$user_dest" >&2
    exit 1
fi

echo "Using template: $template"

template_dir="$work/template"
mkdir -p "$template_dir"
unzip -q "$template" -d "$template_dir"

# --- helpers for rewriting the template's metadata ---------------------------

# Read a top-level element out of our rvmetadata.xml.
rv_field() {
    local file="$1" field="$2"
    tr '\n' ' ' <"$file" \
        | sed -n "s|.*<$field>\(.*\)</$field>.*|\1|p" \
        | sed -n '1{s/^ *//;s/ *$//;p;}'
}

xml_escape() {
    printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

new_id() {
    # 16 lowercase hex characters, the shape of a DBL 2.1 id.
    LC_ALL=C od -An -N8 -tx1 /dev/urandom | tr -d ' \n'; echo
}

# --- localized book names ----------------------------------------------------
#
# The template's metadata.xml carries the template Bible's <names> section, so
# a transplanted package shows English book names ("Genesis") over our text.
# These build a table of local names for the books we ship and write them into
# the template's entries.
#
# Preferred source is the bundle's own DBL 1.2 metadata.xml, which has a
# <bookNames> block; where a book is missing there, the USX file itself carries
# \toc1 (long), \toc2 or \h (short) and \toc3 (abbreviation).

# Escape for XML content, leaving existing entities (&#4096; in the Burmese
# names) alone — the values are lifted straight out of XML and are escaped
# already; only a bare '&' needs help.
names_awk_prelude='
function xmlsafe(v,   out, i, rest) {
    out = ""
    while ((i = index(v, "&")) > 0) {
        out = out substr(v, 1, i - 1)
        rest = substr(v, i)
        if (match(rest, /^&[#A-Za-z][A-Za-z0-9]*;/)) {
            out = out substr(rest, 1, RLENGTH)
            v = substr(rest, RLENGTH + 1)
        } else {
            out = out "\&amp;"
            v = substr(rest, 2)
        }
    }
    v = out v
    gsub(/</, "\&lt;", v)
    gsub(/>/, "\&gt;", v)
    return v
}
function attrtext(line, tag,   open, endtag, i, j, k) {
    open = "<" tag " "
    endtag = "</" tag ">"
    i = index(line, open)
    if (i == 0) return ""
    j = index(substr(line, i), ">")
    if (j == 0) return ""
    k = i + j
    j = index(substr(line, k), endtag)
    if (j == 0) return ""
    return substr(line, k, j - 1)
}
function tagtext(line, tag,   open, endtag, i, j) {
    open = "<" tag ">"
    endtag = "</" tag ">"
    i = index(line, open)
    if (i == 0) return ""
    j = index(substr(line, i + length(open)), endtag)
    if (j == 0) return ""
    return substr(line, i + length(open), j - 1)
}
'

# CODE<tab>abbr<tab>short<tab>long for every book in the bundle's metadata.
names_from_metadata() {
    [ -f "$1" ] || return 0
    awk "$names_awk_prelude"'
        /<bookNames>/  { inside = 1 }
        /<\/bookNames>/ { inside = 0 }
        inside && /<book code="[A-Z0-9]+"/ {
            line = $0
            i = index(line, "code=\"")
            code = substr(line, i + 6)
            code = substr(code, 1, index(code, "\"") - 1)
            a = ""; s = ""; l = ""
        }
        inside && code != "" {
            if (l == "") l = tagtext($0, "long")
            if (s == "") s = tagtext($0, "short")
            if (a == "") a = tagtext($0, "abbr")
        }
        inside && /<\/book>/ && code != "" {
            print code "\t" xmlsafe(a) "\t" xmlsafe(s) "\t" xmlsafe(l)
            code = ""
        }
    ' "$1"
}

# CODE<tab>abbr<tab>short<tab>long from one USX file, read only as far as the
# first chapter — the name lines all sit in the header.
names_from_usx() {
    awk -v code="$2" "$names_awk_prelude"'
        /<chapter/ { exit }
        /<para style="toc1">/ { l = attrtext($0, "para") }
        /<para style="toc2">/ { s = attrtext($0, "para") }
        /<para style="toc3">/ { a = attrtext($0, "para") }
        /<para style="h">/    { h = attrtext($0, "para") }
        END {
            if (s == "") s = h
            if (l == "" && s == "" && a == "") exit
            print code "\t" xmlsafe(a) "\t" xmlsafe(s) "\t" xmlsafe(l)
        }
    ' "$1"
}

# Merge both sources for the books we actually ship, filling gaps in one
# direction only: metadata wins, the USX header fills what it leaves empty, and
# long/short/abbr stand in for each other rather than being written blank.
build_names_table() {
    local bundle="$1" books="$2" table="$3"
    local raw="$table.raw" usx code

    : >"$raw"
    names_from_metadata "$bundle/metadata.xml" >>"$raw"
    for usx in "$books"/*.usx; do
        code="$(basename "$usx" .usx)"
        names_from_usx "$usx" "$code" >>"$raw"
    done

    # Books we ship, in the order their files appear.
    for usx in "$books"/*.usx; do
        basename "$usx" .usx
    done >"$table.codes"

    awk -F'\t' '
        FNR == NR {
            # First entry for a code wins per field; later ones only fill gaps.
            if (!($1 in seen)) { seen[$1] = 1; a[$1] = $2; s[$1] = $3; l[$1] = $4 }
            else {
                if (a[$1] == "") a[$1] = $2
                if (s[$1] == "") s[$1] = $3
                if (l[$1] == "") l[$1] = $4
            }
            next
        }
        {
            code = $1
            if (!(code in seen)) next
            av = a[code]; sv = s[code]; lv = l[code]
            if (sv == "") sv = (lv != "" ? lv : av)
            if (lv == "") lv = sv
            if (av == "") av = sv
            if (av == "" && sv == "" && lv == "") next
            print code "\t" av "\t" sv "\t" lv
        }
    ' "$raw" "$table.codes" >"$table"

    rm -f "$raw" "$table.codes"
}

# Write those names into the template metadata's <names> entries, which look
# like <name id="book-gen"><abbr/><short/><long/></name>, on one line or
# several. Entries for books we do not ship are left as the template had them,
# matching how the template itself lists every book it carries.
apply_book_names() {
    local table="$1" metadata="$2"

    [ -s "$table" ] || return 0

    awk -F'\t' '
        function replace_tag(line, tag, val,   open, endtag, self, i, j, k) {
            if (val == "") return line
            open = "<" tag ">"
            endtag = "</" tag ">"
            i = index(line, open)
            if (i > 0) {
                j = index(substr(line, i + length(open)), endtag)
                if (j == 0) return line
                return substr(line, 1, i - 1) open val endtag \
                       substr(line, i + length(open) + j - 1 + length(endtag))
            }
            for (k = 0; k <= 1; k++) {
                self = (k == 0) ? "<" tag "/>" : "<" tag " />"
                i = index(line, self)
                if (i > 0)
                    return substr(line, 1, i - 1) open val endtag \
                           substr(line, i + length(self))
            }
            return line
        }
        FNR == NR { a[$1] = $2; s[$1] = $3; l[$1] = $4; next }
        {
            line = $0
            if (match(line, /<name id="book-[A-Za-z0-9]+"/)) {
                code = substr(line, RSTART, RLENGTH)
                sub(/.*book-/, "", code)
                sub(/"$/, "", code)
                code = toupper(code)
            }
            if (index(line, "</names>") > 0) code = ""
            if (code != "" && code in a) {
                line = replace_tag(line, "abbr", a[code])
                line = replace_tag(line, "short", s[code])
                line = replace_tag(line, "long", l[code])
            }
            print line
        }
    ' "$table" "$metadata" >"$metadata.names"
    mv "$metadata.names" "$metadata"
}

# --- build ------------------------------------------------------------------

echo "Building .rvbible packages..."
mkdir -p "$repo_root/dist"

packages=()
# Counted separately: macOS ships bash 3.2, where ${#array[@]} on an empty array
# counts as unbound under `set -u` and aborts with a confusing error.
built=0

for bundle in "$repo_root"/bibles/*/; do
    # Each bundle folder is named for its code, which is also the package name.
    abbr="$(basename "$bundle")"
    package="$repo_root/dist/$abbr.rvbible"

    if [ ! -f "$bundle/rvmetadata.xml" ]; then
        echo "  skipping $abbr: no rvmetadata.xml" >&2
        continue
    fi

    books="$bundle/USX"
    [ -d "$books" ] || books="$bundle/USX_1"
    if [ ! -d "$books" ]; then
        echo "  skipping $abbr: no USX/ or USX_1/ folder" >&2
        continue
    fi

    stage="$work/stage-$abbr"
    rm -rf "$stage"
    cp -R "$template_dir" "$stage"

    # Our books replace the template's, under the name ProPresenter reads.
    rm -rf "$stage/release/USX_1"
    mkdir -p "$stage/release/USX_1"
    cp "$books"/*.usx "$stage/release/USX_1/"

    # Keep the template's styles.xml, versification.vrs and .ldml unless this
    # bundle ships its own.
    for extra in styles.xml versification.vrs; do
        if [ -f "$bundle/$extra" ]; then
            cp "$bundle/$extra" "$stage/release/$extra"
        fi
    done
    for ldml in "$bundle"/*.ldml; do
        rm -f "$stage"/release/*.ldml
        cp "$ldml" "$stage/release/"
    done

    # ProPresenter's own metadata, which names the translation in its UI.
    cp "$bundle/rvmetadata.xml" "$stage/rvmetadata.xml"
    if [ -f "$bundle/license.xml" ]; then
        cp "$bundle/license.xml" "$stage/license.xml"
    fi

    # Rewrite the identifying fields of the template's 2.1 metadata so the
    # package describes our translation rather than the template's.
    name="$(rv_field "$bundle/rvmetadata.xml" name)"
    abbreviation="$(rv_field "$bundle/rvmetadata.xml" abbreviation)"
    [ -n "$abbreviation" ] || abbreviation="$abbr"
    [ -n "$name" ] || name="$abbr"

    esc_name="$(xml_escape "$name")"
    esc_abbr="$(xml_escape "$abbreviation")"
    fresh_id="$(new_id)"

    # Only the first id="…" is the bundle id; later ones belong to book and
    # name entries, so the substitution is anchored to that first line.
    awk -v id="$fresh_id" -v name="$esc_name" -v abbr="$esc_abbr" '
        !done_id && /id="[0-9a-fA-F]+"/ {
            sub(/id="[0-9a-fA-F]+"/, "id=\"" id "\"")
            done_id = 1
        }
        !done_name && /<name>/          { sub(/<name>[^<]*<\/name>/, "<name>" name "</name>"); done_name = 1; print; next }
        !done_local && /<nameLocal>/    { sub(/<nameLocal>[^<]*<\/nameLocal>/, "<nameLocal>" name "</nameLocal>"); done_local = 1; print; next }
        !done_desc && /<description>/   { sub(/<description>[^<]*<\/description>/, "<description>" name "</description>"); done_desc = 1; print; next }
        !done_ab && /<abbreviation>/    { sub(/<abbreviation>[^<]*<\/abbreviation>/, "<abbreviation>" abbr "</abbreviation>"); done_ab = 1; print; next }
        !done_ablocal && /<abbreviationLocal>/ { sub(/<abbreviationLocal>[^<]*<\/abbreviationLocal>/, "<abbreviationLocal>" abbr "</abbreviationLocal>"); done_ablocal = 1; print; next }
        { print }
    ' "$stage/metadata.xml" >"$stage/metadata.xml.new"
    mv "$stage/metadata.xml.new" "$stage/metadata.xml"

    # …and give it our book names, so the Bible view does not list Genesis in
    # English over Tedim or Burmese text.
    build_names_table "$bundle" "$books" "$work/names-$abbr.tsv"
    apply_book_names "$work/names-$abbr.tsv" "$stage/metadata.xml"

    rm -f "$package"
    # A .rvbible is a zip of the bundle's *contents*, so zip from inside it.
    (cd "$stage" && zip -q -r -X "$package" . -x '*.DS_Store')

    # Cheap guard against silently shipping the old, flat layout again.
    if ! zip_contains "$package" 'release/USX_1/'; then
        echo "  built $abbr.rvbible without release/USX_1/ — refusing to install it" >&2
        exit 1
    fi

    echo "  built $abbr.rvbible ($name / $abbreviation, id $fresh_id)"
    packages+=("$package")
    built=$((built + 1))
done

if [ "$built" -eq 0 ]; then
    echo "No .rvbible packages were built." >&2
    echo "Is $repo_root/bibles missing or empty?" >&2
    exit 1
fi

# --- install ----------------------------------------------------------------

for dest in "${destinations[@]}"; do
    echo
    echo "Installing into: $dest"
    run_write "$dest" mkdir -p "$dest"

    for package in "${packages[@]}"; do
        name="$(basename "$package")"
        if [ -e "$dest/$name" ]; then
            echo "Replacing existing $name"
        fi
        run_write "$dest" cp "$package" "$dest/$name"
        [ -n "$dry_run" ] || echo "Installed $name"
    done
done

if [ -n "$dry_run" ]; then
    echo
    echo "Dry run - nothing was written."
    exit 0
fi

echo
echo "Done. Start ProPresenter and open the Bible view."
echo "If a translation does not show up, quit ProPresenter completely with"
echo "Cmd+Q and start it again — sometimes twice. If an older copy of one of"
echo "these Bibles is installed under a different filename, delete it from both"
echo "RVBibles/v2 folders first: ProPresenter hides duplicates."
